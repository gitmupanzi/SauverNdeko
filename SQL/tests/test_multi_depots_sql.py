"""Contrats SQL multi-dépôts, lectures seulement sur copie locale explicite.

Les recettes d'opérations et de concurrence sont dans test_multi_depots_api.py.
Ce contrôle ne crée aucun compte, article, dépôt ni mouvement.
"""
import os
import unittest
from urllib.parse import urlsplit

import psycopg


class MultiDepotsSQL(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        dsn = os.environ.get('SAUVERNDEKO_TEST_DATABASE_URL') or os.environ.get('DATABASE_URL', '')
        target = urlsplit(dsn)
        if target.hostname not in {'localhost', '127.0.0.1'} or not target.path[1:].startswith('sauverndeko_test_'):
            raise unittest.SkipTest('Copie privée locale sauverndeko_test_* explicitement requise.')
        cls.connection = psycopg.connect(dsn)
        cls.connection.execute('SET TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY')
        actual = cls.connection.execute('SELECT current_database()').fetchone()[0]
        if actual != target.path[1:]:
            cls.connection.close()
            raise RuntimeError('La connexion ne correspond pas à la copie attendue.')

    @classmethod
    def tearDownClass(cls):
        cls.connection.rollback()
        cls.connection.close()

    def test_depot_historical_fields(self):
        for table in ['T_Commande', 'T_Mouvement', 'T_Inventaire']:
            result = self.connection.execute('''SELECT a.attnotnull,col_description(a.attrelid,a.attnum)
                FROM pg_attribute a WHERE a.attrelid=%s::regclass AND a.attname='ID_DepotFk' ''',
                ['logistique."' + table + '"']).fetchone()
            self.assertTrue(result and result[0] and result[1], table)

    def test_views_expose_depot(self):
        for view in ['V_Commande', 'V_CommandeDetail', 'V_Mouvement', 'V_MouvementStock', 'V_Inventaire']:
            self.assertEqual(self.connection.execute('''SELECT count(*) FROM pg_attribute
                WHERE attrelid=%s::regclass AND attname='ID_DepotFk' AND NOT attisdropped''',
                ['logistique."' + view + '"']).fetchone()[0], 1, view)

    def test_physical_conservation(self):
        self.assertEqual(self.connection.execute('''SELECT count(*) FROM logistique."T_Article" a
            WHERE a."QteArticle" IS DISTINCT FROM (SELECT coalesce(sum(s."StockPhysique"),0)
                FROM logistique."V_StockDepot" s WHERE s."ID_ArticleFk"=a."ID_Article")''').fetchone()[0], 0)
        self.assertEqual(self.connection.execute('''SELECT count(*) FROM logistique."V_StockDepot"
            WHERE "StockPhysique"<0 OR "StockPhysique"-"StockIndisponible"<"StockReserve" OR "StockSansLot"<0''').fetchone()[0], 0)
        self.assertEqual(self.connection.execute('''SELECT count(*) FROM logistique."V_StockLotDepot"
            WHERE "StockLot"<0''').fetchone()[0], 0)

    def test_state_catalogue_and_metadata(self):
        for code in ['TR_BROUILLON', 'TR_VALIDE', 'TR_TRANSIT', 'TR_PARTIEL', 'TR_TERMINE', 'TR_ANNULE']:
            self.assertIsNotNone(self.connection.execute('SELECT logistique.fn_etat_transfert(%s)', [code]).fetchone()[0], code)
        self.assertEqual(self.connection.execute('''SELECT count(*) FROM referentiel."T_ChampReferentiel"
            WHERE "SchemaName"='logistique' AND "TableName"='T_TransfertDepot'
            AND "ColumnName" IN('ID_EtatFk','ID_DeviseFk')''').fetchone()[0], 2)

    def test_local_expiry_preserves_global_quantities(self):
        self.assertEqual(self.connection.execute('''WITH locaux AS (
            SELECT "ID_Article",sum("StockPerime") AS perime,
              sum("StockProchePeremption") AS proche,sum("StockSansDatePeremption") AS sansdate
            FROM logistique."V_ArticlePeremptionDepot" GROUP BY "ID_Article")
            SELECT count(*) FROM logistique."V_ArticlePeremption" g JOIN locaux l USING("ID_Article")
            WHERE (g."StockPerime",g."StockProchePeremption",g."StockSansDatePeremption")
              IS DISTINCT FROM (l.perime,l.proche,l.sansdate)''').fetchone()[0], 0)

    def test_new_columns_commented(self):
        rows = self.connection.execute('''SELECT c.relname,a.attname FROM pg_class c
            JOIN pg_namespace n ON n.oid=c.relnamespace JOIN pg_attribute a ON a.attrelid=c.oid
            WHERE n.nspname='logistique' AND c.relname=ANY(%s) AND a.attnum>0 AND NOT a.attisdropped
            AND col_description(c.oid,a.attnum) IS NULL ORDER BY 1,2''', [[
                'T_Depot', 'T_TransfertDepot', 'T_TransfertDepotLigne', 'T_TransfertDepotAction',
                'V_Depot', 'V_StockDepot', 'V_StockLotDepot', 'V_TransfertDepot',
                'V_TransfertDepotLigne', 'V_StockTransit', 'V_ReservationLotDepot',
                'V_AuditStockDepot', 'V_ConsoMensuelleDepot', 'V_CouvertureStockDepot',
                'V_ArticlePeremptionDepot']]).fetchall()
        self.assertEqual(rows, [])

    def test_transfer_proofs_and_non_commercial_guards(self):
        names = {row[0] for row in self.connection.execute('''SELECT tgname FROM pg_trigger
            WHERE tgname=ANY(%s)''', [[
                'transfert_action_integrite', 'transfert_action_complete', 'transfert_bon_complet',
                'a00_facture_sans_transfert', 'a00_retour_sans_transfert', 'a00_inventaire_sans_transfert',
                'depot_stock_mouvement', 'depot_stock_lot', 'depot_stock_transfert', 'depot_desactivation']])}
        self.assertEqual(len(names), 10)


if __name__ == '__main__':
    unittest.main(verbosity=2)
