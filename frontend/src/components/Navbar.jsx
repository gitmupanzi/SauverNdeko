import { mayOpen } from "../services/moduleAccess";
import AppIcon from "./AppIcon";
import AccountControls from "./AccountControls";
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
  const pageTitle = TITLE_BY_PATH[currentPath] || "SauverNdeko";
  const showSearch = currentPath !== "/discussions" && ["/produits","/pharmacies","/experts"].some(path => mayOpen(user,path));
  const canAccessAdmin = Boolean(user?.permissions?.canAccessAdmin);
  const navItems = (canAccessAdmin ? [...NAV_ITEMS, { label: "Logistique", path: "/logistique" }] : NAV_ITEMS).filter(item => mayOpen(user,item.path));
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
            <AccountControls onLogout={onLogout} />
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
