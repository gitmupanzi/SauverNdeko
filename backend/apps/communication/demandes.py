"""Intentions suivies depuis une fiche publiée ; aucune réservation ou vente implicite."""
import re
from decimal import Decimal
from uuid import UUID

from django.conf import settings
from django.db import DatabaseError, transaction
from rest_framework.views import APIView

from apps.core import db
from apps.core.module_access import access_snapshot, require_module
from apps.core.permissions import HasModuleAccess
from apps.core.repository import page, positive
from apps.core.responses import APIError
from .notifications import private_response

SOURCES = {"product": "produits", "expert": "professionnels", "structure_n3": "structures",
           "structure_n4": "structures", "structure_n5": "structures"}
ERRORS = {
    "PDE01": ("Cette fiche n’est plus disponible dans l’annuaire.", "SOURCE_UNAVAILABLE", 404),
    "PDE02": ("Vous ne pouvez pas effectuer cette action sur cette demande.", "DEMANDE_FORBIDDEN", 403),
    "PDE03": ("L’opération ne correspond plus à l’état du dossier ou à son destinataire. Rechargez la fiche.", "DEMANDE_CONFLICT", 409),
    "PDE04": ("Vérifiez les informations saisies, la quantité et le motif demandé.", "DEMANDE_INVALID", 422),
    "PDE05": ("Cette fiche a été modifiée. Rechargez-la avant de poursuivre.", "STALE_VERSION", 409),
}


def source_key(params):
    kind = params.get("sourceType")
    if not isinstance(kind, str) or kind not in SOURCES:
        raise APIError("Choisissez une fiche produit, professionnel ou structure publiée.", "SOURCE_INVALID", 422)
    return kind, positive(params.get("sourceId"), "Fiche d’origine")


def query_options(params, allowed):
    if set(params) - set(allowed) or any(len(params.getlist(key)) != 1 for key in params):
        raise APIError("Les critères de recherche sont invalides.", "QUERY_INVALID", 422)


def request_key(value):
    try:
        if isinstance(value, str):
            return str(UUID(value))
    except (ValueError, AttributeError):
        pass
    raise APIError("Identifiant de l’opération invalide.", "REQUEST_ID_INVALID", 422)


def version(value):
    if type(value) is not int or value < 0:
        raise APIError("Rechargez la fiche pour obtenir sa version.", "VERSION_REQUIRED", 422)
    return value


def text(value, label, limit, optional=False):
    if optional and value in (None, ""):
        return ""
    if not isinstance(value, str) or "\0" in value or len(value.strip()) > limit or not value.strip():
        raise APIError(f"{label} : indiquez de 1 à {limit} caractères.", "DEMANDE_INVALID", 422)
    try:
        value.encode("utf8")
    except UnicodeEncodeError:
        raise APIError(f"{label} contient un caractère invalide.", "DEMANDE_INVALID", 422) from None
    return value.strip()


def payload(request, keys):
    data = request.data
    if not isinstance(data, dict) or set(data) - set(keys):
        raise APIError("Les informations de cette opération sont invalides.", "DEMANDE_INVALID", 422)
    return data


def mutate(sql, values):
    db.ensure_writable()
    try:
        with transaction.atomic():
            return db.one(sql, values)
    except DatabaseError as exc:
        state = getattr(exc.__cause__, "sqlstate", None)
        if state in ERRORS:
            message, code, status = ERRORS[state]
            raise APIError(message, code, status) from None
        raise


def states():
    return db.query('''SELECT g."NomGenerique" AS id,g."AbrGenerique" AS label
      FROM referentiel."T_Generique" g JOIN referentiel."T_CategorieGenerique" c
       ON c."ID_CategorieGenerique"=g."ID_CategorieGeneriqueFk"
      WHERE c."NomCategorieGenerique"='État demande suivie' AND c."IdEntiteFk" IS NULL
       AND g."NomGenerique" IN ('en_attente','en_cours','satisfaite','non_satisfaite','annulee')
      ORDER BY CASE g."NomGenerique" WHEN 'en_attente' THEN 1 WHEN 'en_cours' THEN 2
        WHEN 'satisfaite' THEN 3 WHEN 'non_satisfaite' THEN 4 ELSE 5 END''')


def receiver(actor, row):
    return row["IdDestinataireUserFk"] == actor.pk or db.one(
        'SELECT communication.fn_demande_gestionnaire(%s,%s) AS allowed',
        [actor.pk, row["IdEntiteDestinataireFk"]],
    )["allowed"]


