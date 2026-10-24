import { createContext, startTransition, useContext, useEffect, useState } from "react";
import {
  fetchCurrentUser,
  loginUser,
  registerUser,
  logoutUser,
  persistAuthSession,
  restoreUserSession,
  updateCurrentUserProfile,
} from "../services/auth";
import { AUTH_SESSION_INVALID_EVENT, clearStoredAuth, getStoredAuth, setStoredAuth } from "../services/authStorage";

const AuthContext = createContext(null);

function buildGuestState() {
  return {
    loading: false,
    isAuthenticated: false,
    user: null,
  };
}

function persistSessionUser(user) {
  const stored = getStoredAuth();
  setStoredAuth({
    accessToken: stored?.accessToken || "",
    refreshToken: stored?.refreshToken || "",
    user,
  });
}

export function AuthProvider({ children }) {
  const [authState, setAuthState] = useState({
    loading: true,
    isAuthenticated: false,
    user: null,
  });

  useEffect(() => {
    let active = true;

    async function bootstrapSession() {
      let session = null;
      try {
        session = await restoreUserSession();
      } catch {
        // Une restauration indisponible laisse la connexion accessible.
      }

      if (!active) {
        return;
      }

      startTransition(() => {
        setAuthState({
          loading: false,
          isAuthenticated: Boolean(session?.accessToken),
          user: session?.user || null,
        });
      });
    }

    bootstrapSession();

    return () => {
      active = false;
    };
  }, []);

  useEffect(() => {
    function invalidateSession(event) {
      const accessToken = getStoredAuth()?.accessToken;
      if (!accessToken || event.detail?.accessToken !== accessToken) return;
      clearStoredAuth();
      setAuthState(buildGuestState());
    }
    window.addEventListener(AUTH_SESSION_INVALID_EVENT, invalidateSession);
    return () => window.removeEventListener(AUTH_SESSION_INVALID_EVENT, invalidateSession);
  }, []);

  useEffect(() => {
    if (!authState.isAuthenticated) {
      return undefined;
    }

    let active = true;
    let refreshing = false;

    async function synchronizeProfile() {
      if (!active || refreshing || document.visibilityState === "hidden") {
        return;
      }
      const accessToken = getStoredAuth()?.accessToken;
      if (!accessToken) {
        return;
      }

      refreshing = true;
      try {
        const payload = await fetchCurrentUser(accessToken);
        if (!active || getStoredAuth()?.accessToken !== accessToken) {
          return;
        }
        if (payload?.status === 401) {
          clearStoredAuth();
          setAuthState(buildGuestState());
          return;
        }
        if (payload?.success && payload.data) {
          persistSessionUser(payload.data);
          startTransition(() => {
            setAuthState((current) => ({ ...current, user: payload.data }));
          });
        }
      } finally {
        refreshing = false;
      }
    }

    // Les droits viennent du serveur, y compris pour une session déjà ouverte.
    void synchronizeProfile();
    window.addEventListener("focus", synchronizeProfile);
    document.addEventListener("visibilitychange", synchronizeProfile);
    return () => {
      active = false;
      window.removeEventListener("focus", synchronizeProfile);
      document.removeEventListener("visibilitychange", synchronizeProfile);
    };
  }, [authState.isAuthenticated]);

  async function login(credentials, options = {}) {
    const payload = await loginUser(credentials, options);
    if (options.signal?.aborted) return { success: false };

    if (payload?.success) {
      const session = persistAuthSession(payload, payload.user || null);

      startTransition(() => {
        setAuthState({
          loading: false,
          isAuthenticated: Boolean(session?.accessToken),
          user: session?.user || null,
        });
      });
    }

    return payload;
  }

  async function register(profileData) {
    const payload = await registerUser(profileData);

    if (payload?.success) {
      const session = persistAuthSession(payload, payload.user || null);

      startTransition(() => {
        setAuthState({
          loading: false,
          isAuthenticated: Boolean(session?.accessToken),
          user: session?.user || null,
        });
      });
    }

    return payload;
  }

  async function logout() {
    const payload = await logoutUser();

    startTransition(() => {
      setAuthState(buildGuestState());
    });

    return payload;
  }

  async function refreshUser() {
    const payload = await fetchCurrentUser();

    if (payload?.success && payload.data) {
      persistSessionUser(payload.data);

      startTransition(() => {
        setAuthState({
          loading: false,
          isAuthenticated: true,
          user: payload.data,
        });
      });
    }

    return payload;
  }

  async function updateProfile(profileData) {
    const payload = await updateCurrentUserProfile(profileData);

    if (payload?.success && payload.data) {
      persistSessionUser(payload.data);

      startTransition(() => {
        setAuthState((current) => ({
          ...current,
          loading: false,
          isAuthenticated: true,
          user: payload.data,
        }));
      });
    }

    return payload;
  }

  return (
    <AuthContext.Provider
      value={{
        ...authState,
        login,
        register,
        logout,
        refreshUser,
        updateProfile,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const context = useContext(AuthContext);

  if (!context) {
    throw new Error("useAuth doit etre utilise dans un AuthProvider.");
  }

  return context;
}
