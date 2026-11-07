export const validDemandId=value=>/^[1-9]\d*$/.test(String(value??""))?String(value):"";
export function demandSourceKey(source){return source&&["product","expert","structure_n3","structure_n4","structure_n5"].includes(source.type)&&validDemandId(source.id)?source.type+":"+source.id:"";}
export function demandQuantityError(value,source){
 const text=String(value??"").trim().replace(",",".").replace(/^0+(?=\d)/,"");
 if(!text)return "";
 if(source?.type!=="product")return "La quantité concerne uniquement un produit.";
 const decimals=Number.isInteger(source.quantityDecimals)?source.quantityDecimals:3;
 if(!/^(?:0|[1-9]\d{0,14})(?:\.\d{1,3})?$/.test(text)||!/[1-9]/.test(text))return "Saisissez une quantité positive, avec au plus trois décimales.";
 if((text.split(".")[1]||"").length>decimals)return decimals?`Cette unité accepte ${decimals} décimale${decimals>1?"s":""} au maximum.`:"Cette unité accepte uniquement des quantités entières.";
 return "";
}
export function demandDraftErrors(draft,source){return Object.fromEntries(Object.entries({subject:!draft.subject.trim()?"Précisez l’objet de la demande.":draft.subject.trim().length>160?"L’objet ne doit pas dépasser 160 caractères.":"",description:!draft.description.trim()?"Décrivez votre besoin.":draft.description.trim().length>5000?"La description ne doit pas dépasser 5 000 caractères.":"",quantity:demandQuantityError(draft.quantity,source),destination:draft.destination.trim().length>300?"Le lieu ne doit pas dépasser 300 caractères.":""}).filter(([,value])=>value));}
export function demandDraftPayload(draft,source,requestId){return {sourceType:source.type,sourceId:Number(source.id),subject:draft.subject.trim(),description:draft.description.trim(),destination:draft.destination.trim()||null,...(source.type==="product"?{quantity:draft.quantity.trim().replace(",",".").replace(/^0+(?=\d)/,"")||null}:{}),requestId};}
export function demandFailure(response,fallback){return response?.error?.code==="CONTEXT_CHANGED"?"Le contexte de travail a changé. Rouvrez la demande.":response?.message||fallback;}
export const demandDeliveryUncertain=response=>!response||response.status===0||response.status>=500;