def record(row, actor, *, labels=None, manage=None, managed_entity=None):
    actions = []
    active = row["EtatDemande"] in {"en_attente", "en_cours"}
    if manage is None:
        manage = not settings.DB_READ_ONLY and access_snapshot(actor)["modules"]["discussions"]["canManage"]
    if labels is None:
        labels = {s["id"]: s["label"] for s in states()}
    if active and manage:
        if row["IdDemandeurFk"] == actor.pk:
            if row["EtatDemande"] == "en_cours":
                actions.append({"key": "satisfaite", "label": "Confirmer la satisfaction", "requiresReason": True})
            actions.extend([
                {"key": "non_satisfaite", "label": "Signaler une demande non satisfaite", "requiresReason": True},
                {"key": "annulee", "label": "Annuler la demande", "requiresReason": True},
            ])
        is_receiver = (row["IdDestinataireUserFk"] == actor.pk or
                       (row["IdEntiteDestinataireFk"] is not None and row["IdEntiteDestinataireFk"] == managed_entity)) if managed_entity is not None else receiver(actor, row)
        if is_receiver:
            if row["EtatDemande"] == "en_attente":
                actions.insert(0, {"key": "en_cours", "label": "Prendre en charge", "requiresReason": False})
            if not any(a["key"] == "non_satisfaite" for a in actions):
                actions.append({"key": "non_satisfaite", "label": "Indiquer que la demande ne peut pas être satisfaite", "requiresReason": True})
    return {
        "id": row["IdDemande"], "code": row["CodeDemande"], "subject": row["SujetDemande"],
        "description": row["DescriptionDemande"], "state": row["EtatDemande"],
        "stateLabel": labels.get(row["EtatDemande"]) or row["LibelleEtat"], "version": row["VersionDemande"],
        "source": {"type": row["TypeSource"], "id": row["IdSource"], "label": row["LibelleSource"]},
        "requester": {"id": row["IdDemandeurFk"], "name": row["NomDemandeur"]},
        "recipient": {"kind": "user" if row["IdDestinataireUserFk"] else "entity",
                      "id": row["IdDestinataireUserFk"] or row["IdEntiteDestinataireFk"], "name": row["NomDestinataire"]},
        "quantity": format(row["QuantiteSouhaitee"], "f") if row["QuantiteSouhaitee"] is not None else None,
        "unit": row["UniteSouhaitee"], "destination": row["DestinationDemande"],
        "createdAt": row["CreeLe"], "updatedAt": row["ModifieLe"], "discussionId": row["IdDiscussion"],
        "actions": actions, "canOpenDiscussion": bool(row["IdDiscussion"]) or manage,
    }


def dossier(actor, pk):
    row = db.one('''SELECT d.* FROM communication."V_Demande" d WHERE d."IdDemande"=%s
      AND communication.fn_demande_participant(%s,d."IdDemande")''', [pk, actor.pk])
    if not row:
        raise APIError("Demande introuvable dans vos échanges.", "NOT_FOUND", 404)
    history = db.query('''SELECT h."IdHistorique" AS id,h."ActionDemande" AS action,
      h."EtatAvant" AS "fromState",h."EtatApres" AS "toState",h."MotifDemande" AS reason,
      h."CreeLe" AS "createdAt",btrim(concat_ws(' ',u."PrenomUser",u."NomUser")) AS "actorName"
      FROM communication."T_DemandeHistorique" h JOIN systeme."T_Utilisateurs" u ON u."IdUser"=h."IdAuteurFk"
      WHERE h."IdDemandeFk"=%s ORDER BY h."IdHistorique"''', [pk])
    return {"record": record(row, actor), "history": history}


