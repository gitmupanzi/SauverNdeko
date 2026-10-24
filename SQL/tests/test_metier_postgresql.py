"""Recette métier : uniquement base dédiée sauverndeko_test_*, jamais DATABASE_URL."""

import os, unittest, uuid, json, time
from decimal import Decimal
from concurrent.futures import ThreadPoolExecutor
from threading import Event
import psycopg
from psycopg import sql
from psycopg.rows import dict_row

DSN = os.environ.get("SAUVERNDEKO_TEST_DATABASE_URL")
if not DSN:
    raise RuntimeError(
        "SAUVERNDEKO_TEST_DATABASE_URL obligatoire ; aucun repli sur la base métier."
    )


def connect():
    c = psycopg.connect(
        DSN,
        autocommit=True,
        row_factory=dict_row,
        options="-c statement_timeout=10000 -c lock_timeout=5000",
    )
    n = c.execute("SELECT current_database() n").fetchone()["n"]
    if not n.startswith("sauverndeko_test_"):
        c.close()
        raise RuntimeError("Base de recette dédiée obligatoire.")
    return c


class Metier(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.c = connect()
        for category in [28, 34, 36, 37, 40, 46, 64, 100]:
            cls.c.execute(
                'INSERT INTO referentiel."T_CategorieGenerique"("ID_CategorieGenerique","NomCategorieGenerique") OVERRIDING SYSTEM VALUE VALUES(%s,%s) ON CONFLICT DO NOTHING',
                (category, "Categorie fictive " + str(category)),
            )
        for gid, cat, label, abbr in [
            (1001, 64, "Entrée", "Entree"),
            (1002, 64, "Sortie", "Sortie"),
            (1003, 28, "Ouverte", "Ouverte"),
            (1004, 100, "Statut fictif", "Test"),
            (1005, 100, "Role fictif", "User"),
            (1006, 64, "Type non géré", "Autre"),
        ]:
            cls.c.execute(
                'INSERT INTO referentiel."T_Generique"("ID_Generique","ID_CategorieGeneriqueFk","NomGenerique","AbrGenerique") OVERRIDING SYSTEM VALUE VALUES(%s,%s,%s,%s) ON CONFLICT DO NOTHING',
                (gid, cat, label, abbr),
            )
        cls.entity = cls.insert(
            "systeme",
            "T_Entite",
            {
                "NomEntite": "Entite recette",
                "EmailEntite": "recette-" + uuid.uuid4().hex + "@example.invalid",
            },
            "IdEntite",
        )
        cls.user = cls.insert(
            "systeme",
            "T_Utilisateurs",
            {
                "NomUser": "Fictif",
                "PrenomUser": "Recette",
                "EmailUser": uuid.uuid4().hex + "@example.invalid",
                "MotdepasseUser": "hachage-entierement-fictif",
                "SexeUser": "M",
                "IdEntiteFk": cls.entity,
            },
            "IdUser",
        )

    @classmethod
    def tearDownClass(cls):
        cls.c.close()

    @classmethod
    def insert(cls, s, t, data, key):
        names = list(data)
        return cls.c.execute(
            sql.SQL("INSERT INTO {}.{} ({}) VALUES ({}) RETURNING {}").format(
                sql.Identifier(s),
                sql.Identifier(t),
                sql.SQL(",").join(map(sql.Identifier, names)),
                sql.SQL(",").join(sql.Placeholder() for _ in names),
                sql.Identifier(key),
            ),
            list(data.values()),
        ).fetchone()[key]

    def article(self, stock=0):
        return self.insert(
            "logistique",
            "T_Article",
            {
                "NomArticle": "Article fictif " + uuid.uuid4().hex,
                "QteArticle": stock,
                "PUArticle": 2,
                "PVArticle": 3,
                "ID_UserFK": self.user,
            },
            "ID_Article",
        )

    def commande(self, kind=1001):
        return self.insert(
            "logistique",
            "T_Commande",
            {
                "ID_TypeCmdFk": kind,
                "ID_StatutCmdFk": 1003,
                "ID_UserFk": self.user,
                "StatusFacture": "Ouverte",
            },
            "ID_Commande",
        )

    def ligne(self, c, a, q=10, p=2):
        self.c.execute(
            'INSERT INTO logistique."T_CommandeDetail"("ID_CmdFk","ID_ArticleFk","QteCmdDetail","PUCmdDetail") VALUES(%s,%s,%s,%s)',
            (c, a, q, p),
        )

    def stock(self, a):
        return self.c.execute(
            'SELECT "QteArticle" n FROM logistique."T_Article" WHERE "ID_Article"=%s',
            (a,),
        ).fetchone()["n"]

    def audit_stock(self, a):
        self.assertEqual(
            self.c.execute(
                'SELECT "Ecart" n FROM logistique.fn_audit_stock(%s)', (a,)
            ).fetchone()["n"],
            0,
        )

    def licence(self, e, days=20, valid=True, explicit=True):
        data = {
            "IdEntiteFk": e,
            "DateFin": None,
            "IdStatutLicenceFk": 1004,
            "ValideLicence": valid,
        }
        data["DateDebut"] = self.c.execute(
            "SELECT now()+%s*interval '1 day' d", (days - 10 if days < 0 else 0,)
        ).fetchone()["d"]
        data["DateFin"] = self.c.execute(
            "SELECT now()+%s*interval '1 day' d", (days,)
        ).fetchone()["d"]
        if explicit:
            data["IdLicence"] = int(uuid.uuid4().hex[:7], 16)
        return self.insert("systeme", "T_Licence", data, "IdLicence")

    def entity_new(self):
        return self.insert(
            "systeme",
            "T_Entite",
            {
                "NomEntite": "Fictif",
                "EmailEntite": uuid.uuid4().hex + "@example.invalid",
            },
            "IdEntite",
        )

    def test_01_stock_initial(self):
        a = self.article(10)
        self.assertEqual(self.stock(a), 10)
        self.audit_stock(a)

    def test_02_entree_sortie(self):
        a = self.article()
        self.ligne(self.commande(), a, 10)
        self.ligne(self.commande(1002), a, 8)
        self.assertEqual(self.stock(a), 2)
        self.audit_stock(a)

    def test_03_augmentation_entree_deja_consommee(self):
        a = self.article()
        c = self.commande()
        self.ligne(c, a, 10)
        self.ligne(self.commande(1002), a, 8)
        self.c.execute(
            'UPDATE logistique."T_CommandeDetail" SET "QteCmdDetail"=15 WHERE "ID_CmdFk"=%s',
            (c,),
        )
        self.assertEqual(self.stock(a), 7)
        self.audit_stock(a)

    def test_04_diminution_entree_impossible(self):
        a = self.article()
        c = self.commande()
        self.ligne(c, a, 10)
        self.ligne(self.commande(1002), a, 8)
        with self.assertRaises(psycopg.Error):
            self.c.execute(
                'UPDATE logistique."T_CommandeDetail" SET "QteCmdDetail"=5 WHERE "ID_CmdFk"=%s',
                (c,),
            )
        self.assertEqual(self.stock(a), 2)
        self.audit_stock(a)

    def test_05_prix_seul(self):
        a = self.article()
        c = self.commande()
        self.ligne(c, a, 10)
        self.c.execute(
            'UPDATE logistique."T_CommandeDetail" SET "PUCmdDetail"=7 WHERE "ID_CmdFk"=%s',
            (c,),
        )
        self.assertEqual(self.stock(a), 10)
        r = self.c.execute(
            'SELECT "PUMvt" p FROM logistique."T_Mouvement" WHERE "ID_cmdFk"=%s', (c,)
        ).fetchone()
        self.assertEqual(r["p"], 7)
        self.audit_stock(a)

    def test_06_suppression_ligne(self):
        a = self.article()
        c = self.commande()
        self.ligne(c, a)
        self.c.execute(
            'DELETE FROM logistique."T_CommandeDetail" WHERE "ID_CmdFk"=%s', (c,)
        )
        self.assertEqual(self.stock(a), 0)
        self.audit_stock(a)

    def test_07_suppression_commande_cascade(self):
        a = self.article()
        c = self.commande()
        self.ligne(c, a)
        self.c.execute(
            'DELETE FROM logistique."T_Commande" WHERE "ID_Commande"=%s', (c,)
        )
        self.assertEqual(self.stock(a), 0)
        self.audit_stock(a)

    def test_08_sortie_insuffisante(self):
        a = self.article(2)
        with self.assertRaises(psycopg.Error):
            self.ligne(self.commande(1002), a, 3)
        self.assertEqual(self.stock(a), 2)
        self.audit_stock(a)

    def test_09_fraction_refusee(self):
        a = self.article()
        with self.assertRaises(psycopg.Error):
            self.ligne(self.commande(), a, Decimal("1.5"))

    def test_10_cloture(self):
        a = self.article()
        c = self.commande()
        self.ligne(c, a)
        self.c.execute(
            'UPDATE logistique."T_Commande" SET "StatusFacture"=%s WHERE "ID_Commande"=%s',
            (" CLÔTURÉE ", c),
        )
        with self.assertRaises(psycopg.Error):
            self.c.execute(
                'DELETE FROM logistique."T_CommandeDetail" WHERE "ID_CmdFk"=%s', (c,)
            )

    def test_11_mouvement_direct_refuse(self):
        a = self.article()
        with self.assertRaises(psycopg.Error):
            self.c.execute(
                'INSERT INTO logistique."T_Mouvement"("ID_ArticleFk","ID_TypeMvtFk","QteMvt") VALUES(%s,1001,1)',
                (a,),
            )

    def test_12_audit_sans_secret(self):
        r = self.c.execute(
            'SELECT "NewData" d FROM systeme."T_Audit_Log" WHERE "TableName" IN (%s,%s) AND "NewData"->>\'IdUser\'=%s ORDER BY "IdLog" DESC LIMIT 1',
            ("T_Utilisateurs", "systeme.T_Utilisateurs", str(self.user)),
        ).fetchone()
        self.assertNotIn("MotdepasseUser", r["d"])

    def test_13_licence_identifiant_automatique(self):
        self.assertGreater(self.licence(self.entity_new(), explicit=False), 0)

    def test_14_licence_inactive_autorisee(self):
        e = self.entity_new()
        self.licence(e)
        self.licence(e, valid=False)

    def test_15_licence_update_doublon_refuse(self):
        e = self.entity_new()
        x = self.licence(e, days=-1)
        self.licence(e)
        with self.assertRaises(psycopg.Error):
            self.c.execute(
                'UPDATE systeme."T_Licence" SET "DateDebut"=now(),"DateFin"=now()+interval \'40 days\' WHERE "IdLicence"=%s',
                (x,),
            )

    def test_16_toutes_vues(self):
        for r in self.c.execute(
            "SELECT schemaname,viewname FROM pg_views WHERE schemaname IN ('referentiel','systeme','geolocalisation','professionnel','analytics','communication','logistique')"
        ).fetchall():
            self.c.execute(
                sql.SQL("SELECT * FROM {}.{} LIMIT 1").format(
                    sql.Identifier(r["schemaname"]), sql.Identifier(r["viewname"])
                )
            ).fetchall()

    def test_17_reference_stock_sens_immuable(self):
        a = self.article(3)
        with self.assertRaises(psycopg.Error):
            self.c.execute(
                'UPDATE referentiel."T_Generique" SET "AbrGenerique"=\'Autre\' WHERE "ID_Generique"=1001'
            )

    def test_18_message_date_synchronisee(self):
        d = self.insert(
            "communication",
            "T_Discussion",
            {
                "IdUserClientFk": self.user,
                "IdEntiteFk": self.entity,
                "TypeDiscussion": "structure",
            },
            "IdDiscussion",
        )
        m = self.insert(
            "communication",
            "T_Chat",
            {
                "IdDiscussionFk": d,
                "AuthorIdFk": self.user,
                "TextChat": "Message fictif",
            },
            "IdChat",
        )
        r = self.c.execute(
            'SELECT "DernierMessageAt" d FROM communication."T_Discussion" WHERE "IdDiscussion"=%s',
            (d,),
        ).fetchone()
        self.assertIsNotNone(r["d"])
        self.c.execute('DELETE FROM communication."T_Chat" WHERE "IdChat"=%s', (m,))
        self.assertIsNone(
            self.c.execute(
                'SELECT "DernierMessageAt" d FROM communication."T_Discussion" WHERE "IdDiscussion"=%s',
                (d,),
            ).fetchone()["d"]
        )

    def test_19_message_vide_refuse(self):
        with self.assertRaises(psycopg.Error):
            self.insert("communication", "T_Chat", {"TextChat": "   "}, "IdChat")

    def test_20_analytics_disponible(self):
        self.assertIsNotNone(
            self.c.execute(
                "SELECT to_regclass('analytics.\"T_Recherche\"') n"
            ).fetchone()["n"]
        )

    def test_21_deplacement_meme_article_entree_consommee(self):
        a = self.article()
        old = self.commande()
        new = self.commande()
        self.ligne(old, a, 10)
        self.ligne(self.commande(1002), a, 8)
        self.c.execute(
            'UPDATE logistique."T_CommandeDetail" SET "ID_CmdFk"=%s WHERE "ID_CmdFk"=%s',
            (new, old),
        )
        self.assertEqual(self.stock(a), 2)
        self.audit_stock(a)

    def test_22_changement_article(self):
        a = self.article()
        b = self.article()
        c = self.commande()
        self.ligne(c, a, 5)
        self.c.execute(
            'UPDATE logistique."T_CommandeDetail" SET "ID_ArticleFk"=%s WHERE "ID_CmdFk"=%s',
            (b, c),
        )
        self.assertEqual(self.stock(a), 0)
        self.assertEqual(self.stock(b), 5)
        self.audit_stock(a)
        self.audit_stock(b)

    def test_23_changement_sens_commande(self):
        a = self.article(100)
        c = self.commande()
        self.ligne(c, a, 5)
        self.c.execute(
            'UPDATE logistique."T_Commande" SET "ID_TypeCmdFk"=1002 WHERE "ID_Commande"=%s',
            (c,),
        )
        self.assertEqual(self.stock(a), 95)
        self.audit_stock(a)

    def test_24_rollback(self):
        a = self.article()
        c = self.commande()
        try:
            with self.c.transaction():
                self.ligne(c, a, 5)
                raise ValueError("annulation fictive")
        except ValueError:
            pass
        self.assertEqual(self.stock(a), 0)
        self.audit_stock(a)

    def test_25_lot_et_total(self):
        c = self.commande()
        a = self.article()
        b = self.article()
        self.c.execute(
            'INSERT INTO logistique."T_CommandeDetail"("ID_CmdFk","ID_ArticleFk","QteCmdDetail","PUCmdDetail") VALUES(%s,%s,3,2),(%s,%s,4,5)',
            (c, a, c, b),
        )
        self.assertEqual(
            self.c.execute(
                'SELECT "MontantHT" m,"MontantTTC" t FROM logistique."T_Commande" WHERE "ID_Commande"=%s',
                (c,),
            ).fetchone(),
            {"m": Decimal(26), "t": Decimal(26)},
        )

    def race(self, first, second):
        ready = Event()
        release = Event()

        def one():
            with connect() as c:
                with c.transaction():
                    first(c)
                    ready.set()
                    release.wait(3)
            return "OK"

        def two():
            with connect() as c:
                try:
                    second(c)
                    return "OK"
                except psycopg.Error as e:
                    return e.sqlstate

        with ThreadPoolExecutor(2) as pool:
            f1 = pool.submit(one)
            self.assertTrue(ready.wait(3))
            f2 = pool.submit(two)
            time.sleep(0.15)
            release.set()
            return [f1.result(timeout=8), f2.result(timeout=8)]

    def test_26_sorties_concurrentes_sans_survente(self):
        a = self.article(10)
        c1 = self.commande(1002)
        c2 = self.commande(1002)
        stmt = 'INSERT INTO logistique."T_CommandeDetail"("ID_CmdFk","ID_ArticleFk","QteCmdDetail","PUCmdDetail") VALUES(%s,%s,8,2)'
        results = self.race(
            lambda c: c.execute(stmt, (c1, a)), lambda c: c.execute(stmt, (c2, a))
        )
        self.assertEqual(results.count("OK"), 1)
        self.assertIn(results[1], ["23514", "P0001"])
        self.assertEqual(self.stock(a), 2)
        self.audit_stock(a)

    def test_27_total_commande_concurrent(self):
        a = self.article()
        b = self.article()
        cmd = self.commande()
        stmt = 'INSERT INTO logistique."T_CommandeDetail"("ID_CmdFk","ID_ArticleFk","QteCmdDetail","PUCmdDetail") VALUES(%s,%s,5,2)'
        self.assertEqual(
            self.race(
                lambda c: c.execute(stmt, (cmd, a)), lambda c: c.execute(stmt, (cmd, b))
            ),
            ["OK", "OK"],
        )
        self.assertEqual(
            self.c.execute(
                'SELECT "MontantTTC" m FROM logistique."T_Commande" WHERE "ID_Commande"=%s',
                (cmd,),
            ).fetchone()["m"],
            20,
        )

    def test_28_licences_concurrentes(self):
        entity = self.entity_new()
        stmt = 'INSERT INTO systeme."T_Licence"("IdEntiteFk","DateFin","IdStatutLicenceFk") VALUES(%s,now()+interval \'20 days\',1004)'
        results = self.race(
            lambda c: c.execute(stmt, (entity,)), lambda c: c.execute(stmt, (entity,))
        )
        self.assertEqual(results, ["OK", "23514"])

    def test_29_messages_concurrents(self):
        d = self.insert(
            "communication",
            "T_Discussion",
            {
                "IdUserClientFk": self.user,
                "IdEntiteFk": self.entity_new(),
                "TypeDiscussion": "structure",
            },
            "IdDiscussion",
        )
        stmt = 'INSERT INTO communication."T_Chat"("IdDiscussionFk","AuthorIdFk","TextChat") VALUES(%s,%s,\'Message fictif\')'
        self.assertEqual(
            self.race(
                lambda c: c.execute(stmt, (d, self.user)),
                lambda c: c.execute(stmt, (d, self.user)),
            ),
            ["OK", "OK"],
        )
        row = self.c.execute(
            'SELECT d."DernierMessageAt" d,max(c."DateChat") m FROM communication."T_Discussion" d JOIN communication."T_Chat" c ON c."IdDiscussionFk"=d."IdDiscussion" WHERE d."IdDiscussion"=%s GROUP BY d."IdDiscussion"',
            (d,),
        ).fetchone()
        self.assertEqual(row["d"], row["m"])

    def test_30_analytics_agregat(self):
        a = self.article()
        self.c.execute(
            'INSERT INTO analytics."T_Recherche"("TexteRecherche","ID_ArticleResultFk") VALUES(\'essai fictif\',%s),(\'autre essai fictif\',%s)',
            (a, a),
        )
        self.assertEqual(
            self.c.execute(
                'SELECT nbrerecherches n FROM analytics."V_Recherche" WHERE "ID_Article"=%s',
                (a,),
            ).fetchone()["n"],
            2,
        )

    def test_31_prix_negatif_refuse(self):
        with self.assertRaises(psycopg.Error):
            self.article(-1)
        with self.assertRaises(psycopg.Error):
            self.insert(
                "logistique",
                "T_Article",
                {
                    "NomArticle": "Article fictif négatif",
                    "PUArticle": -2,
                    "PVArticle": 3,
                },
                "ID_Article",
            )

    def test_32_type_commande_inconnu_refuse(self):
        with self.assertRaises(psycopg.Error):
            self.commande(1006)

    def test_33_sites_directs_inclus(self):
        n = self.insert(
            "geolocalisation",
            "T_Niveau_3",
            {"NomNiveau_3": "Zone fictive"},
            "ID_Niveau_3",
        )
        self.insert(
            "geolocalisation",
            "T_Niveau_5",
            {
                "ID_Niveau_3_Fk": n,
                "NomNiveau_5": "Site direct fictif",
                "PopulationNiveau_5": 123,
            },
            "ID_Niveau_5",
        )
        self.assertEqual(
            self.c.execute(
                'SELECT sum("Nb_Structures_Sante") n FROM geolocalisation."V_Stats_N3_Structures" WHERE "ID_Niveau_3"=%s',
                (n,),
            ).fetchone()["n"],
            1,
        )
        self.assertEqual(
            self.c.execute(
                'SELECT sum("Pop_Cum_Sites") n FROM geolocalisation."V_Pop_N3_Couverte_Sites" WHERE "ID_Niveau_3"=%s',
                (n,),
            ).fetchone()["n"],
            123,
        )

    def test_34_sites_directs_et_via_aire_sans_doublon(self):
        n = self.insert(
            "geolocalisation",
            "T_Niveau_3",
            {"NomNiveau_3": "Zone mixte fictive"},
            "ID_Niveau_3",
        )
        a = self.insert(
            "geolocalisation",
            "T_Niveau_4",
            {"ID_Niveau_3_Fk": n, "NomNiveau_4": "Aire fictive"},
            "ID_Niveau_4",
        )
        self.insert(
            "geolocalisation",
            "T_Niveau_5",
            {
                "ID_Niveau_4_Fk": a,
                "NomNiveau_5": "Site indirect",
                "PopulationNiveau_5": 10,
            },
            "ID_Niveau_5",
        )
        self.insert(
            "geolocalisation",
            "T_Niveau_5",
            {
                "ID_Niveau_3_Fk": n,
                "NomNiveau_5": "Site direct",
                "PopulationNiveau_5": 20,
            },
            "ID_Niveau_5",
        )
        self.assertEqual(
            self.c.execute(
                'SELECT sum("Nb_Structures_Sante") n FROM geolocalisation."V_Stats_N3_Structures" WHERE "ID_Niveau_3"=%s',
                (n,),
            ).fetchone()["n"],
            2,
        )
        self.assertEqual(
            self.c.execute(
                'SELECT sum("Pop_Cum_Sites") n FROM geolocalisation."V_Pop_N3_Couverte_Sites" WHERE "ID_Niveau_3"=%s',
                (n,),
            ).fetchone()["n"],
            30,
        )

    def test_35_vue_audit_historique_masque_secrets(self):
        self.c.execute(
            'INSERT INTO systeme."T_Audit_Log"("TableName","Operation","NewData") VALUES(\'Fixture\',\'INSERT\',\'{"MotdepasseUser":"valeur-fictive","NomUser":"Fictif"}\')'
        )
        r = self.c.execute(
            'SELECT "NewData" d FROM systeme."V_Audit_log" WHERE "TableName"=\'Fixture\' ORDER BY "IdLog" DESC LIMIT 1'
        ).fetchone()["d"]
        self.assertNotIn("MotdepasseUser", r)
        self.assertEqual(r["NomUser"], "Fictif")

    def test_36_pro_public_filtre_liens_perimes(self):
        u = self.insert(
            "systeme",
            "T_Utilisateurs",
            {
                "NomUser": "Expert fictif",
                "PrenomUser": "Test",
                "EmailUser": uuid.uuid4().hex + "@example.invalid",
                "MotdepasseUser": "hachage-fictif",
                "SexeUser": "F",
            },
            "IdUser",
        )
        p = self.insert(
            "professionnel",
            "T_Professionnel",
            {"IdUserFk": u, "IdTypeProfessionnelFk": 1004, "IdSpecialiteFk": 1004},
            "IdProfessionnel",
        )
        e = self.entity_new()
        self.c.execute(
            'INSERT INTO professionnel."T_Professionnel_Entite"("IdProfessionnelFk","IdEntiteFk","DateFin") VALUES(%s,%s,now()-interval \'1 day\')',
            (p, e),
        )
        row = self.c.execute(
            'SELECT * FROM professionnel."V_Professionnel_Public" WHERE "IdProfessionnel"=%s',
            (p,),
        ).fetchone()
        self.assertEqual(row["T_Professionnel_Entite"], [])
        self.assertNotIn("EmailUser", row["T_Utilisateurs"])
        self.c.execute(
            'UPDATE systeme."T_Utilisateurs" SET "ValideUser"=false WHERE "IdUser"=%s',
            (u,),
        )
        self.assertIsNone(
            self.c.execute(
                'SELECT * FROM professionnel."V_Professionnel_Public" WHERE "IdProfessionnel"=%s',
                (p,),
            ).fetchone()
        )


if __name__ == "__main__":
    unittest.main(verbosity=2)
