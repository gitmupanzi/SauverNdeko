"""Permissions of the logistics workspaces, including aliases and linked records."""

from apps.core.module_access import can_use_tab, require_tab
from apps.core.responses import APIError


MODULE = "logistique"

REGISTER_TABS = {
    "articles": "articles",
    "tiers": "tiers",
    "lots": "lots",
    "commandes": "commandes",
    "lignes": "details",
    "mouvements": "mouvements",
    "factures": "factures",
    "reglements": "reglements",
    "immobilisations": "immobilisations",
    "depots": "depots",
    "stocks-depots": "stocks-depots",
    "transferts": "transferts",
    "inventaires": "inventaires",
    "lignes-inventaires": "inventaires",
}
DOCUMENT_TABS = {
    "bon": "commandes",
    "facture": "factures",
    "reglement": "reglements",
    "avoir": "factures",
    "immobilisation": "immobilisations",
}
FOLDER_TABS = {"article": "articles", "bon": "commandes", "facture": "factures"}
INVOICE_FIELDS = frozenset({
    "ID_Facture", "CodeFacture", "DateFacture", "DateHeureAutoFacture", "UrlFacture",
    "StatusFacture", "EstFactureSnapshot", "ValideRemiseFacture", "MontantFacture",
    "TauxTVAFacture", "MontantTVAFacture", "MontantHTFacture", "DateEcheancePaiement",
    "JoursAvantEcheance", "AvoirAEtablir", "MontantAvoirAEtablir", "AvoirImpute",
    "ID_ModePaiementFk", "ID_ConditionPaiementFk", "AbrModePaiement", "ModePaiement",
    "AbrConditionPaiement", "ConditionPaiement", "MontantNetARegler",
})
PAYMENT_FIELDS = frozenset({
    "MontantRegleFacture", "MontantResteFacture", "MontantRegleFactureCalc",
    "MontantResteFactureCalc", "TotalRegleReel", "ResteReel", "NbReglements",
    "DernierReglement", "EtatPaiement", "EstPaiementEnRetard",
    "TotalRegle", "Reste", "EtatReglement", "EstEnRetard",
})
LINE_FIELDS = frozenset({"ListeArticles"})
FINANCE_PROJECTIONS = {"V_Commande", "V_CommandeOverview", "V_CommandeDetail", "T_Commande", "V_SuiviReglements"}
CONSULTATION_TABS = {
    "produit": {
        "identite": "articles",
        "lots": "lots",
        "commandes": "details",
        "mouvements": "mouvements",
        "consommation": "mouvements",
        "couverture": "mouvements",
        "controle": "mouvements",
    },
    "commande": {
        "identite": "commandes",
        "lots": "lots",
        "lignes": "details",
        "mouvements": "mouvements",
        "reglements": "reglements",
        "facture": "factures",
    },
    "tiers": {"identite": "tiers", "bons": "commandes", "factures": "factures", "reglements": "reglements"},
}
STOCK_TABS = {"audit": "mouvements", "alertes": "articles", "consommation": "mouvements", "couverture": "mouvements"}

OBJECT_TABS = {
    "T_Article": "articles",
    "V_Article": "articles",
    "V_AlertStock": "articles",
    "T_Commande": "commandes",
    "V_Commande": "commandes",
    "V_CommandeOverview": "commandes",
    "V_CommandesSansDetails": "commandes",
    "V_CommandeDetail": "details",
    "T_Mouvement": "mouvements",
    "V_Mouvement": "mouvements",
    "V_MouvementStock": "mouvements",
    "V_AuditStock": "mouvements",
    "V_AuditStock_Theorique": "mouvements",
    "V_ConsoMensuelle": "mouvements",
    "V_ConsoMensuelleDevise": "mouvements",
    "V_CouvertureStock": "mouvements",
    "T_Reglements": "reglements",
    "V_Reglements": "reglements",
    "V_SuiviReglements": "factures",
    "V_LotArticleStock": "lots",
    "V_LotDisponibilite": "lots",
    "V_RegistreLots": "lots",
    "V_MouvementLot": "lots",
    "V_RegistreMouvementLot": "lots",
    "V_Immobilisation": "immobilisations",
}
SHARED_PATHS = {"references", "destinations", "entreprises", "entreprise/identite"}
DEPOT_SELECTION_TABS = {
    "dashboard", "depots", "stocks-depots", "articles", "lots", "commandes",
    "details", "mouvements", "inventaires", "transferts", "factures", "reglements",
}


