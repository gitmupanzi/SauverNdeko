"""Masquage identique et coût borné ; copie PostgreSQL locale obligatoire.

N'insère aucune ligne métier ou preuve. L'optimisation reste installée sur la
copie de recette ; les scénarios de retour sont annulés par leur transaction.
"""
import json
import os
from pathlib import Path
import random
import re
import time
import unittest
from urllib.parse import urlsplit

import psycopg
from psycopg.rows import dict_row

DSN = os.environ.get('SAUVERNDEKO_TEST_DATABASE_URL', '')
LOCATION = urlsplit(DSN)
if LOCATION.hostname not in {'localhost', '127.0.0.1', '::1'} or not LOCATION.path.lstrip('/').startswith('sauverndeko_test_'):
    raise RuntimeError('Copie PostgreSQL privée locale obligatoire ; aucun repli applicatif.')
DIRECTORY = Path(__file__).resolve().parents[1] / 'migrations'
MIGRATION = DIRECTORY / '20261104_05_performance_masquage_audit.sql'
ROLLBACK = DIRECTORY / 'rollback/20261104_05_performance_masquage_audit.sql'


def without_envelope(path):
    return re.sub(r'^(BEGIN|COMMIT);\s*$', '', path.read_text(encoding='utf8'), flags=re.M)


