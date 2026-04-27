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
import { getStoredAuth, setStoredAuth } from "../services/authStorage";

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
      const session = await restoreUserSession();

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

  async function login(credentials) {
    const payload = await loginUser(credentials);

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
