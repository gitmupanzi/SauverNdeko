"""Cellules agrégées du registre de recherche, filtrées selon le périmètre autorisé."""

import re
from datetime import date
from zoneinfo import ZoneInfo

from django.db import transaction
from django.utils import timezone
from rest_framework.permissions import BasePermission, IsAuthenticated
from rest_framework.views import APIView

from apps.core import db
from apps.core.module_access import can_use_tab, require_tab
from apps.core.responses import APIError, ok
from apps.core.tenancy import read_entity


RESEARCH_TIMEZONE = ZoneInfo("Africa/Kinshasa")
CONFIDENTIALITY_THRESHOLD = 5
MAX_MONTHS = 12
MAX_CELLS = 5000
REPORT_TABS = {"tableau-de-bord", "demandes", "recherches"}
MONTH_PATTERN = re.compile(r"[1-9][0-9]{3}-(?:0[1-9]|1[0-2])")

SOURCE_AVAILABILITY_SQL = """
    SELECT EXISTS (
               SELECT FROM pg_attribute
               WHERE attrelid = to_regclass('analytics."V_ObservationDemandeRecherche"')
                 AND attname = 'IdEntiteFk' AND NOT attisdropped
           ) AS demandes,
           to_regclass('logistique."V_OffreArticle"') IS NOT NULL AS offres
"""

