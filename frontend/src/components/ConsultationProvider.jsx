import AppIcon from "./AppIcon";
import DataTableToolbar from "./DataTableToolbar";
import { createContext, useCallback, useContext, useEffect, useRef, useState } from "react";
import { createPortal } from "react-dom";
import { useAuth } from "../contexts/AuthContext";
import { requestJson, downloadApiFile } from "../services/api";
import { SimpleTable, formatNumber, formatDate } from "../pages/logistique/logistiqueShared";
import "./Consultation.css";

const Context = createContext(null);
const LABELS = { identite: "Synthèse", commandes: "Bons de stock", lignes: "Lignes", mouvements: "Mouvements", consommation: "Consommation", couverture: "Couverture", controle: "Contrôle", reglements: "Règlements", facture: "Facture" };
const FIELD_LABELS = { CodeArticleInterne: "Code", NomArticle: "Produit", RefArticle: "Référence", TypeArticle: "Type", CategorieArticle: "Catégorie", Unite: "Unité", QteArticle: "Stock actuel", QteMinArticle: "Seuil", QteACommander: "À commander", EtatStock: "État du stock", PUArticle: "Prix d’achat", PVArticle: "Prix de vente", ValeurStockAchat: "Valeur du stock", MargeUnitaire: "Marge unitaire", DatePeremptionArticle: "Péremption", EtatPeremption: "État de péremption", NomComplet: "Responsable", ObsArticle: "Observation", CodeCmd: "Bon de stock", RefCmd: "Référence", TypeCmd: "Type", StatutCmd: "Statut", DateCmd: "Date", NomClientSaisi: "Tiers", NbLignes: "Lignes", MontantTTC: "Montant TTC", TotalRegleReel: "Réglé", ResteReel: "Reste", EtatPaiement: "Paiement", CodeFacture: "Facture", DateFacture: "Date de facture", MontantRegleFacture: "Réglé", DateEcheancePaiement: "Échéance", EtatControleCommande: "Contrôle", ObsCmd: "Observation", AbrUnite: "Unité", QteCmdDetail: "Quantité", PUCmdDetail: "Prix unitaire", MontantLigne: "Montant", DateMvt: "Date", NomTypeMvt: "Type", QteMvtSigned: "Quantité", PUMvt: "Prix unitaire", MontantMvt: "Montant", OrigineMouvement: "Origine", Mois: "Mois", ConsoMensuelle: "Consommation", ValeurConsoMensuelle: "Valeur", StockActuel: "Stock", ConsoMoyMensuelle: "Consommation moyenne", CouvertureMois: "Couverture · mois", EtatCouverture: "État", StockArticle: "Stock courant", StockMouvements: "Stock des mouvements", Ecart: "Écart", EtatAuditStock: "Contrôle", MontantRegle: "Réglé", DateReglement: "Date", TotalRegle: "Réglé", Reste: "Reste", EtatReglement: "Paiement", CodeFactureFk: "Facture", MontantResteFacture: "Solde à régler" };
const SECTION_FIELDS = {
  commandes: ["CodeCmd", "DateCmd", "NomArticle", "QteCmdDetail", "AbrUnite", "PUCmdDetail", "MontantLigne"],
  lignes: ["CodeArticleInterne", "NomArticle", "QteCmdDetail", "AbrUnite", "PUCmdDetail", "MontantLigne"],
  mouvements: ["DateMvt", "NomArticle", "CodeCmd", "NomTypeMvt", "QteMvtSigned", "PUMvt", "MontantMvt"],
  consommation: ["Mois", "ConsoMensuelle", "ValeurConsoMensuelle"],
  couverture: ["StockActuel", "ConsoMoyMensuelle", "CouvertureMois", "EtatCouverture"],
  controle: ["StockArticle", "StockMouvements", "Ecart", "EtatAuditStock"],
  reglements: ["DateReglement", "MontantRegle", "CodeFactureFk"],
  facture: ["CodeFacture", "DateEcheancePaiement", "MontantTTC", "TotalRegle", "Reste", "EtatReglement"],
};
const PRODUCT_FIELDS = ["CodeArticleInterne", "NomArticle", "RefArticle", "TypeArticle", "CategorieArticle", "Unite", "QteArticle", "QteMinArticle", "QteACommander", "EtatStock", "PUArticle", "PVArticle", "ValeurStockAchat", "MargeUnitaire", "DatePeremptionArticle", "EtatPeremption", "NomComplet", "ObsArticle"];
const ORDER_FIELDS = ["CodeCmd", "RefCmd", "TypeCmd", "StatutCmd", "DateCmd", "NomClientSaisi", "NbLignes", "MontantTTC", "TotalRegleReel", "ResteReel", "EtatPaiement", "CodeFacture", "DateEcheancePaiement", "EtatControleCommande", "NomComplet", "ObsCmd"];

