"""Créations administratives atomiques et contrôle des comptes par entreprise.

Les rôles et réglages structurants restent gérés par la plateforme. Aucune
copie de rôle ni de privilège n'est créée pour un gestionnaire d'entreprise.
"""
import hashlib
import hmac
import json
import re
import uuid
import unicodedata
from django.conf import settings
from django.core.exceptions import ValidationError
from django.core.validators import validate_email
from django.db import DatabaseError, transaction
from django.views.decorators.debug import sensitive_variables
from rest_framework.views import APIView
from . import db
from .module_access import RIGHT_FIELDS, access_snapshot, require_module
from .admin_tabs import can_use_admin_tab, require_admin_tab
from .permissions import IsERPAdmin
from .responses import APIError, ExactEncoder, ok
from .tenancy import read_entity, require_entity

TABLES={'utilisateurs':'T_Utilisateurs','roles':'T_Generique','correspondances':'T_Fk_Correspondance','parametres':'T_Admin_UI_Setting'}
USER_FIELDS={'NomUser','PrenomUser','EmailUser','MotdepasseUser','PhoneUser','SexeUser','ValideUser','Is_staff','Is_Admin','IdEntiteFk','IdRoleFk','MatriculeUser','ID_ServiceFk','ID_FonctionFk','DateEmbauche','DateFinEmploi','ObservationProfessionnelle'}
ROLE_FIELDS={'NomGenerique','AbrGenerique','ObsGenerique','ValideGenerique','ID_CategorieGeneriqueFk'}
TECHNICAL={'IdUser','ID_Generique','IdFkCorrespondance','IdAdminUISetting','CreatedAt','UpdatedAt','UpdatedByUserFk','DatecreationUser','DateModificationUser','UrlPhoto','IdChampReferentielFk'}
PRIVILEGED_ROLES={'admin','administrateur','super-admin','super admin','superadmin','administrateur global','administrateur de la plateforme'}

def privileged_user(row):
    if row.get('Is_Admin') is True or row.get('Is_staff') is True:return True
    role=row.get('RoleName')
    if role is None and row.get('IdRoleFk'):
        found=db.one('SELECT "NomGenerique" FROM referentiel."T_Generique" WHERE "ID_Generique"=%s',[row['IdRoleFk']]);role=(found or {}).get('NomGenerique')
    return str(role or '').strip().casefold() in PRIVILEGED_ROLES

def check_user_grant_ceiling(actor, entity, role_id, user_id=None):
    from apps.accounts.authentication import Actor

    target = Actor({"IdUser": user_id, "IdEntiteFk": entity, "IdRoleFk": role_id})
    requester = access_snapshot(actor)
    granted = access_snapshot(target)
    for module, rights in granted["modules"].items():
        own_rights = requester["modules"].get(module, {})
        own_tabs = requester.get("tabs", {}).get(module, {})
        if any(rights[key] and not own_rights.get(key) for key in RIGHT_FIELDS) or any(
            tab_rights[key] and not own_tabs.get(tab, {}).get(key)
            for tab, tab_rights in granted["tabs"].get(module, {}).items()
            for key in RIGHT_FIELDS
        ):
            raise APIError(
                "Le compte ne peut pas recevoir des droits que vous ne possédez pas.",
                "USER_GRANT_EXCEEDS_OWN", 403,
            )


