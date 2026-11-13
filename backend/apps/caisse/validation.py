"""Politique de validation et préparation transactionnelle des écritures."""
import re
import uuid
from decimal import Decimal

from django.db import transaction

from apps.core import db
from apps.core.module_access import can_use_tab, require_tab
from apps.core.repository import positive
from apps.core.responses import APIError
from apps.core.tenancy import require_entity

from . import services


CREATE = 'saisie-ecritures'
EDIT = 'modification-brouillons'
VALIDATE = 'validation-ecritures'
CONFIGURE = 'parametres-validation'
MODES = {'MANUAL', 'OTHER_AGENT', 'AUTO'}
MAX_SELECTION = 200


def lock_policy(entity, *, exclusive=False):
    lock = 'pg_advisory_xact_lock' if exclusive else 'pg_advisory_xact_lock_shared'
    db.query(f'SELECT {lock}(hashtextextended(%s,0))', [f'caisse-validation-policy:{entity}'])


def policy(entity):
    row = db.one('''SELECT "ModeValidation", "IdsValidateurs", "Revision", "AutoriseValidationImmediateHistorique"
        FROM operations."T_ParametreValidationCaisse" WHERE "IdEntiteFk" = %s''', [entity])
    return {
        'mode': row['ModeValidation'] if row else 'MANUAL',
        'validatorIds': row['IdsValidateurs'] if row else [],
        '_version': str(row['Revision']) if row else '0',
        'allowLegacyImmediate': bool(row and row['AutoriseValidationImmediateHistorique']),
    }


def settlement_policy_error(actor, entity):
    config = policy(entity)
    if config['mode'] == 'OTHER_AGENT':
        return ('CAISSE_SETTLEMENT_REQUIRES_OTHER_AGENT',
                'Enregistrez le règlement sans liaison Caisse, puis saisissez l’écriture de caisse pour la faire valider par un autre agent.')
    if config['mode'] == 'MANUAL' and config['validatorIds'] and actor.pk not in config['validatorIds']:
        return ('CAISSE_SETTLEMENT_REQUIRES_DESIGNATED_AGENT',
                'Seul un validateur désigné peut enregistrer un règlement lié à la Caisse.')
    return None


def can_validate(actor):
    return actor.admin and can_use_tab(actor, 'caisse', 'ecritures', 'manage') and can_use_tab(actor, 'caisse', VALIDATE, 'manage')


def eligible_validators(entity):
    from apps.accounts.authentication import Actor

    candidates = db.query('''SELECT u."IdUser", u."IdEntiteFk", u."Is_Admin", u."Is_staff",
            u."IdRoleFk", g."NomGenerique" "RoleName",
            concat_ws(' ', nullif(btrim(u."PrenomUser"), ''), nullif(btrim(u."NomUser"), '')) label
        FROM systeme."T_Utilisateurs" u
        LEFT JOIN referentiel."T_Generique" g ON g."ID_Generique" = u."IdRoleFk"
        WHERE u."IdEntiteFk" = %s AND u."ValideUser" IS TRUE ORDER BY label, u."IdUser"''', [entity])
    return [{'id': row['IdUser'], 'label': row['label'] or f"Utilisateur {row['IdUser']}"}
            for row in candidates if can_validate(Actor(row))]


def configuration(actor):
    require_tab(actor, 'caisse', CONFIGURE)
    entity = require_entity(actor)
    manage = services.capabilities(actor)['canConfigureValidation']
    return {**policy(entity), 'eligibleValidators': eligible_validators(entity) if manage else [], 'canManage': manage}