INDICATORS_SQL = """
    WITH parametres AS (
        SELECT %s::date AS debut, %s::date AS fin, %s::integer AS seuil,
               %s::integer AS entite, %s::text[] AS natures
    ),
    observations_par_entreprise AS (
        SELECT d."Mois" AS mois, d."Source" AS source, d."Nature" AS nature,
               d."IdProduitFk" AS produit_id, min(d."ProduitLibelle") AS produit_libelle,
               d."IdPathologieFk" AS pathologie_id, min(d."PathologieLibelle") AS pathologie_libelle,
               d."IdTerritoireFk" AS territoire_id, min(d."TerritoireLibelle") AS territoire_libelle,
               count(*) AS total,
               count(*) FILTER (WHERE d."EtatDemande" = 'satisfaite') AS satisfaites,
               count(*) FILTER (WHERE d."EtatDemande" = 'non_satisfaite') AS non_satisfaites,
               count(*) FILTER (WHERE d."ResultatRecherche" = 'avec_resultat') AS avec_resultat,
               count(*) FILTER (WHERE d."ResultatRecherche" = 'sans_resultat') AS sans_resultat,
               count(DISTINCT d."Contributeur") FILTER (WHERE d."EtatDemande" = 'satisfaite')
                   NOT BETWEEN 1 AND p.seuil - 1
               AND count(DISTINCT d."Contributeur") FILTER (WHERE d."EtatDemande" = 'non_satisfaite')
                   NOT BETWEEN 1 AND p.seuil - 1
               AND count(DISTINCT d."Contributeur") FILTER (WHERE d."EtatDemande" NOT IN ('satisfaite', 'non_satisfaite'))
                   NOT BETWEEN 1 AND p.seuil - 1 AS issues_publiables,
               count(*) FILTER (WHERE d."ResultatRecherche" IS NOT NULL) > 0
               AND count(DISTINCT d."Contributeur") FILTER (WHERE d."ResultatRecherche" = 'avec_resultat')
                   NOT BETWEEN 1 AND p.seuil - 1
               AND count(DISTINCT d."Contributeur") FILTER (WHERE d."ResultatRecherche" = 'sans_resultat')
                   NOT BETWEEN 1 AND p.seuil - 1
               AND count(DISTINCT d."Contributeur") FILTER (WHERE d."ResultatRecherche" IS NULL)
                   NOT BETWEEN 1 AND p.seuil - 1 AS resultats_publiables
        FROM analytics."V_ObservationDemandeRecherche" d
        CROSS JOIN parametres p
        WHERE d."Mois" BETWEEN p.debut AND p.fin
          AND d."Contributeur" IS NOT NULL
          AND d."IdEntiteFk" IS NOT NULL
          AND (p.entite IS NULL OR d."IdEntiteFk" = p.entite)
          AND d."Nature" = ANY(p.natures)
          AND d."Source" IN ('product', 'expert', 'structure')
          AND (
              (d."Nature" = 'recherche'
                AND (d."ResultatRecherche" IN ('avec_resultat', 'sans_resultat') OR d."ResultatRecherche" IS NULL)
                AND (d."IdProduitFk" IS NULL OR d."IdPathologieFk" IS NULL))
              OR (d."Nature" IN ('besoin_sans_resultat', 'demande_suivie')
                AND d."EtatDemande" IN ('en_attente', 'en_cours', 'satisfaite', 'non_satisfaite', 'annulee')
                AND d."IdPathologieFk" IS NULL)
          )
        GROUP BY d."Mois", d."Source", d."Nature", d."IdProduitFk",
                 d."IdPathologieFk", d."IdTerritoireFk", d."IdEntiteFk", p.seuil
        HAVING count(DISTINCT d."Contributeur") >= p.seuil
    ),
    -- La consolidation additionne seulement les cellules déjà diffusables par entreprise.
    -- Elle masque aussi leurs ventilations si une seule des entreprises doit les masquer.
    observations AS (
        SELECT mois, source, nature, produit_id, min(produit_libelle) AS produit_libelle,
               pathologie_id, min(pathologie_libelle) AS pathologie_libelle,
               territoire_id, min(territoire_libelle) AS territoire_libelle,
               sum(total)::bigint AS total,
               sum(satisfaites)::bigint AS satisfaites,
               sum(non_satisfaites)::bigint AS non_satisfaites,
               sum(avec_resultat)::bigint AS avec_resultat,
               sum(sans_resultat)::bigint AS sans_resultat,
               bool_and(issues_publiables) AS issues_publiables,
               bool_and(resultats_publiables) AS resultats_publiables
        FROM observations_par_entreprise
        GROUP BY mois, source, nature, produit_id, pathologie_id, territoire_id
    )
    SELECT to_char(d.mois, 'YYYY-MM') AS mois, d.source, d.nature,
           d.produit_id AS "produitId",
           CASE WHEN d.produit_id IS NOT NULL THEN d.produit_libelle END AS "produitLibelle",
           d.pathologie_id AS "pathologieId",
           CASE WHEN d.pathologie_id IS NOT NULL THEN d.pathologie_libelle END AS "pathologieLibelle",
           d.territoire_id AS "territoireId",
           CASE WHEN d.territoire_id IS NOT NULL THEN d.territoire_libelle END AS "territoireLibelle",
           CASE WHEN d.nature <> 'recherche' THEN d.total END AS demandes,
           CASE WHEN d.nature <> 'recherche' AND d.issues_publiables THEN d.satisfaites END AS satisfaites,
           CASE WHEN d.nature <> 'recherche' AND d.issues_publiables THEN d.non_satisfaites END AS "nonSatisfaites",
           CASE WHEN d.nature = 'recherche' THEN d.total END AS recherches,
           CASE WHEN d.nature = 'recherche' AND d.resultats_publiables THEN d.avec_resultat END AS "avecResultat",
           CASE WHEN d.nature = 'recherche' AND d.resultats_publiables THEN d.sans_resultat END AS "sansResultat",
           NULL::bigint AS "observationsStock",
           NULL::bigint AS ruptures,
           NULL::bigint AS reapprovisionnements
    FROM observations d
    ORDER BY d.mois, d.source, d.nature, d.produit_id, d.pathologie_id, d.territoire_id
    LIMIT %s
"""

CELL_FIELDS = (
    "mois", "source", "nature", "produitId", "produitLibelle", "pathologieId", "pathologieLibelle",
    "territoireId", "territoireLibelle", "demandes", "satisfaites", "nonSatisfaites",
    "recherches", "avecResultat", "sansResultat", "observationsStock", "ruptures", "reapprovisionnements",
)


