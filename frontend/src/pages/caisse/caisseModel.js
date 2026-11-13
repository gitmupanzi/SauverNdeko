import {sameCategory} from "../../utils/categoricalValues";
import {compareDecimal, decimalParts} from "../../utils/money";
import {referenceLabel} from "../../utils/referenceOptions";

export const CAISSE_ROOT="/api/caisse";
export const CAISSE_REGISTERS={
 caisses:{title:"Caisses",subtitle:"Soldes disponibles et responsables de caisse.",id:"IdCaisse",sort:"NomCaisse",direction:"asc",create:"Nouvelle caisse",icon:"wallet",visible:["CodeCaisse","NomCaisse","DeviseCode","MontantCaisse","Responsable","Actif","actions"]},
 ecritures:{title:"Écritures de caisse",subtitle:"Encaissements, décaissements et contrepassations.",id:"IdPaiement",sort:"DatePaiement",direction:"desc",create:"Nouvelle écriture",icon:"movements",visible:["CodePaiement","DatePaiement","NomCaisse","LibellePaiement","SensMouvement","MontantPaiement","EtatEcriture","actions"]},
 clotures:{title:"Clôtures de caisse",subtitle:"Comptages physiques et écarts conservés dans l’historique.",id:"ID_ClotureCaisse",sort:"ClotureLe",direction:"desc",create:"Nouvelle clôture",icon:"check-circle",visible:["ID_ClotureCaisse","ClotureLe","NomCaisse","SoldeTheorique","MontantCompte","Ecart","Auteur","actions"]},
};
export const CAISSE_VALIDATION_MODES = [
 {value:"MANUAL",label:"Validation manuelle"},
 {value:"OTHER_AGENT",label:"Validation par un autre agent"},
 {value:"AUTO",label:"Validation automatique à l’enregistrement"},
];
export const caisseValidationLabel = mode => CAISSE_VALIDATION_MODES.find(option=>option.value===mode)?.label;
export const CAISSE_LABELS={CodeCaisse:"Code caisse",NomCaisse:"Caisse",DeviseCode:"Devise",MontantCaisse:"Solde validé",EntreesBrouillon:"Encaissements en brouillon",SortiesBrouillon:"Décaissements en brouillon",SoldePrevisionnel:"Solde prévisionnel",ModeValidation:"Mode de validation",Responsable:"Responsable",Actif:"État",NomEntite:"Entreprise",CodePaiement:"N° d’écriture",DatePaiement:"Date et heure",LibellePaiement:"Libellé",SensMouvement:"Sens",MontantPaiement:"Montant",EtatEcriture:"État",ReferenceExterne:"Référence",NomTiers:"Tiers",Auteur:"Auteur",Validateur:"Validateur",ObsPaiement:"Observations",CodeCompensateur:"Contrepassation",ID_ClotureCaisse:"Clôture",ClotureLe:"Date et heure",SoldeTheorique:"Solde théorique",MontantCompte:"Montant compté",Ecart:"Écart",Motif:"Motif"};
export const ENTRY_STATES=[{value:"",label:"Tous les états"},{value:"DRAFT",label:"Brouillons"},{value:"POSTED",label:"Validées"}];
export const ENTRY_SENSES=[{value:"",label:"Tous les mouvements"},{value:"1",label:"Encaissements"},{value:"-1",label:"Décaissements"}];
export function caisseTab(value){return Object.hasOwn(CAISSE_REGISTERS,value)?value:"tableau-de-bord";}
export function caisseQuery(criteria={},grid={}){
 const query=new URLSearchParams();
 if(String(criteria.q||"").trim())query.set("q",String(criteria.q).trim());
 const filters=Object.fromEntries(Object.entries(criteria.filters||{}).filter(([,value])=>value!==""&&value!=null));
 if(Object.keys(filters).length)query.set("filters",JSON.stringify(filters));
 if(grid.take){query.set("take",String(grid.take));query.set("page",String(Math.floor((grid.skip||0)/grid.take)+1));}
 if(grid.sortBy){query.set("sort",grid.sortBy);query.set("direction",grid.sortDir==="asc"?"asc":"desc");}
 return query;
}
export function caisseOptions(items=[],emptyLabel="Choisir…"){
 return [{value:"",label:emptyLabel},...items.map(item=>({value:String(item.id),label:referenceLabel(item),disabled:item.disabled===true||item.active===false}))];
}
export function cashboxOptions(references={},emptyLabel="Choisir une caisse…"){
 return [{value:"",label:emptyLabel},...(references.caisses||[]).map(row=>({value:String(row.IdCaisse),label:[row.CodeCaisse,row.NomCaisse,row.DeviseCode].filter(Boolean).join(" · "),disabled:row.Actif===false}))];
}
export function caisseDateInput(value){
 const date=value?new Date(value):new Date();
 if(Number.isNaN(date.getTime()))return "";
 const parts=new Intl.DateTimeFormat("fr-CA",{timeZone:"Africa/Kinshasa",year:"numeric",month:"2-digit",day:"2-digit",hour:"2-digit",minute:"2-digit",second:"2-digit",hourCycle:"h23"}).formatToParts(date),get=type=>parts.find(part=>part.type===type)?.value;
 return `${get("year")}-${get("month")}-${get("day")}T${get("hour")}:${get("minute")}:${get("second")}`;
}
export function validCaisseDate(value){
 const match=/^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})(?::(\d{2}))?$/.exec(String(value||""));
 if(!match)return false;
 const [,year,month,day,hour,minute,second="00"]=match,date=new Date(`${year}-${month}-${day}T${hour}:${minute}:${second}Z`);
 return !Number.isNaN(date.getTime())&&date.getUTCFullYear()===Number(year)&&date.getUTCMonth()+1===Number(month)&&date.getUTCDate()===Number(day)&&date.getUTCHours()===Number(hour)&&date.getUTCMinutes()===Number(minute)&&date.getUTCSeconds()===Number(second);
}
export function caisseAmount(value,{zero=false}={}){
 const clean=String(value??"").trim().replace(",",".");
 return /^\d{1,16}(?:\.\d{1,2})?$/.test(clean)&&compareDecimal(clean,"0")!==-1&&(zero||compareDecimal(clean,"0")===1)?clean:null;
}
export function caisseResponseUncertain(response){return !response||response.success!==false||!response.status||response.status>=500;}
export function caisseValues(kind,record=null,references={},defaults={}){
 const source=record||defaults,string=key=>source[key]==null?"":String(source[key]);
 if(kind==="caisses"){
  const usd=(references.devises||[]).filter(item=>sameCategory(item.abbr||item.label,"USD")&&!item.disabled&&item.active!==false);
  return {NomCaisse:string("NomCaisse"),IdDeviseFk:string("IdDeviseFk")||(!record&&usd.length===1?String(usd[0].id):""),IdTypeCaisseFk:string("IdTypeCaisseFk"),IdResponsableFk:string("IdResponsableFk"),Actif:source.Actif!==false,motif:""};
 }
 if(kind==="clotures")return {IdCaisseFk:string("IdCaisseFk"),ClotureLe:caisseDateInput(),MontantCompte:"",motif:""};
 return {IdCaisseFk:string("IdCaisseFk"),LibellePaiement:string("LibellePaiement"),ReferenceExterne:string("ReferenceExterne"),DatePaiement:caisseDateInput(source.DatePaiement),MontantPaiement:string("MontantPaiement"),SensMouvement:string("SensMouvement")||"1",IdTypePaiementFk:string("IdTypePaiementFk"),IdTiersFk:string("IdTiersFk"),ObsPaiement:string("ObsPaiement"),ValidePaiement:source.ValidePaiement!==false,valider:false,motif:""};
}
export function caisseErrors(kind,values){
 const errors={};
 if(!String(values.motif||"").trim())errors.motif="Précisez le motif de cette opération.";
 if(kind==="valider"||kind==="contrepasser")return errors;
 if(kind==="caisses"){
  if(!String(values.NomCaisse||"").trim())errors.NomCaisse="Renseignez le nom de la caisse.";
  if(!/^[1-9]\d*$/.test(values.IdDeviseFk))errors.IdDeviseFk="Choisissez une devise.";
 }else{
  if(!/^[1-9]\d*$/.test(values.IdCaisseFk))errors.IdCaisseFk="Choisissez une caisse.";
  const dateKey=kind==="clotures"?"ClotureLe":"DatePaiement";
  if(!validCaisseDate(values[dateKey]))errors[dateKey]="Renseignez une date et une heure valides.";
  const amountKey=kind==="clotures"?"MontantCompte":"MontantPaiement";
  if(caisseAmount(values[amountKey],{zero:kind==="clotures"})===null)errors[amountKey]=kind==="clotures"?"Renseignez un montant positif ou nul, avec deux décimales au maximum.":"Renseignez un montant positif, avec deux décimales au maximum.";
  if(kind!=="clotures"){
   if(!String(values.LibellePaiement||"").trim())errors.LibellePaiement="Renseignez le libellé.";
   if(!["1","-1"].includes(String(values.SensMouvement)))errors.SensMouvement="Choisissez le sens du mouvement.";
  }
 }
 return errors;
}
export function caissePayload(kind,values,{version,requestId}={}){
 const body={requestId,motif:String(values.motif||"").trim()};
 if(version!=null)body._version=String(version);
 if(kind==="valider"||kind==="contrepasser")return body;
 const keys=kind==="caisses"?["NomCaisse","IdDeviseFk","IdTypeCaisseFk","IdResponsableFk","Actif"]:kind==="clotures"?["IdCaisseFk","ClotureLe","MontantCompte"]:["IdCaisseFk","LibellePaiement","ReferenceExterne","DatePaiement","MontantPaiement","SensMouvement","IdTypePaiementFk","IdTiersFk","ObsPaiement","ValidePaiement"];
 body.data=Object.fromEntries(keys.map(key=>{
  if(key==="Actif"||key==="ValidePaiement")return [key,values[key]===true];
  if(key==="SensMouvement")return [key,values[key]==="-1"?-1:1];
  const value=String(values[key]??"").trim();
  if(["DatePaiement","ClotureLe"].includes(key))return [key,value?value+"+01:00":null];
  if(["MontantPaiement","MontantCompte"].includes(key))return [key,caisseAmount(value,{zero:key==="MontantCompte"})];
  return [key,value||null];
 }));
 if(kind==="ecritures")body.valider=values.valider===true;
 return body;
}
/** Mise à l’échelle visuelle uniquement ; les montants affichés viennent du serveur. */
export function caisseBarPercent(value,ceiling){
 const a=decimalParts(value),b=decimalParts(ceiling);
 if(!a||!b||a.units<=0n||b.units<=0n)return 0;
 const scale=Math.max(a.scale,b.scale),ratio=a.units*10n**BigInt(scale-a.scale)*100n/(b.units*10n**BigInt(scale-b.scale));
 return Number(ratio>100n?100n:ratio);
}
