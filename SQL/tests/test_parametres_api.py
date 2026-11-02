"""Recette Paramètres d’entreprise, exclusivement PostgreSQL privé local.

API réelles avec comptes fictifs et dictionnaire commun. Aucune connexion Gmail,
aucune facture ni donnée de l’instance SauverNdeko n’est créée par cette recette.
"""
import hashlib
import io
import json
import os
import sys
import unittest
import uuid
from pathlib import Path
from urllib.parse import urlsplit

import psycopg
from psycopg.rows import dict_row
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
DSN = os.environ.get('SAUVERNDEKO_TEST_DATABASE_URL', '')
target = urlsplit(DSN)
if target.hostname not in {'127.0.0.1', 'localhost'} or not target.path[1:].startswith('sauverndeko_test_'):
    raise RuntimeError('Recette réservée au PostgreSQL privé sauverndeko_test_*.')
with psycopg.connect(DSN) as guard:
    if not guard.execute('SELECT current_database()').fetchone()[0].startswith('sauverndeko_test_'):
        raise RuntimeError('Base privée obligatoire.')
os.environ.update(DATABASE_URL=DSN, DJANGO_SETTINGS_MODULE='config.settings', SAUVERNDEKO_DB_READ_ONLY='0')
sys.path.insert(0, str(ROOT / 'backend'))
import django
django.setup()
from django.core.files.uploadedfile import SimpleUploadedFile
from django.db import transaction
from django.test import override_settings
from rest_framework.test import APIClient
from apps.accounts.authentication import Actor, tokens
from apps.core import db
from apps.core.module_access import access_snapshot
from apps.logistique import entity_documents as service

BASE = '/api/parametres/'


def logo():
    stream = io.BytesIO()
    Image.new('RGBA', (80, 40), (32, 100, 120, 200)).save(stream, format='PNG')
    return SimpleUploadedFile('fictif.png', stream.getvalue(), content_type='image/png')


