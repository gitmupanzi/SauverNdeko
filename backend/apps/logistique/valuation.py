"""Valorisation CUMP : PostgreSQL calcule et journalise ; Python contrôle le périmètre."""
import hashlib
import json
import uuid
from decimal import Decimal,InvalidOperation
from tempfile import SpooledTemporaryFile
from zoneinfo import ZoneInfo
from datetime import datetime
from django.db import transaction,DatabaseError
from django.http import FileResponse
from rest_framework.views import APIView
from apps.core import db
from apps.core.module_access import require_module
from apps.core.permissions import IsERPAdmin
from apps.core.registry import view
from apps.core.repository import get_record,positive,audit,clean
from apps.core.responses import APIError,ok,ExactEncoder
from apps.core.tenancy import require_entity
from .excel import ExcelDownloadView,write_workbook,XLSX_MEDIA_TYPE


def article(actor,pk):
    if not actor.admin:raise APIError('Accès réservé aux gestionnaires.','FORBIDDEN',403)
    require_module(actor,'logistique')
    return get_record(view('logistique','V_Article'),actor,{'ID_Article':positive(pk)})


def revision(pk,devise,version):
    return db.one('SELECT logistique.fn_revision_valorisation(%s,%s,%s) AS revision',[pk,devise,version])['revision']


def snapshot(actor,pk,raw=None):
    record=article(actor,pk);raw=raw or {}
    if set(raw)-{'take','skip','deviseId'}:raise APIError('Critère de valorisation non autorisé.')
    try:take=int(raw.get('take',50));skip=int(raw.get('skip',0))
    except (ValueError,TypeError):raise APIError('Pagination invalide.')
    if take not in {10,25,50,100} or skip<0:raise APIError('Pagination invalide.')
    selected=positive(raw['deviseId']) if raw.get('deviseId') not in (None,'','all') else None
    # Un seul instantané SQL pour positions, révisions, historique et pagination.
    # La révision ne peut jamais décrire un stock postérieur aux nombres affichés.
    packet=db.one('''WITH source AS MATERIALIZED (
       SELECT m.* FROM logistique."T_Mouvement" m WHERE m."ID_ArticleFk"=%s
     ), positions AS (
       SELECT to_jsonb(p)||jsonb_build_object('Version',logistique.fn_revision_valorisation(p."ID_Article",p."ID_DeviseFk",p."Version"),
         'QuantiteArrete',p."QuantiteOuverture",'QuantiteOuverture',p."QteValorisee") AS row,p."DeviseCode",p."ID_DeviseFk"
       FROM logistique."V_ValorisationStock" p WHERE p."ID_Article"=%s
     ), movements AS (
       SELECT m.* FROM logistique."V_CoutMouvement" m WHERE m."ID_ArticleFk"=%s
       AND (%s::integer IS NULL OR m."ID_DeviseFk"=%s) ORDER BY m."ID_Mvt" DESC LIMIT %s OFFSET %s
     ), events AS (
       SELECT "ID_Evenement","ID_UserFk","Operation","Motif","CreeLe","Avant","Apres",
       (SELECT trim(concat_ws(' ',u."PrenomUser",u."NomUser")) FROM systeme."T_Utilisateurs" u WHERE u."IdUser"=e."ID_UserFk") AS "NomAuteur"
       FROM logistique."T_ValorisationEvenement" e WHERE "ID_ArticleFk"=%s
       AND "Operation" IN ('ouverture','reevaluation') ORDER BY "ID_Evenement" DESC LIMIT 30
     ) SELECT
       COALESCE((SELECT jsonb_agg(p.row ORDER BY p."DeviseCode",p."ID_DeviseFk") FROM positions p),'[]'::jsonb) AS positions,
       COALESCE((SELECT jsonb_agg(to_jsonb(m) ORDER BY m."ID_Mvt" DESC) FROM movements m),'[]'::jsonb) AS movements,
       COALESCE((SELECT jsonb_agg(to_jsonb(e) ORDER BY e."ID_Evenement" DESC) FROM events e),'[]'::jsonb) AS history,
       (SELECT count(*) FROM source m WHERE %s::integer IS NULL OR m."ID_DeviseFk"=%s) AS count''',
       [pk,pk,pk,selected,selected,take,skip,pk,selected,selected])
    positions=packet['positions']
    from django.conf import settings
    from apps.core.module_access import access_snapshot
    can_configure=actor.organisation==record['IdEntiteFk'] and actor.admin and not settings.DB_READ_ONLY and access_snapshot(actor)['modules']['logistique']['canManage']
    return clean({'article':{**{key:record.get(key) for key in ('ID_Article','NomArticle','IdEntiteFk','DeviseCode')},'AbrUnite':record.get('AbrUnite') or record.get('Unite')},'positions':positions,'movements':packet['movements'],'history':packet['history'],'canConfigure':can_configure,'pagination':{'filteredCount':packet['count'],'take':take,'skip':skip},'method':'CUMP permanent','order':'Ordre d’enregistrement','requiresOpening':any(p['EtatValorisation']=='À initialiser' for p in positions)})


