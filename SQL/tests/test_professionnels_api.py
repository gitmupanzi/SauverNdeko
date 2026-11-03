"""Recette API réelle des professionnels, exclusivement sur PostgreSQL privé local.

Les fixtures ne sont jamais créées dans SauverNdeko. La licence reste contrôlée
par les permissions DRF ; les acteurs de recette couvrent ses restrictions.
"""
import base64
import io
import json
import os
from pathlib import Path
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor
import unittest
import unicodedata
from urllib.parse import urlsplit
import uuid
from contextlib import contextmanager

import psycopg
from psycopg.rows import dict_row

ROOT = Path(__file__).resolve().parents[2]
DSN = os.environ.get('SAUVERNDEKO_TEST_DATABASE_URL', '')
target = urlsplit(DSN)
if target.hostname not in {'127.0.0.1', 'localhost', '::1'} or not target.path.lstrip('/').startswith('sauverndeko_test_'):
    raise RuntimeError('Tests réservés à PostgreSQL privé local sauverndeko_test_*.')
with psycopg.connect(DSN) as connection:
    if not connection.execute('SELECT current_database()').fetchone()[0].startswith('sauverndeko_test_'):
        raise RuntimeError('Base privée obligatoire.')
os.environ.update(DATABASE_URL=DSN, DJANGO_SETTINGS_MODULE='config.settings', SAUVERNDEKO_DB_READ_ONLY='0')
sys.path.insert(0, str(ROOT/'backend'))
import django
django.setup()
from django.test import override_settings
from rest_framework.test import APIClient
from apps.accounts.authentication import Actor
from apps.core.module_access import WORKSPACE_MODULES
from apps.core import db

BASE = '/api/professionnels'


