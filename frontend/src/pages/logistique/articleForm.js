import {computeArticleAlertDate,getLogistiqueCrudConfig} from "./views";
const CONFIG=getLogistiqueCrudConfig("articles");
const NUMERIC=["CodeArticleExterne","QteMinArticle","PUArticle","PVArticle","PoidsUnitaire","ID_UnitePoidsFk","ID_DeviseFk"];
export function articleForm(record){
  if(!record)return CONFIG.createFormState();
  const form=CONFIG.mapRecordToForm(record);
  return {...form,
    QteArticle:record.QteArticle==null?"":String(record.QteArticle),
    CodeArticleExterne:record.CodeArticleExterne==null?"":String(record.CodeArticleExterne),
    NbreJoursAlerteArticle:record.NbreJoursAlerteArticle==null?"":String(record.NbreJoursAlerteArticle),
    DatePeremptionAlerteArticle:record.DatePeremptionAlerteArticle?new Date(record.DatePeremptionAlerteArticle).toISOString().slice(0,10):"",
  };
}
export function articleErrors(values,creating){
  const errors={};
  if(creating&&!/^[1-9]\d*$/.test(String(values.ID_DeviseFk||"")))errors.ID_DeviseFk="Choisissez une devise.";
  if(!values.NomArticle.trim())errors.NomArticle="Renseignez le nom de l’article.";
  if(creating)for(const [key,label] of [["ID_CategorieArticleFk","une catégorie"],["ID_TypeArticleFk","un type"],["ID_UniteFk","une unité"]])if(!values[key])errors[key]="Choisissez "+label+".";
  for(const key of ["PUArticle","PVArticle"]){
    if(!/^\d{1,10}(?:[.,]\d{1,2})?$/.test(String(values[key]).trim()))errors[key]="Renseignez un montant positif ou nul, avec deux décimales au maximum.";
  }
  for(const [key,max] of [["QteMinArticle",2147483647],["CodeArticleExterne",2147483647],["NbreJoursAlerteArticle",36500],...(creating?[["QteArticle",2147483647]]:[])]){
    const value=String(values[key]??"").trim();
    if(value!==""&&(!/^\d+$/.test(value)||Number(value)>max))errors[key]="Renseignez un entier entre 0 et "+max.toLocaleString("fr-FR")+".";
  }
  if(String(values.CodeArticleExterne??"").trim()!==""&&Number(values.CodeArticleExterne)<1)errors.CodeArticleExterne="Le code externe doit être supérieur à zéro.";
  if(String(values.NbreJoursAlerteArticle??"").trim()!==""&&!values.DatePeremptionArticle)errors.DatePeremptionArticle="Renseignez une date pour définir l’alerte.";
  if(values.PoidsUnitaire!==""&&!/^\d{1,8}(?:[.,]\d{1,6})?$/.test(values.PoidsUnitaire.trim()))errors.PoidsUnitaire="Renseignez un poids positif ou nul, avec six décimales au maximum.";
  if(Boolean(values.PoidsUnitaire)!==Boolean(values.ID_UnitePoidsFk))errors.PoidsUnitaire="Renseignez le poids et son unité, ou laissez les deux vides.";
  return errors;
}
export function articlePayload(values,record,version){
  const payload={...values};
  delete payload.ID_UserFK;
  delete payload.DatePeremptionAlerteArticle;
  for(const key of ["ID_TypeArticleFk","ID_CategorieArticleFk","ID_UniteFk",...NUMERIC,"NbreJoursAlerteArticle"])payload[key]=String(values[key]??"").trim().replace(",",".")||null;
  if(payload.CodeArticleExterne!=null&&/^\d+$/.test(payload.CodeArticleExterne))payload.CodeArticleExterne=String(BigInt(payload.CodeArticleExterne));
  for(const key of ["NomArticle","RefArticle","CodeArticleInterne","PhotoArticle","ObsArticle","InformationArticle"])payload[key]=values[key].trim()||(key==="NomArticle"?"":null);
  payload.DatePeremptionArticle=values.DatePeremptionArticle||null;
  if(record){
    delete payload.QteArticle;
    const previous=articleForm(record);
    for(const key of Object.keys(payload))if(String(payload[key]??"")===String(previous[key]??""))delete payload[key];
    payload._version=version;
  }else payload.QteArticle=String(values.QteArticle||"0").trim();
  return payload;
}
export function alertDate(values,record){
  if(record){
    const previous=articleForm(record);
    if(values.DatePeremptionArticle===previous.DatePeremptionArticle&&values.NbreJoursAlerteArticle===previous.NbreJoursAlerteArticle)return previous.DatePeremptionAlerteArticle;
  }
  return values.NbreJoursAlerteArticle===""?"":computeArticleAlertDate(values.DatePeremptionArticle,values.NbreJoursAlerteArticle);
}
