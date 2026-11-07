"""Liaisons de retours physiques : lecture des protections, sans effet de stock."""
from apps.core import db


def inventory_adjustment(command_id):
    return bool(db.one('SELECT logistique.fn_bon_inventaire(%s) AS linked',[command_id])['linked'])


def return_storage_ready():
    return bool(db.one("SELECT to_regclass('logistique.\"T_RetourBon\"') IS NOT NULL AS ready")['ready'])


def return_context(command_id):
    if not return_storage_ready():
        return {'available':False,'isReturn':False,'hasReturns':False,'originId':None,'returnIds':[]}
    rows=db.query('''SELECT "ID_CommandeOrigineFk","ID_CommandeRetourFk" FROM logistique."T_RetourBon"
        WHERE "ID_CommandeOrigineFk"=%s OR "ID_CommandeRetourFk"=%s ORDER BY "ID_RetourBon"''',[command_id,command_id])
    origin=next((row['ID_CommandeOrigineFk'] for row in rows if row['ID_CommandeRetourFk']==command_id),None)
    children=[row['ID_CommandeRetourFk'] for row in rows if row['ID_CommandeOrigineFk']==command_id]
    return {'available':True,'isReturn':origin is not None,'hasReturns':bool(children),'originId':origin,'returnIds':children}


# Cette portée interne ne peut être déclenchée par un champ de requête.
from contextlib import contextmanager
from contextvars import ContextVar
_return_line_context=ContextVar('historical_return_line',default=None)


@contextmanager
def _historical_line_scope(command_id,article_ids):
    token=_return_line_context.set((command_id,frozenset(article_ids)))
    try:yield
    finally:_return_line_context.reset(token)


def is_historical_return_line(command_id,article_id):
    scope=_return_line_context.get()
    return bool(scope and scope[0]==command_id and article_id in scope[1])


def return_feature_ready():
    names=['logistique."'+name+'"' for name in ('T_RetourBon','V_RetourArticle','V_RetourLot','V_RetourBon')]
    return bool(db.one('''SELECT bool_and(to_regclass(x) IS NOT NULL) AND
        (SELECT count(*)=6 FROM pg_trigger WHERE NOT tgisinternal AND tgenabled<>'D'
         AND tgname=ANY(%s) AND tgrelid IN (to_regclass('logistique."T_RetourBon"'),to_regclass('logistique."T_Commande"'),
          to_regclass('logistique."T_CommandeDetail"'),to_regclass('logistique."T_Mouvement"'),to_regclass('logistique."T_MouvementLot"'),to_regclass('logistique."T_LotArticle"')))
        AS ready FROM unnest(%s::text[]) AS t(x)''',[
        ['retour_bon_integrite','aa_retour_commande_protection','aa_retour_ligne_protection','aa_retour_mouvement_protection','aa_retour_lot_protection','lot_retour_identite'],names])['ready'])


import hashlib,hmac,json,uuid
from datetime import datetime,timezone
from decimal import Decimal
from .quantities import quantity as exact_quantity, line_amount
from zoneinfo import ZoneInfo
from django.conf import settings
from django.db import DatabaseError,transaction
from rest_framework.views import APIView
from apps.core.module_access import require_module,access_snapshot
from apps.core.permissions import IsERPAdmin
from apps.core.registry import model,view
from apps.core.repository import positive,get_record,predicate,mutate,audit,clean
from apps.core.responses import APIError,ExactEncoder,ok


def return_error(field,message,code='RETURN_VALIDATION',status=400):
    raise APIError({field:message},code,status)


def source_context(actor,command_id,*,lock=False):
    row=get_record(model('T_Commande'),actor,{'ID_Commande':positive(command_id)},lock=lock)
    if lock:db.one('SELECT "ID_Commande" FROM logistique."T_Commande" WHERE "ID_Commande"=%s FOR UPDATE',[row['ID_Commande']])
    from apps.core.tenancy import assert_document
    assert_document(actor,row)
    return row


