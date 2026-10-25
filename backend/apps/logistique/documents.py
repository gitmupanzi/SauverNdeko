"""Documents PDF et justificatifs privés issus des données métier autorisées."""
import hashlib
import io
import re
import unicodedata
from datetime import datetime
from decimal import Decimal, ROUND_HALF_UP
from html import escape
from pathlib import Path
from zoneinfo import ZoneInfo

from django.conf import settings
from django.db import transaction
from django.http import HttpResponse
from django.utils.http import content_disposition_header
from rest_framework.views import APIView
from rest_framework.parsers import MultiPartParser,FormParser
from rest_framework.renderers import BaseRenderer
from rest_framework.response import Response
from apps.core.responses import ExactJSONRenderer
from apps.core import db
from apps.core.module_access import require_module
from apps.core.permissions import IsERPAdmin
from apps.core.registry import model, view
from apps.core.repository import get_record, positive, audit, clean
from apps.core.responses import APIError, ok

MAX_BYTES=8*1024*1024
KINDS={'bon','facture','reglement','avoir'}
PDF_TYPES={'bon':{'entree','sortie','livraison'},'facture':{'facture'},'reglement':{'recu'},'avoir':{'avoir'}}


def document_parent(actor,kind,object_id,lock=False):
    if kind not in KINDS:raise APIError('Document introuvable.','NOT_FOUND',404)
    require_module(actor,'logistique','read')
    object_id=positive(object_id)
    if kind in {'bon','facture'}:
        record=get_record(model('T_Commande'),actor,{'ID_Commande':object_id},lock=lock)
        parent=record
        if kind=='facture':
            record=db.one('SELECT * FROM logistique."V_Facture" WHERE "ID_CommandeFk"=%s',[object_id])
            if not record:raise APIError('La facture doit être émise avant son téléchargement.','DOCUMENT_NOT_ISSUED',409)
    elif kind=='reglement':
        record=get_record(model('T_Reglements'),actor,{'ID_Reglement':object_id},lock=lock)
        parent=get_record(model('T_Commande'),actor,{'CodeFacture':record.get('CodeFactureFk')},lock=lock)
    else:
        record=db.one('SELECT * FROM logistique."T_Avoir" WHERE "ID_Avoir"=%s',[object_id])
        if not record:raise APIError('Avoir introuvable.','NOT_FOUND',404)
        parent=get_record(model('T_Commande'),actor,{'ID_Commande':record['ID_CommandeFk']},lock=lock)
    entity=parent.get('IdEntiteFk')
    if entity is None:raise APIError('Rattachez ce document à son entreprise avant son édition.','DOCUMENT_ENTITY_REQUIRED',409)
    if kind in {'facture','avoir'} and record.get('IdEntiteFk')!=entity:raise APIError('Le rattachement du document doit être vérifié.','DOCUMENT_ENTITY_CONFLICT',409)
    return record,parent,entity


def can_manage(actor,parent):
    db.ensure_writable()
    require_module(actor,'logistique','manage')
    from apps.core.tenancy import assert_document
    assert_document(actor,parent)


def identity(kind,object_id,entity):
    frozen=db.one('SELECT * FROM logistique."T_DocumentIdentite" WHERE "TypeObjet"=%s AND "ID_Objet"=%s',[kind,object_id])
    if not frozen or frozen['IdEntiteFk']!=entity:
        raise APIError('L’identité documentaire doit être préparée par votre administrateur.','DOCUMENT_IDENTITY_REQUIRED',409)
    return frozen


def filename(value,extension):
    base=unicodedata.normalize('NFKD',str(value)).encode('ascii','ignore').decode('ascii')
    return (re.sub(r'[^A-Za-z0-9_-]+','-',base).strip('-')[:100] or 'document')+'.'+extension


def date_label(value):
    if not value:return '—'
    if isinstance(value,str):
        try:value=datetime.fromisoformat(value.replace('Z','+00:00'))
        except ValueError:return value[:40]
    if isinstance(value,datetime):
        if value.tzinfo is None:value=value.replace(tzinfo=ZoneInfo(settings.TIME_ZONE))
        return value.astimezone(ZoneInfo(settings.TIME_ZONE)).strftime('%d/%m/%Y %H:%M')
    return value.strftime('%d/%m/%Y')


def numeric(value,scale=None):
    if value is None:return '—'
    number=Decimal(str(value))
    if scale is not None:number=number.quantize(Decimal(10)**(-scale),rounding=ROUND_HALF_UP)
    rendered=format(number,',.'+str(scale)+'f') if scale is not None else format(number,',f').rstrip('0').rstrip('.') if '.' in str(number) else format(number,',f')
    return rendered.replace(',',' ').replace('.',',')


