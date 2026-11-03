"""Publication volontaire : vraies API et licences, PostgreSQL privé obligatoire.

La recette crée exclusivement des sociétés et comptes fictifs. Elle n'installe
pas la migration et ne peut s'exécuter que sur sauverndeko_test_* en local.
"""
import io
import json
import os
import sys
import tempfile
import unittest
import uuid
from decimal import Decimal
from pathlib import Path
from urllib.parse import urlsplit

import psycopg
from psycopg.rows import dict_row
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
DSN = os.environ.get('SAUVERNDEKO_TEST_DATABASE_URL', '')
location = urlsplit(DSN)
if location.hostname not in {'localhost', '127.0.0.1', '::1'} or not location.path[1:].startswith('sauverndeko_test_'):
    raise RuntimeError('Une base PostgreSQL privée locale sauverndeko_test_* est obligatoire.')
with psycopg.connect(DSN) as guard:
    if not guard.execute('SELECT current_database()').fetchone()[0].startswith('sauverndeko_test_'):
        raise RuntimeError('Recette refusée hors base privée.')
os.environ.update(DATABASE_URL=DSN, DJANGO_SETTINGS_MODULE='config.settings', SAUVERNDEKO_DB_READ_ONLY='0')
sys.path.insert(0, str(ROOT / 'backend'))
import django
django.setup()
from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import override_settings
from rest_framework.test import APIClient
from apps.accounts.authentication import actor_by_id
from apps.core import repository
from apps.core.responses import APIError
from apps.logistique import entity_documents


