"""Classification commerciale : API de lecture sans changement des habilitations."""
import os
import sys
import unittest
from pathlib import Path
from urllib.parse import urlsplit

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
from apps.core.module_access import access_snapshot,legacy_rights,MODULE_BY_KEY
from apps.core.application_licences import catalogue_rows


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
        business={'catalogue','logistique','support','caisse','territoires','professionnels','structures'}
        self.assertEqual({key for key,item in by_key.items() if item['type']=='MODULE'},business)
        for key,item in by_key.items():
            self.assertEqual(item['commercialisable'],key in business)
            if key in {'produits','sante'}: self.assertEqual(item['parentModule'],'catalogue')
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


if __name__=='__main__': unittest.main(verbosity=2)
