"""Publication d'offres : recette transactionnelle réservée à un clone privé."""
import os
from pathlib import Path
import unittest
from urllib.parse import urlsplit
import uuid

import psycopg
from psycopg import sql
from psycopg.rows import dict_row

DSN = os.environ.get('SAUVERNDEKO_TEST_DATABASE_URL', '')
location = urlsplit(DSN)
if location.hostname not in {'localhost', '127.0.0.1', '::1'} or not location.path.lstrip('/').startswith('sauverndeko_test_'):
    raise RuntimeError('Base privée sauverndeko_test_* obligatoire ; aucun repli source.')
MIGRATION = Path(__file__).resolve().parents[2] / 'backend/database/migrations/20261103_01_publication_articles.sql'


class PublicationSQL(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.c = psycopg.connect(DSN, autocommit=True, row_factory=dict_row)
        assert cls.c.execute('SELECT current_database() d').fetchone()['d'].startswith('sauverndeko_test_')

    @classmethod
    def tearDownClass(cls):
        cls.c.close()

    def setUp(self):
        self.tx = self.c.transaction(); self.tx.__enter__()
        self.entity = self.insert('systeme', 'T_Entite', {'NomEntite': 'Publication recette ' + uuid.uuid4().hex,
            'EmailEntite': uuid.uuid4().hex + '@example.invalid', 'ValideEntite': True}, 'IdEntite')
        self.user = self.insert('systeme', 'T_Utilisateurs', {'NomUser': 'Recette', 'PrenomUser': 'Publication',
            'EmailUser': uuid.uuid4().hex + '@example.invalid', 'MotdepasseUser': 'inutilisable',
            'PhoneUser': '+243000000000', 'ValideUser': True, 'IdEntiteFk': self.entity,
            'Is_Admin': False, 'SexeUser': 'M'}, 'IdUser')
        self.refs = {}
        for field in ['ID_TypeArticleFk', 'ID_CategorieArticleFk', 'ID_UniteFk', 'ID_DeviseFk']:
            row = self.c.execute('''SELECT g."ID_Generique" id FROM referentiel."T_Generique" g
                WHERE g."ValideGenerique" AND g."IdEntiteFk" IS NULL AND
                  g."ID_CategorieGeneriqueFk"=ANY(referentiel.fn_categories_champ('logistique','T_Article',%s,%s))
                ORDER BY g."ID_Generique" LIMIT 1''', [field, self.entity]).fetchone()
            self.assertIsNotNone(row, field)
            self.refs[field] = row['id']

    def tearDown(self):
        self.c.execute('ROLLBACK'); self.tx.__exit__(None, None, None)

    def insert(self, schema, table, values, key):
        statement = sql.SQL('INSERT INTO {}.{} ({}) VALUES ({}) RETURNING {} id').format(
            sql.Identifier(schema), sql.Identifier(table), sql.SQL(',').join(map(sql.Identifier, values)),
            sql.SQL(',').join(sql.Placeholder() for _ in values), sql.Identifier(key))
        return self.c.execute(statement, list(values.values())).fetchone()['id']

    def article(self, **extra):
        return self.insert('logistique', 'T_Article', {**self.refs, 'IdEntiteFk': self.entity,
            'ID_UserFK': self.user, 'NomArticle': 'Article recette publication', 'PUArticle': 1,
            'PVArticle': 2, 'QteArticle': 0, 'ValideArticle': True, **extra}, 'ID_Article')

    def set_default(self, value):
        self.c.execute('UPDATE systeme."T_Entite" SET "PartageArticlesPublicParDefaut"=%s WHERE "IdEntite"=%s', [value, self.entity])

    def visible(self, pk):
        return self.c.execute('SELECT "VisibleCatalogue" b FROM logistique."T_Article" WHERE "ID_Article"=%s', [pk]).fetchone()['b']

    def offer(self, pk):
        return self.c.execute('SELECT * FROM logistique."V_OffreArticle" WHERE "ID_Article"=%s', [pk]).fetchone()

    def update(self, pk, **values):
        statement = sql.SQL('UPDATE logistique."T_Article" SET {} WHERE "ID_Article"=%s').format(
            sql.SQL(',').join(sql.SQL('{}=%s').format(sql.Identifier(key)) for key in values))
        self.c.execute(statement, [*values.values(), pk])

    def test_01_enterprise_default_true_and_omitted_article_inherits(self):
        self.assertTrue(self.c.execute('SELECT "PartageArticlesPublicParDefaut" b FROM systeme."T_Entite" WHERE "IdEntite"=%s', [self.entity]).fetchone()['b'])
        self.assertTrue(self.visible(self.article()))

    def test_02_false_default_inherits(self):
        self.set_default(False)
        pk = self.article()
        self.assertFalse(self.visible(pk)); self.assertIsNone(self.offer(pk))

    def test_03_explicit_false_overrides_true(self):
        self.assertFalse(self.visible(self.article(VisibleCatalogue=False)))

    def test_04_explicit_true_overrides_false(self):
        self.set_default(False)
        pk = self.article(VisibleCatalogue=True)
        self.assertTrue(self.visible(pk)); self.assertIsNotNone(self.offer(pk))

    def test_05_changed_default_does_not_rewrite_or_filter_existing(self):
        published = self.article(); hidden = self.article(VisibleCatalogue=False)
        self.set_default(False)
        self.assertTrue(self.visible(published)); self.assertIsNotNone(self.offer(published))
        self.assertFalse(self.visible(hidden)); self.assertIsNone(self.offer(hidden))
        self.assertFalse(self.visible(self.article()))
        self.set_default(True)
        self.assertFalse(self.visible(hidden))

    def test_06_null_insert_uses_owner_default_but_null_update_rejected(self):
        self.set_default(False)
        pk = self.article(VisibleCatalogue=None)
        self.assertFalse(self.visible(pk))
        with self.assertRaises(psycopg.errors.NotNullViolation):
            with self.c.transaction(): self.update(pk, VisibleCatalogue=None)

    def test_07_active_owner_and_article_required(self):
        pk = self.article()
        self.assertIsNotNone(self.offer(pk))
        self.update(pk, ValideArticle=False)
        self.assertIsNone(self.offer(pk))
        self.update(pk, ValideArticle=True)
        self.c.execute('UPDATE systeme."T_Entite" SET "ValideEntite"=false WHERE "IdEntite"=%s', [self.entity])
        self.assertIsNone(self.offer(pk))

    def test_08_projection_is_a_whitelist_and_not_purchase_price_or_notes(self):
        pk = self.article(ObsArticle='NOTE INTERNE', InformationArticle='INFORMATION PRIVEE')
        offer = self.offer(pk)
        expected = {'ID_Article','NomArticle','RefArticle','PVArticle','ID_DeviseFk','DeviseCode','DeviseLibelle','Unite','EtatDisponibilite','PhotoArticle','IdEntite','NomEntite','AdresseEntite','PhoneEntite'}
        self.assertEqual(set(offer), expected)
        self.assertNotIn('NOTE INTERNE', str(offer)); self.assertNotIn('INFORMATION PRIVEE', str(offer))

    def test_09_publication_changes_do_not_create_movements(self):
        pk = self.article(QteArticle=5)
        before = self.c.execute('SELECT "QteArticle","PUArticle","PVArticle" FROM logistique."T_Article" WHERE "ID_Article"=%s', [pk]).fetchone()
        count = self.c.execute('SELECT count(*) n FROM logistique."T_Mouvement" WHERE "ID_ArticleFk"=%s', [pk]).fetchone()['n']
        self.assertEqual(count, 1)
        self.update(pk, VisibleCatalogue=False); self.update(pk, VisibleCatalogue=True)
        self.assertEqual(before, self.c.execute('SELECT "QteArticle","PUArticle","PVArticle" FROM logistique."T_Article" WHERE "ID_Article"=%s', [pk]).fetchone())
        self.assertEqual(count, self.c.execute('SELECT count(*) n FROM logistique."T_Mouvement" WHERE "ID_ArticleFk"=%s', [pk]).fetchone()['n'])

    def test_10_stock_label_does_not_claim_verified_availability(self):
        self.assertEqual(self.offer(self.article())['EtatDisponibilite'], 'Stock nul déclaré')
        self.assertEqual(self.offer(self.article(QteArticle=1))['EtatDisponibilite'], 'Stock déclaré')

    def test_11_management_view_preserves_order_and_appends_visibility(self):
        columns = self.c.execute("SELECT column_name FROM information_schema.columns WHERE table_schema='logistique' AND table_name='V_Article' ORDER BY ordinal_position").fetchall()
        self.assertEqual(columns[-1]['column_name'], 'VisibleCatalogue')
        pk = self.article(VisibleCatalogue=False)
        self.assertFalse(self.c.execute('SELECT "VisibleCatalogue" b FROM logistique."V_Article" WHERE "ID_Article"=%s', [pk]).fetchone()['b'])


class MigrationReplaySQL(unittest.TestCase):
    def test_12_replay_preserves_decisions_stock_and_nonpublication_triggers(self):
        with psycopg.connect(DSN, autocommit=True, row_factory=dict_row) as c:
            before = c.execute('SELECT "ID_Article","QteArticle","PUArticle","PVArticle","VisibleCatalogue" FROM logistique."T_Article" ORDER BY 1').fetchall()
            triggers = c.execute("SELECT tgname,pg_get_triggerdef(oid) d FROM pg_trigger WHERE tgrelid='logistique.\"T_Article\"'::regclass AND NOT tgisinternal AND tgname<>'ab_publication_article' ORDER BY tgname").fetchall()
            c.execute(MIGRATION.read_text(encoding='utf8'))
            self.assertEqual(before, c.execute('SELECT "ID_Article","QteArticle","PUArticle","PVArticle","VisibleCatalogue" FROM logistique."T_Article" ORDER BY 1').fetchall())
            self.assertEqual(triggers, c.execute("SELECT tgname,pg_get_triggerdef(oid) d FROM pg_trigger WHERE tgrelid='logistique.\"T_Article\"'::regclass AND NOT tgisinternal AND tgname<>'ab_publication_article' ORDER BY tgname").fetchall())


if __name__ == '__main__':
    unittest.main(verbosity=2)