class ArticlePublicationAPI(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.files = tempfile.TemporaryDirectory(prefix='sauverndeko-publication-')
        cls.settings = override_settings(ALLOWED_HOSTS=['testserver'], MEDIA_ROOT=cls.files.name)
        cls.settings.enable()
        cls.connection = psycopg.connect(DSN, autocommit=True, row_factory=dict_row)
        cls.references = {}
        for column in ('ID_TypeArticleFk', 'ID_CategorieArticleFk', 'ID_UniteFk', 'ID_DeviseFk'):
            row = cls.connection.execute('''SELECT g."ID_Generique" id FROM referentiel."T_Generique" g
                WHERE g."ID_CategorieGeneriqueFk"=ANY(referentiel.fn_categories_champ('logistique','T_Article',%s,NULL))
                  AND g."ValideGenerique" IS TRUE AND g."IdEntiteFk" IS NULL
                ORDER BY CASE WHEN g."AbrGenerique" IN ('pcs','USD') THEN 0 ELSE 1 END,g."ID_Generique" LIMIT 1''', [column]).fetchone()
            if not row:
                raise RuntimeError('Référence commune requise pour la recette : ' + column)
            cls.references[column] = row['id']
        cls.licence_status = cls.connection.execute('''SELECT g."ID_Generique" id
            FROM referentiel."T_Generique" g JOIN referentiel."T_CategorieGenerique" c
              ON c."ID_CategorieGenerique"=g."ID_CategorieGeneriqueFk"
            WHERE lower(c."NomCategorieGenerique")='statut licence'
              AND lower(g."NomGenerique") IN ('active','actif') AND g."ValideGenerique" IS TRUE
            ORDER BY g."ID_Generique" LIMIT 1''').fetchone()['id']

    @classmethod
    def tearDownClass(cls):
        cls.connection.close()
        cls.settings.disable()
        cls.files.cleanup()

    def setUp(self):
        self.tag = 'publication-' + uuid.uuid4().hex
        self.entities = []
        self.locals = []
        for index in range(3):
            entity = self.connection.execute('''INSERT INTO systeme."T_Entite"
                ("NomEntite","EmailEntite","AdresseEntite","PhoneEntite","ValideEntite")
                VALUES (%s,%s,'Adresse publique fictive',%s,true) RETURNING "IdEntite" id''',
                [self.tag + '-societe-' + str(index), self.tag + '-' + str(index) + '@example.invalid',
                 '+243' + str(uuid.uuid4().int)[:12]]).fetchone()['id']
            self.entities.append(entity)
            user = self.connection.execute('''INSERT INTO systeme."T_Utilisateurs"
                ("NomUser","PrenomUser","EmailUser","MotdepasseUser","ValideUser","SexeUser","Is_Admin","Is_staff","IdEntiteFk")
                VALUES ('Fictif','Publication',%s,'inutilisable',true,'M',false,true,%s) RETURNING "IdUser" id''',
                [self.tag + '-local-' + str(index) + '@example.invalid', entity]).fetchone()['id']
            self.locals.append(user)
            if index < 2:
                licence = self.connection.execute('''INSERT INTO systeme."T_Licence"
                    ("IdEntiteFk","DateDebut","DateFin","ValideLicence","IdStatutLicenceFk")
                    VALUES (%s,LOCALTIMESTAMP-interval '1 day',LOCALTIMESTAMP+interval '1 year',true,%s)
                    RETURNING "IdLicence" id''', [entity, self.licence_status]).fetchone()['id']
                for module in ('logistique', 'catalogue'):
                    self.connection.execute('''INSERT INTO systeme."T_LicenceModule"
                        ("IdLicenceFk","CodeModule","Actif") VALUES (%s,%s,true)''', [licence, module])
        self.global_user = self.connection.execute('''INSERT INTO systeme."T_Utilisateurs"
            ("NomUser","PrenomUser","EmailUser","MotdepasseUser","ValideUser","SexeUser","Is_Admin","Is_staff","IdEntiteFk")
            VALUES ('Fictif','Global',%s,'inutilisable',true,'M',true,true,%s) RETURNING "IdUser" id''',
            [self.tag + '-global@example.invalid', self.entities[0]]).fetchone()['id']

    def actor(self, index=0, *, local=False, all_entities=False):
        actor = actor_by_id(self.locals[index] if local else self.global_user)
        if not local and not all_entities:
            actor._context_entity = self.entities[index]
        return actor

    def client(self, index=0, **rights):
        client = APIClient()
        client.force_authenticate(self.actor(index, **rights))
        return client

    def data(self, response, expected=200):
        self.assertEqual(response.status_code, expected, getattr(response, 'data', 'Réponse binaire'))
        return response.json().get('data')

    def body(self, **changes):
        return {**self.references, 'NomArticle': self.tag + '-article-' + uuid.uuid4().hex,
            'PUArticle': '12.50', 'PVArticle': '15.75', 'QteArticle': '2', 'QteMinArticle': '0',
            'RefArticle': 'REF-' + uuid.uuid4().hex,
            'ObsArticle': 'NOTE_INTERNE_' + self.tag, 'InformationArticle': 'CONFIDENTIEL_' + self.tag,
            'ValideArticle': True, 'requestId': str(uuid.uuid4()), **changes}

    def create(self, index=0, **changes):
        body = self.body(**changes)
        return self.data(self.client(index).post('/api/logistique/articles', body, format='json'), 201)

    def get_article(self, pk, index=0, **rights):
        response = self.client(index, **rights).get(f'/api/logistique/articles/{pk}')
        return self.data(response), response.data.get('meta', {})

    def company_body(self, index=0, **changes):
        profile = entity_documents.profile(self.actor(index), self.entities[index], administration=True)
        result = {key: profile.get(key) for key in entity_documents.FIELDS | entity_documents.ADMIN_FIELDS}
        result.update(IdEntite=self.entities[index], _version=profile['_version'], motif='Recette fictive de publication', requestId=str(uuid.uuid4()))
        result.update(changes)
        return result

    def set_default(self, value, index=0):
        return self.data(self.client(index).put(f'/api/systeme/entites/{self.entities[index]}',
            self.company_body(index, PartageArticlesPublicParDefaut=value), format='json'))

    def public(self, query=None, index=0, **rights):
        response = self.client(index, **rights).get('/api/public/articles', query or {'q': self.tag})
        return self.data(response), response.data.get('meta', {})

    def stock_proof(self, pk):
        return self.connection.execute('''SELECT a."QteArticle",a."PUArticle",a."PVArticle",
            (SELECT count(*) FROM logistique."T_Mouvement" m WHERE m."ID_ArticleFk"=a."ID_Article") mouvements,
            (SELECT count(*) FROM logistique."T_CommandeDetail" d WHERE d."ID_ArticleFk"=a."ID_Article") lignes
            FROM logistique."T_Article" a WHERE a."ID_Article"=%s''', [pk]).fetchone()

    def test_01_company_default_and_individual_overrides(self):
        defaults = self.data(self.client().get('/api/systeme/entites/identite-defaut'))
        self.assertIs(defaults['PartageArticlesPublicParDefaut'], True)
        self.assertIs(self.data(self.client().get('/api/logistique/references'))['defaultArticleVisibility'], True)
        self.assertIsNone(self.data(self.client(all_entities=True).get('/api/logistique/references'))['defaultArticleVisibility'])
        first = self.create()
        self.assertIs(first['VisibleCatalogue'], True)
        self.set_default(False)
        self.assertIs(self.data(self.client().get('/api/logistique/references'))['defaultArticleVisibility'], False)
        inherited = self.create()
        explicit = self.create(VisibleCatalogue=True)
        private = self.create(VisibleCatalogue=False)
        self.assertIs(inherited['VisibleCatalogue'], False)
        self.assertIs(explicit['VisibleCatalogue'], True)
        self.assertIs(private['VisibleCatalogue'], False)
        self.assertIs(self.get_article(first['ID_Article'])[0]['VisibleCatalogue'], True)
        self.assertEqual({row['ID_Article'] for row in self.public()[0]}, {first['ID_Article'], explicit['ID_Article']})

    def test_02_private_projection_real_currency_search_and_pagination(self):
        article = self.create(VisibleCatalogue=True)
        self.create(VisibleCatalogue=False)
        rows, meta = self.public({'q': self.tag, 'take': 1, 'skip': 0}, local=True)
        self.assertEqual(meta['total'], 1)
        self.assertEqual(meta['count'], 1)
        row = rows[0]
        self.assertEqual(set(row), {'ID_Article','NomArticle','RefArticle','PVArticle','DeviseCode','DeviseLibelle',
            'Unite','EtatDisponibilite','IdEntite','NomEntite','AdresseEntite','PhoneEntite','PhotoArticle'})
        self.assertEqual(row['ID_Article'], article['ID_Article'])
        self.assertEqual(row['EtatDisponibilite'], 'Stock déclaré')
        self.assertEqual(row['DeviseCode'], 'USD')
        self.assertEqual(Decimal(str(row['PVArticle'])), Decimal('15.75'))
        self.assertIsNone(row['PhotoArticle'])
        self.assertEqual(self.public({'q': 'CONFIDENTIEL_' + self.tag})[1]['total'], 0)
        self.assertEqual(self.public({'q': 'NOTE_INTERNE_' + self.tag})[1]['total'], 0)
        self.assertEqual(self.public({'q': self.tag, 'take': 1, 'skip': 1})[0], [])
        self.assertEqual(self.public({'q': row['RefArticle']})[0][0]['ID_Article'], article['ID_Article'])

    def test_03_publication_revision_and_stock_history_preserved(self):
        article = self.create(VisibleCatalogue=True)
        pk = article['ID_Article']
        record, meta = self.get_article(pk)
        proof = self.stock_proof(pk)
        self.assertEqual(proof['mouvements'], 1)
        result = self.data(self.client().put(f'/api/logistique/articles/{pk}',
            {'VisibleCatalogue': False, '_version': meta['revision']}, format='json'))
        self.assertIs(result['VisibleCatalogue'], False)
        self.assertEqual(self.public()[1]['total'], 0)
        self.assertEqual(self.stock_proof(pk), proof)
        changed, revision = self.get_article(pk)
        self.assertNotEqual(meta['revision'], revision['revision'])
        self.data(self.client().put(f'/api/logistique/articles/{pk}',
            {'VisibleCatalogue': True, '_version': meta['revision']}, format='json'), 409)
        self.assertIs(self.get_article(pk)[0]['VisibleCatalogue'], False)
        self.assertEqual(self.stock_proof(pk), proof)

    def test_04_creation_replay_includes_choice_without_duplicate_movement(self):
        body = self.body(VisibleCatalogue=False)
        first = self.data(self.client().post('/api/logistique/articles', body, format='json'), 201)
        proof = self.stock_proof(first['ID_Article'])
        replay = self.data(self.client().post('/api/logistique/articles', body, format='json'), 201)
        self.assertEqual(first['ID_Article'], replay['ID_Article'])
        self.assertEqual(self.stock_proof(first['ID_Article']), proof)
        self.data(self.client().post('/api/logistique/articles', {**body, 'VisibleCatalogue': True}, format='json'), 409)
        self.assertIs(self.get_article(first['ID_Article'])[0]['VisibleCatalogue'], False)

    def test_05_atomic_batch_inheritance_overrides_and_replay(self):
        self.set_default(False)
        row = self.body(); row.pop('requestId')
        explicit = self.body(VisibleCatalogue=True); explicit.pop('requestId')
        body = {'requestId': str(uuid.uuid4()), 'rows': [{'clientRowId': 'a', 'data': row}, {'clientRowId': 'b', 'data': explicit}]}
        result = self.data(self.client().post('/api/logistique/saisie-multiple/articles', body, format='json'), 201)
        self.assertEqual(result['count'], 2)
        self.assertEqual([record['VisibleCatalogue'] for record in result['records']], [False, True])
        proofs = [self.stock_proof(record['ID_Article']) for record in result['records']]
        response = self.client().post('/api/logistique/saisie-multiple/articles', body, format='json')
        replay = self.data(response)
        self.assertTrue(response.data['meta']['replayed'])
        self.assertEqual(result, replay)
        self.assertEqual([self.stock_proof(record['ID_Article']) for record in result['records']], proofs)
        changed = json.loads(json.dumps(body)); changed['rows'][0]['data']['VisibleCatalogue'] = True
        self.data(self.client().post('/api/logistique/saisie-multiple/articles', changed, format='json'), 409)
        invalid = self.body(VisibleCatalogue=True); invalid.pop('requestId')
        bad = {'requestId': str(uuid.uuid4()), 'rows': [{'clientRowId': 'valid', 'data': invalid},
            {'clientRowId': 'invalid', 'data': {**invalid, 'NomArticle': ''}}]}
        self.data(self.client().post('/api/logistique/saisie-multiple/articles', bad, format='json'), 422)
        self.assertEqual(self.connection.execute('SELECT count(*) n FROM logistique."T_Article" WHERE "NomArticle"=%s', [invalid['NomArticle']]).fetchone()['n'], 0)

    def test_06_company_replay_version_validation_and_no_retroactive_change(self):
        article = self.create(VisibleCatalogue=True)
        proof = self.stock_proof(article['ID_Article'])
        body = self.company_body(PartageArticlesPublicParDefaut=False)
        path = f'/api/systeme/entites/{self.entities[0]}'
        changed = self.data(self.client().put(path, body, format='json'))
        self.assertIs(changed['PartageArticlesPublicParDefaut'], False)
        response = self.client().put(path, body, format='json')
        self.data(response)
        self.assertTrue(response.data['meta']['replayed'])
        self.data(self.client().put(path, {**body, 'PartageArticlesPublicParDefaut': True}, format='json'), 409)
        self.data(self.client().put(path, {**body, 'requestId': str(uuid.uuid4())}, format='json'), 409)
        for value in (None, 1, 'true'):
            self.data(self.client().put(path, self.company_body(PartageArticlesPublicParDefaut=value), format='json'), 400)
        legacy = self.company_body(NomEntite=self.tag + '-updated')
        legacy.pop('PartageArticlesPublicParDefaut')
        self.assertIs(self.data(self.client().put(path, legacy, format='json'))['PartageArticlesPublicParDefaut'], False)
        self.assertIs(self.get_article(article['ID_Article'])[0]['VisibleCatalogue'], True)
        self.assertEqual(self.stock_proof(article['ID_Article']), proof)
        self.assertEqual(self.public()[0][0]['NomEntite'], self.tag + '-updated')
        no_reason = self.company_body(PartageArticlesPublicParDefaut=True, motif='')
        self.data(self.client().put(path, no_reason, format='json'), 400)
        with self.assertRaises(APIError) as caught:
            repository.mutate('T_Entite', self.actor(), {'PartageArticlesPublicParDefaut': True}, {'IdEntite': self.entities[0]}, 'update')
        self.assertEqual(caught.exception.status_code, 405)

    def test_07_permissions_licences_and_cross_company_management(self):
        article = self.create(1, VisibleCatalogue=True)
        # Le catalogue partagé est volontaire ; le CRUD de l'autre entreprise reste refusé.
        rows, _ = self.public(index=0, local=True)
        self.assertIn(article['ID_Article'], {row['ID_Article'] for row in rows})
        self.data(self.client(0, local=True).get(f'/api/logistique/articles/{article["ID_Article"]}'), 404)
        _, revision = self.get_article(article['ID_Article'], index=1)
        self.data(self.client(0, local=True).put(f'/api/logistique/articles/{article["ID_Article"]}',
            {'VisibleCatalogue': False, '_version': revision['revision']}, format='json'), 404)
        self.data(self.client(0, local=True).put(f'/api/systeme/entites/{self.entities[1]}',
            self.company_body(1, PartageArticlesPublicParDefaut=False), format='json'), 404)
        self.data(self.client(2, local=True).get('/api/public/articles'), 403)
        self.data(APIClient().get('/api/public/articles'), 401)
        self.data(APIClient().get('/api/public/stats'), 401)
        self.assertIs(self.get_article(article['ID_Article'], index=1)[0]['VisibleCatalogue'], True)

    def test_08_public_photo_uses_same_publication_and_licence_guards(self):
        stream = io.BytesIO(); Image.new('RGB', (32, 24), (20, 90, 100)).save(stream, format='PNG')
        body = self.body(VisibleCatalogue=True)
        response = self.client().post('/api/logistique/articles', {'payload': json.dumps(body),
            'photo': SimpleUploadedFile('fictif.png', stream.getvalue(), content_type='image/png')}, format='multipart')
        article = self.data(response, 201)
        public = self.public()[0][0]
        self.assertRegex(public['PhotoArticle'], r'^/api/public/articles/[0-9]+/photo\?v=[a-f0-9]{16}$')
        binary = self.client(1, local=True).get(public['PhotoArticle'], HTTP_ACCEPT='image/jpeg')
        self.assertEqual(binary.status_code, 200)
        self.assertEqual(binary['Content-Type'], 'image/jpeg')
        self.assertEqual(binary['Cache-Control'], 'no-store, private')
        self.assertEqual(binary['X-Content-Type-Options'], 'nosniff')
        self.assertTrue(b''.join(binary.streaming_content).startswith(b'\xff\xd8'))
        self.assertEqual(APIClient().get(public['PhotoArticle'], HTTP_ACCEPT='image/jpeg').status_code, 401)
        self.assertEqual(self.client(2, local=True).get(public['PhotoArticle'], HTTP_ACCEPT='image/jpeg').status_code, 403)
        _, meta = self.get_article(article['ID_Article'])
        self.data(self.client().put(f'/api/logistique/articles/{article["ID_Article"]}',
            {'VisibleCatalogue': False, '_version': meta['revision']}, format='json'))
        self.assertEqual(self.client(1, local=True).get(public['PhotoArticle'], HTTP_ACCEPT='image/jpeg').status_code, 404)
        private = self.client().get(f'/api/logistique/articles/{article["ID_Article"]}/photo', HTTP_ACCEPT='image/jpeg')
        self.assertEqual(private.status_code, 200)
        private.close()

    def test_09_zero_stock_inactive_article_and_owner_not_falsely_available(self):
        zero = self.create(VisibleCatalogue=True, QteArticle='0')
        active = self.create(1, VisibleCatalogue=True)
        inactive = self.create(VisibleCatalogue=True, ValideArticle=False, QteArticle='0')
        rows, _ = self.public()
        lookup = {row['ID_Article']: row for row in rows}
        self.assertEqual(lookup[zero['ID_Article']]['EtatDisponibilite'], 'Stock nul déclaré')
        self.assertNotIn(inactive['ID_Article'], lookup)
        self.connection.execute('UPDATE systeme."T_Entite" SET "ValideEntite"=false WHERE "IdEntite"=%s', [self.entities[1]])
        self.assertNotIn(active['ID_Article'], {row['ID_Article'] for row in self.public()[0]})
        self.assertIs(self.connection.execute('SELECT "VisibleCatalogue" FROM logistique."T_Article" WHERE "ID_Article"=%s', [active['ID_Article']]).fetchone()['VisibleCatalogue'], True)

    def test_10_stats_are_observed_counts_and_invalid_choices_do_not_save(self):
        self.create(VisibleCatalogue=True)
        stats = self.data(self.client().get('/api/public/stats'))
        count = self.connection.execute('SELECT count(*) n FROM logistique."V_OffreArticle"').fetchone()['n']
        self.assertEqual(stats['productsCount'], count)
        self.assertIn('structuresCount', stats)
        self.assertTrue({'pharmaciesCount', 'latestAnnouncements', 'responseLabel'}.isdisjoint(stats))
        for value in (None, 0, [], {}):
            body = self.body(VisibleCatalogue=value)
            self.data(self.client().post('/api/logistique/articles', body, format='json'), 400)
            self.assertEqual(self.connection.execute('SELECT count(*) n FROM logistique."T_Article" WHERE "NomArticle"=%s', [body['NomArticle']]).fetchone()['n'], 0)


if __name__ == '__main__':
    unittest.main(verbosity=2)
