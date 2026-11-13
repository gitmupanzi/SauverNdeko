import {useEffect,useId,useRef,useState} from "react";
import {useEntityScope} from "../../contexts/EntityScopeContext";
import ActionButton from "../../components/ActionButton";
import AppIcon from "../../components/AppIcon";
import DataTableToolbar from "../../components/DataTableToolbar";
import ListState from "../../components/ListState";
import RegisterSettingsButton from "../../components/RegisterSettingsButton";
import RegisterSurface from "../../components/RegisterSurface";
import SearchSelect from "../../components/SearchSelect";
import {SimpleTable,formatDate} from "../logistique/logistiqueShared";
import {PROCESS_URL,processOptions,processQuery,useProcessQuery} from "./supportProcess";
import SupportDetail from "./SupportDetail";
import {SupportBadge,SupportStatus} from "./SupportBadge";

const TIMELINE=[
  {key:"enteredAt",label:"Entrée dans l’étape"},
  {key:"dueAt",label:"Échéance de l’étape"},
  {key:"globalDueAt",label:"Échéance du dossier"},
];
const DEFAULT_COLUMNS=["number","subject","stageName","modelName","responsible","late","dueAt","status","actions"];
const EMPTY_CRITERIA={q:"",typeId:"",stage:"",serviceId:"",responsibleId:"",status:"",entityId:"",late:"",blocked:"",dateFrom:"",dateTo:""};
const MONITOR_FILTERS=[
  {key:"typeId",source:"types",label:"Type"},
  {key:"serviceId",source:"services",label:"Service"},
  {key:"responsibleId",source:"users",label:"Responsable"},
  {key:"status",source:"statuses",label:"État du dossier"},
];
const flags=[
  {value:"",label:"Tous"},
  {value:"true",label:"Oui"},
  {value:"false",label:"Non"},
];

function Retry({error,onClick}){
  return error?<div className="admin-error" role="alert"><span>{error}</span><ActionButton icon="refresh" onClick={onClick}>Réessayer</ActionButton></div>:null;
}

export function SupportStageRegister({title="Suivi des étapes",context,refresh,onShowTickets,onShowModels,onNewTicket,onChanged}){
  const [ticketId,setTicketId]=useState(null);
  const [columnsOpen,setColumnsOpen]=useState(false);
  const columnsAnchorRef=useRef(null);
  const canStartJourney=context?.canCreate===true&&context?.canStartJourneyOnCreate===true;
  return <RegisterSurface title={title} subtitle="Étapes, échéances et blocages des tickets associés à un modèle de suivi."
    actions={<>
      <RegisterSettingsButton buttonRef={columnsAnchorRef} expanded={columnsOpen} onTableSettings={()=>setColumnsOpen(open=>!open)}/>
      {onShowModels?<ActionButton icon="folder" onClick={onShowModels}>Modèles de suivi</ActionButton>:null}
      {onShowTickets?<ActionButton icon="list" onClick={onShowTickets}>Voir les tickets</ActionButton>:null}
    </>}>
    <div className="erp-register-table">
      <ProcessMonitor refresh={refresh} onOpenTicket={setTicketId} onNewTicket={canStartJourney?onNewTicket:undefined}
        columnsPanelOpen={columnsOpen} columnsAnchorRef={columnsAnchorRef} onColumnsPanelClose={()=>setColumnsOpen(false)}/>
    </div>
    {ticketId!==null?<SupportDetail key={ticketId} id={ticketId} initialTab="parcours" context={context} canReadJourney
      onClose={()=>setTicketId(null)} onChanged={onChanged}/>:null}
  </RegisterSurface>;
}

