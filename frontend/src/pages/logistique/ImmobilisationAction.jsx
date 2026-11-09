import {useEffect,useId,useRef,useState} from "react";
import ActionButton from "../../components/ActionButton";
import RecordEditorFrame from "../../components/RecordEditorFrame";
import SearchSelect from "../../components/SearchSelect";
import {immobilisationsRequest} from "../../services/immobilisations";
import {validCommandeDate} from "./commandeForm";
import {createReceiptRequestId} from "./receiptForm";

export const validAssetDate=value=>/^\d{4}-\d{2}-\d{2}$/.test(value)&&validCommandeDate(value+"T00:00:00");
export const assetOptions=entries=>Object.entries(entries).map(([value,label])=>({value,label}));

export function useAssetSection(recordId,section){
 const [result,setResult]=useState(null),[loading,setLoading]=useState(true),[error,setError]=useState(""),[revision,setRevision]=useState(0);
 useEffect(()=>{
  const controller=new AbortController();
  setLoading(true);
  setError("");
  immobilisationsRequest("/"+recordId+"/"+section+"/",{signal:controller.signal}).then(response=>{
   if(controller.signal.aborted)return;
   setLoading(false);
   if(response?.success)setResult(response);
   else setError(response?.message||"Les informations n’ont pas pu être chargées.");
  });
  return()=>controller.abort();
 },[recordId,section,revision]);
 return {data:result?.data,meta:result?.meta||{},loading,error,reload:()=>setRevision(value=>value+1)};
}

export function AssetSectionStatus({section}){
 return <>{section.loading?<p className="record-editor-state" role="status">{section.data?"Actualisation…":"Chargement…"}</p>:null}
  {section.error?<div className="record-editor-error" role="alert"><span>{section.error}</span><ActionButton icon="refresh" onClick={section.reload}>Réessayer</ActionButton></div>:null}</>;
}

export function AssetActionEditor({recordId,section,title,subtitle,icon,fields,initial,validate,payload,confirmation,onClose,onSaved,onStale,submitLabel}){
 const prefix=useId(),inFlight=useRef(false),mounted=useRef(false),[values,setValues]=useState(initial),[issues,setIssues]=useState({}),[error,setError]=useState(""),[busy,setBusy]=useState(false),[pending,setPending]=useState(null),[stale,setStale]=useState(false);
 useEffect(()=>{mounted.current=true;return()=>{mounted.current=false;};},[]);
 const dirty=fields.some(field=>values[field.key]!==initial[field.key]);
 const disabled=busy||Boolean(pending)||stale;

 function change(key,value){
  const resets=fields.find(field=>field.key===key)?.reset||[];
  const cleared=Object.fromEntries(resets.map(name=>[name,""]));
  setValues(previous=>({...previous,...cleared,confirmation:false,[key]:value}));
  setIssues(previous=>({...previous,...cleared,[key]:"",confirmation:""}));
 }
 async function submit(){
  if(inFlight.current||stale)return;
  const nextIssues=pending?{}:validate(values);
  if(!pending&&confirmation&&!values.confirmation)nextIssues.confirmation="Cochez la confirmation pour continuer.";
  setIssues(nextIssues);
  if(Object.keys(nextIssues).length){setError("Vérifiez les champs signalés.");return;}
  const body=pending||{...payload(values),requestId:createReceiptRequestId()};
  inFlight.current=true;
  setBusy(true);
  setError("");
  const response=await immobilisationsRequest("/"+recordId+"/"+section+"/",{method:"POST",body});
  if(!mounted.current)return;
  inFlight.current=false;
  setBusy(false);
  if(response?.success){onSaved(response);return;}
  const unknown=!response?.status||response.status>=500;
  setPending(unknown?body:null);
  setStale(["IMMOBILISATION_VERSION_CONFLICT","PATRIMOINE_REQUEST_CONFLICT","CONTEXT_CHANGED"].includes(response?.error?.code));
  const details=response?.error?.details;
  const fieldErrors=details&&typeof details==="object"?Object.fromEntries(fields.filter(field=>typeof details[field.key]==="string").map(field=>[field.key,details[field.key]])):{};
  setIssues(fieldErrors);
  setError(unknown?"La réponse reste à confirmer. Réessayez pour vérifier la même demande.":Object.keys(fieldErrors).length?"Vérifiez les champs signalés.":response?.message||"L’enregistrement a échoué.");
 }
 return <RecordEditorFrame title={title} subtitle={subtitle} icon={icon} onClose={onClose} onSubmit={submit} busy={busy}
  canSubmit={!stale} dirty={dirty||Boolean(values.confirmation)||Boolean(pending)} error={error} onReload={stale?onStale:undefined}
  className="immobilisation-action-editor" defaultWidth={680} storageKey="sauverndeko.immobilisation.action.width"
  submitLabel={pending?"Vérifier l’enregistrement":submitLabel}>
  <section className="record-editor-section">
   <div className="record-editor-grid">
    {fields.filter(field=>!field.when||field.when(values)).map(({key,label,options,kind,wide,placeholder,help,maxLength=1000,readOnly=false})=>{
     const fieldOptions=typeof options==="function"?options(values):options;
     const fieldLabel=typeof label==="function"?label(values):label;
     const id=prefix+key, invalid=Boolean(issues[key]), common={id,disabled:disabled||readOnly,"aria-invalid":invalid,"aria-describedby":invalid?id+"-error":help?id+"-hint":undefined};
     return <div key={key} className={"record-field"+(wide?" is-wide":"")}>
      <label htmlFor={id}>{fieldLabel}</label>
      {fieldOptions?<SearchSelect id={id} label={fieldLabel} value={values[key]||""} options={fieldOptions} onChange={value=>change(key,value)} disabled={disabled||readOnly} invalid={invalid} describedBy={common["aria-describedby"]}/>:
       kind==="textarea"?<textarea {...common} value={values[key]||""} rows={3} maxLength={maxLength} onChange={event=>change(key,event.target.value)}/>:
       <input {...common} type={kind==="date"?"date":"text"} inputMode={kind==="decimal"?"decimal":kind==="integer"?"numeric":undefined} placeholder={placeholder} value={values[key]??""} maxLength={maxLength} readOnly={readOnly} onChange={event=>change(key,event.target.value)}/>}
      {help?<small id={id+"-hint"} className="record-editor-note">{help}</small>:null}
      {invalid?<small id={id+"-error"} className="record-field-error" role="alert">{issues[key]}</small>:null}
     </div>;
    })}
   </div>
   {confirmation?<div className="immobilisation-action-confirm"><label><input type="checkbox" checked={Boolean(values.confirmation)} disabled={disabled} onChange={event=>change("confirmation",event.target.checked)} aria-invalid={Boolean(issues.confirmation)}/><span>{confirmation}</span></label>{issues.confirmation?<small className="record-field-error" role="alert">{issues.confirmation}</small>:null}</div>:null}
  </section>
  {stale?<p className="record-editor-note">Le rechargement ferme le formulaire et abandonne la saisie.</p>:null}
 </RecordEditorFrame>;
}
