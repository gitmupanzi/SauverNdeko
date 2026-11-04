"""Maintenance explicite du schéma métier, indépendante de l'ORM et du serveur HTTP.

Les anciens scripts ne sont jamais rejoués par ce module. Un socle vérifié
atteste le catalogue déjà installé ; seules les évolutions du manifeste fermé
sont ensuite exécutées, chacune avec son inscription dans la même transaction.
"""
import hashlib
import json
import re
import time
from contextlib import contextmanager
from pathlib import Path

import sqlparse
from sqlparse import lexer as sql_lexer
from sqlparse import tokens as sql_tokens
from django.db import DatabaseError, transaction


HASH_ALGORITHM = 'sha256-utf8-lf-v1'
SCHEMAS = ('analytics', 'communication', 'geolocalisation', 'logistique',
           'operations', 'professionnel', 'referentiel', 'support', 'systeme')
LEDGER = 'systeme."T_MigrationSchema"'
LOCK_NAME = 'sauverndeko:schema-migrations:v1'
ID_PATTERN = re.compile(r'[A-Za-z0-9][A-Za-z0-9_.-]{0,127}\Z')
SHA_PATTERN = re.compile(r'[0-9a-f]{64}\Z')


class MigrationError(RuntimeError):
    """Erreur de maintenance lisible, sans SQL ni secret de connexion."""


def normalized_text(path):
    try:
        return Path(path).read_bytes().decode('utf-8-sig').replace('\r\n', '\n').replace('\r', '\n')
    except (OSError, UnicodeError):
        raise MigrationError('Fichier de livraison absent ou illisible en UTF-8.') from None


def sha256_file(path):
    return hashlib.sha256(normalized_text(path).encode('utf-8')).hexdigest()


def _digest(value):
    return hashlib.sha256(json.dumps(value, ensure_ascii=False, sort_keys=True,
                                    separators=(',', ':')).encode('utf-8')).hexdigest()


def _rows(conn, sql, params=()):
    with conn.cursor() as cursor:
        cursor.execute(sql, params)
        return cursor.fetchall()


def _execute(conn, sql, params=None):
    with conn.cursor() as cursor:
        cursor.execute(sql, params)


def _payload(value):
    return json.loads(value) if isinstance(value, str) else value


def canonical_expression(sql):
    """Normaliser une seule variation native de pg_dump/parseur PostgreSQL.

    Un ARRAY de constantes varchar sans limite, converti vers text[], est
    parfois redécompilé avec ::text sur chaque constante après restauration.
    Reconnaître cette grammaire exacte par lexèmes, sans modifier chaînes,
    commentaires, variables, casts avec longueur ni expressions calculées.
    """
    tokens = list(sql_lexer.tokenize(sql))
    significant = [(kind, value, index) for index, (kind, value) in enumerate(tokens)
                   if kind not in sql_tokens.Whitespace]
    replacements = {}
    i = 0
    while i < len(significant):
        kind, value, start = significant[i]
        if kind != sql_tokens.Name.Builtin or value.upper() != 'ARRAY':
            i += 1
            continue
        j = i + 1
        if j >= len(significant) or significant[j][1] != '[':
            i += 1
            continue
        j += 1
        literals = []
        all_text = True
        valid = True
        while j < len(significant):
            if significant[j][0] != sql_tokens.Literal.String.Single:
                valid = False
                break
            literal = significant[j][1]
            j += 1
            if [row[1].lower() for row in significant[j:j+3]] != ['::', 'character', 'varying']:
                valid = False
                break
            j += 3
            has_text = [row[1].lower() for row in significant[j:j+2]] == ['::', 'text']
            if has_text:
                j += 2
            all_text = all_text and has_text
            literals.append(literal)
            if j < len(significant) and significant[j][1] == ',':
                j += 1
                continue
            if j < len(significant) and significant[j][1] == ']':
                j += 1
                break
            valid = False
            break
        if valid and literals:
            outer_text = [row[1].lower() for row in significant[j:j+4]] == ['::', 'text', '[', ']']
            if outer_text:
                j += 4
            if outer_text or all_text:
                end = significant[j-1][2]
                replacements[start] = (end, 'ARRAY[' + ','.join(item+'::text' for item in literals) + ']')
                i = j
                continue
        i += 1
    result = []
    index = 0
    while index < len(tokens):
        if index in replacements:
            end, replacement = replacements[index]
            result.append(replacement)
            index = end+1
        else:
            result.append(tokens[index][1])
            index += 1
    return ''.join(result)


