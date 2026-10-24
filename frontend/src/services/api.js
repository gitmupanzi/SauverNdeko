import { AUTH_SESSION_INVALID_EVENT, getAccessToken } from "./authStorage";

const API_BASE_URL = (import.meta.env.VITE_API_BASE_URL || "").replace(/\/$/, "");

async function safeFetchJson(path) {
  const payload = await requestJson(path, { requiresAuth: true });
  return payload?.success ? payload : null;
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
      if (response.status === 401 && accessToken && accessToken === getAccessToken()) {
        window.dispatchEvent(new CustomEvent(AUTH_SESSION_INVALID_EVENT, { detail: { accessToken } }));
      }
      return {
        success: false,
        status: response.status,
        message: payload?.message || `Erreur API (${response.status}).`,
        data: payload?.data ?? null,
        error: payload?.error ?? {
          code: "HTTP_ERROR",
          details: payload?.message || `Erreur API (${response.status}).`,
        },
      };
    }

    return payload;
  } catch (error) {
    console.warn(`Impossible de contacter ${path}`, error);
    return {
      success: false,
      status: 0,
      message: "Impossible de contacter l'API.",
      data: null,
      error: {
        code: "NETWORK_ERROR",
        details: error?.message || "Erreur reseau inconnue.",
      },
    };
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

const ADMIN_MODEL_ROUTE_MAP = Object.freeze({
  T_CategorieGenerique: "/api/referentiel/categories-generiques",
  T_Generique: "/api/referentiel/generiques",
  T_Utilisateurs: "/api/systeme/utilisateurs",
  T_Entite: "/api/systeme/entites",
  T_Entite_Localisation: "/api/systeme/entite-localisations",
  T_Licence: "/api/systeme/licences",
  T_Login: "/api/systeme/logins",
  T_Audit_Log: "/api/systeme/audit-logs",
  T_Fk_Correspondance: "/api/systeme/fk-correspondances",
  T_Admin_UI_Setting: "/api/systeme/admin-ui-settings",
  T_Niveau_0: "/api/geolocalisation/niveau-0",
  T_Niveau_1_Old: "/api/geolocalisation/niveau-1-old",
  T_Niveau_1: "/api/geolocalisation/niveau-1",
  T_Niveau_2: "/api/geolocalisation/niveau-2",
  T_Niveau_3: "/api/geolocalisation/niveau-3",
  T_Niveau_4: "/api/geolocalisation/niveau-4",
  T_Niveau_5: "/api/geolocalisation/niveau-5",
});

function resolveAdminModelBasePath(model) {
  return ADMIN_MODEL_ROUTE_MAP[model] || `/api/models/${model}`;
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
  return requestJson(`/api/systeme/entites${buildQueryString(options)}`, {
    requiresAuth: true,
  });
}

export function createAdminEntity(payload) {
  return requestJson("/api/systeme/entites", {
    method: "POST",
    requiresAuth: true,
    body: JSON.stringify(payload),
  });
}

export function fetchAdminEntity(id) {
  return requestJson(`/api/systeme/entites/${id}`, {
    requiresAuth: true,
  });
}

export function updateAdminEntity(id, payload) {
  return requestJson(`/api/systeme/entites/${id}`, {
    method: "PUT",
    requiresAuth: true,
    body: JSON.stringify(payload),
  });
}

export function deleteAdminEntity(id) {
  return requestJson(`/api/systeme/entites/${id}`, {
    method: "DELETE",
    requiresAuth: true,
  });
}

export function fetchAdminLicences(options = {}) {
  return requestJson(`/api/systeme/licences${buildQueryString(options)}`, {
    requiresAuth: true,
  });
}

export function fetchAdminLicence(id) {
  return requestJson(`/api/systeme/licences/${id}`, {
    requiresAuth: true,
  });
}

export function createAdminLicence(payload) {
  return requestJson("/api/systeme/licences", {
    method: "POST",
    requiresAuth: true,
    body: JSON.stringify(payload),
  });
}

export function updateAdminLicence(id, payload) {
  return requestJson(`/api/systeme/licences/${id}`, {
    method: "PUT",
    requiresAuth: true,
    body: JSON.stringify(payload),
  });
}

export function deleteAdminLicence(id) {
  return requestJson(`/api/systeme/licences/${id}`, {
    method: "DELETE",
    requiresAuth: true,
  });
}

export function fetchAdminUser(id) {
  return requestJson(`/api/systeme/utilisateurs/${id}`, {
    requiresAuth: true,
  });
}

export function createAdminUser(payload) {
  return requestJson("/api/systeme/utilisateurs", {
    method: "POST",
    requiresAuth: true,
    body: JSON.stringify(payload),
  });
}

export function updateAdminUser(id, payload) {
  return requestJson(`/api/systeme/utilisateurs/${id}`, {
    method: "PUT",
    requiresAuth: true,
    body: JSON.stringify(payload),
  });
}

export function deleteAdminUser(id) {
  return requestJson(`/api/systeme/utilisateurs/${id}`, {
    method: "DELETE",
    requiresAuth: true,
  });
}

export function fetchAdminModelList(model, options = {}) {
  return requestJson(`${resolveAdminModelBasePath(model)}${buildQueryString(options)}`, {
    requiresAuth: true,
  });
}

export function fetchAdminModelItem(model, id) {
  return requestJson(`${resolveAdminModelBasePath(model)}/${id}`, {
    requiresAuth: true,
  });
}

export function createAdminModelRecord(model, payload) {
  return requestJson(resolveAdminModelBasePath(model), {
    method: "POST",
    requiresAuth: true,
    body: JSON.stringify(payload),
  });
}

export function updateAdminModelRecord(model, id, payload) {
  return requestJson(`${resolveAdminModelBasePath(model)}/${id}`, {
    method: "PUT",
    requiresAuth: true,
    body: JSON.stringify(payload),
  });
}

export function deleteAdminModelRecord(model, id) {
  return requestJson(`${resolveAdminModelBasePath(model)}/${id}`, {
    method: "DELETE",
    requiresAuth: true,
  });
}

export function fetchAdminUiSettings(options = {}) {
  return requestJson(`/api/systeme/admin-ui-settings${buildQueryString(options)}`, {
    requiresAuth: true,
  });
}

export function fetchAdminUiSettingsAudit(options = {}) {
  return requestJson(`/api/views/systeme/V_Admin_UI_Setting_Audit${buildQueryString(options)}`, {
    requiresAuth: true,
  });
}

export function saveAdminUiSettings(payload) {
  return requestJson("/api/systeme/admin-ui-settings", {
    method: "PUT",
    requiresAuth: true,
    body: JSON.stringify(payload),
  });
}
