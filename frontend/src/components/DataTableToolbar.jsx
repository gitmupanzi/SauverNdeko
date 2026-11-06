import { useAuth } from "../contexts/AuthContext";
import { useId } from "react";
import AppIcon from "./AppIcon";
import ActionButton from "./ActionButton";
import ExportMenu from "./ExportMenu";
import "./DataTable.css";
export default function DataTableToolbar({ search, setSearch, onApply, onReset, pending, take, onTake, filtersOpen, toggleFilters, activeFilters, density, toggleDensity, columnsOpen, columnsButtonRef, toggleColumns, loading, exportFile, exportCsv, exporting, exportDisabled, error, placeholder = "Rechercher un code, un article, un tiers ou un statut…", filterContent = null, filterControlsId, showFilters=true, settingsLabel="Colonnes", showSettings=true }) {
  const id = useId();
  const { user } = useAuth();
  const exportUnavailable = user?.permissions?.canExportData === false || loading || exporting || exportDisabled || pending;
  const exportTitle = pending ? "Appliquez les filtres avant l’export." : "Exporter tous les résultats filtrés";
  return <>
    <form className="erp-table-toolbar" role="search" aria-label="Recherche et outils de la liste" onSubmit={(event) => { event.preventDefault(); if(!loading) onApply(); }}>
      <label className="erp-table-search" htmlFor={id}><AppIcon name="search" /><span className="erp-sr-only">Rechercher dans la liste</span><input id={id} type="search" value={search} onChange={(event) => setSearch(event.target.value)} placeholder={placeholder} enterKeyHint="search" aria-describedby={pending ? id+"-pending" : undefined} /></label>
      <ActionButton type="submit" variant="primary" disabled={loading}>Rechercher</ActionButton>
      <label className="erp-table-size"><span>Lignes</span><select aria-label="Lignes par page" value={take} onChange={(event) => onTake(Number(event.target.value))} disabled={loading}>{[10,25,50,100].map(value => <option key={value} value={value}>{value}</option>)}</select></label>
      {showFilters?<ActionButton icon="filter" className={filtersOpen ? "is-active" : ""} aria-expanded={filtersOpen} aria-controls={filterControlsId} onClick={toggleFilters}>Filtrer{activeFilters ? <span className="erp-filter-count">{activeFilters}</span> : null}</ActionButton>:null}
      <ActionButton icon="reset" onClick={onReset} disabled={loading || (!search && !activeFilters && !pending)}>Réinitialiser</ActionButton>
      <ActionButton icon={density === "airy" ? "compact" : "expand"} aria-pressed={density === "airy"} onClick={toggleDensity}>{density === "airy" ? "Vue compacte" : "Vue aérée"}</ActionButton>
      {showSettings?<ActionButton ref={columnsButtonRef} icon={settingsLabel === "Réglages" ? "settings" : "columns"} className={settingsLabel === "Colonnes" ? "is-icon" : ""} title={settingsLabel} aria-label={settingsLabel} aria-expanded={columnsOpen} onClick={toggleColumns}>{settingsLabel === "Colonnes" ? null : settingsLabel}</ActionButton>:null}
      {exportFile && exportCsv ? (
        <ExportMenu exportFile={exportFile} exportCsv={exportCsv} disabled={exportUnavailable} exporting={exporting} title={exportTitle} />
      ) : exportFile || exportCsv ? (
        <ActionButton icon="download" onClick={exportFile || exportCsv} disabled={exportUnavailable}
          title={pending ? exportTitle : exportTitle + (exportFile ? " en Excel" : " en CSV")}>
          {exporting ? "Préparation…" : exportFile ? "Excel" : "CSV"}
        </ActionButton>
      ) : null}
    </form>
    {filterContent}
    {pending ? <p className="erp-table-pending" id={id+"-pending"} role="status"><AppIcon name="clock"/>Validez la recherche pour actualiser les résultats.</p> : null}
    {error ? <p className="erp-table-error" role="alert"><AppIcon name="alert"/>{error}</p> : null}
  </>;
}
