"""Migration 05 et compteurs liés : PostgreSQL privé uniquement, aucune donnée réelle."""
import hashlib
import json
import os
import re
import uuid
from pathlib import Path
from urllib.parse import urlsplit

import psycopg
from psycopg.rows import dict_row

ROOT = Path(__file__).resolve().parents[2]
DSN = os.environ.get('SAUVERNDEKO_TEST_DATABASE_URL', '')
TARGET = urlsplit(DSN)
if TARGET.hostname not in {'localhost', '127.0.0.1'} or not TARGET.path[1:].startswith('sauverndeko_test_'):
    raise RuntimeError('Recette réservée à une base privée locale sauverndeko_test_*.')
MIGRATION = ROOT / 'backend/database/migrations/20261030_05_compteurs_territoriaux.sql'
SQL = MIGRATION.read_text(encoding='utf8')
COUNTERS = {0: ('Nb_Niveau_1',), 1: ('Nb_Niveau_2',), 2: ('Nb_Niveau_3',),
            3: ('Nb_Niveau_4', 'Nb_Niveau_5'), 4: ('Nb_Niveau_5',), 5: ()}
KEYS = {n: 'territoires.niveaux-' + key for n, key in enumerate(('zero', 'un', 'deux', 'trois', 'quatre', 'cinq'))}
checks = 0


def check(condition, message):
    global checks
    if not condition:
        raise AssertionError(message)
    checks += 1


def quoted(name):
    return '"' + name.replace('"', '""') + '"'


def table_fingerprints(connection):
    tables = connection.execute("SELECT n.nspname AS schema,c.relname AS name FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE c.relkind='r' AND n.nspname NOT IN ('pg_catalog','information_schema') AND n.nspname NOT LIKE 'pg_%' ORDER BY 1,2").fetchall()
    return {row['schema'] + '.' + row['name']: connection.execute(
        'SELECT count(*) AS count,md5(COALESCE(string_agg(md5(to_jsonb(t)::text),\'\' ORDER BY md5(to_jsonb(t)::text)),\'\')) AS fingerprint FROM '
        + quoted(row['schema']) + '.' + quoted(row['name']) + ' t').fetchone() for row in tables}


def catalogues(connection):
    return {row['CleInterface']: row for row in connection.execute('SELECT * FROM referentiel."T_InterfaceTableau" ORDER BY "CleInterface"').fetchall()}


def view_columns(connection, n):
    return connection.execute("SELECT a.attname AS name,format_type(a.atttypid,a.atttypmod) AS type,col_description(a.attrelid,a.attnum) AS comment FROM pg_attribute a WHERE a.attrelid=%s::regclass AND a.attnum>0 AND NOT a.attisdropped ORDER BY a.attnum", ['geolocalisation."V_Niveau_' + str(n) + '"']).fetchall()


def projection_fingerprint(connection, n, columns):
    sql = 'SELECT count(*) AS count,md5(COALESCE(string_agg(md5(to_jsonb(t)::text),\'\' ORDER BY md5(to_jsonb(t)::text)),\'\')) AS fingerprint FROM (SELECT ' + ','.join(quoted(col['name']) for col in columns) + ' FROM geolocalisation."V_Niveau_' + str(n) + '") t'
    return connection.execute(sql).fetchone()


