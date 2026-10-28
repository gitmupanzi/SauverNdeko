import {useEntityScope} from "../../contexts/EntityScopeContext";
import {fetchAdminFieldReferences} from "../../services/fieldReferences";
import {referenceOptions} from "../../utils/referenceOptions";
import useTablePreferences from "../../hooks/useTablePreferences";
import { useEffect, useId, useRef, useState } from "react";
import { Link, useNavigate, useSearchParams } from "react-router-dom";
import { useAuth } from "../../contexts/AuthContext";
import ModuleHeader from "../../components/ModuleHeader";
import AppIcon from "../../components/AppIcon";
import ActionButton from "../../components/ActionButton";
import RegisterSurface from "../../components/RegisterSurface";
import RegisterSettingsButton from "../../components/RegisterSettingsButton";
import DataTableToolbar from "../../components/DataTableToolbar";
import RowActionsMenu from "../../components/RowActionsMenu";
import SearchSelect from "../../components/SearchSelect";
import RecordEditorFrame from "../../components/RecordEditorFrame";
import useReferencesRefresh from "../../hooks/useReferencesRefresh";
import lazyView from "../../components/LazyView";
import { requestJson, downloadApiFile, fetchCompleteReferenceRows, fetchAdminModelList, deleteAdminUser, deleteAdminEntity, deleteAdminLicence, deleteAdminModelRecord, updateAdminModelRecord } from "../../services/api";
import { SimpleTable, formatDate } from "../logistique/logistiqueShared";
import { ADMIN_ROOT, ADMIN_NAVIGATION, ADMIN_REGISTERS, adminTabKey } from "./adminPortalDefinitions";
import "../logistique/LogistiqueModern.css";
import "./AdminPortal.css";

const AdminRecordEditor = lazyView(() => import("./AdminRecordEditor"), { compact: true, label: "Ouverture de la fiche…" });
const AdminPermissions = lazyView(() => import("./AdminPermissions"), { compact: true, label: "Chargement des permissions…" });
const AdminMailSettings = lazyView(() => import("../../components/AdminMailSettings"), { compact: true, label: "Ouverture de la messagerie…" });
const preference = (key, fallback) => { try { return localStorage.getItem(key) || fallback; } catch { return fallback; } };
const numeric = value => typeof value === "number" ? new Intl.NumberFormat("fr").format(value) : "—";
const fullName = row => [row?.PrenomUser, row?.NomUser].filter(Boolean).join(" ");
function recordName(kind, row) { return kind === "licences" ? "Licence #" + row.IdLicence : ["utilisateurs", "profils", "connexions"].includes(kind) ? fullName(row) : row[ADMIN_REGISTERS[kind].name] || row.SettingKey || row.FieldName || "Fiche"; }
function useAdminSupport(refresh) {
  const entityScope=useEntityScope();
  const [support, setSupport] = useState({ entities: [], generics: [], categories: [], niveaux3: [], niveaux4: [], niveaux5: [],personnelServices:[],personnelFonctions:[] });
  const [error, setError] = useState("");
  useEffect(() => {
    let current = true;
    Promise.allSettled([
      requestJson("/api/workspace/organisations", { requiresAuth: true }),
      fetchCompleteReferenceRows("T_Generique"), fetchCompleteReferenceRows("T_CategorieGenerique"),
      requestJson("/api/systeme/personnel/references",{requiresAuth:true}),fetchAdminFieldReferences(),
    ]).then(results => {
      if (!current) return;
      const [entities, generics, categories,personnel,fieldReferences] = results.map(result => result.status === "fulfilled" ? result.value : null);
      setSupport(old => ({ ...old,referenceOptions:fieldReferences?.options||{},roleCategoryId:fieldReferences?.roleCategoryId??null, entities: entities?.success ? entities.data : [], generics: generics?.success ? generics.data : [], categories: categories?.success ? categories.data : [],personnelServices:personnel?.data?.personnelServices||[],personnelFonctions:personnel?.data?.personnelFonctions||[] }));
      setError(results.some(result => result.status === "rejected" || !result.value?.success) ? "Certaines listes de référence sont indisponibles." : "");
    });
    return () => { current = false; };
  }, [refresh,entityScope.scopeKey]);
  return { support, setSupport, error };
}
function optionsFor(field, support) {
  if (field.options) return field.options;
  if (field.source === "entities") return support.entities.map(row => ({ value: String(row.IdEntite), label: row.NomEntite }));
  if (field.source === "categories") return support.categories.map(row => ({ value: String(row.ID_CategorieGenerique), label: row.NomCategorieGenerique }));
  if (field.source === "roles") return referenceOptions(support.referenceOptions?.roles||[]);
  if(["personnelServices","personnelFonctions"].includes(field.source))return (support[field.source]||[]).map(row=>({value:String(row.id),label:row.label,disabled:row.disabled===true}));
  return [];
}
function serializeCriteria(criteria, grid, columns) {
  const { q, dateFrom, dateTo, ...filters } = criteria;
  const normalized = Object.fromEntries(Object.entries(filters).filter(([, value]) => value !== "" && value != null).map(([key, value]) => [key, value === "true" ? true : value === "false" ? false : value]));
  return new URLSearchParams({ q: q || "", filters: JSON.stringify(normalized), ...grid, ...(dateFrom ? { dateFrom } : {}), ...(dateTo ? { dateTo } : {}), ...(columns ? { columns: JSON.stringify(columns) } : {}) });
}