function display(field, value) {
  if (value == null || value === "") return "—";
  if (/^(Date|Mois)/.test(field)) return formatDate(value);
  if (/^(Qte|PU|PV|Valeur|Montant|Marge|Stock|Conso|CouvertureMois|Ecart|Total|Reste|Nb)/.test(field)) return formatNumber(value);
  if (typeof value === "boolean") return value ? "Oui" : "Non";
  return String(value);
}
function StatusValue({ field, value }) {
  const label = String(value);
  const tones = { "Rupture":"danger", "Périmé":"danger", "Périmés":"danger", "En retard":"danger", "Stock faible":"warning", "Faible":"warning", "En attente":"warning", "Partiel":"warning", "Partiellement réglée":"warning", "À régler":"warning", "Non facturée":"warning", "Disponible":"success", "Normal":"success", "Cohérent":"success", "Soldée":"success", "Réglée":"success", "Validée":"success", "En cours":"info", "Entrée":"info", "Sortie":"neutral" };
  return <span className={"erp-status is-" + (tones[label] || "neutral")}>{display(field,value)}</span>;
}
function useRead(url) {
  const [version, setVersion] = useState(0);
  const [state, setState] = useState({ loading: Boolean(url), payload: null });
  useEffect(() => {
    if (!url) { setState({ loading: false, payload: null }); return; }
    const controller = new AbortController();
    setState((current) => ({ ...current, loading: true }));
    requestJson(url, { requiresAuth: true, signal: controller.signal }).then((payload) => {
      if (!controller.signal.aborted) setState({ loading: false, payload });
    });
    return () => controller.abort();
  }, [url, version]);
  return { ...state, retry: () => setVersion((value) => value + 1) };
}
function ErrorState({ payload, retry }) {
  return <div className="consult-state" role="alert"><p>{payload?.status === 403 ? "Accès refusé." : payload?.status === 404 ? "Fiche introuvable." : "Le chargement a échoué."}</p><button type="button" onClick={retry}>Réessayer</button></div>;
}

