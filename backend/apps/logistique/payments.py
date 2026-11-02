"""Règlements : parent verrouillé avant écriture, prix exacts et preuves de rejeu transactionnelles."""
import hashlib,hmac,json,re,uuid
from datetime import datetime
from decimal import Decimal
from zoneinfo import ZoneInfo
from django.conf import settings
from django.db import DatabaseError,transaction
from rest_framework.views import APIView
from apps.core import db
from apps.core.module_access import require_module,access_snapshot
from apps.core.permissions import IsERPAdmin
from apps.core.registry import model
from apps.core.repository import positive,coerce,get_record,predicate,audit,clean,set_admin_actor
from apps.core.responses import APIError,ExactEncoder,ok

FIELDS={'ID_TiersFk','CodeFactureFk','ID_ModeReglementFk','ID_ClientFk','DateReglement','MontantRegle','ID_DeviseFk'}
MAX_AMOUNT=Decimal('9999999999.99')


def fail(field,message,code='PAYMENT_VALIDATION',status=400):raise APIError({field:message},code,status)


def digest(data):
    return hashlib.sha256(json.dumps(data,cls=ExactEncoder,ensure_ascii=False,sort_keys=True,separators=(',',':')).encode('utf8')).hexdigest()


def parent_snapshot(actor,command_id):
    obj=model('T_Commande');where,values=predicate(obj,actor,keys={'ID_Commande':positive(command_id)})
    row=db.one('''SELECT to_jsonb(v) AS parent,to_jsonb(f) AS facture,
      NOT EXISTS(SELECT 1 FROM logistique."T_Reglements" p WHERE p."CodeFactureFk"=v."CodeFacture" AND p."ID_DeviseFk" IS DISTINCT FROM v."ID_DeviseFk") AS currency_coherent
      FROM logistique."T_Commande" v LEFT JOIN logistique."V_SuiviReglements" f ON f."ID_Commande"=v."ID_Commande" WHERE '''+where,values)
    if not row:raise APIError('Facture introuvable dans votre périmètre.','NOT_FOUND',404)
    return row


def snapshot(actor,payment_id):
    where,values=predicate(model('T_Reglements'),actor,keys={'ID_Reglement':positive(payment_id)})
    row=db.one('''SELECT to_jsonb(v) AS raw,(to_jsonb(rv)||to_jsonb(v))||jsonb_build_object(
      'ID_Commande',c."ID_Commande",'CodeCmd',c."CodeCmd",'NomClientSaisi',c."NomClientSaisi",'ModeReglement',g."NomGenerique") AS record,
      to_jsonb(c) AS parent,to_jsonb(f) AS facture,
      NOT EXISTS(SELECT 1 FROM logistique."T_Reglements" p WHERE p."CodeFactureFk"=c."CodeFacture" AND p."ID_DeviseFk" IS DISTINCT FROM c."ID_DeviseFk") AS currency_coherent,
      COALESCE(v."CreeParUserFk"::text,(SELECT a."NewData"->'_actor'->>'IdUser' FROM systeme."T_Audit_Log" a WHERE a."TableName"='logistique.T_Reglements'
       AND a."Operation"='CREATE' AND a."NewData"->>'ID_Reglement'=v."ID_Reglement"::text ORDER BY a."IdLog" LIMIT 1)) AS creator
      FROM logistique."T_Reglements" v LEFT JOIN logistique."V_Reglements" rv ON rv."ID_Reglement"=v."ID_Reglement"
      LEFT JOIN logistique."T_Commande" c ON c."CodeFacture"=v."CodeFactureFk"
      LEFT JOIN logistique."V_SuiviReglements" f ON f."ID_Commande"=c."ID_Commande"
      LEFT JOIN referentiel."T_Generique" g ON g."ID_Generique"=v."ID_ModeReglementFk" WHERE '''+where,values)
    if not row:raise APIError('Règlement introuvable dans votre périmètre.','NOT_FOUND',404)
    return row


