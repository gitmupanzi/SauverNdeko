import {useEffect,useId,useRef,useState} from "react";
import {useNavigate} from "react-router-dom";
import RecordEditorFrame from "../../components/RecordEditorFrame";
import ActionButton from "../../components/ActionButton";
import AppIcon from "../../components/AppIcon";
import ConsultationTabs from "../../components/ConsultationTabs";
import {getDemand,actOnDemand,openDemandDiscussion} from "../../services/demandes";
import {newMessageRequestId} from "../../services/communication";
import {formatDate} from "../logistique/logistiqueShared";
import {demandDeliveryUncertain,demandFailure,validDemandId} from "./demandModel";
import useDemandRead from "./useDemandRead";
import "./Demandes.css";

function TransitionEditor({record,action,onClose,onSaved,onReload}){
 const prefix=useId(),[reason,setReason]=useState(""),[error,setError]=useState(""),[busy,setBusy]=useState(false),[uncertain,setUncertain]=useState(false),lock=useRef(false),alive=useRef(false),pending=useRef(null),requestId=useRef(newMessageRequestId());
 useEffect(()=>{alive.current=true;return()=>{alive.current=false;};},[]);
 async function submit(){
  if(lock.current)return;
  if(action.requiresReason&&!reason.trim()){setError("Précisez le motif de cette opération.");return;}
  lock.current=true;setBusy(true);setError("");
  const body=pending.current||{state:action.key,version:record.version,reason:reason.trim(),requestId:requestId.current};pending.current=body;
  const response=await actOnDemand(record.id,body);
  if(!alive.current)return;lock.current=false;setBusy(false);
  if(response?.success){onSaved(response.data?.record||response.data);return;}
  const unknown=demandDeliveryUncertain(response);setUncertain(unknown);if(!unknown)pending.current=null;
  setError(unknown?"La confirmation n’a pas été reçue. Réessayez pour vérifier la même opération.":demandFailure(response,"La demande n’a pas pu être mise à jour."));
 }
 const close=()=>{if(!uncertain)onClose();else setError("Réessayez pour vérifier l’opération avant de quitter.");};
 return <RecordEditorFrame title={action.label} subtitle={record.code} icon="check-circle" onClose={close} onSubmit={submit} busy={busy} dirty={Boolean(reason)} canSubmit={!action.requiresReason||Boolean(reason.trim())} error={error} onReload={!uncertain?onReload:undefined} submitLabel={uncertain?"Vérifier l’opération":"Confirmer"} defaultWidth={640} storageKey="sauverndeko.demandes.action.width">
  <section className="record-editor-section"><h3>{record.subject}</h3><p className="demand-note">Confirmez cette opération. Son auteur et son motif seront conservés dans l’historique.</p><div className="demand-fields" style={{marginTop:16}}><label className="is-wide" htmlFor={prefix+"-reason"}><span>Motif{action.requiresReason?" *":" (facultatif)"}</span><textarea id={prefix+"-reason"} required={action.requiresReason} maxLength={1000} value={reason} disabled={busy||uncertain} onChange={event=>setReason(event.target.value)}/></label></div></section>
 </RecordEditorFrame>;
}

