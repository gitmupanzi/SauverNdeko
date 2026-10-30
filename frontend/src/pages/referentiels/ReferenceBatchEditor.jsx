import { useEffect, useId, useRef, useState } from "react";
import { useAuth } from "../../contexts/AuthContext";
import { useEntityScope } from "../../contexts/EntityScopeContext";
import RecordEditorFrame from "../../components/RecordEditorFrame";
import ActionButton from "../../components/ActionButton";
import AppIcon from "../../components/AppIcon";
import SearchSelect from "../../components/SearchSelect";
import { SimpleTable } from "../logistique/logistiqueShared";
import { requestJson } from "../../services/api";
import { REFERENCE_BATCH_MAX, REFERENCE_VISIBILITY, referenceBatchRow, referenceBatchFromExcel, referenceBatchPayload, validateReferenceBatch } from "./referenceBatch";
import "./ReferenceEditor.css";
import "./ReferenceBatchEditor.css";

/** Un en-tête et un panier ; la transaction unique est exécutée au serveur. */
export default function ReferenceBatchEditor({ kind = "values", categories = [], initialCategoryId = "", initialScope = "global", canWrite = false, onClose, onSaved }) {
  const { user } = useAuth(), entity = useEntityScope(), prefix = useId();
  const identity = String(user?.IdUser) + ":" + entity.scopeKey, current = useRef(identity), origin = useRef(identity); current.current = identity;
  const [scope, setScope] = useState(user?.Is_Admin === true ? initialScope : "entity"), [categoryId, setCategoryId] = useState(String(initialCategoryId || ""));
  const [rows, setRows] = useState([]), [errors, setErrors] = useState({ rows: {}, header: {} }), [error, setError] = useState("");
  const [busy, setBusy] = useState(false), [uncertain, setUncertain] = useState(false), [pasteOpen, setPasteOpen] = useState(false), [pasteText, setPasteText] = useState(""), [hasHeaders, setHasHeaders] = useState(false), [pasteError, setPasteError] = useState("");
  const [clearAsked, setClearAsked] = useState(false), [detailsId, setDetailsId] = useState(null);
  const pending = useRef(null), saving = useRef(false), alive = useRef(true), detailAnchor = useRef(null);
  const changedContext = origin.current !== identity;
  const readOnly = !canWrite || changedContext || user?.permissions?.canWriteData !== true;
  const disabled = readOnly || busy || uncertain, scopeValue = scope === "entity" ? String(entity.entityId || "") : "";
  const compatibleCategories = categories.filter(item => item.ValideCategorieGenerique !== false && (item.IdEntiteFk == null || scope === "entity" && String(item.IdEntiteFk) === scopeValue));
  const categoryOptions = compatibleCategories.map(item => ({ value: String(item.ID_CategorieGenerique), label: item.ID_CategorieGenerique + " · " + item.NomCategorieGenerique }));
  if (categoryId && !categoryOptions.some(item => item.value === categoryId)) categoryOptions.push({ value: categoryId, label: "Catégorie à vérifier", disabled: true });
  const selectedDetails = rows.find(row => row.clientRowId === detailsId), activeField = kind === "categories" ? "ValideCategorieGenerique" : "ValideGenerique";
  useEffect(() => { alive.current = true; return () => { alive.current = false; }; }, []);
  useEffect(() => { if (detailsId) requestAnimationFrame(() => detailAnchor.current?.scrollIntoView?.({ behavior: "auto", block: "nearest" })); }, [detailsId]);
  function resetErrors() { pending.current = null; setErrors({ rows: {}, header: {} }); setError(""); }
  function edit(clientRowId, field, value) {
    if (disabled) return;
    setRows(previous => previous.map(row => row.clientRowId === clientRowId ? { ...row, [field]: value } : row));
    pending.current = null; setErrors(previous => ({ ...previous, rows: { ...previous.rows, [clientRowId]: { ...previous.rows?.[clientRowId], [field]: "" } } })); setError("");
  }
  function addLine() {
    if (disabled || rows.length >= REFERENCE_BATCH_MAX) return;
    const row = referenceBatchRow(kind); resetErrors(); setRows(previous => [...previous, row]);
    requestAnimationFrame(() => document.getElementById(prefix + row.clientRowId + (kind === "categories" ? "NomCategorieGenerique" : "NomGenerique"))?.focus());
  }
  function removeLine(id) { if (disabled) return; resetErrors(); setRows(previous => previous.filter(row => row.clientRowId !== id)); if (detailsId === id) setDetailsId(null); }
  function clear() { if (disabled) return; setRows([]); setDetailsId(null); setClearAsked(false); setPasteText(""); resetErrors(); }
  function importExcel() {
    if (disabled) return;
    try {
      const imported = referenceBatchFromExcel(kind, pasteText, { hasHeaders });
      if (!imported.length) { setPasteError("Collez au moins une ligne depuis Excel."); return; }
      if (rows.length + imported.length > REFERENCE_BATCH_MAX) { setPasteError("Le panier peut contenir " + REFERENCE_BATCH_MAX + " lignes au maximum."); return; }
      const combined = [...rows, ...imported]; setRows(combined); setErrors(validateReferenceBatch(kind, combined, { categoryId, categories, scope, scopeValue }));
      pending.current = null; setPasteError(""); setPasteText(""); setPasteOpen(false); setError("");
    } catch (failure) { setPasteError(failure.message); }
  }
  function focusErrors(issues) {
    const header = Object.keys(issues.header || {})[0];
    if (header) { requestAnimationFrame(() => document.getElementById(prefix + (header === "scopeValue" ? "scope" : header))?.focus()); return; }
    const id = Object.keys(issues.rows || {})[0], field = Object.keys(issues.rows?.[id] || {})[0];
    if (field?.startsWith("Visible") || field === "ObsGenerique") setDetailsId(id);
    requestAnimationFrame(() => document.getElementById(prefix + id + field)?.focus());
  }
  async function submit() {
    if (readOnly || saving.current) return;
    if (!pending.current) {
      const issues = validateReferenceBatch(kind, rows, { categoryId, categories, scope, scopeValue });
      setErrors(issues); setError("");
      if (Object.keys(issues.header).length || Object.keys(issues.rows).length) { focusErrors(issues); return; }
      pending.current = referenceBatchPayload(kind, rows, { categoryId, scope, scopeValue });
    }
    const expected = identity; saving.current = true; setBusy(true); setError("");
    const response = await requestJson("/api/referentiel/saisie-multiple/" + (kind === "categories" ? "categories" : "valeurs"), { requiresAuth: true, method: "POST", body: JSON.stringify(pending.current) });
    if (!alive.current || current.current !== expected) return;
    saving.current = false; setBusy(false);
    if (!response?.success) {
      const ambiguous = !response?.status || response.status >= 500;
      setUncertain(ambiguous);
      if (ambiguous) { setError("Le lot peut déjà être enregistré. Réessayez pour vérifier le même enregistrement."); return; }
      pending.current = null;
      const details = response?.error?.details;
      if (details && typeof details === "object" && (details.rows || details.header)) {
        const issues = { rows: details.rows || {}, header: details.header || {} }; setErrors(issues); focusErrors(issues); setError("Corrigez les lignes indiquées. Aucune ligne de cette demande n’a été enregistrée.");
      } else setError(response?.message || "Le lot n’a pas pu être enregistré.");
      return;
    }
    pending.current = null; onSaved?.(response.data, { mode: "batch", kind });
  }
  function textCell(row, field, label, { multiline = false, maximum = 255 } = {}) {
    const issue = errors.rows?.[row.clientRowId]?.[field], id = prefix + row.clientRowId + field;
    const properties = { id, value: row[field] ?? "", disabled, maxLength: maximum, "aria-label": "Ligne " + (rows.indexOf(row) + 1) + " · " + label, "aria-invalid": Boolean(issue), "aria-describedby": issue ? id + "-error" : undefined, onChange: event => edit(row.clientRowId, field, event.target.value) };
    return <div className="reference-batch-cell">{multiline ? <textarea {...properties} rows={2}/> : <input {...properties} type="text" autoComplete="off"/>}{issue ? <small id={id + "-error"} role="alert" className="record-field-error">{issue}</small> : null}</div>;
  }
  function booleanCell(row, field, label) {
    const issue = errors.rows?.[row.clientRowId]?.[field], id = prefix + row.clientRowId + field, value = row[field];
    const options = [{ value: "true", label: field === activeField ? "Actif" : "Oui" }, { value: "false", label: field === activeField ? "Inactif" : "Non" }, ...(field.startsWith("Visible") ? [{ value: "null", label: "Non renseigné" }] : [])];
    if (value !== null && typeof value !== "boolean") options.push({ value: String(value), label: "À vérifier : " + String(value), disabled: true });
    return <div className="reference-batch-cell"><SearchSelect id={id} label={"Ligne " + (rows.indexOf(row) + 1) + " · " + label} value={String(value)} options={options} disabled={disabled} invalid={Boolean(issue)} describedBy={issue ? id + "-error" : undefined} onChange={next => edit(row.clientRowId, field, next === "null" ? null : next === "true")}/>{issue ? <small id={id + "-error"} role="alert" className="record-field-error">{issue}</small> : null}</div>;
  }
  const columns = [
    { key: "line", label: "N°", width: 55, sortable: false, render: row => rows.indexOf(row) + 1 },
    ...(kind === "categories" ? [{ key: "NomCategorieGenerique", label: "Catégorie *", width: 285, render: row => textCell(row, "NomCategorieGenerique", "Catégorie") }, { key: "ModuleCategorieGenerique", label: "Modules associés", width: 240, render: row => textCell(row, "ModuleCategorieGenerique", "Modules associés", { maximum: 4000 }) }]
      : [{ key: "NomGenerique", label: "Libellé *", width: 280, render: row => textCell(row, "NomGenerique", "Libellé") }, { key: "AbrGenerique", label: "Abréviation ou code", width: 205, render: row => textCell(row, "AbrGenerique", "Abréviation ou code") }]),
    { key: activeField, label: "État", width: 135, render: row => booleanCell(row, activeField, "État") },
    { key: "actions", label: "Actions", width: 120, sortable: false, render: row => <div className="erp-row-actions">{kind === "values" ? <ActionButton icon="more" className="is-icon" aria-label={"Détails de la ligne " + (rows.indexOf(row) + 1)} onClick={() => setDetailsId(value => value === row.clientRowId ? null : row.clientRowId)} disabled={disabled}/> : null}<ActionButton icon="trash" className="is-icon" aria-label={"Supprimer la ligne " + (rows.indexOf(row) + 1)} disabled={disabled} onClick={() => removeLine(row.clientRowId)}/></div> },
  ];
  const dirty = Boolean(rows.length || pasteText.trim());
  const hasErrors = Object.values(errors.rows || {}).filter(fields => Object.values(fields).some(Boolean)).length;
  return <RecordEditorFrame title={kind === "categories" ? "Ajouter plusieurs catégories" : "Ajouter plusieurs valeurs"} subtitle="Préparez les lignes, puis enregistrez l’ensemble." icon={kind === "categories" ? "folder" : "list"} defaultWidth={1200} className="reference-editor reference-batch-editor" storageKey="sauverndeko.references.batch.width" onClose={onClose} onSubmit={submit} busy={busy} dirty={!readOnly && dirty} readOnly={readOnly} canSubmit={!readOnly} submitLabel={uncertain ? "Vérifier l’enregistrement" : "Enregistrer l’ensemble"} error={changedContext ? "Le contexte de travail a changé. Rouvrez la saisie depuis le registre." : error}>
    {!changedContext ? <>
      <section className="record-editor-section"><h3><AppIcon name="tag"/>{kind === "values" ? "Catégorie et portée" : "Portée des catégories"}</h3><div className="record-editor-grid">
        <div className="record-field"><label htmlFor={prefix + "scope"}>Portée</label><SearchSelect id={prefix + "scope"} label="Portée de la saisie" value={scope} options={[...(user?.Is_Admin === true ? [{ value: "global", label: "Commun à toutes les entreprises" }] : []), { value: "entity", label: entity.entities?.find(item => String(item.id) === String(entity.entityId))?.label || "Entreprise sélectionnée", disabled: !entity.entityId }]} disabled={disabled} invalid={Boolean(errors.header?.scopeValue)} describedBy={errors.header?.scopeValue ? prefix + "scope-error" : undefined} onChange={value => { setScope(value); resetErrors(); }}/>{errors.header?.scopeValue ? <small id={prefix + "scope-error"} role="alert" className="record-field-error">{errors.header.scopeValue}</small> : null}</div>
        {kind === "values" ? <div className="record-field"><label htmlFor={prefix + "categoryId"}>Catégorie *</label><SearchSelect id={prefix + "categoryId"} label="Catégorie des valeurs" value={categoryId} options={categoryOptions} placeholder="Choisir une catégorie…" disabled={disabled} invalid={Boolean(errors.header?.categoryId)} describedBy={errors.header?.categoryId ? prefix + "categoryId-error" : undefined} onChange={value => { setCategoryId(value); resetErrors(); }}/>{errors.header?.categoryId ? <small id={prefix + "categoryId-error"} role="alert" className="record-field-error">{errors.header.categoryId}</small> : null}</div> : null}
      </div></section>
      <section className="record-editor-section reference-batch-basket"><div className="reference-batch-heading"><h3><AppIcon name="list"/>Panier <span className="erp-count-badge">{rows.length}</span></h3><div className="reference-batch-actions"><ActionButton icon="plus" onClick={addLine} disabled={disabled || rows.length >= REFERENCE_BATCH_MAX}>Ajouter une ligne</ActionButton><ActionButton icon="document" onClick={() => setPasteOpen(value => !value)} disabled={disabled}>Coller depuis Excel</ActionButton><ActionButton icon="trash" disabled={disabled || !rows.length} onClick={() => setClearAsked(true)}>Vider le panier</ActionButton></div></div>
        {clearAsked ? <div className="record-editor-error" role="alert"><span>Retirer toutes les lignes du panier ?</span><div className="reference-batch-actions"><ActionButton onClick={() => setClearAsked(false)}>Conserver</ActionButton><ActionButton icon="trash" onClick={clear}>Vider le panier</ActionButton></div></div> : null}
        {pasteOpen ? <div className="reference-batch-paste"><label htmlFor={prefix + "paste"}>Collage Excel</label><p className="record-editor-note">{kind === "categories" ? "Colonnes : Catégorie · Modules associés · État." : "Colonnes : Libellé · Abréviation ou code · Informations · État."}</p><textarea id={prefix + "paste"} value={pasteText} onChange={event => { setPasteText(event.target.value); setPasteError(""); }} rows={5} disabled={disabled} placeholder="Collez vos lignes ici…"/><label className="reference-batch-checkbox"><input type="checkbox" checked={hasHeaders} disabled={disabled} onChange={event => setHasHeaders(event.target.checked)}/>La première ligne contient les en-têtes</label>{pasteError ? <p role="alert" className="record-field-error">{pasteError}</p> : null}<div className="reference-batch-actions"><ActionButton icon="plus" onClick={importExcel} disabled={disabled}>Ajouter au panier</ActionButton><ActionButton onClick={() => setPasteOpen(false)}>Fermer le collage</ActionButton></div></div> : null}
        {errors.header?.rows ? <p role="alert" id={prefix + "rows"} tabIndex={-1} className="record-field-error">{errors.header.rows}</p> : null}{hasErrors ? <p role="alert" className="record-field-error">{hasErrors} ligne(s) à corriger.</p> : null}
        {Object.entries(errors.header || {}).filter(([field]) => !["categoryId", "scopeValue", "rows"].includes(field)).map(([field, message]) => <p key={field} role="alert" className="record-field-error">{message}</p>)}
        {Object.entries(errors.rows || {}).filter(([, fields]) => Object.values(fields).some(Boolean)).length ? <ul className="reference-batch-errors">{Object.entries(errors.rows).filter(([, fields]) => Object.values(fields).some(Boolean)).slice(0, 5).map(([id, fields]) => <li key={id}>Ligne {rows.findIndex(row => row.clientRowId === id) + 1} · {[...new Set(Object.values(fields).filter(Boolean))].join(" ")}</li>)}</ul> : null}
        <SimpleTable rows={rows} columns={columns} getRowId={row => row.clientRowId} showControls={false} defaultRowsPerPage={REFERENCE_BATCH_MAX} defaultPinnedColumns={[]} defaultVisibleColumns={columns.map(column => column.key)} emptyMessage="Ajoutez une ligne ou collez une liste depuis Excel."/>
      </section>
      {selectedDetails ? <section ref={detailAnchor} className="record-editor-section"><div className="reference-batch-heading"><h3><AppIcon name="tag"/>Détails · {selectedDetails.NomGenerique || "Ligne " + (rows.indexOf(selectedDetails) + 1)}</h3><ActionButton icon="close" className="is-icon" aria-label="Fermer les détails de la ligne" onClick={() => setDetailsId(null)}/></div><div className="record-field"><label htmlFor={prefix + selectedDetails.clientRowId + "ObsGenerique"}>Informations complémentaires</label>{textCell(selectedDetails, "ObsGenerique", "Informations complémentaires", { multiline: true, maximum: 20000 })}</div><div className="reference-batch-visibility">{Object.entries(REFERENCE_VISIBILITY).map(([field, label]) => <div className="record-field" key={field}><label htmlFor={prefix + selectedDetails.clientRowId + field}>{label}</label>{booleanCell(selectedDetails, field, label)}</div>)}</div></section> : null}
    </> : null}
  </RecordEditorFrame>;
}
