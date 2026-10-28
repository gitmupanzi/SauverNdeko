import {fieldCurrencyReferences} from "../../utils/money";
import useTablePreferences from "../../hooks/useTablePreferences";
import {moduleRights} from "../../services/moduleAccess";
import RegisterCategoryFilter from "../../components/RegisterCategoryFilter";
import {useEntityScope} from "../../contexts/EntityScopeContext";
import {useEffect,useId,useMemo,useRef,useState} from "react";
import {useAuth} from "../../contexts/AuthContext";
import {useFollowupFolders} from "../../contexts/FollowupFoldersContext";
import {useConsultations} from "../../components/ConsultationProvider";
import RegisterSurface from "../../components/RegisterSurface";
import RegisterSettingsButton from "../../components/RegisterSettingsButton";
import DataTableToolbar from "../../components/DataTableToolbar";
import RowActionsMenu from "../../components/RowDocumentActions";
import {stockDocuments,recordExcel} from "../../utils/rowDocuments";
import {stockDocumentKind,canCreateStockInvoice,previousStockCode} from "../../utils/stockDocumentTypes";
import ActionButton from "../../components/ActionButton";
import AppIcon from "../../components/AppIcon";
import CategoricalSelect from "../../components/CategoricalSelect";
import {downloadApiFile} from "../../services/api";
import {currencyOptions} from "../../utils/money";
import {asArrayPayload,buildReferenceOptions,formatCurrency,formatDate,formatNumber,SimpleTable,StatusBanner} from "./logistiqueShared";
import {getLogistiqueViewConfig} from "./views";
import OrderDeleteDialog from "./OrderDeleteDialog";
import BonReturnEditor from "./BonReturnEditor";
import BonLineEditor from "./BonLineEditor";
import BonComposer from "./BonComposer";
import InvoiceEditor from "./InvoiceEditor";
import "./Commandes.css";

const CONFIG=getLogistiqueViewConfig("commandes");
const EMPTY_FILTERS={typeId:"",statutId:"",client:"",deviseId:"",payment:"all",control:"all",dateFrom:"",dateTo:""};
const DEFAULT_COLUMNS=["CodeCmd","CodeFacture","DateCmd","TypeCmd","StatutCmd","NomClientSaisi","NbLignes","QteTotale","MontantTTC","EtatPaiement","RefCmd","actions"];
const PAYMENT_OPTIONS=[{value:"non-facturee",label:"Non facturés"},{value:"non-reglee",label:"À régler"},{value:"partielle",label:"Partiellement réglés"},{value:"reglee",label:"Réglés"},{value:"retard",label:"En retard"}];
const CONTROL_OPTIONS=[{value:"sans-details",label:"Sans lignes"},{value:"incoherente",label:"Montants à vérifier"},{value:"coherente",label:"Montants cohérents"}];
const LABELS={q:"Recherche",typeId:"Type de bon",statutId:"Statut du bon",client:"Tiers",deviseId:"Devise",payment:"Facturation",control:"Contrôle",dateFrom:"Du",dateTo:"Au"};
const normalise=value=>String(value||"").normalize("NFD").replace(/[\u0300-\u036f]/g,"").toLowerCase();
const closed=row=>normalise(row?.StatusFacture).trim()==="cloturee";
function tone(value){const text=normalise(value);return /retard|incoher/.test(text)?"danger":/non |partiel|attente|sans/.test(text)?"warning":/regle|termine|clotur|coherent/.test(text)?"success":"neutral";}
function Badge({value}){return value==null||value===""?"—":<span className={"erp-status is-"+tone(value)}>{value}</span>;}
export function formatBonQuantities(row){
  const groups=Array.isArray(row.QuantitesParUnite)?row.QuantitesParUnite:[];
  return groups.length?groups.map(part=>formatNumber(part.quantite)).join(" · "):formatNumber(row.QteTotale);
}

