import { useCallback, useId, useRef, useState } from "react";
import ActionButton from "./ActionButton";
import AppIcon from "./AppIcon";
import HeaderPopover from "./HeaderPopover";
import "./RegisterSettingsButton.css";

// One header entry point keeps personal table choices and shared references distinct.
export default function RegisterSettingsButton({ buttonRef, expanded=false, onTableSettings, onReferences, extraItems=[] }) {
  const ownAnchor=useRef(null), anchor=buttonRef||ownAnchor, menuId=useId();
  const [open,setOpen]=useState(false), hasReferences=typeof onReferences==="function";
  const hasMenu=hasReferences||extraItems.length>0;
  const close=useCallback((restoreFocus=false)=>{
    setOpen(false);
    if(restoreFocus)anchor.current?.focus({preventScroll:true});
  },[anchor]);
  function choose(callback){
    // Restore the persistent origin before the menu disappears and the drawer opens.
    anchor.current?.focus({preventScroll:true});
    setOpen(false);
    callback?.();
  }
  return <>
    <ActionButton ref={anchor} icon="settings" aria-haspopup={hasMenu?"menu":"dialog"} aria-expanded={open||expanded} aria-controls={hasMenu&&open?menuId:undefined} onClick={()=>hasMenu?setOpen(value=>!value):onTableSettings?.()}>Réglages</ActionButton>
    {open&&hasMenu?<HeaderPopover id={menuId} anchor={anchor} label="Réglages du registre" role="menu" width={248} onClose={close} className="register-settings-menu">
      <button type="button" role="menuitem" onClick={()=>choose(onTableSettings)}><AppIcon name="columns"/><span>Tableau et exports</span></button>
      {hasReferences?<button type="button" role="menuitem" onClick={()=>choose(onReferences)}><AppIcon name="list"/><span>Références</span></button>:null}
      {extraItems.map(item=><button key={item.label} type="button" role="menuitem" onClick={()=>choose(item.onSelect)}><AppIcon name={item.icon}/><span>{item.label}</span></button>)}
    </HeaderPopover>:null}
  </>;
}
