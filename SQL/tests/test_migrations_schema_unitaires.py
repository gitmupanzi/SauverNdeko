"""Contrôles sans connexion du contrat fermé de livraison SQL."""
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'backend'))
from apps.core.schema_migrations import (HASH_ALGORITHM, SCHEMAS, MigrationError,
    _digest, _verify_history, canonical_expression, load_manifest, normalized_text, sha256_file, validate_sql)


class ManifestTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.releases = self.root / 'releases'
        self.scripts = self.root / 'migrations'
        self.releases.mkdir()
        self.scripts.mkdir()
        self.script = self.scripts / 'new.sql'
        self.script.write_text('SELECT 1;\n', encoding='utf8')
        self.legacy = self.scripts / 'old.sql'
        self.legacy.write_text('BEGIN; SELECT 1; COMMIT;\n', encoding='utf8')
        self.baseline = {'format': 1, 'hashAlgorithm': HASH_ALGORITHM, 'id': 'socle',
            'description': 'Socle de recette sans données', 'release': 'test',
            'schemas': list(SCHEMAS), 'objects': [], 'sha256': _digest([]),
            'legacyMigrations': [{'file': 'old.sql', 'sha256': sha256_file(self.legacy)}]}
        self.basepath = self.releases / 'baseline.json'
        self.basepath.write_text(json.dumps(self.baseline), encoding='utf8')
        self.manifest = {'format': 1, 'hashAlgorithm': HASH_ALGORITHM,
            'baseline': {'id': 'socle', 'file': 'baseline.json', 'sha256': sha256_file(self.basepath)},
            'migrations': [{'id': 'm1', 'file': '../migrations/new.sql',
                'sha256': sha256_file(self.script), 'dependsOn': ['socle'],
                'description': 'Évolution de recette', 'release': 'test'}]}
        self.path = self.releases / 'manifest.json'

    def load(self):
        self.path.write_text(json.dumps(self.manifest), encoding='utf8')
        return load_manifest(self.path)

    def test_valid_normalized_executable_content(self):
        result = self.load()
        self.assertEqual(result['migrations'][0]['_sql'], normalized_text(self.script))

    def test_lf_crlf_and_bom_have_same_identity(self):
        expected = sha256_file(self.script)
        self.script.write_bytes(b'\xef\xbb\xbfSELECT 1;\r\n')
        self.assertEqual(expected, sha256_file(self.script))
        self.load()

    def test_future_sql_changed(self):
        self.script.write_text('SELECT 2;', encoding='utf8')
        with self.assertRaises(MigrationError): self.load()

    def test_legacy_changed(self):
        self.legacy.write_text('SELECT 2;', encoding='utf8')
        with self.assertRaises(MigrationError): self.load()

    def test_unrecognized_manifest_option(self):
        self.manifest['autoInstall'] = True
        with self.assertRaises(MigrationError): self.load()

    def test_dependency_required(self):
        self.manifest['migrations'][0]['dependsOn'] = []
        with self.assertRaises(MigrationError): self.load()

    def test_malformed_dependency_refused(self):
        self.manifest['migrations'][0]['dependsOn'] = ['socle', {}]
        with self.assertRaises(MigrationError): self.load()

    def test_path_escape_refused(self):
        self.manifest['migrations'][0]['file'] = '../baseline.json'
        with self.assertRaises(MigrationError): self.load()

    def test_old_script_never_becomes_pending(self):
        self.manifest['migrations'][0].update(file='../migrations/old.sql', sha256=sha256_file(self.legacy))
        with self.assertRaises(MigrationError): self.load()

    def test_migration_duplicate_refused(self):
        self.manifest['migrations'].append(self.manifest['migrations'][0].copy())
        with self.assertRaises(MigrationError): self.load()

    def test_bad_baseline_hash(self):
        self.manifest['baseline']['sha256'] = '0' * 64
        with self.assertRaises(MigrationError): self.load()

    def test_malformed_journal_snapshot_is_a_controlled_error(self):
        manifest = self.load()
        row = {'id': 'socle', 'sha256': manifest['baseline']['sha256'], 'nature': 'socle',
               'dependsOn': [], 'position': 0, 'schemaSha256': _digest([])}
        for snapshot in [{'objects': [], 'sha256': _digest([])},
                         {'schemas': list(SCHEMAS), 'objects': [{}], 'sha256': _digest([{}])},
                         None, [], {'schemas': list(SCHEMAS), 'objects': None, 'sha256': _digest(None)}]:
            with self.subTest(snapshot=snapshot), self.assertRaises(MigrationError):
                _verify_history(manifest, [{**row, 'snapshot': snapshot}])


class SqlTests(unittest.TestCase):
    def test_native_text_array_restore_is_equivalent(self):
        before = "CHECK (x = ANY (ARRAY['a'::character varying, 'b'::character varying]::text[]))"
        restored = "CHECK (x = ANY (ARRAY['a'::character varying::text, 'b'::character varying::text]))"
        self.assertEqual(canonical_expression(before), canonical_expression(restored))

    def test_constant_content_remains_distinct(self):
        self.assertNotEqual(canonical_expression("ARRAY['a'::character varying]::text[]"),
                            canonical_expression("ARRAY['b'::character varying]::text[]"))

    def test_strings_comments_and_dollar_bodies_are_opaque(self):
        for sql in ["SELECT 'ARRAY[''a''::character varying]::text[]';",
                    "-- ARRAY['a'::character varying]::text[]\nSELECT 1;",
                    "SELECT $$ARRAY['a'::character varying]::text[]$$;"]:
            with self.subTest(sql=sql): self.assertEqual(canonical_expression(sql), sql)

    def test_variable_arrays_remain_distinct(self):
        for sql in ['ARRAY[x::character varying]::text[]',
                    "ARRAY['a'::character varying(2)]::text[]",
                    "ARRAY['a'::character varying, f()::character varying]::text[]",
                    "ARRAY['a'::character varying]"]:
            with self.subTest(sql=sql): self.assertEqual(canonical_expression(sql), sql)

    def test_escaped_quote_literal_is_preserved(self):
        sql = "ARRAY['l''autre'::character varying]::text[]"
        self.assertEqual(canonical_expression(sql), "ARRAY['l''autre'::text]")

    def test_transaction_control_rejected(self):
        for sql in ['BEGIN; SELECT 1; COMMIT;', 'SELECT 1; ROLLBACK;',
                    'START TRANSACTION;', 'END;', 'SAVEPOINT s;', 'RELEASE s;',
                    'COMMIT PREPARED \'x\';', 'SET TRANSACTION READ WRITE;']:
            with self.subTest(sql=sql), self.assertRaises(MigrationError): validate_sql(sql)

    def test_psql_and_nontransactional_rejected(self):
        for sql in ['\\i other.sql', 'VACUUM;', 'CREATE INDEX CONCURRENTLY x ON t (id);']:
            with self.subTest(sql=sql), self.assertRaises(MigrationError): validate_sql(sql)

    def test_body_strings_and_comments_preserved(self):
        for sql in ["SELECT 'BEGIN; COMMIT; \\i';", '-- BEGIN;\nSELECT 1;',
                    'DO $body$ BEGIN PERFORM 1; END $body$;',
                    "CREATE FUNCTION x() RETURNS void LANGUAGE plpgsql AS $$ BEGIN RETURN; END $$;"]:
            with self.subTest(sql=sql): validate_sql(sql)

    def test_empty_script_refused(self):
        for sql in ['', '  ', '-- commentaire seulement']:
            with self.subTest(sql=sql), self.assertRaises(MigrationError): validate_sql(sql)


if __name__ == '__main__':
    unittest.main()