@sensitive_variables()
def user_change(actor, body, old=None, operation='create'):
    """Appelé par le dépôt, donc également sur les anciennes routes de CRUD."""
    from apps.accounts.authentication import email_in_use
    from .repository import positive
    from .personnel import validate_professional_fields
    require_admin_tab(actor, 'utilisateurs', 'manage')
    body=dict(body or {}); unknown=set(body)-USER_FIELDS
    if unknown:raise APIError({next(iter(unknown)):'Ce champ du compte ne peut pas être saisi.'},'ADMIN_USER_VALIDATION',422)
    if body.get('IdRoleFk') is not None:
        try:body['IdRoleFk']=positive(body['IdRoleFk'],'Rôle')
        except APIError:raise APIError({'IdRoleFk':'Choisissez un rôle de la liste.'},'ADMIN_USER_VALIDATION',422)
    if old and old['IdUser']==actor.pk and (operation=='delete' or body.get('ValideUser') is False or body.get('Is_Admin') is False and actor.global_admin):
        raise APIError('Votre propre compte et son accès doivent rester actifs.','SELF_PROTECTION',409)
    effective={**(old or {}),**body}
    if not actor.global_admin:
        entity=require_entity(actor)
        if old and (old.get('IdEntiteFk')!=entity or privileged_user(old)):
            raise APIError('Ce compte est réservé à l’administration de la plateforme.','PROTECTED_USER',403)
        if 'IdEntiteFk' in body and body['IdEntiteFk'] is not None and positive(body['IdEntiteFk'])!=entity:
            raise APIError('Le compte doit appartenir à votre entreprise.','ENTITY_MISMATCH',403)
        if old and operation != "delete":
            email = body.get("EmailUser")
            if isinstance(email, str) and email.strip() == old.get("EmailUser"):
                body.pop("EmailUser")
            if {"EmailUser", "MotdepasseUser"} & body.keys():
                raise APIError(
                    "La modification des identifiants de connexion est réservée au titulaire du compte ou à la plateforme.",
                    "USER_CREDENTIALS_PROTECTED", 403,
                )
        for key in ('Is_Admin','Is_staff'):
            if key in body and body[key] is not False:raise APIError('La délégation de privilèges est réservée à la plateforme.','PRIVILEGE_ESCALATION',403)
        if privileged_user(effective):raise APIError('Choisissez un rôle sans privilège d’administration.','PRIVILEGE_ESCALATION',403)
        role_id = effective.get("IdRoleFk")
        if old is None or role_id != old.get("IdRoleFk"):
            check_user_grant_ceiling(actor, entity, role_id, old["IdUser"] if old else None)
        body.update(IdEntiteFk=entity,Is_staff=False,Is_Admin=False)
    elif read_entity(actor) is not None and effective.get('IdEntiteFk') is not None and positive(effective['IdEntiteFk'])!=read_entity(actor):
        raise APIError('Choisissez un compte de l’entreprise active.','ENTITY_MISMATCH',403)
    if old and old.get('Is_Admin') is True and old.get('ValideUser') is True and (operation=='delete' or effective.get('ValideUser') is False or effective.get('Is_Admin') is not True):
        db.query('SELECT pg_advisory_xact_lock(hashtextextended(%s,0))',['admin-active-platform-users'])
        count=db.one('SELECT count(*) AS n FROM systeme."T_Utilisateurs" WHERE "Is_Admin" IS TRUE AND "ValideUser" IS TRUE')['n']
        if count<=1:raise APIError('Conservez au moins un administrateur actif de la plateforme.','LAST_PLATFORM_ADMIN',409)
    if operation!='delete':
        if old is None and not effective.get('IdEntiteFk') and effective.get('Is_Admin') is not True:
            raise APIError({'IdEntiteFk':'Choisissez l’entreprise du compte.'},'ADMIN_USER_VALIDATION',422)
        errors={}
        for field in ('NomUser','PrenomUser'):
            if old is None or field in body:
                value=body.get(field)
                if not isinstance(value,str) or not value.strip():errors[field]='Renseignez ce champ.'
                elif len(value.strip())>100 or any(unicodedata.category(char) in {'Cc','Cs','Zl','Zp'} for char in value):errors[field]='Utilisez au maximum 100 caractères, sans caractère de contrôle.'
                else:body[field]=value.strip()
        if old is None or 'EmailUser' in body:
            value=body.get('EmailUser')
            try:
                if not isinstance(value,str):raise ValidationError('email')
                value=value.strip();validate_email(value)
                if len(value)>150:raise ValidationError('email')
            except ValidationError:errors['EmailUser']='Renseignez une adresse e-mail valide.'
            else:
                if email_in_use(value, old["IdUser"] if old else None):
                    errors["EmailUser"] = "Cette adresse e-mail est déjà utilisée."
                body['EmailUser']=value
        if old is None or 'MotdepasseUser' in body:
            password=body.get('MotdepasseUser')
            if not isinstance(password,str) or not 12<=len(password)<=4096:errors['MotdepasseUser']='Utilisez un mot de passe de 12 à 4096 caractères.'
            elif any(unicodedata.category(char)=='Cs' for char in password):errors['MotdepasseUser']='Utilisez des caractères valides pour le mot de passe.'
        for key in ('ValideUser','Is_staff','Is_Admin'):
            if key in body and type(body[key]) is not bool:errors[key]='Choisissez Oui ou Non.'
        if old is None or 'SexeUser' in body:
            if body.get('SexeUser') not in {'M','F'}:errors['SexeUser']='Choisissez une valeur de la liste.'
        if errors:raise APIError(errors,'ADMIN_USER_VALIDATION',422)
    return validate_professional_fields(body)

