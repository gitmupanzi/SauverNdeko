import { useCallback, useEffect, useId, useRef, useState } from "react";
import { useSearchParams } from "react-router-dom";
import AppIcon from "../../components/AppIcon";
import ActionButton from "../../components/ActionButton";
import { ConversationAvatar, conversationName } from "./ConversationIdentity";
import ListState from "../../components/ListState";
import { fetchDiscussions, startDiscussion } from "../../services/api";
import ConversationThread from "./ConversationThread";
import ContactPicker from "./ContactPicker";
import { communicationTime } from "../../services/communication";

const take = 25;
const pollingInterval = 20000;
const validId = value => /^[1-9]\d*$/.test(String(value ?? "")) && Number.isSafeInteger(Number(value));
const emptyList = { rows: [], meta: null, error: "", loading: true };

export default function DiscussionMessages({ visible, title = "Discussions" }) {
  const [params, setParams] = useSearchParams();
  const [contactOpen, setContactOpen] = useState(false);
  const [list, setList] = useState(emptyList);
  const [selection, setSelection] = useState(null);
  const [drafts, setDrafts] = useState({});
  const [search, setSearch] = useState("");
  const [query, setQuery] = useState("");
  const [unreadOnly, setUnreadOnly] = useState(false);
  const [skip, setSkip] = useState(0);
  const [refresh, setRefresh] = useState(0);
  const [startRevision, setStartRevision] = useState(0);
  const [startError, setStartError] = useState("");
  const [starting, setStarting] = useState(false);
  const searchId = useId();
  const searchInput = useRef(null);
  const threadHeading = useRef(null);
  const starter = useRef(null);
  const focusThread = useRef(false);
  const selectedId = validId(params.get("discussion")) ? String(params.get("discussion")) : "";
  const targetType = params.get("type");
  const targetId = params.get("id");
  const hasTarget = Boolean(targetType || targetId);
  const supportedTarget = ["expert", "structure", "user"].includes(targetType) && validId(targetId);
  const selected = list.rows.find(row => String(row.IdDiscussion) === selectedId)
    || (String(selection?.IdDiscussion) === selectedId ? selection : null);

  useEffect(() => {
    if (!visible) return;
    const controller = new AbortController();
    let pending = false;
    async function load(background = false) {
      if (pending) return;
      pending = true;
      if (!background) setList(previous => ({ ...previous, loading: true, error: "" }));
      const result = await fetchDiscussions({ take, skip, q: query, ...(unreadOnly ? { unread: 1 } : {}) }, controller.signal);
      pending = false;
      if (controller.signal.aborted) return;
      if (result?.success && Array.isArray(result.data)) {
        setList({ rows: result.data, meta: result.meta, error: "", loading: false });
      } else {
        setList(previous => ({
          ...previous,
          ...(result?.status === 403 || result?.status === 404 ? { rows: [], meta: null } : {}),
          error: result?.message || "Impossible de charger les conversations.",
          loading: false,
        }));
      }
    }
    load();
    const timer = window.setInterval(() => {
      if (document.visibilityState === "visible") load(true);
    }, pollingInterval);
    return () => { controller.abort(); window.clearInterval(timer); };
  }, [visible, query, unreadOnly, skip, refresh]);

  useEffect(() => {
    if (!visible || !hasTarget || !supportedTarget) {
      setStarting(false);
      setStartError(visible && hasTarget ? "Ce destinataire n’est pas accessible par ce lien." : "");
      return;
    }
    let active = true;
    setStartError("");
    setStarting(true);
    const key = targetType + ":" + targetId;
    if (starter.current?.key !== key) {
      starter.current = { key, request: startDiscussion(targetType, Number(targetId)) };
    }
    const opening = starter.current;
    opening.request.then(result => {
      if (!active) return;
      starter.current = null;
      setStarting(false);
      if (result?.success && validId(result.data?.IdDiscussion)) {
        setSelection(result.data);
        setSkip(0);
        setRefresh(value => value + 1);
        setParams(previous => {
          const next = new URLSearchParams(previous);
          next.delete("type");
          next.delete("id");
          next.set("discussion", result.data.IdDiscussion);
          return next;
        }, { replace: true, state: null });
      } else {
        setStartError(result?.message || "Impossible d’ouvrir cette conversation.");
      }
    });
    return () => { active = false; };
  }, [visible, hasTarget, supportedTarget, targetType, targetId, startRevision, setParams]);

  useEffect(() => {
    if (!focusThread.current || !selectedId) return;
    focusThread.current = false;
    threadHeading.current?.focus({ preventScroll: true });
  }, [selectedId]);

  function select(row) {
    const id = String(row.IdDiscussion);
    setSelection(row);
    if (selectedId === id) return;
    focusThread.current = true;
    setParams(previous => {
      const next = new URLSearchParams(previous);
      next.delete("type");
      next.delete("id");
      next.set("discussion", id);
      return next;
    });
  }

  function backToList() {
    setParams(previous => {
      const next = new URLSearchParams(previous);
      next.delete("discussion");
      return next;
    });
    requestAnimationFrame(() => searchInput.current?.focus({ preventScroll: true }));
  }

  function changeSearch(value) {
    setSearch(value);
    setSkip(0);
    if (value.trim() === query) setRefresh(current => current + 1);
    else setQuery(value.trim());
  }

  const refreshList = useCallback(() => {
    setRefresh(current => current + 1);
  }, []);

  function showUnread(value) {
    if (unreadOnly === value) return;
    setSkip(0);
    setUnreadOnly(value);
  }

  function changeDraft(id, next) {
    setDrafts(previous => {
      const entries = { ...previous };
      if (next.text || next.ticket) entries[id] = next;
      else delete entries[id];
      return entries;
    });
  }

  const canSend = list.meta?.canSend === true;
  const canStart = canSend && list.meta?.contactsAvailable === true;
  const hasNext = list.meta?.hasNext === true;
  return (
    <>
      {startError && <div className="communication-feedback is-error" role="alert"><span>{startError}</span>{supportedTarget && <ActionButton icon="refresh" onClick={() => setStartRevision(value => value + 1)}>Réessayer</ActionButton>}</div>}
      {starting && <div className="communication-feedback" role="status">Ouverture de la conversation…</div>}
      <div className={"communication-workspace" + (selectedId ? " has-thread" : "")}>
        <aside className="communication-inbox" aria-label="Conversations">
          <header className="communication-inbox-heading">
            <h1>{title}</h1>
            {canStart && <ActionButton icon="edit" className="communication-icon-action communication-new-chat"
              aria-label="Nouveau message" title="Nouveau message" onClick={() => setContactOpen(true)} />}
          </header>
          <form className="communication-search" role="search" onSubmit={event => { event.preventDefault(); changeSearch(search); }}>
            <label className="visually-hidden" htmlFor={searchId}>Rechercher une conversation</label>
            <ActionButton icon="search" className="communication-icon-action" type="submit" aria-label="Rechercher" title="Rechercher" />
            <input ref={searchInput} id={searchId} type="search" placeholder="Rechercher une conversation…" value={search}
              onChange={event => { setSearch(event.target.value); if (!event.target.value && query) changeSearch(""); }} />
          </form>
          <div className="communication-chat-filters" aria-label="Filtrer les conversations" role="group">
            <button type="button" aria-pressed={!unreadOnly} onClick={() => showUnread(false)}>Toutes</button>
            <button type="button" aria-pressed={unreadOnly} onClick={() => showUnread(true)}>Non lues</button>
          </div>
          <div className="communication-conversation-list" aria-busy={list.loading}>
            {list.error && <ListState role="alert" icon="alert" title={list.error}
              action={<ActionButton icon="refresh" onClick={refreshList}>Réessayer</ActionButton>} />}
            {list.rows.length > 0 ? <ul>{list.rows.map(row => {
              const id = String(row.IdDiscussion);
              const unread = Number(row.unreadCount) || 0;
              const mine = row.lastMessage?.author?.IdUser != null
                && String(row.lastMessage.author.IdUser) === String(list.meta?.currentUserId);
              return <li key={id}>
                <button type="button" className={"communication-conversation" + (unread ? " is-unread" : "")} aria-current={selectedId === id ? "true" : undefined}
                  onClick={() => select(row)}>
                  <ConversationAvatar row={row} />
                  <span className="communication-conversation-copy">
                    <span><strong>{conversationName(row)}</strong><time dateTime={row.DernierMessageAt || row.DateCreation || undefined}>{communicationTime(row.DernierMessageAt || row.DateCreation, true)}</time></span>
                    <span>
                      <small>{mine ? "Vous : " : ""}{row.lastMessage?.TextChat || "Aucun message"}</small>
                      {unread > 0 && <span className="communication-chat-unread">
                        <span aria-hidden="true">{unread > 99 ? "99+" : unread}</span>
                        <span className="visually-hidden">{unread} message{unread === 1 ? " non lu" : "s non lus"}</span>
                      </span>}
                    </span>
                  </span>
                </button>
              </li>;
            })}</ul> : list.error ? null : <ListState
              role="status" icon="mail" loading={list.loading}
              title={list.loading ? "Chargement des conversations…" : query ? "Aucun résultat" : unreadOnly ? "Aucune conversation non lue" : "Aucune conversation"}
              description={!list.loading && !query && !unreadOnly ? "Les conversations apparaissent ici." : undefined}
              action={query && !list.loading ? <ActionButton icon="reset" onClick={() => changeSearch("")}>Effacer la recherche</ActionButton> : undefined}
            />}
          </div>
          {(skip > 0 || hasNext) && <footer className="communication-inbox-footer">
            <nav aria-label="Pages des conversations">
              <ActionButton icon="chevron-left" className="communication-icon-action" aria-label="Conversations précédentes" title="Conversations précédentes"
                disabled={list.loading || skip === 0} onClick={() => setSkip(value => Math.max(0, value - take))} />
              <span>{Math.floor(skip / take) + 1}</span>
              <ActionButton icon="chevron-right" className="communication-icon-action" aria-label="Conversations suivantes" title="Conversations suivantes"
                disabled={list.loading || !hasNext} onClick={() => setSkip(value => value + take)} />
            </nav>
          </footer>}
        </aside>
        {selectedId ? <ConversationThread key={selectedId} id={selectedId} row={selected} visible={visible}
          canSend={canSend} headingRef={threadHeading} onBack={backToList} onSent={refreshList} onRead={refreshList}
          draft={drafts[selectedId]} onDraftChange={next => changeDraft(selectedId, next)} /> : <div className="communication-thread communication-thread-placeholder">
          <div className="communication-welcome">
            <span className="communication-welcome-icon"><AppIcon name="chat" size={38} /></span>
            <h2>Vos messages</h2>
            <p>Choisissez une conversation pour continuer.</p>
          </div>
        </div>}
      </div>
      {contactOpen && visible && canStart && <ContactPicker onClose={() => setContactOpen(false)}
        onOpened={row => { setContactOpen(false); select(row); setSkip(0); refreshList(); }} />}
    </>
  );
}
