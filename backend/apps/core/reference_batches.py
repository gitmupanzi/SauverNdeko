"""Nomenclatures communes ou privées, saisie groupée sans écriture partielle.

Les tableaux persistés, leurs clés et gardes SQL restent l'autorité. Une demande
groupée réutilise la mutation individuelle et son audit dans la même transaction.
"""
import hashlib
import json
import unicodedata
import uuid

from django.db import DatabaseError, transaction
from rest_framework.views import APIView

from . import db
from .permissions import IsERPAdmin
from .responses import APIError, ExactEncoder, ok
from .tenancy import read_entity

TABLES = {'categories': 'T_CategorieGenerique', 'valeurs': 'T_Generique'}
NAMES = {'T_CategorieGenerique': 'NomCategorieGenerique', 'T_Generique': 'NomGenerique'}
PRIMARY = {'T_CategorieGenerique': 'ID_CategorieGenerique', 'T_Generique': 'ID_Generique'}
VISIBILITY = {'VisibleNiveau_2', 'VisibleNiveau_3', 'VisibleNiveau_4', 'VisibleNiveau_5',
              'VisibleArticle', 'VisibleCmd', 'VisibleFacture', 'VisibleUsers', 'VisibleVoie', 'VisibleAll'}
FIELDS = {
    'T_CategorieGenerique': {'NomCategorieGenerique', 'ModuleCategorieGenerique', 'ValideCategorieGenerique'},
    'T_Generique': {'NomGenerique', 'AbrGenerique', 'ObsGenerique', 'ValideGenerique'} | VISIBILITY,
}
LIMITS = {'NomCategorieGenerique': 255, 'NomGenerique': 255, 'AbrGenerique': 255,
          'ModuleCategorieGenerique': 4000, 'ObsGenerique': 20000}


def is_reference(obj):
    return obj['schema'] == 'referentiel' and obj['name'] in NAMES


def management_rights(actor):
    from django.conf import settings
    from .module_access import access_snapshot
    available = access_snapshot(actor)['modules'].values()
    return bool(actor.admin and not settings.DB_READ_ONLY and any(item.get('canManage') for item in available))


def writable_owner(actor, owner):
    """Un gestionnaire d'entreprise ne peut modifier aucune ligne commune."""
    from .repository import positive
    if owner is not None:
        owner = positive(owner, 'Entreprise')
    if not management_rights(actor):
        raise APIError('Votre rôle ne permet pas de gérer ces références.', 'MODULE_ACTION_FORBIDDEN', 403)
    if not actor.global_admin and (owner is None or owner != read_entity(actor)):
        raise APIError('Seules les références de votre entreprise peuvent être modifiées.', 'REFERENCE_OWNER_FORBIDDEN', 403)
    if owner is not None:
        found = db.one('SELECT "ValideEntite" FROM systeme."T_Entite" WHERE "IdEntite"=%s', [owner])
        if not found:
            raise APIError('Entreprise introuvable.', 'NOT_FOUND', 404)
        if found['ValideEntite'] is False:
            raise APIError('Les références de cette entreprise sont en consultation.', 'ENTITY_INACTIVE', 409)
    return owner


def prepare_body(obj, body, old, actor):
    """Propriété explicite à la création et immuable, même pour la plateforme."""
    result = dict(body or {})
    if old is not None:
        owner = old.get('IdEntiteFk')
        writable_owner(actor, owner)
        from .repository import positive
        given_owner = positive(result['IdEntiteFk'], 'Entreprise') if result.get('IdEntiteFk') is not None else None
        if 'IdEntiteFk' in result and given_owner != owner:
            raise APIError({'IdEntiteFk': 'La portée initiale de cette référence est conservée.'}, 'REFERENCE_OWNER_IMMUTABLE', 409)
        result.pop('IdEntiteFk', None)
    else:
        owner = result.get('IdEntiteFk', None if actor.global_admin else read_entity(actor))
        result['IdEntiteFk'] = writable_owner(actor, owner)
    return result


