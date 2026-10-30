import { useEffect, useId, useRef, useState } from "react";
import RecordEditorFrame from "../../components/RecordEditorFrame";
import SearchSelect from "../../components/SearchSelect";
import ConsultationTabs from "../../components/ConsultationTabs";
import ActionButton from "../../components/ActionButton";
import AppIcon from "../../components/AppIcon";
import { REFERENTIEL_ADMIN_SCHEMA } from "../admin/referentiel";
import { useAuth } from "../../contexts/AuthContext";
import { useEntityScope } from "../../contexts/EntityScopeContext";
import { requestJson } from "../../services/api";
import { referenceBatchRow, referenceBatchPayload } from "./referenceBatch";
import "./ReferenceEditor.css";

const CONFIG_KEYS = {
  categories: "referentiel.V_CategorieGenerique",
  values: "referentiel.V_Generique",
};
const LABELS = {
  NomCategorieGenerique: "Nom de la catégorie",
  ModuleCategorieGenerique: "Modules associés",
  ValideCategorieGenerique: "Catégorie active",
  ID_CategorieGeneriqueFk: "Catégorie",
  NomGenerique: "Libellé",
  AbrGenerique: "Abréviation ou code",
  ObsGenerique: "Informations complémentaires",
  ValideGenerique: "Valeur active",
  VisibleAll: "Visibilité générale",
  VisibleArticle: "Articles",
  VisibleCmd: "Bons de stock",
  VisibleFacture: "Factures",
  VisibleUsers: "Utilisateurs",
  VisibleVoie: "Voies d’accès",
  VisibleNiveau_2: "Niveau territorial 2",
  VisibleNiveau_3: "Niveau territorial 3",
  VisibleNiveau_4: "Niveau territorial 4",
  VisibleNiveau_5: "Niveau territorial 5",
};
const VISIBILITY_GROUPS = [
  { title: "Affichage général", names: ["VisibleAll"] },
  { title: "Usages métier", names: ["VisibleArticle", "VisibleCmd", "VisibleFacture", "VisibleUsers", "VisibleVoie"] },
  { title: "Organisation territoriale", names: ["VisibleNiveau_2", "VisibleNiveau_3", "VisibleNiveau_4", "VisibleNiveau_5"] },
];
const initialValues = fields => Object.fromEntries(fields.map(field => [field.name, field.initialValue ?? (field.type === "checkbox" ? false : "")]));

