import {formatCurrency,formatNumber} from "../pages/logistique/logistiqueShared";
import "./InvoiceTaxSummary.css";

export default function InvoiceTaxSummary({record={},currency,label="Totaux de facturation"}){
  record=record||{};
  const known=value=>value!=null&&value!=="";
  if(![record.MontantHT,record.MontantTVA,record.MontantTTC].some(known))return null;
  const items=[["Montant HT",record.MontantHT],["TVA"+(known(record.TauxTVA)?" ("+formatNumber(record.TauxTVA)+" %)":""),record.MontantTVA],["Montant TTC",record.MontantTTC]];
  return <dl className="invoice-tax-summary" aria-label={label}>{items.map(([title,value])=><div key={title}><dt>{title}</dt><dd>{formatCurrency(value,currency)}</dd></div>)}</dl>;
}
