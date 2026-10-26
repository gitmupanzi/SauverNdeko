import { useEffect, useMemo, useRef, useState } from "react";
import { Link, useSearchParams } from "react-router-dom";
import ModuleHeader from "../components/ModuleHeader";
import AppIcon from "../components/AppIcon";
import ActionButton from "../components/ActionButton";
import RegisterSurface from "../components/RegisterSurface";
import DataTableToolbar from "../components/DataTableToolbar";
import RowActionsMenu from "../components/RowActionsMenu";
import SearchSelect from "../components/SearchSelect";
import RecordEditorFrame from "../components/RecordEditorFrame";
import lazyView from "../components/LazyView";
import { useAuth } from "../contexts/AuthContext";
import useReferencesRefresh from "../hooks/useReferencesRefresh";
import { fetchCompleteReferenceRows, fetchViewData, downloadApiFile } from "../services/api";
import { REFERENTIEL_ADMIN_SCHEMA } from "./admin/referentiel";
import { SimpleTable, exportRowsToCsv } from "./logistique/logistiqueShared";
import "./logistique/LogistiqueModern.css";
import "./referentiels/Referentiels.css";

const ReferenceEditor = lazyView(() => import("./referentiels/ReferenceEditor"), { label:"Ouverture de la fiche…", compact:true });
const DEFINITIONS = {
  values: { title:"Valeurs de référence", subtitle:"Les listes partagées de vos applications.", view:"V_Generique", pk:"ID_Generique", name:"NomGenerique", active:"ValideGenerique", icon:"list", create:"Nouvelle valeur", defaults:["NomCategorieGenerique","NomGenerique","AbrGenerique","ModuleCategorieGenerique","ValideGenerique","actions"] },
  categories: { title:"Catégories", subtitle:"Organisez les valeurs du référentiel par usage.", view:"V_CategorieGenerique", pk:"ID_CategorieGenerique", name:"NomCategorieGenerique", active:"ValideCategorieGenerique", icon:"folder", create:"Nouvelle catégorie", defaults:["NomCategorieGenerique","ModuleCategorieGenerique","ValideCategorieGenerique","actions"] },
};
const EMPTY_FILTERS = { category:"", state:"", module:"" };
const VISIBILITY = { VisibleArticle:"Articles", VisibleCmd:"Bons de stock", VisibleFacture:"Factures", VisibleUsers:"Utilisateurs", VisibleVoie:"Voies d’accès", VisibleAll:"Visibilité générale", VisibleNiveau_2:"Niveau territorial 2", VisibleNiveau_3:"Niveau territorial 3", VisibleNiveau_4:"Niveau territorial 4", VisibleNiveau_5:"Niveau territorial 5" };
function moduleLabel(value) { return String(value || "").trim() || "—"; }
function readPreference(key, fallback) { try { return localStorage.getItem(key) || fallback; } catch { return fallback; } }
function StateBadge({value}) { return value == null ? "—" : <span className={"erp-status is-"+(value?"success":"neutral")}>{value?"Actif":"Inactif"}</span>; }
function apiFilters(kind, criteria) {
  const definition=DEFINITIONS[kind], filters={};
  if(kind==="values" && criteria.category) filters.ID_CategorieGeneriqueFk=Number(criteria.category);
  if(criteria.state!=="") filters[definition.active]=criteria.state==="true";
  if(criteria.module) filters.ModuleCategorieGenerique=criteria.module;
  return filters;
}

