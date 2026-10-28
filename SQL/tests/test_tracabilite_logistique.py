"""Règlements et intégrité SQL sur structure privée, sans données ni transport client.

SAUVERNDEKO_TEST_DATABASE_URL doit viser sauverndeko_test_* sur loopback.
Le scénario installe lui-même 20261028_03 après avoir créé des écritures
historiques fictives, pour contrôler leur conservation exacte.
"""
import json
import hashlib
import os
import secrets
import sys
import threading
import uuid
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone, timedelta
from decimal import Decimal
from pathlib import Path
from types import SimpleNamespace
from urllib.parse import urlsplit

import psycopg

ROOT = Path(__file__).resolve().parents[2]
DSN = os.environ.get("SAUVERNDEKO_TEST_DATABASE_URL", "")
url = urlsplit(DSN)
if url.scheme not in {"postgres", "postgresql"} or url.hostname not in {"localhost", "127.0.0.1"} or not url.path[1:].startswith("sauverndeko_test_"):
    raise RuntimeError("Base privee explicite sauverndeko_test_* sur loopback obligatoire, sans repli.")
with psycopg.connect(DSN) as guard:
    if not guard.execute("SELECT current_database()").fetchone()[0].startswith("sauverndeko_test_"):
        raise RuntimeError("Recette refusee hors base privee.")

os.environ.update(DJANGO_SETTINGS_MODULE="config.settings", DATABASE_URL=DSN,
                  SAUVERNDEKO_DB_READ_ONLY="0", DJANGO_SECRET_KEY=secrets.token_urlsafe(40),
                  JWT_SECRET=secrets.token_urlsafe(40), JWT_REFRESH_SECRET=secrets.token_urlsafe(40))
sys.path.insert(0, str(ROOT / "backend"))
import django
django.setup()
from django.db import DatabaseError, close_old_connections, transaction
from apps.accounts.authentication import actor_by_id
from apps.core import db, repository
from apps.core.responses import APIError
from apps.core.tenancy import bind_context
from apps.logistique import invoices, order_composer, payments

checks = []
tag = uuid.uuid4().hex[:8]


def check(value, label):
    assert value, label
    checks.append(label)


def insert(schema, table, values, pk):
    names = list(values)
    return db.one("INSERT INTO " + db.qualified(schema, table) + " (" + ",".join(map(db.ident, names)) + ") VALUES (" + ",".join(["%s"] * len(names)) + ") RETURNING " + db.ident(pk) + " AS id", list(values.values()))["id"]


def rejected(callback, label):
    try:
        with transaction.atomic():
            callback()
    except (DatabaseError, APIError):
        check(True, label)
    else:
        raise AssertionError(label + " accepte")


for category, label in [(34, "Unites"), (36, "Mode de paiement"), (40, "Categorie produit"), (42, "Devise"), (46, "Type produit"), (64, "Type de commande")]:
    db.query('INSERT INTO referentiel."T_CategorieGenerique"("ID_CategorieGenerique","NomCategorieGenerique","ValideCategorieGenerique") OVERRIDING SYSTEM VALUE VALUES(%s,%s,true) ON CONFLICT DO NOTHING', [category, label])


def generic(category, label, abbr):
    return insert("referentiel", "T_Generique", {"ID_CategorieGeneriqueFk": category, "NomGenerique": label, "AbrGenerique": abbr, "ValideGenerique": True}, "ID_Generique")


