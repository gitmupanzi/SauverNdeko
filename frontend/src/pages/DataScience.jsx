import { useEffect, useId, useMemo, useRef, useState } from "react";
import { useSearchParams } from "react-router-dom";
import ActionButton from "../components/ActionButton";
import AppIcon from "../components/AppIcon";
import ListState from "../components/ListState";
import ModuleSidebar from "../components/ModuleSidebar";
import SearchSelect from "../components/SearchSelect";
import { useAuth } from "../contexts/AuthContext";
import { useEntityScope } from "../contexts/EntityScopeContext";
import { requestJson } from "../services/api";
import { moduleRights, tabRights } from "../services/moduleAccess";
import { SimpleTable } from "./logistique/logistiqueShared";
import DemandSeries, { natureLabel, sourceLabel } from "./datascience/DemandSeries";
import ProvinceMatrix from "./datascience/ProvinceMatrix";
import ResearchScope from "./datascience/ResearchScope";
import { analysisPath, analysisPayload, DEMAND_MEASURES, formatCount, monthLabel, publishedOptions, reportDatePeriod, reportPeriodDates, reportToday, SEARCH_MEASURES, STOCK_MEASURES } from "./datascience/analysisModel";
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

function DashboardSummary({ rows, researchRows, canOpenDemands, canOpenResearch, onNavigate }) {
  const provinces = new Set(rows.flatMap(row => row.territory === null ? [] : [row.territory]));
  const categories = new Set(rows.flatMap(row => row.category === null ? [] : [row.category]));
  const indicators = [
    { label: "Groupes de demandes publiés", value: rows.length, icon: "chart", target: canOpenDemands ? "demandes" : null },
    { label: "Provinces représentées", value: provinces.size, icon: "globe" },
    { label: "Catégories de produits représentées", value: categories.size, icon: "tag" },
  ];
  if (researchRows.length) indicators.push({ label: "Groupes de recherches publiés", value: researchRows.length, icon: "search", target: canOpenResearch ? "recherches" : null });
  return (
    <section className="data-science-panel" aria-label="Synthèse des données publiées">
      <div className="data-science-panel-header">
        <div>
          <h2>Synthèse</h2>
          <p>Couverture des données consultables sur la période.</p>
        </div>
        <div className="data-science-summary-actions">
          {canOpenDemands && <ActionButton icon="arrow-right" onClick={() => onNavigate("demandes")}>Explorer les demandes</ActionButton>}
          {canOpenResearch && <ActionButton icon="arrow-right" onClick={() => onNavigate("recherches")}>Explorer les recherches</ActionButton>}
        </div>
      </div>
      {(rows.length > 0 || researchRows.length > 0) && <dl className="data-science-summary">
        {indicators.filter(indicator => indicator.value > 0).map(({ label, value, icon, target }) => (
          <div key={label} className="data-science-summary-item">
            <dt><AppIcon name={icon} /> {label}</dt>
            <dd>{target
              ? <button type="button" className="data-science-summary-link" aria-label={label + " · " + formatCount(value)} onClick={() => onNavigate(target)}>{formatCount(value)} <AppIcon name="chevron-right" size={14} /></button>
              : formatCount(value)}</dd>
          </div>
        ))}
      </dl>}
    </section>
  );
}