def duplicate_issues(obj, data, old=None):
    """Messages ciblés avant la garde SQL concurrente ; aucun détail d'un tiers."""
    table = obj['name']; effective = {**(old or {}), **data}
    owner = effective.get('IdEntiteFk')
    keys = [NAMES[table]] + (['AbrGenerique'] if table == 'T_Generique' else [])
    errors = {}
    parent_changed = table == 'T_Generique' and (old is None or effective.get('ID_CategorieGeneriqueFk') != old.get('ID_CategorieGeneriqueFk'))
    for key in keys:
        if old is not None and not parent_changed and effective.get(key) == old.get(key):
            continue
        value = effective.get(key)
        if not value or not str(value).strip():
            continue
        clauses = ['referentiel.fn_normaliser_libelle(v.' + db.ident(key) + ')=referentiel.fn_normaliser_libelle(%s)']
        args = [value]
        if owner is not None:
            clauses.append('(v."IdEntiteFk" IS NULL OR v."IdEntiteFk"=%s)'); args.append(owner)
        if table == 'T_Generique':
            clauses.append('v."ID_CategorieGeneriqueFk"=%s'); args.append(effective.get('ID_CategorieGeneriqueFk'))
        if old is not None:
            clauses.append('v.' + db.ident(PRIMARY[table]) + '<>%s'); args.append(old[PRIMARY[table]])
        found = db.one('SELECT 1 AS found FROM referentiel.' + db.ident(table) + ' v WHERE ' + ' AND '.join(clauses) + ' LIMIT 1', args)
        if found:
            errors[key] = 'Ce code existe déjà pour cette catégorie et cette portée.' if key == 'AbrGenerique' else 'Ce libellé existe déjà dans cette portée.'
    return errors


def validate_mutation(obj, data, old, actor):
    if not is_reference(obj):
        return
    table = obj['name']; effective = {**(old or {}), **data}; errors = {}
    name = NAMES[table]
    for key in FIELDS[table]:
        if key not in data:
            continue
        value = data[key]
        if key in LIMITS:
            if value is not None and not isinstance(value, str):
                errors[key] = 'Renseignez une valeur texte.'; continue
            if value is not None:
                value = value.replace('\r\n', '\n').strip()
                if len(value) > LIMITS[key] or any(unicodedata.category(char) in {'Cc', 'Cs', 'Zl', 'Zp'} and not (key == 'ObsGenerique' and char in '\n\t') for char in value):
                    errors[key] = 'Texte trop long ou contenant des caractères de contrôle.'
                data[key] = value or (None if key != name else '')
        elif value is not None and type(value) is not bool or value is None and key not in VISIBILITY and table == 'T_Generique':
            errors[key] = 'Choisissez Oui ou Non.'
    effective.update(data)
    if (old is None or name in data) and not str(effective.get(name) or '').strip():
        errors[name] = 'Renseignez le libellé.'
    if table == 'T_Generique':
        category = effective.get('ID_CategorieGeneriqueFk')
        if category is None:
            errors['ID_CategorieGeneriqueFk'] = 'Choisissez une catégorie.'
        elif old is None or category != old.get('ID_CategorieGeneriqueFk'):
            parent = db.one('SELECT "IdEntiteFk","ValideCategorieGenerique" FROM referentiel."T_CategorieGenerique" WHERE "ID_CategorieGenerique"=%s FOR SHARE', [category])
            if not parent or parent['IdEntiteFk'] is not None and parent['IdEntiteFk'] != effective.get('IdEntiteFk'):
                errors['ID_CategorieGeneriqueFk'] = 'Choisissez une catégorie commune ou appartenant à la même entreprise.'
            elif parent['ValideCategorieGenerique'] is False:
                errors['ID_CategorieGeneriqueFk'] = 'Choisissez une catégorie active.'
        if effective.get('IdEntiteFk') is not None and db.one('SELECT 1 AS protected '
                'FROM referentiel."T_ChampReferentiel" WHERE NOT "CanConfigure" '
                'AND "ID_CategorieDefautFk"=%s LIMIT 1', [category]):
            errors['ID_CategorieGeneriqueFk'] = 'Les références de sécurité restent communes et gérées par la plateforme.'
    if not errors:
        errors.update(duplicate_issues(obj, data, old))
    if errors:
        raise APIError(errors, 'REFERENCE_VALIDATION', 422)


