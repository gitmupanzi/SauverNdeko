import {useState} from "react";
import DrawerDialog from "../../components/DrawerDialog";
import ConsultationTabs from "../../components/ConsultationTabs";
import ActionButton from "../../components/ActionButton";
import AppIcon from "../../components/AppIcon";
import useStructureRead from "./useStructureRead";
import {SANITARY_ROOT,structureDetail,structureName,structureWebsite,structureTarget,structureLevelLabel,structureTerritory,typedTerritory,structureMapUrl} from "./structureModel";
import RequestSourceAction from "../demandes/RequestSourceAction";

export default function StructureDetail({structureKey,owner,onClose}){
 const [retry,setRetry]=useState(0),[tab,setTab]=useState("coordonnees"),target=structureTarget(structureKey);
 const current=useStructureRead({owner,path:SANITARY_ROOT+"/"+target?.level+"/"+target?.id,enabled:Boolean(target),parse:response=>structureDetail(response,structureKey),revision:retry,message:"La fiche n’a pas pu être chargée."}),record=current.data?.record,website=record?.contactsPublished?structureWebsite(record.website):"";
 const mapUrl=structureMapUrl(record?.position);
 const tabs=[{key:"coordonnees",label:"Coordonnées",icon:"mail"},{key:"rattachement",label:"Rattachement",icon:"globe"}],prefix="sanitary-"+(target?target.level+"-"+target.id:"record");
 function term(label,value,empty="Non renseigné"){return <div><dt>{label}</dt><dd className="structure-multiline">{value!=null&&String(value).trim()!==""?value:empty}</dd></div>;}
 return <DrawerDialog title="Fiche structure ou territoire" subtitle={record?structureName(record):"Annuaire des structures et territoires"} icon="building" onClose={onClose} defaultWidth={1000} storageKey="sauverndeko.structures.detail.width" className="structure-drawer" footer={<footer className="structure-footer"><ActionButton onClick={onClose}>Fermer</ActionButton></footer>}>
  <div className="structure-detail" aria-busy={current.loading}>
   {current.loading?<div className="structure-loading" role="status"><AppIcon name="building" size={30}/><span>Chargement de la structure…</span></div>:null}
   {current.error?<div className="structure-error" role="alert"><span>{current.error}</span><ActionButton icon="refresh" onClick={()=>setRetry(value=>value+1)}>Réessayer</ActionButton></div>:null}
   {record?<><section className="structure-identity"><span className="structure-logo" aria-hidden="true"><AppIcon name="building" size={34}/></span><div><span>{record.type||"Type non renseigné"} · {structureLevelLabel(record.level)}</span><h3>{structureName(record)}</h3>{structureTerritory(record)?<p>{structureTerritory(record)}</p>:null}</div></section>
    {mapUrl?<a className="ui-action is-secondary structure-map-link" href={mapUrl} target="_blank" rel="noopener noreferrer"><AppIcon name="map-pin"/>Ouvrir dans Google Maps<AppIcon name="arrow-up-right" size={13}/></a>:null}
    {target.level>=3?<RequestSourceAction sourceType={"structure_n"+target.level} sourceId={target.id}/>:null}
    <ConsultationTabs tabs={tabs} value={tab} onChange={setTab} label="Rubriques de la structure ou du territoire" idPrefix={prefix}/>
    <section id={prefix+"-panel-"+tab} role="tabpanel" aria-labelledby={prefix+"-tab-"+tab} tabIndex={0}>
     {tab==="coordonnees"?<div className="structure-presentation"><section className="structure-section"><h3><AppIcon name="mail"/>Coordonnées et accueil</h3>{record.contactsPublished?<><dl className="structure-terms">
      {term("Adresse",record.address,"Non renseignée")}{term("Téléphone principal",record.phone)}{term("Téléphone secondaire",record.secondaryPhone)}{term("Adresse e-mail",record.email,"Non renseignée")}
      {website?<div><dt>Site web</dt><dd><a href={website} target="_blank" rel="noopener noreferrer">{website}<AppIcon name="arrow-up-right" size={13}/></a></dd></div>:term("Site web",null)}
      {term("Horaires d’ouverture",record.hours,"Non renseignés")}{term("Informations d’accueil",record.reception,"Non renseignées")}
     </dl><p className="structure-note structure-location-note">Confirmez l’adresse et les horaires auprès de la structure avant de vous déplacer.</p></>:<p className="structure-note">Les coordonnées de cette structure ne sont pas publiées. Son nom, son type et son rattachement restent consultables.</p>}</section></div>:<section className="structure-section"><h3><AppIcon name="globe"/>Rattachement territorial</h3><dl className="structure-terms">{term("Nom",record.name)}{term("Type",record.type)}{term("Code",record.code)}{term("Niveau territorial",structureLevelLabel(record.level))}{term("Province ou DPS",typedTerritory(record.province),"Non renseignée")}{term("Antenne ou subdivision",typedTerritory(record.subdivision),"Non renseignée")}{term("Niveau 3",typedTerritory(record.zone),"Non renseignée")}{term("Niveau 4",typedTerritory(record.area),"Non renseignée")}</dl></section>}
    </section>
   </>:null}
  </div>
 </DrawerDialog>;
}
