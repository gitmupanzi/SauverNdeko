"""Recette de la disponibilité réseau, sur une base PostgreSQL privée vide."""

import os
import re
import unittest
from decimal import Decimal
from pathlib import Path
from urllib.parse import urlsplit

import psycopg

ROOT = Path(__file__).resolve().parents[2]
STRUCTURE = ROOT / "SQL/SauverNdeko_Metier_Structure.sql"
MIGRATION = ROOT / "backend/database/migrations/20261113_02_comparaison_disponibilite_reseau.sql"


def definition(structure, kind, schema, name):
    pattern = rf'CREATE {kind} {schema}\."{name}" (?:AS\n|\(\n).*?;'
    return re.search(pattern, structure, re.S)[0]


class DisponibiliteReseauTests(unittest.TestCase):
    def test_rapport_et_detail_reconnaissent_reseau_absent_sans_modifier_les_libelles(self):
        dsn = os.environ.get("SAUVERNDEKO_TEST_DATABASE_URL", "")
        if not dsn:
            self.skipTest("Définissez SAUVERNDEKO_TEST_DATABASE_URL vers une base privée vide.")
        target = urlsplit(dsn)
        if target.hostname not in {"localhost", "127.0.0.1"} or not target.path[1:].startswith("sauverndeko_test_"):
            raise RuntimeError("Base locale de recette sauverndeko_test_* obligatoire.")

        structure = STRUCTURE.read_text(encoding="utf-8")
        with psycopg.connect(dsn, autocommit=True) as conn:
            with conn.transaction(force_rollback=True):
                conn.execute("CREATE SCHEMA geolocalisation; CREATE SCHEMA referentiel;")
                conn.execute(definition(structure, "TABLE", "referentiel", "T_Generique"))
                for level in range(6):
                    conn.execute(definition(structure, "TABLE", "geolocalisation", f"T_Niveau_{level}"))
                conn.execute(definition(structure, "TABLE", "geolocalisation", "T_CoordonneesTerritoire"))
                for name in ("V_Niveau_4", "V_RESEAU_AS_par_ZS"):
                    conn.execute(definition(structure, "VIEW", "geolocalisation", name))

                abbreviations = [
                    (1, "Sans reseau"),
                    (2, "SANS RESEAU"),
                    (3, "Sans réseau"),
                    (4, "SANS RÉSEAU"),
                    (5, "Réseau mobile"),
                    (6, None),
                    (7, "Sans réseaù"),
                ]
                with conn.cursor() as cursor:
                    cursor.executemany(
                        """
                        INSERT INTO referentiel."T_Generique" ("ID_Generique", "ID_CategorieGeneriqueFk", "NomGenerique", "AbrGenerique")
                        VALUES (%s, 1, 'Disponibilité réseau', %s)
                        """,
                        abbreviations,
                    )
                conn.execute('INSERT INTO geolocalisation."T_Niveau_3" ("ID_Niveau_3") VALUES (1), (2)')
                conn.execute("""
                    INSERT INTO geolocalisation."T_Niveau_4"
                        ("ID_Niveau_4", "ID_Niveau_3_Fk", "ID_DispoReseauNiveau_4")
                    SELECT "ID_Generique", 1, "ID_Generique" FROM referentiel."T_Generique"
                """)
                conn.execute("""
                    CREATE ROLE sauverndeko_runtime NOLOGIN;
                    GRANT USAGE ON SCHEMA geolocalisation TO sauverndeko_runtime;
                    GRANT SELECT ON geolocalisation."V_Niveau_4", geolocalisation."V_RESEAU_AS_par_ZS"
                    TO sauverndeko_runtime;
                    ALTER DEFAULT PRIVILEGES REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
                """)
                conn.execute(MIGRATION.read_text(encoding="utf-8"))
                conn.execute("SET LOCAL ROLE sauverndeko_runtime")
                self.assertEqual(
                    conn.execute("""
                        SELECT "AvecReseau", "AdresseTerritoire",
                               "PublierCoordonneesAnnuaire", "HorairesOuvertureTerritoire"
                        FROM geolocalisation."V_Niveau_4" WHERE "ID_Niveau_4" = 1
                    """).fetchone(),
                    (False, None, False, None),
                )
                self.assertTrue(
                    conn.execute("""
                        SELECT has_function_privilege(
                            current_user, 'geolocalisation.fn_aire_avec_reseau(text)', 'EXECUTE'
                        )
                    """).fetchone()[0]
                )
                conn.execute("RESET ROLE")
                self.assertEqual(
                    conn.execute("""
                        SELECT "ID_Generique", "AbrGenerique" FROM referentiel."T_Generique"
                        ORDER BY "ID_Generique"
                    """).fetchall(),
                    abbreviations,
                )
                self.assertEqual(
                    conn.execute("""
                        SELECT "ID_Niveau_4", "AvecReseau" FROM geolocalisation."V_Niveau_4"
                        ORDER BY "ID_Niveau_4"
                    """).fetchall(),
                    [(1, False), (2, False), (3, False), (4, False), (5, True), (6, False), (7, True)],
                )
                self.assertEqual(
                    conn.execute("""
                        SELECT "ID_Niveau_3", "Nb_AS", "Nb_AS_Avec_Reseau", "Pct_AS_Avec_Reseau"
                        FROM geolocalisation."V_RESEAU_AS_par_ZS" ORDER BY "ID_Niveau_3"
                    """).fetchall(),
                    [(1, 7, 2, Decimal("28.6")), (2, 0, 0, None)],
                )


if __name__ == "__main__":
    unittest.main()
