"""Offre de l’entreprise et accès aux applications."""
import os
import sys
import unittest
from pathlib import Path
from urllib.parse import urlsplit
from unittest.mock import patch

import psycopg

ROOT=Path(__file__).resolve().parents[2]
DSN=os.environ.get('SAUVERNDEKO_TEST_DATABASE_URL','')
target=urlsplit(DSN)
if target.hostname not in {'localhost','127.0.0.1','::1'} or not target.path[1:].startswith('sauverndeko_test_'):
    raise RuntimeError('Base de tests PostgreSQL locale sauverndeko_test_* requise.')
with psycopg.connect(DSN) as connection:
    if not connection.execute('SELECT current_database()').fetchone()[0].startswith('sauverndeko_test_'):
        raise RuntimeError('Base privée requise.')
os.environ.update(DATABASE_URL=DSN,DJANGO_SETTINGS_MODULE='config.settings',SAUVERNDEKO_DB_READ_ONLY='0')
sys.path.insert(0,str(ROOT/'backend'))
import django
django.setup()
from django.test import override_settings
from rest_framework.test import APIClient
from apps.accounts.authentication import Actor
from apps.core import db
from apps.core.module_access import access_snapshot,legacy_rights,MODULE_BY_KEY,require_module
from apps.core.application_licences import catalogue_rows
from apps.core.responses import APIError, exception_handler
from django.db import DatabaseError, transaction
from uuid import uuid4
from apps.accounts.authentication import actor_by_id


