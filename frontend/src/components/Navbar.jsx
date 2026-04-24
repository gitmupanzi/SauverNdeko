import { NavLink } from "react-router-dom";

const NAV_ITEMS = [
  { label: "Accueil", path: "/" },
  { label: "Produits", path: "/produits" },
  { label: "Pharmacies", path: "/pharmacies" },
  { label: "Experts", path: "/experts" },
  { label: "Maladies", path: "/maladies" },
  { label: "Discussions", path: "/discussions" },
];

const TITLE_BY_PATH = {
  "/": "Accueil",
  "/produits": "Produits",
  "/pharmacies": "Pharmacies et dépôts",
  "/experts": "Experts",
  "/maladies": "Maladies",
  "/discussions": "Discussions",
};

export default function Navbar({ currentPath, onOpenMenu, onOpenSearch }) {
  const pageTitle = TITLE_BY_PATH[currentPath] || "SauverNdeko";
  const showSearch = currentPath !== "/discussions";

  return (
    <header className="topbar">
      <div className="topbar-mobile">
        <button className="icon-button" type="button" onClick={onOpenMenu} aria-label="Ouvrir le menu">
          <i className="bi bi-list" aria-hidden="true" />
        </button>
        <h1 className="topbar-title">{pageTitle}</h1>
        {showSearch ? (
          <button className="icon-button" type="button" onClick={onOpenSearch} aria-label="Ouvrir la recherche">
            <i className="bi bi-search" aria-hidden="true" />
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
          {NAV_ITEMS.map((item) => (
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

        {showSearch ? (
          <button className="desktop-search" type="button" onClick={onOpenSearch}>
            <i className="bi bi-search" aria-hidden="true" />
            <span>Rechercher</span>
          </button>
        ) : (
          <div className="desktop-search desktop-search-static">
            <i className="bi bi-chat-dots" aria-hidden="true" />
            <span>Contact public</span>
          </div>
        )}
      </div>
    </header>
  );
}
