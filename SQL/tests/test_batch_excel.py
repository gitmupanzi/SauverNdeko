"""Contrat commun XLSX : tests en mémoire, aucune connexion PostgreSQL."""
import io
import os
import sys
from datetime import datetime
from pathlib import Path
from types import SimpleNamespace
from zipfile import ZIP_DEFLATED, ZipFile

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'backend'))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
import django
django.setup()

from django.core.files.uploadedfile import SimpleUploadedFile
from django.http import QueryDict
from django.test import SimpleTestCase
from django.utils.datastructures import MultiValueDict
from openpyxl import Workbook, load_workbook
from apps.core.batch_excel import MAX_UPLOAD_BYTES, build_template, read_uploaded_workbook, read_workbook
from apps.core.responses import APIError


HEADERS = {'Nom': 'Nom', 'État': 'Actif', 'Identifiant': 'ID_Parent', 'Date et heure': 'DateEntree'}


def workbook(rows, *, title='Saisie', extra=False):
    book = Workbook()
    sheet = book.active
    sheet.title = title
    for row in rows:
        sheet.append(row)
    if extra:
        book.create_sheet('Informations').append(['=1+2'])
    target = io.BytesIO()
    book.save(target)
    book.close()
    return target.getvalue()


def read(binary, name='saisie.xlsx', **kwargs):
    return read_workbook(SimpleUploadedFile(name, binary), sheet_name='Saisie', headers=HEADERS,
                         required_headers=('Nom',), max_rows=100, **kwargs)


