import { startTransition, useDeferredValue, useEffect, useRef, useState } from "react";
import { Navigate, Route, Routes, useLocation, useNavigate } from "react-router-dom";
import AdminRoute from "./components/AdminRoute";
import Navbar from "./components/Navbar";
import ProtectedRoute from "./components/ProtectedRoute";
import { useAuth } from "./contexts/AuthContext";
import Discussions from "./pages/Discussions";
import Diseases from "./pages/Diseases";
import Experts from "./pages/Experts";
import Home from "./pages/Home";
import Login from "./pages/Login";
import Pharmacies from "./pages/Pharmacies";
import Products from "./pages/Products";
import Profile from "./pages/Profile";
import Register from "./pages/Register";
import Admin from "./pages/Admin";
import Logistique from "./pages/Logistique";
import { usePublicCatalogue } from "./hooks/usePublicCatalogue";
import { buildDiscussionPath, matchesSearch, normalizeText } from "./services/mappers";

function SearchResultGroup({ title, items, onSelect }) {
  return (
    <section className="search-group">
      <div className="search-group-head">
        <strong>{title}</strong>
        <span>{items.length}</span>
      </div>
      {items.length === 0 ? (
        <div className="search-empty-inline">Aucun resultat.</div>
      ) : (
        <div className="search-list">
          {items.map((item) => (
            <button
              key={item.id}
              className="search-result"
              type="button"
              onClick={() => onSelect(item)}
            >
              <strong>{item.title}</strong>
              <span>{item.subtitle}</span>
            </button>
          ))}
        </div>
      )}
    </section>
  );
}

function SearchOverlay({ isOpen, search, results, onClose, onChange, onSelect, inputRef }) {
  return (
    <section className={`search-overlay ${isOpen ? "is-open" : ""}`} aria-hidden={!isOpen}>
      <div className="search-modal">
        <div className="search-head">
          <div>
            <span className="search-kicker">Recherche</span>
            <h2>Rechercher un produit, une pharmacie ou un expert</h2>
          </div>
          <button className="search-close" type="button" onClick={onClose}>
            Fermer
          </button>
        </div>

        <input
          ref={inputRef}
          className="search-input"
          type="search"
          placeholder="Produit, pharmacie, expert..."
          value={search}
          onChange={onChange}
        />

        {!search ? (
          <div className="search-helper-grid">
            <article>
              <strong>Produit</strong>
              <p>Trouvez rapidement un article public et consultez sa fiche.</p>
            </article>
            <article>
              <strong>Pharmacie</strong>
              <p>Reperez les structures et points de disponibilite utiles.</p>
            </article>
            <article>
              <strong>Expert</strong>
              <p>Consultez les profils publics et preparez la prise de contact.</p>
            </article>
          </div>
        ) : normalizeText(search).length < 2 ? (
          <div className="search-empty-panel">Ecrivez au moins 2 caracteres.</div>
        ) : (
          <div className="search-results-grid">
            <SearchResultGroup title="Produits" items={results.products} onSelect={onSelect} />
            <SearchResultGroup title="Pharmacies" items={results.pharmacies} onSelect={onSelect} />
            <SearchResultGroup title="Experts" items={results.experts} onSelect={onSelect} />
          </div>
        )}
      </div>
    </section>
  );
}

