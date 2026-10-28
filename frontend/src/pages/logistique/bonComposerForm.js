import {compareDecimal,decimalParts,multiplyDecimal} from "../../utils/money";
import {quantityError,roundMoney} from "../../utils/quantities";
import {commandeErrors,commandePayload} from "./commandeForm";
import {stockDocumentKind} from "../../utils/stockDocumentTypes";

export const MAX_COMPOSITION_LINES=50;
export const compositionDirection=stockDocumentKind;
export function compositionType(references,values,record=null) {return references?.commandeTypes?.find(type=>String(type.id)===String(values.ID_TypeCmdFk))||(record&&String(record.ID_TypeCmdFk)===String(values.ID_TypeCmdFk)?{...record,id:record.ID_TypeCmdFk,label:record.TypeCmd,abbr:record.AbrTypeCmd,sign:record.SigneCommande}:null);}
export function cataloguePrice(article,values,references,record=null) {
  if(article?.ID_DeviseFk==null||String(article.ID_DeviseFk)!==String(values.ID_DeviseFk))return "";
  const direction=compositionDirection(compositionType(references,values,record));
  const price=direction==="entree"?article.PUArticle:direction==="sortie"?article.PVArticle:null;
  return price==null?"":String(price);
}
export function compositionLine(article,values,references,record=null) {return {article,QteCmdDetail:"1",PUCmdDetail:cataloguePrice(article,values,references,record),ObsCmdDetail:"",LieuCmdDetail:"",RemiseCmdDetail:null,SelectCmdDetail:null,Lots:[]};}
function integerInput(value){if(value==null)return "";const parsed=decimalParts(value),scale=parsed?10n**BigInt(parsed.scale):1n;return parsed&&parsed.units%scale===0n?(parsed.units/scale).toString():String(value);}
function existingLots(rows){return (rows||[]).map(row=>({NumeroLot:String(row.NumeroLot||""),Quantite:integerInput(row.Quantite),DatePeremptionLot:row.DatePeremptionLot?String(row.DatePeremptionLot).slice(0,10):"",MotifDerogationPeremption:row.MotifDerogationPeremption||""}));}
export function compositionBasket(rows){return (rows||[]).map(row=>({article:row.article||{ID_Article:row.ID_ArticleFk,NomArticle:row.NomArticle||"Article #"+row.ID_ArticleFk,CodeArticleInterne:row.CodeArticleInterne||"",missing:true},original:row,QteCmdDetail:integerInput(row.QteCmdDetail),PUCmdDetail:row.PUCmdDetail==null?"":String(row.PUCmdDetail),ObsCmdDetail:row.ObsCmdDetail??"",LieuCmdDetail:row.LieuCmdDetail==null?"":String(row.LieuCmdDetail),RemiseCmdDetail:row.RemiseCmdDetail??null,SelectCmdDetail:row.SelectCmdDetail??null,Lots:existingLots(row.Lots)}));}
function linePayload(line){const observation=line.original&&line.ObsCmdDetail===(line.original.ObsCmdDetail??"")?line.original.ObsCmdDetail??null:String(line.ObsCmdDetail??"").trim()||null;return {ID_ArticleFk:String(line.article.ID_Article),QteCmdDetail:String(line.QteCmdDetail).trim().replace(",","."),PUCmdDetail:String(line.PUCmdDetail).trim().replace(",","."),ObsCmdDetail:observation,LieuCmdDetail:String(line.LieuCmdDetail??"").trim()||null,RemiseCmdDetail:line.original?.RemiseCmdDetail??null,SelectCmdDetail:line.SelectCmdDetail??null,Lots:line.Lots.map(lot=>({NumeroLot:lot.NumeroLot.trim(),Quantite:String(lot.Quantite).trim(),DatePeremptionLot:lot.DatePeremptionLot||null,...(lot.MotifDerogationPeremption?.trim()?{MotifDerogationPeremption:lot.MotifDerogationPeremption.trim()}:{})}))};}
export function compositionBasketSnapshot(lines){return JSON.stringify(lines.map(linePayload));}
function sameNullableDecimal(left,right){return String(left??"").trim()===""&&String(right??"").trim()===""||compareDecimal(left,right)===0;}
export function compositionStockChanged(line){return !line.original||!sameNullableDecimal(line.QteCmdDetail,line.original.QteCmdDetail)||!sameNullableDecimal(line.PUCmdDetail,line.original.PUCmdDetail)||JSON.stringify(line.Lots)!==JSON.stringify(existingLots(line.original.Lots));}
export function compositionLotsUnchanged(line){return Boolean(line.original)&&sameNullableDecimal(line.QteCmdDetail,line.original.QteCmdDetail)&&JSON.stringify(line.Lots)===JSON.stringify(existingLots(line.original.Lots));}
export function compositionTotal(lines) {
  let cents=0n;
  for(const line of lines) {
    const amount=decimalParts(roundMoney(multiplyDecimal(line.QteCmdDetail,line.PUCmdDetail)));
    if(!amount||amount.units<0n||amount.scale>2)return null;
    cents+=amount.units*10n**BigInt(2-amount.scale);
  }
  return (cents/100n).toString()+"."+(cents%100n).toString().padStart(2,"0");
}
export function compositionHeaderErrors(values,references,record=null) {
  const errors=commandeErrors(values,record);
  const kind=compositionDirection(compositionType(references,values,record));
  if(!kind)errors.ID_TypeCmdFk="Choisissez un type de bon disponible.";
  if(record&&String(values.ID_TypeCmdFk)!==String(record.ID_TypeCmdFk)&&(stockDocumentKind(record)==="commande"||kind==="commande"))errors.ID_TypeCmdFk="Le type d’un bon de commande est conservé. Créez un bon distinct pour l’entrée ou la sortie effective.";
  if((!record||String(values.ID_DeviseFk)!==String(record.ID_DeviseFk))&&!(references?.currencies||[]).some(item=>String(item.id)===String(values.ID_DeviseFk)))errors.ID_DeviseFk="Choisissez une devise disponible.";
  return errors;
}
export function compositionLineErrors(line,direction) {
  const errors={},quantity=String(line.QteCmdDetail||"").trim(),price=String(line.PUCmdDetail??"").trim();
  const precision=Number.isInteger(line.article?.DecimalesStock)?line.article.DecimalesStock:null;
  if(quantityError(quantity,false,precision))errors.QteCmdDetail=quantityError(quantity,false,precision);
  if(!/^\d+(?:[.,]\d{1,2})?$/.test(price)||compareDecimal(price,"9999999999.99")===1)errors.PUCmdDetail="Renseignez le prix du document, avec deux décimales au maximum.";
  const amount=multiplyDecimal(quantity,price);
  if(amount&&compareDecimal(amount,"9999999999.99")===1)errors.PUCmdDetail="Le montant de cette ligne dépasse la limite autorisée.";
  if((line.article?.ValideArticle===false||line.article?.missing)&&compositionStockChanged(line))errors.article=line.original?"Cet article historique ne permet pas de modifier la quantité, le prix ou les lots.":"Cet article est inactif.";
  if(Array.from(String(line.ObsCmdDetail??"")).length>255)errors.ObsCmdDetail="Limitez l’observation à 255 caractères.";
  const place=String(line.LieuCmdDetail??"").trim();
  if(place&&(!/^\d+$/.test(place)||compareDecimal(place,"2147483647")===1))errors.LieuCmdDetail="Renseignez un identifiant de lieu valide.";
  if(line.RemiseCmdDetail!=null&&typeof line.RemiseCmdDetail!=="boolean")errors.RemiseCmdDetail="Choisissez une valeur de la liste.";
  if(line.SelectCmdDetail!=null&&typeof line.SelectCmdDetail!=="boolean")errors.SelectCmdDetail="Choisissez une valeur de la liste.";
  const stock=decimalParts(line.article?.QteArticle),original=decimalParts(line.original?.QteCmdDetail??"0");
  if(direction==="sortie"&&(!line.original||compositionStockChanged(line))){
    const scale=Math.max(stock?.scale||0,original?.scale||0),available=stock&&original?stock.units*10n**BigInt(scale-stock.scale)+original.units*10n**BigInt(scale-original.scale):null,requested=decimalParts(quantity);
    if(available==null||available<=0n)errors.QteCmdDetail="Cet article n’a pas de stock disponible.";
    else if(!errors.QteCmdDetail&&requested){const common=Math.max(scale,requested.scale);if(requested.units*10n**BigInt(common-requested.scale)>available*10n**BigInt(common-scale))errors.QteCmdDetail="La quantité dépasse le stock disponible pour ce bon.";}
  }
  return errors;
}
export function compositionPayload(values,lines,userId,record=null,version=null,references=null) {
  const bon=commandePayload(values,record,version,userId);
  for(const field of ["_version","CodeFacture","DateFacture","StatusFacture","ValideRemiseFacture","UrlFacture"])delete bon[field];
  const order=compositionDirection(compositionType(references,values,record))==="commande";
  return {...(record?{_version:version}:{}),bon,lignes:lines.map(line=>({...linePayload(line),...(order?{Lots:[]}: {})}))};
}
