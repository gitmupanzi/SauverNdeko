import {compareDecimal, multiplyDecimal, sameCurrency} from "../../utils/money";

export function lineKey(row) { return String(row.ID_CmdFk ?? row.ID_Commande)+":"+String(row.ID_ArticleFk); }
export function lineDirection(bon) {
  const sign=Number(bon?.SigneCommande);
  if(sign===1||bon?.EstCommandeEntree===true)return "entree";
  if(sign===-1||bon?.EstCommandeSortie===true)return "sortie";
  const label=String(bon?.TypeCmd||bon?.AbrTypeCmd||"").normalize("NFD").replace(/[\u0300-\u036f]/g,"").toLowerCase();
  return label.startsWith("entr")?"entree":label.startsWith("sort")?"sortie":"";
}
export function closedBon(bon) {
  return String(bon?.StatusFacture||"").normalize("NFD").replace(/[\u0300-\u036f]/g,"").trim().toLowerCase()==="cloturee";
}
export function lineForm(row=null,bonId="") {
  return {ID_CmdFk:String(row?.ID_CmdFk??bonId??""),ID_ArticleFk:String(row?.ID_ArticleFk??""),QteCmdDetail:row?.QteCmdDetail==null?"":String(row.QteCmdDetail),PUCmdDetail:row?.PUCmdDetail==null?"":String(row.PUCmdDetail),ObsCmdDetail:row?.ObsCmdDetail||"",LieuCmdDetail:row?.LieuCmdDetail==null?"":String(row.LieuCmdDetail),RemiseCmdDetail:row?.RemiseCmdDetail??null,SelectCmdDetail:row?.SelectCmdDetail??null};
}
export function lineLots(rows=[]) {return rows.map(row=>({NumeroLot:String(row.NumeroLot||""),Quantite:String(row.Quantite??""),DatePeremptionLot:row.DatePeremptionLot?String(row.DatePeremptionLot).slice(0,10):""}));}
export function linePrice(article,bon) {
  if(!article||!bon||!sameCurrency({currencyId:article.ID_DeviseFk},bon))return "";
  const direction=lineDirection(bon),price=direction==="entree"?article.PUArticle:direction==="sortie"?article.PVArticle:null;
  return price==null?"":String(price);
}
export function lineErrors(values,bon,article,previous=null) {
  const errors={};
  if(!/^[1-9]\d*$/.test(values.ID_CmdFk))errors.ID_CmdFk="Choisissez un bon de stock.";
  if(!/^[1-9]\d*$/.test(values.ID_ArticleFk))errors.ID_ArticleFk="Choisissez un article.";
  if(!/^[1-9]\d*$/.test(values.QteCmdDetail.trim())||Number(values.QteCmdDetail)>2147483647)errors.QteCmdDetail="Saisissez une quantité entière positive.";
  const price=values.PUCmdDetail.trim();
  if(!/^\d+(?:[.,]\d{1,2})?$/.test(price)||compareDecimal(price,"9999999999.99")===1)errors.PUCmdDetail="Saisissez un prix positif ou nul, avec deux décimales au maximum.";
  const amount=multiplyDecimal(values.QteCmdDetail,price);
  if(amount&&compareDecimal(amount,"9999999999.99")===1)errors.PUCmdDetail="Le montant de la ligne dépasse la limite autorisée.";
  if(values.LieuCmdDetail.trim()&&(!/^\d+$/.test(values.LieuCmdDetail.trim())||Number(values.LieuCmdDetail)>2147483647))errors.LieuCmdDetail="Saisissez un identifiant de lieu valide.";
  if(bon&&closedBon(bon))errors.ID_CmdFk="Ce bon est clôturé.";
  if(bon&&bon.ID_DeviseFk==null)errors.ID_CmdFk="Renseignez la devise du bon avant d’ajouter une ligne.";
  if(article?.ValideArticle===false)errors.ID_ArticleFk="Cet article est inactif.";
  if(lineDirection(bon)==="sortie"&&article?.QteArticle!=null&&!errors.QteCmdDetail) {
    const available=Number(article.QteArticle)+(previous?Number(previous.QteCmdDetail)||0:0);
    if(Number.isFinite(available)&&Number(values.QteCmdDetail)>available)errors.QteCmdDetail="La quantité dépasse le stock disponible.";
  }
  return errors;
}
export function linePayload(values,lots,version) {
  const data={ID_ArticleFk:values.ID_ArticleFk,QteCmdDetail:values.QteCmdDetail.trim(),PUCmdDetail:values.PUCmdDetail.trim().replace(",","."),ObsCmdDetail:values.ObsCmdDetail,LieuCmdDetail:values.LieuCmdDetail.trim()||null,RemiseCmdDetail:values.RemiseCmdDetail,SelectCmdDetail:values.SelectCmdDetail,Lots:lots.map(row=>({NumeroLot:row.NumeroLot.trim(),Quantite:String(row.Quantite),DatePeremptionLot:row.DatePeremptionLot||null}))};
  if(version)data._version=version;
  return data;
}