unit = generic(34, "Piece " + tag, "pcs")
mode = generic(36, "Virement fictif " + tag, "VIR")
category = generic(40, "Materiel fictif " + tag, "MAT")
kind = generic(46, "Type fictif " + tag, "TYPE")
currency = generic(42, "USD", "USD")
entry = generic(64, "Entree", "Entree")
outgoing = generic(64, "Sortie", "Sortie")
entity = insert("systeme", "T_Entite", {"NomEntite": "Entreprise fictive " + tag, "EmailEntite": tag + "@example.invalid", "ValideEntite": True}, "IdEntite")
other = insert("systeme", "T_Entite", {"NomEntite": "Autre entreprise fictive " + tag, "EmailEntite": tag + "b@example.invalid", "ValideEntite": True}, "IdEntite")
uid = insert("systeme", "T_Utilisateurs", {"NomUser": "Recette", "PrenomUser": "Traçabilite", "EmailUser": tag + "-a@example.invalid", "MotdepasseUser": "secret-fictif-inutilisable", "ValideUser": True, "SexeUser": "M", "Is_Admin": True}, "IdUser")
second_uid = insert("systeme", "T_Utilisateurs", {"NomUser": "Recette", "PrenomUser": "Second", "EmailUser": tag + "-b@example.invalid", "MotdepasseUser": "secret-fictif-inutilisable", "ValideUser": True, "SexeUser": "M", "Is_Admin": True}, "IdUser")


def actor():
    return bind_context(actor_by_id(uid), SimpleNamespace(headers={"X-Entite-ID": str(entity)}))


article_values = {"NomArticle": "Article fictif " + tag, "ID_TypeArticleFk": kind, "ID_CategorieArticleFk": category, "ID_UniteFk": unit, "ID_DeviseFk": currency, "QteArticle": "100", "PUArticle": "10", "PVArticle": "50", "CodeArticleInterne": "CODE-" + tag}
article = repository.mutate("T_Article", actor(), article_values)


def invoice():
    result = order_composer.compose_order(actor(), {"requestId": str(uuid.uuid4()), "bon": {"ID_TypeCmdFk": outgoing, "ID_DeviseFk": currency, "DateCmd": datetime.now(timezone.utc).isoformat()}, "lignes": [{"ID_ArticleFk": article["ID_Article"], "QteCmdDetail": "2", "PUCmdDetail": "50", "Lots": []}]})
    command = result["bon"]["ID_Commande"]
    info = invoices.context(actor(), command)
    issued = invoices.write_invoice(actor(), command, {"requestId": str(uuid.uuid4()), "_version": info["meta"]["revision"], "DateFacture": datetime.now(timezone.utc).isoformat(), "ID_ModePaiementFk": mode, "ID_ConditionPaiementFk": None, "DateEcheancePaiement": (datetime.now(timezone.utc)+timedelta(days=14)).isoformat()}, "issue")
    return command, issued["facture"]["CodeFacture"]


def direct_payment(code, amount):
    return insert("logistique", "T_Reglements", {"CodeFactureFk": code, "DateReglement": datetime.now(), "ID_ModeReglementFk": mode, "MontantRegle": amount, "ID_DeviseFk": currency}, "ID_Reglement")


before_migration = not db.one("SELECT EXISTS(SELECT FROM information_schema.columns WHERE table_schema='logistique' AND table_name='T_Reglements' AND column_name='CreeLe') yes")["yes"]
if not before_migration:
    raise RuntimeError("Scenario exige une structure privee avant migration 20261028_03.")
legacy_command, legacy_code = invoice()
legacy_id = direct_payment(legacy_code, "20")
db.query('INSERT INTO systeme."T_Audit_Log"("TableName","Operation","NewData","IdEntiteFk") VALUES(\'logistique.T_Reglements\',\'CREATE\',%s::jsonb,%s)', [json.dumps({"ID_Reglement": legacy_id, "_actor": {"IdUser": uid}}), entity])
overflow_command, overflow_code = invoice()
with transaction.atomic():
    db.query('ALTER TABLE logistique."T_Reglements" DISABLE TRIGGER reglement_apres_avoir')
    overflow_id = direct_payment(overflow_code, "130")
    db.query('ALTER TABLE logistique."T_Reglements" ENABLE TRIGGER reglement_apres_avoir')
before = db.query('SELECT to_jsonb(r) AS item FROM logistique."T_Reglements" r ORDER BY "ID_Reglement"')
old_audit = db.query('SELECT to_jsonb(a) AS item FROM systeme."T_Audit_Log" a ORDER BY "IdLog"')
with psycopg.connect(DSN, autocommit=True) as connection:
    connection.execute((ROOT / "SQL/migrations/20261028_03_tracabilite_logistique.sql").read_text(encoding="utf8"))
