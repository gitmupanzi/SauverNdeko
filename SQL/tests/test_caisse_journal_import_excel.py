"""Modèles/imports écritures et clôtures : classeurs réels, aucune base applicative.

Exécuter seul. La lecture prépare un panier ; elle ne simule pas une validation
comptable et ne remplace pas la recette des services PostgreSQL existants.
"""
import io
import sys
import unittest
from datetime import datetime
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'backend'))
from django.conf import settings
if not settings.configured:
    settings.configure(SECRET_KEY='cash-journal-excel-memory-tests', BASE_DIR=ROOT / 'backend',
        DATABASES={'default': {'ENGINE': 'django.db.backends.sqlite3', 'NAME': ':memory:'}},
        INSTALLED_APPS=[], USE_TZ=True, TIME_ZONE='Africa/Kinshasa', DB_READ_ONLY=False,
        REST_FRAMEWORK={'DEFAULT_AUTHENTICATION_CLASSES': [], 'UNAUTHENTICATED_USER': None})
import django
django.setup()
from django.core.files.uploadedfile import SimpleUploadedFile
from django.db import connection
from openpyxl import Workbook, load_workbook
from rest_framework.test import APIRequestFactory
from apps.caisse import excel_import as excel
from apps.core.responses import APIError


def workbook(kind, rows):
    book = Workbook()
    book.active.title = excel.JOURNAL_SHEETS[kind]
    for row in rows:
        book.active.append(row)
    result = io.BytesIO()
    book.save(result)
    book.close()
    return result.getvalue()


class CashJournalExcelTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if connection.vendor != 'sqlite' or connection.settings_dict['NAME'] != ':memory:':
            raise RuntimeError('SQLite mémoire obligatoire ; aucune base applicative autorisée.')

    def setUp(self):
        self.actor = SimpleNamespace(pk=7, admin=True, organisation=9, is_authenticated=True)
        self.factory = APIRequestFactory()
        self.references = {
            'caisses': [
                {'IdCaisse': '9007199254740993', 'CodeCaisse': 'CAI-1', 'NomCaisse': 'Caisse site', 'DeviseCode': 'USD', 'Actif': True, '_version': '19'},
                {'IdCaisse': 2, 'NomCaisse': 'Archivée', 'Actif': False},
            ],
            'typesPaiements': [{'id': 81, 'abbr': 'VIR', 'label': 'Libellé long à ne pas afficher'},
                               {'id': 82, 'abbr': 'MASQUÉ', 'incompatible': True}],
            'tiers': [{'id': 91, 'label': 'Tiers autorisé'}],
        }
        self.db_guard = patch.object(excel.db, 'query', side_effect=AssertionError('Lecture applicative interdite'))
        self.db_guard.start()
        self.addCleanup(self.db_guard.stop)

    def request(self, kind, rows=None, *, binary=None, name='journal.xlsx', extra=None):
        binary = workbook(kind, rows) if binary is None else binary
        payload = {'fichier': SimpleUploadedFile(name, binary), **(extra or {})}
        view = excel.CashExcelPreviewView()
        raw = self.factory.post('/preview', payload, format='multipart')
        request = view.initialize_request(raw)
        request.user = self.actor
        return view, request

    def preview(self, kind, rows=None, **kwargs):
        view, request = self.request(kind, rows, **kwargs)
        with patch.object(excel.services, 'writable', return_value=9):
            return view.post(request, kind).data['data']['cells']

    def test_models_are_blank_native_tables_with_authorized_choices_and_abr(self):
        for kind, fields in excel.JOURNAL_FIELDS.items():
            with self.subTest(kind=kind), patch.object(excel.services, 'references', return_value=self.references) as refs:
                book = load_workbook(excel.build_journal_template(self.actor, kind))
                refs.assert_called_once_with(self.actor)
                sheet = book[excel.JOURNAL_SHEETS[kind]]
                self.assertEqual([cell.value for cell in sheet[1]], [label for _, label, _ in fields])
                self.assertTrue(all(cell.value in ('', None) for row in sheet.iter_rows(min_row=2) for cell in row))
                self.assertEqual(sheet.freeze_panes, 'A2')
                self.assertEqual(sheet.print_title_rows, '$1:$1')
                option_values = [cell.value for row in book['Options'] for cell in row]
                self.assertIn('9007199254740993', option_values)
                self.assertNotIn('Archivée', option_values)
                self.assertNotIn('MASQUÉ', option_values)
                self.assertNotIn('19', option_values)
                if kind == 'ecritures':
                    self.assertIn('VIR', option_values)
                    self.assertNotIn('Libellé long à ne pas afficher', option_values)
                    self.assertIn('Encaissement', option_values)
                    self.assertIn('Décaissement', option_values)
                book.close()

    def test_template_endpoint_keeps_existing_permission_and_private_cache(self):
        request = SimpleNamespace(user=self.actor, query_params={})
        with patch.object(excel.services, 'writable', return_value=9) as writable, patch.object(excel.services, 'references', return_value=self.references):
            for kind in excel.JOURNAL_FIELDS:
                response = excel.CashExcelTemplateView().get(request, kind)
                self.assertEqual(response['Content-Type'], excel.XLSX_MEDIA_TYPE)
                self.assertEqual(response['Cache-Control'], 'no-store, private')
                self.assertIn(excel.JOURNAL_SHEETS[kind], response['Content-Disposition'])
                response.close()
            self.assertEqual(writable.call_count, 2)

    def test_preview_converts_native_dates_without_losing_ids_or_zero_count(self):
        rows = [['Caisse', 'Date et heure du comptage', 'Montant compté', 'Motif'],
                ['9007199254740993', datetime(2026, 11, 7, 14, 5, 3), 0, 'Inventaire']]
        self.assertEqual(self.preview('clotures', rows), [
            ['IdCaisseFk', 'ClotureLe', 'MontantCompte', 'motif'],
            ['9007199254740993', '2026-11-07T14:05:03', '0', 'Inventaire']])

    def test_entry_preview_preserves_invalid_values_for_basket_correction(self):
        rows = [['IdCaisseFk', 'DatePaiement', 'SensMouvement', 'LibellePaiement', 'MontantPaiement', 'IdTypePaiementFk'],
                ['0007', 'date à corriger', 'inconnu', '001 prestation', '-4,123', 'VIR']]
        self.assertEqual(self.preview('ecritures', rows), rows)

    def test_preview_does_not_call_any_writing_service(self):
        rows = [['Caisse', 'Date et heure du comptage', 'Montant compté', 'Motif'], ['1', '07/11/2026 14:00', '0', 'Comptage']]
        with patch.object(excel.services, 'create_entry') as entry, patch.object(excel.services, 'close_cash') as close, patch.object(excel.services, 'create_cash') as cash:
            self.preview('clotures', rows)
            entry.assert_not_called()
            close.assert_not_called()
            cash.assert_not_called()

    def test_permission_is_checked_before_parsing_or_model_reference_read(self):
        class ForbiddenRequest:
            user = self.actor
            @property
            def data(self):
                raise AssertionError('Le corps ne doit pas être lu.')
        for kind in excel.JOURNAL_FIELDS:
            for view, method in [(excel.CashExcelPreviewView(), 'post'), (excel.CashExcelTemplateView(), 'get')]:
                with self.subTest(kind=kind, method=method), patch.object(excel.services, 'writable', side_effect=APIError('Interdit', status=403)), patch.object(excel.services, 'references') as references:
                    with self.assertRaises(APIError) as caught:
                        getattr(view, method)(ForbiddenRequest(), kind)
                    self.assertEqual(caught.exception.status_code, 403)
                    references.assert_not_called()

    def test_server_fields_and_owner_injection_are_refused(self):
        base = ['IdCaisseFk', 'ClotureLe', 'MontantCompte', 'motif']
        for field in ['_version', 'SoldeTheorique', 'CodePaiement', 'CodeCaisse', 'valider', 'IdEntiteFk']:
            with self.subTest(field=field), self.assertRaises(APIError):
                self.preview('clotures', [base + [field], ['1', '2026-11-07T14:00', '0', 'Comptage', '999']])

    def test_invalid_headers_and_formulas_and_empty_model_are_refused(self):
        cases = [
            [['IdCaisseFk'], ['1']],
            [['IdCaisseFk', 'ClotureLe', 'MontantCompte', 'motif', 'Caisse'], ['1', '2026-11-07T14:00', '0', 'X', '1']],
            [['IdCaisseFk', 'ClotureLe', 'MontantCompte', 'motif'], ['1', '2026-11-07T14:00', '=1+2', 'X']],
            [['IdCaisseFk', 'ClotureLe', 'MontantCompte', 'motif']],
        ]
        for rows in cases:
            with self.subTest(rows=rows), self.assertRaises(APIError):
                self.preview('clotures', rows)

    def test_limit_100_and_101_and_single_multipart_file(self):
        head = ['IdCaisseFk', 'ClotureLe', 'MontantCompte', 'motif']
        row = ['1', '2026-11-07T14:00', '0', 'Comptage']
        self.assertEqual(len(self.preview('clotures', [head] + [row] * 100)), 101)
        with self.assertRaisesRegex(APIError, '100 lignes'):
            self.preview('clotures', [head] + [row] * 101)
        with self.assertRaises(APIError):
            self.preview('clotures', [head, row], extra={'IdEntiteFk': 999})
        with self.assertRaises(APIError):
            self.preview('clotures', binary=b'x' * (4 * 1024 * 1024 + 1))


if __name__ == '__main__':
    unittest.main()
