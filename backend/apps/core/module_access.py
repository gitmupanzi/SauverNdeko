"""Accès effectifs : licence, droits du rôle et restrictions individuelles."""
from django.conf import settings
from . import db
from .responses import APIError

WORKSPACE_MODULES = (
    {"key": "catalogue", "label": "Catalogue", "description": "Produits, structures et informations de santé.", "path": "/catalogue", "icon": "grid", "tone": "blue"},
    {"key": "produits", "label": "Produits", "description": "Rechercher et consulter les produits disponibles.", "path": "/produits", "icon": "capsule", "tone": "teal"},
    {"key": "structures", "label": "Structures", "description": "Pharmacies, dépôts et établissements.", "path": "/pharmacies", "icon": "hospital", "tone": "coral"},
    {"key": "professionnels", "label": "Professionnels", "description": "Consulter les profils des professionnels.", "path": "/experts", "icon": "people", "tone": "purple"},
    {"key": "discussions", "label": "Discussions", "description": "Retrouver vos échanges et messages.", "path": "/discussions", "icon": "chat-dots", "tone": "sky"},
    {"key": "logistique", "label": "Logistique", "description": "Articles, stock, bons et factures.", "path": "/logistique", "icon": "box-seam", "tone": "amber", "admin": True},
    {"key": "caisse", "label": "Caisse", "description": "Caisses, encaissements, décaissements et clôtures.", "path": "/caisse", "icon": "wallet2", "tone": "teal", "admin": True},
    {"key": "territoires", "label": "Organisation territoriale", "description": "Découpage administratif et pyramide sanitaire.", "path": "/territoires", "icon": "diagram-3", "tone": "teal", "admin": True},
    {"key": "support", "label": "Support", "description": "Incidents, assistance et réclamations.", "path": "/support", "icon": "headset", "tone": "sky"},
    {"key": "parametres", "label": "Paramètres", "description": "Entreprise, documents et fiscalité.", "path": "/parametres", "icon": "gear", "tone": "teal"},
    {"key": "guide", "label": "Guide utilisateur", "description": "Parcours, exemples et conseils pour vos applications.", "path": "/guide", "icon": "book", "tone": "sky"},
    {"key": "administration", "label": "Administration", "description": "Utilisateurs, organisations et paramètres.", "path": "/admin", "icon": "sliders", "tone": "slate", "admin": True},
)
MODULE_BY_KEY={item["key"]:item for item in WORKSPACE_MODULES}
PLATFORM_MODULES = {"territoires"}
PROTECTED_TABS = {
    "logistique": {
        "dashboard": "Tableau de bord", "dossiers": "Dossiers de suivi",
        "tiers": "Clients et fournisseurs", "depots": "Dépôts", "articles": "Articles",
        "lots": "Lots de stock", "stocks-depots": "Stocks par dépôt", "commandes": "Bons de stock",
        "details": "Lignes des bons", "transferts": "Transferts internes", "mouvements": "Mouvements de stock",
        "inventaires": "Inventaires", "factures": "Factures", "reglements": "Règlements",
        "immobilisations": "Immobilisations",
    },
    "caisse": {
        "tableau-de-bord": "Tableau de bord", "caisses": "Caisses",
        "ecritures": "Écritures", "clotures": "Clôtures",
        "saisie-ecritures": "Saisir les écritures de caisse",
        "modification-brouillons": "Modifier les brouillons de caisse",
        "validation-ecritures": "Valider les écritures de caisse",
        "parametres-validation": "Paramètres de validation de caisse",
    },
    "support": {"tableau-de-bord": "Tableau de bord", "tickets": "Tickets", "processus": "Suivi des étapes"},
    "administration": {
        "tableau-de-bord": "Tableau de bord", "utilisateurs": "Utilisateurs", "roles": "Rôles",
        "permissions": "Permissions", "entites": "Entreprises", "licences": "Licences",
        "correspondances": "Correspondances FK", "parametres": "Paramètres UI",
        "messagerie": "Messagerie", "audit": "Journaux d’audit", "connexions": "Connexions",
        "audit-parametres": "Historique des paramètres",
    },
    "discussions": {"messages": "Messages", "demandes": "Demandes", "annonces": "Annonces"},
    "professionnels": {"annuaire": "Annuaire", "profils": "Profils professionnels"},
}
RIGHT_FIELDS = {
    "canRead": "PeutConsulter",
    "canManage": "PeutGerer",
    "canExport": "PeutExporter",
}
ACTION_RIGHTS = {"read": "canRead", "manage": "canManage", "export": "canExport"}


