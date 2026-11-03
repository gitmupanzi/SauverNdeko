import {useEffect,useState} from "react";
import DrawerDialog from "../../components/DrawerDialog";
import ActionButton from "../../components/ActionButton";
import AppIcon from "../../components/AppIcon";
import ArticlePhoto from "../../components/ArticlePhoto";
import {requestJson} from "../../services/api";
import {formatCurrency} from "../../utils/money";
import {PRODUCT_OFFERS_ROOT,offerName,offerError,validOfferId} from "./productOffers";

export default function ProductOfferDetail({id,owner,onClose,onContact,canContact=false}){
 const [retry,setRetry]=useState(0),[state,setState]=useState({key:"",record:null,locations:[],canContact:false,loading:true,error:""});
 const key=owner+":"+id+":"+retry,current=state.key===key?state:{record:null,locations:[],canContact:false,loading:true,error:""},record=current.record;
 useEffect(()=>{
  let active=true,settled=false;const controller=new AbortController();
  const finish=next=>{if(!active||settled)return;settled=true;clearTimeout(timer);setState({key,record:null,locations:[],canContact:false,loading:false,error:"",...next});};
  const timer=setTimeout(()=>{finish({error:"La fiche prend trop de temps à charger. Réessayez."});controller.abort();},15000);
  requestJson(PRODUCT_OFFERS_ROOT+"/offres/"+encodeURIComponent(id),{requiresAuth:true,signal:controller.signal}).then(response=>{
   if(!active||settled)return;
   if(!response?.success||String(response.data?.record?.ID_Article)!==String(id)){finish({error:offerError(response,"Cette offre n’est pas disponible.")});return;}
   finish({record:response.data.record,locations:Array.isArray(response.data.locations)?response.data.locations:[],canContact:response.data.canContact===true});
  }).catch(()=>finish({error:"La fiche n’a pas pu être chargée."}));
  return()=>{active=false;clearTimeout(timer);controller.abort();};
 },[key]);
 function term(label,value){return value!=null&&value!==""?<div><dt>{label}</dt><dd>{value}</dd></div>:null;}
 return <DrawerDialog title="Offre de produit" subtitle={record?offerName(record):"Fiche partagée par une entreprise"} icon="box" onClose={onClose} defaultWidth={900} storageKey="sauverndeko.produits.detail.width" className="product-offer-drawer" footer={<footer className="product-offer-footer"><ActionButton onClick={onClose}>Fermer</ActionButton>{record&&canContact&&current.canContact&&validOfferId(record.IdEntite)?<ActionButton icon="mail" variant="primary" onClick={()=>onContact({type:"structure",id:record.IdEntite,name:record.NomEntite})}>Contacter l’entreprise</ActionButton>:null}</footer>}>
  <div className="product-offer-detail" aria-busy={current.loading}>
   {current.loading?<div className="product-offer-loading" role="status"><AppIcon name="box" size={30}/><span>Chargement de l’offre…</span></div>:null}
   {current.error?<div className="product-offer-error" role="alert"><span>{current.error}</span><ActionButton icon="refresh" onClick={()=>setRetry(value=>value+1)}>Réessayer</ActionButton></div>:null}
   {record?<><section className="product-offer-identity"><div className="product-offer-image"><ArticlePhoto record={record} publicCatalogue/></div><div><span className="product-offer-category">{record.CategorieArticle||"Catégorie non renseignée"}</span><h3>{offerName(record)}</h3>{record.RefArticle?<p>Réf. {record.RefArticle}</p>:null}<span className="erp-status is-neutral">{record.EtatDisponibilite||"Stock à confirmer"}</span></div></section>
    <section className="product-offer-section product-offer-price"><div><span>Prix de vente déclaré</span><strong>{record.PVArticle==null?"Prix à confirmer":formatCurrency(record.PVArticle,record.DeviseCode)}</strong><small>{record.Unite?"Par "+record.Unite:"Unité non renseignée"}</small></div><p>Confirmez le prix, la disponibilité et les conditions auprès de l’entreprise avant de vous déplacer.</p></section>
    <section className="product-offer-section"><h3><AppIcon name="tag"/>Le produit</h3><dl className="product-offer-terms">{term("Désignation",record.NomArticle)}{term("Référence",record.RefArticle)}{term("Catégorie",record.CategorieArticle)}{term("Type",record.TypeArticle)}{term("Unité",record.Unite)}{term("Stock déclaré",record.EtatDisponibilite)}</dl></section>
    <section className="product-offer-section"><h3><AppIcon name="building"/>L’entreprise</h3><dl className="product-offer-terms">{term("Entreprise",record.NomEntite)}{term("Adresse",record.AdresseEntite)}{term("Téléphone",record.PhoneEntite)}</dl>{!record.AdresseEntite&&!record.PhoneEntite?<p className="product-offer-note">Les coordonnées de cette entreprise ne sont pas renseignées.</p>:null}</section>
    <section className="product-offer-section"><h3><AppIcon name="globe"/>Lieux déclarés</h3>{current.locations.length?<ul className="product-offer-locations">{current.locations.map((location,index)=><li key={index}><strong>{location.label||"Localisation déclarée"}</strong>{location.address&&location.address!==location.label?<span>{location.address}</span>:null}{[...new Set([location.zone,location.area,location.site].filter(value=>value&&value!==location.label))].length?<span>{[...new Set([location.zone,location.area,location.site].filter(value=>value&&value!==location.label))].join(" · ")}</span>:null}</li>)}</ul>:<p className="product-offer-note">Aucun lieu détaillé n’est renseigné pour cette entreprise.</p>}</section>
    <p className="product-offer-note">Cette fiche présente une offre déclarée par l’entreprise. Elle ne remplace pas un conseil professionnel.</p>
   </>:null}
  </div>
 </DrawerDialog>;
}
