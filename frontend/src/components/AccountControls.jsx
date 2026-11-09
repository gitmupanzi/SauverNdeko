import UserAvatar from "./UserAvatar";
import { useCallback, useEffect, useRef, useState } from "react";
import { Link, useLocation, useNavigate } from "react-router-dom";
import { useAuth } from "../contexts/AuthContext";
import AppIcon from "./AppIcon";
import ThemePicker from "./ThemePicker";
import DrawerDialog from "./DrawerDialog";
import HeaderPopover from "./HeaderPopover";
import Notifications from "./Notifications";
import { moduleRights } from "../services/moduleAccess";
import "./AccountControls.css";

export default function AccountControls({ onRequestLogout, onLogout }) {
  const {user,logout}=useAuth(),navigate=useNavigate(),location=useLocation();
  const [open,setOpen]=useState(false),[section,setSection]=useState(''),[leaving,setLeaving]=useState(false);
  const anchor=useRef(null),busy=useRef(false);
  const name=[user?.PrenomUser,user?.NomUser].filter(Boolean).join(' ')||'Mon compte';
  const close=useCallback((restore=false)=>{setOpen(false);if(restore)anchor.current?.focus({preventScroll:true});},[]);
  useEffect(()=>{setOpen(false);setSection('');},[location.pathname,location.search]);
  async function leave(){
    if(busy.current)return;busy.current=true;setLeaving(true);
    try { if(onLogout)await onLogout();else{await logout();navigate('/login',{replace:true});} }
    finally{busy.current=false;setLeaving(false);}
  }
  function requestLeave(){close(true);if(onRequestLogout)onRequestLogout(leave);else leave();}
  function show(next){close(true);setSection(next);}
  return <div className="workspace-account account-controls">
    <ThemePicker/><Notifications/>
    <button ref={anchor} type="button" className="account-trigger" aria-label={'Mon compte — '+name} aria-haspopup="menu" aria-expanded={open} disabled={leaving} onClick={()=>setOpen(value=>!value)} onKeyDown={event=>{if(event.key==='ArrowDown'){event.preventDefault();setOpen(true);}}}>
      <UserAvatar user={user} className="workspace-avatar" decorative/><span className="account-trigger-name">{user?.PrenomUser||user?.NomUser||'Mon compte'}</span><AppIcon name={open?'chevron-up':'chevron-down'} size={14}/>
    </button>
    {open?<HeaderPopover anchor={anchor} role="menu" label="Menu du compte" onClose={close}>
      <div className="account-menu-identity"><strong>{name}</strong><span>{user?.EmailUser||'Adresse e-mail non renseignée'}</span>{user?.entite?.NomEntite?<small>{user.entite.NomEntite}</small>:null}</div>
      <div className="account-menu-links"><Link role="menuitem" to="/profil" onClick={()=>close()}><AppIcon name="user"/><span>Mon profil</span></Link><Link role="menuitem" to="/profil?modifier=1" onClick={()=>close()}><AppIcon name="edit"/><span>Modifier le profil</span></Link><button role="menuitem" type="button" onClick={()=>show('preferences')}><AppIcon name="settings"/><span>Paramètres du compte</span></button>{moduleRights(user,"guide").canRead?<Link role="menuitem" to="/guide" onClick={()=>close()}><AppIcon name="book"/><span>Guide utilisateur</span></Link>:null}{moduleRights(user,"support").canRead?<Link role="menuitem" to="/support" onClick={()=>close()}><AppIcon name="help"/><span>Support</span></Link>:<button role="menuitem" type="button" onClick={()=>show('help')}><AppIcon name="help"/><span>Assistance</span></button>}</div>
      <div className="account-language"><AppIcon name="globe"/><span>Langue</span><strong>Français</strong></div>
      <div className="account-menu-footer"><button role="menuitem" type="button" onClick={requestLeave} disabled={leaving}><AppIcon name="logout"/><span>{leaving?'Déconnexion…':'Se déconnecter'}</span></button></div>
    </HeaderPopover>:null}
    {section?<DrawerDialog title={section==='preferences'?'Paramètres du compte':'Assistance'} icon={section==='preferences'?'settings':'help'} onClose={()=>setSection('')} defaultWidth={540} storageKey="sauverndeko.account.width">
      <div className="account-settings">
        {section==='preferences'?<><section><h3>Apparence</h3><p>Choisissez le thème de ce navigateur.</p><ThemePicker/></section><section><h3>Langue</h3><div className="account-settings-language"><AppIcon name="globe"/>Français<AppIcon name="check-circle"/></div></section><section><h3>Informations personnelles</h3><p>Votre nom, vos coordonnées et votre photo de profil.</p><Link className="ui-action is-secondary" to="/profil?modifier=1" onClick={()=>setSection('')}><AppIcon name="edit"/>Modifier le profil</Link></section></>:<><p className="account-help-intro">Retrouvez les réponses aux questions courantes.</p><details open><summary>Mes applications et mes accès</summary><p>Les applications disponibles dépendent de la licence de votre organisation et de votre rôle. Pour modifier vos accès, contactez votre administrateur.</p><Link to="/espace" onClick={()=>setSection('')}>Mes applications</Link></details><details><summary>Mettre à jour mes informations</summary><p>Ouvrez votre profil pour modifier votre nom, vos coordonnées et votre photo.</p><Link to="/profil" onClick={()=>setSection('')}>Mon profil</Link></details><details><summary>Consulter mes notifications</summary><p>La cloche regroupe les communications qui vous sont adressées. Le repère indique les notifications non lues.</p></details>{user?.permissions?.canAccessAdmin&&moduleRights(user,"administration").canRead?<Link to="/abonnements" className="ui-action is-secondary" onClick={()=>setSection('')}><AppIcon name="settings"/>Licences et applications</Link>:null}</>}
      </div>
    </DrawerDialog>:null}
  </div>;
}
