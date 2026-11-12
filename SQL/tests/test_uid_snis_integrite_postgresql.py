"""Format et unicité locale SNIS : recette sur PostgreSQL privé local seulement."""
import os
from pathlib import Path
import re
import unittest
from urllib.parse import urlsplit
import uuid

import psycopg
from psycopg import sql
from psycopg.rows import dict_row

DSN = os.environ.get('SAUVERNDEKO_TEST_DATABASE_URL', '')
LOCATION = urlsplit(DSN)
if LOCATION.hostname not in {'localhost', '127.0.0.1', '::1'} or not LOCATION.path.lstrip('/').startswith('sauverndeko_test_'):
    raise RuntimeError('Copie privée locale sauverndeko_test_* obligatoire ; aucun repli source.')
DIRECTORY = Path(__file__).resolve().parents[2] / 'backend/database/migrations'
MIGRATION = DIRECTORY / '20261104_04_integrite_uid_snis.sql'
ROLLBACK = DIRECTORY / 'rollback/20261104_04_integrite_uid_snis.sql'


def without_envelope(path):
    return re.sub(r'^(BEGIN|COMMIT);\s*$', '', path.read_text(encoding='utf8'), flags=re.M)


class UidSnisIntegritySQL(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.c = psycopg.connect(DSN, autocommit=True, row_factory=dict_row)
        actual = cls.c.execute('SELECT current_database() AS name').fetchone()['name']
        if actual != LOCATION.path.lstrip('/') or not actual.startswith('sauverndeko_test_'):
            raise RuntimeError('Identité de copie privée incohérente.')
        cls.c.execute(MIGRATION.read_text(encoding='utf8'))

    @classmethod
    def tearDownClass(cls):
        cls.c.close()

    def setUp(self):
        self.tx = self.c.transaction(); self.tx.__enter__()
        self.parents = {}
        self.tag = uuid.uuid4().hex
        for level in range(5):
            fields = {f'NomNiveau_{level}': 'UID fictif '+self.tag}
            if level:
                fields[{1:'ID_Niveau_0_Fk',2:'ID_Niveau_1_FK',3:'ID_Niveau_2_FK',4:'ID_Niveau_3_Fk'}[level]] = self.parents[level-1]
            if level == 1:
                fields.update(VisibleNiveau_1=False,VisibleNiveau_5=False)
            self.parents[level] = self.insert(level, fields)

    def tearDown(self):
        self.c.execute('ROLLBACK'); self.tx.__exit__(None,None,None)

    def insert(self, level, fields):
        statement = sql.SQL('INSERT INTO geolocalisation.{} ({}) VALUES ({}) RETURNING {} AS id').format(
            sql.Identifier(f'T_Niveau_{level}'),sql.SQL(',').join(map(sql.Identifier,fields)),
            sql.SQL(',').join(sql.Placeholder() for _ in fields),sql.Identifier(f'ID_Niveau_{level}'))
        return self.c.execute(statement,list(fields.values())).fetchone()['id']

    def set_uid(self, level, value, identifier=None):
        self.c.execute(sql.SQL('UPDATE geolocalisation.{} SET "uidSNIS"=%s WHERE {}=%s').format(
            sql.Identifier(f'T_Niveau_{level}'),sql.Identifier(f'ID_Niveau_{level}')), [value,identifier or self.parents[level]])

    def get_uid(self, level):
        return self.c.execute(sql.SQL('SELECT "uidSNIS" FROM geolocalisation.{} WHERE {}=%s').format(
            sql.Identifier(f'T_Niveau_{level}'),sql.Identifier(f'ID_Niveau_{level}')), [self.parents[level]]).fetchone()['uidSNIS']

    def rejected(self, action):
        with self.assertRaises(psycopg.Error):
            with self.c.transaction():
                action()

    def valid_uid(self):
        return 'V'+uuid.uuid4().hex[:10]

    def test_01_nullable_or_11_character_uid_on_three_levels(self):
        for level in (1,3,4):
            self.set_uid(level,None); self.assertIsNone(self.get_uid(level))
            value=self.valid_uid(); self.set_uid(level,value); self.assertEqual(self.get_uid(level),value)

    def test_02_invalid_new_uids_rejected_without_partial_change(self):
        for level in (1,3,4):
            good=self.valid_uid();self.set_uid(level,good)
            for invalid in ('','short','01234567890','A123456789_',' A1234567890','A1234567890 ','é1234567890'):
                self.rejected(lambda invalid=invalid:self.set_uid(level,invalid))
                self.assertEqual(self.get_uid(level),good)

    def test_03_uniqueness_is_enforced_by_index_within_each_level(self):
        for level in (1,3,4):
            value=self.valid_uid();self.set_uid(level,value)
            second=self.insert(level,{f'NomNiveau_{level}':'Second UID fictif '+self.tag})
            self.rejected(lambda:self.set_uid(level,value,second))

    def test_04_case_is_significant_not_lowercased_or_trimmed(self):
        self.set_uid(4,'AaBbCc12345')
        second=self.insert(4,{'NomNiveau_4':'Autre casse '+self.tag})
        self.set_uid(4,'aabbcc12345',second)
        self.assertEqual(self.get_uid(4),'AaBbCc12345')

    def test_05_explicit_valid_correction_and_clearing_remain_possible(self):
        for level in (1,3,4):
            self.set_uid(level,self.valid_uid());second=self.valid_uid();self.set_uid(level,second)
            self.assertEqual(self.get_uid(level),second)
            self.set_uid(level,None);self.assertIsNone(self.get_uid(level))

    def test_06_unchanged_uid_and_description_update_are_preserved(self):
        value=self.valid_uid();self.set_uid(3,value)
        self.c.execute('UPDATE geolocalisation."T_Niveau_3" SET "uidSNIS"=%s,"NomNiveau_3"=%s WHERE "ID_Niveau_3"=%s',[value,'Description corrigée',self.parents[3]])
        self.assertEqual(self.get_uid(3),value)

    def test_07_replay_never_assigns_uid_or_rewrites_rows(self):
        before={n:self.get_uid(n) for n in (1,3,4)}
        self.c.execute(without_envelope(MIGRATION));self.c.execute(without_envelope(MIGRATION))
        self.assertEqual(before,{n:self.get_uid(n) for n in (1,3,4)})

    def test_08_rollback_removes_guards_without_erasing_uid(self):
        values={n:self.valid_uid() for n in (1,3,4)}
        for n,value in values.items():self.set_uid(n,value)
        self.c.execute(without_envelope(ROLLBACK))
        self.assertEqual(values,{n:self.get_uid(n) for n in (1,3,4)})
        self.assertIsNone(self.c.execute("SELECT to_regprocedure('geolocalisation.tr_uid_snis_integrite()') AS f").fetchone()['f'])
        self.c.execute(without_envelope(MIGRATION))

    def test_09_existing_invalid_nonempty_uid_blocks_installation_not_silent_rewrite(self):
        self.c.execute(without_envelope(ROLLBACK));self.set_uid(3,'legacy-bad')
        self.rejected(lambda:self.c.execute(without_envelope(MIGRATION)))
        self.assertEqual(self.get_uid(3),'legacy-bad')

    def test_10_existing_duplicate_blocks_installation_without_picking_winner(self):
        self.c.execute(without_envelope(ROLLBACK));value=self.valid_uid();self.set_uid(4,value)
        second=self.insert(4,{'NomNiveau_4':'Doublon à examiner '+self.tag,'uidSNIS':value})
        self.rejected(lambda:self.c.execute(without_envelope(MIGRATION)))
        self.assertEqual(self.get_uid(4),value)
        self.assertEqual(self.c.execute('SELECT "uidSNIS" FROM geolocalisation."T_Niveau_4" WHERE "ID_Niveau_4"=%s',[second]).fetchone()['uidSNIS'],value)

    def test_11_new_objects_are_documented_and_n5_is_untouched(self):
        for n in (1,3,4):
            row=self.c.execute("SELECT obj_description(to_regclass(%s),'pg_class') AS comment",[f'geolocalisation.uq_uid_snis_niveau_{n}']).fetchone()
            self.assertTrue(row['comment'])
        self.assertEqual(self.c.execute("SELECT count(*) AS n FROM pg_trigger WHERE tgrelid='geolocalisation.\"T_Niveau_5\"'::regclass AND tgname='uid_snis_integrite'").fetchone()['n'],0)


if __name__=='__main__':
    unittest.main(verbosity=2)