def revision(row):
    parent=row.get('parent') or {};facture=row.get('facture') or {}
    return digest({'record':row.get('raw'),'parent':{key:parent.get(key) for key in ('ID_Commande','CodeFacture','ID_DeviseFk','ID_ClientFk','ID_TiersFk','IdEntiteFk','StatusFacture')},
      'invoice':{key:facture.get(key) for key in ('ID_Facture','MontantFacture','TotalRegle','Reste')}})


def cash_ready():
    return bool(db.one("SELECT to_regclass('operations.\"V_JournalCaisse\"') IS NOT NULL AS ready")['ready'])


def linked_cash(row,actor):
    payment_id=(row.get('raw') or {}).get('ID_Reglement')
    if not payment_id or not cash_ready():return None
    found=db.one('''SELECT p."IdPaiement",p."CodePaiement",c."NomCaisse",c."CodeCaisse"
      FROM operations."T_Paiement" p JOIN operations."T_Caisse" c ON c."IdCaisse"=p."IdCaisseFk"
      WHERE p."IdReglementFk"=%s''',[payment_id])
    if not found:return None
    # Le rattachement interdit les corrections isolées ; ses détails exigent
    # aussi la licence et les droits du module Caisse.
    return found if access_snapshot(actor).get('modules',{}).get('caisse',{}).get('canRead') else {'linked':True}


def cash_choices(actor,parent):
    if not access_snapshot(actor).get('modules',{}).get('caisse',{}).get('canManage') or not cash_ready():return []
    if parent.get('IdEntiteFk')!=actor.organisation:return []
    return db.query('''SELECT "IdCaisse" AS id,"NomCaisse" AS label,"CodeCaisse" AS code
      FROM operations."T_Caisse" WHERE "IdEntiteFk"=%s AND "IdDeviseFk"=%s AND "Actif" IS TRUE
      ORDER BY "NomCaisse","IdCaisse"''',[parent['IdEntiteFk'],parent.get('ID_DeviseFk')])


def state(row,actor,*,creation=False):
    parent=row.get('parent');facture=row.get('facture') or {};reason=''
    if actor.global_admin and not hasattr(actor,'_context_entity'):
        reason='Choisissez une entreprise avant d’enregistrer un règlement.'
    elif parent and parent.get('IdEntiteFk')!=actor.organisation:
        reason='Cette facture appartient à une autre entreprise.'
    elif not parent or not str(parent.get('CodeFacture') or '').strip() or not facture:
        reason='Ce règlement doit être rattaché à une facture émise.'
    elif parent.get('ID_DeviseFk') is None or row.get('currency_coherent') is not True:
        reason='Les devises de la facture et de ses règlements doivent être rapprochées.'
    elif facture.get('MontantFacture') is None or (not facture.get('EstFactureSnapshot') and parent.get('MontantTTC') is None):
        reason='Le montant historique de cette facture doit être vérifié.'
    elif db.one('SELECT logistique.fn_commande_cloturee(%s) AS closed',[parent.get('StatusFacture')])['closed']:
        reason='Cette facture est clôturée. Ses règlements sont conservés.'
    elif not actor.admin or not access_snapshot(actor)['modules']['logistique']['canManage']:
        reason='Votre rôle ne permet pas de gérer les règlements.'
    elif settings.DB_READ_ONLY:reason='Les écritures sont momentanément indisponibles.'
    if not creation and not reason:
        if linked_cash(row,actor):reason='Ce règlement est lié au journal de caisse et doit être conservé.'
    if not creation and not reason:
        from .credit_notes import ready as credit_ready
        if credit_ready() and db.one('''SELECT EXISTS(SELECT 1 FROM logistique."T_Avoir" WHERE "ID_CommandeFk"=%s) OR EXISTS(SELECT 1 FROM logistique."T_AvoirAffectation" WHERE "ID_CommandeCibleFk"=%s) AS used''',[parent['ID_Commande'],parent['ID_Commande']])['used']:
            reason='Un avoir est lié à cette facture. Le règlement doit être conservé.'
    raw=row.get('raw') or {}
    try:
        remaining=Decimal(str(facture.get('Reste') or '0'));old_amount=Decimal(str(raw.get('MontantRegle') or '0'));invoice_amount=Decimal(str(facture.get('MontantFacture') or '0'))
        if not all(value.is_finite() for value in (remaining,old_amount,invoice_amount)):raise ValueError()
    except (ValueError,ArithmeticError):
        reason=reason or 'Les montants historiques de cette facture doivent être vérifiés.';remaining=old_amount=Decimal('0')
    if not reason and creation and remaining<=0:reason='Cette facture ne présente aucun solde à régler.'
    return {'revision':revision(row),'canCreate':creation and not reason,'canEdit':not creation and not reason,'canDelete':not creation and not reason,
            'reason':reason,'overpaid':remaining<0,'maximumAmount':old_amount if remaining<0 and not creation else max(Decimal('0'),remaining+old_amount)}


