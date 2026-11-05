import RegisterCategoryFilter from "../../components/RegisterCategoryFilter";
import {useEffect,useId,useMemo,useRef,useState} from "react";
import {useEntityScope} from "../../contexts/EntityScopeContext";
import RegisterSurface from "../../components/RegisterSurface";
import DataTableToolbar from "../../components/DataTableToolbar";
import RowActionsMenu from "../../components/RowActionsMenu";
import RecordEditorFrame from "../../components/RecordEditorFrame";
import SearchSelect from "../../components/SearchSelect";
import ActionButton from "../../components/ActionButton";
import AppIcon from "../../components/AppIcon";
import {tiersRequest,tiersRecord,tiersRows,tiersChanged,TIERS_CHANGED,natureLabel} from "../../services/tiers";
import {SimpleTable,formatDate} from "./logistiqueShared";
import TiersEditor from "./TiersEditor";
import LogisticsBatchComposer from "./LogisticsBatchComposer";
import Tiers360 from "./Tiers360";
import "./Tiers.css";
const EMPTY={typeClientId:"",type:"",archived:"false"};
function ArchiveTiers({tiersId,onClose,onSaved}){
  const [record,setRecord]=useState(null),[meta,setMeta]=useState(null),[busy,setBusy]=useState(false),[error,setError]=useState("");const saving=useRef(false),mounted=useRef(true);
  useEffect(()=>{mounted.current=true;tiersRequest("/"+tiersId).then(response=>{if(!mounted.current)return;if(!response?.success){setError(response?.message||"La fiche n’est pas disponible.");return;}setRecord(tiersRecord(response));setMeta(response.meta||{});});return()=>{mounted.current=false;};},[tiersId]);
  async function submit(){if(saving.current||!meta?.revision||meta.canDelete===false)return;saving.current=true;setBusy(true);const response=await tiersRequest("/"+tiersId,{method:"DELETE",body:{_version:meta.revision}});if(!mounted.current)return;saving.current=false;setBusy(false);if(!response?.success){setError(response?.message||"L’archivage a échoué.");return;}tiersChanged();onSaved();}
  return <RecordEditorFrame title="Archiver le tiers" subtitle={record?.Nom||"Client ou fournisseur"} icon="user" onClose={onClose} onSubmit={submit} busy={busy} loading={!record&&!error} canSubmit={Boolean(record)&&Boolean(meta?.revision)&&meta.canDelete!==false} error={error} submitLabel="Archiver"><p className="record-editor-note">Le tiers sera retiré des nouveaux choix. Ses bons, factures et règlements restent conservés.</p></RecordEditorFrame>;
}
export default function Tiers({title = "Clients et fournisseurs", refreshKey,onDataChanged}){
  const scope=useEntityScope(),prefix=useId(),columnsRef=useRef(null);
  const [types,setTypes]=useState([]),[rows,setRows]=useState([]),[meta,setMeta]=useState(null),[loading,setLoading]=useState(true),[error,setError]=useState(""),[revision,setRevision]=useState(0),[feedback,setFeedback]=useState("");
  const [search,setSearch]=useState(""),[draft,setDraft]=useState(EMPTY),[criteria,setCriteria]=useState({...EMPTY,q:""}),[grid,setGrid]=useState({take:25,skip:0,sortBy:"Nom",sortDir:"asc"});
  const [filtersOpen,setFiltersOpen]=useState(false),[columnsOpen,setColumnsOpen]=useState(false),[density,setDensity]=useState("compact"),[editor,setEditor]=useState(null),[consult,setConsult]=useState(null),[archiving,setArchiving]=useState(null);
  const pending=search.trim()!==criteria.q||Object.keys(EMPTY).some(key=>draft[key]!==criteria[key]),activeFilters=Number(Boolean(criteria.q))+Object.keys(EMPTY).filter(key=>criteria[key]!==EMPTY[key]).length;
  useEffect(()=>{let live=true;tiersRequest("/references").then(response=>{if(live&&response?.success)setTypes(response.data?.typesClients||[]);});return()=>{live=false;};},[scope.scopeKey,revision]);
  function apply(){setCriteria({...draft,q:search.trim()});setGrid(current=>({...current,skip:0}));}
  function reset(){setSearch("");setDraft(EMPTY);setCriteria({...EMPTY,q:""});setGrid(current=>({...current,skip:0}));}
  function updated(){setEditor(null);setArchiving(null);setRevision(x=>x+1);setFeedback("Fiche enregistrée.");onDataChanged?.();}
  useEffect(()=>{const update=()=>setRevision(x=>x+1);window.addEventListener(TIERS_CHANGED,update);return()=>window.removeEventListener(TIERS_CHANGED,update);},[]);
  useEffect(()=>{let alive=true;setLoading(true);setError("");const params=new URLSearchParams({...criteria,...grid});tiersRequest("?"+params).then(response=>{if(!alive)return;setLoading(false);if(!response?.success){setRows([]);setMeta(null);setError(response?.message||"Les tiers ne sont pas disponibles.");return;}setRows(tiersRows(response));setMeta({...response.meta,filteredCount:response.meta?.filteredCount??response.meta?.totalCount??0});});return()=>{alive=false;};},[criteria,grid,revision,refreshKey,scope.scopeKey]);
  const columns=useMemo(()=>[
    {key:"Nom",label:"Nom du tiers",width:270,render:row=><span className="tiers-register-identity"><span><AppIcon name={row.Nature==="entreprise"?"apps":"user"}/></span><span><strong>{row.Nom}</strong><small>{natureLabel(row.Nature)}</small></span></span>},
    {key:"Nature",label:"Nature",width:145,render:row=>natureLabel(row.Nature)},{key:"TypeClient",label:"Type de tiers",width:190,render:row=><span className="erp-status is-neutral">{row.TypeClient||"—"}</span>},
    {key:"Telephone",label:"Téléphone",width:180,sortable:false},{key:"Email",label:"Adresse e-mail",width:240,sortable:false},
    {key:"NomEntite",label:"Entreprise",width:220,sortable:false},{key:"Actif",label:"État",width:125,render:row=><span className={"erp-status is-"+(row.Actif===false?"neutral":"success")}>{row.Actif===false?"Archivé":"Actif"}</span>},
    {key:"DateCreation",label:"Créé le",width:180,render:row=>formatDate(row.DateCreation)},
    {key:"actions",label:"Actions",width:110,sortable:false,render:row=><div className="erp-row-actions"><ActionButton icon="eye" className="is-icon" aria-label={"Consulter "+row.Nom} onClick={()=>setConsult(row.ID_Client)}/><RowActionsMenu label={row.Nom} items={[{label:"Consulter",icon:"eye",onSelect:()=>setConsult(row.ID_Client)},{label:"Modifier",icon:"edit",disabled:!scope.canWrite,onSelect:()=>setEditor({id:row.ID_Client})},...(row.Actif!==false?[{label:"Archiver",icon:"folder",disabled:!scope.canWrite,onSelect:()=>setArchiving(row.ID_Client)}]:[])]}/></div>},
  ],[scope.canWrite]);
  return <div className="logistics-screen"><RegisterSurface title={title} subtitle="Vos tiers et leurs opérations" actions={<ActionButton icon="plus" variant="primary" onClick={()=>setEditor({id:null})} disabled={!scope.canCreate} title={!scope.entityId?"Choisissez une entreprise active.":undefined}>Nouveau tiers</ActionButton>} tabs={<RegisterCategoryFilter label="Type de tiers" value={criteria.typeClientId} options={[{value:"",label:"Tous les tiers"},...types.map(item=>({value:String(item.id),label:item.label}))]} onChange={value=>{setDraft(current=>({...current,typeClientId:value}));setCriteria(current=>({...current,typeClientId:value}));setGrid(current=>({...current,skip:0}));}}/>}>
    <div className="erp-register-table erp-results" data-density={density} aria-busy={loading}>{feedback?<p role="status" className="tiers-readonly-note">{feedback}</p>:null}{error?<div className="erp-table-error" role="alert">{error}<ActionButton icon="refresh" onClick={()=>setRevision(x=>x+1)}>Réessayer</ActionButton></div>:null}
      <SimpleTable rows={rows} columns={columns} getRowId={row=>row.ID_Client} defaultVisibleColumns={["Nom","Nature","TypeClient","Telephone","Email",...(scope.globalAdmin&&!scope.entityId?["NomEntite"]:[]),"Actif","actions"]} defaultPinnedColumns={[]} serverMeta={meta} serverState={grid} onServerChange={patch=>setGrid(current=>({...current,...patch}))} onRowConsult={row=>setConsult(row.ID_Client)} consultColumns={["Nom"]} loading={loading} emptyMessage="Aucun tiers pour ces critères." columnsPanelOpen={columnsOpen} columnsAnchorRef={columnsRef} onColumnsPanelClose={()=>setColumnsOpen(false)} toolbar={<>
        <DataTableToolbar search={search} setSearch={setSearch} onApply={apply} onReset={reset} pending={pending} take={grid.take} onTake={take=>setGrid(current=>({...current,take,skip:0}))} filtersOpen={filtersOpen} filterControlsId={prefix+"-filters"} toggleFilters={()=>setFiltersOpen(x=>!x)} activeFilters={activeFilters} density={density} toggleDensity={()=>setDensity(x=>x==="compact"?"airy":"compact")} columnsOpen={columnsOpen} columnsButtonRef={columnsRef} toggleColumns={()=>setColumnsOpen(x=>!x)} loading={loading} placeholder="Rechercher un nom, un e-mail ou un téléphone…"/>
        {filtersOpen?<form id={prefix+"-filters"} className="erp-register-filters" onSubmit={event=>{event.preventDefault();apply();}}><div className="erp-register-filter-grid">{[["type","Nature",[{value:"",label:"Toutes les natures"},{value:"personne",label:"Personnes"},{value:"entreprise",label:"Entreprises"}]],["archived","État",[{value:"false",label:"Actifs"},{value:"true",label:"Archivés"},{value:"all",label:"Tous les tiers"}]]].map(([key,label,options])=><label key={key}><span>{label}</span><SearchSelect id={prefix+key} label={label} value={draft[key]} options={options} onChange={value=>setDraft(current=>({...current,[key]:value}))}/></label>)}</div><div className="erp-register-filters-footer"><ActionButton variant="primary" type="submit" disabled={loading}>Appliquer les filtres</ActionButton></div></form>:null}
      </>}/>
    </div></RegisterSurface>{editor?(editor.id==null?<LogisticsBatchComposer kind="tiers" onClose={()=>setEditor(null)} onSaved={updated}/>:<TiersEditor tiersId={editor.id} onClose={()=>setEditor(null)} onSaved={updated}/>):null}{consult!=null?<Tiers360 tiersId={consult} onClose={()=>setConsult(null)} onChanged={()=>{setRevision(x=>x+1);onDataChanged?.();}}/>:null}{archiving!=null?<ArchiveTiers tiersId={archiving} onClose={()=>setArchiving(null)} onSaved={updated}/>:null}</div>;
}
