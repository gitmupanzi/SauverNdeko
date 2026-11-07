"""Comptages physiques : brouillon versionné, validation atomique, mouvements des triggers existants."""
import hashlib
import hmac
import json
import uuid
from datetime import datetime
from decimal import Decimal, InvalidOperation
from zoneinfo import ZoneInfo

from django.conf import settings
from django.db import transaction
from rest_framework.views import APIView
from apps.core import db
from apps.core.module_access import require_module
from apps.core.permissions import IsERPAdmin
from apps.core.repository import audit, clean, mutate, positive
from apps.core.responses import APIError, ExactEncoder, ok
from apps.core.tenancy import require_entity, assert_document, read_entity
from .quantities import for_unit, quantity, line_amount
from .lots import normalize as normalize_lots

OBJECT={'schema':'logistique','name':'T_Inventaire'}


def access(actor, write=False):
    if not actor.admin:raise APIError('Accès réservé aux gestionnaires autorisés.','FORBIDDEN',403)
    require_module(actor,'logistique','manage' if write else 'read')
    entity=require_entity(actor)
    if write:db.ensure_writable()
    return entity


def failure(field,message,code='INVENTORY_VALIDATION',status=400):
    raise APIError({field:message},code,status)


def header(actor,identifier,lock=False):
    entity=access(actor)
    row=db.one('SELECT * FROM logistique."T_Inventaire" WHERE "ID_Inventaire"=%s AND "IdEntiteFk"=%s'+(' FOR UPDATE' if lock else ''),[positive(identifier),entity])
    if not row:raise APIError('Inventaire introuvable dans cette entreprise.','NOT_FOUND',404)
    return row


def snapshot(actor,identifier):
    row=header(actor,identifier)
    lines=db.query('SELECT * FROM logistique."V_InventaireLigne" WHERE "ID_InventaireFk"=%s ORDER BY "NomArticle","ID_ArticleFk"',[row['ID_Inventaire']])
    return clean({**row,'CodeInventaire':'inv-'+str(row['ID_Inventaire']),'lignes':lines})


def check_version(row,version):
    if str(row['Version'])!=str(version):raise APIError('Le comptage a changé. Rechargez-le avant d’enregistrer.','INVENTORY_CONFLICT',409)


def request_id(body):
    try:return str(uuid.UUID(body.get('requestId')))
    except (ValueError,TypeError,AttributeError):failure('requestId','Rouvrez le formulaire pour préparer une nouvelle demande.')


def digest(value):return hashlib.sha256(json.dumps(value,cls=ExactEncoder,sort_keys=True,ensure_ascii=False,separators=(',',':')).encode('utf8')).hexdigest()


def date_value(value):
    try:
        if not isinstance(value,str) or 'T' not in value:raise ValueError()
        result=datetime.fromisoformat(value.replace('Z','+00:00'))
        return result if result.tzinfo else result.replace(tzinfo=ZoneInfo(settings.TIME_ZONE))
    except (ValueError,TypeError,OverflowError):failure('DateInventaire','Indiquez la date et l’heure du comptage.')


