import { useEffect, useId, useMemo, useRef, useState } from "react";
import { Link } from "react-router-dom";
import ActionButton from "../../components/ActionButton";
import AppIcon from "../../components/AppIcon";
import ListState from "../../components/ListState";
import SearchSelect from "../../components/SearchSelect";
import DashboardIndicators from "./DashboardIndicators";
import DashboardTrend from "./DashboardTrend";
import { dashboardAnalysis } from "./dashboardModel";
import { matchesAnalysisSearch, monthLabel, publishedOptions, recentReportDates, REPORT_PERIODS } from "./analysisModel";
import { natureLabel, sourceLabel } from "./DemandSeries";

const DIMENSIONS = [
  ["territory", "Province", "Toutes les provinces", row => row.territoireLibelle],
  ["category", "Catégorie de produit", "Toutes les catégories", row => row.produitLibelle],
  ["source", "Annuaire", "Tous les annuaires", sourceLabel],
  ["nature", "Nature du signal", "Toutes les natures", natureLabel],
  ["condition", "Terme de maladie", "Tous les termes", row => row.pathologieLibelle],
];

function choices(rows, key, label, selected) {
  const values = publishedOptions(key === "condition" ? rows.filter(row => row.condition !== null) : rows, key, label);
  return selected && !values.some(item => item.value === selected.value) ? [...values, selected] : values;
}

