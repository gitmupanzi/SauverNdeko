import { useEffect, useId, useState } from "react";
import ActionButton from "../../components/ActionButton";
import AppIcon from "../../components/AppIcon";
import DataTableToolbar from "../../components/DataTableToolbar";
import ListState from "../../components/ListState";
import RegisterSettingsButton from "../../components/RegisterSettingsButton";
import RegisterSurface from "../../components/RegisterSurface";
import SearchSelect from "../../components/SearchSelect";
import { useDepotScope } from "../../contexts/DepotScopeContext";
import { useEntityScope } from "../../contexts/EntityScopeContext";
import useLogisticsRegisterSettings from "../../hooks/useLogisticsRegisterSettings";
import { depotFailure, depotRead } from "../../services/depots";
import InventoryEditor from "./InventoryEditor";
import { SimpleTable, formatDate, formatNumber } from "./logistiqueShared";

const EMPTY = { q: "", etat: "", ecart: "" };
const INITIAL_GRID = { take: 25, skip: 0, sortBy: "DateInventaire", sortDir: "desc" };
const SUBTITLE = "Comparez le stock théorique aux quantités comptées, article par article.";
const FILTERS = [
  { key: "etat", label: "État de l’inventaire", options: [
    { value: "", label: "Tous les états" }, { value: "brouillon", label: "Brouillon" },
    { value: "valide", label: "Validé" }, { value: "annule", label: "Annulé" },
  ] },
  { key: "ecart", label: "Écart", options: [
    { value: "", label: "Tous les écarts" }, { value: "avec", label: "Avec écart" },
    { value: "sans", label: "Sans écart" }, { value: "positif", label: "Surplus" },
    { value: "negatif", label: "Manquant" },
  ] },
];
const STATE_LABELS = Object.fromEntries(FILTERS[0].options.map(({value, label}) => [value, label]));
const rowKey = row => row.ID_InventaireFk + ":" + row.ID_ArticleFk;

function quantityColumn(key, label) {
  return { key, label, align: "right", width: 145, render: row => formatNumber(row[key]) };
}

export default function InventoryLines({ title = "Lignes d’inventaire", ...props }) {
  const scope = useEntityScope();
  if (!scope.entityId) return <RegisterSurface title={title} subtitle={SUBTITLE}>
    <div className="erp-register-table"><ListState title="Choisissez une entreprise"
      description="Sélectionnez son nom en haut de la page pour consulter les lignes d’inventaire."/></div>
  </RegisterSurface>;
  return <InventoryLinesRegister key={scope.scopeKey} title={title} {...props}/>;
}

