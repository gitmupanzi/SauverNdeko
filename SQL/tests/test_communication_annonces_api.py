"""Recette des annonces sur une copie PostgreSQL locale explicitement isolée."""

import os
import sys
import unittest
import uuid
from pathlib import Path
from urllib.parse import urlsplit

import psycopg

ROOT = Path(__file__).resolve().parents[2]
DSN = os.environ.get("SAUVERNDEKO_TEST_DATABASE_URL", "")
target = urlsplit(DSN)
if target.hostname not in {"localhost", "127.0.0.1"} or not target.path.startswith("/sauverndeko_test_"):
    raise RuntimeError("Recette réservée à une base PostgreSQL privée sauverndeko_test_*.")
with psycopg.connect(DSN) as guard:
    if not guard.execute("SELECT current_database()").fetchone()[0].startswith("sauverndeko_test_"):
        raise RuntimeError("La connexion ne pointe pas vers une base de recette.")

sys.path.insert(0, str(ROOT / "backend"))
os.environ.update(DATABASE_URL=DSN, DJANGO_SETTINGS_MODULE="config.settings", SAUVERNDEKO_DB_READ_ONLY="0")

import django
django.setup()

from django.db import transaction
from django.test import override_settings
from rest_framework.test import APIClient

from apps.accounts.authentication import Actor
from apps.core import db


BASE = "/api/discussions/annonces"
INBOX = "/api/notifications"


def company(active=True):
    return db.one(
        '''INSERT INTO systeme."T_Entite" ("NomEntite", "EmailEntite", "ValideEntite")
           VALUES (%s, %s, %s) RETURNING "IdEntite"''',
        ["Entreprise de recette " + uuid.uuid4().hex, uuid.uuid4().hex + "@example.invalid", active],
    )["IdEntite"]


def user(entity, *, admin=False, platform=False, active=True):
    return db.one(
        '''INSERT INTO systeme."T_Utilisateurs" (
               "IdEntiteFk", "NomUser", "PrenomUser", "EmailUser", "MotdepasseUser",
               "SexeUser", "ValideUser", "Is_staff", "Is_Admin"
           ) VALUES (%s, 'Recette', 'Communication', %s, 'inutilisable', 'M', %s, %s, %s)
           RETURNING *''',
        [entity, uuid.uuid4().hex + "@example.invalid", active, admin, platform],
    )


def client(row, *, manage=True, read=True, context=None):
    actor = Actor(dict(row))
    actor._module_access = {"modules": {"discussions": {
        "canRead": read, "canManage": manage, "reason": "MODULE_ROLE_FORBIDDEN",
    }}}
    if context is not None:
        actor._context_entity = context
    result = APIClient()
    result.force_authenticate(actor)
    return result


def draft(*company_ids, scope="companies", **fields):
    return {
        "title": "Intervention planifiée",
        "body": "Le service sera indisponible pendant une heure.",
        "scope": scope,
        "companyIds": list(company_ids),
        "requestId": str(uuid.uuid4()),
        **fields,
    }


