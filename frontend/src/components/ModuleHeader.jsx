import AppIcon from "./AppIcon";
import ThemePicker from "./ThemePicker";
import { useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import { useAuth } from "../contexts/AuthContext";
import "../pages/WorkspaceHome.css";

export default function ModuleHeader({ title }) {
  const { user, logout } = useAuth();
  const navigate = useNavigate();
  const [leaving, setLeaving] = useState(false);
  const name = user?.PrenomUser || user?.NomUser || "Mon profil";
  const initials = ((user?.PrenomUser?.[0] || "") + (user?.NomUser?.[0] || "")).toUpperCase() || "SN";
  async function leave() {
    if (leaving) return;
    setLeaving(true);
    try { await logout(); navigate("/login", { replace: true }); } finally { setLeaving(false); }
  }
  return <header className="workspace-bar module-header">
    <Link to="/" className="module-apps-link" aria-label="Toutes les applications" title="Applications"><AppIcon name="apps" /></Link>
    <Link to="/" className="workspace-brand"><img src="/sauverndeko-logo.jpg" alt="" width="36" height="36" /><span>SauverNdeko</span></Link>
    <span className="module-header-title">{title}</span>{user?.permissions?.canWriteData === false ? <span className="module-read-only" title="Les modifications sont momentanément indisponibles.">Consultation</span> : null}
    <div className="workspace-account"><ThemePicker /><Link to="/profil" className="workspace-profile" aria-label={"Mon profil — " + name}><span className="workspace-avatar" aria-hidden="true">{initials}</span><span>{name}</span></Link>
      <button className="workspace-logout" type="button" aria-label="Se déconnecter" disabled={leaving} onClick={leave}><AppIcon name="logout" /><span>{leaving ? "Déconnexion…" : "Se déconnecter"}</span></button>
    </div>
  </header>;
}
