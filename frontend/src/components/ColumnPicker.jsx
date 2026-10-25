import { useEffect, useId, useLayoutEffect, useRef, useState } from "react";
import { createPortal } from "react-dom";
import AppIcon from "./AppIcon";
import ActionButton from "./ActionButton";
import "./ColumnPicker.css";
const normalize = value => String(value).normalize("NFD").replace(/[\u0300-\u036f]/g,"").toLowerCase();
export default function ColumnPicker({ open, anchorRef, onClose, columns, visibleKeys, pinnedKeys, onToggleVisible, onTogglePinned, onShowAll, onResetWidth, onResetWidths }) {
  const id=useId();
  const panelRef=useRef(null), searchRef=useRef(null), closeRef=useRef(onClose);
  closeRef.current=onClose;
  const initialFocus=useRef(false);
  const [query,setQuery]=useState("");
  const [placement,setPlacement]=useState(null);
  const filtered=columns.filter(column=>normalize(column.label).includes(normalize(query)));
  const target=anchorRef.current?.closest("dialog") || document.body;
  useLayoutEffect(()=>{
    if(!open || !panelRef.current) return;
    const panel=panelRef.current;
    setQuery("");
    if(typeof panel.showPopover==="function") panel.showPopover();
    initialFocus.current=false;
    return ()=>{ if(typeof panel.hidePopover==="function" && panel.matches(":popover-open")) panel.hidePopover(); };
  },[open]);
  useLayoutEffect(()=>{
    if(!open) return;
    function position(){
      const anchor=anchorRef.current,panel=panelRef.current;
      if(!anchor || !panel) return;
      const rect=anchor.getBoundingClientRect();
      const width=Math.min(336,window.innerWidth-24);
      const below=window.innerHeight-rect.bottom-16,above=rect.top-16;
      const wanted=Math.min(panel.scrollHeight||460,460);
      const useBelow=below>=Math.min(wanted,280) || below>=above;
      const maxHeight=Math.max(0,Math.min(460,useBelow?below:above,window.innerHeight-24));
      const height=Math.min(wanted,maxHeight);
      setPlacement({width,maxHeight,left:Math.max(12,Math.min(rect.right-width,window.innerWidth-width-12)),top:useBelow?rect.bottom+8:Math.max(12,rect.top-height-8)});
    }
    position();
    window.addEventListener("resize",position);
    window.addEventListener("scroll",position,true);
    return ()=>{window.removeEventListener("resize",position);window.removeEventListener("scroll",position,true);};
  },[open,query,columns.length,visibleKeys.length,pinnedKeys.length,anchorRef]);
  useEffect(()=>{
    if(!open || !placement || initialFocus.current) return;
    const frame=requestAnimationFrame(()=>{searchRef.current?.focus({preventScroll:true});initialFocus.current=true;});
    return ()=>cancelAnimationFrame(frame);
  },[open,placement]);
  useEffect(()=>{
    if(!open) return;
    function outside(event){ if(!panelRef.current?.contains(event.target) && !anchorRef.current?.contains(event.target)) closeRef.current(false); }
    function escape(event){ if(event.key==="Escape"){event.preventDefault();event.stopPropagation();closeRef.current(true);} }
    document.addEventListener("pointerdown",outside,true);
    document.addEventListener("keydown",escape,true);
    return ()=>{document.removeEventListener("pointerdown",outside,true);document.removeEventListener("keydown",escape,true);};
  },[open,anchorRef]);
  if(!open) return null;
  return createPortal(<div ref={panelRef} className="column-picker" role="dialog" aria-labelledby={id} popover="manual" style={placement || {visibility:"hidden"}}>
    <header className="column-picker-header"><div><h3 id={id}>Colonnes</h3><p>{visibleKeys.length} sur {columns.length} affichées</p></div><button type="button" className="column-picker-icon" aria-label="Fermer les colonnes" onClick={()=>onClose(true)}><AppIcon name="close" /></button></header>
    <label className="column-picker-search"><AppIcon name="search" /><input ref={searchRef} type="search" aria-label="Rechercher une colonne" placeholder="Rechercher une colonne…" value={query} onChange={event=>setQuery(event.target.value)} /></label>
    <div className="column-picker-list" role="list">{filtered.map(column=>{const visible=visibleKeys.includes(column.key),pinned=pinnedKeys.includes(column.key);return <div key={column.key} className="column-picker-row" role="listitem"><label><input type="checkbox" checked={visible} disabled={visible && visibleKeys.length===1} aria-label={"Afficher "+column.label} onChange={()=>onToggleVisible(column.key)} /><span>{column.label}</span></label><div><button type="button" className={"column-picker-icon"+(pinned?" is-active":"")} aria-label={(pinned?"Libérer ":"Figer ")+column.label} title={pinned?"Libérer la colonne":"Figer la colonne"} aria-pressed={pinned} disabled={!visible} onClick={()=>onTogglePinned(column.key)}><AppIcon name="pin" size={14} /></button><button type="button" className="column-picker-icon" aria-label={"Largeur auto : "+column.label} title="Largeur automatique" onClick={()=>onResetWidth(column.key)}><AppIcon name="reset" size={14} /></button></div></div>;})}{!filtered.length?<p className="column-picker-empty">Aucune colonne correspondante.</p>:null}</div>
    <footer className="column-picker-footer"><ActionButton onClick={onShowAll}>Tout afficher</ActionButton><ActionButton icon="reset" onClick={onResetWidths}>Largeurs auto</ActionButton></footer>
  </div>,target);
}
