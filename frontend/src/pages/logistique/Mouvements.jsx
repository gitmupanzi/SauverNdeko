import RegisterCategoryFilter from "../../components/RegisterCategoryFilter";
import {useEntityScope} from "../../contexts/EntityScopeContext";
import {useEffect,useId,useMemo,useRef,useState} from "react";
import {useAuth} from "../../contexts/AuthContext";
import {useFollowupFolders} from "../../contexts/FollowupFoldersContext";
import {useConsultations} from "../../components/ConsultationProvider";
import RegisterSurface from "../../components/RegisterSurface";
import RegisterSettingsButton from "../../components/RegisterSettingsButton";
import DataTableToolbar from "../../components/DataTableToolbar";
import ExportMenu from "../../components/ExportMenu";
import SearchSelect from "../../components/SearchSelect";
import RowActionsMenu from "../../components/RowDocumentActions";
import {stockDocuments,recordExcel} from "../../utils/rowDocuments";
import ActionButton from "../../components/ActionButton";
import AppIcon from "../../components/AppIcon";
import useReferencesRefresh from "../../hooks/useReferencesRefresh";
import useTablePreferences from "../../hooks/useTablePreferences";
import {requestJson,downloadApiFile} from "../../services/api";
import {accessSignature,moduleRights} from "../../services/moduleAccess";
import {currencyOptions} from "../../utils/money";
import {asArrayPayload,buildReferenceOptions,formatCurrency,formatDate,formatNumber,SimpleTable,StatusBanner} from "./logistiqueShared";
import StockReceiptEditor from "./StockReceiptEditor";
import "./Mouvements.css";

const API="/api/logistique/registre/mouvements";
const EMPTY={articleId:"",commandeId:"",categorieId:"",articleTypeId:"",typeId:"",origine:"all",sens:"all",deviseId:"",dateFrom:"",dateTo:""};
const LABELS={q:"Recherche",articleId:"Article",commandeId:"Bon de stock",categorieId:"Catégorie d’article",articleTypeId:"Type d’article",typeId:"Type de mouvement",origine:"Origine",sens:"Sens",deviseId:"Devise",dateFrom:"Du",dateTo:"Au"};
const DIRECTIONS=[{value:"entree",label:"Entrées"},{value:"sortie",label:"Sorties"},{value:"neutre",label:"Sans variation"}];
export const MOVEMENT_DEFAULT_COLUMNS=["DateMvt","NomArticle","NomTypeMvt","QteMvt","CodeCmd","PUMvt","MontantMvt","actions"];
const movementId=row=>row.ID_Mvt;
const hasValue=(row,key)=>typeof row[key]==="string"&&Boolean(row[key].trim());
const hasProduct=row=>row.ID_ArticleFk!=null;
const hasOrder=row=>row.ID_cmdFk!=null;
const articleLabel=row=>[row.NomArticle||"Article sans libellé",row.CodeArticleInterne||row.RefArticle].filter(Boolean).join(" · ");
const orderLabel=row=>[row.CodeCmd||"Bon sans code",row.DateCmd?formatDate(row.DateCmd):"",row.TypeCmd||row.AbrTypeCmd].filter(Boolean).join(" · ");
const activeEntries=criteria=>Object.entries(criteria).filter(([key,value])=>key!=="columnFilters"&&(key==="q"?Boolean(value):value!==EMPTY[key]));
const cleanColumns=values=>Object.fromEntries(Object.entries(values).map(([key,value])=>[key,String(value).trim()]).filter(([,value])=>value!==""));
const initialCriteria=q=>({...EMPTY,q:q||"",columnFilters:{}});

