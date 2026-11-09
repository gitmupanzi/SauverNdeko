"""Modèles administratifs et lecture XLSX vers un panier sans création."""
from django.http import FileResponse
from rest_framework.views import APIView

from apps.logistique.excel import ExcelDownloadView, XLSX_MEDIA_TYPE
from . import db
from .admin_operations import management, references
from .batch_excel import ExcelPreviewMixin, build_template, read_uploaded_workbook
from .admin_tabs import require_admin_tab
from .permissions import IsERPAdmin
from .responses import APIError, ok


SHEETS = {'utilisateurs': 'Utilisateurs', 'roles': 'Rôles',
          'correspondances': 'Correspondances', 'parametres': 'Paramètres'}
FIELDS = {
    'utilisateurs': [
        ('PrenomUser', 'Prénom'), ('NomUser', 'Nom'), ('EmailUser', 'Adresse e-mail'),
        ('IdRoleFk', 'Rôle'), ('MotdepasseUser', 'Mot de passe initial'),
        ('PhoneUser', 'Téléphone'), ('SexeUser', 'Sexe'), ('IdEntiteFk', 'Entreprise'),
        ('MatriculeUser', 'Matricule'), ('ID_ServiceFk', 'Service'), ('ID_FonctionFk', 'Fonction'),
        ('DateEmbauche', 'Date d’embauche'), ('DateFinEmploi', 'Fin d’emploi'),
        ('ObservationProfessionnelle', 'Observations professionnelles'), ('ValideUser', 'Compte actif'),
    ],
    'roles': [('NomGenerique', 'Nom du rôle'), ('AbrGenerique', 'Code du rôle'),
              ('ObsGenerique', 'Description'), ('ValideGenerique', 'Rôle actif')],
    'correspondances': [
        ('ModuleName', 'Module'), ('SchemaName', 'Schéma source'), ('ViewName', 'Vue source'),
        ('SourceKey', 'Clé source'), ('FieldName', 'Champ source'), ('FieldLabel', 'Libellé du champ'),
        ('MappingType', 'Type de correspondance'), ('TargetCategoryIdFk', 'Catégorie du référentiel'),
        ('MappingValue', 'Valeur de correspondance'), ('ReferenceSchemaName', 'Schéma de référence'),
        ('ReferenceObjectName', 'Objet de référence'), ('ReferenceFieldName', 'Champ de référence'),
        ('SettingScope', 'Portée'), ('ScopeValue', 'Contexte'), ('DisplayOrder', 'Ordre d’affichage'),
        ('IsDefaultMapping', 'Correspondance par défaut'), ('ValideFkCorrespondance', 'Correspondance active'),
        ('ObsFkCorrespondance', 'Observations'),
    ],
    'parametres': [
        ('SettingKey', 'Clé du paramètre'), ('SettingLabel', 'Libellé'), ('SettingGroup', 'Groupe'),
        ('SettingType', 'Format de la valeur'), ('SettingValue', 'Valeur'), ('SettingValueJson', 'Valeur JSON'),
        ('SettingScope', 'Portée'), ('ScopeValue', 'Contexte'), ('DisplayOrder', 'Ordre d’affichage'),
        ('IsEditable', 'Paramètre modifiable'), ('ValideSetting', 'Paramètre actif'), ('ObsSetting', 'Observations'),
    ],
}
CHOICES = {
    'SexeUser': [('M', 'Masculin'), ('F', 'Féminin')],
    'MappingType': [('generic_category', 'Catégorie du référentiel'), ('direct_source', 'Source directe'), ('hierarchy_mode', 'Hiérarchie')],
    'SettingType': [('text', 'Texte'), ('number', 'Nombre'), ('boolean', 'Oui / Non'), ('select', 'Liste'),
                    ('json', 'JSON'), ('color', 'Couleur'), ('file', 'Fichier'), ('email', 'Adresse e-mail'),
                    ('phone', 'Téléphone'), ('url', 'Lien'), ('textarea', 'Texte long')],
}
BOOLEANS = {'ValideUser', 'ValideGenerique', 'IsDefaultMapping', 'ValideFkCorrespondance', 'IsEditable', 'ValideSetting'}


