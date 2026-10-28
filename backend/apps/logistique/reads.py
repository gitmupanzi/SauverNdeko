from .table_queries import parse_column_filters, query_order, document_zone
"""Lectures logistiques paginées : même périmètre pour mesure, registre et consultation."""
from datetime import date, datetime, timezone
from rest_framework.views import APIView
from apps.core import db
from apps.core.permissions import IsERPAdmin, scope_for
from apps.core.registry import view, model
from apps.core.repository import predicate, page, get_record, positive, clean
from apps.core.responses import ok, APIError
from .currency import MONETARY_KEYS, amounts_by_currency, scalar_amount, validate_currency

QUERY_KEYS = {"q", "dateFrom", "dateTo", "take", "skip", "sortBy", "sortDir", "columnFilters", "timeZone", "deviseId"}
INDICATORS = {
    "articles": ("V_Article", "TRUE", "COUNT(*)", "Articles", "produit", "Tous les articles autorisés."),
    "commandes": ("V_Commande", "TRUE", "COUNT(*)", "Bons de stock", "commande", "Tous les bons de stock autorisés."),
    "alertesStock": ("V_Article", '"EstAlerteStock"=true AND "EstRupture"=false', "COUNT(*)", "Stock faible", "produit", "Stock positif inférieur ou égal au seuil défini."),
    "ruptures": ("V_Article", '"EstRupture"=true', "COUNT(*)", "Ruptures", "produit", "Articles dont le stock courant est nul ou négatif."),
    "commandesSansDetails": ("V_Commande", '"EstCommandeSansDetails"=true', "COUNT(*)", "Bons sans lignes", "commande", "Bons de stock sans ligne de détail."),
    "facturesEnRetard": ("V_Commande", '"DateEcheancePaiement"<CURRENT_TIMESTAMP AND "MontantResteFacture">0', "COUNT(*)", "Factures en retard", "commande", "Échéance dépassée et montant restant positif."),
    "montantTotalFacture": ("V_Commande", "TRUE", 'SUM("MontantTTC")', "Total des bons de stock", "commande", "Somme des montants TTC des bons de stock."),
    "montantTotalRegle": ("V_SuiviReglements", "TRUE", 'SUM("TotalRegle")', "Montant réglé", "commande", "Somme des règlements rattachés aux factures."),
    "montantRestant": ("V_SuiviReglements", "TRUE", 'SUM("Reste")', "Reste à régler", "commande", "Somme des restes des factures."),
    "auditTotal": ("V_AuditStock", "TRUE", "COUNT(*)", "Articles contrôlés", "produit", "Articles présents dans le contrôle des stocks."),
    "auditCoherents": ("V_AuditStock", '"EstStockCoherent"=true', "COUNT(*)", "Stocks cohérents", "produit", "Stock courant égal au stock issu des mouvements."),
    "auditEcarts": ("V_AuditStock", '"Ecart"<>0', "COUNT(*)", "Écarts de stock", "produit", "Écart non nul entre stock courant et mouvements."),
    "coherenceRate": ("V_AuditStock", '"EstStockCoherent" IS NOT NULL', 'ROUND(AVG(CASE WHEN "EstStockCoherent" THEN 100.0 ELSE 0 END),2)', "Taux de cohérence", "produit", "Part des stocks cohérents parmi les contrôles renseignés."),
    "couvertureCritique": ("V_CouvertureStock", '"CouvertureMois" IS NOT NULL AND "CouvertureMois"<=1', "COUNT(*)", "Couverture courte", "produit", "Couverture connue inférieure ou égale à un mois."),
}
INVOICE = '"CodeFacture" IS NOT NULL AND BTRIM("CodeFacture")<>\'\''
INDICATORS.update({
    "peremptionProche": ("V_Article", '"EstAlertePeremption"=true', "COUNT(*)", "Péremption proche", "produit", "Articles ayant un stock encore disponible proche de sa péremption."),
    "articlesPerimes": ("V_Article", '"EstPerime"=true', "COUNT(*)", "Articles périmés", "produit", "Articles ayant encore du stock périmé, par lot ou sans lot."),
    "commandesEnAttente": ("V_Commande", "UPPER(BTRIM(COALESCE(\"StatutCmd\",''))) IN ('EN ATTENTE','ATTENTE')", "COUNT(*)", "Bons en attente", "commande", "Bons dont le statut est En attente ou Attente."),
    "commandesEnCours": ("V_Commande", "UPPER(BTRIM(COALESCE(\"StatutCmd\",'')))='EN COURS'", "COUNT(*)", "Bons en cours", "commande", "Bons dont le statut est En cours."),
    "commandesEntree": ("V_Commande", '"EstCommandeEntree"=true', "COUNT(*)", "Bons d’entrée", "commande", "Bons de stock de type Entrée."),
    "commandesSortie": ("V_Commande", '"EstCommandeSortie"=true', "COUNT(*)", "Bons de sortie", "commande", "Bons de stock de type Sortie."),
    "commandesNonFacturees": ("V_Commande", '"CodeFacture" IS NULL OR BTRIM("CodeFacture")=\'\'', "COUNT(*)", "Bons non facturés", "commande", "Bons sans référence de facture."),
    "montantBons": ("V_Commande", "TRUE", 'SUM("MontantTTC")', "Valeur des bons", "commande", "Somme des montants TTC des bons de stock."),
    "factures": ("V_Commande", INVOICE, "COUNT(*)", "Factures", "commande", "Bons portant une référence de facture non vide."),
    "facturesSoldees": ("V_Commande", INVOICE + ' AND "MontantResteFacture"<=0', "COUNT(*)", "Factures soldées", "commande", "Factures dont le solde restant est nul ou négatif."),
    "facturesPartielles": ("V_Commande", INVOICE + ' AND "MontantRegleFacture">0 AND "MontantResteFacture">0', "COUNT(*)", "Partiellement réglées", "commande", "Factures avec un règlement positif et un solde restant positif."),
    "facturesARegler": ("V_Commande", INVOICE + ' AND "MontantResteFacture">0', "COUNT(*)", "Factures à régler", "commande", "Factures dont le solde restant est positif."),
    "facturesEnRetard": ("V_Commande", INVOICE + ' AND "DateEcheancePaiement"<CURRENT_TIMESTAMP AND "MontantResteFacture">0', "COUNT(*)", "Factures en retard", "commande", "Factures à solde positif dont l’échéance est dépassée."),
    "montantTotalFacture": ("V_Commande", INVOICE, 'SUM("MontantFacture")', "Montant facturé", "commande", "Somme des factures émises : quantités nettes lors de l’émission, hors avoirs à établir."),
    "montantTotalRegle": ("V_SuiviReglements", INVOICE, 'SUM("TotalRegle")', "Montant réglé", "commande", "Somme des règlements des factures du périmètre."),
    "montantRestant": ("V_SuiviReglements", INVOICE, 'SUM("Reste")', "Solde à régler", "commande", "Somme des soldes restants des factures du périmètre."),
})

