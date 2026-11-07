import {retainReference,referenceLabel,referenceOptions} from "../../utils/referenceOptions";

export const SUPPORT_ROOT="/api/support";
export const SUPPORT_FIELDS=[
 {key:"Objet",label:"Objet",required:true,max:200},
 {key:"Description",label:"Description",required:true,type:"textarea",max:20000},
 {key:"ID_DemandeurFk",label:"Demandeur",source:"requesters"},
 {key:"ID_ResponsableFk",label:"Responsable",source:"users"},
 {key:"ID_TypeSupportFk",label:"Type",source:"types"},
 {key:"ID_CategorieSupportFk",label:"Catégorie",source:"categories"},
 {key:"ID_PrioriteFk",label:"Priorité",source:"priorities"},
 {key:"ID_CanalOrigineFk",label:"Canal d’origine",source:"channels"},
 {key:"ID_ServiceConcerneFk",label:"Service concerné",source:"services"},
 {key:"DateEcheance",label:"Échéance",type:"datetime-local"},
 {key:"ID_ArticleFk",label:"Article lié",source:"articles"},
 {key:"ID_CommandeFk",label:"Bon de stock lié",source:"bons"},
 {key:"ID_ImmobilisationFk",label:"Immobilisation liée",source:"immobilisations"},
];
export const SUPPORT_LABELS={NumeroSupport:"N° de dossier",Objet:"Objet",Description:"Description",Entreprise:"Entreprise",Demandeur:"Demandeur",Responsable:"Responsable",TypeSupport:"Type",CategorieSupport:"Catégorie",Priorite:"Priorité",Statut:"Statut",CanalOrigine:"Canal d’origine",DateCreation:"Créé le",DateModification:"Modifié le",DateEcheance:"Échéance",DateResolution:"Résolu le",DateCloture:"Clôturé le",Archive:"Archivé",ServiceConcerne:"Service concerné",actions:"Actions"};
const oldLabels={ID_DemandeurFk:"Demandeur",ID_ResponsableFk:"Responsable",ID_TypeSupportFk:"TypeSupport",ID_CategorieSupportFk:"CategorieSupport",ID_PrioriteFk:"Priorite",ID_CanalOrigineFk:"CanalOrigine",ID_ServiceConcerneFk:"ServiceConcerne",ID_ArticleFk:"Article",ID_CommandeFk:"Bon",ID_ImmobilisationFk:"Immobilisation"};
export function supportOptions(context,field,record={}){
 const raw=context?.references?.[field.source]||context?.[field.source]||context?.links?.[field.source]||[];
 // Le code AbrGenerique est le libellé des choix ; le circuit conserve les IDs.
 const values=referenceOptions(raw);
 return retainReference(values,record[field.key],["types","categories","priorities","channels","services","statuses","verificationResults"].includes(field.source)?referenceLabel({ID_Generique:record[field.key]}):record[oldLabels[field.key]]||"Valeur actuelle hors des choix disponibles");
}
export function supportInputDate(value){
 if(!value)return "";
 const text=String(value);if(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(?::\d{2}(?:\.\d+)?)?$/.test(text))return text.slice(0,16);
 const parsed=new Date(text);if(Number.isNaN(parsed.getTime()))return text.slice(0,16);
 const parts=Object.fromEntries(new Intl.DateTimeFormat("en-CA",{timeZone:"Africa/Kinshasa",year:"numeric",month:"2-digit",day:"2-digit",hour:"2-digit",minute:"2-digit",hourCycle:"h23"}).formatToParts(parsed).map(part=>[part.type,part.value]));
 return parts.year+"-"+parts.month+"-"+parts.day+"T"+parts.hour+":"+parts.minute;
}
export function supportInitial(record={}){return Object.fromEntries(SUPPORT_FIELDS.map(field=>[field.key,field.type==="datetime-local"?supportInputDate(record[field.key]):String(record[field.key]??"")]));}
export function supportValidation(values,requiredFields=[]){const errors={};for(const field of SUPPORT_FIELDS){const value=String(values[field.key]??"");if((field.required||requiredFields.includes(field.key))&&!value.trim())errors[field.key]="Ce champ est obligatoire.";if(field.max&&value.length>field.max)errors[field.key]="Limite : "+field.max+" caractères.";if(field.source&&value&&!/^[1-9]\d*$/.test(value))errors[field.key]="Sélectionnez une valeur dans la liste.";}if(values.DateEcheance&&!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/.test(values.DateEcheance))errors.DateEcheance="Vérifiez la date et l’heure.";return errors;}
export function supportPayload(values,version,requestId){const output={requestId,...(version?{_version:version}:{})};for(const field of SUPPORT_FIELDS){const value=String(values[field.key]??"");output[field.key]=field.source?(value||null):field.type==="datetime-local"?(value?value+":00+01:00":null):value.trim();}return output;}
export function supportQuery(criteria={},grid={}){const query=new URLSearchParams();for(const key of ["q","dateFrom","dateTo","indicator","archive"])if(criteria[key]!==""&&criteria[key]!=null)query.set(key,String(criteria[key]));const filters=Object.fromEntries(Object.entries(criteria.filters||{}).filter(([,value])=>value!==""&&value!=null).map(([key,value])=>[key,value==="__null__"?null:value]));if(Object.keys(filters).length)query.set("filters",JSON.stringify(filters));for(const key of ["take","skip","sortBy","sortDir"])if(grid[key]!=null)query.set(key,String(grid[key]));return query;}
export const supportCount=value=>value==null?"—":new Intl.NumberFormat("fr-FR").format(Number(value));
export function supportActionValidation(action,values){const errors={};if(action.requiresReason&&!String(values.motif||"").trim())errors.motif="Précisez le motif.";if(action.requiresResolution){if(!String(values.CauseIdentifiee||"").trim())errors.CauseIdentifiee="Précisez la cause identifiée.";if(!String(values.SolutionAppliquee||"").trim())errors.SolutionAppliquee="Décrivez la solution appliquée.";}if(action.requiresVerification){if(!/^[1-9]\d*$/.test(String(values.ID_ResultatVerificationFk||"")))errors.ID_ResultatVerificationFk="Sélectionnez le résultat de vérification.";if(!String(values.CommentaireVerification||"").trim())errors.CommentaireVerification="Précisez le contrôle effectué.";}return errors;}
export const supportUncertain=response=>!response?.status||response.status>=500;
