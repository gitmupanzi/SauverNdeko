import {fieldCurrencyReferences} from "../../utils/money";
import {REFERENCE_RETAINED_HINT,isRetainedReference,referenceOptions,retainReference} from "../../utils/referenceOptions";
import {useEntityScope} from "../../contexts/EntityScopeContext";
import {useDepotScope,DepotField} from "../../contexts/DepotScopeContext";
import TiersSelect from "../../components/TiersSelect";
import {useEffect,useId,useRef,useState} from "react";
import {useAuth} from "../../contexts/AuthContext";
import useReferencesRefresh from "../../hooks/useReferencesRefresh";
import RecordEditorFrame from "../../components/RecordEditorFrame";
import SearchSelect from "../../components/SearchSelect";
import LotFields,{lotErrors} from "../../components/LotFields";
import AppIcon from "../../components/AppIcon";
import {fetchArticleReception,receiveArticleStock} from "../../services/logistique";
import {roundMoney} from "../../utils/quantities";
import {compareDecimal,currencyOptions,formatCurrency,multiplyDecimal} from "../../utils/money";
import {formatNumber} from "./logistiqueShared";
import {createReceiptRequestId,receiptForm,receiptErrors,receiptPayload} from "./receiptForm";

function Field({id,label,error,hint,wide=false,children}) {
  return <div className={"record-field"+(wide?" is-wide":"")}><label htmlFor={id}>{label}</label>{children}{error?<small className="record-field-error" id={id+"-error"}>{error}</small>:hint?<small id={id+"-hint"}>{hint}</small>:null}</div>;
}
export default function StockReceiptEditor({articleId,references,onClose,onSaved}) {
  const depot=useDepotScope(),entityScope=useEntityScope(),initialContext=useRef(entityScope.scopeKey),ticket=useRef(null);
  const [uncertain,setUncertain]=useState(false);
  const {user}=useAuth(),prefix=useId(),quantityRef=useRef(null),mounted=useRef(true),saving=useRef(false);

  const [data,setData]=useState(null),[values,setValues]=useState(()=>receiptForm(null)),[initial,setInitial]=useState("");
  const [lots,setLots]=useState([]),[errors,setErrors]=useState({}),[lotsError,setLotsError]=useState("");
  const [typeRefreshError,setTypeRefreshError]=useState("");
  const typeRequest=useRef(0),latestValues=useRef(values);latestValues.current=values;
  const [loading,setLoading]=useState(true),[busy,setBusy]=useState(false),[error,setError]=useState(""),[reload,setReload]=useState(0);
  const receiptReferences=data?.currencies?{...references,currencies:data.currencies}:fieldCurrencyReferences(references,"commandeCurrencies");
  const article=data?.article,options=retainReference(currencyOptions(receiptReferences),values.ID_DeviseFk,"Devise sélectionnée"),currency=receiptReferences?.currencies?.find(item=>String(item.id)===values.ID_DeviseFk);
  const typeOptions=retainReference(referenceOptions(data?.types||[]),values.ID_TypeCmdFk,data?.type?.label||"Type sélectionné");
  const canWrite=entityScope.canWrite&&initialContext.current===entityScope.scopeKey&&user?.permissions?.canWriteData===true,dirty=Boolean(initial)&&(JSON.stringify(values)!==initial||lots.length>0);
  useEffect(()=>{mounted.current=true;return()=>{mounted.current=false;};},[]);
  useEffect(()=>{
    let active=true;setLoading(true);setError("");
    fetchArticleReception(articleId,{depotId:latestValues.current.ID_DepotFk||depot.depotId||depot.defaultDepotId}).then(response=>{
      if(!active)return;
      if(!response?.success){setData(null);setError(response?.message||"La réception n’a pas pu être préparée.");setLoading(false);return;}
      const form={...receiptForm(response.data),ID_DepotFk:String(latestValues.current.ID_DepotFk||depot.depotId||response.data?.defaults?.ID_DepotFk||depot.defaultDepotId||"")};setData(response.data);setValues(form);setInitial(JSON.stringify(form));setLots([]);setErrors({});setLotsError("");setLoading(false);
    });
    return()=>{active=false;};
  },[articleId,reload]);
  useEffect(()=>{
    if(loading||!values.ID_DepotFk)return;
    let active=true;setData(current=>current?{...current,article:{...current.article,StockDepot:null,QteArticle:null}}:current);
    fetchArticleReception(articleId,{depotId:values.ID_DepotFk}).then(response=>{
      if(!active)return;
      if(response?.success)setData(current=>current?{...current,article:response.data.article}:current);
      else setError(response?.message||"Le stock du dépôt n’a pas pu être actualisé.");
    });return()=>{active=false;};
  },[articleId,values.ID_DepotFk,loading]);
  useEffect(()=>{if(loading||!article)return;const frame=requestAnimationFrame(()=>quantityRef.current?.focus({preventScroll:true}));return()=>cancelAnimationFrame(frame);},[loading,articleId]);
  useReferencesRefresh(async()=>{
    const request=++typeRequest.current;
    const response=await fetchArticleReception(articleId,{depotId:latestValues.current.ID_DepotFk||depot.depotId||depot.defaultDepotId});
    if(!mounted.current||request!==typeRequest.current)return;
    if(!response?.success){
      if(response?.error?.code==="RECEIPT_CONFIGURATION")setData(current=>current?{...current,types:[],canReceive:false}:current);
      setTypeRefreshError(response?.message||"La liste des types n’a pas pu être actualisée.");return;
    }
    setTypeRefreshError("");
    const nextTypes=response.data.types||[],selected=latestValues.current.ID_TypeCmdFk;
    setData(current=>current?{...current,types:nextTypes,type:response.data.type,currencies:response.data.currencies,canReceive:response.data.canReceive,currencyToConfirm:response.data.currencyToConfirm,priceToConfirm:response.data.priceToConfirm}:current);
    if(selected)setErrors(current=>({...current,ID_TypeCmdFk:nextTypes.some(type=>String(type.id)===selected)?"":"Ce type n’est plus disponible. Choisissez un type de bon d’entrée."}));
  },{enabled:Boolean(article)&&!loading&&!busy});
  function change(name,value){if(busy||uncertain)return;ticket.current=null;setValues(current=>({...current,[name]:value}));setErrors(current=>({...current,[name]:""}));}
  function changeCurrency(value){if(busy||uncertain)return;ticket.current=null;if(value===values.ID_DeviseFk)return;setValues(current=>({...current,ID_DeviseFk:value,PUCmdDetail:""}));setErrors(current=>({...current,ID_DeviseFk:"",PUCmdDetail:""}));}
  function focusInvalid(invalid){requestAnimationFrame(()=>{const form=quantityRef.current?.form;const key=Object.keys(invalid)[0];const field=form&&Array.from(form.elements).find(element=>element.id===prefix+key);(field||form?.querySelector('[aria-label="Numéro du lot 1"]'))?.focus();});}
  function input(name,label,{hint,wide=false,type="text",...attributes}={}){
    const id=prefix+name;
    return <Field id={id} label={label} error={errors[name]} hint={hint} wide={wide}><input id={id} name={name} ref={name==="QteCmdDetail"?quantityRef:null} value={values[name]} onChange={event=>change(name,event.target.value)} type={type} disabled={busy||uncertain} aria-invalid={Boolean(errors[name])} aria-describedby={errors[name]?id+"-error":hint?id+"-hint":undefined} {...attributes}/></Field>;
  }
  async function submit(){
    if(saving.current||!canWrite||!article)return;
    if(!uncertain){const invalid={...receiptErrors(values,typeOptions.filter(option=>!option.disabled).map(option=>option.value)),...(!values.ID_DepotFk?{ID_DepotFk:"Choisissez le dépôt de réception."}:{})},lotError=lotErrors(lots,values.QteCmdDetail);if(!options.some(option=>option.value===values.ID_DeviseFk&&!option.disabled))invalid.ID_DeviseFk="Choisissez une devise disponible pour ce bon.";setErrors(invalid);setLotsError(lotError);setError("");
    if(Object.keys(invalid).length||lotError){setError("Vérifiez les champs indiqués.");focusInvalid(invalid);return;}
    ticket.current={...receiptPayload(values,lots),requestId:createReceiptRequestId()};}
    if(!ticket.current)return;
    saving.current=true;setBusy(true);
    const response=await receiveArticleStock(articleId,ticket.current);
    if(!mounted.current)return;
    saving.current=false;setBusy(false);
    if(!response?.success){const pending=!response?.status||response.status>=500;setUncertain(pending);if(!pending)ticket.current=null;
      const details=response?.error?.details;
      const invalid=details&&typeof details==="object"&&!Array.isArray(details)?Object.fromEntries(Object.entries(details).filter(([key])=>key in values).map(([key,value])=>[key,String(value)])):{};
      setErrors(invalid);setError(Object.keys(invalid).length?"Vérifiez les champs indiqués.":response?.message||"La réception n’a pas pu être enregistrée.");
      if(Object.keys(invalid).length)focusInvalid(invalid);return;
    }
    onSaved(response.data);
  }
  const catalogPrice=String(article?.ID_DeviseFk)===values.ID_DeviseFk&&compareDecimal(values.PUCmdDetail,article?.PUArticle)===0;
  const priceHint=!values.PUCmdDetail.trim()?"Saisissez le prix d’achat dans la devise du bon.":catalogPrice?"Prix d’achat proposé depuis la fiche article. À ajuster selon la livraison.":"Prix d’achat propre à cette réception.";
  return <RecordEditorFrame title="Réceptionner du stock" subtitle={article?.NomArticle||"Bon d’entrée"} icon="stock-in" onClose={onClose} onSubmit={submit} submitLabel={uncertain?"Réessayer":"Enregistrer la réception"} busy={busy} loading={loading} dirty={dirty&&!uncertain} canSubmit={canWrite&&Boolean(article)&&article.ValideArticle!==false&&data?.canReceive!==false&&options.length>0&&typeOptions.length>0} error={error} onReload={!article&&!loading?()=>setReload(value=>value+1):null} discardMessage={uncertain?"Le résultat reste à vérifier. Fermer ne revient pas sur une réception éventuellement enregistrée.":undefined} discardLabel={uncertain?"Fermer la réception":undefined} storageKey="sauverndeko.stock-receipt.width">
    {!loading&&article?<>
      {data.canReceive===false?<p className="record-editor-note" role="status">Cette installation est en consultation seule.</p>:null}
      <div className="record-editor-identity"><AppIcon name="box"/><div><strong>{article.NomArticle}</strong><small>{[article.CodeArticleInterne||article.RefArticle,"Stock du dépôt : "+formatNumber(article.StockDepot??article.QteArticle)+(article.Unite?" "+article.Unite:"")].filter(Boolean).join(" · ")}</small></div></div>
      <section className="record-editor-section"><h3><AppIcon name="receipt"/>Bon d’entrée</h3><div className="record-editor-grid"><DepotField id={prefix+"ID_DepotFk"} value={values.ID_DepotFk} error={errors.ID_DepotFk} disabled={busy||uncertain} onChange={value=>change("ID_DepotFk",value)}/>
        <Field id={prefix+"ID_TypeCmdFk"} label="Type de bon *" error={errors.ID_TypeCmdFk||typeRefreshError} hint={isRetainedReference(typeOptions,values.ID_TypeCmdFk)?REFERENCE_RETAINED_HINT:!typeOptions.length?"Aucun type de bon d’entrée disponible.":""}><SearchSelect id={prefix+"ID_TypeCmdFk"} label="Type de bon" value={values.ID_TypeCmdFk} options={typeOptions} onChange={value=>change("ID_TypeCmdFk",value)} disabled={busy||uncertain||!typeOptions.length} invalid={Boolean(errors.ID_TypeCmdFk||typeRefreshError)} describedBy={errors.ID_TypeCmdFk||typeRefreshError?prefix+"ID_TypeCmdFk-error":!typeOptions.length?prefix+"ID_TypeCmdFk-hint":undefined}/></Field>
        {input("DateCmd","Date et heure du bon *",{type:"datetime-local",step:60,hint:data.timeZone?"Heure de "+data.timeZone.split("/").at(-1).replace(/_/g," "):""})}
        {input("RefCmd","Référence du bon de livraison",{maxLength:255,autoComplete:"off"})}
        <Field id={prefix+"ID_TiersFk"} label="Tiers référencé" error={errors.ID_TiersFk}><TiersSelect id={prefix+"ID_TiersFk"} value={values.ID_TiersFk} references={references?.clients||[]} role="fournisseur" disabled={busy||uncertain} invalid={Boolean(errors.ID_TiersFk)} onChange={(id,name)=>{change("ID_TiersFk",id);if(name)change("NomClientSaisi",name);}}/></Field>
        {input("NomClientSaisi","Nom du fournisseur",{maxLength:255,autoComplete:"off"})}
      </div></section>
      <section className="record-editor-section"><h3><AppIcon name="stock-in"/>Quantité et prix d’achat</h3><div className="record-editor-grid">
        {data.currencyToConfirm?<p className="record-field record-editor-note is-wide">Choisissez la devise du bon et renseignez le prix d’achat correspondant.</p>:null}
        {input("QteCmdDetail","Quantité reçue *",{inputMode:"decimal",maxLength:15,autoComplete:"off"})}
        <Field id={prefix+"unit"} label="Unité"><input id={prefix+"unit"} value={article.Unite||"Non renseignée"} readOnly/></Field>
        <Field id={prefix+"ID_DeviseFk"} label="Devise du bon *" error={errors.ID_DeviseFk} hint={isRetainedReference(options,values.ID_DeviseFk)?REFERENCE_RETAINED_HINT:!options.length?"Aucune devise disponible. Vérifiez les références.":""}><SearchSelect id={prefix+"ID_DeviseFk"} label="Devise du bon" value={values.ID_DeviseFk} options={options} onChange={changeCurrency} disabled={busy||uncertain||!options.length} invalid={Boolean(errors.ID_DeviseFk)} describedBy={errors.ID_DeviseFk?prefix+"ID_DeviseFk-error":undefined}/></Field>
        {input("PUCmdDetail","Prix d’achat unitaire *",{inputMode:"decimal",maxLength:13,hint:priceHint,autoComplete:"off"})}
        <Field id={prefix+"amount"} label="Montant de la réception" wide><output id={prefix+"amount"} className="stock-receipt-total">{formatCurrency(roundMoney(multiplyDecimal(values.QteCmdDetail,values.PUCmdDetail)),currency?.code)}</output></Field>
      </div></section>
      <LotFields value={lots} onChange={next=>{if(busy||uncertain)return;ticket.current=null;setLots(next);setLotsError("");}} total={values.QteCmdDetail} disabled={busy||uncertain} title="Lots reçus" error={lotsError}/>
      <section className="record-editor-section"><h3><AppIcon name="document"/>Observation</h3><div className="record-editor-grid"><Field id={prefix+"ObsCmd"} label="Observation du bon" error={errors.ObsCmd} wide><textarea id={prefix+"ObsCmd"} name="ObsCmd" value={values.ObsCmd} onChange={event=>change("ObsCmd",event.target.value)} disabled={busy||uncertain} maxLength={255}/></Field></div></section>
    </>:null}
  </RecordEditorFrame>;
}
