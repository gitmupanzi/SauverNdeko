"""Vues de l'annuaire : recette SQL transactionnelle sur clone local uniquement."""
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
MIGRATION = Path(__file__).resolve().parents[1] / 'migrations/20261103_02_annuaire_offres_articles.sql'
LEGACY = ['ID_Article','NomArticle','RefArticle','PVArticle','ID_DeviseFk','DeviseCode','DeviseLibelle',
          'Unite','EtatDisponibilite','PhotoArticle','IdEntite','NomEntite','AdresseEntite','PhoneEntite']


class OfferDirectorySQL(unittest.TestCase):
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
        self.entity = self.insert('systeme','T_Entite',{'NomEntite':'Annuaire fictif '+uuid.uuid4().hex,
            'EmailEntite':uuid.uuid4().hex+'@example.invalid','ValideEntite':True},'IdEntite')
        self.user = self.insert('systeme','T_Utilisateurs',{'NomUser':'Recette','PrenomUser':'Annuaire',
            'EmailUser':uuid.uuid4().hex+'@example.invalid','MotdepasseUser':'inutilisable',
            'ValideUser':True,'IdEntiteFk':self.entity,'Is_Admin':False,'SexeUser':'M'},'IdUser')
        self.refs = {}
        for field in ['ID_TypeArticleFk','ID_CategorieArticleFk','ID_UniteFk','ID_DeviseFk']:
            self.refs[field] = self.c.execute('''SELECT g."ID_Generique" id FROM referentiel."T_Generique" g
                WHERE g."ValideGenerique" AND g."IdEntiteFk" IS NULL
                  AND g."ID_CategorieGeneriqueFk"=ANY(referentiel.fn_categories_champ('logistique','T_Article',%s,%s))
                ORDER BY g."ID_Generique" LIMIT 1''',[field,self.entity]).fetchone()['id']

    def tearDown(self):
        self.c.execute('ROLLBACK'); self.tx.__exit__(None,None,None)

    def insert(self,schema,table,values,key):
        statement=sql.SQL('INSERT INTO {}.{} ({}) VALUES ({}) RETURNING {} id').format(
            sql.Identifier(schema),sql.Identifier(table),sql.SQL(',').join(map(sql.Identifier,values)),
            sql.SQL(',').join(sql.Placeholder() for _ in values),sql.Identifier(key))
        return self.c.execute(statement,list(values.values())).fetchone()['id']

    def article(self,**extra):
        return self.insert('logistique','T_Article',{**self.refs,'IdEntiteFk':self.entity,'ID_UserFK':self.user,
            'NomArticle':'Offre fictive annuaire','PUArticle':12,'PVArticle':15,'QteArticle':0,
            'ValideArticle':True,'VisibleCatalogue':True,**extra},'ID_Article')

    def offer(self,pk):
        return self.c.execute('SELECT * FROM logistique."V_OffreArticle" WHERE "ID_Article"=%s',[pk]).fetchone()

    def points(self,pk):
        return self.c.execute('SELECT * FROM logistique."V_OffreArticleLocalisation" WHERE "ID_Article"=%s ORDER BY label,address',[pk]).fetchall()

    def test_01_legacy_order_preserved_and_closed_extension(self):
        columns=self.c.execute("SELECT column_name FROM information_schema.columns WHERE table_schema='logistique' AND table_name='V_OffreArticle' ORDER BY ordinal_position").fetchall()
        self.assertEqual([r['column_name'] for r in columns],LEGACY+['ID_CategorieArticleFk','CategorieArticle','ID_TypeArticleFk','TypeArticle'])
        row=self.offer(self.article(ObsArticle='NOTE PRIVEE',InformationArticle='Information privée'))
        self.assertEqual(set(row),set(LEGACY+['ID_CategorieArticleFk','CategorieArticle','ID_TypeArticleFk','TypeArticle']))
        self.assertTrue({'PUArticle','QteArticle','ObsArticle','InformationArticle','ID_UserFK'}.isdisjoint(row))

    def test_02_categories_and_types_use_recorded_central_values(self):
        pk=self.article()
        row=self.offer(pk)
        for field,label in [('ID_CategorieArticleFk','CategorieArticle'),('ID_TypeArticleFk','TypeArticle')]:
            reference=self.c.execute('SELECT "NomGenerique","AbrGenerique" FROM referentiel."T_Generique" WHERE "ID_Generique"=%s',[self.refs[field]]).fetchone()
            self.assertEqual(row[field],self.refs[field])
            self.assertEqual(row[label],reference['AbrGenerique'] or reference['NomGenerique'])

    def test_03_inactive_old_reference_is_not_rewritten_or_hidden(self):
        pk=self.article()
        self.c.execute('UPDATE referentiel."T_Generique" SET "ValideGenerique"=false WHERE "ID_Generique"=%s',[self.refs['ID_CategorieArticleFk']])
        self.assertEqual(self.offer(pk)['ID_CategorieArticleFk'],self.refs['ID_CategorieArticleFk'])

    def test_04_offer_without_location_has_no_fictitious_point(self):
        pk=self.article()
        self.assertEqual(self.points(pk),[])
        # Une coordonnée brute sans adresse ni niveau n'est pas une adresse publiable.
        self.insert('systeme','T_Entite_Localisation',{'IdEntiteFk':self.entity,'Latitude':1,'Longitude':2},'IdEntiteLocalisation')
        self.assertEqual(self.points(pk),[])

    def test_05_declared_addresses_only_and_no_private_point_metadata(self):
        pk=self.article()
        self.insert('systeme','T_Entite_Localisation',{'IdEntiteFk':self.entity,'AdresseDetaillee':'Adresse fictive A',
            'Latitude':1,'Longitude':2},'IdEntiteLocalisation')
        self.insert('systeme','T_Entite_Localisation',{'IdEntiteFk':self.entity,'AdresseDetaillee':'Adresse fictive B'},'IdEntiteLocalisation')
        points=self.points(pk)
        self.assertEqual(len(points),2)
        self.assertEqual(set(points[0]),{'ID_Article','label','address','zone','area','site'})
        self.assertEqual([p['address'] for p in points],['Adresse fictive A','Adresse fictive B'])
        self.assertTrue(all(p['zone'] is None and p['area'] is None and p['site'] is None for p in points))

    def test_06_territorial_labels_are_declared_not_inferred(self):
        pk=self.article()
        zone=self.c.execute('SELECT "ID_Niveau_3" id,"NomNiveau_3" name FROM geolocalisation."T_Niveau_3" ORDER BY "ID_Niveau_3" LIMIT 1').fetchone()
        if zone is None:
            self.skipTest('Le clone ne possède aucun niveau 3 pour ce contrôle.')
        self.insert('systeme','T_Entite_Localisation',{'IdEntiteFk':self.entity,'IdNiveau_3_Fk':zone['id'],
            'AdresseDetaillee':'Adresse territoriale fictive'},'IdEntiteLocalisation')
        point=self.points(pk)[0]
        self.assertEqual(point['zone'],zone['name'])
        self.assertEqual(point['label'],zone['name'])
        self.assertIsNone(point['area']);self.assertIsNone(point['site'])

    def test_07_unpublication_or_inactive_owner_removes_addresses(self):
        pk=self.article()
        self.insert('systeme','T_Entite_Localisation',{'IdEntiteFk':self.entity,'AdresseDetaillee':'Adresse à retirer'},'IdEntiteLocalisation')
        self.assertEqual(len(self.points(pk)),1)
        self.c.execute('UPDATE logistique."T_Article" SET "VisibleCatalogue"=false WHERE "ID_Article"=%s',[pk])
        self.assertEqual(self.points(pk),[])
        self.c.execute('UPDATE logistique."T_Article" SET "VisibleCatalogue"=true WHERE "ID_Article"=%s',[pk])
        self.c.execute('UPDATE systeme."T_Entite" SET "ValideEntite"=false WHERE "IdEntite"=%s',[self.entity])
        self.assertEqual(self.points(pk),[])

    def test_08_all_new_view_columns_are_commented(self):
        missing=self.c.execute('''SELECT c.relname,a.attname FROM pg_class c
            JOIN pg_namespace n ON n.oid=c.relnamespace JOIN pg_attribute a ON a.attrelid=c.oid
            WHERE n.nspname='logistique' AND c.relname IN ('V_OffreArticle','V_OffreArticleLocalisation')
              AND a.attnum>0 AND NOT a.attisdropped AND col_description(c.oid,a.attnum) IS NULL''').fetchall()
        self.assertEqual(missing,[])


