import {useEffect,useId,useRef,useState} from "react";
import {useDepotScope,DepotField} from "../../contexts/DepotScopeContext";
import {useAuth} from "../../contexts/AuthContext";
import {useEntityScope} from "../../contexts/EntityScopeContext";
import useReferencesRefresh from "../../hooks/useReferencesRefresh";
import RecordEditorFrame from "../../components/RecordEditorFrame";
import ActionButton from "../../components/ActionButton";
import AppIcon from "../../components/AppIcon";
import SearchSelect from "../../components/SearchSelect";
import articleImportTemplate from "../../assets/modele-import-articles.xlsx?url";
import {SimpleTable} from "./logistiqueShared";
import {downloadApiFile,requestJson} from "../../services/api";
import {tiersRequest,tiersChanged} from "../../services/tiers";
import {immobilisationsRequest} from "../../services/immobilisations";
import {fetchLogistiqueReferences} from "../../services/logistique";
import TiersEditor from "./TiersEditor";
import ArticleEditor from "./ArticleEditor";
import ImmobilisationEditor from "./ImmobilisationEditor";
import {BATCH_KINDS,BATCH_LABELS,logisticsBatchLimit,batchChoices,logisticsBatchRow,validateLogisticsBatch,logisticsBatchFromExcel,logisticsBatchFromMatrix,logisticsBatchTicket,logisticsBatchBody} from "./logisticsBatchForm";
import "./LogisticsBatchComposer.css";

const ARTICLE_EXCEL_MAX_BYTES=4*1024*1024;

