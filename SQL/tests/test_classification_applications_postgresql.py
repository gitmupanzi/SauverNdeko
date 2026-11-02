"""Classification de présentation, indépendante des droits/licences.
Exécuter uniquement sur une recette sauverndeko_test_* après migration04.
"""
import os
import unittest
from urllib.parse import urlsplit
import uuid
import psycopg

DSN = os.environ.get("SAUVERNDEKO_TEST_DATABASE_URL", "")
if not urlsplit(DSN).path.lstrip("/").startswith("sauverndeko_test_"):
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
        for key in ["catalogue", "structures", "professionnels", "logistique", "territoires", "support", "caisse"]:
            self.assertEqual(rows[key][:3], ("MODULE", True, None))
        for key in ["produits", "sante"]:
            self.assertEqual(rows[key][:3], ("FONCTIONNALITE", False, "catalogue"))
            self.assertEqual(rows[key][4], "catalogue")  # original licence inclusion remains
        for key in ["discussions", "administration", "parametres", "guide"]:
            self.assertEqual(rows[key][:3], ("FONCTIONNALITE", False, None))
            self.assertTrue(rows[key][3])  # common access preserved
        self.assertTrue(rows["territoires"][3])

    def test_only_modules_are_commercial(self):
        self.reject('UPDATE systeme."T_ModuleApplication" SET "Commercialisable"=true WHERE "CodeModule"=%s', ["produits"])
        self.reject('UPDATE systeme."T_ModuleApplication" SET "TypeApplication"=%s WHERE "CodeModule"=%s', ["OTHER", "produits"])

    def test_hierarchy_has_only_one_module_parent(self):
        self.reject('UPDATE systeme."T_ModuleApplication" SET "ModuleParentCode"=%s WHERE "CodeModule"=%s', ["produits", "sante"])
        self.reject('UPDATE systeme."T_ModuleApplication" SET "ModuleParentCode"=%s WHERE "CodeModule"=%s', ["catalogue", "catalogue"])
        self.reject('UPDATE systeme."T_ModuleApplication" SET "TypeApplication"=%s,"Commercialisable"=false WHERE "CodeModule"=%s', ["FONCTIONNALITE", "catalogue"])
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


if __name__ == "__main__":
    unittest.main(verbosity=2)