class AuditRedactionPerformanceSQL(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.c = psycopg.connect(DSN, autocommit=True, row_factory=dict_row,
                               options='-c statement_timeout=15000 -c lock_timeout=3000')
        if cls.c.execute('SELECT current_database() AS name').fetchone()['name'] != LOCATION.path.lstrip('/'):
            raise RuntimeError('Identité de copie privée incohérente.')
        cls.before = cls.snapshot()
        cls.function_before = cls.c.execute("SELECT oid,proacl,proowner,provolatile,proparallel FROM pg_proc WHERE oid='systeme.fn_audit_sans_secrets(jsonb)'::regprocedure").fetchone()
        cls.c.execute(MIGRATION.read_text(encoding='utf8'))
        # Oracle de compatibilité exact, limité à cette session privée.
        legacy = without_envelope(ROLLBACK)
        start = legacy.index('CREATE OR REPLACE FUNCTION')
        end = legacy.index('COMMENT ON FUNCTION')
        cls.c.execute(legacy[start:end].replace('systeme.fn_audit_sans_secrets', 'pg_temp.fn_audit_ancienne'))

    @classmethod
    def tearDownClass(cls):
        try:
            if cls.snapshot() != cls.before:
                raise AssertionError('Les journaux ou preuves de recette ont été modifiés.')
        finally:
            cls.c.close()

    @classmethod
    def snapshot(cls):
        return cls.c.execute('''SELECT count(*) AS count,
            md5(coalesce(string_agg(md5(to_jsonb(t)::text),'' ORDER BY "IdLog"),'')) AS fingerprint
            FROM systeme."T_Audit_Log" t''').fetchone()

    def sanitize(self, value, legacy=False):
        name = 'pg_temp.fn_audit_ancienne' if legacy else 'systeme.fn_audit_sans_secrets'
        return self.c.execute('SELECT '+name+'(%s::jsonb) AS value', [json.dumps(value, ensure_ascii=False)]).fetchone()['value']

    def test_01_secrets_logo_and_nested_settings_are_unchanged(self):
        value = {
            'ordinary': 'visible', 'Password': 'secret', 'refresh_token': 'secret',
            'LogoEntite': 'secret-image', 'LogoSha256Entite': 'hash-visible', 'LogoMimeEntite': 'image/png',
            'nested': [{'api_key': 'secret', 'keep': 1}, {'settingKey': 'smtp.host-password',
                       'settingValue': 'secret', 'settingValueJson': {'anything': 'secret'}}],
            'jsonString': json.dumps({'Authorization': 'secret', 'keep': True}),
        }
        result = self.sanitize(value)
        self.assertEqual(result, self.sanitize(value, legacy=True))
        self.assertNotIn('secret', json.dumps(result))
        self.assertEqual(result['LogoSha256Entite'], 'hash-visible')
        self.assertEqual(result['nested'][1]['settingValue'], '[Masqué]')
        self.assertEqual(result['jsonString'], {'keep': True})

    def test_02_null_scalars_empty_collections_and_array_order(self):
        self.assertIsNone(self.c.execute('SELECT systeme.fn_audit_sans_secrets(NULL) AS value').fetchone()['value'])
        for value in (None, True, False, 0, 1.25, '', 'texte', {}, [], [3, 1, None, False, {}], '{invalide'):
            with self.subTest(value=value):
                self.assertEqual(self.sanitize(value), self.sanitize(value, legacy=True))

    def test_03_encoded_json_and_sensitive_key_spelling(self):
        for key in ('SettingKey', 'setting_key', 'SETTING-KEY'):
            value = {key: 'mail.apiKey', 'SETTING_VALUE': 'secret', 'SettingValueJson': [1, 2],
                     'Logo-Entite': 'secret', 'valid': [{'password': 'secret', 'n': 5}]}
            for _ in range(3):
                with self.subTest(key=key, value_type=type(value).__name__):
                    self.assertEqual(self.sanitize(value), self.sanitize(value, legacy=True))
                value = json.dumps(value)

    def test_04_mixed_reference_cases_match_legacy(self):
        randomizer = random.Random(20261104)
        def value(depth):
            if not depth:
                return randomizer.choice([None, True, False, 0, 123, 1.25, 'texte', '{invalide', '[a]'])
            mode = randomizer.randrange(4)
            if mode == 0:
                return [value(depth-1) for _ in range(randomizer.randrange(5))]
            if mode == 1:
                return json.dumps({'access_token': 'secret', 'visible': value(depth-1)})
            if mode == 2:
                return {randomizer.choice(['x', 'Password', 'LogoEntite', 'settingKey', 'SettingValue', 'note'])+str(i): value(depth-1) for i in range(randomizer.randrange(6))}
            return value(0)
        for index in range(100):
            sample = value(4)
            with self.subTest(index=index):
                self.assertEqual(self.sanitize(sample), self.sanitize(sample, legacy=True))

    def test_05_large_proof_keeps_all_values_within_five_seconds(self):
        value = {'result': {'states': {'T_Niveau_4': {str(i): f'{i:064x}' for i in range(25000)}},
                            'proofIds': list(range(25000)), 'nested': {'password': 'secret'}}}
        with self.c.transaction():
            self.c.execute("SET LOCAL statement_timeout='5s'")
            started = time.monotonic()
            result = self.sanitize(value)
            elapsed = time.monotonic()-started
        self.assertEqual(result['result']['states'], value['result']['states'])
        self.assertEqual(result['result']['proofIds'], value['result']['proofIds'])
        self.assertEqual(result['result']['nested'], {})
        self.assertLess(elapsed, 5)
        print(f'\nPreuve synthétique : 25 000 clés + 25 000 éléments masqués en {elapsed:.3f} s')

    def test_06_replay_keeps_oid_permissions_and_full_audit(self):
        with self.c.transaction():
            self.c.execute(without_envelope(MIGRATION))
            after = self.c.execute("SELECT oid,proacl,proowner,provolatile,proparallel FROM pg_proc WHERE oid='systeme.fn_audit_sans_secrets(jsonb)'::regprocedure").fetchone()
            self.assertEqual(after, self.function_before)
            self.assertEqual(self.snapshot(), self.before)

    def test_07_rollback_restores_legacy_without_erasing_proofs(self):
        with self.c.transaction(force_rollback=True):
            self.c.execute(without_envelope(ROLLBACK))
            self.assertEqual(self.sanitize({'keep': {'a': 1}, 'password': 'secret'}), {'keep': {'a': 1}})
            definition = self.c.execute("SELECT pg_get_functiondef('systeme.fn_audit_sans_secrets(jsonb)'::regprocedure) AS definition").fetchone()['definition']
            self.assertIn('v_result:=v_result||jsonb_build_object', definition)
            self.assertEqual(self.snapshot(), self.before)
        self.assertIn('json_object_agg', self.c.execute("SELECT pg_get_functiondef('systeme.fn_audit_sans_secrets(jsonb)'::regprocedure) AS definition").fetchone()['definition'])

    def test_08_largest_private_audit_detail_remains_complete(self):
        biggest = self.c.execute('SELECT "IdLog",pg_column_size("NewData") AS size FROM systeme."T_Audit_Log" ORDER BY pg_column_size("NewData") DESC NULLS LAST LIMIT 1').fetchone()
        if not biggest:
            self.skipTest('Aucun journal dans cette copie privée.')
        with self.c.transaction():
            self.c.execute("SET LOCAL statement_timeout='5s'")
            started = time.monotonic()
            detail = self.c.execute('SELECT * FROM systeme."V_Audit_log" WHERE "IdLog"=%s', [biggest['IdLog']]).fetchone()
            elapsed = time.monotonic()-started
        self.assertEqual(detail['IdLog'], biggest['IdLog'])
        self.assertLess(elapsed, 5)
        print(f'\nPlus grand audit privé ({biggest["size"]} octets stockés) consulté en {elapsed:.3f} s')


if __name__ == '__main__':
    unittest.main(verbosity=2)