function SidebarDrawer({ isOpen, onClose, onNavigate, isAuthenticated, user, onLogout }) {
  const canAccessAdmin = Boolean(user?.permissions?.canAccessAdmin);
  const items = [
    { label: "Accueil", path: "/", icon: "bi-house-door" },
    { label: "Produits", path: "/produits", icon: "bi-capsule" },
    { label: "Pharmacies", path: "/pharmacies", icon: "bi-geo-alt" },
    { label: "Experts", path: "/experts", icon: "bi-people" },
    { label: "Maladies", path: "/maladies", icon: "bi-virus2" },
    { label: "Discussions", path: "/discussions", icon: "bi-chat-dots" },
    ...(isAuthenticated ? [{ label: "Profil", path: "/profil", icon: "bi-person-circle" }] : []),
    ...(canAccessAdmin ? [{ label: "Logistique", path: "/logistique", icon: "bi-box-seam" }] : []),
    ...(canAccessAdmin ? [{ label: "Administration", path: "/admin", icon: "bi-shield-lock" }] : []),
  ];

  return (
    <aside className={`sidebar-drawer ${isOpen ? "is-open" : ""}`} aria-hidden={!isOpen}>
      <div className="drawer-banner">
        <span>Menu</span>
        <button className="icon-button drawer-menu-button" type="button" onClick={onClose}>
          <i className="bi bi-x-lg" aria-hidden="true" />
        </button>
      </div>

      <div className="drawer-account-card">
        <span className="drawer-account-kicker">{isAuthenticated ? "Session active" : "Mode public"}</span>
        <strong>
          {isAuthenticated
            ? `${user?.PrenomUser || ""} ${user?.NomUser || ""}`.trim() || "Utilisateur"
            : "Connectez-vous pour acceder a votre espace"}
        </strong>
        <p>
          {isAuthenticated
            ? user?.EmailUser || "Compte utilisateur"
            : "Les discussions et le profil deviennent disponibles apres authentification."}
        </p>
      </div>

      <nav className="drawer-nav">
        {items.map((item) => (
          <button
            key={item.path}
            className="drawer-row"
            type="button"
            onClick={() => onNavigate(item.path)}
          >
            <span className="drawer-row-icon">
              <i className={`bi ${item.icon}`} aria-hidden="true" />
            </span>
            <span className="drawer-row-label">{item.label}</span>
          </button>
        ))}
      </nav>

      <div className="drawer-auth-actions">
        {isAuthenticated ? (
          <button className="secondary-action" type="button" onClick={onLogout}>
            Se deconnecter
          </button>
        ) : (
          <>
            <button className="primary-action" type="button" onClick={() => onNavigate("/login")}>
              Se connecter
            </button>
            <button className="secondary-action" type="button" onClick={() => onNavigate("/register")}>
              Creer un compte
            </button>
          </>
        )}
      </div>
    </aside>
  );
}

function BottomNav({ currentPath, onHome, onDiscussions, onSearch }) {
  return (
    <nav className="bottom-nav">
      <button
        className={`bottom-icon ${currentPath === "/discussions" ? "is-active" : ""}`}
        type="button"
        onClick={onDiscussions}
      >
        <i className="bi bi-chat-dots" aria-hidden="true" />
      </button>

      <button className="home-fab" type="button" onClick={onHome}>
        <i className="bi bi-house-door" aria-hidden="true" />
      </button>

      <button className="bottom-icon" type="button" onClick={onSearch}>
        <i className="bi bi-search" aria-hidden="true" />
      </button>
    </nav>
  );
}

