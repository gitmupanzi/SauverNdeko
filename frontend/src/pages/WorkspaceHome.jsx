import "./Applications.css";
import { accessSignature } from "../services/moduleAccess";
import {applicationClassificationValid,applicationGroups,applicationGroupCount,applicationParentLabel} from "../services/applicationCatalogue";
import ActionButton from "../components/ActionButton";
import AppIcon from "../components/AppIcon";
import AccountControls from "../components/AccountControls";
import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { useAuth } from "../contexts/AuthContext";
import { requestJson } from "../services/api";
import "./WorkspaceHome.css";

const MODULE_PATHS = new Set(["/catalogue", "/produits", "/pharmacies", "/experts", "/maladies", "/discussions", "/logistique", "/caisse", "/territoires", "/support", "/parametres", "/guide", "/admin"]);

export default function WorkspaceHome() {
  const { user } = useAuth();
  const [modules, setModules] = useState([]);
  const [search, setSearch] = useState("");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [version, setVersion] = useState(0);
  const [moduleOwner,setModuleOwner]=useState("");
  const ownerKey=String(user?.IdUser||"")+":"+String(user?.IdEntiteFk||"")+":"+accessSignature(user);

  useEffect(() => {
    let active = true;
    setLoading(true);
    setError("");
    requestJson("/api/workspace/modules", { requiresAuth: true }).then((payload) => {
      if (!active) return;
      if (!payload?.success || !Array.isArray(payload.data) ||
          payload.data.some((module) => !MODULE_PATHS.has(module.path) || !module.key || !module.label || !applicationClassificationValid(module))) {
        setModules([]);
        setError("Vos applications ne sont pas disponibles. Réessayez dans un instant.");
      } else {
        setModules(payload.data);
      }
      setModuleOwner(ownerKey);
      setLoading(false);
    });
    return () => { active = false; };
  }, [version, user?.IdUser, user?.IdEntiteFk, user?.permissions?.canAccessAdmin, accessSignature(user)]);

  const currentOwner=moduleOwner===ownerKey,viewLoading=loading||!currentOwner,viewError=currentOwner?error:"",currentModules=currentOwner?modules:[];
  const query=search.trim(),groups=applicationGroups(currentModules,query),visibleCount=groups.reduce((count,group)=>count+group.items.length,0);
  return (
    <div className="workspace-home">
      <header className="workspace-bar">
        <Link className="workspace-brand" to="/" aria-label="SauverNdeko — applications">
          <img src="/sauverndeko-logo.jpg" alt="" width="40" height="40" />
          <span>SauverNdeko</span>
        </Link>
        <AccountControls />
      </header>

      <main className="workspace-main" id="workspace-main">
        <div className="workspace-title-row">
          <div><p className="workspace-kicker">VOTRE ESPACE</p><h1>Vos applications</h1><p>{user?.entite?.NomEntite || (user?.moduleAccess?.platformAdmin ? "Administration de la plateforme" : "Choisissez un module pour commencer.")}</p></div>
          <form className="workspace-search" role="search" onSubmit={(event) => event.preventDefault()}>
            <label className="workspace-sr-only" htmlFor="workspace-search">Rechercher une application</label>
            <AppIcon name="search" />
            <input id="workspace-search" type="search" placeholder="Rechercher une application…" value={search} onChange={(event) => setSearch(event.target.value)} autoComplete="off" />
          </form>
        </div>

        <div className="application-links workspace-offer-links"><Link to="/applications" className="ui-action is-secondary"><AppIcon name="apps"/>Découvrir les applications</Link>{user?.permissions?.canAccessAdmin ? <Link to="/abonnements" className="ui-action is-secondary"><AppIcon name="settings"/>Licences et applications</Link> : null}</div>
        {viewLoading ? <p className="workspace-state" role="status">Chargement de vos applications…</p> : null}
        {!viewLoading && viewError ? <div className="workspace-state" role="alert"><i className="bi bi-exclamation-circle" aria-hidden="true" /><p>{viewError}</p><button type="button" onClick={() => setVersion((current) => current + 1)}>Réessayer</button></div> : null}
        {!viewLoading && !viewError ? (
          <>
            {groups.filter(group=>group.total>0).map(group=><section className={"workspace-application-group "+(group.type==="FONCTIONNALITE"?"is-features":"")} key={group.type}>
             <header><h2>{group.label}</h2><p role="status">{applicationGroupCount(group,query)} disponible{group.total===1?"":"s"}</p></header>
             <nav className="workspace-modules" aria-label={group.label}>
              {group.items.map((module) => (
                <Link className={"workspace-app is-" + module.tone} to={module.path} key={module.key}>
                  <span className="workspace-app-open" aria-hidden="true"><i className="bi bi-arrow-up-right" /></span>
                  <span className="workspace-app-icon"><i className={"bi bi-" + module.icon} aria-hidden="true" /></span>
                  <strong>{module.label}</strong>
                  <span className="workspace-app-description">{module.description}</span>
                  {applicationParentLabel(module,currentModules)?<small className="workspace-app-parent">Associé à {applicationParentLabel(module,currentModules)}</small>:null}
                </Link>
              ))}
             </nav>{query&&!group.items.length?<p className="workspace-result">Aucun résultat dans cette rubrique.</p>:null}
            </section>)}
            {!visibleCount ? <div className="workspace-state"><AppIcon name="search" /><p>{query ? "Aucune application ne correspond à votre recherche." : "Aucune application n’est attribuée à ce compte."}</p>{query ? <ActionButton icon="reset" type="button" onClick={() => setSearch("")}>Effacer la recherche</ActionButton> : null}</div> : null}
          </>
        ) : null}
        {!user?.moduleAccess?.platformAdmin ? <p className="workspace-access-note"><i className="bi bi-person-check" aria-hidden="true" /> Applications incluses dans l’offre de votre organisation et autorisées pour votre rôle.</p> : null}
      </main>
    </div>
  );
}
