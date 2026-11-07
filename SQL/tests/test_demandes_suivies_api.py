"""Recette indépendante des demandes suivies, sur copie PostgreSQL locale.

Aucune connexion à la base de l'application ni à Render : le nom de recette
et l'adresse de bouclage sont contrôlés avant le chargement de Django.
Les données fictives de chaque scénario sont annulées par transaction.
"""
import json
from decimal import Decimal
import os
from pathlib import Path
import sys
import tempfile
import unittest
from urllib.parse import urlsplit
import uuid

import psycopg

ROOT = Path(__file__).resolve().parents[2]
DSN = os.environ.get('SAUVERNDEKO_TEST_DATABASE_URL', '')
location = urlsplit(DSN)
if location.hostname not in {'localhost', '127.0.0.1', '::1'} or not location.path[1:].startswith('sauverndeko_test_'):
    raise RuntimeError('Recette réservée à PostgreSQL privé local sauverndeko_test_*.')
with psycopg.connect(DSN) as guard:
    if not guard.execute('SELECT current_database()').fetchone()[0].startswith('sauverndeko_test_'):
        raise RuntimeError('La connexion ne pointe pas vers une base de recette.')
os.environ.update(DATABASE_URL=DSN, DJANGO_SETTINGS_MODULE='config.settings', SAUVERNDEKO_DB_READ_ONLY='0')
sys.path.insert(0, str(ROOT / 'backend'))
import django
django.setup()

from django.db import transaction
from django.test import override_settings
from PIL import Image
from rest_framework.test import APIClient

from apps.accounts.authentication import Actor
from apps.core import db
from apps.core.module_access import WORKSPACE_MODULES

BASE = '/api/discussions/demandes'