def table_tab(interface_key):
    module, _, register = interface_key.partition(".")
    if module != MODULE:
        return None
    return REGISTER_TABS.get(register, {"tiers": "tiers", "details": "details", "dossiers": "dossiers"}.get(register))


def indicator_tabs(key):
    if key.startswith("articles") or key in {"alertesStock", "ruptures", "peremptionProche"}:
        return ("articles",)
    if key in {"montantTotalRegle", "montantRestant", "facturesSoldees", "facturesPartielles", "facturesARegler", "facturesEnRetard"}:
        return ("factures", "reglements")
    if key.startswith("factures") or key == "montantTotalFacture":
        return ("factures",)
    if key == "commandesNonFacturees":
        return ("commandes", "factures")
    if key.startswith("commandes") or key == "montantBons":
        return ("commandes",)
    return ("articles", "mouvements")


def require_tabs(actor, *tabs, action="read"):
    for tab in dict.fromkeys(tabs):
        require_tab(actor, MODULE, tab, action)


def can_read_tabs(actor, *tabs):
    return all(can_use_tab(actor, MODULE, tab) for tab in tabs)


def restricted_fields(actor, *, invoices=False, action="read"):
    result = set()
    if not invoices and not can_use_tab(actor, MODULE, "factures", action):
        result.update(INVOICE_FIELDS)
        result.update(PAYMENT_FIELDS)
    if not can_use_tab(actor, MODULE, "reglements", action):
        result.update(PAYMENT_FIELDS)
    if not can_use_tab(actor, MODULE, "details", action):
        result.update(LINE_FIELDS)
    return result


def mask_order(actor, record, *, invoices=False):
    denied = restricted_fields(actor, invoices=invoices)
    return {key: value for key, value in record.items() if key not in denied}


def validate_invoice_changes(actor, data, old):
    if any(data[field] != (old or {}).get(field) for field in INVOICE_FIELDS.intersection(data)):
        require_tabs(actor, "factures", action="manage")


def enforce_logistics_object(actor, name, action):
    tab = OBJECT_TABS.get(name)
    if not tab:
        raise APIError("Utilisez le registre Logistique correspondant.", "DEDICATED_ROUTE_REQUIRED", 403)
    require_tabs(actor, tab, action=action)
    if name in {"T_Commande", "V_Commande", "V_CommandeOverview"} and action in {"read", "export"}:
        require_tabs(actor, "factures", "reglements", "details", action=action)
    if name == "V_SuiviReglements" and action in {"read", "export"}:
        require_tabs(actor, "reglements", action=action)
    if name == "V_CommandeDetail":
        require_tabs(actor, "factures", action=action)
    if name in {"V_RegistreMouvementLot", "V_MouvementLot"}:
        require_tabs(actor, "mouvements", action=action)


