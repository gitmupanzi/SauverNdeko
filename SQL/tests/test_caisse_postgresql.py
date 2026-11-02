"""Recette du journal Caisse sur une base privée migrée, jamais sur SauverNdeko.

SAUVERNDEKO_TEST_DATABASE_URL doit viser sauverndeko_test_*.
Les fixtures sont fictives et restent dans cette seule base de recette.
"""
import concurrent.futures
from datetime import datetime, timedelta, timezone
from decimal import Decimal
import hashlib
import json
import os
import threading
import unittest
from urllib.parse import urlsplit
import uuid

import psycopg
from psycopg import sql
from psycopg.rows import dict_row

DSN = os.environ.get("SAUVERNDEKO_TEST_DATABASE_URL", "")
if not urlsplit(DSN).path.lstrip("/").startswith("sauverndeko_test_"):
    raise RuntimeError("Base privée sauverndeko_test_* obligatoire, aucun repli source.")


class CaisseSQL(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.c = psycopg.connect(DSN, autocommit=True, row_factory=dict_row)
        assert cls.c.execute("SELECT current_database() d").fetchone()["d"].startswith("sauverndeko_test_")
        cls.tag = uuid.uuid4().hex
        cls.entity = cls.insert("systeme", "T_Entite", {"NomEntite": "Caisse A " + cls.tag, "EmailEntite": "a-" + cls.tag + "@example.invalid", "ValideEntite": True}, "IdEntite")
        cls.other = cls.insert("systeme", "T_Entite", {"NomEntite": "Caisse B " + cls.tag, "EmailEntite": "b-" + cls.tag + "@example.invalid", "ValideEntite": True}, "IdEntite")
        cls.actor = cls.user(cls.entity, "A")
        cls.actor_other = cls.user(cls.other, "B")
        cls.root = cls.user(None, "Global", True)
        cls.usd = cls.c.execute('SELECT "ID_Generique" id FROM referentiel."T_Generique" WHERE "AbrGenerique"=%s AND "IdEntiteFk" IS NULL', ["USD"]).fetchone()["id"]
        cls.cdf = cls.c.execute('SELECT "ID_Generique" id FROM referentiel."T_Generique" WHERE "AbrGenerique"=%s AND "IdEntiteFk" IS NULL', ["CDF"]).fetchone()["id"]
        cls.motif = cls.c.execute('SELECT "ID_Generique" id FROM referentiel."T_Generique" WHERE "AbrGenerique"=%s AND "IdEntiteFk" IS NULL', ["CAISSE_RECETTE"]).fetchone()["id"]

    @classmethod
    def tearDownClass(cls):
        cls.c.close()

    @classmethod
    def insert(cls, schema, table, values, key):
        names = list(values)
        query = sql.SQL("INSERT INTO {}.{} ({}) VALUES ({}) RETURNING {} AS id").format(
            sql.Identifier(schema), sql.Identifier(table),
            sql.SQL(",").join(map(sql.Identifier, names)),
            sql.SQL(",").join(sql.Placeholder() for _ in names), sql.Identifier(key))
        return cls.c.execute(query, [values[k] for k in names]).fetchone()["id"]

    @classmethod
    def user(cls, entity, suffix, admin=False):
        return cls.insert("systeme", "T_Utilisateurs", {
            "NomUser": "Recette", "PrenomUser": suffix, "EmailUser": uuid.uuid4().hex + "@example.invalid",
            "MotdepasseUser": "inutilisable", "SexeUser": "M", "ValideUser": True,
            "IdEntiteFk": entity, "Is_Admin": admin}, "IdUser")

    def cash(self, entity=None, currency=None, **extra):
        return self.insert("operations", "T_Caisse", {
            "NomCaisse": "Recette " + uuid.uuid4().hex,
            "IdEntiteFk": entity or self.entity, "IdDeviseFk": currency or self.usd, **extra}, "IdCaisse")

    def draft(self, cash, amount="10.00", direction=1, actor=None, **extra):
        row = self.c.execute('SELECT * FROM operations."T_Caisse" WHERE "IdCaisse"=%s', [cash]).fetchone()
        return self.insert("operations", "T_Paiement", {
            "IdCaisseFk": cash, "IdEntiteFk": row["IdEntiteFk"], "IdDeviseFk": row["IdDeviseFk"],
            "IdUserFk": actor or self.actor, "MontantPaiement": amount, "SensMouvement": direction,
            "LibellePaiement": "Mouvement fictif", "DatePaiement": datetime.now(timezone.utc) - timedelta(seconds=2),
            "IdTypePaiementFk": self.motif, **extra}, "IdPaiement")

    @staticmethod
    def request():
        return str(uuid.uuid4()), hashlib.sha256(uuid.uuid4().bytes).hexdigest()

    def version(self, table, key, pk):
        return self.c.execute(sql.SQL('SELECT "Revision" v FROM operations.{} WHERE {}=%s').format(sql.Identifier(table), sql.Identifier(key)), [pk]).fetchone()["v"]

    def post(self, pid, actor=None, request=None, version=None):
        req, digest = request or self.request()
        version = version if version is not None else self.version("T_Paiement", "IdPaiement", pid)
        return self.c.execute("SELECT operations.fn_caisse_valider(%s,%s,%s,%s,%s,%s) id", [pid, actor or self.actor, "Justification fictive", req, digest, version]).fetchone()["id"]

    def balance(self, cash):
        return self.c.execute('SELECT "MontantCaisse" b FROM operations."T_Caisse" WHERE "IdCaisse"=%s', [cash]).fetchone()["b"]

    def reject(self, fn, code=None):
        with self.assertRaises(psycopg.Error) as found:
            with self.c.transaction():
                fn()
        if code:
            self.assertEqual(found.exception.sqlstate, code)

    def compensate(self, pid, request=None, motif="Correction fictive", version=None):
        req, digest = request or self.request()
        version = version if version is not None else self.version("T_Paiement", "IdPaiement", pid)
        return self.c.execute("SELECT operations.fn_caisse_contrepasser(%s,%s,%s,%s,%s,%s) id",
                              [pid, self.actor, motif, req, digest, version]).fetchone()["id"]

    def close(self, cash, amount, motif="", date=None, request=None, version=None):
        req, digest = request or self.request()
        version = version if version is not None else self.version("T_Caisse", "IdCaisse", cash)
        return self.c.execute("SELECT operations.fn_caisse_cloturer(%s,%s,%s,%s,%s,%s,%s,%s) id",
                              [cash, self.actor, date or datetime.now(timezone.utc), amount, motif, req, digest, version]).fetchone()["id"]

    def test_01_cash_and_owner_currency_guards(self):
        cash = self.cash()
        self.assertEqual(self.balance(cash), Decimal("0"))
        code = self.c.execute('SELECT "CodeCaisse" c FROM operations."T_Caisse" WHERE "IdCaisse"=%s', [cash]).fetchone()["c"]
        self.assertEqual(code, "CAI-" + str(cash))
        self.assertNotEqual(self.cash(), cash)  # several boxes, same company/currency
        self.reject(lambda: self.cash(MontantCaisse="100"), "23514")
        self.reject(lambda: self.c.execute('UPDATE operations."T_Caisse" SET "IdDeviseFk"=%s WHERE "IdCaisse"=%s', [self.cdf, cash]), "23514")
        self.reject(lambda: self.c.execute('UPDATE operations."T_Caisse" SET "IdEntiteFk"=%s WHERE "IdCaisse"=%s', [self.other, cash]), "23514")
        self.reject(lambda: self.c.execute('DELETE FROM operations."T_Caisse" WHERE "IdCaisse"=%s', [cash]), "23514")
        self.reject(lambda: self.c.execute('UPDATE operations."T_Caisse" SET "MontantCaisse"=10 WHERE "IdCaisse"=%s', [cash]), "23514")
        self.assertEqual(self.balance(cash), 0)

    def test_02_monetary_workflow_and_immutable_journal(self):
        cash = self.cash()
        pid = self.draft(cash, "100.15")
        self.assertEqual(self.balance(cash), 0)
        self.post(pid)
        self.assertEqual(self.balance(cash), Decimal("100.15"))
        out = self.draft(cash, "30.05", -1)
        self.post(out)
        self.assertEqual(self.balance(cash), Decimal("70.10"))
        for expr in ('"MontantPaiement"=1', '"ValidePaiement"=false', '"EtatEcriture"=\'DRAFT\''):
            self.reject(lambda expr=expr: self.c.execute('UPDATE operations."T_Paiement" SET ' + expr + ' WHERE "IdPaiement"=%s', [out]), "23514")
        self.reject(lambda: self.c.execute('DELETE FROM operations."T_Paiement" WHERE "IdPaiement"=%s', [out]), "23514")
        excessive = self.draft(cash, "70.11", -1)
        self.reject(lambda: self.post(excessive), "23514")
        self.assertEqual(self.balance(cash), Decimal("70.10"))
        self.c.execute('UPDATE operations."T_Paiement" SET "ValidePaiement"=false WHERE "IdPaiement"=%s', [excessive])
        self.reject(lambda: self.post(excessive), "23514")
        self.assertEqual(self.c.execute('SELECT "EcartsRapprochement" e FROM operations."V_Caisse" WHERE "IdCaisse"=%s', [cash]).fetchone()["e"], 0)

    def test_03_exact_amounts_dates_and_actor(self):
        cash = self.cash()
        for amount in ("0", "-1", "0.001", "1.999", "10000000000000000", "NaN", "Infinity"):
            self.reject(lambda amount=amount: self.draft(cash, amount))
        self.reject(lambda: self.draft(cash, actor=self.actor_other), "23514")
        self.reject(lambda: self.draft(cash, DatePaiement=datetime.now(timezone.utc) + timedelta(days=1)), "23514")
        self.reject(lambda: self.draft(cash, DatePaiement="-infinity"), "23514")
        pid = self.draft(cash, actor=self.root)
        self.post(pid, actor=self.root)
        self.assertEqual(self.balance(cash), 10)
        othercash = self.cash(entity=self.other, currency=self.cdf)
        self.reject(lambda: self.draft(othercash), "23514")
        otherpid = self.draft(othercash, actor=self.actor_other)
        self.post(otherpid, actor=self.actor_other)
        self.assertEqual(self.balance(othercash), 10)
        self.assertEqual(self.balance(cash), 10)

    def test_04_replay_revision_compensation(self):
        cash = self.cash()
        pid = self.draft(cash, "50")
        version = self.version("T_Paiement", "IdPaiement", pid)
        self.reject(lambda: self.post(pid, version=version + 1), "40001")
        req = self.request()
        self.post(pid, request=req, version=version)
        self.assertEqual(self.post(pid, request=req, version=version), pid)
        self.assertEqual(self.balance(cash), 50)
        self.reject(lambda: self.post(pid), "23514")
        self.reject(lambda: self.compensate(pid, motif=" "), "23514")
        compreq = self.request()
        comp = self.compensate(pid, request=compreq)
        self.assertEqual(self.compensate(pid, request=compreq), comp)
        self.assertEqual(self.balance(cash), 0)
        self.reject(lambda: self.compensate(pid), "23514")
        self.reject(lambda: self.compensate(comp), "23514")
        self.assertEqual(self.c.execute('SELECT count(*) n FROM operations."T_Paiement" WHERE "IdCaisseFk"=%s', [cash]).fetchone()["n"], 2)

    def test_05_closing_is_snapshot_not_money_adjustment(self):
        cash = self.cash()
        pid = self.draft(cash, "100")
        self.post(pid)
        pending = self.draft(cash, "1")
        self.reject(lambda: self.close(cash, "100"), "23514")
        self.c.execute('UPDATE operations."T_Paiement" SET "ValidePaiement"=false WHERE "IdPaiement"=%s', [pending])
        self.reject(lambda: self.close(cash, "99"), "23514")
        self.reject(lambda: self.close(cash, "100.001"))
        req = self.request()
        date = datetime.now(timezone.utc)
        version = self.version("T_Caisse", "IdCaisse", cash)
        cid = self.close(cash, "99", "Écart constaté", date, req, version)
        self.assertEqual(self.close(cash, "99", "Écart constaté", date, req, version), cid)
        self.assertEqual(self.balance(cash), 100)
        cl = self.c.execute('SELECT * FROM operations."T_ClotureCaisse" WHERE "ID_ClotureCaisse"=%s', [cid]).fetchone()
        self.assertEqual(cl["Ecart"], -1)
        self.reject(lambda: self.c.execute('UPDATE operations."T_ClotureCaisse" SET "MontantCompte"=100 WHERE "ID_ClotureCaisse"=%s', [cid]), "23514")
        self.reject(lambda: self.c.execute('DELETE FROM operations."T_ClotureCaisse" WHERE "ID_ClotureCaisse"=%s', [cid]), "23514")
        late = self.draft(cash, DatePaiement=date)
        self.reject(lambda: self.post(late), "23514")
        self.c.execute('UPDATE operations."T_Paiement" SET "ValidePaiement"=false WHERE "IdPaiement"=%s', [late])
        later = self.draft(cash, DatePaiement=datetime.now(timezone.utc))
        self.post(later)
        self.assertEqual(self.balance(cash), 110)
        self.reject(lambda: self.close(cash, "110", date=date), "23514")

    def test_06_archive_and_rollback_are_safe(self):
        cash = self.cash()
        pid = self.draft(cash)
        self.reject(lambda: self.c.execute('UPDATE operations."T_Caisse" SET "Actif"=false WHERE "IdCaisse"=%s', [cash]), "23514")
        self.c.execute('UPDATE operations."T_Paiement" SET "ValidePaiement"=false WHERE "IdPaiement"=%s', [pid])
        self.c.execute('UPDATE operations."T_Caisse" SET "Actif"=false WHERE "IdCaisse"=%s', [cash])
        self.reject(lambda: self.draft(cash), "23514")
        another = self.cash()
        with self.assertRaises(RuntimeError):
            with self.c.transaction():
                draft = self.draft(another, "40")
                self.post(draft)
                self.assertEqual(self.balance(another), 40)
                raise RuntimeError("transaction métier annulée")
        self.assertEqual(self.balance(another), 0)
        self.assertEqual(self.c.execute('SELECT count(*) n FROM operations."T_Paiement" WHERE "IdCaisseFk"=%s', [another]).fetchone()["n"], 0)

    def test_07_concurrent_outflows_cannot_overdraw(self):
        cash = self.cash()
        self.post(self.draft(cash, "100"))
        pids = [self.draft(cash, "80", -1) for _ in range(2)]
        barrier = threading.Barrier(2)

        def worker(pid):
            conn = psycopg.connect(DSN, autocommit=True)
            try:
                req, digest = self.request()
                barrier.wait(timeout=10)
                with conn.transaction():
                    conn.execute("SET LOCAL lock_timeout='10s'")
                    conn.execute("SELECT operations.fn_caisse_valider(%s,%s,%s,%s,%s,1)", [pid, self.actor, "Concurrence fictive", req, digest])
                return "POSTED"
            except psycopg.Error as exc:
                return exc.sqlstate
            finally:
                conn.close()

        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
            results = list(pool.map(worker, pids))
        self.assertCountEqual(results, ["POSTED", "23514"])
        self.assertEqual(self.balance(cash), 20)
        self.assertEqual(self.c.execute('SELECT "EcartsRapprochement" e FROM operations."V_Caisse" WHERE "IdCaisse"=%s', [cash]).fetchone()["e"], 0)

    def test_08_audit_replay_metadata_and_views(self):
        cash = self.cash()
        req, digest = self.request()
        with self.c.transaction():
            self.c.execute("SELECT set_config('systeme.actor_user_id',%s,true),set_config('operations.request_id',%s,true),set_config('operations.payload_hash',%s,true)", [str(self.actor), req, digest])
            self.c.execute('UPDATE operations."T_Caisse" SET "NomCaisse"=%s WHERE "IdCaisse"=%s', ["Nom corrigé " + self.tag, cash])
        audit = self.c.execute('SELECT "NewData" data FROM systeme."T_Audit_Log" WHERE "TableName"=%s AND "NewData"->>%s=%s', ["operations.T_Caisse", "_requestId", req]).fetchall()
        self.assertEqual(len(audit), 1)
        self.assertEqual(audit[0]["data"]["_payloadHash"], digest)
        self.assertEqual(audit[0]["data"]["_actor"]["IdUser"], self.actor)
        self.post(self.draft(cash, "20"))
        self.post(self.draft(cash, "5", -1))
        journal = self.c.execute('SELECT "SoldeApres" b FROM operations."V_JournalCaisse" WHERE "IdCaisseFk"=%s AND "EtatEcriture"=%s ORDER BY "ValideLe","IdPaiement"', [cash, "POSTED"]).fetchall()
        self.assertEqual([r["b"] for r in journal], [20, 15])
        flow = self.c.execute('SELECT * FROM operations."V_FluxCaisseJournalier" WHERE "IdCaisseFk"=%s', [cash]).fetchone()
        self.assertEqual((flow["MontantEntree"], flow["MontantSortie"], flow["NetJour"]), (20, 5, 15))
        self.assertTrue(self.c.execute("SELECT * FROM operations.fn_audit_caisse(%s,%s,NULL)", [self.entity, self.usd]).fetchall())
        self.assertFalse(self.c.execute('SELECT "EstSocle" FROM systeme."T_ModuleApplication" WHERE "CodeModule"=%s', ["caisse"]).fetchone()["EstSocle"])

    def test_09_reference_mapping_and_inactive_responsible(self):
        cash = self.cash(IdResponsableFk=self.actor)
        another_actor = self.user(self.entity, "Autre")
        self.c.execute('UPDATE systeme."T_Utilisateurs" SET "ValideUser"=false WHERE "IdUser"=%s', [another_actor])
        self.reject(lambda: self.c.execute('UPDATE operations."T_Caisse" SET "IdResponsableFk"=%s WHERE "IdCaisse"=%s', [another_actor, cash]), "23514")
        self.c.execute('UPDATE systeme."T_Utilisateurs" SET "ValideUser"=false WHERE "IdUser"=%s', [self.actor])
        try:
            self.post(self.draft(cash, actor=self.root), actor=self.root)
            self.assertEqual(self.balance(cash), 10)  # historical responsibility never freezes the ledger
        finally:
            self.c.execute('UPDATE systeme."T_Utilisateurs" SET "ValideUser"=true WHERE "IdUser"=%s', [self.actor])
        self.reject(lambda: self.c.execute('UPDATE operations."T_Caisse" SET "Actif"=false WHERE "IdCaisse"=%s', [cash]), "23514")
        self.reject(lambda: self.draft(cash, IdTypePaiementFk=self.usd), "23514")
        family = self.insert("referentiel", "T_CategorieGenerique", {"NomCategorieGenerique": "Motifs Caisse " + self.tag, "ValideCategorieGenerique": True}, "ID_CategorieGenerique")
        kind = self.insert("referentiel", "T_Generique", {"ID_CategorieGeneriqueFk": family, "NomGenerique": "Motif alternatif", "AbrGenerique": "TEST_" + self.tag, "ValideGenerique": True}, "ID_Generique")
        field = self.c.execute('SELECT * FROM referentiel."T_ChampReferentiel" WHERE "SchemaName"=%s AND "TableName"=%s AND "ColumnName"=%s', ["operations", "T_Paiement", "IdTypePaiementFk"]).fetchone()
        # A deliberately rolled-back mapping exercises the central source of choices.
        try:
            with self.c.transaction():
                self.c.execute('DELETE FROM systeme."T_Fk_Correspondance" WHERE "IdChampReferentielFk"=%s', [field["ID_ChampReferentiel"]])
                self.insert("systeme", "T_Fk_Correspondance", {
                    "ModuleName": field["ModuleName"], "SchemaName": "operations", "ViewName": None,
                    "SourceKey": "champ." + str(field["ID_ChampReferentiel"]), "FieldName": "IdTypePaiementFk",
                    "FieldLabel": "Motif", "MappingType": "generic_category", "ReferenceSchemaName": "referentiel",
                    "ReferenceObjectName": "T_Generique", "ReferenceFieldName": "ID_Generique", "TargetCategoryIdFk": family,
                    "MappingValue": str(family), "IsDefaultMapping": False, "ValideFkCorrespondance": True,
                    "SettingScope": "global", "ScopeValue": None, "DisplayOrder": 0,
                    "IdChampReferentielFk": field["ID_ChampReferentiel"]}, "IdFkCorrespondance")
                chosen = self.draft(cash, IdTypePaiementFk=kind)
                self.assertTrue(chosen)
                self.reject(lambda: self.draft(cash), "23514")
                raise RuntimeError("restore mapping")
        except RuntimeError:
            pass
        self.assertTrue(self.draft(cash))


if __name__ == "__main__":
    unittest.main(verbosity=2)