def modes(actor,selected=None,*,entity=None,table='T_Reglements',column='ID_ModeReglementFk',lock=False):
    from apps.core.field_references import reference_options,document_reference_actor
    scoped=document_reference_actor(actor,entity)
    rows=reference_options(scoped,'logistique',table,column,current=selected)
    if lock and rows:
        db.query('SELECT g."ID_Generique" FROM referentiel."T_Generique" g JOIN '
            'referentiel."T_CategorieGenerique" c ON c."ID_CategorieGenerique"=g."ID_CategorieGeneriqueFk" '
            'WHERE g."ID_Generique"=ANY(%s::integer[]) FOR SHARE OF g,c',[[row['id'] for row in rows]])
    return [{**row,'active':row['active'] and not row['disabled']} for row in rows]


def record_data(row,actor):
    return clean({**row['record'],'facture':row.get('facture'),'caisse':linked_cash(row,actor),'references':{'reglementModes':modes(actor,row['raw'].get('ID_ModeReglementFk'),entity=(row.get('parent') or {}).get('IdEntiteFk'))}})


def get_payment(actor,payment_id):
    require_module(actor,'logistique')
    row=snapshot(actor,payment_id);meta=state(row,actor)
    meta['createdByUserId']=int(row['creator']) if str(row.get('creator') or '').isdigit() else None
    return record_data(row,actor),meta


def preparation(actor,command_id):
    require_module(actor,'logistique');row=parent_snapshot(actor,command_id);parent=row['parent']
    now=datetime.now(ZoneInfo(settings.TIME_ZONE)).replace(tzinfo=None).isoformat(timespec='seconds')
    data={'facture':row['facture'],'defaults':{'CodeFactureFk':parent.get('CodeFacture'),'ID_DeviseFk':parent.get('ID_DeviseFk'),
      'ID_ClientFk':parent.get('ID_ClientFk'),'ID_TiersFk':parent.get('ID_TiersFk'),'DateReglement':now,'MontantRegle':''},'references':{'reglementModes':modes(actor,entity=parent.get('IdEntiteFk')),'caisses':cash_choices(actor,parent)}}
    return clean(data),state(row,actor,creation=True)


def request_data(body,operation):
    if not isinstance(body,dict) or set(body)-FIELDS-{'_version','requestId'}:fail('reglement','Un champ de ce règlement n’est pas autorisé.')
    try:request_id=str(uuid.UUID(body.get('requestId')))
    except (ValueError,TypeError,AttributeError):fail('requestId','La demande n’est plus valide. Rouvrez la fiche.')
    received=body.get('_version')
    if not isinstance(received,str) or not re.fullmatch('[a-f0-9]{64}',received):fail('_version','Rechargez la facture ou le règlement avant d’enregistrer.','PAYMENT_CONFLICT',409)
    if operation=='delete' and set(body)-{'_version','requestId'}:fail('reglement','La suppression attend seulement sa version et son identifiant de demande.')
    columns={item['column_name']:item for item in model('T_Reglements')['columns']};provided={}
    for key in FIELDS.intersection(body):
        try:provided[key]=coerce(columns[key],body[key])
        except APIError:fail(key,'Vérifiez la valeur ou la précision de ce champ.')
        if key=='DateReglement' and (provided[key] is None or not isinstance(body[key],(str,datetime)) or isinstance(body[key],str) and 'T' not in body[key] or provided[key].tzinfo is not None):
            fail(key,'Indiquez la date et l’heure du règlement, sans changement de fuseau.')
        if isinstance(provided[key],str):
            try:provided[key].encode('utf8')
            except UnicodeError:fail(key,'Indiquez un texte valide.')
    return request_id,received,provided


