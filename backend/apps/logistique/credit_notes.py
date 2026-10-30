"""Avoirs après restitution facturée, imputation et remboursement exacts et idempotents."""
import hashlib
import hmac
import json
import uuid
from datetime import datetime,timezone
from decimal import Decimal,ROUND_HALF_UP
from django.conf import settings
from django.db import transaction
from rest_framework.views import APIView
from apps.core import db
from apps.core.module_access import require_module
from apps.core.permissions import IsERPAdmin
from apps.core.registry import model
from apps.core.repository import get_record,positive,clean,audit
from apps.core.responses import APIError,ExactEncoder,ok
from apps.core.tenancy import assert_document
from .invoices import returned_quantities,parse_date
from .payments import modes

CENT=Decimal('0.01')

def digest(value):return hashlib.sha256(json.dumps(value,sort_keys=True,separators=(',',':'),cls=ExactEncoder).encode()).hexdigest()
def fail(field,message,code='CREDIT_VALIDATION',status=400):raise APIError({field:message},code,status)
def ready():return bool(db.one('''SELECT to_regclass('logistique."T_Avoir"') IS NOT NULL AS ready''')['ready'])

def amount(value):
    if isinstance(value,bool):fail('Montant','Indiquez un montant positif à deux décimales.')
    try:result=Decimal(str(value))
    except (ArithmeticError,ValueError,TypeError):fail('Montant','Indiquez un montant valide.')
    if not result.is_finite() or result<=0 or result>Decimal('9999999999.99') or result!=result.quantize(CENT):fail('Montant','Indiquez un montant positif à deux décimales.')
    return result

def request_fields(body,fields):
    if not isinstance(body,dict) or set(body)-set(fields)-{'requestId','_version'}:fail('avoir','Un champ de cette demande n’est pas autorisé.')
    try:rid=str(uuid.UUID(body.get('requestId')))
    except (ValueError,AttributeError,TypeError):fail('requestId','La demande doit être renouvelée.')
    version=body.get('_version')
    if not isinstance(version,str) or len(version)!=64:fail('_version','Rechargez la fiche.','CREDIT_CONFLICT',409)
    return rid,version

def authorize(actor,parent):
    db.ensure_writable();require_module(actor,'logistique','manage');assert_document(actor,parent)

def credit_record(actor,credit_id):
    note=db.one('SELECT * FROM logistique."V_Avoir" WHERE "ID_Avoir"=%s',[positive(credit_id)])
    if not note:raise APIError('Avoir introuvable.','NOT_FOUND',404)
    parent=get_record(model('T_Commande'),actor,{'ID_Commande':note['ID_CommandeFk']})
    if parent.get('IdEntiteFk')!=note['IdEntiteFk']:raise APIError('Le rattachement de cet avoir doit être vérifié.','CREDIT_ENTITY_CONFLICT',409)
    return note,parent

def note_details(note):
    key=note['ID_Avoir']
    return {**note,'lignes':db.query('SELECT * FROM logistique."T_AvoirLigne" WHERE "ID_AvoirFk"=%s ORDER BY "ID_ArticleFk"',[key]),
      'affectations':db.query('''SELECT a.*,f."CodeFacture" FROM logistique."T_AvoirAffectation" a JOIN logistique."T_Facture" f ON f."ID_CommandeFk"=a."ID_CommandeCibleFk" WHERE a."ID_AvoirFk"=%s ORDER BY a."ID_Affectation"''',[key]),
      'remboursements':db.query('''SELECT r.*,g."NomGenerique" AS "ModePaiement" FROM logistique."T_Remboursement" r LEFT JOIN referentiel."T_Generique" g ON g."ID_Generique"=r."ID_ModePaiementFk" WHERE r."ID_AvoirFk"=%s ORDER BY r."ID_Remboursement"''',[key])}

def note_revision(note):return digest(note_details(note))

