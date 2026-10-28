import { useCallback, useId, useRef, useState } from "react";
import ActionButton from "./ActionButton";
import AppIcon from "./AppIcon";
import HeaderPopover from "./HeaderPopover";
import "./RegisterSettingsButton.css";

// One header entry point keeps personal table choices and shared references distinct.
export default function RegisterSettingsButton({ buttonRef, expanded=false, onTableSettings, onReferences }) {
  const ownAnchor=useRef(null), anchor=buttonRef||ownAnchor, menuId=useId();
  const [open,setOpen]=useState(false), hasReferences=typeof onReferences==="function";
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
    <ActionButton ref={anchor} icon="settings" aria-haspopup={hasReferences?"menu":"dialog"} aria-expanded={open||expanded} aria-controls={hasReferences&&open?menuId:undefined} onClick={()=>hasReferences?setOpen(value=>!value):onTableSettings?.()}>Réglages</ActionButton>
    {open&&hasReferences?<HeaderPopover id={menuId} anchor={anchor} label="Réglages du registre" role="menu" width={248} onClose={close} className="register-settings-menu">
      <button type="button" role="menuitem" onClick={()=>choose(onTableSettings)}><AppIcon name="columns"/><span>Tableau et exports</span></button>
      <button type="button" role="menuitem" onClick={()=>choose(onReferences)}><AppIcon name="list"/><span>Références</span></button>
    </HeaderPopover>:null}
  </>;
}
