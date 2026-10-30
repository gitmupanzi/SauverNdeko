import {articleForm,articleErrors,articlePayload} from "./articleForm";
import {tiersForm,tiersFormErrors,tiersPayload} from "./TiersEditor";
import {immobilisationValues,immobilisationErrors,immobilisationPayload,IMMOBILISATION_REFERENCES} from "./immobilisationForm";
import {lotErrors} from "../../components/LotFields";
import {fieldCurrencyReferences,newCurrencyId} from "../../utils/money";
import {parseExcelTsv,referenceBatchId,referenceDuplicateKey} from "../referentiels/referenceBatch";

export const LOGISTICS_BATCH_MAX=100;
export const BATCH_KINDS={
 tiers:{title:"Nouveau tiers",plural:"tiers",icon:"user",name:"Nom",columns:["Nom","Nature","ID_TypeClientFk","Email","Telephone"],paste:["Nom","ID_TypeClientFk","Nature","Email","Telephone","Adresse"]},
 articles:{title:"Ajouter plusieurs articles",plural:"articles",icon:"box",name:"NomArticle",columns:["NomArticle","RefArticle","ID_CategorieArticleFk","ID_TypeArticleFk","ID_UniteFk","QteArticle","ID_DeviseFk","PUArticle","PVArticle"],paste:["NomArticle","ID_CategorieArticleFk","ID_TypeArticleFk","ID_UniteFk","QteArticle","PUArticle","PVArticle","ID_DeviseFk"]},
 immobilisations:{title:"Nouvelle immobilisation",plural:"immobilisations",icon:"building",name:"NomImmobilisation",columns:["NomImmobilisation","Reference","ID_CategorieFk","Quantite","PrixUnitaire","ID_DeviseFk","ID_ServiceFk"],paste:["NomImmobilisation","ID_CategorieFk","Reference","Quantite","PrixUnitaire","ID_DeviseFk","ID_ServiceFk","motif"]},
};
export const BATCH_LABELS={Nom:"Nom du tiers",Nature:"Nature",ID_TypeClientFk:"Type de client",Email:"E-mail",Telephone:"Téléphone",Adresse:"Adresse",NomArticle:"Article",RefArticle:"Référence",ID_CategorieArticleFk:"Catégorie",ID_TypeArticleFk:"Type",ID_UniteFk:"Unité",QteArticle:"Stock initial",PUArticle:"Prix d’achat",PVArticle:"Prix de vente",ID_DeviseFk:"Devise",NomImmobilisation:"Nom du bien",Reference:"Référence",ID_CategorieFk:"Type de matériel",Quantite:"Quantité",PrixUnitaire:"Prix unitaire",ID_ServiceFk:"Service",motif:"Motif",CodeArticleInterne:"Code interne",CodeArticleExterne:"Code externe",QteMinArticle:"Seuil minimum",PoidsUnitaire:"Poids unitaire",ID_UnitePoidsFk:"Unité de poids",DatePeremptionArticle:"Date de péremption",NbreJoursAlerteArticle:"Jours d’alerte",InformationArticle:"Informations",ObsArticle:"Observations",Observations:"Observations",Caracteristiques:"Caractéristiques",NumeroSerie:"N° de série",DateEntree:"Date et heure d’entrée",DateAcquisition:"Date d’acquisition",SuiviIndividuel:"Suivi individuel",LocalisationComplement:"Bureau ou salle",ID_ResponsableFk:"Responsable",ID_LocalisationFk:"Localisation",ID_EtatFk:"État du matériel",Actif:"Actif",ValideArticle:"Actif",ObsClient:"Informations",IdUserFk:"Compte utilisateur",IdProfessionnelFk:"Professionnel",IdEntiteRepresenteeFk:"Entreprise représentée"};
const sourceFields={tiers:{ID_TypeClientFk:"typesClients",IdUserFk:"users",IdProfessionnelFk:"professionnels",IdEntiteRepresenteeFk:"entites"},articles:{ID_CategorieArticleFk:"articleCategories",ID_TypeArticleFk:"articleTypes",ID_UniteFk:"articleUnits",ID_UnitePoidsFk:"weightUnits",ID_DeviseFk:"articleCurrencies"},immobilisations:IMMOBILISATION_REFERENCES};
export function batchChoices(kind,field,references){
 if(field==="Nature")return [{value:"personne",label:"Personne"},{value:"entreprise",label:"Entreprise"}];
 const items=references?.[sourceFields[kind]?.[field]]||(kind==="articles"&&field==="ID_DeviseFk"?references?.currencies:null);
 if(!items)return null;
 return items.map(item=>({value:String(item.id??item.value),label:item.label??item.name??item.code??String(item.id),code:item.code,disabled:item.disabled===true||item.active===false}));
}
export function logisticsBatchRow(kind,references={},overrides={},id=referenceBatchId()){
 const values=kind==="tiers"?tiersForm(null,references.defaultTypeClientId):kind==="articles"?{...articleForm(null),ID_DeviseFk:newCurrencyId(fieldCurrencyReferences(references,"articleCurrencies"))}:immobilisationValues(null,references);
 return {clientRowId:id,values:{...values,...overrides},motif:"",initialLots:[],photo:{file:null,remove:false},_pristine:Object.keys(overrides).length===0};
}
export function logisticsRowPayload(kind,row,motif=""){
 if(kind==="tiers")return tiersPayload(row.values,null);
 if(kind==="immobilisations"){const data=immobilisationPayload(row.values,{motif:row.motif||motif,requestId:""});delete data.requestId;return data;}
 const data=articlePayload(row.values,null);delete data.PhotoArticle;
 if(row.initialLots?.length)data.LotsInitiaux=row.initialLots;
 return data;
}
export function validateLogisticsBatch(kind,rows,references={},motif=""){
 const header={},issues={};
 if(!rows.length)header.rows="Ajoutez au moins une ligne.";
 if(rows.length>LOGISTICS_BATCH_MAX)header.rows="Limitez le panier à "+LOGISTICS_BATCH_MAX+" lignes.";
 const seen=new Map();let photoBytes=0;
 for(const row of rows){
  const fields=kind==="tiers"?tiersFormErrors(row.values,references):kind==="articles"?articleErrors(row.values,true):immobilisationErrors(row.values,row.motif||motif);
  if(kind==="articles"){
   const invalidLots=lotErrors(row.initialLots||[],row.values.QteArticle);if(invalidLots)fields.LotsInitiaux=invalidLots;
   if(typeof row.values.ValideArticle!=="boolean")fields.ValideArticle="Choisissez Actif ou Inactif.";
   const file=row.photo?.file;if(file){photoBytes+=file.size;if(file.size>8*1024*1024||!["image/jpeg","image/png","image/webp"].includes(file.type))fields.photo="Choisissez une photo JPEG, PNG ou WebP de 8 Mo maximum.";}
  }
  for(const field of Object.keys(sourceFields[kind]||{})){
   const value=row.values[field];if(!value)continue;
   const list=batchChoices(kind,field,references)||[];
   if(!list.some(item=>item.value===String(value)&&!item.disabled))fields[field]="Choisissez une valeur active de la liste.";
  }
  // Seul le code interne possède une contrainte d’unicité métier, sensible à la casse.
  const identifiers=kind==="articles"?["CodeArticleInterne"]:[];
  for(const field of identifiers){const value=String(row.values[field]??"").trim();if(!value)continue;const key=field+":"+value;if(seen.has(key)){fields[field]="Ce code interne apparaît déjà dans le panier.";const prior=seen.get(key);issues[prior]={...(issues[prior]||{}),[field]:fields[field]};}else seen.set(key,row.clientRowId);}
  if(kind==="tiers"&&row.values.Nom?.trim()){const key="tiers:"+JSON.stringify(Object.keys(row.values).sort().map(field=>[field,referenceDuplicateKey(row.values[field])]));if(seen.has(key)){fields.Nom="Ce tiers apparaît déjà avec les mêmes coordonnées dans le panier.";const prior=seen.get(key);issues[prior]={...(issues[prior]||{}),Nom:fields.Nom};}else seen.set(key,row.clientRowId);}
  if(Object.keys(fields).length)issues[row.clientRowId]={...(issues[row.clientRowId]||{}),...fields};
 }
 if(photoBytes>32*1024*1024)header.photos="Limitez les photos de cet enregistrement à 32 Mo au total.";
 return {header,rows:issues};
}
const normal=value=>referenceDuplicateKey(value).normalize("NFD").replace(/[\u0300-\u036f]/g,"").replace(/[^a-z0-9]/g,"");
function dateInput(value){const match=/^(\d{2})\/(\d{2})\/(\d{4})(?:[ T](\d{2}):(\d{2})(?::(\d{2}))?)?$/.exec(value.trim());return match?match[3]+"-"+match[2]+"-"+match[1]+(match[4]?"T"+match[4]+":"+match[5]+":"+(match[6]||"00"):""):value;}
export function logisticsBatchFromExcel(kind,text,references,{hasHeaders=false}={}){
 const matrix=parseExcelTsv(text);if(!matrix.length)return [];
 const config=BATCH_KINDS[kind],base=logisticsBatchRow(kind,references),allowed=Object.keys(base.values).filter(key=>!["PhotoArticle","DatePeremptionAlerteArticle","ID_UserFK"].includes(key));
 if(kind==="immobilisations")allowed.push("motif");
 let columns=config.paste;
 if(hasHeaders){columns=matrix.shift().map(label=>{const token=normal(label),matches=allowed.filter(field=>normal(field)===token||normal(BATCH_LABELS[field]||"")===token);if(matches.length!==1)throw new Error("En-tête non reconnu ou ambigu : « "+label+" ».");return matches[0];});if(new Set(columns).size!==columns.length)throw new Error("Un même en-tête apparaît plusieurs fois.");if(!columns.includes(config.name))throw new Error("Ajoutez la colonne « "+BATCH_LABELS[config.name]+" ».");}
 if(matrix.length>LOGISTICS_BATCH_MAX)throw new Error("Limitez le collage à "+LOGISTICS_BATCH_MAX+" lignes.");
 return matrix.map((cells,index)=>{
  if(cells.length>columns.length)throw new Error("La ligne "+(index+1)+" contient trop de colonnes.");
  const row={...logisticsBatchRow(kind,references),_pristine:false};
  cells.forEach((raw,column)=>{const field=columns[column],token=normal(raw);if(field==="motif"){row.motif=raw;return;}if(raw.trim()===""&&["Actif","ValideArticle","SuiviIndividuel"].includes(field))return;
   let value=raw;
   if(["Actif","ValideArticle","SuiviIndividuel"].includes(field))value=["oui","true","1","actif","vrai"].includes(token)?true:["non","false","0","inactif","faux"].includes(token)?false:raw;
   else if(field==="Nature")value=token==="entreprise"?"entreprise":token==="personne"?"personne":raw;
   else if(field.startsWith("Date"))value=dateInput(raw);
   else {const choices=batchChoices(kind,field,references);if(choices&&raw.trim()){const byId=choices.find(item=>item.value===raw.trim());const matches=byId?[byId]:choices.filter(item=>!item.disabled&&[item.label,item.code].some(label=>referenceDuplicateKey(label)===referenceDuplicateKey(raw)));if(matches.length===1)value=matches[0].value;}}
   row.values[field]=value;
  });return row;
 });
}
export function logisticsBatchTicket(kind,rows,motif=""){
 return {requestId:referenceBatchId(),rows:rows.map(row=>({clientRowId:row.clientRowId,data:logisticsRowPayload(kind,row,motif)}))};
}
export function logisticsBatchBody(kind,ticket,rows){
 const photos=rows.filter(row=>row.photo?.file);if(kind!=="articles"||!photos.length)return JSON.stringify(ticket);
 const body=new FormData();body.set("payload",JSON.stringify(ticket));for(const row of photos)body.set("photo_"+row.clientRowId,row.photo.file,row.photo.file.name||"photo.jpg");return body;
}
