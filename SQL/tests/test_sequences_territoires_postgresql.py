"""Identités territoriales : uniquement sur une base privée locale explicitement fournie."""
import os
from pathlib import Path
import unittest
from urllib.parse import urlsplit

import psycopg
from psycopg import sql

DSN=os.environ.get('SAUVERNDEKO_TEST_DATABASE_URL','')
url=urlsplit(DSN)
if url.hostname not in {'localhost','127.0.0.1','::1'} or not url.path.lstrip('/').startswith('sauverndeko_test_'):
    raise RuntimeError('Base privée locale sauverndeko_test_* obligatoire, sans repli source.')
MIGRATION=Path(__file__).resolve().parents[2]/'backend/database/migrations/20261103_05_sequences_territoires.sql'
TEXT=MIGRATION.read_text(encoding='utf8')
BODY=TEXT.replace('BEGIN;','',1).rsplit('COMMIT;',1)[0]
SUFFIXES=['0','1','1_Old','2','3','4','5']


class TerritorySequencesSQL(unittest.TestCase):
    @classmethod
    def setUpClass(cls):cls.c=psycopg.connect(DSN,autocommit=True)

    @classmethod
    def tearDownClass(cls):cls.c.close()

    def setUp(self):self.tx=self.c.transaction();self.tx.__enter__()

    def tearDown(self):self.c.execute('ROLLBACK');self.tx.__exit__(None,None,None)

    def descriptor(self,suffix):
        table='T_Niveau_'+suffix;column='ID_Niveau_'+suffix
        name=self.c.execute('SELECT pg_get_serial_sequence(%s,%s)',['geolocalisation."'+table+'"',column]).fetchone()[0]
        maximum=self.c.execute(sql.SQL('SELECT max({}) FROM geolocalisation.{}').format(sql.Identifier(column),sql.Identifier(table))).fetchone()[0]
        return table,column,name,maximum

    def state(self,name):return self.c.execute(sql.SQL('SELECT last_value,is_called FROM {}').format(sql.SQL(name))).fetchone()

    def restart(self,name,value):self.c.execute(sql.SQL('ALTER SEQUENCE {} RESTART WITH {}').format(sql.SQL(name),sql.Literal(value)))

    def test_01_all_seven_next_identifiers_exceed_existing_maximum(self):
        for suffix in SUFFIXES:
            _,_,sequence,maximum=self.descriptor(suffix);last,called=self.state(sequence)
            self.assertGreater(last+(1 if called else 0),maximum)

    def test_02_real_insert_uses_generated_non_conflicting_identifiers(self):
        for suffix in SUFFIXES:
            table,column,_,maximum=self.descriptor(suffix)
            generated=self.c.execute(sql.SQL('INSERT INTO geolocalisation.{} ({}) VALUES (%s) RETURNING {}').format(
                sql.Identifier(table),sql.Identifier('NomNiveau_'+suffix),sql.Identifier(column)),['Territoire fictif recette séquence']).fetchone()[0]
            self.assertGreater(generated,maximum)

    def test_03_replay_does_not_change_sequence_already_ahead(self):
        before={self.descriptor(suffix)[2]:self.state(self.descriptor(suffix)[2]) for suffix in SUFFIXES}
        self.c.execute(BODY);self.c.execute(BODY)
        self.assertEqual(before,{sequence:self.state(sequence) for sequence in before})

    def test_04_far_ahead_sequence_is_never_lowered(self):
        _,_,sequence,maximum=self.descriptor('5')
        self.restart(sequence,maximum+500)
        self.c.execute(BODY)
        self.assertEqual(self.state(sequence),(maximum+500,False))

    def test_05_alignment_handles_uncalled_and_called_states(self):
        for suffix,called in [('0',False),('1',True)]:
            _,_,sequence,maximum=self.descriptor(suffix)
            self.restart(sequence,1)
            if called:self.c.execute('SELECT nextval(%s::regclass)',[sequence])
            self.assertEqual(self.state(sequence),(1,called))
            self.c.execute(BODY)
            self.assertEqual(self.state(sequence),(maximum+1,False))

    def test_06_rollback_restores_sequence_alignment_state(self):
        _,_,sequence,maximum=self.descriptor('3')
        self.restart(sequence,1)
        try:
            with self.c.transaction():
                self.c.execute(BODY)
                self.assertEqual(self.state(sequence),(maximum+1,False))
                raise RuntimeError('Annulation volontaire de recette')
        except RuntimeError as error:
            self.assertEqual(str(error),'Annulation volontaire de recette')
        self.assertEqual(self.state(sequence),(1,False))

    def test_07_no_nontransactional_setval_or_business_rewrite(self):
        statements='\n'.join(line for line in TEXT.splitlines() if not line.lstrip().startswith('--')).lower()
        self.assertNotIn('setval(',statements)
        self.assertNotIn('update geolocalisation.',statements)
        self.assertNotIn('delete from',statements)
        self.assertNotIn('insert into',statements)


class TerritorySequencePreservation(unittest.TestCase):
    def test_08_migration_preserves_all_table_records_triggers_and_definitions(self):
        with psycopg.connect(DSN,autocommit=True) as c:
            tables=c.execute("SELECT n.nspname,c.relname FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE c.relkind='r' AND n.nspname=ANY(%s) ORDER BY 1,2",[['analytics','communication','geolocalisation','logistique','operations','professionnel','referentiel','support','systeme','public']]).fetchall()
            rows=[]
            for schema,table in tables:
                query=sql.SQL("SELECT md5(coalesce(jsonb_agg(to_jsonb(t) ORDER BY to_jsonb(t)::text)::text,'[]')) FROM {}.{} t").format(sql.Identifier(schema),sql.Identifier(table))
                rows.append((query,c.execute(query).fetchone()[0]))
            metadata_sql="""SELECT n.nspname,c.relname,t.tgname,pg_get_triggerdef(t.oid) FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid JOIN pg_namespace n ON n.oid=c.relnamespace WHERE NOT t.tgisinternal ORDER BY 1,2,3"""
            before=c.execute(metadata_sql).fetchall()
            sequences=c.execute('SELECT seqrelid::regclass::text,seqstart,seqincrement,seqmax,seqmin,seqcache,seqcycle FROM pg_sequence ORDER BY 1').fetchall()
            c.execute(TEXT);c.execute(TEXT)
            for query,value in rows:self.assertEqual(value,c.execute(query).fetchone()[0])
            self.assertEqual(before,c.execute(metadata_sql).fetchall())
            self.assertEqual(sequences,c.execute('SELECT seqrelid::regclass::text,seqstart,seqincrement,seqmax,seqmin,seqcache,seqcycle FROM pg_sequence ORDER BY 1').fetchall())


if __name__=='__main__':unittest.main(verbosity=2)
