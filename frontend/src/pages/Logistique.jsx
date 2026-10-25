import ReferenceSettings from "../components/ReferenceSettings";
import { useAuth } from "../contexts/AuthContext";
import AppIcon from "../components/AppIcon";
import { Link, useSearchParams } from "react-router-dom";
import ModuleHeader from "../components/ModuleHeader";
import "./logistique/LogistiqueModern.css";
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
import DossiersSuivi from "./logistique/DossiersSuivi";
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
const LOGISTIQUE_SIDEBAR_STORAGE_KEY = "logistique.sidebar-collapsed";

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

function readSidebarCollapsedPreference() {
  if (typeof window === "undefined") {
    return false;
  }

  return window.localStorage.getItem(LOGISTIQUE_SIDEBAR_STORAGE_KEY) === "true";
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

function normalizeUiText(value) {
  return String(value || "")
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "");
}

function LogistiqueSummaryCard({ title, value, tone = "primary" }) {
  return (
    <article className={`admin-summary-card ${tone}`}>
      <span>{title}</span>
      <strong>{value}</strong>
    </article>
  );
}

function LogistiqueResponsiveStyles() {
  return (
    <style>{`
      .logistics-page-shell {
        overflow-x: hidden;
      }

      .logistics-workspace,
      .logistics-main-column,
      .logistics-content-card,
      .logistics-shell-view {
        max-width: 100%;
        min-width: 0;
      }

      .logistics-workspace {
        display: block !important;
        width: 100%;
      }

      .logistics-main-column {
        width: 100% !important;
      }

      .logistics-catalogue-hero-card {
        display: grid;
        grid-template-columns: minmax(220px, 280px) minmax(0, 1fr);
        align-items: start;
        gap: 16px;
        padding: 18px;
        overflow: hidden;
      }

      .logistics-catalogue-hero-head {
        min-width: 0;
      }

      .logistics-catalogue-hero-head .section-head h2 {
        margin-bottom: 6px;
      }

      .logistics-catalogue-hero-head .section-head p {
        margin-bottom: 10px;
      }

      .logistics-catalogue-current-view {
        display: inline-flex;
        max-width: 100%;
      }

      .logistics-catalogue-groups {
        min-width: 0;
        display: grid;
        grid-template-columns: 1fr;
        gap: 12px;
      }

      .logistics-catalogue-horizontal-group {
        min-width: 0 !important;
      }

      .logistics-catalogue-horizontal-tabs {
        display: grid !important;
        grid-template-columns: repeat(auto-fit, minmax(138px, 1fr));
        gap: 8px;
        min-width: 0;
      }

      .logistics-catalogue-horizontal-tabs .admin-view-button {
        width: 100%;
        min-width: 0;
        min-height: 64px;
        padding: 10px 12px;
        text-align: left;
      }

      .logistics-catalogue-horizontal-tabs .logistics-catalogue-item-head {
        align-items: flex-start;
        gap: 6px;
      }

      .logistics-catalogue-horizontal-tabs .logistics-catalogue-badge {
        flex: 0 0 auto;
        font-size: 10px;
        line-height: 1.1;
        white-space: nowrap;
      }

      .logistics-catalogue-horizontal-tabs .admin-view-button strong {
        display: block;
        font-size: 12px;
        line-height: 1.12;
      }

      .logistics-catalogue-horizontal-tabs .admin-view-button > small {
        display: block;
        margin-top: 5px;
        max-width: 100%;
        overflow: hidden;
        text-overflow: ellipsis;
        white-space: nowrap;
        font-size: 10px;
        line-height: 1.2;
      }

      .logistics-content-card {
        overflow: hidden;
      }

      .logistics-shell-view > * {
        max-width: 100%;
        min-width: 0;
      }

      @media (max-width: 1180px) {
        .logistics-catalogue-hero-card {
          grid-template-columns: 1fr;
        }
      }
    `}</style>
  );
}