def parse(body,editing):
    expected={'requestId','DateInventaire','Motif','lignes'}|({'_version'} if editing else set())
    if not isinstance(body,dict) or not expected<=set(body)<=expected|{'ID_DepotFk'}:failure('Motif','Renseignez l’inventaire et ses lignes.')
    identifier=request_id(body)
    motif=body['Motif']
    if not isinstance(motif,str) or not 1<=len(motif.strip())<=1000:failure('Motif','Indiquez un motif de 1 à 1000 caractères.')
    rows=body['lignes']
    if not isinstance(rows,list) or not 1<=len(rows)<=100:failure('lignes','Ajoutez entre 1 et 100 articles distincts.')
    lines=[];seen=set()
    for index,row in enumerate(rows):
        prefix='lignes.'+str(index)
        if not isinstance(row,dict) or set(row)!={'ID_ArticleFk','QteTheorique','QteComptee','Justification','Lots','PUCorrection'}:failure(prefix,'Informations de comptage invalides.')
        article=positive(row['ID_ArticleFk'])
        if article in seen:failure(prefix,'Regroupez le comptage d’un même article.')
        seen.add(article)
        reason=row['Justification']
        if not isinstance(reason,str) or not 1<=len(reason.strip())<=1000:failure(prefix+'.Justification','Justifiez le comptage ou son écart.')
        counted=quantity(row['QteComptee'],prefix+'.QteComptee',zero=True)
        theory=quantity(row['QteTheorique'],prefix+'.QteTheorique',zero=True)
        delta=counted-theory
        lots=normalize_lots(row['Lots'],abs(delta),allow_partial=delta<0)
        if delta==0 and lots:failure(prefix+'.Lots','Un comptage sans écart ne crée pas de ventilation.')
        try:
            price=Decimal(str(row['PUCorrection'])) if row['PUCorrection'] is not None else None
            if price is not None and (not price.is_finite() or price<0 or price>Decimal('9999999999.99') or price!=price.quantize(Decimal('0.01'))):raise ValueError()
        except (ValueError,TypeError,InvalidOperation):failure(prefix+'.PUCorrection','Indiquez un prix indicatif valide à deux décimales.')
        if delta!=0 and price is None:failure(prefix+'.PUCorrection','Renseignez le prix indicatif du bon d’écart.')
        if price is not None and line_amount(abs(delta),price)>Decimal('9999999999.99'):failure(prefix+'.PUCorrection','Le montant du bon d’écart dépasse la capacité autorisée.')
        lines.append({'index':index,'ID_ArticleFk':article,'QteTheorique':theory,'QteComptee':counted,'Justification':reason.strip(),
          'Lots':[{**lot,'DatePeremptionLot':lot['DatePeremptionLot'].isoformat() if lot['DatePeremptionLot'] else None} for lot in lots],'PUCorrection':price})
    return {'requestId':identifier,'DateInventaire':date_value(body['DateInventaire']),'Motif':motif.strip(),'lignes':lines,**({'ID_DepotFk':positive(body['ID_DepotFk'],'Dépôt')} if body.get('ID_DepotFk') else {})}


def lock_articles(actor,lines,depot_id=None):
    result={}
    for line in sorted(lines,key=lambda row:row['ID_ArticleFk']):
        row=db.one('SELECT * FROM logistique."T_Article" WHERE "ID_Article"=%s FOR NO KEY UPDATE',[line['ID_ArticleFk']])
        if not row:raise APIError('Article introuvable.','NOT_FOUND',404)
        assert_document(actor,row)
        if row.get('QteArticle') is None:failure('lignes.'+str(line.get('index',0)), 'Le stock de cet article est inconnu. Vérifiez son historique.','INVENTORY_UNKNOWN_STOCK',409)
        for field in ('QteTheorique','QteComptee'):for_unit(line[field],row['ID_UniteFk'],'lignes.'+str(line.get('index',0))+'.'+field,zero=True)
        from .depots import stock
        physical=stock(row['ID_Article'],depot_id)['StockPhysique'] if depot_id else row['QteArticle']
        if Decimal(str(physical))!=line['QteTheorique']:
            failure('lignes.'+str(line.get('index',0))+'.QteTheorique','Le stock a changé depuis le comptage. Reprenez cette ligne depuis le catalogue et recomptez.','INVENTORY_STOCK_CHANGED',409)
        result[row['ID_Article']]=row
    return result


