"""Catalogue partagé + préférences strictement personnelles, PostgreSQL privé."""
import csv
import io
import json
import os
import sys
import unittest
import uuid
import zipfile
from xml.etree import ElementTree as ET
from pathlib import Path
from urllib.parse import urlsplit

import psycopg
from psycopg.rows import dict_row

ROOT = Path(__file__).resolve().parents[2]
DSN = os.environ.get('SAUVERNDEKO_TEST_DATABASE_URL', '')
target = urlsplit(DSN)
if target.hostname not in {'127.0.0.1', 'localhost'} or not target.path[1:].startswith('sauverndeko_test_'):
    raise RuntimeError('Recette exclusivement PostgreSQL privé local sauverndeko_test_*.')
os.environ.update(DATABASE_URL=DSN, DJANGO_SETTINGS_MODULE='config.settings', SAUVERNDEKO_DB_READ_ONLY='0')
sys.path.insert(0, str(ROOT/'backend'))
import django
django.setup()
from django.db import transaction
from django.test import override_settings
from rest_framework.test import APIClient
from apps.accounts.authentication import Actor

BASE = '/api/referentiel/tableaux'


class ReferenceTablesAPI(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.settings = override_settings(ALLOWED_HOSTS=['testserver'])
        cls.settings.enable()
        cls.sql = psycopg.connect(DSN, autocommit=True, row_factory=dict_row)
        cls.entities = [cls.sql.execute('INSERT INTO systeme."T_Entite"("NomEntite","EmailEntite","ValideEntite") '
            'VALUES(%s,%s,true) RETURNING "IdEntite" id', ['Catalogue fictif '+uuid.uuid4().hex,
            uuid.uuid4().hex+'@example.invalid']).fetchone()['id'] for _ in range(2)]
        cls.users = [cls.sql.execute('INSERT INTO systeme."T_Utilisateurs" '
            '("NomUser","PrenomUser","EmailUser","MotdepasseUser","ValideUser","SexeUser","Is_Admin","Is_staff","IdEntiteFk") '
            'VALUES(\'Catalogue\',\'Fictif\',%s,\'inutilisable\',true,\'M\',true,true,%s) RETURNING *',
            [uuid.uuid4().hex+'@example.invalid', entity]).fetchone() for entity in cls.entities]

    @classmethod
    def tearDownClass(cls):
        cls.sql.close()
        cls.settings.disable()

    def setUp(self):
        self.tx = transaction.atomic()
        self.tx.__enter__()

    def tearDown(self):
        transaction.set_rollback(True)
        self.tx.__exit__(None, None, None)

    def client(self, user=0, entity=0):
        actor = Actor(dict(self.users[user]))
        actor._context_entity = self.entities[entity]
        client = APIClient()
        client.force_authenticate(actor)
        return client

    def test_catalogue_pagination_search_filters_and_detail(self):
        client = self.client()
        first = client.get(BASE, {'take': 1, 'skip': 0})
        second = client.get(BASE, {'take': 1, 'skip': 1})
        self.assertEqual(first.status_code, 200)
        self.assertGreater(first.data['meta']['filteredCount'], 1)
        self.assertNotEqual(first.data['data'][0]['CleInterface'], second.data['data'][0]['CleInterface'])
        response = client.get(BASE, {'q': 'logistique.articles', 'filters': json.dumps({'Module': 'logistique'})})
        self.assertEqual(response.data['meta']['filteredCount'], 1)
        row = response.data['data'][0]
        self.assertFalse(row['PreferenceTableau'])
        self.assertFalse(row['PreferenceExport'])
        self.assertNotIn('Colonnes', row)
        detail = client.get(BASE+'/logistique.articles')
        self.assertEqual(detail.status_code, 200)
        self.assertEqual(detail.data['data']['CleInterface'], 'logistique.articles')
        self.assertGreater(len(detail.data['data']['Colonnes']), 1)

    def test_own_preferences_are_independent_by_user_entity_and_usage(self):
        a, b, other_entity = self.client(), self.client(user=1), self.client(entity=1)
        path = '/api/tableaux/logistique.articles/preferences'
        current = b.get(path).data['data']
        result = b.put(path, {'usage': 'table', 'columns': ['NomArticle'], 'version': current['table']['version']}, format='json')
        self.assertEqual(result.status_code, 200)
        def find(client):
            return client.get(BASE, {'q': 'logistique.articles'}).data['data'][0]
        self.assertFalse(find(a)['PreferenceTableau'])
        self.assertTrue(find(b)['PreferenceTableau'])
        current = a.get(path).data['data']
        result = a.put(path, {'usage': 'table', 'columns': ['NomArticle'], 'version': current['table']['version']}, format='json')
        self.assertEqual(result.status_code, 200)
        self.assertTrue(find(a)['PreferenceTableau'])
        self.assertFalse(find(a)['PreferenceExport'])
        self.assertFalse(find(other_entity)['PreferenceTableau'])
        response = a.get(BASE, {'filters': json.dumps({'PreferenceTableau': True})})
        self.assertEqual([row['CleInterface'] for row in response.data['data']], ['logistique.articles'])
        version = result.data['data']['table']['version']
        self.assertEqual(a.delete(path, {'usage': 'table', 'version': version}, format='json').status_code, 200)
        self.assertFalse(find(a)['PreferenceTableau'])
        self.assertTrue(find(b)['PreferenceTableau'])

    def test_exports_share_scope_and_filtered_rows_with_real_files(self):
        client = self.client()
        params = {'q': 'logistique.articles', 'columns': json.dumps(['CleInterface', 'NbColonnes'])}
        response = client.get(BASE+'/export.csv', params, HTTP_ACCEPT='text/csv')
        self.assertEqual(response.status_code, 200)
        content = b''.join(response.streaming_content).decode('utf-8-sig')
        rows = list(csv.reader(io.StringIO(content), delimiter=';'))
        self.assertEqual(rows[0], ['Interface', 'Colonnes disponibles'])
        self.assertEqual(len(rows), 2)
        self.assertEqual(rows[1][0], 'logistique.articles')
        response = client.get(BASE+'/export.xlsx', params, HTTP_ACCEPT='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
        self.assertEqual(response.status_code, 200)
        content = b''.join(response.streaming_content)
        with zipfile.ZipFile(io.BytesIO(content)) as book:
            self.assertIn('xl/worksheets/sheet1.xml', book.namelist())
            sheet = ET.fromstring(book.read('xl/worksheets/sheet1.xml'))
            namespace = {'x': 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
            self.assertEqual(len(sheet.findall('.//x:sheetData/x:row', namespace)), 2)
            self.assertIn('logistique.articles', [node.text for node in sheet.findall('.//x:t', namespace)])

    def test_protected_catalogue_and_bad_queries(self):
        client = self.client()
        self.assertEqual(client.put(BASE+'/logistique.articles', {'Version': 7}, format='json').status_code, 405)
        self.assertEqual(client.get(BASE, {'filters': json.dumps({'IdUserFk': self.users[1]['IdUser']})}).status_code, 400)
        self.assertEqual(client.get(BASE, {'sortBy': 'IdUserFk'}).status_code, 400)
        self.assertEqual(client.get(BASE+'/unknown.missing').status_code, 404)
        self.assertEqual(client.get(BASE, {'filters': json.dumps({'PreferenceTableau': 'false'})}).status_code, 400)
        self.assertIn(APIClient().get(BASE).status_code, (401, 403))

    def test_private_unit_precision_is_not_visible_or_editable_from_another_entity(self):
        client, other = self.client(), self.client(entity=1)
        family = self.sql.execute('SELECT "ID_CategorieDefautFk" id FROM referentiel."T_ChampReferentiel" '
            'WHERE "SchemaName"=\'logistique\' AND "TableName"=\'T_Article\' AND "ColumnName"=\'ID_UniteFk\'').fetchone()['id']
        name = 'Unité fractionnaire fictive '+uuid.uuid4().hex
        created = client.post('/api/referentiel/saisie-multiple/valeurs',
            {'requestId': str(uuid.uuid4()), 'scope': 'entity', 'scopeValue': self.entities[0], 'categoryId': family,
             'rows': [{'clientRowId': 'private-unit', 'NomGenerique': name, 'AbrGenerique': name}]}, format='json')
        self.assertEqual(created.status_code, 201, created.data)
        unit = created.data['data']['records'][0]['ID_Generique']
        path = '/api/logistique/inventaires/unites'
        saved = client.put(path, {'ID_UniteFk': unit, 'Decimales': 2}, format='json')
        self.assertEqual(saved.status_code, 200, saved.data)
        self.assertTrue(any(row['ID_UniteFk'] == unit and row['Decimales'] == 2 for row in client.get(path).data['data']))
        self.assertFalse(any(row['ID_UniteFk'] == unit for row in other.get(path).data['data']))
        self.assertEqual(other.put(path, {'ID_UniteFk': unit, 'Decimales': 3}, format='json').status_code, 404)

    def test_dependent_health_catalogue_preserves_private_reference_scope(self):
        from apps.core import db
        client, other = self.client(), self.client(entity=1)
        family_row = db.one('SELECT "ID_CategorieGenerique" id FROM referentiel."T_CategorieGenerique" '
            'WHERE lower("NomCategorieGenerique")=\'maladie\' AND "IdEntiteFk" IS NULL LIMIT 1')
        if family_row:
            family = family_row['id']
        else:
            response = client.post('/api/referentiel/saisie-multiple/categories',
                {'requestId': str(uuid.uuid4()), 'scope': 'global', 'rows': [
                    {'clientRowId': 'health-family', 'NomCategorieGenerique': 'Maladie'}]}, format='json')
            self.assertEqual(response.status_code, 201, response.data)
            family = response.data['data']['records'][0]['ID_CategorieGenerique']
        name = 'Référence santé fictive '+uuid.uuid4().hex
        before = client.get('/api/public/stats').data['data']['diseasesCount']
        before_other = other.get('/api/public/stats').data['data']['diseasesCount']
        created = client.post('/api/referentiel/saisie-multiple/valeurs',
            {'requestId': str(uuid.uuid4()), 'scope': 'entity', 'scopeValue': self.entities[0], 'categoryId': family,
             'rows': [{'clientRowId': 'private-health', 'NomGenerique': name, 'AbrGenerique': name}]}, format='json')
        self.assertEqual(created.status_code, 201, created.data)
        found = client.get('/api/public/maladies', {'q': name})
        self.assertEqual(found.status_code, 200, found.data)
        self.assertEqual([row['ID_Generique'] for row in found.data['data']],
                         [created.data['data']['records'][0]['ID_Generique']])
        self.assertEqual(other.get('/api/public/maladies', {'q': name}).data['data'], [])
        self.assertEqual(client.get('/api/public/stats').data['data']['diseasesCount'], before+1)
        self.assertEqual(other.get('/api/public/stats').data['data']['diseasesCount'], before_other)


if __name__ == '__main__':
    unittest.main(verbosity=2)