class AnnouncementAPI(unittest.TestCase):
    def setUp(self):
        self.enterContext(override_settings(ALLOWED_HOSTS=["testserver"]))
        self.tx = transaction.atomic()
        self.tx.__enter__()
        self.addCleanup(self.finish_transaction)
        self.a = company()
        self.b = company()
        self.empty = company()
        self.inactive = company(active=False)
        self.manager = user(self.a, admin=True)
        self.b_manager = user(self.b, admin=True)
        self.a_person = user(self.a)
        self.b_person = user(self.b)
        self.disabled = user(self.a, active=False)
        self.platform = user(self.a, platform=True)

    def finish_transaction(self):
        transaction.set_rollback(True)
        self.tx.__exit__(None, None, None)

    def payload(self, response, status=200):
        self.assertEqual(response.status_code, status, response.data)
        if status in {200, 201}:
            self.assertEqual({part.strip() for part in response["Cache-Control"].split(",")}, {"private", "no-store"})
        return response.data

    def publish(self, actor, data, status=201):
        return self.payload(actor.post(BASE, data, format="json"), status)["data"]

    def received(self, actor, announcement):
        rows = self.payload(actor.get(BASE + "/recues"))["data"]
        return next((row for row in rows if row["announcementId"] == announcement), None)

    def sent(self, actor):
        return self.payload(actor.get(BASE))["data"]

    def test_company_audience_replay_and_individual_read(self):
        manager = client(self.manager)
        recipient = client(self.a_person)
        outsider = client(self.b_manager)
        context = self.payload(manager.get(BASE + "/contexte"))["data"]
        self.assertTrue(context["canPublish"])
        self.assertEqual([row["id"] for row in context["companies"]], [self.a])
        data = draft()
        sent = self.publish(manager, data)
        self.assertEqual(sent["recipientCount"], 3)
        self.assertEqual(sent, self.publish(manager, data, 200))
        self.assertEqual(self.publish(manager, {**data, "title": "Autre titre"}, 409), None)

        notice = self.received(recipient, sent["id"])
        self.assertEqual(notice["title"], sent["title"])
        self.assertFalse(notice["read"])
        self.assertIsNone(self.received(outsider, sent["id"]))
        self.assertIsNone(self.received(client(self.disabled), sent["id"]))
        self.assertIsNotNone(self.received(client(self.platform, context=self.b), sent["id"]))
        self.assertNotIn(sent["id"], [row["id"] for row in self.sent(outsider)])

        url = f'{INBOX}/{notice["id"]}/read'
        self.payload(outsider.patch(url, {}, format="json"), 404)
        read = self.payload(recipient.patch(url, {}, format="json"))["data"]
        self.assertTrue(read["read"])
        self.assertTrue(read["readAt"])
        self.assertEqual(read, self.payload(recipient.patch(url, {}, format="json"))["data"])
        self.assertFalse(self.received(manager, sent["id"])["read"])
        self.assertEqual(self.sent(manager)[0]["readCount"], 1)
        unread = self.payload(recipient.get(BASE + "/recues?read=unread"))
        self.assertEqual(unread["data"], [])
        self.assertEqual(unread["meta"]["unreadCount"], 0)

        audit = db.query(
            '''SELECT "NewData" FROM systeme."T_Audit_Log"
               WHERE "TableName"='communication.T_Annonce' AND "Operation"='DIFFUSION'
               AND "NewData"->>'IdAnnonce'=%s''',
            [str(sent["id"])],
        )
        self.assertEqual(len(audit), 1)
        self.assertNotIn(sent["body"], str(audit))

    def test_platform_selection_all_and_atomic_failure(self):
        manager = client(self.manager)
        local = self.publish(manager, draft())
        platform = client(self.platform, context=self.b)
        selected = self.publish(platform, draft(self.b, self.a))
        self.assertEqual({item["id"] for item in selected["companies"]}, {self.a, self.b})
        self.assertIsNotNone(self.received(client(self.b_person), selected["id"]))
        self.assertNotIn(local["id"], [row["id"] for row in self.sent(platform)])
        self.assertNotIn(selected["id"], [row["id"] for row in self.sent(manager)])
        everywhere = self.publish(platform, draft(scope="all"))
        self.assertEqual(everywhere["scope"], "all")
        self.assertTrue({self.a, self.b}.issubset({item["id"] for item in everywhere["companies"]}))
        self.assertIsNotNone(self.received(client(self.b_person), everywhere["id"]))
        before = self.payload(platform.get(BASE))["meta"]["total"]
        for rejected in (self.empty, self.inactive):
            self.publish(platform, draft(self.a, rejected), 422)
        self.assertEqual(self.payload(platform.get(BASE))["meta"]["total"], before)

    def test_roles_module_and_read_only(self):
        self.payload(APIClient().get(BASE + "/contexte"), 401)
        person = client(self.a_person)
        context = self.payload(person.get(BASE + "/contexte"))["data"]
        self.assertEqual(context["companies"], [])
        self.assertFalse(context["canPublish"])
        self.assertFalse(context["canViewSent"])
        self.payload(person.get(BASE), 403)
        self.publish(person, draft(self.a), 403)
        manager = client(self.manager)
        self.publish(manager, draft(self.b), 403)
        self.publish(manager, draft(scope="all"), 403)
        self.publish(client(self.manager, manage=False), draft(self.a), 403)
        self.payload(client(self.manager, read=False).get(BASE + "/recues"), 403)
        self.payload(client(self.manager, read=False).get(INBOX))
        with override_settings(DB_READ_ONLY=True):
            self.publish(manager, draft(), 503)

    def test_new_membership_does_not_grant_previous_announcements(self):
        sent = self.publish(client(self.manager), draft())
        original = self.received(client(self.a_person), sent["id"])
        moved = db.one(
            '''UPDATE systeme."T_Utilisateurs" SET "IdEntiteFk"=%s
               WHERE "IdUser"=%s RETURNING *''',
            [self.b, self.a_person["IdUser"]],
        )
        receiver = client(moved)
        self.assertIsNone(self.received(receiver, sent["id"]))
        self.payload(receiver.patch(f'{INBOX}/{original["id"]}/read', {}, format="json"), 404)
        self.assertIsNone(self.received(client(user(self.a)), sent["id"]))

    def test_legacy_notifications_and_pagination(self):
        notice = db.one(
            '''INSERT INTO communication."T_Communication" ("IdUserFk", "ContenuCommunication")
               VALUES (%s, 'Notification historique') RETURNING "IdCommunication"''',
            [self.a_person["IdUser"]],
        )["IdCommunication"]
        receiver = client(self.a_person)
        self.assertEqual(self.payload(receiver.get(BASE + "/recues"))["data"], [])
        self.publish(client(self.manager), draft())
        first = self.payload(receiver.get(INBOX + "?pageSize=1"))
        self.assertEqual(first["meta"]["total"], 2)
        self.assertTrue(first["meta"]["hasNext"])
        second = self.payload(receiver.get(INBOX + "?pageSize=1&page=2"))
        self.assertTrue(second["meta"]["hasPrevious"])
        self.assertNotEqual(first["data"][0]["id"], second["data"][0]["id"])
        read = self.payload(receiver.patch(f"{INBOX}/{notice}/read", {}, format="json"))["data"]
        self.assertIsNone(read["announcementId"])
        self.assertIsNone(read["readAt"])
        self.assertEqual(read["body"], "Notification historique")


if __name__ == "__main__":
    unittest.main()
