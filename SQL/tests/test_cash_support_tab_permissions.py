"""Droits croisés Caisse et Support, sans connexion à une base applicative."""
import sys
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'backend'))

from django.conf import settings
if not settings.configured:
    settings.configure(
        SECRET_KEY='isolated-cash-support-access-tests',
        BASE_DIR=ROOT / 'backend',
        INSTALLED_APPS=[],
        DB_READ_ONLY=False,
    )
import django
django.setup()

from apps.caisse import services as cash
from apps.core.responses import APIError
from apps.support import portal as support


def rights(read=True, manage=False, export=False):
    return {'canRead': read, 'canManage': manage, 'canExport': export, 'reason': ''}


def actor(caisse=None, support=None, logistique=None):
    return SimpleNamespace(
        organisation=17,
        pk=29,
        admin=True,
        global_admin=False,
        _module_access={
            'modules': {key: rights(manage=True, export=True) for key in ('caisse', 'support', 'logistique')},
            'tabs': {'caisse': caisse or {}, 'support': support or {}, 'logistique': logistique or {}},
        },
    )


class CashSupportTabPermissions(unittest.TestCase):
    def test_cash_register_denies_direct_read_and_export_before_querying(self):
        user = actor(caisse={'caisses': rights(False), 'ecritures': rights()})
        with patch.object(cash.db, 'query') as query, patch.object(cash.db, 'one') as one:
            with self.assertRaises(APIError) as error:
                cash.detail(user, 'caisses', 1)
            self.assertEqual(error.exception.status_code, 403)
            with self.assertRaises(APIError) as error:
                cash.read_source(user, 'ecritures', {}, export=True)
            self.assertEqual(error.exception.status_code, 403)
            query.assert_not_called()
            one.assert_not_called()

    def test_cash_synthesis_exposes_only_balances_without_journal_read(self):
        user = actor(caisse={'tableau-de-bord': rights(), 'caisses': rights(), 'ecritures': rights(False)})
        balance = {'IdDeviseFk': 2, 'DeviseCode': 'USD', 'NombreCaisses': 2, 'Solde': 10}
        with patch.object(cash, 'read_source', return_value=(None, None, None, 'TRUE', [], None, {})) as source:
            with patch.object(cash.db, 'query', return_value=[balance]) as query:
                self.assertEqual(cash.synthesis(user, {}), {'totals': [balance], 'flux': []})
                source.assert_called_once_with(user, 'caisses', {'filters': {}})
                self.assertIn('V_Caisse', query.call_args.args[0])
                with self.assertRaises(APIError) as error:
                    cash.synthesis(user, {'filters': {'dateMin': '2026-11-01'}})
                self.assertEqual(error.exception.status_code, 403)

    def test_journal_hides_invoice_and_order_codes_in_derived_fields(self):
        user = actor(logistique={'tiers': rights(False), 'factures': rights(), 'commandes': rights(False),
                                 'reglements': rights(False)})
        linked = {'IdReglementFk': 9, 'CodeFactureFk': 'FAC-7', 'LibellePaiement': 'Règlement FAC-7',
                  'ReferenceExterne': 'BS-6', 'NomTiers': 'Client', 'IdTiersFk': 3}
        read = cash.public_record(user, 'ecritures', linked)
        exported = cash.public_record(user, 'ecritures', linked, 'export')
        self.assertEqual(read, {'CodeFactureFk': 'FAC-7', 'LibellePaiement': 'Règlement FAC-7',
                                'ReferenceExterne': None})
        self.assertEqual(exported, {'LibellePaiement': 'Règlement', 'ReferenceExterne': None})
        manual = {'ReferenceExterne': 'Caution', 'LibellePaiement': 'Versement'}
        self.assertEqual(cash.public_record(user, 'ecritures', manual, 'export'), manual)

        available = {name: {'data_type': 'text'} for name in ['LibellePaiement', 'ReferenceExterne']}
        with patch.object(cash, 'columns', return_value=available):
            _, _, _, predicate, _, order, _ = cash.read_source(
                user, 'ecritures', {'q': 'BS-6', 'sort': 'ReferenceExterne'},
            )
        self.assertIn('CASE WHEN v."IdReglementFk" IS NULL THEN v."ReferenceExterne" ELSE NULL END', predicate)
        self.assertIn('CASE WHEN v."IdReglementFk" IS NULL THEN v."ReferenceExterne" ELSE NULL END', order)

    def test_cash_closure_preparation_and_settlement_require_write_right(self):
        user = actor(caisse={'clotures': rights(), 'ecritures': rights()})
        with patch.object(cash, '_scoped_record') as read:
            with self.assertRaises(APIError) as error:
                cash.closure_preparation(user, 1)
            self.assertEqual(error.exception.status_code, 403)
            with self.assertRaises(APIError) as error:
                cash.record_reglement.__wrapped__(user, 1, {}, {}, '')
            self.assertEqual(error.exception.status_code, 403)
            read.assert_not_called()

    def test_support_read_permission_does_not_allow_download_or_edit(self):
        user = actor(support={'tickets': rights()})
        with patch.object(support, 'record') as record, patch.object(support.db, 'ensure_writable') as writable:
            with self.assertRaises(APIError) as error:
                support.document(user, 1, 2)
            self.assertEqual(error.exception.status_code, 403)
            with self.assertRaises(APIError) as error:
                support._write_access(user)
            self.assertEqual(error.exception.status_code, 403)
            record.assert_not_called()
            writable.assert_not_called()

    def test_support_related_order_filters_and_existing_links(self):
        user = actor(support={'tickets': rights(manage=True)}, logistique={'commandes': rights(False)})
        old = {'ID_CommandeFk': 5, 'Objet': 'Assistance', 'BonStock': 'BS-4', 'CodeCmd': 'BS-4',
               'VersionEnregistrement': 1}
        with patch.object(support.db, 'query') as query:
            with self.assertRaises(APIError) as error:
                support.selection(user, {'filters': {'ID_CommandeFk': 5}})
            self.assertEqual(error.exception.status_code, 403)
            query.assert_not_called()
        self.assertEqual(support.public_record(user, old),
                         {'Objet': 'Assistance', 'VersionEnregistrement': 1, '_version': '1'})
        with patch.object(support, 'require_entity', return_value=17):
            self.assertEqual(support.validate_fields(user, {'ID_CommandeFk': None}, old), {})
            with self.assertRaises(APIError) as error:
                support.validate_fields(user, {'ID_CommandeFk': 5}, old)
            self.assertEqual(error.exception.status_code, 403)


if __name__ == '__main__':
    unittest.main()