function AdminRegister({ kind, initial = {}, support, supportError, canWrite, canExport, refresh, onChanged, onNavigate }) {
  const definition = ADMIN_REGISTERS[kind], id = useId();
  const preferences=useTablePreferences("admin."+kind);
  const base = { q: "", dateFrom: "", dateTo: "", ...Object.fromEntries(definition.filters.map(field => [field.key, ""])), ...initial };
  const [draft, setDraft] = useState(base), [criteria, setCriteria] = useState(base);
  const [grid, setGrid] = useState({ take: 25, skip: 0, sortBy: definition.sort[0], sortDir: definition.sort[1] });
  const [rows, setRows] = useState([]), [meta, setMeta] = useState(null), [loading, setLoading] = useState(true), [error, setError] = useState("");
  const [retry, setRetry] = useState(0), [editor, setEditor] = useState(null), [deactivation, setDeactivation] = useState(null), [feedback, setFeedback] = useState("");
  const [filtersOpen, setFiltersOpen] = useState(false), [columnsOpen, setColumnsOpen] = useState(false), anchor = useRef(null);
  const [visible, setVisible] = useState(definition.visible), [density, setDensity] = useState(() => preference("sauverndeko.table.density", "compact"));
  const [selected, setSelected] = useState([]), [selectionReset, setSelectionReset] = useState(0);
  const [exporting, setExporting] = useState(false), [exportError, setExportError] = useState(""), exportRequest = useRef(null);
  const pending = JSON.stringify(draft) !== JSON.stringify(criteria);
  const appliedCount = Object.values(criteria).filter(value => value !== "" && value != null).length;
  const effectiveWrite = canWrite && meta?.canManage !== false;
  const mayEdit = row => effectiveWrite && Boolean(definition.editor) && (kind !== "parametres" || row.IsEditable === true);
  const mayDeactivate = row => mayEdit(row) && (kind !== "parametres" || row.IsSystem !== true);
  function changeGrid(patch) { setGrid(old => ({ ...old, ...patch })); }
  function apply() { setCriteria({ ...draft, q: draft.q.trim() }); changeGrid({ skip: 0 }); }
  function reset() { const empty = Object.fromEntries(Object.keys(base).map(key => [key, ""])); setDraft(empty); setCriteria(empty); changeGrid({ skip: 0 }); }
  function removeFilter(key) { setDraft(old => ({ ...old, [key]: "" })); setCriteria(old => ({ ...old, [key]: "" })); changeGrid({ skip: 0 }); }
  function open(row, mode = "view") { setEditor({ row, mode, id: row?.[definition.pk] ?? null }); }
  useEffect(() => { try { localStorage.setItem("sauverndeko.table.density", density); } catch { /* Préférence locale facultative. */ } }, [density]);
  useEffect(() => {
    let current = true; const controller = new AbortController();
    setLoading(true); setError(""); setSelectionReset(value => value + 1);
    requestJson(ADMIN_ROOT + "/registres/" + kind + "?" + serializeCriteria(criteria, grid), { requiresAuth: true, signal: controller.signal }).then(result => {
      if (!current) return;
      if (!result?.success) {
        if ([401, 403].includes(result?.status)) { setRows([]); setMeta(null); setSelected([]); }
        setError(result?.message || "La liste n’a pas pu être chargée."); setLoading(false); return;
      }
      const total = Number(result.meta?.filteredCount || 0);
      if (grid.skip && grid.skip >= total) { changeGrid({ skip: Math.max(0, (Math.ceil(total / grid.take) - 1) * grid.take) }); return; }
      setRows(result.data || []); setMeta(result.meta); setLoading(false);
    });
    return () => { current = false; controller.abort(); };
  }, [kind, criteria, grid, refresh, retry]);
  useEffect(() => { exportRequest.current?.abort(); setExporting(false); setExportError(""); return () => exportRequest.current?.abort(); }, [criteria, grid.sortBy, grid.sortDir]);
  async function exportExcel(format="xlsx",selection=null) {
    if(pending||exporting||loading||error||!canExport||!preferences.ready||!preferences.canExport||!preferences.exportKeys.length)return;
    const controller=new AbortController();exportRequest.current?.abort();exportRequest.current=controller;setExporting(true);setExportError("");
    const params=serializeCriteria(criteria,{sortBy:grid.sortBy,sortDir:grid.sortDir},preferences.exportKeys);
    if(selection)params.set("selection",JSON.stringify(selection.map(row=>row[definition.pk])));
    try{await downloadApiFile(ADMIN_ROOT+"/registres/"+kind+"/export."+format+"?"+params,{signal:controller.signal});}
    catch(failure){if(!controller.signal.aborted)setExportError(failure.message||"L’export n’a pas abouti.");}
    finally{if(exportRequest.current===controller){exportRequest.current=null;setExporting(false);}}
  }
  const columns = [...definition.columns, {
    key: "actions", label: "Actions", width: 120, sortable: false,
    render: row => <div className="erp-row-actions" onClick={event => event.stopPropagation()}>
      <button type="button" className="erp-row-consult" aria-label={"Consulter " + recordName(kind, row)} onClick={() => open(row)}><AppIcon name="eye" size={17}/></button>
      <RowActionsMenu label={recordName(kind, row)} items={[
        { label: "Consulter", icon: "eye", onSelect: () => open(row) },
        ...(definition.editor ? [{ label: "Modifier", icon: "edit", disabled: !mayEdit(row), reason: kind === "parametres" && row.IsEditable !== true ? "Ce réglage est protégé." : "Accès en consultation", onSelect: () => open(row, "edit") }] : []),
        ...(definition.active ? [{ label: "Désactiver", icon: "close", disabled: !mayDeactivate(row) || row[definition.active] === false, reason: row[definition.active] === false ? "Déjà inactif" : kind === "parametres" && row.IsSystem === true ? "Ce paramètre système doit être conservé." : "Accès en consultation", onSelect: () => setDeactivation(row) }] : []),
        ...(kind === "roles" ? [{ label: "Voir les permissions", icon: "lock", onSelect: () => onNavigate("permissions") }] : []),
        ...(kind === "licences" ? [{ label: "Applications de la licence", icon: "apps", onSelect: () => onNavigate("licence-applications") }] : []),
      ]}/>
    </div>,
  }];
  function saved() { setEditor(null); setFeedback("Modifications enregistrées."); onChanged(); }
  function describe(key, value) {
    if (key === "q") return "Recherche : " + value;
    if (key === "dateFrom") return "Du " + formatDate(value);
    if (key === "dateTo") return "Au " + formatDate(value);
    const field = definition.filters.find(item => item.key === key);
    const label = field?.label || definition.columns.find(column => column.key === key)?.label || key;
    const rendered = field && optionsFor(field, support).find(option => String(option.value) === String(value))?.label;
    return label + " : " + (rendered || (String(value) === "true" ? "Oui" : String(value) === "false" ? "Non" : String(value)));
  }
  return <>
    {feedback ? <div className="admin-feedback" role="status"><AppIcon name="check-circle"/><span>{feedback}</span><button type="button" aria-label="Fermer le message" onClick={() => setFeedback("")}><AppIcon name="close"/></button></div> : null}
    <RegisterSurface title={definition.title} subtitle={definition.description} actions={<>
      <RegisterSettingsButton buttonRef={anchor} expanded={columnsOpen} onTableSettings={()=>setColumnsOpen(true)}/>
      {kind === "parametres" ? <ActionButton icon="clock" onClick={() => onNavigate("audit-parametres")}>Historique</ActionButton> : null}
      {kind === "licences" ? <Link className="ui-action is-secondary" to="/abonnements"><AppIcon name="apps"/>Applications</Link> : null}
      {definition.create ? <ActionButton icon="plus" variant="primary" disabled={!effectiveWrite || Boolean(error)} onClick={() => open(null, "create")}>{definition.create}</ActionButton> : null}
    </>}>
      <div className="admin-register-context"><AppIcon name={definition.platform ? "shield" : "apps"}/><span>{definition.platform ? "Administration de la plateforme" : "Données des entreprises autorisées"}</span>{!definition.editor ? <span className="admin-context-note">Consultation</span> : null}</div>
      <div className="erp-register-table erp-results" data-density={density} aria-busy={loading}>
        {selected.length ? <div className="erp-register-selection"><strong>{selected.length} {selected.length > 1 ? "lignes sélectionnées" : "ligne sélectionnée"}</strong>{canExport?<><ActionButton icon="download" disabled={loading||pending||exporting||!preferences.ready||!preferences.canExport||!preferences.exportKeys.length||Boolean(error)} onClick={()=>exportExcel("xlsx",selected)}>Excel · sélection</ActionButton><ActionButton icon="download" disabled={loading||pending||exporting||!preferences.ready||!preferences.canExport||!preferences.exportKeys.length||Boolean(error)} onClick={()=>exportExcel("csv",selected)}>CSV · sélection</ActionButton></>:null}{selected.length === 1 ? <><ActionButton icon="eye" disabled={loading} onClick={() => open(selected[0])}>Consulter</ActionButton>{definition.editor ? <ActionButton icon="edit" disabled={loading || !mayEdit(selected[0])} onClick={() => open(selected[0], "edit")}>Modifier</ActionButton> : null}</> : null}<ActionButton icon="close" className="is-icon" aria-label="Effacer la sélection" onClick={() => setSelectionReset(value => value + 1)}/></div> : null}
        {error ? <div className="admin-error" role="alert"><span>{error}</span><ActionButton icon="refresh" disabled={loading} onClick={() => setRetry(value => value + 1)}>Réessayer</ActionButton></div> : null}
        <SimpleTable tablePreferences={preferences} rows={rows} columns={columns} getRowId={row => row[definition.pk]} enableSelection onSelectionChange={setSelected} selectionResetKey={selectionReset} defaultVisibleColumns={definition.visible} defaultPinnedColumns={[]} serverMeta={meta} serverState={grid} onServerChange={changeGrid} onRowConsult={row => open(row)} consultColumns={[definition.name]} loading={loading} emptyMessage={error ? "Les données ne sont pas disponibles." : "Aucun résultat pour ces critères."} columnsPanelOpen={columnsOpen} columnsAnchorRef={anchor} onColumnsPanelClose={() => setColumnsOpen(false)} onVisibleColumnsChange={setVisible} toolbar={<>
          <DataTableToolbar showSettings={false} settingsLabel="Réglages" search={draft.q} setSearch={q => setDraft(old => ({ ...old, q }))} onApply={apply} onReset={reset} pending={pending} take={grid.take} onTake={take => changeGrid({ take, skip: 0 })} filtersOpen={filtersOpen} toggleFilters={() => setFiltersOpen(value => !value)} filterControlsId={id + "-filters"} activeFilters={appliedCount} density={density} toggleDensity={() => setDensity(value => value === "airy" ? "compact" : "airy")} columnsOpen={columnsOpen} columnsButtonRef={anchor} toggleColumns={() => setColumnsOpen(value => !value)} loading={loading} placeholder="Rechercher dans ce registre…" exportFile={canExport ? ()=>exportExcel() : undefined} exportCsv={canExport ? ()=>exportExcel("csv") : undefined} exporting={exporting} exportDisabled={Boolean(error) || !meta?.filteredCount || !preferences.ready || !preferences.canExport || !preferences.exportKeys.length} error={exportError||preferences.error}/>
          {filtersOpen ? <form className="erp-register-filters" id={id + "-filters"} onSubmit={event => { event.preventDefault(); apply(); }}><div className="erp-register-filter-grid">
            {definition.filters.map(field => <label key={field.key}><span>{field.label}</span><SearchSelect label={field.label} value={draft[field.key] ?? ""} options={[{ value: "", label: "Tous" }, ...optionsFor(field, support)]} onChange={value => setDraft(old => ({ ...old, [field.key]: value }))}/></label>)}
            {definition.dateKey ? <><label><span>{kind === "licences" ? "Échéance à partir du" : "Du"}</span><input type="date" value={draft.dateFrom} onChange={event => setDraft(old => ({ ...old, dateFrom: event.target.value }))}/></label><label><span>{kind === "licences" ? "Échéance jusqu’au" : "Au"}</span><input type="date" value={draft.dateTo} min={draft.dateFrom || undefined} onChange={event => setDraft(old => ({ ...old, dateTo: event.target.value }))}/></label></> : null}
          </div>{supportError ? <p className="erp-table-error">{supportError}</p> : null}<div className="erp-register-filters-footer"><ActionButton type="submit" variant="primary" disabled={loading}>Appliquer les filtres</ActionButton></div></form> : null}
          {appliedCount ? <div className="erp-register-chips">{Object.entries(criteria).filter(([, value]) => value !== "" && value != null).map(([key, value]) => <span key={key} className="erp-register-chip">{describe(key, value)}<button type="button" aria-label={"Retirer le filtre " + (definition.filters.find(field => field.key === key)?.label || key)} onClick={() => removeFilter(key)}><AppIcon name="close" size={13}/></button></span>)}</div> : null}
        </>}/>
      </div>
    </RegisterSurface>
    {editor ? definition.editor ? <AdminRecordEditor type={definition.editor} recordId={editor.id} row={editor.row} mode={editor.mode} support={support} canWrite={effectiveWrite} onClose={() => setEditor(null)} onSaved={saved}/> : <AdminReadDrawer kind={kind} row={editor.row} onClose={() => setEditor(null)}/> : null}
    {deactivation ? <DeactivateReference kind={kind} row={deactivation} canWrite={mayDeactivate(deactivation)} onClose={() => setDeactivation(null)} onSaved={() => { setDeactivation(null); setFeedback("Désactivation enregistrée."); onChanged(); }}/> : null}
  </>;
}

