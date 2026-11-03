"""Classification de présentation, indépendante des droits/licences.
Exécuter uniquement sur une recette sauverndeko_test_* après la migration08.
"""
import os
import unittest
from urllib.parse import urlsplit
import uuid
from pathlib import Path
import psycopg

DSN = os.environ.get("SAUVERNDEKO_TEST_DATABASE_URL", "")
if urlsplit(DSN).hostname not in {'localhost','127.0.0.1','::1'} or not urlsplit(DSN).path.lstrip("/").startswith("sauverndeko_test_"):
    raise RuntimeError("Base privée sauverndeko_test_* obligatoire.")


class ClassificationSQL(unittest.TestCase):
    def setUp(self):
        self.c = psycopg.connect(DSN)
        assert self.c.execute("SELECT current_database()").fetchone()[0].startswith("sauverndeko_test_")

    def tearDown(self):
        self.c.rollback()
        self.c.close()

    def reject(self, query, args):
        with self.assertRaises(psycopg.Error):
            with self.c.transaction():
                self.c.execute(query, args)

    def test_catalogue_and_historical_access_are_distinct(self):
        rows = {r[0]: r[1:] for r in self.c.execute('SELECT "CodeModule","TypeApplication","Commercialisable","ModuleParentCode","EstSocle","CodeIncluant" FROM systeme."T_ModuleApplication"')}
        for key in ["produits", "discussions", "structures", "professionnels", "logistique", "territoires", "support", "caisse"]:
            self.assertEqual(rows[key][:3], ("MODULE", True, None))
        for key in ["sante", "catalogue"]:
            self.assertEqual(rows[key][:3], ("FONCTIONNALITE", False, None))
        for key in ["sante"]:
            self.assertEqual(rows[key][4], "catalogue")  # original licence inclusion remains
        for key in ["administration", "parametres", "guide"]:
            self.assertEqual(rows[key][:3], ("FONCTIONNALITE", False, None))
            self.assertTrue(rows[key][3])  # common access preserved
        self.assertTrue(rows["territoires"][3])
        self.assertTrue(rows["discussions"][3])
        self.assertEqual(rows["produits"][4],"catalogue")
        visibility=dict(self.c.execute('SELECT "CodeModule","AfficherDansEspace" FROM systeme."T_ModuleApplication"'))
        self.assertFalse(visibility['sante'])
        self.assertFalse(visibility['catalogue'])
        self.assertTrue(all(visible for key,visible in visibility.items() if key not in {'sante','catalogue'}))
        self.assertNotIn('referentiels',rows)

    def test_only_modules_are_commercial(self):
        self.reject('UPDATE systeme."T_ModuleApplication" SET "Commercialisable"=true WHERE "CodeModule"=%s', ["sante"])
        self.reject('UPDATE systeme."T_ModuleApplication" SET "TypeApplication"=%s WHERE "CodeModule"=%s', ["OTHER", "produits"])

    def test_hierarchy_has_only_one_module_parent(self):
        self.reject('UPDATE systeme."T_ModuleApplication" SET "ModuleParentCode"=%s WHERE "CodeModule"=%s', ["guide", "sante"])
        self.reject('UPDATE systeme."T_ModuleApplication" SET "ModuleParentCode"=%s WHERE "CodeModule"=%s', ["catalogue", "catalogue"])
        child='test_'+uuid.uuid4().hex[:16]
        self.c.execute('''INSERT INTO systeme."T_ModuleApplication"("CodeModule","Nom","TypeApplication","ModuleParentCode")
            VALUES(%s,'Fonction fictive','FONCTIONNALITE','produits')''',[child])
        self.reject('UPDATE systeme."T_ModuleApplication" SET "TypeApplication"=%s,"Commercialisable"=false WHERE "CodeModule"=%s', ["FONCTIONNALITE", "produits"])
        self.reject('UPDATE systeme."T_ModuleApplication" SET "ModuleParentCode"=%s WHERE "CodeModule"=%s', ["unknown-module", "produits"])

    def test_classification_does_not_mutate_licences(self):
        before = self.c.execute('SELECT to_jsonb(x) FROM systeme."T_LicenceModule" x ORDER BY x."IdLicenceModule"').fetchall()
        user_before = self.c.execute('SELECT "IdUser","IdRoleFk","Is_Admin","Is_staff" FROM systeme."T_Utilisateurs" ORDER BY "IdUser"').fetchall()
        self.c.execute('UPDATE systeme."T_ModuleApplication" SET "Commercialisable"=false WHERE "CodeModule"=%s', ["caisse"])
        self.assertEqual(before, self.c.execute('SELECT to_jsonb(x) FROM systeme."T_LicenceModule" x ORDER BY x."IdLicenceModule"').fetchall())
        self.assertEqual(user_before, self.c.execute('SELECT "IdUser","IdRoleFk","Is_Admin","Is_staff" FROM systeme."T_Utilisateurs" ORDER BY "IdUser"').fetchall())
        module = "test_" + uuid.uuid4().hex[:16]
        self.c.execute('INSERT INTO systeme."T_ModuleApplication"("CodeModule","Nom") VALUES(%s,%s)', [module, "Module fictif"])
        self.assertEqual(self.c.execute('SELECT "TypeApplication","Commercialisable" FROM systeme."T_ModuleApplication" WHERE "CodeModule"=%s', [module]).fetchone(), ("MODULE", False))

    def test_workspace_flag_is_default_true_and_mandatory(self):
        module='test_'+uuid.uuid4().hex[:16]
        self.c.execute('INSERT INTO systeme."T_ModuleApplication"("CodeModule","Nom") VALUES(%s,%s)',[module,'Présentation fictive'])
        self.assertTrue(self.c.execute('SELECT "AfficherDansEspace" FROM systeme."T_ModuleApplication" WHERE "CodeModule"=%s',[module]).fetchone()[0])
        self.reject('UPDATE systeme."T_ModuleApplication" SET "AfficherDansEspace"=NULL WHERE "CodeModule"=%s',[module])
        self.c.execute('UPDATE systeme."T_ModuleApplication" SET "AfficherDansEspace"=false WHERE "CodeModule"=%s',[module])
        self.assertEqual(self.c.execute('SELECT "Actif","EstSocle","TypeApplication" FROM systeme."T_ModuleApplication" WHERE "CodeModule"=%s',[module]).fetchone(),(True,False,'MODULE'))
        self.assertTrue(self.c.execute('''SELECT obj_description(oid,'pg_constraint') FROM pg_constraint
            WHERE conrelid='systeme."T_ModuleApplication"'::regclass
            AND conname='T_ModuleApplication_AfficherDansEspace_not_null' ''').fetchone()[0])

    def test_catalogue_history_is_retained_but_not_sold_as_module(self):
        item=self.c.execute('''SELECT "TypeApplication","Commercialisable","AfficherDansEspace","Actif"
            FROM systeme."T_ModuleApplication" WHERE "CodeModule"='catalogue' ''').fetchone()
        self.assertEqual(item,('FONCTIONNALITE',False,False,True))
        included=dict(self.c.execute('''SELECT "CodeModule","CodeIncluant" FROM systeme."T_ModuleApplication"
            WHERE "CodeModule" IN ('produits','structures','professionnels','sante')'''))
        self.assertEqual(included,{key:'catalogue' for key in ('produits','structures','professionnels','sante')})

    def test_catalogue_migration_refuses_unexpected_presentation_children(self):
        self.c.execute('''UPDATE systeme."T_ModuleApplication" SET "TypeApplication"='MODULE',
            "Commercialisable"=true WHERE "CodeModule"='catalogue' ''')
        child='test_'+uuid.uuid4().hex[:16]
        self.c.execute('''INSERT INTO systeme."T_ModuleApplication"("CodeModule","Nom","TypeApplication","ModuleParentCode")
            VALUES(%s,'Fonction fictive','FONCTIONNALITE','catalogue')''',[child])
        migration=(Path(__file__).resolve().parents[1]/'migrations/20261103_08_catalogue_accueil.sql').read_text(encoding='utf8')
        # Le fichier garde sa transaction en installation ; ici le savepoint de
        # recette permet de vérifier le refus sans commettre de donnée fictive.
        body=migration[migration.index('BEGIN;')+len('BEGIN;'):migration.rindex('COMMIT;')]
        self.reject(body,[])
        self.assertEqual(self.c.execute('''SELECT "TypeApplication" FROM systeme."T_ModuleApplication"
            WHERE "CodeModule"='catalogue' ''').fetchone()[0],'MODULE')
        self.assertEqual(self.c.execute('''SELECT "ModuleParentCode" FROM systeme."T_ModuleApplication"
            WHERE "CodeModule"=%s''',[child]).fetchone()[0],'catalogue')


if __name__ == "__main__":
    unittest.main(verbosity=2)
