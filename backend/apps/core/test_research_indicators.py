from datetime import date
from types import SimpleNamespace
from unittest.mock import patch

from django.http import QueryDict
from django.test import SimpleTestCase
from django.urls import resolve
from rest_framework.test import APIRequestFactory, force_authenticate

from apps.core import research_indicators as research
from apps.core.responses import APIError
from apps.core.tenancy import bind_context


class ResearchIndicatorsTests(SimpleTestCase):
    @patch.object(research.timezone, "localdate", return_value=date(2026, 11, 14))
    def test_months_are_inclusive_and_use_kinshasa(self, localdate):
        self.assertEqual(research.period(QueryDict()), (date(2025, 12, 1), date(2026, 11, 1)))
        self.assertEqual(research.period(QueryDict("debut=2026-06&fin=2026-11")),
                         (date(2026, 6, 1), date(2026, 11, 1)))
        localdate.assert_called_with(timezone=research.RESEARCH_TIMEZONE)

    @patch.object(research.timezone, "localdate", return_value=date(2026, 11, 14))
    def test_invalid_or_overlapping_filter_shapes_are_rejected(self, localdate):
        for params in (
            "debut=2026-01", "debut=2026-1&fin=2026-11", "debut=2026-12&fin=2026-12",
            "debut=2025-10&fin=2026-10", "debut=2026-07&fin=2026-06",
            "debut=2026-07&debut=2026-08&fin=2026-10", "entite=7",
        ):
            with self.subTest(params=params), self.assertRaises(APIError):
                research.period(QueryDict(params))

    @patch.object(research, "require_tab")
    @patch.object(research, "demand_indicators", return_value={"cellules": []})
    def test_report_requires_authentication_and_tab_access(self, indicators, require_tab):
        path = "/api/data-science/indicateurs/demandes"
        view = resolve(path).func
        factory = APIRequestFactory()
        self.assertIn(view(factory.get(path)).status_code, (401, 403))
        tenant = SimpleNamespace(is_authenticated=True, global_admin=False, organisation=7)
        request = factory.get(path, {"vue": "recherches"})
        force_authenticate(request, tenant)
        self.assertEqual(view(request).status_code, 403)
        require_tab.assert_not_called()
        request = factory.get(path, {"vue": "tableau-de-bord"})
        force_authenticate(request, tenant)
        require_tab.side_effect = APIError("Licence requise.", "MODULE_NOT_INCLUDED", 403)
        self.assertEqual(view(request).status_code, 403)
        require_tab.assert_called_once_with(tenant, "data-science", "tableau-de-bord")
        indicators.assert_not_called()

    @patch.object(research, "require_tab")
    @patch.object(research, "demand_indicators", return_value={"cellules": []})
    def test_report_uses_only_bound_company_context(self, indicators, require_tab):
        path = "/api/data-science/indicateurs/demandes"
        view = resolve(path).func
        tenant = SimpleNamespace(is_authenticated=True, global_admin=False, organisation=7, row={"IdEntiteFk": 7})
        admin = SimpleNamespace(is_authenticated=True, global_admin=True, organisation=None)
        selected_admin = SimpleNamespace(is_authenticated=True, global_admin=True, organisation=8, _context_entity=8)

        for actor, company in ((tenant, 7), (admin, None), (selected_admin, 8)):
            with self.subTest(company=company):
                request = APIRequestFactory().get(path, {"debut": "2026-01", "fin": "2026-01"})
                force_authenticate(request, actor)
                response = view(request)
                self.assertEqual(response.status_code, 200)
                self.assertEqual(response["Cache-Control"], "private, no-store")
                self.assertEqual(response.data["data"]["cellules"], [])
                require_tab.assert_called_with(actor, "data-science", "demandes")
                indicators.assert_called_with(date(2026, 1, 1), date(2026, 1, 1),
                                              entity=company, report_tab="demandes", include_research=False)

        invalid = APIRequestFactory().get(path, HTTP_X_ENTITE_ID="8")
        with self.assertRaises(APIError) as error:
            bind_context(tenant, SimpleNamespace(headers=invalid.headers))
        self.assertEqual(error.exception.status_code, 403)
        request = APIRequestFactory().get(path, {"entite": "8"})
        force_authenticate(request, tenant)
        self.assertEqual(view(request).status_code, 400)

    @patch.object(research, "require_tab")
    @patch.object(research, "can_use_tab", return_value=True)
    @patch.object(research, "demand_indicators", return_value={"cellules": []})
    def test_dashboard_research_needs_platform_scope_and_research_tab(self, indicators, can_use_tab, require_tab):
        path = "/api/data-science/indicateurs/demandes"
        for global_admin, entity, has_tab, include_research in (
            (False, 7, True, False),
            (True, None, False, False),
            (True, None, True, True),
            (True, 7, True, False),
        ):
            with self.subTest(global_admin=global_admin, entity=entity, has_tab=has_tab):
                can_use_tab.return_value = has_tab
                actor = SimpleNamespace(is_authenticated=True, global_admin=global_admin, organisation=entity)
                if global_admin and entity is not None:
                    actor._context_entity = entity
                request = APIRequestFactory().get(path, {"vue": "tableau-de-bord"})
                force_authenticate(request, actor)
                self.assertEqual(resolve(path).func(request).status_code, 200)
                self.assertEqual(indicators.call_args.kwargs["include_research"], include_research)

    def test_research_participation_settings_are_platform_only(self):
        path = "/api/data-science/perimetre"
        request = APIRequestFactory().get(path)
        force_authenticate(request, SimpleNamespace(is_authenticated=True, global_admin=False))
        self.assertEqual(resolve(path).func(request).status_code, 403)

    @patch.object(research.db, "query")
    @patch.object(research.db, "one", return_value={"demandes": False, "offres": False})
    def test_missing_observations_are_not_presented_as_a_measured_zero(self, sources, query):
        data = research.demand_indicators(date(2026, 1, 1), date(2026, 1, 1))
        self.assertEqual(data["statutCollecte"], "indisponible")
        self.assertEqual(data["cellules"], [])
        self.assertFalse(data["rapprochementDisponible"])
        query.assert_not_called()

    @patch.object(research.db, "query")
    @patch.object(research.db, "one", return_value={"demandes": True, "offres": False})
    def test_nulls_and_closed_response_projection(self, sources, query):
        row = dict.fromkeys(research.CELL_FIELDS)
        row.update({"mois": "2026-01", "source": "product", "nature": "recherche",
                    "recherches": 10, "IdAuteurFk": 123, "TexteRecherche": "non diffusable"})
        query.return_value = [row]
        start, end = date(2026, 1, 1), date(2026, 2, 1)
        data = research.demand_indicators(start, end, report_tab="recherches")
        self.assertEqual(query.call_args.args[1], [start, end, 5, None, ["recherche"], 5001])
        self.assertNotIn('FROM analytics."V_ObservationStockRecherche"', query.call_args.args[0])
        self.assertEqual(data["periode"], {"debut": "2026-01", "fin": "2026-02"})
        self.assertEqual(data["statutCollecte"], "disponible")
        self.assertEqual(set(data["cellules"][0]), set(research.CELL_FIELDS) | {"offrePubliee"})
        self.assertIsNone(data["cellules"][0]["offrePubliee"])
        self.assertIsNone(data["cellules"][0]["sansResultat"])
        self.assertFalse(data["associationMaladieProduitDisponible"])

    @patch.object(research.db, "query")
    @patch.object(research.db, "one", return_value={"demandes": True, "offres": True})
    def test_published_offers_are_matched_on_a_known_category_in_the_same_company(self, sources, query):
        rows = [dict.fromkeys(research.CELL_FIELDS) | {"produitId": category} for category in (8, 9, None)]
        query.side_effect = [rows, [{"id": 8}]]
        start = date(2026, 1, 1)
        data = research.demand_indicators(start, start, entity=7)
        self.assertEqual(data["perimetre"], {"type": "entreprise", "entrepriseId": 7})
        self.assertEqual([row["offrePubliee"] for row in data["cellules"]], [True, False, None])
        self.assertEqual(query.call_args.args[1], [[8, 9], 7, 7])

    @patch.object(research.db, "query", return_value=[{}] * (research.MAX_CELLS + 1))
    @patch.object(research.db, "one", return_value={"demandes": True, "offres": False})
    def test_display_limit_does_not_silently_truncate(self, sources, query):
        with self.assertRaises(APIError) as error:
            research.demand_indicators(date(2026, 1, 1), date(2026, 1, 1))
        self.assertEqual(error.exception.default_code, "RESEARCH_PERIOD_TOO_LARGE")
