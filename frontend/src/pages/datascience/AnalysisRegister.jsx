import { useEffect, useId, useMemo, useRef, useState } from "react";
import ActionButton from "../../components/ActionButton";
import AppIcon from "../../components/AppIcon";
import DataTableToolbar from "../../components/DataTableToolbar";
import RegisterSettingsButton from "../../components/RegisterSettingsButton";
import RegisterSurface from "../../components/RegisterSurface";
import SearchSelect from "../../components/SearchSelect";
import { SimpleTable } from "../logistique/logistiqueShared";
import DemandSeries from "./DemandSeries";
import ProvinceMatrix from "./ProvinceMatrix";
import {
  matchesAnalysisSearch, monthLabel, publishedOptions, recentReportDates, reportPeriodDates, REPORT_PERIODS,
} from "./analysisModel";

const EMPTY = { q: "", filters: {} };
const rowId = row => row.key;

export default function AnalysisRegister({
  title, subtitle, rows, data, columns, measures, filterFields, loading, feedback,
  dateDraft, today, customPeriod, periodMessage, onDate, onDates, onApplyPeriod, onResetPeriod,
}) {
  const id = useId();
  const settingsButton = useRef(null);
  const detailHeading = useRef(null);
  const chartTrigger = useRef(null);
  const [draft, setDraft] = useState(EMPTY);
  const [criteria, setCriteria] = useState(EMPTY);
  const [periodMode, setPeriodMode] = useState(customPeriod ? "custom" : "12");
  const [appliedDates, setAppliedDates] = useState(null);
  const [openFilters, setOpenFilters] = useState(false);
  const [settings, setSettings] = useState(false);
  const [take, setTake] = useState(25);
  const [page, setPage] = useState(1);
  const [density, setDensity] = useState("compact");
  const [chart, setChart] = useState("monthly");
  const [series, setSeries] = useState(null);
  const [detail, setDetail] = useState(null);
  const period = data?.periode;
  const standardDates = period && reportPeriodDates(period, today);
  const publishedDates = appliedDates || standardDates;
  const pendingDates = Boolean(publishedDates &&
    (dateDraft.debut !== publishedDates.debut || dateDraft.fin !== publishedDates.fin));
  const pending = JSON.stringify(draft) !== JSON.stringify(criteria) || pendingDates;
  const hasCustomDates = Boolean(customPeriod || (appliedDates && standardDates &&
    (appliedDates.debut !== standardDates.debut || appliedDates.fin !== standardDates.fin)));
  const activeFilters = Object.keys(criteria.filters).length + Number(Boolean(criteria.q)) + Number(hasCustomDates);
  const filtered = useMemo(() => {
    const selections = Object.entries(criteria.filters);
    return rows.filter(row => selections.every(([key, item]) => JSON.stringify(row[key]) === item.value)
      && matchesAnalysisSearch(filterFields.map(field => field.getLabel(row)), criteria.q));
  }, [rows, criteria, filterFields]);
  const detailRows = detail ? filtered.filter(row => row.mois === detail.mois && row.seriesKey === detail.seriesKey) : filtered;

  useEffect(() => {
    if (detail) detailHeading.current?.focus();
  }, [detail]);

  function apply() {
    if (!onApplyPeriod()) {
      setOpenFilters(true);
      return;
    }
    const next = { ...draft, q: draft.q.trim() };
    setDraft(next);
    setCriteria(next);
    setAppliedDates(dateDraft);
    setDetail(null);
    setPage(1);
  }

  function reset() {
    setDraft(EMPTY);
    setCriteria(EMPTY);
    setAppliedDates(null);
    setPeriodMode("12");
    setSeries(null);
    setDetail(null);
    setPage(1);
    onResetPeriod();
  }

  function removeFilter(key) {
    function remove(previous) {
      if (key === "q") return { ...previous, q: "" };
      const filters = { ...previous.filters };
      delete filters[key];
      return { ...previous, filters };
    }
    setDraft(remove);
    setCriteria(remove);
    setDetail(null);
    setPage(1);
  }

  function selectMonth(mois, seriesKey, trigger) {
    chartTrigger.current = trigger;
    setDetail({ mois, seriesKey });
    setPage(1);
  }

  const chips = [
    ...(criteria.q ? [{ key: "q", label: "Recherche · " + criteria.q }] : []),
    ...Object.entries(criteria.filters).map(([key, item]) => ({ key, label: item.label })),
  ];
  const toolbar = <>
    <DataTableToolbar showSettings={false} search={draft.q} setSearch={q => setDraft(current => ({ ...current, q }))}
      onApply={apply} onReset={reset} pending={pending} take={take} onTake={value => { setTake(value); setPage(1); }}
      filtersOpen={openFilters} toggleFilters={() => setOpenFilters(value => !value)} filterControlsId={id + "-filters"}
      activeFilters={activeFilters} density={density} toggleDensity={() => setDensity(value => value === "airy" ? "compact" : "airy")}
      loading={loading} placeholder={filterFields.some(field => field.key === "condition")
        ? "Rechercher une catégorie, un terme de maladie ou une province…"
        : "Rechercher une catégorie, une province ou un annuaire…"} />
    {openFilters && <form className="erp-register-filters" id={id + "-filters"} noValidate
      onSubmit={event => { event.preventDefault(); apply(); }}>
      <div className="erp-register-filter-grid">
        <label><span>Période</span>
          <SearchSelect label="Période" value={periodMode} options={REPORT_PERIODS} onChange={value => {
            setPeriodMode(value);
            if (value !== "custom") onDates(recentReportDates(Number(value), today));
          }} />
        </label>
        {[["debut", "Du"], ["fin", "Au"]].map(([key, label]) => (
          <label key={key}><span>{label}</span>
            <input type="date" max={today} required value={dateDraft[key]} onChange={event => {
              onDate(key, event.target.value);
              setPeriodMode("custom");
            }} aria-invalid={Boolean(periodMessage)} aria-describedby={id + (periodMessage ? "-error" : "-hint")} />
          </label>
        ))}
        {filterFields.map(({ key, label, all, getLabel }) => {
          const selected = draft.filters[key];
          const options = publishedOptions(key === "condition" ? rows.filter(row => row.condition !== null) : rows, key, getLabel);
          if (selected && !options.some(option => option.value === selected.value)) options.push(selected);
          return (
            <label key={key} htmlFor={id + "-" + key}><span>{label}</span>
              <SearchSelect id={id + "-" + key} label={label} value={selected?.value || ""} options={[{ value: "", label: all }, ...options]} onChange={value => {
                const option = options.find(item => item.value === value);
                setDraft(previous => {
                  const filters = { ...previous.filters };
                  if (option) filters[key] = option;
                  else delete filters[key];
                  return { ...previous, filters };
                });
              }} />
            </label>
          );
        })}
      </div>
      <p className="erp-register-hint" id={id + "-hint"}>Les résultats couvrent jusqu’à 12 mois civils.</p>
      {periodMessage && <p className="erp-table-error" id={id + "-error"} role="alert">{periodMessage}</p>}
      <div className="erp-register-filters-footer"><ActionButton variant="primary" type="submit" disabled={loading}>Appliquer les filtres</ActionButton></div>
    </form>}
    {period && <p className="data-science-reading-note data-science-register-period">
      Mois affichés · {monthLabel(period.debut)}{period.fin !== period.debut && " – " + monthLabel(period.fin)}
    </p>}
    {chips.length > 0 && <div className="erp-register-chips" aria-label="Critères appliqués">
      {chips.map(({ key, label }) => <span className="erp-register-chip" key={key}>{label}
        <button type="button" aria-label={"Retirer " + label} onClick={() => removeFilter(key)}><AppIcon name="close" size={13} /></button>
      </span>)}
    </div>}
  </>;

  return <>
    <RegisterSurface title={title} subtitle={subtitle} actions={
      <RegisterSettingsButton buttonRef={settingsButton} expanded={settings} onTableSettings={() => setSettings(true)} />
    }>
      <div className="erp-register-table erp-results" data-density={density} aria-busy={loading}>
        {feedback}
        <h2 className={detail ? "data-science-register-detail" : "erp-sr-only"} ref={detailHeading} tabIndex={-1}>
          {detail ? "Détail · " + monthLabel(detail.mois) : "Détail par mois et par province"}
        </h2>
        {detail && <ActionButton className="data-science-register-detail" icon="reset" onClick={() => {
          setDetail(null);
          setPage(1);
          chartTrigger.current?.focus();
        }}>Afficher toutes les séries filtrées</ActionButton>}
        <SimpleTable rows={detailRows} columns={columns} tableLabel={title} getRowId={rowId}
          defaultPinnedColumns={[]} enableSelection={false} toolbar={toolbar} loading={loading}
          rowsPerPage={take} page={page} onPageChange={setPage}
          columnsPanelOpen={settings} columnsAnchorRef={settingsButton} onColumnsPanelClose={() => setSettings(false)}
          emptyMessage={data?.collecteDisponible ? (rows.length ? "Aucune donnée pour ces filtres."
            : "Aucune donnée publiable pour cette période.") : "Les résultats sont indisponibles."} />
      </div>
    </RegisterSurface>
    {period && filtered.length > 0 && <>
      <div className="data-science-chart-choice" role="group" aria-label="Affichage de l’analyse">
        <ActionButton icon="chart" variant={chart === "monthly" ? "primary" : "secondary"}
          aria-pressed={chart === "monthly"} onClick={() => setChart("monthly")}>Évolution mensuelle</ActionButton>
        <ActionButton icon="dashboard" variant={chart === "province" ? "primary" : "secondary"}
          aria-pressed={chart === "province"} onClick={() => setChart("province")}>Comparaison par province</ActionButton>
      </div>
      {chart === "province" ? <ProvinceMatrix rows={filtered} period={period} measures={measures} onMonth={selectMonth} />
        : <DemandSeries rows={filtered} period={period} measures={measures} selected={series}
          onSelect={value => { setSeries(value); setDetail(null); setPage(1); }} onMonth={selectMonth} />}
    </>}
  </>;
}
