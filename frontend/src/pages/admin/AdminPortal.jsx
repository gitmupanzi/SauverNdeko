import AdminRecordEditor from "./AdminRecordEditor";
import AdminDashboard from "./AdminDashboard";
import {moduleRights} from "../../services/moduleAccess";
import ModuleSidebar from "../../components/ModuleSidebar";
import AdminBatchComposer from "./AdminBatchComposer";
import {ADMIN_BATCH,normalizeAdminSupport} from "./adminBatchForm";
import {useEntityScope} from "../../contexts/EntityScopeContext";
import {referenceOptions} from "../../utils/referenceOptions";
import useTablePreferences from "../../hooks/useTablePreferences";
import { useEffect, useId, useRef, useState } from "react";
import { Link, useNavigate, useSearchParams } from "react-router-dom";
import { useAuth } from "../../contexts/AuthContext";
import AppIcon from "../../components/AppIcon";
import ActionButton from "../../components/ActionButton";
import RegisterSurface from "../../components/RegisterSurface";
import RegisterSettingsButton from "../../components/RegisterSettingsButton";
import DataTableToolbar from "../../components/DataTableToolbar";
import ExportMenu from "../../components/ExportMenu";
import RowActionsMenu from "../../components/RowActionsMenu";
import SearchSelect from "../../components/SearchSelect";
import RecordEditorFrame from "../../components/RecordEditorFrame";
import useReferencesRefresh from "../../hooks/useReferencesRefresh";
import lazyView from "../../components/LazyView";
import { requestJson, downloadApiFile, deleteAdminUser, deleteAdminEntity, deleteAdminLicence, deleteAdminModelRecord, updateAdminModelRecord } from "../../services/api";
import { SimpleTable, formatDate } from "../logistique/logistiqueShared";
import { ADMIN_ROOT, ADMIN_NAVIGATION, ADMIN_REGISTERS, adminTabKey } from "./adminPortalDefinitions";
import "../logistique/LogistiqueModern.css";
import "./AdminPortal.css";


const AdminPermissions = lazyView(() => import("./AdminPermissions"), { compact: true, label: "Chargement des permissions…" });
const AdminMailSettings = lazyView(() => import("../../components/AdminMailSettings"), { compact: true, label: "Ouverture de la messagerie…" });
const preference = (key, fallback) => { try { return localStorage.getItem(key) || fallback; } catch { return fallback; } };
const fullName = row => [row?.PrenomUser, row?.NomUser].filter(Boolean).join(" ");
function recordName(kind, row) { return kind === "licences" ? "Licence #" + row.IdLicence : ["utilisateurs", "profils", "connexions"].includes(kind) ? fullName(row) : row[ADMIN_REGISTERS[kind].name] || row.SettingKey || row.FieldName || "Fiche"; }
function useAdminSupport(refresh,kind) {
  const scope=useEntityScope(),identity=scope.scopeKey+":"+kind,empty={entities:[],generics:[],categories:[],referenceOptions:{},personnelServices:[],personnelFonctions:[]};
  const [loaded,setLoaded]=useState({identity:"",support:empty,error:""});
  useEffect(()=>{const controller=new AbortController();requestJson(ADMIN_ROOT+"/references/"+(ADMIN_BATCH[kind]?kind:"utilisateurs"),{requiresAuth:true,signal:controller.signal}).then(result=>{if(controller.signal.aborted)return;setLoaded({identity,support:result?.success?normalizeAdminSupport(result.data):empty,error:result?.success?"":result?.message||"Certaines listes de référence sont indisponibles."});});return()=>controller.abort();},[refresh,identity,kind]);
  return loaded.identity===identity?loaded:{support:empty,error:""};
}
function optionsFor(field, support) {
  if (field.options) return field.options;
  if (field.source === "entities") return (support.entities||[]).map(row => ({ value: String(row.IdEntite), label: row.NomEntite }));
  if (field.source === "categories") return (support.categories||[]).map(row => ({ value: String(row.ID_CategorieGenerique), label: row.NomCategorieGenerique }));
  if (field.source === "roles") return [{value:"__null__",label:"Sans rôle"},...referenceOptions(support.referenceOptions?.roles||[])];
  if(["personnelServices","personnelFonctions"].includes(field.source))return (support[field.source]||[]).map(row=>({value:String(row.id),label:row.label,disabled:row.disabled===true}));
  return [];
}
export function serializeCriteria(criteria, grid, columns) {
  const { q, dateFrom, dateTo, ...filters } = criteria;
  const normalized = Object.fromEntries(Object.entries(filters).filter(([, value]) => value !== "" && value != null).map(([key, value]) => [key, value === "__null__" ? null : value === "true" ? true : value === "false" ? false : value]));
  return new URLSearchParams({ q: q || "", filters: JSON.stringify(normalized), ...grid, ...(dateFrom ? { dateFrom } : {}), ...(dateTo ? { dateTo } : {}), ...(columns ? { columns: JSON.stringify(columns) } : {}) });
}

