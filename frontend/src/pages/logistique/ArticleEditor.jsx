import {fieldCurrencyReferences} from "../../utils/money";
import {REFERENCE_RETAINED_HINT,retainReference,isRetainedReference} from "../../utils/referenceOptions";
import { newCurrencyId, currencyOptions } from "../../utils/money";
import SearchSelect from "../../components/SearchSelect";
import ConsultationTabs from "../../components/ConsultationTabs";
import ActionButton from "../../components/ActionButton";
import {useConsultations} from "../../components/ConsultationProvider";
import LotFields, {lotErrors} from "../../components/LotFields";
import ProductPhotoPicker from "../../components/ProductPhotoPicker";
import {useEffect,useId,useRef,useState} from "react";
import {useAuth} from "../../contexts/AuthContext";
import RecordEditorFrame from "../../components/RecordEditorFrame";
import AppIcon from "../../components/AppIcon";
import {fetchLogistiqueArticle,createLogistiqueArticle,updateLogistiqueArticle} from "../../services/logistique";
import {buildReferenceOptions,formatDate} from "./logistiqueShared";
import {articleForm,articleErrors,articlePayload,alertDate} from "./articleForm";
import {createReceiptRequestId} from "./receiptForm";
import "./ArticleEditor.css";

function Field({name,label,error,hint,wide=false,children}) {
  return <div className={"record-field"+(wide?" is-wide":"")}><label htmlFor={name}>{label}</label>{children}{error?<small className="record-field-error" id={name+"-error"}>{error}</small>:hint?<small id={name+"-hint"}>{hint}</small>:null}</div>;
}
function Section({icon,title,children}) {return <section className="record-editor-section"><h3><AppIcon name={icon}/>{title}</h3><div className="record-editor-grid">{children}</div></section>;}
export default function ArticleEditor({articleId,onClose,onSaved,references:receivedReferences}) {
 const references=fieldCurrencyReferences(receivedReferences,"articleCurrencies");
  const {user}=useAuth(),creating=!articleId;
  const {openProductLots}=useConsultations();
  const [active,setActive]=useState("article");
  const prefix=useId(),mounted=useRef(true),saving=useRef(false),focusRef=useRef(null);
  const creationRequestId=useRef(null);
  if(!creationRequestId.current)creationRequestId.current=createReceiptRequestId();
  const createForm=()=>({...articleForm(null),ID_DeviseFk:newCurrencyId(references)});
  const [record,setRecord]=useState(null),[meta,setMeta]=useState(null),[values,setValues]=useState(createForm);
  const [initial,setInitial]=useState(()=>JSON.stringify(createForm()));
  const [loading,setLoading]=useState(!creating),[busy,setBusy]=useState(false),[error,setError]=useState(""),[errors,setErrors]=useState({});
  const [initialLots,setInitialLots]=useState([]),[lotsError,setLotsError]=useState("");
  const [photo,setPhoto]=useState({file:null,remove:false});
  const [reload,setReload]=useState(0),[conflict,setConflict]=useState(false);
  const canWrite=user?.permissions?.canWriteData===true;
  const dirty=JSON.stringify(values)!==initial||Boolean(photo.file||photo.remove||initialLots.length);
  useEffect(()=>{mounted.current=true;return()=>{mounted.current=false;};},[]);
  useEffect(()=>{
    if(creating)return;
    let active=true;setLoading(true);setError("");setErrors({});setConflict(false);
    fetchLogistiqueArticle(articleId).then(response=>{
      if(!active)return;
      if(!response?.success){setRecord(null);setMeta(null);setError(response?.message||"La fiche n’a pas pu être chargée.");setLoading(false);return;}
      const form=articleForm(response.data);
      setPhoto({file:null,remove:false});setRecord(response.data);setMeta(response.meta);setValues(form);setInitial(JSON.stringify(form));setLoading(false);
    });
    return()=>{active=false;};
  },[articleId,reload,creating]);
  useEffect(()=>{
    if(loading)return;
    const frame=requestAnimationFrame(()=>focusRef.current?.focus({preventScroll:true}));
    return()=>cancelAnimationFrame(frame);
  },[loading]);
  function change(name,value){if(busy||!canWrite)return;setValues(current=>({...current,[name]:value}));setErrors(current=>({...current,[name]:""}));if(name==="QteArticle")setLotsError("");}
  function fieldTab(name){
    if(["ID_UniteFk","QteArticle","QteMinArticle","PoidsUnitaire","ID_UnitePoidsFk","ID_DeviseFk","PUArticle","PVArticle"].includes(name))return "stock";
    if(["DatePeremptionArticle","NbreJoursAlerteArticle","DatePeremptionAlerteArticle"].includes(name))return "conservation";
    if(["InformationArticle","ObsArticle"].includes(name))return "informations";
    return "article";
  }
  function focusInvalid(fields){
    const name=Object.keys(fields)[0];setActive(fieldTab(name));
    requestAnimationFrame(()=>{
      const target=document.getElementById(prefix+name);
      (name==="photo"?target?.querySelector("button:not(:disabled)")||target:target)?.focus({preventScroll:true});
    });
  }
  function focusLots(){setActive("lots");requestAnimationFrame(()=>{const target=document.getElementById(prefix+"initial-lots");(target?.querySelector("input:not(:disabled)")||target)?.focus({preventScroll:true});});}
  function input(name,label,options={}){
    const {hint,wide,type="text",...attributes}=options,id=prefix+name;
    return <Field name={id} label={label} wide={wide} error={errors[name]} hint={hint}><input id={id} name={name} ref={name==="NomArticle"?focusRef:null} type={type} value={values[name]??""} onChange={e=>change(name,e.target.value)} disabled={busy||!canWrite} aria-invalid={Boolean(errors[name])} aria-describedby={errors[name]?id+"-error":hint?id+"-hint":undefined} {...attributes}/></Field>;
  }
  function select(name,label,source,locked=false){
    const id=prefix+name,options=buildReferenceOptions(source,label),known=options.some(x=>String(x.value)===String(values[name]));
    const choices=retainReference(options,values[name],record?.[{ID_TypeArticleFk:"TypeArticle",ID_CategorieArticleFk:"CategorieArticle",ID_UniteFk:"Unite",ID_UnitePoidsFk:"UnitePoids",ID_DeviseFk:"DeviseCode"}[name]]||"Valeur actuelle");
    const hint=isRetainedReference(choices,values[name])?REFERENCE_RETAINED_HINT:locked?(name==="ID_DeviseFk"?"La devise est conservée après une opération de stock.":"L’unité est conservée après le premier mouvement."):!options.length?"Aucune valeur disponible. Vérifiez les références.":"";
    return <Field name={id} label={label} error={errors[name]} hint={hint}><SearchSelect id={id} label={label} value={values[name]} options={name==="ID_UnitePoidsFk"?[{value:"",label:"Non renseignée"},...choices]:choices} onChange={next=>change(name,next)} disabled={busy||!canWrite||locked||(!options.length&&!values[name])} invalid={Boolean(errors[name])} describedBy={errors[name]?id+"-error":hint?id+"-hint":undefined}/></Field>;
  }
  function readOnly(name,label,value,hint="") {
    const id=prefix+name;
    return <Field name={id} label={label} hint={hint}><input id={id} value={value==null||value===""?"Non renseigné":String(value)} readOnly aria-describedby={hint?id+"-hint":undefined}/></Field>;
  }
  const ownerId=creating?user?.IdUser:(record?.ID_UserFK ?? record?.IdUser);
  const ownerName=creating?[user?.PrenomUser,user?.NomUser].filter(Boolean).join(" "):record?.NomComplet || references?.users?.find(item=>String(item.id)===String(ownerId))?.label;
  const owner=ownerName?ownerName+(ownerId!=null?" · #"+ownerId:""):ownerId!=null?"Utilisateur #"+ownerId:"Non renseigné";
  async function submit(){
    if(saving.current||busy||loading||!canWrite||(!creating&&!meta?.revision))return;
    const invalid=articleErrors(values,creating);
    const lotError=creating?lotErrors(initialLots,values.QteArticle):"";setLotsError(lotError);setErrors(invalid);setError("");setConflict(false);
    if(Object.keys(invalid).length){setError("Vérifiez les champs indiqués.");focusInvalid(invalid);return;}
    if(lotError){setError("Vérifiez les lots du stock initial.");focusLots();return;}
    saving.current=true;setBusy(true);
    const payload=articlePayload(values,record,meta?.revision);
    if(creating)payload.requestId=creationRequestId.current;
    delete payload.PhotoArticle;
    if(creating&&initialLots.length)payload.LotsInitiaux=initialLots;
    if(photo.remove)payload._removePhoto=true;
    const response=creating?await createLogistiqueArticle(payload,photo.file):await updateLogistiqueArticle(articleId,payload,photo.file);
    if(!mounted.current)return;
    saving.current=false;setBusy(false);
    if(!response?.success){
      const details=response?.error?.details;
      const fieldErrors=details&&typeof details==="object"&&!Array.isArray(details)?Object.fromEntries(Object.entries(details).filter(([key])=>key in values||key==="photo").map(([key,value])=>[key,String(value)])):{};
      const serverLots=details&&typeof details==="object"?Object.entries(details).filter(([key])=>/^LotsInitiaux(?:\.|$)/.test(key)).map(([,value])=>String(value)).join(" "):"";
      setErrors(fieldErrors);if(serverLots)setLotsError(serverLots);
      setError(Object.keys(fieldErrors).length||serverLots?"Vérifiez les champs indiqués.":response?.message||"L’article n’a pas pu être enregistré.");
      setConflict(response?.error?.code==="ARTICLE_CONFLICT");
      if(Object.keys(fieldErrors).length)focusInvalid(fieldErrors);else if(serverLots)focusLots();
      return;
    }
    onSaved(response.data,creating?"created":"updated");
  }
  return <RecordEditorFrame title={creating?"Nouvel article":"Modifier l’article"} subtitle={record?.NomArticle||"Identité, stock et prix"} icon="box" onClose={onClose} onSubmit={submit} busy={busy} loading={loading} dirty={dirty} canSubmit={canWrite&&(creating||Boolean(record&&meta?.revision))&&(creating||dirty)} error={error} onReload={!creating&&(conflict||(!record&&!loading))?()=>setReload(x=>x+1):null} className="article-editor-dialog" storageKey="sauverndeko.article-editor.width">
    {!loading&&(creating||record)?<div className="article-editor">
      <ConsultationTabs tabs={[{key:"article",label:"Article",icon:"tag"},{key:"stock",label:"Stock et prix",icon:"box"},{key:"lots",label:"Lots",icon:"box"},{key:"conservation",label:"Conservation",icon:"calendar"},{key:"informations",label:"Informations",icon:"document"},{key:"tracabilite",label:"Traçabilité",icon:"user"}]} value={active} onChange={setActive} label="Rubriques de l’article" idPrefix={prefix}/>
      <section role="tabpanel" id={prefix+"-panel-article"} aria-labelledby={prefix+"-tab-article"} hidden={active!=="article"} tabIndex={active==="article"?0:-1}>
        <div id={prefix+"photo"} tabIndex={-1}>{active==="article"?<ProductPhotoPicker record={record} value={photo} onChange={next=>{if(busy||!canWrite)return;setPhoto(next);setErrors(current=>({...current,photo:""}));}} disabled={busy||!canWrite} error={errors.photo}/>:null}</div>
      {!creating?<div className="record-editor-identity"><AppIcon name="box"/><div><strong>{record.NomArticle}</strong><small>{record.CodeArticleInterne?"Code : "+record.CodeArticleInterne:"Code interne non renseigné"}</small><small>{record.RefArticle?"Réf. : "+record.RefArticle:"Référence non renseignée"}</small></div></div>:null}
      <Section title="Identification" icon="tag">
        {input("NomArticle","Nom de l’article *",{maxLength:100,autoComplete:"off",wide:true})}
        {input("CodeArticleInterne","Code interne",{maxLength:243})}
        {input("CodeArticleExterne","Code externe",{inputMode:"numeric",maxLength:10})}
        {input("RefArticle","Référence",{maxLength:255,wide:true})}
        {select("ID_CategorieArticleFk","Catégorie"+(creating?" *":""),references?.articleCategories)}
        {select("ID_TypeArticleFk","Type"+(creating?" *":""),references?.articleTypes)}
        <div className="record-field"><span>État de l’article</span><label className="record-editor-check" htmlFor={prefix+"ValideArticle"}><input id={prefix+"ValideArticle"} name="ValideArticle" type="checkbox" checked={values.ValideArticle===true} onChange={event=>change("ValideArticle",event.target.checked)} disabled={busy||!canWrite}/>Article actif</label></div>
      </Section>
      </section>
      <section role="tabpanel" id={prefix+"-panel-stock"} aria-labelledby={prefix+"-tab-stock"} hidden={active!=="stock"} tabIndex={active==="stock"?0:-1}>
      <Section title="Stock et prix" icon="box">
        {select("ID_UniteFk","Unité"+(creating?" *":""),references?.articleUnits,!creating&&meta?.canChangeUnit===false)}
        {creating?input("QteArticle","Stock initial",{inputMode:"decimal",hint:"Un mouvement d’entrée est créé pour un stock initial positif."}):<Field name={prefix+"stock"} label="Stock actuel" hint="Les entrées et sorties se saisissent dans les bons de stock."><input id={prefix+"stock"} value={record.QteArticle??"—"} readOnly/></Field>}
        {input("PoidsUnitaire","Poids unitaire",{inputMode:"decimal"})}
        {select("ID_UnitePoidsFk","Unité de poids",references?.weightUnits)}
        {input("QteMinArticle","Seuil minimum",{inputMode:"decimal"})}
        {select("ID_DeviseFk","Devise *",currencyOptions(references).map(option=>({...option,id:option.value})),!creating&&meta?.canChangeCurrency===false)}
        {input("PUArticle","Prix d’achat *",{inputMode:"decimal"})}
        {input("PVArticle","Prix de vente *",{inputMode:"decimal"})}
      </Section>
      </section>
      <section role="tabpanel" id={prefix+"-panel-lots"} aria-labelledby={prefix+"-tab-lots"} hidden={active!=="lots"} tabIndex={active==="lots"?0:-1}>
        {creating?<div id={prefix+"initial-lots"} tabIndex={-1}><LotFields title="Lots du stock initial" value={initialLots} onChange={next=>{if(busy||!canWrite)return;setInitialLots(next);setLotsError("");}} total={values.QteArticle} disabled={busy||!canWrite} error={lotsError}/></div>:<section className="record-editor-section article-editor-lots"><h3><AppIcon name="box"/>Lots de l’article</h3><p>Les entrées et sorties par lot se saisissent dans les bons de stock.</p>{openProductLots?<ActionButton icon="eye" onClick={()=>openProductLots(record)} disabled={busy}>Consulter les lots</ActionButton>:null}</section>}
      </section>
      <section role="tabpanel" id={prefix+"-panel-conservation"} aria-labelledby={prefix+"-tab-conservation"} hidden={active!=="conservation"} tabIndex={active==="conservation"?0:-1}>
      <Section title="Conservation" icon="calendar">
        {input("DatePeremptionArticle","Péremption générale · stock sans lot",{type:"date"})}
        {input("NbreJoursAlerteArticle","Alerte avant péremption · jours",{inputMode:"numeric"})}
        <Field name={prefix+"alert"} label="Début de l’alerte" hint="Date générale seulement. Les lots utilisent leur propre date et ce même délai." wide><input id={prefix+"alert"} type="date" value={alertDate(values,record)} readOnly aria-describedby={prefix+"alert-hint"}/></Field>
      </Section>
      </section>
      <section role="tabpanel" id={prefix+"-panel-informations"} aria-labelledby={prefix+"-tab-informations"} hidden={active!=="informations"} tabIndex={active==="informations"?0:-1}>
      <Section title="Informations complémentaires" icon="document">
        <Field name={prefix+"InformationArticle"} label="Informations sur l’article" error={errors.InformationArticle} wide><textarea id={prefix+"InformationArticle"} name="InformationArticle" value={values.InformationArticle} aria-invalid={Boolean(errors.InformationArticle)} aria-describedby={errors.InformationArticle?prefix+"InformationArticle-error":undefined} disabled={busy||!canWrite} maxLength={20000} onChange={e=>change("InformationArticle",e.target.value)}/></Field>
        <Field name={prefix+"ObsArticle"} label="Observation" error={errors.ObsArticle} wide><textarea id={prefix+"ObsArticle"} name="ObsArticle" value={values.ObsArticle} aria-invalid={Boolean(errors.ObsArticle)} aria-describedby={errors.ObsArticle?prefix+"ObsArticle-error":undefined} disabled={busy||!canWrite} onChange={e=>change("ObsArticle",e.target.value)}/></Field>
      </Section>
      </section>
      <section role="tabpanel" id={prefix+"-panel-tracabilite"} aria-labelledby={prefix+"-tab-tracabilite"} hidden={active!=="tracabilite"} tabIndex={active==="tracabilite"?0:-1}>
      <Section title="Traçabilité" icon="user">
        {readOnly("ID_Article","Identifiant",creating?"Attribué à l’enregistrement":record?.ID_Article)}
        {readOnly("DateHeureAuto","Créé le",creating?"À l’enregistrement":record?.DateHeureAuto?formatDate(record.DateHeureAuto):"Non renseigné")}
        {readOnly("ID_UserFK","Responsable",owner,"Le responsable d’origine est conservé.")}
      </Section>
      </section>
    </div>:null}
  </RecordEditorFrame>;
}
