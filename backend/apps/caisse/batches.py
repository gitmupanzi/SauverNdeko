"""Création de paniers de caisse dans une transaction unique."""
import hashlib
import json
import re
import uuid

from django.db import DatabaseError, transaction

from apps.core.responses import APIError, ExactEncoder

from . import services


MAX_ROWS = 100
CREATE = {
    'caisses': services.create_cash,
    'ecritures': services.create_entry,
    'clotures': services.close_cash,
}


def invalid(issues=None, header=None):
    raise APIError({'rows': issues or {}, 'header': header or {}}, 'CAISSE_BATCH_VALIDATION', 422)


@transaction.atomic
def create_batch(actor, kind, body):
    services.writable(actor, kind)
    allowed = {'requestId', 'rows'} | ({'valider'} if kind == 'ecritures' else set())
    if set(body) - allowed or type(body.get('valider', False)) is not bool:
        invalid(header={'rows': 'Vérifiez le format du panier.'})
    try:
        request_id = uuid.UUID(body.get('requestId'))
    except (AttributeError, TypeError, ValueError):
        invalid(header={'requestId': 'Identifiant de demande invalide.'})
    rows = body.get('rows')
    if not isinstance(rows, list) or not 1 <= len(rows) <= MAX_ROWS:
        invalid(header={'rows': f'Ajoutez de 1 à {MAX_ROWS} lignes.'})

    row_fields = {'clientRowId', 'data', 'motif'} | ({'_version'} if kind == 'clotures' else set())
    row_ids = set()
    cashbox_ids = set()
    issues = {}
    for row in rows:
        if not isinstance(row, dict) or set(row) - row_fields:
            invalid(header={'rows': 'Certaines lignes ont un format invalide.'})
        row_id = row.get('clientRowId')
        if not isinstance(row_id, str) or not re.fullmatch(r'[A-Za-z0-9_-]{1,100}', row_id) or row_id in row_ids:
            invalid(header={'rows': 'Les identifiants de ligne doivent être distincts.'})
        row_ids.add(row_id)
        data = row.get('data')
        if not isinstance(data, dict):
            issues[row_id] = {'_line': 'Complétez les informations de cette ligne.'}
        elif kind == 'clotures':
            cash_id = str(data.get('IdCaisseFk', ''))
            if re.fullmatch(r'[1-9][0-9]*', cash_id):
                if cash_id in cashbox_ids:
                    issues[row_id] = {'IdCaisseFk': 'Une caisse ne peut être clôturée qu’une fois par panier.'}
                cashbox_ids.add(cash_id)
            if not isinstance(row.get('motif'), str) or not row['motif'].strip():
                issues.setdefault(row_id, {})['motif'] = 'Précisez le motif de ce comptage.'
    if issues:
        invalid(issues)

    # Une empreinte du panier complet lie les identifiants déterministes des
    # lignes à leur contenu, leur ordre et leur nombre, même en cas de rejeu.
    try:
        encoded = json.dumps(body, sort_keys=True, ensure_ascii=False, cls=ExactEncoder, allow_nan=False).encode()
    except (TypeError, ValueError, UnicodeError):
        invalid(header={'rows': 'Le panier contient un texte invalide.'})
    if len(encoded) > 1024 * 1024:
        raise APIError('Le panier dépasse 1 Mo.', 'CAISSE_BATCH_TOO_LARGE', 413)
    digest = hashlib.sha256(encoded).hexdigest()
    records = []
    for index, row in enumerate(rows):
        row_id = row['clientRowId']
        item = {key: value for key, value in row.items() if key != 'clientRowId'}
        item['requestId'] = str(uuid.uuid5(request_id, f'caisse:{kind}:{actor.pk}:{index}'))
        if kind == 'ecritures':
            item['valider'] = body.get('valider', False)
        try:
            saved = CREATE[kind](actor, item, batch_digest=digest)
        except APIError as exc:
            if exc.status_code in {401, 403, 503} or exc.default_code == 'IDEMPOTENCY_CONFLICT':
                raise
            if exc.default_code == 'STALE_REVISION':
                issues[row_id] = {'_version': 'Le solde a changé. Rechargez-le et vérifiez le comptage.'}
            else:
                issues[row_id] = exc.detail if isinstance(exc.detail, dict) else {'_line': str(exc.detail)}
        except DatabaseError as exc:
            state = getattr(exc.__cause__, 'sqlstate', None)
            if state in {'40001', '40P01', '55P03'}:
                raise APIError('Une autre opération est en cours. Réessayez dans un instant.', 'CAISSE_RETRY', 409) from exc
            if state not in {'22001', '22003', '23502', '23503', '23505', '23514', '55000', 'P0001'}:
                raise
            issues[row_id] = {'_line': 'Vérifiez le solde disponible, les références et la dernière clôture de cette caisse.'}
        else:
            records.append({'clientRowId': row_id, 'id': saved['record'][services.SOURCES[kind][2]], 'replayed': saved['replayed']})
    if issues:
        invalid(issues)
    replayed = all(item['replayed'] for item in records)
    for item in records:
        del item['replayed']
    return {'requestId': str(request_id), 'count': len(records), 'records': records}, replayed
