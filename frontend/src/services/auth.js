import { requestJson } from "./api";
import {
  clearStoredAuth,
  getAccessToken,
  getRefreshToken,
  getStoredAuth,
  setStoredAuth,
} from "./authStorage";

let sessionGeneration=0;
export function invalidateAuthSessionContext(){sessionGeneration+=1;}
export function captureAuthSessionContext(){
  const stored=getStoredAuth();
  return {generation:sessionGeneration,accessToken:stored?.accessToken || "",refreshToken:stored?.refreshToken || ""};
}
export function isAuthSessionContextCurrent(context){
  if(!context||context.generation!==sessionGeneration)return false;
  const stored=getStoredAuth();
  return context.accessToken===(stored?.accessToken || "")&&context.refreshToken===(stored?.refreshToken || "");
}
function changedAuthContext(){return {success:false,message:"La session a changé. Recommencez.",error:{code:"AUTH_CONTEXT_CHANGED"}};}
function clearSession(){invalidateAuthSessionContext();clearStoredAuth();}

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
  invalidateAuthSessionContext();
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

export function fetchPasswordPolicy() {return requestJson("/SauverNdeko/auth/me/password",{requiresAuth:true});}
export function changeCurrentUserPassword(values) {return requestJson("/SauverNdeko/auth/me/password",{method:"POST",requiresAuth:true,body:JSON.stringify(values)});}

export async function updateCurrentUserProfile(profileData) {
  if (profileData instanceof FormData) return requestJson("/SauverNdeko/auth/me/photo", {method:"POST",requiresAuth:true,body:profileData});
  return requestJson("/SauverNdeko/auth/me", {
    method: "PUT",
    requiresAuth: true,
    body: JSON.stringify(profileData),
  });
}

export async function refreshUserSession(refreshToken = getRefreshToken(), {context=captureAuthSessionContext(),isCurrent=()=>true}={}) {
  const current=()=>isCurrent()&&isAuthSessionContextCurrent(context);
  if(!current()||context.refreshToken!==refreshToken)return changedAuthContext();
  if(!refreshToken)return {success:false,message:"Aucun refresh token disponible."};
  const payload=await requestJson("/SauverNdeko/auth/refresh",{method:"POST",body:JSON.stringify({refreshToken})});
  if(!current())return changedAuthContext();
  if(!payload?.success)return payload;
  const session=buildStoredSession(payload,getStoredAuth()?.user || null);
  if(!session)return {success:false,error:{code:"INVALID_REFRESH_RESPONSE"}};
  // A refresh rotates the credentials within this same guarded operation.
  setStoredAuth(session);
  return {...payload,session};
}

export async function restoreUserSession({isCurrent=()=>true}={}) {
  let context=captureAuthSessionContext();
  const current=()=>isCurrent()&&isAuthSessionContextCurrent(context);
  if(!current())return null;
  if(!context.accessToken&&!context.refreshToken){clearSession();return null;}
  let accessToken=context.accessToken,refreshToken=context.refreshToken;
  if(accessToken){
    const verified=await requestJson("/SauverNdeko/auth/verify",{headers:{Authorization:`Bearer ${accessToken}`}});
    if(!current())return null;
    if(!verified?.success)accessToken="";
  }
  if(!accessToken){
    const refreshed=await refreshUserSession(refreshToken,{context,isCurrent});
    if(refreshed?.session)context={...context,accessToken:refreshed.session.accessToken,refreshToken:refreshed.session.refreshToken};
    if(!current())return null;
    if(!refreshed?.success||!refreshed.session){clearSession();return null;}
    accessToken=refreshed.session.accessToken;refreshToken=refreshed.session.refreshToken;
  }
  const me=await fetchCurrentUser(accessToken);
  if(!current())return null;
  if(!me?.success||!me.data){clearSession();return null;}
  return setStoredAuth({accessToken,refreshToken,user:me.data});
}

export async function logoutUser() {
  const accessToken = getAccessToken();
  const refreshToken = getRefreshToken();
  // Fermer localement avant le réseau, sans restaurer une session après déconnexion.
  clearSession();
  const close = (token) => requestJson("/SauverNdeko/auth/logout", {
    method: "POST",
    headers: { Authorization: `Bearer ${token}` },
  });
  if (accessToken) {
    const result = await close(accessToken);
    if (result?.status !== 401 || !refreshToken) return result;
  }
  if (!refreshToken) return { success: true };
  const refreshed = await requestJson("/SauverNdeko/auth/refresh", {
    method: "POST",
    body: JSON.stringify({ refreshToken }),
  });
  return refreshed?.success && refreshed.accessToken ? close(refreshed.accessToken) : refreshed;
}
