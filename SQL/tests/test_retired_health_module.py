"""Retrait du parcours santé : vrais manifests/guide/routes, sans accès à la DB."""
import os
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'backend'))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
import django
django.setup()

from django.test import SimpleTestCase, override_settings
from rest_framework.test import APIClient
from apps.accounts.authentication import Actor
from apps.core import user_guide
from apps.core.module_access import MODULE_BY_KEY, INCLUSIONS, access_snapshot, require_module
from apps.core.responses import APIError


@override_settings(ALLOWED_HOSTS=['testserver'])
class RetiredHealthModule(SimpleTestCase):
    def setUp(self):
        self.actor = Actor({'IdUser':2147483600, 'Is_Admin':True, 'Is_staff':False,
                            'IdEntiteFk':None, 'ValideUser':True})
        self.client = APIClient()
        self.client.force_authenticate(self.actor)
        # Toute lecture ou écriture métier accidentelle fait échouer cette preuve.
        self.query = patch('apps.core.db.query', side_effect=AssertionError('DB interdite'))
        self.one = patch('apps.core.db.one', side_effect=AssertionError('DB interdite'))
        self.query.start()
        self.one.start()
        self.addCleanup(self.query.stop)
        self.addCleanup(self.one.stop)

    def test_manifest_and_permission_do_not_restore_retired_module(self):
        self.assertNotIn('sante', MODULE_BY_KEY)
        self.assertNotIn('sante', access_snapshot(self.actor)['modules'])
        with self.assertRaises(APIError) as rejected:
            require_module(self.actor, 'sante')
        self.assertEqual(rejected.exception.status_code, 404)
        self.assertEqual(INCLUSIONS['catalogue'], {'produits', 'structures', 'professionnels'})
        for key in INCLUSIONS['catalogue']:
            require_module(self.actor, key)

    def test_workspace_and_discovery_hide_health_for_global_admin(self):
        metadata = {key:{'type':'FONCTIONNALITE', 'commercialisable':False,
                         'parentModule':None, 'showInWorkspace':True}
                    for key in MODULE_BY_KEY}
        with patch('apps.core.workspace.application_metadata', return_value=metadata):
            launcher = self.client.get('/api/workspace/modules')
            catalogue = self.client.get('/api/workspace/catalogue')
        self.assertEqual(launcher.status_code, 200)
        self.assertEqual(catalogue.status_code, 200)
        for entries in (launcher.data['data'], catalogue.data['data']['modules']):
            self.assertNotIn('sante', {item['key'] for item in entries})
            self.assertNotIn('/maladies', {item['path'] for item in entries})

    def test_guide_removes_health_and_rejects_old_deep_link(self):
        _, modules = user_guide.content()
        self.assertEqual(set(modules), (set(MODULE_BY_KEY)-{'guide'})|{'referentiels'})
        self.assertNotIn('sante', modules)
        response = self.client.get('/api/guide/articles/sante/consulter-information-sante')
        self.assertEqual(response.status_code, 404)
        self.assertEqual(response.data['error']['code'], 'GUIDE_ARTICLE_NOT_FOUND')

    def test_retired_api_is_not_routed_and_remaining_apis_stay_protected(self):
        self.assertEqual(self.client.get('/api/public/maladies').status_code, 404)
        anonymous = APIClient()
        for path in ('/api/workspace/modules','/api/workspace/catalogue','/api/public/articles'):
            self.assertIn(anonymous.get(path).status_code, (401,403))


if __name__ == '__main__':
    unittest.main()