def return_snapshot(actor,command_id):
    where,values=predicate(model('T_Commande'),actor,keys={'ID_Commande':command_id})
    snapshot=db.one('''SELECT to_jsonb(v) AS raw,to_jsonb(cv)||to_jsonb(v) AS bon,
        t."AbrGenerique" AS direction,t."ID_CategorieGeneriqueFk" AS type_category,
        logistique.fn_nature_bon(v."ID_TypeCmdFk") AS nature,
        (SELECT COALESCE(jsonb_agg(to_jsonb(d) ORDER BY d."ID_ArticleFk"),'[]'::jsonb)
         FROM logistique."T_CommandeDetail" d WHERE d."ID_CmdFk"=v."ID_Commande") AS raw_lines,
        (SELECT COALESCE(jsonb_agg(to_jsonb(m)||jsonb_build_object('Lots',
           (SELECT COALESCE(jsonb_agg(to_jsonb(ml) ORDER BY ml."ID_LotArticleFk"),'[]'::jsonb)
            FROM logistique."T_MouvementLot" ml WHERE ml."ID_MvtFk"=m."ID_Mvt")) ORDER BY m."ID_Mvt"),'[]'::jsonb)
         FROM logistique."T_Mouvement" m WHERE m."ID_cmdFk"=v."ID_Commande") AS raw_movements,
        (SELECT COALESCE(jsonb_agg(to_jsonb(ra)||jsonb_build_object('Lots',
           (SELECT COALESCE(jsonb_agg(to_jsonb(rl) ORDER BY rl."ID_LotArticle"),'[]'::jsonb)
            FROM logistique."V_RetourLot" rl WHERE rl."ID_CommandeOrigineFk"=ra."ID_CommandeOrigineFk" AND rl."ID_ArticleFk"=ra."ID_ArticleFk")) ORDER BY ra."ID_ArticleFk"),'[]'::jsonb)
         FROM logistique."V_RetourArticle" ra WHERE ra."ID_CommandeOrigineFk"=v."ID_Commande") AS lignes,
        (SELECT COALESCE(jsonb_agg(to_jsonb(rb) ORDER BY rb."ID_RetourBon"),'[]'::jsonb)
         FROM logistique."V_RetourBon" rb WHERE rb."ID_CommandeOrigineFk"=v."ID_Commande") AS retours,
        EXISTS(SELECT 1 FROM logistique."T_RetourBon" r WHERE r."ID_CommandeRetourFk"=v."ID_Commande") AS is_return
        FROM logistique."T_Commande" v LEFT JOIN logistique."V_Commande" cv ON cv."ID_Commande"=v."ID_Commande"
        LEFT JOIN referentiel."T_Generique" t ON t."ID_Generique"=v."ID_TypeCmdFk" WHERE '''+where,values)
    if not snapshot:raise APIError('Objet introuvable dans votre périmètre.','NOT_FOUND',404)
    return snapshot


def return_revision(snapshot):
    canonical={key:snapshot[key] for key in ('raw','raw_lines','raw_movements','retours','is_return')}
    return hashlib.sha256(json.dumps(canonical,cls=ExactEncoder,sort_keys=True,ensure_ascii=False,separators=(',',':')).encode('utf8')).hexdigest()


def return_policy(actor,snapshot,*,writing=False):
    from .receipts import entry_types,default_entry_type
    from .currency import validate_currency
    reason='';selected=None
    if snapshot['raw'].get('ID_TransfertDepotFk'):
        reason='Ce bon appartient à un transfert interne. Réceptionnez ou retournez son transit depuis la fiche du transfert.'
    elif snapshot['raw'].get('OrigineBon') in {'stock_initial','reprise_mouvement'}:
        reason='Un bon de stock initial ou de reprise se corrige par un nouveau bon, sans restitution commerciale.'
    elif inventory_adjustment(snapshot['raw']['ID_Commande']):
        reason='Un bon d’inventaire se corrige par le comptage ou son annulation, sans restitution commerciale.'
    elif snapshot['is_return'] or snapshot['nature']!='sortie':
        reason='Seul un bon de sortie peut recevoir une restitution.'
    elif not snapshot['lignes']:reason='Ce bon ne comporte aucun article sorti.'
    elif any(not row['SourceCoherente'] or Decimal(str(row['QteRestante']))<0 or Decimal(str(row['QteSansLotRestante']))<0 or any(Decimal(str(lot['QteRestante']))<0 for lot in row['Lots']) for row in snapshot['lignes']):
        reason='Rapprochez les lignes et mouvements historiques avant de restituer ce bon.'
    elif not any(Decimal(str(row['QteRestante']))>0 for row in snapshot['lignes']):reason='Tous les articles de ce bon ont déjà été restitués.'
    else:
        try:
            validate_currency(snapshot['raw'].get('ID_DeviseFk'),unchanged=True,actor=actor,table='T_Commande')
            selected=default_entry_type(entry_types(actor,lock=writing))
            if not selected:reason='Définissez un type de bon d’entrée unique dans le référentiel.'
        except APIError as error:
            if writing:raise error
            reason='Vérifiez la devise et le type de bon d’entrée dans le référentiel.'
    if not reason and not access_snapshot(actor)['modules']['logistique']['canManage']:reason='Votre rôle ne permet pas de valider un retour.'
    if not reason and settings.DB_READ_ONLY:reason='Les écritures sont momentanément indisponibles.'
    return {'available':True,'canReturn':not reason,'reason':reason,'revision':return_revision(snapshot),
            'requiresCreditNote':bool(str(snapshot['raw'].get('CodeFacture') or '').strip()),'entryType':selected}


