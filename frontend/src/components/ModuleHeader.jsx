import EntityScopePicker from "./EntityScopePicker";
import AppIcon from "./AppIcon";
import AccountControls from "./AccountControls";
import { Link } from "react-router-dom";
import { useAuth } from "../contexts/AuthContext";
import "../pages/WorkspaceHome.css";
import "./ModuleHeader.css";

function focusModuleContent(event){
  const shell=event.currentTarget.closest(".logistics-app,.applications-page");
  const content=shell?.querySelector('main,[role="main"],.logistics-main-column,.admin-main-column');
  if(!content)return;
  if(!content.hasAttribute("tabindex"))content.setAttribute("tabindex","-1");
  content.focus({preventScroll:false});
}

export default function ModuleHeader({ title, onRequestLogout, showEntityScope=true, menuToggle, menuOpen=false }) {
  const { user } = useAuth();
  return <header className="workspace-bar module-header">
    {!menuOpen?<button type="button" className="module-skip-content" onClick={focusModuleContent}>Aller au contenu</button>:null}
    <Link to="/espace" className="workspace-brand" aria-label="SauverNdeko — applications" inert={menuOpen}><img src="/sauverndeko-logo.jpg" alt="" width="36" height="36" /><span>SauverNdeko</span></Link>
    <div className="module-header-start">{menuToggle}<nav className="module-location" aria-label="Fil d’Ariane" inert={menuOpen}><Link to="/espace" className="module-apps-link" aria-label="Toutes les applications" title="Applications"><AppIcon name="apps" /></Link><AppIcon name="chevron-right" className="module-location-separator" size={14}/><span className="module-header-title" aria-current="page" title={title}>{title}</span></nav></div>
    {user?.permissions?.canWriteData === false ? <span className="module-read-only" title="Les modifications sont momentanément indisponibles.">Consultation</span> : null}
    <div className="module-header-actions" inert={menuOpen}>
      {showEntityScope&&["Logistique","Caisse","Professionnels","Structures","Référentiels","Administration","Support","Paramètres","Guide utilisateur","Data Science","Data science"].includes(title)?<EntityScopePicker/>:null}
      <AccountControls onRequestLogout={onRequestLogout} />
    </div>
  </header>;
}