def period(query_params):
    if any(key not in {"debut", "fin"} or len(values) != 1 for key, values in query_params.lists()):
        raise APIError("Choisissez une seule valeur par borne mensuelle.", "RESEARCH_PERIOD_INVALID")
    current = timezone.localdate(timezone=RESEARCH_TIMEZONE).replace(day=1)
    if not query_params:
        default_index = current.year * 12 + current.month - MAX_MONTHS
        year, month = divmod(default_index, 12)
        return date(year, month + 1, 1), current
    start, end = query_params.get("debut", ""), query_params.get("fin", "")
    if not MONTH_PATTERN.fullmatch(start) or not MONTH_PATTERN.fullmatch(end):
        raise APIError("Les deux bornes doivent être des mois au format AAAA-MM.", "RESEARCH_PERIOD_INVALID")
    start_date, end_date = (date.fromisoformat(value + "-01") for value in (start, end))
    months = (end_date.year - start_date.year) * 12 + end_date.month - start_date.month + 1
    if not 1 <= months <= MAX_MONTHS or end_date > current:
        raise APIError("Choisissez une période de 1 à 12 mois, jusqu’au mois courant.",
                       "RESEARCH_PERIOD_INVALID")
    return start_date, end_date


def demand_indicators(start, end, *, entity=None, report_tab="demandes", include_research=False):
    sources = db.one(SOURCE_AVAILABILITY_SQL)
    cells = []
    if sources and sources["demandes"]:
        natures = ["recherche"] if report_tab == "recherches" else ["besoin_sans_resultat", "demande_suivie"]
        if report_tab == "tableau-de-bord" and include_research:
            natures.append("recherche")
        rows = db.query(INDICATORS_SQL, [
            start, end, CONFIDENTIALITY_THRESHOLD, entity, natures, MAX_CELLS + 1,
        ])
        if len(rows) > MAX_CELLS:
            raise APIError("Réduisez la période pour afficher toutes les cellules de l’analyse.",
                           "RESEARCH_PERIOD_TOO_LARGE", 422)
        cells = [{field: row[field] for field in CELL_FIELDS} for row in rows]
        categories = {cell["produitId"] for cell in cells if cell["produitId"] is not None}
        published = set()
        if sources["offres"] and categories:
            published = {row["id"] for row in db.query('''
                SELECT DISTINCT "ID_CategorieArticleFk" AS id
                FROM logistique."V_OffreArticle"
                WHERE "ID_CategorieArticleFk" = ANY(%s)
                  AND (%s::integer IS NULL OR "IdEntite" = %s)
            ''', [sorted(categories), entity, entity])}
        for cell in cells:
            category = cell["produitId"]
            cell["offrePubliee"] = category in published if sources["offres"] and category is not None else None
    return {
        "perimetre": {"type": "global" if entity is None else "entreprise", "entrepriseId": entity},
        "periode": {"debut": start.isoformat()[:7], "fin": end.isoformat()[:7]},
        "seuilConfidentialite": CONFIDENTIALITY_THRESHOLD,
        "statutCollecte": "disponible" if sources and sources["demandes"] else "indisponible",
        "cellules": cells,
        "rapprochementDisponible": False,
        "associationMaladieProduitDisponible": False,
    }


class IsResearchPlatformAdmin(BasePermission):
    message = "Le périmètre de l’étude est réservé à l’administration de la plateforme."

    def has_permission(self, request, view):
        return bool(request.user and request.user.is_authenticated and getattr(request.user, "global_admin", False))