after = db.query('SELECT to_jsonb(r)-ARRAY[\'CreeParUserFk\',\'ModifieParUserFk\',\'CreeLe\',\'ModifieLe\'] AS item FROM logistique."T_Reglements" r ORDER BY "ID_Reglement"')
check(before == after, "Migration conserve exactement les anciennes valeurs de reglement")
check(old_audit == db.query('SELECT to_jsonb(a) AS item FROM systeme."T_Audit_Log" a ORDER BY "IdLog"'), "Migration conserve les journaux historiques")
check(db.one('SELECT bool_and("CreeLe" IS NULL AND "ModifieLe" IS NULL AND "CreeParUserFk" IS NULL AND "ModifieParUserFk" IS NULL) yes FROM logistique."T_Reglements"')["yes"], "Aucune date ou attribution historique inventee")
check(payments.snapshot(actor(), legacy_id)["creator"] == str(uid), "Createur historique prouve reste lisible depuis audit sans remplir artificiellement la colonne")


def payment_request(command, amount):
    data, meta = payments.preparation(actor(), command)
    return {"requestId": str(uuid.uuid4()), "_version": meta["revision"], "CodeFactureFk": data["defaults"]["CodeFactureFk"], "DateReglement": datetime.now().isoformat(timespec="seconds"), "ID_ModeReglementFk": mode, "MontantRegle": amount}


command, code = invoice()
request = payment_request(command, "30.00")
created = payments.mutate_payment(actor(), request)
pid = created["ID_Reglement"]
row = db.one('SELECT * FROM logistique."T_Reglements" WHERE "ID_Reglement"=%s', [pid])
check(row["CreeParUserFk"] == uid and row["ModifieParUserFk"] == uid and row["CreeLe"] and row["ModifieLe"], "API enregistre auteur et dates SQL")
check(payments.snapshot(actor(), pid)["creator"] == str(uid), "Consultation prefere le createur durable")
check(payments.mutate_payment(actor(), request)["replayed"] is True, "Rejeu API renvoie le meme paiement")
counts = db.one('''SELECT count(*) FILTER(WHERE "Operation"='CREATE') detail,count(*) FILTER(WHERE "Operation"='PAYMENT_CREATE') proof FROM systeme."T_Audit_Log" WHERE "TableName"='logistique.T_Reglements' AND "NewData"->>'ID_Reglement'=%s''', [str(pid)])
check(counts["detail"] == 1 and counts["proof"] == 1, "Un audit SQL detail et une preuve idempotente, sans doublon")
rejected(lambda: db.query('UPDATE logistique."T_Reglements" SET "CreeParUserFk"=%s WHERE "ID_Reglement"=%s', [second_uid, pid]), "Auteur de creation immuable en SQL")
rejected(lambda: db.query('UPDATE logistique."T_Reglements" SET "CreeLe"=clock_timestamp() WHERE "ID_Reglement"=%s', [pid]), "Date technique de creation immuable")
rejected(lambda: db.query('UPDATE logistique."T_Reglements" SET "CodeFactureFk"=%s WHERE "ID_Reglement"=%s', [legacy_code, pid]), "Facture parent immuable")
rejected(lambda: db.query('UPDATE logistique."T_Reglements" SET "ID_ClientFk"=42 WHERE "ID_Reglement"=%s', [pid]), "Identite du tiers historique immuable")
rejected(lambda: db.query('UPDATE logistique."T_Reglements" SET "MontantRegle"=101 WHERE "ID_Reglement"=%s', [pid]), "UPDATE direct ne peut pas depasser le solde")
rejected(lambda: direct_payment(code, "71"), "INSERT direct ne peut pas depasser le solde")
rejected(lambda: db.query('UPDATE logistique."T_Reglements" SET "MontantRegle"=0 WHERE "ID_Reglement"=%s', [pid]), "Montant nul refuse")
rejected(lambda: db.query('UPDATE logistique."T_Reglements" SET "DateReglement"=NULL WHERE "ID_Reglement"=%s', [pid]), "Date metier requise")
with transaction.atomic():
    db.query("SELECT set_config('systeme.actor_user_id',%s,true)", [str(second_uid)])
    db.query('UPDATE logistique."T_Reglements" SET "MontantRegle"=35 WHERE "ID_Reglement"=%s', [pid])
