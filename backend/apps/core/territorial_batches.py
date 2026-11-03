"""Créations territoriales groupées : parent commun et transaction indivisible."""
import hashlib
import json
import uuid

from django.db import DatabaseError, transaction
from rest_framework.views import APIView

from . import db
from .permissions import IsERPAdmin
from .registry import model
from .repository import audit, mutate, payload, positive
from .reference_integration import validate_changed
from .responses import APIError, ExactEncoder, ok
from .territorial_portal import MODELS, hierarchy_lock, record, source, validate_body
from . import territorial_contacts


PARENTS = {
    'niveaux0': (),
    'niveaux1': ('ID_Niveau_0_Fk',),
    'niveaux2': ('ID_Niveau_1_FK',),
    'niveaux3': ('ID_Niveau_2_FK',),
    'niveaux4': ('ID_Niveau_3_Fk',),
    'niveaux5': ('ID_Niveau_3_Fk', 'ID_Niveau_4_Fk'),
}
MAX_ROWS = 100


def _uuid(value):
    try:
        if not isinstance(value, str) or str(uuid.UUID(value)) != value.lower():
            raise ValueError()
        return value.lower()
    except ValueError:
        raise APIError('Identifiant de demande ou de ligne invalide.', 'TERRITORIAL_BATCH_ID_INVALID')


def _invalid(rows=None, header=None):
    raise APIError({'rows': rows or {}, 'header': header or {}}, 'TERRITORIAL_BATCH_VALIDATION', 422)


def _details(error):
    """Les refus métier restent ciblés ; les droits et pannes ne sont pas masqués."""
    if isinstance(error, APIError):
        if error.status_code not in {400, 404, 409, 422}:
            raise error
        return dict(error.detail) if isinstance(error.detail, dict) else {'_line': str(error.detail)}
    state = getattr(error.__cause__, 'sqlstate', None)
    if state not in {'P0001', '23502', '23503', '23505', '23514', '22001', '22003'}:
        raise error
    return {'_line': 'Cette ligne ne respecte plus ses références ou ses contraintes. Vérifiez ses valeurs.'}


def _header(kind, raw):
    if not isinstance(raw, dict):
        _invalid(header={'_header': 'Renseignez les rattachements communs.'})
    expected = PARENTS[kind]
    unknown = set(raw) - set(expected)
    if unknown:
        _invalid(header={key: 'Ce champ ne fait pas partie des rattachements communs.' for key in unknown})
    result = {}; errors = {}
    for key in expected:
        value = raw.get(key)
        if kind == 'niveaux5' and key == 'ID_Niveau_4_Fk' and value is None:
            result[key] = None
            continue
        try:
            result[key] = positive(value, 'Rattachement')
        except APIError:
            errors[key] = 'Choisissez le rattachement commun.'
            continue
        level = key[len('ID_Niveau_')]
        found = db.one('SELECT 1 AS present FROM geolocalisation.' + db.ident('T_Niveau_' + level)
                       + ' WHERE ' + db.ident('ID_Niveau_' + level) + '=%s', [result[key]])
        if not found:
            errors[key] = 'Ce rattachement n’existe plus. Choisissez une valeur de la liste.'
    if not errors and kind == 'niveaux5' and result.get('ID_Niveau_4_Fk') is not None:
        area = db.one('SELECT "ID_Niveau_3_Fk" FROM geolocalisation."T_Niveau_4" WHERE "ID_Niveau_4"=%s',
                      [result['ID_Niveau_4_Fk']])
        if area['ID_Niveau_3_Fk'] != result['ID_Niveau_3_Fk']:
            errors['ID_Niveau_4_Fk'] = 'Choisissez une aire de la zone sélectionnée.'
    if errors:
        _invalid(header=errors)
    return result


def _identity(kind, data):
    """Homonymes permis ; seule la même identité nom/code/parents est comparée."""
    level = kind[-1]; name = 'NomNiveau_' + level; code = 'CodeNiveau_' + level
    normalized = db.one('SELECT referentiel.fn_normaliser_libelle(%s) AS name,'
                        'COALESCE(referentiel.fn_normaliser_libelle(%s),\'\') AS code',
                        [data[name], data.get(code)])
    return (normalized['name'], normalized['code'], *(data.get(key) for key in PARENTS[kind]))


def _exists(obj, kind, identity):
    level = kind[-1]
    clauses = ['referentiel.fn_normaliser_libelle(' + db.ident('NomNiveau_' + level) + ')=%s',
               'COALESCE(referentiel.fn_normaliser_libelle(' + db.ident('CodeNiveau_' + level) + '),\'\')=%s']
    clauses.extend(db.ident(key) + ' IS NOT DISTINCT FROM %s' for key in PARENTS[kind])
    return db.one('SELECT 1 AS duplicate FROM ' + db.qualified(obj['schema'], obj['name'])
                  + ' WHERE ' + ' AND '.join(clauses) + ' LIMIT 1', list(identity)) is not None


