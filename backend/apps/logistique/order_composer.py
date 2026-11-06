"""Création atomique d’un bon et de son panier, avec preuve de rejeu dans l’audit existant."""
import hashlib
import hmac
import json
import uuid
from datetime import timezone
from decimal import Decimal
from zoneinfo import ZoneInfo

from django.conf import settings
from django.db import DatabaseError, transaction
from rest_framework.views import APIView

from apps.core import db
from apps.core.module_access import require_module
from apps.core.permissions import IsERPAdmin
from apps.core.registry import model, view
from apps.core.repository import audit, clean, coerce, get_record, mutate, positive, predicate
from apps.core.responses import APIError, ExactEncoder, ok
from .lots import normalize as normalize_lots
from .order_types import type_context, reject_order_lots
from .quantities import quantity as exact_quantity, line_amount
from .services import mutate_line

MAX_LINES=50
MAX_AMOUNT=Decimal('9999999999.99')
HEADER_GENERATED={'IdEntiteFk','ID_Commande','DateHeureAutoCmd','DateHeureAutoFacture','MontantHT','MontantTTC','MontantRegleFacture','MontantResteFacture'}


def composition_error(field,message,code='COMPOSITION_VALIDATION',status=400):
    raise APIError({field:message},code,status)


def mapped_error(error,prefix):
    if error.status_code>=500:raise error
    details=error.detail
    fields={prefix+'.'+str(key):value for key,value in details.items()} if isinstance(details,dict) else {prefix:details}
    raise APIError(fields,error.default_code,error.status_code) from error


def database_error(error,prefix):
    state=getattr(error.__cause__,'sqlstate',None)
    if state not in {'P0001','23514','23503','23505','55P03','40P01','22003'}:raise error
    message='Ce bon ne peut pas être enregistré. Vérifiez ses références et son code.' if prefix=='bon' else 'Stock, lots ou montant incompatibles. Vérifiez cette ligne.'
    composition_error(prefix,message,'COMPOSITION_CONFLICT',409)


def typed(column,value,field,*,preserve_text=False):
    if not preserve_text and isinstance(value,str) and column['data_type'] in {'text','character varying','character'}:
        value=value.strip() or None
    try:
        value=coerce(column,value)
        if isinstance(value,str):value.encode('utf8')
    except (APIError,UnicodeError):composition_error(field,'Vérifiez la valeur et le format de ce champ.')
    if column['data_type'].startswith('timestamp') and value is not None:
        if column['data_type']=='timestamp with time zone' and value.tzinfo is None:
            value=value.replace(tzinfo=ZoneInfo(settings.TIME_ZONE))
    return value


