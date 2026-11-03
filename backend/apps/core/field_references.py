"""Référencement des véritables champs FK, résolu et conservé dans PostgreSQL.

Les correspondances changent les choix proposés, jamais les clés déjà portées
par les documents. Le catalogue SQL est la liste fermée des champs adressables.
"""
import copy
import hashlib
import json
import unicodedata
import uuid
from datetime import datetime
from tempfile import SpooledTemporaryFile

from django.db import connection, transaction
from django.conf import settings
from django.http import FileResponse
from rest_framework.permissions import IsAuthenticated
from rest_framework.views import APIView

from . import db
from .module_access import access_snapshot, module_for_object, require_module
from .permissions import IsERPAdmin, scope_for
from .registry import model
from .repository import audit, clean, page, positive, set_admin_actor
from .responses import APIError, ExactEncoder, ExactJSONRenderer, ok
from .tenancy import read_entity

TABLE = 'T_ChampReferentiel'
VIEW = 'V_ReferencementChamp'
INTERFACE = 'referentiels.champs'
LABELS = {
    'ID_ChampReferentiel': 'Identifiant du référencement', 'SchemaName': 'Schéma',
    'TableName': 'Table', 'ColumnName': 'Colonne', 'CategoryIds': 'ID catégorie',
    'CategoryLabels': 'Libellé catégorie', 'DefaultCategoryId': 'ID catégorie par défaut',
    'ChampLabel': 'Champ', 'ModuleName': 'Application', 'CategorieDefaut': 'Catégorie par défaut',
    'CategoriesActuelles': 'Catégorie actuelle', 'OrigineReglage': 'Origine du réglage',
    'CanConfigure': 'Configurable', 'ModifieLe': 'Modifié le', 'CreeLe': 'Créé le',
    'AliasSourceKeys': 'Sources associées', 'Revision': 'Révision',
    'ID_CategorieDefautFk': 'Identifiant de catégorie par défaut',
    'ReferenceHeriteeParent': 'Référence héritée du document parent',
    'SupportsEntityScope': 'Réglage par entreprise disponible',
}
DEFAULT_FIELDS = ['SchemaName', 'TableName', 'ColumnName', 'CategoryIds', 'CategoryLabels', 'DefaultCategoryId']
SCOPE_KEYS = {'scope', 'scopeValue'}
READ_KEYS = {'q', 'take', 'skip', 'filters', 'sortBy', 'sortDir'} | SCOPE_KEYS
VISIBILITY = {'VisibleNiveau_2', 'VisibleNiveau_3', 'VisibleNiveau_4', 'VisibleNiveau_5',
              'VisibleArticle', 'VisibleCmd', 'VisibleFacture', 'VisibleUsers', 'VisibleVoie', 'VisibleAll'}


def _admin(actor, action='read'):
    require_module(actor, 'referentiels', action)
    if not actor.global_admin:
        raise APIError('Le référencement des champs est réservé à l’administration de la plateforme.',
                       'GLOBAL_ADMIN_REQUIRED', 403)


def _scope(raw, actor, *, writing=False, automatic=False):
    if automatic:
        entity = read_entity(actor) if actor is not None else None
        return ('entity', str(entity), entity) if entity else ('global', None, None)
    scope = raw.get('scope', 'global')
    value = raw.get('scopeValue')
    if scope not in {'global', 'entity'}:
        raise APIError('Choisissez une portée globale ou une entreprise.', 'REFERENCE_SCOPE_INVALID', 400)
    if scope == 'global':
        if value not in (None, ''):
            raise APIError('La portée globale ne comporte pas d’identifiant d’entreprise.')
        return scope, None, None
    entity = positive(value, 'Entreprise')
    if not actor.global_admin and entity != read_entity(actor):
        raise APIError('Cette entreprise ne fait pas partie de votre accès.', 'FORBIDDEN_SCOPE', 403)
    row = db.one('SELECT "IdEntite","ValideEntite" FROM systeme."T_Entite" WHERE "IdEntite"=%s', [entity])
    if not row:
        raise APIError('Entreprise introuvable.', 'NOT_FOUND', 404)
    if writing and row['ValideEntite'] is False:
        raise APIError('Le paramétrage de cette entreprise est désactivé.', 'ENTITY_INACTIVE', 409)
    return scope, str(entity), entity


