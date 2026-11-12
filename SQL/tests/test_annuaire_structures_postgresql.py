"""Projection Structures : recette transactionnelle, bases privées locales seulement."""
import os
from pathlib import Path
import unittest
from urllib.parse import urlsplit
import uuid

import psycopg
from psycopg import sql
from psycopg.rows import dict_row

DSN = os.environ.get('SAUVERNDEKO_TEST_DATABASE_URL', '')
location = urlsplit(DSN)
if location.hostname not in {'localhost', '127.0.0.1', '::1'} or not location.path.lstrip('/').startswith('sauverndeko_test_'):
    raise RuntimeError('Une base privée locale sauverndeko_test_* est obligatoire, sans repli source.')
MIGRATION = Path(__file__).resolve().parents[2] / 'backend/database/migrations/20261103_03_annuaire_structures.sql'
LEGACY = ['IdEntite','NomEntite','PhoneEntite','AdresseEntite','ValideEntite','T_Generique']
PUBLIC = ['IdEntite','NomEntite','IdTypeEntiteFk','TypeEntite','AdresseEntite','PhoneEntite',
          'SiteWebEntite','PresentationPubliqueEntite','HasLogo','LogoMimeEntite','LogoSha256Entite']
TYPES = ['Pharmacie','Dépôt pharmaceutique','Établissement de santé','Agence immobilière',
         'Promoteur immobilier','Entreprise de construction','Bureau d’études','Cabinet d’architecture']


