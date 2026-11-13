import {referenceLabel} from "../../utils/referenceOptions";
import {useEffect,useId,useRef,useState} from "react";
import {useAuth} from "../../contexts/AuthContext";
import {useEntityScope} from "../../contexts/EntityScopeContext";
import {requestJson} from "../../services/api";
import RecordEditorFrame from "../../components/RecordEditorFrame";
import ConsultationTabs from "../../components/ConsultationTabs";
import SearchSelect from "../../components/SearchSelect";
import ActionButton from "../../components/ActionButton";
import AppIcon from "../../components/AppIcon";
import {formatDate} from "../logistique/logistiqueShared";
import {formatCurrency} from "../../utils/money";
import {CAISSE_ROOT,CAISSE_REGISTERS,caisseValues,caissePayload,caisseErrors,caisseOptions,cashboxOptions,caisseResponseUncertain} from "./caisseModel";

export default function CaisseEditor({kind,id=null,mode="create",defaults={},context,references={},onClose,onSaved}){
 const {user}=useAuth(),scope=useEntityScope(),prefix=useId(),mounted=useRef(true),activeScope=useRef(scope.scopeKey),attempt=useRef(null),saving=useRef(false),initial=useRef(null);
 if(!initial.current)initial.current=caisseValues(kind,null,references,defaults);
 const [loaded,setLoaded]=useState({record:null,version:null,canManage:false,canValidate:false,canReverse:false,loading:Boolean(id),error:""}),[values,setValues]=useState(()=>initial.current),[baseline,setBaseline]=useState(()=>JSON.stringify(initial.current)),[errors,setErrors]=useState({}),[error,setError]=useState(""),[busy,setBusy]=useState(false),[uncertain,setUncertain]=useState(false),[tab,setTab]=useState("operation"),[reload,setReload]=useState(0),[preparation,setPreparation]=useState({key:"",record:null,version:null,loading:false,error:""});
 const action=mode==="valider"||mode==="contrepasser",permitted=(kind==="ecritures"&&mode==="edit"?context?.canEditDrafts===true:context?.tabs?.[kind]?.canManage===true)&&!context?.readOnly&&user?.permissions?.canWriteData===true&&Boolean(scope.entityId)&&activeScope.current===scope.scopeKey;
 const recordPermission=!id||(mode==="valider"?loaded.canValidate:mode==="contrepasser"?loaded.canReverse:loaded.canManage),readOnly=!permitted||!recordPermission;
 const frozen=readOnly||busy||uncertain||loaded.loading,prepKey=scope.scopeKey+":"+values.IdCaisseFk,prep=preparation.key===prepKey?preparation:{record:null,version:null,loading:Boolean(values.IdCaisseFk),error:""};
 useEffect(()=>{mounted.current=true;return()=>{mounted.current=false;};},[]);
 useEffect(()=>{
  if(!id)return;const controller=new AbortController();setLoaded(previous=>({...previous,loading:true,error:""}));
  requestJson(CAISSE_ROOT+"/"+kind+"/"+encodeURIComponent(id),{requiresAuth:true,signal:controller.signal}).then(response=>{
   if(controller.signal.aborted||scope.scopeKey!==activeScope.current)return;
   if(!response?.success||!response.data?.record){setLoaded({record:null,version:null,canManage:false,loading:false,error:response?.message||"La fiche n’a pas pu être chargée."});return;}
   const data=response.data,next=caisseValues(kind,data.record,references,defaults);setValues(next);setBaseline(JSON.stringify(next));setErrors({});setError("");
   setLoaded({record:data.record,version:data._version,canManage:data.canManage===true,canValidate:data.canValidate===true,canReverse:data.canReverse===true,loading:false,error:""});
  });return()=>controller.abort();
 },[id,kind,reload,scope.scopeKey]);
 useEffect(()=>{
  if(kind!=="clotures"||!values.IdCaisseFk)return;
  const controller=new AbortController();setPreparation({key:prepKey,record:null,version:null,loading:true,error:""});
  requestJson(CAISSE_ROOT+"/clotures/preparation?caisseId="+encodeURIComponent(values.IdCaisseFk),{requiresAuth:true,signal:controller.signal}).then(response=>{
   if(controller.signal.aborted)return;
   setPreparation({key:prepKey,record:response?.success?response.data?.record:null,version:response?.data?._version,loading:false,error:response?.success?"":response?.message||"Le solde de la caisse n’a pas pu être chargé.",canManage:response?.data?.canManage===true});
  });return()=>controller.abort();
 },[kind,prepKey,reload]);
 function change(key,value){if(frozen)return;setValues(previous=>({...previous,[key]:value}));setErrors(previous=>({...previous,[key]:""}));}
 function focusError(next){const key=Object.keys(next)[0];if(!key)return;if(action||key==="motif")setTab("tracabilite");else setTab("operation");requestAnimationFrame(()=>document.getElementById(prefix+"-"+key)?.focus());}
 async function submit(){
  if(saving.current||!permitted||!recordPermission||loaded.loading)return;
  if(kind==="clotures"&&(!prep.record||prep.loading||!prep.canManage||prep.version==null)){setError(prep.error||"Choisissez une caisse et chargez son solde avant de poursuivre.");return;}
  if(!attempt.current){
   const validation=caisseErrors(action?mode:kind,values);setErrors(validation);
   if(Object.keys(validation).length){focusError(validation);return;}
   const version=kind==="clotures"?prep.version:loaded.version;
   if(id&&version==null){setError("La version de cette fiche est indisponible. Rechargez-la.");return;}
   const requestId=crypto.randomUUID(),body=JSON.stringify(caissePayload(action?mode:kind,values,{version,requestId}));
   attempt.current={body,path:CAISSE_ROOT+"/"+kind+(id?"/"+encodeURIComponent(id):"")+(action?"/"+mode:""),method:id&&!action?"PUT":"POST"};
  }
  saving.current=true;setBusy(true);setError("");
  const pending=attempt.current,response=await requestJson(pending.path,{requiresAuth:true,method:pending.method,body:pending.body});
  if(!mounted.current||scope.scopeKey!==activeScope.current)return;
  saving.current=false;setBusy(false);
  if(response?.success&&response.data?.record){attempt.current=null;setUncertain(false);setBaseline(JSON.stringify(values));onSaved(response.data.record);return;}
  if(caisseResponseUncertain(response)){setUncertain(true);setError("La confirmation n’a pas été reçue. Réessayez pour vérifier cette même opération, sans la recréer.");return;}
  attempt.current=null;setUncertain(false);setError(response?.message||"L’opération n’a pas pu être enregistrée.");
  const details=response?.error?.details?.fields||response?.error?.details?.fieldErrors||response?.error?.details;
  if(details&&typeof details==="object"&&!Array.isArray(details)){const fieldErrors=Object.fromEntries(Object.entries(details).filter(([key,value])=>Object.hasOwn(values,key)&&typeof value==="string"));setErrors(fieldErrors);focusError(fieldErrors);}
 }
 function field(key,label,{type="text",options,required=false,disabled=false,note,wide=false}={}){
  const preserved=options&&loaded.record&&values[key]!==""&&!options.some(option=>String(option.value)===String(values[key]));
  if(preserved){const names={IdDeviseFk:"DeviseCode",IdTypeCaisseFk:"TypeCaisse",IdResponsableFk:"Responsable",IdCaisseFk:"NomCaisse",IdTypePaiementFk:"TypePaiement",IdTiersFk:"NomTiers"};options=[...options,{value:String(values[key]),label:["IdDeviseFk","IdTypeCaisseFk","IdTypePaiementFk"].includes(key)?referenceLabel({ID_Generique:values[key]}):loaded.record[names[key]]||"Valeur historique #"+values[key],disabled:true}];note="Valeur historique conservée, indisponible pour une nouvelle affectation.";}
  const fieldId=prefix+"-"+key,description=errors[key]?fieldId+"-error":note?fieldId+"-note":undefined;
  return <label className={wide?"is-wide":""} key={key} htmlFor={fieldId}><span>{label}{required?" *":""}</span>{options?<SearchSelect id={fieldId} label={label} value={String(values[key]??"")} options={options} disabled={frozen||disabled} invalid={Boolean(errors[key])} describedBy={description} onChange={value=>change(key,value)}/>:type==="textarea"?<textarea id={fieldId} value={values[key]||""} disabled={frozen||disabled} aria-invalid={Boolean(errors[key])} aria-describedby={description} onChange={event=>change(key,event.target.value)} rows={3}/>:<input id={fieldId} type={type==="decimal"?"text":type} inputMode={type==="decimal"?"decimal":undefined} step={type==="datetime-local"?1:undefined} value={values[key]??""} disabled={frozen||disabled} aria-invalid={Boolean(errors[key])} aria-describedby={description} maxLength={type==="decimal"?20:undefined} onChange={event=>change(key,event.target.value)}/>} {errors[key]?<small className="record-field-error" id={fieldId+"-error"} role="alert">{errors[key]}</small>:note?<small id={fieldId+"-note"}>{note}</small>:null}</label>;
 }
 const record=loaded.record,cash=(references.caisses||[]).find(item=>String(item.IdCaisse)===String(values.IdCaisseFk)),currency=cash?.DeviseCode||record?.DeviseCode||"",title=action?(mode==="valider"?"Valider l’écriture":"Contrepasser l’écriture"):kind==="clotures"?"Clôturer la caisse":kind==="caisses"?(id?"Modifier la caisse":"Nouvelle caisse"):(id?"Modifier le brouillon":"Nouvelle écriture");
 const dirty=uncertain||JSON.stringify(values)!==baseline,allowed=Boolean(!loaded.error&&permitted&&recordPermission&&(!id||record)&&(!action||record));
 return <RecordEditorFrame title={title} subtitle={record?.CodeCaisse||record?.CodePaiement||"Caisse"} icon={CAISSE_REGISTERS[kind].icon} onClose={onClose} onSubmit={submit} busy={busy} loading={loaded.loading} dirty={dirty} readOnly={readOnly} canSubmit={allowed} error={loaded.error||error} onReload={!uncertain&&id?()=>setReload(value=>value+1):undefined} submitLabel={uncertain?"Vérifier l’opération":action?(mode==="valider"?"Valider l’écriture":"Confirmer la contrepassation"):kind==="clotures"?"Enregistrer la clôture":"Enregistrer"} defaultWidth={900} className="caisse-editor" storageKey="sauverndeko.caisse.editor.width" discardMessage={uncertain?"La confirmation est incertaine. Fermer ne garantit pas l’annulation : vérifiez le journal avant de recréer une opération.":"Abandonner les modifications ?"}>
  {!loaded.loading&&readOnly?<p className="record-editor-note">{!permitted?"Vous consultez cette fiche. Les modifications ne sont pas autorisées dans ce contexte.":"Cette opération n’est pas disponible pour cette écriture."}</p>:null}
  {action&&record?<section className="record-editor-section"><h3><AppIcon name="document"/>{record.CodePaiement}</h3><dl className="caisse-summary"><div><dt>Caisse</dt><dd>{record.NomCaisse}</dd></div><div><dt>Montant</dt><dd>{formatCurrency(record.MontantPaiement,record.DeviseCode)}</dd></div><div><dt>Mouvement</dt><dd>{String(record.SensMouvement)==="1"?"Encaissement":"Décaissement"}</dd></div><div><dt>Date et heure</dt><dd>{formatDate(record.DatePaiement)}</dd></div></dl><p>{mode==="valider"?"La validation enregistre le mouvement dans le solde de la caisse. L’écriture devient définitive.":"Une écriture inverse sera créée. L’écriture d’origine et son historique seront conservés."}</p></section>:null}
  {!action?<ConsultationTabs label="Informations de la caisse" idPrefix={prefix+"-tabs"} value={tab} onChange={setTab} tabs={[{key:"operation",label:kind==="clotures"?"Comptage":kind==="caisses"?"Identification":"Opération",icon:kind==="caisses"?"wallet":"document"},{key:"tracabilite",label:"Traçabilité",icon:"clock"}]}/>:null}
  {!action&&tab==="operation"?<section className="record-editor-section caisse-fields" role="tabpanel" id={prefix+"-tabs-panel-operation"} aria-labelledby={prefix+"-tabs-tab-operation"}>
   <h3><AppIcon name={CAISSE_REGISTERS[kind].icon}/>{kind==="caisses"?"Informations de la caisse":kind==="clotures"?"Comptage physique":"Informations de l’écriture"}</h3>
   <div className="caisse-field-grid">
    {kind==="caisses"?<>
     {field("NomCaisse","Nom de la caisse",{required:true,wide:true})}
     {field("IdDeviseFk","Devise",{required:true,options:caisseOptions(references.devises),disabled:Boolean(id),note:id?"La devise d’une caisse reste fixe.":undefined})}
     {field("IdTypeCaisseFk","Type de caisse",{options:caisseOptions(references.typesCaisses,"Non renseigné")})}
     {field("IdResponsableFk","Responsable",{options:caisseOptions(references.responsables,"Non affecté")})}
     <label className="caisse-check"><input type="checkbox" checked={values.Actif} disabled={frozen} onChange={event=>change("Actif",event.target.checked)}/><span>Caisse active</span></label>
     <p className="record-editor-note is-wide">Le code est attribué automatiquement. Une nouvelle caisse commence avec un solde nul ; les fonds s’enregistrent par une écriture.</p>
    </>:<>
     {field("IdCaisseFk","Caisse",{required:true,options:cashboxOptions(references),wide:true,disabled:Boolean(id)})}
     {field(kind==="clotures"?"ClotureLe":"DatePaiement",kind==="clotures"?"Date et heure du comptage":"Date et heure",{type:"datetime-local",required:true,note:"Heure de Kinshasa."})}
     {kind==="clotures"?<>
      <div className="caisse-balance"><span>Solde théorique</span><strong>{prep.loading?"Chargement…":formatCurrency(prep.record?.MontantCaisse,prep.record?.DeviseCode)}</strong></div>
      {field("MontantCompte","Montant compté"+(currency?" · "+currency:""),{type:"decimal",required:true})}
      {prep.error?<div className="record-editor-error is-wide" role="alert">{prep.error}<ActionButton icon="refresh" onClick={()=>setReload(value=>value+1)}>Réessayer</ActionButton></div>:null}
      <p className="record-editor-note is-wide">Comptez les espèces réellement présentes. L’écart sera conservé sans correction automatique du solde. Les écritures antérieures à cette clôture ne pourront plus être validées.</p>
     </>:<>
      {field("SensMouvement","Mouvement",{required:true,options:[{value:"1",label:"Encaissement"},{value:"-1",label:"Décaissement"}]})}
      {field("LibellePaiement","Libellé",{required:true,wide:true})}
      {field("MontantPaiement","Montant"+(currency?" · "+currency:""),{required:true,type:"decimal"})}
      {field("IdTypePaiementFk","Type d’opération",{options:caisseOptions(references.typesPaiements,"Non renseigné")})}
      {!context?.hiddenFields?.[kind]?.includes("IdTiersFk")?field("IdTiersFk","Tiers",{options:caisseOptions(references.tiers,"Non renseigné")}):null}
      {field("ReferenceExterne","Référence")}
      {field("ObsPaiement","Observations",{type:"textarea",wide:true})}
      {!id?<label className="caisse-check is-wide"><input type="checkbox" checked={values.valider} disabled={frozen} onChange={event=>change("valider",event.target.checked)}/><span>Valider immédiatement et mettre à jour le solde</span></label>:null}
      {id?<label className="caisse-check is-wide"><input type="checkbox" checked={values.ValidePaiement} disabled={frozen} onChange={event=>change("ValidePaiement",event.target.checked)}/><span>Conserver le brouillon actif · décochez pour l’abandonner en gardant sa trace</span></label>:null}
      <p className="record-editor-note is-wide">Un brouillon n’affecte pas le solde. Une écriture validée se corrige par contrepassation.</p>
     </>}
    </>}
   </div>
  </section>:null}
  {action||tab==="tracabilite"?<section className="record-editor-section caisse-fields" role={!action?"tabpanel":undefined} id={!action?prefix+"-tabs-panel-tracabilite":undefined} aria-labelledby={!action?prefix+"-tabs-tab-tracabilite":undefined}><h3><AppIcon name="clock"/>Traçabilité</h3><div className="caisse-field-grid">{record?<div className="is-wide caisse-balance"><span>{kind==="caisses"?"Code caisse":"N° d’écriture"}</span><strong>{record.CodeCaisse||record.CodePaiement}</strong></div>:null}{field("motif","Motif de l’opération",{type:"textarea",required:true,wide:true,note:kind==="clotures"?"Décrivez le comptage et justifiez tout écart.":"Ce motif sera conservé avec votre identité et la date de l’opération."})}</div></section>:null}
 </RecordEditorFrame>;
}
