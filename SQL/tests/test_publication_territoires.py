import os
from contextlib import nullcontext
from pathlib import Path
import sys
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'backend'))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')

import django
django.setup()

from django.test import SimpleTestCase, override_settings
from apps.accounts.authentication import Actor
from apps.core import territorial_portal as portal
from apps.core.responses import APIError


@override_settings(DB_READ_ONLY=False)
class TerritorialPublicationTests(SimpleTestCase):
    kind = 'niveaux3'
    key = 'ID_Niveau_3'

    def actor(self, *, manage=True, global_admin=True):
        actor = Actor({'IdUser': 17, 'Is_Admin': global_admin, 'Is_staff': True})
        actor._module_access = {'modules': {'territoires': {'canRead': True, 'canManage': manage,
            'canExport': False, 'reason': 'MODULE_ROLE_FORBIDDEN'}}}
        return actor

    def test_non_administrators_cannot_change_publication(self):
        for actor in (self.actor(global_admin=False), self.actor(manage=False)):
            with self.subTest(actor=actor), patch.object(portal.db, 'query') as query:
                with self.assertRaises(APIError) as failure:
                    portal.publication_request(actor, self.kind, {'ids': [1], 'published': False}, bulk=True)
                self.assertEqual(failure.exception.status_code, 403)
                query.assert_not_called()

    def test_rejects_duplicate_or_out_of_range_selection_without_writing(self):
        for ids in ([1, 1], [True], [2147483648], []):
            with self.subTest(ids=ids), patch.object(portal.db, 'query') as query:
                with self.assertRaises(APIError):
                    portal.publication_request(self.actor(), self.kind, {'ids': ids, 'published': True}, bulk=True)
                query.assert_not_called()

    def test_bulk_updates_only_changed_rows_and_logs_them(self):
        key, field = self.key, portal.PUBLICATION_FIELD
        rows = [{key: 3, field: False}, {key: 4, field: True}]
        actor = self.actor()
        with patch.object(portal.transaction, 'atomic', return_value=nullcontext()),              patch.object(portal, 'hierarchy_lock') as lock,              patch.object(portal, 'audit') as audit,              patch.object(portal.db, 'query', side_effect=[rows, [{key: 3}]]) as query:
            result = portal.publication_request(actor, self.kind, {'ids': [3, 4], 'published': True}, bulk=True)
        self.assertEqual(result, {'updatedCount': 1})
        lock.assert_called_once()
        self.assertIn('FOR UPDATE', query.call_args_list[0].args[0])
        self.assertEqual(query.call_args_list[1].args[1], [True, [3]])
        audit.assert_called_once()
        self.assertEqual(audit.call_args.kwargs['new'], {'ids': [3], field: True})

    def test_bulk_with_missing_ids_does_not_update_or_audit(self):
        rows = [{self.key: 3, portal.PUBLICATION_FIELD: False}]
        with patch.object(portal.transaction, 'atomic', return_value=nullcontext()),              patch.object(portal, 'hierarchy_lock'), patch.object(portal, 'audit') as audit,              patch.object(portal.db, 'query', return_value=rows) as query:
            with self.assertRaises(APIError) as failure:
                portal.publication_request(self.actor(), self.kind, {'ids': [3, 4], 'published': True}, bulk=True)
        self.assertEqual(failure.exception.status_code, 404)
        query.assert_called_once()
        audit.assert_not_called()

    def test_setting_updates_only_the_selected_level(self):
        with patch.object(portal.transaction, 'atomic', return_value=nullcontext()),              patch.object(portal, 'hierarchy_lock'), patch.object(portal, 'audit') as audit,              patch.object(portal.db, 'one', return_value={'PublierParDefaut': True}),              patch.object(portal.db, 'query') as query:
            result = portal.publication_request(self.actor(), 'niveaux5', {'published': False})
        self.assertEqual(result, {'published': False})
        self.assertEqual(query.call_args.args[1], [False, 5])
        self.assertIn('T_ParametrePublicationAnnuaire', query.call_args.args[0])
        audit.assert_called_once()
