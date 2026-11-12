"""Fiche de stock d'un article, calculée à partir des mouvements effectifs."""

import json

from apps.core import db
from apps.core.registry import view
from apps.core.repository import clean, get_record, positive
from apps.core.responses import APIError

from .depots import depot
from .ledger_registers import column, period_clause
from .reads import QUERY_KEYS, read_page, read_predicate, read_scope, row_source
from .tab_access import require_tabs


STOCK_CARD_FIELDS = (
    "DateFicheStock", "NomArticle", "CodeArticleInterne", "NomDepot",
    "TypeMvt", "CodeCmd", "EntreeFicheStock", "SortieFicheStock",
    "SoldeFicheStock", "Unite",
)


def stock_card_source(actor, article_id, raw):
    article_id = positive(article_id, "Article")
    article = get_record(view("logistique", "V_Article"), actor, {"ID_Article": article_id})
    requested = raw.get("depotId")
    owner = article.get("IdEntiteFk")
    selected = None
    if requested not in (None, "", "all"):
        if owner is None:
            raise APIError("Aucun dépôt rattaché à cet article.", "NOT_FOUND", 404)
        selected = depot(actor, requested, active=False, entity=owner)

    base = view("logistique", "V_Mouvement")
    date_field = "DateFicheStock"
    columns = [
        *base["columns"],
        column(date_field, "timestamp without time zone"),
        column("NomDepot", "text"),
        column("Unite", "character varying"),
        column("EntreeFicheStock", "numeric"),
        column("SortieFicheStock", "numeric"),
    ]
    # Seuls les identifiants déjà validés entrent dans cette projection. Les
    # critères de recherche et de période restent paramétrés à l'extérieur.
    conditions = [f'm."ID_ArticleFk" = {article_id}', 'm."QteMvtSigned" <> 0']
    if owner is not None:
        conditions.append(f'm."IdEntiteFk" = {positive(owner, "Entreprise")}')
    if selected is not None:
        conditions.append(f'm."ID_DepotFk" = {positive(selected["ID_Depot"], "Dépôt")}')
    movements = """
        SELECT m.*, coalesce(m."DateMvt", m."DateHeureAutoMvt") AS "DateFicheStock",
               d."NomDepot", u."AbrGenerique" AS "Unite",
               greatest(m."QteMvtSigned", 0) AS "EntreeFicheStock",
               greatest(-m."QteMvtSigned", 0) AS "SortieFicheStock"
          FROM logistique."V_Mouvement" m
          LEFT JOIN logistique."T_Depot" d ON d."ID_Depot" = m."ID_DepotFk"
          JOIN logistique."T_Article" a ON a."ID_Article" = m."ID_ArticleFk"
          LEFT JOIN referentiel."T_Generique" u ON u."ID_Generique" = a."ID_UniteFk"
         WHERE """ + " AND ".join(conditions)
    ledger = {
        **base,
        "columns": columns,
        "primaryKey": ["ID_Mvt"],
        "_date_field": date_field,
        "_row_source": "(" + movements + ") v",
        "_depot_scope": selected["ID_Depot"] if selected else None,
    }
    obj = {
        **ledger,
        "columns": [*columns, column("SoldeFicheStock", "numeric")],
        "_row_source": """
            (SELECT m.*, sum(m."QteMvtSigned") OVER (
                ORDER BY m."DateFicheStock" ASC NULLS FIRST, m."ID_Mvt" ASC
                ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
            ) AS "SoldeFicheStock" FROM (""" + movements + ") m) v",
    }
    return article, selected, ledger, obj


def period_summary(actor, ledger, raw):
    # Les soldes englobent le journal entier du périmètre. La recherche et
    # les filtres de colonnes peuvent masquer des lignes sans changer le solde.
    opening, opening_values = period_clause(ledger, "DateFicheStock", raw.get("dateFrom"), None, raw)
    closing, closing_values = period_clause(ledger, "DateFicheStock", None, raw.get("dateTo"), raw)
    # Les lignes historiques totalement non datées précèdent les lignes datées.
    before = (
        "NOT coalesce(" + opening + ", false)" if opening
        else '"DateFicheStock" IS NULL' if closing
        else "false"
    )
    through = "coalesce(" + closing + ", true)" if closing else "true"
    during = " AND ".join(clause for clause in (opening, closing) if clause) or "true"
    scope, scope_values = read_predicate(ledger, actor)
    return db.one(
        f'''SELECT coalesce(sum("QteMvtSigned") FILTER (WHERE {before}), 0) AS ouverture,
                   coalesce(sum("EntreeFicheStock") FILTER (WHERE {during}), 0) AS entrees,
                   coalesce(sum("SortieFicheStock") FILTER (WHERE {during}), 0) AS sorties,
                   coalesce(sum("QteMvtSigned") FILTER (WHERE {through}), 0) AS cloture,
                   count(*) FILTER (WHERE "DateFicheStock" IS NULL) AS "nonDates"
              FROM {row_source(ledger)} WHERE {scope}''',
        [*opening_values, *opening_values, *closing_values, *opening_values,
         *closing_values, *closing_values, *scope_values],
    )


def stock_card_criteria(raw):
    return {"sortBy": "DateFicheStock", "sortDir": "asc", **raw}


def stock_card(actor, article_id, raw):
    criteria = stock_card_criteria(raw)
    article, selected, ledger, obj = stock_card_source(actor, article_id, criteria)
    rows, meta, _ = read_page(obj, actor, criteria)
    meta["ficheStock"] = clean({
        **period_summary(actor, ledger, criteria),
        "unite": article.get("Unite"),
        "depot": selected["NomDepot"] if selected else None,
        "depots": db.query(
            '''SELECT "ID_Depot" AS id, "NomDepot" AS label
                 FROM logistique."T_Depot" WHERE "IdEntiteFk" = %s
                 ORDER BY "Principal" DESC, "NomDepot", "ID_Depot"''',
            [article.get("IdEntiteFk")],
        ),
    })
    return rows, meta


def stock_card_workbook(actor, kind, raw, file_format):
    if kind != "mouvements" or set(raw) - (QUERY_KEYS | {"articleId"}):
        raise APIError("Critère non autorisé pour la fiche de stock.")
    require_tabs(actor, "articles", "mouvements", action="export")
    criteria = stock_card_criteria(raw)
    article, selected, ledger, obj = stock_card_source(actor, raw.get("articleId"), criteria)
    _, where, values, order, sort, direction, applied = read_scope(obj, actor, criteria)
    summary = period_summary(actor, ledger, criteria)
    from .excel import scope_workbook

    criteria["columns"] = json.dumps(STOCK_CARD_FIELDS)
    metadata = [
        ("Article", article["NomArticle"]),
        ("Dépôt", selected["NomDepot"] if selected else "Tous les dépôts"),
        ("Unité", article.get("Unite") or "—"),
        ("Stock d’ouverture", summary["ouverture"]),
        ("Entrées de la période", summary["entrees"]),
        ("Sorties de la période", summary["sorties"]),
        ("Stock de clôture", summary["cloture"]),
        ("Mouvements non datés", summary["nonDates"]),
    ]
    return scope_workbook(
        actor, "FicheStock-" + str(article["ID_Article"]), obj, criteria, where,
        values, order, sort, direction, applied, "Fiche de stock",
        file_format=file_format, document_metadata=metadata,
    )