def restrict(rights, rule):
    result = {name: bool(rights[name] and (rule is None or rule[field]))
              for name, field in RIGHT_FIELDS.items()}
    if not result["canRead"]:
        result["canManage"] = result["canExport"] = False
    return result


def individual_rule_rows(entity_id, user_id=None):
    if entity_id is None:
        return []
    if db.one("SELECT to_regclass(%s) AS relation", ['systeme."T_UtilisateurModule"'])["relation"] is None:
        raise APIError("Les permissions individuelles sont indisponibles.", "MODULE_CONFIGURATION_UNAVAILABLE", 503)
    sql = 'SELECT * FROM systeme."T_UtilisateurModule" WHERE "IdEntiteFk"=%s'
    return db.query(sql if user_id is None else sql + ' AND "IdUserFk"=%s',
                    [entity_id] if user_id is None else [entity_id, user_id])


def individual_rules(entity_id, user_id):
    return {(row["CodeModule"], row["CodeOnglet"]): row
            for row in individual_rule_rows(entity_id, user_id)}

# Socle initial utilisé par les fixtures. En service, les accès viennent de PostgreSQL.
BASE_MODULES = {"produits", "structures", "professionnels", "administration", "parametres", "guide"}
# Les activations historiques restent conservées en base ; seules les
# applications toujours livrées sont proposées et contrôlées par ce manifeste.
INCLUSIONS={"catalogue":{"produits","structures","professionnels"}}
OBJECT_MODULES={"operations":"caisse","logistique":"logistique","support":"support","professionnel":"professionnels","geolocalisation":"territoires","communication":"discussions","analytics":"administration","systeme":"administration"}

def storage_ready():
    names=['systeme."'+name+'"' for name in ("T_ModuleApplication","T_LicenceModule","T_RoleModule","V_LicenceModule","V_EntiteModuleActif","V_RoleModule")]
    return db.one("SELECT bool_and(to_regclass(x) IS NOT NULL) AS ready FROM unnest(%s::text[]) AS t(x)",[names])["ready"]


def application_metadata():
    """Classification commerciale persistante ; aucun changement d’habilitation."""
    rows=db.query('''SELECT "CodeModule","TypeApplication","Commercialisable","ModuleParentCode","AfficherDansEspace",
        "EstSocle","ReservePlateforme"
        FROM systeme."T_ModuleApplication" WHERE "CodeModule"=ANY(%s::text[])''',[list(MODULE_BY_KEY)])
    if len(rows)!=len(MODULE_BY_KEY):
        raise APIError('Le catalogue des applications est incomplet.','MODULE_CONFIGURATION_UNAVAILABLE',503)
    return {row['CodeModule']:{'type':row['TypeApplication'],'commercialisable':row['Commercialisable'],
                             'parentModule':row['ModuleParentCode'],
                             'showInWorkspace':row['AfficherDansEspace'],'base':row['EstSocle'],
                             'platformOnly':row['ReservePlateforme']} for row in rows}

def legacy_rights(actor,key):
    item=MODULE_BY_KEY[key]
    read = actor.global_admin if key in PLATFORM_MODULES else not item.get("admin") or actor.admin
    manage=key=="discussions" or (key in {"caisse","logistique","administration","support","parametres","professionnels","structures"} and actor.admin) or (key=="territoires" and actor.global_admin)
    return {"canRead":read,"canManage":manage and read,"canExport":read}

