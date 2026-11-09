import {API_BASE_URL,requestJson} from "./api";
import {getAccessToken} from "./authStorage";
import {captureEntityScope,entityScopeIsCurrent} from "./entityScope";
import {ENTITY_LOGO_TYPES,ENTITY_LOGO_MAX} from "../utils/entityProfile";

export function entityProfilePath(context,recordId){
  if(context==="settings")return "/api/parametres/profil";
  if(context==="structures")return "/api/structures/profils/"+encodeURIComponent(recordId);
  return context==="admin"?"/api/systeme/entites"+(recordId==null?"":"/"+encodeURIComponent(recordId)):"/api/logistique/entreprise/identite";
}
export function loadEntityProfile(context,recordId,signal){return requestJson(context==="admin"&&recordId==null?"/api/systeme/entites/identite-defaut":entityProfilePath(context,recordId),{requiresAuth:true,signal});}
export function saveEntityProfile(context,recordId,body){return requestJson(entityProfilePath(context,recordId),{requiresAuth:true,method:context==="admin"&&recordId==null?"POST":"PUT",body});}
export async function fetchEntityLogo(record,{signal}={}){
  if(!/^[1-9]\d*$/.test(String(record?.IdEntite)))throw new Error("L’entreprise du logo n’est pas disponible.");
  const provided=String(record?.logoUrl||""),allowed=["/api/parametres/entreprises/"+record.IdEntite+"/logo","/api/structures/profils/"+record.IdEntite+"/logo"],route=allowed.includes(provided)?provided:"/api/systeme/entites/"+record.IdEntite+"/logo",context=captureEntityScope(route),token=getAccessToken();
  const response=await fetch(API_BASE_URL+route,{headers:{Accept:"image/png, application/json;q=0.9",...(token?{Authorization:"Bearer "+token}: {}),...context.headers},signal,cache:"no-store"});
  if(!entityScopeIsCurrent(context)||token!==getAccessToken())throw new DOMException("Contexte modifié","AbortError");
  if(!response.ok)throw new Error("Le logo n’a pas pu être chargé.");
  const blob=await response.blob();
  if(!entityScopeIsCurrent(context)||token!==getAccessToken())throw new DOMException("Contexte modifié","AbortError");
  if(!ENTITY_LOGO_TYPES.has(blob.type)||blob.size>ENTITY_LOGO_MAX)throw new Error("Le logo reçu n’est pas dans un format pris en charge.");
  return blob;
}
