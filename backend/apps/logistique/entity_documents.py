"""Profil documentaire courant, distinct des identités historiques immuables."""
import hashlib,json,unicodedata,uuid
from django.conf import settings
from django.core.exceptions import ValidationError
from django.core.validators import validate_email
from django.db import transaction,IntegrityError
from psycopg.types.json import Jsonb
from rest_framework.views import APIView
from apps.core import db
from apps.core.module_access import require_module,access_snapshot
from apps.core.permissions import IsERPAdmin
from apps.core.repository import audit,clean
from apps.core.responses import APIError,ok
from apps.core.tenancy import require_entity
FIELDS={'NomEntite','AdresseEntite','EmailEntite','PhoneEntite','IdentifiantsLegauxEntite','MentionDocumentaireEntite'}
OPERATION='ENTITY_DOCUMENT_PROFILE'

def profile(actor):
    require_module(actor,'logistique','read');entity=require_entity(actor)
    row=db.one('SELECT * FROM systeme."V_IdentiteDocumentaire" WHERE "IdEntite"=%s',[entity])
    if not row:raise APIError('Entreprise introuvable.','NOT_FOUND',404)
    row['documentsExistants']=db.one('SELECT count(*) AS n FROM logistique."T_DocumentIdentite" WHERE "IdEntiteFk"=%s',[entity])['n']
    row['canConfigure']=actor.admin and not settings.DB_READ_ONLY and access_snapshot(actor)['modules']['logistique']['canManage']
    return clean(row)

def values(body):
    errors={};result={}
    def text(raw,key,maximum,required=False,multiline=False):
        if raw is None and not required:return None
        if not isinstance(raw,str):errors[key]='Renseignez une valeur texte.';return None
        if any(unicodedata.category(c) in {'Cc','Cs','Zl','Zp'} and not(multiline and c=='\n') for c in raw):errors[key]='Les caractères de contrôle sont interdits.';return None
        value=raw.strip()
        if len(value)>maximum or (required and not value):errors[key]=f'Utilisez entre 1 et {maximum} caractères.' if required else f'Utilisez au maximum {maximum} caractères.'
        return value or None
    for key,maximum in [('NomEntite',200),('AdresseEntite',1000),('EmailEntite',255),('PhoneEntite',20),('MentionDocumentaireEntite',1000)]:
        result[key]=text(body.get(key),key,maximum,key=='NomEntite',key in {'AdresseEntite','MentionDocumentaireEntite'})
    # EmailEntite est NOT NULL dans le schéma historique ; vide signifie non renseigné.
    result['EmailEntite']=result.get('EmailEntite') or ''
    if result.get('EmailEntite'):
        try:validate_email(result['EmailEntite'])
        except ValidationError:errors['EmailEntite']='Renseignez une adresse e-mail valide.'
    identifiers=body.get('IdentifiantsLegauxEntite');parsed=[];labels=set()
    if not isinstance(identifiers,list) or len(identifiers)>10:errors['IdentifiantsLegauxEntite']='Ajoutez au maximum dix identifiants.'
    else:
        for item in identifiers:
            if not isinstance(item,dict) or set(item)!={'libelle','valeur'}:errors['IdentifiantsLegauxEntite']='Renseignez un libellé et une valeur pour chaque identifiant.';continue
            label=text(item['libelle'],'IdentifiantsLegauxEntite',60,True);value=text(item['valeur'],'IdentifiantsLegauxEntite',180,True)
            if label and label.casefold() in labels:errors['IdentifiantsLegauxEntite']='Chaque libellé doit être unique.'
            if label:labels.add(label.casefold())
            parsed.append({'libelle':label,'valeur':value})
    result['IdentifiantsLegauxEntite']=parsed
    reason=text(body.get('motif'),'motif',1000,True,True)
    if errors:raise APIError(errors,'ENTITY_PROFILE_VALIDATION',400)
    return result,reason

