"""Processus métier séquentiels, indépendants du circuit général de Support."""

import hashlib
import json
from datetime import date, datetime, time, timedelta
from uuid import UUID

from django.conf import settings
from django.db import IntegrityError, transaction
from django.utils import timezone
from rest_framework.views import APIView

from apps.core import db
from apps.core.field_references import document_reference_actor, reference_options
from apps.core.module_access import can_read_tab, can_use_tab, require_tab
from apps.core.permissions import HasModuleAccess
from apps.core.reference_labels import reference_label_sql
from apps.core.repository import page, set_admin_actor
from apps.core.responses import APIError, ExactEncoder, ok
from apps.core.tenancy import read_entity, require_entity
from apps.support.model_columns import LABELS as MODEL_LABELS
from apps.support.portal import (
    _option_rows, _text, _write_access, capabilities, identifier, record, scope,
)


MODEL_SELECT = f'''
    SELECT m."ID_Modele" AS id, m."IdEntiteFk" AS "entityId", m."Nom" AS name,
           m."ID_TypeSupportFk" AS "typeId", m."Actif" AS active, m."Revision" AS revision,
           v."Numero" AS version, v."Definition" AS definition,
           v."Definition"->>'description' AS description,
           jsonb_array_length(v."Definition"->'stages') AS "stageCount",
           e."NomEntite" AS "entityName",
           {reference_label_sql('g')} AS type
      FROM support."T_ModeleProcessus" m
      JOIN LATERAL (SELECT * FROM support."T_VersionProcessus" v
          WHERE v."ID_ModeleFk"=m."ID_Modele" ORDER BY v."Numero" DESC LIMIT 1) v ON true
      LEFT JOIN referentiel."T_Generique" g ON g."ID_Generique"=m."ID_TypeSupportFk"
      JOIN systeme."T_Entite" e ON e."IdEntite"=m."IdEntiteFk"
'''
MODEL_FIELDS = {
    'name', 'typeId', 'active', 'revision', 'description', 'globalMinutes',
    'reminderMinutes', 'stages', 'requestId',
}
STAGE_FIELDS = {
    'name', 'serviceId', 'roleId', 'responsibleId', 'minutes', 'requiresReceipt',
    'allowReturn', 'requiresDocument', 'requiredInformation', 'validators', 'blockerReasonIds',
    'returnReasonIds', 'rejectReasonIds',
}
SELECTOR_FIELDS = {'userId', 'roleId', 'serviceId'}
REASON_FIELDS = {
    'block': ('blockerReasonIds', 'blockerReasons'),
    'return': ('returnReasonIds', 'returnReasons'),
    'reject': ('rejectReasonIds', 'rejectReasons'),
}
RUN_FIELDS = {
    'start': {'modelId'},
    'receive': set(),
    'advance': {'documentId', 'information'},
    'return': {'reason', 'reasonId', 'targetPosition'},
    'approve': {'reason'},
    'reject': {'reason', 'reasonId'},
    'block': {'reason', 'reasonId'},
    'unblock': {'reason'},
    'assign': {'reason', 'responsibleId'},
}
REASON_ACTIONS = {'return', 'reject', 'block', 'unblock', 'assign'}

MONITOR_SOURCE = '''
    FROM support."V_ParcoursSupport" p
    JOIN support."V_Support" v ON v."ID_Support"=p."ID_SupportFk"
    JOIN support."T_VersionProcessus" process_version ON process_version."ID_Version"=p."ID_VersionFk"
'''
MONITOR_INDICATORS = {
    'active': 'p."TermineLe" IS NULL',
    'late': '(p."EnRetardGlobal" OR p."EnRetardEtape")',
    'blocked': 'p."Blocage" IS NOT NULL',
    'awaitingReceipt': '''p."ID_EtapeCourante" IS NOT NULL AND p."ReceptionLe" IS NULL
        AND COALESCE((process_version."Definition"->'stages'->(p."Position"-1)->>'requiresReceipt')::boolean,false)''',
}


def process_available():
    row = db.one('SELECT to_regclass(%s) IS NOT NULL AS installed', ['support."V_ParcoursSupport"'])
    return bool(row and row['installed'])


def has_run(ticket_id, *, active_only=False):
    if not process_available():
        return False
    return bool(db.one('SELECT 1 FROM support."T_ParcoursSupport" WHERE "ID_SupportFk"=%s'
                       + (' AND "TermineLe" IS NULL' if active_only else ''), [ticket_id]))


def require_processes():
    if not process_available():
        raise APIError('Le suivi des processus doit être installé.', 'SUPPORT_PROCESS_UNAVAILABLE', 503)


def validation_error(message):
    return APIError(message, 'SUPPORT_PROCESS_VALIDATION', 422)


def conflict(message):
    return APIError(message, 'SUPPORT_PROCESS_CONFLICT', 409)


def request_identity(actor, body, resource, entity, *, batch_digest=None):
    try:
        key = str(UUID(str(body.get('requestId'))))
    except (ValueError, TypeError):
        raise validation_error('L’identifiant de la demande est obligatoire.') from None
    canonical = [actor.pk, entity, resource, {k: v for k, v in body.items() if k != 'requestId'}]
    if batch_digest is not None:
        canonical.append(batch_digest)
    digest = hashlib.sha256(json.dumps(
        canonical, cls=ExactEncoder, sort_keys=True, separators=(',', ':'),
    ).encode('utf8')).hexdigest()
    return key, digest


def optional_id(value, label):
    return None if value in (None, '') else identifier(value, label)


def minutes(value, label):
    if value in (None, ''):
        return None
    value = identifier(value, label)
    if value > 525600:
        raise validation_error(f'{label} doit être inférieur ou égal à 525 600 minutes.')
    return value


def boolean(value, label):
    if type(value) is not bool:
        raise validation_error(f'{label} doit être une case cochée ou décochée.')
    return value


def user_choices(actor):
    return _option_rows(actor, 'systeme."T_Utilisateurs"', 'IdUser',
                        """concat_ws(' ',"PrenomUser","NomUser")""", active='ValideUser')