BASE_QUERY_KEYS = QUERY_KEYS | {"typeId", "categorieId", "uniteId", "statutId", "client", "statut", "stockState", "peremption", "sansDetails", "payment", "control"}

def params_only(raw):
    return {key: value for key, value in raw.items() if key in QUERY_KEYS and value not in (None, "")}

def row_source(obj):
    return obj.get("_row_source") or db.qualified(obj["schema"], obj["name"]) + " v"

def source_for_indicator(key, name):
    obj = view("logistique", name)
    if key.startswith("factures") or key in {"montantTotalFacture", "montantTotalRegle", "montantRestant"}:
        obj = {**obj, "_date_field": "DateFacture"}
    return obj

def read_predicate(obj, actor, raw=None, fixed_filters=None):
    params = params_only(raw or {})
    period = {key: params.pop(key) for key in ["dateFrom", "dateTo"] if params.get(key)}
    params["filters"] = fixed_filters or {}
    where, values = predicate(obj, actor, params)
    if obj.get("_composition_scope"):
        from apps.core.tenancy import require_entity
        where += ' AND v."IdEntiteFk"=%s'
        values.append(require_entity(actor))
    from .ledger_registers import period_clause
    columns = {col['column_name'] for col in obj['columns']}
    field=obj.get('_date_field') or next((key for key in ['DateMvt','DateCmd','DateReglement','DateFacture','Mois'] if key in columns),None)
    if field:
        clause,bind=period_clause(obj,field,period.get('dateFrom'),period.get('dateTo'),raw or {})
        if clause:where+=' AND '+clause;values.extend(bind)
    if obj.get('_extra_period'):
        field,begin,end=obj['_extra_period'];clause,bind=period_clause(obj,field,begin,end,raw or {})
        if clause:where+=' AND '+clause;values.extend(bind)
    return where, values

