export const PRODUCT_OFFERS_ROOT="/api/produits";
export const EMPTY_OFFER_CRITERIA={q:"",categoryId:"",typeId:"",companyId:"",currencyId:"",availability:""};
export const OFFER_PAGE_SIZES=[10,25,50,100];
export function offerId(record={}){return String(record.ID_Article??"");}
export function offerName(record={}){return record.NomArticle||"Produit";}
export function validOfferId(value){return /^[1-9]\d*$/.test(String(value??""))?String(value):"";}
export function offerOptions(items=[],empty="Tous"){
 return [{value:"",label:empty},...items.filter(item=>item?.id!=null).map(item=>({value:String(item.id),label:String(item.label||item.id),disabled:item.disabled===true}))];
}
export function keepOfferFilter(options,value){return !value||options.some(option=>option.value===value)?options:[...options,{value,label:"Valeur sélectionnée indisponible",disabled:true}];}
export function offerLocation(params){
 const criteria=Object.fromEntries(Object.keys(EMPTY_OFFER_CRITERIA).map(key=>[key,params.get(key)||""]));
 const size=Number(params.get("take")),offset=Number(params.get("skip"));
 return {criteria,grid:{take:OFFER_PAGE_SIZES.includes(size)?size:25,skip:Number.isSafeInteger(offset)&&offset>=0?offset:0,sortBy:params.get("sortBy")==="company"?"company":"name",sortDir:params.get("sortDir")==="desc"?"desc":"asc"},focusId:validOfferId(params.get("offre"))};
}
export function offerQuery(criteria,grid){
 const query=new URLSearchParams();
 for(const [key,value] of Object.entries({...criteria,...grid}))if(value!==""&&value!=null)query.set(key,String(value));
 return query;
}
export function offerParams(params,criteria,grid){
 const next=new URLSearchParams(params);
 for(const key of [...Object.keys(EMPTY_OFFER_CRITERIA),"take","skip","sortBy","sortDir"])next.delete(key);
 for(const [key,value] of offerQuery(criteria,grid))next.set(key,value);
 return next;
}
export function offerSearchError(criteria){return Array.from(criteria.q||"").length>200?"Limitez la recherche à 200 caractères.":"";}
export function offerResponse(response){
 const data=response?.data;
 if(!response?.success||!Array.isArray(data?.rows)||data.total==null||!Number.isSafeInteger(Number(data.total))||Number(data.total)<data.rows.length||!data.rows.every(row=>validOfferId(row?.ID_Article))||new Set(data.rows.map(offerId)).size!==data.rows.length)return null;
 return {rows:data.rows,total:Number(data.total)};
}
export function offerError(response,fallback){
 return response?.status===403?"Votre accès ne permet pas de consulter ces offres.":response?.status===401?"Reconnectez-vous pour consulter les offres.":response?.status===404?"Cette offre n’est plus disponible dans l’annuaire.":response?.message||fallback;
}
export function offerLastPage(total,take){return total?Math.floor((total-1)/take)*take:0;}
