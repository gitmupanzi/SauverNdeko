"""Excel/paniers de profils : SQLite mémoire et service individuel simulé.

Exécuter seul. Ne charge pas le .env et refuse toute base applicative. Les tests
de transaction ne constituent pas une recette des triggers PostgreSQL existants.
"""
import hashlib
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
    settings.configure(SECRET_KEY='professional-memory-tests', BASE_DIR=ROOT / 'backend',
        DATABASES={'default': {'ENGINE': 'django.db.backends.sqlite3', 'NAME': ':memory:'}},
        INSTALLED_APPS=['django.contrib.auth', 'django.contrib.contenttypes', 'django.contrib.sessions'], USE_TZ=True, TIME_ZONE='Africa/Kinshasa', DB_READ_ONLY=False,
        DATA_UPLOAD_MAX_MEMORY_SIZE=3 * 1024 * 1024,
        REST_FRAMEWORK={'DEFAULT_AUTHENTICATION_CLASSES': [], 'UNAUTHENTICATED_USER': None})
import django
django.setup()
from django.core.files.uploadedfile import SimpleUploadedFile
from django.db import connection, transaction
from openpyxl import Workbook, load_workbook
from rest_framework.test import APIRequestFactory, force_authenticate
from apps.core.responses import APIError, ExactEncoder
from apps.professionnels import batches, services


def workbook(rows):
    book = Workbook()
    book.active.title = 'Profils'
    for row in rows:
        book.active.append(row)
    result = io.BytesIO()
    book.save(result)
    book.close()
    return result.getvalue()


class ProfessionalImportTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if connection.vendor != 'sqlite' or connection.settings_dict['NAME'] != ':memory:':
            raise RuntimeError('SQLite mémoire obligatoire ; aucune base applicative autorisée.')
        with connection.cursor() as cursor:
            cursor.execute('CREATE TABLE professional_excel_record (id INTEGER PRIMARY KEY, request TEXT UNIQUE, content TEXT, digest TEXT)')
            cursor.execute('CREATE TABLE professional_excel_audit (record_id INTEGER)')

    def setUp(self):
        self.actor = SimpleNamespace(pk=7, admin=True, is_authenticated=True)
        self.factory = APIRequestFactory()
        with connection.cursor() as cursor:
            cursor.execute('DELETE FROM professional_excel_audit')
            cursor.execute('DELETE FROM professional_excel_record')

    def body(self):
        return {'requestId': str(uuid.uuid4()), 'rows': [
            {'clientRowId': f'stable-{index}', 'data': {
                'IdUserFk': str(index + 11), 'IdTypeProfessionnelFk': '31',
                'IdSecteurFk': '41', 'TitrePublic': f'Profil {index}'},
             'competenceIds': ['51'], 'prestationIds': ['61'], 'affiliations': []}
            for index in range(2)]}

    def counts(self):
        with connection.cursor() as cursor:
            return tuple(cursor.execute('SELECT count(*) FROM ' + table).fetchone()[0]
                         for table in ('professional_excel_record', 'professional_excel_audit'))

    def create(self, actor, body, *, _batch_digest):
        with transaction.atomic():
            content = json.dumps(body, sort_keys=True)
            with connection.cursor() as cursor:
                existing = cursor.execute('SELECT id,content,digest FROM professional_excel_record WHERE request=%s', [body['requestId']]).fetchone()
                if existing:
                    if (existing[1], existing[2]) != (content, _batch_digest):
                        raise APIError('Autre contenu.', 'IDEMPOTENCY_CONFLICT', 409)
                    return {'record': {'IdProfessionnel': existing[0], 'Publie': False}, 'replayed': True}
                if body['data'].get('TitrePublic') == 'invalide':
                    raise APIError({'TitrePublic': 'Corrigez le titre.'}, 'PROFESSIONAL_VALIDATION', 422)
                cursor.execute('INSERT INTO professional_excel_record(request,content,digest) VALUES(%s,%s,%s)', [body['requestId'], content, _batch_digest])
                pk = cursor.lastrowid
                cursor.execute('INSERT INTO professional_excel_audit(record_id) VALUES(%s)', [pk])
            return {'record': {'IdProfessionnel': pk, 'Publie': False}, 'replayed': False}

    def test_rolls_back_whole_batch_and_audits_and_preserves_input(self):
        body = self.body()
        body['rows'][1]['data']['TitrePublic'] = 'invalide'
        snapshot = json.dumps(body, sort_keys=True)
        with patch.object(services, 'writable'), patch.object(services, 'create', side_effect=self.create):
            with self.assertRaises(APIError) as caught:
                batches.create_batch(self.actor, body)
        self.assertEqual(caught.exception.status_code, 422)
        self.assertIn('TitrePublic', caught.exception.detail['rows']['stable-1'])
        self.assertEqual(self.counts(), (0, 0))
        self.assertEqual(json.dumps(body, sort_keys=True), snapshot)

    def test_replay_is_stable_and_bound_to_entire_lot(self):
        body = self.body()
        with patch.object(services, 'writable'), patch.object(services, 'create', side_effect=self.create) as create:
            result, replayed = batches.create_batch(self.actor, body)
            self.assertFalse(replayed)
            again, replayed = batches.create_batch(self.actor, body)
            self.assertTrue(replayed)
            self.assertEqual(result, again)
            self.assertEqual(create.call_args_list[0].args[1]['requestId'], create.call_args_list[2].args[1]['requestId'])
            body['rows'].pop()
            with self.assertRaises(APIError) as caught:
                batches.create_batch(self.actor, body)
            self.assertEqual(caught.exception.default_code, 'IDEMPOTENCY_CONFLICT')
            self.assertEqual(self.counts(), (2, 2))

    def test_reordered_or_changed_rows_cannot_reuse_request(self):
        for change in ('reverse', 'title'):
            with self.subTest(change=change):
                body = self.body()
                with patch.object(services, 'writable'), patch.object(services, 'create', side_effect=self.create):
                    batches.create_batch(self.actor, body)
                    if change == 'reverse':
                        body['rows'].reverse()
                    else:
                        body['rows'][1]['data']['TitrePublic'] = 'Un autre titre'
                    with self.assertRaises(APIError) as caught:
                        batches.create_batch(self.actor, body)
                    self.assertEqual(caught.exception.default_code, 'IDEMPOTENCY_CONFLICT')

    def test_distinct_lines_for_same_account_are_both_flagged(self):
        body = self.body()
        body['rows'][1]['data']['IdUserFk'] = 11
        with patch.object(services, 'writable'), patch.object(services, 'create') as create:
            with self.assertRaises(APIError) as caught:
                batches.create_batch(self.actor, body)
            self.assertIn('IdUserFk', caught.exception.detail['rows']['stable-0'])
            self.assertIn('IdUserFk', caught.exception.detail['rows']['stable-1'])
            create.assert_not_called()

    def test_injected_owner_publication_and_photos_are_refused(self):
        for field, value, nested in [('IdEntiteFk', 999, True), ('Publie', True, True),
                                     ('photoDataUrl', 'data:image/png;base64,AAAA', False), ('removePhoto', True, False)]:
            with self.subTest(field=field), patch.object(services, 'writable'), patch.object(services, 'create') as create:
                body = self.body()
                target = body['rows'][0]['data'] if nested else body['rows'][0]
                target[field] = value
                with self.assertRaises(APIError):
                    batches.create_batch(self.actor, body)
                create.assert_not_called()

    def test_repeated_keys_oversize_empty_and_invalid_envelopes_are_refused(self):
        with patch.object(services, 'writable'), patch.object(services, 'create') as create:
            malformed = [None, {}, {'requestId': 'bad', 'rows': []}]
            body = self.body(); body['rows'][1]['clientRowId'] = body['rows'][0]['clientRowId']; malformed.append(body)
            body = self.body(); body['rows'] = []; malformed.append(body)
            body = self.body(); body['rows'] *= 51; malformed.append(body)
            body = self.body(); body['rows'][0]['data']['ObsProfessionnel'] = 'X' * (2 * 1024 * 1024); malformed.append(body)
            for body in malformed:
                with self.subTest(body=str(body)[:80]), self.assertRaises(APIError):
                    batches.create_batch(self.actor, body)
            create.assert_not_called()

    def test_required_fields_appear_on_correct_line(self):
        body = self.body()
        body['rows'][1]['data']['IdSecteurFk'] = None
        with patch.object(services, 'writable'), patch.object(services, 'create') as create:
            with self.assertRaises(APIError) as caught:
                batches.create_batch(self.actor, body)
            self.assertIn('IdSecteurFk', caught.exception.detail['rows']['stable-1'])
            create.assert_not_called()

    def test_whitespace_title_cannot_create_an_incomplete_profile(self):
        body = self.body()
        body['rows'][0]['data']['TitrePublic'] = ' \t\n '
        with patch.object(services, 'writable'), patch.object(services, 'create') as create:
            with self.assertRaises(APIError) as caught:
                batches.create_batch(self.actor, body)
            self.assertIn('TitrePublic', caught.exception.detail['rows']['stable-0'])
            create.assert_not_called()

    def test_nested_and_child_reference_errors_target_the_form_fields(self):
        error = APIError({'IdCompetenceFk': 'Compétence inactive.', 'IdPrestationFk': 'Prestation inactive.',
                          'affiliations.0.IdEntiteFk': 'Structure inactive.', 'data.IdUserFk': 'Compte invalide.'})
        with patch.object(services, 'writable'), patch.object(services, 'create', side_effect=error):
            with self.assertRaises(APIError) as caught:
                batches.create_batch(self.actor, self.body())
        for row in caught.exception.detail['rows'].values():
            self.assertEqual(set(row), {'competenceIds', 'prestationIds', 'affiliations', 'IdUserFk'})
            self.assertIn('inactive', row['affiliations'])

    def test_permission_denial_precedes_excel_parse_and_creates_nothing(self):
        request = self.factory.post('/api/professionnels/profils/import-excel', {'fichier': SimpleUploadedFile('broken.xlsx', b'broken')}, format='multipart')
        force_authenticate(request, self.actor)
        with patch.object(services, 'writable', side_effect=APIError('Accès refusé.', 'FORBIDDEN', 403)), patch.object(batches, 'read_uploaded_workbook') as reader, patch.object(services, 'create') as create, patch.object(batches.HasModuleAccess, 'has_permission', return_value=True):
            response = batches.ProfessionalExcelPreviewView.as_view()(request)
            self.assertEqual(response.status_code, 403)
            reader.assert_not_called()
            with self.assertRaises(APIError):
                batches.create_batch(self.actor, self.body())
            create.assert_not_called()

    def test_preview_is_only_canonical_cells_with_multichoices_and_leading_zeroes(self):
        binary = workbook([['Utilisateur', 'Secteur', 'Profession', 'Titre professionnel', 'Compétences', 'Services proposés', 'Autoriser les contacts'],
                           ['0012', 'Santé', 'Médecin', 'Titre', 'Oncologie;51', 'Consultation', 'Non']])
        request = self.factory.post('/api/professionnels/profils/import-excel', {'fichier': SimpleUploadedFile('profils.xlsx', binary)}, format='multipart')
        force_authenticate(request, self.actor)
        with patch.object(services, 'writable'), patch.object(services, 'create') as create, patch.object(batches.HasModuleAccess, 'has_permission', return_value=True):
            response = batches.ProfessionalExcelPreviewView.as_view()(request)
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['data']['matrix'][0], ['IdUserFk', 'IdSecteurFk', 'IdTypeProfessionnelFk', 'TitrePublic', 'competenceIds', 'prestationIds', 'ContactAutorise'])
        self.assertEqual(response.data['data']['matrix'][1][0], '0012')
        self.assertEqual(response.data['data']['matrix'][1][4], 'Oncologie;51')
        create.assert_not_called()
        self.assertEqual(self.counts(), (0, 0))

    def test_templates_blank_native_authorized_choices_not_names(self):
        refs = {'users': [{'id': 12, 'label': 'Compte autorisé'}, {'id': 99, 'label': 'Inactif', 'disabled': True}],
                'secteurs': [{'id': 40, 'label': 'Abréviation', 'name': 'Nom à ne pas afficher'}, {'id': 41, 'label': 'Incompatible', 'incompatible': True}]}
        request = self.factory.get('/api/professionnels/profils/modele-excel')
        force_authenticate(request, self.actor)
        with patch.object(services, 'writable'), patch.object(services, 'references', return_value=refs), patch.object(batches.HasModuleAccess, 'has_permission', return_value=True):
            response = batches.ProfessionalTemplateView.as_view()(request)
        book = load_workbook(io.BytesIO(b''.join(response.streaming_content)))
        self.assertEqual(book['Profils']['A1'].value, 'Utilisateur')
        self.assertIsNone(book['Profils']['A2'].value)
        self.assertEqual(book['Profils']['A1'].fill.fgColor.rgb[-6:], 'F3F4F6')
        self.assertEqual(book['Profils'].freeze_panes, 'A2')
        self.assertEqual(book['Profils'].max_column, 13)
        self.assertEqual(book['Profils'].max_row, 101)
        self.assertEqual(book['Options']['A2'].value, '12')
        self.assertIsNone(book['Options']['A3'].value)
        self.assertEqual(book['Options']['D2'].value, 'Abréviation')
        self.assertIsNone(book['Options']['D3'].value)
        self.assertTrue(book['Profils'].data_validations.dataValidation)
        self.assertEqual(response['Cache-Control'], 'no-store, private')
        book.close()

    def test_preview_enforces_actual_limits_and_no_formulas(self):
        for count, title, status in [(100, 'Titre', 200), (101, 'Titre', 400), (1, '=1+2', 400)]:
            with self.subTest(count=count, title=title):
                binary = workbook([['Utilisateur', 'Secteur', 'Profession', 'Titre professionnel'], *[['12', '40', '50', title] for _ in range(count)]])
                request = self.factory.post('/api/professionnels/profils/import-excel', {'fichier': SimpleUploadedFile('profils.xlsx', binary)}, format='multipart')
                force_authenticate(request, self.actor)
                with patch.object(services, 'writable'), patch.object(batches.HasModuleAccess, 'has_permission', return_value=True):
                    response = batches.ProfessionalExcelPreviewView.as_view()(request)
                self.assertEqual(response.status_code, status)
                self.assertEqual(self.counts(), (0, 0))

    def test_individual_digest_remains_compatible_and_batch_digest_is_distinct(self):
        body = self.body()['rows'][0]
        body = {key: value for key, value in body.items() if key != 'clientRowId'}
        body['requestId'] = str(uuid.uuid4())
        with patch.object(services, 'read_entity', return_value=8):
            individual = services.envelope(self.actor, body, 'create')[1]
            prior = hashlib.sha256(json.dumps({'actor': 7, 'entity': 8, 'id': None, 'operation': 'create', 'body': body}, sort_keys=True, ensure_ascii=True, cls=ExactEncoder).encode('utf8')).hexdigest()
            self.assertEqual(individual, prior)
            batch_one = services.envelope(self.actor, body, 'create', batch_digest='first')[1]
            batch_two = services.envelope(self.actor, body, 'create', batch_digest='second')[1]
            self.assertNotEqual(individual, batch_one)
            self.assertNotEqual(batch_one, batch_two)


if __name__ == '__main__':
    unittest.main(verbosity=2)
