import {GEOLOCALISATION_ADMIN_SCHEMA} from "../admin/geolocalisation";

export const TERRITORY_ROOT="/api/geolocalisation/territoires";
const level=(kind,n,view,extra={})=>({kind,title:"Niveau "+n,view,pk:"ID_Niveau_"+n,name:"NomNiveau_"+n,icon:"globe",editable:true,preference:"territoires.niveaux-"+({0:"zero",1:"un",2:"deux",3:"trois",4:"quatre",5:"cinq"}[n]),...extra});
export const TERRITORY_REGISTERS={
 niveaux0:level("niveaux0",0,"V_Niveau_0",{visible:["NomNiveau_0","CodeNiveau_0","iso","Nb_Niveau_1","actions"]}),
 "niveaux1-historique":level("niveaux1-historique",1,"V_Niveau_1_Old",{title:"Niveau 1 historique",pk:"ID_Niveau_1_Old",name:"NomNiveau_1_Old",preference:"territoires.niveaux-un-historique",visible:["NomNiveau_1_Old","surfaceNiveau_1_Old","actions"]}),
 niveaux1:level("niveaux1",1,"V_Niveau_1",{visible:["NomNiveau_1","NomNiveau_0","CodeNiveau_1","PopulationNiveau_1","Nb_Niveau_2","VisibleNiveau_1","actions"]}),
 niveaux2:level("niveaux2",2,"V_Niveau_2",{visible:["NomNiveau_2","NomNiveau_1","Type_Niveau_2","PopulationNiveau_2","Nb_Niveau_3","Statut_Niveau_2","actions"]}),
 niveaux3:level("niveaux3",3,"V_Niveau_3",{visible:["NomNiveau_3","NomNiveau_2","Type_Niveau_3","PopulationNiveau_3","Nb_Niveau_4","Nb_Niveau_5","Statut_Niveau_3","actions"]}),
 niveaux4:level("niveaux4",4,"V_Niveau_4",{visible:["NomNiveau_4","NomNiveau_3","NomNiveau_1","Type_Niveau_4","PopulationNiveau_4","Nb_Niveau_5","STATUT_AS","actions"]}),
 niveaux5:level("niveaux5",5,"V_Niveau_5",{visible:["NomNiveau_5","NomNiveau_3","NomNiveau_1","Type_Niveau_5","PopulationNiveau_5","STATUT_Site","actions"]}),
 "as-sans-site":{title:"Aires sans site",view:"V_AS_sans_Site",pk:"_rowId",name:"NomNiveau_4",icon:"alert",visible:["NomNiveau_4","NomNiveau_3","NomNiveau_1","actions"],parent:"niveaux4"},
 "zs-sans-as":{title:"Zones sans aire",view:"V_ZS_sans_AS",pk:"_rowId",name:"NomNiveau_3",icon:"alert",visible:["NomNiveau_3","NomNiveau_2","NomNiveau_1","actions"],parent:"niveaux3"},
 "population-sites":{title:"Population des sites",view:"V_Pop_N3_Couverte_Sites",pk:"_rowId",name:"NomNiveau_3",icon:"user",visible:["NomNiveau_3","NomNiveau_1","Type_Niveau_5","Pop_Cum_Sites","actions"]},
 "reseau-as":{title:"Réseau des aires",view:"V_RESEAU_AS_par_ZS",pk:"_rowId",name:"NomNiveau_3",icon:"globe",visible:["NomNiveau_3","NomNiveau_1","Nb_AS","Nb_AS_Avec_Reseau","Pct_AS_Avec_Reseau","actions"]},
 "statistiques-provinces":{title:"Répartition territoriale",view:"V_Stats_N1_N2",pk:"_rowId",name:"NomNiveau_1",icon:"chart",visible:["NomNiveau_1","NomNiveau_0","Type_Niveau_2","Nb_Niveau_2","Pop_Niveau_2","actions"]},
 "statistiques-zones":{title:"Structures par zone",view:"V_Stats_N3_Structures",pk:"_rowId",name:"NomNiveau_3",icon:"chart",visible:["NomNiveau_3","NomNiveau_1","Type_Niveau_4","Type_Niveau_5","Nb_Aires_Sante","Nb_Structures_Sante","actions"]},
};
Object.entries(TERRITORY_REGISTERS).forEach(([kind,item])=>{item.kind=kind;item.preference||="territoires."+kind;item.crud=GEOLOCALISATION_ADMIN_SCHEMA.crudConfigs["geolocalisation."+item.view];});
Object.entries({niveaux0:"Pays et territoires",niveaux1:"Provinces et DPS",niveaux2:"Antennes et subdivisions",niveaux3:"Zones de santé",niveaux4:"Aires de santé",niveaux5:"Structures et sites","niveaux1-historique":"Ancien découpage provincial"}).forEach(([kind,title])=>{TERRITORY_REGISTERS[kind].title=title;});
Object.entries({niveaux0:"Nouveau pays ou territoire",niveaux1:"Nouvelle province ou DPS",niveaux2:"Nouvelle antenne ou subdivision",niveaux3:"Nouvelle zone de santé",niveaux4:"Nouvelle aire de santé",niveaux5:"Nouvelle structure ou site","niveaux1-historique":"Nouvelle province historique"}).forEach(([kind,createLabel])=>{TERRITORY_REGISTERS[kind].crud={...TERRITORY_REGISTERS[kind].crud,createLabel};});
export const TERRITORY_NAVIGATION=[
 {label:"Pilotage",items:[{key:"tableau-de-bord",label:"Tableau de bord",icon:"dashboard"}]},
 {label:"Organisation",items:["niveaux0","niveaux1","niveaux2","niveaux3","niveaux4","niveaux5"].map(key=>({key,label:TERRITORY_REGISTERS[key].title,icon:key==="niveaux5"?"building":"globe"}))},
 {label:"Analyses",items:["statistiques-provinces","statistiques-zones","population-sites","reseau-as"].map(key=>({key,label:TERRITORY_REGISTERS[key].title,icon:TERRITORY_REGISTERS[key].icon}))},
 {label:"Contrôles",items:["as-sans-site","zs-sans-as"].map(key=>({key,label:TERRITORY_REGISTERS[key].title,icon:"alert"}))},
 {label:"Historique",items:[{key:"niveaux1-historique",label:"Ancien découpage",icon:"clock"}]},
];
const labels={SITE:"Site",RESEAU:"Réseau",Type_Niveau_4:"Type d’aire",Type_Niveau_5:"Type de site",VOIE_AS_ZS:"Voie d’accès",VOIE_AS_Site:"Voie d’accès",STATUT_AS:"Statut",STATUT_Site:"Statut",STATUT_DEPLOI:"Déploiement",Pop_Cum_Sites:"Population des sites",Nb_Niveau_1:"Provinces / DPS",Nb_Niveau_2:"Antennes / subdivisions",Nb_Niveau_3:"Zones de santé",Nb_Niveau_4:"Aires de santé",Nb_Niveau_5:"Sites / structures",Nb_AS:"Aires",Nb_AS_Avec_Reseau:"Aires avec réseau",Pct_AS_Avec_Reseau:"Couverture réseau (%)",Pop_Niveau_2:"Population du niveau 2",Nb_Aires_Sante:"Aires",Nb_Structures_Sante:"Structures",iso:"Code ISO",CodeSNIS:"Code SNIS"};
export const TERRITORY_CONTACT_FIELDS=[
 {name:"TelephoneTerritoire",label:"Téléphone principal",type:"tel",max:50},
 {name:"TelephoneSecondaireTerritoire",label:"Téléphone secondaire",type:"tel",max:50},
 {name:"EmailTerritoire",label:"Adresse e-mail",type:"email",max:255},
 {name:"SiteWebTerritoire",label:"Site web",type:"url",max:255},
 {name:"AdresseTerritoire",label:"Adresse",type:"textarea",max:2000},
 {name:"InformationsAccueilTerritoire",label:"Informations d’accueil",type:"textarea",max:3000},
];
TERRITORY_CONTACT_FIELDS.forEach(field=>{labels[field.name]=field.label;});
labels.CoordonneesModifieLe="Coordonnées mises à jour le";
export function territoryColumnLabel(key){if(labels[key])return labels[key];if(/^ID_Niveau_[0-5](?:_F[kK])?$/.test(key))return "Niveau "+key.match(/Niveau_(\d)/)[1]+" parent";if(/^NomNiveau_[0-5]$/.test(key))return "Niveau "+key.at(-1);if(key==="NomNiveau_1_Old")return "Niveau 1 historique";if(/^Population/.test(key))return "Population";if(/^Code/.test(key))return "Code";if(/^Type_/.test(key))return "Type";if(/^Statut_Niveau/.test(key))return "Statut";if(/^Statut_Deploiement/.test(key))return "Déploiement";if(/^Latitude/.test(key))return "Latitude";if(/^Longitude/.test(key))return "Longitude";if(/^Altitude/.test(key))return "Altitude";if(/^surface/.test(key))return "Surface";if(/^geometry/.test(key))return "Géométrie";if(/^Obs/.test(key))return "Observations";if(/^Abre/.test(key))return "Abréviation";if(/^Visible/.test(key))return "Visible au niveau "+key.at(-1);if(/^Select/.test(key))return "Sélectionné";if(/^ID_/.test(key))return key.replace(/^ID_/,"Réf. ").replace(/_/g," ");return key.replace(/_/g," ").replace(/([a-z])([A-Z])/g,"$1 $2");}
export function territoryTabKey(value){const raw=String(value||"").replace(/^geolocalisation[.:]/,"");return Object.entries(TERRITORY_REGISTERS).find(([key,item])=>key===raw||item.view===raw)?.[0]||"tableau-de-bord";}
export function territoryFields(kind){const parentLabels={niveaux0:"Pays ou territoire",niveaux1Old:"Ancienne province",niveaux1:"Province ou DPS",niveaux2:"Antenne ou subdivision",niveaux3:"Zone de santé",niveaux4:"Aire de santé"};const fields=(TERRITORY_REGISTERS[kind]?.crud?.fields||[]).map(item=>({...item,label:parentLabels[item.optionsSource]||item.label}));if(kind!=="niveaux1-historique"){fields.push({name:"uidSNIS",label:"Identifiant SNIS",type:"text",initialValue:""});fields.push({name:kind==="niveaux1"?"prov_uid":"iso",label:kind==="niveaux1"?"Identifiant provincial":"Code ISO",type:"text",initialValue:""});}if(/^niveaux[1-5]$/.test(kind))fields.push(...TERRITORY_CONTACT_FIELDS.map(field=>({...field,initialValue:""})));if(kind==="niveaux1")fields.forEach(field=>{if(["VisibleNiveau_1","VisibleNiveau_5"].includes(field.name))field.required=true;});if(kind==="niveaux5")fields.forEach(field=>{if(field.name==="ID_Niveau_4_Fk")field.required=false;});return fields;}
export function territorySection(field){if(TERRITORY_CONTACT_FIELDS.some(item=>item.name===field.name))return "contact";if(/^(geometry|surface|Etendu|Latitude|Longitude|Altitude|timezone|wikidata)/.test(field.name))return "geography";if(/^(Visible|Fusion|Select|Obs|ID_Statut|ID_Status|ID_Dispo|ID_Voie|ID_TypeToit|Km)/.test(field.name))return "monitoring";return "identity";}
export function territoryValues(kind,record){return Object.fromEntries(territoryFields(kind).map(field=>{const value=record?record[field.name]:field.initialValue;return [field.name,value==null?"":typeof value==="object"?JSON.stringify(value):String(value)];}));}
export function territoryQuery(criteria,grid={},columns){const {q,...filters}=criteria;return new URLSearchParams({q:q||"",filters:JSON.stringify(Object.fromEntries(Object.entries(filters).filter(([,value])=>value!==""&&value!==undefined).map(([key,value])=>[key,value==="__null__"?null:value==="true"?true:value==="false"?false:value]))),...grid,...(columns?{columns:JSON.stringify(columns)}:{})});}
