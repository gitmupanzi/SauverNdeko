"""Gestion des modules par licence d’entité ; écriture réservée à la plateforme."""
from django.conf import settings
from django.db import transaction
from rest_framework.views import APIView
from apps.accounts.authentication import Actor
from . import db
from .permissions import IsERPAdmin
from .repository import positive, audit, clean
from .responses import APIError, ok
from .module_access import MODULE_BY_KEY, PLATFORM_MODULES, legacy_rights, storage_ready

def ready():
    if not storage_ready():raise APIError("La configuration des applications est indisponible.","MODULE_CONFIGURATION_UNAVAILABLE",503)

def entity_scope(actor,value=None):
    if actor.global_admin:
        if value in (None,""):value=actor.organisation
        if value in (None,""):raise APIError("Choisissez une organisation.")
        pk=positive(value)
    else:
        if not actor.organisation:raise APIError("Organisation requise.","ORGANISATION_REQUIRED",403)
        pk=positive(actor.organisation)
        if value not in (None,"") and positive(value)!=pk:raise APIError("Organisation non autorisée.","FORBIDDEN_SCOPE",403)
    if not db.one('SELECT "IdEntite" FROM systeme."T_Entite" WHERE "IdEntite"=%s',[pk]):raise APIError("Organisation introuvable.","NOT_FOUND",404)
    return pk

def catalogue_rows():
    ready()
    rows=db.query('SELECT * FROM systeme."T_ModuleApplication" WHERE "CodeModule"=ANY(%s::text[]) ORDER BY "Ordre","CodeModule"',[list(MODULE_BY_KEY)])
    if len(rows)!=len(MODULE_BY_KEY):raise APIError("Catalogue incomplet.","MODULE_CONFIGURATION_UNAVAILABLE",503)
    for row in rows:
        row.update({'type': row['TypeApplication'], 'commercialisable': row['Commercialisable'],
                    'parentModule': row['ModuleParentCode'], 'base': row['EstSocle'],
                    'platformOnly': row['ReservePlateforme']})
    return rows

def company_catalogue(rows):
    return [row for row in rows if not row["ReservePlateforme"] and row["CodeModule"] not in PLATFORM_MODULES
            and (row["AfficherDansEspace"] or row["Commercialisable"] or row["EstSocle"])]


def license_module_codes(rows):
    return [row["CodeModule"] for row in company_catalogue(rows)
            if row["Commercialisable"] and not row["EstSocle"] and row["Actif"]]


def license_configuration(actor, entity_id):
    entity_id = entity_scope(actor, entity_id)
    catalogue = company_catalogue(catalogue_rows())
    codes = license_module_codes(catalogue)
    licences = db.query(
        '''SELECT "IdLicence","IdEntiteFk","NomEntite","DateDebut","DateFin",statut_licence
           FROM systeme."V_Licence_active" WHERE "IdEntiteFk"=%s
           ORDER BY "DateFin" DESC,"IdLicence" DESC''', [entity_id],
    )
    bindings = db.query(
        '''SELECT * FROM systeme."V_LicenceModule" WHERE "IdEntiteFk"=%s
           AND "CodeModule"=ANY(%s::text[]) ORDER BY "IdLicenceFk","CodeModule"''',
        [entity_id, [row["CodeModule"] for row in catalogue if row["Commercialisable"]]],
    )
    effective = db.query(
        '''SELECT "CodeModule" FROM systeme."V_EntiteModuleActif"
           WHERE "IdEntiteFk"=%s AND "CodeModule"=ANY(%s::text[])''',
        [entity_id, codes],
    )
    for licence in licences:
        licence["activations"] = [row for row in bindings if row["IdLicenceFk"] == licence["IdLicence"]]
    return clean({"entityId": entity_id, "catalogue": catalogue, "licences": licences,
                  "moduleCodes": codes, "effectiveModules": [row["CodeModule"] for row in effective],
                  "canManage": actor.global_admin and not settings.DB_READ_ONLY})


def validate_versions(body,codes,current):
    versions=body.get("versions")
    if not isinstance(versions,dict) or set(versions)!=set(codes) or any(type(value) is not int or value<0 for value in versions.values()):raise APIError("Versions de configuration invalides.")
    expected={code:current.get(code,{}).get("Version",0) for code in codes}
    if versions!=expected:raise APIError("La configuration a changé. Rechargez-la avant d’enregistrer.","CONFLICT",409)

