"""Paniers de création : les services individuels restent l'autorité métier.

Un panier valide une seule entreprise et une seule transaction. Les fichiers
des nouvelles photos sont compensés si une autre ligne ou le commit échoue.
"""
import hashlib
import hmac
import json
import re
import uuid
from decimal import Decimal

from django.db import DatabaseError, transaction
from django.utils import timezone
from rest_framework.parsers import JSONParser, MultiPartParser
from rest_framework.views import APIView

from apps.core import db
from apps.core.module_access import require_module
from apps.core.permissions import IsERPAdmin
from apps.core.repository import audit
from apps.core.responses import APIError, ExactEncoder, ok
from apps.core.tenancy import require_entity

from .quantities import quantity

TABLES = {'tiers': 'T_Client', 'articles': 'T_Article', 'immobilisations': 'T_Immobilisation'}
MAX_ROWS = 100
MAX_OPENING_ROWS = 600
MAX_PAYLOAD = 4 * 1024 * 1024
MAX_UPLOADS = 32 * 1024 * 1024
LINE_ID = re.compile(r'[A-Za-z0-9_-]{1,100}\Z')


def problem(rows=None, header=None):
    return APIError({'rows': rows or {}, 'header': header or {}}, 'LOGISTICS_BATCH_VALIDATION', 422)


def parse_request(request, kind):
    """La pièce jointe d'une ligne porte une clé fermée, jamais un chemin."""
    if request.content_type.startswith('multipart/form-data'):
        if kind != 'articles' or set(request.data) - {'payload'} - set(request.FILES):
            raise APIError('Contenu du panier non autorisé.')
        try:
            raw = request.data.get('payload', '')
            if not isinstance(raw, str) or len(raw.encode('utf8')) > MAX_PAYLOAD:
                raise ValueError()
            body = json.loads(raw, parse_float=Decimal)
        except (ValueError, TypeError):
            raise APIError('Le panier article est invalide.')
        if len(request.data.getlist('payload')) != 1 or any(len(request.FILES.getlist(key)) != 1 for key in request.FILES):
            raise APIError('Un fichier et un formulaire au maximum par clé.')
        return body, dict(request.FILES.items())
    return request.data, {}


def _digest_files(files, rows):
    allowed = {'photo_' + row['clientRowId'] for row in rows}
    if set(files) - allowed:
        raise APIError('Une photo ne correspond à aucune ligne du panier.')
    from .photos import MAX_BYTES
    if sum(upload.size for upload in files.values()) > MAX_UPLOADS:
        raise problem(header={'photos': 'Les photos du panier ne doivent pas dépasser 32 Mo au total.'})
    hashes = {}
    for key, upload in files.items():
        line_id = key[len('photo_'):]
        if upload.size <= 0:
            raise problem(rows={line_id: {'photo': 'Choisissez un fichier image non vide.'}})
        if upload.size > MAX_BYTES:
            raise problem(rows={line_id: {'photo': 'L’image ne doit pas dépasser 8 Mo.'}})
        content = upload.read(MAX_BYTES + 1)
        upload.seek(0)
        if len(content) > MAX_BYTES:
            raise problem(rows={line_id: {'photo': 'L’image ne doit pas dépasser 8 Mo.'}})
        hashes[key] = hashlib.sha256(content).hexdigest()
    return hashes


def create_row(actor, kind, data, request_id, photo=None, created_paths=None):
    payload = {**data, 'requestId': request_id}
    if kind == 'tiers':
        from .tiers import save
        return save(actor, payload)[0]
    if kind == 'immobilisations':
        from .immobilisations import save
        return save(actor, payload)[0]
    from .photos import save_article
    return save_article(actor, payload, photo, _created_paths=created_paths)


def opening_article(data):
    stock = quantity(data.get('QteArticle'), 'QteArticle', zero=True)
    lots = data.get('LotsInitiaux')
    if lots is not None and (not isinstance(lots, list) or (lots and not stock)):
        raise APIError({'LotsInitiaux': 'Les lots nécessitent une quantité d’ouverture positive.'})
    if stock and data.get('PUArticle') in (None, ''):
        raise APIError({'PUArticle': 'Indiquez le prix d’achat unitaire, même si sa valeur est zéro.'})
    article = {key: value for key, value in data.items() if key != 'LotsInitiaux'}
    return {**article, 'QteArticle': 0}, stock, lots or []


