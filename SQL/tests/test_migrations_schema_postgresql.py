"""Mises à jour du schéma : recette transactionnelle sur copie privée locale.

Aucun repli vers DATABASE_URL. Cette suite crée ses objets fictifs et son journal
dans une base sauverndeko_test_* sans journal préalable, puis les retire. Les
tables et données métier préexistantes ne sont jamais supprimées ni corrigées.
"""
from io import StringIO
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from urllib.parse import unquote, urlsplit
import uuid

DSN = os.environ.get('SAUVERNDEKO_TEST_DATABASE_URL', '')
TARGET = urlsplit(DSN)
DATABASE = unquote(TARGET.path.lstrip('/'))
if (TARGET.scheme not in {'postgres', 'postgresql'}
        or TARGET.hostname not in {'localhost', '127.0.0.1', '::1'}
        or not DATABASE.startswith('sauverndeko_test_')):
    raise RuntimeError('Copie privée locale sauverndeko_test_* obligatoire ; aucun repli source.')

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'backend'))
os.environ.update(
    DATABASE_URL=DSN, DJANGO_SETTINGS_MODULE='config.settings',
    SAUVERNDEKO_DB_READ_ONLY='0', DJANGO_SECRET_KEY='private-schema-recipe',
    JWT_SECRET='private-schema-recipe', JWT_REFRESH_SECRET='private-schema-recipe',
)

import django
django.setup()
from django.core.management import call_command
from django.core.management.base import CommandError
from django.db import DatabaseError, connection, transaction
from django.test import override_settings
import psycopg
from apps.core.schema_migrations import (
    LOCK_NAME, MigrationError, build_schema_snapshot, run_migrations, sha256_file,
)

LEDGER = 'systeme."T_MigrationSchema"'


def execute(statement, params=None):
    with connection.cursor() as cursor:
        cursor.execute(statement, params)
        return cursor.fetchall() if cursor.description else []


def scalar(statement, params=None):
    return execute(statement, params)[0][0]


