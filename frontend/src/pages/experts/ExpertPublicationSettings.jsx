import {useState} from "react";
import RecordEditorFrame from "../../components/RecordEditorFrame";
import {requestJson} from "../../services/api";
import {EXPERT_ROOT} from "./expertModel";

export default function ExpertPublicationSettings({context,onClose,onSaved}) {
  const initial = context?.defaultProfileVisibility === true;
  const [enabled,setEnabled] = useState(initial);
  const [motif,setMotif] = useState("");
  const [busy,setBusy] = useState(false);
  const [error,setError] = useState("");
  const allowed = context?.canManage === true && !context.readOnly;

  async function save() {
    if (busy || !allowed || enabled === initial || !motif.trim()) return;
    setBusy(true);
    setError("");
    try {
      const response = await requestJson(EXPERT_ROOT+"/contexte", {
        method:"PUT",
        requiresAuth:true,
        body:JSON.stringify({enabled,motif:motif.trim()}),
      });
      if (response?.success) onSaved();
      else setError(response?.message || "Le réglage n’a pas pu être enregistré.");
    } catch {
      setError("Le réglage n’a pas pu être enregistré.");
    } finally {
      setBusy(false);
    }
  }

  return <RecordEditorFrame title="Publication dans l’annuaire" icon="globe" onClose={onClose}
    onSubmit={save} canSubmit={allowed && enabled !== initial && Boolean(motif.trim())}
    dirty={enabled !== initial || Boolean(motif)} busy={busy} readOnly={!allowed} error={error}
    defaultWidth={650} className="expert-editor" storageKey="sauverndeko.experts.publication.width">
    <section className="record-editor-section expert-fields">
      <label className="expert-checkbox expert-field-wide">
        <input type="checkbox" checked={enabled} disabled={busy || !allowed}
          onChange={event=>setEnabled(event.target.checked)}/>
        Publier les nouveaux profils par défaut
      </label>
      <p className="record-editor-note expert-field-wide">Ce réglage s’applique aux nouveaux profils de votre entreprise. Vous pouvez ajuster la publication dans chaque formulaire.</p>
      <label className="expert-field-wide">Motif de la modification *
        <textarea rows={3} maxLength={1000} value={motif} disabled={busy || !allowed}
          onChange={event=>setMotif(event.target.value)}/>
      </label>
    </section>
  </RecordEditorFrame>;
}
