import {useEffect,useId,useRef,useState} from "react";
import {Link} from "react-router-dom";
import {useEntityScope} from "../../contexts/EntityScopeContext";
import {requestJson} from "../../services/api";
import AppIcon from "../../components/AppIcon";
import ActionButton from "../../components/ActionButton";
import SearchSelect from "../../components/SearchSelect";
import {formatDate} from "../logistique/logistiqueShared";
import {formatCurrency,compareDecimal} from "../../utils/money";
import {CAISSE_ROOT,caisseQuery,caisseOptions,caisseBarPercent} from "./caisseModel";
import CaisseRegister from "./CaisseRegister";

export default function CaisseDashboard({
 context,references={},refresh,onOpen,title="Tableau de bord",hiddenDashboardBlocks=[],canConfigurePresentation=false,readCash,readEntries,
}){
 const showSummary=(readCash||readEntries)&&!hiddenDashboardBlocks.includes("synthese");
 const showFlow=readEntries&&!hiddenDashboardBlocks.includes("flux");
 const hasVisibleBlocks=showSummary||showFlow;
 const scope=useEntityScope(),prefix=useId(),detail=useRef(null),origin=useRef(null),[criteria,setCriteria]=useState({q:"",filters:{}}),[draft,setDraft]=useState({q:"",filters:{}}),[selection,setSelection]=useState(null),[retry,setRetry]=useState(0),[state,setState]=useState({key:"",owner:"",data:null,loading:true,error:""});
 const owner=scope.scopeKey,key=owner+":"+refresh+":"+retry+":"+JSON.stringify(criteria),current=state.key===key?state:{data:state.owner===owner?state.data:null,loading:true,error:""};
 useEffect(()=>{if(!hasVisibleBlocks)return;const controller=new AbortController();setState(previous=>({...previous,owner,key,data:previous.owner===owner?previous.data:null,loading:true,error:""}));requestJson(CAISSE_ROOT+"/synthese?"+caisseQuery(criteria),{requiresAuth:true,signal:controller.signal}).then(response=>{if(controller.signal.aborted)return;setState({owner,key,data:response?.success?response.data:null,loading:false,error:response?.success?"":response?.message||"La synthèse n’a pas pu être chargée."});});return()=>controller.abort();},[key,hasVisibleBlocks]);
 useEffect(()=>{if(selection)requestAnimationFrame(()=>{detail.current?.scrollIntoView({block:"start",behavior:window.matchMedia?.("(prefers-reduced-motion: reduce)").matches?"auto":"smooth"});detail.current?.focus({preventScroll:true});});},[selection]);
 function open(kind,title,filters,event){origin.current=event.currentTarget;setSelection({kind,title,q:kind==="caisses"?"":criteria.q,filters:kind==="caisses"?filters:{...criteria.filters,ValidePaiement:"true",...filters},token:crypto.randomUUID()});}
 function close(){setSelection(null);requestAnimationFrame(()=>origin.current?.isConnected&&origin.current.focus({preventScroll:true}));}
 function apply(){setCriteria(draft);setSelection(null);}
 function reset(){const empty={q:"",filters:{}};setDraft(empty);setCriteria(empty);setSelection(null);}
 const totals=Array.isArray(current.data?.totals)?current.data.totals:[];
 const flux=showFlow&&Array.isArray(current.data?.flux)?current.data.flux:[];
 const currencyBlocks=totals.map(row=>({
  row,daily:flux.filter(item=>String(item.IdDeviseFk)===String(row.IdDeviseFk)).slice(-8),
 })).filter(({daily})=>showSummary||daily.length);
 function indicator(row,label,value,kind,filters,icon){return <button type="button" className="caisse-kpi" disabled={current.loading} onClick={event=>open(kind,label,filters,event)}><span><AppIcon name={icon}/>{label}</span><strong>{value??"—"}<AppIcon name="chevron-right" size={14}/></strong></button>;}
 return <div className="caisse-dashboard">
  <div className="admin-page-heading">
   <div><h1>{title}</h1><p>Soldes et mouvements par devise.</p></div>
   {canConfigurePresentation?<Link className="ui-action is-secondary" to="/parametres?onglet=presentation&module=caisse"><AppIcon name="settings"/>Paramètres d’affichage</Link>:null}
  </div>
  {!hasVisibleBlocks?<div className="caisse-empty"><AppIcon name="dashboard" size={32}/><h2>Aucun bloc affiché</h2><p>{readCash||readEntries?"Les blocs se règlent dans les paramètres de présentation de l’entreprise.":"Les indicateurs s’affichent selon votre accès aux caisses et aux écritures."}</p></div>:<>

  <form className="caisse-dashboard-filters" role="search" onSubmit={event=>{event.preventDefault();apply();}}>{readEntries?<label className="caisse-dashboard-query" htmlFor={prefix+"-search"}><span>Recherche</span><input id={prefix+"-search"} type="search" placeholder="Caisse, libellé ou référence…" value={draft.q} onChange={event=>setDraft(previous=>({...previous,q:event.target.value}))}/></label>:null}<label><span>Devise</span><SearchSelect label="Devise" value={draft.filters.IdDeviseFk||""} options={caisseOptions(references.devises,"Toutes les devises")} onChange={value=>setDraft(previous=>({...previous,filters:{...previous.filters,IdDeviseFk:value}}))}/></label>{readEntries?<><label><span>Du</span><input type="date" value={draft.filters.dateMin||""} onChange={event=>setDraft(previous=>({...previous,filters:{...previous.filters,dateMin:event.target.value}}))}/></label><label><span>Au</span><input type="date" value={draft.filters.dateMax||""} onChange={event=>setDraft(previous=>({...previous,filters:{...previous.filters,dateMax:event.target.value}}))}/></label></>:null}<ActionButton variant="primary" type="submit" disabled={current.loading}>Rechercher</ActionButton><ActionButton icon="reset" disabled={current.loading} onClick={reset}>Réinitialiser</ActionButton></form>
  {readEntries?<p className="record-editor-note caisse-period-note">La période filtre les écritures et les flux.</p>:null}
  {current.error?<div className="admin-error" role="alert"><span>{current.error}</span><ActionButton icon="refresh" onClick={()=>setRetry(value=>value+1)}>Réessayer</ActionButton></div>:null}
  {current.loading&&!current.data?<p className="record-editor-state" role="status">Chargement de la synthèse…</p>:null}
  {!current.loading&&!current.error&&!currencyBlocks.length?<div className="caisse-empty">
   <AppIcon name="wallet" size={32}/>
   <h2>{showSummary?"Aucune caisse disponible":"Aucun flux pour ces critères"}</h2>
   <p>{showSummary?"Les caisses et leurs mouvements apparaîtront ici.":"Essayez de modifier la période ou les filtres."}</p>
  </div>:null}
  <div className="caisse-currency-blocks" aria-busy={current.loading}>{currencyBlocks.map(({row,daily})=>{const currency={IdDeviseFk:String(row.IdDeviseFk)},max=daily.reduce((largest,item)=>[item.Entrees,item.Sorties].reduce((value,amount)=>compareDecimal(amount,value)===1?amount:value,largest),"0");return <section className="caisse-currency-block" key={row.IdDeviseFk}><header><span className="caisse-detail-icon"><AppIcon name="wallet"/></span><div><h2>{row.DeviseCode||row.DeviseLibelle}</h2><p>{row.DeviseLibelle}</p></div></header>{showSummary?<div className="caisse-kpi-grid">
   {readCash?<>{indicator(row,"Solde disponible",formatCurrency(row.Solde,row.DeviseCode),"caisses",currency,"wallet")}
   {indicator(row,"Caisses",row.NombreCaisses,"caisses",currency,"list")}</>:null}
   {readEntries?<>{indicator(row,"Encaissements",formatCurrency(row.Entrees,row.DeviseCode),"ecritures",{...currency,SensMouvement:"1",EtatEcriture:"POSTED"},"stock-in")}
   {indicator(row,"Décaissements",formatCurrency(row.Sorties,row.DeviseCode),"ecritures",{...currency,SensMouvement:"-1",EtatEcriture:"POSTED"},"stock-out")}
   {indicator(row,"Écritures validées",row.NombreEcritures,"ecritures",{...currency,EtatEcriture:"POSTED"},"document")}
   {indicator(row,"Brouillons",row.NombreBrouillons,"ecritures",{...currency,EtatEcriture:"DRAFT"},"edit")}</>:null}
  </div>:null}{daily.length?<div className="caisse-flow-chart"><h3>Flux quotidiens</h3><div className="caisse-flow-legend"><span>Encaissements</span><span>Décaissements</span></div>{daily.map(day=><div className="caisse-flow-row" key={day.DateJour}><time>{formatDate(day.DateJour,{withTime:false})}</time><div className="caisse-flow-bars"><span className="is-in" style={{width:caisseBarPercent(day.Entrees,max)+"%"}}/><span className="is-out" style={{width:caisseBarPercent(day.Sorties,max)+"%"}}/></div><span>{formatCurrency(day.Entrees,row.DeviseCode)}<small>{formatCurrency(day.Sorties,row.DeviseCode)}</small></span></div>)}</div>:null}</section>;})}</div>
  {showSummary&&selection&&(selection.kind==="caisses"?readCash:readEntries)?<section ref={detail} tabIndex={-1} className="caisse-drill" aria-label={selection.title}><div className="caisse-drill-back"><ActionButton icon="arrow-up" onClick={close}>Revenir à l’indicateur</ActionButton><ActionButton icon="close" aria-label="Fermer la liste" onClick={close}/></div><CaisseRegister key={owner+":"+selection.token} compact kind={selection.kind} title={selection.title} context={context} references={references} refresh={refresh} initial={{q:selection.q,filters:selection.filters}} onOpen={onOpen}/></section>:null}
  </>}
 </div>;
}
