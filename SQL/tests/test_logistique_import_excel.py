"""Recette de l’aperçu Excel des articles, sans écriture ni base de données."""
import io
import os
import sys
import unittest
import warnings
from datetime import date
from pathlib import Path
from unittest.mock import patch
from zipfile import ZIP_DEFLATED, ZipFile

import django
from openpyxl import Workbook

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'backend'))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import SimpleTestCase, override_settings
from rest_framework.test import APIClient

from apps.accounts.authentication import Actor
from apps.core.responses import APIError
from apps.logistique.article_xlsx import MAX_UPLOAD_BYTES, read_article_workbook


URL = '/api/logistique/saisie-multiple/articles/apercu-excel'


def workbook(rows, *, sheet_name='Articles', extra_sheet=True, styled_row=None, date_cells=()):
    book = Workbook()
    sheet = book.active
    sheet.title = sheet_name
    for row in rows:
        sheet.append(row)
    for coordinate in date_cells:
        sheet[coordinate].number_format = 'yyyy-mm-dd'
    if styled_row:
        sheet.cell(styled_row, 16_384).number_format = '0.00'
    if extra_sheet:
        example = book.create_sheet('Exemple')
        example.append(['=2+3', 'Cet exemple doit rester ignoré'])
        example['XFD2'] = 'Colonne hors du panier'
    binary = io.BytesIO()
    book.save(binary)
    return binary.getvalue()


def replace_sheet_xml(data, change):
    result = io.BytesIO()
    with ZipFile(io.BytesIO(data)) as source, ZipFile(result, 'w', ZIP_DEFLATED) as target:
        for name in source.namelist():
            part = source.read(name)
            target.writestr(name, change(part) if name == 'xl/worksheets/sheet1.xml' else part)
    return result.getvalue()


def upload(data, name='articles.xlsx'):
    return SimpleUploadedFile(name, data)


class ArticleExcelReaderTests(unittest.TestCase):
    def test_accepts_a_single_compatible_sheet_and_discards_only_row_numbers(self):
        headers = ['N°', 'Article', 'Catégorie', 'Type', 'Unité', 'Stock initial', 'Référence', 'N° de lot', 'Date de péremption']
        rows = [
            headers,
            [1, 'Produit A', 'Matériel', 'Exemple', 'Unité', 0, '00125', 243121690, date(2027, 1, 8)],
            [2],
            [3, 'Produit B', None, None, None, None, 44561, '00004'],
        ]
        expected = [
            headers[1:],
            ['Produit A', 'Matériel', 'Exemple', 'Unité', '0', '00125', '243121690', '2027-01-08'],
            ['Produit B', '', '', '', '', '44561', '00004'],
        ]
        for sheet_name in ('Articles', 'BASE DES DONNEES'):
            with self.subTest(sheet_name=sheet_name), warnings.catch_warnings():
                warnings.filterwarnings('ignore', message='Cell .* is marked as a date')
                data = workbook(rows, sheet_name=sheet_name, extra_sheet=False, date_cells=('H2', 'G4'))
                self.assertEqual(read_article_workbook(upload(data)), expected)

    def test_requires_a_recognizable_single_sheet_when_articles_is_missing(self):
        headers = ['Article', 'Catégorie', 'Type', 'Unité', 'Stock initial']
        for data in (
            workbook([headers, ['Produit A']], sheet_name='Inventaire'),
            workbook([['Article', 'Prix'], ['Produit A']], sheet_name='Inventaire', extra_sheet=False),
        ):
            with self.assertRaisesRegex(APIError, 'feuille Articles est introuvable'):
                read_article_workbook(upload(data))

    def test_reads_only_articles_with_exact_cell_positions_and_types(self):
        data = workbook([
            ['Article', None, 'Code interne', 'Actif', 'Stock initial', 'Prix d’achat', 'Péremption'],
            ['Produit A', None, '00125', False, 0, 1.25e-6, date(2027, 1, 8)],
            [],
            ['Produit B', None, '', True, 2.5, 3.5],
        ], styled_row=1800)
        self.assertEqual(read_article_workbook(upload(data)), [
            ['Article', '', 'Code interne', 'Actif', 'Stock initial', 'Prix d’achat', 'Péremption'],
            ['Produit A', '', '00125', 'FALSE', '0', '0.00000125', '2027-01-08'],
            ['Produit B', '', '', 'TRUE', '2.5', '3.5'],
        ])

    def test_accepts_600_records_and_rejects_the_next_one(self):
        rows = [['Article']] + [[f'Article {i}'] for i in range(600)]
        data = workbook(rows, styled_row=1500)
        self.assertEqual(len(read_article_workbook(upload(data))), 601)
        with self.assertRaisesRegex(APIError, '600 articles'):
            read_article_workbook(upload(workbook(rows + [['Article de trop']])))

    def test_reports_empty_or_missing_articles_even_with_example_data(self):
        with self.assertRaisesRegex(APIError, 'feuille Articles est vide'):
            read_article_workbook(upload(workbook([['Article']])))
        with self.assertRaisesRegex(APIError, 'feuille Articles est introuvable'):
            read_article_workbook(upload(workbook([['Article'], ['Vérification']], sheet_name='Inventaire')))
        with self.assertRaisesRegex(APIError, 'en-têtes sur la première ligne'):
            read_article_workbook(upload(workbook([[], ['Article']])))

    def test_rejects_formula_and_excel_error_with_cell_reference(self):
        for value, error in (('=2+3', 'une formule'), ('#REF!', 'une erreur Excel')):
            with self.subTest(value=value):
                with self.assertRaisesRegex(APIError, 'A2 contient ' + error):
                    read_article_workbook(upload(workbook([['Article'], [value]])))

    def test_declared_dimensions_cannot_hide_a_row_or_a_far_column(self):
        data = workbook([['Article'], ['Produit A']])
        changed = replace_sheet_xml(data, lambda part: part.replace(b'<dimension ref="A1:A2"', b'<dimension ref="A1"'))
        self.assertEqual(read_article_workbook(upload(changed)), [['Article'], ['Produit A']])
        wide = workbook([['Article'], ['Produit A'] + [None] * 63 + ['Trop loin']])
        with self.assertRaisesRegex(APIError, '64 colonnes'):
            read_article_workbook(upload(wide))

    def test_rejects_duplicate_coordinates_and_xml_document_types(self):
        data = workbook([['Article'], ['Produit A', 'B']])
        duplicate = replace_sheet_xml(data, lambda part: part.replace(b'r="B2"', b'r="A2"'))
        with self.assertRaisesRegex(APIError, 'classeur Excel est illisible'):
            read_article_workbook(upload(duplicate))
        dtd = replace_sheet_xml(data, lambda part: b'<!DOCTYPE worksheet>' + part)
        with self.assertRaisesRegex(APIError, 'classeur Excel est illisible'):
            read_article_workbook(upload(dtd))

    def test_rejects_size_zip_bombs_and_invalid_workbooks(self):
        with self.assertRaises(APIError) as error:
            read_article_workbook(upload(b'x' * (MAX_UPLOAD_BYTES + 1)))
        self.assertEqual(error.exception.status_code, 413)
        content = io.BytesIO()
        with ZipFile(content, 'w', ZIP_DEFLATED) as archive:
            archive.writestr('xl/worksheets/sheet1.xml', b'x' * (13 * 1024 * 1024))
        with self.assertRaisesRegex(APIError, 'contient trop de données'):
            read_article_workbook(upload(content.getvalue()))
        with self.assertRaisesRegex(APIError, 'classeur Excel est illisible'):
            read_article_workbook(upload(b'fichier invalide'))


