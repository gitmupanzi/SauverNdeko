import {useEffect,useState} from "react";
import {useSearchParams} from "react-router-dom";
import {useEntityScope} from "../../contexts/EntityScopeContext";
import {requestJson} from "../../services/api";
import useReferencesRefresh from "../../hooks/useReferencesRefresh";
import ModuleHeader from "../../components/ModuleHeader";
import ModuleSidebar from "../../components/ModuleSidebar";
import ActionButton from "../../components/ActionButton";
import SupportDashboard from "./SupportDashboard";
import SupportRegister from "./SupportRegister";
import {SUPPORT_ROOT} from "./supportForm";
import "../logistique/LogistiqueModern.css";
import "../admin/AdminPortal.css";
import "./Support.css";

export default function SupportPortal(){
 const scope=useEntityScope(),[params,setParams]=useSearchParams(),[refresh,setRefresh]=useState(0),[state,setState]=useState({key:"",data:null,error:"",loading:true});
 const contextKey=scope.scopeKey+":"+refresh,current=state.key===contextKey?state:{data:null,error:"",loading:true},context=current.data,error=current.error,loading=current.loading;
 const [collapsed,setCollapsed]=useState(()=>{try{return localStorage.getItem("sauverndeko.support.sidebar-collapsed")==="true";}catch{return false;}});
 const active=params.get("onglet")==="tickets"?"tickets":"tableau-de-bord";
 useReferencesRefresh(()=>setRefresh(value=>value+1));
 useEffect(()=>{try{localStorage.setItem("sauverndeko.support.sidebar-collapsed",String(collapsed));}catch{}},[collapsed]);
 useEffect(()=>{const controller=new AbortController();setState({key:contextKey,data:null,error:"",loading:true});requestJson(SUPPORT_ROOT+"/contexte",{requiresAuth:true,signal:controller.signal}).then(response=>{if(controller.signal.aborted)return;setState({key:contextKey,data:response?.success?response.data:null,error:response?.success?"":response?.message||"L’espace Support n’est pas disponible.",loading:false});});return()=>controller.abort();},[contextKey]);
 function navigate(kind,criteria={}){setParams({onglet:kind,...(Object.keys(criteria).length?{filters:JSON.stringify(criteria)}:{})});}
 let initial={};try{const value=JSON.parse(params.get("filters")||"{}");if(value&&typeof value==="object"&&!Array.isArray(value))initial=value;}catch{}
 return <div className={"logistics-modern logistics-app admin-portal support-module"+(collapsed?" is-menu-collapsed":"")}>
  <ModuleSidebar title="Support" collapsed={collapsed} onToggle={()=>setCollapsed(value=>!value)} activeKey={active} onNavigate={navigate} storageKey="sauverndeko.support.navigation" groups={[{key:"pilotage",label:"Pilotage",items:[{key:"tableau-de-bord",label:"Tableau de bord",icon:"dashboard"}]},{key:"traitement",label:"Traitement",items:[{key:"tickets",label:"Tickets",icon:"help"}]}]}/>
  <ModuleHeader title="Support"/>
  <main className="admin-main support-main">
   {scope.globalAdmin&&!scope.entityId?<p className="support-scope-note"><span>Toutes les entreprises · Choisissez une entreprise pour créer un dossier.</span></p>:null}
   {error?<div className="admin-error" role="alert"><span>{error}</span><ActionButton icon="refresh" onClick={()=>setRefresh(value=>value+1)}>Réessayer</ActionButton></div>:null}
   {active==="tableau-de-bord"?<SupportDashboard refresh={refresh} onNavigate={navigate}/>:<SupportRegister key={scope.scopeKey+":"+(params.get("filters")||"")} context={context} contextLoading={loading} contextError={error} initial={initial} refresh={refresh} onChanged={()=>setRefresh(value=>value+1)}/>}
  </main>
 </div>;
}
