"""Besoins personnels déclarés après une recherche dans un annuaire."""
from django.conf import settings
from django.db import DatabaseError, transaction
from rest_framework.views import APIView

from apps.core import db
from apps.core.module_access import can_use_tab, require_module, require_tab
from apps.core.permissions import HasModuleAccess
from apps.core.repository import page, positive
from apps.core.responses import APIError
from .demandes import payload, query_options, request_key
from .notifications import private_response

SOURCES = {"product": "produits", "expert": "professionnels", "structure": "structures"}
TABLE = 'communication."T_BesoinAnnuaire"'
PROVINCES = '''SELECT "ID_Niveau_1" AS value, "NomNiveau_1" AS label
                FROM geolocalisation."T_Niveau_1"
                WHERE nullif(btrim("NomNiveau_1"), '') IS NOT NULL'''


def choice_id(value, label):
    if value in (None, ""):
        return None
    if isinstance(value, bool) or not isinstance(value, (int, str)):
        raise APIError(f"{label} : choix invalide.", "NEED_INVALID", 422)
    result = positive(value, label)
    if result > 2147483647:
        raise APIError(f"{label} : choix invalide.", "NEED_INVALID", 422)
    return result


class BesoinsOptionsView(APIView):
    permission_classes = [HasModuleAccess]

    def get(self, request):
        query_options(request.query_params, ())
        entity = request.user.row.get("IdEntiteFk")
        enabled = db.one('''SELECT EXISTS (
            SELECT FROM analytics."T_PerimetreRecherche" p
            JOIN systeme."T_Entite" e ON e."IdEntite"=p."IdEntiteFk"
            WHERE p."IdEntiteFk"=%s AND p."TermineLe" IS NULL
              AND p."DebuteLe"<=statement_timestamp() AND e."ValideEntite") AS enabled''', [entity])
        options = '''SELECT identifiant AS value, libelle AS label
                     FROM analytics.fn_choix_recherche(%s) ORDER BY libelle, identifiant'''
        return private_response({
            "provinces": db.query(PROVINCES + ' ORDER BY label, value'),
            "categories": db.query(options, ["Catégorie produit"]),
            "topics": db.query(options, ["Maladie"]),
            "canWrite": not settings.DB_READ_ONLY and can_use_tab(request.user, "discussions", "demandes", "manage"),
            "canShareResearch": enabled["enabled"],
        })