@override_settings(ALLOWED_HOSTS=['testserver'])
class ArticleExcelPreviewAPITests(SimpleTestCase):
    def client_for(self, *, can_manage=True, admin=True):
        actor = Actor({'IdUser': 5, 'Is_Admin': False, 'Is_staff': admin, 'IdEntiteFk': 9})
        actor._module_access = {'modules': {'logistique': {
            'canRead': True, 'canManage': can_manage, 'reason': 'MODULE_ROLE_FORBIDDEN',
        }}}
        client = APIClient()
        client.force_authenticate(actor)
        return client

    def test_preview_checks_selected_entity_and_returns_the_cell_matrix(self):
        data = workbook([['Article'], ['Produit A']])
        with patch('apps.core.tenancy.db.one', return_value={'ValideEntite': True}) as entity:
            response = self.client_for().post(URL + '/', {'file': upload(data)}, format='multipart')
        self.assertEqual(response.status_code, 200, response.json())
        self.assertEqual(response.json()['data']['cells'], [['Article'], ['Produit A']])
        self.assertEqual(entity.call_args.args[1], [9])

    def test_preview_rejects_inactive_entity_and_module_without_manage_access(self):
        data = workbook([['Article'], ['Produit A']])
        with patch('apps.core.tenancy.db.one', return_value={'ValideEntite': False}):
            response = self.client_for().post(URL, {'file': upload(data)}, format='multipart')
        self.assertEqual(response.status_code, 409, response.json())
        self.assertEqual(response.json()['error']['code'], 'ENTITY_INACTIVE')
        with patch('apps.core.tenancy.db.one') as entity:
            response = self.client_for(can_manage=False).post(URL, {'file': upload(data)}, format='multipart')
            self.assertEqual(response.status_code, 403, response.json())
            response = self.client_for(admin=False).post(URL, {'file': upload(data)}, format='multipart')
            self.assertEqual(response.status_code, 403, response.json())
        entity.assert_not_called()

    def test_preview_refuses_non_file_and_oversized_envelope(self):
        with patch('apps.core.tenancy.db.one', return_value={'ValideEntite': True}):
            client = self.client_for()
            response = client.post(URL, {'file': 'produits.xlsx'}, format='multipart')
            self.assertEqual(response.status_code, 400, response.json())
            response = client.post(URL, {'file': upload(b'x' * (MAX_UPLOAD_BYTES + 128 * 1024))}, format='multipart')
            self.assertEqual(response.status_code, 413, response.json())


if __name__ == '__main__':
    unittest.main()
