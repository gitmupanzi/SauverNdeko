import { useEffect, useId, useRef, useState } from "react";
import ActionButton from "../../components/ActionButton";
import AppIcon from "../../components/AppIcon";
import ConsultationTabs from "../../components/ConsultationTabs";
import DrawerDialog from "../../components/DrawerDialog";
import ListState from "../../components/ListState";
import SearchSelect from "../../components/SearchSelect";
import TablePagination from "../../components/TablePagination";
import AnnouncementComposer from "./AnnouncementComposer";
import {
  communicationTime, getAnnouncementContext, getAnnouncements, markNotificationRead, onNotificationsChanged, refreshNotifications,
} from "../../services/communication";

const pageSize = 20;
const receivedTabs = [{ key: "recues", label: "Reçues", icon: "bell" }];
const historyTabs = [...receivedTabs, { key: "emises", label: "Diffusées", icon: "clock" }];
const filters = [
  { value: "all", label: "Toutes les annonces" },
  { value: "unread", label: "Non lues" },
];

function audienceLabel(item) {
  if (item.scope === "all") return "Toutes les entreprises";
  const names = (item.companies || []).map(company => company.name).filter(Boolean);
  return names.join(", ") || "Entreprise";
}

function AnnouncementMeta({ item, received }) {
  const date = communicationTime(item.createdAt);
  return <span className="communication-announcement-meta">
    {received && !item.read && <span className="communication-unread">Non lue</span>}
    {item.authorName && <span>{item.authorName}</span>}
    {!received && <span>{audienceLabel(item)}</span>}
    {date && <time dateTime={item.createdAt}>{date}</time>}
  </span>;
}

function AnnouncementDetail({ item, received, canMarkRead, onRead, onClose }) {
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const lock = useRef(false);
  const mounted = useRef(false);
  useEffect(() => {
    mounted.current = true;
    return () => { mounted.current = false; };
  }, []);
  async function read() {
    if (lock.current || item.read || !canMarkRead) return;
    lock.current = true;
    setBusy(true);
    setError("");
    const result = await markNotificationRead(item.id);
    if (result?.success) refreshNotifications();
    if (!mounted.current) return;
    lock.current = false;
    setBusy(false);
    if (result?.success) onRead();
    else setError(result?.message || "Impossible d’enregistrer la lecture.");
  }
  return <DrawerDialog title={item.title || "Annonce"} icon="bell" onClose={onClose} busy={busy}
    storageKey="sauverndeko.discussions.announcement-detail.width" defaultWidth={680}
    footer={<footer className="record-editor-footer"><span>{received && item.read ? "Annonce lue" : ""}</span><div>
      <ActionButton onClick={onClose} disabled={busy}>Fermer</ActionButton>
      {received && canMarkRead && !item.read && <ActionButton icon="check-circle" variant="primary" onClick={read} disabled={busy}>
        {busy ? "Enregistrement…" : "Marquer comme lue"}
      </ActionButton>}
    </div></footer>}>
    <div className="communication-announcement-detail">
      <AnnouncementMeta item={item} received={received} />
      {!received && <p className="communication-announcement-delivery">{item.readCount ?? 0} lecture{item.readCount === 1 ? "" : "s"} · {item.recipientCount ?? 0} destinataire{item.recipientCount === 1 ? "" : "s"}</p>}
      {error && <p role="alert" className="communication-feedback is-error">{error}</p>}
      <p className="communication-announcement-body">{item.body}</p>
    </div>
  </DrawerDialog>;
}