def management(actor,kind):
    require_admin_tab(actor, kind)
    return (not settings.DB_READ_ONLY and actor.admin and (kind == 'utilisateurs' or actor.global_admin)
            and can_use_admin_tab(actor, kind, 'manage'))

def references(actor,kind):
    from .field_references import reference_context,reference_options
    if kind not in {*TABLES, 'entites', 'licences', 'connexions'}:
        raise APIError('Saisie indisponible.','NOT_FOUND',404)
    require_admin_tab(actor, kind)
    entity = read_entity(actor)
    result = {'entityId': entity, 'platformAdmin': actor.global_admin,
              'canCreate': kind in TABLES and management(actor, kind)}
    if entity is None and not actor.global_admin:raise APIError('Votre compte doit être rattaché à une entreprise.','ORGANISATION_REQUIRED',403)
    result['entities']=db.query('SELECT "IdEntite" AS id,"NomEntite" AS label,"ValideEntite" AS active FROM systeme."T_Entite"'+(' WHERE "IdEntite"=%s' if entity is not None else '')+' ORDER BY lower("NomEntite"),"IdEntite"',[entity] if entity is not None else [])
    if kind in {'roles','utilisateurs'}:
        result['roleCategoryIds']=reference_context(actor,'systeme','T_Utilisateurs','IdRoleFk')['categoryIds']
        result['roleCategoryId']=next(iter(result['roleCategoryIds']),None)
        choices=reference_options(actor,'systeme','T_Utilisateurs','IdRoleFk')
        result['roles']=[row for row in choices if actor.global_admin or not privileged_user({'IdRoleFk':row['id']})]
    if kind=='utilisateurs':
        result['personnelServices']=reference_options(actor,'systeme','T_Utilisateurs','ID_ServiceFk')
        result['personnelFonctions']=reference_options(actor,'systeme','T_Utilisateurs','ID_FonctionFk')
    if kind=='correspondances':
        result['categories']=db.query('SELECT "ID_CategorieGenerique" AS id,"NomCategorieGenerique" AS label FROM referentiel."T_CategorieGenerique" WHERE "ValideCategorieGenerique" IS TRUE AND ("IdEntiteFk" IS NULL OR "IdEntiteFk"=%s) ORDER BY label',[entity])
    result['referenceOptions'] = {'roles': result.get('roles', [])}
    if kind == 'entites':
        result['referenceOptions']['entityTypes'] = reference_options(actor, 'systeme', 'T_Entite', 'IdTypeEntiteFk')
    if kind == 'licences':
        result['referenceOptions']['licenseStatuses'] = reference_options(actor, 'systeme', 'T_Licence', 'IdStatutLicenceFk')
    result['entities']=[{**row,'IdEntite':row['id'],'NomEntite':row['label'],'ValideEntite':row['active']} for row in result['entities']]
    if 'categories' in result:result['categories']=[{**row,'ID_CategorieGenerique':row['id'],'NomCategorieGenerique':row['label'],'ValideCategorieGenerique':True} for row in result['categories']]
    return result

