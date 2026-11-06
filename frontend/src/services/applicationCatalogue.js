const TYPES=new Set(["MODULE","FONCTIONNALITE"]);
export function applicationType(item){return item?.type||item?.TypeApplication||null;}
export function applicationCommercialisable(item){return item?.commercialisable??item?.Commercialisable;}
export function applicationParent(item){return item?.parentModule??item?.ModuleParentCode??null;}
export function applicationClassificationValid(item){return TYPES.has(applicationType(item))&&typeof applicationCommercialisable(item)==="boolean"&&!(applicationType(item)==="FONCTIONNALITE"&&applicationCommercialisable(item));}
// Masquer aussi un ancien manifeste encore en cache pendant le redémarrage du serveur.
export function applicationRetired(item){return (item?.key||item?.CodeModule)==="sante"||item?.path==="/maladies";}
const normalize=value=>String(value||"").normalize("NFD").replace(/[\u0300-\u036f]/g,"").toLocaleLowerCase("fr");
const GROUPS=[
  {key:"included",type:"MODULE",label:"Modules inclus",noun:"module"},
  {key:"licensed",type:"MODULE",label:"Modules sur licence",noun:"module"},
  {key:"features",type:"FONCTIONNALITE",label:"Fonctionnalités associées",noun:"fonctionnalité"},
  {key:"platform",type:"MODULE",label:"Administration de la plateforme",noun:"application"},
];

function groupKey(item){
  if(item.platformOnly)return "platform";
  if(applicationType(item)==="FONCTIONNALITE")return "features";
  return (item.base??item.EstSocle)?"included":"licensed";
}

export function applicationGroups(items=[],query=""){
  const term=normalize(query).trim();
  return GROUPS.map(group=>{
    const all=items.filter(item=>!applicationRetired(item)&&groupKey(item)===group.key);
    const visible=all.filter(item=>normalize([item.label||item.Nom,item.description||item.Description].join(" ")).includes(term));
    return {...group,total:all.length,items:visible,accessible:visible.filter(item=>item.canRead===true).length};
  });
}
export function applicationParentLabel(item,items=[]){const key=applicationParent(item);return key?(items.find(parent=>(parent.key||parent.CodeModule)===key)?.label||items.find(parent=>parent.CodeModule===key)?.Nom||""):"";}
export function applicationGroupCount(group,query=""){
 const count=String(query||"").trim()?`${group.items.length} sur ${group.total}`:String(group.total);
 return `${count} ${group.noun}${group.total===1?"":"s"}`;
}
