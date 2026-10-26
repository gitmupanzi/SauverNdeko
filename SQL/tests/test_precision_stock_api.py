"""API de précision : recette après migration 20261026_10, sur clone local privé.

Ne crée ni base ni schéma ; aucune migration n’est lancée. Fixtures, licence et
audits fictifs sont annulés dans une transaction globale. DATABASE_URL est fixé
au DSN de recette validé avant le chargement de Django, sans repli applicatif.
"""
import json
import os
import secrets
import sys
import uuid
from datetime import datetime
from pathlib import Path
from types import SimpleNamespace
from urllib.parse import urlsplit

import psycopg

ROOT = Path(__file__).resolve().parents[2]
dsn = os.environ.get("SAUVERNDEKO_TEST_DATABASE_URL", "")
url = urlsplit(dsn)
if (
    url.scheme not in {"postgres", "postgresql"}
    or url.hostname not in {"localhost", "127.0.0.1", "::1"}
    or not url.path[1:].startswith("sauverndeko_test_")
):
    raise RuntimeError("Un clone PostgreSQL local sauverndeko_test_* est obligatoire.")
with psycopg.connect(dsn) as guard:
    if not guard.execute("SELECT current_database()").fetchone()[0].startswith("sauverndeko_test_"):
        raise RuntimeError("Base de recette dédiée obligatoire.")

os.environ.update(
    DJANGO_SETTINGS_MODULE="config.settings",
    DATABASE_URL=dsn,
    SAUVERNDEKO_DB_READ_ONLY="0",
    DJANGO_SECRET_KEY=secrets.token_urlsafe(40),
    JWT_SECRET=secrets.token_urlsafe(40),
    JWT_REFRESH_SECRET=secrets.token_urlsafe(40),
)
sys.path.insert(0, str(ROOT / "backend"))
import django
django.setup()

from django.db import transaction
from django.test import override_settings
from rest_framework.test import APIRequestFactory, force_authenticate
from apps.accounts.authentication import actor_by_id
from apps.core import db
from apps.core.application_licences import catalogue_rows, save_license_modules
from apps.core.module_access import access_snapshot
from apps.core.tenancy import bind_context
from apps.logistique.inventories import UnitPrecisionView

checks = []
factory = APIRequestFactory()
route = "/api/logistique/inventaires/unites"
view = UnitPrecisionView.as_view()


def check(value, label):
    if not value:
        raise AssertionError(label)
    checks.append(label)


def insert(schema, table, values, key):
    return db.one(
        "INSERT INTO " + db.qualified(schema, table) + " ("
        + ",".join(db.ident(name) for name in values) + ") VALUES ("
        + ",".join(["%s"] * len(values)) + ") RETURNING " + db.ident(key) + " id",
        list(values.values()),
    )["id"]


def call(method, actor=None, body=None):
    request = factory.get(route) if method == "get" else factory.put(route, body, format="json")
    if actor is not None:
        force_authenticate(request, actor)
    response = view(request)
    response.render()
    return response, json.loads(response.content)


def same_datetime(actual, expected):
    if isinstance(actual, str):
        actual = datetime.fromisoformat(actual.replace("Z", "+00:00"))
    if isinstance(expected, str):
        expected = datetime.fromisoformat(expected.replace("Z", "+00:00"))
    return actual == expected