def save(actor,identifier,body):
    entity=access(actor,True);data=parse(body,identifier is not None)
    fingerprint=digest({'entity':entity,'identifier':identifier,'body':data})
    with transaction.atomic():
        db.one('SELECT pg_advisory_xact_lock(hashtextextended(%s,0)) AS locked',['inventory:'+str(actor.pk)+':'+data['requestId']])
        proof=db.one('''SELECT "NewData" AS proof FROM systeme."T_Audit_Log" WHERE "TableName"='logistique.T_Inventaire'
            AND "Operation"='INVENTORY_SAVE' AND "NewData"->>'requestId'=%s AND "NewData"->'_actor'->>'IdUser'=%s ORDER BY "IdLog" DESC LIMIT 1''',[data['requestId'],str(actor.pk)])
        if proof:
            saved=proof['proof']
            if not hmac.compare_digest(saved.get('hash',''),fingerprint):raise APIError('Cette demande a déjà été utilisée pour un autre comptage.','INVENTORY_REPLAY_CONFLICT',409)
            return snapshot(actor,saved['ID_Inventaire']),True
        old=header(actor,identifier,True) if identifier else None
        if old:
            check_version(old,body['_version'])
            if old['Etat']!='brouillon':raise APIError('Un inventaire validé est conservé. Créez un nouveau comptage.','INVENTORY_CLOSED',409)
        from .depots import depot
        selected=depot(actor,data.get('ID_DepotFk',(old or {}).get('ID_DepotFk')),lock=True)['ID_Depot']
        if old and selected!=old['ID_DepotFk']:failure('ID_DepotFk','Conservez le dépôt de ce comptage. Créez un autre inventaire pour un autre dépôt.','INVENTORY_DEPOT_LOCKED',409)
        lock_articles(actor,data['lignes'],selected)
        if old:
            record=db.one('UPDATE logistique."T_Inventaire" SET "Motif"=%s,"DateInventaire"=%s WHERE "ID_Inventaire"=%s RETURNING *',[data['Motif'],data['DateInventaire'],identifier])
            db.query('DELETE FROM logistique."T_InventaireLigne" WHERE "ID_InventaireFk"=%s',[identifier])
        else:record=db.one('INSERT INTO logistique."T_Inventaire" ("IdEntiteFk","ID_UserFk","Motif","DateInventaire","ID_DepotFk") VALUES (%s,%s,%s,%s,%s) RETURNING *',[entity,actor.pk,data['Motif'],data['DateInventaire'],selected])
        from psycopg.types.json import Jsonb
        for line in data['lignes']:
            db.query('''INSERT INTO logistique."T_InventaireLigne" ("ID_InventaireFk","ID_ArticleFk","QteTheorique","QteComptee","Justification","Lots","PUCorrection")
                VALUES (%s,%s,%s,%s,%s,%s,%s)''',[record['ID_Inventaire'],line['ID_ArticleFk'],line['QteTheorique'],line['QteComptee'],line['Justification'],Jsonb(json.loads(json.dumps(line['Lots'],cls=ExactEncoder))),line['PUCorrection']])
        audit(OBJECT,'INVENTORY_SAVE',old=old,new={'ID_Inventaire':record['ID_Inventaire'],'requestId':data['requestId'],'hash':fingerprint,'Version':record['Version']},actor=actor)
        return snapshot(actor,record['ID_Inventaire']),False


