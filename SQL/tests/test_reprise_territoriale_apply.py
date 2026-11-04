"""Reprise du plan privé : recette réelle, uniquement sur copie PostgreSQL locale.

Le jeu de sources sensibles reste hors Git. SAUVERNDEKO_TERRITORIAL_PLAN peut
désigner son plan contrôlé ; à défaut le plan de travail privé est utilisé.
Chaque scénario d'écriture est annulé par la transaction extérieure du test.
"""
import copy
import hashlib
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
from urllib.parse import urlsplit

DSN = os.environ.get('SAUVERNDEKO_TEST_DATABASE_URL', '')
LOCATION = urlsplit(DSN)
if LOCATION.hostname not in {'localhost', '127.0.0.1', '::1'} or not LOCATION.path.lstrip('/').startswith('sauverndeko_test_'):
    raise RuntimeError('Copie locale sauverndeko_test_* obligatoire ; aucun repli vers la source.')
ROOT = Path(__file__).resolve().parents[2]
os.environ.update(DATABASE_URL=DSN, DJANGO_SETTINGS_MODULE='config.settings', SAUVERNDEKO_DB_READ_ONLY='0')
sys.path.insert(0, str(ROOT / 'backend'))
import django
django.setup()
from django.db import connection, transaction
from apps.core import db
from apps.core import territorial_reconciliation_apply as service
from apps.core.responses import APIError

PLAN = Path(os.environ.get('SAUVERNDEKO_TERRITORIAL_PLAN', ROOT / '.runtime/georeconciliation-20261104/import-plan.json'))