@contextmanager
def _catalogue_transaction(conn):
    with transaction.atomic(using=conn.alias):
        previous = _rows(conn, 'SELECT current_setting(%s)', ['search_path'])[0][0]
        _execute(conn, 'SELECT set_config(%s,%s,true)', ['search_path', 'pg_catalog'])
        try:
            yield
        finally:
            # Un éventuel échec SQL est d'abord annulé par le savepoint. Le SET
            # LOCAL est alors lui aussi annulé ; ne pas requêter un bloc cassé.
            if not conn.needs_rollback:
                _execute(conn, 'SELECT set_config(%s,%s,true)', ['search_path', previous])


def build_schema_snapshot(connection):
    """Empreintes du catalogue, sans lignes, propriétaire, ACL ou valeur de séquence.

    Le search_path pg_catalog rend les noms décompilés indépendants de la session.
    public/Django et le journal de maintenance sont hors de ce contrat métier.
    """
    if connection.vendor != 'postgresql':
        raise MigrationError('Le moteur de migration exige PostgreSQL.')
    objects = []
    with _catalogue_transaction(connection):
        existing = [row[0] for row in _rows(connection,
            'SELECT nspname FROM pg_namespace WHERE nspname=ANY(%s) ORDER BY nspname', [list(SCHEMAS)])]
        if existing != sorted(SCHEMAS):
            raise MigrationError('Schémas métier incomplets : utiliser le parcours d’installation vierge.')
        queries = [
            ('schema', '''SELECT n.nspname,jsonb_build_object('comment',obj_description(n.oid,'pg_namespace'))
                FROM pg_namespace n WHERE n.nspname=ANY(%s)'''),
            ('relation', '''SELECT n.nspname||'.'||c.relname,jsonb_build_object(
                'kind',c.relkind,'persistence',c.relpersistence,'rowsecurity',c.relrowsecurity,
                'forcerowsecurity',c.relforcerowsecurity,'replicaidentity',c.relreplident,
                'options',c.reloptions,'accessmethod',a.amname,
                'partition',CASE WHEN c.relkind='p' THEN pg_get_partkeydef(c.oid) ELSE NULL END,
                'partitionbound',CASE WHEN c.relispartition THEN pg_get_expr(c.relpartbound,c.oid) ELSE NULL END,
                'comment',obj_description(c.oid,'pg_class'))
                FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
                LEFT JOIN pg_am a ON a.oid=c.relam
                WHERE n.nspname=ANY(%s) AND c.relkind IN ('r','p','v','m','f')
                AND NOT(n.nspname='systeme' AND COALESCE(c.relname,'')='T_MigrationSchema')'''),
            ('column', '''SELECT n.nspname||'.'||c.relname||'.'||a.attname,jsonb_build_object(
                'position',row_number() OVER (PARTITION BY c.oid ORDER BY a.attnum),
                'type',format_type(a.atttypid,a.atttypmod),
                'notnull',a.attnotnull,'identity',a.attidentity,'generated',a.attgenerated,
                'default',pg_get_expr(d.adbin,d.adrelid),'collation',cn.nspname||'.'||co.collname,
                'comment',col_description(c.oid,a.attnum))
                FROM pg_attribute a JOIN pg_class c ON c.oid=a.attrelid
                JOIN pg_namespace n ON n.oid=c.relnamespace
                LEFT JOIN pg_attrdef d ON d.adrelid=c.oid AND d.adnum=a.attnum
                LEFT JOIN pg_collation co ON co.oid=a.attcollation
                LEFT JOIN pg_namespace cn ON cn.oid=co.collnamespace
                WHERE n.nspname=ANY(%s) AND c.relkind IN ('r','p','v','m','f','c')
                AND a.attnum>0 AND NOT a.attisdropped
                AND NOT(n.nspname='systeme' AND c.relname='T_MigrationSchema')'''),
            ('constraint', '''SELECT n.nspname||'.'||COALESCE(c.relname,t.typname)||'.'||k.conname,
                jsonb_build_object('type',k.contype,'definition',pg_get_constraintdef(k.oid,true),
                'validated',k.convalidated,'comment',obj_description(k.oid,'pg_constraint'))
                FROM pg_constraint k JOIN pg_namespace n ON n.oid=k.connamespace
                LEFT JOIN pg_class c ON c.oid=k.conrelid LEFT JOIN pg_type t ON t.oid=k.contypid
                WHERE n.nspname=ANY(%s)
                AND NOT(n.nspname='systeme' AND COALESCE(c.relname,'')='T_MigrationSchema')'''),
            ('index', '''SELECT n.nspname||'.'||i.relname,jsonb_build_object(
                'definition',pg_get_indexdef(i.oid),'valid',x.indisvalid,'ready',x.indisready,
                'comment',obj_description(i.oid,'pg_class'))
                FROM pg_index x JOIN pg_class i ON i.oid=x.indexrelid
                JOIN pg_class c ON c.oid=x.indrelid JOIN pg_namespace n ON n.oid=i.relnamespace
                WHERE n.nspname=ANY(%s)
                AND NOT(n.nspname='systeme' AND c.relname='T_MigrationSchema')'''),
            ('view', '''SELECT n.nspname||'.'||c.relname,jsonb_build_object('definition',pg_get_viewdef(c.oid,true))
                FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
                WHERE n.nspname=ANY(%s) AND c.relkind IN ('v','m')'''),
            ('routine', '''SELECT n.nspname||'.'||p.proname||'('||pg_get_function_identity_arguments(p.oid)||')',
                jsonb_build_object('definition',pg_get_functiondef(p.oid),'comment',obj_description(p.oid,'pg_proc'))
                FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
                WHERE n.nspname=ANY(%s) AND p.prokind IN ('f','p')'''),
            ('trigger', '''SELECT n.nspname||'.'||c.relname||'.'||t.tgname,
                jsonb_build_object('definition',pg_get_triggerdef(t.oid,true),'enabled',t.tgenabled,
                'comment',obj_description(t.oid,'pg_trigger'))
                FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid JOIN pg_namespace n ON n.oid=c.relnamespace
                WHERE n.nspname=ANY(%s) AND NOT t.tgisinternal
                AND NOT(n.nspname='systeme' AND c.relname='T_MigrationSchema')'''),
            ('sequence', '''SELECT n.nspname||'.'||c.relname,jsonb_build_object(
                'type',format_type(s.seqtypid,NULL),'start',s.seqstart,'increment',s.seqincrement,
                'minimum',s.seqmin,'maximum',s.seqmax,'cache',s.seqcache,'cycle',s.seqcycle,
                'comment',obj_description(c.oid,'pg_class'))
                FROM pg_sequence s JOIN pg_class c ON c.oid=s.seqrelid JOIN pg_namespace n ON n.oid=c.relnamespace
                WHERE n.nspname=ANY(%s)'''),
            ('type', '''SELECT n.nspname||'.'||t.typname,jsonb_build_object(
                'kind',t.typtype,'basetype',format_type(t.typbasetype,t.typtypmod),
                'notnull',t.typnotnull,'default',t.typdefault,
                'enum',(SELECT jsonb_agg(e.enumlabel ORDER BY e.enumsortorder) FROM pg_enum e WHERE e.enumtypid=t.oid),
                'comment',obj_description(t.oid,'pg_type'))
                FROM pg_type t JOIN pg_namespace n ON n.oid=t.typnamespace
                LEFT JOIN pg_class c ON c.oid=t.typrelid
                WHERE n.nspname=ANY(%s) AND t.typelem=0 AND (t.typtype IN ('d','e','r','m') OR c.relkind='c')'''),
            ('policy', '''SELECT n.nspname||'.'||c.relname||'.'||p.polname,jsonb_build_object(
                'command',p.polcmd,'permissive',p.polpermissive,'using',pg_get_expr(p.polqual,p.polrelid),
                'check',pg_get_expr(p.polwithcheck,p.polrelid),
                'roles',(SELECT jsonb_agg(CASE WHEN r=0 THEN 'PUBLIC' ELSE pg_get_userbyid(r) END ORDER BY r)
                         FROM unnest(p.polroles) r))
                FROM pg_policy p JOIN pg_class c ON c.oid=p.polrelid JOIN pg_namespace n ON n.oid=c.relnamespace
                WHERE n.nspname=ANY(%s) AND NOT(n.nspname='systeme' AND c.relname='T_MigrationSchema')'''),
            ('rule', '''SELECT n.nspname||'.'||c.relname||'.'||r.rulename,
                jsonb_build_object('definition',pg_get_ruledef(r.oid,true),'enabled',r.ev_enabled,
                'comment',obj_description(r.oid,'pg_rewrite'))
                FROM pg_rewrite r JOIN pg_class c ON c.oid=r.ev_class JOIN pg_namespace n ON n.oid=c.relnamespace
                WHERE n.nspname=ANY(%s) AND r.rulename<>'_RETURN'
                AND NOT(n.nspname='systeme' AND c.relname='T_MigrationSchema')'''),
        ]
        for kind, query in queries:
            for name, payload in _rows(connection, query, [list(SCHEMAS)]):
                value = _payload(payload)
                if kind in {'constraint', 'view'}:
                    value['definition'] = canonical_expression(value['definition'])
                objects.append({'kind': kind, 'name': name, 'sha256': _digest(value)})
    objects.sort(key=lambda item: (item['kind'], item['name']))
    return {'schemas': list(SCHEMAS), 'objects': objects, 'sha256': _digest(objects)}


