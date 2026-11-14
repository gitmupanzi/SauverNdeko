import { useEffect, useState } from "react";
import { useLocation, useSearchParams } from "react-router-dom";
import ModuleSidebar from "../components/ModuleSidebar";
import ListState from "../components/ListState";
import ActionButton from "../components/ActionButton";
import { useAuth } from "../contexts/AuthContext";
import { useEntityScope } from "../contexts/EntityScopeContext";
import { presentedModuleTabs, useModulePresentation } from "../hooks/useModulePresentation";
import { tabRights } from "../services/moduleAccess";
import DiscussionMessages from "./discussions/DiscussionMessages";
import Announcements from "./discussions/Announcements";
import DemandRegister from "./demandes/DemandRegister";
import "./logistique/LogistiqueModern.css";
import "./admin/AdminPortal.css";
import "./discussions/Discussions.css";

const sidebarPreference = "sauverndeko.discussions.sidebar-collapsed";
const menuGroups = [{
  key: "communication",
  label: "Communication",
  items: [
    { key: "messages", label: "Messages", icon: "chat" },
    { key: "demandes", label: "Demandes", icon: "list" },
    { key: "annonces", label: "Annonces", icon: "bell" },
  ],
}];

function requestedTab(params) {
  const tab = params.get("onglet");
  if (tab) return tab;
  if (params.has("demande")) return "demandes";
  if (params.has("discussion") || params.has("type") || params.has("id")) return "messages";
  return null;
}

export default function Discussions() {
  const location = useLocation();
  const {user} = useAuth();
  const scope = useEntityScope();
  const { presentation, loading, error, retry } = useModulePresentation("discussions", scope);
  const [params, setParams] = useSearchParams();
  const [collapsed, setCollapsed] = useState(() => {
    try { return localStorage.getItem(sidebarPreference) !== "false"; }
    catch { return true; }
  });
  const readableItems = menuGroups[0].items.filter(item => tabRights(user, "discussions", item.key).canRead);
  const items = loading ? [] : presentedModuleTabs(readableItems, presentation);
  const requested = requestedTab(params);
  const active = requested || items[0]?.key;
  const canReadActive = readableItems.some(item => item.key === active);
  const showMessages = readableItems.some(item => item.key === "messages");
  const titles = presentation?.tabLabels;

  useEffect(() => {
    try { localStorage.setItem(sidebarPreference, String(collapsed)); }
    catch { /* Préférence d’affichage facultative. */ }
  }, [collapsed]);

  function navigate(tab) {
    if (tab === active) return;
    const next = new URLSearchParams(params);
    next.set("onglet", tab);
    // Une cible de messagerie ne doit pas recréer un fil après un passage
    // par les demandes ou les annonces. Le fil choisi reste dans son URL.
    next.delete("type");
    next.delete("id");
    setParams(next);
  }

  return (
    <div className={"logistics-modern logistics-app admin-portal communications-module" + (canReadActive && active === "messages" ? " is-messaging" : "") + (collapsed ? " is-menu-collapsed" : "")}>
      <ModuleSidebar title="Discussions" groups={[{...menuGroups[0], items}]} activeKey={active}
        onNavigate={navigate} collapsed={collapsed} onToggle={() => setCollapsed(value => !value)}
        storageKey="sauverndeko.discussions.navigation" headerProps={{ showEntityScope: false }} />
      <main className="admin-main communications-main" tabIndex={-1}>
        {error && <div className="admin-error" role="status"><span>Les réglages d’affichage sont indisponibles. La présentation standard est utilisée.</span><ActionButton icon="refresh" onClick={retry}>Réessayer</ActionButton></div>}
        {loading && !requested && <ListState loading role="status" title="Chargement de la présentation…" />}
        {showMessages && <section className="communication-messaging" hidden={active !== "messages"} aria-label="Messages privés">
          <DiscussionMessages visible={active === "messages"} title={titles?.messages} />
        </section>}
        {requested && !canReadActive && <ListState icon="shield" role="alert" title="Vous n’avez pas accès à cet onglet." />}
        {!requested && !loading && !active && <ListState icon="shield" title={readableItems.length ? "Aucun onglet visible" : "Aucun onglet accessible"} />}
        {canReadActive && active === "annonces" && <Announcements title={titles?.annonces} />}
        {canReadActive && active === "demandes" && <DemandRegister title={titles?.demandes}
          intake={location.state?.newNeed} navigationKey={location.key} />}
      </main>
    </div>
  );
}
