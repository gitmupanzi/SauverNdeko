import {useEffect,useState} from "react";
import {API_BASE_URL} from "../../services/api";
import {getAccessToken} from "../../services/authStorage";
import {ENTITY_LOGO_MAX,ENTITY_LOGO_TYPES} from "../../utils/entityProfile";
import {structureInitials,validStructureId} from "./structureModel";

export default function StructureLogo({record,owner="",className=""}){
 const [image,setImage]=useState({key:"",url:""}),[failed,setFailed]=useState(""),id=validStructureId(record?.id),source=String(record?.logoUrl||""),key=owner+":"+id+":"+source;
 const allowed=id&&new RegExp("^/api/structures/annuaire/"+id+"/logo(?:\\?v=[a-f0-9]{16,64})?$").test(source);
 useEffect(()=>{
  if(!allowed)return;const token=getAccessToken();if(!token)return;
  let active=true,url="";const controller=new AbortController();
  fetch(API_BASE_URL+source,{signal:controller.signal,cache:"no-store",headers:{Accept:"image/png,image/jpeg,image/webp",Authorization:"Bearer "+token}}).then(async response=>{
   if(!response.ok)return;const blob=await response.blob();if(!active||token!==getAccessToken()||!ENTITY_LOGO_TYPES.has(blob.type)||blob.size>ENTITY_LOGO_MAX)return;
   url=URL.createObjectURL(blob);setImage({key,url});
  }).catch(()=>{});
  return()=>{active=false;controller.abort();if(url)URL.revokeObjectURL(url);};
 },[key,allowed]);
 return <span className={"structure-logo "+className}>{image.key===key&&image.url&&failed!==key?<img src={image.url} alt="" onError={()=>setFailed(key)}/>:<span aria-hidden="true">{structureInitials(record?.name)}</span>}</span>;
}
