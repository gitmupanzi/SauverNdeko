"""Régression HTTP des exports XLSX. Aucune connexion ni écriture PostgreSQL."""
import io
import json
import os
import sys
import unittest
import zipfile
import xml.etree.ElementTree as ET
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "backend"))
os.environ["DJANGO_SETTINGS_MODULE"] = "config.settings"
os.environ["SAUVERNDEKO_DB_READ_ONLY"] = "1"
import django
django.setup()
from django.test import override_settings
from rest_framework.test import APIClient
from apps.accounts.authentication import Actor
from apps.core.responses import APIError
from apps.logistique.excel import XLSX_MEDIA_TYPE, write_workbook


class ExportHTTP(unittest.TestCase):
    routes = [
        ("/api/logistique/registre/articles/export.xlsx", "register_workbook"),
        ("/api/logistique/indicateurs/commandes/export.xlsx", "indicator_workbook"),
        ("/api/logistique/dossiers-suivi/articles-perimes/export.xlsx", "scope_workbook"),
    ]

    @classmethod
    def setUpClass(cls):
        cls.context = override_settings(ALLOWED_HOSTS=["testserver"])
        cls.context.enable()
        target = io.BytesIO()
        from datetime import datetime
        from decimal import Decimal
        from zoneinfo import ZoneInfo
        columns = [{"column_name":"CodeArticleInterne","label":"Code interne","data_type":"character varying"},{"column_name":"NomArticle","label":"Article","data_type":"character varying"},{"column_name":"QteArticle","label":"Stock","data_type":"numeric"}]
        write_workbook(target, columns, [{"CodeArticleInterne":"000123","NomArticle":"=Texte source","QteArticle":Decimal("1.250")}], {"title":"Recette fictive","scope":"Données fictives","generated":"25/10/2026 12:00","zone":"Africa/Kinshasa","tz":ZoneInfo("Africa/Kinshasa"),"source":"Recette sans base","raw":{},"filters":{},"order":"Code ASC"})
        cls.xlsx = target.getvalue()

    @classmethod
    def tearDownClass(cls):
        cls.context.disable()

    def client(self):
        client = APIClient()
        client.force_authenticate(Actor({"IdUser":2147483600,"Is_Admin":True}))
        return client

    def guards(self):
        from contextlib import ExitStack
        stack = ExitStack()
        stack.enter_context(patch("apps.core.permissions.IsERPAdmin.has_permission", return_value=True))
        stack.enter_context(patch("apps.logistique.followup_folders.get_definition", return_value={"name":"Recette fictive","objectType":"article","mode":"automatic","rules":{}}))
        stack.enter_context(patch("apps.logistique.followup_folders.folder_scope", return_value=(None,None,"TRUE",[],"",None,None,{})))
        return stack

    def test_excel_accept_downloads_native_file(self):
        with self.guards():
            for route, function in self.routes:
                with self.subTest(route=route), patch("apps.logistique.excel."+function, side_effect=lambda *args: (io.BytesIO(self.xlsx),1,"SauverNdeko_Recette_Complet.xlsx")):
                    response = self.client().get(route,HTTP_ACCEPT=XLSX_MEDIA_TYPE)
                    self.assertEqual(response.status_code,200)
                    self.assertEqual(response["Content-Type"],XLSX_MEDIA_TYPE)
                    self.assertEqual(response["X-Export-Row-Count"],"1")
                    self.assertEqual(response["Cache-Control"],"no-store, private")
                    self.assertIn("attachment",response["Content-Disposition"])
                    content = b"".join(response.streaming_content)
                    response.close()
                    self.assertEqual(content,self.xlsx)
                    with zipfile.ZipFile(io.BytesIO(content)) as book:
                        self.assertIn("xl/workbook.xml",book.namelist())
                        self.assertIn("000123",book.read("xl/worksheets/sheet1.xml").decode())
                        sheet=book.read("xl/worksheets/sheet1.xml").decode()
                        self.assertNotIn("<f>",sheet)
                        root=ET.fromstring(sheet)
                        ns={"x":"http://schemas.openxmlformats.org/spreadsheetml/2006/main"}
                        rows=root.findall("x:sheetData/x:row",ns)
                        self.assertEqual([row.get("r") for row in rows],["1","2"])
                        self.assertEqual(rows[0].find("x:c",ns).get("r"),"A1")
                        self.assertEqual(root.find("x:autoFilter",ns).get("ref"),"A1:C2")
                        self.assertEqual(root.find("x:sheetViews/x:sheetView/x:pane",ns).get("topLeftCell"),"B2")
                        self.assertIsNone(root.find("x:mergeCells",ns))
                        self.assertIsNone(root.find("x:drawing",ns))
                        styles=book.read("xl/styles.xml").decode()
                        self.assertIn('rgb="FFF3F4F6"',styles)
                        self.assertIn('rgb="FF374151"',styles)

    def test_errors_remain_json_with_excel_accept(self):
        with self.guards():
            for route, function in self.routes:
                for status in [400,403,404,413]:
                    with self.subTest(route=route,status=status), patch("apps.logistique.excel."+function,side_effect=APIError("Refus de recette.","EXPORT_TEST",status)):
                        response=self.client().get(route,HTTP_ACCEPT=XLSX_MEDIA_TYPE)
                        self.assertEqual(response.status_code,status)
                        self.assertTrue(response["Content-Type"].startswith("application/json"))
                        self.assertEqual(json.loads(response.content)["error"]["code"],"EXPORT_TEST")
                        self.assertNotIn("Content-Disposition",response)

    def test_quantity_keeps_its_unit_when_columns_are_selected(self):
        from apps.logistique.excel import export_columns
        obj={"name":"V_Article","columns":[{"column_name":key,"data_type":"text"} for key in ["NomArticle","QteArticle","Unite"]]}
        fields=export_columns(obj,{"columns":json.dumps(["NomArticle","QteArticle"])})
        self.assertEqual([field["column_name"] for field in fields],["NomArticle","QteArticle","Unite"])

    def test_sort_is_stable_for_equal_values(self):
        from apps.logistique.table_queries import query_order
        obj={"name":"V_Commande","columns":[{"column_name":key} for key in ["ID_Commande","DateCmd","CodeCmd"]]}
        self.assertEqual(query_order(obj,{})[0],'v."ID_Commande" DESC NULLS LAST')
        self.assertEqual(query_order(obj,{"sortBy":"DateCmd","sortDir":"desc"})[0],'v."DateCmd" DESC NULLS LAST,v."ID_Commande" ASC')

    def test_anonymous_remains_unauthorized(self):
        for route, _ in self.routes:
            with self.subTest(route=route):
                response=APIClient().get(route,HTTP_ACCEPT=XLSX_MEDIA_TYPE)
                self.assertEqual(response.status_code,401)
                self.assertTrue(response["Content-Type"].startswith("application/json"))

    def test_unrelated_media_type_remains_refused(self):
        for route, _ in self.routes:
            with self.subTest(route=route):
                response=self.client().get(route,HTTP_ACCEPT="image/png")
                self.assertEqual(response.status_code,406)
                self.assertTrue(response["Content-Type"].startswith("application/json"))


if __name__ == "__main__":
    unittest.main(verbosity=2)