class StructureDirectorySQL(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.c = psycopg.connect(DSN, autocommit=True, row_factory=dict_row)
        if not cls.c.execute('SELECT current_database() d').fetchone()['d'].startswith('sauverndeko_test_'):
            raise RuntimeError('Base de recette privée requise.')

    @classmethod
    def tearDownClass(cls):
        cls.c.close()

    def setUp(self):
        self.tx = self.c.transaction(); self.tx.__enter__()
        self.entity = self.insert('systeme','T_Entite',{'NomEntite':'Structure fictive '+uuid.uuid4().hex,
            'EmailEntite':uuid.uuid4().hex+'@example.invalid','ValideEntite':True},'IdEntite')

    def tearDown(self):
        self.c.execute('ROLLBACK'); self.tx.__exit__(None,None,None)

    def insert(self,schema,table,values,key):
        statement=sql.SQL('INSERT INTO {}.{} ({}) VALUES ({}) RETURNING {} id').format(
            sql.Identifier(schema),sql.Identifier(table),sql.SQL(',').join(map(sql.Identifier,values)),
            sql.SQL(',').join(sql.Placeholder() for _ in values),sql.Identifier(key))
        return self.c.execute(statement,list(values.values())).fetchone()['id']

    def record(self,view='V_StructurePublique'):
        return self.c.execute(sql.SQL('SELECT * FROM systeme.{} WHERE "IdEntite"=%s').format(sql.Identifier(view)),[self.entity]).fetchone()

    def publish(self,active=True):
        self.c.execute('UPDATE systeme."T_Entite" SET "VisibleAnnuaireEntite"=true,"ValideEntite"=%s WHERE "IdEntite"=%s',[active,self.entity])

    def points(self):
        return self.c.execute('SELECT * FROM systeme."V_StructureLocalisation" WHERE "IdEntite"=%s ORDER BY label,address',[self.entity]).fetchall()

    def test_01_new_company_is_not_published_implicitly(self):
        row=self.c.execute('SELECT "VisibleAnnuaireEntite","PartageArticlesPublicParDefaut" FROM systeme."T_Entite" WHERE "IdEntite"=%s',[self.entity]).fetchone()
        self.assertIs(row['VisibleAnnuaireEntite'],False)
        self.assertIs(row['PartageArticlesPublicParDefaut'],True)
        self.assertIsNone(self.record()); self.assertIsNone(self.record('V_Entite_Public'))

    def test_02_optin_and_activity_gate_both_projections(self):
        self.publish()
        self.assertIsNotNone(self.record()); self.assertIsNotNone(self.record('V_Entite_Public'))
        self.publish(active=False)
        self.assertIsNone(self.record()); self.assertIsNone(self.record('V_Entite_Public'))
        self.c.execute('UPDATE systeme."T_Entite" SET "ValideEntite"=true,"VisibleAnnuaireEntite"=false WHERE "IdEntite"=%s',[self.entity])
        self.assertIsNone(self.record()); self.assertIsNone(self.record('V_Entite_Public'))

    def test_03_exact_closed_contract_and_legacy_shape(self):
        self.publish()
        self.assertEqual(list(self.record()),PUBLIC)
        self.assertEqual(list(self.record('V_Entite_Public')),LEGACY)
        forbidden={'EmailEntite','IdentifiantsLegauxEntite','MentionDocumentaireEntite','LogoEntite',
                   'DateCreationEntite','TauxTVAEntite','PartageArticlesPublicParDefaut','VisibleAnnuaireEntite'}
        self.assertTrue(forbidden.isdisjoint(self.record()))

    def test_04_presentation_accepts_plain_text_and_limits_length(self):
        self.publish()
        text='<strong>Texte non interprété</strong>\n'+'x'*4950
        self.c.execute('UPDATE systeme."T_Entite" SET "PresentationPubliqueEntite"=%s WHERE "IdEntite"=%s',[text,self.entity])
        self.assertEqual(self.record()['PresentationPubliqueEntite'],text)
        with self.assertRaises(psycopg.errors.CheckViolation):
            with self.c.transaction():
                self.c.execute('UPDATE systeme."T_Entite" SET "PresentationPubliqueEntite"=%s WHERE "IdEntite"=%s',['x'*5001,self.entity])
        self.assertEqual(self.record()['PresentationPubliqueEntite'],text)

    def test_05_type_uses_existing_central_value_and_preserves_old_fk(self):
        family=self.c.execute("SELECT referentiel.fn_categories_champ('systeme','T_Entite','IdTypeEntiteFk',NULL) ids").fetchone()['ids'][0]
        typ=self.c.execute('SELECT "ID_Generique" id,"NomGenerique" name,"AbrGenerique" code FROM referentiel."T_Generique" WHERE "ID_CategorieGeneriqueFk"=%s AND "IdEntiteFk" IS NULL AND "ValideGenerique" ORDER BY "ID_Generique" LIMIT 1',[family]).fetchone()
        self.c.execute('UPDATE systeme."T_Entite" SET "IdTypeEntiteFk"=%s WHERE "IdEntite"=%s',[typ['id'],self.entity])
        self.publish()
        self.assertEqual(self.record()['IdTypeEntiteFk'],typ['id'])
        self.assertEqual(self.record()['TypeEntite'],typ['code'] or typ['name'])
        self.c.execute('UPDATE referentiel."T_Generique" SET "ValideGenerique"=false WHERE "ID_Generique"=%s',[typ['id']])
        self.assertEqual(self.record()['IdTypeEntiteFk'],typ['id'])

    def test_06_no_fictitious_location_or_raw_gps(self):
        self.publish()
        self.assertEqual(self.points(),[])
        self.insert('systeme','T_Entite_Localisation',{'IdEntiteFk':self.entity,'Latitude':1,'Longitude':2},'IdEntiteLocalisation')
        self.assertEqual(self.points(),[])
        self.insert('systeme','T_Entite_Localisation',{'IdEntiteFk':self.entity,'AdresseDetaillee':'Adresse fictive',
            'Latitude':1,'Longitude':2},'IdEntiteLocalisation')
        point=self.points()[0]
        self.assertEqual(list(point),['IdEntite','label','address','zone','area','site'])
        self.assertEqual(point['label'],'Adresse fictive')
        self.assertIsNone(point['zone']); self.assertIsNone(point['area']); self.assertIsNone(point['site'])

    def test_07_explicit_territorial_labels_only(self):
        self.publish()
        zone=self.c.execute('SELECT "ID_Niveau_3" id,"NomNiveau_3" name FROM geolocalisation."T_Niveau_3" ORDER BY "ID_Niveau_3" LIMIT 1').fetchone()
        self.assertIsNotNone(zone,'La restauration doit comporter le référentiel territorial existant.')
        self.insert('systeme','T_Entite_Localisation',{'IdEntiteFk':self.entity,'IdNiveau_3_Fk':zone['id'],
            'AdresseDetaillee':'Adresse déclarée'},'IdEntiteLocalisation')
        point=self.points()[0]
        self.assertEqual(point['zone'],zone['name']); self.assertEqual(point['label'],zone['name'])
        self.assertIsNone(point['area']);self.assertIsNone(point['site'])

    def test_08_location_retraction_and_other_company_isolation(self):
        self.insert('systeme','T_Entite_Localisation',{'IdEntiteFk':self.entity,'AdresseDetaillee':'Adresse privée'},'IdEntiteLocalisation')
        self.assertEqual(self.points(),[])
        self.publish(); self.assertEqual(len(self.points()),1)
        other=self.insert('systeme','T_Entite',{'NomEntite':'Autre structure fictive',
            'EmailEntite':uuid.uuid4().hex+'@example.invalid','VisibleAnnuaireEntite':True},'IdEntite')
        self.insert('systeme','T_Entite_Localisation',{'IdEntiteFk':other,'AdresseDetaillee':'Autre adresse'},'IdEntiteLocalisation')
        self.assertEqual(len(self.points()),1)
        self.publish(active=False);self.assertEqual(self.points(),[])

    def test_09_publication_is_independent_of_article_default_and_stock(self):
        before=self.c.execute('SELECT "PartageArticlesPublicParDefaut" value FROM systeme."T_Entite" WHERE "IdEntite"=%s',[self.entity]).fetchone()['value']
        self.publish()
        self.assertEqual(before,self.c.execute('SELECT "PartageArticlesPublicParDefaut" value FROM systeme."T_Entite" WHERE "IdEntite"=%s',[self.entity]).fetchone()['value'])
        self.c.execute('UPDATE systeme."T_Entite" SET "PartageArticlesPublicParDefaut"=false WHERE "IdEntite"=%s',[self.entity])
        self.assertIsNotNone(self.record())

    def test_10_all_new_columns_and_views_have_comments(self):
        rows=self.c.execute('''SELECT c.relname,a.attname FROM pg_class c
            JOIN pg_namespace n ON n.oid=c.relnamespace JOIN pg_attribute a ON a.attrelid=c.oid
            WHERE n.nspname='systeme' AND a.attnum>0 AND NOT a.attisdropped
             AND (c.relname IN ('V_StructurePublique','V_StructureLocalisation')
                  OR c.relname='T_Entite' AND a.attname IN ('VisibleAnnuaireEntite','PresentationPubliqueEntite'))
             AND col_description(c.oid,a.attnum) IS NULL''').fetchall()
        self.assertEqual(rows,[])
        for name in ['V_StructurePublique','V_StructureLocalisation']:
            self.assertTrue(self.c.execute("SELECT obj_description(%s::regclass) value",['systeme."'+name+'"']).fetchone()['value'])

    def test_11_eight_active_common_types_in_configured_family(self):
        families=self.c.execute("SELECT referentiel.fn_categories_champ('systeme','T_Entite','IdTypeEntiteFk',NULL) ids").fetchone()['ids']
        self.assertEqual(len(families),1)
        for name in TYPES:
            rows=self.c.execute('''SELECT "IdEntiteFk","ValideGenerique" FROM referentiel."T_Generique"
                WHERE "ID_CategorieGeneriqueFk"=%s AND referentiel.fn_normaliser_libelle("NomGenerique")=referentiel.fn_normaliser_libelle(%s)''',[families[0],name]).fetchall()
            self.assertEqual(len(rows),1); self.assertIsNone(rows[0]['IdEntiteFk']); self.assertIs(rows[0]['ValideGenerique'],True)

    def test_12_inactive_existing_type_fails_instead_of_overwriting(self):
        self.c.execute('''UPDATE referentiel."T_Generique" SET "ValideGenerique"=false WHERE "IdEntiteFk" IS NULL
            AND "NomGenerique"='Pharmacie' AND "ID_CategorieGeneriqueFk"=ANY(referentiel.fn_categories_champ('systeme','T_Entite','IdTypeEntiteFk',NULL))''')
        seed=MIGRATION.read_text(encoding='utf8').split('-- Nomenclature commune,',1)[1]
        seed=seed[seed.index('DO $$'):].removesuffix('COMMIT;\n')
        with self.assertRaisesRegex(psycopg.errors.RaiseException,'inactif'):
            with self.c.transaction(): self.c.execute(seed)

    def test_13_no_public_grant_is_introduced(self):
        rows=self.c.execute('''SELECT c.relname,p.privilege_type FROM pg_class c
            JOIN pg_namespace n ON n.oid=c.relnamespace CROSS JOIN LATERAL aclexplode(c.relacl) p
            WHERE n.nspname='systeme' AND c.relname IN ('V_StructurePublique','V_StructureLocalisation')
             AND p.grantee=0''').fetchall()
        self.assertEqual(rows,[])

    def test_14_inactive_configured_category_fails_explicitly(self):
        family=self.c.execute("SELECT referentiel.fn_categories_champ('systeme','T_Entite','IdTypeEntiteFk',NULL) ids").fetchone()['ids'][0]
        self.c.execute('UPDATE referentiel."T_CategorieGenerique" SET "ValideCategorieGenerique"=false WHERE "ID_CategorieGenerique"=%s',[family])
        seed=MIGRATION.read_text(encoding='utf8').split('-- Nomenclature commune,',1)[1]
        seed=seed[seed.index('DO $$'):].removesuffix('COMMIT;\n')
        with self.assertRaisesRegex(psycopg.errors.RaiseException,'commune et active'):
            with self.c.transaction():self.c.execute(seed)

    def test_15_current_professional_identity_not_a_stale_copy(self):
        self.publish()
        self.c.execute('''UPDATE systeme."T_Entite" SET "NomEntite"='Structure renommée',
            "PhoneEntite"='0123456789',"AdresseEntite"='Adresse modifiée',"SiteWebEntite"='https://example.invalid',
            "PresentationPubliqueEntite"='Présentation modifiée' WHERE "IdEntite"=%s''',[self.entity])
        row=self.record()
        self.assertEqual(row['NomEntite'],'Structure renommée');self.assertEqual(row['PhoneEntite'],'0123456789')
        self.assertEqual(row['AdresseEntite'],'Adresse modifiée');self.assertEqual(row['SiteWebEntite'],'https://example.invalid')
        self.assertEqual(row['PresentationPubliqueEntite'],'Présentation modifiée')
        self.assertEqual(self.record('V_Entite_Public')['NomEntite'],'Structure renommée')


class StructureMigrationReplay(unittest.TestCase):
    def test_16_replay_preserves_all_records_and_existing_triggers(self):
        with psycopg.connect(DSN,autocommit=True,row_factory=dict_row) as c:
            tables=c.execute("""SELECT n.nspname schema,c.relname name FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
                WHERE c.relkind='r' AND n.nspname=ANY(%s) ORDER BY 1,2""",
                [['analytics','communication','geolocalisation','logistique','operations','professionnel','referentiel','support','systeme','public']]).fetchall()
            snapshots=[]
            for table in tables:
                query=sql.SQL("SELECT md5(COALESCE(jsonb_agg(to_jsonb(t) ORDER BY to_jsonb(t)::text)::text,'[]')) hash FROM {}.{} t").format(sql.Identifier(table['schema']),sql.Identifier(table['name']))
                snapshots.append((query,c.execute(query).fetchone()['hash']))
            triggers=c.execute("SELECT tgrelid::regclass::text relation,tgname,pg_get_triggerdef(oid) definition FROM pg_trigger WHERE NOT tgisinternal ORDER BY 1,2").fetchall()
            for _ in range(2):c.execute(MIGRATION.read_text(encoding='utf8'))
            for query,before in snapshots:self.assertEqual(before,c.execute(query).fetchone()['hash'])
            self.assertEqual(triggers,c.execute("SELECT tgrelid::regclass::text relation,tgname,pg_get_triggerdef(oid) definition FROM pg_trigger WHERE NOT tgisinternal ORDER BY 1,2").fetchall())


if __name__=='__main__':
    unittest.main(verbosity=2)