def _field(identifier=None, schema=None, table=None, column=None, *, lock=False):
    where, values = ('c."ID_ChampReferentiel"=%s', [positive(identifier)]) if identifier is not None else (
        'c."SchemaName"=%s AND c."TableName"=%s AND c."ColumnName"=%s', [schema, table, column])
    row = db.one('SELECT c.*,d."NomCategorieGenerique" AS "CategorieDefaut",v."ReferenceHeriteeParent" '
                 'FROM referentiel."T_ChampReferentiel" c LEFT JOIN referentiel."T_CategorieGenerique" d '
                 'ON d."ID_CategorieGenerique"=c."ID_CategorieDefautFk" '
                 'JOIN referentiel."V_ReferencementChamp" v ON v."ID_ChampReferentiel"=c."ID_ChampReferentiel" WHERE '+where+
                 (' FOR UPDATE OF c' if lock else ''), values)
    if not row:
        raise APIError('Champ de référence introuvable.', 'REFERENCE_FIELD_NOT_FOUND', 404)
    return row


def _rows(field, entity):
    return db.query('''SELECT f."IdFkCorrespondance",f."IdChampReferentielFk",f."SourceKey",
        f."MappingValue",f."TargetCategoryIdFk",f."SettingScope",f."ScopeValue",f."UpdatedAt",
        f."ValideFkCorrespondance",f."IsDefaultMapping" FROM systeme."T_Fk_Correspondance" f
        WHERE f."MappingType"='generic_category' AND
          (f."IdChampReferentielFk"=%s OR (f."IdChampReferentielFk" IS NULL AND f."SourceKey"=ANY(%s::text[])))
          AND ((f."SettingScope"='global' AND f."ScopeValue" IS NULL)
               OR (f."SettingScope"='entity' AND f."ScopeValue"=%s))
        ORDER BY f."IdFkCorrespondance"''',
        [field['ID_ChampReferentiel'], field['AliasSourceKeys'] or [], str(entity) if entity else None])


def _provenance(field, rows, entity):
    for scope in (['entity', 'global'] if entity else ['global']):
        scoped = [r for r in rows if r['ValideFkCorrespondance'] is True and r['SettingScope'] == scope]
        canonical = [r for r in scoped if r['IdChampReferentielFk'] == field['ID_ChampReferentiel']]
        selected = canonical or [r for r in scoped if r['IdChampReferentielFk'] is None]
        if selected:
            restored = bool(canonical) and any(r['MappingValue'] == '@default' for r in canonical)
            return ('default' if restored else 'canonical' if canonical else 'legacy'), scope
    return 'default', 'default'


def _version(field, rows):
    # Une écriture SQL historique via un alias est aussi détectée, avant même
    # qu’un ancien client ait adopté le nouveau service.
    fingerprint = hashlib.sha256(json.dumps(clean(rows), cls=ExactEncoder, sort_keys=True,
                                            separators=(',', ':')).encode('utf8')).hexdigest()
    return str(field['Revision']) + ':' + fingerprint


def _statistics(actor, field, categories, entity):
    """Compter sans déplacer de références, dans un périmètre démontrable."""
    physical = db.query('''SELECT a.attname FROM pg_catalog.pg_attribute a
        JOIN pg_catalog.pg_class t ON t.oid=a.attrelid JOIN pg_catalog.pg_namespace n ON n.oid=t.relnamespace
        WHERE n.nspname=%s AND t.relname=%s AND a.attnum>0 AND NOT a.attisdropped''',
        [field['SchemaName'], field['TableName']])
    columns = {row['attname'] for row in physical}
    scope, values = 'TRUE', []
    if entity:
        owner = next((name for name in ('IdEntiteFk', 'ID_EntiteFk') if name in columns), None)
        if owner:
            scope, values = 'v.'+db.ident(owner)+'=%s', [entity]
        elif field['TableName'] == 'T_Entite' and 'IdEntite' in columns:
            scope, values = 'v."IdEntite"=%s', [entity]
        elif field['SchemaName'] not in {'referentiel', 'geolocalisation'}:
            try:
                context = copy.copy(actor)
                context._context_entity = entity
                scope, values = scope_for(model(field['TableName']), context)
            except APIError:
                return {'existingCount': None, 'incompatibleExistingCount': None, 'inactiveExistingCount': None,
                        'countsScope': 'unavailable'}
    key = 'v.'+db.ident(field['ColumnName'])
    found = db.one('SELECT count(*) FILTER(WHERE '+key+' IS NOT NULL) AS existing,'
        'count(*) FILTER(WHERE '+key+' IS NOT NULL AND (g."ID_Generique" IS NULL OR '
        'NOT(g."ID_CategorieGeneriqueFk"=ANY(%s::integer[])))) AS incompatible,'
        'count(*) FILTER(WHERE '+key+' IS NOT NULL AND '
        '(g."ValideGenerique" IS NOT TRUE OR c."ValideCategorieGenerique" IS NOT TRUE)) AS inactive '
        'FROM '+db.qualified(field['SchemaName'], field['TableName'])+' v '
        'LEFT JOIN referentiel."T_Generique" g ON g."ID_Generique"='+key+' '
        'LEFT JOIN referentiel."T_CategorieGenerique" c ON c."ID_CategorieGenerique"=g."ID_CategorieGeneriqueFk" '
        'WHERE '+scope, [categories, *values])
    return {'existingCount': int(found['existing']), 'incompatibleExistingCount': int(found['incompatible']),
            'inactiveExistingCount': int(found['inactive']),
            'countsScope': 'entity' if entity and field['SchemaName'] not in {'referentiel', 'geolocalisation'} else 'shared'}


