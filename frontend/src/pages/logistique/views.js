const SCHEMA_NAME = "logistique";

export const LOGISTIQUE_GENERIC_SOURCE_CONFIG = {
  "logistique.articleTypes": {
    label: "Type d'article",
    referenceKey: "articleTypes",
    defaultCategoryIds: [46],
  },
  "logistique.articleCategories": {
    label: "Categorie d'article",
    referenceKey: "articleCategories",
    defaultCategoryIds: [40],
  },
  "logistique.articleUnits": {
    label: "Unite",
    referenceKey: "articleUnits",
    defaultCategoryIds: [34],
  },
  "logistique.commandeTypes": {
    label: "Type de commande",
    referenceKey: "commandeTypes",
    defaultCategoryIds: [64],
  },
  "logistique.commandeStatuses": {
    label: "Statut commande",
    referenceKey: "commandeStatuses",
    defaultCategoryIds: [28],
  },
  "logistique.commandeConditionPaiements": {
    label: "Condition de paiement",
    referenceKey: "commandeConditionPaiements",
    defaultCategoryIds: [37],
  },
  "logistique.commandeModesPaiement": {
    label: "Mode de paiement",
    referenceKey: "commandeModesPaiement",
    defaultCategoryIds: [36],
  },
  "logistique.reglementModes": {
    label: "Mode de reglement",
    referenceKey: "reglementModes",
    defaultCategoryIds: [36],
  },
};

const LOGISTIQUE_VIEWS = [
  {
    key: "dashboard",
    schema: SCHEMA_NAME,
    name: "dashboard",
    title: "Vue d'ensemble logistique",
    description: "Consolide les indicateurs des vues logistiques pour suivre stocks, commandes et paiements.",
    group: "pilotage",
    accessMode: "Pilotage",
  },
  {
    key: "articles",
    schema: SCHEMA_NAME,
    name: "V_Article",
    title: "Catalogue des articles",
    description: "Expose les articles, leur stock, leurs prix et leurs metadonnees de reference.",
    group: "pilotage",
    accessMode: "CRUD disponible",
  },
  {
    key: "commandes",
    schema: SCHEMA_NAME,
    name: "V_Commande",
    title: "Suivi des commandes",
    description: "Permet de piloter les commandes, la facturation et les statuts associes.",
    group: "pilotage",
    accessMode: "CRUD disponible",
  },
  {
    key: "details",
    schema: SCHEMA_NAME,
    name: "V_CommandeDetail",
    title: "Details des commandes",
    description: "Detaille les lignes des commandes et les quantites qui pilotent les mouvements.",
    group: "pilotage",
    accessMode: "CRUD disponible",
  },
  {
    key: "mouvements",
    schema: SCHEMA_NAME,
    name: "V_Mouvement",
    title: "Historique des mouvements",
    description: "Trace les entrees et sorties de stock issues de la logique metier existante.",
    group: "pilotage",
    accessMode: "Lecture seule",
  },
  {
    key: "reglements",
    schema: SCHEMA_NAME,
    name: "V_SuiviReglements",
    title: "Suivi des reglements",
    description: "Suit les ecritures de reglement et le reste a payer par facture.",
    group: "pilotage",
    accessMode: "CRUD disponible",
  },
  {
    key: "audit",
    schema: SCHEMA_NAME,
    name: "V_AuditStock",
    title: "Audit de stock",
    description: "Compare le stock des articles avec les mouvements pour identifier les ecarts.",
    group: "analyse",
    accessMode: "Lecture seule",
  },
  {
    key: "alertes",
    schema: SCHEMA_NAME,
    name: "V_AlertStock",
    title: "Alertes de stock",
    description: "Met en evidence les articles critiques, les marges faibles et les ruptures proches.",
    group: "analyse",
    accessMode: "Lecture seule",
  },
  {
    key: "consommation",
    schema: SCHEMA_NAME,
    name: "V_ConsoMensuelle",
    title: "Consommation mensuelle",
    description: "Analyse les volumes consommes par article et par mois pour le pilotage des approvisionnements.",
    group: "analyse",
    accessMode: "Lecture seule",
  },
  {
    key: "couverture",
    schema: SCHEMA_NAME,
    name: "V_CouvertureStock",
    title: "Couverture du stock",
    description: "Mesure la couverture en mois et isole les articles qui necessitent une action rapide.",
    group: "analyse",
    accessMode: "Lecture seule",
  },
];

const LOGISTIQUE_TAB_GROUPS = [
  { key: "pilotage", title: "Volets metier", subtitle: "Operations et ecritures", accessMode: "Vue avec actions" },
  { key: "analyse", title: "Analyse et controle", subtitle: "Lecture et supervision", accessMode: "Lecture seule" },
];

