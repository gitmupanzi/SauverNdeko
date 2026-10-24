from rest_framework.permissions import BasePermission
from .responses import APIError


class IsERPAdmin(BasePermission):
    message = "Accès réservé aux gestionnaires autorisés."

    def has_permission(self, request, view):
        return bool(request.user and request.user.admin)


def scope_for(obj, actor, alias="v"):
    """Retourne SQL + valeurs. Aucune donnée sans propriétaire pour un gestionnaire local.
    Limite héritée : l’organisation est celle du créateur actuel, faute de FK immuable sur les objets.
    """
    schema, name = obj["schema"], obj["name"]
    a = alias
    if actor.global_admin:
        return "TRUE", []
    if schema in {"geolocalisation", "referentiel"}:
        return "TRUE", []
    if not actor.organisation:
        raise APIError("Organisation requise.", "ORGANISATION_REQUIRED", 403)
    org = actor.organisation
    columns = {x["column_name"] for x in obj["columns"]}
    if (
        name in {"T_Entite", "V_Entite", "V_Entite_Localisation_Detail"}
        and "IdEntite" in columns
    ):
        return f'{a}."IdEntite"=%s', [org]
    for field in ["IdEntiteFk", "ID_EntiteFk"]:
        if field in columns:
            return f'{a}."{field}"=%s', [org]
    if schema == "systeme" and {"SettingScope", "ScopeValue"}.issubset(columns):
        return f'{a}."SettingScope"=%s AND {a}."ScopeValue"=%s', ["entity", str(org)]
    if name == "V_User_profil":
        return f'{a}."IdEntite"=%s', [org]
    if name in {
        "T_Article",
        "V_Article",
        "T_Commande",
        "V_Commande",
        "V_CommandesSansDetails",
        "V_SuiviReglements",
    }:
        field = "ID_UserFK" if "ID_UserFK" in columns else "ID_UserFk"
        if field in columns:
            return (
                f'EXISTS (SELECT 1 FROM systeme."T_Utilisateurs" own WHERE own."IdUser"={a}."{field}" AND own."IdEntiteFk"=%s)',
                [org],
            )
    if schema == "logistique":
        art = next((x for x in ["ID_ArticleFk", "ID_Article"] if x in columns), None)
        cmd = next(
            (x for x in ["ID_CmdFk", "ID_cmdFk", "ID_Commande"] if x in columns), None
        )
        clauses = []
        values = []
        if art:
            clauses.append(
                f'EXISTS (SELECT 1 FROM logistique."T_Article" own_a JOIN systeme."T_Utilisateurs" own_u ON own_u."IdUser"=own_a."ID_UserFK" WHERE own_a."ID_Article"={a}."{art}" AND own_u."IdEntiteFk"=%s)'
            )
            values.append(org)
        if cmd:
            clauses.append(
                f'EXISTS (SELECT 1 FROM logistique."T_Commande" own_c JOIN systeme."T_Utilisateurs" own_u ON own_u."IdUser"=own_c."ID_UserFk" WHERE own_c."ID_Commande"={a}."{cmd}" AND own_u."IdEntiteFk"=%s)'
            )
            values.append(org)
        if clauses:
            return " AND ".join(clauses), values
        if "CodeFactureFk" in columns:
            return (
                f'EXISTS (SELECT 1 FROM logistique."T_Commande" own_c JOIN systeme."T_Utilisateurs" own_u ON own_u."IdUser"=own_c."ID_UserFk" WHERE own_c."CodeFacture"={a}."CodeFactureFk" AND own_u."IdEntiteFk"=%s)',
                [org],
            )
    raise APIError(
        "Cet objet exige un administrateur global : périmètre local non démontré.",
        "SCOPE_UNAVAILABLE",
        403,
    )


def check_global_write(obj, actor):
    if not actor.global_admin and (
        obj["schema"] in {"geolocalisation", "referentiel"}
        or obj["name"] in {"T_Fk_Correspondance", "T_Admin_UI_Setting"}
    ):
        raise APIError(
            "Modification du référentiel partagé réservée à un administrateur global.",
            "GLOBAL_ADMIN_REQUIRED",
            403,
        )
