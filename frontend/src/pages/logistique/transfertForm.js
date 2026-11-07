import {quantityError} from '../../utils/quantities';
import {compareDecimal} from '../../utils/money';
import {commandeDateInput} from './commandeForm';
export const TRANSFER_STATES={TR_BROUILLON:'Brouillon',TR_VALIDE:'Validé',TR_TRANSIT:'En transit',TR_PARTIEL:'Réception partielle',TR_TERMINE:'Terminé',TR_ANNULE:'Annulé'};
export function transferForm(record,source='',currency=''){
 return {ID_DepotSourceFk:String(record?.ID_DepotSourceFk??source),ID_DepotDestinationFk:String(record?.ID_DepotDestinationFk??''),ID_DeviseFk:String(record?.ID_DeviseFk??currency),DateTransfert:commandeDateInput(record?.DateTransfert??new Date().toISOString()),Motif:record?.Motif||'',ReferenceTransfert:record?.ReferenceTransfert||'',lignes:(record?.lignes||[]).map(row=>({...row,ID_ArticleFk:String(row.ID_ArticleFk??row.ID_Article),QteDemandee:String(row.QteDemandee??''),Lots:row.Lots||[],ObsLigne:row.ObsLigne||''}))};
}
export function transferErrors(values){
 const errors=[];
 if(!/^[1-9]\d*$/.test(values.ID_DepotSourceFk))errors.push('Choisissez le dépôt de départ.');
 if(!/^[1-9]\d*$/.test(values.ID_DepotDestinationFk))errors.push('Choisissez le dépôt de destination.');
 if(values.ID_DepotSourceFk&&values.ID_DepotSourceFk===values.ID_DepotDestinationFk)errors.push('Choisissez deux dépôts différents.');
 if(!/^[1-9]\d*$/.test(values.ID_DeviseFk))errors.push('Choisissez la devise du transfert.');
 if(!values.DateTransfert||!Number.isFinite(Date.parse(values.DateTransfert)))errors.push('Indiquez une date et une heure valides.');
 if(!values.Motif.trim())errors.push('Précisez le motif du transfert.');
 if(!values.lignes.length)errors.push('Ajoutez au moins un article.');
 const ids=new Set();
 for(const line of values.lignes){if(ids.has(line.ID_ArticleFk))errors.push('Regroupez les quantités du même article.');ids.add(line.ID_ArticleFk);const issue=quantityError(line.QteDemandee,false,Number(line.DecimalesStock??line.Decimales??3));if(issue)errors.push((line.NomArticle||'Article')+' : '+issue);}
 return errors;
}
export function transferPayload(values){return {transfert:Object.fromEntries(Object.entries(values).filter(([key])=>key!=='lignes').map(([key,value])=>[key,String(value).trim()])),lignes:values.lignes.map(line=>({ID_ArticleFk:line.ID_ArticleFk,QteDemandee:line.QteDemandee.trim().replace(',','.'),Lots:line.Lots,ObsLigne:line.ObsLigne.trim()}))};}
export function transferActionLines(record,quantities,lots={}){return (record.lignes||[]).filter(row=>compareDecimal(quantities[row.ID_ArticleFk]||'0','0')===1).map(row=>({ID_ArticleFk:String(row.ID_ArticleFk),Quantite:String(quantities[row.ID_ArticleFk]).replace(',','.'),...(lots[row.ID_ArticleFk]?.length?{Lots:lots[row.ID_ArticleFk]}:{})}));}
