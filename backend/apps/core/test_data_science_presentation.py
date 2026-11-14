from types import SimpleNamespace
from unittest.mock import patch

from django.test import SimpleTestCase, override_settings
from django.urls import resolve
from rest_framework.test import APIRequestFactory, force_authenticate

from apps.core import module_presentation as presentation


MODULE = "data-science"
CATALOGUE = "/api/parametres/presentation"
MODULE_VIEW = "/api/data-science/presentation"
SETTINGS_VIEW = "/api/parametres/data-science/presentation"


def actor(*, platform=False, licensed=True, tabs=("tableau-de-bord", "demandes")):
    settings_rights = {"canRead": True, "canManage": True}
    module_rights = {"canRead": licensed or platform, "reason": "MODULE_NOT_INCLUDED"}
    return SimpleNamespace(
        is_authenticated=True,
        admin=True,
        global_admin=platform,
        organisation=7,
        _context_entity=7,
        _module_access={
            "modules": {"parametres": settings_rights, MODULE: module_rights},
            "tabs": {
                MODULE: {
                    tab: {"canRead": tab in tabs}
                    for tab in ("tableau-de-bord", "demandes", "recherches", "perimetre")
                },
            },
        },
    )


class DataSciencePresentationTests(SimpleTestCase):
    def request(self, path, user, *, body=None):
        factory = APIRequestFactory()
        request = factory.get(path) if body is None else factory.put(path, body, format="json")
        force_authenticate(request, user)
        route = resolve(path)
        return route.func(request, **route.kwargs)

    @patch.object(presentation.db, "query")
    def test_catalogue_requires_licence_and_readable_tab(self, query):
        licensed = {"entityId": 7, "modules": [{"key": MODULE, "label": "Data Science"}]}
        empty = {"entityId": 7, "modules": []}
        self.assertEqual(self.request(CATALOGUE, actor()).data["data"], licensed)
        self.assertEqual(self.request(CATALOGUE, actor(licensed=False)).data["data"], empty)
        self.assertEqual(self.request(CATALOGUE, actor(tabs=("recherches",))).data["data"], empty)
        query.assert_not_called()
        platform = actor(platform=True, tabs=("recherches",))
        query.return_value = []
        self.assertEqual(self.request(CATALOGUE, platform).data["data"], empty)
        query.return_value = [{"CodeModule": MODULE}]
        self.assertEqual(self.request(CATALOGUE, platform).data["data"], licensed)
        self.assertEqual(query.call_args.args[1], [7, [MODULE]])

    @override_settings(DB_READ_ONLY=False)
    @patch.object(presentation.db, "one", return_value={"ValideEntite": True})
    @patch.object(presentation, "setting_row")
    def test_module_and_settings_disclose_only_readable_tabs(self, row, one):
        row.return_value = {
            "SettingValueJson": {
                "tabLabels": {"demandes": "Besoins", "recherches": "Analyse interne"},
                "hiddenTabs": ["perimetre"],
                "hiddenDashboardBlocks": ["evolution"],
            },
            "ValideSetting": True,
            "IsEditable": True,
            "revision": "x",
        }
        self.assertEqual(self.request(SETTINGS_VIEW, actor(licensed=False)).status_code, 403)
        self.assertEqual(self.request(MODULE_VIEW, actor(tabs=())).status_code, 403)
        for path in (MODULE_VIEW, SETTINGS_VIEW):
            with self.subTest(path=path):
                result = self.request(path, actor(tabs=("tableau-de-bord", "demandes", "recherches", "perimetre")))
                self.assertEqual(result.status_code, 200)
                data = result.data["data"]
                self.assertEqual(set(data["tabDefaults"]), {"tableau-de-bord", "demandes"})
                self.assertEqual(data["tabLabels"], {"demandes": "Besoins"})
                self.assertEqual(data["hiddenTabs"], [])
                self.assertEqual(data["hiddenDashboardBlocks"], ["evolution"])
                self.assertNotIn("recherches", data["dashboardBlockDefaults"])
                self.assertTrue(data["canManage"])

    @patch.object(presentation.db, "ensure_writable")
    @patch.object(presentation, "save_presentation", presentation.save_presentation.__wrapped__)
    def test_company_cannot_write_platform_tabs_or_blocks(self, writable):
        empty = {"tabLabels": {}, "hiddenTabs": [], "hiddenDashboardBlocks": [], "entityId": 7, "revision": None}
        invalid = (
            {"tabLabels": {"recherches": "Interne"}},
            {"hiddenTabs": ["perimetre"]},
            {"hiddenDashboardBlocks": ["recherches"]},
        )
        for change in invalid:
            with self.subTest(change=change):
                self.assertEqual(self.request(SETTINGS_VIEW, actor(), body={**empty, **change}).status_code, 422)

    @override_settings(DB_READ_ONLY=False)
    @patch.object(presentation.db, "ensure_writable")
    @patch.object(presentation.db, "one", return_value={"ValideEntite": True})
    @patch.object(presentation.db, "query")
    @patch.object(presentation, "set_admin_actor")
    @patch.object(presentation, "setting_row")
    @patch.object(presentation, "save_presentation", presentation.save_presentation.__wrapped__)
    def test_company_save_preserves_existing_platform_tab_values(self, row, set_actor, query, one, writable):
        old = {
            "IdAdminUISetting": 7,
            "SettingValueJson": {
                "tabLabels": {"demandes": "Suivi", "recherches": "Interne"},
                "hiddenTabs": ["perimetre"],
                "hiddenDashboardBlocks": ["evolution"],
            },
            "ValideSetting": True,
            "IsEditable": True,
            "revision": "x",
        }
        updated = {
            "tabLabels": {"demandes": "Besoins", "recherches": "Interne"},
            "hiddenTabs": ["perimetre"],
            "hiddenDashboardBlocks": ["evolution"],
        }
        row.side_effect = [old, {**old, "SettingValueJson": updated, "revision": "y"}]
        result = self.request(SETTINGS_VIEW, actor(tabs=("demandes",)), body={
            "entityId": 7, "revision": presentation.revision_for(old), "tabLabels": {"demandes": "Besoins"},
            "hiddenTabs": [], "hiddenDashboardBlocks": [],
        })
        self.assertEqual(result.status_code, 200)
        saved_values = query.call_args.args[1][0].obj
        self.assertCountEqual(saved_values["hiddenDashboardBlocks"], updated["hiddenDashboardBlocks"])
        self.assertEqual(saved_values["tabLabels"], updated["tabLabels"])
        self.assertEqual(saved_values["hiddenTabs"], updated["hiddenTabs"])
        self.assertEqual(result.data["data"]["hiddenDashboardBlocks"], [])
