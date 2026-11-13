import {useId,useState} from "react";
import {useSearchParams} from "react-router-dom";
import {useAuth} from "../../contexts/AuthContext";
import {useEntityScope} from "../../contexts/EntityScopeContext";
import {accessSignature} from "../../services/moduleAccess";
import {getDemands} from "../../services/demandes";
import RegisterSurface from "../../components/RegisterSurface";
import DataTableToolbar from "../../components/DataTableToolbar";
import ConsultationTabs from "../../components/ConsultationTabs";
import SearchSelect from "../../components/SearchSelect";
import ActionButton from "../../components/ActionButton";
import {SimpleTable,formatDate} from "../logistique/logistiqueShared";
import DemandDetail from "./DemandDetail";
import useDemandRead from "./useDemandRead";
import {validDemandId} from "./demandModel";
import "./Demandes.css";

export default function DemandRegister({title="Demandes"}){
 const {user}=useAuth(),scope=useEntityScope(),[params,setParams]=useSearchParams(),prefix=useId(),direction=params.get("direction")==="received"?"received":"sent",state=params.get("state")||"",search=params.get("search")||"",take=[10,25,50,100].includes(Number(params.get("take")))?Number(params.get("take")):25,rawSkip=Number(params.get("skip")),skip=Number.isInteger(rawSkip)&&rawSkip>=0?Math.floor(rawSkip/take)*take:0,id=validDemandId(params.get("demande")),owner=[user?.IdUser,scope.scopeKey,accessSignature(user)].join(":"),identity=JSON.stringify([owner,direction,state,search,take,skip]),[revision,setRevision]=useState(0),[draft,setDraft]=useState({key:"",search:"",state:""}),[filtersOpen,setFilters]=useState(false),[density,setDensity]=useState("compact"),current=useDemandRead({identity,revision,load:signal=>getDemands({direction,state,search,take,skip},signal),parse:response=>Array.isArray(response.data?.rows)&&Number.isInteger(response.data?.total)&&response.data.total>=0?{...response.data,meta:response.meta||{}}:null,message:"Les demandes n’ont pas pu être chargées."}),rows=current.data?.rows||[],states=current.data?.meta.states||[],draftKey=owner+":"+direction+":"+state+":"+search,inputs=draft.key===draftKey?draft:{key:draftKey,search,state},pending=inputs.search.trim()!==search||inputs.state!==state;
 function update(values,replace=false){const next=new URLSearchParams(params);for(const[key,value]of Object.entries(values)){if(value==null||value===""||value===0)next.delete(key);else next.set(key,String(value));}setParams(next,{replace});}
 function filter(key,value){setDraft({...inputs,[key]:value});}
 function apply(){if(inputs.search.trim().length>200)return;const same=inputs.search.trim()===search&&inputs.state===state&&skip===0;update({search:inputs.search.trim(),state:inputs.state,skip:0,demande:null});setDraft({key:"",search:"",state:""});if(same)setRevision(value=>value+1);}
 function reset(){update({search:null,state:null,skip:0,demande:null});setDraft({key:"",search:"",state:""});}
 const searchError=inputs.search.trim().length>200?"La recherche ne doit pas dépasser 200 caractères.":"",columns=[
  {key:"code",label:"Demande",sortable:false,width:140},
  {key:"subject",label:"Objet",sortable:false,width:260},
  {key:"source",label:"Source",sortable:false,width:220,render:row=>row.source?.label||"—"},
  {key:"participant",label:direction==="sent"?"Destinataire":"Demandeur",sortable:false,width:200,render:row=>direction==="sent"?row.recipient?.name||"—":row.requester?.name||"—"},
  {key:"stateLabel",label:"État",sortable:false,width:165,render:row=><span className="erp-status is-neutral">{row.stateLabel}</span>},
  {key:"createdAt",label:"Date et heure",sortable:false,width:170,render:row=>formatDate(row.createdAt)},
  {key:"actions",label:"Actions",sortable:false,width:80,render:row=><ActionButton icon="eye" className="is-icon" aria-label={"Consulter la demande "+row.code} onClick={()=>update({demande:row.id})}/>}
 ];
 const filterOptions=[{value:"",label:"Tous les états"},...states.map(item=>({value:String(item.id),label:item.label})),...(inputs.state&&!states.some(item=>String(item.id)===inputs.state)?[{value:inputs.state,label:"État sélectionné indisponible",disabled:true}]:[])];
 const toolbar=<DataTableToolbar search={inputs.search} setSearch={value=>filter("search",value)} onApply={apply} onReset={reset} pending={pending} take={take} onTake={value=>update({take:value,skip:0,demande:null})} filtersOpen={filtersOpen} toggleFilters={()=>setFilters(value=>!value)} activeFilters={Number(Boolean(state))} density={density} toggleDensity={()=>setDensity(value=>value==="airy"?"compact":"airy")} loading={current.loading} error={searchError||current.error} placeholder="Rechercher un numéro, un objet ou un destinataire…" showSettings={false} filterControlsId={prefix+"-filters"} filterContent={filtersOpen?<div id={prefix+"-filters"} className="demand-register-filters"><label><span>État de la demande</span><SearchSelect label="État de la demande" value={inputs.state} options={filterOptions} onChange={value=>filter("state",value)}/></label></div>:null}/>;
 return <RegisterSurface title={title} subtitle="Suivez vos besoins et leur traitement." tabs={<div className="demand-register-summary"><ConsultationTabs tabs={[{key:"sent",label:"Envoyées",icon:"send"},{key:"received",label:"Reçues",icon:"mail"}]} value={direction} onChange={value=>{update({direction:value,state:null,search:null,skip:0,demande:null});setDraft({key:"",search:"",state:""});}} label="Sens des demandes" idPrefix={prefix+"-direction"}/></div>}>
  <div className="demand-register-content erp-results" data-density={density} id={prefix+"-direction-panel-"+direction} role="tabpanel" aria-labelledby={prefix+"-direction-tab-"+direction} tabIndex={0}>{toolbar}<SimpleTable rows={rows} columns={columns} getRowId={row=>String(row.id)} enableSelection={false} showControls={false} showSearch={false} loading={current.loading} serverState={{take,skip}} serverMeta={current.data?{take,skip,filteredCount:current.data.total,totalCount:current.data.total}:null} onServerChange={change=>update({...change,demande:null})} onRowConsult={row=>update({demande:row.id})} consultColumns={["code","subject"]} tableLabel={direction==="sent"?"Demandes envoyées":"Demandes reçues"} emptyMessage={current.error?"La liste est indisponible.":direction==="sent"?"Aucune demande envoyée. Ouvrez une fiche produit, professionnel ou structure pour décrire votre besoin.":"Aucune demande reçue pour ce compte."}/>{current.error?<ActionButton icon="refresh" onClick={()=>setRevision(value=>value+1)} disabled={current.loading}>Réessayer</ActionButton>:null}</div>
  {id?<DemandDetail key={owner+":"+id} id={id} owner={owner} states={states} onClose={()=>update({demande:null})} onChanged={()=>setRevision(value=>value+1)}/>:null}
 </RegisterSurface>;
}
