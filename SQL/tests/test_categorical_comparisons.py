"""Catégories métier et panier de bon, sans connexion à PostgreSQL."""
import sys
import unittest
from contextlib import nullcontext
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch
from uuid import UUID

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'backend'))

from django.conf import settings

if not settings.configured:
    settings.configure(
        SECRET_KEY='categorical-comparisons-tests',
        BASE_DIR=ROOT / 'backend',
        DATABASES={'default': {'ENGINE': 'django.db.backends.dummy'}},
        INSTALLED_APPS=[],
        TIME_ZONE='Africa/Kinshasa',
    )

import django

django.setup()

from apps.core.category_values import category_key
from apps.core.responses import APIError
from apps.logistique import lots, order_composer, order_types, receipts, services
from apps.support import process_workbooks


class CategoryComparisonTests(unittest.TestCase):
    def test_preserves_accent_distinctions_and_original(self):
        original = '  ENTRE\u0301E  en STOCK  '
        self.assertEqual(category_key(original), 'entrée  en stock')
        self.assertEqual(original, '  ENTRE\u0301E  en STOCK  ')
        self.assertEqual(category_key('  ENTRE\u0301E  '), category_key('Entrée'))
        self.assertNotEqual(category_key('Entrée'), category_key('Entree'))
        self.assertNotEqual(category_key('Straße'), category_key('Strasse'))
        self.assertEqual(category_key(None), '')

    def test_order_type_preserves_returned_kind_and_stock_sign(self):
        for kind in ('Sortie', 'sortie', 'SORTIE'):
            with self.subTest(kind=kind), patch.object(order_types.db, 'one', return_value={'kind': kind, 'effect': -1}):
                result = order_types.type_context(17)
                self.assertEqual(result, {'kind': kind, 'stockEffect': -1, 'sign': -1, 'canInvoice': True})
        with patch.object(order_types.db, 'one', return_value={'kind': 'INCONNU', 'effect': None}):
            with self.assertRaises(APIError) as error:
                order_types.type_context(17)
            self.assertEqual(error.exception.default_code, 'ORDER_TYPE_UNSUPPORTED')

    def test_outgoing_stock_type_uses_the_same_comparison(self):
        for kind in ('Sortie', 'sortie', 'SORTIE', 'Entrée', None):
            with self.subTest(kind=kind), patch.object(lots.db, 'one', return_value={'kind': kind}):
                self.assertEqual(lots.outgoing_type(17), kind in ('Sortie', 'sortie', 'SORTIE'))

    def test_receipt_filters_by_kind_and_preserves_display_label(self):
        rows = [
            {'id': 17, 'kind': 'EnTrEe', 'label': 'ENTRÉE', 'abbr': 'BE'},
            {'id': 18, 'kind': 'SORTIE', 'label': 'Sortie', 'abbr': 'BS'},
        ]
        with patch('apps.core.field_references.reference_options', return_value=rows):
            self.assertEqual(receipts.entry_type(), {'id': 17, 'label': 'ENTRÉE'})

    def test_ambiguous_receipt_requires_selecting_an_id(self):
        rows = [
            {'id': 17, 'label': 'Entrée', 'abbreviation': 'BE'},
            {'id': 18, 'label': 'ENTRÉE', 'abbreviation': 'BE2'},
        ]
        with patch.object(receipts, 'entry_types', return_value=rows):
            with self.assertRaises(APIError) as error:
                receipts.entry_type()
            self.assertIn('ID_TypeCmdFk', error.exception.detail)
            self.assertEqual(receipts.entry_type(18), {'id': 18, 'label': 'ENTRÉE'})

    def test_workbook_uses_category_ids_and_reports_ambiguous_labels(self):
        lookup = process_workbooks.option_lookup({'reasons': [
            {'id': 17, 'label': 'Fermé'},
            {'id': 18, 'label': 'FERMÉ'},
            {'id': 19, 'label': 'Ferme'},
            {'id': 20, 'label': 'Archivé', 'disabled': True},
        ]})
        resolve = process_workbooks.workbook_value
        self.assertEqual(resolve('17', 'reasons', lookup), 17)
        self.assertEqual(resolve('FERME', 'reasons', lookup), 19)
        self.assertIs(resolve('Oui', 'bool', lookup), True)
        with self.assertRaisesRegex(ValueError, 'ambigu'):
            resolve('fermé', 'reasons', lookup)
        with self.assertRaisesRegex(ValueError, 'valeur active'):
            resolve('ARCHIVÉ', 'reasons', lookup)


