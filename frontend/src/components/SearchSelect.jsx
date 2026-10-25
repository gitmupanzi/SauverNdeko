import {useEffect,useId,useLayoutEffect,useRef,useState} from "react";
import {createPortal} from "react-dom";
import AppIcon from "./AppIcon";
import "./SearchSelect.css";
export default function SearchSelect({id,label,value,onChange,options=[],disabled=false,invalid=false,describedBy,placeholder="Choisir…",loading=false}){
 const generated=useId(),listId=generated+"-list",anchor=useRef(null),panel=useRef(null),search=useRef(null);
 const [open,setOpen]=useState(false),[query,setQuery]=useState(""),[position,setPosition]=useState({left:0,top:0,width:240});
 const selected=options.find(option=>String(option.value)===String(value));
 const normalize=text=>String(text||"").normalize("NFD").replace(/[\u0300-\u036f]/g,"").toLowerCase();
 const filtered=options.filter(option=>normalize(option.label).includes(normalize(query)));
 function close(restore=false){setOpen(false);if(restore)anchor.current?.focus({preventScroll:true});}
 function choose(option){onChange(String(option.value));close(true);}
 useLayoutEffect(()=>{
  if(!open)return;
  const menu=panel.current;
  try{menu.showPopover?.();}catch{}
  function place(){
   if(!anchor.current?.isConnected){setOpen(false);return;}
   const rect=anchor.current.getBoundingClientRect(),width=Math.min(Math.max(rect.width,240),window.innerWidth-24);
   const height=Math.min(320,menu.scrollHeight||320),below=window.innerHeight-rect.bottom-12;
   setPosition({left:Math.max(12,Math.min(rect.left,window.innerWidth-width-12)),width,top:below>=height?rect.bottom+6:Math.max(12,rect.top-height-6)});
  }
  place();const frame=requestAnimationFrame(()=>search.current?.focus());
  function outside(event){if(!menu.contains(event.target)&&!anchor.current?.contains(event.target))close();}
  function escape(event){if(event.key==="Escape"){event.preventDefault();event.stopPropagation();close(true);}}
  window.addEventListener("resize",place);window.addEventListener("scroll",place,true);document.addEventListener("pointerdown",outside,true);document.addEventListener("keydown",escape,true);
  return()=>{cancelAnimationFrame(frame);window.removeEventListener("resize",place);window.removeEventListener("scroll",place,true);document.removeEventListener("pointerdown",outside,true);document.removeEventListener("keydown",escape,true);};
 },[open,query,filtered.length]);
 useEffect(()=>{if(disabled)close();},[disabled]);
 function navigate(event){
  if(event.key==="Tab"){close(true);return;}
  if(!["ArrowDown","ArrowUp","Home","End"].includes(event.key))return;
  event.preventDefault();
  const choices=[...panel.current.querySelectorAll('[role="option"]:not(:disabled)')],index=choices.indexOf(document.activeElement);
  if(!choices.length)return;
  const next=event.key==="Home"?0:event.key==="End"?choices.length-1:(index+(event.key==="ArrowDown"?1:-1)+choices.length)%choices.length;
  choices[next].focus();
 }
 return <><button ref={anchor} id={id} type="button" role="combobox" aria-label={label} aria-expanded={open} aria-controls={open?listId:undefined} aria-haspopup="listbox" aria-invalid={invalid} aria-describedby={describedBy} disabled={disabled||loading} className={"search-select-trigger"+(!selected?" is-placeholder":"")} onClick={()=>{setQuery("");setOpen(current=>!current);}} onKeyDown={event=>{if(["ArrowDown","ArrowUp"].includes(event.key)){event.preventDefault();setQuery("");setOpen(true);}}}><span>{loading?"Chargement…":selected?.label||placeholder}</span><AppIcon name="chevron-down"/></button>
 {open?createPortal(<div ref={panel} className="search-select-panel" popover="manual" style={position} onKeyDown={navigate}>
  <label className="search-select-search"><AppIcon name="search"/><input ref={search} type="search" aria-label={"Rechercher · "+label} placeholder="Rechercher…" value={query} onChange={event=>setQuery(event.target.value)}/></label>
  <div id={listId} role="listbox" aria-label={label} className="search-select-options">{filtered.length?filtered.map(option=><button type="button" role="option" key={option.value} aria-selected={String(option.value)===String(value)} disabled={option.disabled} onClick={()=>choose(option)}><span>{option.label}</span>{String(option.value)===String(value)?<AppIcon name="check-circle"/>:null}</button>):<p role="status">Aucun résultat.</p>}</div>
  <div className="search-select-footer">{filtered.length} option{filtered.length>1?"s":""}</div>
 </div>,anchor.current?.closest("dialog")||document.body):null}</>;
}
