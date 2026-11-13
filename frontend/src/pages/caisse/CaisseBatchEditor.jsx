import {useEffect, useId, useRef, useState} from "react";
import {useAuth} from "../../contexts/AuthContext";
import {useEntityScope} from "../../contexts/EntityScopeContext";
import {downloadApiFile, requestJson} from "../../services/api";
import ActionButton from "../../components/ActionButton";
import AppIcon from "../../components/AppIcon";
import RecordEditorFrame from "../../components/RecordEditorFrame";
import SearchSelect from "../../components/SearchSelect";
import {formatCurrency} from "../../utils/money";
import {SimpleTable} from "../logistique/logistiqueShared";
import "../logistique/LogisticsBatchComposer.css";
import {CAISSE_REGISTERS, CAISSE_ROOT, caisseAmount, validCaisseDate} from "./caisseModel";
import {
  CAISSE_BATCH_FIELDS, CAISSE_BATCH_LABELS, MAX_CAISSE_BATCH_ROWS, TEXT_LIMITS, caisseBatchChoices,
  caisseBatchErrors, caisseBatchFromMatrix, caisseBatchPaste, caisseBatchPayload, caisseBatchRow, isBatchAmount, isBatchDate,
} from "./caisseBatch";

const PAGE_SIZE = 10;
const EXCEL_MAX_BYTES = 4 * 1024 * 1024;
const DETAILS = ["IdTypePaiementFk", "IdTiersFk", "ReferenceExterne", "ObsPaiement", "motif"];
const WIDTHS = {NomCaisse:220, IdCaisseFk:210, DatePaiement:188, ClotureLe:188, MontantCompte:120,
  MontantPaiement:126, LibellePaiement:200, motif:250, _version:152};
const TITLES = {caisses:"Caisse", ecritures:"Écriture", clotures:"Clôture"};

