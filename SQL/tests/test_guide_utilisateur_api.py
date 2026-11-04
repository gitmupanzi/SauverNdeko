"""Guide utilisateur : API réelles, licences/entreprises sur PostgreSQL privé.

Aucune lecture de mot de passe utilisateur ni mutation de la base SauverNdeko.
La recette refuse toute base qui n'est pas locale et sauverndeko_test_*.
"""
import copy
import json
import os
import sys
import tempfile
import unittest
import uuid
from pathlib import Path
from unittest.mock import patch
from urllib.parse import urlsplit

import psycopg
from psycopg.rows import dict_row

ROOT = Path(__file__).resolve().parents[2]
DSN = os.environ.get('SAUVERNDEKO_TEST_DATABASE_URL', '')
target = urlsplit(DSN)
if target.hostname not in {'localhost', '127.0.0.1'} or not target.path[1:].startswith('sauverndeko_test_'):
    raise RuntimeError('Base privée locale sauverndeko_test_* obligatoire.')
with psycopg.connect(DSN) as guard:
    if not guard.execute('SELECT current_database()').fetchone()[0].startswith('sauverndeko_test_'):
        raise RuntimeError('Recette interdite hors base privée.')
os.environ.update(DATABASE_URL=DSN, DJANGO_SETTINGS_MODULE='config.settings', SAUVERNDEKO_DB_READ_ONLY='0')
sys.path.insert(0, str(ROOT / 'backend'))
import django
django.setup()
from django.db import transaction
from django.test import override_settings
from rest_framework.test import APIClient
from apps.accounts.authentication import Actor, tokens
from apps.core import db, user_guide
from apps.core.module_access import MODULE_BY_KEY, access_snapshot

BASE = '/api/guide/'