function DeactivateReference({ kind, row, canWrite, onClose, onSaved }) {
  const [busy, setBusy] = useState(false), [error, setError] = useState(""), lock = useRef(false), definition = ADMIN_REGISTERS[kind];
  async function submit() {
    if (!canWrite || lock.current) return;
    lock.current = true; setBusy(true); setError("");
    let result;
    try {
      if (["utilisateurs", "profils"].includes(kind)) result = await deleteAdminUser(row.IdUser);
      else if (kind === "entites") result = await deleteAdminEntity(row.IdEntite);
      else if (kind === "licences") result = await deleteAdminLicence(row.IdLicence);
      else if (kind === "correspondances") result = await updateAdminModelRecord("T_Fk_Correspondance", row.IdFkCorrespondance, { ValideFkCorrespondance: false });
      else if (kind === "parametres") result = await updateAdminModelRecord("T_Admin_UI_Setting", row.IdAdminUISetting, { ValideSetting: false });
      else result = await deleteAdminModelRecord("T_Generique", row.ID_Generique);
      if (result?.success) onSaved(); else setError(result?.message || "La désactivation n’a pas abouti.");
    } finally { lock.current = false; setBusy(false); }
  }
  return <RecordEditorFrame title="Désactiver la fiche" subtitle={recordName(kind, row)} icon="close" defaultWidth={600} onClose={onClose} onSubmit={submit} submitLabel="Désactiver" busy={busy} canSubmit={canWrite} error={error}><section className="record-editor-section"><p>Désactiver « {recordName(kind, row)} » ?</p><p className="record-editor-note">La fiche et son historique sont conservés.</p></section></RecordEditorFrame>;
}

