"""Recette réelle des références et saisies atomiques en PostgreSQL privé.

Aucune route d'écriture de cette recette ne doit viser SauverNdeko. Les noms,
comptes et entreprises sont créés exclusivement dans une base locale de test.
"""
import csv
import io
import json
import os
import sys
import unittest
import uuid
from pathlib import Path
from unittest.mock import patch
from urllib.parse import urlsplit

import psycopg
from psycopg.rows import dict_row

ROOT = Path(__file__).resolve().parents[2]
DSN = os.environ.get('SAUVERNDEKO_TEST_DATABASE_URL', '')
location = urlsplit(DSN)
if location.hostname not in {'localhost', '127.0.0.1', '::1'} or not location.path[1:].startswith('sauverndeko_test_'):
    raise RuntimeError('Base PostgreSQL privée locale sauverndeko_test_* obligatoire.')
with psycopg.connect(DSN) as check:
    if not check.execute('SELECT current_database()').fetchone()[0].startswith('sauverndeko_test_'):
        raise RuntimeError('Base privée requise.')
os.environ.update(DATABASE_URL=DSN, DJANGO_SETTINGS_MODULE='config.settings', SAUVERNDEKO_DB_READ_ONLY='0')
sys.path.insert(0, str(ROOT / 'backend'))
import django
django.setup()
from django.db import transaction
from django.test import override_settings
from rest_framework.test import APIClient
from apps.accounts.authentication import Actor
from apps.core import db
from apps.core.module_access import MODULE_BY_KEY
from apps.core.responses import APIError

BASE = '/api/referentiel/saisie-multiple/'


