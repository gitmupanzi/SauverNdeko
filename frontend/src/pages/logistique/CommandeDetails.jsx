import {useEffect,useMemo,useRef,useState} from "react";
import {useAuth} from "../../contexts/AuthContext";
import {useConsultations} from "../../components/ConsultationProvider";
import {useFollowupFolders} from "../../contexts/FollowupFoldersContext";
import RegisterSurface from "../../components/RegisterSurface";
import DataTableToolbar from "../../components/DataTableToolbar";
import ActionButton from "../../components/ActionButton";
import AppIcon from "../../components/AppIcon";
import RowActionsMenu from "../../components/RowDocumentActions";
import {recordExcel} from "../../utils/rowDocuments";
import CategoricalSelect from "../../components/CategoricalSelect";
import {requestJson,downloadApiFile} from "../../services/api";
import {currencyOptions} from "../../utils/money";
import BonLineEditor,{BonLineDelete} from "./BonLineEditor";
import {lineKey,closedBon} from "./lineForm";
import {asArrayPayload,buildReferenceOptions,formatCurrency,formatDate,formatNumber,SimpleTable,StatusBanner,exportRowsToCsv} from "./logistiqueShared";

const EMPTY={typeId:"",statutId:"",deviseId:"",etat:"all",dateFrom:"",dateTo:""};
const DEFAULT_COLUMNS=["CodeCmd","DateCmd","NomArticle","QteCmdDetail","PUCmdDetail","MontantLigne","actions"];
const hasConsultationValue=(row,key)=>typeof row[key]==="string"&&Boolean(row[key].trim());
const bonCode=row=>hasConsultationValue(row,"CodeCmd")?row.CodeCmd.trim():"Bon sans code";
function fieldValue(key,value,references){
 if(key==="deviseId")return currencyOptions(references,true).find(item=>String(item.value)===String(value))?.label||value;
 if(key==="typeId"||key==="statutId")return buildReferenceOptions(key==="typeId"?references?.commandeTypes:references?.commandeStatuses).find(item=>String(item.value)===String(value))?.label||value;
 if(key==="etat")return value==="conforme"?"Conformes":"Incohérentes";
 return key==="dateFrom"||key==="dateTo"?formatDate(value):value;
}
export default function CommandeDetails({selectedCommande,references,refreshKey,onDataChanged,sharedTable,onToggleFkMappings,onClearCommande}) {
 const {user}=useAuth(),{openProduct,openOrder}=useConsultations(),{refresh:refreshFolders}=useFollowupFolders();
 const canWrite=user?.permissions?.canWriteData===true,canExport=user?.permissions?.canExportData!==false;
 const [search,setSearch]=useState(sharedTable?.searchValue||""),[criteria,setCriteria]=useState(()=>({...EMPTY,q:sharedTable?.searchValue||""})),[draft,setDraft]=useState(EMPTY);
 const [grid,setGrid]=useState({take:25,skip:0,sortBy:"DateCmd",sortDir:"desc"}),[meta,setMeta]=useState(null),[rows,setRows]=useState([]),[loading,setLoading]=useState(true),[error,setError]=useState("");
 const [filtersOpen,setFiltersOpen]=useState(false),[columnsOpen,setColumnsOpen]=useState(false),[visibleColumns,setVisibleColumns]=useState(DEFAULT_COLUMNS),columnsAnchorRef=useRef(null);
 const [density,setDensity]=useState(()=>{try{return localStorage.getItem("sauverndeko.table.density")==="airy"?"airy":"compact";}catch{return "compact";}});
 const [selected,setSelected]=useState([]),[selectionReset,setSelectionReset]=useState(0),[editor,setEditor]=useState(null),[deleting,setDeleting]=useState(null),[localRefresh,setLocalRefresh]=useState(0),[feedback,setFeedback]=useState(null),[savedLine,setSavedLine]=useState(null);
 const [exporting,setExporting]=useState(false),[exportError,setExportError]=useState(""),[criteriaError,setCriteriaError]=useState(""),exportRequest=useRef(null);
 const parentId=selectedCommande?.ID_Commande??null,previousParent=useRef(parentId);
 const activeFilters=Object.entries(criteria).filter(([key,value])=>key==="q"?Boolean(value):value!==EMPTY[key]).length;
 const pending=search.trim()!==criteria.q||Object.keys(EMPTY).some(key=>draft[key]!==criteria[key]);
 function changeGrid(patch){setGrid(current=>({...current,...patch}));}
 function apply(){
  if(draft.dateFrom&&draft.dateTo&&draft.dateFrom>draft.dateTo){setCriteriaError("La date de fin doit suivre la date de début.");return;}
  setCriteriaError("");const q=search.trim();setCriteria({...draft,q});sharedTable?.setSearchValue?.(q);changeGrid({skip:0});
 }
 function reset(){setSearch("");setDraft(EMPTY);setCriteria({...EMPTY,q:""});setCriteriaError("");sharedTable?.setSearchValue?.("");changeGrid({skip:0});}
 function removeFilter(key){if(key==="q"){setSearch("");sharedTable?.setSearchValue?.("");}else setDraft(current=>({...current,[key]:EMPTY[key]}));setCriteria(current=>({...current,[key]:key==="q"?"":EMPTY[key]}));changeGrid({skip:0});setCriteriaError("");}
 function edit(row){if(canWrite)setEditor({line:row});}
 function remove(row){if(canWrite)setDeleting(row);}
 function consultBon(row){openOrder({...row,ID_Commande:row.ID_CmdFk??row.ID_Commande});}
 function consultArticle(row){openProduct({...row,ID_Article:row.ID_ArticleFk});}
 function saved(record,operation){setEditor(null);setDeleting(null);setSavedLine(operation==="deleted"?null:record);setFeedback({type:"success",message:{created:"Ligne ajoutée au bon.",updated:"Ligne mise à jour.",deleted:"Ligne supprimée."}[operation]});setSelectionReset(x=>x+1);sharedTable?.clearSelectedRow?.();refreshFolders();setLocalRefresh(x=>x+1);onDataChanged?.();}
 useEffect(()=>{try{localStorage.setItem("sauverndeko.table.density",density);}catch{}},[density]);
 useEffect(()=>{if(previousParent.current===parentId)return;previousParent.current=parentId;changeGrid({skip:0});setSelectionReset(x=>x+1);},[parentId]);
 useEffect(()=>{if(sharedTable?.composerMode==="create"){if(canWrite)setEditor({line:null});sharedTable?.setComposerMode?.("view");}},[sharedTable?.composerMode,canWrite]);
 useEffect(()=>{
  let active=true;setLoading(true);setError("");
  const params=new URLSearchParams({...criteria,...grid,...(parentId?{commandeId:parentId}:{})});
  requestJson("/api/logistique/registre/lignes?"+params,{requiresAuth:true}).then(response=>{
   if(!active)return;
   if(!response?.success){setRows([]);setMeta(null);setSelected([]);setError(response?.message||"Les lignes n’ont pas pu être chargées.");setLoading(false);return;}
   setRows(asArrayPayload(response));setMeta(response.meta||null);setSelectionReset(x=>x+1);setLoading(false);
  });return()=>{active=false;};
 },[criteria,grid,parentId,refreshKey,localRefresh]);
 useEffect(()=>{setExportError("");exportRequest.current?.abort();setExporting(false);return()=>exportRequest.current?.abort();},[criteria,grid.sortBy,grid.sortDir,parentId]);
 async function exportLines(){
  if(!canExport||loading||pending||!meta?.filteredCount)return;
  const controller=new AbortController();exportRequest.current?.abort();exportRequest.current=controller;setExporting(true);setExportError("");
  const params=new URLSearchParams({...criteria,sortBy:grid.sortBy,sortDir:grid.sortDir,...(parentId?{commandeId:parentId}:{}),columns:JSON.stringify(visibleColumns.filter(key=>key!=="actions")),timeZone:Intl.DateTimeFormat().resolvedOptions().timeZone});
  try{await downloadApiFile("/api/logistique/registre/lignes/export.xlsx?"+params,{signal:controller.signal});}catch(failure){if(!controller.signal.aborted)setExportError(failure.message||"L’export a échoué.");}finally{if(!controller.signal.aborted)setExporting(false);}
 }
 const columns=useMemo(()=>[
  {key:"CodeCmd",label:"Bon de stock",width:165,render:bonCode,renderText:bonCode},
  {key:"DateCmd",label:"Date et heure",width:180,render:row=>formatDate(row.DateCmd)},
  {key:"NomArticle",label:"Article",width:260,render:row=><span className="erp-product-cell"><span className="erp-product-avatar"><AppIcon name="box" size={19}/></span><span className="erp-product-identity"><strong>{row.NomArticle||"Article #"+row.ID_ArticleFk}</strong><small>{row.CodeArticleInterne||"Code non renseigné"}</small></span></span>,renderText:row=>row.NomArticle||"Article #"+row.ID_ArticleFk},
  {key:"CodeArticleInterne",label:"Code article",width:150},
  {key:"TypeCmd",label:"Type",width:140,render:row=>row.TypeCmd||row.AbrTypeCmd||"—"},
  {key:"StatutCmd",label:"Statut du bon",width:150,render:row=>row.StatutCmd?<span className="erp-status is-neutral">{row.StatutCmd}</span>:"—"},
  {key:"QteCmdDetail",label:"Quantité",width:125,align:"right",render:row=><span className="erp-stock-quantity">{formatNumber(row.QteCmdDetail)}<small>{row.AbrUnite||""}</small></span>,renderText:row=>formatNumber(row.QteCmdDetail)},
  {key:"AbrUnite",label:"Unité",width:110},
  {key:"PUCmdDetail",label:"Prix unitaire",width:155,align:"right",render:row=>formatCurrency(row.PUCmdDetail,row.DeviseCode)},
  {key:"MontantLigne",label:"Montant",width:170,align:"right",render:row=>formatCurrency(row.MontantLigne,row.DeviseCode)},
  {key:"DeviseCode",label:"Devise",width:110,render:row=>row.DeviseCode||"Non renseignée"},
  {key:"StockActuel",label:"Stock actuel",width:130,align:"right",render:row=>formatNumber(row.StockActuel)},
  {key:"EtatLigne",label:"Contrôle",width:160,render:row=>row.EtatLigne?<span className={"erp-status is-"+(row.EtatLigne==="Valide"?"success":"warning")}>{row.EtatLigne}</span>:"—"},
  {key:"ObsCmdDetail",label:"Observation",width:240},
  {key:"LieuCmdDetail",label:"Lieu",width:110},
  {key:"actions",label:"Actions",width:120,sortable:false,render:row=><div className="erp-row-actions" onClick={event=>event.stopPropagation()}><button type="button" className="erp-row-consult" title="Bon de stock 360" aria-label={"Consulter le bon "+(row.CodeCmd||row.ID_CmdFk)} onClick={()=>consultBon(row)}><AppIcon name="eye" size={18}/></button><RowActionsMenu documents={[recordExcel('lignes',{ID_CmdFk:row.ID_CmdFk,ID_ArticleFk:row.ID_ArticleFk},'Ligne du bon')]} label={(row.CodeCmd||"Bon #"+row.ID_CmdFk)+" · "+(row.NomArticle||"Article")} items={[
   {label:"Consulter le bon",icon:"eye",onSelect:()=>consultBon(row)},
   {label:"Consulter l’article",icon:"box",onSelect:()=>consultArticle(row)},
   {label:"Modifier",icon:"edit",disabled:!canWrite||closedBon(row),reason:!canWrite?"Accès en consultation":closedBon(row)?"Ce bon est clôturé.":"",onSelect:()=>edit(row)},
   {label:"Supprimer",icon:"trash",danger:true,disabled:!canWrite||closedBon(row),reason:!canWrite?"Accès en consultation":closedBon(row)?"Ce bon est clôturé.":"",onSelect:()=>remove(row)}
  ]}/></div>}
 ],[canWrite,openProduct,openOrder]);
 const filterOptions=[
  {key:"typeId",label:"Type de bon",options:buildReferenceOptions(references?.commandeTypes,"Type")},
  {key:"statutId",label:"Statut du bon",options:buildReferenceOptions(references?.commandeStatuses,"Statut")},
  {key:"deviseId",label:"Devise",options:currencyOptions(references,true)},
  {key:"etat",label:"Contrôle",options:[{value:"conforme",label:"Conformes"},{value:"incoherente",label:"Incohérentes"}]}
 ];
 const filterLabels={q:"Recherche",typeId:"Type",statutId:"Statut",deviseId:"Devise",etat:"Contrôle",dateFrom:"Du",dateTo:"Au"};
 return <div className="logistics-screen">
  <div aria-live="polite"><StatusBanner feedback={feedback}/>{savedLine?<button type="button" className="application-back" onClick={()=>consultBon(savedLine)}>Consulter le bon<AppIcon name="arrow-up-right"/></button>:null}</div>
  <RegisterSurface title="Lignes des bons" subtitle="Articles, quantités et prix des bons de stock" actions={<><ActionButton icon="settings" onClick={onToggleFkMappings}>Réglages</ActionButton><ActionButton icon="plus" variant="primary" disabled={!canWrite} title={!canWrite?"Accès en consultation":"Ajouter une ligne à un bon de stock"} onClick={()=>setEditor({line:null})}>Nouvelle ligne</ActionButton></>}>
   {parentId?<div className="erp-register-chips"><span className="erp-register-chip">Bon de stock : {selectedCommande.CodeCmd||"#"+parentId}{onClearCommande?<button type="button" aria-label="Afficher les lignes de tous les bons" onClick={onClearCommande}><AppIcon name="close" size={13}/></button>:null}</span><button type="button" className="erp-object-link" onClick={()=>openOrder(selectedCommande)}>Consulter le bon</button></div>:null}
   <div className="erp-register-table erp-results" data-density={density} aria-busy={loading}>
    {selected.length?<div className="erp-register-selection"><strong>{selected.length} ligne{selected.length>1?"s":""} sélectionnée{selected.length>1?"s":""}</strong>{selected.length===1?<><ActionButton icon="eye" disabled={loading} onClick={()=>consultBon(selected[0])}>Consulter le bon</ActionButton>{canWrite?<><ActionButton icon="edit" disabled={loading} onClick={()=>edit(selected[0])}>Modifier</ActionButton><ActionButton icon="trash" disabled={loading} onClick={()=>remove(selected[0])}>Supprimer</ActionButton></>:null}</>:null}{canExport?<ActionButton icon="download" disabled={loading} onClick={()=>{if(canExport&&!loading)exportRowsToCsv("Lignes_bons_selection.csv",columns.filter(column=>column.key!=="actions"&&visibleColumns.includes(column.key)).concat(visibleColumns.includes("DeviseCode")?[]:[{key:"DeviseCode",label:"Devise"}]),selected);}}>CSV · sélection</ActionButton>:null}<ActionButton icon="close" className="is-icon" aria-label="Effacer la sélection" disabled={loading} onClick={()=>{setSelectionReset(x=>x+1);sharedTable?.clearSelectedRow?.();}}/></div>:null}
    {error?<div className="erp-table-error" role="alert">{error}<ActionButton icon="refresh" onClick={()=>setLocalRefresh(x=>x+1)} disabled={loading}>Réessayer</ActionButton></div>:null}
    <SimpleTable rows={rows} columns={columns} getRowId={lineKey} enableSelection onSelectionChange={next=>{setSelected(next);sharedTable?.setSelectedRow?.(next.length===1?next[0]:null);}} selectionResetKey={selectionReset} defaultVisibleColumns={DEFAULT_COLUMNS} defaultPinnedColumns={[]} serverMeta={meta} serverState={grid} onServerChange={changeGrid} loading={loading} emptyMessage={error?"Les lignes ne sont pas disponibles.":"Aucune ligne pour ces critères."} onRowConsult={(row,key)=>key==="NomArticle"||key==="CodeArticleInterne"?consultArticle(row):consultBon(row)} consultColumns={["CodeCmd","NomArticle","CodeArticleInterne"]} isCellConsultable={hasConsultationValue} columnsPanelOpen={columnsOpen} columnsAnchorRef={columnsAnchorRef} onColumnsPanelClose={()=>setColumnsOpen(false)} onVisibleColumnsChange={setVisibleColumns} toolbar={<>
     <DataTableToolbar search={search} setSearch={setSearch} onApply={apply} onReset={reset} pending={pending} take={grid.take} onTake={take=>changeGrid({take,skip:0})} filtersOpen={filtersOpen} filterControlsId="bon-line-filters" toggleFilters={()=>setFiltersOpen(value=>!value)} activeFilters={activeFilters} density={density} toggleDensity={()=>setDensity(value=>value==="airy"?"compact":"airy")} columnsOpen={columnsOpen} columnsButtonRef={columnsAnchorRef} toggleColumns={()=>setColumnsOpen(value=>!value)} loading={loading} placeholder="Rechercher un bon, un article ou un code…" exportFile={exportLines} exporting={exporting} exportDisabled={Boolean(error)||!meta?.filteredCount||!visibleColumns.some(key=>key!=="actions")} error={criteriaError||exportError}/>
     {filtersOpen?<form id="bon-line-filters" className="erp-register-filters" onSubmit={event=>{event.preventDefault();apply();}}><div className="erp-register-filter-grid">{filterOptions.map(({key,label,options})=><label key={key}><span>{label}</span><CategoricalSelect aria-label={label} value={draft[key]} onChange={event=>setDraft(current=>({...current,[key]:event.target.value}))}><option value={EMPTY[key]}>Tous</option>{options.map(option=><option key={option.value} value={option.value}>{option.label}</option>)}</CategoricalSelect></label>)}{[['dateFrom','Du'],['dateTo','Au']].map(([key,label])=><label key={key}><span>{label}</span><input type="date" value={draft[key]} onChange={event=>setDraft(current=>({...current,[key]:event.target.value}))}/></label>)}</div><div className="erp-register-filters-footer"><ActionButton variant="primary" type="submit" disabled={loading}>Appliquer les filtres</ActionButton></div></form>:null}
     {activeFilters?<div className="erp-register-chips">{Object.entries(criteria).filter(([key,value])=>key==="q"?Boolean(value):value!==EMPTY[key]).map(([key,value])=><span key={key} className="erp-register-chip">{filterLabels[key]} : {fieldValue(key,value,references)}<button type="button" aria-label={"Retirer le filtre "+filterLabels[key]} onClick={()=>removeFilter(key)}><AppIcon name="close" size={13}/></button></span>)}</div>:null}
    </>}/>
    {meta?.summary?<p className="record-editor-note" role="status">{formatNumber(meta.summary.total)} ligne{Number(meta.summary.total)===1?"":"s"} · {formatNumber(meta.summary.bons)} bon{Number(meta.summary.bons)===1?"":"s"} · {formatNumber(meta.summary.articles)} article{Number(meta.summary.articles)===1?"":"s"}</p>:null}
   </div>
  </RegisterSurface>
  {editor?<BonLineEditor key={editor.line?lineKey(editor.line):"new"} line={editor.line} selectedCommande={selectedCommande} onClose={()=>setEditor(null)} onSaved={saved}/>:null}
  {deleting?<BonLineDelete key={lineKey(deleting)} line={deleting} onClose={()=>setDeleting(null)} onSaved={saved}/>:null}
 </div>;
}