def platform_write(actor):
    if not actor.global_admin:raise APIError("Cette opération est réservée à l’administration de la plateforme.","PLATFORM_ADMIN_REQUIRED",403)
    db.ensure_writable();ready()

def save_license_modules(actor,licence_id,body):
    platform_write(actor)
    if not isinstance(body,dict) or set(body)!={"versions","enabled"}:raise APIError("Configuration de licence invalide.")
    enabled = body["enabled"]
    codes = license_module_codes(catalogue_rows())
    if not isinstance(enabled,list) or any(not isinstance(code,str) or code not in codes for code in enabled) or len(set(enabled))!=len(enabled):raise APIError("Liste d’applications invalide.")
    with transaction.atomic():
        licence=db.one('SELECT "IdLicence","IdEntiteFk" FROM systeme."T_Licence" WHERE "IdLicence"=%s FOR UPDATE',[positive(licence_id)])
        if not licence:raise APIError("Licence introuvable.","NOT_FOUND",404)
        current={row["CodeModule"]:row for row in db.query('SELECT * FROM systeme."V_LicenceModule" WHERE "IdLicenceFk"=%s',[licence["IdLicence"]])}
        validate_versions(body,codes,current)
        # Le socle et les rattachements historiques hors offre restent intacts.
        changed=[]
        for code in codes:
            active=code in enabled;old=current.get(code)
            if (old is None and not active) or (old and old["Actif"]==active):continue
            row=db.one('INSERT INTO systeme."T_LicenceModule" AS m ("IdLicenceFk","CodeModule","Actif","ModifieParUserFk") VALUES (%s,%s,%s,%s) ON CONFLICT ("IdLicenceFk","CodeModule") DO UPDATE SET "Actif"=EXCLUDED."Actif","ModifieParUserFk"=EXCLUDED."ModifieParUserFk" RETURNING *',[licence["IdLicence"],code,active,actor.pk]);changed.append(row)
        if changed:audit({"schema":"systeme","name":"T_LicenceModule"},"UPDATE",old={"licence":licence["IdLicence"],"modules":list(current.values())},new={"entityId":licence["IdEntiteFk"],"licence":licence["IdLicence"],"changes":changed},actor=actor)
        return license_configuration(actor,licence["IdEntiteFk"])

def entity_roles(entity_id):
    return db.query('''SELECT u."IdRoleFk",g."NomGenerique" AS "NomRole",bool_or(u."Is_staff" IS TRUE OR lower(COALESCE(g."NomGenerique",'')) IN ('admin','administrateur')) AS "Gestionnaire" FROM systeme."T_Utilisateurs" u JOIN referentiel."T_Generique" g ON g."ID_Generique"=u."IdRoleFk" WHERE u."IdEntiteFk"=%s AND u."Is_Admin" IS NOT TRUE AND u."ValideUser" GROUP BY u."IdRoleFk",g."NomGenerique" ORDER BY g."NomGenerique",u."IdRoleFk"''',[entity_id])

def role_baseline(role, entity_id, codes):
    representative=Actor({"IdUser":0,"IdRoleFk":role["IdRoleFk"],"RoleName":role["NomRole"],"Is_staff":role["Gestionnaire"],"Is_Admin":False,"IdEntiteFk":entity_id})
    return {key: legacy_rights(representative, key) for key in codes}

def role_configuration(actor,entity_id):
    entity_id=entity_scope(actor,entity_id);catalog=company_catalogue(catalogue_rows());roles=entity_roles(entity_id)
    codes = [row["CodeModule"] for row in catalog]
    rows=db.query('SELECT * FROM systeme."V_RoleModule" WHERE "IdEntiteFk"=%s',[entity_id])
    for role in roles:
        role["baseline"]=role_baseline(role, entity_id, codes)
        role["permissions"]=[row for row in rows if row["IdRoleFk"]==role["IdRoleFk"] and row["CodeModule"] in codes]
    return clean({"entityId":entity_id,"catalogue":catalog,"roles":roles,"canManage":actor.global_admin and not settings.DB_READ_ONLY})

