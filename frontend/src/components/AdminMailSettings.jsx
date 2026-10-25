import {useEffect,useId,useRef,useState} from "react";
import RecordEditorFrame from "./RecordEditorFrame";
import ActionButton from "./ActionButton";
import AppIcon from "./AppIcon";
import {fetchMailSettings,saveMailSettings} from "../services/mail";
import {formatDate} from "../pages/logistique/logistiqueShared";
import "./AdminMailSettings.css";

export default function AdminMailSettings({onClose}) {
  const prefix=useId(),mounted=useRef(true),saving=useRef(false),first=useRef(null);
  const [data,setData]=useState(null),[values,setValues]=useState({senderEmail:"",senderName:""}),[initial,setInitial]=useState("");
  const [loading,setLoading]=useState(true),[busy,setBusy]=useState(false),[error,setError]=useState(""),[errors,setErrors]=useState({}),[revision,setRevision]=useState(0),[feedback,setFeedback]=useState("");
  const dirty=Boolean(initial)&&JSON.stringify(values)!==initial,canManage=data?.canManage===true;
  useEffect(()=>{mounted.current=true;return()=>{mounted.current=false;};},[]);
  useEffect(()=>{let active=true;setLoading(true);setError("");fetchMailSettings().then(result=>{
    if(!active)return;
    if(!result?.success){setData(null);setError(result?.message||"Les réglages d’envoi sont indisponibles.");}
    else{const fields={senderEmail:result.data.senderEmail||"",senderName:result.data.senderName||""};setData(result.data);setValues(fields);setInitial(JSON.stringify(fields));}
    setLoading(false);
  });return()=>{active=false;};},[revision]);
  useEffect(()=>{if(loading||!canManage)return;const frame=requestAnimationFrame(()=>first.current?.focus({preventScroll:true}));return()=>cancelAnimationFrame(frame);},[loading,canManage]);
  function change(key,value){if(saving.current)return;setValues(current=>({...current,[key]:value}));setErrors(current=>({...current,[key]:""}));setError("");setFeedback("");}
  async function submit(){
    if(saving.current||!canManage||!dirty)return;
    const payload={senderEmail:values.senderEmail.trim(),senderName:values.senderName.trim()},invalid={};
    if(!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(payload.senderEmail)||payload.senderEmail.length>254)invalid.senderEmail="Renseignez une adresse e-mail valide.";
    if(!payload.senderName||payload.senderName.length>100||/[\r\n]/.test(payload.senderName))invalid.senderName="Renseignez un nom de 100 caractères au maximum.";
    setErrors(invalid);setError("");
    if(Object.keys(invalid).length){requestAnimationFrame(()=>document.getElementById(prefix+Object.keys(invalid)[0])?.focus());return;}
    saving.current=true;setBusy(true);const result=await saveMailSettings(payload);
    if(!mounted.current)return;saving.current=false;setBusy(false);
    if(!result?.success){const details=result?.error?.details,invalid=details&&typeof details==="object"&&!Array.isArray(details)?Object.fromEntries(Object.entries(details).filter(([key])=>key in values).map(([key,value])=>[key,String(value)])):{};setErrors(invalid);setError(Object.keys(invalid).length?"Vérifiez les champs indiqués.":result?.message||"Les réglages n’ont pas pu être enregistrés.");if(Object.keys(invalid).length)requestAnimationFrame(()=>document.getElementById(prefix+Object.keys(invalid)[0])?.focus());return;}
    const fields={senderEmail:result.data.senderEmail,senderName:result.data.senderName};setData(result.data);setValues(fields);setInitial(JSON.stringify(fields));setFeedback("Adresse expéditrice enregistrée.");
  }
  return <RecordEditorFrame title="Messagerie" subtitle="Adresse expéditrice" icon="mail" onClose={onClose} onSubmit={submit} submitLabel="Enregistrer les réglages" loading={loading} busy={busy} dirty={dirty} canSubmit={canManage&&dirty} error={error} onReload={!data&&!loading?()=>setRevision(value=>value+1):null} storageKey="sauverndeko.mail-settings.width">
    {!loading&&data?<>
      {feedback?<p className="record-result" role="status"><AppIcon name="check-circle"/>{feedback}</p>:null}
      <section className="record-editor-section"><h3><AppIcon name="mail"/>Expéditeur des e-mails</h3><div className="record-editor-grid">
        {[{key:"senderName",label:"Nom affiché",maxLength:100},{key:"senderEmail",label:"Adresse expéditrice",maxLength:254,type:"email"}].map(({key,label,...attributes},index)=><div className="record-field is-wide" key={key}><label htmlFor={prefix+key}>{label}</label><input ref={index===0?first:null} id={prefix+key} name={key} value={values[key]} onChange={event=>change(key,event.target.value)} disabled={busy||!canManage} autoComplete="off" aria-invalid={Boolean(errors[key])} aria-describedby={errors[key]?prefix+key+"-error":undefined} {...attributes}/>{errors[key]?<small className="record-field-error" id={prefix+key+"-error"}>{errors[key]}</small>:null}</div>)}
      </div><p className="record-editor-note">Cette adresse doit être autorisée par votre compte Google d’envoi.</p>
      <div className="admin-mail-reset"><ActionButton icon="reset" disabled={busy||!canManage} onClick={()=>{setValues({senderName:"SauverNdeko",senderEmail:"benjaminmupanzi@gmail.com"});setErrors({});setError("");setFeedback("");}}>Valeurs par défaut</ActionButton></div></section>
      <div className={"admin-mail-status "+(data.canSend?"is-ready":"")} role="status"><AppIcon name={data.canSend?"check-circle":"mail"}/><div><strong>{data.canSend?"Service d’envoi configuré":"L’envoi des e-mails reste à activer"}</strong><p>{data.canSend?"Les messages utilisent les réglages du service d’envoi.":"L’adresse expéditrice est prête. La connexion au compte Google doit être configurée."}</p>{data.updatedAt?<small>Mis à jour le {formatDate(data.updatedAt)}</small>:null}</div></div>
      {!canManage?<p className="record-editor-note">Ces réglages sont actuellement en consultation.</p>:null}
    </>:null}
  </RecordEditorFrame>;
}
