import {TERRITORY_REGISTERS} from "./territorialDefinitions";

/** Les cibles de compteurs sont définies par le serveur au grain de la vue. */
export function territoryDrilldown(meta,column,row){
 const rule=meta?.drilldowns?.[column];if(!rule||!TERRITORY_REGISTERS[rule.kind]||!rule.filters||typeof rule.filters!=="object")return null;
 const filters={};for(const [key,source] of Object.entries(rule.filters)){if(!source||typeof source!=="object")return null;const field=source.field;if(field&&!Object.hasOwn(row,field))return null;const value=field?row[field]:Object.hasOwn(source,"value")?source.value:undefined;if(value===undefined)return null;filters[key]=value===null?"__null__":typeof value==="boolean"?String(value):String(value);}
 return {kind:rule.kind,filters,label:rule.label||"Consulter les éléments liés",...(rule.mode?{mode:rule.mode}:{})};
}
/** Une fiche est ouverte par son identifiant, jamais par le libellé affiché. */
export function territoryRecordTarget(column,row,meta){
 const rule=meta?.records?.[column];if(rule){const id=row[rule.idField];return TERRITORY_REGISTERS[rule.kind]&&id!==null&&id!==undefined&&id!==""?{kind:rule.kind,id}:null;}if(meta?.records)return null;
 const match=/^NomNiveau_([0-5])(_Old)?$/.exec(column);if(!match)return null;const kind=match[2]?"niveaux1-historique":"niveaux"+match[1],key=TERRITORY_REGISTERS[kind]?.pk;
 const candidates=match[2]?[key,"ID_Niveau_1_Old_Fk"]:[key,key+"_Fk",key+"_FK"],id=candidates.map(key=>row[key]).find(value=>value!==null&&value!==undefined&&value!=="");
 return id==null?null:{kind,id};
}