def save_batch(actor, kind, body):
    source(actor, kind, 'manage'); db.ensure_writable()
    if kind not in PARENTS:
        raise APIError('La saisie groupée est disponible pour les niveaux actuels 0 à 5.', 'NOT_FOUND', 404)
    if not actor.global_admin:
        raise APIError('Le découpage partagé est géré par la plateforme.', 'GLOBAL_ADMIN_REQUIRED', 403)
    if not isinstance(body, dict) or set(body) - {'requestId', 'header', 'rows'}:
        raise APIError('Un champ de la saisie groupée n’est pas autorisé.')
    request_id = _uuid(body.get('requestId')); rows = body.get('rows')
    if not isinstance(rows, list) or not 1 <= len(rows) <= MAX_ROWS:
        _invalid(header={'rows': 'Ajoutez de 1 à 100 lignes.'})
    identifiers = []
    for row in rows:
        if not isinstance(row, dict):
            raise APIError('Chaque ligne doit être un objet JSON.')
        identifiers.append(_uuid(row.get('rowId')))
    if len(set(identifiers)) != len(identifiers):
        raise APIError('Les lignes doivent posséder des identifiants distincts.', 'TERRITORIAL_BATCH_ID_INVALID')
    digest = hashlib.sha256(json.dumps({'kind': kind, 'body': body}, sort_keys=True,
                                      separators=(',', ':'), cls=ExactEncoder).encode()).hexdigest()
    obj = model(MODELS[kind]); operation = 'TERRITORIAL_BATCH_CREATE'
    with transaction.atomic():
        hierarchy_lock()
        db.query('SELECT pg_advisory_xact_lock(hashtextextended(%s,0))',
                 ['territorial-batch:' + str(actor.pk) + ':' + request_id])
        previous = db.one('SELECT "NewData" FROM systeme."T_Audit_Log" '
                          'WHERE "Operation"=%s '
                          'AND "NewData"->>\'requestId\'=%s AND "NewData"#>>\'{_actor,IdUser}\'=%s '
                          'ORDER BY "IdLog" DESC LIMIT 1',
                          [operation, request_id, str(actor.pk)])
        if previous:
            proof = previous['NewData']
            if proof.get('payloadHash') != digest:
                raise APIError('Cette demande a déjà été utilisée avec un autre contenu.', 'REQUEST_CONFLICT', 409)
            return proof['result'], True
        header = _header(kind, body.get('header', {})); prepared = []; issues = {}; seen = {}
        for row in rows:
            row_id = row['rowId']; data = {key: value for key, value in row.items() if key != 'rowId'}
            misplaced = set(data) & set(PARENTS[kind])
            if misplaced:
                issues[row_id] = {key: 'Choisissez ce rattachement dans l’en-tête commun.' for key in misplaced}
                continue
            try:
                with transaction.atomic():
                    data, contacts = territorial_contacts.split(kind, {**data, **header})
                    data = validate_body(kind, data)
                    data = payload(obj, data, actor, creating=True)
                    validate_changed(obj, data, None, actor)
                    identity = _identity(kind, data)
                    field = 'NomNiveau_' + kind[-1]
                    if identity in seen:
                        message = 'La même combinaison nom, code et rattachement apparaît plusieurs fois.'
                        issues.setdefault(row_id, {})[field] = message
                        issues.setdefault(seen[identity], {})[field] = message
                    elif _exists(obj, kind, identity):
                        issues.setdefault(row_id, {})[field] = 'Un enregistrement possède déjà ce nom, ce code et ce rattachement.'
                    seen[identity] = row_id
                    prepared.append((row_id, data, contacts))
            except (APIError, DatabaseError) as error:
                issues[row_id] = _details(error)
        if issues:
            _invalid(rows=issues)
        records = []
        for row_id, data, contacts in prepared:
            try:
                with transaction.atomic():
                    saved = mutate(obj['name'], actor, data)
                    territorial_contacts.save(actor,kind,saved[obj['primaryKey'][0]],contacts)
                    saved = record(actor, kind, saved[obj['primaryKey'][0]])
            except (APIError, DatabaseError) as error:
                _invalid(rows={row_id: _details(error)})
            records.append({'rowId': row_id, 'record': saved})
        result = {'requestId': request_id, 'createdCount': len(records), 'rows': records}
        audit(obj, operation, new={'requestId': request_id, 'payloadHash': digest, 'result': result}, actor=actor)
        return result, False


class TerritorialBatchView(APIView):
    permission_classes = [IsERPAdmin]
    http_method_names = ['post', 'options']

    def post(self, request, kind):
        result, replay = save_batch(request.user, kind, request.data)
        return ok(result, status=200 if replay else 201, meta={'replayed': replay}, message='Saisie enregistrée.')
