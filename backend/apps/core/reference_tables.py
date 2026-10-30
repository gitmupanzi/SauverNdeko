"""Catalogue des tableaux et préférences du seul compte connecté.

Les définitions communes sont consultables. Leur personnalisation réutilise
TablePreferencesView, avec ses révisions et son propriétaire vérifiés.
"""
import json
from datetime import datetime
from tempfile import SpooledTemporaryFile

from django.http import FileResponse
from rest_framework.permissions import IsAuthenticated
from rest_framework.views import APIView

from . import db
from .module_access import require_module
from .repository import clean, page
from .responses import APIError, ok, ExactJSONRenderer
from .tenancy import read_entity
from .tabular_exports import write_tabular
from apps.logistique.excel import ExcelDownloadView, CSVFileRenderer, XLSX_MEDIA_TYPE
from apps.logistique.table_queries import document_zone

LABELS = {'CleInterface': 'Interface', 'Libelle': 'Tableau', 'Module': 'Module',
          'Version': 'Version du catalogue', 'Actif': 'Actif', 'NbColonnes': 'Colonnes disponibles',
          'PreferenceTableau': 'Tableau personnalisé', 'PreferenceExport': 'Export personnalisé',
          'ModifieLe': 'Catalogue modifié le'}
TYPES = {'Version': 'integer', 'NbColonnes': 'integer', 'Actif': 'boolean',
         'PreferenceTableau': 'boolean', 'PreferenceExport': 'boolean', 'ModifieLe': 'timestamp with time zone'}


def table_source():
    # Projection d'API fermée : ne prétend pas ajouter les préférences d'un
    # utilisateur aux colonnes physiques du catalogue partagé.
    return {'schema': 'referentiel', 'name': 'V_InterfaceTableau', 'primaryKey': ['CleInterface'],
            'columns': [{'column_name': key, 'data_type': TYPES.get(key, 'text')}
                        for key in LABELS], 'relations': []}


def accessible_rows(actor):
    from .table_preferences import source_definition
    require_module(actor, 'referentiels')
    rows = db.query('SELECT * FROM referentiel."V_InterfaceTableau" ORDER BY "CleInterface"')
    preferences = db.query('SELECT "CleInterfaceFk","Usage" FROM referentiel."T_PreferenceTableau" '
        'WHERE "IdUserFk"=%s AND "IdEntiteFk" IS NOT DISTINCT FROM %s', [actor.pk, read_entity(actor)])
    own = {(row['CleInterfaceFk'], row['Usage']) for row in preferences}
    result = []
    for row in rows:
        try:
            source_definition(actor, row['CleInterface'])
        except APIError as error:
            if error.status_code in (403, 404):
                continue
            raise
        result.append({**row, 'PreferenceTableau': (row['CleInterface'], 'table') in own,
                       'PreferenceExport': (row['CleInterface'], 'export') in own})
    return result


def selection(actor, raw, *, exporting=False):
    allowed = {'q', 'filters', 'take', 'skip', 'sortBy', 'sortDir'} | ({'columns', 'timeZone'} if exporting else set())
    if set(raw) - allowed:
        raise APIError('Critère non autorisé.')
    query = raw.get('q', '')
    if not isinstance(query, str) or len(query) > 300:
        raise APIError('Recherche trop longue.')
    try:
        filters = raw.get('filters', {})
        filters = json.loads(filters) if isinstance(filters, str) else filters
    except (TypeError, ValueError):
        raise APIError('Filtres invalides.')
    if not isinstance(filters, dict) or set(filters) - {'Module', 'Actif', 'PreferenceTableau', 'PreferenceExport'}:
        raise APIError('Filtre non autorisé.')
    for key, value in filters.items():
        if key == 'Module':
            if value not in {'logistique', 'referentiels', 'administration'}:
                raise APIError('Module de tableau invalide.')
        elif type(value) is not bool:
            raise APIError('Filtre oui/non invalide.')
    sort, direction = raw.get('sortBy', 'Libelle'), raw.get('sortDir', 'asc')
    if sort not in LABELS or direction not in ('asc', 'desc'):
        raise APIError('Tri non autorisé.')
    rows = accessible_rows(actor)
    total = len(rows)
    query = query.strip().casefold()
    rows = [row for row in rows if all(row.get(key) == value for key, value in filters.items())
            and (not query or any(query in str(row.get(key) or '').casefold()
                                  for key in ('CleInterface', 'Libelle', 'Module')))]
    def order(row):
        value = row.get(sort)
        if isinstance(value, datetime):
            value = value.isoformat()
        if isinstance(value, str):
            value = value.casefold()
        return value is None, value if value is not None else '', row['CleInterface']
    rows.sort(key=order, reverse=direction == 'desc')
    return rows, total, sort, direction


class ReferenceTablesView(APIView):
    permission_classes = [IsAuthenticated]
    http_method_names = ['get', 'options']

    def get(self, request, interface_key=None):
        if interface_key is not None:
            if request.query_params:
                raise APIError('Critère non autorisé.')
            row = next((row for row in accessible_rows(request.user) if row['CleInterface'] == interface_key), None)
            if row is None:
                raise APIError('Tableau introuvable dans vos accès.', 'NOT_FOUND', 404)
            return ok(clean(row))
        rows, total, sort, direction = selection(request.user, request.query_params.dict())
        take, skip = page(request.query_params)
        return ok(clean([{key: row[key] for key in LABELS} for row in rows[skip:skip+take]]),
                  meta={'totalCount': total, 'filteredCount': len(rows), 'take': take, 'skip': skip,
                        'sortBy': sort, 'sortDir': direction, 'entityId': read_entity(request.user)})


class ReferenceTablesExcelView(ExcelDownloadView):
    permission_classes = [IsAuthenticated]
    file_format = 'xlsx'

    def get(self, request):
        from .table_preferences import export_keys
        require_module(request.user, 'referentiels', 'export')
        raw = request.query_params.dict()
        keys = export_keys(request.user, 'referentiels.tableaux', raw)
        rows, _, sort, direction = selection(request.user, raw, exporting=True)
        zone = document_zone(raw)
        generated = datetime.now(zone)
        fields = [{**column, 'label': LABELS[column['column_name']]}
                  for key in keys for column in table_source()['columns'] if column['column_name'] == key]
        stream = SpooledTemporaryFile(max_size=1024*1024, mode='w+b')
        try:
            count = write_tabular(stream, fields, rows,
                {'title': 'Tableaux et exports', 'scope': 'Préférences personnelles du compte connecté',
                 'generated': generated.strftime('%d/%m/%Y %H:%M'), 'zone': str(zone), 'tz': zone,
                 'source': 'referentiel.V_InterfaceTableau', 'raw': raw, 'filters': {},
                 'order': LABELS[sort]+' '+direction.upper()}, self.file_format)
            stream.seek(0)
        except Exception:
            stream.close()
            raise
        response = FileResponse(stream, as_attachment=True,
            filename='SauverNdeko_Tableaux_'+generated.strftime('%Y-%m-%d')+'.'+self.file_format,
            content_type=XLSX_MEDIA_TYPE if self.file_format == 'xlsx' else 'text/csv; charset=utf-8')
        response['X-Export-Row-Count'] = str(count)
        response['Cache-Control'] = 'no-store, private'
        return response


class ReferenceTablesCSVView(ReferenceTablesExcelView):
    file_format = 'csv'
    renderer_classes = [ExactJSONRenderer, CSVFileRenderer]
