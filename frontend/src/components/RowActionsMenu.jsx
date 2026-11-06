import { useEffect, useId, useLayoutEffect, useRef, useState } from "react";
import { createPortal } from "react-dom";
import AppIcon from "./AppIcon";
import "./RowActionsMenu.css";
export default function RowActionsMenu({ label, items, triggerText="", triggerIcon="more", selectedValue, disabled=false, triggerClassName, triggerTitle }) {
  const [open,setOpen] = useState(false);
  const [position,setPosition] = useState({left:0,top:0});
  const anchor=useRef(null), panel=useRef(null);
  const id=useId();
  const close=(restore=false) => { setOpen(false); if(restore) anchor.current?.focus({preventScroll:true}); };
  useLayoutEffect(() => {
    if (disabled && open) { setOpen(false); return; }
    if(!open || !panel.current) return;
    const menu=panel.current;
    try { menu.showPopover?.(); } catch { /* Positionnement fixe de repli. */ }
    const place=() => {
      const rect=anchor.current.getBoundingClientRect();
      const width=Math.min(240,window.innerWidth-24);
      const height=menu.getBoundingClientRect().height;
      const top=rect.bottom+8+height>window.innerHeight-12 ? Math.max(12,rect.top-height-8) : rect.bottom+8;
      setPosition({left:Math.max(12,Math.min(rect.right-width,window.innerWidth-width-12)),top});
    };
    place(); window.addEventListener("resize",place); window.addEventListener("scroll",place,true);
    const frame=requestAnimationFrame(()=>(menu.querySelector('[aria-checked=true]') || menu.querySelector('button:not(:disabled)'))?.focus());
    const outside=event => { if(!menu.contains(event.target) && !anchor.current?.contains(event.target)) close(); };
    const escape=event => { if(event.key === "Escape") { event.preventDefault();event.stopPropagation();close(true); } };
    document.addEventListener("pointerdown",outside,true); document.addEventListener("keydown",escape,true);
    return () => {cancelAnimationFrame(frame);window.removeEventListener("resize",place);window.removeEventListener("scroll",place,true);document.removeEventListener("pointerdown",outside,true);document.removeEventListener("keydown",escape,true);};
  },[open, disabled]);
  useEffect(()=>{ if(!open) return; const dismiss=event=>{if(!anchor.current?.isConnected)close();}; window.addEventListener("resize",dismiss); return()=>window.removeEventListener("resize",dismiss); },[open]);
  function navigate(event) {
    if(event.key === "Tab") { close(true); return; }
    if(!["ArrowDown","ArrowUp","Home","End"].includes(event.key)) return;
    event.preventDefault();const buttons=[...panel.current.querySelectorAll('button:not(:disabled)')];const current=buttons.indexOf(document.activeElement);
    const index=event.key === "Home" ? 0 : event.key === "End" ? buttons.length-1 : (current+(event.key === "ArrowDown" ? 1 : -1)+buttons.length)%buttons.length;
    buttons[index]?.focus();
  }
  const expanded = open && !disabled;
  return <>
    <button
      ref={anchor}
      type="button"
      className={triggerClassName || (triggerText ? "erp-view-menu-trigger" : "erp-row-menu-trigger")}
      disabled={disabled}
      aria-label={triggerText ? label + " : " + triggerText : "Actions · " + label}
      aria-haspopup="menu"
      aria-expanded={expanded}
      aria-controls={expanded ? id : undefined}
      title={triggerTitle || (triggerText ? "Changer l’affichage" : "Actions")}
      onClick={event => { event.stopPropagation(); setOpen(value => !value); }}
      onKeyDown={event => {
        if (event.key === "ArrowDown") { event.preventDefault(); setOpen(true); }
      }}
    >
      <AppIcon name={triggerIcon} size={triggerText ? 16 : 19}/>
      {triggerText ? <><span>{triggerText}</span><AppIcon name="chevron-down" size={13}/></> : null}
    </button>
    {expanded ? createPortal(<div ref={panel} id={id} role="menu" aria-label={triggerText?label:"Actions · "+label} className="erp-row-menu" popover="manual" style={{left:position.left,top:position.top}} onKeyDown={navigate}>
      {items.map(item=><button key={item.label} type="button" role={item.value?"menuitemradio":"menuitem"} aria-checked={item.value?item.value===selectedValue:undefined} disabled={item.disabled} className={item.danger?"is-danger":""} title={item.reason || undefined} onClick={event=>{event.stopPropagation();close(true);item.onSelect();}}><AppIcon name={item.icon}/><span>{item.label}</span>{item.value && item.value===selectedValue?<AppIcon name="check-circle" className="erp-menu-selected" size={15}/>:null}</button>)}
    </div>,anchor.current?.closest("dialog") || document.body) : null}</>;
}
