import { fetchViewData } from "../../services/api";
import {
  createLogistiqueArticle,
  createLogistiqueCommande,
  createLogistiqueCommandeDetail,
  fetchLogistiqueArticles,
  fetchLogistiqueAlertesStock,
  fetchLogistiqueCommandes,
  createLogistiqueReglement,
  deleteLogistiqueCommande,
  deleteLogistiqueArticle,
  deleteLogistiqueCommandeDetail,
  fetchLogistiqueCommandeDetails,
  fetchLogistiqueConsommation,
  fetchLogistiqueCouverture,
  fetchLogistiqueDashboard,
  fetchLogistiqueMouvements,
  fetchLogistiqueReglements,
  fetchLogistiqueReglementEntries,
  fetchLogistiqueStockAudit,
  hardDeleteLogistiqueArticle,
  updateLogistiqueArticle,
  updateLogistiqueCommande,
  updateLogistiqueCommandeDetail,
  updateLogistiqueReglement,
} from "../../services/logistique";

const SCHEMA_NAME = "logistique";

export const LOGISTIQUE_GENERIC_SOURCE_CONFIG = {
  "logistique.articleCurrencies": {label:"Devise des articles",referenceKey:"articleCurrencies",defaultCategoryIds:[],categoryLabel:"Devise",locked:true},
  "logistique.commandeCurrencies": {label:"Devise des bons",referenceKey:"commandeCurrencies",defaultCategoryIds:[],categoryLabel:"Devise",locked:true},
  "logistique.weightUnits": {label:"Unité de poids",referenceKey:"weightUnits",defaultCategoryIds:[],categoryLabel:"Unité de poids",locked:true},
  "logistique.movementTypes": {label:"Type de mouvement",referenceKey:"movementTypes",defaultCategoryIds:[],categoryLabel:"Type de mouvement",locked:true},
  "logistique.articleTypes": {
    label: "Type d'article",
    referenceKey: "articleTypes",
    defaultCategoryIds: [],
    categoryLabel: "Type produit",
    locked: true,
  },
  "logistique.articleCategories": {
    label: "Categorie d'article",
    referenceKey: "articleCategories",
    defaultCategoryIds: [],
    categoryLabel: "Categorie produit",
    locked: true,
  },
  "logistique.articleUnits": {
    label: "Unite",
    referenceKey: "articleUnits",
    defaultCategoryIds: [],
    categoryLabel: "Unites",
    locked: true,
  },
  "logistique.commandeTypes": {
    label: "Type de bon",
    referenceKey: "commandeTypes",
    defaultCategoryIds: [],
    categoryLabel: "Type de bon",
    locked: true,
  },
  "logistique.commandeStatuses": {
    label: "Statut du bon",
    referenceKey: "commandeStatuses",
    defaultCategoryIds: [],
    categoryLabel: "Statut",
    locked: true,
  },
  "logistique.commandeConditionPaiements": {
    label: "Condition de paiement",
    referenceKey: "commandeConditionPaiements",
    defaultCategoryIds: [],
    categoryLabel: "Condition de paiement",
    locked: true,
  },
  "logistique.commandeModesPaiement": {
    label: "Mode de paiement",
    referenceKey: "commandeModesPaiement",
    defaultCategoryIds: [],
    categoryLabel: "Mode paiement",
    locked: true,
  },
  "logistique.reglementModes": {
    label: "Mode de reglement",
    referenceKey: "reglementModes",
    defaultCategoryIds: [],
    categoryLabel: "Mode paiement",
    locked: true,
  },
};

export function getLogistiqueGenericSourceConfig(sourceKey) {
  return LOGISTIQUE_GENERIC_SOURCE_CONFIG[sourceKey] || null;
}

export function getLogistiqueGenericSourceHint(sourceKey) {
  const config = getLogistiqueGenericSourceConfig(sourceKey);

  if (!config) {
    return "";
  }

  const categoryIds = Array.isArray(config.defaultCategoryIds) ? config.defaultCategoryIds.join(", ") : "";
  const categoryLabel = config.categoryLabel || "Categorie generique";

  return `Referentiel: categorie ${categoryIds} - ${categoryLabel}`;
}