class SourceContextView(APIView):
    permission_classes = [HasModuleAccess]
    http_method_names = ["get", "head", "options"]

    def get(self, request):
        query_options(request.query_params, {"sourceType", "sourceId"})
        kind, pk = source_key(request.query_params)
        require_module(request.user, SOURCES[kind])
        source = db.one('SELECT communication.fn_demande_source(%s,%s) AS source', [kind, pk])["source"]
        if not source:
            raise APIError("Cette fiche n’est plus publiée.", "SOURCE_UNAVAILABLE", 404)
        actor = request.user
        target = source.get("userId") or source.get("entityId")
        is_user = source.get("userId") is not None
        recipient = {"kind": "user" if is_user else "entity", "id": target, "name": source.get("recipientName")} if target else None
        if is_user:
            available = target != actor.pk and db.one('SELECT communication.fn_demande_compte_autorise(%s,false) AS allowed', [target])["allowed"]
        else:
            available = bool(target) and db.one('''SELECT EXISTS(SELECT FROM systeme."T_Utilisateurs" u
              WHERE communication.fn_demande_gestionnaire(u."IdUser",%s)) AS allowed''', [target])["allowed"]
        can_manage = access_snapshot(actor)["modules"]["discussions"]["canManage"] and not settings.DB_READ_ONLY
        can_route = kind.startswith("structure_") and actor.global_admin and can_manage
        routing = db.one('''SELECT "VersionRoutage" AS version,CASE WHEN "Actif" THEN "IdEntiteFk" END AS "entityId"
          FROM communication."T_RoutageStructure" WHERE "TypeSource"=%s AND "IdSource"=%s''', [kind, pk])
        entities = db.query('''SELECT e."IdEntite" AS id,e."NomEntite" AS label FROM systeme."T_Entite" e
          WHERE e."ValideEntite" IS TRUE AND EXISTS (SELECT FROM systeme."T_Utilisateurs" u
           WHERE communication.fn_demande_gestionnaire(u."IdUser",e."IdEntite"))
          ORDER BY e."NomEntite",e."IdEntite"''') if can_route else []
        reason = "" if available and can_manage else (
            "Cette structure n’a pas encore de destinataire vérifié." if not target else
            "Ce destinataire ne peut pas recevoir de demande pour le moment." if not available else
            "Votre accès actuel ne permet pas d’envoyer une demande.")
        return private_response({"source": {"type": kind, "id": pk, "label": source["label"],
            "unit": source.get("unit"), "quantityDecimals": source.get("quantityDecimals")},
            "recipient": recipient, "canCreate": bool(available and can_manage), "unavailableReason": reason,
            "canConfigureRouting": bool(can_route), "routing": routing or {"version": 0, "entityId": None}, "entities": entities})


class DemandesView(APIView):
    permission_classes = [HasModuleAccess]
    http_method_names = ["get", "post", "head", "options"]

    def get(self, request):
        query_options(request.query_params, {"direction", "state", "search", "take", "skip"})
        actor = request.user
        direction = request.query_params.get("direction", "sent")
        if direction not in {"sent", "received"}:
            raise APIError("Choisissez les demandes envoyées ou reçues.")
        where = 'communication.fn_demande_participant(%s,d."IdDemande")'
        values = [actor.pk]
        if direction == "sent":
            where += ' AND d."IdDemandeurFk"=%s'
            values.append(actor.pk)
        else:
            where += ' AND (d."IdDestinataireUserFk"=%s OR communication.fn_demande_gestionnaire(%s,d."IdEntiteDestinataireFk"))'
            values.extend([actor.pk, actor.pk])
        state_options = states()
        state = request.query_params.get("state")
        if state:
            if state not in {s["id"] for s in state_options}:
                raise APIError("État de demande invalide.")
            where += ' AND d."EtatDemande"=%s'
            values.append(state)
        term = text(request.query_params.get("search", ""), "Recherche", 200, optional=True)
        if term:
            where += ' AND concat_ws(\' \',d."CodeDemande",d."SujetDemande",d."LibelleSource",d."NomDemandeur",d."NomDestinataire") ILIKE %s'
            values.append("%" + term + "%")
        take, skip = page(request.query_params)
        if take > 100:
            raise APIError("Affichez au plus 100 demandes par page.", "QUERY_INVALID", 422)
        population = db.one('WITH population AS MATERIALIZED (SELECT d.* FROM communication."V_Demande" d WHERE ' + where +
            '), selection AS (SELECT * FROM population ORDER BY "CreeLe" DESC,"IdDemande" DESC LIMIT %s OFFSET %s) '
            'SELECT (SELECT count(*) FROM population) AS total,coalesce((SELECT jsonb_agg(to_jsonb(s) '
            'ORDER BY s."CreeLe" DESC,s."IdDemande" DESC) FROM selection s),\'[]\'::jsonb) AS rows', [*values, take, skip])
        total, rows = population["total"], population["rows"]
        manage = not settings.DB_READ_ONLY and access_snapshot(actor)["modules"]["discussions"]["canManage"]
        actual_entity = actor.row.get("IdEntiteFk")
        managed_entity = actual_entity if actual_entity and db.one(
            'SELECT communication.fn_demande_gestionnaire(%s,%s) AS allowed', [actor.pk, actual_entity])["allowed"] else -1
        labels = {s["id"]: s["label"] for s in state_options}
        return private_response({"rows": [record(row, actor, labels=labels, manage=manage, managed_entity=managed_entity) for row in rows], "total": total},
            meta={"states": state_options, "take": take, "skip": skip, "hasNext": skip + len(rows) < total})

    def post(self, request):
        data = payload(request, {"sourceType", "sourceId", "subject", "description", "quantity", "destination", "requestId"})
        kind, pk = source_key(data)
        require_module(request.user, SOURCES[kind])
        subject = text(data.get("subject"), "Objet", 160)
        if "\n" in subject or "\r" in subject:
            raise APIError("L’objet doit tenir sur une seule ligne.", "DEMANDE_INVALID", 422)
        quantity = data.get("quantity")
        if quantity not in (None, ""):
            if kind != "product" or not isinstance(quantity, str) or not re.fullmatch(r"(?:0|[1-9][0-9]{0,14})(?:\.[0-9]{1,3})?", quantity) or Decimal(quantity) <= 0:
                raise APIError("La quantité doit être un nombre positif, avec au plus trois décimales.", "QUANTITY_INVALID", 422)
            quantity = Decimal(quantity)
        else:
            quantity = None
        result = mutate('SELECT communication.fn_demande_creer(%s,%s,%s,%s,%s,%s,%s,%s::uuid) AS id',
            [request.user.pk, kind, pk, subject, text(data.get("description"), "Description", 5000), quantity,
             text(data.get("destination"), "Destination", 300, optional=True), request_key(data.get("requestId"))])
        return private_response(dossier(request.user, result["id"]), status=201)


