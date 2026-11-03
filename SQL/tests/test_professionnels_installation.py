"""Seed lexical : PostgreSQL réel, données d'entreprise exclues du paquet neuf."""
import json
import os
from pathlib import Path
import re
import sys
import unittest
import uuid
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parents[2]
DSN = os.environ.get('SAUVERNDEKO_TEST_DATABASE_URL', '')
target = urlsplit(DSN)
if target.hostname not in {'localhost', '127.0.0.1'} or not target.path[1:].startswith('sauverndeko_test_'):
    raise RuntimeError('Base privée locale sauverndeko_test_* obligatoire.')
os.environ.update(DATABASE_URL=DSN, DJANGO_SETTINGS_MODULE='config.settings', SAUVERNDEKO_DB_READ_ONLY='0')
sys.path.insert(0, str(ROOT/'backend'))
import django
django.setup()
from django.db import DatabaseError, connection, transaction
from apps.core import db
from apps.core.management.commands.preparer_installation import professional_search_seed


class ProfessionalSearchInstallation(unittest.TestCase):
    def setUp(self):
        self.tx = transaction.atomic()
        self.tx.__enter__()
        self.assertTrue(db.one('SELECT current_database() n')['n'].startswith('sauverndeko_test_'))

    def tearDown(self):
        transaction.set_rollback(True)
        self.tx.__exit__(None, None, None)

    def test_private_terms_excluded_and_common_literals_restored_exactly(self):
        entity = db.one('INSERT INTO systeme."T_Entite"("NomEntite","EmailEntite","ValideEntite") '
                        'VALUES(%s,%s,true) RETURNING "IdEntite" id',
                        ['Fictif lexical '+uuid.uuid4().hex, uuid.uuid4().hex+'@example.invalid'])['id']
        category = db.one('SELECT "ID_CategorieDefautFk" id FROM referentiel."T_ChampReferentiel" '
                          'WHERE "SchemaName"=\'professionnel\' AND "TableName"=\'T_Professionnel_Competence\' '
                          'AND "ColumnName"=\'IdCompetenceFk\'')['id']
        values = []
        for owner in (None, entity):
            name = "Compétence d'essai " + uuid.uuid4().hex
            generic = db.one('INSERT INTO referentiel."T_Generique" '
                             '("ID_CategorieGeneriqueFk","NomGenerique","AbrGenerique","IdEntiteFk","ValideGenerique") '
                             'VALUES(%s,%s,%s,%s,true) RETURNING "ID_Generique" id', [category, name, name, owner])['id']
            term = "besoin d'essai " + uuid.uuid4().hex
            synonym = db.one('INSERT INTO professionnel."T_SynonymeRecherche" '
                             '("IdGeneriqueFk","Terme","IdEntiteFk") VALUES(%s,%s,%s) '
                             'RETURNING *', [generic, term, owner])
            values.append(synonym)
        command, count = professional_search_seed()
        payload = re.search(r"jsonb_populate_recordset\(NULL::professionnel\.\"T_SynonymeRecherche\",'((?:[^']|'')*)'::jsonb\)", command)
        self.assertIsNotNone(payload)
        rows = json.loads(payload[1].replace("''", "'"))
        self.assertEqual(count, len(rows))
        self.assertIn(values[0], rows)
        self.assertNotIn(values[1], rows)
        self.assertNotIn(values[1]['Terme'], command)
        self.assertTrue(all(row['IdEntiteFk'] is None for row in rows))
        with connection.cursor() as cursor:
            cursor.execute('DELETE FROM professionnel."T_SynonymeRecherche"')
            cursor.execute(command)
        restored = db.query('SELECT * FROM professionnel."T_SynonymeRecherche" ORDER BY "ID_SynonymeRecherche"')
        self.assertEqual(restored, rows)
        # Un second import refuse un dictionnaire non vide, sans insertion partielle.
        with self.assertRaises(DatabaseError), transaction.atomic():
            with connection.cursor() as cursor:
                cursor.execute(command)
        self.assertEqual(db.query('SELECT * FROM professionnel."T_SynonymeRecherche" ORDER BY "ID_SynonymeRecherche"'), rows)


if __name__ == '__main__':
    unittest.main(verbosity=2)
