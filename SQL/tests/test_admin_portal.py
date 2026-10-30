"""Contrats de l’administration : assertions et mocks, aucune écriture en base.

Lancer avec le Python du backend. Les requêtes de mutation de cette recette
remplacent le dépôt par des mocks ; aucun compte ni droit réel n’est modifié.
"""
import io
import json
import os
import sys
import unittest
import zipfile
from pathlib import Path
from unittest.mock import patch
from xml.etree import ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "backend"))
os.environ["DJANGO_SETTINGS_MODULE"] = "config.settings"
os.environ["SAUVERNDEKO_DB_READ_ONLY"] = "1"
import django
django.setup()
from django.test import override_settings
from django.urls import resolve
from rest_framework.test import APIClient
from apps.accounts.authentication import Actor
from apps.core import admin_portal as portal
from apps.core.registry import model
from apps.core.repository import clean, secret_key
from apps.core.responses import APIError


class FakeCursor:
    def __init__(self, rows):
        self.rows = list(rows)
        self.executed = None
    def __enter__(self): return self
    def __exit__(self, *_): pass
    def execute(self, sql, params): self.executed = (sql, params)
    def fetchmany(self, count):
        rows, self.rows = self.rows[:count], self.rows[count:]
        return rows


class AdminPortalTests(unittest.TestCase):
    def setUp(self):
        self.override = override_settings(ALLOWED_HOSTS=["testserver"])
        self.override.enable()
        self.actor = Actor({"IdUser": 2147483600, "Is_Admin": True})
        self.client = APIClient()
        self.client.force_authenticate(self.actor)
        def fake_catalogue(actor, interface_key):
            # Les contrats d'export restent sans SQL ; la persistance réelle est
            # couverte séparément par test_preferences_tableaux.py en base privée.
            obj, *_ = portal.source(actor, interface_key.split(".",1)[1])
            return ([{"id":c["column_name"], "label":portal.LABELS[c["column_name"]],
                      "exportable":True} for c in obj["columns"]], 1, True)
        self.catalogue_patch=patch("apps.core.table_preferences.catalogue",side_effect=fake_catalogue)
        self.catalogue_patch.start()
        self.reference_patch=patch("apps.core.field_references.reference_context",return_value={"categoryIds":[39]})
        self.reference_patch.start()

    def tearDown(self):
        self.catalogue_patch.stop()
        self.reference_patch.stop()
        self.override.disable()

    def url(self, kind, suffix=""):
        return "/api/systeme/administration/registres/" + kind + suffix

    def test_authentication_and_platform_limits(self):
        anonymous = APIClient()
        self.assertIn(anonymous.get(self.url("audit")).status_code, {401, 403})
        local = Actor({"IdUser": 2147483599, "IdEntiteFk": 99, "Is_staff": True})
        with patch("apps.core.admin_portal.require_module"):
            for kind in portal.GLOBAL_ONLY:
                with self.assertRaises(APIError) as error:
                    portal.source(local, kind)
                self.assertEqual(error.exception.status_code, 403)

    def test_source_allowlist_and_roles_cannot_escape_category(self):
        with self.assertRaises(APIError): portal.source(self.actor, "T_Utilisateurs")
        with self.assertRaises(APIError): portal.selection(self.actor, "roles", {"filters": {"ID_CategorieGeneriqueFk": 42}})
        obj, where, params, order, *_ = portal.selection(self.actor, "roles", {"q": "test"})
        self.assertEqual(obj["name"], "V_Generique")
        self.assertIn('v."ID_CategorieGeneriqueFk"=ANY(%s::integer[])', where)
        self.assertIn([39], params)
        self.assertNotIn("test", where)
        self.assertIn('v."ID_Generique" ASC', order)

    def test_parameters_and_sort_are_closed(self):
        for raw in ({"bogus": 1}, {"sortBy": 'NomUser;DROP TABLE x'}, {"sortDir": "random"},
                    {"filters": {"MotdepasseUser": "x"}}, {"filters": {"OldData": {}}}):
            with self.assertRaises(APIError): portal.selection(self.actor, "utilisateurs", raw)

    def test_date_filters_use_actual_event_column(self):
        _, where, values, _, *_ = portal.selection(self.actor, "connexions", {"dateFrom": "2026-10-01", "dateTo": "2026-10-02", "timeZone": "Africa/Kinshasa"})
        self.assertIn('v."DateLogin">=%s', where)
        self.assertIn('v."DateLogin"<%s', where)
        self.assertEqual(values[-1].day, 3)
        self.assertIsNotNone(values[-1].tzinfo)
        _, where, values, *_ = portal.selection(self.actor, "audit", {"dateFrom": "2026-10-01"})
        self.assertIn('v."ChangedAt">=%s', where)
        self.assertIsNone(values[-1].tzinfo)
        for raw in ({"dateFrom": "invalid"}, {"dateFrom": "2026-10-02", "dateTo": "2026-10-01"}):
            with self.assertRaises(APIError): portal.selection(self.actor, "audit", raw)
        with self.assertRaises(APIError): portal.selection(self.actor, "roles", {"dateFrom": "2026-10-01"})

    def test_platform_journal_scope_and_local_record_scope(self):
        self.actor._context_entity = 99
        _, where, values, *_ = portal.selection(self.actor, "audit", {})
        self.assertEqual(where, "(TRUE)")
        self.assertEqual(values, [])
        _, where, values, *_ = portal.selection(self.actor, "utilisateurs", {})
        self.assertIn('v."IdEntite"=%s', where)
        self.assertEqual(values, [99])

    def test_list_paginates_and_cleans_history(self):
        records = [{"IdLog": 1, "TableName": "systeme.T_Utilisateurs", "OldData": {"password": "never", "details": {"refresh_token": "never"}}, "NewData": {"NomUser": "Fictif"}}]
        with patch("apps.core.admin_portal.db.one", side_effect=[{"n": 100}, {"n": 8}]), patch("apps.core.admin_portal.db.query", return_value=records) as query:
            response = self.client.get(self.url("audit"), {"q": "fictif", "take": 2, "skip": 2})
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data["meta"]["filteredCount"], 8)
        self.assertEqual(query.call_args[0][1][-2:], [2, 2])
        self.assertNotIn("never", json.dumps(response.data))
        self.assertEqual(response.data["data"][0]["OldData"], {"details": {}})

    def test_detail_uses_precise_localisation_key(self):
        with patch("apps.core.admin_portal.db.one", return_value={"IdEntiteLocalisation": 17, "IdEntite": 3}) as query:
            response = self.client.get(self.url("localisations", "/17"))
        self.assertEqual(response.status_code, 200)
        self.assertIn('v."IdEntiteLocalisation"=%s', query.call_args[0][0])
        self.assertEqual(query.call_args[0][1], [17])
        self.assertIn('v."IdEntiteLocalisation" IS NOT NULL', query.call_args[0][0])

    def test_user_role_is_joined_before_filter_sort_and_export(self):
        obj, where, values, order, *_ = portal.selection(self.actor, "utilisateurs", {"filters": {"IdRoleFk": 39}, "sortBy": "Role", "sortDir": "asc"})
        self.assertIn('v."IdRoleFk"=%s', where)
        self.assertEqual(values, [39])
        self.assertIn('v."Role" ASC', order)
        self.assertIn('systeme."V_User_profil"', portal.source_sql(obj))
        self.assertNotIn('MotdepasseUser', portal.source_sql(obj))
        self.assertIn("Role", [field["column_name"] for field in obj["columns"]])

    def test_raw_user_and_licence_fields_reach_existing_editor_routes(self):
        cases = [("utilisateurs", "T_Utilisateurs", {"IdUser": 17, "IdRoleFk": 42, "IdEntiteFk": 3, "UrlPhoto": "private", "MotdepasseUser": "never"}),
                 ("licences", "T_Licence", {"IdLicence": 17, "IdStatutLicenceFk": 55, "IdEntiteFk": 3})]
        for module, name, row in cases:
            with patch("apps.core.views.get_record", return_value=row) as get:
                response = self.client.get("/api/systeme/" + module + "/17")
            self.assertEqual(response.status_code, 200)
            self.assertEqual(get.call_args[0][0]["name"], name)
            for key in row:
                if key == "MotdepasseUser": self.assertNotIn(key, response.data["data"])
                else: self.assertEqual(row[key], response.data["data"][key])

    def test_secret_keys_and_legacy_nested_audit_are_masked(self):
        for name in ("Password", "Mot_de_passe", "JWT_SECRET", "refresh_token", "api-key", "smtpPassword"):
            self.assertTrue(secret_key(name), name)
        row = clean({"SettingKey": "smtp_password", "SettingValue": "never", "SettingValueJson": {"secret": "never"},
                     "OldData": '{"client_secret":"never","safe":1}', "NewData": {"items": [{"access_token": "never", "name": "safe"}]}})
        self.assertNotIn("never", json.dumps(row))
        self.assertEqual(row["SettingValue"], "[Masqué]")
        self.assertEqual(row["OldData"], {"safe": 1})

    def test_sensitive_setting_editor_get_has_explicit_readonly_hint(self):
        with patch("apps.core.views.get_record", return_value={"IdAdminUISetting": 8, "SettingKey": "smtp_password", "SettingValue": "never"}):
            response = self.client.get("/api/systeme/admin-ui-settings/8")
        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.data["meta"]["sensitive"])
        self.assertEqual(response.data["data"]["SettingValue"], "[Masqué]")

    def test_export_full_filter_scope_and_native_excel(self):
        cursor = FakeCursor([("=Fictif", "00042", True), ("Fictif 2", "00043", False)])
        with patch("apps.core.admin_portal.connection.cursor", return_value=cursor):
            response = self.client.get(self.url("roles", "/export.xlsx"), {"columns": json.dumps(["NomGenerique", "AbrGenerique", "ValideGenerique"]), "q": "Fictif", "take": 1, "skip": 1}, HTTP_ACCEPT=portal.XLSX_MEDIA_TYPE)
            self.assertEqual(response.status_code, 200)
            data = b"".join(response.streaming_content)
            response.close()
        self.assertEqual(response["X-Export-Row-Count"], "2")
        self.assertEqual(response["Content-Type"], portal.XLSX_MEDIA_TYPE)
        self.assertIn([39], cursor.executed[1])
        self.assertNotIn("OFFSET", cursor.executed[0])
        ns = {"m": "http://schemas.openxmlformats.org/spreadsheetml/2006/main"}
        sheet = ET.fromstring(zipfile.ZipFile(io.BytesIO(data)).read("xl/worksheets/sheet1.xml"))
        self.assertEqual(len(sheet.findall("m:sheetData/m:row", ns)), 3)
        self.assertEqual(sheet.findall(".//m:f", ns), [])
        self.assertIn("=Fictif", "".join(sheet.itertext()))
        self.assertIn("00042", "".join(sheet.itertext()))

    def test_export_secret_setting_even_without_visible_key(self):
        cursor = FakeCursor([("never", "smtp_password")])
        with patch("apps.core.admin_portal.connection.cursor", return_value=cursor):
            stream, count, _ = portal.admin_workbook(self.actor, "parametres", {"columns": '["SettingValue"]'})
            archive = zipfile.ZipFile(stream)
            sheet = archive.read("xl/worksheets/sheet1.xml").decode("utf8")
            stream.close()
        self.assertEqual(count, 1)
        self.assertNotIn("never", sheet)
        self.assertIn("Masqué", sheet)

    def test_export_refuses_bad_columns_and_honours_export_right(self):
        for raw in ({"columns": '["MotdepasseUser"]'}, {"columns": '["NomUser","NomUser"]'}, {"columns": "bad"}):
            with self.assertRaises(APIError): portal.admin_workbook(self.actor, "utilisateurs", raw)
        with patch("apps.core.admin_portal.require_module", side_effect=APIError("Refus", "FORBIDDEN", 403)):
            response = self.client.get(self.url("utilisateurs", "/export.xlsx"), HTTP_ACCEPT=portal.XLSX_MEDIA_TYPE)
        self.assertEqual(response.status_code, 403)
        self.assertEqual(response.accepted_media_type, "application/json")

    def test_setting_system_guards_precede_any_write(self):
        from apps.core.repository import _mutate
        rows = [{"IdAdminUISetting": 1, "IsEditable": False, "IsSystem": True, "SettingKey": "theme"},
                {"IdAdminUISetting": 1, "IsEditable": True, "IsSystem": True, "SettingKey": "theme"},
                {"IdAdminUISetting": 1, "IsEditable": True, "IsSystem": False, "SettingKey": "smtp_password"}]
        # Appeler la fonction décorée sans sa transaction évite tout accès à PostgreSQL.
        for old, body, operation in [(rows[0], {"SettingValue": "dark"}, "update"), (rows[1], {"SettingKey": "other"}, "update"),
                                     (rows[1], {}, "delete"), (rows[2], {"SettingValue": "never"}, "update")]:
            with patch("apps.core.repository.db.ensure_writable"), patch("apps.core.repository.get_record", return_value=old), patch("apps.core.repository.db.query") as query:
                with self.assertRaises(APIError) as error:
                    _mutate.__wrapped__("T_Admin_UI_Setting", self.actor, body, {"IdAdminUISetting": 1}, operation)
            self.assertEqual(error.exception.status_code, 409)
            query.assert_not_called()

    def test_shared_setting_author_is_server_owned_and_audit_is_sql_only(self):
        from apps.core.repository import _mutate
        for name, identity, body in (
            ("T_Admin_UI_Setting", "IdAdminUISetting", {"SettingValue": "dark"}),
            ("T_Fk_Correspondance", "IdFkCorrespondance", {"FieldLabel": "Catégorie"}),
        ):
            old = {identity: 17, "IsEditable": True, "IsSystem": False, "SettingKey": "theme"}
            received = {**body, "UpdatedAt": "2000-01-01T00:00:00Z", "CreatedAt": "2000-01-01T00:00:00Z", "UpdatedByUserFk": 99}
            with patch("apps.core.repository.db.ensure_writable"), patch("apps.core.repository.get_record", return_value=old), \
                 patch("apps.core.repository.db.one", return_value={**old, **body}) as update, \
                 patch("apps.core.repository.db.query") as context, patch("apps.core.repository.audit") as audit, patch("apps.core.reference_integration.validate_changed"):
                _mutate.__wrapped__(name, self.actor, received, {identity: 17}, "update")
            context.assert_called_once_with("SELECT set_config('systeme.actor_user_id',%s,true)", [str(self.actor.pk)])
            self.assertNotIn('"UpdatedAt"=', update.call_args[0][0])
            self.assertNotIn('"CreatedAt"=', update.call_args[0][0])
            self.assertNotIn('"UpdatedByUserFk"=', update.call_args[0][0])
            audit.assert_not_called()

    def test_secret_setting_cannot_be_created_through_public_admin_form(self):
        from apps.core.repository import _mutate
        with patch("apps.core.repository.db.ensure_writable"), patch("apps.core.repository.db.query") as query:
            with self.assertRaises(APIError) as error:
                _mutate.__wrapped__("T_Admin_UI_Setting", self.actor, {"SettingKey": "smtp_password", "SettingValue": "private"})
        self.assertEqual(error.exception.default_code, "SETTING_SECRET_PRIVATE")
        query.assert_not_called()

    def test_setting_rejects_nonobject_payload_before_any_sql(self):
        from apps.core.repository import _mutate
        for body in ([], ["SettingValue"], "dark", 1):
            with patch("apps.core.repository.db.ensure_writable"), patch("apps.core.repository.db.query") as query:
                with self.assertRaises(APIError) as error:
                    _mutate.__wrapped__("T_Admin_UI_Setting", self.actor, body)
            self.assertEqual(error.exception.status_code, 400)
            query.assert_not_called()


if __name__ == "__main__": unittest.main(verbosity=2)
