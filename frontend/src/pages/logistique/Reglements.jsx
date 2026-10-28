import RegisterCategoryFilter from "../../components/RegisterCategoryFilter";
import {useEntityScope} from "../../contexts/EntityScopeContext";
import {useEffect,useId,useMemo,useRef,useState} from "react";
import {useAuth} from "../../contexts/AuthContext";
import {useConsultations} from "../../components/ConsultationProvider";
import {useFollowupFolders} from "../../contexts/FollowupFoldersContext";
import {moduleRights,accessSignature} from "../../services/moduleAccess";
import RegisterSurface from "../../components/RegisterSurface";
import RegisterSettingsButton from "../../components/RegisterSettingsButton";
import ConsultationTabs from "../../components/ConsultationTabs";
import DataTableToolbar from "../../components/DataTableToolbar";
import useTablePreferences from "../../hooks/useTablePreferences";
import SearchSelect from "../../components/SearchSelect";
import RowActionsMenu from "../../components/RowDocumentActions";
import {pdfDocument,recordExcel} from "../../utils/rowDocuments";
import ActionButton from "../../components/ActionButton";
import AppIcon from "../../components/AppIcon";
import {requestJson,downloadApiFile} from "../../services/api";
import {currencyOptions,formatCurrency} from "../../utils/money";
import {asArrayPayload,buildReferenceOptions,formatDate,formatNumber,SimpleTable,StatusBanner} from "./logistiqueShared";
import InvoiceEditor from "./InvoiceEditor";
import ReglementEditor,{ReglementDeleteDialog} from "./ReglementEditor";
import ReglementBatchEditor from "./ReglementBatchEditor";
import "./Reglements.css";

const COMMON={client:"",deviseId:"",dateFrom:"",dateTo:"",commandeId:""};
const INITIAL={factures:{...COMMON,payment:"all",late:"all",dueFrom:"",dueTo:""},reglements:{...COMMON,modeId:"",codeFacture:""}};
const LABELS={q:"Recherche",client:"Tiers",deviseId:"Devise",dateFrom:"Du",dateTo:"Au",commandeId:"Facture",payment:"Paiement",late:"Retard",dueFrom:"Échéance du",dueTo:"Échéance au",modeId:"Mode",codeFacture:"Facture"};
const PAYMENTS=[{value:"all",label:"Toutes les factures"},{value:"non-reglee",label:"Non réglées"},{value:"partielle",label:"Partiellement réglées"},{value:"reglee",label:"Soldées"},{value:"retard",label:"En retard"}];
const DEFAULT_COLUMNS={factures:["CodeFacture","DateFacture","NomClientSaisi","MontantFacture","TotalRegle","Reste","EtatReglement","actions"],reglements:["DateReglement","CodeFactureFk","NomClientSaisi","ModeReglement","MontantRegle","actions"]};
const normalise=value=>String(value??"").normalize("NFD").replace(/[\u0300-\u036f]/g,"").toLowerCase();
function State({value}){if(value==null||value==="")return "—";const label=normalise(value),tone=/retard/.test(label)?"danger":/non |partiel|attente|a regler/.test(label)?"warning":/solde|reglee|paye/.test(label)?"success":"neutral";return <span className={"erp-status is-"+tone}>{value}</span>;}