def _context(actor, field, scope, scope_value, entity, *, counts=False):
    # Un référentiel partagé ne peut pas dépendre de l'entreprise du lecteur.
    # Le périmètre demandé reste décrit, mais seule sa configuration globale
    # intervient dans la résolution, la version et les comptes de compatibilité.
    if not field['SupportsEntityScope']:
        entity = None
    rows = _rows(field, entity)
    resolved = db.one('SELECT referentiel.fn_categories_champ(%s,%s,%s,%s::integer) AS ids',
                     [field['SchemaName'], field['TableName'], field['ColumnName'], entity])
    identifiers = resolved['ids'] or []
    categories = db.query('SELECT c."ID_CategorieGenerique" AS id,c."NomCategorieGenerique" AS label,'
                         'c."ValideCategorieGenerique" AS active FROM unnest(%s::integer[]) WITH ORDINALITY r(id,n) '
                         'JOIN referentiel."T_CategorieGenerique" c ON c."ID_CategorieGenerique"=r.id ORDER BY r.n', [identifiers])
    source, effective_scope = _provenance(field, rows, entity)
    result = {**field, 'CanConfigure': field['CanConfigure'] and (scope == 'global' or field['SupportsEntityScope']),
              'CategoryIds': identifiers, 'CategoryLabels': [c['label'] for c in categories],
              'DefaultCategoryId': field['ID_CategorieDefautFk'], 'CategoriesActuelles': ', '.join(c['label'] for c in categories),
              'OrigineReglage': effective_scope+':'+source, 'categoryIds': identifiers,
              'categoryLabels': [c['label'] for c in categories], 'defaultCategoryId': field['ID_CategorieDefautFk'],
              'effectiveSource': source, 'effectiveScope': effective_scope, 'scope': scope, 'scopeValue': scope_value,
              'configured': bool(identifiers), '_version': _version(field, rows)}
    if counts:
        result.update(_statistics(actor, field, identifiers, entity))
    return clean(result)


def reference_context(actor, schema, table, column, *, counts=False):
    """Contexte réutilisable après les droits propres du service appelant."""
    scope, value, entity = _scope({}, actor, automatic=True)
    return _context(actor, _field(schema=schema, table=table, column=column), scope, value, entity, counts=counts)


def document_reference_actor(actor, entity):
    """Résoudre les choix dans l'entreprise durable d'un document déjà autorisé.

    La consultation globale d'un administrateur ne transforme pas les listes
    privées du document en listes communes ou en listes d'une autre entreprise.
    Le compte d'origine et ses droits restent inchangés.
    """
    if entity is None:
        return actor
    entity = positive(entity, 'Entreprise du document')
    if actor is None or not actor.global_admin and entity != read_entity(actor):
        raise APIError('Ce document appartient à une autre entreprise.', 'FORBIDDEN_SCOPE', 403)
    scoped = copy.copy(actor)
    scoped._context_entity = entity
    return scoped


