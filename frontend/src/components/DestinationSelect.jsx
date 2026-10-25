import {useEffect,useState} from "react";
import {useEntityScope} from "../contexts/EntityScopeContext";
import SearchSelect from "./SearchSelect";
import {requestJson} from "../services/api";

const PAGE_SIZE=25;
export default function DestinationSelect({id,value,onChange,selectedLabel="",disabled=false,invalid=false}){
 const {scopeKey}=useEntityScope();
 const [search,setSearch]=useState(""),[query,setQuery]=useState(""),[skip,setSkip]=useState(0),[rows,setRows]=useState([]),[meta,setMeta]=useState(null),[selected,setSelected]=useState(null);
 const [loading,setLoading]=useState(true),[error,setError]=useState(""),[lookupError,setLookupError]=useState(""),[revision,setRevision]=useState(0);
 useEffect(()=>{if(search.trim()===query)return;const timer=setTimeout(()=>{setQuery(search.trim());setSkip(0);},250);return()=>clearTimeout(timer);},[search,query]);
 useEffect(()=>{
  let live=true;const controller=new AbortController();setLoading(true);setError("");
  requestJson("/api/logistique/destinations?"+new URLSearchParams({q:query,take:String(PAGE_SIZE),skip:String(skip)}),{requiresAuth:true,signal:controller.signal}).then(result=>{
   if(!live)return;setLoading(false);
   if(!result?.success){setError(result?.message||"Les destinations ne sont pas disponibles.");return;}
   const items=Array.isArray(result.data)?result.data:[];
   setRows(current=>skip===0?items:[...new Map([...current,...items].map(item=>[String(item.id),item])).values()]);setMeta({...result.meta,pageCount:items.length});
  });
  return()=>{live=false;controller.abort();};
 },[query,skip,revision,scopeKey]);
 useEffect(()=>{
  let live=true;setLookupError("");if(!value){setSelected(null);return()=>{live=false;};}
  const controller=new AbortController();requestJson("/api/logistique/destinations?"+new URLSearchParams({id:String(value),take:"1",skip:"0"}),{requiresAuth:true,signal:controller.signal}).then(result=>{
   if(!live)return;const item=result?.success&&Array.isArray(result.data)?result.data.find(row=>String(row.id)===String(value)):null;
   if(item)setSelected(item);else setLookupError(result?.message||"La destination actuelle n’a pas pu être vérifiée.");
  });
  return()=>{live=false;controller.abort();};
 },[value,scopeKey]);
 const pending=search.trim()!==query,currentOption=value?selected&&String(selected.id)===String(value)?selected:{id:value,label:selectedLabel||"Destination actuelle"}:null;
 const choices=[...new Map([...(currentOption?[currentOption]:[]),...rows].map(item=>[String(item.id),item])).values()];
 const hasMore=Boolean(meta?.pageCount)&&Number(meta?.skip??skip)+Number(meta?.take??PAGE_SIZE)<Number(meta?.filteredCount??meta?.totalCount??0);
 return <><SearchSelect id={id} label="Destination" value={value} options={[{value:"",label:"Non renseignée"},...choices.map(item=>({value:String(item.id),label:item.label}))]} onChange={onChange} disabled={disabled} invalid={invalid} remote onSearchChange={setSearch} optionsLoading={pending||loading&&skip===0} moreLoading={loading&&skip>0} optionsError={pending?"":error} onOptionsRetry={()=>setRevision(current=>current+1)} hasMore={!pending&&hasMore} onLoadMore={()=>{if(!loading&&!pending&&hasMore)setSkip(Number(meta?.skip??skip)+Number(meta?.take??PAGE_SIZE));}}/>{lookupError?<small className="record-field-error" role="alert">{lookupError}</small>:null}</>;
}
