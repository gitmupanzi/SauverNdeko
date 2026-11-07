import { Fragment, useEffect, useLayoutEffect, useRef, useState } from "react";
import { Link } from "react-router-dom";
import ActionButton from "../../components/ActionButton";
import AppIcon from "../../components/AppIcon";
import ListState from "../../components/ListState";
import { useAuth } from "../../contexts/AuthContext";
import { fetchDiscussionMessages, sendMessage } from "../../services/api";
import { chatDay, chatHour, communicationTime, markMessagesRead, newMessageRequestId, uncertainDelivery } from "../../services/communication";
import { ConversationAvatar, conversationName, conversationSubtitle } from "./ConversationIdentity";

const pollingInterval = 20000;
const initialState = { rows: [], meta: null, nextBefore: null, loading: true, error: "" };
const emptyDraft = { text: "", ticket: null };

function mergeMessages(existing, incoming) {
  const rows = new Map(existing.map(row => [row.IdChat, row]));
  for (const row of incoming) rows.set(row.IdChat, row);
  return [...rows.values()].sort((left, right) => Date.parse(left.DateChat) - Date.parse(right.DateChat)
    || left.IdChat - right.IdChat);
}

export default function ConversationThread({ id, row, visible, canSend, headingRef, onBack, onSent, onRead, draft = emptyDraft, onDraftChange }) {
  const { user } = useAuth();
  const [state, setState] = useState(initialState);
  const [refresh, setRefresh] = useState(0);
  const [olderBusy, setOlderBusy] = useState(false);

  const [sendError, setSendError] = useState("");
  const mounted = useRef(false);
  const scroll = useRef(null);
  const input = useRef(null);
  const scrollAction = useRef(null);
  const olderController = useRef(null);
  const sendingLock = useRef(false);
  const loadedEarlier = useRef(false);
  const denied = state.meta === null && Boolean(state.error);
  const discussion = denied ? null : state.meta?.discussion || row;
  const canReply = canSend && state.meta?.canSend === true;
  const currentUserId = String(state.meta?.currentUserId ?? user?.IdUser ?? "");
  const { text, ticket, sending = false } = draft;
  const canMarkRead = state.meta?.canMarkRead === true;

  useEffect(() => {
    mounted.current = true;
    return () => {
      mounted.current = false;
      olderController.current?.abort();
    };
  }, []);

  useLayoutEffect(() => {
    const element = scroll.current, action = scrollAction.current;
    if (!element || !action) return;
    scrollAction.current = null;
    if (action.kind === "bottom") element.scrollTop = element.scrollHeight;
    else element.scrollTop = action.top + element.scrollHeight - action.height;
  }, [state.rows]);

  useEffect(() => {
    if (!visible) return;
    const controller = new AbortController();
    let pending = false;
    async function load() {
      if (pending) return;
      pending = true;
      const result = await fetchDiscussionMessages(id, {}, controller.signal);
      pending = false;
      if (controller.signal.aborted) return;
      if (!result?.success) {
        const forbidden = [401, 403, 404].includes(result?.status);
        if (forbidden) {
          olderController.current?.abort();
          olderController.current = null;
          loadedEarlier.current = false;
          setOlderBusy(false);
        }
        setState(previous => ({
          ...(forbidden ? initialState : previous),
          error: result?.message || "Impossible de charger les messages.",
          loading: false,
        }));
        return;
      }
      const element = scroll.current;
      const nearBottom = !element || element.scrollHeight - element.scrollTop - element.clientHeight < 64;
      if (nearBottom && !scrollAction.current) scrollAction.current = { kind: "bottom" };
      setState(previous => ({
        rows: mergeMessages(previous.rows, Array.isArray(result.data) ? result.data : []),
        nextBefore: loadedEarlier.current ? previous.nextBefore : result.meta?.nextBefore,
        meta: result.meta,
        error: "",
        loading: false,
      }));
    }
    load();
    const timer = window.setInterval(() => {
      if (document.visibilityState === "visible") load();
    }, pollingInterval);
    return () => { controller.abort(); window.clearInterval(timer); };
  }, [id, visible, refresh]);

  useEffect(() => {
    const element = scroll.current;
    if (!visible || !canMarkRead || !element || typeof IntersectionObserver === "undefined") return;
    const nodes = element.querySelectorAll("[data-unread-message]");
    if (!nodes.length) return;

    const controller = new AbortController();
    const seen = new Set();
    let timer;
    const observer = new IntersectionObserver(entries => {
      if (document.visibilityState !== "visible") return;
      for (const entry of entries) {
        if (!entry.isIntersecting || entry.intersectionRect.height === 0) continue;
        seen.add(Number(entry.target.dataset.unreadMessage));
        observer.unobserve(entry.target);
      }
      if (!seen.size) return;
      window.clearTimeout(timer);
      timer = window.setTimeout(async () => {
        if (controller.signal.aborted || document.visibilityState !== "visible") return;
        const ids = [...seen].slice(0, 100);
        const result = await markMessagesRead(id, ids, controller.signal);
        if (!result?.success || controller.signal.aborted) return;
        const confirmed = new Set(ids);
        setState(previous => ({
          ...previous,
          rows: previous.rows.map(message => confirmed.has(Number(message.IdChat))
            ? { ...message, unread: false } : message),
        }));
        onRead();
      }, 180);
    }, { root: element, threshold: [0, .15] });

    function observeUnread() {
      observer.disconnect();
      window.clearTimeout(timer);
      seen.clear();
      if (document.visibilityState === "visible") nodes.forEach(node => observer.observe(node));
    }

    observeUnread();
    document.addEventListener("visibilitychange", observeUnread);
    return () => {
      controller.abort();
      observer.disconnect();
      window.clearTimeout(timer);
      document.removeEventListener("visibilitychange", observeUnread);
    };
  }, [id, visible, canMarkRead, state.rows, onRead]);

  async function loadEarlier() {
    if (olderController.current || !state.nextBefore) return;
    const controller = new AbortController();
    olderController.current = controller;
    setOlderBusy(true);
    const result = await fetchDiscussionMessages(id, { before: state.nextBefore }, controller.signal);
    if (olderController.current === controller) olderController.current = null;
    if (controller.signal.aborted) return;
    setOlderBusy(false);
    if (!result?.success) {
      const forbidden = [401, 403, 404].includes(result?.status);
      setState(previous => ({
        ...(forbidden ? initialState : previous),
        error: result?.message || "Impossible de charger les messages précédents.",
        loading: false,
      }));
      return;
    }
    const element = scroll.current;
    if (element) scrollAction.current = { kind: "preserve", top: element.scrollTop, height: element.scrollHeight };
    loadedEarlier.current = true;
    setState(previous => ({
      ...previous,
      rows: mergeMessages(previous.rows, result.data),
      nextBefore: result.meta?.nextBefore,
      error: "",
    }));
  }

  async function send(event) {
    event.preventDefault();
    if (!canReply || !text.trim() || sending || sendingLock.current) return;
    const attempt = ticket || { text: text.trim(), id: newMessageRequestId() };
    sendingLock.current = true;

    setSendError("");
    onDraftChange({ text, ticket: attempt, sending: true });
    const result = await sendMessage(id, attempt.text, attempt.id);
    sendingLock.current = false;
    if (result?.success && result.data?.IdChat) {
      onDraftChange(emptyDraft);
      onSent();
      if (mounted.current) {
        scrollAction.current = { kind: "bottom" };
        setState(previous => ({ ...previous, rows: mergeMessages(previous.rows, [result.data]), error: "" }));
        requestAnimationFrame(() => input.current?.focus({ preventScroll: true }));
      }
      return;
    }
    const uncertain = uncertainDelivery(result) || (Boolean(ticket) && result?.status === 409);
    onDraftChange({ text, ticket: uncertain ? attempt : null });
    if (mounted.current) {
      setSendError(uncertain
        ? "Impossible de confirmer l’envoi. Réessayez pour vérifier le même message."
        : result?.message || "Le message n’a pas pu être envoyé.");
      if ([403, 404].includes(result?.status)) setRefresh(value => value + 1);
    }
  }

  const name = conversationName(discussion);
  return (
    <section className="communication-thread" aria-label="Conversation">
      <header className="communication-thread-heading">
        <ActionButton icon="chevron-left" className="communication-icon-action communication-back"
          aria-label="Revenir aux conversations" title="Revenir aux conversations" onClick={onBack} />
        {discussion && <ConversationAvatar row={discussion} />}
        <div className="communication-thread-identity">
          <h2 tabIndex={-1} ref={headingRef}>{name}</h2>
          {discussion && <p>{conversationSubtitle(discussion)}</p>}
        </div>
        <ActionButton icon="refresh" className="communication-icon-action" onClick={() => setRefresh(value => value + 1)}
          aria-label="Actualiser les messages" title="Actualiser les messages" disabled={state.loading} />
      </header>
      {discussion?.demand && /^[1-9]\d*$/.test(String(discussion.demand.id)) && <div className="communication-demand-context">
        <AppIcon name="document" />
        <span>{discussion.demand.code} · {discussion.demand.subject}</span>
        <Link to={"/discussions?onglet=demandes&demande=" + encodeURIComponent(discussion.demand.id)}>Voir la demande<AppIcon name="chevron-right" size={14} /></Link>
      </div>}
      <div className="communication-thread-scroll" ref={scroll} aria-label="Historique des messages" tabIndex={0}>
        {state.error && <ListState role="alert" icon="alert" title={state.error}
          action={<ActionButton icon="refresh" onClick={() => setRefresh(value => value + 1)}>Réessayer</ActionButton>} />}
        {state.nextBefore && <div className="communication-thread-earlier"><ActionButton icon="chevron-up" disabled={olderBusy} onClick={loadEarlier}>
          {olderBusy ? "Chargement…" : "Messages précédents"}
        </ActionButton></div>}
        {state.loading ? <ListState role="status" loading title="Chargement des messages…" />
          : state.rows.length > 0 ? <ol className="communication-messages" aria-label="Messages de la conversation">
            {state.rows.map((message, index) => {
              const mine = currentUserId && String(message.author?.IdUser) === currentUserId;
              const author = [message.author?.PrenomUser, message.author?.NomUser].filter(Boolean).join(" ");
              const date = chatDay(message.DateChat);
              const previousDate = index > 0 ? chatDay(state.rows[index - 1].DateChat) : "";
              return <Fragment key={message.IdChat}>
                {date && date !== previousDate && <li className="communication-message-day"><span>{date}</span></li>}
                <li className={mine ? "is-own" : undefined} data-unread-message={message.unread ? message.IdChat : undefined}>
                  <article className="communication-bubble">
                    {["structure", "demande"].includes(discussion?.TypeDiscussion) && !mine && <strong>{author || "Participant"}</strong>}
                    <p><span className="visually-hidden">{mine ? "Vous" : author || "Participant"} : </span>
                      {message.TextChat || "Message sans texte"}
                      <time dateTime={message.DateChat} title={communicationTime(message.DateChat)}>{chatHour(message.DateChat)}</time>
                    </p>
                  </article>
                </li>
              </Fragment>;
            })}
          </ol> : !state.error && <ListState role="status" icon="mail" title="Aucun message" description={canReply ? "Écrivez le premier message." : undefined} />}
      </div>
      {canReply && <form className="communication-compose" onSubmit={send}>
        {sendError && <p className="communication-compose-error" role="alert">{sendError}</p>}
        {!sendError && ticket && !sending && <p className="communication-compose-error" role="status">Vérifiez cet envoi avant d’écrire un nouveau message.</p>}
        <label className="visually-hidden" htmlFor={"chat-message-" + id}>Votre message</label>
        <div className="communication-compose-row">
          <textarea ref={input} id={"chat-message-" + id} rows={1} maxLength={10000} value={text}
            readOnly={sending || Boolean(ticket)} placeholder="Écrivez votre message…"
            onKeyDown={event => {
              if (event.key === "Enter" && !event.shiftKey && !event.nativeEvent.isComposing
                && !window.matchMedia("(pointer: coarse)").matches) {
                event.preventDefault();
                event.currentTarget.form.requestSubmit();
              }
            }}
            onChange={event => { onDraftChange({ text: event.target.value, ticket: null }); setSendError(""); }} />
          <ActionButton icon="send" className="communication-icon-action communication-send" variant="primary" type="submit"
            disabled={sending || !text.trim()} aria-label={sending ? "Envoi en cours" : ticket ? "Vérifier l’envoi" : "Envoyer"}
            title={ticket ? "Vérifier l’envoi" : "Envoyer"} />
        </div>
      </form>}
      {!canReply && state.meta && <p className="communication-read-only"><AppIcon name="lock" /> Conversation en lecture seule</p>}
    </section>
  );
}