@unittest.skipUnless(PLAN.is_file(), 'Plan de sources privées nécessaire, non versionné dans Git.')
class TerritorialReconciliationApply(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if db.one('SELECT current_database() AS name')['name'] != LOCATION.path.lstrip('/'):
            raise RuntimeError('Identité de copie privée incohérente.')
        cls.actor = db.one('SELECT "EmailUser" FROM systeme."T_Utilisateurs" WHERE "Is_Admin" AND "ValideUser" ORDER BY "IdUser" LIMIT 1')['EmailUser']
        cls.non_admin = db.one('SELECT "EmailUser" FROM systeme."T_Utilisateurs" WHERE NOT "Is_Admin" AND "ValideUser" ORDER BY "IdUser" LIMIT 1')['EmailUser']
        raw = PLAN.read_bytes()
        cls.full = json.loads(raw.decode('utf8'))
        actions = cls.full['actions']
        created = copy.deepcopy(actions['area_create'][0])
        zone_id = created['values']['ID_Niveau_3_Fk']
        zone = next(a for a in actions['zone_uid_fill'] if a['id'] == zone_id)
        cls.plan = copy.deepcopy(cls.full)
        cls.plan['actions'] = {k: [] for k in service.ACTIONS}
        selected = cls.plan['actions']
        selected['reference_visibility'] = copy.deepcopy(actions['reference_visibility'])
        selected['province_uid_fill'] = [copy.deepcopy(next(a for a in actions['province_uid_fill'] if a['id'] == zone['province_id']))]
        selected['zone_uid_fill'] = [copy.deepcopy(zone)]
        selected['area_create'] = [created]
        for kind in ('bureau_de_zone', 'rattachement_sanitaire'):
            selected[kind] = copy.deepcopy([a for a in actions[kind] if a['zone_id'] == zone_id])
        for kind in ('aire_de_zone', 'grid3_object_link'):
            selected[kind] = copy.deepcopy([a for a in actions[kind] if a['area'].get('creation_key') == created['creation_key']])
        selected['alias_n5_n4'] = [copy.deepcopy(actions['alias_n5_n4'][0])]
        cls.plan['counts'] = {k: len(v) for k, v in selected.items()}
        cls.temp = tempfile.TemporaryDirectory(prefix='sauverndeko-reconciliation-test-')

    @classmethod
    def tearDownClass(cls):
        cls.temp.cleanup()
        connection.close()

    def write_plan(self, plan=None):
        target = Path(self.temp.name) / 'plan.json'
        data = copy.deepcopy(self.plan if plan is None else plan)
        data['counts'] = {k: len(v) for k, v in data['actions'].items()}
        raw = json.dumps(data, ensure_ascii=False, sort_keys=True).encode('utf8')
        target.write_bytes(raw)
        return target, hashlib.sha256(raw).hexdigest()

    def run_plan(self, plan=None, mode='preflight', actor=None):
        path, sha = self.write_plan(plan)
        return service.run_plan(path, sha, actor or self.actor, mode)

    def snapshot(self):
        result = {}
        for name, (table, _) in {**service.TABLES, **service.PROOF_TABLES}.items():
            result[name] = db.one(f'''SELECT count(*) AS count,md5(COALESCE(string_agg(h,'' ORDER BY h),'')) AS hash
                FROM (SELECT md5(to_jsonb(t)::text) h FROM {table} t) rows''')
        result['audit'] = db.one('SELECT count(*) AS count FROM systeme."T_Audit_Log" WHERE "Operation"=%s', [service.OPERATION])
        return result

    def sequences(self):
        # pg_sequences est une vue en lecture seule, aucun nextval ni setval.
        return db.query("SELECT schemaname,sequencename,last_value FROM pg_sequences WHERE schemaname IN ('geolocalisation','referentiel','systeme') ORDER BY 1,2")

    def test_01_default_preflight_has_no_rows_or_sequence_writes(self):
        before, sequences = self.snapshot(), self.sequences()
        result = self.run_plan()
        self.assertTrue(result['databaseReadOnly'])
        self.assertFalse(result['committed'])
        self.assertEqual(self.snapshot(), before)
        self.assertEqual(self.sequences(), sequences)

    def test_02_modified_file_hash_is_rejected_before_database_access(self):
        path, sha = self.write_plan()
        path.write_bytes(path.read_bytes() + b' ')
        with patch.object(service, '_actor', side_effect=AssertionError('La base ne doit pas être appelée')):
            with self.assertRaises(APIError):
                service.run_plan(path, sha, self.actor)

    def test_03_unknown_action_is_rejected(self):
        plan = copy.deepcopy(self.plan); plan['actions']['arbitrary_sql'] = []
        with self.assertRaises(APIError): self.run_plan(plan)

    def test_04_simulation_never_runs_on_source_database(self):
        path, sha = self.write_plan()
        with patch.dict(connection.settings_dict, NAME='SauverNdeko'):
            with self.assertRaises(APIError): service.run_plan(path, sha, self.actor, 'simulate')

    def test_05_non_global_account_is_denied(self):
        with self.assertRaises(APIError): self.run_plan(actor=self.non_admin)

    def test_06_stale_photo_is_rejected_without_change(self):
        plan = copy.deepcopy(self.plan)
        plan['actions']['alias_n5_n4'][0]['guards'][0]['before']['NomNiveau_5'] += ' changé'
        before = self.snapshot()
        with self.assertRaises(APIError): self.run_plan(plan)
        self.assertEqual(self.snapshot(), before)

    def test_07_cross_level_duplicate_uid_is_rejected(self):
        plan = copy.deepcopy(self.plan)
        plan['actions']['zone_uid_fill'][0]['uid'] = plan['actions']['province_uid_fill'][0]['uid']
        with self.assertRaises(APIError): self.run_plan(plan)

    def test_08_new_area_with_extra_business_columns_is_rejected(self):
        plan = copy.deepcopy(self.plan)
        plan['actions']['area_create'][0]['values']['PopulationNiveau_4'] = 99
        with self.assertRaises(APIError): self.run_plan(plan)

    def test_09_grid3_parent_conflict_is_rejected_in_preflight(self):
        plan = copy.deepcopy(self.plan)
        plan['actions']['grid3_object_link'][0]['zone_uid'] = plan['actions']['province_uid_fill'][0]['uid']
        with self.assertRaises(APIError): self.run_plan(plan)

    def test_10_partial_failure_rolls_back_uid_visibility_area_and_proofs(self):
        before = self.snapshot()
        insert_many = service._insert_many
        def fail_at_links(sql, rows):
            if 'INSERT INTO geolocalisation."T_LienTerritorial"' in sql:
                raise APIError('Échec contrôlé après création AS et preuves externes.', 'TEST_FAILURE', 409)
            return insert_many(sql, rows)
        with patch.object(service, '_insert_many', side_effect=fail_at_links):
            with self.assertRaises(APIError): self.run_plan(mode='apply')
        self.assertEqual(self.snapshot(), before)

    def test_11_private_simulation_rolls_back_all_rows(self):
        before = self.snapshot()
        result = self.run_plan(mode='simulate')
        self.assertEqual(result['createdAreaCount'], 1)
        self.assertFalse(result['committed'])
        self.assertEqual(self.snapshot(), before)

    def test_12_apply_is_idempotent_and_preserves_physical_parents(self):
        with transaction.atomic():
            before_parents = db.query('SELECT "ID_Niveau_5","ID_Niveau_3_Fk","ID_Niveau_4_Fk" FROM geolocalisation."T_Niveau_5" ORDER BY 1')
            result = self.run_plan(mode='apply')
            after = self.snapshot()
            replay = self.run_plan(mode='apply')
            self.assertTrue(result['committed']); self.assertTrue(replay['alreadyApplied'])
            self.assertEqual(self.snapshot(), after)
            self.assertEqual(db.query('SELECT "ID_Niveau_5","ID_Niveau_3_Fk","ID_Niveau_4_Fk" FROM geolocalisation."T_Niveau_5" ORDER BY 1'), before_parents)
            new_uid = self.plan['actions']['area_create'][0]['uid']
            new_area = db.one('SELECT * FROM geolocalisation."T_Niveau_4" WHERE "uidSNIS"=%s', [new_uid])
            self.assertEqual(new_area['ID_Niveau_3_Fk'], self.plan['actions']['area_create'][0]['values']['ID_Niveau_3_Fk'])
            provenance = db.one('''SELECT s."CodeSource",l."Preuves" FROM geolocalisation."T_LienTerritorial" l
                JOIN geolocalisation."T_SourceRapprochementTerritorial" s ON s."ID_SourceRapprochementTerritorial"=l."ID_SourceRapprochementFk"
                WHERE l."NatureLien"='rattachement_sanitaire' ''')
            self.assertEqual(provenance['CodeSource'], 'GRID3')
            self.assertTrue(provenance['Preuves']['grid3Rows'])
            transaction.set_rollback(True)

    def test_13_post_application_edit_blocks_replay(self):
        with transaction.atomic():
            self.run_plan(mode='apply')
            new_uid = self.plan['actions']['area_create'][0]['uid']
            db.query('UPDATE geolocalisation."T_Niveau_4" SET "NomNiveau_4"="NomNiveau_4"||%s WHERE "uidSNIS"=%s', [' modifié', new_uid])
            with self.assertRaises(APIError): self.run_plan(mode='apply')
            self.assertTrue(db.one('SELECT "NomNiveau_4" AS name FROM geolocalisation."T_Niveau_4" WHERE "uidSNIS"=%s', [new_uid])['name'].endswith(' modifié'))
            transaction.set_rollback(True)

    def test_14_multiple_grid3_objects_for_one_area_are_preserved(self):
        plan = copy.deepcopy(self.plan)
        obj = copy.deepcopy(plan['actions']['grid3_object_link'][0])
        obj['grid3id'] += '_second_test_object'; obj['source_row'] += 1
        plan['actions']['grid3_object_link'].append(obj)
        with transaction.atomic():
            self.run_plan(plan, mode='apply')
            count = db.one('SELECT count(*) AS count FROM geolocalisation."T_CorrespondanceTerritoriale" WHERE "Grid3Id" IS NOT NULL')['count']
            self.assertEqual(count, 2)
            transaction.set_rollback(True)

    def test_15_unresolved_area_target_is_rejected_before_writes(self):
        plan = copy.deepcopy(self.plan)
        plan['actions']['grid3_object_link'][0]['area'] = {'creation_key': 'inconnue'}
        before, sequences = self.snapshot(), self.sequences()
        with self.assertRaises(APIError): self.run_plan(plan)
        self.assertEqual(self.snapshot(), before)
        self.assertEqual(self.sequences(), sequences)

    def test_16_area_already_under_matching_bureau_blocks_canonical_duplicate(self):
        # Variante du préétat en mémoire : une AS homonyme est apparue sous le
        # bureau historique après la photographie. Aucune ligne SQL n'est écrite.
        plan = copy.deepcopy(self.plan)
        snapshot = json.loads((PLAN.parent / 'database/rows.json').read_text(encoding='utf8'))
        all_levels = {f'T_Niveau_{level}': {r[f'ID_Niveau_{level}']: r for r in snapshot[str(level)]} for level in (1, 3, 4)}
        current, guards = {}, {}
        for actions in plan['actions'].values():
            for action in actions:
                for guard in action.get('guards', []):
                    key = (guard['table'], guard['id'])
                    current[key] = guard['before']; guards[key] = guard['before']
        types = json.loads((PLAN.parent / 'database/references.json').read_text(encoding='utf8'))['values']
        labels = {r['ID_Generique']: r['AbrGenerique'] for r in types}
        as_ref = next(r for r in types if r['ID_Generique'] == plan['actions']['reference_visibility'][0]['id'])
        creation = plan['actions']['area_create'][0]
        old_key = creation['creation_key']
        creation['uid'] = 'Z9Z9Z9Z9Z9Z'
        creation['creation_key'] = 'dhis2:aire:' + creation['uid']
        creation['values']['uidSNIS'] = creation['uid']
        for kind in ('aire_de_zone', 'grid3_object_link'):
            for item in plan['actions'][kind]:
                if item['area'].get('creation_key') == old_key:
                    item['area']['creation_key'] = creation['creation_key']
                    item['source_area_uid' if kind == 'aire_de_zone' else 'uid'] = creation['uid']
        self.assertFalse(any(row.get('uidSNIS') == creation['uid'] for rows in all_levels.values() for row in rows.values()))
        new = creation['values']
        self.assertFalse(any(row.get('ID_Niveau_3_Fk') == new['ID_Niveau_3_Fk']
            and service.normalized(row.get('NomNiveau_4')) == service.normalized(new['NomNiveau_4'])
            for row in all_levels['T_Niveau_4'].values()))
        bureau = plan['actions']['bureau_de_zone'][0]['bureau_id']
        all_levels['T_Niveau_4'][2147483646] = {'ID_Niveau_4': 2147483646,
            'ID_Niveau_3_Fk': bureau, 'ID_TypeNiveau_4_Fk': as_ref['ID_Generique'],
            'NomNiveau_4': new['NomNiveau_4'], 'uidSNIS': None}
        n2 = {r['ID_Niveau_2']: r for r in snapshot['2']}
        with patch.object(service, '_read_rows', return_value=n2), patch.object(service.db, 'query', return_value=[]):
            with self.assertRaises(APIError) as error:
                service._inspect_links(plan, guards, current, service._desired_uids(plan['actions']), as_ref, labels, all_levels)
        self.assertEqual(str(error.exception), 'Une AS de même nom est déjà présente dans cette ZS, sous le bureau ou la zone canonique.')


if __name__ == '__main__':
    unittest.main(verbosity=2)
