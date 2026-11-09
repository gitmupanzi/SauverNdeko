"""Références professionnelles de l'administration, sans effet sur les accès."""
import unicodedata
from datetime import date
from rest_framework.views import APIView
from . import db
from .permissions import IsERPAdmin
from .admin_tabs import require_admin_tab
from .responses import APIError, ok

FIELDS={'MatriculeUser','ID_ServiceFk','ID_FonctionFk','DateEmbauche','DateFinEmploi','ObservationProfessionnelle'}

def validate_professional_fields(body):
    """Valider les seuls champs professionnels présents d'une mutation existante.

    Les droits et clés sont contrôlés par la route utilisateur habituelle ;
    familles de FK, unicité et cohérence finale restent imposées par PostgreSQL.
    """
    if not isinstance(body,dict) or not FIELDS.intersection(body):return body
    result=dict(body);errors={}
    for name,maximum in [('MatriculeUser',50),('ObservationProfessionnelle',1000)]:
        if name not in body:continue
        value=body[name]
        if value is None:continue
        if not isinstance(value,str):errors[name]='Renseignez une valeur texte.';continue
        value=value.replace('\r\n','\n').strip()
        if len(value)>maximum or any(unicodedata.category(c) in {'Cc','Cs','Zl','Zp'} and not(name=='ObservationProfessionnelle' and c=='\n') for c in value):
            errors[name]='Utilisez au maximum '+str(maximum)+' caractères, sans caractère de contrôle.'
        result[name]=value or None
    for name in ('DateEmbauche','DateFinEmploi'):
        if name not in body or body[name] is None:continue
        try:
            value=body[name]
            if not isinstance(value,str) or len(value)!=10:raise ValueError()
            result[name]=date.fromisoformat(value).isoformat()
        except (ValueError,TypeError):errors[name]='Renseignez une date valide au format AAAA-MM-JJ.'
    if result.get('DateEmbauche') and result.get('DateFinEmploi') and result['DateFinEmploi']<result['DateEmbauche']:
        errors['DateFinEmploi']='La fin de l’emploi ne peut pas précéder l’embauche.'
    if errors:raise APIError(errors,'PERSONNEL_VALIDATION',400)
    return result

class PersonnelReferencesView(APIView):
    permission_classes=[IsERPAdmin]
    http_method_names=['get','options']
    def get(self,request):
        require_admin_tab(request.user, 'utilisateurs')
        if request.query_params:raise APIError('Aucun critère n’est attendu.')
        result={}
        from .field_references import reference_options
        for key,field in [('personnelServices','ID_ServiceFk'),('personnelFonctions','ID_FonctionFk')]:
            result[key]=reference_options(request.user,'systeme','T_Utilisateurs',field)
        return ok(result)
