import { useCallback, useId, useRef, useState } from "react";
import { useTheme } from "../contexts/ThemeContext";
import AppIcon from "./AppIcon";
import HeaderPopover from "./HeaderPopover";
import "./ThemePicker.css";

const OPTIONS = [["light", "Clair", "bi-sun"], ["dark", "Sombre", "bi-moon-stars"], ["contrast", "Contraste élevé", "bi-circle-half"], ["system", "Système", "bi-display"]];
export default function ThemePicker() {
  const { mode, setMode } = useTheme();
  const [open,setOpen]=useState(false),anchor=useRef(null),id=useId();
  const selected=OPTIONS.find(([key])=>key===mode)||OPTIONS[0];
  const close=useCallback((restore=false)=>{setOpen(false);if(restore)anchor.current?.focus({preventScroll:true});},[]);
  return <>
    <button ref={anchor} type="button" className="theme-picker" aria-label={"Thème : "+selected[1]} title={"Thème : "+selected[1]} aria-haspopup="menu" aria-expanded={open} aria-controls={open?id:undefined} onClick={()=>setOpen(current=>!current)} onKeyDown={event=>{if(["ArrowDown","ArrowUp"].includes(event.key)){event.preventDefault();setOpen(true);}}}><i className={"bi "+selected[2]} aria-hidden="true"/></button>
    {open?<HeaderPopover id={id} anchor={anchor} label="Choisir le thème" role="menu" width={232} className="theme-menu" onClose={close}>
      <p className="theme-menu-heading">Apparence</p>
      {OPTIONS.map(([key,label,icon])=><button key={key} type="button" role="menuitemradio" tabIndex={-1} aria-checked={mode===key} className="theme-menu-choice" onClick={()=>{setMode(key);close(true);}}><span className="theme-menu-icon"><i className={"bi "+icon} aria-hidden="true"/></span><span>{label}</span>{mode===key?<AppIcon name="check-circle" size={16}/>:null}</button>)}
    </HeaderPopover>:null}
  </>;
}