def snapshot_differences(expected, actual, limit=12):
    before = {(row['kind'], row['name']): row['sha256'] for row in expected['objects']}
    after = {(row['kind'], row['name']): row['sha256'] for row in actual['objects']}
    differences = []
    for key in sorted(before.keys() | after.keys()):
        if before.get(key) != after.get(key):
            state = 'ajouté' if key not in before else 'absent' if key not in after else 'différent'
            differences.append(f'{key[0]} {key[1]} : {state}')
    return differences[:limit]


def _json_file(path):
    try:
        value = json.loads(normalized_text(path))
    except ValueError:
        raise MigrationError('JSON de livraison invalide.') from None
    if not isinstance(value, dict):
        raise MigrationError('Objet JSON de livraison attendu.')
    return value


def _valid_id(value):
    return isinstance(value, str) and ID_PATTERN.fullmatch(value) is not None


def _valid_sha(value):
    return isinstance(value, str) and SHA_PATTERN.fullmatch(value) is not None


def _safe_file(directory, name, suffix, *, relative_to=None):
    if not isinstance(name, str) or not name or '\\' in name or '\x00' in name:
        raise MigrationError('Chemin de livraison non conforme.')
    path = (directory / name).resolve()
    boundary = (relative_to or directory).resolve()
    if boundary not in path.parents or path.suffix != suffix or not path.is_file():
        raise MigrationError('Fichier de livraison absent ou hors du répertoire autorisé.')
    return path


