import { useId, useLayoutEffect, useRef, useState } from "react";
import { createPortal } from "react-dom";
import "./HeaderPopover.css";

// Shared positioning and keyboard dismissal for account and notification panels.
export default function HeaderPopover({ anchor, label, role="dialog", width=320, onClose, children, className="", id:providedId }) {
  const panel=useRef(null), generated=useId(), id=providedId||generated;
  const [position,setPosition]=useState({left:12,top:72,maxHeight:500,width:Math.min(width,document.documentElement.clientWidth-24)});
  useLayoutEffect(()=>{
    const element=panel.current;
    try { element.showPopover?.(); } catch { /* Fixed positioning fallback. */ }
    const place=()=>{
      if(!anchor.current?.isConnected)return onClose();
      const rect=anchor.current.getBoundingClientRect(), viewportWidth=document.documentElement.clientWidth, size=Math.min(width,viewportWidth-24);
      const top=Math.max(12,Math.min(rect.bottom+10,window.innerHeight-160));
      setPosition({left:Math.max(12,Math.min(rect.right-size,viewportWidth-size-12)),top,width:size,maxHeight:Math.max(120,window.innerHeight-top-12)});
    };
    place();
    const frame=requestAnimationFrame(()=>(element.querySelector('[aria-checked=true]')||element.querySelector('[role=menuitem],button,a[href],input'))?.focus({preventScroll:true}));
    const outside=event=>{if(!element.contains(event.target)&&!anchor.current?.contains(event.target))onClose();};
    const escape=event=>{if(event.key==='Escape'){event.preventDefault();event.stopPropagation();onClose(true);}};
    document.addEventListener('pointerdown',outside,true);document.addEventListener('focusin',outside,true);document.addEventListener('keydown',escape,true);
    window.addEventListener('resize',place);window.addEventListener('scroll',place,true);
    return()=>{cancelAnimationFrame(frame);document.removeEventListener('pointerdown',outside,true);document.removeEventListener('focusin',outside,true);document.removeEventListener('keydown',escape,true);window.removeEventListener('resize',place);window.removeEventListener('scroll',place,true);};
  },[anchor,onClose,width]);
  function keyboard(event){
    if(role==="menu"&&event.key==="Tab"){onClose(true);return;}
    if(role!=='menu'||!['ArrowDown','ArrowUp','Home','End'].includes(event.key))return;
    event.preventDefault();const items=[...panel.current.querySelectorAll(':is([role=menuitem],[role=menuitemradio]):not(:disabled)')], current=items.indexOf(document.activeElement);
    items[event.key==='Home'?0:event.key==='End'?items.length-1:(current+(event.key==='ArrowUp'?-1:1)+items.length)%items.length]?.focus();
  }
  return createPortal(<div ref={panel} id={id} className={'account-popover '+className} popover="manual" role={role} aria-label={label} style={position} onKeyDown={keyboard}>{children}</div>,anchor.current?.closest("dialog")||document.body);
}