class ClassificationApplicationsAPI(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.settings=override_settings(ALLOWED_HOSTS=['testserver'])
        cls.settings.enable()
        cls.actor=Actor({'IdUser':2147483600,'Is_Admin':True,'Is_staff':False,'IdEntiteFk':None,'ValideUser':True})

    @classmethod
    def tearDownClass(cls): cls.settings.disable()

    def test_01_workspace_metadata_and_existing_rights(self):
        client=APIClient(); client.force_authenticate(self.actor)
        before=db.query('SELECT * FROM systeme."T_LicenceModule" ORDER BY "IdLicenceFk","CodeModule"')
        modules=client.get('/api/workspace/modules')
        self.assertEqual(modules.status_code,200,modules.data)
        by_key={item['key']:item for item in modules.data['data']}
        business={'produits','discussions','logistique','support','caisse','territoires','professionnels','structures'}
        self.assertEqual({key for key,item in by_key.items() if item['type']=='MODULE'},business)
        sellable = {'discussions', 'logistique', 'caisse', 'support'}
        included = {'produits', 'structures', 'professionnels'}
        for key, item in by_key.items():
            self.assertEqual(item['commercialisable'], key in sellable)
            self.assertEqual(item['platformOnly'], key == 'territoires')
            if key in business:
                self.assertEqual(item['base'], key in included)
                self.assertIsNone(item['parentModule'])
        self.assertNotIn('sante',by_key)
        self.assertNotIn('catalogue',by_key)
        self.assertEqual(by_key['referentiels']['path'],'/referentiels')
        self.assertEqual(by_key['referentiels']['type'],'FONCTIONNALITE')
        catalogue=client.get('/api/workspace/catalogue')
        self.assertEqual(catalogue.status_code,200,catalogue.data)
        for item in catalogue.data['data']['modules']:
            if item['key'] == 'referentiels':
                self.assertTrue(item['canRead'])
                continue
            expected=legacy_rights(self.actor,item['key'])
            for permission in ('canRead','canManage','canExport'):
                self.assertEqual(item[permission],expected[permission])
        self.assertEqual(before,db.query('SELECT * FROM systeme."T_LicenceModule" ORDER BY "IdLicenceFk","CodeModule"'))

    def test_02_licence_metadata_keeps_codes_and_flags(self):
        rows=catalogue_rows()
        self.assertEqual({row['CodeModule'] for row in rows},set(MODULE_BY_KEY))
        for row in rows:
            self.assertEqual(row['type'],row['TypeApplication'])
            self.assertEqual(row['commercialisable'],row['Commercialisable'])
            self.assertEqual(row['parentModule'],row['ModuleParentCode'])
            self.assertIsInstance(row['EstSocle'],bool)
        snapshot=access_snapshot(self.actor)
        self.assertTrue(snapshot['modules']['caisse']['canManage'])
        self.assertFalse(snapshot['modules']['caisse']['base'])

    def test_03_retired_health_module_is_not_available(self):
        client=APIClient();client.force_authenticate(self.actor)
        launcher=client.get('/api/workspace/modules').data['data']
        self.assertNotIn('sante',{item['key'] for item in launcher})
        catalogue={item['key']:item for item in client.get('/api/workspace/catalogue').data['data']['modules']}
        self.assertNotIn('sante',catalogue)
        self.assertNotIn('catalogue',catalogue)
        with self.assertRaises(APIError) as error:
            require_module(self.actor,'sante')
        self.assertEqual(error.exception.status_code,404)
        self.assertEqual(client.get('/api/public/maladies').status_code,404)
        self.assertIn('referentiels',catalogue)
        self.assertEqual(set(catalogue), set(MODULE_BY_KEY) - {'catalogue'} | {'referentiels'})

    def test_04_reference_feature_uses_existing_read_permission(self):
        from apps.core.workspace import available_modules
        actor=Actor({'IdUser':2147483599,'Is_Admin':False,'Is_staff':False,'ValideUser':True})
        rights={key:{'canRead':False,'canManage':False,'canExport':False,'base':False} for key in MODULE_BY_KEY}
        snapshot={'modules':rights,'platformAdmin':False,'entityId':None}
        with patch('apps.core.workspace.access_snapshot',return_value=snapshot),patch('apps.core.module_access.access_snapshot',return_value=snapshot):
            self.assertEqual(available_modules(actor),[])
            with self.assertRaises(APIError):require_module(actor,'referentiels')
            rights['produits']['canRead']=True
            self.assertEqual({item['key'] for item in available_modules(actor)},{'produits'})
            require_module(actor,'referentiels')
            # Le contrôle de module ne remplace pas la barrière IsERPAdmin
            # des routes : la tuile ne doit pas conduire à un parcours interdit.
            actor.row['Is_staff']=True
            self.assertEqual({item['key'] for item in available_modules(actor)},{'produits','referentiels'})
            # Export and mutation rights are not invented by the new tile.
            with self.assertRaises(APIError):require_module(actor,'referentiels','export')
            with self.assertRaises(APIError):require_module(actor,'referentiels','manage')

    def test_05_authentication_is_still_required(self):
        for path in ('/api/workspace/modules','/api/workspace/catalogue'):
            self.assertIn(APIClient().get(path).status_code,(401,403))

    def test_06_lock_conflicts_are_transversal_without_code_change(self):
        class Cause(Exception):pass
        for state in ('55P03','40P01'):
            error=DatabaseError('Details deliberately omitted')
            cause=Cause();cause.sqlstate=state;error.__cause__=cause
            response=exception_handler(error,{})
            self.assertEqual(response.status_code,409)
            self.assertEqual(response.data['error']['code'],'BUSINESS_CONFLICT')
            self.assertEqual(response.data['message'],'Une autre opération est en cours. Réessayez dans un instant.')
            self.assertNotIn('stock',response.data['message'])

    def test_07_launcher_flag_is_read_from_database(self):
        from apps.core.workspace import available_modules
        # La transaction est annulée ; aucun réglage durable n'est modifié.
        from django.db import transaction
        with transaction.atomic():
            db.query('UPDATE systeme."T_ModuleApplication" SET "AfficherDansEspace"=false WHERE "CodeModule"=\'produits\'')
            self.assertNotIn('produits',{item['key'] for item in available_modules(self.actor)})
            self.assertTrue(access_snapshot(self.actor)['modules']['produits']['canRead'])
            transaction.set_rollback(True)


class ClassificationApplicationsLicenceAPI(unittest.TestCase):
    """Comptes et licences fictifs, annulés à la fin de chaque test."""

    def setUp(self):
        self.enterContext(override_settings(ALLOWED_HOSTS=['testserver']))
        tx = transaction.atomic()
        tx.__enter__()
        self.addCleanup(tx.__exit__, None, None, None)
        self.addCleanup(transaction.set_rollback, True)
        self.entities = [
            db.one(
                """INSERT INTO systeme."T_Entite" ("NomEntite","EmailEntite","ValideEntite")
                   VALUES (%s,%s,true) RETURNING "IdEntite" """,
                [f'Offre de test {uuid4()}', f'{uuid4()}@example.invalid'],
            )['IdEntite']
            for _ in range(3)
        ]
        self.locals = [self.account(entity) for entity in self.entities]
        self.global_user = self.account(None, platform=True)
        self.licences = [self.licence(entity) for entity in self.entities[:2]]
        for licence in self.licences:
            db.query(
                """INSERT INTO systeme."T_LicenceModule" ("IdLicenceFk","CodeModule","Actif")
                   VALUES (%s,'catalogue',true),(%s,'logistique',true)""",
                [licence, licence],
            )

    @staticmethod
    def account(entity, *, platform=False):
        return db.one(
            """INSERT INTO systeme."T_Utilisateurs"
               ("NomUser","PrenomUser","EmailUser","MotdepasseUser","ValideUser","SexeUser","Is_Admin","Is_staff","IdEntiteFk")
               VALUES ('Offre','Test',%s,'inutilisable',true,'M',%s,true,%s) RETURNING "IdUser" """,
            [f'{uuid4()}@example.invalid', platform, entity],
        )['IdUser']

    @staticmethod
    def licence(entity):
        return db.one(
            """INSERT INTO systeme."T_Licence" ("IdEntiteFk","DateDebut","DateFin","ValideLicence","IdStatutLicenceFk")
               SELECT %s, LOCALTIMESTAMP-interval '1 day', LOCALTIMESTAMP+interval '1 year', true, g."ID_Generique"
               FROM referentiel."T_Generique" g JOIN referentiel."T_CategorieGenerique" c
                 ON c."ID_CategorieGenerique"=g."ID_CategorieGeneriqueFk"
               WHERE lower(c."NomCategorieGenerique")='statut licence'
                 AND lower(g."NomGenerique") IN ('active','actif') AND g."ValideGenerique" IS TRUE
               ORDER BY g."ID_Generique" LIMIT 1 RETURNING "IdLicence" """,
            [entity],
        )['IdLicence']

    def actor(self, index=0, *, local=False):
        return actor_by_id(self.locals[index] if local else self.global_user)

    def client(self, index=0, *, local=False):
        client = APIClient()
        client.force_authenticate(self.actor(index, local=local))
        return client

    def data(self, response, expected=200):
        self.assertEqual(response.status_code, expected, getattr(response, 'data', None))
        return response.json().get('data')

    def test_01_directories_are_included_for_members_and_users_without_company(self):
        user = self.locals[2]
        db.query('UPDATE systeme."T_Utilisateurs" SET "Is_staff"=false WHERE "IdUser"=%s', [user])
        for organisation in (self.entities[2], None):
            with self.subTest(organisation=organisation):
                db.query('UPDATE systeme."T_Utilisateurs" SET "IdEntiteFk"=%s WHERE "IdUser"=%s', [organisation, user])
                actor = actor_by_id(user)
                snapshot = access_snapshot(actor)
                for key in ('produits', 'structures', 'professionnels'):
                    self.assertTrue(snapshot['modules'][key]['canRead'])
                    self.assertTrue(snapshot['modules'][key]['base'])
                for key in ('discussions', 'logistique', 'caisse', 'support'):
                    self.assertFalse(snapshot['modules'][key]['available'])
                    self.assertFalse(snapshot['modules'][key]['base'])
                client = self.client(2, local=True)
                keys = {item['key'] for item in self.data(client.get('/api/workspace/modules'))}
                self.assertTrue({'produits', 'structures', 'professionnels'}.issubset(keys))
                self.assertFalse(keys.intersection({'catalogue', 'sante', 'territoires', 'discussions', 'referentiels'}))
                self.data(client.get('/api/produits/offres'))
                self.data(client.get('/api/structures/annuaire-sanitaire', {'take': 1}))
                self.data(client.get('/api/professionnels/annuaire', {'take': 1}))
                self.data(client.get('/api/discussions'), 403)
                self.data(client.get('/api/geolocalisation/territoires/synthese'), 403)
                self.data(client.get('/api/models/T_CategorieGenerique'), 403)
                self.data(client.get('/api/views/referentiel/V_Generique'), 403)

    def test_02_catalogue_inclusion_and_company_context_are_unchanged(self):
        before=db.query('SELECT to_jsonb(m) row FROM systeme."T_LicenceModule" m ORDER BY "IdLicenceModule"')
        actor=self.actor(local=True);snapshot=access_snapshot(actor)
        self.assertTrue(snapshot['modules']['produits']['canRead'])
        self.assertTrue(snapshot['modules']['produits']['base'])
        self.assertIsNone(snapshot['modules']['produits']['includedBy'])
        launcher=self.data(self.client(local=True).get('/api/workspace/modules'))
        self.assertIn('referentiels',{item['key'] for item in launcher})
        products=next(item for item in launcher if item['key']=='produits')
        self.assertEqual(products['type'],'MODULE')
        self.assertFalse(products['commercialisable'])
        self.assertIsNone(products['parentModule'])
        catalogue=self.data(self.client(local=True).get('/api/workspace/catalogue'))
        self.assertEqual(catalogue['entityId'],self.entities[0])
        self.assertEqual({item['key'] for item in catalogue['modules']},
                         set(MODULE_BY_KEY) - {'catalogue', 'territoires'} | {'referentiels'})
        sellable = {item['key'] for item in catalogue['modules'] if item['commercialisable']}
        self.assertEqual(sellable, {'discussions', 'logistique', 'caisse', 'support'})
        after=db.query('SELECT to_jsonb(m) row FROM systeme."T_LicenceModule" m ORDER BY "IdLicenceModule"')
        self.assertEqual(before,after)


    def test_03_platform_activation_and_company_isolation(self):
        entity = self.entities[0]
        licence = self.licences[0]
        path = f'/api/workspace/licences/{licence}/modules'
        db.query('INSERT INTO systeme."T_LicenceModule" ("IdLicenceFk","CodeModule","Actif") VALUES (%s,\'territoires\',true)', [licence])
        self.assertFalse(db.one('SELECT "EstAccesActif" FROM systeme."V_LicenceModule" WHERE "IdLicenceFk"=%s AND "CodeModule"=\'territoires\'', [licence])['EstAccesActif'])
        local = self.client(local=True)
        self.data(local.get('/api/geolocalisation/territoires/synthese'), 403)
        guide = self.data(local.get('/api/guide/contexte'))
        self.assertNotIn('territoires', {module['key'] for module in guide['modules']})
        self.assertNotIn('discussions', {module['key'] for module in guide['modules']})
        self.data(local.get('/api/workspace/licences', {'entite': self.entities[1]}), 403)
        offer = self.data(local.get('/api/workspace/licences', {'entite': entity}))
        self.assertFalse(offer['canManage'])
        self.assertEqual(set(offer['moduleCodes']), {'discussions', 'logistique', 'caisse', 'support'})

        def versions_from(data):
            selected = next(row for row in data['licences'] if row['IdLicence'] == licence)
            versions = {row['CodeModule']: row['Version'] for row in selected['activations']}
            return {key: versions.get(key, 0) for key in data['moduleCodes']}

        versions = versions_from(offer)
        payload = {'versions': versions, 'enabled': ['logistique', 'discussions']}
        self.data(local.put(path, payload, format='json'), 403)
        platform = self.client()
        self.data(platform.put(path, {**payload, 'enabled': ['territoires']}, format='json'), 400)
        updated = self.data(platform.put(path, payload, format='json'))
        self.assertIn('discussions', updated['effectiveModules'])
        self.assertTrue(access_snapshot(self.actor(local=True))['modules']['discussions']['canRead'])
        self.assertFalse(access_snapshot(self.actor(1, local=True))['modules']['discussions']['canRead'])
        self.data(platform.put(path, payload, format='json'), 409)

        updated = self.data(platform.put(path, {'versions': versions_from(updated), 'enabled': ['logistique']}, format='json'))
        self.assertNotIn('discussions', updated['effectiveModules'])
        self.assertFalse(access_snapshot(self.actor(local=True))['modules']['discussions']['canRead'])
        preserved = db.query('SELECT "CodeModule","Actif" FROM systeme."T_LicenceModule" WHERE "IdLicenceFk"=%s AND "CodeModule" IN (\'catalogue\',\'territoires\')', [licence])
        self.assertEqual({row['CodeModule']: row['Actif'] for row in preserved}, {'catalogue': True, 'territoires': True})



    def test_04_individual_permissions_gate_routes_and_keep_company_scope(self):
        endpoint = '/api/workspace/droits-utilisateurs'
        platform = self.client()
        entity = self.entities[0]
        user = self.locals[0]
        config = self.data(platform.get(endpoint, {'entite': entity}))
        codes = {item['CodeModule'] for item in config['catalogue']}
        for code in ('logistique.immobilisations', 'logistique.commandes', 'caisse.ecritures',
                     'support.tickets', 'administration.utilisateurs', 'discussions.messages', 'professionnels.annuaire'):
            self.assertIn(code, codes)
        self.assertNotIn('territoires', codes)
        self.assertEqual({row['IdUser'] for row in config['users']}, {user})
        self.data(self.client(local=True).get(endpoint, {'entite': entity}), 403)

        inherited = {'canRead': True, 'canManage': True, 'canExport': True}
        permissions = {code: inherited.copy() for code in codes}
        permissions['logistique.immobilisations'].update(canManage=False, canExport=False)
        payload = {'entityId': entity, 'versions': dict.fromkeys(codes, 0), 'permissions': permissions}
        self.data(self.client(local=True).put(f'{endpoint}/{user}', payload, format='json'), 403)
        self.data(platform.put(f'{endpoint}/{self.locals[1]}', payload, format='json'), 404)
        self.data(platform.put(f'{endpoint}/{self.global_user}', payload, format='json'), 404)
        response = self.data(platform.put(f'{endpoint}/{user}', payload, format='json'))
        rules = {row['CodeModule']: row for row in response['users'][0]['permissions']}
        self.assertEqual(rules['logistique.immobilisations']['Version'], 1)
        self.data(platform.put(f'{endpoint}/{user}', payload, format='json'), 409)

        assets = '/api/logistique/immobilisations'
        local = self.client(local=True)
        listed = local.get(assets)
        self.data(listed)
        self.assertFalse(listed.data['meta']['canWrite'])
        self.assertFalse(listed.data['meta']['canExport'])
        self.data(local.post(assets, {}, format='json'), 403)
        self.data(local.post('/api/logistique/saisie-multiple/immobilisations', {}, format='json'), 403)
        for path in (assets + '/export.xlsx', '/api/logistique/registre/immobilisations/export.csv',
                     '/api/logistique/documents/immobilisation/1/fiche.pdf',
                     '/api/logistique/documents/immobilisation/1/pieces/1'):
            with self.subTest(path=path):
                self.data(local.get(path), 403)
        self.data(local.get('/api/logistique/registre/articles'))
        self.data(self.client(1, local=True).get(assets))
        self.data(platform.get(assets))

        payload['versions']['logistique.immobilisations'] = 1
        permissions['logistique.immobilisations'] = dict.fromkeys(inherited, False)
        response = self.data(platform.put(f'{endpoint}/{user}', payload, format='json'))
        local = self.client(local=True)
        for path in (assets, '/api/views/logistique/V_Immobilisation',
                     '/api/logistique/registre/immobilisations',
                     '/api/logistique/saisie-multiple/immobilisations/modele-excel',
                     '/api/tableaux/logistique.immobilisations/preferences'):
            with self.subTest(path=path):
                self.data(local.get(path), 403)
        self.data(local.get('/api/logistique/registre/articles'))

        payload['versions']['logistique.immobilisations'] = 2
        permissions['logistique.immobilisations'] = inherited
        permissions['logistique'] = dict.fromkeys(inherited, False)
        self.data(platform.put(f'{endpoint}/{user}', payload, format='json'))
        local = self.client(local=True)
        self.data(local.get(assets), 403)
        self.data(local.get('/api/articles'), 403)
        keys = {row['key'] for row in self.data(local.get('/api/workspace/modules'))}
        self.assertNotIn('logistique', keys)

        # Autoriser par défaut côté compte ne contourne jamais une licence absente.
        self.assertFalse(access_snapshot(self.actor(local=True))['modules']['caisse']['canRead'])
        self.assertTrue(db.one(
            """SELECT EXISTS(SELECT FROM systeme."T_Audit_Log" WHERE "TableName"=%s
               AND "IdEntiteFk"=%s AND "NewData"->>'userId'=%s) AS found""",
            ['systeme.T_UtilisateurModule', entity, str(user)],
        )['found'])

    def test_05_individual_tabs_deny_direct_and_alternative_routes(self):
        entity, user = self.entities[0], self.locals[0]
        db.query(
            """INSERT INTO systeme."T_LicenceModule" ("IdLicenceFk","CodeModule","Actif")
               SELECT %s, code, true FROM unnest(ARRAY['discussions','caisse','support']) AS code""",
            [self.licences[0]],
        )
        endpoint = '/api/workspace/droits-utilisateurs'
        platform = self.client()
        config = self.data(platform.get(endpoint, {'entite': entity}))
        codes = {item['CodeModule'] for item in config['catalogue']}
        inherited = {'canRead': True, 'canManage': True, 'canExport': True}
        permissions = {code: inherited.copy() for code in codes}
        for code in ('logistique.articles', 'caisse.ecritures', 'support.tickets',
                     'administration.utilisateurs', 'discussions.messages', 'professionnels.annuaire'):
            permissions[code] = dict.fromkeys(inherited, False)
        permissions['logistique.factures']['canExport'] = False
        self.data(platform.put(f'{endpoint}/{user}', {
            'entityId': entity, 'versions': dict.fromkeys(codes, 0), 'permissions': permissions,
        }, format='json'))
        local = self.client(local=True)
        for path in (
            '/api/logistique/registre/articles', '/api/models/T_Article',
            '/api/caisse/registres/ecritures', '/api/models/T_Paiement',
            '/api/support/tickets', '/api/support/tickets/export.xlsx',
            '/api/systeme/administration/registres/utilisateurs',
            '/api/discussions', '/api/discussions/1/lecture',
            '/api/professionnels/annuaire', '/api/public/experts',
        ):
            with self.subTest(path=path):
                self.data(local.post(path, {'messageIds': [1]}, format='json')
                          if path.endswith('/lecture') else local.get(path), 403)
        for path in ('/api/logistique/registre/commandes', '/api/caisse/registres/caisses',
                     '/api/discussions/demandes', '/api/professionnels/contexte'):
            with self.subTest(path=path):
                self.data(local.get(path))
        self.data(platform.get('/api/professionnels/annuaire'))
        self.data(self.client(1, local=True).get('/api/logistique/registre/articles'))
        self.data(local.get('/api/logistique/registre/factures'))
        self.data(local.get('/api/logistique/registre/factures/export.xlsx'), 403)
        prefs = self.data(local.get('/api/tableaux/logistique.commandes/preferences'))
        invoice_column = next(column for column in prefs['columns'] if column['id'] == 'CodeFacture')
        self.assertFalse(invoice_column['exportable'])
        self.data(local.get('/api/logistique/registre/commandes/export.csv', {
            'columns': '["CodeFacture"]',
        }), 400)

if __name__=='__main__': unittest.main(verbosity=2)