def validate_sql(sql):
    """Refuser les contrôles de transaction hors des blocs et chaînes SQL.

    Les fichiers sont du code revu, pas des requêtes d'utilisateurs. Ce contrôle
    évite une transaction partielle accidentelle ; il n'est pas un bac à sable SQL.
    """
    statements = sqlparse.parse(sql)
    if not statements:
        raise MigrationError('Migration SQL vide.')
    substantive = False
    for statement in statements:
        words = [token.value for token in statement.flatten()
                 if not token.is_whitespace and token.ttype not in sql_tokens.Comment
                 and token.ttype not in sql_tokens.Literal.String]
        if not words:
            continue
        substantive = True
        first = words[0].upper()
        upper = [word.upper() for word in words]
        if (first in {'BEGIN', 'START', 'COMMIT', 'END', 'ROLLBACK', 'ABORT',
                      'SAVEPOINT', 'RELEASE', 'PREPARE', 'VACUUM', 'DISCARD'}
                or any(word.startswith('\\') for word in words)
                or 'CONCURRENTLY' in upper
                or (first == 'SET' and any(word in upper for word in ('ROLE', 'AUTHORIZATION', 'TRANSACTION')))):
            raise MigrationError('Migration non atomique ou commande psql interdite : retirer le contrôle de transaction du script.')
    if not substantive:
        raise MigrationError('Migration SQL vide.')


