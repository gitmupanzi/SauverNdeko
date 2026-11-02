const TYPES=new Set(["MODULE","FONCTIONNALITE"]);
export function applicationType(item){return item?.type||item?.TypeApplication||null;}
export function applicationCommercialisable(item){return item?.commercialisable??item?.Commercialisable;}
export function applicationParent(item){return item?.parentModule??item?.ModuleParentCode??null;}
export function applicationClassificationValid(item){return TYPES.has(applicationType(item))&&typeof applicationCommercialisable(item)==="boolean"&&!(applicationType(item)==="FONCTIONNALITE"&&applicationCommercialisable(item));}
const normalize=value=>String(value||"").normalize("NFD").replace(/[\u0300-\u036f]/g,"").toLocaleLowerCase("fr");
export function applicationGroups(items=[],query=""){
 const term=normalize(query).trim();
 return [{type:"MODULE",label:"Modules métier"},{type:"FONCTIONNALITE",label:"Fonctionnalités associées"}].map(group=>{
  const all=items.filter(item=>applicationType(item)===group.type),visible=all.filter(item=>normalize([item.label||item.Nom,item.description||item.Description].join(" ")).includes(term));
  return {...group,total:all.length,items:visible,accessible:all.filter(item=>item.canRead===true).length};
 });
}
export function applicationParentLabel(item,items=[]){const key=applicationParent(item);return key?(items.find(parent=>(parent.key||parent.CodeModule)===key)?.label||items.find(parent=>parent.CodeModule===key)?.Nom||""):"";}
export function applicationGroupCount(group,query=""){
 const count=String(query||"").trim()?`${group.items.length} sur ${group.total}`:String(group.total),noun=group.type==="MODULE"?"module":"fonctionnalité";
 return `${count} ${noun}${group.total===1?"":"s"}`;
}