/** Brouillons uniquement ; toutes les écritures sont regroupées par le serveur. */
export default function LogisticsBatchComposer({kind,references:receivedReferences,onClose,onSaved}){
 const depotScope=useDepotScope();
 const [depotId,setDepotId]=useState(()=>depotScope.depotId||depotScope.defaultDepotId);
 const config=BATCH_KINDS[kind],scope=useEntityScope(),{user}=useAuth(),prefix=useId();
 const identity=String(user?.IdUser)+":"+scope.scopeKey,origin=useRef(identity),current=useRef(identity),alive=useRef(true),saving=useRef(false),ticket=useRef(null),request=useRef(null);current.current=identity;
 const [references,setReferences]=useState(receivedReferences||{}),[rows,setRows]=useState([]),[loading,setLoading]=useState(true),[busy,setBusy]=useState(false),[error,setError]=useState(""),[errors,setErrors]=useState({rows:{},header:{}}),[uncertain,setUncertain]=useState(false),[reload,setReload]=useState(0);
 const [details,setDetails]=useState(null),[motif,setMotif]=useState(""),[pasteOpen,setPasteOpen]=useState(false),[pasteText,setPasteText]=useState(""),[hasHeaders,setHasHeaders]=useState(kind==="articles"),[pasteError,setPasteError]=useState(""),[clearAsked,setClearAsked]=useState(false);
 const [openingReceipt,setOpeningReceipt]=useState(false),[page,setPage]=useState(1),[focusTarget,setFocusTarget]=useState(null);
 const fileInput=useRef(null),previewRequest=useRef(null);
 const [importing,setImporting]=useState(false),[downloading,setDownloading]=useState(false),[importError,setImportError]=useState(""),[importMessage,setImportMessage]=useState("");
 useEffect(()=>{if(!depotId&&depotScope.defaultDepotId)setDepotId(depotScope.defaultDepotId);},[depotId,depotScope.defaultDepotId]);
 const limit=logisticsBatchLimit(kind,openingReceipt),pageSize=kind==="articles"?50:limit;
 const pageForIndex=index=>Math.floor(index/pageSize)+1;
 const changed=origin.current!==identity,deniedByReferences=references.canCreate===false,allowed=scope.canCreate===true&&user?.permissions?.canWriteData===true&&!changed&&!deniedByReferences,disabled=!allowed||loading||busy||uncertain||importing;
 const access=useRef(allowed);access.current=allowed;
 useReferencesRefresh(()=>{if(!busy&&!uncertain&&!changed&&!previewRequest.current)setReload(value=>value+1);});
 useEffect(()=>{alive.current=true;return()=>{alive.current=false;request.current?.abort();};},[]);
 useEffect(()=>()=>previewRequest.current?.abort(),[identity]);
 useEffect(()=>{if(allowed)return;previewRequest.current?.abort();previewRequest.current=null;setImporting(false);setDownloading(false);setImportMessage("");setImportError("");},[allowed,identity]);
 useEffect(()=>{
  if(changed)return;let active=true;setLoading(true);setError("");
  const fetchReferences=kind==="tiers"?tiersRequest("/references"):kind==="immobilisations"?immobilisationsRequest("/references"):receivedReferences?Promise.resolve({success:true,data:receivedReferences}):fetchLogistiqueReferences();
  fetchReferences.then(response=>{if(!active||current.current!==identity)return;setLoading(false);if(!response?.success){setError(response?.message||"Les listes n’ont pas pu être chargées.");return;}const refs=response.data||{};setReferences(refs);setRows(previous=>previous.length?previous:[logisticsBatchRow(kind,refs)]);});
  return()=>{active=false;};
 },[kind,reload,identity]);
 useEffect(()=>{
  if(!focusTarget)return;
  const frame=requestAnimationFrame(()=>document.getElementById(prefix+focusTarget.id)?.focus());
  return ()=>{if(frame!=null)cancelAnimationFrame(frame);};
 },[focusTarget,prefix]);
 function changedDraft(){ticket.current=null;setError("");setErrors({rows:{},header:{}});}
 function edit(id,field,value){if(disabled)return;setRows(previous=>previous.map(row=>row.clientRowId===id?{...row,_pristine:false,values:{...row.values,[field]:value}}:row));ticket.current=null;setError("");setErrors(previous=>{
  const header={...previous.header};
  if(field==="QteArticle"||field==="ID_DeviseFk")delete header.openingReceipt;
  return {...previous,header,rows:{...previous.rows,[id]:{...previous.rows[id],[field]:""}}};
 });}
 function add(){
  if(disabled||rows.length>=limit)return;
  const row=logisticsBatchRow(kind,references);
  changedDraft();
  setRows(previous=>[...previous,row]);
  setPage(pageForIndex(rows.length));
  setFocusTarget({id:row.clientRowId+config.name});
 }
 function remove(id){if(disabled)return;changedDraft();setRows(previous=>previous.filter(row=>row.clientRowId!==id));if(details===id)setDetails(null);}
 function clear(){if(disabled)return;changedDraft();setRows([]);setPage(1);setDetails(null);setPasteText("");setClearAsked(false);}
 function appendImportedRows(imported){
  const existing=rows.length===1&&rows[0]._pristine===true?[]:rows;
  if(existing.length+imported.length>limit)throw new Error("Le panier peut contenir "+limit+" lignes au maximum.");
  const next=[...existing,...imported],issues=validateLogisticsBatch(kind,next,references,motif,openingReceipt);
  setRows(next);
  setPage(pageForIndex(existing.length));
  ticket.current=null;
  setErrors(issues);
  setError("");
  return {next,issues,firstImportedIndex:existing.length};
 }
 function importRows(){
  if(disabled)return;
  try{
   const imported=logisticsBatchFromExcel(kind,pasteText,references,{hasHeaders,openingReceipt});
   if(!imported.length)throw new Error("Collez au moins une ligne.");
   appendImportedRows(imported);
   setPasteText("");setPasteError("");setPasteOpen(false);setImportError("");setImportMessage("");
  }catch(failure){setPasteError(failure.message);}
 }
 function excelIsCurrent(controller){return alive.current&&access.current&&current.current===identity&&previewRequest.current===controller&&!controller.signal.aborted;}
 async function downloadTemplate(){
  if(disabled||saving.current||previewRequest.current)return;
  const controller=new AbortController();previewRequest.current=controller;setDownloading(true);setImportMessage("");setImportError("");
  try{
   await downloadApiFile("/api/logistique/saisie-multiple/"+kind+"/modele-excel",{signal:controller.signal,filename:"modele-import-"+kind+".xlsx"});
   if(excelIsCurrent(controller))setImportMessage("Modèle Excel téléchargé.");
  }catch(failure){if(excelIsCurrent(controller))setImportError(failure.message||"Le modèle Excel n’a pas pu être téléchargé.");}
  finally{if(previewRequest.current===controller){if(excelIsCurrent(controller))setDownloading(false);previewRequest.current=null;}}
 }
 async function importFile(event){
  const file=event.currentTarget.files?.[0];
  event.currentTarget.value="";
  if(!file||disabled||saving.current||previewRequest.current)return;
  setImportMessage("");
  setImportError("");
  if(!/\.xlsx$/i.test(file.name)||!file.size||file.size>ARTICLE_EXCEL_MAX_BYTES){
   setImportError("Choisissez un fichier Excel .xlsx non vide de 4 Mo maximum.");
   return;
  }
  const controller=new AbortController();
  previewRequest.current=controller;
  setImporting(true);
  try{
   const body=new FormData();
   body.append(kind==="articles"?"file":"fichier",file);
   const endpoint=kind==="articles"?"/api/logistique/saisie-multiple/articles/apercu-excel":"/api/logistique/saisie-multiple/"+kind+"/import-excel";
   const response=await requestJson(endpoint,{requiresAuth:true,method:"POST",body,signal:controller.signal});
   if(!excelIsCurrent(controller))return;
   if(!response?.success)throw new Error(response?.status===413?"Le fichier dépasse 4 Mo.":response?.message||"Le fichier Excel n’a pas pu être lu.");
   const cells=response.data?.cells;
   if(!Array.isArray(cells)||!cells.every(row=>Array.isArray(row)&&row.every(cell=>typeof cell==="string")))throw new Error("L’aperçu du fichier Excel n’a pas pu être chargé.");
   const imported=logisticsBatchFromMatrix(kind,cells,references,{hasHeaders:true,openingReceipt});
   if(!imported.length)throw new Error("Ajoutez au moins une ligne sous les en-têtes.");
   const {next,issues,firstImportedIndex}=appendImportedRows(imported);
   if(!focusIssues(issues,next,firstImportedIndex))setFocusTarget({id:next[firstImportedIndex].clientRowId+config.name});
   const names=imported.map(row=>String(row.values[config.name]??"").trim().toLocaleLowerCase("fr")).filter(Boolean);
   const count=imported.length===1?"1 ligne ajoutée au panier.":imported.length+" lignes ajoutées au panier.";
   const repeatedNames=new Set(names).size<names.length;
   setImportMessage((kind==="articles"&&repeatedNames?count+" Des noms se répètent. Vérifiez s’il s’agit de lots d’un même article.":count)+(kind!=="articles"&&Object.keys(issues.rows).length?" Vérifiez les champs signalés avant d’enregistrer.":""));
  }catch(failure){
   if(excelIsCurrent(controller)){
    setImportError(failure.message);
    setFocusTarget({id:"import-excel"});
   }
  }finally{
   if(previewRequest.current===controller){
    previewRequest.current=null;
    if(alive.current&&access.current&&current.current===identity&&!controller.signal.aborted)setImporting(false);
   }
  }
 }
 function focusIssues(issues,sourceRows=rows,startIndex=0){
  const index=sourceRows.findIndex((row,position)=>position>=startIndex&&Object.values(issues.rows?.[row.clientRowId]||{}).some(Boolean));
  if(index<0){
   const field=Object.keys(issues.header||{})[0];
   if(field)setFocusTarget({id:field});
   return Boolean(field);
  }
  const id=sourceRows[index].clientRowId;
  const field=Object.keys(issues.rows[id]).find(key=>issues.rows[id][key]);
  setPage(pageForIndex(index));
  setFocusTarget({id:id+(config.columns.includes(field)?field:"-errors")});
  return true;
 }
 async function submit(){
  if(!allowed||loading||saving.current||previewRequest.current)return;
  if(!ticket.current){const issues=validateLogisticsBatch(kind,rows,references,motif,openingReceipt);setErrors(issues);setError("");if(Object.keys(issues.header).length||Object.keys(issues.rows).length){focusIssues(issues);return;}const payload=logisticsBatchTicket(kind,rows,motif,openingReceipt);if(kind==="articles")payload.ID_DepotFk=depotId;ticket.current={payload,body:logisticsBatchBody(kind,payload,rows)};}
  const snapshot=ticket.current,expected=identity,controller=new AbortController();request.current=controller;saving.current=true;setBusy(true);setError("");
  const response=await requestJson("/api/logistique/saisie-multiple/"+kind,{requiresAuth:true,method:"POST",body:snapshot.body,signal:controller.signal});
  if(!alive.current||changed||current.current!==expected||controller.signal.aborted)return;saving.current=false;setBusy(false);
  const records=response?.data?.records,expectedIds=new Set(snapshot.payload.rows.map(row=>row.clientRowId));
  const receipt=response?.data?.openingReceipt;
  const receiptConfirmed=!snapshot.payload.openingReceipt||(
   /^[1-9]\d*$/.test(String(receipt?.id??""))&&typeof receipt?.code==="string"&&receipt.code.trim()!==""
  );
  const complete=receiptConfirmed&&response?.success&&response.data?.requestId===snapshot.payload.requestId&&Array.isArray(records)&&records.length===expectedIds.size&&Number(response.data.count)===records.length&&new Set(records.map(row=>row.clientRowId)).size===expectedIds.size&&records.every(row=>expectedIds.has(row.clientRowId));
  if(!complete){const ambiguous=!response?.status||response.status>=500||response.success===true;setUncertain(ambiguous);if(ambiguous){setError("La réponse n’est pas parvenue. Vérifiez le même enregistrement avant de modifier le panier.");return;}ticket.current=null;const details=response?.error?.details;if(details&&typeof details==="object"&&(details.rows||details.header)){const issues={rows:details.rows||{},header:details.header||{}};setErrors(issues);focusIssues(issues);setError("Corrigez les lignes indiquées. Aucune ligne de cette demande n’a été enregistrée.");}else setError(response?.message||"Le panier n’a pas pu être enregistré.");return;}
  ticket.current=null;setUncertain(false);if(kind==="tiers")tiersChanged();onSaved?.(response.data,{operation:"batch",kind});
 }
 function textCell(row,field){const issue=errors.rows[row.clientRowId]?.[field],id=prefix+row.clientRowId+field;return <div className="logistics-batch-cell"><input id={id} aria-label={BATCH_LABELS[field]+" · ligne "+(rows.indexOf(row)+1)} value={row.values[field]??""} disabled={disabled} aria-invalid={Boolean(issue)} aria-describedby={issue?id+"-error":undefined} autoComplete="off" placeholder={field==="DatePeremptionArticle"?"JJ/MM/AAAA":undefined} inputMode={["QteArticle","Quantite","PrixUnitaire","PUArticle","PVArticle"].includes(field)?"decimal":undefined} onChange={event=>edit(row.clientRowId,field,event.target.value)}/>{issue?<small id={id+"-error"} className="record-field-error">{issue}</small>:null}</div>;}
 function valueCell(row,field){if(field==="VisibleCatalogue"){const id=prefix+row.clientRowId+field,issue=errors.rows[row.clientRowId]?.[field];return <div className="logistics-batch-cell"><label className="record-editor-check" htmlFor={id}><input id={id} type="checkbox" checked={row.values.VisibleCatalogue===true} disabled={disabled} onChange={event=>edit(row.clientRowId,field,event.target.checked)} aria-label={"Visible dans l’annuaire · ligne "+(rows.indexOf(row)+1)} aria-invalid={Boolean(issue)} aria-describedby={issue?id+"-error":undefined}/>Visible</label>{issue?<small id={id+"-error"} className="record-field-error">{issue}</small>:null}</div>;}const options=batchChoices(kind,field,references);if(!options)return textCell(row,field);const currentValue=String(row.values[field]??"");const choices=[{value:"",label:"Choisir…"},...options];if(currentValue&&!choices.some(item=>item.value===currentValue))choices.push({value:currentValue,label:"À vérifier : "+currentValue,disabled:true});const issue=errors.rows[row.clientRowId]?.[field],id=prefix+row.clientRowId+field;return <div className="logistics-batch-cell"><SearchSelect id={id} label={BATCH_LABELS[field]+" · ligne "+(rows.indexOf(row)+1)} options={choices} value={currentValue} disabled={disabled} invalid={Boolean(issue)} describedBy={issue?id+"-error":undefined} onChange={value=>edit(row.clientRowId,field,value)}/>{issue?<small id={id+"-error"} className="record-field-error">{issue}</small>:null}</div>;}
 const columns=[{key:"line",label:"N°",width:55,sortable:false,render:row=>rows.indexOf(row)+1},...config.columns.map(field=>({key:field,label:BATCH_LABELS[field],width:field===config.name?245:["PUArticle","PVArticle","QteArticle","PrixUnitaire","Quantite"].includes(field)?145:190,sortable:false,render:row=>valueCell(row,field)})),{key:"actions",label:"Actions",width:105,sortable:false,render:row=><div className="erp-row-actions"><ActionButton icon="edit" className="is-icon" aria-label={"Détails de la ligne "+(rows.indexOf(row)+1)} onClick={()=>setDetails(row.clientRowId)} disabled={disabled}/><ActionButton icon="trash" className="is-icon" aria-label={"Retirer la ligne "+(rows.indexOf(row)+1)} onClick={()=>remove(row.clientRowId)} disabled={disabled}/></div>}];
 const selected=rows.find(row=>row.clientRowId===details);
 function savedDraft(draft){if(disabled||!selected)return;changedDraft();setRows(previous=>previous.map(row=>row.clientRowId===details?{...row,...draft,_pristine:false}:row));setDetails(null);}
 const rowErrors=rows.flatMap((row,index)=>{
  const fields=Object.entries(errors.rows[row.clientRowId]||{}).filter(([,message])=>Boolean(message));
  return fields.length?[{id:row.clientRowId,index,fields}]:[];
 });
 const pageErrors=rowErrors.filter(({index})=>pageForIndex(index)===page);
 return <><RecordEditorFrame title={config.title} subtitle="Une ou plusieurs fiches dans le même panier." icon={config.icon} onClose={onClose} onSubmit={submit} loading={loading} busy={busy} dirty={!changed&&Boolean(rows.some(row=>!row._pristine)||pasteText.trim()||motif.trim()||openingReceipt)} readOnly={!allowed} canSubmit={allowed&&!loading&&!importing} submitLabel={uncertain?"Vérifier l’enregistrement":"Enregistrer l’ensemble"} discardMessage={uncertain?"Fermer n’annule pas l’enregistrement. Vérifiez le registre avant une nouvelle création.":undefined} discardLabel={uncertain?"Fermer la saisie":undefined} error={changed?"L’entreprise a changé. Rouvrez la saisie dans le nouvel espace.":deniedByReferences?"Votre accès ne permet pas de créer ces fiches dans cette entreprise.":error} onReload={!uncertain&&error?()=>setReload(value=>value+1):null} defaultWidth={1250} storageKey={"sauverndeko.logistique.batch."+kind+".width"} className="logistics-batch-composer">
  {!changed&&!loading?<><section className="record-editor-section"><div className="logistics-batch-heading"><h3><AppIcon name={config.icon}/>Panier <span className="erp-count-badge">{rows.length}</span></h3>
   <div className="logistics-batch-actions">
    <ActionButton icon="plus" onClick={add} disabled={disabled||rows.length>=limit}>Ajouter une ligne</ActionButton>
    {kind==="articles"?<a className="ui-action is-secondary" data-action="download" href={articleImportTemplate} download="modele-import-articles.xlsx"><AppIcon name="download"/>Télécharger le modèle Excel</a>
     :<ActionButton icon="download" disabled={disabled||downloading} onClick={downloadTemplate}>{downloading?"Téléchargement…":"Télécharger le modèle Excel"}</ActionButton>}
    <input type="file" ref={fileInput} accept=".xlsx,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" hidden disabled={disabled||downloading||rows.length>=limit} onChange={importFile}/>
    <ActionButton id={prefix+"import-excel"} aria-describedby={prefix+"import-excel-hint"} icon="stock-in" variant="primary" onClick={()=>{if(!disabled&&!previewRequest.current)fileInput.current?.click();}} disabled={disabled||downloading||rows.length>=limit}>Importer un fichier Excel</ActionButton>
    <ActionButton icon="document" onClick={()=>setPasteOpen(value=>!value)} disabled={disabled}>Coller depuis Excel</ActionButton>
    <ActionButton icon="trash" onClick={()=>setClearAsked(true)} disabled={disabled||!rows.length}>Vider le panier</ActionButton>
   </div>
  </div>
   <p className="record-editor-note">{scope.entities?.find(item=>String(item.id)===String(scope.entityId))?.label||"Entreprise sélectionnée"}</p>
   {kind==="articles"?<DepotField id={prefix+"depot"} value={depotId} disabled={disabled} onChange={value=>{setDepotId(value);changedDraft();}}/>:null}
   {kind==="articles"?<div className="record-field logistics-batch-reason">
    <label className="record-editor-check" htmlFor={prefix+"group-opening-stock"}>
     <input id={prefix+"group-opening-stock"} type="checkbox" checked={openingReceipt} disabled={disabled} aria-invalid={Boolean(errors.header.openingReceipt)} aria-describedby={prefix+"opening-stock-hint"+(errors.header.openingReceipt?" "+prefix+"openingReceipt":"")} onChange={event=>{setOpeningReceipt(event.target.checked);setPasteError("");changedDraft();}}/>
     Regrouper le stock initial dans un seul bon d’entrée
    </label>
    <small id={prefix+"opening-stock-hint"}>{openingReceipt?"Saisissez les quantités et vérifiez le prix d’achat. Les lignes avec du stock doivent partager la même devise. Les articles à zéro sont créés sans mouvement.":"Par défaut, chaque article avec un stock initial a son propre bon d’entrée."} {limit} lignes maximum.</small>
   </div>:null}
   <p id={prefix+"import-excel-hint"} className="record-editor-note">Importez le modèle ou un fichier .xlsx avec les mêmes en-têtes sur la première ligne (4 Mo maximum). Vérifiez le panier avant d’enregistrer l’ensemble.</p>
   {importing||downloading||importMessage?<p role="status" aria-live="polite" className="record-editor-note">{importing?"Lecture du fichier Excel…":downloading?"Téléchargement du modèle Excel…":importMessage}</p>:null}
   {importError?<p role="alert" className="record-field-error">{importError}</p>:null}
   {kind==="immobilisations"?<div className="record-field logistics-batch-reason"><label htmlFor={prefix+"motif"}>Motif commun de l’enregistrement</label><input id={prefix+"motif"} value={motif} onChange={event=>{setMotif(event.target.value);changedDraft();}} disabled={disabled} maxLength={1000} placeholder="Motif appliqué aux lignes sans motif particulier"/></div>:null}
   {clearAsked?<div className="record-editor-error" role="alert"><span>Retirer toutes les lignes ?</span><ActionButton disabled={disabled} onClick={()=>setClearAsked(false)}>Conserver</ActionButton><ActionButton icon="trash" onClick={clear} disabled={disabled}>Vider le panier</ActionButton></div>:null}
   {pasteOpen?<div className="logistics-batch-paste">
    <label htmlFor={prefix+"paste"}>Collage Excel</label>
    {kind==="articles"&&hasHeaders?<p className="record-editor-note">Dans la feuille <strong>Articles</strong> du modèle, copiez les en-têtes et les lignes renseignées. Collez-les ici, laissez la case des en-têtes cochée, puis cliquez sur <strong>Ajouter au panier</strong>.</p>:null}
    <p className="record-editor-note">{!hasHeaders?<>Sans en-têtes, utilisez cet ordre de colonnes. {config.paste.map(field=>BATCH_LABELS[field]).join(" · ")}. </>:kind!=="articles"?"Utilisez les noms des champs en première ligne, dans l’ordre de votre feuille. ":""}Les listes acceptent leur libellé exact ou leur identifiant.</p>
    {kind==="articles"?<p className="record-editor-note">Vérifiez l’unité, le stock, les prix, la devise et la péremption. Indiquez un numéro de lot uniquement si toute la quantité de la ligne appartient à ce lot. Les articles collés restent privés jusqu’à publication explicite.</p>:null}
    <textarea id={prefix+"paste"} value={pasteText} onChange={event=>{setPasteText(event.target.value);setPasteError("");}} rows={4} disabled={disabled}/>
    <label><input type="checkbox" checked={hasHeaders} onChange={event=>setHasHeaders(event.target.checked)} disabled={disabled}/>La première ligne contient les en-têtes</label>
    {pasteError?<p className="record-field-error" role="alert">{pasteError}</p>:null}
    <div className="logistics-batch-actions"><ActionButton icon="plus" onClick={importRows} disabled={disabled}>Ajouter au panier</ActionButton><ActionButton onClick={()=>setPasteOpen(false)} disabled={disabled}>Fermer le collage</ActionButton></div>
   </div>:null}
   {Object.entries(errors.header||{}).map(([field,message])=><p id={prefix+field} tabIndex={-1} role="alert" className="record-field-error" key={field}>{String(message)}</p>)}
   <SimpleTable rows={rows} columns={columns} getRowId={row=>row.clientRowId} showControls={false} defaultRowsPerPage={pageSize} page={page} onPageChange={setPage} defaultVisibleColumns={columns.map(column=>column.key)} defaultPinnedColumns={[]} emptyMessage="Ajoutez une ligne ou importez un fichier Excel."/>
   {rowErrors.length>pageErrors.length?<div className="logistics-batch-actions">
    <span className="record-editor-note" role="status">{rowErrors.length} lignes à corriger dans le panier</span>
    <ActionButton onClick={()=>focusIssues(errors)} disabled={disabled}>Aller à la première ligne à corriger</ActionButton>
   </div>:null}
   {pageErrors.length?<ul className="logistics-batch-errors">{pageErrors.map(({id,index,fields})=><li id={prefix+id+"-errors"} tabIndex={-1} key={id}><button type="button" disabled={disabled} onClick={()=>setDetails(id)}>Ligne {index+1}</button> · {fields.map(([field,message])=>BATCH_LABELS[field]?BATCH_LABELS[field]+" — "+message:String(message)).join(" ")}</li>)}</ul>:null}
  </section><p className="record-editor-note">Les détails de chaque ligne conservent tous les champs de la fiche. Aucune fiche n’est créée avant l’enregistrement de l’ensemble.</p></>:null}
 </RecordEditorFrame>{selected&&!changed&&!disabled?(kind==="tiers"?<TiersEditor key={selected.clientRowId} draft={selected} onDraftSave={savedDraft} onClose={()=>setDetails(null)}/>:kind==="articles"?<ArticleEditor key={selected.clientRowId} draft={selected} references={references} onDraftSave={savedDraft} onClose={()=>setDetails(null)}/>:<ImmobilisationEditor key={selected.clientRowId} draft={{...selected,motif:selected.motif||motif}} onDraftSave={savedDraft} onClose={()=>setDetails(null)}/>):null}</>;
}