function parseFilters(value) { try { return typeof value === "string" ? JSON.parse(value || "{}") : value || {}; } catch { return {}; } }
function compactFilters(filters) { return Object.fromEntries(Object.entries(filters).filter(([,value]) => String(value).trim()).map(([key,value]) => [key,String(value).trim()])); }
function ResultTable({ remote, query, onQueryChange, fields, open, kind = null, exportPath = null }) {
  const data = remote.payload;
  const available = data?.meta?.columns || Object.keys(data?.data?.[0] || {});
  const types = data?.meta?.columnTypes || {};
  const shown = fields.filter((field) => available.includes(field));
  const [search,setSearch] = useState(query.q || "");
  const [filters,setFilters] = useState(() => parseFilters(query.columnFilters));
  const [filtersOpen,setFiltersOpen] = useState(() => Object.keys(parseFilters(query.columnFilters)).length > 0);
  const [columnsOpen,setColumnsOpen] = useState(false);
  const columnsAnchorRef=useRef(null);
  const [visibleColumns,setVisibleColumns] = useState([]);
  const [density,setDensity] = useState(() => { try { return localStorage.getItem("sauverndeko.table.density") === "airy" ? "airy" : "compact"; } catch { return "compact"; } });
  const [exporting,setExporting] = useState(false);
  const [exportError,setExportError] = useState("");
  const exportRequest = useRef(null);
  const queryKey = JSON.stringify(query);
  useEffect(() => { setSearch(query.q || ""); setFilters(parseFilters(query.columnFilters)); },[query.q,query.columnFilters]);
  useEffect(() => { try { localStorage.setItem("sauverndeko.table.density",density); } catch { /* Préférence facultative. */ } },[density]);
  useEffect(() => { setExportError(""); exportRequest.current?.abort(); setExporting(false); return () => exportRequest.current?.abort(); },[queryKey,exportPath]);
  const applied = compactFilters(parseFilters(query.columnFilters));
  const draft = compactFilters(filters);
  const pending = search.trim() !== (query.q || "") || JSON.stringify(draft) !== JSON.stringify(applied);
  const activeFilters = Object.keys(applied).length + Number(Boolean(query.q));
  const apply = () => onQueryChange({ q:search.trim(), columnFilters:JSON.stringify(draft), skip:0 });
  const reset = () => { setSearch(""); setFilters({}); onQueryChange({ q:"",columnFilters:"{}",skip:0 }); };
  async function exportFile() {
    const controller = new AbortController();
    exportRequest.current?.abort(); exportRequest.current = controller;
    setExporting(true); setExportError("");
    const keys = (visibleColumns.length ? visibleColumns : shown).filter(key => shown.includes(key));
    const params = new URLSearchParams({ ...query, timeZone:Intl.DateTimeFormat().resolvedOptions().timeZone, columns:JSON.stringify(keys) });
    params.delete("take"); params.delete("skip");
    try { await downloadApiFile(exportPath + "?" + params,{ signal:controller.signal }); }
    catch(error) { if (!controller.signal.aborted && error.name !== "AbortError") setExportError(error.message || "L’export a échoué."); }
    finally { if (!controller.signal.aborted) setExporting(false); }
  }
  const columns = shown.map((field) => {
    const sqlType = types[field] || "";
    const numeric = /^(numeric|decimal|integer|bigint|smallint|real|double precision)$/.test(sqlType);
    return { key:field,label:FIELD_LABELS[field] || field,align:numeric ? "right" : "left",filterType:numeric ? "number" : /^(date|timestamp)/.test(sqlType) ? "date" : sqlType === "boolean" ? "boolean" : "text",
      render:(row) => {
        if (["NomArticle","CodeArticleInterne"].includes(field) && (row.ID_Article || row.ID_ArticleFk)) return <button type="button" className="erp-object-link" onClick={(event) => { event.stopPropagation(); open("produit",row.ID_Article || row.ID_ArticleFk,row.NomArticle); }}>{display(field,row[field])}</button>;
        if (field === "CodeCmd" && (row.ID_Commande || row.ID_CmdFk || row.ID_cmdFk)) return <button type="button" className="erp-object-link" onClick={(event) => { event.stopPropagation(); open("commande",row.ID_Commande || row.ID_CmdFk || row.ID_cmdFk,row.CodeCmd); }}>{display(field,row[field])}</button>;
        if (/^(Etat|Statut)/.test(field) && row[field] != null && row[field] !== "") return <StatusValue field={field} value={row[field]} />;
        return display(field,row[field]);
      }, renderText:(row) => display(field,row[field]) };
  });
  if (kind && available.length) columns.push({ key:"consultation",label:"Actions",sortable:false,searchable:false,renderText:()=>"",render:(row) => {
    const id = kind === "produit" ? row.ID_Article || row.ID_ArticleFk : row.ID_Commande || row.ID_CmdFk || row.ID_cmdFk;
    return id ? <button type="button" className="erp-object-link" onClick={(event) => { event.stopPropagation(); open(kind,id,row.NomArticle || row.CodeCmd || row.CodeFacture); }}>Consulter</button> : "—";
  }});
  const toolbar = <DataTableToolbar search={search} setSearch={setSearch} onApply={apply} onReset={reset} pending={pending} take={Number(query.take || 25)} onTake={(take) => onQueryChange({take,skip:0})} filtersOpen={filtersOpen} toggleFilters={() => setFiltersOpen(value => !value)} activeFilters={activeFilters} density={density} toggleDensity={() => setDensity(value => value === "airy" ? "compact" : "airy")} columnsOpen={columnsOpen} columnsButtonRef={columnsAnchorRef} toggleColumns={() => setColumnsOpen(value => !value)} loading={remote.loading} exportFile={exportPath ? exportFile : null} exporting={exporting} exportDisabled={!data?.success || !data?.meta?.filteredCount} error={exportError} />;
  return <div className="erp-results" data-density={density} aria-busy={remote.loading}>
    {remote.loading ? <span className="erp-grid-loading" role="status">Actualisation…</span> : null}
    {data && !data.success ? <ErrorState payload={data} retry={remote.retry} /> : null}
    <SimpleTable columns={columns} rows={data?.success ? data.data || [] : []} toolbar={toolbar} columnsPanelOpen={columnsOpen} columnsAnchorRef={columnsAnchorRef} onColumnsPanelClose={()=>setColumnsOpen(false)} onVisibleColumnsChange={setVisibleColumns} filtersVisible={filtersOpen} columnFilters={filters} onColumnFilterChange={(key,value) => setFilters(current => ({...current,[key]:value}))} onApplyColumnFilters={apply} showControls serverMeta={data?.meta} serverState={query} onServerChange={onQueryChange} enableSelection={false} loading={remote.loading} getRowId={(row,index) => [row.ID_Mvt || row.IdReglement || row.ID_Commande || row.ID_CmdFk || row.ID_Article || "",row.ID_ArticleFk || "",row.Mois || "",index].join(":")} />
  </div>;
}

