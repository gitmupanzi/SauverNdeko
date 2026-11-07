import { useEffect, useId, useRef, useState } from "react";
import { requestJson } from "../services/api";
import ActionButton from "../components/ActionButton";
import AppIcon from "../components/AppIcon";
import RecordEditorFrame from "../components/RecordEditorFrame";

const MAX_LABEL_LENGTH = 60;
const defaults = () => ({tabLabels:{},hiddenTabs:[],hiddenDashboardBlocks:[]});
const isMap = value => value && typeof value === "object" && !Array.isArray(value);

function snapshot(response, entityId) {
  const data = response?.data;
  if (!response?.success || String(data?.entityId) !== String(entityId) ||
      !isMap(data.tabDefaults) || !isMap(data.dashboardBlockDefaults) ||
      !isMap(data.tabLabels) || !Array.isArray(data.hiddenDashboardBlocks) ||
      (data.hiddenTabs !== undefined && !Array.isArray(data.hiddenTabs)) ||
      !(data.revision === null || typeof data.revision === "string")) return null;
  return data;
}

function presentationValues(values, configuration) {
  const tabLabels = {};
  for (const [key, standard] of Object.entries(configuration.tabDefaults)) {
    const value = values.tabLabels[key]?.trim();
    if (value && value !== standard) tabLabels[key] = value;
  }
  return {
    tabLabels,
    hiddenTabs:Object.keys(configuration.tabDefaults).filter(key => values.hiddenTabs?.includes(key)),
    hiddenDashboardBlocks:Object.keys(configuration.dashboardBlockDefaults)
      .filter(key => values.hiddenDashboardBlocks.includes(key)),
  };
}

function messageText(value) {
  return Array.isArray(value) ? value.map(messageText).filter(Boolean).join(" ")
    : typeof value === "string" ? value : "";
}

function labelErrors(details, configuration) {
  if (!isMap(details)) return {};
  return Object.fromEntries(Object.keys(configuration.tabDefaults).flatMap(key => {
    const message = messageText(details["tabLabels."+key] ?? details.tabLabels?.[key]);
    return message ? [[key,message]] : [];
  }));
}