export default function Reglements({references,refreshKey,onDataChanged,onToggleFkMappings,section,onSectionChange}){
 const {user}=useAuth(),scope=useEntityScope(),rights=moduleRights(user,"logistique"),consultations=useConsultations(),{refresh:refreshFolders}=useFollowupFolders(),tabsId=useId();
 const canWrite=scope.canWrite&&user?.permissions?.canWriteData===true&&rights.canManage===true,canExport=user?.permissions?.canExportData!==false&&rights.canExport===true;
 const [batch,setBatch]=useState(null),[selectedInvoices,setSelectedInvoices]=useState([]),[localSection,setLocalSection]=useState("factures"),[invoiceTarget,setInvoiceTarget]=useState(null),[selectedInvoice,setSelectedInvoice]=useState(null),[editor,setEditor]=useState(null),[deleting,setDeleting]=useState(null),[invoiceEditor,setInvoiceEditor]=useState(null),[revision,setRevision]=useState(0),[feedback,setFeedback]=useState(null);
 const controlledSection=["factures","reglements"].includes(section)?section:null,active=controlledSection||localSection;
 const [columnSettingsOpen,setColumnSettingsOpen]=useState(false),columnSettingsAnchor=useRef(null);
 useEffect(()=>setColumnSettingsOpen(false),[active,scope.scopeKey]);
 function setActive(next){if(!["factures","reglements"].includes(next))return;setLocalSection(next);onSectionChange?.(next);}
 const contextKey=String(user?.IdUser??"")+":"+scope.scopeKey+":"+accessSignature(user);
 useEffect(()=>{setBatch(null);setSelectedInvoices([]);setEditor(null);setDeleting(null);setInvoiceEditor(null);setSelectedInvoice(null);setInvoiceTarget(null);setFeedback(null);},[contextKey]);
 function saved(record,operation){setEditor(null);setDeleting(null);setInvoiceEditor(null);setFeedback({type:"success",message:operation==="deleted"?"Règlement supprimé.":operation==="created"?"Règlement enregistré.":"Règlement mis à jour."});setRevision(value=>value+1);refreshFolders();onDataChanged?.();}
 function newPayment(row){if(canWrite)setEditor({id:null,commandeId:row?.ID_Commande??null});}
 function openPayments(row){setInvoiceTarget(row);setActive("reglements");}
 return <div className="logistics-screen finance-screen"><div aria-live="polite"><StatusBanner feedback={feedback}/></div>
  <RegisterSurface title={controlledSection?(active==="factures"?"Factures":"Règlements"):"Factures et règlements"} subtitle={controlledSection?(active==="factures"?"Suivi des factures émises":"Journal des paiements"):"Factures émises et journal des paiements"} actions={<><RegisterSettingsButton buttonRef={columnSettingsAnchor} expanded={columnSettingsOpen} onTableSettings={()=>setColumnSettingsOpen(true)} onReferences={onToggleFkMappings}/><ActionButton icon="plus" variant="primary" disabled={!canWrite} onClick={()=>setBatch({initialInvoices:active==="factures"?selectedInvoices:[]})}>Préparer des règlements</ActionButton></>} tabs={controlledSection?null:<ConsultationTabs tabs={[{key:"factures",label:"Factures",icon:"document"},{key:"reglements",label:"Règlements",icon:"wallet"}]} value={active} onChange={setActive} label="Factures et règlements" idPrefix={tabsId}/>}>
   {["factures","reglements"].map(kind=><section key={kind} role={controlledSection?"region":"tabpanel"} id={tabsId+"-panel-"+kind} aria-labelledby={controlledSection?undefined:tabsId+"-tab-"+kind} aria-label={controlledSection?(kind==="factures"?"Factures":"Règlements"):undefined} hidden={active!==kind} tabIndex={active===kind?0:-1}>
    <FinanceRegister kind={kind} enabled={active===kind} settingsOpen={active===kind&&columnSettingsOpen} onSettingsClose={()=>setColumnSettingsOpen(false)} settingsAnchor={columnSettingsAnchor} references={references} contextKey={contextKey} refreshKey={String(refreshKey??"")+":"+revision} canWrite={canWrite} canExport={canExport} invoiceTarget={kind==="reglements"?invoiceTarget:null} clearInvoiceTarget={()=>setInvoiceTarget(null)} onSelectInvoice={setSelectedInvoice} onSelectInvoices={setSelectedInvoices} onNewPayment={newPayment} onEditPayment={row=>{if(canWrite)setEditor({id:row.ID_Reglement});}} onViewPayment={row=>setEditor({id:row.ID_Reglement,readOnly:true})} onDeletePayment={row=>{if(canWrite)setDeleting(row.ID_Reglement);}} onInvoice={row=>setInvoiceEditor(row.ID_Commande)} openInvoice={consultations.openOrderInvoice} openPayments={openPayments} openOrder={consultations.openOrder}/>
   </section>)}
  </RegisterSurface>
  {batch?<ReglementBatchEditor references={references} initialInvoices={batch.initialInvoices} onClose={()=>setBatch(null)} onSaved={data=>{setBatch(null);saved(data,"created");const count=data.reglements?.length||0;setFeedback({type:"success",message:count===1?"Règlement enregistré.":count+" règlements enregistrés."});}}/>:null}
  {editor?<ReglementEditor key={editor.id??"new"} reglementId={editor.id} commandeId={editor.commandeId} readOnly={editor.readOnly===true} onClose={()=>setEditor(null)} onSaved={saved}/>:null}
  {deleting!=null?<ReglementDeleteDialog key={deleting} reglementId={deleting} onClose={()=>setDeleting(null)} onSaved={saved}/>:null}
  {invoiceEditor!=null?<InvoiceEditor key={invoiceEditor} commandeId={invoiceEditor} onClose={()=>setInvoiceEditor(null)} onSaved={()=>{setInvoiceEditor(null);setRevision(value=>value+1);refreshFolders();onDataChanged?.();setFeedback({type:"success",message:"Facture mise à jour."});}}/>:null}
 </div>;
}

