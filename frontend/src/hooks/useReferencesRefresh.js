import { useEffect, useRef } from "react";
import { subscribeReferencesRefresh } from "../services/referencesRefresh";

/** Recharge les options en place ; le callback conserve les valeurs et gère son état d’erreur. */
export default function useReferencesRefresh(callback, { enabled = true, revalidateOnFocus = true, delay = 120 } = {}) {
  const latest = useRef(callback);
  latest.current = callback;
  useEffect(() => {
    if (!enabled || typeof window === "undefined" || typeof document === "undefined") return;
    let active = true, timer = null, pending = null, running = false;
    function schedule(change) {
      pending = { ...change, models: [...new Set([...(pending?.models || []), ...(change.models || [])])] };
      if (document.visibilityState === "hidden") return;
      window.clearTimeout(timer);
      timer = window.setTimeout(flush, Math.max(0, delay));
    }
    async function flush() {
      timer = null;
      if (!active || !pending || running || document.visibilityState === "hidden") return;
      const change = pending; pending = null; running = true;
      try { await latest.current?.(change); } catch { /* L’écran conserve ses options et présente son erreur. */ }
      finally { running = false; if (active && pending) schedule(pending); }
    }
    const wake = () => schedule({ reason: "focus", models: [] });
    const visible = () => { if (document.visibilityState !== "hidden" && (revalidateOnFocus || pending)) schedule({ reason: "visible", models: [] }); };
    const restored = event => { if (event.persisted) schedule({ reason: "pageshow", models: [] }); };
    const unsubscribe = subscribeReferencesRefresh(schedule);
    if (revalidateOnFocus) {
      window.addEventListener("focus", wake);
      window.addEventListener("pageshow", restored);
      document.addEventListener("visibilitychange", visible);
    } else document.addEventListener("visibilitychange", visible);
    return () => {
      active = false; pending = null; window.clearTimeout(timer); unsubscribe();
      window.removeEventListener("focus", wake);
      window.removeEventListener("pageshow", restored);
      document.removeEventListener("visibilitychange", visible);
    };
  }, [enabled, revalidateOnFocus, delay]);
}
