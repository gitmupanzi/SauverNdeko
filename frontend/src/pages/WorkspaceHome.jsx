import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { useAuth } from "../contexts/AuthContext";
import { requestJson } from "../services/api";
import "./WorkspaceHome.css";

const MODULE_PATHS = new Set(["/catalogue", "/produits", "/pharmacies", "/experts", "/maladies", "/discussions", "/logistique", "/admin"]);

export default function WorkspaceHome() {
  const { user, logout } = useAuth();
  const [modules, setModules] = useState([]);
  const [search, setSearch] = useState("");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [version, setVersion] = useState(0);
  const [leaving, setLeaving] = useState(false);

  useEffect(() => {
    let active = true;
    setLoading(true);
    setError("");
    requestJson("/api/workspace/modules", { requiresAuth: true }).then((payload) => {
      if (!active) return;
      if (!payload?.success || !Array.isArray(payload.data) ||
          payload.data.some((module) => !MODULE_PATHS.has(module.path) || !module.key || !module.label)) {
        setModules([]);
        setError("Vos applications ne sont pas disponibles. Réessayez dans un instant.");
      } else {
        setModules(payload.data);
      }
      setLoading(false);
    });
    return () => { active = false; };
  }, [version]);

  const query = search.trim().normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase();
  const visible = modules.filter((module) =>
    (module.label + " " + module.description).normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase().includes(query)
  );
  const displayName = user?.PrenomUser || user?.NomUser || "Bienvenue";
  const initials = ((user?.PrenomUser?.[0] || "") + (user?.NomUser?.[0] || "")).toUpperCase() || "SN";

  async function leaveWorkspace() {
    if (leaving) return;
    setLeaving(true);
    try { await logout(); } finally { setLeaving(false); }
  }

  return (
    <div className="workspace-home">
      <header className="workspace-bar">
        <Link className="workspace-brand" to="/" aria-label="SauverNdeko — applications">
          <img src="/sauverndeko-logo.jpg" alt="" width="40" height="40" />
          <span>SauverNdeko</span>
        </Link>
        <div className="workspace-account">
          <Link to="/profil" className="workspace-profile" aria-label={"Mon profil — " + displayName}>
            <span className="workspace-avatar" aria-hidden="true">{initials}</span>
            <span>{displayName}</span>
          </Link>
          <button className="workspace-logout" type="button" onClick={leaveWorkspace} disabled={leaving} aria-label="Se déconnecter">
            <i className="bi bi-box-arrow-right" aria-hidden="true" />
            <span>{leaving ? "Déconnexion…" : "Se déconnecter"}</span>
          </button>
        </div>
      </header>

      <main className="workspace-main" id="workspace-main">
        <div className="workspace-title-row">
          <div><p className="workspace-kicker">VOTRE ESPACE</p><h1>Vos applications</h1><p>Choisissez un module pour commencer.</p></div>
          <form className="workspace-search" role="search" onSubmit={(event) => event.preventDefault()}>
            <label className="workspace-sr-only" htmlFor="workspace-search">Rechercher une application</label>
            <i className="bi bi-search" aria-hidden="true" />
            <input id="workspace-search" type="search" placeholder="Rechercher une application…" value={search} onChange={(event) => setSearch(event.target.value)} autoComplete="off" />
          </form>
        </div>

        {loading ? <p className="workspace-state" role="status">Chargement de vos applications…</p> : null}
        {!loading && error ? <div className="workspace-state" role="alert"><i className="bi bi-exclamation-circle" aria-hidden="true" /><p>{error}</p><button type="button" onClick={() => setVersion((current) => current + 1)}>Réessayer</button></div> : null}
        {!loading && !error ? (
          <>
            <p className="workspace-result" role="status">{visible.length} application{visible.length === 1 ? "" : "s"}{query ? " correspondant à votre recherche" : " disponible" + (visible.length === 1 ? "" : "s")}</p>
            <nav className="workspace-modules" aria-label="Applications disponibles">
              {visible.map((module) => (
                <Link className={"workspace-app is-" + module.tone} to={module.path} key={module.key}>
                  <span className="workspace-app-icon"><i className={"bi bi-" + module.icon} aria-hidden="true" /></span>
                  <strong>{module.label}</strong>
                  <span className="workspace-app-description">{module.description}</span>
                </Link>
              ))}
            </nav>
            {!visible.length ? <div className="workspace-state"><i className="bi bi-search" aria-hidden="true" /><p>{query ? "Aucune application ne correspond à votre recherche." : "Aucune application n’est attribuée à ce compte."}</p>{query ? <button type="button" onClick={() => setSearch("")}>Effacer la recherche</button> : null}</div> : null}
          </>
        ) : null}
        <p className="workspace-access-note"><i className="bi bi-person-check" aria-hidden="true" /> Les applications affichées correspondent à vos autorisations.</p>
      </main>
    </div>
  );
}
