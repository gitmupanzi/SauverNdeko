"""Identité/logo : vraie API, trois entreprises fictives, PostgreSQL privé imposé."""
import hashlib
import io
import json
import os
import sys
import unittest
import uuid
import threading
from pathlib import Path
from urllib.parse import urlsplit

import psycopg
from psycopg.rows import dict_row
from PIL import Image, PngImagePlugin

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
from django.db import connections
from rest_framework.test import APIClient
from apps.accounts.authentication import Actor
from apps.core import db, repository
from apps.core.responses import APIError
from apps.core.registry import model
from apps.logistique import entity_documents as service


def logo_file(fmt='PNG', *, size=(80, 40), color=(32, 100, 120, 120), metadata=True):
    image = Image.new('RGBA', size, color)
    if fmt == 'JPEG':
        image = image.convert('RGB')
    stream = io.BytesIO()
    options = {}
    if fmt == 'PNG' and metadata:
        info = PngImagePlugin.PngInfo()
        info.add_text('PrivateComment', 'Cette métadonnée ne doit pas être conservée.')
        options['pnginfo'] = info
    image.save(stream, format=fmt, **options)
    # Le type et le nom déclarés ne font pas foi, seuls les pixels sont décodés.
    return SimpleUploadedFile('source.' + fmt.lower(), stream.getvalue(), content_type='application/octet-stream')


