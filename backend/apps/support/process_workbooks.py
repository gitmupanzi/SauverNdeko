"""Paniers et classeurs des modèles de suivi, dans le périmètre Support."""

import hashlib
import json
import re
from datetime import datetime
from tempfile import SpooledTemporaryFile
from uuid import UUID, uuid5

from django.db import connection, transaction
from django.http import FileResponse
from rest_framework.views import APIView

from apps.core import db
from apps.core.category_values import category_key
from apps.core.batch_excel import ExcelPreviewMixin, build_template, read_uploaded_workbook
from apps.core.module_access import require_tab
from apps.core.permissions import HasModuleAccess
from apps.core.responses import APIError, ExactEncoder, ExactJSONRenderer, ok
from apps.core.table_preferences import export_keys
from apps.core.tabular_exports import selected_scope, write_tabular
from apps.core.tenancy import read_entity
from apps.logistique.excel import CSVFileRenderer, ExcelDownloadView, MAX_EXPORT_ROWS, XLSX_MEDIA_TYPE
from apps.logistique.table_queries import document_zone
from apps.support import processes
from apps.support.model_columns import LABELS
from apps.support.portal import _text, _write_access


MAX_MODELS = 100
MAX_EXCEL_ROWS = 500
SHEET = 'Modèles'
MODEL_COLUMNS = (
    ('name', 'Nom du modèle', None), ('typeId', 'Type de dossier', 'types'),
    ('active', 'Modèle actif', 'bool'), ('description', 'Description du modèle', None),
    ('globalMinutes', 'Délai global (minutes)', None),
    ('reminderMinutes', 'Relance (minutes)', None),
)
STAGE_COLUMNS = (
    ('stageName', 'Nom de l’étape', None), ('serviceId', 'Service', 'services'),
    ('roleId', 'Rôle', 'roles'), ('responsibleId', 'Responsable', 'users'),
    ('minutes', 'Délai de l’étape (minutes)', None),
    ('requiresReceipt', 'Réception obligatoire', 'bool'), ('allowReturn', 'Retour autorisé', 'bool'),
    ('requiresDocument', 'Justificatif obligatoire', 'bool'),
    ('requiredInformation', 'Information requise', None),
    ('validators', 'Validations', None), ('blockerReasonIds', 'Motifs de blocage', 'reasons'),
    ('returnReasonIds', 'Motifs de retour', None), ('rejectReasonIds', 'Motifs de refus', None),
)
HEADERS = {label: key for key, label, _ in (*MODEL_COLUMNS, *STAGE_COLUMNS)}
CREATION_FIELDS = processes.MODEL_FIELDS - {'revision', 'requestId'}


def require_write(actor):
    require_tab(actor, 'support', 'processus', 'manage')
    entity = _write_access(actor)
    processes.require_processes()
    return entity


def invalid_batch(errors):
    raise APIError({'errors': errors}, 'SUPPORT_MODEL_BATCH_VALIDATION', 422)


def error_message(error):
    if isinstance(error.detail, dict):
        return ' '.join(f'{field} — {message}' for field, message in error.detail.items())
    return str(error.detail)