export default function DemandDetail({id,owner,states=[],onClose,onChanged}){
 const navigate=useNavigate(),[revision,setRevision]=useState(0),[tab,setTab]=useState("demande"),[action,setAction]=useState(null),[busy,setBusy]=useState(false),[discussionError,setDiscussionError]=useState(""),discussionPending=useRef(null),lock=useRef(false),alive=useRef(false),current=useDemandRead({identity:owner+":"+id,revision,load:signal=>getDemand(id,signal),parse:response=>String(response.data?.record?.id)===String(id)&&Array.isArray(response.data?.history)?response.data:null,message:"Cette demande n’est pas disponible."}),record=current.data?.record,history=current.data?.history||[],prefix=useId();
 useEffect(()=>{alive.current=true;return()=>{alive.current=false;};},[]);
 const labels=new Map(states.map(item=>[String(item.id),item.label]));if(record)labels.set(record.state,record.stateLabel);
 const historyLabel=item=>item.action==="creation"?"Demande envoyée":item.action==="discussion"?"Discussion ouverte":labels.get(item.toState)||item.toState;
 const term=(label,value)=><div><dt>{label}</dt><dd>{value??"—"}</dd></div>;
 async function openDiscussion(){
  if(lock.current||record?.canOpenDiscussion!==true)return;
  if(validDemandId(record.discussionId)){navigate("/discussions?onglet=messages&discussion="+encodeURIComponent(record.discussionId));return;}
  lock.current=true;setBusy(true);setDiscussionError("");
  const body=discussionPending.current||{version:record.version,requestId:newMessageRequestId()};discussionPending.current=body;
  const result=await openDemandDiscussion(id,body);if(!alive.current)return;lock.current=false;setBusy(false);
  if(result?.success&&validDemandId(result.data?.discussionId)){navigate("/discussions?onglet=messages&discussion="+encodeURIComponent(result.data.discussionId));return;}
  if(!demandDeliveryUncertain(result))discussionPending.current=null;
  setDiscussionError(demandDeliveryUncertain(result)?"La confirmation n’a pas été reçue. Réessayez pour retrouver cette même discussion.":demandFailure(result,"La discussion n’a pas pu être ouverte."));
 }
 function changed(){setAction(null);setRevision(value=>value+1);onChanged?.();}
 return <><RecordEditorFrame title="Demande suivie" subtitle={record?.code||"Consultation"} icon="document" readOnly loading={current.loading} error={current.error} onReload={()=>setRevision(value=>value+1)} onClose={onClose} busy={busy} defaultWidth={920} storageKey="sauverndeko.demandes.detail.width">
  {record?<><section className="record-editor-section"><div className="demand-detail-heading"><div><h3>{record.subject}</h3><p className="demand-note">{record.code}</p></div><span className="erp-status is-neutral">{record.stateLabel}</span></div><div className="demand-actions" style={{marginTop:16}}>{(record.actions||[]).map(item=><ActionButton key={item.key} icon="check-circle" disabled={current.loading||Boolean(current.error)||busy||Boolean(discussionPending.current)} onClick={()=>setAction(item)}>{item.label}</ActionButton>)}{record.canOpenDiscussion===true?<ActionButton icon="chat" variant="primary" disabled={current.loading||Boolean(current.error)||busy} onClick={openDiscussion}>{busy?"Ouverture…":record.discussionId?"Ouvrir la discussion":"Démarrer une discussion"}</ActionButton>:null}</div>{discussionError?<p className="demand-field-error" role="alert" style={{marginTop:12}}>{discussionError}</p>:null}</section>
   <ConsultationTabs tabs={[{key:"demande",label:"Demande",icon:"document"},{key:"historique",label:"Historique",icon:"clock"}]} value={tab} onChange={setTab} label="Rubriques de la demande" idPrefix={prefix}/>
   <section className="record-editor-section" id={prefix+"-panel-"+tab} role="tabpanel" aria-labelledby={prefix+"-tab-"+tab} tabIndex={0}>
    {tab==="demande"?<><dl className="demand-detail-terms">{term("Source",record.source?.label)}{term("Demandeur",record.requester?.name)}{term("Destinataire",record.recipient?.name)}{term("Créée le",formatDate(record.createdAt))}{term("Mise à jour le",formatDate(record.updatedAt))}{record.quantity!=null?term("Quantité souhaitée",record.quantity+(record.unit?" "+record.unit:"")):null}{record.destination?term("Lieu souhaité",record.destination):null}</dl><h3 style={{marginTop:24}}><AppIcon name="document"/>Description du besoin</h3><p className="demand-description">{record.description}</p><p className="demand-note" style={{marginTop:18}}>Cette demande ne réserve aucun stock et ne crée pas de commande. La discussion est ouverte uniquement à votre demande.</p></>:history.length?<ol className="demand-history">{history.map(item=><li key={item.id}><strong>{historyLabel(item)}</strong><small>{item.actorName} · {formatDate(item.createdAt)}</small>{item.reason?<p>{item.reason}</p>:null}</li>)}</ol>:<p className="demand-note">Aucun changement d’état enregistré.</p>}
   </section>
  </>:null}
 </RecordEditorFrame>{action&&record?<TransitionEditor key={record.id+":"+action.key+":"+record.version} record={record} action={action} onClose={()=>setAction(null)} onSaved={changed} onReload={()=>{setAction(null);setRevision(value=>value+1);}}/>:null}</>;
}