changed = db.one('SELECT * FROM logistique."T_Reglements" WHERE "ID_Reglement"=%s', [pid])
check(changed["CreeParUserFk"] == uid and changed["CreeLe"] == row["CreeLe"] and changed["ModifieParUserFk"] == second_uid and changed["ModifieLe"] > row["ModifieLe"], "Modification SQL conserve origine et attribue le dernier auteur")
check(db.one('SELECT "IdEntiteFk" company FROM systeme."T_Audit_Log" WHERE "TableName"=\'logistique.T_Reglements\' AND "Operation"=\'UPDATE\' AND "NewData"->>\'ID_Reglement\'=%s ORDER BY "IdLog" DESC LIMIT 1', [str(pid)])["company"] == entity, "Audit du paiement rattache a son entreprise proprietaire")
db.query('UPDATE logistique."T_Reglements" SET "MontantRegle"=120 WHERE "ID_Reglement"=%s', [overflow_id])
check(db.one('SELECT "MontantRegle" amount FROM logistique."T_Reglements" WHERE "ID_Reglement"=%s', [overflow_id])["amount"] == Decimal("120"), "Excedent historique peut diminuer sans etre encore entierement corrige")
rejected(lambda: db.query('UPDATE logistique."T_Reglements" SET "MontantRegle"=125 WHERE "ID_Reglement"=%s', [overflow_id]), "Excedent historique ne peut augmenter")

gate = threading.Barrier(2)


def competing(index):
    with psycopg.connect(DSN, autocommit=True, options="-c lock_timeout=5000 -c statement_timeout=10000") as connection:
        gate.wait()
        try:
            connection.execute('INSERT INTO logistique."T_Reglements"("CodeFactureFk","DateReglement","ID_ModeReglementFk","MontantRegle","ID_DeviseFk") VALUES(%s,LOCALTIMESTAMP,%s,65,%s)', [code, mode, currency])
            return "ok"
        except psycopg.errors.CheckViolation:
            return "rejected"


with ThreadPoolExecutor(2) as workers:
    outcomes = list(workers.map(competing, [0, 1]))
check(sorted(outcomes) == ["ok", "rejected"], "Deux encaissements SQL concurrents : un seul solde encaisse")
check(db.one('SELECT sum("MontantRegle") amount FROM logistique."T_Reglements" WHERE "CodeFactureFk"=%s', [code])["amount"] == Decimal("100"), "Total concurrent ne depasse pas la facture")

editable_command, editable_code = invoice()
editable = payments.mutate_payment(actor(), payment_request(editable_command, "20"))
editable_id = editable["ID_Reglement"]
update_request = {"requestId": str(uuid.uuid4()), "_version": payments.revision(payments.snapshot(actor(), editable_id)), "MontantRegle": "25"}
updated = payments.mutate_payment(actor(), update_request, {"ID_Reglement": editable_id}, "update")
check(updated["MontantRegle"] == Decimal("25"), "Modification API applique le montant exact")
check(payments.mutate_payment(actor(), update_request, {"ID_Reglement": editable_id}, "update")["replayed"], "Rejeu modification API sans deuxieme ecriture")
check(db.one('SELECT count(*) n FROM systeme."T_Audit_Log" WHERE "TableName"=\'logistique.T_Reglements\' AND "Operation"=\'UPDATE\' AND "NewData"->>\'ID_Reglement\'=%s', [str(editable_id)])["n"] == 1, "Une seule image SQL pour modification API")
delete_request = {"requestId": str(uuid.uuid4()), "_version": payments.revision(payments.snapshot(actor(), editable_id))}
check(payments.mutate_payment(actor(), delete_request, {"ID_Reglement": editable_id}, "delete")["deleted"], "Suppression autorisee conserve sa preuve")
check(payments.mutate_payment(actor(), delete_request, {"ID_Reglement": editable_id}, "delete")["replayed"], "Rejeu suppression API reconnu apres disparition de ligne")
check(db.one('SELECT count(*) n FROM systeme."T_Audit_Log" WHERE "TableName"=\'logistique.T_Reglements\' AND "Operation"=\'DELETE\' AND "OldData"->>\'ID_Reglement\'=%s', [str(editable_id)])["n"] == 1, "Une seule image SQL pour suppression API")

