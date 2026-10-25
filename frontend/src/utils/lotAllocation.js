import {decimalParts} from './money';

export function wholeQuantity(value){
 const number=decimalParts(value);
 if(!number||number.units<0n)return null;
 const factor=10n**BigInt(number.scale);
 return number.units%factor===0n?number.units/factor:null;
}
export function allocatedQuantity(rows=[]){
 let sum=0n;
 for(const row of rows){const value=wholeQuantity(row.Quantite);if(value==null)return null;sum+=value;}
 return sum;
}
export function lotNumber(value){return String(value??'').trim().toLocaleLowerCase('fr');}
export function lotAvailability(meta,rows=[],previous=null){
 const source=meta?.lotStock??meta;
 const without=wholeQuantity(source?.stockWithoutLot),total=wholeQuantity(source?.stockTotal),allocated=wholeQuantity(source?.stockAllocated);
 if(without==null||total==null||allocated==null)return null;
 const oldQuantity=wholeQuantity(previous?.QteCmdDetail??'0'),oldAllocated=allocatedQuantity(previous?.Lots||[]);
 if(oldQuantity==null||oldAllocated==null||oldAllocated>oldQuantity)return null;
 const original=new Map();
 for(const row of previous?.Lots||[]){const key=lotNumber(row.NumeroLot),value=wholeQuantity(row.Quantite);if(value==null)return null;original.set(key,(original.get(key)||0n)+value);}
 const choices=rows.map(row=>{const stock=wholeQuantity(row.StockLot),released=original.get(lotNumber(row.NumeroLot))||0n;return {...row,availableForLine:stock==null?null:(stock+released).toString()};});
 return {stockTotal:total.toString(),stockAllocated:allocated.toString(),stockWithoutLot:without.toString(),stockWithoutLotForLine:(without+oldQuantity-oldAllocated).toString(),rows:choices};
}
export function requiredLotQuantity(total,availability){
 const quantity=wholeQuantity(total),without=wholeQuantity(availability?.stockWithoutLotForLine);
 return quantity==null||without==null?null:(quantity>without?quantity-without:0n).toString();
}
export function outgoingLotError(rows,total,availability){
 if(!availability)return '';
 const quantity=wholeQuantity(total),assigned=allocatedQuantity(rows),minimum=wholeQuantity(requiredLotQuantity(total,availability));
 if(quantity==null||assigned==null||minimum==null)return '';
 if(assigned>quantity)return 'La quantité ventilée dépasse la quantité de cette ligne.';
 if(assigned<minimum)return 'Sélectionnez les lots à sortir : au moins '+minimum.toString()+' unité(s) doivent être ventilées.';
 const known=new Map(availability.rows.map(row=>[lotNumber(row.NumeroLot),row]));
 for(const row of rows){const lot=known.get(lotNumber(row.NumeroLot)),requested=wholeQuantity(row.Quantite);
  if(!lot)return 'Choisissez un lot déjà reçu pour cet article.';
  if(lot.Actif===false)return 'Le lot '+lot.NumeroLot+' est archivé. Choisissez un lot disponible.';
  const available=wholeQuantity(lot.availableForLine);
  if(requested!=null&&available!=null&&requested>available)return 'Le lot '+lot.NumeroLot+' dispose de '+available.toString()+' unité(s) pour cette ligne.';
 }
 return '';
}

export function unchangedLotAllocation(rows,total,previous){
 if(!previous||wholeQuantity(total)!==wholeQuantity(previous.QteCmdDetail))return false;
 const signature=items=>items.map(row=>[lotNumber(row.NumeroLot),wholeQuantity(row.Quantite)?.toString()??null,String(row.DatePeremptionLot||'').slice(0,10)]).sort((a,b)=>a[0].localeCompare(b[0]));
 return JSON.stringify(signature(rows))===JSON.stringify(signature(previous.Lots||[]));
}