function ReferenceRegister({kind,categories,initialCategory,onBrowseCategory,refresh,onChanged,categoryError}) {
  const {user}=useAuth(), definition=DEFINITIONS[kind];
  const canWrite=user?.Is_Admin===true && user?.permissions?.canWriteData===true;
  const canExport=user?.permissions?.canExportData===true;
  const [search,setSearch]=useState("");
  const [draft,setDraft]=useState({...EMPTY_FILTERS,category:initialCategory||""});
  const [criteria,setCriteria]=useState({...EMPTY_FILTERS,category:initialCategory||"",q:""});
  const [grid,setGrid]=useState({take:25,skip:0,sortBy:definition.name,sortDir:"asc"});
  const [rows,setRows]=useState([]),[meta,setMeta]=useState(null),[loading,setLoading]=useState(true),[error,setError]=useState("");
  const [retry,setRetry]=useState(0),[editor,setEditor]=useState(null),[deletion,setDeletion]=useState(null),[feedback,setFeedback]=useState("");
  const [filtersOpen,setFiltersOpen]=useState(false),[columnsOpen,setColumnsOpen]=useState(false),columnsAnchor=useRef(null);
  const [visibleColumns,setVisibleColumns]=useState(definition.defaults);
  const [density,setDensity]=useState(()=>readPreference("sauverndeko.table.density","compact"));
  const [selected,setSelected]=useState([]),[selectionReset,setSelectionReset]=useState(0);
  const [exporting,setExporting]=useState(false),[exportError,setExportError]=useState("");
  const exportRequest=useRef(null);
  const pending=search.trim()!==criteria.q || Object.keys(EMPTY_FILTERS).some(key=>draft[key]!==criteria[key]);
  const activeFilters=Number(Boolean(criteria.q))+Object.keys(EMPTY_FILTERS).filter(key=>Boolean(criteria[key])).length;
  const modules=useMemo(()=>[...new Set(categories.map(row=>row.ModuleCategorieGenerique).filter(Boolean))].sort(),[categories]);
  function changeGrid(patch) { setGrid(current=>({...current,...patch})); }
  function apply() { setCriteria({...draft,q:search.trim()});changeGrid({skip:0}); }
  function reset() { setSearch("");setDraft(EMPTY_FILTERS);setCriteria({...EMPTY_FILTERS,q:""});changeGrid({skip:0}); }
  function removeFilter(key) {
    if(key==="q")setSearch("");else setDraft(current=>({...current,[key]:""}));
    setCriteria(current=>({...current,[key]:""}));changeGrid({skip:0});
  }
  function open(row,mode="view") { setEditor({id:row?.[definition.pk]??null,mode}); }
  useEffect(()=>{try{localStorage.setItem("sauverndeko.table.density",density);}catch{}},[density]);
  useEffect(()=>{
    let current=true;
    setLoading(true);setError("");setSelectionReset(value=>value+1);
    fetchViewData("referentiel",definition.view,{...grid,q:criteria.q,filters:JSON.stringify(apiFilters(kind,criteria))}).then(response=>{
      if(!current)return;
      if(!response?.success){if([401,403].includes(response?.status)){setRows([]);setMeta(null);setSelected([]);setSelectionReset(value=>value+1);}setError(response?.message || "Le référentiel n’a pas pu être chargé.");setLoading(false);return;}
      const count=Number(response.meta?.filteredCount||0);
      if(grid.skip>0 && grid.skip>=count){changeGrid({skip:Math.max(0,(Math.ceil(count/grid.take)-1)*grid.take)});return;}
      setRows(response.data||[]);setMeta(response.meta);setLoading(false);
    });
    return()=>{current=false;};
  },[kind,criteria,grid,refresh,retry]);
  useEffect(()=>{exportRequest.current?.abort();setExporting(false);setExportError("");return()=>exportRequest.current?.abort();},[criteria,grid.sortBy,grid.sortDir]);
  async function exportExcel() {
    if(!canExport||exporting||pending)return;
    const controller=new AbortController();exportRequest.current?.abort();exportRequest.current=controller;setExporting(true);setExportError("");
    const params=new URLSearchParams({q:criteria.q,filters:JSON.stringify(apiFilters(kind,criteria)),sortBy:grid.sortBy,sortDir:grid.sortDir,columns:JSON.stringify(visibleColumns.filter(key=>key!=="actions"))});
    try{await downloadApiFile("/api/referentiel/exports/"+(kind==="values"?"valeurs":"categories")+".xlsx?"+params,{signal:controller.signal});}
    catch(failure){if(!controller.signal.aborted)setExportError(failure.message||"L’export a échoué.");}
    finally{if(!controller.signal.aborted)setExporting(false);}
  }
  function saved(_record,info) {setEditor(null);setFeedback(info?.mode==="create"?"Référence créée.":"Référence mise à jour.");onChanged();}
  const columns=useMemo(()=>[
    ...(kind==="values"?[{key:"NomCategorieGenerique",label:"Catégorie",width:190}]:[]),
    {key:definition.name,label:kind==="values"?"Libellé":"Catégorie",width:kind==="values"?240:300,render:row=><span className="erp-product-cell"><span className="erp-product-avatar"><AppIcon name={definition.icon} size={18}/></span><span className="erp-product-identity"><strong>{row[definition.name] || "Sans libellé"}</strong></span></span>},
    ...(kind==="values"?[{key:"AbrGenerique",label:"Abréviation ou code",width:150,render:row=>row.AbrGenerique?<span className="reference-code">{row.AbrGenerique}</span>:"—"}]:[]),
    {key:"ModuleCategorieGenerique",label:"Modules associés",width:190,render:row=>row.ModuleCategorieGenerique?<span className="reference-module"><strong>{row.ModuleCategorieGenerique}</strong>{moduleLabel(row.ModuleCategorieGenerique)!==row.ModuleCategorieGenerique?<small>{moduleLabel(row.ModuleCategorieGenerique)}</small>:null}</span>:"—",renderText:row=>row.ModuleCategorieGenerique||"—"},
    {key:definition.active,label:"État",width:120,render:row=><StateBadge value={row[definition.active]}/>},
    ...(kind==="values"?Object.entries(VISIBILITY).map(([key,label])=>({key,label,width:150,render:row=>row[key]==null?"—":row[key]?"Oui":"Non"})):[]),
    ...(kind==="values"?[{key:"ObsGenerique",label:"Informations complémentaires",width:280},{key:"ID_CategorieGeneriqueFk",label:"Identifiant de catégorie",width:150,align:"right"}]:[]),
    {key:definition.pk,label:"Identifiant",width:120,align:"right"},
    {key:"actions",label:"Actions",width:120,sortable:false,render:row=><div className="erp-row-actions" onClick={event=>event.stopPropagation()}><button type="button" className="erp-row-consult" aria-label={"Consulter "+row[definition.name]} onClick={()=>open(row)}><AppIcon name="eye" size={17}/></button><RowActionsMenu label={row[definition.name] || "Référence"} items={[
      {label:"Consulter",icon:"eye",onSelect:()=>open(row)},
      ...(kind==="categories"?[{label:"Voir les valeurs",icon:"list",onSelect:()=>onBrowseCategory(row.ID_CategorieGenerique)}]:[]),
      {label:"Modifier",icon:"edit",disabled:!canWrite,reason:!canWrite?"Accès en consultation":"",onSelect:()=>open(row,"edit")},
      {label:"Désactiver",icon:"close",disabled:!canWrite||row[definition.active]===false,reason:!canWrite?"Accès en consultation":row[definition.active]===false?"Cette référence est déjà inactive.":"",onSelect:()=>setDeletion(row)},
    ]}/></div>},
  ],[kind,canWrite,onBrowseCategory]);
  const categoryName=id=>categories.find(row=>String(row.ID_CategorieGenerique)===String(id))?.NomCategorieGenerique || "Catégorie sélectionnée";
  const chips=Object.entries(criteria).filter(([,value])=>Boolean(value));
  return <>
    {feedback?<div className="reference-feedback" role="status"><AppIcon name="check-circle"/><span>{feedback}</span><button type="button" aria-label="Fermer le message" onClick={()=>setFeedback("")}><AppIcon name="close"/></button></div>:null}
    <RegisterSurface title={definition.title} subtitle={definition.subtitle} actions={<ActionButton icon="plus" variant="primary" disabled={!canWrite} title={!canWrite?"Accès en consultation":undefined} onClick={()=>open(null,"create")}>{definition.create}</ActionButton>}>
      <div className="reference-register-context"><AppIcon name="globe"/><span>Référentiel commun à toutes les entreprises</span></div>
      <div className="erp-register-table erp-results" data-density={density} aria-busy={loading}>
        {selected.length?<div className="erp-register-selection"><strong>{selected.length} {selected.length>1?"lignes sélectionnées":"ligne sélectionnée"}</strong>{selected.length===1?<><ActionButton icon="eye" onClick={()=>open(selected[0])}>Consulter</ActionButton><ActionButton icon="edit" disabled={!canWrite||loading} onClick={()=>open(selected[0],"edit")}>Modifier</ActionButton></>:null}<ActionButton icon="download" disabled={!canExport||loading} onClick={()=>exportRowsToCsv("Referentiel_selection.csv",columns.filter(column=>column.key!=="actions"&&visibleColumns.includes(column.key)),selected.map(row=>Object.fromEntries(Object.entries(row).map(([key,value])=>[key,typeof value==="string"&&/^[=+\-@\t\r]/.test(value)?"'"+value:value]))))}>CSV · sélection</ActionButton><ActionButton icon="close" className="is-icon" aria-label="Effacer la sélection" onClick={()=>setSelectionReset(value=>value+1)}/></div>:null}
        {error?<div className="reference-error" role="alert"><span>{error}</span><ActionButton icon="refresh" onClick={()=>setRetry(value=>value+1)} disabled={loading}>Réessayer</ActionButton></div>:null}
        <SimpleTable rows={rows} columns={columns} getRowId={row=>row[definition.pk]} enableSelection onSelectionChange={setSelected} selectionResetKey={selectionReset} defaultVisibleColumns={definition.defaults} defaultPinnedColumns={[]} serverMeta={meta} serverState={grid} onServerChange={changeGrid} onRowConsult={row=>open(row)} consultColumns={[definition.name]} loading={loading} emptyMessage={error?"Les données ne sont pas disponibles.":"Aucune référence pour ces critères."} columnsPanelOpen={columnsOpen} columnsAnchorRef={columnsAnchor} onColumnsPanelClose={()=>setColumnsOpen(false)} onVisibleColumnsChange={setVisibleColumns} toolbar={<>
          <DataTableToolbar search={search} setSearch={setSearch} onApply={apply} onReset={reset} pending={pending} take={grid.take} onTake={take=>changeGrid({take,skip:0})} filtersOpen={filtersOpen} filterControlsId={"reference-filters-"+kind} toggleFilters={()=>setFiltersOpen(value=>!value)} activeFilters={activeFilters} density={density} toggleDensity={()=>setDensity(value=>value==="airy"?"compact":"airy")} columnsOpen={columnsOpen} columnsButtonRef={columnsAnchor} toggleColumns={()=>setColumnsOpen(value=>!value)} loading={loading} placeholder={kind==="values"?"Rechercher un libellé, une catégorie ou un code…":"Rechercher une catégorie ou un module…"} exportFile={canExport?exportExcel:undefined} exporting={exporting} exportDisabled={Boolean(error)||!meta?.filteredCount||!visibleColumns.some(key=>key!=="actions")} error={exportError}/>
          {filtersOpen?<form id={"reference-filters-"+kind} className="erp-register-filters" onSubmit={event=>{event.preventDefault();apply();}}><div className="erp-register-filter-grid">
            {kind==="values"?<label><span>Catégorie</span><SearchSelect label="Catégorie" value={draft.category} options={[{value:"",label:"Toutes les catégories"},...categories.map(row=>({value:String(row.ID_CategorieGenerique),label:row.NomCategorieGenerique}))]} onChange={category=>setDraft(current=>({...current,category}))}/></label>:null}
            <label><span>État</span><SearchSelect label="État" value={draft.state} options={[{value:"",label:"Tous les états"},{value:"true",label:"Actif"},{value:"false",label:"Inactif"}]} onChange={state=>setDraft(current=>({...current,state}))}/></label>
            <label><span>Modules associés</span><SearchSelect label="Modules associés" value={draft.module} options={[{value:"",label:"Tous les modules"},...modules.map(value=>({value,label:moduleLabel(value)}))]} onChange={module=>setDraft(current=>({...current,module}))}/></label>
          </div>{categoryError?<p className="erp-table-error" role="alert">{categoryError}</p>:null}<div className="erp-register-filters-footer"><ActionButton type="submit" variant="primary" disabled={loading}>Appliquer les filtres</ActionButton></div></form>:null}
          {activeFilters?<div className="erp-register-chips">{chips.map(([key,value])=><span key={key} className="erp-register-chip">{{q:"Recherche",category:"Catégorie",state:"État",module:"Modules"}[key]} : {key==="category"?categoryName(value):key==="state"?value==="true"?"Actif":"Inactif":key==="module"?moduleLabel(value):value}<button type="button" aria-label={"Retirer le filtre "+({q:"Recherche",category:"Catégorie",state:"État",module:"Modules"}[key])} onClick={()=>removeFilter(key)}><AppIcon name="close" size={13}/></button></span>)}</div>:null}
        </>}/>
      </div>
    </RegisterSurface>
    {editor?<ReferenceEditor kind={kind} recordId={editor.id} mode={editor.mode} initialCategoryId={criteria.category} categories={categories} canWrite={canWrite} onClose={()=>setEditor(null)} onSaved={saved}/>:null}
    {deletion?<ReferenceDeletion kind={kind} row={deletion} canWrite={canWrite} onClose={()=>setDeletion(null)} onDeleted={()=>{setDeletion(null);setFeedback("Référence désactivée.");onChanged();}}/>:null}
  </>;
}

