"""Préférences et exports réels, exclusivement dans une base privée de recette."""
import csv
import io
import json
import os
import sys
import unittest
import uuid
import zipfile
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime
from decimal import Decimal
from pathlib import Path
from urllib.parse import quote
from zoneinfo import ZoneInfo

import psycopg
from psycopg.conninfo import conninfo_to_dict
from psycopg.rows import dict_row

DSN = os.environ.get("SAUVERNDEKO_TEST_DATABASE_URL")
if not DSN:
    raise RuntimeError("Base de recette explicite obligatoire.")
params = conninfo_to_dict(DSN)
with psycopg.connect(DSN) as guard:
    name = guard.execute("SELECT current_database()").fetchone()[0]
    if not name.startswith("sauverndeko_test_"):
        raise RuntimeError("Recette refusée hors base privée sauverndeko_test_*.")
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "backend"))
os.environ["DATABASE_URL"] = "postgresql://" + quote(params["user"], safe="") + "@" + params["host"] + ":" + params["port"] + "/" + name
os.environ["DJANGO_SETTINGS_MODULE"] = "config.settings"
os.environ["SAUVERNDEKO_DB_READ_ONLY"] = "0"
import django
django.setup()
from django.conf import settings
from django.test import override_settings
from rest_framework.test import APIClient
from apps.accounts.authentication import Actor
from apps.core.table_preferences import settings_snapshot
from apps.core.tabular_exports import selected_scope, write_csv
from apps.core.responses import APIError
from apps.logistique.excel import write_workbook