def load_manifest(path):
    path = Path(path).resolve()
    manifest = _json_file(path)
    if (set(manifest) != {'format', 'hashAlgorithm', 'baseline', 'migrations'}
            or manifest['format'] != 1 or manifest['hashAlgorithm'] != HASH_ALGORITHM
            or not isinstance(manifest['baseline'], dict) or not isinstance(manifest['migrations'], list)):
        raise MigrationError('Format de manifeste de migration non reconnu.')
    base_ref = manifest['baseline']
    if set(base_ref) != {'id', 'file', 'sha256'} or not _valid_id(base_ref['id']) or not _valid_sha(base_ref['sha256']):
        raise MigrationError('Référence du socle non conforme.')
    baseline_path = _safe_file(path.parent, base_ref['file'], '.json')
    if sha256_file(baseline_path) != base_ref['sha256']:
        raise MigrationError('Empreinte du fichier de socle différente.')
    baseline = _json_file(baseline_path)
    required = {'format', 'hashAlgorithm', 'id', 'description', 'release', 'schemas', 'objects', 'sha256', 'legacyMigrations'}
    if (set(baseline) != required or baseline['format'] != 1 or baseline['hashAlgorithm'] != HASH_ALGORITHM
            or baseline['id'] != base_ref['id'] or baseline['schemas'] != list(SCHEMAS)
            or not isinstance(baseline['objects'], list) or not isinstance(baseline['legacyMigrations'], list)
            or not isinstance(baseline['description'], str) or not isinstance(baseline['release'], str)):
        raise MigrationError('Socle de catalogue non conforme.')
    keys = set()
    for row in baseline['objects']:
        if (not isinstance(row, dict) or set(row) != {'kind', 'name', 'sha256'}
                or not all(isinstance(row[key], str) for key in row)
                or not _valid_sha(row['sha256']) or (row['kind'], row['name']) in keys):
            raise MigrationError('Catalogue de socle non conforme.')
        keys.add((row['kind'], row['name']))
    if baseline['objects'] != sorted(baseline['objects'], key=lambda row: (row['kind'], row['name'])) or baseline['sha256'] != _digest(baseline['objects']):
        raise MigrationError('Empreinte du catalogue de socle différente.')
    sql_root = path.parent.parent
    legacy_names = set()
    for row in baseline['legacyMigrations']:
        if (not isinstance(row, dict) or set(row) != {'file', 'sha256'}
                or not isinstance(row['file'], str) or not _valid_sha(row['sha256']) or row['file'] in legacy_names):
            raise MigrationError('Historique antérieur non conforme.')
        legacy = _safe_file(sql_root / 'migrations', row['file'], '.sql')
        if sha256_file(legacy) != row['sha256']:
            raise MigrationError('Un ancien fichier de migration a changé : conserver son contenu et ajouter une nouvelle migration.')
        legacy_names.add(row['file'])
    previous = base_ref['id']
    seen = {previous}
    files = set()
    for row in manifest['migrations']:
        if (not isinstance(row, dict) or set(row) != {'id', 'file', 'sha256', 'dependsOn', 'description', 'release'}
                or not _valid_id(row['id']) or row['id'] in seen or not _valid_sha(row['sha256'])
                or not isinstance(row['dependsOn'], list) or previous not in row['dependsOn']
                or not all(_valid_id(value) for value in row['dependsOn'])
                or len(set(row['dependsOn'])) != len(row['dependsOn']) or not set(row['dependsOn']).issubset(seen)
                or not isinstance(row['description'], str) or not isinstance(row['release'], str)):
            raise MigrationError('Ordre ou dépendances des migrations non conforme.')
        script = _safe_file(path.parent, row['file'], '.sql', relative_to=sql_root / 'migrations')
        if script in files or script.relative_to(sql_root / 'migrations').as_posix() in legacy_names:
            raise MigrationError('Script dupliqué ou ancien script inscrit parmi les nouvelles migrations.')
        if sha256_file(script) != row['sha256']:
            raise MigrationError('Empreinte SQL différente : publication interrompue.')
        sql = normalized_text(script)
        validate_sql(sql)
        row['_sql'] = sql
        files.add(script)
        seen.add(row['id'])
        previous = row['id']
    manifest['_baseline'] = baseline
    manifest['_baselinePath'] = baseline_path
    return manifest


def _ledger_exists(conn):
    return _rows(conn, 'SELECT to_regclass(%s)', [LEDGER])[0][0] is not None


def _verify_ledger_shape(conn):
    """Un journal restauré vide doit conserver le contrat exact de maintenance."""
    columns = [
        ('Identifiant', 'text', True, None, '', ''),
        ('EmpreinteFichier', 'character varying(64)', True, None, '', ''),
        ('Nature', 'text', True, None, '', ''),
        ('Description', 'text', True, None, '', ''),
        ('VersionApplication', 'text', True, None, '', ''),
        ('AppliqueLe', 'timestamp with time zone', True, 'clock_timestamp()', '', ''),
        ('DureeMs', 'bigint', True, None, '', ''),
        ('Dependances', 'jsonb', True, None, '', ''),
        ('Position', 'integer', True, None, '', ''),
        ('EmpreinteStructure', 'character varying(64)', True, None, '', ''),
        ('Structure', 'jsonb', True, None, '', ''),
    ]
    expected_constraints = {
        ('p', 'PRIMARY KEY ("Identifiant")', False, False, True),
        ('u', 'UNIQUE ("Position")', False, False, True),
        ('c', 'CHECK ("EmpreinteFichier"::text ~ \'^[0-9a-f]{64}$\'::text)', False, False, True),
        ('c', 'CHECK ("Nature" = ANY (ARRAY[\'socle\'::text, \'migration\'::text]))', False, False, True),
        ('c', 'CHECK ("DureeMs" >= 0)', False, False, True),
        ('c', 'CHECK (jsonb_typeof("Dependances") = \'array\'::text)', False, False, True),
        ('c', 'CHECK ("Position" >= 0)', False, False, True),
        ('c', 'CHECK ("EmpreinteStructure"::text ~ \'^[0-9a-f]{64}$\'::text)', False, False, True),
        ('c', 'CHECK (jsonb_typeof("Structure") = \'object\'::text)', False, False, True),
    }
    with _catalogue_transaction(conn):
        actual_columns = _rows(conn, '''SELECT a.attname,format_type(a.atttypid,a.atttypmod),a.attnotnull,
            pg_get_expr(d.adbin,d.adrelid),a.attidentity,a.attgenerated FROM pg_attribute a
            LEFT JOIN pg_attrdef d ON d.adrelid=a.attrelid AND d.adnum=a.attnum
            WHERE a.attrelid=%s::regclass AND a.attnum>0 AND NOT a.attisdropped ORDER BY a.attnum''', [LEDGER])
        constraints = _rows(conn, '''SELECT contype,pg_get_constraintdef(oid,true),
            condeferrable,condeferred,convalidated FROM pg_constraint
            WHERE conrelid=%s::regclass AND contype<>'n' ''', [LEDGER])
        relation = _rows(conn, '''SELECT relkind,relpersistence,relrowsecurity,relforcerowsecurity,relispartition
            FROM pg_class WHERE oid=%s::regclass''', [LEDGER])
        extras = _rows(conn, '''SELECT
            (SELECT count(*) FROM pg_trigger WHERE tgrelid=%s::regclass AND NOT tgisinternal),
            (SELECT count(*) FROM pg_inherits WHERE inhrelid=%s::regclass OR inhparent=%s::regclass),
            (SELECT count(*) FROM pg_index WHERE indrelid=%s::regclass),
            (SELECT count(*) FROM pg_index WHERE indrelid=%s::regclass AND (NOT indisvalid OR NOT indisready)),
            (SELECT count(*) FROM pg_constraint WHERE conrelid=%s::regclass AND contype='n' AND NOT convalidated)''',
            [LEDGER]*6)[0]
    if (actual_columns != columns or set(constraints) != expected_constraints
            or len(constraints) != len(expected_constraints)
            or relation != [('r', 'p', False, False, False)] or extras != (0, 0, 2, 0, 0)):
        raise MigrationError('Structure du journal de migrations non conforme ; maintenance refusée.')


