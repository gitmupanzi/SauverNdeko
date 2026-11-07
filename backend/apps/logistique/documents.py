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
KINDS={'bon','facture','reglement','avoir','immobilisation'}
PDF_TYPES={'bon':{'entree','sortie','livraison','commande'},'facture':{'facture'},'reglement':{'recu'},'avoir':{'avoir'},'immobilisation':{'fiche'}}


def document_parent(actor,kind,object_id,lock=False):
    if kind not in KINDS:raise APIError('Document introuvable.','NOT_FOUND',404)
    require_module(actor,'logistique','read')
    object_id=positive(object_id)
    if kind=='immobilisation':
        record=get_record(model('T_Immobilisation'),actor,{'ID_Immobilisation':object_id},lock=lock)
        parent=record
    elif kind in {'bon','facture'}:
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


def issued_parent_code(kind,record,parent):
    """Référence au moment d'émission, après contrôle du parent et de son périmètre.

    Une date de création absente reste inconnue : la fonction SQL conserve alors
    l'ancienne référence, sans supposer que la date métier prouve l'émission.
    """
    issued_at = record.get('CreeLe')
    if kind == 'facture':
        snapshot = db.one('SELECT "CreeLe" FROM logistique."T_Facture" WHERE "ID_CommandeFk"=%s', [parent['ID_Commande']])
        issued_at = (snapshot or {}).get('CreeLe')
    return db.one('SELECT logistique.fn_code_bon_a_date(%s,%s::timestamptz) AS code',
                  [parent['ID_Commande'],issued_at])['code']


def stock_location_details(parent, entity):
    """Private document context, resolved only after the parent was authorised.

    Depot names are current, like the emitter identity. The links and dates of
    the underlying stock events remain historical and are never rewritten.
    """
    depot_id=parent.get('ID_DepotFk')
    if not depot_id:return []
    depot=db.one('SELECT "CodeDepot","NomDepot" FROM logistique."T_Depot" WHERE "ID_Depot"=%s AND "IdEntiteFk"=%s',[depot_id,entity])
    if not depot:raise APIError('Le dépôt du document doit être vérifié.','DOCUMENT_DEPOT_CONFLICT',409)
    details=[('Dépôt',depot['CodeDepot']+' · '+depot['NomDepot'])]
    transfer_id=parent.get('ID_TransfertDepotFk')
    if transfer_id:
        transfer=db.one('''SELECT t."CodeTransfert",s."CodeDepot" AS source_code,s."NomDepot" AS source_name,
          d."CodeDepot" AS destination_code,d."NomDepot" AS destination_name
          FROM logistique."T_TransfertDepot" t
          JOIN logistique."T_Depot" s ON s."ID_Depot"=t."ID_DepotSourceFk" AND s."IdEntiteFk"=t."IdEntiteFk"
          JOIN logistique."T_Depot" d ON d."ID_Depot"=t."ID_DepotDestinationFk" AND d."IdEntiteFk"=t."IdEntiteFk"
          WHERE t."ID_TransfertDepot"=%s AND t."IdEntiteFk"=%s''',[transfer_id,entity])
        if not transfer:raise APIError('Le transfert du document doit être vérifié.','DOCUMENT_TRANSFER_CONFLICT',409)
        details.extend([('Transfert interne',transfer['CodeTransfert']),('Dépôt source',transfer['source_code']+' · '+transfer['source_name']),
          ('Dépôt destinataire',transfer['destination_code']+' · '+transfer['destination_name'])])
    return details