class UserGuideAPI(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.settings = override_settings(ALLOWED_HOSTS=['testserver'])
        cls.settings.enable()
        cls.sql = psycopg.connect(DSN, autocommit=True, row_factory=dict_row)
        cls.entities = [cls.sql.execute('INSERT INTO systeme."T_Entite"("NomEntite","EmailEntite","ValideEntite") VALUES(%s,%s,true) RETURNING "IdEntite" id',
            ['Guide fictif '+uuid.uuid4().hex, uuid.uuid4().hex+'@example.invalid']).fetchone()['id'] for _ in range(2)]
        cls.role = cls.sql.execute('''SELECT g."ID_Generique" id FROM referentiel."T_Generique" g
            JOIN referentiel."T_CategorieGenerique" c ON c."ID_CategorieGenerique"=g."ID_CategorieGeneriqueFk"
            WHERE c."NomCategorieGenerique"='Role' AND g."ValideGenerique" IS TRUE ORDER BY g."ID_Generique" LIMIT 1''').fetchone()['id']
        cls.status = cls.sql.execute('''SELECT g."ID_Generique" id FROM referentiel."T_Generique" g
            JOIN referentiel."T_CategorieGenerique" c ON c."ID_CategorieGenerique"=g."ID_CategorieGeneriqueFk"
            WHERE c."NomCategorieGenerique"='Statut licence' AND g."NomGenerique"='Active' AND g."ValideGenerique" IS TRUE LIMIT 1''').fetchone()['id']
        cls.users = [cls.sql.execute('''INSERT INTO systeme."T_Utilisateurs"
            ("NomUser","PrenomUser","EmailUser","MotdepasseUser","ValideUser","SexeUser","Is_Admin","Is_staff","IdEntiteFk","IdRoleFk")
            VALUES('Guide','Fictif',%s,'inutilisable',true,'M',%s,%s,%s,%s) RETURNING *''',
            [uuid.uuid4().hex+'@example.invalid', global_admin, staff, entity, cls.role]).fetchone()
            for global_admin, staff, entity in [(False, True, cls.entities[0]), (False, True, cls.entities[1]),
                                               (False, False, cls.entities[0]), (True, True, None)]]
        _, cls.modules = user_guide.content()

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

    def actor(self, index=0, entity=None):
        actor = Actor(dict(self.users[index]))
        if index == 3 and entity is not None:
            actor._context_entity = entity
        return actor

    def client(self, index=0, entity=None):
        client = APIClient()
        client.force_authenticate(self.actor(index, entity))
        return client

    def data(self, response, expected=200):
        self.assertEqual(response.status_code, expected, getattr(response, 'data', 'non JSON'))
        self.assertEqual(response.get('Cache-Control'), 'no-store, private')
        return response.json().get('data')

    def context(self, index=0):
        return self.data(self.client(index).get(BASE+'contexte'))

    def article_url(self, module='logistique'):
        return BASE+'articles/'+module+'/'+self.modules[module]['articles'][0]['id']

    def licence(self, module='logistique', entity=None, expired=False, future=False):
        entity = entity or self.entities[0]
        start = 'LOCALTIMESTAMP+INTERVAL \'1 day\'' if future else 'LOCALTIMESTAMP-INTERVAL \'3 days\''
        end = 'LOCALTIMESTAMP-INTERVAL \'1 day\'' if expired else 'LOCALTIMESTAMP+INTERVAL \'5 years\''
        licence = db.one('INSERT INTO systeme."T_Licence"("IdEntiteFk","DateDebut","DateFin","ValideLicence","IdStatutLicenceFk") VALUES(%s,'+start+','+end+',true,%s) RETURNING "IdLicence" id', [entity, self.status])['id']
        db.query('INSERT INTO systeme."T_LicenceModule"("IdLicenceFk","CodeModule","Actif") VALUES(%s,%s,true)', [licence, module])
        return licence

    def test_01_anonymous_refused(self):
        self.data(APIClient().get(BASE+'contexte'), 401)
        self.data(APIClient().get(self.article_url()), 401)

    def test_02_socle_guide_without_paid_licence(self):
        rights = access_snapshot(self.actor())['modules']
        self.assertTrue(rights['guide']['base'])
        self.assertTrue(rights['guide']['canRead'])
        self.assertFalse(rights['guide']['canManage'])
        self.assertFalse(rights['logistique']['canRead'])
        data = self.context()
        self.assertEqual(data['entityId'], self.entities[0])
        keys = {item['key'] for item in data['modules']}
        self.assertIn('parametres', keys)
        self.assertNotIn('logistique', keys)
        self.assertNotIn('produits', keys)
        self.assertNotIn('guide', keys)
        self.assertTrue(all(set(article) == {'id', 'title', 'summary'} for module in data['modules'] for article in module['articles']))

    def test_03_licensed_module_visible_and_complete(self):
        self.licence()
        self.assertIn('logistique', {item['key'] for item in self.context()['modules']})
        detail = self.data(self.client().get(self.article_url()))
        self.assertEqual(detail['module']['key'], 'logistique')
        self.assertTrue(detail['article']['steps'])
        self.assertTrue(detail['article']['example']['text'])

    def test_04_unlicensed_direct_url_refused_without_text(self):
        response = self.client().get(self.article_url())
        self.data(response, 403)
        self.assertNotIn(self.modules['logistique']['articles'][0]['summary'], response.content.decode())

    def test_05_expired_licence_removes_module_and_direct_access(self):
        self.licence(expired=True)
        self.assertNotIn('logistique', {item['key'] for item in self.context()['modules']})
        self.data(self.client().get(self.article_url()), 403)

    def test_06_future_and_disabled_licences_refused(self):
        future = self.licence(future=True)
        self.assertNotIn('logistique', {item['key'] for item in self.context()['modules']})
        db.query('UPDATE systeme."T_Licence" SET "ValideLicence"=false WHERE "IdLicence"=%s', [future])
        licence = self.licence()
        db.query('UPDATE systeme."T_Licence" SET "ValideLicence"=false WHERE "IdLicence"=%s', [licence])
        self.data(self.client().get(self.article_url()), 403)

    def test_07_role_denial_preserved_with_valid_licence(self):
        self.licence()
        db.query('''INSERT INTO systeme."T_RoleModule"("IdEntiteFk","IdRoleFk","CodeModule","PeutConsulter","PeutGerer","PeutExporter","Actif")
                    VALUES(%s,%s,'logistique',false,false,false,true)''', [self.entities[0], self.role])
        self.assertNotIn('logistique', {item['key'] for item in self.context()['modules']})
        self.data(self.client().get(self.article_url()), 403)

    def test_08_other_enterprise_licence_never_grants_access(self):
        self.licence(entity=self.entities[1])
        self.assertNotIn('logistique', {item['key'] for item in self.context()['modules']})
        self.assertIn('logistique', {item['key'] for item in self.context(1)['modules']})
        choices = self.data(self.client().get(BASE+'entreprises'))
        self.assertEqual([item['id'] for item in choices], [self.entities[0]])

    def test_09_real_jwt_rejects_enterprise_spoof(self):
        client = APIClient()
        client.credentials(HTTP_AUTHORIZATION='Bearer '+tokens(self.actor())['accessToken'])
        self.data(client.get(BASE+'contexte', HTTP_X_ENTITE_ID=str(self.entities[1])), 403)
        self.data(client.get(BASE+'entreprises', HTTP_X_ENTITE_ID=str(self.entities[1])), 403)
        self.data(client.get(self.article_url('parametres'), HTTP_X_ENTITE_ID=str(self.entities[1])), 403)

    def test_10_platform_admin_keeps_all_guides(self):
        data = self.context(3)
        self.assertTrue(data['platformAdmin'])
        self.assertIsNone(data['entityId'])
        self.assertEqual({item['key'] for item in data['modules']}, set(self.modules))
        self.assertIn(self.entities[0], [item['id'] for item in self.data(self.client(3).get(BASE+'entreprises'))])
        self.assertEqual(self.data(self.client(3, self.entities[0]).get(BASE+'contexte'))['entityId'], self.entities[0])

    def test_11_unknown_module_article_and_query(self):
        self.data(self.client().get(BASE+'articles/inconnu/inconnu'), 404)
        self.data(self.client().get(BASE+'articles/guide/inconnu'), 404)
        self.data(self.client().get(BASE+'articles/parametres/inconnu'), 404)
        self.data(self.client().get(BASE+'contexte?q=licence'), 400)
        self.data(self.client().get(self.article_url('parametres')+'?q=licence'), 400)

    def test_12_read_only_routes_do_not_offer_mutations(self):
        for path in (BASE+'contexte', BASE+'entreprises', self.article_url('parametres')):
            for method in ('post', 'put', 'patch', 'delete'):
                self.data(getattr(self.client(), method)(path, {}, format='json'), 405)

    def test_13_reader_has_only_reader_documented_modules(self):
        self.licence()
        data = self.context(2)
        self.assertNotIn('administration', {item['key'] for item in data['modules']})
        self.assertNotIn('logistique', {item['key'] for item in data['modules']})
        self.data(self.client(2).get(self.article_url('administration')), 403)

    def test_14_catalogue_includes_children_of_catalogue_licence(self):
        self.licence('catalogue')
        keys = {item['key'] for item in self.context()['modules']}
        self.assertTrue({'catalogue', 'produits', 'structures', 'professionnels'}.issubset(keys))
        self.assertNotIn('sante',keys)

    def test_15_content_catalogue_has_unique_safe_routes_and_examples(self):
        revision, modules = user_guide.content()
        self.assertEqual(set(modules), (set(MODULE_BY_KEY)-{'guide'})|{'referentiels'})
        self.assertTrue(revision.startswith('2026-11-03:'))
        for key, module in modules.items():
            for item in module['articles']:
                self.assertTrue(item['steps'])
                self.assertTrue(item['example']['text'])
                detail = self.data(self.client(3).get(BASE+'articles/'+key+'/'+item['id']))
                self.assertEqual(detail['article'], item)

    def test_catalogue_and_publication_instructions_match_delivered_routes(self):
        _, modules = user_guide.content()
        articles = {item['id']: item for item in modules['catalogue']['articles']}
        presentation = json.dumps(articles['decouvrir-catalogue'], ensure_ascii=False)
        self.assertIn('présentation', presentation)
        self.assertIn('connexion', presentation)
        self.assertNotIn('statistiques en temps réel', presentation)
        creation = next(item for item in modules['logistique']['articles'] if item['id']=='creer-article')
        self.assertIn('Choisir la visibilité', [step['title'] for step in creation['steps']])
        entreprise = next(item for item in modules['parametres']['articles'] if item['id']=='modifier-entreprise')
        self.assertIn('Régler le partage des articles', [step['title'] for step in entreprise['steps']])

    def test_16_invalid_content_and_external_links_fail_closed(self):
        original = json.loads(user_guide.CONTENT_PATH.read_bytes())
        for alter in ('external', 'duplicate', 'incomplete'):
            invalid = copy.deepcopy(original)
            if alter == 'external':
                invalid['modules'][0]['articles'][0]['links'] = [{'label':'Lien interdit', 'path':'https://example.invalid/'}]
            elif alter == 'duplicate':
                invalid['modules'].append(copy.deepcopy(invalid['modules'][0]))
            else:
                invalid['modules'].pop()
            with tempfile.TemporaryDirectory() as folder:
                path = Path(folder)/'contenu.json'
                path.write_text(json.dumps(invalid), encoding='utf8')
                with patch.object(user_guide, 'CONTENT_PATH', path):
                    self.data(self.client().get(BASE+'contexte'), 503)

    def test_17_next_request_rechecks_revoked_licence(self):
        licence = self.licence()
        self.data(self.client().get(self.article_url()))
        db.query('UPDATE systeme."T_Licence" SET "ValideLicence"=false WHERE "IdLicence"=%s', [licence])
        self.data(self.client().get(self.article_url()), 403)
        self.assertNotIn('logistique', {item['key'] for item in self.context()['modules']})

    def test_18_all_guide_reads_leave_business_rows_unchanged(self):
        def counts():
            return [db.one('SELECT count(*) n FROM '+table)['n'] for table in
                    ['logistique."T_Article"','logistique."T_Commande"','logistique."T_Facture"','logistique."T_Mouvement"','systeme."T_Audit_Log"']]
        before = counts()
        self.context(3)
        self.data(self.client(3).get(BASE+'entreprises'))
        for key, module in self.modules.items():
            self.data(self.client(3).get(BASE+'articles/'+key+'/'+module['articles'][0]['id']))
        self.assertEqual(before, counts())

    def test_19_guide_role_restriction_applies_to_all_entry_points(self):
        db.query('''INSERT INTO systeme."T_RoleModule"("IdEntiteFk","IdRoleFk","CodeModule","PeutConsulter","PeutGerer","PeutExporter","Actif")
                    VALUES(%s,%s,'guide',false,false,false,true)''', [self.entities[0], self.role])
        for path in (BASE+'contexte', BASE+'entreprises', self.article_url('parametres')):
            self.data(self.client().get(path), 403)


if __name__ == '__main__':
    unittest.main(verbosity=2)
