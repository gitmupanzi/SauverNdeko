"""Reprise territoriale contrôlée à partir d'un plan privé épinglé par SHA-256.

Aucune instruction SQL n'est lue dans le plan. Le prévol est en lecture seule ;
la simulation avec écritures est réservée à une copie locale privée. L'application
sérialise la hiérarchie et conserve parents, identités et copies historiques.
"""
import hashlib
import json
import re
import unicodedata
from decimal import Decimal, InvalidOperation
from pathlib import Path

from django.conf import settings
from django.db import connection, transaction
from apps.accounts.authentication import actor_by_id
from . import db
from .category_values import category_key
from .module_access import require_module
from .repository import audit, set_admin_actor
from .responses import APIError, ExactEncoder

OPERATION = 'TERRITORIAL_RECONCILIATION_APPLY'
ACTIONS = ('reference_visibility', 'province_uid_fill', 'zone_uid_fill',
           'bureau_de_zone', 'rattachement_sanitaire', 'area_uid_fill',
           'area_create', 'aire_de_zone', 'grid3_object_link', 'alias_n5_n4')
TABLES = {f'T_Niveau_{n}': (f'geolocalisation."T_Niveau_{n}"', f'ID_Niveau_{n}') for n in range(1, 6)}
TABLES['T_Generique'] = ('referentiel."T_Generique"', 'ID_Generique')
PROOF_TABLES = {
    'sources': ('geolocalisation."T_SourceRapprochementTerritorial"', 'ID_SourceRapprochementTerritorial'),
    'correspondances': ('geolocalisation."T_CorrespondanceTerritoriale"', 'ID_CorrespondanceTerritoriale'),
    'liens': ('geolocalisation."T_LienTerritorial"', 'ID_LienTerritorial'),
}
UID = re.compile(r'^[A-Za-z][A-Za-z0-9]{10}$')
SHA = re.compile(r'^[a-f0-9]{64}$')
MAX_PLAN_BYTES = 100 * 1024 * 1024


def fail(message, code='TERRITORIAL_RECONCILIATION_INVALID'):
    raise APIError(message, code, 409)


def packed(value):
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(',', ':'), cls=ExactEncoder)


def fingerprint(value):
    return hashlib.sha256(packed(value).encode('utf8')).hexdigest()


def positive(value):
    if isinstance(value, bool) or not isinstance(value, int) or value <= 0:
        fail('Identifiant local positif attendu dans le plan.')
    return value


def uid(value):
    if not isinstance(value, str) or not UID.fullmatch(value):
        fail('UID SNIS invalide dans le plan.')
    return value


def normalized(value):
    return ''.join(c for c in unicodedata.normalize('NFKD', str(value or '')).lower() if c.isalnum() and not unicodedata.combining(c))


def same(actual, expected):
    if isinstance(actual, (Decimal, int, float)) and not isinstance(actual, bool) and isinstance(expected, str):
        try:
            return actual == Decimal(expected)
        except InvalidOperation:
            return False
    return actual == expected


def load_plan(path, expected_sha256):
    if not isinstance(expected_sha256, str) or not SHA.fullmatch(expected_sha256):
        fail('Empreinte SHA-256 explicite du plan requise.')
    location = Path(path)
    if not location.is_file() or location.stat().st_size > MAX_PLAN_BYTES:
        fail('Plan privé introuvable ou trop volumineux.')
    raw = location.read_bytes()
    digest = hashlib.sha256(raw).hexdigest()
    if digest != expected_sha256:
        fail('Le fichier de plan ne correspond plus à son empreinte approuvée.')
    try:
        plan = json.loads(raw.decode('utf-8-sig'))
    except (ValueError, UnicodeError):
        fail('Plan JSON invalide.')
    if not isinstance(plan, dict) or plan.get('version') != 1 or plan.get('database') != 'SauverNdeko':
        fail('Format ou base métier du plan non reconnu.')
    if set(plan.get('actions', {})) != set(ACTIONS):
        fail('Le plan ne contient pas les dix rubriques autorisées.')
    for kind in ACTIONS:
        rows = plan['actions'][kind]
        if not isinstance(rows, list) or len(rows) > 50000 or any(not isinstance(row, dict) for row in rows):
            fail('Rubrique de reprise invalide : ' + kind)
        if plan.get('counts', {}).get(kind) != len(rows):
            fail('Le nombre annoncé de lignes diffère de la rubrique : ' + kind)
    if set(plan.get('sources', {})) != {'dhis2', 'grid3'}:
        fail('Les deux sources examinées sont obligatoires.')
    for source in plan['sources'].values():
        if not isinstance(source, dict) or not SHA.fullmatch(source.get('sha256', '')) or not source.get('file') or not source.get('sheet'):
            fail('Provenance de source incomplète.')
    if not SHA.fullmatch(plan.get('input_fingerprints', {}).get('rows.json', '')):
        fail('Empreinte de la photographie locale absente.')
    return plan, digest


