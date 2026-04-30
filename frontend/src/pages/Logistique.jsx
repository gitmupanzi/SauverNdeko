import { startTransition, useEffect, useMemo, useState } from "react";
import {
  fetchAdminModelList,
  fetchAdminUiSettings,
  fetchAdminUiSettingsAudit,
  fetchViewData,
  saveAdminUiSettings,
} from "../services/api";
import { fetchLogistiqueReferences } from "../services/logistique";
import AlertesStock from "./logistique/AlertesStock";
import Articles from "./logistique/Articles";
import CommandeDetails from "./logistique/CommandeDetails";
import Commandes from "./logistique/Commandes";
import ConsommationMensuelle from "./logistique/ConsommationMensuelle";
import CouvertureStock from "./logistique/CouvertureStock";
import DashboardLogistique from "./logistique/DashboardLogistique";
import Mouvements from "./logistique/Mouvements";
import Reglements from "./logistique/Reglements";
import StockAudit from "./logistique/StockAudit";
import { LOGISTIQUE_GENERIC_SOURCE_CONFIG, LOGISTIQUE_MODULE_SCHEMA } from "./logistique/views";

const LOGISTIQUE_GENERIC_CATEGORY_STORAGE_KEY = "logistique.generic-category-overrides";

function normalizeStringRecord(value) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return {};
  }

  return Object.entries(value).reduce((accumulator, [key, entryValue]) => {
    const normalizedKey = String(key || "").trim();
    const normalizedValue = String(entryValue || "").trim();

    if (normalizedKey && normalizedValue) {
      accumulator[normalizedKey] = normalizedValue;
    }

    return accumulator;
  }, {});
}

function readLogistiqueCategoryOverrides() {
  if (typeof window === "undefined") {
    return {};
  }

  try {
    const rawValue = window.localStorage.getItem(LOGISTIQUE_GENERIC_CATEGORY_STORAGE_KEY);

    if (!rawValue) {
      return {};
    }

    const parsed = JSON.parse(rawValue);
    return normalizeStringRecord(parsed);
  } catch (_error) {
    return {};
  }
}

function extractPayloadRows(payload) {
  return payload?.success && Array.isArray(payload.data) ? payload.data : [];
}

