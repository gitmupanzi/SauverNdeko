import {useEffect,useId,useLayoutEffect,useRef,useState} from "react";
import {createPortal} from "react-dom";
import AppIcon from "./AppIcon";
import "./SearchSelect.css";
export default function SearchSelect({id,label,value,onChange,options=[],disabled=false,invalid=false,describedBy,placeholder="Choisir…",loading=false,remote=false,onSearchChange,onLoadMore,hasMore=false,optionsLoading=false,moreLoading=false,optionsError="",onOptionsRetry}){
 const generated=useId(),listId=generated+"-list",statusId=generated+"-status",anchor=useRef(null),panel=useRef(null),search=useRef(null),choiceLabel=label||"Choix";
 const [open,setOpen]=useState(false),[query,setQuery]=useState(""),[position,setPosition]=useState({left:0,top:0,width:240});
 const selected=options.find(option=>String(option.value)===String(value));
 const normalize=text=>String(text||"").normalize("NFD").replace(/[\u0300-\u036f]/g,"").toLowerCase();
 const filtered=remote?options:options.filter(option=>normalize(option.label).includes(normalize(query).trim()));
 function searchChanged(value){setQuery(value);onSearchChange?.(value);}
 function close(restore=false){setOpen(false);if(restore)anchor.current?.focus({preventScroll:true});}
 function choose(option){if(disabled||loading||optionsLoading||option.disabled)return;onChange(String(option.value));close(true);}
 useLayoutEffect(()=>{
  if(!open)return;
  const menu=panel.current;
  try{menu.showPopover?.();}catch{}
  function place(){
   if(!anchor.current?.isConnected){setOpen(false);return;}
   const rect=anchor.current.getBoundingClientRect(),view=window.visualViewport;
   const left=view?.offsetLeft||0,top=view?.offsetTop||0,viewWidth=view?.width||window.innerWidth,viewHeight=view?.height||window.innerHeight;
   if(rect.bottom<=top+12||rect.top>=top+viewHeight-12){close();return;}
   const width=Math.max(1,Math.min(Math.max(rect.width,240),viewWidth-24));
   const below=Math.max(0,top+viewHeight-rect.bottom-18),above=Math.max(0,rect.top-top-18),showBelow=below>=240||below>=above;
   const maxHeight=Math.min(340,showBelow?below:above),height=Math.min(maxHeight,menu.scrollHeight||340);
   setPosition({left:Math.max(left+12,Math.min(rect.left,left+viewWidth-width-12)),width,maxHeight,top:showBelow?rect.bottom+6:Math.max(top+12,rect.top-height-6)});
  }
  place();
  function outside(event){if(!menu.contains(event.target)&&!anchor.current?.contains(event.target))close();}
  function escape(event){if(event.key==="Escape"){event.preventDefault();event.stopPropagation();close(true);}}
  window.addEventListener("resize",place);window.addEventListener("scroll",place,true);window.visualViewport?.addEventListener("resize",place);window.visualViewport?.addEventListener("scroll",place);document.addEventListener("pointerdown",outside,true);document.addEventListener("keydown",escape,true);
  return()=>{window.removeEventListener("resize",place);window.removeEventListener("scroll",place,true);window.visualViewport?.removeEventListener("resize",place);window.visualViewport?.removeEventListener("scroll",place);document.removeEventListener("pointerdown",outside,true);document.removeEventListener("keydown",escape,true);};
 },[open,query,filtered.length,optionsLoading,optionsError,hasMore]);
 useEffect(()=>{if(!open)return;const frame=requestAnimationFrame(()=>search.current?.focus({preventScroll:true}));return()=>cancelAnimationFrame(frame);},[open]);
 useEffect(()=>{if(disabled||loading)close();},[disabled,loading]);
 function navigate(event){
  if(event.key==="Tab"){close(true);return;}
  // Dans le champ de recherche, Début/Fin restent des commandes de saisie.
  if(event.target===search.current&&["Home","End"].includes(event.key))return;
  if(!["ArrowDown","ArrowUp","Home","End"].includes(event.key))return;
  event.preventDefault();
  const choices=[...panel.current.querySelectorAll('[role="option"]:not(:disabled),[data-option-command]:not(:disabled)')],index=choices.indexOf(document.activeElement);
  if(!choices.length)return;
  const next=event.key==="Home"?0:event.key==="End"?choices.length-1:index<0?(event.key==="ArrowUp"?choices.length-1:0):(index+(event.key==="ArrowDown"?1:-1)+choices.length)%choices.length;
  choices[next].focus();
 }
 return <><button ref={anchor} id={id||generated+"-trigger"} type="button" role="combobox" aria-label={choiceLabel} aria-expanded={open} aria-controls={open?listId:undefined} aria-haspopup="listbox" aria-invalid={invalid} aria-describedby={describedBy} disabled={disabled||loading} className={"search-select-trigger"+(!selected?" is-placeholder":"")} onClick={()=>{searchChanged("");setOpen(current=>!current);}} onKeyDown={event=>{if(["ArrowDown","ArrowUp"].includes(event.key)){event.preventDefault();searchChanged("");setOpen(true);}}}><span>{loading?"Chargement…":selected?.label||placeholder}</span><AppIcon name="chevron-down"/></button>
 {open?createPortal(<div ref={panel} className={"search-select-panel"+(remote?" is-remote":"")} popover="manual" style={position} onKeyDown={navigate}>
  <label className="search-select-search"><AppIcon name="search"/><input ref={search} type="search" aria-label={"Rechercher · "+choiceLabel} aria-controls={listId} aria-describedby={statusId} placeholder="Rechercher…" value={query} onChange={event=>searchChanged(event.target.value)}/></label>
  <div id={listId} role="listbox" aria-label={choiceLabel} className="search-select-options" aria-busy={optionsLoading}>{optionsLoading?<p role="status">Recherche…</p>:optionsError?<p role="alert">{optionsError}</p>:filtered.length?filtered.map(option=><button type="button" role="option" key={option.value} aria-selected={String(option.value)===String(value)} disabled={option.disabled} onClick={()=>choose(option)}><span>{option.label}</span>{String(option.value)===String(value)?<AppIcon name="check-circle"/>:null}</button>):<p role="status">{query?"Aucun choix ne correspond à votre recherche.":"Aucun choix disponible."}</p>}</div>
  <div className="search-select-footer"><span id={statusId} role="status" aria-live="polite" aria-atomic="true">{optionsLoading?"Chargement…":filtered.length+" option"+(filtered.length>1?"s":"")}</span>{optionsError&&onOptionsRetry?<button data-option-command type="button" onClick={onOptionsRetry}>Réessayer</button>:hasMore&&onLoadMore?<button data-option-command type="button" disabled={moreLoading||optionsLoading} onClick={onLoadMore}>{moreLoading?"Chargement…":"Afficher plus"}</button>:null}</div>
 </div>,anchor.current?.closest("dialog")||document.body):null}</>;
}