function ReferenceDeletion({kind,row,canWrite,onClose,onDeleted}) {
  const definition=DEFINITIONS[kind], [busy,setBusy]=useState(false),[error,setError]=useState(""),saving=useRef(false);
  async function remove() {
    if(!canWrite||saving.current)return;
    saving.current=true;setBusy(true);setError("");
    const config=REFERENTIEL_ADMIN_SCHEMA.crudConfigs["referentiel."+definition.view];
    const response=await config.deleteRecord(row[definition.pk]);
    saving.current=false;setBusy(false);
    if(response?.success)onDeleted();else setError(response?.message||"La désactivation n’a pas abouti.");
  }
  return <RecordEditorFrame title="Désactiver la référence" subtitle={row[definition.name]} icon="close" defaultWidth={600} onClose={onClose} onSubmit={remove} busy={busy} canSubmit={canWrite} error={error} submitLabel="Désactiver" storageKey="sauverndeko.references.action.width"><section className="record-editor-section"><p className="record-action-copy">Désactiver « {row[definition.name]} » ?</p><p className="record-editor-note">La référence et son historique sont conservés. Vous pourrez la réactiver depuis sa fiche.</p></section></RecordEditorFrame>;
}

export default function Referentiels() {
  const {user}=useAuth(),[params,setParams]=useSearchParams();
  const kind=params.get("onglet")==="categories"?"categories":"values",category=params.get("categorie")||"";
  const [collapsed,setCollapsed]=useState(()=>readPreference("sauverndeko.references.sidebar-collapsed","false")==="true");
  const [categories,setCategories]=useState([]),[categoryError,setCategoryError]=useState(""),[refresh,setRefresh]=useState(0);
  useReferencesRefresh(()=>setRefresh(value=>value+1));
  useEffect(()=>{try{localStorage.setItem("sauverndeko.references.sidebar-collapsed",String(collapsed));}catch{}},[collapsed]);
  useEffect(()=>{let current=true;fetchCompleteReferenceRows("T_CategorieGenerique").then(response=>{if(!current)return;if(response?.success){setCategories(response.data);setCategoryError("");}else setCategoryError("La liste des catégories est indisponible.");});return()=>{current=false;};},[refresh]);
  function navigate(next,id="") {const query=new URLSearchParams();query.set("onglet",next==="categories"?"categories":"valeurs");if(id)query.set("categorie",String(id));setParams(query);}
  const browseCategory=id=>navigate("values",id);
  return <div className={"logistics-modern logistics-app references-app"+(collapsed?" is-menu-collapsed":"")}>
    <aside className={"logistics-sidebar-shell"+(collapsed?" is-collapsed":"")}>
      <div className="logistics-sidebar-top"><Link to="/" className="logistics-brand-lockup" aria-label="SauverNdeko — Applications"><img className="logistics-brand-logo" src="/sauverndeko-logo.jpg" alt="" width="34" height="34"/>{!collapsed?<div className="logistics-brand-copy"><strong>SauverNdeko</strong><span>Référentiels</span></div>:null}</Link><button type="button" className="logistics-sidebar-toggle" onClick={()=>setCollapsed(value=>!value)} aria-label={collapsed?"Afficher le menu Référentiels":"Replier le menu Référentiels"} title={collapsed?"Déplier":"Replier"}><AppIcon name="sidebar"/></button></div>
      <nav className="logistics-sidebar-nav" aria-label="Menu Référentiels"><div className="logistics-nav-group">{!collapsed?<span className="logistics-nav-heading">Nomenclatures</span>:null}{Object.entries(DEFINITIONS).map(([key,definition])=><button key={key} type="button" className={"logistics-sidebar-link"+(kind===key?" is-active":"")} aria-current={kind===key?"page":undefined} aria-label={definition.title} title={definition.title} onClick={()=>navigate(key)}><span className="logistics-sidebar-icon"><AppIcon name={definition.icon} size={18}/></span>{!collapsed?<span className="logistics-sidebar-label">{definition.title}</span>:null}</button>)}</div></nav>
      <div className="logistics-app-switcher">{user?.moduleAccess?.modules?.logistique?.canRead?<Link to="/logistique" aria-label="Logistique" title="Logistique"><span><AppIcon name="box"/></span>{!collapsed?<><span>Logistique</span><AppIcon name="arrow-up-right"/></>:null}</Link>:null}{user?.permissions?.canAccessAdmin?<Link to="/admin" aria-label="Administration" title="Administration"><span><AppIcon name="shield"/></span>{!collapsed?<><span>Administration</span><AppIcon name="arrow-up-right"/></>:null}</Link>:null}<Link to="/" aria-label="Toutes les applications" title="Applications"><span><AppIcon name="apps"/></span>{!collapsed?<><span>Applications</span><AppIcon name="arrow-up-right"/></>:null}</Link></div>
    </aside>
    <ModuleHeader title="Référentiels"/>
    <main className="references-main"><ReferenceRegister key={kind+":"+category} kind={kind} categories={categories} initialCategory={category} onBrowseCategory={browseCategory} refresh={refresh} onChanged={()=>setRefresh(value=>value+1)} categoryError={categoryError}/></main>
  </div>;
}