export default function CaisseBatchEditor({kind, defaults = {}, references, context, onClose, onSaved}) {
  const {user} = useAuth();
  const scope = useEntityScope();
  const prefix = useId();
  const [rows, setRows] = useState(() => [caisseBatchRow(kind, references, defaults)]);
  const [issues, setIssues] = useState({});
  const [error, setError] = useState("");
  const [page, setPage] = useState(1);
  const [detailId, setDetailId] = useState("");
  const [pasteOpen, setPasteOpen] = useState(false);
  const [pasteText, setPasteText] = useState("");
  const [pasteError, setPasteError] = useState("");
  const [clearAsked, setClearAsked] = useState(false);
  const [validate, setValidate] = useState(false);
  const [confirmed, setConfirmed] = useState(false);
  const [busy, setBusy] = useState(false);
  const [uncertain, setUncertain] = useState(false);
  const [excelBusy, setExcelBusy] = useState("");
  const [excelError, setExcelError] = useState("");
  const [excelMessage, setExcelMessage] = useState("");
  const ticket = useRef(null);
  const currentRequest = useRef(null);
  const excelRequest = useRef(null);
  const fileInput = useRef(null);
  const alive = useRef(true);
  const balanceRequests = useRef(new Map());
  const identity = String(user?.IdUser) + ":" + scope.scopeKey;
  const openedScope = useRef(identity);
  const currentScope = useRef(identity);
  currentScope.current = identity;
  const canManageOperation = kind === "ecritures" ? context?.canCreateEntries === true : context?.tabs?.[kind]?.canManage === true;
  const canWrite = Boolean(scope.entityId && canManageOperation && !context?.readOnly &&
    user?.permissions?.canWriteData && openedScope.current === identity);
  const legacyImmediate = kind === "ecritures" && context?.allowLegacyImmediate === true && context?.canValidateEntries === true;
  const currentAccess = useRef(canWrite);
  currentAccess.current = canWrite;
  const importing = excelBusy === "import";
  const frozen = !canWrite || busy || uncertain || importing;
  const needsConfirmation = kind === "clotures" || legacyImmediate && validate;
  const rowsById = new Map(rows.map((row, index) => [row.clientRowId, index]));

  useEffect(() => {
    alive.current = true;
    return () => {
      alive.current = false;
      currentRequest.current?.abort();
      excelRequest.current?.abort();
      for (const request of balanceRequests.current.values()) request.abort();
      balanceRequests.current.clear();
    };
  }, []);
  useEffect(() => {
    if (canWrite) return;
    excelRequest.current?.abort();
    excelRequest.current = null;
    setExcelBusy("");
    setExcelError("");
    setExcelMessage("");
    if (balanceRequests.current.size) {
      for (const request of balanceRequests.current.values()) request.abort();
      balanceRequests.current.clear();
      setRows(previous => previous.map(row => row.balance?.loading
        ? {...row, balance:{error:"Rechargez le solde avant de confirmer la clôture."}} : row));
      setConfirmed(false);
    }
  }, [identity, canWrite]);

  function draftFrozen() {
    return frozen || !alive.current || !currentAccess.current || currentScope.current !== identity ||
      currentRequest.current || excelRequest.current?.operation === "import";
  }

  function changeRow(id, field, value) {
    if (draftFrozen()) return;
    const resetBalance = kind === "clotures" && ["IdCaisseFk","ClotureLe","MontantCompte"].includes(field);
    if (resetBalance) {
      balanceRequests.current.get(id)?.abort();
      balanceRequests.current.delete(id);
    }
    setRows(previous => previous.map(row => row.clientRowId === id ? {
      ...row, pristine:false, values:{...row.values, [field]:value},
      ...(resetBalance ? {balance:null} : {}),
    } : row));
    setIssues(previous => ({...previous, [id]:{...previous[id], [field]:undefined, _line:undefined,
      ...(resetBalance ? {_version:undefined} : {})}}));
    setConfirmed(false);
  }

  function append(next) {
    if (draftFrozen() || next.length > MAX_CAISSE_BATCH_ROWS) return;
    setRows(next);
    setPage(Math.ceil(next.length / PAGE_SIZE));
    setConfirmed(false);
  }

  function remove(id) {
    if (draftFrozen()) return;
    balanceRequests.current.get(id)?.abort();
    balanceRequests.current.delete(id);
    const next = rows.filter(row => row.clientRowId !== id);
    setRows(next.length ? next : [caisseBatchRow(kind, references, defaults)]);
    if (detailId === id) setDetailId("");
    setPage(Math.min(page, Math.ceil(next.length / PAGE_SIZE) || 1));
    setConfirmed(false);
  }

  function clear() {
    if (draftFrozen()) return;
    for (const request of balanceRequests.current.values()) request.abort();
    balanceRequests.current.clear();
    setRows([caisseBatchRow(kind, references, defaults)]);
    setPage(1);
    setIssues({});
    setError("");
    setPasteError("");
    setPasteText("");
    setClearAsked(false);
    setDetailId("");
    setConfirmed(false);
    setExcelError("");
    setExcelMessage("");
  }

  function paste() {
    if (draftFrozen()) return;
    try {
      const imported = caisseBatchPaste(kind, pasteText, references, defaults);
      const existing = rows.length === 1 && rows[0].pristine ? [] : rows;
      if (imported.length + existing.length > MAX_CAISSE_BATCH_ROWS) {
        throw new Error("Le panier accepte au maximum "+MAX_CAISSE_BATCH_ROWS+" lignes.");
      }
      append([...existing, ...imported]);
      setPasteError("");
      setPasteText("");
      setPasteOpen(false);
    } catch (failure) {
      setPasteError(failure.message);
    }
  }

  function focusIssue(id, field, sourceRows = rows) {
    const index = sourceRows.findIndex(row => row.clientRowId === id);
    if (index < 0) return;
    setPage(Math.floor(index / PAGE_SIZE) + 1);
    if (kind === "ecritures" && DETAILS.includes(field)) setDetailId(id);
    requestAnimationFrame(() => {
      if (!alive.current || currentScope.current !== identity) return;
      const target = document.getElementById(prefix+id+field) || document.getElementById(prefix+id+"-details");
      target?.focus({preventScroll:true});
      target?.scrollIntoView({block:"nearest", inline:"nearest"});
    });
  }

  function showIssues(next, sourceRows = rows) {
    setIssues(next);
    const [id, fields] = Object.entries(next)[0] || [];
    if (id) focusIssue(id, Object.keys(fields)[0], sourceRows);
  }

  function excelIsCurrent(controller) {
    return alive.current && currentAccess.current && currentScope.current === identity &&
      excelRequest.current === controller && !controller.signal.aborted;
  }

  async function downloadTemplate() {
    if (draftFrozen() || excelRequest.current) return;
    const controller = new AbortController();
    controller.operation = "download";
    excelRequest.current = controller;
    setExcelBusy("download");
    setExcelError("");
    setExcelMessage("");
    try {
      await downloadApiFile(CAISSE_ROOT+"/"+kind+"/modele-excel", {
        signal:controller.signal, filename:"modele-import-"+kind+".xlsx",
      });
      if (excelIsCurrent(controller)) setExcelMessage("Modèle Excel téléchargé.");
    } catch (failure) {
      if (excelIsCurrent(controller)) setExcelError(failure.message || "Le modèle Excel n’a pas pu être téléchargé.");
    } finally {
      if (excelRequest.current === controller) {
        if (excelIsCurrent(controller)) setExcelBusy("");
        excelRequest.current = null;
      }
    }
  }

  async function importFile(event) {
    const file = event.currentTarget.files?.[0];
    event.currentTarget.value = "";
    if (!file || draftFrozen() || excelRequest.current || rows.length >= MAX_CAISSE_BATCH_ROWS) return;
    setExcelError("");
    setExcelMessage("");
    if (!/\.xlsx$/i.test(file.name) || !file.size || file.size > EXCEL_MAX_BYTES) {
      setExcelError("Choisissez un fichier Excel .xlsx non vide de 4 Mo maximum.");
      return;
    }
    const controller = new AbortController();
    controller.operation = "import";
    excelRequest.current = controller;
    setExcelBusy("import");
    try {
      const body = new FormData();
      body.append("fichier", file);
      const response = await requestJson(CAISSE_ROOT+"/"+kind+"/import-excel", {
        requiresAuth:true, method:"POST", body, signal:controller.signal,
      });
      if (!excelIsCurrent(controller)) return;
      if (!response?.success) throw new Error(response?.status === 413 ? "Le fichier dépasse 4 Mo." :
        response?.message || "Le fichier Excel n’a pas pu être lu.");
      const imported = caisseBatchFromMatrix(kind, response.data?.cells, references, defaults);
      const existing = rows.length === 1 && rows[0].pristine ? [] : rows;
      if (existing.length + imported.length > MAX_CAISSE_BATCH_ROWS) {
        throw new Error("Le panier accepte au maximum "+MAX_CAISSE_BATCH_ROWS+" lignes.");
      }
      const next = [...existing, ...imported];
      const nextIssues = caisseBatchErrors(kind, next, references);
      setRows(next);
      setPage(Math.floor(existing.length / PAGE_SIZE) + 1);
      setConfirmed(false);
      setError("");
      setIssues(nextIssues);
      ticket.current = null;
      const [issueId, fields] = Object.entries(nextIssues)[0] || [];
      focusIssue(issueId || imported[0].clientRowId, issueId ? Object.keys(fields)[0] : CAISSE_BATCH_FIELDS[kind][0], next);
      setExcelMessage((imported.length === 1 ? "1 ligne ajoutée au panier." : imported.length+" lignes ajoutées au panier.") +
        (issueId ? " Vérifiez les champs signalés avant d’enregistrer." : ""));
    } catch (failure) {
      if (excelIsCurrent(controller)) {
        setExcelError(failure.message || "Le fichier Excel n’a pas pu être lu.");
        requestAnimationFrame(() => {
          if (alive.current && currentAccess.current && currentScope.current === identity) {
            document.getElementById(prefix+"import-excel")?.focus();
          }
        });
      }
    } finally {
      if (excelRequest.current === controller) {
        if (excelIsCurrent(controller)) setExcelBusy("");
        excelRequest.current = null;
      }
    }
  }

  async function refreshBalance(row) {
    if (draftFrozen() || balanceRequests.current.has(row.clientRowId)) return;
    const controller = new AbortController();
    const {clientRowId:id, values:{IdCaisseFk:cashId, ClotureLe:date, MontantCompte:amount}} = row;
    if (!cashId || !validCaisseDate(date)) return;
    const params = new URLSearchParams({caisseId:cashId,date});
    const counted = caisseAmount(amount,{zero:true});
    if (counted != null) params.set("montantCompte",counted);
    balanceRequests.current.set(id, controller);
    setConfirmed(false);
    setRows(previous => previous.map(item => item.clientRowId === id ? {...item, balance:{loading:true}} : item));
    const isCurrent = () => alive.current && currentAccess.current && currentScope.current === identity &&
      balanceRequests.current.get(id) === controller && !controller.signal.aborted;
    try {
      const response = await requestJson(CAISSE_ROOT+"/clotures/preparation?"+params,
        {requiresAuth:true, signal:controller.signal});
      if (!isCurrent()) return;
      const data = response?.data;
      const balance = response?.success && data?.canManage && data.record?.Actif && data._version &&
          String(data.record.IdCaisse) === String(cashId)
        ? {record:data.record, version:data._version}
        : {error:response?.message || "Le solde n’a pas pu être chargé."};
      setRows(previous => previous.map(item => item.clientRowId === id && item.values.IdCaisseFk === cashId ? {...item, balance} : item));
      setIssues(previous => ({...previous, [id]:{...previous[id], _version:undefined}}));
    } catch (failure) {
      if (isCurrent()) setRows(previous => previous.map(item => item.clientRowId === id && item.values.IdCaisseFk === cashId
        ? {...item, balance:{error:failure.message || "Le solde n’a pas pu être chargé."}} : item));
    } finally {
      if (balanceRequests.current.get(id) === controller) balanceRequests.current.delete(id);
    }
  }

  async function submit() {
    if (!canWrite || !currentAccess.current || currentScope.current !== identity || !alive.current ||
      currentRequest.current || balanceRequests.current.size || importing ||
      excelRequest.current?.operation === "import") return;
    if (!ticket.current) {
      const next = caisseBatchErrors(kind, rows, references);
      if (Object.keys(next).length) {
        setError("Vérifiez les lignes signalées. Aucune ligne n’a été enregistrée.");
        showIssues(next);
        return;
      }
      if (needsConfirmation && !confirmed) {
        setError("Confirmez l’opération avant d’enregistrer l’ensemble.");
        document.getElementById(prefix+"confirm")?.focus();
        return;
      }
      const payload = caisseBatchPayload(kind, rows, legacyImmediate && validate);
      ticket.current = {payload, body:JSON.stringify(payload)};
    }
    const snapshot = ticket.current;
    const controller = new AbortController();
    currentRequest.current = controller;
    setError("");
    setBusy(true);
    const response = await requestJson(CAISSE_ROOT+"/"+kind,
      {requiresAuth:true, method:"POST", body:snapshot.body, signal:controller.signal});
    if (!alive.current || controller.signal.aborted || currentRequest.current !== controller) return;
    currentRequest.current = null;
    setBusy(false);
    if (currentScope.current !== identity || !currentAccess.current) {
      setUncertain(true);
      setError("La confirmation n’a pas été reçue. Réessayez pour vérifier le même enregistrement.");
      return;
    }
    const result = response?.data;
    const expected = new Set(snapshot.payload.rows.map(row => row.clientRowId));
    const received = new Set(Array.isArray(result?.records) ? result.records.map(row => row?.clientRowId) : []);
    if (response?.success && result?.requestId === snapshot.payload.requestId &&
      result.count === expected.size && result.records?.length === expected.size &&
      received.size === expected.size && [...received].every(id => expected.has(id))) {
      ticket.current = null;
      onSaved(result);
      return;
    }
    if (!response?.status || response.status >= 500 || response.success) {
      setUncertain(true);
      setError("La confirmation n’a pas été reçue. Réessayez pour vérifier le même enregistrement.");
      return;
    }
    ticket.current = null;
    setUncertain(false);
    setConfirmed(false);
    const details = response.error?.details;
    if (details?.rows && Object.keys(details.rows).length) {
      showIssues(details.rows);
      setError("Vérifiez les lignes signalées. Aucune ligne n’a été enregistrée.");
    } else {
      setError(Object.values(details?.header || {})[0] || response.message || "Le panier n’a pas pu être enregistré.");
    }
  }

  function field(row, key) {
    const value = row.values[key];
    const id = prefix+row.clientRowId+key;
    const issue = issues[row.clientRowId]?.[key];
    const label = CAISSE_BATCH_LABELS[key]+" · ligne "+(rowsById.get(row.clientRowId)+1);
    const props = {id, disabled:frozen, "aria-label":label, "aria-invalid":Boolean(issue),
      "aria-describedby":issue ? id+"-error" : undefined, value:value ?? "",
      onChange:event => changeRow(row.clientRowId, key, event.target.value)};
    const options = caisseBatchChoices(key, references);
    const choices = options && String(value ?? "") && !options.some(option => option.value === String(value))
      ? [...options, {value:String(value), label:"À vérifier · "+value, disabled:true}] : options;
    return <div className="logistics-batch-cell">
      {choices ? <SearchSelect id={id} label={label} value={String(value ?? "")} options={choices} disabled={frozen}
        invalid={Boolean(issue)} describedBy={issue ? id+"-error" : undefined}
        onChange={next => changeRow(row.clientRowId, key, key === "Actif" ? next === "true" : next)}/>
        : key === "ObsPaiement" ? <textarea {...props} rows={3} maxLength={TEXT_LIMITS[key]}/>
        : <input {...props} type={isBatchDate(key) && (!value || validCaisseDate(value)) ? "datetime-local" : "text"} step={isBatchDate(key) ? 1 : undefined}
          inputMode={isBatchAmount(key) ? "decimal" : undefined} maxLength={TEXT_LIMITS[key]} autoComplete="off"/>}
      {issue ? <small id={id+"-error"} className="record-field-error">{issue}</small> : null}
    </div>;
  }

  const fields = CAISSE_BATCH_FIELDS[kind];
  const columns = [{key:"number", label:"N°", width:52, sortable:false, render:row => rowsById.get(row.clientRowId)+1}];
  for (const key of fields) {
    if (kind === "ecritures" && DETAILS.includes(key)) continue;
    columns.push({key, label:CAISSE_BATCH_LABELS[key], width:WIDTHS[key] || 144, sortable:false, render:row => field(row,key)});
    if (kind === "clotures" && key === "ClotureLe") {
      columns.push({key:"balance", label:"Contrôle du comptage", width:230, sortable:false, render:row => {
        const issue = issues[row.clientRowId]?._version || row.balance?.error;
        const balance = row.balance?.record;
        const amount = field => formatCurrency(balance[field],balance.DeviseCode);
        return <div className="logistics-batch-cell caisse-batch-balance">
          {row.values.IdCaisseFk ? <ActionButton id={prefix+row.clientRowId+"_version"} icon="refresh"
            aria-label={"Vérifier le solde · ligne "+(rowsById.get(row.clientRowId)+1)}
            disabled={frozen || row.balance?.loading || !validCaisseDate(row.values.ClotureLe)} onClick={() => refreshBalance(row)}>
            {row.balance?.loading?"Vérification…":balance?"Actualiser":"Vérifier le solde"}
          </ActionButton> : null}
          {balance ? <dl className="caisse-count-breakdown">
            <div><dt>Solde validé</dt><dd>{amount("SoldeValide")}</dd></div>
            {Number(balance.NombreBrouillons) > 0 ? <>
              <div><dt>Brouillons</dt><dd>{balance.NombreBrouillons}</dd></div>
              <div><dt>Encaissements</dt><dd>{amount("EntreesBrouillon")}</dd></div>
              <div><dt>Décaissements</dt><dd>{amount("SortiesBrouillon")}</dd></div>
              <div><dt>Solde prévisionnel</dt><dd>{amount("SoldePrevisionnel")}</dd></div>
            </> : null}
            {balance.EcartComptage!=null?<div><dt>Écart constaté</dt><dd>{amount("EcartComptage")}</dd></div>:null}
          </dl> : null}
          {issue ? <small className="record-field-error">{issue}</small> : null}
        </div>;
      }});
    }
  }
  columns.push({key:"actions", label:"Actions", width:108, sortable:false, render:row => {
    const index = rowsById.get(row.clientRowId)+1;
    return <div className="erp-row-actions">
      {kind === "ecritures" ? <ActionButton id={prefix+row.clientRowId+"-details"} icon="edit" className="is-icon"
        aria-label={"Détails de la ligne "+index} disabled={frozen} onClick={() => {
          setDetailId(row.clientRowId);
          requestAnimationFrame(() => document.getElementById(prefix+row.clientRowId+DETAILS[0])?.focus());
        }}/> : null}
      <ActionButton icon="trash" className="is-icon" aria-label={"Retirer la ligne "+index} disabled={frozen}
        onClick={() => remove(row.clientRowId)}/>
    </div>;
  }});
  const selected = rows.find(row => row.clientRowId === detailId);
  const rowErrors = Object.entries(issues).flatMap(([id, fields]) => {
    const index = rowsById.get(id);
    return index == null ? [] : Object.entries(fields).filter(([, message]) => message).map(([key, message]) =>
      <li key={id+key}><button type="button" onClick={() => focusIssue(id,key)}>Ligne {index+1} · {CAISSE_BATCH_LABELS[key] || "Vérification"}</button> {message}</li>);
  });
  const definition = CAISSE_REGISTERS[kind];

  return <RecordEditorFrame title={definition.create} subtitle="Une ou plusieurs lignes dans le même panier."
    icon={definition.icon} onClose={onClose} onSubmit={submit} busy={busy} readOnly={!canWrite} canSubmit={!importing}
    dirty={uncertain || rows.length > 1 || rows.some(row => !row.pristine) || Boolean(pasteText.trim()) || validate}
    submitLabel={uncertain ? "Vérifier l’enregistrement" : "Enregistrer l’ensemble"} error={error}
    discardMessage={uncertain ? "L’enregistrement est peut-être terminé. Vérifiez le registre avant de refaire cette opération." : undefined}
    defaultWidth={1230} storageKey="sauverndeko.caisse.panier.width" className="caisse-batch logistics-batch-composer">
    <section className="record-editor-section">
      <div className="logistics-batch-heading">
        <h3><AppIcon name={definition.icon}/>Panier <span className="erp-count-badge">{rows.length}</span></h3>
        <div className="logistics-batch-actions">
          <ActionButton icon="plus" disabled={frozen || rows.length >= MAX_CAISSE_BATCH_ROWS}
            onClick={() => append([...rows,caisseBatchRow(kind,references,kind === "clotures" ? {} : defaults)])}>Ajouter une ligne</ActionButton>
          <>
            <ActionButton icon="download" disabled={frozen || Boolean(excelBusy)} onClick={downloadTemplate}>
              {excelBusy === "download" ? "Téléchargement…" : "Télécharger le modèle Excel"}
            </ActionButton>
            <input type="file" ref={fileInput} accept=".xlsx,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
              hidden disabled={frozen || Boolean(excelBusy) || rows.length >= MAX_CAISSE_BATCH_ROWS} onChange={importFile}/>
            <ActionButton id={prefix+"import-excel"} icon="upload" variant="primary" aria-describedby={prefix+"import-excel-hint"}
              disabled={frozen || Boolean(excelBusy) || rows.length >= MAX_CAISSE_BATCH_ROWS}
              onClick={() => {if (!draftFrozen() && !excelRequest.current) fileInput.current?.click();}}>Importer un fichier Excel</ActionButton>
          </>
          <ActionButton icon="document" disabled={frozen} aria-expanded={pasteOpen} aria-controls={prefix+"paste-panel"}
            onClick={() => setPasteOpen(open => !open)}>Coller depuis Excel</ActionButton>
          <ActionButton icon="trash" disabled={frozen || rows.every(row => row.pristine) && rows.length === 1 && !pasteText}
            onClick={() => setClearAsked(true)}>Vider le panier</ActionButton>
        </div>
      </div>
      <p className="record-editor-note">{kind === "caisses" ? "Les codes sont attribués automatiquement. Les nouvelles caisses commencent à zéro."
        : kind === "ecritures" ? "Un brouillon n’affecte pas le solde. Date et heure de Kinshasa."
        : "Une ligne par caisse. Les écarts de comptage restent dans l’historique. Date et heure de Kinshasa."}</p>
      <>
        <p id={prefix+"import-excel-hint"} className="record-editor-note">Importez le modèle ou un fichier .xlsx avec les mêmes en-têtes sur la première ligne (4 Mo, 100 lignes maximum). Vérifiez le panier puis choisissez Enregistrer l’ensemble.</p>
        {excelBusy || excelMessage ? <p className="record-editor-note" role="status" aria-live="polite" aria-atomic="true">
          {importing ? "Lecture du fichier Excel…" : excelBusy ? "Téléchargement du modèle Excel…" : excelMessage}
        </p> : null}
        {excelError ? <p className="record-field-error" role="alert">{excelError}</p> : null}
      </>
      {legacyImmediate ? <label className="caisse-batch-check"><input type="checkbox" checked={validate} disabled={frozen}
        onChange={event => {setValidate(event.target.checked); setConfirmed(false);}}/>Valider immédiatement les écritures</label> :
        kind === "ecritures" ? <p className="record-editor-note">{context?.validationMode==="AUTO"
          ? "Les écritures conformes sont validées à l’enregistrement."
          : context?.validationMode==="OTHER_AGENT" ? "Les écritures restent en brouillon jusqu’à leur validation par un autre agent habilité."
          : "Les écritures sont enregistrées en brouillon."}</p> : null}
      {clearAsked ? <div className="record-discard" role="alert"><span>Retirer toutes les lignes ?</span><div>
        <ActionButton onClick={() => setClearAsked(false)}>Conserver</ActionButton><ActionButton icon="trash" onClick={clear}>Vider le panier</ActionButton>
      </div></div> : null}
      {pasteOpen ? <div id={prefix+"paste-panel"} className="logistics-batch-paste">
        <label htmlFor={prefix+"paste"}>Collage Excel</label>
        <p className="record-editor-note">Copiez les en-têtes avec les lignes. Utilisez les libellés ou les identifiants exacts pour les listes.</p>
        <p className="record-editor-note">{fields.map(key => CAISSE_BATCH_LABELS[key]).join(" · ")}.
          {kind !== "caisses" ? " Date et heure au format JJ/MM/AAAA HH:MM." : ""}</p>
        <textarea id={prefix+"paste"} value={pasteText} onChange={event => {setPasteText(event.target.value);setPasteError("");}}
          rows={4} disabled={frozen}/>
        {pasteError ? <p className="record-field-error" role="alert">{pasteError}</p> : null}
        <ActionButton icon="plus" disabled={frozen || !pasteText.trim()} onClick={paste}>Ajouter au panier</ActionButton>
      </div> : null}
      <div className="erp-results" data-density="compact">
        <SimpleTable columns={columns} rows={rows} getRowId={row => row.clientRowId} page={page} onPageChange={setPage}
          defaultRowsPerPage={PAGE_SIZE} showControls={false} toolbar={<></>} tableLabel={TITLES[kind]+" · panier"}/>
      </div>
      {rowErrors.length ? <ul className="logistics-batch-errors" aria-label="Lignes à vérifier">{rowErrors}</ul> : null}
    </section>
    {selected ? <section className="record-editor-section caisse-fields">
      <div className="logistics-batch-heading"><h3><AppIcon name="document"/>Détails de la ligne {rowsById.get(detailId)+1}</h3>
        <ActionButton icon="close" onClick={() => setDetailId("")}>Fermer les détails</ActionButton>
      </div>
      <div className="caisse-field-grid">{DETAILS.filter(key=>!context?.hiddenFields?.[kind]?.includes(key)).map(key => <div key={key} className="record-field">
        <label htmlFor={prefix+detailId+key}>{CAISSE_BATCH_LABELS[key]}</label>{field(selected,key)}
      </div>)}</div>
    </section> : null}
    {needsConfirmation ? <section className="record-editor-section">
      <label className="caisse-batch-check" htmlFor={prefix+"confirm"}>
        <input id={prefix+"confirm"} type="checkbox" checked={confirmed} disabled={frozen}
          onChange={event => setConfirmed(event.target.checked)}/>
        {kind === "clotures" ? "Je confirme les soldes et les comptages du panier." : "Je confirme la mise à jour des soldes par ces écritures."}
      </label>
    </section> : null}
  </RecordEditorFrame>;
}
