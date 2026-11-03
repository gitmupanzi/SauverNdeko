import useReferencesRefresh from "../../hooks/useReferencesRefresh";
import {REFERENCE_RETAINED_HINT,referenceLabel,referenceOptions,retainReference,isRetainedReference} from "../../utils/referenceOptions";
import {useEffect,useId,useMemo,useRef,useState} from "react";
import {useAuth} from "../../contexts/AuthContext";
import RecordEditorFrame from "../../components/RecordEditorFrame";
import SearchSelect from "../../components/SearchSelect";
import ActionButton from "../../components/ActionButton";
import AppIcon from "../../components/AppIcon";
import {requestJson} from "../../services/api";
import {formatCurrency,formatNumber,SimpleTable} from "./logistiqueShared";
import {createReceiptRequestId} from "./receiptForm";
import {invoiceDeadline,invoiceErrors,invoiceForm,invoicePayload} from "./invoiceForm";
import BusinessDocuments from "../../components/BusinessDocuments";
import InvoiceTaxSummary from "../../components/InvoiceTaxSummary";
import "./InvoiceEditor.css";

function Field({id,label,error,hint,children}) {return <div className="record-field"><label htmlFor={id}>{label}</label>{children}{error?<small id={id+"-error"} className="record-field-error">{error}</small>:hint?<small id={id+"-hint"}>{hint}</small>:null}</div>;}
export default function InvoiceEditor({commandeId,onClose,onSaved}) {
  const {user}=useAuth(),id=useId(),mounted=useRef(true),saving=useRef(false),request=useRef(null),baseline=useRef(null);
  const contextKey=String(user?.IdUser??"")+":"+String(user?.IdEntiteFk??""),initialContext=useRef(contextKey);
  const [record,setRecord]=useState(null),[meta,setMeta]=useState(null),[values,setValues]=useState({DateFacture:"",ID_ModePaiementFk:"",ID_ConditionPaiementFk:"",DateEcheancePaiement:""}),[loading,setLoading]=useState(true),[busy,setBusy]=useState(false),[error,setError]=useState(""),[issues,setIssues]=useState({}),[revision,setRevision]=useState(0),[uncertain,setUncertain]=useState(false),[closeWarning,setCloseWarning]=useState(false),[reloadWarning,setReloadWarning]=useState(false);
  const canWrite=user?.permissions?.canWriteData===true&&contextKey===initialContext.current,existing=Boolean(record?.facture),editable=canWrite&&meta?.available===true&&(existing?meta?.canEdit===true:meta?.canIssue===true),disabled=loading||busy||uncertain||!editable;
  const dirty=baseline.current!=null&&JSON.stringify(values)!==JSON.stringify(baseline.current),refs=record?.references||{},condition=(refs.conditionsPaiement||[]).find(row=>String(row.id)===values.ID_ConditionPaiementFk),automatic=invoiceDeadline(values.DateFacture,condition),code=(existing?record?.facture?.DeviseCode:record?.totaux?.DeviseCode)||record?.bonOrigine?.DeviseCode;
  useEffect(()=>{mounted.current=true;return()=>{mounted.current=false;};},[]);
  useEffect(()=>{if(contextKey!==initialContext.current)onClose();},[contextKey,onClose]);
  useEffect(()=>{
    let live=true;setLoading(true);setError("");setIssues({});setUncertain(false);setCloseWarning(false);setReloadWarning(false);request.current=null;
    requestJson("/api/logistique/commandes/"+commandeId+"/facture",{requiresAuth:true}).then(response=>{
      if(!live)return;
      if(!response?.success){setRecord(null);setMeta(null);setError(response?.message||"La facture n’a pas pu être chargée.");setLoading(false);return;}
      const next=invoiceForm(response.data);baseline.current=next;setValues(next);setRecord(response.data);setMeta(response.meta||{});setLoading(false);
    });return()=>{live=false;};
  },[commandeId,revision]);
  useReferencesRefresh(async()=>{if(disabled||!record)return;const response=await requestJson("/api/logistique/commandes/"+commandeId+"/facture",{requiresAuth:true});if(mounted.current&&response?.success)setRecord(previous=>previous?{...previous,references:response.data?.references||{}}:previous);},{enabled:!disabled&&Boolean(record)});
  function change(name,value){
    if(disabled)return;
    setValues(current=>{
      const next={...current,[name]:value};
      if(name==="ID_ConditionPaiementFk"||name==="DateFacture"){
        const selected=(refs.conditionsPaiement||[]).find(row=>String(row.id)===next.ID_ConditionPaiementFk),deadline=invoiceDeadline(next.DateFacture,selected);
        if(deadline)next.DateEcheancePaiement=deadline;else if(name==="ID_ConditionPaiementFk")next.DateEcheancePaiement="";
      }
      return next;
    });setIssues(current=>({...current,[name]:"",...(["ID_ConditionPaiementFk","DateFacture"].includes(name)?{DateEcheancePaiement:""}:{})}));
  }
  function dateField(name,label,{readOnly=false,hint}={}){const fieldId=id+name,invalid=issues[name];return <Field id={fieldId} label={label} error={invalid} hint={hint}><input id={fieldId} type="datetime-local" step="1" value={values[name]} onChange={event=>change(name,event.target.value)} readOnly={readOnly} disabled={disabled} aria-invalid={Boolean(invalid)} aria-describedby={invalid?fieldId+"-error":hint?fieldId+"-hint":undefined}/></Field>;}
  function selector(name,label,items){const fieldId=id+name,invalid=issues[name],options=retainReference(referenceOptions(items||[]),values[name],referenceLabel({ID_Generique:values[name]}));return <Field id={fieldId} label={label} error={invalid} hint={isRetainedReference(options,values[name])?REFERENCE_RETAINED_HINT:undefined}><SearchSelect id={fieldId} label={label} value={values[name]} options={[{value:"",label:"Choisir"},...options]} onChange={value=>change(name,value)} disabled={disabled} invalid={Boolean(invalid)} describedBy={invalid?fieldId+"-error":undefined}/></Field>;}

  function requestClose(){if(busy)return;if(uncertain){setCloseWarning(true);return;}onClose();}
  function reload(){if(busy||uncertain)return;if(dirty){setReloadWarning(true);return;}setRevision(value=>value+1);}
  async function submit(){
    if(saving.current||!editable)return;
    let snapshot=request.current;
    if(!uncertain){
      const invalid=invoiceErrors(values,refs,existing?baseline.current:null);setIssues(invalid);setError("");
      if(Object.keys(invalid).length){setError("Vérifiez les champs indiqués.");requestAnimationFrame(()=>document.getElementById(id+Object.keys(invalid)[0])?.focus());return;}
      const payload=invoicePayload(values,meta.revision,""),fingerprint=JSON.stringify({method:existing?"PUT":"POST",payload});
      if(!snapshot||snapshot.fingerprint!==fingerprint){snapshot={fingerprint,method:existing?"PUT":"POST",payload:{...payload,requestId:createReceiptRequestId()}};request.current=snapshot;}
    }
    if(!snapshot)return;
    saving.current=true;setBusy(true);setError("");setCloseWarning(false);
    const response=await requestJson("/api/logistique/commandes/"+commandeId+"/facture",{requiresAuth:true,method:snapshot.method,body:JSON.stringify(snapshot.payload)});
    if(!mounted.current)return;saving.current=false;setBusy(false);
    if(!response?.success||!response.data?.facture){
      if(!response||!response.status||response.status>=500||response.success===true){setUncertain(true);setError("La réponse du serveur n’est pas parvenue. Réessayez sans modifier la facture.");return;}
      setUncertain(false);const details=response.error?.details,invalid={};
      if(details&&typeof details==="object"&&!Array.isArray(details))for(const [key,message] of Object.entries(details)){const field=key.replace(/^facture\./,"");if(field in values)invalid[field]=String(message);}
      setIssues(invalid);setError(response.message||"La facture n’a pas pu être enregistrée.");return;
    }
    onSaved(response.data.bonOrigine,existing?"updated":"created");
  }
  const columns=useMemo(()=>[
    {key:"NomArticle",label:"Article",width:240,render:row=><span className="invoice-product"><strong>{row.NomArticle||"Article"}</strong>{row.CodeArticleInterne?<small>{row.CodeArticleInterne}</small>:null}</span>},
    {key:"QteSortie",label:"Sortie",width:120,align:"right",render:row=>formatNumber(row.QteSortie)+(row.Unite?" "+row.Unite:"")},
    {key:"QteRetourAvantFacture",label:"Restituée",width:120,align:"right",render:row=>formatNumber(row.QteRetourAvantFacture)},
    {key:"QteFacturee",label:"Facturée",width:120,align:"right",render:row=>formatNumber(row.QteFacturee)},
    {key:"PUFacture",label:"Prix unitaire HT",width:150,align:"right",render:row=>formatCurrency(row.PUFacture,row.DeviseCode||code)},
    {key:"MontantLigneHT",label:"Montant HT",width:160,align:"right",render:row=>formatCurrency(row.MontantLigneHT??row.MontantLigne,row.DeviseCode||code)},
    {key:"MontantTVA",label:"TVA",width:140,align:"right",render:row=>formatCurrency(row.MontantTVA,row.DeviseCode||code)},
    {key:"MontantTTC",label:"Montant TTC",width:160,align:"right",render:row=>formatCurrency(row.MontantTTC,row.DeviseCode||code)},
  ],[code]);
  const total=existing?record?.facture?.MontantTTC??record?.facture?.MontantFacture:record?.totaux?.MontantTTC??record?.totaux?.MontantFacture;
  return <RecordEditorFrame title={existing?"Facture · "+record.facture.CodeFacture:"Créer la facture"} subtitle={record?.bonOrigine?.CodeCmd||"Facturation du bon de sortie"} icon="document" defaultWidth={980} storageKey="sauverndeko.invoice-editor.width" className="invoice-editor-dialog" onClose={requestClose} onSubmit={submit} loading={loading} busy={busy} dirty={!uncertain&&dirty} canSubmit={editable&&(!existing||dirty||uncertain)} submitLabel={uncertain?"Réessayer":existing?"Enregistrer les modifications":"Créer la facture"} error={error} onReload={!loading&&!uncertain&&(!record||Boolean(error))?reload:null}>
    {closeWarning?<div className="record-editor-error" role="alert"><span>La facture a peut-être été enregistrée. Réessayez pour vérifier avant de fermer.</span><div className="invoice-inline-actions"><ActionButton disabled={!editable||busy} onClick={submit}>Réessayer</ActionButton><ActionButton onClick={onClose}>Fermer la fenêtre</ActionButton></div></div>:null}
    {reloadWarning?<div className="record-editor-error" role="alert"><span>Recharger la facture et abandonner la saisie ?</span><div className="invoice-inline-actions"><ActionButton onClick={()=>setReloadWarning(false)}>Continuer</ActionButton><ActionButton icon="refresh" onClick={()=>setRevision(value=>value+1)}>Recharger</ActionButton></div></div>:null}
    {record?<div className="invoice-editor">
      {!editable&&meta?.reason?<div className="record-editor-note" role="status">{meta.reason}</div>:null}
      <section className="record-editor-section"><h3><AppIcon name="document"/>Facturation</h3><div className="invoice-editor-summary"><div><span>Bon de stock</span><strong>{record.bonOrigine?.CodeCmd||"Bon sans code"}</strong></div><div><span>Facture</span><strong>{record.facture?.CodeFacture||"Attribué à l’émission"}</strong></div><div><span>Montant de la facture</span><strong>{formatCurrency(total,code)}</strong></div></div><div className="record-editor-grid">
        {dateField("DateFacture","Date et heure de facture *",{hint:"Heure de Kinshasa."})}
        {selector("ID_ModePaiementFk","Mode de paiement *",refs.modesPaiement)}
        {selector("ID_ConditionPaiementFk","Condition de paiement *",refs.conditionsPaiement)}
        {dateField("DateEcheancePaiement","Échéance de paiement *",{readOnly:automatic!==null,hint:automatic!==null?"Calculée selon le délai de la condition de paiement.":"Renseignez l’échéance convenue."})}
      </div></section>
      <InvoiceTaxSummary record={existing?record.facture:record.totaux} currency={code}/>
      <section className="record-editor-section"><h3><AppIcon name="box"/>Articles facturés</h3><p className="record-editor-note">Quantités restantes après les restitutions enregistrées avant l’émission. Les prix unitaires sont hors taxes.</p><div className="erp-results" data-density="compact"><SimpleTable rows={record.lignes||[]} columns={columns} defaultPinnedColumns={[]} showControls={false} toolbar={<></>} emptyMessage="Aucun article à facturer."/></div></section>
      {existing?<BusinessDocuments kind="facture" objectId={commandeId} types={["facture"]}/>:null}
      {record.retoursApresEmission?.required?<section className="record-editor-section invoice-credit-note"><h3><AppIcon name="alert"/>Avoir à établir</h3><p>Des articles ont été restitués après l’émission. La facture reste inchangée.</p>{record.retoursApresEmission.MontantAvoir!=null?<strong>{formatCurrency(record.retoursApresEmission.MontantAvoir,record.retoursApresEmission.DeviseCode)}</strong>:null}</section>:null}
    </div>:null}
  </RecordEditorFrame>;
}