def _read_rows(table, ids=None, lock=False):
    sql_table, key = TABLES[table]
    suffix, params = ('', []) if ids is None else (f' WHERE t."{key}"=ANY(%s::integer[])', [list(ids)])
    rows = db.query(f'SELECT t."{key}" AS id,to_jsonb(t) AS row FROM {sql_table} t' + suffix + (' FOR UPDATE' if lock else ''), params)
    return {r['id']: r['row'] for r in rows}


def _actor(email):
    rows = db.query('SELECT "IdUser" FROM systeme."T_Utilisateurs" WHERE lower("EmailUser")=lower(%s)', [email])
    if len(rows) != 1:
        fail('Le compte acteur doit être identifié sans ambiguïté.', 'GLOBAL_ADMIN_REQUIRED')
    actor = actor_by_id(rows[0]['IdUser'])
    if not actor.global_admin:
        fail('La reprise partagée est réservée à un administrateur global actif.', 'GLOBAL_ADMIN_REQUIRED')
    require_module(actor, 'territoires', 'manage')
    return actor


def _desired_uids(actions):
    result = {}
    for kind, table in [('province_uid_fill', 'T_Niveau_1'), ('zone_uid_fill', 'T_Niveau_3'), ('area_uid_fill', 'T_Niveau_4')]:
        for action in actions[kind]:
            key = (table, positive(action['id']))
            if key in result:
                fail('Plusieurs écritures ciblent le même UID local.')
            result[key] = uid(action['uid'])
    return result