def read_scope(obj, actor, raw=None, condition="TRUE", fixed_filters=None, population_query=None):
    raw = raw or {}
    params = params_only(raw)
    where, values = read_predicate(obj, actor, params, fixed_filters)
    if population_query is not None:
        population_where, population_values = predicate(obj, actor, {"q": population_query})
        where += " AND (" + population_where + ")"
        values = [*values, *population_values]
    where += " AND (" + condition + ")"
    column_where, column_values, applied = parse_column_filters(obj, raw)
    if column_where:
        where += " AND (" + column_where + ")"
        values = [*values, *column_values]
    order, sort, direction = query_order(obj, params)
    return params, where, values, order, sort, direction, applied

def read_page(obj, actor, raw=None, condition="TRUE", fixed_filters=None, population_query=None):
    params, where, values, order, sort, direction, applied = read_scope(obj, actor, raw, condition, fixed_filters, population_query)
    take, skip = page(params)
    columns = [col["column_name"] for col in obj["columns"]]
    source = row_source(obj)
    scope, scope_values = read_predicate(obj, actor, {}) if obj.get("_composition_scope") else scope_for(obj, actor)
    total = db.one("SELECT COUNT(*) AS n FROM " + source + " WHERE (" + scope + ") AND ("+obj.get("_base_condition","TRUE")+")", scope_values)["n"]
    count = db.one("SELECT COUNT(*) AS n FROM " + source + " WHERE " + where, values)["n"]
    rows = db.query("SELECT v.* FROM " + source + " WHERE " + where + " ORDER BY " + order + " LIMIT %s OFFSET %s", [*values,take,skip])
    return clean(rows), {"columns":columns, "columnTypes":{col["column_name"]:col["data_type"] for col in obj["columns"]}, "totalCount":total, "filteredCount":count, "count":len(rows), "take":take, "skip":skip, "sortBy":sort, "sortDir":direction, "columnFilters":applied}, (where,values)

def metric_value(obj, actor, raw, condition, expression, fixed_filters=None):
    where, values = read_predicate(obj, actor, raw, fixed_filters)
    if expression.startswith("SUM("):
        return scalar_amount(amounts_by_currency(obj, row_source(obj), where + " AND (" + condition + ")", values, expression))
    # Les expressions sont des constantes du registre ci-dessus.
    value = db.one("SELECT " + expression + " AS value FROM " + row_source(obj) + " WHERE " + where + " AND (" + condition + ")", values)["value"]
    return value

def resolve_indicator(key, raw):
    fixed_filters = None
    if key == "articlesCategorie":
        category = raw.get("categorieId")
        if category in (None, ""):
            raise APIError("Catégorie requise.")
        fixed_filters = {"ID_CategorieArticleFk": None if category == "sans-categorie" else positive(category)}
        rule = ("V_Article", "TRUE", "COUNT(*)", "Articles par catégorie", "produit", "Articles de la catégorie sélectionnée, dans le périmètre autorisé.")
    else:
        if key not in INDICATORS:
            raise APIError("Indicateur introuvable.", "NOT_FOUND", 404)
        rule = INDICATORS[key]
    name, condition, expression, label, kind, definition = rule
    obj = source_for_indicator(key, name)
    return obj, condition, expression, label, kind, definition, fixed_filters

def indicator_details(actor, key, raw):
    obj, condition, expression, label, kind, definition, fixed_filters = resolve_indicator(key, raw)
    name = obj["name"]
    population_query = raw.get("populationQ")
    metric_criteria = {**raw, "q": population_query} if population_query is not None else dict(raw)
    metric_criteria.pop("columnFilters", None)
    rows, meta, _ = read_page(obj, actor, raw, condition, fixed_filters=fixed_filters, population_query=population_query)
    groups = None
    if key in MONETARY_KEYS:
        where, values = read_predicate(obj, actor, metric_criteria, fixed_filters)
        groups = amounts_by_currency(obj, row_source(obj), where + " AND (" + condition + ")", values, expression)
    value = scalar_amount(groups) if groups is not None else metric_value(obj, actor, metric_criteria, condition, expression, fixed_filters)
    meta["indicator"] = {"key":key, "label":label, "value":value, "definition":definition, "kind":kind, "source":name, "unit":"%" if key == "coherenceRate" else None}
    if groups is not None:
        meta["indicator"]["amountsByCurrency"] = groups

    return rows, meta