def save_role_modules(actor,role_id,body):
    platform_write(actor)
    if not isinstance(body,dict) or set(body)!={"entityId","versions","permissions"}:raise APIError("Droits du rôle invalides.")
    entity_id=entity_scope(actor,body["entityId"]);role_id=positive(role_id)
    role=next((row for row in entity_roles(entity_id) if row["IdRoleFk"]==role_id),None)
    if not role:raise APIError("Rôle d’entreprise introuvable.","NOT_FOUND",404)
    permissions = body["permissions"]
    codes = [row["CodeModule"] for row in company_catalogue(catalogue_rows())]
    baseline = role_baseline(role, entity_id, codes)
    if not isinstance(permissions,dict) or set(permissions)!=set(codes):raise APIError("Applications du rôle invalides.")
    for code,rights in permissions.items():
        if not isinstance(rights,dict) or set(rights)!={"canRead","canManage","canExport"} or any(type(value) is not bool for value in rights.values()):raise APIError("Droits invalides.")
        if any(value and not baseline[code][key] for key,value in rights.items()):raise APIError("Ces droits dépassent les habilitations actuelles du rôle.","ROLE_LIMIT",403)
        if not rights["canRead"] and (rights["canManage"] or rights["canExport"]):raise APIError("La consultation est requise pour gérer ou exporter.")
    with transaction.atomic():
        db.one('SELECT "IdEntite" FROM systeme."T_Entite" WHERE "IdEntite"=%s FOR UPDATE',[entity_id])
        current={row["CodeModule"]:row for row in db.query('SELECT * FROM systeme."V_RoleModule" WHERE "IdEntiteFk"=%s AND "IdRoleFk"=%s',[entity_id,role_id])}
        validate_versions(body,codes,current);changed=[]
        for code,rights in permissions.items():
            old=current.get(code)
            if not old and rights==baseline[code]:continue
            if old and old["Actif"] and all(rights[key]==old[field] for key,field in (("canRead","PeutConsulter"),("canManage","PeutGerer"),("canExport","PeutExporter"))):continue
            row=db.one('INSERT INTO systeme."T_RoleModule" ("IdEntiteFk","IdRoleFk","CodeModule","PeutConsulter","PeutGerer","PeutExporter","ModifieParUserFk") VALUES (%s,%s,%s,%s,%s,%s,%s) ON CONFLICT ("IdEntiteFk","IdRoleFk","CodeModule") DO UPDATE SET "PeutConsulter"=EXCLUDED."PeutConsulter","PeutGerer"=EXCLUDED."PeutGerer","PeutExporter"=EXCLUDED."PeutExporter","Actif"=true,"ModifieParUserFk"=EXCLUDED."ModifieParUserFk" RETURNING *',[entity_id,role_id,code,rights["canRead"],rights["canManage"],rights["canExport"],actor.pk]);changed.append(row)
        if changed:audit({"schema":"systeme","name":"T_RoleModule"},"UPDATE",old={"entityId":entity_id,"role":role_id,"rules":list(current.values())},new={"entityId":entity_id,"role":role_id,"rules":changed},actor=actor)
        return role_configuration(actor,entity_id)

class OrganisationApplicationsView(APIView):
    permission_classes=[IsERPAdmin]
    def get(self,request):
        if request.query_params:raise APIError("Filtre non autorisé.")
        sql='SELECT "IdEntite","NomEntite","ValideEntite" FROM systeme."T_Entite"'
        if request.user.global_admin:rows=db.query(sql+' ORDER BY lower("NomEntite"),"IdEntite"')
        else:rows=db.query(sql+' WHERE "IdEntite"=%s',[entity_scope(request.user)])
        return ok(rows)

class LicenceApplicationsView(APIView):
    permission_classes=[IsERPAdmin]
    def get(self,request):
        if set(request.query_params)-{'entite'}:raise APIError("Filtre non autorisé.")
        return ok(license_configuration(request.user,request.query_params.get('entite')))

class LicenceModulesView(APIView):
    permission_classes=[IsERPAdmin]
    def put(self,request,pk):return ok(save_license_modules(request.user,pk,request.data))

class RoleApplicationsView(APIView):
    permission_classes=[IsERPAdmin]
    def get(self,request):
        if set(request.query_params)-{'entite'}:raise APIError("Filtre non autorisé.")
        return ok(role_configuration(request.user,request.query_params.get('entite')))
    def put(self,request,pk):return ok(save_role_modules(request.user,pk,request.data))