def _inspect(plan, lock=False):
    actions = plan['actions']
    desired = _desired_uids(actions)
    guards = {}
    for kind in ACTIONS:
        for action in actions[kind]:
            for guard in action.get('guards', []):
                table = guard.get('table')
                if table not in TABLES or table == 'T_Generique':
                    fail('Table de précondition non autorisée.')
                pk, before = positive(guard.get('id')), guard.get('before')
                if not isinstance(before, dict) or before.get(TABLES[table][1]) != pk:
                    fail('Précondition de ligne incomplète.')
                key = (table, pk)
                if key in guards and guards[key] != before:
                    fail('Le plan contient deux photographies différentes de la même ligne.')
                guards[key] = before
    current = {}
    for table in TABLES:
        ids = [pk for tab, pk in guards if tab == table]
        if ids:
            current.update({(table, pk): row for pk, row in _read_rows(table, ids, lock).items()})
    for key, before in guards.items():
        row = current.get(key)
        if row is None:
            fail('Une ligne examinée a disparu : ' + str(key), 'TERRITORIAL_RECONCILIATION_STALE')
        for column, value in before.items():
            if column not in row:
                fail('Colonne de photographie inconnue.')
            if not same(row[column], value):
                # Une reprise antérieure ciblée (03) peut avoir rempli le même UID.
                if column == 'uidSNIS' and value in (None, '') and row[column] == desired.get(key):
                    continue
                fail('Une ligne examinée a changé : ' + str(key) + '.' + column, 'TERRITORIAL_RECONCILIATION_STALE')
    for key in desired:
        if key not in guards:
            fail('Toute écriture UID exige sa photographie préalable.')
    as_choices = db.query('''SELECT g.* FROM referentiel."T_Generique" g JOIN referentiel."T_CategorieGenerique" c
        ON c."ID_CategorieGenerique"=g."ID_CategorieGeneriqueFk" WHERE referentiel.fn_normaliser_libelle(g."AbrGenerique") = 'as'
        AND g."ValideGenerique" AND c."ValideCategorieGenerique" AND g."IdEntiteFk" IS NULL AND c."IdEntiteFk" IS NULL
        AND g."ID_CategorieGeneriqueFk"=ANY(referentiel.fn_categories_champ('geolocalisation','T_Niveau_4','ID_TypeNiveau_4_Fk',NULL))''')
    if len(as_choices) != 1:
        fail('La référence AS commune active doit être unique dans la famille N4 résolue.')
    as_ref = as_choices[0]
    visibility = actions['reference_visibility']
    if len(visibility) > 1:
        fail('Une seule activation de visibilité AS est autorisée.')
    for change in visibility:
        if (change.get('id') != as_ref['ID_Generique'] or change.get('column') != 'VisibleNiveau_4'
                or change.get('after') is not True or change.get('category_id') != as_ref['ID_CategorieGeneriqueFk']):
            fail('Seule la visibilité N4 de la référence AS résolue peut être activée.')
        for column, value in change.get('before', {}).items():
            if column not in as_ref or not same(as_ref[column], value):
                fail('La référence AS examinée a changé.', 'TERRITORIAL_RECONCILIATION_STALE')
    if not as_ref.get('VisibleNiveau_4') and not visibility:
        fail('AS n’est pas activée pour N4 ; aucune activation explicite dans le plan.')
    identity = db.one('''SELECT is_identity,pg_get_serial_sequence('geolocalisation."T_Niveau_4"','ID_Niveau_4') AS sequence
        FROM information_schema.columns WHERE table_schema='geolocalisation' AND table_name='T_Niveau_4' AND column_name='ID_Niveau_4' ''')
    if not identity or identity['is_identity'] != 'YES' or not identity['sequence']:
        fail('N4 doit utiliser sa véritable identité PostgreSQL avant toute création.')
    # Vérifier toutes les identités canoniques avant de réserver un seul numéro.
    owners = {}
    all_areas = None
    all_levels = {}
    for table in ('T_Niveau_1', 'T_Niveau_3', 'T_Niveau_4'):
        rows = _read_rows(table)
        all_levels[table] = rows
        if table == 'T_Niveau_4':
            all_areas = rows
        for pk, row in rows.items():
            present = row.get('uidSNIS')
            if present:
                if present in owners:
                    fail('Un UID déjà enregistré désigne plusieurs identités locales.')
                owners[present] = (table, pk)
    for key, value in desired.items():
        if value in owners and owners[value] != key:
            fail('Un UID souhaité est déjà enregistré sur une autre identité.')
        owners[value] = key
    created = set()
    names = {(r.get('ID_Niveau_3_Fk'), normalized(r.get('NomNiveau_4'))) for r in all_areas.values() if r.get('ID_TypeNiveau_4_Fk') == as_ref['ID_Generique']}
    for action in actions['area_create']:
        values = action.get('values', {})
        required = {'ID_Niveau_3_Fk', 'ID_TypeNiveau_4_Fk', 'NomNiveau_4', 'uidSNIS'}
        if not required <= set(values) or set(values) - required - {'CodeNiveau_4'}:
            fail('Champs de création AS non autorisés.')
        value = uid(action['uid'])
        if values['uidSNIS'] != value or action.get('creation_key') != 'dhis2:aire:' + value or value in created or value in owners:
            fail('Une aire à créer possède un UID ou une clé déjà utilisé.')
        name = values['NomNiveau_4']
        parent = positive(values['ID_Niveau_3_Fk'])
        if values['ID_TypeNiveau_4_Fk'] != as_ref['ID_Generique'] or not isinstance(name, str) or not name.strip() or len(name) > 255:
            fail('Identité ou type de la nouvelle AS invalide.')
        if ('T_Niveau_3', parent) not in guards:
            fail('Le parent de toute nouvelle AS exige sa photographie.')
        name_key = (parent, normalized(name))
        if name_key in names:
            fail('Une AS du même nom et du même parent existe déjà ou est répétée.')
        names.add(name_key)
        created.add(value)
    # Les catégories métier viennent des FK physiques ; aucune famille chiffrée.
    type_rows = db.query('SELECT "ID_Generique","AbrGenerique" FROM referentiel."T_Generique" WHERE "IdEntiteFk" IS NULL')
    labels = {r['ID_Generique']: r['AbrGenerique'] for r in type_rows}
    for action in actions['zone_uid_fill']:
        if labels.get(current[('T_Niveau_3', action['id'])].get('ID_TypeNiveau_2_Fk')) != 'ZS':
            fail('Un UID de zone ne peut pas être affecté à un bureau BCZS.')
    for action in actions['area_uid_fill']:
        if current[('T_Niveau_4', action['id'])].get('ID_TypeNiveau_4_Fk') != as_ref['ID_Generique']:
            fail('Un UID d’aire ne peut pas être affecté à un groupement.')
    for action in actions['area_create']:
        parent = action['values']['ID_Niveau_3_Fk']
        if labels.get(current[('T_Niveau_3', parent)].get('ID_TypeNiveau_2_Fk')) != 'ZS':
            fail('Une nouvelle AS doit dépendre d’une ZS canonique.')
    _inspect_links(plan, guards, current, desired, as_ref, labels, all_levels)
    return current, desired, as_ref