def preview_returns(actor,command_id):
    require_module(actor,'logistique')
    source_context(actor,command_id)
    defaults={'DateCmd':datetime.now(ZoneInfo(settings.TIME_ZONE)).replace(tzinfo=None).isoformat(timespec='minutes')}
    if not return_feature_ready():
        return {'bonOrigine':get_record(view('logistique','V_Commande'),actor,{'ID_Commande':command_id}),
                'lignes':[],'retours':[],'defaults':defaults,'timeZone':settings.TIME_ZONE}, {'available':False,'canReturn':False,'reason':'Les retours de stock ne sont pas encore disponibles.','revision':None}
    snapshot=return_snapshot(actor,command_id)
    return clean({'bonOrigine':snapshot['bon'],'lignes':snapshot['lignes'],'retours':snapshot['retours'],
                  'defaults':defaults,'timeZone':settings.TIME_ZONE}),return_policy(actor,snapshot)


def return_data(body):
    if not isinstance(body,dict) or set(body)!={'requestId','_version','DateCmd','motif','lignes'}:
        return_error('motif','Renseignez la restitution et les articles rendus.')
    try:request_id=str(uuid.UUID(body['requestId']))
    except (ValueError,TypeError,AttributeError):return_error('requestId','La demande n’est plus valide. Rouvrez le formulaire.')
    motif=body['motif']
    if not isinstance(motif,str) or not 1<=len(motif.strip())<=1000:return_error('motif','Indiquez un motif de 1 à 1000 caractères.')
    try:motif.strip().encode('utf8')
    except UnicodeError:return_error('motif','Indiquez un motif valide.')
    raw_date=body['DateCmd']
    try:
        if not isinstance(raw_date,str) or 'T' not in raw_date or len(raw_date)>40:raise ValueError()
        date=datetime.fromisoformat(raw_date.replace('Z','+00:00'))
        if date.tzinfo is None:date=date.replace(tzinfo=ZoneInfo(settings.TIME_ZONE))
    except (ValueError,TypeError,OverflowError):return_error('DateCmd','Indiquez la date et l’heure du retour.')
    if not isinstance(body['lignes'],list) or not 1<=len(body['lignes'])<=50:return_error('lignes','Sélectionnez entre 1 et 50 articles à restituer par événement.')
    lines=[];seen=set()
    for index,row in enumerate(body['lignes']):
        prefix='lignes.'+str(index)
        if not isinstance(row,dict) or set(row)-{'ID_ArticleFk','QteRetour','Lots'}:return_error(prefix,'Informations de restitution non autorisées.')
        try:identifier=positive(row.get('ID_ArticleFk'),'Article');quantity=exact_quantity(row.get('QteRetour'),'QteRetour')
        except APIError:return_error(prefix+'.QteRetour','Indiquez un article et une quantité strictement positive, avec trois décimales au maximum.')
        if identifier in seen:return_error(prefix+'.QteRetour','Chaque article doit apparaître une seule fois avec une quantité dans les limites du stock.')
        seen.add(identifier);lots=[];lot_ids=set();lot_rows=row.get('Lots',[])
        if not isinstance(lot_rows,list) or len(lot_rows)>50:return_error(prefix+'.Lots','Indiquez au maximum 50 lots source par ligne.')
        for lot in lot_rows:
            if not isinstance(lot,dict) or set(lot)!={'ID_LotArticle','Quantite'}:return_error(prefix+'.Lots','Sélectionnez uniquement les lots de la sortie d’origine.')
            try:lot_id=positive(lot['ID_LotArticle'],'Lot');lot_qty=exact_quantity(lot['Quantite'],'Quantite')
            except APIError:return_error(prefix+'.Lots','Chaque lot exige une quantité strictement positive, avec trois décimales au maximum.')
            if lot_id in lot_ids:return_error(prefix+'.Lots','Un lot source ne doit apparaître qu’une fois dans la ligne.')
            lot_ids.add(lot_id);lots.append({'ID_LotArticle':lot_id,'Quantite':lot_qty})
        if sum(lot['Quantite'] for lot in lots)>quantity:return_error(prefix+'.Lots','La ventilation ne peut pas dépasser la quantité rendue.')
        lines.append({'index':index,'ID_ArticleFk':identifier,'QteRetour':quantity,'Lots':sorted(lots,key=lambda lot:lot['ID_LotArticle'])})
    return {'requestId':request_id,'DateCmd':date,'motif':motif.strip(),'lignes':lines}