def model_references(actor, current_type=None):
    return {
        'types': reference_options(actor, 'support', 'T_Support', 'ID_TypeSupportFk', current_type),
        'services': reference_options(actor, 'systeme', 'T_Utilisateurs', 'ID_ServiceFk'),
        'roles': reference_options(actor, 'systeme', 'T_Utilisateurs', 'IdRoleFk'),
        'users': user_choices(actor),
        'reasons': reference_options(actor, 'support', 'T_EtapeParcours', 'ID_MotifBlocageFk'),
    }


def allowed_reference(value, choices, label):
    key = optional_id(value, label)
    if key is not None and key not in choices:
        raise validation_error(f'{label} ne fait pas partie des choix actifs de l’entreprise.')
    return key


def prepare_reasons(stage, allowed, index):
    fields = {}
    for field, _ in REASON_FIELDS.values():
        reasons = stage.get(field, [])
        if not isinstance(reasons, list) or len(reasons) > 50:
            raise validation_error(f'Étape {index}. Liste des motifs invalide.')
        reason_ids = [identifier(item, 'Motif') for item in reasons]
        if len(set(reason_ids)) != len(reason_ids) or not set(reason_ids) <= allowed:
            raise validation_error(f'Étape {index}. Choisissez des motifs actifs et distincts.')
        fields[field] = reason_ids
    return fields


def prepare_definition(body, refs):
    names = {field: {item['id'] for item in rows if not item.get('disabled')}
             for field, rows in refs.items()}
    if not isinstance(body.get('stages'), list) or not 1 <= len(body['stages']) <= 30:
        raise validation_error('Le modèle doit comporter entre 1 et 30 étapes.')
    stages = []
    for index, stage in enumerate(body['stages'], 1):
        if not isinstance(stage, dict) or set(stage) - STAGE_FIELDS:
            raise validation_error(f'Étape {index} invalide.')
        validators = stage.get('validators', [])
        if not isinstance(validators, list) or len(validators) > 10:
            raise validation_error(f'Étape {index}. Dix validations maximum.')
        rules = []
        for rule in validators:
            if not isinstance(rule, dict) or set(rule) - SELECTOR_FIELDS:
                raise validation_error(f'Étape {index}. Validation invalide.')
            selectors = {'userId': 'users', 'roleId': 'roles', 'serviceId': 'services'}
            choices = {key: allowed_reference(rule.get(key), names[field], 'Cible de validation')
                       for key, field in selectors.items() if rule.get(key) not in (None, '')}
            if len(choices) != 1:
                raise validation_error(f'Étape {index}. Choisissez une personne, un rôle ou un service par validation.')
            if 'userId' in choices and choices in rules:
                raise validation_error(f'Étape {index}. Chaque validation nominative doit viser une personne différente.')
            rules.append(choices)
        stages.append({
            'name': _text(stage.get('name'), f'Étape {index}', 120, required=True),
            'serviceId': allowed_reference(stage.get('serviceId'), names['services'], 'Service'),
            'roleId': allowed_reference(stage.get('roleId'), names['roles'], 'Rôle'),
            'responsibleId': allowed_reference(stage.get('responsibleId'), names['users'], 'Responsable'),
            'minutes': minutes(stage.get('minutes'), 'Délai de l’étape'),
            'requiresReceipt': boolean(stage.get('requiresReceipt', False), 'Réception'),
            'allowReturn': boolean(stage.get('allowReturn', False), 'Retour'),
            'requiresDocument': boolean(stage.get('requiresDocument', False), 'Pièce justificative'),
            'requiredInformation': _text(stage.get('requiredInformation'), 'Information requise', 1000),
            'validators': rules,
            **prepare_reasons(stage, names['reasons'], index),
        })
    type_id = allowed_reference(body.get('typeId'), names['types'], 'Type de dossier')
    if type_id is None:
        raise validation_error('Choisissez un type de dossier.')
    return type_id, {
        'description': _text(body.get('description'), 'Description', 4000),
        'globalMinutes': minutes(body.get('globalMinutes'), 'Délai global'),
        'reminderMinutes': minutes(body.get('reminderMinutes'), 'Intervalle de relance'),
        'stages': stages,
    }


def model_record(actor, model_id):
    where, params = scope(actor, 'm')
    row = db.one(MODEL_SELECT + ' WHERE m."ID_Modele"=%s AND ' + where,
                 [identifier(model_id, 'Modèle'), *params])
    if row is None:
        raise APIError('Modèle introuvable.', 'SUPPORT_PROCESS_NOT_FOUND', 404)
    definition = row.pop('definition')
    return {**row, **definition}


def can_read_models(actor):
    return (capabilities(actor)['canReadInternal']
            and can_use_tab(actor, 'support', 'processus', 'manage'))


def manage_models(actor):
    if not can_read_models(actor):
        raise APIError('La configuration des modèles est réservée aux gestionnaires.',
                       'SUPPORT_PROCESS_FORBIDDEN', 403)


def unchanged_definition(body, previous):
    stages = body.get('stages')
    if not isinstance(stages, list) or not all(isinstance(stage, dict) for stage in stages):
        return False
    stages = [{**stage, 'requiredInformation': stage.get('requiredInformation') or None} for stage in stages]
    return (stages == previous['stages']
            and (body.get('description') or None) == previous['description']
            and body.get('globalMinutes') == previous['globalMinutes']
            and body.get('reminderMinutes') == previous['reminderMinutes'])


