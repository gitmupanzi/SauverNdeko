"""Applications : licence de l’entité, puis restrictions du rôle ; aucun abonnement individuel."""
from django.conf import settings
from . import db
from .responses import APIError

WORKSPACE_MODULES = (
    {"key": "catalogue", "label": "Catalogue", "description": "Produits, structures et informations de santé.", "path": "/catalogue", "icon": "grid", "tone": "blue"},
    {"key": "produits", "label": "Produits", "description": "Rechercher et consulter les produits disponibles.", "path": "/produits", "icon": "capsule", "tone": "teal"},
    {"key": "structures", "label": "Structures", "description": "Pharmacies, dépôts et établissements.", "path": "/pharmacies", "icon": "hospital", "tone": "coral"},
    {"key": "professionnels", "label": "Professionnels", "description": "Consulter les profils des professionnels.", "path": "/experts", "icon": "people", "tone": "purple"},
    {"key": "sante", "label": "Informations santé", "description": "Consulter les informations par maladie.", "path": "/maladies", "icon": "heart-pulse", "tone": "rose"},
    {"key": "discussions", "label": "Discussions", "description": "Retrouver vos échanges et messages.", "path": "/discussions", "icon": "chat-dots", "tone": "sky"},
    {"key": "logistique", "label": "Logistique", "description": "Articles, stock, bons et factures.", "path": "/logistique", "icon": "box-seam", "tone": "amber", "admin": True},
    {"key": "territoires", "label": "Organisation territoriale", "description": "Découpage administratif et pyramide sanitaire.", "path": "/territoires", "icon": "diagram-3", "tone": "teal", "admin": True},
    {"key": "support", "label": "Support", "description": "Incidents, assistance et réclamations.", "path": "/support", "icon": "headset", "tone": "sky"},
    {"key": "parametres", "label": "Paramètres", "description": "Entreprise, documents et fiscalité.", "path": "/parametres", "icon": "gear", "tone": "teal"},
    {"key": "guide", "label": "Guide utilisateur", "description": "Parcours, exemples et conseils pour vos applications.", "path": "/guide", "icon": "book", "tone": "sky"},
    {"key": "administration", "label": "Administration", "description": "Utilisateurs, organisations et paramètres.", "path": "/admin", "icon": "sliders", "tone": "slate", "admin": True},
)
MODULE_BY_KEY={item["key"]:item for item in WORKSPACE_MODULES}
BASE_MODULES={"discussions","territoires","administration","parametres","guide"}
INCLUSIONS={"catalogue":{"produits","structures","professionnels","sante"}}
OBJECT_MODULES={"logistique":"logistique","support":"support","professionnel":"professionnels","geolocalisation":"territoires","communication":"discussions","analytics":"administration","systeme":"administration"}

def storage_ready():
    names=['systeme."'+name+'"' for name in ("T_ModuleApplication","T_LicenceModule","T_RoleModule","V_LicenceModule","V_EntiteModuleActif","V_RoleModule")]
    return db.one("SELECT bool_and(to_regclass(x) IS NOT NULL) AS ready FROM unnest(%s::text[]) AS t(x)",[names])["ready"]

def legacy_rights(actor,key):
    item=MODULE_BY_KEY[key]
    read=not item.get("admin") or actor.admin
    manage=key=="discussions" or (key in {"logistique","administration","support","parametres"} and actor.admin) or (key=="territoires" and actor.global_admin)
    return {"canRead":read,"canManage":manage and read,"canExport":read}

def access_snapshot(actor):
    cached=getattr(actor,"_module_access",None)
    if cached is not None:return cached
    if actor.global_admin:
        modules={key:{**legacy_rights(actor,key),"available":True,"base":key in BASE_MODULES,"reason":"","includedBy":None} for key in MODULE_BY_KEY}
    else:
        if not storage_ready():raise APIError("La configuration des applications est indisponible.","MODULE_CONFIGURATION_UNAVAILABLE",503)
        rows=db.query('''SELECT m.*,r."IdRoleModule",r."PeutConsulter",r."PeutGerer",r."PeutExporter",r."Actif" AS "RegleActive",
         EXISTS(SELECT 1 FROM systeme."V_EntiteModuleActif" e WHERE e."IdEntiteFk"=%s AND e."CodeModule"=m."CodeModule") AS "Disponible",
         EXISTS(SELECT 1 FROM systeme."V_LicenceModule" l WHERE l."IdEntiteFk"=%s AND (l."CodeModule"=m."CodeModule" OR l."CodeModule"=m."CodeIncluant")) AS "LicenceConnue"
         FROM systeme."T_ModuleApplication" m LEFT JOIN systeme."T_RoleModule" r ON r."CodeModule"=m."CodeModule" AND r."IdEntiteFk"=%s AND r."IdRoleFk"=%s WHERE m."CodeModule"=ANY(%s::text[])''',[actor.organisation,actor.organisation,actor.organisation,actor.row.get("IdRoleFk"),list(MODULE_BY_KEY)])
        if len(rows)!=len(MODULE_BY_KEY):raise APIError("Le catalogue des applications est incomplet.","MODULE_CONFIGURATION_UNAVAILABLE",503)
        modules={}
        for row in rows:
            key=row["CodeModule"];rights=legacy_rights(actor,key);available=row["Actif"] and row["Disponible"]
            if row["IdRoleModule"] is not None:
                rights={"canRead":rights["canRead"] and row["RegleActive"] and row["PeutConsulter"],"canManage":rights["canManage"] and row["RegleActive"] and row["PeutGerer"],"canExport":rights["canExport"] and row["RegleActive"] and row["PeutExporter"]}
            reason="" if available and rights["canRead"] else "ORGANISATION_REQUIRED" if not actor.organisation else "LICENCE_INACTIVE" if not available and row["LicenceConnue"] else "MODULE_NOT_INCLUDED" if not available else "MODULE_ROLE_FORBIDDEN"
            modules[key]={**{name:bool(value and available and rights["canRead"]) for name,value in rights.items()},"available":bool(available),"base":row["EstSocle"],"reason":reason,"includedBy":row["CodeIncluant"]}
    result={"platformAdmin":actor.global_admin,"entityId":actor.organisation,"readOnly":settings.DB_READ_ONLY,"modules":modules}
    actor._module_access=result
    return result

