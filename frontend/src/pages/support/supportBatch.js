import {SUPPORT_FIELDS,supportInitial,supportValidation,supportOptions,supportPayload} from "./supportForm";

export const SUPPORT_BATCH_MAX=100;
const normalized=value=>String(value??"").normalize("NFKC").trim().replace(/\s+/g," ").toLocaleLowerCase("fr");
export function supportBatchDateValid(value){
 const match=/^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})(?::(\d{2})(?:\.\d+)?)?(Z|[+-]\d{2}:\d{2})?$/.exec(String(value));
 if(!match||Number(match[1])<1)return false;
 const base=new Date(match[1]+"-"+match[2]+"-"+match[3]+"T"+match[4]+":"+match[5]+":"+(match[6]||"00")+"Z");
 return !Number.isNaN(base.getTime())&&base.getUTCFullYear()===Number(match[1])&&base.getUTCMonth()+1===Number(match[2])&&base.getUTCDate()===Number(match[3])&&base.getUTCHours()===Number(match[4])&&base.getUTCMinutes()===Number(match[5])&&base.getUTCSeconds()===Number(match[6]||0)&&(!match[7]||!Number.isNaN(new Date(String(value)).getTime()));
}
export function supportExcelRows(matrix,context={},makeId=()=>crypto.randomUUID()){
 if(!Array.isArray(matrix)||!Array.isArray(matrix[0]))throw new Error("Le fichier ne contient pas de colonnes reconnues.");
 const keys=matrix[0],allowed=new Set(SUPPORT_FIELDS.map(field=>field.key));
 if(!keys.length||keys.some(key=>!allowed.has(key))||new Set(keys).size!==keys.length)throw new Error("Les colonnes du fichier ne sont pas reconnues.");
 const raw=matrix.slice(1).filter(row=>Array.isArray(row)&&row.some(value=>String(value??"").trim()));
 if(!raw.length||raw.length>SUPPORT_BATCH_MAX)throw new Error("Le panier attend de 1 à 100 dossiers.");
 return raw.map(row=>{const source={...context.defaults,...Object.fromEntries(keys.map((key,index)=>[key,row[index]??""]))},data=supportInitial(source);if(source.DateEcheance&&!supportBatchDateValid(source.DateEcheance))data.DateEcheance=String(source.DateEcheance);for(const field of SUPPORT_FIELDS){if(!field.source||!data[field.key])continue;const choices=supportOptions(context,field).filter(option=>!option.disabled),value=data[field.key].trim();if(choices.some(option=>String(option.value)===value)){data[field.key]=value;continue;}const matching=choices.filter(option=>normalized(option.label)===normalized(value));if(matching.length===1)data[field.key]=String(matching[0].value);}return {clientRowId:makeId(),data};});
}
export function supportBatchValidation(rows,context={}){
 const errors={};
 for(const row of rows){const fields=supportValidation(row.data,context.requiredFields||[]);if(row.data.DateEcheance&&!supportBatchDateValid(row.data.DateEcheance))fields.DateEcheance="Vérifiez la date et l’heure.";for(const field of SUPPORT_FIELDS){const value=row.data[field.key];if(field.source&&value&&!supportOptions(context,field).some(option=>String(option.value)===String(value)&&!option.disabled))fields[field.key]="Sélectionnez une valeur disponible pour cette entreprise.";}if(Object.keys(fields).length)errors[row.clientRowId]=fields;}
 return errors;
}
export function supportBatchPayload(rows,requestId){return {requestId,rows:rows.map(row=>{const {requestId:ignored,...data}=supportPayload(row.data,null,requestId);return {clientRowId:row.clientRowId,data};})};}