def enforce_logistics_request(actor, request, view, action):
    path = request.path_info.rstrip("/")
    kwargs = getattr(view, "kwargs", {})
    if kwargs.get("schema") == MODULE:
        enforce_logistics_object(actor, kwargs.get("name"), action)
        return True

    module = kwargs.get("module", "")
    if not path.startswith("/api/logistique/") and not module.startswith("logistique/"):
        return False
    if module.startswith("logistique/"):
        tab = REGISTER_TABS.get(module.split("/")[1])
        if not tab:
            raise APIError("Utilisez le registre Logistique correspondant.", "DEDICATED_ROUTE_REQUIRED", 403)
        require_tabs(actor, tab, action=action)
        if tab == "reglements" and action == "manage":
            require_tabs(actor, "factures")
        if tab == "commandes" and action == "read" and (kwargs.get("pk") is None or kwargs.get("search")):
            # L’ancienne API générique expose la ligne entière, y compris ses informations financières.
            require_tabs(actor, "factures", "reglements", "details")
        return True

    relative = path.removeprefix("/api/logistique/")
    if relative in SHARED_PATHS or relative == "presentation":
        return False
    parts = relative.split("/")
    resource = parts[0]
    kind, section = kwargs.get("kind"), kwargs.get("section") or "identite"
    if resource == "depots" and len(parts) == 1 and action == "read" and request.query_params.get("usage") == "selection":
        if not any(can_use_tab(actor, MODULE, tab) for tab in DEPOT_SELECTION_TABS):
            raise APIError("Vous n’avez pas accès à la sélection des dépôts.", "TAB_ACTION_FORBIDDEN", 403)
        return True
    if resource in {"registre", "saisie-multiple"}:
        require_tabs(actor, REGISTER_TABS[kind or parts[1]], action=action)
    elif resource == "documents":
        require_tabs(actor, DOCUMENT_TABS[kind], action=action)
        if action == "export" and len(parts) > 3 and parts[3].endswith(".pdf"):
            if kind in {"bon", "facture", "avoir"}:
                require_tabs(actor, "details", action="export")
    elif resource == "consultations":
        kind = kind or parts[1]
        sections = CONSULTATION_TABS[kind]
        require_tabs(actor, sections["identite"], sections.get(section, sections["identite"]), action=action)
        if kind == "commande" and section == "lots":
            require_tabs(actor, "mouvements")
    elif resource in {"dashboard", "synthese", "indicateurs"}:
        require_tabs(actor, "dashboard", action=action)
        if resource == "indicateurs":
            require_tabs(actor, *indicator_tabs(kwargs["key"]), action=action)
        if resource == "dashboard":
            require_tabs(actor, "articles", "commandes", "details", "factures", "reglements", "mouvements")
    elif resource == "stock":
        require_tabs(actor, "dashboard")
        require_tabs(actor, *([STOCK_TABS[kind]] if kind else STOCK_TABS.values()), action=action)
    elif resource == "commande-details":
        require_tabs(actor, "details", action=action)
        if action == "read" and kwargs.get("article") is None:
            require_tabs(actor, "factures")
    elif resource == "commandes-sans-details":
        require_tabs(actor, "commandes", action=action)
    elif resource == "dossiers-suivi":
        require_tabs(actor, "dossiers", action=action)
    elif resource == "peremption":
        require_tabs(actor, "articles", action=action)
    elif resource == "avoirs":
        require_tabs(actor, "factures", action=action)
        if kwargs.get("operation"):
            require_tabs(actor, "reglements", action=action)
    elif resource == "commandes":
        subresource = parts[-1] if len(parts) < 4 else parts[2]
        tab = {"avoirs": "factures", "facture": "factures", "details": "details"}.get(subresource, "commandes")
        require_tabs(actor, tab, action=action)
        if subresource in {"composition", "composees", "retours"}:
            require_tabs(actor, "details", action=action if subresource != "retours" else "read")
        if subresource in {"composition", "composees"}:
            require_tabs(actor, "articles")
        if subresource == "retours":
            require_tabs(actor, "lots")
        if subresource in {"facture", "avoirs", "details"}:
            require_tabs(actor, "commandes")
        if subresource == "facture":
            require_tabs(actor, "details")
        if subresource == "details" and action == "read" and kwargs.get("article") is None:
            require_tabs(actor, "factures")
    elif resource == "articles":
        require_tabs(actor, "articles", action=action)
        if parts[-1] == "receptions":
            require_tabs(actor, "commandes", "details", action=action)
        elif parts[-1] == "fefo":
            require_tabs(actor, "lots")
    elif resource in REGISTER_TABS:
        require_tabs(actor, REGISTER_TABS[resource], action=action)
        if resource == "lots" and "mouvements" in parts:
            require_tabs(actor, "mouvements", action=action)
        elif resource == "inventaires" and kwargs.get("action") == "catalogue":
            require_tabs(actor, "articles")
        elif resource == "reglements" and parts[-1] in {"preparation", "groupes"}:
            require_tabs(actor, "factures")
    else:
        raise APIError("Utilisez le registre Logistique correspondant.", "DEDICATED_ROUTE_REQUIRED", 403)
    return True