export default function App() {
  const location = useLocation();
  const navigate = useNavigate();
  const { health, catalogue } = usePublicCatalogue();
  const { isAuthenticated, user, logout } = useAuth();
  const [search, setSearch] = useState("");
  const deferredSearch = useDeferredValue(normalizeText(search));
  const [isSidebarOpen, setIsSidebarOpen] = useState(false);
  const [isSearchOpen, setIsSearchOpen] = useState(false);
  const searchInputRef = useRef(null);
  const contentRef = useRef(null);

  useEffect(() => {
    if (!isSearchOpen) {
      return;
    }

    const timer = window.setTimeout(() => {
      searchInputRef.current?.focus();
    }, 40);

    return () => window.clearTimeout(timer);
  }, [isSearchOpen]);

  useEffect(() => {
    contentRef.current?.scrollTo({ top: 0, behavior: "smooth" });
  }, [location.pathname, location.search]);

  function closeOverlays() {
    setIsSidebarOpen(false);
    setIsSearchOpen(false);
  }

  function toggleSearchOverlay() {
    setIsSidebarOpen(false);
    setIsSearchOpen((current) => !current);
  }

  function goTo(path, options) {
    closeOverlays();
    navigate(path, options);
  }

  async function handleLogout() {
    await logout();
    closeOverlays();

    if (["/discussions", "/profil", "/admin", "/logistique"].includes(location.pathname)) {
      navigate("/", { replace: true });
    }
  }

  function handleSearchChange(event) {
    const nextValue = event.target.value;
    startTransition(() => {
      setSearch(nextValue);
    });
  }

  function handleSearchSelect(result) {
    if (result.type === "product") {
      goTo("/produits", { state: { focusId: result.payload.id } });
      return;
    }

    if (result.type === "pharmacy") {
      goTo("/pharmacies", { state: { focusId: result.payload.id } });
      return;
    }

    if (result.type === "expert") {
      goTo("/experts", { state: { focusId: result.payload.id } });
      return;
    }

    goTo("/");
  }

  function openDiscussion(target) {
    if (!target?.id || !target?.type) {
      goTo("/discussions");
      return;
    }

    goTo(buildDiscussionPath(target.type, target.id), {
      state: {
        targetName: target.name || null,
        targetType: target.type,
      },
    });
  }

  const searchResults =
    deferredSearch.length < 2
      ? { products: [], pharmacies: [], experts: [] }
      : {
          products: catalogue.articles
            .filter((item) => matchesSearch(item, deferredSearch))
            .slice(0, 5)
            .map((item) => ({
              id: `product-${item.id}`,
              type: "product",
              title: item.name,
              subtitle: item.price,
              payload: item,
            })),
          pharmacies: catalogue.pharmacies
            .filter((item) => matchesSearch(item, deferredSearch))
            .slice(0, 5)
            .map((item) => ({
              id: `pharmacy-${item.id}`,
              type: "pharmacy",
              title: item.name,
              subtitle: item.address,
              payload: item,
            })),
          experts: catalogue.experts
            .filter((item) => matchesSearch(item, deferredSearch))
            .slice(0, 5)
            .map((item) => ({
              id: `expert-${item.id}`,
              type: "expert",
              title: item.fullName,
              subtitle: item.specialty,
              payload: item,
            })),
        };

  return (
    <div className="app-shell">
      <div className="phone-shell">
        <div
          className={`screen-overlay ${isSidebarOpen || isSearchOpen ? "is-visible" : ""}`}
          onClick={closeOverlays}
        />

        <SidebarDrawer
          isOpen={isSidebarOpen}
          onClose={() => setIsSidebarOpen(false)}
          onNavigate={goTo}
          isAuthenticated={isAuthenticated}
          user={user}
          onLogout={handleLogout}
        />

        <SearchOverlay
          isOpen={isSearchOpen}
          search={search}
          results={searchResults}
          onClose={() => setIsSearchOpen(false)}
          onChange={handleSearchChange}
          onSelect={handleSearchSelect}
          inputRef={searchInputRef}
        />

        <Navbar
          currentPath={location.pathname}
          onOpenMenu={() => setIsSidebarOpen(true)}
          onOpenSearch={toggleSearchOverlay}
          isAuthenticated={isAuthenticated}
          user={user}
          onLogout={handleLogout}
        />

        <main className="mobile-content" ref={contentRef}>
          <Routes>
            <Route
              path="/"
              element={
                <Home
                  health={health}
                  stats={catalogue.stats}
                  products={catalogue.articles}
                  pharmacies={catalogue.pharmacies}
                  experts={catalogue.experts}
                  onOpenSearch={toggleSearchOverlay}
                  onNavigate={goTo}
                  onContact={openDiscussion}
                />
              }
            />
            <Route path="/produits" element={<Products products={catalogue.articles} onNavigate={goTo} />} />
            <Route
              path="/pharmacies"
              element={
                <Pharmacies
                  pharmacies={catalogue.pharmacies}
                  onNavigate={goTo}
                  onContact={openDiscussion}
                />
              }
            />
            <Route path="/experts" element={<Experts experts={catalogue.experts} onContact={openDiscussion} />} />
            <Route path="/maladies" element={<Diseases diseases={catalogue.diseases} />} />
            <Route path="/login" element={<Login />} />
            <Route path="/register" element={<Register />} />
            <Route
              path="/profil"
              element={
                <ProtectedRoute>
                  <Profile />
                </ProtectedRoute>
              }
            />
            <Route
              path="/discussions"
              element={
                <ProtectedRoute>
                  <Discussions experts={catalogue.experts} pharmacies={catalogue.pharmacies} />
                </ProtectedRoute>
              }
            />
            <Route
              path="/admin"
              element={
                <AdminRoute>
                  <Admin />
                </AdminRoute>
              }
            />
            <Route
              path="/logistique"
              element={
                <AdminRoute>
                  <Logistique />
                </AdminRoute>
              }
            />
            <Route path="*" element={<Navigate to="/" replace />} />
          </Routes>
        </main>

        <BottomNav
          currentPath={location.pathname}
          onHome={() => goTo("/")}
          onDiscussions={() => goTo("/discussions")}
          onSearch={toggleSearchOverlay}
        />
      </div>
    </div>
  );
}