def mutate_payment(actor,body=None,keys=None,operation='create'):
    db.ensure_writable()
    from apps.core.tenancy import require_entity,assert_document
    require_entity(actor)
    if not actor.admin:raise APIError('Accès réservé aux gestionnaires autorisés.','FORBIDDEN',403)
    require_module(actor,'logistique','manage')
    if operation not in {'create','update','delete'}:raise APIError('Opération de règlement invalide.')
    if keys is not None and (not isinstance(keys,dict) or set(keys)!={'ID_Reglement'}):raise APIError('Clé de règlement non autorisée.')
    payment_id=positive(keys['ID_Reglement']) if keys and set(keys)=={'ID_Reglement'} else None
    if (operation=='create')!=(payment_id is None):raise APIError('Identifiant de règlement incompatible avec cette opération.')
    caisse_id=None
    if isinstance(body,dict) and 'caisseId' in body:
        if operation!='create':fail('caisseId','La caisse ne peut être associée qu’à la création du règlement.')
        raw_cash=body['caisseId']
        if raw_cash not in (None,''):
            if isinstance(raw_cash,bool) or not re.fullmatch(r'[1-9]\d*',str(raw_cash)):fail('caisseId','Choisissez une caisse valide.')
            caisse_id=positive(raw_cash)
        body={key:value for key,value in body.items() if key!='caisseId'}
    request_id,received,provided=request_data(body,operation)
    content={'operation':operation,'ID_Reglement':payment_id,'fields':provided,'actor':actor.pk,'entity':actor.organisation}
    if caisse_id is not None:content['caisseId']=caisse_id
    fingerprint=digest(content)
    with transaction.atomic():
        set_admin_actor(actor)
        db.one('SELECT pg_advisory_xact_lock(hashtextextended(%s,0)) AS locked',['payment:'+str(actor.pk)+':'+request_id])
        proof=db.one('''SELECT "NewData" AS proof FROM systeme."T_Audit_Log" WHERE "TableName"='logistique.T_Reglements'
          AND "Operation" IN ('PAYMENT_CREATE','PAYMENT_UPDATE','PAYMENT_DELETE') AND "NewData"->>'requestId'=%s
          AND "NewData"->'_actor'->>'IdUser'=%s ORDER BY "IdLog" DESC LIMIT 1''',[request_id,str(actor.pk)])
        if proof:
            saved=proof['proof']
            if not isinstance(saved,dict) or saved.get('IdEntiteFk')!=actor.organisation or not hmac.compare_digest(str(saved.get('payloadHash','')).encode('utf8'),fingerprint.encode('ascii')):
                raise APIError('Cette demande a déjà été enregistrée avec d’autres informations. Rouvrez la fiche.','PAYMENT_REPLAY_CONFLICT',409)
            get_record(model('T_Commande'),actor,{'ID_Commande':positive(saved.get('ID_Commande'))},lock=True)
            if operation=='delete':return {'ID_Reglement':saved['ID_Reglement'],'deleted':True,'replayed':True}
            return {**record_data(snapshot(actor,positive(saved.get('ID_Reglement'))),actor),'replayed':True}
        old=get_record(model('T_Reglements'),actor,{'ID_Reglement':payment_id}) if payment_id is not None else None
        code=old.get('CodeFactureFk') if old else provided.get('CodeFactureFk')
        if not isinstance(code,str) or not code.strip():fail('CodeFactureFk','Choisissez une facture émise.')
        parent=get_record(model('T_Commande'),actor,{'CodeFacture':code},lock=True)
        assert_document(actor,parent)
        db.one('SELECT "ID_Commande" FROM logistique."T_Commande" WHERE "ID_Commande"=%s FOR UPDATE',[parent['ID_Commande']])
        if old:
            old=get_record(model('T_Reglements'),actor,{'ID_Reglement':payment_id},lock=True)
            if old.get('CodeFactureFk')!=code:raise APIError('Le rattachement du règlement a changé. Rechargez la fiche.','PAYMENT_CONFLICT',409)
            current=snapshot(actor,payment_id)
        else:current=parent_snapshot(actor,parent['ID_Commande'])
        policy=state(current,actor,creation=old is None)
        if not policy['canCreate' if old is None else 'canDelete' if operation=='delete' else 'canEdit']:
            raise APIError(policy['reason'],'PAYMENT_LOCKED',409)
        if not hmac.compare_digest(policy['revision'],received):raise APIError('La facture ou ses règlements ont changé. Rechargez la fiche.','PAYMENT_CONFLICT',409)
        if 'CodeFactureFk' in provided and provided['CodeFactureFk']!=code:fail('CodeFactureFk','La facture d’un règlement existant doit être conservée.','PAYMENT_PARENT_LOCKED',409)
        if 'ID_DeviseFk' in provided and provided['ID_DeviseFk']!=parent['ID_DeviseFk']:fail('ID_DeviseFk','La devise est celle de la facture.','CURRENCY_MISMATCH',409)
        expected_client=old.get('ID_ClientFk') if old else parent.get('ID_ClientFk')
        expected_tiers=old.get('ID_TiersFk') if old else parent.get('ID_TiersFk')
        if 'ID_TiersFk' in provided and provided['ID_TiersFk']!=expected_tiers:fail('ID_TiersFk','Le tiers est celui de la facture.','PAYMENT_PARENT_LOCKED',409)
        if 'ID_ClientFk' in provided and provided['ID_ClientFk']!=expected_client:fail('ID_ClientFk','Le tiers est celui de la facture ou de l’écriture historique.','PAYMENT_PARENT_LOCKED',409)
        if old and old.get('ID_DeviseFk')!=parent['ID_DeviseFk']:fail('ID_DeviseFk','Les devises de cette écriture doivent être rapprochées.','CURRENCY_MISMATCH',409)
        if operation=='delete':
            row=db.one('DELETE FROM logistique."T_Reglements" WHERE "ID_Reglement"=%s RETURNING *',[payment_id])
        else:
            effective={**(old or {}),**provided}
            if effective.get('DateReglement') is None:fail('DateReglement','Indiquez la date et l’heure du règlement.')
            amount=effective.get('MontantRegle')
            if amount is None or amount<=0:fail('MontantRegle','Indiquez un montant strictement positif dans la devise de la facture.')
            mode=effective.get('ID_ModeReglementFk')
            if mode is None:fail('ID_ModeReglementFk','Choisissez un mode de règlement.')
            if old is None or mode!=old.get('ID_ModeReglementFk'):
                available=modes(actor,entity=parent.get('IdEntiteFk'),lock=True)
                if not any(item['id']==mode and item['active'] for item in available):
                    fail('ID_ModeReglementFk','Ce mode n’est plus disponible. Actualisez la liste.')
            # Même parent verrouillé pour chaque règlement : aucun double encaissement concurrent du solde.
            sums=db.one('SELECT COALESCE(SUM("MontantRegle"),0) AS total FROM logistique."T_Reglements" WHERE "CodeFactureFk"=%s AND (%s::integer IS NULL OR "ID_Reglement"<>%s)',[code,payment_id,payment_id])
            others=Decimal(str(sums['total']));invoice_amount=Decimal(str(current['facture'].get('MontantNetARegler',current['facture']['MontantFacture'])));new_total=others+amount
            if new_total>MAX_AMOUNT:fail('MontantRegle','Le total des règlements dépasse la capacité de la facture.')
            old_total=others+Decimal(str((old or {}).get('MontantRegle') or '0'))
            if new_total>invoice_amount and not (old is not None and old_total>invoice_amount and new_total<old_total):
                fail('MontantRegle','Le montant dépasse le solde à régler. Un excédent historique peut seulement être réduit.','PAYMENT_EXCEEDS_BALANCE',409)
            fields={key:value for key,value in provided.items() if key in {'DateReglement','ID_ModeReglementFk','MontantRegle'}}
            if old is None:
                fields.update(CodeFactureFk=code,ID_DeviseFk=parent['ID_DeviseFk'],ID_ClientFk=expected_client,ID_TiersFk=expected_tiers)
                columns=list(fields);row=db.one('INSERT INTO logistique."T_Reglements" ('+','.join(db.ident(key) for key in columns)+') VALUES ('+','.join(['%s']*len(columns))+') RETURNING *',list(fields.values()))
                if caisse_id is not None:
                    if not cash_ready():fail('caisseId','Le module Caisse doit être installé avant cet encaissement.','CAISSE_UNAVAILABLE',409)
                    from apps.caisse.services import record_reglement
                    try:record_reglement(actor,caisse_id,row,parent,request_id)
                    except DatabaseError as exc:
                        cause=exc.__cause__;state_code=getattr(cause,'sqlstate',None)
                        if state_code in {'40001','40P01','55P03'}:
                            fail('caisseId','La caisse a changé pendant l’enregistrement. Réessayez la même demande.','CAISSE_CONFLICT',409)
                        if state_code in {'P0001','23514','23503','23505','55000'}:
                            message=getattr(getattr(cause,'diag',None),'message_primary','') or ''
                            hint='La date du règlement doit être postérieure à la dernière clôture de cette caisse.' if 'clôture' in message.lower() else 'Vérifiez la date, les références et la disponibilité de cette caisse.'
                            fail('caisseId',hint+' Aucun règlement ni encaissement n’a été enregistré.','CAISSE_CONFLICT',409)
                        raise
            elif fields:row=db.one('UPDATE logistique."T_Reglements" SET '+','.join(db.ident(key)+'=%s' for key in fields)+' WHERE "ID_Reglement"=%s RETURNING *',[*fields.values(),payment_id])
            else:row=old
        # L'image métier avant/après est auditée une seule fois par le trigger SQL.
        # La preuve PAYMENT_* conserve uniquement le rejeu transactionnel de la demande.
        audit(model('T_Reglements'),'PAYMENT_'+operation.upper(),new={'ID_Reglement':row['ID_Reglement'],'ID_Commande':parent['ID_Commande'],
          'requestId':request_id,'payloadHash':fingerprint,'IdEntiteFk':actor.organisation},actor=actor)
        return {'ID_Reglement':row['ID_Reglement'],'deleted':True,'replayed':False} if operation=='delete' else {**record_data(snapshot(actor,row['ID_Reglement']),actor),'replayed':False}


