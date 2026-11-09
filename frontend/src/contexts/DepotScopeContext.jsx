import {createContext,useContext,useEffect,useMemo,useState} from "react";
import {useEntityScope} from "./EntityScopeContext";
import {requestJson} from "../services/api";
import SearchSelect from "../components/SearchSelect";
import ActionButton from "../components/ActionButton";
import "../pages/logistique/Depots.css";

const EMPTY={depotId:"",defaultDepotId:"",depots:[],loading:false,error:"",revision:0,retry(){},selectDepot(){}};
const Context=createContext(EMPTY);
export function depotOptions(rows=[],{all=false,current="",currentLabel=""}={}){
 const options=rows.map(row=>({value:String(row.id??row.ID_Depot),label:[row.label??row.NomDepot,row.principal??row.Principal?"Principal":""].filter(Boolean).join(" · "),disabled:row.active===false||row.Actif===false}));
 if(current&&!options.some(option=>option.value===String(current)))options.unshift({value:String(current),label:currentLabel||"Dépôt enregistré",disabled:true,incompatible:true});
 return [{value:"",label:all?"Tous les dépôts":"Choisir un dépôt…"},...options];
}
export function DepotScopeProvider({children}){
 const scope=useEntityScope(),[state,setState]=useState({key:"",rows:[],defaultId:"",error:""}),[choice,setChoice]=useState({key:"",id:""}),[revision,setRevision]=useState(0);
 const current=state.key===scope.scopeKey?state:null,depotId=choice.key===scope.scopeKey?choice.id:"";
 useEffect(()=>{
  const controller=new AbortController();setState({key:"",rows:[],defaultId:"",error:""});
  (async()=>{
   const response = await requestJson("/api/logistique/depots?usage=selection",{requiresAuth:true,signal:controller.signal});
   if(controller.signal.aborted)return;
   const rows = Array.isArray(response?.data) ? response.data : [];
   const principal=rows.find(row=>(row.Principal===true||row.principal===true)&&row.Actif!==false&&row.active!==false);
   setState({key:scope.scopeKey,rows:response?.success?rows:[],defaultId:String(principal?.ID_Depot??principal?.id??""),error:response?.success?"":response?.message||"Les dépôts ne sont pas disponibles."});
  })();return()=>controller.abort();
 },[scope.scopeKey,revision]);
 function selectDepot(id){if(document.querySelector("dialog[open]"))return;const value=String(id||"");if(value&&!current?.rows.some(row=>String(row.id??row.ID_Depot)===value))return;setChoice({key:scope.scopeKey,id:value});}
 const value=useMemo(()=>({depotId,defaultDepotId:current?.defaultId||"",depots:current?.rows||[],loading:!current,error:current?.error||"",revision,retry:()=>setRevision(value=>value+1),selectDepot}),[depotId,current,revision]);
 return <Context.Provider value={value}>{children}</Context.Provider>;
}
export function useDepotScope(){return useContext(Context);}
export function DepotScopeBar(){
 const depot=useDepotScope(),scope=useEntityScope();
 return <div className="depot-scope-bar"><label><span>Dépôt</span><SearchSelect label="Dépôt de consultation" value={depot.depotId} options={depotOptions(depot.depots,{all:true,current:depot.depotId})} onChange={depot.selectDepot} loading={depot.loading} disabled={depot.loading||Boolean(depot.error)}/></label><small>{depot.depotId?"Stocks du dépôt sélectionné. Le total de l’entreprise reste distinct.":scope.entityId?"Vue de tous les dépôts. Le dépôt est précisé dans chaque opération.":"Sélectionnez une entreprise pour effectuer une opération."}</small>{depot.error?<span className="record-field-error" role="alert">{depot.error}<ActionButton icon="refresh" onClick={depot.retry}>Réessayer</ActionButton></span>:null}</div>;
}
export function DepotField({value,onChange,disabled=false,label="Dépôt *",error="",currentLabel="",id}){
 const depot=useDepotScope();
 return <label className="record-field" htmlFor={id}><span>{label}</span><SearchSelect id={id} label={label} value={String(value||"")} options={depotOptions(depot.depots,{current:value,currentLabel})} onChange={onChange} disabled={disabled||depot.loading||Boolean(depot.error)} loading={depot.loading} invalid={Boolean(error)} describedBy={error?id+"-error":undefined}/>{error?<small id={id+"-error"} className="record-field-error">{error}</small>:null}{depot.error?<small className="record-field-error">{depot.error}</small>:null}</label>;
}
