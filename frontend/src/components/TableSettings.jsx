import { useEffect, useId, useRef, useState } from "react";
import RecordEditorFrame from "./RecordEditorFrame";
import ConsultationTabs from "./ConsultationTabs";
import AppIcon from "./AppIcon";
import ActionButton from "./ActionButton";
import { movePreference, preferenceChoices, preferenceIds, samePreference } from "../utils/tablePreferences";
import "./TableSettings.css";

const normalize = value => String(value || "").normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase();

export default function TableSettings({ preferences, onClose, title = "Réglages du tableau", pinnedKeys = [], onTogglePinned, onResetWidths, additionalActions = [] }) {
  const id = useId(), initialised = useRef(false), dragged = useRef(null), moveFocus = useRef(null);
  const [usage, setUsage] = useState("table"), [query, setQuery] = useState(""), [notice, setNotice] = useState("");
  const [drafts, setDrafts] = useState({ table: [], export: [] });
  const catalogue = preferences.catalogue || [], busy = preferences.busy, loading = preferences.loading;
  const hasExportOptions = preferences.hasExportOptions !== false;
  useEffect(() => {
    if (!preferences.ready || initialised.current) return;
    initialised.current = true;
    setDrafts({ table: preferences.tableKeys, export: preferences.exportKeys });
  }, [preferences.ready, preferences.tableKeys.join("|"), preferences.exportKeys.join("|")]);
  const selected = preferenceIds(catalogue, drafts[usage], usage);
  const available = preferenceChoices(catalogue, selected, usage);
  const shown = available.filter(column => normalize(column.label).includes(normalize(query)));
  const saved = usage === "table" ? preferences.tableKeys : preferences.exportKeys;
  const dirty = !samePreference(drafts.table, preferences.tableKeys) || !samePreference(drafts.export, preferences.exportKeys);
  const activeDirty = !samePreference(selected, saved);
  const canEdit = preferences.ready && !busy && !loading && (usage !== "export" || preferences.canExport);

  function replace(next) { setNotice(""); setDrafts(current => ({ ...current, [usage]: next })); }
  function toggle(columnId) {
    if (!canEdit) return;
    replace(selected.includes(columnId) ? selected.filter(key => key !== columnId) : [...selected, columnId]);
  }
  function move(source, destination) {
    if (!canEdit) return;
    replace(movePreference(selected, source, destination));
    const label = catalogue.find(column => column.id === source)?.label || source;
    setNotice(label + " déplacé.");
    requestAnimationFrame(() => moveFocus.current?.querySelector('[data-move-id="' + CSS.escape(source) + '"]')?.focus({ preventScroll: true }));
  }
  async function save() {
    if (!canEdit || !selected.length || !activeDirty) return;
    const result = await preferences.save(usage, selected);
    if (!result) return;
    setDrafts(current => ({ ...current, [usage]: preferenceIds(result.columns, result[usage]?.columns, usage) }));
    setNotice(preferences.local ? "Réglages appliqués." : usage === "table" ? "Présentation enregistrée." : "Options d’export enregistrées.");
  }
  async function reset() {
    if (!canEdit) return;
    const result = await preferences.reset(usage);
    if (!result) return;
    setDrafts(current => ({ ...current, [usage]: preferenceIds(result.columns, result[usage]?.columns, usage) }));
    setNotice(usage === "table" ? "Présentation de référence rétablie." : "Export de référence rétabli.");
  }
  function switchUsage(next) { if (busy) return; setUsage(next); setQuery(""); setNotice(""); }

  return <RecordEditorFrame title={title} subtitle={preferences.local ? "Préférences de cet affichage" : "Préférences personnelles"} icon="settings" onClose={onClose}
    defaultWidth={690} storageKey="sauverndeko.table-settings.width" className="table-settings"
    busy={busy} loading={loading} dirty={dirty && preferences.ready} canSubmit={canEdit && activeDirty && selected.length > 0}
    onSubmit={save} submitLabel={preferences.local ? "Appliquer" : "Enregistrer par défaut"} error={preferences.error} onReload={preferences.retry}>
    <ConsultationTabs idPrefix={id} value={usage} onChange={switchUsage} label="Réglages du tableau et de l’export" tabs={[
      { key: "table", label: "Colonnes du tableau", icon: "columns", disabled: busy },
      ...(hasExportOptions ? [{ key: "export", label: "Options d’export", icon: "download", disabled: busy }] : []),
    ]}/>
    <section id={id + "-panel-" + usage} role="tabpanel" aria-labelledby={id + "-tab-" + usage} className="table-settings-panel">
      <div className="table-settings-context"><div><strong>{usage === "table" ? "Présentation du tableau" : "Colonnes Excel et CSV"}</strong><p>{usage === "table" ? "Choisissez les colonnes et leur ordre." : "Ces choix sont indépendants du tableau affiché."}</p></div><span className="table-settings-source">{preferences.data?.[usage]?.personal ? "Personnel" : "Référence"}</span></div>
      {usage === "export" && !preferences.canExport && preferences.ready ? <p className="table-settings-unavailable" role="status">L’export n’est pas autorisé pour votre compte.</p> : <>
        <label className="table-settings-search"><AppIcon name="search"/><input type="search" aria-label="Rechercher une colonne" placeholder="Rechercher une colonne…" value={query} onChange={event => setQuery(event.target.value)} disabled={!canEdit}/></label>
        <div className="table-settings-selection"><span>{selected.length} colonne{selected.length === 1 ? "" : "s"} sélectionnée{selected.length === 1 ? "" : "s"}</span><button type="button" disabled={!canEdit || selected.length === available.length} onClick={() => replace(available.map(column => column.id))}>Tout sélectionner</button></div>
        <div ref={moveFocus} className="table-settings-columns" role="list" aria-label={usage === "table" ? "Colonnes du tableau dans l’ordre choisi" : "Colonnes à exporter dans l’ordre choisi"}>
          {shown.map(column => {
            const checked = selected.includes(column.id), position = selected.indexOf(column.id);
            return <div key={column.id} className={"table-settings-column" + (checked ? " is-selected" : "")} role="listitem"
              onDragOver={event => { if (canEdit && checked && dragged.current && dragged.current !== column.id) { event.preventDefault(); event.dataTransfer.dropEffect = "move"; } }}
              onDrop={event => { event.preventDefault(); if (checked && dragged.current) move(dragged.current, column.id); dragged.current = null; }}>
              <button type="button" className="table-settings-grip" data-move-id={column.id} draggable={canEdit && checked} disabled={!canEdit || !checked}
                aria-label={"Déplacer " + column.label} title="Glisser pour déplacer, ou Alt + flèche haut/bas"
                onDragStart={event => { dragged.current = column.id; event.dataTransfer.effectAllowed = "move"; event.dataTransfer.setData("text/plain", column.id); }}
                onDragEnd={() => { dragged.current = null; }}
                onKeyDown={event => { if (event.altKey && ["ArrowUp", "ArrowDown"].includes(event.key)) { event.preventDefault(); const target = selected[position + (event.key === "ArrowUp" ? -1 : 1)]; if (target) move(column.id, target); } }}><AppIcon name="rows-compact" size={15}/></button>
              <label><input type="checkbox" checked={checked} disabled={!canEdit || checked && selected.length === 1} onChange={() => toggle(column.id)}/><span>{column.label}</span></label>
              {checked ? <span className="table-settings-position" aria-label={"Position " + (position + 1)}>{position + 1}</span> : null}
              <div className="table-settings-move" role="group" aria-label={"Ordre : " + column.label}>
                {usage === "table" && onTogglePinned ? <button type="button" className={pinnedKeys.includes(column.id) ? "is-pinned" : ""} disabled={!canEdit || !checked} aria-pressed={pinnedKeys.includes(column.id)} aria-label={(pinnedKeys.includes(column.id) ? "Libérer " : "Figer ") + column.label} title="Figer la colonne" onClick={() => onTogglePinned(column.id)}><AppIcon name="pin" size={14}/></button> : null}
                <button type="button" disabled={!canEdit || !checked || position === 0} aria-label={"Monter " + column.label} onClick={() => move(column.id, selected[position - 1])}><AppIcon name="chevron-up" size={15}/></button>
                <button type="button" disabled={!canEdit || !checked || position === selected.length - 1} aria-label={"Descendre " + column.label} onClick={() => move(column.id, selected[position + 1])}><AppIcon name="chevron-down" size={15}/></button>
              </div>
            </div>;
          })}
          {!shown.length && preferences.ready ? <p className="table-settings-empty">Aucune colonne correspondante.</p> : null}
        </div>
        <div className="table-settings-reset"><ActionButton icon="reset" onClick={reset} disabled={!canEdit}>Rétablir la référence</ActionButton>{usage === "table" && onResetWidths ? <ActionButton onClick={onResetWidths} disabled={busy}>Largeurs auto</ActionButton> : null}</div>
      </>}
      <p className="table-settings-notice" role="status" aria-live="polite">{notice}</p>
    </section>
    {additionalActions.length > 0 && <section className="table-settings-related" aria-label="Réglages du module">
      {additionalActions.map(({ label, icon, onSelect }) => <ActionButton key={label} icon={icon} disabled={busy || dirty}
        onClick={() => { onClose(false); onSelect(); }}>{label}</ActionButton>)}
      {dirty && <p>Enregistrez ou rétablissez les réglages du tableau avant d’ouvrir une autre rubrique.</p>}
    </section>}
  </RecordEditorFrame>;
}