def money(value,currency):
    return numeric(value,2)+(' '+str(currency) if currency else ' · devise à préciser')


def document_data(actor,kind,object_id,document_type):
    record,parent,entity=document_parent(actor,kind,object_id)
    if document_type not in PDF_TYPES[kind]:raise APIError('Format de document introuvable.','NOT_FOUND',404)
    frozen=identity(kind,object_id,entity)
    currency=record.get('DeviseCode') or db.one('SELECT "DeviseCode" FROM logistique."V_Commande" WHERE "ID_Commande"=%s',[parent['ID_Commande']])['DeviseCode']
    result={'emitter':frozen['IdentiteEmetteur'],'thirdParty':frozen.get('IdentiteTiers'),
      'historical':frozen['RepriseHistorique'],'currency':currency,'parentCode':parent.get('CodeCmd'),
      'recipient':parent.get('NomClientSaisi'),'reference':parent.get('RefCmd') or parent.get('ReferenceCmd'),
      'destination':parent.get('DestinationLibelle') or parent.get('geolocalisationCmd') or parent.get('LieuLivraison'),'lines':[],'totals':[],'notes':[]}
    if kind=='bon':
        # Le bon préparatoire reste modifiable ; son tiers courant est celui du bon.
        result['thirdParty']=None
        source=get_record(view('logistique','V_Commande'),actor,{'ID_Commande':object_id})
        result['destination']=source.get('DestinationLibelle') or result['destination']
        if parent.get('ID_TiersFk'):
            result['thirdParty']=db.one('SELECT * FROM logistique."T_Client" WHERE "ID_Client"=%s AND "IdEntiteFk"=%s',[parent['ID_TiersFk'],entity])
        incoming=source.get('EstCommandeEntree') is True;outgoing=source.get('EstCommandeSortie') is True
        if document_type=='entree' and not incoming or document_type in {'sortie','livraison'} and not outgoing:
            raise APIError('Ce type de document ne correspond pas au bon.','DOCUMENT_TYPE_MISMATCH',409)
        result.update({'title':{'entree':'Bon d’entrée','sortie':'Bon de sortie','livraison':'Bon de livraison'}[document_type],
          'code':parent.get('CodeCmd'),'date':parent.get('DateCmd')})
        rows=db.query('''SELECT d."ID_ArticleFk",a."NomArticle",a."RefArticle",u."AbrGenerique" AS "Unite",d."QteCmdDetail",d."PUCmdDetail"
          FROM logistique."T_CommandeDetail" d JOIN logistique."T_Article" a ON a."ID_Article"=d."ID_ArticleFk"
          LEFT JOIN referentiel."T_Generique" u ON u."ID_Generique"=a."ID_UniteFk" WHERE d."ID_CmdFk"=%s ORDER BY d."ID_ArticleFk"''',[object_id])
        result['lines']=[{'name':r['NomArticle'],'reference':r['RefArticle'],'quantity':r['QteCmdDetail'],'unit':r['Unite'],'price':r['PUCmdDetail'],'amount':Decimal(str(r['QteCmdDetail']))*Decimal(str(r['PUCmdDetail'])) if r['PUCmdDetail'] is not None else None} for r in rows]
        result['totals']=[('Montant du bon',source.get('MontantTTC'))]
        if parent.get('ObsCmd'):result['notes'].append(parent['ObsCmd'])
        if document_type=='livraison':result['notes'].append('Réceptionnaire et visa à compléter lors de la remise des articles.')
    elif kind=='facture':
        result.update({'title':'Facture','code':record['CodeFacture'],'date':record['DateFacture'],'dueDate':record.get('DateEcheancePaiement')})
        rows=db.query('SELECT * FROM logistique."T_FactureLigne" WHERE "ID_FactureFk"=%s ORDER BY "ID_ArticleFk"',[record['ID_Facture']])
        result['lines']=[{'name':r['NomArticle'],'reference':r['CodeArticleInterne'],'quantity':r['QteFacturee'],'unit':r['Unite'],'price':r['PUFacture'],'amount':r['MontantLigne']} for r in rows]
        result['totals']=[('Montant HT',record['MontantHT']),('Montant TTC',record['MontantTTC']),('Avoirs imputés',record.get('AvoirImpute',0)),('Réglé',record.get('TotalRegle')),('Reste à régler',record.get('Reste'))]
        result['notes'].append('Montants repris de la facture émise.')
    elif kind=='reglement':
        result.update({'title':'Reçu de règlement','code':'reg-'+str(record['ID_Reglement']),'date':record['DateReglement']})
        mode=db.one('SELECT "NomGenerique" AS label FROM referentiel."T_Generique" WHERE "ID_Generique"=%s',[record.get('ID_ModeReglementFk')])
        result['lines']=[{'name':'Règlement de la facture '+str(record['CodeFactureFk']),'reference':(mode or {}).get('label'),'quantity':None,'unit':None,'price':None,'amount':record['MontantRegle']}]
        result['totals']=[('Montant reçu',record['MontantRegle'])]
    else:
        result.update({'title':'Avoir','code':record['CodeAvoir'],'date':record['DateAvoir']})
        rows=db.query('SELECT * FROM logistique."T_AvoirLigne" WHERE "ID_AvoirFk"=%s ORDER BY "ID_ArticleFk"',[object_id])
        result['lines']=[{'name':r['NomArticle'],'reference':None,'quantity':r['Quantite'],'unit':r.get('Unite'),'price':r['PUAvoir'],'amount':r['MontantLigne']} for r in rows]
        result['totals']=[('Montant de l’avoir',record['MontantTTC'])]
        result['notes'].append(record['Motif'])
    return result