class PreferencesTableaux(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.context = override_settings(ALLOWED_HOSTS=["testserver"])
        cls.context.enable()
        cls.c = psycopg.connect(DSN, autocommit=True, row_factory=dict_row)
        cls.entities = [cls.c.execute('INSERT INTO systeme."T_Entite" ("NomEntite","EmailEntite","ValideEntite") VALUES (%s,%s,true) RETURNING "IdEntite"',
                                    ["Entreprise fictive " + uuid.uuid4().hex,uuid.uuid4().hex+"@example.invalid"]).fetchone()["IdEntite"] for _ in range(2)]
        cls.users = []
        for entity in cls.entities:
            row = cls.c.execute('''INSERT INTO systeme."T_Utilisateurs"
                ("NomUser","PrenomUser","EmailUser","MotdepasseUser","ValideUser","SexeUser","Is_Admin","IdEntiteFk")
                VALUES ('Fictif','Recette',%s,'hachage-fictif-non-utilisable',true,'M',true,%s) RETURNING *''',
                [uuid.uuid4().hex + "@example.invalid", entity]).fetchone()
            cls.users.append(row)

    @classmethod
    def tearDownClass(cls):
        cls.c.close()
        cls.context.disable()

    def actor(self, user=0, entity=None):
        actor = Actor(self.users[user])
        if entity is not None:
            actor._context_entity = self.entities[entity]
        return actor

    def client(self, user=0, entity=None):
        client = APIClient()
        client.force_authenticate(self.actor(user, entity))
        return client

    def endpoint(self, key="logistique.articles"):
        return "/api/tableaux/" + key + "/preferences"

    def snapshot(self, user=0, entity=None, key="logistique.articles"):
        response = self.client(user, entity).get(self.endpoint(key))
        self.assertEqual(response.status_code, 200, response.data)
        return response.data["data"]

    def save(self, usage, columns, user=0, entity=None, key="logistique.articles"):
        previous = self.snapshot(user, entity, key)
        response = self.client(user, entity).put(self.endpoint(key),
            {"usage": usage, "columns": columns, "version": previous[usage]["version"]}, format="json")
        self.assertEqual(response.status_code, 200, response.data)
        return response.data["data"]

    def test_01_catalogue_defaults_and_no_writes_on_get(self):
        before = self.c.execute('SELECT count(*) n FROM referentiel."T_PreferenceTableau"').fetchone()["n"]
        value = self.snapshot()
        self.assertEqual(value["table"]["columns"][:3], ["NomArticle", "CategorieArticle", "TypeArticle"])
        self.assertEqual(value["export"]["columns"][:3], ["NomArticle", "CodeArticleInterne", "RefArticle"])
        self.assertFalse(next(c for c in value["columns"] if c["id"] == "actions")["exportable"])
        self.assertEqual(before, self.c.execute('SELECT count(*) n FROM referentiel."T_PreferenceTableau"').fetchone()["n"])

    def test_02_usages_independent_and_new_session(self):
        self.save("table", ["TypeArticle", "NomArticle", "actions"], entity=0)
        exported = self.save("export", ["RefArticle", "NomArticle", "CodeArticleInterne"], entity=0)
        self.assertEqual(exported["table"]["columns"], ["TypeArticle", "NomArticle", "actions"])
        # Nouveau client HTTP = aucun état React/localStorage ni session préalable.
        reconnected = self.snapshot(entity=0)
        self.assertEqual(reconnected["export"]["columns"], ["RefArticle", "NomArticle", "CodeArticleInterne"])

    def test_03_isolation_users_and_entities(self):
        self.save("table", ["NomArticle", "actions"], user=0, entity=0)
        self.assertFalse(self.snapshot(user=1, entity=0)["table"]["personal"])
        self.assertFalse(self.snapshot(user=0, entity=1)["table"]["personal"])
        self.assertEqual(self.snapshot(user=0, entity=0)["table"]["columns"], ["NomArticle", "actions"])

    def test_04_reset_only_one_usage(self):
        value = self.save("export", ["RefArticle", "NomArticle"], user=1, entity=1)
        value = self.save("table", ["NomArticle", "actions"], user=1, entity=1)
        response = self.client(1, 1).delete(self.endpoint(), {"usage": "table", "version": value["table"]["version"]}, format="json")
        self.assertEqual(response.status_code, 200)
        self.assertFalse(response.data["data"]["table"]["personal"])
        self.assertEqual(response.data["data"]["export"]["columns"], ["RefArticle", "NomArticle"])

    def test_05_stale_version_conflict(self):
        old = self.snapshot(key="referentiels.categories")
        self.save("table", ["NomCategorieGenerique", "actions"], key="referentiels.categories")
        response = self.client().put(self.endpoint("referentiels.categories"),
            {"usage": "table", "columns": ["NomCategorieGenerique"], "version": old["table"]["version"]}, format="json")
        self.assertEqual(response.status_code, 409)

    def test_06_unknown_duplicate_secret_and_action_export_refused(self):
        value = self.snapshot()
        for columns in (["actions"], ["MotdepasseUser"], ["NomArticle", "NomArticle"], [], ["__proto__"]):
            with self.subTest(columns=columns):
                response = self.client().put(self.endpoint(), {"usage": "export", "columns": columns, "version": value["export"]["version"]}, format="json")
                self.assertEqual(response.status_code, 400)

    def test_07_sql_actor_and_scope_guard(self):
        self.c.execute("SELECT set_config('systeme.actor_user_id','',false)")
        with self.assertRaises(psycopg.errors.CheckViolation):
            self.c.execute('INSERT INTO referentiel."T_PreferenceTableau" ("CleInterfaceFk","IdUserFk","Usage","Colonnes") VALUES (%s,%s,%s,%s::jsonb)',
                           ["logistique.articles", self.users[0]["IdUser"], "table", '["NomArticle"]'])

    def test_08_sql_unknown_and_nonexportable_refused(self):
        self.c.execute("SELECT set_config('systeme.actor_user_id',%s,false)", [str(self.users[1]["IdUser"])])
        for columns in ('["actions"]', '["MotdepasseUser"]', '["NomArticle","NomArticle"]'):
            with self.subTest(columns=columns), self.assertRaises(psycopg.errors.CheckViolation):
                self.c.execute('INSERT INTO referentiel."T_PreferenceTableau" ("CleInterfaceFk","IdUserFk","Usage","Colonnes") VALUES (%s,%s,%s,%s::jsonb)',
                               ["logistique.articles", self.users[1]["IdUser"], "export", columns])

    def test_09_no_actor_or_company_payload_override(self):
        response = self.client().put(self.endpoint(), {"usage":"table", "columns":["NomArticle"], "version":0, "IdUserFk":self.users[1]["IdUser"]}, format="json")
        self.assertEqual(response.status_code, 400)

    def test_10_anonymous_and_unknown_interface(self):
        self.assertIn(APIClient().get(self.endpoint()).status_code, [401, 403])
        self.assertEqual(self.client().get(self.endpoint("logistique.secret")).status_code, 404)

    def test_11_selection_validation_and_order(self):
        where, values = selected_scope({"selection":"[3,1]"}, "ID_Article")
        self.assertEqual(values, [[3,1]])
        self.assertIn('v."ID_Article"=ANY', where)
        _, values = selected_scope({"selection":'["1:2",{"ID_CmdFk":3,"ID_ArticleFk":4}]'}, ["ID_CmdFk","ID_ArticleFk"])
        self.assertEqual(values,[1,2,3,4])
        for invalid in ("[]", "[1,1]", "[true]", '["0 OR 1=1"]'):
            with self.subTest(invalid=invalid), self.assertRaises(APIError): selected_scope({"selection":invalid}, "ID_Article")

    def test_12_csv_bom_french_separator_quotes_newlines_formulas(self):
        fields=[{"column_name":key,"label":key,"data_type":kind} for key,kind in [("ref","text"),("label","text"),("qty","numeric"),("day","timestamp with time zone")]]
        rows=[{"ref":"000123","label":'École; "Nord"\nLigne',"qty":Decimal("1.250"),"day":datetime(2026,10,28,12,30,tzinfo=ZoneInfo("UTC"))},
              {"ref":"=1+1","label":" @SUM(1)","qty":Decimal("-2.5")}]
        target=io.BytesIO();write_csv(target,fields,rows,{"tz":ZoneInfo("Africa/Kinshasa")})
        self.assertTrue(target.getvalue().startswith(b"\xef\xbb\xbf"))
        decoded=list(csv.reader(io.StringIO(target.getvalue().decode("utf-8-sig")),delimiter=";"))
        self.assertEqual(decoded[1],["000123",'École; "Nord"\nLigne',"1,250","28/10/2026 13:30:00"])
        self.assertEqual(decoded[2][:3],["'=1+1","' @SUM(1)","-2,5"])

    def test_13_xlsx_native_numbers_dates_references_and_no_formula(self):
        columns=[{"column_name":key,"label":key,"data_type":kind} for key,kind in [("RefArticle","text"),("QteArticle","numeric"),("DateCmd","timestamp with time zone"),("NomArticle","text")]]
        context={"title":"Fictif","scope":"Recette","generated":"28/10/2026","zone":"Africa/Kinshasa","tz":ZoneInfo("Africa/Kinshasa"),"source":"Recette","raw":{},"filters":{},"order":"Référence ASC"}
        target=io.BytesIO();write_workbook(target,columns,[{"RefArticle":"000123","QteArticle":Decimal("1.25"),"DateCmd":datetime(2026,10,28,10,30),"NomArticle":"=1+1"}],context)
        with zipfile.ZipFile(io.BytesIO(target.getvalue())) as book:
            sheet=book.read("xl/worksheets/sheet1.xml").decode()
            self.assertIn("000123",sheet);self.assertIn("<v>1.25</v>",sheet)
            self.assertNotIn("<f>",sheet);self.assertIn('r="C2"',sheet)

    def test_14_reference_exports_full_filtered_and_selection(self):
        from apps.core.reference_exports import reference_workbook
        prefix="RecetteExport"+uuid.uuid4().hex
        ids=[self.c.execute('INSERT INTO referentiel."T_CategorieGenerique" ("NomCategorieGenerique") VALUES (%s) RETURNING "ID_CategorieGenerique"',[prefix+str(i)]).fetchone()["ID_CategorieGenerique"] for i in range(2)]
        stream,count,_=reference_workbook(self.actor(),"categories",{"q":prefix,"take":"1","columns":'["NomCategorieGenerique"]'})
        self.assertEqual(count,2);stream.close()
        stream,count,filename=reference_workbook(self.actor(),"categories",{"q":prefix,"selection":json.dumps([ids[1]]),"columns":'["NomCategorieGenerique"]'},file_format="csv")
        self.assertEqual(count,1);self.assertTrue(filename.endswith(".csv"));self.assertIn((prefix+"1").encode(),stream.read());stream.close()

    def test_15_all_catalogues_available_and_actions_nonexportable(self):
        keys=self.c.execute('SELECT "CleInterface" FROM referentiel."T_InterfaceTableau" ORDER BY 1').fetchall()
        self.assertGreaterEqual(len(keys),20)
        for item in keys:
            with self.subTest(key=item["CleInterface"]):
                data=self.snapshot(key=item["CleInterface"])
                self.assertNotIn("actions",data["export"]["columns"])
                self.assertTrue(data["columns"])

    def test_16_concurrent_saves_one_success_one_conflict(self):
        key="referentiels.valeurs"
        previous=self.snapshot(key=key)
        payload={"usage":"table","version":previous["table"]["version"]}
        def write(columns):
            from django.db import connections
            try:
                return self.client().put(self.endpoint(key),{**payload,"columns":columns},format="json").status_code
            finally:
                connections.close_all()
        with ThreadPoolExecutor(max_workers=2) as workers:
            results=list(workers.map(write,[["NomGenerique","actions"],["NomCategorieGenerique","NomGenerique"]]))
        self.assertEqual(sorted(results),[200,409])

    def test_17_consultant_preferences_do_not_grant_export(self):
        actor=self.actor(1,1)
        actor.row={**actor.row,"Is_Admin":False,"Is_staff":True}
        modules={key:{"canRead":True,"canManage":False,"canExport":False} for key in ("logistique","administration")}
        actor._module_access={"modules":modules}
        client=APIClient();client.force_authenticate(actor)
        response=client.get(self.endpoint())
        self.assertEqual(response.status_code,200);self.assertFalse(response.data["data"]["canExport"])
        version=response.data["data"]["table"]["version"]
        response=client.put(self.endpoint(),{"usage":"table","columns":["NomArticle","actions"],"version":version},format="json")
        self.assertEqual(response.status_code,200)
        response=client.get('/api/logistique/registre/articles/export.xlsx',{"columns":'["NomArticle"]'})
        self.assertEqual(response.status_code,403)

    def test_18_quantities_are_grouped_by_actual_unit(self):
        for key,label in ((34,"Unités"),(42,"Devise"),(64,"Type de commande")):
            self.c.execute('INSERT INTO referentiel."T_CategorieGenerique" ("ID_CategorieGenerique","NomCategorieGenerique") OVERRIDING SYSTEM VALUE VALUES (%s,%s) ON CONFLICT DO NOTHING',[key,label])
        for key,category,label,code in ((950001,34,"Pièce fictive","pcs"),(950002,34,"Kilogramme fictif","kg"),(950003,42,"USD","USD"),(950004,64,"Entrée","Entree")):
            self.c.execute('INSERT INTO referentiel."T_Generique" ("ID_Generique","ID_CategorieGeneriqueFk","NomGenerique","AbrGenerique") OVERRIDING SYSTEM VALUE VALUES (%s,%s,%s,%s) ON CONFLICT DO NOTHING',[key,category,label,code])
        articles=[]
        for unit in (950001,950002):
            articles.append(self.c.execute('''INSERT INTO logistique."T_Article"
                ("NomArticle","QteArticle","PUArticle","PVArticle","ID_UniteFk","ID_DeviseFk","ID_UserFK","IdEntiteFk")
                VALUES (%s,0,2,3,%s,950003,%s,%s) RETURNING "ID_Article"''',
                ["Article fictif "+uuid.uuid4().hex,unit,self.users[0]["IdUser"],self.entities[0]]).fetchone()["ID_Article"])
        cmd=self.c.execute('''INSERT INTO logistique."T_Commande" ("ID_TypeCmdFk","DateCmd","ID_DeviseFk","ID_UserFk","IdEntiteFk")
            VALUES (950004,now(),950003,%s,%s) RETURNING "ID_Commande"''',[self.users[0]["IdUser"],self.entities[0]]).fetchone()["ID_Commande"]
        def line(article,qty):
            self.c.execute('INSERT INTO logistique."T_CommandeDetail" ("ID_CmdFk","ID_ArticleFk","QteCmdDetail","PUCmdDetail") VALUES (%s,%s,%s,2)',[cmd,article,qty])
        line(articles[0],2)
        row=self.c.execute('SELECT * FROM logistique."V_QuantitesBonUnite" WHERE "ID_CmdFk"=%s',[cmd]).fetchone()
        self.assertEqual(row["QuantiteHomogene"],Decimal(2))
        self.assertIsInstance(row["QuantitesParUnite"][0]["quantite"],str)
        line(articles[1],3)
        row=self.c.execute('SELECT * FROM logistique."V_QuantitesBonUnite" WHERE "ID_CmdFk"=%s',[cmd]).fetchone()
        self.assertIsNone(row["QuantiteHomogene"]);self.assertEqual(row["NombreUnites"],2)
        self.assertEqual({item["code"] for item in row["QuantitesParUnite"]},{"pcs","kg"})

    def test_19_generic_crud_cannot_read_personal_settings(self):
        for key in ("T_InterfaceTableau","T_PreferenceTableau"):
            response=self.client().get('/api/models/'+key)
            self.assertEqual(response.status_code,403)

    def test_20_article_export_is_exact_order_and_selection(self):
        code="00"+uuid.uuid4().hex[:8]
        article=self.c.execute('''INSERT INTO logistique."T_Article"
            ("NomArticle","CodeArticleInterne","RefArticle","QteArticle","PUArticle","PVArticle","ID_UniteFk","ID_DeviseFk","ID_UserFK","IdEntiteFk")
            VALUES ('Écran de recette',%s,'000123',0,2.25,3,950001,950003,%s,%s) RETURNING "ID_Article"''',
            [code,self.users[0]["IdUser"],self.entities[0]]).fetchone()["ID_Article"]
        params={"columns":json.dumps(["RefArticle","NomArticle","CodeArticleInterne","PUArticle"]),"selection":json.dumps([article]),"take":1,"skip":100}
        response=self.client().get('/api/logistique/registre/articles/export.xlsx',params,HTTP_ACCEPT='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
        self.assertEqual(response.status_code,200,response.data if not response.streaming else None)
        self.assertEqual(response['X-Export-Row-Count'],'1')
        data=b''.join(response.streaming_content);response.close()
        with zipfile.ZipFile(io.BytesIO(data)) as book:
            sheet=book.read('xl/worksheets/sheet1.xml').decode()
            self.assertLess(sheet.index('Référence'),sheet.index('Article'))
            self.assertIn('000123',sheet);self.assertIn(code,sheet);self.assertIn('<v>2.25</v>',sheet)
            self.assertNotIn('Devise</t>',sheet)  # Aucun ajout implicite.
        response=self.client().get('/api/logistique/registre/articles/export.csv',params,HTTP_ACCEPT='text/csv')
        self.assertEqual(response.status_code,200)
        data=b''.join(response.streaming_content);response.close()
        parsed=list(csv.reader(io.StringIO(data.decode('utf-8-sig')),delimiter=';'))
        self.assertEqual(parsed[0],["Référence","Article","Code article","Prix d’achat"])
        self.assertEqual(parsed[1],["000123","Écran de recette",code,"2,25"])

    def test_21_admin_export_selection_and_forbidden_columns(self):
        path='/api/systeme/administration/registres/utilisateurs/export.csv'
        response=self.client().get(path,{"columns":'["EmailUser","NomUser"]',"selection":json.dumps([self.users[1]["IdUser"]])},HTTP_ACCEPT='text/csv')
        self.assertEqual(response.status_code,200)
        data=b''.join(response.streaming_content);response.close()
        parsed=list(csv.reader(io.StringIO(data.decode('utf-8-sig')),delimiter=';'))
        self.assertEqual(len(parsed),2);self.assertEqual(parsed[1],[self.users[1]['EmailUser'],'Fictif'])
        response=self.client().get(path,{"columns":'["MotdepasseUser"]'},HTTP_ACCEPT='text/csv')
        self.assertEqual(response.status_code,400)
        self.assertTrue(response['Content-Type'].startswith('application/json'))

    def test_22_reset_and_recreate_does_not_reuse_old_revision(self):
        key="logistique.lots"
        first=self.save("table",["NumeroLot","actions"],key=key)
        old=first["table"]["version"]
        response=self.client().delete(self.endpoint(key),{"usage":"table","version":old},format="json")
        self.assertEqual(response.status_code,200)
        next_value=self.save("table",["NomArticle","NumeroLot"],key=key)
        self.assertGreater(next_value["table"]["version"],old)
        response=self.client().put(self.endpoint(key),{"usage":"table","columns":["NumeroLot"],"version":old},format="json")
        self.assertEqual(response.status_code,409)

    def test_23_individual_document_keeps_reference_fields_not_list_preferences(self):
        article=self.c.execute('SELECT "ID_Article" FROM logistique."T_Article" WHERE "ID_UserFK"=%s AND "NomArticle"=%s ORDER BY "ID_Article" DESC LIMIT 1',
                              [self.users[0]["IdUser"],"Écran de recette"]).fetchone()["ID_Article"]
        self.save("export",["RefArticle"],entity=0)
        base='/api/logistique/registre/articles/export.xlsx'
        selection=json.dumps([str(article)])
        response=self.client(entity=0).get(base,{"selection":selection},HTTP_ACCEPT='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
        self.assertEqual(response.status_code,200)
        data=b''.join(response.streaming_content);response.close()
        with zipfile.ZipFile(io.BytesIO(data)) as book:
            sheet=book.read('xl/worksheets/sheet1.xml').decode()
            self.assertIn('Référence',sheet);self.assertNotIn('Code article',sheet)
        response=self.client(entity=0).get(base,{"documentScope":"record","selection":selection},HTTP_ACCEPT='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
        self.assertEqual(response.status_code,200)
        self.assertEqual(response['X-Export-Row-Count'],'1')
        data=b''.join(response.streaming_content);response.close()
        with zipfile.ZipFile(io.BytesIO(data)) as book:
            sheet=book.read('xl/worksheets/sheet1.xml').decode()
            self.assertIn('Référence',sheet);self.assertIn('Code article',sheet);self.assertIn('Prix d’achat',sheet)
        for invalid in ({"selection":"[]"},{"selection":"[1,2]"},{"selection":selection,"columns":'["MotdepasseUser"]'}):
            response=self.client(entity=0).get(base,{"documentScope":"record",**invalid})
            self.assertEqual(response.status_code,400)


if __name__ == "__main__":
    unittest.main(verbosity=2)
