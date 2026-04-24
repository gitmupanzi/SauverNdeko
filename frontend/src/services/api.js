const API_BASE_URL = (import.meta.env.VITE_API_BASE_URL || "").replace(/\/$/, "");

async function safeFetchJson(path) {
  const url = `${API_BASE_URL}${path}`;

  try {
    const response = await fetch(url, {
      headers: {
        Accept: "application/json",
      },
    });

    if (!response.ok) {
      return null;
    }

    return await response.json();
  } catch (error) {
    console.warn(`Impossible de recuperer ${path}`, error);
    return null;
  }
}

async function requestJson(path, options = {}) {
  const url = `${API_BASE_URL}${path}`;

  try {
    const response = await fetch(url, {
      ...options,
      headers: {
        Accept: "application/json",
        ...(options.body ? { "Content-Type": "application/json" } : {}),
        ...(options.headers || {}),
      },
    });

    const payload = await response.json().catch(() => null);

    if (!response.ok) {
      return {
        success: false,
        status: response.status,
        message: payload?.message || `Erreur API (${response.status}).`,
        data: payload?.data ?? null,
      };
    }

    return payload;
  } catch (error) {
    console.warn(`Impossible de contacter ${path}`, error);
    return null;
  }
}

export function fetchPublicStats() {
  return safeFetchJson("/api/public/stats");
}

export function fetchPublicArticles() {
  return safeFetchJson("/api/public/articles");
}

export function fetchPublicPharmacies() {
  return safeFetchJson("/api/public/pharmacies");
}

export function fetchPublicExperts() {
  return safeFetchJson("/api/public/experts");
}

export function fetchPublicMaladies() {
  return safeFetchJson("/api/public/maladies");
}

export function fetchPublicChatContext(type, id) {
  const params = new URLSearchParams();
  params.set("type", type);
  params.set("id", String(id));
  return safeFetchJson(`/api/public/chat/context?${params.toString()}`);
}

export function startDiscussion(type, targetId) {
  return requestJson("/api/discussions/start", {
    method: "POST",
    body: JSON.stringify({
      type,
      targetId,
    }),
  });
}

export function fetchDiscussions() {
  return requestJson("/api/discussions");
}

export function fetchDiscussionMessages(discussionId) {
  return requestJson(`/api/discussions/${discussionId}/messages`);
}

export function sendMessage(discussionId, message) {
  return requestJson(`/api/discussions/${discussionId}/messages`, {
    method: "POST",
    body: JSON.stringify({
      message,
    }),
  });
}