def render_pdf(data):
    from reportlab.lib import colors
    from reportlab.lib.enums import TA_RIGHT
    from reportlab.lib.styles import getSampleStyleSheet,ParagraphStyle
    from reportlab.lib.units import mm
    from reportlab.lib.pagesizes import A4
    from reportlab.platypus import SimpleDocTemplate,Paragraph,Spacer,Table,TableStyle,KeepTogether
    from reportlab.pdfgen.canvas import Canvas
    output=io.BytesIO();styles=getSampleStyleSheet()
    styles.add(ParagraphStyle(name='BodyERP',fontName='Helvetica',fontSize=10,leading=14,textColor=colors.HexColor('#252525'),spaceAfter=4))
    styles.add(ParagraphStyle(name='SmallERP',parent=styles['BodyERP'],fontSize=8,leading=11,textColor=colors.HexColor('#5F6B7A')))
    styles.add(ParagraphStyle(name='CellERP',parent=styles['BodyERP'],fontSize=9,leading=12,spaceAfter=0))
    styles.add(ParagraphStyle(name='RightERP',parent=styles['CellERP'],alignment=TA_RIGHT))
    styles.add(ParagraphStyle(name='TitleERP',parent=styles['BodyERP'],fontName='Helvetica-Bold',fontSize=18,leading=23,spaceAfter=8))
    def p(text,style='BodyERP'):return Paragraph(escape(str(text if text is not None else '—')).replace('\n','<br/>'),styles[style])
    emitter=data.get('emitter') or {};currency=data.get('currency');story=[]
    story.append(p(emitter.get('NomEntite') or 'Entreprise à renseigner','TitleERP'))
    for key in ('AdresseEntite','EmailEntite','PhoneEntite'):
        if emitter.get(key):story.append(p(emitter[key],'SmallERP'))
    story.append(Spacer(1,7*mm));story.append(p(data['title'],'TitleERP'))
    story.append(p('N° '+str(data.get('code') or '—')+' · '+date_label(data.get('date'))))
    if data.get('parentCode') and data['parentCode']!=data.get('code'):story.append(p('Bon d’origine : '+str(data['parentCode']),'SmallERP'))
    third=data.get('thirdParty') or {}
    recipient=third.get('Nom') or third.get('NomTiers') or third.get('NomClient') or data.get('recipient')
    if recipient:story.append(p('Tiers : '+str(recipient)))
    if data.get('destination'):story.append(p('Destination : '+str(data['destination'])))
    if data.get('dueDate'):story.append(p('Échéance : '+date_label(data['dueDate'])))
    story.append(Spacer(1,5*mm))
    header=['Désignation','Quantité','Unité','Prix unitaire','Montant']
    rows=[[p(x,'CellERP') for x in header]]
    for row in data['lines']:
        name=str(row.get('name') or '—')
        if row.get('reference'):name+='\n'+str(row['reference'])
        rows.append([p(name,'CellERP'),p(numeric(row.get('quantity')),'RightERP'),p(row.get('unit'),'CellERP'),p(money(row.get('price'),currency) if row.get('price') is not None else '—','RightERP'),p(money(row.get('amount'),currency),'RightERP')])
    if len(rows)==1:rows.append([p('Aucune ligne','CellERP'),'','','',''])
    table=Table(rows,colWidths=[66*mm,22*mm,14*mm,30*mm,33*mm],repeatRows=1,hAlign='LEFT')
    table.setStyle(TableStyle([('BACKGROUND',(0,0),(-1,0),colors.HexColor('#EAF1FF')),('FONTNAME',(0,0),(-1,0),'Helvetica-Bold'),('ROWBACKGROUNDS',(0,1),(-1,-1),[colors.white,colors.HexColor('#F4F4F4')]),('LINEBELOW',(0,0),(-1,0),.6,colors.HexColor('#D8E1EC')),('LINEBELOW',(0,1),(-1,-1),.25,colors.HexColor('#D8E1EC')),('VALIGN',(0,0),(-1,-1),'TOP'),('TOPPADDING',(0,0),(-1,-1),8),('BOTTOMPADDING',(0,0),(-1,-1),8)]))
    story.append(table);story.append(Spacer(1,5*mm))
    totals=Table([[p(label,'CellERP'),p(money(value,currency),'RightERP')] for label,value in data['totals']],colWidths=[110*mm,55*mm],hAlign='RIGHT')
    totals.setStyle(TableStyle([('VALIGN',(0,0),(-1,-1),'TOP'),('TOPPADDING',(0,0),(-1,-1),5),('BOTTOMPADDING',(0,0),(-1,-1),5),('LINEABOVE',(0,-1),(-1,-1),.6,colors.HexColor('#D8E1EC'))]))
    story.append(KeepTogether([totals,Spacer(1,4*mm)]))
    for note in data.get('notes',[]):story.append(p(note,'SmallERP'))
    if data.get('historical'):story.append(p('Identité de l’entreprise reprise lors de la mise en service des documents.','SmallERP'))
    if data['title']=='Bon de livraison':story.extend([Spacer(1,8*mm),p('Réceptionnaire : ____________________     Date : ____________________','SmallERP'),p('Visa : ____________________','SmallERP')])
    class Pages(Canvas):
        def __init__(self,*args,**kwargs):super().__init__(*args,**kwargs);self.states=[]
        def showPage(self):self.states.append(dict(self.__dict__));self._startPage()
        def save(self):
            count=len(self.states)
            for state in self.states:
                self.__dict__.update(state);self.saveState();self.setStrokeColor(colors.HexColor('#D8E1EC'));self.line(25*mm,18*mm,190*mm,18*mm)
                self.setFont('Helvetica',8);self.setFillColor(colors.HexColor('#5F6B7A'));self.drawString(25*mm,13*mm,'SauverNdeko · '+str(data.get('code') or 'Document'));self.drawRightString(190*mm,13*mm,'Page '+str(self._pageNumber)+' sur '+str(count));self.restoreState();Canvas.showPage(self)
            Canvas.save(self)
    SimpleDocTemplate(output,pagesize=A4,leftMargin=25*mm,rightMargin=20*mm,topMargin=20*mm,bottomMargin=25*mm,title=data['title']+' '+str(data.get('code') or ''),author=str(emitter.get('NomEntite') or '')).build(story,canvasmaker=Pages)
    return output.getvalue()


