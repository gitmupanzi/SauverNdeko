import {useId} from "react";
import ActionButton from "./ActionButton";
import AppIcon from "./AppIcon";
import "./RecordEditor.css";
export function lotErrors(rows,total){
 if(!rows.length)return "";
 const numbers=new Set();
 for(const row of rows){
  if(!row.NumeroLot.trim()||row.NumeroLot.trim().length>100)return "Renseignez un numéro de lot de 100 caractères au maximum.";
  const key=row.NumeroLot.trim().toLocaleLowerCase();
  if(numbers.has(key))return "Regroupez les quantités d’un même numéro de lot.";numbers.add(key);
  if(!/^[1-9]\d*$/.test(String(row.Quantite))||Number(row.Quantite)>2147483647)return "Renseignez une quantité entière positive pour chaque lot.";
 }
 return rows.reduce((sum,row)=>sum+Number(row.Quantite),0)!==Number(total)?"La somme des lots doit correspondre à la quantité saisie.":"";
}
export default function LotFields({value,onChange,total,disabled=false,known=[],outgoing=false,title="Lots reçus",error=""}){
 const id=useId();
 function update(index,key,next){onChange(value.map((row,i)=>i===index?{...row,[key]:next}:row));}
 return <section className="record-editor-section lot-fields"><h3><AppIcon name="box"/>{title}</h3>
  {value.map((row,index)=><div className="lot-fields-row" key={index}><label><span>N° de lot</span><input list={id} value={row.NumeroLot} maxLength={100} disabled={disabled} onChange={e=>update(index,"NumeroLot",e.target.value)} aria-label={"Numéro du lot "+(index+1)}/></label><label><span>Quantité</span><input inputMode="numeric" value={row.Quantite} disabled={disabled} onChange={e=>update(index,"Quantite",e.target.value)} aria-label={"Quantité du lot "+(index+1)}/></label>{!outgoing?<label><span>Péremption du lot</span><input type="date" value={row.DatePeremptionLot||""} disabled={disabled} onChange={e=>update(index,"DatePeremptionLot",e.target.value)} aria-label={"Péremption du lot "+(index+1)}/></label>:null}<ActionButton icon="close" className="is-icon" disabled={disabled} aria-label={"Retirer le lot "+(index+1)} onClick={()=>onChange(value.filter((_,i)=>i!==index))}/></div>)}
  <datalist id={id}>{known.map(row=><option key={row.ID_LotArticle} value={row.NumeroLot}>{row.StockLot+" en stock"}</option>)}</datalist>
  <ActionButton icon="plus" disabled={disabled||value.length>=50} onClick={()=>onChange([...value,{NumeroLot:"",Quantite:value.length?"":String(total||""),DatePeremptionLot:""}])}>Ajouter un lot</ActionButton>
  <p className="record-editor-note">{outgoing?"Utilisez les numéros de lot déjà reçus.":"Renseignez le numéro indiqué sur les produits ou le bon de livraison."}{value.length?" Total ventilé : "+value.reduce((sum,row)=>sum+(Number(row.Quantite)||0),0)+" / "+(total||0)+".":""}</p>
  {error?<p className="record-field-error" role="alert">{error}</p>:null}
 </section>;
}
