"""Référentiel partagé des tiers : aucune identité de connexion obligatoire."""
import hashlib,hmac,json,uuid
from django.db import transaction
from rest_framework.views import APIView
from apps.core import db
from apps.core.module_access import require_module
from apps.core.permissions import IsERPAdmin
from apps.core.repository import audit,clean,positive
from apps.core.responses import APIError,ExactEncoder,ok
from apps.core.tenancy import require_entity,read_entity,assert_document

FIELDS={'Nom','Nature','ID_TypeClientFk','Email','Telephone','Adresse','IdUserFk','IdProfessionnelFk','IdEntiteRepresenteeFk','ObsClient','Actif'}
SORTS={'Nom','Nature','TypeClient','DateCreation','Actif'}
OBJ={'schema':'logistique','name':'T_Client'}

def revision(row):
    return hashlib.sha256(json.dumps(row,cls=ExactEncoder,sort_keys=True,separators=(',',':')).encode()).hexdigest()

def rights(actor,row):
    from django.conf import settings
    from apps.core.module_access import access_snapshot
    allowed=bool(read_entity(actor)==row.get('IdEntiteFk')) and not settings.DB_READ_ONLY and access_snapshot(actor)['modules']['logistique']['canManage']
    return {'revision':revision(row),'canEdit':allowed,'canDelete':allowed}

def scope(actor,alias='t'):
    entity=read_entity(actor)
    return ('TRUE',[]) if entity is None and actor.global_admin else (alias+'."IdEntiteFk"=%s',[entity])

def record(actor,pk,lock=False):
    where,args=scope(actor)
    row=db.one('SELECT t.* FROM logistique."V_Client" t WHERE '+where+' AND t."ID_Client"=%s'+(' FOR UPDATE OF t' if lock else ''),[*args,positive(pk)]) if not lock else None
    if lock:row=db.one('SELECT t.* FROM logistique."T_Client" t WHERE '+where+' AND t."ID_Client"=%s FOR UPDATE',[*args,positive(pk)])
    if not row:raise APIError('Tiers introuvable.','NOT_FOUND',404)
    return row

def references(actor):
    from apps.core.field_references import reference_options
    entity=read_entity(actor)
    return {'typesClients':reference_options(actor, 'logistique', 'T_Client', 'ID_TypeClientFk'),
      'users':db.query('''SELECT "IdUser" AS id,concat_ws(' ',"PrenomUser","NomUser") AS label FROM systeme."T_Utilisateurs" WHERE "ValideUser" AND "IdEntiteFk"=%s ORDER BY label''',[entity]) if entity else [],
      'professionnels':db.query('''SELECT p."IdProfessionnel" AS id,p."IdUserFk" AS "userId",concat_ws(' ',u."PrenomUser",u."NomUser") AS label FROM professionnel."T_Professionnel" p JOIN systeme."T_Utilisateurs" u ON u."IdUser"=p."IdUserFk" WHERE p."ValideProfessionnel" AND u."ValideUser" AND (u."IdEntiteFk"=%s OR EXISTS(SELECT 1 FROM professionnel."T_Professionnel_Entite" l WHERE l."IdProfessionnelFk"=p."IdProfessionnel" AND l."IdEntiteFk"=%s AND (l."DateFin" IS NULL OR l."DateFin">=CURRENT_TIMESTAMP))) ORDER BY label''',[entity,entity]) if entity else [],
      'entites':db.query('SELECT "IdEntite" AS id,"NomEntite" AS label FROM systeme."T_Entite" WHERE "ValideEntite" IS NOT FALSE ORDER BY "NomEntite"')}