class DemandesSuiviesAPI(unittest.TestCase):
    def setUp(self):
        self.responses = []
        self.files = self.enterContext(tempfile.TemporaryDirectory(prefix='sauverndeko-demandes-'))
        self.enterContext(override_settings(ALLOWED_HOSTS=['testserver'], ARTICLE_MEDIA_ROOT=self.files))
        self.tx = transaction.atomic()
        self.tx.__enter__()
        self.addCleanup(self.rollback)
        self.tag = 'recette-demande-' + uuid.uuid4().hex
        self.a, self.b, self.c = [self.company() for _ in range(3)]
        self.alice = self.user(self.a)
        self.colleague = self.user(self.a)
        self.manager = self.user(self.b, admin=True)
        self.agent = self.user(self.b)
        self.outsider = self.user(self.c, admin=True)
        self.expert_user = self.user(self.b)
        self.platform = self.user(None, platform=True)
        self.product = self.article()

    def rollback(self):
        transaction.set_rollback(True)
        self.tx.__exit__(None, None, None)
        # FileResponse.close emits request_finished, which closes Django's DB
        # connection. Close it only after the enclosing fixture rollback.
        for response in self.responses:
            response.close()

    def company(self):
        entity = db.one('''INSERT INTO systeme."T_Entite"
            ("NomEntite","EmailEntite","ValideEntite") VALUES(%s,%s,true) RETURNING "IdEntite"''',
            [self.tag + '-' + uuid.uuid4().hex[:8], uuid.uuid4().hex + '@example.invalid'])['IdEntite']
        status = db.one('''SELECT g."ID_Generique" id FROM referentiel."T_Generique" g
            JOIN referentiel."T_CategorieGenerique" c ON c."ID_CategorieGenerique"=g."ID_CategorieGeneriqueFk"
            WHERE lower(c."NomCategorieGenerique")='statut licence' AND lower(g."NomGenerique") IN ('active','actif')
            AND g."ValideGenerique" IS TRUE AND g."IdEntiteFk" IS NULL ORDER BY g."ID_Generique" LIMIT 1''')
        self.assertIsNotNone(status, 'Statut actif de licence requis sur la copie de recette.')
        licence = db.one('''INSERT INTO systeme."T_Licence"
            ("IdEntiteFk","DateDebut","DateFin","ValideLicence","IdStatutLicenceFk")
            VALUES(%s,LOCALTIMESTAMP-interval '1 day',LOCALTIMESTAMP+interval '1 year',true,%s)
            RETURNING "IdLicence"''', [entity, status['id']])['IdLicence']
        for module in ('discussions', 'logistique'):
            db.query('INSERT INTO systeme."T_LicenceModule" ("IdLicenceFk","CodeModule","Actif") VALUES(%s,%s,true)',
                     [licence, module])
        return entity

    def user(self, entity, *, admin=False, platform=False):
        return db.one('''INSERT INTO systeme."T_Utilisateurs"
            ("IdEntiteFk","NomUser","PrenomUser","EmailUser","MotdepasseUser","ValideUser","SexeUser","Is_staff","Is_Admin")
            VALUES(%s,'Fictif','Demande',%s,'inutilisable',true,'M',%s,%s) RETURNING *''',
            [entity, uuid.uuid4().hex + '@example.invalid', admin, platform])

    def client(self, row=None, *, context=None, denied=(), manage=True, real_rights=False):
        actor = Actor(dict(row or self.alice))
        if context is not None:
            actor._context_entity = context
        if not real_rights:
            actor._module_access = {'modules': {item['key']: {
                'canRead': item['key'] not in denied,
                'canManage': manage and item['key'] not in denied,
                'canExport': item['key'] not in denied,
                'reason': 'MODULE_ROLE_FORBIDDEN' if item['key'] in denied else '',
            } for item in WORKSPACE_MODULES}}
        client = APIClient()
        client.force_authenticate(actor)
        return client

    def ref(self, schema, table, column):
        row = db.one('''SELECT g."ID_Generique" id FROM referentiel."T_Generique" g
            WHERE g."ID_CategorieGeneriqueFk"=ANY(referentiel.fn_categories_champ(%s,%s,%s,NULL))
            AND g."ValideGenerique" IS TRUE AND g."IdEntiteFk" IS NULL
            ORDER BY CASE WHEN g."AbrGenerique" IN ('pcs','USD') THEN 0 ELSE 1 END,g."ID_Generique" LIMIT 1''',
            [schema, table, column])
        self.assertIsNotNone(row, 'Référence commune manquante : ' + column)
        return row['id']

    def article(self):
        refs = [self.ref('logistique', 'T_Article', field) for field in
                ('ID_TypeArticleFk', 'ID_CategorieArticleFk', 'ID_UniteFk', 'ID_DeviseFk')]
        return db.one('''INSERT INTO logistique."T_Article"
            ("IdEntiteFk","ID_UserFK","NomArticle","RefArticle","ID_TypeArticleFk","ID_CategorieArticleFk", "ID_UniteFk","ID_DeviseFk",
             "PUArticle","PVArticle","QteArticle","QteMinArticle","ValideArticle","VisibleCatalogue","ObsArticle","InformationArticle")
            VALUES(%s,%s,%s,%s,%s,%s,%s,%s,7.31,12.50,0,0,true,true,'NOTE-PRIVEE-NE-PAS-EXPOSER','INFORMATION-PRIVEE')
            RETURNING "ID_Article"''', [self.b, self.manager['IdUser'], self.tag + '-article', 'REF-DEMANDE', *refs])['ID_Article']

    def profile(self):
        typ = self.ref('professionnel', 'T_Professionnel', 'IdTypeProfessionnelFk')
        sector = self.ref('professionnel', 'T_Professionnel', 'IdSecteurFk')
        return db.one('''INSERT INTO professionnel."T_Professionnel"
            ("IdUserFk","IdEntiteFk","IdTypeProfessionnelFk","IdSecteurFk","TitrePublic","PresentationPublique",
             "ValideProfessionnel","Publie","ContactAutorise","ObsProfessionnel")
            VALUES(%s,%s,%s,%s,'Expert fictif','Présentation fictive publique',true,true,true,'NOTE-EXPERT-PRIVEE')
            RETURNING "IdProfessionnel"''', [self.expert_user['IdUser'], self.b, typ, sector])['IdProfessionnel']

    def data(self, response, expected=200):
        statuses = expected if isinstance(expected, (tuple, list, set)) else (expected,)
        self.assertIn(response.status_code, statuses, getattr(response, 'data', None))
        if response.status_code in {200, 201}:
            self.assertEqual({part.strip() for part in response['Cache-Control'].split(',')}, {'private', 'no-store'})
        return getattr(response, 'data', {}).get('data')

    def draft(self, *, kind='product', source=None, **changes):
        return {'sourceType': kind, 'sourceId': source or self.product,
                'subject': 'Disponibilité et service', 'description': 'Besoin fictif sans donnée médicale.',
                'requestId': str(uuid.uuid4()), **changes}

    def create(self, *, who=None, data=None):
        payload = data or self.draft()
        result = self.data(self.client(who).post(BASE, payload, format='json'), 201)
        return result.get('record', result), payload

    def detail(self, row, who=None, expected=200, **rights):
        return self.data(self.client(who, **rights).get(BASE + '/' + str(row['id'])), expected)

    def source(self, kind='product', identifier=None, who=None, **rights):
        return self.data(self.client(who, **rights).get(BASE + '/contexte-source',
            {'sourceType': kind, 'sourceId': identifier or self.product}))

    def transition(self, row, state, *, who=None, reason='Motif fictif de recette', expected=200, request_id=None, version=None):
        return self.data(self.client(who or self.manager).post(BASE + '/' + str(row['id']) + '/transition',
            {'state': state, 'version': row['version'] if version is None else version,
             'reason': reason, 'requestId': request_id or str(uuid.uuid4())}, format='json'), expected)

    def test_01_authentication_permissions_and_read_only(self):
        self.data(APIClient().get(BASE), 401)
        self.data(self.client(denied=('discussions',)).get(BASE), 403)
        self.data(self.client(denied=('produits',)).post(BASE, self.draft(), format='json'), 403)
        self.data(self.client(manage=False).post(BASE, self.draft(), format='json'), 403)
        with override_settings(DB_READ_ONLY=True):
            self.data(self.client().post(BASE, self.draft(), format='json'), 503)

    def test_02_source_projection_is_minimal_and_destination_is_proven(self):
        source = self.source()
        self.assertTrue(source['canCreate'])
        self.assertEqual(source['source']['type'], 'product')
        self.assertEqual(source['source']['id'], self.product)
        self.assertEqual(source['recipient']['kind'], 'entity')
        self.assertEqual(source['recipient']['id'], self.b)
        serialized = json.dumps(source, ensure_ascii=False)
        for forbidden in ('NOTE-PRIVEE', 'INFORMATION-PRIVEE', 'PUArticle', 'QteArticle', 'MotdepasseUser', 'PhotoArticle'):
            self.assertNotIn(forbidden, serialized)
        self.assertFalse(source['canConfigureRouting'])

    def business_counts(self):
        return {name: db.one('SELECT count(*) n FROM ' + name)['n'] for name in (
            'logistique."T_Article"', 'logistique."T_Commande"', 'logistique."T_CommandeDetail"',
            'logistique."T_Mouvement"', 'logistique."T_Reglements"', 'analytics."T_Recherche"')}

    def test_03_creation_replay_and_no_business_or_chat_side_effect(self):
        before = self.business_counts()
        chats = db.one('SELECT count(*) n FROM communication."T_Discussion"')['n']
        row, draft = self.create()
        self.assertEqual(row['state'], 'en_attente')
        self.assertTrue(row['code'])
        self.assertIsNone(row['discussionId'])
        self.assertEqual(row['requester']['id'], self.alice['IdUser'])
        self.assertEqual(row['recipient']['id'], self.b)
        replay = self.data(self.client().post(BASE, draft, format='json'), (200, 201))
        self.assertEqual(replay.get('record', replay)['id'], row['id'])
        self.data(self.client().post(BASE, {**draft, 'subject': 'Autre objet'}, format='json'), 409)
        self.assertEqual(self.business_counts(), before)
        self.assertEqual(db.one('SELECT count(*) n FROM communication."T_Discussion"')['n'], chats)
        result = self.detail(row)
        self.assertEqual(result['record']['id'], row['id'])
        self.assertTrue(result['history'])
        self.assertEqual(self.detail(row)['history'], result['history'])

    def test_04_requester_and_company_isolation_including_global_context(self):
        row, _ = self.create()
        self.detail(row, self.colleague, expected=404)
        self.detail(row, self.outsider, expected=404)
        self.detail(row, self.platform, expected=404, context=self.b)
        self.detail(row, self.manager)
        sent = self.data(self.client().get(BASE, {'direction': 'sent'}))
        self.assertIn(row['id'], [item['id'] for item in sent['rows']])
        for who in (self.colleague, self.outsider, self.platform):
            result = self.data(self.client(who, context=self.b if who is self.platform else None).get(BASE, {'direction': 'sent'}))
            self.assertNotIn(row['id'], [item['id'] for item in result['rows']])
        incoming = self.data(self.client(self.manager).get(BASE, {'direction': 'received'}))
        self.assertIn(row['id'], [item['id'] for item in incoming['rows']])
        outsider = self.data(self.client(self.outsider).get(BASE, {'direction': 'received'}))
        self.assertNotIn(row['id'], [item['id'] for item in outsider['rows']])

    def test_05_pagination_search_and_counts_share_the_authorized_population(self):
        rows = [self.create(data=self.draft(subject=self.tag + '-' + str(number)))[0] for number in range(4)]
        self.create(who=self.colleague, data=self.draft(subject=self.tag + '-autre-compte'))
        ids = []
        for skip in (0, 2):
            page = self.data(self.client().get(BASE, {'direction': 'sent', 'search': self.tag, 'take': 2, 'skip': skip}))
            self.assertEqual(page['total'], 4)
            self.assertEqual(len(page['rows']), 2)
            ids.extend(item['id'] for item in page['rows'])
        self.assertEqual(set(ids), {item['id'] for item in rows})
        self.assertEqual(len(ids), len(set(ids)))
        self.assertEqual(self.data(self.client().get(BASE, {'search': 'NOTE-PRIVEE'}))['total'], 0)
        for query in ({'take': 0}, {'take': 101}, {'skip': -1}, {'direction': 'all'},
                      {'state': 'secret'}, {'unexpected': 'true'}, {'search': 'x' * 301}):
            self.data(self.client().get(BASE, query), (400, 422))
        self.data(self.client().get(BASE + '?direction=sent&direction=received'), (400, 422))

    def test_06_professional_receiver_is_the_user_not_an_affiliated_company(self):
        profile = self.profile()
        context = self.source('expert', profile)
        self.assertEqual(context['recipient']['kind'], 'user')
        self.assertEqual(context['recipient']['id'], self.expert_user['IdUser'])
        row, _ = self.create(data=self.draft(kind='expert', source=profile))
        self.detail(row, self.expert_user)
        self.detail(row, self.manager, expected=404)
        self.detail(row, self.platform, expected=404, context=self.b)
        self.assertNotIn('NOTE-EXPERT-PRIVEE', json.dumps(self.detail(row), default=str))
        self_context = self.source('expert', profile, self.expert_user)
        self.assertFalse(self_context['canCreate'])

    def test_07_unpublished_source_refuses_new_requests_but_retains_history(self):
        row, _ = self.create()
        db.query('UPDATE logistique."T_Article" SET "VisibleCatalogue"=false WHERE "ID_Article"=%s', [self.product])
        response = self.client().post(BASE, self.draft(), format='json')
        self.assertIn(response.status_code, {404, 409}, response.data)
        historic = self.detail(row)
        self.assertEqual(historic['record']['id'], row['id'])
        self.assertEqual(historic['record']['source']['id'], self.product)
        self.assertEqual(historic['record']['source']['label'], row['source']['label'])
        self.detail(row, self.manager)
        self.data(self.client().get('/api/produits/offres/' + str(self.product)), 404)

    def test_08_profile_contact_optout_preserves_previous_request(self):
        profile = self.profile()
        row, _ = self.create(data=self.draft(kind='expert', source=profile))
        db.query('UPDATE professionnel."T_Professionnel" SET "ContactAutorise"=false WHERE "IdProfessionnel"=%s', [profile])
        context = self.client().get(BASE + '/contexte-source', {'sourceType': 'expert', 'sourceId': profile})
        self.assertIn(context.status_code, {200, 404}, context.data)
        if context.status_code == 200:
            self.assertFalse(context.data['data']['canCreate'])
        response = self.client().post(BASE, self.draft(kind='expert', source=profile), format='json')
        self.assertIn(response.status_code, {404, 409}, response.data)
        self.detail(row)
        self.detail(row, self.expert_user)

    def test_09_quantity_is_exact_optional_and_never_reserves_stock(self):
        context = self.source()
        before = self.business_counts()
        row, _ = self.create(data=self.draft(quantity='2', destination='Lieu fictif'))
        self.assertEqual(Decimal(row['quantity']), Decimal('2'))
        self.assertEqual(row['unit'], context['source']['unit'])
        self.assertEqual(row['destination'], 'Lieu fictif')
        self.assertEqual(self.business_counts(), before)
        absent, _ = self.create()
        self.assertIsNone(absent['quantity'])
        for bad in ('0', '-1', '1e3', 'NaN', 'Infinity', '1.0001', '1,5', 2.5, True):
            response = self.client().post(BASE, self.draft(quantity=bad), format='json')
            self.assertIn(response.status_code, {400, 422}, (bad, response.data))
        if context['source']['quantityDecimals'] == 0:
            response = self.client().post(BASE, self.draft(quantity='0.5'), format='json')
            self.assertIn(response.status_code, {400, 422}, response.data)
        self.data(self.client().post(BASE, self.draft(destination='x' * 301), format='json'), 422)

    def test_10_recipient_actions_require_current_version_and_terminal_states_are_final(self):
        row, _ = self.create()
        self.transition(row, 'en_cours', who=self.outsider, expected=404)
        self.transition(row, 'en_cours', who=self.alice, expected=403)
        changed = self.transition(row, 'en_cours', reason='')
        changed = changed.get('record', changed)
        self.assertEqual(changed['state'], 'en_cours')
        self.assertNotEqual(changed['version'], row['version'])
        self.transition(row, 'satisfaite', expected=409)
        finished = self.transition(changed, 'satisfaite', who=self.alice)
        finished = finished.get('record', finished)
        self.assertEqual(finished['state'], 'satisfaite')
        self.assertEqual(finished['actions'], [])
        self.transition(finished, 'en_cours', expected=409)
        self.assertGreaterEqual(len(self.detail(row)['history']), 3)

    def test_11_cancellation_reason_transition_replay_and_conflicting_reuse(self):
        row, _ = self.create()
        self.transition(row, 'annulee', who=self.alice, reason='', expected=422)
        request_id = str(uuid.uuid4())
        first = self.transition(row, 'annulee', who=self.alice, request_id=request_id)
        second = self.transition(row, 'annulee', who=self.alice, request_id=request_id)
        self.assertEqual(first, second)
        self.transition(row, 'annulee', who=self.alice, request_id=request_id, reason='Autre raison', expected=409)
        self.assertEqual(self.detail(row)['record']['state'], 'annulee')

    def test_12_discussion_is_explicit_replayable_and_private(self):
        row, _ = self.create()
        before = db.one('SELECT count(*) n FROM communication."T_Discussion"')['n']
        self.assertIsNone(row['discussionId'])
        payload = {'version': row['version'], 'requestId': str(uuid.uuid4())}
        opened = self.data(self.client().post(BASE + '/' + str(row['id']) + '/discussion', payload, format='json'))
        self.assertIsInstance(opened['discussionId'], int)
        replay = self.data(self.client().post(BASE + '/' + str(row['id']) + '/discussion', payload, format='json'))
        self.assertEqual(opened['discussionId'], replay['discussionId'])
        self.assertEqual(db.one('SELECT count(*) n FROM communication."T_Discussion"')['n'], before + 1)
        self.assertEqual(db.one('SELECT count(*) n FROM communication."T_Chat" WHERE "IdDiscussionFk"=%s',
            [opened['discussionId']])['n'], 0)
        self.data(self.client(self.outsider).get('/api/discussions/' + str(opened['discussionId']) + '/messages'), 404)
        self.data(self.client().get('/api/discussions/' + str(opened['discussionId']) + '/messages'))
        self.data(self.client(self.manager).get('/api/discussions/' + str(opened['discussionId']) + '/messages'))
        message_url = '/api/discussions/' + str(opened['discussionId']) + '/messages'
        message = {'message': 'Réponse fictive à la demande, sans donnée médicale.', 'requestId': str(uuid.uuid4())}
        sent = self.data(self.client(self.manager).post(message_url, message, format='json'), 201)
        self.assertEqual(sent['TextChat'], message['message'])
        messages = self.data(self.client().get(message_url))
        self.assertIn(sent['IdChat'], [item['IdChat'] for item in messages])
        replay_message = self.data(self.client(self.manager).post(message_url, message, format='json'))
        self.assertEqual(replay_message['IdChat'], sent['IdChat'])
        self.data(self.client(self.platform, context=self.b).get(message_url), 404)
        self.assertEqual(self.detail(row)['record']['discussionId'], opened['discussionId'])

    def test_13_validation_has_no_partial_creation_or_forced_recipient(self):
        before = self.data(self.client().get(BASE))['total']
        invalid = [self.draft(subject=''), self.draft(description=''), self.draft(requestId='invalid'),
                   self.draft(sourceType='arbitrary'), self.draft(sourceId=-1), self.draft(recipientId=self.c),
                   self.draft(subject='x' * 301), self.draft(description='x\x00y')]
        for payload in invalid:
            response = self.client().post(BASE, payload, format='json')
            self.assertIn(response.status_code, {400, 422}, response.data)
        self.assertEqual(self.data(self.client().get(BASE))['total'], before)

    def test_14_generic_models_and_views_never_bypass_private_access(self):
        from apps.core.registry import MODELS, VIEWS
        self.assertFalse(any(obj['schema'] == 'communication' for obj in MODELS.values()))
        self.assertFalse(any(obj['schema'] == 'communication' for obj in VIEWS.values()))
        platform = self.client(self.platform)
        for name in ('T_Demande', 'T_DemandeHistorique', 'T_RoutageStructure', 'T_RoutageStructureHistorique'):
            for operation in ('get', 'post'):
                response = getattr(platform, operation)('/api/models/' + name, {} if operation == 'post' else None,
                    **({'format': 'json'} if operation == 'post' else {}))
                self.assertIn(response.status_code, {403, 404}, response.data)
        for name in ('V_Demande', 'V_DemandeHistorique', 'V_RoutageStructure'):
            response = platform.get('/api/views/communication/' + name)
            self.assertIn(response.status_code, {403, 404}, response.data)

    def test_15_historic_request_does_not_restore_a_withdrawn_offer_photo(self):
        relative = 'Article/fictif_' + uuid.uuid4().hex + '.jpg'
        filename = Path(self.files) / relative
        filename.parent.mkdir()
        Image.new('RGB', (20, 20), 'green').save(filename, format='JPEG')
        db.query('UPDATE logistique."T_Article" SET "PhotoArticle"=%s WHERE "ID_Article"=%s', [relative, self.product])
        row, _ = self.create()
        photo = '/api/public/articles/' + str(self.product) + '/photo'
        result = self.client().get(photo)
        self.assertEqual(result.status_code, 200)
        self.responses.append(result)
        db.query('UPDATE logistique."T_Article" SET "VisibleCatalogue"=false WHERE "ID_Article"=%s', [self.product])
        self.detail(row)
        self.assertEqual(self.client().get(photo).status_code, 404)
        encoded = json.dumps(self.detail(row), ensure_ascii=False, default=str)
        self.assertNotIn(relative, encoded)
        self.assertNotIn('NOTE-PRIVEE', encoded)
        self.assertNotIn('INFORMATION-PRIVEE', encoded)

    def territory(self, level):
        # Reuse only a valid reference hierarchy and category from the clone.
        # The territorial identity itself must be fictitious and newly created:
        # another recipe or an operator may already have routed an older source.
        fields = {
            3: ('ID_Niveau_2_FK', 'ID_TypeNiveau_2_Fk'),
            4: ('ID_Niveau_3_Fk', 'ID_TypeNiveau_4_Fk'),
            5: ('ID_Niveau_3_Fk', 'ID_Niveau_4_Fk', 'ID_TypeNiveau_5_Fk'),
        }
        self.assertIn(level, fields)
        table, primary = 'T_Niveau_' + str(level), 'ID_Niveau_' + str(level)
        columns = fields[level]
        projection = ','.join('t."' + name + '"' for name in columns)
        template = db.one('SELECT ' + projection + ' FROM geolocalisation."' + table + '" t '
            'JOIN geolocalisation."V_StructureSanitairePublique" v '
            'ON v."ID_Structure"=t."' + primary + '" AND v."NiveauStructure"=%s '
            'ORDER BY t."' + primary + '" LIMIT 1', [level])
        self.assertIsNotNone(template, 'Une hiérarchie publiée de référence est requise sur la copie.')
        columns += ('NomNiveau_' + str(level), 'CodeNiveau_' + str(level))
        quoted = ','.join('"' + name + '"' for name in columns)
        values = [template[name] for name in fields[level]] + [self.tag + '-territoire-' + str(level), uuid.uuid4().hex]
        result = db.one('INSERT INTO geolocalisation."' + table + '" (' + quoted + ') VALUES ('
            + ','.join(['%s'] * len(columns)) + ') RETURNING "' + primary + '" id', values)
        self.assertIsNotNone(db.one('SELECT "ID_Structure" FROM geolocalisation."V_StructureSanitairePublique" '
            'WHERE "NiveauStructure"=%s AND "ID_Structure"=%s', [level, result['id']]))
        return result['id']

    def route(self, kind, pk, *, entity='default', version=0, who=None, reason='Rattachement fictif vérifié', expected=200, request_id=None):
        return self.data(self.client(who or self.platform).put(BASE + '/routage',
            {'entityId': self.b if entity == 'default' else entity, 'version': version, 'reason': reason,
             'requestId': request_id or str(uuid.uuid4())},
            format='json', QUERY_STRING='sourceType=' + kind + '&sourceId=' + str(pk)), expected)

    def test_16_territorial_identity_is_composite_and_has_no_implicit_recipient(self):
        for level in (3, 4, 5):
            kind, pk = 'structure_n' + str(level), self.territory(level)
            source = self.source(kind, pk)
            self.assertEqual((source['source']['type'], source['source']['id']), (kind, pk))
            self.assertIsNone(source['recipient'])
            self.assertFalse(source['canCreate'])
            self.assertTrue(source['unavailableReason'])
            self.assertFalse(source['canConfigureRouting'])
            self.assertEqual(source.get('entities', []), [])
            result = self.client().post(BASE, self.draft(kind=kind, source=pk), format='json')
            self.assertIn(result.status_code, {404, 409}, result.data)
        self.assertEqual(self.data(self.client().get(BASE))['total'], 0)

    def test_17_routing_requires_global_admin_reason_version_and_preserves_previous_destination(self):
        kind, pk = 'structure_n5', self.territory(5)
        context = self.source(kind, pk, self.platform)
        self.assertTrue(context['canConfigureRouting'])
        self.assertIn(self.b, [item['id'] for item in context['entities']])
        self.route(kind, pk, who=self.manager, expected=403)
        self.route(kind, pk, reason='', expected=422)
        request_id = str(uuid.uuid4())
        first = self.route(kind, pk, request_id=request_id)
        self.assertEqual(first, self.route(kind, pk, request_id=request_id))
        self.route(kind, pk, request_id=request_id, reason='Autre motif', expected=409)
        source = self.source(kind, pk)
        self.assertTrue(source['canCreate'])
        self.assertEqual(source['recipient']['id'], self.b)
        row, _ = self.create(data=self.draft(kind=kind, source=pk))
        self.route(kind, pk, entity=self.c, version=0, expected=409)
        self.route(kind, pk, entity=self.c, version=source['routing']['version'])
        self.assertEqual(self.detail(row, self.manager)['record']['recipient']['id'], self.b)
        self.detail(row, self.outsider, expected=404)
        new_row, _ = self.create(data=self.draft(kind=kind, source=pk))
        self.assertEqual(new_row['recipient']['id'], self.c)
        self.detail(new_row, self.outsider)
        self.detail(new_row, self.manager, expected=404)
        current = self.source(kind, pk)
        self.route(kind, pk, entity=None, version=current['routing']['version'])
        removed = self.source(kind, pk)
        self.assertFalse(removed['canCreate'])
        self.assertIsNone(removed['recipient'])
        self.assertGreater(removed['routing']['version'], current['routing']['version'])
        self.assertEqual(self.detail(new_row, self.outsider)['record']['recipient']['id'], self.c)

    def test_18_database_retains_identity_and_immutable_history(self):
        from django.db import DatabaseError
        row, _ = self.create()
        attempts = [
            ('UPDATE communication."T_Demande" SET "IdEntiteDestinataireFk"=%s WHERE "IdDemande"=%s', [self.c, row['id']]),
            ('DELETE FROM communication."T_Demande" WHERE "IdDemande"=%s', [row['id']]),
            ('UPDATE communication."T_DemandeHistorique" SET "MotifDemande"=%s WHERE "IdDemandeFk"=%s', ['Effacement', row['id']]),
            ('DELETE FROM communication."T_DemandeHistorique" WHERE "IdDemandeFk"=%s', [row['id']]),
        ]
        for query, values in attempts:
            with self.assertRaises(DatabaseError):
                with transaction.atomic():
                    db.query(query, values)
        result = self.detail(row)
        self.assertEqual(result['record']['recipient']['id'], self.b)
        self.assertNotIn('ContenuRequete', json.dumps(result, default=str))

    def test_19_real_license_is_checked_beyond_client_capabilities(self):
        self.assertTrue(self.data(self.client(real_rights=True).get(BASE + '/contexte-source',
            {'sourceType': 'product', 'sourceId': self.product}))['canCreate'])
        db.query('''UPDATE systeme."T_LicenceModule" m SET "Actif"=false
            FROM systeme."T_Licence" l WHERE l."IdLicence"=m."IdLicenceFk"
            AND l."IdEntiteFk"=%s AND m."CodeModule"='discussions' ''', [self.a])
        self.data(self.client(real_rights=True).get(BASE), 403)
        # Même une capacité API mise en cache ne contourne pas la garde SQL.
        self.data(self.client().post(BASE, self.draft(), format='json'), 403)

    def test_20_disabled_recipient_company_cannot_receive_a_new_request(self):
        row, _ = self.create()
        db.query('UPDATE systeme."T_Entite" SET "ValideEntite"=false WHERE "IdEntite"=%s', [self.b])
        response = self.client().post(BASE, self.draft(), format='json')
        self.assertIn(response.status_code, {404, 409}, response.data)
        self.assertEqual(self.detail(row)['record']['id'], row['id'])

    def test_21_new_sql_tables_columns_and_view_are_documented(self):
        names = ['T_Demande', 'T_DemandeHistorique', 'T_RoutageStructure', 'T_RoutageStructureHistorique', 'V_Demande']
        missing = db.query('''SELECT c.relname,a.attname FROM pg_class c
            JOIN pg_namespace n ON n.oid=c.relnamespace
            JOIN pg_attribute a ON a.attrelid=c.oid
            WHERE n.nspname='communication' AND c.relname=ANY(%s::text[])
            AND a.attnum>0 AND NOT a.attisdropped AND col_description(c.oid,a.attnum) IS NULL''', [names])
        self.assertEqual(missing, [])
        objects = db.query('''SELECT c.relname,obj_description(c.oid) AS description FROM pg_class c
            JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='communication' AND c.relname=ANY(%s::text[])''', [names])
        self.assertEqual(len(objects), len(names))
        self.assertTrue(all(row['description'] for row in objects))


if __name__ == '__main__':
    unittest.main(verbosity=2)
