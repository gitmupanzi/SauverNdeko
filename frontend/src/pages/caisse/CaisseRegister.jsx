import {useEffect,useId,useRef,useState} from "react";
import {useEntityScope} from "../../contexts/EntityScopeContext";
import {requestJson,downloadApiFile} from "../../services/api";
import useTablePreferences from "../../hooks/useTablePreferences";
import AppIcon from "../../components/AppIcon";
import ActionButton from "../../components/ActionButton";
import RegisterSurface from "../../components/RegisterSurface";
import RegisterSettingsButton from "../../components/RegisterSettingsButton";
import DataTableToolbar from "../../components/DataTableToolbar";
import SearchSelect from "../../components/SearchSelect";
import RowActionsMenu from "../../components/RowActionsMenu";
import {SimpleTable,formatDate} from "../logistique/logistiqueShared";
import {formatCurrency,compareDecimal} from "../../utils/money";
import {CAISSE_ROOT,CAISSE_REGISTERS,CAISSE_LABELS,caisseValidationLabel,caisseQuery,caisseOptions,cashboxOptions,ENTRY_STATES,ENTRY_SENSES} from "./caisseModel";
import CaisseReferences from "./CaisseReferences";

export function CaisseStatus({record}){
 const value=record.EtatEcriture&&record.ValidePaiement===false?"ABANDONED":record.EtatEcriture|| (record.Actif===false?"INACTIVE":"ACTIVE"),posted=value==="POSTED",text=posted?"Validée":value==="DRAFT"?"Brouillon":value==="ABANDONED"?"Abandonnée":value==="INACTIVE"?"Inactive":"Active";
 return <span className={"erp-status "+(posted||value==="ACTIVE"?"is-success":"is-neutral")}>{text}</span>;
}
export default function CaisseRegister({kind,context,references={},refresh=0,initial={},onOpen,compact=false,title,onCreate}){
 const scope=useEntityScope(),definition=CAISSE_REGISTERS[kind],preferences=useTablePreferences("caisse."+kind),anchor=useRef(null),prefix=useId(),exportRequest=useRef(null);
 const [criteria,setCriteria]=useState(()=>({q:"",filters:{},...initial})),[draft,setDraft]=useState(()=>({q:"",filters:{},...initial})),[grid,setGrid]=useState({take:25,skip:0,sortBy:definition.sort,sortDir:definition.direction});
 const [state,setState]=useState({owner:"",key:"",rows:[],meta:null,loading:true,error:""}),[retry,setRetry]=useState(0),[filtersOpen,setFiltersOpen]=useState(false),[settings,setSettings]=useState(false),[referencesOpen,setReferencesOpen]=useState(false),[density,setDensity]=useState("compact"),[exporting,setExporting]=useState(false),[exportError,setExportError]=useState("");
 const owner=scope.scopeKey+":"+kind,key=owner+":"+refresh+":"+retry+":"+JSON.stringify(criteria)+":"+JSON.stringify(grid),current=state.key===key?state:{rows:state.owner===owner?state.rows:[],meta:null,loading:true,error:""},pending=JSON.stringify(criteria)!==JSON.stringify(draft);
 const [selection,setSelection]=useState([]);
 const scopedWrite=Boolean(scope.entityId)&&!context?.readOnly;
 const canManage=context?.tabs?.[kind]?.canManage===true&&scopedWrite,canExport=context?.tabs?.[kind]?.canExport===true;
 const createEntry=scopedWrite&&context?.canCreateEntries===true,createClosure=scopedWrite&&context?.tabs?.clotures?.canManage===true;
 const canValidate=kind==="ecritures"&&scopedWrite&&context?.canValidateEntries===true;
 const canEditDrafts=kind==="ecritures"&&scopedWrite&&context?.canEditDrafts===true;
 const canCreate=kind==="ecritures"?createEntry:canManage;
 function validate(rows){
  onOpen({kind,mode:"valider",rows:rows.map(row=>({id:row.IdPaiement,_version:row._version,code:row.CodePaiement}))});
 }
 const hidden=context?.hiddenFields?.[kind]||[], hiddenExports=context?.hiddenExportFields?.[kind]||[];
 const exportKeys=preferences.exportKeys.filter(key=>!hiddenExports.includes(key));
 function changeGrid(patch){setGrid(previous=>({...previous,...patch}));}
 function apply(){const next={...draft,q:draft.q.trim()};setDraft(next);setCriteria(next);changeGrid({skip:0});}
 function reset(){setDraft({q:"",filters:{}});setCriteria({q:"",filters:{}});changeGrid({skip:0});}
 useEffect(()=>{
  const controller=new AbortController();setState(previous=>({...previous,owner,key,rows:previous.owner===owner?previous.rows:[],meta:previous.owner===owner?previous.meta:null,loading:true,error:""}));
  requestJson(CAISSE_ROOT+"/registres/"+kind+"?"+caisseQuery(criteria,grid),{requiresAuth:true,signal:controller.signal}).then(response=>{
   if(controller.signal.aborted)return;
   if(!response?.success||!Array.isArray(response.data?.rows)){setState({owner,key,rows:[],meta:null,loading:false,error:response?.message||"La liste n’a pas pu être chargée."});return;}
   const total=Number(response.data.total||0);
   if(grid.skip&&grid.skip>=total){changeGrid({skip:Math.max(0,(Math.ceil(total/grid.take)-1)*grid.take)});return;}
   setState({owner,key,rows:response.data.rows,meta:{filteredCount:total,totalCount:total,take:grid.take,skip:grid.skip},loading:false,error:""});
  });return()=>controller.abort();
 },[key]);
 useEffect(()=>{exportRequest.current?.abort();setExporting(false);setExportError("");return()=>exportRequest.current?.abort();},[key]);
 const moneyKeys=["MontantCaisse","MontantPaiement","SoldeTheorique","MontantCompte","SoldeApres","MontantSigne","EcartsRapprochement","Ecart","EntreesBrouillon","SortiesBrouillon","SoldePrevisionnel"];
 const standard=kind==="caisses"?["CodeCaisse","NomCaisse","DeviseCode","MontantCaisse","SoldeTheorique","TypeCaisse","Responsable","Actif","NomEntite","EntreesBrouillon","SortiesBrouillon","SoldePrevisionnel"]:kind==="ecritures"?["CodePaiement","DatePaiement","NomCaisse","LibellePaiement","SensMouvement","MontantPaiement","EtatEcriture","ReferenceExterne","NomTiers","Auteur","Validateur","ModeValidation","CodeCompensateur","ObsPaiement","NomEntite"]:["ID_ClotureCaisse","ClotureLe","NomCaisse","SoldeTheorique","MontantCompte","Ecart","Auteur","Motif","NomEntite"];
 const base=[...new Set([...standard,...preferences.catalogue.filter(column=>column.id!=="actions").map(column=>column.id)])].filter(column=>!hidden.includes(column));
 const columns=[...base.map(column=>({key:column,label:preferences.catalogue.find(item=>item.id===column)?.label||CAISSE_LABELS[column]||column,width:["LibellePaiement","Motif","ObsPaiement"].includes(column)?280:170,render:row=>{
  if(moneyKeys.includes(column))return column==="Ecart"?<button type="button" className={"caisse-value-link "+(compareDecimal(row.Ecart,"0")===0?"":"is-warning")} onClick={event=>{event.stopPropagation();onOpen({kind,id:row[definition.id]});}}>{formatCurrency(row[column],row.DeviseCode)}</button>:<span className="caisse-money">{formatCurrency(row[column],row.DeviseCode)}</span>;
  if(["DatePaiement","ClotureLe","CreeLe","ModifieLe","ValideLe","DerniereClotureLe"].includes(column))return formatDate(row[column]);
  if(column==="EtatEcriture"||column==="Actif")return <CaisseStatus record={row}/>;
  if(column==="SensMouvement")return <span className={"erp-status "+(String(row.SensMouvement)==="1"?"is-success":"is-neutral")}>{String(row.SensMouvement)==="1"?"Encaissement":"Décaissement"}</span>;
  if(column==="ModeValidation")return caisseValidationLabel(row.ModeValidation)||"—";
  if(column==="Responsable")return row.Responsable||row.NomResponsable||"Non affecté";
  if(column==="ID_ClotureCaisse")return <strong>{"CL-"+row.ID_ClotureCaisse}</strong>;
  return typeof row[column]==="boolean"?(row[column]?"Oui":"Non"):row[column]??"—";
 }})),{key:"actions",label:"Actions",width:110,sortable:false,render:row=><div className="erp-row-actions" onClick={event=>event.stopPropagation()}><button type="button" className="erp-row-consult" aria-label={"Consulter "+(row.CodeCaisse||row.CodePaiement||row.CodeCloture||"la clôture")} onClick={()=>onOpen({kind,id:row[definition.id]})}><AppIcon name="eye"/></button><RowActionsMenu label={row.CodeCaisse||row.CodePaiement||"Clôture"} items={[
   {label:"Consulter",icon:"eye",onSelect:()=>onOpen({kind,id:row[definition.id]})},
   ...(kind==="caisses"?[
    ...(canManage?[{label:"Modifier",icon:"edit",onSelect:()=>onOpen({kind,id:row.IdCaisse,mode:"edit"})}]:[]),
    ...(createEntry?[{label:"Nouvelle écriture",icon:"plus",disabled:row.Actif===false,onSelect:()=>onOpen({kind:"ecritures",defaults:{IdCaisseFk:row.IdCaisse},mode:"create"})}]:[]),
    ...(createClosure?[{label:"Clôturer la caisse",icon:"check-circle",disabled:row.Actif===false,onSelect:()=>onOpen({kind:"clotures",defaults:{IdCaisseFk:row.IdCaisse},mode:"create"})}]:[]),
   ]:[]),
   ...(canEditDrafts&&row.EtatEcriture==="DRAFT"&&row.ValidePaiement!==false?[{label:"Modifier le brouillon",icon:"edit",onSelect:()=>onOpen({kind,id:row.IdPaiement,mode:"edit"})}]:[]),
   ...(canValidate&&row.ValidationAutorisee===true?[{label:"Valider",icon:"check-circle",onSelect:()=>validate([row])}]:[]),
   ...(canManage&&kind==="ecritures"&&row.ValidePaiement!==false&&row.EtatEcriture==="POSTED"&&!row.IdCompensateurFk&&!row.IdPaiementOrigineFk&&row.ContrepassationAutorisee?[{label:"Contrepasser",icon:"reset",onSelect:()=>onOpen({kind,id:row.IdPaiement,mode:"contrepasser"})}]:[]),
  ]}/></div>}];
 async function exportFile(format){
  if(!canExport||pending||current.loading||exporting||!preferences.ready||!preferences.canExport||!exportKeys.length)return;
  const controller=new AbortController();exportRequest.current=controller;setExporting(true);setExportError("");
  const query=caisseQuery(criteria,{sortBy:grid.sortBy,sortDir:grid.sortDir});query.set("columns",JSON.stringify(exportKeys));
  try{await downloadApiFile(CAISSE_ROOT+"/registres/"+kind+"."+format+"?"+query,{signal:controller.signal});}catch(error){if(!controller.signal.aborted)setExportError(error.message||"L’export n’a pas abouti.");}finally{if(exportRequest.current===controller){exportRequest.current=null;setExporting(false);}}
 }
 const filters=[{key:"IdDeviseFk",label:"Devise",options:caisseOptions(references.devises,"Toutes les devises")},...(kind!=="caisses"?[{key:"IdCaisseFk",label:"Caisse",options:cashboxOptions(references,"Toutes les caisses")}]:[]),...(kind==="caisses"?[{key:"Actif",label:"État",options:[{value:"",label:"Toutes les caisses"},{value:"true",label:"Actives"},{value:"false",label:"Inactives"}]}]:[]),...(kind==="ecritures"?[{key:"SensMouvement",label:"Mouvement",options:ENTRY_SENSES},{key:"EtatEcriture",label:"État",options:ENTRY_STATES},{key:"ValidePaiement",label:"Conservation",options:[{value:"",label:"Toutes les écritures"},{value:"true",label:"Écritures actives"},{value:"false",label:"Brouillons abandonnés"}]},{key:"IdTiersFk",label:"Tiers",options:caisseOptions(references.tiers,"Tous les tiers")}]:[])].filter(field=>!hidden.includes(field.key));
 const activeFilters=Object.values(criteria.filters).filter(value=>value!==""&&value!=null).length+(criteria.q?1:0);
 const toolbar=<><DataTableToolbar showSettings={false} search={draft.q} setSearch={q=>setDraft(previous=>({...previous,q}))} onApply={apply} onReset={reset} pending={pending} take={grid.take} onTake={take=>changeGrid({take,skip:0})} filtersOpen={filtersOpen} toggleFilters={()=>setFiltersOpen(value=>!value)} filterControlsId={prefix+"-filters"} activeFilters={activeFilters} density={density} toggleDensity={()=>setDensity(value=>value==="compact"?"airy":"compact")} loading={current.loading} exportFile={canExport?()=>exportFile("xlsx"):undefined} exportCsv={canExport?()=>exportFile("csv"):undefined} exporting={exporting} exportDisabled={Boolean(current.error)||!current.meta?.filteredCount||!preferences.ready||!preferences.canExport||!exportKeys.length} error={exportError||preferences.error} placeholder={kind==="caisses"?"Rechercher une caisse ou un responsable…":kind==="clotures"?"Rechercher une caisse ou un motif…":"Rechercher un code, un libellé ou une référence…"}/>
  {filtersOpen?<form id={prefix+"-filters"} className="erp-register-filters" onSubmit={event=>{event.preventDefault();apply();}}><div className="erp-register-filter-grid">{filters.map(field=><label key={field.key}><span>{field.label}</span><SearchSelect label={field.label} value={String(draft.filters[field.key]??"")} options={field.options} onChange={value=>setDraft(previous=>({...previous,filters:{...previous.filters,[field.key]:value}}))}/></label>)}{kind!=="caisses"?[{key:"dateMin",label:"Du"},{key:"dateMax",label:"Au"}].map(field=><label key={field.key}><span>{field.label}</span><input type="date" value={draft.filters[field.key]||""} onChange={event=>setDraft(previous=>({...previous,filters:{...previous.filters,[field.key]:event.target.value}}))}/></label>):null}</div><div className="erp-register-filters-footer"><ActionButton variant="primary" type="submit" disabled={current.loading}>Appliquer les filtres</ActionButton></div></form>:null}
  {canValidate&&selection.length>0&&!current.loading?<div className="erp-register-selection"><strong>{selection.length===1?"1 écriture sélectionnée":selection.length+" écritures sélectionnées"}</strong><ActionButton icon="check-circle" variant="primary" onClick={()=>validate(selection)}>Valider la sélection</ActionButton></div>:null}
  {activeFilters?<p className="caisse-filter-note">{activeFilters} critère{activeFilters>1?"s":""} appliqué{activeFilters>1?"s":""} · <button type="button" className="caisse-value-link" onClick={reset}>Tout afficher</button></p>:null}
 </>;
 const body=<div className="erp-register-table erp-results" data-density={density} aria-busy={current.loading}>
  {current.error?<div className="admin-error" role="alert"><span>{current.error}</span><ActionButton icon="refresh" onClick={()=>setRetry(value=>value+1)}>Réessayer</ActionButton></div>:null}
  <SimpleTable rows={current.rows} columns={columns} tablePreferences={preferences} getRowId={row=>row[definition.id]} defaultVisibleColumns={definition.visible} defaultPinnedColumns={[]} serverMeta={current.meta} serverState={grid} onServerChange={changeGrid} enableSelection={canValidate} onSelectionChange={setSelection} selectionResetKey={key} loading={current.loading} toolbar={toolbar} onRowConsult={row=>onOpen({kind,id:row[definition.id]})} consultColumns={[definition.visible[0]]} columnsPanelOpen={settings} columnsAnchorRef={anchor} onColumnsPanelClose={()=>setSettings(false)} emptyMessage={current.error?"La liste est indisponible.":"Aucun résultat pour ces critères."}/>
 </div>;
 const validationSettings=!compact&&kind==="ecritures"&&scopedWrite&&context?.canConfigureValidation===true
  ?[{label:"Paramètres de validation",icon:"check-circle",onSelect:()=>onOpen({kind,mode:"parametres-validation"})}]:[];
 const actions=<><RegisterSettingsButton buttonRef={anchor} expanded={settings} onTableSettings={()=>setSettings(true)} onReferences={()=>setReferencesOpen(true)} extraItems={validationSettings}/>{onCreate?<ActionButton icon="plus" variant="primary" disabled={!canCreate} onClick={()=>onCreate(kind)}>{definition.create}</ActionButton>:null}</>;
 return <>{compact?<section className="caisse-drill-register"><header><h3>{title||definition.title}</h3><div>{actions}</div></header>{body}</section>:<RegisterSurface title={title||definition.title} subtitle={definition.subtitle} actions={actions}>{body}</RegisterSurface>}{referencesOpen?<CaisseReferences references={references} onClose={()=>setReferencesOpen(false)}/>:null}</>;
}
