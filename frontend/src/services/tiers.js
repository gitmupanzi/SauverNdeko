import {requestJson} from "./api";
export const TIERS_CHANGED="sauverndeko.tiers.changed";
export function tiersChanged(){window.dispatchEvent(new Event(TIERS_CHANGED));}
export function tiersRequest(path="",options={}){return requestJson("/api/logistique/tiers"+path,{requiresAuth:true,...options,...(options.body?{body:JSON.stringify(options.body)}:{})});}
export const tiersRecord=payload=>payload?.data?.record||payload?.data?.tiers||payload?.data;
export const tiersRows=payload=>Array.isArray(payload?.data)?payload.data:Array.isArray(payload?.data?.items)?payload.data.items:[];
export const natureLabel=value=>({personne:"Personne",entreprise:"Entreprise"})[value]||"—";
export const tiersOptions=items=>(items||[]).map(item=>({value:String(item.id??item.ID_Client),label:item.label??item.Nom}));
export const optionalOptions=items=>[{value:"",label:"Non renseigné"},...tiersOptions(items)];