def composition_data(actor,body,old=None,old_lines=None,*,max_lines=MAX_LINES):
    expected={'requestId','bon','lignes'} | ({'_version'} if old is not None else set())
    if not isinstance(body,dict) or set(body)!=expected:
        composition_error('bon','Renseignez le bon et son panier.')
    try:request_id=str(uuid.UUID(body['requestId']))
    except (ValueError,TypeError,AttributeError):composition_error('requestId','La demande n’est plus valide. Rouvrez le formulaire.')
    raw_header,raw_lines=body['bon'],body['lignes']
    header_columns={column['column_name']:column for column in model('T_Commande')['columns'] if column['column_name'] not in HEADER_GENERATED}
    if not isinstance(raw_header,dict) or set(raw_header)-set(header_columns):
        composition_error('bon','Un champ du bon n’est pas autorisé.')
    if not isinstance(raw_lines,list) or not (0 if old is not None else 1)<=len(raw_lines)<=max_lines:
        composition_error('lignes',f'Indiquez au maximum {max_lines} articles distincts.' if old is not None else f'Ajoutez entre 1 et {max_lines} articles distincts.')
    header={key:typed(column,raw_header.get(key,(old or {}).get(key)), 'bon.'+key) for key,column in header_columns.items() if key!='ID_UserFk'}
    expected_owner=old.get('ID_UserFk') if old is not None else actor.pk
    try:owner=positive(raw_header.get('ID_UserFk',expected_owner),'Responsable')
    except APIError:composition_error('bon.ID_UserFk','Le responsable est le compte connecté.')
    if owner!=expected_owner:composition_error('bon.ID_UserFk','Le responsable initial du bon doit être conservé.','COMPOSITION_OWNER',403)
    header['ID_UserFk']=owner
    from apps.core.tenancy import require_entity
    header['IdEntiteFk']=require_entity(actor)
    for key in ('ID_TypeCmdFk','ID_DeviseFk'):
        try:header[key]=positive(header[key])
        except APIError:composition_error('bon.'+key,'Choisissez une valeur de la liste.')
    if header['DateCmd'] is None:composition_error('bon.DateCmd','Indiquez la date et l’heure du bon.')
    line_columns={column['column_name']:column for column in model('T_CommandeDetail')['columns'] if column['column_name']!='ID_CmdFk'}
    nature=type_context(header["ID_TypeCmdFk"])
    outgoing=nature['kind']=='sortie'
    lines=[];seen=set();total=Decimal('0');total_quantity=0
    for index,item in enumerate(raw_lines):
        prefix='lignes.'+str(index)
        if not isinstance(item,dict) or set(item)-set(line_columns)-{'Lots'}:
            composition_error(prefix,'Un champ de cette ligne n’est pas autorisé.')
        previous_input=next((row for row in (old_lines or []) if str(row['ID_ArticleFk'])==str(item.get('ID_ArticleFk'))),None)
        line={key:typed(column,item.get(key),prefix+'.'+key,preserve_text=previous_input is not None and item.get(key)==previous_input.get(key)) for key,column in line_columns.items()}
        try:identifier=positive(line['ID_ArticleFk'],'Article')
        except APIError:composition_error(prefix+'.ID_ArticleFk','Choisissez un article.')
        if identifier in seen:composition_error(prefix+'.ID_ArticleFk','Cet article figure déjà dans le panier.')
        seen.add(identifier);line['ID_ArticleFk']=identifier
        quantity,price=line['QteCmdDetail'],line['PUCmdDetail']
        try:quantity=exact_quantity(quantity,'QteCmdDetail')
        except APIError as error:mapped_error(error,prefix)
        if price is None or price<0:
            composition_error(prefix+'.PUCmdDetail','Renseignez le prix unitaire dans la devise du bon. Le prix peut être nul.')
        line['QteCmdDetail']=quantity;line['PUCmdDetail']=price.quantize(Decimal('0.01'))
        total_quantity+=line['QteCmdDetail']
        if total_quantity>99999999999:composition_error(prefix+'.QteCmdDetail','La quantité cumulée dépasse la capacité de ce bon.')
        total+=line_amount(line['QteCmdDetail'],line['PUCmdDetail'])
        if total>MAX_AMOUNT:composition_error(prefix+'.PUCmdDetail','Le total du bon dépasse 9 999 999 999,99 dans sa devise.')
        raw_lots=item.get('Lots',[])
        try:
            if nature['kind']=='commande':reject_order_lots(raw_lots)
            # Les anciennes ventilations partielles sont conservables, jamais étendues silencieusement.
            if old is not None and isinstance(raw_lots,list):
                lot_sum=sum(exact_quantity(lot.get('Quantite'),'Quantite') for lot in raw_lots if isinstance(lot,dict))
                lots=normalize_lots(raw_lots,lot_sum)
                if lot_sum>line['QteCmdDetail']:raise APIError('La ventilation dépasse la quantité de cette ligne.')
                previous=next((row for row in (old_lines or []) if row['ID_ArticleFk']==identifier),None)
                if lots and lot_sum!=line['QteCmdDetail'] and not outgoing and (previous is None or Decimal(str(previous.get('QteCmdDetail'))) != quantity or lot_signature(lots)!=lot_signature(previous.get('Lots',[]))):
                    raise APIError('Répartissez la quantité entière entre les lots de la ligne modifiée.')
            else:lots=normalize_lots(raw_lots,line['QteCmdDetail'],allow_partial=outgoing)
        except APIError as error:mapped_error(error,prefix+'.Lots')
        line['Lots']=[{**lot,'DatePeremptionLot':lot['DatePeremptionLot'].isoformat() if lot['DatePeremptionLot'] else None} for lot in lots]
        lines.append({'index':index,'data':line})
    result={'requestId':request_id,'bon':header,'lignes':lines}
    if old is not None:result['_providedHeader']={key:header[key] for key in raw_header}
    return result