def access_snapshot(actor):
    cached=getattr(actor,"_module_access",None)
    if cached is not None:return cached
    restrictions = {} if actor.global_admin or actor.pk is None else individual_rules(actor.organisation, actor.pk)
    if actor.global_admin:
        metadata = application_metadata()
        modules = {
            key: {**legacy_rights(actor, key), "available": True, "base": metadata[key]["base"],
                  "reason": "", "includedBy": None}
            for key in MODULE_BY_KEY
        }
    else:
        if not storage_ready():raise APIError("La configuration des applications est indisponible.","MODULE_CONFIGURATION_UNAVAILABLE",503)
        rows=db.query('''SELECT m.*,r."IdRoleModule",r."PeutConsulter",r."PeutGerer",r."PeutExporter",r."Actif" AS "RegleActive",
         EXISTS(SELECT 1 FROM systeme."V_EntiteModuleActif" e WHERE e."IdEntiteFk"=%s AND e."CodeModule"=m."CodeModule") AS "Disponible",
         EXISTS(SELECT 1 FROM systeme."V_LicenceModule" l WHERE l."IdEntiteFk"=%s AND (l."CodeModule"=m."CodeModule" OR l."CodeModule"=m."CodeIncluant")) AS "LicenceConnue"
         FROM systeme."T_ModuleApplication" m LEFT JOIN systeme."T_RoleModule" r ON r."CodeModule"=m."CodeModule" AND r."IdEntiteFk"=%s AND r."IdRoleFk"=%s WHERE m."CodeModule"=ANY(%s::text[])''',[actor.organisation,actor.organisation,actor.organisation,actor.row.get("IdRoleFk"),list(MODULE_BY_KEY)])
        if len(rows)!=len(MODULE_BY_KEY):raise APIError("Le catalogue des applications est incomplet.","MODULE_CONFIGURATION_UNAVAILABLE",503)
        modules={}
        for row in rows:
            key = row["CodeModule"]
            reserved = row["ReservePlateforme"] or key in PLATFORM_MODULES
            rights = legacy_rights(actor, key)
            available = not reserved and row["Actif"] and (
                row["Disponible"] or (actor.organisation is None and row["AccessibleSansEntite"])
            )
            if row["IdRoleModule"] is not None:
                rights = {
                    "canRead": rights["canRead"] and row["RegleActive"] and row["PeutConsulter"],
                    "canManage": rights["canManage"] and row["RegleActive"] and row["PeutGerer"],
                    "canExport": rights["canExport"] and row["RegleActive"] and row["PeutExporter"],
                }
            rule = restrictions.get((key, ""))
            previous_read = rights["canRead"]
            rights = restrict(rights, rule)
            if reserved:
                reason = "PLATFORM_ADMIN_REQUIRED"
            elif available:
                reason = "" if rights["canRead"] else (
                    "MODULE_USER_FORBIDDEN" if previous_read else "MODULE_ROLE_FORBIDDEN"
                )
            elif not actor.organisation:
                reason = "ORGANISATION_REQUIRED"
            else:
                reason = "LICENCE_INACTIVE" if row["LicenceConnue"] else "MODULE_NOT_INCLUDED"
            modules[key] = {
                **{name: bool(value and available and rights["canRead"]) for name, value in rights.items()},
                "available": bool(available), "base": row["EstSocle"], "reason": reason,
                "includedBy": None if row["EstSocle"] else row["CodeIncluant"],
            }
    tabs = {
        key: {tab: restrict(modules[key], restrictions.get((key, tab))) for tab in protected}
        for key, protected in PROTECTED_TABS.items()
    }
    result={"platformAdmin":actor.global_admin,"entityId":actor.organisation,"readOnly":settings.DB_READ_ONLY,"modules":modules,"tabs":tabs}
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
    if key in PLATFORM_MODULES and not actor.global_admin:
        raise APIError("Accès réservé à l’administration de la plateforme.", "PLATFORM_ADMIN_REQUIRED", 403)
    item=access_snapshot(actor)["modules"].get(key)
    if not item:raise APIError("Application inconnue.","MODULE_NOT_FOUND",404)
    if not item["canRead"]:
        messages={"ORGANISATION_REQUIRED":"Votre compte doit être rattaché à une organisation.","LICENCE_INACTIVE":"La licence de votre organisation ne permet plus cet accès.","MODULE_NOT_INCLUDED":"Cette application n’est pas comprise dans l’offre de votre organisation.","MODULE_ROLE_FORBIDDEN":"Votre rôle ne permet pas l’accès à cette application.","MODULE_USER_FORBIDDEN":"Votre compte ne dispose pas de l’accès à cette application.","PLATFORM_ADMIN_REQUIRED":"Accès réservé à l’administration de la plateforme."}
        raise APIError(messages.get(item["reason"],"Accès à l’application refusé."),item["reason"] or "MODULE_ROLE_FORBIDDEN",403)
    if not item[ACTION_RIGHTS[action]]:
        raise APIError("Vous n’avez pas la permission d’effectuer cette opération.", "MODULE_ACTION_FORBIDDEN", 403)