def prepare(kind,data,actor):
    from .registry import model
    from .repository import positive
    if not isinstance(data,dict):raise APIError('Les champs de la ligne doivent former un objet.')
    allowed=USER_FIELDS if kind=='utilisateurs' else ROLE_FIELDS if kind=='roles' else {c['column_name'] for c in model(TABLES[kind])['columns']}-TECHNICAL
    if set(data)-allowed:raise APIError({next(iter(set(data)-allowed)):'Champ non autorisé.'},'ADMIN_BATCH_VALIDATION',422)
    data=dict(data)
    required = {'parametres': ('SettingKey',), 'correspondances': ('ModuleName','SchemaName','SourceKey','FieldName','MappingType','MappingValue')}.get(kind,())
    issues={key:'Renseignez ce champ.' for key in required if not isinstance(data.get(key),str) or not data[key].strip()}
    if issues:raise APIError(issues,'ADMIN_BATCH_VALIDATION',422)
    for key in required:data[key]=data[key].strip()
    if kind=='roles':
        from .field_references import reference_context
        categories=reference_context(actor,'systeme','T_Utilisateurs','IdRoleFk')['categoryIds']
        category=data.get('ID_CategorieGeneriqueFk')
        if category is None and len(categories)==1:category=categories[0]
        if category not in categories:raise APIError({'ID_CategorieGeneriqueFk':'Choisissez la famille de rôles autorisée.'},'ADMIN_BATCH_VALIDATION',422)
        data['ID_CategorieGeneriqueFk']=category;data['IdEntiteFk']=None
    if kind in {'correspondances','parametres'}:
        scope=data.get('SettingScope','global');value=data.get('ScopeValue');entity=read_entity(actor)
        if scope in {'entity','entite'}:
            value=positive(value,'Entreprise')
            if entity is not None and value!=entity:raise APIError('Le réglage doit cibler l’entreprise active.','ENTITY_MISMATCH',403)
            if not db.one('SELECT "IdEntite" FROM systeme."T_Entite" WHERE "IdEntite"=%s',[value]):raise APIError('Entreprise introuvable.')
            data['ScopeValue']=str(value)
        elif scope=='global':
            if value not in (None,''):raise APIError('La portée globale ne comporte pas de contexte.')
            data['ScopeValue']=None
        elif entity is not None:raise APIError('Ce contexte ne peut être créé depuis une entreprise sélectionnée.','ENTITY_MISMATCH',403)
        if kind=='parametres':data['IsSystem']=False
    return data