def save(actor,body):
    require_module(actor,'logistique','manage');db.ensure_writable();entity=require_entity(actor)
    if not actor.admin:raise APIError('Ce réglage est réservé à l’administrateur de l’entreprise.','FORBIDDEN',403)
    if not isinstance(body,dict) or set(body)!=FIELDS|{'IdEntite','_version','motif','requestId'}:raise APIError('Demande d’identité documentaire invalide.')
    if type(body['IdEntite']) is not int or body['IdEntite']!=entity:raise APIError('L’entreprise active a changé. Rechargez la fiche.','ENTITY_MISMATCH',403)
    if not isinstance(body['_version'],str) or not 1<=len(body['_version'])<=120:raise APIError('Rechargez le profil avant de modifier.','ENTITY_PROFILE_VERSION',409)
    try:request_id=str(uuid.UUID(body['requestId']))
    except (ValueError,TypeError,AttributeError):raise APIError('Identifiant de demande invalide.')
    data,reason=values(body)
    fingerprint=hashlib.sha256(json.dumps({'entity':entity,'values':data,'motif':reason},sort_keys=True,ensure_ascii=False,separators=(',',':')).encode()).hexdigest()
    with transaction.atomic():
        # Sérialise les rejeux d’un même acteur, y compris entre entreprises.
        db.query('SELECT pg_advisory_xact_lock(hashtextextended(%s,0))',[OPERATION+':'+str(actor.pk)+':'+request_id])
        previous=db.one('SELECT "NewData" FROM systeme."T_Audit_Log" WHERE "Operation"=%s AND "NewData" @> %s ORDER BY "IdLog" DESC LIMIT 1',[OPERATION,Jsonb({'requestId':request_id,'_actor':{'IdUser':actor.pk}})])
        if previous:
            if previous['NewData'].get('fingerprint')!=fingerprint:raise APIError('Cette demande a déjà été utilisée avec un autre contenu.','REQUEST_CONFLICT',409)
            return profile(actor),True
        old=db.one('SELECT *,xmin::text AS "_version" FROM systeme."T_Entite" WHERE "IdEntite"=%s FOR UPDATE',[entity])
        if not old or old['_version']!=body['_version']:raise APIError('Le profil a changé. Rechargez la fiche avant de confirmer.','VERSION_CONFLICT',409)
        try:
            db.query('UPDATE systeme."T_Entite" SET "NomEntite"=%s,"AdresseEntite"=%s,"EmailEntite"=%s,"PhoneEntite"=%s,"IdentifiantsLegauxEntite"=%s,"MentionDocumentaireEntite"=%s WHERE "IdEntite"=%s',[data['NomEntite'],data['AdresseEntite'],data['EmailEntite'],data['PhoneEntite'],Jsonb(data['IdentifiantsLegauxEntite']),data['MentionDocumentaireEntite'],entity])
        except IntegrityError as error:
            if getattr(error.__cause__,'sqlstate',None)=='23505':
                constraint=getattr(getattr(error.__cause__,'diag',None),'constraint_name','') or ''
                key='PhoneEntite' if 'PhoneEntite' in constraint else 'EmailEntite'
                raise APIError({key:'Cette coordonnée est déjà utilisée. Vérifiez la valeur de cette entreprise.'},'ENTITY_PROFILE_VALIDATION',400) from error
            raise
        audit({'schema':'systeme','name':'T_Entite'},OPERATION,old={key:old.get(key) for key in FIELDS|{'IdEntite'}},new={**data,'IdEntite':entity,'motif':reason,'requestId':request_id,'fingerprint':fingerprint},actor=actor)
        return profile(actor),False

class EntityDocumentIdentityView(APIView):
    permission_classes=[IsERPAdmin]
    def get(self,request):
        if request.query_params:raise APIError('Aucun critère attendu pour le profil documentaire.')
        return ok(profile(request.user))
    def put(self,request):
        data,replayed=save(request.user,request.data)
        return ok(data,message='Identité de l’entreprise enregistrée.',meta={'replayed':replayed})