def composition_hash(actor,data):
    header={key:(value.astimezone(timezone.utc).isoformat() if getattr(value,'tzinfo',None) else value) for key,value in data['bon'].items()}
    lines=[]
    for item in sorted(data['lignes'],key=lambda item:item['data']['ID_ArticleFk']):
        line={**item['data'],'Lots':sorted(item['data']['Lots'],key=lambda lot:lot['NumeroLot'].casefold())}
        lines.append(line)
    canonical={'bon':header,'lignes':lines,'IdUser':actor.pk,'IdEntiteFk':actor.organisation}
    return hashlib.sha256(json.dumps(canonical,cls=ExactEncoder,ensure_ascii=False,sort_keys=True,separators=(',',':')).encode('utf8')).hexdigest()


def article_contexts(actor,lines,*,active=True):
    owners={}
    for item in sorted(lines,key=lambda item:item['data']['ID_ArticleFk']):
        prefix='lignes.'+str(item['index'])+'.ID_ArticleFk'
        try:article=get_record(model('T_Article'),actor,{'ID_Article':item['data']['ID_ArticleFk']},lock=True)
        except APIError as error:mapped_error(error,prefix)
        from apps.core.tenancy import assert_document
        assert_document(actor,article)
        if article['IdEntiteFk']!=actor.organisation:
            composition_error(prefix,'Choisissez un article de votre organisation.','COMPOSITION_ORGANISATION',403)
        if active and article.get('ValideArticle') is not True:
            composition_error(prefix,'Cet article est inactif. Actualisez le catalogue.','ARTICLE_INACTIVE',409)


def composition_result(actor,command_id,lines,*,replayed):
    bon=get_record(view('logistique','V_Commande'),actor,{'ID_Commande':command_id})
    obj=view('logistique','V_CommandeDetail')
    where,values=predicate(obj,actor,keys={'ID_CmdFk':command_id})
    ids=sorted(item['data']['ID_ArticleFk'] for item in lines)
    rows=db.query('SELECT v.* FROM '+db.qualified(obj['schema'],obj['name'])+' v WHERE '+where+
                  ' AND v."ID_ArticleFk"=ANY(%s) ORDER BY v."ID_ArticleFk"',[*values,ids])
    return clean({'bon':bon,'lignes':rows,'replayed':replayed})