@transaction.atomic
def create_batch(actor, body):
    entity = require_write(actor)
    if not isinstance(body, dict) or set(body) != {'requestId', 'items'}:
        invalid_batch([{'message': 'Vérifiez le format du panier.'}])
    try:
        request_id = UUID(str(body['requestId']))
    except (ValueError, TypeError):
        invalid_batch([{'message': 'L’identifiant de la demande est invalide.'}])
    items = body['items']
    if not isinstance(items, list) or not 1 <= len(items) <= MAX_MODELS:
        invalid_batch([{'message': f'Ajoutez de 1 à {MAX_MODELS} modèles.'}])
    keys, issues = set(), []
    for item in items:
        key = item.get('clientRowId') if isinstance(item, dict) else None
        if not isinstance(key, str) or not re.fullmatch(r'[A-Za-z0-9_-]{1,100}', key) or key in keys:
            invalid_batch([{'message': 'Les identifiants de ligne doivent être valides et distincts.'}])
        keys.add(key)
        if set(item) - (CREATION_FIELDS | {'clientRowId'}):
            issues.append({'clientRowId': key, 'message': 'Vérifiez les champs du modèle.'})
    if issues:
        invalid_batch(issues)
    try:
        canonical = json.dumps(items, cls=ExactEncoder, sort_keys=True, ensure_ascii=False,
                               separators=(',', ':'), allow_nan=False).encode('utf8')
    except (ValueError, TypeError, UnicodeError):
        invalid_batch([{'message': 'Le panier contient une valeur invalide.'}])
    if len(canonical) > 1024 * 1024:
        raise APIError('Le panier dépasse 1 Mo.', 'SUPPORT_MODEL_BATCH_TOO_LARGE', 413)
    digest = hashlib.sha256(canonical).hexdigest()
    # Le verrou par demande empêche deux reprises du même lot de traiter les mêmes lignes.
    db.query('SELECT pg_advisory_xact_lock(hashtextextended(%s,0))',
             [f'support-process-batch:{actor.pk}:{request_id}'])
    refs = processes.model_references(actor)
    records, replays = {}, []
    # Les lots concurrents acquièrent les verrous d’unicité dans le même ordre.
    indices = sorted(range(len(items)), key=lambda index: str(items[index].get('name') or '').strip().lower())
    for index in indices:
        item = items[index]
        key = item['clientRowId']
        payload = {field: value for field, value in item.items() if field != 'clientRowId'}
        payload['requestId'] = str(uuid5(request_id, f'support-process-model:{actor.pk}:{index}'))
        try:
            record, replayed = processes.publish_model(actor, payload, batch_digest=digest, references=refs)
        except APIError as exc:
            if exc.status_code not in {400, 409, 422} or exc.default_code == 'SUPPORT_PROCESS_IDEMPOTENCY_CONFLICT':
                raise
            issues.append({'clientRowId': key, 'message': error_message(exc)})
        else:
            records[index] = {'clientRowId': key, **record}
            replays.append(replayed)
    if issues:
        invalid_batch(issues)
    return {'items': [records[index] for index in range(len(items))], 'count': len(records),
            'requestId': str(request_id)}, all(replays)


def template_columns(refs):
    for key, label, family in (*MODEL_COLUMNS, *STAGE_COLUMNS):
        column = {'key': key, 'label': label, 'required': key in {'name', 'stageName'},
                  'width': 38 if key in {'name', 'stageName', 'description', 'requiredInformation'} else 26}
        if family == 'bool':
            column['choices'] = [{'value': value, 'label': value} for value in ('Oui', 'Non')]
        elif family:
            column['choices'] = [{'value': str(item['id']), 'label': item['label']}
                                 for item in refs[family] if not item.get('disabled')]
        yield column


def option_lookup(refs):
    result = {}
    for family, options in refs.items():
        ids, labels = set(), {}
        for item in options:
            if not item.get('disabled'):
                ids.add(str(item['id']))
                labels.setdefault(category_key(item['label']), []).append(item['id'])
        result[family] = ids, labels
    return result


def workbook_value(value, family, lookup):
    if not family or value == '':
        return value
    if family == 'bool':
        values = {'oui': True, 'true': True, '1': True, 'non': False, 'false': False, '0': False}
        key = category_key(value)
        if key in values:
            return values[key]
        raise ValueError('saisissez Oui ou Non.')
    ids, labels = lookup[family]
    if value in ids:
        return int(value)
    options = labels.get(category_key(value), [])
    if len(options) == 1:
        return options[0]
    if options:
        raise ValueError('ce libellé est ambigu. Utilisez l’identifiant.')
    raise ValueError('choisissez une valeur active de cette entreprise.')


