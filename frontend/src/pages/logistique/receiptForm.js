import {quantityError} from "../../utils/quantities";
export function createReceiptRequestId(cryptoSource=globalThis.crypto) {
  if(cryptoSource.randomUUID)return cryptoSource.randomUUID();
  const bytes=cryptoSource.getRandomValues(new Uint8Array(16));
  bytes[6]=(bytes[6]&15)|64;bytes[8]=(bytes[8]&63)|128;
  const hex=Array.from(bytes,value=>value.toString(16).padStart(2,"0")).join("");
  return [hex.slice(0,8),hex.slice(8,12),hex.slice(12,16),hex.slice(16,20),hex.slice(20)].join("-");
}
export function receiptForm(data) {
  const defaults=data?.defaults||{};
  return {ID_DepotFk:String(defaults.ID_DepotFk??""),ID_TypeCmdFk:defaults.ID_TypeCmdFk==null?String(data?.type?.id??""):String(defaults.ID_TypeCmdFk),QteCmdDetail:"",PUCmdDetail:data?.priceToConfirm||defaults.PUCmdDetail==null?"":String(defaults.PUCmdDetail),ID_DeviseFk:data?.currencyToConfirm||defaults.ID_DeviseFk==null?"":String(defaults.ID_DeviseFk),DateCmd:defaults.DateCmd||"",RefCmd:"",ID_TiersFk:"",NomClientSaisi:"",ObsCmd:""};
}
export function receiptErrors(values,typeIds=null) {
  const errors={};
  if(values.ID_TiersFk&&!/^[1-9]\d*$/.test(values.ID_TiersFk))errors.ID_TiersFk="Choisissez un tiers de la liste.";
  if(!/^[1-9]\d*$/.test(String(values.ID_TypeCmdFk||""))||(typeIds&&!typeIds.some(id=>String(id)===values.ID_TypeCmdFk)))errors.ID_TypeCmdFk="Choisissez un type de bon d’entrée proposé dans la liste.";
  if(quantityError(values.QteCmdDetail))errors.QteCmdDetail=quantityError(values.QteCmdDetail);
  if(!/^\d{1,10}(?:[.,]\d{1,2})?$/.test(values.PUCmdDetail.trim()))errors.PUCmdDetail="Renseignez un prix positif ou nul, avec deux décimales au maximum.";
  if(!/^[1-9]\d*$/.test(values.ID_DeviseFk))errors.ID_DeviseFk="Choisissez une devise.";
  const match=/^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})(?::(\d{2}))?$/.exec(values.DateCmd);
  if(!match)errors.DateCmd="Renseignez la date et l’heure du bon.";
  else {
    const [year,month,day,hour,minute,second]=match.slice(1).map(value=>Number(value||0));
    const date=new Date(0);date.setUTCFullYear(year,month-1,day);date.setUTCHours(hour,minute,second,0);
    if(year<1||date.getUTCFullYear()!==year||date.getUTCMonth()+1!==month||date.getUTCDate()!==day||date.getUTCHours()!==hour||date.getUTCMinutes()!==minute||date.getUTCSeconds()!==second)errors.DateCmd="Renseignez une date et une heure valides.";
  }
  if(values.RefCmd.trim().length>255)errors.RefCmd="Limitez la référence à 255 caractères.";
  if(values.NomClientSaisi.trim().length>255)errors.NomClientSaisi="Limitez le fournisseur à 255 caractères.";
  if(values.ObsCmd.trim().length>255)errors.ObsCmd="Limitez l’observation à 255 caractères.";
  return errors;
}
export function receiptPayload(values,lots) {
  return {...values,QteCmdDetail:values.QteCmdDetail.trim().replace(",","."),PUCmdDetail:values.PUCmdDetail.trim().replace(",","."),RefCmd:values.RefCmd.trim()||null,NomClientSaisi:values.NomClientSaisi.trim()||null,ObsCmd:values.ObsCmd.trim()||null,Lots:lots.map(lot=>({...lot,NumeroLot:lot.NumeroLot.trim(),Quantite:String(lot.Quantite).trim(),DatePeremptionLot:lot.DatePeremptionLot||null}))};
}
