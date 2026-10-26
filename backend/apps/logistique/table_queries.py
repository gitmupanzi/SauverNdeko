"""Filtres typés et ordre partagés par les listes et les exports logistiques."""
import json
import re
from datetime import date
from decimal import Decimal, InvalidOperation
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError
from django.conf import settings
from apps.core import db
from apps.core.responses import APIError

LABELS = {"QteMvt":"Quantité du mouvement","MontantMvtSigned":"Valeur signée","ModeReglement":"Mode de règlement","ID_Reglement":"N° écriture","EstEnRetard":"En retard","AvoirAEtablir":"Avoir à établir","MontantFacture":"Montant facturé","MontantBon":"Valeur du bon d’origine","MontantAvoirAEtablir":"Avoir à établir","EtatLigne":"Contrôle de la ligne","ObsCmdDetail":"Observations","RemiseCmdDetail":"Remise","LieuCmdDetail":"Lieu","SelectCmdDetail":"Sélection enregistrée","DeviseCode":"Devise","DeviseLibelle":"Libellé de devise","MontantsParDevise":"Montants par devise","PoidsUnitaire":"Poids unitaire","UnitePoids":"Unité de poids","NombreLots":"Nombre de lots","InformationArticle":"Informations sur l’article","CodeArticleInterne":"Code article","NomArticle":"Article","RefArticle":"Référence","TypeArticle":"Type","CategorieArticle":"Catégorie","Unite":"Unité","AbrUnite":"Unité","QteArticle":"Stock actuel","QteMinArticle":"Seuil","QteACommander":"À commander","PUArticle":"Prix d’achat","PVArticle":"Prix de vente","ValeurStockAchat":"Valeur au prix d’achat","MargeUnitaire":"Marge unitaire","DatePeremptionArticle":"Péremption","EtatStock":"État du stock","EtatPeremption":"État de péremption","ValideArticle":"Actif","CodeCmd":"Bon de stock","RefCmd":"Référence","DateCmd":"Date du bon","TypeCmd":"Type","StatutCmd":"Statut","NomClientSaisi":"Tiers","NbLignes":"Lignes","NbArticlesDistincts":"Articles distincts","QteTotale":"Quantité totale","MontantHT":"Montant HT","MontantTTC":"Montant TTC","CodeFacture":"Facture","DateFacture":"Date de facture","DateEcheancePaiement":"Échéance","MontantRegleFacture":"Réglé","MontantResteFacture":"Solde à régler","TotalRegleReel":"Réglé","ResteReel":"Solde à régler","EtatPaiement":"Paiement","EtatControleCommande":"Contrôle","QteCmdDetail":"Quantité","PUCmdDetail":"Prix unitaire","MontantLigne":"Montant","DateMvt":"Date du mouvement","NomTypeMvt":"Type de mouvement","QteMvtSigned":"Quantité signée","PUMvt":"Prix unitaire","MontantMvt":"Montant","OrigineMouvement":"Origine","Mois":"Mois","ConsoMensuelle":"Consommation","ValeurConsoMensuelle":"Valeur","StockActuel":"Stock actuel","ConsoMoyMensuelle":"Consommation moyenne","CouvertureMois":"Couverture en mois","EtatCouverture":"Couverture","StockArticle":"Stock courant","StockMouvements":"Stock des mouvements","Ecart":"Écart","EtatAuditStock":"Contrôle","DateReglement":"Date de règlement","MontantRegle":"Réglé","CodeFactureFk":"Facture","TotalRegle":"Réglé","Reste":"Solde à régler","EtatReglement":"Paiement"}
# Les exports d’une ligne utilisent les clés numériques exactes, dans le périmètre autorisé.
LABELS.update({"ID_Article":"Article","ID_Commande":"Bon de stock","ID_CmdFk":"Bon de stock","ID_ArticleFk":"Article","ID_Mvt":"Mouvement"})
NUMERIC = {"smallint","integer","bigint","numeric","decimal","real","double precision"}
DATES = {"date","timestamp without time zone","timestamp with time zone"}

def document_zone(raw):
    name = raw.get("timeZone") or settings.TIME_ZONE
    try:
        return ZoneInfo(name)
    except (ZoneInfoNotFoundError, ValueError, TypeError):
        raise APIError("Fuseau horaire invalide.")

