"""Modèle et aperçu Excel Caisse : fichiers en mémoire, aucune base autorisée."""
import io
import os
import sys
import unittest
from pathlib import Path
from unittest.mock import patch
from zipfile import ZIP_DEFLATED, ZipFile

import django
from openpyxl import Workbook, load_workbook

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'backend'))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import SimpleTestCase, override_settings
from rest_framework.test import APIClient

from apps.accounts.authentication import Actor
from apps.caisse.excel_import import HEADERS, read_cash_workbook
from apps.core.responses import APIError
from apps.logistique.article_xlsx import MAX_UPLOAD_BYTES

BASE = '/api/caisse/caisses/'


def workbook(rows, *, title='Caisses', extra_sheet=True):
    book = Workbook()
    sheet = book.active
    sheet.title = title
    for row in rows:
        sheet.append(row)
    if extra_sheet:
        book.create_sheet('Informations').append(['=2+3', 'Feuille ignorée'])
    target = io.BytesIO()
    book.save(target)
    book.close()
    return target.getvalue()


def upload(binary, name='caisses.xlsx'):
    return SimpleUploadedFile(name, binary)


def replace_part(binary, part_name, transform):
    target = io.BytesIO()
    with ZipFile(io.BytesIO(binary)) as source, ZipFile(target, 'w', ZIP_DEFLATED) as result:
        for name in source.namelist():
            part = source.read(name)
            result.writestr(name, transform(part) if name == part_name else part)
    return target.getvalue()


