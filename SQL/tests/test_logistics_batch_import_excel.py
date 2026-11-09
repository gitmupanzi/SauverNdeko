"""Classeurs et API d'aperçu Logistique réels, sans connexion applicative."""
import io
import os
import sys
import unittest
from datetime import datetime
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'backend'))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
import django
django.setup()
from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import override_settings
from openpyxl import Workbook, load_workbook
from rest_framework.test import APIRequestFactory, force_authenticate
from apps.accounts.authentication import Actor
from apps.core.responses import APIError
from apps.logistique.batch_excel import COLUMNS, LogisticsExcelPreviewView, LogisticsExcelTemplateView


class LogisticsBatchExcelTests(unittest.TestCase):
    def setUp(self):
        self.factory = APIRequestFactory()
        self.settings = override_settings(DB_READ_ONLY=True)
        self.settings.enable(); self.addCleanup(self.settings.disable)
        for target in ('django.db.backends.base.base.BaseDatabaseWrapper.ensure_connection',
                       'apps.core.db.one', 'apps.core.db.query'):
            guard = patch(target, side_effect=AssertionError('Aucune connexion, lecture ou écriture applicative autorisée.'))
            guard.start(); self.addCleanup(guard.stop)
        self.allow = patch('apps.core.module_access.enforce_request')
        self.allow.start(); self.addCleanup(self.allow.stop)
        self.module = patch('apps.logistique.batch_excel.require_module')
        self.module_mock = self.module.start(); self.addCleanup(self.module.stop)
        self.writable = patch('apps.logistique.batch_excel.db.ensure_writable')
        self.writable_mock = self.writable.start(); self.addCleanup(self.writable.stop)
        self.entity = patch('apps.logistique.batch_excel.require_entity', return_value=7)
        self.entity_mock = self.entity.start(); self.addCleanup(self.entity.stop)
        self.refs = {'typesClients': [{'id': 30, 'label': 'CLI', 'NomGenerique': 'Client détaillé'}],
            'users': [{'id': 5, 'label': 'Alice'}], 'professionnels': [], 'entites': [],
            'types': [{'id': 40, 'label': 'MAT', 'NomGenerique': 'Matériel long'},
                      {'id': 41, 'label': 'Hors périmètre', 'incompatible': True},
                      {'id': 42, 'label': 'Inactif', 'active': False}],
            'etats': [], 'responsables': [{'id': 5, 'label': 'Alice'}], 'services': [],
            'localisations': [{'id': 8, 'label': 'COD/Kinshasa/Bureau'}],
            'currencies': [{'id': 451, 'label': 'USD'}]}
        for name in ('tiers', 'immobilisations'):
            patched = patch(f'apps.logistique.batch_excel.{name}.references', return_value=self.refs)
            patched.start(); self.addCleanup(patched.stop)

    def actor(self, admin=True):
        return Actor({'IdUser': 15, 'Is_staff': admin, 'Is_Admin': False, 'IdEntiteFk': 7})

    def workbook(self, kind='tiers', headers=None, rows=None, sheet=None):
        book = Workbook(); ws = book.active
        ws.title = sheet or ('Tiers' if kind == 'tiers' else 'Immobilisations')
        ws.append(headers or [column[0] for column in COLUMNS[kind]])
        for row in rows if rows is not None else [['Alice', 'CLI', 'Personne', 'a@example.invalid', '00123']]:
            ws.append(row)
        stream = io.BytesIO(); book.save(stream); book.close()
        return SimpleUploadedFile('panier.xlsx', stream.getvalue())

    def post(self, kind='tiers', file=None, actor=None, **extra):
        request = self.factory.post('/api/logistique/saisie-multiple/' + kind + '/import-excel',
            {'fichier': file or self.workbook(kind), **extra}, format='multipart')
        force_authenticate(request, actor or self.actor())
        return LogisticsExcelPreviewView.as_view()(request, kind=kind)

    def template(self, kind):
        request = self.factory.get('/api/logistique/saisie-multiple/' + kind + '/modele-excel')
        force_authenticate(request, self.actor())
        return LogisticsExcelTemplateView.as_view()(request, kind=kind)

    def test_tiers_preview_preserves_text_and_does_not_resolve_or_save(self):
        response = self.post()
        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(response.data['data']['cells'][1][4], '00123')
        self.assertEqual(response.data['data']['cells'][1][1], 'CLI')
        self.assertEqual(response.data['data']['count'], 1)
        self.entity_mock.assert_called_once()
        self.module_mock.assert_called_once_with(unittest.mock.ANY, 'logistique', 'manage')

    def test_dates_and_exact_quantities_remain_correctable(self):
        file = self.workbook('immobilisations', headers=['Nom du bien', 'Date et heure d’entrée', 'Quantité', 'Date d’acquisition'],
            rows=[['Bureau', datetime(2026, 11, 7, 12, 13, 14), '9007199254740993', '31/02/2026']])
        response = self.post('immobilisations', file)
        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(response.data['data']['cells'], [['NomImmobilisation', 'DateEntree', 'Quantite', 'DateAcquisition'],
            ['Bureau', '2026-11-07T12:13:14', '9007199254740993', '31/02/2026']])

    def test_immobilisation_location_import_accepts_free_text_and_legacy_headers(self):
        for headers, row, keys in [
            (['Nom du bien', 'Localisation (texte libre)'], ['Bureau', 'Bâtiment B, bureau 12'],
             ['NomImmobilisation', 'LocalisationComplement']),
            (['Nom du bien', 'Localisation', 'Bureau ou salle'], ['Bureau', '6', 'Salle 3'],
             ['NomImmobilisation', 'ID_LocalisationFk', 'LocalisationComplement']),
        ]:
            with self.subTest(headers=headers):
                response = self.post('immobilisations', self.workbook('immobilisations', headers=headers, rows=[row]))
                self.assertEqual(response.status_code, 200, response.data)
                self.assertEqual(response.data['data']['cells'], [keys, row])

    def test_unknown_reference_is_returned_for_correction(self):
        response = self.post(file=self.workbook(headers=['Nom', 'Type de tiers'], rows=[['Alice', 'Référence à corriger']]))
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['data']['cells'][1][1], 'Référence à corriger')

    def test_legacy_type_client_header_is_supported(self):
        response = self.post(file=self.workbook(headers=['Nom', 'Type de client'], rows=[['Alice', '30']]))
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['data']['cells'][0], ['Nom', 'ID_TypeClientFk'])

    def test_both_templates_are_empty_text_and_use_authorized_labels(self):
        for kind in COLUMNS:
            with self.subTest(kind=kind):
                response = self.template(kind)
                self.assertEqual(response.status_code, 200)
                self.assertEqual(response['Cache-Control'], 'no-store, private')
                book = load_workbook(io.BytesIO(b''.join(response.streaming_content)))
                try:
                    ws = book['Tiers' if kind == 'tiers' else 'Immobilisations']
                    self.assertEqual([cell.value for cell in ws[1]], [col[1] for col in COLUMNS[kind]])
                    self.assertTrue(all(cell.value in ('', None) for row in ws.iter_rows(min_row=2) for cell in row))
                    self.assertEqual(ws.freeze_panes, 'A2')
                    self.assertEqual(ws['A1'].fill.fgColor.rgb, '00F3F4F6')
                    options = [cell.value for row in book['Options'] for cell in row]
                    self.assertIn('CLI' if kind == 'tiers' else 'MAT', options)
                    self.assertNotIn('Client détaillé', options)
                    self.assertNotIn('Matériel long', options)
                    self.assertNotIn('Hors périmètre', options)
                    self.assertNotIn('Inactif', options)
                    self.assertNotIn('IdEntiteFk', [cell.value for cell in ws[1]])
                finally:
                    book.close(); response.close()

    def test_denied_module_is_checked_before_reading_bad_file(self):
        self.module_mock.side_effect = APIError('Accès refusé.', 'FORBIDDEN', 403)
        response = self.post(file=SimpleUploadedFile('bad.xlsx', b'not an archive'))
        self.assertEqual(response.status_code, 403)
        self.entity_mock.assert_not_called()

    def test_readonly_is_checked_before_reading_bad_file(self):
        self.writable_mock.side_effect = APIError('Lecture seule.', 'READ_ONLY', 403)
        response = self.post(file=SimpleUploadedFile('bad.xlsx', b'not an archive'))
        self.assertEqual(response.status_code, 403)

    def test_nonmanager_cannot_import(self):
        response = self.post(actor=self.actor(False))
        self.assertEqual(response.status_code, 403)
        self.module_mock.assert_not_called()

    def test_entity_required_before_parsing(self):
        self.entity_mock.side_effect = APIError('Choisissez une entreprise.', 'ENTITY_REQUIRED', 409)
        response = self.post(file=SimpleUploadedFile('bad.xlsx', b'not an archive'))
        self.assertEqual(response.status_code, 409)

    def test_unknown_kind_is_not_a_generic_table_import(self):
        response = self.post('mouvements', self.workbook())
        self.assertEqual(response.status_code, 404)
        self.entity_mock.assert_not_called()

    def test_forbidden_columns_are_rejected(self):
        for kind, field in [('tiers', 'IdEntiteFk'), ('tiers', 'requestId'), ('immobilisations', 'CodeImmobilisation'),
                            ('immobilisations', '_version'), ('immobilisations', 'photoDataUrl')]:
            with self.subTest(kind=kind, field=field):
                name = 'Nom' if kind == 'tiers' else 'NomImmobilisation'
                response = self.post(kind, self.workbook(kind, headers=[name, field], rows=[['Bien', '9']]))
                self.assertEqual(response.status_code, 400)

    def test_formula_duplicate_header_missing_name_and_overflow_rejected(self):
        for headers, rows in [(['Nom', 'Email'], [['=2+3', 'x']]), (['Nom', 'Nom du tiers'], [['A', 'B']]),
                              (['Email'], [['a@example.invalid']]), (['Nom'], [['A']] * 101)]:
            with self.subTest(headers=headers, count=len(rows)):
                self.assertEqual(self.post(file=self.workbook(headers=headers, rows=rows)).status_code, 400)

    def test_extra_multipart_parameters_rejected(self):
        response = self.post(IdEntiteFk='8')
        self.assertEqual(response.status_code, 400)

    def test_large_upload_rejected(self):
        response = self.post(file=SimpleUploadedFile('large.xlsx', b' ' * (4 * 1024 * 1024 + 1)))
        self.assertEqual(response.status_code, 413)


if __name__ == '__main__':
    unittest.main()