def parse_column_filters(obj, raw):
    value = raw.get("columnFilters") or "{}"
    if isinstance(value, str):
        if len(value) > 8000:
            raise APIError("Trop de filtres.")
        try:
            value = json.loads(value)
        except (ValueError, TypeError):
            raise APIError("Filtres invalides.")
    if not isinstance(value, dict) or len(value) > 30:
        raise APIError("Filtres invalides.")
    columns = {col["column_name"]:col for col in obj["columns"]}
    clauses, params, applied = [], [], {}
    for key, item in value.items():
        if key not in columns or key not in LABELS or not isinstance(item, str):
            raise APIError("Colonne de filtre non autorisée.")
        item = item.strip()
        if not item:
            continue
        if len(item) > 300:
            raise APIError("Filtre trop long.")
        field = "v." + db.ident(key)
        kind = columns[key]["data_type"]
        if kind in NUMERIC:
            match = re.fullmatch(r"\s*(>=|<=|>|<|=|≥|≤)?\s*([+-]?(?:\d+(?:[.,]\d*)?|[.,]\d+))\s*", item)
            if not match:
                raise APIError("Filtre numérique invalide : " + LABELS[key] + ".")
            try:
                number = Decimal(match[2].replace(",", "."))
                if not number.is_finite() or len(match[2]) > 50:
                    raise InvalidOperation
            except InvalidOperation:
                raise APIError("Nombre invalide.")
            operator = {"≥":">=","≤":"<="}.get(match[1],match[1]) or "="
            clauses.append(field + operator + "%s")
            params.append(number)
        elif kind in DATES:
            try:
                day = date.fromisoformat(item)
            except ValueError:
                raise APIError("Date invalide : " + LABELS[key] + ".")
            if kind == "timestamp with time zone":
                clauses.append("(" + field + " AT TIME ZONE %s)::date=%s")
                params.extend([str(document_zone(raw)),day])
            else:
                clauses.append(field + "::date=%s")
                params.append(day)
        elif kind == "boolean":
            if item not in {"true","false"}:
                raise APIError("Valeur booléenne invalide.")
            clauses.append(field + "=%s")
            params.append(item == "true")
        elif kind in {"text","character varying","character"}:
            clauses.append("POSITION(LOWER(%s) IN LOWER(COALESCE(" + field + ",'')))>0")
            params.append(item)
        else:
            raise APIError("Type de filtre non pris en charge.")
        applied[key] = item
    return " AND ".join(clauses), params, applied

def query_order(obj, raw):
    column_names = [col["column_name"] for col in obj["columns"]]
    columns = set(column_names)
    view_keys = {
        "V_Article":["ID_Article"], "V_Commande":["ID_Commande"],
        "V_SuiviReglements":["ID_Commande"], "V_CommandeOverview":["ID_Commande"],
        "V_CommandesSansDetails":["ID_Commande"],
        "V_CommandeDetail":["ID_CmdFk","ID_ArticleFk"],
        "V_Mouvement":["ID_Mvt"], "V_MouvementStock":["ID_Mvt"],
        "V_ConsoMensuelle":["ID_Article","Mois"], "V_ConsoMensuelleDevise":["ID_Article","Mois","ID_DeviseFk"],
        "V_CouvertureStock":["ID_Article"], "V_AuditStock":["ID_Article"],
        "V_LotArticleStock":["ID_LotArticle"],
        "V_MouvementLot":["ID_MvtFk","ID_LotArticleFk"],
    }
    # Une clé stable départage les valeurs identiques entre page affichée et export.
    keys = obj.get("primaryKey") or [key for key in view_keys.get(obj["name"],[]) if key in columns] or column_names[:1]
    sort = raw.get("sortBy") or keys[0]
    direction = str(raw.get("sortDir","desc")).lower()
    if sort not in columns or direction not in {"asc","desc"}:
        raise APIError("Tri non autorisé.")
    order = "v." + db.ident(sort) + " " + direction.upper() + " NULLS LAST"
    for key in keys:
        if key != sort:
            order += ",v." + db.ident(key) + " ASC"
    return order, sort, direction
