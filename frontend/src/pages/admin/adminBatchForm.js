import {adminEditorFields,adminEditorValues,adminEditorOptions,adminEditorErrors,buildAdminEditorPayload} from "./AdminRecordEditor";
import {parseExcelTsv,referenceBatchId,referenceDuplicateKey} from "../referentiels/referenceBatch";

export const ADMIN_BATCH_MAX=100;
export function normalizeAdminSupport(data={}){return {...data,entities:(data.entities||[]).map(row=>({...row,IdEntite:row.IdEntite??row.id,NomEntite:row.NomEntite??row.label,ValideEntite:row.ValideEntite??row.active})),categories:(data.categories||[]).map(row=>({...row,ID_CategorieGenerique:row.ID_CategorieGenerique??row.id,NomCategorieGenerique:row.NomCategorieGenerique??row.label,ValideCategorieGenerique:row.ValideCategorieGenerique??row.active??true})),referenceOptions:{...data.referenceOptions,roles:data.referenceOptions?.roles??data.roles??[]}};}
export const ADMIN_BATCH={
 utilisateurs:{type:"users",title:"Nouvel utilisateur",icon:"user",name:"EmailUser",columns:["PrenomUser","NomUser","EmailUser","IdEntiteFk","IdRoleFk","MotdepasseUser"],paste:["PrenomUser","NomUser","EmailUser","IdRoleFk","MotdepasseUser","PhoneUser"]},
 roles:{type:"roles",title:"Nouveau rôle",icon:"shield",name:"NomGenerique",columns:["NomGenerique","AbrGenerique","ObsGenerique","ValideGenerique"],paste:["NomGenerique","AbrGenerique","ObsGenerique","ValideGenerique"]},
 correspondances:{type:"fk",title:"Nouvelle correspondance",icon:"movements",name:"SourceKey",columns:["ModuleName","SourceKey","FieldName","FieldLabel","MappingType","TargetCategoryIdFk","MappingValue"],paste:["ModuleName","SchemaName","ViewName","SourceKey","FieldName","FieldLabel","MappingType","TargetCategoryIdFk","MappingValue"]},
 parametres:{type:"settings",title:"Nouveau paramètre",icon:"settings",name:"SettingKey",columns:["SettingKey","SettingLabel","SettingGroup","SettingType","SettingValue"],paste:["SettingKey","SettingLabel","SettingGroup","SettingType","SettingValue"]},
};
export function adminBatchRow(kind,support={},overrides={}){
 const fields=adminEditorFields(ADMIN_BATCH[kind].type,true),values=adminEditorValues(fields,null);
 if(kind==="utilisateurs"){values.SexeUser="";values.IdEntiteFk=String(support.entityId||"");}
 if(["correspondances","parametres"].includes(kind)&&support.entityId){values.SettingScope=kind==="correspondances"?"entity":"entite";values.ScopeValue=String(support.entityId);}
 return {clientRowId:referenceBatchId(),values:{...values,...overrides},pristine:Object.keys(overrides).length===0};
}
export function adminBatchOptions(kind,field,values,support){return adminEditorOptions(ADMIN_BATCH[kind].type,field,values,support)||[];}
export function validateAdminBatch(kind,rows,support={}){
 const header={},issues={},config=ADMIN_BATCH[kind],fields=adminEditorFields(config.type,true),seen=new Map();
 if(!rows.length||rows.length>ADMIN_BATCH_MAX)header.rows="Ajoutez de 1 à 100 lignes.";
 for(const row of rows){const errors=adminEditorErrors(config.type,fields,row.values,{},support,true,field=>adminBatchOptions(kind,field,row.values,support));
  for(const field of fields)if(field.type==="checkbox"&&typeof row.values[field.name]!=="boolean")errors[field.name]="Choisissez Oui ou Non.";
  const identity=kind==="utilisateurs"?referenceDuplicateKey(row.values.EmailUser):kind==="roles"?referenceDuplicateKey(row.values.NomGenerique):JSON.stringify((kind==="correspondances"?["ModuleName","SchemaName","ViewName","SourceKey","FieldName","MappingType","SettingScope","ScopeValue"]:["SettingKey","SettingScope","ScopeValue"]).map(key=>row.values[key]||""));
  if(identity){if(seen.has(identity)){errors[config.name]="Cette identité apparaît déjà dans le panier.";const prior=seen.get(identity);issues[prior]={...(issues[prior]||{}),[config.name]:errors[config.name]};}else seen.set(identity,row.clientRowId);}
  if(Object.keys(errors).length)issues[row.clientRowId]={...(issues[row.clientRowId]||{}),...errors};
 }
 return {header,rows:issues};
}
export function adminBatchTicket(kind,rows,support){const config=ADMIN_BATCH[kind],fields=adminEditorFields(config.type,true);return {requestId:referenceBatchId(),rows:rows.map(row=>({clientRowId:row.clientRowId,data:buildAdminEditorPayload(config.type,fields,row.values,{}, {creating:true,roleCategoryId:support.roleCategoryId})}))};}
export function adminBatchReceipt(kind,result,request){
 const key={utilisateurs:"IdUser",roles:"ID_Generique",correspondances:"IdFkCorrespondance",parametres:"IdAdminUISetting"}[kind];
 if(!key||!result||result.requestId!==request.requestId||result.count!==request.rows.length||!Array.isArray(result.records)||result.records.length!==request.rows.length)return false;
 const expected=new Set(request.rows.map(row=>row.clientRowId)),seen=new Set(),ids=new Set();
 return result.records.every(record=>{const id=String(record?.[key]??"");if(!expected.has(record?.clientRowId)||seen.has(record.clientRowId)||!/^[1-9]\d*$/.test(id)||ids.has(id))return false;seen.add(record.clientRowId);ids.add(id);return true;});
}
const normal=value=>referenceDuplicateKey(value).normalize("NFD").replace(/[\u0300-\u036f]/g,"").replace(/[^a-z0-9]/g,"");
export function adminBatchFromExcel(kind,text,support,{hasHeaders=false}={}){
 return adminBatchFromMatrix(kind,parseExcelTsv(text),support,{hasHeaders});
}
export function adminBatchFromMatrix(kind,source,support,{hasHeaders=true}={}){
 if(!Array.isArray(source)||source.some(row=>!Array.isArray(row)||row.some(value=>value!=null&&typeof value!=="string"&&typeof value!=="number"&&typeof value!=="boolean")))throw Error("Les lignes du fichier ne sont pas reconnues.");
 const matrix=source.map(row=>row.map(value=>String(value??""))),config=ADMIN_BATCH[kind],fields=adminEditorFields(config.type,true);if(!matrix.length)return [];
 let columns=config.paste;
 if(hasHeaders){columns=matrix.shift().map(label=>{const found=fields.filter(field=>normal(field.name)===normal(label)||normal(field.label)===normal(label));if(found.length!==1)throw Error("En-tête non reconnu ou ambigu : « "+label+" ».");return found[0].name;});if(new Set(columns).size!==columns.length)throw Error("Un même en-tête apparaît plusieurs fois.");if(!columns.includes(config.name))throw Error("Ajoutez la colonne « "+fields.find(field=>field.name===config.name).label+" ».");}
 if(matrix.length>ADMIN_BATCH_MAX)throw Error("Limitez le collage à 100 lignes.");
 return matrix.filter(cells=>cells.some(value=>value.trim())).map((cells,index)=>{if(cells.length>columns.length)throw Error("La ligne "+(index+1)+" contient trop de colonnes.");const row=adminBatchRow(kind,support);row.pristine=false;cells.forEach((raw,i)=>{const field=fields.find(field=>field.name===columns[i]);let value=raw;if(field.type==="checkbox"){if(!raw.trim())return;value=["oui","1","true","actif"].includes(normal(raw))?true:["non","0","false","inactif"].includes(normal(raw))?false:raw;}else if(field.type==="select"||field.name==="SettingType"){if(!raw.trim())return;const options=adminBatchOptions(kind,field,row.values,support),byId=options.filter(option=>!option.disabled&&String(option.value)===raw.trim()),found=byId.length?byId:options.filter(option=>!option.disabled&&referenceDuplicateKey(option.label)===referenceDuplicateKey(raw));if(found.length===1)value=String(found[0].value);}else if(field.type==="date"&&/^\d{4}-\d{2}-\d{2}T00:00:00$/.test(raw))value=raw.slice(0,10);row.values[field.name]=value;});return row;});
}
