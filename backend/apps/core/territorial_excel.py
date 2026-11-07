"""Modèles XLSX territoriaux et lecture vers le panier, sans écriture métier."""
from django.http import FileResponse
from rest_framework.views import APIView
from apps.logistique.excel import ExcelDownloadView

from . import db
from .batch_excel import ExcelPreviewMixin, build_template, read_uploaded_workbook, read_workbook
from .permissions import IsERPAdmin
from .responses import APIError, ok
from .territorial_batches import MAX_ROWS, PARENTS
from .territorial_contacts import FIELDS as CONTACT_FIELDS
from .territorial_portal import LABELS, TITLES, references, source


SHEET_NAME = 'Territoires'
XLSX_MEDIA_TYPE = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'

# Même périmètre que la fiche territoriale : aucune colonne d’auteur, de clé
# primaire ou de rattachement commun n’entre dans le détail du fichier.
LEVEL_FIELDS = {
    0: ('NomNiveau_0', 'CodeNiveau_0', 'geometryNiveau_0'),
    1: ('ID_Niveau_1_Old_Fk', 'NomNiveau_1', 'Alt1_Niveau_1', 'Alt2_Niveau_1',
        'AbreNiveau_1', 'CodeSNIS', 'CodeNiveau_1', 'PopulationNiveau_1',
        'LatitudeNiveau_1', 'LongitudeNiveau_1', 'surfaceNiveau_1', 'geometryNiveau_1',
        'EtenduNiveau_1', 'timezoneNiveau_1', 'wikidataNiveau_1', 'FusionNiveau_1',
        'VisibleNiveau_1', 'VisibleNiveau_5', 'ObsNiveau_1'),
    2: ('ID_TypeNiveau_2_Fk', 'NomNiveau_2', 'Alt1_NomNiveau_2', 'AbreNiveau_2',
        'CodeNiveau_2', 'PopulationNiveau_2', 'LatitudeNiveau_2', 'LongitudeNiveau_2',
        'AltitudeNiveau_2', 'surfaceNiveau_2', 'geometryNiveau_2', 'EtenduNiveau_2',
        'ObsNiveau_2', 'ID_StatutNiveau_2', 'ID_StatusDeploiFk', 'KmDPSANT',
        'ID_VoieAccesDPSANTFk', 'SelectNiveau_2'),
    3: ('ID_TypeNiveau_2_Fk', 'NomNiveau_3', 'Alt_Niveau_3', 'AbreNiveau_3',
        'CodeNiveau_3', 'PopulationNiveau_3', 'LatitudeNiveau_3', 'LongitudeNiveau_3',
        'AltitudeNiveau_3', 'surfaceNiveau_3', 'geometryNiveau_3', 'ObsNiveau_3',
        'ID_StatutNiveau_3_Fk', 'ID_StatutDeploieFk', 'KmAntenneBCZS',
        'ID_VoieAccesANTBCZFk', 'KmDPSBCZS', 'ID_VoieAccesDPSBCZFk', 'SelectNiveau_3'),
    4: ('ID_TypeNiveau_4_Fk', 'NomNiveau_4', 'AbreNiveau_4', 'CodeNiveau_4',
        'PopulationNiveau_4', 'LatitudeNiveau_4', 'LongitudeNiveau_4', 'AltitudeNiveau_4',
        'KmZoneSanteAS', 'surfaceNiveau_4', 'geometryNiveau_4', 'ID_DispoReseauNiveau_4',
        'ID_VoieAccesZsASFk', 'ID_StatutNiveau_4', 'ID_StatutDeploiementFk',
        'SelectNiveau_4', 'ObsNiveau_4'),
    5: ('ID_TypeNiveau_5_Fk', 'NomNiveau_5', 'AbreNiveau_5', 'CodeNiveau_5',
        'PopulationNiveau_5', 'LatitudeNiveau_5', 'LongitudeNiveau_5', 'AltitudeNiveau_5',
        'KmZoneSanteNiveau_5', 'surfaceNiveau_5', 'geometryNiveau_5', 'ID_DispoReseauNiveau_5',
        'ID_VoieAccesZsSiteFk', 'ID_StatutNiveau_5', 'ID_StatutDeploiementFk',
        'ID_TypeToitFk', 'SelectNiveau_5', 'ObsNiveau_5'),
}
FRIENDLY_LABELS = {
    'ID_Niveau_1_Old_Fk': 'Ancienne province', 'prov_uid': 'Identifiant provincial',
    'PublierCoordonneesAnnuaire': 'Publier les coordonnées dans l’annuaire',
    'FusionNiveau_1': 'Fusion active', 'VisibleNiveau_1': 'Visible niveau 1',
    'VisibleNiveau_5': 'Visible niveau 5', 'timezoneNiveau_1': 'Fuseau horaire',
    'ID_TypeToitFk': 'Type de toit',
}


