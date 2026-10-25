import {quantityUnits,quantityString,quantityError,roundMoney} from "../../utils/quantities";
import {decimalParts,multiplyDecimal} from "../../utils/money";
import {commandeDateInput,validCommandeDate} from "./commandeForm";

/** Quantités du journal exactes à trois décimales ; aucune conversion flottante. */
export function returnQuantity(value) {
  return quantityString(quantityUnits(value));
}
export function returnedQuantityError(value,remaining) {
  const raw=String(value??"").trim(),limit=returnQuantity(remaining);
  if(quantityError(raw,true))return quantityError(raw,true);
  if(limit==null)return "La quantité restante doit être vérifiée avant la restitution.";
  if(quantityUnits(raw)>quantityUnits(limit))return "La quantité dépasse le reste à restituer.";
  return "";
}
export function returnHeader(defaultDate) {return {DateCmd:commandeDateInput(defaultDate),motif:""};}
export function returnHeaderErrors(values) {
  const errors={},motif=String(values.motif??"").trim();
  if(!motif)errors.motif="Renseignez le motif de la restitution.";
  else if(Array.from(motif).length>1000)errors.motif="Limitez le motif à 1 000 caractères.";
  if(!validCommandeDate(values.DateCmd))errors.DateCmd="Renseignez la date et l’heure de la restitution.";
  return errors;
}
export function restitutionTotal(items) {
  let cents=0n;
  for(const item of items){
    const quantity=returnQuantity(item.quantity);
    if(quantity==null)return null;
    if(quantity==="0")continue;
    const amount=decimalParts(roundMoney(multiplyDecimal(quantity,item.price)));
    if(!amount||amount.units<0n||amount.scale>2)return null;
    cents+=amount.units*10n**BigInt(2-amount.scale);
  }
  return (cents/100n).toString()+"."+(cents%100n).toString().padStart(2,"0");
}
export function restitutionSelection(lines,previous={}) {
  return Object.fromEntries(lines.map(line=>{const id=String(line.ID_ArticleFk),old=previous[id];return [id,{QteRetour:old?.QteRetour??"0",Lots:{...(old?.Lots||{}),...Object.fromEntries((line.Lots||[]).map(lot=>[String(lot.ID_LotArticle),old?.Lots?.[String(lot.ID_LotArticle)]??"0"]))}}];}));
}
export function restitutionLineErrors(line,selection) {
  const errors={},choice=selection||{QteRetour:"0",Lots:{}},quantityError=returnedQuantityError(choice.QteRetour,line.QteRestante);
  if(quantityError)errors.QteRetour=quantityError;
  let lotsTotal=0n;const known=new Set();
  for(const lot of line.Lots||[]){const id=String(lot.ID_LotArticle),raw=choice.Lots?.[id]??"0";known.add(id);const error=returnedQuantityError(raw,lot.QteRestante);if(error){errors.LotQuantities={...errors.LotQuantities,[id]:error};continue;}lotsTotal+=quantityUnits(raw);}
  for(const [id,value] of Object.entries(choice.Lots||{}))if(!known.has(id)&&returnQuantity(value)!=="0")errors.Lots="Les lots d’origine ont changé. Vérifiez la ventilation.";
  if(!quantityError){const quantity=quantityUnits(choice.QteRetour);if(lotsTotal>quantity)errors.Lots="La ventilation en lots dépasse la quantité à restituer.";else{const noLotRemaining=returnQuantity(line.QteSansLotRestante);if(noLotRemaining==null||quantity-lotsTotal>quantityUnits(noLotRemaining))errors.Lots="Répartissez la quantité entre les lots d’origine disponibles.";}}
  return errors;
}
export function allRemainingReturns(lines) {
  return Object.fromEntries(lines.map(line=>[String(line.ID_ArticleFk),{QteRetour:returnQuantity(line.QteRestante)??"0",Lots:Object.fromEntries((line.Lots||[]).map(lot=>[String(lot.ID_LotArticle),returnQuantity(lot.QteRestante)??"0"]))}]));
}
export function restitutionPayload(values,lines,selection,version) {
  return {_version:version,DateCmd:values.DateCmd,motif:String(values.motif).trim(),lignes:lines.filter(line=>{const quantity=returnQuantity(selection[line.ID_ArticleFk]?.QteRetour);return quantity!=null&&quantityUnits(quantity)>0n;}).map(line=>({ID_ArticleFk:String(line.ID_ArticleFk),QteRetour:returnQuantity(selection[line.ID_ArticleFk].QteRetour),Lots:(line.Lots||[]).filter(lot=>{const quantity=returnQuantity(selection[line.ID_ArticleFk]?.Lots?.[lot.ID_LotArticle]??"0");return quantity!=null&&quantityUnits(quantity)>0n;}).map(lot=>({ID_LotArticle:String(lot.ID_LotArticle),Quantite:returnQuantity(selection[line.ID_ArticleFk].Lots[lot.ID_LotArticle])}))}))};
}