with override_settings(ALLOWED_HOSTS=["testserver"]):
    with transaction.atomic():
        try:
            tag = uuid.uuid4().hex
            entity = insert("systeme", "T_Entite", {
                "NomEntite": "Précision API fictive " + tag,
                "EmailEntite": tag + "@example.invalid",
                "ValideEntite": True,
            }, "IdEntite")
            common = {
                "NomUser": "Recette",
                "PrenomUser": "Précision API",
                "MotdepasseUser": "compte-fictif-inutilisable",
                "SexeUser": "M",
                "IdEntiteFk": entity,
                "ValideUser": True,
            }
            global_id = insert("systeme", "T_Utilisateurs", {
                **common, "EmailUser": tag + "-global@example.invalid", "Is_Admin": True,
            }, "IdUser")
            local_id = insert("systeme", "T_Utilisateurs", {
                **common, "EmailUser": tag + "-local@example.invalid", "Is_Admin": False, "Is_staff": True,
            }, "IdUser")
            global_actor = bind_context(
                actor_by_id(global_id),
                SimpleNamespace(headers={"X-Entite-ID": str(entity)}),
            )
            active_status = db.one(
                """SELECT g."ID_Generique" id FROM referentiel."T_Generique" g
                   JOIN referentiel."T_CategorieGenerique" c ON c."ID_CategorieGenerique"=g."ID_CategorieGeneriqueFk"
                   WHERE lower(c."NomCategorieGenerique")='statut licence'
                     AND lower(g."NomGenerique") IN ('active','actif')
                     AND g."ValideGenerique" IS TRUE ORDER BY g."ID_Generique" LIMIT 1"""
            )
            check(active_status is not None, "statut de licence du dictionnaire disponible")
            dates = db.one("SELECT LOCALTIMESTAMP-interval '1 day' start, LOCALTIMESTAMP+interval '1 year' finish")
            licence = insert("systeme", "T_Licence", {
                "IdEntiteFk": entity, "DateDebut": dates["start"], "DateFin": dates["finish"],
                "IdStatutLicenceFk": active_status["id"], "ValideLicence": True,
            }, "IdLicence")
            save_license_modules(global_actor, licence, {
                "enabled": ["logistique"],
                "versions": {row["CodeModule"]: 0 for row in catalogue_rows() if not row["EstSocle"]},
            })
            local_actor = actor_by_id(local_id)
            local_rights = access_snapshot(local_actor)["modules"]["logistique"]
            check(local_actor.admin and not local_actor.global_admin and local_rights["canManage"], "gestionnaire local licencié réellement habilité")

            unit = insert("referentiel", "T_Generique", {
                "ID_CategorieGeneriqueFk": 34, "NomGenerique": "Unité API fictive " + tag,
                "AbrGenerique": "u", "ValideGenerique": True,
            }, "ID_Generique")
            def records():
                return db.query(
                    """SELECT "Operation","OldData","NewData" FROM systeme."T_Audit_Log"
                       WHERE "TableName"='logistique.T_PrecisionStock'
                         AND "NewData"->>'ID_UniteFk'=%s
                       ORDER BY "ChangedAt","IdLog" """,
                    [str(unit)],
                )

            response, payload = call("get", global_actor)
            check(response.status_code == 200, "GET administrateur global")
            current = next(row for row in payload["data"] if row["ID_UniteFk"] == unit)
            check(current["Decimales"] == 0 and current["ID_PrecisionStock"] is None, "GET expose alias Decimales et défaut entier")
            check("DecimalesStock" not in current and "ModifieLe" in current, "contrat GET compatible sans fuite de colonne physique")

            response, created = call("put", global_actor, {"ID_UniteFk": unit, "Decimales": 3})
            check(response.status_code == 200, "PUT crée la politique")
            policy = created["data"]
            check(policy["ID_PrecisionStock"] > 0 and policy["ID_UniteFk"] == unit and policy["Decimales"] == 3, "identité retournée et unité conservée")
            check(bool(policy["ModifieLe"]), "date du réglage retournée")
            history = records()
            check(len(history) == 1 and history[0]["Operation"] == "INSERT" and history[0]["OldData"] is None, "audit INSERT sans valeur antérieure fictive")
            check(
                history[0]["NewData"]["ID_PrecisionStock"] == policy["ID_PrecisionStock"]
                and history[0]["NewData"]["DecimalesStock"] == 3
                and same_datetime(history[0]["NewData"]["ModifieLe"], policy["ModifieLe"])
                and history[0]["NewData"]["_actor"]["IdUser"] == global_id,
                "audit INSERT contient identité, précision, date sérialisée et acteur réel",
            )

            response, unchanged = call("put", global_actor, {"ID_UniteFk": unit, "Decimales": 3})
            check(response.status_code == 200, "PUT identique accepté")
            check(
                unchanged["data"]["ID_PrecisionStock"] == policy["ID_PrecisionStock"]
                and same_datetime(unchanged["data"]["ModifieLe"], policy["ModifieLe"]),
                "ID et date inchangés sur une opération sans changement",
            )
            history = records()
            check(
                len(history) == 2 and history[-1]["Operation"] == "UPDATE"
                and same_datetime(history[-1]["OldData"]["ModifieLe"], policy["ModifieLe"])
                and same_datetime(history[-1]["NewData"]["ModifieLe"], policy["ModifieLe"]),
                "audit UPDATE sans changement sérialise les deux dates historiques",
            )

            response, changed = call("put", global_actor, {"ID_UniteFk": unit, "Decimales": 2})
            check(response.status_code == 200 and changed["data"]["Decimales"] == 2, "PUT change effectivement la précision")
            check(changed["data"]["ID_PrecisionStock"] == policy["ID_PrecisionStock"], "ID stable après modification")
            history = records()
            check(
                len(history) == 3 and history[-1]["OldData"]["DecimalesStock"] == 3
                and history[-1]["NewData"]["DecimalesStock"] == 2
                and same_datetime(history[-1]["OldData"]["ModifieLe"], policy["ModifieLe"])
                and same_datetime(history[-1]["NewData"]["ModifieLe"], changed["data"]["ModifieLe"]),
                "audit UPDATE conserve anciennes et nouvelles valeurs horodatées",
            )

            response, listed = call("get", local_actor)
            check(response.status_code == 200, "gestionnaire local consulte la politique partagée")
            current = next(row for row in listed["data"] if row["ID_UniteFk"] == unit)
            check(current["Decimales"] == 2 and current["ID_PrecisionStock"] == policy["ID_PrecisionStock"], "GET après modification reflète le réglage partagé")
            response, refused = call("put", local_actor, {"ID_UniteFk": unit, "Decimales": 1})
            check(
                response.status_code == 403 and refused["error"]["code"] == "GLOBAL_ADMIN_REQUIRED",
                "gestionnaire local licencié ne modifie pas la politique globale",
            )
            check(len(records()) == 3, "refus local sans audit ni écriture de précision")
            response, _ = call("get")
            check(response.status_code in (401, 403), "authentification obligatoire")
            for invalid in [True, -1, 4, "3"]:
                response, _ = call("put", global_actor, {"ID_UniteFk": unit, "Decimales": invalid})
                check(response.status_code == 400, "précision API invalide refusée : " + repr(invalid))
        finally:
            transaction.set_rollback(True)

print("PASS", len(checks), checks)