class DirectoryMigrationReplay(unittest.TestCase):
    def test_09_replay_preserves_all_business_records_and_triggers(self):
        with psycopg.connect(DSN,autocommit=True,row_factory=dict_row) as c:
            snapshots={}
            for schema,table in [('logistique','T_Article'),('logistique','T_Mouvement'),('logistique','T_LotArticle'),
                                 ('logistique','T_Commande'),('logistique','T_CommandeDetail'),
                                 ('systeme','T_Entite'),('systeme','T_Entite_Localisation')]:
                query=sql.SQL('SELECT md5(COALESCE(jsonb_agg(to_jsonb(t) ORDER BY to_jsonb(t)::text)::text,\'[]\')) hash FROM {}.{} t').format(sql.Identifier(schema),sql.Identifier(table))
                snapshots[(schema,table)]=(query,c.execute(query).fetchone()['hash'])
            triggers=c.execute("SELECT tgrelid::regclass::text relation,tgname,pg_get_triggerdef(oid) definition FROM pg_trigger WHERE NOT tgisinternal ORDER BY 1,2").fetchall()
            c.execute(MIGRATION.read_text(encoding='utf8'))
            for query,before in snapshots.values():
                self.assertEqual(before,c.execute(query).fetchone()['hash'])
            self.assertEqual(triggers,c.execute("SELECT tgrelid::regclass::text relation,tgname,pg_get_triggerdef(oid) definition FROM pg_trigger WHERE NOT tgisinternal ORDER BY 1,2").fetchall())


if __name__=='__main__':
    unittest.main(verbosity=2)
