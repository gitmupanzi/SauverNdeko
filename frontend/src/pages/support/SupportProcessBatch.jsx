import {useEffect,useRef,useState} from "react";
import ActionButton from "../../components/ActionButton";
import RecordEditorFrame from "../../components/RecordEditorFrame";
import {requestJson} from "../../services/api";
import {initialProcessModel,processModelPayload,SupportProcessModelFields,validateProcessModel} from "./SupportProcessEditor";
import {PROCESS_URL,useProcessMutation} from "./supportProcess";

const MAX_MODELS=100;
const MAX_WORKBOOK_BYTES=4*1024*1024;

export default function SupportProcessBatch({references,canManage,onClose,onSaved}){
  const upload=useRef(null),writable=useRef(canManage);
  writable.current=canManage;
  const [models,setModels]=useState([]),[selectedId,setSelectedId]=useState("");
  const [fileName,setFileName]=useState(""),[importing,setImporting]=useState(false);
  const [importIssues,setImportIssues]=useState([]),[importRowIssues,setImportRowIssues]=useState({});
  const [rowErrors,setRowErrors]=useState({}),[error,setError]=useState("");
  const mutation=useProcessMutation();
  const selected=models.find(model=>model.clientRowId===selectedId)||models[0];
  const busy=importing||mutation.busy;
  const disabled=!canManage||busy||mutation.uncertain;
  const serverErrors=mutation.details?.errors??[];

  useEffect(()=>{
    const first=serverErrors.find(issue=>issue.clientRowId);
    if(first)setSelectedId(first.clientRowId);
  },[mutation.details]);

  useEffect(()=>()=>upload.current?.abort(),[]);

  async function importWorkbook(event){
    const file=event.target.files?.[0];
    event.target.value="";
    if(!file||disabled||upload.current)return;
    if(!/\.xlsx$/i.test(file.name)||file.size>MAX_WORKBOOK_BYTES){
      setError("Choisissez un fichier Excel .xlsx de 4 Mo maximum.");
      return;
    }
    const controller=new AbortController(),body=new FormData();
    upload.current=controller;
    body.append("file",file);
    setImporting(true);
    setError("");
    const response=await requestJson(PROCESS_URL+"/import.xlsx",{requiresAuth:true,method:"POST",body,signal:controller.signal});
    if(controller.signal.aborted)return;
    upload.current=null;
    setImporting(false);
    if(!writable.current)return;
    if(!response?.success){
      const detail=response?.error?.details;
      setError((typeof detail==="string"&&detail)||response?.message||"Le classeur n’a pas pu être lu.");
      return;
    }
    const items=response.data?.items??[], issues=response.data?.errors??[];
    if(items.length>MAX_MODELS){
      setError("Le panier est limité à "+MAX_MODELS+" modèles.");
      return;
    }
    const imported=items.map(item=>({clientRowId:item.clientRowId||crypto.randomUUID(),values:initialProcessModel(item)}));
    setFileName(file.name);
    setImportIssues(issues.filter(issue=>!imported.some(item=>item.clientRowId===issue.clientRowId)));
    setImportRowIssues(Object.fromEntries(imported.map(({clientRowId})=>[clientRowId,
      issues.filter(issue=>issue.clientRowId===clientRowId),
    ]).filter(([,messages])=>messages.length)));
    setRowErrors({});
    setModels(imported);
    mutation.clearError();
    if(imported.length)setSelectedId(imported[0].clientRowId);
    else if(!issues.length)setError("Le fichier ne contient aucun modèle.");
  }

  function clearRowError(id){
    setRowErrors(current=>Object.fromEntries(Object.entries(current).filter(([key])=>key!==id)));
    setError("");
    mutation.clearError();
  }

  function update(values){
    setModels(current=>current.map(model=>model.clientRowId===selected.clientRowId?{...model,values}:model));
    clearRowError(selected.clientRowId);
  }

  function confirmCorrection(){
    const issue=validateProcessModel(selected.values,references);
    if(issue){setRowErrors(current=>({...current,[selected.clientRowId]:issue}));return;}
    setImportRowIssues(current=>Object.fromEntries(Object.entries(current).filter(([key])=>key!==selected.clientRowId)));
    clearRowError(selected.clientRowId);
  }

  function remove(id){
    setModels(current=>current.filter(model=>model.clientRowId!==id));
    if(selectedId===id)setSelectedId("");
    clearRowError(id);
  }

  function submit(){
    if(!canManage||busy||!models.length||importIssues.length)return;
    if(!mutation.uncertain){
      const errors=Object.fromEntries(models.map(model=>[model.clientRowId,
        validateProcessModel(model.values,references)||
          (importRowIssues[model.clientRowId]?.length?"Vérifiez et confirmez la correction des lignes Excel signalées.":""),
      ]).filter(([,issue])=>issue));
      const first=Object.keys(errors)[0];
      if(first){
        setRowErrors(errors);
        setSelectedId(first);
        setError("Corrigez les modèles indiqués avant d’enregistrer le panier.");
        return;
      }
    }
    const items=models.map(({clientRowId,values})=>{
      const {requestId,revision,...data}=processModelPayload(values);
      return {clientRowId,...data};
    });
    mutation.save(PROCESS_URL+"/lot","POST",{requestId:crypto.randomUUID(),items},onSaved);
  }

  const issuesFor=model=>rowErrors[model.clientRowId]||serverErrors.filter(issue=>issue.clientRowId===model.clientRowId).map(issue=>issue.message).join(" ");
  const uploadDisabled=disabled||Boolean(models.length&&!importIssues.length);
  return <RecordEditorFrame title="Importer des modèles de suivi" subtitle="Vérifiez les modèles et leurs étapes avant de les enregistrer."
    icon="folder" onClose={onClose} onSubmit={submit} busy={busy} dirty={Boolean(models.length||mutation.uncertain)}
    readOnly={!canManage} canSubmit={models.length>0&&!importIssues.length}
    submitLabel={mutation.uncertain?"Vérifier l’enregistrement":"Enregistrer le panier ("+models.length+")"}
    error={error||mutation.error} defaultWidth={1180} className="support-editor support-process-editor support-batch-editor"
    storageKey="sauverndeko.support.process-batch.width"
    discardMessage={mutation.uncertain?"Fermer n’annule pas un éventuel enregistrement. Vérifiez le registre avant une nouvelle saisie.":undefined}>
    <section className="record-editor-section">
      <label className="support-field"><span>Fichier Excel .xlsx · 4 Mo maximum</span>
        <input type="file" accept=".xlsx,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
          disabled={uploadDisabled} onChange={importWorkbook}/></label>
      {fileName?<p className="record-editor-note">{fileName} · {models.length} {models.length===1?"modèle":"modèles"} dans le panier.</p>:
        <p className="record-editor-note">Remplissez le modèle Excel, puis choisissez le fichier.</p>}
      {importIssues.length?<div role="alert">
        <p>Corrigez les lignes signalées dans le classeur, puis importez-le à nouveau. Le nouveau fichier remplace le panier.</p>
        <ul>{importIssues.map((issue,index)=><li key={index}>{issue.row?"Ligne "+issue.row+" · ":""}{issue.message}</li>)}</ul>
      </div>:null}
    </section>
    {selected?<div className="support-batch-layout">
      <nav className="support-batch-rows" aria-label="Modèles du panier">{models.map((model,index)=><div className="support-batch-row" key={model.clientRowId}>
        <button type="button" aria-current={model===selected?"true":undefined} onClick={()=>setSelectedId(model.clientRowId)}>
          <strong>{index+1}. {model.values.name||"Nom à compléter"}</strong>
          <small>{issuesFor(model)||importRowIssues[model.clientRowId]?.length?"À corriger":model.values.stages.length+" étape(s)"}</small>
        </button>
        <ActionButton icon="close" aria-label={"Retirer le modèle "+(index+1)} disabled={disabled} onClick={()=>remove(model.clientRowId)}/>
      </div>)}</nav>
      <div className="support-batch-fields">
        {importRowIssues[selected.clientRowId]?.length?<section className="record-editor-section">
          <h3>Lignes Excel à vérifier</h3>
          <ul>{importRowIssues[selected.clientRowId].map((issue,index)=><li key={index}>
            {issue.row?"Ligne "+issue.row+" · ":""}{issue.message}
          </li>)}</ul>
          <ActionButton icon="check-circle" disabled={disabled} onClick={confirmCorrection}>Confirmer la correction</ActionButton>
        </section>:null}
        {issuesFor(selected)?<p className="record-field-error" role="alert">{issuesFor(selected)}</p>:null}
        <SupportProcessModelFields key={selected.clientRowId} values={selected.values} references={references}
          editable={canManage} disabled={disabled} onChange={update}/>
      </div>
    </div>:null}
  </RecordEditorFrame>;
}