def overview(actor, raw):
    raw = params_only(raw)
    totals, grouped = {}, {}
    for key, rule in INDICATORS.items():
        name, condition, expression, *_ = rule
        obj = source_for_indicator(key, name)
        if key in MONETARY_KEYS:
            where, values = read_predicate(obj, actor, raw)
            grouped[key] = amounts_by_currency(obj, row_source(obj), where + " AND (" + condition + ")", values, expression)
            totals[key] = scalar_amount(grouped[key])
        else:
            totals[key] = metric_value(obj, actor, raw, condition, expression)
    article_source = view("logistique", "V_Article")
    where, values = read_predicate(article_source, actor, raw)
    categories = db.query('SELECT "ID_CategorieArticleFk" AS id, COALESCE(NULLIF(BTRIM("CategorieArticle"),\'\'),\'Sans catégorie\') AS label, COUNT(*) AS count FROM ' + row_source(article_source) + ' WHERE ' + where + ' GROUP BY "ID_CategorieArticleFk", "CategorieArticle" ORDER BY label', values)
    return {"totals": totals, "amountsByCurrency": grouped, "activeCurrency": validate_currency(raw["deviseId"],unchanged=True) if raw.get("deviseId") not in (None,"","all","sans-devise") else None, "categories": categories, "definitions": {key: rule[5] for key, rule in INDICATORS.items()}, "highlights": {}, "criteria": raw, "currency": None, "generatedAt": datetime.now(timezone.utc)}

