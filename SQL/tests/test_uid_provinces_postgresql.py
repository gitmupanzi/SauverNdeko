"""Recette du lot provincial sur restauration privée des données pré-audit.

Refuse toute connexion autre qu'une base locale sauverndeko_test_*.
Chaque scénario et ses journaux sont annulés après vérification.
"""
import json
import os
from pathlib import Path
import unittest
from urllib.parse import urlsplit

import psycopg
from psycopg.rows import dict_row

DSN=os.environ.get('SAUVERNDEKO_TEST_DATABASE_URL','')
target=urlsplit(DSN)
if target.hostname not in {'localhost','127.0.0.1','::1'} or not target.path.lstrip('/').startswith('sauverndeko_test_'):
    raise RuntimeError('Restauration privée locale sauverndeko_test_* obligatoire ; aucun repli source.')
ROOT=Path(__file__).resolve().parents[2]
MIGRATION=ROOT/'backend/database/migrations/20261104_03_uid_provinces_prouves.sql'
ROLLBACK=ROOT/'backend/database/migrations/rollback/20261104_03_uid_provinces_prouves.sql'
OP='SNIS_PROVINCE_UID_20261104'
SOURCE=MIGRATION.read_text('utf8')
PLAN=json.loads(SOURCE.split('$provinces$',2)[1])

def body(path):
    source=path.read_text('utf8').strip()
    assert source.endswith('COMMIT;')
    return source.replace('BEGIN;','',1)[:-len('COMMIT;')]

class ProvinceReconciliationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.db=psycopg.connect(DSN,autocommit=True,row_factory=dict_row)

    @classmethod
    def tearDownClass(cls):cls.db.close()

    def setUp(self):
        self.tx=self.db.transaction();self.tx.__enter__()
        self.db.execute("SET LOCAL TIME ZONE 'UTC'")
        # Préconditions du lot réel, la base de test doit provenir de sa sauvegarde.
        for item in PLAN:
            row=self.db.execute('SELECT "ID_Niveau_1","ID_Niveau_0_Fk","NomNiveau_1","prov_uid","uidSNIS" FROM geolocalisation."T_Niveau_1" WHERE "ID_Niveau_1"=%s',[item['id']]).fetchone()
            self.assertEqual(row,item['before'])
        self.before=self.snapshot()

    def tearDown(self):self.db.execute('ROLLBACK');self.tx.__exit__(None,None,None)

    def snapshot(self):
        return {n:self.db.execute('SELECT to_jsonb(t) row FROM geolocalisation."T_Niveau_'+str(n)+'" t ORDER BY "ID_Niveau_'+str(n)+'"').fetchall() for n in range(6)}

    def events(self):return self.db.execute('SELECT * FROM systeme."T_Audit_Log" WHERE "Operation" LIKE %s ORDER BY "IdLog"',[OP+'%']).fetchall()

    def apply(self):self.db.execute(body(MIGRATION))
    def reverse(self):self.db.execute(body(ROLLBACK))

    def test_01_only_25_uids_change_with_sources_and_before_after_audit(self):
        old_events=len(self.events());self.apply();after=self.snapshot()
        self.assertEqual({n:v for n,v in after.items() if n!=1},{n:v for n,v in self.before.items() if n!=1})
        changes=[]
        for old,new in zip(self.before[1],after[1]):
            a,b=old['row'],new['row']
            self.assertEqual({k:v for k,v in a.items() if k!='uidSNIS'},{k:v for k,v in b.items() if k!='uidSNIS'})
            if a!=b:changes.append(b['ID_Niveau_1']);self.assertIsNone(a['uidSNIS'])
        self.assertEqual(set(changes),{r['id'] for r in PLAN});self.assertNotIn(11,changes)
        events=self.events();self.assertEqual(len(events),old_events+1)
        self.assertEqual(len(events[-1]['OldData']),25)
        self.assertEqual(set(events[-1]['NewData']['sources']),{'dhis2','grid3'})

    def test_02_replay_does_not_update_rows_or_duplicate_audit(self):
        self.apply();after=self.snapshot();events=self.events()
        self.apply();self.assertEqual(after,self.snapshot());self.assertEqual(events,self.events())

    def test_03_conflict_late_in_plan_rolls_back_earlier_changes(self):
        last=PLAN[-1]
        self.db.execute('UPDATE geolocalisation."T_Niveau_1" SET "uidSNIS"=%s WHERE "ID_Niveau_1"=%s',['Z0000000001',last['id']])
        before=self.snapshot();events=self.events()
        with self.assertRaises(psycopg.errors.RaiseException):
            with self.db.transaction():self.apply()
        self.assertEqual(before,self.snapshot());self.assertEqual(events,self.events())

    def test_04_changed_name_refuses_any_overwrite(self):
        self.db.execute('UPDATE geolocalisation."T_Niveau_1" SET "NomNiveau_1"=%s WHERE "ID_Niveau_1"=%s',['Nom corrigé après audit',PLAN[-1]['id']])
        before=self.snapshot()
        with self.assertRaises(psycopg.errors.RaiseException):
            with self.db.transaction():self.apply()
        self.assertEqual(before,self.snapshot())

    def test_05_reverse_is_exact_and_replay_preserves_audit(self):
        self.apply();self.reverse();self.assertEqual(self.before,self.snapshot())
        events=self.events();self.assertTrue(any(r['Operation']==OP+'_RETOUR' for r in events))
        self.reverse();self.assertEqual(events,self.events())

    def test_06_reverse_refuses_later_edit(self):
        self.apply()
        self.db.execute('UPDATE geolocalisation."T_Niveau_1" SET "NomNiveau_1"=%s WHERE "ID_Niveau_1"=%s',['Édition métier ultérieure',PLAN[-1]['id']])
        before=self.snapshot();events=self.events()
        with self.assertRaises(psycopg.errors.RaiseException):
            with self.db.transaction():self.reverse()
        self.assertEqual(before,self.snapshot());self.assertEqual(events,self.events())

    def test_07_duplicate_uid_on_another_province_is_rejected(self):
        self.db.execute('UPDATE geolocalisation."T_Niveau_1" SET "uidSNIS"=%s WHERE "ID_Niveau_1"=11',[PLAN[0]['proposed_after']])
        before=self.snapshot()
        with self.assertRaises(psycopg.errors.RaiseException):
            with self.db.transaction():self.apply()
        self.assertEqual(before,self.snapshot())

if __name__=='__main__':unittest.main()
