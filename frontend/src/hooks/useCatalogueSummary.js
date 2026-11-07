import { useCallback, useEffect, useState } from "react";
import { requestJson } from "../services/api";
import { normalizeCatalogueSummary } from "../services/catalogueSummary";

export const CATALOGUE_SUMMARY_TIMEOUT = 12000;

export default function useCatalogueSummary() {
  const [attempt, setAttempt] = useState(0);
  const [state, setState] = useState({ loading: true, data: null, error: false });
  const retry = useCallback(() => setAttempt(value => value + 1), []);

  useEffect(() => {
    let active = true;
    const controller = new AbortController();
    setState({ loading: true, data: null, error: false });
    const timeout = setTimeout(() => {
      if (!active) return;
      active = false;
      controller.abort();
      setState({ loading: false, data: null, error: true });
    }, CATALOGUE_SUMMARY_TIMEOUT);
    requestJson("/api/public/catalogue/synthese", { signal: controller.signal })
      .then(payload => {
        if (!active) return;
        const data = normalizeCatalogueSummary(payload);
        setState({ loading: false, data, error: !data });
      })
      .catch(() => { if (active) setState({ loading: false, data: null, error: true }); })
      .finally(() => clearTimeout(timeout));
    return () => { active = false; clearTimeout(timeout); controller.abort(); };
  }, [attempt]);

  return { ...state, retry };
}
