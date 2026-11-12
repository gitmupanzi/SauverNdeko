"""Règles réelles de présentation, isolées de Django et de toute base de données.

Seules les définitions et fonctions pures du module sont chargées par AST.
La sauvegarde/API et les permissions SQL ne sont pas simulées comme une recette réelle.
"""

import ast
import hashlib
import json
from pathlib import Path
import re
import unicodedata
import unittest


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "backend/apps/core/module_presentation.py"
CONSTANTS = {"PRESENTATIONS", "REQUIRED_FIELDS", "PRESENTATION_FIELDS"}
FUNCTIONS = {"definition_for", "validate_hidden", "validate_values", "revision_for",
             "stored_values", "presentation_data"}


class APIError(Exception):
    pass


namespace = {"APIError": APIError, "hashlib": hashlib, "json": json,
             "unicodedata": unicodedata, "ExactEncoder": json.JSONEncoder}
tree = ast.parse(SOURCE.read_text(encoding="utf-8-sig"), filename=str(SOURCE))
nodes = [node for node in tree.body
         if (isinstance(node, ast.Assign)
             and any(isinstance(target, ast.Name) and target.id in CONSTANTS for target in node.targets))
         or (isinstance(node, ast.FunctionDef) and node.name in FUNCTIONS)]
exec(compile(ast.Module(body=nodes, type_ignores=[]), str(SOURCE), "exec"), namespace)


class PresentationCatalogueTests(unittest.TestCase):
    def setUp(self):
        self.definition = namespace["definition_for"]("logistique")

    def test_logistique_defaults_follow_real_navigation_and_add_depots(self):
        expected = ["dashboard", "dossiers", "tiers", "depots", "stocks-depots", "articles", "lots",
                    "commandes", "details", "transferts", "mouvements",
                    "inventaires", "lignes-inventaires", "factures", "reglements", "immobilisations"]
        self.assertEqual(list(self.definition["tabDefaults"]), expected)
        navigation = (ROOT / "frontend/src/pages/Logistique.jsx").read_text(encoding="utf-8-sig")
        declarations = navigation.split("const MAIN_TAB_DEFINITIONS = [", 1)[1].split("];", 1)[0]
        self.assertEqual(re.findall(r'key\s*:\s*["\']([^"\']+)', declarations), expected)
        sidebar = navigation.split("function LogistiqueSidebar(", 1)[1].split("const navigation=", 1)[0]
        groups = {label: re.findall(r'"([^"]+)"', keys)
                  for label, keys in re.findall(r'label: "([^"]+)", keys: \[([^\]]+)\]', sidebar)}
        self.assertEqual(groups["Dépôts et stocks"], expected[3:7])
        self.assertEqual(groups["Opérations de stock"], expected[7:13])
        self.assertEqual([key for keys in groups.values() for key in keys], expected)
        self.assertEqual(list(self.definition["dashboardBlockDefaults"]),
                         ["articles", "commandes", "factures", "alertes"])

    def test_historical_customization_survives_new_tabs(self):
        values = {"tabLabels": {"tiers": "COUSP et Partenaires", "articles": "Produits"},
                  "hiddenTabs": ["factures"], "hiddenDashboardBlocks": ["factures"]}
        row = {"SettingValueJson": values, "ValideSetting": True, "IsEditable": True}
        result = namespace["presentation_data"](self.definition, 7, row, can_manage=True)
        for field, expected in values.items():
            self.assertEqual(result[field], expected)
        self.assertTrue(result["canManage"])
        self.assertEqual(result["entityId"], 7)
        for key in ["depots", "stocks-depots", "transferts", "lignes-inventaires"]:
            self.assertIn(key, result["tabDefaults"])
            self.assertNotIn(key, result["hiddenTabs"])

    def test_new_tabs_can_be_named_hidden_and_restored(self):
        result = namespace["validate_values"](self.definition, {
            "tabLabels": {"depots": " Magasins ", "stocks-depots": "Disponibilités",
                          "transferts": "Mouvements internes", "lignes-inventaires": "Détail des comptages"},
            "hiddenTabs": ["transferts", "depots", "lignes-inventaires"], "hiddenDashboardBlocks": []})
        self.assertEqual(result["tabLabels"]["depots"], "Magasins")
        self.assertEqual(result["tabLabels"]["lignes-inventaires"], "Détail des comptages")
        self.assertEqual(result["hiddenTabs"], ["depots", "transferts", "lignes-inventaires"])
        result = namespace["validate_values"](self.definition, {
            "tabLabels": {}, "hiddenTabs": [], "hiddenDashboardBlocks": []})
        self.assertEqual(result, {"tabLabels": {}, "hiddenTabs": [], "hiddenDashboardBlocks": []})

    def test_legacy_payload_and_protected_configuration(self):
        result = namespace["validate_values"](self.definition, {
            "tabLabels": {"depots": "Dépôts"}, "hiddenDashboardBlocks": ["factures"]})
        self.assertEqual(result["tabLabels"], {})
        self.assertEqual(result["hiddenTabs"], [])
        row = {"SettingValueJson": result, "ValideSetting": True, "IsEditable": False}
        self.assertFalse(namespace["presentation_data"](
            self.definition, 7, row, can_manage=True)["canManage"])
        row["IsEditable"] = True
        self.assertFalse(namespace["presentation_data"](
            self.definition, 7, row, can_manage=False)["canManage"])

    def test_invalid_settings_are_rejected_or_repairable(self):
        for changes in [{"hiddenTabs": ["depots", "depots"]},
                        {"hiddenTabs": ["autre"]},
                        {"tabLabels": {"depots": "x" * 61}},
                        {"tabLabels": {"depots": "Nom\ninterdit"}},
                        {"tabLabels": {"autre": "Autre"}}]:
            with self.subTest(changes=changes), self.assertRaises(APIError):
                namespace["validate_values"](self.definition, {
                    "tabLabels": {}, "hiddenTabs": [], "hiddenDashboardBlocks": [], **changes})
        row = {"SettingValueJson": {"tabLabels": {"inconnu": "Ancien"},
                                    "hiddenDashboardBlocks": []},
               "ValideSetting": True, "IsEditable": True}
        self.assertIsNone(namespace["stored_values"](self.definition, row))
        self.assertEqual(namespace["presentation_data"](
            self.definition, 7, row)["hiddenTabs"], [])


if __name__ == "__main__":
    unittest.main()
