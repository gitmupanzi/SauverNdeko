import {EXPERT_FIELDS,expertValues,expertErrors,expertPayload,expertOptions} from "./expertModel";
import {validCommandeDate} from "../logistique/commandeForm";

export const EXPERT_BATCH_MAX=100;
export const EXPERT_BATCH_FIELDS=[
 {key:"IdUserFk",label:"Utilisateur",source:"users",required:true},
 {key:"IdSecteurFk",label:"Secteur",source:"secteurs",required:true},
 {key:"IdTypeProfessionnelFk",label:"Profession",source:"types",required:true},
 {key:"IdSpecialiteFk",label:"Spécialité",source:"specialites"},
 {key:"TitrePublic",label:"Titre professionnel",required:true,max:180},
 {key:"PresentationPublique",label:"Présentation",area:true,max:10000},
 {key:"LocalitePublique",label:"Localité ou zone d’intervention",max:255},
 {key:"ExperienceAns",label:"Années d’expérience",type:"number"},
 {key:"NumeroIdentification",label:"Identification professionnelle",max:50},
 {key:"ObsProfessionnel",label:"Observations internes",area:true,max:5000},
];
const canonical=value=>String(value??"").normalize("NFKC").trim().replace(/\s+/g," ").toLocaleLowerCase("fr");
const enabled=option=>!option.disabled&&!option.incompatible;
const allowedKeys=new Set([...EXPERT_FIELDS,"competenceIds","prestationIds"]);
export function expertBatchOptions(refs,source){return expertOptions(refs?.[source]||[]).map(item=>({...item,disabled:item.disabled||item.incompatible}));}
function resolve(value,options){
 const raw=String(value??"").trim();if(!raw)return "";
 const available=options.filter(enabled);
 if(available.some(option=>option.value===raw))return raw;
 const matches=available.filter(option=>canonical(option.label)===canonical(raw));
 return matches.length===1?matches[0].value:raw;
}
export function expertExcelRows(matrix,refs={},makeId=()=>crypto.randomUUID()){
 if(!Array.isArray(matrix)||!Array.isArray(matrix[0]))throw new Error("Le fichier ne contient pas de colonnes reconnues.");
 const keys=matrix[0];if(!keys.length||keys.some(key=>!allowedKeys.has(key))||new Set(keys).size!==keys.length)throw new Error("Les colonnes du fichier ne sont pas reconnues.");
 const lines=matrix.slice(1).filter(row=>Array.isArray(row)&&row.some(value=>String(value??"").trim()));
 if(!lines.length||lines.length>EXPERT_BATCH_MAX)throw new Error("Le panier attend de 1 à 100 profils.");
 return lines.map(line=>{
  const raw=Object.fromEntries(keys.map((key,index)=>[key,line[index]??""])),values=expertValues();
  for(const key of EXPERT_FIELDS)if(key in raw&&key!=="ContactAutorise")values[key]=String(raw[key]??"");
  const contact=canonical(raw.ContactAutorise);
  values.ContactAutorise=!["","oui","true","1","non","false","0"].includes(contact)?String(raw.ContactAutorise):!["non","false","0"].includes(contact);
  for(const field of EXPERT_BATCH_FIELDS.filter(item=>item.source))values[field.key]=resolve(values[field.key],expertBatchOptions(refs,field.source));
  for(const [key,source]of [["competenceIds","competences"],["prestationIds","prestations"]])values[key]=String(raw[key]??"").split(";").map(value=>value.trim()).filter(Boolean).map(value=>resolve(value,expertBatchOptions(refs,source)));
  return {clientRowId:makeId(),values};
 });
}
export function expertBatchValidation(rows,refs={}){
 const all={},users=new Map();
 for(const row of rows){
  const values=row.values,issues=expertErrors(values);
  for(const field of EXPERT_BATCH_FIELDS.filter(item=>item.source))if(values[field.key]&&!expertBatchOptions(refs,field.source).some(option=>enabled(option)&&option.value===String(values[field.key])))issues[field.key]="Sélectionnez une valeur disponible pour cette entreprise.";
  if(typeof values.ContactAutorise!=="boolean")issues.ContactAutorise="Choisissez Oui ou Non.";
  for(const [key,source]of [["competenceIds","competences"],["prestationIds","prestations"]])if(values[key].some(value=>!expertBatchOptions(refs,source).some(option=>enabled(option)&&option.value===String(value))))issues[key]="Retirez ou remplacez les valeurs indisponibles.";
  if(values.affiliations.some(item=>!expertBatchOptions(refs,"entities").some(option=>enabled(option)&&option.value===String(item.IdEntiteFk))||item.IdTypeLienFk&&!expertBatchOptions(refs,"typesLiens").some(option=>enabled(option)&&option.value===String(item.IdTypeLienFk))||[item.DateDebut,item.DateFin].some(date=>date&&!validCommandeDate(date))))issues.affiliations="Vérifiez les structures, leurs types et leurs dates.";
  const user=String(values.IdUserFk||"").trim();if(user){if(!users.has(user))users.set(user,[]);users.get(user).push(row.clientRowId);}
  if(Object.keys(issues).length)all[row.clientRowId]=issues;
 }
 for(const ids of users.values())if(ids.length>1)for(const id of ids)all[id]={...all[id],IdUserFk:"Ce compte figure déjà dans le panier. Un seul profil par utilisateur."};
 return all;
}
export function expertBatchPayload(rows,requestId){return {requestId,rows:rows.map(row=>{const {requestId:ignored,...payload}=expertPayload(row.values);return {clientRowId:row.clientRowId,...payload};})};}
export function expertBatchReceipt(result,request){
 if(!result||result.requestId!==request.requestId||result.count!==request.rows.length||!Array.isArray(result.records)||result.records.length!==request.rows.length)return false;
 const expected=new Set(request.rows.map(row=>row.clientRowId)),seen=new Set(),ids=new Set();
 return result.records.every(record=>{const id=String(record?.id??"");if(!expected.has(record?.clientRowId)||seen.has(record.clientRowId)||!/^[1-9]\d*$/.test(id)||ids.has(id))return false;seen.add(record.clientRowId);ids.add(id);return true;});
}
