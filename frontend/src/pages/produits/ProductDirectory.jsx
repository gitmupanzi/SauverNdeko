import {useEffect,useId,useRef,useState} from "react";
import {Link,useLocation,useNavigate,useSearchParams} from "react-router-dom";
import {useAuth} from "../../contexts/AuthContext";
import {useEntityScope} from "../../contexts/EntityScopeContext";
import {mayOpen,accessSignature} from "../../services/moduleAccess";
import {buildDiscussionPath} from "../../services/mappers";
import useReferencesRefresh from "../../hooks/useReferencesRefresh";
import ModuleSidebar from "../../components/ModuleSidebar";
import ModuleHeader from "../../components/ModuleHeader";
import RegisterSurface from "../../components/RegisterSurface";
import AppliedCriteria from "../../components/AppliedCriteria";
import ListState from "../../components/ListState";
import DataTableToolbar from "../../components/DataTableToolbar";
import ActionButton from "../../components/ActionButton";
import AppIcon from "../../components/AppIcon";
import SearchSelect from "../../components/SearchSelect";
import ArticlePhoto from "../../components/ArticlePhoto";
import {SimpleTable} from "../logistique/logistiqueShared";
import {formatCurrency} from "../../utils/money";
import {useProductOffers,useProductReferences} from "./useProductOffers";
import {EMPTY_OFFER_CRITERIA,offerLocation,offerParams,offerOptions,keepOfferFilter,offerId,offerName,validOfferId,offerSearchError} from "./productOffers";
import ProductOfferDetail from "./ProductOfferDetail";
import "../logistique/LogistiqueModern.css";
import "../admin/AdminPortal.css";
import "./Products.css";