def reference_options(actor, schema, table, column, current=None, visibility=None):
    """Abréviation prioritaire ; une ancienne valeur reste visible mais non sélectionnable."""
    field = _field(schema=schema, table=table, column=column)
    scope, value, entity = _scope({}, actor, automatic=True)
    context = _context(actor, field, scope, value, entity)
    choice_entity = entity if field['SupportsEntityScope'] else None
    if visibility is not None and (not isinstance(visibility, dict) or set(visibility)-VISIBILITY
                                   or any(type(v) is not bool for v in visibility.values())):
        raise APIError('Règle de visibilité non autorisée.', 'REFERENCE_VISIBILITY_INVALID', 400)
    clauses = ['g."ID_CategorieGeneriqueFk"=ANY(%s::integer[])',
               'g."ValideGenerique" IS TRUE', 'c."ValideCategorieGenerique" IS TRUE',
               'referentiel.fn_reference_visible(g."ID_Generique",%s)']
    params = [context['categoryIds'], choice_entity]
    for key, expected in (visibility or {}).items():
        clauses.append('g.'+db.ident(key)+' IS NOT DISTINCT FROM %s')
        params.append(expected)
    from .reference_labels import reference_label_sql
    label_sql=reference_label_sql('g')
    projection = f'''SELECT g."ID_Generique" AS id,
        {label_sql} AS label,
        g."NomGenerique" AS name,g."AbrGenerique" AS abbr,g."ID_CategorieGeneriqueFk" AS "categoryId",
        (g."ValideGenerique" IS TRUE AND c."ValideCategorieGenerique" IS TRUE) AS active
        FROM referentiel."T_Generique" g JOIN referentiel."T_CategorieGenerique" c
          ON c."ID_CategorieGenerique"=g."ID_CategorieGeneriqueFk"'''
    result = [{**row, 'disabled': False, 'incompatible': False} for row in db.query(
        projection+' WHERE '+' AND '.join(clauses)+' ORDER BY lower('+label_sql+'),g."ID_Generique"', params)]
    retained = [] if current is None or current == '' else current if isinstance(current, (list, tuple)) else [current]
    retained = list(dict.fromkeys(positive(v, 'Valeur actuelle') for v in retained))
    missing = [key for key in retained if not any(row['id'] == key for row in result)]
    if missing:
        result.extend({**row, 'disabled': True, 'incompatible': row['categoryId'] not in context['categoryIds']}
                      for row in db.query(projection+' WHERE g."ID_Generique"=ANY(%s::integer[]) '
                          'AND referentiel.fn_reference_visible(g."ID_Generique",%s) ORDER BY g."ID_Generique"', [missing, choice_entity]))
    if schema == 'logistique' and (table, column) in {('T_Commande', 'ID_TypeCmdFk'), ('T_Mouvement', 'ID_TypeMvtFk')} and result:
        kinds = {row['id']: row for row in db.query('SELECT id,logistique.fn_nature_bon(id) AS kind,'
            'logistique.fn_effet_type_bon(id) AS effect FROM unnest(%s::integer[]) AS x(id)', [[row['id'] for row in result]])}
        result = [{**row, 'kind': kinds[row['id']]['kind'] or 'inconnu', 'stockEffect': kinds[row['id']]['effect'],
                   'sign': kinds[row['id']]['effect'], 'canInvoice': kinds[row['id']]['kind'] == 'sortie'} for row in result]
    return clean(result)


def _detail(actor, identifier, raw):
    scope, value, entity = _scope(raw, actor)
    result = _context(actor, _field(identifier), scope, value, entity, counts=True)
    result['categories'] = db.query('SELECT "ID_CategorieGenerique" AS id,"NomCategorieGenerique" AS label '
        'FROM referentiel."T_CategorieGenerique" WHERE "ValideCategorieGenerique" IS TRUE '
        'AND referentiel.fn_categorie_visible("ID_CategorieGenerique",%s) '
        'ORDER BY lower("NomCategorieGenerique"),"ID_CategorieGenerique"', [entity if result['SupportsEntityScope'] else None])
    return result


def table_source():
    # Métadonnées inspectées, et non colonnes supposées d’une table métier.
    columns = db.query('''SELECT column_name,data_type,is_nullable,character_maximum_length,numeric_precision,
        numeric_scale,is_identity FROM information_schema.columns WHERE table_schema='referentiel'
        AND table_name='V_ReferencementChamp' ORDER BY ordinal_position''')
    if not columns:
        raise APIError('Le référencement des champs n’est pas installé.', 'REFERENCE_CONFIGURATION_UNAVAILABLE', 503)
    return {'schema': 'referentiel', 'name': VIEW, 'columns': columns,
            'primaryKey': ['ID_ChampReferentiel'], 'relations': []}