def opening_receipt(actor, request_id, entries):
    from .order_composer import compose_order
    from .receipts import entry_type

    if not entries:
        raise problem(header={'rows': 'Saisissez une quantité positive pour au moins un article.'})
    currencies = {entry[0]['ID_DeviseFk'] for entry in entries}
    if len(currencies) != 1:
        message = 'Tous les articles réceptionnés sur le même bon doivent utiliser la même devise.'
        raise problem(rows={article['clientRowId']: {'ID_DeviseFk': message} for article, _, _ in entries})
    lines = [
        {'ID_ArticleFk': article['ID_Article'], 'QteCmdDetail': stock, 'PUCmdDetail': article['PUArticle'], 'Lots': lots}
        for article, stock, lots in entries
    ]
    try:
        kind = entry_type(lock=True, actor=actor)
        result = compose_order(actor, {
            'requestId': str(uuid.uuid5(uuid.UUID(request_id), 'opening-receipt')),
            'bon': {
                'ID_TypeCmdFk': kind['id'],
                'ID_DeviseFk': next(iter(currencies)),
                'DateCmd': timezone.now().isoformat(),
                'RefCmd': 'Stock d’ouverture',
                'ObsCmd': 'Entrée de stock issue d’un import d’articles.',
            },
            'lignes': lines,
        }, max_lines=MAX_OPENING_ROWS)
    except APIError as error:
        if error.status_code in (401, 403) or error.status_code >= 500:
            raise
        fields = {'QteCmdDetail': 'QteArticle', 'PUCmdDetail': 'PUArticle', 'Lots': 'LotsInitiaux'}
        row_errors = {}
        header_errors = {}
        details = error.detail if isinstance(error.detail, dict) else {'bon': str(error.detail)}
        for key, message in details.items():
            match = re.fullmatch(r'lignes\.(\d+)(?:\.([^.]+).*)?', key)
            if match and int(match[1]) < len(entries):
                identity = entries[int(match[1])][0]['clientRowId']
                row_errors.setdefault(identity, {})[fields.get(match[2], '_line')] = message
            else:
                header_errors[key.removeprefix('bon.')] = message
        raise problem(rows=row_errors, header=header_errors) from error

    stock_by_article = {line['ID_ArticleFk']: line['StockActuel'] for line in result['lignes']}
    for article, _, _ in entries:
        article['QteArticle'] = stock_by_article[article['ID_Article']]
    bon = result['bon']
    return {'id': bon['ID_Commande'], 'code': bon['CodeCmd']}


