import {requestJson} from "./api";
export const DEPOTS_CHANGED="sauverndeko:depots-changed";
export function depotQuery(values={}){return new URLSearchParams(Object.entries(values).filter(([,value])=>value!==""&&value!=null).map(([key,value])=>[key,String(value)]));}
export function depotRead(path,query={},signal){return requestJson("/api/logistique"+path+"?"+depotQuery(query),{requiresAuth:true,signal});}
export function depotWrite(path,payload,method="POST"){return requestJson("/api/logistique"+path,{requiresAuth:true,method,body:JSON.stringify(payload)});}
export function depotRecord(response){return response?.data?.record||response?.data||null;}
export function depotRevision(record,meta={}){return String(meta.revision??record?.Version??record?._version??"");}
export function depotFailure(response,fallback){const messages=[];const visit=value=>{if(typeof value==="string")messages.push(value);else if(Array.isArray(value))value.forEach(visit);else if(value&&typeof value==="object")Object.values(value).forEach(visit);};visit(response?.error?.details);return messages.length?messages.slice(0,4).join(" "):response?.message||fallback;}
export function depotUncertain(response){return !response?.status||response.status>=500||response.success===true;}