function ModulePresentationSettings({entityId,entityName,module}) {
  const path = "/api/parametres/"+encodeURIComponent(module.key)+"/presentation";
  const prefix = useId(), editButton = useRef(null), request = useRef(null);
  const [configuration,setConfiguration] = useState(null);
  const [values,setValues] = useState(defaults);
  const [loading,setLoading] = useState(Boolean(entityId));
  const [busy,setBusy] = useState(false);
  const [editing,setEditing] = useState(false);
  const [conflict,setConflict] = useState(false);
  const [confirmReload,setConfirmReload] = useState(false);
  const [error,setError] = useState("");
  const [errors,setErrors] = useState({});
  const [feedback,setFeedback] = useState("");

  async function load() {
    if (!entityId) return;
    request.current?.abort();
    const controller = new AbortController();
    request.current = controller;
    setLoading(true);
    setError("");
    const response = await requestJson(path,{requiresAuth:true,signal:controller.signal});
    if (controller.signal.aborted) return;
    request.current = null;
    setLoading(false);
    const data = snapshot(response,entityId);
    if (!data) {
      setError(response?.success
        ? "Les réglages reçus ne correspondent pas à cette entreprise."
        : response?.message || "La présentation n’a pas pu être chargée.");
      return;
    }
    setConfiguration(data);
    setValues(presentationValues(data,data));
    setErrors({});
    setConflict(false);
    setConfirmReload(false);
    if (data.canManage !== true) setEditing(false);
  }

  useEffect(() => {
    void load();
    return () => request.current?.abort();
  }, [entityId,path]);

  const initial = configuration ? presentationValues(configuration,configuration) : defaults();
  const desired = configuration ? presentationValues(values,configuration) : defaults();
  const changed = JSON.stringify(initial) !== JSON.stringify(desired);
  const customized = Object.values(values.tabLabels).some(value => value !== "") || values.hiddenTabs.length > 0 || values.hiddenDashboardBlocks.length > 0;
  const canManage = configuration?.canManage === true;
  const disabled = loading || busy || confirmReload;
  const labelHint = prefix+"-label-hint";

  function openEditor() {
    setValues(initial);
    setError("");
    setErrors({});
    setFeedback("");
    setEditing(true);
  }

  function closeEditor() {
    if (conflict) void load();
    setEditing(false);
    setConfirmReload(false);
    setConflict(false);
    setError("");
    setErrors({});
    requestAnimationFrame(() => editButton.current?.focus());
  }

  function changeLabel(key, value) {
    setValues(previous => ({...previous,tabLabels:{...previous.tabLabels,[key]:value}}));
    setErrors(previous => ({...previous,[key]:""}));
  }

  function changeTab(key, visible) {
    setValues(previous => ({...previous,hiddenTabs:visible
      ? previous.hiddenTabs.filter(item => item !== key)
      : [...previous.hiddenTabs,key]}));
  }

  function changeBlock(key, visible) {
    setValues(previous => ({...previous,hiddenDashboardBlocks:visible
      ? previous.hiddenDashboardBlocks.filter(item => item !== key)
      : [...previous.hiddenDashboardBlocks,key]}));
  }

  function restoreDefaults() {
    setValues(defaults());
    setErrors({});
    if (!conflict) setError("");
  }

  async function save() {
    if (!canManage || !changed || conflict || disabled || request.current) return;
    const issues = Object.fromEntries(Object.entries(desired.tabLabels)
      .filter(([,label]) => [...label].length > MAX_LABEL_LENGTH)
      .map(([key]) => [key,"Saisissez au maximum 60 caractères."]));
    setErrors(issues);
    if (Object.keys(issues).length) {
      setError("Vérifiez les noms indiqués.");
      return;
    }
    const controller = new AbortController();
    request.current = controller;
    setBusy(true);
    setError("");
    const response = await requestJson(path,{
      requiresAuth:true,method:"PUT",signal:controller.signal,
      body:JSON.stringify({entityId:configuration.entityId,revision:configuration.revision,...desired}),
    });
    if (controller.signal.aborted) return;
    request.current = null;
    setBusy(false);
    const data = snapshot(response,entityId);
    if (!data) {
      const concurrent = response?.error?.code === "VERSION_CONFLICT";
      setConflict(concurrent);
      setErrors(labelErrors(response?.error?.details,configuration));
      setError(concurrent
        ? "Ces réglages ont changé. Rechargez-les avant d’enregistrer."
        : response?.success || response?.status === 0 || response?.status >= 500
          ? "L’enregistrement reste à confirmer. Réessayez ou rechargez les réglages."
          : response?.message || "Les réglages n’ont pas pu être enregistrés.");
      return;
    }
    setConfiguration(data);
    setValues(presentationValues(data,data));
    closeEditor();
    setFeedback("Présentation enregistrée.");
  }

  return <>
    <div className="settings-presentation-module-head">
      <h2>{module.label}</h2>
      {canManage ? <ActionButton ref={editButton} icon="edit" variant="primary" disabled={loading} onClick={openEditor}>Modifier</ActionButton> : null}
    </div>
    {loading && !editing ? <div className="settings-placeholder" role="status">Chargement de la présentation…</div> : null}
    {!editing && error ? <div className="admin-error" role="alert"><span>{error}</span><ActionButton icon="refresh" onClick={load}>Réessayer</ActionButton></div> : null}
    {feedback ? <p className="admin-feedback" role="status"><AppIcon name="check-circle"/>{feedback}</p> : null}
    {configuration ? <div className="settings-content">
      <section className="record-editor-section">
        <h2><AppIcon name="sidebar"/>Onglets du menu</h2>
        <dl className="settings-details settings-presentation-labels">
          {Object.entries(configuration.tabDefaults).map(([key,label]) => <div key={key}>
            <dt>{label}</dt><dd>{initial.tabLabels[key] || label}</dd>
            <span className={"erp-status "+(initial.hiddenTabs.includes(key)?"is-neutral":"is-success")}>
              {initial.hiddenTabs.includes(key)?"Masqué":"Visible"}
            </span>
          </div>)}
        </dl>
      </section>
      <section className="record-editor-section">
        <h2><AppIcon name="dashboard"/>Blocs du tableau de bord</h2>
        <ul className="settings-presentation-blocks">
          {Object.entries(configuration.dashboardBlockDefaults).map(([key,label]) => {
            const hidden = initial.hiddenDashboardBlocks.includes(key);
            return <li key={key}><span>{label}</span><span className={"erp-status "+(hidden?"is-neutral":"is-success")}>{hidden?"Masqué":"Visible"}</span></li>;
          })}
        </ul>
      </section>
    </div> : null}
    {editing && configuration ? <RecordEditorFrame
      title="Modifier la présentation" subtitle={[module.label,entityName].filter(Boolean).join(" · ")} icon="sidebar" className="settings-presentation-editor"
      storageKey="sauverndeko.presentation-editor.width" onClose={closeEditor}
      onSubmit={save} loading={loading} busy={busy} dirty={changed}
      canSubmit={canManage && changed && !conflict && !confirmReload}
      error={error} onReload={error && !confirmReload ? () => setConfirmReload(true) : undefined}
    >
      {confirmReload ? <div className="record-discard" role="alert">
        <span>Recharger les réglages et abandonner les modifications ?</span>
        <div>
          <ActionButton disabled={loading} onClick={() => setConfirmReload(false)}>Continuer</ActionButton>
          <ActionButton icon="refresh" disabled={loading} onClick={() => {setConfirmReload(false);void load();}}>Recharger</ActionButton>
        </div>
      </div> : null}
      <section className="record-editor-section">
        <h3><AppIcon name="sidebar"/>Onglets du menu</h3>
        <p className="record-editor-note" id={labelHint}>Un nom vide reprend le nom d’origine. Maximum 60 caractères. Les liens directs restent accessibles selon vos droits.</p>
        <div className="record-editor-grid">
          {Object.entries(configuration.tabDefaults).map(([key,label]) => <div className="record-field" key={key}>
            <label htmlFor={prefix+"-"+key}>{label}</label>
            <input id={prefix+"-"+key} value={values.tabLabels[key] || ""} placeholder={label}
              maxLength={MAX_LABEL_LENGTH*2} disabled={disabled} aria-invalid={Boolean(errors[key])}
              aria-describedby={labelHint+(errors[key]?" "+prefix+"-error-"+key:"")}
              onChange={event => changeLabel(key,event.target.value)}/>
            <label className="settings-presentation-tab-option">
              <input type="checkbox" checked={!values.hiddenTabs.includes(key)} disabled={disabled}
                aria-label={"Afficher dans le menu · "+label} onChange={event => changeTab(key,event.target.checked)}/>
              Afficher dans le menu
            </label>
            {errors[key] ? <small id={prefix+"-error-"+key} className="record-field-error">{errors[key]}</small> : null}
          </div>)}
        </div>
      </section>
      <section className="record-editor-section">
        <h3 id={prefix+"-blocks"}><AppIcon name="dashboard"/>Blocs du tableau de bord</h3>
        <p className="record-editor-note">Cochez les blocs à afficher.</p>
        <div className="settings-presentation-blocks" role="group" aria-labelledby={prefix+"-blocks"}>
          {Object.entries(configuration.dashboardBlockDefaults).map(([key,label]) => <label key={key} className="settings-presentation-option">
            <input type="checkbox" checked={!values.hiddenDashboardBlocks.includes(key)} disabled={disabled}
              onChange={event => changeBlock(key,event.target.checked)}/>{label}
          </label>)}
        </div>
      </section>
      <ActionButton icon="reset" disabled={disabled || !customized} onClick={restoreDefaults}>Rétablir les valeurs par défaut</ActionButton>
    </RecordEditorFrame> : null}
  </>;
}

export default function PresentationSettings({entityId,entityName,module,loading,error,onRetry}) {
  return <>
    <header className="settings-heading">
      <div><h1>Présentation</h1><p>{entityName||"Personnalisez l’affichage des modules de votre entreprise."}</p></div>
    </header>
    {!entityId ? <section className="settings-placeholder">
      <AppIcon name="building" size={28}/>
      <h2>Choisissez une entreprise</h2>
      <p>Utilisez le sélecteur dans l’en-tête pour consulter sa présentation.</p>
    </section> : loading ? <div className="settings-placeholder" role="status">Chargement des modules…</div>
      : error ? <div className="admin-error" role="alert">
          <span>{error}</span>
          <ActionButton icon="refresh" onClick={onRetry}>Réessayer</ActionButton>
        </div>
      : module ? <ModulePresentationSettings key={module.key} entityId={entityId} entityName={entityName} module={module}/>
        : <section className="settings-placeholder">
          <AppIcon name="sidebar" size={28}/>
          <h2>Aucun module personnalisable</h2>
          <p>Les modules activés pour cette entreprise apparaissent ici lorsqu’ils proposent des réglages de présentation.</p>
        </section>}
  </>;
}