function AdminReadDrawer({ kind, row, onClose }) {
  const definition = ADMIN_REGISTERS[kind];
  const [record, setRecord] = useState(null), [loading, setLoading] = useState(true), [error, setError] = useState(""), [retry, setRetry] = useState(0);
  useEffect(() => {
    let current = true; setRecord(null); setLoading(true); setError("");
    requestJson(ADMIN_ROOT + "/registres/" + kind + "/" + encodeURIComponent(row[definition.pk]), { requiresAuth: true }).then(result => { if (!current) return; if (result?.success) setRecord(result.data); else setError(result?.message || "La fiche est indisponible."); setLoading(false); });
    return () => { current = false; };
  }, [kind, row, retry]);
  return <RecordEditorFrame title={definition.title} subtitle={recordName(kind, row)} icon={definition.icon} onClose={onClose} readOnly loading={loading} error={error} onReload={error ? () => setRetry(value => value + 1) : null} defaultWidth={850}>
    {record ? <><section className="record-editor-section"><h3><AppIcon name={definition.icon}/>Informations</h3><div className="admin-detail-grid">{definition.columns.map(column => <div key={column.key}><span>{column.label}</span><strong>{column.render ? column.render(record) : record[column.key] == null || record[column.key] === "" ? "—" : String(record[column.key])}</strong></div>)}</div></section>{["OldData", "NewData"].filter(key => record[key] != null).map(key => <section className="record-editor-section" key={key}><h3>{key === "OldData" ? "Avant la modification" : "Après la modification"}</h3><pre className="admin-audit-payload">{JSON.stringify(record[key], null, 2)}</pre></section>)}</> : null}
  </RecordEditorFrame>;
}