def binary_response(blob,mime,name):
    response=HttpResponse(blob,content_type=mime)
    response['Content-Disposition']=content_disposition_header(True,name)
    response['Cache-Control']='private, no-store'
    response['X-Content-Type-Options']='nosniff'
    return response



class PdfRenderer(BaseRenderer):
    media_type='application/pdf';format='pdf';charset=None
    def render(self,data,accepted_media_type=None,renderer_context=None):return bytes(data or b'')
class JpegRenderer(PdfRenderer):media_type='image/jpeg';format='jpg'
class PngRenderer(PdfRenderer):media_type='image/png';format='png'
class WebpRenderer(PdfRenderer):media_type='image/webp';format='webp'
class DocumentDownloadView(APIView):
    renderer_classes=[ExactJSONRenderer,PdfRenderer,JpegRenderer,PngRenderer,WebpRenderer]
    def finalize_response(self,request,response,*args,**kwargs):
        if isinstance(response,Response):request.accepted_renderer=ExactJSONRenderer();request.accepted_media_type='application/json'
        return super().finalize_response(request,response,*args,**kwargs)

class DocumentPdfView(DocumentDownloadView):
    permission_classes=[IsERPAdmin]
    http_method_names=['get','options']
    def get(self,request,kind,pk,document_type):
        with transaction.atomic():data=document_data(request.user,kind,positive(pk),document_type)
        return binary_response(render_pdf(data),'application/pdf',filename(str(data['title'])+'-'+str(data.get('code') or pk),'pdf'))