def register_source(kind, raw, for_export=False):
    from .ledger_registers import KINDS, register_source as ledger_source
    if kind in KINDS:return ledger_source(kind,raw,for_export)
    if kind not in {"articles", "commandes", "lignes"}:
        raise APIError("Registre introuvable.", "NOT_FOUND", 404)
    unknown = set(raw) - (BASE_QUERY_KEYS | ({"contexte"} if kind == "articles" else set()) | ({"commandeId","articleId","etat"} if kind == "lignes" else set()) | ({"columns","selection"} if for_export else set()))
    if unknown:
        raise APIError("Critère non autorisé.")
    if kind == "lignes":
        obj = view("logistique", "V_CommandeDetail")
        filters = {field:positive(raw[key]) for key,field in {"commandeId":"ID_CmdFk","articleId":"ID_ArticleFk","typeId":"ID_TypeCmdFk","statutId":"ID_StatutCmdFk"}.items() if raw.get(key) not in (None,"")}
        states={"all":"TRUE","conforme":'"EtatLigne"=\'Valide\'',"incoherente":'"EtatLigne"<>\'Valide\''}
        state=raw.get("etat") or "all"
        if state not in states:raise APIError("État de ligne invalide.")
        return obj,states[state],filters
    article = kind == "articles"
    obj = view("logistique", "V_Article" if article else "V_Commande")
    if not article:
        # La vue commune ne produit jamais une somme de quantités d’unités différentes.
        names=[col["column_name"] for col in obj["columns"] if col["column_name"]!="QteTotale"]
        projection=",".join("c."+db.ident(name) for name in names)
        obj={**obj,"columns":[*obj["columns"],{"column_name":"QuantitesParUnite","data_type":"jsonb","is_nullable":"YES"}],
             "_row_source":"(SELECT "+projection+",CASE WHEN q.\"NombreUnites\" IS NULL THEN 0::numeric ELSE q.\"QuantiteHomogene\" END AS \"QteTotale\",COALESCE(q.\"QuantitesParUnite\",'[]'::jsonb) AS \"QuantitesParUnite\" FROM logistique.\"V_Commande\" c LEFT JOIN logistique.\"V_QuantitesBonUnite\" q ON q.\"ID_CmdFk\"=c.\"ID_Commande\") v"}
    filters = {}
    if article:
        context = raw.get("contexte")
        if context not in (None,"","composition"):
            raise APIError("Contexte de catalogue non autorisé.")
        if context == "composition":obj = {**obj,"_composition_scope":True}
    mapping = {"typeId": "ID_TypeArticleFk", "categorieId": "ID_CategorieArticleFk", "uniteId": "ID_UniteFk"} if article else {"typeId": "ID_TypeCmdFk", "statutId": "ID_StatutCmdFk", "client": "ID_TiersFk"}
    for key, field in mapping.items():
        if raw.get(key) not in (None, ""):
            filters[field] = positive(raw[key])
    conditions = ["TRUE"]
    if article:
        if raw.get("statut") not in (None, "", "all"):
            if raw["statut"] not in {"true", "false"}:
                raise APIError("État invalide.")
            filters["ValideArticle"] = raw["statut"] == "true"
        states = {"all": "TRUE", "rupture": '"EstRupture"=true', "faible": '"EstAlerteStock"=true AND "EstRupture"=false', "disponible": '"QteArticle">0 AND ("QteMinArticle" IS NULL OR "QteArticle">"QteMinArticle")'}
        expiry = {"all": "TRUE", "perime": '"EstPerime"=true', "alerte": '"EstAlertePeremption"=true', "non-renseignee": '"StockSansDatePeremption">0', "valide": '"EtatPeremption"=\'Valide\''}
        for key, rules in [("stockState", states), ("peremption", expiry)]:
            selected = raw.get(key) or "all"
            if selected not in rules:
                raise APIError("État invalide.")
            conditions.append(rules[selected])
    else:
        if raw.get("sansDetails") == "true":
            conditions.append('"EstCommandeSansDetails"=true')
        payments = {"all": "TRUE", "": "TRUE", "reglee": '"CodeFacture" IS NOT NULL AND "MontantResteFacture"<=0', "partielle": '"MontantRegleFacture">0 AND "MontantResteFacture">0', "non-reglee": 'COALESCE("MontantRegleFacture",0)<=0 AND "MontantResteFacture">0', "non-facturee": '"CodeFacture" IS NULL', "retard": '"EstPaiementEnRetard"=true'}
        selected = raw.get("payment") or "all"
        if selected not in payments:
            raise APIError("État de paiement invalide.")
        conditions.append(payments[selected])
        controls = {"all": "TRUE", "sans-details": '"EstCommandeSansDetails"=true', "incoherente": '"EstMontantIncoherent"=true AND "EstCommandeSansDetails"=false', "coherente": '"EstMontantIncoherent"=false AND "EstCommandeSansDetails"=false'}
        control = raw.get("control") or "all"
        if control not in controls:
            raise APIError("Contrôle invalide.")
        conditions.append(controls[control])
    return obj, " AND ".join(conditions), filters

def register(actor, kind, raw):
    obj, condition, filters = register_source(kind, raw)
    article = kind == "articles"
    rows, meta, (where, values) = read_page(obj, actor, raw, condition, filters)
    if kind in {"mouvements","factures","reglements","lots"}:
        from .ledger_registers import annotate_metadata
        return rows,annotate_metadata(kind,obj,actor,raw,where,values,meta)
    if kind == "commandes":
        from .stock_returns import annotate_return_context,return_feature_ready
        from .invoices import storage_ready as invoice_storage_ready
        rows=annotate_return_context(rows,actor)
        meta["features"]={"returns":return_feature_ready(),"invoices":invoice_storage_ready()}
    if kind == "lignes":
        meta["summary"] = db.one('SELECT COUNT(*) AS total,COUNT(DISTINCT "ID_CmdFk") AS bons,COUNT(DISTINCT "ID_ArticleFk") AS articles FROM '+row_source(obj)+" WHERE "+where,values)
        return rows,meta
    expression = 'COUNT(*) AS total, COUNT(*) FILTER(WHERE "EstRupture"=true) AS rupture, COUNT(*) FILTER(WHERE "EstAlerteStock"=true AND "EstRupture"=false) AS faible, COUNT(*) FILTER(WHERE "QteArticle">0 AND ("QteMinArticle" IS NULL OR "QteArticle">"QteMinArticle")) AS disponible' if article else 'COUNT(*) AS total, SUM("NbLignes") AS totalLignes, COUNT(*) FILTER(WHERE "EstCommandeSansDetails"=true) AS sansDetails, COUNT(*) FILTER(WHERE "EstPaiementEnRetard"=true) AS enRetard'
    meta["summary"] = db.one("SELECT " + expression + " FROM " + row_source(obj) + " WHERE " + where, values)
    return rows, meta