class StockDocumentCategoryTests(unittest.TestCase):
    @staticmethod
    def column(name, data_type):
        return {
            'column_name': name, 'data_type': data_type, 'is_nullable': 'NO',
            'numeric_scale': 3, 'numeric_precision': 15,
        }

    def setUp(self):
        self.actor = SimpleNamespace(pk=10)
        self.models = {
            'T_Commande': {'columns': [
                self.column('ID_TypeCmdFk', 'integer'),
                self.column('ID_DeviseFk', 'integer'),
                self.column('DateCmd', 'timestamp without time zone'),
            ]},
            'T_CommandeDetail': {'columns': [
                self.column('ID_ArticleFk', 'integer'),
                self.column('QteCmdDetail', 'numeric'),
                self.column('PUCmdDetail', 'numeric'),
            ]},
        }
        self.body = {
            'requestId': str(UUID(int=1)),
            'bon': {'ID_TypeCmdFk': 17, 'ID_DeviseFk': 451, 'DateCmd': '2026-01-01T15:00'},
            'lignes': [{
                'ID_ArticleFk': 91, 'QteCmdDetail': '2', 'PUCmdDetail': '15',
                'Lots': [{'NumeroLot': 'Lot-A', 'Quantite': '1'}],
            }],
        }
        self.enterContext(patch.object(order_composer, 'model', side_effect=self.models.__getitem__))
        self.enterContext(patch('apps.core.tenancy.require_entity', return_value=9))

    def compose(self, kind):
        with patch.object(order_composer, 'type_context', return_value={'kind': kind}):
            return order_composer.composition_data(self.actor, self.body)

    def test_outgoing_allows_partial_lot_with_any_case(self):
        expected = self.compose('sortie')
        self.assertEqual(self.compose('Sortie'), expected)
        self.assertEqual(self.compose('SORTIE'), expected)
        self.assertEqual(expected['lignes'][0]['data']['Lots'][0]['NumeroLot'], 'Lot-A')

    def test_purchase_order_never_reserves_lots(self):
        with self.assertRaises(APIError) as error:
            self.compose('COMMANDE')
        self.assertEqual(error.exception.default_code, 'ORDER_LOTS_FORBIDDEN')

    def test_individual_line_cannot_allocate_lots_to_a_preparatory_order(self):
        with (
            patch.object(services.db, 'ensure_writable'),
            patch.object(services.transaction, 'atomic', side_effect=nullcontext),
            patch.object(services, 'model', side_effect=self.models.__getitem__),
            patch.object(services, 'get_record', return_value={'ID_TypeCmdFk': 17}),
            patch('apps.core.tenancy.assert_document'),
            patch.object(order_types, 'type_context', return_value={'kind': 'Commande'}),
        ):
            with self.assertRaises(APIError) as error:
                services.mutate_line(self.actor, 5, self.body['lignes'][0])
        self.assertEqual(error.exception.default_code, 'ORDER_LOTS_FORBIDDEN')

    def test_incoming_still_rejects_incomplete_lot_allocation(self):
        with self.assertRaises(APIError) as error:
            self.compose('EnTrEe')
        self.assertEqual(error.exception.default_code, 'LOT_QUANTITY_MISMATCH')


if __name__ == '__main__':
    unittest.main()
