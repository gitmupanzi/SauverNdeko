"""Facturation d’un bon : instantané financier, jamais un second effet de stock."""
import hashlib
import hmac
import json
import re
import uuid
from contextlib import contextmanager
from contextvars import ContextVar
from datetime import datetime, timedelta, timezone
from decimal import Decimal, InvalidOperation
from zoneinfo import ZoneInfo

from django.conf import settings
from django.db import transaction
from rest_framework.views import APIView

from apps.core import db
from apps.core.category_values import category_key
from apps.core.module_access import require_module
from apps.core.permissions import IsERPAdmin
from apps.core.registry import model, view
from apps.core.repository import audit, clean, get_record, mutate, positive
from apps.core.responses import APIError, ExactEncoder, ok
from .document_rules import closed, revision as document_revision
from .order_composer import composition_snapshot
from .stock_returns import return_context, return_storage_ready, return_feature_ready, inventory_adjustment
from .tab_access import MODULE, can_use_tab, mask_order

CENT=Decimal('0.01')
MAX_AMOUNT=Decimal('9999999999.99')
METADATA={'DateFacture','DateEcheancePaiement','ID_ModePaiementFk','ID_ConditionPaiementFk'}
INVOICE_FIELDS=METADATA|{'CodeFacture','DateHeureAutoFacture'}
_invoice_command=ContextVar('invoice_command',default=None)


@contextmanager
def invoice_write_scope(command_id):
    """Autorisation interne bornée à un parent ; aucun drapeau envoyé par le navigateur."""
    token=_invoice_command.set(positive(command_id))
    try:yield
    finally:_invoice_command.reset(token)


def same_value(left,right):
    if left is None or left=='':return right is None or right==''
    if isinstance(right,datetime) and isinstance(left,str):
        try:return parse_date(left,'DateFacture')==right
        except APIError:return False
    if isinstance(right,int) and not isinstance(right,bool):
        return not isinstance(left,bool) and str(left)==str(right)
    return left==right


def protect_invoice_fields(body,old=None):
    """Le CRUD générique conserve les anciens clients, sans permettre d’émettre une facture."""
    scoped=old is not None and _invoice_command.get()==old.get('ID_Commande')
    issued=bool(str((old or {}).get('CodeFacture') or '').strip())
    if 'CodeFacture' in body:
        value=body['CodeFacture']
        if old and same_value(value,old.get('CodeFacture')):body.pop('CodeFacture')
        elif not scoped:
            if old is None and (value is None or isinstance(value,str) and not value.strip()):body.pop('CodeFacture')
            else:raise APIError({'CodeFacture':'La référence de facture est attribuée et conservée par le serveur.'},'INVOICE_CODE_READ_ONLY',400)
        elif issued:raise APIError({'CodeFacture':'La référence de facture est conservée.'},'INVOICE_CODE_READ_ONLY',400)
    if issued and not scoped:
        for field in INVOICE_FIELDS.intersection(body):
            if not same_value(body[field],old.get(field)):
                raise APIError({field:'Utilisez la fiche de facturation pour modifier cette information.'},'INVOICE_METADATA_READ_ONLY',409)
            body.pop(field)


def storage_ready():
    row=db.one('''SELECT to_regclass('logistique."T_Facture"') IS NOT NULL
        AND to_regclass('logistique."T_FactureLigne"') IS NOT NULL
        AND to_regclass('logistique."V_Facture"') IS NOT NULL
        AND to_regclass('logistique."V_FactureLigne"') IS NOT NULL
        AND to_regprocedure('logistique.fn_facturation_tva(integer)') IS NOT NULL
        AND (SELECT count(*)=9 FROM pg_trigger WHERE NOT tgisinternal AND tgenabled<>'D'
          AND tgname IN ('facture_protection','facture_ligne_protection','facture_snapshot_coherent','facture_ligne_coherente','facture_bon_protection',
                        'facture_detail_protection','facture_mouvement_protection','facture_mouvement_lot_protection','facture_lot_identite')
          AND tgrelid IN (to_regclass('logistique."T_Facture"'),to_regclass('logistique."T_FactureLigne"'),
            to_regclass('logistique."T_Commande"'),to_regclass('logistique."T_CommandeDetail"'),to_regclass('logistique."T_Mouvement"'),
            to_regclass('logistique."T_MouvementLot"'),to_regclass('logistique."T_LotArticle"'))) AS ready''')
    return bool(row and row['ready']) and return_feature_ready()