function remembered(key,fallback,valid){try{const value=localStorage.getItem(key);return valid.includes(value)?value:fallback;}catch{return fallback;}}
export default function ProductDirectory(){
 const {user}=useAuth(),scope=useEntityScope(),location=useLocation(),navigate=useNavigate(),[params,setParams]=useSearchParams(),prefix=useId();
 const {criteria,grid,focusId}=offerLocation(params),criteriaKey=JSON.stringify(criteria),owner=[user?.IdUser,scope.scopeKey,accessSignature(user)].join(":"),fallbackFocus=useRef(null),origin=useRef(null),deepLink=useRef(null),draftAfterRemoval=useRef(null);
 const [draft,setDraft]=useState(criteria),[filtersOpen,setFiltersOpen]=useState(false),[display,setDisplay]=useState(()=>remembered("sauverndeko.produits.display","cards",["cards","table"])),[density,setDensity]=useState("compact"),[collapsed,setCollapsed]=useState(()=>remembered("sauverndeko.produits.sidebar-collapsed","false",["true","false"])==="true"),[revision,setRevision]=useState(0),[searchError,setSearchError]=useState("");
 const references=useProductReferences(owner,revision);
 function changeGrid(patch){setParams(offerParams(params,criteria,{...grid,...patch}));}
 const current=useProductOffers({owner,criteria,grid,revision,onPageCorrection:skip=>changeGrid({skip})});
 const pending=JSON.stringify(draft)!==criteriaKey,activeFilters=Object.values(criteria).filter(Boolean).length,canDiscuss=mayOpen(user,"/discussions"),canManage=mayOpen(user,"/logistique");
 useReferencesRefresh(()=>setRevision(value=>value+1));
 useEffect(()=>{const saved=draftAfterRemoval.current;setDraft(saved?.owner===owner&&saved?.criteria===criteriaKey?saved.draft:criteria);draftAfterRemoval.current=null;setSearchError("");},[criteriaKey,owner]);
 useEffect(()=>{try{localStorage.setItem("sauverndeko.produits.display",display);localStorage.setItem("sauverndeko.produits.sidebar-collapsed",String(collapsed));}catch{}},[display,collapsed]);
 useEffect(()=>{const id=validOfferId(location.state?.focusId);if(!id||deepLink.current===location.key)return;deepLink.current=location.key;const next=new URLSearchParams(params);next.set("offre",id);setParams(next,{replace:true,state:null});},[location.key,location.state]);
 function apply(){const next={...draft,q:draft.q.trim()},invalid=offerSearchError(next);setSearchError(invalid);if(invalid)return;setDraft(next);if(JSON.stringify(next)===criteriaKey&&grid.skip===0)setRevision(value=>value+1);setParams(offerParams(params,next,{...grid,skip:0}));}
 function removeCriterion(key){const next={...criteria,[key]:""},nextDraft={...draft,[key]:""};draftAfterRemoval.current={owner,criteria:JSON.stringify(next),draft:nextDraft};setDraft(nextDraft);setSearchError("");setParams(offerParams(params,next,{...grid,skip:0}));}
 function reset(){setDraft({...EMPTY_OFFER_CRITERIA});setSearchError("");setParams(offerParams(params,EMPTY_OFFER_CRITERIA,{...grid,skip:0}));}
 function open(row,event){if(current.loading)return;const id=validOfferId(offerId(row));if(!id)return;event?.stopPropagation();origin.current=event?.currentTarget||document.activeElement;const next=new URLSearchParams(params);next.set("offre",id);setParams(next);}
 function close(){const next=new URLSearchParams(params);next.delete("offre");setParams(next,{replace:true,state:null});requestAnimationFrame(()=>{const target=origin.current?.isConnected?origin.current:fallbackFocus.current;target?.focus({preventScroll:true});});}
 function contact(target){if(!canDiscuss||!validOfferId(target.id))return;navigate(buildDiscussionPath("structure",target.id),{state:{targetName:target.name,targetType:"structure"}});}
 const filters=[{key:"categoryId",label:"Catégorie",items:references.data.categories,empty:"Toutes les catégories"},{key:"typeId",label:"Type de produit",items:references.data.types,empty:"Tous les types"},{key:"companyId",label:"Entreprise",items:references.data.companies,empty:"Toutes les entreprises"},{key:"currencyId",label:"Devise",items:references.data.currencies,empty:"Toutes les devises"},{key:"availability",label:"Stock déclaré",items:references.data.availability,empty:"Tous les états"}];
 const toolbar=<><DataTableToolbar search={draft.q} setSearch={q=>{setDraft(previous=>({...previous,q}));setSearchError("");}} onApply={apply} onReset={reset} pending={pending} take={grid.take} onTake={take=>changeGrid({take,skip:0})} filtersOpen={filtersOpen} toggleFilters={()=>setFiltersOpen(value=>!value)} filterControlsId={prefix+"-filters"} activeFilters={activeFilters} density={density} toggleDensity={()=>setDensity(value=>value==="compact"?"airy":"compact")} loading={current.loading} showSettings={false} error={searchError} placeholder="Rechercher un produit, une référence ou une entreprise…"/>
  {filtersOpen?<form id={prefix+"-filters"} className="erp-register-filters" onSubmit={event=>{event.preventDefault();apply();}}><div className="erp-register-filter-grid">{filters.map(field=><label key={field.key}><span>{field.label}</span><SearchSelect label={field.label} value={draft[field.key]} options={keepOfferFilter(offerOptions(field.items,field.empty),draft[field.key])} disabled={references.loading} onChange={value=>setDraft(previous=>({...previous,[field.key]:value}))}/></label>)}</div><div className="erp-register-filters-footer"><ActionButton type="submit" variant="primary" disabled={current.loading||references.loading}>Appliquer les filtres</ActionButton></div></form>:null}
  <AppliedCriteria items={Object.entries(criteria).filter(([,value])=>value).map(([key,value])=>({key,label:key==="q"?"Recherche":filters.find(field=>field.key===key)?.label||key,value:key==="q"?value:(filters.find(field=>field.key===key)?.items||[]).find(item=>String(item.id)===value)?.label||"Valeur sélectionnée"}))} onRemove={removeCriterion} disabled={current.loading}/>
 </>;
 const columns=[{key:"name",label:"Produit",width:270,render:row=><div className="product-offer-table-name"><span className="product-offer-thumb"><ArticlePhoto record={row} publicCatalogue/></span><button type="button" disabled={current.loading} onClick={event=>open(row,event)}><strong>{offerName(row)}</strong>{row.RefArticle?<small>Réf. {row.RefArticle}</small>:null}</button></div>},{key:"company",label:"Entreprise",width:220,render:row=><span>{row.NomEntite||"—"}<small className="product-offer-table-address">{row.AdresseEntite||""}</small></span>},{key:"CategorieArticle",label:"Catégorie",sortable:false,width:170,render:row=>row.CategorieArticle||"—"},{key:"TypeArticle",label:"Type",sortable:false,width:150,render:row=>row.TypeArticle||"—"},{key:"PVArticle",label:"Prix de vente",sortable:false,width:180,render:row=><span className="product-offer-money">{row.PVArticle==null?"À confirmer":formatCurrency(row.PVArticle,row.DeviseCode)}<small>{row.Unite?"Par "+row.Unite:"Unité non renseignée"}</small></span>},{key:"EtatDisponibilite",label:"Stock déclaré",sortable:false,width:160,render:row=><span className="erp-status is-neutral">{row.EtatDisponibilite||"À confirmer"}</span>},{key:"actions",label:"Actions",sortable:false,width:85,render:row=><ActionButton icon="eye" className="is-icon" aria-label={"Consulter l’offre de "+offerName(row)+" chez "+(row.NomEntite||"l’entreprise")} disabled={current.loading} onClick={event=>open(row,event)}/>}];
 const empty=!current.loading&&!current.error&&current.total===0,pages=Math.max(1,Math.ceil((current.total||0)/grid.take));
 const emptyContent=<ListState role="status" icon="box" title={activeFilters?"Aucune offre ne correspond à ces critères":"Aucune offre partagée pour le moment"} description={activeFilters?"Essayez une autre désignation ou élargissez les filtres.":"Les entreprises choisissent les articles à rendre visibles dans cet annuaire."} action={activeFilters?<ActionButton icon="reset" onClick={reset}>Effacer les critères</ActionButton>:canManage?<Link className="ui-action is-primary" to="/logistique?onglet=articles">Gérer les articles de mon entreprise</Link>:null}/>;
 return <div className={"logistics-modern logistics-app admin-portal products-module"+(collapsed?" is-menu-collapsed":"")}>
  <ModuleSidebar title="Produits" collapsed={collapsed} onToggle={()=>setCollapsed(value=>!value)} activeKey="offres" groups={[{key:"produits",label:"Catalogue",items:[{key:"offres",label:"Offres de produits",icon:"box",to:"/produits"}]}]} storageKey="sauverndeko.produits.navigation"/>
  <ModuleHeader title="Produits"/>
  <main className="admin-main products-main" ref={fallbackFocus} tabIndex={-1}>
   <RegisterSurface title="Offres de produits" subtitle="Les produits partagés par les entreprises participantes." actions={<div className="product-offer-display" role="group" aria-label="Affichage des offres"><ActionButton icon="apps" aria-label="Affichage en cartes" aria-pressed={display==="cards"} onClick={()=>setDisplay("cards")}/><ActionButton icon="table" aria-label="Affichage en tableau" aria-pressed={display==="table"} onClick={()=>setDisplay("table")}/></div>}>
    <div className="product-offer-directory" data-density={density} aria-busy={current.loading}>
     {references.error?<div className="product-offer-error" role="alert"><span>{references.error}</span><ActionButton icon="refresh" onClick={()=>setRevision(value=>value+1)}>Recharger les filtres</ActionButton></div>:null}
     {current.error?<div className="product-offer-error" role="alert"><span>{current.error}</span><ActionButton icon="refresh" onClick={()=>setRevision(value=>value+1)}>Réessayer</ActionButton></div>:null}
     <p className="product-offer-note">Chaque offre appartient à une entreprise. Vérifiez la référence, l’unité et la devise avant de comparer les prix.</p>
     {toolbar}
     {display==="table"?<div className="erp-register-table erp-results" data-density={density}>{empty?<>{emptyContent}<p className="product-offer-note" role="status">0 offre</p></>:<SimpleTable rows={current.rows} columns={columns} getRowId={offerId} serverMeta={current.loading||current.total==null?null:{filteredCount:current.total,totalCount:current.total,take:grid.take,skip:grid.skip}} serverState={grid} onServerChange={changeGrid} enableSelection={false} loading={current.loading} defaultPinnedColumns={[]} showControls={false} emptyMessage={current.loading?"Chargement des offres…":current.error?"La liste est indisponible.":activeFilters?"Aucune offre ne correspond à ces critères.":"Aucune offre partagée pour le moment."}/>}</div>:<><div className={"product-offer-results"+(current.loading?" is-loading":"")} aria-label="Offres de produits">{current.rows.length?<div className="product-offer-cards">{current.rows.map(row=><article className="product-offer-card" key={offerId(row)}><div className="product-offer-card-image"><ArticlePhoto record={row} publicCatalogue/></div><div className="product-offer-card-copy"><span className="product-offer-category">{row.CategorieArticle||row.TypeArticle||"Produit"}</span><h2><button type="button" disabled={current.loading} onClick={event=>open(row,event)}>{offerName(row)}</button></h2>{row.RefArticle?<p className="product-offer-reference">Réf. {row.RefArticle}</p>:null}<span className="erp-status is-neutral">{row.EtatDisponibilite||"Stock à confirmer"}</span><div className="product-offer-money"><strong>{row.PVArticle==null?"Prix à confirmer":formatCurrency(row.PVArticle,row.DeviseCode)}</strong><small>{row.Unite?"Par "+row.Unite:"Unité non renseignée"}</small></div><div className="product-offer-company"><AppIcon name="building"/><div><strong>{row.NomEntite||"Entreprise"}</strong><span>{row.AdresseEntite||"Adresse à confirmer"}</span></div></div><ActionButton icon="eye" disabled={current.loading} onClick={event=>open(row,event)}>Consulter l’offre</ActionButton></div></article>)}</div>:current.loading?<ListState role="status" loading title="Recherche des offres…"/>:empty?emptyContent:null}</div>
      <div className="product-offer-pagination"><span role="status">{current.loading?"Actualisation…":current.error?"Résultats indisponibles":current.total?`${grid.skip+1}–${Math.min(grid.skip+grid.take,current.total)} sur ${current.total} offre${current.total>1?"s":""}`:"0 offre"}</span><div><ActionButton icon="chevron-left" disabled={current.loading||!grid.skip} onClick={()=>changeGrid({skip:Math.max(0,grid.skip-grid.take)})}>Précédent</ActionButton><span>Page {Math.floor(grid.skip/grid.take)+1} / {pages}</span><ActionButton icon="chevron-right" disabled={current.loading||current.error||grid.skip+grid.take>=(current.total||0)} onClick={()=>changeGrid({skip:grid.skip+grid.take})}>Suivant</ActionButton></div></div>
     </>}
    </div>
   </RegisterSurface>
  </main>
  {focusId?<ProductOfferDetail key={owner+":"+focusId} id={focusId} owner={owner} onClose={close} onContact={contact} canContact={canDiscuss}/>:null}
 </div>;
}