def require_tab(actor, key, tab, action="read"):
    require_module(actor, key, action)
    if not can_use_tab(actor, key, tab, action):
        raise APIError("Vous n’avez pas la permission d’effectuer cette opération dans cet onglet.",
                       "TAB_ACTION_FORBIDDEN", 403)


def can_use_tab(actor, key, tab, action="read"):
    if tab not in PROTECTED_TABS.get(key, {}):
        return False
    snapshot = access_snapshot(actor)
    right = ACTION_RIGHTS[action]
    parent = snapshot["modules"].get(key, {})
    rights = snapshot.get("tabs", {}).get(key, {}).get(tab, parent)
    return bool(parent.get("canRead") and parent.get(right) and rights.get(right))


def can_read_tab(actor, key, tab):
    return can_use_tab(actor, key, tab)

def module_for_object(obj):
    if obj["schema"]=="systeme" and obj.get("name")=="V_Entite_Public":return "structures"
    return "referentiels" if obj["schema"]=="referentiel" else OBJECT_MODULES.get(obj["schema"],"administration")

def enforce_request(actor,request,view):
    path=request.path_info
    if path.startswith("/SauverNdeko/auth/") or path.rstrip("/") in {"/api/workspace/modules", "/api/workspace/catalogue"}:
        return
    kwargs=getattr(view,"kwargs",{})
    action="read" if request.method in {"GET","HEAD","OPTIONS"} or path.rstrip('/').endswith('/apercu') else "manage"
    if path.rstrip('/').endswith(('.xlsx','.csv','.pdf','.docx')):action="export"
    if (path.rstrip("/").endswith(("/modele-excel", "/modele.xlsx", "/import-excel"))
            or path.rstrip("/") == "/api/support/processus/import.xlsx"):
        action = "manage"
    if request.method in {"GET", "HEAD"} and path.startswith("/api/logistique/documents/") and kwargs.get("piece_id"):
        action = "export"
    from apps.logistique.tab_access import enforce_logistics_request
    if enforce_logistics_request(actor, request, view, action):
        return
    route = path.strip("/").split("/")
    if route[:2] == ["api", "workspace"] and len(route) > 2:
        admin_tab = {"roles": "permissions", "droits-utilisateurs": "permissions", "licences": "licences"}.get(route[2])
        if admin_tab:
            require_tab(actor, "administration", admin_tab, action)
            return
    if path.startswith('/api/public/'):
        kind=kwargs.get('kind')
        if kind=='chat/context':
            require_tab(actor, "discussions", "messages")
            target={'expert':'professionnels','structure':'structures'}.get(request.query_params.get('type'))
            if target == "professionnels":
                require_tab(actor, target, "annuaire")
            elif target:
                require_module(actor, target)
            return
        key={'stats':'catalogue','articles':'produits','pharmacies':'structures','experts':'professionnels'}.get(kind)
        if key == "professionnels":
            require_tab(actor, key, "annuaire", action)
            return
    elif path.startswith('/api/produits/'):
        key='produits'
    elif path.startswith('/api/structures/'):
        key='structures'
    elif path.startswith('/api/discussions'):
        key='discussions'
        group = route[2] if len(route) > 2 else ""
        tab = group if group in {"annonces", "demandes"} else "messages"
        # La lecture d’un fil met uniquement à jour le marqueur du compte.
        tab_action = "read" if route[-1] == "lecture" else action
        require_tab(actor, key, tab, tab_action)
        if tab == "demandes" and route[-1] == "discussion":
            require_tab(actor, key, "messages", action)
        if path.rstrip('/').endswith('/start'):
            kind = request.data.get("type") if hasattr(request.data, "get") else None
            target = {"expert": "professionnels", "structure": "structures"}.get(kind) if isinstance(kind, str) else None
            if target == "professionnels":
                require_tab(actor, target, "annuaire")
            elif target:
                require_module(actor, target)
        return
    elif path.startswith('/api/logistique/') or path.startswith(('/api/articles','/api/commandes')):key='logistique'
    elif path.rstrip('/') in {'/api/views','/api/models'}:key='referentiels'
    elif path.rstrip('/') in {'/api/systeme/admin-ui-settings','/api/admin-ui-settings'} and action=='read':key='referentiels'
    elif path.startswith('/api/geolocalisation/'):key='territoires'
    elif path.startswith('/api/support/'):key='support'
    elif path.startswith('/api/caisse/'):key='caisse'
    elif path.startswith('/api/professionnels/'):
        key = "professionnels"
        if len(route) > 2 and route[2] in PROTECTED_TABS[key]:
            require_tab(actor, key, route[2], action)
            return
    elif path.startswith('/api/parametres/'):key='parametres'
    elif path.startswith('/api/guide/'):
        # Le guide ne possède que des lectures : DRF refuse les autres méthodes.
        require_module(actor,'guide')
        return
    elif kwargs.get('schema'):
        enforce_object(actor, {"schema": kwargs["schema"], "name": kwargs.get("name")}, action)
        return
    elif kwargs.get('module') or kwargs.get('model_name'):
        obj,_=view.objects(kwargs.get('module'),kwargs.get('model_name'))
        if obj['name']=='T_Licence' and action=='manage' and not actor.global_admin:raise APIError("Les licences sont gérées par l’administration de la plateforme.","PLATFORM_ADMIN_REQUIRED",403)
        enforce_object(actor, obj, action)
        return
    elif path.startswith('/api/referentiel/'):key='referentiels'
    else:key='administration'
    require_module(actor,key,action)