function ObjectContent({ entry, update, open }) {
  const base = "/api/logistique/consultations/" + entry.kind + "/" + entry.id;
  const header = useRead(base);
  const queryString = new URLSearchParams(entry.query).toString();
  const section = entry.section || "identite";
  const details = useRead(section === "identite" ? null : base + "/" + section + "?" + queryString);
  const record = header.payload?.data?.record;
  if (header.loading && !record) return <p className="consult-loading" role="status">Chargement…</p>;
  if (!header.payload?.success) return <ErrorState payload={header.payload} retry={header.retry} />;
  return <>
    <div className="consult-record-heading"><h3>{record.NomArticle || record.CodeCmd || (entry.kind === "produit" ? "Produit" : "Bon de stock")}</h3><span>{record.EtatStock || record.StatutCmd || ""}</span></div>
    <nav className="consult-tabs" aria-label="Rubriques">
      {header.payload.data.sections.map((key) => <button key={key} type="button" aria-current={key === section ? "page" : undefined} onClick={() => update({ section: key, query: { take: 25, skip: 0 } })}>{LABELS[key] || key}</button>)}
    </nav>
    {section === "identite" ? <><dl className="consult-fields">{(entry.kind === "produit" ? PRODUCT_FIELDS : ORDER_FIELDS).map((field) => <div key={field}><dt>{FIELD_LABELS[field]}</dt><dd>{display(field, record[field])}</dd></div>)}</dl><p className="consult-note">Montants sans devise précisée.</p></> :
      <ResultTable key={section} remote={details} query={entry.query} onQueryChange={(patch) => update({ query: { ...entry.query, ...patch } })} fields={SECTION_FIELDS[section] || []} open={open} />}
  </>;
}
function IndicatorContent({ entry, update, open, inline = false }) {
  const remote = useRead("/api/logistique/indicateurs/" + entry.id + "?" + new URLSearchParams(entry.query));
  const indicator = remote.payload?.meta?.indicator;
  const isInvoice = entry.id.startsWith("factures") || ["montantTotalFacture", "montantTotalRegle", "montantRestant"].includes(entry.id);
  const fields = indicator?.kind === "produit" ? ["CodeArticleInterne", "NomArticle", "QteArticle", "QteMinArticle", "EtatStock", "StockArticle", "StockMouvements", "Ecart", "EtatAuditStock", "CouvertureMois"] : isInvoice ? ["CodeFacture", "CodeCmd", "DateFacture", "DateEcheancePaiement", "NomClientSaisi", "MontantTTC", "MontantRegleFacture", "TotalRegle", "MontantResteFacture", "Reste"] : ["CodeCmd", "DateCmd", "TypeCmd", "StatutCmd", "NomClientSaisi", "NbLignes", "MontantTTC", "EtatPaiement"];
  return <>{!inline && indicator ? <div className="consult-indicator"><strong>{formatNumber(indicator.value)}{indicator.unit ? " " + indicator.unit : ""}</strong><span>{indicator.label}</span></div> : null}
    <ResultTable remote={remote} query={entry.query} onQueryChange={(patch) => update({ query: { ...entry.query, ...patch } })} fields={fields} open={open} showControls={inline} kind={indicator?.kind} exportPath={"/api/logistique/indicateurs/" + entry.id + "/export.xlsx"} />
  </>;
}