export default function Announcements() {
  const prefix = useId();
  const [context, setContext] = useState(null);
  const [contextError, setContextError] = useState("");
  const [contextRevision, setContextRevision] = useState(0);
  const [tab, setTab] = useState("recues");
  const [filter, setFilter] = useState("all");
  const [page, setPage] = useState(1);
  const [revision, setRevision] = useState(0);
  const [list, setList] = useState(null);
  const [compose, setCompose] = useState(false);
  const [opened, setOpened] = useState(null);
  const [notice, setNotice] = useState("");
  const received = tab === "recues";
  const listKey = tab + ":" + filter + ":" + page;
  const current = list?.key === listKey ? list : null;
  const rows = current?.rows || [];

  useEffect(() => {
    const controller = new AbortController();
    setContextError("");
    getAnnouncementContext(controller.signal).then(result => {
      if (controller.signal.aborted) return;
      setContext(result?.success ? result.data : null);
      if (!result?.success) setContextError(result?.message || "Impossible de charger les droits de diffusion.");
    });
    return () => controller.abort();
  }, [contextRevision]);

  useEffect(() => {
    const controller = new AbortController();
    setList(previous => previous?.key === listKey ? { ...previous, error: "", loading: true } : null);
    getAnnouncements(tab, { page, pageSize, ...(received ? { read: filter } : {}) }, controller.signal).then(result => {
      if (controller.signal.aborted) return;
      if (!result?.success) {
        setList({ key: listKey, rows: [], meta: null, loading: false, error: result?.message || "Impossible de charger les annonces." });
        return;
      }
      const last = Math.max(1, Math.ceil((result.meta?.total || 0) / pageSize));
      if (page > last) { setPage(last); return; }
      setList({ key: listKey, rows: result.data || [], meta: result.meta, loading: false, error: "" });
    });
    return () => controller.abort();
  }, [tab, page, filter, received, listKey, revision]);

  useEffect(() => onNotificationsChanged(() => {
    if (received) setRevision(value => value + 1);
  }), [received]);

  function changeTab(next) {
    setTab(next);
    setPage(1);
    setOpened(null);
  }

  function afterPublish(item) {
    setCompose(false);
    setNotice("Annonce diffusée." + (typeof item?.recipientCount === "number"
      ? " " + item.recipientCount + " destinataire" + (item.recipientCount === 1 ? "." : "s.") : ""));
    changeTab("emises");
    setRevision(value => value + 1);
    refreshNotifications();
  }

  return <section aria-label="Annonces">
    <header className="communication-page-heading">
      <div><h1>Annonces</h1><p>Les communications de votre entreprise et de la plateforme.</p></div>
      {context?.canPublish && <ActionButton icon="plus" variant="primary" onClick={() => { setNotice(""); setCompose(true); }}>Nouvelle annonce</ActionButton>}
    </header>
    {notice && <div className="communication-feedback is-success" role="status"><AppIcon name="check-circle" />{notice}</div>}
    {contextError && <div className="communication-feedback is-error" role="alert"><span>{contextError}</span>
      <ActionButton icon="refresh" onClick={() => setContextRevision(value => value + 1)}>Réessayer</ActionButton></div>}
    <div className="communication-announcements">
      <div className="communication-announcement-toolbar">
        {context?.canViewSent ? <ConsultationTabs tabs={historyTabs} value={tab} onChange={changeTab} label="Registre des annonces" idPrefix={prefix} />
          : <h2>Annonces reçues</h2>}
        <div className="communication-announcement-tools">
          {received && <SearchSelect label="Filtrer les annonces" options={filters} value={filter} onChange={value => { setFilter(value); setPage(1); }} />}
          <ActionButton icon="refresh" className="communication-icon-action" title="Actualiser les annonces" aria-label="Actualiser les annonces"
            onClick={() => setRevision(value => value + 1)} disabled={!current || current.loading} />
        </div>
      </div>
      <div id={prefix + "-panel-" + tab} role={context?.canViewSent ? "tabpanel" : undefined}
        aria-labelledby={context?.canViewSent ? prefix + "-tab-" + tab : undefined} aria-busy={!current || current.loading}>
        {current?.error ? <ListState role="alert" icon="alert" title={current.error}
          action={<ActionButton icon="refresh" onClick={() => setRevision(value => value + 1)}>Réessayer</ActionButton>} />
          : rows.length ? <ul className="communication-announcement-list">{rows.map(item => <li key={item.id}>
            <button type="button" className={"communication-announcement-row" + (received && !item.read ? " is-unread" : "")}
              onClick={() => setOpened(item)}>
              <span className="communication-avatar"><AppIcon name="bell" size={18} /></span>
              <span className="communication-announcement-copy"><strong>{item.title || "Annonce"}</strong>
                <AnnouncementMeta item={item} received={received} /><span className="communication-announcement-excerpt">{item.body}</span>
                {!received && <span className="communication-announcement-delivery">{item.readCount ?? 0} / {item.recipientCount ?? 0} lectures</span>}
              </span>
              <AppIcon name="chevron-right" />
            </button>
          </li>)}</ul> : <ListState role="status" loading={!current || current.loading} icon="bell"
            title={!current || current.loading ? "Chargement des annonces…" : !received ? "Aucune annonce diffusée"
              : filter === "unread" ? "Aucune annonce non lue" : "Aucune annonce reçue"}
            description={current && !current.loading && received && filter === "all" ? "Les annonces qui vous sont adressées apparaissent ici." : undefined} />}
        {current?.meta && <TablePagination total={current.meta.total} take={pageSize} page={page} onPage={setPage} loading={current.loading} />}
      </div>
    </div>
    {opened && <AnnouncementDetail key={opened.id} item={opened} received={received} canMarkRead={current?.meta?.canMarkRead === true}
      onClose={() => setOpened(null)} onRead={() => setOpened(previous => previous ? { ...previous, read: true } : null)} />}
    {compose && context?.canPublish && <AnnouncementComposer context={context} onClose={() => setCompose(false)} onSent={afterPublish} />}
  </section>;
}