@transaction.atomic
def publish_model(actor, body, model_id=None, *, batch_digest=None, references=None):
    require_tab(actor, 'support', 'processus', 'manage')
    entity = _write_access(actor)
    require_processes()
    if not isinstance(body, dict) or set(body) - MODEL_FIELDS:
        raise validation_error('Modèle de processus invalide.')
    model_id = identifier(model_id, 'Modèle') if model_id is not None else None
    request_id, digest = request_identity(actor, body, model_id, entity, batch_digest=batch_digest)
    db.query('SELECT pg_advisory_xact_lock(hashtextextended(%s,0))',
             [f'support-process-model:{actor.pk}:{request_id}'])
    prior = db.one('''
        SELECT v."ID_ModeleFk" AS id, v."PayloadHash" AS hash, m."IdEntiteFk" AS entity
        FROM support."T_VersionProcessus" v JOIN support."T_ModeleProcessus" m
          ON m."ID_Modele"=v."ID_ModeleFk"
        WHERE v."CreePar"=%s AND v."RequestId"=%s
    ''', [actor.pk, request_id])
    if prior:
        if prior['hash'] != digest or prior['entity'] != entity:
            if batch_digest is not None:
                raise APIError('Cette demande a déjà été utilisée avec un autre contenu.',
                               'SUPPORT_PROCESS_IDEMPOTENCY_CONFLICT', 409)
            raise conflict('Cette demande a déjà été utilisée avec un autre contenu.')
        return model_record(actor, prior['id']), True
    old = None
    if model_id is not None:
        old = db.one('''SELECT * FROM support."T_ModeleProcessus"
                        WHERE "ID_Modele"=%s AND "IdEntiteFk"=%s FOR UPDATE''', [model_id, entity])
        if old is None:
            raise APIError('Modèle introuvable.', 'SUPPORT_PROCESS_NOT_FOUND', 404)
        if str(body.get('revision')) != str(old['Revision']):
            raise conflict('Le modèle a changé. Rechargez-le avant d’enregistrer.')
    name = _text(body.get('name'), 'Nom du modèle', 120, required=True)
    active = boolean(body.get('active', True if old is None else old['Actif']), 'Modèle actif')
    if old and identifier(body.get('typeId'), 'Type de dossier') != old['ID_TypeSupportFk']:
        raise validation_error('Le type d’un modèle publié est fixe. Créez un modèle pour un autre type.')
    previous = model_record(actor, model_id) if old else None
    # Une activation doit rester possible si les références historiques ont été désactivées.
    if previous and unchanged_definition(body, previous):
        type_id = old['ID_TypeSupportFk']
        definition = {key: previous[key] for key in ('description', 'globalMinutes', 'reminderMinutes', 'stages')}
    else:
        refs = references if references is not None else model_references(actor, old['ID_TypeSupportFk'] if old else None)
        type_id, definition = prepare_definition(body, refs)
    set_admin_actor(actor)
    try:
        if old:
            db.query('''UPDATE support."T_ModeleProcessus"
                        SET "Nom"=%s, "Actif"=%s, "Revision"="Revision"+1, "ModifieLe"=clock_timestamp()
                        WHERE "ID_Modele"=%s''', [name, active, model_id])
            version = previous['version'] + 1
        else:
            model_id = db.one('''INSERT INTO support."T_ModeleProcessus"
                ("IdEntiteFk","Nom","ID_TypeSupportFk","Actif","CreePar")
                VALUES (%s,%s,%s,%s,%s) RETURNING "ID_Modele" AS id
            ''', [entity, name, type_id, active, actor.pk])['id']
            version = 1
    except IntegrityError as exc:
        diagnostic = getattr(exc.__cause__, 'diag', None)
        if getattr(diagnostic, 'constraint_name', None) == 'ux_support_modele_nom':
            raise conflict('Cette entreprise possède déjà un modèle portant ce nom.') from None
        raise
    definition['modelName'] = name
    db.query('''INSERT INTO support."T_VersionProcessus"
        ("ID_ModeleFk","Numero","Definition","CreePar","Actif","RequestId","PayloadHash")
        VALUES (%s,%s,%s::jsonb,%s,%s,%s,%s)
    ''', [model_id, version, json.dumps(definition, ensure_ascii=False), actor.pk, active, request_id, digest])
    return model_record(actor, model_id), False


def model_selection(actor, raw, *, extras=()):
    filters = {'q', 'typeId', 'active', 'entityId', 'sortBy', 'sortDir'}
    if set(raw) - (filters | set(extras)):
        raise validation_error('Un filtre des modèles de suivi est inconnu.')
    where, params = scope(actor, 'm')
    clauses = [where]
    for key, column in {'typeId': 'm."ID_TypeSupportFk"', 'entityId': 'm."IdEntiteFk"'}.items():
        if raw.get(key):
            clauses.append(f'{column}=%s')
            params.append(identifier(raw[key]))
    if raw.get('active'):
        if raw['active'] not in {'true', 'false'}:
            raise validation_error('Choisissez un état valide.')
        clauses.append('m."Actif"=%s')
        params.append(raw['active'] == 'true')
    search = raw.get('q', '').strip()
    if len(search) > 300:
        raise validation_error('La recherche est trop longue.')
    if search:
        pattern = '%' + search.replace('\\', '\\\\').replace('%', '\\%').replace('_', '\\_') + '%'
        clauses.append(f'''(m."Nom" ILIKE %s OR {reference_label_sql('g')} ILIKE %s
                            OR v."Definition"->>'description' ILIKE %s OR e."NomEntite" ILIKE %s)''')
        params.extend([pattern] * 4)
    sort, direction = raw.get('sortBy') or 'name', (raw.get('sortDir') or 'asc').lower()
    if sort not in MODEL_LABELS or direction not in {'asc', 'desc'}:
        raise validation_error('Le tri demandé est invalide.')
    sort_field = f'v.{db.ident(sort)}'
    if sort in {'name', 'type', 'entityName', 'description'}:
        sort_field = f'lower({sort_field})'
    order = f'{sort_field} {direction} NULLS LAST, v.id'
    return MODEL_SELECT + ' WHERE ' + ' AND '.join(clauses), params, order, sort, direction


def model_filter_types(actor):
    where, params = scope(actor, 'm')
    return db.query(f'''
        SELECT id, label FROM (
            SELECT DISTINCT g."ID_Generique" AS id, {reference_label_sql('g')} AS label
            FROM support."T_ModeleProcessus" m
            JOIN referentiel."T_Generique" g ON g."ID_Generique"=m."ID_TypeSupportFk"
            WHERE {where}
        ) types
        ORDER BY lower(label), id
    ''', params)


