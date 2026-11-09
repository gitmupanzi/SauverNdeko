"""Excel et paniers Support : mémoire uniquement, aucune connexion PostgreSQL.

Exécuter ce fichier seul. SQLite vérifie le retour arrière du lot et de son
audit ; le service métier reste simulé pour ne toucher aucun schéma client.
"""
import io
import json
import sys
import unittest
import uuid
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'backend'))
from django.conf import settings
if not settings.configured:
    settings.configure(SECRET_KEY='support-memory-tests', BASE_DIR=ROOT / 'backend',
        DATABASES={'default': {'ENGINE': 'django.db.backends.sqlite3', 'NAME': ':memory:'}},
        INSTALLED_APPS=[], USE_TZ=True, TIME_ZONE='Africa/Kinshasa', DB_READ_ONLY=False,
        REST_FRAMEWORK={'DEFAULT_AUTHENTICATION_CLASSES': [], 'UNAUTHENTICATED_USER': None})
import django
django.setup()
from django.core.files.uploadedfile import SimpleUploadedFile
from django.db import connection, transaction
from openpyxl import Workbook, load_workbook
from rest_framework.test import APIRequestFactory, force_authenticate
from apps.core.batch_excel import read_workbook
from apps.core.responses import APIError
from apps.support import batches, portal


def workbook(rows):
    book = Workbook()
    book.active.title = 'Tickets'
    for row in rows:
        book.active.append(row)
    result = io.BytesIO()
    book.save(result)
    book.close()
    return result.getvalue()


class SupportImportTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if connection.vendor != 'sqlite' or connection.settings_dict['NAME'] != ':memory:':
            raise RuntimeError('SQLite mémoire obligatoire ; aucune base applicative autorisée.')
        with connection.cursor() as cursor:
            cursor.execute('CREATE TABLE support_test_record (id INTEGER PRIMARY KEY, request TEXT UNIQUE, content TEXT, digest TEXT)')
            cursor.execute('CREATE TABLE support_test_audit (record_id INTEGER)')

    def setUp(self):
        self.actor = SimpleNamespace(pk=7, admin=True, is_authenticated=True)
        self.factory = APIRequestFactory()
        with connection.cursor() as cursor:
            cursor.execute('DELETE FROM support_test_audit')
            cursor.execute('DELETE FROM support_test_record')

    def body(self):
        return {'requestId': str(uuid.uuid4()), 'rows': [
            {'clientRowId': 'stable-a', 'data': {'Objet': 'Dossier A', 'Description': 'Description A'}},
            {'clientRowId': 'stable-b', 'data': {'Objet': 'Dossier B', 'Description': 'Description B'}},
        ]}

    def counts(self):
        with connection.cursor() as cursor:
            return tuple(cursor.execute('SELECT count(*) FROM ' + table).fetchone()[0]
                         for table in ('support_test_record', 'support_test_audit'))

    def save(self, actor, body, *, batch_digest):
        with transaction.atomic():
            content = json.dumps(body, sort_keys=True)
            with connection.cursor() as cursor:
                existing = cursor.execute('SELECT id,content,digest FROM support_test_record WHERE request=%s', [body['requestId']]).fetchone()
                if existing:
                    if (existing[1], existing[2]) != (content, batch_digest):
                        raise APIError('Autre contenu.', 'IDEMPOTENCY_CONFLICT', 409)
                    return {'ID_Support': existing[0]}, True
                if body.get('Objet') == 'invalide':
                    raise APIError({'Objet': 'Corrigez cet objet.'}, 'SUPPORT_VALIDATION', 422)
                cursor.execute('INSERT INTO support_test_record(request,content,digest) VALUES(%s,%s,%s)', [body['requestId'], content, batch_digest])
                pk = cursor.lastrowid
                cursor.execute('INSERT INTO support_test_audit(record_id) VALUES(%s)', [pk])
            return {'ID_Support': pk}, False

    def test_outer_transaction_rolls_back_all_records_and_audits(self):
        body = self.body()
        body['rows'][1]['data']['Objet'] = 'invalide'
        with patch.object(portal, '_write_access'), patch.object(portal, 'save', side_effect=self.save):
            with self.assertRaises(APIError) as caught:
                batches.create_batch(self.actor, body)
        self.assertEqual(caught.exception.status_code, 422)
        self.assertIn('stable-b', caught.exception.detail['rows'])
        self.assertEqual(self.counts(), (0, 0))
        self.assertEqual(body['rows'][0]['data']['Description'], 'Description A')

    def test_replay_is_stable_and_whole_content_is_bound(self):
        body = self.body()
        with patch.object(portal, '_write_access'), patch.object(portal, 'save', side_effect=self.save) as service:
            result, replay = batches.create_batch(self.actor, body)
            self.assertFalse(replay)
            again, replay = batches.create_batch(self.actor, body)
            self.assertTrue(replay)
            self.assertEqual(result, again)
            self.assertEqual(service.call_args_list[0].args[1]['requestId'], service.call_args_list[2].args[1]['requestId'])
            self.assertEqual(self.counts(), (2, 2))
            body['rows'].pop()
            with self.assertRaises(APIError) as caught:
                batches.create_batch(self.actor, body)
            self.assertEqual(caught.exception.default_code, 'IDEMPOTENCY_CONFLICT')
            self.assertEqual(self.counts(), (2, 2))

    def test_duplicate_row_keys_and_injected_fields_are_rejected(self):
        body = self.body()
        with patch.object(portal, '_write_access'), patch.object(portal, 'save') as service:
            body['rows'][1]['clientRowId'] = 'stable-a'
            with self.assertRaises(APIError): batches.create_batch(self.actor, body)
            body = self.body()
            body['rows'][0]['data']['IdEntiteFk'] = 99
            with self.assertRaises(APIError): batches.create_batch(self.actor, body)
            service.assert_not_called()

    def test_permission_denial_precedes_parsing_and_creation(self):
        with patch.object(portal, '_write_access', side_effect=APIError('Accès refusé.', 'FORBIDDEN', 403)), patch.object(portal, 'save') as save, patch.object(batches, 'read_uploaded_workbook') as reader:
            request = self.factory.post('/api/support/tickets/import-excel', {'fichier': SimpleUploadedFile('x.xlsx', b'broken')}, format='multipart')
            force_authenticate(request, self.actor)
            with patch.object(batches.HasModuleAccess, 'has_permission', return_value=True):
                response = batches.SupportExcelPreviewView.as_view()(request)
            self.assertEqual(response.status_code, 403)
            reader.assert_not_called()
            with self.assertRaises(APIError): batches.create_batch(self.actor, self.body())
            save.assert_not_called()

    def test_preview_returns_canonical_strings_without_business_writes(self):
        binary = workbook([['Objet', 'Description', 'Responsable'], ['Depuis Excel', 'À vérifier', '0012']])
        request = self.factory.post('/api/support/tickets/import-excel', {'fichier': SimpleUploadedFile('tickets.xlsx', binary)}, format='multipart')
        force_authenticate(request, self.actor)
        with patch.object(portal, '_write_access'), patch.object(portal, 'save') as save, patch.object(batches.HasModuleAccess, 'has_permission', return_value=True):
            response = batches.SupportExcelPreviewView.as_view()(request)
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['data']['matrix'], [['Objet', 'Description', 'ID_ResponsableFk'], ['Depuis Excel', 'À vérifier', '0012']])
        save.assert_not_called()
        self.assertEqual(self.counts(), (0, 0))

    def test_template_is_empty_native_and_uses_only_authorized_choices(self):
        context = {'canLinkAsset': False, 'requiredFields': ['Objet', 'Description'], 'references': {}, 'users': [
            {'id': 12, 'label': 'Agent autorisé'}, {'id': 99, 'label': 'Ancien agent', 'disabled': True}]}
        request = self.factory.get('/api/support/tickets/modele.xlsx')
        force_authenticate(request, self.actor)
        with patch.object(portal, '_write_access'), patch.object(portal, 'references', return_value=context), patch.object(batches.HasModuleAccess, 'has_permission', return_value=True):
            response = batches.SupportTemplateView.as_view()(request)
        book = load_workbook(io.BytesIO(b''.join(response.streaming_content)))
        self.assertEqual(book['Tickets']['A1'].value, 'Objet')
        self.assertNotIn('Immobilisation li\u00e9e', [cell.value for cell in book['Tickets'][1]])
        self.assertIsNone(book['Tickets']['A2'].value)
        self.assertEqual(book['Tickets']['A1'].fill.fgColor.rgb[-6:], 'F3F4F6')
        self.assertEqual(book['Tickets'].freeze_panes, 'A2')
        self.assertEqual(book['Options']['A2'].value, '12')
        self.assertIsNone(book['Options']['A3'].value)
        self.assertEqual(book['Options']['B2'].value, 'Agent autorisé')
        self.assertTrue(book['Tickets'].data_validations.dataValidation)
        self.assertEqual(response['Cache-Control'], 'no-store, private')
        book.close()

    def test_preview_checks_asset_permission_only_for_nonempty_links(self):
        self.actor._module_access = {
            'modules': {'logistique': {'canRead': True}},
            'tabs': {'logistique': {'immobilisations': {'canRead': False}}},
        }
        for asset, expected in ((None, 200), ('12', 403)):
            with self.subTest(asset=asset):
                binary = workbook([['Objet', 'Description', portal.ASSET_FIELD], ['A', 'B', asset]])
                upload = SimpleUploadedFile('tickets.xlsx', binary)
                request = self.factory.post('/api/support/tickets/import-excel', {'fichier': upload}, format='multipart')
                force_authenticate(request, self.actor)
                with patch.object(portal, '_write_access'), patch.object(batches.HasModuleAccess, 'has_permission', return_value=True):
                    response = batches.SupportExcelPreviewView.as_view()(request)
                self.assertEqual(response.status_code, expected)
                self.assertEqual(self.counts(), (0, 0))

    def test_formulas_are_rejected_before_preview(self):
        binary = workbook([['Objet', 'Description'], ['=1+2', 'Description']])
        with self.assertRaises(APIError):
            read_workbook(SimpleUploadedFile('x.xlsx', binary), sheet_name='Tickets', headers=batches.HEADERS,
                          required_headers=('Objet', 'Description'))

    def test_preview_accepts_full_description_limit_without_truncation(self):
        for size, expected in ((20000, 200), (20001, 400)):
            with self.subTest(size=size):
                binary = workbook([['Objet', 'Description'], ['Dossier', 'D' * size]])
                request = self.factory.post('/api/support/tickets/import-excel', {'fichier': SimpleUploadedFile('tickets.xlsx', binary)}, format='multipart')
                force_authenticate(request, self.actor)
                with patch.object(portal, '_write_access'), patch.object(batches.HasModuleAccess, 'has_permission', return_value=True):
                    response = batches.SupportExcelPreviewView.as_view()(request)
                self.assertEqual(response.status_code, expected)
                if expected == 200:
                    self.assertEqual(response.data['data']['matrix'][1][1], 'D' * size)
                self.assertEqual(self.counts(), (0, 0))

    def test_batch_digest_changes_the_existing_individual_replay_proof(self):
        body = {'requestId': str(uuid.uuid4()), 'Objet': 'A', 'Description': 'B'}
        queries = []
        def execute(sql, params):
            queries.append((sql, params))
            return []
        with patch.object(portal, 'read_entity', return_value=8), patch.object(portal, 'set_admin_actor'), patch.object(portal.db, 'query', side_effect=execute):
            portal._mutation_begin(self.actor, body, 'create', batch_digest='first')
            first = json.loads(queries[-1][1][0])['payloadHash']
            portal._mutation_begin(self.actor, body, 'create', batch_digest='different')
            second = json.loads(queries[-1][1][0])['payloadHash']
        self.assertNotEqual(first, second)


if __name__ == '__main__':
    unittest.main(verbosity=2)