def _inspect_links(plan, guards, current, desired, as_ref, labels, all_levels):
    """Valider le graphe complet avant INSERT, même pendant un prévol sans DML."""
    actions = plan['actions']
    n2 = _read_rows('T_Niveau_2')
    n3 = all_levels['T_Niveau_3']
    n4 = all_levels['T_Niveau_4']
    creations = {a['creation_key']: a for a in actions['area_create']}

    def guarded(table, value):
        key = (table, positive(value))
        if key not in guards or key not in current:
            fail('Toute cible locale d’un lien exige sa photographie préalable : ' + str(key))
        return current[key]

    def row_uid(table, row, key):
        return desired.get((table, row[key]), row.get('uidSNIS'))

    def province_of_zone(zone):
        parent = n2.get(zone.get('ID_Niveau_2_FK'))
        if not parent:
            fail('Parent provincial d’une zone introuvable.')
        return parent['ID_Niveau_1_FK']

    def zone(value):
        record = guarded('T_Niveau_3', value)
        if labels.get(record.get('ID_TypeNiveau_2_Fk')) != 'ZS':
            fail('Le lien doit cibler une ZS canonique, jamais son bureau BCZS.')
        return record

    def area(target):
        if not isinstance(target, dict):
            fail('Cible AS invalide.')
        if set(target) == {'existing_id'}:
            record = guarded('T_Niveau_4', target['existing_id'])
            if record.get('ID_TypeNiveau_4_Fk') != as_ref['ID_Generique']:
                fail('La cible existante doit être une AS et non un autre objet N4.')
            return ('existing', target['existing_id']), record, row_uid('T_Niveau_4', record, 'ID_Niveau_4')
        if set(target) == {'creation_key'} and target['creation_key'] in creations:
            action = creations[target['creation_key']]
            return ('new', target['creation_key']), action['values'], action['uid']
        fail('Cible AS absente du lot contrôlé.')

    bureau_zones = {}
    for action in actions['bureau_de_zone']:
        bureau = guarded('T_Niveau_3', action['bureau_id'])
        target = zone(action['zone_id'])
        if labels.get(bureau.get('ID_TypeNiveau_2_Fk')) != 'BCZS' or province_of_zone(bureau) != province_of_zone(target):
            fail('Le bureau et la ZS doivent être de types distincts dans la même province.')
        if uid(action['source_zone_uid']) != row_uid('T_Niveau_3', target, 'ID_Niveau_3'):
            fail('L’UID source du bureau ne correspond pas à la ZS canonique.')
        if action['bureau_id'] in bureau_zones:
            fail('Un bureau possède plusieurs liens sanitaires proposés.')
        bureau_zones[action['bureau_id']] = action['zone_id']

    existing_bureau_links = db.query('''SELECT "ID_OrigineNiveau_3Fk" AS bureau,"ID_CibleNiveau_3Fk" AS zone
        FROM geolocalisation."T_LienTerritorial" WHERE "NatureLien"='bureau_de_zone' AND "Decision"='confirmee' ''')
    for relation in existing_bureau_links:
        bureau, target = relation['bureau'], relation['zone']
        if bureau in bureau_zones and bureau_zones[bureau] != target:
            fail('Un lien sanitaire confirmé du bureau contredit la reprise proposée.')
        bureau_zones[bureau] = target
    sanitary_names = set()
    for record in n4.values():
        if record.get('ID_TypeNiveau_4_Fk') != as_ref['ID_Generique']:
            continue
        parent_id = record.get('ID_Niveau_3_Fk')
        parent = n3.get(parent_id)
        canonical = parent_id if parent and labels.get(parent.get('ID_TypeNiveau_2_Fk')) == 'ZS' else bureau_zones.get(parent_id)
        if canonical:
            sanitary_names.add((canonical, normalized(record.get('NomNiveau_4'))))
    for action in actions['area_create']:
        values = action['values']
        if (values['ID_Niveau_3_Fk'], normalized(values['NomNiveau_4'])) in sanitary_names:
            fail('Une AS de même nom est déjà présente dans cette ZS, sous le bureau ou la zone canonique.')

    attached_zones = set()
    for action in actions['rattachement_sanitaire']:
        target = zone(action['zone_id'])
        antenna = guarded('T_Niveau_2', action['antenne_id'])
        if category_key(labels.get(antenna.get('ID_TypeNiveau_2_Fk'))) not in {'ant pev', 'antpev', 'ant-pev', 'ant. pev'} or antenna.get('ID_Niveau_1_FK') != province_of_zone(target):
            fail('L’antenne PEV et la ZS doivent appartenir à la même province.')
        if action['zone_id'] in attached_zones:
            fail('Une zone possède plusieurs rattachements sanitaires proposés.')
        attached_zones.add(action['zone_id'])

    area_zones = {}
    for action in actions['aire_de_zone']:
        area_key, record, area_uid = area(action['area'])
        target = zone(action['zone_id'])
        if uid(action['source_area_uid']) != area_uid or area_key in area_zones:
            fail('Une aire possède un UID contradictoire ou plusieurs ZS proposées.')
        physical_parent = n3.get(record.get('ID_Niveau_3_Fk'))
        if not physical_parent or province_of_zone(physical_parent) != province_of_zone(target):
            fail('L’AS et la ZS doivent appartenir à la même province.')
        parent_type = labels.get(physical_parent.get('ID_TypeNiveau_2_Fk'))
        if parent_type == 'ZS' and physical_parent['ID_Niveau_3'] != action['zone_id']:
            fail('Le parent canonique existant de l’AS contredit la ZS source.')
        if parent_type == 'BCZS' and bureau_zones.get(physical_parent['ID_Niveau_3']) != action['zone_id']:
            fail('Une AS historique sous BCZS exige son lien bureau-ZS concordant.')
        if parent_type not in {'ZS', 'BCZS'}:
            fail('Le parent physique de l’AS ne représente ni une ZS ni son bureau.')
        area_zones[area_key] = action['zone_id']
    if any(('new', key) not in area_zones for key in creations):
        fail('Chaque nouvelle AS doit avoir sa correspondance vers une ZS.')

    grid3_ids = set()
    for action in actions['grid3_object_link']:
        area_key, record, area_uid = area(action['area'])
        target_id = area_zones.get(area_key)
        target = n3.get(target_id)
        province = all_levels['T_Niveau_1'].get(province_of_zone(target)) if target else None
        if (not target or not province or uid(action['uid']) != area_uid
                or uid(action['zone_uid']) != row_uid('T_Niveau_3', target, 'ID_Niveau_3')
                or uid(action['province_uid']) != row_uid('T_Niveau_1', province, 'ID_Niveau_1')):
            fail('La provenance GRID3 contredit l’aire, la zone ou la province canonique.')
        key = action.get('grid3id')
        if not isinstance(key, str) or not key or len(key) > 500 or key in grid3_ids:
            fail('Identité d’objet GRID3 absente ou répétée dans le lot.')
        if not isinstance(action.get('name'), str) or not action['name'].strip():
            fail('Nom d’objet GRID3 obligatoire.')
        positive(action.get('source_row'))
        grid3_ids.add(key)

    alias_origins, alias_targets = set(), set()
    type_counts = {}
    for record in n4.values():
        key = (record.get('ID_Niveau_3_Fk'), record.get('ID_TypeNiveau_4_Fk'), normalized(record.get('NomNiveau_4')))
        type_counts[key] = type_counts.get(key, 0) + 1
    for action in actions['alias_n5_n4']:
        origin = guarded('T_Niveau_5', action['n5_id'])
        target = guarded('T_Niveau_4', action['n4_id'])
        target_type = labels.get(target.get('ID_TypeNiveau_4_Fk'))
        if (action.get('type') not in {'AS', 'Grp'} or target_type != action['type']
                or origin.get('ID_TypeNiveau_5_Fk') != target.get('ID_TypeNiveau_4_Fk')
                or origin.get('ID_Niveau_3_Fk') != target.get('ID_Niveau_3_Fk')
                or normalized(origin.get('NomNiveau_5')) != normalized(target.get('NomNiveau_4'))
                or type_counts.get((target.get('ID_Niveau_3_Fk'), target.get('ID_TypeNiveau_4_Fk'), normalized(target.get('NomNiveau_4')))) != 1):
            fail('La copie historique N5/N4 n’est pas certaine et unique.')
        if (action.get('domain') != ('sanitaire' if target_type == 'AS' else 'administratif')
                or action['n5_id'] in alias_origins or action['n4_id'] in alias_targets):
            fail('Domaine ou unicité de copie historique contradictoire.')
        old_uid, new_uid = origin.get('uidSNIS'), row_uid('T_Niveau_4', target, 'ID_Niveau_4')
        if old_uid and new_uid and old_uid != new_uid:
            fail('Les UID de la copie historique sont contradictoires.')
        alias_origins.add(action['n5_id']); alias_targets.add(action['n4_id'])