def save_batch(actor,kind,body):
    from .registry import model
    from .repository import mutate,audit
    if kind not in TABLES:raise APIError('Saisie indisponible.','NOT_FOUND',404)
    require_admin_tab(actor, kind, 'manage')
    db.ensure_writable()
    if not management(actor,kind):raise APIError('Création réservée à l’administration autorisée.','PLATFORM_ADMIN_REQUIRED',403)
    if not isinstance(body,dict) or set(body)!={'requestId','rows'}:raise APIError('Le panier attend son identifiant et ses lignes.')
    try:request_id=str(uuid.UUID(body['requestId']))
    except (ValueError,TypeError,AttributeError):raise APIError('Identifiant de demande invalide.')
    rows=body['rows'];issues={}
    if not isinstance(rows,list) or not 1<=len(rows)<=100:raise APIError({'header':{'rows':'Ajoutez de 1 à 100 lignes.'},'rows':{}},'ADMIN_BATCH_VALIDATION',422)
    ids=[]
    for row in rows:
        if not isinstance(row,dict) or set(row)!={'clientRowId','data'} or not isinstance(row['clientRowId'],str) or not re.fullmatch(r'[A-Za-z0-9_-]{1,100}',row['clientRowId']) or row['clientRowId'] in ids:raise APIError('Les clés de lignes doivent être distinctes et valides.')
        ids.append(row['clientRowId'])
    try:raw=json.dumps({'body':body,'entity':read_entity(actor),'kind':kind},cls=ExactEncoder,sort_keys=True,separators=(',',':')).encode()
    except (UnicodeError,TypeError,ValueError):raise APIError('Le contenu du panier doit être un JSON UTF-8 valide.')
    if len(raw)>4*1024*1024:raise APIError('Le panier dépasse 4 Mo.')
    digest=hmac.new(settings.SECRET_KEY.encode(),raw,hashlib.sha256).hexdigest()
    table=TABLES[kind];obj=model(table);audit_name=table if kind in {'correspondances','parametres'} else obj['schema']+'.'+table
    with transaction.atomic():
        db.query('SELECT pg_advisory_xact_lock(hashtextextended(%s,0))',['admin-batch:'+str(actor.pk)+':'+request_id])
        prior=db.one('SELECT "NewData" proof FROM systeme."T_Audit_Log" WHERE "TableName"=%s AND "Operation"=%s AND "NewData"->>\'requestId\'=%s AND "NewData"#>>\'{_actor,IdUser}\'=%s ORDER BY "IdLog" DESC LIMIT 1',[audit_name,'ADMIN_BATCH_CREATE',request_id,str(actor.pk)])
        if prior:
            proof=prior['proof']
            if not hmac.compare_digest(proof.get('payloadHash',''),digest):raise APIError('Cette demande a déjà été utilisée avec un autre contenu.','ADMIN_BATCH_CONFLICT',409)
            return proof['response'],True
        records=[]
        for row in rows:
            try:
                with transaction.atomic():saved=mutate(table,actor,prepare(kind,row['data'],actor))
            except APIError as error:
                if error.status_code in (401,403,503):raise
                issues[row['clientRowId']]=dict(error.detail) if isinstance(error.detail,dict) else {'_line':str(error.detail)}
            except DatabaseError as error:
                if getattr(error.__cause__,'sqlstate',None) not in {'23502','23503','23505','23514','22001','22003','P0001'}:raise
                issues[row['clientRowId']]={'_line':'Vérifiez les références, les champs obligatoires et les doublons de cette ligne.'}
            else:records.append({'clientRowId':row['clientRowId'],**saved})
        if issues:raise APIError({'rows':issues,'header':{}},'ADMIN_BATCH_VALIDATION',422)
        result={'requestId':request_id,'count':len(records),'records':records}
        audit(obj,'ADMIN_BATCH_CREATE',new={'requestId':request_id,'payloadHash':digest,'response':result},actor=actor)
        return result,False

class AdminBatchView(APIView):
    permission_classes=[IsERPAdmin]
    def post(self,request,kind):
        data,replayed=save_batch(request.user,kind,request.data)
        return ok(data,status=200 if replayed else 201,meta={'replayed':replayed})

class AdminReferencesView(APIView):
    permission_classes=[IsERPAdmin]
    def get(self,request,kind):
        if request.query_params:raise APIError('Aucun critère attendu.')
        return ok(references(request.user,kind))

class AdminEntitiesView(APIView):
    permission_classes=[IsERPAdmin]
    def get(self,request):
        require_module(request.user,'administration')
        if request.query_params:raise APIError('Aucun critère attendu.')
        entity=read_entity(request.user)
        if entity is None and not request.user.global_admin:raise APIError('Votre compte doit être rattaché à une entreprise.','ORGANISATION_REQUIRED',403)
        rows=db.query('SELECT "IdEntite" AS id,"NomEntite" AS label,"ValideEntite" AS active FROM systeme."T_Entite"'+(' WHERE "IdEntite"=%s' if entity is not None else '')+' ORDER BY lower("NomEntite"),"IdEntite"',[entity] if entity is not None else [])
        return ok(rows,meta={'canCreate':not settings.DB_READ_ONLY and can_use_admin_tab(request.user, 'entites', 'manage'),'entityId':entity})
