"""Coordonnées territoriales : recette privée transactionnelle, sans import de contacts."""
import json
import os
from pathlib import Path
import unittest
from urllib.parse import urlsplit

import psycopg
from psycopg import sql
from psycopg.rows import dict_row

DSN=os.environ.get('SAUVERNDEKO_TEST_DATABASE_URL','')
location=urlsplit(DSN)
if location.hostname not in {'localhost','127.0.0.1','::1'} or not location.path.lstrip('/').startswith('sauverndeko_test_'):
    raise RuntimeError('Base privée locale sauverndeko_test_* obligatoire, sans repli source.')
MIGRATION=Path(__file__).resolve().parents[1]/'migrations/20261103_04_coordonnees_territoires.sql'
FIELDS=['AdresseTerritoire','TelephoneTerritoire','TelephoneSecondaireTerritoire','EmailTerritoire',
        'SiteWebTerritoire','InformationsAccueilTerritoire','CoordonneesModifieLe']


class TerritoryContactsSQL(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.c=psycopg.connect(DSN,autocommit=True,row_factory=dict_row)

    @classmethod
    def tearDownClass(cls):cls.c.close()

    def setUp(self):
        self.tx=self.c.transaction();self.tx.__enter__();self.parents={}
        for level in range(1,6):
            self.parents[level]=self.c.execute(sql.SQL('SELECT {} id FROM geolocalisation.{} ORDER BY {} LIMIT 1').format(
                sql.Identifier('ID_Niveau_'+str(level)),sql.Identifier('T_Niveau_'+str(level)),sql.Identifier('ID_Niveau_'+str(level)))).fetchone()['id']

    def tearDown(self):self.c.execute('ROLLBACK');self.tx.__exit__(None,None,None)

    def insert(self,level=1,**extra):
        values={'ID_Niveau_'+str(level)+'Fk':self.parents[level],**extra}
        query=sql.SQL('INSERT INTO geolocalisation."T_CoordonneesTerritoire" ({}) VALUES ({}) RETURNING *').format(
            sql.SQL(',').join(map(sql.Identifier,values)),sql.SQL(',').join(sql.Placeholder() for _ in values))
        return self.c.execute(query,list(values.values())).fetchone()

    def view(self,level):
        return self.c.execute(sql.SQL('SELECT * FROM geolocalisation.{} WHERE {}=%s').format(
            sql.Identifier('V_Niveau_'+str(level)),sql.Identifier('ID_Niveau_'+str(level))),[self.parents[level]]).fetchone()

    def test_01_shared_table_has_no_entity_or_personal_gps(self):
        fields=[r['column_name'] for r in self.c.execute("SELECT column_name FROM information_schema.columns WHERE table_schema='geolocalisation' AND table_name='T_CoordonneesTerritoire' ORDER BY ordinal_position")]
        self.assertEqual(fields,['ID_CoordonneesTerritoire',*[f'ID_Niveau_{n}Fk' for n in range(1,6)],*FIELDS[:-1],'ModifieLe','ModifieParUserFk'])

    def test_02_exactly_one_existing_parent(self):
        with self.assertRaises(psycopg.errors.CheckViolation):
            with self.c.transaction():self.c.execute('INSERT INTO geolocalisation."T_CoordonneesTerritoire" DEFAULT VALUES')
        with self.assertRaises(psycopg.errors.CheckViolation):
            with self.c.transaction():self.insert(ID_Niveau_2Fk=self.parents[2])
        with self.assertRaises(psycopg.errors.ForeignKeyViolation):
            with self.c.transaction():self.insert(ID_Niveau_1Fk=2147483647)

    def test_03_one_contact_per_real_territory_at_every_level(self):
        for level in range(1,6):
            self.insert(level,AdresseTerritoire='Adresse fictive '+str(level))
            with self.assertRaises(psycopg.errors.UniqueViolation):
                with self.c.transaction():self.insert(level,AdresseTerritoire='Doublon')

    def test_04_parent_and_identity_are_immutable(self):
        row=self.insert()
        for values in [{'ID_Niveau_1Fk':None,'ID_Niveau_2Fk':self.parents[2]},
                       {'ID_CoordonneesTerritoire':row['ID_CoordonneesTerritoire']+1000}]:
            with self.assertRaises((psycopg.errors.CheckViolation,psycopg.errors.GeneratedAlways)):
                with self.c.transaction():
                    self.c.execute(sql.SQL('UPDATE geolocalisation."T_CoordonneesTerritoire" SET {} WHERE "ID_CoordonneesTerritoire"=%s').format(
                        sql.SQL(',').join(sql.SQL('{}=%s').format(sql.Identifier(k)) for k in values)),[*values.values(),row['ID_CoordonneesTerritoire']])

    def test_05_contacts_project_at_all_levels_without_multiplication(self):
        for level in range(1,6):
            before=self.view(level)
            contact=self.insert(level,AdresseTerritoire='Adresse fictive',TelephoneTerritoire='+243000000000',
                TelephoneSecondaireTerritoire='+243000000001',EmailTerritoire='territoire@example.invalid',
                SiteWebTerritoire='https://example.invalid',InformationsAccueilTerritoire='Accueil déclaré')
            after=self.view(level)
            self.assertEqual({k:v for k,v in before.items() if k not in FIELDS},{k:v for k,v in after.items() if k not in FIELDS})
            for field in FIELDS[:-1]:self.assertEqual(after[field],contact[field])
            self.assertEqual(after['CoordonneesModifieLe'],contact['ModifieLe'])

    def test_06_no_contact_keeps_parent_visible_with_nulls(self):
        for level in range(1,6):
            self.assertTrue(all(self.view(level)[field] is None for field in FIELDS))

    def test_07_contact_delete_keeps_territory_and_old_derived_values(self):
        before=self.view(3);row=self.insert(3,AdresseTerritoire='Adresse à retirer')
        self.c.execute('DELETE FROM geolocalisation."T_CoordonneesTerritoire" WHERE "ID_CoordonneesTerritoire"=%s',[row['ID_CoordonneesTerritoire']])
        self.assertEqual(before,self.view(3))

    def test_08_text_limits_and_invalid_controls_are_guarded(self):
        for field,maximum in [('AdresseTerritoire',2000),('InformationsAccueilTerritoire',3000),
                              ('TelephoneTerritoire',50),('TelephoneSecondaireTerritoire',50),('EmailTerritoire',255),('SiteWebTerritoire',255)]:
            for value in ['x'*(maximum+1),'x\x01y',' leading','']:
                with self.assertRaises((psycopg.errors.CheckViolation,psycopg.errors.StringDataRightTruncation)):
                    with self.c.transaction():self.insert(**{field:value})
        self.insert(AdresseTerritoire='Adresse\nComplément',InformationsAccueilTerritoire='Texte\r\nAccueil')

    def test_09_email_and_web_forbid_embedded_whitespace(self):
        for field in ['EmailTerritoire','SiteWebTerritoire']:
            with self.assertRaises(psycopg.errors.CheckViolation):
                with self.c.transaction():self.insert(**{field:'two words'})

    def test_10_timestamp_and_actor_are_imposed(self):
        self.c.execute("SELECT set_config('systeme.actor_user_id','',true)")
        row=self.insert(ModifieLe='2000-01-01',ModifieParUserFk=2147483647)
        self.assertGreater(row['ModifieLe'].year,2000);self.assertIsNone(row['ModifieParUserFk'])
        actor=self.c.execute('SELECT "IdUser" id FROM systeme."T_Utilisateurs" WHERE "ValideUser" ORDER BY "IdUser" LIMIT 1').fetchone()['id']
        self.c.execute("SELECT set_config('systeme.actor_user_id',%s,true)",[str(actor)])
        updated=self.c.execute('UPDATE geolocalisation."T_CoordonneesTerritoire" SET "AdresseTerritoire"=%s,"ModifieLe"=%s WHERE "ID_CoordonneesTerritoire"=%s RETURNING *',['Actualisée','2000-01-01',row['ID_CoordonneesTerritoire']]).fetchone()
        self.assertEqual(updated['ModifieParUserFk'],actor);self.assertGreaterEqual(updated['ModifieLe'],row['ModifieLe'])

    def test_11_foreign_keys_are_real_and_no_parent_cascade(self):
        keys=self.c.execute("SELECT confrelid::regclass::text parent,confdeltype FROM pg_constraint WHERE conrelid='geolocalisation.\"T_CoordonneesTerritoire\"'::regclass AND contype='f'").fetchall()
        self.assertEqual(len(keys),6);self.assertTrue(all(r['confdeltype']=='a' for r in keys))

    def test_12_all_new_objects_have_useful_comments(self):
        missing=self.c.execute('''SELECT attname FROM pg_attribute WHERE attrelid='geolocalisation."T_CoordonneesTerritoire"'::regclass
            AND attnum>0 AND NOT attisdropped AND col_description(attrelid,attnum) IS NULL''').fetchall()
        self.assertEqual(missing,[])
        constraints=self.c.execute('''SELECT conname FROM pg_constraint WHERE conrelid='geolocalisation."T_CoordonneesTerritoire"'::regclass
            AND obj_description(oid,'pg_constraint') IS NULL''').fetchall();self.assertEqual(constraints,[])
        for level in range(1,6):
            for field in FIELDS:
                self.assertTrue(self.c.execute('''SELECT col_description(attrelid,attnum) description FROM pg_attribute
                    WHERE attrelid=%s::regclass AND attname=%s''',['geolocalisation."V_Niveau_'+str(level)+'"',field]).fetchone()['description'])

    def test_15_contacts_are_available_but_optional_in_table_and_export(self):
        for suffix in ['un','deux','trois','quatre','cinq']:
            columns=self.c.execute('SELECT "Colonnes" FROM referentiel."T_InterfaceTableau" WHERE "CleInterface"=%s',['territoires.niveaux-'+suffix]).fetchone()['Colonnes']
            for field in FIELDS:
                found=[column for column in columns if column['id']==field]
                self.assertEqual(len(found),1)
                self.assertIs(found[0]['exportable'],True);self.assertIs(found[0]['tableAvailable'],True)
                self.assertIs(found[0]['defaultVisible'],False);self.assertIs(found[0]['defaultExport'],False)


class TerritoryContactsReplay(unittest.TestCase):
    def test_13_replay_preserves_all_business_data_and_does_not_nest_views(self):
        with psycopg.connect(DSN,autocommit=True) as c:
            views=c.execute("SELECT c.relname,pg_get_viewdef(c.oid,true) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='geolocalisation' AND c.relname=ANY(%s) ORDER BY 1",[[f'V_Niveau_{n}' for n in range(1,6)]]).fetchall()
            tables=c.execute("SELECT n.nspname,c.relname FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE c.relkind='r' AND n.nspname=ANY(%s) ORDER BY 1,2",[['analytics','communication','geolocalisation','logistique','operations','professionnel','referentiel','support','systeme','public']]).fetchall()
            before=[]
            for schema,table in tables:
                query=sql.SQL("SELECT md5(coalesce(jsonb_agg(to_jsonb(t) ORDER BY to_jsonb(t)::text)::text,'[]')) FROM {}.{} t").format(sql.Identifier(schema),sql.Identifier(table))
                before.append((query,c.execute(query).fetchone()[0]))
            triggers=c.execute("SELECT tgrelid::regclass::text,tgname,pg_get_triggerdef(oid) FROM pg_trigger WHERE NOT tgisinternal ORDER BY 1,2").fetchall()
            for _ in range(2):c.execute(MIGRATION.read_text(encoding='utf8'))
            self.assertEqual(views,c.execute("SELECT c.relname,pg_get_viewdef(c.oid,true) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='geolocalisation' AND c.relname=ANY(%s) ORDER BY 1",[[f'V_Niveau_{n}' for n in range(1,6)]]).fetchall())
            for query,value in before:self.assertEqual(value,c.execute(query).fetchone()[0])
            self.assertEqual(triggers,c.execute("SELECT tgrelid::regclass::text,tgname,pg_get_triggerdef(oid) FROM pg_trigger WHERE NOT tgisinternal ORDER BY 1,2").fetchall())

    def test_14_direct_write_waits_for_versioned_parent_lock(self):
        with psycopg.connect(DSN,autocommit=True) as fixture:
            parent=fixture.execute('SELECT "ID_Niveau_1" FROM geolocalisation."T_Niveau_1" ORDER BY "ID_Niveau_1" LIMIT 1').fetchone()[0]
            key=fixture.execute('''INSERT INTO geolocalisation."T_CoordonneesTerritoire" ("ID_Niveau_1Fk","AdresseTerritoire")
                VALUES (%s,'Avant') RETURNING "ID_CoordonneesTerritoire"''',[parent]).fetchone()[0]
            try:
                with psycopg.connect(DSN) as owner,psycopg.connect(DSN,autocommit=True) as external:
                    owner.execute('SELECT "ID_Niveau_1" FROM geolocalisation."T_Niveau_1" WHERE "ID_Niveau_1"=%s FOR UPDATE',[parent])
                    external.execute("SET lock_timeout='300ms'")
                    for operation in ['UPDATE geolocalisation."T_CoordonneesTerritoire" SET "AdresseTerritoire"=\'Concurrent\' WHERE "ID_CoordonneesTerritoire"=%s',
                                      'DELETE FROM geolocalisation."T_CoordonneesTerritoire" WHERE "ID_CoordonneesTerritoire"=%s']:
                        with self.assertRaises(psycopg.errors.LockNotAvailable):external.execute(operation,[key])
                    self.assertEqual(owner.execute('SELECT "AdresseTerritoire" FROM geolocalisation."T_CoordonneesTerritoire" WHERE "ID_CoordonneesTerritoire"=%s',[key]).fetchone()[0],'Avant')
                    owner.commit()
                    external.execute('UPDATE geolocalisation."T_CoordonneesTerritoire" SET "AdresseTerritoire"=\'Après\' WHERE "ID_CoordonneesTerritoire"=%s',[key])
                    self.assertEqual(external.execute('SELECT "AdresseTerritoire" FROM geolocalisation."T_CoordonneesTerritoire" WHERE "ID_CoordonneesTerritoire"=%s',[key]).fetchone()[0],'Après')
            finally:
                fixture.execute('DELETE FROM geolocalisation."T_CoordonneesTerritoire" WHERE "ID_CoordonneesTerritoire"=%s',[key])


if __name__=='__main__':unittest.main(verbosity=2)