def compose_order(actor,body,*,max_lines=MAX_LINES):
    db.ensure_writable()
    if not actor.admin:raise APIError('Accès réservé aux gestionnaires autorisés.','FORBIDDEN',403)
    require_module(actor,'logistique','manage')
    data=composition_data(actor,body,max_lines=max_lines)
    fingerprint=composition_hash(actor,data)
    operation_key='compose:'+str(actor.pk)+':'+data['requestId']
    with transaction.atomic():
        db.one('SELECT pg_advisory_xact_lock(hashtextextended(%s,0)) AS locked',[operation_key])
        proof=db.one('''SELECT "NewData" AS proof FROM systeme."T_Audit_Log"
            WHERE "TableName"='logistique.T_Commande' AND "Operation"='COMPOSE'
              AND "NewData"->>'requestId'=%s AND "NewData"->'_actor'->>'IdUser'=%s
            ORDER BY "IdLog" DESC LIMIT 1''',[data['requestId'],str(actor.pk)])
        if proof:
            saved=proof['proof']
            if not isinstance(saved,dict) or saved.get('IdEntiteFk')!=actor.organisation or not hmac.compare_digest(str(saved.get('payloadHash','')).encode('utf8'),fingerprint.encode('ascii')):
                raise APIError('Cette demande a déjà été enregistrée avec un autre panier. Rouvrez le formulaire.','COMPOSITION_REPLAY_CONFLICT',409)
            command_id=positive(saved.get('ID_Commande'))
            command=get_record(model('T_Commande'),actor,{'ID_Commande':command_id},lock=True)
            if command.get('ID_UserFk')!=actor.pk:
                raise APIError('Ce bon n’appartient plus au contexte de cette demande.','COMPOSITION_OWNER',403)
            article_contexts(actor,data['lignes'],active=False)
            return composition_result(actor,command_id,data['lignes'],replayed=True)
        header=dict(data['bon'])
        # Le canonique historique conserve CodeCmd pour les anciens rejeux, jamais pour une nouvelle attribution.
        if header.pop('CodeCmd',None) is not None:
            composition_error('bon.CodeCmd','Le code du bon est attribué automatiquement.','ORDER_CODE_READ_ONLY',400)
        try:command=mutate('T_Commande',actor,header,operation='create')
        except APIError as error:mapped_error(error,'bon')
        except DatabaseError as error:database_error(error,'bon')
        article_contexts(actor,data['lignes'])
        for item in sorted(data['lignes'],key=lambda item:item['data']['ID_ArticleFk']):
            try:mutate_line(actor,command['ID_Commande'],item['data'])
            except APIError as error:mapped_error(error,'lignes.'+str(item['index']))
            except DatabaseError as error:database_error(error,'lignes.'+str(item['index']))
        audit(model('T_Commande'),'COMPOSE',new={'ID_Commande':command['ID_Commande'],'requestId':data['requestId'],
              'payloadHash':fingerprint,'IdEntiteFk':actor.organisation},actor=actor)
        return composition_result(actor,command['ID_Commande'],data['lignes'],replayed=False)


class OrderComposerView(APIView):
    permission_classes=[IsERPAdmin]
    http_method_names=['post','options']

    def post(self,request):
        result=compose_order(request.user,request.data)
        return ok(result,status=200 if result['replayed'] else 201,message='Bon de stock enregistré.')


def lot_signature(lots):
    return sorted((str(row['NumeroLot']).casefold(),Decimal(str(row['Quantite'])),
                   row.get('DatePeremptionLot').isoformat() if hasattr(row.get('DatePeremptionLot'),'isoformat') else row.get('DatePeremptionLot'),str(row.get('MotifDerogationPeremption') or '').strip())
                  for row in lots)


def line_signature(line):
    fields=[column['column_name'] for column in model('T_CommandeDetail')['columns'] if column['column_name']!='ID_CmdFk']
    values={key:line.get(key) for key in fields}
    for key in ('QteCmdDetail','PUCmdDetail'):
        if values[key] is not None:values[key]=Decimal(str(values[key]))
    return values,lot_signature(line.get('Lots',[]))


