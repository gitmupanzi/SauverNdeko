import { useCallback, useEffect, useRef, useState } from "react";
import { useAuth } from "../contexts/AuthContext";
import { useEntityScope } from "../contexts/EntityScopeContext";
import { fetchTablePreferences, saveTablePreferences, resetTablePreferences } from "../services/tablePreferences";
import { preferenceIds } from "../utils/tablePreferences";

export default function useTablePreferences(interfaceKey) {
  const { user, isAuthenticated } = useAuth(), scope = useEntityScope();
  const contextKey = String(user?.IdUser || "") + ":" + scope.scopeKey + ":" + String(interfaceKey || "");
  const identity = useRef(contextKey), operation = useRef(null), currentData = useRef(null);
  identity.current = contextKey;
  const [state, setState] = useState({ key: "", data: null, loading: false, busy: false, error: "" });
  const [attempt, setAttempt] = useState(0);
  const current = state.key === contextKey ? state : { data: null, loading: true, busy: false, error: "" };
  currentData.current = current.data;

  useEffect(() => {
    const controller = new AbortController(), expected = contextKey;
    operation.current?.abort(); operation.current = controller;
    setState({ key: expected, data: null, loading: Boolean(interfaceKey && isAuthenticated), busy: false, error: "" });
    if (!interfaceKey || !isAuthenticated) return () => controller.abort();
    fetchTablePreferences(interfaceKey, controller.signal).then(response => {
      if (controller.signal.aborted || identity.current !== expected) return;
      setState({ key: expected, data: response?.success ? response.data : null, loading: false, busy: false,
        error: response?.success ? "" : response?.message || "Les réglages du tableau sont indisponibles." });
    }).finally(() => { if (operation.current === controller) operation.current = null; });
    return () => { controller.abort(); if (operation.current === controller) operation.current = null; };
  }, [contextKey, interfaceKey, isAuthenticated, attempt]);

  const mutate = useCallback(async (usage, columns, reset = false) => {
    const data = currentData.current, expected = identity.current;
    if (!data || !["table", "export"].includes(usage) || operation.current) return null;
    const controller = new AbortController(); operation.current = controller;
    setState(previous => previous.key === expected ? { ...previous, busy: true, error: "" } : previous);
    try {
      const response = await (reset ? resetTablePreferences(interfaceKey, usage, data[usage]?.version, controller.signal)
        : saveTablePreferences(interfaceKey, usage, preferenceIds(data.columns, columns, usage), data[usage]?.version, controller.signal));
      if (controller.signal.aborted || identity.current !== expected) return null;
      if (!response?.success) {
        setState(previous => previous.key === expected ? { ...previous, busy: false, error: response?.message || "Les réglages n’ont pas été enregistrés." } : previous);
        return null;
      }
      currentData.current = response.data;
      setState({ key: expected, data: response.data, busy: false, loading: false, error: "" });
      return response.data;
    } finally { if (operation.current === controller) operation.current = null; }
  }, [interfaceKey]);

  return {
    interfaceKey, contextKey, data: current.data, catalogue: current.data?.columns || [],
    tableKeys: preferenceIds(current.data?.columns, current.data?.table?.columns),
    exportKeys: preferenceIds(current.data?.columns, current.data?.export?.columns, "export"),
    loading: current.loading, busy: current.busy, error: current.error,
    ready: Boolean(current.data), canExport: current.data?.canExport === true,
    retry: () => setAttempt(value => value + 1),
    save: (usage, columns) => mutate(usage, columns), reset: usage => mutate(usage, null, true),
  };
}