function AdminRegister({ kind, initial = {}, support, supportError, canWrite, canExport, refresh, onChanged, onNavigate }) {
  const definition = ADMIN_REGISTERS[kind], id = useId(),scope=useEntityScope();
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
  const mayEdit = row => effectiveWrite && Boolean(definition.editor) && (kind!=="utilisateurs"||scope.globalAdmin||row.Is_Admin!==true&&row.Is_staff!==true&&!/^(admin|administrateur|super.admin|superadmin|administrateur global|administrateur de la plateforme)$/i.test(row.Role||"")) && (kind !== "parametres" || row.IsEditable === true);
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
  }, [kind, criteria, grid, refresh, retry,scope.scopeKey]);
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
      {kind === "parametres" && scope.globalAdmin ? <ActionButton icon="clock" onClick={() => onNavigate("audit-parametres")}>Historique</ActionButton> : null}
      {kind === "licences" ? <Link className="ui-action is-secondary" to="/abonnements"><AppIcon name="apps"/>Applications</Link> : null}
      {definition.create ? <ActionButton icon="plus" variant="primary" disabled={!effectiveWrite || kind==="entites"&&!scope.globalAdmin || Boolean(error)} onClick={() => open(null, "create")}>{definition.create}</ActionButton> : null}
    </>}>
      <div className="admin-register-context"><AppIcon name={definition.platform ? "shield" : "apps"}/><span>{definition.platform ? "Administration de la plateforme" : kind==="roles"?"Rôles communs à la plateforme":["correspondances","parametres"].includes(kind)?"Réglages communs et de l’entreprise":"Données des entreprises autorisées"}</span>{!definition.editor ? <span className="admin-context-note">Consultation</span> : null}</div>
      <div className="erp-register-table erp-results" data-density={density} aria-busy={loading}>
        {selected.length ? <div className="erp-register-selection"><strong>{selected.length} {selected.length > 1 ? "lignes sélectionnées" : "ligne sélectionnée"}</strong>{canExport?<ExportMenu selection exportFile={()=>exportExcel("xlsx",selected)} exportCsv={()=>exportExcel("csv",selected)} disabled={loading||pending||exporting||!preferences.ready||!preferences.canExport||!preferences.exportKeys.length||Boolean(error)} exporting={exporting}/>:null}{selected.length === 1 ? <><ActionButton icon="eye" disabled={loading} onClick={() => open(selected[0])}>Consulter</ActionButton>{definition.editor ? <ActionButton icon="edit" disabled={loading || !mayEdit(selected[0])} onClick={() => open(selected[0], "edit")}>Modifier</ActionButton> : null}</> : null}<ActionButton icon="close" className="is-icon" aria-label="Effacer la sélection" onClick={() => setSelectionReset(value => value + 1)}/></div> : null}
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
    {editor ? editor.mode==="create"&&ADMIN_BATCH[kind]?<AdminBatchComposer kind={kind} onClose={()=>setEditor(null)} onSaved={saved}/>:definition.editor ? <AdminRecordEditor type={definition.editor} recordId={editor.id} row={editor.row} mode={editor.mode} support={{...support,platformAdmin:scope.globalAdmin,entityId:scope.entityId}} canWrite={effectiveWrite} onClose={() => setEditor(null)} onSaved={saved}/> : <AdminReadDrawer kind={kind} row={editor.row} onClose={() => setEditor(null)}/> : null}
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

