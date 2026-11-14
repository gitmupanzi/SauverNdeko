import {useEffect,useId,useRef,useState} from "react";
import {useLocation,useSearchParams} from "react-router-dom";
import {useAuth} from "../../contexts/AuthContext";
import {accessSignature} from "../../services/moduleAccess";
import useReferencesRefresh from "../../hooks/useReferencesRefresh";
import RegisterSurface from "../../components/RegisterSurface";
import AppliedCriteria from "../../components/AppliedCriteria";
import ListState from "../../components/ListState";
import SearchNeedAction from "../../components/SearchNeedAction";
import DataTableToolbar from "../../components/DataTableToolbar";
import ActionButton from "../../components/ActionButton";
import AppIcon from "../../components/AppIcon";
import SearchSelect from "../../components/SearchSelect";
import {SimpleTable} from "../logistique/logistiqueShared";
import useStructureRead from "./useStructureRead";
import StructureDetail from "./StructureDetail";
import {SANITARY_ROOT,EMPTY_STRUCTURE_CRITERIA,structureLocation,structureParams,structureQuery,structureSearchError,structureOptions,sanitaryRows,sanitaryReferences,structureLastPage,structureId,structureName,validStructureKey,structureLevelLabel,structureTerritory} from "./structureModel";
import "./Structures.css";