class BatchExcelTests(SimpleTestCase):
    def test_headers_are_canonical_and_blank_positions_kept(self):
        self.assertEqual(read(workbook([['Nom', 'État', 'Identifiant'], ['001 A', False, '0002'],
                                       [], ['B', None, '0003']])),
                         [['Nom', 'Actif', 'ID_Parent'], ['001 A', 'FALSE', '0002'], ['B', '', '0003']])

    def test_physical_headers_single_sheet_and_accents(self):
        self.assertEqual(read(workbook([['Nom', 'Actif'], ['A', True]], title='Données')),
                         [['Nom', 'Actif'], ['A', 'TRUE']])

    def test_date_and_time_are_preserved(self):
        self.assertEqual(read(workbook([['Nom', 'Date et heure'], ['A', datetime(2026, 11, 7, 14, 5, 3)]]))[1][1],
                         '2026-11-07T14:05:03')

    def test_identifier_styled_as_date_remains_identifier(self):
        book = load_workbook(io.BytesIO(workbook([['Nom', 'Identifiant'], ['A', 46000]])))
        book.active['B2'].number_format = 'yyyy-mm-dd'
        target = io.BytesIO(); book.save(target); book.close()
        self.assertEqual(read(target.getvalue())[1][1], '46000')

    def test_limit_is_on_nonempty_rows_without_truncation(self):
        rows = [['Nom']] + [[f'A{i}'] for i in range(100)]
        self.assertEqual(len(read(workbook(rows))), 101)
        with self.assertRaisesRegex(APIError, '100 lignes'):
            read(workbook(rows + [['A101']]))

    def test_unknown_duplicate_missing_and_blank_headers_rejected(self):
        for rows in ([['Autre'], ['A']], [['Nom', 'État', 'Actif'], ['A', True, True]],
                     [['État'], [True]], [[], ['Nom'], ['A']], [['Nom'], ['A', 'sans en-tête']]):
            with self.subTest(rows=rows), self.assertRaises(APIError):
                read(workbook(rows))

    def test_empty_template_rejected(self):
        with self.assertRaisesRegex(APIError, 'est vide'):
            read(workbook([['Nom'], [], []]))

    def test_formula_and_excel_error_rejected(self):
        for value in ('=1+2', '#DIV/0!'):
            with self.subTest(value=value), self.assertRaises(APIError):
                read(workbook([['Nom'], [value]]))

    def test_unselected_information_formula_does_not_enter_basket(self):
        self.assertEqual(read(workbook([['Nom'], ['A']], extra=True)), [['Nom'], ['A']])
        with self.assertRaisesRegex(APIError, 'introuvable'):
            read(workbook([['Nom'], ['A']], title='Autre', extra=True))

    def test_long_cells_and_non_xlsx_rejected(self):
        with self.assertRaisesRegex(APIError, '10000'):
            read(workbook([['Nom'], ['A' * 10001]]))
        for binary, filename in ((b'no zip', 'a.xlsx'), (b'123', 'a.xls'), (b'', 'a.xlsx')):
            with self.subTest(filename=filename), self.assertRaises(APIError):
                read(binary, filename)

    def test_declared_dimensions_cannot_hide_extra_values(self):
        binary = workbook([['Nom'], ['A'], ['B']])
        target = io.BytesIO()
        with ZipFile(io.BytesIO(binary)) as source, ZipFile(target, 'w', ZIP_DEFLATED) as output:
            for name in source.namelist():
                data = source.read(name)
                if name == 'xl/worksheets/sheet1.xml':
                    data = data.replace(b'<dimension ref="A1:A3"', b'<dimension ref="A1"')
                output.writestr(name, data)
        self.assertEqual(len(read(target.getvalue())), 3)

    def test_cells_past_column_limit_rejected(self):
        with self.assertRaises(APIError):
            read(workbook([['Nom'], ['A'] + [None] * 63 + ['caché']]))

    def test_template_layout_and_literal_options(self):
        stream = build_template(sheet_name='Saisie', columns=[
            {'key': 'Nom', 'label': 'Nom'},
            {'key': 'ID_Parent', 'label': 'Identifiant', 'choices': [{'value': '0002', 'label': '=texte'}]},
        ], notes=[('Parent', 'Choisir dans le formulaire')])
        book = load_workbook(stream)
        self.addCleanup(book.close)
        sheet = book['Saisie']
        self.assertEqual([cell.value for cell in sheet[1]], ['Nom', 'Identifiant'])
        self.assertEqual(sheet.freeze_panes, 'A2')
        self.assertEqual(sheet.auto_filter.ref, 'A1:B101')
        self.assertEqual(sheet['A2'].number_format, '@')
        self.assertEqual(sheet['A1'].fill.fgColor.rgb[-6:], 'F3F4F6')
        self.assertEqual(book['Options']['A2'].value, '0002')
        self.assertEqual(book['Options']['B2'].data_type, 's')
        self.assertEqual(len(sheet.data_validations.dataValidation), 1)
        self.assertTrue(all(cell.value is None for row in sheet.iter_rows(min_row=2) for cell in row))
        sheet['A2'] = 'A'; sheet['B2'] = '0002'
        target = io.BytesIO(); book.save(target)
        self.assertEqual(read(target.getvalue()), [['Nom', 'ID_Parent'], ['A', '0002']])

    def test_multipart_accepts_exact_file_and_explicit_header_metadata_only(self):
        upload = SimpleUploadedFile('a.xlsx', workbook([['Nom'], ['A']]))
        data = QueryDict('', mutable=True); data['scope'] = 'entity'; data['fichier'] = upload
        request = SimpleNamespace(META={}, data=data, FILES=MultiValueDict({'fichier': [upload]}))
        self.assertEqual(read_uploaded_workbook(request, allowed_fields=('scope',), sheet_name='Saisie',
                         headers=HEADERS, required_headers=('Nom',)), [['Nom'], ['A']])
        with self.assertRaises(APIError):
            read_uploaded_workbook(request, sheet_name='Saisie', headers=HEADERS)
        data.setlist('scope', ['entity', 'global'])
        with self.assertRaises(APIError):
            read_uploaded_workbook(request, allowed_fields=('scope',), sheet_name='Saisie', headers=HEADERS)

    def test_multipart_rejects_multiple_files_and_oversized_body(self):
        upload = SimpleUploadedFile('a.xlsx', workbook([['Nom'], ['A']]))
        request = SimpleNamespace(META={}, data={'fichier': upload}, FILES=MultiValueDict({'fichier': [upload, upload]}))
        with self.assertRaises(APIError):
            read_uploaded_workbook(request, sheet_name='Saisie', headers=HEADERS)
        request.META['CONTENT_LENGTH'] = str(MAX_UPLOAD_BYTES + 65537)
        with self.assertRaises(APIError) as caught:
            read_uploaded_workbook(request, sheet_name='Saisie', headers=HEADERS)
        self.assertEqual(caught.exception.status_code, 413)


if __name__ == '__main__':
    import unittest
    unittest.main()