const LOGISTIQUE_VIEWS = [
  ...[{key:"depots",name:"V_Depot",title:"Dépôts"},{key:"stocks-depots",name:"V_StockDepot",title:"Stocks par dépôt"},{key:"transferts",name:"V_Transfert",title:"Transferts internes"}].map(view=>({...view,schema:SCHEMA_NAME,description:view.title,group:"stocks",accessMode:"Consultation"})),
  {
    key: "dashboard",
    schema: SCHEMA_NAME,
    name: "dashboard",
    title: "Vue d'ensemble logistique",
    description: "Consolide les indicateurs des vues logistiques pour suivre stocks, bons de stock et paiements.",
    group: "pilotage",
    accessMode: "Pilotage",
  },
  {key:"immobilisations",schema:SCHEMA_NAME,name:"V_Immobilisation",title:"Immobilisations",description:"Biens, affectations et acquisitions de l’entreprise.",group:"patrimoine",accessMode:"CRUD disponible"},
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
    key: "lots",
    schema: SCHEMA_NAME,
    name: "V_RegistreLots",
    title: "Lots de stock",
    description: "Disponibilités, péremption et traçabilité des lots.",
    group: "pilotage",
    accessMode: "Lecture seule",
  },
  {
    key: "commandes",
    schema: SCHEMA_NAME,
    name: "V_Commande",
    title: "Suivi des bons de stock",
    description: "Permet de piloter les bons de stock, la facturation et les statuts associes.",
    group: "pilotage",
    accessMode: "CRUD disponible",
  },
  {
    key: "details",
    schema: SCHEMA_NAME,
    name: "V_CommandeDetail",
    title: "Lignes des bons",
    description: "Detaille les lignes des bons de stock et les quantites qui pilotent les mouvements.",
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
    key: "factures",
    schema: SCHEMA_NAME,
    name: "V_SuiviReglements",
    title: "Factures",
    description: "Factures émises, soldes et échéances.",
    group: "pilotage",
    accessMode: "Consultation et facturation",
  },
  {
    key: "reglements",
    schema: SCHEMA_NAME,
    name: "V_Reglements",
    title: "Règlements",
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
  {key:"patrimoine",title:"Patrimoine",subtitle:"Biens et affectations",accessMode:"Vue avec actions"},
];

const LOGISTIQUE_TABLE_FEATURES = {
  articles: {
    searchLabel: "Recherche globale",
    toolbarTitle: "Tableau logistique.V_Article",
    exportFilename: "logistique-v_article.csv",
    fkMappings: [
      {field:"ID_DeviseFk",label:"Devise des articles",sourceKey:"logistique.articleCurrencies",source:"referentiel.T_Generique",kind:"generic"},
      {field:"ID_UnitePoidsFk",label:"Unité de poids",sourceKey:"logistique.weightUnits",source:"referentiel.T_Generique",kind:"generic"},
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
      {field:"ID_DeviseFk",label:"Devise du bon",sourceKey:"logistique.commandeCurrencies",source:"referentiel.T_Generique",kind:"generic"},
      {
        field: "ID_TypeCmdFk",
        label: "Type de bon",
        sourceKey: "logistique.commandeTypes",
        source: "referentiel.T_Generique",
        kind: "generic",
      },
      {
        field: "ID_StatutCmdFk",
        label: "Statut du bon",
        sourceKey: "logistique.commandeStatuses",
        source: "referentiel.T_Generique",
        kind: "generic",
      },
      { field: "ID_TiersFk", label: "Tiers référencé", source: "logistique.T_Client", kind: "direct" },
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
      { field: "ID_CmdFk", label: "Bon de stock associé", source: "Vue logistique.V_CommandeDetail / logistique.T_Commande", kind: "direct" },
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
        sourceKey: "logistique.movementTypes",
        source: "referentiel.T_Generique",
        kind: "generic",
      },
      { field: "ID_ArticleFk", label: "Article", source: "logistique.T_Article via V_Mouvement", kind: "direct" },
      { field: "ID_cmdFk", label: "Bon de stock", source: "logistique.T_Commande via V_Mouvement", kind: "direct" },
    ],
  },
  factures: {
    searchLabel: "Recherche facture",
    toolbarTitle: "Factures",
    fkMappings: [
      {field: "ID_Commande", label: "Bon de stock", source: "logistique.T_Commande", kind: "direct"},
      {field: "ID_ModePaiementFk", label: "Mode de paiement", sourceKey: "logistique.commandeModesPaiement", source: "referentiel.T_Generique", kind: "generic"},
      {field: "ID_ConditionPaiementFk", label: "Condition de paiement", sourceKey: "logistique.commandeConditionPaiements", source: "referentiel.T_Generique", kind: "generic"},
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
      { field: "ID_ClientFk", label: "Client", source: "Source tiers disponible dans la base actuelle", kind: "direct" },
    ],
  },
};

