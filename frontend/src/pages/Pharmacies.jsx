import {useEffect,useState} from "react";
import {Link,useSearchParams} from "react-router-dom";
import {useAuth} from "../contexts/AuthContext";
import {accessSignature} from "../services/moduleAccess";
import ModuleSidebar from "../components/ModuleSidebar";
import StructureDirectory from "./structures/StructureDirectory";
import RegisterSurface from "../components/RegisterSurface";
import ListState from "../components/ListState";
import ActionButton from "../components/ActionButton";
import AppIcon from "../components/AppIcon";
import useStructureRead from "./structures/useStructureRead";
import "./logistique/LogistiqueModern.css";
import "./admin/AdminPortal.css";
import "./structures/Structures.css";

export default function Pharmacies(){
 const {user}=useAuth(),[params,setParams]=useSearchParams(),[revision,setRevision]=useState(0);
 const owner=[user?.IdUser,accessSignature(user)].join(":"),tab=params.get("onglet")==="gestion"?"gestion":"annuaire";
 const [collapsed,setCollapsed]=useState(()=>{try{return localStorage.getItem("sauverndeko.structures.sidebar-collapsed")==="true";}catch{return false;}});
 const context=useStructureRead({owner,path:"/api/structures/contexte",revision,parse:response=>response?.success&&typeof response.data?.canManageTerritories==="boolean"?response.data:null});
 useEffect(()=>{try{localStorage.setItem("sauverndeko.structures.sidebar-collapsed",String(collapsed));}catch{}},[collapsed]);
 function navigateTab(value){setParams(previous=>{const next=new URLSearchParams(previous);next.set("onglet",value);next.delete("structure");return next;});}
 return <div className={"logistics-modern logistics-app admin-portal structures-module"+(collapsed?" is-menu-collapsed":"")}>
  <ModuleSidebar headerProps={{showEntityScope:false}} title="Structures" collapsed={collapsed} onToggle={()=>setCollapsed(value=>!value)} activeKey={tab} onNavigate={navigateTab} storageKey="sauverndeko.structures.navigation" groups={[{key:"structures",label:"Structures",items:[{key:"annuaire",label:"Annuaire",icon:"building"},{key:"gestion",label:"Gestion territoriale",icon:"globe",hidden:context.data?.canManageTerritories!==true}]}]}/>
  <main className="admin-main structures-main">
   {tab==="annuaire"?<StructureDirectory/>:<StructureManagement context={context} onRetry={()=>setRevision(value=>value+1)}/>}
  </main>
 </div>;
}

export function StructureManagement({context,onRetry}){
 const destinations=[{kind:"niveaux3",label:"Niveau 3",description:"Zones, districts, secteurs et autres territoires de niveau 3."},{kind:"niveaux4",label:"Niveau 4",description:"Aires et autres territoires de niveau 4."},{kind:"niveaux5",label:"Structures et sites",description:"Établissements, pharmacies et autres structures et sites du niveau 5."}];
 return <RegisterSurface title="Gestion territoriale" subtitle="Les structures et les territoires partagent les mêmes fiches de référence."><div className="structure-directory">
  {context.loading?<ListState loading role="status" title="Chargement des accès…"/>:context.error?<ListState role="alert" icon="alert" title="Les accès sont indisponibles" description={context.error} action={<ActionButton icon="refresh" onClick={onRetry}>Réessayer</ActionButton>}/>:context.data?.canManageTerritories!==true?<ListState role="status" icon="shield" title="Gestion territoriale réservée aux administrateurs autorisés" description="Vous pouvez consulter les structures et territoires dans l’annuaire."/>:<div className="structure-cards structure-management">{destinations.map(item=><article className="structure-card" key={item.kind}><div className="structure-card-copy"><AppIcon name={item.kind==="niveaux5"?"building":"globe"} size={25}/><h2>{item.label}</h2><p className="structure-note">{item.description}</p><Link className="ui-action is-primary" aria-label={"Ouvrir le registre "+item.label} to={"/territoires?onglet="+item.kind}>Ouvrir le registre</Link></div></article>)}</div>}
 </div></RegisterSurface>;
}