def enforce_object(actor, obj, action="read"):
    key = module_for_object(obj)
    name = obj.get("name") or ""
    if key == "logistique":
        from apps.logistique.tab_access import enforce_logistics_object
        enforce_logistics_object(actor, name, action)
        return
    if key == "administration":
        from .admin_tabs import admin_tab_for_object, require_admin_tab
        tab = admin_tab_for_object(obj)
        if tab:
            require_admin_tab(actor, tab, action)
            return
    if key == "caisse":
        if not actor.global_admin:
            raise APIError("Utilisez le registre de cette application.", "TAB_ACTION_FORBIDDEN", 403)
        if name in {"V_SyntheseCaisseDevise", "V_FluxCaisseJournalier"}:
            for tab in ("tableau-de-bord", "caisses", "ecritures"):
                require_tab(actor, key, tab, action)
            return
        if name in {"T_Caisse", "V_Caisse"}:
            tab = "caisses"
        elif name in {"V_ClotureCaisse", "T_ClotureCaisse"}:
            tab = "clotures"
        else:
            tab = "ecritures"
        require_tab(actor, key, tab, action)
        return
    if key == "professionnels" and name == "V_Professionnel_Public":
        require_tab(actor, key, "annuaire", action)
        return
    if key in {"support", "discussions", "professionnels"} and not actor.global_admin:
        # Les API dédiées appliquent le périmètre des lignes et des champs.
        raise APIError("Utilisez le registre de cette application.", "TAB_ACTION_FORBIDDEN", 403)
    require_module(actor, key, action)
