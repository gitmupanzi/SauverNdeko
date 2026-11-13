import {useEffect,useId,useRef,useState} from "react";
import ActionButton from "../../components/ActionButton";
import RecordEditorFrame from "../../components/RecordEditorFrame";
import SearchSelect from "../../components/SearchSelect";
import {requestJson} from "../../services/api";
import {referenceBatchId} from "../referentiels/referenceBatch";
import {CAISSE_ROOT,CAISSE_VALIDATION_MODES,caisseResponseUncertain} from "./caisseModel";

const SETTINGS_URL = CAISSE_ROOT + "/parametres-validation";
const MAX_VALIDATORS = 100;

export default function CaisseValidationSettings({onClose,onSaved,companyName}) {
  const prefix = useId();
  const [settings,setSettings] = useState(null);
  const [mode,setMode] = useState("");
  const [ids,setIds] = useState([]);
  const [motif,setMotif] = useState("");
  const [error,setError] = useState("");
  const [loading,setLoading] = useState(true);
  const [busy,setBusy] = useState(false);
  const [uncertain,setUncertain] = useState(false);
  const [retry,setRetry] = useState(0);
  const [stale,setStale] = useState(false);
  const [refreshing,setRefreshing] = useState(false);
  const agentRefresh = useRef(null);
  const attempt = useRef(null);
  const saving = useRef(null);
  useEffect(() => {
    const controller = new AbortController();
    setLoading(true);
    setError("");
    setStale(false);
    requestJson(SETTINGS_URL,{requiresAuth:true,signal:controller.signal}).then(response => {
      if (controller.signal.aborted) return;
      setLoading(false);
      if (!response?.success) {
        setError(response?.message || "Les paramètres de validation sont indisponibles.");
        return;
      }
      setSettings(response.data);
      setMode(response.data.mode);
      setIds(response.data.validatorIds || []);
    });
    return () => controller.abort();
  },[retry]);
  useEffect(() => () => {saving.current?.abort();agentRefresh.current?.abort();},[]);

  const original = new Set(settings?.validatorIds || []);
  const eligible = settings?.eligibleValidators || [];
  const canManage = settings?.canManage === true;
  const frozen = loading || busy || uncertain || stale || !canManage;
  const eligibleById = new Map(eligible.map(person=>[person.id,person]));
  const remaining = eligible.filter(person=>!ids.includes(person.id));
  const invalidSelection = canManage && ids.some(id=>!eligibleById.has(id));
  const agentPickerId = prefix+"-agents";
  const agentHelpId = prefix+"-agents-help";
  const changed = mode !== settings?.mode || ids.length !== original.size || ids.some(id => !original.has(id));
  const canSave = changed || Boolean(settings?.allowLegacyImmediate);
  const needsAgent = mode === "OTHER_AGENT";
  const hasAgent = ids.some(id=>eligibleById.has(id));

  async function refreshAgents() {
    if (agentRefresh.current || saving.current || frozen) return;
    const controller = new AbortController();
    agentRefresh.current = controller;
    setRefreshing(true);
    setError("");
    const response = await requestJson(SETTINGS_URL,{requiresAuth:true,signal:controller.signal});
    if (controller.signal.aborted) return;
    agentRefresh.current = null;
    setRefreshing(false);
    if (!response?.success) {
      setError(response?.message || "Impossible d’actualiser les agents. Réessayez.");
      return;
    }
    if (response.data._version !== settings._version) {
      setStale(true);
      setError("Ces paramètres ont changé. Rechargez la fiche pour afficher les choix enregistrés.");
      return;
    }
    setSettings(response.data);
  }

  async function submit() {
    if (saving.current || agentRefresh.current || !canManage || loading || stale) return;
    if (!attempt.current) {
      if (!canSave || !motif.trim() || invalidSelection || (needsAgent && !hasAgent)) return;
      attempt.current = JSON.stringify({mode,validatorIds:ids,_version:settings._version,
        requestId:referenceBatchId(),motif:motif.trim()});
    }
    const controller = new AbortController();
    saving.current = controller;
    setBusy(true);
    setError("");
    const response = await requestJson(SETTINGS_URL,{requiresAuth:true,method:"PUT",body:attempt.current,signal:controller.signal});
    if (controller.signal.aborted) return;
    saving.current = null;
    setBusy(false);
    if (response?.success) {
      onSaved({message:"Paramètres de validation enregistrés."});
      return;
    }
    if (caisseResponseUncertain(response)) {
      setUncertain(true);
      setError("La confirmation est indisponible. Réessayez pour vérifier cet enregistrement.");
      return;
    }
    attempt.current = null;
    setUncertain(false);
    const details = response?.error?.details;
    const conflict = response?.error?.code === "STALE_REVISION";
    setStale(conflict);
    setError(conflict
      ? "Ces paramètres ont changé. Rechargez la fiche pour afficher les choix enregistrés."
      : details?.mode || details?.validatorIds || details?.motif || response?.message || "Les paramètres n’ont pas pu être enregistrés.");
  }
  function addAgent(value) {
    const id = Number(value);
    if (frozen || agentRefresh.current || !eligibleById.has(id)) return;
    setIds(previous=>previous.includes(id)||previous.length>=MAX_VALIDATORS ? previous : [...previous,id]);
  }

  function removeAgent(id) {
    setIds(previous=>previous.filter(value=>value!==id));
    requestAnimationFrame(()=>{
      const picker = document.getElementById(agentPickerId);
      (picker&&!picker.disabled?picker:document.getElementById(prefix+"-agents-heading"))?.focus();
    });
  }

  return <RecordEditorFrame title="Validation des écritures" subtitle={companyName} icon="settings"
    loading={loading} busy={busy} error={error} readOnly={Boolean(settings)&&!canManage}
    canSubmit={Boolean(settings)&&!stale&&!refreshing&&(uncertain||(canSave&&Boolean(motif.trim())&&!invalidSelection&&(!needsAgent||hasAgent)))}
    dirty={uncertain || (Boolean(settings) && (changed || Boolean(motif.trim())))} onClose={onClose} onSubmit={submit}
    onReload={(stale||!settings)&&!loading?()=>{setMotif("");setRetry(value=>value+1);}:undefined}
    submitLabel={uncertain?"Vérifier l’enregistrement":"Enregistrer"}
    defaultWidth={760} className="caisse-editor" storageKey="sauverndeko.caisse.validation-settings.width">
    {settings?<><section className="record-editor-section caisse-fields">
      <h3>Mode de validation</h3>
      <div className="caisse-field-grid">
        <label className="is-wide"><span>Mode pour les nouvelles écritures</span>
          <SearchSelect label="Mode pour les nouvelles écritures" value={mode} options={CAISSE_VALIDATION_MODES}
            disabled={frozen} onChange={setMode}/>
        </label>
      </div>
      <p className="record-editor-note">Les brouillons déjà saisis conservent leur mode de validation.</p>
      {settings.allowLegacyImmediate?<p className="record-editor-note">La validation immédiate au choix reste disponible jusqu’à l’enregistrement de ces paramètres.</p>:null}
    </section>
    <section className="record-editor-section">
      <h3 id={prefix+"-agents-heading"} tabIndex={-1}>Agents habilités</h3>
      <p className="record-editor-note" id={agentHelpId}>{needsAgent
        ? "Ajoutez au moins un agent. Chacun peut valider seul les écritures dont il n’est pas l’auteur."
        : mode==="AUTO" ? "Ces agents peuvent intervenir sur les brouillons qui exigent une validation désignée." : "En validation manuelle, seuls les agents désignés peuvent valider si vous en choisissez. Sans sélection, tous les agents habilités peuvent valider."}</p>
      {canManage?<div className="caisse-validator-picker">
        <SearchSelect id={agentPickerId} label="Ajouter un agent" value="" describedBy={agentHelpId}
          placeholder="Rechercher un agent…" options={remaining.map(person=>({value:String(person.id),label:person.label}))}
          loading={refreshing} disabled={frozen||!remaining.length||ids.length>=MAX_VALIDATORS} onChange={addAgent}/>
        <ActionButton icon="refresh" disabled={frozen||refreshing} onClick={refreshAgents}>Actualiser les agents</ActionButton>
      </div>:null}
      {canManage&&!eligible.length&&!refreshing?<p className="record-editor-note">Aucun agent admissible. Vérifiez que la licence de l’entreprise inclut Caisse et qu’au moins un compte actif de cette entreprise est habilité à valider.</p>:null}
      {canManage&&eligible.length>0&&!remaining.length&&ids.length<MAX_VALIDATORS?<p className="record-editor-note">Tous les agents admissibles sont déjà sélectionnés.</p>:null}
      {canManage&&ids.length>=MAX_VALIDATORS?<p className="record-editor-note">Limite de {MAX_VALIDATORS} agents atteinte.</p>:null}
      <p className="record-editor-note caisse-validator-count" role="status">{ids.length===0?"Aucun agent sélectionné":ids.length===1?"1 agent sélectionné":ids.length+" agents sélectionnés"}</p>
      {ids.length>0?<ul className="caisse-validator-list" aria-label="Agents sélectionnés">{ids.map(id=>{
        const person = eligibleById.get(id);
        const label = person?.label || "Utilisateur nº "+id;
        return <li key={id}>
          <span>{label}{canManage&&!person?<small>Habilitation à vérifier</small>:null}</span>
          {canManage?<ActionButton icon="close" aria-label={"Retirer "+label} disabled={frozen||refreshing} onClick={()=>removeAgent(id)}/> : null}
        </li>;
      })}</ul>:null}
      {invalidSelection?<p className="record-editor-note">Retirez les agents qui n’ont plus l’habilitation pour enregistrer.</p>:null}
    </section>
    <section className="record-editor-section caisse-fields">
      <h3>Traçabilité</h3>
      <div className="caisse-field-grid"><label className="is-wide" htmlFor={prefix+"-motif"}><span>Motif du changement *</span>
        <textarea id={prefix+"-motif"} rows={3} maxLength={1000} value={motif} disabled={frozen}
          onChange={event=>setMotif(event.target.value)}/>
      </label></div>
    </section></>:null}
  </RecordEditorFrame>;
}
