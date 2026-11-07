"""Droits des preuves de transfert, sur copie locale avec rôle HTTP déjà préparé.

Ce test ne crée ni rôle, ni donnée. Les UPDATE/DELETE sont limités à WHERE false
et doivent être refusés par PostgreSQL avant tout déclenchement métier.
"""
import os
import unittest
from urllib.parse import urlsplit

import psycopg


class MultiDepotsRuntime(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        dsn = os.environ.get('SAUVERNDEKO_TEST_DATABASE_URL') or os.environ.get('DATABASE_URL', '')
        target = urlsplit(dsn)
        if target.hostname not in {'localhost', '127.0.0.1'} or not target.path[1:].startswith('sauverndeko_test_'):
            raise unittest.SkipTest('Copie privée locale sauverndeko_test_* explicitement requise.')
        cls.connection = psycopg.connect(dsn, autocommit=True)
        if cls.connection.execute('SELECT current_database()').fetchone()[0] != target.path[1:]:
            cls.connection.close()
            raise RuntimeError('La connexion ne correspond pas à la copie attendue.')
        if not cls.connection.execute("SELECT EXISTS(SELECT FROM pg_roles WHERE rolname='sauverndeko_runtime')").fetchone()[0]:
            cls.connection.close()
            raise unittest.SkipTest('Le rôle HTTP doit être préparé sur cette copie avant la recette.')
        cls.connection.execute('SET ROLE sauverndeko_runtime')

    @classmethod
    def tearDownClass(cls):
        cls.connection.execute('RESET ROLE')
        cls.connection.close()

    def test_select_and_insert_granted(self):
        self.assertEqual(self.connection.execute('SELECT current_user').fetchone()[0], 'sauverndeko_runtime')
        self.connection.execute('SELECT * FROM logistique."T_TransfertDepotAction" LIMIT 0')
        self.assertEqual(self.connection.execute('''SELECT
            has_table_privilege(current_user,'logistique."T_TransfertDepotAction"','SELECT'),
            has_table_privilege(current_user,'logistique."T_TransfertDepotAction"','INSERT')''').fetchone(), (True, True))

    def test_update_refused(self):
        with self.assertRaises(psycopg.errors.InsufficientPrivilege):
            self.connection.execute('UPDATE logistique."T_TransfertDepotAction" SET "Motif"=\'inaccessible\' WHERE false')

    def test_delete_refused(self):
        with self.assertRaises(psycopg.errors.InsufficientPrivilege):
            self.connection.execute('DELETE FROM logistique."T_TransfertDepotAction" WHERE false')


if __name__ == '__main__':
    unittest.main(verbosity=2)
