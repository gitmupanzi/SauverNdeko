import { useEffect, useState } from "react";
import { API_BASE_URL } from "../services/api";
import { getAccessToken } from "../services/authStorage";
import "./UserAvatar.css";

export default function UserAvatar({user,photo,className="",onError,decorative=false}){
  const source=String(photo===undefined?user?.UrlPhoto||'':photo||'').trim();
  const privatePhoto=/^Profils\/[0-9]+_[a-f0-9]{32}\.jpg$/.test(source);
  const [image,setImage]=useState({key:'',url:''}),[failed,setFailed]=useState('');
  const name=[user?.PrenomUser,user?.NomUser].filter(Boolean).join(' ')||'Mon compte';
  const initials=[user?.PrenomUser,user?.NomUser].map(value=>String(value||'').trim().charAt(0)).join('').toLocaleUpperCase('fr')||'SN';
  const key=String(user?.IdUser||'')+':'+source;
  useEffect(()=>{
    if(!privatePhoto)return;
    const controller=new AbortController();let objectUrl='';
    const token=getAccessToken();if(!token)return;
    fetch(API_BASE_URL+'/SauverNdeko/auth/me/photo?version='+encodeURIComponent(source),{headers:{Authorization:'Bearer '+token,Accept:'image/jpeg'},signal:controller.signal,cache:'no-store'}).then(async response=>{
      if(!response.ok)throw new Error('Photo indisponible');
      const blob=await response.blob();if(controller.signal.aborted)return;
      objectUrl=URL.createObjectURL(blob);setImage({key,url:objectUrl});
    }).catch(error=>{if(error.name!=='AbortError')setFailed(key);});
    return()=>{controller.abort();if(objectUrl)URL.revokeObjectURL(objectUrl);};
  },[key,source,privatePhoto]);
  let url=privatePhoto?(image.key===key?image.url:''):'';
  if(!privatePhoto&&source){try{const parsed=new URL(source,window.location.origin);if((['http:','https:'].includes(parsed.protocol)&&!parsed.username&&!parsed.password)||source.startsWith('blob:'))url=source;}catch{/* Initiales si l’adresse n’est pas affichable. */}}
  return <span className={'user-avatar '+className} aria-hidden={decorative||undefined}>{url&&failed!==key?<img src={url} alt={decorative?'':'Photo de '+name} referrerPolicy="no-referrer" onError={()=>{setFailed(key);onError?.();}}/>:<span role={decorative?undefined:'img'} aria-label={decorative?undefined:'Avatar de '+name}>{initials}</span>}</span>;
}
