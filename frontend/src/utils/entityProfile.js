import {entityLocationValues,entityLocationErrors,entityLocationPayload} from "./entityLocations";
export const ENTITY_PROFILE_FIELDS=[
  {name:"NomEntite",label:"Nom de l’entreprise",type:"text",max:200,required:true},
  {name:"EmailEntite",label:"Adresse e-mail",type:"email",max:255},
  {name:"PhoneEntite",label:"Téléphone",type:"tel",max:20},
  {name:"PhoneSecondaireEntite",label:"Téléphone secondaire",type:"tel",max:20},
  {name:"SiteWebEntite",label:"Site web",type:"url",max:255},
  {name:"AdresseEntite",label:"Adresse",type:"textarea",max:1000},
];
export const LEGAL_ID_LABELS=["RCCM","ID national","N° d’impôt"];
export const ENTITY_LOGO_TYPES=new Set(["image/png","image/jpeg","image/webp"]);
export const ENTITY_LOGO_MAX=2*1024*1024;
const string=value=>value==null?"":String(value);
export function entityProfileValues(record=null){
  return {...Object.fromEntries(ENTITY_PROFILE_FIELDS.map(({name})=>[name,string(record?.[name])])),
    MentionDocumentaireEntite:string(record?.MentionDocumentaireEntite),
    Localisations:(record?.Localisations||[]).map(entityLocationValues),
    IdentifiantsLegauxEntite:(record?.IdentifiantsLegauxEntite||[]).map(row=>({libelle:string(row.libelle),valeur:string(row.valeur)})),
    AfficherEnteteDocument:record?.AfficherEnteteDocument??true,AfficherPiedDocument:record?.AfficherPiedDocument??true,
    IdTypeEntiteFk:string(record?.IdTypeEntiteFk),ValideEntite:record?record.ValideEntite??null:true};
}
export function entityLogoError(file){
  if(!file)return "Choisissez un logo.";
  if(!ENTITY_LOGO_TYPES.has(file.type))return "Choisissez un logo PNG, JPEG ou WebP.";
  return file.size>ENTITY_LOGO_MAX?"Le logo ne doit pas dépasser 2 Mo.":"";
}
export function entityProfileErrors(values,motif,{manageStructure=false}={}){
  const errors={};
  for(const {name,max,required} of ENTITY_PROFILE_FIELDS){const value=string(values[name]).trim();if(required&&!value)errors[name]="Renseignez ce champ.";else if(Array.from(value).length>max)errors[name]="Limitez ce champ à "+max+" caractères.";}
  if(values.EmailEntite&&!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(values.EmailEntite.trim()))errors.EmailEntite="Renseignez une adresse e-mail valide.";
  if(values.SiteWebEntite?.trim()){try{const url=new URL(values.SiteWebEntite.trim());if(!["http:","https:"].includes(url.protocol)||!url.hostname||url.username||url.password)throw new Error();}catch{errors.SiteWebEntite="Utilisez une adresse http:// ou https:// sans identifiants.";}}
  if(Array.from(string(values.MentionDocumentaireEntite)).length>1000)errors.MentionDocumentaireEntite="Limitez la mention à 1000 caractères.";
  const rows=values.IdentifiantsLegauxEntite,seen=new Set();
  if(!Array.isArray(rows)||rows.length>10)errors.IdentifiantsLegauxEntite="Ajoutez au maximum dix identifiants.";
  else for(const row of rows){const label=string(row.libelle).trim(),value=string(row.valeur).trim(),key=label.toLocaleLowerCase("fr");if(!label||!value||Array.from(label).length>60||Array.from(value).length>180){errors.IdentifiantsLegauxEntite="Renseignez chaque libellé (60 caractères maximum) et sa référence (180 maximum).";break;}if(seen.has(key)){errors.IdentifiantsLegauxEntite="Chaque libellé d’identifiant doit être unique.";break;}seen.add(key);}
  for(const name of ["AfficherEnteteDocument","AfficherPiedDocument"])if(typeof values[name]!=="boolean")errors[name]="Choisissez une option valide.";
  if(manageStructure&&values.IdTypeEntiteFk&&!/^[1-9]\d*$/.test(values.IdTypeEntiteFk))errors.IdTypeEntiteFk="Choisissez un type d’entreprise valide.";
  if(manageStructure&&values.ValideEntite!=null&&typeof values.ValideEntite!=="boolean")errors.ValideEntite="Choisissez un état valide.";
  if(!string(motif).trim())errors.motif="Précisez le motif de cette mise à jour.";
  else if(Array.from(motif.trim()).length>1000)errors.motif="Limitez le motif à 1000 caractères.";
  Object.assign(errors,entityLocationErrors(values.Localisations||[]));
  return errors;
}
export function entityProfilePayload(values,{record=null,motif,requestId,logo={file:null,remove:false},manageStructure=false,manageLocations=false}={}){
  const payload={...Object.fromEntries(ENTITY_PROFILE_FIELDS.map(({name})=>[name,string(values[name]).trim()||null])),
    MentionDocumentaireEntite:string(values.MentionDocumentaireEntite).trim()||null,
    IdentifiantsLegauxEntite:values.IdentifiantsLegauxEntite.map(row=>({libelle:row.libelle.trim(),valeur:row.valeur.trim()})),
    AfficherEnteteDocument:values.AfficherEnteteDocument,AfficherPiedDocument:values.AfficherPiedDocument,
    ...(manageLocations?{Localisations:entityLocationPayload(values.Localisations||[])}:{}),
    logoAction:logo.file?"replace":logo.remove?"remove":"keep",motif:motif.trim(),requestId};
  if(record){payload.IdEntite=record.IdEntite;payload._version=record._version;}
  if(manageStructure){if(!record||string(record.IdTypeEntiteFk)!==values.IdTypeEntiteFk)payload.IdTypeEntiteFk=values.IdTypeEntiteFk?Number(values.IdTypeEntiteFk):null;if(!record||record.ValideEntite!==values.ValideEntite)payload.ValideEntite=values.ValideEntite;}
  return payload;
}
export function entityProfileBody(payload,logoFile=null){
  if(!logoFile)return JSON.stringify(payload);
  const body=new FormData();body.set("payload",JSON.stringify(payload));body.set("logo",logoFile);return body;
}
