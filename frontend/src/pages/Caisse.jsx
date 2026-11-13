import {useEffect,useState} from "react";
import {useSearchParams} from "react-router-dom";
import {useAuth} from "../contexts/AuthContext";
import {accessSignature,tabRights} from "../services/moduleAccess";
import {useEntityScope} from "../contexts/EntityScopeContext";
import {requestJson} from "../services/api";
import {useModulePresentation} from "../hooks/useModulePresentation";
import useReferencesRefresh from "../hooks/useReferencesRefresh";
import ModuleSidebar from "../components/ModuleSidebar";
import ActionButton from "../components/ActionButton";
import {CAISSE_ROOT,caisseTab} from "./caisse/caisseModel";
import CaisseDashboard from "./caisse/CaisseDashboard";
import CaisseRegister from "./caisse/CaisseRegister";
import CaisseEditor from "./caisse/CaisseEditor";
import CaisseBatchEditor from "./caisse/CaisseBatchEditor";
import CaisseDetail from "./caisse/CaisseDetail";
import CaisseValidation from "./caisse/CaisseValidation";
import CaisseValidationSettings from "./caisse/CaisseValidationSettings";
import "./logistique/LogistiqueModern.css";
import "./admin/AdminPortal.css";
import "./caisse/Caisse.css";
import "./caisse/CaisseValidation.css";

const SIDEBAR_GROUPS = [
 {key:"pilotage",label:"Pilotage",items:[{key:"tableau-de-bord",label:"Tableau de bord",icon:"dashboard"}]},
 {key:"gestion",label:"Gestion",items:[
  {key:"caisses",label:"Caisses",icon:"wallet"},
  {key:"ecritures",label:"Écritures",icon:"movements"},
 ]},
 {key:"controle",label:"Contrôles",items:[{key:"clotures",label:"Clôtures",icon:"check-circle"}]},
];