class PaymentPreparationView(APIView):
    permission_classes=[IsERPAdmin]
    http_method_names=['get','options']
    def get(self,request):
        if set(request.query_params)-{'commandeId'}:raise APIError('Critère de préparation non autorisé.')
        data,meta=preparation(request.user,positive(request.query_params.get('commandeId')))
        response=ok(data,meta=meta);response['ETag']='"'+meta['revision']+'"';return response


def batch_error(error,index,fallback='reglement'):
    details=error.detail
    mapped={'reglements.'+str(index)+'.'+str(key):value for key,value in details.items()} if isinstance(details,dict) else {'reglements.'+str(index)+'.'+fallback:details}
    raise APIError(mapped,error.default_code,error.status_code) from error


def batch_data(body):
    if not isinstance(body,dict) or set(body)!={'requestId','reglements'}:fail('reglements','Renseignez le panier de règlements.','PAYMENT_BATCH_VALIDATION')
    try:request_id=str(uuid.UUID(body['requestId']))
    except (ValueError,TypeError,AttributeError):fail('requestId','La demande n’est plus valide. Rouvrez le panier.','PAYMENT_BATCH_VALIDATION')
    rows=body['reglements']
    if not isinstance(rows,list) or not 1<=len(rows)<=50:fail('reglements','Préparez entre 1 et 50 règlements par panier.','PAYMENT_BATCH_VALIDATION')
    result=[];pairs=set();expected={'commandeId','_version','ID_ModeReglementFk','DateReglement','MontantRegle'}
    for index,item in enumerate(rows):
        if not isinstance(item,dict) or set(item)!=expected:
            fail('reglements.'+str(index)+'.reglement','Renseignez la facture, son mode, sa date, son montant et sa version.','PAYMENT_BATCH_VALIDATION')
        try:command_id=positive(item['commandeId'],'Facture')
        except APIError as error:batch_error(error,index,'commandeId')
        # Namespace interne stable ; aucun UUID de ligne n’est accepté du navigateur.
        child_id=str(uuid.uuid5(uuid.UUID(request_id),'payment:'+str(command_id)+':'+str(item['ID_ModeReglementFk'])))
        try:_,version,fields=request_data({'requestId':child_id,**{key:item[key] for key in expected if key!='commandeId'}},'create')
        except APIError as error:batch_error(error,index)
        amount=fields['MontantRegle'];mode=fields['ID_ModeReglementFk']
        if amount is None or amount<=0:fail('reglements.'+str(index)+'.MontantRegle','Indiquez un montant strictement positif.','PAYMENT_BATCH_VALIDATION')
        pair=(command_id,mode)
        if pair in pairs:fail('reglements.'+str(index)+'.ID_ModeReglementFk','Ce mode figure déjà dans le panier pour cette facture.','PAYMENT_BATCH_DUPLICATE')
        pairs.add(pair)
        # Normaliser l’UUID après coercition du mode évite deux namespaces pour 01 et 1.
        child_id=str(uuid.uuid5(uuid.UUID(request_id),'payment:'+str(command_id)+':'+str(mode)))
        result.append({'index':index,'commandeId':command_id,'version':version,'fields':fields,'requestId':child_id})
    return request_id,result


