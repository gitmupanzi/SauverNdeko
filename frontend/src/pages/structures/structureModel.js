export const STRUCTURES_ROOT="/api/structures";
export const SANITARY_ROOT=STRUCTURES_ROOT+"/annuaire-sanitaire";
export const EMPTY_STRUCTURE_CRITERIA={q:"",typeId:"",level:"",provinceId:"",locality:""};
export const STRUCTURE_PAGE_SIZES=[10,25,50,100];
export function structureId(record={}){return validStructureKey(record.key);}
export function structureName(record={}){return record.name||"Structure ou territoire";}
export function validStructureId(value){return /^[1-9]\d*$/.test(String(value??""))?String(value):"";}
export function validStructureKey(value){return /^n[345]:[1-9]\d*$/.test(String(value??""))?String(value):"";}
export function structureTarget(value){const key=validStructureKey(value);if(!key)return null;const [level,id]=key.slice(1).split(":");return {key,level:Number(level),id};}
export function structureLevelLabel(value){return {3:"Niveau 3",4:"Niveau 4",5:"Niveau 5 — Structures et sites"}[value]||"Structure ou territoire";}
export function structureTerritory(record={}){return [...new Set([record.area?.name,record.zone?.name,record.subdivision?.name,record.province?.name].filter(value=>value&&value!==record.name))].join(" · ");}
export function structureLocation(params){
 const criteria=Object.fromEntries(Object.keys(EMPTY_STRUCTURE_CRITERIA).map(key=>[key,params.get(key)||""])),take=Number(params.get("take")),skip=Number(params.get("skip"));
 return {criteria,grid:{take:STRUCTURE_PAGE_SIZES.includes(take)?take:25,skip:Number.isSafeInteger(skip)&&skip>=0?skip:0,sortBy:params.get("sortBy")==="type"?"type":"name",sortDir:params.get("sortDir")==="desc"?"desc":"asc"},focusKey:validStructureKey(params.get("structure")),invalidFocus:Boolean(params.get("structure")&&!validStructureKey(params.get("structure")))};
}
export function structureQuery(criteria,grid){const query=new URLSearchParams();for(const [key,value] of Object.entries({...criteria,...grid}))if(value!==""&&value!=null)query.set(key,String(value));return query;}
export function structureParams(params,criteria,grid){const next=new URLSearchParams(params);for(const key of [...Object.keys(EMPTY_STRUCTURE_CRITERIA),"take","skip","sortBy","sortDir"])next.delete(key);for(const [key,value] of structureQuery(criteria,grid))next.set(key,value);return next;}
export function structureSearchError(criteria){return [criteria.q,criteria.locality].some(value=>Array.from(value||"").length>200)?"Limitez la recherche et la localité à 200 caractères chacune.":"";}
export function structureOptions(items=[],value="",allLabel="Tous les types"){
 const options=[{value:"",label:allLabel},...items.map(item=>({value:String(item.id),label:String(item.label||item.id),disabled:item.disabled===true}))];
 return value&&!options.some(item=>item.value===value)?[...options,{value,label:"Valeur sélectionnée indisponible",disabled:true}]:options;
}
export function structureError(response,fallback){return response?.status===403?"Votre accès ne permet pas de consulter ces informations.":response?.status===401?"Reconnectez-vous pour poursuivre.":response?.status===404?"Cette structure n’est plus disponible dans l’annuaire.":response?.message||fallback;}
export function structureRows(response,idKey="id"){
 const data=response?.data;
 if(!response?.success||!Array.isArray(data?.rows)||data.total==null||!Number.isSafeInteger(Number(data.total))||Number(data.total)<data.rows.length||!data.rows.every(row=>validStructureId(row?.[idKey]))||new Set(data.rows.map(row=>String(row[idKey]))).size!==data.rows.length)return null;
 return {rows:data.rows,total:Number(data.total)};
}
export function structureReferences(response){const data=response?.data;return response?.success&&Array.isArray(data?.types)?data:null;}
export function sanitaryReferences(response){const data=structureReferences(response);return data&&Array.isArray(data.levels)&&Array.isArray(data.provinces)&&typeof data.canManageTerritories==="boolean"?data:null;}
export function sanitaryRecord(record){const target=structureTarget(record?.key);return Boolean(target&&String(record.level)===String(target.level)&&String(record.id)===target.id&&typeof record.contactsPublished==="boolean");}
export function sanitaryRows(response){const data=response?.data;if(!response?.success||!Array.isArray(data?.rows)||data.total==null||!Number.isSafeInteger(Number(data.total))||Number(data.total)<data.rows.length||!data.rows.every(sanitaryRecord)||new Set(data.rows.map(structureId)).size!==data.rows.length)return null;return {rows:data.rows,total:Number(data.total)};}
export function structureDetail(response,key){return response?.success&&sanitaryRecord(response.data?.record)&&response.data.record.key===key?response.data:null;}
export function structureLastPage(total,take){return total?Math.floor((total-1)/take)*take:0;}
export function structureWebsite(value){try{const url=new URL(String(value||""));return ["https:","http:"].includes(url.protocol)&&!url.username&&!url.password?url.href:"";}catch{return "";}}
export function structureInitials(name){return String(name||"Structure").trim().split(/\s+/).slice(0,2).map(part=>part[0]).join("").toLocaleUpperCase("fr");}