function buildViewLabel(view) {
  return `${view.schema}.${view.name}`;
}

function createGenericViewRequestOptions(options = {}, filterMap = {}) {
  const requestOptions = {
    take: options.take || 500,
  };
  const filters = {};

  if (options.q) {
    requestOptions.q = options.q;
  }

  if (options.sortBy) {
    requestOptions.sortBy = options.sortBy;
  }

  if (options.sortDir) {
    requestOptions.sortDir = options.sortDir;
  }

  Object.entries(filterMap).forEach(([optionKey, columnName]) => {
    const rawValue = options?.[optionKey];

    if (rawValue == null || rawValue === "") {
      return;
    }

    filters[columnName] = rawValue;
  });

  if (Object.keys(filters).length > 0) {
    requestOptions.filters = JSON.stringify(filters);
  }

  return requestOptions;
}

function createViewRowsFetcher(viewName, { filterMap = {}, defaultOptions = {} } = {}) {
  return (options = {}) =>
    fetchViewData(SCHEMA_NAME, viewName, {
      ...defaultOptions,
      ...createGenericViewRequestOptions(options, filterMap),
    });
}

function stringifyNullableValue(value) {
  return value == null ? "" : String(value);
}

function normalizeDateValueForDiff(value) {
  if (!value) {
    return null;
  }

  const parsed = new Date(value);

  if (Number.isNaN(parsed.getTime())) {
    return null;
  }

  return new Date(Date.UTC(parsed.getFullYear(), parsed.getMonth(), parsed.getDate()));
}

export function computeArticleAlertDays(datePeremption, dateAlerte) {
  const peremptionDate = normalizeDateValueForDiff(datePeremption);
  const alertDate = normalizeDateValueForDiff(dateAlerte);

  if (!peremptionDate || !alertDate) {
    return "";
  }

  const diffMs = peremptionDate.getTime() - alertDate.getTime();
  const diffDays = Math.round(diffMs / 86400000);

  return diffDays >= 0 ? String(diffDays) : "";
}

export function computeArticleAlertDate(datePeremption, alertDays) {
  const peremptionDate = normalizeDateValueForDiff(datePeremption);
  const parsedDays = Number(alertDays);

  if (alertDays == null || String(alertDays).trim() === "" || !peremptionDate || !Number.isInteger(parsedDays) || parsedDays < 0 || parsedDays > 36500) {
    return "";
  }

  const alertDate = new Date(peremptionDate);
  alertDate.setUTCDate(alertDate.getUTCDate() - parsedDays);

  return alertDate.toISOString().slice(0, 10);
}