SECTIONS = {
    "produit": {"lots": ("V_LotArticleStock", "ID_ArticleFk"), "commandes": ("V_CommandeDetail", "ID_ArticleFk"), "mouvements": ("V_Mouvement", "ID_ArticleFk"), "consommation": ("V_ConsoMensuelle", "ID_Article"), "couverture": ("V_CouvertureStock", "ID_Article"), "controle": ("V_AuditStock", "ID_Article")},
    "commande": {"lots": ("V_MouvementLot", "ID_cmdFk"), "lignes": ("V_CommandeDetail", "ID_CmdFk"), "mouvements": ("V_Mouvement", "ID_cmdFk"), "reglements": ("V_Reglements", "CodeFactureFk"), "facture": ("V_SuiviReglements", "ID_Commande")},
}
def consultation(actor, kind, pk, section, raw):
    if kind not in SECTIONS:
        raise APIError("Fiche introuvable.", "NOT_FOUND", 404)
    pk = positive(pk)
    header = get_record(view("logistique", "V_Article" if kind == "produit" else "V_Commande"), actor, {"ID_Article" if kind == "produit" else "ID_Commande": pk})
    if not section or section == "identite":
        data = {"record": header, "sections": ["identite", *SECTIONS[kind]]}
        from .followup_folders import record_folders
        data["dossiers"] = record_folders(actor,"article" if kind=="produit" else "bon",pk)
        if kind=="commande":
            invoices=record_folders(actor,"facture",pk)
            data["dossiers"]["items"].extend(invoices["items"])
        meta=None
        if kind=="commande":
            from .stock_returns import return_context,return_feature_ready
            from .invoices import storage_ready as invoice_storage_ready
            meta={"features":{"returns":return_feature_ready(),"invoices":invoice_storage_ready()},"returnContext":return_context(pk)}
        return clean(data), meta
    if section not in SECTIONS[kind]:
        raise APIError("Rubrique introuvable.", "NOT_FOUND", 404)
    name, field = SECTIONS[kind][section]
    if kind == "produit" and section == "consommation" and raw.get("deviseId") not in (None,"","all"):
        name = "V_ConsoMensuelleDevise"
    value = header.get("CodeFacture") if section == "reglements" else pk
    if section == "reglements" and not value:
        return [], {"filteredCount": 0, "totalCount": 0, "count": 0, "take": 25, "skip": 0, "columns": []}
    obj = model(name) if name.startswith("T_") else view("logistique", name)
    fixed = {field: value}
    rows, meta, _ = read_page(obj, actor, raw, fixed_filters=fixed)
    # Le total de la rubrique reste celui de cet objet, avant sa recherche locale.
    parent_where, parent_values = read_predicate(obj, actor, {}, fixed)
    meta["totalCount"] = db.one("SELECT COUNT(*) AS n FROM " + row_source(obj) + " WHERE " + parent_where, parent_values)["n"]
    if kind=="produit" and section=="lots":
        from .lots import stock_state
        meta["lotStock"]=clean(stock_state(pk))
    return rows, meta

class RegisterReadView(APIView):
    permission_classes = [IsERPAdmin]
    def get(self, request, kind):
        rows, meta = register(request.user, kind, request.query_params.dict())
        return ok(rows, meta=meta)

class OverviewReadView(APIView):
    permission_classes = [IsERPAdmin]
    def get(self, request):
        return ok(overview(request.user, request.query_params.dict()))

class IndicatorReadView(APIView):
    permission_classes = [IsERPAdmin]
    def get(self, request, key):
        rows, meta = indicator_details(request.user, key, request.query_params.dict())
        return ok(rows, meta=meta)

class ConsultationReadView(APIView):
    permission_classes = [IsERPAdmin]
    def get(self, request, kind, pk, section=None):
        data, meta = consultation(request.user, kind, pk, section, request.query_params.dict())
        return ok(data, meta=meta)
