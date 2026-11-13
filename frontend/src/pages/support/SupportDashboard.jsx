import {useCallback,useEffect,useId,useRef,useState} from "react";
import ActionButton from "../../components/ActionButton";
import AppIcon from "../../components/AppIcon";
import SupportDetail from "./SupportDetail";
import {ProcessMonitor} from "./SupportProcesses";
import SupportRegister from "./SupportRegister";
import {SUPPORT_ROOT,supportCount} from "./supportForm";
import {PROCESS_METRICS,useProcessQuery} from "./supportProcess";

const DUE_DATE_SORT={sortBy:"DateEcheance",sortDir:"asc"};

const ATTENTION_METRICS=[
  {key:"enRetard",label:"Tickets en retard",icon:"alert",indicator:"retard",tone:"danger",initialSort:DUE_DATE_SORT},
  {key:"aEcheanceProchaine",label:"À échéance dans les 7 prochains jours",icon:"calendar",indicator:"echeance-prochaine",tone:"warning",initialSort:DUE_DATE_SORT},
  {key:"sansResponsable",label:"Sans responsable",icon:"user",indicator:"sans-responsable",tone:"warning"},
  {key:"enAttente",label:"En attente",icon:"clock",indicator:"attente"},
];

const ACTIVITY_METRICS=[
  {key:"total",label:"Tous les dossiers",icon:"help"},
  {key:"ouverts",label:"Dossiers ouverts",icon:"folder",indicator:"ouverts"},
  {key:"resolus",label:"Résolus",icon:"check-circle",indicator:"resolus"},
  {key:"clotures",label:"Clôturés",icon:"shield",indicator:"clotures"},
];

const STEP_METRICS=PROCESS_METRICS.map(metric=>{
  if(metric.key==="late")return {...metric,label:"Parcours hors délai",tone:"danger"};
  if(metric.key==="blocked")return {...metric,tone:"danger"};
  if(metric.key==="awaitingReceipt")return {...metric,tone:"warning"};
  return metric;
});

const CHARTS=[
  {key:"parStatut",label:"Dossiers par statut",field:"ID_StatutFk"},
  {key:"parPriorite",label:"Dossiers par priorité",field:"ID_PrioriteFk"},
];

function MetricsPanel({title,icon,metrics,values,loading,selected,detailId,onSelect,priority=false}){
  return <section className={"admin-dashboard-panel"+(priority?" support-dashboard-priority":"")}>
    <header><h2><AppIcon name={icon}/>{title}</h2></header>
    <div className="admin-metrics support-dashboard-metrics" aria-busy={loading}>
      {metrics.map(metric=>{
        const value=values?.[metric.key];
        const expanded=selected?.key===metric.key;
        return <button key={metric.key} type="button" className="admin-metric"
          data-tone={Number(value)>0?metric.tone:undefined}
          aria-expanded={expanded} aria-controls={expanded?detailId:undefined}
          disabled={value==null} onClick={event=>onSelect(event,metric)}>
          <span className="admin-metric-icon"><AppIcon name={metric.icon}/></span>
          <span><small>{metric.label}</small><strong>{value==null?"—":supportCount(value)}</strong></span>
          <AppIcon name="chevron-right" size={14}/>
        </button>;
      })}
    </div>
  </section>;
}

const PERCENT_FORMAT=new Intl.NumberFormat("fr",{style:"percent",maximumFractionDigits:1});

function Distribution({chart,rows,selected,detailId,onSelect}){
  const total=rows.reduce((sum,row)=>sum+Number(row.count),0);
  return <section className="admin-dashboard-panel">
    <header><h2><AppIcon name="chart"/>{chart.label}</h2></header>
    <div className="support-chart">
      {rows.length?rows.map(row=>{
        const label=row.label||"Non renseigné";
        const filterValue=row.id==null?"__null__":String(row.id);
        const key=chart.key+"-"+filterValue;
        const expanded=selected?.key===key;
        const share=total?Number(row.count)/total:0;
        const percent=PERCENT_FORMAT.format(share);
        return <button type="button" key={key} aria-expanded={expanded} aria-controls={expanded?detailId:undefined}
          aria-label={chart.label+" · "+label+" · "+supportCount(row.count)+" · "+percent}
          onClick={event=>onSelect(event,{key,label:chart.label+" · "+label,criteria:{filters:{[chart.field]:filterValue}}})}>
          <span>{label}</span>
          <span className="support-chart-track" aria-hidden="true"><span style={{width:100*share+"%"}}/></span>
          <span className="support-chart-value"><strong>{supportCount(row.count)}</strong><small>{percent}</small></span>
        </button>;
      }):<p className="support-empty">Aucun dossier à répartir.</p>}
    </div>
  </section>;
}