export default function Commandes({references:receivedReferences,refreshKey,onDataChanged,onOpenDetails,sharedTable,onToggleFkMappings}) {
 const references=fieldCurrencyReferences(receivedReferences,"commandeCurrencies");
  const preferences=useTablePreferences("logistique.commandes");
  const {user}=useAuth(),consultations=useConsultations(),{refresh:refreshFolders}=useFollowupFolders(),filterId=useId();
  const canWrite=useEntityScope().canWrite&&user?.permissions?.canWriteData===true,canExport=user?.permissions?.canExportData!==false&&moduleRights(user,"logistique").canExport===true;
  const [grid,setGrid]=useState({take:25,skip:0,sortBy:"DateCmd",sortDir:"desc"}),[rows,setRows]=useState([]),[meta,setMeta]=useState(null),[loading,setLoading]=useState(true),[error,setError]=useState("");
  const [search,setSearch]=useState(sharedTable?.searchValue||""),[criteria,setCriteria]=useState(()=>({...EMPTY_FILTERS,q:sharedTable?.searchValue||""})),[filters,setFilters]=useState(EMPTY_FILTERS),[filtersOpen,setFiltersOpen]=useState(false),[filtersError,setFiltersError]=useState("");
  const [columnsOpen,setColumnsOpen]=useState(false),columnsAnchorRef=useRef(null),[visibleColumns,setVisibleColumns]=useState(DEFAULT_COLUMNS);
  const [density,setDensity]=useState(()=>{try{return localStorage.getItem("sauverndeko.table.density")==="airy"?"airy":"compact";}catch{return "compact";}});
  const [selection,setSelection]=useState([]),[selectionResetKey,setSelectionResetKey]=useState(0),[editor,setEditor]=useState(null),[deleting,setDeleting]=useState(null),[lineBon,setLineBon]=useState(null);
  const [invoiceEditorId,setInvoiceEditorId]=useState(null);
  const [returnEditorId,setReturnEditorId]=useState(null);
  const [feedback,setFeedback]=useState(null),[savedRecord,setSavedRecord]=useState(null),[savedOperation,setSavedOperation]=useState(""),[localRevision,setLocalRevision]=useState(0);
  const [exporting,setExporting]=useState(false),[exportError,setExportError]=useState(""),exportRequest=useRef(null);
  const selected=sharedTable?.selectedRow;
  const options=useMemo(()=>({typeId:buildReferenceOptions(references?.commandeTypes,"Type"),statutId:buildReferenceOptions(references?.commandeStatuses,"Statut"),client:buildReferenceOptions(references?.clients,"Tiers"),deviseId:currencyOptions(references,true),payment:PAYMENT_OPTIONS,control:CONTROL_OPTIONS}),[references]);
  const activeFilters=Object.entries(criteria).filter(([key,value])=>key==="q"?Boolean(value):value!==EMPTY_FILTERS[key]).length;
  const pending=search.trim()!==criteria.q||Object.keys(EMPTY_FILTERS).some(key=>filters[key]!==criteria[key]);
  function changeGrid(patch){setGrid(current=>({...current,...patch}));}
  function applyFilters(){
    if(filters.dateFrom&&filters.dateTo&&filters.dateFrom>filters.dateTo){setFiltersError("La date de fin doit suivre la date de début.");return;}
    const q=search.trim();setFiltersError("");setCriteria({...filters,q});sharedTable?.setSearchValue?.(q);changeGrid({skip:0});
  }
  function resetFilters(){setSearch("");setFilters(EMPTY_FILTERS);setCriteria({...EMPTY_FILTERS,q:""});setFiltersError("");sharedTable?.setSearchValue?.("");changeGrid({skip:0});}
  function removeFilter(key){if(key==="q"){setSearch("");sharedTable?.setSearchValue?.("");}else setFilters(current=>({...current,[key]:EMPTY_FILTERS[key]}));setCriteria(current=>({...current,[key]:key==="q"?"":EMPTY_FILTERS[key]}));setFiltersError("");changeGrid({skip:0});}
  function preset(key){const next={payment:key==="non-facturee"?key:key==="retard"?key:"all",control:key==="sans-details"?key:"all"};setFilters(current=>({...current,...next}));setCriteria(current=>({...current,...next}));changeGrid({skip:0});}
  function openOrder(row){consultations.openOrder(row);}
  function openLines(row){if(onOpenDetails)onOpenDetails(row);else consultations.openOrderLines?.(row);}
  function edit(row){if(canWrite)setEditor({id:row.ID_Commande});}
  function create(){if(canWrite)setEditor({id:null});}
  function addLine(row){if(canWrite&&!closed(row))setLineBon(row);}
  function saved(record,operation){setEditor(null);setDeleting(null);setSavedRecord(operation==="deleted"?null:record);setSavedOperation(operation);setFeedback({type:"success",message:{created:"Bon de stock créé.",updated:"Bon de stock mis à jour.",deleted:"Bon de stock supprimé."}[operation]});setLocalRevision(value=>value+1);refreshFolders();onDataChanged?.();if(operation==="deleted"){setSelectionResetKey(value=>value+1);sharedTable?.clearSelectedRow?.();}}
  function savedLine(){setLineBon(null);setSavedRecord(lineBon);setSavedOperation("lineCreated");setFeedback({type:"success",message:"Ligne ajoutée au bon."});setLocalRevision(value=>value+1);refreshFolders();onDataChanged?.();}
  function openInvoice(id){const row=rows.find(item=>String(item.ID_Commande)===String(id));if(meta?.features?.invoices!==true||row&&!row.CodeFacture&&!canCreateStockInvoice(row))return;setEditor(null);setInvoiceEditorId(id);}
  function savedReturn(result){setReturnEditorId(null);setSavedRecord(result.bonRetour);setSavedOperation("return");setFeedback({type:"success",message:"Restitution enregistrée."});setLocalRevision(value=>value+1);refreshFolders();onDataChanged?.();}
  function savedInvoice(record,operation){setInvoiceEditorId(null);setSavedRecord(record);setSavedOperation("invoice");setFeedback({type:"success",message:operation==="created"?"Facture créée.":"Facture mise à jour."});setLocalRevision(value=>value+1);refreshFolders();onDataChanged?.();}
  useEffect(()=>{try{localStorage.setItem("sauverndeko.table.density",density);}catch{/* Préférence facultative. */}},[density]);
  useEffect(()=>{if(sharedTable?.composerMode!=="create")return;if(canWrite)create();sharedTable?.setComposerMode?.("view");},[sharedTable?.composerMode,canWrite]);
  useEffect(()=>{
    let active=true;setLoading(true);setError("");
    CONFIG.fetchRows({...criteria,...grid,timeZone:"Africa/Kinshasa"}).then(response=>{
      if(!active)return;
      if(!response?.success){setRows([]);setMeta(null);setError(response?.message||"Les bons de stock n’ont pas pu être chargés.");setLoading(false);return;}
      const nextRows=asArrayPayload(response);setRows(nextRows);setMeta(response.meta||null);setLoading(false);
      if(selected?.ID_Commande!=null){const match=nextRows.find(row=>row.ID_Commande===selected.ID_Commande);if(match)sharedTable?.setSelectedRow?.(match);else sharedTable?.clearSelectedRow?.();}
    });return()=>{active=false;};
  },[criteria,grid,refreshKey,localRevision]);
  useEffect(()=>{setExportError("");exportRequest.current?.abort();exportRequest.current=null;setExporting(false);return()=>{exportRequest.current?.abort();};},[criteria,grid.sortBy,grid.sortDir]);
  async function exportExcel(format="xlsx", selection=null){
    if(!canExport||!preferences.ready||!preferences.canExport||!preferences.exportKeys.length||loading||pending||error||exporting||!meta?.filteredCount)return;
    const controller=new AbortController();exportRequest.current?.abort();exportRequest.current=controller;setExporting(true);setExportError("");
    const params=new URLSearchParams({...criteria,sortBy:grid.sortBy,sortDir:grid.sortDir,timeZone:"Africa/Kinshasa",columns:JSON.stringify(preferences.exportKeys),...(selection?{selection:JSON.stringify(selection.map(row=>row.ID_Commande))}:{})});
    try{await downloadApiFile("/api/logistique/registre/commandes/export."+format+"?"+params,{signal:controller.signal});}catch(failure){if(!controller.signal.aborted)setExportError(failure.message||"L’export n’a pas pu être préparé.");}finally{if(exportRequest.current===controller){exportRequest.current=null;setExporting(false);}}
  }
  const columns=[
    {key:"CodeCmd",label:"Bon de stock",width:205,render:row=><span className="erp-product-cell"><span className="erp-product-avatar"><AppIcon name="receipt" size={19}/></span><span className="erp-product-identity"><strong>{row.CodeCmd||"Bon sans code"}</strong><small>{row.RefCmd||"Référence non renseignée"}</small></span></span>,renderText:row=>row.CodeCmd||""},
    {key:"AncienCodeCmd",label:"Ancien code",width:170,render:row=>previousStockCode(row)||"—",renderText:previousStockCode},
    {key:"CodeFacture",label:"Code facture",width:165,render:row=>row.CodeFacture||"—"},
    {key:"RefCmd",label:"Référence",width:170},
    {key:"OrigineBon",label:"Origine",width:230,render:row=>({stock_initial:"Création depuis Articles / Stock initial",reprise_mouvement:"Reprise d’un mouvement historique"}[row.OrigineBon]||row.OrigineBon||"—")},
    {key:"DateCmd",label:"Date et heure",width:180,render:row=>formatDate(row.DateCmd)},
    {key:"TypeCmd",label:"Type de bon",width:160,render:row=>row.TypeCmd||options.typeId.find(option=>option.value===String(row.ID_TypeCmdFk))?.label||"—"},
    {key:"NomClientSaisi",label:"Tiers",width:185,render:row=>row.NomClientSaisi||options.client.find(option=>option.value===String(row.ID_TiersFk))?.label||"—"},
    {key:"StatutCmd",label:"Statut du bon",width:160,render:row=><Badge value={row.StatutCmd||options.statutId.find(option=>option.value===String(row.ID_StatutCmdFk))?.label}/>},
    {key:"NbLignes",label:"Lignes",width:100,align:"right",render:row=><button type="button" className="erp-object-link" aria-label={"Voir les lignes du bon "+(row.CodeCmd||"sans code")} onClick={event=>{event.stopPropagation();openLines(row);}}>{formatNumber(row.NbLignes)}</button>,renderText:row=>formatNumber(row.NbLignes)},
    {key:"NbArticlesDistincts",label:"Articles",width:110,align:"right",render:row=>formatNumber(row.NbArticlesDistincts)},
    {key:"QteTotale",label:"Quantité totale",width:180,align:"right",render:row=><button type="button" className="erp-object-link" title={row.QuantitesParUnite?.length>1?"Quantités distinctes, sans conversion":undefined} aria-label={"Voir les quantités du bon "+(row.CodeCmd||"sans code")} onClick={event=>{event.stopPropagation();openLines(row);}}>{formatBonQuantities(row)}</button>,renderText:formatBonQuantities},
    {key:"DeviseCode",label:"Devise",width:110,render:row=>row.DeviseCode||"Non renseignée"},
    {key:"MontantHT",label:"Montant HT",width:160,align:"right",render:row=>formatCurrency(row.MontantHT,row.DeviseCode)},
    {key:"MontantTTC",label:"Montant TTC",width:160,align:"right",render:row=>formatCurrency(row.MontantTTC,row.DeviseCode)},
    {key:"DateFacture",label:"Date de facture",width:180,render:row=>formatDate(row.DateFacture)},
    {key:"DateEcheancePaiement",label:"Échéance",width:180,render:row=>formatDate(row.DateEcheancePaiement)},
    {key:"MontantRegleFacture",label:"Montant réglé",width:160,align:"right",render:row=>formatCurrency(row.MontantRegleFacture,row.DeviseCode)},
    {key:"MontantResteFacture",label:"Reste à régler",width:160,align:"right",render:row=>formatCurrency(row.MontantResteFacture,row.DeviseCode)},
    {key:"EtatPaiement",label:"Paiement",width:180,render:row=><Badge value={row.EtatPaiement}/>},
    {key:"EtatControleCommande",label:"Contrôle",width:180,render:row=><Badge value={row.EtatControleCommande}/>},
    {key:"actions",label:"Actions",width:110,sortable:false,render:row=><div className="erp-row-actions" onClick={event=>event.stopPropagation()}><button type="button" className="erp-row-consult" title="Consulter le bon" aria-label={"Consulter le bon "+(row.CodeCmd||"sans code")} onClick={()=>openOrder(row)}><AppIcon name="eye" size={18}/></button><RowActionsMenu documents={[...stockDocuments(row),recordExcel('commandes',{ID_Commande:row.ID_Commande},'Bon de stock')]} label={row.CodeCmd||"Bon de stock"} items={[
      {label:"Consulter",icon:"eye",onSelect:()=>openOrder(row)},
      {label:"Voir les lignes",icon:"list",onSelect:()=>openLines(row)},
      {label:"Modifier",icon:"edit",disabled:!canWrite||closed(row),reason:!canWrite?"Accès en consultation":closed(row)?"Ce bon est clôturé.":"",onSelect:()=>edit(row)},
      {label:"Ajouter une ligne",icon:"plus",disabled:!canWrite||closed(row),reason:!canWrite?"Accès en consultation":closed(row)?"Ce bon est clôturé.":"",onSelect:()=>addLine(row)},
      ...(stockDocumentKind(row)==="sortie"&&row.returnContext?.available===true&&!row.returnContext.isReturn?[{label:"Restituer des articles",icon:"stock-in",disabled:!canWrite||row.returnContext.canReturn!==true,reason:!canWrite?"Accès en consultation":row.returnContext.reason||"",onSelect:()=>{if(canWrite&&stockDocumentKind(row)==="sortie"&&row.returnContext.canReturn===true)setReturnEditorId(row.ID_Commande);}}]:[]),
      ...(meta?.features?.invoices===true&&(row.CodeFacture||canCreateStockInvoice(row))?[{label:row.CodeFacture?"Consulter / modifier la facture":"Créer la facture",icon:"document",disabled:!canWrite&&!row.CodeFacture,reason:!canWrite&&!row.CodeFacture?"Accès en consultation":"",onSelect:()=>openInvoice(row.ID_Commande)}]:[]),
      {label:"Supprimer",icon:"trash",danger:true,disabled:!canWrite,reason:!canWrite?"Accès en consultation":"Les conditions de suppression seront vérifiées.",onSelect:()=>{if(canWrite)setDeleting(row.ID_Commande);}},
    ]}/></div>},
  ].sort((a,b)=>(a.key==="AncienCodeCmd"?0.5:DEFAULT_COLUMNS.indexOf(a.key)<0?99:DEFAULT_COLUMNS.indexOf(a.key))-(b.key==="AncienCodeCmd"?0.5:DEFAULT_COLUMNS.indexOf(b.key)<0?99:DEFAULT_COLUMNS.indexOf(b.key)));
  function filterLabel(key,value){return options[key]?.find(option=>String(option.value)===String(value))?.label||(key==="dateFrom"||key==="dateTo"?value.split("-").reverse().join("/"):value);}
  return <div className="logistics-screen commandes-register">
    <div aria-live="polite"><StatusBanner feedback={feedback}/>{savedRecord?<div className="commandes-saved-actions"><ActionButton icon="eye" onClick={()=>openOrder(savedRecord)}>Consulter le bon</ActionButton>{savedOperation==="created"&&canWrite?<ActionButton icon="plus" onClick={()=>addLine(savedRecord)}>Ajouter des lignes</ActionButton>:null}</div>:null}</div>
    <RegisterSurface title="Bons de stock" subtitle="Entrées, sorties et suivi des bons" actions={<><RegisterSettingsButton buttonRef={columnsAnchorRef} expanded={columnsOpen} onTableSettings={()=>setColumnsOpen(true)} onReferences={onToggleFkMappings}/><ActionButton icon="plus" variant="primary" onClick={create} disabled={!canWrite} title={!canWrite?"Accès en consultation":"Créer un bon de stock"}>Nouveau bon</ActionButton></>} tabs={<RegisterCategoryFilter label="Suivi des bons" value={criteria.control==="sans-details"?"sans-details":["non-facturee","retard"].includes(criteria.payment)?criteria.payment:criteria.control==="all"&&criteria.payment==="all"?"all":"custom"} options={[{value:"all",label:"Tous les bons"},{value:"sans-details",label:"Sans lignes"},{value:"non-facturee",label:"Non facturés"},{value:"retard",label:"En retard"},{value:"custom",label:"Filtres personnalisés",disabled:true}]} onChange={preset}/>}>
      <div className="erp-register-table erp-results" data-density={density} aria-busy={loading}>
        {selection.length?<div className="erp-register-selection"><strong>{selection.length===1?selection[0].CodeCmd||"Bon sélectionné":selection.length+" bons sélectionnés"}</strong>{selection.length===1?<><ActionButton icon="eye" onClick={()=>openOrder(selection[0])}>Consulter</ActionButton>{canWrite?<ActionButton icon="edit" onClick={()=>edit(selection[0])} disabled={loading||closed(selection[0])}>Modifier</ActionButton>:null}</>:null}{canExport?<><ActionButton icon="download" disabled={loading||pending||exporting||!preferences.ready||!preferences.canExport||!preferences.exportKeys.length||Boolean(error)} onClick={()=>exportExcel("xlsx",selection)}>Excel · sélection</ActionButton><ActionButton icon="download" disabled={loading||pending||exporting||!preferences.ready||!preferences.canExport||!preferences.exportKeys.length||Boolean(error)} onClick={()=>exportExcel("csv",selection)}>CSV · sélection</ActionButton></>:null}<ActionButton icon="close" className="is-icon" aria-label="Effacer la sélection" onClick={()=>{setSelectionResetKey(value=>value+1);sharedTable?.clearSelectedRow?.();}}/></div>:null}
        {error?<div className="erp-table-error" role="alert">{error}<ActionButton icon="refresh" onClick={()=>setLocalRevision(value=>value+1)}>Réessayer</ActionButton></div>:null}
        <SimpleTable tablePreferences={preferences} rows={rows} columns={columns} selectedRowId={selected?.ID_Commande??null} enableSelection onSelectionChange={next=>{setSelection(next);sharedTable?.setSelectedRow?.(next.length===1?next[0]:null);}} selectionResetKey={selectionResetKey} defaultVisibleColumns={DEFAULT_COLUMNS} defaultPinnedColumns={[]} serverMeta={meta} serverState={grid} onServerChange={changeGrid} onRowConsult={openOrder} consultColumns={["CodeCmd","AncienCodeCmd","RefCmd"]} isCellConsultable={(row,key)=>key==="AncienCodeCmd"?Boolean(previousStockCode(row)):Boolean(row[key])} loading={loading} emptyMessage={error?"Les bons ne sont pas disponibles.":"Aucun bon pour ces critères."} columnsPanelOpen={columnsOpen} columnsAnchorRef={columnsAnchorRef} onColumnsPanelClose={()=>setColumnsOpen(false)} onVisibleColumnsChange={setVisibleColumns} toolbar={<>
          <DataTableToolbar showSettings={false} settingsLabel="Réglages" search={search} setSearch={setSearch} onApply={applyFilters} onReset={resetFilters} pending={pending} take={grid.take} onTake={take=>changeGrid({take,skip:0})} filtersOpen={filtersOpen} filterControlsId={filterId} toggleFilters={()=>setFiltersOpen(value=>!value)} activeFilters={activeFilters} density={density} toggleDensity={()=>setDensity(value=>value==="airy"?"compact":"airy")} columnsOpen={columnsOpen} columnsButtonRef={columnsAnchorRef} toggleColumns={()=>setColumnsOpen(value=>!value)} loading={loading} placeholder="Rechercher un bon, une référence ou un tiers…" exportFile={canExport?()=>exportExcel():undefined} exportCsv={canExport?()=>exportExcel("csv"):undefined} exporting={exporting} exportDisabled={Boolean(error)||!meta?.filteredCount||!preferences.ready||!preferences.canExport||!preferences.exportKeys.length} error={exportError||preferences.error}/>
          {filtersOpen?<form id={filterId} className="erp-register-filters" onSubmit={event=>{event.preventDefault();applyFilters();}}><div className="erp-register-filter-grid">{Object.entries(options).map(([key,choices])=><label key={key}><span>{LABELS[key]}</span><CategoricalSelect aria-label={LABELS[key]} value={filters[key]} onChange={event=>setFilters(current=>({...current,[key]:event.target.value}))}><option value={EMPTY_FILTERS[key]}>Tous</option>{choices.map(option=><option key={option.value} value={option.value}>{option.label}</option>)}</CategoricalSelect></label>)}{["dateFrom","dateTo"].map(key=><label key={key}><span>{LABELS[key]}</span><input type="date" value={filters[key]} onChange={event=>{setFilters(current=>({...current,[key]:event.target.value}));setFiltersError("");}} aria-invalid={Boolean(filtersError)} aria-describedby={filtersError?filterId+"-error":undefined}/></label>)}</div>{filtersError?<p id={filterId+"-error"} className="erp-table-error" role="alert">{filtersError}</p>:null}<div className="erp-register-filters-footer"><ActionButton type="submit" variant="primary" disabled={loading}>Appliquer les filtres</ActionButton></div></form>:null}
          {activeFilters?<div className="erp-register-chips">{Object.entries(criteria).filter(([key,value])=>key==="q"?Boolean(value):value!==EMPTY_FILTERS[key]).map(([key,value])=><span className="erp-register-chip" key={key}>{LABELS[key]} : {filterLabel(key,value)}<button type="button" aria-label={"Retirer le filtre "+LABELS[key]} onClick={()=>removeFilter(key)}><AppIcon name="close" size={13}/></button></span>)}</div>:null}
        </>}/>
      </div>
    </RegisterSurface>
    {editor?<BonComposer key={editor.id??"new"} commandeId={editor.id} references={references} onClose={()=>setEditor(null)} onSaved={saved} invoiceAvailable={meta?.features?.invoices===true} onInvoice={openInvoice}/>:null}
    {deleting!=null?<OrderDeleteDialog key={deleting} commandeId={deleting} onClose={()=>setDeleting(null)} onSaved={saved}/>:null}
    {lineBon?<BonLineEditor key={lineBon.ID_Commande} selectedCommande={lineBon} onClose={()=>setLineBon(null)} onSaved={savedLine}/>:null}
    {returnEditorId!=null?<BonReturnEditor key={returnEditorId} commandeId={returnEditorId} onClose={()=>setReturnEditorId(null)} onSaved={savedReturn} onConsultOrder={openOrder}/>:null}
    {invoiceEditorId!=null?<InvoiceEditor key={invoiceEditorId} commandeId={invoiceEditorId} onClose={()=>setInvoiceEditorId(null)} onSaved={savedInvoice}/>:null}
  </div>;
}