def preview_models(matrix, numbers, refs, existing_names=()):
    lookup = option_lookup(refs)
    items, issues, first_rows = {}, [], {}
    for row_number, cells in zip(numbers[1:], matrix[1:]):
        values = {key: value.strip() for key, value in zip(matrix[0], cells)}
        name = values.get('name', '')
        if not name:
            issues.append({'row': row_number, 'message': 'Renseignez le nom du modèle.'})
            continue
        key = name.lower()
        if key not in items and len(items) == MAX_MODELS:
            issues.append({'row': row_number, 'message': f'Importez au maximum {MAX_MODELS} modèles par panier.'})
            continue
        item = items.setdefault(key, {'clientRowId': f'excel-{row_number}', 'name': name, 'stages': []})
        first_rows.setdefault(key, row_number)

        def issue(message):
            issues.append({'row': row_number, 'clientRowId': item['clientRowId'], 'message': message})

        def parse(key, label, family, raw):
            try:
                if key == 'validators':
                    selectors = {'personne': ('userId', 'users'), 'role': ('roleId', 'roles'),
                                 'rôle': ('roleId', 'roles'), 'service': ('serviceId', 'services')}
                    parsed = []
                    for entry in raw.split(','):
                        prefix, sep, value = entry.strip().partition(':')
                        if not sep or not value.strip() or prefix.casefold() not in selectors:
                            raise ValueError('utilisez Personne:ID, Rôle:ID ou Service:ID.')
                        field, source = selectors[prefix.casefold()]
                        parsed.append({field: workbook_value(value.strip(), source, lookup)})
                    return parsed
                if key in {'blockerReasonIds', 'returnReasonIds', 'rejectReasonIds'}:
                    return [workbook_value(entry.strip(), 'reasons', lookup)
                            for entry in raw.split(',') if entry.strip()]
                return workbook_value(raw, family, lookup)
            except ValueError as exc:
                issue(f'{label} — {exc}')
                if key in {'blockerReasonIds', 'returnReasonIds', 'rejectReasonIds'}:
                    return [entry.strip() for entry in raw.split(',') if entry.strip()]
                if key == 'validators':
                    return []
                return raw

        for field, label, family in MODEL_COLUMNS[1:]:
            raw = values.get(field, '')
            if raw:
                value = parse(field, label, family, raw)
                if field in item and item[field] != value:
                    issue(f'{label} diffère entre les lignes du modèle.')
                else:
                    item[field] = value
        stage = {'name': values.get('stageName', '')}
        for field, label, family in STAGE_COLUMNS[1:]:
            raw = values.get(field, '')
            if raw:
                stage[field] = parse(field, label, family, raw)
        if not stage['name']:
            issue('Renseignez le nom de l’étape.')
        item['stages'].append(stage)

    for key, item in items.items():
        try:
            _text(item['name'], 'Nom du modèle', 120, required=True)
            processes.prepare_definition(item, refs)
        except APIError as exc:
            if not any(issue.get('clientRowId') == item['clientRowId'] for issue in issues):
                issues.append({'row': first_rows[key], 'clientRowId': item['clientRowId'], 'message': error_message(exc)})
        if key in existing_names:
            issues.append({'row': first_rows[key], 'clientRowId': item['clientRowId'],
                           'message': 'Cette entreprise possède déjà un modèle portant ce nom.'})
    return {'items': list(items.values()), 'errors': issues}


class SupportModelTemplateView(ExcelDownloadView):
    permission_classes = [HasModuleAccess]

    def get(self, request):
        require_write(request.user)
        if request.query_params:
            raise APIError('Critère non autorisé.')
        stream = build_template(sheet_name=SHEET, columns=list(template_columns(processes.model_references(request.user))),
            notes=[
                ('Modèle', 'Une ligne par étape. Répétez le nom du modèle sur toutes ses lignes. Renseignez le type et les autres données du modèle au moins une fois.'),
                ('Étapes', 'Leur ordre suit celui des lignes du fichier. Chaque modèle contient de 1 à 30 étapes.'),
                ('Validations', 'Saisissez Personne:ID, Rôle:ID ou Service:ID. Séparez les validations par des virgules. Les identifiants figurent dans la feuille Options.'),
                ('Motifs', 'Séparez les identifiants ou les libellés des motifs par des virgules.'),
                ('Limite', '100 modèles et 500 étapes par fichier.'),
            ], max_rows=MAX_EXCEL_ROWS)
        response = FileResponse(stream, as_attachment=True, filename='SauverNdeko_Modele_Suivi.xlsx',
                                content_type=XLSX_MEDIA_TYPE)
        response['Cache-Control'] = 'no-store, private'
        return response


