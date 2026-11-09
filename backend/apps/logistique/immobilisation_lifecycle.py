"""Parcours patrimoniaux complémentaires du registre, sans mouvement de stock."""

import hashlib
import hmac
import json
import re
import unicodedata
import uuid
from datetime import date
from decimal import Decimal, InvalidOperation

from django.db import DatabaseError, transaction
from rest_framework.views import APIView

from apps.core import db
from apps.core.module_access import require_module
from apps.core.permissions import IsERPAdmin
from apps.core.repository import positive, set_admin_actor
from apps.core.responses import ExactEncoder, ok
from apps.core.tenancy import assert_document
from .immobilisations import KEY, fail, record, rights


def require_schema(relation):
    if not db.one('SELECT to_regclass(%s) relation', ['logistique."' + relation + '"'])['relation']:
        fail('Ce suivi sera disponible après la mise à jour de la base.', code='PATRIMOINE_MIGRATION_REQUIRED', status=503)


def request_proof(body, entity, pk, fields):
    if not isinstance(body, dict) or set(body) - (fields | {'requestId', '_version'}):
        fail('Un champ du formulaire n’est pas autorisé.')
    try:
        request_id = str(uuid.UUID(body.get('requestId')))
    except (TypeError, ValueError, AttributeError):
        fail('Rouvrez le formulaire pour obtenir un identifiant de demande.')
    payload = {key: value for key, value in body.items() if key not in {'requestId', '_version'}}
    encoded = json.dumps([entity, pk, payload], cls=ExactEncoder, sort_keys=True, separators=(',', ':'), ensure_ascii=False)
    return request_id, hashlib.sha256(encoded.encode()).hexdigest()


def text_value(body, key, limit, *, required=True):
    value = body.get(key)
    if not required and value in (None, ''):
        return None
    if not isinstance(value, str) or len(value) > limit:
        fail(f'Renseignez un texte de {limit} caractères au maximum.', key)
    value = value.replace('\r\n', '\n').strip()
    if (required and not value) or any(
        unicodedata.category(char) in {'Cc', 'Cs', 'Zl', 'Zp'} and (required or char != '\n') for char in value
    ):
        fail('Renseignez un texte sans caractère de contrôle.', key)
    return value or None


def date_value(body, key, *, required=True):
    value = body.get(key)
    if not required and value in (None, ''):
        return None
    try:
        if not isinstance(value, str) or not re.fullmatch(r'[0-9]{4}-[0-9]{2}-[0-9]{2}', value):
            raise ValueError()
        return date.fromisoformat(value)
    except ValueError:
        fail('Indiquez une date valide.', key)


def amount(body, key, *, scale=2, digits=18, required=True):
    value = body.get(key)
    if not required and value in (None, ''):
        return None
    try:
        if isinstance(value, bool):
            raise ValueError()
        number = Decimal(str(value))
        if not number.is_finite() or not 0 <= number < Decimal(10) ** (digits - scale) or number.as_tuple().exponent < -scale:
            raise ValueError()
        return number
    except (InvalidOperation, ValueError):
        fail('Indiquez un nombre positif ou nul avec une précision valide.', key)


def require_manager(actor, row):
    require_module(actor, 'logistique', 'manage')
    db.ensure_writable()
    if not actor.admin:
        fail('Accès réservé aux gestionnaires.', code='FORBIDDEN', status=403)
    return assert_document(actor, row)


def revision(body, *, plan=False):
    value = body.get('_version')
    if not isinstance(value, str) or not re.fullmatch(r'[0-9a-f]{32}' if plan else r'[0-9]{1,12}', value):
        fail('Rechargez la fiche avant de confirmer.', code='IMMOBILISATION_VERSION_CONFLICT', status=409)
    return value


def business_error(exc):
    cause = exc.__cause__
    state = getattr(cause, 'sqlstate', None)
    if state == '42501':
        fail('Cette action est réservée aux gestionnaires de l’entreprise.', code='FORBIDDEN', status=403)
    if state == '40001':
        fail('Les données ont changé. Rechargez la fiche ou le plan avant de confirmer.', code='IMMOBILISATION_VERSION_CONFLICT', status=409)
    if state == '23505':
        fail('Une opération identique ou incompatible existe déjà.', code='PATRIMOINE_CONFLICT', status=409)
    if state in {'23514', '23503'}:
        diagnostic = getattr(cause, 'diag', None)
        if diagnostic and not diagnostic.constraint_name and diagnostic.message_primary:
            fail(diagnostic.message_primary, code='PATRIMOINE_CONFLICT', status=409)
        fail('L’opération est incompatible avec l’état du bien ou ses références.', code='PATRIMOINE_CONFLICT', status=409)
    raise exc


