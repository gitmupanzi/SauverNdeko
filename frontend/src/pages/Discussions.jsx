import { useEffect, useState } from "react";
import { useSearchParams } from "react-router-dom";
import ModuleSidebar from "../components/ModuleSidebar";
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

export default function Discussions() {
  const [params, setParams] = useSearchParams();
  const [collapsed, setCollapsed] = useState(() => {
    try { return localStorage.getItem(sidebarPreference) !== "false"; }
    catch { return true; }
  });
  const active = ["annonces", "demandes"].includes(params.get("onglet")) ? params.get("onglet") : "messages";

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
    <div className={"logistics-modern logistics-app admin-portal communications-module" + (active === "messages" ? " is-messaging" : "") + (collapsed ? " is-menu-collapsed" : "")}>
      <ModuleSidebar title="Discussions" groups={menuGroups} activeKey={active}
        onNavigate={navigate} collapsed={collapsed} onToggle={() => setCollapsed(value => !value)}
        storageKey="sauverndeko.discussions.navigation" headerProps={{ showEntityScope: false }} />
      <main className="admin-main communications-main" tabIndex={-1}>
        <section className="communication-messaging" hidden={active !== "messages"} aria-label="Messages privés">
          <DiscussionMessages visible={active === "messages"} />
        </section>
        {active === "annonces" && <Announcements />}
        {active === "demandes" && <DemandRegister />}
      </main>
    </div>
  );
}
