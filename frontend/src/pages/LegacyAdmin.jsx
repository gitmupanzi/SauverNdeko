import {categoricalKey, sameCategory} from "../utils/categoricalValues";
import ModuleSidebar from "../components/ModuleSidebar";
import AppIcon from "../components/AppIcon";
import {useEntityScope} from "../contexts/EntityScopeContext";
import {fetchTerritorialReferences} from "../services/fieldReferences";
import {REFERENCE_RETAINED_HINT,referenceLabel,referenceOptions,retainReference} from "../utils/referenceOptions";
import AdminMailSettings from "../components/AdminMailSettings";
import useReferencesRefresh from "../hooks/useReferencesRefresh";
import {formatDate} from "./logistique/logistiqueShared";
import CategoricalSelect from "../components/CategoricalSelect";
import { useAuth } from "../contexts/AuthContext";
import ActionButton from "../components/ActionButton";
import { useEffect, useMemo, useRef, useState } from "react";
import {
  fetchAdminUiSettings,
  fetchAdminUiSettingsAudit,
  fetchAdminEntities,
  fetchAdminLicences,
  fetchAdminModelList,
  fetchCompleteReferenceRows,
  fetchAvailableViews,
  fetchViewData,
  saveAdminUiSettings,
} from "../services/api";
import { GEOLOCALISATION_ADMIN_SCHEMA } from "./admin/geolocalisation";
import { REFERENTIEL_ADMIN_SCHEMA } from "./admin/referentiel";
import { SYSTEME_ADMIN_SCHEMA } from "./admin/systeme";

const ADMIN_SCHEMAS = [SYSTEME_ADMIN_SCHEMA, REFERENTIEL_ADMIN_SCHEMA, GEOLOCALISATION_ADMIN_SCHEMA];
const ADMIN_VIEWS = ADMIN_SCHEMAS.flatMap((schemaConfig) => schemaConfig.views);
const SCHEMA_TITLES = Object.fromEntries(
  ADMIN_SCHEMAS.map((schemaConfig) => [schemaConfig.schema, schemaConfig.title])
);
const CRUD_CONFIGS = ADMIN_SCHEMAS.reduce((accumulator, schemaConfig) => {
  Object.assign(accumulator, schemaConfig.crudConfigs);
  return accumulator;
}, {});

const DEFAULT_ROWS_PER_PAGE = 25;
const MIN_COLUMN_WIDTH = 120;
const ADMIN_VIEW_STORAGE_PREFIX = "sauverndeko.admin.view.";
const ADMIN_GENERIC_CATEGORY_STORAGE_KEY = "sauverndeko.admin.generic-category-overrides";
const ADMIN_HIERARCHY_FILTER_STORAGE_KEY = "sauverndeko.admin.hierarchy-filter-modes";
const NOTIFICATION_TIMEOUT = 4000;
const ADMIN_UI_SCOPE_PRIORITY = ["entity", "country", "global"];
const GENERIC_OPTION_SOURCE_CONFIG = {
  roles: {
    label: "Role",
    defaultCategoryIds: [],
    fallbackKeywords: ["role"],
  },
  entityTypes: {
    label: "Type entite",
    defaultCategoryIds: [],
    fallbackKeywords: ["typeentite"],
  },
  licenseStatuses: {
    label: "Statut licence",
    defaultCategoryIds: [],
    fallbackKeywords: ["statutlicence"],
  },
  niveau2Types: {
    label: "Type niveau 2",
    defaultCategoryIds: [],
  },
  niveau3Types: {
    label: "Type niveau 3",
    defaultCategoryIds: [],
    predicate: (item) => isTrueFlag(item.VisibleNiveau_3),
  },
  niveau2Statuses: {
    label: "Statut niveau 2",
    defaultCategoryIds: [],
  },
  niveau3Statuses: {
    label: "Statut niveau 3",
    defaultCategoryIds: [],
  },
  deploymentStatuses: {
    label: "Statut deploiement",
    defaultCategoryIds: [],
  },
  dpsAccessRoutes: {
    label: "Voie acces DPS",
    defaultCategoryIds: [],
    predicate: (item) => isFalseFlag(item.VisibleVoie),
    fallbackMode: "withoutPredicate",
  },
  antBczAccessRoutes: {
    label: "Voie acces antenne BCZS",
    defaultCategoryIds: [],
  },
  dpsBczAccessRoutes: {
    label: "Voie acces DPS BCZS",
    defaultCategoryIds: [],
  },
  niveau4Types: {
    label: "Type niveau 4",
    defaultCategoryIds: [],
    predicate: (item) => isTrueFlag(item.VisibleNiveau_4),
  },
  niveau5Types: {
    label: "Type niveau 5",
    defaultCategoryIds: [],
    predicate: (item) => isTrueFlag(item.VisibleNiveau_5),
  },
  niveau4Statuses: {
    label: "Statut niveau 4",
    defaultCategoryIds: [],
  },
  niveau5Statuses: {
    label: "Statut niveau 5",
    defaultCategoryIds: [],
  },
  networkAvailabilities: {
    label: "Disponibilite reseau",
    defaultCategoryIds: [],
    fallbackKeywords: ["disporeseau", "reseau"],
  },
  zsAsAccessRoutes: {
    label: "Voie acces ZS-AS",
    defaultCategoryIds: [],
  },
  zsSiteAccessRoutes: {
    label: "Voie acces ZS-Site",
    defaultCategoryIds: [],
  },
  roofTypes: {
    label: "Type de toit",
    defaultCategoryIds: [],
  },
};
const HIERARCHY_OPTION_SOURCE_CONFIG = {
  niveaux0: {
    label: "Niveau 0",
    defaultMode: "all",
    availableModes: ["all"],
  },
  niveaux1Old: {
    label: "Niveau 1 historique",
    defaultMode: "all",
    availableModes: ["all"],
  },
  niveaux1: {
    label: "Niveau 1",
    defaultMode: "filtered",
    availableModes: ["filtered", "all"],
  },
  niveaux2: {
    label: "Niveau 2",
    defaultMode: "filtered",
    availableModes: ["filtered", "all"],
  },
  niveaux3: {
    label: "Niveau 3",
    defaultMode: "filtered",
    availableModes: ["filtered", "all"],
  },
  niveaux4: {
    label: "Niveau 4",
    defaultMode: "filtered",
    availableModes: ["filtered", "all"],
  },
  niveaux5: {
    label: "Niveau 5",
    defaultMode: "filtered",
    availableModes: ["filtered", "all"],
  },
};

function normalizeViewKey(schema, name) {
  return `${schema}.${name}`;
}

function buildViewLabel(view) {
  return `${view.schema}.${view.name}`;
}

function isLikelyIsoDateTimeString(value) {
  if (typeof value !== "string") {
    return false;
  }

  return /^\d{4}-\d{2}-\d{2}(?:[T\s]\d{2}:\d{2}(?::\d{2}(?:\.\d+)?)?(?:Z|[+-]\d{2}:\d{2})?)?$/.test(value.trim());
}

function formatDisplayDateTime(value) {
  const formatted=formatDate(value,{withTime:true});
  return formatted==="—"||formatted==="-"?null:formatted;
}

function formatAdminSettingsSyncLabel(meta) {
  if (!meta?.updatedAt) {
    return "Aucune synchronisation serveur enregistree";
  }

  const formattedDate = formatDisplayDateTime(meta.updatedAt) || String(meta.updatedAt);
  const authorLabel = meta.updatedByName ? ` par ${meta.updatedByName}` : "";
  return `Synchronise le ${formattedDate}${authorLabel}`;
}

function buildSharedFkSyncStatus({
  loading,
  saving,
  error,
  targetScopeLabel,
  loadedScope,
  loadedScopeLabel,
  meta,
  hasDirtyDrafts,
  hasInvalidDrafts,
}) {
  const scopeDetails = [];

  if (targetScopeLabel) {
    scopeDetails.push({
      tone: "muted",
      text: targetScopeLabel,
    });
  }

  if (loading) {
    return {
      tone: "info",
      title: "Chargement des reglages partages...",
      details: scopeDetails,
    };
  }

  if (saving) {
    return {
      tone: "info",
      title: "Enregistrement serveur en cours...",
      details: [
        ...scopeDetails,
        {
          tone: "info",
          text: "Les modifications sont en cours d'enregistrement sur le serveur.",
        },
      ],
    };
  }

  if (error) {
    return {
      tone: "danger",
      title: "Synchronisation serveur indisponible",
      details: [
        ...scopeDetails,
        {
          tone: "danger",
          text: error,
        },
        {
          tone: "warning",
          text: "Les reglages visibles restent actifs localement dans cette session.",
        },
      ],
    };
  }

  if (loadedScope) {
    const details = [...scopeDetails];

    if (loadedScopeLabel && loadedScopeLabel !== targetScopeLabel) {
      details.push({
        tone: "warning",
        text: `Valeurs actuellement heritees de ${loadedScopeLabel.toLowerCase()}.`,
      });
    } else {
      details.push({
        tone: "success",
        text: "Les reglages affiches proviennent du serveur et sont deja actifs.",
      });
    }

    details.push({
      tone: "muted",
      text: formatAdminSettingsSyncLabel(meta),
    });

    if (hasInvalidDrafts) {
      details.push({
        tone: "danger",
        text: "Certaines categories saisies sont invalides.",
      });
    } else if (hasDirtyDrafts) {
      details.push({
        tone: "warning",
        text: "Des modifications locales attendent encore d'etre appliquees.",
      });
    }

    return {
      tone: loadedScopeLabel && loadedScopeLabel !== targetScopeLabel ? "warning" : "success",
      title:
        loadedScopeLabel && loadedScopeLabel !== targetScopeLabel
          ? "Reglages herites depuis une portee plus large"
          : "Reglages synchronises via le serveur admin",
      details,
    };
  }

  const details = [
    ...scopeDetails,
    {
      tone: "muted",
      text: "Aucune synchronisation serveur enregistree pour cette portee.",
    },
    {
      tone: "warning",
      text: "Les reglages affiches restent actifs localement jusqu'au premier enregistrement serveur.",
    },
  ];

  if (hasInvalidDrafts) {
    details.push({
      tone: "danger",
      text: "Certaines categories saisies sont invalides.",
    });
  } else if (hasDirtyDrafts) {
    details.push({
      tone: "warning",
      text: "Des modifications locales attendent d'etre appliquees.",
    });
  }

  return {
    tone: "warning",
    title: "Reglages locaux actifs",
    details,
  };
}

function parseAuditPayload(rawValue) {
  if (!rawValue) {
    return null;
  }

  if (typeof rawValue === "object") {
    return rawValue;
  }

  if (typeof rawValue !== "string") {
    return null;
  }

  try {
    return JSON.parse(rawValue);
  } catch (_error) {
    return null;
  }
}

function getAuditSettingScope(row) {
  const newData = parseAuditPayload(row?.NewData);
  const oldData = parseAuditPayload(row?.OldData);
  const settingScope = newData?.settingScope || oldData?.settingScope || "global";
  const scopeValue = newData?.scopeValue ?? oldData?.scopeValue ?? null;

  return {
    scope: settingScope,
    scopeValue: scopeValue == null || scopeValue === "" ? null : String(scopeValue),
  };
}

function isSameAdminUiScope(leftScope, rightScope) {
  if (!leftScope || !rightScope) {
    return false;
  }

  return (
    String(leftScope.scope || "global") === String(rightScope.scope || "global") &&
    String(leftScope.scopeValue ?? "") === String(rightScope.scopeValue ?? "")
  );
}

function buildAdminUiScopeLabelFromValues(scope, scopeValue) {
  return buildAdminUiScopeLabel(
    createAdminUiScope(scope || "global", scopeValue, scope === "global" ? "Global" : String(scopeValue || ""))
  );
}

function buildAdminUiScopeLabel(scope) {
  if (!scope) {
    return "Portee globale";
  }

  if (scope.scope === "entity") {
    return scope.name ? `Portee entite: ${scope.name}` : `Portee entite: ${scope.scopeValue}`;
  }

  if (scope.scope === "country") {
    if (scope.name && scope.code) {
      return `Portee pays: ${scope.name} (${scope.code})`;
    }

    return scope.name ? `Portee pays: ${scope.name}` : `Portee pays: ${scope.scopeValue}`;
  }

  return "Portee globale";
}

function createAdminUiScope(scope, scopeValue, name = "", code = "") {
  return {
    scope,
    scopeValue: scopeValue == null || scopeValue === "" ? null : String(scopeValue),
    name: String(name || "").trim(),
    code: String(code || "").trim(),
  };
}

function buildAdminUiScopeCandidates(user) {
  const candidates = [];
  const scopeContext = user?.scopeContext || {};

  if (scopeContext.entity?.id) {
    candidates.push(createAdminUiScope("entity", scopeContext.entity.id, scopeContext.entity.name));
  }

  if (scopeContext.country?.id || scopeContext.country?.code) {
    candidates.push(
      createAdminUiScope(
        "country",
        scopeContext.country.id || scopeContext.country.code,
        scopeContext.country.name,
        scopeContext.country.code
      )
    );
  }

  candidates.push(createAdminUiScope("global", null, "Global"));

  return ADMIN_UI_SCOPE_PRIORITY.flatMap((priority) =>
    candidates.filter(
      (item, index, array) =>
        item.scope === priority &&
        array.findIndex((candidate) => candidate.scope === item.scope && candidate.scopeValue === item.scopeValue) === index
    )
  );
}

function wait(ms) {
  return new Promise((resolve) => {
    window.setTimeout(resolve, ms);
  });
}

function formatCellValue(value) {
  if (value == null) {
    return "-";
  }

  if (typeof value === "object") {
    return JSON.stringify(value, null, 2);
  }

  if (isLikelyIsoDateTimeString(value)) {
    const formattedDateTime = formatDisplayDateTime(value);

    if (formattedDateTime) {
      return formattedDateTime;
    }
  }

  return String(value);
}

function normalizeSearchText(value) {
  return String(value || "")
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "");
}

function getFilterableCellValue(value) {
  if (value == null) {
    return "";
  }

  if (typeof value === "object") {
    return "";
  }

  return String(value);
}

function compareSortableValues(leftValue, rightValue) {
  if (leftValue == null && rightValue == null) {
    return 0;
  }

  if (leftValue == null) {
    return 1;
  }

  if (rightValue == null) {
    return -1;
  }

  const leftNumber = Number(leftValue);
  const rightNumber = Number(rightValue);
  const leftIsNumber = String(leftValue).trim() !== "" && Number.isFinite(leftNumber);
  const rightIsNumber = String(rightValue).trim() !== "" && Number.isFinite(rightNumber);

  if (leftIsNumber && rightIsNumber) {
    return leftNumber - rightNumber;
  }

  const leftDate = Date.parse(leftValue);
  const rightDate = Date.parse(rightValue);
  const leftIsDate = Number.isFinite(leftDate);
  const rightIsDate = Number.isFinite(rightDate);

  if (leftIsDate && rightIsDate) {
    return leftDate - rightDate;
  }

  return normalizeSearchText(leftValue).localeCompare(normalizeSearchText(rightValue), "fr");
}