function preferredDisplay(){try{return localStorage.getItem("sauverndeko.structures.display")==="table"?"table":"cards";}catch{return "cards";}}
export default function StructureDirectory(){
 const {user}=useAuth(),location=useLocation(),[params,setParams]=useSearchParams(),prefix=useId(),fallbackFocus=useRef(null),origin=useRef(null),deepLink=useRef(null),draftAfterRemoval=useRef(null);
 const {criteria,grid,focusKey,invalidFocus}=structureLocation(params),criteriaKey=JSON.stringify(criteria),owner=[user?.IdUser,accessSignature(user)].join(":");
 const [draft,setDraft]=useState(criteria),[filtersOpen,setFiltersOpen]=useState(false),[display,setDisplay]=useState(preferredDisplay),[density,setDensity]=useState("compact"),[revision,setRevision]=useState(0),[searchError,setSearchError]=useState("");
 const references=useStructureRead({owner,path:SANITARY_ROOT+"/references",parse:sanitaryReferences,revision,message:"Les filtres ne sont pas disponibles."});
 const current=useStructureRead({owner,path:SANITARY_ROOT+"?"+structureQuery(criteria,grid),parse:sanitaryRows,revision,retain:true,message:"La recherche n’a pas abouti. Réessayez."});
 const rows=current.data?.rows||[],total=current.data?.total??null,pages=Math.max(1,Math.ceil((total||0)/grid.take)),pending=JSON.stringify(draft)!==criteriaKey,activeFilters=Object.values(criteria).filter(Boolean).length;
 const typeChoices=(references.data?.types||[]).filter(item=>!draft.level||!Array.isArray(item.levels)||item.levels.map(String).includes(draft.level));
 function changeGrid(patch){setParams(structureParams(params,criteria,{...grid,...patch}));}
 useReferencesRefresh(()=>setRevision(value=>value+1));
 useEffect(()=>{const saved=draftAfterRemoval.current;setDraft(saved?.owner===owner&&saved?.criteria===criteriaKey?saved.draft:criteria);draftAfterRemoval.current=null;setSearchError("");},[criteriaKey,owner]);
 useEffect(()=>{try{localStorage.setItem("sauverndeko.structures.display",display);}catch{}},[display]);
 useEffect(()=>{if(!current.loading&&!current.error&&total!=null&&grid.skip>0&&grid.skip>=total)changeGrid({skip:structureLastPage(total,grid.take)});},[current.loading,current.error,total,grid.skip,grid.take]);
 useEffect(()=>{const key=validStructureKey(location.state?.focusKey||location.state?.focusId);if(!key||deepLink.current===location.key)return;deepLink.current=location.key;const next=new URLSearchParams(params);next.set("structure",key);setParams(next,{replace:true,state:null});},[location.key,location.state]);
 function apply(){const next={...draft,q:draft.q.trim(),locality:draft.locality.trim()},invalid=structureSearchError(next);setSearchError(invalid);if(invalid)return;setDraft(next);if(JSON.stringify(next)===criteriaKey&&grid.skip===0)setRevision(value=>value+1);setParams(structureParams(params,next,{...grid,skip:0}));}
 function removeCriterion(key){const next={...criteria,[key]:""},nextDraft={...draft,[key]:""};draftAfterRemoval.current={owner,criteria:JSON.stringify(next),draft:nextDraft};setDraft(nextDraft);setSearchError("");setParams(structureParams(params,next,{...grid,skip:0}));}
 function reset(){setDraft({...EMPTY_STRUCTURE_CRITERIA});setSearchError("");setParams(structureParams(params,EMPTY_STRUCTURE_CRITERIA,{...grid,skip:0}));}
 function open(row,event){if(current.loading)return;const key=structureId(row);if(!key)return;event?.stopPropagation();origin.current=event?.currentTarget||document.activeElement;const next=new URLSearchParams(params);next.set("structure",key);setParams(next);}
 function close(){const next=new URLSearchParams(params);next.delete("structure");setParams(next,{replace:true,state:null});requestAnimationFrame(()=>{const target=origin.current?.isConnected?origin.current:fallbackFocus.current;target?.focus({preventScroll:true});});}
 const referenceLabel=(key,items)=>criteria[key]?(items?.find(item=>String(item.id)===criteria[key])?.label||"Valeur sélectionnée"):"";
 const columns=[
  {key:"name",label:"Structure ou territoire",width:290,render:row=><div className="structure-table-name"><span className="structure-logo" aria-hidden="true"><AppIcon name="building"/></span><button type="button" disabled={current.loading} onClick={event=>open(row,event)}>{structureName(row)}</button></div>},
  {key:"type",label:"Type",width:190,render:row=>row.type||"Non renseigné"},
  {key:"level",label:"Niveau territorial",sortable:false,width:180,render:row=>structureLevelLabel(row.level)},
  {key:"territory",label:"Rattachement territorial",sortable:false,width:270,render:structureTerritory},
  {key:"address",label:"Adresse",sortable:false,width:270,render:row=>row.contactsPublished?row.address||"Non renseignée":"Coordonnées non publiées"},
  {key:"phone",label:"Téléphone",sortable:false,width:180,render:row=>row.contactsPublished?row.phone||"Non renseigné":"—"},
  {key:"hours",label:"Horaires d’ouverture",sortable:false,width:240,render:row=><span className="structure-multiline">{row.contactsPublished?row.hours||"Non renseignés":"—"}</span>},
  {key:"actions",label:"Actions",sortable:false,width:85,render:row=><ActionButton icon="eye" className="is-icon" aria-label={"Consulter "+structureName(row)} disabled={current.loading} onClick={event=>open(row,event)}/>}
 ];
 const empty=!current.loading&&!current.error&&total===0;
 const emptyContent=<ListState role="status" icon="building" title={activeFilters?"Aucun résultat ne correspond à ces critères":"Aucune entrée disponible"} description={activeFilters?"Essayez un autre nom ou élargissez les filtres.":"Les structures, sites et territoires renseignés apparaîtront dans cet annuaire."} action={activeFilters?<>{!pending?<SearchNeedAction source="structure"/>:null}<ActionButton icon="reset" onClick={reset}>Effacer les critères</ActionButton></>:null}/>;
 return <div ref={fallbackFocus} tabIndex={-1} className="structure-directory-root"><RegisterSurface title="Trouver une structure ou un territoire" subtitle="Structures, sites, zones, districts, secteurs et autres territoires." actions={<div className="structure-display" role="group" aria-label="Affichage des structures"><ActionButton icon="apps" aria-label="Affichage en cartes" aria-pressed={display==="cards"} onClick={()=>setDisplay("cards")}/><ActionButton icon="table" aria-label="Affichage en tableau" aria-pressed={display==="table"} onClick={()=>setDisplay("table")}/></div>}>
  <div className="structure-directory" data-density={density} aria-busy={current.loading}>
   {invalidFocus?<p role="status" className="structure-note">Ce lien de structure n’est plus valide. Recherchez la structure dans l’annuaire.</p>:null}
   {references.error?<div className="structure-error" role="alert"><span>{references.error}</span><ActionButton icon="refresh" onClick={()=>setRevision(value=>value+1)}>Recharger les filtres</ActionButton></div>:null}
   {current.error?<div className="structure-error" role="alert"><span>{current.error}</span><ActionButton icon="refresh" onClick={()=>setRevision(value=>value+1)}>Réessayer</ActionButton></div>:null}
   <DataTableToolbar search={draft.q} setSearch={q=>{setDraft(previous=>({...previous,q}));setSearchError("");}} onApply={apply} onReset={reset} pending={pending} take={grid.take} onTake={take=>changeGrid({take,skip:0})} filtersOpen={filtersOpen} toggleFilters={()=>setFiltersOpen(value=>!value)} filterControlsId={prefix+"-filters"} activeFilters={activeFilters} density={density} toggleDensity={()=>setDensity(value=>value==="compact"?"airy":"compact")} loading={current.loading} showSettings={false} error={searchError} placeholder="Rechercher une structure, un territoire, un type ou une localité…"/>
   {filtersOpen?<form id={prefix+"-filters"} className="erp-register-filters" onSubmit={event=>{event.preventDefault();apply();}}><div className="erp-register-filter-grid">
    <label><span>Niveau territorial</span><SearchSelect label="Niveau territorial" value={draft.level} options={structureOptions(references.data?.levels||[],draft.level,"Tous les niveaux")} disabled={references.loading} onChange={level=>setDraft(previous=>({...previous,level}))}/></label>
    <label><span>Type de structure</span><SearchSelect label="Type de structure" value={draft.typeId} options={structureOptions(typeChoices,draft.typeId)} disabled={references.loading} onChange={typeId=>setDraft(previous=>({...previous,typeId}))}/></label>
    <label><span>Province ou DPS</span><SearchSelect label="Province ou DPS" value={draft.provinceId} options={structureOptions(references.data?.provinces||[],draft.provinceId,"Toutes les provinces et DPS")} disabled={references.loading} onChange={provinceId=>setDraft(previous=>({...previous,provinceId}))}/></label>
    <label htmlFor={prefix+"-locality"}><span>Localité ou adresse</span><input id={prefix+"-locality"} type="search" value={draft.locality} placeholder="Province, zone, aire, site ou adresse…" onChange={event=>setDraft(previous=>({...previous,locality:event.target.value}))}/></label>
   </div><div className="erp-register-filters-footer"><ActionButton type="submit" variant="primary" disabled={current.loading||references.loading}>Appliquer les filtres</ActionButton></div></form>:null}
   <AppliedCriteria items={[{key:"q",label:"Recherche",value:criteria.q},{key:"level",label:"Niveau territorial",value:referenceLabel("level",references.data?.levels)},{key:"typeId",label:"Type",value:referenceLabel("typeId",references.data?.types)},{key:"provinceId",label:"Province ou DPS",value:referenceLabel("provinceId",references.data?.provinces)},{key:"locality",label:"Localité",value:criteria.locality}]} onRemove={removeCriterion} disabled={current.loading}/>
   {activeFilters>0&&!pending&&!current.loading&&!current.error&&rows.length>0
     ? <SearchNeedAction source="structure" shareSearch/> : null}
   {display==="table"?<div className="erp-register-table erp-results" data-density={density}>{empty?emptyContent:<SimpleTable rows={rows} columns={columns} getRowId={structureId} serverMeta={current.loading||total==null?null:{filteredCount:total,totalCount:total,take:grid.take,skip:grid.skip}} serverState={grid} onServerChange={changeGrid} enableSelection={false} loading={current.loading} defaultPinnedColumns={[]} showControls={false} emptyMessage={current.loading?"Chargement des fiches…":current.error?"La liste est indisponible.":"Aucun résultat pour ces critères."}/>}</div>:<><div className="structure-results" aria-label="Structures et territoires">{rows.length?<div className="structure-cards">{rows.map(row=><article className="structure-card" key={structureId(row)}><header><span className="structure-logo" aria-hidden="true"><AppIcon name="building"/></span><span>{row.type||"Type non renseigné"}</span></header><div className="structure-card-copy"><h2><button type="button" disabled={current.loading} onClick={event=>open(row,event)}>{structureName(row)}</button></h2><p className="structure-summary">{structureLevelLabel(row.level)}{structureTerritory(row)?" · "+structureTerritory(row):""}</p><dl className="structure-card-contact"><div><dt><AppIcon name="globe"/>Adresse</dt><dd>{row.contactsPublished?row.address||"Non renseignée":"Coordonnées non publiées"}</dd></div>{row.contactsPublished?<><div><dt>Téléphone</dt><dd>{row.phone||"Non renseigné"}</dd></div><div><dt><AppIcon name="clock"/>Horaires d’ouverture</dt><dd className="structure-multiline">{row.hours||"Non renseignés"}</dd></div></>:null}</dl><ActionButton icon="eye" disabled={current.loading} onClick={event=>open(row,event)}>Consulter la fiche</ActionButton></div></article>)}</div>:current.loading?<ListState role="status" loading title="Recherche des structures et territoires…"/>:empty?emptyContent:null}</div><div className="structure-pagination"><span role="status">{current.loading?"Actualisation…":current.error?"Résultats indisponibles":total?`${grid.skip+1}–${Math.min(grid.skip+grid.take,total)} sur ${total} résultat${total>1?"s":""}`:"0 résultat"}</span><div><ActionButton icon="chevron-left" disabled={current.loading||!grid.skip} onClick={()=>changeGrid({skip:Math.max(0,grid.skip-grid.take)})}>Précédent</ActionButton><span>Page {Math.floor(grid.skip/grid.take)+1} / {pages}</span><ActionButton icon="chevron-right" disabled={current.loading||Boolean(current.error)||grid.skip+grid.take>=(total||0)} onClick={()=>changeGrid({skip:grid.skip+grid.take})}>Suivant</ActionButton></div></div></>}
  </div>
 </RegisterSurface>{focusKey?<StructureDetail key={owner+":"+focusKey} structureKey={focusKey} owner={owner} onClose={close}/>:null}</div>;
}