def _read_ledger(conn):
    rows = _rows(conn, '''SELECT "Identifiant","EmpreinteFichier","Nature","Dependances","Position",
        "EmpreinteStructure","Structure" FROM systeme."T_MigrationSchema" ORDER BY "Position"''')
    return [{'id': row[0], 'sha256': row[1], 'nature': row[2], 'dependsOn': _payload(row[3]),
             'position': row[4], 'schemaSha256': row[5], 'snapshot': _payload(row[6])} for row in rows]


def _expected_entries(manifest):
    baseline = manifest['baseline']
    return [{'id': baseline['id'], 'sha256': baseline['sha256'], 'nature': 'socle', 'dependsOn': []}] + [
        {'id': row['id'], 'sha256': row['sha256'], 'nature': 'migration', 'dependsOn': row['dependsOn']}
        for row in manifest['migrations']]


def _verify_history(manifest, ledger):
    expected = _expected_entries(manifest)
    if not ledger or len(ledger) > len(expected):
        raise MigrationError('Journal absent, vide ou plus récent que cette livraison.')
    for position, row in enumerate(ledger):
        item = expected[position]
        if any(row[key] != item[key] for key in ('id', 'sha256', 'nature', 'dependsOn')) or row['position'] != position:
            raise MigrationError('Historique installé différent du manifeste ; aucun rejeu ni retour automatique autorisé.')
        snapshot = row['snapshot']
        if (not isinstance(snapshot, dict) or set(snapshot) != {'schemas', 'objects', 'sha256'}
                or snapshot['schemas'] != list(SCHEMAS) or not isinstance(snapshot['objects'], list)
                or not _valid_sha(snapshot['sha256'])):
            raise MigrationError('Preuve structurelle du journal invalide.')
        keys = set()
        for obj in snapshot['objects']:
            if (not isinstance(obj, dict) or set(obj) != {'kind', 'name', 'sha256'}
                    or not all(isinstance(value, str) for value in obj.values())
                    or not _valid_sha(obj['sha256']) or (obj['kind'], obj['name']) in keys):
                raise MigrationError('Preuve structurelle du journal invalide.')
            keys.add((obj['kind'], obj['name']))
        if (snapshot['objects'] != sorted(snapshot['objects'], key=lambda obj: (obj['kind'], obj['name']))
                or row['schemaSha256'] != snapshot['sha256'] or snapshot['sha256'] != _digest(snapshot['objects'])):
            raise MigrationError('Preuve structurelle du journal invalide.')


def _assert_snapshot(expected, actual):
    if expected['schemas'] != actual['schemas'] or expected['sha256'] != actual['sha256']:
        detail = '; '.join(snapshot_differences(expected, actual))
        raise MigrationError('Le schéma réel diffère du dernier état attesté. ' + detail)