export function IndicatorDetails({ metricKey, criteria }) {
  const { openProduct, openOrder } = useConsultations();
  const [query, setQuery] = useState(() => ({ ...criteria, populationQ: criteria.q || "", q: "", timeZone:Intl.DateTimeFormat().resolvedOptions().timeZone, take: 50, skip: 0 }));
  const entry = { id: metricKey, query };
  const open = (kind, id, label) => kind === "produit" ? openProduct({ ID_Article: id, NomArticle: label }) : openOrder({ ID_Commande: id, CodeCmd: label });
  return <IndicatorContent entry={entry} update={(patch) => setQuery(patch.query)} open={open} inline />;
}

function Dialog({ children, title, onClose, onBack }) {
  const dialog = useRef(null);
  const origin = useRef(null);
  const drag = useRef(null);
  const [width, setWidth] = useState(() => {
    try { return Number(localStorage.getItem("sauverndeko.consultation.width")) || 680; } catch { return 680; }
  });
  const [viewport, setViewport] = useState(window.innerWidth);
  const limits = { min: Math.min(480, viewport), max: Math.max(Math.min(480, viewport), Math.floor(viewport * .94)) };
  const actual = Math.min(limits.max, Math.max(limits.min, width));
  const resize = useCallback((next) => setWidth(Math.min(limits.max, Math.max(limits.min, next))), [limits.min, limits.max]);
  useEffect(() => { const listener = () => setViewport(window.innerWidth); window.addEventListener("resize", listener); return () => window.removeEventListener("resize", listener); }, []);
  useEffect(() => {
    origin.current = document.activeElement;
    const element = dialog.current;
    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    element.showModal();
    element.querySelector(".consult-close")?.focus();
    return () => { document.body.style.overflow = previousOverflow; element.close(); if (origin.current?.isConnected) origin.current.focus({ preventScroll: true }); };
  }, []);
  useEffect(() => { try { localStorage.setItem("sauverndeko.consultation.width", String(actual)); } catch { /* Préférence facultative. */ } }, [actual]);
  return createPortal(<dialog ref={dialog} id="consultation-dialog" className="consultation-dialog" style={{ "--consultation-width": actual + "px" }} aria-labelledby="consult-title" onCancel={(event) => { event.preventDefault(); onClose(); }} onClick={(event) => {
    if (event.target !== event.currentTarget || drag.current) return;
    const rect = event.currentTarget.getBoundingClientRect();
    if (event.clientX < rect.left || event.clientX > rect.right) onClose();
  }}>
    <header className="consult-header"><div>{onBack ? <button type="button" className="consult-back" onClick={onBack}><i className="bi bi-arrow-left" aria-hidden="true" /> Retour</button> : null}<h2 id="consult-title">{title}</h2></div>
      <div className="consult-actions"><div className="consult-width-actions" role="group" aria-label="Largeur de la consultation"><button type="button" aria-label="Réduire" disabled={actual <= limits.min} onClick={() => resize(actual - 160)}><i className="bi bi-chevron-bar-right" aria-hidden="true" /></button><button type="button" aria-label="Élargir" disabled={actual >= limits.max} onClick={() => resize(actual + 160)}><i className="bi bi-chevron-bar-left" aria-hidden="true" /></button><button type="button" aria-label="Rétablir la largeur" onClick={() => resize(680)}><AppIcon name="reset" /></button></div><button type="button" aria-label="Fermer la consultation" className="consult-close" onClick={onClose}><i className="bi bi-x-lg" aria-hidden="true" /></button></div>
    </header>
    <div className="consult-resize" role="separator" tabIndex="0" aria-label="Redimensionner la consultation" aria-orientation="vertical" aria-controls="consultation-dialog" aria-valuetext={actual + " pixels"} aria-valuemin={limits.min} aria-valuemax={limits.max} aria-valuenow={actual}
      onPointerDown={(event) => { event.currentTarget.setPointerCapture(event.pointerId); drag.current = { x: event.clientX, width: actual }; }}
      onPointerMove={(event) => { if (drag.current) resize(drag.current.width + drag.current.x - event.clientX); }}
      onPointerUp={(event) => { drag.current = null; event.currentTarget.releasePointerCapture(event.pointerId); }}
      onPointerCancel={() => { drag.current = null; }} onDoubleClick={() => resize(680)}
      onKeyDown={(event) => { const step = event.shiftKey ? 128 : 32; if (["ArrowLeft", "ArrowRight", "Home", "End"].includes(event.key)) { event.preventDefault(); resize(event.key === "Home" ? limits.min : event.key === "End" ? limits.max : actual + (event.key === "ArrowLeft" ? step : -step)); } }} />
    <div className="consult-content">{children}</div>
  </dialog>, document.body);
}

