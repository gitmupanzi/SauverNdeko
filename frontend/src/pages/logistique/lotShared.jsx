import {categoricalKey} from "../../utils/categoricalValues";
import {formatNumber} from "./logistiqueShared";
import {recordExcel} from "../../utils/rowDocuments";
export function LotState({value}){if(value==null||value==="")return "—";const v=categoricalKey(value),tone=/p[ée]rim[ée]|n[ée]gatif/.test(v)?"danger":/proche/.test(v)?"warning":/disponible|valide|actif/.test(v)?"success":"neutral";return <span className={"erp-status is-"+tone}>{value}</span>;}
export function LotQuantity({value,unit}){return <span className="erp-stock-quantity">{formatNumber(value)}<small>{unit||"Unité non renseignée"}</small></span>;}
export const lotExcel=lotId=>recordExcel("lots",{ID_LotArticle:lotId},"Fiche du lot");
