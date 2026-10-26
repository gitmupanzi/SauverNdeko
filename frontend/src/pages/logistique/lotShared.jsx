import {formatNumber} from "./logistiqueShared";
export function LotState({value}){if(value==null||value==="")return "—";const v=String(value).normalize("NFD").replace(/[\u0300-\u036f]/g,"").toLowerCase(),tone=/perime|negatif/.test(v)?"danger":/proche/.test(v)?"warning":/disponible|valide|actif/.test(v)?"success":"neutral";return <span className={"erp-status is-"+tone}>{value}</span>;}
export function LotQuantity({value,unit}){return <span className="erp-stock-quantity">{formatNumber(value)}<small>{unit||"Unité non renseignée"}</small></span>;}
export const lotExcel=lotId=>({label:"Fiche du lot · Excel",url:"/api/logistique/registre/lots/export.xlsx?"+new URLSearchParams({lotId:String(lotId),timeZone:"Africa/Kinshasa"}),filename:"lot-"+lotId+".xlsx"});
