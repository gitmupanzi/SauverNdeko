import {useEffect,useRef,useState} from "react";
import {Link,useSearchParams} from "react-router-dom";
import {useAuth} from "../../contexts/AuthContext";
import {useEntityScope} from "../../contexts/EntityScopeContext";
import {mayOpen} from "../../services/moduleAccess";
import RegisterSurface from "../../components/RegisterSurface";
import DataTableToolbar from "../../components/DataTableToolbar";
import ActionButton from "../../components/ActionButton";
import AppIcon from "../../components/AppIcon";
import EntityProfileEditor from "../../components/EntityProfileEditor";
import {SimpleTable} from "../logistique/logistiqueShared";
import useStructureRead from "./useStructureRead";
import {structureRows} from "./structureModel";

export default function StructureProfiles({owner,context,onContextReload}){
 const {user}=useAuth(),scope=useEntityScope(),[params,setParams]=useSearchParams(),[revision,setRevision]=useState(0),[editor,setEditor]=useState(null),[feedback,setFeedback]=useState(""),[density,setDensity]=useState("compact"),origin=useRef(null),fallback=useRef(null);
 const q=params.get("profilQ")||"",take=[10,25,50,100].includes(Number(params.get("profilTake")))?Number(params.get("profilTake")):25,rawSkip=Number(params.get("profilSkip")),skip=Number.isSafeInteger(rawSkip)&&rawSkip>=0?rawSkip:0,sortBy=params.get("profilSortBy")==="type"?"type":"name",sortDir=params.get("profilSortDir")==="desc"?"desc":"asc",[draft,setDraft]=useState(q);
 const query=new URLSearchParams({q,take,skip,sortBy,sortDir}),allowed=context.data?.canReadRegistry===true;
 const current=useStructureRead({owner,path:"/api/structures/profils?"+query,revision,enabled:allowed,retain:true,parse:structureRows,message:"Les profils des structures ne sont pas disponibles."});
 const rows=current.data?.rows||[],total=current.data?.total??null;
 useEffect(()=>{setDraft(q);},[q,owner]);
 useEffect(()=>{setEditor(null);setFeedback("");},[owner]);
 function change(patch){setParams(previous=>{const next=new URLSearchParams(previous);for(const [key,value] of Object.entries(patch))next.set("profil"+key[0].toUpperCase()+key.slice(1),String(value));return next;});}
 function search(){change({q:draft.trim(),skip:0});if(draft.trim()===q&&skip===0)setRevision(value=>value+1);}
 function open(row,mode,event){if(current.loading)return;origin.current=event?.currentTarget;setEditor({owner,id:row.id,mode});}
 function close(){setEditor(null);requestAnimationFrame(()=>{const target=origin.current?.isConnected?origin.current:fallback.current;target?.focus({preventScroll:true});});}
 function saved(){close();setRevision(value=>value+1);onContextReload?.();setFeedback("Profil de la structure enregistré.");}
 const columns=[{key:"name",label:"Structure",width:280,render:row=><button className="structure-profile-name" type="button" disabled={current.loading} onClick={event=>open(row,"view",event)}><AppIcon name="building"/>{row.name}</button>},{key:"type",label:"Type de structure",width:180,render:row=>row.type||"Non renseigné"},{key:"published",label:"Publication",sortable:false,width:160,render:row=><span className={"erp-status "+(row.published?"is-success":"is-neutral")}>{row.published?"Publiée":"Non publiée"}</span>},{key:"active",label:"État",sortable:false,width:120,render:row=>row.active?"Active":"Inactive"},{key:"actions",label:"Actions",sortable:false,width:145,render:row=><div className="structure-profile-actions"><ActionButton icon="eye" className="is-icon" aria-label={"Consulter "+row.name} disabled={current.loading} onClick={event=>open(row,"view",event)}/>{row.canManage&&context.data?.canManage?<ActionButton icon="edit" className="is-icon" aria-label={"Modifier "+row.name} disabled={current.loading} onClick={event=>open(row,"edit",event)}/>:null}</div>}];
 return <RegisterSurface title="Profils des structures" subtitle="La présentation de votre entreprise dans l’annuaire." actions={scope.globalAdmin&&mayOpen(user,"/admin")?<Link className="ui-action" to="/admin?onglet=entites"><AppIcon name="building"/>Gérer les entreprises</Link>:null}>
  <div className="structure-directory" ref={fallback} tabIndex={-1}>
   {context.loading?<p role="status">Chargement des accès…</p>:context.error?<div className="structure-error" role="alert"><span>{context.error}</span><ActionButton icon="refresh" onClick={onContextReload}>Réessayer</ActionButton></div>:!allowed?<p role="status">La gestion des profils est réservée aux gestionnaires des structures autorisées.</p>:<>
    {feedback?<p className="admin-feedback" role="status">{feedback}</p>:null}
    {scope.globalAdmin&&!scope.entityId?<p className="structure-note">Choisissez une entreprise dans l’en-tête pour modifier son profil.</p>:null}
    <DataTableToolbar search={draft} setSearch={setDraft} onApply={search} onReset={()=>{setDraft("");change({q:"",skip:0});}} pending={draft!==q} take={take} onTake={value=>change({take:value,skip:0})} loading={current.loading} showFilters={false} showSettings={false} density={density} toggleDensity={()=>setDensity(value=>value==="compact"?"airy":"compact")} placeholder="Rechercher une structure, un type ou une adresse…"/>
    {current.error?<div className="structure-error" role="alert"><span>{current.error}</span><ActionButton icon="refresh" onClick={()=>setRevision(value=>value+1)}>Réessayer</ActionButton></div>:null}
    <div className="erp-register-table erp-results" data-density={density}><SimpleTable rows={rows} columns={columns} getRowId={row=>row.id} enableSelection={false} loading={current.loading} showControls={false} defaultPinnedColumns={[]} serverMeta={current.loading||total==null?null:{filteredCount:total,totalCount:total,take,skip}} serverState={{take,skip,sortBy,sortDir}} onServerChange={change} emptyMessage={current.loading?"Chargement des profils…":current.error?"Les profils sont indisponibles.":"Aucun profil dans ce périmètre."}/></div>
   </>}
  </div>
  {editor?.owner===owner&&allowed?<EntityProfileEditor context="structures" recordId={editor.id} mode={editor.mode} canWrite={context.data?.canManage===true} initialTab="publication" onClose={close} onSaved={saved}/>:null}
 </RegisterSurface>;
}