def batch_result(actor,identifiers,*,replayed):
    rows=[]
    for index,identifier in enumerate(identifiers):
        try:rows.append(record_data(snapshot(actor,positive(identifier)),actor))
        except APIError as error:batch_error(error,index)
    return {'reglements':rows,'replayed':replayed}


def mutate_payment_batch(actor,body):
    db.ensure_writable()
    from apps.core.tenancy import require_entity,assert_document
    require_entity(actor)
    if not actor.admin:raise APIError('Accès réservé aux gestionnaires autorisés.','FORBIDDEN',403)
    require_module(actor,'logistique','manage')
    request_id,lines=batch_data(body)
    canonical={'actor':actor.pk,'entity':actor.organisation,'reglements':[{'commandeId':row['commandeId'],**row['fields']} for row in lines]}
    fingerprint=digest(canonical)
    with transaction.atomic():
        set_admin_actor(actor)
        db.one('SELECT pg_advisory_xact_lock(hashtextextended(%s,0)) AS locked',['payment-batch:'+str(actor.pk)+':'+request_id])
        saved=db.one('''SELECT "NewData" AS proof FROM systeme."T_Audit_Log" WHERE "TableName"='logistique.T_Reglements'
          AND "Operation"='PAYMENT_BATCH' AND "NewData"->>'requestId'=%s AND "NewData"->'_actor'->>'IdUser'=%s ORDER BY "IdLog" DESC LIMIT 1''',[request_id,str(actor.pk)])
        if saved:
            proof=saved['proof']
            if not isinstance(proof,dict) or proof.get('IdEntiteFk')!=actor.organisation or not hmac.compare_digest(str(proof.get('payloadHash','')).encode('utf8'),fingerprint.encode('ascii')):
                raise APIError('Cette demande a déjà été enregistrée avec un autre panier. Rouvrez le formulaire.','PAYMENT_BATCH_REPLAY_CONFLICT',409)
            identifiers=proof.get('ID_Reglements')
            if not isinstance(identifiers,list) or len(identifiers)!=len(lines):raise APIError('La preuve de ce panier doit être vérifiée.','PAYMENT_BATCH_REPLAY_CONFLICT',409)
            for command_id in sorted({row['commandeId'] for row in lines}):
                index=next(row['index'] for row in lines if row['commandeId']==command_id)
                try:get_record(model('T_Commande'),actor,{'ID_Commande':command_id},lock=True)
                except APIError as error:batch_error(error,index,'commandeId')
            for index,identifier in enumerate(identifiers):
                try:current=snapshot(actor,positive(identifier))
                except APIError as error:batch_error(error,index)
                if not current.get('parent') or current['parent']['ID_Commande']!=lines[index]['commandeId']:
                    raise APIError('La preuve de ce panier doit être vérifiée.','PAYMENT_BATCH_REPLAY_CONFLICT',409)
            return batch_result(actor,identifiers,replayed=True)
        # Les verrous des UUID enfants précèdent les parents, comme les paiements individuels.
        for child_id in sorted(row['requestId'] for row in lines):
            db.one('SELECT pg_advisory_xact_lock(hashtextextended(%s,0)) AS locked',['payment:'+str(actor.pk)+':'+child_id])
        parents={};snapshots={}
        for command_id in sorted({row['commandeId'] for row in lines}):
            index=next(row['index'] for row in lines if row['commandeId']==command_id)
            try:
                parent=get_record(model('T_Commande'),actor,{'ID_Commande':command_id},lock=True)
                db.one('SELECT "ID_Commande" FROM logistique."T_Commande" WHERE "ID_Commande"=%s FOR UPDATE',[command_id])
                parents[command_id]=parent;snapshots[command_id]=parent_snapshot(actor,command_id)
            except APIError as error:batch_error(error,index,'commandeId')
        # Toutes les versions et les cumuls d’origine sont vérifiés AVANT la première écriture.
        totals={}
        for row in lines:
            index=row['index'];command_id=row['commandeId'];current=snapshots[command_id];policy=state(current,actor,creation=True)
            if not policy['canCreate']:fail('reglements.'+str(index)+'.commandeId',policy['reason'],'PAYMENT_LOCKED',409)
            if not hmac.compare_digest(policy['revision'],row['version']):
                fail('reglements.'+str(index)+'._version','La facture ou ses règlements ont changé. Rechargez cette facture.','PAYMENT_CONFLICT',409)
            totals[command_id]=totals.get(command_id,Decimal('0'))+row['fields']['MontantRegle']
            if totals[command_id]>Decimal(str(current['facture']['Reste'])):
                fail('reglements.'+str(index)+'.MontantRegle','Le cumul préparé dépasse le solde de cette facture.','PAYMENT_EXCEEDS_BALANCE',409)
        # Une preuve enfant sans preuve du groupe ne doit pas devenir un règlement préexistant réutilisé.
        occupied=db.one('''SELECT EXISTS(SELECT 1 FROM systeme."T_Audit_Log" WHERE "TableName"='logistique.T_Reglements'
          AND "Operation"='PAYMENT_CREATE' AND "NewData"->>'requestId'=ANY(%s) AND "NewData"->'_actor'->>'IdUser'=%s) AS present''',[[row['requestId'] for row in lines],str(actor.pk)])
        if occupied['present']:raise APIError('Une demande liée à ce panier existe déjà. Rouvrez le formulaire.','PAYMENT_BATCH_REPLAY_CONFLICT',409)
        identifiers=[]
        for row in lines:
            command_id=row['commandeId'];parent=parents[command_id]
            # Le serveur rafraîchit seulement la version interne, après la validation initiale de TOUS les clients.
            current=parent_snapshot(actor,command_id)
            payload={**row['fields'],'CodeFactureFk':parent['CodeFacture'],'_version':revision(current),'requestId':row['requestId']}
            try:created=mutate_payment(actor,payload)
            except APIError as error:batch_error(error,row['index'])
            identifiers.append(created['ID_Reglement'])
        audit(model('T_Reglements'),'PAYMENT_BATCH',new={'requestId':request_id,'payloadHash':fingerprint,'IdEntiteFk':actor.organisation,
          'ID_Commandes':[row['commandeId'] for row in lines],'ID_Reglements':identifiers},actor=actor)
        # Relecture après la dernière ligne : chaque résultat expose le solde final du groupe.
        return batch_result(actor,identifiers,replayed=False)


class PaymentBatchView(APIView):
    permission_classes=[IsERPAdmin]
    http_method_names=['post','options']
    def post(self,request):
        result=mutate_payment_batch(request.user,request.data)
        return ok(result,status=200 if result['replayed'] else 201,message='Règlements enregistrés.')
