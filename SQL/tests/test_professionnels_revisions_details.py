"""Révisions parent/détails, uniquement sur PostgreSQL privé migré jusqu'à07."""
import unittest
import uuid
from psycopg import sql
import test_professionnels_postgresql as base


class RevisionsDetailsSQL(base.ProfessionnelsSQL):
    def revision(self, pk):
        return self.c.execute('SELECT "Revision" FROM professionnel."T_Professionnel" WHERE "IdProfessionnel"=%s', [pk]).fetchone()["Revision"]

    def alternative(self, current):
        return self.c.execute('''SELECT "ID_Generique" id FROM referentiel."T_Generique" WHERE "ValideGenerique"
            AND "IdEntiteFk" IS NULL AND "ID_Generique"<>%s AND "ID_CategorieGeneriqueFk"=(
            SELECT "ID_CategorieGeneriqueFk" FROM referentiel."T_Generique" WHERE "ID_Generique"=%s)
            ORDER BY "ID_Generique" LIMIT 1''', [current, current]).fetchone()["id"]

    def selection_cycle(self, table, column, value):
        p = self.profile()
        self.assertEqual(self.revision(p), 1)
        self.insert("professionnel", table, {"IdProfessionnelFk": p, column: value})
        self.assertEqual(self.revision(p), 2)
        other = self.alternative(value)
        self.c.execute(sql.SQL('UPDATE professionnel.{} SET {}=%s WHERE "IdProfessionnelFk"=%s AND {}=%s').format(
            sql.Identifier(table), sql.Identifier(column), sql.Identifier(column)), [other, p, value])
        self.assertEqual(self.revision(p), 3)
        self.c.execute(sql.SQL('UPDATE professionnel.{} SET {}={} WHERE "IdProfessionnelFk"=%s').format(
            sql.Identifier(table), sql.Identifier(column), sql.Identifier(column)), [p])
        self.assertEqual(self.revision(p), 3)
        self.c.execute(sql.SQL('DELETE FROM professionnel.{} WHERE "IdProfessionnelFk"=%s').format(sql.Identifier(table)), [p])
        self.assertEqual(self.revision(p), 4)

    def test_detail_01_competence_insert_update_delete_noop(self):
        self.selection_cycle("T_Professionnel_Competence", "IdCompetenceFk", self.skill)

    def test_detail_02_prestation_insert_update_delete_noop(self):
        self.selection_cycle("T_Professionnel_Prestation", "IdPrestationFk", self.service)

    def test_detail_03_affiliation_insert_update_delete_noop(self):
        p = self.profile()
        self.insert("professionnel", "T_Professionnel_Entite", {"IdProfessionnelFk": p, "IdEntiteFk": self.other})
        self.assertEqual(self.revision(p), 2)
        self.c.execute('UPDATE professionnel."T_Professionnel_Entite" SET "ObsLien"=%s WHERE "IdProfessionnelFk"=%s', ["Changement SQL direct fictif", p])
        self.assertEqual(self.revision(p), 3)
        self.c.execute('UPDATE professionnel."T_Professionnel_Entite" SET "ObsLien"="ObsLien" WHERE "IdProfessionnelFk"=%s', [p])
        self.assertEqual(self.revision(p), 3)
        self.c.execute('DELETE FROM professionnel."T_Professionnel_Entite" WHERE "IdProfessionnelFk"=%s', [p])
        self.assertEqual(self.revision(p), 4)

    def test_detail_04_rejected_change_preserves_revision(self):
        p = self.profile()
        self.insert("professionnel", "T_Professionnel_Competence", {"IdProfessionnelFk": p, "IdCompetenceFk": self.skill})
        revision = self.revision(p)
        self.reject(lambda: self.insert("professionnel", "T_Professionnel_Competence", {"IdProfessionnelFk": p, "IdCompetenceFk": self.skill}), "23505")
        self.assertEqual(self.revision(p), revision)
        self.reject(lambda: self.insert("professionnel", "T_Professionnel_Prestation", {"IdProfessionnelFk": p, "IdPrestationFk": self.skill}))
        self.assertEqual(self.revision(p), revision)

    def test_detail_05_transaction_rollback_restores_parent(self):
        p = self.profile()
        with self.c.transaction(force_rollback=True):
            self.insert("professionnel", "T_Professionnel_Competence", {"IdProfessionnelFk": p, "IdCompetenceFk": self.skill})
            self.assertEqual(self.revision(p), 2)
        self.assertEqual(self.revision(p), 1)
        self.assertFalse(self.c.execute('SELECT EXISTS(SELECT FROM professionnel."T_Professionnel_Competence" WHERE "IdProfessionnelFk"=%s) found', [p]).fetchone()["found"])

    def test_detail_06_no_forged_account_or_author(self):
        p = self.profile(CreeParUserFk=self.actor, ModifieParUserFk=self.actor)
        self.insert("professionnel", "T_Professionnel_Prestation", {"IdProfessionnelFk": p, "IdPrestationFk": self.service})
        row = self.c.execute('SELECT "IdUserFk","IdEntiteFk","CreeParUserFk","ModifieParUserFk" FROM professionnel."T_Professionnel" WHERE "IdProfessionnel"=%s', [p]).fetchone()
        self.assertEqual(row["IdUserFk"], self.user)
        self.assertEqual(row["IdEntiteFk"], self.entity)
        self.assertEqual(row["CreeParUserFk"], self.actor)
        self.assertIsNone(row["ModifieParUserFk"])

    def test_detail_07_context_actor_and_parent_audit(self):
        p = self.profile()
        req = str(uuid.uuid4())
        self.c.execute("SELECT set_config('professionnel.actor_id',%s,true),set_config('professionnel.request_id',%s,true),set_config('professionnel.operation','update',true)", [str(self.actor), req])
        self.insert("professionnel", "T_Professionnel_Competence", {"IdProfessionnelFk": p, "IdCompetenceFk": self.skill})
        row = self.c.execute('SELECT "NewData" FROM systeme."T_Audit_Log" WHERE "TableName"=%s AND "NewData"->>%s=%s', ["professionnel.T_Professionnel", "_requestId", req]).fetchall()
        self.assertEqual(len(row), 1)
        self.assertEqual(row[0]["NewData"]["Revision"], 2)
        self.assertEqual(row[0]["NewData"]["ModifieParUserFk"], self.actor)

    def test_detail_08_noop_does_not_audit_parent(self):
        p = self.profile()
        self.insert("professionnel", "T_Professionnel_Competence", {"IdProfessionnelFk": p, "IdCompetenceFk": self.skill})
        req = str(uuid.uuid4())
        self.c.execute("SELECT set_config('professionnel.request_id',%s,true)", [req])
        self.c.execute('UPDATE professionnel."T_Professionnel_Competence" SET "IdCompetenceFk"="IdCompetenceFk" WHERE "IdProfessionnelFk"=%s', [p])
        self.assertEqual(self.revision(p), 2)
        self.assertEqual(self.c.execute('SELECT count(*) n FROM systeme."T_Audit_Log" WHERE "TableName"=%s AND "NewData"->>%s=%s', ["professionnel.T_Professionnel", "_requestId", req]).fetchone()["n"], 0)

    def test_detail_09_late_trigger_rejection_rolls_back_parent(self):
        p = self.profile()
        # Déclenchement APRÈS zy : la version du parent a déjà été touchée,
        # mais un rejet ultérieur doit annuler cette version et son audit.
        self.c.execute("""CREATE FUNCTION pg_temp.refuser_detail_apres_revision() RETURNS trigger LANGUAGE plpgsql AS $$
            BEGIN RAISE EXCEPTION 'Rejet tardif fictif de recette' USING ERRCODE='23514';END $$""")
        self.c.execute('''CREATE TRIGGER zzzz_rejet_recette AFTER INSERT ON professionnel."T_Professionnel_Competence"
            FOR EACH ROW EXECUTE FUNCTION pg_temp.refuser_detail_apres_revision()''')
        self.reject(lambda: self.insert("professionnel", "T_Professionnel_Competence", {"IdProfessionnelFk": p, "IdCompetenceFk": self.skill}))
        self.assertEqual(self.revision(p), 1)
        self.assertEqual(self.c.execute('SELECT count(*) n FROM systeme."T_Audit_Log" WHERE "TableName"=%s AND "NewData"->>%s=%s', ["professionnel.T_Professionnel", "IdProfessionnel", str(p)]).fetchone()["n"], 1)


def load_tests(loader, tests, pattern):
    return unittest.TestSuite(RevisionsDetailsSQL(name) for name in loader.getTestCaseNames(RevisionsDetailsSQL) if name.startswith("test_detail_"))


if __name__ == "__main__": unittest.main(verbosity=2)
