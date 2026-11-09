import {REFERENCE_RETAINED_HINT,referenceLabel,isRetainedReference} from "../../utils/referenceOptions";
import {useEffect,useId,useRef,useState} from "react";
import {useAuth} from "../../contexts/AuthContext";
import {useEntityScope} from "../../contexts/EntityScopeContext";
import useReferencesRefresh from "../../hooks/useReferencesRefresh";
import {immobilisationsRequest,immobilisationRecord} from "../../services/immobilisations";
import {immobilisationValues,immobilisationErrors,immobilisationPayload,immobilisationOptions,immobilisationValue,IMMOBILISATION_REFERENCES,IMMOBILISATION_LIMITS} from "./immobilisationForm";
import RecordEditorFrame from "../../components/RecordEditorFrame";
import ConsultationTabs from "../../components/ConsultationTabs";
import SearchSelect from "../../components/SearchSelect";
import ActionButton from "../../components/ActionButton";
import AppIcon from "../../components/AppIcon";
import {formatDate,formatCurrency} from "./logistiqueShared";
import "./Immobilisations.css";

const TABS=[{key:"identification",label:"Identification",icon:"tag"},{key:"affectation",label:"Affectation",icon:"user"},{key:"acquisition",label:"Acquisition",icon:"cash"},{key:"trace",label:"Traçabilité",icon:"clock"}];
const LABELS={ID_CategorieFk:"CategorieMateriel",ID_EtatFk:"EtatMateriel",ID_ResponsableFk:"Responsable",ID_ServiceFk:"Service",ID_DeviseFk:"DeviseCode"};
const flatten=value=>Array.isArray(value)?value.map(flatten).join(" "):typeof value==="string"?value:"";
const tabFor=key=>["ID_ResponsableFk","ID_ServiceFk","ID_LocalisationFk","LocalisationComplement"].includes(key)?"affectation":["PrixUnitaire","ID_DeviseFk","DateEntree","DateAcquisition","DateMiseEnService"].includes(key)?"acquisition":["Observations","motif"].includes(key)?"trace":"identification";
export default function ImmobilisationEditor({recordId=null,operation="edit",onClose,onSaved,draft=null,onDraftSave,initialTab="identification"}){
 const {user}=useAuth(),scope=useEntityScope(),prefix=useId(),creating=recordId==null,actionOnly=["archive","restore"].includes(operation);
 const identity=String(user?.IdUser??"")+":"+scope.scopeKey+":"+String(recordId??"new")+":"+operation,current=useRef(identity),mounted=useRef(true),saving=useRef(false),ticket=useRef(null),referenceRequest=useRef(null);current.current=identity;
 const [values,setValues]=useState(()=>immobilisationValues()),[baseline,setBaseline]=useState(null),[record,setRecord]=useState(null),[meta,setMeta]=useState(null),[references,setReferences]=useState({}),[motif,setMotif]=useState("");
 const [active,setActive]=useState(initialTab),[loading,setLoading]=useState(true),[busy,setBusy]=useState(false),[error,setError]=useState(""),[errors,setErrors]=useState({}),[reload,setReload]=useState(0),[uncertain,setUncertain]=useState(false),[confirmReload,setConfirmReload]=useState(false),[settled,setSettled]=useState(""),[referenceError,setReferenceError]=useState("");
 const ready=settled===identity,changed=Boolean(baseline)&&JSON.stringify(values)!==JSON.stringify(baseline),allowed=ready&&scope.canWrite&&(creating?references.canCreate===true:actionOnly?meta?.[operation==="archive"?"canArchive":"canRestore"]===true:meta?.canEdit===true),disabled=loading||busy||uncertain||!allowed;
 useEffect(()=>{mounted.current=true;return()=>{mounted.current=false;};},[]);
 async function refreshReferences(){
  if(!ready||loading||busy||uncertain||actionOnly)return;
  const key=identity,controller=new AbortController();referenceRequest.current?.abort();referenceRequest.current=controller;
  const response=await immobilisationsRequest("/references"+(creating?"":"?immobilisationId="+encodeURIComponent(recordId)),{signal:controller.signal});
  if(controller.signal.aborted||!mounted.current||current.current!==key)return;
  if(response?.success){setReferences(response.data||{});setReferenceError("");}else setReferenceError(response?.message||"Les listes n’ont pas pu être actualisées.");
 }
 useReferencesRefresh(refreshReferences,{enabled:ready&&!actionOnly});
 useEffect(()=>{
  const controller=new AbortController(),key=identity;referenceRequest.current?.abort();setLoading(true);setBusy(false);setError("");setErrors({});setReferenceError("");setRecord(null);setMeta(null);setBaseline(null);setReferences({});setMotif("");setActive(initialTab);setUncertain(false);setConfirmReload(false);saving.current=false;ticket.current=null;
  Promise.all([immobilisationsRequest("/references"+(creating?"":"?immobilisationId="+encodeURIComponent(recordId)),{signal:controller.signal}),creating?Promise.resolve({success:true,data:null,meta:{}}):immobilisationsRequest("/"+recordId,{signal:controller.signal})]).then(([refs,response])=>{
   if(controller.signal.aborted||current.current!==key)return;setLoading(false);setSettled(key);
   if(!refs?.success||!response?.success){setError((refs?.success?response:refs)?.message||"La fiche n’a pas pu être chargée.");return;}
   const row=creating?null:immobilisationRecord(response);if(!creating&&String(row?.ID_Immobilisation)!==String(recordId)){setError("La fiche reçue ne correspond pas au bien choisi. Rechargez-la.");return;}
   const form=creating&&draft?.values?{...draft.values}:immobilisationValues(row,refs.data);if(creating&&draft?.motif)setMotif(draft.motif);setReferences(refs.data||{});setRecord(row);setMeta(response.meta||{});setValues(form);setBaseline(form);
  });return()=>{controller.abort();referenceRequest.current?.abort();};
 },[identity,reload]);
 function change(key,value){if(disabled||saving.current)return;setValues(previous=>({...previous,[key]:value,...(key==="SuiviIndividuel"&&value||key==="NumeroSerie"&&value.trim()?{Quantite:"1"}:{})}));setErrors(previous=>({...previous,[key]:""}));}
 function focusIssue(issues){const key=Object.keys(issues)[0];if(!actionOnly)setActive(tabFor(key));requestAnimationFrame(()=>document.getElementById(prefix+key)?.focus());}
 async function submit(){
  if(!allowed||loading||saving.current||!baseline||!creating&&!actionOnly&&!changed&&!uncertain)return;
  let snapshot=ticket.current;
  if(!uncertain){
   const issues=actionOnly?(!motif.trim()?{motif:"Précisez le motif de cette action."}:Array.from(motif.trim()).length>1000?{motif:"Limitez le motif à 1000 caractères."}:{}):immobilisationErrors(values,motif,record);setErrors(issues);setError("");
   const revision=meta?.revision??record?._version;if(!creating&&!revision){setError("Rechargez la fiche avant de l’enregistrer.");return;}
   if(Object.keys(issues).length){setError("Vérifiez les champs indiqués.");focusIssue(issues);return;}
   if(creating&&onDraftSave){const data=immobilisationPayload(values,{motif,requestId:""});delete data.requestId;onDraftSave({values:{...values},data,motif});return;}
   const payload=actionOnly?{...(operation==="restore"?{Actif:true}:{}),_version:revision,motif:motif.trim(),requestId:""}:immobilisationPayload(values,{record,revision,motif,requestId:""}),fingerprint=JSON.stringify(payload);
   if(snapshot?.fingerprint!==fingerprint){payload.requestId=crypto.randomUUID();snapshot={fingerprint,payload};ticket.current=snapshot;}
  }
  if(!snapshot)return;const key=identity;saving.current=true;setBusy(true);setError("");
  const response=await immobilisationsRequest(creating?"":"/"+recordId,{method:creating?"POST":operation==="archive"?"DELETE":operation==="restore"?"PATCH":"PUT",body:snapshot.payload});
  if(!mounted.current||current.current!==key)return;saving.current=false;setBusy(false);
  const row=immobilisationRecord(response);
  if(!response?.success||!row?.ID_Immobilisation){setUncertain(!response?.status||response.status>=500||response.success===true);const details=response?.error?.details,issues=details&&typeof details==="object"&&!Array.isArray(details)?Object.fromEntries(Object.entries(details).filter(([name])=>name in values||name==="motif").map(([name,value])=>[name,flatten(value)])):{};setErrors(issues);setError(response?.message||"Le bien n’a pas pu être enregistré.");if(Object.keys(issues).length)focusIssue(issues);return;}
  if(!creating&&String(row.ID_Immobilisation)!==String(recordId)){setUncertain(true);setError("La réponse reçue ne correspond pas à cette fiche. Vérifiez l’enregistrement.");return;}
  ticket.current=null;setUncertain(false);onSaved?.(row,{operation:creating?"create":operation});
 }
 function field(name,label,control){const id=prefix+name;return <div className="record-field" key={name}><label htmlFor={id}>{label}</label>{control(id)}{errors[name]?<small id={id+"-error"} className="record-field-error" role="alert">{errors[name]}</small>:null}</div>;}
 function input(name,label,props={}){return field(name,label,id=><input id={id} value={values[name]??""} onChange={event=>change(name,event.target.value)} disabled={disabled} aria-invalid={Boolean(errors[name])} aria-describedby={errors[name]?id+"-error":undefined} {...props}/>);}
 function select(name,label,options){return field(name,label,id=><><SearchSelect id={id} label={label} value={String(values[name])} options={options} onChange={value=>change(name,name==="SuiviIndividuel"?value==="true":value)} disabled={disabled} invalid={Boolean(errors[name])}/>{isRetainedReference(options,values[name])?<small className="record-editor-note">{REFERENCE_RETAINED_HINT}</small>:null}</>);}
 function reference(name,label,required=false){return select(name,label,immobilisationOptions(references[IMMOBILISATION_REFERENCES[name]],{optional:!required,current:values[name],currentLabel:["ID_CategorieFk","ID_EtatFk","ID_ServiceFk","ID_DeviseFk"].includes(name)?referenceLabel({ID_Generique:values[name]}):record?.[LABELS[name]]}));}
 function area(name,label,max){return field(name,label,id=><textarea id={id} value={values[name]} maxLength={max} rows={4} disabled={disabled} onChange={event=>change(name,event.target.value)} aria-invalid={Boolean(errors[name])}/>);}

 const title=onDraftSave?"Immobilisation du panier":creating?"Nouvelle immobilisation":operation==="archive"?"Archiver l’immobilisation":operation==="restore"?"Réactiver l’immobilisation":"Modifier l’immobilisation";
 return <RecordEditorFrame title={title} subtitle={ready?(record?.NomImmobilisation||"Bien et affectation"):"Bien et affectation"} icon="building" defaultWidth={1000} storageKey="sauverndeko.immobilisation.editor.width" onClose={onClose} onSubmit={submit} loading={loading||!ready} busy={busy} readOnly={ready&&!allowed} dirty={ready&&Boolean(changed||motif.trim()||uncertain)} canSubmit={allowed&&Boolean(baseline)&&(creating||actionOnly||changed||uncertain)} error={ready?error:""} onReload={()=>{if(changed||motif.trim()||uncertain)setConfirmReload(true);else setReload(x=>x+1);}} submitLabel={onDraftSave?"Valider la ligne":uncertain?"Vérifier l’enregistrement":operation==="archive"?"Archiver":operation==="restore"?"Réactiver":"Enregistrer"} className="immobilisation-editor">
  {ready&&confirmReload?<div className="record-discard" role="alert"><span>Recharger la fiche et abandonner les modifications ?</span><div><ActionButton onClick={()=>setConfirmReload(false)}>Continuer</ActionButton><ActionButton onClick={()=>setReload(x=>x+1)}>Recharger</ActionButton></div></div>:null}
  {ready&&!loading&&baseline?<>
   {referenceError?<div className="record-editor-error" role="alert">{referenceError}<ActionButton icon="refresh" disabled={disabled} onClick={refreshReferences}>Actualiser les listes</ActionButton></div>:null}
   {actionOnly?<section className="record-editor-section"><h3><AppIcon name="building"/>{record?.CodeImmobilisation}</h3><p>{record?.NomImmobilisation}</p><p className="record-editor-note">{operation==="archive"?"Le bien sera archivé. Sa fiche et son historique restent conservés.":"Le bien sera de nouveau proposé dans le registre actif."}</p></section>:<><ConsultationTabs tabs={TABS.map(tab=>({...tab,disabled:busy}))} value={active} onChange={setActive} label="Informations du bien" idPrefix={prefix}/>
    <section role="tabpanel" id={prefix+"-panel-"+active} aria-labelledby={prefix+"-tab-"+active} className="record-editor-section"><h3><AppIcon name={TABS.find(tab=>tab.key===active).icon}/>{TABS.find(tab=>tab.key===active).label}</h3>
    <div className="record-editor-grid">
     {active==="identification"?<>{input("NomImmobilisation","Nom du bien *",{maxLength:200})}{field("code","Code du bien",id=><input id={id} value={record?.CodeImmobilisation||"Attribué à l’enregistrement"} readOnly disabled/>)}{reference("ID_CategorieFk","Type de matériel *",true)}{reference("ID_EtatFk","État du matériel")}{select("SuiviIndividuel","Mode de suivi *",[{value:"true",label:"Bien individuel"},{value:"false",label:"Lot homogène"}])}{input("Quantite","Quantité *",{inputMode:"numeric",maxLength:18,readOnly:values.SuiviIndividuel||Boolean(values.NumeroSerie.trim())})}{input("Reference","Référence",{maxLength:255})}{input("NumeroSerie","N° de série",{maxLength:255})}<div className="record-field is-wide">{area("Caracteristiques","Caractéristiques",4000)}</div><p className="record-editor-note is-wide">{values.SuiviIndividuel?"Un bien individuel est suivi avec une quantité de 1.":"Un lot homogène regroupe des biens de mêmes caractéristiques, état et affectation."}</p></>:null}
     {active==="affectation"?<>{reference("ID_ResponsableFk","Responsable")}{reference("ID_ServiceFk","Service")}{input("LocalisationComplement","Localisation",{maxLength:IMMOBILISATION_LIMITS.LocalisationComplement,placeholder:"Ex. : Bâtiment B, bureau 12"})}{creating&&values.ID_LocalisationFk?<p className="record-editor-note is-wide">Site du fichier importé · {references.localisations?.find(item=>String(item.id)===String(values.ID_LocalisationFk))?.label||values.ID_LocalisationFk}</p>:null}<p className="record-editor-note is-wide">Les affectations non renseignées restent possibles.</p></>:null}
     {active==="acquisition"?<>{input("DateEntree","Date et heure d’entrée *",{type:"datetime-local",step:"1"})}{input("DateAcquisition","Date d’acquisition",{type:"date"})}{input("DateMiseEnService","Date de mise en service",{type:"date"})}{input("PrixUnitaire","Prix d’acquisition unitaire",{inputMode:"decimal",maxLength:19,placeholder:"Non renseigné"})}{reference("ID_DeviseFk","Devise") }<div className="record-field"><label>Valeur d’acquisition indicative</label><output>{formatCurrency(immobilisationValue(values),(references.currencies||[]).find(item=>String(item.id)===values.ID_DeviseFk)?.code||record?.DeviseCode)}</output></div><p className="record-editor-note is-wide">Heure de Kinshasa. Laissez le prix vide si son montant n’est pas connu.</p></>:null}
     {active==="trace"?<><div className="record-field is-wide">{area("Observations","Observations",4000)}</div>{record?<><div className="record-field"><label>Créé le</label><output>{formatDate(record.CreeLe)}</output></div><div className="record-field"><label>Modifié le</label><output>{formatDate(record.ModifieLe)}</output></div><div className="record-field"><label>Entreprise</label><output>{record.NomEntite||"—"}</output></div></>:null}</>:null}
    </div></section></>}
   <section className="record-editor-section"><div className="record-field"><label htmlFor={prefix+"motif"}>Motif de l’enregistrement *</label><textarea id={prefix+"motif"} value={motif} disabled={disabled} rows={2} maxLength={1000} onChange={event=>{setMotif(event.target.value);setErrors(previous=>({...previous,motif:""}));}} aria-invalid={Boolean(errors.motif)}/>{errors.motif?<small className="record-field-error" role="alert">{errors.motif}</small>:null}</div>{uncertain?<p className="record-editor-note" role="status">La réponse reste à confirmer. Réessayez pour vérifier la même demande ou rechargez la fiche.</p>:null}</section>
  </>:null}
 </RecordEditorFrame>;
}
