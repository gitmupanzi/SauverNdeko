import {useEffect,useId,useRef,useState} from "react";
import {useAuth} from "../../contexts/AuthContext";
import {useEntityScope} from "../../contexts/EntityScopeContext";
import {requestJson} from "../../services/api";
import RecordEditorFrame from "../../components/RecordEditorFrame";
import ConsultationTabs from "../../components/ConsultationTabs";
import SearchSelect from "../../components/SearchSelect";
import AppIcon from "../../components/AppIcon";
import {isRetainedReference,REFERENCE_RETAINED_HINT} from "../../utils/referenceOptions";
import {SUPPORT_ROOT,SUPPORT_FIELDS,SUPPORT_DETAIL_DRAWER,SUPPORT_EDIT_MODES,supportFieldGroups,supportInitial,supportOptions,supportValidation,supportPayload,supportUncertain} from "./supportForm";

export function useSupportEditor({record=null,context,mode,onSaved,allowed=true}){
 const {user}=useAuth(),scope=useEntityScope(),prefix=useId(),identity=scope.scopeKey+":"+String(user?.IdUser),origin=useRef(identity),active=useRef(true),lock=useRef(false),attempt=useRef(null),operation=useRef(null);
 const creating=mode==="create",editing=Boolean(mode&&record);
 const [draft,setDraft]=useState(null),[tab,setTab]=useState("demande"),[errors,setErrors]=useState({}),[busy,setBusy]=useState(false),[uncertain,setUncertain]=useState(false),[error,setError]=useState(""),[modelNotice,setModelNotice]=useState("");
 const initial={...supportInitial(record||{}),...(creating?Object.fromEntries(Object.entries(context?.defaults||{}).map(([key,value])=>[key,String(value??"")])):{})};
 const values=draft||initial,changed=origin.current!==identity,canWrite=!changed&&allowed&&user?.permissions?.canWriteData===true&&(creating?context?.canCreate===true:editing&&context?.canManage===true),disabled=busy||uncertain||!canWrite;
 const groups=supportFieldGroups(context,mode),activeTab=groups.some(group=>group.key===tab)?tab:groups[0]?.key;
 const fields=SUPPORT_FIELDS.filter(field=>groups.some(group=>group.fields.includes(field.key)));
 const changedFields=fields.filter(field=>values[field.key]!==initial[field.key]);
 const dirty=!changed&&(uncertain||changedFields.length>0||(creating&&Boolean(values.modelId)));
 const firstField=groups[0]?.fields[0];
 useEffect(()=>{active.current=true;return()=>{active.current=false;operation.current?.abort();};},[]);
 useEffect(()=>{
  if(!editing||!canWrite)return;
  const frame=requestAnimationFrame(()=>{
   const field=document.getElementById(prefix+firstField);
   const body=field?.closest?.(".record-editor-body");
   if(body)body.scrollTop=0;
   field?.focus({preventScroll:true});
  });
  return()=>cancelAnimationFrame(frame);
 },[editing,mode,canWrite,prefix,firstField]);
 function reset(){
  attempt.current=null;setDraft(null);setTab("demande");setErrors({});setError("");setUncertain(false);setModelNotice("");
 }
 function change(key,value){if(disabled)return;attempt.current=null;setDraft(previous=>({...((previous||initial)),[key]:value}));setErrors(previous=>({...previous,[key]:null}));}
 const canChooseModel=creating&&context?.canStartJourneyOnCreate===true;
 const journeyModels=context?.journeyModels||[];
 const modelsForType=typeId=>journeyModels.filter(model=>typeId&&String(model.typeId)===typeId);
 const availableModels=modelsForType(values.ID_TypeSupportFk);
 const selectedModel=availableModels.find(model=>String(model.id)===values.modelId);

 function changeType(typeId){
  change("ID_TypeSupportFk",typeId);
  if(values.modelId&&!modelsForType(typeId).some(model=>String(model.id)===values.modelId)){
   change("modelId","");
   setModelNotice("Le modèle sélectionné a été retiré après le changement de type.");
  }else{
   setModelNotice("");
  }
 }

 function showErrors(fieldErrors){
  setErrors(fieldErrors);
  const first=Object.keys(fieldErrors)[0];
  if(!first)return;
  setTab(groups.find(group=>group.fields.includes(first))?.key||"demande");
  requestAnimationFrame(()=>document.getElementById(prefix+first)?.focus());
 }
 async function submit(){
  if(lock.current||!canWrite)return;
  if(!attempt.current){
   if(editing&&!changedFields.length)return;
   const invalid=supportValidation(values,context?.requiredFields||[],creating?fields:changedFields);
   if(canChooseModel&&values.modelId&&!selectedModel){
    invalid.modelId="Ce modèle n’est plus disponible pour ce type de dossier.";
   }
   if(Object.keys(invalid).length){
    showErrors(invalid);
    setError("Vérifiez les champs indiqués.");
    return;
   }
   const payload=supportPayload(values,record?._version,crypto.randomUUID(),creating?fields:changedFields);
   if(canChooseModel&&selectedModel)payload.modelId=selectedModel.id;
   attempt.current=JSON.stringify(payload);
  }
  lock.current=true;setBusy(true);setError("");const controller=new AbortController();operation.current=controller;const response=await requestJson(SUPPORT_ROOT+"/tickets"+(record?"/"+record.ID_Support:""),{requiresAuth:true,method:record?"PATCH":"POST",body:attempt.current,signal:controller.signal});if(!active.current||controller.signal.aborted||origin.current!==identity)return;lock.current=false;setBusy(false);
  if(response?.success){
   onSaved(response.data?.record||response.data,{startedJourney:Boolean(JSON.parse(attempt.current).modelId)});
   return;
  }
  const unknown=supportUncertain(response);setUncertain(unknown);if(!unknown)attempt.current=null;setError((response?.message||"L’enregistrement n’a pas abouti.")+(unknown?" Vérifiez l’enregistrement avec la même demande.":""));
  const serverFields=response?.error?.details?.fields||response?.error?.details?.errors||response?.error?.details;if(serverFields&&typeof serverFields==="object"&&!Array.isArray(serverFields)){
   showErrors(Object.fromEntries(Object.entries(serverFields).filter(([key])=>
    (canChooseModel&&key==="modelId")||fields.some(field=>field.key===key))));
  }
 }
 function field(name){const field=SUPPORT_FIELDS.find(item=>item.key===name),options=field.source?supportOptions(context,field,{...record,...values}):[],invalid=Boolean(errors[name]);return <label className={field.type==="textarea"||name==="Objet"?"support-field is-wide":"support-field"} key={name}><span>{field.label}{field.required||context?.requiredFields?.includes(name)?" *":""}</span>{field.source?<SearchSelect id={prefix+name} label={field.label} value={values[name]} options={[{value:"",label:"Non renseigné"},...options]} disabled={disabled} invalid={invalid} onChange={value=>name==="ID_TypeSupportFk"?changeType(value):change(name,value)}/>:field.type==="textarea"?<textarea id={prefix+name} rows={6} value={values[name]} maxLength={field.max} aria-invalid={invalid} disabled={disabled} onChange={event=>change(name,event.target.value)}/>:<input id={prefix+name} value={values[name]} type={field.type||"text"} maxLength={field.max} aria-invalid={invalid} disabled={disabled} onChange={event=>change(name,event.target.value)}/>} {invalid?<small className="record-field-error">{String(errors[name])}</small>:field.source&&isRetainedReference(options,values[name])?<small className="record-editor-note">{REFERENCE_RETAINED_HINT}</small>:null}{name==="DateEcheance"?<small className="record-editor-note">Heure de Kinshasa.</small>:null}</label>;}
 function journeyField(){
  const id=prefix+"modelId",modelError=errors.modelId;
  let hint="Choisissez d’abord le type du dossier.";
  if(values.ID_TypeSupportFk)hint=availableModels.length
   ?"La première étape démarre à l’enregistrement si vous choisissez un modèle."
   :"Aucun modèle actif pour ce type. Vous pouvez enregistrer le dossier.";
  const options=[{value:"",label:"Sans modèle de suivi"},...availableModels.map(model=>({
   value:String(model.id),label:model.name,
  }))];
  if(values.modelId&&!selectedModel)options.push({value:values.modelId,label:"Modèle indisponible",disabled:true});
  return <label className="support-field is-wide" htmlFor={id}>
   <span>Modèle de suivi</span>
   <SearchSelect id={id} label="Modèle de suivi" value={values.modelId||""} options={options}
    disabled={disabled||(!availableModels.length&&!values.modelId)} invalid={Boolean(modelError)}
    describedBy={id+"-hint"} onChange={value=>{change("modelId",value);setModelNotice("");}}/>
   <small id={id+"-hint"} className={modelError?"record-field-error":"record-editor-note"} aria-live="polite">
    {modelError||modelNotice||(selectedModel?.stageCount
     ?selectedModel.stageCount+(selectedModel.stageCount===1?" étape":" étapes")+" · "+hint:hint)}
   </small>
  </label>;
 }

 const content=mode?<>
  {groups.length>1?<ConsultationTabs label="Rubriques du dossier" value={activeTab} onChange={setTab} tabs={groups}/>:null}
  {groups.map(group=><section key={group.key} hidden={activeTab!==group.key} className="record-editor-section"><h3><AppIcon name={group.icon}/>{group.label}</h3>{group.key==="liens"?<p className="record-editor-note">Les objets proposés appartiennent à l’entreprise du dossier.</p>:null}<div className="record-editor-grid">{group.fields.map(field)}{group.key==="demande"&&canChooseModel?journeyField():null}</div></section>)}
 </>:null;
 const frameProps={
  title:creating?"Nouveau dossier Support":SUPPORT_EDIT_MODES[mode]?.label,
  subtitle:record?.NumeroSupport||"Demande, incident ou réclamation",
  icon:SUPPORT_EDIT_MODES[mode]?.icon||"help",
  onSubmit:submit,busy,dirty,readOnly:!canWrite,canSubmit:canWrite&&(creating||dirty),
  submitLabel:uncertain?"Vérifier l’enregistrement":mode==="suivi"?"Enregistrer le suivi":"Enregistrer le dossier",
  error:changed?"L’entreprise a changé. Rouvrez le formulaire dans le nouvel espace.":error,
  discardMessage:uncertain?"Fermer n’annule pas un éventuel enregistrement. Vérifiez le registre.":undefined,
 };
 return {content,frameProps,reset};
}

export default function SupportEditor({record=null,context,onClose,onSaved,allowed=true}){
 const editor=useSupportEditor({record,context,mode:record?"ticket":"create",onSaved,allowed});
 return <RecordEditorFrame {...editor.frameProps} onClose={onClose}
  {...(record?SUPPORT_DETAIL_DRAWER:{defaultWidth:1000,storageKey:"sauverndeko.support.editor.width"})}
  className="support-editor">{editor.content}</RecordEditorFrame>;
}
