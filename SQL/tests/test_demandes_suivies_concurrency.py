"""Three real concurrency checks on a disposable, isolated PostgreSQL clone.

Set SAUVERNDEKO_TEST_DATABASE_URL to an idle loopback sauverndeko_test_* copy.
The source is never modified. CREATE DATABASE permission is required; no session
is terminated. All committed fictitious records disappear with the temporary
clone, which is dropped only after its own connections have closed.
"""
from concurrent.futures import ThreadPoolExecutor
import importlib.util
import os
from pathlib import Path
from threading import Barrier
import unittest
from urllib.parse import urlsplit,urlunsplit
import uuid

import psycopg
from psycopg import sql

ROOT=Path(__file__).resolve().parents[2]
SOURCE=os.environ.get('SAUVERNDEKO_TEST_DATABASE_URL','')
location=urlsplit(SOURCE)
if location.hostname not in {'localhost','127.0.0.1','::1'} or not location.path[1:].startswith('sauverndeko_test_'):
    raise RuntimeError('Recette concurrente réservée à une copie locale sauverndeko_test_*.')
SOURCE_NAME=location.path[1:]
ADMIN_DSN=urlunsplit(location._replace(path='/postgres'))


class DemandesConcurrency(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # The name is generated here, never accepted as an arbitrary deletion target.
        cls.clone='sauverndeko_test_demandes_race_'+uuid.uuid4().hex[:14]
        cls.dsn=urlunsplit(location._replace(path='/'+cls.clone))
        with psycopg.connect(ADMIN_DSN,autocommit=True) as admin:
            if not admin.execute('SELECT oid FROM pg_database WHERE datname=%s',[SOURCE_NAME]).fetchone():
                raise RuntimeError('Copie source inexistante.')
            if admin.execute('SELECT count(*) FROM pg_stat_activity WHERE datname=%s',[SOURCE_NAME]).fetchone()[0]:
                raise RuntimeError('La copie source est utilisée ; aucun arrêt de connexion autorisé.')
            admin.execute(sql.SQL('CREATE DATABASE {} TEMPLATE {}').format(sql.Identifier(cls.clone),sql.Identifier(SOURCE_NAME)))
        cls.addClassCleanup(cls.drop_clone)
        os.environ['SAUVERNDEKO_TEST_DATABASE_URL']=cls.dsn
        spec=importlib.util.spec_from_file_location('demandes_api_fixture',ROOT/'SQL/tests/test_demandes_suivies_api.py')
        cls.m=importlib.util.module_from_spec(spec);spec.loader.exec_module(cls.m)
        from django.db import transaction
        case=cls.m.DemandesSuiviesAPI();case.tag='Recette concurrence '+uuid.uuid4().hex[:8]
        with transaction.atomic():
            case.a=case.company();case.b=case.company()
            case.alice=case.user(case.a);case.manager=case.user(case.b,admin=True);case.product=case.article()
        cls.fixture=case

    @classmethod
    def drop_clone(cls):
        from django.db import connections
        connections.close_all()
        assert cls.clone.startswith('sauverndeko_test_demandes_race_') and len(cls.clone)==45
        with psycopg.connect(ADMIN_DSN,autocommit=True) as admin:
            count=admin.execute('SELECT count(*) FROM pg_stat_activity WHERE datname=%s',[cls.clone]).fetchone()[0]
            if count:
                raise RuntimeError('Connexions restantes sur le clone éphémère ; aucune terminaison forcée.')
            admin.execute(sql.SQL('DROP DATABASE {}').format(sql.Identifier(cls.clone)))
        os.environ['SAUVERNDEKO_TEST_DATABASE_URL']=SOURCE

    def race(self,items):
        gate=Barrier(len(items))
        def run(item):
            try:
                with psycopg.connect(self.dsn) as connection:
                    self.assertEqual(connection.execute('SELECT current_database()').fetchone()[0],self.clone)
                    connection.execute("SET statement_timeout='10s'")
                    gate.wait(timeout=8)
                    value=connection.execute(*item).fetchone()[0]
                return {'ok':True,'id':value}
            except psycopg.Error as error:
                return {'ok':False,'sqlstate':error.sqlstate}
        with ThreadPoolExecutor(max_workers=len(items)) as pool:
            return list(pool.map(run,items))

    def creation(self,key=None):
        f=self.fixture
        return ('SELECT communication.fn_demande_creer(%s,%s,%s,%s,%s,%s,%s,%s)',
                [f.alice['IdUser'],'product',f.product,f.tag,'Besoin fictif de concurrence, sans donnée médicale.',None,None,key or str(uuid.uuid4())])

    def create(self):
        with psycopg.connect(self.dsn) as connection:
            identifier=connection.execute(*self.creation()).fetchone()[0]
        return identifier

    def test_creation_replay_creates_one_request(self):
        operation=self.creation()
        results=self.race([operation,operation])
        self.assertTrue(all(item['ok'] for item in results),results)
        self.assertEqual(results[0]['id'],results[1]['id'])
        with psycopg.connect(self.dsn) as connection:
            count=connection.execute('SELECT count(*) FROM communication."T_DemandeHistorique" WHERE "IdAuteurFk"=%s AND "CleRequete"=%s',
                [self.fixture.alice['IdUser'],operation[1][-1]]).fetchone()[0]
        self.assertEqual(count,1)

    def test_competing_closures_commit_only_one_history(self):
        identifier=self.create()
        operations=[('SELECT communication.fn_demande_transition(%s,%s,%s,%s,%s,%s)',
            [self.fixture.alice['IdUser'],identifier,state,1,'Motif fictif de concurrence.',str(uuid.uuid4())]) for state in ('annulee','non_satisfaite')]
        results=self.race(operations)
        self.assertEqual(sum(item['ok'] for item in results),1,results)
        self.assertEqual([item['sqlstate'] for item in results if not item['ok']],['PDE05'])
        with psycopg.connect(self.dsn) as connection:
            current=connection.execute('SELECT "VersionDemande" FROM communication."T_Demande" WHERE "IdDemande"=%s',[identifier]).fetchone()[0]
            count=connection.execute('SELECT count(*) FROM communication."T_DemandeHistorique" WHERE "IdDemandeFk"=%s AND "ActionDemande"=\'transition\'',[identifier]).fetchone()[0]
        self.assertEqual((current,count),(2,1))

    def test_two_participants_open_only_one_conversation(self):
        identifier=self.create()
        operations=[('SELECT communication.fn_demande_discussion(%s,%s,%s,%s)',
            [user,identifier,1,str(uuid.uuid4())]) for user in (self.fixture.alice['IdUser'],self.fixture.manager['IdUser'])]
        results=self.race(operations)
        self.assertTrue(all(item['ok'] for item in results),results)
        self.assertEqual(results[0]['id'],results[1]['id'])
        with psycopg.connect(self.dsn) as connection:
            count=connection.execute('SELECT count(*) FROM communication."T_Discussion" WHERE "IdDemandeFk"=%s',[identifier]).fetchone()[0]
        self.assertEqual(count,1)


if __name__=='__main__':
    unittest.main(verbosity=2)
