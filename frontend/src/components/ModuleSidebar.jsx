import {useEffect,useId,useRef,useState} from "react";
import {Link} from "react-router-dom";
import AppIcon from "./AppIcon";
import {useAuth} from "../contexts/AuthContext";
import {mayOpen} from "../services/moduleAccess";
import {lockBodyScroll,unlockBodyScroll} from "../utils/bodyScrollLock";
import ModuleHeader from "./ModuleHeader";
import "./ModuleSidebar.css";

function rememberedGroups(key){try{const value=JSON.parse(localStorage.getItem(key)||"{}");return value&&typeof value==="object"&&!Array.isArray(value)?value:{};}catch{return {};}}
function Icon({name="apps"}){return <AppIcon name={name} size={19}/>;}
const menuText=value=>String(value||"").normalize("NFD").replace(/[\u0300-\u036f]/g,"").toLocaleLowerCase("fr").trim();
const mobileQuery="(max-width:760px)";

/** Navigation commune : les entrées sont déjà filtrées par les droits du module. */
export default function ModuleSidebar({title,groups=[],activeKey,onNavigate,collapsed=false,onToggle,storageKey="sauverndeko.navigation",className="",children,overlay=false,open=true,onClose,headerProps={}}){
 const {user,isAuthenticated}=useAuth();
 const footerItems=isAuthenticated?[
  {key:"/parametres",label:"Paramètres",icon:"settings",to:"/parametres"},
  {key:"/admin",label:"Administration",icon:"shield",to:"/admin"},
 ].filter(item=>mayOpen(user,item.to)&&(item.to!=="/admin"||user?.permissions?.canAccessAdmin)): [];
 const prefix=useId(),root=useRef(null),navigation=useRef(null),toggle=useRef(null),returnFocus=useRef(null),searchInput=useRef(null),scrollOwner=useRef({});
 const [folded,setFolded]=useState(()=>rememberedGroups(storageKey+".groups")),[mobileOpen,setMobileOpen]=useState(false),[query,setQuery]=useState(""),[hint,setHint]=useState(null);
 const visibleGroups=groups.map(group=>({...group,items:(group.items||[]).filter(item=>item&&item.hidden!==true)})).filter(group=>group.items.length);
 const [mobile,setMobile]=useState(()=>!overlay&&typeof matchMedia!=="undefined"&&matchMedia(mobileQuery).matches);
 const inHeader=Boolean(onToggle&&headerProps&&!overlay),modal=overlay?open:mobile&&mobileOpen,fullMenu=(!collapsed&&!mobile)||modal;
 const term=fullMenu?menuText(query):"",itemCount=visibleGroups.reduce((total,group)=>total+group.items.length,0),searchable=itemCount>=7||Boolean(query);
 const menuId=prefix+"-sidebar",expanded=mobile||overlay?modal:!collapsed;
 const toggleIcon=inHeader?(expanded?"close":"menu"):overlay||mobileOpen?"close":mobile?"menu":"sidebar";
 const toggleLabel=overlay||modal?"Fermer le menu":mobile?"Ouvrir le menu":collapsed?"Déplier le menu":"Replier le menu";
 const displayedGroups=term?visibleGroups.map(group=>({...group,items:group.items.filter(item=>menuText(group.label+" "+item.label).includes(term))})).filter(group=>group.items.length):visibleGroups;
 const matchingCount=displayedGroups.reduce((total,group)=>total+group.items.length,0);
 const currentGroup=visibleGroups.find(group=>group.items.some(item=>item.key===activeKey||item.active===true)),activeGroup=currentGroup?.key||currentGroup?.label;
 useEffect(()=>{if(activeGroup)setFolded(previous=>previous[activeGroup]?{...previous,[activeGroup]:false}:previous);},[activeGroup]);
 useEffect(()=>{try{localStorage.setItem(storageKey+".groups",JSON.stringify(folded));}catch{/* Préférence visuelle facultative. */}},[folded,storageKey]);
 useEffect(()=>{
  if(overlay||typeof matchMedia==="undefined")return;
  const media=matchMedia(mobileQuery);
  function changed(event){
   setMobile(event.matches);
   setQuery("");
   setHint(null);
   if(!event.matches)setMobileOpen(false);
  }
  setMobile(media.matches);
  media.addEventListener?.("change",changed);
  return()=>media.removeEventListener?.("change",changed);
 },[overlay]);
 useEffect(()=>{setQuery("");setHint(null);},[storageKey,activeKey]);
 function closeMenu(){setQuery("");setHint(null);if(overlay)onClose?.();else setMobileOpen(false);}
 useEffect(()=>{
  if(!modal)return;returnFocus.current=document.activeElement;lockBodyScroll(scrollOwner.current);
  const focusables=()=>Array.from((inHeader?navigation.current:root.current)?.querySelectorAll(':is(a[href],button:not([disabled]),input:not([disabled]),select:not([disabled]),[tabindex="0"]):not([tabindex="-1"],[inert],[inert] *)')||[]).filter(element=>element.getClientRects().length);
  const initialFocus=overlay?focusables()[0]:toggle.current;
  initialFocus?.focus({preventScroll:true});
  function keydown(event){if(event.key==="Escape"){event.preventDefault();closeMenu();}else if(event.key==="Tab"){const nodes=focusables(),first=nodes[0],last=nodes.at(-1);if(!first)return;if(event.shiftKey&&document.activeElement===first){event.preventDefault();last.focus();}else if(!event.shiftKey&&document.activeElement===last){event.preventDefault();first.focus();}}}
  document.addEventListener("keydown",keydown);
  return()=>{unlockBodyScroll(scrollOwner.current);document.removeEventListener("keydown",keydown);const target=overlay?returnFocus.current:toggle.current;requestAnimationFrame(()=>target?.isConnected&&target.focus({preventScroll:true}));};
 },[modal,overlay,inHeader]);
 function toggleMenu(){setHint(null);setQuery("");if(overlay){closeMenu();return;}if(mobile)setMobileOpen(value=>!value);else onToggle?.();}
 function showHint(event,item){
  if(modal||(!collapsed&&!mobile))return;
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
 const menuToggle=onToggle||overlay?<button ref={toggle} type="button" className={inHeader?"module-sidebar-trigger":"logistics-sidebar-toggle"} onClick={toggleMenu} aria-label={toggleLabel} aria-controls={menuId} aria-expanded={expanded} title={toggleLabel}><AppIcon name={toggleIcon} size={inHeader||mobile?20:16}/></button>:null;
 const sidebar=<>{modal?<button type="button" className="module-sidebar-backdrop" tabIndex={-1} aria-label="Fermer le menu" onClick={closeMenu}/>:null}<aside ref={root} id={menuId} className={"logistics-sidebar-shell erp-module-sidebar"+(collapsed?" is-collapsed":"")+(mobileOpen?" is-mobile-open":"")+(overlay?" is-overlay"+(open?" is-open":""):"")+" "+className} aria-label={"Navigation "+title} aria-hidden={overlay&&!open?true:undefined} inert={overlay&&!open?true:undefined} role={modal&&!inHeader?"dialog":undefined} aria-modal={modal&&!inHeader?true:undefined}>
  <div className="logistics-sidebar-top"><Link to="/espace" className="logistics-brand-lockup" aria-label="SauverNdeko — Applications" onClick={closeMenu}><img className="logistics-brand-logo" src="/sauverndeko-logo.jpg" alt="" width="34" height="34"/><span className="logistics-brand-copy"><strong>SauverNdeko</strong><span>{title}</span></span></Link>{inHeader?null:menuToggle}</div>
  {searchable?<div className="module-menu-search"><div className="module-menu-search-field"><AppIcon name="search" size={16}/><input ref={searchInput} type="search" aria-label="Rechercher dans le menu" placeholder="Trouver un menu…" value={query} onChange={event=>setQuery(event.target.value)} onKeyDown={searchKeydown}/>{query?<button type="button" aria-label="Effacer la recherche du menu" onClick={()=>{setQuery("");searchInput.current?.focus();}}><AppIcon name="close" size={14}/></button>:null}</div>{term?<span className="module-menu-result" role="status">{matchingCount} menu{matchingCount===1?"":"s"}</span>:null}</div>:null}
  <nav className="logistics-sidebar-nav" aria-label={"Menu "+title} onScroll={()=>setHint(null)}>{children? <div className="module-sidebar-extra">{children}</div>:null}{displayedGroups.map((group,index)=>{const key=group.key||group.label,id=prefix+"-group-"+index,isFolded=!term&&folded[key]===true&&fullMenu;return <section className="logistics-nav-group" key={key} aria-label={group.label}><button type="button" className={"module-nav-group-toggle logistics-nav-heading"+(key===activeGroup?" contains-active":"")} aria-expanded={!isFolded} aria-controls={id} disabled={Boolean(term)} onClick={()=>setFolded(previous=>({...previous,[key]:!isFolded}))}><span>{group.label}</span><AppIcon name="chevron-down" size={14} className={isFolded?"":"is-expanded"}/></button><div id={id} className="module-nav-items" hidden={isFolded}>{group.items.map(item=>entry(item))}</div></section>;})}{term&&!matchingCount?<p className="module-menu-empty">Aucun menu trouvé. Essayez un autre mot.</p>:null}</nav>
  {footerItems.length?<nav className="logistics-app-switcher" aria-label="Raccourcis de gestion">{footerItems.map(item=>entry(item,true))}</nav>:null}
 </aside>{hint&&!modal?<span id={prefix+"-hint"} className="module-rail-hint" role="tooltip" style={{top:hint.top,left:hint.left}}>{hint.label}</span>:null}</>;
 if(!inHeader)return sidebar;
 return <div ref={navigation} className={"module-navigation"+(modal?" is-menu-open":"")} role={modal?"dialog":undefined} aria-modal={modal?true:undefined} aria-label={modal?"Navigation "+title:undefined}>
  <ModuleHeader {...headerProps} title={title} menuToggle={menuToggle} menuOpen={modal}/>
  {sidebar}
 </div>;
}