class DemandeDetailView(APIView):
    permission_classes = [HasModuleAccess]
    http_method_names = ["get", "head", "options"]

    def get(self, request, pk):
        return private_response(dossier(request.user, positive(pk)))


class DemandeTransitionView(APIView):
    permission_classes = [HasModuleAccess]
    http_method_names = ["post", "options"]

    def post(self, request, pk):
        data = payload(request, {"state", "version", "reason", "requestId"})
        target = text(data.get("state"), "État", 30)
        if target not in {s["id"] for s in states()}:
            raise APIError("État de demande invalide.", "DEMANDE_INVALID", 422)
        pk = positive(pk)
        # Le 404 ne révèle jamais un dossier hors du périmètre privé.
        dossier(request.user, pk)
        mutate('SELECT communication.fn_demande_transition(%s,%s,%s,%s,%s,%s::uuid) AS id',
            [request.user.pk, pk, target, version(data.get("version")), text(data.get("reason"), "Motif", 1000, optional=target == "en_cours"), request_key(data.get("requestId"))])
        return private_response(dossier(request.user, pk))


class DemandeDiscussionView(APIView):
    permission_classes = [HasModuleAccess]
    http_method_names = ["post", "options"]

    def post(self, request, pk):
        data = payload(request, {"version", "requestId"})
        pk = positive(pk)
        dossier(request.user, pk)
        result = mutate('SELECT communication.fn_demande_discussion(%s,%s,%s,%s::uuid) AS id',
            [request.user.pk, pk, version(data.get("version")), request_key(data.get("requestId"))])
        return private_response({"discussionId": result["id"], "record": dossier(request.user, pk)["record"]})


class DemandeRoutingView(APIView):
    permission_classes = [HasModuleAccess]
    http_method_names = ["put", "options"]

    def put(self, request):
        if not request.user.global_admin:
            raise APIError("Le routage est réservé à l’administration de la plateforme.", "GLOBAL_ADMIN_REQUIRED", 403)
        data = payload(request, {"entityId", "version", "reason", "requestId"})
        query_options(request.query_params, {"sourceType", "sourceId"})
        kind, pk = source_key(request.query_params)
        if not kind.startswith("structure_"):
            raise APIError("Le routage concerne uniquement une structure territoriale.", "SOURCE_INVALID", 422)
        mutate('SELECT communication.fn_demande_routage(%s,%s,%s,%s,%s,%s,%s::uuid) AS version',
            [request.user.pk, kind, pk, positive(data.get("entityId"), "Entreprise") if data.get("entityId") is not None else None, version(data.get("version")),
             text(data.get("reason"), "Motif de la vérification", 1000), request_key(data.get("requestId"))])
        return SourceContextView().get(request)
