from types import SimpleNamespace
from unittest.mock import patch

from django.test import SimpleTestCase
from django.urls import resolve

from apps.core.responses import APIError
from apps.logistique.article_publication import ArticlePublicationView, set_article_publication


def article(key, published=False, active=True):
    return {"ID_Article": key, "VisibleCatalogue": published, "ValideArticle": active}


class ArticlePublicationTests(SimpleTestCase):
    def setUp(self):
        self.actor = SimpleNamespace(pk=5)
        self.operation = set_article_publication.__wrapped__
        self.module = self.start_patch("require_module")
        self.tab = self.start_patch("require_tabs")
        self.entity = self.start_patch("require_entity", return_value=21)
        self.writable = self.start_patch("db.ensure_writable")
        self.sql = self.start_patch("db.query")
        self.audit = self.start_patch("audit")

    def start_patch(self, name, **options):
        replacement = patch("apps.logistique.article_publication." + name, **options)
        self.addCleanup(replacement.stop)
        return replacement.start()

    def test_route_and_authorization(self):
        self.assertIs(resolve("/api/logistique/articles/publication").func.cls, ArticlePublicationView)
        self.tab.side_effect = APIError("Accès refusé.", "FORBIDDEN", 403)
        with self.assertRaises(APIError):
            self.operation(self.actor, {"ids": [1], "visible": True})
        self.module.assert_called_once_with(self.actor, "logistique", "manage")
        self.tab.assert_called_once_with(self.actor, "articles", action="manage")
        self.sql.assert_not_called()

    def test_requires_writable_active_company(self):
        for gate in (self.writable, self.entity):
            gate.side_effect = APIError("Écriture bloquée.", "FORBIDDEN", 403)
            with self.subTest(gate=gate), self.assertRaises(APIError):
                self.operation(self.actor, {"ids": [1], "visible": True})
            gate.side_effect = None
        self.sql.assert_not_called()
        self.audit.assert_not_called()

    def test_rejects_invalid_ids_and_visibility(self):
        for ids, visible in (([], False), ([1, 1], True), ([True], True), ([0], False), ([1], "false")):
            with self.subTest(ids=ids, visible=visible), self.assertRaises(APIError) as rejected:
                self.operation(self.actor, {"ids": ids, "visible": visible})
            self.assertEqual(rejected.exception.status_code, 400)
        self.sql.assert_not_called()

    def test_other_company_or_missing_id_refuses_whole_selection(self):
        self.sql.return_value = [article(1)]
        with self.assertRaises(APIError) as rejected:
            self.operation(self.actor, {"ids": [1, 2], "visible": True})
        self.assertEqual(rejected.exception.status_code, 404)
        self.sql.assert_called_once()
        statement, params = self.sql.call_args.args
        self.assertIn('"IdEntiteFk"=%s', statement)
        self.assertIn('ORDER BY "ID_Article" FOR UPDATE', statement)
        self.assertEqual(params, [21, [1, 2]])
        self.audit.assert_not_called()

    def test_inactive_item_blocks_publication_but_can_be_removed(self):
        self.sql.return_value = [article(1, published=True, active=False)]
        with self.assertRaises(APIError) as rejected:
            self.operation(self.actor, {"ids": [1], "visible": True})
        self.assertEqual(rejected.exception.status_code, 409)
        self.sql.assert_called_once()
        self.audit.assert_not_called()

        self.sql.reset_mock()
        self.assertEqual(self.operation(self.actor, {"ids": [1], "visible": False}), {"changed": 1, "unchanged": 0})
        self.assertEqual(self.sql.call_args.args[1], [False, 21, [1]])

    def test_updates_only_changed_items_and_audits_once(self):
        self.sql.return_value = [article(1, published=True), article(2)]
        self.assertEqual(self.operation(self.actor, {"ids": [1, 2], "visible": True}), {"changed": 1, "unchanged": 1})
        self.assertEqual(self.sql.call_count, 2)
        self.assertEqual(self.sql.call_args.args[1], [True, 21, [2]])
        self.audit.assert_called_once()
        self.assertEqual(self.audit.call_args.kwargs["entity_id"], 21)
        self.assertEqual(self.audit.call_args.kwargs["new"], {"ids": [2], "VisibleCatalogue": True})

        self.audit.reset_mock()
        self.sql.reset_mock()
        self.sql.return_value = [article(1, published=True), article(2, published=True)]
        self.assertEqual(self.operation(self.actor, {"ids": [1, 2], "visible": True}), {"changed": 0, "unchanged": 2})
        self.sql.assert_called_once()
        self.audit.assert_not_called()
