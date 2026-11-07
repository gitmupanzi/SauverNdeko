"""Excel territorial : véritables classeurs et API, toute connexion SQL interdite."""
import io
import os
from pathlib import Path
import sys
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'backend'))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')

import django
django.setup()

from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import SimpleTestCase, override_settings
from django.urls import re_path
from openpyxl import Workbook, load_workbook
from rest_framework.test import APIClient
from apps.accounts.authentication import Actor
from apps.core import territorial_excel as excel
from apps.core.responses import APIError

urlpatterns = [
    re_path(r'^api/geolocalisation/territoires/registres/(?P<kind>niveaux[0-5])/modele-excel$',
            excel.TerritorialExcelTemplateView.as_view()),
    re_path(r'^api/geolocalisation/territoires/registres/(?P<kind>niveaux[0-5])/import-excel$',
            excel.TerritorialExcelImportView.as_view()),
]
BASE = '/api/geolocalisation/territoires/registres/'


def workbook(rows, sheet_name=excel.SHEET_NAME):
    book = Workbook()
    sheet = book.active
    sheet.title = sheet_name
    for row in rows:
        sheet.append(row)
    output = io.BytesIO()
    book.save(output)
    book.close()
    return output.getvalue()


def upload(binary):
    return SimpleUploadedFile('territoires.xlsx', binary,
                              content_type=excel.XLSX_MEDIA_TYPE)