with psycopg.connect(DSN, autocommit=True, row_factory=dict_row) as connection:
    before = table_fingerprints(connection)
    old_catalogues = catalogues(connection)
    old_columns = {n: view_columns(connection, n) for n in range(6)}
    old_projections = {n: projection_fingerprint(connection, n, old_columns[n]) for n in range(6)}
    connection.execute(SQL)
    after = table_fingerprints(connection)
    changed = [name for name in before if before[name] != after[name]]
    check(set(before) == set(after), 'Aucune table métier ne doit être ajoutée ou retirée.')
    check(set(changed) <= {'referentiel.T_InterfaceTableau'}, 'Aucune donnée métier ou préférence personnelle ne doit changer.')
    new_catalogues = catalogues(connection)
    changed_catalogues = [key for key in old_catalogues if old_catalogues[key] != new_catalogues[key]]
    check(set(changed_catalogues) <= set(KEYS.values()), 'Seuls les six catalogues territoriaux peuvent changer.')
    new_column_count = 0
    documented_additions = re.findall(r'COMMENT ON COLUMN geolocalisation\."(V_Niveau_[0-5])"\."([^"]+)" IS', SQL)
    for view_name, column_name in documented_additions:
        column = next((c for c in view_columns(connection, int(view_name[-1])) if c['name'] == column_name), None)
        check(column is not None and bool(column['comment']), 'Chaque ajout déclaré par la migration doit exister et être documenté, même après rejeu.')
    for n in range(6):
        current = view_columns(connection, n)
        check([(c['name'], c['type']) for c in current[:len(old_columns[n])]] == [(c['name'], c['type']) for c in old_columns[n]], 'Les colonnes historiques doivent garder nom, type et position : niveau ' + str(n))
        check(projection_fingerprint(connection, n, old_columns[n]) == old_projections[n], 'Les valeurs historiques de la vue doivent être strictement conservées : niveau ' + str(n))
        for column in current[len(old_columns[n]):]:
            check(bool(column['comment']), 'Chaque nouvelle colonne doit posséder son COMMENT ON.')
            new_column_count += 1
        old = old_catalogues[KEYS[n]]; new = new_catalogues[KEYS[n]]
        old_by_id = {col['id']: col for col in old['Colonnes']}; new_by_id = {col['id']: col for col in new['Colonnes']}
        check(len(new_by_id) == len(new['Colonnes']), 'Aucune colonne dupliquée dans le catalogue.')
        check(all(new_by_id[name] == definition for name, definition in old_by_id.items()), 'Aucune définition commune préexistante ne doit être écrasée.')
        check(new['Version'] == old['Version'] + (1 if old['Colonnes'] != new['Colonnes'] else 0), 'Une seule augmentation de version pour un catalogue complété.')
        physical = {col['name'] for col in current}
        check(set(new_by_id) - {'actions'} <= physical, 'Le catalogue ne doit proposer que de vraies colonnes SQL.')
        for name in COUNTERS[n]:
            check(name in new_by_id and new_by_id[name]['type'] == 'bigint', 'Le compteur exact doit être disponible dans les colonnes et exports.')
            if name not in old_by_id:
                check(new_by_id[name]['defaultVisible'] and new_by_id[name]['defaultExport'], 'Le compteur nouvellement ajouté est proposé par défaut aux comptes non personnalisés.')
        if 'actions' in new_by_id:
            check(all(col['defaultOrder'] < new_by_id['actions']['defaultOrder'] for col in new['Colonnes'] if col['id'] not in old_by_id), 'Les nouvelles colonnes viennent avant Actions sans déplacer les anciennes.')
    first_replay = catalogues(connection)
    connection.execute(SQL)
    check(catalogues(connection) == first_replay, 'Le rejeu ne doit pas augmenter les versions ni réécrire les colonnes.')
    check(table_fingerprints(connection) == after, 'Le rejeu de la migration doit laisser toutes les lignes inchangées.')

    # Personnalisation fictive dans une transaction toujours annulée.
    unwrapped = re.sub(r'^BEGIN;\s*', '', SQL, count=1, flags=re.M)
    unwrapped = re.sub(r'^COMMIT;\s*$', '', unwrapped, count=1, flags=re.M)
    with connection.transaction(force_rollback=True):
        row = connection.execute('SELECT "Colonnes" FROM referentiel."T_InterfaceTableau" WHERE "CleInterface"=%s', [KEYS[0]]).fetchone()
        definitions = row['Colonnes']
        for col in definitions:
            if col['id'] == 'Nb_Niveau_1':
                col.update(label='Compteur personnalisé fictif', defaultVisible=False, defaultExport=False)
        connection.execute('UPDATE referentiel."T_InterfaceTableau" SET "Colonnes"=%s::jsonb WHERE "CleInterface"=%s', [json.dumps(definitions), KEYS[0]])
        custom = catalogues(connection)
        connection.execute(unwrapped)
        check(catalogues(connection) == custom, 'Un rejeu ne doit pas écraser un compteur déjà personnalisé.')

    # Arbre privé : homonymes possibles, parents vides, fusion, sites sans aire et zone déduite de l’aire.
    with connection.transaction(force_rollback=True):
        marker = 'Compteur fictif ' + uuid.uuid4().hex
        def insert(n, **values):
            values['NomNiveau_' + str(n)] = marker + ' ' + str(n) + '-' + uuid.uuid4().hex[:8]
            return connection.execute('INSERT INTO geolocalisation."T_Niveau_' + str(n) + '" (' + ','.join(quoted(k) for k in values) + ') VALUES (' + ','.join('%s' for _ in values) + ') RETURNING *', list(values.values())).fetchone()
        def pk(row, n):
            return row['ID_Niveau_' + str(n)]
        country = insert(0); empty_country = insert(0)
        province = insert(1, ID_Niveau_0_Fk=pk(country, 0), FusionNiveau_1=False)
        fused_province = insert(1, ID_Niveau_0_Fk=pk(country, 0), FusionNiveau_1=True)
        null_fusion_province = insert(1, ID_Niveau_0_Fk=pk(country, 0), FusionNiveau_1=None)
        antenna = insert(2, ID_Niveau_1_FK=pk(province, 1)); empty_antenna = insert(2, ID_Niveau_1_FK=pk(province, 1))
        zone = insert(3, ID_Niveau_2_FK=pk(antenna, 2)); empty_zone = insert(3, ID_Niveau_2_FK=pk(antenna, 2))
        area1 = insert(4, ID_Niveau_3_Fk=pk(zone, 3)); area2 = insert(4, ID_Niveau_3_Fk=pk(zone, 3)); empty_area = insert(4, ID_Niveau_3_Fk=pk(empty_zone, 3))
        for area in (area1, area1, area2):
            insert(5, ID_Niveau_4_Fk=pk(area, 4), ID_Niveau_3_Fk=pk(zone, 3))
        insert(5, ID_Niveau_4_Fk=pk(area2, 4), ID_Niveau_3_Fk=None)
        insert(5, ID_Niveau_4_Fk=None, ID_Niveau_3_Fk=pk(zone, 3))
        unassigned = insert(5, ID_Niveau_4_Fk=None, ID_Niveau_3_Fk=None)
        expected = [(0, country, {'Nb_Niveau_1': 3}), (0, empty_country, {'Nb_Niveau_1': 0}),
                    (1, province, {'Nb_Niveau_2': 2}), (1, fused_province, {'Nb_Niveau_2': 0}),
                    (2, antenna, {'Nb_Niveau_3': 2}), (2, empty_antenna, {'Nb_Niveau_3': 0}),
                    (3, zone, {'Nb_Niveau_4': 2, 'Nb_Niveau_5': 5}), (3, empty_zone, {'Nb_Niveau_4': 1, 'Nb_Niveau_5': 0}),
                    (4, area1, {'Nb_Niveau_5': 2}), (4, area2, {'Nb_Niveau_5': 2}), (4, empty_area, {'Nb_Niveau_5': 0})]
        for n, parent, counters in expected:
            row = connection.execute('SELECT * FROM geolocalisation."V_Niveau_' + str(n) + '" WHERE "ID_Niveau_' + str(n) + '"=%s', [pk(parent, n)]).fetchone()
            for name, count in counters.items():
                check(row[name] == count, 'Comptage exact sans jointure multiplicative : niveau ' + str(n) + ', ' + name)
        for n, parent, counters in expected:
            for name in counters:
                child = int(name[-1])
                fk = ('ID_Niveau_3' if n == 3 and child == 5 else 'ID_Niveau_' + str(n) + '_' + ('Fk' if n in {0, 3, 4} else 'FK'))
                actual = connection.execute('SELECT count(*) n FROM geolocalisation."V_Niveau_' + str(child) + '" WHERE ' + quoted(fk) + '=%s', [pk(parent, n)]).fetchone()['n']
                check(actual == counters[name], 'La liste ciblée par le clic doit avoir exactement le même effectif que le compteur.')
        row = connection.execute('SELECT * FROM geolocalisation."V_Niveau_5" WHERE "ID_Niveau_5"=%s', [pk(unassigned, 5)]).fetchone()
        check(row is not None and row['NomNiveau_4'] is None and row['ID_Niveau_3'] is None, 'Un site sans rattachement reste visible sans parent inventé.')
        check(connection.execute('SELECT "NomNiveau_0","NomNiveau_1","NomNiveau_2" FROM geolocalisation."V_Niveau_3" WHERE "ID_Niveau_3"=%s', [pk(zone, 3)]).fetchone() == {'NomNiveau_0': country['NomNiveau_0'], 'NomNiveau_1': province['NomNiveau_1'], 'NomNiveau_2': antenna['NomNiveau_2']}, 'Les noms des ancêtres proviennent des tables parent réelles.')
        for area in (area1, area2, empty_area):
            observed = connection.execute('SELECT v."AvecReseau",g."AbrGenerique" FROM geolocalisation."V_Niveau_4" v LEFT JOIN referentiel."T_Generique" g ON g."ID_Generique"=v."ID_DispoReseauNiveau_4" WHERE v."ID_Niveau_4"=%s', [pk(area, 4)]).fetchone()
            check(observed['AvecReseau'] == (observed['AbrGenerique'] is not None and observed['AbrGenerique'] != 'Sans reseau'), 'Le dérivé réseau doit reprendre exactement le prédicat du rapport existant.')
        check(connection.execute('SELECT count(*) AS n FROM geolocalisation."V_Niveau_5" v JOIN geolocalisation."T_Niveau_4" a ON a."ID_Niveau_4"=v."ID_Niveau_4_Fk" WHERE v."ID_Niveau_3"=%s AND v."ID_TypeNiveau_4_Fk" IS DISTINCT FROM a."ID_TypeNiveau_4_Fk"', [pk(zone, 3)]).fetchone()['n'] == 0, 'Le type d’aire dérivé doit provenir de la véritable aire du site.')
    check(table_fingerprints(connection) == after, 'Tous les exemples privés et personnalisations doivent être annulés.')

result = {'success': True, 'checks': checks, 'privateDatabase': TARGET.path[1:],
          'migration': MIGRATION.name, 'sha256': hashlib.sha256(MIGRATION.read_bytes()).hexdigest(),
          'tablesChecked': len(before), 'changedTables': changed, 'changedCatalogues': changed_catalogues,
          'viewsChecked': 6, 'newViewColumns': new_column_count, 'sourceMutations': False,
          'documentedMigrationColumns': len(documented_additions),
          'privateFixturesRolledBack': True, 'existingDefinitionsPreserved': True, 'personalPreferencesPreserved': True}
(ROOT / '.runtime/territoires-compteurs-tests.json').write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding='utf8')
print(json.dumps(result, ensure_ascii=False))
