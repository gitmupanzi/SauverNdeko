from rest_framework.permissions import BasePermission
from .responses import APIError


class IsERPAdmin(BasePermission):
    message = "Accès réservé aux gestionnaires autorisés."

    def has_permission(self, request, view):
        if not (request.user and request.user.admin):return False
        from .module_access import enforce_request
        enforce_request(request.user,request,view)
        return True


def scope_for(obj, actor, alias="v"):
    """Périmètre collaboratif de l'entreprise, indépendant de l'affectation de l'auteur."""
    from .tenancy import read_entity
    schema,name=obj['schema'],obj['name'];a=alias;org=read_entity(actor)
    if actor.global_admin and org is None:return 'TRUE',[]
    if schema in {'geolocalisation','referentiel'}:return 'TRUE',[]
    if not org:raise APIError('Organisation requise.','ORGANISATION_REQUIRED',403)
    columns={x['column_name'] for x in obj['columns']}
    if name in {'T_Entite','V_Entite','V_Entite_Localisation_Detail','V_IdentiteDocumentaire'} and 'IdEntite' in columns:return f'{a}."IdEntite"=%s',[org]
    for field in ('IdEntiteFk','ID_EntiteFk'):
        if field in columns:return f'{a}."{field}"=%s',[org]
    if schema=='systeme' and {'SettingScope','ScopeValue'}.issubset(columns):return f'{a}."SettingScope"=%s AND {a}."ScopeValue"=%s',['entity',str(org)]
    if name=='V_User_profil':return f'{a}."IdEntite"=%s',[org]
    if schema=='logistique':
        art=next((x for x in ('ID_ArticleFk','ID_Article') if x in columns),None)
        cmd=next((x for x in ('ID_CmdFk','ID_cmdFk','ID_Commande') if x in columns),None)
        clauses=[];values=[]
        if art:
            clauses.append(f'EXISTS(SELECT 1 FROM logistique."T_Article" own_a WHERE own_a."ID_Article"={a}."{art}" AND own_a."IdEntiteFk"=%s)');values.append(org)
        if cmd:
            condition=f'EXISTS(SELECT 1 FROM logistique."T_Commande" own_c WHERE own_c."ID_Commande"={a}."{cmd}" AND own_c."IdEntiteFk"=%s)'
            if name in {'T_Mouvement','V_Mouvement','V_MouvementStock'}:condition=f'({a}."{cmd}" IS NULL OR '+condition+')'
            clauses.append(condition);values.append(org)
        if clauses:return ' AND '.join('('+item+')' for item in clauses),values
        if 'CodeFactureFk' in columns:return f'EXISTS(SELECT 1 FROM logistique."T_Commande" own_c WHERE own_c."CodeFacture"={a}."CodeFactureFk" AND own_c."IdEntiteFk"=%s)',[org]
    raise APIError('Périmètre local indisponible pour cet objet.','SCOPE_UNAVAILABLE',403)


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


class HasModuleAccess(BasePermission):
    message="Connexion et accès à l’application requis."
    def has_permission(self,request,view):
        if not request.user or not request.user.is_authenticated:return False
        from .module_access import enforce_request
        enforce_request(request.user,request,view)
        return True
