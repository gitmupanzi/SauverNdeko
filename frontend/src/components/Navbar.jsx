import { mayOpen } from "../services/moduleAccess";
import AppIcon from "./AppIcon";
import { useEffect, useRef, useState } from "react";
import { NavLink } from "react-router-dom";

const NAV_ITEMS = [
  { label: "Applications", path: "/" },
  { label: "Produits", path: "/produits" },
  { label: "Pharmacies", path: "/pharmacies" },
  { label: "Experts", path: "/experts" },
  { label: "Maladies", path: "/maladies" },
  { label: "Discussions", path: "/discussions" },
];

const TITLE_BY_PATH = {
  "/": "Applications",
  "/catalogue": "Catalogue",
  "/produits": "Produits",
  "/pharmacies": "Pharmacies et depots",
  "/experts": "Experts",
  "/maladies": "Maladies",
  "/discussions": "Discussions",
  "/login": "Connexion",
  "/register": "Creer un compte",
  "/profil": "Profil",
  "/admin": "Administration",
  "/logistique": "Logistique",
};

export default function Navbar({
  currentPath,
  onOpenMenu,
  onOpenSearch,
  isAuthenticated,
  user,
  onLogout,
}) {
  const [isUserMenuOpen, setIsUserMenuOpen] = useState(false);
  const userMenuRef = useRef(null);
  const pageTitle = TITLE_BY_PATH[currentPath] || "SauverNdeko";
  const showSearch = currentPath !== "/discussions" && ["/produits","/pharmacies","/experts"].some(path => mayOpen(user,path));
  const displayName = user?.PrenomUser || user?.NomUser || "Mon profil";
  const canAccessAdmin = Boolean(user?.permissions?.canAccessAdmin);
  const navItems = (canAccessAdmin ? [...NAV_ITEMS, { label: "Logistique", path: "/logistique" }] : NAV_ITEMS).filter(item => mayOpen(user,item.path));

  useEffect(() => {
    setIsUserMenuOpen(false);
  }, [currentPath, isAuthenticated]);

  useEffect(() => {
    if (!isUserMenuOpen) {
      return undefined;
    }

    function handlePointerDown(event) {
      if (!userMenuRef.current?.contains(event.target)) {
        setIsUserMenuOpen(false);
      }
    }

    function handleEscape(event) {
      if (event.key === "Escape") {
        setIsUserMenuOpen(false);
      }
    }

    window.addEventListener("mousedown", handlePointerDown);
    window.addEventListener("keydown", handleEscape);

    return () => {
      window.removeEventListener("mousedown", handlePointerDown);
      window.removeEventListener("keydown", handleEscape);
    };
  }, [isUserMenuOpen]);

  async function handleLogoutClick() {
    setIsUserMenuOpen(false);
    await onLogout?.();
  }

  return (
    <header className="topbar">
      <div className="topbar-mobile">
        <button className="icon-button" type="button" onClick={onOpenMenu} aria-label="Ouvrir le menu">
          <i className="bi bi-list" aria-hidden="true" />
        </button>
        <h1 className="topbar-title">{pageTitle}</h1>
        {showSearch ? (
          <button className="icon-button" type="button" onClick={onOpenSearch} aria-label="Ouvrir la recherche">
            <AppIcon name="search" size={18} />
          </button>
        ) : (
          <span className="topbar-spacer" aria-hidden="true" />
        )}
      </div>

      <div className="topbar-desktop">
        <NavLink className="desktop-brand" to="/">
          <img src="/sauverndeko-logo.jpg" alt="SauverNdeko" />
          <span>
            <strong>SauverNdeko</strong>
            <small>Rechercher, contacter, acheter</small>
          </span>
        </NavLink>

        <nav className="desktop-tabs" aria-label="Navigation principale">
          {navItems.map((item) => (
            <NavLink
              key={item.path}
              to={item.path}
              end={item.path === "/"}
              className={({ isActive }) => `desktop-tab ${isActive ? "is-active" : ""}`}
            >
              {item.label}
            </NavLink>
          ))}
        </nav>

        <div className="desktop-actions">
          {showSearch ? (
            <button className="desktop-search" type="button" onClick={onOpenSearch}>
              <AppIcon name="search" size={18} />
              <span>Rechercher</span>
            </button>
          ) : (
            <div className="desktop-search desktop-search-static">
              <i className="bi bi-chat-dots" aria-hidden="true" />
              <span>Contact public</span>
            </div>
          )}

          {isAuthenticated ? (
            <div className={`desktop-user-menu ${isUserMenuOpen ? "is-open" : ""}`} ref={userMenuRef}>
              <button
                className="desktop-account-link desktop-user-trigger"
                type="button"
                onClick={() => setIsUserMenuOpen((current) => !current)}
                aria-haspopup="menu"
                aria-expanded={isUserMenuOpen}
              >
                <i className="bi bi-person-circle" aria-hidden="true" />
                <span>{displayName}</span>
                <i className={`bi ${isUserMenuOpen ? "bi-chevron-up" : "bi-chevron-down"}`} aria-hidden="true" />
              </button>

              {isUserMenuOpen ? (
                <div className="desktop-user-dropdown" role="menu" aria-label="Menu utilisateur">
                  <NavLink className="desktop-user-option" to="/profil">
                    Profil
                  </NavLink>
                  {canAccessAdmin && mayOpen(user,"/admin") ? (
                    <NavLink className="desktop-user-option" to="/admin">
                      Administration
                    </NavLink>
                  ) : null}
                  {canAccessAdmin && mayOpen(user,"/logistique") ? (
                    <NavLink className="desktop-user-option" to="/logistique">
                      Logistique
                    </NavLink>
                  ) : null}
                  <button className="desktop-user-option is-danger" type="button" onClick={handleLogoutClick}>
                    Se deconnecter
                  </button>
                </div>
              ) : null}
            </div>
          ) : (
            <NavLink className="desktop-auth-button" to="/login">
              Se connecter
            </NavLink>
          )}
        </div>
      </div>
    </header>
  );
}
