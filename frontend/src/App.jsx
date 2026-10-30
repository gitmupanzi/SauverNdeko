import ModuleSidebar from "./components/ModuleSidebar";
import lazyView from "./components/LazyView";
import ModuleHeader from "./components/ModuleHeader";
import ModuleGate from "./components/ModuleGate";
import { mayOpen, accessSignature } from "./services/moduleAccess";
import AppIcon from "./components/AppIcon";
import { startTransition, useDeferredValue, useEffect, useRef, useState } from "react";
import { Navigate, Route, Routes, useLocation, useMatch, useNavigate } from "react-router-dom";
import AdminRoute from "./components/AdminRoute";
import Navbar from "./components/Navbar";
import ProtectedRoute from "./components/ProtectedRoute";
import { useAuth } from "./contexts/AuthContext";
import Login, { SessionLoading } from "./pages/Login";
import { loginPathFor } from "./services/authNavigation";
import { usePublicCatalogue } from "./hooks/usePublicCatalogue";
import { buildDiscussionPath, matchesSearch, normalizeText } from "./services/mappers";

const PasswordReset=lazyView(()=>import("./pages/PasswordReset"),{label:"Ouverture de la page…"});
const Applications=lazyView(()=>import("./pages/Applications"),{label:"Ouverture de la page…"});
const ApplicationLicences=lazyView(()=>import("./pages/ApplicationLicences"),{label:"Ouverture de la page…"});
const Discussions=lazyView(()=>import("./pages/Discussions"),{label:"Ouverture de la page…"});
const Diseases=lazyView(()=>import("./pages/Diseases"),{label:"Ouverture de la page…"});
const Experts=lazyView(()=>import("./pages/Experts"),{label:"Ouverture de la page…"});
const Home=lazyView(()=>import("./pages/Home"),{label:"Ouverture de la page…"});
const Pharmacies=lazyView(()=>import("./pages/Pharmacies"),{label:"Ouverture de la page…"});
const Products=lazyView(()=>import("./pages/Products"),{label:"Ouverture de la page…"});
const Profile=lazyView(()=>import("./pages/Profile"),{label:"Ouverture du profil…"});
const WorkspaceHome=lazyView(()=>import("./pages/WorkspaceHome"),{label:"Ouverture de vos applications…"});
const Admin=lazyView(()=>import("./pages/Admin"),{label:"Ouverture de l’administration…"});
const Logistique=lazyView(()=>import("./pages/Logistique"),{label:"Ouverture de la logistique…"});
const Referentiels=lazyView(()=>import("./pages/Referentiels"),{label:"Ouverture de la page…"});
const OrganisationTerritoriale=lazyView(()=>import("./pages/OrganisationTerritoriale"),{label:"Ouverture de la page…"});

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
  const {pathname}=useLocation(),canAccessAdmin=Boolean(user?.permissions?.canAccessAdmin);
  const catalogue=[
    {key:"/produits",label:"Produits",icon:"bi-capsule"},
    {key:"/pharmacies",label:"Pharmacies",icon:"globe"},
    {key:"/experts",label:"Experts",icon:"user"},
    {key:"/maladies",label:"Informations santé",icon:"bi-heart-pulse"},
    {key:"/discussions",label:"Discussions",icon:"bi-chat-dots"},
  ].filter(item=>mayOpen(user,item.key));
  const modules=[
    {key:"/logistique",label:"Logistique",icon:"box"},
    {key:"/territoires",label:"Organisation territoriale",icon:"globe"},
    {key:"/referentiels",label:"Référentiels",icon:"tag"},
    ...(canAccessAdmin?[{key:"/admin",label:"Administration",icon:"shield"}]:[]),
  ].filter(item=>mayOpen(user,item.key));
  return <ModuleSidebar title="Applications" overlay open={isOpen} onClose={onClose} activeKey={pathname} onNavigate={onNavigate} storageKey="sauverndeko.catalogue.navigation" groups={[
    {label:"Votre espace",items:[{key:"/",label:"Applications",icon:"apps"}]},
    {label:"Catalogue",items:catalogue},
    {label:"Gestion",items:modules},
  ]} footerItems={isAuthenticated?[
    {key:"/profil",label:"Mon profil",icon:"user",onClick:()=>onNavigate("/profil")},
    {key:"logout",label:"Se déconnecter",icon:"logout",onClick:onLogout},
  ]:[{key:"/login",label:"Se connecter",icon:"lock",onClick:()=>onNavigate("/login")}]}/>;
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
        <AppIcon name="search" size={18} />
      </button>
    </nav>
  );
}

function ApplicationShell() {
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
    startTransition(() => navigate(path, options));
  }

  async function handleLogout() {
    await logout();
    closeOverlays();

    navigate("/login", { replace: true });
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
              path="/catalogue"
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

export default function App() {
  const location = useLocation();
  const isLoginRoute = useMatch("/login");
  const isRegisterRoute = useMatch("/register");
  const isPasswordResetRoute = useMatch("/reset-password");
  const { loading, isAuthenticated, user } = useAuth();
  const scopeKey = [user?.IdUser, user?.IdEntiteFk, user?.IdRoleFk, user?.permissions?.canAccessAdmin, accessSignature(user)].join(":");

  if (isPasswordResetRoute) return <PasswordReset />;
  if (isLoginRoute) return <Login />;
  if (isRegisterRoute) return <Navigate to="/login" replace />;
  if (loading) return <SessionLoading />;
  if (!isAuthenticated) {
    return <Navigate to={loginPathFor(location)} replace />;
  }
  if (location.pathname === "/") return <WorkspaceHome key={scopeKey} />;
  if (location.pathname === "/profil") return <div className="applications-page"><ModuleHeader title="Mon profil" /><Profile key={scopeKey} /></div>;
  if (location.pathname === "/applications") return <Applications key={scopeKey} />;
  if (location.pathname === "/abonnements") return <AdminRoute><ApplicationLicences key={scopeKey} /></AdminRoute>;
  if (location.pathname === "/admin") return <ModuleGate><AdminRoute><Admin key={scopeKey} /></AdminRoute></ModuleGate>;
  if (location.pathname === "/logistique") return <ModuleGate><AdminRoute><Logistique key={scopeKey} /></AdminRoute></ModuleGate>;
  if (location.pathname === "/referentiels") return <ModuleGate><AdminRoute><Referentiels key={scopeKey} /></AdminRoute></ModuleGate>;
  if (location.pathname === "/territoires") return <ModuleGate><AdminRoute><OrganisationTerritoriale key={scopeKey} /></AdminRoute></ModuleGate>;
  return <ModuleGate><ApplicationShell key={scopeKey} /></ModuleGate>;
}