function InventoryLinesRegister({ title, inventoryId, onClearInventory }) {
  const { depotId } = useDepotScope();
  const filterId = useId();
  const [draft, setDraft] = useState(EMPTY);
  const [criteria, setCriteria] = useState(EMPTY);
  const [grid, setGrid] = useState(INITIAL_GRID);
  const [result, setResult] = useState({ rows: [], meta: null });
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [revision, setRevision] = useState(0);
  const [editor, setEditor] = useState(null);
  const [filtersOpen, setFiltersOpen] = useState(false);
  const [density, setDensity] = useState("compact");
  const [inventoryCode, setInventoryCode] = useState("");
  const [previousInventoryId, setPreviousInventoryId] = useState(inventoryId);
  if (previousInventoryId !== inventoryId) {
    setPreviousInventoryId(inventoryId);
    setGrid(current => ({ ...current, skip: 0 }));
    setResult({ rows: [], meta: null });
    setInventoryCode("");
    setEditor(null);
    setLoading(true);
    setError("");
  }
  const pending = draft.q.trim() !== criteria.q || FILTERS.some(({key}) => draft[key] !== criteria[key]);
  const { q, etat, ecart } = criteria;
  const { rows, meta } = result;
  const query = { q, etat, ecart, depotId, inventaireId: inventoryId };
  const tools = useLogisticsRegisterSettings("lignes-inventaires", {
    query, grid, loading, pending, error, count: meta?.filteredCount,
    permissionTab: "inventaires",
  });

  useEffect(() => {
    const controller = new AbortController();
    setLoading(true);
    setError("");
    depotRead("/lignes-inventaires", { q, etat, ecart, depotId, inventaireId: inventoryId, ...grid }, controller.signal)
      .then(response => {
        if (controller.signal.aborted) return;
        if (response?.success) {
          const nextRows = Array.isArray(response.data) ? response.data : [];
          setResult({ rows: nextRows, meta: response.meta || null });
          if (inventoryId && nextRows[0]?.CodeInventaire) setInventoryCode(nextRows[0].CodeInventaire);
        } else {
          if ([401, 403].includes(response?.status)) setResult({ rows: [], meta: null });
          setError(depotFailure(response, "Les lignes d’inventaire ne sont pas disponibles."));
        }
        setLoading(false);
      });
    return () => controller.abort();
  }, [q, etat, ecart, depotId, inventoryId, grid, revision]);

  function apply() {
    setCriteria({ ...draft, q: draft.q.trim() });
    setGrid(current => ({ ...current, skip: 0 }));
  }

  function removeFilter(key) {
    setDraft(current => ({ ...current, [key]: "" }));
    setCriteria(current => ({ ...current, [key]: "" }));
    setGrid(current => ({ ...current, skip: 0 }));
  }

  function reset() {
    setDraft(EMPTY);
    setCriteria(EMPTY);
    setGrid(current => ({ ...current, skip: 0 }));
    if (inventoryId) onClearInventory();
  }

  const activeFilters = FILTERS.filter(({key}) => criteria[key]).length;
  const openInventory = row => setEditor(row.ID_InventaireFk);
  const columns = [
    { key: "CodeInventaire", label: "Inventaire", width: 140,
      render: row => <button type="button" className="erp-object-link" onClick={() => openInventory(row)}>{row.CodeInventaire || "Consulter"}</button> },
    { key: "DateInventaire", label: "Date et heure", width: 155, render: row => formatDate(row.DateInventaire) },
    { key: "NomDepot", label: "Dépôt", width: 165 },
    { key: "NomArticle", label: "Article", width: 240 },
    { key: "CodeArticleInterne", label: "Code article", width: 140 },
    quantityColumn("QteTheorique", "Quantité théorique"),
    quantityColumn("QteComptee", "Quantité physique"),
    { key: "Unite", label: "Unité", width: 120 },
    { ...quantityColumn("Ecart", "Écart"), width: 120, render: row => {
      if (row.Ecart == null || row.Ecart === "") return "—";
      const amount = Number(row.Ecart);
      return <span className={"erp-status is-" + (amount < 0 ? "warning" : amount > 0 ? "info" : "muted")}>{amount > 0 ? "+" : ""}{formatNumber(row.Ecart)}</span>;
    } },
    { key: "Justification", label: "Justification", width: 215 },
    { key: "EtatInventaire", label: "État", width: 130,
      render: row => <span className={"erp-status is-" + (row.EtatInventaire === "valide" ? "success" : row.EtatInventaire === "annule" ? "muted" : "warning")}>{STATE_LABELS[row.EtatInventaire] || "—"}</span> },
    { key: "Motif", label: "Motif de l’inventaire", width: 200 },
    { key: "CodeCorrection", label: "Bon correcteur", width: 145 },
    { key: "CodeAnnulation", label: "Bon d’annulation", width: 145 },
    { key: "actions", label: "Actions", width: 110, sortable: false, render: row =>
      <ActionButton className="is-icon" icon="eye" aria-label={"Consulter l’inventaire " + (row.CodeInventaire || "")} onClick={() => openInventory(row)}/> },
  ];
  const settings = <RegisterSettingsButton buttonRef={tools.columnsAnchorRef} expanded={tools.columnsOpen} onTableSettings={tools.open}/>;
  const toolbar = <DataTableToolbar {...tools.toolbarProps}
    search={draft.q} setSearch={q => setDraft(current => ({ ...current, q }))}
    onApply={apply} onReset={reset} pending={pending} loading={loading}
    take={grid.take} onTake={take => setGrid(current => ({ ...current, take, skip: 0 }))}
    filtersOpen={filtersOpen} toggleFilters={() => setFiltersOpen(open => !open)}
    activeFilters={activeFilters + (criteria.q ? 1 : 0) + (inventoryId ? 1 : 0)} filterControlsId={filtersOpen ? filterId : undefined}
    density={density} toggleDensity={() => setDensity(current => current === "compact" ? "airy" : "compact")}
    placeholder="Rechercher un inventaire, un article ou un dépôt…"
    filterContent={<>
      {filtersOpen ? <form id={filterId} className="erp-register-filters" onSubmit={event => { event.preventDefault(); if (!loading) apply(); }}>
        <div className="erp-register-filter-grid">
          {FILTERS.map(({key, label, options}) => <div key={key}><label htmlFor={filterId + key}>{label}</label>
            <SearchSelect id={filterId + key} label={label} value={draft[key]} options={options}
              onChange={value => setDraft(current => ({ ...current, [key]: value }))}/></div>)}
        </div>
        <div className="erp-register-filters-footer"><ActionButton type="submit" variant="primary" disabled={loading}>Appliquer les filtres</ActionButton></div>
      </form> : null}
      {inventoryId || activeFilters || criteria.q ? <div className="erp-register-chips">
        {inventoryId ? <span className="erp-register-chip">{inventoryCode ? "Inventaire : " + inventoryCode : "Inventaire sélectionné"}<button type="button" aria-label="Afficher tous les inventaires" onClick={onClearInventory}><AppIcon name="close" size={13}/></button></span> : null}
        {criteria.q ? <span className="erp-register-chip">Recherche : {criteria.q}<button type="button" aria-label="Effacer la recherche" onClick={() => removeFilter("q")}><AppIcon name="close" size={13}/></button></span> : null}
        {FILTERS.filter(({key}) => criteria[key]).map(({key, label, options}) => <span className="erp-register-chip" key={key}>
          {options.find(option => option.value === criteria[key])?.label}<button type="button" aria-label={"Retirer le filtre " + label} onClick={() => removeFilter(key)}><AppIcon name="close" size={13}/></button>
        </span>)}
      </div> : null}
    </>}/>;

  return <RegisterSurface title={title} actions={settings} subtitle={SUBTITLE}>
    <div className="erp-register-table erp-results" data-density={density}>
      {error ? <div className="record-editor-error" role="alert">{error}<ActionButton icon="refresh" onClick={() => setRevision(value => value + 1)}>Réessayer</ActionButton></div> : null}
      <SimpleTable {...tools.tableProps} rows={rows} columns={columns} getRowId={rowKey}
        serverMeta={meta} serverState={grid} loading={loading} onServerChange={patch => setGrid(current => ({ ...current, ...patch }))}
        defaultPinnedColumns={[]} toolbar={toolbar} emptyMessage="Aucune ligne d’inventaire pour ces critères."/>
    </div>
    {editor != null ? <InventoryEditor key={editor} inventoryId={editor} readOnly onClose={() => setEditor(null)}/> : null}
  </RegisterSurface>;
}
