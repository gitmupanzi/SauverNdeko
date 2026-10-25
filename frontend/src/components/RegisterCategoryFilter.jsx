import {useId} from "react";
import SearchSelect from "./SearchSelect";
import "./RegisterCategoryFilter.css";
export default function RegisterCategoryFilter({label="Afficher",value,options,onChange,disabled=false,className=""}){
 const id=useId();
 return <div className={"register-category-filter "+className}><div className="register-category-filter-field"><label htmlFor={id}>{label}</label><SearchSelect id={id} label={label} value={value} options={options} onChange={onChange} disabled={disabled}/></div></div>;
}
