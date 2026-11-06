"""Diffusions administratives, distinctes des discussions privées."""

import uuid

from django.conf import settings
from django.db import DatabaseError, transaction
from rest_framework.views import APIView

from apps.core import db
from apps.core.module_access import access_snapshot
from apps.core.repository import positive
from apps.core.responses import APIError

from .notifications import pagination, private_response


MAX_TITLE = 160
MAX_BODY = 5000
MAX_COMPANIES = 100

SQL_ERRORS = {
    "PCO01": ("Votre compte ne peut pas diffuser vers cette entreprise.", "ANNOUNCEMENT_FORBIDDEN", 403),
    "PCO02": ("Une entreprise sélectionnée est introuvable ou inactive.", "ANNOUNCEMENT_TARGET_INVALID", 422),
    "PCO03": ("Aucun compte actif pour une ou plusieurs entreprises destinataires.", "ANNOUNCEMENT_NO_RECIPIENTS", 422),
    "PCO04": ("Cette demande a déjà été utilisée pour une autre annonce.", "ANNOUNCEMENT_REQUEST_CONFLICT", 409),
    "PCO05": ("Vérifiez le titre et le contenu de l’annonce.", "ANNOUNCEMENT_CONTENT_INVALID", 422),
}


def can_view_sent(actor):
    return actor.global_admin or (actor.admin and actor.row.get("IdEntiteFk") is not None)


def sent_scope(actor):
    if not can_view_sent(actor):
        raise APIError("L’historique des diffusions est réservé aux administrateurs.", "ANNOUNCEMENT_FORBIDDEN", 403)
    if actor.global_admin:
        return 'a."EmisParPlateforme" IS TRUE', []
    return 'a."EmisParPlateforme" IS FALSE AND a."IdEntiteFk"=%s', [actor.row["IdEntiteFk"]]


def available_companies(actor):
    if not can_view_sent(actor):
        return []
    where, params = "", []
    if not actor.global_admin:
        where = ' AND e."IdEntite"=%s'
        params = [actor.row["IdEntiteFk"]]
    return db.query(
        '''SELECT e."IdEntite" AS id, e."NomEntite" AS name
           FROM systeme."T_Entite" e
           WHERE e."ValideEntite" IS TRUE AND EXISTS (
               SELECT 1 FROM systeme."T_Utilisateurs" u
               WHERE u."IdEntiteFk"=e."IdEntite" AND u."ValideUser" IS TRUE
           )''' + where + ' ORDER BY e."NomEntite",e."IdEntite"',
        params,
    )


def sent_item(row):
    return {
        "id": row["IdAnnonce"],
        "title": row["SujetAnnonce"],
        "body": row["ContenuAnnonce"],
        "createdAt": row["PublieLe"].isoformat(),
        "scope": {"entreprises": "companies", "toutes": "all"}[row["PorteeAnnonce"]],
        "companies": row["Entreprises"],
        "authorName": row["NomAuteur"],
        "recipientCount": row["NombreDestinataires"],
        "readCount": row["NombreLus"],
    }


def required_text(value, label, limit):
    value = value.strip() if isinstance(value, str) else ""
    if not value or len(value) > limit or "\0" in value:
        raise APIError(f"{label} est obligatoire et doit comporter au plus {limit} caractères.", "ANNOUNCEMENT_CONTENT_INVALID", 422)
    try:
        value.encode("utf8")
    except UnicodeEncodeError:
        raise APIError(f"{label} contient un caractère invalide.", "ANNOUNCEMENT_CONTENT_INVALID", 422) from None
    return value


def request_key(value):
    try:
        if isinstance(value, str):
            parsed = uuid.UUID(value)
            if str(parsed) == value.lower():
                return parsed
    except ValueError:
        pass
    raise APIError("Identifiant de demande invalide.", "ANNOUNCEMENT_REQUEST_INVALID")