def _list_source(actor, raw):
    scope, value, entity = _scope(raw, actor)
    obj = table_source()
    names = [c['column_name'] for c in obj['columns'] if c['column_name'] not in
             {'CategoryIds', 'CategoryLabels', 'CategoriesActuelles', 'OrigineReglage', 'CanConfigure'}]
    # Le même jeu contextualisé alimente recherche, filtres, tri et export.
    projection = ','.join('c.'+db.ident(name) for name in names)
    projection += ',(c."CanConfigure" AND '+('TRUE' if entity is None else 'c."SupportsEntityScope"')+') AS "CanConfigure"'
    entity_sql = 'NULL' if entity is None else str(entity)
    scope_sql = 'NULL' if entity is None else "'"+str(entity)+"'"
    # Les deux littéraux proviennent exclusivement de l’entier validé par _scope.
    sql = f'''(SELECT {projection},r.ids AS "CategoryIds",
        ARRAY(SELECT g."NomCategorieGenerique" FROM unnest(r.ids) WITH ORDINALITY a(id,n)
              JOIN referentiel."T_CategorieGenerique" g ON g."ID_CategorieGenerique"=a.id ORDER BY a.n) AS "CategoryLabels",
        (SELECT string_agg(g."NomCategorieGenerique",', ' ORDER BY a.n)
         FROM unnest(r.ids) WITH ORDINALITY a(id,n) JOIN referentiel."T_CategorieGenerique" g ON g."ID_CategorieGenerique"=a.id) AS "CategoriesActuelles",
        CASE WHEN c."SupportsEntityScope" AND EXISTS(SELECT 1 FROM systeme."T_Fk_Correspondance" f WHERE f."ValideFkCorrespondance"
          AND f."MappingType"='generic_category' AND f."SettingScope"='entity' AND f."ScopeValue"={scope_sql}
          AND (f."IdChampReferentielFk"=c."ID_ChampReferentiel" OR
              (f."IdChampReferentielFk" IS NULL AND f."SourceKey"=ANY(c."AliasSourceKeys"))))
          THEN 'entity' ELSE c."OrigineReglage" END AS "OrigineReglage"
        FROM referentiel."V_ReferencementChamp" c CROSS JOIN LATERAL
          (SELECT referentiel.fn_categories_champ(c."SchemaName",c."TableName",c."ColumnName",{entity_sql}::integer) AS ids) r) v'''
    return obj, sql, scope, value


def selection(actor, raw, *, exporting=False):
    _admin(actor, 'export' if exporting else 'read')
    if set(raw)-(READ_KEYS | ({'columns', 'selection', 'timeZone'} if exporting else set())):
        raise APIError('Critère non autorisé.')
    obj, source, scope, value = _list_source(actor, raw)
    try:
        filters = json.loads(raw.get('filters', '{}')) if isinstance(raw.get('filters', {}), str) else raw.get('filters', {})
    except (ValueError, TypeError):
        raise APIError('Filtres invalides.')
    allowed = {c['column_name']: c for c in obj['columns'] if c['column_name'] in LABELS}
    if not isinstance(filters, dict) or set(filters)-allowed.keys():
        raise APIError('Filtre non autorisé.')
    clauses, params = ['TRUE'], []
    for key, value_filter in filters.items():
        if value_filter is None:
            clauses.append('v.'+db.ident(key)+' IS NULL')
        elif key in {'CategoryIds', 'AliasSourceKeys', 'CategoryLabels'}:
            if not isinstance(value_filter, list) or any(type(v) is bool for v in value_filter):
                raise APIError('Filtre de catégorie invalide.')
            if key == 'CategoryIds':
                value_filter = [positive(v, 'Catégorie') for v in value_filter]
            elif any(not isinstance(v, str) or len(v) > 300 for v in value_filter):
                raise APIError('Filtre texte invalide.')
            clauses.append('v.'+db.ident(key)+('@>%s::integer[]' if key == 'CategoryIds' else '=%s'))
            params.append(value_filter)
        elif allowed[key]['data_type'] == 'boolean':
            if value_filter in ('true', 'false'):
                value_filter = value_filter == 'true'
            if type(value_filter) is not bool:
                raise APIError('Filtre booléen invalide.')
            clauses.append('v.'+db.ident(key)+'=%s'); params.append(value_filter)
        elif allowed[key]['data_type'] in {'integer', 'bigint'}:
            clauses.append('v.'+db.ident(key)+'=%s'); params.append(positive(value_filter))
        else:
            if not isinstance(value_filter, str) or len(value_filter) > 300:
                raise APIError('Filtre texte invalide.')
            clauses.append('v.'+db.ident(key)+'=%s'); params.append(value_filter)
    q = raw.get('q', '')
    if not isinstance(q, str) or len(q) > 300:
        raise APIError('Recherche trop longue.')
    if q.strip():
        fields = ['SchemaName', 'TableName', 'ColumnName', 'ChampLabel', 'ModuleName', 'CategoriesActuelles', 'CategorieDefaut']
        clauses.append('('+' OR '.join('v.'+db.ident(name)+' ILIKE %s' for name in fields)+')')
        params.extend(['%'+q.strip()+'%']*len(fields))
    sort, direction = raw.get('sortBy') or 'SchemaName', str(raw.get('sortDir', 'asc')).lower()
    if sort not in allowed or direction not in {'asc', 'desc'}:
        raise APIError('Tri non autorisé.')
    order = 'v.'+db.ident(sort)+' '+direction.upper()+' NULLS LAST'
    if sort != 'ID_ChampReferentiel':
        order += ',v."ID_ChampReferentiel" ASC'
    return obj, source, ' AND '.join(clauses), params, order, sort, direction, scope, value


