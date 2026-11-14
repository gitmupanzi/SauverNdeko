import { useEffect, useMemo, useState } from "react";
import { useSearchParams } from "react-router-dom";
import ActionButton from "../components/ActionButton";
import AppIcon from "../components/AppIcon";
import ListState from "../components/ListState";
import ModuleSidebar from "../components/ModuleSidebar";
import { useAuth } from "../contexts/AuthContext";
import { useEntityScope } from "../contexts/EntityScopeContext";
import { presentedModuleTabs, useModulePresentation } from "../hooks/useModulePresentation";
import { requestJson } from "../services/api";
import { moduleRights, tabRights } from "../services/moduleAccess";
import { SimpleTable } from "./logistique/logistiqueShared";
import { natureLabel, sourceLabel } from "./datascience/DemandSeries";
import AnalysisRegister from "./datascience/AnalysisRegister";
import ResearchScope from "./datascience/ResearchScope";
import ScienceDashboard from "./datascience/ScienceDashboard";
import { analysisPath, analysisPayload, DEMAND_MEASURES, formatCount, monthLabel, reportDatePeriod, reportPeriodDates, reportToday, SEARCH_MEASURES, STOCK_MEASURES } from "./datascience/analysisModel";
import "./logistique/LogistiqueModern.css";
import "./admin/AdminPortal.css";
import "./datascience/DataScience.css";

const MODULE = "data-science";
const DASHBOARD = "tableau-de-bord";
const GROUPS = [{ key: "pilotage", label: "Pilotage", items: [
  { key: DASHBOARD, label: "Tableau de bord", icon: "dashboard" },
] }, { key: "analyses", label: "Analyses", items: [
  { key: "demandes", label: "Demandes et besoins", icon: "chart" },
  { key: "recherches", label: "Recherches déclarées", icon: "search" },
] }, { key: "etude", label: "Étude", items: [
  { key: "perimetre", label: "Périmètre de l’étude", icon: "settings" },
] }];
const FILTERS = [
  { key: "category", label: "Catégorie de produit", all: "Toutes les catégories", getLabel: row => row.produitLibelle },
  { key: "territory", label: "Province", all: "Toutes les provinces", getLabel: row => row.territoireLibelle },
  { key: "source", label: "Annuaire", all: "Tous les annuaires", getLabel: sourceLabel },
  { key: "nature", label: "Nature du signal", all: "Toutes les natures", getLabel: natureLabel },
];
const CONDITION_FILTER = { key: "condition", label: "Terme de maladie", all: "Tous les termes", getLabel: row => row.pathologieLibelle };
const RESEARCH_FILTERS = [...FILTERS.slice(0, 3), CONDITION_FILTER];
const DETAILS_COLUMNS = [
  { key: "mois", label: "Mois", width: 125, render: row => monthLabel(row.mois) },
  { key: "produitLibelle", label: "Catégorie de produit", width: 180 },
  { key: "territoireLibelle", label: "Province", width: 170 },
  { key: "source", label: "Annuaire", width: 125, render: sourceLabel },
  { key: "nature", label: "Nature du signal", width: 175, render: natureLabel },
];

const SEARCH_COLUMNS = [
  ...DETAILS_COLUMNS.slice(0, 2),
  { key: "pathologieLibelle", label: "Terme de maladie", width: 175 },
  ...DETAILS_COLUMNS.slice(2, 4),
];

const OFFER_COLUMN = {
  key: "offrePubliee", label: "Offre au catalogue", width: 155,
  render: row => row.offrePubliee === null ? "—" : row.offrePubliee ? "Oui" : "Non",
};

function measureColumns(measures) {
  return measures.map(({ key, label }) => ({
    key, label, width: 142, align: "right",
    render: row => row[key] === null ? <span aria-label="Valeur indisponible">—</span> : formatCount(row[key]),
  }));
}

function renderDashboardDetails({ rows, measure }, detail) {
  const includesResearch = rows.some(row => row.nature === "recherche");
  const includesDemands = rows.some(row => row.nature !== "recherche");
  const dimensions = includesResearch
    ? [...SEARCH_COLUMNS, ...(includesDemands ? DETAILS_COLUMNS.slice(-1) : [])] : DETAILS_COLUMNS;
  const measures = [
    ...(includesDemands ? DEMAND_MEASURES : []),
    ...(includesResearch ? SEARCH_MEASURES : []),
  ].filter(item => !measure || item.key === measure);
  return <div className="data-science-table">
    <SimpleTable key={detail.key || detail.mois} tableLabel={detail.label} rows={rows}
      columns={[...dimensions, ...measureColumns(measures)]} getRowId={row => row.key} defaultPinnedColumns={[]}
      showControls={false} enableSelection={false} defaultRowsPerPage={12} />
  </div>;
}

