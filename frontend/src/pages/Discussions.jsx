import { useEffect, useMemo, useState } from "react";
import { useLocation, useSearchParams } from "react-router-dom";
import { useAuth } from "../contexts/AuthContext";
import {
  fetchDiscussionMessages,
  fetchDiscussions,
  sendMessage,
  startDiscussion,
} from "../services/api";

function formatThreadTime(value) {
  if (!value) {
    return "A l'instant";
  }

  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return "A l'instant";
  }

  return new Intl.DateTimeFormat("fr-FR", {
    day: "2-digit",
    month: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
  }).format(date);
}

function buildRecipientFromExpert(expert) {
  if (!expert) {
    return null;
  }

  return {
    type: "expert",
    id: expert.id,
    firstName: expert.firstName,
    lastName: expert.lastName,
    fullName: expert.fullName,
    photo: expert.photo,
    professionalType: expert.professionalType,
    specialty: expert.specialty,
    structure: expert.structure,
    publicAddress: null,
    publicPhone: null,
  };
}

function buildRecipientFromStructure(pharmacy) {
  if (!pharmacy) {
    return null;
  }

  return {
    type: "structure",
    id: pharmacy.id,
    name: pharmacy.name,
    structureType: pharmacy.type,
    publicAddress: pharmacy.address,
    publicPhone: pharmacy.phone,
  };
}

function buildLocationRecipient(type, id, state) {
  if (!state?.targetName || !type || !id) {
    return null;
  }

  if (type === "expert") {
    return {
      type: "expert",
      id,
      firstName: "",
      lastName: "",
      fullName: state.targetName,
      photo: "/illustration-experts.svg",
      professionalType: "Professionnel de sante",
      specialty: "Specialite a confirmer",
      structure: "Structure a confirmer",
      publicAddress: null,
      publicPhone: null,
    };
  }

  if (type === "structure") {
    return {
      type: "structure",
      id,
      name: state.targetName,
      structureType: "Entreprise",
      publicAddress: null,
      publicPhone: null,
    };
  }

  return null;
}

function upsertDiscussion(currentDiscussions, nextDiscussion) {
  if (!nextDiscussion) {
    return currentDiscussions;
  }

  const withoutCurrent = currentDiscussions.filter(
    (item) => String(item.IdDiscussion) !== String(nextDiscussion.IdDiscussion)
  );

  return [nextDiscussion, ...withoutCurrent];
}

function discussionDisplayName(discussion) {
  if (!discussion?.recipient) {
    return "Discussion";
  }

  return discussion.recipient.type === "expert"
    ? discussion.recipient.fullName || "Expert"
    : discussion.recipient.name || "Structure";
}

function discussionDisplaySubtitle(discussion) {
  if (!discussion?.recipient) {
    return "Conversation";
  }

  return discussion.recipient.type === "expert"
    ? discussion.recipient.specialty || discussion.recipient.professionalType || "Expert"
    : discussion.recipient.structureType || "Structure";
}

function messagePreview(discussion) {
  return discussion?.lastMessage?.TextChat || "Aucun message pour l'instant.";
}

