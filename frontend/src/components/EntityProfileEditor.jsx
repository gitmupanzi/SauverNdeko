import useReferencesRefresh from "../hooks/useReferencesRefresh";
import {fetchFieldValues} from "../services/fieldReferences";
import {referenceOptions,retainReference} from "../utils/referenceOptions";
import {useEffect,useId,useRef,useState} from "react";
import {useAuth} from "../contexts/AuthContext";
import {useEntityScope} from "../contexts/EntityScopeContext";
import {loadEntityProfile,saveEntityProfile} from "../services/entityProfile";
import {entityProfileValues,entityProfileErrors,entityProfilePayload,entityProfileBody} from "../utils/entityProfile";
import RecordEditorFrame from "./RecordEditorFrame";
import ConsultationTabs from "./ConsultationTabs";
import ActionButton from "./ActionButton";
import EntityProfileFields from "./EntityProfileFields";
import "./EntityDocumentIdentity.css";

const flatten=value=>Array.isArray(value)?value.map(flatten).join(" "):typeof value==="string"?value:"";
const emptyLogo=()=>({file:null,remove:false});
export default function EntityProfileEditor({context="active",recordId=null,mode="view",canWrite=true,onClose,onSaved}){
  const {user}=useAuth(),scope=useEntityScope(),prefix=useId(),creating=context==="admin"&&recordId==null;
  const identity=String(user?.IdUser??"")+":"+scope.scopeKey+":"+context+":"+String(recordId??"active"),current=useRef(identity),mounted=useRef(true),saving=useRef(false),ticket=useRef(null);
  current.current=identity;
  const [record,setRecord]=useState(null),[values,setValues]=useState(()=>entityProfileValues()),[baseline,setBaseline]=useState(null),[logo,setLogo]=useState(emptyLogo),[motif,setMotif]=useState("");
  const [loading,setLoading]=useState(true),[busy,setBusy]=useState(false),[error,setError]=useState(""),[errors,setErrors]=useState({}),[editing,setEditing]=useState(creating||mode==="edit");
  const [active,setActive]=useState("identity"),[revision,setRevision]=useState(0),[uncertain,setUncertain]=useState(false),[confirmReload,setConfirmReload]=useState(false),[feedback,setFeedback]=useState("");
  const [settledIdentity,setSettledIdentity]=useState(""),settled=settledIdentity===identity;
  const globalAdmin=scope.globalAdmin===true||user?.Is_Admin===true,allowed=settled&&canWrite&&record?.canConfigure===true&&(creating?globalAdmin&&record?.IdEntite==null:context==="admin"||scope.canWrite);
  const manageStructure=context==="admin"&&globalAdmin&&canWrite&&(creating||record?.canManageEntity!==false);
  const changed=Boolean(baseline)&&(JSON.stringify(values)!==JSON.stringify(baseline)||Boolean(logo.file)||logo.remove),readOnly=!editing||!allowed,disabled=loading||busy||uncertain;
  const typeOptions=referenceOptions(record?.references?.entityTypes||[]);
  if(values.IdTypeEntiteFk&&!typeOptions.some(item=>item.value===values.IdTypeEntiteFk))typeOptions.unshift({value:values.IdTypeEntiteFk,label:record?.TypeEntite||"Type actuel",disabled:true,incompatible:true});
  useReferencesRefresh(async()=>{if(!settled||disabled||!manageStructure)return;const expected=identity,response=await fetchFieldValues("systeme","T_Entite","IdTypeEntiteFk",{currentId:values.IdTypeEntiteFk});if(current.current===expected&&response?.success)setRecord(previous=>({...previous,references:{...previous.references,entityTypes:response.data?.options||[]}}));},{enabled:settled&&manageStructure});
  useEffect(()=>{mounted.current=true;return()=>{mounted.current=false;};},[]);
  useEffect(()=>{
    const controller=new AbortController(),key=identity;setRecord(null);setBaseline(null);setValues(entityProfileValues());setLogo(emptyLogo());setMotif("");setLoading(true);setBusy(false);setError("");setErrors({});setUncertain(false);setConfirmReload(false);setFeedback("");setActive("identity");setEditing(creating||mode==="edit");saving.current=false;ticket.current=null;
    async function load(){
      const result=await loadEntityProfile(context,recordId,controller.signal);
      if(controller.signal.aborted||current.current!==key)return;
      setLoading(false);setSettledIdentity(key);
      if(!result?.success||!result.data){setError(result?.message||"Le profil de l’entreprise n’a pas pu être chargé.");return;}
      const expected=context==="admin"?recordId:scope.entityId;
      if(!creating&&expected&&String(expected)!==String(result.data.IdEntite)){setError("L’entreprise reçue ne correspond pas à la fiche choisie. Rechargez-la.");return;}
      const next=entityProfileValues(result.data);setRecord(result.data);setValues(next);setBaseline(next);
    }
    void load();return()=>controller.abort();
  },[identity,mode,revision]);
  function change(name,value){if(disabled||readOnly||saving.current)return;setValues(previous=>({...previous,[name]:value}));setErrors(previous=>({...previous,[name]:""}));setFeedback("");}
  function changeLogo(value){if(disabled||readOnly||saving.current)return;setLogo(value);setErrors(previous=>({...previous,logo:"",logoAction:""}));setFeedback("");}
  function begin(){if(!allowed||busy)return;setEditing(true);setErrors({});setError("");setFeedback("");setMotif("");ticket.current=null;}
  function focusIssue(issues){const name=Object.keys(issues)[0];if(name!=="motif")setActive(name==="IdentifiantsLegauxEntite"?"legal":["MentionDocumentaireEntite","AfficherEnteteDocument","AfficherPiedDocument","logo","logoAction"].includes(name)?"documents":"identity");requestAnimationFrame(()=>document.getElementById(prefix+name)?.focus());}
  function reload(){if(busy)return;if(editing&&(changed||motif.trim()||uncertain))setConfirmReload(true);else setRevision(value=>value+1);}
  async function submit(){
    if(!allowed||!editing||loading||saving.current||!baseline||!creating&&!changed&&!uncertain)return;
    let snapshot=ticket.current;
    if(!uncertain){
      const issues=entityProfileErrors(values,motif,{manageStructure});setErrors(issues);setError("");
      if(!creating&&!record?._version){setError("Rechargez l’entreprise avant de l’enregistrer.");return;}
      if(Object.keys(issues).length){setError("Vérifiez les informations indiquées.");focusIssue(issues);return;}
      const payload=entityProfilePayload(values,{record:creating?null:record,motif,requestId:"",logo,manageStructure}),fingerprint=JSON.stringify(payload);
      if(!snapshot||snapshot.fingerprint!==fingerprint||snapshot.file!==logo.file){payload.requestId=crypto.randomUUID();snapshot={fingerprint,file:logo.file,body:entityProfileBody(payload,logo.file)};ticket.current=snapshot;}
    }
    if(!snapshot)return;
    const key=identity;saving.current=true;setBusy(true);setError("");setConfirmReload(false);
    const result=await saveEntityProfile(context,recordId,snapshot.body);
    if(!mounted.current||current.current!==key)return;
    saving.current=false;setBusy(false);
    if(!result?.success||!result.data){
      setUncertain(!result?.status||result.status>=500||result.success===true);const details=result?.error?.details;
      const issues=details&&typeof details==="object"&&!Array.isArray(details)?Object.fromEntries(Object.entries(details).map(([name,value])=>[name,flatten(value)])):{};
      setErrors(issues);setError(result?.message||"L’entreprise n’a pas pu être enregistrée.");if(Object.keys(issues).length)focusIssue(issues);return;
    }
    const expected=context==="admin"?recordId:scope.entityId;
    if(!creating&&expected&&String(expected)!==String(result.data.IdEntite)){setUncertain(true);setError("La réponse reçue ne correspond pas à cette entreprise. Vérifiez l’enregistrement ou rechargez la fiche.");return;}
    const next=entityProfileValues(result.data);setRecord(result.data);setValues(next);setBaseline(next);setLogo(emptyLogo());setMotif("");setEditing(false);setUncertain(false);ticket.current=null;setFeedback("Profil de l’entreprise enregistré.");onSaved?.(result.data,{type:"entities",mode:creating?"create":"edit"});
  }
  const tabs=[{key:"identity",label:"Coordonnées",icon:"apps"},{key:"legal",label:"Identifiants légaux",icon:"list"},{key:"documents",label:"Documents",icon:"document"}].map(tab=>({...tab,disabled:busy}));
  return <RecordEditorFrame title={creating?"Nouvelle entreprise":editing&&allowed?"Modifier l’entreprise":"Identité de l’entreprise"} subtitle={settled?(record?.NomEntite||values.NomEntite||"Profil de l’entreprise"):"Profil de l’entreprise"} icon="apps" defaultWidth={900} storageKey="sauverndeko.entity-profile.width" className="entity-profile-editor" onClose={onClose} onSubmit={submit} busy={busy} loading={loading||!settled} readOnly={readOnly} dirty={settled&&!readOnly&&(changed||Boolean(motif.trim())||uncertain)} canSubmit={allowed&&(creating||changed||uncertain)&&!loading} submitLabel={uncertain?"Vérifier l’enregistrement":"Enregistrer"} error={settled?error:""} onReload={reload}>
    {settled&&confirmReload?<div className="record-discard" role="alert"><span>Recharger la fiche et abandonner les modifications ?</span><div><ActionButton onClick={()=>setConfirmReload(false)}>Continuer la saisie</ActionButton><ActionButton onClick={()=>setRevision(value=>value+1)}>Recharger</ActionButton></div></div>:null}
    {settled&&!loading&&baseline?<div className="entity-document-identity">
      {feedback?<p className="entity-document-feedback" role="status">{feedback}</p>:null}
      <div className="entity-document-section-head"><p className="record-editor-note">Coordonnées, identité légale et présentation des documents.</p>{allowed&&!editing?<ActionButton icon="edit" onClick={begin}>Modifier</ActionButton>:null}</div>
      {creating&&!globalAdmin?<p className="record-editor-error" role="alert">La création d’une entreprise est réservée à l’administration de la plateforme.</p>:null}
      <ConsultationTabs tabs={tabs} value={active} onChange={setActive} label="Profil de l’entreprise" idPrefix={prefix}/>
      <section role="tabpanel" id={prefix+"-panel-"+active} aria-labelledby={prefix+"-tab-"+active}>
        <EntityProfileFields active={active} prefix={prefix} values={values} record={record} change={change} logo={logo} onLogoChange={changeLogo} errors={errors} disabled={disabled} readOnly={readOnly} manageStructure={manageStructure} typeOptions={typeOptions} contextKey={identity}/>
      </section>
      {!readOnly?<section className="record-editor-section"><div className="record-field"><label htmlFor={prefix+"motif"}>Motif de la modification *</label><textarea id={prefix+"motif"} required rows={2} maxLength={1000} value={motif} disabled={disabled} onChange={event=>{setMotif(event.target.value);setErrors(previous=>({...previous,motif:""}));}} aria-invalid={Boolean(errors.motif)} aria-describedby={prefix+"motif-help"+(errors.motif?" "+prefix+"motif-error":"")}/><small id={prefix+"motif-help"}>Indiquez la raison du changement pour l’historique.</small>{errors.motif?<small id={prefix+"motif-error"} className="record-field-error" role="alert">{errors.motif}</small>:null}</div>{uncertain?<p className="record-editor-note" role="status">La réponse reste à confirmer. Réessayez pour vérifier la même demande ou rechargez la fiche.</p>:null}</section>:null}
    </div>:null}
  </RecordEditorFrame>;
}