def save_batch(actor, kind, body, files=None):
    if kind not in TABLES:
        raise APIError('Ce panier est introuvable.', 'NOT_FOUND', 404)
    db.ensure_writable()
    require_module(actor, 'logistique', 'manage')
    entity = require_entity(actor)
    if not actor.admin:
        raise APIError('Accès réservé aux gestionnaires.', 'FORBIDDEN', 403)
    expected = {'requestId', 'rows'}
    allowed = expected | ({'openingReceipt'} if kind == 'articles' else set())
    if not isinstance(body, dict) or not expected <= set(body) <= allowed:
        raise APIError('Le panier attend son identifiant et ses lignes.')
    with_receipt = body.get('openingReceipt', False)
    if type(with_receipt) is not bool:
        raise problem(header={'openingReceipt': 'Choisissez si le panier crée un bon d’entrée.'})
    try:
        request_id = str(uuid.UUID(body['requestId']))
    except (TypeError, ValueError, AttributeError):
        raise APIError('Rouvrez le formulaire pour identifier le panier.', 'LOGISTICS_BATCH_REQUEST_INVALID', 400)
    rows = body['rows']
    max_rows = MAX_OPENING_ROWS if with_receipt else MAX_ROWS
    if not isinstance(rows, list) or not 1 <= len(rows) <= max_rows:
        raise problem(header={'rows': f'Ajoutez de 1 à {max_rows} lignes.'})
    ids = set()
    issues = {}
    for row in rows:
        if not isinstance(row, dict) or set(row) != {'clientRowId', 'data'} or not isinstance(row.get('clientRowId'), str) or not LINE_ID.fullmatch(row['clientRowId']):
            raise APIError('Chaque ligne attend une clé stable et ses informations.')
        identity = row['clientRowId']
        if identity in ids:
            raise APIError('Les clés des lignes doivent être distinctes.')
        ids.add(identity)
        if not isinstance(row['data'], dict):
            issues[identity] = {'_line': 'Les informations de la ligne doivent être un objet.'}
        elif {'requestId', '_version', 'IdEntiteFk', 'ID_EntiteFk'} & set(row['data']):
            issues[identity] = {'_line': 'L’entreprise et l’identité sont celles du panier, sans révision de fiche.'}
    if issues:
        raise problem(rows=issues)
    encoded = json.dumps(body, cls=ExactEncoder, ensure_ascii=False, sort_keys=True, separators=(',', ':')).encode('utf8')
    if len(encoded) > MAX_PAYLOAD:
        raise problem(header={'rows': 'Le contenu du panier dépasse 4 Mo.'})
    files = files or {}
    if kind != 'articles' and files:
        raise APIError('Ce panier ne reçoit pas de photos.')
    hashes = _digest_files(files, rows)
    digest = hashlib.sha256(json.dumps({'body': body, 'files': hashes, 'entity': entity, 'kind': kind},
        cls=ExactEncoder, ensure_ascii=False, sort_keys=True, separators=(',', ':')).encode('utf8')).hexdigest()
    obj = {'schema': 'logistique', 'name': TABLES[kind]}
    created_paths = []
    committed = False
    try:
        with transaction.atomic():
            db.one('SELECT pg_advisory_xact_lock(hashtextextended(%s,0)) locked',
                   [f'logistics-batch:{actor.pk}:{request_id}'])
            prior = db.one('SELECT "NewData" proof FROM systeme."T_Audit_Log" '
                'WHERE "TableName"=%s AND "Operation"=\'LOGISTICS_BATCH_CREATE\' '
                'AND "NewData"->>\'requestId\'=%s AND "NewData"->\'_actor\'->>\'IdUser\'=%s '
                'ORDER BY "IdLog" DESC LIMIT 1', ['logistique.' + TABLES[kind], request_id, str(actor.pk)])
            if prior:
                proof = prior['proof']
                if proof.get('IdEntiteFk') != entity or not hmac.compare_digest(str(proof.get('payloadHash', '')), digest):
                    raise APIError('Cette demande a déjà été enregistrée avec un autre contenu.', 'LOGISTICS_BATCH_REPLAY_CONFLICT', 409)
                return proof['response'], True
            records = []
            opening_entries = []
            for row in rows:
                identity = row['clientRowId']
                child_request = str(uuid.uuid5(uuid.UUID(request_id), kind + ':' + identity))
                try:
                    with transaction.atomic():
                        data = row['data']
                        if with_receipt:
                            data, stock, lots = opening_article(data)
                        saved = create_row(actor, kind, data, child_request,
                                           files.get('photo_' + identity), created_paths)
                except APIError as error:
                    if error.status_code in (401, 403, 503):
                        raise
                    issues[identity] = dict(error.detail) if isinstance(error.detail, dict) else {'_line': str(error.detail)}
                except DatabaseError as error:
                    state = getattr(error.__cause__, 'sqlstate', None)
                    if state not in {'22001', '22003', '23502', '23503', '23505', '23514', 'P0001'}:
                        raise
                    issues[identity] = {'_line': 'La ligne est incompatible avec les références, l’unicité du code ou les règles métier.'}
                else:
                    record = {'clientRowId': identity, **saved}
                    records.append(record)
                    if with_receipt and stock:
                        opening_entries.append((record, stock, lots))
            if issues:
                raise problem(rows=issues)
            result = {'requestId': request_id, 'count': len(records), 'records': records}
            if with_receipt:
                result['openingReceipt'] = opening_receipt(actor, request_id, opening_entries)
            audit(obj, 'LOGISTICS_BATCH_CREATE', new={'requestId': request_id, 'payloadHash': digest,
                'IdEntiteFk': entity, 'response': result}, actor=actor)
        committed = True
        return result, False
    finally:
        if not committed:
            for path in created_paths:
                path.unlink(missing_ok=True)


class LogisticsBatchView(APIView):
    permission_classes = [IsERPAdmin]
    parser_classes = [JSONParser, MultiPartParser]
    http_method_names = ['post', 'options']

    def post(self, request, kind):
        body, files = parse_request(request, kind)
        data, replayed = save_batch(request.user, kind, body, files)
        return ok(data, status=200 if replayed else 201, meta={'replayed': replayed}, message='Panier enregistré.')