def validate(actor,raw,old=None):
    if not isinstance(raw,dict) or set(raw)-FIELDS-{'_version','requestId'}:raise APIError('Un champ du tiers n’est pas autorisé.')
    data={key:value for key,value in raw.items() if key in FIELDS}
    for key in FIELDS-{'Actif','ID_TypeClientFk','IdUserFk','IdProfessionnelFk','IdEntiteRepresenteeFk'}:
        if key in data:
            if data[key] is not None and not isinstance(data[key],str):raise APIError({key:'Texte attendu.'})
            data[key]=(data[key] or '').strip() or None
            if data[key] and len(data[key])>4000:raise APIError({key:'Texte trop long.'})
    for key in ('ID_TypeClientFk','IdUserFk','IdProfessionnelFk','IdEntiteRepresenteeFk'):
        if key in data:data[key]=positive(data[key]) if data[key] not in ('',None) else None
    if 'Actif' in data and type(data['Actif']) is not bool:raise APIError({'Actif':'Valeur oui/non attendue.'})
    effective={**(old or {'Nature':'personne','Actif':True}),**data}
    if not effective.get('Nom'):raise APIError({'Nom':'Indiquez le nom ou la raison sociale.'})
    if effective.get('Nature') not in {'personne','entreprise'}:raise APIError({'Nature':'Choisissez une nature.'})
    if not effective.get('ID_TypeClientFk'):raise APIError({'ID_TypeClientFk':'Choisissez le type de client.'})
    refs=references(actor)
    for key,collection in [('ID_TypeClientFk','typesClients'),('IdUserFk','users'),('IdProfessionnelFk','professionnels'),('IdEntiteRepresenteeFk','entites')]:
        value=effective.get(key)
        if value is not None and (not old or old.get(key)!=value) and not any(x['id']==value for x in refs[collection]):raise APIError({key:'Choisissez une référence disponible.'},'TIERS_REFERENCE',400)
    if effective.get('IdProfessionnelFk') and effective.get('IdUserFk'):
        prof=db.one('SELECT "IdUserFk" FROM professionnel."T_Professionnel" WHERE "IdProfessionnel"=%s',[effective['IdProfessionnelFk']])
        if not prof or prof['IdUserFk']!=effective['IdUserFk']:raise APIError({'IdProfessionnelFk':'Le professionnel et le compte doivent désigner la même personne.'})
    return effective if old is None else data

class EntreprisesView(APIView):
    permission_classes=[IsERPAdmin]
    def get(self,request):
        actor=request.user
        sql='SELECT "IdEntite" AS id,"NomEntite" AS label,"ValideEntite" AS active FROM systeme."T_Entite"'
        rows=db.query(sql+' ORDER BY "NomEntite"') if actor.global_admin else db.query(sql+' WHERE "IdEntite"=%s',[actor.organisation])
        counts=db.one('''SELECT count(*) FILTER (WHERE "TypeObjet"='article') AS articles,count(*) FILTER (WHERE "TypeObjet"='commande') AS commandes FROM logistique."V_ProprietairesARevoir"''') if actor.global_admin else None
        return ok(rows,meta={'entityId':read_entity(actor),'globalAdmin':actor.global_admin,'unresolvedCounts':counts})

class TiersReferencesView(APIView):
    permission_classes=[IsERPAdmin]
    def get(self,request):
        refs=references(request.user);refs['defaultTypeClientId']=next((x['id'] for x in refs['typesClients'] if x['label'].strip().lower()=='client'),None)
        return ok(clean(refs))