function normalizeGenericRows(rows, categories) {
  const categoryNameById = new Map(
    categories.map((category) => [
      String(category.ID_CategorieGenerique ?? category.id ?? ""),
      category.NomCategorieGenerique || category.label || "",
    ])
  );

  return rows.map((row) => {
    const categoryId = row.ID_CategorieGeneriqueFk ?? row.categoryId ?? row.ID_CategorieGenerique ?? row.idCategorie;

    return {
      ...row,
      ID_Generique: row.ID_Generique ?? row.id,
      NomGenerique: row.NomGenerique ?? row.label,
      AbrGenerique: row.AbrGenerique ?? row.abbr ?? "",
      ID_CategorieGeneriqueFk: categoryId,
      NomCategorieGenerique:
        row.NomCategorieGenerique || categoryNameById.get(String(categoryId ?? "")) || "",
    };
  });
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

function serializeCategoryIds(categoryIds) {
  return categoryIds.map((value) => String(value)).join(", ");
}

function filterGenericsByCategoryIds(generics, categoryIds) {
  const allowedIds = new Set(categoryIds.map((value) => Number(value)));
  return generics.filter((item) => allowedIds.has(Number(item.ID_CategorieGeneriqueFk ?? item.ID_CategorieGenerique)));
}

function getConfiguredCategoryIdsForSource(sourceKey, overrides) {
  const config = LOGISTIQUE_GENERIC_SOURCE_CONFIG[sourceKey];

  if (!config) {
    return [];
  }

  if (config.locked) {
    return config.defaultCategoryIds;
  }

  const overrideValue = overrides?.[sourceKey];
  const parsedOverride = parseCategoryOverrideInput(overrideValue);
  return parsedOverride && parsedOverride.length > 0 ? parsedOverride : config.defaultCategoryIds;
}

function buildGenericReferenceOptions(sourceKey, generics, overrides) {
  const matches = filterGenericsByCategoryIds(generics, getConfiguredCategoryIdsForSource(sourceKey, overrides));

  return matches
    .map((item) => ({
      id: item.ID_Generique,
      label: item.NomGenerique || item.AbrGenerique || `Valeur #${item.ID_Generique}`,
      abbr: item.AbrGenerique || "",
      categoryId: item.ID_CategorieGeneriqueFk,
    }))
    .sort((leftItem, rightItem) => leftItem.label.localeCompare(rightItem.label, "fr"));
}

function isLockedLogistiqueGenericSource(sourceKey) {
  return Boolean(LOGISTIQUE_GENERIC_SOURCE_CONFIG[sourceKey]?.locked);
}

function buildLogistiqueReferences(baseReferences, generics, overrides) {
  if (!baseReferences) {
    return null;
  }

  if (!Array.isArray(generics) || generics.length === 0) {
    return baseReferences;
  }

  const nextReferences = { ...baseReferences };

  Object.entries(LOGISTIQUE_GENERIC_SOURCE_CONFIG).forEach(([sourceKey, config]) => {
    const generatedOptions = buildGenericReferenceOptions(sourceKey, generics, overrides);
    const backendOptions = Array.isArray(baseReferences[config.referenceKey]) ? baseReferences[config.referenceKey] : [];

    if (config.locked && backendOptions.length > 0) {
      nextReferences[config.referenceKey] = backendOptions;
      return;
    }

    nextReferences[config.referenceKey] = generatedOptions.length > 0 ? generatedOptions : backendOptions;
  });

  return nextReferences;
}

function pickLogistiqueOverrides(overrides) {
  return Object.entries(normalizeStringRecord(overrides)).reduce((accumulator, [key, value]) => {
    if (key.startsWith("logistique.")) {
      accumulator[key] = value;
    }

    return accumulator;
  }, {});
}

function mergeLogistiqueOverrides(allOverrides, logistiqueOverrides) {
  const nextOverrides = { ...normalizeStringRecord(allOverrides) };

  Object.keys(nextOverrides).forEach((key) => {
    if (key.startsWith("logistique.")) {
      delete nextOverrides[key];
    }
  });

  return {
    ...nextOverrides,
    ...normalizeStringRecord(logistiqueOverrides),
  };
}

function formatDisplayDateTime(value) {
  if (!value) {
    return null;
  }

  const parsed = new Date(value);

  if (Number.isNaN(parsed.getTime())) {
    return null;
  }

  return new Intl.DateTimeFormat("fr-FR", {
    day: "2-digit",
    month: "2-digit",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
  }).format(parsed);
}

function formatSyncLabel(meta) {
  if (!meta?.updatedAt) {
    return "Aucune synchronisation serveur enregistree";
  }

  const dateLabel = formatDisplayDateTime(meta.updatedAt) || String(meta.updatedAt);
  return meta.updatedByName ? `Synchronise le ${dateLabel} par ${meta.updatedByName}` : `Synchronise le ${dateLabel}`;
}

function buildLogistiqueFkSyncStatus({
  loading,
  saving,
  error,
  meta,
  hasServerSettings,
  hasDirtyDrafts,
  hasInvalidDrafts,
}) {
  if (loading) {
    return {
      tone: "info",
      title: "Chargement des reglages partages...",
      details: [{ tone: "muted", text: "Les categories FK logistiques sont en cours de lecture." }],
    };
  }

  if (saving) {
    return {
      tone: "info",
      title: "Enregistrement serveur en cours...",
      details: [{ tone: "info", text: "Les correspondances FK logistiques sont en cours de synchronisation." }],
    };
  }

  if (error) {
    return {
      tone: "danger",
      title: "Synchronisation serveur indisponible",
      details: [
        { tone: "danger", text: error },
        { tone: "warning", text: "Les reglages visibles restent actifs localement dans cette session." },
      ],
    };
  }

  const details = [];

  if (hasServerSettings) {
    details.push({ tone: "success", text: "Les reglages affiches proviennent du serveur et sont deja actifs." });
    details.push({ tone: "muted", text: formatSyncLabel(meta) });
  } else {
    details.push({ tone: "muted", text: "Aucun parametrage serveur logistique n'est encore enregistre." });
    details.push({ tone: "warning", text: "Les reglages affiches restent locaux jusqu'au premier enregistrement." });
  }

  if (hasInvalidDrafts) {
    details.push({ tone: "danger", text: "Certaines categories saisies sont invalides." });
  } else if (hasDirtyDrafts) {
    details.push({ tone: "warning", text: "Des modifications locales attendent encore d'etre appliquees." });
  }

  return {
    tone: hasServerSettings ? "success" : "warning",
    title: hasServerSettings ? "Reglages synchronises via le serveur admin" : "Reglages locaux actifs",
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

function pickLogistiqueOverridesFromAuditPayload(payload) {
  return pickLogistiqueOverrides(payload?.genericCategoryOverrides);
}

function hasLogistiqueAuditChange(row) {
  const newData = parseAuditPayload(row?.NewData);
  const oldData = parseAuditPayload(row?.OldData);
  const before = JSON.stringify(pickLogistiqueOverridesFromAuditPayload(oldData));
  const after = JSON.stringify(pickLogistiqueOverridesFromAuditPayload(newData));
  return before !== after;
}

function countLoadedReferenceEntries(references) {
  if (!references || typeof references !== "object") {
    return 0;
  }

  return Object.values(references).reduce((total, value) => {
    if (Array.isArray(value)) {
      return total + value.length;
    }

    return total;
  }, 0);
}

function LogistiqueSummaryCard({ title, value, tone = "primary" }) {
  return (
    <article className={`admin-summary-card ${tone}`}>
      <span>{title}</span>
      <strong>{value}</strong>
    </article>
  );
}

function LogistiqueTabButton({ tab, isActive, onSelect }) {
  return (
    <button className={`admin-view-button ${isActive ? "is-active" : ""}`} type="button" onClick={onSelect}>
      <div className="logistics-catalogue-item-head">
        <strong>{tab.label || tab.title}</strong>
        <small className={`logistics-catalogue-badge ${tab.accessMode === "Lecture seule" ? "is-muted" : ""}`}>
          {tab.accessMode}
        </small>
      </div>
      <small>{tab.viewLabel}</small>
    </button>
  );
}

const TABS = LOGISTIQUE_MODULE_SCHEMA.views;
const TAB_GROUPS = LOGISTIQUE_MODULE_SCHEMA.tabGroups;
const TABLE_FEATURE_CONFIG = LOGISTIQUE_MODULE_SCHEMA.tableFeatures;

export default function Logistique() {
  const [activeTab, setActiveTab] = useState("dashboard");
  const [selectedCommande, setSelectedCommande] = useState(null);
  const [refreshKey, setRefreshKey] = useState(0);
  const [sharedTableState, setSharedTableState] = useState({
    articles: { search: "", selectedRow: null },
    commandes: { search: "", selectedRow: null },
    details: { search: "", selectedRow: null, composerMode: "view" },
    mouvements: { search: "", selectedRow: null },
    reglements: { search: "", selectedRow: null },
  });
  const [baseReferences, setBaseReferences] = useState(null);
  const [referenceCategories, setReferenceCategories] = useState([]);
  const [genericRows, setGenericRows] = useState([]);
  const [referencesLoading, setReferencesLoading] = useState(true);
  const [referencesError, setReferencesError] = useState("");
  const [genericSupportError, setGenericSupportError] = useState("");
  const [genericCategoryOverrides, setGenericCategoryOverrides] = useState(() => readLogistiqueCategoryOverrides());
  const [genericCategoryDrafts, setGenericCategoryDrafts] = useState({});
  const [allServerGenericOverrides, setAllServerGenericOverrides] = useState({});
  const [serverHierarchyModes, setServerHierarchyModes] = useState({});
  const [loadingSharedFkSettings, setLoadingSharedFkSettings] = useState(true);
  const [savingSharedFkSettings, setSavingSharedFkSettings] = useState(false);
  const [sharedFkSettingsError, setSharedFkSettingsError] = useState("");
  const [sharedFkSettingsMeta, setSharedFkSettingsMeta] = useState({
    updatedAt: null,
    updatedByUserId: null,
    updatedByName: null,
  });
  const [showFkMappingPanel, setShowFkMappingPanel] = useState(false);
  const [sharedFkAuditRows, setSharedFkAuditRows] = useState([]);
  const [loadingSharedFkAudit, setLoadingSharedFkAudit] = useState(false);
  const [sharedFkAuditError, setSharedFkAuditError] = useState("");

  useEffect(() => {
    if (typeof window === "undefined") {
      return;
    }

    window.localStorage.setItem(LOGISTIQUE_GENERIC_CATEGORY_STORAGE_KEY, JSON.stringify(genericCategoryOverrides));
  }, [genericCategoryOverrides]);

  useEffect(() => {
    let isMounted = true;

    async function loadReferences() {
      setReferencesLoading(true);
      setReferencesError("");
      setGenericSupportError("");

      const [referencesResponse, categoriesResponse, genericsViewResponse, genericsTableResponse] = await Promise.all([
        fetchLogistiqueReferences(),
        fetchAdminModelList("T_CategorieGenerique", { take: 200 }),
        fetchViewData("referentiel", "V_Generique", { take: 500 }),
        fetchAdminModelList("T_Generique", { take: 500 }),
      ]);

      if (!isMounted) {
        return;
      }

      if (!referencesResponse?.success) {
        setBaseReferences(null);
        setReferencesError(referencesResponse?.message || "Impossible de charger les references logistiques.");
        setReferencesLoading(false);
        return;
      }

      const categories = extractPayloadRows(categoriesResponse);
      const genericsFromView = normalizeGenericRows(extractPayloadRows(genericsViewResponse), categories);
      const genericsFromTable = normalizeGenericRows(extractPayloadRows(genericsTableResponse), categories);

      setBaseReferences(referencesResponse.data);
      setReferenceCategories(categories);
      setGenericRows(genericsFromView.length > 0 ? genericsFromView : genericsFromTable);

      if (!categoriesResponse?.success || (!genericsViewResponse?.success && !genericsTableResponse?.success)) {
        setGenericSupportError("Les sources referentiel du panneau FK n'ont pas toutes pu etre chargees.");
      }

      setReferencesLoading(false);
    }

    loadReferences();

    return () => {
      isMounted = false;
    };
  }, []);

  useEffect(() => {
    let isMounted = true;

    async function loadSharedLogistiqueSettings() {
      setLoadingSharedFkSettings(true);
      setSharedFkSettingsError("");

      try {
        const response = await fetchAdminUiSettings({ scope: "global" });

        if (!isMounted) {
          return;
        }

        if (response?.success && response.data?.exists) {
          const allOverrides = normalizeStringRecord(response.data.genericCategoryOverrides);
          setAllServerGenericOverrides(allOverrides);
          setServerHierarchyModes(response.data.hierarchyFilterModes || {});
          setGenericCategoryOverrides(pickLogistiqueOverrides(allOverrides));
          setGenericCategoryDrafts({});
          setSharedFkSettingsMeta({
            updatedAt: response.data.updatedAt || null,
            updatedByUserId: response.data.updatedByUserId ?? null,
            updatedByName: response.data.updatedByName || null,
          });
        } else {
          setAllServerGenericOverrides({});
          setServerHierarchyModes({});
          setSharedFkSettingsMeta({
            updatedAt: null,
            updatedByUserId: null,
            updatedByName: null,
          });
        }
      } catch (_error) {
        if (!isMounted) {
          return;
        }

        setSharedFkSettingsError("Impossible de charger les reglages partages du panneau FK.");
      } finally {
        if (isMounted) {
          setLoadingSharedFkSettings(false);
        }
      }
    }

    loadSharedLogistiqueSettings();

    return () => {
      isMounted = false;
    };
  }, []);

  useEffect(() => {
    let isMounted = true;

    async function loadSharedFkAuditTrail() {
      if (!showFkMappingPanel) {
        return;
      }

      setLoadingSharedFkAudit(true);
      setSharedFkAuditError("");

      const payload = await fetchAdminUiSettingsAudit({
        take: 20,
        skip: 0,
      });

      if (!isMounted) {
        return;
      }

      if (payload?.success && Array.isArray(payload.data)) {
        setSharedFkAuditRows(payload.data);
      } else {
        setSharedFkAuditRows([]);
        setSharedFkAuditError(payload?.message || "Impossible de charger l'historique compact des reglages FK.");
      }

      setLoadingSharedFkAudit(false);
    }

    loadSharedFkAuditTrail();

    return () => {
      isMounted = false;
    };
  }, [showFkMappingPanel, sharedFkSettingsMeta.updatedAt]);

  function bumpRefresh() {
    setRefreshKey((current) => current + 1);
  }

  function handleNavigate(tabKey) {
    startTransition(() => {
      setActiveTab(tabKey);
    });
  }

  function handleOpenDetails(commande, composerMode = "view") {
    setSelectedCommande(commande);
    setSharedTableState((current) => ({
      ...current,
      commandes: {
        ...current.commandes,
        selectedRow: commande,
      },
      details: {
        ...current.details,
        selectedRow: null,
        composerMode,
      },
    }));
    handleNavigate("details");
  }

  function updateSharedTableState(tabKey, patch) {
    setSharedTableState((current) => ({
      ...current,
      [tabKey]: {
        ...current[tabKey],
        ...patch,
      },
    }));
  }

  const references = useMemo(
    () => buildLogistiqueReferences(baseReferences, genericRows, genericCategoryOverrides),
    [baseReferences, genericRows, genericCategoryOverrides]
  );

  const activeTabConfig = useMemo(
    () => TABS.find((tab) => tab.key === activeTab) || TABS[0],
    [activeTab]
  );

  const activeTableConfig = TABLE_FEATURE_CONFIG[activeTab] || null;
  const activeFkMappings = activeTableConfig?.fkMappings || [];

  const activeGenericMappings = useMemo(() => {
    const sourceMap = new Map();

    activeFkMappings.forEach((mapping) => {
      if (mapping.kind !== "generic" || !mapping.sourceKey || !LOGISTIQUE_GENERIC_SOURCE_CONFIG[mapping.sourceKey]) {
        return;
      }

      if (sourceMap.has(mapping.sourceKey)) {
        const current = sourceMap.get(mapping.sourceKey);
        current.labels.push(mapping.label);
        current.fieldNames.push(mapping.field);
        return;
      }

      sourceMap.set(mapping.sourceKey, {
        sourceKey: mapping.sourceKey,
        labels: [mapping.label],
        fieldNames: [mapping.field],
        source: mapping.source,
      });
    });

    return Array.from(sourceMap.values()).sort((leftItem, rightItem) =>
      leftItem.labels[0].localeCompare(rightItem.labels[0], "fr")
    );
  }, [activeFkMappings]);

  const activeDirectMappings = useMemo(
    () => activeFkMappings.filter((mapping) => mapping.kind !== "generic"),
    [activeFkMappings]
  );

  useEffect(() => {
    if (activeGenericMappings.length === 0) {
      return;
    }

    setGenericCategoryDrafts((current) => {
      const nextDrafts = { ...current };

      activeGenericMappings.forEach((mapping) => {
        const config = LOGISTIQUE_GENERIC_SOURCE_CONFIG[mapping.sourceKey];

        if (config && nextDrafts[mapping.sourceKey] == null) {
          nextDrafts[mapping.sourceKey] =
            config.locked
              ? serializeCategoryIds(config.defaultCategoryIds)
              : genericCategoryOverrides[mapping.sourceKey] ?? serializeCategoryIds(config.defaultCategoryIds);
        }
      });

      return nextDrafts;
    });
  }, [activeGenericMappings, genericCategoryOverrides]);

  const categoryNameById = useMemo(
    () =>
      new Map(
        referenceCategories.map((category) => [
          String(category.ID_CategorieGenerique ?? category.id ?? ""),
          category.NomCategorieGenerique || category.label || `Categorie ${category.ID_CategorieGenerique ?? category.id}`,
        ])
      ),
    [referenceCategories]
  );

  const genericMappingStates = useMemo(
    () =>
      activeGenericMappings.map((mapping) => {
        const config = LOGISTIQUE_GENERIC_SOURCE_CONFIG[mapping.sourceKey];
        const defaultValue = serializeCategoryIds(config.defaultCategoryIds);
        const isLocked = Boolean(config.locked);
        const storedOverride = isLocked ? "" : genericCategoryOverrides[mapping.sourceKey];
        const inputValue = isLocked ? defaultValue : genericCategoryDrafts[mapping.sourceKey] ?? storedOverride ?? defaultValue;
        const parsedInput = parseCategoryOverrideInput(inputValue);
        const isValid = Boolean(parsedInput && parsedInput.length > 0);
        const normalizedInput = isValid ? serializeCategoryIds(parsedInput) : String(inputValue ?? "").trim();
        const isDirty = isLocked ? false : normalizedInput !== String(storedOverride ?? defaultValue);
        const effectiveIds = getConfiguredCategoryIdsForSource(mapping.sourceKey, genericCategoryOverrides);
        const effectiveCategoryLabels = effectiveIds
          .map((categoryId) => categoryNameById.get(String(categoryId)) || `Categorie ${categoryId}`)
          .join(", ");
        const optionsCount = Array.isArray(references?.[config.referenceKey]) ? references[config.referenceKey].length : 0;

        return {
          ...mapping,
          config,
          defaultValue,
          storedOverride,
          inputValue,
          parsedInput,
          isValid,
          isDirty,
          isCustom: isLocked ? false : Boolean(storedOverride),
          isLocked,
          effectiveIds,
          effectiveCategoryLabels,
          optionsCount,
        };
      }),
    [activeGenericMappings, categoryNameById, genericCategoryDrafts, genericCategoryOverrides, references]
  );

  const hasInvalidGenericDrafts = genericMappingStates.some((item) => !item.isValid);
  const hasDirtyGenericDrafts = genericMappingStates.some((item) => item.isDirty);
  const hasCustomFkSettings = genericMappingStates.some((item) => item.isCustom);

  const sharedFkSyncStatus = useMemo(
    () =>
      buildLogistiqueFkSyncStatus({
        loading: loadingSharedFkSettings,
        saving: savingSharedFkSettings,
        error: sharedFkSettingsError,
        meta: sharedFkSettingsMeta,
        hasServerSettings: Boolean(sharedFkSettingsMeta.updatedAt),
        hasDirtyDrafts: hasDirtyGenericDrafts,
        hasInvalidDrafts: hasInvalidGenericDrafts,
      }),
    [
      hasDirtyGenericDrafts,
      hasInvalidGenericDrafts,
      loadingSharedFkSettings,
      savingSharedFkSettings,
      sharedFkSettingsError,
      sharedFkSettingsMeta,
    ]
  );

  const visibleSharedFkAuditRows = useMemo(
    () => sharedFkAuditRows.filter(hasLogistiqueAuditChange).slice(0, 4),
    [sharedFkAuditRows]
  );

  async function persistSharedFkSettings(nextLogistiqueOverrides) {
    setSavingSharedFkSettings(true);
    setSharedFkSettingsError("");

    const response = await saveAdminUiSettings({
      scope: "global",
      genericCategoryOverrides: mergeLogistiqueOverrides(allServerGenericOverrides, nextLogistiqueOverrides),
      hierarchyFilterModes: serverHierarchyModes,
    });

    setSavingSharedFkSettings(false);

    if (!response?.success || !response.data) {
      setSharedFkSettingsError(response?.message || "Impossible d'enregistrer les reglages partages.");
      return false;
    }

    const nextAllOverrides = normalizeStringRecord(response.data.genericCategoryOverrides);

    setAllServerGenericOverrides(nextAllOverrides);
    setGenericCategoryOverrides(pickLogistiqueOverrides(nextAllOverrides));
    setSharedFkSettingsMeta({
      updatedAt: response.data.updatedAt || null,
      updatedByUserId: response.data.updatedByUserId ?? null,
      updatedByName: response.data.updatedByName || null,
    });
    setSharedFkSettingsError("");

    return true;
  }

  function handleGenericCategoryDraftChange(sourceKey, nextValue) {
    if (isLockedLogistiqueGenericSource(sourceKey)) {
      return;
    }

    setGenericCategoryDrafts((current) => ({
      ...current,
      [sourceKey]: nextValue,
    }));
  }

  async function handleApplyGenericCategoryOverride(sourceKey) {
    const config = LOGISTIQUE_GENERIC_SOURCE_CONFIG[sourceKey];

    if (!config || config.locked) {
      return;
    }

    const draftValue =
      genericCategoryDrafts[sourceKey] ?? genericCategoryOverrides[sourceKey] ?? serializeCategoryIds(config.defaultCategoryIds);
    const parsedCategoryIds = parseCategoryOverrideInput(draftValue);

    if (!parsedCategoryIds || parsedCategoryIds.length === 0) {
      return;
    }

    const serializedValue = serializeCategoryIds(parsedCategoryIds);
    const defaultValue = serializeCategoryIds(config.defaultCategoryIds);

    setGenericCategoryDrafts((current) => ({
      ...current,
      [sourceKey]: serializedValue,
    }));

    const nextOverrides = { ...genericCategoryOverrides };

    if (serializedValue === defaultValue) {
      delete nextOverrides[sourceKey];
    } else {
      nextOverrides[sourceKey] = serializedValue;
    }

    await persistSharedFkSettings(nextOverrides);
  }

  async function handleResetGenericCategoryOverride(sourceKey) {
    const config = LOGISTIQUE_GENERIC_SOURCE_CONFIG[sourceKey];

    if (!config || config.locked) {
      return;
    }

    setGenericCategoryDrafts((current) => ({
      ...current,
      [sourceKey]: serializeCategoryIds(config.defaultCategoryIds),
    }));

    const nextOverrides = { ...genericCategoryOverrides };
    delete nextOverrides[sourceKey];

    await persistSharedFkSettings(nextOverrides);
  }

  async function handleApplyAllGenericCategoryOverrides() {
    if (genericMappingStates.some((item) => !item.isValid)) {
      return;
    }

    const nextOverrides = {};
    const nextDrafts = {};

    genericMappingStates.forEach((item) => {
      if (item.isLocked) {
        nextDrafts[item.sourceKey] = item.defaultValue;
        return;
      }

      const serializedValue = serializeCategoryIds(item.parsedInput);
      nextDrafts[item.sourceKey] = serializedValue;

      if (serializedValue !== item.defaultValue) {
        nextOverrides[item.sourceKey] = serializedValue;
      }
    });

    setGenericCategoryDrafts((current) => ({
      ...current,
      ...nextDrafts,
    }));

    await persistSharedFkSettings(nextOverrides);
  }

  async function handleResetAllFkSettings() {
    const nextDrafts = {};

    genericMappingStates.forEach((item) => {
      nextDrafts[item.sourceKey] = item.defaultValue;
    });

    setGenericCategoryDrafts((current) => ({
      ...current,
      ...nextDrafts,
    }));

    await persistSharedFkSettings({});
  }

  const headerStats = useMemo(
    () => [
      { label: "Volets logistiques", value: TABS.length },
      {
        label: "Vue selectionnee",
        value: TABS.find((tab) => tab.key === activeTab)?.title || "Aucune",
        tone: "soft",
      },
      {
        label: "References chargees",
        value: referencesLoading ? "..." : formatCompactCount(countLoadedReferenceEntries(references)),
        tone: "soft",
      },
    ],
    [activeTab, references, referencesLoading]
  );

  const tabGroups = useMemo(
    () =>
      TAB_GROUPS.map((group) => ({
        ...group,
        tabs: TABS.filter((tab) => tab.group === group.key),
      })),
    []
  );

  const logistiqueMeta = useMemo(
    () =>
      [
        activeTabConfig.accessMode,
        activeTabConfig.viewLabel,
        referencesLoading ? "Chargement des references..." : `${formatCompactCount(references?.articles?.length || 0)} articles references`,
        referencesLoading ? "" : `${formatCompactCount(references?.factures?.length || 0)} factures repertoriees`,
        selectedCommande?.CodeCmd ? `Commande cible: ${selectedCommande.CodeCmd}` : "",
      ].filter(Boolean),
    [activeTabConfig, references, referencesLoading, selectedCommande]
  );

  const sharedTableFeatures = useMemo(
    () =>
      Object.fromEntries(
        Object.entries(TABLE_FEATURE_CONFIG).map(([tabKey, config]) => [
          tabKey,
          {
            ...config,
            searchValue: sharedTableState[tabKey]?.search || "",
            setSearchValue: (value) => updateSharedTableState(tabKey, { search: value }),
            selectedRow: sharedTableState[tabKey]?.selectedRow || null,
            setSelectedRow: (row) => updateSharedTableState(tabKey, { selectedRow: row }),
            clearSelectedRow: () => updateSharedTableState(tabKey, { selectedRow: null }),
            composerMode: sharedTableState[tabKey]?.composerMode || "view",
            setComposerMode: (value) => updateSharedTableState(tabKey, { composerMode: value }),
          },
        ])
      ),
    [sharedTableState]
  );

  return (
    <div className="page-shell admin-page-shell logistics-page-shell">
      <section className="admin-workspace logistics-workspace">
        <aside className="admin-sidebar-card logistics-sidebar-card">
          <div className="section-head">
            <h3>Catalogue logistique</h3>
            <p>Ouvrez vite une vue metier ou un ecran de controle.</p>
          </div>

          <div className="admin-view-list" role="tablist" aria-label="Navigation interne logistique">
            {tabGroups.map((group) => (
              <section key={group.key} className="admin-view-group">
                <div className="admin-view-group-head">
                  <strong>{group.title}</strong>
                  <span>{group.tabs.length}</span>
                </div>
                {group.tabs.map((tab) => (
                  <LogistiqueTabButton
                    key={tab.key}
                    tab={tab}
                    isActive={activeTab === tab.key}
                    onSelect={() => handleNavigate(tab.key)}
                  />
                ))}
              </section>
            ))}
          </div>
        </aside>

        <div className="admin-main-column logistics-main-column">
          <section className="page-hero-card admin-hero-card logistics-hero-card">
            <div>
              <span className="badge rounded-pill text-bg-primary-subtle text-primary-emphasis mb-3">Module logistique</span>
              <h2>Logistique</h2>
              <p>
                Vue de gestion compacte pour les articles, commandes, mouvements et reglements.
              </p>
            </div>
            <div className="logistics-hero-side">
              <span className="status-pill">Acces logistique</span>
              <small>{activeTabConfig.viewLabel}</small>
            </div>
          </section>

          {activeTab === "dashboard" ? (
            <section className="admin-summary-grid">
              {headerStats.map((item) => (
                <LogistiqueSummaryCard
                  key={item.label}
                  title={item.label}
                  value={String(item.value)}
                  tone={item.tone || "primary"}
                />
              ))}
            </section>
          ) : null}

          <section className="admin-content-card logistics-content-card">
            <div className="admin-sticky-panel logistics-sticky-panel">
              <div className="admin-content-head">
                <div className="section-head">
                  <h3>{activeTabConfig.label || activeTabConfig.title}</h3>
                  <p>{activeTabConfig.viewLabel}</p>
                </div>
                <span className="status-pill">{activeTabConfig.accessMode}</span>
              </div>

              <div className="admin-toolbar">
                <div className="admin-toolbar-meta">
                  {logistiqueMeta.map((item) => (
                    <span key={item} className={`status-pill ${item === activeTabConfig.accessMode ? "" : "is-muted"}`}>
                      {item}
                    </span>
                  ))}
                  {referencesError ? <small>{referencesError}</small> : null}
                  {!referencesError && genericSupportError ? <small>{genericSupportError}</small> : null}
                </div>

                <div className="admin-toolbar-actions">
                  <button type="button" className="secondary-action" onClick={bumpRefresh}>
                    Actualiser
                  </button>
                  {activeTab !== "dashboard" ? (
                    <button type="button" className="secondary-action" onClick={() => handleNavigate("dashboard")}>
                      Retour dashboard
                    </button>
                  ) : null}
                </div>
              </div>
            </div>

            {referencesLoading ? <section className="table-empty-state">Chargement des references logistiques...</section> : null}
            {!referencesLoading && referencesError ? <section className="table-empty-state">{referencesError}</section> : null}

            {!referencesLoading && !referencesError && activeFkMappings.length > 0 ? (
              <section className="admin-fk-mapping-card">
                <div className="admin-fk-mapping-head">
                  <div>
                    <strong>Correspondances FK et comportement des listes</strong>
                    <p>Parametrage optionnel des listes logistiques.</p>
                  </div>
                  <div className="admin-fk-mapping-head-side">
                    <span className="status-pill is-muted">
                      {`${activeGenericMappings.length + activeDirectMappings.length} reglage(s) pour cette vue`}
                    </span>
                    <div className="admin-fk-mapping-head-actions">
                      <button
                        className="secondary-action"
                        type="button"
                        onClick={() => setShowFkMappingPanel((current) => !current)}
                      >
                        {showFkMappingPanel ? "Masquer correspondances FK" : "Correspondances FK"}
                      </button>
                    </div>
                  </div>
                </div>

                {!showFkMappingPanel ? (
                  <div className="admin-fk-history-empty">Panneau masque pour garder la lecture du tableau prioritaire.</div>
                ) : (
                  <>
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
                          <p>Les dernieres modifications enregistrees pour le parametrage partage logistique.</p>
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
                          Aucun historique n'est encore disponible pour les reglages logistiques.
                        </div>
                      ) : null}

                      {!sharedFkAuditError && !loadingSharedFkAudit && visibleSharedFkAuditRows.length > 0 ? (
                        <div className="admin-fk-history-list">
                          {visibleSharedFkAuditRows.map((row) => {
                            const operationLabel = row.Operation === "CREATE" ? "Creation" : "Mise a jour";
                            const changedAtLabel =
                              formatDisplayDateTime(row.ChangedAt || row.UpdatedSettingAt) ||
                              String(row.ChangedAt || row.UpdatedSettingAt || "");
                            const authorLabel = row.UpdatedByName || row.UpdatedByUserId || "Utilisateur inconnu";

                            return (
                              <article key={row.IdLog || `${row.ChangedAt}-${row.Operation}`} className="admin-fk-history-item">
                                <div className="admin-fk-history-item-top">
                                  <strong>{operationLabel}</strong>
                                  <span className="admin-fk-state-chip is-info">Logistique</span>
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

                    {genericMappingStates.length > 0 ? (
                      <>
                        <div className="admin-fk-mapping-section-head">
                          <strong>Categories generiques</strong>
                          <span>ID_CategorieGenerique utilise pour chaque liste deroulante logistique</span>
                        </div>

                        <div className="admin-fk-mapping-head-actions">
                          <button
                            className="secondary-action"
                            type="button"
                            onClick={handleApplyAllGenericCategoryOverrides}
                            disabled={!hasDirtyGenericDrafts || hasInvalidGenericDrafts || savingSharedFkSettings || loadingSharedFkSettings}
                          >
                            Appliquer toutes les categories
                          </button>
                          <button
                            className="secondary-action"
                            type="button"
                            onClick={handleResetAllFkSettings}
                            disabled={(!hasCustomFkSettings && !hasDirtyGenericDrafts) || savingSharedFkSettings || loadingSharedFkSettings}
                          >
                            Reinitialiser tout
                          </button>
                        </div>

                        <div className="admin-fk-mapping-grid">
                          {genericMappingStates.map((mapping) => (
                            <article key={mapping.sourceKey} className="admin-fk-mapping-item">
                              <div className="admin-fk-mapping-meta">
                                <div className="admin-fk-mapping-title-row">
                                  <strong>{mapping.labels.join(", ")}</strong>
                                  <div className="admin-fk-state-badges">
                                    <span className={`admin-fk-state-chip ${mapping.isCustom ? "is-custom" : "is-default"}`}>
                                      {mapping.isLocked ? "Verrouille" : mapping.isCustom ? "Personnalise" : "Defaut"}
                                    </span>
                                    {mapping.isDirty ? <span className="admin-fk-state-chip is-pending">Non applique</span> : null}
                                    {!mapping.isValid ? <span className="admin-fk-state-chip is-invalid">Invalide</span> : null}
                                  </div>
                                </div>
                                <span>{mapping.fieldNames.join(", ")}</span>
                                <small>{mapping.sourceKey}</small>
                              </div>

                              <label className={`admin-form-field ${!mapping.isValid ? "is-invalid" : ""}`}>
                                <span>ID categorie</span>
                                <input
                                  type="text"
                                  inputMode="numeric"
                                  value={mapping.inputValue}
                                  onChange={(event) => handleGenericCategoryDraftChange(mapping.sourceKey, event.target.value)}
                                  placeholder={mapping.defaultValue}
                                  disabled={mapping.isLocked}
                                />
                              </label>

                              <div className="admin-fk-mapping-hint">
                                <small>{`Defaut: ${mapping.defaultValue}`}</small>
                                <small>{`Categorie active: ${mapping.effectiveCategoryLabels}`}</small>
                                <small>{`${mapping.optionsCount} options chargees actuellement`}</small>
                                {mapping.isLocked ? (
                                  <small>Alignement metier verrouille pour garantir les listes deroulantes logistiques attendues.</small>
                                ) : null}
                                {!mapping.isValid ? (
                                  <small>Utilisez un ou plusieurs IDs entiers positifs separes par des virgules.</small>
                                ) : null}
                              </div>

                              <div className="admin-fk-mapping-actions">
                                <button
                                  className="secondary-action"
                                  type="button"
                                  onClick={() => handleApplyGenericCategoryOverride(mapping.sourceKey)}
                                  disabled={
                                    mapping.isLocked ||
                                    !mapping.isValid ||
                                    !mapping.isDirty ||
                                    savingSharedFkSettings ||
                                    loadingSharedFkSettings
                                  }
                                >
                                  Appliquer
                                </button>
                                <button
                                  className="secondary-action"
                                  type="button"
                                  onClick={() => handleResetGenericCategoryOverride(mapping.sourceKey)}
                                  disabled={
                                    mapping.isLocked ||
                                    ((!mapping.isCustom && mapping.inputValue === mapping.defaultValue) ||
                                      savingSharedFkSettings ||
                                      loadingSharedFkSettings)
                                  }
                                >
                                  Reinitialiser
                                </button>
                              </div>
                            </article>
                          ))}
                        </div>
                      </>
                    ) : null}

                    {activeDirectMappings.length > 0 ? (
                      <>
                        <div className="admin-fk-mapping-section-head">
                          <strong>Sources directes</strong>
                          <span>Ces liaisons restent basees sur des tables ou vues metier sans categorie generique editable.</span>
                        </div>

                        <div className="admin-fk-mapping-grid">
                          {activeDirectMappings.map((mapping) => (
                            <article key={mapping.field} className="admin-fk-mapping-item">
                              <div className="admin-fk-mapping-meta">
                                <div className="admin-fk-mapping-title-row">
                                  <strong>{mapping.label}</strong>
                                  <div className="admin-fk-state-badges">
                                    <span className="admin-fk-state-chip is-default">Direct</span>
                                  </div>
                                </div>
                                <span>{mapping.field}</span>
                                <small>{mapping.source}</small>
                              </div>
                              <div className="admin-fk-mapping-hint">
                                <small>Cette correspondance est informative et sert au detail de ligne et aux libelles.</small>
                              </div>
                            </article>
                          ))}
                        </div>
                      </>
                    ) : null}
                  </>
                )}
              </section>
            ) : null}

            {!referencesLoading && !referencesError ? (
              <div className="logistics-shell-view">
                {activeTab === "dashboard" ? <DashboardLogistique refreshKey={refreshKey} onNavigate={handleNavigate} /> : null}
                {activeTab === "articles" ? (
                  <Articles
                    references={references}
                    refreshKey={refreshKey}
                    onDataChanged={bumpRefresh}
                    sharedTable={sharedTableFeatures.articles}
                  />
                ) : null}
                {activeTab === "commandes" ? (
                  <Commandes
                    references={references}
                    refreshKey={refreshKey}
                    onDataChanged={bumpRefresh}
                    onOpenDetails={handleOpenDetails}
                    sharedTable={sharedTableFeatures.commandes}
                  />
                ) : null}
                {activeTab === "details" ? (
                  <CommandeDetails
                    selectedCommande={selectedCommande}
                    references={references}
                    refreshKey={refreshKey}
                    onDataChanged={bumpRefresh}
                    sharedTable={sharedTableFeatures.details}
                  />
                ) : null}
                {activeTab === "mouvements" ? (
                  <Mouvements references={references} refreshKey={refreshKey} sharedTable={sharedTableFeatures.mouvements} />
                ) : null}
                {activeTab === "audit" ? <StockAudit refreshKey={refreshKey} /> : null}
                {activeTab === "alertes" ? <AlertesStock refreshKey={refreshKey} /> : null}
                {activeTab === "consommation" ? (
                  <ConsommationMensuelle references={references} refreshKey={refreshKey} />
                ) : null}
                {activeTab === "couverture" ? <CouvertureStock refreshKey={refreshKey} /> : null}
                {activeTab === "reglements" ? (
                  <Reglements
                    references={references}
                    refreshKey={refreshKey}
                    onDataChanged={bumpRefresh}
                    sharedTable={sharedTableFeatures.reglements}
                  />
                ) : null}
              </div>
            ) : null}
          </section>
        </div>
      </section>
    </div>
  );
}

function formatCompactCount(value) {
  return new Intl.NumberFormat("fr-FR").format(Number(value || 0));
}
