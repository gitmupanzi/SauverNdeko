"""Paniers logistiques réels : PostgreSQL privé local et médias temporaires.

La recette refuse toute base hors sauverndeko_test_* ; aucune donnée de test
ni image n'est créée dans SauverNdeko ou ses médias applicatifs.
"""
import io
import json
import os
import sys
import tempfile
import unittest
import uuid
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from time import perf_counter
from unittest.mock import patch
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
from django.core.files.uploadedfile import SimpleUploadedFile
from django.db import connections, transaction
from django.test import override_settings
from PIL import Image
from rest_framework.test import APIClient
from apps.accounts.authentication import Actor
from apps.core import db
from apps.core.field_references import reference_options
from apps.logistique import batch_creation

BASE = '/api/logistique/saisie-multiple/'


class LogisticsBatchAPI(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.media = tempfile.TemporaryDirectory(prefix='sauverndeko-batch-test-')
        cls.settings = override_settings(ALLOWED_HOSTS=['testserver'], ARTICLE_MEDIA_ROOT=Path(cls.media.name))
        cls.settings.enable()
        cls.sql = psycopg.connect(DSN, autocommit=True, row_factory=dict_row)
        cls.entities = [cls.sql.execute('INSERT INTO systeme."T_Entite"("NomEntite","EmailEntite","ValideEntite") '
            'VALUES(%s,%s,true) RETURNING "IdEntite" id', ['Panier fictif '+uuid.uuid4().hex,
            uuid.uuid4().hex+'@example.invalid']).fetchone()['id'] for _ in range(2)]
        cls.users = [cls.sql.execute('INSERT INTO systeme."T_Utilisateurs" '
            '("NomUser","PrenomUser","EmailUser","MotdepasseUser","ValideUser","SexeUser","Is_Admin","Is_staff","IdEntiteFk") '
            'VALUES(\'Panier\',\'Fictif\',%s,\'inutilisable\',true,\'M\',true,true,%s) RETURNING *',
            [uuid.uuid4().hex+'@example.invalid', owner]).fetchone() for owner in cls.entities]
        cls.article_refs = {field: reference_options(cls.actor(), 'logistique', 'T_Article', field)[0]['id']
            for field in ('ID_CategorieArticleFk', 'ID_TypeArticleFk', 'ID_UniteFk', 'ID_DeviseFk')}
        cls.tiers_type = reference_options(cls.actor(), 'logistique', 'T_Client', 'ID_TypeClientFk')[0]['id']
        cls.asset_type = reference_options(cls.actor(), 'logistique', 'T_Immobilisation', 'ID_CategorieFk')[0]['id']

    @classmethod
    def tearDownClass(cls):
        cls.sql.close()
        cls.settings.disable()
        cls.media.cleanup()

    @classmethod
    def actor(cls, entity=0, *, allowed=True, global_admin=True):
        actor = Actor({**cls.users[entity], 'Is_Admin': global_admin, 'Is_staff': allowed})
        if global_admin:
            actor._context_entity = cls.entities[entity]
        actor._module_access = {'modules': {'logistique': {'canRead': True, 'canManage': allowed,
            'canExport': allowed, 'reason': 'MODULE_ROLE_FORBIDDEN'}}}
        return actor

    @classmethod
    def client(cls, entity=0, **kwargs):
        client = APIClient()
        client.force_authenticate(cls.actor(entity, **kwargs))
        return client

    def setUp(self):
        self.tx = None if self._testMethodName == 'test_14_concurrent_replay_creates_exactly_one_batch' else transaction.atomic()
        if self.tx:
            self.tx.__enter__()
        self.before_files = set(Path(self.media.name).rglob('*.jpg'))

    def tearDown(self):
        if self.tx:
            transaction.set_rollback(True)
            self.tx.__exit__(None, None, None)
        # La transaction de recette ne doit pas laisser de médias fictifs.
        for path in set(Path(self.media.name).rglob('*.jpg')) - self.before_files:
            path.unlink()

    def row(self, kind, **changes):
        if kind == 'articles':
            data = {**self.article_refs, 'NomArticle': 'Article fictif '+uuid.uuid4().hex,
                    'QteArticle': '2', 'PUArticle': '10', 'PVArticle': '15', 'ValideArticle': True}
        elif kind == 'tiers':
            data = {'Nom': 'Tiers fictif '+uuid.uuid4().hex, 'Nature': 'personne',
                    'ID_TypeClientFk': self.tiers_type, 'Actif': True}
        else:
            data = {'NomImmobilisation': 'Bien fictif '+uuid.uuid4().hex,
                    'ID_CategorieFk': self.asset_type, 'DateEntree': '2026-10-30T12:00:00+01:00',
                    'Quantite': '1', 'SuiviIndividuel': True, 'PrixUnitaire': '10',
                    'ID_DeviseFk': self.article_refs['ID_DeviseFk'], 'motif': 'Recette privée de panier'}
        return {'clientRowId': uuid.uuid4().hex, 'data': {**data, **changes}}

    def body(self, kind, n=2, **changes):
        return {'requestId': str(uuid.uuid4()), 'rows': [self.row(kind, **changes) for _ in range(n)]}

    def post(self, kind, body=None, **kwargs):
        return self.client(**kwargs).post(BASE+kind, body or self.body(kind), format='json')

    def counts(self):
        tables = ['logistique.T_Article', 'logistique.T_Client', 'logistique.T_Immobilisation',
                  'logistique.T_Commande', 'logistique.T_CommandeDetail', 'logistique.T_Mouvement',
                  'logistique.T_LotArticle', 'systeme.T_Audit_Log']
        return {table: db.one('SELECT count(*) n FROM '+'.'.join(db.ident(part) for part in table.split('.')))['n'] for table in tables}

    def test_01_each_kind_one_and_multiple(self):
        for kind in batch_creation.TABLES:
            for count in (1, 3):
                with self.subTest(kind=kind, count=count):
                    body = self.body(kind, count)
                    result = self.post(kind, body)
                    self.assertEqual(result.status_code, 201, result.data)
                    self.assertEqual(result.data['data']['count'], count)
                    self.assertFalse(result.data['meta']['replayed'])
                    self.assertEqual([row['clientRowId'] for row in result.data['data']['records']],
                                     [row['clientRowId'] for row in body['rows']])
                    self.assertTrue(all(row['IdEntiteFk'] == self.entities[0] for row in result.data['data']['records']))

    def test_02_replay_and_conflicts_do_not_duplicate(self):
        names = {'tiers': 'Nom', 'articles': 'NomArticle', 'immobilisations': 'NomImmobilisation'}
        for kind in batch_creation.TABLES:
            with self.subTest(kind=kind):
                body = self.body(kind)
                first = self.post(kind, body)
                self.assertEqual(first.status_code, 201, first.data)
                before = self.counts()
                replay = self.post(kind, body)
                self.assertEqual(replay.status_code, 200, replay.data)
                self.assertTrue(replay.data['meta']['replayed'])
                self.assertEqual(first.json()['data'], replay.json()['data'])
                self.assertEqual(self.counts(), before)
                body['rows'][0]['data'][names[kind]] += ' modifié'
                self.assertEqual(self.post(kind, body).status_code, 409)
                self.assertEqual(self.counts(), before)

    def test_03_failed_later_line_rolls_back_every_business_and_audit_row(self):
        invalid = {'tiers': {'Nom': ''}, 'articles': {'PUArticle': '-1'},
                   'immobilisations': {'Quantite': '0'}}
        for kind in batch_creation.TABLES:
            with self.subTest(kind=kind):
                body = self.body(kind)
                body['rows'][1]['data'].update(invalid[kind])
                before = self.counts()
                response = self.post(kind, body)
                self.assertEqual(response.status_code, 422, response.data)
                self.assertIn(body['rows'][1]['clientRowId'], response.data['error']['details']['rows'])
                self.assertEqual(self.counts(), before)

    def test_04_permission_readonly_and_missing_entity(self):
        for kind in batch_creation.TABLES:
            with self.subTest(kind=kind):
                self.assertIn(APIClient().post(BASE+kind, self.body(kind), format='json').status_code, (401, 403))
                self.assertEqual(self.post(kind, allowed=False, global_admin=False).status_code, 403)
                with override_settings(DB_READ_ONLY=True):
                    self.assertEqual(self.post(kind).status_code, 503)
                actor = self.actor()
                del actor._context_entity
                client = APIClient(); client.force_authenticate(actor)
                self.assertEqual(client.post(BASE+kind, self.body(kind), format='json').status_code, 409)

    def test_05_owner_revision_request_forgeries_refused(self):
        for kind in batch_creation.TABLES:
            for field in ('IdEntiteFk', '_version', 'requestId'):
                with self.subTest(kind=kind, field=field):
                    before = self.counts()
                    body = self.body(kind, 1, **{field: self.entities[1]})
                    response = self.post(kind, body)
                    self.assertEqual(response.status_code, 422, response.data)
                    self.assertEqual(self.counts(), before)

    def test_06_request_and_line_shapes(self):
        bodies = [{'requestId': 'no', 'rows': [self.row('tiers')]},
                  {'requestId': str(uuid.uuid4()), 'rows': []},
                  {'requestId': str(uuid.uuid4()), 'rows': [self.row('tiers') for _ in range(101)]},
                  {'requestId': str(uuid.uuid4()), 'rows': [{'clientRowId': '../escape', 'data': {}}]}]
        row = self.row('tiers')
        bodies.append({'requestId': str(uuid.uuid4()), 'rows': [row, row]})
        for body in bodies:
            with self.subTest(body=str(body)[:60]):
                self.assertIn(self.post('tiers', body).status_code, (400, 422))

    def test_07_initial_stock_uses_one_movement_and_lots_are_atomic(self):
        body = self.body('articles', 1)
        body['rows'][0]['data']['LotsInitiaux'] = [{'NumeroLot': 'LOT-FICTIF-'+uuid.uuid4().hex,
                                                  'Quantite': '2'}]
        response = self.post('articles', body)
        self.assertEqual(response.status_code, 201, response.data)
        row = response.data['data']['records'][0]
        movements = db.query('SELECT * FROM logistique."T_Mouvement" WHERE "ID_ArticleFk"=%s', [row['ID_Article']])
        self.assertEqual(len(movements), 1)
        self.assertEqual(row['QteArticle'], 2)
        self.assertIsNotNone(movements[0]['ID_cmdFk'])
        self.assertEqual(db.one('SELECT count(*) n FROM logistique."T_LotArticle" WHERE "ID_ArticleFk"=%s', [row['ID_Article']])['n'], 1)

    def photo(self):
        stream = io.BytesIO()
        Image.new('RGB', (8, 8), 'blue').save(stream, format='PNG')
        return SimpleUploadedFile('fictive.png', stream.getvalue(), content_type='image/png')

    def multipart(self, body, files):
        return self.client().post(BASE+'articles', {'payload': json.dumps(body), **files}, format='multipart')

    def test_08_photos_saved_and_replay_does_not_recreate_files(self):
        body = self.body('articles', 1)
        key = 'photo_' + body['rows'][0]['clientRowId']
        response = self.multipart(body, {key: self.photo()})
        self.assertEqual(response.status_code, 201, response.data)
        files = set(Path(self.media.name).rglob('*.jpg'))
        self.assertEqual(len(files-self.before_files), 1)
        replay = self.multipart(body, {key: self.photo()})
        self.assertEqual(replay.status_code, 200, replay.data)
        self.assertEqual(set(Path(self.media.name).rglob('*.jpg')), files)
        changed = SimpleUploadedFile('other.png', b'other content', content_type='image/png')
        self.assertEqual(self.multipart(body, {key: changed}).status_code, 409)

    def test_09_photo_compensation_after_later_validation_failure(self):
        body = self.body('articles')
        body['rows'][1]['data']['PUArticle'] = '-1'
        before = self.counts()
        response = self.multipart(body, {'photo_'+body['rows'][0]['clientRowId']: self.photo()})
        self.assertEqual(response.status_code, 422, response.data)
        self.assertEqual(self.counts(), before)
        self.assertEqual(set(Path(self.media.name).rglob('*.jpg')), self.before_files)

    def test_10_photo_compensation_after_outer_audit_failure(self):
        body = self.body('articles', 1)
        client = self.client(); client.raise_request_exception = False
        before = self.counts()
        with patch('apps.logistique.batch_creation.audit', side_effect=RuntimeError('Échec simulé audit')):
            response = client.post(BASE+'articles', {'payload': json.dumps(body),
                'photo_'+body['rows'][0]['clientRowId']: self.photo()}, format='multipart')
        self.assertEqual(response.status_code, 500)
        self.assertEqual(self.counts(), before)
        self.assertEqual(set(Path(self.media.name).rglob('*.jpg')), self.before_files)

    def test_11_unknown_file_empty_file_invalid_photo(self):
        body = self.body('articles', 1)
        key = 'photo_' + body['rows'][0]['clientRowId']
        self.assertEqual(self.multipart(body, {'photo_wrong': self.photo()}).status_code, 400)
        for upload in (SimpleUploadedFile('empty.png', b'', content_type='image/png'),
                       SimpleUploadedFile('bad.png', b'not a photo', content_type='image/png')):
            response = self.multipart(body, {key: upload})
            self.assertEqual(response.status_code, 422, response.data)
            self.assertIn('photo', response.data['error']['details']['rows'][body['rows'][0]['clientRowId']])

    def test_12_asset_assignment_is_historized_without_stock(self):
        body = self.body('immobilisations', 2, ID_ResponsableFk=self.users[0]['IdUser'])
        before = self.counts()
        response = self.post('immobilisations', body)
        self.assertEqual(response.status_code, 201, response.data)
        after = self.counts()
        self.assertEqual(after['logistique.T_Mouvement'], before['logistique.T_Mouvement'])
        self.assertEqual(after['logistique.T_Article'], before['logistique.T_Article'])
        for row in response.data['data']['records']:
            self.assertEqual(row['ValeurAcquisition'], 10)
            self.assertEqual(row['ID_ResponsableFk'], self.users[0]['IdUser'])
            self.assertTrue(row['CodeImmobilisation'])

    def test_13_lengths_numeric_overflow_and_upload_limits_are_targeted(self):
        for kind, field, value in [('tiers', 'Nom', 'X'*5000), ('articles', 'PUArticle', '1e100')]:
            before = self.counts()
            body = self.body(kind, 2)
            body['rows'][1]['data'][field] = value
            response = self.post(kind, body)
            self.assertEqual(response.status_code, 422, response.data)
            self.assertIn(body['rows'][1]['clientRowId'], response.data['error']['details']['rows'])
            self.assertEqual(self.counts(), before)
        from apps.core.responses import APIError
        upload = self.photo(); upload.size = 33*1024*1024
        body = self.body('articles', 1)
        with self.assertRaises(APIError) as failure:
            batch_creation.save_batch(self.actor(), 'articles', body, {'photo_'+body['rows'][0]['clientRowId']: upload})
        self.assertEqual(failure.exception.status_code, 422)
        self.assertIn('photos', failure.exception.detail['header'])

    def test_14_concurrent_replay_creates_exactly_one_batch(self):
        for kind in ('tiers', 'articles', 'immobilisations'):
            body = self.body(kind, 2)
            table = 'logistique.' + batch_creation.TABLES[kind]
            before = self.counts()
            def submit():
                try:
                    response = self.post(kind, body)
                    return response.status_code, response.json()
                finally:
                    connections.close_all()
            with ThreadPoolExecutor(max_workers=2) as pool:
                results = list(pool.map(lambda _: submit(), range(2)))
            self.assertEqual(sorted(status for status, _ in results), [200, 201], results)
            self.assertEqual(results[0][1]['data'], results[1][1]['data'])
            self.assertEqual(self.counts()[table], before[table]+2)

    def test_15_tiers_individual_creation_replay_update_and_archive_remain_supported(self):
        client = self.client()
        body = {**self.row('tiers')['data'], 'requestId': str(uuid.uuid4())}
        first = client.post('/api/logistique/tiers', body, format='json')
        self.assertEqual(first.status_code, 201, first.data)
        key = first.data['data']['ID_Client']
        before = self.counts()
        replay = client.post('/api/logistique/tiers', body, format='json')
        self.assertEqual(replay.status_code, 200, replay.data)
        self.assertEqual(replay.data['data']['ID_Client'], key)
        self.assertEqual(self.counts(), before)
        modified = client.patch('/api/logistique/tiers/'+str(key),
            {'_version': replay.data['meta']['revision'], 'Telephone': '+243810000000'}, format='json')
        self.assertEqual(modified.status_code, 200, modified.data)
        self.assertEqual(modified.data['data']['Telephone'], '+243810000000')
        archived = client.delete('/api/logistique/tiers/'+str(key),
            {'_version': modified.data['meta']['revision']}, format='json')
        self.assertEqual(archived.status_code, 200, archived.data)
        self.assertFalse(archived.data['data']['Actif'])

    def test_16_upper_limit_100_tiers_accepts_one_transaction_and_replay(self):
        body = self.body('tiers', 100)
        before = self.counts()
        first = self.post('tiers', body)
        self.assertEqual(first.status_code, 201, first.data)
        self.assertEqual(first.data['data']['count'], 100)
        self.assertEqual(len({row['ID_Client'] for row in first.data['data']['records']}), 100)
        self.assertEqual(self.counts()['logistique.T_Client'], before['logistique.T_Client']+100)
        after = self.counts()
        replay = self.post('tiers', body)
        self.assertEqual(replay.status_code, 200, replay.data)
        self.assertEqual(first.json()['data'], replay.json()['data'])
        self.assertEqual(self.counts(), after)

    def test_17_local_manager_own_company_and_foreign_relations(self):
        for kind in batch_creation.TABLES:
            with self.subTest(kind=kind):
                response = self.post(kind, self.body(kind, 1), global_admin=False)
                self.assertEqual(response.status_code, 201, response.data)
                self.assertEqual(response.data['data']['records'][0]['IdEntiteFk'], self.entities[0])
        for kind, field in [('tiers', 'IdUserFk'), ('immobilisations', 'ID_ResponsableFk')]:
            before = self.counts()
            response = self.post(kind, self.body(kind, 1, **{field: self.users[1]['IdUser']}), global_admin=False)
            self.assertEqual(response.status_code, 422, response.data)
            self.assertEqual(self.counts(), before)


    def test_18_opening_receipt_creates_one_entry_and_replays(self):
        body = self.body('articles', 3)
        body['openingReceipt'] = True
        body['rows'][0]['data']['LotsInitiaux'] = [
            {'NumeroLot': 'LOT-A', 'Quantite': '1', 'DatePeremptionLot': '2030-01-01'},
            {'NumeroLot': 'LOT-B', 'Quantite': '1'},
        ]
        body['rows'][1]['data'].update(QteArticle='3', PUArticle='0')
        body['rows'][2]['data']['QteArticle'] = '0'
        before = self.counts()
        first = self.post('articles', body)
        self.assertEqual(first.status_code, 201, first.data)
        result = first.data['data']
        receipt = result['openingReceipt']
        self.assertTrue(receipt['code'].startswith('BE-'), receipt)
        records = result['records']
        self.assertEqual([row['QteArticle'] for row in records], [2, 3, 0])
        article_ids = [row['ID_Article'] for row in records]
        self.assertTrue(all(row['IdEntiteFk'] == self.entities[0] for row in records))
        command = db.one('SELECT "IdEntiteFk","ID_DeviseFk",logistique.fn_nature_bon("ID_TypeCmdFk") AS kind '
                         'FROM logistique."T_Commande" WHERE "ID_Commande"=%s', [receipt['id']])
        self.assertEqual(command, {'IdEntiteFk': self.entities[0],
            'ID_DeviseFk': self.article_refs['ID_DeviseFk'], 'kind': 'entree'})
        movements = db.query('SELECT "ID_ArticleFk","QteMvt","PUMvt","SigneStock" '
            'FROM logistique."V_MouvementStock" WHERE "ID_cmdFk"=%s ORDER BY "ID_ArticleFk"', [receipt['id']])
        self.assertEqual([(row['ID_ArticleFk'], row['QteMvt'], row['PUMvt'], row['SigneStock']) for row in movements],
                         [(article_ids[0], 2, 10, 1), (article_ids[1], 3, 0, 1)])
        after = self.counts()
        for table, increase in [('T_Article', 3), ('T_Commande', 1), ('T_CommandeDetail', 2),
                                ('T_Mouvement', 2), ('T_LotArticle', 2)]:
            self.assertEqual(after['logistique.'+table] - before['logistique.'+table], increase, table)
        replay = self.post('articles', body)
        self.assertEqual(replay.status_code, 200, replay.data)
        self.assertEqual(first.json()['data'], replay.json()['data'])
        self.assertEqual(self.counts(), after)

    def test_19_invalid_opening_receipts_roll_back_articles_and_stock(self):
        alternate_currency = next(item['id'] for item in reference_options(
            self.actor(), 'logistique', 'T_Article', 'ID_DeviseFk')
            if item['id'] != self.article_refs['ID_DeviseFk'])
        cases = [
            ({'LotsInitiaux': [{'NumeroLot': 'LOT-A', 'Quantite': '1'}]}, 'LotsInitiaux'),
            ({'ID_DeviseFk': alternate_currency}, 'ID_DeviseFk'),
            ({'PUArticle': ''}, 'PUArticle'),
            ({'QteArticle': None}, 'QteArticle'),
        ]
        for changes, field in cases:
            with self.subTest(field=field):
                body = self.body('articles')
                body['openingReceipt'] = True
                body['rows'][1]['data'].update(changes)
                before = self.counts()
                response = self.post('articles', body)
                self.assertEqual(response.status_code, 422, response.data)
                errors = response.data['error']['details']['rows'][body['rows'][1]['clientRowId']]
                self.assertIn(field, errors)
                self.assertEqual(self.counts(), before)
        zero = {**self.body('articles', 2, QteArticle='0'), 'openingReceipt': True}
        response = self.post('articles', zero)
        self.assertEqual(response.status_code, 422, response.data)
        self.assertIn('rows', response.data['error']['details']['header'])
        self.assertEqual(self.counts(), before)

    def test_20_import_limits_keep_normal_bon_creation_at_fifty_lines(self):
        body = {**self.body('articles', 515), 'openingReceipt': True}
        for row in body['rows'][-7:]:
            row['data']['QteArticle'] = '0'
        before = self.counts()
        ordinary = self.post('articles', {'requestId': body['requestId'], 'rows': body['rows']})
        self.assertEqual(ordinary.status_code, 422, ordinary.data)
        self.assertEqual(self.counts(), before)
        started = perf_counter()
        response = self.post('articles', body)
        self.assertEqual(response.status_code, 201, response.data)
        result = response.data['data']
        after = self.counts()
        self.assertEqual(result['count'], 515)
        self.assertEqual(after['logistique.T_Article'], before['logistique.T_Article']+515)
        self.assertEqual(after['logistique.T_Commande'], before['logistique.T_Commande']+1)
        self.assertEqual(after['logistique.T_CommandeDetail'], before['logistique.T_CommandeDetail']+508)
        self.assertEqual(after['logistique.T_Mouvement'], before['logistique.T_Mouvement']+508)
        proof = db.one('SELECT pg_column_size("NewData") AS bytes FROM systeme."T_Audit_Log" '
            'WHERE "Operation"=%s AND jsonb_extract_path_text("NewData",%s)=%s',
            ['LOGISTICS_BATCH_CREATE', 'requestId', body['requestId']])
        print(f"Panier 515 articles / 508 mouvements en {perf_counter()-started:.2f}s, "
              f"réponse {len(response.content)} octets, preuve JSONB {proof['bytes']} octets.", flush=True)
        from apps.logistique.receipts import entry_type
        order = self.client().post('/api/logistique/commandes/composees', {
            'requestId': str(uuid.uuid4()),
            'bon': {'ID_TypeCmdFk': entry_type(actor=self.actor())['id'],
                'ID_DeviseFk': self.article_refs['ID_DeviseFk'], 'DateCmd': '2026-10-30T12:00:00+01:00'},
            'lignes': [{'ID_ArticleFk': article['ID_Article'], 'QteCmdDetail': '1', 'PUCmdDetail': '10'}
                       for article in result['records'][:51]],
        }, format='json')
        self.assertEqual(order.status_code, 400, order.data)
        self.assertIn('50', order.data['error']['details']['lignes'])
        self.assertEqual(self.counts(), after)
        client = self.client()
        url = f"/api/logistique/commandes/{result['openingReceipt']['id']}/composition"
        read = client.get(url)
        self.assertEqual(read.status_code, 200, read.data)
        lines = read.data['data']['lignes']
        self.assertEqual(len(lines), 508)
        self.assertEqual(read.data['meta']['maxLines'], 508)
        edited = client.put(url, {
            'requestId': str(uuid.uuid4()),
            '_version': read.data['meta']['revision'],
            'bon': {'ObsCmd': 'Recette de modification du bon d’ouverture'},
            'lignes': [{key: str(line[key]) if key in ('QteCmdDetail', 'PUCmdDetail') else line[key]
                        for key in ('ID_ArticleFk', 'QteCmdDetail', 'PUCmdDetail')}
                       for line in lines],
        }, format='json')
        self.assertEqual(edited.status_code, 200, edited.data)
        self.assertEqual(len(edited.data['data']['lignes']), 508)
        self.assertEqual(self.counts()['logistique.T_Mouvement'], after['logistique.T_Mouvement'])


if __name__ == '__main__':
    result = unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(LogisticsBatchAPI))
    (ROOT/'.runtime/logistique-batch-api.json').write_text(json.dumps({'passed': result.wasSuccessful(),
        'tests': result.testsRun, 'failures': len(result.failures), 'errors': len(result.errors),
        'database': target.path[1:], 'media': 'Répertoire temporaire de recette uniquement'}, ensure_ascii=False, indent=2), encoding='utf8')
    sys.exit(0 if result.wasSuccessful() else 1)