def _insert_many(sql, rows):
    """JSON transmis comme valeur, SQL et colonnes fixes dans le programme."""
    if not rows:
        return []
    return db.query(sql, [packed(rows)])


def _sources(plan, plan_sha):
    specs = {key: {'code': key.upper(), 'version': value['sheet'], 'sha': value['sha256'], 'file': value['file'],
                   'meta': {'sheet': value['sheet'], 'planFormat': 1}}
             for key, value in plan['sources'].items()}
    specs['local'] = {'code': 'SAUVERNDEKO', 'version': 'photographie-' + plan['input_fingerprints']['rows.json'][:16],
                      'sha': plan['input_fingerprints']['rows.json'], 'file': 'rows.json', 'meta': {'type': 'photographie_locale'}}
    result = {}
    for key, item in specs.items():
        existing = db.one('SELECT * FROM geolocalisation."T_SourceRapprochementTerritorial" WHERE "Sha256Source"=%s', [item['sha']])
        if existing:
            if existing['CodeSource'] != item['code'] or existing['NomFichierSource'] != item['file']:
                fail('Une empreinte source est déjà enregistrée avec une provenance différente.')
            result[key] = existing['ID_SourceRapprochementTerritorial']
        else:
            result[key] = db.one('''INSERT INTO geolocalisation."T_SourceRapprochementTerritorial"
                ("CodeSource","VersionSource","Sha256Source","NomFichierSource","MetadonneesSource")
                VALUES(%s,%s,%s,%s,%s::jsonb) RETURNING "ID_SourceRapprochementTerritorial" id''',
                [item['code'], item['version'], item['sha'], item['file'], packed(item['meta'])])['id']
    return result