def save(actor, identifier, body, *, restore=False):
    _admin(actor, 'manage')
    db.ensure_writable()
    keys = {'scope', 'scopeValue', '_version', 'requestId', 'motif'} | (set() if restore else {'categoryIds'})
    if not isinstance(body, dict) or set(body)-keys:
        raise APIError('Paramétrage invalide.')
    scope, scope_value, entity = _scope(body, actor, writing=True)
    reason = body.get('motif')
    if not isinstance(reason, str) or not reason.strip() or len(reason) > 1000 or any(unicodedata.category(c) in {'Cc', 'Cs', 'Zl', 'Zp'} for c in reason):
        raise APIError({'motif': 'Précisez un motif, au maximum 1 000 caractères.'})
    version = body.get('_version')
    if not isinstance(version, str) or not version or len(version) > 120:
        raise APIError('Rechargez le paramétrage avant de l’enregistrer.', 'REFERENCE_VERSION_REQUIRED', 400)
    try:
        request_id = str(uuid.UUID(body.get('requestId', '')))
    except (ValueError, TypeError, AttributeError):
        raise APIError('Identifiant de demande invalide.')
    identifier = positive(identifier)
    categories = None
    if not restore:
        categories = body.get('categoryIds')
        if not isinstance(categories, list) or len(categories) != 1:
            raise APIError({'categoryIds': 'Choisissez une seule catégorie.'})
        categories = [positive(categories[0], 'Catégorie')]
    operation = 'REFERENCE_FIELD_RESTORE' if restore else 'REFERENCE_FIELD_CONFIGURE'
    payload = {'fieldId': identifier, 'actorId': actor.pk, 'scope': scope, 'scopeValue': scope_value,
               '_version': version, 'categoryIds': categories, 'motif': reason.strip(), 'operation': operation}
    digest = hashlib.sha256(json.dumps(payload, sort_keys=True, separators=(',', ':')).encode('utf8')).hexdigest()
    with transaction.atomic():
        db.query('SELECT pg_advisory_xact_lock(hashtextextended(%s,0))', ['reference-field:'+str(actor.pk)+':'+request_id])
        replay = db.one('''SELECT "NewData" FROM systeme."T_Audit_Log" WHERE "TableName"='referentiel.T_ChampReferentiel'
            AND "NewData"->>'requestId'=%s AND "NewData"#>>'{_actor,IdUser}'=%s ORDER BY "IdLog" DESC LIMIT 1''', [request_id, str(actor.pk)])
        if replay:
            if replay['NewData'].get('payloadHash') != digest:
                raise APIError('Cette demande a déjà été utilisée avec un autre contenu.', 'REQUEST_REPLAY_CONFLICT', 409)
            return replay['NewData']['response'], True
        field = _field(identifier, lock=True)
        if not field['CanConfigure']:
            raise APIError('Ce champ est protégé par les règles d’accès de la plateforme.', 'REFERENCE_FIELD_PROTECTED', 403)
        if scope == 'entity' and not field['SupportsEntityScope']:
            raise APIError('Cette référence est partagée. Modifiez son réglage dans la portée globale.',
                           'REFERENCE_SCOPE_UNAVAILABLE', 400)
        previous = _context(actor, field, scope, scope_value, entity, counts=True)
        if previous['_version'] != version:
            raise APIError('Le référencement a changé. Rechargez-le avant d’enregistrer.', 'REFERENCE_VERSION_CONFLICT', 409)
        if categories and not db.one('SELECT "ID_CategorieGenerique" FROM referentiel."T_CategorieGenerique" '
                'WHERE "ID_CategorieGenerique"=%s AND "ValideCategorieGenerique" IS TRUE '
                'AND referentiel.fn_categorie_visible("ID_CategorieGenerique",%s) FOR SHARE',
                [*categories, entity if field['SupportsEntityScope'] else None]):
            raise APIError({'categoryIds': 'Choisissez une catégorie active de cette portée.'}, 'REFERENCE_CATEGORY_INACTIVE', 400)
        set_admin_actor(actor)
        db.query('DELETE FROM systeme."T_Fk_Correspondance" WHERE "IdChampReferentielFk"=%s '
                 'AND "SettingScope"=%s AND "ScopeValue" IS NOT DISTINCT FROM %s', [identifier, scope, scope_value])
        row = {'ModuleName': field['ModuleName'], 'SchemaName': field['SchemaName'], 'ViewName': None,
               'SourceKey': 'champ.'+str(identifier), 'FieldName': field['ColumnName'], 'FieldLabel': field['ChampLabel'],
               'MappingType': 'generic_category', 'ReferenceSchemaName': 'referentiel', 'ReferenceObjectName': 'T_Generique',
               'ReferenceFieldName': 'ID_Generique', 'TargetCategoryIdFk': None if restore else categories[0],
               'MappingValue': '@default' if restore else str(categories[0]), 'IsDefaultMapping': restore,
               'ValideFkCorrespondance': True, 'SettingScope': scope, 'ScopeValue': scope_value,
               'DisplayOrder': 0, 'ObsFkCorrespondance': reason.strip(), 'IdChampReferentielFk': identifier}
        db.query('INSERT INTO systeme."T_Fk_Correspondance" ('+','.join(db.ident(k) for k in row)+') VALUES ('+
                 ','.join(['%s']*len(row))+')', list(row.values()))
        result = _context(actor, _field(identifier), scope, scope_value, entity, counts=True)
        audit({'schema': 'referentiel', 'name': TABLE}, operation, old=previous,
              new={'fieldId': identifier, 'requestId': request_id, 'payloadHash': digest,
                   'scope': scope, 'scopeValue': scope_value, 'motif': reason.strip(), 'response': result}, actor=actor)
    return result, False