const LOGISTIQUE_CRUD_CONFIGS = {
  articles: {
    primaryKey: "ID_Article",
    resourceLabel: "article",
    createLabel: "Nouveau article",
    messages: {
      createSuccess: "Article cree avec succes.",
      updateSuccess: "Article mis a jour avec succes.",
      deleteSuccess: "Article desactive avec succes.",
    },
    createFormState: () => ({
      NomArticle: "",
      InformationArticle: "",
      PoidsUnitaire: "",
      ID_UnitePoidsFk: "",
      RefArticle: "",
      CodeArticleInterne: "",
      CodeArticleExterne: "",
      ID_TypeArticleFk: "",
      ID_CategorieArticleFk: "",
      ID_UserFK: "",
      ID_UniteFk: "",
      QteArticle: "0",
      QteMinArticle: "",
      ID_DeviseFk: "",
      PUArticle: "",
      PVArticle: "",
      PhotoArticle: "",
      DatePeremptionArticle: "",
      DatePeremptionAlerteArticle: "",
      NbreJoursAlerteArticle: "",
      ObsArticle: "",
      ValideArticle: true,
    }),
    mapRecordToForm: (article) => ({
      NomArticle: article.NomArticle || "",
      InformationArticle: article.InformationArticle || "",
      PoidsUnitaire: article.PoidsUnitaire == null ? "" : String(article.PoidsUnitaire),
      ID_UnitePoidsFk: article.ID_UnitePoidsFk == null ? "" : String(article.ID_UnitePoidsFk),
      RefArticle: article.RefArticle || "",
      CodeArticleInterne: article.CodeArticleInterne || "",
      CodeArticleExterne: stringifyNullableValue(article.CodeArticleExterne),
      ID_TypeArticleFk: article.ID_TypeArticleFk ? String(article.ID_TypeArticleFk) : "",
      ID_CategorieArticleFk: article.ID_CategorieArticleFk ? String(article.ID_CategorieArticleFk) : "",
      ID_UserFK: article.ID_UserFK ? String(article.ID_UserFK) : article.IdUser ? String(article.IdUser) : "",
      ID_UniteFk: article.ID_UniteFk ? String(article.ID_UniteFk) : "",
      QteArticle: article.QteArticle != null ? String(article.QteArticle) : "0",
      QteMinArticle: article.QteMinArticle != null ? String(article.QteMinArticle) : "",
      ID_DeviseFk: article.ID_DeviseFk == null ? "" : String(article.ID_DeviseFk),
      PUArticle: article.PUArticle != null ? String(article.PUArticle) : "",
      PVArticle: article.PVArticle != null ? String(article.PVArticle) : "",
      PhotoArticle: article.PhotoArticle || "",
      DatePeremptionArticle: article.DatePeremptionArticle ? new Date(article.DatePeremptionArticle).toISOString().slice(0, 10) : "",
      NbreJoursAlerteArticle:
        stringifyNullableValue(article.NbreJoursAlerteArticle) ||
        computeArticleAlertDays(article.DatePeremptionArticle, article.DatePeremptionAlerteArticle),
      DatePeremptionAlerteArticle: article.DatePeremptionAlerteArticle
        ? new Date(article.DatePeremptionAlerteArticle).toISOString().slice(0, 10)
        : computeArticleAlertDate(
            article.DatePeremptionArticle,
            article.NbreJoursAlerteArticle ||
              computeArticleAlertDays(article.DatePeremptionArticle, article.DatePeremptionAlerteArticle)
          ),
      ObsArticle: article.ObsArticle || "",
      ValideArticle: article.ValideArticle !== false,
    }),
    buildPayload: (values, { mode, record } = {}) => {
      const computedAlertDate = computeArticleAlertDate(
        values.DatePeremptionArticle,
        values.NbreJoursAlerteArticle
      );
      const computedAlertDays = computeArticleAlertDays(values.DatePeremptionArticle, computedAlertDate);

      const payload = {
        ...values,
        ID_TypeArticleFk: values.ID_TypeArticleFk || null,
        ID_CategorieArticleFk: values.ID_CategorieArticleFk || null,
        QteMinArticle: values.QteMinArticle || null,
        CodeArticleExterne: values.CodeArticleExterne || null,
        PhotoArticle: values.PhotoArticle || null,
        DatePeremptionAlerteArticle: computedAlertDate || null,
        NbreJoursAlerteArticle: computedAlertDays || null,
      };

      if (mode === "create" || values.ID_UserFK || record?.IdUser != null || record?.ID_UserFK != null) {
        payload.ID_UserFK = values.ID_UserFK || null;
      }

      if (mode === "create" || values.ID_UniteFk || record?.ID_UniteFk != null) {
        payload.ID_UniteFk = values.ID_UniteFk || null;
      }

      if (mode === "create" || values.DatePeremptionArticle || record?.DatePeremptionArticle != null) {
        payload.DatePeremptionArticle = values.DatePeremptionArticle || null;
      }

      if (
        mode === "create" ||
        computedAlertDate ||
        record?.DatePeremptionAlerteArticle != null
      ) {
        payload.DatePeremptionAlerteArticle = computedAlertDate || null;
      }

      return payload;
    },
    createRecord: ({ payload }) => createLogistiqueArticle(payload),
    updateRecord: ({ record, payload }) => updateLogistiqueArticle(record.ID_Article, payload),
    deleteRecord: ({ record }) => deleteLogistiqueArticle(record.ID_Article),
    hardDeleteRecord: ({ record }) => hardDeleteLogistiqueArticle(record.ID_Article),
  },
  commandes: {
    primaryKey: "ID_Commande",
    resourceLabel: "commande",
    createLabel: "Nouveau bon de stock",
    messages: {
      createSuccess: "Bon de stock créé avec succes.",
      updateSuccess: "Bon de stock mis à jour avec succes.",
    },
    createFormState: () => ({
      ID_TypeCmdFk: "",
      ID_StatutCmdFk: "",
      ID_ClientFk: "",
      NomClientSaisi: "",
      ID_UserFk: "",
      geolocalisationCmd: "",
      ID_ConditionPaiementFk: "",
      ID_ModePaiementFk: "",
      DateCmd: "",
      RefCmd: "",
      ID_DeviseFk: "",
      MontantHT: "",
      MontantTTC: "",
      UrlBL: "",
      ObsCmd: "",
      SelectCmd: false,
      CodeFacture: "",
      DateFacture: "",
      MontantRegleFacture: "",
      MontantResteFacture: "",
      StatusFacture: "",
      ValideRemiseFacture: false,
      UrlFacture: "",
      DateEcheancePaiement: "",
    }),
    mapRecordToForm: (commande) => ({
      ID_TypeCmdFk: commande.ID_TypeCmdFk ? String(commande.ID_TypeCmdFk) : "",
      ID_StatutCmdFk: commande.ID_StatutCmdFk ? String(commande.ID_StatutCmdFk) : "",
      ID_ClientFk: commande.ID_ClientFk ? String(commande.ID_ClientFk) : "",
      NomClientSaisi: commande.NomClientSaisi || "",
      ID_UserFk: commande.ID_UserFk ? String(commande.ID_UserFk) : "",
      geolocalisationCmd: commande.geolocalisationCmd || "",
      ID_ConditionPaiementFk: commande.ID_ConditionPaiementFk ? String(commande.ID_ConditionPaiementFk) : "",
      ID_ModePaiementFk: commande.ID_ModePaiementFk ? String(commande.ID_ModePaiementFk) : "",
      DateCmd: commande.DateCmd ? new Date(new Date(commande.DateCmd).getTime() - new Date(commande.DateCmd).getTimezoneOffset() * 60000).toISOString().slice(0, 16) : "",
      RefCmd: commande.RefCmd || "",
      ID_DeviseFk: commande.ID_DeviseFk == null ? "" : String(commande.ID_DeviseFk),
      MontantHT: commande.MontantHT != null ? String(commande.MontantHT) : "",
      MontantTTC: commande.MontantTTC != null ? String(commande.MontantTTC) : "",
      UrlBL: commande.UrlBL || "",
      ObsCmd: commande.ObsCmd || "",
      SelectCmd: Boolean(commande.SelectCmd),
      CodeFacture: commande.CodeFacture || "",
      DateFacture: commande.DateFacture
        ? new Date(new Date(commande.DateFacture).getTime() - new Date(commande.DateFacture).getTimezoneOffset() * 60000)
            .toISOString()
            .slice(0, 16)
        : "",
      MontantRegleFacture: stringifyNullableValue(commande.MontantRegleFacture),
      MontantResteFacture: stringifyNullableValue(commande.MontantResteFacture),
      StatusFacture: commande.StatusFacture || "",
      ValideRemiseFacture: Boolean(commande.ValideRemiseFacture),
      UrlFacture: commande.UrlFacture || "",
      DateEcheancePaiement: commande.DateEcheancePaiement
        ? new Date(
            new Date(commande.DateEcheancePaiement).getTime() -
              new Date(commande.DateEcheancePaiement).getTimezoneOffset() * 60000
          )
            .toISOString()
            .slice(0, 16)
        : "",
    }),
    buildPayload: (values, { mode, record } = {}) => {
      const payload = {
        ...values,
        ID_StatutCmdFk: values.ID_StatutCmdFk || null,
        ID_ClientFk: values.ID_ClientFk || null,
        NomClientSaisi: values.NomClientSaisi || null,
        DateCmd: values.DateCmd || null,
        ID_DeviseFk: values.ID_DeviseFk || null,
        MontantHT: values.MontantHT || null,
        MontantTTC: values.MontantTTC || null,
      };

      delete payload.CodeCmd;

      if (mode === "create" || values.ID_UserFk || record?.ID_UserFk != null) {
        payload.ID_UserFk = values.ID_UserFk || null;
      }

      if (mode === "create" || values.ID_ConditionPaiementFk || record?.ID_ConditionPaiementFk != null) {
        payload.ID_ConditionPaiementFk = values.ID_ConditionPaiementFk || null;
      }

      if (mode === "create" || values.ID_ModePaiementFk || record?.ID_ModePaiementFk != null) {
        payload.ID_ModePaiementFk = values.ID_ModePaiementFk || null;
      }

      if (mode === "create" || values.DateFacture || record?.DateFacture != null) {
        payload.DateFacture = values.DateFacture || null;
      }

      if (mode === "create" || values.DateEcheancePaiement || record?.DateEcheancePaiement != null) {
        payload.DateEcheancePaiement = values.DateEcheancePaiement || null;
      }

      return payload;
    },
    createRecord: ({ payload }) => createLogistiqueCommande(payload),
    updateRecord: ({ record, payload }) => updateLogistiqueCommande(record.ID_Commande, payload),
    deleteRecord: ({ record }) => deleteLogistiqueCommande(record.ID_Commande),
  },
  details: {
    primaryKey: ["ID_CmdFk", "ID_ArticleFk"],
    resourceLabel: "ligne de bon de stock",
    createLabel: "Ajouter une ligne",
    messages: {
      createSuccess: "Ligne ajoutee au bon de stock.",
      updateSuccess: "Ligne du bon mis a jour.",
      deleteSuccess: "Ligne de bon de stock supprimee avec succes.",
    },
    createFormState: () => ({
      ID_ArticleFk: "",
      QteCmdDetail: "",
      PUCmdDetail: "",
      ObsCmdDetail: "",
      RemiseCmdDetail: false,
      LieuCmdDetail: "",
      SelectCmdDetail: false,
    }),
    mapRecordToForm: (detail) => ({
      ID_ArticleFk: detail.ID_ArticleFk ? String(detail.ID_ArticleFk) : "",
      QteCmdDetail: stringifyNullableValue(detail.QteCmdDetail),
      PUCmdDetail: stringifyNullableValue(detail.PUCmdDetail),
      ObsCmdDetail: detail.ObsCmdDetail || "",
      RemiseCmdDetail: Boolean(detail.RemiseCmdDetail),
      LieuCmdDetail: stringifyNullableValue(detail.LieuCmdDetail),
      SelectCmdDetail: Boolean(detail.SelectCmdDetail),
    }),
    buildPayload: (values) => ({
      ...values,
      PUCmdDetail: values.PUCmdDetail || null,
      LieuCmdDetail: values.LieuCmdDetail || null,
    }),
    createRecord: ({ parentRecord, payload }) => createLogistiqueCommandeDetail(parentRecord.ID_Commande, payload),
    updateRecord: ({ parentRecord, record, payload }) =>
      updateLogistiqueCommandeDetail(parentRecord.ID_Commande, record.ID_ArticleFk, payload),
    deleteRecord: ({ parentRecord, record }) => deleteLogistiqueCommandeDetail(parentRecord.ID_Commande, record.ID_ArticleFk),
  },
  reglements: {
    primaryKey: "ID_Reglement",
    resourceLabel: "reglement",
    createLabel: "Nouveau reglement",
    messages: {
      createSuccess: "Reglement cree avec succes.",
      updateSuccess: "Reglement mis a jour avec succes.",
    },
    createFormState: () => ({
      CodeFactureFk: "",
      ID_ModeReglementFk: "",
      ID_ClientFk: "",
      DateReglement: "",
      MontantRegle: "",
    }),
    mapRecordToForm: (reglement) => ({
      CodeFactureFk: reglement.CodeFactureFk || "",
      ID_ModeReglementFk: reglement.ID_ModeReglementFk ? String(reglement.ID_ModeReglementFk) : "",
      ID_ClientFk: reglement.ID_ClientFk ? String(reglement.ID_ClientFk) : "",
      DateReglement: reglement.DateReglement ? new Date(reglement.DateReglement).toISOString().slice(0, 10) : "",
      MontantRegle: stringifyNullableValue(reglement.MontantRegle),
    }),
    buildPayload: (values) => ({
      ...values,
      ID_ClientFk: values.ID_ClientFk || null,
      DateReglement: values.DateReglement || null,
    }),
    createRecord: ({ payload }) => createLogistiqueReglement(payload),
    updateRecord: ({ record, payload }) => updateLogistiqueReglement(record.ID_Reglement, payload),
  },
};