export default function Discussions({ experts = [], pharmacies = [] }) {
  const location = useLocation();
  const [searchParams] = useSearchParams();
  const { user } = useAuth();
  const [draft, setDraft] = useState("");
  const [discussions, setDiscussions] = useState([]);
  const [selectedDiscussionId, setSelectedDiscussionId] = useState(null);
  const [messages, setMessages] = useState([]);
  const [loadingDiscussions, setLoadingDiscussions] = useState(true);
  const [loadingMessages, setLoadingMessages] = useState(false);
  const [sendingMessage, setSendingMessage] = useState(false);
  const [errorMessage, setErrorMessage] = useState("");
  const [currentUserId, setCurrentUserId] = useState(user?.IdUser || null);

  const targetType = searchParams.get("type");
  const targetId = searchParams.get("id");
  const numericTargetId = Number(targetId);
  const canUseDiscussionApiTarget = Number.isInteger(numericTargetId) && numericTargetId > 0;

  const requestedRecipient = useMemo(() => {
    if (targetType === "expert") {
      const expert = experts.find((item) => String(item.id) === String(targetId));
      return buildRecipientFromExpert(expert) || buildLocationRecipient(targetType, targetId, location.state);
    }

    if (targetType === "structure") {
      const pharmacy = pharmacies.find((item) => String(item.id) === String(targetId));
      return buildRecipientFromStructure(pharmacy) || buildLocationRecipient(targetType, targetId, location.state);
    }

    return null;
  }, [experts, location.state, pharmacies, targetId, targetType]);

  const selectedDiscussion = useMemo(
    () => discussions.find((item) => String(item.IdDiscussion) === String(selectedDiscussionId)) || null,
    [discussions, selectedDiscussionId]
  );

  useEffect(() => {
    if (user?.IdUser != null) {
      setCurrentUserId(user.IdUser);
    }
  }, [user?.IdUser]);

  useEffect(() => {
    let active = true;

    async function initializeDiscussions() {
      setLoadingDiscussions(true);
      setErrorMessage("");

      const listPayload = await fetchDiscussions();

      if (!active) {
        return;
      }

      if (!listPayload?.success) {
        setDiscussions([]);
        setSelectedDiscussionId(null);
        setLoadingDiscussions(false);
        setErrorMessage(listPayload?.message || "Impossible de charger les discussions.");
        return;
      }

      let nextDiscussions = Array.isArray(listPayload.data) ? listPayload.data : [];
      let nextSelectedId = nextDiscussions[0]?.IdDiscussion || null;

      if (listPayload.meta?.currentUserId != null) {
        setCurrentUserId(listPayload.meta.currentUserId);
      }

      if (targetType && targetId && canUseDiscussionApiTarget) {
        const startPayload = await startDiscussion(targetType, numericTargetId);

        if (!active) {
          return;
        }

        if (startPayload?.success) {
          nextDiscussions = upsertDiscussion(nextDiscussions, startPayload.data);
          nextSelectedId = startPayload.data?.IdDiscussion || nextSelectedId;
          if (startPayload.meta?.currentUserId != null) {
            setCurrentUserId(startPayload.meta.currentUserId);
          }
        } else {
          setErrorMessage(startPayload?.message || "Impossible d'ouvrir la discussion cible.");
        }
      }

      setDiscussions(nextDiscussions);
      setSelectedDiscussionId(nextSelectedId);
      setLoadingDiscussions(false);
    }

    initializeDiscussions();

    return () => {
      active = false;
    };
  }, [canUseDiscussionApiTarget, numericTargetId, targetId, targetType]);

  useEffect(() => {
    let active = true;

    async function loadMessages() {
      if (!selectedDiscussionId) {
        setMessages([]);
        return;
      }

      setLoadingMessages(true);

      const payload = await fetchDiscussionMessages(selectedDiscussionId);

      if (!active) {
        return;
      }

      if (payload?.success) {
        setMessages(Array.isArray(payload.data) ? payload.data : []);
        if (payload.meta?.currentUserId != null) {
          setCurrentUserId(payload.meta.currentUserId);
        }
      } else {
        setMessages([]);
        setErrorMessage(payload?.message || "Impossible de recuperer les messages.");
      }

      setLoadingMessages(false);
    }

    loadMessages();

    return () => {
      active = false;
    };
  }, [selectedDiscussionId]);

  async function handleSend() {
    const nextMessage = draft.trim();
    if (!nextMessage || !selectedDiscussion) {
      return;
    }

    setSendingMessage(true);
    setErrorMessage("");

    const payload = await sendMessage(selectedDiscussion.IdDiscussion, nextMessage);

    if (payload?.success) {
      const createdMessage = payload.data;

      setMessages((current) => [...current, createdMessage]);
      setDiscussions((current) =>
        current.map((item) =>
          String(item.IdDiscussion) === String(selectedDiscussion.IdDiscussion)
            ? {
                ...item,
                DernierMessageAt: createdMessage.DateChat,
                lastMessage: createdMessage,
              }
            : item
        )
      );
      if (payload.meta?.currentUserId != null) {
        setCurrentUserId(payload.meta.currentUserId);
      }
      setDraft("");
    } else {
      setErrorMessage(payload?.message || "Impossible d'envoyer le message.");
    }

    setSendingMessage(false);
  }

  const fallbackMessage =
    requestedRecipient?.type === "expert"
      ? `La discussion avec ${requestedRecipient.fullName || "cet expert"} sera creee des que l'API la validera.`
      : requestedRecipient?.type === "structure"
        ? `La discussion avec ${requestedRecipient.name || "cette structure"} sera creee des que l'API la validera.`
        : "Selectionnez un expert ou une structure depuis les cartes publiques pour ouvrir une conversation ciblee.";

  return (
    <div className="page-shell">
      <section className="page-hero-card">
        <div>
          <span className="badge rounded-pill text-bg-primary-subtle text-primary-emphasis mb-3">Messagerie</span>
          <h2>Discussions</h2>
          <p>
            Ouvrez ou poursuivez ici une conversation avec un expert ou une structure depuis les
            boutons "Contacter".
          </p>
        </div>
        <span className="status-pill">Donnees reelles</span>
      </section>

      {errorMessage ? <section className="table-empty-state">{errorMessage}</section> : null}

      {loadingDiscussions ? (
        <section className="table-empty-state">Chargement des discussions...</section>
      ) : discussions.length > 0 ? (
        <section className="chat-layout">
          <aside className="chat-sidebar">
            <div className="chat-contact-card">
              <span className="badge rounded-pill text-bg-light text-primary-emphasis">Session connectee</span>
              <h3>Vos discussions</h3>
              <p>Selectionnez une conversation pour afficher l'historique et envoyer un message.</p>
            </div>

            <div className="chat-discussions-list">
              {discussions.map((discussion) => (
                <button
                  key={discussion.IdDiscussion}
                  className={`chat-discussion-item ${
                    String(discussion.IdDiscussion) === String(selectedDiscussionId) ? "is-active" : ""
                  }`}
                  type="button"
                  onClick={() => setSelectedDiscussionId(discussion.IdDiscussion)}
                >
                  <div className="chat-discussion-item-head">
                    <strong>{discussionDisplayName(discussion)}</strong>
                    <small>{formatThreadTime(discussion.DernierMessageAt || discussion.DateCreation)}</small>
                  </div>
                  <span>{discussionDisplaySubtitle(discussion)}</span>
                  <p>{messagePreview(discussion)}</p>
                </button>
              ))}
            </div>
          </aside>

          <section className="chat-thread-card">
            {selectedDiscussion ? (
              <>
                <header className="chat-thread-head">
                  <div>
                    <strong>{discussionDisplayName(selectedDiscussion)}</strong>
                    <p>{discussionDisplaySubtitle(selectedDiscussion)}</p>
                  </div>
                  <span className="status-pill">
                    {selectedDiscussion.TypeDiscussion === "expert"
                      ? "Conversation expert"
                      : "Conversation structure"}
                  </span>
                </header>

                {selectedDiscussion.recipient ? (
                  <section className="chat-thread-meta">
                    <span className="chat-thread-meta-item">
                      {selectedDiscussion.recipient.type === "expert"
                        ? selectedDiscussion.recipient.structure || "Structure a confirmer"
                        : selectedDiscussion.recipient.publicAddress || "Adresse a confirmer"}
                    </span>
                    {selectedDiscussion.recipient.type === "structure" &&
                    selectedDiscussion.recipient.publicPhone ? (
                      <span className="chat-thread-meta-item">
                        {selectedDiscussion.recipient.publicPhone}
                      </span>
                    ) : null}
                  </section>
                ) : null}

                <div className="chat-messages">
                  {loadingMessages ? (
                    <div className="chat-empty-state">Chargement des messages...</div>
                  ) : messages.length > 0 ? (
                    messages.map((message) => {
                      const isCurrentUser =
                        String(message.author?.IdUser || "") === String(currentUserId || "");

                      return (
                        <article
                          key={message.IdChat}
                          className={`chat-message ${isCurrentUser ? "is-user" : "is-system"}`}
                        >
                          <span>{message.TextChat || "Message sans texte."}</span>
                          <small>{formatThreadTime(message.DateChat)}</small>
                        </article>
                      );
                    })
                  ) : (
                    <div className="chat-empty-state">Aucun message pour cette discussion.</div>
                  )}
                </div>

                <div className="chat-composer">
                  <textarea
                    className="chat-textarea"
                    rows="4"
                    value={draft}
                    onChange={(event) => setDraft(event.target.value)}
                    placeholder="Ecrivez votre message ici..."
                    disabled={sendingMessage}
                  />
                  <div className="discussion-actions">
                    <a
                      className="secondary-action text-decoration-none d-inline-flex align-items-center justify-content-center"
                      href="mailto:contact@sauverndeko.cd"
                    >
                      Contact public
                    </a>
                    <button
                      className="primary-action"
                      type="button"
                      onClick={handleSend}
                      disabled={sendingMessage || !draft.trim()}
                    >
                      {sendingMessage ? "Envoi..." : "Envoyer"}
                    </button>
                  </div>
                </div>
              </>
            ) : (
              <div className="chat-empty-state">Selectionnez une discussion.</div>
            )}
          </section>
        </section>
      ) : (
        <section className="discussion-page-card">
          <img src="/illustration-experts.svg" alt="Discussions" />
          <span className="badge rounded-pill text-bg-light text-primary-emphasis px-3 py-2">Discussions</span>
          <h2>Aucune conversation selectionnee</h2>
          <p>{fallbackMessage}</p>
          <div className="discussion-actions">
            <a
              className="primary-action text-decoration-none d-inline-flex align-items-center justify-content-center"
              href="mailto:contact@sauverndeko.cd"
            >
              Contact public
            </a>
            <button className="secondary-action" type="button" disabled>
              En attente de discussion
            </button>
          </div>
        </section>
      )}
    </div>
  );
}