def document_data(actor,kind,object_id,document_type):
    record,parent,entity=document_parent(actor,kind,object_id)
    if document_type not in PDF_TYPES[kind]:raise APIError('Format de document introuvable.','NOT_FOUND',404)
    if kind=='immobilisation':
        # Une fiche patrimoniale est courante et n'émet aucune facture/mouvement.
        from .entity_documents import current_identity
        row=get_record(view('logistique','V_Immobilisation'),actor,{'ID_Immobilisation':object_id})
        location=' · '.join(str(row[key]) for key in ('Localisation','LocalisationComplement') if row.get(key))
        return {'emitter':current_identity(entity,include_logo=True),'thirdParty':None,'recipient':row.get('Responsable'),
          'currency':row.get('DeviseCode'),'title':'Fiche d’immobilisation','documentType':'fiche',
          'code':row['CodeImmobilisation'],'date':row['DateEntree'],'reference':row.get('Reference'),
          'destination':location,'lines':[{'name':row['NomImmobilisation'],'reference':row.get('NumeroSerie'),
             'quantity':row['Quantite'],'unit':'unité','price':row.get('PrixUnitaire'),'amount':row.get('ValeurAcquisition')}],
          'totals':[] if row.get('ValeurAcquisition') is None else [('Valeur d’acquisition',row['ValeurAcquisition'])],
          'details':[(label,value) for label,value in [('Catégorie',row.get('CategorieMateriel')),('État',row.get('EtatMateriel')),('Service',row.get('Service')),
            ('Date d’acquisition',date_label(row.get('DateAcquisition')) if row.get('DateAcquisition') else None),
            ('Suivi','Bien individuel' if row.get('SuiviIndividuel') else 'Lot homogène'),('Registre','Actif' if row.get('Actif') else 'Archivé')] if value],
          'notes':[str(row[key]) for key in ('Caracteristiques','Observations') if row.get(key)]}
    frozen=identity(kind,object_id,entity)
    currency=record.get('DeviseCode') or db.one('SELECT "DeviseCode" FROM logistique."V_Commande" WHERE "ID_Commande"=%s',[parent['ID_Commande']])['DeviseCode']
    # Le parent a été autorisé avant la lecture du logo privé. Seule la
    # présentation de l'émetteur est courante ; tiers et finance restent figés.
    from .entity_documents import current_identity
    result={'emitter':current_identity(entity,include_logo=True),'thirdParty':frozen.get('IdentiteTiers'),
      'historical':frozen['RepriseHistorique'],'currency':currency,
      'parentCode':parent.get('CodeCmd') if kind=='bon' else issued_parent_code(kind,record,parent),
      'recipient':parent.get('NomClientSaisi'),'reference':parent.get('RefCmd') or parent.get('ReferenceCmd'),
      'destination':parent.get('DestinationLibelle') or parent.get('geolocalisationCmd') or parent.get('LieuLivraison'),'documentType':document_type,'lines':[],'totals':[],'notes':[]}
    if kind=='bon':
        # Le bon préparatoire reste modifiable ; son tiers courant est celui du bon.
        result['thirdParty']=None
        source=get_record(view('logistique','V_Commande'),actor,{'ID_Commande':object_id})
        result['destination']=source.get('DestinationLibelle') or result['destination']
        result['details']=stock_location_details(parent,entity)
        if parent.get('ID_TiersFk'):
            result['thirdParty']=db.one('SELECT * FROM logistique."T_Client" WHERE "ID_Client"=%s AND "IdEntiteFk"=%s',[parent['ID_TiersFk'],entity])
        incoming=source.get('EstCommandeEntree') is True;outgoing=source.get('EstCommandeSortie') is True
        from .order_types import type_context
        order=type_context(parent.get('ID_TypeCmdFk'),required=False)['kind']=='commande'
        if document_type=='commande' and not order or document_type=='entree' and not incoming or document_type in {'sortie','livraison'} and not outgoing:
            raise APIError('Ce type de document ne correspond pas au bon.','DOCUMENT_TYPE_MISMATCH',409)
        result.update({'title':{'entree':'Bon d’entrée','sortie':'Bon de sortie','livraison':'Bon de livraison','commande':'Bon de commande'}[document_type],
          'code':parent.get('CodeCmd'),'date':parent.get('DateCmd')})
        rows=db.query('''SELECT d."ID_ArticleFk",a."NomArticle",a."RefArticle",u."AbrGenerique" AS "Unite",d."QteCmdDetail",d."PUCmdDetail"
          FROM logistique."T_CommandeDetail" d JOIN logistique."T_Article" a ON a."ID_Article"=d."ID_ArticleFk"
          LEFT JOIN referentiel."T_Generique" u ON u."ID_Generique"=a."ID_UniteFk" WHERE d."ID_CmdFk"=%s ORDER BY d."ID_ArticleFk"''',[object_id])
        result['lines']=[{'name':r['NomArticle'],'reference':r['RefArticle'],'quantity':r['QteCmdDetail'],'unit':r['Unite'],'price':r['PUCmdDetail'],'amount':Decimal(str(r['QteCmdDetail']))*Decimal(str(r['PUCmdDetail'])) if r['PUCmdDetail'] is not None else None} for r in rows]
        # The PDF reports the actual allocation of the unique stock movement,
        # never a new FEFO proposal or quantities inferred from current stock.
        allocations=db.query('''SELECT m."ID_ArticleFk",l."NumeroLot",l."DatePeremptionLot",ml."Quantite"
          FROM logistique."T_Mouvement" m JOIN logistique."T_MouvementLot" ml ON ml."ID_MvtFk"=m."ID_Mvt"
          JOIN logistique."T_LotArticle" l ON l."ID_LotArticle"=ml."ID_LotArticleFk"
          WHERE m."ID_cmdFk"=%s ORDER BY m."ID_ArticleFk",l."NumeroLot",l."ID_LotArticle"''',[object_id])
        by_article={}
        for allocation in allocations:
            label='Lot '+allocation['NumeroLot']+' · '+numeric(allocation['Quantite'])
            if allocation.get('DatePeremptionLot'):label+=' · Péremption '+date_label(allocation['DatePeremptionLot'])
            by_article.setdefault(allocation['ID_ArticleFk'],[]).append(label)
        for original,line in zip(rows,result['lines']):
            lot_details=by_article.get(original['ID_ArticleFk'])
            if lot_details:line['reference']='\n'.join(([line['reference']] if line['reference'] else [])+lot_details)
        result['totals']=[('Montant du bon',source.get('MontantTTC'))]
        previous=source.get('AncienCodeCmd')
        if previous and previous!=parent.get('CodeCmd'):
            result['notes'].append('Ancienne référence du bon : '+str(previous))
        if parent.get('ObsCmd'):result['notes'].append(parent['ObsCmd'])
        if document_type=='livraison':result['notes'].append('Réceptionnaire et visa à compléter lors de la remise des articles.')
        if document_type=='commande':result['notes'].append('Document préparatoire. Aucune réception, sortie de stock ou facture n’est constatée par cette commande.')
        if parent.get('ID_TransfertDepotFk'):result['notes'].append('Transfert interne à l’entreprise. Ce bon ne constitue ni une vente ni une facture.')
    elif kind=='facture':
        result.update({'title':'Facture','code':record['CodeFacture'],'date':record['DateFacture'],'dueDate':record.get('DateEcheancePaiement')})
        rows=db.query('SELECT * FROM logistique."T_FactureLigne" WHERE "ID_FactureFk"=%s ORDER BY "ID_ArticleFk"',[record['ID_Facture']])
        result['lines']=[{'name':r['NomArticle'],'reference':r['CodeArticleInterne'],'quantity':r['QteFacturee'],'unit':r['Unite'],'price':r['PUFacture'],'amount':r['MontantLigne']} for r in rows]
        tax_label='TVA ('+numeric(record['TauxTVA'])+' %)' if record.get('TauxTVA') is not None else 'TVA'
        result['totals']=[('Montant HT',record['MontantHT']),(tax_label,record.get('MontantTVA')),('Montant TTC',record['MontantTTC']),('Avoirs imputés',record.get('AvoirImpute',0)),('Réglé',record.get('TotalRegle')),('Reste à régler',record.get('Reste'))]
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
        tax_label='TVA ('+numeric(record['TauxTVA'])+' %)' if record.get('TauxTVA') is not None else 'TVA'
        result['totals']=[('Montant HT',record.get('MontantHT')),(tax_label,record.get('MontantTVA')),('Montant TTC de l’avoir',record['MontantTTC'])]
        result['notes'].append(record['Motif'])
    return result


