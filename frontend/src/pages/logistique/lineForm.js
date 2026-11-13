import {quantityError,quantityUnits} from "../../utils/quantities";
import {compareDecimal, multiplyDecimal, sameCurrency} from "../../utils/money";
import {stockDocumentKind} from "../../utils/stockDocumentTypes";
import {categoricalKey} from "../../utils/categoricalValues";

export function lineKey(row) { return String(row.ID_CmdFk ?? row.ID_Commande)+":"+String(row.ID_ArticleFk); }
export const lineDirection=stockDocumentKind;
export function closedBon(bon) {
  return /^cl[oô]tur[ée]e$/.test(categoricalKey(bon?.StatusFacture));
}
export function lineForm(row=null,bonId="") {
  return {ID_CmdFk:String(row?.ID_CmdFk??bonId??""),ID_ArticleFk:String(row?.ID_ArticleFk??""),QteCmdDetail:row?.QteCmdDetail==null?"":String(row.QteCmdDetail),PUCmdDetail:row?.PUCmdDetail==null?"":String(row.PUCmdDetail),ObsCmdDetail:row?.ObsCmdDetail||"",LieuCmdDetail:row?.LieuCmdDetail==null?"":String(row.LieuCmdDetail),RemiseCmdDetail:row?.RemiseCmdDetail??null,SelectCmdDetail:row?.SelectCmdDetail??null};
}
export function lineLots(rows=[]) {return rows.map(row=>({NumeroLot:String(row.NumeroLot||""),Quantite:String(row.Quantite??""),DatePeremptionLot:row.DatePeremptionLot?String(row.DatePeremptionLot).slice(0,10):"",MotifDerogationPeremption:row.MotifDerogationPeremption||""}));}
export function linePrice(article,bon) {
  if(!article||!bon||!sameCurrency({currencyId:article.ID_DeviseFk},bon))return "";
  const direction=lineDirection(bon),price=direction==="entree"?article.PUArticle:direction==="sortie"?article.PVArticle:null;
  return price==null?"":String(price);
}
export function lineErrors(values,bon,article,previous=null) {
  const errors={};
  if(!/^[1-9]\d*$/.test(values.ID_CmdFk))errors.ID_CmdFk="Choisissez un bon de stock.";
  if(!/^[1-9]\d*$/.test(values.ID_ArticleFk))errors.ID_ArticleFk="Choisissez un article.";
  const precision=Number.isInteger(article?.DecimalesStock)?article.DecimalesStock:null;
  if(quantityError(values.QteCmdDetail,false,precision))errors.QteCmdDetail=quantityError(values.QteCmdDetail,false,precision);
  const price=values.PUCmdDetail.trim();
  if(!/^\d+(?:[.,]\d{1,2})?$/.test(price)||compareDecimal(price,"9999999999.99")===1)errors.PUCmdDetail="Saisissez un prix positif ou nul, avec deux décimales au maximum.";
  const amount=multiplyDecimal(values.QteCmdDetail,price);
  if(amount&&compareDecimal(amount,"9999999999.99")===1)errors.PUCmdDetail="Le montant de la ligne dépasse la limite autorisée.";
  if(values.LieuCmdDetail.trim()&&(!/^\d+$/.test(values.LieuCmdDetail.trim())||Number(values.LieuCmdDetail)>2147483647))errors.LieuCmdDetail="Saisissez un identifiant de lieu valide.";
  if(bon&&closedBon(bon))errors.ID_CmdFk="Ce bon est clôturé.";
  if(bon&&!lineDirection(bon))errors.ID_CmdFk="Ce type de bon ne permet pas de préparer des lignes.";
  if(bon&&bon.ID_DeviseFk==null)errors.ID_CmdFk="Renseignez la devise du bon avant d’ajouter une ligne.";
  if(article?.ValideArticle===false)errors.ID_ArticleFk="Cet article est inactif.";
  if(lineDirection(bon)==="sortie"&&article?.QteArticle!=null&&!errors.QteCmdDetail) {
    const stock=quantityUnits(article.QteArticle),old=quantityUnits(previous?.QteCmdDetail??"0"),requested=quantityUnits(values.QteCmdDetail);
    if(stock!=null&&old!=null&&requested!=null&&requested>stock+old)errors.QteCmdDetail="La quantité dépasse le stock disponible.";
  }
  return errors;
}
export function linePayload(values,lots,version,bon=null) {
  const data={ID_ArticleFk:values.ID_ArticleFk,QteCmdDetail:values.QteCmdDetail.trim().replace(",","."),PUCmdDetail:values.PUCmdDetail.trim().replace(",","."),ObsCmdDetail:values.ObsCmdDetail,LieuCmdDetail:values.LieuCmdDetail.trim()||null,RemiseCmdDetail:values.RemiseCmdDetail,SelectCmdDetail:values.SelectCmdDetail,Lots:lots.map(row=>({NumeroLot:row.NumeroLot.trim(),Quantite:String(row.Quantite),DatePeremptionLot:row.DatePeremptionLot||null,...(row.MotifDerogationPeremption?.trim()?{MotifDerogationPeremption:row.MotifDerogationPeremption.trim()}:{})}))};
  if(version)data._version=version;
  if(lineDirection(bon)==="commande")data.Lots=[];
  return data;
}
