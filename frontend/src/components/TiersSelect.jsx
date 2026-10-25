import {useEffect,useState} from "react";
import {useEntityScope} from "../contexts/EntityScopeContext";
import SearchSelect from "./SearchSelect";
import ActionButton from "./ActionButton";
import TiersEditor from "../pages/logistique/TiersEditor";
import Tiers360 from "../pages/logistique/Tiers360";
import {requestJson} from "../services/api";
import {TIERS_CHANGED,tiersOptions} from "../services/tiers";
import "../pages/logistique/Tiers.css";
export default function TiersSelect({id,value,onChange,references=[],currentLabel="",disabled=false,invalid=false,label="Tiers référencé"}){
  const scope=useEntityScope(),[added,setAdded]=useState([]),[editor,setEditor]=useState(false),[consult,setConsult]=useState(false),[remote,setRemote]=useState(null);
  useEffect(()=>{let live=true;const refresh=()=>requestJson("/api/logistique/references",{requiresAuth:true}).then(response=>{if(live&&response?.success)setRemote(response.data?.clients||[]);});window.addEventListener(TIERS_CHANGED,refresh);return()=>{live=false;window.removeEventListener(TIERS_CHANGED,refresh);};},[scope.scopeKey]);
  const merged=[...new Map([...(remote||references),...added].map(item=>[String(item.id),item])).values()];
  const options=[{value:"",label:"Non renseigné"},...tiersOptions(merged)];if(value&&!options.some(item=>item.value===String(value)))options.push({value:String(value),label:currentLabel||"Tiers actuel"});
  function saved(row){setEditor(false);if(!row?.ID_Client)return;setAdded(current=>[...current,{id:row.ID_Client,label:row.Nom,typeId:row.ID_TypeClientFk,typeLabel:row.TypeClient}]);onChange(String(row.ID_Client),row.Nom);}
  return <><div className="tiers-inline-select"><SearchSelect id={id} label={label} value={value} options={options} onChange={next=>onChange(next,merged.find(item=>String(item.id)===next)?.label||"")} disabled={disabled} invalid={invalid}/>{value?<ActionButton icon="eye" className="is-icon" aria-label="Consulter le tiers" disabled={disabled} onClick={()=>setConsult(true)}/>:null}{scope.canCreate?<ActionButton icon="plus" className="is-icon" aria-label="Créer un tiers" title="Créer un tiers" disabled={disabled} onClick={()=>setEditor(true)}/>:null}</div>{editor?<TiersEditor onClose={()=>setEditor(false)} onSaved={saved}/>:null}{consult&&value?<Tiers360 tiersId={value} onClose={()=>setConsult(false)}/>:null}</>;
}