class SchemaMigrationsPostgreSQL(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        if scalar('SELECT current_database()') != DATABASE:
            raise RuntimeError('Identité de copie privée incohérente ; recette interrompue.')
        if not connection.get_autocommit():
            raise RuntimeError('La recette exige une connexion privée autonome en autocommit.')
        if scalar('SELECT to_regclass(%s)', [LEDGER]) is not None:
            raise RuntimeError('Recette réservée à une copie privée sans journal de migrations préexistant.')
        cls.initial_snapshot = build_schema_snapshot(connection)

    @classmethod
    def tearDownClass(cls):
        try:
            if scalar('SELECT to_regclass(%s)', [LEDGER]) is not None:
                raise AssertionError('Le journal fictif de recette n’a pas été retiré.')
            if build_schema_snapshot(connection) != cls.initial_snapshot:
                raise AssertionError('La recette a laissé une modification structurelle inattendue.')
        finally:
            connection.close()
            super().tearDownClass()

    def setUp(self):
        self.tag = uuid.uuid4().hex[:12]
        self.table_name = 'recette_schema_' + self.tag
        self.table = 'analytics."' + self.table_name + '"'
        self.extra = self.table_name + '_extra'
        self.view = self.table_name + '_vue'
        self.function = self.table_name + '_controle'
        execute('CREATE TABLE ' + self.table + ' (id integer PRIMARY KEY, libelle text NOT NULL)')
        execute('COMMENT ON TABLE ' + self.table + " IS 'Données fictives de recette des migrations'")
        execute('INSERT INTO ' + self.table + " VALUES (1,'Premier client fictif'),(2,'Deuxième client fictif'),(3,'Troisième client fictif')")
        self.rows = execute('SELECT id,libelle FROM ' + self.table + ' ORDER BY id')
        self.directory = tempfile.TemporaryDirectory(prefix='.recette-migrations-', dir=ROOT / 'SQL')
        self.package = Path(self.directory.name)
        self.releases = self.package / 'releases'
        self.scripts = self.package / 'migrations'
        self.releases.mkdir()
        self.scripts.mkdir()
        self.manifest_path = self.releases / 'manifest.json'
        self.baseline_path = self.releases / 'baseline.json'
        self.legacy = self.scripts / 'historique.sql'
        self.legacy.write_text('-- Historique fictif : ne doit jamais être exécuté.\n', encoding='utf8')
        self.snapshot = build_schema_snapshot(connection)
        self.baseline = {
            'format': 1, 'hashAlgorithm': 'sha256-utf8-lf-v1',
            'id': 'socle_recette', 'description': 'Socle privé de recette',
            'release': 'recette', **self.snapshot,
            'legacyMigrations': [{'file': self.legacy.name, 'sha256': sha256_file(self.legacy)}],
        }
        self.write_json(self.baseline_path, self.baseline)
        self.manifest = {
            'format': 1, 'hashAlgorithm': 'sha256-utf8-lf-v1',
            'baseline': {'id': self.baseline['id'], 'file': self.baseline_path.name,
                         'sha256': sha256_file(self.baseline_path)},
            'migrations': [],
        }
        self.write_manifest()

    def tearDown(self):
        try:
            # Ces noms sont fixes ou générés par cette suite, jamais des noms
            # découverts dans une base cliente ou une suppression de schéma.
            execute('DROP TABLE IF EXISTS ' + LEDGER)
            execute('DROP VIEW IF EXISTS analytics."' + self.view + '"')
            execute('DROP TABLE IF EXISTS analytics."' + self.extra + '"')
            execute('DROP TABLE IF EXISTS ' + self.table)
            execute('DROP FUNCTION IF EXISTS analytics."' + self.function + '"()')
        finally:
            self.directory.cleanup()

    @staticmethod
    def write_json(path, payload):
        path.write_text(json.dumps(payload, ensure_ascii=False, sort_keys=True, indent=2) + '\n', encoding='utf8')

    def write_manifest(self):
        self.write_json(self.manifest_path, self.manifest)

    def attest(self):
        return run_migrations(connection, self.manifest_path, apply=True,
                              baseline_path=self.baseline_path)

    def migrate(self, **options):
        return run_migrations(connection, self.manifest_path, **options)

    def add_migration(self, sql, identifier='m001', depends=None, description='Évolution privée de recette'):
        path = self.scripts / (identifier + '.sql')
        path.write_text(sql, encoding='utf8')
        self.manifest['migrations'].append({
            'id': identifier, 'file': '../migrations/' + path.name,
            'sha256': sha256_file(path),
            'dependsOn': depends if depends is not None else [self.manifest['baseline']['id']],
            'description': description, 'release': 'recette',
        })
        self.write_manifest()
        return path

    def count_ledger(self):
        return scalar('SELECT count(*) FROM ' + LEDGER) if scalar('SELECT to_regclass(%s)', [LEDGER]) else 0

    def assert_rows_preserved(self):
        self.assertEqual(execute('SELECT id,libelle FROM ' + self.table + ' ORDER BY id'), self.rows)

    def assert_refused(self, operation):
        with self.assertRaises(MigrationError):
            operation()
        self.assert_rows_preserved()

    def test_01_plan_unattested_never_creates_ledger_or_changes_schema(self):
        try:
            self.migrate()
        except MigrationError:
            pass  # Le plan peut signaler explicitement l’absence d’attestation.
        self.assertEqual(self.count_ledger(), 0)
        self.assertEqual(build_schema_snapshot(connection), self.snapshot)
        self.assert_refused(lambda: self.migrate(apply=True))

    def test_02_attestation_requires_exact_fingerprint_and_preserves_data(self):
        self.attest()
        self.assertEqual(self.count_ledger(), 1)
        self.assertEqual(build_schema_snapshot(connection), self.snapshot)
        self.assert_rows_preserved()
        self.attest()
        self.assertEqual(self.count_ledger(), 1)

    def test_03_baseline_drift_refused_before_journal_creation(self):
        execute('ALTER TABLE ' + self.table + ' ADD COLUMN changement_inattendu text')
        self.assert_refused(self.attest)
        self.assertEqual(self.count_ledger(), 0)

    def test_04_wrong_baseline_file_hash_refused(self):
        self.manifest['baseline']['sha256'] = '0' * 64
        self.write_manifest()
        self.assert_refused(self.attest)
        self.assertEqual(self.count_ledger(), 0)

    def test_05_historical_file_change_refused_without_replay(self):
        self.legacy.write_text('SELECT 1; -- Fichier historique modifié\n', encoding='utf8')
        self.assert_refused(self.attest)
        self.assertEqual(self.count_ledger(), 0)

    def test_06_add_column_table_view_function_trigger_and_replay(self):
        self.attest()
        self.add_migration('''
ALTER TABLE %s ADD COLUMN telephone_secondaire text;
COMMENT ON COLUMN %s.telephone_secondaire IS 'Contact facultatif ajouté sans supprimer les clients';
CREATE TABLE analytics."%s" (id integer PRIMARY KEY, client_id integer REFERENCES %s(id));
COMMENT ON TABLE analytics."%s" IS 'Table complémentaire fictive';
CREATE FUNCTION analytics."%s"() RETURNS trigger LANGUAGE plpgsql AS $controle$
BEGIN
 IF NEW.client_id IS NULL THEN RAISE EXCEPTION 'Client fictif requis'; END IF;
 RETURN NEW;
END;
$controle$;
COMMENT ON FUNCTION analytics."%s"() IS 'Contrôle fictif de relation';
CREATE TRIGGER controle_recette BEFORE INSERT ON analytics."%s"
FOR EACH ROW EXECUTE FUNCTION analytics."%s"();
CREATE VIEW analytics."%s" AS SELECT id,libelle,telephone_secondaire FROM %s;
COMMENT ON VIEW analytics."%s" IS 'Lecture fictive du nouveau champ';
''' % (self.table, self.table, self.extra, self.table, self.extra,
       self.function, self.function, self.extra, self.function, self.view,
       self.table, self.view))
        self.migrate(apply=True)
        self.assertEqual(self.count_ledger(), 2)
        self.assert_rows_preserved()
        self.assertEqual(execute('SELECT telephone_secondaire FROM ' + self.table), [(None,)] * 3)
        execute('UPDATE ' + self.table + " SET telephone_secondaire='0800000000' WHERE id=1")
        self.assertEqual(scalar('SELECT telephone_secondaire FROM analytics."' + self.view + '" WHERE id=1'), '0800000000')
        execute('INSERT INTO analytics."' + self.extra + '" VALUES(1,1)')
        with self.assertRaises(DatabaseError):
            execute('INSERT INTO analytics."' + self.extra + '" VALUES(2,NULL)')
        after = build_schema_snapshot(connection)
        self.migrate(apply=True)
        self.assertEqual(self.count_ledger(), 2)
        self.assertEqual(build_schema_snapshot(connection), after)
        self.assertEqual(scalar('SELECT count(*) FROM analytics."' + self.extra + '"'), 1)

    def test_07_pending_plan_and_check_never_write(self):
        self.attest()
        self.add_migration('ALTER TABLE ' + self.table + ' ADD COLUMN complement text;')
        self.migrate()
        self.assertEqual(build_schema_snapshot(connection), self.snapshot)
        self.assertEqual(self.count_ledger(), 1)
        self.assert_refused(lambda: self.migrate(check=True))
        self.assertEqual(self.count_ledger(), 1)

    def test_08_failed_migration_rolls_back_ddl_data_and_ledger(self):
        self.attest()
        self.add_migration('ALTER TABLE ' + self.table + ' ADD COLUMN jamais_validee text;\n'
            'CREATE TABLE analytics."' + self.extra + '" (id integer);\n'
            'UPDATE ' + self.table + " SET libelle='Ne doit pas rester';\n"
            "DO $refus$ BEGIN RAISE EXCEPTION 'Erreur métier fictive'; END $refus$;\n")
        self.assert_refused(lambda: self.migrate(apply=True))
        self.assertEqual(self.count_ledger(), 1)
        self.assertEqual(build_schema_snapshot(connection), self.snapshot)
        self.assertIsNone(scalar('SELECT to_regclass(%s)', ['analytics."' + self.extra + '"']))

    def test_09_valid_chain_applies_in_dependency_order(self):
        self.attest()
        self.add_migration('ALTER TABLE ' + self.table + ' ADD COLUMN ordre integer;', 'm001')
        self.add_migration('UPDATE ' + self.table + ' SET ordre=id;', 'm002', ['m001'])
        self.migrate(apply=True)
        self.assertEqual(execute('SELECT id,ordre FROM ' + self.table + ' ORDER BY id'), [(1,1), (2,2), (3,3)])
        self.assertEqual(self.count_ledger(), 3)
        self.assert_rows_preserved()

    def test_10_missing_dependency_refused_before_any_ddl(self):
        self.attest()
        self.add_migration('ALTER TABLE ' + self.table + ' ADD COLUMN impossible text;', depends=['inconnue'])
        self.assert_refused(lambda: self.migrate(apply=True))
        self.assertEqual(build_schema_snapshot(connection), self.snapshot)
        self.assertEqual(self.count_ledger(), 1)

    def test_11_migration_file_checksum_change_refused(self):
        self.attest()
        path = self.add_migration('ALTER TABLE ' + self.table + ' ADD COLUMN controle text;')
        path.write_text('ALTER TABLE ' + self.table + ' ADD COLUMN autre text;\n', encoding='utf8')
        self.assert_refused(lambda: self.migrate(apply=True))
        self.assertEqual(build_schema_snapshot(connection), self.snapshot)

    def test_12_already_applied_file_cannot_be_rewritten_even_with_new_manifest_hash(self):
        self.attest()
        path = self.add_migration('ALTER TABLE ' + self.table + ' ADD COLUMN controle text;')
        self.migrate(apply=True)
        path.write_text('ALTER TABLE ' + self.table + ' ADD COLUMN autre text;\n', encoding='utf8')
        self.manifest['migrations'][0]['sha256'] = sha256_file(path)
        self.write_manifest()
        after = build_schema_snapshot(connection)
        self.assert_refused(lambda: self.migrate(apply=True))
        self.assertEqual(self.count_ledger(), 2)
        self.assertEqual(build_schema_snapshot(connection), after)

    def test_13_structural_drift_after_attestation_is_refused(self):
        self.attest()
        execute('COMMENT ON TABLE ' + self.table + " IS 'Modification structurelle hors migration'")
        self.add_migration('ALTER TABLE ' + self.table + ' ADD COLUMN futur text;')
        self.assert_refused(lambda: self.migrate(apply=True))
        self.assertEqual(self.count_ledger(), 1)

    def test_14_transaction_escape_scripts_refused_before_any_ddl(self):
        self.attest()
        for index, statement in enumerate(('BEGIN;', 'COMMIT;', 'ROLLBACK;', 'END;',
                'START TRANSACTION;', 'SET TRANSACTION READ ONLY;', '\\echo metacommande')):
            with self.subTest(statement=statement):
                self.manifest['migrations'] = []
                self.add_migration('ALTER TABLE ' + self.table + ' ADD COLUMN echappee text;\n' + statement,
                                   identifier='unsafe' + str(index))
                self.assert_refused(lambda: self.migrate(apply=True))
                self.assertEqual(build_schema_snapshot(connection), self.snapshot)
                self.assertEqual(self.count_ledger(), 1)

    def test_15_transaction_words_inside_literals_are_not_misread(self):
        self.attest()
        self.add_migration('ALTER TABLE ' + self.table + ' ADD COLUMN note text;\n'
            'UPDATE ' + self.table + " SET note='COMMIT; BEGIN; ROLLBACK;';\n"
            '-- COMMIT; ce commentaire ne contrôle pas de transaction\n')
        self.migrate(apply=True)
        self.assertEqual(scalar('SELECT note FROM ' + self.table + ' WHERE id=1'), 'COMMIT; BEGIN; ROLLBACK;')
        self.assertEqual(self.count_ledger(), 2)

    def test_16_read_only_configuration_refuses_apply_but_allows_plan(self):
        self.attest()
        self.add_migration('ALTER TABLE ' + self.table + ' ADD COLUMN interdit text;')
        with override_settings(DB_READ_ONLY=True):
            call_command('migrer_metier', manifest=str(self.manifest_path), stdout=StringIO())
            with self.assertRaises(CommandError):
                call_command('migrer_metier', manifest=str(self.manifest_path), apply=True, stdout=StringIO())
        self.assertEqual(build_schema_snapshot(connection), self.snapshot)
        self.assertEqual(self.count_ledger(), 1)

    def test_17_journal_has_comments_and_no_public_or_runtime_write_grant(self):
        self.attest()
        self.assertTrue(scalar('SELECT obj_description(%s::regclass)', [LEDGER]))
        missing = execute('''SELECT a.attname FROM pg_attribute a
            WHERE a.attrelid=%s::regclass AND a.attnum>0 AND NOT a.attisdropped
            AND col_description(a.attrelid,a.attnum) IS NULL''', [LEDGER])
        self.assertEqual(missing, [])
        public = execute('''SELECT a.privilege_type FROM pg_class c
            CROSS JOIN LATERAL aclexplode(COALESCE(c.relacl,acldefault('r',c.relowner))) a
            WHERE c.oid=%s::regclass AND a.grantee=0''', [LEDGER])
        self.assertEqual(public, [])
        if scalar("SELECT EXISTS(SELECT FROM pg_roles WHERE rolname='sauverndeko_runtime')"):
            for privilege in ('INSERT', 'UPDATE', 'DELETE', 'TRUNCATE'):
                self.assertFalse(scalar('SELECT has_table_privilege(%s,%s,%s)',
                    ['sauverndeko_runtime', LEDGER, privilege]), privilege)

    def test_18_cli_plan_is_read_only_and_errors_are_sanitized(self):
        output = StringIO()
        try:
            call_command('migrer_metier', manifest=str(self.manifest_path), stdout=output)
        except CommandError:
            pass
        self.assertEqual(self.count_ledger(), 0)
        self.assertEqual(build_schema_snapshot(connection), self.snapshot)
        self.assertTrue(DSN not in output.getvalue(), 'Une sortie de maintenance contient la connexion privée.')

    def test_19_unknown_journal_entry_is_refused(self):
        self.attest()
        record = json.loads(scalar('SELECT to_jsonb(m)::text FROM ' + LEDGER + ' m'))
        record.update(Identifiant='livraison_inconnue', Position=1, Nature='migration',
                      Dependances=[self.baseline['id']])
        execute('INSERT INTO ' + LEDGER + ' SELECT * FROM jsonb_populate_record(NULL::' + LEDGER + ',%s::jsonb)',
                [json.dumps(record)])
        self.add_migration('ALTER TABLE ' + self.table + ' ADD COLUMN incompatible text;')
        self.assert_refused(lambda: self.migrate(apply=True))
        self.assertEqual(build_schema_snapshot(connection), self.snapshot)
        self.assertEqual(self.count_ledger(), 2)

    def test_20_parallel_migration_is_refused_and_lock_is_released(self):
        self.attest()
        self.add_migration('ALTER TABLE ' + self.table + ' ADD COLUMN concurrence text;')
        with psycopg.connect(DSN, autocommit=True) as other:
            other.execute('SELECT pg_advisory_lock(hashtextextended(%s,0))', [LOCK_NAME])
            self.assert_refused(lambda: self.migrate(apply=True))
            self.assertEqual(self.count_ledger(), 1)
            self.assertEqual(build_schema_snapshot(connection), self.snapshot)
            other.execute('SELECT pg_advisory_unlock(hashtextextended(%s,0))', [LOCK_NAME])
        self.migrate(apply=True)
        self.assertEqual(self.count_ledger(), 2)

    def test_21_first_migration_remains_attested_if_second_rolls_back(self):
        self.attest()
        self.add_migration('ALTER TABLE ' + self.table + ' ADD COLUMN etape_validee text;', 'm001')
        self.add_migration('ALTER TABLE ' + self.table + ' ADD COLUMN etape_refusee text;\n'
            'UPDATE ' + self.table + " SET libelle='Erreur fictive';\n"
            "DO $refus$ BEGIN RAISE EXCEPTION 'Erreur fictive de seconde étape'; END $refus$;",
            'm002', ['m001'])
        self.assert_refused(lambda: self.migrate(apply=True))
        names = {row[0] for row in execute('SELECT attname FROM pg_attribute WHERE attrelid=%s::regclass AND attnum>0 AND NOT attisdropped', [self.table])}
        self.assertIn('etape_validee', names)
        self.assertNotIn('etape_refusee', names)
        self.assertEqual(self.count_ledger(), 2)
        self.assert_refused(lambda: self.migrate(apply=True))
        self.assertEqual(self.count_ledger(), 2)

    def test_22_snapshot_restores_callers_search_path(self):
        with transaction.atomic():
            execute("SET LOCAL search_path=public,analytics")
            before = scalar('SHOW search_path')
            build_schema_snapshot(connection)
            self.assertEqual(scalar('SHOW search_path'), before)

    def test_23_malformed_journal_snapshot_is_refused_as_migration_error(self):
        self.attest()
        empty_sha = hashlib.sha256(b'[]').hexdigest()
        # JSONB valide et empreinte cohérente, mais preuve incomplète : ce cas
        # doit produire un refus de maintenance lisible, pas une KeyError.
        malformed = {'objects': [], 'sha256': empty_sha}
        execute('UPDATE ' + LEDGER + ' SET "Structure"=%s::jsonb,"EmpreinteStructure"=%s',
                [json.dumps(malformed), empty_sha])
        self.assert_refused(self.migrate)
        self.assert_rows_preserved()

    def test_24_empty_canonical_journal_requires_explicit_attestation(self):
        self.attest()
        execute('DELETE FROM ' + LEDGER)
        before = build_schema_snapshot(connection)
        plan = self.migrate()
        self.assertFalse(plan['baselineAttested'])
        self.assertEqual(self.count_ledger(), 0)
        self.assertEqual(build_schema_snapshot(connection), before)
        self.assert_refused(lambda: self.migrate(check=True))
        self.assert_refused(lambda: self.migrate(apply=True))
        self.assertEqual(self.count_ledger(), 0)
        self.attest()
        self.assertEqual(self.count_ledger(), 1)
        self.assert_rows_preserved()

    def test_25_changed_journal_structure_is_refused(self):
        self.attest()
        execute('ALTER TABLE ' + LEDGER + ' ADD COLUMN colonne_intruse text')
        self.assert_refused(self.migrate)
        self.assert_refused(lambda: self.migrate(apply=True))
        self.assertEqual(self.count_ledger(), 1)

    def test_26_render_runtime_check_is_valid_with_and_without_journal(self):
        directory = ROOT / 'deploy/render'
        previous_path = sys.path[:]
        try:
            sys.path.insert(0, str(directory))
            spec = importlib.util.spec_from_file_location('schema_recipe_render_runtime', directory / 'runtime_role.py')
            module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(module)
        finally:
            sys.path[:] = previous_path
        with transaction.atomic():
            execute('SET TRANSACTION READ ONLY')
            self.assertIs(scalar(module.CHECK_SQL), True)
        self.attest()
        with transaction.atomic():
            execute('SET TRANSACTION READ ONLY')
            # La connexion de recette possède ses objets fictifs : elle doit
            # donc être refusée comme compte HTTP, jamais validée par défaut.
            self.assertIs(scalar(module.CHECK_SQL), True)


if __name__ == '__main__':
    unittest.main(verbosity=2)
