import EntityScopePicker from "./EntityScopePicker";
import AppIcon from "./AppIcon";
import AccountControls from "./AccountControls";
import { Link } from "react-router-dom";
import { useAuth } from "../contexts/AuthContext";
import "../pages/WorkspaceHome.css";

export default function ModuleHeader({ title, onRequestLogout }) {
  const { user } = useAuth();
  return <header className="workspace-bar module-header">
    <Link to="/" className="module-apps-link" aria-label="Toutes les applications" title="Applications"><AppIcon name="apps" /></Link>
    <Link to="/" className="workspace-brand" aria-label="SauverNdeko — applications"><img src="/sauverndeko-logo.jpg" alt="" width="36" height="36" /><span>SauverNdeko</span></Link>
    <span className="module-header-title">{title}</span>{user?.permissions?.canWriteData === false ? <span className="module-read-only" title="Les modifications sont momentanément indisponibles.">Consultation</span> : null}
    {["Logistique","Référentiels"].includes(title)?<EntityScopePicker/>:null}<AccountControls onRequestLogout={onRequestLogout} />
  </header>;
}
