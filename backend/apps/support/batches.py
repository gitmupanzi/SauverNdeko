"""Modèle, lecture Excel sans écriture et création atomique de dossiers Support."""
import hashlib
import json
import re
import uuid

from django.db import transaction
from django.http import FileResponse
from rest_framework.views import APIView

from apps.core.batch_excel import ExcelPreviewMixin, build_template, read_uploaded_workbook
from apps.core.permissions import HasModuleAccess
from apps.core.responses import APIError, ExactEncoder, ok
from apps.logistique.excel import ExcelDownloadView, XLSX_MEDIA_TYPE
from . import portal

MAX_ROWS = 100
SHEET = 'Tickets'
FIELDS = [
    ('Objet', 'Objet', None), ('Description', 'Description', None),
    ('ID_DemandeurFk', 'Demandeur', 'requesters'),
    ('ID_ResponsableFk', 'Responsable', 'users'),
    ('ID_TypeSupportFk', 'Type', 'types'),
    ('ID_CategorieSupportFk', 'Catégorie', 'categories'),
    ('ID_PrioriteFk', 'Priorité', 'priorities'),
    ('ID_CanalOrigineFk', 'Canal d’origine', 'channels'),
    ('ID_ServiceConcerneFk', 'Service concerné', 'services'),
    ('DateEcheance', 'Échéance', None),
    ('ID_ArticleFk', 'Article lié', 'articles'),
    ('ID_CommandeFk', 'Bon de stock lié', 'bons'),
    ('ID_ImmobilisationFk', 'Immobilisation liée', 'immobilisations'),
]
HEADERS = {alias: key for key, label, _ in FIELDS for alias in (key, label)}


def invalid(rows=None, header=None):
    raise APIError({'rows': rows or {}, 'header': header or {}}, 'SUPPORT_BATCH_VALIDATION', 422)


@transaction.atomic
def create_batch(actor, body):
    portal._write_access(actor)
    if not isinstance(body, dict) or set(body) != {'requestId', 'rows'}:
        invalid(header={'rows': 'Vérifiez le format du panier.'})
    try:
        request_id = uuid.UUID(str(body.get('requestId')))
    except (AttributeError, TypeError, ValueError):
        invalid(header={'requestId': 'Identifiant de demande invalide.'})
    rows = body.get('rows')
    if not isinstance(rows, list) or not 1 <= len(rows) <= MAX_ROWS:
        invalid(header={'rows': 'Ajoutez de 1 à 100 lignes.'})
    seen = set()
    for row in rows:
        if not isinstance(row, dict) or set(row) != {'clientRowId', 'data'}:
            invalid(header={'rows': 'Chaque ligne attend son identifiant et ses informations.'})
        row_id = row['clientRowId']
        if not isinstance(row_id, str) or not re.fullmatch(r'[A-Za-z0-9_-]{1,100}', row_id) or row_id in seen:
            invalid(header={'rows': 'Les identifiants de ligne doivent être distincts.'})
        seen.add(row_id)
        if not isinstance(row['data'], dict) or set(row['data']) - portal.EDIT_FIELDS:
            invalid({row_id: {'_line': 'Vérifiez les champs du dossier.'}})
    try:
        canonical = json.dumps(body, cls=ExactEncoder, sort_keys=True, ensure_ascii=False,
                               separators=(',', ':'), allow_nan=False).encode('utf8')
    except (TypeError, ValueError, UnicodeError):
        invalid(header={'rows': 'Le panier contient une valeur invalide.'})
    if len(canonical) > 1024 * 1024:
        raise APIError('Le panier dépasse 1 Mo.', 'SUPPORT_BATCH_TOO_LARGE', 413)
    digest = hashlib.sha256(canonical).hexdigest()
    records, issues, replays = [], {}, []
    for index, row in enumerate(rows):
        body = {**row['data'], 'requestId': str(uuid.uuid5(request_id, f'support:{actor.pk}:{index}'))}
        try:
            # Chaque dossier passe par le service individuel : droits, relations,
            # circuit, audit et preuve de rejeu. L'empreinte lie le lot complet.
            record, replayed = portal.save(actor, body, batch_digest=digest)
        except APIError as exc:
            if exc.status_code in {401, 403, 503} or exc.default_code.startswith('IDEMPOTENCY_'):
                raise
            issues[row['clientRowId']] = exc.detail if isinstance(exc.detail, dict) else {'_line': str(exc.detail)}
        else:
            records.append({'clientRowId': row['clientRowId'], 'id': record['ID_Support']})
            replays.append(replayed)
    if issues:
        invalid(issues)
    return {'requestId': str(request_id), 'count': len(records), 'records': records}, all(replays)


def options(context, source):
    return context.get('references', {}).get(source, context.get(source, context.get('links', {}).get(source, [])))


class SupportTemplateView(ExcelDownloadView):
    permission_classes = [HasModuleAccess]

    def get(self, request):
        portal._write_access(request.user)
        if request.query_params:
            raise APIError('Critère non autorisé.')
        context = portal.references(request.user)
        columns = [{'key': key, 'label': label, 'width': 45 if key in {'Objet', 'Description'} else 28,
                    **({'choices': [{'value': str(item['id']), 'label': item['label']}
                                    for item in options(context, source) if not item.get('disabled')]}
                       if source else {})} for key, label, source in FIELDS]
        stream = build_template(sheet_name=SHEET, columns=columns, notes=[
            ('Utilisation', 'Une ligne par dossier. Importez puis vérifiez le panier avant enregistrement.'),
            ('Limite', '100 dossiers par panier.'),
            ('Champs obligatoires', ', '.join(label for key, label, _ in FIELDS if key in context['requiredFields'])),
            ('Échéance', 'AAAA-MM-JJTHH:MM ; heure de Kinshasa.'),
            ('Références', 'Utilisez les identifiants proposés pour cette entreprise. Le panier permet de corriger chaque champ.'),
        ], max_rows=MAX_ROWS)
        response = FileResponse(stream, as_attachment=True, filename='SauverNdeko_Modele_Tickets.xlsx', content_type=XLSX_MEDIA_TYPE)
        response['Cache-Control'] = 'no-store, private'
        return response


class SupportExcelPreviewView(ExcelPreviewMixin, APIView):
    permission_classes = [HasModuleAccess]
    http_method_names = ['post', 'options']

    def post(self, request):
        portal._write_access(request.user)
        matrix = read_uploaded_workbook(request, sheet_name=SHEET, headers=HEADERS,
                                        required_headers=('Objet', 'Description'), max_rows=MAX_ROWS, max_cell_length=20000)
        return ok({'matrix': matrix})


class SupportBatchView(APIView):
    permission_classes = [HasModuleAccess]
    http_method_names = ['post', 'options']

    def post(self, request):
        result, replayed = create_batch(request.user, request.data)
        return ok(result, status=200 if replayed else 201, meta={'replayed': replayed})