def return_hash(actor,command_id,data):
    canonical={key:value for key,value in data.items() if key not in {'requestId','lignes'}}
    canonical.update(ID_CommandeOrigineFk=command_id,IdUser=actor.pk,IdEntiteFk=actor.organisation,
      DateCmd=data['DateCmd'].astimezone(timezone.utc).isoformat(),lignes=[{key:value for key,value in row.items() if key!='index'} for row in sorted(data['lignes'],key=lambda row:row['ID_ArticleFk'])])
    return hashlib.sha256(json.dumps(canonical,cls=ExactEncoder,sort_keys=True,ensure_ascii=False,separators=(',',':')).encode('utf8')).hexdigest()


def return_result(actor,source_id,child_id,*,replayed):
    return clean({'bonOrigine':get_record(view('logistique','V_Commande'),actor,{'ID_Commande':source_id}),
                  'bonRetour':get_record(view('logistique','V_Commande'),actor,{'ID_Commande':child_id}),'replayed':replayed})


def record_return(actor,command_id,body):
    db.ensure_writable()
    if not actor.admin:raise APIError('Accès réservé aux gestionnaires autorisés.','FORBIDDEN',403)
    require_module(actor,'logistique','manage')
    if not return_feature_ready():raise APIError('Les retours de stock ne sont pas encore disponibles.','RETURN_UNAVAILABLE',503)
    command_id=positive(command_id);data=return_data(body);fingerprint=return_hash(actor,command_id,data)
    try:
        with transaction.atomic():
            db.one('SELECT pg_advisory_xact_lock(hashtextextended(%s,0)) AS locked',['stock-return:'+str(actor.pk)+':'+data['requestId']])
            source=source_context(actor,command_id,lock=True)
            saved=db.one('SELECT * FROM logistique."T_RetourBon" WHERE "ID_UserFk"=%s AND "RequestId"=%s',[actor.pk,data['requestId']])
            if saved:
                if saved['ID_CommandeOrigineFk']!=command_id or saved['IdEntiteFk']!=actor.organisation or not hmac.compare_digest(str(saved['PayloadHash']),fingerprint):
                    raise APIError('Cette demande a déjà été enregistrée avec une autre restitution. Rouvrez le formulaire.','RETURN_REPLAY_CONFLICT',409)
                return return_result(actor,command_id,saved['ID_CommandeRetourFk'],replayed=True)
            snapshot=return_snapshot(actor,command_id);policy=return_policy(actor,snapshot,writing=True)
            if not policy['canReturn']:raise APIError(policy['reason'],'RETURN_NOT_ALLOWED',409)
            if not isinstance(body['_version'],str) or not hmac.compare_digest(policy['revision'],body['_version']):
                raise APIError('La sortie ou ses restitutions ont changé. Rechargez les quantités restantes.','RETURN_CONFLICT',409)
            from .depots import depot
            depot(actor,source['ID_DepotFk'],lock=True)
            from .order_composer import article_contexts,mapped_error
            article_contexts(actor,[{'index':line['index'],'data':{'ID_ArticleFk':line['ID_ArticleFk']}} for line in data['lignes']],active=False)
            budget={row['ID_ArticleFk']:row for row in snapshot['lignes']};total=Decimal('0')
            for row in data['lignes']:
                prefix='lignes.'+str(row['index']);available=budget.get(row['ID_ArticleFk'])
                if not available or row['QteRetour']>Decimal(str(available['QteRestante'])):
                    return_error(prefix+'.QteRetour','La quantité dépasse la sortie encore restituable.','RETURN_QUANTITY_CONFLICT',409)
                original_lots={lot['ID_LotArticle']:lot for lot in available['Lots']}
                for lot in row['Lots']:
                    initial=original_lots.get(lot['ID_LotArticle'])
                    if not initial or lot['Quantite']>Decimal(str(initial['QteRestante'])):
                        return_error(prefix+'.Lots','Ce lot ou sa quantité ne provient pas de la sortie restante.','RETURN_LOT_CONFLICT',409)
                if row['QteRetour']-sum(lot['Quantite'] for lot in row['Lots'])>Decimal(str(available['QteSansLotRestante'])):
                    return_error(prefix+'.Lots','Précisez les lots d’origine : la part sortie sans lot est insuffisante.','RETURN_LOT_CONFLICT',409)
                total+=line_amount(row['QteRetour'],available['PUHistorique'])
                if total>Decimal('9999999999.99'):return_error(prefix+'.QteRetour','La valeur de cet événement dépasse la capacité du bon de retour.')
            child=mutate('T_Commande',actor,{'ID_TypeCmdFk':policy['entryType']['id'],'ID_DeviseFk':source['ID_DeviseFk'],'ID_DepotFk':source.get('ID_DepotFk'),
                 'DateCmd':data['DateCmd'],'RefCmd':'Retour de '+str(source.get('CodeCmd') or '#'+str(command_id)),
                 'ID_ClientFk':source.get('ID_ClientFk'),'ID_TiersFk':source.get('ID_TiersFk'),'NomClientSaisi':source.get('NomClientSaisi'),
                 'ObsCmd':('Retour de stock — '+data['motif'])[:255]},operation='create')
            from .services import mutate_line
            with _historical_line_scope(child['ID_Commande'],[line['ID_ArticleFk'] for line in data['lignes']]):
                for row in sorted(data['lignes'],key=lambda line:line['ID_ArticleFk']):
                    try:mutate_line(actor,child['ID_Commande'],{'ID_ArticleFk':row['ID_ArticleFk'],'QteCmdDetail':row['QteRetour'],
                                       'PUCmdDetail':budget[row['ID_ArticleFk']]['PUHistorique']})
                    except APIError as error:mapped_error(error,'lignes.'+str(row['index']))
                    movement=db.one('SELECT "ID_Mvt" FROM logistique."T_Mouvement" WHERE "ID_cmdFk"=%s AND "ID_ArticleFk"=%s',[child['ID_Commande'],row['ID_ArticleFk']])
                    if not movement:raise APIError('Mouvement compensateur introuvable.','RETURN_MOVEMENT_MISSING',409)
                    # La ventilation ne crée aucun mouvement et ne modifie jamais une seconde fois QteArticle.
                    for lot in row['Lots']:
                        db.query('INSERT INTO logistique."T_MouvementLot" ("ID_MvtFk","ID_LotArticleFk","Quantite") VALUES (%s,%s,%s)',[movement['ID_Mvt'],lot['ID_LotArticle'],lot['Quantite']])
            # Sceller seulement après les lignes/lots : aucune portée SQL ou HTTP de déverrouillage.
            link=db.one('''INSERT INTO logistique."T_RetourBon" ("ID_CommandeOrigineFk","ID_CommandeRetourFk","ID_UserFk","IdEntiteFk","RequestId","PayloadHash","Motif","DateRetour")
                VALUES (%s,%s,%s,%s,%s,%s,%s,%s) RETURNING "ID_RetourBon"''',[command_id,child['ID_Commande'],actor.pk,actor.organisation,data['requestId'],fingerprint,data['motif'],data['DateCmd']])
            audit(model('T_Commande'),'STOCK_RETURN',new={'ID_Commande':command_id,'ID_CommandeRetourFk':child['ID_Commande'],'ID_RetourBon':link['ID_RetourBon'],
                  'requestId':data['requestId'],'payloadHash':fingerprint,'IdEntiteFk':actor.organisation,'motif':data['motif'],'lignes':data['lignes']},actor=actor)
            return return_result(actor,command_id,child['ID_Commande'],replayed=False)
    except DatabaseError as error:
        state=getattr(error.__cause__,'sqlstate',None)
        if state in {'P0001','23514','23503','23505','55P03','40P01','22003'}:
            raise APIError('La restitution est incompatible avec les quantités restantes, les lots ou les références. Rechargez le bon.','RETURN_STOCK_CONFLICT',409) from error
        raise


