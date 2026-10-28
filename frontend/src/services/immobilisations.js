import {requestJson} from "./api";

export const IMMOBILISATIONS_API="/api/logistique/immobilisations";
export function immobilisationsRequest(path="",options={}){
  return requestJson(IMMOBILISATIONS_API+path,{requiresAuth:true,...options,...(options.body?{body:JSON.stringify(options.body)}:{})});
}
export const immobilisationPdf=id=>({label:"Fiche PDF",url:"/api/logistique/documents/immobilisation/"+encodeURIComponent(id)+"/fiche.pdf"});
export const immobilisationRecord=response=>response?.data&&typeof response.data==="object"&&!Array.isArray(response.data)?response.data:null;