class CashExcelReaderTests(SimpleTestCase):
    def test_keeps_positions_text_boolean_and_empty_optional_values(self):
        binary = workbook([HEADERS, ['001 Caisse', 'USD', None, '0009', False, '=texte littéral']])
        # Les textes ressemblant à une formule doivent être explicitement du texte.
        book = load_workbook(io.BytesIO(binary))
        book['Caisses']['F2'].data_type = 's'
        target = io.BytesIO()
        book.save(target)
        book.close()
        self.assertEqual(read_cash_workbook(upload(target.getvalue())), [list(HEADERS),
            ['001 Caisse', 'USD', '', '0009', 'FALSE', '=texte littéral']])

    def test_single_compatible_sheet_and_form_field_headers_are_accepted(self):
        rows = [['NomCaisse', 'IdDeviseFk', 'Actif'], ['Caisse A', '0012', True]]
        self.assertEqual(read_cash_workbook(upload(workbook(rows, title='Saisie', extra_sheet=False))),
            [rows[0], ['Caisse A', '0012', 'TRUE']])

    def test_accepts_100_nonempty_rows_and_refuses_101(self):
        rows = [['Caisse', 'Devise']] + [[f'Caisse {i}', 'USD'] for i in range(100)]
        self.assertEqual(len(read_cash_workbook(upload(workbook(rows)))), 101)
        with self.assertRaisesRegex(APIError, '100 caisses'):
            read_cash_workbook(upload(workbook(rows + [['Caisse de trop', 'USD']])))

    def test_empty_rows_are_ignored_and_dimensions_do_not_hide_data(self):
        binary = workbook([['Caisse', 'Devise'], ['Caisse A', 'USD'], [], ['Caisse B', 'CDF']])
        binary = replace_part(binary, 'xl/worksheets/sheet1.xml',
            lambda part: part.replace(b'<dimension ref="A1:B4"', b'<dimension ref="A1"'))
        self.assertEqual(read_cash_workbook(upload(binary)), [
            ['Caisse', 'Devise'], ['Caisse A', 'USD'], ['Caisse B', 'CDF']])

    def test_refuses_other_sheets_empty_template_and_wrong_headers(self):
        samples = [
            (workbook([HEADERS], title='Saisie'), 'feuille Caisses est introuvable'),
            (workbook([HEADERS]), 'feuille Caisses est vide'),
            (workbook([[], HEADERS]), 'en-têtes sur la première ligne'),
            (workbook([['Caisse', 'Solde'], ['A', 10]]), 'noms des colonnes'),
            (workbook([['Caisse', 'Devise', 'IdDeviseFk'], ['A', 1, 1]]), 'en-têtes en double'),
            (workbook([['Caisse'], ['A']]), 'Caisse et Devise sont obligatoires'),
            (workbook([['Caisse', 'Devise'], ['A', 'USD', 'sans en-tête']]), 'ligne 2'),
        ]
        for binary, message in samples:
            with self.subTest(message=message), self.assertRaisesRegex(APIError, message):
                read_cash_workbook(upload(binary))

    def test_formulas_and_excel_errors_are_refused_in_the_imported_sheet(self):
        for value, message in [('=2+3', 'une formule'), ('#REF!', 'une erreur Excel')]:
            with self.subTest(value=value), self.assertRaisesRegex(APIError, 'A2 contient ' + message) as error:
                read_cash_workbook(upload(workbook([['Caisse', 'Devise'], [value, 'USD']])))
            self.assertEqual(error.exception.default_code, 'CAISSE_EXCEL_INVALID')

    def test_refuses_corrupt_zip_macros_external_workbook_links_and_xml_dtd(self):
        binary = workbook([['Caisse', 'Devise'], ['A', 'USD']])
        samples = [b'invalide',
            replace_part(binary, 'xl/worksheets/sheet1.xml', lambda part: b'<!DOCTYPE worksheet>' + part),
            replace_part(binary, '[Content_Types].xml', lambda part: part.replace(
                b'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml',
                b'application/vnd.ms-excel.sheet.macroEnabled.main+xml')),
            replace_part(binary, 'xl/_rels/workbook.xml.rels', lambda part: part.replace(
                b'Type="', b'TargetMode="External" Type="', 1)),
            replace_part(binary, 'xl/worksheets/sheet1.xml', lambda part: part.replace(b'r="B2"', b'r="A2"')),
        ]
        for sample in samples:
            with self.subTest(length=len(sample)), self.assertRaises(APIError) as error:
                read_cash_workbook(upload(sample))
            self.assertEqual(error.exception.default_code, 'CAISSE_EXCEL_INVALID')

    def test_rejects_zip_bomb_wide_sparse_cells_and_large_or_non_xlsx_files(self):
        target = io.BytesIO()
        with ZipFile(target, 'w', ZIP_DEFLATED) as archive:
            archive.writestr('xl/worksheets/sheet1.xml', b'x' * (13 * 1024 * 1024))
        for binary, name, code in [
            (target.getvalue(), 'caisses.xlsx', 'CAISSE_EXCEL_INVALID'),
            (workbook([['Caisse', 'Devise'], ['A', 'USD'] + [None] * 62 + ['Trop loin']]), 'caisses.xlsx', 'CAISSE_EXCEL_INVALID'),
            (b'x' * (MAX_UPLOAD_BYTES + 1), 'caisses.xlsx', 'CAISSE_EXCEL_SIZE'),
            (b'non-xlsx', 'caisses.xls', 'CAISSE_EXCEL_INVALID'),
            (b'', 'caisses.xlsx', 'CAISSE_EXCEL_INVALID'),
        ]:
            with self.subTest(name=name, length=len(binary)), self.assertRaises(APIError) as error:
                read_cash_workbook(upload(binary, name))
            self.assertEqual(error.exception.default_code, code)


