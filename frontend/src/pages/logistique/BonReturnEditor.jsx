import {useEffect,useId,useRef,useState} from "react";
import {useAuth} from "../../contexts/AuthContext";
import RecordEditorFrame from "../../components/RecordEditorFrame";
import ActionButton from "../../components/ActionButton";
import AppIcon from "../../components/AppIcon";
import {requestJson} from "../../services/api";
import {quantityUnits} from "../../utils/quantities";
import {formatCurrency} from "../../utils/money";
import {formatDate,formatNumber,SimpleTable} from "./logistiqueShared";
import {createReceiptRequestId} from "./receiptForm";
import {allRemainingReturns,returnHeader,returnHeaderErrors,returnQuantity,restitutionLineErrors,restitutionPayload,restitutionSelection,restitutionTotal} from "./stockReturnForm";
import "../../components/DataTable.css";
import "./BonReturnEditor.css";

function Field({id,label,error,children}){return <div className="record-field"><label htmlFor={id}>{label}</label>{children}{error?<small id={id+"-error"} className="record-field-error">{error}</small>:null}</div>;}
const zeroChoice={QteRetour:"0",Lots:{}};

export default function BonReturnEditor({commandeId,onClose,onSaved,onConsultOrder}) {
  const {user}=useAuth(),prefix=useId(),mounted=useRef(true),saving=useRef(false),request=useRef(null),seeded=useRef(false);
  const contextKey=String(user?.IdUser??"")+":"+String(user?.IdEntiteFk??""),initialContext=useRef(contextKey);
  const [preview,setPreview]=useState(null),[meta,setMeta]=useState(null),[loading,setLoading]=useState(true),[revision,setRevision]=useState(0);
  const [values,setValues]=useState({DateCmd:"",motif:""}),[initial,setInitial]=useState(""),[selection,setSelection]=useState({}),[lotsOpen,setLotsOpen]=useState({});
  const [headerErrors,setHeaderErrors]=useState({}),[rowErrors,setRowErrors]=useState({}),[error,setError]=useState(""),[reloadable,setReloadable]=useState(false);
  const [busy,setBusy]=useState(false),[uncertain,setUncertain]=useState(false),[closeWarning,setCloseWarning]=useState(false);
  const lines=preview?.lignes||[],source=preview?.bonOrigine,history=preview?.retours||[];
  const canWrite=user?.permissions?.canWriteData===true&&contextKey===initialContext.current,disabled=busy||uncertain||loading||!canWrite;
  const canReturn=meta?.available===true&&meta?.canReturn===true&&Boolean(meta?.revision),dirty=Boolean(initial)&&(JSON.stringify(values)!==initial||Object.values(selection).some(item=>returnQuantity(item.QteRetour)!=="0"));
  const total=restitutionTotal(lines.map(line=>({quantity:selection[line.ID_ArticleFk]?.QteRetour??"0",price:line.PUHistorique})));
  useEffect(()=>{mounted.current=true;return()=>{mounted.current=false;};},[]);
  useEffect(()=>{if(contextKey!==initialContext.current)onClose();},[contextKey,onClose]);
  useEffect(()=>{
    let active=true;setLoading(true);setError("");setReloadable(false);
    requestJson("/api/logistique/commandes/"+commandeId+"/retours",{requiresAuth:true}).then(response=>{
      if(!active)return;
      if(!response?.success){setMeta(null);setError(response?.message||"La restitution n’a pas pu être préparée.");setReloadable(true);setLoading(false);return;}
      setPreview(response.data);setMeta(response.meta||null);setSelection(current=>restitutionSelection(response.data?.lignes||[],current));
      if(!seeded.current){const form=returnHeader(response.data?.defaults?.DateCmd);setValues(form);setInitial(JSON.stringify(form));seeded.current=true;}
      setHeaderErrors({});setRowErrors({});setLoading(false);
    });return()=>{active=false;};
  },[commandeId,revision]);
  function change(name,value){if(disabled)return;setValues(current=>({...current,[name]:value}));setHeaderErrors(current=>({...current,[name]:""}));}
  function quantity(line,value){
    if(disabled||!canReturn)return;
    const id=String(line.ID_ArticleFk),parsed=returnQuantity(value),known=line.Lots||[];
    setSelection(current=>{
      const old=current[id]||zeroChoice;let lots=old.Lots;
      if(parsed==="0")lots=Object.fromEntries(known.map(lot=>[String(lot.ID_LotArticle),"0"]));
      else if(parsed!=null&&known.length===1&&returnQuantity(line.QteSansLotRestante)==="0")lots={[String(known[0].ID_LotArticle)]:parsed};
      return {...current,[id]:{QteRetour:value,Lots:lots}};
    });
    if(parsed!=null&&quantityUnits(parsed)>0n&&known.length)setLotsOpen(current=>({...current,[id]:true}));
    setRowErrors(current=>({...current,[id]:{}}));
  }
  function lotQuantity(articleId,lotId,value){if(disabled||!canReturn)return;setSelection(current=>({...current,[articleId]:{...(current[articleId]||zeroChoice),Lots:{...(current[articleId]?.Lots||{}),[lotId]:value}}}));setRowErrors(current=>({...current,[articleId]:{...current[articleId],Lots:"",LotQuantities:{...current[articleId]?.LotQuantities,[lotId]:""}}}));}
  function fillRemaining(){if(disabled||!canReturn)return;setSelection(allRemainingReturns(lines));setRowErrors({});setLotsOpen(Object.fromEntries(lines.filter(line=>line.Lots?.length).map(line=>[String(line.ID_ArticleFk),true])));}
  function close(){if(busy)return;if(uncertain){setCloseWarning(true);return;}onClose();}
  function focusInvalid(header,rows){const name=Object.keys(header)[0];requestAnimationFrame(()=>{if(name){document.getElementById(prefix+name)?.focus();return;}const id=Object.keys(rows)[0];document.getElementById(prefix+"quantity-"+id)?.focus();});}
  async function submit(){
    if(saving.current||!canWrite||loading||(!uncertain&&!canReturn))return;
    let snapshot=request.current;
    if(!uncertain){
      const invalidHeader=returnHeaderErrors(values),invalidRows={};
      for(const line of lines){const issues=restitutionLineErrors(line,selection[line.ID_ArticleFk]);if(Object.keys(issues).length)invalidRows[line.ID_ArticleFk]=issues;}
      setHeaderErrors(invalidHeader);setRowErrors(invalidRows);setError("");
      if(Object.keys(invalidHeader).length||Object.keys(invalidRows).length){setLotsOpen(current=>({...current,...Object.fromEntries(Object.entries(invalidRows).filter(([,issues])=>issues.Lots||issues.LotQuantities).map(([id])=>[id,true]))}));setError("Vérifiez les champs et les quantités indiqués.");focusInvalid(invalidHeader,invalidRows);return;}
      const payload=restitutionPayload(values,lines,selection,meta.revision);
      if(!payload.lignes.length){setError("Renseignez au moins une quantité à restituer.");return;}
      const fingerprint=JSON.stringify(payload);
      if(!snapshot||snapshot.fingerprint!==fingerprint){snapshot={payload,fingerprint,requestId:createReceiptRequestId()};request.current=snapshot;}
    }
    if(!snapshot)return;
    saving.current=true;setBusy(true);setError("");setCloseWarning(false);setReloadable(false);
    const response=await requestJson("/api/logistique/commandes/"+commandeId+"/retours",{method:"POST",requiresAuth:true,body:JSON.stringify({...snapshot.payload,requestId:snapshot.requestId})});
    if(!mounted.current)return;saving.current=false;setBusy(false);
    if(!response?.success||!response.data?.bonRetour){
      if(!response||!response.status||response.status>=500||response.success===true){setUncertain(true);setError("La réponse du serveur n’est pas parvenue. Réessayez sans modifier la restitution.");return;}
      setUncertain(false);setReloadable(true);
      const details=response.error?.details,invalidHeader={},invalidRows={};
      if(details&&typeof details==="object"&&!Array.isArray(details))for(const [key,value] of Object.entries(details)){
        if(["DateCmd","motif"].includes(key))invalidHeader[key]=String(value);
        const match=/^lignes\.(\d+)(?:\.(.+))?$/.exec(key),sent=match?snapshot.payload.lignes[Number(match[1])]:null;
        if(sent){const id=sent.ID_ArticleFk,field=match[2]==="QteRetour"?"QteRetour":"Lots";invalidRows[id]={...invalidRows[id],[field]:String(value)};}
      }
      setHeaderErrors(invalidHeader);setRowErrors(invalidRows);setLotsOpen(current=>({...current,...Object.fromEntries(Object.entries(invalidRows).filter(([,issues])=>issues.Lots).map(([id])=>[id,true]))}));
      const general=details&&typeof details==="object"?[details.motif,details.DateCmd,details.lignes,details.requestId].find(value=>typeof value==="string"&&value):"";
      setError(general||response.message||"La restitution n’a pas pu être enregistrée.");if(Object.keys(invalidHeader).length||Object.keys(invalidRows).length)focusInvalid(invalidHeader,invalidRows);return;
    }
    onSaved(response.data);
  }
  const columns=[
    {key:"NomArticle",label:"Article et lots",width:255,render:line=>{const id=String(line.ID_ArticleFk),choice=selection[id]||zeroChoice,issues=rowErrors[id]||{},lots=line.Lots||[];return <div className="bon-return-product"><strong>{line.NomArticle||"Article"}</strong><small>{line.CodeArticleInterne||""}{line.AbrUnite?" · "+line.AbrUnite:""}</small>{lots.length?<details className="bon-return-lots" open={Boolean(lotsOpen[id])} onToggle={event=>{const open=event.currentTarget.open;setLotsOpen(current=>current[id]===open?current:{...current,[id]:open});}}><summary>Lots d’origine · {lots.length}</summary>{lots.map(lot=>{const lotId=String(lot.ID_LotArticle),fieldId=prefix+"lot-"+id+"-"+lotId,invalid=issues.LotQuantities?.[lotId];return <div key={lotId} className="bon-return-lot"><label htmlFor={fieldId}>{lot.NumeroLot}<small>Restant : {formatNumber(lot.QteRestante)}{lot.DatePeremptionLot?" · "+formatDate(lot.DatePeremptionLot):""}</small></label><input id={fieldId} className="bon-return-quantity" inputMode="decimal" maxLength={15} value={choice.Lots[lotId]??"0"} onChange={event=>lotQuantity(id,lotId,event.target.value)} disabled={disabled||!canReturn||returnQuantity(lot.QteRestante)==="0"||returnQuantity(choice.QteRetour)==="0"} aria-invalid={Boolean(invalid)} aria-describedby={invalid?fieldId+"-error":undefined}/>{invalid?<small className="bon-return-line-error" id={fieldId+"-error"}>{invalid}</small>:null}</div>;})}<small>Sans lot disponible : {formatNumber(line.QteSansLotRestante)}</small></details>:null}{issues.Lots?<small className="bon-return-line-error" role="alert">{issues.Lots}</small>:null}</div>; }},
    {key:"QteRetour",label:"À restituer",width:145,sortable:false,render:line=>{const id=line.ID_ArticleFk,fieldId=prefix+"quantity-"+id,invalid=rowErrors[id]?.QteRetour;return <div><label className="erp-sr-only" htmlFor={fieldId}>{"Quantité à restituer · "+(line.NomArticle||"Article")}</label><input id={fieldId} className="bon-return-quantity" inputMode="decimal" maxLength={15} value={selection[id]?.QteRetour??"0"} onChange={event=>quantity(line,event.target.value)} disabled={disabled||!canReturn||returnQuantity(line.QteRestante)==="0"} aria-invalid={Boolean(invalid)} aria-describedby={invalid?fieldId+"-error":undefined}/>{invalid?<small className="bon-return-line-error" id={fieldId+"-error"}>{invalid}</small>:null}</div>;}},
    {key:"QteRestante",label:"Restant",width:110,align:"right",render:line=>formatNumber(line.QteRestante)},
    {key:"QteSortie",label:"Sortie d’origine",width:130,align:"right",render:line=>formatNumber(line.QteSortie)},
    {key:"QteDejaRetournee",label:"Déjà restitué",width:130,align:"right",render:line=>formatNumber(line.QteDejaRetournee)},
    {key:"PUHistorique",label:"Prix d’origine",width:160,align:"right",render:line=>formatCurrency(line.PUHistorique,line.DeviseCode)},
  ];
  return <RecordEditorFrame title="Restitution de stock" subtitle={source?.CodeCmd||"Articles du bon de sortie"} icon="stock-in" defaultWidth={1080} className="bon-return-dialog" storageKey="sauverndeko.bon-return.width" onClose={close} onSubmit={submit} loading={loading&&!preview} busy={busy} dirty={!uncertain&&dirty} canSubmit={canWrite&&!loading&&(uncertain||canReturn)} submitLabel={uncertain?"Réessayer":"Enregistrer la restitution"} error={error} onReload={reloadable&&!uncertain?()=>setRevision(value=>value+1):null}>
    <div className="bon-return-editor">
      {closeWarning?<div className="record-editor-error" role="alert"><span>Une restitution a peut-être été enregistrée. Réessayez pour vérifier avant de fermer.</span><div className="bon-return-inline-actions"><ActionButton onClick={submit} disabled={busy}>Réessayer</ActionButton><ActionButton onClick={onClose} disabled={busy}>Fermer la fenêtre</ActionButton></div></div>:null}
      {source?<div className="bon-return-origin"><AppIcon name="stock-out" size={24}/><div><strong>{source.CodeCmd||"Bon de sortie"}</strong><small>{source.DateCmd?formatDate(source.DateCmd):""}{source.NomClientSaisi?" · "+source.NomClientSaisi:""}</small></div><span>{source.DeviseCode||"Devise non renseignée"}</span></div>:null}
      {preview&&!canReturn&&!uncertain?<p className="record-editor-error" role="status">{meta?.reason||"Ce bon ne permet pas de restitution."}</p>:null}
      {preview&&loading?<p className="record-editor-note" role="status">Actualisation de l’aperçu…</p>:null}
      {preview?<><section className="record-editor-section"><h3><AppIcon name="receipt"/>Informations de la restitution</h3><div className="record-editor-grid">
        <Field id={prefix+"DateCmd"} label="Date et heure de la restitution *" error={headerErrors.DateCmd}><input id={prefix+"DateCmd"} type="datetime-local" step={1} value={values.DateCmd} onChange={event=>change("DateCmd",event.target.value)} disabled={disabled||!canReturn} aria-invalid={Boolean(headerErrors.DateCmd)} aria-describedby={headerErrors.DateCmd?prefix+"DateCmd-error":undefined}/></Field>
        <Field id={prefix+"code"} label="Code du bon de retour"><input id={prefix+"code"} readOnly value="Attribué à l’enregistrement"/></Field>
        <div className="record-field is-wide"><label htmlFor={prefix+"motif"}>Motif *</label><textarea id={prefix+"motif"} rows={3} maxLength={1000} value={values.motif} onChange={event=>change("motif",event.target.value)} disabled={disabled||!canReturn} aria-invalid={Boolean(headerErrors.motif)} aria-describedby={headerErrors.motif?prefix+"motif-error":undefined}/>{headerErrors.motif?<small id={prefix+"motif-error"} className="record-field-error">{headerErrors.motif}</small>:null}</div>
      </div></section>
      <section className="record-editor-section"><header className="bon-return-lines-head"><div><h3><AppIcon name="box"/>Articles à restituer</h3><p>Les quantités choisies seront remises en stock avec un bon de retour.</p></div><ActionButton icon="stock-in" onClick={fillRemaining} disabled={disabled||!canReturn}>Tout restituer</ActionButton></header><div className="erp-results" data-density="compact"><SimpleTable columns={columns} rows={lines} getRowId={line=>line.ID_ArticleFk} defaultPinnedColumns={[]} showControls={false} toolbar={<></>} loading={loading} emptyMessage="Aucune ligne de sortie disponible."/></div><div className="bon-return-total"><span>Valeur des articles sélectionnés</span><strong>{formatCurrency(total,source?.DeviseCode)}</strong></div></section>
      {history.length?<section className="record-editor-section"><h3><AppIcon name="clock"/>Restitutions enregistrées</h3><div className="bon-return-history">{history.map(item=><article key={item.ID_RetourBon}><div><strong>{item.CodeCmd||"Bon de retour"}</strong><small>{formatDate(item.DateCmd)}{item.NomComplet?" · "+item.NomComplet:""}</small>{item.Motif?<p>{item.Motif}</p>:null}</div>{onConsultOrder&&item.ID_CommandeRetourFk?<ActionButton icon="eye" onClick={()=>onConsultOrder({...item,ID_Commande:item.ID_CommandeRetourFk})} disabled={busy||uncertain}>Consulter</ActionButton>:null}</article>)}</div></section>:null}
      </>:null}
    </div>
  </RecordEditorFrame>;
}
