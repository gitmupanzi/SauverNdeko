"""Modèles et lecture Excel vers le panier de références, sans écriture métier."""
from django.http import FileResponse
from rest_framework.parsers import MultiPartParser
from rest_framework.views import APIView

from . import db
from .batch_excel import ExcelPreviewMixin, build_template, read_uploaded_workbook
from .module_access import access_snapshot, require_module
from .permissions import IsERPAdmin
from .responses import APIError, ok
from .tenancy import read_entity
from apps.logistique.excel import ExcelDownloadView, XLSX_MEDIA_TYPE


VISIBILITY_LABELS = {
    'VisibleAll': 'Visibilité générale', 'VisibleArticle': 'Articles',
    'VisibleCmd': 'Bons de stock', 'VisibleFacture': 'Factures',
    'VisibleUsers': 'Utilisateurs', 'VisibleVoie': 'Voies d’accès',
    'VisibleNiveau_2': 'Niveau territorial 2', 'VisibleNiveau_3': 'Niveau territorial 3',
    'VisibleNiveau_4': 'Niveau territorial 4', 'VisibleNiveau_5': 'Niveau territorial 5',
}
COLUMNS = {
    'categories': [
        {'key': 'NomCategorieGenerique', 'label': 'Catégorie', 'width': 38},
        {'key': 'ModuleCategorieGenerique', 'label': 'Modules associés', 'width': 35},
        {'key': 'ValideCategorieGenerique', 'label': 'État', 'width': 18},
    ],
    'valeurs': [
        {'key': 'NomGenerique', 'label': 'Libellé', 'width': 38},
        {'key': 'AbrGenerique', 'label': 'Abréviation ou code', 'width': 26},
        {'key': 'ObsGenerique', 'label': 'Informations', 'width': 48},
        {'key': 'ValideGenerique', 'label': 'État', 'width': 18},
        *[{'key': key, 'label': label, 'width': 24} for key, label in VISIBILITY_LABELS.items()],
    ],
}
SHEETS = {'categories': 'Catégories', 'valeurs': 'Valeurs'}
CONTEXT_FIELDS = ('scope', 'scopeValue', 'categoryId')


def require_excel_access(actor, kind):
    if kind not in COLUMNS:
        raise APIError('Saisie indisponible.', 'NOT_FOUND', 404)
    require_module(actor, 'referentiels', 'manage')
    if not actor.admin or not any(item.get('canManage') for item in access_snapshot(actor)['modules'].values()):
        raise APIError('Votre rôle ne permet pas de préparer ces références.', 'MODULE_ACTION_FORBIDDEN', 403)