class ScientificDemandIndicatorsView(APIView):
    permission_classes = [IsAuthenticated]
    http_method_names = ["get", "head", "options"]

    def get(self, request):
        actor = request.user
        filters = request.query_params.copy()
        tabs = filters.pop("vue", ["demandes"])
        if len(tabs) != 1 or tabs[0] not in REPORT_TABS:
            raise APIError("Choisissez une vue d’analyse valide.", "RESEARCH_VIEW_INVALID")
        tab = tabs[0]
        if tab == "recherches" and not actor.global_admin:
            raise APIError("Les recherches déclarées sont réservées à l’administration de la plateforme.",
                           "PLATFORM_ADMIN_REQUIRED", 403)
        require_tab(actor, "data-science", tab)
        entity = read_entity(actor)
        if not actor.global_admin and entity is None:
            raise APIError("Votre compte doit être rattaché à une entreprise.", "ORGANISATION_REQUIRED", 403)
        include_research = (tab == "tableau-de-bord" and actor.global_admin and entity is None
                            and can_use_tab(actor, "data-science", "recherches"))
        response = ok(demand_indicators(*period(filters), entity=entity, report_tab=tab,
                                        include_research=include_research))
        response["Cache-Control"] = "private, no-store"
        return response


class ResearchScopeView(APIView):
    permission_classes = [IsResearchPlatformAdmin]

    def get(self, request):
        require_tab(request.user, "data-science", "perimetre")
        if request.query_params:
            raise APIError("Aucun filtre n’est attendu.", "RESEARCH_SCOPE_INVALID")
        exists = db.one("""SELECT to_regclass('analytics."T_PerimetreRecherche"') IS NOT NULL AS disponible""")
        if not exists["disponible"]:
            raise APIError("La mise à jour Data Science est nécessaire.", "RESEARCH_SCHEMA_REQUIRED", 503)
        rows = db.query('''SELECT e."IdEntite" AS id, e."NomEntite" AS nom, p."DebuteLe" AS "debuteLe"
            FROM systeme."T_Entite" e
            LEFT JOIN analytics."T_PerimetreRecherche" p
              ON p."IdEntiteFk" = e."IdEntite" AND p."TermineLe" IS NULL
            WHERE e."ValideEntite" IS TRUE OR p."IdPerimetre" IS NOT NULL
            ORDER BY e."NomEntite", e."IdEntite"''')
        response = ok({"entreprises": rows})
        response["Cache-Control"] = "private, no-store"
        return response

    def post(self, request):
        require_tab(request.user, "data-science", "perimetre", "manage")
        data = request.data
        if not isinstance(data, dict) or set(data) != {"entityId", "enabled"}:
            raise APIError("Choisissez une entreprise et un état de participation.", "RESEARCH_SCOPE_INVALID")
        entity_id, enabled = data["entityId"], data["enabled"]
        if type(entity_id) is not int or not 0 < entity_id <= 2147483647 or type(enabled) is not bool:
            raise APIError("Choisissez une entreprise et un état de participation valides.", "RESEARCH_SCOPE_INVALID")
        db.ensure_writable()
        with transaction.atomic():
            # Same lock order as the declaration trigger, entity before the active study period.
            entity = db.one('''SELECT "ValideEntite" AS active FROM systeme."T_Entite"
                WHERE "IdEntite"=%s FOR UPDATE''', [entity_id])
            if not entity or (enabled and entity["active"] is not True):
                raise APIError("Cette entreprise ne peut pas participer à l’étude.", "RESEARCH_SCOPE_INVALID", 422)
            if enabled:
                db.one('''INSERT INTO analytics."T_PerimetreRecherche" ("IdEntiteFk", "IdModifieParFk")
                    VALUES (%s, %s) ON CONFLICT ("IdEntiteFk") WHERE "TermineLe" IS NULL
                    DO NOTHING RETURNING "IdPerimetre"''', [entity_id, request.user.pk])
            else:
                db.one('''UPDATE analytics."T_PerimetreRecherche"
                    SET "TermineLe"=statement_timestamp(), "IdTermineParFk"=%s
                    WHERE "IdEntiteFk"=%s AND "TermineLe" IS NULL RETURNING "IdPerimetre"''',
                    [request.user.pk, entity_id])
        response = ok({"id": entity_id, "enabled": enabled})
        response["Cache-Control"] = "private, no-store"
        return response