function AnalysisWorkspace({ active, entityId, canOpenDemands, canOpenResearch, onNavigate }) {
  const dashboard = active === DASHBOARD;
  const research = active === "recherches";
  const measures = research ? SEARCH_MEASURES : DEMAND_MEASURES;
  const filtersForView = research ? [...FILTERS.slice(0, 3), CONDITION_FILTER] : FILTERS;
  const prefix = useId();
  const detailHeading = useRef(null);
  const [draft, setDraft] = useState({ debut: "", fin: "" });
  const [period, setPeriod] = useState(null);
  const [attempt, setAttempt] = useState(0);
  const [periodMessage, setPeriodMessage] = useState("");
  const [request, setRequest] = useState({ path: "", payload: null, error: "" });
  const [filters, setFilters] = useState({});
  const [series, setSeries] = useState({});
  const [detail, setDetail] = useState(null);
  const [chart, setChart] = useState("monthly");
  const today = reportToday();
  const path = analysisPath(period, active);
  const current = request.path === path && request.attempt === attempt;
  const loading = !current;
  const data = current ? request.payload : null;
  const rows = useMemo(() => (data?.cellules || []).filter(row => research === (row.nature === "recherche")), [data, research]);
  const researchRows = dashboard && canOpenResearch ? data?.cellules.filter(row => row.nature === "recherche") || [] : [];
  const dashboardShowsResearch = dashboard && !rows.length && researchRows.length > 0;
  const displayedRows = dashboardShowsResearch ? researchRows : rows;
  const activeFilters = filters[active] || {};
  const activeDetail = detail?.view === active ? detail : null;

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
      const error = payload ? "" : result?.status === 403
        ? "Votre compte ne peut pas consulter ces analyses."
        : "Les résultats n’ont pas pu être chargés.";
      setRequest({ path, attempt, payload, error });
      if (payload) setDraft(previous => previous.debut || previous.fin ? previous : reportPeriodDates(payload.periode));
    }
    void load();
    return () => controller.abort();
  }, [path, attempt, entityId]);

  const filtered = rows.filter(row => filtersForView.every(({ key }) =>
    !activeFilters[key] || JSON.stringify(row[key]) === activeFilters[key]));
  const detailRows = activeDetail ? filtered.filter(row => row.mois === activeDetail.mois && row.seriesKey === activeDetail.key) : filtered;
  const columns = [...(research ? SEARCH_COLUMNS : DETAILS_COLUMNS), ...measureColumns(measures), OFFER_COLUMN];
  if (!research && data?.rapprochementDisponible) columns.push(...measureColumns(STOCK_MEASURES));

  function updateDate(field, value) {
    setDraft(previous => ({ ...previous, [field]: value }));
    setPeriodMessage("");
  }

  function submitPeriod(event) {
    event.preventDefault();
    const { period: months, error } = reportDatePeriod(draft, today);
    setPeriodMessage(error);
    if (error) return;
    setPeriod(months);
    setFilters({});
    setSeries({});
    setDetail(null);
  }

  function resetPeriod() {
    setPeriod(null);
    setDraft({ debut: "", fin: "" });
    setPeriodMessage("");
    setFilters({});
    setSeries({});
    setDetail(null);
    setAttempt(value => value + 1);
  }

  function selectMonth(mois, key) {
    setDetail({ view: active, mois, key });
    detailHeading.current?.focus();
  }

  return (
    <>
        <header className="erp-register-heading data-science-heading">
          <div>
            <h1>{dashboard ? "Tableau de bord" : research ? "Recherches déclarées" : "Demandes et besoins"}</h1>
            <p>{dashboard
              ? "Consultez les demandes et l’évolution des besoins déclarés."
              : research ? "Explorez les recherches déclarées par catégorie de produit, terme de maladie et province."
                : "Explorez les besoins signalés après une recherche sans résultat et leur issue déclarée."}</p>
          </div>
        </header>
        <form className="data-science-panel data-science-period" onSubmit={submitPeriod} noValidate>
          <div className="data-science-panel-header">
            <div><h2><AppIcon name="calendar" /> Période d’observation</h2><p id={prefix + "-period-hint"}>Les résultats couvrent les mois civils sélectionnés, sur 12 mois au maximum.</p></div>
          </div>
          <div className="data-science-controls">
            {[["debut", "Du"], ["fin", "Au"]].map(([key, label]) => (
              <label key={key} className="admin-form-field data-science-field">
                <span>{label}</span>
                <input type="date" max={today} required value={draft[key]} onChange={event => updateDate(key, event.target.value)}
                  aria-invalid={Boolean(periodMessage)} aria-describedby={prefix + (periodMessage ? "-period-error" : "-period-hint")} />
              </label>
            ))}
            <ActionButton icon="search" variant="primary" type="submit" disabled={loading}>Afficher</ActionButton>
            <ActionButton icon="reset" onClick={resetPeriod} disabled={loading}>Période par défaut</ActionButton>
          </div>
          {data?.collecteDisponible && <p className="data-science-reading-note data-science-period-applied">
            Mois affichés · {monthLabel(data.periode.debut)}{data.periode.fin !== data.periode.debut && " – " + monthLabel(data.periode.fin)}
          </p>}
          {periodMessage && <p className="data-science-period-error" role="alert" id={prefix + "-period-error"}>{periodMessage}</p>}
        </form>
        <div aria-busy={loading} className="data-science-results">
          {loading ? <ListState title="Chargement des analyses…" loading role="status" /> : null}
          {!loading && request.error ? (
            <ListState title="Analyse indisponible" description={request.error} icon="alert" role="alert"
              action={<ActionButton onClick={() => setAttempt(value => value + 1)} icon="refresh">Réessayer</ActionButton>} />
          ) : null}
          {data && !data.collecteDisponible ? (
            <ListState title="Collecte indisponible" description="Les données de cette analyse ne sont pas accessibles pour le moment." icon="document" />
          ) : null}
          {dashboard && data?.collecteDisponible && <DashboardSummary rows={rows} researchRows={researchRows}
            canOpenDemands={canOpenDemands} canOpenResearch={canOpenResearch} onNavigate={onNavigate} />}
          {dashboardShowsResearch && <DemandSeries key={active} rows={researchRows} period={data.periode}
            measures={SEARCH_MEASURES} selected={series[active]} onSelect={value => setSeries(previous => ({ ...previous, [active]: value }))}
            onMonth={canOpenResearch ? () => onNavigate("recherches") : undefined} />}
          {data?.collecteDisponible && !displayedRows.length ? (
            <ListState title="Aucune donnée publiable pour cette période" description="Essayez une autre période. Les petits groupes sont masqués pour protéger la confidentialité." icon="chart" />
          ) : null}
          {data?.collecteDisponible && rows.length > 0 ? (
            <>
              <section className="data-science-panel">
                <div className="data-science-panel-header">
                  <h2><AppIcon name="search" /> Explorer les données</h2>
                  {Object.values(activeFilters).some(Boolean) && <ActionButton icon="reset" onClick={() => { setFilters(previous => ({ ...previous, [active]: {} })); setDetail(null); }}>Effacer les filtres</ActionButton>}
                </div>
                <div className="data-science-controls data-science-filters">
                  {filtersForView.map(({ key, label, all, getLabel }) => (
                    <label className="data-science-field" key={key} htmlFor={prefix + "-" + key}>
                      <span>{label}</span>
                      <SearchSelect id={prefix + "-" + key} label={label} value={activeFilters[key] || ""} onChange={value => {
                        setFilters(previous => ({ ...previous, [active]: { ...activeFilters, [key]: value } }));
                        setDetail(null);
                      }} options={[{ value: "", label: all }, ...publishedOptions(rows, key, getLabel)]} />
                    </label>
                  ))}
                </div>
              </section>
              <div className="data-science-chart-choice" role="group" aria-label="Affichage de l’analyse">
                <ActionButton icon="chart" variant={chart === "monthly" ? "primary" : "secondary"}
                  aria-pressed={chart === "monthly"} onClick={() => setChart("monthly")}>Évolution mensuelle</ActionButton>
                <ActionButton icon="dashboard" variant={chart === "province" ? "primary" : "secondary"}
                  aria-pressed={chart === "province"} onClick={() => setChart("province")}>Comparaison par province</ActionButton>
              </div>
              {chart === "province" ? (
                <ProvinceMatrix key={active} rows={filtered} period={data.periode} measures={measures} onMonth={selectMonth} />
              ) : (
                <DemandSeries key={active} rows={filtered} period={data.periode} measures={measures} selected={series[active]}
                  onSelect={value => { setSeries(previous => ({ ...previous, [active]: value })); setDetail(null); }} onMonth={selectMonth} />
              )}
              <section className="data-science-panel" aria-labelledby={prefix + "-details"}>
                <div className="data-science-panel-header">
                  <div><h2 ref={detailHeading} tabIndex={-1} id={prefix + "-details"}>Détail par mois et par province</h2>
                    {activeDetail && <p>Mois sélectionné · {monthLabel(activeDetail.mois)}</p>}
                  </div>
                  {activeDetail && <ActionButton icon="reset" onClick={() => setDetail(null)}>Afficher toutes les séries filtrées</ActionButton>}
                </div>
                {detailRows.length ? (
                  <div className="data-science-table">
                    <SimpleTable key={JSON.stringify([active, activeFilters, activeDetail])} tableLabel={research ? "Détail des recherches déclarées" : "Détail des demandes et besoins"}
                      rows={detailRows} columns={columns} getRowId={row => row.key} defaultPinnedColumns={[]}
                      showControls={false} enableSelection={false} defaultRowsPerPage={12} />
                  </div>
                ) : <ListState title="Aucune donnée pour ces filtres" description="Modifiez les critères pour consulter d’autres données publiées." />}
              </section>
            </>
          ) : null}
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
        </div>
    </>
  );
}

