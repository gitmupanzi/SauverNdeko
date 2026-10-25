import {quantityUnits,quantityString} from './quantities';
export {quantityString};
// Nom conservé pour les consommateurs existants ; valeur interne = milli-unités.
export const wholeQuantity=quantityUnits;
export function allocatedQuantity(rows=[]){let sum=0n;for(const row of rows){const value=quantityUnits(row.Quantite);if(value==null)return null;sum+=value;}return sum;}
export function lotNumber(value){return String(value??'').trim().toLocaleLowerCase('fr');}
export function lotAvailability(meta,rows=[],previous=null){
 const source=meta?.lotStock??meta,without=quantityUnits(source?.stockWithoutLot),total=quantityUnits(source?.stockTotal),allocated=quantityUnits(source?.stockAllocated);
 if(without==null||total==null||allocated==null)return null;
 const oldQuantity=quantityUnits(previous?.QteCmdDetail??'0'),oldAllocated=allocatedQuantity(previous?.Lots||[]);
 if(oldQuantity==null||oldAllocated==null||oldAllocated>oldQuantity)return null;
 const original=new Map();for(const row of previous?.Lots||[]){const key=lotNumber(row.NumeroLot),value=quantityUnits(row.Quantite);if(value==null)return null;original.set(key,(original.get(key)||0n)+value);}
 const choices=rows.map(row=>{const stock=quantityUnits(row.StockLot),released=original.get(lotNumber(row.NumeroLot))||0n;return {...row,availableForLine:stock==null?null:quantityString(stock+released)};});
 return {stockTotal:quantityString(total),stockAllocated:quantityString(allocated),stockWithoutLot:quantityString(without),stockWithoutLotForLine:quantityString(without+oldQuantity-oldAllocated),rows:choices};
}
export function requiredLotQuantity(total,availability){const quantity=quantityUnits(total),without=quantityUnits(availability?.stockWithoutLotForLine);return quantity==null||without==null?null:quantityString(quantity>without?quantity-without:0n);}
export function outgoingLotError(rows,total,availability){
 if(!availability)return '';const quantity=quantityUnits(total),assigned=allocatedQuantity(rows),minimum=quantityUnits(requiredLotQuantity(total,availability));
 if(quantity==null||assigned==null||minimum==null)return '';
 if(assigned>quantity)return 'La quantité ventilée dépasse la quantité de cette ligne.';
 if(assigned<minimum)return 'Sélectionnez les lots à sortir : au moins '+quantityString(minimum)+' unité(s) doivent être ventilées.';
 const known=new Map(availability.rows.map(row=>[lotNumber(row.NumeroLot),row]));
 for(const row of rows){const lot=known.get(lotNumber(row.NumeroLot)),requested=quantityUnits(row.Quantite);
  if(!lot)return 'Choisissez un lot déjà reçu pour cet article.';
  if(lot.Actif===false)return 'Le lot '+lot.NumeroLot+' est archivé. Choisissez un lot disponible.';
  const available=quantityUnits(lot.availableForLine);if(requested!=null&&available!=null&&requested>available)return 'Le lot '+lot.NumeroLot+' dispose de '+quantityString(available)+' unité(s) pour cette ligne.';
 }return '';
}
export function unchangedLotAllocation(rows,total,previous){if(!previous||quantityUnits(total)!==quantityUnits(previous.QteCmdDetail))return false;const signature=items=>items.map(row=>[lotNumber(row.NumeroLot),quantityString(quantityUnits(row.Quantite)),String(row.DatePeremptionLot||'').slice(0,10)]).sort((a,b)=>a[0].localeCompare(b[0]));return JSON.stringify(signature(rows))===JSON.stringify(signature(previous.Lots||[]));}