def context(actor,command_id):
    require_module(actor,'logistique','read')
    parent=get_record(model('T_Commande'),actor,{'ID_Commande':positive(command_id)})
    invoice=db.one('SELECT * FROM logistique."T_Facture" WHERE "ID_CommandeFk"=%s',[command_id])
    if not ready():raise APIError('Le service des avoirs est indisponible.','CREDIT_UNAVAILABLE',503)
    notes=db.query('SELECT * FROM logistique."V_Avoir" WHERE "ID_CommandeFk"=%s ORDER BY "ID_Avoir" DESC',[command_id])
    returned=returned_quantities(command_id);pending=[]
    invoice_lines=db.query('SELECT * FROM logistique."T_FactureLigne" WHERE "ID_FactureFk"=%s ORDER BY "ID_ArticleFk"',[invoice['ID_Facture']]) if invoice else []
    credited={r['ID_ArticleFk']:r['quantity'] for r in db.query('''SELECT l."ID_ArticleFk",sum(l."Quantite") AS quantity FROM logistique."T_AvoirLigne" l JOIN logistique."T_Avoir" a ON a."ID_Avoir"=l."ID_AvoirFk" WHERE a."ID_CommandeFk"=%s GROUP BY l."ID_ArticleFk"''',[command_id])}
    for line in invoice_lines:
        quantity=max(Decimal(str(returned.get(line['ID_ArticleFk'],0)))-line['QteRetourAvantFacture']-credited.get(line['ID_ArticleFk'],Decimal('0')),Decimal('0'))
        if quantity:pending.append({'ID_ArticleFk':line['ID_ArticleFk'],'NomArticle':line['NomArticle'],'Unite':line['Unite'],'Quantite':quantity,'PUAvoir':line['PUFacture'],'MontantLigne':(quantity*line['PUFacture']).quantize(CENT,rounding=ROUND_HALF_UP)})
    total=sum((r['MontantLigne'] for r in pending),Decimal('0'))
    manage=bool(actor.admin) and not settings.DB_READ_ONLY
    try:require_module(actor,'logistique','manage');assert_document(actor,parent)
    except APIError:manage=False
    data={'bon':parent,'facture':invoice,'lignesEnAttente':pending,'MontantEnAttente':total,'avoirs':[note_details(n) for n in notes],'references':{'modesPaiement':modes(actor,entity=parent.get('IdEntiteFk'),table='T_Remboursement',column='ID_ModePaiementFk')}}
    revision=digest({'invoice':invoice,'lines':invoice_lines,'returned':sorted(returned.items()),'notes':data['avoirs'],'owner':parent.get('IdEntiteFk')})
    return {'data':data,'meta':{'revision':revision,'canIssue':manage and bool(invoice) and total>0,'canManage':manage,'reason':None if invoice else 'Émettez d’abord la facture du bon.'}}

def replay(table,actor,rid,fingerprint):
    if table not in {'T_Avoir','T_AvoirAffectation','T_Remboursement'}:raise ValueError()
    saved=db.one('SELECT * FROM logistique.'+db.ident(table)+' WHERE "ID_UserFk"=%s AND "RequestId"=%s',[actor.pk,rid])
    if saved and not hmac.compare_digest(str(saved['PayloadHash']),fingerprint):raise APIError('Cette demande a déjà été utilisée avec un autre contenu.','CREDIT_REPLAY_CONFLICT',409)
    return saved

