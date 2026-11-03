import {useEffect,useState} from "react";
import {API_BASE_URL} from "../../services/api";
import {getAccessToken} from "../../services/authStorage";
import {captureEntityScope,entityScopeIsCurrent} from "../../services/entityScope";
import {useEntityScope} from "../../contexts/EntityScopeContext";
export default function ExpertAvatar({record, className=""}) {
  const [failed,setFailed]=useState(""),[image,setImage]=useState({key:"",url:""}),scope=useEntityScope();
  const name=record.fullName || [record.PrenomUser,record.NomUser].filter(Boolean).join(" ") || "Professionnel";
  const initials=name.trim().split(/\s+/).slice(0,2).map(part=>part[0]).join("").toLocaleUpperCase("fr");
  const source=String(record.photo || "");
  const protectedPhoto=/^\/api\/professionnels\/(?:annuaire|profils)\/[1-9]\d*\/photo(?:\?v=[a-f0-9]{16})?$/.test(source),key=scope.scopeKey+":"+source;
  useEffect(()=>{if(!protectedPhoto)return;const controller=new AbortController(),snapshot=captureEntityScope(source);let url="";const token=getAccessToken();if(!token)return;fetch(API_BASE_URL+source,{signal:controller.signal,cache:"no-store",headers:{Accept:"image/jpeg,image/png,image/webp",Authorization:"Bearer "+token,...snapshot.headers}}).then(async response=>{if(!response.ok)throw Error("Photo indisponible");const blob=await response.blob();if(controller.signal.aborted||!entityScopeIsCurrent(snapshot))return;url=URL.createObjectURL(blob);setImage({key,url});}).catch(error=>{if(error.name!=="AbortError")setFailed(key);});return()=>{controller.abort();if(url)URL.revokeObjectURL(url);};},[key,protectedPhoto]);
  const safe=source && !source.includes("illustration-experts") && (/^\/(?!\/|api\/|SauverNdeko\/)/.test(source) || /^https:\/\//.test(source)),url=protectedPhoto?(image.key===key?image.url:""):safe?source:"";
  return <span className={"expert-avatar "+className}>{url && failed!==key ? <img src={url} alt="" referrerPolicy="no-referrer" onError={()=>setFailed(key)}/> : <span aria-hidden="true">{initials}</span>}</span>;
}
