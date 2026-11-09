"""Dépôts de l'entreprise ; le journal PostgreSQL reste l'unique source du stock."""
import hashlib
import hmac
import json
import uuid
from contextlib import contextmanager
from contextvars import ContextVar
from decimal import Decimal

from django.db import transaction
from rest_framework.views import APIView
from apps.core import db
from apps.core.module_access import require_module, access_snapshot, can_use_tab
from apps.core.permissions import IsERPAdmin
from apps.core.repository import audit, clean, page, positive
from apps.core.responses import APIError, ExactEncoder, ok
from apps.core.tenancy import assert_document, read_entity, require_entity

_internal = ContextVar('internal_depot_transfer', default=False)


@contextmanager
def internal_transfer():
    token = _internal.set(True)
    try: yield
    finally: _internal.reset(token)


def is_internal_transfer(): return _internal.get()


def access(actor, write=False):
    require_module(actor, 'logistique', 'manage' if write else 'read')
    if write:
        db.ensure_writable()
        if not actor.admin: raise APIError('Accès réservé aux gestionnaires autorisés.', 'FORBIDDEN', 403)
        return require_entity(actor)
    return read_entity(actor)


def can_manage(actor):
    from django.conf import settings
    return bool(actor.admin and not settings.DB_READ_ONLY and read_entity(actor) is not None
                and access_snapshot(actor)['modules'].get('logistique', {}).get('canManage'))


def depot(actor, identifier=None, *, active=True, lock=False, entity=None):
    owner = entity if entity is not None else (read_entity(actor) if identifier not in (None,'') else require_entity(actor))
    if identifier in (None, ''):
        row = db.one('SELECT * FROM logistique."T_Depot" WHERE "IdEntiteFk"=%s AND "Principal" IS TRUE' + (' FOR SHARE' if lock else ''), [owner])
    else:
        row = db.one('SELECT * FROM logistique."T_Depot" WHERE "ID_Depot"=%s' + (' AND "IdEntiteFk"=%s' if owner is not None else '') + (' FOR SHARE' if lock else ''), [positive(identifier, 'Dépôt'), *([owner] if owner is not None else [])])
    if not row: raise APIError({'ID_DepotFk': 'Choisissez un dépôt de cette entreprise.'}, 'DEPOT_REQUIRED', 409)
    if active and not row['Actif']: raise APIError({'ID_DepotFk': 'Ce dépôt est désactivé.'}, 'DEPOT_INACTIVE', 409)
    return row


def choices(actor):
    owner = access(actor)
    rows = db.query('SELECT * FROM logistique."T_Depot"' + (' WHERE "IdEntiteFk"=%s' if owner else '') + ' ORDER BY "Principal" DESC,"NomDepot","ID_Depot"', [owner] if owner else [])
    return [{**clean(row), 'id': row['ID_Depot'], 'label': row['NomDepot'], 'principal': row['Principal'], 'active': row['Actif'], 'revision': str(row['Version'])} for row in rows]


def resolve_header(actor, data, old=None):
    """Une modification ne déplace jamais un historique de mouvements."""
    previous = (old or {}).get('ID_DepotFk')
    selected = data.get('ID_DepotFk', previous)
    row = depot(actor, selected, active=not old or selected != previous, lock=True)
    if old and previous != row['ID_Depot']:
        linked = db.one('SELECT EXISTS(SELECT FROM logistique."T_CommandeDetail" WHERE "ID_CmdFk"=%s) OR EXISTS(SELECT FROM logistique."T_Mouvement" WHERE "ID_cmdFk"=%s) AS present', [old['ID_Commande'], old['ID_Commande']])['present']
        if linked: raise APIError('Le dépôt est conservé après la première ligne. Utilisez un transfert interne.', 'DEPOT_LOCKED', 409)
    data['ID_DepotFk'] = row['ID_Depot']
    return row


def stock(article_id, depot_id):
    row = db.one('SELECT * FROM logistique."V_StockDepot" WHERE "ID_ArticleFk"=%s AND "ID_DepotFk"=%s', [article_id, depot_id])
    return row or {'ID_ArticleFk': article_id, 'ID_DepotFk': depot_id, 'StockPhysique': Decimal(0), 'StockReserve': Decimal(0), 'StockDisponible': Decimal(0), 'StockSansLot': Decimal(0)}


def article_stock(record, depot_id):
    local=stock(record['ID_Article'],depot_id)
    return {**record,'StockEntreprise':record['QteArticle'],'QteArticle':local['StockPhysique'],
            'StockDepot':local['StockPhysique'],'StockDisponible':local['StockDisponible'],
            'StockReserve':local['StockReserve'],'ID_DepotFk':depot_id}


def requested_depot(actor, params):
    value = params.get('depotId', params.get('ID_DepotFk'))
    if value in (None, '', 'all'): return None
    row = db.one('SELECT * FROM logistique."T_Depot" WHERE "ID_Depot"=%s', [positive(value, 'Dépôt')])
    if not row: raise APIError('Dépôt introuvable.', 'NOT_FOUND', 404)
    owner = read_entity(actor)
    if owner is not None and row['IdEntiteFk'] != owner: raise APIError('Dépôt introuvable.', 'NOT_FOUND', 404)
    return row['ID_Depot']


