const text=value=>String(value??"").trim();
export const REFERENCE_RETAINED_HINT="Référence conservée. Choisissez une valeur de la nouvelle catégorie pour la remplacer.";
export function referenceLabel(item,fallback="Valeur sans libellé") {
 const generic=item&&["AbrGenerique","abbr","ID_Generique","NomGenerique","categoryId"].some(key=>Object.prototype.hasOwnProperty.call(item,key));
 if(generic){const label=text(Object.prototype.hasOwnProperty.call(item,"AbrGenerique")?item.AbrGenerique:item.abbr),id=item.ID_Generique??item.id??item.value;return label||"Valeur sans abréviation"+(id!=null&&text(id)?" #"+text(id):"");}
 return text(item?.label)||text(item?.name)||text(item?.code)||fallback;
}
export function referenceOptions(items=[]) {
 return items.map(item=>({...item,value:String(item.value??item.id??item.ID_Generique??""),label:referenceLabel(item),disabled:item.disabled===true||item.incompatible===true||item.active===false})).filter(item=>item.value);
}
export function retainReference(options,value,label="Valeur actuelle") {
 const current=text(value),found=options.find(item=>String(item.value)===current);
 if(!current)return options;
 if(found)return options;
 return [...options,{value:current,label:text(label)||"Valeur actuelle",disabled:true,incompatible:true}];
}
export function isRetainedReference(options,value) {
 return options.some(item=>String(item.value)===String(value)&&(item.incompatible===true||item.disabled===true));
}