class SupportProcessesView(APIView):
    permission_classes = [HasModuleAccess]

    def get(self, request, pk=None):
        actor = request.user
        manage_models(actor)
        available = process_available()
        if pk is not None:
            require_processes()
            return ok(model_record(actor, pk))
        raw = request.query_params.dict()
        source, params, order, _, _ = model_selection(actor, raw, extras={'take', 'skip'})
        page_params = {}
        rows = []
        if 'take' in raw or 'skip' in raw:
            take, skip = page(raw)
            page_params = {'take': take, 'skip': skip}
        count = 0
        if available:
            query = f'SELECT v.* FROM ({source}) v ORDER BY {order}'
            if page_params:
                count = db.one(f'SELECT count(*) AS count FROM ({source}) v', params)['count']
                rows = db.query(query + ' LIMIT %s OFFSET %s', [*params, take, skip])
            else:
                rows = db.query(query, params)
                count = len(rows)
        items = []
        for row in rows:
            items.append({**row.pop('definition'), **row})
        can_manage = available and capabilities(actor)['canManage']
        return ok({'items': items, 'count': count, **page_params,
                   'references': model_references(actor) if can_manage else {},
                   'filterTypes': model_filter_types(actor) if available else [],
                   'canManage': can_manage, 'available': available,
                   'canExport': available and can_use_tab(actor, 'support', 'processus', 'export')})

    def post(self, request, pk=None):
        if pk is not None:
            raise APIError('Utilisez la modification du modèle.', 'METHOD_NOT_ALLOWED', 405)
        model, replayed = publish_model(request.user, request.data)
        return ok(model, status=200 if replayed else 201, meta={'replayed': replayed})

    def put(self, request, pk=None):
        if pk is None:
            raise APIError('Choisissez le modèle à modifier.', 'METHOD_NOT_ALLOWED', 405)
        model, replayed = publish_model(request.user, request.data, pk)
        return ok(model, meta={'replayed': replayed})


def run_record(ticket_id):
    return db.one('''
        SELECT p."ID_VersionFk" AS "versionId", p."Revision" AS revision,
               p."DemarreLe" AS "startedAt", p."EcheanceGlobale" AS "globalDueAt",
               p."TermineLe" AS "completedAt", v."Numero" AS version,
               v."ID_ModeleFk" AS "modelId", v."Definition" AS definition
        FROM support."T_ParcoursSupport" p JOIN support."T_VersionProcessus" v
          ON v."ID_Version"=p."ID_VersionFk"
        WHERE p."ID_SupportFk"=%s
    ''', [ticket_id])


def steps_and_history(ticket_id):
    steps = db.query(f'''
        SELECT e."ID_Etape" AS id, e."Position" AS position, e."EntreeLe" AS "enteredAt",
               e."Echeance" AS "dueAt", e."ReceptionLe" AS "receivedAt", e."SortieLe" AS "exitedAt",
               e."ID_ResponsableFk" AS "responsibleId", e."ID_ServiceFk" AS "serviceId",
               e."Blocage" AS blockage, e."ID_MotifBlocageFk" AS "blockerReasonId",
               {reference_label_sql('g')} AS service,
               NULLIF(concat_ws(' ', u."PrenomUser", u."NomUser"),'') AS responsible
          FROM support."T_EtapeParcours" e
          JOIN support."T_ParcoursSupport" p ON p."ID_SupportFk"=e."ID_SupportFk"
          LEFT JOIN systeme."T_Utilisateurs" u ON u."IdUser"=e."ID_ResponsableFk"
          LEFT JOIN referentiel."T_Generique" g ON g."ID_Generique"=e."ID_ServiceFk"
            AND referentiel.fn_reference_visible(g."ID_Generique", p."IdEntiteFk")
         WHERE e."ID_SupportFk"=%s ORDER BY e."ID_Etape"
    ''', [ticket_id])
    history = db.query(f'''
        SELECT h."ID_Evenement" AS id, h."ID_EtapeFk" AS "stepId", h."Action" AS action,
               h."AuteurFk" AS "actorId", h."DateEvenement" AS "occurredAt", h."Motif" AS reason,
               h."Donnees" AS data, e."Position" AS position, {reference_label_sql('g')} AS "reasonLabel",
               NULLIF(concat_ws(' ',u."PrenomUser",u."NomUser"),'') AS actor
          FROM support."T_EvenementParcours" h
          JOIN support."T_ParcoursSupport" p ON p."ID_SupportFk"=h."ID_SupportFk"
          LEFT JOIN support."T_EtapeParcours" e ON e."ID_Etape"=h."ID_EtapeFk"
          LEFT JOIN systeme."T_Utilisateurs" u ON u."IdUser"=h."AuteurFk"
          LEFT JOIN referentiel."T_Generique" g ON g."ID_Generique"::text=(h."Donnees"->>'reasonId')
            AND referentiel.fn_reference_visible(g."ID_Generique", p."IdEntiteFk")
         WHERE h."ID_SupportFk"=%s ORDER BY h."ID_Evenement"
    ''', [ticket_id])
    return steps, history


def run_alerts(ticket_id):
    return db.query('''
        SELECT a."ID_Alerte" AS id, a."Type" AS type, a."Occurrence" AS occurrence,
               a."Statut" AS status, a."CreeLe" AS "createdAt", a."TraiteLe" AS "processedAt",
               a."Erreur" AS error, e."Position" AS position
          FROM support."T_AlerteParcours" a
          LEFT JOIN support."T_EtapeParcours" e ON e."ID_Etape"=a."ID_EtapeFk"
         WHERE a."ID_SupportFk"=%s ORDER BY a."ID_Alerte" DESC LIMIT 100
    ''', [ticket_id])


def approvals(events, step_id):
    return [event for event in events if event['stepId'] == step_id and event['action'] == 'approve']


def eligible_slots(actor, stage):
    identities = {'userId': actor.pk, 'roleId': actor.row.get('IdRoleFk'),
                  'serviceId': actor.row.get('ID_ServiceFk')}
    return [index for index, rule in enumerate(stage['validators'])
            if all(identities[key] == value for key, value in rule.items())]


