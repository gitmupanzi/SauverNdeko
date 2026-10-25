import ArticleEditor from "./ArticleEditor";
import ArticleActionDrawer from "./ArticleActionDrawer";
import { useFollowupFolders } from "../../contexts/FollowupFoldersContext";
import RowActionsMenu from "../../components/RowActionsMenu";
import AppIcon from "../../components/AppIcon";
import RegisterSurface from "../../components/RegisterSurface";
import DataTableToolbar from "../../components/DataTableToolbar";
import { downloadApiFile } from "../../services/api";
import ActionButton from "../../components/ActionButton";
import { useConsultations } from "../../components/ConsultationProvider";
import { useEffect, useMemo, useRef, useState } from "react";
import { useAuth } from "../../contexts/AuthContext";
import {
  asArrayPayload,
  exportRowsToCsv,
  buildReferenceLabelMap,
  buildReferenceOptions,
  formatCurrency,
  formatDate,
  formatNumber,
  getApiMessage,
  SimpleTable,
  StatusBanner,
} from "./logistiqueShared";
import {
  getLogistiqueViewConfig,
} from "./views";

const ARTICLES_VIEW_CONFIG = getLogistiqueViewConfig("articles");
const EMPTY_FILTERS = { categorieId:"", typeId:"", uniteId:"", stockState:"all", peremption:"all", statut:"" };
const DEFAULT_COLUMNS = ["NomArticle","CategorieArticle","QteArticle","EtatStock","PUArticle","DatePeremptionArticle","actions"];

function stockTone(value) {
  const label = String(value || "").normalize("NFD").replace(/[\u0300-\u036f]/g,"").toLowerCase();
  return label.includes("rupture") ? "danger" : label.includes("faible") ? "warning" : label.includes("disponible") ? "success" : "neutral";
}
function expiryTone(value) {
  const label = String(value || "").normalize("NFD").replace(/[\u0300-\u036f]/g,"").toLowerCase();
  return label.includes("perime") ? "danger" : /alerte|proche/.test(label) ? "warning" : label.includes("valide") ? "success" : "neutral";
}
function ArticleStatus({ value, tone }) { return value == null || value === "" ? "—" : <span className={"erp-status is-"+tone}>{value}</span>; }

