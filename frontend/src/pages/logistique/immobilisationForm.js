import {referenceOptions,retainReference} from "../../utils/referenceOptions";
import {commandeDateInput,validCommandeDate} from "./commandeForm";
import {multiplyDecimal,newCurrencyId} from "../../utils/money";

export const IMMOBILISATION_LIMITS={NomImmobilisation:200,Reference:255,Caracteristiques:4000,NumeroSerie:255,LocalisationComplement:255,Observations:4000};
export const IMMOBILISATION_REFERENCES={ID_CategorieFk:"types",ID_EtatFk:"etats",ID_ResponsableFk:"responsables",ID_ServiceFk:"services",ID_LocalisationFk:"localisations",ID_DeviseFk:"currencies"};
const text=value=>value==null?"":String(value);
export const immobilisationLocation=record=>[record?.Localisation,record?.LocalisationComplement].filter(Boolean).join(" · ");
export const ASSET_CYCLE_LABELS={EN_SERVICE:"En service",A_METTRE_EN_SERVICE:"À mettre en service",SORTI:"Sorti"};
export function assetCycleLabel(record){
  if(record?.StatutCycle==="A_METTRE_EN_SERVICE"&&!record.DateMiseEnService)return "Mise en service non renseignée";
  return ASSET_CYCLE_LABELS[record?.StatutCycle]||"—";
}
export function immobilisationValues(record=null,references={},now=new Date()){
  return {...Object.fromEntries([...Object.keys(IMMOBILISATION_LIMITS),...Object.keys(IMMOBILISATION_REFERENCES)].map(key=>[key,text(record?.[key])])),
    LocalisationComplement:immobilisationLocation(record),
    Quantite:text(record?.Quantite??"1"),PrixUnitaire:text(record?.PrixUnitaire),SuiviIndividuel:record?.SuiviIndividuel??true,
    DateEntree:commandeDateInput(record?.DateEntree??now.toISOString()),DateAcquisition:text(record?.DateAcquisition).slice(0,10),DateMiseEnService:text(record?.DateMiseEnService).slice(0,10),
    ...(!record?{ID_DeviseFk:newCurrencyId(references)}:{})};
}
function validDate(value){return /^\d{4}-\d{2}-\d{2}$/.test(value)&&validCommandeDate(value+"T00:00:00");}
export function immobilisationErrors(values,motif,record=null){
  const errors={};
  for(const [key,max] of Object.entries(IMMOBILISATION_LIMITS)){
    const value=text(values[key]).trim();
    if(key==="LocalisationComplement"&&record?.ID_LocalisationFk&&value===immobilisationLocation(record).trim())continue;
    if(Array.from(value).length>max)errors[key]="Limitez ce champ à "+max+" caractères.";
  }
  if(!text(values.NomImmobilisation).trim())errors.NomImmobilisation="Renseignez le nom du bien.";
  if(!values.ID_CategorieFk)errors.ID_CategorieFk="Choisissez le type de matériel.";
  for(const key of Object.keys(IMMOBILISATION_REFERENCES))if(values[key]&&!/^[1-9]\d*$/.test(values[key]))errors[key]="Choisissez une valeur de la liste.";
  const quantity=text(values.Quantite).trim();
  if(!/^\d{1,18}$/.test(quantity)||!/[1-9]/.test(quantity))errors.Quantite="Renseignez un nombre entier positif de 18 chiffres maximum.";
  else if((values.SuiviIndividuel||text(values.NumeroSerie).trim())&&BigInt(quantity)!==1n)errors.Quantite="Un bien individuel ou portant un numéro de série a une quantité de 1.";
  if(typeof values.SuiviIndividuel!=="boolean")errors.SuiviIndividuel="Choisissez un mode de suivi.";
  const price=text(values.PrixUnitaire).trim();
  if(price&&!/^\d{1,16}(?:[.,]\d{1,2})?$/.test(price))errors.PrixUnitaire="Renseignez un prix positif ou nul, avec deux décimales maximum.";
  if(price&&!values.ID_DeviseFk)errors.ID_DeviseFk="Choisissez la devise du prix d’acquisition.";
  if(!validCommandeDate(values.DateEntree))errors.DateEntree="Renseignez une date et une heure valides.";
  if(values.DateAcquisition&&!validDate(values.DateAcquisition))errors.DateAcquisition="Renseignez une date valide.";
  if(values.DateMiseEnService&&!validDate(values.DateMiseEnService))errors.DateMiseEnService="Renseignez une date valide.";
  else if(values.DateMiseEnService&&values.DateAcquisition&&values.DateMiseEnService<values.DateAcquisition)errors.DateMiseEnService="La mise en service doit être postérieure ou égale à l’acquisition.";
  if(!text(motif).trim())errors.motif="Précisez le motif de l’enregistrement.";
  else if(Array.from(motif.trim()).length>1000)errors.motif="Limitez le motif à 1000 caractères.";
  return errors;
}
export function immobilisationPayload(values,{record=null,revision,motif,requestId}={}){
  const payload=Object.fromEntries(Object.keys(IMMOBILISATION_LIMITS).map(key=>[key,text(values[key]).trim()||null]));
  for(const key of Object.keys(IMMOBILISATION_REFERENCES))payload[key]=values[key]||null;
  if(record?.ID_LocalisationFk){
    if(text(values.LocalisationComplement).trim()===immobilisationLocation(record).trim()){
      payload.LocalisationComplement=record.LocalisationComplement||null;
    }else{
      payload.ID_LocalisationFk=null;
    }
  }
  payload.SuiviIndividuel=values.SuiviIndividuel;
  // La quantité reste une chaîne exacte : les nombres JavaScript arrondissent au-delà de 15 chiffres.
  payload.Quantite=/^\d+$/.test(values.Quantite)?BigInt(values.Quantite).toString():values.Quantite;
  payload.PrixUnitaire=text(values.PrixUnitaire).trim().replace(",",".")||null;
  payload.DateEntree=values.DateEntree?values.DateEntree+"+01:00":null;
  payload.DateAcquisition=values.DateAcquisition||null;
  payload.DateMiseEnService=values.DateMiseEnService||null;
  payload.motif=motif.trim();payload.requestId=requestId;
  if(record)payload._version=revision??record._version;
  return payload;
}
export function immobilisationValue(values){return multiplyDecimal(values.Quantite,values.PrixUnitaire);}
export function immobilisationOptions(items=[],{optional=true,current="",currentLabel=""}={}){
  const options=retainReference(referenceOptions(items),current,currentLabel);
  return optional?[{value:"",label:"Non renseigné"},...options]:[{value:"",label:"Choisir…"},...options];
}
