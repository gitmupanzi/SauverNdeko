import {useId} from "react";
import {useAuth} from "../contexts/AuthContext";
import ActionButton from "./ActionButton";
import AppIcon from "./AppIcon";
import SearchSelect from "./SearchSelect";
import {allocatedQuantity,wholeQuantity,quantityString,requiredLotQuantity,outgoingLotError} from "../utils/lotAllocation";
import {quantityError} from "../utils/quantities";
import FefoSuggestion from "./FefoSuggestion";
import "./RecordEditor.css";
import "./LotFields.css";
export function lotErrors(rows,total,{outgoing=false,availability=null}={}){
 const numbers=new Set();
 for(const row of rows){
  if(!row.NumeroLot.trim()||row.NumeroLot.trim().length>100)return "Renseignez un numéro de lot de 100 caractères au maximum.";
  const key=row.NumeroLot.trim().toLocaleLowerCase('fr');
  if(numbers.has(key))return "Regroupez les quantités d’un même numéro de lot.";numbers.add(key);
  if(quantityError(row.Quantite))return quantityError(row.Quantite);
 }
 const assigned=allocatedQuantity(rows),quantity=wholeQuantity(total);
 if(outgoing){
  if(assigned!=null&&quantity!=null&&assigned>quantity)return "La quantité ventilée dépasse la quantité de cette ligne.";
  return outgoingLotError(rows,total,availability);
 }
 return rows.length&&assigned!==quantity?"La somme des lots doit correspondre à la quantité saisie.":"";
}
function displayQuantity(value){const number=wholeQuantity(value);return number==null?'—':quantityString(number).replace('.',',');}
export default function LotFields({value,onChange,total,disabled=false,known=[],outgoing=false,title="Lots reçus",error="",availability=null,loading=false,unit="",articleId=null}){
 const {user}=useAuth();
 const id=useId(),assigned=allocatedQuantity(value),quantity=wholeQuantity(total),remainder=quantity!=null&&assigned!=null&&quantity>=assigned?quantityString(quantity-assigned):null,minimum=requiredLotQuantity(total,availability);
 const rows=availability?.rows||known;
 const today=new Intl.DateTimeFormat("en-CA",{timeZone:"Africa/Kinshasa",year:"numeric",month:"2-digit",day:"2-digit"}).format(new Date());
 const expired=row=>Boolean(row?.DatePeremptionLot)&&String(row.DatePeremptionLot).slice(0,10)<today;
 const options=rows.map(row=>({value:String(row.NumeroLot),label:row.NumeroLot+' · '+displayQuantity(row.availableForLine??row.StockLot)+(unit?' '+unit:'')+' disponible(s)'+(expired(row)?' · Périmé':row.DatePeremptionLot?' · '+String(row.DatePeremptionLot).slice(0,10):''),disabled:row.Actif===false||wholeQuantity(row.availableForLine??row.StockLot)===0n}));
 const hasAvailable=options.some(option=>!option.disabled);
 function update(index,key,next){onChange(value.map((row,i)=>i===index?{...row,[key]:next}:row));}
 function choose(index,number){const row=rows.find(item=>String(item.NumeroLot)===number);onChange(value.map((item,i)=>i===index?{...item,NumeroLot:number,DatePeremptionLot:row?.DatePeremptionLot?String(row.DatePeremptionLot).slice(0,10):item.DatePeremptionLot||''}:item));}
 return <section className="record-editor-section lot-fields" aria-busy={loading}>
  <h3><AppIcon name="box"/>{title}</h3>
  {outgoing&&availability?<div className="lot-fields-stock" role="status"><span>Stock sans lot disponible <strong>{displayQuantity(availability.stockWithoutLotForLine)} {unit}</strong></span>{minimum!=null&&wholeQuantity(minimum)>0n?<span className="lot-fields-required">À ventiler au minimum <strong>{displayQuantity(minimum)} {unit}</strong></span>:<span>Ventilation facultative pour cette quantité.</span>}</div>:null}
  {outgoing&&articleId?<FefoSuggestion articleId={articleId} total={total} disabled={disabled||loading} onApply={onChange}/>:null}
  {loading?<p className="record-editor-note" role="status">Chargement des lots disponibles…</p>:null}
  {value.map((row,index)=>{const choices=options.some(option=>option.value===row.NumeroLot)||!row.NumeroLot?options:[{value:row.NumeroLot,label:row.NumeroLot+' · valeur actuelle',disabled:true},...options];return <div className="lot-fields-row" key={index}>
   <label htmlFor={id+'-number-'+index}><span>N° de lot</span>{outgoing?<SearchSelect id={id+'-number-'+index} label={'Numéro du lot '+(index+1)} value={row.NumeroLot} options={choices} disabled={disabled||loading} onChange={number=>choose(index,number)} describedBy={error?id+'-error':undefined} invalid={Boolean(error)} placeholder="Choisir un lot reçu…"/>:<input id={id+'-number-'+index} value={row.NumeroLot} maxLength={100} disabled={disabled} onChange={event=>update(index,'NumeroLot',event.target.value)} aria-label={'Numéro du lot '+(index+1)}/>}</label>
   <label htmlFor={id+'-quantity-'+index}><span>Quantité</span><input id={id+'-quantity-'+index} inputMode="decimal" value={row.Quantite} disabled={disabled||loading} onChange={event=>update(index,'Quantite',event.target.value)} aria-label={'Quantité du lot '+(index+1)}/></label>
   {!outgoing?<label htmlFor={id+'-expiry-'+index}><span>Péremption du lot</span><input id={id+'-expiry-'+index} type="date" value={row.DatePeremptionLot||''} disabled={disabled} onChange={event=>update(index,'DatePeremptionLot',event.target.value)} aria-label={'Péremption du lot '+(index+1)}/></label>:null}
   <ActionButton icon="close" className="is-icon" disabled={disabled||loading} aria-label={'Retirer le lot '+(index+1)} onClick={()=>onChange(value.filter((_,i)=>i!==index))}/>
   {outgoing&&expired(rows.find(item=>item.NumeroLot===row.NumeroLot))&&user?.Is_Admin===true?<label className="lot-fields-override" htmlFor={id+'-override-'+index}><span>Motif de dérogation</span><input id={id+'-override-'+index} value={row.MotifDerogationPeremption||''} minLength={10} maxLength={1000} disabled={disabled||loading} onChange={event=>update(index,'MotifDerogationPeremption',event.target.value)} placeholder="Précisez la raison de ce prélèvement périmé…"/><small>Réservé à l’administration. Obligatoire si l’entreprise bloque les lots périmés.</small></label>:null}
  </div>;})}
  <ActionButton icon="plus" disabled={disabled||loading||value.length>=50||outgoing&&!hasAvailable} onClick={()=>onChange([...value,{NumeroLot:'',Quantite:outgoing?'':value.length?'':String(total||''),DatePeremptionLot:''}])}>Ajouter un lot</ActionButton>
  {outgoing&&value.some(lot=>expired(rows.find(row=>row.NumeroLot===lot.NumeroLot)))?<p className="record-field-error" role="status">Un lot sélectionné est périmé. Vérifiez son utilisation avant de confirmer la sortie.</p>:null}
  {outgoing&&!loading&&!hasAvailable?<p className="record-editor-note">Aucun lot disponible pour cette ligne.</p>:null}
  {value.length||outgoing?<div className="lot-fields-allocation" role="status"><span>Quantité ventilée <strong>{displayQuantity(quantityString(assigned))} {unit}</strong></span><span>{outgoing?'Quantité sans lot':'Quantité de la ligne'} <strong>{displayQuantity(outgoing?remainder:total)} {unit}</strong></span></div>:null}
  <p className="record-editor-note">{outgoing?'Sélectionnez les lots réellement sortis. La quantité restante utilise uniquement le stock sans lot disponible.':'Renseignez le numéro indiqué sur les produits ou le bon de livraison.'}</p>
  {error?<p id={id+'-error'} className="record-field-error" role="alert">{error}</p>:null}
 </section>;
}
