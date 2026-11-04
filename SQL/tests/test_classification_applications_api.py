"""Classification commerciale : API de lecture sans changement des habilitations."""
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
from django.db import DatabaseError
import test_publication_articles_api as publication


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
        for key,item in by_key.items():
            self.assertEqual(item['commercialisable'],key in business)
            if key in {'produits','discussions'}: self.assertIsNone(item['parentModule'])
        self.assertNotIn('sante',by_key)
        self.assertNotIn('catalogue',by_key)
        self.assertEqual(by_key['referentiels']['path'],'/referentiels')
        self.assertEqual(by_key['referentiels']['type'],'FONCTIONNALITE')
        catalogue=client.get('/api/workspace/catalogue')
        self.assertEqual(catalogue.status_code,200,catalogue.data)
        for item in catalogue.data['data']['modules']:
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
        self.assertIsNone(catalogue['catalogue']['parentModule'])
        self.assertEqual(catalogue['catalogue']['type'],'FONCTIONNALITE')
        self.assertFalse(catalogue['catalogue']['commercialisable'])
        self.assertFalse(catalogue['catalogue']['showInWorkspace'])
        self.assertTrue(catalogue['catalogue']['canRead'])
        with self.assertRaises(APIError) as error:
            require_module(self.actor,'sante')
        self.assertEqual(error.exception.status_code,404)
        self.assertEqual(client.get('/api/public/maladies').status_code,404)
        self.assertNotIn('referentiels',catalogue)
        self.assertEqual(set(catalogue),set(MODULE_BY_KEY))

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
    """Comptes fictifs de deux entreprises : la présentation n'accorde rien."""
    setUpClass=publication.ArticlePublicationAPI.__dict__['setUpClass']
    tearDownClass=publication.ArticlePublicationAPI.__dict__['tearDownClass']
    actor=publication.ArticlePublicationAPI.actor
    client=publication.ArticlePublicationAPI.client
    data=publication.ArticlePublicationAPI.data
    setUp=publication.ArticlePublicationAPI.setUp

    def test_01_module_products_still_requires_existing_licence(self):
        from apps.accounts.authentication import actor_by_id
        self.connection.execute('UPDATE systeme."T_Utilisateurs" SET "Is_staff"=false WHERE "IdUser"=%s',[self.locals[2]])
        actor=actor_by_id(self.locals[2]);snapshot=access_snapshot(actor)
        self.assertFalse(snapshot['modules']['produits']['canRead'])
        self.assertFalse(snapshot['modules']['produits']['available'])
        self.assertTrue(snapshot['modules']['discussions']['canRead'])
        self.assertTrue(snapshot['modules']['discussions']['base'])
        keys={item['key'] for item in self.data(self.client(2,local=True).get('/api/workspace/modules'))}
        self.assertNotIn('produits',keys)
        self.assertNotIn('sante',keys)
        self.assertIn('discussions',keys)
        self.assertNotIn('referentiels',keys)
        self.data(self.client(2,local=True).get('/api/produits/offres'),403)
        self.data(self.client(2,local=True).get('/api/models/T_CategorieGenerique'),403)
        self.data(self.client(2,local=True).get('/api/views/referentiel/V_Generique'),403)

    def test_02_catalogue_inclusion_and_company_context_are_unchanged(self):
        before=self.connection.execute('SELECT to_jsonb(m) row FROM systeme."T_LicenceModule" m ORDER BY "IdLicenceModule"').fetchall()
        actor=self.actor(local=True);snapshot=access_snapshot(actor)
        self.assertTrue(snapshot['modules']['produits']['canRead'])
        self.assertFalse(snapshot['modules']['produits']['base'])
        self.assertEqual(snapshot['modules']['produits']['includedBy'],'catalogue')
        launcher=self.data(self.client(local=True).get('/api/workspace/modules'))
        self.assertIn('referentiels',{item['key'] for item in launcher})
        products=next(item for item in launcher if item['key']=='produits')
        self.assertEqual(products['type'],'MODULE')
        self.assertTrue(products['commercialisable'])
        self.assertIsNone(products['parentModule'])
        catalogue=self.data(self.client(local=True).get('/api/workspace/catalogue'))
        self.assertEqual(catalogue['entityId'],self.entities[0])
        self.assertEqual({item['key'] for item in catalogue['modules']},set(MODULE_BY_KEY))
        after=self.connection.execute('SELECT to_jsonb(m) row FROM systeme."T_LicenceModule" m ORDER BY "IdLicenceModule"').fetchall()
        self.assertEqual(before,after)


if __name__=='__main__': unittest.main(verbosity=2)
