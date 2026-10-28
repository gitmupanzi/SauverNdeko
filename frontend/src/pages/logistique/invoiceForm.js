import {commandeDateInput,validCommandeDate} from "./commandeForm";

export const INVOICE_FIELDS=["DateFacture","ID_ModePaiementFk","ID_ConditionPaiementFk","DateEcheancePaiement"];
export function invoiceForm(data) {
  const source=data?.facture||data?.defaults||{};
  return {DateFacture:commandeDateInput(source.DateFacture),ID_ModePaiementFk:source.ID_ModePaiementFk==null?"":String(source.ID_ModePaiementFk),ID_ConditionPaiementFk:source.ID_ConditionPaiementFk==null?"":String(source.ID_ConditionPaiementFk),DateEcheancePaiement:commandeDateInput(source.DateEcheancePaiement)};
}
export function invoiceDeadline(value,condition) {
  if(!validCommandeDate(value)||!Number.isInteger(condition?.delayDays)||condition.delayDays<0||condition.delayDays>36500)return null;
  const match=value.match(/^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})(?::(\d{2}))?$/);
  const values=match.slice(1).map(Number),date=new Date(0);
  date.setUTCFullYear(values[0],values[1]-1,values[2]);date.setUTCHours(values[3],values[4],values[5]||0,0);date.setUTCDate(date.getUTCDate()+condition.delayDays);
  if(date.getUTCFullYear()>9999)return null;
  const pad=number=>String(number).padStart(2,"0");
  return String(date.getUTCFullYear()).padStart(4,"0")+"-"+pad(date.getUTCMonth()+1)+"-"+pad(date.getUTCDate())+"T"+pad(date.getUTCHours())+":"+pad(date.getUTCMinutes())+":"+pad(date.getUTCSeconds());
}
export function invoiceErrors(values,references,previous=null) {
  const issues={};
  if(!validCommandeDate(values.DateFacture))issues.DateFacture="Indiquez la date et l’heure de la facture.";
  const modePreserved=previous&&values.ID_ModePaiementFk===previous.ID_ModePaiementFk;
  if(!values.ID_ModePaiementFk||!modePreserved&&!(references?.modesPaiement||[]).some(row=>String(row.id)===values.ID_ModePaiementFk&&!row.disabled&&!row.incompatible))issues.ID_ModePaiementFk="Choisissez un mode de paiement disponible.";
  const condition=(references?.conditionsPaiement||[]).find(row=>String(row.id)===values.ID_ConditionPaiementFk);
  const conditionPreserved=previous&&values.ID_ConditionPaiementFk===previous.ID_ConditionPaiementFk;
  if(!values.ID_ConditionPaiementFk||!conditionPreserved&&(!condition||condition.disabled||condition.incompatible))issues.ID_ConditionPaiementFk="Choisissez une condition de paiement disponible.";
  if(!validCommandeDate(values.DateEcheancePaiement))issues.DateEcheancePaiement="Indiquez la date et l’heure d’échéance.";
  else if(!issues.DateFacture&&commandeDateInput(values.DateEcheancePaiement)<commandeDateInput(values.DateFacture))issues.DateEcheancePaiement="L’échéance ne peut pas précéder la facture.";
  const automatic=invoiceDeadline(values.DateFacture,condition);
  const preserved=previous&&["DateFacture","ID_ConditionPaiementFk","DateEcheancePaiement"].every(key=>values[key]===previous[key]);
  if(!preserved&&automatic&&automatic!==commandeDateInput(values.DateEcheancePaiement))issues.DateEcheancePaiement="L’échéance doit correspondre à la condition de paiement.";
  return issues;
}
export function invoicePayload(values,revision,requestId) {
  return {requestId,_version:revision,...Object.fromEntries(INVOICE_FIELDS.map(key=>[key,String(values[key]??"").trim()]))};
}