def _create_ledger(conn):
    _execute(conn, '''CREATE TABLE systeme."T_MigrationSchema" (
        "Identifiant" text PRIMARY KEY,
        "EmpreinteFichier" varchar(64) NOT NULL CHECK ("EmpreinteFichier" ~ '^[0-9a-f]{64}$'),
        "Nature" text NOT NULL CHECK ("Nature" IN ('socle','migration')),
        "Description" text NOT NULL,"VersionApplication" text NOT NULL,
        "AppliqueLe" timestamptz NOT NULL DEFAULT clock_timestamp(),
        "DureeMs" bigint NOT NULL CHECK ("DureeMs">=0),
        "Dependances" jsonb NOT NULL CHECK (jsonb_typeof("Dependances")='array'),
        "Position" integer UNIQUE NOT NULL CHECK ("Position">=0),
        "EmpreinteStructure" varchar(64) NOT NULL CHECK ("EmpreinteStructure" ~ '^[0-9a-f]{64}$'),
        "Structure" jsonb NOT NULL CHECK (jsonb_typeof("Structure")='object'));
        COMMENT ON TABLE systeme."T_MigrationSchema" IS 'Journal technique immuable des socles attestés et migrations métier réussies, sans données clientes. Écrit exclusivement par la maintenance de déploiement.';
        REVOKE ALL ON TABLE systeme."T_MigrationSchema" FROM PUBLIC;''')
    comments = {
        'Identifiant': 'Identité stable du socle ou de la migration, unique par base.',
        'EmpreinteFichier': 'SHA-256 du fichier UTF-8 normalisé LF effectivement validé.',
        'Nature': 'socle : catalogue déjà présent vérifié ; migration : SQL exécuté avec succès.',
        'Description': 'Objet de la livraison technique, sans secret ni donnée métier.',
        'VersionApplication': 'Version applicative déclarée par la livraison du schéma.',
        'AppliqueLe': 'Instant serveur de validation de cette entrée de maintenance.',
        'DureeMs': 'Durée de la vérification et de l’application, en millisecondes.',
        'Dependances': 'Identifiants des migrations préalables explicitement requis.',
        'Position': 'Position séquentielle depuis le socle numéro zéro.',
        'EmpreinteStructure': 'Empreinte du catalogue métier après validation, hors journal.',
        'Structure': 'Empreintes par objet du catalogue, sans lignes ni valeurs de séquence.',
    }
    for column, comment in comments.items():
        _execute(conn, 'COMMENT ON COLUMN systeme."T_MigrationSchema"."' + column + '" IS %s', [comment])
    # Les privilèges par défaut d'un propriétaire peuvent accorder le DML au rôle
    # applicatif : le journal reste exclusivement inscriptible par maintenance.
    if _rows(conn, "SELECT 1 FROM pg_roles WHERE rolname='sauverndeko_runtime'"):
        _execute(conn, 'REVOKE ALL ON TABLE systeme."T_MigrationSchema" FROM sauverndeko_runtime')
        _execute(conn, 'GRANT SELECT ON TABLE systeme."T_MigrationSchema" TO sauverndeko_runtime')


def _record(conn, entry, snapshot, position, started, release=None):
    _execute(conn, '''INSERT INTO systeme."T_MigrationSchema"
        ("Identifiant","EmpreinteFichier","Nature","Description","VersionApplication","DureeMs",
         "Dependances","Position","EmpreinteStructure","Structure")
        VALUES (%s,%s,%s,%s,%s,%s,%s::jsonb,%s,%s,%s::jsonb)''', [
        entry['id'], entry['sha256'], entry['nature'], entry['description'],
        release or entry['release'], max(0, round((time.monotonic()-started)*1000)),
        json.dumps(entry['dependsOn']), position, snapshot['sha256'],
        json.dumps(snapshot, ensure_ascii=False, separators=(',', ':'))])


def _timeouts(conn, lock_timeout_ms, statement_timeout_ms):
    _execute(conn, 'SELECT set_config(%s,%s,true),set_config(%s,%s,true)',
             ['lock_timeout', str(lock_timeout_ms), 'statement_timeout', str(statement_timeout_ms)])