export function ProcessMonitor({refresh,onOpenTicket,onNewTicket,indicator,onReady,columnsPanelOpen,columnsAnchorRef,onColumnsPanelClose}){
  const scope=useEntityScope();
  const [draft,setDraft]=useState(EMPTY_CRITERIA);
  const [criteria,setCriteria]=useState(EMPTY_CRITERIA);
  const [take,setTake]=useState(25);
  const [page,setPage]=useState(1);
  const [filtersOpen,setFiltersOpen]=useState(false);
  const [density,setDensity]=useState("compact");
  const prefix=useId();
  const state=useProcessQuery(PROCESS_URL+"/suivi?"+processQuery({...criteria,indicator},page,take),refresh);
  const display=state.data||state.previousData;
  const references=display?.references||{};
  useEffect(()=>{if(!state.loading)onReady?.();},[state.loading,onReady]);
  const count=state.data?.count;
  const set=(key,value)=>setDraft(previous=>({...previous,[key]:value}));
  const apply=()=>{setCriteria({...draft,q:draft.q.trim(),stage:draft.stage.trim()});setPage(1);};
  const reset=()=>{setDraft(EMPTY_CRITERIA);setCriteria(EMPTY_CRITERIA);setPage(1);};
  const pending=JSON.stringify(criteria)!==JSON.stringify(draft);
  const active=Object.entries(criteria).filter(([key,value])=>key!=="q"&&value!=="").length;
  const columns=[
    {key:"number",label:"Dossier",sortable:false,render:row=><strong className="support-record-code">{row.number}</strong>},
    {key:"subject",label:"Objet",width:220,sortable:false},
    {key:"stageName",label:"Étape",width:160,sortable:false},
    {key:"modelName",label:"Modèle de suivi",width:165,sortable:false},
    {key:"responsible",label:"Responsable",width:160,sortable:false},
    {key:"late",label:"Suivi",sortable:false,render:row=><div className="support-badges">
      {row.late?<SupportBadge value="En retard" tone="warning"/>:null}
      {row.blockage?<SupportBadge value="Bloqué" tone="danger"/>:null}
      {!row.late&&!row.blockage?"—":null}
    </div>},
    ...TIMELINE.map(({key,label})=>({key,label,width:160,sortable:false,render:row=>row[key]?formatDate(row[key]):"—"})),
    {key:"status",label:"État du dossier",width:145,sortable:false,
      render:row=><SupportStatus value={row.status} id={row.statusId} options={references.statuses}/>},
    {key:"entity",label:"Entreprise",sortable:false},
    {key:"service",label:"Service",sortable:false},
    {key:"actions",label:"Actions",sortable:false,render:row=><div className="erp-row-actions">
      <button type="button" className="erp-row-consult" title="Ouvrir le parcours" aria-label={`Ouvrir le parcours de ${row.number}`}
        onClick={()=>onOpenTicket(row.ticketId)}><AppIcon name="eye"/></button>
    </div>},
  ];

  let emptyState;
  if(state.data?.available===false){
    emptyState=<ListState title="Le suivi des étapes est indisponible" description="La base de données doit être mise à jour pour activer le suivi."
      action={<ActionButton icon="refresh" onClick={state.reload}>Réessayer</ActionButton>}/>;
  }else if(count===0&&!indicator&&!Object.values(criteria).some(Boolean)){
    emptyState=<ListState title="Aucun parcours démarré" icon="movements"
      description={onNewTicket?"Choisissez un modèle de suivi à la création d’un ticket ou dans l’onglet Parcours de sa fiche.":"Les tickets associés à un modèle de suivi s’affichent ici."}
      action={onNewTicket?<ActionButton icon="plus" variant="primary" onClick={onNewTicket}>Nouveau dossier</ActionButton>:null}/>;
  }
  const toolbar=<>
    <DataTableToolbar showSettings={false} search={draft.q} setSearch={value=>set("q",value)} onApply={apply} onReset={reset}
      pending={pending} take={take} onTake={value=>{setTake(value);setPage(1);}} filtersOpen={filtersOpen} toggleFilters={()=>setFiltersOpen(value=>!value)}
      filterControlsId={prefix+"-filters"} activeFilters={active} density={density} toggleDensity={()=>setDensity(value=>value==="compact"?"airy":"compact")}
      loading={state.loading} placeholder="Rechercher un dossier ou un modèle…"/>
    {filtersOpen?<form id={prefix+"-filters"} className="erp-register-filters" onSubmit={event=>{event.preventDefault();apply();}}>
      <div className="erp-register-filter-grid">
        {MONITOR_FILTERS.filter(field=>references[field.source]?.length).map(field=><div className="support-field" key={field.key}>
          <label htmlFor={prefix+field.key}>{field.label}</label><SearchSelect id={prefix+field.key} label={field.label}
          value={draft[field.key]} options={processOptions(references[field.source],draft[field.key],"Tous")} onChange={value=>set(field.key,value)}/></div>)}
        {scope.globalAdmin&&!scope.entityId&&scope.entities?.length?<div className="support-field"><label htmlFor={prefix+"entity"}>Entreprise</label>
          <SearchSelect id={prefix+"entity"} label="Entreprise" value={draft.entityId} options={processOptions(scope.entities,draft.entityId,"Toutes les entreprises")} onChange={value=>set("entityId",value)}/></div>:null}
        <label><span>Étape</span><input value={draft.stage} onChange={event=>set("stage",event.target.value)}/></label>
        <label><span>Retard</span><SearchSelect label="Retard" value={draft.late} options={flags} onChange={value=>set("late",value)}/></label>
        <label><span>Blocage</span><SearchSelect label="Blocage" value={draft.blocked} options={flags} onChange={value=>set("blocked",value)}/></label>
        <label><span>Parcours démarré du</span><input type="date" value={draft.dateFrom} onChange={event=>set("dateFrom",event.target.value)}/></label>
        <label><span>Parcours démarré au</span><input type="date" value={draft.dateTo} onChange={event=>set("dateTo",event.target.value)}/></label>
      </div>
      <div className="erp-register-filters-footer"><ActionButton type="submit" variant="primary">Appliquer les filtres</ActionButton></div>
    </form>:null}
    <Retry error={state.error} onClick={state.reload}/>
  </>;
  return <div className="erp-results support-stage-grid" data-density={density}>
    <SimpleTable rows={display?.items||[]} columns={columns} getRowId={row=>row.ticketId} defaultVisibleColumns={DEFAULT_COLUMNS}
      defaultPinnedColumns={[]} toolbar={toolbar} loading={state.loading} onRowConsult={row=>onOpenTicket(row.ticketId)}
      columnsPanelOpen={columnsPanelOpen} columnsAnchorRef={columnsAnchorRef} onColumnsPanelClose={onColumnsPanelClose}
      tableLabel="Suivi des étapes des tickets" consultColumns={["number","subject","stageName"]} serverMeta={count==null?null:{filteredCount:count,take}}
      serverState={{take,skip:(page-1)*take}} onServerChange={patch=>setPage(Math.floor((patch.skip??0)/take)+1)}
      emptyState={emptyState} emptyMessage={state.error?"Les données ne sont pas disponibles.":"Aucun parcours pour ces critères."}/>
  </div>;
}