const LOGISTIQUE_TABLE_FEATURES = {
  articles: {
    searchLabel: "Recherche globale",
    toolbarTitle: "Tableau logistique.V_Article",
    exportFilename: "logistique-v_article.csv",
    fkMappings: [
      {
        field: "ID_TypeArticleFk",
        label: "Type d'article",
        sourceKey: "logistique.articleTypes",
        source: "referentiel.T_Generique",
        kind: "generic",
      },
      {
        field: "ID_CategorieArticleFk",
        label: "Categorie d'article",
        sourceKey: "logistique.articleCategories",
        source: "referentiel.T_Generique",
        kind: "generic",
      },
      { field: "ID_UserFK", label: "Utilisateur", source: "systeme.T_Utilisateurs", kind: "direct" },
      {
        field: "ID_UniteFk",
        label: "Unite",
        sourceKey: "logistique.articleUnits",
        source: "referentiel.T_Generique",
        kind: "generic",
      },
    ],
  },
  commandes: {
    searchLabel: "Recherche globale",
    toolbarTitle: "Tableau logistique.V_Commande",
    exportFilename: "logistique-v_commande.csv",
    fkMappings: [
      {
        field: "ID_TypeCmdFk",
        label: "Type de commande",
        sourceKey: "logistique.commandeTypes",
        source: "referentiel.T_Generique",
        kind: "generic",
      },
      {
        field: "ID_StatutCmdFk",
        label: "Statut commande",
        sourceKey: "logistique.commandeStatuses",
        source: "referentiel.T_Generique",
        kind: "generic",
      },
      { field: "ID_ClientFk", label: "Client", source: "Source client disponible dans la base actuelle", kind: "direct" },
      { field: "ID_UserFk", label: "Utilisateur", source: "systeme.T_Utilisateurs", kind: "direct" },
      {
        field: "ID_ConditionPaiementFk",
        label: "Condition de paiement",
        sourceKey: "logistique.commandeConditionPaiements",
        source: "referentiel.T_Generique",
        kind: "generic",
      },
      {
        field: "ID_ModePaiementFk",
        label: "Mode de paiement",
        sourceKey: "logistique.commandeModesPaiement",
        source: "referentiel.T_Generique",
        kind: "generic",
      },
    ],
  },
  details: {
    searchLabel: "Recherche globale",
    toolbarTitle: "Tableau logistique.V_CommandeDetail",
    exportFilename: "logistique-v_commandedetail.csv",
    fkMappings: [
      { field: "ID_CmdFk", label: "Commande parent", source: "Vue logistique.V_CommandeDetail / logistique.T_Commande", kind: "direct" },
      { field: "ID_ArticleFk", label: "Article", source: "logistique.T_Article", kind: "direct" },
    ],
  },
  mouvements: {
    searchLabel: "Recherche globale",
    toolbarTitle: "Tableau logistique.V_Mouvement",
    exportFilename: "logistique-v_mouvement.csv",
    fkMappings: [
      {
        field: "ID_TypeMvtFk",
        label: "Type de mouvement",
        sourceKey: "logistique.commandeTypes",
        source: "referentiel.T_Generique",
        kind: "generic",
      },
      { field: "ID_ArticleFk", label: "Article", source: "logistique.T_Article via V_Mouvement", kind: "direct" },
      { field: "ID_cmdFk", label: "Commande", source: "logistique.T_Commande via V_Mouvement", kind: "direct" },
    ],
  },
  reglements: {
    searchLabel: "Filtre facture",
    toolbarTitle: "Tableau logistique.V_SuiviReglements",
    exportFilename: "logistique-v_suivi_reglements.csv",
    fkMappings: [
      { field: "CodeFactureFk", label: "Facture", source: "Codes issus de logistique.T_Commande", kind: "direct" },
      {
        field: "ID_ModeReglementFk",
        label: "Mode de reglement",
        sourceKey: "logistique.reglementModes",
        source: "referentiel.T_Generique",
        kind: "generic",
      },
      { field: "ID_ClientFk", label: "Client", source: "Source client disponible dans la base actuelle", kind: "direct" },
    ],
  },
};

function buildViewLabel(view) {
  return `${view.schema}.${view.name}`;
}

export const LOGISTIQUE_MODULE_SCHEMA = {
  schema: SCHEMA_NAME,
  title: "Catalogue logistique",
  genericSources: LOGISTIQUE_GENERIC_SOURCE_CONFIG,
  views: LOGISTIQUE_VIEWS.map((view) => ({
    ...view,
    viewLabel: buildViewLabel(view),
  })),
  tabGroups: LOGISTIQUE_TAB_GROUPS,
  tableFeatures: LOGISTIQUE_TABLE_FEATURES,
};
