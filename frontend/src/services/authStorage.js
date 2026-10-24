export const AUTH_SESSION_INVALID_EVENT = "sauverndeko:session-invalid";

const AUTH_STORAGE_KEY = "sauverndeko.auth";

function canUseStorage() {
  return typeof window !== "undefined" && Boolean(window.localStorage);
}

function normalizeStoredAuth(value) {
  if (!value || typeof value !== "object") {
    return null;
  }

  const accessToken = typeof value.accessToken === "string" ? value.accessToken : "";
  const refreshToken = typeof value.refreshToken === "string" ? value.refreshToken : "";
  const user = value.user && typeof value.user === "object" ? value.user : null;

  if (!accessToken && !refreshToken) {
    return null;
  }

  return {
    accessToken,
    refreshToken,
    user,
  };
}

export function getStoredAuth() {
  if (!canUseStorage()) {
    return null;
  }

  try {
    const rawValue = window.localStorage.getItem(AUTH_STORAGE_KEY);
    if (!rawValue) {
      return null;
    }

    return normalizeStoredAuth(JSON.parse(rawValue));
  } catch (error) {
    console.warn("Impossible de lire la session locale.", error);
    return null;
  }
}

export function setStoredAuth(session) {
  const normalized = normalizeStoredAuth(session);

  if (!canUseStorage()) {
    return normalized;
  }

  if (!normalized) {
    window.localStorage.removeItem(AUTH_STORAGE_KEY);
    return null;
  }

  window.localStorage.setItem(AUTH_STORAGE_KEY, JSON.stringify(normalized));
  return normalized;
}

export function clearStoredAuth() {
  if (!canUseStorage()) {
    return;
  }

  window.localStorage.removeItem(AUTH_STORAGE_KEY);
}

export function getAccessToken() {
  return getStoredAuth()?.accessToken || "";
}

export function getRefreshToken() {
  return getStoredAuth()?.refreshToken || "";
}