def fingerprint(value):
    return hashlib.sha256(json.dumps(value, cls=ExactEncoder, sort_keys=True, separators=(',', ':')).encode()).hexdigest()


def save(actor, identifier, body):
    owner = access(actor, True)
    allowed = {'requestId', '_version', 'CodeDepot', 'NomDepot', 'AdresseDepot', 'Actif', 'Principal','motif'}
    if not isinstance(body, dict) or set(body) - allowed: raise APIError('Informations du dépôt invalides.')
    try: request = str(uuid.UUID(body.get('requestId')))
    except (ValueError, TypeError, AttributeError): raise APIError('Rouvrez le formulaire pour préparer une nouvelle demande.')
    data = {key: body[key] for key in allowed - {'requestId', '_version','motif'} if key in body}
    for field, maximum in [('NomDepot', 120), ('CodeDepot', 40), ('AdresseDepot', 1000)]:
        if field in data:
            if not isinstance(data[field], str) or len(data[field].strip()) > maximum: raise APIError({field: 'Texte invalide ou trop long.'})
            data[field] = data[field].strip()
    if not identifier and not data.get('NomDepot'): raise APIError({'NomDepot': 'Indiquez le nom du dépôt.'})
    for field in ('Actif', 'Principal'):
        if field in data and type(data[field]) is not bool: raise APIError({field: 'Valeur Oui ou Non attendue.'})
    signature = fingerprint({'entity': owner, 'id': identifier, 'body': body})
    with transaction.atomic():
        db.one('SELECT pg_advisory_xact_lock(hashtextextended(%s,0)) AS locked', ['depot:' + str(actor.pk) + ':' + request])
        proof = db.one('''SELECT "NewData" AS proof FROM systeme."T_Audit_Log" WHERE "TableName"='logistique.T_Depot' AND "Operation"='DEPOT_SAVE' AND "NewData"->>'requestId'=%s AND "NewData"->'_actor'->>'IdUser'=%s ORDER BY "IdLog" DESC LIMIT 1''', [request, str(actor.pk)])
        if proof:
            saved = proof['proof']
            if not hmac.compare_digest(saved.get('hash', ''), signature): raise APIError('Cette demande a déjà été utilisée.', 'DEPOT_REPLAY_CONFLICT', 409)
            return depot(actor, saved['ID_Depot'], active=False), True
        # Sérialise aussi les changements de dépôt principal d'une entreprise.
        db.one('SELECT pg_advisory_xact_lock(hashtextextended(%s,0)) AS locked', ['depot-owner:' + str(owner)])
        old = depot(actor, identifier, active=False, lock=True) if identifier else None
        if old and str(old['Version']) != str(body.get('_version')): raise APIError('Ce dépôt a changé. Rechargez sa fiche.', 'DEPOT_CONFLICT', 409)
        if old and 'NomDepot' in data and not data['NomDepot']: raise APIError({'NomDepot': 'Indiquez le nom du dépôt.'})
        if data.get('Principal'):
            db.query('UPDATE logistique."T_Depot" SET "Principal"=false WHERE "IdEntiteFk"=%s AND "Principal" AND "ID_Depot"<>%s', [owner, identifier or 0])
        if old:
            if not data: return old, False
            row = db.one('UPDATE logistique."T_Depot" SET ' + ','.join(db.ident(k) + '=%s' for k in data) + ' WHERE "ID_Depot"=%s RETURNING *', [*data.values(), identifier])
        else:
            data.update(IdEntiteFk=owner, ID_UserFk=actor.pk)
            row = db.one('INSERT INTO logistique."T_Depot" (' + ','.join(db.ident(k) for k in data) + ') VALUES (' + ','.join(['%s'] * len(data)) + ') RETURNING *', list(data.values()))
        audit({'schema': 'logistique', 'name': 'T_Depot'}, 'DEPOT_SAVE', old=old, new={**row, 'requestId': request, 'hash': signature}, actor=actor)
        return clean(row), False


class DepotsView(APIView):
    permission_classes = [IsERPAdmin]
    def get(self, request, pk=None):
        if pk is None and request.query_params.get("usage") == "selection":
            return ok([{key: row[key] for key in ("id", "label", "principal", "active")} for row in choices(request.user)])
        access(request.user)
        if pk:
            requested_depot(request.user, {'depotId':pk})
            row=depot(request.user, pk, active=False)
            return ok(row,meta={'revision':str(row['Version']),'canEdit':can_manage(request.user) and can_use_tab(request.user, "logistique", "depots", "manage")})
        from .depot_registers import listing
        rows, meta = listing(request.user, 'depots', request.query_params)
        return ok(rows, meta=meta)
    def post(self, request):
        row, replayed = save(request.user, None, request.data)
        return ok(row, status=200 if replayed else 201)
    def put(self, request, pk): return ok(save(request.user, positive(pk), request.data)[0])


class DepotStocksView(APIView):
    permission_classes = [IsERPAdmin]
    def get(self, request):
        from .depot_registers import listing
        rows, meta = listing(request.user, 'stocks-depots', request.query_params)
        return ok(rows, meta=meta)