def render_pdf(data):
    """Modèle A4 commun ; zones mesurées et identité actuelle de l'émetteur.

    Les tableaux peuvent se fractionner dans une ligne longue, leurs titres
    se répètent. En-tête et pied réservent leur hauteur réelle sur chaque page.
    Aucun téléchargement externe ni mutation n'est effectué pendant le rendu.
    """
    import reportlab
    from reportlab.lib import colors
    from reportlab.lib.enums import TA_RIGHT
    from reportlab.lib.styles import ParagraphStyle
    from reportlab.lib.units import mm
    from reportlab.lib.pagesizes import A4
    from reportlab.pdfbase import pdfmetrics
    from reportlab.pdfbase.ttfonts import TTFont
    from reportlab.platypus import BaseDocTemplate,Frame,PageTemplate,Paragraph,Spacer,Table,TableStyle,Image,PageBreak
    from reportlab.pdfgen.canvas import Canvas

    # Polices embarquées, identiques sous Windows et sur le serveur de livraison.
    font_dir=Path(reportlab.__file__).parent/'fonts'
    if 'ERPDocument' not in pdfmetrics.getRegisteredFontNames():
        pdfmetrics.registerFont(TTFont('ERPDocument',str(font_dir/'Vera.ttf')))
        pdfmetrics.registerFont(TTFont('ERPDocumentBold',str(font_dir/'VeraBd.ttf')))
        pdfmetrics.registerFontFamily('ERPDocument',normal='ERPDocument',bold='ERPDocumentBold')
    ink=colors.HexColor('#23364A');muted=colors.HexColor('#596777')
    rule=colors.HexColor('#D9E0E7');pale=colors.HexColor('#F1F4F7')
    styles={
      'body':ParagraphStyle('ERPBody',fontName='ERPDocument',fontSize=10,leading=14,textColor=ink,spaceAfter=0),
      'small':ParagraphStyle('ERPSmall',fontName='ERPDocument',fontSize=8,leading=11,textColor=muted,spaceAfter=0),
      'cell':ParagraphStyle('ERPCell',fontName='ERPDocument',fontSize=9,leading=12,textColor=ink,spaceAfter=0),
      'head':ParagraphStyle('ERPHead',fontName='ERPDocumentBold',fontSize=8,leading=11,textColor=ink,spaceAfter=0),
      'company':ParagraphStyle('ERPCompany',fontName='ERPDocumentBold',fontSize=16,leading=20,textColor=ink,spaceAfter=4),
      'title':ParagraphStyle('ERPTitle',fontName='ERPDocumentBold',fontSize=18,leading=23,textColor=ink,spaceAfter=4),
      'footer':ParagraphStyle('ERPFooter',fontName='ERPDocument',fontSize=7,leading=9,textColor=muted,spaceAfter=0),
    }
    styles['right']=ParagraphStyle('ERPRight',parent=styles['cell'],alignment=TA_RIGHT)
    styles['total']=ParagraphStyle('ERPTotal',parent=styles['right'],fontName='ERPDocumentBold',fontSize=10,leading=14)
    def p(text,style='body'):
        value=str(text if text is not None else '—').replace('\r\n','\n').replace('\r','\n')
        return Paragraph(escape(value).replace('\n','<br/>'),styles[style])
    emitter=data.get('emitter') or {};currency=data.get('currency')
    show_header=emitter.get('AfficherEnteteDocument') is not False
    show_footer=emitter.get('AfficherPiedDocument') is not False
    company=str(emitter.get('NomEntite') or 'Entreprise à renseigner')
    width,height=A4;left=25*mm;right=20*mm;content_width=width-left-right
    top_edge=height-16*mm;bottom_edge=12*mm

    header=None;header_height=0
    if show_header:
        company_lines=[p(company,'company')]
        for key in ('AdresseEntite','PhoneEntite','PhoneSecondaireEntite','EmailEntite','SiteWebEntite'):
            if emitter.get(key):company_lines.append(p(emitter[key],'small'))
        logo=None
        if emitter.get('LogoEntite'):
            # Le fichier normalisé est lu dans la même révision que le profil.
            raw=bytes(emitter['LogoEntite']);logo=Image(io.BytesIO(raw))
            ratio=min(22*mm/logo.imageWidth,22*mm/logo.imageHeight)
            logo.drawWidth=logo.imageWidth*ratio;logo.drawHeight=logo.imageHeight*ratio
            logo.hAlign='LEFT'
        header=Table([[logo or '',company_lines]] if logo else [[company_lines]],
                     colWidths=[28*mm,content_width-28*mm] if logo else [content_width])
        header.setStyle(TableStyle([('VALIGN',(0,0),(-1,-1),'TOP'),('LEFTPADDING',(0,0),(-1,-1),0),
          ('RIGHTPADDING',(0,0),(-1,-1),0),('TOPPADDING',(0,0),(-1,-1),0),('BOTTOMPADDING',(0,0),(-1,-1),5*mm),
          ('LINEBELOW',(0,-1),(-1,-1),.7,rule)]))
        header_height=header.wrap(content_width,height)[1]

    footer=None;footer_height=0
    if show_footer:
        footer_rows=[[p(company,'footer'),'']]
        identifiers=[item for item in emitter.get('IdentifiantsLegauxEntite') or []
                     if isinstance(item,dict) and item.get('libelle') and item.get('valeur')]
        for offset in range(0,len(identifiers),2):
            pair=[p(str(item['libelle'])+' : '+str(item['valeur']),'footer') for item in identifiers[offset:offset+2]]
            footer_rows.append(pair+['']*(2-len(pair)))
        spans=[('SPAN',(0,0),(1,0))]
        if emitter.get('MentionDocumentaireEntite'):
            footer_rows.append([p(emitter['MentionDocumentaireEntite'],'footer'),''])
            spans.append(('SPAN',(0,len(footer_rows)-1),(1,len(footer_rows)-1)))
        footer=Table(footer_rows,colWidths=[content_width/2]*2)
        footer.setStyle(TableStyle(spans+[('VALIGN',(0,0),(-1,-1),'TOP'),('LEFTPADDING',(0,0),(-1,-1),0),
          ('RIGHTPADDING',(0,0),(-1,-1),7),('TOPPADDING',(0,0),(-1,-1),2),('BOTTOMPADDING',(0,0),(-1,-1),2)]))
        footer_height=footer.wrap(content_width,height)[1]

    signatures={
      'entree':['Réceptionné par','Visa du magasinier'],
      'sortie':['Remis par','Reçu par'],
      'livraison':['Livré par','Réceptionnaire / visa'],
      'commande':['Établi par','Bon pour accord'],
      'recu':['Reçu par','Signature'],
    }.get(data.get('documentType'))
    signature_table=None;signature_height=0
    if signatures:
        signature_table=Table([[p(value,'head') for value in signatures],['','']],colWidths=[content_width/2]*2,rowHeights=[None,14*mm])
        signature_table.setStyle(TableStyle([('LINEABOVE',(0,0),(-1,0),.5,rule),('TOPPADDING',(0,0),(-1,0),7),('VALIGN',(0,0),(-1,-1),'TOP')]))
        signature_height=signature_table.wrap(content_width,height)[1]
    top_margin=height-top_edge+(header_height+6*mm if show_header else 0)
    footer_margin=bottom_edge+(footer_height+13*mm if show_footer else 3*mm)
    # Une zone fixe est réservée sous le contenu ; elle n'est dessinée qu'à
    # la dernière page. Les signatures ne repoussent jamais seules une page.
    bottom_margin=footer_margin+(signature_height+6*mm if signatures else 0)
    usable_height=height-top_margin-bottom_margin
    if usable_height<110:
        # Refuser explicitement un profil anormal au lieu de couper les mentions.
        raise APIError('Les coordonnées et mentions sont trop longues pour la mise en page A4. Réduisez-les dans la fiche entreprise.','PDF_PROFILE_TOO_LONG',400)

    story=[]
    if not show_header:
        story.extend([p('Émetteur : '+company,'cell'),Spacer(1,4*mm)])
    story.extend([p(data['title'],'title'),p('N° '+str(data.get('code') or '—'),'body'),Spacer(1,4*mm)])
    details=[('Date et heure',date_label(data.get('date')))]
    if data.get('parentCode') and data['parentCode']!=data.get('code'):details.append(('Bon d’origine',data['parentCode']))
    if data.get('reference'):details.append(('Référence',data['reference']))
    third=data.get('thirdParty') or {}
    recipient=third.get('Nom') or third.get('NomTiers') or third.get('NomClient') or data.get('recipient')
    if recipient:details.append(('Affectataire' if data.get('documentType')=='fiche' else 'Tiers',recipient))
    if data.get('destination'):details.append(('Destination',data['destination']))
    if data.get('dueDate'):details.append(('Échéance',date_label(data['dueDate'])))
    details.extend((label,value) for label,value in data.get('details',[]) if value is not None and value!='')
    detail_rows=[[p(label,'head'),p(value,'cell')] for label,value in details]
    meta=Table(detail_rows,colWidths=[34*mm,content_width-34*mm],splitInRow=1)
    meta.setStyle(TableStyle([('BACKGROUND',(0,0),(-1,-1),pale),('VALIGN',(0,0),(-1,-1),'TOP'),
       ('TOPPADDING',(0,0),(-1,-1),5),('BOTTOMPADDING',(0,0),(-1,-1),5),('LEFTPADDING',(0,0),(-1,-1),9),('RIGHTPADDING',(0,0),(-1,-1),9)]))
    story.extend([meta,Spacer(1,5*mm)])

    receipt=data.get('documentType')=='recu' or data.get('title')=='Reçu de règlement'
    taxable=data.get('documentType') in {'facture','avoir'}
    numbered=data.get('documentType') in {'entree','sortie','livraison','commande'}
    labels=['Désignation','Mode de règlement','Montant'] if receipt else ['Désignation','Quantité','Unité','Prix unitaire HT' if taxable else 'Prix unitaire','Montant HT' if taxable else 'Montant']
    columns=[85*mm,43*mm,37*mm] if receipt else [62*mm,21*mm,16*mm,32*mm,34*mm]
    if numbered:
        labels=['N°',*labels];columns=[10*mm,52*mm,21*mm,16*mm,32*mm,34*mm]
    rows=[[p(label,'head') for label in labels]]
    for position,row in enumerate(data.get('lines',[]),1):
        name=str(row.get('name') or '—')
        if row.get('reference') and not receipt:name+='\n'+str(row['reference'])
        if receipt:
            rows.append([p(name,'cell'),p(row.get('reference'),'cell'),p(money(row.get('amount'),currency),'right')])
        else:
            rows.append(([p(position,'cell')] if numbered else [])+[p(name,'cell'),p(numeric(row.get('quantity')),'right'),p(row.get('unit'),'cell'),
                         p(money(row.get('price'),currency) if row.get('price') is not None else '—','right'),
                         p(money(row.get('amount'),currency),'right')])
    if len(rows)==1:rows.append([p('Aucune ligne','cell')]+['']*(len(labels)-1))
    class DocumentLines(Table):
        def split(self,availWidth,availHeight):
            parts=super().split(availWidth,availHeight)
            # ReportLab peut réessayer le fragment suivant dans le même cadre
            # lorsque des lots allongent une ligne. Son en-tête serait alors
            # dessiné deux fois sur une page : chaque continuation commence
            # explicitement sur la suivante, y compris pour une ligne très longue.
            if len(parts)==2 and all(isinstance(part,Table) for part in parts):
                return [parts[0],PageBreak(),parts[1]]
            return parts
    table=DocumentLines(rows,colWidths=columns,repeatRows=1,splitInRow=1,hAlign='LEFT')
    table.setStyle(TableStyle([('BACKGROUND',(0,0),(-1,0),pale),('ROWBACKGROUNDS',(0,1),(-1,-1),[colors.white,colors.HexColor('#FAFBFC')]),
      ('LINEBELOW',(0,0),(-1,0),.7,rule),('LINEBELOW',(0,1),(-1,-1),.3,rule),('VALIGN',(0,0),(-1,-1),'TOP'),
      ('TOPPADDING',(0,0),(-1,-1),8),('BOTTOMPADDING',(0,0),(-1,-1),8),('LEFTPADDING',(0,0),(-1,-1),8),('RIGHTPADDING',(0,0),(-1,-1),8)]))
    if numbered:table.setStyle(TableStyle([('LEFTPADDING',(0,0),(0,-1),4),('RIGHTPADDING',(0,0),(0,-1),4)]))
    story.extend([table,Spacer(1,5*mm)])
    total_rows=[(label,value) for label,value in data.get('totals',[]) if value is not None]
    if total_rows:
        totals=Table([[p(label,'cell'),p(money(value,currency),'total' if index==len(total_rows)-1 else 'right')]
                       for index,(label,value) in enumerate(total_rows)],colWidths=[65*mm,44*mm],hAlign='RIGHT')
        totals.setStyle(TableStyle([('VALIGN',(0,0),(-1,-1),'TOP'),('TOPPADDING',(0,0),(-1,-1),6),('BOTTOMPADDING',(0,0),(-1,-1),6),
           ('BACKGROUND',(0,-1),(-1,-1),pale),('LINEABOVE',(0,-1),(-1,-1),.7,rule)]))
        story.extend([totals,Spacer(1,5*mm)])
    for note in data.get('notes',[]):
        if note:story.extend([p(note,'small'),Spacer(1,2*mm)])
    def draw_header(canvas,document):
        if header:
            canvas.saveState();header.drawOn(canvas,left,top_edge-header_height);canvas.restoreState()
    class Pages(Canvas):
        def __init__(self,*args,**kwargs):super().__init__(*args,**kwargs);self.states=[]
        def showPage(self):self.states.append(dict(self.__dict__));self._startPage()
        def save(self):
            count=len(self.states)
            for state in self.states:
                self.__dict__.update(state)
                if signature_table and self._pageNumber==count:
                    self.saveState();signature_table.drawOn(self,left,footer_margin+3*mm);self.restoreState()
                if footer:
                    self.saveState();footer.drawOn(self,left,bottom_edge+7*mm)
                    self.setStrokeColor(rule);self.line(left,bottom_edge+footer_height+9*mm,width-right,bottom_edge+footer_height+9*mm)
                    self.setFont('ERPDocument',7);self.setFillColor(muted)
                    self.drawString(left,bottom_edge,str(data.get('code') or 'Document'))
                    self.drawRightString(width-right,bottom_edge,'Page '+str(self._pageNumber)+' sur '+str(count));self.restoreState()
                Canvas.showPage(self)
            Canvas.save(self)
    output=io.BytesIO()
    document=BaseDocTemplate(output,pagesize=A4,leftMargin=left,rightMargin=right,topMargin=top_margin,bottomMargin=bottom_margin,
      title=data['title']+' '+str(data.get('code') or ''),author=company,allowSplitting=True)
    # Sans marges internes implicites de Frame : toutes les zones partagent
    # exactement les mêmes bords, même lorsqu'une ligne se coupe entre pages.
    frame=Frame(left,bottom_margin,content_width,usable_height,leftPadding=0,rightPadding=0,topPadding=0,bottomPadding=0,id='contenu')
    document.addPageTemplates(PageTemplate(id='ERP',frames=frame,onPage=draw_header))
    document.build(story,canvasmaker=Pages)
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
