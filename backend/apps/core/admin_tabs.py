"""Autorisation des registres administratifs et de leurs alias historiques."""
from .responses import APIError

ADMIN_GLOBAL_TABS = frozenset({"audit", "connexions", "audit-parametres", "permissions", "messagerie"})
ADMIN_TAB_ALIASES = {"profils": "utilisateurs", "localisations": "entites"}
SYSTEM_OBJECT_TABS = {
    "T_Utilisateurs": "utilisateurs",
    "V_User_profil": "utilisateurs",
    "V_User_Affectation": "utilisateurs",
    "T_Entite": "entites",
    "T_Entite_Localisation": "entites",
    "V_Entite_Localisation_Detail": "entites",
    "V_IdentiteDocumentaire": "entites",
    "T_Licence": "licences",
    "V_Licence_active": "licences",
    "T_Audit_Log": "audit",
    "V_Audit_log": "audit",
    "T_Login": "connexions",
    "V_Login_history": "connexions",
    "T_Fk_Correspondance": "correspondances",
    "V_Fk_Correspondance": "correspondances",
    "V_Fk_Correspondance_Detail": "correspondances",
    "V_Fk_Correspondance_Audit": "correspondances",
    "T_Admin_UI_Setting": "parametres",
    "V_Admin_UI_Setting": "parametres",
    "V_Admin_UI_Setting_Group": "parametres",
    "V_Admin_UI_Setting_Audit": "audit-parametres",
}


def admin_tab_for_object(obj):
    return SYSTEM_OBJECT_TABS.get(obj.get("name")) if obj.get("schema") == "systeme" else None


def can_use_admin_tab(actor, tab, action="read"):
    from .module_access import can_use_tab

    tab = ADMIN_TAB_ALIASES.get(tab, tab)
    return (tab not in ADMIN_GLOBAL_TABS or actor.global_admin) and can_use_tab(
        actor, "administration", tab, action,
    )


def require_admin_tab(actor, tab, action="read"):
    from .module_access import require_tab

    tab = ADMIN_TAB_ALIASES.get(tab, tab)
    if tab in ADMIN_GLOBAL_TABS and not actor.global_admin:
        raise APIError("Registre réservé à l’administration de la plateforme.", "PLATFORM_ADMIN_REQUIRED", 403)
    require_tab(actor, "administration", tab, action)