@transaction.atomic
def configure(actor, body):
    entity = services.writable(actor, CONFIGURE)
    if not isinstance(body, dict) or set(body) != {'mode', 'validatorIds', '_version', 'requestId', 'motif'}:
        services.fail('Vérifiez les paramètres de validation.')
    mode, validators = body['mode'], body['validatorIds']
    if not isinstance(mode, str) or mode not in MODES:
        services.fail('Choisissez un mode de validation.', 'mode')
    if not isinstance(validators, list) or len(validators) > 100 or any(type(value) is not int or not 0 < value <= 2147483647 for value in validators) or len(set(validators)) != len(validators):
        services.fail('Choisissez des agents distincts et admissibles.', 'validatorIds')
    if mode == 'OTHER_AGENT' and not validators:
        services.fail('Désignez au moins un agent habilité à valider.', 'validatorIds')
    request_id, digest, motif = services.envelope(actor, {
        'requestId': body['requestId'], 'motif': body['motif'],
        '_version': body['_version'], 'data': {'mode': mode, 'validatorIds': sorted(validators)},
    }, 'configure-validation', entity, require_motif=True)
    services.request_lock(actor, request_id, digest, motif)
    lock_policy(entity, exclusive=True)
    proof = db.one('''SELECT "NewData" proof FROM systeme."T_Audit_Log"
        WHERE "TableName" = 'operations.T_ParametreValidationCaisse' AND "NewData"->>'_requestId' = %s
        ORDER BY "IdLog" DESC LIMIT 1''', [request_id])
    if proof:
        data = proof['proof']
        if data.get('_payloadHash') != digest or data.get('IdEntiteFk') != entity:
            services.fail('Cette demande a déjà été utilisée avec un autre contenu.', code='IDEMPOTENCY_CONFLICT', status=409)
        return configuration(actor)
    version = body['_version']
    if not isinstance(version, str) or version != policy(entity)['_version']:
        services.fail('Ces paramètres ont changé. Rechargez-les.', code='STALE_REVISION', status=409)
    if not set(validators) <= {item['id'] for item in eligible_validators(entity)}:
        services.fail('Un agent sélectionné ne dispose plus du droit de validation dans cette entreprise.', 'validatorIds')
    if not validators and db.one('''SELECT 1 FROM operations."T_Paiement"
        WHERE "IdEntiteFk" = %s AND "EtatEcriture" = 'DRAFT' AND "ValidePaiement" IS TRUE
          AND "ValidationDesigneeRequise" IS TRUE LIMIT 1''', [entity]):
        services.fail('Conservez au moins un agent pour les brouillons qui nécessitent une validation désignée.', 'validatorIds')
    db.query('''INSERT INTO operations."T_ParametreValidationCaisse" ("IdEntiteFk", "ModeValidation", "IdsValidateurs")
        VALUES (%s, %s, %s) ON CONFLICT ("IdEntiteFk") DO UPDATE
        SET "ModeValidation" = EXCLUDED."ModeValidation", "IdsValidateurs" = EXCLUDED."IdsValidateurs"
        RETURNING "Revision"''', [entity, mode, sorted(validators)])
    return configuration(actor)


def permission_reason(actor, row, validators):
    if row['EtatEcriture'] != 'DRAFT' or not row['ValidePaiement']:
        return 'Cette écriture n’est plus un brouillon actif.'
    if row.get('ModeValidation') == 'AUTO':
        return 'Cette écriture relève de la validation automatique à la création.'
    if row.get('ModeValidation') == 'OTHER_AGENT' and row['IdUserFk'] == actor.pk:
        return 'Un autre agent doit valider cette écriture.'
    if row.get('ValidationDesigneeRequise') and actor.pk not in validators:
        return 'Vous ne faites pas partie des agents désignés pour cette écriture.'
    return None


def selection(body, *, confirm=False):
    fields = {'rows', 'requestId', 'motif'} if confirm else {'rows'}
    if not isinstance(body, dict) or set(body) != fields:
        services.fail('Vérifiez la sélection des écritures.')
    rows = body['rows']
    if not isinstance(rows, list) or not 1 <= len(rows) <= MAX_SELECTION:
        services.fail(f'Sélectionnez de 1 à {MAX_SELECTION} écritures.')
    selected = {}
    for item in rows:
        if not isinstance(item, dict) or set(item) != {'id', '_version'}:
            services.fail('Une ligne de la sélection est invalide.')
        raw_id = item['id']
        pk = positive(raw_id)
        version = item['_version']
        if pk in selected or not isinstance(version, str) or not re.fullmatch(r'[1-9][0-9]{0,18}', version):
            services.fail('La sélection contient une ligne en double ou une version invalide.')
        selected[pk] = version
    return dict(sorted(selected.items()))