export function FinanceRegister({kind,enabled,settingsOpen,onSettingsClose,settingsAnchor,references,contextKey,refreshKey,canWrite,canExport,invoiceTarget,clearInvoiceTarget,onSelectInvoice,onSelectInvoices,onNewPayment,onEditPayment,onViewPayment,onDeletePayment,onInvoice,openInvoice,openPayments,openOrder}){
 const preferences=useTablePreferences("logistique."+kind);
 const invoices=kind==="factures",filterId=useId(),localColumnsRef=useRef(null),columnsRef=settingsAnchor||localColumnsRef,exportRequest=useRef(null),previousContext=useRef(contextKey);
 const [rows,setRows]=useState([]),[meta,setMeta]=useState(null),[loading,setLoading]=useState(true),[error,setError]=useState(""),[reload,setReload]=useState(0);
 const [search,setSearch]=useState(""),[filters,setFilters]=useState(INITIAL[kind]),[criteria,setCriteria]=useState({...INITIAL[kind],q:""}),[filtersOpen,setFiltersOpen]=useState(false),[filterError,setFilterError]=useState("");
 const [grid,setGrid]=useState({take:25,skip:0,sortBy:invoices?"DateFacture":"DateReglement",sortDir:"desc"}),[selection,setSelection]=useState([]),[selectionReset,setSelectionReset]=useState(0),[visibleColumns,setVisibleColumns]=useState(DEFAULT_COLUMNS[kind]),[columnsOpen,setColumnsOpen]=useState(false),[indicators,setIndicators]=useState(false);
 const [density,setDensity]=useState(()=>{try{return localStorage.getItem("sauverndeko.table.density")==="airy"?"airy":"compact";}catch{return "compact";}}),[exporting,setExporting]=useState(false),[exportError,setExportError]=useState("");
 const blocked=!enabled||loading||Boolean(error),pending=search.trim()!==criteria.q||Object.keys(INITIAL[kind]).some(key=>filters[key]!==criteria[key]),activeFilters=Object.entries(criteria).filter(([key,value])=>key==="q"?Boolean(value):value!==INITIAL[kind][key]).length;
 useEffect(()=>{try{localStorage.setItem("sauverndeko.table.density",density);}catch{}},[density]);
 useEffect(()=>{if(invoices)return;const id=invoiceTarget?.ID_Commande!=null?String(invoiceTarget.ID_Commande):"";setFilters(current=>({...current,commandeId:id}));setCriteria(current=>({...current,commandeId:id}));setGrid(current=>({...current,skip:0}));},[invoiceTarget?.ID_Commande,invoices]);
 useEffect(()=>{
  if(previousContext.current===contextKey)return;previousContext.current=contextKey;setRows([]);setMeta(null);setSelection([]);setSelectionReset(value=>value+1);setSearch("");setFilters(INITIAL[kind]);setCriteria({...INITIAL[kind],q:""});setGrid(current=>({...current,skip:0}));
 },[contextKey,kind]);
 useEffect(()=>{
  if(!enabled)return;let live=true;setLoading(true);setError("");
  const query=new URLSearchParams({...criteria,...grid,timeZone:"Africa/Kinshasa"});
  requestJson("/api/logistique/registre/"+kind+"?"+query,{requiresAuth:true}).then(response=>{if(!live)return;if(!response?.success){if([401,403].includes(response?.status)){setRows([]);setMeta(null);setSelection([]);setSelectionReset(value=>value+1);if(invoices){onSelectInvoice?.(null);onSelectInvoices?.([]);}}setError(response?.message||"La liste n’a pas pu être chargée.");setLoading(false);return;}setRows(asArrayPayload(response));setMeta(response.meta||null);setLoading(false);});
  return()=>{live=false;};
 },[kind,enabled,contextKey,criteria,grid,refreshKey,reload]);
 useEffect(()=>{setExportError("");exportRequest.current?.abort();exportRequest.current=null;setExporting(false);return()=>exportRequest.current?.abort();},[criteria,grid.sortBy,grid.sortDir,enabled,contextKey]);
 function changeGrid(patch){setGrid(current=>({...current,...patch}));}
 function apply(){if(filters.dateFrom&&filters.dateTo&&filters.dateFrom>filters.dateTo||invoices&&filters.dueFrom&&filters.dueTo&&filters.dueFrom>filters.dueTo){setFilterError("La date de fin doit suivre la date de début.");return;}setCriteria({...filters,q:search.trim()});setFilterError("");changeGrid({skip:0});}
 function reset(){setSearch("");setFilters(INITIAL[kind]);setCriteria({...INITIAL[kind],q:""});setFilterError("");changeGrid({skip:0});if(!invoices)clearInvoiceTarget?.();}
 function removeFilter(key){if(key==="q")setSearch("");else setFilters(current=>({...current,[key]:INITIAL[kind][key]}));setCriteria(current=>({...current,[key]:key==="q"?"":INITIAL[kind][key]}));changeGrid({skip:0});if(key==="commandeId")clearInvoiceTarget?.();}
 function preset(payment){setFilters(current=>({...current,payment}));setCriteria(current=>({...current,payment}));changeGrid({skip:0});}
 const options={client:[{value:"",label:"Tous les tiers"},...buildReferenceOptions(references?.clients)],deviseId:[{value:"",label:"Toutes les devises"},...currencyOptions(references,true)],...(invoices?{payment:PAYMENTS,late:[{value:"all",label:"Tous"},{value:"true",label:"En retard"},{value:"false",label:"Sans retard"}]}:{modeId:[{value:"",label:"Tous les modes"},...buildReferenceOptions(references?.reglementModes)]})};
 const dateKeys=invoices?["dateFrom","dateTo","dueFrom","dueTo"]:["dateFrom","dateTo"];
 function labelFor(key,value){return options[key]?.find(option=>String(option.value)===String(value))?.label||(key==="commandeId"?invoiceTarget?.CodeFacture||"Bon sélectionné":dateKeys.includes(key)?value.split("-").reverse().join("/"):value);}
 async function exportData(format="xlsx",selected=null){
  if(!canExport||!preferences.ready||!preferences.canExport||!preferences.exportKeys.length||blocked||pending||exporting||!meta?.filteredCount||selected&&!selected.length)return;const controller=new AbortController();exportRequest.current?.abort();exportRequest.current=controller;setExporting(true);setExportError("");
  const query=new URLSearchParams({...criteria,sortBy:grid.sortBy,sortDir:grid.sortDir,timeZone:"Africa/Kinshasa",columns:JSON.stringify(preferences.exportKeys),...(selected?{selection:JSON.stringify(selected.map(row=>invoices?row.ID_Commande:row.ID_Reglement))}:{})});
  try{await downloadApiFile("/api/logistique/registre/"+kind+"/export."+format+"?"+query,{signal:controller.signal});}catch(failure){if(!controller.signal.aborted)setExportError(failure.message||"L’export n’a pas pu être préparé.");}finally{if(exportRequest.current===controller){exportRequest.current=null;setExporting(false);}}
 }
 function consult(row){if(blocked)return;if(invoices)openInvoice(row);else onViewPayment(row);}
 const columns=invoices?[
  {key:"CodeFacture",label:"Facture",width:190,render:row=><span className="erp-product-cell"><span className="erp-product-avatar"><AppIcon name="document" size={18}/></span><span className="erp-product-identity"><strong>{row.CodeFacture||"—"}</strong><small>{row.CodeCmd||""}</small></span></span>},
  {key:"DateFacture",label:"Date de facture",width:175,render:row=>formatDate(row.DateFacture)},
  {key:"CodeCmd",label:"Bon de stock",width:150},{key:"NomClientSaisi",label:"Tiers",width:200},
  {key:"MontantFacture",label:"Montant facturé",width:175,align:"right",render:row=>formatCurrency(row.MontantFacture,row.DeviseCode)},
  {key:"TotalRegle",label:"Réglé",width:155,align:"right",render:row=>formatCurrency(row.TotalRegle,row.DeviseCode)},
  {key:"Reste",label:"Solde à régler",width:175,align:"right",render:row=>formatCurrency(row.Reste,row.DeviseCode)},
  {key:"EtatReglement",label:"Paiement",width:170,render:row=><State value={row.EtatReglement}/>},
  {key:"DateEcheancePaiement",label:"Échéance",width:175,render:row=>formatDate(row.DateEcheancePaiement)},
  {key:"NbReglements",label:"Règlements",width:110,align:"right",render:row=>formatNumber(row.NbReglements)},
  {key:"DernierReglement",label:"Dernier règlement",width:175,render:row=>formatDate(row.DernierReglement)},
  {key:"MontantAvoirAEtablir",label:"Avoir à établir",width:170,align:"right",render:row=>formatCurrency(row.MontantAvoirAEtablir,row.DeviseCode)},
  {key:"DeviseCode",label:"Devise",width:100},
  {key:"actions",label:"Actions",width:105,sortable:false,render:row=><RowActionsMenu disabled={blocked} documents={[...(row.EstFactureSnapshot===true?[pdfDocument('facture',row.ID_Commande,'facture','Facture')]:[]),recordExcel('factures',{ID_Commande:row.ID_Commande},'Facture')]} label={row.CodeFacture||"Facture"} items={[{label:"Consulter la facture",icon:"eye",disabled:blocked,onSelect:()=>openInvoice(row)},{label:"Voir les règlements",icon:"wallet",disabled:blocked,onSelect:()=>openPayments(row)},{label:"Enregistrer un règlement",icon:"plus",disabled:blocked||!canWrite,reason:!canWrite?"Accès en consultation":"",onSelect:()=>onNewPayment(row)},...(meta?.features?.invoices===true?[{label:"Modifier la facture",icon:"edit",disabled:blocked||!canWrite,onSelect:()=>onInvoice(row)}]:[]),{label:"Bon d’origine",icon:"receipt",disabled:blocked,onSelect:()=>openOrder(row)}]}/>},
 ]:[
  {key:"DateReglement",label:"Date et heure",width:185,render:row=>formatDate(row.DateReglement)},
  {key:"CodeFactureFk",label:"Facture",width:170,render:row=><button type="button" className="erp-object-link" disabled={blocked||!row.ID_Commande} onClick={event=>{event.stopPropagation();openInvoice(row);}}>{row.CodeFactureFk||"—"}</button>},
  {key:"CodeCmd",label:"Bon de stock",width:150},{key:"NomClientSaisi",label:"Tiers",width:210},{key:"ModeReglement",label:"Mode de règlement",width:180},
  {key:"MontantRegle",label:"Montant réglé",width:185,align:"right",render:row=>formatCurrency(row.MontantRegle,row.DeviseCode)},{key:"DeviseCode",label:"Devise",width:100},
  {key:"actions",label:"Actions",width:105,sortable:false,render:row=><RowActionsMenu disabled={blocked} documents={[pdfDocument('reglement',row.ID_Reglement,'recu','Reçu de règlement'),recordExcel('reglements',{ID_Reglement:row.ID_Reglement},'Règlement')]} label={"Règlement du "+formatDate(row.DateReglement)} items={[{label:"Consulter",icon:"eye",disabled:blocked,onSelect:()=>onViewPayment(row)},{label:"Modifier",icon:"edit",disabled:blocked||!canWrite,onSelect:()=>onEditPayment(row)},{label:"Consulter la facture",icon:"document",disabled:blocked||!row.ID_Commande,onSelect:()=>openInvoice(row)},{label:"Supprimer",icon:"trash",danger:true,disabled:blocked||!canWrite,onSelect:()=>onDeletePayment(row)}]}/>},
 ];
 const amountLabels=invoices?{MontantFacture:"Facturé",TotalRegle:"Réglé",Reste:"Solde à régler",MontantAvoirAEtablir:"Avoir à établir"}:{MontantRegle:"Montant réglé"};
 return <div className="erp-register-table erp-results finance-register" data-density={density} aria-busy={loading}>
  {invoices?<RegisterCategoryFilter className="is-inline" label="État des factures" value={criteria.payment} options={PAYMENTS} onChange={preset}/>:null}
  {selection.length?<div className="erp-register-selection"><strong>{selection.length===1?(invoices?selection[0].CodeFacture:selection[0].CodeFactureFk):selection.length+" éléments sélectionnés"}</strong>{selection.length===1?<ActionButton icon="eye" disabled={blocked} onClick={()=>consult(selection[0])}>Consulter</ActionButton>:null}{["xlsx","csv"].map(format=><ActionButton key={format} icon="download" disabled={!canExport||blocked||pending||exporting||!preferences.ready||!preferences.canExport||!preferences.exportKeys.length} onClick={()=>exportData(format,selection)}>{format==="xlsx"?"Excel":"CSV"} · sélection</ActionButton>)}<ActionButton icon="close" className="is-icon" aria-label="Effacer la sélection" onClick={()=>{setSelection([]);setSelectionReset(value=>value+1);if(invoices){onSelectInvoice?.(null);onSelectInvoices?.([]);}}}/></div>:null}
  {error?<div className="erp-table-error" role="alert"><span>{error}</span><ActionButton icon="refresh" onClick={()=>setReload(value=>value+1)} disabled={loading}>Réessayer</ActionButton></div>:null}
  <SimpleTable tablePreferences={preferences} rows={rows} columns={columns} getRowId={row=>invoices?row.ID_Commande:row.ID_Reglement} enableSelection onSelectionChange={next=>{if(blocked)return;setSelection(next);if(invoices){onSelectInvoice?.(next.length===1?next[0]:null);onSelectInvoices?.(next);}}} selectionResetKey={selectionReset} defaultVisibleColumns={DEFAULT_COLUMNS[kind]} defaultPinnedColumns={[]} serverMeta={meta} serverState={grid} onServerChange={changeGrid} loading={loading} emptyMessage={invoices?"Aucune facture pour ces critères.":"Aucun règlement pour ces critères."} onRowConsult={consult} consultColumns={invoices?["CodeFacture"]:["DateReglement"]} columnsPanelOpen={settingsOpen??columnsOpen} columnsAnchorRef={columnsRef} onColumnsPanelClose={()=>{setColumnsOpen(false);onSettingsClose?.();}} onVisibleColumnsChange={setVisibleColumns} toolbar={<>
   <DataTableToolbar showSettings={false} settingsLabel="Réglages" search={search} setSearch={setSearch} onApply={apply} onReset={reset} pending={pending} take={grid.take} onTake={take=>changeGrid({take,skip:0})} filtersOpen={filtersOpen} filterControlsId={filterId} toggleFilters={()=>setFiltersOpen(value=>!value)} activeFilters={activeFilters} density={density} toggleDensity={()=>setDensity(value=>value==="airy"?"compact":"airy")} columnsOpen={columnsOpen} columnsButtonRef={columnsRef} toggleColumns={()=>setColumnsOpen(value=>!value)} loading={loading} exportFile={canExport?()=>exportData("xlsx"):undefined} exportCsv={canExport?()=>exportData("csv"):undefined} exporting={exporting} exportDisabled={Boolean(error)||!meta?.filteredCount||!preferences.ready||!preferences.canExport||!preferences.exportKeys.length} error={exportError||preferences.error} placeholder={invoices?"Rechercher une facture, un bon ou un tiers…":"Rechercher une facture, un tiers ou un paiement…"}/>
   {filtersOpen?<form id={filterId} className="erp-register-filters" onSubmit={event=>{event.preventDefault();apply();}}><div className="erp-register-filter-grid">{Object.entries(options).map(([key,choices])=><div className="finance-filter" key={key}><label htmlFor={filterId+key}>{LABELS[key]}</label><SearchSelect id={filterId+key} label={LABELS[key]} value={filters[key]} options={choices} onChange={value=>setFilters(current=>({...current,[key]:value}))}/></div>)}{dateKeys.map(key=><label key={key}><span>{LABELS[key]}</span><input type="date" value={filters[key]} onChange={event=>setFilters(current=>({...current,[key]:event.target.value}))}/></label>)}</div>{filterError?<p className="erp-table-error" role="alert">{filterError}</p>:null}<div className="erp-register-filters-footer"><ActionButton type="submit" variant="primary" disabled={loading}>Appliquer</ActionButton></div></form>:null}
   {activeFilters?<div className="erp-register-chips">{Object.entries(criteria).filter(([key,value])=>key==="q"?Boolean(value):value!==INITIAL[kind][key]).map(([key,value])=><span className="erp-register-chip" key={key}>{LABELS[key]} : {labelFor(key,value)}<button type="button" aria-label={"Retirer le filtre "+LABELS[key]} onClick={()=>removeFilter(key)}><AppIcon name="close" size={12}/></button></span>)}</div>:null}
  </>}/>
  {meta?.amountsByCurrency?<div className="finance-indicators"><button type="button" className="erp-object-link" aria-expanded={indicators} onClick={()=>setIndicators(value=>!value)}><AppIcon name={indicators?"chevron-up":"chevron-down"} size={13}/>{indicators?"Masquer les indicateurs":"Afficher les indicateurs"}</button>{indicators?<div className="finance-amounts">{Object.entries(amountLabels).map(([key,label])=><section key={key}><h3>{label}</h3>{Array.isArray(meta.amountsByCurrency[key])&&meta.amountsByCurrency[key].length?meta.amountsByCurrency[key].map((group,index)=><strong key={String(group.id??group.code??index)}>{formatCurrency(group.value,group.code)}</strong>):<span>Aucun montant.</span>}</section>)}</div>:null}</div>:null}
 </div>;
}