def matched_validations(events):
    """Une personne compte une fois, même si elle couvre plusieurs validations."""
    assignments = {}

    def assign(index, seen):
        for slot in events[index]['data']['eligibleSlots']:
            if slot in seen:
                continue
            seen.add(slot)
            if slot not in assignments or assign(assignments[slot], seen):
                assignments[slot] = index
                return True
        return False

    for index in range(len(events)):
        assign(index, set())
    return len(assignments)


def handles_step(actor, step, stage, manager, entity):
    if step['responsibleId'] is not None:
        return step['responsibleId'] == actor.pk
    role = stage['roleId']
    service = step['serviceId']
    if role is None and service is None:
        return manager
    return (actor.row.get('IdEntiteFk') == entity
            and (role is None or role == actor.row.get('IdRoleFk'))
            and (service is None or service == actor.row.get('ID_ServiceFk')))


def available_actions(actor, ticket, current, stage, events):
    if (current is None or settings.DB_READ_ONLY or read_entity(actor) != ticket['IdEntiteFk']
            or not can_use_tab(actor, 'support', 'processus', 'manage')):
        return []
    if ticket['Archive'] or ticket['ID_StatutFk'] in (
        ticket['CircuitSnapshot']['states']['closed'], ticket['CircuitSnapshot']['states']['resolved'],
    ):
        return []
    manager = capabilities(actor)['canManage']
    entity = ticket['IdEntiteFk']
    handles = handles_step(actor, current, stage, manager, entity)
    actions = ['assign'] if manager else []
    if current['blockage']:
        return actions + (['unblock'] if handles or manager else [])
    if handles:
        actions.append('block')
        if stage['allowReturn'] and current['position'] > 1:
            actions.append('return')
        if stage['requiresReceipt'] and not current['receivedAt']:
            actions.append('receive')
        elif matched_validations(approvals(events, current['id'])) >= len(stage['validators']):
            actions.append('advance')
    slots = eligible_slots(actor, stage) if actor.row.get('IdEntiteFk') == entity else []
    if slots and (not stage['requiresReceipt'] or current['receivedAt']):
        approved = approvals(events, current['id'])
        if not any(event['actorId'] == actor.pk for event in approved):
            if matched_validations([*approved, {'data': {'eligibleSlots': slots}}]) > matched_validations(approved):
                actions.append('approve')
        actions.append('reject')
    return actions


def journey_model_choices(entity_id, type_id=None):
    where = 'm."IdEntiteFk"=%s AND m."Actif"'
    params = [entity_id]
    if type_id is not None:
        where += ' AND m."ID_TypeSupportFk"=%s'
        params.append(type_id)
    return db.query('SELECT id, name, "typeId", version, "stageCount" FROM ('
                    + MODEL_SELECT + ' WHERE ' + where + ') model ORDER BY lower(name), id', params)


def can_start_journey(actor):
    return (capabilities(actor)['canManage']
            and can_use_tab(actor, 'support', 'processus', 'manage'))


def creation_journey_options(actor, current=None):
    can_start = current is None and can_start_journey(actor) and process_available()
    return {'canStartJourneyOnCreate': can_start,
            'journeyModels': journey_model_choices(read_entity(actor)) if can_start else []}


def start_allowed(actor, ticket):
    states = ticket['CircuitSnapshot']['states']
    return (not ticket['Archive'] and ticket['ID_StatutFk'] not in (states['closed'], states['resolved'])
            and read_entity(actor) == ticket['IdEntiteFk'] and can_start_journey(actor))


def run_detail(actor, ticket):
    empty = {'run': None, 'models': [], 'available': False, 'canStart': False}
    if not process_available():
        return empty
    ticket_id = ticket['ID_Support']
    run = run_record(ticket_id)
    if run is None:
        can_start = start_allowed(actor, ticket)
        type_id = ticket['ID_TypeSupportFk']
        return {**empty, 'available': True, 'canStart': can_start,
                'models': journey_model_choices(ticket['IdEntiteFk'], type_id) if can_start and type_id is not None else []}
    stages = run.pop('definition')
    run['modelName'] = stages['modelName']
    stages = stages['stages']
    steps, events = steps_and_history(ticket_id)
    internal = capabilities(actor)['canReadInternal']
    current = next((step for step in steps if step['exitedAt'] is None), None)
    active_stage = stages[current['position'] - 1] if current else None
    actions = available_actions(actor, ticket, current, active_stage, events)
    can_see_evidence = internal or bool(actions)
    now = timezone.now()
    for index, step in enumerate(steps):
        stage = stages[step['position'] - 1]
        duration = int(((step['exitedAt'] or now) - step['enteredAt']).total_seconds())
        step.update({
            'name': stage['name'],
            'requiresReceipt': stage['requiresReceipt'],
            'requiresDocument': stage['requiresDocument'],
            'requiredInformation': stage['requiredInformation'],
            'validationCount': matched_validations(approvals(events, step['id'])),
            'validationRequired': len(stage['validators']),
            'durationSeconds': duration,
            'durationMinutes': duration // 60,
            'transmittedAt': step['enteredAt'] if index > 0 else None,
            'isLast': step['position'] == len(stages),
            'late': bool(step['dueAt'] and step['dueAt'] < (step['exitedAt'] or now)),
        })
        if step['blockage'] and not can_see_evidence:
            step['blockage'] = 'Dossier bloqué'
            step.pop('blockerReasonId')
    visible_reason_fields = {label: active_stage.get(key, []) for action, (key, label) in REASON_FIELDS.items()
                             if action in actions}
    reason_ids = sorted({item for ids in visible_reason_fields.values() for item in ids})
    if reason_ids:
        choices = db.query(f'''
            SELECT "ID_Generique" AS id, {reference_label_sql('g')} AS label
            FROM referentiel."T_Generique" g
            WHERE "ID_Generique"=ANY(%s::integer[])
              AND referentiel.fn_reference_visible("ID_Generique", %s)
            ORDER BY label, id
        ''', [reason_ids, ticket['IdEntiteFk']])
        for label, ids in visible_reason_fields.items():
            current[label] = [item for item in choices if item['id'] in ids]
    document_ids = [event['data'].get('documentId') for event in events
                    if internal or event['actorId'] == actor.pk]
    documents = visible_pieces(actor, ticket_id, sorted({item for item in document_ids if type(item) is int}))
    public_history = []
    for event in events:
        data = event.pop('data')
        if internal or event['actorId'] == actor.pk:
            event.update({key: data[key] for key in ('information', 'reasonId') if key in data})
            if type(data.get('documentId')) is int and data['documentId'] in documents:
                event['documentId'] = data['documentId']
        else:
            event.pop('reason')
            event.pop('reasonLabel')
        public_history.append(event)
    scoped = document_reference_actor(actor, ticket['IdEntiteFk'])
    run.update({
        'current': current, 'steps': steps, 'history': public_history,
        'alerts': run_alerts(ticket_id) if internal else [],
        'actions': [{'key': action, 'requiresReason': action in REASON_ACTIONS} for action in actions],
        'users': user_choices(scoped) if 'assign' in actions else [],
        'returnTargets': [{'position': i, 'name': stage['name']} for i, stage in enumerate(stages, 1)
                          if 'return' in actions and i < current['position']],
    })
    return {**empty, 'available': True, 'run': run}