@override_settings(ROOT_URLCONF=__name__, ALLOWED_HOSTS=['testserver'], DB_READ_ONLY=False)
class TerritorialExcelTests(SimpleTestCase):
    def client_for(self, *, manage=True, global_admin=True):
        actor = Actor({'IdUser': 17, 'Is_Admin': global_admin, 'Is_staff': True})
        actor._module_access = {'modules': {'territoires': {'canRead': True, 'canManage': manage,
            'canExport': False, 'reason': 'MODULE_ROLE_FORBIDDEN'}}}
        client = APIClient()
        client.force_authenticate(actor)
        return client

    def test_all_levels_read_native_workbooks_and_preserve_full_contact_details(self):
        for level in range(6):
            kind = f'niveaux{level}'
            names = excel.fields(kind)
            values = {'NomNiveau_' + str(level): 'Territoire de recette',
                      'CodeNiveau_' + str(level): '00017', 'uidSNIS': '000UID'}
            if level:
                values.update(AdresseTerritoire='Rue A\nBureau B',
                    TelephoneTerritoire='+243000001', TelephoneSecondaireTerritoire='000002',
                    EmailTerritoire='contact@example.invalid', SiteWebTerritoire='https://example.invalid',
                    InformationsAccueilTerritoire='Accueil\nSur rendez-vous',
                    HorairesOuvertureTerritoire='Lundi : 8 h–17 h\nMardi : 9 h–12 h',
                    PublierCoordonneesAnnuaire='Non')
            binary = workbook([[excel.field_label(name) for name in names],
                               [values.get(name, '') for name in names]])
            with self.subTest(kind=kind):
                matrix = excel.read_territorial_workbook(upload(binary), kind)
                self.assertEqual(matrix[0], names)
                actual = dict(zip(matrix[0], matrix[1]))
                self.assertTrue(all(isinstance(value, str) for row in matrix for value in row))
                for name, value in values.items():
                    self.assertEqual(actual[name], value)
                self.assertFalse(set(excel.PARENTS[kind]) & set(matrix[0]))

    def test_rejects_parent_primary_key_unknown_wrong_level_and_missing_name(self):
        for forbidden in ['ID_Niveau_2_FK', 'ID_Niveau_3', 'IdUserFk', 'NomNiveau_4', 'Inconnue']:
            with self.subTest(forbidden=forbidden), self.assertRaises(APIError):
                excel.read_territorial_workbook(upload(workbook([
                    ['Nom', forbidden], ['Zone', '8']])), 'niveaux3')
        for headings in [['Code'], ['Nom', 'NomNiveau_3']]:
            with self.subTest(headings=headings), self.assertRaises(APIError):
                excel.read_territorial_workbook(upload(workbook([headings, ['A'] * len(headings)])), 'niveaux3')
        with self.assertRaises(APIError):
            book = load_workbook(io.BytesIO(workbook([['Nom'], ['Zone']], 'Caisses')))
            book.create_sheet('Informations')
            output = io.BytesIO()
            book.save(output)
            book.close()
            excel.read_territorial_workbook(upload(output.getvalue()), 'niveaux3')

    def test_real_reader_rejects_formula_and_101_rows(self):
        for rows in [[['Nom'], ['=1+1']], [['Nom']] + [[f'Zone {i}'] for i in range(101)]]:
            with self.assertRaises(APIError):
                excel.read_territorial_workbook(upload(workbook(rows)), 'niveaux3')

    def test_import_is_preview_only_and_does_not_require_an_entity_or_parent(self):
        binary = workbook([['Nom', 'Code', 'Adresse', 'Horaires d’ouverture'],
                           ['Zone de recette', '0009', 'A\nB', 'Lundi\nMardi']])
        with patch('apps.core.db.one', side_effect=AssertionError('SQL interdit')), \
                patch('apps.core.db.query', side_effect=AssertionError('SQL interdit')):
            response = self.client_for().post(BASE + 'niveaux3/import-excel',
                {'fichier': upload(binary)}, format='multipart')
        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(response.data['data']['matrix'], [
            ['NomNiveau_3', 'CodeNiveau_3', 'AdresseTerritoire', 'HorairesOuvertureTerritoire'],
            ['Zone de recette', '0009', 'A\nB', 'Lundi\nMardi']])
        self.assertNotIn('createdCount', response.data['data'])

    def test_permissions_and_read_only_refuse_before_file_parsing(self):
        for client in [self.client_for(manage=False), self.client_for(global_admin=False)]:
            with patch.object(excel, 'read_uploaded_workbook') as reader:
                response = client.post(BASE + 'niveaux3/import-excel',
                    {'fichier': upload(b'invalide')}, format='multipart')
                self.assertEqual(response.status_code, 403)
                reader.assert_not_called()
        with override_settings(DB_READ_ONLY=True), patch.object(excel, 'read_uploaded_workbook') as reader:
            response = self.client_for().post(BASE + 'niveaux3/import-excel',
                {'fichier': upload(b'invalide')}, format='multipart')
            self.assertEqual(response.status_code, 503)
            reader.assert_not_called()

    def test_import_refuses_ambiguous_upload_fields_and_excess_size(self):
        binary = workbook([['Nom'], ['Zone']])
        for data in [{'file': upload(binary)}, {'fichier': [upload(binary), upload(binary)]},
                     {'fichier': upload(binary), 'parent': '8'}]:
            response = self.client_for().post(BASE + 'niveaux3/import-excel', data, format='multipart')
            self.assertIn(response.status_code, (400, 422), response.data)
        response = self.client_for().post(BASE + 'niveaux3/import-excel',
            {'fichier': upload(b'x' * (4 * 1024 * 1024 + 1))}, format='multipart')
        self.assertEqual(response.status_code, 413)

    def test_templates_use_current_reference_choices_and_never_put_parents_in_rows(self):
        for level in range(6):
            kind = f'niveaux{level}'
            type_field = next((name for name in excel.fields(kind) if name.startswith('ID_TypeNiveau_')), None)
            context = {'fieldReferences': {type_field: {'options': [
                {'id': 8, 'label': 'ZS', 'name': 'Nom long à ignorer'},
                {'id': 9, 'label': 'Masqué', 'disabled': True}]}}, 'options': {}}
            with self.subTest(kind=kind), patch.object(excel, 'references', return_value=context) as reference, \
                    patch('apps.core.db.query', side_effect=AssertionError('SQL interdit')):
                response = self.client_for().get(BASE + kind + '/modele-excel',
                    HTTP_ACCEPT=excel.XLSX_MEDIA_TYPE)
                self.assertEqual(response.status_code, 200)
                self.assertEqual(response['Cache-Control'], 'no-store, private')
                content = b''.join(response.streaming_content)
                response.close()
                self.assertEqual(reference.call_args.args[1], kind)
                book = load_workbook(io.BytesIO(content))
                try:
                    headings = [cell.value for cell in book[excel.SHEET_NAME][1]]
                    self.assertEqual(headings, [excel.field_label(name) for name in excel.fields(kind)])
                    self.assertEqual(len(headings), len(set(headings)))
                    self.assertFalse(set(excel.PARENTS[kind]) & set(headings))
                    self.assertEqual(book[excel.SHEET_NAME].freeze_panes, 'A2')
                    cells = [str(cell.value) for sheet in book for row in sheet for cell in row]
                    self.assertNotIn('Nom long à ignorer', cells)
                    self.assertNotIn('Masqué', cells)
                    if type_field:
                        self.assertIn('ZS', cells)
                    self.assertFalse(any(cell.data_type == 'f' for sheet in book for row in sheet for cell in row))
                finally:
                    book.close()