def inspection(actor, entity, selected, *, lock=False):
    if lock:
        db.query('''SELECT "IdPaiement" FROM operations."T_Paiement"
            WHERE "IdEntiteFk" = %s AND "IdPaiement" = ANY(%s)
            ORDER BY "IdPaiement" FOR UPDATE''', [entity, list(selected)])
        db.query('''SELECT c."IdCaisse" FROM operations."T_Caisse" c
            WHERE c."IdEntiteFk" = %s AND EXISTS (
                SELECT 1 FROM operations."T_Paiement" p WHERE p."IdCaisseFk" = c."IdCaisse"
                AND p."IdEntiteFk" = c."IdEntiteFk" AND p."IdPaiement" = ANY(%s))
            ORDER BY c."IdCaisse" FOR UPDATE''', [entity, list(selected)])
    rows = db.query('''SELECT p."IdPaiement", p."IdCaisseFk", p."IdDeviseFk", p."CodePaiement",
            p."Revision", p."EtatEcriture", p."ValidePaiement", p."ModeValidation", p."ValidationDesigneeRequise",
            p."IdUserFk", p."DatePaiement", p."SensMouvement", p."MontantPaiement",
            c."Actif", c."DeviseCode", c."MontantCaisse", c."DerniereClotureLe",
            operations.fn_caisse_actor(p."IdUserFk", p."IdEntiteFk") "AuteurAdmissible",
            (p."IdPayeurFk" IS NULL OR operations.fn_caisse_actor(p."IdPayeurFk", p."IdEntiteFk")) "PayeurAdmissible",
            (p."IdTypeMouvementFk" IS NULL OR operations.fn_caisse_sens_type(p."IdTypeMouvementFk")
                IS NOT DISTINCT FROM p."SensMouvement") "SensAdmissible"
        FROM operations."T_Paiement" p
        JOIN operations."V_Caisse" c ON c."IdCaisse" = p."IdCaisseFk" AND c."IdEntiteFk" = p."IdEntiteFk"
        WHERE p."IdEntiteFk" = %s AND p."IdPaiement" = ANY(%s)''', [entity, list(selected)])
    by_id = {row['IdPaiement']: row for row in rows}
    validators = set(policy(entity)['validatorIds'])
    if lock:
        refresh_validator(actor, entity)
    totals = {}
    results = {}
    for pk, version in selected.items():
        row = by_id.get(pk)
        reason = 'Cette écriture est introuvable dans cette entreprise.'
        if row:
            reason = row_reason(actor, row, version, validators)
            currency = row['IdDeviseFk']
            total = totals.setdefault(currency, {'currencyId': currency, 'currency': row['DeviseCode'],
                                                   'entries': Decimal(0), 'exits': Decimal(0)})
            total['entries' if row['SensMouvement'] == 1 else 'exits'] += row['MontantPaiement']
        results[pk] = {'id': pk, 'code': row['CodePaiement'] if row else None, 'eligible': not reason, 'reason': reason}

    # Dans chaque caisse, les entrées de la sélection financent les sorties.
    # L’ordre est stable entre l’aperçu et l’exécution, à révisions identiques.
    ordered = sorted(rows, key=lambda row: (row['IdCaisseFk'], -row['SensMouvement'], row['DatePaiement'], row['IdPaiement']))
    balances = {}
    for row in ordered:
        result = results[row['IdPaiement']]
        if result['reason']:
            continue
        cash = row['IdCaisseFk']
        balance = balances.setdefault(cash, row['MontantCaisse'])
        updated = balance + row['MontantPaiement'] * row['SensMouvement']
        if updated < 0:
            result.update(eligible=False, reason='Le solde de la caisse est insuffisant pour cette sortie.')
        elif updated > Decimal('9999999999999999.99'):
            result.update(eligible=False, reason='Cette entrée dépasserait le montant maximal de la caisse.')
        else:
            balances[cash] = updated
    return {'count': len(selected), 'totals': list(totals.values()), 'rows': list(results.values())}, ordered


def refresh_validator(actor, entity):
    from apps.accounts.authentication import actor_by_id

    actor.row = actor_by_id(actor.pk).row
    actor.__dict__.pop('_module_access', None)
    if not actor.admin or (not actor.global_admin and actor.row.get('IdEntiteFk') != entity):
        services.fail('Votre accès à cette entreprise a changé. Rechargez la page.', code='CAISSE_FORBIDDEN', status=403)
    require_tab(actor, 'caisse', 'ecritures', 'manage')
    require_tab(actor, 'caisse', VALIDATE, 'manage')


def row_reason(actor, row, version, validators):
    if str(row['Revision']) != version:
        return 'Cette écriture a changé depuis son affichage. Actualisez le journal.'
    if not row['Actif']:
        return 'Cette caisse est désactivée.'
    if not row['AuteurAdmissible']:
        return 'L’auteur de l’écriture n’est plus actif dans cette entreprise.'
    if not row['PayeurAdmissible']:
        return 'Le payeur n’est plus actif dans cette entreprise.'
    if not row['SensAdmissible']:
        return 'Le type de mouvement ne correspond plus au sens de cette écriture.'
    if row['DerniereClotureLe'] and row['DatePaiement'] <= row['DerniereClotureLe']:
        return 'L’écriture appartient à une période clôturée.'
    return permission_reason(actor, row, validators)


@transaction.atomic
def preview(actor, body):
    entity = services.writable(actor, VALIDATE)
    require_tab(actor, 'caisse', 'ecritures', 'manage')
    lock_policy(entity)
    return inspection(actor, entity, selection(body))[0]


@transaction.atomic
def confirm(actor, body):
    entity = services.writable(actor, VALIDATE)
    require_tab(actor, 'caisse', 'ecritures', 'manage')
    selected = selection(body, confirm=True)
    request_id, digest, motif = services.envelope(actor, {
        'requestId': body['requestId'], 'motif': body['motif'],
        'data': {'rows': list(selected.items())},
    }, 'validate-selection', entity, require_motif=True)
    services.request_lock(actor, request_id, digest, motif)
    lock_policy(entity)
    found = services.replay('ecritures', request_id, digest, 'ValidationRequestId')
    if found:
        return {'count': len(selected), 'ids': list(selected), 'replayed': True}
    review, ordered = inspection(actor, entity, selected, lock=True)
    if any(not row['eligible'] for row in review['rows']):
        raise APIError({'message': 'Corrigez la sélection avant de valider. Aucune écriture n’a été validée.',
                        'rows': review['rows']}, 'CAISSE_VALIDATION_SELECTION', 409)
    for index, row in enumerate(ordered):
        pk = row['IdPaiement']
        line_request = request_id if index == 0 else str(uuid.uuid5(uuid.UUID(request_id), f'validation-caisse:{pk}'))
        services.set_request_metadata(actor, line_request, digest, motif)
        services.sql_action('valider', pk, actor, motif, line_request, digest, int(selected[pk]))
    return {'count': len(selected), 'ids': list(selected), 'replayed': False}
