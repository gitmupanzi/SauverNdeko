import { useEffect, useId, useRef, useState } from "react";
import ActionButton from "../../components/ActionButton";
import AppIcon from "../../components/AppIcon";
import DataTableToolbar from "../../components/DataTableToolbar";
import RecordEditorFrame from "../../components/RecordEditorFrame";
import RegisterSettingsButton from "../../components/RegisterSettingsButton";
import RegisterSurface from "../../components/RegisterSurface";
import SearchSelect from "../../components/SearchSelect";
import { requestJson } from "../../services/api";
import { formatDate, SimpleTable } from "../logistique/logistiqueShared";
import { matchesAnalysisSearch } from "./analysisModel";

const PATH = "/api/data-science/perimetre";
const EMPTY_FILTER = { q: "", state: "" };
const STATES = [
  { value: "", label: "Tous les états" },
  { value: "active", label: "Active" },
  { value: "inactive", label: "Désactivée" },
];

function participation(row) {
  return row.debuteLe ? STATES[1] : STATES[2];
}

function ParticipationStatus({ row }) {
  return <span className={"erp-status " + (row.debuteLe ? "is-success" : "is-neutral")}>{participation(row).label}</span>;
}

export default function ResearchScope({ canManage, title = "Périmètre de l’étude" }) {
  const id = useId();
  const settingsButton = useRef(null);
  const [rows, setRows] = useState([]);
  const [draft, setDraft] = useState(EMPTY_FILTER);
  const [criteria, setCriteria] = useState(EMPTY_FILTER);
  const [take, setTake] = useState(25);
  const [page, setPage] = useState(1);
  const [density, setDensity] = useState("compact");
  const [filtersOpen, setFiltersOpen] = useState(false);
  const [settingsOpen, setSettingsOpen] = useState(false);
  const [selectedId, setSelectedId] = useState(null);
  const [refresh, setRefresh] = useState(0);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState("");
  const [feedback, setFeedback] = useState("");
  const selected = rows.find(row => row.id === selectedId);

  useEffect(() => {
    const controller = new AbortController();
    async function load() {
      let result;
      try {
        result = await requestJson(PATH, { requiresAuth: true, signal: controller.signal });
      } catch {
        result = null;
      }
      if (controller.signal.aborted) return;
      const companies = result?.data?.entreprises;
      if (result?.success && Array.isArray(companies)) {
        setRows(companies);
      } else {
        setRows([]);
        setLoadError("Les entreprises participantes n’ont pas pu être chargées.");
      }
      setLoading(false);
    }
    void load();
    return () => controller.abort();
  }, [refresh]);

  function reload() {
    setLoading(true);
    setLoadError("");
    setRefresh(value => value + 1);
  }

  function apply() {
    const next = { ...draft, q: draft.q.trim() };
    setDraft(next);
    setCriteria(next);
    setPage(1);
  }

  function reset() {
    setDraft(EMPTY_FILTER);
    setCriteria(EMPTY_FILTER);
    setPage(1);
  }

  function removeCriterion(key) {
    setDraft(previous => ({ ...previous, [key]: "" }));
    setCriteria(previous => ({ ...previous, [key]: "" }));
    setPage(1);
  }

  function saved(enabled) {
    setSelectedId(null);
    setFeedback(enabled ? "Participation activée." : "Participation arrêtée.");
    reload();
  }

  const matching = rows.filter(row =>
    (!criteria.state || participation(row).value === criteria.state)
    && matchesAnalysisSearch([row.nom], criteria.q));
  const open = row => {
    setFeedback("");
    setSelectedId(row.id);
  };
  const columns = [
    { key: "nom", label: "Entreprise", width: 320 },
    { key: "state", label: "Participation", width: 180, sortValue: row => participation(row).label,
      render: row => <ParticipationStatus row={row} /> },
    { key: "debuteLe", label: "Participation depuis", width: 220, render: row => formatDate(row.debuteLe) },
    { key: "actions", label: "Actions", width: 90, sortable: false, render: row => (
      <div className="erp-row-actions">
        <button type="button" className="erp-row-consult" aria-label={"Consulter " + row.nom} onClick={() => open(row)}><AppIcon name="eye" /></button>
      </div>
    ) },
  ];
  const activeCriteria = [
    criteria.q && { key: "q", label: "Recherche", value: criteria.q },
    criteria.state && { key: "state", label: "Participation", value: STATES.find(item => item.value === criteria.state)?.label },
  ].filter(Boolean);
  const toolbar = <>
    <DataTableToolbar showSettings={false} search={draft.q} setSearch={q => setDraft(previous => ({ ...previous, q }))}
      onApply={apply} onReset={reset} pending={draft.q !== criteria.q || draft.state !== criteria.state}
      take={take} onTake={value => { setTake(value); setPage(1); }}
      filtersOpen={filtersOpen} toggleFilters={() => setFiltersOpen(value => !value)} filterControlsId={id + "-filters"}
      activeFilters={activeCriteria.length} density={density} toggleDensity={() => setDensity(value => value === "compact" ? "airy" : "compact")}
      loading={loading} placeholder="Rechercher une entreprise…" filterContent={(
        <form id={id + "-filters"} className="erp-register-filters" hidden={!filtersOpen} onSubmit={event => { event.preventDefault(); apply(); }}>
          <div className="erp-register-filter-grid">
            <label htmlFor={id + "-state"}><span>Participation</span>
              <SearchSelect id={id + "-state"} label="Participation" options={STATES} value={draft.state}
                onChange={state => setDraft(previous => ({ ...previous, state }))} />
            </label>
          </div>
          <div className="erp-register-filters-footer"><ActionButton variant="primary" type="submit" disabled={loading}>Appliquer les filtres</ActionButton></div>
        </form>
      )} />
    {activeCriteria.length > 0 && <div className="erp-register-chips" aria-label="Critères appliqués">
      {activeCriteria.map(({ key, label, value }) => <span className="erp-register-chip" key={key}>{label} · {value}
        <button type="button" aria-label={"Retirer le filtre " + label} onClick={() => removeCriterion(key)}><AppIcon name="close" size={12} /></button>
      </span>)}
    </div>}
  </>;
  return <>
    <RegisterSurface title={title} subtitle="Participation des entreprises à la collecte de recherche."
      actions={<RegisterSettingsButton buttonRef={settingsButton} expanded={settingsOpen} onTableSettings={() => setSettingsOpen(value => !value)} />}>
      <div className="erp-register-table erp-results" data-density={density}>
        {feedback && <p role="status">{feedback}</p>}
        {loadError && <div className="admin-error" role="alert"><span>{loadError}</span>
          <ActionButton icon="refresh" onClick={reload}>Réessayer</ActionButton>
        </div>}
        <SimpleTable columns={columns} rows={matching} getRowId={row => row.id} rowsPerPage={take}
          page={page} onPageChange={setPage} defaultSortColumn="nom" enableSelection={false}
          tableLabel="Entreprises dans le périmètre de l’étude" loading={loading} toolbar={toolbar}
          columnsPanelOpen={settingsOpen} columnsAnchorRef={settingsButton} onColumnsPanelClose={() => setSettingsOpen(false)}
          onRowConsult={open} consultColumns={["nom"]}
          emptyMessage={loadError ? "Liste indisponible." : activeCriteria.length ? "Aucune entreprise ne correspond à ces critères." : "Aucune entreprise disponible."} />
      </div>
    </RegisterSurface>
    {selected && <ParticipationEditor key={selected.id} row={selected} canManage={canManage}
      onClose={() => setSelectedId(null)} onSaved={saved} />}
  </>;
}

