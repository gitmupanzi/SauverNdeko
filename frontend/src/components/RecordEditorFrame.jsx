import {useEffect,useId,useRef,useState} from "react";
import DrawerDialog from "./DrawerDialog";
import ActionButton from "./ActionButton";
import "./RecordEditor.css";
export default function RecordEditorFrame({title,subtitle,icon="edit",children,onClose,onSubmit,busy=false,loading=false,dirty=false,readOnly=false,canSubmit=true,error="",onReload,submitLabel="Enregistrer",defaultWidth=800,className="",storageKey="sauverndeko.record-editor.width",discardMessage="Abandonner les modifications ?",discardLabel="Abandonner"}) {
  const id=useId(),[discard,setDiscard]=useState(false);
  const formRef=useRef(null),errorRef=useRef(null),announcedError=useRef(""),initialFocus=useRef(false),discardRef=useRef(null),discardOrigin=useRef(null),restoreFocus=useRef(false);
  useEffect(()=>{
    if(initialFocus.current||readOnly||loading||busy||error||discard)return;
    const frame=requestAnimationFrame(()=>{
      if(formRef.current?.contains?.(document.activeElement)){initialFocus.current=true;return;}
      const field=Array.from(formRef.current?.querySelectorAll('input:not([type="hidden"]):not(:disabled):not([readonly]),select:not(:disabled),textarea:not(:disabled):not([readonly]),[role="combobox"]:not(:disabled)')||[]).find(item=>item.getClientRects().length>0);
      if(field){field.focus({preventScroll:true});initialFocus.current=true;}
    });
    return()=>cancelAnimationFrame(frame);
  },[readOnly,loading,busy,error,discard]);
  useEffect(()=>{
    if(!error){announcedError.current="";return;}
    if(busy||discard||announcedError.current===error)return;
    announcedError.current=error;
    const frame=requestAnimationFrame(()=>{
      const invalid=Array.from(formRef.current?.querySelectorAll('[aria-invalid="true"]:not(:disabled)')||[]).find(field=>field.getClientRects().length>0);
      const target=invalid||errorRef.current;
      target?.focus({preventScroll:true});
      target?.scrollIntoView?.({block:"nearest"});
    });
    return()=>cancelAnimationFrame(frame);
  },[error,busy,discard]);
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
    {discard?<div ref={discardRef} className="record-discard" role="alert"><span>{discardMessage}</span><div><ActionButton disabled={busy} onClick={continueEditing}>Continuer</ActionButton><ActionButton variant="danger" disabled={busy} onClick={()=>{if(!busy)onClose();}}>{discardLabel}</ActionButton></div></div>:<><span role="status" aria-live="polite" aria-atomic="true">{busy?"Enregistrement en cours…":dirty?"Modifications non enregistrées":""}</span><div><ActionButton disabled={busy} onClick={close}>{readOnly?"Fermer":"Annuler"}</ActionButton>{!readOnly?<ActionButton icon="check-circle" form={id} type="submit" variant="primary" disabled={busy||loading||!canSubmit}>{busy?"Enregistrement…":submitLabel}</ActionButton>:null}</div></>}
  </footer>}>
    {loading?<p className="record-editor-state" role="status">Chargement de la fiche…</p>:null}
    {error?<div ref={errorRef} id={id+"-error"} tabIndex={-1} className="record-editor-error" role="alert"><span>{error}</span>{onReload?<ActionButton icon="refresh" onClick={onReload} disabled={busy}>Recharger la fiche</ActionButton>:null}</div>:null}
    <form ref={formRef} id={id} noValidate aria-busy={busy||loading} aria-describedby={error?id+"-error":undefined} inert={discard?true:undefined} aria-hidden={discard?true:undefined} onSubmit={event=>{event.preventDefault();if(!discard&&!readOnly&&!busy&&!loading&&canSubmit)onSubmit();}}>{children}</form>
  </DrawerDialog>;
}