def excel_support(actor, kind):
    if kind not in FIELDS:
        raise APIError('Saisie indisponible.', 'NOT_FOUND', 404)
    require_admin_tab(actor, kind, 'manage')
    db.ensure_writable()
    if not management(actor, kind):
        raise APIError('Votre accès ne permet pas de préparer ces fiches.', 'PLATFORM_ADMIN_REQUIRED', 403)
    return references(actor, kind)


def columns_for(kind, support):
    """Le contexte fixé sur l’écran reste hors des colonnes importables."""
    fixed = ({'IdEntiteFk'} if kind == 'utilisateurs' else {'SettingScope', 'ScopeValue'}) if support.get('entityId') else set()
    choices = {key: [{'value': value, 'label': label} for value, label in values] for key, values in CHOICES.items()}
    choices.update({
        'IdRoleFk': support.get('roles', []), 'IdEntiteFk': support.get('entities', []),
        'ID_ServiceFk': support.get('personnelServices', []), 'ID_FonctionFk': support.get('personnelFonctions', []),
        'TargetCategoryIdFk': support.get('categories', []),
    })
    scopes = [('global', 'Globale'), ('country', 'Pays'), ('entity', 'Entreprise')] if kind == 'correspondances' else [('global', 'Globale'), ('entite', 'Entreprise'), ('user', 'Utilisateur'), ('module', 'Module')]
    choices['SettingScope'] = [{'value': key, 'label': label} for key, label in scopes]
    return [{'key': key, 'label': label, 'width': 32,
             'choices': [{'value': value, 'label': value} for value in ('Oui', 'Non')] if key in BOOLEANS else
                        [row for row in choices.get(key, []) if row.get('active') is not False and row.get('disabled') is not True]}
            for key, label in FIELDS[kind] if key not in fixed]


class AdminExcelTemplateView(ExcelDownloadView):
    permission_classes = [IsERPAdmin]
    http_method_names = ['get', 'options']

    def get(self, request, kind):
        if request.query_params:
            raise APIError('Aucun critère attendu.')
        support = excel_support(request.user, kind)
        notes = [
            ('Parcours', 'Importez le fichier, vérifiez et corrigez les lignes du panier, puis enregistrez l’ensemble.'),
            ('Contexte', 'L’entreprise sélectionnée dans l’application est conservée. Les rôles restent communs à la plateforme.'),
            ('Listes', 'Utilisez les identifiants ou les libellés exacts de la feuille Options. Les références génériques affichent AbrGenerique.'),
            ('Dates', 'Utilisez AAAA-MM-JJ pour les dates d’emploi.'),
            ('Limites', '100 lignes ; fichier .xlsx de 4 Mo maximum. Aucun compte ni réglage n’est créé lors de l’import.'),
        ]
        if kind == 'utilisateurs':
            notes += [('Accès', 'Les comptes importés ne reçoivent aucun privilège Is_staff ou Is_Admin par le fichier.'),
                      ('Confidentialité', 'Le mot de passe initial reste dans le fichier et le panier en mémoire. Ne partagez pas ce fichier et retirez-le après usage.')]
        stream = build_template(sheet_name=SHEETS[kind], columns=columns_for(kind, support), notes=notes)
        response = FileResponse(stream, as_attachment=True, filename='SauverNdeko_Modele_Administration_'+kind+'.xlsx', content_type=XLSX_MEDIA_TYPE)
        response['Cache-Control'] = 'no-store, private'
        return response


class AdminExcelPreviewView(ExcelPreviewMixin, APIView):
    permission_classes = [IsERPAdmin]
    http_method_names = ['post', 'options']

    def post(self, request, kind):
        # Autorisations avant la lecture multipart et aucun appel au service de mutation.
        columns = columns_for(kind, excel_support(request.user, kind))
        matrix = read_uploaded_workbook(request, sheet_name=SHEETS[kind],
            headers={value: column['key'] for column in columns for value in (column['key'], column['label'])},
            required_headers=(FIELDS[kind][0][0],), max_rows=100)
        response = ok({'matrix': matrix, 'count': len(matrix)-1, 'maxRows': 100},
                      message='Fichier lu. Vérifiez et corrigez le panier avant l’enregistrement.')
        response['Cache-Control'] = 'no-store, private'
        return response