function ParticipationEditor({ row, canManage, onClose, onSaved }) {
  const [confirm, setConfirm] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const operation = useRef(null);
  const confirmation = useRef(null);
  const enabled = Boolean(row.debuteLe);
  const action = enabled ? "Arrêter la participation" : "Activer la participation";

  useEffect(() => () => operation.current?.abort(), []);
  useEffect(() => {
    if (confirm) confirmation.current?.focus();
  }, [confirm]);

  async function save() {
    if (!canManage || !confirm || operation.current) return;
    const controller = new AbortController();
    operation.current = controller;
    setBusy(true);
    setError("");
    let result;
    try {
      result = await requestJson(PATH, {
        requiresAuth: true, method: "POST", signal: controller.signal,
        body: JSON.stringify({ entityId: row.id, enabled: !enabled }),
      });
    } catch {
      result = null;
    }
    if (controller.signal.aborted) return;
    operation.current = null;
    setBusy(false);
    if (result?.success) onSaved(!enabled);
    else setError(result?.message || "Le réglage n’a pas pu être enregistré. Réessayez.");
  }

  return <RecordEditorFrame title="Participation à l’étude" subtitle={row.nom} icon="building"
    onClose={onClose} onSubmit={save} busy={busy} readOnly={!canManage || !confirm} canSubmit={canManage && confirm}
    defaultWidth={620} storageKey="sauverndeko.data-science.participation.width" submitLabel="Confirmer" error={error}>
    <section className="record-editor-section">
      <h3>Participation</h3>
      <div className="admin-detail-grid">
        <div><span>État</span><strong><ParticipationStatus row={row} /></strong></div>
        <div><span>Depuis</span><strong>{formatDate(row.debuteLe)}</strong></div>
      </div>
      {canManage && !confirm && <ActionButton icon={enabled ? "close" : "check-circle"} onClick={() => setConfirm(true)}>{action}</ActionButton>}
      {canManage && confirm && <p className="record-editor-note" ref={confirmation} tabIndex={-1}>
        {enabled ? "L’arrêt retire les contributions de cette entreprise des prochaines analyses."
          : "La collecte commence à l’activation. Les utilisateurs choisissent ensuite s’ils souhaitent partager leurs déclarations."}
      </p>}
    </section>
  </RecordEditorFrame>;
}