def issue(actor,command_id,body):
    rid,version=request_fields(body,{'DateAvoir','Motif'});command_id=positive(command_id)
    date=parse_date(body.get('DateAvoir'),'DateAvoir');reason=body.get('Motif')
    if not isinstance(reason,str) or not 3<=len(reason.strip())<=2000:fail('Motif','Indiquez le motif de l’avoir.')
    fingerprint=digest({'command':command_id,'actor':actor.pk,'version':version,'date':date,'reason':reason.strip()})
    with transaction.atomic():
        db.ensure_writable();db.one('SELECT pg_advisory_xact_lock(hashtextextended(%s,0))',['credit:'+str(actor.pk)+':'+rid])
        parent=get_record(model('T_Commande'),actor,{'ID_Commande':command_id},lock=True);authorize(actor,parent)
        old=replay('T_Avoir',actor,rid,fingerprint)
        if old:return clean({'avoir':note_details(credit_record(actor,old['ID_Avoir'])[0]),'replayed':True})
        current=context(actor,command_id)
        if not hmac.compare_digest(current['meta']['revision'],version):fail('_version','Les retours ou avoirs ont changé. Rechargez la fiche.','CREDIT_CONFLICT',409)
        if not current['meta']['canIssue']:fail('avoir',current['meta']['reason'] or 'Aucun retour facturé ne reste à créditer.','CREDIT_LOCKED',409)
        invoice=current['data']['facture']
        if date<invoice['DateFacture']:fail('DateAvoir','La date de l’avoir ne peut pas précéder la facture.')
        note=db.one('''INSERT INTO logistique."T_Avoir"("ID_FactureFk","ID_CommandeFk","IdEntiteFk","ID_UserFk","CodeAvoir","DateAvoir","Motif","ID_DeviseFk","DeviseCode","MontantTTC","RequestId","PayloadHash") VALUES(%s,%s,%s,%s,'',%s,%s,%s,%s,%s,%s,%s) RETURNING *''',[invoice['ID_Facture'],command_id,parent['IdEntiteFk'],actor.pk,date,reason.strip(),invoice['ID_DeviseFk'],invoice['DeviseCode'],current['data']['MontantEnAttente'],rid,fingerprint])
        for line in current['data']['lignesEnAttente']:
            db.query('''INSERT INTO logistique."T_AvoirLigne"("ID_AvoirFk","ID_ArticleFk","NomArticle","Unite","Quantite","PUAvoir","MontantLigne") VALUES(%s,%s,%s,%s,%s,%s,%s)''',[note['ID_Avoir'],line['ID_ArticleFk'],line['NomArticle'],line['Unite'],line['Quantite'],line['PUAvoir'],line['MontantLigne']])
        balance=db.one('SELECT "Reste" FROM logistique."V_SuiviReglements" WHERE "ID_Commande"=%s',[command_id])
        allocation=min(note['MontantTTC'],max(balance['Reste'],Decimal('0')))
        if allocation>0:
            db.query('''INSERT INTO logistique."T_AvoirAffectation"("ID_AvoirFk","ID_CommandeCibleFk","Montant","ID_UserFk","RequestId","PayloadHash") VALUES(%s,%s,%s,%s,%s,%s)''',[note['ID_Avoir'],command_id,allocation,actor.pk,str(uuid.uuid5(uuid.UUID(rid),'origin-allocation')),fingerprint])
        audit({'schema':'logistique','name':'T_Avoir'},'CREDIT_ISSUE',new={'ID_Avoir':note['ID_Avoir'],'CodeAvoir':note['CodeAvoir'],'ID_CommandeFk':command_id,'IdEntiteFk':parent['IdEntiteFk'],'MontantTTC':note['MontantTTC'],'ImputeOrigine':allocation,'requestId':rid},actor=actor)
        return clean({'avoir':note_details(credit_record(actor,note['ID_Avoir'])[0]),'replayed':False})

def targets(actor,note,parent):
    if parent.get('ID_TiersFk') is None:return []
    return db.query('''SELECT f."ID_Commande" AS id,f."CodeFacture" AS label,f."Reste",f."DeviseCode" FROM logistique."V_SuiviReglements" f JOIN logistique."T_Commande" c ON c."ID_Commande"=f."ID_Commande" WHERE c."IdEntiteFk"=%s AND c."ID_TiersFk"=%s AND c."ID_DeviseFk"=%s AND f."Reste">0 AND f."EstFactureSnapshot" IS TRUE ORDER BY f."DateFacture",f."ID_Commande" LIMIT 200''',[note['IdEntiteFk'],parent['ID_TiersFk'],note['ID_DeviseFk']])