def _proof(action, plan_sha):
    return {'planSha256': plan_sha, 'dhis2Rows': action.get('dhis2_rows', []),
            'grid3Rows': action.get('grid3_rows', []), 'methode': 'UID, noms primaires et parents concordants dans les sources examinées'}


def _persist(plan, plan_sha, actor, current, desired, as_ref):
    actions = plan['actions']
    before_changes = []
    for change in actions['reference_visibility']:
        before_changes.append({'table': 'T_Generique', 'id': change['id'], 'before': {'VisibleNiveau_4': as_ref['VisibleNiveau_4']}, 'after': {'VisibleNiveau_4': True}})
        db.query('UPDATE referentiel."T_Generique" SET "VisibleNiveau_4"=true WHERE "ID_Generique"=%s', [change['id']])
    for (table, pk), value in desired.items():
        if current[(table, pk)].get('uidSNIS') == value:
            continue
        before_changes.append({'table': table, 'id': pk, 'before': {'uidSNIS': current[(table, pk)].get('uidSNIS')}, 'after': {'uidSNIS': value}})
        sql_table, column = TABLES[table]
        db.query(f'UPDATE {sql_table} SET "uidSNIS"=%s WHERE "{column}"=%s', [value, pk])
    created_rows = _insert_many('''INSERT INTO geolocalisation."T_Niveau_4"
        ("NomNiveau_4","ID_Niveau_3_Fk","ID_TypeNiveau_4_Fk","uidSNIS","CodeNiveau_4")
        SELECT r."NomNiveau_4",r."ID_Niveau_3_Fk",r."ID_TypeNiveau_4_Fk",r."uidSNIS",r."CodeNiveau_4"
        FROM jsonb_to_recordset(%s::jsonb) AS r("NomNiveau_4" text,"ID_Niveau_3_Fk" integer,"ID_TypeNiveau_4_Fk" integer,"uidSNIS" text,"CodeNiveau_4" text)
        RETURNING "ID_Niveau_4" id,"uidSNIS" uid''', [a['values'] for a in actions['area_create']])
    created = {'dhis2:aire:' + r['uid']: r['id'] for r in created_rows}
    def area_id(target):
        if set(target) == {'existing_id'}:
            return positive(target['existing_id'])
        if set(target) == {'creation_key'} and target['creation_key'] in created:
            return created[target['creation_key']]
        fail('Cible AS non résolue dans ce lot.')
    sources = _sources(plan, plan_sha)
    correspondence = []
    def external(source, key, level, target, value, proof, **extra):
        correspondence.append({'source': sources[source], 'key': key, 'n1': target if level == 1 else None,
            'n3': target if level == 3 else None, 'n4': target if level == 4 else None, 'uid': value,
            'proof': proof, **extra})
    for kind, level in [('province_uid_fill', 1), ('zone_uid_fill', 3), ('area_uid_fill', 4)]:
        for action in actions[kind]:
            extra = {'province_uid': None, 'zone_uid': None, 'area_uid': None}
            extra[{1: 'province_uid', 3: 'zone_uid', 4: 'area_uid'}[level]] = action['uid']
            external('dhis2', f'n{level}:' + action['uid'], level, action['id'], action['uid'], _proof(action, plan_sha), **extra)
    for action in actions['area_create']:
        external('dhis2', 'n4:' + action['uid'], 4, created[action['creation_key']], action['uid'], _proof(action, plan_sha), area_uid=action['uid'])
    for action in actions['grid3_object_link']:
        uid(action['uid']); uid(action['province_uid']); uid(action['zone_uid'])
        if not isinstance(action.get('grid3id'), str) or not action['grid3id'] or len(action['grid3id']) > 500:
            fail('Identité objet GRID3 invalide.')
        proof = {'planSha256': plan_sha, 'sheet': plan['sources']['grid3']['sheet'], 'row': action['source_row'],
                 'sourceid': action.get('sourceid'), 'source_acronym': action.get('source_acronym'),
                 'edit_par': action.get('edit_par'), 'date_source': action.get('date_source')}
        external('grid3', action['grid3id'], 4, area_id(action['area']), action['uid'], proof,
                 grid3id=action['grid3id'], name=action.get('name'), province_uid=action['province_uid'],
                 zone_uid=action['zone_uid'], area_uid=action['uid'])
    corr = _insert_many('''INSERT INTO geolocalisation."T_CorrespondanceTerritoriale"
        ("ID_SourceRapprochementFk","CleLigneSource","UidSource","UidSNISSource","UidProvinceSource","UidZoneSource","UidAireSource","Grid3Id","NomSource",
         "ID_Niveau_1Fk","ID_Niveau_3Fk","ID_Niveau_4Fk","Decision","Preuves","MotifDecision","DecideParUserFk")
        SELECT r.source,r.key,r.uid,r.uid,r.province_uid,r.zone_uid,r.area_uid,r.grid3id,r.name,r.n1,r.n3,r.n4,'confirmee',r.proof,
         'Correspondance certaine du plan privé contrôlé',r.actor
        FROM jsonb_to_recordset(%s::jsonb) AS r(source bigint,key text,uid text,province_uid text,zone_uid text,area_uid text,grid3id text,name text,
         n1 integer,n3 integer,n4 integer,proof jsonb,actor integer)
        RETURNING "ID_CorrespondanceTerritoriale" id''', [{**r, 'actor': actor.pk} for r in correspondence])
    links = []
    def link(kind, key, proof, **targets):
        source = 'local' if kind == 'copie_n5_n4' else 'grid3' if kind == 'rattachement_sanitaire' else 'dhis2'
        links.append({'source': sources[source], 'key': key,
                      'nature': kind, 'domain': targets.pop('domain', 'sanitaire'), 'proof': proof,
                      'actor': actor.pk, **targets})
    for action in actions['bureau_de_zone']:
        link('bureau_de_zone', 'bureau:' + str(action['bureau_id']) + ':zone:' + str(action['zone_id']), _proof(action, plan_sha), o3=positive(action['bureau_id']), c3=positive(action['zone_id']))
    zone_evidence = {a['id']: a for a in actions['zone_uid_fill']}
    for action in actions['rattachement_sanitaire']:
        evidence = zone_evidence.get(action['zone_id'], {})
        proof = {'planSha256': plan_sha, 'grid3Rows': evidence.get('grid3_rows', []),
                 'sheet': plan['sources']['grid3']['sheet'], 'antenneId': action['antenne_id'],
                 'methode': 'Antenne et province concordantes dans GRID3, ZS canonique rapprochée et bureau-zone confirmé'}
        link('rattachement_sanitaire', 'zone:' + str(action['zone_id']) + ':antenne:' + str(action['antenne_id']), proof,
             o3=positive(action['zone_id']), c2=positive(action['antenne_id']))
    for action in actions['aire_de_zone']:
        target = area_id(action['area'])
        link('aire_de_zone', 'aire:' + action['source_area_uid'] + ':zone:' + str(action['zone_id']), _proof(action, plan_sha), o4=target, c3=positive(action['zone_id']))
    for action in actions['alias_n5_n4']:
        if action['domain'] not in {'sanitaire', 'administratif', 'compatibilite'}:
            fail('Domaine de copie locale non autorisé.')
        link('copie_n5_n4', f"copie:n5:{positive(action['n5_id'])}:n4:{positive(action['n4_id'])}", {'planSha256': plan_sha, 'methode': action['proof']},
             domain=action['domain'], o5=action['n5_id'], c4=action['n4_id'])
    inserted_links = _insert_many('''INSERT INTO geolocalisation."T_LienTerritorial"
        ("ID_SourceRapprochementFk","CleLienSource","NatureLien","DomaineLien","ID_OrigineNiveau_3Fk","ID_OrigineNiveau_4Fk","ID_OrigineNiveau_5Fk",
         "ID_CibleNiveau_2Fk","ID_CibleNiveau_3Fk","ID_CibleNiveau_4Fk","Decision","Preuves","MotifDecision","DecideParUserFk")
        SELECT r.source,r.key,r.nature,r.domain,r.o3,r.o4,r.o5,r.c2,r.c3,r.c4,'confirmee',r.proof,'Lien certain du plan privé contrôlé',r.actor
        FROM jsonb_to_recordset(%s::jsonb) AS r(source bigint,key text,nature text,domain text,o3 integer,o4 integer,o5 integer,c2 integer,c3 integer,c4 integer,proof jsonb,actor integer)
        RETURNING "ID_LienTerritorial" id''', links)
    affected = {table: sorted({pk for tab, pk in current if tab == table}) for table in TABLES}
    affected['T_Niveau_4'] = sorted(set(affected['T_Niveau_4']) | set(created.values()))
    if actions['reference_visibility']:
        affected['T_Generique'] = [as_ref['ID_Generique']]
    states = {table: {str(pk): fingerprint(row) for pk, row in _read_rows(table, ids).items()}
              for table, ids in affected.items() if ids}
    proof_ids = {'sources': sorted(set(sources.values())), 'correspondances': [r['id'] for r in corr], 'liens': [r['id'] for r in inserted_links]}
    proof_states = _proof_states(proof_ids)
    return {'createdAreas': created, 'sources': sources, 'proofIds': proof_ids, 'states': states, 'proofStates': proof_states,
            'changes': before_changes, 'counts': plan['counts'], 'planSha256': plan_sha, 'actorId': actor.pk}


