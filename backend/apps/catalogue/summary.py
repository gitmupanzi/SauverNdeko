"""Three non-identifying publication totals for the public landing page.

This endpoint deliberately does not expose directory records. Those APIs keep
their session, licence and module checks. The source views already exclude
unpublished/private records; no ERP table or user-specific scope is consulted.
"""
from django.core.cache import cache
from django.utils import timezone
from rest_framework.permissions import AllowAny
from rest_framework.views import APIView

from apps.core import db
from apps.core.responses import APIError, ok


CACHE_KEY = 'catalogue:publication-summary:v1'
CACHE_SECONDS = 60
COUNT_SQL = '''SELECT
    (SELECT count(*) FROM logistique."V_OffreArticle") AS "productsCount",
    (SELECT count(*) FROM professionnel."V_Professionnel_Public") AS "expertsCount",
    (SELECT count(*) FROM geolocalisation."V_StructureSanitairePublique") AS "structuresCount"'''


def publication_summary():
    cached = cache.get(CACHE_KEY)
    if cached is not None:
        return cached
    # One statement supplies one consistent PostgreSQL snapshot across all
    # three publications. Count profiles/offers, not unique people/products.
    row = db.one(COUNT_SQL)
    counts = {}
    for field in ('productsCount', 'expertsCount', 'structuresCount'):
        count = row.get(field) if row else None
        if isinstance(count, bool) or not isinstance(count, int) or count < 0:
            raise APIError('Les indicateurs sont momentanément indisponibles.',
                           'CATALOGUE_SUMMARY_UNAVAILABLE', 503)
        counts[field] = count
    # Closed projection: even an accidental additional query column cannot
    # disclose a record, contact, quantity, cost or company identifier.
    result = {**counts, 'calculatedAt': timezone.now().isoformat()}
    cache.set(CACHE_KEY, result, CACHE_SECONDS)
    return result


class CatalogueSummaryView(APIView):
    authentication_classes = []
    permission_classes = [AllowAny]
    http_method_names = ['get', 'head', 'options']

    def get(self, request):
        # No search, company selector or identifier can turn a global total
        # into an anonymous inference endpoint for a particular organisation.
        if request.query_params:
            raise APIError('Cette synthèse ne prend pas de filtre.',
                           'CATALOGUE_SUMMARY_QUERY_INVALID', 400)
        response = ok(publication_summary())
        response['Cache-Control'] = 'no-store'
        return response