export default function Caisse(){
 const {user}=useAuth(),scope=useEntityScope(),[params,setParams]=useSearchParams(),[refresh,setRefresh]=useState(0),[retry,setRetry]=useState(0),[state,setState]=useState({owner:"",data:null,references:{},loading:true,error:""}),[drawer,setDrawer]=useState(null),[feedback,setFeedback]=useState(""),[collapsed,setCollapsed]=useState(()=>{try{return localStorage.getItem("sauverndeko.caisse.sidebar-collapsed")==="true";}catch{return false;}});
 const owner=scope.scopeKey+":"+accessSignature(user),current=state.owner===owner?state:{data:null,references:{},loading:true,error:""},context=current.data,references=current.references;
 const {presentation,loading:presentationLoading,error:presentationError,retry:retryPresentation}=useModulePresentation("caisse",scope);
 const tabLabels=presentation?.tabLabels;
 const groups=presentationLoading?[]:SIDEBAR_GROUPS.map(group=>({
  ...group,
  items:group.items.filter(item=>tabRights(user,"caisse",item.key).canRead&&!presentation?.hiddenTabs?.includes(item.key))
   .map(item=>({...item,label:tabLabels?.[item.key]||item.label})),
 })).filter(group=>group.items.length);
 const requested=params.get("onglet"),active=requested?caisseTab(requested):groups[0]?.items[0]?.key;
 const access=active?tabRights(user,"caisse",active).canRead:false;
 const hasReadableTabs=SIDEBAR_GROUPS.some(group=>group.items.some(item=>tabRights(user,"caisse",item.key).canRead));
 const canManageValidationSettings=tabRights(user,"caisse","parametres-validation").canManage;
 function canOpen(kind,mode){
  if(mode==="parametres-validation")return Boolean(scope.entityId)&&context?.canConfigureValidation===true;
  const rights=tabRights(user,"caisse",kind);
  if(kind==="ecritures"&&mode==="valider")return rights.canRead&&Boolean(scope.entityId)&&context?.canValidateEntries===true;
  if(kind==="ecritures"&&mode==="create")return rights.canRead&&Boolean(scope.entityId)&&context?.canCreateEntries===true;
  if(kind==="ecritures"&&mode==="edit")return rights.canRead&&Boolean(scope.entityId)&&context?.canEditDrafts===true;
  return rights[mode?"canManage":"canRead"];
 }
 useReferencesRefresh(()=>setRefresh(value=>value+1));
 useEffect(()=>{setFeedback("");},[owner]);
 useEffect(()=>{try{localStorage.setItem("sauverndeko.caisse.sidebar-collapsed",String(collapsed));}catch{}},[collapsed]);
 useEffect(()=>{if(!hasReadableTabs&&!canManageValidationSettings)return;const controller=new AbortController();setState(previous=>({...previous,owner,data:previous.owner===owner?previous.data:null,references:previous.owner===owner?previous.references:{},loading:true,error:""}));Promise.all([requestJson(CAISSE_ROOT+"/contexte",{requiresAuth:true,signal:controller.signal}),hasReadableTabs?requestJson(CAISSE_ROOT+"/references",{requiresAuth:true,signal:controller.signal}):Promise.resolve({success:true,data:{}})]).then(([response,refs])=>{if(controller.signal.aborted)return;setState({owner,data:response?.success?response.data:null,references:refs?.success?refs.data:{},loading:false,error:!response?.success?response?.message||"Le module Caisse n’est pas disponible.":!refs?.success?refs?.message||"Les listes de référence ne sont pas disponibles.":""});});return()=>controller.abort();},[owner,refresh,retry,hasReadableTabs,canManageValidationSettings]);
 function navigate(kind,criteria={}){setDrawer(null);setParams({onglet:kind,...(Object.keys(criteria).length?{filters:JSON.stringify(criteria)}:{})});}
 function open(next){if(canOpen(next.kind,next.mode))setDrawer({...next,owner});}
 function saved(result){setDrawer(null);setFeedback(result?.message||(result?.count>1?result.count+" lignes enregistrées.":"Opération enregistrée."));setRefresh(value=>value+1);}
 let initial={};try{const value=JSON.parse(params.get("filters")||"{}");if(value&&typeof value==="object"&&!Array.isArray(value))initial=value;}catch{}
 const safeDrawer=drawer?.owner===owner&&canOpen(drawer.kind,drawer.mode)?drawer:null;
 const settingsAction=()=>open({kind:"ecritures",mode:"parametres-validation"});
 const showSettingsLink=!presentationLoading&&canOpen("ecritures","parametres-validation")&&
  !groups.some(group=>group.items.some(item=>item.key==="ecritures"));
 const sidebarGroups=showSettingsLink?[...groups,{key:"configuration",label:"Configuration",items:[
  {key:"parametres-validation",label:"Validation des écritures",icon:"settings",onClick:settingsAction},
 ]}]:groups;
 return <div className={"logistics-modern logistics-app admin-portal caisse-module"+(collapsed?" is-menu-collapsed":"")}>
  <ModuleSidebar title="Caisse" collapsed={collapsed} onToggle={()=>setCollapsed(value=>!value)} activeKey={active} onNavigate={navigate} storageKey="sauverndeko.caisse.navigation" groups={sidebarGroups}/>
  <main className="admin-main caisse-main">
   {scope.globalAdmin&&!scope.entityId?<p className="caisse-scope-note">Toutes les entreprises · Choisissez une entreprise pour effectuer une opération.</p>:null}
   {presentationError?<div className="admin-error" role="status"><span>Les réglages d’affichage sont indisponibles. La présentation standard est utilisée.</span><ActionButton icon="refresh" onClick={retryPresentation}>Réessayer</ActionButton></div>:null}
   {current.error?<div className="admin-error" role="alert"><span>{current.error}</span><ActionButton icon="refresh" onClick={()=>setRetry(value=>value+1)}>Réessayer</ActionButton></div>:null}
   {feedback?<div className="admin-feedback" role="status">{feedback}<ActionButton icon="close" aria-label="Fermer le message" onClick={()=>setFeedback("")}/></div>:null}
   {presentationLoading?<p className="record-editor-state" role="status">Chargement de la présentation…</p>:!active&&showSettingsLink?<div className="admin-header"><h1>Validation des écritures</h1><ActionButton icon="settings" onClick={settingsAction}>Réglages</ActionButton></div>:!access?<div className="admin-error" role="alert">{requested?"Vous n’avez pas accès à cet onglet.":"Vous n’avez accès à aucun onglet de la Caisse."}</div>:active==="tableau-de-bord"?
    <CaisseDashboard key={owner} title={tabLabels?.[active]} hiddenDashboardBlocks={presentation?.hiddenDashboardBlocks}
      canConfigurePresentation={presentation?.canManage===true} readCash={canOpen("caisses")} readEntries={canOpen("ecritures")} context={context} references={references} refresh={refresh} onOpen={open}/>:
    <CaisseRegister title={tabLabels?.[active]} key={owner+":"+active+":"+(params.get("filters")||"")} kind={active} context={context} references={references} refresh={refresh} initial={initial} onOpen={open} onCreate={kind=>open({kind,mode:"create"})}/>}
  </main>
  {safeDrawer?.mode==="create"?<CaisseBatchEditor key={owner+":"+safeDrawer.kind+":panier"} {...safeDrawer} context={context}
    references={references} onClose={()=>setDrawer(null)} onSaved={saved}/>:null}
  {safeDrawer?.mode==="parametres-validation"?<CaisseValidationSettings key={owner+":validation-settings"}
    companyName={scope.entities.find(entity=>String(entity.id)===scope.entityId)?.label} onClose={()=>setDrawer(null)} onSaved={saved}/>:null}
  {safeDrawer?.mode==="valider"?<CaisseValidation key={owner+":validation"}
    rows={safeDrawer.rows} onClose={()=>setDrawer(null)} onSaved={saved}/>:null}
  {["edit","contrepasser"].includes(safeDrawer?.mode)?<CaisseEditor key={owner+":"+safeDrawer.kind+":"+safeDrawer.id+":"+safeDrawer.mode}
    {...safeDrawer} context={context} references={references} onClose={()=>setDrawer(null)} onSaved={saved}/>:null}
  {safeDrawer&&!safeDrawer.mode?<CaisseDetail key={owner+":"+safeDrawer.kind+":"+safeDrawer.id} kind={safeDrawer.kind}
    id={safeDrawer.id} context={context} onClose={()=>setDrawer(null)} onOpen={open} onNavigate={navigate}/>:null}
 </div>;
}