export default function Articles({ references, refreshKey, onDataChanged, sharedTable, onToggleFkMappings }) {
  const { user: currentUser } = useAuth();
  const { openProduct, openProductLots } = useConsultations();
  const {assign,refresh:refreshFolders}=useFollowupFolders();
  const [gridState, setGridState] = useState({ take: 25, skip: 0, sortBy: "NomArticle", sortDir: "asc" });
  const [serverMeta, setServerMeta] = useState(null);
  const [selectedRows, setSelectedRows] = useState([]);
  const [selectionResetKey, setSelectionResetKey] = useState(0);
  const canWrite = currentUser?.permissions?.canWriteData === true;
  const [search, setSearch] = useState(sharedTable?.searchValue || "");
  const [criteria, setCriteria] = useState(() => ({ ...EMPTY_FILTERS, q:sharedTable?.searchValue || "" }));
  const [draftFilters, setDraftFilters] = useState(EMPTY_FILTERS);
  const [filtersOpen, setFiltersOpen] = useState(false);
  const [columnsOpen, setColumnsOpen] = useState(false);
  const columnsAnchorRef = useRef(null);
  const [visibleColumns, setVisibleColumns] = useState(DEFAULT_COLUMNS);
  const [density, setDensity] = useState(() => { try { return localStorage.getItem("sauverndeko.table.density") === "airy" ? "airy" : "compact"; } catch { return "compact"; } });
  const [exporting, setExporting] = useState(false);
  const [exportError, setExportError] = useState("");
  const exportRequest = useRef(null);
  const activeFilters = Object.entries(criteria).filter(([key,value]) => key !== "q" && value !== EMPTY_FILTERS[key]).length + Number(Boolean(criteria.q));
  const pending = search.trim() !== criteria.q || Object.keys(EMPTY_FILTERS).some(key => draftFilters[key] !== criteria[key]);
  function changeGrid(patch) { setGridState(current => ({ ...current, ...patch })); }
  function applyFilters() { const q = search.trim(); setCriteria({ ...draftFilters,q }); sharedTable?.setSearchValue?.(q); changeGrid({skip:0}); }
  function resetFilters() { setSearch(""); setDraftFilters(EMPTY_FILTERS); setCriteria({ ...EMPTY_FILTERS,q:"" }); sharedTable?.setSearchValue?.(""); changeGrid({skip:0}); }
  function removeFilter(key) {
    if(key === "q") { setSearch(""); sharedTable?.setSearchValue?.(""); }
    else setDraftFilters(current => ({...current,[key]:EMPTY_FILTERS[key]}));
    setCriteria(current => ({...current,[key]:key === "q" ? "" : EMPTY_FILTERS[key]})); changeGrid({skip:0});
  }
  function chooseStock(stockState) { setDraftFilters(current => ({...current,stockState})); setCriteria(current => ({...current,stockState})); changeGrid({skip:0}); }
  useEffect(() => { try { localStorage.setItem("sauverndeko.table.density",density); } catch { /* Préférence facultative. */ } },[density]);
  useEffect(() => { setExportError(""); exportRequest.current?.abort(); setExporting(false); return () => exportRequest.current?.abort(); },[criteria,gridState.sortBy,gridState.sortDir]);
  async function exportArticles() {
    const controller = new AbortController(); exportRequest.current?.abort(); exportRequest.current = controller;
    setExporting(true); setExportError("");
    const columns = visibleColumns.filter(key => key !== "actions");
    if(columns.includes("NomArticle") && !columns.includes("CodeArticleInterne")) columns.unshift("CodeArticleInterne");
    if(columns.includes("PoidsUnitaire")&&!columns.includes("UnitePoids"))columns.push("UnitePoids");
    const params = new URLSearchParams({...criteria,sortBy:gridState.sortBy,sortDir:gridState.sortDir,timeZone:Intl.DateTimeFormat().resolvedOptions().timeZone,columns:JSON.stringify(columns)});
    try { await downloadApiFile("/api/logistique/registre/articles/export.xlsx?"+params,{signal:controller.signal}); }
    catch(error) { if(!controller.signal.aborted) setExportError(error.message || "L’export a échoué."); }
    finally { if(!controller.signal.aborted) setExporting(false); }
  }
  useEffect(() => {
    if (sharedTable?.composerMode === "create") {
      if (canWrite) handleNewArticle();
      sharedTable?.setComposerMode?.("view");
    }
  }, [sharedTable?.composerMode, canWrite]);
  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [feedback, setFeedback] = useState(null);
  const [editor,setEditor]=useState(null);
  const [action,setAction]=useState(null);
  const [savedRecord,setSavedRecord]=useState(null);
  const selectedArticle = sharedTable?.selectedRow || null;
  function handleNewArticle(){if(canWrite)setEditor({mode:"create"});}
  function handleEditArticle(article){if(canWrite)setEditor({mode:"edit",id:article.ID_Article});}
  function handleDisableArticle(article){if(canWrite)setAction({id:article.ID_Article,kind:article.ValideArticle===false?"enable":"disable"});}
  function handleDeleteArticle(article){if(canWrite&&currentUser?.Is_Admin&&article.ValideArticle===false)setAction({id:article.ID_Article,kind:"delete"});}
  function saved(record,operation){
    setEditor(null);setAction(null);
    setSavedRecord(operation==="deleted"?null:record);
    setFeedback({type:"success",message:{created:"Article créé.",updated:"Article mis à jour.",disabled:"Article désactivé.",enabled:"Article réactivé.",deleted:"Article supprimé."}[operation]});
    if(operation==="deleted"){sharedTable?.clearSelectedRow?.();setSelectionResetKey(x=>x+1);}
    refreshFolders();
    onDataChanged?.();
  }

  const articleTypeOptions = useMemo(() => buildReferenceOptions(references?.articleTypes, "Type"), [references]);
  const articleCategoryOptions = useMemo(
    () => buildReferenceOptions(references?.articleCategories, "Categorie"),
    [references]
  );
  const articleUnitOptions = useMemo(() => buildReferenceOptions(references?.articleUnits, "Unite"), [references]);
  const typeLabelMap = useMemo(() => buildReferenceLabelMap(articleTypeOptions), [articleTypeOptions]);
  const categoryLabelMap = useMemo(() => buildReferenceLabelMap(articleCategoryOptions), [articleCategoryOptions]);
  const unitLabelMap = useMemo(() => buildReferenceLabelMap(articleUnitOptions), [articleUnitOptions]);
  const visibleRows = rows;

  const tableColumns = useMemo(() => [
    { key:"NomArticle", label:"Article", width:270, render:row => <span className="erp-product-cell"><span className="erp-product-avatar"><AppIcon name="box" size={19}/></span><span className="erp-product-identity"><strong>{row.NomArticle || "Article sans nom"}</strong><small>{row.CodeArticleInterne || row.RefArticle || "Code non renseigné"}</small>{row.ValideArticle===false?<small>Inactif</small>:null}</span></span>, renderText:row => row.NomArticle || "—" },
    { key:"CodeArticleInterne", label:"Code interne", width:150 },
    { key:"CategorieArticle", label:"Catégorie", width:160, render:row => row.CategorieArticle || categoryLabelMap.get(String(row.ID_CategorieArticleFk)) || "—" },
    { key:"TypeArticle", label:"Type", width:140, render:row => row.TypeArticle || typeLabelMap.get(String(row.ID_TypeArticleFk)) || "—" },
    { key:"Unite", label:"Unité", width:120, render:row => row.Unite || unitLabelMap.get(String(row.ID_UniteFk)) || "—" },
    { key:"QteArticle", label:"Stock actuel", width:130, align:"right", render:row => <span className="erp-stock-quantity">{formatNumber(row.QteArticle)}<small>{row.Unite || unitLabelMap.get(String(row.ID_UniteFk)) || ""}</small></span>, renderText:row => formatNumber(row.QteArticle) },
    { key:"QteMinArticle", label:"Seuil minimum", align:"right", render:row => formatNumber(row.QteMinArticle) },
    { key:"QteACommander", label:"À commander", align:"right", render:row => formatNumber(row.QteACommander) },
    { key:"EtatStock", label:"État du stock", width:150, render:row => <ArticleStatus value={row.EtatStock} tone={stockTone(row.EtatStock)}/> },
    { key:"PUArticle", label:"Prix d’achat", width:130, align:"right", render:row => formatCurrency(row.PUArticle) },
    { key:"PoidsUnitaire",label:"Poids unitaire",width:145,align:"right",render:row=>row.PoidsUnitaire==null?"—":formatNumber(row.PoidsUnitaire)+(row.UnitePoids?" "+row.UnitePoids:"") },
    { key:"NombreLots",label:"Lots",width:110,align:"right",render:row=><button type="button" className="erp-object-link" onClick={event=>{event.stopPropagation();openProductLots(row);}}>{formatNumber(row.NombreLots)}</button> },
    { key:"InformationArticle",label:"Informations",width:240 },
    { key:"PVArticle", label:"Prix de vente", width:130, align:"right", render:row => formatCurrency(row.PVArticle) },
    { key:"ValeurStockAchat", label:"Valeur du stock", width:150, align:"right", render:row => formatCurrency(row.ValeurStockAchat) },
    { key:"MargeUnitaire", label:"Marge unitaire", align:"right", render:row => formatCurrency(row.MargeUnitaire) },
    { key:"DatePeremptionArticle", label:"Péremption", width:140, render:row => row.DatePeremptionArticle ? formatDate(row.DatePeremptionArticle) : "—" },
    { key:"EtatPeremption", label:"État de péremption", width:170, render:row => <ArticleStatus value={row.EtatPeremption} tone={expiryTone(row.EtatPeremption)}/> },
    { key:"ValideArticle", label:"État de l’article", width:145, render:row => <ArticleStatus value={row.ValideArticle == null ? null : row.ValideArticle ? "Actif" : "Inactif"} tone={row.ValideArticle ? "success" : "neutral"}/> },
    { key:"actions", label:"Actions", width:120, sortable:false, render:row => <div className="erp-row-actions" onClick={event=>event.stopPropagation()}><button type="button" className="erp-row-consult" aria-label={"Consulter "+(row.NomArticle || "l’article")} title="Produit 360" onClick={()=>openProduct(row)}><AppIcon name="eye" size={18}/></button><RowActionsMenu label={row.NomArticle || "Article"} items={[
      {label:"Consulter",icon:"eye",onSelect:()=>openProduct(row)},
      {label:"Modifier",icon:"edit",disabled:!canWrite,reason:!canWrite?"Accès en consultation":"",onSelect:()=>handleEditArticle(row)},
      {label:row.ValideArticle===false?"Réactiver":"Désactiver",icon:row.ValideArticle===false?"check-circle":"close",disabled:!canWrite,reason:!canWrite?"Accès en consultation":"",onSelect:()=>handleDisableArticle(row)},
      {label:"Supprimer",icon:"trash",danger:true,disabled:!canWrite || !currentUser?.Is_Admin || row.ValideArticle !== false,reason:!canWrite?"Accès en consultation":!currentUser?.Is_Admin?"Réservé à l’administration de la plateforme":row.ValideArticle !== false?"Désactivez d’abord l’article.":"",onSelect:()=>handleDeleteArticle(row)},
    ]}/></div> },
  ],[categoryLabelMap,typeLabelMap,unitLabelMap,openProduct,openProductLots,canWrite,currentUser?.Is_Admin]);

  useEffect(() => {
    let isMounted = true;

    async function loadArticles() {
      setLoading(true);
      setError("");

      const response = await ARTICLES_VIEW_CONFIG.fetchRows({ ...criteria, ...gridState });

      if (!isMounted) {
        return;
      }

      if (!response?.success) {
        setRows([]);
        setServerMeta(null);
        setError(response?.message || "Impossible de charger les articles.");
        setLoading(false);
        return;
      }

      const nextRows = asArrayPayload(response);
      setServerMeta(response.meta || null);
      setRows(nextRows);
      if (selectedArticle?.ID_Article != null) {
        const matchedArticle = nextRows.find((row) => row.ID_Article === selectedArticle.ID_Article);
        if (matchedArticle) {
          sharedTable?.setSelectedRow?.(matchedArticle);
        } else {
          sharedTable?.clearSelectedRow?.();
        }
      }
      setLoading(false);
    }

    loadArticles();

    return () => {
      isMounted = false;
    };
  }, [criteria, refreshKey, gridState]);

  return (
    <div className="logistics-screen">
      <div aria-live="polite"><StatusBanner feedback={feedback} />{savedRecord?<button type="button" className="application-back" onClick={()=>openProduct(savedRecord)}>Consulter l’article<AppIcon name="arrow-up-right"/></button>:null}</div>
      <RegisterSurface title="Articles" subtitle="Catalogue et suivi du stock" actions={<>
        <ActionButton icon="settings" onClick={onToggleFkMappings} title="Réglages des références">Réglages</ActionButton>
        <ActionButton icon="plus" variant="primary" onClick={handleNewArticle} disabled={!canWrite} title={!canWrite ? "Accès en consultation" : "Créer un article"}>Nouvel article</ActionButton>
      </>} tabs={<nav className="erp-register-tabs" aria-label="État du stock">
        {[["all","Tous les articles","box"],["disponible","Disponibles","check-circle"],["faible","Stock faible","alert"],["rupture","Ruptures","box"]].map(([key,label,icon]) => <button key={key} type="button" aria-pressed={criteria.stockState === key} onClick={() => chooseStock(key)}><AppIcon name={icon}/>{label}</button>)}
      </nav>}>
        <div className="erp-register-table erp-results" data-density={density} aria-busy={loading}>
          {selectedRows.length ? <div className="erp-register-selection"><strong>{selectedRows.length === 1 ? selectedRows[0].NomArticle || "Article sélectionné" : selectedRows.length+" articles sélectionnés"}</strong>
            {selectedRows.length === 1 ? <ActionButton icon="eye" onClick={() => openProduct(selectedRows[0])}>Consulter</ActionButton> : null}
            {canWrite ? <ActionButton icon="folder" onClick={()=>assign(selectedRows.map(row=>row.ID_Article))} disabled={loading}>Classer</ActionButton> : null}
            <ActionButton icon="download" onClick={() => exportRowsToCsv("Articles_selection.csv",tableColumns.filter(column => column.key !== "actions"),selectedRows)}>CSV · sélection</ActionButton>
            {canWrite && selectedRows.length===1 && selectedArticle ? <><ActionButton icon="edit" onClick={() => handleEditArticle(selectedArticle)}>Modifier</ActionButton><ActionButton onClick={() => handleDisableArticle(selectedArticle)} >{selectedArticle.ValideArticle===false?"Réactiver":"Désactiver"}</ActionButton><ActionButton icon="trash" onClick={() => handleDeleteArticle(selectedArticle)} disabled={!currentUser?.Is_Admin || selectedArticle.ValideArticle !== false} title={selectedArticle.ValideArticle !== false ? "Désactivez d’abord l’article." : "Supprimer définitivement"}>Supprimer</ActionButton></> : null}
            <ActionButton icon="close" className="is-icon" aria-label="Effacer la sélection" onClick={() => { setSelectionResetKey(key => key+1); sharedTable?.clearSelectedRow?.(); }}/>
          </div> : null}
          {error ? <div className="erp-table-error" role="alert">{error}</div> : null}
          {loading ? <span className="erp-grid-loading" role="status">Chargement des articles…</span> : null}
          <SimpleTable rows={error ? [] : visibleRows} columns={tableColumns} selectedRowId={selectedArticle?.ID_Article ?? null} enableSelection onSelectionChange={selected => { setSelectedRows(selected); sharedTable?.setSelectedRow?.(selected.length === 1 ? selected[0] : null); }} selectionResetKey={selectionResetKey} defaultVisibleColumns={DEFAULT_COLUMNS} defaultPinnedColumns={[]} serverMeta={serverMeta} serverState={gridState} onServerChange={changeGrid} onRowConsult={openProduct} consultColumns={["NomArticle","CodeArticleInterne"]} isCellConsultable={(row,key) => row[key] != null && row[key] !== ""} loading={loading} emptyMessage={error ? "Les articles ne sont pas disponibles." : "Aucun article pour ces critères."} columnsPanelOpen={columnsOpen} columnsAnchorRef={columnsAnchorRef} onColumnsPanelClose={() => setColumnsOpen(false)} onVisibleColumnsChange={setVisibleColumns}
            toolbar={<>
              <DataTableToolbar search={search} setSearch={setSearch} onApply={applyFilters} onReset={resetFilters} pending={pending} take={gridState.take} onTake={take => changeGrid({take,skip:0})} filtersOpen={filtersOpen} filterControlsId="article-filters" toggleFilters={() => setFiltersOpen(value => !value)} activeFilters={activeFilters} density={density} toggleDensity={() => setDensity(value => value === "airy" ? "compact" : "airy")} columnsOpen={columnsOpen} columnsButtonRef={columnsAnchorRef} toggleColumns={() => setColumnsOpen(value => !value)} loading={loading} placeholder="Rechercher un article, un code ou une référence…" exportFile={exportArticles} exporting={exporting} exportDisabled={Boolean(error) || !serverMeta?.filteredCount || !visibleColumns.some(key => key !== "actions")} error={exportError}/>
              {filtersOpen ? <form id="article-filters" className="erp-register-filters" onSubmit={event => {event.preventDefault();applyFilters();}}><div className="erp-register-filter-grid">
                {[{key:"categorieId",label:"Catégorie",options:articleCategoryOptions},{key:"typeId",label:"Type",options:articleTypeOptions},{key:"uniteId",label:"Unité",options:articleUnitOptions},{key:"stockState",label:"État du stock",options:[{value:"disponible",label:"Disponible"},{value:"faible",label:"Stock faible"},{value:"rupture",label:"Rupture"}]},{key:"peremption",label:"Péremption",options:[{value:"valide",label:"Valide"},{value:"alerte",label:"Alerte de péremption"},{value:"perime",label:"Périmé"},{value:"non-renseignee",label:"Non renseignée"}]},{key:"statut",label:"État de l’article",options:[{value:"true",label:"Actif"},{value:"false",label:"Inactif"}]}].map(({key,label,options}) => <label key={key}><span>{label}</span><select aria-label={label} value={draftFilters[key]} onChange={event => setDraftFilters(current => ({...current,[key]:event.target.value}))}><option value={EMPTY_FILTERS[key]}>Tous</option>{options.map(option => <option key={option.value} value={option.value}>{option.label}</option>)}</select></label>)}
              </div><div className="erp-register-filters-footer"><ActionButton type="submit" variant="primary" disabled={loading}>Appliquer les filtres</ActionButton></div></form> : null}
              {activeFilters ? <div className="erp-register-chips">{Object.entries(criteria).filter(([key,value]) => key === "q" ? Boolean(value) : value !== EMPTY_FILTERS[key]).map(([key,value]) => {
                const labels = {q:"Recherche",categorieId:"Catégorie",typeId:"Type",uniteId:"Unité",stockState:"Stock",peremption:"Péremption",statut:"Article"};
                const values = {categorieId:categoryLabelMap.get(String(value)),typeId:typeLabelMap.get(String(value)),uniteId:unitLabelMap.get(String(value)),stockState:{disponible:"Disponible",faible:"Stock faible",rupture:"Rupture"}[value],peremption:{valide:"Valide",alerte:"Alerte",perime:"Périmé","non-renseignee":"Non renseignée"}[value],statut:value === "true" ? "Actif" : "Inactif"};
                return <span key={key} className="erp-register-chip">{labels[key]} : {values[key] || value}<button type="button" aria-label={"Retirer le filtre "+labels[key]} onClick={() => removeFilter(key)}><AppIcon name="close" size={13}/></button></span>;
              })}</div> : null}
            </>}/>
          <p className="erp-register-hint">Montants sans devise précisée.</p>
        </div>
      </RegisterSurface>

      {editor?<ArticleEditor key={editor.id||"new"} articleId={editor.id} references={references} onClose={()=>setEditor(null)} onSaved={saved}/>:null}
      {action?<ArticleActionDrawer key={action.id+action.kind} articleId={action.id} action={action.kind} onClose={()=>setAction(null)} onSaved={saved}/>:null}
    </div>
  );
}