def invoice_error(field,message,code='INVOICE_VALIDATION',status=400):
    raise APIError({field:message},code,status)


def parse_date(value,field):
    if not isinstance(value,str) or not value.strip():invoice_error(field,'Indiquez la date et l’heure.')
    try:
        result=datetime.fromisoformat(value.replace('Z','+00:00'))
        # Une date seule ne représente pas l’heure de la facture.
        if 'T' not in value and ' ' not in value:raise ValueError()
        if result.tzinfo is None:result=result.replace(tzinfo=ZoneInfo(settings.TIME_ZONE))
        return result.astimezone(timezone.utc)
    except (ValueError,OverflowError):invoice_error(field,'Indiquez une date et une heure valides.')


def delay_days(label,abbreviation=None):
    """Seuls les jours écrits explicitement sont un délai ; un identifiant ne l’est jamais."""
    values=[]
    for value in (label,abbreviation):
        match=re.fullmatch(r'\s*(\d{1,4})\s+jours?\s*',str(value or ''),re.IGNORECASE)
        if match:values.append(int(match.group(1)))
    return values[0] if values and len(set(values))==1 else None


def request_data(body):
    allowed={'requestId','_version',*METADATA}
    if not isinstance(body,dict) or set(body)-allowed:invoice_error('facture','Un champ de cette facture n’est pas autorisé.')
    try:request_id=str(uuid.UUID(body.get('requestId')))
    except (ValueError,TypeError,AttributeError):invoice_error('requestId','La demande n’est plus valide. Rouvrez la fiche.')
    version=body.get('_version')
    if not isinstance(version,str) or not re.fullmatch('[a-f0-9]{64}',version):invoice_error('_version','Rechargez la facture avant de l’enregistrer.','INVOICE_CONFLICT',409)
    values={'DateFacture':parse_date(body.get('DateFacture'),'DateFacture')}
    for key in ('ID_ModePaiementFk','ID_ConditionPaiementFk'):
        value=body.get(key)
        if value is None or value=='':values[key]=None
        else:
            try:values[key]=positive(value)
            except APIError:invoice_error(key,'Choisissez une valeur de la liste.')
    due=body.get('DateEcheancePaiement')
    values['DateEcheancePaiement']=None if due is None or due=='' else parse_date(due,'DateEcheancePaiement')
    return {'requestId':request_id,'_version':version,'values':values}


def request_hash(actor,command_id,data,operation):
    canonical={'commandId':command_id,'actorId':actor.pk,'entityId':actor.organisation,
               'operation':operation,'version':data['_version'],'values':data['values']}
    return hashlib.sha256(json.dumps(canonical,cls=ExactEncoder,sort_keys=True,separators=(',',':')).encode('utf8')).hexdigest()


def payment_references(selected=None,lock=False,actor=None):
    selected=selected or {}
    from apps.core.field_references import reference_options,document_reference_actor
    actor=document_reference_actor(actor,selected.get('IdEntiteFk'))
    result={}
    for key,field in [('modesPaiement','ID_ModePaiementFk'),('conditionsPaiement','ID_ConditionPaiementFk')]:
        rows=reference_options(actor,'logistique','T_Commande',field,current=selected.get(field))
        if lock and rows:
            db.query('SELECT g."ID_Generique" FROM referentiel."T_Generique" g JOIN '
                'referentiel."T_CategorieGenerique" c ON c."ID_CategorieGenerique"=g."ID_CategorieGeneriqueFk" '
                'WHERE g."ID_Generique"=ANY(%s::integer[]) FOR SHARE OF g,c',[[row['id'] for row in rows]])
        result[key]=[{**row,'active':row['active'] and not row['disabled'],
                      **({'delayDays':delay_days(row['name'],row['abbr'])} if key=='conditionsPaiement' else {})} for row in rows]
    return result


