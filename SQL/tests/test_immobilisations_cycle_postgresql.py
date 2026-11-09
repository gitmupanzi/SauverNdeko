"""Recette du cycle physique des immobilisations sur une copie PostgreSQL locale.

La migration doit déjà être appliquée. Les fixtures et assertions s’exécutent
dans une transaction annulée, même en cas de succès.
"""

import hashlib
import os
import unittest
import uuid
from datetime import timedelta
from urllib.parse import unquote, urlsplit

import psycopg
from psycopg.rows import dict_row


class ImmobilisationCycleSQL(unittest.TestCase):
    def setUp(self):
        dsn = os.environ.get("SAUVERNDEKO_TEST_DATABASE_URL", "")
        target = urlsplit(dsn)
        database = unquote(target.path.lstrip("/"))
        if target.hostname not in {"127.0.0.1", "localhost", "::1"} or not database.startswith("sauverndeko_test_"):
            self.fail("Une base PostgreSQL locale sauverndeko_test_* est obligatoire.")

        self.db = psycopg.connect(dsn, autocommit=True, row_factory=dict_row)
        self.addCleanup(self.db.close)
        self.assertEqual(self.one("SELECT current_database() AS nom")["nom"], database)
        tx = self.db.transaction(force_rollback=True)
        tx.__enter__()
        self.addCleanup(tx.__exit__, None, None, None)
        self.today = self.one("SELECT (now() AT TIME ZONE 'Africa/Kinshasa')::date AS date")["date"]
        self.entity = self.make_entity()
        self.other_entity = self.make_entity()
        self.actor = self.make_user(self.entity)
        self.other_actor = self.make_user(self.other_entity)
        self.set_actor(self.actor)
        self.category = self.one(
            '''SELECT g."ID_Generique" AS id FROM referentiel."T_Generique" g
               WHERE logistique.fn_reference_immobilisation_valide(g."ID_Generique",'categories',%s)
               ORDER BY g."ID_Generique" LIMIT 1''',
            [self.entity],
        )["id"]
        self.asset = self.make_asset(self.entity)

    def one(self, query, params=None):
        return self.db.execute(query, params).fetchone()

    def make_entity(self):
        tag = uuid.uuid4().hex
        return self.one(
            '''INSERT INTO systeme."T_Entite"("NomEntite","EmailEntite")
               VALUES (%s,%s) RETURNING "IdEntite" AS id''',
            ["Recette cycle " + tag, tag + "@example.invalid"],
        )["id"]

    def make_user(self, entity):
        return self.one(
            '''INSERT INTO systeme."T_Utilisateurs"("NomUser","PrenomUser","EmailUser","MotdepasseUser","SexeUser","IdEntiteFk")
               VALUES ('Cycle','Recette',%s,'empreinte-fictive-inutilisable','M',%s) RETURNING "IdUser" AS id''',
            [uuid.uuid4().hex + "@example.invalid", entity],
        )["id"]

    def set_actor(self, actor):
        self.one("SELECT set_config('systeme.actor_user_id',%s,true)", [str(actor) if actor else ""])

    def make_asset(self, entity, commissioned=None):
        return self.one(
            '''INSERT INTO logistique."T_Immobilisation"
               ("IdEntiteFk","NomImmobilisation","ID_CategorieFk","DateAcquisition","DateMiseEnService","SuiviIndividuel","Quantite")
               VALUES (%s,'Lot de recette',%s,%s,%s,false,3) RETURNING "ID_Immobilisation" AS id''',
            [entity, self.category, self.today - timedelta(days=5), commissioned],
        )["id"]

    def asset_data(self):
        return self.one(
            '''SELECT "Actif","StatutCycle","TypeSortie","DateSortie","Quantite","Responsable"
               FROM logistique."V_Immobilisation" WHERE "ID_Immobilisation"=%s''',
            [self.asset],
        )

    def event(self, kind, *, date=None, count=None, piece=None, request=None, entity=None):
        return self.one(
            '''INSERT INTO logistique."T_ImmobilisationEvenement"
               ("ID_ImmobilisationFk","IdEntiteFk","TypeEvenement","DateEvenement","Motif",
                "QuantiteComptee","ID_PieceFk","RequestId","PayloadHash")
               VALUES (%s,%s,%s,%s,'Motif de recette',%s,%s,%s,%s) RETURNING "ID_Evenement" AS id''',
            [self.asset, entity or self.entity, kind, date or self.today, count, piece, request or uuid.uuid4(), "a" * 64],
        )["id"]

    def document(self, asset):
        data = b"%PDF-1.4\nrecette de stockage"
        return self.one(
            '''INSERT INTO logistique."T_PieceJustificative"
               ("TypeObjet","ID_Objet","IdEntiteFk","ID_UserFk","NomFichier","MimeType","TailleOctets","Sha256","Contenu")
               VALUES ('immobilisation',%s,%s,%s,'preuve.pdf','application/pdf',%s,%s,%s) RETURNING "ID_Piece" AS id''',
            [asset, self.entity, self.actor, len(data), hashlib.sha256(data).hexdigest(), data],
        )["id"]

    def reject(self, error, operation):
        with self.assertRaises(error):
            with self.db.transaction():
                operation()

    def test_mise_en_service_et_transfert_trace(self):
        self.assertEqual(self.asset_data()["StatutCycle"], "A_METTRE_EN_SERVICE")
        self.assertIsNone(self.asset_data()["Responsable"])
        self.reject(psycopg.errors.CheckViolation, lambda: self.make_asset(self.entity, self.today - timedelta(days=6)))
        location = self.one(
            '''INSERT INTO systeme."T_Entite_Localisation"("IdEntiteFk","AdresseDetaillee")
               VALUES (%s,'Bureau de recette') RETURNING "IdEntiteLocalisation" AS id''',
            [self.entity],
        )["id"]
        self.db.execute(
            '''UPDATE logistique."T_Immobilisation" SET "DateMiseEnService"=%s,"ID_LocalisationFk"=%s,"ID_ResponsableFk"=%s
               WHERE "ID_Immobilisation"=%s''',
            [self.today, location, self.actor, self.asset],
        )
        self.assertEqual(self.asset_data()["StatutCycle"], "EN_SERVICE")
        images = self.one(
            '''SELECT "OldData","NewData" FROM systeme."T_Audit_Log"
               WHERE "TableName"='logistique.T_Immobilisation' AND "Operation"='UPDATE'
                AND "NewData"->>'ID_Immobilisation'=%s ORDER BY "IdLog" DESC LIMIT 1''',
            [str(self.asset)],
        )
        self.assertIsNone(images["OldData"]["ID_LocalisationFk"])
        self.assertEqual(images["NewData"]["ID_LocalisationFk"], location)
        self.assertEqual(images["NewData"]["ID_ResponsableFk"], self.actor)

    def test_comptage_fige_et_justificatif(self):
        other_asset = self.make_asset(self.entity)
        self.reject(psycopg.errors.ForeignKeyViolation, lambda: self.event("INVENTAIRE", count=2, piece=self.document(other_asset)))
        piece = self.document(self.asset)
        inventory = self.event("INVENTAIRE", count=2, piece=piece)
        self.db.execute('UPDATE logistique."T_Immobilisation" SET "Quantite"=4 WHERE "ID_Immobilisation"=%s', [self.asset])
        data = self.one(
            '''SELECT "QuantiteComptee","QuantiteTheorique","EcartInventaire","ID_UserFk","Auteur","NomFichier"
               FROM logistique."V_ImmobilisationEvenement" WHERE "ID_Evenement"=%s''',
            [inventory],
        )
        self.assertEqual((data["QuantiteComptee"], data["QuantiteTheorique"], data["EcartInventaire"]), (2, 3, -1))
        self.assertEqual((data["ID_UserFk"], data["Auteur"], data["NomFichier"]), (self.actor, "Recette Cycle", "preuve.pdf"))
        self.reject(psycopg.errors.CheckViolation, lambda: self.event("INVENTAIRE", count=-1))
        self.reject(psycopg.errors.CheckViolation, lambda: self.event("INVENTAIRE", count="0.5"))
        self.reject(psycopg.errors.CheckViolation, lambda: self.event("INVENTAIRE"))
        self.reject(psycopg.errors.CheckViolation, lambda: self.event("ENTRETIEN", count=1))
        self.event("INVENTAIRE", count=0)
        self.reject(
            psycopg.errors.CheckViolation,
            lambda: self.db.execute('UPDATE logistique."T_PieceJustificative" SET "Archive"=true WHERE "ID_Piece"=%s', [piece]),
        )

    def test_sortie_fige_fiche_et_evenements(self):
        upkeep = self.event("ENTRETIEN")
        self.reject(psycopg.errors.CheckViolation, lambda: self.event("CESSION", date=self.today - timedelta(days=1)))
        self.reject(psycopg.errors.CheckViolation, lambda: self.event("REBUT", date=self.today + timedelta(days=1)))
        self.event("CESSION")
        state = self.asset_data()
        self.assertEqual((state["StatutCycle"], state["TypeSortie"], state["DateSortie"], state["Quantite"]), ("SORTI", "CESSION", self.today, 3))
        for kind in ("CESSION", "REBUT", "ENTRETIEN"):
            self.reject(psycopg.errors.CheckViolation, lambda: self.event(kind))
        self.reject(
            psycopg.errors.CheckViolation,
            lambda: self.db.execute('DELETE FROM logistique."T_ImmobilisationEvenement" WHERE "ID_Evenement"=%s', [upkeep]),
        )
        self.reject(
            psycopg.errors.CheckViolation,
            lambda: self.db.execute('UPDATE logistique."T_ImmobilisationEvenement" SET "Motif"=%s WHERE "ID_Evenement"=%s', ["altéré", upkeep]),
        )
        self.reject(
            psycopg.errors.CheckViolation,
            lambda: self.db.execute('UPDATE logistique."T_Immobilisation" SET "Quantite"=2 WHERE "ID_Immobilisation"=%s', [self.asset]),
        )
        for active in (False, True):
            self.db.execute('UPDATE logistique."T_Immobilisation" SET "Actif"=%s WHERE "ID_Immobilisation"=%s', [active, self.asset])
            self.assertEqual((self.asset_data()["Actif"], self.asset_data()["StatutCycle"]), (active, "SORTI"))

    def test_perimetre_et_rejeu(self):
        self.set_actor(None)
        self.reject(psycopg.errors.InsufficientPrivilege, lambda: self.event("ENTRETIEN"))
        self.set_actor(self.other_actor)
        self.reject(psycopg.errors.InsufficientPrivilege, lambda: self.event("ENTRETIEN"))
        self.set_actor(self.actor)
        self.reject(psycopg.errors.InsufficientPrivilege, lambda: self.event("ENTRETIEN", entity=self.other_entity))
        proof = uuid.uuid4()
        self.event("ENTRETIEN", request=proof)
        self.reject(psycopg.errors.UniqueViolation, lambda: self.event("ENTRETIEN", request=proof))
        self.assertEqual(
            self.one('SELECT count(*) AS n FROM logistique."T_ImmobilisationEvenement" WHERE "RequestId"=%s', [proof])["n"], 1,
        )


if __name__ == "__main__":
    unittest.main()
