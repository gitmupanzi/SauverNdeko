import {useEffect,useId,useRef,useState} from "react";
import {useAuth} from "../../contexts/AuthContext";
import {useEntityScope} from "../../contexts/EntityScopeContext";
import {requestJson} from "../../services/api";
import RecordEditorFrame from "../../components/RecordEditorFrame";
import ActionButton from "../../components/ActionButton";
import ConsultationTabs from "../../components/ConsultationTabs";
import SearchSelect from "../../components/SearchSelect";
import {SUPPORT_ROOT,SUPPORT_FIELDS,supportFieldGroups,supportOptions,supportUncertain} from "./supportForm";
import {SUPPORT_BATCH_MAX,supportExcelRows,supportBatchValidation,supportBatchPayload,supportBatchDateValid} from "./supportBatch";

export default function SupportBatchEditor({context,onClose,onSaved}){
 const {user}=useAuth(),scope=useEntityScope(),prefix=useId(),identity=scope.scopeKey+":"+String(user?.IdUser),origin=useRef(identity),active=useRef(true),lock=useRef(false),operation=useRef(null),attempt=useRef(null),contextIdentity=useRef(identity);
 contextIdentity.current=identity;
 const [rows,setRows]=useState([]),[selected,setSelected]=useState(""),[tab,setTab]=useState("demande"),[errors,setErrors]=useState({}),[error,setError]=useState(""),[busy,setBusy]=useState(false),[uncertain,setUncertain]=useState(false),[fileName,setFileName]=useState("");
 const groups=supportFieldGroups(context),activeTab=groups.some(group=>group.key===tab)?tab:groups[0].key;
 const changed=origin.current!==identity,canWrite=!changed&&context?.canCreate===true&&user?.permissions?.canWriteData===true,disabled=busy||uncertain||!canWrite,row=rows.find(item=>item.clientRowId===selected)||rows[0],shownRows=changed?[]:rows;
 const writable=useRef(canWrite);writable.current=canWrite;
 useEffect(()=>{active.current=true;return()=>{active.current=false;operation.current?.abort();};},[]);
 useEffect(()=>{if(changed){operation.current?.abort();setRows([]);setErrors({});setFileName("");setBusy(false);}},[identity]);
 function edit(key,value){if(disabled||!row)return;attempt.current=null;setRows(previous=>previous.map(item=>item.clientRowId===row.clientRowId?{...item,data:{...item.data,[key]:value}}:item));setErrors(previous=>({...previous,[row.clientRowId]:{...previous[row.clientRowId],[key]:null}}));}
 async function importFile(event){
  const file=event.target.files?.[0];event.target.value="";if(!file||disabled||lock.current)return;
  if(!/\.xlsx$/i.test(file.name)||file.size>4*1024*1024){setError("Choisissez un fichier Excel .xlsx de 4 Mo maximum.");return;}
  lock.current=true;setBusy(true);setError("");const controller=new AbortController();operation.current=controller;const body=new FormData();body.append("fichier",file);
  const response=await requestJson(SUPPORT_ROOT+"/tickets/import-excel",{requiresAuth:true,method:"POST",body,signal:controller.signal});
  if(!active.current||controller.signal.aborted||origin.current!==contextIdentity.current)return;
  lock.current=false;setBusy(false);
  if(!writable.current)return;
  if(!response?.success){setError(response?.message||"Le fichier n’a pas pu être lu.");return;}
  try{const imported=supportExcelRows(response.data?.matrix,context);if(rows.length+imported.length>SUPPORT_BATCH_MAX)throw new Error("Le panier est limité à 100 dossiers.");setRows(previous=>[...previous,...imported]);setSelected(imported[0].clientRowId);setFileName(file.name);setErrors(previous=>({...previous,...supportBatchValidation(imported,context)}));attempt.current=null;}catch(reason){setError(reason.message);}
 }
 async function submit(){
  if(lock.current||!canWrite||!rows.length)return;
  if(!attempt.current){const invalid=supportBatchValidation(rows,context);if(Object.keys(invalid).length){setErrors(invalid);const first=Object.keys(invalid)[0],key=Object.keys(invalid[first])[0];setSelected(first);setTab(groups.find(group=>group.fields.includes(key))?.key||"demande");setError("Corrigez les dossiers indiqués avant d’enregistrer le panier.");requestAnimationFrame(()=>document.getElementById(prefix+key)?.focus());return;}attempt.current=JSON.stringify(supportBatchPayload(rows,crypto.randomUUID()));}
  lock.current=true;setBusy(true);setError("");const controller=new AbortController();operation.current=controller;
  const response=await requestJson(SUPPORT_ROOT+"/tickets/batch",{requiresAuth:true,method:"POST",body:attempt.current,signal:controller.signal});
  if(!active.current||controller.signal.aborted||origin.current!==contextIdentity.current)return;
  lock.current=false;setBusy(false);if(response?.success){onSaved(response.data);return;}
  const unknown=supportUncertain(response);setUncertain(unknown);if(!unknown)attempt.current=null;
  setError((response?.message&&response.message!=="Requête refusée."?response.message:"Le panier n’a pas pu être enregistré.")+(unknown?" Vérifiez l’enregistrement avec la même demande.":" Corrigez les dossiers indiqués ; le panier est conservé."));
  const issues=response?.error?.details?.rows;if(issues&&typeof issues==="object"){setErrors(issues);const first=Object.keys(issues)[0],key=Object.keys(issues[first]||{})[0];if(first){setSelected(first);setTab(groups.find(group=>group.fields.includes(key))?.key||"demande");}}
 }
 function remove(id){if(disabled)return;attempt.current=null;setRows(previous=>previous.filter(item=>item.clientRowId!==id));setErrors(previous=>{const next={...previous};delete next[id];return next;});}
 function field(name){const field=SUPPORT_FIELDS.find(item=>item.key===name),value=row.data[name],message=errors[row.clientRowId]?.[name],invalid=Boolean(message),id=prefix+name,choices=field.source?supportOptions(context,field):[],unknown=field.source&&value&&!choices.some(option=>String(option.value)===String(value)),badDate=name==="DateEcheance"&&value&&!supportBatchDateValid(value);return <label key={name} className={field.type==="textarea"||name==="Objet"?"support-field is-wide":"support-field"}><span>{field.label}{field.required||context?.requiredFields?.includes(name)?" *":""}</span>{field.source?<SearchSelect id={id} label={field.label} value={value} options={[{value:"",label:"Non renseigné"},...choices,...(unknown?[{value,label:"Valeur à vérifier : "+value,disabled:true}]:[])]} disabled={disabled} invalid={invalid} onChange={value=>edit(name,value)}/>:field.type==="textarea"?<textarea id={id} rows={6} value={value} maxLength={field.max} disabled={disabled} aria-invalid={invalid} onChange={event=>edit(name,event.target.value)}/>:<input id={id} type={badDate?"text":field.type||"text"} value={value} maxLength={field.max} disabled={disabled} aria-invalid={invalid} onChange={event=>edit(name,event.target.value)}/>} {message?<small className="record-field-error">{String(message)}</small>:null}{badDate?<small className="record-field-error">Date à vérifier : {value}. Utilisez AAAA-MM-JJTHH:MM.</small>:name==="DateEcheance"?<small className="record-editor-note">Heure de Kinshasa.</small>:null}</label>;}
 return <RecordEditorFrame title="Importer des dossiers Support" subtitle="Vérifiez et corrigez le panier avant son enregistrement." icon="help" onClose={onClose} onSubmit={submit} busy={busy} dirty={!changed&&Boolean(rows.length||uncertain)} readOnly={!canWrite} canSubmit={canWrite&&rows.length>0} submitLabel={uncertain?"Vérifier l’enregistrement":"Enregistrer le panier ("+rows.length+")"} error={changed?"L’entreprise a changé. Rouvrez le panier dans le nouvel espace.":error} defaultWidth={1180} className="support-editor support-batch-editor" storageKey="sauverndeko.support.batch.width" discardMessage={uncertain?"Fermer n’annule pas un éventuel enregistrement. Vérifiez le registre avant une nouvelle saisie.":undefined}>
  <section className="record-editor-section"><label className="support-field"><span>Fichier Excel .xlsx · 4 Mo maximum · 100 dossiers</span><input type="file" accept=".xlsx,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" disabled={disabled} onChange={importFile}/></label>{fileName?<p className="record-editor-note">{fileName} · {shownRows.length} dossiers dans le panier. Un autre fichier ajoute ses lignes.</p>:<p className="record-editor-note">Choisissez le modèle rempli pour préparer les dossiers.</p>}</section>
  {shownRows.length?<div className="support-batch-layout"><nav className="support-batch-rows" aria-label="Dossiers du panier">{shownRows.map((item,index)=><div className="support-batch-row" key={item.clientRowId}><button type="button" aria-current={item.clientRowId===row?.clientRowId?"true":undefined} onClick={()=>setSelected(item.clientRowId)}><strong>{index+1}. {item.data.Objet||"Objet à compléter"}</strong><small>{Object.values(errors[item.clientRowId]||{}).some(Boolean)?"À corriger":"Dossier à vérifier"}</small></button><ActionButton icon="close" aria-label={"Retirer le dossier "+(index+1)} disabled={disabled} onClick={()=>remove(item.clientRowId)}/></div>)}</nav><div className="support-batch-fields"><h3>Dossier {shownRows.indexOf(row)+1}</h3>{errors[row.clientRowId]?._line?<p className="record-field-error" role="alert">{String(errors[row.clientRowId]._line)}</p>:null}<ConsultationTabs label="Rubriques du dossier importé" value={activeTab} onChange={setTab} tabs={groups}/>{groups.map(group=><section key={group.key} hidden={activeTab!==group.key} className="record-editor-section"><h3>{group.label}</h3><div className="record-editor-grid">{group.fields.map(field)}</div></section>)}</div></div>:null}
 </RecordEditorFrame>;
}