class FieldReferencesView(APIView):
    permission_classes = [IsERPAdmin]
    http_method_names = ['get', 'put', 'options']

    def get(self, request, pk=None):
        if pk is not None:
            _admin(request.user)
            if set(request.query_params)-SCOPE_KEYS:
                raise APIError('Critère non autorisé.')
            result = _detail(request.user, pk, request.query_params)
            return ok(result, meta={'canWrite': bool(result['CanConfigure']) and request.user.global_admin and not settings.DB_READ_ONLY,
                                    'source': 'referentiel.'+VIEW})
        obj, source, where, params, order, sort, direction, scope, value = selection(request.user, request.query_params.dict())
        take, skip = page(request.query_params)
        count = db.one('SELECT count(*) AS n FROM '+source+' WHERE '+where, params)['n']
        total = db.one('SELECT count(*) AS n FROM '+source)['n']
        rows = db.query('SELECT v.* FROM '+source+' WHERE '+where+' ORDER BY '+order+' LIMIT %s OFFSET %s', [*params, take, skip])
        return ok(clean(rows), meta={'count': len(rows), 'filteredCount': count, 'totalCount': total, 'take': take,
                  'skip': skip, 'sortBy': sort, 'sortDir': direction, 'scope': scope, 'scopeValue': value,
                  'canWrite': request.user.global_admin and not settings.DB_READ_ONLY,
                  'canExport': any(item['canExport'] for item in access_snapshot(request.user)['modules'].values()),
                  'columns': [c['column_name'] for c in obj['columns']]})

    def put(self, request, pk=None):
        if pk is None:
            raise APIError('Choisissez le champ à modifier.', 'REFERENCE_FIELD_REQUIRED', 400)
        result, replay = save(request.user, pk, request.data)
        return ok(result, meta={'replayed': replay}, message='Référencement enregistré.')


class FieldReferenceRestoreView(APIView):
    permission_classes = [IsERPAdmin]

    def post(self, request, pk):
        result, replay = save(request.user, pk, request.data, restore=True)
        return ok(result, meta={'replayed': replay}, message='Catégorie par défaut rétablie.')


class FieldReferenceOptionsView(APIView):
    permission_classes = [IsAuthenticated]
    http_method_names = ['get', 'options']

    def get(self, request, pk=None):
        raw = request.query_params.dict()
        if set(raw)-{'schema', 'table', 'column', 'currentId', 'visibility'}:
            raise APIError('Critère non autorisé.')
        field = _field(pk) if pk is not None else _field(schema=raw.get('schema'), table=raw.get('table'), column=raw.get('column'))
        require_module(request.user, module_for_object({'schema': field['SchemaName'], 'name': field['TableName']}))
        visibility = raw.get('visibility')
        try:
            visibility = json.loads(visibility) if visibility else None
        except (ValueError, TypeError):
            raise APIError('Règle de visibilité invalide.')
        result = reference_context(request.user, field['SchemaName'], field['TableName'], field['ColumnName'])
        options = reference_options(request.user, field['SchemaName'], field['TableName'], field['ColumnName'], raw.get('currentId'), visibility)
        return ok({key: result[key] for key in ('categoryIds', 'categoryLabels', 'defaultCategoryId', 'effectiveSource', 'effectiveScope', 'configured', '_version')} |
                  {'options': options, 'inheritedFromParent': bool(field['ReferenceHeriteeParent']),
                   'supportsEntityScope': bool(field['SupportsEntityScope']),
                   'field': {'id': field['ID_ChampReferentiel'], 'schema': field['SchemaName'],
                    'table': field['TableName'], 'column': field['ColumnName'], 'label': field['ChampLabel']}})


