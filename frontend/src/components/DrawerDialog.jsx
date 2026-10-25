import { useCallback, useEffect, useId, useRef, useState } from "react";
import { createPortal } from "react-dom";
import AppIcon from "./AppIcon";
import "./DrawerDialog.css";
export default function DrawerDialog({ children, title, subtitle, icon, onClose, onBack, id, titleId, className="", headerClassName="", bodyClassName="", closeClassName="", closeLabel="Fermer la fenêtre", storageKey="sauverndeko.drawer.width", defaultWidth=680, top=null, footer=null, busy=false }) {
  const generated=useId(),heading=titleId || generated,dialogId=id || generated+"-drawer";
  const elementRef=useRef(null),closeRef=useRef(null),origin=useRef(null),drag=useRef(null);
  const [width,setWidth]=useState(()=>{try{const saved=Number(localStorage.getItem(storageKey));return Number.isFinite(saved) && saved>0?saved:defaultWidth;}catch{return defaultWidth;}});
  const [viewport,setViewport]=useState(window.innerWidth);
  const min=Math.min(480,viewport),max=Math.max(min,Math.floor(viewport*.94));
  const actual=Math.min(max,Math.max(min,width));
  const resize=useCallback(next=>setWidth(Math.min(max,Math.max(min,next))),[min,max]);
  useEffect(()=>{const listener=()=>setViewport(window.innerWidth);window.addEventListener("resize",listener);return()=>window.removeEventListener("resize",listener);},[]);
  useEffect(()=>{if(viewport<=640)return;try{localStorage.setItem(storageKey,String(actual));}catch{/* Préférence facultative. */}},[actual,storageKey,viewport]);
  useEffect(()=>{origin.current=document.activeElement;const element=elementRef.current,previous=document.body.style.overflow;document.body.style.overflow="hidden";element.showModal();closeRef.current?.focus();return()=>{document.body.style.overflow=previous;element.close();if(origin.current?.isConnected)origin.current.focus({preventScroll:true});};},[]);
  const requestClose=()=>{if(!busy)onClose();};
  return createPortal(<dialog ref={elementRef} id={dialogId} className={"resizable-drawer "+className} style={{"--drawer-width":actual+"px","--consultation-width":actual+"px"}} aria-labelledby={heading} aria-busy={busy} onCancel={event=>{event.preventDefault();requestClose();}} onClick={event=>{if(event.target!==event.currentTarget || drag.current)return;const rect=event.currentTarget.getBoundingClientRect();if(event.clientX<rect.left || event.clientX>rect.right)requestClose();}}>
    <header className={"drawer-header "+headerClassName}>{icon?<span className="drawer-mark"><AppIcon name={icon} size={22}/></span>:null}<div className="drawer-heading">{onBack?<button type="button" className="consult-back" onClick={onBack} disabled={busy}><AppIcon name="chevron-left"/>Retour</button>:null}<h2 id={heading}>{title}</h2>{subtitle?<p>{subtitle}</p>:null}</div>
      <div className="drawer-controls consult-actions"><div className="drawer-width-actions consult-width-actions" role="group" aria-label="Largeur de la fenêtre"><button type="button" aria-label="Réduire" title="Réduire" disabled={actual<=min} onClick={()=>resize(actual-160)}><AppIcon name="panel-narrow"/></button><button type="button" aria-label="Élargir" title="Élargir" disabled={actual>=max} onClick={()=>resize(actual+160)}><AppIcon name="panel-widen"/></button><button type="button" aria-label="Rétablir la largeur" title="Rétablir la largeur" onClick={()=>resize(defaultWidth)}><AppIcon name="reset"/></button></div><button ref={closeRef} type="button" className={"drawer-close "+closeClassName} aria-label={closeLabel} title="Fermer" disabled={busy} onClick={requestClose}><AppIcon name="close"/></button></div>
    </header>
    <div className="drawer-resize" role="separator" tabIndex="0" aria-label="Redimensionner la fenêtre" aria-orientation="vertical" aria-controls={dialogId} aria-valuemin={min} aria-valuemax={max} aria-valuenow={actual} aria-valuetext={actual+" pixels"} onPointerDown={event=>{event.currentTarget.setPointerCapture(event.pointerId);drag.current={x:event.clientX,width:actual};}} onPointerMove={event=>{if(drag.current)resize(drag.current.width+drag.current.x-event.clientX);}} onPointerUp={event=>{drag.current=null;event.currentTarget.releasePointerCapture(event.pointerId);}} onPointerCancel={()=>{drag.current=null;}} onDoubleClick={()=>resize(defaultWidth)} onKeyDown={event=>{if(!["ArrowLeft","ArrowRight","Home","End"].includes(event.key))return;event.preventDefault();const step=event.shiftKey?128:32;resize(event.key==="Home"?min:event.key==="End"?max:actual+(event.key==="ArrowLeft"?step:-step));}}/>
    {top}<div className={"drawer-body "+bodyClassName}>{children}</div>{footer}
  </dialog>,document.body);
}
