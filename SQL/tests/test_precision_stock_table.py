"""Précision du stock : recette postmigration 20261026_10 en base privée locale.

Aucun repli vers DATABASE_URL. Cette recette ne crée ni base ni schéma et ne
lance aucune migration. Ses données fictives sont annulées dans un ROLLBACK
final, y compris lorsqu’une assertion échoue. Elle doit être lancée uniquement
après installation de la migration dans une base sauverndeko_test_* dédiée.
"""
import os
import uuid
from pathlib import Path
from urllib.parse import urlsplit

import psycopg

dsn = os.environ.get("SAUVERNDEKO_TEST_DATABASE_URL", "")
url = urlsplit(dsn)
if (
    url.scheme not in {"postgres", "postgresql"}
    or url.hostname not in {"localhost", "127.0.0.1", "::1"}
    or not url.path[1:].startswith("sauverndeko_test_")
):
    raise RuntimeError("URL locale de recette sauverndeko_test_* explicitement requise.")

checks = []


def check(value, label):
    if not value:
        raise AssertionError(label)
    checks.append(label)


with psycopg.connect(dsn, autocommit=False) as conn:
    try:
        database = conn.execute("SELECT current_database()").fetchone()[0]
        check(database.startswith("sauverndeko_test_"), "base privée vérifiée")
        check(
            conn.execute("SELECT to_regclass('logistique.\"T_PrecisionStock\"') IS NOT NULL").fetchone()[0],
            "migration de précision installée",
        )
        check(
            conn.execute(
                """SELECT count(*) FROM information_schema.columns
                   WHERE table_schema='referentiel' AND table_name='T_Generique'
                     AND column_name IN ('DecimalesStock','PrecisionStockModifieLe')"""
            ).fetchone()[0] == 0,
            "anciennes colonnes retirées du référentiel",
        )
        check(
            conn.execute(
                """SELECT is_identity='YES' AND is_nullable='NO'
                   FROM information_schema.columns
                   WHERE table_schema='logistique' AND table_name='T_PrecisionStock'
                     AND column_name='ID_PrecisionStock'"""
            ).fetchone()[0],
            "identifiant de précision natif et obligatoire",
        )
        check(
            conn.execute(
                """SELECT EXISTS(
                     SELECT FROM pg_constraint c
                     JOIN pg_attribute local_col ON local_col.attrelid=c.conrelid
                       AND local_col.attnum=ANY(c.conkey)
                     JOIN pg_attribute target_col ON target_col.attrelid=c.confrelid
                       AND target_col.attnum=ANY(c.confkey)
                     WHERE c.contype='f' AND c.conrelid='logistique."T_PrecisionStock"'::regclass
                       AND c.confrelid='referentiel."T_Generique"'::regclass
                       AND local_col.attname='ID_UniteFk' AND target_col.attname='ID_Generique'
                   )"""
            ).fetchone()[0],
            "clé étrangère réelle vers la même unité que les articles",
        )
        check(
            conn.execute(
                """SELECT obj_description('logistique."T_PrecisionStock"'::regclass) IS NOT NULL
                    AND (SELECT count(*)=4 FROM pg_attribute
                         WHERE attrelid='logistique."T_PrecisionStock"'::regclass
                           AND attnum>0 AND NOT attisdropped
                           AND col_description(attrelid,attnum) IS NOT NULL)"""
            ).fetchone()[0],
            "table et quatre colonnes documentées par COMMENT ON",
        )
        check(
            conn.execute(
                """SELECT count(*) FROM information_schema.columns
                   WHERE table_schema='logistique' AND table_name='V_PrecisionStock'
                     AND column_name IN ('ID_UniteFk','DecimalesStock')"""
            ).fetchone()[0] == 2,
            "vue canonique de précision disponible",
        )

        tag = "PRECISION-RECETTE-" + uuid.uuid4().hex
        check(
            conn.execute(
                'SELECT EXISTS(SELECT FROM referentiel."T_CategorieGenerique" WHERE "ID_CategorieGenerique"=34)'
            ).fetchone()[0],
            "catégorie Unités du dictionnaire présente",
        )

        def generic(category, suffix):
            return conn.execute(
                """INSERT INTO referentiel."T_Generique"
                     ("ID_CategorieGeneriqueFk","NomGenerique","AbrGenerique","ValideGenerique")
                   VALUES (%s,%s,%s,true) RETURNING "ID_Generique" """,
                [category, tag + suffix, "u"],
            ).fetchone()[0]

        def reject(operation, label):
            conn.execute("SAVEPOINT precision_rejection")
            try:
                operation()
            except psycopg.Error as error:
                conn.execute("ROLLBACK TO SAVEPOINT precision_rejection")
                conn.execute("RELEASE SAVEPOINT precision_rejection")
                check(error.sqlstate in {"23503", "23505", "23514", "23502"}, label)
                return
            conn.execute("ROLLBACK TO SAVEPOINT precision_rejection")
            conn.execute("RELEASE SAVEPOINT precision_rejection")
            raise AssertionError(label + " : opération acceptée")

        def quantity(unit, value):
            return conn.execute("SELECT logistique.fn_verifier_quantite(%s,%s::numeric)", [unit, value]).fetchone()

        unit = generic(34, "-entier")
        quantity(unit, "2")
        check(True, "unité sans réglage accepte une quantité entière")
        reject(lambda: quantity(unit, "0.5"), "zéro décimale implicite sans réglage")
        row = conn.execute(
            """INSERT INTO logistique."T_PrecisionStock" ("ID_UniteFk","DecimalesStock")
               VALUES (%s,3)
               RETURNING "ID_PrecisionStock","ID_UniteFk","DecimalesStock","ModifieLe" """,
            [unit],
        ).fetchone()
        check(row[0] > 0 and row[1] == unit and row[2] == 3 and row[3] is not None, "réglage lié et horodaté")
        quantity(unit, "1.125")
        check(True, "trois décimales exactes acceptées")
        for value in ["-1", "1.1251", "NaN", "Infinity", "-Infinity", "100000000000"]:
            reject(lambda value=value: quantity(unit, value), "quantité hors précision refusée : " + value)
        for decimals in [-1, 4]:
            reject(
                lambda decimals=decimals: conn.execute(
                    'UPDATE logistique."T_PrecisionStock" SET "DecimalesStock"=%s WHERE "ID_UniteFk"=%s',
                    [decimals, unit],
                ),
                "borne de décimales refusée : " + str(decimals),
            )
        reject(
            lambda: conn.execute(
                'INSERT INTO logistique."T_PrecisionStock" ("ID_UniteFk","DecimalesStock") VALUES (%s,2)',
                [unit],
            ),
            "un seul réglage par unité",
        )
        other_category = conn.execute(
            'SELECT "ID_CategorieGenerique" FROM referentiel."T_CategorieGenerique" WHERE "ID_CategorieGenerique"<>34 ORDER BY "ID_CategorieGenerique" LIMIT 1'
        ).fetchone()
        check(other_category is not None, "autre catégorie disponible pour le contrôle négatif")
        not_unit = generic(other_category[0], "-hors-unite")
        reject(
            lambda: conn.execute(
                'INSERT INTO logistique."T_PrecisionStock" ("ID_UniteFk","DecimalesStock") VALUES (%s,1)',
                [not_unit],
            ),
            "valeur d’une autre catégorie refusée",
        )
        reject(
            lambda: conn.execute(
                'UPDATE referentiel."T_Generique" SET "ID_CategorieGeneriqueFk"=%s WHERE "ID_Generique"=%s',
                [other_category[0], unit],
            ),
            "reclassement d’une unité configurée refusé",
        )
        reject(
            lambda: conn.execute(
                'UPDATE logistique."T_PrecisionStock" SET "ID_UniteFk"=%s WHERE "ID_UniteFk"=%s',
                [generic(34, "-autre"), unit],
            ),
            "unité du réglage immuable",
        )
        reject(
            lambda: conn.execute('DELETE FROM logistique."T_PrecisionStock" WHERE "ID_UniteFk"=%s', [unit]),
            "suppression directe de politique refusée",
        )
        conn.execute(
            'UPDATE logistique."T_PrecisionStock" SET "DecimalesStock"=0 WHERE "ID_UniteFk"=%s', [unit]
        )
        quantity(unit, "3")
        reject(lambda: quantity(unit, "1.125"), "retour explicite à zéro sur unité non utilisée")
        check(
            conn.execute('SELECT "DecimalesStock" FROM logistique."V_PrecisionStock" WHERE "ID_UniteFk"=%s', [unit]).fetchone()[0] == 0,
            "vue alignée sur le réglage modifié",
        )
    finally:
        conn.rollback()

print("PASS", len(checks), checks)