class FieldReferenceHistoryView(APIView):
    permission_classes = [IsERPAdmin]

    def get(self, request, pk):
        _admin(request.user)
        _field(pk)
        if set(request.query_params)-({'take', 'skip'} | SCOPE_KEYS):
            raise APIError('Critère non autorisé.')
        take, skip = page(request.query_params)
        where = 'a."TableName"=%s AND a."NewData"->>\'fieldId\'=%s'
        params = ['referentiel.'+TABLE, str(pk)]
        if set(request.query_params) & SCOPE_KEYS:
            scope, scope_value, _ = _scope(request.query_params, request.user)
            where += ' AND a."NewData"->>\'scope\'=%s AND a."NewData"->>\'scopeValue\' IS NOT DISTINCT FROM %s'
            params.extend([scope, scope_value])
        count = db.one('SELECT count(*) AS n FROM systeme."T_Audit_Log" a WHERE '+where, params)['n']
        rows = db.query('SELECT a."IdLog",a."ChangedAt",a."Operation",a."OldData",a."NewData",'
            'concat_ws(\' \',u."PrenomUser",u."NomUser") AS "Auteur" FROM systeme."T_Audit_Log" a '
            'LEFT JOIN systeme."T_Utilisateurs" u ON u."IdUser"=(a."NewData"#>>\'{_actor,IdUser}\')::integer '
            'WHERE '+where+' ORDER BY a."IdLog" DESC LIMIT %s OFFSET %s', [*params, take, skip])
        return ok(clean(rows), meta={'count': len(rows), 'filteredCount': count, 'totalCount': count, 'take': take, 'skip': skip})


def workbook(actor, raw, file_format='xlsx'):
    from .table_preferences import export_keys
    from .tabular_exports import selected_scope, write_tabular
    from apps.logistique.excel import MAX_EXPORT_ROWS
    from apps.logistique.table_queries import document_zone
    wanted = export_keys(actor, INTERFACE, raw)
    obj, source, where, params, order, _, _, scope, _ = selection(actor, raw, exporting=True)
    clause, values = selected_scope(raw, 'ID_ChampReferentiel')
    where += clause; params.extend(values)
    available = {col['column_name']: col for col in obj['columns']}
    if any(key not in available or key not in LABELS for key in wanted):
        raise APIError('Colonne d’export non autorisée.')
    fields = [{**available[key], 'label': LABELS[key],
               **({'data_type': 'text'} if key.startswith('ID_') else {})} for key in wanted]
    zone = document_zone(raw); generated = datetime.now(zone)
    context = {'title': 'Référencement des champs', 'scope': 'Paramétrage '+scope, 'generated': generated.strftime('%d/%m/%Y %H:%M'),
               'zone': str(zone), 'tz': zone, 'source': 'referentiel.'+VIEW, 'raw': raw, 'filters': {}, 'order': order}
    stream = SpooledTemporaryFile(max_size=8*1024*1024, mode='w+b')
    try:
        with connection.cursor() as cursor:
            cursor.execute('SELECT '+','.join('v.'+db.ident(key) for key in wanted)+' FROM '+source+' WHERE '+where+
                           ' ORDER BY '+order+' LIMIT %s', [*params, MAX_EXPORT_ROWS+1])
            def rows():
                while batch := cursor.fetchmany(500):
                    for values_row in batch:
                        yield {key: ', '.join(str(item) for item in value) if isinstance(value, list) else value
                               for key, value in zip(wanted, values_row)}
            count = write_tabular(stream, fields, rows(), context, file_format)
        stream.seek(0)
        return stream, count, 'SauverNdeko_Referencement_Champs_'+generated.strftime('%Y-%m-%d')+'.'+file_format
    except Exception:
        stream.close()
        raise


from apps.logistique.excel import ExcelDownloadView, CSVFileRenderer, XLSX_MEDIA_TYPE


class FieldReferenceExportView(ExcelDownloadView):
    renderer_classes = [ExactJSONRenderer, CSVFileRenderer, *ExcelDownloadView.renderer_classes[1:]]

    def get(self, request, file_format):
        stream, count, filename = workbook(request.user, request.query_params.dict(), file_format)
        response = FileResponse(stream, as_attachment=True, filename=filename,
                                content_type=XLSX_MEDIA_TYPE if file_format == 'xlsx' else 'text/csv; charset=utf-8')
        response['X-Export-Row-Count'] = str(count)
        response['Cache-Control'] = 'no-store, private'
        return response