class StockReturnsView(APIView):
    permission_classes=[IsERPAdmin]
    http_method_names=['get','post','options']

    def get(self,request,pk):
        data,meta=preview_returns(request.user,positive(pk))
        return ok(data,meta=meta)

    def post(self,request,pk):
        result=record_return(request.user,pk,request.data)
        return ok(result,status=200 if result['replayed'] else 201,message='Retour de stock enregistré.')


def annotate_return_context(rows,actor):
    """Annotation par lot de lignes déjà autorisées ; jamais une requête par bon."""
    available=return_feature_ready()
    empty={'available':available,'canReturn':False,'reason':'Les retours de stock ne sont pas encore disponibles.' if not available else '',
           'isReturn':False,'hasReturns':False,'allReturned':False,'originId':None,'returnIds':[]}
    if not available or not rows:return [{**row,'returnContext':dict(empty)} for row in rows]
    identifiers=[row['ID_Commande'] for row in rows]
    contexts=db.query('''SELECT c."ID_Commande",c."IdEntiteFk" AS organisation,t."AbrGenerique" AS direction,logistique.fn_bon_inventaire(c."ID_Commande") AS inventory_adjustment,
        t."ID_CategorieGeneriqueFk" AS category,logistique.fn_nature_bon(c."ID_TypeCmdFk") AS nature,
        (SELECT r."ID_CommandeOrigineFk" FROM logistique."T_RetourBon" r WHERE r."ID_CommandeRetourFk"=c."ID_Commande") AS origin,
        ARRAY(SELECT r."ID_CommandeRetourFk" FROM logistique."T_RetourBon" r WHERE r."ID_CommandeOrigineFk"=c."ID_Commande" ORDER BY r."ID_RetourBon") AS children,
        (SELECT bool_and(ra."SourceCoherente") AND bool_and(ra."QteRestante">=0) AND bool_and(ra."QteSansLotRestante">=0) FROM logistique."V_RetourArticle" ra WHERE ra."ID_CommandeOrigineFk"=c."ID_Commande") AS coherent,
        (SELECT bool_or(ra."QteRestante">0) FROM logistique."V_RetourArticle" ra WHERE ra."ID_CommandeOrigineFk"=c."ID_Commande") AS remaining,
        (cu."ID_Generique" IS NOT NULL) AS currency_present,
        COALESCE(NULLIF(btrim(cu."AbrGenerique"),''),cu."NomGenerique") AS currency_code
        FROM logistique."T_Commande" c
        LEFT JOIN referentiel."T_Generique" t ON t."ID_Generique"=c."ID_TypeCmdFk"
        LEFT JOIN referentiel."T_Generique" cu ON cu."ID_Generique"=c."ID_DeviseFk"
        LEFT JOIN referentiel."T_CategorieGenerique" cat ON cat."ID_CategorieGenerique"=cu."ID_CategorieGeneriqueFk"
        WHERE c."ID_Commande"=ANY(%s)''',[identifiers])
    from .receipts import entry_types,default_entry_type
    try:configured=default_entry_type(entry_types(actor)) is not None
    except APIError:configured=False
    manage=access_snapshot(actor)['modules']['logistique']['canManage']
    indexed={row['ID_Commande']:row for row in contexts};result=[]
    for row in rows:
        state=indexed.get(row['ID_Commande'])
        if not state:context=dict(empty)
        else:
            from .currency import normalize_code
            try:currency_valid=state['currency_present'] and bool(normalize_code(state['currency_code']))
            except APIError:currency_valid=False
            reason=('Ce bon appartient à un transfert interne. Utilisez la fiche du transfert.' if row.get('ID_TransfertDepotFk') else
                    'Effectuez le retour dans l’organisation du bon.' if state['organisation']!=actor.organisation else
                    'Un bon d’inventaire ne permet pas de restitution commerciale.' if state['inventory_adjustment'] else
                    'Ce document n’est pas une sortie originale.' if state['origin'] is not None or state['nature']!='sortie' else
                    'Rapprochez les lignes et mouvements historiques avant un retour.' if not state['coherent'] else
                    'Tous les articles ont déjà été restitués.' if not state['remaining'] else
                    'Vérifiez la devise et le type de bon d’entrée dans le référentiel.' if not configured or not currency_valid else
                    'Votre rôle ne permet pas de valider un retour.' if not manage else
                    'Les écritures sont momentanément indisponibles.' if settings.DB_READ_ONLY else '')
            context={'available':True,'canReturn':not reason,'reason':reason,'isReturn':state['origin'] is not None,
                     'hasReturns':bool(state['children']),'allReturned':bool(state['coherent'] and not state['remaining']),
                     'originId':state['origin'],'returnIds':state['children']}
        result.append({**row,'returnContext':context})
    return result