def run_migrations(connection, manifest_path, *, apply=False, baseline_path=None, check=False,
                   release=None, lock_timeout_ms=10000, statement_timeout_ms=120000):
    """Plan sans écriture ; --apply exige un socle déjà attesté ou explicite.

    Aucune sauvegarde, restauration, attribution de version ou création de base
    n'est implicite. Le compte de maintenance et la fenêtre sont choisis dehors.
    """
    manifest = load_manifest(manifest_path)
    if check and (apply or baseline_path):
        raise MigrationError('--check ne se combine pas avec une écriture ou un socle explicite.')
    if not 100 <= lock_timeout_ms <= 60000 or not 1000 <= statement_timeout_ms <= 3600000:
        raise MigrationError('Délais de maintenance hors limites.')
    if release is not None and (not isinstance(release, str) or not release.strip() or len(release) > 128):
        raise MigrationError('Version applicative non conforme.')
    if baseline_path is not None and Path(baseline_path).resolve() != manifest['_baselinePath']:
        raise MigrationError('Le socle explicite doit être celui du manifeste vérifié.')
    if apply and (connection.in_atomic_block or not connection.get_autocommit()):
        raise MigrationError('L’application exige une connexion de maintenance hors transaction existante.')
    locked = False
    applied = []
    try:
        if apply:
            readonly, user = _rows(connection, 'SELECT current_setting(%s),current_user', ['default_transaction_read_only'])[0]
            if readonly == 'on' or user == 'sauverndeko_runtime':
                raise MigrationError('Utiliser explicitement une connexion de maintenance autorisant les écritures.')
            locked = bool(_rows(connection, 'SELECT pg_try_advisory_lock(hashtextextended(%s,0))', [LOCK_NAME])[0][0])
            if not locked:
                raise MigrationError('Une autre mise à jour de schéma est en cours. Aucun changement effectué.')
        with transaction.atomic(using=connection.alias):
            if not apply:
                _execute(connection, 'SET TRANSACTION ISOLATION LEVEL REPEATABLE READ, READ ONLY')
            _timeouts(connection, lock_timeout_ms, statement_timeout_ms)
            journal_exists = _ledger_exists(connection)
            if journal_exists:
                _verify_ledger_shape(connection)
            actual = build_schema_snapshot(connection)
            ledger = _read_ledger(connection) if journal_exists else []
            present = bool(ledger)
            if present:
                _verify_history(manifest, ledger)
                _assert_snapshot(ledger[-1]['snapshot'], actual)
                if baseline_path is not None and len(ledger) != 1:
                    raise MigrationError('Une base déjà mise à jour ne peut pas être réattestée au socle initial.')
            else:
                _assert_snapshot(manifest['_baseline'], actual)
                if check:
                    raise MigrationError('Socle non attesté : effectuer la vérification et l’inscription explicites avant déploiement.')
                if apply:
                    if baseline_path is None:
                        raise MigrationError('Socle non attesté : --baseline est obligatoire pour la première inscription.')
                    started = time.monotonic()
                    if not journal_exists:
                        _create_ledger(connection)
                    _verify_ledger_shape(connection)
                    entry = {**manifest['_baseline'], 'sha256': manifest['baseline']['sha256'],
                             'nature': 'socle', 'dependsOn': []}
                    _record(connection, entry, actual, 0, started, release)
                    applied.append(entry['id'])
                    ledger = _read_ledger(connection)
                    _verify_history(manifest, ledger)
            pending = manifest['migrations'][max(0, len(ledger)-1):] if present or apply else manifest['migrations']
            if check and pending:
                raise MigrationError('Migrations métier en attente : ' + ', '.join(row['id'] for row in pending))
        # Une attestation explicite fait seulement l'attestation, jamais un lot
        # d'évolutions dans son sillage. La commande standard applique ensuite.
        if apply and baseline_path is None:
            for offset, item in enumerate(pending, start=len(ledger)):
                started = time.monotonic()
                with transaction.atomic(using=connection.alias):
                    _timeouts(connection, lock_timeout_ms, statement_timeout_ms)
                    _assert_snapshot(ledger[-1]['snapshot'], build_schema_snapshot(connection))
                    _execute(connection, item['_sql'])
                    snapshot = build_schema_snapshot(connection)
                    entry = {**item, 'nature': 'migration'}
                    _record(connection, entry, snapshot, offset, started, release)
                    _verify_ledger_shape(connection)
                    ledger = _read_ledger(connection)
                    _verify_history(manifest, ledger)
                applied.append(item['id'])
        return {'mode': 'check' if check else 'apply' if apply else 'plan',
                'baselineAttested': bool(present or apply), 'baseline': manifest['baseline']['id'],
                'applied': applied, 'pending': [row['id'] for row in pending if row['id'] not in applied],
                'upToDate': bool(present or apply) and not [row for row in pending if row['id'] not in applied],
                'schemaSha256': ledger[-1]['schemaSha256'] if ledger else actual['sha256']}
    except DatabaseError as error:
        state = getattr(error.__cause__, 'sqlstate', None)
        suffix = f' (SQLSTATE {state})' if state and re.fullmatch(r'[0-9A-Z]{5}', state) else ''
        raise MigrationError('Migration refusée par PostgreSQL ; la transaction courante a été annulée' + suffix + '.') from None
    finally:
        if locked:
            try:
                _rows(connection, 'SELECT pg_advisory_unlock(hashtextextended(%s,0))', [LOCK_NAME])
            except DatabaseError:
                connection.close()
