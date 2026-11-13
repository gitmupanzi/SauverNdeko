"""Export journalier des fiches de stock depuis le registre des mouvements."""

from datetime import date, datetime
from itertools import groupby
from tempfile import SpooledTemporaryFile

from django.db import connection

from apps.core import db
from apps.core.permissions import scope_for
from apps.core.registry import view
from apps.core.responses import APIError
from apps.core.tenancy import read_entity

from .depots import requested_depot
from .ledger_registers import column
from .reads import read_scope, register_source, restrict_order_source, row_source
from .tab_access import require_tabs
from .table_queries import document_zone


ARTICLE_COLUMNS = (
    ("NomArticle", "Article", "text"),
    ("ID_Article", "ID article", "text"),
    ("CodeArticleInterne", "Code article", "text"),
    ("RefArticle", "Référence", "text"),
    ("CategorieArticle", "Catégorie", "text"),
    ("Unite", "Unité", "text"),
    ("NomEntite", "Entreprise", "text"),
    ("NomDepot", "Dépôt", "text"),
)
SUMMARY_COLUMNS = (
    ("Jour", "Date", "date"),
    *ARTICLE_COLUMNS,
    ("Ouverture", "Stock d’ouverture", "numeric"),
    ("Entrees", "Entrées", "numeric"),
    ("Sorties", "Sorties", "numeric"),
    ("Cloture", "Stock de clôture", "numeric"),
    ("NonDates", "Mouvements historiques non datés", "integer"),
)
MOVEMENT_COLUMNS = (
    ("DateFicheStock", "Date et heure", "timestamp without time zone"),
    *ARTICLE_COLUMNS,
    ("ID_Mvt", "N° du mouvement", "text"),
    ("NomTypeMvt", "Type de mouvement", "text"),
    ("CodeCmd", "Bon de stock", "text"),
    ("Entrees", "Entrée", "numeric"),
    ("Sorties", "Sortie", "numeric"),
    ("Cloture", "Solde après mouvement", "numeric"),
)
MOVEMENT_FILTERS = ("commandeId", "typeId", "origine", "sens", "deviseId")
ARTICLE_FILTERS = {
    "ID_ArticleFk": "ID_Article",
    "ID_CategorieArticleFk": "ID_CategorieArticleFk",
    "ID_TypeArticleFk": "ID_TypeArticleFk",
}


def export_fields(columns):
    return [{**column(key, kind), "label": label} for key, label, kind in columns]