def resolve_metadata(data,references,previous=None):
    values=dict(data['values']);previous=previous or {}
    condition=None
    for field,list_key in (('ID_ModePaiementFk','modesPaiement'),('ID_ConditionPaiementFk','conditionsPaiement')):
        if values[field] is None:continue
        item=next((row for row in references[list_key] if row['id']==values[field]),None)
        if not item or not item['active'] and values[field]!=previous.get(field):
            invoice_error(field,'Cette référence n’est plus disponible. Actualisez la liste.')
        if field=='ID_ConditionPaiementFk':condition=item
    days=condition['delayDays'] if condition else None
    # Un renommage du référentiel ne réécrit pas le délai d’une facture existante.
    if previous and all(same_value(values[field],previous.get(field))
                        for field in ('DateFacture','ID_ConditionPaiementFk','DateEcheancePaiement')):
        days=previous.get('DelaiJours')
    if values['DateEcheancePaiement'] is None:
        if days is None:invoice_error('DateEcheancePaiement','Indiquez l’échéance ; aucun délai explicite n’est défini.')
        try:values['DateEcheancePaiement']=values['DateFacture']+timedelta(days=days)
        except OverflowError:invoice_error('DateEcheancePaiement','L’échéance calculée dépasse les dates autorisées.')
    if values['DateEcheancePaiement']<values['DateFacture']:
        invoice_error('DateEcheancePaiement','L’échéance ne peut pas précéder la facture.')
    values['DelaiJours']=days
    return values


def exact(value,label):
    try:result=Decimal(str(value))
    except (InvalidOperation,ValueError,TypeError):raise APIError('Vérifiez '+label+'.','INVOICE_SOURCE_INVALID',409)
    if not result.is_finite():raise APIError('Vérifiez '+label+'.','INVOICE_SOURCE_INVALID',409)
    return result


def returned_quantities(command_id):
    if not return_storage_ready():return {}
    rows=db.query('''SELECT d."ID_ArticleFk",SUM(d."QteCmdDetail") AS quantity
        FROM logistique."T_RetourBon" r JOIN logistique."T_CommandeDetail" d
        ON d."ID_CmdFk"=r."ID_CommandeRetourFk"
        WHERE r."ID_CommandeOrigineFk"=%s GROUP BY d."ID_ArticleFk"''',[command_id])
    return {row['ID_ArticleFk']:exact(row['quantity'],'les quantités retournées') for row in rows}


def candidate_lines(snapshot,returned):
    lines=[];total=Decimal('0')
    for row in snapshot['lignes']:
        article=row.get('article')
        if not article:raise APIError('Un article de ce bon est hors de votre périmètre.','INVOICE_SOURCE_FORBIDDEN',403)
        quantity=exact(row.get('QteCmdDetail'),'les quantités du bon')
        price=exact(row.get('PUCmdDetail'),'les prix unitaires du bon')
        back=returned.get(row['ID_ArticleFk'],Decimal('0'))
        if quantity<=0 or quantity!=quantity.quantize(Decimal('0.001')) or price<0 or price!=price.quantize(CENT) or not 0<=back<=quantity:
            raise APIError('Les lignes et leurs retours doivent être vérifiés avant facturation.','INVOICE_SOURCE_INVALID',409)
        from .quantities import line_amount
        net=quantity-back;amount=line_amount(net,price);total+=amount
        lines.append({'ID_ArticleFk':row['ID_ArticleFk'],'NomArticle':article.get('NomArticle'),
            'CodeArticleInterne':article.get('CodeArticleInterne'),'Unite':article.get('AbrUnite') or article.get('NomUnite'),
            'QteSortie':quantity,'QteRetourAvantFacture':back,'QteFacturee':net,
            'PUFacture':price,'MontantLigne':amount,'DeviseCode':snapshot['bon'].get('DeviseCode')})
    if total>MAX_AMOUNT:raise APIError('Le montant net dépasse la capacité d’une facture.','INVOICE_AMOUNT_LIMIT',409)
    return lines,total


