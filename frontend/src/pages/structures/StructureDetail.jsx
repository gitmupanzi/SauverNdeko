import {useState} from "react";
import DrawerDialog from "../../components/DrawerDialog";
import ConsultationTabs from "../../components/ConsultationTabs";
import ActionButton from "../../components/ActionButton";
import AppIcon from "../../components/AppIcon";
import useStructureRead from "./useStructureRead";
import StructureLogo from "./StructureLogo";
import StructureRelated from "./StructureRelated";
import {STRUCTURES_ROOT,structureDetail,structureName,structureWebsite} from "./structureModel";

export default function StructureDetail({id,owner,onClose,onContact,canContact=false,canReadProducts=false,canReadProfessionals=false}){
 const [retry,setRetry]=useState(0),[tab,setTab]=useState("presentation");
 const current=useStructureRead({owner,path:STRUCTURES_ROOT+"/annuaire/"+encodeURIComponent(id),parse:response=>structureDetail(response,id),revision:retry,message:"La fiche n’a pas pu être chargée."}),data=current.data,record=data?.record,website=structureWebsite(record?.website);
 const products=canReadProducts&&data?.canReadProducts===true,professionals=canReadProfessionals&&data?.canReadProfessionals===true;
 const tabs=[{key:"presentation",label:"Présentation",icon:"building"},...(products?[{key:"offres",label:"Produits",icon:"box"}]:[]),...(professionals?[{key:"professionnels",label:"Professionnels",icon:"user"}]:[])],active=tabs.some(item=>item.key===tab)?tab:"presentation";
 function term(label,value){return value!=null&&String(value).trim()!==""?<div><dt>{label}</dt><dd>{value}</dd></div>:null;}
 return <DrawerDialog title="Fiche structure" subtitle={record?structureName(record):"Informations partagées dans l’annuaire"} icon="building" onClose={onClose} defaultWidth={1000} storageKey="sauverndeko.structures.detail.width" className="structure-drawer" footer={<footer className="structure-footer"><ActionButton onClick={onClose}>Fermer</ActionButton>{record&&canContact&&data?.canContact===true?<ActionButton icon="mail" variant="primary" onClick={()=>onContact(record)}>Contacter la structure</ActionButton>:null}</footer>}>
  <div className="structure-detail" aria-busy={current.loading}>
   {current.loading?<div className="structure-loading" role="status"><AppIcon name="building" size={30}/><span>Chargement de la structure…</span></div>:null}
   {current.error?<div className="structure-error" role="alert"><span>{current.error}</span><ActionButton icon="refresh" onClick={()=>setRetry(value=>value+1)}>Réessayer</ActionButton></div>:null}
   {record?<><section className="structure-identity"><StructureLogo record={record} owner={owner}/><div><span>{record.type||"Structure"}</span><h3>{structureName(record)}</h3>{record.address?<p>{record.address}</p>:null}</div></section>
    <ConsultationTabs tabs={tabs} value={active} onChange={setTab} label="Rubriques de la structure" idPrefix={"structure-"+id}/>
    <section id={"structure-"+id+"-panel-"+active} role="tabpanel" aria-labelledby={"structure-"+id+"-tab-"+active} tabIndex={0}>
     {active==="presentation"?<div className="structure-presentation">
      {record.summary?<section className="structure-section"><h3><AppIcon name="document"/>Présentation</h3><p className="structure-description">{record.summary}</p></section>:null}
      <section className="structure-section"><h3><AppIcon name="building"/>Coordonnées</h3><dl className="structure-terms">{term("Nom",record.name)}{term("Type de structure",record.type)}{term("Adresse déclarée",record.address)}{term("Téléphone",record.phone)}{website?<div><dt>Site web</dt><dd><a href={website} target="_blank" rel="noopener noreferrer">{website}<AppIcon name="arrow-up-right" size={13}/></a></dd></div>:null}</dl>{!record.address&&!record.phone&&!website?<p className="structure-note">Les coordonnées ne sont pas renseignées.</p>:null}</section>
      <section className="structure-section"><h3><AppIcon name="globe"/>Lieux déclarés</h3>{data.locations.length?<ul className="structure-locations">{data.locations.map((location,index)=>{const details=[...new Set([location.zone,location.area,location.site].filter(value=>value&&value!==location.label))];return <li key={index}><strong>{location.label||"Localisation déclarée"}</strong>{location.address&&location.address!==location.label?<span>{location.address}</span>:null}{details.length?<span>{details.join(" · ")}</span>:null}</li>;})}</ul>:<p className="structure-note">Aucun lieu détaillé n’est renseigné.</p>}<p className="structure-note structure-location-note">Confirmez l’adresse et les conditions d’accueil auprès de la structure avant de vous déplacer.</p></section>
     </div>:<StructureRelated key={owner+":"+id+":"+active} id={id} owner={owner} kind={active}/>}
    </section>
   </>:null}
  </div>
 </DrawerDialog>;
}
