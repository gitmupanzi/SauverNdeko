import { getAccessToken } from "./authStorage";

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
  const { requiresAuth = false, ...fetchOptions } = options;
  const accessToken = requiresAuth ? getAccessToken() : "";

  try {
    const response = await fetch(url, {
      ...fetchOptions,
      headers: {
        Accept: "application/json",
        ...(fetchOptions.body ? { "Content-Type": "application/json" } : {}),
        ...(accessToken ? { Authorization: `Bearer ${accessToken}` } : {}),
        ...(fetchOptions.headers || {}),
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

export { API_BASE_URL, requestJson };

function buildQueryString(options = {}) {
  const params = new URLSearchParams();

  Object.entries(options).forEach(([key, value]) => {
    if (value == null || value === "") {
      return;
    }

    params.set(key, String(value));
  });

  const queryString = params.toString();
  return queryString ? `?${queryString}` : "";
}

export function fetchPublicStats() {
  return safeFetchJson("/api/public/stats");
}

export function fetchPublicArticles() {
  return safeFetchJson("/api/public/articles");
}

export function fetchPublicPharmacies(options = {}) {
  return safeFetchJson(`/api/public/pharmacies${buildQueryString(options)}`);
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
    requiresAuth: true,
    body: JSON.stringify({
      type,
      targetId,
    }),
  });
}

export function fetchDiscussions() {
  return requestJson("/api/discussions", {
    requiresAuth: true,
  });
}

export function fetchDiscussionMessages(discussionId) {
  return requestJson(`/api/discussions/${discussionId}/messages`, {
    requiresAuth: true,
  });
}

export function sendMessage(discussionId, message) {
  return requestJson(`/api/discussions/${discussionId}/messages`, {
    method: "POST",
    requiresAuth: true,
    body: JSON.stringify({
      message,
    }),
  });
}

export function fetchAvailableViews() {
  return requestJson("/api/views", {
    requiresAuth: true,
  });
}

export function fetchViewData(schema, view, options = {}) {
  return requestJson(`/api/views/${schema}/${view}${buildQueryString(options)}`, {
    requiresAuth: true,
  });
}

export function fetchAdminEntities(options = {}) {
  return requestJson(`/api/entites${buildQueryString(options)}`, {
    requiresAuth: true,
  });
}

export function createAdminEntity(payload) {
  return requestJson("/api/entites", {
    method: "POST",
    requiresAuth: true,
    body: JSON.stringify(payload),
  });
}

export function fetchAdminEntity(id) {
  return requestJson(`/api/entites/${id}`, {
    requiresAuth: true,
  });
}

export function updateAdminEntity(id, payload) {
  return requestJson(`/api/entites/${id}`, {
    method: "PUT",
    requiresAuth: true,
    body: JSON.stringify(payload),
  });
}

export function deleteAdminEntity(id) {
  return requestJson(`/api/entites/${id}`, {
    method: "DELETE",
    requiresAuth: true,
  });
}

export function fetchAdminLicences(options = {}) {
  return requestJson(`/api/licences${buildQueryString(options)}`, {
    requiresAuth: true,
  });
}

export function fetchAdminLicence(id) {
  return requestJson(`/api/licences/${id}`, {
    requiresAuth: true,
  });
}

export function createAdminLicence(payload) {
  return requestJson("/api/licences", {
    method: "POST",
    requiresAuth: true,
    body: JSON.stringify(payload),
  });
}

export function updateAdminLicence(id, payload) {
  return requestJson(`/api/licences/${id}`, {
    method: "PUT",
    requiresAuth: true,
    body: JSON.stringify(payload),
  });
}

export function deleteAdminLicence(id) {
  return requestJson(`/api/licences/${id}`, {
    method: "DELETE",
    requiresAuth: true,
  });
}

export function fetchAdminUser(id) {
  return requestJson(`/api/utilisateurs/${id}`, {
    requiresAuth: true,
  });
}

export function createAdminUser(payload) {
  return requestJson("/api/utilisateurs", {
    method: "POST",
    requiresAuth: true,
    body: JSON.stringify(payload),
  });
}

export function updateAdminUser(id, payload) {
  return requestJson(`/api/utilisateurs/${id}`, {
    method: "PUT",
    requiresAuth: true,
    body: JSON.stringify(payload),
  });
}

export function deleteAdminUser(id) {
  return requestJson(`/api/utilisateurs/${id}`, {
    method: "DELETE",
    requiresAuth: true,
  });
}

export function fetchAdminModelList(model, options = {}) {
  return requestJson(`/api/models/${model}${buildQueryString(options)}`, {
    requiresAuth: true,
  });
}

export function fetchAdminModelItem(model, id) {
  return requestJson(`/api/models/${model}/${id}`, {
    requiresAuth: true,
  });
}

export function createAdminModelRecord(model, payload) {
  return requestJson(`/api/models/${model}`, {
    method: "POST",
    requiresAuth: true,
    body: JSON.stringify(payload),
  });
}

export function updateAdminModelRecord(model, id, payload) {
  return requestJson(`/api/models/${model}/${id}`, {
    method: "PUT",
    requiresAuth: true,
    body: JSON.stringify(payload),
  });
}

export function deleteAdminModelRecord(model, id) {
  return requestJson(`/api/models/${model}/${id}`, {
    method: "DELETE",
    requiresAuth: true,
  });
}

export function fetchAdminUiSettings(options = {}) {
  return requestJson(`/api/admin-ui-settings${buildQueryString(options)}`, {
    requiresAuth: true,
  });
}

export function saveAdminUiSettings(payload) {
  return requestJson("/api/admin-ui-settings", {
    method: "PUT",
    requiresAuth: true,
    body: JSON.stringify(payload),
  });
}
