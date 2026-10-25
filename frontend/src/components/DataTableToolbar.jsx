import { useAuth } from "../contexts/AuthContext";
import { useId } from "react";
import AppIcon from "./AppIcon";
import ActionButton from "./ActionButton";
import "./DataTable.css";
export default function DataTableToolbar({ search, setSearch, onApply, onReset, pending, take, onTake, filtersOpen, toggleFilters, activeFilters, density, toggleDensity, columnsOpen, columnsButtonRef, toggleColumns, loading, exportFile, exporting, exportDisabled, error, placeholder = "Rechercher un code, un article, un tiers ou un statut…", filterContent = null, filterControlsId, showFilters=true }) {
  const id = useId();
  const { user } = useAuth();
  return <>
    <form className="erp-table-toolbar" role="search" onSubmit={(event) => { event.preventDefault(); onApply(); }}>
      <label className="erp-table-search" htmlFor={id}><AppIcon name="search" /><span className="erp-sr-only">Rechercher dans la liste</span><input id={id} type="search" value={search} onChange={(event) => setSearch(event.target.value)} placeholder={placeholder} /></label>
      <ActionButton type="submit" variant="primary" disabled={loading}>Rechercher</ActionButton>
      <label className="erp-table-size"><span>Lignes</span><select aria-label="Lignes par page" value={take} onChange={(event) => onTake(Number(event.target.value))} disabled={loading}>{[10,25,50,100].map(value => <option key={value} value={value}>{value}</option>)}</select></label>
      {showFilters?<ActionButton icon="filter" className={filtersOpen ? "is-active" : ""} aria-expanded={filtersOpen} aria-controls={filterControlsId} onClick={toggleFilters}>Filtrer{activeFilters ? <span className="erp-filter-count">{activeFilters}</span> : null}</ActionButton>:null}
      <ActionButton icon="reset" onClick={onReset} disabled={loading || (!search && !activeFilters && !pending)}>Réinitialiser</ActionButton>
      <ActionButton icon={density === "airy" ? "compact" : "expand"} aria-pressed={density === "airy"} onClick={toggleDensity}>{density === "airy" ? "Vue compacte" : "Vue aérée"}</ActionButton>
      <ActionButton ref={columnsButtonRef} icon="columns" className="is-icon" title="Colonnes" aria-label="Colonnes" aria-expanded={columnsOpen} onClick={toggleColumns} />
      {exportFile ? <ActionButton icon="download" onClick={exportFile} disabled={user?.permissions?.canExportData === false || loading || exporting || exportDisabled || pending} title={pending ? "Appliquez les filtres avant l’export." : "Exporter tous les résultats filtrés en Excel"}>{exporting ? "Préparation…" : "Excel"}</ActionButton> : null}
    </form>
    {filterContent}
    {pending ? <p className="erp-table-pending" role="status">Filtres à appliquer.</p> : null}
    {error ? <p className="erp-table-error" role="alert">{error}</p> : null}
  </>;
}
