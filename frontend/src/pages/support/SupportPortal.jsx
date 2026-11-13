import {useEffect,useState} from "react";
import {useSearchParams} from "react-router-dom";
import {useAuth} from "../../contexts/AuthContext";
import {accessSignature,tabRights} from "../../services/moduleAccess";
import {useEntityScope} from "../../contexts/EntityScopeContext";
import {requestJson} from "../../services/api";
import {presentedModuleTabs,useModulePresentation} from "../../hooks/useModulePresentation";
import useReferencesRefresh from "../../hooks/useReferencesRefresh";
import ModuleSidebar from "../../components/ModuleSidebar";
import ActionButton from "../../components/ActionButton";
import SupportDashboard from "./SupportDashboard";
import SupportProcessModels from "./SupportProcessModels";
import SupportRegister from "./SupportRegister";
import {SupportStageRegister} from "./SupportProcesses";
import {SUPPORT_ROOT} from "./supportForm";
import "../logistique/LogistiqueModern.css";
import "../admin/AdminPortal.css";
import "./Support.css";

const GROUPS=[
 {key:"pilotage",label:"Pilotage",items:[{key:"tableau-de-bord",label:"Tableau de bord",icon:"dashboard"},{key:"modeles",label:"Modèles de suivi",icon:"folder"}]},
 {key:"traitement",label:"Traitement",items:[{key:"tickets",label:"Tickets",icon:"help"},{key:"processus",label:"Suivi des étapes",icon:"movements"}]},
];