function AnalysisWorkspace({ active, title, entityId, canOpenDemands, canOpenResearch, showResearch, presentation, onNavigate }) {
  const dashboard = active === DASHBOARD;
  const research = active === "recherches";
  const measures = research ? SEARCH_MEASURES : DEMAND_MEASURES;
  const [draft, setDraft] = useState({ debut: "", fin: "" });
  const [period, setPeriod] = useState(null);
  const [attempt, setAttempt] = useState(0);
  const [periodMessage, setPeriodMessage] = useState("");
  const [request, setRequest] = useState({ path: "", payload: null, error: "" });
  const today = reportToday();
  const path = analysisPath(period, active);
  const current = request.path === path && request.attempt === attempt;
  const loading = !current;
  const data = current ? request.payload : null;
  const rows = useMemo(() => (data?.cellules || []).filter(row => research === (row.nature === "recherche")), [data, research]);

  useEffect(() => {
    const controller = new AbortController();
    async function load() {
      let result;
      try {
        result = await requestJson(path, { requiresAuth: true, signal: controller.signal });
      } catch {
        result = null;
      }
      if (controller.signal.aborted) return;
      const parsed = result?.success ? analysisPayload(result.data) : null;
      const payload = parsed && (
        entityId ? parsed.perimetre?.type === "entreprise" && String(parsed.perimetre.entrepriseId) === String(entityId)
          : !parsed.perimetre || parsed.perimetre.type === "global"
      ) ? parsed : null;
      const error = payload ? "" : {
        403: "Votre compte ne peut pas consulter ces analyses.",
        422: "Réduisez la période pour consulter les résultats.",
      }[result?.status] || "Les résultats n’ont pas pu être chargés.";
      setRequest({ path, attempt, payload, error });
      if (payload) setDraft(previous => previous.debut || previous.fin ? previous : reportPeriodDates(payload.periode));
    }
    void load();
    return () => controller.abort();
  }, [path, attempt, entityId]);

  const columns = [...(research ? SEARCH_COLUMNS : DETAILS_COLUMNS), ...measureColumns(measures), OFFER_COLUMN];
  if (!research && data?.rapprochementDisponible) columns.push(...measureColumns(STOCK_MEASURES));

  function updateDate(field, value) {
    setDraft(previous => ({ ...previous, [field]: value }));
    setPeriodMessage("");
  }

  function submitPeriod() {
    const { period: months, error } = reportDatePeriod(draft, today);
    setPeriodMessage(error);
    if (error) return false;
    if (months.debut !== data?.periode.debut || months.fin !== data?.periode.fin) setPeriod(months);
    return true;
  }

  function updateDates(dates) {
    setDraft(dates);
    setPeriodMessage("");
  }

  function resetPeriod() {
    setPeriod(null);
    setDraft({ debut: "", fin: "" });
    setPeriodMessage("");
    setAttempt(value => value + 1);
  }

  const feedback = <>
    {loading && <ListState title="Chargement des analyses…" loading role="status" />}
    {!loading && request.error && (
      <ListState title="Analyse indisponible" description={request.error} icon="alert" role="alert"
        action={<ActionButton onClick={() => setAttempt(value => value + 1)} icon="refresh">Réessayer</ActionButton>} />
    )}
    {data && !data.collecteDisponible && (
      <ListState title="Collecte indisponible" description="Les données de cette analyse ne sont pas accessibles pour le moment." icon="document" />
    )}
  </>;

  if (dashboard) {
    return <ScienceDashboard title={title} data={data} loading={loading} dateDraft={draft} onDate={updateDate}
      onDates={updateDates} today={today} periodMessage={periodMessage}
      onSubmitPeriod={submitPeriod} onResetPeriod={resetPeriod} canOpenDemands={canOpenDemands}
      canOpenResearch={canOpenResearch} showResearch={showResearch} onNavigate={onNavigate}
      hiddenBlocks={presentation?.hiddenDashboardBlocks} canConfigurePresentation={presentation?.canManage === true}
      renderDetails={renderDashboardDetails}>{feedback}</ScienceDashboard>;
  }

  return (
    <>
      <AnalysisRegister key={active} title={title}
        subtitle={research ? "Recherches par catégorie de produit, terme de maladie et province."
          : "Besoins signalés et issue déclarée des demandes."}
        rows={rows} data={data} columns={columns} measures={measures} filterFields={research ? RESEARCH_FILTERS : FILTERS}
        loading={loading} feedback={feedback} dateDraft={draft} today={today} customPeriod={Boolean(period)}
        periodMessage={periodMessage} onDate={updateDate} onDates={updateDates}
        onApplyPeriod={submitPeriod} onResetPeriod={resetPeriod} />
      {research && data?.collecteDisponible && !data.associationMaladieProduitDisponible &&
        <p className="data-science-reading-note"><AppIcon name="link" /><span>Aucune correspondance maladie–produit validée n’est disponible.</span></p>}
      {data?.collecteDisponible && (
        <details className="data-science-panel data-science-method">
          <summary>Définitions et limites</summary>
          <p>{research
            ? "Les recherches décrivent un usage déclaré de la plateforme. Un terme recherché ne constitue pas un diagnostic."
            : "Les demandes sont regroupées par mois de création. Les résultats de traitement sont déclarés."}</p>
          <p>Chaque cellule correspond à une catégorie ou un terme, une province, un mois, un annuaire et une nature de signal. Les graphiques reprennent les effectifs publiés pour ces cellules.</p>
          <p>{data.seuilConfidentialite
            ? "Le seuil de confidentialité annoncé est de " + formatCount(data.seuilConfidentialite) + " contributeurs distincts. "
            : ""}Une cellule non publiée et une valeur indisponible sont distinctes d’un zéro publié.</p>
        </details>
      )}
    </>
  );
}

