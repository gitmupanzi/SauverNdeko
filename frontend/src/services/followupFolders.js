import { requestJson } from "./api";
export function folderRequest(path,options={}) {
  return requestJson(path,{...options,requiresAuth:true,...(options.body == null?{}:{body:JSON.stringify(options.body)})});
}

export const FOLDER_OBJECT_LABELS={article:"Articles",bon:"Bons de stock",facture:"Factures"};
export const FOLDER_UNITS={article:"article",bon:"bon",facture:"facture"};
export const FOLDER_VIEWS=[{key:"list",label:"Liste",icon:"list"},{key:"compact",label:"Compact",icon:"rows-compact"},{key:"table",label:"Tableau",icon:"table"},{key:"cards",label:"Cartes",icon:"dashboard"}];
