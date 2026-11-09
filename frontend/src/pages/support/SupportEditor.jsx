import {useEffect,useId,useRef,useState} from "react";
import {useAuth} from "../../contexts/AuthContext";
import {useEntityScope} from "../../contexts/EntityScopeContext";
import {requestJson} from "../../services/api";
import RecordEditorFrame from "../../components/RecordEditorFrame";
import ConsultationTabs from "../../components/ConsultationTabs";
import SearchSelect from "../../components/SearchSelect";
import AppIcon from "../../components/AppIcon";
import {isRetainedReference,REFERENCE_RETAINED_HINT} from "../../utils/referenceOptions";
import {SUPPORT_ROOT,SUPPORT_FIELDS,supportFieldGroups,supportInitial,supportOptions,supportValidation,supportPayload,supportUncertain} from "./supportForm";

export default function SupportEditor({record=null,context,onClose,onSaved,allowed=true}){
 const {user}=useAuth(),scope=useEntityScope(),prefix=useId(),identity=scope.scopeKey+":"+String(user?.IdUser),origin=useRef(identity),active=useRef(true),lock=useRef(false),attempt=useRef(null),operation=useRef(null);
 const creating=!record,[values,setValues]=useState(()=>({...supportInitial(record||{}),...(creating?Object.fromEntries(Object.entries(context?.defaults||{}).map(([key,value])=>[key,String(value??"")])):{})})),[tab,setTab]=useState("demande"),[errors,setErrors]=useState({}),[busy,setBusy]=useState(false),[uncertain,setUncertain]=useState(false),[error,setError]=useState("");
 const initial=useRef(JSON.stringify(values)),changed=origin.current!==identity,canWrite=!changed&&allowed&&user?.permissions?.canWriteData===true&&(creating?context?.canCreate===true:context?.canManage===true),disabled=busy||uncertain||!canWrite;
 useEffect(()=>{active.current=true;return()=>{active.current=false;operation.current?.abort();};},[]);
 function change(key,value){if(disabled)return;attempt.current=null;setValues(previous=>({...previous,[key]:value}));setErrors(previous=>({...previous,[key]:null}));}
 const groups=supportFieldGroups(context),activeTab=groups.some(group=>group.key===tab)?tab:groups[0].key;
 async function submit(){
  if(lock.current||!canWrite)return;
  if(!attempt.current){const invalid=supportValidation(values,context?.requiredFields||[]);if(Object.keys(invalid).length){setErrors(invalid);setError("Vérifiez les champs indiqués.");setTab(groups.find(group=>group.fields.includes(Object.keys(invalid)[0]))?.key||"demande");requestAnimationFrame(()=>document.getElementById(prefix+Object.keys(invalid)[0])?.focus());return;}attempt.current=JSON.stringify(supportPayload(values,record?._version,crypto.randomUUID()));}
  lock.current=true;setBusy(true);setError("");const controller=new AbortController();operation.current=controller;const response=await requestJson(SUPPORT_ROOT+"/tickets"+(record?"/"+record.ID_Support:""),{requiresAuth:true,method:record?"PATCH":"POST",body:attempt.current,signal:controller.signal});if(!active.current||controller.signal.aborted||origin.current!==identity)return;lock.current=false;setBusy(false);
  if(response?.success){onSaved(response.data?.record||response.data);return;}
  const unknown=supportUncertain(response);setUncertain(unknown);if(!unknown)attempt.current=null;setError((response?.message||"L’enregistrement n’a pas abouti.")+(unknown?" Vérifiez l’enregistrement avec la même demande.":""));
  const fields=response?.error?.details?.fields||response?.error?.details?.errors||response?.error?.details;if(fields&&typeof fields==="object"&&!Array.isArray(fields)){const errors=Object.fromEntries(Object.entries(fields).filter(([key])=>SUPPORT_FIELDS.some(field=>field.key===key)));setErrors(errors);const first=Object.keys(errors)[0];setTab(groups.find(group=>group.fields.includes(first))?.key||tab);}
 }
 function field(name){const field=SUPPORT_FIELDS.find(item=>item.key===name),options=field.source?supportOptions(context,field,{...record,...values}):[],invalid=Boolean(errors[name]);return <label className={field.type==="textarea"||name==="Objet"?"support-field is-wide":"support-field"} key={name}><span>{field.label}{field.required||context?.requiredFields?.includes(name)?" *":""}</span>{field.source?<SearchSelect id={prefix+name} label={field.label} value={values[name]} options={[{value:"",label:"Non renseigné"},...options]} disabled={disabled} invalid={invalid} onChange={value=>change(name,value)}/>:field.type==="textarea"?<textarea id={prefix+name} rows={6} value={values[name]} maxLength={field.max} aria-invalid={invalid} disabled={disabled} onChange={event=>change(name,event.target.value)}/>:<input id={prefix+name} value={values[name]} type={field.type||"text"} maxLength={field.max} aria-invalid={invalid} disabled={disabled} onChange={event=>change(name,event.target.value)}/>} {invalid?<small className="record-field-error">{String(errors[name])}</small>:field.source&&isRetainedReference(options,values[name])?<small className="record-editor-note">{REFERENCE_RETAINED_HINT}</small>:null}{name==="DateEcheance"?<small className="record-editor-note">Heure de Kinshasa.</small>:null}</label>;}
 return <RecordEditorFrame title={creating?"Nouveau dossier Support":"Modifier le dossier"} subtitle={record?.NumeroSupport||"Demande, incident ou réclamation"} icon="help" onClose={onClose} onSubmit={submit} busy={busy} dirty={!changed&&(initial.current!==JSON.stringify(values)||uncertain)} readOnly={!canWrite} canSubmit={canWrite} submitLabel={uncertain?"Vérifier l’enregistrement":"Enregistrer le dossier"} error={changed?"L’entreprise a changé. Rouvrez le formulaire dans le nouvel espace.":error} defaultWidth={1000} className="support-editor" storageKey="sauverndeko.support.editor.width" discardMessage={uncertain?"Fermer n’annule pas une éventuelle création. Vérifiez le registre avant une nouvelle saisie.":undefined}>
  <ConsultationTabs label="Rubriques du dossier" value={activeTab} onChange={setTab} tabs={groups}/>
  {groups.map(group=><section key={group.key} hidden={activeTab!==group.key} className="record-editor-section"><h3><AppIcon name={group.icon}/>{group.label}</h3>{group.key==="liens"?<p className="record-editor-note">Les objets proposés appartiennent à l’entreprise du dossier.</p>:null}<div className="record-editor-grid">{group.fields.map(field)}</div></section>)}
 </RecordEditorFrame>;
}