def validate(actor,identifier,body):
    entity=access(actor,True)
    if not isinstance(body,dict) or set(body)!={'requestId','_version'}:failure('requestId','Demande de validation invalide.')
    request=request_id(body)
    with transaction.atomic():
        record=header(actor,identifier,True)
        fingerprint=digest({'entity':entity,'ID_Inventaire':record['ID_Inventaire'],'version':str(body['_version'])})
        if record['Etat']=='valide':
            if str(record['ValidationRequest'])!=request or not hmac.compare_digest(record['ValidationHash'],fingerprint):raise APIError('Cet inventaire est déjà validé.','INVENTORY_CLOSED',409)
            return snapshot(actor,identifier),True
        if record['Etat']!='brouillon':raise APIError('Cet inventaire est historique. Créez un nouveau comptage.','INVENTORY_CLOSED',409)
        check_version(record,body['_version'])
        lines=db.query('SELECT * FROM logistique."T_InventaireLigne" WHERE "ID_InventaireFk"=%s ORDER BY "ID_ArticleFk"',[record['ID_Inventaire']])
        if not lines:failure('lignes','Ajoutez les articles comptés.')
        from .depots import depot
        depot(actor,record['ID_DepotFk'],lock=True)
        articles=lock_articles(actor,lines,record['ID_DepotFk'])
        from .lots import stock_document_types
        types=stock_document_types(actor,lock=True)
        corrections={}
        from .services import mutate_line
        for line in lines:
            delta=line['QteComptee']-line['QteTheorique']
            if delta==0:continue
            sign=1 if delta>0 else -1;article=articles[line['ID_ArticleFk']]
            if sign not in types:raise APIError('Configurez les types de bon Entrée et Sortie dans les références.','INVENTORY_TYPE_REQUIRED',409)
            if not article.get('ID_DeviseFk'):raise APIError('La devise du bon d’écart doit être renseignée.','CURRENCY_REQUIRED',409)
            # Bons groupés par sens ET devise ; les triggers restent l'unique effet de stock.
            key=(sign,article['ID_DeviseFk'])
            if key not in corrections:
                corrections[key]=mutate('T_Commande',actor,{'ID_TypeCmdFk':types[sign],'ID_DeviseFk':article['ID_DeviseFk'],'ID_DepotFk':record['ID_DepotFk'],
                    'DateCmd':record['DateInventaire'],'RefCmd':'Inventaire inv-'+str(record['ID_Inventaire']),
                    'ObsCmd':('Écart d’inventaire — '+record['Motif'])[:255]},operation='create')
            command=corrections[key]
            payload={'ID_ArticleFk':line['ID_ArticleFk'],'QteCmdDetail':abs(delta),'PUCmdDetail':line['PUCorrection'],'ObsCmdDetail':line['Justification'][:255]}
            if line['Lots']:payload['Lots']=line['Lots']
            mutate_line(actor,command['ID_Commande'],payload)
            db.query('UPDATE logistique."T_InventaireLigne" SET "ID_CommandeCorrectionFk"=%s WHERE "ID_InventaireFk"=%s AND "ID_ArticleFk"=%s',[command['ID_Commande'],identifier,line['ID_ArticleFk']])
        db.query('''UPDATE logistique."T_Inventaire" SET "Etat"='valide',"ID_ValidateurFk"=%s,"ValideLe"=clock_timestamp(),"ValidationRequest"=%s,"ValidationHash"=%s WHERE "ID_Inventaire"=%s''',[actor.pk,request,fingerprint,identifier])
        audit(OBJECT,'INVENTORY_VALIDATE',new={'ID_Inventaire':identifier,'requestId':request,'hash':fingerprint,'bons':[row['ID_Commande'] for row in corrections.values()]},actor=actor)
        return snapshot(actor,identifier),False


def catalogue(actor,params):
    entity=access(actor);q=str(params.get('q','')).strip()[:200]
    from .depots import depot
    selected=depot(actor,params.get('depotId'),active=False)['ID_Depot']
    try:take=min(100,max(1,int(params.get('take',25))));skip=max(0,int(params.get('skip',0)))
    except (ValueError,TypeError):raise APIError('Pagination invalide.')
    sort=params.get('sortBy','NomArticle');direction=params.get('sortDir','asc')
    sorts={'NomArticle':'a."NomArticle"','QteArticle':'COALESCE(s."StockPhysique",0)','Decimales':'COALESCE(p."DecimalesStock",0)'}
    if sort not in sorts or direction not in ('asc','desc'):raise APIError('Tri invalide.')
    where='a."IdEntiteFk"=%s AND a."ValideArticle" IS TRUE';values=[entity]
    if q:where+=' AND (a."NomArticle" ILIKE %s OR a."CodeArticleInterne" ILIKE %s OR a."RefArticle" ILIKE %s)';values += ['%'+q+'%']*3
    total=db.one('SELECT count(*) n FROM logistique."T_Article" a WHERE '+where,values)['n']
    rows=db.query('''SELECT a."ID_Article",a."NomArticle",a."CodeArticleInterne",a."RefArticle",a."QteArticle" AS "StockEntreprise",
      COALESCE(s."StockPhysique",0) AS "QteArticle",COALESCE(s."StockPhysique",0) AS "StockDepot",
      COALESCE(s."StockDisponible",0) AS "StockDisponible",COALESCE(s."StockReserve",0) AS "StockReserve",%s::bigint AS "ID_DepotFk",
      a."PUArticle",a."ID_DeviseFk",a."ID_UniteFk",g."AbrGenerique" AS "Unite",COALESCE(p."DecimalesStock",0) AS "Decimales"
      FROM logistique."T_Article" a LEFT JOIN referentiel."T_Generique" g ON g."ID_Generique"=a."ID_UniteFk"
      LEFT JOIN logistique."V_PrecisionStock" p ON p."ID_UniteFk"=a."ID_UniteFk"
      LEFT JOIN logistique."V_StockDepot" s ON s."ID_ArticleFk"=a."ID_Article" AND s."ID_DepotFk"=%s
      WHERE '''+where+' ORDER BY '+sorts[sort]+' '+direction+',a."ID_Article" LIMIT %s OFFSET %s',[selected,selected,*values,take,skip])
    return clean(rows),{'filteredCount':total,'take':take,'skip':skip,'sortBy':sort,'sortDir':direction,'depotId':selected}


