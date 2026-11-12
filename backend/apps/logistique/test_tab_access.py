from types import SimpleNamespace
from unittest.mock import patch

from django.test import SimpleTestCase
from django.urls import resolve

from apps.core.responses import APIError
from apps.core.views import mutation_response
from apps.logistique.excel import register_workbook
from apps.logistique.reads import restrict_order_source, row_source
from apps.logistique.tab_access import enforce_logistics_request, restricted_fields, validate_invoice_changes


class LogisticsTabAccessTests(SimpleTestCase):
    def setUp(self):
        self.actor = SimpleNamespace(global_admin=False)
        self.permissions = {"canRead": True, "canManage": True, "canExport": True}
        self.tabs = {}
        snapshot = patch("apps.core.module_access.access_snapshot", return_value={
            "modules": {"logistique": self.permissions},
            "tabs": {"logistique": self.tabs},
        })
        snapshot.start()
        self.addCleanup(snapshot.stop)

    def deny(self, tab, *rights):
        self.tabs[tab] = {**self.permissions, **dict.fromkeys(rights, False)}

    def authorize(self, path, action="read", query=None):
        match = resolve(path)
        request = SimpleNamespace(path_info=path, query_params=query or {})
        return enforce_logistics_request(self.actor, request, SimpleNamespace(kwargs=match.kwargs), action)

    def test_article_read_does_not_allow_mutation_or_exports(self):
        self.deny("articles", "canManage", "canExport")
        self.assertTrue(self.authorize("/api/logistique/registre/articles"))
        for path, action in [
            ("/api/logistique/saisie-multiple/articles/apercu-excel", "manage"),
            ("/api/logistique/registre/articles/export.xlsx", "export"),
            ("/api/logistique/registre/articles/export.csv", "export"),
        ]:
            with self.subTest(path=path), self.assertRaises(APIError):
                self.authorize(path, action)

    def test_stock_card_export_checks_both_source_tabs(self):
        self.deny("articles", "canExport")
        for extension in ("xlsx", "csv"):
            path = "/api/logistique/registre/mouvements/export." + extension
            query = {"documentScope": "stock-card", "articleId": "2"}
            with self.subTest(extension=extension):
                self.assertTrue(self.authorize(path, "export"))
                with self.assertRaises(APIError):
                    register_workbook(self.actor, "mouvements", query, file_format=extension)

    def test_forbidden_lines_cannot_be_recovered_from_a_related_workspace(self):
        self.deny("details", "canRead", "canManage", "canExport")
        self.assertTrue(self.authorize("/api/logistique/consultations/commande/19"))
        for path, action in [
            ("/api/logistique/consultations/produit/2/commandes", "read"),
            ("/api/logistique/consultations/commande/19/lignes", "read"),
            ("/api/logistique/commandes/19/details", "read"),
            ("/api/logistique/commandes/19/composition", "manage"),
            ("/api/logistique/documents/bon/19/sortie.pdf", "export"),
        ]:
            with self.subTest(path=path), self.assertRaises(APIError):
                self.authorize(path, action)

    def test_dashboard_uses_read_and_export_rights_of_its_data_sources(self):
        self.deny("reglements", "canExport")
        self.assertTrue(self.authorize("/api/logistique/indicateurs/facturesSoldees"))
        with self.assertRaises(APIError):
            self.authorize("/api/logistique/indicateurs/facturesSoldees/export.xlsx", "export")
        self.deny("reglements", "canRead", "canExport")
        self.assertTrue(self.authorize("/api/logistique/synthese"))
        with self.assertRaises(APIError):
            self.authorize("/api/logistique/indicateurs/facturesSoldees")

    def test_only_minimal_depot_choices_bypass_the_depots_register_right(self):
        self.deny("depots", "canRead", "canManage", "canExport")
        self.assertTrue(self.authorize("/api/logistique/depots", query={"usage": "selection"}))
        for path, action in [
            ("/api/logistique/depots", "read"),
            ("/api/logistique/depots/3", "read"),
            ("/api/logistique/depots/export.xlsx", "export"),
        ]:
            with self.subTest(path=path), self.assertRaises(APIError):
                self.authorize(path, action)

    def test_same_fields_are_masked_on_excel_even_when_visible_on_screen(self):
        self.deny("factures", "canExport")
        self.deny("reglements", "canExport")
        obj = {"name": "V_Commande", "schema": "logistique", "columns": [
            {"column_name": "CodeCmd", "data_type": "character varying"},
            {"column_name": "CodeFacture", "data_type": "character varying"},
            {"column_name": "TotalRegleReel", "data_type": "numeric"},
        ]}
        self.assertNotIn("CodeFacture", restricted_fields(self.actor))
        export_source = row_source(restrict_order_source(obj, self.actor, action="export"))
        self.assertIn('v."CodeCmd"', export_source)
        self.assertIn('NULL::character varying AS "CodeFacture"', export_source)
        self.assertIn('NULL::numeric AS "TotalRegleReel"', export_source)

    def test_order_changes_cannot_modify_invoice_fields(self):
        self.deny("factures", "canManage")
        previous = {"CodeFacture": "fac-19", "ID_ModePaiementFk": 2}
        validate_invoice_changes(self.actor, {"CodeFacture": "fac-19", "RefCmd": "livraison"}, previous)
        validate_invoice_changes(self.actor, {"CodeFacture": None}, None)
        for update in [{"CodeFacture": None}, {"ID_ModePaiementFk": 3}, {"UrlFacture": "/facture.pdf"}]:
            with self.subTest(update=update), self.assertRaises(APIError):
                validate_invoice_changes(self.actor, update, previous)

    def test_legacy_order_record_and_register_apply_different_protection(self):
        self.deny("reglements", "canRead", "canManage", "canExport")
        self.assertTrue(self.authorize("/api/logistique/commandes/19"))
        with self.assertRaises(APIError):
            self.authorize("/api/logistique/commandes")

    def test_legacy_order_mutation_does_not_disclose_restricted_fields(self):
        self.deny("factures", "canRead", "canManage", "canExport")
        self.deny("details", "canRead", "canManage", "canExport")
        result = {"CodeCmd": "BS-19", "CodeFacture": "fac-19", "ListeArticles": "Article réservé"}
        response = mutation_response(self.actor, {"name": "T_Commande"}, result)
        self.assertEqual(response.data["data"], {"CodeCmd": "BS-19"})
