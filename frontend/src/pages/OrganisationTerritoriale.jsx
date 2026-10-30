import {useEffect,useState} from "react";
import ModuleHeader from "../components/ModuleHeader";
import Admin from "./Admin";
import "./logistique/LogistiqueModern.css";

export default function OrganisationTerritoriale() {
  const [collapsed,setCollapsed]=useState(()=>{try{return localStorage.getItem("sauverndeko.territoires.sidebar-collapsed")==="true";}catch{return false;}});
  useEffect(()=>{try{localStorage.setItem("sauverndeko.territoires.sidebar-collapsed",String(collapsed));}catch{}},[collapsed]);
  return <div className={"logistics-modern logistics-app territorial-module"+(collapsed?" is-menu-collapsed":"")}><ModuleHeader title="Organisation territoriale" /><Admin schemaOnly="geolocalisation" moduleTitle="Organisation territoriale" navigationCollapsed={collapsed} onToggleNavigation={()=>setCollapsed(value=>!value)}/></div>;
}
