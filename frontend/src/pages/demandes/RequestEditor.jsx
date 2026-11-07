import {useEffect,useId,useRef,useState} from "react";
import RecordEditorFrame from "../../components/RecordEditorFrame";
import AppIcon from "../../components/AppIcon";
import {newMessageRequestId} from "../../services/communication";
import {createDemand} from "../../services/demandes";
import {demandDeliveryUncertain,demandDraftErrors,demandDraftPayload,demandFailure} from "./demandModel";
import "./Demandes.css";

export default function RequestEditor({context,onClose,onSaved}){
 const source=context.source,initialSubject=("Demande — "+source.label).slice(0,160),prefix=useId(),[draft,setDraft]=useState({subject:initialSubject,description:"",quantity:"",destination:""}),[errors,setErrors]=useState({}),[error,setError]=useState(""),[busy,setBusy]=useState(false),[uncertain,setUncertain]=useState(false),lock=useRef(false),mounted=useRef(false),pending=useRef(null),requestId=useRef(newMessageRequestId());
 useEffect(()=>{mounted.current=true;return()=>{mounted.current=false;};},[]);
 const dirty=Boolean(draft.description||draft.quantity||draft.destination||draft.subject!==initialSubject);
 function change(key,value){setDraft(previous=>({...previous,[key]:value}));setErrors(previous=>({...previous,[key]:""}));setError("");}
 async function submit(){
  if(lock.current||context.canCreate!==true)return;
  const invalid=demandDraftErrors(draft,source);setErrors(invalid);
  if(Object.keys(invalid).length){setError("Vérifiez les champs indiqués.");return;}
  lock.current=true;setBusy(true);setError("");
  const payload=pending.current||demandDraftPayload(draft,source,requestId.current);pending.current=payload;
  const response=await createDemand(payload);
  if(!mounted.current)return;
  lock.current=false;setBusy(false);
  if(response?.success){setUncertain(false);onSaved(response.data?.record||response.data);return;}
  const unknown=demandDeliveryUncertain(response);setUncertain(unknown);
  if(!unknown)pending.current=null;
  setError(unknown?"La confirmation n’a pas été reçue. Réessayez : la même demande sera vérifiée, sans nouvel envoi.":demandFailure(response,"La demande n’a pas pu être envoyée."));
 }
 function close(){if(uncertain){setError("Réessayez pour vérifier l’enregistrement avant de quitter ce formulaire.");return;}onClose();}
 const field=(key,label,props={})=><label className={props.wide?"is-wide":""} htmlFor={prefix+key}><span>{label}</span>{props.multiline?<textarea id={prefix+key} value={draft[key]} maxLength={props.maxLength} required={props.required} aria-invalid={Boolean(errors[key])} aria-describedby={errors[key]?prefix+key+"-error":undefined} onChange={event=>change(key,event.target.value)}/>:<input id={prefix+key} value={draft[key]} maxLength={props.maxLength} required={props.required} inputMode={props.inputMode} aria-invalid={Boolean(errors[key])} aria-describedby={errors[key]?prefix+key+"-error":undefined} onChange={event=>change(key,event.target.value)}/>} {errors[key]?<span className="demand-field-error" id={prefix+key+"-error"}>{errors[key]}</span>:null}</label>;
 return <RecordEditorFrame title="Nouvelle demande" subtitle={source.label} icon="document" onClose={close} onSubmit={submit} busy={busy} dirty={dirty} error={error} canSubmit={context.canCreate===true} submitLabel={uncertain?"Vérifier l’envoi":"Envoyer la demande"} defaultWidth={780} storageKey="sauverndeko.demandes.editor.width">
  <section className="record-editor-section demand-context"><strong>{source.label}</strong><span>Destinataire : {context.recipient?.name||"Non disponible"}</span><p className="demand-note">Votre demande sera transmise à ce destinataire. Elle ne constitue pas une réservation ni une commande.</p></section>
  <section className="record-editor-section"><h3><AppIcon name="document"/>Votre besoin</h3><fieldset disabled={busy||uncertain} style={{border:0,padding:0,margin:0}}><div className="demand-fields">
   {field("subject","Objet *",{wide:true,required:true,maxLength:160})}
   {source.type==="product"?<>{field("quantity","Quantité souhaitée",{inputMode:"decimal",maxLength:24})}<label><span>Unité du produit</span><input readOnly value={source.unit||"Non renseignée"}/></label></>:null}
   {field("destination","Lieu souhaité",{wide:true,maxLength:300})}
   {field("description","Description du besoin *",{wide:true,required:true,multiline:true,maxLength:5000})}
  </div></fieldset><p className="demand-note" style={{marginTop:14}}>Indiquez les informations utiles au traitement. Évitez les informations personnelles ou médicales qui ne sont pas nécessaires.</p></section>
 </RecordEditorFrame>;
}
