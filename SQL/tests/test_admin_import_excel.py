"""Modèles et aperçu administratifs réels ; aucune connexion applicative."""
import io
import os
import sys
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'backend'))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
import django
django.setup()
from django.core.files.uploadedfile import SimpleUploadedFile
from openpyxl import Workbook, load_workbook
from rest_framework.test import APIRequestFactory, force_authenticate
from apps.accounts.authentication import Actor
from apps.core.admin_excel import (AdminExcelPreviewView, AdminExcelTemplateView,
                                   FIELDS, SHEETS, columns_for, excel_support)
from apps.core.responses import APIError


SUPPORT = {'entityId': 7, 'canCreate': True, 'roleCategoryId': 39,
           'roles': [{'id': 6, 'label': 'AG', 'name': 'Agent', 'active': True}],
           'entities': [{'id': 7, 'label': 'Entreprise fictive', 'active': True}],
           'categories': [{'id': 42, 'label': 'Famille fictive'}],
           'personnelServices': [], 'personnelFonctions': []}


class AdminExcelTests(unittest.TestCase):
    def setUp(self):
        self.factory = APIRequestFactory()
        self.actor = Actor({'IdUser': 15, 'Is_Admin': True, 'Is_staff': True, 'IdEntiteFk': 7})
        self.actor._module_access = {'modules': {'administration': {'canRead': True, 'canManage': True, 'canExport': True}}}
        blocked = patch('django.db.backends.base.base.BaseDatabaseWrapper.ensure_connection',
                        side_effect=AssertionError('Connexion applicative interdite.'))
        blocked.start(); self.addCleanup(blocked.stop)
        self.access = patch('apps.core.admin_excel.excel_support', return_value=SUPPORT)
        self.access.start(); self.addCleanup(self.access.stop)

    def upload(self, kind, headers=None, rows=None):
        book = Workbook(); sheet = book.active; sheet.title = SHEETS[kind]
        sheet.append(headers or [FIELDS[kind][0][0]])
        for row in rows or [['Valeur fictive']]: sheet.append(row)
        stream = io.BytesIO(); book.save(stream)
        return SimpleUploadedFile('modele.xlsx', stream.getvalue(),
            content_type='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')

    def preview(self, kind, file=None, extra=None, authenticated=True):
        request = self.factory.post('/api/systeme/administration/saisie-multiple/'+kind+'/import-excel',
                                    {'fichier': file or self.upload(kind), **(extra or {})}, format='multipart')
        if authenticated: force_authenticate(request, self.actor)
        return AdminExcelPreviewView.as_view()(request, kind=kind)

    def test_four_native_templates_have_blank_rows_and_safe_options(self):
        for kind in FIELDS:
            request = self.factory.get('/template')
            force_authenticate(request, self.actor)
            response = AdminExcelTemplateView.as_view()(request, kind=kind)
            self.assertEqual(response.status_code, 200)
            self.assertIn('no-store', response['Cache-Control'])
            book = load_workbook(io.BytesIO(b''.join(response.streaming_content)))
            sheet = book[SHEETS[kind]]
            self.assertEqual([c.value for c in sheet[1]], [c['label'] for c in columns_for(kind, SUPPORT)])
            self.assertEqual(sheet.freeze_panes, 'A2')
            self.assertTrue(sheet.auto_filter.ref)
            self.assertTrue(all(c.value is None for row in sheet.iter_rows(min_row=2) for c in row))
            self.assertNotIn('Is_Admin', [c['key'] for c in columns_for(kind, SUPPORT)])
            self.assertNotIn('Is_staff', [c['key'] for c in columns_for(kind, SUPPORT)])
            if kind == 'utilisateurs':
                self.assertIn('AG', [c.value for row in book['Options'] for c in row])
                self.assertNotIn('Agent', [c.value for row in book['Options'] for c in row])

    def test_preview_all_four_is_read_only_and_retains_zero_false_and_whitespace(self):
        for kind in FIELDS:
            response = self.preview(kind)
            self.assertEqual(response.status_code, 200, response.data)
            self.assertEqual(response.data['data']['count'], 1)
        file = self.upload('utilisateurs', ['Prénom', 'Nom', 'Mot de passe initial', 'Téléphone', 'Compte actif'],
                           [['Anne', 'Test', '  Fictif-secret-123  ', '00123', False]])
        response = self.preview('utilisateurs', file)
        self.assertEqual(response.data['data']['matrix'][1], ['Anne', 'Test', '  Fictif-secret-123  ', '00123', 'FALSE'])
        self.assertIn('no-store', response['Cache-Control'])

    def test_fixed_company_and_security_fields_cannot_be_imported(self):
        for field in ('IdEntiteFk', 'Is_Admin', 'Is_staff', 'IdUser', 'UrlPhoto'):
            response = self.preview('utilisateurs', self.upload('utilisateurs', ['Prénom', field], [['Anne', '8']]))
            self.assertEqual(response.status_code, 400, response.data)
        for kind in ('correspondances', 'parametres'):
            for field in ('SettingScope', 'ScopeValue', 'UpdatedByUserFk'):
                response = self.preview(kind, self.upload(kind, [FIELDS[kind][0][0], field], [['test', '8']]))
                self.assertEqual(response.status_code, 400, response.data)
        all_scope = {**SUPPORT, 'entityId': None}
        self.assertIn('IdEntiteFk', [c['key'] for c in columns_for('utilisateurs', all_scope)])
        self.assertIn('SettingScope', [c['key'] for c in columns_for('parametres', all_scope)])

    def test_rejects_formulas_unknown_duplicate_and_oversize_rows(self):
        for headers, rows in [(['Nom du rôle', 'NomGenerique'], [['A', 'B']]),
                              (['Nom du rôle', 'inconnu'], [['A', 'B']]),
                              (['Code du rôle'], [['A']]),
                              (['Nom du rôle'], [['=1+1']]),
                              (['Nom du rôle'], [['A']]*101)]:
            self.assertEqual(self.preview('roles', self.upload('roles', headers, rows)).status_code, 400)
        self.assertEqual(self.preview('roles', self.upload('roles', rows=[['Rôle']]*100)).status_code, 200)

    def test_permission_before_multipart_and_anonymous_denied(self):
        self.assertIn(self.preview('roles', authenticated=False).status_code, (401, 403))
        with patch('apps.core.admin_excel.excel_support', side_effect=APIError('Accès refusé.', 'FORBIDDEN', 403)):
            response = self.preview('roles', SimpleUploadedFile('corrompu.xlsx', b'pas-un-classeur'))
        self.assertEqual(response.status_code, 403)

    def test_local_manager_cannot_prepare_roles_or_structural_settings(self):
        self.access.stop()
        with patch('apps.core.admin_excel.db.ensure_writable'), patch('apps.core.admin_excel.require_admin_tab'), \
             patch('apps.core.admin_excel.management', return_value=False), \
             patch('apps.core.admin_excel.references', side_effect=AssertionError('Pas de références après refus.')):
            for kind in FIELDS:
                with self.assertRaises(APIError) as found: excel_support(self.actor, kind)
                self.assertEqual(found.exception.status_code, 403)

    def test_rejects_extra_parameters_and_no_mutation_route_called(self):
        with patch('apps.core.admin_operations.save_batch', side_effect=AssertionError('Aucune création avant validation.')):
            self.assertEqual(self.preview('roles').status_code, 200)
            self.assertEqual(self.preview('roles', extra={'Is_Admin': '1'}).status_code, 400)


if __name__ == '__main__': unittest.main()