function LogistiqueTabButton({ tab, isActive, onSelect }) {
  return (
    <button
      className={`admin-view-button ${isActive ? "is-active" : ""}`}
      type="button"
      onClick={onSelect}
      role="tab"
      aria-selected={isActive}
      title={`${tab.label || tab.title} - ${tab.viewLabel}`}
    >
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

function LogistiqueCatalogueBar({ tabGroups, activeTab, activeTabConfig, onNavigate }) {
  return (
    <section className="page-hero-card admin-hero-card logistics-catalogue-hero-card" aria-label="Catalogue logistique">
      <div className="logistics-catalogue-hero-head">
        <div className="section-head">
          <h2>Catalogue logistique</h2>
          <p>Ouvrez vite une vue metier ou un ecran de controle.</p>
        </div>
        <div className="logistics-hero-side logistics-catalogue-current-view">
          <span className="status-pill">{activeTabConfig.accessMode}</span>
          <small>{activeTabConfig.viewLabel}</small>
        </div>
      </div>

      <div className="logistics-catalogue-groups" role="tablist" aria-label="Navigation interne logistique">
        {tabGroups.map((group) => (
          <section key={group.key} className="admin-view-group logistics-catalogue-horizontal-group">
            <div className="admin-view-group-head">
              <strong>{group.title}</strong>
              <span>{group.tabs.length}</span>
            </div>
            <div className="logistics-catalogue-horizontal-tabs">
              {group.tabs.map((tab) => (
                <LogistiqueTabButton
                  key={tab.key}
                  tab={tab}
                  isActive={activeTab === tab.key}
                  onSelect={() => onNavigate(tab.key)}
                />
              ))}
            </div>
          </section>
        ))}
      </div>
    </section>
  );
}

function LogistiqueSidebar({ collapsed, activeTab, mainTabs, onNavigate, onToggle }) {
  const dashboardActive = activeTab === "dashboard" || ["audit", "alertes", "consommation", "couverture"].includes(activeTab);
  const groups = [
    { label: "Pilotage", keys: ["dashboard", "dossiers"] },
    { label: "Stocks", keys: ["articles", "commandes", "details", "mouvements"] },
    { label: "Finances", keys: ["reglements"] },
  ];
  return <aside className={"logistics-sidebar-shell" + (collapsed ? " is-collapsed" : "")}>
    <div className="logistics-sidebar-top">
      <Link to="/" className="logistics-brand-lockup" aria-label="SauverNdeko — Applications">
        <img className="logistics-brand-logo" src="/sauverndeko-logo.jpg" alt="" width="34" height="34" />
        {!collapsed ? <div className="logistics-brand-copy"><strong>SauverNdeko</strong><span>Logistique</span></div> : null}
      </Link>
      <button type="button" className="logistics-sidebar-toggle" onClick={onToggle} aria-label={collapsed ? "Afficher le menu logistique" : "Replier le menu logistique"} title={collapsed ? "Déplier" : "Replier"}><AppIcon name="sidebar" /></button>
    </div>
    <nav className="logistics-sidebar-nav" aria-label="Menu logistique">
      {groups.map((group) => <div key={group.label} className="logistics-nav-group" role="group" aria-label={group.label}>
        {!collapsed ? <span className="logistics-nav-heading">{group.label}</span> : null}
        {group.keys.map((key) => {
          const tab = mainTabs.find((item) => item.key === key);
          if (!tab) return null;
          const active = key === activeTab || (key === "dashboard" && dashboardActive);
          return <button key={key} type="button" className={"logistics-sidebar-link" + (active ? " is-active" : "")} onClick={() => onNavigate(key)} title={tab.label || tab.title} aria-label={tab.label || tab.title} aria-current={active ? "page" : undefined}>
            <span className="logistics-sidebar-icon" aria-hidden="true"><AppIcon name={tab.icon || "apps"} size={18} /></span>
            {!collapsed ? <span className="logistics-sidebar-label">{tab.label || tab.title}</span> : null}
          </button>;
        })}
      </div>)}
    </nav>
    <div className="logistics-app-switcher"><Link to="/referentiels" title="Référentiels communs" aria-label="Référentiels"><span><AppIcon name="tag" /></span>{!collapsed ? <><span>Référentiels</span><AppIcon name="arrow-up-right" /></> : null}</Link><Link to="/" title="Toutes les applications" aria-label="Toutes les applications"><span><AppIcon name="apps" /></span>{!collapsed ? <><span>Applications</span><AppIcon name="arrow-up-right" /></> : null}</Link></div>
  </aside>;
}

function LogistiqueShellHeader({
  activeTabConfig,
  activeTab,
  referencesLoading,
  references,
  selectedCommande,
  onRefresh,
  onShowFkMappings,
  showFkMappingPanel,
  onDashboard,
}) {
  const title = activeTabConfig.label || activeTabConfig.title;
  const subtitle =
    activeTab === "dashboard"
      ? "Vue synthetique du stock, des bons de stock, des mouvements et des reglements."
      : activeTabConfig.description || activeTabConfig.viewLabel;
  const activeViewLabel = activeTabConfig.viewLabel;
  const articleCount = referencesLoading ? "..." : formatCompactCount(references?.articles?.length || 0);
  const factureCount = referencesLoading ? "..." : formatCompactCount(references?.factures?.length || 0);
  const contextualChips = [
    activeViewLabel,
    `${articleCount} articles`,
    `${factureCount} factures`,
    selectedCommande?.CodeCmd ? `Bon de stock cible : ${selectedCommande.CodeCmd}` : "",
  ].filter(Boolean);

  return (
    <section className="logistics-shell-header-card">
      <div className="logistics-shell-header-main">
        <div className="logistics-shell-header-copy">
          <span className="logistics-shell-eyebrow">Module logistique</span>
          <h1>{title}</h1>
          <p>{subtitle}</p>
        </div>

        <div className="logistics-shell-header-side">
          <div className="logistics-shell-header-status">
            <span className="status-pill">{activeTabConfig.accessMode}</span>
            {activeTab !== "dashboard" ? (
              <button type="button" className="secondary-action" onClick={onDashboard}>
                Tableau de bord
              </button>
            ) : null}
          </div>

          <div className="logistics-shell-header-actions">
            <button type="button" className="secondary-action" onClick={onShowFkMappings}>
              {showFkMappingPanel ? "Masquer FK" : "Correspondance FK"}
            </button>
            <button type="button" className="primary-action" onClick={onRefresh}>
              Actualiser
            </button>
          </div>
        </div>
      </div>

      <div className="logistics-shell-chip-row">
        {contextualChips.map((item) => (
          <span key={item} className={`status-pill ${item === activeViewLabel ? "" : "is-muted"}`}>
            {item}
          </span>
        ))}
      </div>
    </section>
  );
}

const TABS = LOGISTIQUE_MODULE_SCHEMA.views;
const TAB_GROUPS = LOGISTIQUE_MODULE_SCHEMA.tabGroups;
const TABLE_FEATURE_CONFIG = LOGISTIQUE_MODULE_SCHEMA.tableFeatures;
const MAIN_TAB_DEFINITIONS = [
  { key: "dashboard", label: "Tableau de bord", icon: "bi-speedometer2" },
  { key: "articles", label: "Articles", icon: "bi-box-seam" },
  { key: "dossiers", label: "Dossiers de suivi", icon: "folder" },
  { key: "commandes", label: "Bons de stock", icon: "bi-receipt" },
  { key: "details", label: "Lignes des bons", icon: "bi-list-ul" },
  { key: "mouvements", label: "Mouvements de stock", icon: "bi-arrow-left-right" },
  { key: "reglements", label: "Factures et règlements", icon: "bi-wallet2" },
];

export default function Logistique() {
  const { user } = useAuth();
  const canEditReferences = user?.Is_Admin === true && user?.permissions?.canWriteData === true;
  const [settingsVersion, setSettingsVersion] = useState(0);
  const [navigation,setNavigation]=useSearchParams();
  const requestedTab=navigation.get("onglet");
  const [activeTab, setActiveTab] = useState(()=>MAIN_TAB_DEFINITIONS.some(tab=>tab.key===requestedTab)?requestedTab:"dashboard");
  useEffect(()=>{if(MAIN_TAB_DEFINITIONS.some(tab=>tab.key===requestedTab))setActiveTab(requestedTab);},[requestedTab]);
  useEffect(() => { window.scrollTo({ top: 0, left: 0 }); }, [activeTab]);
  const [sidebarCollapsed, setSidebarCollapsed] = useState(() => readSidebarCollapsedPreference());
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
  useEffect(()=>{
    if(!refreshKey)return;
    let active=true;
    fetchLogistiqueReferences().then(result=>{if(active&&result?.success)setBaseReferences(result.data);});
    return()=>{active=false;};
  },[refreshKey]);
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
    if (typeof window === "undefined") {
      return;
    }

    window.localStorage.setItem(LOGISTIQUE_SIDEBAR_STORAGE_KEY, String(sidebarCollapsed));
  }, [sidebarCollapsed]);

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
          if (!response?.success) setSharedFkSettingsError(response?.message || "Les réglages n’ont pas pu être chargés.");
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

        setSharedFkSettingsError("Les réglages n’ont pas pu être chargés.");
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
  }, [settingsVersion]);

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

  function handleNavigate(tabKey, options = {}) {
    setNavigation(current=>{const next=new URLSearchParams(current);next.set("onglet",tabKey);if(tabKey!=="dossiers")next.delete("dossier");return next;},{replace:true});
    if (options.create) updateSharedTableState(tabKey, { composerMode: "create" });
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

  function handleOpenCommande(commande) {
    setSelectedCommande(commande);
    setSharedTableState((current) => ({
      ...current,
      commandes: {
        ...current.commandes,
        selectedRow: commande,
      },
    }));
    handleNavigate("commandes");
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

  const visibleSharedFkAuditRows = useMemo(
    () => sharedFkAuditRows.filter(hasLogistiqueAuditChange).slice(0, 4),
    [sharedFkAuditRows]
  );

  async function persistSharedFkSettings(nextLogistiqueOverrides) {
    if (!canEditReferences || savingSharedFkSettings || loadingSharedFkSettings) return false;
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

    const nextOverrides = { ...genericCategoryOverrides };
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
      } else {
        delete nextOverrides[item.sourceKey];
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
    const nextOverrides = { ...genericCategoryOverrides };

    genericMappingStates.forEach((item) => {
      nextDrafts[item.sourceKey] = item.defaultValue;
      if (!item.isLocked) delete nextOverrides[item.sourceKey];
    });

    setGenericCategoryDrafts((current) => ({
      ...current,
      ...nextDrafts,
    }));

    await persistSharedFkSettings(nextOverrides);
  }

  const mainTabs = useMemo(
    () =>
      MAIN_TAB_DEFINITIONS.map((item) => ({
        ...TABS.find((tab) => tab.key === item.key),
        ...item,
      })).filter((item) => item?.key),
    []
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
    <>
      <LogistiqueResponsiveStyles />
      <div className={"logistics-modern logistics-app" + (sidebarCollapsed ? " is-menu-collapsed" : "")}>
        <LogistiqueSidebar
          collapsed={sidebarCollapsed}
          activeTab={activeTab}
          mainTabs={mainTabs}
          activeTabConfig={activeTabConfig}
          onNavigate={handleNavigate}
          onToggle={() => setSidebarCollapsed((current) => !current)}
        />

        <ModuleHeader title="Logistique" />
        <div className="page-shell admin-page-shell logistics-page-shell logistics-shell-layout">
        <section className="admin-workspace logistics-workspace">
          <div className="admin-main-column logistics-main-column">
            {referencesLoading ? <section className="table-empty-state">Chargement des references logistiques...</section> : null}
            {!referencesLoading && referencesError ? <section className="table-empty-state">{referencesError}</section> : null}

            {!referencesLoading && !referencesError ? (
              <div className="logistics-shell-view">
                {activeTabConfig.key !== "dashboard" && activeFkMappings.length > 0 && showFkMappingPanel ? (
                  <ReferenceSettings title={MAIN_TAB_DEFINITIONS.find(tab=>tab.key===activeTab)?.label || activeTabConfig.title} mappings={genericMappingStates} directMappings={activeDirectMappings} references={references} categories={referenceCategories} loading={loadingSharedFkSettings} saving={savingSharedFkSettings} error={sharedFkSettingsError} supportError={genericSupportError} meta={sharedFkSettingsMeta} auditRows={visibleSharedFkAuditRows} auditLoading={loadingSharedFkAudit} auditError={sharedFkAuditError} canEdit={canEditReferences} formatDateTime={formatDisplayDateTime} onClose={()=>setShowFkMappingPanel(false)} onChange={handleGenericCategoryDraftChange} onApply={handleApplyGenericCategoryOverride} onReset={handleResetGenericCategoryOverride} onApplyAll={handleApplyAllGenericCategoryOverrides} onResetAll={handleResetAllFkSettings} onRetry={()=>setSettingsVersion(version=>version+1)} />
                ) : null}

                {activeTab === "dashboard" ? <DashboardLogistique refreshKey={refreshKey} onNavigate={handleNavigate} references={references} /> : null}
                {activeTab === "dossiers" ? <DossiersSuivi references={references} folderKey={navigation.get("dossier") || ""} onSelect={key=>setNavigation(current=>{const next=new URLSearchParams(current);next.set("onglet","dossiers");if(key)next.set("dossier",key);else next.delete("dossier");return next;},{replace:true})} onNavigateRecords={type=>handleNavigate(type==="article"?"articles":type==="facture"?"reglements":"commandes")}/> : null}
                {activeTab === "articles" ? (
                  <Articles
                    references={references}
                    refreshKey={refreshKey}
                    onDataChanged={bumpRefresh}
                    sharedTable={sharedTableFeatures.articles}
                    onToggleFkMappings={() => setShowFkMappingPanel((current) => !current)}
                  />
                ) : null}
                {activeTab === "commandes" ? (
                  <Commandes
                    references={references}
                    refreshKey={refreshKey}
                    onDataChanged={bumpRefresh}
                    onOpenDetails={handleOpenDetails}
                    sharedTable={sharedTableFeatures.commandes}
                    onToggleFkMappings={() => setShowFkMappingPanel((current) => !current)}
                  />
                ) : null}
                {activeTab === "details" ? (
                  <CommandeDetails
                    selectedCommande={selectedCommande}
                    references={references}
                    refreshKey={refreshKey}
                    onDataChanged={bumpRefresh}
                    sharedTable={sharedTableFeatures.details}
                    onToggleFkMappings={() => setShowFkMappingPanel((current) => !current)}
                  />
                ) : null}
                {activeTab === "mouvements" ? (
                  <Mouvements
                    references={references}
                    refreshKey={refreshKey}
                    sharedTable={sharedTableFeatures.mouvements}
                    onToggleFkMappings={() => setShowFkMappingPanel((current) => !current)}
                  />
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
                    onOpenCommande={handleOpenCommande}
                    onToggleFkMappings={() => setShowFkMappingPanel((current) => !current)}
                  />
                ) : null}
              </div>
            ) : null}
          </div>
        </section>
      </div>
      </div>
    </>
  );
}

function formatCompactCount(value) {
  return new Intl.NumberFormat("fr-FR").format(Number(value || 0));
}
