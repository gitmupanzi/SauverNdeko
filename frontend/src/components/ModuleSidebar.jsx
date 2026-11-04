import {useEffect,useId,useRef,useState} from "react";
import {Link} from "react-router-dom";
import AppIcon from "./AppIcon";
import {lockBodyScroll,unlockBodyScroll} from "../utils/bodyScrollLock";
import "./ModuleSidebar.css";

function rememberedGroups(key){try{const value=JSON.parse(localStorage.getItem(key)||"{}");return value&&typeof value==="object"&&!Array.isArray(value)?value:{};}catch{return {};}}
function Icon({name="apps"}){return name.startsWith("bi-")?<i className={"bi "+name} aria-hidden="true"/>:<AppIcon name={name} size={19}/>;}
const menuText=value=>String(value||"").normalize("NFD").replace(/[\u0300-\u036f]/g,"").toLocaleLowerCase("fr").trim();

/** Navigation commune : les entrées sont déjà filtrées par les droits du module. */
export default function ModuleSidebar({title,groups=[],activeKey,onNavigate,collapsed=false,onToggle,footerItems=[],storageKey="sauverndeko.navigation",className="",children,overlay=false,open=true,onClose}){
 const prefix=useId(),root=useRef(null),toggle=useRef(null),returnFocus=useRef(null),searchInput=useRef(null),scrollOwner=useRef({});
 const [folded,setFolded]=useState(()=>rememberedGroups(storageKey+".groups")),[mobileOpen,setMobileOpen]=useState(false),[query,setQuery]=useState(""),[hint,setHint]=useState(null);
 const visibleGroups=groups.map(group=>({...group,items:(group.items||[]).filter(item=>item&&item.hidden!==true)})).filter(group=>group.items.length);
 const modal=overlay?open:mobileOpen,term=(!collapsed||modal)?menuText(query):"",itemCount=visibleGroups.reduce((total,group)=>total+group.items.length,0),searchable=itemCount>=7||Boolean(query);
 const displayedGroups=term?visibleGroups.map(group=>({...group,items:group.items.filter(item=>menuText(group.label+" "+item.label).includes(term))})).filter(group=>group.items.length):visibleGroups;
 const matchingCount=displayedGroups.reduce((total,group)=>total+group.items.length,0);
 const currentGroup=visibleGroups.find(group=>group.items.some(item=>item.key===activeKey||item.active===true)),activeGroup=currentGroup?.key||currentGroup?.label;
 useEffect(()=>{if(activeGroup)setFolded(previous=>previous[activeGroup]?{...previous,[activeGroup]:false}:previous);},[activeGroup]);
 useEffect(()=>{try{localStorage.setItem(storageKey+".groups",JSON.stringify(folded));}catch{/* Préférence visuelle facultative. */}},[folded,storageKey]);
 useEffect(()=>{if(!mobileOpen||typeof matchMedia==="undefined")return;const media=matchMedia("(max-width:760px)"),changed=event=>{if(!event.matches)setMobileOpen(false);};media.addEventListener?.("change",changed);return()=>media.removeEventListener?.("change",changed);},[mobileOpen]);
 useEffect(()=>{setQuery("");setHint(null);},[storageKey,activeKey]);
 function closeMenu(){setQuery("");setHint(null);if(overlay)onClose?.();else setMobileOpen(false);}
 useEffect(()=>{
  if(!modal)return;returnFocus.current=document.activeElement;lockBodyScroll(scrollOwner.current);
  const focusables=()=>Array.from(root.current?.querySelectorAll('a[href],button:not([disabled]),input:not([disabled]),select:not([disabled]),[tabindex="0"]')||[]).filter(element=>element.getClientRects().length);
  const first=focusables()[0];first?.focus({preventScroll:true});
  function keydown(event){if(event.key==="Escape"){event.preventDefault();closeMenu();}else if(event.key==="Tab"){const nodes=focusables(),first=nodes[0],last=nodes.at(-1);if(!first)return;if(event.shiftKey&&document.activeElement===first){event.preventDefault();last.focus();}else if(!event.shiftKey&&document.activeElement===last){event.preventDefault();first.focus();}}}
  document.addEventListener("keydown",keydown);
  return()=>{unlockBodyScroll(scrollOwner.current);document.removeEventListener("keydown",keydown);const target=overlay?returnFocus.current:toggle.current;requestAnimationFrame(()=>target?.isConnected&&target.focus({preventScroll:true}));};
 },[modal,overlay]);
 function toggleMenu(){setHint(null);setQuery("");if(overlay){closeMenu();return;}if(typeof matchMedia!=="undefined"&&matchMedia("(max-width:760px)").matches)setMobileOpen(value=>!value);else onToggle?.();}
 function showHint(event,item){
  if(modal||!(collapsed||(typeof matchMedia!=="undefined"&&matchMedia("(max-width:760px)").matches)))return;
  const bounds=event.currentTarget.getBoundingClientRect();
  setHint({key:item.key??item.to??item.label,label:item.label,top:bounds.top+bounds.height/2,left:bounds.right+10});
 }
 function searchKeydown(event){
  if(event.key==="Escape"&&query){event.preventDefault();event.stopPropagation();setQuery("");}
  else if(event.key==="ArrowDown"){
   const first=root.current?.querySelector('.logistics-sidebar-nav .logistics-sidebar-link:not(:disabled)');
   if(first){event.preventDefault();first.focus({preventScroll:false});}
  }
 }
 function navigate(item){if(item.disabled)return;if(item.onClick)item.onClick();else onNavigate?.(item.key);closeMenu();}
 function entry(item,footer=false){const active=item.key===activeKey||item.active===true,itemKey=item.key??item.to??item.label;const contents=<><span className="logistics-sidebar-icon"><Icon name={item.icon}/></span><span className="logistics-sidebar-label">{item.label}</span>{item.badge!=null?<span className="module-nav-badge">{item.badge}</span>:null}{footer&&item.to?<AppIcon name="arrow-up-right" size={14} className="module-nav-external"/>:null}</>;
  const props={className:"logistics-sidebar-link"+(active?" is-active":""),title:item.title||item.label,"aria-label":item.label,"aria-current":active?"page":undefined,"aria-describedby":hint?.key===itemKey?prefix+"-hint":undefined,onMouseEnter:event=>showHint(event,item),onMouseLeave:()=>setHint(null),onFocus:event=>showHint(event,item),onBlur:()=>setHint(null),onKeyDown:event=>{if(event.key==="Escape"&&hint){event.preventDefault();setHint(null);}}};
  return item.to&&!item.disabled?<Link {...props} key={item.key||item.to} to={item.to} onClick={()=>{item.onClick?.();closeMenu();}}>{contents}</Link>:<button {...props} key={item.key} type="button" disabled={item.disabled} onClick={()=>navigate(item)}>{contents}</button>;
 }
 return <>{modal?<button type="button" className="module-sidebar-backdrop" tabIndex={-1} aria-label="Fermer le menu" onClick={closeMenu}/>:null}<aside ref={root} className={"logistics-sidebar-shell erp-module-sidebar"+(collapsed?" is-collapsed":"")+(mobileOpen?" is-mobile-open":"")+(overlay?" is-overlay"+(open?" is-open":""):"")+" "+className} aria-label={"Navigation "+title} aria-hidden={overlay&&!open?true:undefined} inert={overlay&&!open?true:undefined} role={modal?"dialog":undefined} aria-modal={modal?true:undefined}>
  <div className="logistics-sidebar-top"><Link to="/espace" className="logistics-brand-lockup" aria-label="SauverNdeko — Applications" onClick={closeMenu}><img className="logistics-brand-logo" src="/sauverndeko-logo.jpg" alt="" width="34" height="34"/><span className="logistics-brand-copy"><strong>SauverNdeko</strong><span>{title}</span></span></Link>{onToggle||overlay?<button ref={toggle} type="button" className="logistics-sidebar-toggle" onClick={toggleMenu} aria-label={overlay||mobileOpen?"Fermer le menu":collapsed?"Déplier le menu":"Replier ou ouvrir le menu"} aria-expanded={overlay?open:mobileOpen||!collapsed} title={overlay||mobileOpen?"Fermer":collapsed?"Déplier":"Replier"}><AppIcon name={overlay||mobileOpen?"close":"sidebar"}/></button>:null}</div>
  {searchable?<div className="module-menu-search"><div className="module-menu-search-field"><AppIcon name="search" size={16}/><input ref={searchInput} type="search" aria-label="Rechercher dans le menu" placeholder="Trouver un menu…" value={query} onChange={event=>setQuery(event.target.value)} onKeyDown={searchKeydown}/>{query?<button type="button" aria-label="Effacer la recherche du menu" onClick={()=>{setQuery("");searchInput.current?.focus();}}><AppIcon name="close" size={14}/></button>:null}</div>{term?<span className="module-menu-result" role="status">{matchingCount} menu{matchingCount===1?"":"s"}</span>:null}</div>:null}
  <nav className="logistics-sidebar-nav" aria-label={"Menu "+title} onScroll={()=>setHint(null)}>{children? <div className="module-sidebar-extra">{children}</div>:null}{displayedGroups.map((group,index)=>{const key=group.key||group.label,id=prefix+"-group-"+index,isFolded=!term&&folded[key]===true&&(!collapsed||mobileOpen||overlay);return <section className="logistics-nav-group" key={key} aria-label={group.label}><button type="button" className={"module-nav-group-toggle logistics-nav-heading"+(key===activeGroup?" contains-active":"")} aria-expanded={!isFolded} aria-controls={id} disabled={Boolean(term)} onClick={()=>setFolded(previous=>({...previous,[key]:!isFolded}))}><span>{group.label}</span><AppIcon name="chevron-down" size={14} className={isFolded?"":"is-expanded"}/></button><div id={id} className="module-nav-items" hidden={isFolded}>{group.items.map(item=>entry(item))}</div></section>;})}{term&&!matchingCount?<p className="module-menu-empty">Aucun menu trouvé. Essayez un autre mot.</p>:null}</nav>
  {footerItems.some(item=>item&&!item.hidden)?<div className="logistics-app-switcher">{footerItems.filter(item=>item&&!item.hidden).map(item=>entry(item,true))}</div>:null}
 </aside>{hint&&!modal?<span id={prefix+"-hint"} className="module-rail-hint" role="tooltip" style={{top:hint.top,left:hint.left}}>{hint.label}</span>:null}</>;
}
