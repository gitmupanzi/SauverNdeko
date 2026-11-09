"""Recette du journal de session sur une base PostgreSQL privée."""
import json
import unittest
from unittest.mock import patch
from uuid import uuid4

import test_publication_articles_api  # Vérifie le DSN privé avant d’initialiser Django.
from django.contrib.auth.hashers import make_password
from django.core.cache import cache
from django.db import transaction
from django.test import override_settings
from rest_framework.test import APIClient

from apps.accounts.authentication import decode_claims
from apps.core import db

AUTH = "/SauverNdeko/auth/"
REGISTER = "/api/systeme/administration/registres/connexions"


class SessionAuditAPI(unittest.TestCase):
    def setUp(self):
        cache.clear()
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
        self.assertEqual(client.get(REGISTER).status_code, 403)
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

        self.assertEqual(client.get(REGISTER).status_code, 401)
        admin, _ = self.login(self.platform_email)
        response = admin.get(
            REGISTER, {"q": self.email, "filters": json.dumps({"TypeLogin": "Déconnexion"})},
            HTTP_X_ENTITE_ID=str(self.company),
        )
        self.assertEqual(response.status_code, 200, response.data.get("message"))
        self.assertEqual([row["IdLogin"] for row in response.data["data"]], [events[-1]["IdLogin"]])
        self.assertIsNone(self.events(self.platform)[0]["IdEntite"])

    def test_logout_revokes_the_session_without_disconnecting_another_device(self):
        client, refresh_token = self.login(self.email)
        another, another_refresh = self.login(self.email)
        renewed = APIClient().post(AUTH + "refresh", {"refreshToken": refresh_token}, format="json")
        self.assertEqual(renewed.status_code, 200)
        before = decode_claims(refresh_token, "refresh")
        after = decode_claims(renewed.data["refreshToken"], "refresh")
        self.assertEqual((before["sid"], before["exp"]), (after["sid"], after["exp"]))
        response = client.post(AUTH + "logout")
        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.data["data"]["revoked"])

        self.assertEqual(client.get(AUTH + "verify").status_code, 401)
        replay = APIClient()
        replay.credentials(HTTP_AUTHORIZATION="Bearer " + renewed.data["accessToken"])
        self.assertEqual(replay.get(AUTH + "verify").status_code, 401)
        for revoked in (refresh_token, renewed.data["refreshToken"]):
            response = APIClient().post(AUTH + "refresh", {"refreshToken": revoked}, format="json")
            self.assertIn(response.status_code, {401, 403})
        self.assertEqual(another.get(AUTH + "verify").status_code, 200)
        self.assertEqual(
            APIClient().post(AUTH + "refresh", {"refreshToken": another_refresh}, format="json").status_code,
            200,
        )

    def test_email_cannot_reuse_another_accounts_login(self):
        client, _ = self.login(self.email)
        response = client.put(
            AUTH + "me",
            {"EmailUser": self.platform_email.upper(), "currentPassword": self.password},
            format="json",
        )
        self.assertEqual(response.status_code, 409, response.data)
        self.assertEqual(client.get(AUTH + "me").data["data"]["EmailUser"], self.email)

    def test_changing_email_requires_current_password_for_both_profile_routes(self):
        client, _ = self.login(self.email)
        email = f"{uuid4()}@example.invalid"
        self.assertEqual(client.put(AUTH + "me", {"PrenomUser": "Modifié"}, format="json").status_code, 200)
        for method, url, body, fmt in (
            (client.put, "me", {"EmailUser": email}, "json"),
            (client.post, "me/photo", {"payload": json.dumps({"EmailUser": email, "currentPassword": "wrong"})}, "multipart"),
        ):
            response = method(AUTH + url, body, format=fmt)
            self.assertEqual(response.status_code, 400, response.data)
            self.assertEqual(response.data["error"]["code"], "PROFILE_EMAIL_REAUTHENTICATION")
        self.assertEqual(client.get(AUTH + "me").data["data"]["EmailUser"], self.email)
        response = client.put(
            AUTH + "me", {"EmailUser": email, "currentPassword": self.password}, format="json",
        )
        self.assertEqual(response.status_code, 200, response.data.get("message"))
        self.assertEqual(response.data["data"]["EmailUser"], email)
        self.assertNotIn(self.password, response.content.decode())
        self.login(email)
        other_email = f"{uuid4()}@example.invalid"
        response = client.post(
            AUTH + "me/photo", {"payload": json.dumps({"EmailUser": other_email, "currentPassword": self.password})},
            format="multipart",
        )
        self.assertEqual(response.status_code, 200, response.data.get("message"))
        self.assertEqual(response.data["data"]["EmailUser"], other_email)
        records = db.query(
            'SELECT "OldData", "NewData" FROM systeme."T_Audit_Log" '
            'WHERE "NewData"->>\'IdUser\'=%s',
            [str(self.manager)],
        )
        self.assertTrue(records)
        for record in records:
            for data in (record["OldData"], record["NewData"]):
                if data:
                    self.assertNotIn("currentPassword", data)
                    self.assertNotIn("MotdepasseUser", data)
        self.assertNotIn(self.password, str(records))

    def test_login_and_refresh_reject_json_arrays(self):
        client = APIClient()
        self.assertEqual(client.post(AUTH + "login", [{}], format="json").status_code, 400)
        self.assertIn(client.post(AUTH + "refresh", [{}], format="json").status_code, {401, 403})

    def test_login_throttle_follows_account_across_ip_addresses_and_case(self):
        with patch("apps.accounts.views.password_matches", return_value=False):
            for attempt in range(16):
                email = self.email.upper() if attempt % 2 else self.email
                response = APIClient().post(
                    AUTH + "login", {"EmailUser": email, "MotdepasseUser": "wrong"}, format="json",
                    REMOTE_ADDR=f"192.0.2.{attempt + 1}",
                )
                if attempt < 15:
                    self.assertIn(response.status_code, {401, 403})
                else:
                    self.assertEqual(response.status_code, 429)

    def test_login_throttle_ignores_forwarded_addresses_from_the_request(self):
        with patch("apps.accounts.views.password_matches", return_value=False):
            for attempt in range(11):
                response = APIClient().post(
                    AUTH + "login", {"EmailUser": self.email, "MotdepasseUser": "wrong"}, format="json",
                    REMOTE_ADDR="192.0.2.1", HTTP_X_FORWARDED_FOR=f"198.51.100.{attempt + 1}",
                )
                if attempt < 10:
                    self.assertIn(response.status_code, {401, 403})
                else:
                    self.assertEqual(response.status_code, 429)

    def test_authentication_in_read_only_mode(self):
        with override_settings(DB_READ_ONLY=True):
            client, _ = self.login(self.email)
            response = client.post(AUTH + "logout")
            self.assertEqual(response.status_code, 200)
            self.assertFalse(response.data["data"]["revoked"])
        self.assertEqual(self.events(self.manager), [])


if __name__ == "__main__":
    unittest.main()