class EnterpriseIdentityAPI(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.override = override_settings(ALLOWED_HOSTS=['testserver'])
        cls.override.enable()
        cls.connection = psycopg.connect(DSN, autocommit=True, row_factory=dict_row)
        cls.entities = [cls.connection.execute('INSERT INTO systeme."T_Entite" ("NomEntite","EmailEntite","ValideEntite") VALUES (%s,%s,true) RETURNING "IdEntite" id',
            ['Entreprise identité fictive ' + uuid.uuid4().hex, uuid.uuid4().hex + '@example.invalid']).fetchone()['id'] for _ in range(3)]
        cls.user = cls.connection.execute('''INSERT INTO systeme."T_Utilisateurs"
            ("NomUser","PrenomUser","EmailUser","MotdepasseUser","ValideUser","SexeUser","Is_Admin","Is_staff","IdEntiteFk")
            VALUES ('Fictif','Logo',%s,'inutilisable',true,'M',true,true,%s) RETURNING *''',
            [uuid.uuid4().hex + '@example.invalid', cls.entities[0]]).fetchone()

    @classmethod
    def tearDownClass(cls):
        cls.connection.close()
        cls.override.disable()

    def actor(self, index=0, *, global_admin=True, manage=True, read=True, staff=True):
        actor = Actor({**self.user, 'Is_Admin': global_admin, 'Is_staff': staff, 'IdEntiteFk': self.entities[index]})
        if global_admin:
            actor._context_entity = self.entities[index]
        actor._module_access = {'modules': {key: {'canRead': read, 'canManage': manage, 'canExport': read, 'reason': 'MODULE_ROLE_FORBIDDEN'} for key in ('administration', 'logistique')}}
        return actor

    def client(self, index=0, **rights):
        client = APIClient()
        client.force_authenticate(self.actor(index, **rights))
        return client

    def profile(self, index=0, *, administration=False):
        actor = self.actor(index)
        return service.profile(actor, self.entities[index] if administration else None, administration=administration)

    def body(self, index=0, *, administration=False, **changes):
        profile = self.profile(index, administration=administration)
        result = {key: profile.get(key) for key in service.FIELDS}
        if administration:
            result.update({key: profile.get(key) for key in service.ADMIN_FIELDS})
        result.update(IdEntite=self.entities[index], _version=profile['_version'], motif='Recette fictive du profil entreprise', requestId=str(uuid.uuid4()))
        result.update(changes)
        return result

    def put(self, body, *, index=0, administration=False, upload=None, **rights):
        path = f'/api/systeme/entites/{self.entities[index]}' if administration else '/api/logistique/entreprise/identite'
        return self.client(index, **rights).put(path, {'payload': json.dumps(body), 'logo': upload}, format='multipart') if upload is not None else self.client(index, **rights).put(path, body, format='json')

    def assert_status(self, response, status=200):
        self.assertEqual(response.status_code, status, getattr(response, 'data', 'Réponse binaire'))
        return getattr(response, 'data', {}).get('data')

    def test_01_defaults_shared_contract_and_no_binary(self):
        defaults = self.assert_status(self.client().get('/api/systeme/entites/identite-defaut'))
        self.assertTrue(defaults['AfficherEnteteDocument'])
        self.assertTrue(defaults['AfficherPiedDocument'])
        self.assertIn('entityTypes', defaults['references'])
        self.assert_status(self.client(global_admin=False).get('/api/systeme/entites/identite-defaut'), 403)
        for index in range(3):
            for path in [f'/api/systeme/entites/{self.entities[index]}', '/api/logistique/entreprise/identite']:
                profile = self.assert_status(self.client(index).get(path))
                self.assertTrue(profile['AfficherEnteteDocument'])
                self.assertTrue(profile['AfficherPiedDocument'])
                self.assertFalse(profile['HasLogo'])
                self.assertNotIn('LogoEntite', profile)
                self.assertIsInstance(profile['_version'], str)
                self.assertTrue(profile['canConfigure'])

    def test_02_atomic_profile_logo_and_shared_visibility(self):
        body = self.body(0, NomEntite='Identité commune & société fictive', SiteWebEntite='https://example.invalid',
            AdresseEntite='Adresse fictive\nDeuxième ligne', AfficherEnteteDocument=False,
            IdentifiantsLegauxEntite=[{'libelle': 'RCCM', 'valeur': 'FICTIF-001'}, {'libelle': 'Banque', 'valeur': 'Compte fictif'}], logoAction='replace')
        profile = self.assert_status(self.put(body, upload=logo_file()))
        self.assertTrue(profile['HasLogo'])
        self.assertFalse(profile['AfficherEnteteDocument'])
        admin = self.assert_status(self.client().get(f'/api/systeme/entites/{self.entities[0]}'))
        for key in service.FIELDS | {'_version', 'HasLogo', 'LogoSha256Entite'}:
            self.assertEqual(profile[key], admin[key])
        binary = self.client().get(profile['logoUrl'])
        self.assert_status(binary)
        self.assertEqual(binary['Content-Type'], 'image/png')
        self.assertEqual(binary['Cache-Control'], 'no-store, private')
        self.assertEqual(binary['X-Content-Type-Options'], 'nosniff')
        self.assertEqual(hashlib.sha256(binary.content).hexdigest(), profile['LogoSha256Entite'])
        with Image.open(io.BytesIO(binary.content)) as decoded:
            self.assertEqual(decoded.size, (80, 40))
            self.assertNotIn('PrivateComment', decoded.info)
            self.assertEqual(decoded.getpixel((0, 0))[3], 120)
        log = self.connection.execute('SELECT * FROM systeme."T_Audit_Log" WHERE "Operation"=%s AND "NewData" @> %s::jsonb ORDER BY "IdLog" DESC LIMIT 1', [service.OPERATION, json.dumps({'requestId': body['requestId']})]).fetchone()
        self.assertEqual(log['IdEntiteFk'], self.entities[0])
        self.assertNotIn('LogoEntite', log['NewData'])
        self.assertNotIn('PrivateComment', json.dumps(log['NewData'], default=str))

    def test_03_replay_stale_version_and_conflicting_replay(self):
        body = self.body(1, logoAction='replace')
        first = self.assert_status(self.put(body, index=1, upload=logo_file('JPEG')))
        response = self.put(body, index=1, upload=logo_file('JPEG'))
        replay = self.assert_status(response)
        self.assertTrue(response.data['meta']['replayed'])
        self.assertEqual(replay['_version'], first['_version'])
        self.assert_status(self.put({**body, 'NomEntite': 'Autre contenu'}, index=1, upload=logo_file('JPEG')), 409)
        self.assert_status(self.put({**body, 'requestId': str(uuid.uuid4())}, index=1, upload=logo_file('JPEG')), 409)
        count = self.connection.execute('SELECT count(*) n FROM systeme."T_Audit_Log" WHERE "Operation"=%s AND "NewData" @> %s::jsonb', [service.OPERATION, json.dumps({'requestId': body['requestId']})]).fetchone()['n']
        self.assertEqual(count, 1)

    def test_04_reject_invalid_image_without_partial_profile_change(self):
        baseline = self.profile(2)
        invalid = [SimpleUploadedFile('logo.svg', b'<svg xmlns="http://www.w3.org/2000/svg"/>', content_type='image/svg+xml'),
            SimpleUploadedFile('remote.png', b'https://example.invalid/logo.png'),
            SimpleUploadedFile('big.png', b'a' * (service.MAX_LOGO_BYTES + 1)), logo_file(size=(4097, 1))]
        for upload in invalid:
            body = self.body(2, NomEntite='Ne doit jamais être persisté', logoAction='replace')
            self.assert_status(self.put(body, index=2, upload=upload), 400)
            self.assertEqual(self.profile(2)['_version'], baseline['_version'])
        self.assert_status(self.put(self.body(2, logoAction=[]), index=2), 400)
        self.assert_status(self.put(self.body(2, logoAction='replace'), index=2), 400)
        self.assert_status(self.put(self.body(2, logoAction='remove'), index=2, upload=logo_file()), 400)

    def test_05_all_three_enterprises_are_isolated(self):
        local = self.client(0, global_admin=False)
        self.assert_status(local.get(f'/api/systeme/entites/{self.entities[0]}'))
        for entity in self.entities[1:]:
            self.assert_status(local.get(f'/api/systeme/entites/{entity}'), 404)
            self.assert_status(local.get(f'/api/systeme/entites/{entity}/logo'), 404)
            body = self.body(1, administration=True)
            self.assert_status(local.put(f'/api/systeme/entites/{entity}', body, format='json'), 404)
        self.assert_status(self.put(self.body(1), index=0), 403)
        self.assert_status(self.client(global_admin=False).delete(f'/api/systeme/entites/{self.entities[0]}'), 403)
        # Un global peut cibler la troisième fiche tout en gardant A actif.
        self.assert_status(self.client(0).get(f'/api/systeme/entites/{self.entities[2]}'))
        anonymous = APIClient()
        self.assertIn(anonymous.get(f'/api/systeme/entites/{self.entities[0]}/logo').status_code, {401, 403})

    def test_06_rights_and_state_are_server_controlled(self):
        body = self.body(2)
        self.assert_status(self.put(body, index=2, manage=False), 403)
        self.assert_status(self.put(body, index=2, read=False), 403)
        self.assert_status(self.client(2, global_admin=False, staff=False).get(f'/api/systeme/entites/{self.entities[2]}/logo'), 403)
        admin_body = self.body(2, administration=True, ValideEntite=False)
        self.assert_status(self.put(admin_body, index=2, administration=True, global_admin=False), 403)
        self.assertTrue(self.profile(2, administration=True)['ValideEntite'])
        with override_settings(DB_READ_ONLY=True):
            self.assert_status(self.put(body, index=2), 503)

    def test_07_logo_keep_remove_and_generated_fields(self):
        created = self.assert_status(self.put(self.body(2, logoAction='replace'), index=2, upload=logo_file('WEBP')))
        kept = self.assert_status(self.put(self.body(2, MentionDocumentaireEntite='Mention fictive'), index=2))
        self.assertEqual(created['LogoSha256Entite'], kept['LogoSha256Entite'])
        removed = self.assert_status(self.put(self.body(2, logoAction='remove', AfficherPiedDocument=False), index=2))
        self.assertFalse(removed['HasLogo'])
        self.assertFalse(removed['AfficherPiedDocument'])
        for key in ('LogoMimeEntite', 'LogoSha256Entite', 'LogoModifieLe', 'logoUrl'):
            self.assertIsNone(removed[key])
        self.assert_status(self.client(2).get(f'/api/systeme/entites/{self.entities[2]}/logo'), 404)
        for key in service.LOGO_FIELDS:
            self.assert_status(self.put(self.body(2, **{key: 'fake'}), index=2), 400)
            with self.assertRaises(APIError):
                repository.payload({'name': 'T_Entite', 'columns': [], 'primaryKey': []}, {key: 'fake'}, self.actor())

    def test_08_creation_uses_same_atomic_contract_and_is_idempotent(self):
        body = self.body(1, administration=True, NomEntite='Nouvelle entreprise fictive ' + uuid.uuid4().hex,
            EmailEntite=uuid.uuid4().hex + '@example.invalid', logoAction='replace')
        for key in ('IdEntite', '_version'):
            body.pop(key)
        client = self.client(0)
        response = client.post('/api/systeme/entites', {'payload': json.dumps(body), 'logo': logo_file()}, format='multipart')
        profile = self.assert_status(response, 201)
        self.assertTrue(profile['HasLogo'])
        again = client.post('/api/systeme/entites', {'payload': json.dumps(body), 'logo': logo_file()}, format='multipart')
        self.assertEqual(self.assert_status(again)['IdEntite'], profile['IdEntite'])
        self.assertTrue(again.data['meta']['replayed'])
        self.assert_status(self.client(global_admin=False).post('/api/systeme/entites', body, format='json'), 403)
        audit = self.connection.execute('SELECT "IdEntiteFk" FROM systeme."T_Audit_Log" WHERE "Operation"=%s AND "NewData" @> %s::jsonb', [service.OPERATION + '_CREATE', json.dumps({'requestId': body['requestId']})]).fetchone()
        self.assertEqual(audit['IdEntiteFk'], profile['IdEntite'])

    def test_09_validation_and_generic_binary_defence(self):
        intranet = self.assert_status(self.put(self.body(2, SiteWebEntite='http://serveur-interne:8080/contact'), index=2))
        self.assertEqual(intranet['SiteWebEntite'], 'http://serveur-interne:8080/contact')
        for key, value in [('SiteWebEntite', 'ftp://example.invalid'), ('SiteWebEntite', 'https://user:pass@example.invalid'),
                ('SiteWebEntite', 'https://serveur-interne:99999/contact'), ('SiteWebEntite', 'javascript:alert(1)'),
                ('AfficherEnteteDocument', None), ('AfficherPiedDocument', 'false'), ('motif', ''), ('PhoneEntite', '1' * 21),
                ('IdentifiantsLegauxEntite', [{'libelle': 'RCCM', 'valeur': '1'}, {'libelle': ' rccm ', 'valeur': '2'}])]:
            self.assert_status(self.put(self.body(2, **{key: value}), index=2), 400)
        for path in ['/api/systeme/entites', '/api/systeme/administration/registres/entites']:
            data = self.assert_status(self.client().get(path))
            self.assertFalse(any('LogoEntite' in row for row in data))
        self.assertEqual(repository.clean({'nested': {'LogoEntite': b'private', 'LogoSha256Entite': 'hash'}}), {'nested': {'LogoSha256Entite': 'hash'}})
        internal = service.current_identity(self.entities[0], include_logo=True)
        self.assertIsInstance(internal['LogoEntite'], bytes)
        ordinary = service.current_identity(self.entities[0])
        self.assertNotIn('LogoEntite', ordinary)
        scoped_view = self.assert_status(self.client(global_admin=False).get('/api/views/systeme/V_IdentiteDocumentaire'))
        self.assertEqual({row['IdEntite'] for row in scoped_view}, {self.entities[0]})
        self.assertFalse(any('LogoEntite' in row for row in scoped_view))
        obj = model('T_Entite')
        names = {column['column_name'] for column in obj['columns']}
        protected = [{**obj['columns'][0], 'column_name': key, 'data_type': 'text'} for key in repository.ENTITY_LOGO_GENERATED - names]
        obj = {**obj, 'columns': [*obj['columns'], *protected]}
        rows, meta = repository.listing(obj, self.actor(), {'take': 2})
        self.assertFalse(set(meta['columns']) & repository.ENTITY_LOGO_GENERATED)
        self.assertFalse(set(repository.get_record(obj, self.actor(), {'IdEntite': self.entities[0]})) & repository.ENTITY_LOGO_GENERATED)
        with self.assertRaises(APIError):
            repository.predicate(obj, self.actor(), {'filters': {'LogoSha256Entite': 'probe'}})

    def test_10_platform_state_control_preserves_nullable_history(self):
        entity = self.entities[2]
        self.connection.execute('UPDATE systeme."T_Entite" SET "ValideEntite"=NULL WHERE "IdEntite"=%s', [entity])
        body = self.body(2, administration=True, NomEntite='Nom courant sans activation implicite')
        for key in service.ADMIN_FIELDS:
            body.pop(key)
        profile = self.assert_status(self.put(body, index=2, administration=True))
        self.assertIsNone(profile['ValideEntite'])
        body = self.body(2, administration=True, ValideEntite=False)
        self.assertFalse(self.assert_status(self.put(body, index=2, administration=True))['ValideEntite'])
        self.assert_status(self.client(2, global_admin=False).put(f'/api/systeme/entites/{entity}', body, format='json'), 409)
        body = self.body(2, administration=True, ValideEntite=True)
        self.assertTrue(self.assert_status(self.put(body, index=2, administration=True))['ValideEntite'])

    def test_11_entity_type_references_follow_server_mapping(self):
        entity = self.entities[2]
        category = self.connection.execute('''INSERT INTO referentiel."T_CategorieGenerique"
            ("NomCategorieGenerique","ValideCategorieGenerique") VALUES (%s,true) RETURNING "ID_CategorieGenerique" id''',
            ['Types entreprise fictifs ' + uuid.uuid4().hex]).fetchone()['id']
        type_id = self.connection.execute('''INSERT INTO referentiel."T_Generique"
            ("ID_CategorieGeneriqueFk","NomGenerique","AbrGenerique","ValideGenerique") VALUES (%s,'Entreprise fictive','FICTIF',true) RETURNING "ID_Generique" id''', [category]).fetchone()['id']
        self.connection.execute('''INSERT INTO systeme."T_Fk_Correspondance"
            ("ModuleName","SchemaName","SourceKey","FieldName","FieldLabel","MappingType","ReferenceSchemaName","ReferenceObjectName","ReferenceFieldName","TargetCategoryIdFk","MappingValue","SettingScope","ScopeValue","ValideFkCorrespondance")
            VALUES ('admin','referentiel','entityTypes','entityTypes','Type entreprise','generic_category','referentiel','T_Generique','ID_Generique',%s,%s,'entity',%s,true)''', [category, str(category), str(entity)])
        profile = self.profile(2, administration=True)
        self.assertIn(type_id, [row['id'] for row in profile['references']['entityTypes']])
        body = self.body(2, administration=True, IdTypeEntiteFk=type_id)
        self.assert_status(self.put(body, index=2, administration=True, global_admin=False), 403)
        updated = self.assert_status(self.put(body, index=2, administration=True))
        self.assertEqual(updated['IdTypeEntiteFk'], type_id)
        self.connection.execute('UPDATE referentiel."T_Generique" SET "ValideGenerique"=false WHERE "ID_Generique"=%s', [type_id])
        retained = self.profile(2, administration=True)['references']['entityTypes']
        self.assertTrue(next(row for row in retained if row['id'] == type_id)['disabled'])
        body = self.body(2, administration=True)
        self.assert_status(self.put(body, index=2, administration=True))

    def test_12_parallel_replay_or_edit_has_one_winner(self):
        for same_request in (True, False):
            body = self.body(1)
            barrier, results = threading.Barrier(2), []
            def worker():
                try:
                    candidate = dict(body)
                    if not same_request:
                        candidate['requestId'] = str(uuid.uuid4())
                    barrier.wait(timeout=10)
                    data, replayed = service.save(self.actor(1), candidate)
                    results.append(('ok', replayed))
                except APIError as error:
                    results.append(('error', error.status_code))
                except Exception as error:
                    results.append(('unexpected', type(error).__name__))
                finally:
                    connections.close_all()
            threads = [threading.Thread(target=worker) for _ in range(2)]
            for thread in threads:
                thread.start()
            for thread in threads:
                thread.join(15)
                self.assertFalse(thread.is_alive())
            self.assertEqual(sorted(results), [('ok', False), ('ok', True)] if same_request else [('error', 409), ('ok', False)])

    def test_13_secondary_phone_is_shared_validated_and_backward_compatible(self):
        changed = self.assert_status(self.put(self.body(0, PhoneSecondaireEntite='  +243 81 000 00 00  ')))
        self.assertEqual(changed['PhoneSecondaireEntite'], '+243 81 000 00 00')
        self.assertEqual(self.profile(0, administration=True)['PhoneSecondaireEntite'], changed['PhoneSecondaireEntite'])
        old_payload = self.body(0, administration=True)
        old_payload.pop('PhoneSecondaireEntite')
        kept = self.assert_status(self.put(old_payload, administration=True))
        self.assertEqual(kept['PhoneSecondaireEntite'], changed['PhoneSecondaireEntite'])
        for invalid in ['1' * 21, '123\t456', '123\n456']:
            self.assert_status(self.put(self.body(0, PhoneSecondaireEntite=invalid)), 400)
        removed = self.assert_status(self.put(self.body(0, PhoneSecondaireEntite='')))
        self.assertIsNone(removed['PhoneSecondaireEntite'])


if __name__ == '__main__':
    suite = unittest.defaultTestLoader.loadTestsFromTestCase(EnterpriseIdentityAPI)
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    output = Path(os.environ.get('SAUVERNDEKO_TEST_PROOF', str(ROOT / '.runtime/identite-entreprise-api/verification.json')))
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps({'passed': result.wasSuccessful(), 'tests': result.testsRun, 'failures': len(result.failures), 'errors': len(result.errors),
        'database': location.path[1:], 'scope': 'trois entreprises fictives ; aucun appel à SauverNdeko',
        'sha256': {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest() for path in [ROOT / 'backend/apps/logistique/entity_documents.py', ROOT / 'backend/apps/core/repository.py', ROOT / 'backend/apps/core/views.py', ROOT / 'backend/apps/core/permissions.py', ROOT / 'backend/apps/core/models.py', ROOT / 'backend/apps/core/registry.json', ROOT / 'backend/config/urls.py']}}, ensure_ascii=False, indent=2), encoding='utf8')
    raise SystemExit(0 if result.wasSuccessful() else 1)
