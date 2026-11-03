import {commandeDateInput,validCommandeDate} from "../logistique/commandeForm";
export const EXPERT_ROOT = "/api/professionnels";
export const EXPERT_LIMITS={TitrePublic:180,PresentationPublique:10000,LocalitePublique:255,NumeroIdentification:50,ObsProfessionnel:5000};
export const EXPERT_FIELDS = ["IdUserFk", "IdTypeProfessionnelFk", "IdSpecialiteFk", "IdSecteurFk", "TitrePublic", "PresentationPublique", "LocalitePublique", "ExperienceAns", "NumeroIdentification", "ObsProfessionnel", "ContactAutorise"];
export function expertOptions(items = [], emptyLabel = "Choisir…") {
  return [{value:"", label:emptyLabel}, ...items.map(item => ({value:String(item.id), label:item.label || item.name || String(item.id), disabled:item.disabled === true, incompatible:item.incompatible === true}))];
}
export function expertQuery(criteria = {}, grid = {}) {
  const query = new URLSearchParams();
  for (const [key, value] of Object.entries({...criteria, ...grid})) if (key!=="state" && value !== "" && value != null) query.set(key, String(value));
  if(criteria.state==="published"){query.set("published","true");query.set("active","true");}
  if(criteria.state==="draft"){query.set("published","false");query.set("active","true");}
  if(criteria.state==="archived")query.set("active","false");
  return query;
}
export function expertName(record = {}) { return record.fullName || record.NomComplet || [record.PrenomUser, record.NomUser].filter(Boolean).join(" ") || "Professionnel"; }
export function expertId(record = {}) { return record.id ?? record.IdProfessionnel; }
export function expertLabels(items = []) { return items.map(item => item.label || item.name || item.NomGenerique).filter(Boolean); }
export function expertPublicationMissing(record={}){
 return [{key:"IdSecteurFk",label:"secteur"},{key:"TitrePublic",label:"titre professionnel"},{key:"PresentationPublique",label:"présentation"}].filter(field=>!String(record[field.key]||"").trim()).map(field=>field.label);
}
export function expertValues(record) {
  const values = Object.fromEntries(EXPERT_FIELDS.map(key => [key, record?.[key] == null ? "" : String(record[key])]));
  values.ContactAutorise = record?.ContactAutorise !== false;
  return {...values, competenceIds:(record?.competenceIds || record?.Competences || record?.skills || []).map(item=>String(item.id ?? item.ID_Generique ?? item)), prestationIds:(record?.prestationIds || record?.Prestations || record?.services || []).map(item=>String(item.id ?? item.ID_Generique ?? item)), affiliations:(record?.affiliations || record?.Affiliations || []).map(item=>({IdEntiteFk:String(item.IdEntiteFk || item.id || ""), IdTypeLienFk:String(item.IdTypeLienFk || ""), DateDebut:commandeDateInput(item.DateDebut), DateFin:commandeDateInput(item.DateFin), _originalDates:{DateDebut:item.DateDebut||null,DateFin:item.DateFin||null}, EstPrincipal:item.EstPrincipal === true, ObsLien:item.ObsLien || ""})), motif:""};
}
export function expertErrors(values, edit = false) {
  const errors = {};
  for (const key of ["IdUserFk", "IdSecteurFk", "IdTypeProfessionnelFk"]) if (!/^[1-9]\d*$/.test(String(values[key] || ""))) errors[key] = "Choisissez une valeur.";
  if (!values.TitrePublic.trim()) errors.TitrePublic = "Renseignez le titre professionnel.";
  for(const [key,max] of Object.entries(EXPERT_LIMITS))if(Array.from(values[key]||"").length>max)errors[key]=`Limitez ce champ à ${max} caractères.`;
  if (values.ExperienceAns !== "" && (!/^\d+$/.test(values.ExperienceAns) || Number(values.ExperienceAns) > 100)) errors.ExperienceAns = "Indiquez un nombre d’années entre 0 et 100.";
  if (edit && !values.motif.trim()) errors.motif = "Précisez le motif de la modification.";
  if (new Set(values.competenceIds).size !== values.competenceIds.length) errors.competenceIds = "Cette compétence est déjà ajoutée.";
  if (new Set(values.prestationIds).size !== values.prestationIds.length) errors.prestationIds = "Cette prestation est déjà ajoutée.";
  if (values.affiliations.filter(item=>item.EstPrincipal).length > 1) errors.affiliations = "Choisissez une seule structure principale.";
  if (values.affiliations.some(item=>!item.IdEntiteFk || (item.DateFin && item.DateDebut && item.DateFin <= item.DateDebut))) errors.affiliations = "Vérifiez la structure et les dates de chaque rattachement.";
  if(new Set(values.affiliations.map(item=>item.IdEntiteFk)).size!==values.affiliations.length)errors.affiliations="Cette structure est déjà ajoutée.";
  if(values.affiliations.some(item=>Array.from(item.ObsLien||"").length>2000))errors.affiliations="Limitez les observations du rattachement à 2 000 caractères.";
  if (values.affiliations.some(item=>[item.DateDebut,item.DateFin].some(value=>value&&!validCommandeDate(value))))errors.affiliations="Renseignez une date et une heure valides.";
  return errors;
}
export function expertPayload(values, {version, requestId, edit = false,photoDataUrl=null,removePhoto=false} = {}) {
  const data = Object.fromEntries(EXPERT_FIELDS.map(key => [key, key === "ContactAutorise" ? values[key] === true : values[key] === "" ? null : values[key].trim()]));
  return {data, competenceIds:[...values.competenceIds], prestationIds:[...values.prestationIds], affiliations:values.affiliations.map(item=>({IdEntiteFk:item.IdEntiteFk,IdTypeLienFk:item.IdTypeLienFk||null,DateDebut:item.DateDebut===commandeDateInput(item._originalDates?.DateDebut)?item._originalDates?.DateDebut||null:item.DateDebut||null,DateFin:item.DateFin===commandeDateInput(item._originalDates?.DateFin)?item._originalDates?.DateFin||null:item.DateFin||null,EstPrincipal:item.EstPrincipal,ObsLien:item.ObsLien})), requestId, ...(photoDataUrl?{photoDataUrl}:{}),...(removePhoto?{removePhoto:true}:{}),...(edit ? {_version:String(version || ""), motif:values.motif.trim()} : {})};
}
export function uncertainExpertResponse(response) { return !response || !response.success && (!response.status || response.status >= 500); }
export function expertResponseErrors(response){
 const details=response?.error?.details;
 if(!details||typeof details!=="object"||Array.isArray(details))return {};
 return Object.fromEntries(Object.entries(details).map(([field,message])=>[field.split(".")[0],Array.isArray(message)?message.join(" "):String(message)]));
}