def parse_publication(actor, payload):
    sent_scope(actor)
    if not isinstance(payload, dict) or set(payload) - {"title", "body", "scope", "companyIds", "requestId"}:
        raise APIError("Les informations de diffusion sont invalides.")

    title = required_text(payload.get("title"), "Le titre", MAX_TITLE)
    if "\r" in title or "\n" in title:
        raise APIError("Le titre doit tenir sur une seule ligne.", "ANNOUNCEMENT_CONTENT_INVALID", 422)
    body = required_text(payload.get("body"), "Le message", MAX_BODY)
    key = request_key(payload.get("requestId"))
    scope = payload.get("scope")
    raw_ids = payload.get("companyIds", [])
    if scope not in ("companies", "all") or not isinstance(raw_ids, list) or len(raw_ids) > MAX_COMPANIES:
        raise APIError("Choisissez les entreprises destinataires.", "ANNOUNCEMENT_TARGET_INVALID", 422)
    company_ids = sorted({positive(value, "Entreprise") for value in raw_ids})

    if not actor.global_admin:
        entity = actor.row["IdEntiteFk"]
        if scope != "companies" or (company_ids and company_ids != [entity]):
            raise APIError("Vous pouvez diffuser uniquement à votre entreprise.", "ANNOUNCEMENT_FORBIDDEN", 403)
        company_ids = [entity]
    elif (scope == "companies" and not company_ids) or (scope == "all" and company_ids):
        raise APIError("Choisissez des entreprises ou la diffusion à toutes les entreprises.", "ANNOUNCEMENT_TARGET_INVALID", 422)

    return title, body, company_ids if scope == "companies" else None, key


class AnnouncementContextView(APIView):
    http_method_names = ["get", "head", "options"]

    def get(self, request):
        actor = request.user
        can_view = can_view_sent(actor)
        companies = available_companies(actor)
        can_manage = access_snapshot(actor)["modules"]["discussions"]["canManage"]
        return private_response({
            "canViewSent": can_view,
            "canPublish": can_view and can_manage and bool(companies) and not settings.DB_READ_ONLY,
            "platformAdmin": actor.global_admin,
            "companies": companies,
        })


class AnnouncementsView(APIView):
    http_method_names = ["get", "head", "post", "options"]

    def get(self, request):
        where, params = sent_scope(request.user)
        page, size = pagination(request.query_params)
        offset = (page - 1) * size
        total = db.one(
            'SELECT COUNT(*) AS total FROM communication."T_Annonce" a WHERE ' + where,
            params,
        )["total"]
        rows = db.query(
            'SELECT a.* FROM communication."V_Annonce" a WHERE ' + where
            + ' ORDER BY a."PublieLe" DESC, a."IdAnnonce" DESC LIMIT %s OFFSET %s',
            [*params, size, offset],
        ) if offset < total else []
        return private_response(
            [sent_item(row) for row in rows],
            meta={
                "total": total, "page": page, "pageSize": size,
                "hasNext": offset + size < total, "hasPrevious": page > 1,
            },
        )

    def post(self, request):
        actor = request.user
        title, body, companies, key = parse_publication(actor, request.data)
        db.ensure_writable()
        try:
            with transaction.atomic():
                result = db.one(
                    "SELECT * FROM communication.fn_diffuser_annonce(%s, %s::integer[], %s, %s, %s::uuid)",
                    [actor.pk, companies, title, body, key],
                )
                row = db.one(
                    'SELECT * FROM communication."V_Annonce" WHERE "IdAnnonce"=%s',
                    [result["IdAnnonce"]],
                )
        except DatabaseError as error:
            rejection = SQL_ERRORS.get(getattr(error.__cause__, "sqlstate", None))
            if rejection:
                raise APIError(*rejection) from error
            raise
        return private_response(
            sent_item(row),
            status=200 if result["Rejouee"] else 201,
            meta={"replayed": result["Rejouee"]},
        )