def report_query(actor, raw, day, depot_id, limit):
    movements, condition, fixed = register_source("mouvements", raw)
    movements = restrict_order_source(movements, actor, action="export")
    movements = {
        **movements,
        "columns": [*movements["columns"], column("DateFicheStock", "timestamp without time zone")],
        "_date_field": "DateFicheStock",
        "_row_source": '''(SELECT v.*, coalesce(v."DateMvt", v."DateHeureAutoMvt") AS "DateFicheStock"
                           FROM ''' + row_source(movements) + ") v",
    }
    _, matched_where, matched_values, _, _, _, applied = read_scope(
        movements, actor, raw, condition, fixed,
    )
    article = view("logistique", "V_Article")
    article_where, article_values = scope_for(article, actor, alias="a")
    for movement_field, article_field in ARTICLE_FILTERS.items():
        if movement_field in fixed:
            article_where += " AND a." + db.ident(article_field) + " = %s"
            article_values.append(fixed[movement_field])

    article_search = "TRUE"
    search_values = []
    if query := (raw.get("q") or "").strip():
        article_search = '''concat_ws(' ', a."NomArticle", a."CodeArticleInterne",
            a."CodeArticleExterne", a."RefArticle", a."CategorieArticle", a."TypeArticle") ILIKE %s'''
        search_values.append(f"%{query}%")
    only_matched = bool(applied) or any(raw.get(key) not in (None, "", "all") for key in MOVEMENT_FILTERS)
    if only_matched:
        article_search, search_values = "FALSE", []

    sql = f'''
        WITH day AS (
            SELECT %s::date AS start_at, %s::date + interval '1 day' AS end_at
        ), selected_depot AS (
            SELECT "ID_Depot", "IdEntiteFk", "NomDepot"
            FROM logistique."T_Depot" WHERE "ID_Depot" = %s
        ), matched AS (
            SELECT v."ID_Mvt", v."ID_ArticleFk"
            FROM {row_source(movements)} WHERE {matched_where}
        ), articles AS (
            SELECT a."ID_Article", a."NomArticle", a."CodeArticleInterne", a."RefArticle",
                   a."CategorieArticle", a."AbrUnite" AS "Unite", a."IdEntiteFk",
                   e."NomEntite", sd."NomDepot", sd."ID_Depot"
            FROM logistique."V_Article" a
            LEFT JOIN systeme."T_Entite" e ON e."IdEntite" = a."IdEntiteFk"
            LEFT JOIN selected_depot sd ON sd."IdEntiteFk" = a."IdEntiteFk"
            WHERE {article_where} AND (%s::bigint IS NULL OR sd."ID_Depot" IS NOT NULL)
              AND (({article_search}) OR EXISTS (
                  SELECT FROM matched f WHERE f."ID_ArticleFk" = a."ID_Article"
              ))
        ), journal AS (
            SELECT m."ID_Mvt", m."ID_ArticleFk", m."ID_DepotFk", m."CodeCmd", m."NomTypeMvt",
                   m."QteMvtSigned", coalesce(m."DateMvt", m."DateHeureAutoMvt") AS occurred_at,
                   day.start_at
            FROM logistique."V_Mouvement" m
            JOIN articles a ON a."ID_Article" = m."ID_ArticleFk"
              AND a."IdEntiteFk" IS NOT DISTINCT FROM m."IdEntiteFk"
              AND (a."ID_Depot" IS NULL OR a."ID_Depot" = m."ID_DepotFk")
            CROSS JOIN day
            WHERE coalesce(m."DateMvt", m."DateHeureAutoMvt") < day.end_at
               OR (m."DateMvt" IS NULL AND m."DateHeureAutoMvt" IS NULL)
        ), balances AS (
            SELECT "ID_ArticleFk",
                   coalesce(sum("QteMvtSigned") FILTER (
                       WHERE occurred_at < start_at OR occurred_at IS NULL), 0) AS opening,
                   coalesce(sum("QteMvtSigned") FILTER (
                       WHERE occurred_at >= start_at AND "QteMvtSigned" > 0), 0) AS entries,
                   coalesce(sum(-"QteMvtSigned") FILTER (
                       WHERE occurred_at >= start_at AND "QteMvtSigned" < 0), 0) AS exits,
                   coalesce(sum("QteMvtSigned"), 0) AS closing,
                   count(*) FILTER (WHERE occurred_at IS NULL AND "QteMvtSigned" <> 0) AS undated
            FROM journal GROUP BY "ID_ArticleFk"
        ), running AS (
            SELECT j.*, b.opening + sum(coalesce(j."QteMvtSigned", 0)) OVER (
                PARTITION BY j."ID_ArticleFk" ORDER BY j.occurred_at, j."ID_Mvt"
                ROWS UNBOUNDED PRECEDING
            ) AS balance
            FROM journal j JOIN balances b USING ("ID_ArticleFk")
            WHERE j.occurred_at >= j.start_at
        ), summary AS (
            SELECT 0 AS section, day.start_at AS "Jour", a."ID_Article", a."NomArticle",
                   a."CodeArticleInterne", a."RefArticle", a."CategorieArticle", a."Unite",
                   a."NomEntite", coalesce(a."NomDepot", 'Tous les dépôts') AS "NomDepot",
                   NULL::timestamp AS "DateFicheStock", NULL::integer AS "ID_Mvt",
                   NULL::text AS "NomTypeMvt", NULL::text AS "CodeCmd",
                   coalesce(b.opening, 0) AS "Ouverture", coalesce(b.entries, 0) AS "Entrees",
                   coalesce(b.exits, 0) AS "Sorties", coalesce(b.closing, 0) AS "Cloture",
                   coalesce(b.undated, 0) AS "NonDates"
            FROM articles a CROSS JOIN day
            LEFT JOIN balances b ON b."ID_ArticleFk" = a."ID_Article"
            WHERE coalesce(b.opening, 0) <> 0 OR b.entries <> 0 OR b.exits <> 0
               OR EXISTS (SELECT FROM matched f WHERE f."ID_ArticleFk" = a."ID_Article")
            LIMIT %s
        ), detail AS (
            SELECT 1, r.start_at, a."ID_Article", a."NomArticle", a."CodeArticleInterne",
                   a."RefArticle", a."CategorieArticle", a."Unite", a."NomEntite", d."NomDepot",
                   r.occurred_at, r."ID_Mvt", r."NomTypeMvt", r."CodeCmd", NULL::numeric,
                   greatest(r."QteMvtSigned", 0), greatest(-r."QteMvtSigned", 0), r.balance, NULL::bigint
            FROM running r JOIN matched f ON f."ID_Mvt" = r."ID_Mvt"
            JOIN articles a ON a."ID_Article" = r."ID_ArticleFk"
            LEFT JOIN logistique."T_Depot" d ON d."ID_Depot" = r."ID_DepotFk"
            LIMIT %s
        )
        SELECT * FROM summary UNION ALL SELECT * FROM detail
        ORDER BY section, "NomEntite", "NomArticle", "ID_Article", "DateFicheStock", "ID_Mvt"
    '''
    return sql, [day, day, depot_id, *matched_values, *article_values, depot_id,
                 *search_values, limit, limit], applied