def write_event(ticket_id, step_id, action, actor, now, reason, data, request_id, digest):
    db.query('''
        INSERT INTO support."T_EvenementParcours"
            ("ID_SupportFk","ID_EtapeFk","Action","AuteurFk","DateEvenement",
             "Motif","Donnees","RequestId","PayloadHash")
        VALUES (%s,%s,%s,%s,%s,%s,%s::jsonb,%s,%s)
    ''', [ticket_id, step_id, action, actor.pk, now, reason,
          json.dumps(data, ensure_ascii=False), request_id, digest])


def due_at(now, duration):
    return now + timedelta(minutes=duration) if duration is not None else None


def insert_step(ticket_id, stages, position, now, blockage=None):
    stage = stages[position - 1]
    row = db.one('''
        INSERT INTO support."T_EtapeParcours"
          ("ID_SupportFk","Position","EntreeLe","Echeance","ID_ResponsableFk","ID_ServiceFk","Blocage")
        SELECT p."ID_SupportFk", %s, %s, %s, u."IdUser", %s, %s
        FROM support."T_ParcoursSupport" p
        LEFT JOIN systeme."T_Utilisateurs" u ON u."IdUser"=%s
          AND u."ValideUser" AND u."IdEntiteFk"=p."IdEntiteFk"
        WHERE p."ID_SupportFk"=%s
        RETURNING "ID_Etape" AS id
    ''', [position, now, due_at(now, stage['minutes']), stage['serviceId'], blockage,
          stage['responsibleId'], ticket_id])
    return row['id']


def start_run(actor, ticket, body, now):
    if not start_allowed(actor, ticket):
        raise APIError('Vous ne pouvez pas démarrer un parcours pour ce dossier.',
                       'SUPPORT_PROCESS_FORBIDDEN', 403)
    model_id = identifier(body.get('modelId'), 'Modèle')
    model = db.one('''
        SELECT m."ID_Modele" AS id FROM support."T_ModeleProcessus" m
        WHERE m."ID_Modele"=%s AND m."IdEntiteFk"=%s AND m."ID_TypeSupportFk"=%s AND m."Actif"
        FOR SHARE
    ''', [model_id, ticket['IdEntiteFk'], ticket['ID_TypeSupportFk']])
    if model is None:
        raise validation_error('Choisissez un modèle actif adapté à ce type de dossier.')
    version = db.one('''
        SELECT "ID_Version" AS id, "Definition" AS definition FROM support."T_VersionProcessus"
        WHERE "ID_ModeleFk"=%s ORDER BY "Numero" DESC LIMIT 1
    ''', [model_id])
    if version is None:
        raise validation_error('Ce modèle ne possède pas de version publiée.')
    ticket_id = ticket['ID_Support']
    definition = version['definition']
    db.query('''
        INSERT INTO support."T_ParcoursSupport"
            ("ID_SupportFk","IdEntiteFk","ID_VersionFk","DemarreLe","EcheanceGlobale")
        VALUES (%s,%s,%s,%s,%s)
    ''', [ticket_id, ticket['IdEntiteFk'], version['id'], now, due_at(now, definition['globalMinutes'])])
    return insert_step(ticket_id, definition['stages'], 1, now)


def visible_pieces(actor, ticket_id, ids):
    if not ids:
        return set()
    rows = db.query('''
        SELECT "ID_PieceFk" AS id FROM support."V_PieceSupport"
        WHERE "ID_SupportFk"=%s AND "ID_PieceFk"=ANY(%s::bigint[]) AND NOT "Archive"
          AND (%s OR "Visibilite"='public')
    ''', [ticket_id, ids, capabilities(actor)['canReadInternal']])
    return {row['id'] for row in rows}


def document_evidence(actor, ticket_id, value, required):
    piece_id = optional_id(value, 'Pièce justificative')
    if piece_id is None:
        if required:
            raise validation_error('Choisissez une pièce du dossier avant de transmettre.')
        return None
    if piece_id not in visible_pieces(actor, ticket_id, [piece_id]):
        raise validation_error('Choisissez une pièce active de ce dossier.')
    return piece_id


def end_step(current, now):
    db.query('UPDATE support."T_EtapeParcours" SET "SortieLe"=%s WHERE "ID_Etape"=%s',
             [now, current['id']])


def selected_reason(actor, stage, action, raw):
    reason_id = optional_id(raw, 'Motif')
    field, _ = REASON_FIELDS[action]
    choices = stage.get(field, [])
    if (choices and reason_id not in choices) or (not choices and reason_id is not None):
        raise validation_error('Choisissez un motif prévu pour cette action.')
    if reason_id is not None and not db.one(
        'SELECT 1 WHERE referentiel.fn_reference_visible(%s, %s)', [reason_id, read_entity(actor)],
    ):
        raise validation_error('Ce motif n’est plus disponible pour cette entreprise.')
    return reason_id