def cycle_data(actor, row):
    require_schema('V_ImmobilisationEvenement')
    writable = rights(actor, row)['canWrite']
    active = writable and row['Actif'] and not row['TypeSortie']
    keys = [row['IdEntiteFk'], row[KEY]]
    events = db.query('''
        SELECT * FROM logistique."V_ImmobilisationEvenement"
        WHERE "IdEntiteFk"=%s AND "ID_ImmobilisationFk"=%s
        ORDER BY "DateEvenement" DESC, "ID_Evenement" DESC
        ''', keys)
    documents = db.query('''
        SELECT "ID_Piece","NomFichier","MimeType","TailleOctets","CreeLe"
        FROM logistique."V_PieceJustificative"
        WHERE "IdEntiteFk"=%s AND "TypeObjet"='immobilisation' AND "ID_Objet"=%s AND NOT "Archive"
        ORDER BY "CreeLe" DESC, "ID_Piece" DESC
        ''', keys)
    return ok({'events': events, 'documents': documents},
        meta={'canEvent': bool(active), 'canDispose': bool(active), 'canAttach': writable})


def add_physical_event(actor, pk, body):
    row = record(actor, pk)
    entity = require_manager(actor, row)
    proof, digest = request_proof(body, entity, pk, {'type', 'date', 'motif', 'observation', 'quantiteComptee', 'pieceId'})
    kind = body.get('type')
    if kind not in ('INVENTAIRE', 'ENTRETIEN', 'CESSION', 'REBUT'):
        fail('Choisissez un événement valide.', 'type')
    on = date_value(body, 'date')
    reason = text_value(body, 'motif', 1000)
    observation = text_value(body, 'observation', 4000, required=False)
    counted = amount(body, 'quantiteComptee', scale=0, required=kind == 'INVENTAIRE')
    piece = amount(body, 'pieceId', scale=0, digits=19, required=False)
    if piece is not None and not 0 < piece < 2**63:
        fail('Choisissez un justificatif valide.', 'pieceId')
    version = revision(body)
    require_schema('T_ImmobilisationEvenement')
    with transaction.atomic():
        db.one('SELECT pg_advisory_xact_lock(hashtextextended(%s,0)) locked', [f'patrimoine-evenement:{entity}:{actor.pk}:{proof}'])
        locked = record(actor, pk, lock=True)
        previous = db.one('''
            SELECT "ID_ImmobilisationFk","PayloadHash" FROM logistique."T_ImmobilisationEvenement"
            WHERE "IdEntiteFk"=%s AND "ID_UserFk"=%s AND "RequestId"=%s
            ''', [entity, actor.pk, proof])
        if previous:
            if previous['ID_ImmobilisationFk'] != pk or not hmac.compare_digest(previous['PayloadHash'], digest):
                fail('Cette demande est déjà utilisée pour un autre contenu.', code='PATRIMOINE_REQUEST_CONFLICT', status=409)
            return
        if version != locked['_version']:
            fail('Cette fiche a changé. Rechargez-la avant de confirmer.', code='IMMOBILISATION_VERSION_CONFLICT', status=409)
        set_admin_actor(actor)
        db.one('''
            INSERT INTO logistique."T_ImmobilisationEvenement"(
              "ID_ImmobilisationFk","IdEntiteFk","TypeEvenement","DateEvenement","Motif","Observation",
              "QuantiteComptee","ID_PieceFk","RequestId","PayloadHash")
            VALUES(%s,%s,%s,%s,%s,%s,%s,%s,%s,%s) RETURNING "ID_Evenement"
            ''', [pk, entity, kind, on, reason, observation, counted, int(piece) if piece is not None else None, proof, digest])


class ImmobilisationCycleView(APIView):
    permission_classes = [IsERPAdmin]
    http_method_names = ['get', 'post', 'options']

    def get(self, request, pk):
        return cycle_data(request.user, record(request.user, pk))

    def post(self, request, pk):
        try:
            add_physical_event(request.user, positive(pk), request.data)
        except DatabaseError as exc:
            business_error(exc)
        return cycle_data(request.user, record(request.user, pk))