def snapshot_invoice(command_id):
    row=db.one('SELECT * FROM logistique."V_Facture" WHERE "ID_CommandeFk"=%s',[command_id])
    lines=db.query('SELECT * FROM logistique."V_FactureLigne" WHERE "ID_CommandeFk"=%s ORDER BY "ID_ArticleFk"',[command_id]) if row else []
    return row,lines


def invoice_revision(snapshot,invoice,lines,returned,taxes=None):
    fields=[column['column_name'] for column in model('T_Commande')['columns']]
    canonical={'bon':{field:snapshot['bon'].get(field) for field in fields},
               'lines':[{key:row.get(key) for key in ('ID_ArticleFk','QteCmdDetail','PUCmdDetail')} for row in snapshot['lignes']],
               'returns':sorted(returned.items()),'invoice':invoice,'snapshotLines':lines,'owner':snapshot['owner_entity'],
               'taxes':taxes}
    return hashlib.sha256(json.dumps(canonical,cls=ExactEncoder,sort_keys=True,separators=(',',':')).encode('utf8')).hexdigest()


def context(actor,command_id):
    snapshot=composition_snapshot(actor,command_id)
    parent=snapshot['bon'];ready=storage_ready();returned=returned_quantities(command_id)
    issued,lines=snapshot_invoice(command_id) if ready else (None,[])
    if issued and not actor.global_admin and issued['IdEntiteFk']!=actor.organisation:
        raise APIError('Facture introuvable dans votre organisation.','NOT_FOUND',404)
    legacy=bool(str(parent.get('CodeFacture') or '').strip()) and not issued
    refs=payment_references(issued or parent,actor=actor)
    source_reason='';candidates=[];net=Decimal('0')
    try:candidates,net=candidate_lines(snapshot,returned)
    except APIError as error:source_reason=str(error.detail)
    if ready and not source_reason and not issued:
        coherence=db.one('SELECT EXISTS(SELECT 1 FROM logistique."V_RetourArticle" WHERE "ID_CommandeOrigineFk"=%s AND NOT "SourceCoherente") AS invalid',[command_id])
        if coherence['invalid']:source_reason='Rapprochez les lignes et mouvements du bon avant facturation.'
    returns=return_context(command_id)
    kind=db.one('SELECT logistique.fn_nature_bon(%s) AS nature',[parent.get('ID_TypeCmdFk')])
    outgoing = bool(kind and category_key(kind['nature']) == 'sortie')
    owner=bool(actor.organisation) and snapshot['owner_entity']==actor.organisation and (not issued or issued['IdEntiteFk']==actor.organisation)
    manage=bool(actor.admin) and not settings.DB_READ_ONLY and can_use_tab(actor,MODULE,'factures','manage')
    reason=('La facturation sera disponible après installation de son socle.' if not ready else
            'Vous ne disposez pas du droit de facturation.' if not manage else
            'Ce bon appartient à une autre organisation.' if not owner else
            'Ce bon est clôturé.' if closed(parent) else
            'Un transfert interne ne crée pas de facture ni de règlement.' if parent.get('ID_TransfertDepotFk') else
            'Un bon de stock initial ou de reprise ne peut pas être facturé.' if parent.get('OrigineBon') in {'stock_initial','reprise_mouvement'} else
            'Un bon d’inventaire ne peut pas être facturé.' if inventory_adjustment(command_id) else
            'Un bon de retour ne peut pas être facturé.' if returns['isReturn'] else
            'La facturation concerne les bons de sortie.' if not outgoing else
            'Cette facture historique nécessite une reprise contrôlée.' if legacy else source_reason)
    payments=db.one('''SELECT COUNT(*) AS count,COALESCE(SUM("MontantRegle"),0) AS total
        FROM logistique."T_Reglements" WHERE "CodeFactureFk"=%s''',[parent.get('CodeFacture')])
    if not issued and not reason:
        if not parent.get('ID_DeviseFk'):reason='Renseignez la devise du bon avant facturation.'
        elif not candidates or net<=0:reason='Aucun montant net positif ne reste à facturer.'
    edit_reason=reason or ('Un règlement existe. Les informations de la facture sont conservées.' if payments['count'] else '')
    if legacy:
        issued={key:parent.get(key) for key in ('CodeFacture',*METADATA,'ID_DeviseFk','DeviseCode')}
        issued.update({'ID_Facture':None,'ID_CommandeFk':command_id,'legacy':True,'MontantHT':parent.get('MontantHT'),
            'MontantTTC':parent.get('MontantTTC'),'MontantFacture':parent.get('MontantTTC'),
            'TotalRegle':payments['total'],'Reste':exact(parent.get('MontantTTC') or 0,'le montant')-payments['total']})
        lines=candidates
    elif issued:issued={**issued,'legacy':False}
    display_lines=lines if issued else candidates
    if issued:
        taxes={field:issued.get(field) for field in ('TauxTVA','MontantHT','MontantTVA','MontantTTC')}
    elif ready:
        # Le calcul, l'arrondi par ligne et le taux de l'entreprise sont ceux
        # que le trigger conservera à l'émission. Aucun recalcul navigateur.
        taxes=db.one('SELECT * FROM logistique.fn_facturation_tva(%s)',[command_id])
        if not taxes:raise APIError('La préparation fiscale de la facture est indisponible.','INVOICE_TAX_UNAVAILABLE',503)
        if taxes['MontantTTC']>MAX_AMOUNT:
            reason=reason or 'Le montant TTC dépasse la capacité d’une facture.'
            edit_reason=edit_reason or reason
    else:
        taxes={'TauxTVA':None,'MontantHT':net,'MontantTVA':None,'MontantTTC':None}
    total=taxes['MontantTTC']
    credit=[]
    from .credit_notes import ready as credit_ready,context as credit_context
    credit_state=credit_context(actor,command_id)['data'] if issued and not legacy and credit_ready() else None
    if credit_state and (credit_state['avoirs'] or issued.get('AvoirImpute',0)):
        edit_reason=edit_reason or 'Un avoir existe. Les informations de la facture sont conservées.'
    if issued and not legacy:
        for line in lines:
            after=max(returned.get(line['ID_ArticleFk'],Decimal('0'))-exact(line['QteRetourAvantFacture'],'les retours'),0)
            if after:
                credit.append({'ID_ArticleFk':line['ID_ArticleFk'],'NomArticle':line['NomArticle'],
                    'Quantite':after,'MontantLigne':(after*exact(line['PUFacture'],'le prix')).quantize(CENT)})
    if credit_state is not None:
        credit=credit_state['lignesEnAttente']
    now=datetime.now(timezone.utc)
    defaults={key:(issued or parent).get(key) for key in METADATA}
    defaults['DateFacture']=defaults.get('DateFacture') or now
    for key in ('DateFacture','DateEcheancePaiement'):
        if isinstance(defaults.get(key),str):defaults[key]=parse_date(defaults[key],key)
    due_condition=next((row for row in refs['conditionsPaiement'] if row['id']==defaults['ID_ConditionPaiementFk']),None)
    if defaults['DateEcheancePaiement'] is None and due_condition and due_condition['delayDays'] is not None:
        try:defaults['DateEcheancePaiement']=defaults['DateFacture']+timedelta(days=due_condition['delayDays'])
        except OverflowError:pass
    return {'data':{'bonOrigine':mask_order(actor,parent),'facture':mask_order(actor,issued,invoices=True) if issued else None,
        'lignes':display_lines,'references':refs,'defaults':defaults,
        'totaux':{'MontantBon':parent.get('MontantTTC'),'MontantFacture':total,**taxes,'DeviseCode':parent.get('DeviseCode')},
        'retoursApresEmission':{'required':bool(credit),'MontantAvoir':sum((line.get('MontantTTC',line['MontantLigne']) for line in credit),Decimal('0')),
                              'DeviseCode':parent.get('DeviseCode'),'lignes':credit}},
        'meta':{'available':ready,'canIssue':not issued and not reason,'canEdit':bool(issued) and not edit_reason,
                'reason':edit_reason if issued else reason,'revision':invoice_revision(snapshot,issued,display_lines,returned,taxes)},
        'snapshot':snapshot,'candidates':candidates}