/** Administration dédiée ; les écrans métier conservent leurs modules distincts. */
export default function AdminPortal() {
  const scope=useEntityScope();
  const { user } = useAuth(), [params, setParams] = useSearchParams(), navigateRoute = useNavigate();
  const platform = Boolean(user?.moduleAccess?.platformAdmin || user?.Is_Admin === true);
  const key = adminTabKey(params.get("onglet")) || "tableau-de-bord";
  const allKeys = ["tableau-de-bord", "permissions", "messagerie", ...Object.keys(ADMIN_REGISTERS)];
  const active = allKeys.includes(key) ? key : "tableau-de-bord";
  const restricted = (ADMIN_REGISTERS[active]?.platform || ["permissions", "messagerie"].includes(active)) && !platform;
  const [collapsed, setCollapsed] = useState(() => preference("sauverndeko.admin.sidebar-collapsed", "false") === "true");
  const [refresh, setRefresh] = useState(0), [mail, setMail] = useState(false), [permissionsDirty, setPermissionsDirty] = useState(false), [permissionsBusy, setPermissionsBusy] = useState(false), [transition, setTransition] = useState(null);
  const [initial, setInitial] = useState({}), [navigationVersion, setNavigationVersion] = useState(0);
  const { support, error: supportError } = useAdminSupport(refresh,active);
  useReferencesRefresh(() => setRefresh(value => value + 1));
  useEffect(() => {
    if (!["profils","localisations"].includes(params.get("onglet"))) return;
    const next = new URLSearchParams(params); next.set("onglet", adminTabKey(params.get("onglet")));
    setParams(next, { replace: true });
  }, [params, setParams]);
  useEffect(() => { try { localStorage.setItem("sauverndeko.admin.sidebar-collapsed", String(collapsed)); } catch { /* Préférence locale facultative. */ } }, [collapsed]);
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
  const canWrite = Boolean(user?.permissions?.canWriteData) && moduleRights(user,"administration").canManage===true && (!(definition?.platform || definition?.platformWrite) || platform);
  return <div className={"logistics-modern logistics-app admin-portal" + (collapsed ? " is-menu-collapsed" : "")} onClickCapture={guardLinks}>
    <ModuleSidebar headerProps={{onRequestLogout:requestTransition}} title="Administration" collapsed={collapsed} onToggle={()=>setCollapsed(value=>!value)} groups={ADMIN_NAVIGATION.map(group=>({...group,items:group.items.filter(item=>!item.platform||platform)}))} activeKey={active} onNavigate={navigate} storageKey="sauverndeko.admin.navigation"/>
    <main className="admin-main">
      {restricted ? <section className="admin-error" role="alert">Cette rubrique est réservée à l’administration de la plateforme.</section> : active === "tableau-de-bord" ? <AdminDashboard key={scope.scopeKey} refresh={refresh} platform={platform} onNavigate={navigate}/> : active === "permissions" ?  <><header className="erp-register-heading"><div><h1>Permissions</h1><p>Les droits des rôles par entreprise.</p></div></header><AdminPermissions canWrite={canWrite} onChanged={() => setRefresh(value => value + 1)} onDirtyChange={setPermissionsDirty} onBusyChange={setPermissionsBusy}/></> : active === "messagerie" ? <RegisterSurface title="Messagerie" subtitle="L’expéditeur et le service d’envoi de la plateforme." actions={<ActionButton icon="settings" variant="primary" onClick={() => setMail(true)}>Ouvrir les réglages</ActionButton>}><div className="admin-mail-intro"><span className="admin-metric-icon"><AppIcon name="mail" size={26}/></span><div><h2>E-mails de l’application</h2><p>Adresse expéditrice et diagnostic de connexion.</p></div></div></RegisterSurface> : <AdminRegister key={active + ":" + navigationVersion+":"+scope.scopeKey} kind={active} initial={initial} support={support} supportError={supportError} refresh={refresh} onChanged={() => setRefresh(value => value + 1)} canWrite={canWrite} canExport={user?.permissions?.canExportData === true} onNavigate={navigate}/>}
    </main>
    {mail ? <AdminMailSettings onClose={() => setMail(false)}/> : null}
    {transition ? <RecordEditorFrame title="Modifications non enregistrées" icon="alert" defaultWidth={560} onClose={() => setTransition(null)} onSubmit={() => { const run = transition.run; setTransition(null); setPermissionsDirty(false); run(); }} submitLabel="Abandonner les modifications" canSubmit><section className="record-editor-section"><p>Quitter sans enregistrer les permissions modifiées ?</p></section></RecordEditorFrame> : null}
  </div>;
}