@override_settings(ALLOWED_HOSTS=['testserver'], DB_READ_ONLY=False)
class CashExcelAPITests(SimpleTestCase):
    def client_for(self, *, read=True, manage=True, admin=True, global_admin=False, entity=9):
        actor = Actor({'IdUser': 5, 'Is_Admin': global_admin, 'Is_staff': admin, 'IdEntiteFk': entity})
        if global_admin and entity:
            actor._context_entity = entity
        actor._module_access = {'modules': {'caisse': {'canRead': read, 'canManage': manage,
            'canExport': False, 'reason': 'MODULE_ROLE_FORBIDDEN'}}}
        client = APIClient()
        client.force_authenticate(actor)
        return client

    def test_import_returns_only_cell_matrix_and_never_calls_creation(self):
        rows = [['Caisse', 'Devise'], ['A', 'USD']]
        with patch('apps.core.tenancy.db.one', return_value={'ValideEntite': True}) as entity, \
                patch('apps.caisse.services.create_cash') as create, \
                patch('apps.caisse.services.insert') as insert:
            response = self.client_for().post(BASE + 'import-excel/', {'fichier': upload(workbook(rows))}, format='multipart')
        self.assertEqual(response.status_code, 200, response.json())
        self.assertEqual(response.json()['data'], {'cells': rows})
        self.assertEqual(entity.call_args.args[1], [9])
        create.assert_not_called()
        insert.assert_not_called()

    def test_both_routes_check_read_manage_role_and_active_entity(self):
        for template in (True, False):
            for rights in ({'read': False}, {'manage': False}, {'admin': False}):
                with self.subTest(template=template, rights=rights), patch('apps.core.tenancy.db.one') as entity:
                    client = self.client_for(**rights)
                    response = client.get(BASE + 'modele-excel') if template else client.post(
                        BASE + 'import-excel', {'fichier': upload(b'invalide')}, format='multipart')
                    self.assertEqual(response.status_code, 403, response.json())
                    entity.assert_not_called()
            with patch('apps.core.tenancy.db.one', return_value={'ValideEntite': False}):
                response = self.client_for().get(BASE + 'modele-excel') if template else self.client_for().post(
                    BASE + 'import-excel', {'fichier': upload(b'invalide')}, format='multipart')
            self.assertEqual(response.status_code, 409, response.json())
            self.assertEqual(response.json()['error']['code'], 'ENTITY_INACTIVE')

    def test_readonly_and_missing_global_context_refuse_before_parsing_file(self):
        with override_settings(DB_READ_ONLY=True), patch('apps.core.tenancy.db.one') as entity:
            response = self.client_for().post(BASE + 'import-excel', {'fichier': upload(b'invalide')}, format='multipart')
            self.assertEqual(response.status_code, 503, response.json())
            self.assertEqual(response.json()['error']['code'], 'READ_ONLY')
            entity.assert_not_called()
        with patch('apps.core.tenancy.db.one') as entity:
            response = self.client_for(global_admin=True, entity=None).get(BASE + 'modele-excel')
            self.assertEqual(response.status_code, 409, response.json())
            self.assertEqual(response.json()['error']['code'], 'ENTITY_REQUIRED')
            entity.assert_not_called()

    def test_import_rejects_wrong_fields_multiple_files_and_oversized_envelope(self):
        binary = workbook([['Caisse', 'Devise'], ['A', 'USD']])
        with patch('apps.core.tenancy.db.one', return_value={'ValideEntite': True}):
            for fields in ({'file': upload(binary)}, {'fichier': 'caisses.xlsx'},
                    {'fichier': [upload(binary), upload(binary)]},
                    {'fichier': upload(binary), 'entreprise': '11'}):
                with self.subTest(fields=list(fields)):
                    response = self.client_for().post(BASE + 'import-excel', fields, format='multipart')
                    self.assertEqual(response.status_code, 400, response.json())
            for extra in (1, 128 * 1024):
                # +1 traverse le handler borné ; +128 Ko refuse l’enveloppe avant lecture.
                response = self.client_for().post(BASE + 'import-excel',
                    {'fichier': upload(b'x' * (MAX_UPLOAD_BYTES + extra))}, format='multipart')
                self.assertEqual(response.status_code, 413, response.json())
                self.assertEqual(response.json()['error']['code'], 'CAISSE_EXCEL_SIZE')

    def test_authentication_and_http_methods_are_closed(self):
        self.assertIn(APIClient().get(BASE + 'modele-excel').status_code, (401, 403))
        self.assertIn(APIClient().post(BASE + 'import-excel', {}, format='multipart').status_code, (401, 403))
        self.assertEqual(self.client_for().get(BASE + 'import-excel').status_code, 405)
        self.assertEqual(self.client_for().post(BASE + 'modele-excel', {}, format='json').status_code, 405)

    def test_template_has_native_text_and_only_eligible_options_for_selected_entity(self):
        def reference_options(actor, schema, table, field):
            self.assertEqual(actor.organisation, 9)
            self.assertEqual((schema, table), ('operations', 'T_Caisse'))
            if field == 'IdDeviseFk':
                return [{'id': 4, 'abbr': 'USD', 'name': 'Dollar américain', 'label': 'Ancien libellé'},
                    {'id': 5, 'abbr': '', 'name': 'Ne doit pas servir de libellé'},
                    {'id': 6, 'abbr': 'INACTIVE', 'active': False},
                    {'id': 7, 'abbr': 'INCOMPATIBLE', 'incompatible': True}]
            return [{'id': 8, 'abbr': '=texte littéral', 'name': 'Nom différent'},
                {'id': 10, 'abbr': 'DISABLED', 'disabled': True}]

        def one(sql, params):
            self.assertEqual(params, [9])
            return {'NomEntite': 'Entreprise autorisée'} if 'NomEntite' in sql else {'ValideEntite': True}

        with patch('apps.caisse.services.reference_options', side_effect=reference_options), \
                patch('apps.caisse.excel_import.db.one', side_effect=one), \
                patch('apps.caisse.excel_import.db.query', return_value=[{'id': 12, 'label': '=Responsable'}]) as owners:
            response = self.client_for().get(BASE + 'modele-excel', HTTP_ACCEPT='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
            self.assertEqual(response.status_code, 200)
            self.assertEqual(response['Cache-Control'], 'no-store, private')
            binary = b''.join(response.streaming_content)
            response.close()
        owners.assert_called_once()
        self.assertEqual(owners.call_args.args[1], [9])
        self.assertIn('"ValideUser" IS TRUE', owners.call_args.args[0])
        book = load_workbook(io.BytesIO(binary))
        try:
            self.assertEqual(book.sheetnames, ['Caisses', 'Options', 'Informations'])
            sheet = book['Caisses']
            self.assertEqual([cell.value for cell in sheet[1]], list(HEADERS))
            self.assertTrue(all(cell.value is None for row in sheet.iter_rows(min_row=2) for cell in row))
            self.assertEqual(sheet['A1'].fill.fgColor.rgb, '00F3F4F6')
            self.assertEqual(sheet['A1'].font.color.rgb, '00374151')
            self.assertEqual(sheet['A2'].number_format, '@')
            self.assertEqual(sheet.freeze_panes, 'A2')
            self.assertEqual(sheet.auto_filter.ref, 'A1:F101')
            self.assertEqual(len(sheet.data_validations.dataValidation), 4)
            options = book['Options']
            self.assertEqual(options['A2'].value, '4')
            self.assertEqual(options['B2'].value, 'USD')
            self.assertEqual(options['B3'].value, 'Valeur sans abréviation #5')
            self.assertEqual(options['D2'].value, '=texte littéral')
            self.assertEqual(options['D2'].data_type, 's')
            self.assertEqual(options['F2'].data_type, 's')
            self.assertEqual(book['Informations']['B3'].value, 'Entreprise autorisée')
            self.assertFalse(any(cell.data_type == 'f' for sheet in book for row in sheet for cell in row))
        finally:
            book.close()
        with self.assertRaisesRegex(APIError, 'feuille Caisses est vide'):
            read_cash_workbook(upload(binary))
        # Le modèle téléchargé, une fois complété, est directement réimportable.
        book = load_workbook(io.BytesIO(binary))
        book['Caisses']['A2'] = 'Caisse complétée'
        book['Caisses']['B2'] = '4'
        target = io.BytesIO()
        book.save(target)
        book.close()
        self.assertEqual(read_cash_workbook(upload(target.getvalue())), [list(HEADERS), ['Caisse complétée', '4']])


if __name__ == '__main__':
    unittest.main()
