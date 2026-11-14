import { useEffect, useState } from "react";
import ActionButton from "../../components/ActionButton";
import ListState from "../../components/ListState";
import SearchSelect from "../../components/SearchSelect";
import { requestJson } from "../../services/api";

const PATH = "/api/data-science/perimetre";

export default function ResearchScope({ canManage }) {
  const [rows, setRows] = useState(null);
  const [entity, setEntity] = useState("");
  const [refresh, setRefresh] = useState(0);
  const [loadError, setLoadError] = useState("");
  const [feedback, setFeedback] = useState("");
  const [confirm, setConfirm] = useState(false);
  const [busy, setBusy] = useState(false);
  const selected = rows?.find(row => String(row.id) === entity);
  const enabled = Boolean(selected?.debuteLe);

  useEffect(() => {
    const controller = new AbortController();
    async function load() {
      let result;
      try {
        result = await requestJson(PATH, { requiresAuth: true, signal: controller.signal });
      } catch {
        result = null;
      }
      if (controller.signal.aborted) return;
      const companies = result?.data?.entreprises;
      if (result?.success && Array.isArray(companies)) {
        setRows(companies);
        setLoadError("");
      } else {
        setLoadError("Les entreprises participantes n’ont pas pu être chargées.");
      }
    }
    void load();
    return () => controller.abort();
  }, [refresh]);

  async function save() {
    if (!canManage || !selected || busy) return;
    setBusy(true);
    setFeedback("");
    try {
      const result = await requestJson(PATH, {
        requiresAuth: true, method: "POST",
        body: JSON.stringify({ entityId: selected.id, enabled: !enabled }),
      });
      if (!result?.success) throw new Error();
      setRows(null);
      setConfirm(false);
      setFeedback(enabled ? "Participation arrêtée." : "Participation activée.");
      setRefresh(value => value + 1);
    } catch {
      setFeedback("Le réglage n’a pas pu être enregistré. Réessayez.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <>
      <header className="erp-register-heading data-science-heading">
        <div><h1>Périmètre de l’étude</h1><p>Gérez la participation des entreprises à la collecte de recherche.</p></div>
      </header>
      {feedback && <p role="status">{feedback}</p>}
      {loadError ? <ListState title={loadError} role="alert"
        action={<ActionButton icon="refresh" onClick={() => { setLoadError(""); setRefresh(value => value + 1); }}>Réessayer</ActionButton>} />
        : !rows ? <ListState title="Chargement des entreprises…" loading role="status" />
        : !rows.length ? <ListState title="Aucune entreprise disponible" />
        : <section className="data-science-panel">
          <div className="data-science-panel-header">
            <div><h2>Entreprises</h2><p>Seules les déclarations partagées volontairement pendant la participation entrent dans les analyses.</p></div>
          </div>
          <div className="data-science-controls">
            <label className="data-science-field">
              <span>Entreprise</span>
              <SearchSelect label="Entreprise" value={entity} disabled={busy} onChange={value => {
                setEntity(value); setConfirm(false); setFeedback("");
              }} options={[{ value: "", label: "Choisir une entreprise" }, ...rows.map(row => ({ value: String(row.id), label: row.nom }))]} />
            </label>
            {selected && <div className="data-science-field">
              <span>{enabled ? "Participation active" : "Participation désactivée"}</span>
              {canManage && !confirm && <ActionButton onClick={() => setConfirm(true)} disabled={busy}>
                {enabled ? "Arrêter la participation" : "Activer la participation"}
              </ActionButton>}
            </div>}
          </div>
          {canManage && confirm && selected && <div className="data-science-controls" role="group" aria-label="Confirmer la participation">
            <p>{enabled
              ? "L’arrêt retire les contributions de cette entreprise des prochaines analyses."
              : "La collecte commence à l’activation. Les utilisateurs choisissent ensuite s’ils souhaitent partager leurs déclarations."}</p>
            <ActionButton onClick={() => setConfirm(false)} disabled={busy}>Annuler</ActionButton>
            <ActionButton variant="primary" onClick={save} disabled={busy}>{busy ? "Enregistrement…" : "Confirmer"}</ActionButton>
          </div>}
        </section>}
    </>
  );
}