class SupportModelExcelPreviewView(ExcelPreviewMixin, APIView):
    permission_classes = [HasModuleAccess]
    http_method_names = ['post', 'options']

    def post(self, request):
        entity = require_write(request.user)
        matrix, numbers = read_uploaded_workbook(request, file_field='file', sheet_name=SHEET, headers=HEADERS,
            required_headers=('name', 'typeId', 'stageName'), max_rows=MAX_EXCEL_ROWS,
            max_cell_length=4000, with_row_numbers=True)
        refs = processes.model_references(request.user)
        existing = db.query('SELECT lower(btrim("Nom")) AS name FROM support."T_ModeleProcessus" WHERE "IdEntiteFk"=%s', [entity])
        return ok(preview_models(matrix, numbers, refs, {row['name'] for row in existing}))


class SupportModelBatchView(APIView):
    permission_classes = [HasModuleAccess]
    http_method_names = ['post', 'options']

    def post(self, request):
        result, replayed = create_batch(request.user, request.data)
        return ok(result, status=200 if replayed else 201, meta={'replayed': replayed})


def workbook(actor, raw, file_format):
    processes.manage_models(actor)
    require_tab(actor, 'support', 'processus', 'export')
    processes.require_processes()
    source, params, order, sort, direction = processes.model_selection(
        actor, raw, extras={'columns', 'selection', 'timeZone'},
    )
    columns = export_keys(actor, 'support.modeles', raw)
    selection, selected_params = selected_scope(raw, 'id')
    types = {'version': 'integer', 'stageCount': 'integer', 'active': 'boolean'}
    fields = [{'column_name': key, 'label': LABELS[key], 'data_type': types.get(key, 'text')}
              for key in columns]
    zone = document_zone(raw)
    generated = datetime.now(zone)
    entity = read_entity(actor)
    context = {'title': 'Modèles de suivi', 'scope': f'Entreprise {entity}' if entity else 'Toutes les entreprises autorisées',
               'generated': generated.strftime('%d/%m/%Y %H:%M'), 'zone': str(zone), 'tz': zone,
               'source': 'support.T_ModeleProcessus', 'raw': raw,
               'filters': {label: raw[key] for key, label in {'typeId': 'Identifiant du type', 'entityId': 'Identifiant de l’entreprise',
                                                               'active': 'Actif'}.items() if raw.get(key)},
               'order': f'{LABELS[sort]} {direction}'}
    selected_columns = ','.join('v.' + db.ident(key) for key in columns)
    stream = SpooledTemporaryFile(max_size=8 * 1024 * 1024, mode='w+b')
    try:
        with connection.cursor() as cursor:
            cursor.execute(f'SELECT {selected_columns} FROM ({source}) v WHERE TRUE{selection} ORDER BY {order} LIMIT %s',
                           [*params, *selected_params, MAX_EXPORT_ROWS + 1])

            def rows():
                while batch := cursor.fetchmany(500):
                    yield from (dict(zip(columns, row)) for row in batch)

            count = write_tabular(stream, fields, rows(), context, file_format)
        stream.seek(0)
        return stream, count, f'SauverNdeko_Modeles_de_suivi_{generated:%Y-%m-%d}.{file_format}'
    except Exception:
        stream.close()
        raise


class SupportModelExcelView(ExcelDownloadView):
    permission_classes = [HasModuleAccess]
    file_format = 'xlsx'
    media_type = XLSX_MEDIA_TYPE

    def get(self, request):
        stream, count, name = workbook(request.user, request.query_params.dict(), self.file_format)
        response = FileResponse(stream, as_attachment=True, filename=name, content_type=self.media_type)
        response['X-Export-Row-Count'] = str(count)
        response['Cache-Control'] = 'no-store, private'
        return response


class SupportModelCSVView(SupportModelExcelView):
    renderer_classes = [ExactJSONRenderer, CSVFileRenderer]
    file_format = 'csv'
    media_type = 'text/csv; charset=utf-8'