def composition_snapshot(actor,command_id):
    """En-tête brut, lignes et lots exhaustifs d’un même snapshot SQL ; aucun plafond de pagination."""
    obj=model('T_Commande')
    where,values=predicate(obj,actor,keys={'ID_Commande':command_id})
    article_where,article_values=predicate(view('logistique','V_Article'),actor)
    article_where=article_where.replace('v.','a.')
    from .stock_returns import return_storage_ready
    returns=("(SELECT COALESCE(jsonb_agg(jsonb_build_object('id',r.\"ID_RetourBon\",'source',r.\"ID_CommandeOrigineFk\",'retour',r.\"ID_CommandeRetourFk\") ORDER BY r.\"ID_RetourBon\"),'[]'::jsonb) FROM logistique.\"T_RetourBon\" r WHERE r.\"ID_CommandeOrigineFk\"=v.\"ID_Commande\" OR r.\"ID_CommandeRetourFk\"=v.\"ID_Commande\")"
             if return_storage_ready() else "'[]'::jsonb")
    invoice_ready=db.one("SELECT to_regclass('logistique.\"T_Facture\"') IS NOT NULL AS ready")['ready']
    invoice=('EXISTS(SELECT 1 FROM logistique."T_Facture" f WHERE f."ID_CommandeFk"=v."ID_Commande")' if invoice_ready else 'FALSE')
    row=db.one('''WITH parent AS MATERIALIZED (
            SELECT v.* FROM logistique."T_Commande" v WHERE '''+where+'''
        ), details AS MATERIALIZED (
            SELECT d.* FROM logistique."T_CommandeDetail" d
            WHERE d."ID_CmdFk"=(SELECT "ID_Commande" FROM parent)
        ), projected_details AS MATERIALIZED (
            SELECT dv."ID_ArticleFk",to_jsonb(dv) AS data
            FROM logistique."V_CommandeDetail" dv
            WHERE dv."ID_CmdFk"=(SELECT "ID_Commande" FROM parent)
        ), articles AS MATERIALIZED (
            SELECT a."ID_Article",to_jsonb(a) AS data
            FROM logistique."V_Article" a
            WHERE a."ID_Article"=ANY(ARRAY(SELECT "ID_ArticleFk" FROM details))
              AND '''+article_where+'''
        ), lots AS MATERIALIZED (
            SELECT m."ID_ArticleFk",jsonb_agg(jsonb_build_object(
                'ID_LotArticle',lot."ID_LotArticle",'NumeroLot',lot."NumeroLot",
                'DatePeremptionLot',lot."DatePeremptionLot",'Quantite',ml."Quantite",
                'MotifDerogationPeremption',ml."MotifDerogationPeremption")
                ORDER BY lot."NumeroLot",lot."ID_LotArticle") AS data
            FROM logistique."T_Mouvement" m JOIN logistique."T_MouvementLot" ml ON ml."ID_MvtFk"=m."ID_Mvt"
            JOIN logistique."T_LotArticle" lot ON lot."ID_LotArticle"=ml."ID_LotArticleFk"
            WHERE m."ID_cmdFk"=(SELECT "ID_Commande" FROM parent)
            GROUP BY m."ID_ArticleFk"
        )
        SELECT (to_jsonb(cv)||to_jsonb(v)) AS bon,v."IdEntiteFk" AS owner_entity,
            (SELECT COALESCE(jsonb_agg((COALESCE(dv.data,'{}'::jsonb)||to_jsonb(d))||
                jsonb_build_object('Lots',COALESCE(l.data,'[]'::jsonb),'article',a.data)
                ORDER BY d."ID_ArticleFk"),'[]'::jsonb)
             FROM details d
             LEFT JOIN projected_details dv USING ("ID_ArticleFk")
             LEFT JOIN articles a ON a."ID_Article"=d."ID_ArticleFk"
             LEFT JOIN lots l USING ("ID_ArticleFk")) AS lignes,
            '''+returns+' AS retours,'+invoice+''' AS snapshot_invoice
        FROM parent v LEFT JOIN logistique."V_Commande" cv ON cv."ID_Commande"=v."ID_Commande"''',
        [*values,*article_values])
    if not row:raise APIError('Objet introuvable dans votre périmètre.','NOT_FOUND',404)
    return row


def composition_revision(snapshot):
    header={column['column_name']:snapshot['bon'].get(column['column_name']) for column in model('T_Commande')['columns']}
    lines=[]
    for line in snapshot['lignes']:
        lines.append({**{column['column_name']:line.get(column['column_name']) for column in model('T_CommandeDetail')['columns']},
                      'Lots':[{key:lot.get(key) for key in ('ID_LotArticle','NumeroLot','DatePeremptionLot','Quantite')} for lot in line.get('Lots',[])]})
    canonical={'bon':header,'lignes':lines,'retours':snapshot['retours'],'facture':snapshot['snapshot_invoice'],'organisation':snapshot['owner_entity']}
    return hashlib.sha256(json.dumps(canonical,cls=ExactEncoder,sort_keys=True,ensure_ascii=False,separators=(',',':')).encode('utf8')).hexdigest()