export default function SupportPortal(){
 const {user}=useAuth(),scope=useEntityScope(),[params,setParams]=useSearchParams(),[refresh,setRefresh]=useState(0),[state,setState]=useState(null),[newTicketOwner,setNewTicketOwner]=useState(null);
 const owner=scope.scopeKey+":"+accessSignature(user),contextKey=owner+":"+refresh;
 const current=state?.owner===owner?state:null;
 const loading=current?.key!==contextKey;
 const context=loading?null:current.data,error=loading?"":current.error;
 const [collapsed,setCollapsed]=useState(()=>{try{return localStorage.getItem("sauverndeko.support.sidebar-collapsed")==="true";}catch{return false;}});
 const canReadTickets=tabRights(user,"support","tickets").canRead;
 const canReadDashboard=canReadTickets&&tabRights(user,"support","tableau-de-bord").canRead;
 const canReadProcesses=canReadTickets&&tabRights(user,"support","processus").canRead;
 const rights={"tableau-de-bord":canReadDashboard,tickets:canReadTickets,processus:canReadProcesses,
  modeles:canReadProcesses&&current?.data?.canReadProcessModels===true};
 const {presentation,loading:presentationLoading,error:presentationError,retry:retryPresentation}=useModulePresentation("support",{...scope,scopeKey:owner,entityId:canReadTickets?scope.entityId:null});
 const groups=presentationLoading?[]:GROUPS.map(group=>({
  ...group,items:presentedModuleTabs(group.items.filter(item=>rights[item.key]),presentation),
 })).filter(group=>group.items.length);
 const visibleTabs=presentedModuleTabs(GROUPS.flatMap(group=>group.items),presentation);
 const firstVisible=visibleTabs.find(item=>rights[item.key]||(item.key==="modeles"&&canReadProcesses&&!current))?.key;
 const requested=params.get("onglet");
 const legacyStages=requested==="tickets"&&params.get("vue")==="suivi";
 const active=legacyStages?"processus":Object.hasOwn(rights,requested)?requested:firstVisible;
 const title=presentation?.tabLabels?.[active];
 const access=rights[active];
 const initialCreate=active==="tickets"&&newTicketOwner===owner;
 const canCreateTicket=canReadTickets&&context?.canCreate===true&&user?.permissions?.canWriteData===true;
 useEffect(()=>{
  if(initialCreate||(newTicketOwner&&newTicketOwner!==owner))setNewTicketOwner(null);
 },[initialCreate,newTicketOwner,owner]);
 const needsContext=canReadProcesses||(access&&active==="tickets");
 const modelsContextPending=active==="modeles"&&canReadProcesses&&!access&&loading;
 const showContextError=error&&(active==="tickets"||active==="processus"||active==="modeles");
 const onChanged=()=>setRefresh(value=>value+1);
 useReferencesRefresh(()=>setRefresh(value=>value+1));
 useEffect(()=>{try{localStorage.setItem("sauverndeko.support.sidebar-collapsed",String(collapsed));}catch{}},[collapsed]);
 useEffect(()=>{
  if(!legacyStages)return;
  const next=new URLSearchParams(params);
  next.set("onglet","processus");
  next.delete("vue");
  setParams(next,{replace:true});
 },[params,legacyStages,setParams]);
 useEffect(()=>{
  if(!needsContext)return;
  const controller=new AbortController();
  requestJson(SUPPORT_ROOT+"/contexte",{requiresAuth:true,signal:controller.signal}).then(response=>{
   if(controller.signal.aborted)return;
   setState({key:contextKey,owner,data:response?.success?response.data:null,
    error:response?.success?"":response?.message||"L’espace Support n’est pas disponible."});
  });
  return()=>controller.abort();
 },[contextKey,needsContext,owner]);
 function navigate(kind,criteria={}){setParams({onglet:kind,...(Object.keys(criteria).length?{filters:JSON.stringify(criteria)}:{})});}
 let initial={};try{const value=JSON.parse(params.get("filters")||"{}");if(value&&typeof value==="object"&&!Array.isArray(value))initial=value;}catch{}
 return <div className={"logistics-modern logistics-app admin-portal support-module"+(collapsed?" is-menu-collapsed":"")}>
  <ModuleSidebar title="Support" collapsed={collapsed} onToggle={()=>setCollapsed(value=>!value)} activeKey={active} onNavigate={navigate} storageKey="sauverndeko.support.navigation" groups={groups}/>
  <main className="admin-main support-main">
   {scope.globalAdmin&&!scope.entityId?<p className="support-scope-note"><span>Toutes les entreprises · Choisissez une entreprise pour créer un dossier.</span></p>:null}
   {showContextError?<div className="admin-error" role="alert"><span>{error}</span><ActionButton icon="refresh" onClick={onChanged}>Réessayer</ActionButton></div>:null}
   {presentationError?<div className="admin-error" role="status"><span>Les réglages d’affichage sont indisponibles. La présentation standard est utilisée.</span><ActionButton icon="refresh" onClick={retryPresentation}>Réessayer</ActionButton></div>:null}
   {presentationLoading?<p className="record-editor-state" role="status">Chargement de la présentation…</p>:
    modelsContextPending?<p className="support-empty" role="status">Vérification de l’accès aux modèles…</p>:
    !access?(showContextError?null:<div className="admin-error" role="alert">{requested?"Vous n’avez pas accès à cet onglet.":canReadTickets?"Aucun onglet du Support n’est affiché dans le menu.":"Vous n’avez accès à aucun onglet du Support."}</div>):
    active==="tableau-de-bord"?<SupportDashboard key={owner} title={title} hiddenDashboardBlocks={presentation?.hiddenDashboardBlocks} refresh={refresh} onNavigate={navigate}
      canReadProcesses={canReadProcesses} onChanged={onChanged}/>:
    active==="modeles"?<SupportProcessModels key={owner} title={title} refresh={refresh}/>:
    active==="processus"?<SupportStageRegister key={owner} title={title} context={context} refresh={refresh}
      onShowTickets={()=>navigate("tickets")} onShowModels={rights.modeles?()=>navigate("modeles"):undefined}
      onNewTicket={canCreateTicket?()=>{setNewTicketOwner(owner);navigate("tickets");}:undefined} onChanged={onChanged}/>:
    <SupportRegister title={title} key={owner+":"+(params.get("filters")||"")} context={context} contextLoading={loading} contextError={error}
      initial={initial} initialCreate={initialCreate} refresh={refresh} canReadJourney={rights.processus} onChanged={onChanged}/>}
  </main>
 </div>;
}