export default function SupportDashboard({title="Tableau de bord",hiddenDashboardBlocks=[],refresh,onNavigate,canReadProcesses,onChanged}){
  const id=useId();
  const [selected,setSelected]=useState(null);
  const [ticketId,setTicketId]=useState(null);
  const panel=useRef(null),returnButton=useRef(null),trigger=useRef(null);
  const scrollFrame=useRef(null),hasScrolled=useRef(false);
  const summary=useProcessQuery(SUPPORT_ROOT+"/tableau-de-bord",refresh);
  const ticketContext=useProcessQuery(selected&&!selected.process?SUPPORT_ROOT+"/contexte":null,refresh);
  const data=summary.data||summary.previousData;
  const processValues=canReadProcesses?data?.processes:null;
  const showAttention=!hiddenDashboardBlocks.includes("attention");
  const showActivity=!hiddenDashboardBlocks.includes("activite");
  const showSteps=!hiddenDashboardBlocks.includes("etapes")&&(processValues||(canReadProcesses&&summary.loading));
  const showCharts=!hiddenDashboardBlocks.includes("graphiques");

  function closeDetail(){
    if(scrollFrame.current!=null)cancelAnimationFrame(scrollFrame.current);
    setSelected(null);
    setTicketId(null);
    const origin=trigger.current;
    if(origin?.isConnected){
      origin.scrollIntoView({block:"center",behavior:"auto"});
      origin.focus({preventScroll:true});
    }
  }

  function openDetail(event,metric,process=false){
    if(selected?.key===metric.key){
      closeDetail();
      return;
    }
    if(scrollFrame.current!=null)cancelAnimationFrame(scrollFrame.current);
    trigger.current=event.currentTarget;
    hasScrolled.current=false;
    setSelected({...metric,process,criteria:metric.criteria||(metric.indicator?{indicator:metric.indicator}:{})});
  }

  const detailReady=useCallback(()=>{
    if(hasScrolled.current)return;
    hasScrolled.current=true;
    scrollFrame.current=requestAnimationFrame(()=>{
      scrollFrame.current=null;
      panel.current?.scrollIntoView({block:"start",behavior:"auto"});
      returnButton.current?.focus({preventScroll:true});
    });
  },[]);
  useEffect(()=>()=>{if(scrollFrame.current!=null)cancelAnimationFrame(scrollFrame.current);},[]);

  const detailId=id+"-detail";
  return <div className="support-dashboard">
    <header className="erp-register-heading">
      <div><h1>{title}</h1><p>Demandes, incidents et suivi des dossiers.</p></div>
      <div className="erp-register-actions">
        <ActionButton icon="list" onClick={()=>onNavigate("tickets")}>Ouvrir les tickets</ActionButton>
      </div>
    </header>
    {summary.error?<div className="admin-error" role="alert">
      <span>{summary.error}</span><ActionButton icon="refresh" onClick={summary.reload}>Réessayer</ActionButton>
    </div>:null}
    {showAttention||showActivity||showSteps?<div className="support-dashboard-sections" aria-busy={summary.loading}>
      {showAttention?<MetricsPanel title="À traiter" icon="alert" metrics={ATTENTION_METRICS} values={data?.metrics} loading={summary.loading}
        selected={selected} detailId={detailId} onSelect={openDetail} priority/>:null}
      {showActivity?<MetricsPanel title="Activité des tickets" icon="help" metrics={ACTIVITY_METRICS} values={data?.metrics} loading={summary.loading}
        selected={selected} detailId={detailId} onSelect={openDetail}/>:null}
      {showSteps?<MetricsPanel title="Suivi des étapes" icon="movements" metrics={STEP_METRICS}
        values={processValues} loading={summary.loading} selected={selected} detailId={detailId}
        onSelect={(event,metric)=>openDetail(event,metric,true)}/>:null}
    </div>:null}
    {summary.loading&&!data?<p className="support-empty" role="status">Chargement de la synthèse…</p>:null}
    {data&&showCharts?<div className="support-charts">
      {CHARTS.map(chart=><Distribution key={chart.key} chart={chart} rows={data.charts?.[chart.key]||[]}
        selected={selected} detailId={detailId} onSelect={openDetail}/>)}
    </div>:null}

    {!summary.loading&&!summary.error&&!showAttention&&!showActivity&&!showSteps&&!showCharts?
      <p className="support-empty" role="status">Aucun bloc du tableau de bord n’est affiché.</p>:null}
    {selected&&(!selected.process||canReadProcesses)?<div ref={panel} className="support-dashboard-detail">
      <ActionButton ref={returnButton} className="erp-detail-return" icon="arrow-up" onClick={closeDetail}>Revenir à l’indicateur</ActionButton>
      <section id={detailId} className="erp-register-card support-dashboard-detail-card" aria-labelledby={id+"-detail-title"}>
        <div className="erp-detail-header">
          <h2 id={id+"-detail-title"}>{selected.label}</h2>
          <button type="button" className="erp-detail-close" aria-label="Fermer la liste" onClick={closeDetail}><AppIcon name="close"/></button>
        </div>
        {selected.process?<div className="erp-register-table">
          <ProcessMonitor key={selected.key} refresh={refresh} indicator={selected.key} onOpenTicket={setTicketId} onReady={detailReady}/>
        </div>:<SupportRegister key={selected.key} embedded initial={selected.criteria} refresh={refresh}
          initialSort={selected.initialSort}
          context={ticketContext.data} contextLoading={ticketContext.loading} contextError={ticketContext.error}
          onReady={detailReady} onChanged={onChanged} canReadJourney={canReadProcesses}/>}
      </section>
    </div>:null}
    {ticketId&&canReadProcesses?<SupportDetail key={ticketId} id={ticketId} initialTab="parcours" canReadJourney
      onClose={()=>setTicketId(null)} onChanged={onChanged}/>:null}
  </div>;
}
