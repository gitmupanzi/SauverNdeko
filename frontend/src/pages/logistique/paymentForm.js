import {compareDecimal} from "../../utils/money";
import {commandeDateInput,validCommandeDate} from "./commandeForm";
export const PAYMENT_FIELDS=["ID_ModeReglementFk","DateReglement","MontantRegle"];
export function paymentForm(record=null,defaults={}){
 const source=record||defaults;
 return {CodeFactureFk:source.CodeFactureFk==null?"":String(source.CodeFactureFk),ID_ModeReglementFk:source.ID_ModeReglementFk==null?"":String(source.ID_ModeReglementFk),DateReglement:commandeDateInput(source.DateReglement),MontantRegle:source.MontantRegle==null?"":String(source.MontantRegle)};
}
export function paymentErrors(values){
 const errors={};
 if(!String(values.CodeFactureFk||"").trim())errors.CodeFactureFk="Choisissez une facture.";
 if(!/^[1-9]\d*$/.test(String(values.ID_ModeReglementFk||"")))errors.ID_ModeReglementFk="Choisissez un mode de règlement.";
 if(!validCommandeDate(values.DateReglement))errors.DateReglement="Renseignez une date et une heure valides.";
 const amount=String(values.MontantRegle??"").trim();
 if(!/^\d{1,10}(?:[.,]\d{1,2})?$/.test(amount)||compareDecimal(amount,"0")!==1||compareDecimal(amount,"9999999999.99")===1)errors.MontantRegle="Renseignez un montant positif, avec deux décimales au maximum.";
 return errors;
}
export function paymentPayload(values,record=null,revision=null){
 const current=paymentForm(record),payload={};
 if(!record)payload.CodeFactureFk=String(values.CodeFactureFk).trim();
 for(const key of PAYMENT_FIELDS){
  const value=String(values[key]??"").trim(),normal=key==="MontantRegle"?value.replace(",","."):value;
  if(!record||normal!==String(current[key]??""))payload[key]=normal||null;
 }
 if(record)payload._version=revision;
 return payload;
}
