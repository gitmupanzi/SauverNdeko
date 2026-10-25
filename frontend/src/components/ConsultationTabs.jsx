import { useId, useLayoutEffect, useRef } from "react";
import AppIcon from "./AppIcon";
import "./ConsultationTabs.css";

export default function ConsultationTabs({ tabs=[], value, onChange, label="Rubriques", idPrefix }) {
  const generated=useId(), strip=useRef(null), tabRefs=useRef(new Map());
  const prefix=idPrefix || generated;
  const enabled=tabs.filter(tab=>!tab.disabled);
  const activeKey=(enabled.find(tab=>tab.key===value) || enabled[0])?.key;
  const tabsKey=tabs.map(tab=>String(tab.key)+":"+Boolean(tab.disabled)).join("|");
  useLayoutEffect(()=>{
    const container=strip.current, active=tabRefs.current.get(activeKey);
    if(!container || !active)return;
    function reveal(){
      const bounds=container.getBoundingClientRect(), item=active.getBoundingClientRect();
      const delta=item.left<bounds.left+4 ? item.left-bounds.left-4 : item.right>bounds.right-4 ? item.right-bounds.right+4 : 0;
      // Défilement horizontal seulement : changer de rubrique ne déplace pas la page.
      if(delta)container.scrollTo({left:container.scrollLeft+delta,behavior:"auto"});
    }
    reveal();
    const observer=typeof ResizeObserver==="function" ? new ResizeObserver(reveal) : null;
    observer?.observe(container); observer?.observe(active);
    window.addEventListener("resize",reveal);
    return()=>{observer?.disconnect();window.removeEventListener("resize",reveal);};
  },[activeKey,tabsKey]);
  function activate(key,focus=false){
    if(focus)tabRefs.current.get(key)?.focus({preventScroll:true});
    if(key!==value)onChange?.(key);
  }
  function navigate(event,key){
    if(!["ArrowLeft","ArrowRight","Home","End"].includes(event.key) || !enabled.length)return;
    event.preventDefault();
    const index=Math.max(0,enabled.findIndex(tab=>tab.key===key));
    const next=event.key==="Home" ? 0 : event.key==="End" ? enabled.length-1 : (index+(event.key==="ArrowRight"?1:-1)+enabled.length)%enabled.length;
    activate(enabled[next].key,true);
  }
  return <div ref={strip} className="consultation-tabs" role="tablist" aria-label={label} aria-orientation="horizontal">
    {tabs.map(tab=><button ref={element=>{if(element)tabRefs.current.set(tab.key,element);else tabRefs.current.delete(tab.key);}} key={tab.key} id={prefix+"-tab-"+tab.key} type="button" role="tab" className="consultation-tabs__tab" aria-selected={tab.key===activeKey} aria-controls={prefix+"-panel-"+tab.key} tabIndex={tab.key===activeKey?0:-1} disabled={tab.disabled} onClick={()=>activate(tab.key)} onKeyDown={event=>navigate(event,tab.key)}>{tab.icon?<AppIcon name={tab.icon} size={16}/>:null}<span>{tab.label}</span></button>)}
  </div>;
}