def daily_stock_card_workbook(actor, kind, raw, file_format):
    from .excel import MAX_EXPORT_ROWS, write_workbook

    if kind != "mouvements" or file_format != "xlsx" or {"take", "skip"} & raw.keys():
        raise APIError("Ce rapport journalier est disponible en Excel depuis les mouvements de stock.")
    require_tabs(actor, "articles", "mouvements", action="export")
    try:
        day = date.fromisoformat(raw.get("dateFrom", ""))
        if raw.get("dateTo") != day.isoformat() or raw["dateFrom"] != day.isoformat():
            raise ValueError
    except (ValueError, TypeError):
        raise APIError("Choisissez une seule date pour le rapport journalier.") from None

    zone = document_zone({})
    depot_id = requested_depot(actor, raw)
    depot = db.one(
        'SELECT "NomDepot" FROM logistique."T_Depot" WHERE "ID_Depot" = %s', [depot_id],
    ) if depot_id is not None else None
    entity = read_entity(actor)
    company = db.one(
        'SELECT "NomEntite" FROM systeme."T_Entite" WHERE "IdEntite" = %s', [entity],
    ) if entity is not None else None
    sql, values, applied = report_query(actor, raw, day, depot_id, MAX_EXPORT_ROWS + 1)
    context = {
        "title": "Fiches de stock journalières",
        "scope": company["NomEntite"] if company else "Toutes les entreprises autorisées",
        "coverage": "Une ligne par article et par entreprise. Détail selon les filtres du registre.",
        "generated": datetime.now(zone).strftime("%d/%m/%Y %H:%M"),
        "zone": str(zone), "tz": zone,
        "source": "logistique.V_Mouvement, logistique.V_Article",
        "raw": raw, "filters": applied,
        "order": "Entreprise, article, date et numéro du mouvement",
        "document_metadata": [
            ("Dépôt", depot["NomDepot"] if depot else "Tous les dépôts"),
            ("Périmètre des soldes", "Stock physique total du périmètre, calculé avec tous les mouvements des articles retenus."),
            ("Mouvements non datés", "Les mouvements historiques sans date sont repris dans le stock d’ouverture."),
        ],
    }
    output = SpooledTemporaryFile(max_size=8 * 1024 * 1024, mode="w+b")
    try:
        with connection.cursor() as cursor:
            cursor.execute(sql, values)
            names = [description[0] for description in cursor.description]

            def rows():
                while batch := cursor.fetchmany(500):
                    for row in batch:
                        yield row

            groups = groupby(rows(), key=lambda row: row[0])
            section, first = next(groups, (None, ()))
            summary = (dict(zip(names, row)) for row in first) if section == 0 else ()

            def details():
                movement_rows = first if section == 1 else next(groups, (None, ()))[1]
                for row in movement_rows:
                    yield dict(zip(names, row))

            count = write_workbook(
                output, export_fields(SUMMARY_COLUMNS), summary, context, sheet_name="Synthèse",
                detail=("Mouvements", export_fields(MOVEMENT_COLUMNS), details()),
            )
        output.seek(0)
        return output, count, f"SauverNdeko_FichesStock_{day.isoformat()}.xlsx"
    except Exception:
        output.close()
        raise