def edit_line_limit(snapshot):
    return max(MAX_LINES,len(snapshot['lignes']))


def composition_metadata(snapshot,actor):
    from .document_rules import stock_write_state,usage
    state=stock_write_state(snapshot['bon'])
    rights=usage(snapshot['bon'],actor)
    from apps.core.module_access import access_snapshot
    can_manage=access_snapshot(actor)['modules']['logistique']['canManage']
    reason=state['reason'] or ('Ce bon appartient à une autre organisation.' if snapshot['owner_entity']!=actor.organisation else
                              'Votre rôle ne permet pas de modifier les bons.' if not can_manage else
                              'Les écritures sont momentanément indisponibles.' if settings.DB_READ_ONLY else '')
    return {'revision':composition_revision(snapshot),'canEdit':not reason,'reason':reason,'maxLines':edit_line_limit(snapshot),
            'canChangeType':rights['canChangeType'] and not reason,'canChangeCurrency':rights['canChangeCurrency'] and not reason,
            **type_context(snapshot['bon'].get('ID_TypeCmdFk'),required=False)}


def edit_composition_hash(actor,data,command_id):
    normalized={**data,'bon':data['_providedHeader']}
    return hashlib.sha256((str(command_id)+':'+composition_hash(actor,normalized)).encode('ascii')).hexdigest()