def excel_context(actor, kind, raw):
    """Même propriété et parent que le panier ; uniquement des SELECT sans verrou."""
    from .repository import positive
    require_excel_access(actor, kind)
    if set(raw) - set(CONTEXT_FIELDS):
        raise APIError('Un champ de la saisie n’est pas autorisé.')
    scope = raw.get('scope', 'global' if actor.global_admin else 'entity')
    if scope not in {'global', 'entity'}:
        raise APIError('Choisissez la portée des références.')
    owner = None
    if scope == 'global':
        if raw.get('scopeValue') not in (None, ''):
            raise APIError('La portée commune ne comporte pas d’entreprise.')
    else:
        owner = positive(raw.get('scopeValue', read_entity(actor)), 'Entreprise')
    if not actor.global_admin and (owner is None or owner != read_entity(actor)):
        raise APIError('Seules les références de votre entreprise peuvent être préparées.', 'REFERENCE_OWNER_FORBIDDEN', 403)
    notes = [('Portée', 'Commune à toutes les entreprises')]
    if owner is not None:
        company = db.one('SELECT "NomEntite","ValideEntite" FROM systeme."T_Entite" WHERE "IdEntite"=%s', [owner])
        if not company:
            raise APIError('Entreprise introuvable.', 'NOT_FOUND', 404)
        if company['ValideEntite'] is False:
            raise APIError('Les références de cette entreprise sont en consultation.', 'ENTITY_INACTIVE', 409)
        notes = [('Portée', 'Entreprise : ' + str(company['NomEntite'] or owner))]
    if kind == 'valeurs':
        category = positive(raw.get('categoryId'), 'Catégorie')
        parent = db.one('SELECT "NomCategorieGenerique","IdEntiteFk","ValideCategorieGenerique" '
                        'FROM referentiel."T_CategorieGenerique" WHERE "ID_CategorieGenerique"=%s', [category])
        if not parent or parent['IdEntiteFk'] is not None and parent['IdEntiteFk'] != owner or parent['ValideCategorieGenerique'] is False:
            raise APIError('Choisissez une catégorie active commune ou de la même entreprise.', 'REFERENCE_CATEGORY_INVALID', 422)
        if owner is not None and db.one('SELECT 1 AS protected FROM referentiel."T_ChampReferentiel" '
                                       'WHERE NOT "CanConfigure" AND "ID_CategorieDefautFk"=%s LIMIT 1', [category]):
            raise APIError('Les références de sécurité restent communes et gérées par la plateforme.', 'REFERENCE_CATEGORY_INVALID', 422)
        notes.append(('Catégorie', str(category) + ' · ' + str(parent['NomCategorieGenerique'])))
    elif raw.get('categoryId') not in (None, ''):
        raise APIError('La saisie de catégories ne comporte pas de catégorie parente.')
    return notes


def template_columns(kind):
    columns = [dict(column) for column in COLUMNS[kind]]
    for column in columns:
        if column['key'].startswith(('Valide', 'Visible')):
            values = ['Oui', 'Non', *(['Non renseigné'] if column['key'].startswith('Visible') else [])]
            column['choices'] = [{'value': value, 'label': value} for value in values]
    return columns


class ReferenceExcelTemplateView(ExcelDownloadView):
    http_method_names = ['get', 'options']

    def get(self, request, kind):
        notes = excel_context(request.user, kind, request.query_params.dict())
        stream = build_template(sheet_name=SHEETS[kind], columns=template_columns(kind), notes=[
            ('Modèle', 'Création de ' + kind + ' de référence'), *notes,
            ('En-tête commun', 'La portée et la catégorie se choisissent dans le formulaire, puis s’appliquent à toutes les lignes.'),
            ('Vérification', 'L’import ajoute les lignes au panier pour correction. Seul Enregistrer l’ensemble enregistre le lot.'),
            ('Valeurs vides', 'État et visibilités vides reprennent Oui. Non renseigné conserve une visibilité non renseignée.'),
            ('Limites', '100 lignes par fichier .xlsx ; 200 lignes par panier.'),
        ], max_rows=100)
        response = FileResponse(stream, as_attachment=True,
                                filename='SauverNdeko_Modele_Referentiels_' + kind + '.xlsx', content_type=XLSX_MEDIA_TYPE)
        response['Cache-Control'] = 'no-store, private'
        return response


class ReferenceExcelImportView(ExcelPreviewMixin, APIView):
    permission_classes = [IsERPAdmin]
    parser_classes = [MultiPartParser]
    http_method_names = ['post', 'options']

    def post(self, request, kind):
        # Contrôle avant même de lire le multipart, puis du contexte et du parent.
        require_excel_access(request.user, kind)
        cells = read_uploaded_workbook(request, allowed_fields=CONTEXT_FIELDS,
            sheet_name=SHEETS[kind], headers={value: column['key'] for column in COLUMNS[kind]
                for value in (column['key'], column['label'])}, required_headers=(COLUMNS[kind][0]['key'],), max_rows=100)
        excel_context(request.user, kind, {key: request.data[key] for key in CONTEXT_FIELDS if key in request.data})
        return ok({'cells': cells, 'count': max(0, len(cells) - 1), 'maxRows': 100},
                  message='Fichier lu. Vérifiez les lignes du panier avant de les enregistrer.')
