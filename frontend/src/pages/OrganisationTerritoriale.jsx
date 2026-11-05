import {useEffect,useState} from "react";
import {useSearchParams} from "react-router-dom";
import ModuleSidebar from "../components/ModuleSidebar";
import ModuleHeader from "../components/ModuleHeader";
import useReferencesRefresh from "../hooks/useReferencesRefresh";
import TerritoryRegister from "./territoires/TerritoryRegister";
import TerritoryDashboard from "./territoires/TerritoryDashboard";
import {TERRITORY_REGISTERS,TERRITORY_NAVIGATION,territoryTabKey} from "./territoires/territorialDefinitions";
import "./logistique/LogistiqueModern.css";
import "./admin/AdminPortal.css";
import "./territoires/Territoires.css";

export function territoryInitialFilters(value){try{const parsed=JSON.parse(value||"{}");return parsed&&typeof parsed==="object"&&!Array.isArray(parsed)?parsed:{};}catch{return {};}}
export default function OrganisationTerritoriale(){
 const [params,setParams]=useSearchParams(),[refresh,setRefresh]=useState(0);
 const [collapsed,setCollapsed]=useState(()=>{try{return localStorage.getItem("sauverndeko.territoires.sidebar-collapsed")==="true";}catch{return false;}});
 const requested=params.get("onglet")||params.get("vue")||params.get("view"),active=territoryTabKey(requested),initial=territoryInitialFilters(params.get("filters"));
 useEffect(()=>{try{localStorage.setItem("sauverndeko.territoires.sidebar-collapsed",String(collapsed));}catch{}},[collapsed]);
 useEffect(()=>{if(!requested||requested===active)return;const next=new URLSearchParams(params);next.delete("vue");next.delete("view");next.set("onglet",active);setParams(next,{replace:true});},[requested,active,params,setParams]);
 useReferencesRefresh(()=>setRefresh(value=>value+1));
 function navigate(kind,filters={}){if(kind!=="tableau-de-bord"&&!TERRITORY_REGISTERS[kind])return;if(kind===active&&!Object.keys(filters).length&&!params.get("filters"))return;setParams({onglet:kind,...(Object.keys(filters).length?{filters:JSON.stringify(filters)}:{})});}
 return <div className={"logistics-modern logistics-app admin-portal territorial-module"+(collapsed?" is-menu-collapsed":"")}>
  <ModuleSidebar title="Organisation territoriale" collapsed={collapsed} onToggle={()=>setCollapsed(value=>!value)} groups={TERRITORY_NAVIGATION} activeKey={active} onNavigate={navigate} storageKey="sauverndeko.territoires.navigation"/>
  <ModuleHeader title="Organisation territoriale"/>
  <main className="admin-main territory-main">{active==="tableau-de-bord"?<TerritoryDashboard refresh={refresh} onNavigate={navigate}/>:<TerritoryRegister key={active+":"+(params.get("filters")||"")} kind={active} initial={initial} refresh={refresh} onChanged={()=>setRefresh(value=>value+1)} onNavigate={navigate}/>}</main>
 </div>;
}
