import {useEffect,useId,useRef,useState} from "react";
import {useEntityScope} from "../../contexts/EntityScopeContext";
import RecordEditorFrame from "../../components/RecordEditorFrame";
import SearchSelect from "../../components/SearchSelect";
import ConsultationTabs from "../../components/ConsultationTabs";
import AppIcon from "../../components/AppIcon";
import ActionButton from "../../components/ActionButton";
import {tiersRequest,tiersRecord,tiersChanged,optionalOptions} from "../../services/tiers";
import {createReceiptRequestId} from "./receiptForm";
import "./Tiers.css";
const FIELDS=["Nom","Nature","ID_TypeClientFk","Email","Telephone","Adresse","IdUserFk","IdProfessionnelFk","IdEntiteRepresenteeFk","ObsClient"];
const REFERENCES=["ID_TypeClientFk","IdUserFk","IdProfessionnelFk","IdEntiteRepresenteeFk"];
export function tiersForm(record,defaultTypeId=""){return Object.fromEntries([...FIELDS.map(key=>[key,record?.[key]==null?(key==="Nature"?"personne":key==="ID_TypeClientFk"?String(defaultTypeId||""):""):String(record[key])]),["Actif",record?.Actif!==false]]);}
export function tiersFormErrors(values,references={}){
  const errors={};if(!values.Nom.trim())errors.Nom="Renseignez le nom du tiers.";if(values.Nom.length>255)errors.Nom="Limitez le nom à 255 caractères.";
  if(!["personne","entreprise"].includes(values.Nature))errors.Nature="Choisissez la nature du tiers.";
  if(!values.ID_TypeClientFk)errors.ID_TypeClientFk="Choisissez le type de client.";
  if(values.Email.trim()&&!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(values.Email.trim()))errors.Email="Renseignez une adresse e-mail valide.";
  for(const key of REFERENCES)if(values[key]&&!/^[1-9]\d*$/.test(values[key]))errors[key]="Choisissez une valeur de la liste.";
  const professional=(references.professionnels||[]).find(item=>String(item.id)===values.IdProfessionnelFk);
  if(professional&&values.IdUserFk&&String(professional.userId)!==values.IdUserFk)errors.IdProfessionnelFk="Ce professionnel est associé à un autre compte.";
  return errors;
}
export function tiersPayload(values,original,revision){const payload={};for(const key of [...FIELDS,"Actif"]){if(original&&values[key]===original[key])continue;payload[key]=key==="Actif"?values[key]:values[key].trim()||null;}if(original)payload._version=revision;return payload;}
export default function TiersEditor({tiersId=null,onClose,onSaved}){
  const scope=useEntityScope(),prefix=useId(),mounted=useRef(false),saving=useRef(false),createRequest=useRef(null);
  const [values,setValues]=useState(()=>tiersForm(null)),[initial,setInitial]=useState(null),[record,setRecord]=useState(null),[meta,setMeta]=useState(null),[references,setReferences]=useState({});
  const [active,setActive]=useState("identite"),[loading,setLoading]=useState(true),[busy,setBusy]=useState(false),[error,setError]=useState(""),[errors,setErrors]=useState({}),[reload,setReload]=useState(0),[uncertain,setUncertain]=useState(false),[confirmReload,setConfirmReload]=useState(false);
  const dirty=initial&&JSON.stringify(initial)!==JSON.stringify(values),editable=scope.canWrite&&meta?.canEdit!==false;
  useEffect(()=>{mounted.current=true;return()=>{mounted.current=false;};},[]);
  useEffect(()=>{let alive=true;setLoading(true);setError("");Promise.all([tiersRequest("/references"),tiersId?tiersRequest("/"+tiersId):Promise.resolve({success:true,data:null,meta:{}})]).then(([refs,response])=>{
    if(!alive)return;setLoading(false);if(!refs?.success||!response?.success){setError(refs?.success?response?.message:refs?.message||"La fiche n’a pas pu être chargée.");return;}
    const row=tiersId?tiersRecord(response):null,form=tiersForm(row,refs.data?.defaultTypeClientId);setReferences(refs.data||{});setRecord(row);setMeta(response.meta||{});setValues(form);setInitial(form);setErrors({});setConfirmReload(false);setUncertain(false);createRequest.current=null;
  });return()=>{alive=false;};},[tiersId,reload,scope.scopeKey]);
  function change(name,value){setValues(current=>({...current,[name]:value}));setErrors(current=>({...current,[name]:""}));}
  function focusIssue(issues){const key=Object.keys(issues)[0];setActive(REFERENCES.includes(key)&&key!=="ID_TypeClientFk"?"liens":"identite");requestAnimationFrame(()=>document.getElementById(prefix+key)?.focus());}
  async function submit(){if(saving.current||!editable||!initial||(tiersId&&!meta?.revision))return;const invalid=tiersFormErrors(values,references);setErrors(invalid);setError("");if(Object.keys(invalid).length){focusIssue(invalid);return;}saving.current=true;setBusy(true);
    if(!tiersId&&!createRequest.current)createRequest.current={...tiersPayload(values,null),requestId:createReceiptRequestId()};
    const response=await tiersRequest(tiersId?"/"+tiersId:"",{method:tiersId?"PATCH":"POST",body:tiersId?tiersPayload(values,initial,meta?.revision):createRequest.current});if(!mounted.current)return;saving.current=false;setBusy(false);
    if(!response?.success||!tiersRecord(response)?.ID_Client){
      if(!tiersId&&(!response?.status||response.status>=500||response.success===true)){setUncertain(true);setError("La réponse n’est pas parvenue. Réessayez pour vérifier l’enregistrement.");return;}
      setUncertain(false);createRequest.current=null;const details=response?.error?.details;const issues=details&&typeof details==="object"&&!Array.isArray(details)?Object.fromEntries(Object.entries(details).filter(([key])=>key in values).map(([key,value])=>[key,String(value)])):{};setErrors(issues);setError(Object.keys(issues).length?"Vérifiez les champs indiqués.":response?.message||"La fiche n’a pas pu être enregistrée.");if(Object.keys(issues).length)focusIssue(issues);return;}
    tiersChanged();onSaved(tiersRecord(response));
  }
  function field(name,label,control){const id=prefix+name;return <div className="record-field" key={name}><label htmlFor={id}>{label}</label>{control(id)}{errors[name]?<small className="record-field-error" id={id+"-error"}>{errors[name]}</small>:null}</div>;}
  function input(name,label,props={}){return field(name,label,id=><input id={id} value={values[name]} onChange={event=>change(name,event.target.value)} disabled={busy||uncertain||!editable} aria-invalid={Boolean(errors[name])} aria-describedby={errors[name]?id+"-error":undefined} {...props}/>);}
  function select(name,label,options){const current=values[name];const choices=[...options];if(current&&!choices.some(item=>String(item.value)===current))choices.push({value:current,label:record?.[{ID_TypeClientFk:"TypeClient",IdUserFk:"NomUtilisateur",IdProfessionnelFk:"NomProfessionnel",IdEntiteRepresenteeFk:"NomEntiteRepresentee"}[name]]||"Valeur actuelle"});return field(name,label,id=><SearchSelect id={id} label={label} value={current} options={choices} onChange={value=>change(name,value)} disabled={busy||uncertain||!editable} invalid={Boolean(errors[name])}/>);}
  return <RecordEditorFrame title={tiersId?"Modifier le tiers":"Nouveau tiers"} subtitle={record?.Nom||"Identité et coordonnées"} icon="user" defaultWidth={850} onClose={onClose} onSubmit={submit} loading={loading} busy={busy} dirty={Boolean(dirty)} canSubmit={editable&&Boolean(initial)&&(!tiersId||Boolean(meta?.revision))&&(!tiersId||Boolean(dirty))} error={error} onReload={!uncertain&&(!initial||error)?()=>dirty?setConfirmReload(true):setReload(x=>x+1):null} submitLabel={uncertain?"Vérifier l’enregistrement":"Enregistrer"} storageKey="sauverndeko.tiers.editor.width">
    {confirmReload?<div className="record-editor-error" role="alert"><span>Recharger la fiche et abandonner les modifications ?</span><ActionButton onClick={()=>setConfirmReload(false)}>Continuer la saisie</ActionButton><ActionButton onClick={()=>setReload(x=>x+1)}>Recharger</ActionButton></div>:null}
    {!loading&&initial?<><ConsultationTabs tabs={[{key:"identite",label:"Identité",icon:"user"},{key:"liens",label:"Rattachements",icon:"apps"}]} value={active} onChange={setActive} label="Informations du tiers" idPrefix={prefix}/>
      {active==="identite"?<section className="record-editor-section tiers-editor-section" role="tabpanel" id={prefix+"-panel-identite"} aria-labelledby={prefix+"-tab-identite"}><h3><AppIcon name="user"/>Identité et coordonnées</h3><div className="record-editor-grid">
        {input("Nom","Nom du tiers *",{maxLength:255,autoComplete:"organization"})}{select("Nature","Nature *",[{value:"personne",label:"Personne"},{value:"entreprise",label:"Entreprise"}])}{select("ID_TypeClientFk","Type de client *",(references.typesClients||[]).map(item=>({value:String(item.id),label:item.label})))}{input("Email","Adresse e-mail",{type:"email",maxLength:254,autoComplete:"email"})}{input("Telephone","Téléphone",{type:"tel",maxLength:60,autoComplete:"tel"})}{input("Adresse","Adresse",{maxLength:1000,autoComplete:"street-address"})}
        <div className="record-field"><label htmlFor={prefix+"Actif"}>État du tiers</label><label className="tiers-active"><input type="checkbox" id={prefix+"Actif"} checked={values.Actif} onChange={event=>change("Actif",event.target.checked)} disabled={busy||uncertain||!editable}/>Tiers actif</label></div>
        <div className="record-field is-wide"><label htmlFor={prefix+"ObsClient"}>Informations complémentaires</label><textarea id={prefix+"ObsClient"} value={values.ObsClient} onChange={event=>change("ObsClient",event.target.value)} disabled={busy||uncertain||!editable} maxLength={10000}/></div>
      </div></section>:<section className="record-editor-section tiers-editor-section" role="tabpanel" id={prefix+"-panel-liens"} aria-labelledby={prefix+"-tab-liens"}><h3><AppIcon name="apps"/>Rattachements facultatifs</h3><p className="record-editor-note">Un tiers peut être enregistré sans compte utilisateur.</p><div className="record-editor-grid">{select("IdUserFk","Compte utilisateur",optionalOptions(references.users))}{select("IdProfessionnelFk","Professionnel",optionalOptions(references.professionnels))}{select("IdEntiteRepresenteeFk","Entreprise représentée",optionalOptions(references.entites))}<div className="record-field"><label>Entreprise propriétaire</label><output>{record?.NomEntite||scope.entities.find(item=>String(item.id)===scope.entityId)?.label||"Entreprise active"}</output></div></div></section>}
    </>:null}
  </RecordEditorFrame>;
}