def generate_invoice_code(command_id):
    """Référence canonique du bon facturé ; aucune consommation de séquence de commande."""
    from django.db import DatabaseError
    command_id=positive(command_id)
    try:
        row=db.one('SELECT logistique.fn_code_facture(%s) AS code',[command_id])
        code=row.get('code') if isinstance(row,dict) else None
        if not isinstance(code,str) or not code or code.strip()!=code or len(code)>255:raise ValueError()
    except (DatabaseError,ValueError,TypeError):
        raise APIError('La numérotation des factures est indisponible. Contactez votre administrateur.','INVOICE_NUMBERING_UNAVAILABLE',503)
    return code


def write_invoice(actor,command_id,body,operation):
    db.ensure_writable()
    if not actor.admin:raise APIError('Accès réservé aux gestionnaires autorisés.','FORBIDDEN',403)
    require_module(actor,'logistique','manage')
    from apps.core.tenancy import require_entity,assert_document
    require_entity(actor)
    command_id=positive(command_id);data=request_data(body);fingerprint=request_hash(actor,command_id,data,operation)
    with transaction.atomic():
        db.one('SELECT pg_advisory_xact_lock(hashtextextended(%s,0)) AS locked',['invoice:'+str(actor.pk)+':'+data['requestId']])
        raw=get_record(model('T_Commande'),actor,{'ID_Commande':command_id},lock=True)
        assert_document(actor,raw)
        if not storage_ready():raise APIError('Le socle de facturation n’est pas encore installé.','INVOICE_UNAVAILABLE',503)
        proof=db.one('''SELECT "NewData" AS proof FROM systeme."T_Audit_Log"
            WHERE "TableName"='logistique.T_Facture' AND "Operation" IN ('INVOICE_ISSUE','INVOICE_UPDATE')
              AND "NewData"->>'requestId'=%s AND "NewData"->'_actor'->>'IdUser'=%s
            ORDER BY "IdLog" DESC LIMIT 1''',[data['requestId'],str(actor.pk)])
        if proof:
            saved=proof['proof']
            if not isinstance(saved,dict) or saved.get('ID_CommandeFk')!=command_id or saved.get('IdEntiteFk')!=actor.organisation or not hmac.compare_digest(str(saved.get('payloadHash','')).encode(),fingerprint.encode()):
                raise APIError('Cette demande a déjà été utilisée avec d’autres informations.','INVOICE_REPLAY_CONFLICT',409)
            invoice,_=snapshot_invoice(command_id)
            if not invoice or invoice['ID_Facture']!=saved.get('ID_Facture'):
                raise APIError('La preuve de facturation doit être vérifiée.','INVOICE_REPLAY_CONFLICT',409)
            return clean({'facture':mask_order(actor,{**invoice,'legacy':False},invoices=True),
                          'bonOrigine':mask_order(actor,get_record(view('logistique','V_Commande'),actor,{'ID_Commande':command_id})),
                          'replayed':True})
        if operation=='issue':
            # Une mise à jour du profil ne peut pas changer le taux entre le
            # contrôle de révision et l'instantané financier PostgreSQL.
            db.one('SELECT "IdEntite" FROM systeme."T_Entite" WHERE "IdEntite"=%s FOR SHARE',[raw['IdEntiteFk']])
        current=context(actor,command_id);meta=current['meta']
        if not hmac.compare_digest(meta['revision'],data['_version']):
            raise APIError('Le bon, ses retours, sa facture ou le taux de TVA ont changé. Rechargez la fiche.','INVOICE_CONFLICT',409)
        action='canIssue' if operation=='issue' else 'canEdit'
        if not meta[action]:raise APIError(meta['reason'] or 'Cette opération n’est plus disponible.','INVOICE_LOCKED',409)
        previous=current['data']['facture']
        references=payment_references(previous or raw,lock=True,actor=actor)
        values=resolve_metadata(data,references,previous)
        if operation=='issue':
            # La devise appartient au bon, jamais au prix actuel du catalogue.
            db.one('SELECT logistique.fn_verifier_devise(%s) AS checked',[raw['ID_DeviseFk']])
            code=generate_invoice_code(command_id);totals=current['data']['totaux']
            snapshot=current['snapshot']['bon']
            invoice=db.one('''INSERT INTO logistique."T_Facture"
                ("ID_CommandeFk","CodeFacture","ID_UserFk","IdEntiteFk","RequestId","PayloadHash",
                 "DateFacture","DateEcheancePaiement","ID_ModePaiementFk","ID_ConditionPaiementFk","DelaiJours",
                 "ID_DeviseFk","DeviseCode","DeviseLibelle","MontantHT","MontantTTC")
                VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s) RETURNING *''',
                [command_id,code,actor.pk,actor.organisation,data['requestId'],fingerprint,values['DateFacture'],values['DateEcheancePaiement'],
                 values['ID_ModePaiementFk'],values['ID_ConditionPaiementFk'],values['DelaiJours'],raw['ID_DeviseFk'],
                 snapshot.get('DeviseCode'),snapshot.get('DeviseLibelle'),totals['MontantHT'],totals['MontantTTC']])
            for line in current['candidates']:
                if not line['QteFacturee']:continue
                db.query('''INSERT INTO logistique."T_FactureLigne"
                    ("ID_FactureFk","ID_CmdFk","ID_ArticleFk","NomArticle","CodeArticleInterne","Unite",
                     "QteSortie","QteRetourAvantFacture","QteFacturee","PUFacture","MontantLigne")
                    VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)''',
                    [invoice['ID_Facture'],command_id,line['ID_ArticleFk'],line['NomArticle'],line['CodeArticleInterne'],line['Unite'],
                     line['QteSortie'],line['QteRetourAvantFacture'],line['QteFacturee'],line['PUFacture'],line['MontantLigne']])
        else:
            code=previous['CodeFacture']
            invoice=db.one('''UPDATE logistique."T_Facture" SET "DateFacture"=%s,"DateEcheancePaiement"=%s,
                "ID_ModePaiementFk"=%s,"ID_ConditionPaiementFk"=%s,"DelaiJours"=%s,"ModifieLe"=clock_timestamp()
                WHERE "ID_CommandeFk"=%s RETURNING *''',
                [values['DateFacture'],values['DateEcheancePaiement'],values['ID_ModePaiementFk'],values['ID_ConditionPaiementFk'],values['DelaiJours'],command_id])
        mirror={key:values[key] for key in METADATA}
        mirror.update({'CodeFacture':code,'_version':document_revision(raw)})
        with invoice_write_scope(command_id):mutate('T_Commande',actor,mirror,{'ID_Commande':command_id},operation='update')
        audit({'schema':'logistique','name':'T_Facture'},'INVOICE_ISSUE' if operation=='issue' else 'INVOICE_UPDATE',
              old=previous,new={'ID_Facture':invoice['ID_Facture'],'ID_CommandeFk':command_id,'CodeFacture':code,
                 'requestId':data['requestId'],'payloadHash':fingerprint,'IdEntiteFk':actor.organisation,
                 **{key:invoice.get(key) for key in ('TauxTVA','MontantHT','MontantTVA','MontantTTC')},
                 **{key:values[key] for key in METADATA}},actor=actor)
        issued,_=snapshot_invoice(command_id)
        return clean({'facture':mask_order(actor,{**issued,'legacy':False},invoices=True),
                      'bonOrigine':mask_order(actor,get_record(view('logistique','V_Commande'),actor,{'ID_Commande':command_id})),
                      'replayed':False})


class InvoiceView(APIView):
    permission_classes=[IsERPAdmin]
    http_method_names=['get','post','put','options']

    def get(self,request,pk):
        require_module(request.user,'logistique','read')
        with transaction.atomic():result=context(request.user,positive(pk))
        return ok(clean(result['data']),meta=clean(result['meta']))

    def post(self,request,pk):
        result=write_invoice(request.user,pk,request.data,'issue')
        return ok(result,status=200 if result['replayed'] else 201,message='Facture enregistrée.')

    def put(self,request,pk):
        return ok(write_invoice(request.user,pk,request.data,'update'),message='Facture mise à jour.')
