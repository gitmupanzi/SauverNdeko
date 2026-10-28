import {requestJson} from "./api";

export const FIELD_REFERENCES_API="/api/referentiel/champs-references";
export function fieldReferencesRequest(path="",options={}) {
 return requestJson(FIELD_REFERENCES_API+path,{requiresAuth:true,...options,...(options.body?{body:JSON.stringify(options.body)}:{})});
}
export function fetchFieldValues(schema,table,column,{currentId,visibility,signal}={}) {
 const query=new URLSearchParams({schema,table,column,...(currentId?{currentId:String(currentId)}:{}),...(visibility?{visibility:JSON.stringify(visibility)}:{})});
 return fieldReferencesRequest("/valeurs?"+query,{signal});
}
export async function fetchAdminFieldReferences({signal}={}) {
 const fields={roles:["T_Utilisateurs","IdRoleFk"],entityTypes:["T_Entite","IdTypeEntiteFk"],licenseStatuses:["T_Licence","IdStatutLicenceFk"]};
 const entries=await Promise.all(Object.entries(fields).map(async([key,[table,column]])=>[key,await fetchFieldValues("systeme",table,column,{signal})]));
 return {success:entries.every(([,response])=>response?.success),options:Object.fromEntries(entries.map(([key,response])=>[key,response?.success?response.data?.options||[]:[]])),roleCategoryId:entries.find(([key])=>key==="roles")?.[1]?.data?.categoryIds?.[0]??null};
}
// Ces identités désignent les champs physiques ; aucune catégorie n'est résolue côté navigateur.
export const TERRITORIAL_REFERENCE_FIELDS={
 niveau2Types:["T_Niveau_2","ID_TypeNiveau_2_Fk"],niveau3Types:["T_Niveau_3","ID_TypeNiveau_2_Fk"],
 niveau2Statuses:["T_Niveau_2","ID_StatutNiveau_2"],niveau3Statuses:["T_Niveau_3","ID_StatutNiveau_3_Fk"],
 niveau4Types:["T_Niveau_4","ID_TypeNiveau_4_Fk"],niveau5Types:["T_Niveau_5","ID_TypeNiveau_5_Fk"],
 niveau4Statuses:["T_Niveau_4","ID_StatutNiveau_4"],niveau5Statuses:["T_Niveau_5","ID_StatutNiveau_5"],
 dpsAccessRoutes:["T_Niveau_2","ID_VoieAccesDPSANTFk"],antBczAccessRoutes:["T_Niveau_3","ID_VoieAccesANTBCZFk"],dpsBczAccessRoutes:["T_Niveau_3","ID_VoieAccesDPSBCZFk"],
 zsAsAccessRoutes:["T_Niveau_4","ID_VoieAccesZsASFk"],zsSiteAccessRoutes:["T_Niveau_5","ID_VoieAccesZsSiteFk"],roofTypes:["T_Niveau_5","ID_TypeToitFk"],
};
export async function fetchTerritorialReferences({signal}={}) {
 const physical={...TERRITORIAL_REFERENCE_FIELDS};
 for(const level of [2,3,4,5])physical["deployment"+level]=["T_Niveau_"+level,level===2?"ID_StatusDeploiFk":level===3?"ID_StatutDeploieFk":"ID_StatutDeploiementFk"];
 for(const level of [4,5])physical["network"+level]=["T_Niveau_"+level,"ID_DispoReseauNiveau_"+level];
 const entries=await Promise.all(Object.entries(physical).map(async([key,[table,column]])=>{
  const response=await fetchFieldValues("geolocalisation",table,column,{signal,visibility:key==="niveau3Types"?{VisibleNiveau_3:false}:key==="dpsAccessRoutes"?{VisibleVoie:false}:undefined});
  return [key,response];
 }));
 const failures=entries.filter(([,response])=>!response?.success);
 return {success:!failures.length,data:Object.fromEntries(entries.map(([key,response])=>[key,(response?.success?response.data?.options:[])||[]])),responses:Object.fromEntries(entries),byField:Object.fromEntries(entries.map(([key,response])=>[physical[key].join("."),response?.success?response.data:{options:[]}])),message:failures.length?"Certaines références territoriales sont indisponibles.":""};
}