export default function ScienceDashboard({
  data, loading, dateDraft, onDate, onDates, today, periodMessage, onSubmitPeriod, onResetPeriod,
  title = "Tableau de bord", canOpenDemands, canOpenResearch, showResearch, onNavigate, children, renderDetails,
  hiddenBlocks, canConfigurePresentation,
}) {
  const id = useId();
  const detailHeading = useRef(null);
  const trigger = useRef(null);
  const searchInput = useRef(null);
  const [periodMode, setPeriodMode] = useState("12");
  const [draft, setDraft] = useState({ q: "", choices: {} });
  const [criteria, setCriteria] = useState({ q: "", choices: {} });
  const [advanced, setAdvanced] = useState(false);
  const [detail, setDetail] = useState(null);
  const visible = useMemo(() => (data?.cellules || []).filter(row => showResearch || row.nature !== "recherche"), [data, showResearch]);
  const filtered = useMemo(() => {
    const selected = Object.entries(criteria.choices);
    return visible.filter(row => selected.every(([key, option]) => JSON.stringify(row[key]) === option.value)
      && matchesAnalysisSearch([row.territoireLibelle, row.produitLibelle, row.condition !== null && row.pathologieLibelle,
        sourceLabel(row), natureLabel(row)], criteria.q));
  }, [visible, criteria]);
  const { groups, points, populations } = useMemo(() => dashboardAnalysis(filtered, data?.periode, showResearch), [filtered, data, showResearch]);
  const displayedGroups = groups.filter(group => !hiddenBlocks?.includes(group.key));
  const trendVisible = !hiddenBlocks?.includes("evolution");
  const filters = DIMENSIONS.filter(([key]) => key !== "condition" || showResearch);
  const filterCount = Object.keys(criteria.choices).length;
  const activeLabels = [criteria.q.trim(), ...filters.flatMap(([key, label]) =>
    criteria.choices[key] ? [label + " · " + criteria.choices[key].label] : [])].filter(Boolean);
  const population = detail?.mois ? { rows: filtered.filter(row => row.mois === detail.mois) } : populations.get(detail?.key);

  useEffect(() => {
    if (!detail) return;
    detailHeading.current?.focus();
  }, [detail]);

  function submit(event) {
    event.preventDefault();
    if (!onSubmitPeriod()) return;
    setCriteria(draft);
    setDetail(null);
  }

  function reset() {
    const empty = { q: "", choices: {} };
    setPeriodMode("12");
    setDraft(empty);
    setCriteria(empty);
    setDetail(null);
    onResetPeriod();
  }

  function selectFilter(key, value, options) {
    setDraft(previous => {
      const next = { ...previous.choices };
      const option = options.find(item => item.value === value);
      if (option) next[key] = option;
      else delete next[key];
      return { ...previous, choices: next };
    });
  }

  function openDetail(next, source) {
    trigger.current = source;
    setDetail(next);
  }

  function closeDetail() {
    setDetail(null);
    if (trigger.current?.getClientRects().length) trigger.current.focus();
    else searchInput.current?.focus();
  }

  return (
    <div className="erp-dashboard data-science-dashboard">
      <header className="erp-register-heading data-science-heading">
        <div>
          <h1>{title}</h1>
          <p>Demandes, recherches et couverture des données publiées.</p>
        </div>
        <div className="data-science-summary-actions">
          {canConfigurePresentation && <Link className="ui-action is-secondary" to="/parametres?onglet=presentation&module=data-science">
            <AppIcon name="settings" /> Paramètres d’affichage
          </Link>}
          {canOpenDemands && <ActionButton icon="arrow-right" onClick={() => onNavigate("demandes")}>Explorer les demandes</ActionButton>}
          {canOpenResearch && <ActionButton icon="arrow-right" onClick={() => onNavigate("recherches")}>Explorer les recherches</ActionButton>}
        </div>
      </header>
      <form className="data-science-dashboard-form" aria-label="Filtres du tableau de bord" onSubmit={submit} noValidate>
        <div className="erp-dashboard-filters data-science-period">
          <label className="admin-form-field erp-dashboard-query">
            <span>Recherche</span>
            <span className="erp-dashboard-search"><AppIcon name="search" />
              <input ref={searchInput} type="search" placeholder="Catégorie, province, annuaire…" value={draft.q}
                onChange={event => setDraft(previous => ({ ...previous, q: event.target.value }))} />
            </span>
          </label>
          <label className="admin-form-field erp-dashboard-period" htmlFor={id + "-period"}>
            <span>Période</span>
            <SearchSelect id={id + "-period"} label="Période" value={periodMode} options={REPORT_PERIODS} onChange={value => {
              setPeriodMode(value);
              if (value !== "custom") onDates(recentReportDates(Number(value), today));
            }} />
          </label>
          {[["debut", "Du"], ["fin", "Au"]].map(([key, label]) => (
            <label className="admin-form-field" key={key}>
              <span>{label}</span>
              <input type="date" max={today} required value={dateDraft[key]} onChange={event => {
                setPeriodMode("custom");
                onDate(key, event.target.value);
              }} aria-invalid={Boolean(periodMessage)} aria-describedby={id + (periodMessage ? "-error" : "-hint")} />
            </label>
          ))}
          <ActionButton icon="search" type="submit" variant="primary" disabled={loading}>Rechercher</ActionButton>
          <ActionButton icon="filter" aria-expanded={advanced} aria-controls={id + "-filters"}
            onClick={() => setAdvanced(value => !value)}>Filtrer{filterCount > 0 ? " (" + filterCount + ")" : ""}</ActionButton>
          <ActionButton icon="reset" onClick={reset} disabled={loading}>Réinitialiser</ActionButton>
          <div className="data-science-controls data-science-filters data-science-dashboard-dimensions" id={id + "-filters"} hidden={!advanced}>
            {filters.map(([key, label, all, getLabel]) => {
              const selected = draft.choices[key];
              const options = choices(visible, key, getLabel, selected);
              return (
                <label className="admin-form-field" htmlFor={id + "-" + key} key={key}>
                  <span>{label}</span>
                  <SearchSelect id={id + "-" + key} label={label} value={selected?.value || ""}
                    options={[{ value: "", label: all }, ...options]} onChange={value => selectFilter(key, value, options)} />
                </label>
              );
            })}
          </div>
        </div>
        <p id={id + "-hint"} className="data-science-reading-note">
          {data ? "Mois affichés · " + monthLabel(data.periode.debut) + (data.periode.fin !== data.periode.debut ? " – " + monthLabel(data.periode.fin) : "") + " · " : ""}
          Jusqu’à 12 mois civils.
        </p>
        {periodMessage && <p id={id + "-error"} className="data-science-period-error" role="alert">{periodMessage}</p>}
        {activeLabels.length > 0 && <ul className="data-science-applied-filters" aria-label="Critères appliqués">
          {activeLabels.map((label, index) => <li key={index}>{label}</li>)}
        </ul>}
      </form>
      <div className="data-science-results" aria-busy={loading}>
        {children}
        {data?.collecteDisponible && (
          <>
            {(displayedGroups.length > 0 || trendVisible) &&
              <p className="data-science-reading-note">Les résultats couvrent les groupes publiés.</p>}
            <DashboardIndicators groups={displayedGroups} activeMetric={detail} detailsId={id + "-detail"}
              onMetric={(groupKey, metric, source) => openDetail({ groupKey, key: metric.key, label: metric.label }, source)} />
            {filtered.length > 0 && trendVisible && (
              <DashboardTrend points={points} showResearch={points.some(point => point.recherches !== null)}
                detailsId={detail ? id + "-detail" : undefined}
                onMonth={(mois, source) => openDetail({ mois, label: monthLabel(mois) }, source)} />
            )}
            {!filtered.length && (displayedGroups.length > 0 || trendVisible) && (
              <ListState title={visible.length ? "Aucune donnée pour ces critères" : "Aucune donnée publiable pour cette période"}
                description={visible.length ? "Modifiez les filtres pour élargir les résultats." : "Les groupes sous le seuil de confidentialité sont masqués."}
                icon="chart" />
            )}
            {detail && population && <section className="data-science-panel data-science-dashboard-detail" id={id + "-detail"} aria-labelledby={id + "-detail-title"}>
              <div className="data-science-panel-header">
                <h2 id={id + "-detail-title"} ref={detailHeading} tabIndex={-1}>Détail · {detail.label}</h2>
                <ActionButton icon="arrow-up" onClick={closeDetail}>Revenir {detail.mois ? "au graphique" : "à l’indicateur"}</ActionButton>
              </div>
              {renderDetails(population, detail)}
            </section>}
            <details className="data-science-panel data-science-method">
              <summary>Définitions et limites</summary>
              <p>Les volumes additionnent les événements des groupes publiés. La couverture compte les provinces, catégories ou termes distincts de ces groupes.</p>
              <p>Un tiret indique une valeur indisponible. Les ventilations restent masquées lorsqu’un des groupes retenus ne peut pas les publier.</p>
              {showResearch && <p>Les termes de maladie représentent les sujets recherchés volontairement par les participants.</p>}
            </details>
          </>
        )}
      </div>
    </div>
  );
}