export function movementExportColumns(keys){
 return [...new Set(keys.filter(key=>key!=="actions"))];
}
export function buildMovementQuery(criteria,grid={},columns){
 const params=new URLSearchParams();
 for(const key of ["q",...Object.keys(EMPTY)])if(criteria[key]!==undefined)params.set(key,String(criteria[key]));
 for(const key of ["take","skip","sortBy","sortDir"])if(grid[key]!==undefined)params.set(key,String(grid[key]));
 const columnFilters=cleanColumns(criteria.columnFilters||{});
 if(Object.keys(columnFilters).length)params.set("columnFilters",JSON.stringify(columnFilters));
 if(columns)params.set("columns",JSON.stringify(movementExportColumns(columns)));
 params.set("timeZone","Africa/Kinshasa");
 return params;
}

// Les choix volumineux sont recherchés et paginés ; aucun catalogue tronqué en mémoire.
function MovementRecordFilter({id,label,kind,value,selectedLabel,onChange,scopeKey}){
 const product=kind==="article",idKey=product?"ID_Article":"ID_Commande",path=product?"articles":"commandes",labelFor=product?articleLabel:orderLabel;
 const [search,setSearch]=useState(""),[query,setQuery]=useState(""),[skip,setSkip]=useState(0),[rows,setRows]=useState([]),[meta,setMeta]=useState(null),[loading,setLoading]=useState(true),[error,setError]=useState(""),[revision,setRevision]=useState(0);
 useReferencesRefresh(()=>setRevision(current=>current+1));
 useEffect(()=>{
  let active=true;setLoading(true);setError("");
  const params=new URLSearchParams({q:query,take:"25",skip:String(skip),sortBy:product?"NomArticle":"DateCmd",sortDir:product?"asc":"desc"});
  requestJson("/api/logistique/registre/"+path+"?"+params,{requiresAuth:true}).then(response=>{
   if(!active)return;
   if(!response?.success){if(response?.status===401||response?.status===403){setRows([]);setMeta(null);}setError(response?.message||"Les choix n’ont pas pu être chargés.");setLoading(false);return;}
   setRows(asArrayPayload(response));setMeta(response.meta||null);setLoading(false);
  }).catch(()=>{if(active){setError("Les choix n’ont pas pu être chargés.");setLoading(false);}});
  return()=>{active=false;};
 },[path,product,query,skip,revision,scopeKey]);
 const options=[{value:"",label:product?"Tous les articles":"Tous les bons"},...rows.map(row=>({value:String(row[idKey]),label:labelFor(row)}))];
 if(value&&!options.some(option=>option.value===String(value)))options.splice(1,0,{value:String(value),label:selectedLabel||"Sélection conservée"});
 const total=Number(meta?.filteredCount??0),next=skip+rows.length<total;
 function applySearch(){setQuery(search.trim());setSkip(0);setRevision(current=>current+1);}
 return <div className="mouvements-record-filter">
  <label htmlFor={id}>{label}</label>
  <div className="mouvements-choice-search"><input type="search" aria-label={"Rechercher · "+label} value={search} onChange={event=>setSearch(event.target.value)} onKeyDown={event=>{if(event.key==="Enter"){event.preventDefault();event.stopPropagation();applySearch();}}} placeholder={product?"Nom ou code article…":"Code du bon…"}/><ActionButton icon="search" className="is-icon" aria-label={"Rechercher les choix · "+label} onClick={applySearch} disabled={loading}/></div>
  <SearchSelect id={id} label={label} value={value} options={options} onChange={nextValue=>onChange(nextValue,options.find(option=>option.value===nextValue)?.label||"")} loading={loading} disabled={Boolean(error)} describedBy={id+"-state"}/>
  <div className="mouvements-choice-page"><small id={id+"-state"} role="status">{loading?"Chargement…":total?`${skip+1}–${skip+rows.length} sur ${formatNumber(total)}`:"Aucun choix disponible."}</small><ActionButton icon="chevron-left" className="is-icon" aria-label={"Choix précédents · "+label} onClick={()=>setSkip(current=>Math.max(0,current-25))} disabled={loading||Boolean(error)||skip===0}/><ActionButton icon="chevron-right" className="is-icon" aria-label={"Choix suivants · "+label} onClick={()=>setSkip(current=>current+25)} disabled={loading||Boolean(error)||!next}/></div>
  {error?<p className="mouvements-choice-error" role="alert">{error}<button type="button" className="erp-object-link" onClick={()=>setRevision(current=>current+1)}>Réessayer</button></p>:null}
 </div>;
}