export default function DataScience() {
  const { user } = useAuth();
  const scope = useEntityScope();
  const [params, setParams] = useSearchParams();
  const [collapsed, setCollapsed] = useState(false);
  const platformAdmin = user?.moduleAccess?.platformAdmin === true;
  const moduleAllowed = moduleRights(user, MODULE).canRead;
  const { presentation, loading: loadingPresentation, error: presentationError, retry } = useModulePresentation(MODULE,
    { ...scope, entityId: moduleAllowed ? scope.entityId : null });
  const allowedGroups = GROUPS.map(group => ({
    ...group,
    items: group.items.filter(({ key }) =>
      (platformAdmin || !["recherches", "perimetre"].includes(key)) && tabRights(user, MODULE, key).canRead),
  })).filter(group => group.items.length);
  const tabs = allowedGroups.flatMap(group => group.items);
  const allowed = new Set(tabs.map(item => item.key));
  const groups = loadingPresentation ? [] : allowedGroups.map(group => ({
    ...group, items: presentedModuleTabs(group.items, presentation),
  })).filter(group => group.items.length);
  const visibleTabs = groups.flatMap(group => group.items);
  const requested = params.get("onglet");
  const knownTab = GROUPS.some(group => group.items.some(item => item.key === requested));
  const active = knownTab ? requested : visibleTabs[0]?.key;
  const title = presentation?.tabLabels?.[active] || tabs.find(item => item.key === active)?.label;
  const navigate = key => {
    if (allowed.has(key)) setParams(key === DASHBOARD ? {} : { onglet: key });
  };
  if (!moduleAllowed || !allowed.size) {
    return <main className="data-science-denied"><ListState title="Votre compte ne peut pas consulter Data science" icon="shield" /></main>;
  }
  return (
    <div className={"logistics-modern logistics-app admin-portal data-science-module" + (collapsed ? " is-menu-collapsed" : "")}>
      <ModuleSidebar title="Data science" groups={groups} activeKey={active} onNavigate={navigate}
        collapsed={collapsed} onToggle={() => setCollapsed(value => !value)} storageKey="sauverndeko.data-science.navigation"
        headerProps={{ showEntityScope: active !== "perimetre" }} />
      <main className="admin-main data-science-main">
        {presentationError && <div className="admin-error" role="status">
          <span>Les réglages d’affichage sont indisponibles. La présentation standard est utilisée.</span>
          <ActionButton icon="refresh" onClick={retry}>Réessayer</ActionButton>
        </div>}
        {loadingPresentation ? <ListState title="Chargement de la présentation…" loading role="status" />
          : !active ? <ListState title="Aucun onglet affiché dans le menu" icon="sidebar" />
          : !allowed.has(active)
          ? <ListState title="Vous n’avez pas accès à cet onglet" icon="shield"
            action={visibleTabs.length ? <ActionButton icon="arrow-right" onClick={() => navigate(visibleTabs[0].key)}>Ouvrir les analyses disponibles</ActionButton> : null} />
          : active === "perimetre" ? <ResearchScope key={scope.scopeKey} title={title} canManage={tabRights(user, MODULE, "perimetre").canManage} />
            : <AnalysisWorkspace key={scope.scopeKey} active={active} title={title} entityId={scope.entityId} presentation={presentation}
              canOpenDemands={visibleTabs.some(item => item.key === "demandes")} canOpenResearch={visibleTabs.some(item => item.key === "recherches")}
              showResearch={allowed.has("recherches") && !scope.entityId} onNavigate={navigate} />}
      </main>
    </div>
  );
}
