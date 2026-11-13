import {TERRITORY_PUBLICATION_FIELD,territoryFields} from "./territorialDefinitions";
import {referenceOptions,retainReference} from "../../utils/referenceOptions";

export const OPTIONAL_BOOLEAN=[{value:"",label:"Non renseigné"},{value:"true",label:"Oui"},{value:"false",label:"Non"}];
export function territoryPublicationChoices(support,creating){
 const label=support?.publicationDefault===false?"Non":"Oui";
 return creating?[{value:"",label:"Par défaut · "+label},...OPTIONAL_BOOLEAN.slice(1)]:OPTIONAL_BOOLEAN.slice(1);
}
export function territoryTypeReference(kind,support){
 const field=territoryFields(kind).find(item=>/^niveau[345]Types$/.test(item.optionsSource||""));
 if(!field||!support)return null;
 const reference=support.fieldReferences?.[field.name],options=referenceOptions(support.options?.[field.optionsSource]||[]),declared=reference?.availableCount;
 const availableCount=Number.isSafeInteger(declared)&&declared>=0?declared:options.filter(item=>!item.disabled).length;
 return {field,availableCount,message:availableCount?"":reference?.choiceMessage||"Aucun type activé pour ce niveau. Vérifiez les valeurs autorisées dans Réglages des références."};
}
export function territoryOptions(field,support,values={},record={}){
 const source=support?.options?.[field.optionsSource]||[];
 const options=referenceOptions(source);
 const parentName={niveaux1:"ID_Niveau_0_Fk",niveaux2:"ID_Niveau_1_FK",niveaux3:"ID_Niveau_2_FK",niveaux4:"ID_Niveau_3_Fk"}[field.optionsSource];
 const parent=parentName&&values[parentName];
 const filtered=parent?options.filter(option=>{const candidate=option.parentId??option.parent??option[parentName];return candidate==null||String(candidate)===String(parent);}):options;
 return retainReference(filtered,values[field.name],support?.currentLabels?.[field.name]||record?.[field.name+"Label"]||"Valeur actuelle · "+values[field.name]);
}
export function territoryErrors(kind,values,baseline,support){
 const errors={};
 territoryFields(kind).forEach(field=>{
  const value=String(values[field.name]??"").trim(),changed=!baseline||values[field.name]!==baseline[field.name];
  if(!changed)return;
  if(field.required&&!value){errors[field.name]="Renseignez ce champ.";return;}
  if(!value)return;
  if(field.type==="select"&&!territoryOptions(field,support,values).some(item=>item.value===value&&!item.disabled))errors[field.name]="Choisissez une valeur autorisée.";
  if(field.type==="checkbox"&&!["true","false"].includes(value))errors[field.name]="Choisissez Oui ou Non.";
  if(field.max&&Array.from(value).length>field.max)errors[field.name]="Limitez ce champ à "+field.max+" caractères.";
  if(["tel","email","url"].includes(field.type)&&/[\u0000-\u001f\u007f]/.test(value))errors[field.name]="Utilisez une seule ligne sans caractère de contrôle.";
  if(field.type==="email"&&!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value))errors[field.name]="Renseignez une adresse e-mail valide.";
  if(field.type==="url"){try{const url=new URL(value);if(!["http:","https:"].includes(url.protocol)||!url.hostname||url.username||url.password)throw Error();}catch{errors[field.name]="Utilisez une adresse http:// ou https:// sans identifiants.";}}
  if(field.type==="number"){
   if(!/^-?(?:\d+(?:[.,]\d*)?|[.,]\d+)$/.test(value))errors[field.name]="Renseignez un nombre valide.";
   else{const normalized=value.replace(",","."),number=Number(normalized);if(!Number.isFinite(number))errors[field.name]="Ce nombre est trop grand.";else if(/^Population/.test(field.name)&&normalized.includes(".")&&!/^0*$/.test(normalized.split(".")[1]))errors[field.name]="Renseignez une population entière.";else if(field.min!=null&&number<Number(field.min))errors[field.name]="La valeur doit être positive ou nulle.";else if(/^Latitude/.test(field.name)&&Math.abs(number)>90||/^Longitude/.test(field.name)&&Math.abs(number)>180)errors[field.name]="Vérifiez cette coordonnée géographique.";}
  }
  if(!field.max&&field.type!=="textarea"&&value.length>1000)errors[field.name]="Utilisez un texte plus court.";
 });
 if(kind==="niveaux5"&&!values.ID_Niveau_4_Fk&&!values.ID_Niveau_3_Fk&&(!baseline||values.ID_Niveau_4_Fk!==baseline.ID_Niveau_4_Fk||values.ID_Niveau_3_Fk!==baseline.ID_Niveau_3_Fk))errors.ID_Niveau_3_Fk="Choisissez une zone ou une aire de rattachement.";
 if(/^niveaux[1-5]$/.test(kind)){const n=kind.at(-1),lat="LatitudeNiveau_"+n,lon="LongitudeNiveau_"+n;if((!baseline||values[lat]!==baseline[lat]||values[lon]!==baseline[lon])&&Boolean(values[lat])!==Boolean(values[lon]))errors[lat]="Renseignez ensemble latitude et longitude.";}
 return errors;
}
export function territoryPayload(kind,values,baseline){
 const result={};territoryFields(kind).forEach(field=>{if(baseline&&values[field.name]===baseline[field.name])return;const value=String(values[field.name]??"").trim();if(field.name===TERRITORY_PUBLICATION_FIELD&&value==="")return;result[field.name]=value===""?null:field.type==="checkbox"?value==="true":field.type==="select"?Number(value):field.type==="number"?value.replace(",","."):value;});return result;
}