class ProfessionalsAPI(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.settings = override_settings(ALLOWED_HOSTS=['testserver'])
        cls.settings.enable()
        cls.sql = psycopg.connect(DSN, autocommit=True, row_factory=dict_row)
        cls.entities = [cls.sql.execute('INSERT INTO systeme."T_Entite"("NomEntite","EmailEntite","ValideEntite") VALUES(%s,%s,true) RETURNING "IdEntite" id',
             ['Experts recette '+uuid.uuid4().hex, uuid.uuid4().hex+'@example.invalid']).fetchone()['id'] for _ in range(2)]
        cls.admins = [cls.account(entity, admin=True) for entity in cls.entities]
        cls.global_user = cls.account(None, global_admin=True)
        cls.reader = cls.account(cls.entities[1])
        cls.typ = cls.ref('T_Professionnel', 'IdTypeProfessionnelFk')
        cls.sector = cls.ref('T_Professionnel', 'IdSecteurFk', 'SANTE')
        cls.skill = cls.ref('T_Professionnel_Competence', 'IdCompetenceFk', 'Oncologie')
        cls.service = cls.ref('T_Professionnel_Prestation', 'IdPrestationFk', 'Consultation médicale')

    @classmethod
    def tearDownClass(cls):
        cls.sql.close()
        cls.settings.disable()

    @classmethod
    def account(cls, entity, admin=False, global_admin=False):
        return cls.sql.execute('''INSERT INTO systeme."T_Utilisateurs"("NomUser","PrenomUser","EmailUser","PhoneUser","MotdepasseUser","ValideUser","SexeUser","Is_Admin","Is_staff","IdEntiteFk")
             VALUES(%s,'Expert',%s,'+243000000001','inutilisable',true,'M',%s,%s,%s) RETURNING *''',
             ['Recette '+uuid.uuid4().hex, uuid.uuid4().hex+'@example.invalid', global_admin, admin, entity]).fetchone()

    @classmethod
    def ref(cls, table, field, code=None):
        query = '''SELECT "ID_Generique" id FROM referentiel."T_Generique" WHERE "ID_CategorieGeneriqueFk"=ANY(referentiel.fn_categories_champ('professionnel',%s,%s,NULL)) AND "ValideGenerique" AND "IdEntiteFk" IS NULL'''
        params = [table, field]
        if code:
            query += ' AND "AbrGenerique"=%s'
            params.append(code)
        row = cls.sql.execute(query+' ORDER BY "ID_Generique" LIMIT 1', params).fetchone()
        if not row and code:
            # Le dictionnaire vivant peut afficher « Santé » au lieu de
            # l'ancien code SANTE : la recette ne réécrit aucune référence.
            normalize = lambda value: ''.join(char for char in unicodedata.normalize('NFKD', value or '')
                if not unicodedata.combining(char)).casefold()
            candidates = cls.sql.execute('''SELECT "ID_Generique" id,"AbrGenerique","NomGenerique"
                FROM referentiel."T_Generique" WHERE "ID_CategorieGeneriqueFk"=ANY(
                  referentiel.fn_categories_champ('professionnel',%s,%s,NULL))
                AND "ValideGenerique" AND "IdEntiteFk" IS NULL ORDER BY "ID_Generique"''',[table,field]).fetchall()
            matches = [item for item in candidates if normalize(code) in {normalize(item['AbrGenerique']),normalize(item['NomGenerique'])}]
            row = matches[0] if len(matches)==1 else None
        if not row:
            raise AssertionError('Référence de recette manquante : '+field+' '+str(code))
        return row['id']

    @classmethod
    def actor(cls, index=0, user=None, *, global_admin=False, all_entities=False, read=True, manage=True, discussions=True):
        actor = Actor(user or (cls.global_user if global_admin else cls.admins[index]))
        if global_admin and not all_entities:
            actor._context_entity = cls.entities[index]
        actor._module_access = {'modules': {item['key']: {'canRead': read,
            'canManage': manage if item['key'] != 'discussions' else discussions,
            'canExport': read, 'reason': '' if read else 'MODULE_ROLE_FORBIDDEN'} for item in WORKSPACE_MODULES}}
        return actor

    @classmethod
    def client(cls, index=0, **rights):
        client = APIClient()
        client.force_authenticate(cls.actor(index, **rights))
        return client

    def create(self, user=None, **changes):
        user = user or self.account(self.entities[0])
        data = {'IdUserFk': user['IdUser'], 'IdTypeProfessionnelFk': self.typ, 'IdSecteurFk': self.sector,
                'TitrePublic': 'Profil de recette', 'PresentationPublique': 'Description publique de recette.',
                'LocalitePublique': 'Kinshasa', 'NumeroIdentification': 'NE-JAMAIS-PUBLIER-'+uuid.uuid4().hex[:16], 'ObsProfessionnel': 'NOTE-INTERNE-SECRETE',
                'ExperienceAns': 8, 'ContactAutorise': True}
        data.update(changes)
        body = {'data': data, 'competenceIds': [self.skill], 'prestationIds': [self.service], 'affiliations': [], 'requestId': str(uuid.uuid4())}
        result = self.client().post(BASE+'/profils', body, format='json')
        self.assertEqual(result.status_code, 201, result.data)
        return result.data['data'], body

    def action(self, profile, operation, *, client=None, status=200):
        body = {'action': operation, '_version': profile['_version'], 'motif': 'Vérification de recette', 'requestId': str(uuid.uuid4())}
        result = (client or self.client()).post(BASE+'/profils/'+str(profile['record']['IdProfessionnel'])+'/actions', body, format='json')
        self.assertEqual(result.status_code, status, result.data)
        return result.data['data'], body

    @staticmethod
    def image_url(kind='PNG', color=(50, 120, 180)):
        from PIL import Image
        stream = io.BytesIO()
        Image.new('RGB', (20, 20), color).save(stream, format=kind)
        mime = {'JPEG': 'jpeg', 'PNG': 'png', 'WEBP': 'webp'}[kind]
        return 'data:image/'+mime+';base64,'+base64.b64encode(stream.getvalue()).decode('ascii')

    @contextmanager
    def photo_media(self):
        with tempfile.TemporaryDirectory(prefix='prof-photo-tests-') as folder, override_settings(ARTICLE_MEDIA_ROOT=folder):
            yield Path(folder)

    def create_photo(self, photo=None, *, user=None, client=None, **extra):
        user = user or self.account(self.entities[0])
        body = {'data': {'IdUserFk': user['IdUser'], 'IdTypeProfessionnelFk': self.typ,
            'IdSecteurFk': self.sector, 'TitrePublic': 'Profil fictif avec photo', 'PresentationPublique': 'Description de recette uniquement.'},
            'photoDataUrl': photo or self.image_url(), 'requestId': str(uuid.uuid4()), **extra}
        response = (client or self.client()).post(BASE+'/profils', body, format='json')
        self.assertEqual(response.status_code, 201, response.data)
        return response.data['data'], body

    def photo_update(self, profile, **extra):
        body = {'data': {}, '_version': profile['_version'], 'motif': 'Photo de recette contrôlée', 'requestId': str(uuid.uuid4()), **extra}
        response = self.client().put(BASE+'/profils/'+str(profile['record']['IdProfessionnel']), body, format='json')
        self.assertEqual(response.status_code, 200, response.data)
        return response.data['data'], body

    def photo_source(self, user):
        return self.sql.execute('SELECT "UrlPhoto" FROM systeme."T_Utilisateurs" WHERE "IdUser"=%s', [user]).fetchone()['UrlPhoto']

    def test_01_authentication_permissions_context(self):
        self.assertEqual(APIClient().get(BASE+'/annuaire').status_code, 401)
        self.assertEqual(self.client(read=False).get(BASE+'/annuaire').status_code, 403)
        self.assertEqual(self.client(user=self.reader).get(BASE+'/profils').status_code, 403)
        context = self.client(global_admin=True, all_entities=True).get(BASE+'/contexte').data['data']
        self.assertTrue(context['canReadRegistry'])
        self.assertFalse(context['canManage'])
        self.assertEqual(self.client(global_admin=True, all_entities=True).post(BASE+'/profils', {'data': {}, 'requestId': str(uuid.uuid4())}, format='json').status_code, 409)
        references = self.client(user=self.reader).get(BASE+'/references').data['data']
        self.assertEqual(references['users'], [])

    def test_02_create_replay_and_private_draft(self):
        profile, body = self.create()
        pk = profile['record']['IdProfessionnel']
        self.assertFalse(profile['record']['Publie'])
        self.assertEqual(self.client(user=self.reader).get(BASE+'/annuaire/'+str(pk)).status_code, 404)
        replay = self.client().post(BASE+'/profils', body, format='json')
        self.assertEqual(replay.status_code, 201, replay.data)
        self.assertTrue(replay.data['data']['replayed'])
        self.assertEqual(replay.data['data']['record']['IdProfessionnel'], pk)
        self.assertEqual(self.client(index=1).get(BASE+'/profils/'+str(pk)).status_code, 404)
        denied = self.client().post(BASE+'/profils', {**body, 'data': {**body['data'], 'TitrePublic': 'Rejeu différent'}}, format='json')
        self.assertEqual(denied.status_code, 409)
        self.assertNotIn('CreationPayloadHash', profile['record'])

    def test_03_publication_need_search_privacy_and_compatibility(self):
        profile, _ = self.create()
        pk = profile['record']['IdProfessionnel']
        published, _ = self.action(profile, 'publier')
        result = self.client(user=self.reader).get(BASE+'/annuaire', {'q': 'cancer', 'take': 100})
        self.assertEqual(result.status_code, 200, result.data)
        self.assertIn(pk, [r['id'] for r in result.data['data']['rows']])
        result = self.client(user=self.reader).get(BASE+'/annuaire/'+str(pk))
        serialized = json.dumps(result.data)
        for private in ['NOTE-INTERNE-SECRETE', 'NE-JAMAIS-PUBLIER', 'EmailUser', 'PhoneUser', 'MotdepasseUser', 'CreationPayloadHash', 'RechercheVecteur']:
            self.assertNotIn(private, serialized)
        self.assertEqual(result.data['data']['record']['locality'], 'Kinshasa')
        self.assertTrue(result.data['data']['canContact'])
        compat = self.client(user=self.reader).get('/api/public/experts', {'q': 'cancer', 'take': 100})
        self.assertEqual(compat.status_code, 200, compat.data)
        self.assertIn(pk, [r['id'] for r in compat.data['data']])
        hidden, _ = self.action(published, 'depublier')
        self.assertEqual(self.client(user=self.reader).get(BASE+'/annuaire/'+str(pk)).status_code, 404)

    def test_04_child_error_rolls_back_parent_and_details(self):
        user = self.account(self.entities[0])
        body = {'data': {'IdUserFk': user['IdUser'], 'IdTypeProfessionnelFk': self.typ},
                'competenceIds': [2147483647], 'requestId': str(uuid.uuid4())}
        denied = self.client().post(BASE+'/profils', body, format='json')
        self.assertEqual(denied.status_code, 422, denied.data)
        self.assertEqual(self.sql.execute('SELECT count(*) n FROM professionnel."T_Professionnel" WHERE "IdUserFk"=%s', [user['IdUser']]).fetchone()['n'], 0)

    def test_05_update_reload_same_form_revision_replay(self):
        profile, _ = self.create()
        pk = profile['record']['IdProfessionnel']
        body = {'data': {'TitrePublic': 'Titre corrigé'}, 'competenceIds': [], 'prestationIds': [],
                'affiliations': [], 'motif': 'Correction documentée', '_version': profile['_version'], 'requestId': str(uuid.uuid4())}
        path = BASE+'/profils/'+str(pk)
        updated = self.client().put(path, body, format='json')
        self.assertEqual(updated.status_code, 200, updated.data)
        self.assertEqual(updated.data['data']['record']['TitrePublic'], 'Titre corrigé')
        self.assertEqual(updated.data['data']['record']['competenceIds'], [])
        replay = self.client().put(path, body, format='json')
        self.assertEqual(replay.status_code, 200, replay.data)
        self.assertTrue(replay.data['data']['replayed'])
        stale = self.client().put(path, {**body, 'requestId': str(uuid.uuid4())}, format='json')
        self.assertEqual(stale.status_code, 409)
        self.assertEqual(stale.data['error']['code'], 'STALE_REVISION')

    def test_06_owner_user_immutability_and_duplicate(self):
        profile, body = self.create()
        self.assertEqual(self.client().post(BASE+'/profils', {**body, 'requestId': str(uuid.uuid4())}, format='json').status_code, 409)
        bad = {'data': {**body['data'], 'IdUserFk': self.account(self.entities[1])['IdUser']}, 'requestId': str(uuid.uuid4())}
        self.assertEqual(self.client().post(BASE+'/profils', bad, format='json').status_code, 403)
        with self.assertRaises(Exception) as denied:
            from apps.core.repository import _mutate
            _mutate('T_Professionnel', self.actor(), body={'IdUserFk': self.reader['IdUser']})
        self.assertEqual(denied.exception.status_code, 405)

    def test_07_contact_published_toggle_self_and_thread_replay(self):
        user = self.account(self.entities[0])
        profile, _ = self.create(user)
        pk = profile['record']['IdProfessionnel']
        reader = self.client(user=self.reader)
        self.assertEqual(reader.post('/api/discussions/start', {'type': 'expert', 'targetId': pk}, format='json').status_code, 404)
        profile, _ = self.action(profile, 'publier')
        self.assertFalse(self.client(user=user).get(BASE+'/annuaire/'+str(pk)).data['data']['canContact'])
        self.assertEqual(self.client(user=user).post('/api/discussions/start', {'type': 'expert', 'targetId': pk}, format='json').status_code, 409)
        created = reader.post('/api/discussions/start', {'type': 'expert', 'targetId': pk}, format='json')
        self.assertEqual(created.status_code, 201, created.data)
        repeat = reader.post('/api/discussions/start', {'type': 'expert', 'targetId': pk}, format='json')
        self.assertEqual(repeat.status_code, 200, repeat.data)
        self.assertEqual(created.data['data']['IdDiscussion'], repeat.data['data']['IdDiscussion'])
        unrelated = self.client(index=0).get('/api/discussions/'+str(created.data['data']['IdDiscussion'])+'/messages')
        self.assertEqual(unrelated.status_code, 404)
        updated = self.client().put(BASE+'/profils/'+str(pk), {'data': {'ContactAutorise': False},
            '_version': profile['_version'], 'requestId': str(uuid.uuid4()), 'motif': 'Contact désactivé'}, format='json')
        self.assertEqual(updated.status_code, 200, updated.data)
        self.assertEqual(reader.post('/api/discussions/start', {'type': 'expert', 'targetId': pk}, format='json').status_code, 409)
        self.assertEqual(reader.get('/api/discussions/'+str(created.data['data']['IdDiscussion'])+'/messages').status_code, 200)

    def test_08_archive_reactivate_requires_republication(self):
        profile, _ = self.create()
        profile, _ = self.action(profile, 'publier')
        archived, _ = self.action(profile, 'archiver')
        self.assertFalse(archived['record']['ValideProfessionnel'])
        self.assertFalse(archived['record']['Publie'])
        active, _ = self.action(archived, 'reactiver')
        self.assertTrue(active['record']['ValideProfessionnel'])
        self.assertFalse(active['record']['Publie'])
        self.assertEqual(self.client().delete(BASE+'/profils/'+str(profile['record']['IdProfessionnel'])).status_code, 405)

    def test_09_affiliations_dates_public_and_private_notes(self):
        profile, _ = self.create()
        pk = profile['record']['IdProfessionnel']
        body = {'data': {}, 'affiliations': [{'IdEntiteFk': self.entities[1], 'IdTypeLienFk': None,
                 'EstPrincipal': True, 'DateDebut': '2020-01-01T08:00:00', 'DateFin': None, 'ObsLien': 'AFFILIATION-PRIVEE'}],
                 '_version': profile['_version'], 'requestId': str(uuid.uuid4()), 'motif': 'Affiliation confirmée'}
        updated = self.client().put(BASE+'/profils/'+str(pk), body, format='json')
        self.assertEqual(updated.status_code, 200, updated.data)
        profile, _ = self.action(updated.data['data'], 'publier')
        public = self.client(user=self.reader).get(BASE+'/annuaire/'+str(pk))
        self.assertEqual(public.data['data']['record']['structures'][0]['id'], self.entities[1])
        self.assertNotIn('AFFILIATION-PRIVEE', json.dumps(public.data))
        body['affiliations'][0]['DateFin'] = '2019-01-01T08:00:00'
        invalid = self.client().put(BASE+'/profils/'+str(pk), {**body, '_version': profile['_version'], 'requestId': str(uuid.uuid4())}, format='json')
        self.assertEqual(invalid.status_code, 422)

    def test_10_readonly_and_no_discussion_capability(self):
        profile, _ = self.create()
        profile, _ = self.action(profile, 'publier')
        self.assertFalse(self.client(user=self.reader, discussions=False).get(BASE+'/annuaire/'+str(profile['record']['IdProfessionnel'])).data['data']['canContact'])
        with override_settings(DB_READ_ONLY=True):
            self.assertFalse(self.client().get(BASE+'/contexte').data['data']['canManage'])
            self.assertFalse(self.client(user=self.reader).get(BASE+'/annuaire/'+str(profile['record']['IdProfessionnel'])).data['data']['canContact'])
            self.assertEqual(self.client().post(BASE+'/profils', {'data': {}, 'requestId': str(uuid.uuid4())}, format='json').status_code, 503)

    def test_11_dynamic_reference_preserves_incompatible_then_restores(self):
        profile, _ = self.create()
        pk = profile['record']['IdProfessionnel']
        family = self.sql.execute('INSERT INTO referentiel."T_CategorieGenerique"("NomCategorieGenerique","ValideCategorieGenerique") VALUES(%s,true) RETURNING "ID_CategorieGenerique" id',
             ['Compétences recette '+uuid.uuid4().hex]).fetchone()['id']
        replacement = self.sql.execute('INSERT INTO referentiel."T_Generique"("ID_CategorieGeneriqueFk","NomGenerique","AbrGenerique","ValideGenerique") VALUES(%s,%s,%s,true) RETURNING "ID_Generique" id',
             [family, 'Valeur de recette '+uuid.uuid4().hex, 'Nouvelle valeur']).fetchone()['id']
        field = self.sql.execute('SELECT "ID_ChampReferentiel" id FROM referentiel."T_ChampReferentiel" WHERE "SchemaName"=%s AND "TableName"=%s AND "ColumnName"=%s',
             ['professionnel', 'T_Professionnel_Competence', 'IdCompetenceFk']).fetchone()['id']
        global_client = self.client(global_admin=True)
        url = '/api/referentiel/champs-references/'+str(field)
        scope = {'scope': 'entity', 'scopeValue': str(self.entities[0])}
        previous = global_client.get(url, scope)
        self.assertEqual(previous.status_code, 200, previous.data)
        configured = global_client.put(url, {**scope, '_version': previous.data['data']['_version'],
             'categoryIds': [family], 'motif': 'Correspondance de recette', 'requestId': str(uuid.uuid4())}, format='json')
        self.assertEqual(configured.status_code, 200, configured.data)
        try:
            choices = self.client().get(BASE+'/references', {'profileId': pk}).data['data']
            self.assertEqual(choices['referenceMeta']['competences']['categoryIds'], [family])
            retained = next(v for v in choices['competences'] if v['id'] == self.skill)
            self.assertTrue(retained['disabled'])
            self.assertTrue(retained['incompatible'])
            self.assertTrue(any(v['id'] == replacement and not v['disabled'] for v in choices['competences']))
            updated = self.client().put(BASE+'/profils/'+str(pk), {'data': {'TitrePublic': 'Titre sans reclassement'},
                 'competenceIds': [self.skill], '_version': profile['_version'], 'requestId': str(uuid.uuid4()), 'motif': 'Conservation historique'}, format='json')
            self.assertEqual(updated.status_code, 200, updated.data)
            self.assertEqual(updated.data['data']['record']['competenceIds'], [self.skill])
            user = self.account(self.entities[0])
            invalid = self.client().post(BASE+'/profils', {'data': {'IdUserFk': user['IdUser'], 'IdTypeProfessionnelFk': self.typ},
                 'competenceIds': [self.skill], 'requestId': str(uuid.uuid4())}, format='json')
            self.assertEqual(invalid.status_code, 422, invalid.data)
        finally:
            current = global_client.get(url, scope).data['data']
            restored = global_client.post(url+'/retablir', {**scope, '_version': current['_version'],
                 'motif': 'Retour à la configuration standard', 'requestId': str(uuid.uuid4())}, format='json')
            self.assertEqual(restored.status_code, 200, restored.data)
        restored_choices = self.client().get(BASE+'/references', {'profileId': pk}).data['data']
        self.assertFalse(next(v for v in restored_choices['competences'] if v['id'] == self.skill)['incompatible'])

    def test_12_pagination_sort_filters_and_invalid_inputs(self):
        profile, _ = self.create()
        pk = profile['record']['IdProfessionnel']
        profile, _ = self.action(profile, 'publier')
        query = {'q': profile['record']['NomUser'], 'sectorId': self.sector, 'competenceId': self.skill,
                 'prestationId': self.service, 'locality': 'Kinshasa', 'sortBy': 'fullName', 'sortDir': 'asc', 'take': 1}
        first = self.client(user=self.reader).get(BASE+'/annuaire', query)
        self.assertEqual(first.status_code, 200, first.data)
        self.assertEqual(first.data['data']['total'], 1)
        self.assertEqual(first.data['data']['rows'][0]['id'], pk)
        second = self.client(user=self.reader).get(BASE+'/annuaire', {**query, 'skip': 1})
        self.assertEqual(second.data['data']['rows'], [])
        self.assertEqual(second.data['data']['total'], 1)
        self.assertEqual(self.client().get(BASE+'/annuaire', {'sortBy': 'EmailUser'}).status_code, 422)
        self.assertEqual(self.client().get(BASE+'/annuaire', {'q': 'x'*301}).status_code, 422)
        self.assertEqual(self.client().get(BASE+'/profils', {'published': 'true', 'active': 'true'}).status_code, 200)

    def test_13_photo_only_while_published_and_safe_public_url(self):
        profile, body = self.create()
        pk, user = profile['record']['IdProfessionnel'], body['data']['IdUserFk']
        relative = 'Profils/'+str(user)+'_'+uuid.uuid4().hex+'.jpg'
        self.sql.execute('UPDATE systeme."T_Utilisateurs" SET "UrlPhoto"=%s WHERE "IdUser"=%s', [relative, user])
        url = BASE+'/annuaire/'+str(pk)+'/photo'
        with tempfile.TemporaryDirectory(prefix='experts-photo-') as folder, override_settings(ARTICLE_MEDIA_ROOT=folder):
            target = Path(folder)/relative
            target.parent.mkdir()
            target.write_bytes(b'photo-fictive-privee')
            self.assertEqual(self.client(user=self.reader).get(url).status_code, 404)
            profile, _ = self.action(profile, 'publier')
            public = self.client(user=self.reader).get(BASE+'/annuaire/'+str(pk)).data['data']['record']
            self.assertTrue(public['photo'].startswith(url+'?v='))
            self.assertNotIn(relative, json.dumps(public))
            image = self.client(user=self.reader).get(url, HTTP_ACCEPT='image/jpeg')
            self.assertEqual(image.status_code, 200)
            self.assertEqual(b''.join(image.streaming_content), b'photo-fictive-privee')
            self.assertEqual(image['Cache-Control'], 'no-store, private')
            self.action(profile, 'depublier')
            self.assertEqual(self.client(user=self.reader).get(url).status_code, 404)

    def test_14_publication_incomplete_returns_field_validation(self):
        profile, _ = self.create(TitrePublic=None)
        result = self.client().post(BASE+'/profils/'+str(profile['record']['IdProfessionnel'])+'/actions',
            {'action': 'publier', '_version': profile['_version'], 'requestId': str(uuid.uuid4()), 'motif': 'Vérification'}, format='json')
        self.assertEqual(result.status_code, 422, result.data)
        self.assertIn('TitrePublic', result.data['error']['details'])
        self.assertFalse(self.client().get(BASE+'/profils/'+str(profile['record']['IdProfessionnel'])).data['data']['record']['Publie'])

    def test_15_affiliation_never_grants_private_conversation_access(self):
        user = self.account(self.entities[0])
        profile, _ = self.create(user)
        pk = profile['record']['IdProfessionnel']
        updated = self.client().put(BASE+'/profils/'+str(pk), {'data': {},
            'affiliations': [{'IdEntiteFk': self.entities[1], 'EstPrincipal': True}],
            '_version': profile['_version'], 'requestId': str(uuid.uuid4()), 'motif': 'Exercice dans une autre structure'}, format='json')
        self.assertEqual(updated.status_code, 200, updated.data)
        profile, _ = self.action(updated.data['data'], 'publier')
        third = self.sql.execute('INSERT INTO systeme."T_Entite"("NomEntite","EmailEntite","ValideEntite") VALUES(%s,%s,true) RETURNING "IdEntite" id',
            ['Client recette '+uuid.uuid4().hex, uuid.uuid4().hex+'@example.invalid']).fetchone()['id']
        visitor = self.account(third)
        client = self.client(user=visitor)
        created = client.post('/api/discussions/start', {'type': 'expert', 'targetId': pk}, format='json')
        self.assertEqual(created.status_code, 201, created.data)
        conversation = created.data['data']['IdDiscussion']
        stored = self.sql.execute('SELECT "IdProfessionnelFk","IdEntiteFk" FROM communication."T_Discussion" WHERE "IdDiscussion"=%s', [conversation]).fetchone()
        self.assertEqual(stored['IdProfessionnelFk'], pk)
        self.assertIsNone(stored['IdEntiteFk'])
        path = '/api/discussions/'+str(conversation)+'/messages'
        for unrelated in [self.client(index=0), self.client(index=1)]:
            self.assertEqual(unrelated.get(path).status_code, 404)
            self.assertEqual(unrelated.post(path, {'message': 'Non autorisé'}, format='json').status_code, 404)
        self.assertEqual(client.post(path, {'message': 'Question de recette privée'}, format='json').status_code, 201)
        self.assertEqual(self.client(user=user).get(path).status_code, 200)

    def test_16_concurrent_replay_and_stale_write(self):
        user = self.account(self.entities[0])
        body = {'data': {'IdUserFk': user['IdUser'], 'IdTypeProfessionnelFk': self.typ}, 'requestId': str(uuid.uuid4())}
        def send_create(_):
            from django.db import connections
            try:
                result = self.client().post(BASE+'/profils', body, format='json')
                return result.status_code, result.data
            finally:
                connections.close_all()
        with ThreadPoolExecutor(max_workers=2) as pool:
            results = list(pool.map(send_create, [0, 1]))
        self.assertEqual([r[0] for r in results], [201, 201], results)
        identifiers = [r[1]['data']['record']['IdProfessionnel'] for r in results]
        self.assertEqual(len(set(identifiers)), 1)
        profile = results[0][1]['data']
        def send_update(index):
            from django.db import connections
            try:
                result = self.client().put(BASE+'/profils/'+str(identifiers[0]), {'data': {'TitrePublic': 'Titre concurrent '+str(index)},
                    '_version': profile['_version'], 'requestId': str(uuid.uuid4()), 'motif': 'Modification concurrente'}, format='json')
                return result.status_code, result.data
            finally:
                connections.close_all()
        with ThreadPoolExecutor(max_workers=2) as pool:
            updates = list(pool.map(send_update, [0, 1]))
        self.assertEqual(sorted(r[0] for r in updates), [200, 409], updates)

    def test_17_inactive_current_references_remain_editable_without_reassignment(self):
        profile, body = self.create()
        pk = profile['record']['IdProfessionnel']
        target = self.sql.execute('INSERT INTO systeme."T_Entite"("NomEntite","EmailEntite","ValideEntite") VALUES(%s,%s,true) RETURNING "IdEntite" id',
            ['Structure ancienne '+uuid.uuid4().hex, uuid.uuid4().hex+'@example.invalid']).fetchone()['id']
        updated = self.client().put(BASE+'/profils/'+str(pk), {'data': {}, 'affiliations': [{'IdEntiteFk': target}],
            '_version': profile['_version'], 'requestId': str(uuid.uuid4()), 'motif': 'Ancienne affiliation'}, format='json')
        self.assertEqual(updated.status_code, 200, updated.data)
        self.sql.execute('UPDATE systeme."T_Entite" SET "ValideEntite"=false WHERE "IdEntite"=%s', [target])
        self.sql.execute('UPDATE systeme."T_Utilisateurs" SET "ValideUser"=false WHERE "IdUser"=%s', [body['data']['IdUserFk']])
        choices = self.client().get(BASE+'/references', {'profileId': pk})
        self.assertEqual(choices.status_code, 200, choices.data)
        self.assertTrue(next(v for v in choices.data['data']['entities'] if v['id'] == target)['disabled'])
        self.assertTrue(next(v for v in choices.data['data']['users'] if v['id'] == body['data']['IdUserFk'])['disabled'])
        saved = self.client().put(BASE+'/profils/'+str(pk), {'data': {'TitrePublic': 'Titre historique conservé'},
            'competenceIds': [self.skill], 'affiliations': [{'IdEntiteFk': target}],
            '_version': updated.data['data']['_version'], 'requestId': str(uuid.uuid4()), 'motif': 'Correction descriptive'}, format='json')
        self.assertEqual(saved.status_code, 200, saved.data)
        self.assertEqual(saved.data['data']['record']['affiliations'][0]['IdEntiteFk'], target)

    def test_18_global_represents_only_self_and_runtime_license_enforced(self):
        client = self.client(global_admin=True)
        body = {'data': {'IdUserFk': self.global_user['IdUser'], 'IdTypeProfessionnelFk': self.typ}, 'requestId': str(uuid.uuid4())}
        created = client.post(BASE+'/profils', body, format='json')
        self.assertEqual(created.status_code, 201, created.data)
        outsider = self.account(None, global_admin=True)
        forbidden = client.post(BASE+'/profils', {'data': {'IdUserFk': outsider['IdUser'], 'IdTypeProfessionnelFk': self.typ}, 'requestId': str(uuid.uuid4())}, format='json')
        self.assertEqual(forbidden.status_code, 403)
        actual_global = APIClient()
        actual_global.force_authenticate(Actor(self.global_user))
        caps = actual_global.get(BASE+'/contexte')
        self.assertEqual(caps.status_code, 200, caps.data)
        self.assertTrue(caps.data['data']['canReadRegistry'])
        self.assertFalse(caps.data['data']['canManage'])
        actual_unlicensed = APIClient()
        actual_unlicensed.force_authenticate(Actor(self.reader))
        refused = actual_unlicensed.get(BASE+'/annuaire')
        self.assertEqual(refused.status_code, 403, refused.data)
        self.assertIn(refused.data['error']['code'], {'MODULE_NOT_INCLUDED', 'LICENCE_INACTIVE'})

    def test_19_direct_child_revision_rejects_stale_form_and_replays_final_version(self):
        profile, creation = self.create()
        pk = profile['record']['IdProfessionnel']
        initial_version = int(profile['_version'])
        family = self.sql.execute('SELECT unnest(referentiel.fn_categories_champ(%s,%s,%s,%s)) id',
            ['professionnel', 'T_Professionnel_Competence', 'IdCompetenceFk', self.entities[0]]).fetchone()['id']
        extra = self.sql.execute('''INSERT INTO referentiel."T_Generique"("ID_CategorieGeneriqueFk","NomGenerique","AbrGenerique","ValideGenerique")
            VALUES(%s,%s,%s,true) RETURNING "ID_Generique" id''',
            [family, 'Compétence fictive '+uuid.uuid4().hex, 'Recette SQL '+uuid.uuid4().hex[:12]]).fetchone()['id']
        self.sql.execute('INSERT INTO professionnel."T_Professionnel_Competence"("IdProfessionnelFk","IdCompetenceFk") VALUES(%s,%s)', [pk, extra])
        current = self.client().get(BASE+'/profils/'+str(pk)).data['data']
        self.assertGreater(int(current['_version']), initial_version)
        stale_body = {'data': {'TitrePublic': 'Ne doit pas écraser la fiche'}, 'competenceIds': [self.skill],
            '_version': profile['_version'], 'requestId': str(uuid.uuid4()), 'motif': 'Ancienne fiche après détail SQL'}
        stale = self.client().put(BASE+'/profils/'+str(pk), stale_body, format='json')
        self.assertEqual(stale.status_code, 409, stale.data)
        self.assertEqual(stale.data['error']['code'], 'STALE_REVISION')
        retained = self.client().get(BASE+'/profils/'+str(pk)).data['data']
        self.assertEqual(set(retained['record']['competenceIds']), {self.skill, extra})
        self.assertNotEqual(retained['record']['TitrePublic'], stale_body['data']['TitrePublic'])
        replay_creation = self.client().post(BASE+'/profils', creation, format='json')
        self.assertEqual(replay_creation.status_code, 201, replay_creation.data)
        self.assertTrue(replay_creation.data['data']['replayed'])
        self.assertEqual(replay_creation.data['data']['_version'], current['_version'])
        body = {'data': {'TitrePublic': 'Fiche relue puis corrigée'}, 'competenceIds': [], 'prestationIds': [],
            '_version': current['_version'], 'requestId': str(uuid.uuid4()), 'motif': 'Mise à jour après relecture'}
        updated = self.client().put(BASE+'/profils/'+str(pk), body, format='json')
        self.assertEqual(updated.status_code, 200, updated.data)
        self.assertGreater(int(updated.data['data']['_version']), int(current['_version'])+1)
        replay_update = self.client().put(BASE+'/profils/'+str(pk), body, format='json')
        self.assertEqual(replay_update.status_code, 200, replay_update.data)
        self.assertTrue(replay_update.data['data']['replayed'])
        self.assertEqual(replay_update.data['data']['_version'], updated.data['data']['_version'])
        self.assertEqual(replay_update.data['data']['record']['competenceIds'], [])

    def test_20_photo_creation_draft_private_and_public_normalized_jpeg(self):
        from PIL import Image
        with self.photo_media() as folder:
            profile, body = self.create_photo()
            pk, user = profile['record']['IdProfessionnel'], body['data']['IdUserFk']
            source = self.photo_source(user)
            self.assertTrue(source.startswith('Profils/'+str(user)+'_'))
            self.assertTrue(source.endswith('.jpg'))
            self.assertTrue((folder/source).exists())
            with Image.open(folder/source) as image:
                self.assertEqual(image.format, 'JPEG')
            private = BASE+'/profils/'+str(pk)+'/photo'
            self.assertTrue(profile['record']['photo'].startswith(private+'?v='))
            self.assertTrue(profile['record']['photoSharedWithAccount'])
            self.assertEqual(APIClient().get(private).status_code, 401)
            self.assertEqual(self.client(user=self.reader).get(private).status_code, 403)
            self.assertEqual(self.client(index=1).get(private).status_code, 404)
            image = self.client().get(private, HTTP_ACCEPT='image/jpeg')
            self.assertEqual(image.status_code, 200)
            self.assertEqual(image['Content-Type'], 'image/jpeg')
            self.assertTrue(b''.join(image.streaming_content).startswith(b'\xff\xd8'))
            refreshed = self.sql.execute('SELECT * FROM systeme."T_Utilisateurs" WHERE "IdUser"=%s', [user]).fetchone()
            account_photo = self.client(user=refreshed).get('/SauverNdeko/auth/me/photo', HTTP_ACCEPT='image/jpeg')
            self.assertEqual(account_photo.status_code, 200, getattr(account_photo, 'data', None))
            self.assertEqual(b''.join(account_photo.streaming_content), (folder/source).read_bytes())
            public = BASE+'/annuaire/'+str(pk)+'/photo'
            self.assertEqual(self.client(user=self.reader).get(public).status_code, 404)
            profile, _ = self.action(profile, 'publier')
            published = self.client(user=self.reader).get(BASE+'/annuaire/'+str(pk)).data['data']['record']
            self.assertTrue(published['photo'].startswith(public+'?v='))
            image = self.client(user=self.reader).get(published['photo'], HTTP_ACCEPT='image/jpeg')
            self.assertEqual(image.status_code, 200)
            self.assertEqual(b''.join(image.streaming_content), (folder/source).read_bytes())
            serialized = json.dumps(published)
            self.assertNotIn(source, serialized)
            self.assertNotIn(body['photoDataUrl'], serialized)

    def test_21_replace_remove_commit_and_uuid_replays(self):
        with self.photo_media() as folder:
            profile, creation = self.create_photo()
            pk, user = profile['record']['IdProfessionnel'], creation['data']['IdUserFk']
            original = self.photo_source(user)
            original_url = profile['record']['photo']
            profile, _ = self.action(profile, 'publier')
            changed, payload = self.photo_update(profile, photoDataUrl=self.image_url('JPEG', (180, 80, 30)))
            replacement = self.photo_source(user)
            self.assertNotEqual(replacement, original)
            self.assertFalse((folder/original).exists())
            self.assertTrue((folder/replacement).exists())
            self.assertNotEqual(changed['record']['photo'], original_url)
            self.assertTrue(changed['record']['Publie'])
            replay = self.client().put(BASE+'/profils/'+str(pk), payload, format='json')
            self.assertEqual(replay.status_code, 200, replay.data)
            self.assertTrue(replay.data['data']['replayed'])
            self.assertEqual(self.photo_source(user), replacement)
            self.assertEqual(len(list(folder.rglob('*.jpg'))), 1)
            removed, payload = self.photo_update(changed, removePhoto=True)
            self.assertEqual(removed['record']['photo'], '')
            self.assertIsNone(self.photo_source(user))
            self.assertFalse((folder/replacement).exists())
            self.assertTrue(removed['record']['Publie'])
            replay = self.client().put(BASE+'/profils/'+str(pk), payload, format='json')
            self.assertEqual(replay.status_code, 200, replay.data)
            self.assertTrue(replay.data['data']['replayed'])
            self.assertEqual(list(folder.rglob('*.jpg')), [])
            self.assertEqual(self.client(user=self.reader).get(BASE+'/annuaire/'+str(pk)+'/photo').status_code, 404)

    def test_22_missing_or_null_photo_preserves_current_account_photo(self):
        with self.photo_media() as folder:
            profile, creation = self.create_photo()
            user = creation['data']['IdUserFk']
            original = self.photo_source(user)
            profile, _ = self.photo_update(profile, data={'TitrePublic': 'Titre corrigé sans photo'})
            self.assertEqual(self.photo_source(user), original)
            profile, _ = self.photo_update(profile, photoDataUrl=None, removePhoto=None)
            self.assertEqual(self.photo_source(user), original)
            self.assertTrue((folder/original).exists())
            proof = self.sql.execute('''SELECT count(*) n FROM systeme."T_Audit_Log" WHERE "TableName"='systeme.T_Utilisateurs'
                AND "Operation"='PROFESSIONAL_PHOTO_CHANGE' AND "NewData"->>'IdUser'=%s''', [str(user)]).fetchone()
            self.assertEqual(proof['n'], 1)

    def test_23_photo_rollback_for_failed_creation_and_replacement(self):
        with self.photo_media() as folder:
            user = self.account(self.entities[0])
            bad = {'data': {'IdUserFk': user['IdUser'], 'IdTypeProfessionnelFk': self.typ},
                'photoDataUrl': self.image_url(), 'competenceIds': [2147483647], 'requestId': str(uuid.uuid4())}
            response = self.client().post(BASE+'/profils', bad, format='json')
            self.assertEqual(response.status_code, 422, response.data)
            self.assertIsNone(self.photo_source(user['IdUser']))
            self.assertEqual(list(folder.rglob('*.jpg')), [])
            self.assertEqual(self.sql.execute('SELECT count(*) n FROM professionnel."T_Professionnel" WHERE "IdUserFk"=%s', [user['IdUser']]).fetchone()['n'], 0)
            profile, creation = self.create_photo()
            pk, user = profile['record']['IdProfessionnel'], creation['data']['IdUserFk']
            original = self.photo_source(user)
            for change in [{'photoDataUrl': self.image_url('JPEG')}, {'removePhoto': True}]:
                body = {'data': {}, '_version': profile['_version'], 'requestId': str(uuid.uuid4()), 'motif': 'Échec atomique de recette',
                    'competenceIds': [2147483647], **change}
                response = self.client().put(BASE+'/profils/'+str(pk), body, format='json')
                self.assertEqual(response.status_code, 422, response.data)
                self.assertEqual(self.photo_source(user), original)
                self.assertTrue((folder/original).exists())
                self.assertEqual(len(list(folder.rglob('*.jpg'))), 1)
                self.assertEqual(self.client().get(BASE+'/profils/'+str(pk)).data['data']['_version'], profile['_version'])

    def test_24_photo_permissions_never_modify_other_company_or_platform_account(self):
        with self.photo_media() as folder:
            profile, creation = self.create_photo()
            pk, user = profile['record']['IdProfessionnel'], creation['data']['IdUserFk']
            original = self.photo_source(user)
            payload = {'data': {}, 'photoDataUrl': self.image_url(), '_version': profile['_version'], 'requestId': str(uuid.uuid4()), 'motif': 'Tentative hors périmètre'}
            self.assertEqual(self.client(index=1).put(BASE+'/profils/'+str(pk), payload, format='json').status_code, 404)
            self.assertEqual(self.client(manage=False).put(BASE+'/profils/'+str(pk), payload, format='json').status_code, 403)
            self.assertEqual(self.photo_source(user), original)
            self.assertEqual(len(list(folder.rglob('*.jpg'))), 1)
            global_account = self.account(None, global_admin=True)
            global_client = self.client(user=global_account, global_admin=True)
            protected, creation = self.create_photo(user=global_account, client=global_client)
            payload.update(_version=protected['_version'], requestId=str(uuid.uuid4()))
            refused = self.client().put(BASE+'/profils/'+str(protected['record']['IdProfessionnel']), payload, format='json')
            self.assertEqual(refused.status_code, 403, refused.data)
            self.assertEqual(refused.data['error']['code'], 'PROFESSIONAL_PHOTO_FORBIDDEN')

    def test_25_invalid_photo_mime_bytes_and_explicit_action_are_rejected(self):
        with self.photo_media() as folder:
            profile, creation = self.create_photo()
            pk, user = profile['record']['IdProfessionnel'], creation['data']['IdUserFk']
            original = self.photo_source(user)
            cases = [{'photoDataUrl': 'data:image/svg+xml;base64,'+base64.b64encode(b'<svg/>').decode()},
                {'photoDataUrl': 'data:image/jpeg;base64,eHl6'}, {'photoDataUrl': 'data:image/png;base64,%%%INVALID'},
                {'photoDataUrl': self.image_url('JPEG').replace('image/jpeg', 'image/png')},
                {'photoDataUrl': ''}, {'photoDataUrl': self.image_url(), 'removePhoto': True}, {'removePhoto': 'true'}]
            for change in cases:
                with self.subTest(change=list(change)):
                    response = self.client().put(BASE+'/profils/'+str(pk), {'data': {}, '_version': profile['_version'],
                        'requestId': str(uuid.uuid4()), 'motif': 'Validation photo', **change}, format='json')
                    self.assertEqual(response.status_code, 422, response.data)
                    self.assertIn('photoDataUrl', response.data['error']['details'])
            self.assertEqual(self.photo_source(user), original)
            self.assertEqual(len(list(folder.rglob('*.jpg'))), 1)

    def test_26_webp_reencoding_and_creation_replay_does_not_write_twice(self):
        from PIL import Image
        with self.photo_media() as folder:
            profile, creation = self.create_photo(self.image_url('WEBP'))
            source = self.photo_source(creation['data']['IdUserFk'])
            with Image.open(folder/source) as image:
                self.assertEqual(image.format, 'JPEG')
                self.assertNotIn('exif', image.info)
            response = self.client().post(BASE+'/profils', creation, format='json')
            self.assertEqual(response.status_code, 201, response.data)
            self.assertTrue(response.data['data']['replayed'])
            self.assertEqual(response.data['data']['record']['IdProfessionnel'], profile['record']['IdProfessionnel'])
            self.assertEqual(len(list(folder.rglob('*.jpg'))), 1)
            conflicting = self.client().post(BASE+'/profils', {**creation, 'photoDataUrl': self.image_url('PNG')}, format='json')
            self.assertEqual(conflicting.status_code, 409)
            self.assertEqual(len(list(folder.rglob('*.jpg'))), 1)

    def test_27_binary_eight_mebibyte_limit_and_json_envelope(self):
        from django.conf import settings
        self.assertGreaterEqual(settings.DATA_UPLOAD_MAX_MEMORY_SIZE, 12*1024*1024)
        with self.photo_media() as folder:
            head = base64.b64decode(self.image_url('JPEG').split(',')[1])
            exact = head+b'\0'*(8*1024*1024-len(head))
            photo = 'data:image/jpeg;base64,'+base64.b64encode(exact).decode('ascii')
            profile, creation = self.create_photo(photo)
            self.assertEqual(len(list(folder.rglob('*.jpg'))), 1)
            too_large = 'data:image/jpeg;base64,'+base64.b64encode(exact+b'\0').decode('ascii')
            response = self.client().put(BASE+'/profils/'+str(profile['record']['IdProfessionnel']), {'data': {},
                '_version': profile['_version'], 'requestId': str(uuid.uuid4()), 'motif': 'Limite photo', 'photoDataUrl': too_large}, format='json')
            self.assertEqual(response.status_code, 422, response.data)
            self.assertEqual(len(list(folder.rglob('*.jpg'))), 1)

    def test_28_commit_failure_rolls_back_database_and_new_photo_file(self):
        from psycopg import sql
        with self.photo_media() as folder:
            request_id = str(uuid.uuid4())
            suffix = uuid.uuid4().hex
            function, trigger = 'test_photo_commit_'+suffix, 'test_photo_commit_'+suffix
            self.sql.execute(sql.SQL('CREATE FUNCTION professionnel.{}() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN RAISE EXCEPTION \'Recette de contrainte différée\' USING ERRCODE=\'23514\'; END $$').format(sql.Identifier(function)))
            self.sql.execute(sql.SQL('''CREATE CONSTRAINT TRIGGER {} AFTER INSERT ON professionnel."T_Professionnel"
                DEFERRABLE INITIALLY DEFERRED FOR EACH ROW WHEN(NEW."CreationRequestId"={}) EXECUTE FUNCTION professionnel.{}()''').format(
                sql.Identifier(trigger), sql.Literal(uuid.UUID(request_id)), sql.Identifier(function)))
            try:
                user = self.account(self.entities[0])
                response = self.client().post(BASE+'/profils', {'data': {'IdUserFk': user['IdUser'], 'IdTypeProfessionnelFk': self.typ},
                    'requestId': request_id, 'photoDataUrl': self.image_url()}, format='json')
                self.assertEqual(response.status_code, 409, response.data)
                self.assertEqual(list(folder.rglob('*.jpg')), [])
                self.assertIsNone(self.photo_source(user['IdUser']))
                self.assertEqual(self.sql.execute('SELECT count(*) n FROM professionnel."T_Professionnel" WHERE "CreationRequestId"=%s', [request_id]).fetchone()['n'], 0)
            finally:
                self.sql.execute(sql.SQL('DROP TRIGGER {} ON professionnel."T_Professionnel"').format(sql.Identifier(trigger)))
                self.sql.execute(sql.SQL('DROP FUNCTION professionnel.{}()').format(sql.Identifier(function)))

    def test_29_json_request_is_bounded_before_decoding(self):
        from django.conf import settings
        with self.photo_media() as folder:
            body = {'data': {}, 'requestId': str(uuid.uuid4()), 'photoDataUrl': 'x'*(settings.DATA_UPLOAD_MAX_MEMORY_SIZE+1)}
            response = self.client().post(BASE+'/profils', body, format='json')
            self.assertEqual(response.status_code, 413, response.data)
            self.assertEqual(response.data['error']['code'], 'PROFESSIONAL_BODY_TOO_LARGE')
            self.assertEqual(list(folder.rglob('*.jpg')), [])


if __name__ == '__main__':
    unittest.main(verbosity=2)