const LOGISTIQUE_VIEW_FETCHERS = {
  dashboard: {
    fetchSummary: () => fetchLogistiqueDashboard(),
  },
  articles: {
    fetchRows: (options = {}) => fetchLogistiqueArticles(options),
  },
  commandes: {
    fetchRows: (options = {}) => fetchLogistiqueCommandes(options),
  },
  details: {
    fetchRows: (options = {}) =>
      fetchLogistiqueCommandeDetails(options.commandeId ?? options.commande ?? null, options),
  },
  mouvements: {
    fetchRows: (options = {}) => fetchLogistiqueMouvements(options),
  },
  reglements: {
    fetchRows: (options = {}) => fetchLogistiqueReglements(options),
    fetchEntries: (options = {}) => fetchLogistiqueReglementEntries(options),
  },
  audit: {
    fetchRows: (options = {}) => fetchLogistiqueStockAudit(options),
  },
  alertes: {
    fetchRows: (options = {}) => fetchLogistiqueAlertesStock(options),
  },
  consommation: {
    fetchRows: (options = {}) => fetchLogistiqueConsommation(options),
  },
  couverture: {
    fetchRows: (options = {}) => fetchLogistiqueCouverture(options),
  },
};

export function getLogistiqueViewConfig(viewKey) {
  return LOGISTIQUE_VIEW_FETCHERS[viewKey] || null;
}

export function getLogistiqueCrudConfig(viewKey) {
  return LOGISTIQUE_CRUD_CONFIGS[viewKey] || null;
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
  viewConfigs: LOGISTIQUE_VIEW_FETCHERS,
  crudConfigs: LOGISTIQUE_CRUD_CONFIGS,
};