def fields(kind):
    if kind not in PARENTS:
        raise APIError('Le modèle Excel concerne les niveaux actuels 0 à 5.', 'NOT_FOUND', 404)
    level = int(kind[-1])
    names = list(LEVEL_FIELDS[level]) + ['uidSNIS', 'prov_uid' if level == 1 else 'iso']
    if level:
        names.extend(CONTACT_FIELDS)
    # Nom/code/abréviation/type en premier, puis tous les détails de la fiche.
    priority = ['NomNiveau_' + str(level), 'CodeNiveau_' + str(level), 'AbreNiveau_' + str(level)]
    priority.extend(name for name in names if name.startswith('ID_TypeNiveau_'))
    return list(dict.fromkeys([name for name in priority if name in names] + names))


def field_label(name):
    if name in FRIENDLY_LABELS:
        return FRIENDLY_LABELS[name]
    if name.startswith('NomNiveau_'):
        return 'Nom'
    if name.startswith('ID_TypeNiveau_'):
        return 'Type'
    if name.startswith('ID_StatutNiveau_'):
        return 'Statut'
    if name in {'ID_StatusDeploiFk', 'ID_StatutDeploieFk', 'ID_StatutDeploiementFk'}:
        return 'Statut déploiement'
    if name.startswith('ID_DispoReseauNiveau_'):
        return 'Disponibilité réseau'
    return LABELS.get(name, name)


def headers(kind):
    result = {}
    for name in fields(kind):
        result[name] = name
        result[field_label(name)] = name
    # Les alias courts servent aussi au collage déjà utilisé dans le panier.
    if kind != 'niveaux0':
        result['Abréviation'] = 'AbreNiveau_' + kind[-1]
        result['Observation'] = 'ObsNiveau_' + kind[-1]
    return result


def read_territorial_workbook(upload, kind):
    return read_workbook(upload, sheet_name=SHEET_NAME, headers=headers(kind),
                         required_headers=('NomNiveau_' + kind[-1],), max_rows=MAX_ROWS)


def authorize(actor, kind):
    fields(kind)
    source(actor, kind, 'manage')
    if not actor.global_admin:
        raise APIError('Le découpage partagé est géré par la plateforme.', 'GLOBAL_ADMIN_REQUIRED', 403)
    db.ensure_writable()


def template(actor, kind):
    authorize(actor, kind)
    context = references(actor, kind)
    columns = []
    for name in fields(kind):
        choices = context.get('fieldReferences', {}).get(name, {}).get('options', [])
        if name == 'ID_Niveau_1_Old_Fk':
            choices = context.get('options', {}).get('niveaux1Old', [])
        if name.startswith(('Visible', 'Fusion', 'Select')) or name == 'PublierCoordonneesAnnuaire':
            choices = [{'value': 'true', 'label': 'Oui'}, {'value': 'false', 'label': 'Non'}]
        column = {'key': name, 'label': field_label(name), 'width': 40 if name in CONTACT_FIELDS else 26,
                  'required': name in {'NomNiveau_' + kind[-1], 'VisibleNiveau_1', 'VisibleNiveau_5'}}
        if choices:
            column['choices'] = [{'value': str(item.get('value', item.get('id'))), 'label': item['label']}
                                 for item in choices if not item.get('disabled')]
        columns.append(column)
    return build_template(sheet_name=SHEET_NAME, columns=columns, max_rows=MAX_ROWS, notes=[
        ('Registre', TITLES[kind]),
        ('Rattachement', 'Choisir le parent commun dans l’en-tête du panier ; aucun parent dans les lignes Excel.'),
        ('Vérification', 'Importer remplit le brouillon. Corriger le panier et les détails, puis Enregistrer l’ensemble.'),
        ('Limite', '100 lignes, fichier .xlsx de 4 Mo maximum. Conserver les codes et téléphones en texte.'),
        ('Champs obligatoires', 'Nom ; pour les provinces, choisir Oui ou Non dans les deux colonnes de visibilité.'),
        ('Références', 'Utiliser le libellé exact ou l’identifiant des choix autorisés ; types et visibilités du niveau courant.'),
        ('Publication', 'Non par défaut. La publication porte seulement sur les coordonnées, horaires et informations d’accueil.'),
    ])


class TerritorialExcelTemplateView(ExcelDownloadView):
    permission_classes = [IsERPAdmin]
    http_method_names = ['get', 'options']

    def get(self, request, kind):
        response = FileResponse(template(request.user, kind), as_attachment=True,
                            filename='SauverNdeko_Territoires_' + kind + '_Modele.xlsx',
                            content_type=XLSX_MEDIA_TYPE)
        response['Cache-Control'] = 'no-store, private'
        return response


class TerritorialExcelImportView(ExcelPreviewMixin, APIView):
    permission_classes = [IsERPAdmin]
    http_method_names = ['post', 'options']

    def post(self, request, kind):
        authorize(request.user, kind)
        matrix = read_uploaded_workbook(request, sheet_name=SHEET_NAME, headers=headers(kind),
                                        required_headers=('NomNiveau_' + kind[-1],), max_rows=MAX_ROWS)
        return ok({'matrix': matrix}, message='Fichier lu. Vérifiez le panier avant son enregistrement.')
