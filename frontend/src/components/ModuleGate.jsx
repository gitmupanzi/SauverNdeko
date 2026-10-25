import { Link, useLocation } from "react-router-dom";
import { useState } from "react";
import { useAuth } from "../contexts/AuthContext";
import { mayOpen, moduleForPath, moduleRights } from "../services/moduleAccess";
import ModuleHeader from "./ModuleHeader";
import ActionButton from "./ActionButton";
import AppIcon from "./AppIcon";
import "../pages/Applications.css";
export default function ModuleGate({children}) {
  const {user,refreshUser} = useAuth();
  const location = useLocation();
  const [busy,setBusy]=useState(false);
  const [error,setError]=useState("");
  if (location.pathname === "/profil" || (user?.moduleAccess && mayOpen(user,location.pathname))) return children;
  const rights=moduleRights(user,moduleForPath(location.pathname));
  const messages={
    ORGANISATION_REQUIRED:"Votre compte doit être rattaché à une organisation.",
    LICENCE_INACTIVE:"La licence de votre organisation ne permet plus cet accès.",
    MODULE_NOT_INCLUDED:"Cette application n’est pas comprise dans l’offre de votre organisation.",
    MODULE_ROLE_FORBIDDEN:"Votre rôle ne permet pas l’accès à cette application.",
  };
  async function retry() { setBusy(true);setError(""); try { const result=await refreshUser();if(!result?.success)setError("Les accès n’ont pas pu être actualisés."); } finally {setBusy(false);} }
  return <div className="applications-page"><ModuleHeader title="Applications"/><main className="application-denied" role="status"><span className="application-denied-icon"><AppIcon name="alert"/></span><h1>{user?.moduleAccess ? "Accès limité" : "Accès indisponible"}</h1><p>{messages[rights.reason] || "Vos accès ne sont pas disponibles pour le moment."}</p>{error ? <p role="alert">{error}</p>:null}<div className="application-links"><Link className="ui-action is-primary" to="/">Mes applications</Link><Link className="ui-action is-secondary" to="/applications">Découvrir les applications</Link><ActionButton icon="refresh" disabled={busy} onClick={retry}>{busy?"Actualisation…":"Actualiser"}</ActionButton></div></main></div>;
}