class InventoriesView(APIView):
    permission_classes=[IsERPAdmin]
    def get(self,request,pk=None,action=None):
        if action=='catalogue':
            data,meta=catalogue(request.user,request.query_params);return ok(data,meta=meta)
        if pk:return ok(snapshot(request.user,pk))
        from .depot_registers import listing
        rows, meta = listing(request.user, 'inventaires', request.query_params)
        return ok(rows, meta=meta)
    def post(self,request,pk=None,action=None):
        if action=='valider':data,replayed=validate(request.user,positive(pk),request.data)
        elif action=='annuler':
            from .inventory_cancellation import cancel
            data,replayed=cancel(request.user,positive(pk),request.data)
        elif pk is None:data,replayed=save(request.user,None,request.data)
        else:raise APIError('Action inconnue.','NOT_FOUND',404)
        return ok(data,status=200 if replayed else 201)
    def put(self,request,pk):
        data,replayed=save(request.user,positive(pk),request.data);return ok(data)


class UnitPrecisionView(APIView):
    permission_classes=[IsERPAdmin]
    def get(self,request):
        access(request.user)
        return ok(db.query('''SELECT "ID_PrecisionStock","ID_UniteFk","Unite","Abreviation",
          "DecimalesStock" AS "Decimales","ModifieLe"
          FROM logistique."V_PrecisionStock"
          WHERE referentiel.fn_reference_visible("ID_UniteFk",%s)
          ORDER BY "Unite","ID_UniteFk"''', [read_entity(request.user)]))
    def put(self,request):
        access(request.user,True)
        if not request.user.global_admin:raise APIError('Le paramétrage partagé des unités exige un administrateur de plateforme.','GLOBAL_ADMIN_REQUIRED',403)
        body=request.data
        if not isinstance(body,dict) or set(body)!={'ID_UniteFk','Decimales'} or type(body['Decimales']) is not int or body['Decimales'] not in range(4):raise APIError('Choisissez une unité et une précision de zéro à trois décimales.')
        unit_id=positive(body['ID_UniteFk'])
        with transaction.atomic():
            unit=db.one('''SELECT "IdEntiteFk" FROM referentiel."T_Generique"
              WHERE "ID_Generique"=%s AND referentiel.fn_reference_visible("ID_Generique",%s) FOR SHARE''',
              [unit_id,read_entity(request.user)])
            if unit is None:raise APIError('Unité introuvable dans cet espace.','NOT_FOUND',404)
            previous=db.one('''SELECT * FROM logistique."T_PrecisionStock" WHERE "ID_UniteFk"=%s FOR UPDATE''',[unit_id])
            if previous:
                row=db.one('''UPDATE logistique."T_PrecisionStock" SET "DecimalesStock"=%s
                  WHERE "ID_UniteFk"=%s RETURNING *''',[body['Decimales'],unit_id])
            else:
                row=db.one('''INSERT INTO logistique."T_PrecisionStock"("ID_UniteFk","DecimalesStock")
                  SELECT "ID_Generique",%s FROM referentiel."T_Generique"
                  WHERE "ID_Generique"=%s AND referentiel.fn_valider_reference_champ(
                    'logistique','T_PrecisionStock','ID_UniteFk',"ID_Generique",%s)
                  RETURNING *''',[body['Decimales'],unit_id,unit['IdEntiteFk']])
            if not row:raise APIError('Unité introuvable.','NOT_FOUND',404)
            audit({'schema':'logistique','name':'T_PrecisionStock'},'UPDATE' if previous else 'INSERT',old=previous,new=row,actor=request.user)
            return ok(clean({'ID_PrecisionStock':row['ID_PrecisionStock'],'ID_UniteFk':row['ID_UniteFk'],'Decimales':row['DecimalesStock'],'ModifieLe':row['ModifieLe']}))