batch_command, batch_code = invoice()
second_mode = generic(36, "Especes fictives " + tag, "ESP")
_, batch_meta = payments.preparation(actor(), batch_command)
batch_request = {"requestId": str(uuid.uuid4()), "reglements": [{"commandeId": batch_command, "_version": batch_meta["revision"], "ID_ModeReglementFk": payment_mode, "DateReglement": datetime.now().isoformat(timespec="seconds"), "MontantRegle": amount} for payment_mode, amount in [(mode, "30"), (second_mode, "20")]]}
batch = payments.mutate_payment_batch(actor(), batch_request)
check(len(batch["reglements"]) == 2 and all(item["CreeParUserFk"] == uid for item in batch["reglements"]), "Panier attribue chaque creation au meme acteur SQL")
check(payments.mutate_payment_batch(actor(), batch_request)["replayed"], "Panier rejoue sans nouveau paiement")
check(db.one('SELECT count(*) n FROM logistique."T_Reglements" WHERE "CodeFactureFk"=%s', [batch_code])["n"] == 2, "Panier conserve seulement ses deux lignes")

other_actor = bind_context(actor_by_id(uid), SimpleNamespace(headers={"X-Entite-ID": str(other)}))
same_code_other = repository.mutate("T_Article", other_actor, {**article_values, "QteArticle": "0"})
check(same_code_other["IdEntiteFk"] == other, "Deux entreprises peuvent employer le meme code interne")
rejected(lambda: repository.mutate("T_Article", actor(), {**article_values, "QteArticle": "0"}), "Doublon du code interne dans une entreprise refuse")
new_command, new_code = invoice()
numbers = db.query('SELECT "TableName","IdEntiteFk" company FROM systeme."T_Audit_Log" WHERE "Operation"=\'DOCUMENT_NUMBER\' AND (("TableName"=\'logistique.T_Commande\' AND "NewData"->>\'ID_Commande\'=%s) OR ("TableName"=\'logistique.T_Facture\' AND "NewData"->>\'ID_CommandeFk\'=%s))', [str(new_command), str(new_command)])
check(len(numbers) == 2 and all(item["company"] == entity for item in numbers), "Bons et factures audites avec leur entreprise, meme si createur global sans entreprise")

content = b"%PDF-1.4\n%FICTIF RECETTE\n"
attachment = {"TypeObjet": "bon", "ID_Objet": new_command, "IdEntiteFk": entity, "ID_UserFk": uid,
              "NomFichier": "preuve-fictive.pdf", "MimeType": "application/pdf", "TailleOctets": len(content),
              "Sha256": hashlib.sha256(content).hexdigest(), "Contenu": content}
piece = insert("logistique", "T_PieceJustificative", attachment, "ID_Piece")
check(piece is not None, "Justificatif conserve son contenu et son empreinte concordante")
try:
    with transaction.atomic():
        insert("logistique", "T_PieceJustificative", {**attachment, "Sha256": "0" * 64}, "ID_Piece")
except DatabaseError as error:
    check(getattr(getattr(error, "__cause__", None), "diag", None).constraint_name == "ck_piece_sha256_contenu", "SQL refuse une empreinte ne correspondant pas au contenu")
else:
    raise AssertionError("Justificatif falsifie accepte")
print(json.dumps({"success": True, "checks": len(checks), "scenarios": checks, "database": url.path[1:]}, ensure_ascii=True))