function escapeCsvValue(value) {
  const normalized = String(value ?? "");

  if (/[",;\n]/.test(normalized)) {
    return `"${normalized.replace(/"/g, '""')}"`;
  }

  return normalized;
}

function buildColumnFilterSummary(selectedValues) {
  if (!Array.isArray(selectedValues) || selectedValues.length === 0) {
    return "Toutes les valeurs";
  }

  if (selectedValues.length === 1) {
    return selectedValues[0];
  }

  return `${selectedValues.length} valeurs`;
}

function createInitialValues(fields) {
  return fields.reduce((accumulator, field) => {
    accumulator[field.name] = field.type === "checkbox" ? Boolean(field.initialValue) : field.initialValue ?? "";
    return accumulator;
  }, {});
}

function filterGenericsByCategory(generics, categoryPattern) {
  return generics.filter(item => categoryPattern.test(categoricalKey(item.NomCategorieGenerique)));
}

function isTrueFlag(value) {
  if (value === true || value === 1) return true;
  return ["true", "1", "yes", "oui"].includes(categoricalKey(value));
}

function isFalseFlag(value) {
  if (value === false || value === 0) {
    return true;
  }

  const normalized = categoricalKey(value);
  return normalized === "false" || normalized === "0" || normalized === "no" || normalized === "non";
}

function filterGenericsByCategoryIds(generics, categoryIds, predicate = null) {
  const allowedIds = new Set(categoryIds.map((value) => Number(value)));
  const matches = generics.filter((item) => {
    const categoryId = Number(item.ID_CategorieGeneriqueFk ?? item.ID_CategorieGenerique);
    const categoryMatches = allowedIds.has(categoryId);
    const predicateMatches = typeof predicate === "function" ? predicate(item) : true;
    return categoryMatches && predicateMatches;
  });

  return matches;
}

function serializeCategoryIds(categoryIds) {
  return categoryIds.map((value) => String(value)).join(", ");
}

function parseCategoryOverrideInput(value) {
  const parts = String(value ?? "")
    .split(",")
    .map((item) => item.trim())
    .filter(Boolean);

  const parsed = [];

  for (const part of parts) {
    const number = Number(part);

    if (!Number.isInteger(number) || number <= 0) {
      return null;
    }

    if (!parsed.includes(number)) {
      parsed.push(number);
    }
  }

  return parsed;
}

function readGenericCategoryOverrides() {
  if (typeof window === "undefined") {
    return {};
  }

  try {
    const rawValue = window.localStorage.getItem(ADMIN_GENERIC_CATEGORY_STORAGE_KEY);

    if (!rawValue) {
      return {};
    }

    const parsed = JSON.parse(rawValue);
    return parsed && typeof parsed === "object" ? parsed : {};
  } catch (_error) {
    return {};
  }
}

function readHierarchyFilterModes() {
  if (typeof window === "undefined") {
    return {};
  }

  try {
    const rawValue = window.localStorage.getItem(ADMIN_HIERARCHY_FILTER_STORAGE_KEY);

    if (!rawValue) {
      return {};
    }

    const parsed = JSON.parse(rawValue);
    return parsed && typeof parsed === "object" ? parsed : {};
  } catch (_error) {
    return {};
  }
}

function getConfiguredCategoryIdsForSource(source, overrides) {
  const config = GENERIC_OPTION_SOURCE_CONFIG[source];

  if (!config) {
    return [];
  }

  const overrideValue = overrides?.[source];
  const parsedOverride = parseCategoryOverrideInput(overrideValue);
  return parsedOverride && parsedOverride.length > 0 ? parsedOverride : config.defaultCategoryIds;
}

function buildGenericSupportList() {
  // Les valeurs génériques sont chargées par champ physique via le service central.
  return [];
}

function getHierarchyFilterMode(source, modes) {
  const config = HIERARCHY_OPTION_SOURCE_CONFIG[source];

  if (!config) {
    return "filtered";
  }

  return modes?.[source] === "all" ? "all" : config.defaultMode;
}

function preferSupportRows(viewRows, tableRows) {
  return viewRows.length > 0 ? viewRows : tableRows;
}

function getEditorContextValue(editorValues, keys) {
  for (const key of keys) {
    const value = editorValues?.[key];
    if (value !== "" && value != null) {
      return String(value);
    }
  }

  return "";
}

function filterRowsByParent(rows, rowKey, editorValues, editorKeys) {
  const parentValue = getEditorContextValue(editorValues, editorKeys);

  if (!parentValue) {
    return rows;
  }

  return rows.filter((row) => String(row?.[rowKey] ?? "") === parentValue);
}

function findSupportRowById(rows, idKey, value) {
  if (value == null || value === "") {
    return null;
  }

  return rows.find((row) => String(row?.[idKey] ?? "") === String(value)) || null;
}

function buildNiveau2OptionLabel(row) {
  const typeLabel = row?.Type_Niveau_2 || row?.AbrGenerique || "";
  const mainLabel = typeLabel && row?.NomNiveau_2 ? `${typeLabel} (${row.NomNiveau_2})` : row?.NomNiveau_2 || "";
  return buildOptionLabel([mainLabel, row?.NomNiveau_1], `Niveau 2 ${row?.ID_Niveau_2 ?? ""}`);
}

function buildNiveau3OptionLabel(row, supportData) {
  const typeLabel = row?.Type_Niveau_3 || row?.AbrGenerique || "";
  const mainLabel = typeLabel && row?.NomNiveau_3 ? `${typeLabel} (${row.NomNiveau_3})` : row?.NomNiveau_3 || "";
  const parentNiveau2 =
    row?.NomNiveau_2 || findSupportRowById(supportData.niveaux2, "ID_Niveau_2", row?.ID_Niveau_2_FK)?.NomNiveau_2 || "";
  const parentNiveau1 =
    row?.NomNiveau_1 ||
    findSupportRowById(supportData.niveaux2, "ID_Niveau_2", row?.ID_Niveau_2_FK)?.NomNiveau_1 ||
    "";

  return buildOptionLabel([mainLabel, parentNiveau2, parentNiveau1], `Niveau 3 ${row?.ID_Niveau_3 ?? ""}`);
}

function buildNiveau4OptionLabel(row) {
  const mainLabel = row?.SITE || buildOptionLabel([row?.Type_Niveau_4, row?.NomNiveau_4], row?.NomNiveau_4 || "");
  return buildOptionLabel([mainLabel, row?.NomNiveau_3, row?.NomNiveau_2, row?.NomNiveau_1], `Niveau 4 ${row?.ID_Niveau_4 ?? ""}`);
}

function buildNiveau5OptionLabel(row) {
  const mainLabel = row?.SITE || buildOptionLabel([row?.Type_Niveau_5, row?.NomNiveau_5], row?.NomNiveau_5 || "");
  return buildOptionLabel([mainLabel, row?.NomNiveau_3, row?.NomNiveau_2, row?.NomNiveau_1], `Niveau 5 ${row?.ID_Niveau_5 ?? ""}`);
}

function getDefaultColumnWidth(column) {
  const normalized = normalizeSearchText(column);

  if (/olddata|newdata|description|adresse|detaillee|email/.test(normalized)) {
    return 280;
  }

  if (/date|time|login/.test(normalized)) {
    return 210;
  }

  if (/phone|telephone|nom|prenom|role|type|statut/.test(normalized)) {
    return 180;
  }

  if (/id|sexe|admin|staff|valide|visible/.test(normalized)) {
    return 150;
  }

  return 200;
}

function getSchemaTitle(schema) {
  return SCHEMA_TITLES[schema] || `Schema ${schema}`;
}

const COLUMN_LABEL_OVERRIDES = {
  IdUser: "ID utilisateur",
  PrenomUser: "Prenom",
  DatecreationUser: "Date creation",
  ValideGenerique: "Actif",
  NomGenerique: "Libelle",
  AbrGenerique: "Code",
  IdLogin: "ID login",
  IdLog: "ID log",
  IdEntite: "ID entite",
  IdEntiteLocalisation: "ID localisation",
  IdLicence: "ID licence",
  statut_licence: "Statut licence",
  SettingGroup: "Groupe",
  SettingKey: "Cle",
  SettingLabel: "Libelle",
  SettingType: "Type",
  SettingScope: "Scope",
  ScopeValue: "Valeur scope",
  UpdatedByName: "Mis a jour par",
  UpdatedAt: "Mis a jour le",
  ModuleName: "Module",
  SchemaName: "Schema",
  ViewName: "Vue",
  SourceKey: "Cle source",
  FieldName: "Champ",
  FieldLabel: "Libelle champ",
  MappingType: "Type mapping",
  NomCategorieGenerique: "Categorie",
  MappingValue: "Valeur mapping",
  ValideFkCorrespondance: "Actif",
  OldData: "Anciennes donnees",
  NewData: "Nouvelles donnees",
  TableName: "Table",
  Operation: "Operation",
  ChangedAt: "Date modification",
  TypeLogin: "Type connexion",
  DateLogin: "Date connexion",
  EmailUser: "Email utilisateur",
  PhoneUser: "Telephone utilisateur",
  UrlPhoto: "Photo",
  Is_staff: "Acces staff",
  Is_Admin: "Acces admin",
  ValideUser: "Compte valide",
  NomEntite: "Nom entite",
  EmailEntite: "Email entite",
  PhoneEntite: "Telephone entite",
  AdresseEntite: "Adresse entite",
  AdresseDetaillee: "Adresse detaillee",
  ID_Niveau_0_Fk: "Parent niveau 0",
  ID_Niveau_1_Old_Fk: "Ancien niveau 1",
  ID_Niveau_1_FK: "Parent niveau 1",
  ID_Niveau_2_FK: "Parent niveau 2",
  ID_Niveau_3_Fk: "Parent niveau 3",
  ID_Niveau_4_Fk: "Parent niveau 4",
  ID_TypeNiveau_2_Fk: "Type niveau",
  ID_TypeNiveau_4_Fk: "Type niveau 4",
  ID_TypeNiveau_5_Fk: "Type niveau 5",
  ID_StatusDeploiFk: "Statut deploiement",
  ID_StatutDeploieFk: "Statut deploiement",
  ID_DispoReseauNiveau_4: "Disponibilite reseau",
  ID_DispoReseauNiveau_5: "Disponibilite reseau",
  ID_VoieAccesDPSANTFk: "Voie acces DPS",
  ID_VoieAccesANTBCZFk: "Voie acces antenne",
  ID_VoieAccesDPSBCZFk: "Voie acces DPS BCZS",
  ID_VoieAccesZsASFk: "Voie acces ZS-AS",
  ID_VoieAccesZsSiteFk: "Voie acces ZS-site",
  ID_TypeToitFk: "Type de toit",
  KmDPSANT: "Distance DPS",
  KmAntenneBCZS: "Distance antenne BCZS",
  KmDPSBCZS: "Distance DPS BCZS",
  KmZoneSanteAS: "Distance zone de sante",
  KmZoneSanteNiveau_5: "Distance zone de sante",
  VOIE_AS_ZS: "Voie AS-ZS",
  VOIE_AS_Site: "Voie AS-site",
  STATUT_AS: "Statut AS",
  STATUT_Site: "Statut site",
  STATUT_DEPLOI: "Statut deploiement",
  RESEAU: "Reseau",
  SITE: "Site",
};

function getColumnDisplayLabel(column) {
  if (!column) {
    return "";
  }

  if (COLUMN_LABEL_OVERRIDES[column]) {
    return COLUMN_LABEL_OVERRIDES[column];
  }

  const normalized = String(column)
    .replace(/_/g, " ")
    .replace(/([a-z])([A-Z0-9])/g, "$1 $2")
    .replace(/([0-9])([A-Za-z])/g, "$1 $2")
    .replace(/\s+/g, " ")
    .trim();

  return normalized
    .replace(/\bID\b/g, "ID")
    .replace(/\bFk\b/g, "FK")
    .replace(/\bOld\b/g, "historique")
    .replace(/\bNom\b/g, "Nom")
    .replace(/\bCode\b/g, "Code")
    .replace(/\bLatitude\b/g, "Latitude")
    .replace(/\bLongitude\b/g, "Longitude")
    .replace(/\bAltitude\b/g, "Altitude")
    .replace(/\bPopulation\b/g, "Population")
    .replace(/\bgeometry\b/g, "Geometrie")
    .replace(/\bsurface\b/g, "Surface");
}

function getAdminViewStorageKey(viewKey) {
  return `${ADMIN_VIEW_STORAGE_PREFIX}${viewKey}`;
}

function resolveRowRecordId(row, crudConfig) {
  if (!crudConfig?.primaryKey || !row) {
    return null;
  }

  const rawValue = row[crudConfig.primaryKey];

  if (rawValue === undefined || rawValue === null || rawValue === "") {
    return null;
  }

  return String(rawValue);
}

function loadStoredAdminViewState(viewKey) {
  if (!viewKey) {
    return null;
  }

  try {
    const raw = window.localStorage.getItem(getAdminViewStorageKey(viewKey));
    return raw ? JSON.parse(raw) : null;
  } catch (error) {
    return null;
  }
}

function saveStoredAdminViewState(viewKey, state) {
  if (!viewKey) {
    return;
  }

  try {
    window.localStorage.setItem(getAdminViewStorageKey(viewKey), JSON.stringify(state));
  } catch (error) {
    console.warn("Impossible d'enregistrer les preferences admin.", error);
  }
}

function sortSelectOptions(options) {
  return [...options].sort((leftOption, rightOption) =>
    normalizeSearchText(leftOption.label || "").localeCompare(normalizeSearchText(rightOption.label || ""), "fr")
  );
}

function getFieldOptions(field, supportData, editorValues = {}, hierarchyFilterModes = {}, physicalTable="") {
  if (physicalTable && GENERIC_OPTION_SOURCE_CONFIG[field.optionsSource]) {
    return referenceOptions(supportData.referenceByField?.[physicalTable+"."+field.name]?.options || []);
  }
  if (Array.isArray(field.options)) {
    return sortSelectOptions(field.options);
  }

  if (field.optionsSource === "niveaux0") {
    const rows =
      getHierarchyFilterMode("niveaux0", hierarchyFilterModes) === "all" ? supportData.niveaux0 : supportData.niveaux0;

    return sortSelectOptions(rows.map((item) => ({
      value: String(item.ID_Niveau_0),
      label: item.NomNiveau_0 || `Niveau 0 ${item.ID_Niveau_0}`,
    })));
  }

  if (field.optionsSource === "niveaux1Old") {
    const rows =
      getHierarchyFilterMode("niveaux1Old", hierarchyFilterModes) === "all"
        ? supportData.niveaux1Old
        : supportData.niveaux1Old;

    return sortSelectOptions(rows.map((item) => ({
      value: String(item.ID_Niveau_1_Old),
      label: item.NomNiveau_1_Old || `Niveau 1 ancien ${item.ID_Niveau_1_Old}`,
    })));
  }

  if (field.optionsSource === "niveaux1") {
    const rows =
      getHierarchyFilterMode("niveaux1", hierarchyFilterModes) === "all"
        ? supportData.niveaux1
        : filterRowsByParent(supportData.niveaux1, "ID_Niveau_0_Fk", editorValues, ["ID_Niveau_0_Fk", "IdNiveau_0_Fk"]);

    return sortSelectOptions(rows.map((item) => ({
      value: String(item.ID_Niveau_1),
      label: buildOptionLabel([item.NomNiveau_1, item.NomNiveau_0], `Niveau 1 ${item.ID_Niveau_1}`),
    })));
  }

  if (field.optionsSource === "niveaux2") {
    const rows =
      getHierarchyFilterMode("niveaux2", hierarchyFilterModes) === "all"
        ? supportData.niveaux2
        : filterRowsByParent(supportData.niveaux2, "ID_Niveau_1_FK", editorValues, ["ID_Niveau_1_FK", "IdNiveau_1_FK"]);

    return sortSelectOptions(rows.map((item) => ({
      value: String(item.ID_Niveau_2),
      label: buildNiveau2OptionLabel(item),
    })));
  }

  if (field.optionsSource === "niveaux3") {
    const rows =
      getHierarchyFilterMode("niveaux3", hierarchyFilterModes) === "all"
        ? supportData.niveaux3
        : filterRowsByParent(supportData.niveaux3, "ID_Niveau_2_FK", editorValues, ["ID_Niveau_2_FK", "IdNiveau_2_FK"]);

    return sortSelectOptions(rows.map((item) => ({
      value: String(item.ID_Niveau_3),
      label: buildNiveau3OptionLabel(item, supportData),
    })));
  }

  if (field.optionsSource === "niveaux4") {
    const rows =
      getHierarchyFilterMode("niveaux4", hierarchyFilterModes) === "all"
        ? supportData.niveaux4
        : filterRowsByParent(supportData.niveaux4, "ID_Niveau_3_Fk", editorValues, ["ID_Niveau_3_Fk", "IdNiveau_3_Fk"]);

    return sortSelectOptions(rows.map((item) => ({
      value: String(item.ID_Niveau_4),
      label: buildNiveau4OptionLabel(item),
    })));
  }

  if (field.optionsSource === "niveaux5") {
    const parentNiveau4 = getEditorContextValue(editorValues, ["ID_Niveau_4_Fk", "IdNiveau_4_Fk"]);
    const rows =
      getHierarchyFilterMode("niveaux5", hierarchyFilterModes) === "all"
        ? supportData.niveaux5
        : parentNiveau4
          ? supportData.niveaux5.filter((item) => String(item?.ID_Niveau_4_Fk ?? "") === parentNiveau4)
          : filterRowsByParent(supportData.niveaux5, "ID_Niveau_3_Fk", editorValues, ["ID_Niveau_3_Fk", "IdNiveau_3_Fk"]);

    return sortSelectOptions(rows.map((item) => ({
      value: String(item.ID_Niveau_5),
      label: buildNiveau5OptionLabel(item),
    })));
  }

  if (field.optionsSource === "roles") {
    return sortSelectOptions(supportData.roles.map((item) => ({
      value: String(item.ID_Generique),
      label: referenceLabel(item),
    })));
  }

  if (field.optionsSource === "entities") {
    return sortSelectOptions(supportData.entities.map((item) => ({
      value: String(item.IdEntite),
      label: item.NomEntite || `Entite ${item.IdEntite}`,
    })));
  }

  if (field.optionsSource === "categories") {
    return sortSelectOptions(supportData.categories.map((item) => ({
      value: String(item.ID_CategorieGenerique),
      label: item.NomCategorieGenerique || `Categorie ${item.ID_CategorieGenerique}`,
    })));
  }

  if (field.optionsSource === "entityTypes") {
    return sortSelectOptions(supportData.entityTypes.map((item) => ({
      value: String(item.ID_Generique),
      label: referenceLabel(item),
    })));
  }

  if (field.optionsSource === "licenseStatuses") {
    return sortSelectOptions(supportData.licenseStatuses.map((item) => ({
      value: String(item.ID_Generique),
      label: referenceLabel(item),
    })));
  }

  if (field.optionsSource === "niveau2Types") {
    return sortSelectOptions(supportData.niveau2Types.map((item) => ({
      value: String(item.ID_Generique),
      label: referenceLabel(item),
    })));
  }

  if (field.optionsSource === "niveau3Types") {
    return sortSelectOptions(supportData.niveau3Types.map((item) => ({
      value: String(item.ID_Generique),
      label: referenceLabel(item),
    })));
  }

  if (field.optionsSource === "niveau2Statuses") {
    return sortSelectOptions(supportData.niveau2Statuses.map((item) => ({
      value: String(item.ID_Generique),
      label: referenceLabel(item),
    })));
  }

  if (field.optionsSource === "niveau3Statuses") {
    return sortSelectOptions(supportData.niveau3Statuses.map((item) => ({
      value: String(item.ID_Generique),
      label: referenceLabel(item),
    })));
  }

  if (field.optionsSource === "deploymentStatuses") {
    return sortSelectOptions(supportData.deploymentStatuses.map((item) => ({
      value: String(item.ID_Generique),
      label: referenceLabel(item),
    })));
  }

  if (field.optionsSource === "dpsAccessRoutes") {
    return sortSelectOptions(supportData.dpsAccessRoutes.map((item) => ({
      value: String(item.ID_Generique),
      label: referenceLabel(item),
    })));
  }

  if (field.optionsSource === "antBczAccessRoutes") {
    return sortSelectOptions(supportData.antBczAccessRoutes.map((item) => ({
      value: String(item.ID_Generique),
      label: referenceLabel(item),
    })));
  }

  if (field.optionsSource === "dpsBczAccessRoutes") {
    return sortSelectOptions(supportData.dpsBczAccessRoutes.map((item) => ({
      value: String(item.ID_Generique),
      label: referenceLabel(item),
    })));
  }

  if (field.optionsSource === "niveau4Types") {
    return sortSelectOptions(supportData.niveau4Types.map((item) => ({
      value: String(item.ID_Generique),
      label: referenceLabel(item),
    })));
  }

  if (field.optionsSource === "niveau5Types") {
    return sortSelectOptions(supportData.niveau5Types.map((item) => ({
      value: String(item.ID_Generique),
      label: referenceLabel(item),
    })));
  }

  if (field.optionsSource === "niveau4Statuses") {
    return sortSelectOptions(supportData.niveau4Statuses.map((item) => ({
      value: String(item.ID_Generique),
      label: referenceLabel(item),
    })));
  }

  if (field.optionsSource === "niveau5Statuses") {
    return sortSelectOptions(supportData.niveau5Statuses.map((item) => ({
      value: String(item.ID_Generique),
      label: referenceLabel(item),
    })));
  }

  if (field.optionsSource === "networkAvailabilities") {
    return sortSelectOptions(supportData.networkAvailabilities.map((item) => ({
      value: String(item.ID_Generique),
      label: referenceLabel(item),
    })));
  }

  if (field.optionsSource === "zsAsAccessRoutes") {
    return sortSelectOptions(supportData.zsAsAccessRoutes.map((item) => ({
      value: String(item.ID_Generique),
      label: referenceLabel(item),
    })));
  }

  if (field.optionsSource === "zsSiteAccessRoutes") {
    return sortSelectOptions(supportData.zsSiteAccessRoutes.map((item) => ({
      value: String(item.ID_Generique),
      label: referenceLabel(item),
    })));
  }

  if (field.optionsSource === "roofTypes") {
    return sortSelectOptions(supportData.roofTypes.map((item) => ({
      value: String(item.ID_Generique),
      label: referenceLabel(item),
    })));
  }

  return [];
}

function extractPayloadRows(payload) {
  if (payload?.success && Array.isArray(payload.data)) {
    return payload.data;
  }

  return [];
}

function normalizeGenericRows(rows, categories) {
  const categoriesById = new Map(
    categories.map((category) => [String(category.ID_CategorieGenerique), category.NomCategorieGenerique || ""])
  );

  return rows.map((item) => {
    const categoryId = item.ID_CategorieGeneriqueFk ?? item.ID_CategorieGenerique;

    return {
      ...item,
      NomCategorieGenerique:
        item.NomCategorieGenerique ||
        categoriesById.get(String(categoryId ?? "")) ||
        "",
    };
  });
}

function ensureCurrentSelectOption(options, value) {
  if (value == null || value === "") {
    return options;
  }

  const normalizedValue = String(value);
  const hasCurrentValue = options.some((option) => String(option.value) === normalizedValue);

  if (hasCurrentValue) {
    return options;
  }

  return [
    {
      value: normalizedValue,
      label: `Valeur actuelle (${normalizedValue})`,
    },
    ...options,
  ];
}

function buildOptionLabel(parts, fallback) {
  const label = parts.filter(Boolean).join(" - ").trim();
  return label || fallback || "";
}

function getSelectFallbackLabel(field, value, sourceRow) {
  if (!sourceRow || value == null || value === "") {
    return "";
  }

  switch (field.optionsSource) {
    case "niveaux0":
      return buildOptionLabel([sourceRow.NomNiveau_0], `Niveau 0 ${value}`);
    case "niveaux1Old":
      return buildOptionLabel([sourceRow.NomNiveau_1_Old], `Niveau 1 ancien ${value}`);
    case "niveaux1":
      return buildOptionLabel([sourceRow.CodeNiveau_1, sourceRow.NomNiveau_1], `Niveau 1 ${value}`);
    case "niveaux2":
      return buildOptionLabel([sourceRow.CodeNiveau_2, sourceRow.NomNiveau_2], `Niveau 2 ${value}`);
    case "niveaux3":
      return buildOptionLabel([sourceRow.CodeNiveau_3, sourceRow.NomNiveau_3], `Niveau 3 ${value}`);
    case "niveaux4":
      return buildOptionLabel([sourceRow.CodeNiveau_4, sourceRow.NomNiveau_4 || sourceRow.SITE], `Niveau 4 ${value}`);
    case "niveaux5":
      return buildOptionLabel([sourceRow.CodeNiveau_5, sourceRow.NomNiveau_5 || sourceRow.SITE], `Niveau 5 ${value}`);
    case "niveau2Types":
      return buildOptionLabel([sourceRow.Type_Niveau_2], `Type ${value}`);
    case "niveau3Types":
      return buildOptionLabel([sourceRow.Type_Niveau_3], `Type ${value}`);
    case "niveau4Types":
      return buildOptionLabel([sourceRow.Type_Niveau_4], `Type ${value}`);
    case "niveau5Types":
      return buildOptionLabel([sourceRow.Type_Niveau_5], `Type ${value}`);
    case "niveau2Statuses":
      return buildOptionLabel([sourceRow.Statut_Niveau_2], `Statut ${value}`);
    case "niveau3Statuses":
      return buildOptionLabel([sourceRow.Statut_Niveau_3], `Statut ${value}`);
    case "niveau4Statuses":
      return buildOptionLabel([sourceRow.STATUT_AS], `Statut ${value}`);
    case "niveau5Statuses":
      return buildOptionLabel([sourceRow.STATUT_Site], `Statut ${value}`);
    case "deploymentStatuses":
      return buildOptionLabel([sourceRow.Statut_Deploiement, sourceRow.STATUT_DEPLOI], `Deploiement ${value}`);
    case "networkAvailabilities":
      return buildOptionLabel([sourceRow.RESEAU], `Reseau ${value}`);
    case "dpsAccessRoutes":
      return buildOptionLabel([sourceRow.Voie_Acces_DPS], `Voie ${value}`);
    case "antBczAccessRoutes":
      return buildOptionLabel([sourceRow.Voie_ANTBCZ], `Voie ${value}`);
    case "dpsBczAccessRoutes":
      return buildOptionLabel([sourceRow.Voie_DPSBCZS], `Voie ${value}`);
    case "zsAsAccessRoutes":
      return buildOptionLabel([sourceRow.VOIE_AS_ZS], `Voie ${value}`);
    case "zsSiteAccessRoutes":
      return buildOptionLabel([sourceRow.VOIE_AS_Site], `Voie ${value}`);
    case "roles":
      return buildOptionLabel([sourceRow.RoleUser, sourceRow.Role, sourceRow.NomRole], `Role ${value}`);
    case "entities":
      return buildOptionLabel([sourceRow.NomEntite], `Entite ${value}`);
    case "categories":
      return buildOptionLabel([sourceRow.NomCategorieGenerique], `Categorie ${value}`);
    case "entityTypes":
      return buildOptionLabel([sourceRow.TypeEntite], `Type ${value}`);
    case "licenseStatuses":
      return buildOptionLabel([sourceRow.statut_licence, sourceRow.StatutLicence], `Statut ${value}`);
    case "roofTypes":
      return buildOptionLabel([sourceRow.TypeToit], `Toit ${value}`);
    default:
      return "";
  }
}

function ensureCurrentSelectOptionWithLabel(options, value, fallbackLabel) {
  if (value == null || value === "") {
    return options;
  }

  const normalizedValue = String(value);
  const hasCurrentValue = options.some((option) => String(option.value) === normalizedValue);

  if (hasCurrentValue) {
    return options;
  }

  return [
    {
      value: normalizedValue,
      label: fallbackLabel || "Valeur actuelle",
      disabled:true,incompatible:true,
    },
    ...options,
  ];
}

const DEFAULT_ADMIN_VIEW_KEY =
  ADMIN_VIEWS.find((view) => view.renderMode === "dashboard")
    ? normalizeViewKey(
        ADMIN_VIEWS.find((view) => view.renderMode === "dashboard").schema,
        ADMIN_VIEWS.find((view) => view.renderMode === "dashboard").name
      )
    : ADMIN_VIEWS.map((view) => normalizeViewKey(view.schema, view.name)).find((viewKey) => Boolean(CRUD_CONFIGS[viewKey])) ||
  (ADMIN_VIEWS[0] ? normalizeViewKey(ADMIN_VIEWS[0].schema, ADMIN_VIEWS[0].name) : "");

function DashboardMetricCard({ title, value, detail, tone = "primary", icon = "dashboard" }) {
  return (
    <article className={`admin-dashboard-metric is-${tone}`}>
      <span className="admin-dashboard-metric-icon">
        <AppIcon name={icon} size="1em"/>
      </span>
      <div>
        <strong>{title}</strong>
        <b>{value}</b>
        {detail ? <small>{detail}</small> : null}
      </div>
    </article>
  );
}

function DashboardMiniTable({ title, rows, columns, emptyLabel = "Aucune donnee recente." }) {
  return (
    <section className="admin-dashboard-panel">
      <div className="section-head">
        <h3>{title}</h3>
      </div>
      {rows.length === 0 ? (
        <div className="table-empty-state">{emptyLabel}</div>
      ) : (
        <div className="admin-dashboard-table-wrap">
          <table className="admin-dashboard-table">
            <thead>
              <tr>
                {columns.map((column) => (
                  <th key={`${title}-${column.key}`}>{column.label}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {rows.map((row, index) => (
                <tr key={`${title}-${index}`}>
                  {columns.map((column) => (
                    <td key={`${title}-${index}-${column.key}`}>{column.render ? column.render(row) : row[column.key] ?? "-"}</td>
                  ))}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </section>
  );
}

function AdminMultiSelectFilter({
  definition,
  selectedValues,
  isOpen,
  searchValue,
  onToggleOpen,
  onSearchChange,
  onToggleValue,
  onSelectAll,
  onClear,
}) {
  const visibleOptions = useMemo(
    () => definition.values.filter((value) => normalizeSearchText(value).includes(normalizeSearchText(searchValue))),
    [definition.values, searchValue]
  );

  return (
    <div className="admin-multiselect">
      <span>{definition.displayLabel || definition.column}</span>
      <button
        type="button"
        className={`admin-multiselect-trigger ${isOpen ? "is-open" : ""}`}
        onClick={onToggleOpen}
      >
        <strong>{buildColumnFilterSummary(selectedValues)}</strong>
        <small>{isOpen ? "-" : "+"}</small>
      </button>

      {isOpen ? (
        <div className="admin-multiselect-panel">
          <div className="admin-multiselect-actions">
            <button type="button" className="secondary-action" onClick={onSelectAll}>
              Tout cocher
            </button>
            <button type="button" className="secondary-action" onClick={onClear}>
              Effacer
            </button>
          </div>

          <input
            className="admin-multiselect-search"
            type="search"
            value={searchValue}
            onChange={(event) => onSearchChange(event.target.value)}
            placeholder={`Rechercher dans ${definition.displayLabel || definition.column}`}
          />

          <div className="admin-multiselect-options">
            {visibleOptions.length > 0 ? (
              visibleOptions.map((value) => {
                const checked = selectedValues.includes(value);

                return (
                  <label key={`${definition.column}-${value}`} className="admin-multiselect-option">
                    <input type="checkbox" checked={checked} onChange={() => onToggleValue(value)} />
                    <span>{value}</span>
                  </label>
                );
              })
            ) : (
              <div className="admin-multiselect-empty">Aucune valeur ne correspond a cette recherche.</div>
            )}
          </div>
        </div>
      ) : null}
    </div>
  );
}

function AdminSummaryCard({ title, value, tone = "primary" }) {
  return (
    <article className={`admin-summary-card ${tone}`}>
      <span>{title}</span>
      <strong>{value}</strong>
    </article>
  );
}

function AdminViewButton({ view, isActive, onSelect }) {
  return (
    <button className={`admin-view-button ${isActive ? "is-active" : ""}`} type="button" onClick={onSelect}>
      <strong>{view.title}</strong>
      <span>{buildViewLabel(view)}</span>
      <p>{view.description}</p>
    </button>
  );
}

export default function Admin({ schemaOnly = "", moduleTitle = "Administration", navigationCollapsed=false, onToggleNavigation }) {
  const entityReferenceScope=useEntityScope();
  const { user: currentUser } = useAuth();
  const [mailSettingsOpen,setMailSettingsOpen]=useState(false);
  const [availableViews, setAvailableViews] = useState([]);
  const [selectedViewKey, setSelectedViewKey] = useState(() => schemaOnly ? (() => { const first = ADMIN_VIEWS.find(view => view.schema === schemaOnly); return first ? normalizeViewKey(first.schema,first.name) : ""; })() : DEFAULT_ADMIN_VIEW_KEY);
  const [rows, setRows] = useState([]);
  const [viewMeta, setViewMeta] = useState({
    totalCount: 0,
    filteredCount: 0,
    take: DEFAULT_ROWS_PER_PAGE,
    skip: 0,
    sortBy: "",
    sortDir: "asc",
    columns: [],
  });
  const [loadingViews, setLoadingViews] = useState(true);
  const [loadingData, setLoadingData] = useState(true);
  const [errorMessage, setErrorMessage] = useState("");
  const [supportData, setSupportData] = useState({
    roles: [],
    entities: [],
    categories: [],
    entityTypes: [],
    licenseStatuses: [],
    niveaux0: [],
    niveaux1Old: [],
    niveaux1: [],
    niveaux2: [],
    niveaux3: [],
    niveaux4: [],
    niveaux5: [],
    niveau2Types: [],
    niveau3Types: [],
    niveau2Statuses: [],
    niveau3Statuses: [],
    deploymentStatuses: [],
    dpsAccessRoutes: [],
    antBczAccessRoutes: [],
    dpsBczAccessRoutes: [],
    niveau4Types: [],
    niveau5Types: [],
    niveau4Statuses: [],
    niveau5Statuses: [],
    networkAvailabilities: [],
    zsAsAccessRoutes: [],
    zsSiteAccessRoutes: [],
    roofTypes: [],
  });
  const [loadingSupport, setLoadingSupport] = useState(true);
  const [supportError, setSupportError] = useState("");
  const [referenceVersion, setReferenceVersion] = useState(0);
  const viewRequest = useRef(0);
  useEffect(() => () => { viewRequest.current += 1; }, []);
  useReferencesRefresh(() => setReferenceVersion(version => version + 1));
  const [editorMode, setEditorMode] = useState(null);
  const [editorRecordId, setEditorRecordId] = useState(null);
  const [editorValues, setEditorValues] = useState({});
  const [editorSourceRow, setEditorSourceRow] = useState(null);
  const [loadingEditor, setLoadingEditor] = useState(false);
  const [submittingEditor, setSubmittingEditor] = useState(false);
  const [actionFeedback, setActionFeedback] = useState(null);
  const [showSearchPanel, setShowSearchPanel] = useState(false);
  const [searchTerm, setSearchTerm] = useState("");
  const [columnFilters, setColumnFilters] = useState({});
  const [filterSearchTerms, setFilterSearchTerms] = useState({});
  const [openFilterColumn, setOpenFilterColumn] = useState("");
  const [showExportMenu, setShowExportMenu] = useState(false);
  const [showNavigationMenu, setShowNavigationMenu] = useState(false);
  const [sortConfig, setSortConfig] = useState({
    column: "",
    direction: "",
  });
  const [visibleColumns, setVisibleColumns] = useState([]);
  const [columnWidths, setColumnWidths] = useState({});
  const [pinnedColumns, setPinnedColumns] = useState([]);
  const [rowsPerPage, setRowsPerPage] = useState(DEFAULT_ROWS_PER_PAGE);
  const [currentPage, setCurrentPage] = useState(1);
  const [collapsedSchemas, setCollapsedSchemas] = useState({});
  const [notifications, setNotifications] = useState([]);
  const [selectedRowIds, setSelectedRowIds] = useState([]);
  const [expandedCells, setExpandedCells] = useState({});
  const [showFkMappingPanel, setShowFkMappingPanel] = useState(false);
  const [genericCategoryOverrides, setGenericCategoryOverrides] = useState({});
  const [genericCategoryDrafts, setGenericCategoryDrafts] = useState({});
  const [hierarchyFilterModes, setHierarchyFilterModes] = useState(() => readHierarchyFilterModes());
  const [loadingSharedFkSettings, setLoadingSharedFkSettings] = useState(true);
  const [savingSharedFkSettings, setSavingSharedFkSettings] = useState(false);
  const [sharedFkSettingsError, setSharedFkSettingsError] = useState("");
  const [sharedFkTargetScope, setSharedFkTargetScope] = useState(null);
  const [sharedFkLoadedScope, setSharedFkLoadedScope] = useState(null);
  const [sharedFkSettingsMeta, setSharedFkSettingsMeta] = useState({
    updatedAt: null,
    updatedByUserId: null,
    updatedByName: null,
  });
  const [sharedFkAuditRows, setSharedFkAuditRows] = useState([]);
  const [loadingSharedFkAudit, setLoadingSharedFkAudit] = useState(false);
  const [sharedFkAuditError, setSharedFkAuditError] = useState("");
  const [dashboardData, setDashboardData] = useState(null);
  const [loadingDashboard, setLoadingDashboard] = useState(false);
  const [dashboardError, setDashboardError] = useState("");
  const resizingRef = useRef(null);
  const tableWrapRef = useRef(null);
  const tableFooterRef = useRef(null);
  const paginationViewportRef = useRef(null);
  const exportMenuRef = useRef(null);
  const navigationMenuRef = useRef(null);
  const [horizontalScrollState, setHorizontalScrollState] = useState({
    overflow: false,
    canScrollLeft: false,
    canScrollRight: false,
  });

  const adminViews = useMemo(() => {
    const availableKeys = new Set(availableViews.map((view) => normalizeViewKey(view.schema, view.name)));
    return ADMIN_VIEWS.filter((view) => {
      if (schemaOnly && view.schema !== schemaOnly) return false;
      if (view.virtual) {
        if (view.renderMode === "dashboard" || view.renderMode === "empty") {
          return true;
        }

        const dataView = view.dataView || view;
        return availableKeys.has(normalizeViewKey(dataView.schema, dataView.name));
      }

      return availableKeys.has(normalizeViewKey(view.schema, view.name));
    });
  }, [availableViews, schemaOnly]);

  const navigationViews = useMemo(
    () => adminViews.filter((view) => view.showInNavigation !== false),
    [adminViews]
  );

  const storedAuthUser = currentUser;
  const adminUiScopeCandidates = useMemo(() => buildAdminUiScopeCandidates(storedAuthUser), [storedAuthUser]);

  const selectedView = useMemo(
    () => adminViews.find((view) => normalizeViewKey(view.schema, view.name) === selectedViewKey) || null,
    [adminViews, selectedViewKey]
  );

  const canManageView = currentUser?.permissions?.canWriteData && (currentUser?.Is_Admin || (selectedView?.schema !== "geolocalisation" && selectedView?.schema !== "referentiel" && !selectedView?.name?.includes("Licence")));
  const selectedCrudConfig = selectedView && canManageView
    ? CRUD_CONFIGS[selectedView.crudConfigKey || normalizeViewKey(selectedView.schema, selectedView.name)] || null
    : null;

  const editorFields =
    selectedCrudConfig && editorMode
      ? selectedCrudConfig.getFields?.(editorMode) || selectedCrudConfig.fields
      : selectedCrudConfig?.fields || [];

  const columns = useMemo(() => {
    if (Array.isArray(viewMeta.columns) && viewMeta.columns.length > 0) {
      return viewMeta.columns;
    }

    return rows.length > 0 ? Object.keys(rows[0]) : [];
  }, [rows, viewMeta.columns]);

  const configurableFkMappings = useMemo(() => {
    if (!selectedCrudConfig) {
      return [];
    }

    const sourceMap = new Map();
    const sourceFields = selectedCrudConfig.allFields || selectedCrudConfig.fields || [];

    sourceFields.forEach((field) => {
      if (field.type !== "select" || !GENERIC_OPTION_SOURCE_CONFIG[field.optionsSource]) {
        return;
      }

      const existing = sourceMap.get(field.optionsSource);

      if (existing) {
        existing.labels.push(field.label);
        existing.fieldNames.push(field.name);
        return;
      }

      sourceMap.set(field.optionsSource, {
        source: field.optionsSource,
        labels: [field.label],
        fieldNames: [field.name],
      });
    });

    return Array.from(sourceMap.values()).sort((leftItem, rightItem) =>
      leftItem.labels[0].localeCompare(rightItem.labels[0], "fr")
    );
  }, [selectedCrudConfig]);

  const configurableHierarchyMappings = useMemo(() => {
    if (!selectedCrudConfig) {
      return [];
    }

    const sourceMap = new Map();
    const sourceFields = selectedCrudConfig.allFields || selectedCrudConfig.fields || [];

    sourceFields.forEach((field) => {
      if (field.type !== "select" || !HIERARCHY_OPTION_SOURCE_CONFIG[field.optionsSource]) {
        return;
      }

      const existing = sourceMap.get(field.optionsSource);

      if (existing) {
        existing.labels.push(field.label);
        existing.fieldNames.push(field.name);
        return;
      }

      sourceMap.set(field.optionsSource, {
        source: field.optionsSource,
        labels: [field.label],
        fieldNames: [field.name],
      });
    });

    return Array.from(sourceMap.values()).sort((leftItem, rightItem) =>
      leftItem.labels[0].localeCompare(rightItem.labels[0], "fr")
    );
  }, [selectedCrudConfig]);

  const categoryNameById = useMemo(
    () =>
      new Map(
        supportData.categories.map((category) => [
          String(category.ID_CategorieGenerique),
          category.NomCategorieGenerique || `Categorie ${category.ID_CategorieGenerique}`,
        ])
      ),
    [supportData.categories]
  );

  const genericMappingStates = useMemo(
    () =>
      configurableFkMappings.map((mapping) => {
        const config = GENERIC_OPTION_SOURCE_CONFIG[mapping.source];
        const defaultValue = serializeCategoryIds(config.defaultCategoryIds);
        const storedOverride = genericCategoryOverrides[mapping.source];
        const inputValue = genericCategoryDrafts[mapping.source] ?? storedOverride ?? defaultValue;
        const parsedInput = parseCategoryOverrideInput(inputValue);
        const isValid = Boolean(parsedInput && parsedInput.length > 0);
        const normalizedInput = isValid ? serializeCategoryIds(parsedInput) : String(inputValue ?? "").trim();
        const isDirty = normalizedInput !== String(storedOverride ?? defaultValue);
        const effectiveIds = getConfiguredCategoryIdsForSource(mapping.source, genericCategoryOverrides);
        const effectiveCategoryLabels = effectiveIds
          .map((categoryId) => categoryNameById.get(String(categoryId)) || `Categorie ${categoryId}`)
          .join(", ");
        const optionsCount = Array.isArray(supportData[mapping.source]) ? supportData[mapping.source].length : 0;

        return {
          ...mapping,
          config,
          defaultValue,
          storedOverride,
          inputValue,
          parsedInput,
          isValid,
          isDirty,
          isCustom: Boolean(storedOverride),
          effectiveIds,
          effectiveCategoryLabels,
          optionsCount,
        };
      }),
    [categoryNameById, configurableFkMappings, genericCategoryDrafts, genericCategoryOverrides, supportData]
  );

  const hierarchyMappingStates = useMemo(
    () =>
      configurableHierarchyMappings.map((mapping) => {
        const config = HIERARCHY_OPTION_SOURCE_CONFIG[mapping.source];
        const mode = getHierarchyFilterMode(mapping.source, hierarchyFilterModes);
        const optionsCount = Array.isArray(supportData[mapping.source]) ? supportData[mapping.source].length : 0;

        return {
          ...mapping,
          config,
          mode,
          isCustom: mode !== config.defaultMode,
          optionsCount,
        };
      }),
    [configurableHierarchyMappings, hierarchyFilterModes, supportData]
  );

  const hasInvalidGenericDrafts = genericMappingStates.some((item) => !item.isValid);
  const hasDirtyGenericDrafts = genericMappingStates.some((item) => item.isDirty);
  const hasCustomFkSettings =
    genericMappingStates.some((item) => item.isCustom) || hierarchyMappingStates.some((item) => item.isCustom);
  const sharedFkTargetScopeLabel = buildAdminUiScopeLabel(sharedFkTargetScope);
  const sharedFkLoadedScopeLabel = sharedFkLoadedScope ? buildAdminUiScopeLabel(sharedFkLoadedScope) : "";
  function applySharedFkServerPayload(payload, scope) {
    setSharedFkSettingsError("");
    setGenericCategoryOverrides({});
    setHierarchyFilterModes(normalizeHierarchyModes(payload.hierarchyFilterModes));
    setGenericCategoryDrafts({});
    setSharedFkLoadedScope(scope);
    setSharedFkSettingsMeta({
      updatedAt: payload.updatedAt || null,
      updatedByUserId: payload.updatedByUserId ?? null,
      updatedByName: payload.updatedByName || null,
    });
  }

  function resetSharedFkServerPayload() {
    setSharedFkLoadedScope(null);
    setSharedFkSettingsMeta({
      updatedAt: null,
      updatedByUserId: null,
      updatedByName: null,
    });
  }

  async function fetchSharedFkSettingsCandidate(candidate) {
    let response = await fetchAdminUiSettings({
      scope: candidate.scope,
      scopeValue: candidate.scopeValue,
    });

    if (response) {
      return response;
    }

    await wait(250);

    return fetchAdminUiSettings({
      scope: candidate.scope,
      scopeValue: candidate.scopeValue,
    });
  }

  const sharedFkSyncStatus = useMemo(
    () =>
      buildSharedFkSyncStatus({
        loading: loadingSharedFkSettings,
        saving: savingSharedFkSettings,
        error: sharedFkSettingsError,
        targetScopeLabel: sharedFkTargetScopeLabel,
        loadedScope: sharedFkLoadedScope,
        loadedScopeLabel: sharedFkLoadedScopeLabel,
        meta: sharedFkSettingsMeta,
        hasDirtyDrafts: hasDirtyGenericDrafts,
        hasInvalidDrafts: hasInvalidGenericDrafts,
      }),
    [
      hasDirtyGenericDrafts,
      hasInvalidGenericDrafts,
      loadingSharedFkSettings,
      savingSharedFkSettings,
      sharedFkLoadedScope,
      sharedFkLoadedScopeLabel,
      sharedFkSettingsError,
      sharedFkSettingsMeta,
      sharedFkTargetScopeLabel,
    ]
  );
  const sharedFkAuditTargetScope = sharedFkLoadedScope || sharedFkTargetScope;
  const visibleSharedFkAuditRows = useMemo(() => {
    const filteredRows = sharedFkAuditRows.filter((row) => {
      if (!sharedFkAuditTargetScope) {
        return true;
      }

      return isSameAdminUiScope(getAuditSettingScope(row), sharedFkAuditTargetScope);
    });

    return filteredRows.slice(0, 4);
  }, [sharedFkAuditRows, sharedFkAuditTargetScope]);


  useEffect(() => {
    if (typeof window === "undefined") {
      return;
    }

    window.localStorage.setItem(ADMIN_HIERARCHY_FILTER_STORAGE_KEY, JSON.stringify(hierarchyFilterModes));
  }, [hierarchyFilterModes]);

  useEffect(() => {
    let active = true;

    async function loadSharedAdminUiSettings() {
      setLoadingSharedFkSettings(true);
      setSharedFkSettingsError("");
      const scopeCandidates = adminUiScopeCandidates.length > 0 ? adminUiScopeCandidates : [createAdminUiScope("global", null, "Global")];

      try {
        if (!active) {
          return;
        }

        setSharedFkTargetScope(scopeCandidates[0] || null);

        let matchingPayload = null;
        let matchingScope = null;
        let lastErrorMessage = "";

        for (const candidate of scopeCandidates) {
          const response = await fetchSharedFkSettingsCandidate(candidate);

          if (!active) {
            return;
          }

          if (response?.success && response.data?.exists) {
            matchingPayload = response.data;
            matchingScope = candidate;
            break;
          }

          if (response && !response.success) {
            lastErrorMessage = response.message || "Impossible de charger les reglages partages du panneau FK.";
          }
        }

        if (matchingPayload) {
          applySharedFkServerPayload(matchingPayload, matchingScope);
          return;
        }

        if (lastErrorMessage) {
          setSharedFkSettingsError(lastErrorMessage);
        }

        resetSharedFkServerPayload();
      } catch (_error) {
        if (!active) {
          return;
        }

        setSharedFkSettingsError("Impossible de charger les reglages partages du panneau FK.");
      } finally {
        if (active) {
          setLoadingSharedFkSettings(false);
        }
      }
    }

    loadSharedAdminUiSettings();

    return () => {
      active = false;
    };
  }, [adminUiScopeCandidates]);

  useEffect(() => {
    let active = true;

    async function loadSharedFkAuditTrail() {
      if (!showFkMappingPanel) {
        return;
      }

      setLoadingSharedFkAudit(true);
      setSharedFkAuditError("");

      const payload = await fetchAdminUiSettingsAudit({
        take: 12,
        skip: 0,
      });

      if (!active) {
        return;
      }

        if (payload?.success && Array.isArray(payload.data)) {
          setSharedFkAuditRows(payload.data);
          setSharedFkAuditError("");

          const scopeCandidates = adminUiScopeCandidates.length > 0 ? adminUiScopeCandidates : [createAdminUiScope("global", null, "Global")];
          const shouldResyncSharedFkSettings = Boolean(sharedFkSettingsError) || !sharedFkLoadedScope;

          if (shouldResyncSharedFkSettings) {
            const hasAuditForKnownScope = scopeCandidates.some((candidate) =>
              payload.data.some((row) => isSameAdminUiScope(getAuditSettingScope(row), candidate))
            );

            if (!hasAuditForKnownScope && !sharedFkSettingsError) {
              setLoadingSharedFkAudit(false);
              return;
            }

            for (const candidate of scopeCandidates) {
              const response = await fetchSharedFkSettingsCandidate(candidate);

            if (!active) {
              return;
            }

            if (response?.success && response.data?.exists) {
              applySharedFkServerPayload(response.data, candidate);
                break;
              }
            }
          }
        } else {
        setSharedFkAuditRows([]);
        setSharedFkAuditError(payload?.message || "Impossible de charger l'historique compact des reglages FK.");
      }

      setLoadingSharedFkAudit(false);
    }

    loadSharedFkAuditTrail();

    return () => {
      active = false;
    };
  }, [adminUiScopeCandidates, sharedFkLoadedScope, sharedFkSettingsError, showFkMappingPanel, sharedFkSettingsMeta.updatedAt]);

  useEffect(() => {
    if (configurableFkMappings.length === 0) {
      return;
    }

    setGenericCategoryDrafts((current) => {
      const nextDrafts = { ...current };

      configurableFkMappings.forEach((item) => {
        if (nextDrafts[item.source] == null) {
          nextDrafts[item.source] =
            genericCategoryOverrides[item.source] ??
            serializeCategoryIds(GENERIC_OPTION_SOURCE_CONFIG[item.source].defaultCategoryIds);
        }
      });

      return nextDrafts;
    });
  }, [configurableFkMappings, genericCategoryOverrides]);

  const effectiveVisibleColumns = useMemo(() => {
    if (columns.length === 0) {
      return [];
    }

    if (!Array.isArray(visibleColumns) || visibleColumns.length === 0) {
      return columns;
    }

    const nextVisibleColumns = visibleColumns.filter((column) => columns.includes(column));
    const missingColumns = columns.filter((column) => !nextVisibleColumns.includes(column));
    return [...nextVisibleColumns, ...missingColumns];
  }, [columns, visibleColumns]);

  const filterableColumns = useMemo(
    () =>
      columns.filter((column) => {
        if (/OldData|NewData/i.test(column)) {
          return false;
        }

        return rows.some((row) => {
          const value = row[column];
          return value != null && typeof value !== "object";
        });
      }),
    [columns, rows]
  );

  const columnFilterDefinitions = useMemo(
    () =>
      filterableColumns.map((column) => {
        const values = Array.from(
          new Set(
            rows
              .map((row) => getFilterableCellValue(row[column]).trim())
              .filter((value) => Boolean(value))
          )
        ).sort((leftValue, rightValue) => compareSortableValues(leftValue, rightValue));

        return {
          column,
          displayLabel: getColumnDisplayLabel(column),
          values,
          useMultiSelect: values.length > 1 && values.length <= 80,
        };
      }),
    [filterableColumns, rows]
  );

  const filteredRows = rows;
  const sortedRows = rows;
  const selectedRows = useMemo(() => {
    if (!selectedCrudConfig) {
      return [];
    }

    return rows.filter((row) => {
      const recordId = resolveRowRecordId(row, selectedCrudConfig);
      return recordId ? selectedRowIds.includes(recordId) : false;
    });
  }, [rows, selectedCrudConfig, selectedRowIds]);

  const selectedPrimaryRow = selectedRows[0] || null;

  const totalPages = useMemo(
    () => Math.max(1, Math.ceil((viewMeta.filteredCount || rows.length || 1) / rowsPerPage)),
    [rows.length, rowsPerPage, viewMeta.filteredCount]
  );

  const paginatedRows = rows;

  const schemaGroups = useMemo(() => {
    const schemaOrder = Array.from(new Set(ADMIN_VIEWS.map((view) => view.schema)));

    return schemaOrder
      .map((schema) => {
        const views = navigationViews.filter((view) => view.schema === schema);
        const crudViews = views.filter((view) =>
          Boolean(CRUD_CONFIGS[view.crudConfigKey || normalizeViewKey(view.schema, view.name)])
        );
        const readOnlyViews = views.filter(
          (view) => !CRUD_CONFIGS[view.crudConfigKey || normalizeViewKey(view.schema, view.name)]
        );

        return {
          schema,
          title: getSchemaTitle(schema),
          crudViews,
          readOnlyViews,
        };
      })
      .filter((group) => group.crudViews.length > 0 || group.readOnlyViews.length > 0);
  }, [navigationViews]);

  const activeFilterChips = useMemo(() => {
    const chips = [];

    if (searchTerm.trim()) {
      chips.push({
        key: "global-search",
        label: `Recherche: ${searchTerm.trim()}`,
        onRemove: () => setSearchTerm(""),
      });
    }

    Object.entries(columnFilters).forEach(([column, filterValue]) => {
      if (Array.isArray(filterValue) && filterValue.length > 0) {
        chips.push({
          key: `filter-${column}`,
          label: `${getColumnDisplayLabel(column)}: ${filterValue.join(", ")}`,
          onRemove: () => handleClearMultiFilter(column),
        });
      } else if (typeof filterValue === "string" && filterValue.trim()) {
        chips.push({
          key: `filter-${column}`,
          label: `${getColumnDisplayLabel(column)}: ${filterValue.trim()}`,
          onRemove: () => handleColumnFilterChange(column, ""),
        });
      }
    });

    if (sortConfig.column && sortConfig.direction) {
      chips.push({
        key: "sort",
        label: `Tri: ${getColumnDisplayLabel(sortConfig.column)} (${sortConfig.direction === "asc" ? "croissant" : "decroissant"})`,
        onRemove: () =>
          setSortConfig({
            column: "",
            direction: "",
          }),
      });
    }

    if (pinnedColumns.length > 0) {
      chips.push({
        key: "pinned",
        label: `Colonnes gelees: ${pinnedColumns.map((column) => getColumnDisplayLabel(column)).join(", ")}`,
        onRemove: () => setPinnedColumns([]),
      });
    }

    return chips;
  }, [columnFilters, pinnedColumns, searchTerm, sortConfig]);

  const pinnedOffsets = useMemo(() => {
    const offsets = {};
    let currentLeft = 0;

    effectiveVisibleColumns.forEach((column) => {
      if (!pinnedColumns.includes(column)) {
        return;
      }

      offsets[column] = currentLeft;
      currentLeft += columnWidths[column] || getDefaultColumnWidth(column);
    });

    return offsets;
  }, [columnWidths, effectiveVisibleColumns, pinnedColumns]);

  function pushNotification(type, message) {
    const id = `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;

    setNotifications((current) => [...current, { id, type, message }]);
    window.setTimeout(() => {
      setNotifications((current) => current.filter((item) => item.id !== id));
    }, NOTIFICATION_TIMEOUT);
  }

  function dismissNotification(notificationId) {
    setNotifications((current) => current.filter((item) => item.id !== notificationId));
  }

  function toggleExpandedCell(cellKey) {
    setExpandedCells((current) => ({
      ...current,
      [cellKey]: !current[cellKey],
    }));
  }

  function buildServerFilters(sourceFilters = columnFilters) {
    return Object.entries(sourceFilters).reduce((accumulator, [column, value]) => {
      if (Array.isArray(value) && value.length > 0) {
        accumulator[column] = value;
      } else if (typeof value === "string" && value.trim()) {
        accumulator[column] = value.trim();
      }

      return accumulator;
    }, {});
  }

  function getSelectedRows() {
    if (!selectedCrudConfig) {
      return [];
    }

    return selectedRows;
  }

  function exportRowsToExcel(rowsToExport, fileLabel) {
    const exportColumns = effectiveVisibleColumns;
    const headerHtml = exportColumns.map((column) => `<th>${column}</th>`).join("");
    const rowsHtml = rowsToExport
      .map(
        (row) =>
          `<tr>${exportColumns
            .map((column) => `<td>${String(formatCellValue(row[column])).replace(/</g, "&lt;").replace(/>/g, "&gt;")}</td>`)
            .join("")}</tr>`
      )
      .join("");

    const html = `
      <html>
        <head><meta charset="utf-8" /></head>
        <body>
          <table border="1">
            <thead><tr>${headerHtml}</tr></thead>
            <tbody>${rowsHtml}</tbody>
          </table>
        </body>
      </html>
    `;

    const blob = new Blob([html], { type: "application/vnd.ms-excel;charset=utf-8;" });
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.href = url;
    link.download = `${fileLabel}.xls`;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(url);
  }

  function exportRowsToPdf(rowsToExport, fileLabel) {
    const exportColumns = effectiveVisibleColumns;
    const headerHtml = exportColumns.map((column) => `<th>${column}</th>`).join("");
    const rowsHtml = rowsToExport
      .map(
        (row) =>
          `<tr>${exportColumns
            .map((column) => `<td>${String(formatCellValue(row[column])).replace(/</g, "&lt;").replace(/>/g, "&gt;")}</td>`)
            .join("")}</tr>`
      )
      .join("");

    const printWindow = window.open("", "_blank", "noopener,noreferrer,width=1200,height=800");

    if (!printWindow) {
      pushNotification("error", "Impossible d'ouvrir la fenetre PDF.");
      return;
    }

    printWindow.document.write(`
      <html>
        <head>
          <meta charset="utf-8" />
          <title>${fileLabel}</title>
          <style>
            body { font-family: Arial, sans-serif; padding: 24px; }
            table { width: 100%; border-collapse: collapse; }
            th, td { border: 1px solid #cfd7e4; padding: 8px; text-align: left; vertical-align: top; }
            th { background: #eef4ff; }
          </style>
        </head>
        <body>
          <h1>${fileLabel}</h1>
          <table>
            <thead><tr>${headerHtml}</tr></thead>
            <tbody>${rowsHtml}</tbody>
          </table>
        </body>
      </html>
    `);
    printWindow.document.close();
    printWindow.focus();
    printWindow.print();
  }

  function getPageScrollContainer() {
    if (tableWrapRef.current?.closest) {
      const closestScrollable = tableWrapRef.current.closest(".mobile-content");

      if (closestScrollable) {
        return closestScrollable;
      }
    }

    if (typeof document !== "undefined") {
      return document.querySelector(".mobile-content");
    }

    return null;
  }

  function capturePaginationViewport() {
    if (typeof window === "undefined") {
      return;
    }

    const pageScrollContainer = getPageScrollContainer();

    const footerRect = tableFooterRef.current?.getBoundingClientRect?.() || null;
    const pageContainerRect = pageScrollContainer?.getBoundingClientRect?.() || null;

    paginationViewportRef.current = {
      pageScrollTop: pageScrollContainer?.scrollTop ?? null,
      pageScrollLeft: pageScrollContainer?.scrollLeft ?? null,
      footerOffsetTop:
        footerRect && pageContainerRect ? footerRect.top - pageContainerRect.top : footerRect?.top ?? null,
      pageScrollY:
        window.scrollY ??
        window.pageYOffset ??
        document.documentElement?.scrollTop ??
        document.body?.scrollTop ??
        0,
      tableScrollTop: tableWrapRef.current?.scrollTop ?? 0,
      tableScrollLeft: tableWrapRef.current?.scrollLeft ?? 0,
    };
  }

  function handlePageNavigation(nextPage) {
    if (nextPage === currentPage) {
      return;
    }

    capturePaginationViewport();
    setCurrentPage(nextPage);
  }

  function handleRowsPerPageChange(nextRowsPerPage) {
    if (nextRowsPerPage === rowsPerPage) {
      return;
    }

    capturePaginationViewport();
    setRowsPerPage(nextRowsPerPage);
  }

  useEffect(() => {
    async function handleMouseMove(event) {
      if (!resizingRef.current) {
        return;
      }

      const { column, startX, startWidth } = resizingRef.current;
      const width = Math.max(MIN_COLUMN_WIDTH, startWidth + (event.clientX - startX));

      setColumnWidths((current) => ({
        ...current,
        [column]: width,
      }));
    }

    function handleMouseUp() {
      if (resizingRef.current) {
        resizingRef.current = null;
      }
    }

    window.addEventListener("mousemove", handleMouseMove);
    window.addEventListener("mouseup", handleMouseUp);

    return () => {
      window.removeEventListener("mousemove", handleMouseMove);
      window.removeEventListener("mouseup", handleMouseUp);
    };
  }, []);

  useEffect(() => {
    const tableElement = tableWrapRef.current;

    if (!tableElement) {
      return undefined;
    }

    function updateHorizontalScrollState() {
      const overflow = tableElement.scrollWidth - tableElement.clientWidth > 2;
      const maxScrollLeft = Math.max(0, tableElement.scrollWidth - tableElement.clientWidth);
      const canScrollLeft = tableElement.scrollLeft > 2;
      const canScrollRight = tableElement.scrollLeft < maxScrollLeft - 2;

      setHorizontalScrollState({
        overflow,
        canScrollLeft,
        canScrollRight,
      });
    }

    const resizeObserver =
      typeof ResizeObserver !== "undefined"
        ? new ResizeObserver(() => {
            updateHorizontalScrollState();
          })
        : null;

    updateHorizontalScrollState();

    tableElement.addEventListener("scroll", updateHorizontalScrollState);
    resizeObserver?.observe(tableElement);
    window.addEventListener("resize", updateHorizontalScrollState);

    return () => {
      tableElement.removeEventListener("scroll", updateHorizontalScrollState);
      resizeObserver?.disconnect();
      window.removeEventListener("resize", updateHorizontalScrollState);
    };
  }, [rows, effectiveVisibleColumns, columnWidths, selectedViewKey, loadingData]);

  useEffect(() => {
    if (loadingData || !paginationViewportRef.current) {
      return;
    }

    const snapshot = paginationViewportRef.current;
    paginationViewportRef.current = null;

    const restoreScroll = () => {
      const pageScrollContainer = getPageScrollContainer();

      if (pageScrollContainer && snapshot.pageScrollTop != null) {
        pageScrollContainer.scrollTop = snapshot.pageScrollTop;
        pageScrollContainer.scrollLeft = snapshot.pageScrollLeft ?? 0;
      }

      if (typeof window !== "undefined") {
        window.scrollTo({
          top: snapshot.pageScrollY,
          left: 0,
          behavior: "auto",
        });
      }

      if (tableWrapRef.current) {
        tableWrapRef.current.scrollTop = snapshot.tableScrollTop;
        tableWrapRef.current.scrollLeft = snapshot.tableScrollLeft;
      }

      if (pageScrollContainer && snapshot.footerOffsetTop != null && tableFooterRef.current) {
        const currentFooterRect = tableFooterRef.current.getBoundingClientRect();
        const currentContainerRect = pageScrollContainer.getBoundingClientRect();
        const currentFooterOffsetTop = currentFooterRect.top - currentContainerRect.top;
        const delta = currentFooterOffsetTop - snapshot.footerOffsetTop;

        if (Math.abs(delta) > 1) {
          pageScrollContainer.scrollTop += delta;
        }
      }
    };

    const animationFrameId = window.requestAnimationFrame(() => {
      restoreScroll();
      window.requestAnimationFrame(() => {
        restoreScroll();
      });
    });

    return () => {
      window.cancelAnimationFrame(animationFrameId);
    };
  }, [loadingData, currentPage, rowsPerPage, rows.length]);

  async function loadViewRows(view, overrides = {}) {
    const requestId = ++viewRequest.current;
    const silent = overrides.silent === true;
    if (!view) {
      setRows([]);
      setViewMeta((current) => ({
        ...current,
        columns: [],
        totalCount: 0,
        filteredCount: 0,
      }));
      setLoadingData(false);
      return;
    }

    if (view.renderMode === "dashboard" || view.renderMode === "empty") {
      setRows([]);
      setViewMeta((current) => ({
        ...current,
        columns: [],
        totalCount: 0,
        filteredCount: 0,
      }));
      setLoadingData(false);
      return;
    }

    if (!silent) setLoadingData(true);
    setErrorMessage("");

    const effectiveSortColumn =
      overrides.sortConfig?.column !== undefined ? overrides.sortConfig.column : sortConfig.column;
    const effectiveSortDirection =
      overrides.sortConfig?.direction !== undefined ? overrides.sortConfig.direction : sortConfig.direction;
    const effectiveSearchTerm = overrides.searchTerm !== undefined ? overrides.searchTerm : searchTerm;
    const effectiveFilters = overrides.columnFilters !== undefined ? overrides.columnFilters : columnFilters;
    const effectiveRowsPerPage = overrides.rowsPerPage || rowsPerPage;
    const effectiveCurrentPage = overrides.currentPage || currentPage;

    const targetView = view.dataView || view;
    const serverFilters = {
      ...(view.defaultFilters || {}),
      ...buildServerFilters(effectiveFilters),
    };

    const payload = await fetchViewData(targetView.schema, targetView.name, {
      take: effectiveRowsPerPage,
      skip: (effectiveCurrentPage - 1) * effectiveRowsPerPage,
      q: effectiveSearchTerm.trim() || undefined,
      sortBy: effectiveSortColumn || undefined,
      sortDir: effectiveSortDirection || undefined,
      filters: JSON.stringify(serverFilters),
    });

    if (requestId !== viewRequest.current) return;
    if (payload?.success && Array.isArray(payload.data)) {
      setRows(payload.data);
      setViewMeta({
        columns: Array.isArray(payload.meta?.columns) ? payload.meta.columns : [],
        totalCount: Number(payload.meta?.totalCount || payload.data.length || 0),
        filteredCount: Number(payload.meta?.filteredCount || payload.data.length || 0),
        take: Number(payload.meta?.take || effectiveRowsPerPage),
        skip: Number(payload.meta?.skip || 0),
        sortBy: payload.meta?.sortBy || effectiveSortColumn || "",
        sortDir: payload.meta?.sortDir || effectiveSortDirection || "asc",
      });
    } else {
      if (!silent) {
        setRows([]);
        setViewMeta((current) => ({ ...current, columns: [], totalCount: 0, filteredCount: 0 }));
      }
      setErrorMessage(payload?.message || "Impossible de charger les donnees de la vue selectionnee.");
    }

    if (!silent) setLoadingData(false);
  }

  useEffect(() => {
    let active = true;

    async function loadViews() {
      const payload = await fetchAvailableViews();

      if (!active) {
        return;
      }

      if (payload?.success && Array.isArray(payload.data)) {
        setAvailableViews(payload.data);
      } else {
        setErrorMessage(payload?.message || "Impossible de charger la liste des vues d'administration.");
      }

      setLoadingViews(false);
    }

    loadViews();

    return () => {
      active = false;
    };
  }, []);

  useEffect(() => {
    let active = true;

    async function loadSupportData() {
      setLoadingSupport(true);
      setSupportError("");

      if (schemaOnly === "referentiel") {
        const payload = await fetchCompleteReferenceRows("T_CategorieGenerique");
        if (!active) return;
        setSupportData(current => ({...current,categories:extractPayloadRows(payload)}));
        if (!payload?.success) setSupportError("La liste des catégories n’a pas pu être chargée.");
        setLoadingSupport(false);
        return;
      }

      const [
        entitiesPayload,
        categoriesPayload,
        genericViewsPayload,
        genericTablePayload,
        licencesPayload,
        niveaux0Payload,
        niveaux1OldPayload,
        niveaux1Payload,
        niveaux2Payload,
        niveaux3Payload,
        niveaux4Payload,
        niveaux5Payload,
        niveaux0ViewPayload,
        niveaux1OldViewPayload,
        niveaux1ViewPayload,
        niveaux2ViewPayload,
        niveaux3ViewPayload,
        niveaux4ViewPayload,
        niveaux5ViewPayload,
        fieldReferencesPayload,
      ] = await Promise.all([
        fetchAdminEntities({ take: 100 }),
        fetchCompleteReferenceRows("T_CategorieGenerique"),
        fetchViewData("referentiel", "V_Generique", { take: 500 }),
        fetchCompleteReferenceRows("T_Generique"),
        fetchAdminLicences({ take: 50 }),
        fetchAdminModelList("T_Niveau_0", { take: 1000 }),
        fetchAdminModelList("T_Niveau_1_Old", { take: 1000 }),
        fetchAdminModelList("T_Niveau_1", { take: 2000 }),
        fetchAdminModelList("T_Niveau_2", { take: 3000 }),
        fetchAdminModelList("T_Niveau_3", { take: 4000 }),
        fetchAdminModelList("T_Niveau_4", { take: 6000 }),
        fetchAdminModelList("T_Niveau_5", { take: 8000 }),
        fetchViewData("geolocalisation", "V_Niveau_0", { take: 1000 }),
        fetchViewData("geolocalisation", "V_Niveau_1_Old", { take: 1000 }),
        fetchViewData("geolocalisation", "V_Niveau_1", { take: 2000 }),
        fetchViewData("geolocalisation", "V_Niveau_2", { take: 3000 }),
        fetchViewData("geolocalisation", "V_Niveau_3", { take: 4000 }),
        fetchViewData("geolocalisation", "V_Niveau_4", { take: 6000 }),
        fetchViewData("geolocalisation", "V_Niveau_5", { take: 8000 }),
        fetchTerritorialReferences(),
      ]);

      if (!active) {
        return;
      }

      const categories = extractPayloadRows(categoriesPayload);
      const genericViewRows = normalizeGenericRows(extractPayloadRows(genericViewsPayload), categories);
      const genericTableRows = normalizeGenericRows(extractPayloadRows(genericTablePayload), categories);
      const generics = genericTablePayload?.success ? genericTableRows : genericViewRows;
      const roles = buildGenericSupportList("roles", generics, genericCategoryOverrides);
      const entityTypes = buildGenericSupportList("entityTypes", generics, genericCategoryOverrides);
      const licenseStatuses = buildGenericSupportList("licenseStatuses", generics, genericCategoryOverrides);
      const niveau2Types = buildGenericSupportList("niveau2Types", generics, genericCategoryOverrides);
      const niveau3Types = buildGenericSupportList("niveau3Types", generics, genericCategoryOverrides);
      const niveau2Statuses = buildGenericSupportList("niveau2Statuses", generics, genericCategoryOverrides);
      const niveau3Statuses = buildGenericSupportList("niveau3Statuses", generics, genericCategoryOverrides);
      const deploymentStatuses = buildGenericSupportList("deploymentStatuses", generics, genericCategoryOverrides);
      const dpsAccessRoutes = buildGenericSupportList("dpsAccessRoutes", generics, genericCategoryOverrides);
      const antBczAccessRoutes = buildGenericSupportList("antBczAccessRoutes", generics, genericCategoryOverrides);
      const dpsBczAccessRoutes = buildGenericSupportList("dpsBczAccessRoutes", generics, genericCategoryOverrides);
      const niveau4Types = buildGenericSupportList("niveau4Types", generics, genericCategoryOverrides);
      const niveau5Types = buildGenericSupportList("niveau5Types", generics, genericCategoryOverrides);
      const niveau4Statuses = buildGenericSupportList("niveau4Statuses", generics, genericCategoryOverrides);
      const niveau5Statuses = buildGenericSupportList("niveau5Statuses", generics, genericCategoryOverrides);
      const networkAvailabilities = buildGenericSupportList("networkAvailabilities", generics, genericCategoryOverrides);
      const zsAsAccessRoutes = buildGenericSupportList("zsAsAccessRoutes", generics, genericCategoryOverrides);
      const zsSiteAccessRoutes = buildGenericSupportList("zsSiteAccessRoutes", generics, genericCategoryOverrides);
      const roofTypes = buildGenericSupportList("roofTypes", generics, genericCategoryOverrides);
      const niveaux0 = preferSupportRows(extractPayloadRows(niveaux0ViewPayload), extractPayloadRows(niveaux0Payload));
      const niveaux1Old = preferSupportRows(
        extractPayloadRows(niveaux1OldViewPayload),
        extractPayloadRows(niveaux1OldPayload)
      );
      const niveaux1 = preferSupportRows(extractPayloadRows(niveaux1ViewPayload), extractPayloadRows(niveaux1Payload));
      const niveaux2 = preferSupportRows(extractPayloadRows(niveaux2ViewPayload), extractPayloadRows(niveaux2Payload));
      const niveaux3 = preferSupportRows(extractPayloadRows(niveaux3ViewPayload), extractPayloadRows(niveaux3Payload));
      const niveaux4 = preferSupportRows(extractPayloadRows(niveaux4ViewPayload), extractPayloadRows(niveaux4Payload));
      const niveaux5 = preferSupportRows(extractPayloadRows(niveaux5ViewPayload), extractPayloadRows(niveaux5Payload));

      setSupportData({
        referenceByField:fieldReferencesPayload.byField || {},
        entities: entitiesPayload?.success && Array.isArray(entitiesPayload.data) ? entitiesPayload.data : [],
        categories,
        roles: roles.length > 0 ? roles : filterGenericsByCategory(generics, /^r[ôo]le$/u),
        entityTypes:
          entityTypes.length > 0
            ? entityTypes
            : filterGenericsByCategory(generics, /type[\s_-]*(?:(?:d['’]|de)[\s_-]*)?entit[ée]/u),
        licenseStatuses:
          licenseStatuses.length > 0
            ? licenseStatuses
            : filterGenericsByCategory(generics, /statut[\s_-]*(?:de[\s_-]+(?:la[\s_-]+)?)?licence/u),
        niveaux0,
        niveaux1Old,
        niveaux1,
        niveaux2,
        niveaux3,
        niveaux4,
        niveaux5,
        niveau2Types,
        niveau3Types,
        niveau2Statuses,
        niveau3Statuses,
        deploymentStatuses,
        dpsAccessRoutes,
        antBczAccessRoutes,
        dpsBczAccessRoutes,
        niveau4Types,
        niveau5Types,
        niveau4Statuses,
        niveau5Statuses,
        networkAvailabilities:
          networkAvailabilities.length > 0
            ? networkAvailabilities
            : filterGenericsByCategory(generics, /r[ée]seau/u),
        zsAsAccessRoutes,
        zsSiteAccessRoutes,
        roofTypes,
      });

      if (
        !fieldReferencesPayload?.success ||
        !entitiesPayload?.success ||
        !categoriesPayload?.success ||
        (!genericViewsPayload?.success && !genericTablePayload?.success) ||
        !licencesPayload?.success ||
        !niveaux0Payload?.success ||
        !niveaux1OldPayload?.success ||
        !niveaux1Payload?.success ||
        !niveaux2Payload?.success ||
        !niveaux3Payload?.success ||
        !niveaux4Payload?.success ||
        !niveaux5Payload?.success
      ) {
        setSupportError("Certaines listes de support n'ont pas pu etre chargees. Le CRUD reste disponible.");
      }

      setLoadingSupport(false);
    }

    loadSupportData();

    return () => {
      active = false;
    };
  }, [genericCategoryOverrides,schemaOnly,entityReferenceScope.scopeKey]);

  useEffect(() => {
    if (!referenceVersion || loadingSupport) return;
    let active = true;
    async function refreshReferenceOptions() {
      const [categoriesPayload, genericsPayload,fieldReferencesPayload] = await Promise.all([
        fetchCompleteReferenceRows("T_CategorieGenerique"),
        fetchCompleteReferenceRows("T_Generique"),
        fetchTerritorialReferences(),
      ]);
      if (!active) return;
      if (!categoriesPayload?.success || !genericsPayload?.success || !fieldReferencesPayload?.success) {
        setSupportError("Les références n’ont pas pu être actualisées. Les listes précédentes restent disponibles.");
        return;
      }
      const categories = extractPayloadRows(categoriesPayload);
      const generics = normalizeGenericRows(extractPayloadRows(genericsPayload), categories);
      setSupportData(current => ({ ...current, categories,referenceByField:fieldReferencesPayload.byField || {},
        ...Object.fromEntries(Object.keys(GENERIC_OPTION_SOURCE_CONFIG).map(key => [key, buildGenericSupportList(key, generics, genericCategoryOverrides)])),
      }));
      setSupportError("");
    }
    void refreshReferenceOptions();
    return () => { active = false; };
  }, [referenceVersion, genericCategoryOverrides, loadingSupport]);

  useEffect(() => {
    if (!referenceVersion || loadingData || submittingEditor || selectedView?.schema !== "referentiel") return;
    void loadViewRows(selectedView, { silent: true });
  }, [referenceVersion, selectedView, loadingData, submittingEditor]);

  useEffect(() => {
    if (adminViews.length === 0) {
      return;
    }

    const selectedExists = adminViews.some((view) => normalizeViewKey(view.schema, view.name) === selectedViewKey);

    if (!selectedExists) {
      const fallbackView =
        adminViews.find((view) => Boolean(CRUD_CONFIGS[normalizeViewKey(view.schema, view.name)])) || adminViews[0];

      if (fallbackView) {
        setSelectedViewKey(normalizeViewKey(fallbackView.schema, fallbackView.name));
      }
    }
  }, [adminViews, selectedViewKey]);

  useEffect(() => {
    let active = true;

    async function refreshSelectedView() {
      await loadViewRows(selectedView);

      if (!active) {
        return;
      }
    }

    refreshSelectedView();

    return () => {
      active = false;
    };
  }, [selectedView, searchTerm, columnFilters, sortConfig, rowsPerPage, currentPage]);

  useEffect(() => {
    let active = true;

    async function loadDashboardData() {
      if (selectedView?.renderMode !== "dashboard") {
        return;
      }

      setLoadingDashboard(true);
      setDashboardError("");

      const [
        usersPayload,
        entitiesPayload,
        licencesPayload,
        loginPayload,
        auditPayload,
        fkPayload,
        settingsPayload,
      ] = await Promise.all([
        fetchViewData("systeme", "V_User_profil", { take: 1000 }),
        fetchAdminEntities({ take: 1000 }),
        fetchViewData("systeme", "V_Licence_active", { take: 1000 }),
        fetchViewData("systeme", "V_Login_history", { take: 300 }),
        fetchViewData("systeme", "V_Audit_log", { take: 300 }),
        fetchViewData("systeme", "V_Fk_Correspondance", { take: 300 }),
        fetchViewData("systeme", "V_Admin_UI_Setting", { take: 300 }),
      ]);

      if (!active) {
        return;
      }

      const users = Array.isArray(usersPayload?.data) ? usersPayload.data : [];
      const entities = Array.isArray(entitiesPayload?.data) ? entitiesPayload.data : [];
      const licences = Array.isArray(licencesPayload?.data) ? licencesPayload.data : [];
      const logins = Array.isArray(loginPayload?.data) ? loginPayload.data : [];
      const auditRows = Array.isArray(auditPayload?.data) ? auditPayload.data : [];
      const fkRows = Array.isArray(fkPayload?.data) ? fkPayload.data : [];
      const settingsRows = Array.isArray(settingsPayload?.data) ? settingsPayload.data : [];

      const todayKey = new Date().toISOString().slice(0, 10);
      const activeUsers = users.filter((row) => row.ValideUser !== false).length;
      const adminUsers = users.filter((row) => Boolean(row.Is_Admin)).length;
      const activeLicences = licences.filter((row) => sameCategory(row.statut_licence, "active")).length;
      const expiredLicences = licences.filter((row) => /expir/i.test(String(row.statut_licence || ""))).length;
      const todayLogins = logins.filter((row) => String(row.DateLogin || "").slice(0, 10) === todayKey).length;
      const activeMappings = fkRows.filter((row) => row.HasActiveMapping !== false).length;

      setDashboardData({
        metrics: [
          { title: "Utilisateurs", value: users.length, detail: `${activeUsers} actifs`, tone: "primary", icon: "bi-people" },
          { title: "Entites", value: entities.length, detail: "Structures rattachees", tone: "info", icon: "bi-building" },
          { title: "Licences actives", value: activeLicences, detail: `${expiredLicences} expirees`, tone: "success", icon: "bi-shield-check" },
          { title: "Licences expirees", value: expiredLicences, detail: "A surveiller", tone: "danger", icon: "bi-shield-x" },
          { title: "Connexions du jour", value: todayLogins, detail: "Historique recent", tone: "primary", icon: "bi-person-check" },
          { title: "Journaux d'audit", value: Number(auditPayload?.meta?.totalCount || auditRows.length), detail: "Activites tracees", tone: "info", icon: "bi-journal-text" },
          { title: "Correspondances FK", value: activeMappings, detail: "Mappings actifs", tone: "primary", icon: "bi-link-45deg" },
          { title: "Parametres modifies", value: settingsRows.length, detail: `${adminUsers} administrateurs`, tone: "soft", icon: "bi-sliders" },
        ],
        recentAudit: auditRows.slice(0, 6),
        recentLogins: logins.slice(0, 6),
        recentLicences: licences
          .slice()
          .sort((leftItem, rightItem) => String(leftItem.DateFin || "").localeCompare(String(rightItem.DateFin || "")))
          .slice(0, 6),
        recentMappings: fkRows.slice(0, 6),
        recentSettings: settingsRows.slice(0, 6),
      });
      setLoadingDashboard(false);
    }

    loadDashboardData().catch((error) => {
      if (!active) {
        return;
      }

      console.warn("Impossible de charger le dashboard administration", error);
      setDashboardError("Impossible de charger le tableau de bord Administration.");
      setLoadingDashboard(false);
    });

    return () => {
      active = false;
    };
  }, [selectedView]);

  useEffect(() => {
    const storedState = loadStoredAdminViewState(selectedViewKey);

    setEditorMode(null);
    setEditorRecordId(null);
    setEditorValues({});
    setLoadingEditor(false);
    setSubmittingEditor(false);
    setActionFeedback(null);
    setSearchTerm(storedState?.searchTerm || "");
    setColumnFilters(storedState?.columnFilters || {});
    setFilterSearchTerms(storedState?.filterSearchTerms || {});
    setOpenFilterColumn("");
    setShowSearchPanel(Boolean(storedState?.showSearchPanel));
    setSortConfig(
      storedState?.sortConfig || {
        column: "",
        direction: "",
      }
    );
    setVisibleColumns(storedState?.visibleColumns || []);
    setPinnedColumns(storedState?.pinnedColumns || []);
    setRowsPerPage(Number(storedState?.rowsPerPage || DEFAULT_ROWS_PER_PAGE));
    setSelectedRowIds([]);
    setCurrentPage(1);
    setShowExportMenu(false);
    setShowNavigationMenu(false);
  }, [selectedViewKey]);

  useEffect(() => {
    function handleDocumentPointerDown(event) {
      if (!exportMenuRef.current?.contains(event.target)) {
        setShowExportMenu(false);
      }

      if (!navigationMenuRef.current?.contains(event.target)) {
        setShowNavigationMenu(false);
      }
    }

    document.addEventListener("mousedown", handleDocumentPointerDown);

    return () => {
      document.removeEventListener("mousedown", handleDocumentPointerDown);
    };
  }, []);

  useEffect(() => {
    setVisibleColumns((current) => {
      if (columns.length === 0) {
        return [];
      }

      if (!Array.isArray(current) || current.length === 0) {
        const preferredColumns = Array.isArray(selectedView?.preferredColumns)
          ? selectedView.preferredColumns.filter((column) => columns.includes(column))
          : [];
        return preferredColumns.length > 0 ? preferredColumns : columns;
      }

      const nextVisibleColumns = current.filter((column) => columns.includes(column));
      const missingColumns = columns.filter((column) => !nextVisibleColumns.includes(column));
      return [...nextVisibleColumns, ...missingColumns];
    });

    setColumnWidths((current) => {
      const next = {};
      columns.forEach((column) => {
        next[column] = current[column] || getDefaultColumnWidth(column);
      });
      return next;
    });

    setPinnedColumns((current) => {
      const nextPinned = current.filter((column) => columns.includes(column));

      if (nextPinned.length > 0) {
        return nextPinned;
      }

      return columns[0] ? [columns[0]] : [];
    });
  }, [columns, selectedView]);

  useEffect(() => {
    setCurrentPage(1);
  }, [searchTerm, columnFilters, sortConfig, rowsPerPage, selectedViewKey]);

  useEffect(() => {
    if (currentPage > totalPages) {
      setCurrentPage(totalPages);
    }
  }, [currentPage, totalPages]);

  useEffect(() => {
    saveStoredAdminViewState(selectedViewKey, {
      searchTerm,
      columnFilters,
      filterSearchTerms,
      sortConfig,
      visibleColumns,
      pinnedColumns,
      rowsPerPage,
      showSearchPanel,
    });
  }, [
    columnFilters,
    filterSearchTerms,
    pinnedColumns,
    rowsPerPage,
    searchTerm,
    selectedViewKey,
    showSearchPanel,
    sortConfig,
    visibleColumns,
  ]);

  useEffect(() => {
    if (!selectedCrudConfig) {
      setSelectedRowIds([]);
      return;
    }

    const rowIds = new Set(
      rows.map((row) => resolveRowRecordId(row, selectedCrudConfig)).filter((recordId) => Boolean(recordId))
    );
    setSelectedRowIds((current) => current.filter((item) => rowIds.has(item)));
  }, [rows, selectedCrudConfig]);

  useEffect(() => {
    setCollapsedSchemas((current) => {
      const nextState = {};

      schemaGroups.forEach((group) => {
        nextState[group.schema] = current[group.schema] ?? (group.schema !== schemaOnly);
      });

      return nextState;
    });
  }, [schemaGroups]);

  function getColumnWidth(column) {
    return columnWidths[column] || getDefaultColumnWidth(column);
  }

  function getCellStyle(column, isHeader = false) {
    const isPinned = pinnedColumns.includes(column);
    const width = getColumnWidth(column);

    return {
      width,
      minWidth: width,
      ...(isPinned
        ? {
            left: pinnedOffsets[column] || 0,
            zIndex: isHeader ? 6 : 3,
          }
        : null),
    };
  }

  function handleEditorValueChange(fieldName, nextValue) {
    setEditorValues((current) => ({
      ...current,
      [fieldName]: nextValue,
    }));
  }

  async function persistSharedFkSettings(nextGenericOverrides, nextHierarchyModes, successMessage) {
    const targetScope = sharedFkTargetScope || createAdminUiScope("global", null, "Global");

    setSavingSharedFkSettings(true);
    setSharedFkSettingsError("");

    const response = await saveAdminUiSettings({
      scope: targetScope.scope,
      scopeValue: targetScope.scopeValue,
      genericCategoryOverrides: nextGenericOverrides,
      hierarchyFilterModes: nextHierarchyModes,
    });

    setSavingSharedFkSettings(false);

    if (!response?.success || !response.data) {
      setSharedFkSettingsError(response?.message || "Impossible d'enregistrer les reglages partages.");
      pushNotification("error", response?.message || "Impossible d'enregistrer les reglages partages.");
      return false;
    }

    const normalizedGenericOverrides = normalizeStringRecord(response.data.genericCategoryOverrides);
    const normalizedHierarchyModes = normalizeHierarchyModes(response.data.hierarchyFilterModes);

    setGenericCategoryOverrides(normalizedGenericOverrides);
    setHierarchyFilterModes(normalizedHierarchyModes);
    setSharedFkLoadedScope(targetScope);
    setSharedFkSettingsError("");
    setSharedFkSettingsMeta({
      updatedAt: response.data.updatedAt || null,
      updatedByUserId: response.data.updatedByUserId ?? null,
      updatedByName: response.data.updatedByName || null,
    });

    if (successMessage) {
      pushNotification("success", successMessage);
    }

    return true;
  }

  function handleGenericCategoryDraftChange(source, nextValue) {
    setGenericCategoryDrafts((current) => ({
      ...current,
      [source]: nextValue,
    }));
  }

  async function handleHierarchyFilterModeChange(source, nextMode) {
    const config = HIERARCHY_OPTION_SOURCE_CONFIG[source];

    if (!config) {
      return;
    }

    const nextModes = { ...hierarchyFilterModes };

    if (nextMode === config.defaultMode) {
      delete nextModes[source];
    } else {
      nextModes[source] = nextMode;
    }

    await persistSharedFkSettings(
      genericCategoryOverrides,
      nextModes,
      nextMode === "all"
        ? `Liste complete activee pour ${config.label}.`
        : `Filtrage par parent reactive pour ${config.label}.`
    );
  }

  async function handleApplyGenericCategoryOverride(source) {
    const config = GENERIC_OPTION_SOURCE_CONFIG[source];

    if (!config) {
      return;
    }

    const draftValue =
      genericCategoryDrafts[source] ?? genericCategoryOverrides[source] ?? serializeCategoryIds(config.defaultCategoryIds);
    const parsedCategoryIds = parseCategoryOverrideInput(draftValue);

    if (!parsedCategoryIds || parsedCategoryIds.length === 0) {
      pushNotification("error", "Saisissez un ou plusieurs IDs de categorie valides, separes par des virgules.");
      return;
    }

    const serializedValue = serializeCategoryIds(parsedCategoryIds);
    const defaultValue = serializeCategoryIds(config.defaultCategoryIds);

    setGenericCategoryDrafts((current) => ({
      ...current,
      [source]: serializedValue,
    }));

    const nextOverrides = { ...genericCategoryOverrides };

    if (serializedValue === defaultValue) {
      delete nextOverrides[source];
    } else {
      nextOverrides[source] = serializedValue;
    }

    await persistSharedFkSettings(nextOverrides, hierarchyFilterModes, `Correspondance mise a jour pour ${config.label}.`);
  }

  async function handleResetGenericCategoryOverride(source) {
    const config = GENERIC_OPTION_SOURCE_CONFIG[source];

    if (!config) {
      return;
    }

    setGenericCategoryDrafts((current) => ({
      ...current,
      [source]: serializeCategoryIds(config.defaultCategoryIds),
    }));

    const nextOverrides = { ...genericCategoryOverrides };
    delete nextOverrides[source];

    await persistSharedFkSettings(nextOverrides, hierarchyFilterModes, `Correspondance reinitialisee pour ${config.label}.`);
  }

  async function handleApplyAllGenericCategoryOverrides() {
    if (genericMappingStates.some((item) => !item.isValid)) {
      pushNotification("error", "Certaines categories sont invalides. Corrigez la saisie avant d'appliquer.");
      return;
    }

    const nextOverrides = {};
    const nextDrafts = {};

    genericMappingStates.forEach((item) => {
      const serializedValue = serializeCategoryIds(item.parsedInput);
      nextDrafts[item.source] = serializedValue;

      if (serializedValue !== item.defaultValue) {
        nextOverrides[item.source] = serializedValue;
      }
    });

    setGenericCategoryDrafts((current) => ({
      ...current,
      ...nextDrafts,
    }));

    await persistSharedFkSettings(nextOverrides, hierarchyFilterModes, "Toutes les correspondances de categories ont ete appliquees.");
  }

  async function handleResetAllFkSettings() {
    const nextDrafts = {};

    genericMappingStates.forEach((item) => {
      nextDrafts[item.source] = item.defaultValue;
    });

    setGenericCategoryDrafts((current) => ({
      ...current,
      ...nextDrafts,
    }));

    await persistSharedFkSettings({}, {}, "Tous les reglages du panneau ont ete reinitialises.");
  }

  function handleColumnFilterChange(column, value) {
    setColumnFilters((current) => ({
      ...current,
      [column]: value,
    }));
  }

  function handleToggleMultiFilterValue(column, value) {
    setColumnFilters((current) => {
      const currentValues = Array.isArray(current[column]) ? current[column] : [];
      const nextValues = currentValues.includes(value)
        ? currentValues.filter((item) => item !== value)
        : [...currentValues, value];

      return {
        ...current,
        [column]: nextValues,
      };
    });
  }

  function handleSelectAllMultiFilter(column, values) {
    setColumnFilters((current) => ({
      ...current,
      [column]: values,
    }));
  }

  function handleClearMultiFilter(column) {
    setColumnFilters((current) => ({
      ...current,
      [column]: [],
    }));
  }

  function handleToggleVisibleColumn(column) {
    setVisibleColumns((current) => {
      const baselineColumns = current.length > 0 ? current : columns;

      if (baselineColumns.includes(column)) {
        const nextColumns = baselineColumns.filter((item) => item !== column);
        return nextColumns.length > 0 ? nextColumns : current;
      }

      return [...baselineColumns, column];
    });
  }

  function handleShowAllColumns() {
    setVisibleColumns(columns);
  }

  function handleResetColumns() {
    setVisibleColumns(columns);
    setPinnedColumns(columns[0] ? [columns[0]] : []);
    setColumnWidths(columns.reduce((accumulator, column) => {
      accumulator[column] = getDefaultColumnWidth(column);
      return accumulator;
    }, {}));
  }

  function handleSortColumn(column) {
    setSortConfig((current) => {
      if (current.column !== column) {
        return {
          column,
          direction: "asc",
        };
      }

      if (current.direction === "asc") {
        return {
          column,
          direction: "desc",
        };
      }

      if (current.direction === "desc") {
        return {
          column: "",
          direction: "",
        };
      }

      return {
        column,
        direction: "asc",
      };
    });
  }

  function handleToggleSchema(schema) {
    setCollapsedSchemas((current) => ({
      ...current,
      [schema]: !current[schema],
    }));
  }

  function handleTogglePinnedColumn(column) {
    setPinnedColumns((current) => {
      if (current.includes(column)) {
        return current.filter((item) => item !== column);
      }

      return [...current, column].sort(
        (leftValue, rightValue) => effectiveVisibleColumns.indexOf(leftValue) - effectiveVisibleColumns.indexOf(rightValue)
      );
    });
  }

  function handleResetColumnWidth(column) {
    setColumnWidths((current) => ({
      ...current,
      [column]: getDefaultColumnWidth(column),
    }));
  }

  function handleResizeStart(column, event) {
    event.preventDefault();
    event.stopPropagation();

    resizingRef.current = {
      column,
      startX: event.clientX,
      startWidth: getColumnWidth(column),
    };
  }

  function handleResetFilters() {
    setSearchTerm("");
    setColumnFilters({});
    setFilterSearchTerms({});
    setOpenFilterColumn("");
    setSortConfig({
      column: "",
      direction: "",
    });
    setCurrentPage(1);
  }

  function scrollTableHorizontally(mode) {
    const tableElement = tableWrapRef.current;

    if (!tableElement) {
      return;
    }

    const maxScrollLeft = Math.max(0, tableElement.scrollWidth - tableElement.clientWidth);
    const pageStep = Math.max(240, Math.round(tableElement.clientWidth * 0.75));

    if (mode === "start") {
      tableElement.scrollTo({ left: 0, behavior: "smooth" });
      return;
    }

    if (mode === "end") {
      tableElement.scrollTo({ left: maxScrollLeft, behavior: "smooth" });
      return;
    }

    const delta = mode === "left" ? -pageStep : pageStep;
    tableElement.scrollBy({ left: delta, behavior: "smooth" });
  }

  function handleNavigationAction(mode) {
    scrollTableHorizontally(mode);
    setShowNavigationMenu(false);
  }

  function handleTableWrapKeyDown(event) {
    if (event.key === "ArrowLeft") {
      event.preventDefault();
      scrollTableHorizontally("left");
      return;
    }

    if (event.key === "ArrowRight") {
      event.preventDefault();
      scrollTableHorizontally("right");
    }
  }

  function handleToggleRowSelection(row) {
    if (!selectedCrudConfig) {
      return;
    }

    const recordId = resolveRowRecordId(row, selectedCrudConfig);

    if (!recordId) {
      setActionFeedback({
        type: "error",
        message: `La cle primaire ${selectedCrudConfig.primaryKey} est absente de cette vue.`,
      });
      return;
    }

    setSelectedRowIds((current) =>
      current.includes(recordId) ? current.filter((item) => item !== recordId) : [...current, recordId]
    );
  }

  function handleTogglePageSelection() {
    if (!selectedCrudConfig) {
      return;
    }

    const pageIds = rows
      .map((row) => resolveRowRecordId(row, selectedCrudConfig))
      .filter((recordId) => Boolean(recordId));
    const everySelected = pageIds.length > 0 && pageIds.every((id) => selectedRowIds.includes(id));

    setSelectedRowIds((current) =>
      everySelected ? current.filter((id) => !pageIds.includes(id)) : Array.from(new Set([...current, ...pageIds]))
    );
  }

  function handleActivateRow(row, event) {
    if (!selectedCrudConfig) {
      return;
    }

    const interactiveTarget = event.target.closest("button, input, a, select, textarea, label");

    if (interactiveTarget) {
      return;
    }

    const recordId = resolveRowRecordId(row, selectedCrudConfig);

    if (!recordId) {
      return;
    }

    setSelectedRowIds((current) => (current.length === 1 && current[0] === recordId ? [] : [recordId]));
  }

  function handleExportCsv() {
    const rowsToExport = selectedRowIds.length > 0 ? getSelectedRows() : rows;
    const exportColumns = effectiveVisibleColumns;
    const csvRows = [
      exportColumns.join(";"),
      ...rowsToExport.map((row) =>
        exportColumns.map((column) => escapeCsvValue(getFilterableCellValue(row[column]))).join(";")
      ),
    ];

    const csvContent = "\uFEFF" + csvRows.join("\n");
    const blob = new Blob([csvContent], { type: "text/csv;charset=utf-8;" });
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.href = url;
    link.download = `${selectedView?.name || "tableau-admin"}.csv`;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(url);
    setShowExportMenu(false);
  }

  function handleExportExcel() {
    const rowsToExport = selectedRowIds.length > 0 ? getSelectedRows() : rows;
    exportRowsToExcel(rowsToExport, selectedView?.name || "tableau-admin");
    pushNotification("success", "Export Excel prepare.");
    setShowExportMenu(false);
  }

  function handleExportPdf() {
    const rowsToExport = selectedRowIds.length > 0 ? getSelectedRows() : rows;
    exportRowsToPdf(rowsToExport, selectedView?.name || "tableau-admin");
    setShowExportMenu(false);
  }

  function handleCreate() {
    if (!selectedCrudConfig) {
      return;
    }

    setActionFeedback(null);
    setEditorMode("create");
    setEditorRecordId(null);
    setEditorValues(createInitialValues(selectedCrudConfig.allFields || selectedCrudConfig.fields));
    setEditorSourceRow(null);
  }

  async function handleEdit(row, mode = "edit") {
    if (!selectedCrudConfig) {
      return;
    }

    const recordId = row[selectedCrudConfig.primaryKey];

    if (!recordId) {
      setActionFeedback({
        type: "error",
        message: "Impossible d'identifier la ligne a modifier.",
      });
      return;
    }

    setActionFeedback(null);
    setLoadingEditor(true);
    setEditorSourceRow(row);

    const payload = await selectedCrudConfig.fetchRecord(row, recordId);

    if (payload?.success && payload.data) {
      setEditorMode(mode);
      setEditorRecordId(recordId);
      setEditorValues(selectedCrudConfig.mapRecord(payload.data));
    } else {
      setEditorMode(null);
      setEditorRecordId(null);
      setEditorValues({});
      setEditorSourceRow(null);
      setActionFeedback({
        type: "error",
        message: payload?.message || "Impossible de charger cet enregistrement.",
      });
    }

    setLoadingEditor(false);
  }

  function handleCancelEditor() {
    setEditorMode(null);
    setEditorRecordId(null);
    setEditorValues({});
    setEditorSourceRow(null);
  }

  async function handleSubmitEditor(event) {
    event.preventDefault();

    if (!selectedCrudConfig || !editorMode) {
      return;
    }

    setSubmittingEditor(true);
    setActionFeedback(null);

    const payload = selectedCrudConfig.buildPayload(editorValues, editorMode);
    const response =
      editorMode === "create"
        ? await selectedCrudConfig.createRecord(payload)
        : await selectedCrudConfig.updateRecord(editorRecordId, payload, editorValues);

    if (response?.success) {
      const successMessage = selectedCrudConfig.getSuccessMessage
        ? selectedCrudConfig.getSuccessMessage(editorMode)
        : editorMode === "create"
          ? `${selectedCrudConfig.resourceLabel} cree avec succes.`
          : `${selectedCrudConfig.resourceLabel} mis a jour avec succes.`;

      setActionFeedback({
        type: "success",
        message: successMessage,
      });
      pushNotification("success", successMessage);
      setEditorMode(null);
      setEditorRecordId(null);
      setEditorValues({});
      setEditorSourceRow(null);
      await loadViewRows(selectedView);
    } else {
      setActionFeedback({
        type: "error",
        message: response?.message || "L'operation a echoue.",
      });
      pushNotification("error", response?.message || "L'operation a echoue.");
    }

    setSubmittingEditor(false);
  }

  async function handleDelete(row) {
    if (!selectedCrudConfig) {
      return;
    }

    const recordId = row[selectedCrudConfig.primaryKey];

    if (!recordId) {
      setActionFeedback({
        type: "error",
        message: "Impossible d'identifier la ligne a supprimer.",
      });
      return;
    }

    const confirmed = window.confirm(
      selectedCrudConfig.deleteConfirmation || "Voulez-vous vraiment supprimer cet enregistrement ?"
    );

    if (!confirmed) {
      return;
    }

    setActionFeedback(null);

    const response = await selectedCrudConfig.deleteRecord(recordId, row);

    if (response?.success) {
      setActionFeedback({
        type: "success",
        message: `${selectedCrudConfig.resourceLabel} supprime avec succes.`,
      });
      pushNotification("success", `${selectedCrudConfig.resourceLabel} supprime avec succes.`);
      await loadViewRows(selectedView);
    } else {
      setActionFeedback({
        type: "error",
        message: response?.message || "La suppression a echoue.",
      });
      pushNotification("error", response?.message || "La suppression a echoue.");
    }
  }

  function renderEditorField(field) {
    const value = editorValues[field.name];

    if (field.type === "checkbox") {
      return (
        <label key={field.name} className="admin-checkbox-field">
          <input
            type="checkbox"
            checked={Boolean(value)}
            onChange={(event) => handleEditorValueChange(field.name, event.target.checked)}
          />
          <span>{field.label}</span>
        </label>
      );
    }

    if (field.type === "select") {
      const fallbackLabel = getSelectFallbackLabel(field, value, editorSourceRow);
      const options = ensureCurrentSelectOptionWithLabel(
        getFieldOptions(field, supportData, editorValues, hierarchyFilterModes, selectedCrudConfig?.model),
        value,
        fallbackLabel
      );

      return (
        <label key={field.name} className="admin-form-field">
          <span>{field.label}</span>
          <CategoricalSelect
            aria-label={field.label}
            value={value ?? ""}
            onChange={(event) => handleEditorValueChange(field.name, event.target.value)}
            required={Boolean(field.required)}
          >
            <option value="">Selectionner</option>
            {options.map((option) => (
              <option key={`${field.name}-${option.value}`} value={option.value} disabled={option.disabled}>
                {option.label}
              </option>
            ))}
          </CategoricalSelect>
          {options.some(option=>option.incompatible&&String(option.value)===String(value))?<small className="record-editor-note">{REFERENCE_RETAINED_HINT}</small>:null}
        </label>
      );
    }

    if (field.type === "textarea") {
      return (
        <label key={field.name} className="admin-form-field admin-form-field-wide">
          <span>{field.label}</span>
          <textarea
            value={value ?? ""}
            onChange={(event) => handleEditorValueChange(field.name, event.target.value)}
            rows={4}
          />
        </label>
      );
    }

    const isRequired = Boolean(field.required || (field.requiredOnCreate && editorMode === "create"));
    const placeholder = editorMode === "create" ? field.placeholderCreate : field.placeholderEdit;

    return (
      <label key={field.name} className="admin-form-field">
        <span>{field.label}</span>
        <input
          type={field.type}
          value={value ?? ""}
          onChange={(event) => handleEditorValueChange(field.name, event.target.value)}
          required={isRequired}
          placeholder={placeholder || ""}
          step={field.step}
          min={field.min}
        />
      </label>
    );
  }

  function renderTableCell(row, column, rowIndex) {
    const rawValue = row[column];
    const cellKey = `${selectedViewKey}-${rowIndex}-${column}`;
    const isObjectValue = typeof rawValue === "object" && rawValue !== null;
    const formattedValue = formatCellValue(rawValue);
    const isLongText = String(formattedValue).length > 180 || isObjectValue;
    const isExpanded = Boolean(expandedCells[cellKey]);

    if (isLongText) {
      return (
        <div className="admin-cell-stack">
          <pre className={`admin-json-cell ${isExpanded ? "is-expanded" : "is-collapsed"}`}>{formattedValue}</pre>
          <button
            type="button"
            className="admin-json-toggle"
            onClick={() => toggleExpandedCell(cellKey)}
          >
            {isExpanded ? "Voir moins" : "Voir plus"}
          </button>
        </div>
      );
    }

    return formatCellValue(rawValue);
  }

  return (
    <div className="page-shell admin-page-shell">
      {notifications.length > 0 ? (
        <div className="admin-notification-stack">
          {notifications.map((notification) => (
            <button
              key={notification.id}
              type="button"
              className={`admin-notification is-${notification.type}`}
              onClick={() => dismissNotification(notification.id)}
            >
              <strong>{notification.type === "success" ? "Succes" : "Attention"}</strong>
              <span>{notification.message}</span>
            </button>
          ))}
        </div>
      ) : null}

      <section className="admin-workspace">
        <ModuleSidebar title={moduleTitle} headerProps={null} collapsed={navigationCollapsed} onToggle={onToggleNavigation} activeKey={selectedViewKey} onNavigate={setSelectedViewKey} storageKey="sauverndeko.territoires.navigation" groups={schemaGroups.flatMap(group=>[
          {key:group.schema+".references",label:schemaGroups.length>1?group.title+" · Références":"Références",items:group.crudViews.map(view=>({key:normalizeViewKey(view.schema,view.name),label:view.title,icon:view.icon||"globe"}))},
          {key:group.schema+".analyses",label:schemaGroups.length>1?group.title+" · Analyses":"Analyses",items:group.readOnlyViews.map(view=>({key:normalizeViewKey(view.schema,view.name),label:view.title,icon:view.icon||"chart"}))},
        ])}>{loadingViews?<p role="status">Chargement du menu…</p>:!schemaGroups.length?<p>Aucune rubrique disponible.</p>:null}</ModuleSidebar>

        <div className="admin-main-column">
          <section className="page-hero-card admin-hero-card">
            <div>
              <span className="badge rounded-pill text-bg-primary-subtle text-primary-emphasis mb-3">Module administration</span>
              <h2>{selectedView?.title || "Administration"}</h2>
              <p>
                {selectedView?.description || "Cet espace regroupe les ecrans d'administration du systeme."}
              </p>
            </div>
            <div className="admin-mail-tools">{!schemaOnly&&currentUser?.Is_Admin===true?<ActionButton icon="mail" onClick={()=>setMailSettingsOpen(true)}>Messagerie</ActionButton>:null}<span className="status-pill">Acces admin</span></div>
          </section>

          {selectedView?.renderMode !== "dashboard" ? (
            <section className="admin-summary-grid">
              <AdminSummaryCard title="Vues disponibles" value={String(navigationViews.length)} />
              <AdminSummaryCard title="Vue selectionnee" value={selectedView ? selectedView.title : "Aucune"} tone="soft" />
              <AdminSummaryCard
                title="Lignes visibles"
                value={loadingData ? "..." : `${rows.length}/${viewMeta.filteredCount || rows.length}`}
                tone="soft"
              />
            </section>
          ) : null}

          <section className="admin-content-card">
          <div className="admin-sticky-panel">
            <div className="admin-content-head">
              <div className="section-head">
                <h3>{selectedView?.title || "Vue d'administration"}</h3>
                <p>{selectedView?.description || "Selectionnez une vue."}</p>
              </div>
              {selectedView ? <span className="status-pill">{buildViewLabel(selectedView)}</span> : null}
            </div>

            {selectedView?.renderMode !== "dashboard" && selectedView?.renderMode !== "empty" ? (
            <>
            <div className="admin-toolbar">
              <div className="admin-toolbar-meta">
                <span className={`status-pill ${selectedCrudConfig ? "" : "is-muted"}`}>
                  {selectedCrudConfig ? "CRUD disponible" : "Lecture seule"}
                </span>
                <span className="status-pill is-muted">
                  {`${viewMeta.filteredCount || rows.length}/${viewMeta.totalCount || rows.length} lignes`}
                </span>
                <span className="status-pill is-muted">{`${pinnedColumns.length} colonnes gelees`}</span>
                {horizontalScrollState.overflow ? (
                  <span className="status-pill is-muted">Defilement horizontal actif</span>
                ) : null}
                {selectedCrudConfig ? (
                  <span className="status-pill is-muted">{`${selectedRowIds.length} selectionnees`}</span>
                ) : null}
                {loadingSupport ? <small>Chargement des listes de support...</small> : null}
                {supportError ? <small>{supportError}</small> : null}
              </div>

              <div className="admin-toolbar-actions">
                <button
                  className="secondary-action"
                  type="button"
                  onClick={() => setShowSearchPanel((current) => !current)}
                >
                  {showSearchPanel ? "Masquer filtres" : "Filtres"}
                </button>
                {selectedCrudConfig && (configurableFkMappings.length > 0 || configurableHierarchyMappings.length > 0) ? (
                  <button
                    className="secondary-action"
                    type="button"
                    onClick={() => setShowFkMappingPanel((current) => !current)}
                  >
                    {showFkMappingPanel ? "Masquer correspondances FK" : "Correspondances FK"}
                  </button>
                ) : null}
                <div ref={exportMenuRef} className="admin-scroll-menu" aria-label="Options d'export">
                  <ActionButton icon="download"

                    type="button"
                    onClick={() => {
                      setShowNavigationMenu(false);
                      setShowExportMenu((current) => !current);
                    }}
                    disabled={rows.length === 0}
                    aria-expanded={showExportMenu}
                    aria-haspopup="true"
                  >
                    Exporter
                  </ActionButton>
                  {showExportMenu ? (
                    <div className="admin-scroll-menu-panel">
                      <ActionButton icon="download"  type="button" onClick={handleExportCsv} disabled={sortedRows.length === 0}>
                        Export CSV
                      </ActionButton>
                      <ActionButton icon="download"  type="button" onClick={handleExportExcel} disabled={rows.length === 0}>
                        Export Excel
                      </ActionButton>
                      <ActionButton icon="download"  type="button" onClick={handleExportPdf} disabled={rows.length === 0}>
                        Export PDF
                      </ActionButton>
                    </div>
                  ) : null}
                </div>
                <div ref={navigationMenuRef} className="admin-scroll-menu" aria-label="Controles de defilement horizontal">
                  <button
                    className={`secondary-action admin-scroll-trigger ${showNavigationMenu ? "is-active" : ""}`}
                    type="button"
                    onClick={() => {
                      setShowExportMenu(false);
                      setShowNavigationMenu((current) => !current);
                    }}
                    disabled={!horizontalScrollState.overflow}
                    aria-expanded={showNavigationMenu}
                    aria-haspopup="true"
                  >
                    Navigation
                  </button>
                  {showNavigationMenu ? (
                    <div className="admin-scroll-menu-panel">
                      <button
                        className="secondary-action"
                        type="button"
                        onClick={() => handleNavigationAction("start")}
                        disabled={!horizontalScrollState.canScrollLeft}
                      >
                        Debut
                      </button>
                      <button
                        className="secondary-action"
                        type="button"
                        onClick={() => handleNavigationAction("left")}
                        disabled={!horizontalScrollState.canScrollLeft}
                      >
                        Gauche
                      </button>
                      <button
                        className="secondary-action"
                        type="button"
                        onClick={() => handleNavigationAction("right")}
                        disabled={!horizontalScrollState.canScrollRight}
                      >
                        Droite
                      </button>
                      <button
                        className="secondary-action"
                        type="button"
                        onClick={() => handleNavigationAction("end")}
                        disabled={!horizontalScrollState.canScrollRight}
                      >
                        Fin
                      </button>
                    </div>
                  ) : null}
                </div>

                {selectedCrudConfig ? (
                  <button
                    className="primary-action"
                    type="button"
                    onClick={handleCreate}
                    disabled={loadingSupport || loadingEditor || submittingEditor}
                  >
                    {selectedCrudConfig.createLabel}
                  </button>
                ) : null}
              </div>
            </div>

            {selectedCrudConfig &&
            showFkMappingPanel &&
            (configurableFkMappings.length > 0 || configurableHierarchyMappings.length > 0) ? (
              <section className="admin-fk-mapping-card">
                <div className="admin-fk-mapping-head">
                  <div>
                    <strong>Correspondances FK et comportement des listes</strong><a href="/referentiels?onglet=champs">Référencement des champs</a>{schemaOnly==="geolocalisation"?<div className="reference-groups">{Object.entries(supportData.referenceByField||{}).filter(([name])=>name.startsWith(selectedCrudConfig.model+".")).map(([name,reference])=><article className="reference-group" key={name}><strong>{name.split(".").slice(1).join(".")}</strong><p>{(reference.categoryIds||[]).join(", ")||"—"} · {(reference.categoryLabels||[]).join(", ")||"Non configurée"}</p></article>)}</div>:null}
                    <p>
                      Les catégories sont gérées dans le référencement des champs. Le filtrage hiérarchique conserve ses réglages.
                    </p>
                  </div>
                  <div className="admin-fk-mapping-head-side">
                    <span className="status-pill is-muted">
                      {`${configurableFkMappings.length + configurableHierarchyMappings.length} reglages configurables`}
                    </span>
                    <div className="admin-fk-mapping-head-actions">
                      {schemaOnly !== "geolocalisation" && genericMappingStates.length > 0 ? (
                        <button
                          className="secondary-action"
                          type="button"
                          onClick={handleApplyAllGenericCategoryOverrides}
                          disabled={!hasDirtyGenericDrafts || hasInvalidGenericDrafts || savingSharedFkSettings || loadingSharedFkSettings}
                        >
                          Appliquer toutes les categories
                        </button>
                      ) : null}
                      <ActionButton icon="reset"

                        type="button"
                        onClick={handleResetAllFkSettings}
                        disabled={(!hasCustomFkSettings && !hasDirtyGenericDrafts) || savingSharedFkSettings || loadingSharedFkSettings}
                      >
                        Reinitialiser tout
                      </ActionButton>
                    </div>
                  </div>
                </div>

                <div className={`admin-fk-mapping-note is-${sharedFkSyncStatus.tone}`}>
                  <div className="admin-fk-mapping-note-head">
                    <span className={`admin-fk-state-chip is-${sharedFkSyncStatus.tone}`}>{sharedFkSyncStatus.title}</span>
                  </div>
                  <div className="admin-fk-mapping-note-details">
                    {sharedFkSyncStatus.details.map((detail, index) => (
                      <span key={`${detail.text}-${index}`} className={`admin-fk-note-item is-${detail.tone || "muted"}`}>
                        {detail.text}
                      </span>
                    ))}
                  </div>
                </div>

                <div className="admin-fk-history-card">
                  <div className="admin-fk-history-head">
                    <div>
                      <strong>Historique compact</strong>
                      <p>Les dernieres modifications enregistrees pour le parametrage partage.</p>
                    </div>
                    <span className="status-pill is-muted">
                      {loadingSharedFkAudit ? "Chargement..." : `${visibleSharedFkAuditRows.length} entree(s) affichee(s)`}
                    </span>
                  </div>

                  {sharedFkAuditError ? <div className="admin-fk-history-empty is-error">{sharedFkAuditError}</div> : null}

                  {!sharedFkAuditError && loadingSharedFkAudit ? (
                    <div className="admin-fk-history-empty">Chargement de l'historique des reglages FK...</div>
                  ) : null}

                  {!sharedFkAuditError && !loadingSharedFkAudit && visibleSharedFkAuditRows.length === 0 ? (
                    <div className="admin-fk-history-empty">
                      Aucun historique n'est encore disponible pour cette portee.
                    </div>
                  ) : null}

                  {!sharedFkAuditError && !loadingSharedFkAudit && visibleSharedFkAuditRows.length > 0 ? (
                    <div className="admin-fk-history-list">
                      {visibleSharedFkAuditRows.map((row) => {
                        const auditScope = getAuditSettingScope(row);
                        const auditScopeLabel = buildAdminUiScopeLabelFromValues(auditScope.scope, auditScope.scopeValue);
                        const operationLabel = row.Operation === "CREATE" ? "Creation" : "Mise a jour";
                        const changedAtLabel =
                          formatDisplayDateTime(row.ChangedAt || row.UpdatedSettingAt) ||
                          String(row.ChangedAt || row.UpdatedSettingAt || "");
                        const authorLabel = row.UpdatedByName || row.UpdatedByUserId || "Utilisateur inconnu";

                        return (
                          <article key={row.IdLog || `${row.ChangedAt}-${row.Operation}`} className="admin-fk-history-item">
                            <div className="admin-fk-history-item-top">
                              <strong>{operationLabel}</strong>
                              <span className="admin-fk-state-chip is-info">{auditScopeLabel}</span>
                            </div>
                            <div className="admin-fk-history-item-meta">
                              <span>{changedAtLabel}</span>
                              <span>{authorLabel}</span>
                            </div>
                          </article>
                        );
                      })}
                    </div>
                  ) : null}
                </div>

                {schemaOnly !== "geolocalisation" && configurableFkMappings.length > 0 ? (
                  <>
                    <div className="admin-fk-mapping-section-head">
                      <strong>Categories generiques</strong>
                      <span>ID_CategorieGenerique utilise pour chaque liste deroulante</span>
                    </div>

                    <div className="admin-fk-mapping-grid">
                      {(schemaOnly === "geolocalisation" ? [] : genericMappingStates).map((mapping) => {
                        return (
                          <article key={mapping.source} className="admin-fk-mapping-item">
                            <div className="admin-fk-mapping-meta">
                              <div className="admin-fk-mapping-title-row">
                                <strong>{mapping.labels.join(", ")}</strong>
                                <div className="admin-fk-state-badges">
                                  <span className={`admin-fk-state-chip ${mapping.isCustom ? "is-custom" : "is-default"}`}>
                                    {mapping.isCustom ? "Personnalise" : "Defaut"}
                                  </span>
                                  {mapping.isDirty ? (
                                    <span className="admin-fk-state-chip is-pending">Non applique</span>
                                  ) : null}
                                  {!mapping.isValid ? (
                                    <span className="admin-fk-state-chip is-invalid">Invalide</span>
                                  ) : null}
                                </div>
                              </div>
                              <span>{mapping.fieldNames.join(", ")}</span>
                              <small>{mapping.source}</small>
                            </div>

                            <label className={`admin-form-field ${!mapping.isValid ? "is-invalid" : ""}`}>
                              <span>ID categorie</span>
                              <input
                                type="text"
                                inputMode="numeric"
                                value={mapping.inputValue}
                                onChange={(event) => handleGenericCategoryDraftChange(mapping.source, event.target.value)}
                                placeholder={mapping.defaultValue}
                              />
                            </label>

                            <div className="admin-fk-mapping-hint">
                              <small>{`Defaut: ${mapping.defaultValue}`}</small>
                              <small>{`Categorie active: ${mapping.effectiveCategoryLabels}`}</small>
                              <small>{`${mapping.optionsCount} options chargees actuellement`}</small>
                              {!mapping.isValid ? (
                                <small>Utilisez un ou plusieurs IDs entiers positifs separes par des virgules.</small>
                              ) : null}
                            </div>

                            <div className="admin-fk-mapping-actions">
                              <button
                                className="secondary-action"
                                type="button"
                                onClick={() => handleApplyGenericCategoryOverride(mapping.source)}
                                disabled={!mapping.isValid || !mapping.isDirty || savingSharedFkSettings || loadingSharedFkSettings}
                              >
                                Appliquer
                              </button>
                              <ActionButton icon="reset"

                                type="button"
                                onClick={() => handleResetGenericCategoryOverride(mapping.source)}
                                disabled={(!mapping.isCustom && mapping.inputValue === mapping.defaultValue) || savingSharedFkSettings || loadingSharedFkSettings}
                              >
                                Reinitialiser
                              </ActionButton>
                            </div>
                          </article>
                        );
                      })}
                    </div>
                  </>
                ) : null}

                {configurableHierarchyMappings.length > 0 ? (
                  <>
                    <div className="admin-fk-mapping-section-head">
                      <strong>Listes hierarchiques</strong>
                      <span>Choisissez entre une liste filtree par le parent saisi ou la liste complete</span>
                    </div>

                    <div className="admin-fk-mapping-grid">
                      {hierarchyMappingStates.map((mapping) => {
                        const availableModes = mapping.config.availableModes || ["filtered", "all"];

                        return (
                          <article key={mapping.source} className="admin-fk-mapping-item">
                            <div className="admin-fk-mapping-meta">
                              <div className="admin-fk-mapping-title-row">
                                <strong>{mapping.labels.join(", ")}</strong>
                                <div className="admin-fk-state-badges">
                                  <span className={`admin-fk-state-chip ${mapping.isCustom ? "is-custom" : "is-default"}`}>
                                    {mapping.isCustom ? "Personnalise" : "Defaut"}
                                  </span>
                                </div>
                              </div>
                              <span>{mapping.fieldNames.join(", ")}</span>
                              <small>{mapping.source}</small>
                            </div>

                            <label className="admin-form-field">
                              <span>Mode de liste</span>
                              <CategoricalSelect
                                aria-label={"Mode de liste · " + mapping.labels.join(", ")}
                                value={mapping.mode}
                                onChange={(event) => handleHierarchyFilterModeChange(mapping.source, event.target.value)}
                                disabled={savingSharedFkSettings || loadingSharedFkSettings || availableModes.length <= 1}
                              >
                                {availableModes.includes("filtered") ? (
                                  <option value="filtered">Liste filtree par parent</option>
                                ) : null}
                                {availableModes.includes("all") ? <option value="all">Liste complete</option> : null}
                              </CategoricalSelect>
                            </label>

                            <div className="admin-fk-mapping-hint">
                              <small>
                                {mapping.mode === "all"
                                  ? "Toutes les valeurs de ce niveau sont affichees."
                                  : "Seules les valeurs liees au parent renseigne sont affichees."}
                              </small>
                              <small>{`${mapping.optionsCount} options disponibles dans la source`}</small>
                              {availableModes.length <= 1 ? (
                                <small>Cette liste ne depend pas d'un parent, elle reste donc complete.</small>
                              ) : null}
                            </div>
                          </article>
                        );
                      })}
                    </div>
                  </>
                ) : null}
              </section>
            ) : null}

            {selectedCrudConfig ? (
              <div className="admin-selection-strip">
                <div className="admin-bulk-actions">
                  <div className="admin-bulk-actions-main">
                    <span>{selectedRowIds.length > 0 ? `${selectedRowIds.length} lignes selectionnees` : "Aucune ligne selectionnee"}</span>
                    {selectedPrimaryRow ? (
                      <small>{`Ligne active: ${selectedCrudConfig.primaryKey} ${selectedPrimaryRow[selectedCrudConfig.primaryKey]}`}</small>
                    ) : (
                      <small>Cliquez sur une ligne du tableau pour afficher ses actions hors de la grille.</small>
                    )}
                  </div>
                </div>

                <div className="admin-selection-actions">
                  <div className="admin-selection-actions-head">
                    <strong>Actions de la ligne selectionnee</strong>
                    <span>
                      {selectedPrimaryRow
                        ? `Vous agissez hors du tableau sur la ligne ${selectedPrimaryRow[selectedCrudConfig.primaryKey]}.`
                        : selectedRowIds.length > 1
                          ? "Plusieurs lignes sont selectionnees. Gardez une seule ligne active pour voir ses actions."
                          : "Selectionnez une seule ligne pour voir ses actions metier."}
                    </span>
                  </div>
                  <div className="admin-selection-actions-buttons">
                    {selectedPrimaryRow ? (
                      (selectedCrudConfig.rowActions || []).length > 0 ? (
                        selectedCrudConfig.rowActions.map((action) =>
                          action.mode === "delete" ? (
                            <button
                              key={action.mode}
                              type="button"
                              className="admin-danger-button"
                              onClick={() => handleDelete(selectedPrimaryRow)}
                              disabled={selectedRowIds.length !== 1 || submittingEditor}
                            >
                              {action.label}
                            </button>
                          ) : (
                            <button
                              key={action.mode}
                              type="button"
                              className="secondary-action"
                              onClick={() => handleEdit(selectedPrimaryRow, action.mode)}
                              disabled={selectedRowIds.length !== 1 || submittingEditor}
                            >
                              {action.label}
                            </button>
                          )
                        )
                      ) : (
                        <>
                          <button
                            type="button"
                            className="secondary-action"
                            onClick={() => handleEdit(selectedPrimaryRow)}
                            disabled={selectedRowIds.length !== 1 || submittingEditor}
                          >
                            Modifier
                          </button>
                          <button
                            type="button"
                            className="admin-danger-button"
                            onClick={() => handleDelete(selectedPrimaryRow)}
                            disabled={selectedRowIds.length !== 1 || submittingEditor}
                          >
                            Supprimer
                          </button>
                        </>
                      )
                    ) : null}
                  </div>
                </div>
              </div>
            ) : null}

            <div className="admin-global-search-bar">
              <label className="admin-form-field admin-global-search-field">
                <span>Recherche globale</span>
                <input
                  type="search"
                  value={searchTerm}
                  onChange={(event) => setSearchTerm(event.target.value)}
                  placeholder="Rechercher une information dans le tableau"
                />
              </label>
            </div>
            </>
            ) : null}
          </div>

          {showSearchPanel ? (
            <section className="admin-search-card">
              <div className="admin-search-head">
                <div className="section-head">
                  <h3>Filtres</h3>
                  <p>Affinez le tableau, gelez et redimensionnez les colonnes importantes.</p>
                </div>
                <ActionButton icon="reset"  type="button" onClick={handleResetFilters}>
                  Reinitialiser
                </ActionButton>
              </div>

              {activeFilterChips.length > 0 ? (
                <div className="admin-filter-chips">
                  {activeFilterChips.map((chip) => (
                    <button key={chip.key} type="button" className="admin-filter-chip" onClick={chip.onRemove}>
                      <span>{chip.label}</span>
                      <small>x</small>
                    </button>
                  ))}
                </div>
              ) : null}

              <div className="admin-search-grid">
                {selectedViewKey === "systeme.V_Login_history" && filterableColumns.includes("TypeLogin") ? (
                  <div className="admin-quick-filters admin-form-field-wide">
                    <span>Filtre rapide historique</span>
                    <div className="admin-quick-filter-actions">
                      {[
                        { label: "Tout", values: [] },
                        { label: "Connexion", values: ["Connexion"] },
                        { label: "D\u00e9connexion", values: ["Deconnexion", "D\u00e9connexion"] },
                      ].map((option) => {
                        const isActive = JSON.stringify(columnFilters.TypeLogin || []) === JSON.stringify(option.values);

                        return (
                          <button
                            key={option.label}
                            type="button"
                            className={`secondary-action ${isActive ? "is-active" : ""}`}
                            onClick={() => handleSelectAllMultiFilter("TypeLogin", option.values)}
                          >
                            {option.label}
                          </button>
                        );
                      })}
                    </div>
                  </div>
                ) : null}

                {columnFilterDefinitions.map((definition) =>
                  definition.useMultiSelect ? (
                    <AdminMultiSelectFilter
                      key={definition.column}
                      definition={definition}
                      selectedValues={Array.isArray(columnFilters[definition.column]) ? columnFilters[definition.column] : []}
                      isOpen={openFilterColumn === definition.column}
                      searchValue={filterSearchTerms[definition.column] || ""}
                      onToggleOpen={() =>
                        setOpenFilterColumn((current) => (current === definition.column ? "" : definition.column))
                      }
                      onSearchChange={(value) =>
                        setFilterSearchTerms((current) => ({
                          ...current,
                          [definition.column]: value,
                        }))
                      }
                      onToggleValue={(value) => handleToggleMultiFilterValue(definition.column, value)}
                      onSelectAll={() => handleSelectAllMultiFilter(definition.column, definition.values)}
                      onClear={() => handleClearMultiFilter(definition.column)}
                    />
                  ) : (
                    <label key={definition.column} className="admin-form-field">
                      <span>{definition.displayLabel || definition.column}</span>
                      <input
                        type="search"
                        value={typeof columnFilters[definition.column] === "string" ? columnFilters[definition.column] : ""}
                        onChange={(event) => handleColumnFilterChange(definition.column, event.target.value)}
                        placeholder={`Filtrer ${definition.displayLabel || definition.column}`}
                      />
                    </label>
                  )
                )}

                <div className="admin-visibility-card admin-form-field-wide">
                  <div className="admin-visibility-head">
                    <span>Colonnes visibles, gelees et largeur</span>
                    <div className="admin-visibility-actions">
                      <button type="button" className="secondary-action" onClick={handleShowAllColumns}>
                        Tout afficher
                      </button>
                      <ActionButton icon="reset" type="button"  onClick={handleResetColumns}>
                        Reinitialiser
                      </ActionButton>
                    </div>
                  </div>
                  <div className="admin-visibility-grid">
                    {columns.map((column) => {
                      const isPinned = pinnedColumns.includes(column);

                      return (
                        <div key={`visible-${column}`} className="admin-column-option">
                          <label className="admin-multiselect-option">
                            <input
                              type="checkbox"
                              checked={effectiveVisibleColumns.includes(column)}
                              onChange={() => handleToggleVisibleColumn(column)}
                            />
                            <span>{getColumnDisplayLabel(column)}</span>
                          </label>
                          <div className="admin-column-option-actions">
                            <button
                              type="button"
                              className={`secondary-action ${isPinned ? "is-active" : ""}`}
                              onClick={() => handleTogglePinnedColumn(column)}
                            >
                              {isPinned ? "Degeler" : "Geler"}
                            </button>
                            <button
                              type="button"
                              className="secondary-action"
                              onClick={() => handleResetColumnWidth(column)}
                            >
                              Largeur auto
                            </button>
                          </div>
                        </div>
                      );
                    })}
                  </div>
                </div>
              </div>
            </section>
          ) : null}

          {selectedView?.renderMode === "dashboard" ? (
            <section className="admin-dashboard-layout">
              {dashboardError ? <section className="table-empty-state">{dashboardError}</section> : null}
              {loadingDashboard ? <section className="table-empty-state">Chargement du tableau de bord...</section> : null}

              {!dashboardError && !loadingDashboard && dashboardData ? (
                <>
                  <div className="admin-dashboard-metrics">
                    {dashboardData.metrics.map((metric) => (
                      <DashboardMetricCard
                        key={metric.title}
                        title={metric.title}
                        value={metric.value}
                        detail={metric.detail}
                        tone={metric.tone}
                        icon={metric.icon}
                      />
                    ))}
                  </div>

                  <div className="admin-dashboard-grid">
                    <DashboardMiniTable
                      title="Derniers journaux d'audit"
                      rows={dashboardData.recentAudit}
                      columns={[
                        { key: "ChangedAt", label: "Date", render: (row) => formatCellValue(row.ChangedAt) },
                        { key: "TableName", label: "Table" },
                        { key: "Operation", label: "Operation", render: (row) => formatCellValue(row.Operation) },
                      ]}
                    />
                    <DashboardMiniTable
                      title="Historique de connexion recent"
                      rows={dashboardData.recentLogins}
                      columns={[
                        { key: "DateLogin", label: "Date", render: (row) => formatCellValue(row.DateLogin) },
                        { key: "NomUser", label: "Utilisateur", render: (row) => `${row.PrenomUser || ""} ${row.NomUser || ""}`.trim() || row.EmailUser || "-" },
                        { key: "TypeLogin", label: "Type" },
                      ]}
                    />
                    <DashboardMiniTable
                      title="Licences proches expiration"
                      rows={dashboardData.recentLicences}
                      columns={[
                        { key: "NomEntite", label: "Entite" },
                        { key: "DateFin", label: "Date fin", render: (row) => formatCellValue(row.DateFin) },
                        { key: "statut_licence", label: "Statut", render: (row) => formatCellValue(row.statut_licence) },
                      ]}
                    />
                    <DashboardMiniTable
                      title="Correspondances FK recentes"
                      rows={dashboardData.recentMappings}
                      columns={[
                        { key: "ViewName", label: "Vue" },
                        { key: "FieldName", label: "Champ" },
                        { key: "SettingScope", label: "Scope" },
                      ]}
                    />
                    <DashboardMiniTable
                      title="Parametres UI modifies"
                      rows={dashboardData.recentSettings}
                      columns={[
                        { key: "SettingGroup", label: "Groupe" },
                        { key: "SettingKey", label: "Cle" },
                        { key: "UpdatedAt", label: "Mis a jour", render: (row) => formatCellValue(row.UpdatedAt) },
                      ]}
                    />
                  </div>
                </>
              ) : null}
            </section>
          ) : null}

          {selectedView?.renderMode === "empty" ? (
            <section className="table-empty-state">
              <strong>{selectedView.emptyTitle || "Vue indisponible"}</strong>
              <p>{selectedView.emptyMessage || "Aucune source de donnees n'est encore disponible pour cet ecran."}</p>
            </section>
          ) : null}

          {actionFeedback ? (
            <section className={`profile-feedback ${actionFeedback.type === "success" ? "is-success" : "is-error"}`}>
              {actionFeedback.message}
            </section>
          ) : null}

          {selectedView?.renderMode !== "dashboard" && selectedView?.renderMode !== "empty" ? (
            <>
          {selectedCrudConfig && editorMode ? (
            <section className="admin-editor-card">
              <div className="admin-editor-head">
                <div className="section-head">
                  <h3>
                    {selectedCrudConfig.getModeLabel
                      ? selectedCrudConfig.getModeLabel(editorMode)
                      : editorMode === "create"
                        ? selectedCrudConfig.createLabel
                        : "Modifier l'enregistrement"}
                  </h3>
                  <p>
                    {selectedCrudConfig.getModeDescription
                      ? selectedCrudConfig.getModeDescription(editorMode)
                      : editorMode === "create"
                        ? "Les champs saisis seront envoyes au backend admin."
                        : "Modifiez les informations puis validez la mise a jour."}
                  </p>
                </div>
                {loadingEditor ? <span className="status-pill">Chargement...</span> : null}
              </div>

              <form className="admin-editor-form" onSubmit={handleSubmitEditor}>
                <div className="admin-editor-grid">{editorFields.map(renderEditorField)}</div>

                <div className="admin-editor-actions">
                  <button className="secondary-action" type="button" onClick={handleCancelEditor} disabled={submittingEditor}>
                    Annuler
                  </button>
                  <button className="primary-action" type="submit" disabled={loadingEditor || submittingEditor}>
                    {submittingEditor ? "Enregistrement..." : "Enregistrer"}
                  </button>
                </div>
              </form>
            </section>
          ) : null}

          {errorMessage ? <section className="table-empty-state">{errorMessage}</section> : null}

          {loadingData ? (
            <section className="table-empty-state">Chargement des donnees...</section>
          ) : rows.length > 0 ? (
            <>
              <div
                ref={tableWrapRef}
                className="public-table-wrap admin-table-wrap"
                tabIndex={0}
                onKeyDown={handleTableWrapKeyDown}
                aria-label="Tableau d'administration avec defilement horizontal et vertical"
              >
                <table className="public-table admin-table">
                  <colgroup>
                    {selectedCrudConfig ? <col style={{ width: 64 }} /> : null}
                    {effectiveVisibleColumns.map((column) => (
                      <col key={`col-${column}`} style={{ width: getColumnWidth(column) }} />
                    ))}
                  </colgroup>
                  <thead>
                    <tr>
                      {selectedCrudConfig ? (
                        <th className="admin-select-column">
                          {(() => {
                            const selectablePageIds = rows
                              .map((row) => resolveRowRecordId(row, selectedCrudConfig))
                              .filter((recordId) => Boolean(recordId));

                            return (
                              <input
                                type="checkbox"
                                checked={
                                  selectablePageIds.length > 0 &&
                                  selectablePageIds.every((recordId) => selectedRowIds.includes(recordId))
                                }
                                onChange={handleTogglePageSelection}
                                aria-label="Selectionner la page"
                              />
                            );
                          })()}
                        </th>
                      ) : null}
                      {effectiveVisibleColumns.map((column) => {
                        const isPinned = pinnedColumns.includes(column);

                        return (
                          <th
                            key={column}
                            className={`admin-table-head-cell ${isPinned ? "is-pinned" : ""}`}
                            style={getCellStyle(column, true)}
                          >
                            <div className="admin-header-cell">
                              <div className="admin-header-content">
                                <div className="admin-header-tools">
                                  <button
                                    type="button"
                                    className={`admin-sort-button ${sortConfig.column === column ? "is-active" : ""} ${
                                      sortConfig.column === column && sortConfig.direction ? `is-${sortConfig.direction}` : ""
                                    }`}
                                    onClick={() => handleSortColumn(column)}
                                  >
                                    <small>
                                      {sortConfig.column === column
                                        ? sortConfig.direction === "asc"
                                          ? "Asc"
                                          : sortConfig.direction === "desc"
                                            ? "Desc"
                                            : "Tri"
                                        : "Tri"}
                                    </small>
                                  </button>

                                  <button
                                    type="button"
                                    className={`admin-pin-button ${isPinned ? "is-active" : ""}`}
                                    onClick={() => handleTogglePinnedColumn(column)}
                                  >
                                    {isPinned ? "Degeler" : "Geler"}
                                  </button>
                                </div>

                                <div className="admin-header-label" title={column}>
                                  {getColumnDisplayLabel(column)}
                                </div>
                              </div>

                              <div
                                className="admin-resize-handle"
                                onMouseDown={(event) => handleResizeStart(column, event)}
                                role="separator"
                                aria-orientation="vertical"
                                aria-label={`Redimensionner la colonne ${column}`}
                              />
                            </div>
                          </th>
                        );
                      })}
                    </tr>
                  </thead>
                  <tbody>
                    {paginatedRows.map((row, rowIndex) => {
                      const rowRecordId = resolveRowRecordId(row, selectedCrudConfig);
                      const isSelected = rowRecordId ? selectedRowIds.includes(rowRecordId) : false;

                      return (
                        <tr
                          key={`${selectedViewKey}-${rowRecordId || "row"}-${row.IdEntiteLocalisation || rowIndex}`}
                          className={isSelected ? "admin-table-row is-selected" : "admin-table-row"}
                          onClick={(event) => handleActivateRow(row, event)}
                        >
                        {selectedCrudConfig ? (
                          <td className="admin-select-column">
                            <input
                              type="checkbox"
                              checked={isSelected}
                              onChange={() => handleToggleRowSelection(row)}
                              disabled={!rowRecordId}
                              aria-label="Selectionner la ligne"
                            />
                          </td>
                        ) : null}
                        {effectiveVisibleColumns.map((column) => {
                          const isPinned = pinnedColumns.includes(column);

                          return (
                            <td
                              key={`${rowIndex}-${column}`}
                              className={isPinned ? "admin-table-cell is-pinned" : "admin-table-cell"}
                              style={getCellStyle(column)}
                            >
                              {renderTableCell(row, column, rowIndex)}
                            </td>
                          );
                        })}
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              </div>

              {!loadingData && viewMeta.filteredCount === 0 ? (
                <section className="table-empty-state">
                  Aucun resultat ne correspond a votre recherche ou a vos filtres.
                </section>
              ) : null}

              {sortedRows.length > 0 ? (
                <section ref={tableFooterRef} className="admin-table-footer">
                  <div className="admin-table-footer-meta">
                    <span>{`Page ${currentPage} sur ${totalPages}`}</span>
                    <span>{`${rows.length} lignes affichees sur ${viewMeta.filteredCount || rows.length}`}</span>
                  </div>

                  <div className="admin-table-footer-actions">
                    <label className="admin-page-size">
                      <span>Lignes par page</span>
                      <select value={rowsPerPage} onChange={(event) => handleRowsPerPageChange(Number(event.target.value))}>
                        {[10, 25, 50, 100].map((value) => (
                          <option key={value} value={value}>
                            {value}
                          </option>
                        ))}
                      </select>
                    </label>

                    <div className="admin-pagination">
                      <button type="button" className="secondary-action" onClick={() => handlePageNavigation(1)} disabled={currentPage === 1}>
                        1ere
                      </button>
                      <button
                        type="button"
                        className="secondary-action"
                        onClick={() => handlePageNavigation(Math.max(1, currentPage - 1))}
                        disabled={currentPage === 1}
                      >
                        Prec
                      </button>
                      <button
                        type="button"
                        className="secondary-action"
                        onClick={() => handlePageNavigation(Math.min(totalPages, currentPage + 1))}
                        disabled={currentPage === totalPages}
                      >
                        Suiv
                      </button>
                      <button
                        type="button"
                        className="secondary-action"
                        onClick={() => handlePageNavigation(totalPages)}
                        disabled={currentPage === totalPages}
                      >
                        Dern
                      </button>
                    </div>
                  </div>
                </section>
              ) : null}
            </>
          ) : (
            <section className="table-empty-state">
              {selectedCrudConfig
                ? "Aucune donnee disponible pour cette vue. Vous pouvez creer un nouvel enregistrement."
                : "Aucune donnee disponible pour cette vue."}
            </section>
          )}
            </>
          ) : null}
          </section>
        </div>
      </section>
      {mailSettingsOpen&&!schemaOnly&&currentUser?.Is_Admin===true?<AdminMailSettings onClose={()=>setMailSettingsOpen(false)}/>:null}
    </div>
  );
}