def valuation_data(actor, row):
    require_schema('V_ImmobilisationPlan')
    writable = rights(actor, row)['canWrite']
    entity = row['IdEntiteFk']
    plans = db.query('''
        SELECT * FROM logistique."V_ImmobilisationPlan"
        WHERE "IdEntiteFk"=%s AND "ID_ImmobilisationFk"=%s ORDER BY "UsagePlan"
        ''', [entity, row[KEY]])
    for plan in plans:
        plan_id = plan['ID_Plan']
        plan['schedule'] = db.query('SELECT * FROM logistique.fn_echeancier_immobilisation(%s::bigint)', [plan_id])
        plan['events'] = db.query('''
            SELECT "ID_EvenementValeur","ID_PlanFk","TypeEvenement","DateEffet","Montant",
                   "Motif","ValeurAvantSortie","CreeLe","CreeParUserFk"
            FROM logistique."T_ImmobilisationEvenementValeur"
            WHERE "IdEntiteFk"=%s AND "ID_PlanFk"=%s ORDER BY "DateEffet" DESC,"ID_EvenementValeur" DESC
            ''', [entity, plan_id])
    periods = db.query('''
        SELECT "ID_ClotureValeur","UsagePlan","JusquAu","Motif","CreeLe","CreeParUserFk"
        FROM logistique."T_ImmobilisationClotureValeur" WHERE "IdEntiteFk"=%s
        ORDER BY "JusquAu" DESC,"ID_ClotureValeur" DESC
        ''', [entity])
    return ok({'plans': plans, 'periods': periods},
        meta={'canCreate': writable and row['Actif'], 'canPost': writable, 'canClose': writable})


def add_valuation_event(actor, pk, body):
    row = record(actor, pk)
    entity = require_manager(actor, row)
    require_schema('V_ImmobilisationPlan')
    action = body.get('action') if isinstance(body, dict) else None
    fields = {
        'CREER': {'usage', 'referentiel', 'methode', 'cout', 'residuel', 'debut', 'duree', 'deviseId'},
        'EVENEMENT': {'planId', 'type', 'date', 'montant'},
        'CLOTURER': {'usage', 'date'},
    }
    if not isinstance(action, str) or action not in fields:
        fail('Action de valorisation invalide.')
    proof, digest = request_proof(body, entity, pk, fields[action] | {'action', 'motif'})
    reason = text_value(body, 'motif', 1000)
    prefix = [entity, actor.pk, proof, digest]
    with transaction.atomic():
        set_admin_actor(actor)
        if action == 'CREER':
            duration = body.get('duree')
            db.one('SELECT logistique.fn_creer_plan_immobilisation(%s::bigint,%s,%s,%s::uuid,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)', [
                pk, *prefix, text_value(body, 'usage', 16), text_value(body, 'referentiel', 16),
                text_value(body, 'methode', 24), amount(body, 'cout'), amount(body, 'residuel'),
                date_value(body, 'debut'), positive(duration, 'Durée') if duration not in (None, '') else None,
                positive(body.get('deviseId'), 'Devise'), reason, revision(body)])
        elif action == 'EVENEMENT':
            plan_id = positive(body.get('planId'), 'Plan')
            if not db.one('''SELECT 1 FROM logistique."T_ImmobilisationPlan"
                WHERE "ID_Plan"=%s AND "IdEntiteFk"=%s AND "ID_ImmobilisationFk"=%s''', [plan_id, entity, pk]):
                fail('Plan de valorisation introuvable pour cette fiche.', code='NOT_FOUND', status=404)
            db.one('SELECT logistique.fn_enregistrer_evenement_valorisation(%s::bigint,%s,%s,%s::uuid,%s,%s,%s,%s,%s,%s)', [
                plan_id, *prefix, revision(body, plan=True), text_value(body, 'type', 24), date_value(body, 'date'),
                amount(body, 'montant', required=False), reason])
        else:
            db.one('SELECT logistique.fn_cloturer_valorisation(%s,%s,%s::uuid,%s,%s,%s,%s)', [
                *prefix, text_value(body, 'usage', 16), date_value(body, 'date'), reason])


class ImmobilisationValuationView(APIView):
    permission_classes = [IsERPAdmin]
    http_method_names = ['get', 'post', 'options']

    def get(self, request, pk):
        return valuation_data(request.user, record(request.user, pk))

    def post(self, request, pk):
        try:
            add_valuation_event(request.user, positive(pk), request.data)
        except DatabaseError as exc:
            business_error(exc)
        return valuation_data(request.user, record(request.user, pk))
