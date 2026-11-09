"""Modèles et aperçu XLSX des paniers de tiers et d'immobilisations.

L'aperçu ne crée rien ; le panier utilise ensuite sa transaction métier existante.
Les références proviennent du même service et de la même entreprise que la fiche.
"""
from django.http import FileResponse
from rest_framework.views import APIView

from apps.core import db
from apps.core.batch_excel import ExcelPreviewMixin, build_template, read_uploaded_workbook
from apps.core.module_access import require_module
from apps.core.permissions import IsERPAdmin
from apps.core.responses import APIError, ok
from apps.core.tenancy import require_entity
from apps.logistique.excel import ExcelDownloadView, XLSX_MEDIA_TYPE

from . import immobilisations, tiers


COLUMNS = {
    'tiers': [
        ('Nom', 'Nom du tiers', 32), ('ID_TypeClientFk', 'Type de tiers', 24),
        ('Nature', 'Nature', 18), ('Email', 'E-mail', 30), ('Telephone', 'Téléphone', 24),
        ('Adresse', 'Adresse', 42), ('IdUserFk', 'Compte utilisateur', 28),
        ('IdProfessionnelFk', 'Professionnel', 28),
        ('IdEntiteRepresenteeFk', 'Entreprise représentée', 30),
        ('ObsClient', 'Informations', 48), ('Actif', 'Actif', 16),
    ],
    'immobilisations': [
        ('NomImmobilisation', 'Nom du bien', 32), ('ID_CategorieFk', 'Type de matériel', 24),
        ('Reference', 'Référence', 26), ('Quantite', 'Quantité', 16),
        ('SuiviIndividuel', 'Suivi individuel', 20), ('PrixUnitaire', 'Prix unitaire', 20),
        ('ID_DeviseFk', 'Devise', 18), ('ID_EtatFk', 'État du matériel', 24),
        ('ID_ResponsableFk', 'Responsable', 28), ('ID_ServiceFk', 'Service', 24),
        ('LocalisationComplement', 'Localisation (texte libre)', 42),
        ('DateEntree', 'Date et heure d’entrée', 26), ('DateAcquisition', 'Date d’acquisition', 24),
        ('DateMiseEnService', 'Date de mise en service', 24),
        ('NumeroSerie', 'N° de série', 28), ('Caracteristiques', 'Caractéristiques', 48),
        ('Observations', 'Observations', 48), ('motif', 'Motif', 42),
    ],
}
SHEETS = {'tiers': 'Tiers', 'immobilisations': 'Immobilisations'}
REFERENCE_FIELDS = {
    'tiers': {'ID_TypeClientFk': 'typesClients', 'IdUserFk': 'users',
              'IdProfessionnelFk': 'professionnels', 'IdEntiteRepresenteeFk': 'entites'},
    'immobilisations': {'ID_CategorieFk': 'types', 'ID_EtatFk': 'etats',
        'ID_ResponsableFk': 'responsables', 'ID_ServiceFk': 'services',
        'ID_DeviseFk': 'currencies'},
}


def writable(actor, kind):
    if kind not in COLUMNS:
        raise APIError('Panier introuvable.', 'NOT_FOUND', 404)
    require_module(actor, 'logistique', 'manage')
    db.ensure_writable()
    return require_entity(actor)


def template_columns(kind, references):
    result = []
    for key, label, width in COLUMNS[kind]:
        spec = {'key': key, 'label': label, 'width': width,
                'required': key in {'Nom', 'ID_TypeClientFk', 'NomImmobilisation', 'ID_CategorieFk'}}
        source = REFERENCE_FIELDS[kind].get(key)
        if source:
            # Ces services exposent déjà AbrGenerique comme label des références
            # catégorielles, et les noms autorisés pour comptes et localisations.
            spec['choices'] = [{'value': str(item.get('id', item.get('value'))), 'label': item['label']}
                for item in references.get(source, []) if item.get('active', True)
                and not item.get('disabled') and not item.get('incompatible')]
        elif key == 'Nature':
            spec['choices'] = [{'value': 'personne', 'label': 'Personne'}, {'value': 'entreprise', 'label': 'Entreprise'}]
        elif key in {'Actif', 'SuiviIndividuel'}:
            spec['choices'] = [{'value': 'Oui', 'label': 'Oui'}, {'value': 'Non', 'label': 'Non'}]
        result.append(spec)
    return result


class LogisticsExcelTemplateView(ExcelDownloadView):
    permission_classes = [IsERPAdmin]
    http_method_names = ['get', 'options']

    def get(self, request, kind):
        writable(request.user, kind)
        references = tiers.references(request.user) if kind == 'tiers' else immobilisations.references(request.user)
        notes = [
            'Les choix appartiennent à l’entreprise sélectionnée. Une valeur inconnue reste à corriger dans le panier.',
            'Aucun code interne d’inventaire, identifiant de fiche, propriétaire ni révision ne se renseigne dans le fichier.',
        ]
        if kind == 'tiers':
            notes.append('La nature vide conserve Personne et l’état vide conserve Actif. Un tiers peut rester sans compte utilisateur.')
        else:
            notes.extend([
                'La localisation accepte du texte libre (255 caractères maximum).',
                'Un suivi individuel ou un numéro de série exige une quantité de 1. Pour un lot homogène, indiquez Non dans Suivi individuel.',
                'Prix non négatif, deux décimales maximum. Les dates utilisent JJ/MM/AAAA HH:MM:SS ou AAAA-MM-JJTHH:MM:SS, heure de Kinshasa.',
                'Renseignez le motif sur chaque ligne ou le motif commun dans le panier. Aucun mouvement de stock ni amortissement ne découle de cet import.',
            ])
        response = FileResponse(build_template(sheet_name=SHEETS[kind], columns=template_columns(kind, references),
            notes=notes), as_attachment=True, filename=f'SauverNdeko_Modele_{SHEETS[kind]}.xlsx', content_type=XLSX_MEDIA_TYPE)
        response['Cache-Control'] = 'no-store, private'
        return response


class LogisticsExcelPreviewView(ExcelPreviewMixin, APIView):
    permission_classes = [IsERPAdmin]
    http_method_names = ['post', 'options']

    def post(self, request, kind):
        # Contrôler l'accès avant le parseur multipart et avant toute lecture du fichier.
        writable(request.user, kind)
        headers = {label: key for key, label, _ in COLUMNS[kind]}
        if kind == 'tiers':
            headers['Type de client'] = 'ID_TypeClientFk'
        else:
            headers.update({'Localisation': 'ID_LocalisationFk', 'Bureau ou salle': 'LocalisationComplement'})
        cells = read_uploaded_workbook(request, sheet_name=SHEETS[kind], headers=headers,
            required_headers=('Nom',) if kind == 'tiers' else ('NomImmobilisation',))
        return ok({'cells': cells, 'count': len(cells) - 1, 'maxRows': 100})