const METRICS = [
  ["users", "Utilisateurs", "user", "utilisateurs"], ["entities", "Entreprises", "apps", "entites"],
  ["activeLicences", "Licences actives", "check-circle", "licences", { statut_licence: "Active" }], ["expiredLicences", "Licences expirées", "alert", "licences", { ExpireeLicence: "true" }],
  ["loginsToday", "Connexions du jour", "clock", "connexions"], ["auditEvents", "Événements d’audit", "document", "audit"],
  ["fkMappings", "Correspondances FK actives", "movements", "correspondances", { ValideFkCorrespondance: "true" }], ["settings", "Paramètres UI actifs", "settings", "parametres", { ValideSetting: "true" }],
];
function AdminDashboard({ onNavigate, refresh, platform }) {
  const [data, setData] = useState(null), [loading, setLoading] = useState(true), [error, setError] = useState(""), [retry, setRetry] = useState(0);
  useEffect(() => { let current = true; setLoading(true); setError(""); requestJson(ADMIN_ROOT + "/synthese", { requiresAuth: true }).then(result => { if (!current) return; if (result?.success) setData(result.data); else setError(result?.message || "La synthèse n’a pas pu être chargée."); setLoading(false); }); return () => { current = false; }; }, [refresh, retry]);
  const roles = data?.roleDistribution || [], activity = data?.activity || [], max = Math.max(1, ...activity.map(day => Number(day.logins || 0) + Number(day.audit || 0)));
  function openMetric(key, target, initial) {
    if (key === "loginsToday") { const today = new Intl.DateTimeFormat("sv-SE", { timeZone: "Africa/Kinshasa" }).format(new Date(data.generatedAt)); onNavigate(target, { dateFrom: today, dateTo: today, TypeLogin: "Connexion" }); }
    else onNavigate(target, initial || {});
  }
  return <div className="admin-dashboard">
    <header className="erp-register-heading"><div><h1>Tableau de bord</h1><p>Les accès et l’activité de la plateforme.</p></div>{data?.generatedAt ? <span className="admin-updated"><AppIcon name="clock"/>Situation au {formatDate(data.generatedAt, { withTime: true })}</span> : null}</header>
    {error ? <div className="admin-error" role="alert"><span>{error}</span><ActionButton icon="refresh" disabled={loading} onClick={() => setRetry(value => value + 1)}>Réessayer</ActionButton></div> : null}
    <div className="admin-metrics" aria-busy={loading}>{METRICS.filter(([key]) => platform || !["auditEvents", "fkMappings", "settings", "loginsToday"].includes(key)).map(([key, label, icon, target, initial]) => <button key={key} type="button" className={"admin-metric metric-" + key} disabled={loading || data?.metrics?.[key] == null} onClick={() => openMetric(key, target, initial)}><span className="admin-metric-icon"><AppIcon name={icon} size={20}/></span><span><small>{label}</small><strong>{numeric(data?.metrics?.[key])}</strong></span><AppIcon name="chevron-right" size={15}/></button>)}</div>
    {loading && !data ? <div className="admin-dashboard-placeholder" role="status">Chargement de la synthèse…</div> : data ? <>
      <div className="admin-dashboard-grid">
        <section className="admin-dashboard-panel"><header><h2><AppIcon name="chart"/>Activité des 7 derniers jours</h2></header><div className="admin-activity">{activity.length ? activity.map(day => <div key={day.date} role="img" aria-label={formatDate(day.date) + " : " + day.audit + " événements d’audit et " + day.logins + " événements de connexion"}><span className="admin-activity-bars"><span className="is-audit" style={{ height: (Number(day.audit || 0) / max * 100) + "%" }}/><span className="is-login" style={{ height: (Number(day.logins || 0) / max * 100) + "%" }}/></span><strong>{numeric(Number(day.logins || 0) + Number(day.audit || 0))}</strong><small>{formatDate(day.date)}</small></div>) : <p className="admin-empty">Aucune activité enregistrée sur cette période.</p>}</div><div className="admin-chart-legend"><span>Audit</span><span>Connexions</span></div></section>
        <section className="admin-dashboard-panel"><header><h2><AppIcon name="shield"/>Répartition des rôles</h2>{platform ? <button type="button" onClick={() => onNavigate("roles")}>Voir les rôles<AppIcon name="chevron-right"/></button> : null}</header><div className="admin-role-list">{roles.length ? roles.map((role, index) => <div key={role.IdRoleFk ?? index}><span className={"admin-role-dot tone-" + index % 5}/><span>{role.Role || "Sans rôle"}</span><strong>{numeric(role.count)}</strong></div>) : <p className="admin-empty">Aucun utilisateur à répartir.</p>}</div></section>
      </div>
      <section className="admin-dashboard-panel"><header><h2><AppIcon name="shield"/>Licences proches de l’échéance</h2><button type="button" onClick={() => onNavigate("licences")}>Toutes les licences<AppIcon name="chevron-right"/></button></header><div className="erp-results"><SimpleTable rows={data.expiringLicences || []} columns={[{ key: "IdLicence", label: "Licence", render: row => "Licence #" + row.IdLicence }, { key: "NomEntite", label: "Entreprise" }, { key: "DateFin", label: "Échéance", render: row => formatDate(row.DateFin, { withTime: true }) }, { key: "statut_licence", label: "Statut" }]} getRowId={row => row.IdLicence} onRowConsult={row => onNavigate("licences", { IdLicence: String(row.IdLicence) })} consultColumns={["IdLicence"]} showControls={false} defaultRowsPerPage={5} emptyMessage="Aucune licence proche de l’échéance."/></div></section>
      {platform ? <section className="admin-dashboard-panel"><header><h2><AppIcon name="document"/>Dernières opérations</h2><button type="button" onClick={() => onNavigate("audit")}>Tout l’audit<AppIcon name="chevron-right"/></button></header><div className="erp-results"><SimpleTable rows={data.recentAudit || []} columns={[{ key: "ChangedAt", label: "Date et heure", render: row => formatDate(row.ChangedAt, { withTime: true }) }, { key: "TableName", label: "Objet" }, { key: "Operation", label: "Opération" }, { key: "NomEntite", label: "Entreprise" }]} getRowId={row => row.IdLog} showControls={false} defaultRowsPerPage={5} emptyMessage="Aucune opération enregistrée."/></div></section> : null}
    </> : null}
  </div>;
}