class BesoinsView(APIView):
    permission_classes = [HasModuleAccess]

    def get(self, request):
        query_options(request.query_params, ("take", "skip"))
        take, skip = page(request.query_params)
        scope = [request.user.pk, request.user.row.get("IdEntiteFk")]
        rows = db.query(f'''SELECT b."IdBesoin" AS id, b."Source" AS source, b."Nature" AS nature,
                   p."NomNiveau_1" AS province, g."AbrGenerique" AS category,
                   m."AbrGenerique" AS topic, b."Etat" AS state, b."CreeLe" AS "createdAt"
            FROM {TABLE} b
            LEFT JOIN geolocalisation."T_Niveau_1" p ON p."ID_Niveau_1"=b."IdTerritoireFk"
            LEFT JOIN referentiel."T_Generique" g ON g."ID_Generique"=b."IdCategorieProduitFk"
            LEFT JOIN referentiel."T_Generique" m ON m."ID_Generique"=b."IdPathologieFk"
            WHERE b."IdAuteurFk"=%s AND b."IdEntiteFk" IS NOT DISTINCT FROM %s
            ORDER BY b."CreeLe" DESC, b."IdBesoin" DESC LIMIT %s OFFSET %s''', [*scope, min(take, 100), skip])
        total = db.one(f'''SELECT count(*) AS total FROM {TABLE}
            WHERE "IdAuteurFk"=%s AND "IdEntiteFk" IS NOT DISTINCT FROM %s''', scope)
        return private_response({"rows": rows, "total": total["total"]})

    def post(self, request):
        db.ensure_writable()
        data = payload(request, ("requestId", "source", "nature", "provinceId", "categoryId", "topicId", "consent"))
        source, nature, consent = data.get("source"), data.get("nature"), data.get("consent", False)
        if not isinstance(source, str) or source not in SOURCES or nature not in ("recherche", "besoin_sans_resultat") or type(consent) is not bool:
            raise APIError("Choisissez un annuaire et un type de déclaration valides.", "NEED_INVALID", 422)
        actor = request.user
        if source == "expert":
            require_tab(actor, "professionnels", "annuaire")
        else:
            require_module(actor, SOURCES[source])
        category = choice_id(data.get("categoryId"), "Catégorie de produit")
        topic = choice_id(data.get("topicId"), "Sujet de santé")
        province = choice_id(data.get("provinceId"), "Province")
        if (category and topic) or (nature == "recherche" and (not consent or not (category or topic))):
            raise APIError("Choisissez une seule catégorie ou un sujet de santé et confirmez le partage pour une recherche.", "NEED_INVALID", 422)
        entity = actor.row.get("IdEntiteFk")
        key = request_key(data.get("requestId"))
        values = [source, nature, category, topic, province, consent]
        try:
            with transaction.atomic():
                db.one("SELECT pg_advisory_xact_lock(%s, hashtext(%s)) AS verrou", [actor.pk, key])
                existing = db.one(f'''SELECT "IdBesoin" AS id,
                    ROW("Source","Nature","IdCategorieProduitFk","IdPathologieFk","IdTerritoireFk","Consentement")
                      IS NOT DISTINCT FROM ROW(%s::text,%s::text,%s::integer,%s::integer,%s::integer,%s::boolean) AS same
                    FROM {TABLE} WHERE "IdAuteurFk"=%s AND "CleRequete"=%s
                      AND "IdEntiteFk" IS NOT DISTINCT FROM %s''', [*values, actor.pk, key, entity])
                if existing:
                    if not existing["same"]:
                        raise APIError("Cette opération a déjà été enregistrée avec d’autres choix.", "NEED_CONFLICT", 409)
                    return private_response({"id": existing["id"]})
                created = db.one(f'''INSERT INTO {TABLE} ("IdAuteurFk","IdEntiteFk","CleRequete","Source","Nature",
                    "IdCategorieProduitFk","IdPathologieFk","IdTerritoireFk","Consentement","Etat")
                    VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s) RETURNING "IdBesoin" AS id''',
                    [actor.pk, entity, key, *values, "en_attente" if nature == "besoin_sans_resultat" else None])
        except DatabaseError as exc:
            sqlstate = getattr(exc.__cause__, "sqlstate", None)
            if sqlstate == "PBA03":
                raise APIError("Votre entreprise ne participe pas à cette étude.", "RESEARCH_INACTIVE", 403) from None
            if sqlstate in ("PBA01", "23503", "23514"):
                raise APIError("Un choix n’est plus disponible. Actualisez les listes.", "NEED_INVALID", 422) from None
            raise
        return private_response(created, status=201)


class BesoinIssueView(APIView):
    permission_classes = [HasModuleAccess]

    def post(self, request, pk):
        db.ensure_writable()
        state = payload(request, ("state",)).get("state")
        if state not in ("satisfaite", "non_satisfaite"):
            raise APIError("Choisissez une issue valide.", "NEED_INVALID", 422)
        with transaction.atomic():
            row = db.one(f'''SELECT "Etat" AS state FROM {TABLE}
                WHERE "IdBesoin"=%s AND "IdAuteurFk"=%s AND "Nature"='besoin_sans_resultat'
                  AND "IdEntiteFk" IS NOT DISTINCT FROM %s
                FOR UPDATE''', [pk, request.user.pk, request.user.row.get("IdEntiteFk")])
            if not row:
                raise APIError("Besoin introuvable.", "NOT_FOUND", 404)
            if row["state"] != state:
                if row["state"] != "en_attente":
                    raise APIError("Une issue a déjà été enregistrée.", "NEED_CONFLICT", 409)
                db.one(f'UPDATE {TABLE} SET "Etat"=%s WHERE "IdBesoin"=%s RETURNING "IdBesoin"', [state, pk])
        return private_response({"id": pk, "state": state})
