"""Contrôles SQL d'administration, uniquement dans une base privée sauverndeko_test_*."""
import json
import os
import unittest
import uuid

import psycopg
from psycopg.rows import dict_row

DSN = os.environ.get("SAUVERNDEKO_TEST_DATABASE_URL")
if not DSN:
    raise RuntimeError("SAUVERNDEKO_TEST_DATABASE_URL obligatoire ; aucun repli applicatif.")


def connect():
    connection = psycopg.connect(DSN, autocommit=True, row_factory=dict_row,
                                options="-c statement_timeout=10000 -c lock_timeout=5000")
    if not connection.execute("SELECT current_database() n").fetchone()["n"].startswith("sauverndeko_test_"):
        connection.close()
        raise RuntimeError("Recette refusée hors base privée sauverndeko_test_*.")
    return connection


class ControlesAdministration(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.c = connect()
        cls.user = cls.c.execute('''INSERT INTO systeme."T_Utilisateurs"
            ("NomUser","PrenomUser","EmailUser","MotdepasseUser","ValideUser","SexeUser")
            VALUES ('Fictif','Recette',%s,'hachage-fictif-non-utilisable',true,'M') RETURNING "IdUser"''',
            ["admin-" + uuid.uuid4().hex + "@example.invalid"]).fetchone()["IdUser"]

    @classmethod
    def tearDownClass(cls):
        cls.c.close()

    def setUp(self):
        self.c.execute("SELECT set_config('systeme.actor_user_id','',false)")

    def setting(self, **kwargs):
        data = {"SettingKey": "recette." + uuid.uuid4().hex, "SettingScope": "global",
                "SettingType": "text", "SettingValue": "avant", "IsEditable": True,
                "IsSystem": False, **kwargs}
        fields = list(data)
        statement = psycopg.sql.SQL('INSERT INTO systeme."T_Admin_UI_Setting" ({}) VALUES ({}) RETURNING *').format(
            psycopg.sql.SQL(',').join(map(psycopg.sql.Identifier, fields)),
            psycopg.sql.SQL(',').join(psycopg.sql.Placeholder() for _ in fields))
        return self.c.execute(statement, list(data.values())).fetchone()

    def mapping(self, **kwargs):
        data = {"ModuleName": "recette", "SchemaName": "systeme", "ViewName": None,
                "SourceKey": "recette." + uuid.uuid4().hex, "FieldName": "IdRoleFk",
                "MappingType": "generic_category", "MappingValue": "39",
                "SettingScope": "global", "ScopeValue": None, **kwargs}
        fields = list(data)
        statement = psycopg.sql.SQL('INSERT INTO systeme."T_Fk_Correspondance" ({}) VALUES ({}) RETURNING *').format(
            psycopg.sql.SQL(',').join(map(psycopg.sql.Identifier, fields)),
            psycopg.sql.SQL(',').join(psycopg.sql.Placeholder() for _ in fields))
        return self.c.execute(statement, list(data.values())).fetchone()

    def test_01_unique_global_setting(self):
        row = self.setting()
        with self.assertRaises(psycopg.errors.UniqueViolation):
            self.setting(SettingKey=row["SettingKey"])
        self.setting(SettingKey=row["SettingKey"], SettingScope="module", ScopeValue="logistique")

    def test_02_unique_mapping_with_nullable_view_and_scope(self):
        row = self.mapping()
        with self.assertRaises(psycopg.errors.UniqueViolation):
            self.mapping(SourceKey=row["SourceKey"])
        self.mapping(SourceKey=row["SourceKey"], SettingScope="entity", ScopeValue="1")

    def test_03_scope_consistency(self):
        for arguments in ({"ScopeValue": "1"}, {"SettingScope": "entite"},
                          {"SettingScope": "module", "ScopeValue": " "}):
            with self.subTest(arguments=arguments), self.assertRaises(psycopg.errors.CheckViolation):
                self.setting(**arguments)
        for arguments in ({"ScopeValue": "1"}, {"SettingScope": "entity"},
                          {"SettingScope": "country", "ScopeValue": " "}):
            with self.subTest(arguments=arguments), self.assertRaises(psycopg.errors.CheckViolation):
                self.mapping(**arguments)

    def test_04_noneditable_setting_stays_protected(self):
        row = self.setting(IsEditable=False)
        for statement in ('UPDATE systeme."T_Admin_UI_Setting" SET "SettingValue"=\'après\' WHERE "IdAdminUISetting"=%s',
                          'UPDATE systeme."T_Admin_UI_Setting" SET "IsEditable"=true WHERE "IdAdminUISetting"=%s',
                          'DELETE FROM systeme."T_Admin_UI_Setting" WHERE "IdAdminUISetting"=%s'):
            with self.assertRaises(psycopg.errors.CheckViolation):
                self.c.execute(statement, [row["IdAdminUISetting"]])

    def test_05_system_editable_value_allowed_identity_protected(self):
        row = self.setting(IsSystem=True)
        updated = self.c.execute('UPDATE systeme."T_Admin_UI_Setting" SET "SettingValue"=\'après\' WHERE "IdAdminUISetting"=%s RETURNING *',
                                 [row["IdAdminUISetting"]]).fetchone()
        self.assertEqual(updated["SettingValue"], "après")
        for field, value in (("SettingKey", "autre"), ("SettingType", "number"),
                             ("IsSystem", False), ("IsEditable", False)):
            with self.subTest(field=field), self.assertRaises(psycopg.errors.CheckViolation):
                self.c.execute(psycopg.sql.SQL('UPDATE systeme."T_Admin_UI_Setting" SET {}=%s WHERE "IdAdminUISetting"=%s').format(
                    psycopg.sql.Identifier(field)), [value, row["IdAdminUISetting"]])
        with self.assertRaises(psycopg.errors.CheckViolation):
            self.c.execute('DELETE FROM systeme."T_Admin_UI_Setting" WHERE "IdAdminUISetting"=%s', [row["IdAdminUISetting"]])

    def test_06_actor_and_dates_are_server_controlled(self):
        with self.c.transaction():
            self.c.execute("SELECT set_config('systeme.actor_user_id',%s,true)", [str(self.user)])
            row = self.setting(UpdatedByUserFk=None, UpdatedAt="2000-01-01T00:00:00+00:00")
            fk = self.mapping(UpdatedByUserFk=None, UpdatedAt="2000-01-01T00:00:00")
            self.assertEqual(row["UpdatedByUserFk"], self.user)
            self.assertEqual(fk["UpdatedByUserFk"], self.user)
            self.assertGreater(row["UpdatedAt"].year, 2020)
            expected = self.c.execute("SELECT CURRENT_TIMESTAMP AT TIME ZONE 'Africa/Kinshasa' n").fetchone()["n"]
            self.assertEqual(fk["UpdatedAt"], expected)
        direct = self.c.execute('UPDATE systeme."T_Admin_UI_Setting" SET "SettingValue"=\'direct\',"UpdatedByUserFk"=%s WHERE "IdAdminUISetting"=%s RETURNING *',
                                [self.user, row["IdAdminUISetting"]]).fetchone()
        self.assertIsNone(direct["UpdatedByUserFk"])
        self.assertEqual(direct["CreatedAt"], row["CreatedAt"])

    def test_07_invalid_actor_is_null(self):
        for value in ("abc", "2147483648", "0", "999999999", "-1"):
            with self.subTest(value=value), self.c.transaction():
                self.c.execute("SELECT set_config('systeme.actor_user_id',%s,true)", [value])
                self.assertIsNone(self.c.execute("SELECT systeme.fn_admin_actor_user_id() n").fetchone()["n"])

    def test_08_audit_once_per_dml_and_pascalcase_projection(self):
        with self.c.transaction():
            self.c.execute("SELECT set_config('systeme.actor_user_id',%s,true)", [str(self.user)])
            row = self.setting(SettingLabel="Libellé recette")
            self.c.execute('UPDATE systeme."T_Admin_UI_Setting" SET "SettingValue"=\'après\' WHERE "IdAdminUISetting"=%s', [row["IdAdminUISetting"]])
            self.c.execute('DELETE FROM systeme."T_Admin_UI_Setting" WHERE "IdAdminUISetting"=%s', [row["IdAdminUISetting"]])
        events = self.c.execute('SELECT * FROM systeme."V_Admin_UI_Setting_Audit" WHERE "SettingKey"=%s ORDER BY "IdLog"', [row["SettingKey"]]).fetchall()
        self.assertEqual([event["Operation"] for event in events], ["INSERT", "UPDATE", "DELETE"])
        self.assertTrue(all(event["UpdatedByUserId"] == str(self.user) for event in events))
        self.assertTrue(all(event["UpdatedByName"] == "Recette Fictif" for event in events))
        self.assertTrue(all(event["SettingLabel"] == "Libellé recette" for event in events))

    def test_09_fk_audit_once_and_legacy_bulk_replace(self):
        with self.c.transaction():
            self.c.execute("SELECT set_config('systeme.actor_user_id',%s,true)", [str(self.user)])
            row = self.mapping()
            self.c.execute('UPDATE systeme."T_Fk_Correspondance" SET "MappingValue"=\'40\' WHERE "IdFkCorrespondance"=%s', [row["IdFkCorrespondance"]])
            self.c.execute('DELETE FROM systeme."T_Fk_Correspondance" WHERE "IdFkCorrespondance"=%s', [row["IdFkCorrespondance"]])
            self.mapping(SourceKey=row["SourceKey"])
        events = self.c.execute('SELECT * FROM systeme."V_Fk_Correspondance_Audit" WHERE coalesce("NewData"->>\'SourceKey\',"OldData"->>\'SourceKey\')=%s ORDER BY "IdLog"', [row["SourceKey"]]).fetchall()
        self.assertEqual([event["Operation"] for event in events], ["INSERT", "UPDATE", "DELETE", "INSERT"])
        self.assertTrue(all(event["UpdatedByUserId"] == str(self.user) for event in events))

    def test_10_recursive_redaction_and_double_encoded_json(self):
        sample = {"ordinary": "visible", "Password": "invisible", "nested": [{"api_key": "invisible", "keep": 1}],
                  "jsonString": json.dumps({"refresh_token": "invisible", "keep": True}),
                  "SettingKey": "smtp.host-password", "SettingValue": "invisible", "SettingValueJson": {"any": "invisible"}}
        result = self.c.execute('SELECT systeme.fn_audit_sans_secrets(%s::jsonb) n', [json.dumps(sample)]).fetchone()["n"]
        self.assertNotIn("invisible", json.dumps(result))
        self.assertEqual(result["ordinary"], "visible")
        self.assertEqual(result["nested"], [{"keep": 1}])
        self.assertEqual(result["jsonString"], {"keep": True})
        self.assertEqual(result["SettingValue"], "[Masqué]")
        self.assertIsNone(self.c.execute('SELECT systeme.fn_audit_sans_secrets(NULL) n').fetchone()["n"])

    def test_11_sensitive_setting_never_reaches_stored_audit(self):
        row = self.setting(SettingKey="smtp.password." + uuid.uuid4().hex, SettingValue="FAKE_SECRET_NEVER_STORE")
        event = self.c.execute('SELECT "NewData" FROM systeme."T_Audit_Log" WHERE "TableName"=\'T_Admin_UI_Setting\' AND "NewData"->>\'SettingKey\'=%s', [row["SettingKey"]]).fetchone()
        self.assertNotIn("FAKE_SECRET_NEVER_STORE", json.dumps(event))
        self.assertEqual(event["NewData"]["SettingValue"], "[Masqué]")

    def test_12_legacy_camelcase_is_visible_and_cleaned(self):
        key = "smtp.password." + uuid.uuid4().hex
        self.c.execute('''INSERT INTO systeme."T_Audit_Log"("TableName","Operation","NewData","ChangedAt")
                       VALUES ('T_Admin_UI_Setting','UPDATE',%s::jsonb,CURRENT_TIMESTAMP)''',
                       [json.dumps({"settingKey": key, "settingValue": "FAKE_LEGACY_SECRET", "settingScope": "module",
                                    "scopeValue": "logistique", "updatedByName": "Ancien acteur"})])
        event = self.c.execute('SELECT * FROM systeme."V_Admin_UI_Setting_Audit" WHERE "SettingKey"=%s', [key]).fetchone()
        self.assertEqual(event["SettingValue"], "[Masqué]")
        self.assertEqual(event["SettingScope"], "module")
        self.assertEqual(event["ScopeValue"], "logistique")
        self.assertNotIn("FAKE_LEGACY_SECRET", json.dumps(event, default=str))

    def test_13_clearing_value_remains_null_in_audit_view(self):
        row = self.setting()
        self.c.execute('UPDATE systeme."T_Admin_UI_Setting" SET "SettingValue"=NULL WHERE "IdAdminUISetting"=%s', [row["IdAdminUISetting"]])
        event = self.c.execute('SELECT * FROM systeme."V_Admin_UI_Setting_Audit" WHERE "SettingKey"=%s ORDER BY "IdLog" DESC LIMIT 1', [row["SettingKey"]]).fetchone()
        self.assertIsNone(event["SettingValue"])
        self.assertEqual(event["OldData"]["SettingValue"], "avant")

    def test_14_direct_sql_actor_null_and_timezone_independent(self):
        with self.c.transaction():
            self.c.execute("SELECT set_config('systeme.actor_user_id',%s,true)", [str(self.user)])
            row = self.setting()
        with self.c.transaction():
            self.c.execute("SET LOCAL TIME ZONE 'UTC'")
            self.c.execute('UPDATE systeme."T_Admin_UI_Setting" SET "SettingValue"=\'SQL direct\' WHERE "IdAdminUISetting"=%s', [row["IdAdminUISetting"]])
            event = self.c.execute('SELECT * FROM systeme."V_Admin_UI_Setting_Audit" WHERE "SettingKey"=%s ORDER BY "IdLog" DESC LIMIT 1', [row["SettingKey"]]).fetchone()
            expected = self.c.execute("SELECT CURRENT_TIMESTAMP AT TIME ZONE 'Africa/Kinshasa' n").fetchone()["n"]
            self.assertEqual(event["ChangedAt"], expected)
            self.assertIsNone(event["UpdatedByUserId"])
            self.assertIsNone(event["UpdatedByName"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