def settle(actor,credit_id,operation,body):
    fields={'Montant','ID_CommandeCibleFk'} if operation=='affectation' else {'Montant','DateRemboursement','ID_ModePaiementFk','ReferenceRemboursement'}
    rid,version=request_fields(body,fields);value=amount(body.get('Montant'));credit_id=positive(credit_id)
    target=positive(body.get('ID_CommandeCibleFk')) if operation=='affectation' else None
    date=parse_date(body.get('DateRemboursement'),'DateRemboursement') if operation=='remboursement' else None
    mode=positive(body.get('ID_ModePaiementFk')) if operation=='remboursement' else None
    reference=body.get('ReferenceRemboursement') or ''
    if not isinstance(reference,str) or len(reference)>200:fail('ReferenceRemboursement','La référence ne doit pas dépasser 200 caractères.')
    fingerprint=digest({'credit':credit_id,'actor':actor.pk,'operation':operation,'version':version,'value':value,'target':target,'date':date,'mode':mode,'reference':reference})
    with transaction.atomic():
        db.ensure_writable();db.one('SELECT pg_advisory_xact_lock(hashtextextended(%s,0))',['credit-use:'+str(actor.pk)+':'+rid])
        note,parent=credit_record(actor,credit_id);authorize(actor,parent)
        table='T_AvoirAffectation' if target is not None else 'T_Remboursement'
        old=replay(table,actor,rid,fingerprint)
        if old:return clean({'avoir':note_details(credit_record(actor,credit_id)[0]),'replayed':True})
        ids=sorted({parent['ID_Commande'],*([target] if target is not None else [])})
        for command_id in ids:
            current=get_record(model('T_Commande'),actor,{'ID_Commande':command_id},lock=True);assert_document(actor,current)
        note=db.one('SELECT * FROM logistique."V_Avoir" WHERE "ID_Avoir"=%s',[credit_id])
        if not hmac.compare_digest(note_revision(note),version):fail('_version','Le disponible de l’avoir a changé. Rechargez la fiche.','CREDIT_CONFLICT',409)
        if value>note['Disponible']:fail('Montant','Le montant dépasse le disponible de l’avoir.')
        if target is not None:
            if target!=parent['ID_Commande'] and not any(r['id']==target for r in targets(actor,note,parent)):fail('ID_CommandeCibleFk','Choisissez une facture ouverte du même tiers et de la même devise.')
            db.query('''INSERT INTO logistique."T_AvoirAffectation"("ID_AvoirFk","ID_CommandeCibleFk","Montant","ID_UserFk","RequestId","PayloadHash") VALUES(%s,%s,%s,%s,%s,%s)''',[credit_id,target,value,actor.pk,rid,fingerprint])
        else:
            if date<note['DateAvoir']:fail('DateRemboursement','Le remboursement ne peut pas précéder l’avoir.')
            if not any(r['id']==mode and r['active'] for r in modes(actor,entity=parent.get('IdEntiteFk'),table='T_Remboursement',column='ID_ModePaiementFk',lock=True)):
                fail('ID_ModePaiementFk','Choisissez un mode actif de la liste.')
            db.query('''INSERT INTO logistique."T_Remboursement"("ID_AvoirFk","Montant","DateRemboursement","ID_ModePaiementFk","ReferenceRemboursement","ID_UserFk","RequestId","PayloadHash") VALUES(%s,%s,%s,%s,%s,%s,%s,%s)''',[credit_id,value,date,mode,reference or None,actor.pk,rid,fingerprint])
        audit({'schema':'logistique','name':table},'CREDIT_ALLOCATE' if target else 'CREDIT_REFUND',new={'ID_AvoirFk':credit_id,'ID_CommandeCibleFk':target,'Montant':value,'IdEntiteFk':note['IdEntiteFk'],'requestId':rid},actor=actor)
        return clean({'avoir':note_details(credit_record(actor,credit_id)[0]),'replayed':False})


class OrderCreditsView(APIView):
    permission_classes=[IsERPAdmin]
    http_method_names=['get','post','options']
    def get(self,request,pk):
        with transaction.atomic():result=context(request.user,positive(pk))
        return ok(clean(result['data']),meta=clean(result['meta']))
    def post(self,request,pk):
        result=issue(request.user,pk,request.data)
        return ok(result,status=200 if result['replayed'] else 201,message='Avoir émis.')


class CreditView(APIView):
    permission_classes=[IsERPAdmin]
    http_method_names=['get','post','options']
    def get(self,request,pk,operation=None):
        require_module(request.user,'logistique','read')
        with transaction.atomic():
            note,parent=credit_record(request.user,pk);manage=False
            try:authorize(request.user,parent);manage=True
            except APIError:pass
            data={**note_details(note),'references':{'facturesCibles':targets(request.user,note,parent),'modesPaiement':modes(request.user,entity=parent.get('IdEntiteFk'),table='T_Remboursement',column='ID_ModePaiementFk')}}
            revision=note_revision(note)
        return ok(clean(data),meta={'revision':revision,'canManage':manage})
    def post(self,request,pk,operation=None):
        if operation not in {'affectation','remboursement'}:raise APIError('Action introuvable.','NOT_FOUND',404)
        result=settle(request.user,pk,operation,request.data)
        return ok(result,status=200 if result['replayed'] else 201,message='Imputation enregistrée.' if operation=='affectation' else 'Remboursement enregistré.')
