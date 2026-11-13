import {categoricalKey} from "../../utils/categoricalValues";
import {useDepotScope} from "../../contexts/DepotScopeContext";
import {fieldCurrencyReferences} from "../../utils/money";
import useTablePreferences from "../../hooks/useTablePreferences";
import {tabRights} from "../../services/moduleAccess";
import lazyView from "../../components/LazyView";
const StockValuation=lazyView(()=>import("../../components/StockValuation"),{label:"Chargement de la valorisation…",compact:true});
import ExpiryPolicyEditor from "./ExpiryPolicyEditor";
import RegisterCategoryFilter from "../../components/RegisterCategoryFilter";
import {useEntityScope} from "../../contexts/EntityScopeContext";
import { currencyOptions } from "../../utils/money";
import CategoricalSelect from "../../components/CategoricalSelect";
import ArticleEditor from "./ArticleEditor";
import LogisticsBatchComposer from "./LogisticsBatchComposer";
import StockReceiptEditor from "./StockReceiptEditor";
import ArticleActionDrawer from "./ArticleActionDrawer";
import ArticlePublicationDrawer from "./ArticlePublicationDrawer";
import EntityProfileEditor from "../../components/EntityProfileEditor";
import { useFollowupFolders } from "../../contexts/FollowupFoldersContext";
import RowActionsMenu from "../../components/RowDocumentActions";
import {recordExcel} from "../../utils/rowDocuments";
import AppIcon from "../../components/AppIcon";
import RegisterSurface from "../../components/RegisterSurface";
import RegisterSettingsButton from "../../components/RegisterSettingsButton";
import DataTableToolbar from "../../components/DataTableToolbar";
import ExportMenu from "../../components/ExportMenu";
import { downloadApiFile } from "../../services/api";
import ActionButton from "../../components/ActionButton";
import { useConsultations } from "../../components/ConsultationProvider";
import { useEffect, useMemo, useRef, useState } from "react";
import { useAuth } from "../../contexts/AuthContext";
import {
  asArrayPayload,
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
const EMPTY_FILTERS = { deviseId:"", categorieId:"", typeId:"", uniteId:"", stockState:"all", peremption:"all", statut:"" };
const DEFAULT_COLUMNS = ["NomArticle","CategorieArticle","TypeArticle","QteArticle","NombreLots","ValideArticle","actions"];

function stockTone(value) {
  const label = categoricalKey(value);
  return label.includes("rupture") ? "danger" : label.includes("faible") ? "warning" : label.includes("disponible") ? "success" : "neutral";
}
function expiryTone(value) {
  const label = categoricalKey(value);
  return /p[ée]rim[ée]/.test(label) ? "danger" : /alerte|proche/.test(label) ? "warning" : label.includes("valide") ? "success" : "neutral";
}
function ArticleStatus({ value, tone }) { return value == null || value === "" ? "—" : <span className={"erp-status is-"+tone}>{value}</span>; }

export default function Articles({ title = "Articles", references:receivedReferences, refreshKey, onDataChanged, onPublicationDefaultChanged, sharedTable, onToggleFkMappings }) {
 const depotScope=useDepotScope();
 const references=fieldCurrencyReferences(receivedReferences,"articleCurrencies");
  const preferences=useTablePreferences("logistique.articles");
  const { user: currentUser } = useAuth();
  const { openProduct, openProductLots, openProductStock, openOrder } = useConsultations();
  const {assign,refresh:refreshFolders}=useFollowupFolders();
  const [gridState, setGridState] = useState({ take: 25, skip: 0, sortBy: "NomArticle", sortDir: "asc" });
  const [serverMeta, setServerMeta] = useState(null);
  const [selectedRows, setSelectedRows] = useState([]);
  const [selectionResetKey, setSelectionResetKey] = useState(0);
  const scope = useEntityScope();
  const writable = scope.canWrite && currentUser?.permissions?.canWriteData === true;
  const canWrite = writable && tabRights(currentUser,"logistique","articles").canManage;
  const canReceive = canWrite && tabRights(currentUser,"logistique","commandes").canManage && tabRights(currentUser,"logistique","details").canManage;
  const canReadStockCard = tabRights(currentUser,"logistique","mouvements").canRead;
  const canClassify = writable && tabRights(currentUser,"logistique","dossiers").canManage;
  const canExport = currentUser?.permissions?.canExportData !== false && tabRights(currentUser,"logistique","articles").canExport === true;
  const [search, setSearch] = useState(sharedTable?.searchValue || "");
  const [criteria, setCriteria] = useState(() => ({ ...EMPTY_FILTERS, q:sharedTable?.searchValue || "" }));
  const [draftFilters, setDraftFilters] = useState(EMPTY_FILTERS);
  const [filtersOpen, setFiltersOpen] = useState(false);
  const [columnsOpen, setColumnsOpen] = useState(false);
  const [expiryPolicyOpen,setExpiryPolicyOpen]=useState(false);
  const [publicationSettingsOpen,setPublicationSettingsOpen]=useState(false);
  const [publication,setPublication]=useState(null);
  const canConfigurePublication = canWrite && currentUser?.canAccessAdmin === true;
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
  async function exportArticles(format="xlsx", selection=null) {
    if(!canExport||!preferences.ready||!preferences.canExport||!preferences.exportKeys.length||loading||pending||exporting||error)return;
    const controller=new AbortController();exportRequest.current?.abort();exportRequest.current=controller;
    setExporting(true);setExportError("");
    const params=new URLSearchParams({depotId:depotScope.depotId,...criteria,sortBy:gridState.sortBy,sortDir:gridState.sortDir,timeZone:"Africa/Kinshasa",columns:JSON.stringify(preferences.exportKeys),...(selection?{selection:JSON.stringify(selection.map(row=>row.ID_Article))}:{})});
    try{await downloadApiFile("/api/logistique/registre/articles/export."+format+"?"+params,{signal:controller.signal});}
    catch(failure){if(!controller.signal.aborted)setExportError(failure.message||"L’export a échoué.");}
    finally{if(exportRequest.current===controller){exportRequest.current=null;setExporting(false);}}
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
  const [readRetry,setReadRetry]=useState(0);
  const [feedback, setFeedback] = useState(null);
  const [editor,setEditor]=useState(null),[batchOpen,setBatchOpen]=useState(false);
  const [receipt,setReceipt]=useState(null),[savedReceipt,setSavedReceipt]=useState(null);
  const [action,setAction]=useState(null);
  const [valuation,setValuation]=useState(null);
  const [savedRecord,setSavedRecord]=useState(null);
  const selectedArticle = sharedTable?.selectedRow || null;
  function handleReceipt(article){if(canReceive&&article.ValideArticle!==false)setReceipt(article.ID_Article);}
  function published(result){
    setPublication(null);
    setSelectedRows([]);
    setSelectionResetKey(key=>key+1);
    sharedTable?.clearSelectedRow?.();
    const count=result.changed;
    const message=count
      ? `${count} article${count===1?"":"s"} ${publication.visible?(count===1?"publié":"publiés"):(count===1?"retiré":"retirés")} ${publication.visible?"dans":"de"} l’annuaire.`
      : "La visibilité des articles sélectionnés est déjà à jour.";
    setFeedback({type:"success",message});
    onDataChanged?.();
  }
  function received(result){setReceipt(null);setSavedRecord(result.article);setSavedReceipt(result.bon);setFeedback({type:"success",message:"Réception enregistrée."});refreshFolders();onDataChanged?.();}
  function savedBatch(result){
    setBatchOpen(false);
    setSavedRecord(null);
    const receipt=result.openingReceipt;
    setSavedReceipt(receipt?{ID_Commande:receipt.id,CodeCmd:receipt.code}:null);
    const message=result.count===1?"1 article créé.":result.count+" articles créés.";
    setFeedback({type:"success",message:receipt?message+" Bon d’entrée "+receipt.code+".":message});
    refreshFolders();
    onDataChanged?.();
  }
  function handleNewArticle(){if(canWrite)setEditor({mode:"create"});}
  function handleEditArticle(article){if(canWrite)setEditor({mode:"edit",id:article.ID_Article});}
  function handleDisableArticle(article){if(canWrite)setAction({id:article.ID_Article,kind:article.ValideArticle===false?"enable":"disable"});}
  function handleDeleteArticle(article){if(canWrite&&currentUser?.Is_Admin&&article.ValideArticle===false)setAction({id:article.ID_Article,kind:"delete"});}
  function saved(record,operation){
    setEditor(null);setAction(null);setSavedReceipt(null);
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
    { key:"NomArticle", label:"Article", width:270, render:row => <span className="erp-product-cell"><span className="erp-product-avatar"><AppIcon name="box" size={19}/></span><span className="erp-product-identity"><strong>{row.NomArticle || "Article sans nom"}</strong><small>{row.CodeArticleInterne ? "Code : "+row.CodeArticleInterne : "Code interne non renseigné"}</small><small>{row.RefArticle ? "Réf. : "+row.RefArticle : "Référence non renseignée"}</small>{row.ValideArticle===false?<small>Inactif</small>:null}</span></span>, renderText:row => row.NomArticle || "—" },
    { key:"CodeArticleInterne", label:"Code interne", width:150 },
    { key:"RefArticle", label:"Référence", width:180 },
    { key:"CategorieArticle", label:"Catégorie", width:160, render:row => row.CategorieArticle || categoryLabelMap.get(String(row.ID_CategorieArticleFk)) || "—" },
    { key:"TypeArticle", label:"Type", width:140, render:row => row.TypeArticle || typeLabelMap.get(String(row.ID_TypeArticleFk)) || "—" },
    { key:"Unite", label:"Unité", width:120, render:row => row.Unite || unitLabelMap.get(String(row.ID_UniteFk)) || "—" },
    { key:"QteArticle", label:depotScope.depotId?"Stock du dépôt":"Stock entreprise", width:130, align:"right", render:row => <span className="erp-stock-quantity">{formatNumber(row.QteArticle)}<small>{row.Unite || unitLabelMap.get(String(row.ID_UniteFk)) || ""}</small>{depotScope.depotId?<small>Entreprise : {formatNumber(row.StockEntreprise)}</small>:null}</span>, renderText:row => formatNumber(row.QteArticle) },
    { key:"QteMinArticle", label:"Seuil minimum", align:"right", render:row => formatNumber(row.QteMinArticle) },
    { key:"QteACommander", label:"À commander", align:"right", render:row => formatNumber(row.QteACommander) },
    { key:"EtatStock", label:"État du stock", width:150, render:row => <ArticleStatus value={row.EtatStock} tone={stockTone(row.EtatStock)}/> },
    { key:"DeviseCode",label:"Devise",width:115,render:row=>row.DeviseCode || "Non renseignée" },
    { key:"PUArticle", label:"Prix d’achat", width:130, align:"right", render:row => formatCurrency(row.PUArticle,row.DeviseCode) },
    { key:"PoidsUnitaire",label:"Poids unitaire",width:145,align:"right",render:row=>row.PoidsUnitaire==null?"—":formatNumber(row.PoidsUnitaire)+(row.UnitePoids?" "+row.UnitePoids:"") },
    { key:"NombreLots",label:"Lots",width:110,align:"right",render:row=><button type="button" className="erp-object-link" onClick={event=>{event.stopPropagation();openProductLots(row);}}>{formatNumber(row.NombreLots)}</button> },
    { key:"InformationArticle",label:"Informations",width:240 },
    { key:"PVArticle", label:"Prix de vente", width:130, align:"right", render:row => formatCurrency(row.PVArticle,row.DeviseCode) },
    { key:"ValeurStockAchat", label:"Valeur catalogue (achat)", width:150, align:"right", render:row => formatCurrency(row.ValeurStockAchat,row.DeviseCode) },
    { key:"MargeUnitaire", label:"Marge unitaire", align:"right", render:row => formatCurrency(row.MargeUnitaire,row.DeviseCode) },
    { key:"DatePeremptionArticle", label:"Péremption", width:140, render:row => row.DatePeremptionArticle ? formatDate(row.DatePeremptionArticle) : "—" },
    { key:"EtatPeremption", label:"État de péremption", width:170, render:row => <ArticleStatus value={row.EtatPeremption} tone={expiryTone(row.EtatPeremption)}/> },
    { key:"ValideArticle", label:"État de l’article", width:145, render:row => <ArticleStatus value={row.ValideArticle == null ? null : row.ValideArticle ? "Actif" : "Inactif"} tone={row.ValideArticle ? "success" : "neutral"}/> },
    { key:"actions", label:"Actions", width:120, sortable:false, render:row => <div className="erp-row-actions" onClick={event=>event.stopPropagation()}><button type="button" className="erp-row-consult" aria-label={"Consulter "+(row.NomArticle || "l’article")} title="Produit 360" onClick={()=>openProduct(row)}><AppIcon name="eye" size={18}/></button><RowActionsMenu documents={[recordExcel('articles',{ID_Article:row.ID_Article},'Fiche article')]} label={row.NomArticle || "Article"} items={[
      {label:"Consulter",icon:"eye",onSelect:()=>openProduct(row)},
      ...(canReadStockCard?[{label:"Fiche de stock",icon:"movements",onSelect:()=>openProductStock(row,depotScope.depotId)}]:[]),
      {label:"Valorisation CUMP",icon:"cash",onSelect:()=>setValuation({id:row.ID_Article,currency:row.ID_DeviseFk})},
      {label:"Réceptionner du stock",icon:"stock-in",disabled:!canReceive||row.ValideArticle===false,reason:!canReceive?"Accès en consultation":row.ValideArticle===false?"Réactivez l’article pour réceptionner du stock.":"",onSelect:()=>handleReceipt(row)},
      {label:"Modifier",icon:"edit",disabled:!canWrite,reason:!canWrite?"Accès en consultation":"",onSelect:()=>handleEditArticle(row)},
      {label:row.ValideArticle===false?"Réactiver":"Désactiver",icon:row.ValideArticle===false?"check-circle":"close",disabled:!canWrite,reason:!canWrite?"Accès en consultation":"",onSelect:()=>handleDisableArticle(row)},
      {label:"Supprimer",icon:"trash",danger:true,disabled:!canWrite || !currentUser?.Is_Admin || row.ValideArticle !== false,reason:!canWrite?"Accès en consultation":!currentUser?.Is_Admin?"Réservé à l’administration de la plateforme":row.ValideArticle !== false?"Désactivez d’abord l’article.":"",onSelect:()=>handleDeleteArticle(row)},
    ]}/></div> },
  ],[categoryLabelMap,typeLabelMap,unitLabelMap,openProduct,openProductLots,openProductStock,canReadStockCard,depotScope.depotId,canWrite,canReceive,currentUser?.Is_Admin,openOrder]);

  useEffect(() => {
    let isMounted = true;

    async function loadArticles() {
      setLoading(true);
      setError("");

      const response = await ARTICLES_VIEW_CONFIG.fetchRows({ ...criteria, ...gridState, depotId:depotScope.depotId });

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
  }, [criteria, refreshKey, gridState, readRetry]);

  return (
    <div className="logistics-screen">
      <div aria-live="polite"><StatusBanner feedback={feedback} />{savedRecord?<button type="button" className="application-back" onClick={()=>openProduct(savedRecord)}>Consulter l’article<AppIcon name="arrow-up-right"/></button>:null}{savedReceipt?<button type="button" className="application-back" onClick={()=>openOrder(savedReceipt)}>Consulter le bon d’entrée<AppIcon name="arrow-up-right"/></button>:null}</div>
      <RegisterSurface title={title} subtitle="Catalogue et suivi du stock" actions={<>
        <>{currentUser?.Is_Admin===true?<ActionButton icon="calendar" onClick={()=>setExpiryPolicyOpen(true)} disabled={!canWrite}>Conservation</ActionButton>:null}</><RegisterSettingsButton buttonRef={columnsAnchorRef} expanded={columnsOpen} onTableSettings={()=>setColumnsOpen(true)} onReferences={onToggleFkMappings} extraItems={canConfigurePublication?[{icon:"globe",label:"Publication dans l’annuaire",onSelect:()=>setPublicationSettingsOpen(true)}]:[]}/>
        <ActionButton icon="plus" variant="primary" onClick={handleNewArticle} disabled={!canWrite} title={!canWrite ? "Accès en consultation" : "Créer un article"}>Nouvel article</ActionButton>
        <ActionButton icon="list" onClick={()=>setBatchOpen(true)} disabled={!canWrite}>Ajouter plusieurs articles</ActionButton>
      </>} tabs={<RegisterCategoryFilter label="État du stock" value={criteria.stockState} options={[{value:"all",label:"Tous les articles"},{value:"disponible",label:"Disponibles"},{value:"faible",label:"Stock faible"},{value:"rupture",label:"Ruptures"}]} onChange={chooseStock}/>}>
        <div className="erp-register-table erp-results" data-density={density} aria-busy={loading}>
          {selectedRows.length ? <div className="erp-register-selection"><strong>{selectedRows.length === 1 ? selectedRows[0].NomArticle || "Article sélectionné" : selectedRows.length+" articles sélectionnés"}</strong>
            {selectedRows.length === 1 ? <ActionButton icon="eye" onClick={() => openProduct(selectedRows[0])}>Consulter</ActionButton> : null}
            {canClassify ? <ActionButton icon="folder" onClick={()=>assign(selectedRows.map(row=>row.ID_Article))} disabled={loading}>Classer</ActionButton> : null}
            {canWrite?<><ActionButton icon="globe" disabled={loading||pending} onClick={()=>setPublication({ids:selectedRows.map(row=>Number(row.ID_Article)),visible:true})}>Publier dans l’annuaire</ActionButton><ActionButton icon="close" disabled={loading||pending} onClick={()=>setPublication({ids:selectedRows.map(row=>Number(row.ID_Article)),visible:false})}>Retirer de l’annuaire</ActionButton></>:null}
            {canExport?<ExportMenu selection exportFile={()=>exportArticles("xlsx",selectedRows)} exportCsv={()=>exportArticles("csv",selectedRows)} disabled={loading||pending||exporting||!preferences.ready||!preferences.canExport||!preferences.exportKeys.length||Boolean(error)} exporting={exporting}/>:null}
            {canWrite && selectedRows.length===1 && selectedArticle ? <><ActionButton icon="edit" onClick={() => handleEditArticle(selectedArticle)}>Modifier</ActionButton><ActionButton onClick={() => handleDisableArticle(selectedArticle)} >{selectedArticle.ValideArticle===false?"Réactiver":"Désactiver"}</ActionButton><ActionButton icon="trash" onClick={() => handleDeleteArticle(selectedArticle)} disabled={!currentUser?.Is_Admin || selectedArticle.ValideArticle !== false} title={selectedArticle.ValideArticle !== false ? "Désactivez d’abord l’article." : "Supprimer définitivement"}>Supprimer</ActionButton></> : null}
            <ActionButton icon="close" className="is-icon" aria-label="Effacer la sélection" onClick={() => { setSelectionResetKey(key => key+1); sharedTable?.clearSelectedRow?.(); }}/>
          </div> : null}
          {error ? <div className="erp-table-error" role="alert"><span>{error}</span><ActionButton icon="refresh" disabled={loading} onClick={()=>setReadRetry(value=>value+1)}>Réessayer</ActionButton></div> : null}
          <SimpleTable tablePreferences={preferences} rows={visibleRows} columns={tableColumns} selectedRowId={selectedArticle?.ID_Article ?? null} enableSelection onSelectionChange={selected => { setSelectedRows(selected); sharedTable?.setSelectedRow?.(selected.length === 1 ? selected[0] : null); }} selectionResetKey={selectionResetKey} defaultVisibleColumns={DEFAULT_COLUMNS} defaultPinnedColumns={[]} serverMeta={serverMeta} serverState={gridState} onServerChange={changeGrid} onRowConsult={openProduct} consultColumns={["NomArticle","CodeArticleInterne"]} isCellConsultable={(row,key) => row[key] != null && row[key] !== ""} loading={loading} emptyMessage={error ? "Les articles ne sont pas disponibles." : "Aucun article pour ces critères."} columnsPanelOpen={columnsOpen} columnsAnchorRef={columnsAnchorRef} onColumnsPanelClose={() => setColumnsOpen(false)} onVisibleColumnsChange={setVisibleColumns}
            toolbar={<>
              <DataTableToolbar showSettings={false} settingsLabel="Réglages" search={search} setSearch={setSearch} onApply={applyFilters} onReset={resetFilters} pending={pending} take={gridState.take} onTake={take => changeGrid({take,skip:0})} filtersOpen={filtersOpen} filterControlsId="article-filters" toggleFilters={() => setFiltersOpen(value => !value)} activeFilters={activeFilters} density={density} toggleDensity={() => setDensity(value => value === "airy" ? "compact" : "airy")} columnsOpen={columnsOpen} columnsButtonRef={columnsAnchorRef} toggleColumns={() => setColumnsOpen(value => !value)} loading={loading} placeholder="Rechercher un article, un code ou une référence…" exportFile={canExport?()=>exportArticles():undefined} exportCsv={canExport?()=>exportArticles("csv"):undefined} exporting={exporting} exportDisabled={Boolean(error) || !serverMeta?.filteredCount || !preferences.ready || !preferences.canExport || !preferences.exportKeys.length} error={exportError||preferences.error}/>
              {filtersOpen ? <form id="article-filters" className="erp-register-filters" onSubmit={event => {event.preventDefault();applyFilters();}}><div className="erp-register-filter-grid">
                {[{key:"deviseId",label:"Devise",options:currencyOptions(references,true)},{key:"categorieId",label:"Catégorie",options:articleCategoryOptions},{key:"typeId",label:"Type",options:articleTypeOptions},{key:"uniteId",label:"Unité",options:articleUnitOptions},{key:"stockState",label:"État du stock",options:[{value:"disponible",label:"Disponible"},{value:"faible",label:"Stock faible"},{value:"rupture",label:"Rupture"}]},{key:"peremption",label:"Péremption",options:[{value:"valide",label:"Valide"},{value:"alerte",label:"Alerte de péremption"},{value:"perime",label:"Périmé"},{value:"non-renseignee",label:"Non renseignée"}]},{key:"statut",label:"État de l’article",options:[{value:"true",label:"Actif"},{value:"false",label:"Inactif"}]}].map(({key,label,options}) => <label key={key}><span>{label}</span><CategoricalSelect aria-label={label} value={draftFilters[key]} onChange={event => setDraftFilters(current => ({...current,[key]:event.target.value}))}><option value={EMPTY_FILTERS[key]}>Tous</option>{options.map(option => <option key={option.value} value={option.value}>{option.label}</option>)}</CategoricalSelect></label>)}
              </div><div className="erp-register-filters-footer"><ActionButton type="submit" variant="primary" disabled={loading}>Appliquer les filtres</ActionButton></div></form> : null}
              {activeFilters ? <div className="erp-register-chips">{Object.entries(criteria).filter(([key,value]) => key === "q" ? Boolean(value) : value !== EMPTY_FILTERS[key]).map(([key,value]) => {
                const labels = {deviseId:"Devise",q:"Recherche",categorieId:"Catégorie",typeId:"Type",uniteId:"Unité",stockState:"Stock",peremption:"Péremption",statut:"Article"};
                const values = {deviseId:currencyOptions(references,true).find(option=>option.value===String(value))?.label,categorieId:categoryLabelMap.get(String(value)),typeId:typeLabelMap.get(String(value)),uniteId:unitLabelMap.get(String(value)),stockState:{disponible:"Disponible",faible:"Stock faible",rupture:"Rupture"}[value],peremption:{valide:"Valide",alerte:"Alerte",perime:"Périmé","non-renseignee":"Non renseignée"}[value],statut:value === "true" ? "Actif" : "Inactif"};
                return <span key={key} className="erp-register-chip">{labels[key]} : {values[key] || value}<button type="button" aria-label={"Retirer le filtre "+labels[key]} onClick={() => removeFilter(key)}><AppIcon name="close" size={13}/></button></span>;
              })}</div> : null}
            </>}/>
        </div>
      </RegisterSurface>

      {publicationSettingsOpen&&canConfigurePublication?<EntityProfileEditor mode="edit" initialTab="article-publication" onClose={()=>setPublicationSettingsOpen(false)} onSaved={record=>{setPublicationSettingsOpen(false);onPublicationDefaultChanged?.(record.PartageArticlesPublicParDefaut);setFeedback({type:"success",message:"Préférence de publication enregistrée."});}}/>:null}
      {publication&&canWrite?<ArticlePublicationDrawer selection={publication} onClose={()=>setPublication(null)} onSaved={published}/>:null}
      {expiryPolicyOpen?<ExpiryPolicyEditor onClose={()=>setExpiryPolicyOpen(false)} onSaved={()=>{onDataChanged?.();refreshFolders?.();}}/>:null}
      {valuation?<StockValuation articleId={valuation.id} defaultCurrencyId={valuation.currency} onClose={()=>setValuation(null)} onSaved={()=>onDataChanged?.()}/>:null}
      {editor?<ArticleEditor key={editor.id||"new"} articleId={editor.id} references={references} onClose={()=>setEditor(null)} onSaved={saved}/>:null}
      {batchOpen?<LogisticsBatchComposer kind="articles" references={references} onClose={()=>setBatchOpen(false)} onSaved={savedBatch}/>:null}
      {receipt?<StockReceiptEditor key={receipt} articleId={receipt} references={references} onClose={()=>setReceipt(null)} onSaved={received}/>:null}
      {action?<ArticleActionDrawer key={action.id+action.kind} articleId={action.id} action={action.kind} onClose={()=>setAction(null)} onSaved={saved}/>:null}
    </div>
  );
}
