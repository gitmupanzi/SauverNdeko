import {useEffect,useId,useRef,useState} from "react";
import DrawerDialog from "./DrawerDialog";
import ActionButton from "./ActionButton";
import "./RecordEditor.css";
export default function RecordEditorFrame({title,subtitle,icon="edit",children,onClose,onSubmit,busy=false,loading=false,dirty=false,canSubmit=true,error="",onReload,submitLabel="Enregistrer",defaultWidth=800,className="",storageKey="sauverndeko.record-editor.width"}) {
  const id=useId(),[discard,setDiscard]=useState(false);
  const formRef=useRef(null),discardRef=useRef(null),discardOrigin=useRef(null),restoreFocus=useRef(false);
  useEffect(()=>{
    if(discard){discardRef.current?.querySelector("button:not(:disabled)")?.focus({preventScroll:true});return;}
    if(!restoreFocus.current)return;
    restoreFocus.current=false;
    const origin=discardOrigin.current;
    discardOrigin.current=null;
    const firstField=Array.from(formRef.current?.querySelectorAll('input:not([type="hidden"]):not(:disabled),select:not(:disabled),textarea:not(:disabled),[role="combobox"]:not(:disabled)')||[]).find(field=>field.getClientRects().length>0) || formRef.current?.querySelector('button:not(:disabled)');
    (origin?.isConnected?origin:firstField)?.focus({preventScroll:true});
  },[discard]);
  function continueEditing(){if(busy)return;restoreFocus.current=true;setDiscard(false);}
  function close(){if(busy)return;if(discard){continueEditing();return;}if(dirty){discardOrigin.current=document.activeElement;setDiscard(true);}else onClose();}
  return <DrawerDialog title={title} subtitle={subtitle} icon={icon} onClose={close} busy={busy} defaultWidth={defaultWidth} className={className} storageKey={storageKey} bodyClassName="record-editor-body" footer={<footer className="record-editor-footer">
    {discard?<div ref={discardRef} className="record-discard" role="alert"><span>Abandonner les modifications ?</span><div><ActionButton disabled={busy} onClick={continueEditing}>Continuer</ActionButton><ActionButton disabled={busy} onClick={onClose}>Abandonner</ActionButton></div></div>:<><span>{dirty?"Modifications non enregistrées":""}</span><div><ActionButton disabled={busy} onClick={close}>Annuler</ActionButton><ActionButton icon="check-circle" form={id} type="submit" variant="primary" disabled={busy||loading||!canSubmit}>{busy?"Enregistrement…":submitLabel}</ActionButton></div></>}
  </footer>}>
    {loading?<p className="record-editor-state" role="status">Chargement de la fiche…</p>:null}
    {error?<div className="record-editor-error" role="alert"><span>{error}</span>{onReload?<ActionButton icon="refresh" onClick={onReload} disabled={busy}>Recharger la fiche</ActionButton>:null}</div>:null}
    <form ref={formRef} id={id} noValidate onSubmit={event=>{event.preventDefault();if(!busy&&!loading&&canSubmit)onSubmit();}}>{children}</form>
  </DrawerDialog>;
}