/** Formulaire commun du référentiel : création, modification et consultation. */
export default function ReferenceEditor({ kind = "values", recordId = null, mode = "create", categories = [], initialCategoryId = "", initialScope = "global", onClose, onSaved, canWrite = false }) {
  const { user } = useAuth(), entity = useEntityScope();
  const prefix = useId();
  const [scope, setScope] = useState(user?.Is_Admin === true ? initialScope : "entity");
  const pendingCreation = useRef(null);
  const creationCategoryId = useRef(String(initialCategoryId || ""));
  const config = REFERENTIEL_ADMIN_SCHEMA.crudConfigs[CONFIG_KEYS[kind]];
  const fields = config?.allFields || config?.fields || [];
  const readOnly = mode === "view" || !canWrite;
  const creating = recordId == null;
  const [values, setValues] = useState(() => initialValues(fields));
  const [initial, setInitial] = useState(null);
  const [record, setRecord] = useState(null);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [errors, setErrors] = useState({});
  const [active, setActive] = useState("identification");
  const [reload, setReload] = useState(0);
  const [confirmReload, setConfirmReload] = useState(false);
  const [uncertain, setUncertain] = useState(false);
  const request = useRef(0);
  const saving = useRef(false);
  const alive = useRef(true);
  const dirty = Boolean(initial) && JSON.stringify(values) !== JSON.stringify(initial);
  const disabled = readOnly || busy || uncertain;

  useEffect(() => { alive.current = true; return () => { alive.current = false; request.current += 1; }; }, []);
  useEffect(() => {
    const token = ++request.current;
    let current = true;
    setLoading(true); setError(""); setErrors({}); setInitial(null); setRecord(null);
    setBusy(false); saving.current = false; setUncertain(false); setConfirmReload(false); setActive("identification");
    if (!config) { setError("Ce référentiel n’est pas disponible."); setLoading(false); return; }
    async function load() {
      const response = creating ? { success: true, data: null } : await config.fetchRecord(null, recordId);
      if (!current || token !== request.current) return;
      setLoading(false);
      if (!response?.success || (!creating && !response.data)) {
        setError(response?.message || "La fiche n’a pas pu être chargée.");
        return;
      }
      const next = creating ? initialValues(fields) : config.mapRecord(response.data);
      if (!creating) for (const field of fields) {
        if (field.type === "checkbox" && response.data[field.name] == null) next[field.name] = null;
      }
      if (creating && kind === "values" && creationCategoryId.current && categories.some(category => String(category.ID_CategorieGenerique) === creationCategoryId.current && category.ValideCategorieGenerique !== false)) next.ID_CategorieGeneriqueFk = creationCategoryId.current;
      setRecord(response.data); setValues(next); setInitial(next);
    }
    load();
    return () => { current = false; };
  }, [kind, recordId, mode, reload]);

  function change(name, value) {
    if (disabled) return;
    setValues(current => ({ ...current, [name]: value }));
    setErrors(current => ({ ...current, [name]: "" }));
    pendingCreation.current = null;
  }
  function focusIssue(issues) {
    const key = Object.keys(issues)[0];
    setActive(key?.startsWith("Visible") ? "visibility" : "identification");
    requestAnimationFrame(() => document.getElementById(prefix + key)?.focus({ preventScroll: false }));
  }
  function validation() {
    const issues = {};
    for (const field of fields) {
      if (field.required && !String(values[field.name] ?? "").trim()) issues[field.name] = field.type === "select" ? "Choisissez une catégorie." : "Renseignez ce champ.";
      if (["NomCategorieGenerique", "NomGenerique", "AbrGenerique"].includes(field.name) && String(values[field.name] ?? "").length > 255) issues[field.name] = "Limitez ce champ à 255 caractères.";
    }
    if (kind === "values" && values.ID_CategorieGeneriqueFk && !/^[1-9]\d*$/.test(values.ID_CategorieGeneriqueFk)) issues.ID_CategorieGeneriqueFk = "Choisissez une catégorie de la liste.";
    if (kind === "values" && values.ID_CategorieGeneriqueFk) {
      const selected = categories.find(category => String(category.ID_CategorieGenerique) === String(values.ID_CategorieGeneriqueFk));
      const originalCategory = !creating ? String(record?.ID_CategorieGeneriqueFk ?? "") : "";
      if (selected?.ValideCategorieGenerique === false && String(values.ID_CategorieGeneriqueFk) !== originalCategory) issues.ID_CategorieGeneriqueFk = "Choisissez une catégorie active.";
      const owner = creating ? scope === "entity" ? entity.entityId : null : record?.IdEntiteFk;
      if (selected?.IdEntiteFk != null && String(selected.IdEntiteFk) !== String(owner ?? "")) issues.ID_CategorieGeneriqueFk = "Cette catégorie appartient à une autre portée.";
    }
    if (creating && scope === "entity" && !entity.entityId) issues.IdEntiteFk = "Choisissez une entreprise dans l’en-tête du module.";
    return issues;
  }
  async function submit() {
    if (!config || readOnly || busy || !initial || saving.current || (!creating && !dirty)) return;
    // Une réponse incertaine se vérifie avec le corps initial, même si le catalogue a changé.
    const issues = creating && pendingCreation.current ? {} : validation(); setErrors(issues); setError("");
    if (Object.keys(issues).length) { focusIssue(issues); return; }
    const token = request.current;
    saving.current = true; setBusy(true);
    const completePayload = config.buildPayload(values, creating ? "create" : "edit");
    const payload = creating ? completePayload : Object.fromEntries(Object.entries(completePayload).filter(([name]) => values[name] !== initial[name]));
    if (creating && !pendingCreation.current) {
      const { ID_CategorieGeneriqueFk, ...detail } = payload;
      pendingCreation.current = referenceBatchPayload(kind, [referenceBatchRow(kind, detail)], { categoryId: ID_CategorieGeneriqueFk, scope, scopeValue: entity.entityId });
    }
    const response = creating ? await requestJson("/api/referentiel/saisie-multiple/" + (kind === "categories" ? "categories" : "valeurs"), { requiresAuth: true, method: "POST", body: JSON.stringify(pendingCreation.current) }) : await config.updateRecord(recordId, payload);
    if (!alive.current || token !== request.current) return;
    saving.current = false; setBusy(false);
    if (!response?.success) {
      if (creating && (!response?.status || response.status >= 500)) {
        setUncertain(true);
        setError("La référence peut déjà être enregistrée. Réessayez pour vérifier le même enregistrement.");
        return;
      }
      setUncertain(false);
      const sourceDetails = response?.error?.details;
      const details = creating ? { ...(sourceDetails?.rows?.[pendingCreation.current?.rows?.[0]?.clientRowId] || {}), ...(sourceDetails?.header?.categoryId ? { ID_CategorieGeneriqueFk: sourceDetails.header.categoryId } : {}), ...(sourceDetails?.header?.scopeValue ? { IdEntiteFk: sourceDetails.header.scopeValue } : {}) } : sourceDetails;
      pendingCreation.current = null;
      const serverIssues = details && typeof details === "object" && !Array.isArray(details)
        ? Object.fromEntries(Object.entries(details).filter(([name]) => fields.some(field => field.name === name)).map(([name, message]) => [name, Array.isArray(message) ? message.join(" ") : String(message)])) : {};
      setErrors(serverIssues);
      setError(Object.keys(serverIssues).length ? "Vérifiez les champs indiqués." : response?.message || "L’enregistrement n’a pas abouti.");
      if (Object.keys(serverIssues).length) focusIssue(serverIssues);
      return;
    }
    setInitial({ ...values });
    onSaved?.(creating ? response.data?.records?.[0] : response.data, { kind, mode: creating ? "create" : "edit" });
  }
  function requestReload() { if (dirty) setConfirmReload(true); else setReload(value => value + 1); }
  function checkbox(field) {
    return <label className="reference-editor-check" key={field.name} htmlFor={prefix + field.name}>
      <span><strong>{LABELS[field.name] || field.label}</strong>{values[field.name] == null ? <small>Non renseigné</small> : field.name === "VisibleAll" ? <small>Conserve la règle d’affichage générale du référentiel.</small> : null}</span>
      <input ref={element => { if (element) element.indeterminate = values[field.name] == null; }} id={prefix + field.name} type="checkbox" checked={Boolean(values[field.name])} disabled={disabled} onChange={event => change(field.name, event.target.checked)} aria-invalid={Boolean(errors[field.name])}/>
    </label>;
  }
  function renderField(field) {
    const name = field.name, id = prefix + name, issue = errors[name];
    if (field.type === "checkbox") return checkbox(field);
    let options = [];
    if (field.type === "select") {
      const originalCategory = !creating ? String(record?.ID_CategorieGeneriqueFk ?? "") : "";
      const owner = creating ? scope === "entity" ? entity.entityId : null : record?.IdEntiteFk;
      options = categories.map(category => ({ value: String(category.ID_CategorieGenerique), label: (category.NomCategorieGenerique || "Catégorie sans libellé") + (category.ValideCategorieGenerique === false ? " · Inactive" : ""), disabled: (category.ValideCategorieGenerique === false || category.IdEntiteFk != null && String(category.IdEntiteFk) !== String(owner ?? "")) && String(category.ID_CategorieGenerique) !== originalCategory }));
      if (values[name] && !options.some(option => option.value === String(values[name]))) options.push({ value: String(values[name]), label: record?.NomCategorieGenerique || "Catégorie actuelle" });
    }
    return <div key={name} className={"record-field" + (field.type === "textarea" || name.startsWith("Nom") ? " is-wide" : "")}>
      <label htmlFor={id}>{LABELS[name] || field.label}{field.required ? " *" : ""}</label>
      {field.type === "select" ? <SearchSelect id={id} label={LABELS[name] || field.label} value={values[name] ?? ""} options={options} placeholder="Choisir une catégorie…" disabled={disabled} invalid={Boolean(issue)} describedBy={issue ? id + "-error" : undefined} onChange={value => change(name, value)}/>
        : field.type === "textarea" ? <textarea id={id} rows={name === "ModuleCategorieGenerique" ? 3 : 4} value={values[name] ?? ""} disabled={disabled} onChange={event => change(name, event.target.value)} aria-invalid={Boolean(issue)} aria-describedby={issue ? id + "-error" : undefined}/>
          : <input id={id} type="text" value={values[name] ?? ""} disabled={disabled} maxLength={255} autoComplete="off" onChange={event => change(name, event.target.value)} aria-invalid={Boolean(issue)} aria-describedby={issue ? id + "-error" : undefined}/>
      }
      {issue ? <small className="record-field-error" id={id + "-error"}>{issue}</small> : null}
    </div>;
  }

  const noun = kind === "categories" ? "la catégorie" : "la valeur";
  const title = readOnly ? kind === "categories" ? "Catégorie du référentiel" : "Valeur du référentiel" : creating ? kind === "categories" ? "Nouvelle catégorie" : "Nouvelle valeur" : "Modifier " + noun;
  const identityFields = fields.filter(field => !field.name.startsWith("Visible"));
  const tabs = [{ key: "identification", label: "Identification", icon: "tag" }, ...(kind === "values" ? [{ key: "visibility", label: "Visibilité", icon: "eye" }] : [])];
  const displayName = record?.NomGenerique || record?.NomCategorieGenerique || "";
  const activeValue = values[kind === "categories" ? "ValideCategorieGenerique" : "ValideGenerique"];
  return <RecordEditorFrame title={title} subtitle={displayName || (kind === "categories" ? "Organisation du référentiel" : "Libellé et usages")} icon={kind === "categories" ? "folder" : "tag"} defaultWidth={800} onClose={onClose} onSubmit={submit} loading={loading} busy={busy} dirty={!readOnly && dirty} readOnly={readOnly} canSubmit={Boolean(config) && Boolean(initial) && (creating || dirty)} submitLabel={uncertain ? "Vérifier l’enregistrement" : "Enregistrer"} error={error} onReload={!uncertain && error ? requestReload : null} className="reference-editor" storageKey="sauverndeko.references.editor.width">
    {confirmReload ? <div className="record-editor-error" role="alert"><span>Recharger la fiche et abandonner les modifications ?</span><div className="reference-editor-inline-actions"><ActionButton onClick={() => setConfirmReload(false)}>Continuer</ActionButton><ActionButton icon="refresh" onClick={() => setReload(value => value + 1)}>Recharger</ActionButton></div></div> : null}
    {!loading && initial ? <>
      {creating ? <section className="record-editor-section"><div className="record-field"><label htmlFor={prefix + "IdEntiteFk"}>Portée</label><SearchSelect id={prefix + "IdEntiteFk"} label="Portée du référentiel" value={scope} options={[...(user?.Is_Admin === true ? [{ value: "global", label: "Commun à toutes les entreprises" }] : []), { value: "entity", label: entity.entities?.find(item => String(item.id) === String(entity.entityId))?.label || "Entreprise sélectionnée", disabled: !entity.entityId }]} disabled={disabled} onChange={next => { setScope(next); pendingCreation.current = null; setErrors({}); }}/>{errors.IdEntiteFk ? <small role="alert" className="record-field-error">{errors.IdEntiteFk}</small> : null}</div></section> : null}
      <div className="reference-editor-context"><span className="reference-editor-context-icon"><AppIcon name={kind === "categories" ? "folder" : "tag"}/></span><div><strong>{values.NomGenerique || values.NomCategorieGenerique || (kind === "categories" ? "Nouvelle catégorie" : "Nouvelle valeur")}</strong><small>{kind === "categories" ? "Catégorie du référentiel" : categories.find(category => String(category.ID_CategorieGenerique) === values.ID_CategorieGeneriqueFk)?.NomCategorieGenerique || "Valeur du référentiel"}</small></div><span className={"erp-status is-" + (activeValue ? "success" : "neutral")}>{activeValue == null ? "Non renseigné" : activeValue ? "Actif" : "Inactif"}</span></div>
      <ConsultationTabs tabs={tabs} value={active} onChange={setActive} label="Rubriques du référentiel" idPrefix={prefix}/>
      {active === "identification" ? <section className="record-editor-section reference-editor-section" role="tabpanel" id={prefix + "-panel-identification"} aria-labelledby={prefix + "-tab-identification"}><h3><AppIcon name="tag"/>Identification</h3><div className="record-editor-grid">{identityFields.map(renderField)}</div></section>
        : <section className="reference-editor-visibility" role="tabpanel" id={prefix + "-panel-visibility"} aria-labelledby={prefix + "-tab-visibility"}>{VISIBILITY_GROUPS.map(group => <section className="record-editor-section reference-editor-section" key={group.title}><h3><AppIcon name="eye"/>{group.title}</h3><div className="reference-editor-check-grid">{group.names.map(name => fields.find(field => field.name === name)).filter(Boolean).map(checkbox)}</div></section>)}</section>}
    </> : null}
  </RecordEditorFrame>;
}