export default function Mouvements({title = "Mouvements de stock", references,refreshKey,sharedTable,onToggleFkMappings,onDataChanged}){
 const preferences=useTablePreferences("logistique.mouvements");
 const {user}=useAuth(),{openProduct,openOrder}=useConsultations(),{refresh:refreshFolders}=useFollowupFolders(),filterId=useId();
 const rights=moduleRights(user,"logistique"),canRead=Boolean(user?.permissions?.canAccessAdmin&&rights.canRead);
 const scopeKey=JSON.stringify([user?.IdUser,user?.IdEntiteFk,user?.permissions?.canAccessAdmin,user?.permissions?.canWriteData,user?.permissions?.canExportData,accessSignature(user)]);
 const canExport=canRead&&Boolean(user?.permissions)&&user.permissions.canExportData!==false&&rights.canExport===true;
 const canManage=useEntityScope().canWrite&&canRead&&user?.permissions?.canWriteData===true&&rights.canManage===true;
 const managePermission=useRef(canManage);managePermission.current=canManage;
 const shared=useRef(sharedTable);shared.current=sharedTable;
 const previousScope=useRef(scopeKey),columnsAnchorRef=useRef(null),exportRequest=useRef(null);
 const [search,setSearch]=useState(sharedTable?.searchValue||""),[draft,setDraft]=useState(EMPTY),[criteria,setCriteria]=useState(()=>initialCriteria(sharedTable?.searchValue));
 const [columnDraft,setColumnDraft]=useState({}),[recordLabels,setRecordLabels]=useState({}),[appliedLabels,setAppliedLabels]=useState({});
 const [grid,setGrid]=useState({take:25,skip:0,sortBy:"DateMvt",sortDir:"desc"}),[rows,setRows]=useState([]),[meta,setMeta]=useState(null),[loading,setLoading]=useState(true),[error,setError]=useState(""),[revision,setRevision]=useState(0),[denied,setDenied]=useState(false);
 const [filtersOpen,setFiltersOpen]=useState(false),[criteriaError,setCriteriaError]=useState(""),[columnsOpen,setColumnsOpen]=useState(false),[visibleColumns,setVisibleColumns]=useState(MOVEMENT_DEFAULT_COLUMNS);
 const [density,setDensity]=useState(()=>{try{return localStorage.getItem("sauverndeko.table.density")==="airy"?"airy":"compact";}catch{return "compact";}});
 const [selected,setSelected]=useState([]),[selectionReset,setSelectionReset]=useState(0),[exporting,setExporting]=useState(false),[exportError,setExportError]=useState("");
 const [receipt,setReceipt]=useState(null),[savedReceipt,setSavedReceipt]=useState(null),[feedback,setFeedback]=useState(null);
 const appliedColumnFilters=criteria.columnFilters||{},activeFilters=activeEntries(criteria).length+Object.keys(appliedColumnFilters).length;
 const pending=search.trim()!==criteria.q||Object.keys(EMPTY).some(key=>draft[key]!==criteria[key])||JSON.stringify(cleanColumns(columnDraft))!==JSON.stringify(appliedColumnFilters);
 const options=useMemo(()=>({categorieId:buildReferenceOptions(references?.articleCategories,"Catégorie"),articleTypeId:buildReferenceOptions(references?.articleTypes,"Type"),typeId:buildReferenceOptions(references?.movementTypes,"Type"),deviseId:currencyOptions(references,true),sens:DIRECTIONS,
  origine:(meta?.options?.origines||[]).map(option=>({value:String(option.value),label:String(option.label)}))}),[references,meta?.options?.origines]);
 const contextChanged=previousScope.current!==scopeKey,blocked=loading||Boolean(error)||!canRead||contextChanged||denied;
 function changeGrid(patch){setLoading(true);setGrid(current=>({...current,...patch}));}
 function apply(){
  if(draft.dateFrom&&draft.dateTo&&draft.dateFrom>draft.dateTo){setCriteriaError("La date de fin doit suivre la date de début.");return;}
  const q=search.trim();setCriteriaError("");setLoading(true);setCriteria({...draft,q,columnFilters:cleanColumns(columnDraft)});setAppliedLabels(recordLabels);shared.current?.setSearchValue?.(q);setGrid(current=>({...current,skip:0}));
 }
 function reset(){setLoading(true);setSearch("");setDraft(EMPTY);setCriteria(initialCriteria());setColumnDraft({});setRecordLabels({});setAppliedLabels({});setCriteriaError("");setGrid(current=>({...current,skip:0}));shared.current?.setSearchValue?.("");}
 function removeFilter(key){setLoading(true);setCriteriaError("");if(key==="q"){setSearch("");shared.current?.setSearchValue?.("");}else setDraft(current=>({...current,[key]:EMPTY[key]}));setCriteria(current=>({...current,[key]:key==="q"?"":EMPTY[key]}));setGrid(current=>({...current,skip:0}));}
 function removeColumnFilter(key){setLoading(true);setColumnDraft(current=>Object.fromEntries(Object.entries(current).filter(([name])=>name!==key)));setCriteria(current=>({...current,columnFilters:Object.fromEntries(Object.entries(current.columnFilters).filter(([name])=>name!==key))}));setGrid(current=>({...current,skip:0}));}
 function chooseDirection(sens){setLoading(true);setDraft(current=>({...current,sens}));setCriteria(current=>({...current,sens}));setGrid(current=>({...current,skip:0}));}
 function product(row){if(!blocked&&hasProduct(row))openProduct({...row,ID_Article:row.ID_ArticleFk});}
 function order(row){if(!blocked&&hasOrder(row))openOrder({...row,ID_Commande:row.ID_cmdFk});}
 function consult(row,key){if(key==="CodeCmd")order(row);else product(row);}
 function selectionChanged(next){setSelected(next);shared.current?.setSelectedRow?.(next.length===1?next[0]:null);}
 function receive(row){if(managePermission.current&&!blocked&&hasProduct(row)&&row.ValideArticle!==false)setReceipt(row.ID_ArticleFk);}
 function received(result){setReceipt(null);setSavedReceipt(result.bon);setFeedback({type:"success",message:"Réception enregistrée."});setRevision(value=>value+1);refreshFolders();onDataChanged?.();}
 useEffect(()=>{try{localStorage.setItem("sauverndeko.table.density",density);}catch{/* Préférence locale facultative. */}},[density]);
 useEffect(()=>{
  if(previousScope.current===scopeKey)return;
  previousScope.current=scopeKey;setRows([]);setMeta(null);setSelected([]);setReceipt(null);setSavedReceipt(null);setFeedback(null);setSelectionReset(value=>value+1);setRecordLabels({});setAppliedLabels({});shared.current?.clearSelectedRow?.();reset();
 },[scopeKey]);
 useEffect(()=>{
  let active=true;setLoading(true);setError("");setDenied(false);
  if(!canRead){setRows([]);setMeta(null);setError("Vous n’avez pas accès aux mouvements de stock.");setLoading(false);return()=>{active=false;};}
  requestJson(API+"?"+buildMovementQuery(criteria,grid),{requiresAuth:true}).then(response=>{
   if(!active)return;
   if(!response?.success){setRows([]);setMeta(null);if(response?.status===401||response?.status===403){setDenied(true);setSelected([]);setReceipt(null);setSavedReceipt(null);setFeedback(null);setSelectionReset(value=>value+1);setRecordLabels({});setAppliedLabels({});shared.current?.clearSelectedRow?.();}setError(response?.message||"Les mouvements n’ont pas pu être chargés.");setLoading(false);return;}
   setRows(asArrayPayload(response));setMeta(response.meta||null);setLoading(false);
  }).catch(()=>{if(active){setRows([]);setMeta(null);setError("Les mouvements n’ont pas pu être chargés.");setLoading(false);}});
  return()=>{active=false;};
 },[criteria,grid,refreshKey,revision,scopeKey]);
 useEffect(()=>{setExportError("");exportRequest.current?.abort();exportRequest.current=null;setExporting(false);return()=>{exportRequest.current?.abort();};},[criteria,grid.sortBy,grid.sortDir,scopeKey,denied]);
 async function exportData(format="xlsx",selection=null){
  if(!canExport||!preferences.ready||!preferences.canExport||!preferences.exportKeys.length||blocked||pending||exporting||!meta?.filteredCount||selection&&!selection.length)return;
  const controller=new AbortController();exportRequest.current?.abort();exportRequest.current=controller;setExporting(true);setExportError("");
  const params=buildMovementQuery(criteria,{sortBy:grid.sortBy,sortDir:grid.sortDir},preferences.exportKeys);
  if(selection)params.set("selection",JSON.stringify(selection.map(row=>row.ID_Mvt)));
  try{await downloadApiFile(API+"/export."+format+"?"+params,{signal:controller.signal});}catch(failure){if(!controller.signal.aborted)setExportError(failure.message||"L’export n’a pas pu être préparé.");}finally{if(exportRequest.current===controller){exportRequest.current=null;setExporting(false);}}
 }
 const columns=useMemo(()=>[
  {key:"ID_Mvt",label:"N° de mouvement",width:155,align:"right",filterType:"number",render:row=>formatNumber(row.ID_Mvt)},
  {key:"DateMvt",label:"Date et heure",width:180,filterType:"date",render:row=>formatDate(row.DateMvt)},
  {key:"NomArticle",label:"Article",width:260,filterType:"text",render:row=><span className="erp-product-cell"><span className="erp-product-avatar"><AppIcon name="box" size={19}/></span><span className="erp-product-identity"><strong>{row.NomArticle||"Article sans libellé"}</strong><small>{row.CodeArticleInterne?"Code : "+row.CodeArticleInterne:"Code interne non renseigné"}</small><small>{row.RefArticle?"Réf. : "+row.RefArticle:"Référence non renseignée"}</small></span></span>,renderText:row=>row.NomArticle||""},
  {key:"CodeArticleInterne",label:"Code article",width:155,filterType:"text"},
  {key:"RefArticle",label:"Référence article",width:170,filterType:"text"},
  {key:"CategorieArticle",label:"Catégorie d’article",width:190},
  {key:"TypeArticle",label:"Type d’article",width:180},
  {key:"NomTypeMvt",label:"Mouvement",width:155,render:row=><span className={"erp-status is-"+(Number(row.SigneStock)>0?"success":Number(row.SigneStock)<0?"warning":"neutral")}><AppIcon name={Number(row.SigneStock)>0?"stock-in":Number(row.SigneStock)<0?"stock-out":"movements"} size={13}/>{row.NomTypeMvt||row.TypeMvt||"Non renseigné"}</span>,renderText:row=>row.NomTypeMvt||row.TypeMvt||""},
  {key:"QteMvt",label:"Quantité",width:140,align:"right",filterType:"number",render:row=><span className="erp-stock-quantity">{formatNumber(row.QteMvt)}<small>{row.AbrUnite||""}</small></span>},
  {key:"AbrUnite",label:"Unité",width:100},
  {key:"QteMvtSigned",label:"Variation du stock",width:155,align:"right",filterType:"number",render:row=><span className="erp-stock-quantity">{formatNumber(row.QteMvtSigned)}<small>{row.AbrUnite||""}</small></span>},
  {key:"StockActuel",label:"Stock actuel",width:155,align:"right",filterType:"number",render:row=><span className="erp-stock-quantity" title="Stock actuel de l’article">{formatNumber(row.StockActuel)}<small>{row.AbrUnite||""}</small></span>},
  {key:"CodeCmd",label:"Bon de stock",width:155,filterType:"text",render:row=>row.CodeCmd||"Sans bon",renderText:row=>row.CodeCmd||""},
  {key:"PUMvt",label:"Prix unitaire",width:160,align:"right",filterType:"number",render:row=>formatCurrency(row.PUMvt,row.DeviseCode)},
  {key:"MontantMvt",label:"Montant",width:170,align:"right",filterType:"number",render:row=>formatCurrency(row.MontantMvt,row.DeviseCode)},
  {key:"MontantMvtSigned",label:"Montant signé",width:170,align:"right",filterType:"number",render:row=>formatCurrency(row.MontantMvtSigned,row.DeviseCode)},
  {key:"DeviseCode",label:"Devise",width:110,render:row=>row.DeviseCode||"Non renseignée"},
  {key:"OrigineMouvement",label:"Origine",width:200,render:row=>options.origine.find(option=>option.value===row.OrigineMouvement)?.label||row.OrigineMouvement||"—"},
  {key:"DateCmd",label:"Date du bon",width:180,render:row=>formatDate(row.DateCmd)},
  {key:"DateHeureAutoMvt",label:"Enregistré le",width:190,render:row=>formatDate(row.DateHeureAutoMvt,{withSeconds:true})},
  {key:"actions",label:"Actions",width:110,sortable:false,render:row=><div className="erp-row-actions" onClick={event=>event.stopPropagation()}><button type="button" className="erp-row-consult" title={hasOrder(row)?"Consulter le bon":"Consulter l’article"} aria-label={hasOrder(row)?"Consulter le bon "+(row.CodeCmd||"sans code"):"Consulter "+(row.NomArticle||"l’article")} disabled={blocked||(!hasOrder(row)&&!hasProduct(row))} onClick={()=>hasOrder(row)?order(row):product(row)}><AppIcon name="eye" size={18}/></button><RowActionsMenu disabled={blocked} documents={[...stockDocuments({EstCommandeEntree:Number(row.SigneStock)===1,EstCommandeSortie:Number(row.SigneStock)===-1},row.ID_cmdFk),recordExcel('mouvements',{ID_Mvt:row.ID_Mvt},'Mouvement')]} label={row.NomArticle||"Mouvement de stock"} items={[
   {label:"Consulter l’article",icon:"box",disabled:blocked||!hasProduct(row),onSelect:()=>product(row)},
   ...(hasOrder(row)?[{label:"Consulter le bon",icon:"receipt",disabled:blocked,onSelect:()=>order(row)}]:[]),
   ...(canManage?[{label:"Réceptionner du stock",icon:"stock-in",disabled:blocked||!hasProduct(row)||row.ValideArticle===false,reason:row.ValideArticle===false?"Réactivez l’article pour réceptionner du stock.":"",onSelect:()=>receive(row)}]:[])
  ]}/></div>}
 ],[options.origine,blocked,canManage,openProduct,openOrder]);
 const columnsByKey=Object.fromEntries(columns.map(column=>[column.key,column]));
 function valueLabel(key,value){return appliedLabels[key]||options[key]?.find(option=>option.value===String(value))?.label||(key==="dateFrom"||key==="dateTo"?formatDate(value):value);}
 const summary=meta?.summary;
 if(contextChanged||!canRead||denied)return <div className="logistics-screen mouvements-register"><RegisterSurface title={title} subtitle="Journal des entrées, sorties et ajustements"><div className="erp-register-table" role={canRead&&!denied?"status":"alert"}>{contextChanged&&canRead?"Chargement du registre…":error||"Vous n’avez pas accès aux mouvements de stock."}{denied?<ActionButton icon="refresh" disabled={loading} onClick={()=>setRevision(value=>value+1)}>Réessayer</ActionButton>:null}</div></RegisterSurface></div>;
 return <div className="logistics-screen mouvements-register">
  <div aria-live="polite"><StatusBanner feedback={feedback}/>{savedReceipt?<ActionButton icon="receipt" onClick={()=>openOrder(savedReceipt)}>Consulter le bon d’entrée</ActionButton>:null}</div>
  <RegisterSurface title={title} subtitle="Journal des entrées, sorties et ajustements" actions={<RegisterSettingsButton buttonRef={columnsAnchorRef} expanded={columnsOpen} onTableSettings={()=>setColumnsOpen(true)} onReferences={onToggleFkMappings}/>} tabs={<RegisterCategoryFilter label="Sens du mouvement" value={criteria.sens} options={[{value:"all",label:"Tous les mouvements"},{value:"entree",label:"Entrées"},{value:"sortie",label:"Sorties"}]} onChange={chooseDirection} disabled={loading}/>}>
   <div className="erp-register-table erp-results" data-density={density} aria-busy={loading}>
    {selected.length?<div className="erp-register-selection"><strong>{formatNumber(selected.length)} mouvement{selected.length===1?"":"s"} sélectionné{selected.length===1?"":"s"}</strong>{selected.length===1?<><ActionButton icon="box" disabled={blocked||!hasProduct(selected[0])} onClick={()=>product(selected[0])}>Article</ActionButton>{hasOrder(selected[0])?<ActionButton icon="receipt" disabled={blocked} onClick={()=>order(selected[0])}>Bon de stock</ActionButton>:null}</>:null}{canExport?<ExportMenu selection exportFile={()=>exportData("xlsx",selected)} exportCsv={()=>exportData("csv",selected)} disabled={blocked||pending||exporting||!preferences.ready||!preferences.canExport||!preferences.exportKeys.length} exporting={exporting}/>:null}<ActionButton icon="close" className="is-icon" aria-label="Effacer la sélection" disabled={loading} onClick={()=>{setSelectionReset(value=>value+1);shared.current?.clearSelectedRow?.();}}/></div>:null}
    {error?<div className="erp-table-error" role="alert">{error}<ActionButton icon="refresh" disabled={loading} onClick={()=>setRevision(value=>value+1)}>Réessayer</ActionButton></div>:null}
    <SimpleTable tablePreferences={preferences} rows={rows} columns={columns} getRowId={movementId} enableSelection selectedRowId={sharedTable?.selectedRow?.ID_Mvt??null} onSelectionChange={selectionChanged} selectionResetKey={selectionReset} defaultVisibleColumns={MOVEMENT_DEFAULT_COLUMNS} defaultPinnedColumns={[]} serverMeta={meta} serverState={grid} onServerChange={changeGrid} loading={loading} emptyMessage={error?"Les mouvements ne sont pas disponibles.":"Aucun mouvement pour ces critères."} onRowConsult={consult} consultColumns={["NomArticle","CodeArticleInterne","RefArticle","CodeCmd"]} isCellConsultable={(row,key)=>hasValue(row,key)&&(key==="CodeCmd"?hasOrder(row):hasProduct(row))} columnsPanelOpen={columnsOpen} columnsAnchorRef={columnsAnchorRef} onColumnsPanelClose={()=>setColumnsOpen(false)} onVisibleColumnsChange={setVisibleColumns} filtersVisible={filtersOpen} columnFilters={columnDraft} onColumnFilterChange={(key,value)=>setColumnDraft(current=>({...current,[key]:value}))} onApplyColumnFilters={apply} toolbar={<>
     <DataTableToolbar showSettings={false} settingsLabel="Réglages" search={search} setSearch={setSearch} onApply={apply} onReset={reset} pending={pending} take={grid.take} onTake={take=>changeGrid({take,skip:0})} filtersOpen={filtersOpen} filterControlsId={filterId} toggleFilters={()=>setFiltersOpen(value=>!value)} activeFilters={activeFilters} density={density} toggleDensity={()=>setDensity(value=>value==="airy"?"compact":"airy")} columnsOpen={columnsOpen} columnsButtonRef={columnsAnchorRef} toggleColumns={()=>setColumnsOpen(value=>!value)} loading={loading} placeholder="Rechercher un article, une référence ou un bon…" exportFile={canExport?()=>exportData("xlsx"):undefined} exportCsv={canExport?()=>exportData("csv"):undefined} exporting={exporting} exportDisabled={Boolean(error)||!meta?.filteredCount||!preferences.ready||!preferences.canExport||!preferences.exportKeys.length} error={criteriaError||exportError||preferences.error}/>
     {filtersOpen?<form id={filterId} className="erp-register-filters" onSubmit={event=>{event.preventDefault();apply();}}><div className="erp-register-filter-grid">
      {[["articleId","Article","article"],["commandeId","Bon de stock","commande"]].map(([key,label,kind])=><MovementRecordFilter key={scopeKey+key} id={filterId+key} label={label} kind={kind} value={draft[key]} selectedLabel={recordLabels[key]} scopeKey={scopeKey} onChange={(value,labelValue)=>{setDraft(current=>({...current,[key]:value}));setRecordLabels(current=>({...current,[key]:value?labelValue:""}));}}/>)}
      {["categorieId","articleTypeId","typeId","origine","sens","deviseId"].map(key=><div key={key} className="mouvements-filter-field"><label htmlFor={filterId+key}>{LABELS[key]}</label><SearchSelect id={filterId+key} label={LABELS[key]} value={draft[key]} options={[{value:EMPTY[key],label:key==="origine"?"Toutes les origines":key==="deviseId"?"Toutes les devises":"Tous"},...options[key]]} onChange={value=>setDraft(current=>({...current,[key]:value}))}/></div>)}
      {["dateFrom","dateTo"].map(key=><div key={key} className="mouvements-filter-field"><label htmlFor={filterId+key}>{LABELS[key]}</label><input id={filterId+key} type="date" value={draft[key]} onChange={event=>{setDraft(current=>({...current,[key]:event.target.value}));setCriteriaError("");}} aria-invalid={Boolean(criteriaError)} aria-describedby={criteriaError?filterId+"-error":undefined}/></div>)}
     </div>{criteriaError?<p id={filterId+"-error"} className="mouvements-choice-error" role="alert">{criteriaError}</p>:null}<div className="erp-register-filters-footer"><ActionButton variant="primary" type="submit" disabled={loading}>Appliquer les filtres</ActionButton></div></form>:null}
     {activeFilters?<div className="erp-register-chips">{activeEntries(criteria).map(([key,value])=><span key={key} className="erp-register-chip">{LABELS[key]} : {valueLabel(key,value)}<button type="button" aria-label={"Retirer le filtre "+LABELS[key]} onClick={()=>removeFilter(key)}><AppIcon name="close" size={13}/></button></span>)}{Object.entries(appliedColumnFilters).map(([key,value])=><span key={"column-"+key} className="erp-register-chip">{columnsByKey[key]?.label||"Colonne"} : {value}<button type="button" aria-label={"Retirer le filtre de colonne "+(columnsByKey[key]?.label||key)} onClick={()=>removeColumnFilter(key)}><AppIcon name="close" size={13}/></button></span>)}</div>:null}
    </>}/>
    <div className="mouvements-register-footer">{summary?<p role="status">{formatNumber(summary.total)} mouvement{Number(summary.total)===1?"":"s"} · {formatNumber(summary.articles)} article{Number(summary.articles)===1?"":"s"} · {formatNumber(summary.bons)} bon{Number(summary.bons)===1?"":"s"}</p>:null}<p>Heures : Africa/Kinshasa · Journal en lecture seule</p></div>
   </div>
  </RegisterSurface>
  {receipt!=null?<StockReceiptEditor key={scopeKey+receipt} articleId={receipt} references={references} onClose={()=>setReceipt(null)} onSaved={received}/>:null}
 </div>;
}