def update_composition(actor,command_id,body):
    db.ensure_writable()
    if not actor.admin:raise APIError('Accès réservé aux gestionnaires autorisés.','FORBIDDEN',403)
    require_module(actor,'logistique','manage')
    command_id=positive(command_id)
    if not isinstance(body,dict):composition_error('bon','Objet JSON attendu.')
    try:request_id=str(uuid.UUID(body.get('requestId')))
    except (ValueError,TypeError,AttributeError):composition_error('requestId','La demande n’est plus valide. Rouvrez le formulaire.')
    with transaction.atomic():
        db.one('SELECT pg_advisory_xact_lock(hashtextextended(%s,0)) AS locked',['compose-update:'+str(actor.pk)+':'+request_id])
        current=get_record(model('T_Commande'),actor,{'ID_Commande':command_id},lock=True)
        snapshot=composition_snapshot(actor,command_id)
        from apps.core.tenancy import assert_document
        assert_document(actor,current)
        if current['IdEntiteFk']!=actor.organisation:
            composition_error('bon','Ce bon appartient à une autre organisation.','COMPOSITION_ORGANISATION',403)
        data=composition_data(actor,body,old=current,old_lines=snapshot['lignes'],
                              max_lines=edit_line_limit(snapshot))
        fingerprint=edit_composition_hash(actor,data,command_id)
        proof=db.one('''SELECT "NewData" AS proof FROM systeme."T_Audit_Log"
            WHERE "TableName"='logistique.T_Commande' AND "Operation"='COMPOSE_UPDATE'
              AND "NewData"->>'requestId'=%s AND "NewData"->'_actor'->>'IdUser'=%s
            ORDER BY "IdLog" DESC LIMIT 1''',[request_id,str(actor.pk)])
        if proof:
            saved=proof['proof']
            if not isinstance(saved,dict) or saved.get('ID_Commande')!=command_id or saved.get('IdEntiteFk')!=actor.organisation or not hmac.compare_digest(str(saved.get('payloadHash','')).encode('utf8'),fingerprint.encode('ascii')):
                raise APIError('Cette demande a déjà été enregistrée avec un autre panier. Rouvrez le formulaire.','COMPOSITION_REPLAY_CONFLICT',409)
            return composition_result(actor,command_id,data['lignes'],replayed=True)
        from .document_rules import assert_stock_editable,revision,protect_command_code
        assert_stock_editable(current)
        if not isinstance(body.get('_version'),str) or not hmac.compare_digest(composition_revision(snapshot),body['_version']):
            raise APIError('Le bon, ses lignes ou ses lots ont changé. Rechargez le panier avant d’enregistrer.','COMPOSITION_CONFLICT',409)
        # Les identités historiques sont conservées, même si le panier transmis ne les contient pas.
        patch=dict(data['_providedHeader'])
        protect_command_code(patch,current)
        patch.pop('ID_UserFk',None)
        patch.pop('IdEntiteFk',None)
        existing={row['ID_ArticleFk']:row for row in snapshot['lignes']}
        requested={item['data']['ID_ArticleFk']:item for item in data['lignes']}
        # Verrouiller tous les articles une seule fois, dans l’ordre, avant la première écriture.
        context_lines=[{'index':requested[identifier]['index'] if identifier in requested else 0,'data':{'ID_ArticleFk':identifier}}
                       for identifier in sorted(set(existing)|set(requested))]
        article_contexts(actor,context_lines,active=False)
        for identifier,item in requested.items():
            old=existing.get(identifier)
            if old is not None and line_signature(old)==line_signature(item['data']):continue
            article=get_record(model('T_Article'),actor,{'ID_Article':identifier})
            if article.get('ValideArticle') is not True:
                composition_error('lignes.'+str(item['index'])+'.ID_ArticleFk','Cet article est inactif. Conservez la ligne ou retirez-la du panier.','ARTICLE_INACTIVE',409)
        try:mutate('T_Commande',actor,{**patch,'_version':revision(current)},keys={'ID_Commande':command_id},operation='update')
        except APIError as error:mapped_error(error,'bon')
        except DatabaseError as error:database_error(error,'bon')
        # Retirer et diminuer avant d’augmenter : la limite porte sur le panier final, pas un état intermédiaire artificiel.
        for identifier in sorted(set(existing)-set(requested)):
            old=existing[identifier]
            try:mutate_line(actor,command_id,{'_version':revision(old,'ligne')},identifier,'delete')
            except APIError as error:mapped_error(error,'lignes')
            except DatabaseError as error:database_error(error,'lignes')
        changed=[item for identifier,item in requested.items() if identifier not in existing or line_signature(existing[identifier])!=line_signature(item['data'])]
        def priority(item):
            old=existing.get(item['data']['ID_ArticleFk']);new=item['data']
            old_amount=Decimal(str(old.get('QteCmdDetail') or 0))*Decimal(str(old.get('PUCmdDetail') or 0)) if old else Decimal('0')
            return (0 if old and new['QteCmdDetail']*new['PUCmdDetail']<=old_amount else 1,new['ID_ArticleFk'])
        for item in sorted(changed,key=priority):
            line=dict(item['data']);identifier=line['ID_ArticleFk'];old=existing.get(identifier)
            if old:
                line['_version']=revision(old,'ligne')
                if lot_signature(old.get('Lots',[]))==lot_signature(line['Lots']):line.pop('Lots')
            try:mutate_line(actor,command_id,line,identifier if old else None,'update' if old else 'create')
            except APIError as error:mapped_error(error,'lignes.'+str(item['index']))
            except DatabaseError as error:database_error(error,'lignes.'+str(item['index']))
        audit(model('T_Commande'),'COMPOSE_UPDATE',new={'ID_Commande':command_id,'requestId':request_id,'payloadHash':fingerprint,'IdEntiteFk':actor.organisation},actor=actor)
        return composition_result(actor,command_id,data['lignes'],replayed=False)


class OrderCompositionView(APIView):
    permission_classes=[IsERPAdmin]
    http_method_names=['get','put','options']

    def get(self,request,pk):
        require_module(request.user,'logistique')
        snapshot=composition_snapshot(request.user,positive(pk))
        return ok(clean({'bon':snapshot['bon'],'lignes':snapshot['lignes']}),meta=composition_metadata(snapshot,request.user))

    def put(self,request,pk):
        result=update_composition(request.user,pk,request.data)
        return ok(result,message='Bon de stock enregistré.')