def advance_run(actor, ticket_id, run, current, stage, action, body, reason, now):
    step_id = current['id']
    stages = run['definition']['stages']
    position = current['position']
    reason_id = selected_reason(actor, stage, action, body.get('reasonId')) if action in REASON_FIELDS else None
    if action == 'receive':
        db.query('UPDATE support."T_EtapeParcours" SET "ReceptionLe"=%s WHERE "ID_Etape"=%s',
                 [now, step_id])
    elif action == 'assign':
        responsible = optional_id(body.get('responsibleId'), 'Responsable')
        users = {row['id'] for row in user_choices(actor)}
        if responsible is not None and responsible not in users:
            raise validation_error('Choisissez un utilisateur actif de cette entreprise.')
        if responsible == current['responsibleId']:
            raise validation_error('Choisissez une nouvelle affectation.')
        db.query('UPDATE support."T_EtapeParcours" SET "ID_ResponsableFk"=%s WHERE "ID_Etape"=%s',
                 [responsible, step_id])
        return {'responsibleId': responsible}
    elif action == 'approve':
        return {'eligibleSlots': eligible_slots(actor, stage)}
    elif action == 'block':
        db.query('''UPDATE support."T_EtapeParcours" SET "Blocage"=%s,"ID_MotifBlocageFk"=%s
                    WHERE "ID_Etape"=%s''', [reason, reason_id, step_id])
        return {'reasonId': reason_id}
    elif action == 'unblock':
        db.query('''UPDATE support."T_EtapeParcours" SET "Blocage"=NULL,"ID_MotifBlocageFk"=NULL
                    WHERE "ID_Etape"=%s''', [step_id])
    elif action == 'reject':
        end_step(current, now)
        target = position - 1 if stage['allowReturn'] and position > 1 else position
        return {'targetStepId': insert_step(ticket_id, stages, target, now,
                                            reason if target == position else None),
                'reasonId': reason_id}
    elif action == 'return':
        target = identifier(body.get('targetPosition'), 'Étape de retour')
        if target >= position:
            raise validation_error('Choisissez une étape précédente.')
        end_step(current, now)
        return {'targetStepId': insert_step(ticket_id, stages, target, now), 'reasonId': reason_id}
    elif action == 'advance':
        info = _text(body.get('information'), 'Information requise', 4000,
                     required=bool(stage['requiredInformation']))
        piece = document_evidence(actor, ticket_id, body.get('documentId'), stage['requiresDocument'])
        end_step(current, now)
        payload = {'information': info, 'documentId': piece}
        if position < len(stages):
            payload['targetStepId'] = insert_step(ticket_id, stages, position + 1, now)
        return payload
    return {}


@transaction.atomic
def mutate_run(actor, pk, body):
    require_tab(actor, 'support', 'tickets')
    require_tab(actor, 'support', 'processus', 'manage')
    db.ensure_writable()
    require_processes()
    if not isinstance(body, dict) or not isinstance(body.get('action'), str):
        raise validation_error('Action du parcours invalide.')
    action = body['action']
    if action not in RUN_FIELDS or set(body) - RUN_FIELDS[action] - {'action', 'requestId', 'revision'}:
        raise validation_error('Action du parcours invalide.')
    # Le verrou de ce parent sérialise toutes les transitions et les écritures Support historiques.
    ticket = record(actor, pk, lock=True)
    entity = require_entity(actor)
    if entity != ticket['IdEntiteFk']:
        raise APIError('Choisissez l’entreprise du dossier.', 'SUPPORT_ENTITY_MISMATCH', 403)
    ticket_id = ticket['ID_Support']
    request_id, digest = request_identity(actor, body, ticket_id, entity)
    previous = db.one('''
        SELECT "AuteurFk" AS actor, "PayloadHash" AS hash FROM support."T_EvenementParcours"
        WHERE "ID_SupportFk"=%s AND "RequestId"=%s
    ''', [ticket_id, request_id])
    if previous:
        if previous['hash'] != digest or previous['actor'] != actor.pk:
            raise conflict('Cette demande a déjà été utilisée avec un autre contenu.')
        return run_detail(actor, ticket), True
    set_admin_actor(actor)
    run = run_record(ticket_id)
    now = timezone.now()
    reason = _text(body.get('reason'), 'Motif', 2000, required=action in REASON_ACTIONS)
    if action == 'start':
        if run is not None:
            raise conflict('Un parcours existe déjà pour ce dossier.')
        step_id = start_run(actor, ticket, body, now)
        data = {}
    else:
        if run is None or run['completedAt']:
            raise conflict('Ce dossier ne comporte pas de parcours en cours.')
        if str(body.get('revision')) != str(run['revision']):
            raise conflict('Le parcours a changé. Rechargez la fiche.')
        steps, events = steps_and_history(ticket_id)
        current = next((step for step in steps if step['exitedAt'] is None), None)
        if current is None:
            raise conflict('Le parcours en cours ne comporte aucune étape active.')
        stage = run['definition']['stages'][current['position'] - 1]
        if action not in available_actions(actor, ticket, current, stage, events):
            raise APIError('Votre rôle ou l’état de l’étape ne permet pas cette action.',
                           'SUPPORT_PROCESS_FORBIDDEN', 403)
        step_id = current['id']
        data = advance_run(actor, ticket_id, run, current, stage, action, body, reason, now)
        completed = action == 'advance' and 'targetStepId' not in data
        db.query('''UPDATE support."T_ParcoursSupport" SET "Revision"="Revision"+1,"TermineLe"=%s
                    WHERE "ID_SupportFk"=%s''', [now if completed else None, ticket_id])
    write_event(ticket_id, step_id, action, actor, now, reason, data, request_id, digest)
    return run_detail(actor, ticket), False


class SupportProcessRunView(APIView):
    permission_classes = [HasModuleAccess]

    def get(self, request, pk):
        require_tab(request.user, 'support', 'processus')
        return ok(run_detail(request.user, record(request.user, pk)))

    def post(self, request, pk):
        result, replayed = mutate_run(request.user, pk, request.data)
        return ok(result, meta={'replayed': replayed})


