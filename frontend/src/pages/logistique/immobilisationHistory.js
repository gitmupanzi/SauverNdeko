const ASSIGNMENTS=[
 {field:"ID_ResponsableFk",key:"responsable",label:"Responsable",empty:"Sans affectataire"},
 {field:"ID_ServiceFk",key:"service",label:"Service",empty:"Non renseigné"},
 {field:"ID_LocalisationFk",extra:"LocalisationComplement",key:"localisation",label:"Localisation",empty:"Non renseignée"},
 {field:"ID_EtatFk",key:"etat",label:"État du matériel",empty:"Non renseigné"},
];
export function immobilisationAuditImage(value){
 if(value&&typeof value==="object"&&!Array.isArray(value))return value;
 if(typeof value==="string"){try{const image=JSON.parse(value);if(image&&typeof image==="object"&&!Array.isArray(image))return image;}catch{/* Image ancienne non exploitable. */}}
 return {};
}
const identifier=value=>value==null||value===""?null:String(value);
function assignmentLabel(present,labels,definition){
 if(!present)return definition.empty;
 const label=labels?.[definition.key];
 return typeof label==="string"&&label.trim()?label.trim():"Libellé indisponible";
}
/** Le changement suit les clés historiques ; les libellés autorisés viennent du serveur. */
export function immobilisationChanges(row){
 const before=immobilisationAuditImage(row?.OldData),after=immobilisationAuditImage(row?.NewData);
 const creation=["CREATE","INSERT"].includes(after.operation||row?.Operation);
 return ASSIGNMENTS.flatMap(definition=>{
  const oldId=identifier(before[definition.field]),newId=identifier(after[definition.field]);
  const oldExtra=definition.extra?identifier(before[definition.extra]):null,newExtra=definition.extra?identifier(after[definition.extra]):null;
  const beforePresent=oldId!==null||oldExtra!==null,afterPresent=newId!==null||newExtra!==null;
  if(creation?!afterPresent:oldId===newId&&oldExtra===newExtra)return [];
  return [{key:definition.key,label:definition.label,creation,
   before:creation?null:assignmentLabel(beforePresent,row?.AffectationAvant,definition),
   after:assignmentLabel(afterPresent,row?.AffectationApres,definition)}];
 });
}
