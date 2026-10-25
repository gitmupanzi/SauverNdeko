import { useLocation } from "react-router-dom";
import { moduleForPath, moduleRights } from "../services/moduleAccess";
import { createContext, startTransition, useContext, useEffect, useRef, useState } from "react";
import {
  captureAuthSessionContext,
  isAuthSessionContextCurrent,
  invalidateAuthSessionContext,
  fetchCurrentUser,
  loginUser,
  registerUser,
  logoutUser,
  persistAuthSession,
  restoreUserSession,
  updateCurrentUserProfile,
} from "../services/auth";
import { AUTH_STORAGE_KEY, AUTH_SESSION_INVALID_EVENT, clearStoredAuth, getStoredAuth, setStoredAuth } from "../services/authStorage";

const AuthContext = createContext(null);

function buildGuestState() {
  return {
    loading: false,
    isAuthenticated: false,
    user: null,
  };
}

function persistSessionUser(user,context) {
  if(!isAuthSessionContextCurrent(context))return false;
  const stored = getStoredAuth();
  setStoredAuth({
    accessToken: stored?.accessToken || "",
    refreshToken: stored?.refreshToken || "",
    user,
  });
  return true;
}

export function AuthProvider({ children }) {
  const location = useLocation();
  const generation=useRef(0);
  const [authState, setAuthState] = useState({
    loading: true,
    isAuthenticated: false,
    user: null,
  });

  const cancelled=()=>({success:false,message:"La session a changé. Recommencez.",error:{code:"AUTH_CONTEXT_CHANGED"}});
  function sessionMatches(session){
    const stored=getStoredAuth();
    return session ? session.accessToken===(stored?.accessToken || "")&&session.refreshToken===(stored?.refreshToken || "") : !stored?.accessToken&&!stored?.refreshToken;
  }
  async function restoreForGeneration(expected,isActive=()=>true){
    const current=()=>isActive()&&generation.current===expected;
    let session=null;
    try{session=await restoreUserSession({isCurrent:current});}catch{
      if(current())startTransition(()=>setAuthState(state=>current()?buildGuestState():state));
      return;
    }
    if(!current()||!sessionMatches(session))return;
    startTransition(()=>setAuthState(state=>current()&&sessionMatches(session)?{loading:false,isAuthenticated:Boolean(session?.accessToken),user:session?.user || null}:state));
  }
  useEffect(()=>{
    let active=true;const expected=generation.current;
    void restoreForGeneration(expected,()=>active);
    return()=>{active=false;};
  },[]);

  useEffect(() => {
    function invalidateSession(event) {
      const accessToken = getStoredAuth()?.accessToken;
      if (!accessToken || event.detail?.accessToken !== accessToken) return;
      endLocalSession();
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
      const context=captureAuthSessionContext(),expected=generation.current;
      const accessToken=context.accessToken;
      if (!accessToken) {
        return;
      }

      refreshing = true;
      try {
        const payload = await fetchCurrentUser(accessToken);
        if (!active || generation.current!==expected || !isAuthSessionContextCurrent(context)) {
          return;
        }
        if (payload?.status === 401) {
          endLocalSession();
          return;
        }
        if (payload?.success && payload.data) {
          if(!persistSessionUser(payload.data,context))return;
          startTransition(() => {
            setAuthState(current=>generation.current===expected&&isAuthSessionContextCurrent(context)?{...current,user:payload.data}:current);
          });
        }
      } finally {
        refreshing = false;
      }
    }

    // Les droits viennent du serveur, y compris pour une session déjà ouverte.
    void synchronizeProfile();
    const timer = window.setInterval(synchronizeProfile, 60000);
    window.addEventListener("sauverndeko:applications-changed", synchronizeProfile);
    window.addEventListener("focus", synchronizeProfile);
    document.addEventListener("visibilitychange", synchronizeProfile);
    return () => {
      active = false;
      window.clearInterval(timer);
      window.removeEventListener("sauverndeko:applications-changed", synchronizeProfile);
      window.removeEventListener("focus", synchronizeProfile);
      document.removeEventListener("visibilitychange", synchronizeProfile);
    };
  }, [authState.isAuthenticated]);

  async function login(credentials, options = {}) {
    const expected=generation.current;
    const payload = await loginUser(credentials, options);
    if(generation.current!==expected)return cancelled();
    if (options.signal?.aborted) return { success: false };

    if (payload?.success) {
      const committed=++generation.current;
      const session = persistAuthSession(payload, payload.user || null);

      startTransition(() => {
        setAuthState(current=>generation.current===committed&&sessionMatches(session)?{loading:false,isAuthenticated:Boolean(session?.accessToken),user:session?.user || null}:current);
      });
    }

    return payload;
  }

  async function register(profileData) {
    const expected=generation.current;
    const payload = await registerUser(profileData);
    if(generation.current!==expected)return cancelled();

    if (payload?.success) {
      const committed=++generation.current;
      const session = persistAuthSession(payload, payload.user || null);

      startTransition(() => {
        setAuthState(current=>generation.current===committed&&sessionMatches(session)?{loading:false,isAuthenticated:Boolean(session?.accessToken),user:session?.user || null}:current);
      });
    }

    return payload;
  }

  function endLocalSession() {
    generation.current+=1;invalidateAuthSessionContext();
    try { clearStoredAuth(); } catch { /* La révocation serveur reste effective si le stockage est indisponible. */ }
    setAuthState(buildGuestState());
  }

  useEffect(()=>{
    let active=true;
    function onSessionChanged(event){
      if(event.key!==AUTH_STORAGE_KEY&&event.key!==null)return;
      const stored=getStoredAuth();
      if(!stored?.accessToken&&!stored?.refreshToken){endLocalSession();return;}
      let before=null;try{before=JSON.parse(event.oldValue || "null");}catch{/* Revalidate an unrecognized external context. */}
      if(before?.accessToken===stored.accessToken&&before?.refreshToken===stored.refreshToken&&before?.user?.IdUser===stored.user?.IdUser&&before?.user?.IdEntiteFk===stored.user?.IdEntiteFk)return;
      const expected=++generation.current;invalidateAuthSessionContext();
      setAuthState({loading:true,isAuthenticated:false,user:null});
      void restoreForGeneration(expected,()=>active);
    }
    window.addEventListener("storage",onSessionChanged);
    return()=>{active=false;window.removeEventListener("storage",onSessionChanged);};
  },[]);

  async function logout(){
    const result=logoutUser();
    endLocalSession();
    return result;
  }

  async function refreshUser() {
    const expected=generation.current,context=captureAuthSessionContext();
    const payload = await fetchCurrentUser(context.accessToken);
    if(generation.current!==expected||!isAuthSessionContextCurrent(context))return cancelled();

    if (payload?.success && payload.data) {
      if(!persistSessionUser(payload.data,context))return cancelled();

      startTransition(() => {
        setAuthState(current=>generation.current===expected&&isAuthSessionContextCurrent(context)?{loading:false,isAuthenticated:true,user:payload.data}:current);
      });
    }

    return payload;
  }

  async function updateProfile(profileData) {
    const expected=generation.current,context=captureAuthSessionContext();
    const payload = await updateCurrentUserProfile(profileData);
    if(generation.current!==expected||!isAuthSessionContextCurrent(context))return cancelled();

    if (payload?.success && payload.data) {
      if(!persistSessionUser(payload.data,context))return cancelled();

      startTransition(() => {
        setAuthState(current=>generation.current===expected&&isAuthSessionContextCurrent(context)?{...current,loading:false,isAuthenticated:true,user:payload.data}:current);
      });
    }

    return payload;
  }

  const key = moduleForPath(location.pathname);
  const rights = key ? moduleRights(authState.user,key) : null;
  const sharedReferences = location.pathname === "/referentiels";
  const user = authState.user ? {
    ...authState.user,
    permissions: {
      ...authState.user.permissions,
      canWriteData: Boolean(authState.user.permissions?.canWriteData && (rights ? rights.canManage : sharedReferences ? authState.user.moduleAccess?.platformAdmin : true)),
      canExportData: rights ? rights.canExport : true,
    },
  } : null;
  return (
    <AuthContext.Provider
      value={{
        ...authState,
        user,
        login,
        register,
        logout,
        endLocalSession,
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
