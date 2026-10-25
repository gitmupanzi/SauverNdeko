import {useEffect,useId,useState} from "react";
import {useEntityScope} from "../contexts/EntityScopeContext";
import SearchSelect from "./SearchSelect";
import AppIcon from "./AppIcon";
import "./EntityScopePicker.css";
export default function EntityScopePicker(){
  const scope=useEntityScope(),id=useId(),[blocked,setBlocked]=useState(false);
  useEffect(()=>{const sync=()=>setBlocked(Boolean(document.querySelector("dialog[open]")));sync();const observer=new MutationObserver(sync);observer.observe(document.body,{subtree:true,childList:true,attributes:true,attributeFilter:["open"]});return()=>observer.disconnect();},[]);
  if(!scope.globalAdmin)return null;
  const options=[{value:"",label:"Toutes les entreprises"},...scope.entities.filter(item=>item.active!==false||String(item.id)===scope.entityId).map(item=>({value:String(item.id),label:item.label,disabled:item.active===false}))];
  return <div className="entity-scope-picker" title={blocked?"Fermez la fenêtre avant de changer d’entreprise.":scope.error||"Entreprise active"}><AppIcon name="apps"/><SearchSelect id={id} label="Entreprise active" value={scope.entityId} options={options} onChange={scope.selectEntity} disabled={blocked||scope.loading} loading={scope.loading}/>{scope.error?<button type="button" aria-label="Recharger les entreprises" onClick={scope.retry}><AppIcon name="refresh"/></button>:null}</div>;
}