/** Administration dédiée ; les écrans métier conservent leurs modules distincts. */
export default function AdminPortal() {
  const { user } = useAuth(), [params, setParams] = useSearchParams(), navigateRoute = useNavigate();
  const platform = Boolean(user?.moduleAccess?.platformAdmin || user?.Is_Admin === true);
  const key = adminTabKey(params.get("onglet")) || "tableau-de-bord";
  const allKeys = ["tableau-de-bord", "permissions", "messagerie", ...Object.keys(ADMIN_REGISTERS)];
  const active = allKeys.includes(key) ? key : "tableau-de-bord";
  const restricted = (ADMIN_REGISTERS[active]?.platform || ["permissions", "messagerie"].includes(active)) && !platform;
  const [collapsed, setCollapsed] = useState(() => preference("sauverndeko.admin.sidebar-collapsed", "false") === "true");
  const [refresh, setRefresh] = useState(0), [mail, setMail] = useState(false), [permissionsDirty, setPermissionsDirty] = useState(false), [permissionsBusy, setPermissionsBusy] = useState(false), [transition, setTransition] = useState(null);
  const [initial, setInitial] = useState({}), [navigationVersion, setNavigationVersion] = useState(0);
  const { support, setSupport, error: supportError } = useAdminSupport(refresh);
  const [locationSupportReady, setLocationSupportReady] = useState(false);
  useReferencesRefresh(() => setRefresh(value => value + 1));
  useEffect(() => {
    if (params.get("onglet") !== "profils") return;
    const next = new URLSearchParams(params); next.set("onglet", "utilisateurs");
    setParams(next, { replace: true });
  }, [params, setParams]);
  useEffect(() => { try { localStorage.setItem("sauverndeko.admin.sidebar-collapsed", String(collapsed)); } catch { /* Préférence locale facultative. */ } }, [collapsed]);
  useEffect(() => {
    if (active !== "localisations" || locationSupportReady) return;
    let current = true;
    async function complete(model) { const rows = []; let skip = 0; while (true) { const result = await fetchAdminModelList(model, { take: 500, skip }); if (!result?.success) throw new Error(result?.message || "Localisations indisponibles."); rows.push(...result.data); const count = Number(result.meta?.filteredCount ?? result.meta?.totalCount); if ((Number.isFinite(count) && rows.length >= count) || !result.data.length || (!Number.isFinite(count) && result.data.length < 500)) return rows; skip += result.data.length; } }
    Promise.all([complete("T_Niveau_3"), complete("T_Niveau_4"), complete("T_Niveau_5")]).then(([niveaux3, niveaux4, niveaux5]) => { if (current) { setSupport(old => ({ ...old, niveaux3, niveaux4, niveaux5 })); setLocationSupportReady(true); } }).catch(() => { /* Le formulaire indique la liste manquante. */ });
    return () => { current = false; };
  }, [active, locationSupportReady, setSupport]);
  function requestTransition(run) { if (permissionsBusy) return; if (permissionsDirty) setTransition({ run }); else run(); }
  function navigate(next, criteria = {}) {
    next = adminTabKey(next);
    if (next === "licence-applications") { requestTransition(() => navigateRoute("/abonnements")); return; }
    if (next === active && !Object.keys(criteria).length) return;
    requestTransition(() => { setInitial(criteria); setNavigationVersion(value => value + 1); setParams({ onglet: next }); });
  }
  function guardLinks(event) {
    if (!permissionsDirty && !permissionsBusy) return;
    const link = event.target.closest?.("a[href]"); if (!link || event.defaultPrevented || event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
    const target = new URL(link.href, window.location.href);
    if (target.origin !== window.location.origin || link.target === "_blank") return;
    event.preventDefault(); event.stopPropagation(); requestTransition(() => navigateRoute(target.pathname + target.search + target.hash));
  }
  const definition = ADMIN_REGISTERS[active];
  const canWrite = Boolean(user?.permissions?.canWriteData) && (!(definition?.platform || definition?.platformWrite) || platform);
  return <div className={"logistics-modern logistics-app admin-portal" + (collapsed ? " is-menu-collapsed" : "")} onClickCapture={guardLinks}>
    <aside className={"logistics-sidebar-shell" + (collapsed ? " is-collapsed" : "")}>
      <div className="logistics-sidebar-top"><Link className="logistics-brand-lockup" to="/" aria-label="SauverNdeko — Applications"><img className="logistics-brand-logo" src="/sauverndeko-logo.jpg" alt="" width="34" height="34"/>{!collapsed ? <div className="logistics-brand-copy"><strong>SauverNdeko</strong><span>Administration</span></div> : null}</Link><button type="button" className="logistics-sidebar-toggle" onClick={() => setCollapsed(value => !value)} aria-label={collapsed ? "Afficher le menu Administration" : "Replier le menu Administration"} title={collapsed ? "Déplier" : "Replier"}><AppIcon name="sidebar"/></button></div>
      <nav className="logistics-sidebar-nav" aria-label="Menu Administration">{ADMIN_NAVIGATION.map(group => <div className="logistics-nav-group" key={group.label}>{!collapsed ? <span className="logistics-nav-heading">{group.label}</span> : null}{group.items.filter(item => !item.platform || platform).map(item => <button type="button" key={item.key} className={"logistics-sidebar-link" + (active === item.key ? " is-active" : "")} title={item.label} aria-label={item.label} aria-current={active === item.key ? "page" : undefined} onClick={() => navigate(item.key)}><span className="logistics-sidebar-icon"><AppIcon name={item.icon} size={18}/></span>{!collapsed ? <span className="logistics-sidebar-label">{item.label}</span> : null}</button>)}</div>)}</nav>
      <div className="logistics-app-switcher"><Link to="/logistique" title="Logistique" aria-label="Logistique"><span><AppIcon name="box"/></span>{!collapsed ? <><span>Logistique</span><AppIcon name="arrow-up-right"/></> : null}</Link>{platform ? <Link to="/referentiels" title="Référentiels" aria-label="Référentiels"><span><AppIcon name="tag"/></span>{!collapsed ? <><span>Référentiels</span><AppIcon name="arrow-up-right"/></> : null}</Link> : null}<Link to="/" title="Applications" aria-label="Toutes les applications"><span><AppIcon name="apps"/></span>{!collapsed ? <><span>Applications</span><AppIcon name="arrow-up-right"/></> : null}</Link></div>
    </aside>
    <ModuleHeader title="Administration" onRequestLogout={requestTransition}/>
    <main className="admin-main">
      {restricted ? <section className="admin-error" role="alert">Cette rubrique est réservée à l’administration de la plateforme.</section> : active === "tableau-de-bord" ? <AdminDashboard refresh={refresh} platform={platform} onNavigate={navigate}/> : active === "permissions" ?  <><header className="erp-register-heading"><div><h1>Permissions</h1><p>Les droits des rôles par entreprise.</p></div></header><AdminPermissions canWrite={canWrite} onChanged={() => setRefresh(value => value + 1)} onDirtyChange={setPermissionsDirty} onBusyChange={setPermissionsBusy}/></> : active === "messagerie" ? <RegisterSurface title="Messagerie" subtitle="L’expéditeur et le service d’envoi de la plateforme." actions={<ActionButton icon="settings" variant="primary" onClick={() => setMail(true)}>Ouvrir les réglages</ActionButton>}><div className="admin-mail-intro"><span className="admin-metric-icon"><AppIcon name="mail" size={26}/></span><div><h2>E-mails de l’application</h2><p>Adresse expéditrice et diagnostic de connexion.</p></div></div></RegisterSurface> : <AdminRegister key={active + ":" + navigationVersion} kind={active} initial={initial} support={support} supportError={supportError} refresh={refresh} onChanged={() => setRefresh(value => value + 1)} canWrite={canWrite} canExport={user?.permissions?.canExportData === true} onNavigate={navigate}/>}
    </main>
    {mail ? <AdminMailSettings onClose={() => setMail(false)}/> : null}
    {transition ? <RecordEditorFrame title="Modifications non enregistrées" icon="alert" defaultWidth={560} onClose={() => setTransition(null)} onSubmit={() => { const run = transition.run; setTransition(null); setPermissionsDirty(false); run(); }} submitLabel="Abandonner les modifications" canSubmit><section className="record-editor-section"><p>Quitter sans enregistrer les permissions modifiées ?</p></section></RecordEditorFrame> : null}
  </div>;
}
