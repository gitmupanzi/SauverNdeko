"""Recette du journal de session sur une base PostgreSQL privée."""
import json
import unittest
from uuid import uuid4

import test_publication_articles_api  # Vérifie le DSN privé avant d’initialiser Django.
from django.contrib.auth.hashers import make_password
from django.db import transaction
from django.test import override_settings
from rest_framework.test import APIClient

from apps.core import db

AUTH = "/SauverNdeko/auth/"
REGISTER = "/api/systeme/administration/registres/connexions"


class SessionAuditAPI(unittest.TestCase):
    def setUp(self):
        self.enterContext(override_settings(ALLOWED_HOSTS=["testserver"]))
        self.enterContext(transaction.atomic())
        self.addCleanup(transaction.set_rollback, True)
        self.company = db.one(
            """INSERT INTO systeme."T_Entite" ("NomEntite","EmailEntite","ValideEntite")
               VALUES ('Recette journal',%s,true) RETURNING "IdEntite" """,
            [f"{uuid4()}@example.invalid"],
        )["IdEntite"]
        self.password = f"{uuid4()}Aa!7"
        self.manager, self.email = self.account(self.company, staff=True)
        self.platform, self.platform_email = self.account(None, platform=True)

    def account(self, company, *, staff=False, platform=False):
        email = f"{uuid4()}@example.invalid"
        row = db.one(
            """INSERT INTO systeme."T_Utilisateurs"
               ("PrenomUser","NomUser","EmailUser","MotdepasseUser","ValideUser",
                "IdEntiteFk","Is_staff","Is_Admin","SexeUser")
               VALUES ('Compte','Recette',%s,%s,true,%s,%s,%s,'M') RETURNING "IdUser" """,
            [email, make_password(self.password), company, staff, platform],
        )
        return row["IdUser"], email

    def login(self, email):
        client = APIClient()
        response = client.post(
            AUTH + "login", {"EmailUser": email, "MotdepasseUser": self.password}, format="json",
        )
        self.assertEqual(response.status_code, 200, response.data.get("message"))
        client.credentials(HTTP_AUTHORIZATION="Bearer " + response.data["accessToken"])
        return client, response.data["refreshToken"]

    def events(self, user):
        return db.query(
            """SELECT "IdLogin","IdEntite","TypeLogin","DateLogin"
               FROM systeme."V_Login_history" WHERE "IdUser"=%s ORDER BY "IdLogin" """,
            [user],
        )

    def test_authentication_lifecycle_and_admin_visibility(self):
        rejected = APIClient().post(
            AUTH + "login", {"EmailUser": self.email, "MotdepasseUser": "incorrect"}, format="json",
        )
        self.assertIn(rejected.status_code, {401, 403})
        self.assertEqual(self.events(self.manager), [])
        client, refresh_token = self.login(self.email)
        self.assertEqual(client.get(AUTH + "verify").status_code, 200)
        renewed = client.post(AUTH + "refresh", {"refreshToken": refresh_token}, format="json")
        self.assertEqual(renewed.status_code, 200)
        self.assertEqual([row["TypeLogin"] for row in self.events(self.manager)], ["Connexion"])
        self.assertIn(APIClient().post(AUTH + "logout").status_code, {401, 403})
        self.assertEqual(client.post(AUTH + "logout").status_code, 200)

        events = self.events(self.manager)
        self.assertEqual([row["TypeLogin"] for row in events], ["Connexion", "Déconnexion"])
        self.assertTrue(all(row["IdEntite"] == self.company and row["DateLogin"] for row in events))
        audits = db.query(
            """SELECT "NewData","IdEntiteFk" FROM systeme."T_Audit_Log"
               WHERE "TableName"='T_Login' AND "Operation"='INSERT'
                 AND "NewData"->>'IdUserFk'=%s ORDER BY "IdLog" """,
            [str(self.manager)],
        )
        self.assertEqual([audit["NewData"]["IdLogin"] for audit in audits], [row["IdLogin"] for row in events])
        for audit in audits:
            self.assertEqual(audit["IdEntiteFk"], self.company)
            self.assertEqual(set(audit["NewData"]), {"IdLogin", "IdUserFk", "IdTypeLoginFk", "DateLogin", "IdEntiteFk"})

        self.assertEqual(client.get(REGISTER).status_code, 403)
        admin, _ = self.login(self.platform_email)
        response = admin.get(
            REGISTER, {"q": self.email, "filters": json.dumps({"TypeLogin": "Déconnexion"})},
            HTTP_X_ENTITE_ID=str(self.company),
        )
        self.assertEqual(response.status_code, 200, response.data.get("message"))
        self.assertEqual([row["IdLogin"] for row in response.data["data"]], [events[-1]["IdLogin"]])
        self.assertIsNone(self.events(self.platform)[0]["IdEntite"])

    def test_authentication_in_read_only_mode(self):
        with override_settings(DB_READ_ONLY=True):
            client, _ = self.login(self.email)
            self.assertEqual(client.post(AUTH + "logout").status_code, 200)
        self.assertEqual(self.events(self.manager), [])


if __name__ == "__main__":
    unittest.main()
