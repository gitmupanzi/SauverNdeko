import { useEffect, useId, useRef, useState } from "react";
import SearchSelect from "../../components/SearchSelect";
import RecordEditorFrame from "../../components/RecordEditorFrame";
import { startDiscussion } from "../../services/api";
import { getContacts } from "../../services/communication";

export default function ContactPicker({ onClose, onOpened }) {
  const id = useId();
  const [query, setQuery] = useState("");
  const [skip, setSkip] = useState(0);
  const [revision, setRevision] = useState(0);
  const [options, setOptions] = useState([]);
  const [selected, setSelected] = useState(null);
  const [loading, setLoading] = useState(true);
  const [hasMore, setHasMore] = useState(false);
  const [optionsError, setOptionsError] = useState("");
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);
  const lock = useRef(false);
  const mounted = useRef(false);

  useEffect(() => {
    mounted.current = true;
    return () => { mounted.current = false; };
  }, []);
  useEffect(() => {
    const controller = new AbortController();
    setLoading(true);
    setOptionsError("");
    const timer = window.setTimeout(async () => {
      const result = await getContacts(query, skip, controller.signal);
      if (controller.signal.aborted) return;
      setLoading(false);
      if (!result?.success) {
        setOptionsError(result?.message || "Les contacts sont indisponibles.");
        return;
      }
      const contacts = Array.isArray(result.data) ? result.data : [];
      setHasMore(result.meta?.hasNext === true);
      setOptions(previous => {
        const rows = new Map((skip > 0 ? previous : []).map(option => [option.value, option]));
        for (const contact of contacts) {
          rows.set(String(contact.id), { value: String(contact.id), label: contact.fullName || contact.name });
        }
        return [...rows.values()];
      });
    }, skip > 0 ? 0 : 250);
    return () => { window.clearTimeout(timer); controller.abort(); };
  }, [query, skip, revision]);

  function search(value) {
    const next = value.trim();
    if (next === query && skip === 0) return;
    setLoading(true);
    setHasMore(false);
    setQuery(next);
    setSkip(0);
  }

  async function open() {
    if (lock.current) return;
    if (!selected) { setError("Choisissez un destinataire."); return; }
    lock.current = true;
    setBusy(true);
    setError("");
    const result = await startDiscussion("user", Number(selected.value));
    if (!mounted.current) return;
    lock.current = false;
    setBusy(false);
    if (result?.success && result.data?.IdDiscussion) onOpened(result.data);
    else setError(result?.message || "Impossible d’ouvrir cette conversation.");
  }

  const displayed = selected && !options.some(option => option.value === selected.value)
    ? [...options, selected] : options;
  return <RecordEditorFrame title="Nouveau message" icon="mail" onClose={onClose} onSubmit={open}
    busy={busy} error={error} submitLabel="Ouvrir la conversation" defaultWidth={560}
    storageKey="sauverndeko.discussions.contact.width">
    <div className="communication-form">
      <label className="communication-field" htmlFor={id}>
        <span>Destinataire</span>
        <SearchSelect id={id} label="Destinataire" options={displayed} value={selected?.value || ""}
          onChange={value => { setSelected(displayed.find(option => option.value === value)); setError(""); }}
          disabled={busy} invalid={Boolean(error && !selected)} placeholder="Rechercher une personne…"
          remote onSearchChange={search} optionsLoading={loading && skip === 0} optionsError={optionsError}
          hasMore={hasMore} moreLoading={loading && skip > 0} onLoadMore={() => setSkip(options.length)}
          onOptionsRetry={() => setRevision(value => value + 1)} />
      </label>
      <p>Recherchez un membre de votre entreprise par son nom.</p>
    </div>
  </RecordEditorFrame>;
}