class TiersView(APIView):
    permission_classes=[IsERPAdmin]
    def get(self,request,pk=None):
        if pk:
            row=record(request.user,pk);return ok(clean(row),meta=rights(request.user,row))
        raw=request.query_params;where,args=scope(request.user)
        clauses=[where]
        if raw.get('q'):clauses.append('(t."Nom" ILIKE %s OR t."Email" ILIKE %s OR t."Telephone" ILIKE %s)');args.extend(['%'+raw['q']+'%']*3)
        if raw.get('type') in {'personne','entreprise'}:clauses.append('t."Nature"=%s');args.append(raw['type'])
        if raw.get('typeClientId'):
            clauses.append('t."ID_TypeClientFk"=%s');args.append(positive(raw['typeClientId']))
        if raw.get('archived')!='all':clauses.append('t."Actif"=%s');args.append(raw.get('archived')!='true')
        where=' AND '.join(clauses);take=min(200,max(1,positive(raw.get('take',25))));skip=max(0,int(raw.get('skip',0)))
        sort=raw.get('sortBy','Nom');sort=sort if sort in SORTS else 'Nom';direction='DESC' if raw.get('sortDir','').lower()=='desc' else 'ASC'
        count=db.one('SELECT count(*) AS n FROM logistique."V_Client" t WHERE '+where,args)['n']
        rows=db.query('SELECT t.* FROM logistique."V_Client" t WHERE '+where+' ORDER BY t.'+db.ident(sort)+' '+direction+',t."ID_Client" LIMIT %s OFFSET %s',[*args,take,skip])
        return ok(clean(rows),meta={'totalCount':count,'take':take,'skip':skip,'sortBy':sort,'sortDir':direction.lower()})
    def post(self,request):return self.write(request,None)
    def patch(self,request,pk):return self.write(request,pk)
    put=patch
    def delete(self,request,pk):return self.write(request,pk,archive=True)
    def write(self,request,pk,archive=False):
        db.ensure_writable();require_module(request.user,'logistique','manage');entity=require_entity(request.user)
        request_id=None;fingerprint=None
        if not pk:
            try:request_id=str(uuid.UUID(request.data.get('requestId')))
            except (ValueError,TypeError,AttributeError):raise APIError('Rouvrez le formulaire de création.','TIERS_REQUEST_INVALID',400)
            fingerprint=hashlib.sha256(json.dumps({key:value for key,value in request.data.items() if key!='requestId'},cls=ExactEncoder,sort_keys=True,separators=(',',':')).encode()).hexdigest()
        with transaction.atomic():
            if request_id:
                db.one('SELECT pg_advisory_xact_lock(hashtextextended(%s,0)) AS locked',['tiers:'+str(request.user.pk)+':'+str(entity)+':'+request_id])
                saved=db.one('''SELECT "NewData" AS proof FROM systeme."T_Audit_Log" WHERE "TableName"='logistique.T_Client' AND "Operation"='TIERS_CREATE' AND "NewData"->>'requestId'=%s AND "NewData"->'_actor'->>'IdUser'=%s ORDER BY "IdLog" DESC LIMIT 1''',[request_id,str(request.user.pk)])
                if saved:
                    proof=saved['proof']
                    if proof.get('IdEntiteFk')!=entity or not hmac.compare_digest(str(proof.get('payloadHash','')),fingerprint):raise APIError('Cette demande a déjà été enregistrée avec un autre contenu.','TIERS_REPLAY_CONFLICT',409)
                    row=record(request.user,proof['ID_Client']);return ok(clean(row),meta={**rights(request.user,row),'replayed':True})
            old=record(request.user,pk,lock=True) if pk else None
            if old:
                assert_document(request.user,old)
                # La révision porte sur la même fiche brute, indépendante des libellés du référentiel.
                shown=record(request.user,pk)
                if not isinstance(request.data.get('_version'),str) or not hmac.compare_digest(revision(shown),request.data['_version']):raise APIError('Ce tiers a changé. Rechargez sa fiche.','TIERS_CONFLICT',409)
            data=validate(request.user,{'Actif':False} if archive else request.data,old)
            if old:
                if data:
                    cols=list(data);db.one('UPDATE logistique."T_Client" SET '+','.join(db.ident(k)+'=%s' for k in cols)+',"ModifieParUserFk"=%s,"DateModification"=CURRENT_TIMESTAMP WHERE "ID_Client"=%s RETURNING "ID_Client"',[*[data[k] for k in cols],request.user.pk,old['ID_Client']])
                identifier=old['ID_Client']
            else:
                data.update(IdEntiteFk=entity,CreeParUserFk=request.user.pk,ModifieParUserFk=request.user.pk);cols=list(data)
                identifier=db.one('INSERT INTO logistique."T_Client" ('+','.join(map(db.ident,cols))+') VALUES ('+','.join(['%s']*len(cols))+') RETURNING "ID_Client"',[data[k] for k in cols])['ID_Client']
            row=record(request.user,identifier);audit(OBJ,'ARCHIVE' if archive else 'UPDATE' if old else 'INSERT',old=old,new=row,actor=request.user)
            if request_id:audit(OBJ,'TIERS_CREATE',new={'requestId':request_id,'payloadHash':fingerprint,'ID_Client':identifier,'IdEntiteFk':entity},actor=request.user)
            return ok(clean(row),status=200 if old else 201,meta=rights(request.user,row))

class TiersConsultationView(APIView):
    permission_classes=[IsERPAdmin]
    def get(self,request,pk,section='identite'):
        client=record(request.user,pk)
        if section=='identite':return ok(clean(client),meta=rights(request.user,client))
        if section not in {'bons','factures','reglements'}:raise APIError('Onglet introuvable.','NOT_FOUND',404)
        from apps.core.registry import view
        from .reads import read_page
        from .ledger_registers import source
        obj=source('reglements') if section=='reglements' else view('logistique','V_SuiviReglements' if section=='factures' else 'V_Commande')
        condition='"ID_TiersFk"='+str(positive(pk))
        if section=='factures':condition+=" AND \"CodeFacture\" IS NOT NULL AND btrim(\"CodeFacture\")<>''"
        rows,meta,_=read_page(obj,request.user,request.query_params.dict(),condition=condition)
        meta["totalCount"]=meta["filteredCount"]
        return ok(clean(rows),meta=meta)
