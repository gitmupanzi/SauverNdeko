"""Recette Django réelle sur une base sauverndeko_test_* alimentée par test_metier_postgresql.py."""

import os, sys, json, uuid
from pathlib import Path
from urllib.parse import quote
import psycopg
from psycopg.conninfo import conninfo_to_dict
from psycopg.rows import dict_row

DSN = os.environ.get("SAUVERNDEKO_TEST_DATABASE_URL")
if not DSN:
    raise RuntimeError("SAUVERNDEKO_TEST_DATABASE_URL obligatoire.")
p = conninfo_to_dict(DSN)
with psycopg.connect(DSN) as guard:
    dbname = guard.execute("SELECT current_database()").fetchone()[0]
    if not dbname.startswith("sauverndeko_test_"):
        raise RuntimeError("Base de recette dédiée obligatoire.")
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "backend"))
os.environ["DATABASE_URL"] = (
    "postgresql://"
    + quote(p.get("user", ""), safe="")
    + ":"
    + quote(p.get("password", ""), safe="")
    + "@"
    + p.get("host", "localhost")
    + ":"
    + p.get("port", "5432")
    + "/"
    + quote(dbname, safe="")
)
os.environ["SAUVERNDEKO_DB_READ_ONLY"] = (
    "0"  # Seulement ce processus, après vérification du nom de base dédié.
)
os.environ["DJANGO_SETTINGS_MODULE"] = "config.settings"
import django

django.setup()
from django.conf import settings

assert settings.DATABASES["default"]["NAME"] == dbname
from django.test import override_settings
from django.contrib.auth.hashers import make_password
from rest_framework.test import APIClient
from test_metier_postgresql import Metier

Metier.setUpClass()
checks = []


def expect(client, method, url, body=None, status=200):
    response = (
        getattr(client, method)(url, body, format="json")
        if body is not None
        else getattr(client, method)(url)
    )
    checks.append(
        {
            "method": method.upper(),
            "url": url,
            "status": response.status_code,
            "expected": status,
        }
    )
    if response.status_code != status:
        raise AssertionError(
            str(checks[-1]) + " code=" + str(response.data.get("error"))
        )
    return response.data.get("data")


try:
    with override_settings(ALLOWED_HOSTS=[*settings.ALLOWED_HOSTS, "testserver"]):
        password = uuid.uuid4().hex + "Aa!7"
        email = uuid.uuid4().hex + "@example.invalid"
        uid = Metier.insert(
            "systeme",
            "T_Utilisateurs",
            {
                "NomUser": "Administrateur fictif",
                "PrenomUser": "Recette",
                "EmailUser": email,
                "MotdepasseUser": make_password(password),
                "SexeUser": "M",
                "IdEntiteFk": Metier.entity,
                "Is_Admin": True,
            },
            "IdUser",
        )
        client = APIClient()
        response = client.post(
            "/SauverNdeko/auth/login",
            {"EmailUser": email, "MotdepasseUser": password},
            format="json",
        )
        assert response.status_code == 200, "Connexion du compte fictif refusée."
        token = response.data.get("accessToken") or (
            response.data.get("data") or {}
        ).get("accessToken")
        if not token:
            raise AssertionError("Jeton de session manquant.")
        client.credentials(HTTP_AUTHORIZATION="Bearer " + token)
        me = expect(client, "get", "/SauverNdeko/auth/me")
        assert me["permissions"]["canAccessAdmin"]
        article = expect(
            client,
            "post",
            "/api/logistique/articles",
            {
                "NomArticle": "Article API fictif",
                "PUArticle": "2.00",
                "PVArticle": "3.00",
                "QteArticle": "0",
            },
            201,
        )
        entree = expect(
            client,
            "post",
            "/api/logistique/commandes",
            {"ID_TypeCmdFk": 1001, "ID_StatutCmdFk": 1003},
            201,
        )
        sortie = expect(
            client,
            "post",
            "/api/logistique/commandes",
            {"ID_TypeCmdFk": 1002, "ID_StatutCmdFk": 1003},
            201,
        )
        aid = article["ID_Article"]
        cid = entree["ID_Commande"]
        expect(
            client,
            "post",
            f"/api/logistique/commandes/{cid}/details",
            {"ID_ArticleFk": aid, "QteCmdDetail": "10", "PUCmdDetail": "2"},
            201,
        )
        expect(
            client,
            "post",
            f'/api/logistique/commandes/{sortie["ID_Commande"]}/details',
            {"ID_ArticleFk": aid, "QteCmdDetail": "8", "PUCmdDetail": "2"},
            201,
        )
        expect(
            client,
            "put",
            f"/api/logistique/commandes/{cid}/details/{aid}",
            {"QteCmdDetail": "15"},
        )
        current = expect(client, "get", f"/api/logistique/articles/{aid}")
        assert str(current["QteArticle"]).startswith("7")
        entity = expect(
            client,
            "post",
            "/api/systeme/entites",
            {
                "NomEntite": "Entité API fictive",
                "EmailEntite": uuid.uuid4().hex + "@example.invalid",
            },
            201,
        )
        with psycopg.connect(DSN, row_factory=dict_row) as sqlc:
            date = sqlc.execute("SELECT (now()+interval '20 days')::text d").fetchone()[
                "d"
            ]
        licence = expect(
            client,
            "post",
            "/api/systeme/licences",
            {
                "IdEntiteFk": entity["IdEntite"],
                "DateFin": date,
                "IdStatutLicenceFk": 1004,
            },
            201,
        )
        assert licence["IdLicence"] > 0
        expect(
            client,
            "post",
            "/api/systeme/licences",
            {
                "IdEntiteFk": entity["IdEntite"],
                "DateFin": date,
                "IdStatutLicenceFk": 1004,
            },
            409,
        )
        discussion = expect(
            client,
            "post",
            "/api/discussions/start",
            {"type": "structure", "targetId": entity["IdEntite"]},
            201,
        )
        expect(
            client,
            "post",
            f'/api/discussions/{discussion["IdDiscussion"]}/messages',
            {"message": "Message API fictif"},
            201,
        )
        messages = expect(
            client, "get", f'/api/discussions/{discussion["IdDiscussion"]}/messages'
        )
        assert len(messages) == 1
        expect(client, "get", "/api/recherches")
        expect(client, "get", "/api/public/experts?q=introuvable-fictif-xyz")
        expect(client, "get", "/api/public/stats")
        anonymous = APIClient()
        expect(anonymous, "get", "/api/recherches", status=401)
        from apps.accounts.authentication import Actor

        local = APIClient()
        local.force_authenticate(
            Actor({"IdUser": uid, "Is_staff": True, "IdEntiteFk": Metier.entity})
        )
        expect(local, "get", "/api/recherches", status=403)
    print(
        json.dumps(
            {
                "resultat": "OK",
                "controles": len(checks),
                "connexionMotDePasseReelleSurCompteFictif": True,
                "details": checks,
            },
            ensure_ascii=False,
        )
    )
finally:
    Metier.tearDownClass()
