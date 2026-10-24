import { requestJson } from "./api";
import {
  clearStoredAuth,
  getAccessToken,
  getRefreshToken,
  getStoredAuth,
  setStoredAuth,
} from "./authStorage";

function buildStoredSession(payload, fallbackUser = null) {
  const accessToken = typeof payload?.accessToken === "string" ? payload.accessToken : "";
  const refreshToken = typeof payload?.refreshToken === "string" ? payload.refreshToken : "";
  const user = payload?.user || fallbackUser || null;

  if (!accessToken && !refreshToken) {
    return null;
  }

  return {
    accessToken,
    refreshToken,
    user,
  };
}

export function persistAuthSession(payload, fallbackUser = null) {
  const session = buildStoredSession(payload, fallbackUser);
  return setStoredAuth(session);
}

export async function loginUser(credentials, { signal } = {}) {
  const payload = await requestJson("/SauverNdeko/auth/login", {
    method: "POST",
    body: JSON.stringify(credentials),
    signal,
  });
  if (
    payload?.success &&
    (typeof payload.accessToken !== "string" || !payload.accessToken.trim() ||
      !payload.user || typeof payload.user !== "object" || Array.isArray(payload.user))
  ) {
    return { success: false, error: { code: "INVALID_LOGIN_RESPONSE" } };
  }
  return payload;
}

export async function registerUser(payload) {
  return requestJson("/SauverNdeko/auth/register", {
    method: "POST",
    body: JSON.stringify(payload),
  });
}

export async function fetchCurrentUser(accessToken = getAccessToken()) {
  if (!accessToken) {
    return {
      success: false,
      message: "Aucun token d'acces disponible.",
    };
  }

  return requestJson("/SauverNdeko/auth/me", {
    headers: {
      Authorization: `Bearer ${accessToken}`,
    },
  });
}

export async function updateCurrentUserProfile(profileData) {
  return requestJson("/SauverNdeko/auth/me", {
    method: "PUT",
    requiresAuth: true,
    body: JSON.stringify(profileData),
  });
}

export async function refreshUserSession(refreshToken = getRefreshToken()) {
  if (!refreshToken) {
    return {
      success: false,
      message: "Aucun refresh token disponible.",
    };
  }

  const payload = await requestJson("/SauverNdeko/auth/refresh", {
    method: "POST",
    body: JSON.stringify({
      refreshToken,
    }),
  });

  if (!payload?.success) {
    return payload;
  }

  const stored = getStoredAuth();
  const session = persistAuthSession(payload, stored?.user || null);

  return {
    ...payload,
    session,
  };
}

export async function restoreUserSession() {
  const stored = getStoredAuth();

  if (!stored?.accessToken && !stored?.refreshToken) {
    clearStoredAuth();
    return null;
  }

  let accessToken = stored?.accessToken || "";
  let refreshToken = stored?.refreshToken || "";

  if (accessToken) {
    const verifyPayload = await requestJson("/SauverNdeko/auth/verify", {
      headers: {
        Authorization: `Bearer ${accessToken}`,
      },
    });

    if (!verifyPayload?.success) {
      accessToken = "";
    }
  }

  if (!accessToken) {
    const refreshPayload = await refreshUserSession(refreshToken);

    if (!refreshPayload?.success || !refreshPayload.session) {
      clearStoredAuth();
      return null;
    }

    accessToken = refreshPayload.session.accessToken;
    refreshToken = refreshPayload.session.refreshToken;
  }

  const mePayload = await fetchCurrentUser(accessToken);

  if (!mePayload?.success || !mePayload.data) {
    clearStoredAuth();
    return null;
  }

  const session = setStoredAuth({
    accessToken,
    refreshToken,
    user: mePayload.data,
  });

  return session;
}

export async function logoutUser() {
  const accessToken = getAccessToken();
  let payload = {
    success: true,
  };

  if (accessToken) {
    payload = await requestJson("/SauverNdeko/auth/logout", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
      },
    });
  }

  clearStoredAuth();
  return payload;
}
