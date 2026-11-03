"""Recette des professionnels sur un clone privé migré ; jamais sur SauverNdeko.

Chaque scénario annule ses fixtures, profils et audits. Le dictionnaire commun
provient de la migration et ne désigne aucune personne qualifiée réellement.
"""
import hashlib
import os
from pathlib import Path
import unittest
from urllib.parse import urlsplit
import uuid

import psycopg
from psycopg import sql
from psycopg.rows import dict_row

DSN = os.environ.get("SAUVERNDEKO_TEST_DATABASE_URL", "")
if not urlsplit(DSN).path.lstrip("/").startswith("sauverndeko_test_"):
    raise RuntimeError("Base privée sauverndeko_test_* obligatoire, aucun repli source.")


class ProfessionnelsSQL(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.c = psycopg.connect(DSN, autocommit=True, row_factory=dict_row)
        assert cls.c.execute("SELECT current_database() d").fetchone()["d"].startswith("sauverndeko_test_")

    @classmethod
    def tearDownClass(cls):
        cls.c.close()

    def setUp(self):
        self.tx = self.c.transaction(); self.tx.__enter__()
        self.entity = self.insert("systeme", "T_Entite", {"NomEntite": "Recette Experts A " + uuid.uuid4().hex,
            "EmailEntite": uuid.uuid4().hex + "@example.invalid", "ValideEntite": True}, "IdEntite")
        self.other = self.insert("systeme", "T_Entite", {"NomEntite": "Recette Experts B " + uuid.uuid4().hex,
            "EmailEntite": uuid.uuid4().hex + "@example.invalid", "ValideEntite": True}, "IdEntite")
        self.user = self.account(self.entity)
        self.other_user = self.account(self.other)
        self.actor = self.account(None, True)
        self.typ = self.c.execute('SELECT "ID_Generique" id FROM referentiel."T_Generique" g WHERE g."ID_CategorieGeneriqueFk"=ANY(referentiel.fn_categories_champ(%s,%s,%s,%s)) AND g."ValideGenerique" AND g."IdEntiteFk" IS NULL ORDER BY 1 LIMIT 1',
            ["professionnel", "T_Professionnel", "IdTypeProfessionnelFk", self.entity]).fetchone()["id"]
        self.sector = self.ref("T_Professionnel", "IdSecteurFk", "SANTE")
        self.skill = self.ref("T_Professionnel_Competence", "IdCompetenceFk", "Oncologie")
        self.service = self.ref("T_Professionnel_Prestation", "IdPrestationFk", "Consultation médicale")

    def tearDown(self):
        self.c.execute("ROLLBACK")
        self.tx.__exit__(None, None, None)

    def insert(self, schema, table, values, key=None):
        names = list(values)
        q = sql.SQL("INSERT INTO {}.{} ({}) VALUES ({})").format(sql.Identifier(schema), sql.Identifier(table),
            sql.SQL(",").join(map(sql.Identifier, names)), sql.SQL(",").join(sql.Placeholder() for _ in names))
        if key: q += sql.SQL(" RETURNING {} AS id").format(sql.Identifier(key))
        result = self.c.execute(q, [values[n] for n in names])
        return result.fetchone()["id"] if key else None

    def account(self, entity, admin=False):
        return self.insert("systeme", "T_Utilisateurs", {"NomUser": "Recette privée", "PrenomUser": "Profil",
            "EmailUser": uuid.uuid4().hex + "@example.invalid", "PhoneUser": "+243000000000",
            "MotdepasseUser": "inutilisable", "SexeUser": "M", "ValideUser": True,
            "IdEntiteFk": entity, "Is_Admin": admin}, "IdUser")

    def ref(self, table, field, code):
        return self.c.execute('SELECT "ID_Generique" id FROM referentiel."T_Generique" WHERE "ID_CategorieGeneriqueFk"=ANY(referentiel.fn_categories_champ(%s,%s,%s,%s)) AND "AbrGenerique"=%s AND "IdEntiteFk" IS NULL',
            ["professionnel", table, field, self.entity, code]).fetchone()["id"]

    def profile(self, **extra):
        return self.insert("professionnel", "T_Professionnel", {"IdUserFk": self.user, "IdEntiteFk": self.entity,
            "IdTypeProfessionnelFk": self.typ, "IdSecteurFk": self.sector,
            "TitrePublic": "Professionnel fictif pour recette", "PresentationPublique": "Présentation strictement fictive.", **extra}, "IdProfessionnel")

    def update(self, profile, **values):
        q = sql.SQL('UPDATE professionnel."T_Professionnel" SET {} WHERE "IdProfessionnel"=%s').format(
            sql.SQL(",").join(sql.SQL("{}=%s").format(sql.Identifier(k)) for k in values))
        self.c.execute(q, [*values.values(), profile])

    def reject(self, fn, state="23514"):
        with self.assertRaises(psycopg.Error) as got:
            with self.c.transaction(): fn()
        self.assertEqual(got.exception.sqlstate, state)

    def public(self, pk):
        return self.c.execute('SELECT * FROM professionnel."V_Professionnel_Public" WHERE "IdProfessionnel"=%s', [pk]).fetchone()

    def test_01_draft_not_public_nullable_specialty(self):
        p = self.profile()
        self.assertIsNone(self.public(p))
        self.assertIsNone(self.c.execute('SELECT "IdSpecialiteFk" v FROM professionnel."T_Professionnel" WHERE "IdProfessionnel"=%s', [p]).fetchone()["v"])

    def test_02_single_profile_per_user(self):
        self.profile()
        self.reject(lambda: self.profile(), "23505")

    def test_03_cross_company_account_refused(self):
        self.reject(lambda: self.profile(IdUserFk=self.other_user))

    def test_04_owner_and_account_immutable(self):
        p = self.profile()
        self.reject(lambda: self.update(p, IdEntiteFk=self.other))
        self.reject(lambda: self.update(p, IdUserFk=self.other_user))

    def test_05_global_represents_self_only(self):
        self.reject(lambda: self.profile(IdUserFk=self.actor))
        self.c.execute("SELECT set_config('professionnel.actor_id',%s,true)", [str(self.actor)])
        self.profile(IdUserFk=self.actor)

    def test_06_publish_requires_public_identity(self):
        p = self.profile(TitrePublic=None)
        self.reject(lambda: self.update(p, Publie=True))
        self.update(p, TitrePublic="Profil de recette", Publie=True)
        self.assertIsNotNone(self.public(p))

    def test_07_search_need_requires_selected_skill(self):
        p = self.profile(Publie=True)
        q = 'SELECT count(*) n FROM professionnel."V_Professionnel_Public" WHERE "IdProfessionnel"=%s AND "RechercheVecteur" @@ professionnel.fn_expert_recherche(%s)'
        self.assertEqual(self.c.execute(q, [p, "cancer"]).fetchone()["n"], 0)
        self.insert("professionnel", "T_Professionnel_Competence", {"IdProfessionnelFk": p, "IdCompetenceFk": self.skill})
        self.assertEqual(self.c.execute(q, [p, "cancer"]).fetchone()["n"], 1)

    def test_08_public_whitelist_excludes_sensitive_fields(self):
        p = self.profile(Publie=True, NumeroIdentification="PRIVE-" + uuid.uuid4().hex, ObsProfessionnel="Note privée")
        r = self.public(p)
        self.assertNotIn("EmailUser", r); self.assertNotIn("NumeroIdentification", r)
        self.assertEqual(set(r["T_Utilisateurs"]), {"IdUser", "NomUser", "PrenomUser", "UrlPhoto"})

    def test_09_user_inactive_hides_published(self):
        p = self.profile(Publie=True)
        self.c.execute('UPDATE systeme."T_Utilisateurs" SET "ValideUser"=false WHERE "IdUser"=%s', [self.user])
        self.assertIsNone(self.public(p))

    def test_10_company_inactive_hides_published(self):
        p = self.profile(Publie=True)
        self.c.execute('UPDATE systeme."T_Entite" SET "ValideEntite"=false WHERE "IdEntite"=%s', [self.entity])
        self.assertIsNone(self.public(p))

    def test_11_contact_independent_from_publication(self):
        p = self.profile(Publie=True, ContactAutorise=False)
        self.assertFalse(self.public(p)["ContactAutorise"])

    def test_12_new_wrong_category_refused(self):
        self.reject(lambda: self.profile(IdSecteurFk=self.skill))

    def test_13_duplicate_skill_refused(self):
        p = self.profile()
        self.insert("professionnel", "T_Professionnel_Competence", {"IdProfessionnelFk": p, "IdCompetenceFk": self.skill})
        self.reject(lambda: self.insert("professionnel", "T_Professionnel_Competence", {"IdProfessionnelFk": p, "IdCompetenceFk": self.skill}), "23505")

    def test_14_private_skill_other_company_refused(self):
        p = self.profile()
        family = self.c.execute('SELECT "ID_CategorieGeneriqueFk" f FROM referentiel."T_Generique" WHERE "ID_Generique"=%s', [self.skill]).fetchone()["f"]
        private = self.insert("referentiel", "T_Generique", {"ID_CategorieGeneriqueFk": family, "NomGenerique": "Privé " + uuid.uuid4().hex,
            "AbrGenerique": uuid.uuid4().hex, "IdEntiteFk": self.other, "ValideGenerique": True}, "ID_Generique")
        self.reject(lambda: self.insert("professionnel", "T_Professionnel_Competence", {"IdProfessionnelFk": p, "IdCompetenceFk": private}))

    def test_15_historical_inactive_reference_descriptive_edit(self):
        p = self.profile()
        self.c.execute('UPDATE referentiel."T_Generique" SET "ValideGenerique"=false WHERE "ID_Generique"=%s', [self.typ])
        self.update(p, TitrePublic="Titre actualisé")
        self.reject(lambda: self.profile(IdUserFk=self.account(self.entity)))

    def test_16_affiliations_do_not_duplicate_profile(self):
        p = self.profile(Publie=True)
        for e in [self.entity, self.other]:
            self.insert("professionnel", "T_Professionnel_Entite", {"IdProfessionnelFk": p, "IdEntiteFk": e})
        row = self.public(p)
        self.assertEqual(len(row["T_Professionnel_Entite"]), 2)
        self.assertEqual(self.c.execute('SELECT count(*) n FROM professionnel."V_Professionnel_Public" WHERE "IdProfessionnel"=%s', [p]).fetchone()["n"], 1)

    def test_17_primary_affiliation_overlapping_refused(self):
        p = self.profile()
        self.insert("professionnel", "T_Professionnel_Entite", {"IdProfessionnelFk": p, "IdEntiteFk": self.entity, "EstPrincipal": True})
        self.reject(lambda: self.insert("professionnel", "T_Professionnel_Entite", {"IdProfessionnelFk": p, "IdEntiteFk": self.other, "EstPrincipal": True}))

    def test_18_invalid_dates_refused(self):
        p = self.profile()
        self.reject(lambda: self.insert("professionnel", "T_Professionnel_Entite", {"IdProfessionnelFk": p, "IdEntiteFk": self.entity,
            "DateDebut": "2026-02-01", "DateFin": "2026-01-01"}))
        self.reject(lambda: self.insert("professionnel", "T_Professionnel_Entite", {"IdProfessionnelFk": p, "IdEntiteFk": self.entity, "DateDebut": "infinity"}))

    def test_19_revision_and_single_audit_proof(self):
        p = self.profile()
        req = str(uuid.uuid4()); digest = hashlib.sha256(req.encode()).hexdigest()
        self.c.execute("SELECT set_config('professionnel.actor_id',%s,true),set_config('professionnel.request_id',%s,true),set_config('professionnel.payload_hash',%s,true),set_config('professionnel.operation','update',true)", [str(self.actor), req, digest])
        self.update(p, TitrePublic="Titre changé")
        row = self.c.execute('SELECT "Revision" FROM professionnel."T_Professionnel" WHERE "IdProfessionnel"=%s', [p]).fetchone()
        self.assertEqual(row["Revision"], 2)
        audits = self.c.execute('SELECT "NewData" FROM systeme."T_Audit_Log" WHERE "TableName"=%s AND "NewData"->>%s=%s', ["professionnel.T_Professionnel", "_requestId", req]).fetchall()
        self.assertEqual(len(audits), 1); self.assertEqual(audits[0]["NewData"]["_payloadHash"], digest)

    def test_20_physical_delete_refused(self):
        p = self.profile()
        self.reject(lambda: self.c.execute('DELETE FROM professionnel."T_Professionnel" WHERE "IdProfessionnel"=%s', [p]))

    def test_21_synonym_scope_and_duplicates(self):
        self.reject(lambda: self.insert("professionnel", "T_SynonymeRecherche", {"IdGeneriqueFk": self.skill, "Terme": "privé", "IdEntiteFk": self.other}))
        self.reject(lambda: self.insert("professionnel", "T_SynonymeRecherche", {"IdGeneriqueFk": self.skill, "Terme": "  CANCER  "}), "23505")

    def test_22_user_company_move_refused(self):
        self.profile()
        self.reject(lambda: self.c.execute('UPDATE systeme."T_Utilisateurs" SET "IdEntiteFk"=%s WHERE "IdUser"=%s', [self.other, self.user]))

    def test_23_comments_complete(self):
        rows = self.c.execute("SELECT c.relname,a.attname FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace JOIN pg_attribute a ON a.attrelid=c.oid AND a.attnum>0 AND NOT a.attisdropped WHERE n.nspname='professionnel' AND c.relkind IN('r','v') AND col_description(c.oid,a.attnum) IS NULL").fetchall()
        self.assertEqual(rows, [])

    def test_24_dynamic_category_and_default_restoration(self):
        p = self.profile()
        family = self.insert("referentiel", "T_CategorieGenerique", {"NomCategorieGenerique": "Secteur alternatif " + uuid.uuid4().hex,
            "ValideCategorieGenerique": True}, "ID_CategorieGenerique")
        value = self.insert("referentiel", "T_Generique", {"ID_CategorieGeneriqueFk": family,
            "NomGenerique": "Référence alternative " + uuid.uuid4().hex, "ValideGenerique": True}, "ID_Generique")
        field = self.c.execute('SELECT "ID_ChampReferentiel" id FROM referentiel."T_ChampReferentiel" WHERE "SchemaName"=%s AND "TableName"=%s AND "ColumnName"=%s', ["professionnel", "T_Professionnel", "IdSecteurFk"]).fetchone()["id"]
        mapping = self.insert("systeme", "T_Fk_Correspondance", {"ModuleName": "professionnel", "SchemaName": "professionnel",
            "SourceKey": "champ." + str(field), "FieldName": "IdSecteurFk", "FieldLabel": "Secteur",
            "MappingType": "generic_category", "ReferenceSchemaName": "referentiel", "ReferenceObjectName": "T_Generique",
            "ReferenceFieldName": "ID_Generique", "TargetCategoryIdFk": family, "MappingValue": str(family),
            "IsDefaultMapping": False, "ValideFkCorrespondance": True, "SettingScope": "entity", "ScopeValue": str(self.entity),
            "IdChampReferentielFk": field}, "IdFkCorrespondance")
        self.update(p, TitrePublic="Modification descriptive autorisée")
        self.reject(lambda: self.profile(IdUserFk=self.account(self.entity)))
        self.profile(IdUserFk=self.account(self.entity), IdSecteurFk=value)
        self.c.execute('UPDATE systeme."T_Fk_Correspondance" SET "MappingValue"=%s,"TargetCategoryIdFk"=NULL,"IsDefaultMapping"=true WHERE "IdFkCorrespondance"=%s', ["@default", mapping])
        self.profile(IdUserFk=self.account(self.entity))

    def test_25_future_and_expired_affiliations_hidden(self):
        p = self.profile(Publie=True)
        self.insert("professionnel", "T_Professionnel_Entite", {"IdProfessionnelFk": p, "IdEntiteFk": self.entity, "DateDebut": "2099-01-01"})
        self.insert("professionnel", "T_Professionnel_Entite", {"IdProfessionnelFk": p, "IdEntiteFk": self.other, "DateFin": "2000-01-01"})
        self.assertEqual(self.public(p)["T_Professionnel_Entite"], [])

    def test_26_publish_inactive_reference_refused(self):
        p = self.profile()
        self.c.execute('UPDATE referentiel."T_Generique" SET "ValideGenerique"=false WHERE "ID_Generique"=%s', [self.typ])
        self.reject(lambda: self.update(p, Publie=True))

    def test_27_defaults_useful_without_customer_overrides(self):
        for table, field in [("T_Professionnel", "IdTypeProfessionnelFk"), ("T_Professionnel_Entite", "IdTypeLienFk")]:
            row = self.c.execute('SELECT "ID_CategorieDefautFk" id FROM referentiel."T_ChampReferentiel" WHERE "SchemaName"=%s AND "TableName"=%s AND "ColumnName"=%s', ["professionnel", table, field]).fetchone()
            self.assertIsNotNone(row["id"])
            self.assertGreater(self.c.execute('SELECT count(*) n FROM referentiel."T_Generique" WHERE "ID_CategorieGeneriqueFk"=%s AND "ValideGenerique" AND "IdEntiteFk" IS NULL', [row["id"]]).fetchone()["n"], 0)

    def test_28_affiliation_references_use_profile_owner(self):
        p = self.profile()
        family = self.c.execute('SELECT "ID_CategorieDefautFk" id FROM referentiel."T_ChampReferentiel" WHERE "SchemaName"=%s AND "TableName"=%s AND "ColumnName"=%s', ["professionnel", "T_Professionnel_Entite", "IdTypeLienFk"]).fetchone()["id"]
        private = self.insert("referentiel", "T_Generique", {"ID_CategorieGeneriqueFk": family, "NomGenerique": "Affiliation privée " + uuid.uuid4().hex,
            "IdEntiteFk": self.entity, "ValideGenerique": True}, "ID_Generique")
        self.insert("professionnel", "T_Professionnel_Entite", {"IdProfessionnelFk": p, "IdEntiteFk": self.other, "IdTypeLienFk": private})


if __name__ == "__main__": unittest.main(verbosity=2)