def monitoring_filters(actor, raw):
    selectors = {
        'typeId': 'v."ID_TypeSupportFk"', 'status': 'v."ID_StatutFk"',
        'serviceId': 'p."ID_ServiceFk"', 'responsibleId': 'p."ID_ResponsableFk"',
        'entityId': 'v."IdEntiteFk"',
    }
    flags = {'late', 'blocked'}
    if set(raw) - (selectors.keys() | flags | {'q', 'stage', 'dateFrom', 'dateTo', 'take', 'skip', 'indicator'}):
        raise validation_error('Un filtre de suivi est inconnu.')
    predicate, params = scope(actor)
    clauses = [predicate, 'NOT v."Archive"']
    indicator = raw.get('indicator')
    if indicator:
        if indicator not in MONITOR_INDICATORS:
            raise validation_error('Indicateur de suivi inconnu.')
        clauses.append(f'({MONITOR_INDICATORS[indicator]})')
    for key, column in selectors.items():
        if raw.get(key):
            clauses.append(f'{column}=%s')
            params.append(identifier(raw[key]))
    for key in ('late', 'blocked'):
        if raw.get(key):
            if raw[key] not in ('true', 'false'):
                raise validation_error('Un filtre Oui/Non est invalide.')
            clauses.append(f'({MONITOR_INDICATORS[key]})=%s')
            params.append(raw[key] == 'true')
    search = str(raw.get('q', '')).strip()
    stage = str(raw.get('stage', '')).strip()
    if len(search) > 300 or len(stage) > 120:
        raise validation_error('La recherche est trop longue.')
    if search:
        clauses.append('(v."NumeroSupport" ILIKE %s OR v."Objet" ILIKE %s OR process_version."Definition"->>\'modelName\' ILIKE %s)')
        params.extend([f'%{search}%'] * 3)
    if stage:
        clauses.append('p."NomEtape" ILIKE %s')
        params.append(f'%{stage}%')
    for key, operator in [('dateFrom', '>='), ('dateTo', '<')]:
        if raw.get(key):
            try:
                day = date.fromisoformat(raw[key]) + timedelta(days=int(key == 'dateTo'))
                stamp = timezone.make_aware(datetime.combine(day, time.min))
            except (ValueError, OverflowError):
                raise validation_error('La période est invalide.') from None
            clauses.append(f'p."DemarreLe"{operator}%s')
            params.append(stamp)
    return ' AND '.join(clauses), params


def monitoring_totals(where, params):
    counts = ', '.join(f'count(*) FILTER (WHERE {predicate}) AS {db.ident(key)}'
                       for key, predicate in MONITOR_INDICATORS.items())
    return db.one(f'SELECT count(*) AS count, {counts} {MONITOR_SOURCE} WHERE {where}', params)


def dashboard_metrics(actor):
    if not can_read_tab(actor, 'support', 'tickets') or not can_read_tab(actor, 'support', 'processus'):
        return None
    if not process_available():
        return None
    totals = monitoring_totals(*monitoring_filters(actor, {}))
    totals.pop('count')
    return totals


def monitoring(actor, raw):
    require_tab(actor, 'support', 'tickets')
    require_tab(actor, 'support', 'processus')
    where, params = monitoring_filters(actor, raw)
    take, skip = page(raw)
    empty = {'items': [], 'count': 0, 'take': take, 'skip': skip, 'available': False,
             'metrics': dict.fromkeys(MONITOR_INDICATORS, 0),
             'references': {}, 'canReadModels': can_read_models(actor)}
    if not process_available():
        return empty
    totals = monitoring_totals(where, params)
    can_read_internal = capabilities(actor)['canReadInternal']
    items = db.query(f'''
        SELECT v."ID_Support" AS "ticketId", v."NumeroSupport" AS number, v."Objet" AS subject,
               v."Statut" AS status, v."ID_StatutFk" AS "statusId",
               v."ID_TypeSupportFk" AS "typeId", v."TypeSupport" AS type,
               process_version."Definition"->>'modelName' AS "modelName", p."Position" AS position,
               p."NomEtape" AS "stageName", {reference_label_sql('g')} AS service,
               NULLIF(concat_ws(' ',u."PrenomUser",u."NomUser"),'') AS responsible,
               p."EntreeLe" AS "enteredAt", p."EcheanceEtape" AS "dueAt",
               p."EcheanceGlobale" AS "globalDueAt", p."TermineLe" AS "completedAt",
               CASE WHEN %s THEN p."Blocage" WHEN p."Blocage" IS NOT NULL THEN 'Dossier bloqué' END AS blockage,
               {MONITOR_INDICATORS['late']} AS late,
               v."IdEntiteFk" AS "entityId", v."Entreprise" AS entity
        {MONITOR_SOURCE}
        LEFT JOIN referentiel."T_Generique" g ON g."ID_Generique"=p."ID_ServiceFk"
        LEFT JOIN systeme."T_Utilisateurs" u ON u."IdUser"=p."ID_ResponsableFk"
        WHERE {where}
        ORDER BY (p."TermineLe" IS NOT NULL), late DESC, p."DemarreLe" DESC, v."ID_Support" DESC
        LIMIT %s OFFSET %s
    ''', [can_read_internal, *params, take, skip])
    references = {
        'types': reference_options(actor, 'support', 'T_Support', 'ID_TypeSupportFk'),
        'statuses': reference_options(actor, 'support', 'T_Support', 'ID_StatutFk'),
        'services': reference_options(actor, 'systeme', 'T_Utilisateurs', 'ID_ServiceFk'),
        'users': user_choices(actor) if read_entity(actor) else [],
    }
    return {**empty, 'items': items, 'count': totals.pop('count'), 'metrics': totals,
            'available': True, 'references': references}


class SupportProcessMonitoringView(APIView):
    permission_classes = [HasModuleAccess]

    def get(self, request):
        return ok(monitoring(request.user, request.query_params.dict()))
