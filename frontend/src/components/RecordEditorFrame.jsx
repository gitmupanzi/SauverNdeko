import {useId,useState} from "react";
import DrawerDialog from "./DrawerDialog";
import ActionButton from "./ActionButton";
import "./RecordEditor.css";
export default function RecordEditorFrame({title,subtitle,icon="edit",children,onClose,onSubmit,busy=false,loading=false,dirty=false,canSubmit=true,error="",onReload,storageKey="sauverndeko.record-editor.width"}) {
  const id=useId(),[discard,setDiscard]=useState(false);
  function close(){if(busy)return;if(dirty)setDiscard(value=>!value);else onClose();}
  return <DrawerDialog title={title} subtitle={subtitle} icon={icon} onClose={close} busy={busy} defaultWidth={800} storageKey={storageKey} bodyClassName="record-editor-body" footer={<footer className="record-editor-footer">
    {discard?<div className="record-discard" role="alert"><span>Abandonner les modifications ?</span><div><ActionButton onClick={()=>setDiscard(false)}>Continuer</ActionButton><ActionButton onClick={onClose}>Abandonner</ActionButton></div></div>:<><span>{dirty?"Modifications non enregistrées":""}</span><div><ActionButton disabled={busy} onClick={close}>Annuler</ActionButton><ActionButton icon="check-circle" form={id} type="submit" variant="primary" disabled={busy||loading||!canSubmit}>{busy?"Enregistrement…":"Enregistrer"}</ActionButton></div></>}
  </footer>}>
    {loading?<p className="record-editor-state" role="status">Chargement de la fiche…</p>:null}
    {error?<div className="record-editor-error" role="alert"><span>{error}</span>{onReload?<ActionButton icon="refresh" onClick={onReload} disabled={busy}>Recharger la fiche</ActionButton>:null}</div>:null}
    <form id={id} noValidate onSubmit={event=>{event.preventDefault();if(!busy&&!loading&&canSubmit)onSubmit();}}>{children}</form>
  </DrawerDialog>;
}
