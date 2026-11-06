"""Recette des discussions sur une copie PostgreSQL privée."""

import unittest
from uuid import uuid4

import test_publication_articles_api  # Initialise Django après contrôle du DSN privé.
from django.db import IntegrityError, transaction
from django.test import override_settings
from rest_framework.test import APIClient

from apps.accounts.authentication import actor_by_id
from apps.core import db

BASE = "/api/discussions"


class DiscussionsAPI(unittest.TestCase):
    def setUp(self):
        self.enterContext(override_settings(ALLOWED_HOSTS=["testserver"]))
        tx = transaction.atomic()
        tx.__enter__()
        self.addCleanup(tx.__exit__, None, None, None)
        self.addCleanup(transaction.set_rollback, True)
        self.first_entity = self.entity()
        self.second_entity = self.entity()
        self.first = self.account("Élodie", self.first_entity)
        self.second = self.account("Éric", self.first_entity)
        self.local_admin = self.account("Gestion", self.first_entity, admin=True)
        self.outsider = self.account("Autre", self.second_entity)
        self.global_admin = self.account("Plateforme", None, platform=True)
        self.inactive = self.account("Inactif", self.first_entity, active=False)

    @staticmethod
    def entity():
        return db.one(
            '''INSERT INTO systeme."T_Entite" ("NomEntite","EmailEntite","ValideEntite")
               VALUES (%s,%s,true) RETURNING "IdEntite"''',
            [f"Communication test {uuid4()}", f"{uuid4()}@example.invalid"],
        )["IdEntite"]

    @staticmethod
    def account(name, entity, *, active=True, admin=False, platform=False):
        return db.one(
            '''INSERT INTO systeme."T_Utilisateurs"
               ("PrenomUser","NomUser","EmailUser","MotdepasseUser","ValideUser","IdEntiteFk","Is_staff","Is_Admin","SexeUser")
               VALUES (%s,'Recette',%s,'inutilisable',%s,%s,%s,%s,'M') RETURNING "IdUser"''',
            [name, f"{uuid4()}@example.invalid", active, entity, admin, platform],
        )["IdUser"]

    @staticmethod
    def client(user, *, context=None):
        actor = actor_by_id(user)
        if context is not None:
            actor._context_entity = context
        client = APIClient()
        client.force_authenticate(actor)
        return client

    def payload(self, response, status=200):
        self.assertEqual(response.status_code, status, response.json().get("message"))
        return response.json()

    def start(self, actor=None, target=None, *, status=201, context=None):
        return self.payload(self.client(actor or self.first, context=context).post(
            BASE + "/start", {"type": "user", "targetId": target or self.second}, format="json",
        ), status)["data"]

    def test_contacts_show_only_active_coworkers(self):
        url = BASE + "/contacts"
        result = self.payload(self.client(self.first).get(url, {"q": "éric"}))
        self.assertEqual(result["data"], [{"type": "user", "id": self.second, "fullName": "Éric Recette", "name": "Éric Recette"}])
        self.assertEqual(self.payload(self.client(self.first).get(url, {"q": "Inactif"}))["data"], [])
        self.assertEqual(self.payload(self.client(self.first).get(url, {"q": "Autre"}))["data"], [])
        self.assertEqual(self.payload(self.client(self.global_admin, context=self.first_entity).get(url))["data"], [])

    def test_direct_thread_is_bidirectional_and_private(self):
        created = self.start()
        thread = created["IdDiscussion"]
        self.assertEqual(created["recipient"]["id"], self.second)
        reverse = self.start(self.second, self.first, status=200)
        self.assertEqual(reverse["IdDiscussion"], thread)
        self.assertEqual(reverse["recipient"]["id"], self.first)
        self.start(target=self.first, status=400)
        self.start(target=self.inactive, status=404)
        self.start(target=self.outsider, status=404)
        self.start(self.global_admin, self.first, status=404, context=self.first_entity)
        for user in (self.outsider, self.local_admin, self.global_admin):
            client = self.client(user, context=self.first_entity if user == self.global_admin else None)
            self.assertEqual(self.payload(client.get(BASE))["data"], [])
            self.payload(client.get(f"{BASE}/{thread}/messages"), 404)
            self.payload(client.post(f"{BASE}/{thread}/messages", {"message": "Refus"}, format="json"), 404)
        admin = self.client(self.global_admin)
        self.payload(admin.get("/api/views/communication/V_Chat"), 404)
        self.payload(admin.get("/api/views/communication/V_Communication"), 404)
        self.assertFalse(any(row["schema"] == "communication" for row in self.payload(admin.get("/api/views"))["data"]))

    def test_send_replay_latest_page_and_search(self):
        thread = self.start()["IdDiscussion"]
        sender, receiver = self.client(self.first), self.client(self.second)
        path = f"{BASE}/{thread}/messages"
        request_id = str(uuid4())
        body = {"message": " Un ", "requestId": request_id}
        sent = self.payload(sender.post(path, body, format="json"), 201)["data"]
        replay = self.payload(sender.post(path, body, format="json"))["data"]
        self.assertEqual(sent["IdChat"], replay["IdChat"])
        self.payload(sender.post(path, {**body, "message": "Autre"}, format="json"), 409)
        self.payload(receiver.post(path, {"message": "Deux"}, format="json"), 201)
        self.payload(sender.post(path, {"message": "Trois"}, format="json"), 201)
        latest = self.payload(receiver.get(path, {"take": 2}))
        self.assertEqual([row["TextChat"] for row in latest["data"]], ["Deux", "Trois"])
        self.assertTrue(latest["meta"]["hasPrevious"])
        self.assertTrue(latest["meta"]["canSend"])
        self.assertEqual(latest["meta"]["discussion"]["lastMessage"]["TextChat"], "Trois")
        older = self.payload(receiver.get(path, {"take": 2, "before": latest["meta"]["nextBefore"]}))
        self.assertEqual([row["TextChat"] for row in older["data"]], ["Un"])
        self.assertFalse(older["meta"]["hasPrevious"])
        found = self.payload(receiver.get(BASE, {"q": "élodie", "take": 1}))
        self.assertEqual(found["data"][0]["IdDiscussion"], thread)
        self.assertFalse(found["meta"]["hasNext"])

    def test_company_transfer_closes_replies_without_erasing_history(self):
        thread = self.start()["IdDiscussion"]
        path = f"{BASE}/{thread}/messages"
        self.payload(self.client(self.first).post(path, {"message": "Historique"}, format="json"), 201)
        db.query('UPDATE systeme."T_Utilisateurs" SET "IdEntiteFk"=%s WHERE "IdUser"=%s', [self.second_entity, self.second])
        self.payload(self.client(self.second).get(path), 404)
        result = self.payload(self.client(self.first).get(path))
        self.assertEqual([row["TextChat"] for row in result["data"]], ["Historique"])
        self.assertFalse(result["meta"]["canSend"])
        self.payload(self.client(self.first).post(path, {"message": "Refus"}, format="json"), 409)

    def test_unread_filter_reads_exact_messages_and_preserves_legacy_history(self):
        thread = self.start()["IdDiscussion"]
        sender, receiver = self.client(self.first), self.client(self.second)
        messages = f"{BASE}/{thread}/messages"
        read = f"{BASE}/{thread}/lecture"
        historical = db.one(
            '''INSERT INTO communication."T_Chat"
               ("IdDiscussionFk","AuthorIdFk","TextChat","SuiviLectureChat","LuChat")
               VALUES (%s,%s,'Ancien',false,true) RETURNING "IdChat"''',
            [thread, self.first],
        )["IdChat"]
        first = self.payload(sender.post(messages, {"message": "Premier"}, format="json"), 201)["data"]
        own = self.payload(receiver.post(messages, {"message": "Réponse"}, format="json"), 201)["data"]
        second = self.payload(sender.post(messages, {"message": "Deuxième"}, format="json"), 201)["data"]
        self.assertFalse(first["unread"])
        history = self.payload(receiver.get(messages))
        self.assertTrue(history["meta"]["canMarkRead"])
        self.assertEqual(
            {row["IdChat"]: row["unread"] for row in history["data"]},
            {historical: False, first["IdChat"]: True, own["IdChat"]: False, second["IdChat"]: True},
        )
        self.assertEqual(next(row for row in history["data"] if row["IdChat"] == historical)["LuChat"], True)
        self.assertEqual(self.payload(receiver.get(BASE, {"unread": "1", "q": "Élodie"}))["data"][0]["unreadCount"], 2)
        self.assertEqual(self.payload(receiver.get(BASE, {"unread": "1", "q": "introuvable"}))["data"], [])
        self.assertEqual(self.payload(sender.get(BASE))["data"][0]["unreadCount"], 1)
        batch = {"messageIds": [historical, first["IdChat"], own["IdChat"], first["IdChat"]]}
        self.assertEqual(self.payload(receiver.post(read, batch, format="json"))["data"],
                         {"markedCount": 1, "unreadCount": 1})
        self.assertEqual(self.payload(receiver.post(read, batch, format="json"))["data"],
                         {"markedCount": 0, "unreadCount": 1})
        self.assertEqual(self.payload(receiver.post(read, {"messageIds": [second["IdChat"]]}, format="json"))["data"],
                         {"markedCount": 1, "unreadCount": 0})
        self.assertEqual(self.payload(receiver.get(BASE, {"unread": "1"}))["data"], [])
        self.assertEqual(self.payload(receiver.get(BASE))["data"][0]["unreadCount"], 0)
        self.assertEqual(self.payload(sender.get(BASE))["data"][0]["unreadCount"], 1)

    def test_read_lot_refuses_out_of_scope_and_invalid_payload_without_partial_write(self):
        first_thread = self.start()["IdDiscussion"]
        other_thread = self.start(target=self.local_admin)["IdDiscussion"]
        read = f"{BASE}/{first_thread}/lecture"
        first_id, other_id = [
            self.payload(self.client(self.first).post(
                f"{BASE}/{thread}/messages", {"message": "Message réservé"}, format="json",
            ), 201)["data"]["IdChat"]
            for thread in (first_thread, other_thread)
        ]
        receiver = self.client(self.second)
        for body in ({}, {"messageIds": []}, {"messageIds": [True]}, {"messageIds": [first_id] * 101}):
            self.payload(receiver.post(read, body, format="json"), 400)
        self.payload(receiver.post(read, {"messageIds": [first_id, other_id]}, format="json"), 404)
        self.payload(APIClient().post(read, {"messageIds": [first_id]}, format="json"), 401)
        for user in (self.local_admin, self.outsider, self.global_admin):
            self.payload(self.client(user).post(read, {"messageIds": [first_id]}, format="json"), 404)
        self.assertEqual(self.payload(receiver.get(BASE))["data"][0]["unreadCount"], 1)
        db.query('UPDATE systeme."T_Utilisateurs" SET "IdEntiteFk"=%s WHERE "IdUser"=%s',
                 [self.second_entity, self.second])
        self.payload(self.client(self.second).post(read, {"messageIds": [first_id]}, format="json"), 404)

    def test_read_does_not_require_send_permission_and_honors_read_only(self):
        thread = self.start()["IdDiscussion"]
        messages = f"{BASE}/{thread}/messages"
        read = f"{BASE}/{thread}/lecture"
        received = self.payload(self.client(self.first).post(
            messages, {"message": "À lire"}, format="json",
        ), 201)["data"]["IdChat"]
        role = db.one(
            '''SELECT g."ID_Generique" FROM referentiel."T_Generique" g
               JOIN referentiel."T_CategorieGenerique" c ON c."ID_CategorieGenerique"=g."ID_CategorieGeneriqueFk"
               WHERE c."NomCategorieGenerique"='Role' AND g."ValideGenerique" IS TRUE
               ORDER BY g."ID_Generique" LIMIT 1'''
        )["ID_Generique"]
        db.query('UPDATE systeme."T_Utilisateurs" SET "IdRoleFk"=%s WHERE "IdUser"=%s', [role, self.second])
        db.query(
            '''INSERT INTO systeme."T_RoleModule"
               ("IdEntiteFk","IdRoleFk","CodeModule","PeutConsulter","PeutGerer","PeutExporter","Actif")
               VALUES (%s,%s,'discussions',true,false,false,true)''',
            [self.first_entity, role],
        )
        receiver = self.client(self.second)
        self.assertFalse(self.payload(receiver.get(messages))["meta"]["canSend"])
        self.payload(receiver.post(messages, {"message": "Non autorisé"}, format="json"), 403)
        with override_settings(DB_READ_ONLY=True):
            self.assertFalse(self.payload(self.client(self.second).get(messages))["meta"]["canMarkRead"])
            self.payload(receiver.post(read, {"messageIds": [received]}, format="json"), 503)
        self.assertEqual(self.payload(receiver.post(read, {"messageIds": [received]}, format="json"))["data"],
                         {"markedCount": 1, "unreadCount": 0})
        db.query(
            '''UPDATE systeme."T_RoleModule" SET "PeutConsulter"=false
               WHERE "IdEntiteFk"=%s AND "IdRoleFk"=%s AND "CodeModule"='discussions' ''',
            [self.first_entity, role],
        )
        self.payload(self.client(self.second).post(read, {"messageIds": [received]}, format="json"), 403)

    def test_shared_structure_retains_one_read_state_per_user(self):
        other_admin = self.account("Deuxième gestion", self.first_entity, admin=True)
        thread = db.one(
            '''INSERT INTO communication."T_Discussion"
               ("IdUserClientFk","IdEntiteFk","TypeDiscussion")
               VALUES (%s,%s,'structure') RETURNING "IdDiscussion"''',
            [self.outsider, self.first_entity],
        )["IdDiscussion"]
        messages = f"{BASE}/{thread}/messages"
        read = f"{BASE}/{thread}/lecture"
        received = self.payload(self.client(self.outsider).post(
            messages, {"message": "Reçu dans une structure"}, format="json",
        ), 201)["data"]["IdChat"]
        local = self.client(self.local_admin)
        other = self.client(other_admin)
        self.assertEqual(self.payload(local.post(read, {"messageIds": [received]}, format="json"))["data"],
                         {"markedCount": 1, "unreadCount": 0})
        self.assertFalse(self.payload(local.get(messages))["data"][0]["unread"])
        self.assertTrue(self.payload(other.get(messages))["data"][0]["unread"])
        self.payload(self.client(self.first).post(read, {"messageIds": [received]}, format="json"), 404)
        self.assertEqual(self.payload(other.post(read, {"messageIds": [received]}, format="json"))["data"],
                         {"markedCount": 1, "unreadCount": 0})

    def test_postgresql_blocks_direct_cross_company_insert(self):
        with self.assertRaises(IntegrityError), transaction.atomic():
            db.query(
                '''INSERT INTO communication."T_Discussion"
                   ("IdUserClientFk","IdUserDestinataireFk","IdEntiteFk","TypeDiscussion")
                   VALUES (%s,%s,%s,'user')''',
                [self.first, self.outsider, self.first_entity],
            )


if __name__ == "__main__":
    unittest.main()