class EnterpriseSettingsAPI(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.override = override_settings(ALLOWED_HOSTS=['testserver'])
        cls.override.enable()
        cls.sql = psycopg.connect(DSN, autocommit=True, row_factory=dict_row)
        cls.entities = [cls.sql.execute('INSERT INTO systeme."T_Entite" ("NomEntite","EmailEntite","ValideEntite") VALUES(%s,%s,true) RETURNING "IdEntite" id',
            ['Paramètres fictifs '+uuid.uuid4().hex, uuid.uuid4().hex+'@example.invalid']).fetchone()['id'] for _ in range(2)]
        cls.users = [cls.sql.execute('''INSERT INTO systeme."T_Utilisateurs"
            ("NomUser","PrenomUser","EmailUser","MotdepasseUser","ValideUser","SexeUser","Is_Admin","Is_staff","IdEntiteFk")
            VALUES ('Paramètres','Fictif',%s,'inutilisable',true,'M',%s,%s,%s) RETURNING *''',
            [uuid.uuid4().hex+'@example.invalid', global_admin, staff, entity]).fetchone()
            for global_admin, staff, entity in [(False, True, cls.entities[0]), (False, False, cls.entities[0]),
                                               (False, True, cls.entities[1]), (True, True, None)]]

    @classmethod
    def tearDownClass(cls):
        cls.sql.close()
        cls.override.disable()

    def setUp(self):
        self.tx = None if self._testMethodName == 'test_15_real_stale_revision' else transaction.atomic()
        if self.tx:
            self.tx.__enter__()

    def tearDown(self):
        if self.tx:
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

    def status(self, response, code=200):
        self.assertEqual(response.status_code, code, getattr(response, 'data', 'binaire'))
        # Contrôler le JSON effectivement rendu, pas les Decimal internes DRF.
        return response.json().get('data') if hasattr(response, 'data') else None

    def profile(self, index=0, entity=None):
        return self.status(self.client(index, entity).get(BASE+'profil'))

    def body(self, index=0, entity=None, **changes):
        record = self.profile(index, entity)
        values = {key: record.get(key) for key in service.FIELDS}
        values.update(IdEntite=record['IdEntite'], _version=record['_version'],
            Localisations=record['Localisations'], requestId=str(uuid.uuid4()), motif='Paramétrage fictif de recette privée')
        values.update(changes)
        return values

    def put(self, body=None, index=0, entity=None, upload=None):
        client = self.client(index, entity)
        body = body if body is not None else self.body(index, entity)
        if upload is not None:
            return client.put(BASE+'profil', {'payload': json.dumps(body), 'logo': upload}, format='multipart')
        return client.put(BASE+'profil', body, format='json')

    def test_01_socle_without_logistics_licence(self):
        rights = access_snapshot(self.actor())['modules']
        self.assertTrue(rights['parametres']['base'])
        self.assertTrue(rights['parametres']['canRead'])
        self.assertTrue(rights['parametres']['canManage'])
        self.assertFalse(rights['logistique']['canRead'])
        data = self.status(self.client().get(BASE+'contexte'))
        self.assertTrue(data['canManage'])
        self.assertEqual(data['profile']['IdEntite'], self.entities[0])
        self.assertEqual(data['profile']['TauxTVAEntite'], '0.0000')

    def test_02_entity_isolation_and_choices(self):
        items = self.status(self.client().get(BASE+'entreprises'))
        self.assertEqual([row['id'] for row in items], [self.entities[0]])
        self.assertEqual(items[0]['label'], items[0]['NomEntite'])
        self.assertTrue(items[0]['active'])
        authenticated = APIClient()
        authenticated.credentials(HTTP_AUTHORIZATION='Bearer '+tokens(self.actor())['accessToken'])
        self.status(authenticated.get(BASE+'profil', HTTP_X_ENTITE_ID=str(self.entities[1])), 403)
        self.status(self.put(self.body(IdEntite=self.entities[1])), 403)
        self.assertEqual(self.profile(2)['IdEntite'], self.entities[1])

    def test_03_reader_can_consult_but_not_change(self):
        data = self.status(self.client(1).get(BASE+'contexte'))
        self.assertTrue(data['canRead'])
        self.assertFalse(data['canManage'])
        self.assertFalse(data['profile']['canConfigure'])
        self.status(self.put(self.body(), index=1), 403)

    def test_04_save_exact_tax_and_common_identity(self):
        data = self.status(self.put(self.body(TauxTVAEntite='16.1250', NomEntite='Entreprise fiscale fictive')))
        self.assertEqual(data['TauxTVAEntite'], '16.1250')
        self.assertEqual(data['NomEntite'], 'Entreprise fiscale fictive')
        current = service.current_identity(self.entities[0])
        self.assertEqual(str(current['TauxTVAEntite']), '16.1250')
        self.assertEqual(current['NomEntite'], data['NomEntite'])
        audit = db.one('SELECT "NewData" FROM systeme."T_Audit_Log" WHERE "Operation"=%s ORDER BY "IdLog" DESC LIMIT 1', [service.OPERATION])
        self.assertEqual(str(audit['NewData']['TauxTVAEntite']), '16.1250')
        self.assertNotIn('LogoEntite', audit['NewData'])

    def test_05_invalid_tax_is_atomic_and_explicit(self):
        before = self.profile()
        audits = db.one('SELECT count(*) n FROM systeme."T_Audit_Log"')['n']
        for value in (True, False, None, '', 'NaN', 'Infinity', '-0.1', '100.0001', '1.12345', {}, []):
            with self.subTest(value=value):
                response = self.put(self.body(TauxTVAEntite=value, NomEntite='Ne pas enregistrer'))
                self.status(response, 400)
                self.assertIn('TauxTVAEntite', response.data['error']['details'])
        self.assertEqual(self.profile()['NomEntite'], before['NomEntite'])
        self.assertEqual(db.one('SELECT count(*) n FROM systeme."T_Audit_Log"')['n'], audits)

    def test_06_zero_and_one_hundred_are_allowed(self):
        for value, expected in [('100', '100.0000'), ('0', '0.0000')]:
            data = self.status(self.put(self.body(TauxTVAEntite=value)))
            self.assertEqual(data['TauxTVAEntite'], expected)

    def test_07_old_clients_preserve_current_tax(self):
        self.status(self.put(self.body(TauxTVAEntite='7.5000')))
        body = self.body(NomEntite='Compatibilité fictive')
        body.pop('TauxTVAEntite')
        self.assertEqual(self.status(self.put(body))['TauxTVAEntite'], '7.5000')

    def test_08_global_selects_explicit_entity(self):
        data = self.status(self.client(3).get(BASE+'contexte'))
        self.assertIsNone(data['entityId'])
        self.assertIsNone(data['profile'])
        self.assertFalse(data['canManage'])
        self.status(self.client(3).get(BASE+'profil'), 409)
        self.status(self.put(self.body(), index=3), 409)
        choices = self.status(self.client(3, self.entities[0]).get(BASE+'entreprises'))
        self.assertTrue(set(self.entities).issubset({row['id'] for row in choices}))
        self.assertEqual(self.profile(3, self.entities[1])['IdEntite'], self.entities[1])

    def test_09_role_can_restrict_settings_without_logistics(self):
        from apps.core.field_references import reference_options
        role = reference_options(self.actor(3, self.entities[0]), 'systeme', 'T_Utilisateurs', 'IdRoleFk')[0]['id']
        db.query('INSERT INTO systeme."T_RoleModule" ("IdEntiteFk","IdRoleFk","CodeModule","PeutConsulter","PeutGerer","PeutExporter","Actif") VALUES(%s,%s,\'parametres\',false,false,false,true)', [self.entities[0], role])
        actor = self.actor()
        actor.row['IdRoleFk'] = role
        client = APIClient()
        client.force_authenticate(actor)
        self.status(client.get(BASE+'contexte'), 403)

    def test_10_replay_and_changed_content(self):
        body = self.body(TauxTVAEntite='8.25')
        self.status(self.put(body))
        audits = db.one('SELECT count(*) n FROM systeme."T_Audit_Log"')['n']
        response = self.put(body)
        data = self.status(response)
        self.assertTrue(response.data['meta']['replayed'])
        self.assertEqual(data['TauxTVAEntite'], '8.2500')
        self.assertEqual(db.one('SELECT count(*) n FROM systeme."T_Audit_Log"')['n'], audits)
        self.status(self.put({**body, 'TauxTVAEntite': '8.26'}), 409)

    def test_11_profile_logo_locations_are_atomic(self):
        before = self.profile()
        body = self.body(TauxTVAEntite='15', NomEntite='Ne pas enregistrer', logoAction='replace',
            Localisations=[{'Latitude': '91', 'Longitude': '1'}])
        self.status(self.put(body, upload=logo()), 422)
        after = self.profile()
        self.assertEqual(after['NomEntite'], before['NomEntite'])
        self.assertEqual(after['TauxTVAEntite'], before['TauxTVAEntite'])
        self.assertFalse(after['HasLogo'])
        self.assertEqual(after['Localisations'], before['Localisations'])

    def test_12_private_logo_for_authorised_reader(self):
        body = self.body(logoAction='replace', TauxTVAEntite='12',
            Localisations=[{'AdresseDetaillee': 'Adresse de recette privée', 'Latitude': '0', 'Longitude': '1'}])
        data = self.status(self.put(body, upload=logo()))
        self.assertTrue(data['HasLogo'])
        self.assertEqual(len(data['Localisations']), 1)
        response = self.client(1).get(data['logoUrl'])
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response['Content-Type'], 'image/png')
        self.assertEqual(hashlib.sha256(response.content).hexdigest(), data['LogoSha256Entite'])
        self.status(self.client(2).get(data['logoUrl']), 403)

    def test_13_type_state_stay_in_administration(self):
        for change in ({'ValideEntite': False}, {'IdTypeEntiteFk': 999999}):
            self.status(self.put(self.body(**change)), 403)
            self.status(self.put(self.body(3, self.entities[0], **change), index=3, entity=self.entities[0]), 403)
        self.assertTrue(self.profile()['ValideEntite'])
        self.assertFalse(self.profile()['canManageEntity'])

    def test_14_readonly_and_inactive_guards(self):
        body = self.body(TauxTVAEntite='16')
        with override_settings(DB_READ_ONLY=True):
            self.assertFalse(self.profile()['canConfigure'])
            self.status(self.put(body), 503)
        db.query('UPDATE systeme."T_Entite" SET "ValideEntite"=false WHERE "IdEntite"=%s', [self.entities[0]])
        self.assertFalse(self.profile(3, self.entities[0])['canConfigure'])
        self.status(self.put(body, index=3, entity=self.entities[0]), 409)

    def test_15_real_stale_revision(self):
        # Sans transaction extérieure : deux requêtes ont réellement des xmin
        # distincts comme en HTTP, sans simuler la révision PostgreSQL.
        first, second = self.body(TauxTVAEntite='10'), self.body(TauxTVAEntite='20')
        self.status(self.put(first))
        self.status(self.put(second), 409)
        self.assertEqual(self.profile()['TauxTVAEntite'], '10.0000')

    def test_16_unauthenticated_and_unknown_fields(self):
        self.assertEqual(APIClient().get(BASE+'contexte').status_code, 401)
        self.status(self.put({**self.body(), 'Is_Admin': True}), 400)
        self.status(self.client().get(BASE+'profil?IdEntite='+str(self.entities[1])), 400)


if __name__ == '__main__':
    unittest.main(verbosity=2)
