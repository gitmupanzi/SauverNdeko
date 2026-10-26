import {useEffect,useRef,useState} from "react";
import SearchSelect from "./SearchSelect";
import {requestJson} from "../services/api";
import {asArrayPayload} from "../pages/logistique/logistiqueShared";

// Recherche distante bornée : les entreprises ayant beaucoup d’articles ne chargent pas leur catalogue entier.
export default function RemoteArticleSelect({id,label="Article",value,onChange,scopeKey,disabled=false}){
 const [search,setSearch]=useState(""),[query,setQuery]=useState(""),[skip,setSkip]=useState(0),[rows,setRows]=useState([]),[total,setTotal]=useState(0),[loading,setLoading]=useState(false),[error,setError]=useState(""),[revision,setRevision]=useState(0),[selected,setSelected]=useState(null);
 const context=useRef(scopeKey);context.current=scopeKey;
 useEffect(()=>{const timer=setTimeout(()=>{setQuery(search.trim());setSkip(0);},220);return()=>clearTimeout(timer);},[search]);
 useEffect(()=>{setSearch("");setQuery("");setSkip(0);setRows([]);setSelected(null);},[scopeKey]);
 useEffect(()=>{let live=true;const key=scopeKey;setLoading(true);setError("");const params=new URLSearchParams({q:query,take:25,skip,sortBy:"NomArticle",sortDir:"asc"});requestJson("/api/logistique/registre/articles?"+params,{requiresAuth:true}).then(response=>{if(!live||context.current!==key)return;setLoading(false);if(!response?.success){setError(response?.message||"Les articles ne sont pas disponibles.");if(!skip)setRows([]);return;}const list=asArrayPayload(response);setRows(previous=>skip?[...previous,...list.filter(row=>!previous.some(item=>item.ID_Article===row.ID_Article))]:list);setTotal(response.meta?.filteredCount??0);});return()=>{live=false;};},[query,skip,scopeKey,revision]);
 const options=[{value:"",label:"Tous les articles"},...rows.map(row=>({value:String(row.ID_Article),label:[row.NomArticle,row.CodeArticleInterne||row.RefArticle].filter(Boolean).join(" · ")}))];
 if(value&&!options.some(option=>option.value===String(value)))options.push(selected?.value===String(value)?selected:{value:String(value),label:"Article sélectionné"});
 return <SearchSelect id={id} label={label} value={value} onChange={next=>{setSelected(options.find(option=>option.value===next));onChange(next);}} options={options} disabled={disabled} remote onSearchChange={setSearch} onLoadMore={()=>setSkip(current=>current+25)} hasMore={rows.length<total} optionsLoading={loading&&skip===0} moreLoading={loading&&skip>0} optionsError={error} onOptionsRetry={()=>setRevision(current=>current+1)}/>;
}