def _proof_states(proof_ids):
    result = {}
    for name, ids in proof_ids.items():
        if name not in PROOF_TABLES:
            fail('Table de preuve inconnue dans le journal.')
        table, pk = PROOF_TABLES[name]
        rows = db.query(f'SELECT "{pk}" AS id,to_jsonb(t) AS row FROM {table} t WHERE "{pk}"=ANY(%s::bigint[]) ORDER BY "{pk}"', [ids])
        if len(rows) != len(set(ids)):
            fail('Une preuve attendue a disparu.', 'TERRITORIAL_RECONCILIATION_STALE')
        result[name] = fingerprint(rows)
    return result


def _replay(previous, mode):
    result = previous['result']
    for table, rows in result['states'].items():
        if table not in TABLES:
            fail('Table inattendue dans le journal de reprise.')
        current = _read_rows(table, [positive(int(pk)) for pk in rows])
        if {str(pk): fingerprint(row) for pk, row in current.items()} != rows:
            fail('Une ligne appliquée a été modifiée ; réexaminer avant rejeu ou retour.', 'TERRITORIAL_RECONCILIATION_STALE')
    if _proof_states(result['proofIds']) != result['proofStates']:
        fail('Une preuve appliquée ne correspond plus au journal.', 'TERRITORIAL_RECONCILIATION_STALE')
    summary = {'mode': mode, 'alreadyApplied': True, 'committed': False, 'planSha256': result['planSha256'], 'counts': result['counts']}
    if mode == 'prepare_return':
        summary['returnAssessment'] = {'unchangedSinceApplication': True, 'uidOrVisibilityChanges': result['changes'],
            'createdAreaCount': len(result['createdAreas']), 'policy': 'Préparer une nouvelle version compensatrice. Ne pas supprimer les preuves finales ni les territoires créés utilisés.'}
    return summary


