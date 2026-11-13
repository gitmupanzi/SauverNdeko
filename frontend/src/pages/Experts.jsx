import {useEffect,useRef,useState} from "react";
import {useLocation,useNavigate,useSearchParams} from "react-router-dom";
import {useEntityScope} from "../contexts/EntityScopeContext";
import {useAuth} from "../contexts/AuthContext";
import {requestJson} from "../services/api";
import {tabRights} from "../services/moduleAccess";
import {buildDiscussionPath} from "../services/mappers";
import useReferencesRefresh from "../hooks/useReferencesRefresh";
import ModuleSidebar from "../components/ModuleSidebar";
import ActionButton from "../components/ActionButton";
import ListState from "../components/ListState";
import ExpertDirectory from "./experts/ExpertDirectory";
import ExpertDetail from "./experts/ExpertDetail";
import ExpertEditor from "./experts/ExpertEditor";
import ExpertAction from "./experts/ExpertAction";
import ExpertPublicationSettings from "./experts/ExpertPublicationSettings";
import ExpertBatchEditor from "./experts/ExpertBatchEditor";
import {EXPERT_ROOT} from "./experts/expertModel";
import "./logistique/LogistiqueModern.css";
import "./admin/AdminPortal.css";
import "./experts/Experts.css";

export default function Experts({onContact}){
 const {user}=useAuth();
 const scope=useEntityScope(),location=useLocation(),navigate=useNavigate(),[params,setParams]=useSearchParams(),[state,setState]=useState({owner:"",context:null,references:{},loading:true,error:""}),[refresh,setRefresh]=useState(0),[retry,setRetry]=useState(0),[drawer,setDrawer]=useState(null),[feedback,setFeedback]=useState(null),[collapsed,setCollapsed]=useState(()=>{try{return localStorage.getItem("sauverndeko.experts.sidebar-collapsed")==="true";}catch{return false;}}),focus=useRef(null);
 const owner=scope.scopeKey,current=state.owner===owner?state:{context:null,references:{},loading:true,error:""};
 const annuaire=tabRights(user,"professionnels","annuaire").canRead;
 const profils=tabRights(user,"professionnels","profils").canRead&&(current.context?.canReadRegistry||current.context?.platformAdmin||current.context?.canManage);
 const active=profils&&(params.get("onglet")==="profils"||!annuaire)?"profils":annuaire?"annuaire":null;
 const safeDrawer=drawer?.owner===owner&&(drawer.manage||drawer.mode||drawer.batch||drawer.action||drawer.publicationSettings?profils:annuaire)?drawer:null;
 useReferencesRefresh(()=>setRefresh(value=>value+1));
 useEffect(()=>{setFeedback(null);},[owner]);
 useEffect(()=>{try{localStorage.setItem("sauverndeko.experts.sidebar-collapsed",String(collapsed));}catch{}},[collapsed]);
 useEffect(()=>{const controller=new AbortController();setState(previous=>({...previous,owner,context:previous.owner===owner?previous.context:null,references:previous.owner===owner?previous.references:{},loading:true,error:""}));Promise.all([requestJson(EXPERT_ROOT+"/contexte",{requiresAuth:true,signal:controller.signal}),requestJson(EXPERT_ROOT+"/references",{requiresAuth:true,signal:controller.signal})]).then(([context,references])=>{if(controller.signal.aborted)return;setState({owner,context:context?.success?context.data:null,references:references?.success?references.data:{},loading:false,error:!context?.success?context?.message||"Le module n’est pas disponible.":!references?.success?references?.message||"Les listes de référence ne sont pas disponibles.":""});});return()=>controller.abort();},[owner,refresh,retry]);
 useEffect(()=>{const id=location.state?.focusId;if(!id||focus.current===location.key)return;focus.current=location.key;setDrawer({id:String(id),owner,manage:false});},[location.key,location.state,owner]);
 function open(next){setDrawer({...next,owner});}
 function contact(target){setDrawer(null);if(onContact)onContact(target);else navigate(buildDiscussionPath("expert",target.id),{state:{targetName:target.name,targetType:"expert"}});}
 function saved(record){
  const id=record?.IdProfessionnel||record?.id,action=safeDrawer?.action;
  let message="Profil mis à jour.";
  if (safeDrawer?.publicationSettings) message="Réglage de publication enregistré.";
  else if (safeDrawer?.selection){
   const multiple=record.count>1;
   const label=record.count+" profil"+(multiple?"s ":" ");
   message=label+(action==="publier"?(multiple?"publiés.":"publié."):(multiple?"retirés de l’annuaire.":"retiré de l’annuaire."));
  }
  else if (safeDrawer?.batch){
   const total=record?.count||0,published=record?.publishedCount||0;
   message=total+(total===1?" profil enregistré":" profils enregistrés")+", dont "+published+(published===1?" publié.":" publiés.");
  }
  else if (action) message=({publier:"Profil publié dans l’annuaire.",depublier:"Profil retiré de l’annuaire.",archiver:"Profil archivé.",reactiver:"Profil réactivé. Publiez-le pour le rendre visible dans l’annuaire."})[action];
  else if (safeDrawer?.mode==="create") message=record?.Publie?"Profil enregistré et publié dans l’annuaire.":"Brouillon enregistré.";
  setDrawer(null);setFeedback({text:message,id:id||null});setRefresh(value=>value+1);
 }
 return <div className={"logistics-modern logistics-app admin-portal experts-module"+(collapsed?" is-menu-collapsed":"")}>
  <ModuleSidebar title="Professionnels" collapsed={collapsed} onToggle={()=>setCollapsed(value=>!value)} activeKey={active} onNavigate={key=>{setDrawer(null);setParams(key==="annuaire"?{}:{onglet:key});}} storageKey="sauverndeko.experts.navigation" groups={[{key:"annuaire",label:"Professionnels",items:[{key:"annuaire",label:"Annuaire",icon:"user",hidden:!annuaire},{key:"profils",label:"Profils professionnels",icon:"document",hidden:!profils}]}]}/>
  <main className="admin-main experts-main">
   {current.error?<div className="admin-error" role="alert"><span>{current.error}</span><ActionButton icon="refresh" onClick={()=>setRetry(value=>value+1)}>Réessayer</ActionButton></div>:null}
   {feedback?<div className="admin-feedback" role="status">{feedback.text}{feedback.id?<ActionButton icon="eye" onClick={()=>open({id:feedback.id,manage:true})}>Consulter le profil</ActionButton>:null}<ActionButton icon="close" aria-label="Fermer le message" onClick={()=>setFeedback(null)}/></div>:null}
   {active==="profils"&&scope.globalAdmin&&!scope.entityId?<p className="expert-scope-note">Choisissez une entreprise pour créer, modifier ou publier un profil.</p>:null}
   {active?<ExpertDirectory key={owner+":"+active} manage={active==="profils"} context={current.loading?null:current.context} references={current.references} refresh={refresh} onOpen={open} onContact={contact} onCreate={()=>open({mode:"create"})} onImport={()=>open({batch:true})} onPublicationSettings={()=>open({publicationSettings:true})} onManage={profils?()=>{setDrawer(null);setParams({onglet:"profils"});}:undefined}/>:<ListState loading={current.loading} icon="shield" title={current.loading?"Chargement des accès…":"Aucun onglet accessible"}/>}
  </main>
  {safeDrawer?.publicationSettings?<ExpertPublicationSettings key={owner+":publication"} context={current.context} onClose={()=>setDrawer(null)} onSaved={saved}/>:safeDrawer?.batch?<ExpertBatchEditor key={owner+":batch"} context={current.loading?null:current.context} references={current.references} onClose={()=>setDrawer(null)} onSaved={saved}/>:safeDrawer?.action?<ExpertAction key={owner+":"+safeDrawer.id+":"+safeDrawer.action} {...safeDrawer} context={current.context} onClose={()=>setDrawer(null)} onSaved={saved}/>:safeDrawer?.mode?<ExpertEditor key={owner+":"+(safeDrawer.id||"new")} id={safeDrawer.id} context={current.context} onClose={()=>setDrawer(null)} onSaved={saved}/>:safeDrawer?<ExpertDetail key={owner+":"+safeDrawer.id+":"+Boolean(safeDrawer.manage)} id={safeDrawer.id} manage={safeDrawer.manage} onClose={()=>setDrawer(null)} onEdit={id=>open({id,mode:"edit"})} onAction={open} onContact={contact}/>:null}
 </div>;
}