export function ConsultationProvider({ children }) {
  const { user, isAuthenticated } = useAuth();
  const [history, setHistory] = useState([]);
  useEffect(() => { setHistory([]); }, [user?.IdUser, user?.IdEntiteFk, user?.permissions?.canAccessAdmin, isAuthenticated]);
  const open = useCallback((kind, id, label = "", criteria = {}) => {
    if (!user?.permissions?.canAccessAdmin || !id || !["produit", "commande", "indicateur"].includes(kind)) return;
    setHistory((current) => [...current.slice(-7), { kind, id, label, section: "identite", query: { ...criteria, take: 25, skip: 0 } }]);
  }, [user?.permissions?.canAccessAdmin]);
  const update = (patch) => setHistory((current) => current.map((item, index) => index === current.length - 1 ? { ...item, ...patch } : item));
  const entry = history[history.length - 1];
  return <Context.Provider value={{ openProduct: (row) => open("produit", typeof row === "object" ? row.ID_Article || row.ID_ArticleFk : row, row?.NomArticle || ""), openOrder: (row) => open("commande", typeof row === "object" ? row.ID_Commande || row.ID_CmdFk || row.ID_cmdFk : row, row?.CodeCmd || ""), openMetric: (key, criteria = {}, label = "") => open("indicateur", key, label, criteria) }}>{children}
    {entry && isAuthenticated ? <Dialog title={entry.kind === "produit" ? "Produit 360" + (entry.label ? " · " + entry.label : "") : entry.kind === "commande" ? "Bon de stock 360" + (entry.label ? " · " + entry.label : "") : entry.label || "Détail de l’indicateur"} onClose={() => setHistory([])} onBack={history.length > 1 ? () => setHistory((current) => current.slice(0, -1)) : null}>
      {entry.kind === "indicateur" ? <IndicatorContent key={entry.kind + entry.id} entry={entry} update={update} open={open} /> : <ObjectContent key={entry.kind + entry.id} entry={entry} update={update} open={open} />}
    </Dialog> : null}
  </Context.Provider>;
}
export function useConsultations() {
  const context = useContext(Context);
  if (!context) throw new Error("ConsultationProvider manquant.");
  return context;
}
