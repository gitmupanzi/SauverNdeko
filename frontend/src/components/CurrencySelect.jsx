import { useId } from "react";
import SearchSelect from "./SearchSelect";
import { currencyOptions } from "../utils/money";

export default function CurrencySelect({ references, value, onChange, filter=false, disabled=false, label="Devise", hint="", currentCode="" }) {
  const id=useId();
  const options=currencyOptions(references,filter);
  if (value && !options.some(option=>option.value===String(value))) options.unshift({value:String(value),label:currentCode || "Devise actuelle"});
  return <div className="admin-form-field"><label htmlFor={id}>{label}</label><SearchSelect id={id} label={label} value={String(value ?? "")} options={[{value:"",label:filter?"Toutes les devises":"Choisir une devise"},...options]} onChange={onChange} disabled={disabled} describedBy={hint?id+"-hint":undefined}/>{hint?<small id={id+"-hint"}>{hint}</small>:null}</div>;
}
