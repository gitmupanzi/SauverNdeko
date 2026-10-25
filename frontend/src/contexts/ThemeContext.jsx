import { createContext, useContext, useEffect, useLayoutEffect, useMemo, useState } from "react";

const ThemeContext = createContext(null);
const KEY = "sauverndeko.theme";
const MODES = new Set(["light", "dark", "contrast", "system"]);
function storedMode() {
  try { const value = localStorage.getItem(KEY); return MODES.has(value) ? value : "light"; } catch { return "light"; }
}
function systemDark() { return typeof window.matchMedia === "function" && window.matchMedia("(prefers-color-scheme: dark)").matches; }
export function ThemeProvider({ children }) {
  const [mode, setMode] = useState(storedMode);
  const [darkSystem, setDarkSystem] = useState(systemDark);
  const resolved = mode === "system" ? (darkSystem ? "dark" : "light") : mode;
  useLayoutEffect(() => {
    document.documentElement.dataset.theme = resolved;
    document.documentElement.style.colorScheme = resolved === "light" ? "light" : "dark";
  }, [resolved]);
  useEffect(() => { try { localStorage.setItem(KEY, mode); } catch { /* Préférence facultative. */ } }, [mode]);
  useEffect(() => {
    if (typeof window.matchMedia !== "function") return;
    const media = window.matchMedia("(prefers-color-scheme: dark)");
    const update = () => setDarkSystem(media.matches);
    media.addEventListener("change", update);
    return () => media.removeEventListener("change", update);
  }, []);
  useEffect(() => {
    const update = (event) => { if (event.key === KEY) setMode(MODES.has(event.newValue) ? event.newValue : "light"); };
    window.addEventListener("storage", update);
    return () => window.removeEventListener("storage", update);
  }, []);
  const value = useMemo(() => ({ mode, resolved, setMode: (next) => { if (MODES.has(next)) setMode(next); } }), [mode, resolved]);
  return <ThemeContext.Provider value={value}>{children}</ThemeContext.Provider>;
}
export function useTheme() {
  const value = useContext(ThemeContext);
  if (!value) throw new Error("ThemeProvider manquant.");
  return value;
}