def run_plan(path, expected_sha256, actor_email, mode='preflight'):
    if mode not in {'preflight', 'simulate', 'apply', 'prepare_return'}:
        fail('Mode de reprise inconnu.')
    plan, digest = load_plan(path, expected_sha256)
    name, host = str(connection.settings_dict.get('NAME', '')), str(connection.settings_dict.get('HOST', ''))
    private = name.startswith('sauverndeko_test_') and host in {'localhost', '127.0.0.1', '::1'}
    if name != 'SauverNdeko' and not private:
        fail('Base non autorisée pour la reprise.')
    if mode == 'simulate' and not private:
        fail('Une simulation avec écritures exige une copie locale sauverndeko_test_* ; le prévol source reste sans écriture.')
    write = mode in {'simulate', 'apply'}
    if write:
        db.ensure_writable()
    with transaction.atomic():
        if not write:
            db.query('SET TRANSACTION ISOLATION LEVEL REPEATABLE READ, READ ONLY')
        else:
            db.query("SET LOCAL statement_timeout='300000ms'")
            db.query("SELECT pg_advisory_xact_lock(hashtextextended('geolocalisation:hierarchy-writes',0))")
            # Protéger également les écritures SQL directes qui ignorent le verrou applicatif.
            db.query('LOCK TABLE geolocalisation."T_Niveau_1",geolocalisation."T_Niveau_2",geolocalisation."T_Niveau_3",geolocalisation."T_Niveau_4",geolocalisation."T_Niveau_5",referentiel."T_Generique" IN SHARE ROW EXCLUSIVE MODE')
        actor = _actor(actor_email)
        previous = db.one('''SELECT "NewData" FROM systeme."T_Audit_Log" WHERE "Operation"=%s
            AND "NewData"->>'planSha256'=%s ORDER BY "IdLog" DESC LIMIT 1''', [OPERATION, digest])
        if previous:
            return _replay(previous['NewData'], mode)
        if mode == 'prepare_return':
            fail('Ce plan ne possède aucun journal d’application.')
        for table, _ in PROOF_TABLES.values():
            if not db.one('SELECT to_regclass(%s) AS name', [table])['name']:
                fail('Le socle SQL de rapprochement doit être installé avant le prévol.')
        current, desired, as_ref = _inspect(plan, lock=write)
        if not write:
            return {'mode': mode, 'alreadyApplied': False, 'committed': False, 'databaseReadOnly': True,
                    'planSha256': digest, 'counts': plan['counts'], 'guardedRows': len(current),
                    'note': 'Prévol uniquement : aucun numéro réservé ni aucune écriture.'}
        set_admin_actor(actor)
        result = _persist(plan, digest, actor, current, desired, as_ref)
        audit({'schema': 'geolocalisation', 'name': 'T_SourceRapprochementTerritorial'}, OPERATION,
              old={'changes': result['changes']}, new={'planSha256': digest, 'result': result}, actor=actor)
        if mode == 'simulate':
            transaction.set_rollback(True)
        return {'mode': mode, 'alreadyApplied': False, 'committed': mode == 'apply', 'planSha256': digest,
                'counts': plan['counts'], 'createdAreaCount': len(result['createdAreas']),
                'sequenceNotice': 'La simulation privée annule les lignes ; les séquences PostgreSQL peuvent conserver des écarts.' if mode == 'simulate' else ''}