def _scope(actor, body):
    scope = body.get('scope', 'global' if actor.global_admin else 'entity')
    if scope not in {'global', 'entity'}:
        raise APIError({'header': {'scope': 'Choisissez la portée des références.'}, 'rows': {}}, 'REFERENCE_BATCH_VALIDATION', 422)
    if scope == 'global':
        if body.get('scopeValue') not in (None, ''):
            raise APIError('La portée commune ne comporte pas d’entreprise.')
        return writable_owner(actor, None)
    return writable_owner(actor, body.get('scopeValue', read_entity(actor)))


def save_batch(actor, kind, body):
    from .repository import audit, mutate, positive
    from .registry import model
    if kind not in TABLES:
        raise APIError('Saisie indisponible.', 'NOT_FOUND', 404)
    if not isinstance(body, dict) or set(body) - {'requestId', 'scope', 'scopeValue', 'categoryId', 'rows'}:
        raise APIError('Un champ de la saisie n’est pas autorisé.')
    db.ensure_writable()
    owner = _scope(actor, body)
    try:
        request_id = str(uuid.UUID(body.get('requestId', '')))
    except (ValueError, TypeError, AttributeError):
        raise APIError('Rouvrez le formulaire pour identifier cet enregistrement.', 'REFERENCE_REQUEST_INVALID', 400)
    rows = body.get('rows')
    if not isinstance(rows, list) or not 1 <= len(rows) <= 200:
        raise APIError({'header': {'rows': 'Ajoutez de 1 à 200 lignes.'}, 'rows': {}}, 'REFERENCE_BATCH_VALIDATION', 422)
    ids = [row.get('clientRowId') if isinstance(row, dict) else None for row in rows]
    if any(not isinstance(value, str) or not value.strip() or len(value) > 120 for value in ids) or len(set(ids)) != len(ids):
        raise APIError('Les lignes doivent posséder des identifiants distincts.', 'REFERENCE_ROWS_INVALID', 400)
    category = None
    if kind == 'valeurs':
        try:
            category = positive(body.get('categoryId'), 'Catégorie')
        except APIError:
            raise APIError({'header': {'categoryId': 'Choisissez une catégorie.'}, 'rows': {}}, 'REFERENCE_BATCH_VALIDATION', 422)
    elif body.get('categoryId') not in (None, ''):
        raise APIError('La saisie de catégories ne comporte pas de catégorie parente.')
    table = TABLES[kind]; obj = model(table)
    digest = hashlib.sha256(json.dumps({'kind': kind, 'owner': owner, 'body': body}, cls=ExactEncoder, sort_keys=True, separators=(',', ':')).encode()).hexdigest()
    with transaction.atomic():
        db.query('SELECT pg_advisory_xact_lock(hashtextextended(%s,0))', ['reference-batch:' + str(actor.pk) + ':' + request_id])
        prior = db.one('SELECT "NewData" FROM systeme."T_Audit_Log" WHERE "TableName"=%s '
                       'AND "Operation"=\'REFERENCE_BATCH_CREATE\' AND "NewData"->>\'requestId\'=%s '
                       'AND "NewData"#>>\'{_actor,IdUser}\'=%s ORDER BY "IdLog" DESC LIMIT 1',
                       ['referentiel.' + table, request_id, str(actor.pk)])
        if prior:
            proof = prior['NewData']
            if proof.get('payloadHash') != digest:
                raise APIError('Cette demande a déjà été utilisée avec un autre contenu.', 'REFERENCE_REPLAY_CONFLICT', 409)
            return proof['response'], True
        issues = {}; prepared = []
        if category is not None:
            parent = db.one('SELECT "IdEntiteFk","ValideCategorieGenerique" FROM referentiel."T_CategorieGenerique" WHERE "ID_CategorieGenerique"=%s FOR SHARE', [category])
            if not parent or parent['IdEntiteFk'] is not None and parent['IdEntiteFk'] != owner or parent['ValideCategorieGenerique'] is False:
                raise APIError({'header': {'categoryId': 'Choisissez une catégorie active commune ou de la même entreprise.'}, 'rows': {}}, 'REFERENCE_BATCH_VALIDATION', 422)
            if owner is not None and db.one('SELECT 1 AS protected FROM referentiel."T_ChampReferentiel" '
                    'WHERE NOT "CanConfigure" AND "ID_CategorieDefautFk"=%s LIMIT 1', [category]):
                raise APIError({'header': {'categoryId': 'Les références de sécurité restent communes et gérées par la plateforme.'}, 'rows': {}}, 'REFERENCE_BATCH_VALIDATION', 422)
        seen = {}
        for row in rows:
            row_id = row['clientRowId']; data = {key: value for key, value in row.items() if key != 'clientRowId'}
            unknown = set(data) - FIELDS[table]
            if unknown:
                issues[row_id] = {next(iter(unknown)): 'Champ non autorisé.'}; continue
            data['IdEntiteFk'] = owner
            if category is not None:
                data['ID_CategorieGeneriqueFk'] = category
            try:
                validate_mutation(obj, data, None, actor)
            except APIError as error:
                issues[row_id] = dict(error.detail) if isinstance(error.detail, dict) else {'_line': str(error.detail)}
                continue
            for key in [NAMES[table]] + (['AbrGenerique'] if table == 'T_Generique' else []):
                value = data.get(key)
                if isinstance(value, str) and value.strip():
                    normalized = db.one('SELECT referentiel.fn_normaliser_libelle(%s) AS value', [value])['value']
                    identity = (key, normalized)
                    if identity in seen:
                        text = 'Ce code apparaît plusieurs fois dans la saisie.' if key == 'AbrGenerique' else 'Ce libellé apparaît plusieurs fois dans la saisie.'
                        issues.setdefault(row_id, {})[key] = text
                        issues.setdefault(seen[identity], {})[key] = text
                    else:
                        seen[identity] = row_id
            prepared.append((row_id, data))
        if issues:
            raise APIError({'rows': issues, 'header': {}}, 'REFERENCE_BATCH_VALIDATION', 422)
        records = []
        for row_id, data in prepared:
            try:
                with transaction.atomic():
                    saved = mutate(table, actor, data)
            except (APIError, DatabaseError) as error:
                details = dict(error.detail) if isinstance(error, APIError) and isinstance(error.detail, dict) else {
                    '_line': 'Cette ligne n’a pas pu être enregistrée. Vérifiez ses valeurs et les doublons.'}
                raise APIError({'rows': {row_id: details}, 'header': {}}, 'REFERENCE_BATCH_VALIDATION', 422) from error
            records.append({'clientRowId': row_id, **saved})
        result = {'records': records, 'requestId': request_id, 'count': len(records)}
        audit({'schema': 'referentiel', 'name': table}, 'REFERENCE_BATCH_CREATE',
              new={'requestId': request_id, 'payloadHash': digest, 'response': result}, actor=actor)
        return result, False


class ReferenceBatchView(APIView):
    permission_classes = [IsERPAdmin]
    http_method_names = ['post', 'options']

    def post(self, request, kind):
        result, replayed = save_batch(request.user, kind, request.data)
        return ok(result, status=200 if replayed else 201, meta={'replayed': replayed},
                  message='Saisie enregistrée.')
