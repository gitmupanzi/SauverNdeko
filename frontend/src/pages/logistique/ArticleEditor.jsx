import { newCurrencyId, currencyOptions } from "../../utils/money";
import SearchSelect from "../../components/SearchSelect";
import LotFields, {lotErrors} from "../../components/LotFields";
import ProductPhotoPicker from "../../components/ProductPhotoPicker";
import {useEffect,useId,useRef,useState} from "react";
import {useAuth} from "../../contexts/AuthContext";
import RecordEditorFrame from "../../components/RecordEditorFrame";
import AppIcon from "../../components/AppIcon";
import {fetchLogistiqueArticle,createLogistiqueArticle,updateLogistiqueArticle} from "../../services/logistique";
import {buildReferenceOptions,formatDate} from "./logistiqueShared";
import {articleForm,articleErrors,articlePayload,alertDate} from "./articleForm";

function Field({name,label,error,hint,wide=false,children}) {
  return <div className={"record-field"+(wide?" is-wide":"")}><label htmlFor={name}>{label}</label>{children}{error?<small className="record-field-error" id={name+"-error"}>{error}</small>:hint?<small id={name+"-hint"}>{hint}</small>:null}</div>;
}
function Section({icon,title,children}) {return <section className="record-editor-section"><h3><AppIcon name={icon}/>{title}</h3><div className="record-editor-grid">{children}</div></section>;}
export default function ArticleEditor({articleId,onClose,onSaved,references}) {
  const {user}=useAuth(),creating=!articleId;
  const prefix=useId(),mounted=useRef(true),saving=useRef(false),focusRef=useRef(null);
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
  function change(name,value){setValues(current=>({...current,[name]:value}));setErrors(current=>({...current,[name]:""}));}
  function focusInvalid(fields){
    requestAnimationFrame(()=>{
      const form=focusRef.current?.form,name=Object.keys(fields)[0];
      const field=form&&Array.from(form.elements).find(element=>element.id===prefix+name||element.name===name);
      field?.focus();
    });
  }
  function input(name,label,options={}){
    const {hint,wide,type="text",...attributes}=options,id=prefix+name;
    return <Field name={id} label={label} wide={wide} error={errors[name]} hint={hint}><input id={id} name={name} ref={name==="NomArticle"?focusRef:null} type={type} value={values[name]??""} onChange={e=>change(name,e.target.value)} disabled={busy} aria-invalid={Boolean(errors[name])} aria-describedby={errors[name]?id+"-error":hint?id+"-hint":undefined} {...attributes}/></Field>;
  }
  function select(name,label,source,locked=false){
    const id=prefix+name,options=buildReferenceOptions(source,label),known=options.some(x=>String(x.value)===String(values[name]));
    const choices=!known&&values[name]?[{value:values[name],label:record?.[{ID_TypeArticleFk:"TypeArticle",ID_CategorieArticleFk:"CategorieArticle",ID_UniteFk:"Unite",ID_UnitePoidsFk:"UnitePoids",ID_DeviseFk:"DeviseCode"}[name]]||"Valeur actuelle"},...options]:options;
    const hint=locked?(name==="ID_DeviseFk"?"La devise est conservée après une opération de stock.":"L’unité est conservée après le premier mouvement."):!options.length?"Aucune valeur disponible. Vérifiez les références.":"";
    return <Field name={id} label={label} error={errors[name]} hint={hint}><SearchSelect id={id} label={label} value={values[name]} options={name==="ID_UnitePoidsFk"?[{value:"",label:"Non renseignée"},...choices]:choices} onChange={next=>change(name,next)} disabled={busy||locked||!options.length} invalid={Boolean(errors[name])} describedBy={errors[name]?id+"-error":hint?id+"-hint":undefined}/></Field>;
  }
  function readOnly(name,label,value,hint="") {
    const id=prefix+name;
    return <Field name={id} label={label} hint={hint}><input id={id} value={value==null||value===""?"Non renseigné":String(value)} readOnly aria-describedby={hint?id+"-hint":undefined}/></Field>;
  }
  const ownerId=creating?user?.IdUser:(record?.ID_UserFK ?? record?.IdUser);
  const ownerName=creating?[user?.PrenomUser,user?.NomUser].filter(Boolean).join(" "):record?.NomComplet || references?.users?.find(item=>String(item.id)===String(ownerId))?.label;
  const owner=ownerName?ownerName+(ownerId!=null?" · #"+ownerId:""):ownerId!=null?"Utilisateur #"+ownerId:"Non renseigné";
  async function submit(){
    if(saving.current||!canWrite||(!creating&&!meta?.revision))return;
    const invalid=articleErrors(values,creating);
    const lotError=creating?lotErrors(initialLots,values.QteArticle):"";setLotsError(lotError);if(lotError)return;setErrors(invalid);setError("");setConflict(false);
    if(Object.keys(invalid).length){setError("Vérifiez les champs indiqués.");focusInvalid(invalid);return;}
    saving.current=true;setBusy(true);
    const payload=articlePayload(values,record,meta?.revision);
    delete payload.PhotoArticle;
    if(creating&&initialLots.length)payload.LotsInitiaux=initialLots;
    if(photo.remove)payload._removePhoto=true;
    const response=creating?await createLogistiqueArticle(payload,photo.file):await updateLogistiqueArticle(articleId,payload,photo.file);
    if(!mounted.current)return;
    saving.current=false;setBusy(false);
    if(!response?.success){
      const details=response?.error?.details;
      const fieldErrors=details&&typeof details==="object"&&!Array.isArray(details)?Object.fromEntries(Object.entries(details).filter(([key])=>key in values||key==="photo").map(([key,value])=>[key,String(value)])):{};
      setErrors(fieldErrors);
      setError(Object.keys(fieldErrors).length?"Vérifiez les champs indiqués.":response?.message||"L’article n’a pas pu être enregistré.");
      setConflict(response?.error?.code==="ARTICLE_CONFLICT");
      if(Object.keys(fieldErrors).length)focusInvalid(fieldErrors);
      return;
    }
    onSaved(response.data,creating?"created":"updated");
  }
  return <RecordEditorFrame title={creating?"Nouvel article":"Modifier l’article"} subtitle={record?.NomArticle||"Identité, stock et prix"} icon="box" onClose={onClose} onSubmit={submit} busy={busy} loading={loading} dirty={dirty} canSubmit={canWrite&&(creating||Boolean(record&&meta?.revision))&&(creating||dirty)} error={error} onReload={!creating&&(conflict||(!record&&!loading))?()=>setReload(x=>x+1):null} storageKey="sauverndeko.article-editor.width">
    {!loading&&(creating||record)?<>
      <ProductPhotoPicker record={record} value={photo} onChange={setPhoto} disabled={busy} error={errors.photo}/>
      {!creating?<div className="record-editor-identity"><AppIcon name="box"/><div><strong>{record.NomArticle}</strong><small>{record.CodeArticleInterne||record.RefArticle||"Code non renseigné"}</small></div></div>:null}
      <Section title="Identification" icon="tag">
        {input("NomArticle","Nom de l’article *",{maxLength:100,autoComplete:"off",wide:true})}
        {input("CodeArticleInterne","Code interne",{maxLength:243})}
        {input("CodeArticleExterne","Code externe",{inputMode:"numeric",maxLength:10})}
        {input("RefArticle","Référence",{maxLength:255,wide:true})}
        {select("ID_CategorieArticleFk","Catégorie"+(creating?" *":""),references?.articleCategories)}
        {select("ID_TypeArticleFk","Type"+(creating?" *":""),references?.articleTypes)}
      </Section>
      <Section title="Stock et prix" icon="box">
        {select("ID_UniteFk","Unité"+(creating?" *":""),references?.articleUnits,!creating&&meta?.canChangeUnit===false)}
        {creating?input("QteArticle","Stock initial",{inputMode:"numeric",hint:"Un mouvement d’entrée est créé pour un stock initial positif."}):<Field name={prefix+"stock"} label="Stock actuel" hint="Les entrées et sorties se saisissent dans les bons de stock."><input id={prefix+"stock"} value={record.QteArticle??"—"} readOnly/></Field>}
        {input("PoidsUnitaire","Poids unitaire",{inputMode:"decimal"})}
        {select("ID_UnitePoidsFk","Unité de poids",references?.weightUnits)}
        {input("QteMinArticle","Seuil minimum",{inputMode:"numeric"})}
        {select("ID_DeviseFk","Devise *",currencyOptions(references).map(option=>({id:option.value,label:option.label})),!creating&&meta?.canChangeCurrency===false)}
        {input("PUArticle","Prix d’achat *",{inputMode:"decimal"})}
        {input("PVArticle","Prix de vente *",{inputMode:"decimal"})}
      </Section>
      {creating?<LotFields title="Lots du stock initial" value={initialLots} onChange={setInitialLots} total={values.QteArticle} disabled={busy} error={lotsError}/>:null}
      <Section title="Conservation" icon="calendar">
        {input("DatePeremptionArticle","Date de péremption",{type:"date"})}
        {input("NbreJoursAlerteArticle","Alerte avant péremption (jours)",{inputMode:"numeric"})}
        <Field name={prefix+"alert"} label="Début de l’alerte" hint="Calculé à partir de la péremption et du délai d’alerte." wide><input id={prefix+"alert"} type="date" value={alertDate(values,record)} readOnly aria-describedby={prefix+"alert-hint"}/></Field>
      </Section>
      <Section title="Informations complémentaires" icon="document">
        <Field name={prefix+"InformationArticle"} label="Informations sur l’article" wide><textarea id={prefix+"InformationArticle"} name="InformationArticle" value={values.InformationArticle} disabled={busy} maxLength={20000} onChange={e=>change("InformationArticle",e.target.value)}/></Field>
        <Field name={prefix+"ObsArticle"} label="Observation" wide><textarea id={prefix+"ObsArticle"} name="ObsArticle" value={values.ObsArticle} disabled={busy} onChange={e=>change("ObsArticle",e.target.value)}/></Field>
      </Section>
      <Section title="Suivi de l’article" icon="document">
        {readOnly("ID_Article","Identifiant",creating?"Attribué à l’enregistrement":record?.ID_Article)}
        {readOnly("DateHeureAuto","Créé le",creating?"À l’enregistrement":record?.DateHeureAuto?formatDate(record.DateHeureAuto):"Non renseigné")}
        {readOnly("ID_UserFK","Responsable",owner,"Le responsable d’origine est conservé.")}
        <div className="record-field"><span>État de l’article</span><label className="record-editor-check" htmlFor={prefix+"ValideArticle"}><input id={prefix+"ValideArticle"} name="ValideArticle" type="checkbox" checked={values.ValideArticle===true} onChange={event=>change("ValideArticle",event.target.checked)} disabled={busy}/>Article actif</label></div>
      </Section>
    </>:null}
  </RecordEditorFrame>;
}
