"""Vrais classeurs + vues DRF, sans connexion ni écriture en base applicative.

Les droits et parents sont des fixtures. Le lecteur XLSX et les vues montées sont
exécutés réellement ; toute tentative de connexion PostgreSQL fait échouer le test.
"""
import io
import os
import sys
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'backend'))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
os.environ.setdefault('SAUVERNDEKO_DB_READ_ONLY', '1')
import django
django.setup()
from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import override_settings
from openpyxl import Workbook, load_workbook
from rest_framework.test import APIRequestFactory, force_authenticate
from apps.accounts.authentication import Actor
from apps.core.reference_excel import COLUMNS, ReferenceExcelImportView, ReferenceExcelTemplateView

BASE = '/api/referentiel/saisie-multiple/'


class ReferenceExcelTests(unittest.TestCase):
    def setUp(self):
        self.factory = APIRequestFactory()
        self.settings = override_settings(DB_READ_ONLY=True)
        self.settings.enable()
        self.addCleanup(self.settings.disable)
        self.connections = patch('django.db.backends.base.base.BaseDatabaseWrapper.ensure_connection',
                                 side_effect=AssertionError('Aucune connexion applicative autorisée.'))
        self.connections.start(); self.addCleanup(self.connections.stop)
        self.sql = patch('apps.core.reference_excel.db.one', side_effect=self.lookup)
        self.sql.start(); self.addCleanup(self.sql.stop)
        self.writes = patch('apps.core.db.query', side_effect=AssertionError('Aucune écriture ou audit autorisé.'))
        self.writes.start(); self.addCleanup(self.writes.stop)
        self.queries = []
        self.parent = {'NomCategorieGenerique': 'Famille fictive', 'IdEntiteFk': None, 'ValideCategorieGenerique': True}

    def lookup(self, sql, params=None):
        self.assertTrue(sql.lstrip().startswith('SELECT'), sql)
        self.assertNotIn('FOR SHARE', sql)
        self.queries.append((sql, params))
        if 'T_Entite' in sql:
            return {'NomEntite': 'Entreprise fictive', 'ValideEntite': True} if params == [7] else None
        if 'T_CategorieGenerique' in sql:
            return dict(self.parent) if params == [42] else None
        if 'T_ChampReferentiel' in sql:
            return None
        self.fail('Lecture inattendue : ' + sql)

    def actor(self, *, local=False, manage=True, admin=True):
        actor = Actor({'IdUser': 15, 'Is_Admin': not local and admin, 'Is_staff': admin, 'IdEntiteFk': 7})
        actor._context_entity = 7
        actor._module_access = {'modules': {'logistique': {'canRead': True, 'canManage': manage, 'canExport': True}}}
        return actor

    def workbook(self, kind='valeurs', headers=None, rows=None):
        book = Workbook(); sheet = book.active
        sheet.title = 'Valeurs' if kind == 'valeurs' else 'Catégories'
        sheet.append(headers or [column['key'] for column in COLUMNS[kind]])
        for row in rows if rows is not None else [['Nouvelle valeur', '001', 'Informations\nsuite', 'Non', 'Non renseigné', 'Non']]:
            sheet.append(row)
        stream = io.BytesIO(); book.save(stream)
        return SimpleUploadedFile('references.xlsx', stream.getvalue(), content_type='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')

    def post(self, *, kind='valeurs', actor=None, file=None, **extra):
        body = {'fichier': file or self.workbook(kind), 'scope': 'global', **({'categoryId': '42'} if kind == 'valeurs' else {}), **extra}
        request = self.factory.post(BASE + kind + '/import-excel', body, format='multipart')
        if actor is not False:
            force_authenticate(request, actor or self.actor())
        return ReferenceExcelImportView.as_view()(request, kind=kind)

    def test_values_file_preserves_codes_notes_and_all_visibility_columns(self):
        response = self.post()
        self.assertEqual(response.status_code, 200, response.data)
        data = response.data['data']
        self.assertEqual(data['count'], 1)
        self.assertEqual(data['maxRows'], 100)
        self.assertEqual(data['cells'][0], [column['key'] for column in COLUMNS['valeurs']])
        self.assertEqual(data['cells'][1][1:6], ['001', 'Informations\nsuite', 'Non', 'Non renseigné', 'Non'])
        self.assertNotIn('ID_CategorieGeneriqueFk', data['cells'][0])
        self.assertNotIn('IdEntiteFk', data['cells'][0])

    def test_categories_file_is_separate_and_read_only(self):
        response = self.post(kind='categories', file=self.workbook('categories', rows=[['Famille', 'LOG', False]]))
        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(response.data['data']['cells'][0], [column['key'] for column in COLUMNS['categories']])
        self.assertEqual(response.data['data']['count'], 1)
        self.assertEqual(response.data['data']['cells'][1][2], 'FALSE')
        self.assertFalse(self.queries)

    def test_actual_templates_are_empty_native_workbooks(self):
        for kind in ('categories', 'valeurs'):
            request = self.factory.get(BASE + kind + '/modele-excel', {'scope': 'global', **({'categoryId': 42} if kind == 'valeurs' else {})})
            force_authenticate(request, self.actor())
            response = ReferenceExcelTemplateView.as_view()(request, kind=kind)
            self.assertEqual(response.status_code, 200)
            self.assertIn('.xlsx', response['Content-Disposition'])
            book = load_workbook(io.BytesIO(b''.join(response.streaming_content)))
            sheet = book['Valeurs' if kind == 'valeurs' else 'Catégories']
            self.assertEqual([cell.value for cell in sheet[1]], [column['label'] for column in COLUMNS[kind]])
            self.assertEqual(sheet.freeze_panes, 'A2')
            self.assertTrue(sheet.auto_filter.ref)
            self.assertTrue(all(cell.value is None for row in sheet.iter_rows(min_row=2) for cell in row))
            self.assertIn('Informations', book.sheetnames)
            self.assertTrue(sheet.data_validations.count)
            response.close()

    def test_own_template_round_trip_and_flexible_column_order(self):
        request = self.factory.get(BASE + 'valeurs/modele-excel', {'scope': 'global', 'categoryId': 42})
        force_authenticate(request, self.actor())
        response = ReferenceExcelTemplateView.as_view()(request, kind='valeurs')
        book = load_workbook(io.BytesIO(b''.join(response.streaming_content)))
        book['Valeurs']['A2'] = 'Valeur de recette'
        book['Valeurs']['B2'] = '0007'
        book['Valeurs']['F2'] = 'Non'
        stream = io.BytesIO(); book.save(stream); response.close()
        imported = self.post(file=SimpleUploadedFile('modele.xlsx', stream.getvalue()))
        self.assertEqual(imported.status_code, 200, imported.data)
        self.assertEqual(imported.data['data']['cells'][1][1], '0007')
        self.assertEqual(imported.data['data']['cells'][1][5], 'Non')
        reordered = self.post(file=self.workbook(headers=['État', 'Libellé'], rows=[['Non', 'Autre valeur']]))
        self.assertEqual(reordered.status_code, 200, reordered.data)
        self.assertEqual(reordered.data['data']['cells'], [['ValideGenerique', 'NomGenerique'], ['Non', 'Autre valeur']])

    def test_missing_or_unauthorized_parent_and_local_scope(self):
        self.assertEqual(self.post(categoryId='999').status_code, 422)
        self.parent['IdEntiteFk'] = 8
        self.assertEqual(self.post(scope='entity', scopeValue='7').status_code, 422)
        self.parent['IdEntiteFk'] = None
        self.assertEqual(self.post(actor=self.actor(local=True), scope='entity', scopeValue='7').status_code, 200)
        self.assertEqual(self.post(actor=self.actor(local=True)).status_code, 403)
        self.assertEqual(self.post(actor=self.actor(local=True), scope='entity', scopeValue='8').status_code, 403)
        self.parent['ValideCategorieGenerique'] = False
        self.assertEqual(self.post().status_code, 422)

    def test_permission_denied_before_workbook_reader(self):
        for actor in (self.actor(manage=False), self.actor(admin=False), False):
            with patch('apps.core.reference_excel.read_uploaded_workbook', side_effect=AssertionError('Ne pas lire un fichier non autorisé.')):
                self.assertIn(self.post(actor=actor).status_code, (401, 403))

    def test_identifiers_parent_unknown_headers_and_other_fields_refused(self):
        for headers in (['Libellé', 'ID_Generique'], ['Libellé', 'ID_CategorieGeneriqueFk'], ['Libellé', 'IdEntiteFk'], ['Libellé', 'Inconnue']):
            response = self.post(file=self.workbook(headers=headers, rows=[['Valeur', '12']]))
            self.assertIn(response.status_code, (400, 422), response.data)
        self.assertIn(self.post(extra='non autorisé').status_code, (400, 422))

    def test_duplicate_missing_header_and_formulas_rejected(self):
        for headers, rows in ((['Libellé', 'Libellé'], [['A', 'B']]), (['Code'], [['X']]), (['Libellé'], [['=1+1']])):
            response = self.post(file=self.workbook(headers=headers, rows=rows))
            self.assertIn(response.status_code, (400, 422), response.data)

    def test_limit_hundred_data_rows_and_wrong_format(self):
        self.assertEqual(self.post(file=self.workbook(headers=['Libellé'], rows=[['Valeur ' + str(i)] for i in range(100)])).status_code, 200)
        response = self.post(file=self.workbook(headers=['Libellé'], rows=[['Valeur ' + str(i)] for i in range(101)]))
        self.assertIn(response.status_code, (400, 422))
        self.assertIn(self.post(file=SimpleUploadedFile('valeurs.csv', b'Libelle\nValeur')).status_code, (400, 422))


if __name__ == '__main__':
    unittest.main(verbosity=2)