def save(actor,pk,body):
    record=article(actor,pk);entity=require_entity(actor);require_module(actor,'logistique','manage');db.ensure_writable()
    if record['IdEntiteFk']!=entity:raise APIError('Choisissez l’entreprise propriétaire de cet article.','FORBIDDEN',403)
    if not isinstance(body,dict) or set(body)!={'deviseId','coutUnitaire','motif','_version','requestId'}:raise APIError('Demande de valorisation invalide.')
    try:
        currency=positive(body['deviseId']);request=str(uuid.UUID(body['requestId']));cost=Decimal(str(body['coutUnitaire']).replace(',','.'))
        if isinstance(body['coutUnitaire'],(bool,float)) or not cost.is_finite() or cost<0 or cost>Decimal('9999999999.999999') or cost!=cost.quantize(Decimal('0.000001')):raise ValueError()
        version=body['_version'];stored_version=int(str(version).split(':')[0])
        if not isinstance(version,str) or len(version)>120:raise ValueError()
    except (ValueError,TypeError,InvalidOperation,AttributeError):raise APIError('Indiquez un coût positif ou nul à six décimales au maximum.','VALUATION_VALIDATION',400)
    reason=body['motif']
    if not isinstance(reason,str) or not 1<=len(reason.strip())<=1000:raise APIError({'motif':'Précisez le motif de cette valorisation.'})
    try:
        with transaction.atomic():
            db.query('SELECT "ID_Article" FROM logistique."T_Article" WHERE "ID_Article"=%s AND "IdEntiteFk"=%s FOR UPDATE',[pk,entity])
            previous=db.one('SELECT * FROM logistique."T_ValorisationEvenement" WHERE "ID_UserFk"=%s AND "RequestId"=%s',[actor.pk,request])
            opening=db.one('SELECT "Version" FROM logistique."T_ValorisationOuverture" WHERE "ID_ArticleFk"=%s AND "ID_DeviseFk"=%s',[pk,currency])
            if not previous and revision(pk,currency,opening['Version'] if opening else 0)!=version:
                raise APIError('Le stock ou le coût a changé. Rechargez la fiche avant de confirmer.','VALUATION_CONFLICT',409)
            db.query('SELECT logistique.enregistrer_cout_ouverture(%s,%s,%s,%s,%s,%s,%s,%s,%s)',[pk,currency,cost,reason.strip(),actor.pk,stored_version,request,entity,version])
            if not previous:audit({'schema':'logistique','name':'T_ValorisationOuverture'},'CUMP_REVALUE',new={'ID_ArticleFk':pk,'ID_DeviseFk':currency,'CoutOuverture':cost,'motif':reason.strip(),'requestId':request},actor=actor)
    except DatabaseError as error:
        if getattr(error.__cause__,'sqlstate',None) in {'23505','40001','55P03','40P01'}:raise APIError('La demande entre en conflit avec une modification récente. Rechargez la fiche.','VALUATION_CONFLICT',409) from error
        raise
    return snapshot(actor,pk),bool(previous)


class ArticleValuationView(APIView):
    permission_classes=[IsERPAdmin]
    def get(self,request,pk):return ok(snapshot(request.user,positive(pk),request.query_params.dict()))
    def put(self,request,pk):
        data,replayed=save(request.user,positive(pk),request.data)
        return ok(data,message='Valorisation confirmée.',meta={'replayed':replayed})


class ArticleValuationExcelView(ExcelDownloadView):
    def get(self,request,pk):
        record=article(request.user,pk);require_module(request.user,'logistique','export')
        if set(request.query_params)-{'deviseId'}:raise APIError('Critère d’export non autorisé.')
        selected=positive(request.query_params['deviseId']) if request.query_params.get('deviseId') not in (None,'','all') else None
        condition=' AND \"ID_DeviseFk\"=%s' if selected else ''
        args=[positive(pk),selected] if selected else [positive(pk)]
        rows=db.query('SELECT * FROM logistique.\"V_CoutMouvement\" WHERE \"ID_ArticleFk\"=%s'+condition+' ORDER BY \"ID_Mvt\" LIMIT 200001',args)
        if len(rows)>200000:raise APIError('Affinez la période avant export.','EXPORT_LIMIT',413)
        fields=[('ID_Mvt','Mouvement','integer'),('CodeCmd','Bon de stock','text'),('DateMvt','Date et heure','timestamp without time zone'),('QteSignee','Quantité signée','numeric'),('CoutUnitaire','Coût unitaire','numeric'),('ValeurMouvement','Valeur du mouvement','numeric'),('StockApres','Stock après','numeric'),('ValeurApres','Valeur après','numeric'),('DeviseCode','Devise','text'),('OrigineCout','Source du coût','text'),('EtatValorisation','État','text')]
        columns=[{'column_name':k,'label':label,'data_type':kind,'is_nullable':'YES'} for k,label,kind in fields]
        zone=ZoneInfo('Africa/Kinshasa');stream=SpooledTemporaryFile(max_size=8*1024*1024,mode='w+b')
        context={'title':'Valorisation · '+record['NomArticle'],'scope':'Entreprise #'+str(record['IdEntiteFk']),'generated':datetime.now(zone).strftime('%d/%m/%Y %H:%M'),'zone':str(zone),'tz':zone,'source':'logistique.V_CoutMouvement','raw':{'articleId':pk,'deviseId':selected},'filters':{},'order':'ID_Mvt ASC','folder':None}
        try:count=write_workbook(stream,columns,rows,context);stream.seek(0)
        except Exception:stream.close();raise
        response=FileResponse(stream,as_attachment=True,filename='Valorisation_article_'+str(pk)+'.xlsx',content_type=XLSX_MEDIA_TYPE)
        response['X-Export-Row-Count']=str(count);response['Cache-Control']='no-store, private';return response