export default function DataScience() {
  const { user } = useAuth();
  const scope = useEntityScope();
  const [params, setParams] = useSearchParams();
  const [collapsed, setCollapsed] = useState(false);
  const platformAdmin = user?.moduleAccess?.platformAdmin === true;
  const groups = GROUPS.map(group => ({
    ...group,
    items: group.items.filter(({ key }) =>
      (platformAdmin || !["recherches", "perimetre"].includes(key)) && tabRights(user, MODULE, key).canRead),
  })).filter(group => group.items.length);
  const allowed = new Set(groups.flatMap(group => group.items.map(item => item.key)));
  const tab = params.get("onglet");
  const knownTab = GROUPS.some(group => group.items.some(item => item.key === tab));
  const active = knownTab ? tab : (allowed.has(DASHBOARD) ? DASHBOARD : [...allowed][0]);
  const navigate = key => {
    if (allowed.has(key)) setParams(key === DASHBOARD ? {} : { onglet: key });
  };
  if (!moduleRights(user, MODULE).canRead || !allowed.size) {
    return <main className="data-science-denied"><ListState title="Votre compte ne peut pas consulter Data science" icon="shield" /></main>;
  }
  return (
    <div className={"logistics-modern logistics-app admin-portal data-science-module" + (collapsed ? " is-menu-collapsed" : "")}>
      <ModuleSidebar title="Data science" groups={groups} activeKey={active} onNavigate={navigate}
        collapsed={collapsed} onToggle={() => setCollapsed(value => !value)} storageKey="sauverndeko.data-science.navigation"
        headerProps={{ showEntityScope: active !== "perimetre" }} />
      <main className="admin-main data-science-main">
        {!allowed.has(active)
          ? <ListState title="Vous n’avez pas accès à cet onglet" icon="shield"
            action={<ActionButton icon="arrow-right" onClick={() => navigate([...allowed][0])}>Ouvrir les analyses disponibles</ActionButton>} />
          : active === "perimetre" ? <ResearchScope canManage={tabRights(user, MODULE, "perimetre").canManage} />
            : <AnalysisWorkspace key={scope.scopeKey} active={active} entityId={scope.entityId}
              canOpenDemands={allowed.has("demandes")} canOpenResearch={allowed.has("recherches")} onNavigate={navigate} />}
      </main>
    </div>
  );
}