class ReferentialAPI(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.settings = override_settings(ALLOWED_HOSTS=['testserver'])
        cls.settings.enable()
        cls.sql = psycopg.connect(DSN, autocommit=True, row_factory=dict_row)
        cls.tag = uuid.uuid4().hex[:12]
        cls.entities = [cls.sql.execute('INSERT INTO systeme."T_Entite"("NomEntite","EmailEntite","ValideEntite") '
            'VALUES(%s,%s,true) RETURNING "IdEntite" id', [f'Recette références {cls.tag}-{i}', f'{cls.tag}-{i}@example.invalid']).fetchone()['id'] for i in range(2)]
        cls.users = [cls.sql.execute('INSERT INTO systeme."T_Utilisateurs" '
            '("NomUser","PrenomUser","EmailUser","MotdepasseUser","ValideUser","SexeUser","Is_Admin","Is_staff","IdEntiteFk") '
            'VALUES(\'Fictif\',\'Référence\',%s,\'inutilisable\',true,\'M\',true,true,%s) RETURNING *',
            [f'{cls.tag}-user-{i}@example.invalid', owner]).fetchone() for i, owner in enumerate(cls.entities)]
        cls.categories = [cls.sql.execute('INSERT INTO referentiel."T_CategorieGenerique" '
            '("NomCategorieGenerique","ModuleCategorieGenerique","ValideCategorieGenerique","IdEntiteFk") '
            'VALUES(%s,\'RECETTE\',true,%s) RETURNING "ID_CategorieGenerique" id',
            [f'Famille recette {cls.tag}-{i}', owner]).fetchone()['id'] for i, owner in enumerate([None, *cls.entities])]
        cls.shared_value = cls.sql.execute('INSERT INTO referentiel."T_Generique" '
            '("ID_CategorieGeneriqueFk","NomGenerique","AbrGenerique") VALUES(%s,%s,%s) RETURNING "ID_Generique" id',
            [cls.categories[0], f'Commun {cls.tag}', f'C-{cls.tag}']).fetchone()['id']
        cls.private_values = [cls.sql.execute('INSERT INTO referentiel."T_Generique" '
            '("ID_CategorieGeneriqueFk","NomGenerique","AbrGenerique","IdEntiteFk") VALUES(%s,%s,%s,%s) RETURNING "ID_Generique" id',
            [cls.categories[0], f'Privé {cls.tag}-{i}', f'P-{cls.tag}-{i}', owner]).fetchone()['id'] for i, owner in enumerate(cls.entities)]
        cls.article_category_field = cls.sql.execute('SELECT "ID_ChampReferentiel" id FROM referentiel."T_ChampReferentiel" '
            'WHERE "SchemaName"=\'logistique\' AND "TableName"=\'T_Article\' AND "ColumnName"=\'ID_CategorieArticleFk\'').fetchone()['id']

    @classmethod
    def tearDownClass(cls):
        cls.sql.close(); cls.settings.disable()

    def setUp(self):
        self.tx = transaction.atomic(); self.tx.__enter__()

    def tearDown(self):
        transaction.set_rollback(True); self.tx.__exit__(None, None, None)

    def actor(self, index=0, *, global_admin=True, admin=True, read=True, manage=True):
        actor = Actor({**self.users[index], 'Is_Admin': global_admin, 'Is_staff': admin})
        actor._context_entity = self.entities[index]
        actor._module_access = {'modules': {key: {'canRead': read, 'canManage': manage,
            'canExport': read, 'reason': '' if read else 'MODULE_ROLE_FORBIDDEN'} for key in MODULE_BY_KEY}}
        return actor

    def client(self, **kwargs):
        client = APIClient(); client.force_authenticate(self.actor(**kwargs)); return client

    def batch(self, kind='valeurs', rows=None, **extra):
        return {'requestId': str(uuid.uuid4()), 'scope': 'global',
            **({'categoryId': self.categories[0]} if kind == 'valeurs' else {}),
            'rows': rows if rows is not None else [{'clientRowId': 'ligne-1', 'NomGenerique': 'Valeur ' + uuid.uuid4().hex,
                              'AbrGenerique': 'N-' + uuid.uuid4().hex[:12]}], **extra}

    def category_row(self, name=None, row_id='ligne-1'):
        return {'clientRowId': row_id, 'NomCategorieGenerique': name or 'Famille ' + uuid.uuid4().hex,
                'ModuleCategorieGenerique': 'RECETTE', 'ValideCategorieGenerique': True}

    def post(self, body=None, kind='valeurs', **actor):
        return self.client(**actor).post(BASE + kind, body or self.batch(kind), format='json')

    def test_01_categories_batch_real_ids(self):
        rows = [self.category_row(row_id=f'c-{i}') for i in range(3)]
        response = self.post(self.batch('categories', rows), 'categories')
        self.assertEqual(response.status_code, 201, response.data)
        records = response.data['data']['records']; self.assertEqual(len(records), 3)
        self.assertEqual([r['clientRowId'] for r in records], ['c-0', 'c-1', 'c-2'])
        self.assertEqual(len({r['ID_CategorieGenerique'] for r in records}), 3)
        self.assertTrue(all(r['IdEntiteFk'] is None for r in records))

    def test_02_values_header_shared_and_flags(self):
        body = self.batch(rows=[{'clientRowId': f'v-{i}', 'NomGenerique': f'Libellé {uuid.uuid4().hex}',
            'AbrGenerique': f'CODE-{uuid.uuid4().hex}', 'VisibleArticle': False, 'VisibleNiveau_2': None} for i in range(2)])
        response = self.post(body); self.assertEqual(response.status_code, 201, response.data)
        for row in response.data['data']['records']:
            self.assertEqual(row['ID_CategorieGeneriqueFk'], self.categories[0])
            self.assertIs(row['VisibleArticle'], False); self.assertIsNone(row['VisibleNiveau_2'])

    def test_03_replay_and_changed_payload(self):
        body = self.batch(); first = self.post(body); second = self.post(body)
        self.assertEqual(first.status_code, 201, first.data); self.assertEqual(second.status_code, 200, second.data)
        self.assertTrue(second.data['meta']['replayed']); self.assertEqual(first.data['data'], second.data['data'])
        body['rows'][0]['NomGenerique'] += ' changé'
        changed = self.post(body); self.assertEqual(changed.status_code, 409)

    def test_04_error_preserves_all_database_rows(self):
        prefix = 'Panier valide ' + uuid.uuid4().hex
        rows = [{'clientRowId': 'ok', 'NomGenerique': prefix}, {'clientRowId': 'corriger', 'NomGenerique': ''}]
        response = self.post(self.batch(rows=rows)); self.assertEqual(response.status_code, 422, response.data)
        self.assertIn('NomGenerique', response.data['error']['details']['rows']['corriger'])
        self.assertEqual(db.one('SELECT count(*) n FROM referentiel."T_Generique" WHERE "NomGenerique"=%s', [prefix])['n'], 0)

    def test_05_duplicate_names_all_involved_rows(self):
        name = 'Doublon ' + uuid.uuid4().hex
        rows = [{'clientRowId': 'a', 'NomGenerique': name}, {'clientRowId': 'b', 'NomGenerique': '  ' + name.upper().replace(' ', '\u00a0 ') + '  '}]
        response = self.post(self.batch(rows=rows)); self.assertEqual(response.status_code, 422, response.data)
        self.assertEqual(set(response.data['error']['details']['rows']), {'a', 'b'})

    def test_06_duplicate_codes(self):
        code = 'UNIQUE-' + uuid.uuid4().hex
        rows = [{'clientRowId': str(i), 'NomGenerique': str(uuid.uuid4()), 'AbrGenerique': code.lower() if i else code} for i in range(2)]
        response = self.post(self.batch(rows=rows)); self.assertEqual(response.status_code, 422)
        self.assertTrue(all('AbrGenerique' in value for value in response.data['error']['details']['rows'].values()))

    def test_07_existing_duplicates_return_row_fields(self):
        row = db.one('SELECT * FROM referentiel."T_Generique" WHERE "ID_Generique"=%s', [self.shared_value])
        response = self.post(self.batch(rows=[{'clientRowId': 'duplique', 'NomGenerique': row['NomGenerique']}]))
        self.assertEqual(response.status_code, 422); self.assertIn('NomGenerique', response.data['error']['details']['rows']['duplique'])

    def test_08_late_sql_error_rolls_back_first_insert_and_audit(self):
        from apps.core.repository import mutate
        names = ['Atomicité ' + uuid.uuid4().hex for _ in range(2)]
        body = self.batch(rows=[{'clientRowId': str(i), 'NomGenerique': name} for i, name in enumerate(names)])
        count = 0
        def late_failure(*args, **kwargs):
            nonlocal count
            count += 1
            if count == 2:
                raise APIError('Conflit concurrent simulé après la première écriture.', 'CONSTRAINT_VIOLATION', 409)
            return mutate(*args, **kwargs)
        with patch('apps.core.repository.mutate', side_effect=late_failure):
            response = self.post(body)
        self.assertEqual(response.status_code, 422, response.data)
        self.assertEqual(db.one('SELECT count(*) n FROM referentiel."T_Generique" WHERE "NomGenerique"=ANY(%s)', [names])['n'], 0)
        self.assertEqual(db.one('SELECT count(*) n FROM systeme."T_Audit_Log" WHERE "NewData"->>\'requestId\'=%s', [body['requestId']])['n'], 0)

    def test_09_parent_missing_invalid_inactive(self):
        for value in [None, 'invalide', 2147483647]:
            response = self.post(self.batch(categoryId=value)); self.assertEqual(response.status_code, 422, response.data)
        db.query('UPDATE referentiel."T_CategorieGenerique" SET "ValideCategorieGenerique"=false WHERE "ID_CategorieGenerique"=%s', [self.categories[0]])
        self.assertEqual(self.post().status_code, 422)

    def test_10_invalid_rows_bounds_and_unknowns(self):
        for rows in [[], [{}] * 201]:
            response = self.post(self.batch(rows=rows)); self.assertEqual(response.status_code, 422, response.data)
        response = self.post(self.batch(rows=[{'clientRowId': 'x', 'NomGenerique': 'x', 'ID_Generique': 99}]))
        self.assertEqual(response.status_code, 422)

    def test_11_non_boolean_and_too_long(self):
        for row in [{'clientRowId': 'x', 'NomGenerique': 'x', 'VisibleArticle': 1},
                    {'clientRowId': 'x', 'NomGenerique': 'x' * 256},
                    {'clientRowId': 'x', 'NomGenerique': 'x\x00bad'}]:
            self.assertEqual(self.post(self.batch(rows=[row])).status_code, 422)

    def test_12_private_create_for_own_entity(self):
        body = self.batch(scope='entity', scopeValue=self.entities[0], categoryId=self.categories[1])
        response = self.post(body, global_admin=False); self.assertEqual(response.status_code, 201, response.data)
        self.assertEqual(response.data['data']['records'][0]['IdEntiteFk'], self.entities[0])

    def test_13_local_cannot_common_or_foreign(self):
        self.assertEqual(self.post(global_admin=False).status_code, 403)
        self.assertEqual(self.post(self.batch(scope='entity', scopeValue=self.entities[1]), global_admin=False).status_code, 403)

    def test_14_private_under_common_allowed_parent_foreign_denied(self):
        body = self.batch(scope='entity', scopeValue=self.entities[0], categoryId=self.categories[0])
        self.assertEqual(self.post(body, global_admin=False).status_code, 201)
        body = self.batch(scope='entity', scopeValue=self.entities[0], categoryId=self.categories[2])
        self.assertEqual(self.post(body, global_admin=False).status_code, 422)

    def test_15_anonymous_no_write_readonly_and_licence(self):
        anonymous = APIClient().post(BASE + 'valeurs', self.batch(), format='json')
        self.assertIn(anonymous.status_code, (401, 403))
        self.assertEqual(self.post(global_admin=False, admin=False).status_code, 403)
        self.assertEqual(self.post(global_admin=False, manage=False).status_code, 403)
        with override_settings(DB_READ_ONLY=True):
            self.assertEqual(self.post().status_code, 503)

    def test_16_individual_create_edit_archive_owner(self):
        client = self.client(global_admin=False)
        response = client.post('/api/models/T_Generique', {'NomGenerique': 'Individuel ' + uuid.uuid4().hex,
            'ID_CategorieGeneriqueFk': self.categories[0], 'IdEntiteFk': self.entities[0]}, format='json')
        self.assertEqual(response.status_code, 201, response.data); pk = response.data['data']['ID_Generique']
        changed = client.put('/api/models/T_Generique/' + str(pk), {'ObsGenerique': 'Correction descriptive'}, format='json')
        self.assertEqual(changed.status_code, 200, changed.data)
        archived = client.delete('/api/models/T_Generique/' + str(pk)); self.assertEqual(archived.status_code, 200, archived.data)
        self.assertIs(archived.data['data']['ValideGenerique'], False)

    def test_17_local_common_foreign_update_denied(self):
        client = self.client(global_admin=False)
        common = client.put('/api/models/T_Generique/' + str(self.shared_value), {'NomGenerique': 'Interdit'}, format='json')
        self.assertEqual(common.status_code, 403, common.data)
        foreign = client.get('/api/models/T_Generique/' + str(self.private_values[1]))
        self.assertEqual(foreign.status_code, 404, foreign.data)

    def test_18_owner_immutable_even_platform(self):
        response = self.client().put('/api/models/T_Generique/' + str(self.private_values[0]),
            {'IdEntiteFk': self.entities[1]}, format='json')
        self.assertEqual(response.status_code, 409, response.data)

    def test_19_individual_duplicate(self):
        response = self.client().post('/api/models/T_Generique', {'ID_CategorieGeneriqueFk': self.categories[0],
            'NomGenerique': f'Commun {self.tag}'}, format='json')
        self.assertEqual(response.status_code, 422, response.data)

    def test_20_scoped_list_and_filters_no_escape(self):
        response = self.client(global_admin=False).get('/api/views/referentiel/V_Generique',
            {'take': 500, 'filters': json.dumps({'ID_CategorieGeneriqueFk': self.categories[0]})})
        self.assertEqual(response.status_code, 200, response.data)
        ids = {row['ID_Generique'] for row in response.data['data']}
        self.assertIn(self.shared_value, ids); self.assertIn(self.private_values[0], ids); self.assertNotIn(self.private_values[1], ids)
        self.assertTrue(response.data['meta']['canCreateEntity']); self.assertFalse(response.data['meta']['canCreateCommon'])
        escaped = self.client(global_admin=False).get('/api/views/referentiel/V_Generique',
            {'filters': json.dumps({'IdEntiteFk': self.entities[1]})})
        self.assertEqual(escaped.status_code, 200); self.assertEqual(escaped.data['meta']['filteredCount'], 0)

    def test_21_private_options_and_forged_currentid_no_leak(self):
        # L'alias physique d'une catégorie est changé uniquement dans la copie.
        field_path = '/api/referentiel/champs-references/' + str(self.article_category_field)
        admin = self.client(); detail = admin.get(field_path).data['data']
        body = {'requestId': str(uuid.uuid4()), 'scope': 'global', '_version': detail['_version'],
                'motif': 'Recette isolée', 'categoryIds': [self.categories[0]]}
        response = admin.put(field_path, body, format='json'); self.assertEqual(response.status_code, 200, response.data)
        query = {'schema': 'logistique', 'table': 'T_Article', 'column': 'ID_CategorieArticleFk',
                 'currentId': self.private_values[1]}
        options = self.client(global_admin=False).get('/api/referentiel/champs-references/valeurs', query)
        self.assertEqual(options.status_code, 200, options.data)
        ids = {row['id'] for row in options.data['data']['options']}
        self.assertIn(self.shared_value, ids); self.assertIn(self.private_values[0], ids); self.assertNotIn(self.private_values[1], ids)

    def test_22_private_category_configuration_scope(self):
        path = '/api/referentiel/champs-references/' + str(self.article_category_field)
        client = self.client()
        detail = client.get(path).data['data']
        common = {'requestId': str(uuid.uuid4()), 'scope': 'global', '_version': detail['_version'],
                  'motif': 'Recette', 'categoryIds': [self.categories[1]]}
        self.assertEqual(client.put(path, common, format='json').status_code, 400)
        detail = client.get(path, {'scope': 'entity', 'scopeValue': self.entities[0]}).data['data']
        body = {**common, 'requestId': str(uuid.uuid4()), 'scope': 'entity', 'scopeValue': self.entities[0], '_version': detail['_version']}
        response = client.put(path, body, format='json'); self.assertEqual(response.status_code, 200, response.data)

    def test_23_currencies_private_are_scoped(self):
        from apps.logistique.currency import currency_references
        category = db.one('SELECT "ID_CategorieDefautFk" id FROM referentiel."T_ChampReferentiel" '
            'WHERE "SchemaName"=\'logistique\' AND "TableName"=\'T_Article\' AND "ColumnName"=\'ID_DeviseFk\'')['id']
        value = db.one('INSERT INTO referentiel."T_Generique"("ID_CategorieGeneriqueFk","NomGenerique","AbrGenerique","IdEntiteFk") '
            'VALUES(%s,%s,\'CHF\',%s) RETURNING "ID_Generique" id', [category, 'Franc suisse recette ' + self.tag, self.entities[0]])['id']
        self.assertIn(value, {row['id'] for row in currency_references(self.actor(global_admin=False))})
        self.assertNotIn(value, {row['id'] for row in currency_references(self.actor(index=1, global_admin=False))})

    def test_24_csv_export_matches_authorized_filtered_rows(self):
        client = self.client(global_admin=False)
        query = {'filters': json.dumps({'ID_CategorieGeneriqueFk': self.categories[0]}),
                 'columns': json.dumps(['NomGenerique', 'ID_Generique'])}
        listing = client.get('/api/views/referentiel/V_Generique', {'filters': query['filters']})
        response = client.get('/api/referentiel/exports/valeurs.csv', query)
        self.assertEqual(response.status_code, 200, getattr(response, 'data', None))
        content = b''.join(response.streaming_content).decode('utf-8-sig')
        table = list(csv.reader(io.StringIO(content), delimiter=';'))
        self.assertEqual(len(table) - 1, listing.data['meta']['filteredCount'])
        self.assertNotIn(f'Privé {self.tag}-1', content)

    def test_25_categories_private_batch_and_duplicate_boundaries(self):
        name = 'Organisation locale ' + uuid.uuid4().hex
        for index in range(2):
            body = self.batch('categories', [self.category_row(name)], scope='entity', scopeValue=self.entities[index])
            response = self.post(body, 'categories', index=index, global_admin=False)
            self.assertEqual(response.status_code, 201, response.data)
        # La création commune ne masque aucune des familles privées existantes.
        response = self.post(self.batch('categories', [self.category_row(name)]), 'categories')
        self.assertEqual(response.status_code, 422, response.data)

    def test_26_individual_categories_and_no_partial_categories(self):
        client = self.client(global_admin=False)
        name = 'Catégorie individuelle ' + uuid.uuid4().hex
        response = client.post('/api/models/T_CategorieGenerique', {'NomCategorieGenerique': name,
            'IdEntiteFk': self.entities[0]}, format='json')
        self.assertEqual(response.status_code, 201, response.data)
        pk = response.data['data']['ID_CategorieGenerique']
        changed = client.put('/api/models/T_CategorieGenerique/' + str(pk), {'ModuleCategorieGenerique': 'M_ART'}, format='json')
        self.assertEqual(changed.status_code, 200, changed.data)
        rows = [self.category_row('À annuler ' + uuid.uuid4().hex), self.category_row('', row_id='invalid')]
        rows[1]['NomCategorieGenerique'] = ''
        response = self.post(self.batch('categories', rows), 'categories')
        self.assertEqual(response.status_code, 422)
        self.assertEqual(db.one('SELECT count(*) n FROM referentiel."T_CategorieGenerique" WHERE "NomCategorieGenerique"=%s', [rows[0]['NomCategorieGenerique']])['n'], 0)

    def test_27_private_security_roles_cannot_be_created_or_assigned(self):
        category = db.one('SELECT "ID_CategorieDefautFk" id FROM referentiel."T_ChampReferentiel" '
            'WHERE NOT "CanConfigure" AND "SchemaName"=\'systeme\' AND "TableName"=\'T_Utilisateurs\'')['id']
        body = self.batch(scope='entity', scopeValue=self.entities[0], categoryId=category)
        response = self.post(body, global_admin=False)
        self.assertEqual(response.status_code, 422, response.data)
        self.assertIn('categoryId', response.data['error']['details']['header'])
        response = self.client(global_admin=False).post('/api/models/T_Generique',
            {'ID_CategorieGeneriqueFk': category, 'NomGenerique': 'Faux administrateur ' + uuid.uuid4().hex,
             'AbrGenerique': 'FauxAdmin', 'IdEntiteFk': self.entities[0]}, format='json')
        self.assertEqual(response.status_code, 422, response.data)

    def test_28_dynamic_remap_restores_without_changing_prior_values(self):
        path = '/api/referentiel/champs-references/' + str(self.article_category_field)
        client = self.client(); args = {'scope': 'entity', 'scopeValue': self.entities[0]}
        before = db.query('SELECT * FROM referentiel."T_Generique" WHERE "ID_CategorieGeneriqueFk"=%s ORDER BY "ID_Generique"', [self.categories[0]])
        detail = client.get(path, args).data['data']
        changed = client.put(path, {**args, 'requestId': str(uuid.uuid4()), '_version': detail['_version'],
            'motif': 'Recette changement', 'categoryIds': [self.categories[1]]}, format='json')
        self.assertEqual(changed.status_code, 200, changed.data)
        detail = client.get(path, args).data['data']
        restored = client.post(path + '/retablir', {**args, 'requestId': str(uuid.uuid4()), '_version': detail['_version'],
            'motif': 'Recette restauration'}, format='json')
        self.assertEqual(restored.status_code, 200, restored.data)
        self.assertEqual(restored.data['data']['categoryIds'], [detail['defaultCategoryId']])
        self.assertEqual(before, db.query('SELECT * FROM referentiel."T_Generique" WHERE "ID_CategorieGeneriqueFk"=%s ORDER BY "ID_Generique"', [self.categories[0]]))

    def test_29_batch_no_partial_after_private_header_mismatch(self):
        body = self.batch(scope='entity', scopeValue=self.entities[0], categoryId=self.categories[2])
        before = db.one('SELECT count(*) n FROM referentiel."T_Generique"')['n']
        response = self.post(body, global_admin=False)
        self.assertEqual(response.status_code, 422, response.data)
        self.assertEqual(before, db.one('SELECT count(*) n FROM referentiel."T_Generique"')['n'])

    def remap(self, table, column, category, *, entity=None):
        field = db.one('SELECT "ID_ChampReferentiel" id FROM referentiel."T_ChampReferentiel" '
            'WHERE "SchemaName"=\'logistique\' AND "TableName"=%s AND "ColumnName"=%s', [table, column])['id']
        args = {'scope': 'entity', 'scopeValue': entity} if entity is not None else {'scope': 'global'}
        path = '/api/referentiel/champs-references/' + str(field)
        client = self.client(); detail = client.get(path, args).data['data']
        response = client.put(path, {**args, 'requestId': str(uuid.uuid4()), '_version': detail['_version'],
            'motif': 'Recette dépendance métier', 'categoryIds': [category]}, format='json')
        self.assertEqual(response.status_code, 200, response.data)

    def new_article(self):
        from apps.core import repository
        from apps.core.field_references import reference_options
        actor = self.actor()
        fields = ('ID_CategorieArticleFk', 'ID_TypeArticleFk', 'ID_UniteFk', 'ID_DeviseFk')
        values = {field: reference_options(actor, 'logistique', 'T_Article', field)[0]['id'] for field in fields}
        return repository.mutate('T_Article', actor, {**values, 'NomArticle': 'Article métier fictif ' + uuid.uuid4().hex,
            'QteArticle': '10', 'PUArticle': '10', 'PVArticle': '15', 'ValideArticle': True})

    def test_30_payment_and_refund_modes_dynamic_private_and_retained(self):
        from apps.logistique.payments import modes
        from apps.logistique.invoices import payment_references
        actor = self.actor(); previous = modes(actor)[0]['id']
        for table, column in [('T_Reglements', 'ID_ModeReglementFk'), ('T_Remboursement', 'ID_ModePaiementFk'),
                              ('T_Commande', 'ID_ModePaiementFk')]:
            self.remap(table, column, self.categories[0])
        scoped = self.actor(); del scoped._context_entity
        rows = modes(scoped, previous, entity=self.entities[0])
        by_id = {row['id']: row for row in rows}
        self.assertIn(self.private_values[0], by_id); self.assertNotIn(self.private_values[1], by_id)
        self.assertEqual(by_id[self.shared_value]['label'], 'C-' + self.tag)
        self.assertTrue(by_id[previous]['disabled']); self.assertFalse(by_id[previous]['active'])
        self.assertFalse(hasattr(scoped, '_context_entity'))
        for owner, allowed, forbidden in [(self.entities[0], self.private_values[0], self.private_values[1]),
                                          (self.entities[1], self.private_values[1], self.private_values[0])]:
            refund = modes(scoped, entity=owner, table='T_Remboursement', column='ID_ModePaiementFk', lock=True)
            self.assertIn(allowed, {row['id'] for row in refund}); self.assertNotIn(forbidden, {row['id'] for row in refund})
            invoice = payment_references({'IdEntiteFk': owner}, actor=scoped)['modesPaiement']
            self.assertIn(allowed, {row['id'] for row in invoice}); self.assertNotIn(forbidden, {row['id'] for row in invoice})
        with self.assertRaises(APIError):
            modes(self.actor(global_admin=False), entity=self.entities[1])

    def test_31_inventory_and_cancellation_use_configured_document_types(self):
        from apps.logistique import inventories, inventory_cancellation
        from apps.logistique.lots import stock_document_types, outgoing_type
        article = self.new_article(); article_id = article['ID_Article']; actor = self.actor()
        kinds = {}
        for sign, name, code in [(1, 'Réception privée', 'Entrée'), (-1, 'Expédition privée', 'Sortie')]:
            kinds[sign] = db.one('INSERT INTO referentiel."T_Generique" '
                '("ID_CategorieGeneriqueFk","NomGenerique","AbrGenerique","IdEntiteFk") '
                'VALUES(%s,%s,%s,%s) RETURNING "ID_Generique" id',
                [self.categories[1], name + self.tag, code, self.entities[0]])['id']
        self.remap('T_Commande', 'ID_TypeCmdFk', self.categories[1], entity=self.entities[0])
        self.assertEqual(stock_document_types(actor, lock=True), kinds)
        self.assertTrue(outgoing_type(kinds[-1])); self.assertFalse(outgoing_type(kinds[1]))
        saved, _ = inventories.save(actor, None, {'requestId': str(uuid.uuid4()),
            'DateInventaire': '2026-10-30T12:00:00', 'Motif': 'Comptage fictif dynamique',
            'lignes': [{'ID_ArticleFk': article_id, 'QteTheorique': '10', 'QteComptee': '9',
                'Justification': 'Écart fictif', 'Lots': [], 'PUCorrection': '10'}]})
        validated, _ = inventories.validate(actor, saved['ID_Inventaire'],
            {'requestId': str(uuid.uuid4()), '_version': saved['Version']})
        correction = validated['lignes'][0]['ID_CommandeCorrectionFk']
        self.assertEqual(db.one('SELECT "ID_TypeCmdFk" id FROM logistique."T_Commande" WHERE "ID_Commande"=%s', [correction])['id'], kinds[-1])
        cancelled, _ = inventory_cancellation.cancel(actor, saved['ID_Inventaire'],
            {'requestId': str(uuid.uuid4()), '_version': validated['Version'], 'motif': 'Contrôle compensation'})
        inverse = cancelled['lignes'][0]['ID_CommandeAnnulationFk']
        self.assertEqual(db.one('SELECT "ID_TypeCmdFk" id FROM logistique."T_Commande" WHERE "ID_Commande"=%s', [inverse])['id'], kinds[1])
        self.assertEqual(db.one('SELECT "QteArticle" q FROM logistique."T_Article" WHERE "ID_Article"=%s', [article_id])['q'], 10)

    def test_32_payment_create_after_mapping_uses_private_mode(self):
        from datetime import datetime, timedelta, timezone
        from apps.logistique import order_composer, invoices, payments
        from apps.core.field_references import reference_options
        actor = self.actor(); article = self.new_article()
        outgoing = next(item for item in reference_options(actor, 'logistique', 'T_Commande', 'ID_TypeCmdFk')
                        if item['kind'] == 'sortie')['id']
        payload = {'requestId': str(uuid.uuid4()), 'bon': {'ID_TypeCmdFk': outgoing,
            'ID_DeviseFk': article['ID_DeviseFk'], 'DateCmd': '2026-10-30T12:00:00'},
            'lignes': [{'ID_ArticleFk': article['ID_Article'], 'QteCmdDetail': '1', 'PUCmdDetail': '15', 'Lots': []}]}
        created = self.client().post('/api/logistique/commandes/composees', payload, format='json')
        self.assertEqual(created.status_code, 201, created.data); command = created.data['data']['bon']['ID_Commande']
        info = invoices.context(actor, command); stamp = datetime.now(timezone.utc)
        invoice = invoices.write_invoice(actor, command, {'requestId': str(uuid.uuid4()),
            '_version': info['meta']['revision'], 'DateFacture': stamp.isoformat(),
            'DateEcheancePaiement': (stamp + timedelta(days=7)).isoformat()}, 'issue')['facture']
        self.remap('T_Reglements', 'ID_ModeReglementFk', self.categories[0], entity=self.entities[0])
        prepared, policy = payments.preparation(actor, command)
        self.assertIn(self.private_values[0], {row['id'] for row in prepared['references']['reglementModes']})
        body = {'requestId': str(uuid.uuid4()), '_version': policy['revision'], 'CodeFactureFk': invoice['CodeFacture'],
            'ID_ModeReglementFk': self.private_values[1], 'DateReglement': stamp.replace(tzinfo=None).isoformat(), 'MontantRegle': '5'}
        response = self.client().post('/api/logistique/reglements', body, format='json')
        self.assertEqual(response.status_code, 400, response.data)
        response = self.client().post('/api/logistique/reglements', {**body, 'requestId': str(uuid.uuid4()),
            'ID_ModeReglementFk': self.private_values[0]}, format='json')
        self.assertEqual(response.status_code, 201, response.data)
        self.assertEqual(response.data['data']['ID_ModeReglementFk'], self.private_values[0])

    def test_33_invoice_on_private_configured_outgoing_type(self):
        from datetime import datetime, timedelta, timezone
        from apps.logistique import invoices
        actor = self.actor(); article = self.new_article()
        kind = db.one('INSERT INTO referentiel."T_Generique" '
            '("ID_CategorieGeneriqueFk","NomGenerique","AbrGenerique","IdEntiteFk") '
            'VALUES(%s,%s,\'Sortie\',%s) RETURNING "ID_Generique" id',
            [self.categories[1], 'Expédition privée facture ' + self.tag, self.entities[0]])['id']
        self.remap('T_Commande', 'ID_TypeCmdFk', self.categories[1], entity=self.entities[0])
        created = self.client().post('/api/logistique/commandes/composees', {'requestId': str(uuid.uuid4()),
            'bon': {'ID_TypeCmdFk': kind, 'ID_DeviseFk': article['ID_DeviseFk'], 'DateCmd': '2026-10-30T12:00:00'},
            'lignes': [{'ID_ArticleFk': article['ID_Article'], 'QteCmdDetail': '2', 'PUCmdDetail': '15', 'Lots': []}]}, format='json')
        self.assertEqual(created.status_code, 201, created.data)
        command = created.data['data']['bon']['ID_Commande']; info = invoices.context(actor, command)
        self.assertTrue(info['meta']['canIssue'], info['meta']); stamp = datetime.now(timezone.utc)
        invoice = invoices.write_invoice(actor, command, {'requestId': str(uuid.uuid4()),
            '_version': info['meta']['revision'], 'DateFacture': stamp.isoformat(),
            'DateEcheancePaiement': (stamp + timedelta(days=7)).isoformat()}, 'issue')['facture']
        self.assertTrue(invoice['CodeFacture'].startswith('fac-'))
        self.assertEqual(str(invoice['MontantTTC']), '30.00')
        movement = db.one('SELECT "SigneStock","QteMvtSigned" FROM logistique."V_MouvementStock" '
            'WHERE "ID_cmdFk"=%s AND "ID_ArticleFk"=%s', [command, article['ID_Article']])
        self.assertEqual(movement['SigneStock'], -1); self.assertEqual(movement['QteMvtSigned'], -2)
        self.assertEqual(db.one('SELECT "QteArticle" q FROM logistique."T_Article" WHERE "ID_Article"=%s',
                               [article['ID_Article']])['q'], 8)

    def test_34_private_reference_labels_remain_in_article_view(self):
        from apps.core import repository
        from apps.logistique.article_rules import revision
        actor = self.actor(); article = self.new_article()
        self.remap('T_Article', 'ID_CategorieArticleFk', self.categories[0], entity=self.entities[0])
        self.remap('T_Article', 'ID_TypeArticleFk', self.categories[0], entity=self.entities[0])
        private = self.private_values[0]
        current = db.one('SELECT * FROM logistique."T_Article" WHERE "ID_Article"=%s', [article['ID_Article']])
        changed = repository.mutate('T_Article', actor, {'ID_CategorieArticleFk': private, 'ID_TypeArticleFk': private,
            '_version': revision(current)},
            keys={'ID_Article': article['ID_Article']}, operation='update')
        self.assertEqual(changed['ID_CategorieArticleFk'], private)
        response = self.client().get('/api/views/logistique/V_Article',
            {'filters': json.dumps({'ID_Article': article['ID_Article']})})
        self.assertEqual(response.status_code, 200, response.data)
        shown = response.data['data'][0]; label = f'Privé {self.tag}-0'
        self.assertEqual(shown['CategorieArticle'], label); self.assertEqual(shown['TypeArticle'], label)
        self.assertEqual(shown['AbrCategorieArticle'], 'P-' + self.tag + '-0')


if __name__ == '__main__':
    result = unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(ReferentialAPI))
    proof = {'passed': result.wasSuccessful(), 'tests': result.testsRun, 'failures': len(result.failures),
             'errors': len(result.errors), 'database': location.path[1:],
             'scope': 'Données fictives dans PostgreSQL privé local, aucune mutation de SauverNdeko.'}
    output = ROOT / '.runtime/referentiels30-api.json'; output.write_text(json.dumps(proof, ensure_ascii=False, indent=2), encoding='utf8')
    sys.exit(0 if result.wasSuccessful() else 1)