def can_read(actor,key):
    return bool(access_snapshot(actor)["modules"].get(key,{}).get("canRead"))

def require_module(actor,key,action="read"):
    if key=="referentiels":
        values=access_snapshot(actor)["modules"].values()
        permission="canExport" if action=="export" else "canRead"
        if action=="manage":
            if not actor.global_admin:
                from .tenancy import read_entity
                if not actor.admin or read_entity(actor) is None or not any(item['canManage'] for item in values):
                    raise APIError("Votre rôle ne permet pas de gérer les références de cette entreprise.","MODULE_ACTION_FORBIDDEN",403)
                # La mutation vérifie ensuite la propriété de chaque ligne.
                # Les catalogues partagés et les correspondances physiques
                # conservent leur contrôle global dédié.
        elif not any(item[permission] for item in values):raise APIError("Aucune application ne permet cet accès.","MODULE_ROLE_FORBIDDEN",403)
        return
    item=access_snapshot(actor)["modules"].get(key)
    if not item:raise APIError("Application inconnue.","MODULE_NOT_FOUND",404)
    if not item["canRead"]:
        messages={"ORGANISATION_REQUIRED":"Votre compte doit être rattaché à une organisation.","LICENCE_INACTIVE":"La licence de votre organisation ne permet plus cet accès.","MODULE_NOT_INCLUDED":"Cette application n’est pas comprise dans l’offre de votre organisation.","MODULE_ROLE_FORBIDDEN":"Votre rôle ne permet pas l’accès à cette application."}
        raise APIError(messages.get(item["reason"],"Accès à l’application refusé."),item["reason"] or "MODULE_ROLE_FORBIDDEN",403)
    permission={"read":"canRead","manage":"canManage","export":"canExport"}[action]
    if not item[permission]:raise APIError("Votre rôle ne permet pas cette opération.","MODULE_ACTION_FORBIDDEN",403)

def module_for_object(obj):
    if obj["schema"]=="systeme" and obj.get("name")=="V_Entite_Public":return "structures"
    return "referentiels" if obj["schema"]=="referentiel" else OBJECT_MODULES.get(obj["schema"],"administration")

def enforce_request(actor,request,view):
    path=request.path
    if path.startswith(("/SauverNdeko/auth/","/api/workspace/")):return
    kwargs=getattr(view,"kwargs",{})
    action="read" if request.method in {"GET","HEAD","OPTIONS"} or path.rstrip('/').endswith('/apercu') else "manage"
    if path.rstrip('/').endswith(('.xlsx','.csv','.pdf','.docx')):action="export"
    if path.startswith('/api/public/'):
        kind=kwargs.get('kind')
        if kind=='chat/context':
            require_module(actor,'discussions')
            target={'expert':'professionnels','structure':'structures'}.get(request.query_params.get('type'))
            if target:require_module(actor,target)
            return
        key={'stats':'catalogue','articles':'produits','pharmacies':'structures','experts':'professionnels','maladies':'sante'}.get(kind)
    elif path.startswith('/api/discussions'):
        key='discussions'
        if path.rstrip('/').endswith('/start'):
            target={'expert':'professionnels','structure':'structures'}.get(request.data.get('type'))
            if target:require_module(actor,target)
    elif path.startswith('/api/logistique/') or path.startswith(('/api/articles','/api/commandes')):key='logistique'
    elif path.rstrip('/') in {'/api/views','/api/models'}:key='referentiels'
    elif path.rstrip('/') in {'/api/systeme/admin-ui-settings','/api/admin-ui-settings'} and action=='read':key='referentiels'
    elif path.startswith('/api/geolocalisation/'):key='territoires'
    elif path.startswith('/api/support/'):key='support'
    elif path.startswith('/api/parametres/'):key='parametres'
    elif path.startswith('/api/guide/'):
        # Le guide ne possède que des lectures : DRF refuse les autres méthodes.
        require_module(actor,'guide')
        return
    elif kwargs.get('schema'):key=module_for_object({'schema':kwargs['schema'],'name':kwargs.get('name')})
    elif kwargs.get('module') or kwargs.get('model_name'):
        obj,_=view.objects(kwargs.get('module'),kwargs.get('model_name'));key=module_for_object(obj)
        if obj['name']=='T_Licence' and action=='manage' and not actor.global_admin:raise APIError("Les licences sont gérées par l’administration de la plateforme.","PLATFORM_ADMIN_REQUIRED",403)
    elif path.startswith('/api/referentiel/'):key='referentiels'
    else:key='administration'
    require_module(actor,key,action)
