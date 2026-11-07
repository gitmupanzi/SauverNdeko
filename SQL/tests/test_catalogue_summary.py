"""Public landing aggregates, isolated from application databases and .env.

Run: backend/.venv/Scripts/python.exe SQL/tests/test_catalogue_summary.py
The SQL boundary is simulated; PostgreSQL source views remain authoritative.
"""
import sys
import unittest
from datetime import datetime, timezone
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'backend'))
from django.conf import settings
if not settings.configured:
    settings.configure(SECRET_KEY='catalogue-summary-memory-tests',
        INSTALLED_APPS=[], USE_TZ=True, DB_READ_ONLY=True,
        DATABASES={'default': {'ENGINE': 'django.db.backends.sqlite3', 'NAME': ':memory:'}},
        CACHES={'default': {'BACKEND': 'django.core.cache.backends.locmem.LocMemCache'}},
        REST_FRAMEWORK={'DEFAULT_AUTHENTICATION_CLASSES': [], 'UNAUTHENTICATED_USER': None})
import django
django.setup()
from django.core.cache import cache
from django.db import connection
from rest_framework.test import APIRequestFactory
from apps.catalogue import summary
from apps.catalogue.views import PublicView
from apps.core.responses import APIError


class CatalogueSummaryTests(unittest.TestCase):
    def setUp(self):
        if connection.vendor != 'sqlite' or connection.settings_dict['NAME'] != ':memory:':
            raise RuntimeError('SQLite mémoire obligatoire ; aucune base applicative autorisée.')
        cache.clear()
        self.factory = APIRequestFactory()
        self.counts = {'productsCount': 7, 'expertsCount': 4, 'structuresCount': 521}

    def get(self, path='/api/public/catalogue/synthese', **headers):
        return summary.CatalogueSummaryView.as_view()(self.factory.get(path, **headers))

    def test_anonymous_access_returns_only_publication_counts_and_timestamp(self):
        instant = datetime(2026, 11, 7, 12, 0, tzinfo=timezone.utc)
        with patch.object(summary.db, 'one', return_value={**self.counts, 'privateNote': 'never expose'}) as sql, \
             patch.object(summary.timezone, 'now', return_value=instant):
            response = self.get()
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['data'], {**self.counts, 'calculatedAt': instant.isoformat()})
        self.assertEqual(response['Cache-Control'], 'no-store')
        self.assertEqual(sql.call_count, 1)
        self.assertEqual(sql.call_args.args, (summary.COUNT_SQL,))

    def test_zero_is_an_honest_count(self):
        with patch.object(summary.db, 'one', return_value=dict.fromkeys(self.counts, 0)):
            response = self.get()
        self.assertEqual(response.status_code, 200)
        for field in self.counts:
            self.assertIs(type(response.data['data'][field]), int)
            self.assertEqual(response.data['data'][field], 0)

    def test_query_reads_only_existing_closed_publication_views(self):
        sql = summary.COUNT_SQL
        for source in ('logistique."V_OffreArticle"', 'professionnel."V_Professionnel_Public"',
                       'geolocalisation."V_StructureSanitairePublique"'):
            self.assertEqual(sql.count(source), 1)
        self.assertEqual(sql.lower().count('count(*)'), 3)
        self.assertNotIn('T_Article', sql)
        self.assertNotIn('T_Utilisateurs', sql)
        self.assertNotIn('T_Entite', sql)
        self.assertNotIn('SELECT *', sql)
        self.assertNotIn('WHERE', sql)  # no anonymous per-company population

    def test_short_cache_preserves_calculation_time(self):
        with patch.object(summary.db, 'one', return_value=self.counts) as sql:
            first = self.get().data['data']
            second = self.get().data['data']
        self.assertEqual(first, second)
        self.assertEqual(sql.call_count, 1)
        self.assertEqual(summary.CACHE_SECONDS, 60)

    def test_expired_cache_recalculates_counts(self):
        with patch.object(summary.db, 'one', return_value=self.counts) as sql:
            self.get()
            cache.delete(summary.CACHE_KEY)
            changed = {**self.counts, 'productsCount': 8}
            sql.return_value = changed
            response = self.get()
        self.assertEqual(response.data['data']['productsCount'], 8)
        self.assertEqual(sql.call_count, 2)

    def test_no_filter_can_disclose_a_targeted_population(self):
        for query in ('?companyId=2', '?q=Benjamin', '?take=1', '?IdEntite=2&IdEntite=3'):
            with self.subTest(query=query), patch.object(summary.db, 'one') as sql:
                response = self.get('/api/public/catalogue/synthese' + query)
                self.assertEqual(response.status_code, 400)
                sql.assert_not_called()

    def test_authentication_is_not_used_to_change_global_totals(self):
        with patch.object(summary.db, 'one', return_value=self.counts):
            response = self.get(HTTP_AUTHORIZATION='Bearer invalid-token', HTTP_X_ENTITE_ID='99')
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['data']['productsCount'], 7)
        self.assertEqual(summary.CatalogueSummaryView.authentication_classes, [])

    def test_writes_are_not_allowed(self):
        for method in ('post', 'patch', 'delete'):
            with self.subTest(method=method), patch.object(summary.db, 'one') as sql:
                request = getattr(self.factory, method)('/api/public/catalogue/synthese', {}, format='json')
                response = summary.CatalogueSummaryView.as_view()(request)
                self.assertEqual(response.status_code, 405)
                sql.assert_not_called()

    def test_invalid_or_missing_counts_never_become_fabricated_zero(self):
        for bad in (None, {}, {**self.counts, 'productsCount': None},
                    {**self.counts, 'productsCount': True}, {**self.counts, 'productsCount': -1},
                    {**self.counts, 'productsCount': '7'}):
            with self.subTest(bad=bad), patch.object(summary.db, 'one', return_value=bad):
                with self.assertRaises(APIError) as error:
                    summary.publication_summary()
                self.assertEqual(error.exception.status_code, 503)
                self.assertIsNone(cache.get(summary.CACHE_KEY))

    def test_failure_is_not_cached(self):
        with patch.object(summary.db, 'one', side_effect=RuntimeError('source unavailable')):
            with self.assertRaises(RuntimeError):
                summary.publication_summary()
        self.assertIsNone(cache.get(summary.CACHE_KEY))

    def test_legacy_stats_and_directories_remain_session_protected(self):
        for kind in ('stats', 'articles', 'experts', 'pharmacies'):
            with self.subTest(kind=kind), patch.object(summary.db, 'one') as sql:
                response = PublicView.as_view()(self.factory.get('/api/public/' + kind), kind=kind)
                self.assertIn(response.status_code, (401, 403))
                sql.assert_not_called()


if __name__ == '__main__':
    unittest.main()