def validate_upload(upload):
    if not upload or upload.size<=0 or upload.size>MAX_BYTES:raise APIError({'file':'Choisissez un PDF ou une image de 8 Mo maximum.'},'ATTACHMENT_VALIDATION',400)
    content=upload.read(MAX_BYTES+1)
    if len(content)>MAX_BYTES:raise APIError({'file':'Le fichier dépasse 8 Mo.'},'ATTACHMENT_VALIDATION',400)
    if content.startswith(b'%PDF-') and b'%%EOF' in content[-2048:]:return content,'application/pdf','pdf'
    from .photos import normalize_photo
    upload.seek(0)
    try:content=normalize_photo(upload)
    except APIError:raise APIError({'file':'Le fichier doit être un PDF, JPEG, PNG ou WebP valide.'},'ATTACHMENT_VALIDATION',400)
    return content,'image/jpeg','jpg'


class AttachmentsView(DocumentDownloadView):
    parser_classes=[MultiPartParser,FormParser]
    permission_classes=[IsERPAdmin]
    http_method_names=['get','post','delete','options']
    def get(self,request,kind,pk,piece_id=None):
        _,_,entity=document_parent(request.user,kind,positive(pk))
        if piece_id is not None:
            row=db.one('SELECT "NomFichier","MimeType","Contenu" FROM logistique."T_PieceJustificative" WHERE "ID_Piece"=%s AND "TypeObjet"=%s AND "ID_Objet"=%s AND "IdEntiteFk"=%s AND NOT "Archive"',[positive(piece_id),kind,positive(pk),entity])
            if not row:raise APIError('Pièce introuvable.','NOT_FOUND',404)
            return binary_response(bytes(row['Contenu']),row['MimeType'],row['NomFichier'])
        rows=db.query('SELECT * FROM logistique."V_PieceJustificative" WHERE "TypeObjet"=%s AND "ID_Objet"=%s AND "IdEntiteFk"=%s AND NOT "Archive" ORDER BY "CreeLe" DESC,"ID_Piece" DESC',[kind,positive(pk),entity])
        return ok(clean(rows))
    def post(self,request,kind,pk,piece_id=None):
        if piece_id is not None:raise APIError('Action introuvable.','NOT_FOUND',404)
        if set(request.data)-{'file'}:raise APIError('Un seul fichier est attendu.','ATTACHMENT_VALIDATION',400)
        upload=request.FILES.get('file');blob,mime,extension=validate_upload(upload)
        name=filename(Path(str(upload.name).replace('\\','/')).stem,extension)
        with transaction.atomic():
            _,parent,entity=document_parent(request.user,kind,positive(pk),lock=True);can_manage(request.user,parent)
            row=db.one('''INSERT INTO logistique."T_PieceJustificative"("TypeObjet","ID_Objet","IdEntiteFk","ID_UserFk","NomFichier","MimeType","TailleOctets","Sha256","Contenu") VALUES(%s,%s,%s,%s,%s,%s,%s,%s,%s) RETURNING "ID_Piece","NomFichier","MimeType","TailleOctets","CreeLe"''',[kind,positive(pk),entity,request.user.pk,name,mime,len(blob),hashlib.sha256(blob).hexdigest(),blob])
            audit({'schema':'logistique','name':'T_PieceJustificative'},'ATTACHMENT_ADD',new={**row,'TypeObjet':kind,'ID_Objet':positive(pk),'IdEntiteFk':entity},actor=request.user)
        return ok(clean(row),status=201,message='Justificatif ajouté.')
    def delete(self,request,kind,pk,piece_id=None):
        if piece_id is None:raise APIError('Pièce introuvable.','NOT_FOUND',404)
        with transaction.atomic():
            _,parent,entity=document_parent(request.user,kind,positive(pk),lock=True);can_manage(request.user,parent)
            row=db.one('UPDATE logistique."T_PieceJustificative" SET "Archive"=true WHERE "ID_Piece"=%s AND "TypeObjet"=%s AND "ID_Objet"=%s AND "IdEntiteFk"=%s AND NOT "Archive" RETURNING "ID_Piece","NomFichier"',[positive(piece_id),kind,positive(pk),entity])
            if not row:raise APIError('Pièce introuvable.','NOT_FOUND',404)
            audit({'schema':'logistique','name':'T_PieceJustificative'},'ATTACHMENT_ARCHIVE',new={**row,'TypeObjet':kind,'ID_Objet':positive(pk),'IdEntiteFk':entity},actor=request.user)
        return ok({'archived':True},message='Justificatif retiré de la liste active.')
