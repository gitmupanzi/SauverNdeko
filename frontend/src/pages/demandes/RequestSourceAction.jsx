import {useEffect,useId,useRef,useState} from "react";
import {useNavigate} from "react-router-dom";
import {useAuth} from "../../contexts/AuthContext";
import {useEntityScope} from "../../contexts/EntityScopeContext";
import {accessSignature} from "../../services/moduleAccess";
import {getDemandSource,saveDemandRouting} from "../../services/demandes";
import {newMessageRequestId} from "../../services/communication";
import ActionButton from "../../components/ActionButton";
import RecordEditorFrame from "../../components/RecordEditorFrame";
import SearchSelect from "../../components/SearchSelect";
import RequestEditor from "./RequestEditor";
import {demandDeliveryUncertain,demandFailure,demandSourceKey} from "./demandModel";
import useDemandRead from "./useDemandRead";
import "./Demandes.css";

function RoutingEditor({context,onClose,onSaved,onReload}){
 const prefix=useId(),[entityId,setEntity]=useState(String(context.routing?.entityId||"")),[reason,setReason]=useState(""),[busy,setBusy]=useState(false),[error,setError]=useState(""),[uncertain,setUncertain]=useState(false),lock=useRef(false),pending=useRef(null),requestId=useRef(newMessageRequestId()),alive=useRef(false);
 useEffect(()=>{alive.current=true;return()=>{alive.current=false;};},[]);
 async function submit(){if(lock.current||!reason.trim())return;lock.current=true;setBusy(true);setError("");const body=pending.current||{entityId:entityId?Number(entityId):null,version:context.routing?.version,reason:reason.trim(),requestId:requestId.current};pending.current=body;const result=await saveDemandRouting(context.source,body);if(!alive.current)return;lock.current=false;setBusy(false);if(result?.success){onSaved();return;}const unknown=demandDeliveryUncertain(result);setUncertain(unknown);if(!unknown)pending.current=null;setError(unknown?"La confirmation n’a pas été reçue. Réessayez pour vérifier ce même rattachement.":demandFailure(result,"Le destinataire n’a pas pu être enregistré."));}
 const options=[{value:"",label:"Aucun destinataire"},...(context.entities||[]).map(item=>({value:String(item.id),label:item.label}))];
 return <RecordEditorFrame title="Destinataire des demandes" subtitle={context.source.label} icon="building" onClose={()=>{if(!uncertain)onClose();else setError("Réessayez pour vérifier le rattachement avant de quitter.");}} onSubmit={submit} busy={busy} dirty={entityId!==String(context.routing?.entityId||"")||Boolean(reason)} error={error} onReload={!uncertain?onReload:undefined} canSubmit={Boolean(reason.trim())} submitLabel={uncertain?"Vérifier l’enregistrement":"Enregistrer le destinataire"} defaultWidth={700} storageKey="sauverndeko.demandes.routing.width">
  <section className="record-editor-section"><p className="demand-note">Choisissez l’entreprise qui recevra les demandes pour cette structure ou ce territoire. Ce rattachement est explicite et reste enregistré dans l’historique.</p><fieldset disabled={busy||uncertain} style={{border:0,padding:0,margin:"18px 0 0"}}><div className="demand-fields"><label className="is-wide"><span>Entreprise destinataire</span><SearchSelect label="Entreprise destinataire" value={entityId} options={options} onChange={setEntity}/></label><label className="is-wide" htmlFor={prefix+"-reason"}><span>Motif du changement *</span><textarea id={prefix+"-reason"} required maxLength={1000} value={reason} onChange={event=>setReason(event.target.value)}/></label></div></fieldset></section>
 </RecordEditorFrame>;
}

export default function RequestSourceAction({sourceType,sourceId}){
 const {user}=useAuth(),scope=useEntityScope(),navigate=useNavigate(),source={type:sourceType,id:sourceId},identity=demandSourceKey(source),owner=[user?.IdUser,scope.scopeKey,accessSignature(user)].join(":"),[retry,setRetry]=useState(0),[opened,setOpened]=useState(null),key=owner+":"+identity+":"+retry,current=useDemandRead({identity:owner+":"+identity,revision:retry,load:signal=>getDemandSource(source,signal),parse:response=>demandSourceKey(response.data?.source)===identity?response.data:null,message:"Le service des demandes n’est pas disponible."}),context=current.data;
 if(!identity)return null;
 const drawer=opened?.key===key?opened.mode:null;
 return <div className="demand-source-action"><div className="demand-source-action-buttons"><ActionButton icon="document" variant="primary" disabled={current.loading||Boolean(current.error)||context?.canCreate!==true} onClick={()=>setOpened({key,mode:"create"})}>Faire une demande</ActionButton>{context?.canConfigureRouting===true?<ActionButton icon="settings" disabled={current.loading||Boolean(current.error)} onClick={()=>setOpened({key,mode:"routing"})}>Destinataire des demandes</ActionButton>:null}{current.error?<ActionButton icon="refresh" onClick={()=>setRetry(value=>value+1)}>Réessayer</ActionButton>:null}</div>
  {current.error?<p className="demand-note" role="status">{current.error}</p>:context&&!context.canCreate?<p className="demand-note">{context.unavailableReason||"Aucun destinataire n’est configuré pour recevoir une demande. Les coordonnées publiées restent disponibles."}</p>:context?.recipient?<p className="demand-note">Destinataire : {context.recipient.name}</p>:null}
  {drawer==="create"&&context?<RequestEditor context={context} onClose={()=>setOpened(null)} onSaved={record=>{setOpened(null);navigate("/discussions?onglet=demandes&demande="+encodeURIComponent(record.id));}}/>:null}
  {drawer==="routing"&&context?<RoutingEditor context={context} onClose={()=>setOpened(null)} onSaved={()=>{setOpened(null);setRetry(value=>value+1);}} onReload={()=>{setOpened(null);setRetry(value=>value+1);}}/>:null}
 </div>;
}
