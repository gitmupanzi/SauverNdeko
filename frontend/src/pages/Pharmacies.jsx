import {useEffect,useState} from "react";
import {useSearchParams} from "react-router-dom";
import {useAuth} from "../contexts/AuthContext";
import {useEntityScope} from "../contexts/EntityScopeContext";
import {accessSignature,mayOpen} from "../services/moduleAccess";
import ModuleSidebar from "../components/ModuleSidebar";
import ModuleHeader from "../components/ModuleHeader";
import StructureDirectory from "./structures/StructureDirectory";
import StructureProfiles from "./structures/StructureProfiles";
import useStructureRead from "./structures/useStructureRead";
import "./logistique/LogistiqueModern.css";
import "./admin/AdminPortal.css";
import "./structures/Structures.css";

export default function Pharmacies(){
 const {user}=useAuth(),scope=useEntityScope(),[params,setParams]=useSearchParams(),[revision,setRevision]=useState(0);
 const owner=[user?.IdUser,scope.scopeKey,accessSignature(user)].join(":"),tab=params.get("onglet")==="profils"?"profils":"annuaire";
 const [collapsed,setCollapsed]=useState(()=>{try{return localStorage.getItem("sauverndeko.structures.sidebar-collapsed")==="true";}catch{return false;}});
 const context=useStructureRead({owner,path:"/api/structures/contexte",revision,parse:response=>response?.success&&response.data&&typeof response.data.canReadRegistry==="boolean"?response.data:null});
 useEffect(()=>{try{localStorage.setItem("sauverndeko.structures.sidebar-collapsed",String(collapsed));}catch{}},[collapsed]);
 function navigateTab(value){setParams(previous=>{const next=new URLSearchParams(previous);next.set("onglet",value);next.delete("structure");return next;});}
 return <div className={"logistics-modern logistics-app admin-portal structures-module"+(collapsed?" is-menu-collapsed":"")}>
  <ModuleSidebar title="Structures" collapsed={collapsed} onToggle={()=>setCollapsed(value=>!value)} activeKey={tab} onNavigate={navigateTab} storageKey="sauverndeko.structures.navigation" groups={[{key:"structures",label:"Structures",items:[{key:"annuaire",label:"Annuaire",icon:"building"},{key:"profils",label:"Profils des structures",icon:"document",hidden:context.data?.canReadRegistry!==true}]}]} footerItems={[{key:"guide",label:"Guide utilisateur",icon:"book",to:"/guide?module=structures",hidden:!mayOpen(user,"/guide")},{key:"settings",label:"Paramètres",icon:"settings",to:"/parametres",hidden:!mayOpen(user,"/parametres")},{key:"admin",label:"Administration",icon:"shield",to:"/admin",hidden:!mayOpen(user,"/admin")},{key:"applications",label:"Applications",icon:"apps",to:"/espace"}]}/>
  <ModuleHeader title="Structures"/>
  <main className="admin-main structures-main">
   {tab==="annuaire"?<StructureDirectory/>:<StructureProfiles owner={owner} context={context} onContextReload={()=>setRevision(value=>value+1)}/>}
  </main>
 </div>;
}
