const MODELS = new Set(["T_Generique", "T_CategorieGenerique"]);
const CHANNEL = "sauverndeko.references.v1";
const STORAGE_KEY = "sauverndeko.references.changed";
const listeners = new Set();
const seen = new Set();
let channel = null;
let listening = false;
let sequence = 0;

function message(value) {
  if (!value || value.kind !== "references" || typeof value.version !== "string" || value.version.length > 100) return null;
  const models = Array.isArray(value.models) ? value.models.filter(model => MODELS.has(model)) : [];
  return models.length ? { reason: "mutation", models: [...new Set(models)], version: value.version } : null;
}

function deliver(value) {
  const change = message(value);
  if (!change || seen.has(change.version)) return;
  seen.add(change.version);
  if (seen.size > 64) seen.delete(seen.values().next().value);
  for (const listener of listeners) {
    try { listener(change); } catch { /* Une actualisation ne doit pas altérer le résultat du CRUD. */ }
  }
}

function onStorage(event) {
  if (event.key !== STORAGE_KEY || !event.newValue) return;
  try { deliver(JSON.parse(event.newValue)); } catch { /* Ignorer les messages étrangers au contrat. */ }
}

function ensureChannel() {
  if (typeof window === "undefined") return;
  if (!listening) { window.addEventListener("storage", onStorage); listening = true; }
  if (!channel && typeof window.BroadcastChannel === "function") {
    try { channel = new window.BroadcastChannel(CHANNEL); channel.onmessage = event => deliver(event.data); }
    catch { /* Le signal storage reste disponible. */ }
  }
}

export function subscribeReferencesRefresh(listener) {
  if (typeof listener !== "function") return () => {};
  ensureChannel();
  listeners.add(listener);
  return () => { listeners.delete(listener); };
}

export function publishReferencesRefresh(model) {
  if (!MODELS.has(model)) return;
  ensureChannel();
  const change = { kind: "references", models: [model], version: `${Date.now()}-${++sequence}-${Math.random().toString(36).slice(2, 10)}` };
  deliver(change);
  try { channel?.postMessage(change); } catch { /* Repli storage ci-dessous. */ }
  // Seulement une version et des noms de modèles ; aucun contenu, identifiant métier ou secret.
  try { if (typeof window !== "undefined") window.localStorage.setItem(STORAGE_KEY, JSON.stringify(change)); } catch { /* Stockage privé ou indisponible. */ }
}

export function notifyReferencesMutation(path, method, payload) {
  if (payload?.success !== true || !["POST", "PUT", "PATCH", "DELETE"].includes(String(method || "GET").toUpperCase())) return;
  const pathname = String(path || "").split(/[?#]/, 1)[0];
  if (/^\/api\/(?:referentiel\/generiques|models\/T_Generique)(?:\/\d+)?\/?$/.test(pathname)) publishReferencesRefresh("T_Generique");
  else if (/^\/api\/(?:referentiel\/categories-generiques|models\/T_CategorieGenerique)(?:\/\d+)?\/?$/.test(pathname)) publishReferencesRefresh("T_CategorieGenerique");
}

if (import.meta.hot) import.meta.hot.dispose(() => {
  channel?.close(); channel = null;
  if (listening && typeof window !== "undefined") window.removeEventListener("storage", onStorage);
  listening = false; listeners.clear(); seen.clear();
});
