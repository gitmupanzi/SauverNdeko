import { formatConsumptionMoney, formatCurrencyGroups } from "../utils/money";
import { accessSignature, moduleRights } from "../services/moduleAccess";
import { useNavigate } from "react-router-dom";
import { RecordFolderLinks } from "./FollowupFolderWidgets";
import { useFollowupFolders } from "../contexts/FollowupFoldersContext";
import ProductOverview, { ProductHeading } from "./ProductOverview";
import AppIcon from "./AppIcon";
import DataTableToolbar from "./DataTableToolbar";
import { createContext, useCallback, useContext, useEffect, useRef, useState } from "react";
import DrawerDialog from "./DrawerDialog";
import ConsultationTabs from "./ConsultationTabs";
import { useAuth } from "../contexts/AuthContext";
import { requestJson, downloadApiFile } from "../services/api";
import { SimpleTable, formatCurrency, formatNumber, formatDate } from "../pages/logistique/logistiqueShared";
import "./Consultation.css";

const Context = createContext(null);
const PRODUCT_INDICATORS = new Set(["articles","articlesCategorie","alertesStock","ruptures","auditTotal","auditCoherents","auditEcarts","coherenceRate","couvertureCritique","peremptionProche","articlesPerimes"]);
const LABELS = {lots:"Lots", identite: "Synthèse", commandes: "Bons de stock", lignes: "Lignes", mouvements: "Mouvements", consommation: "Consommation", couverture: "Couverture", controle: "Contrôle", reglements: "Règlements", facture: "Facture" };
const FIELD_LABELS = {DeviseCode:"Devise",MontantsParDevise:"Valeurs par devise",NumeroLot:"N° de lot",StockLot:"Stock du lot",Quantite:"Quantité",QuantiteSignee:"Quantité signée",DatePeremptionLot:"Péremption du lot",QuantiteEntree:"Entrées",QuantiteSortie:"Sorties", CodeArticleInterne: "Code", NomArticle: "Produit", RefArticle: "Référence", TypeArticle: "Type", CategorieArticle: "Catégorie", Unite: "Unité", QteArticle: "Stock actuel", QteMinArticle: "Seuil", QteACommander: "À commander", EtatStock: "État du stock", PUArticle: "Prix d’achat", PVArticle: "Prix de vente", ValeurStockAchat: "Valeur du stock", MargeUnitaire: "Marge unitaire", DatePeremptionArticle: "Péremption", EtatPeremption: "État de péremption", NomComplet: "Responsable", ObsArticle: "Observation", CodeCmd: "Bon de stock", RefCmd: "Référence", TypeCmd: "Type", StatutCmd: "Statut", DateCmd: "Date", NomClientSaisi: "Tiers", NbLignes: "Lignes", MontantTTC: "Montant TTC", TotalRegleReel: "Réglé", ResteReel: "Reste", EtatPaiement: "Paiement", CodeFacture: "Facture", DateFacture: "Date de facture", MontantRegleFacture: "Réglé", DateEcheancePaiement: "Échéance", EtatControleCommande: "Contrôle", ObsCmd: "Observation", AbrUnite: "Unité", QteCmdDetail: "Quantité", PUCmdDetail: "Prix unitaire", MontantLigne: "Montant", DateMvt: "Date", NomTypeMvt: "Type", QteMvtSigned: "Quantité", PUMvt: "Prix unitaire", MontantMvt: "Montant", OrigineMouvement: "Origine", Mois: "Mois", ConsoMensuelle: "Consommation", ValeurConsoMensuelle: "Valeur", StockActuel: "Stock", ConsoMoyMensuelle: "Consommation moyenne", CouvertureMois: "Couverture · mois", EtatCouverture: "État", StockArticle: "Stock courant", StockMouvements: "Stock des mouvements", Ecart: "Écart", EtatAuditStock: "Contrôle", MontantRegle: "Réglé", DateReglement: "Date", TotalRegle: "Réglé", Reste: "Reste", EtatReglement: "Paiement", CodeFactureFk: "Facture", MontantResteFacture: "Solde à régler" };
const SECTION_FIELDS = {lots:["NomArticle","NumeroLot","StockLot","Quantite","DateMvt","CodeCmd","DatePeremptionLot","QuantiteEntree","QuantiteSortie"],
  commandes: ["CodeCmd", "DateCmd", "NomArticle", "QteCmdDetail", "AbrUnite", "PUCmdDetail", "MontantLigne"],
  lignes: ["CodeArticleInterne", "NomArticle", "QteCmdDetail", "AbrUnite", "PUCmdDetail", "MontantLigne"],
  mouvements: ["DateMvt", "NomArticle", "CodeCmd", "NomTypeMvt", "QteMvtSigned", "PUMvt", "MontantMvt"],
  consommation: ["Mois", "ConsoMensuelle", "ValeurConsoMensuelle"],
  couverture: ["StockActuel", "ConsoMoyMensuelle", "CouvertureMois", "EtatCouverture"],
  controle: ["StockArticle", "StockMouvements", "Ecart", "EtatAuditStock"],
  reglements: ["DateReglement", "MontantRegle", "CodeFactureFk"],
  facture: ["CodeFacture", "DateEcheancePaiement", "MontantTTC", "TotalRegle", "Reste", "EtatReglement"],
};

const ORDER_FIELDS = ["DeviseCode","CodeCmd", "RefCmd", "TypeCmd", "StatutCmd", "DateCmd", "NomClientSaisi", "NbLignes", "MontantTTC", "TotalRegleReel", "ResteReel", "EtatPaiement", "CodeFacture", "DateEcheancePaiement", "EtatControleCommande", "NomComplet", "ObsCmd"];

function display(field, value, row={}) {
  if (field === "ValeurConsoMensuelle" || field === "MontantsParDevise") return formatConsumptionMoney(row);
  if (/^(PU|PV|Valeur|Montant|Marge|TotalRegle|Reste)/.test(field)) return formatCurrency(value,row.DeviseCode);
  if (value == null || value === "") return "—";
  if (field === "Mois") return formatDate(value, {withTime:false});
  if (/^Date/.test(field)) return formatDate(value);
  if (/^(Qte|PU|PV|Valeur|Montant|Marge|Stock|Conso|CouvertureMois|Ecart|Total|Reste|Nb)/.test(field)) return formatNumber(value);
  if (typeof value === "boolean") return value ? "Oui" : "Non";
  return String(value);
}
function StatusValue({ field, value }) {
  const label = String(value);
  const tones = { "Rupture":"danger", "Périmé":"danger", "Périmés":"danger", "En retard":"danger", "Stock faible":"warning", "Faible":"warning", "En attente":"warning", "Partiel":"warning", "Partiellement réglée":"warning", "À régler":"warning", "Non facturée":"warning", "Disponible":"success", "Normal":"success", "Cohérent":"success", "Soldée":"success", "Réglée":"success", "Validée":"success", "En cours":"info", "Entrée":"info", "Sortie":"neutral" };
  return <span className={"erp-status is-" + (tones[label] || "neutral")}>{display(field,value)}</span>;
}
export function useRead(url,externalVersion=0) {
  const [version, setVersion] = useState(0);
  const source = url?.split("?")[0] || null;
  const [state, setState] = useState({ source, loading: Boolean(url), payload: null });
  useEffect(() => {
    if (!url) { setState({ source:null, loading: false, payload: null }); return; }
    const controller = new AbortController();
    setState((current) => ({ source, payload:current.source === source ? current.payload : null, loading:true }));
    requestJson(url, { requiresAuth: true, signal: controller.signal }).then((payload) => {
      if (!controller.signal.aborted) setState({ source, loading: false, payload });
    });
    return () => controller.abort();
  }, [url, version, externalVersion]);
  return { ...state, payload:state.source === source ? state.payload : null, retry: () => setVersion((value) => value + 1) };
}
function ErrorState({ payload, retry }) {
  return <div className="consult-state" role="alert"><p>{payload?.status === 403 ? "Accès refusé." : payload?.status === 404 ? "Fiche introuvable." : "Le chargement a échoué."}</p><button type="button" onClick={retry}>Réessayer</button></div>;
}

function parseFilters(value) { try { return typeof value === "string" ? JSON.parse(value || "{}") : value || {}; } catch { return {}; } }
function compactFilters(filters) { return Object.fromEntries(Object.entries(filters).filter(([,value]) => String(value).trim()).map(([key,value]) => [key,String(value).trim()])); }
export function ResultTable({ remote, query, onQueryChange, fields, open, kind = null, exportPath = null, onSelectionChange, selectionResetKey=0, onReady }) {
  const data = remote.payload;
  const available = data?.meta?.columns || Object.keys(data?.data?.[0] || {});
  const types = data?.meta?.columnTypes || {};
  const schemaKnown = Array.isArray(data?.meta?.columns) || Boolean(data?.data?.length);
  const moneyFields=fields.some(field=>/^(PU|PV|Valeur|Montant|Marge|TotalRegle|Reste)/.test(field));
  const wanted=moneyFields&&!fields.includes("DeviseCode")?[...fields,"DeviseCode"]:fields;
  const shown = schemaKnown ? wanted.filter((field) => available.includes(field)) : wanted;
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
  useEffect(() => { if (!remote.loading && data) onReady?.(); },[remote.loading,data,onReady]);
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
    const timestamp = /^timestamp/.test(sqlType) && field !== "Mois";
    const label = FIELD_LABELS[field] || field;
    return { key:field,label:timestamp && label === "Date" ? "Date et heure" : label,width:/^Date/.test(field) ? 180 : undefined,align:numeric ? "right" : "left",filterType:numeric ? "number" : /^(date|timestamp)/.test(sqlType) ? "date" : sqlType === "boolean" ? "boolean" : "text",
      render:(row) => {
        if (["NomArticle","CodeArticleInterne"].includes(field) && (row.ID_Article || row.ID_ArticleFk)) return <button type="button" className="erp-object-link" onClick={(event) => { event.stopPropagation(); open("produit",row.ID_Article || row.ID_ArticleFk,row.NomArticle); }}>{display(field,row[field],row)}</button>;
        if (field === "CodeCmd" && (row.ID_Commande || row.ID_CmdFk || row.ID_cmdFk)) return <button type="button" className="erp-object-link" onClick={(event) => { event.stopPropagation(); open("commande",row.ID_Commande || row.ID_CmdFk || row.ID_cmdFk,row.CodeCmd); }}>{display(field,row[field],row)}</button>;
        if (/^(Etat|Statut)/.test(field) && row[field] != null && row[field] !== "") return <StatusValue field={field} value={row[field]} />;
        return display(field,row[field],row);
      }, renderText:(row) => display(field,row[field],row) };
  });
  if (kind) columns.push({ key:"consultation",label:"Actions",sortable:false,searchable:false,renderText:()=>"",render:(row) => {
    const id = kind === "produit" ? row.ID_Article || row.ID_ArticleFk : row.ID_Commande || row.ID_CmdFk || row.ID_cmdFk;
    return id ? <button type="button" className="erp-object-link" onClick={(event) => { event.stopPropagation(); open(kind,id,row.NomArticle || row.CodeCmd || row.CodeFacture); }}>Consulter</button> : "—";
  }});
  const toolbar = <DataTableToolbar search={search} setSearch={setSearch} onApply={apply} onReset={reset} pending={pending} take={Number(query.take || 25)} onTake={(take) => onQueryChange({take,skip:0})} filtersOpen={filtersOpen} toggleFilters={() => setFiltersOpen(value => !value)} activeFilters={activeFilters} density={density} toggleDensity={() => setDensity(value => value === "airy" ? "compact" : "airy")} columnsOpen={columnsOpen} columnsButtonRef={columnsAnchorRef} toggleColumns={() => setColumnsOpen(value => !value)} loading={remote.loading} exportFile={exportPath ? exportFile : null} exporting={exporting} exportDisabled={!data?.success || !data?.meta?.filteredCount} error={exportError} />;
  return <div className="erp-results" data-density={density} aria-busy={remote.loading}>
    {data && !data.success ? <ErrorState payload={data} retry={remote.retry} /> : null}
    <SimpleTable columns={columns} defaultVisibleColumns={columns.filter(column => column.key !== "DeviseCode").map(column => column.key)} rows={data?.success ? data.data || [] : []} toolbar={toolbar} columnsPanelOpen={columnsOpen} columnsAnchorRef={columnsAnchorRef} onColumnsPanelClose={()=>setColumnsOpen(false)} onVisibleColumnsChange={setVisibleColumns} filtersVisible={filtersOpen} columnFilters={filters} onColumnFilterChange={(key,value) => setFilters(current => ({...current,[key]:value}))} onApplyColumnFilters={apply} showControls serverMeta={data?.meta} serverState={query} onServerChange={onQueryChange} enableSelection={Boolean(onSelectionChange)} onSelectionChange={onSelectionChange} selectionResetKey={selectionResetKey} loading={remote.loading} getRowId={(row,index) => ([row.ID_LotArticle || row.ID_Mvt || row.IdReglement || row.ID_Commande || row.ID_CmdFk || row.ID_Article || "",row.ID_ArticleFk || "",row.Mois || ""].some(Boolean) ? [row.ID_LotArticle || row.ID_Mvt || row.IdReglement || row.ID_Commande || row.ID_CmdFk || row.ID_Article || "",row.ID_ArticleFk || "",row.Mois || ""].join(":") : "row:"+index)} />
  </div>;
}

function ObjectContent({ entry, update, open, openFolder }) {
  const {version}=useFollowupFolders();
  const base = "/api/logistique/consultations/" + entry.kind + "/" + entry.id;
  const header = useRead(base,version);
  const queryString = new URLSearchParams(entry.query).toString();
  const section = entry.section || "identite";
  const tabPrefix = "consultation-"+entry.kind+"-"+entry.id;
  const details = useRead(section === "identite" ? null : base + "/" + section + "?" + queryString);
  const record = header.payload?.data?.record;
  if (header.loading && !record) return <p className="consult-loading" role="status">Chargement…</p>;
  if (!header.payload?.success) return <ErrorState payload={header.payload} retry={header.retry} />;
  return <>
    <div className="consult-object-overview">{entry.kind === "produit" ? <ProductHeading record={record}/> : <div className="consult-record-heading"><h3>{record.CodeCmd || "Bon de stock"}</h3><span>{record.StatutCmd || ""}</span></div>}
    <RecordFolderLinks data={header.payload.data.dossiers} recordId={entry.id} objectType={entry.kind === "produit"?"article":"bon"} hasInvoice={entry.kind==="commande" && Boolean(record.CodeFacture?.trim())} onOpen={openFolder}/></div>
    <ConsultationTabs tabs={header.payload.data.sections.map(key=>({key,label:LABELS[key] || key,icon:({identite:"box",lots:"box",commandes:"receipt",lignes:"list",mouvements:"movements",consommation:"chart",couverture:"clock",controle:"check-circle",reglements:"wallet",facture:"document"})[key] || "list"}))} value={section} onChange={key=>update({section:key,query:{take:25,skip:0}})} label={entry.kind==="produit"?"Rubriques du produit":"Rubriques du bon de stock"} idPrefix={tabPrefix}/>
    {header.payload.data.sections.map(key=><section key={key} className="consultation-tabpanel" role="tabpanel" id={tabPrefix+"-panel-"+key} aria-labelledby={tabPrefix+"-tab-"+key} tabIndex={key===section?0:-1} hidden={key!==section}>
    {key===section?<>
    {section==="lots"&&entry.kind==="produit"?<p className="consult-note">Stock identifié par lot : {formatNumber(record.StockVentileLots)} · Stock sans lot : {formatNumber(record.StockSansLot)}{record.Unite?" "+record.Unite:""}</p>:null}
    {section === "identite" ? entry.kind === "produit" ? <ProductOverview record={record}/> : <><dl className="consult-fields">{ORDER_FIELDS.map((field) => <div key={field}><dt>{FIELD_LABELS[field]}</dt><dd>{display(field, record[field],record)}</dd></div>)}</dl></> :
      <ResultTable key={section} remote={details} query={entry.query} onQueryChange={(patch) => update({ query: { ...entry.query, ...patch } })} fields={SECTION_FIELDS[section] || []} open={open} />}
    </>:null}
    </section>)}
  </>;
}
function IndicatorContent({ entry, update, open, inline = false, onReady }) {
  const remote = useRead("/api/logistique/indicateurs/" + entry.id + "?" + new URLSearchParams(entry.query));
  const indicator = remote.payload?.meta?.indicator;
  const kind = indicator?.kind || (PRODUCT_INDICATORS.has(entry.id) ? "produit" : "commande");
  const isInvoice = entry.id.startsWith("factures") || ["montantTotalFacture", "montantTotalRegle", "montantRestant"].includes(entry.id);
  const fields = kind === "produit" ? ["CodeArticleInterne", "NomArticle", "QteArticle", "QteMinArticle", "EtatStock", "StockArticle", "StockMouvements", "Ecart", "EtatAuditStock", "CouvertureMois"] : isInvoice ? ["CodeFacture", "CodeCmd", "DateFacture", "DateEcheancePaiement", "NomClientSaisi", "MontantTTC", "MontantRegleFacture", "TotalRegle", "MontantResteFacture", "Reste"] : ["CodeCmd", "DateCmd", "TypeCmd", "StatutCmd", "NomClientSaisi", "NbLignes", "MontantTTC", "EtatPaiement"];
  return <>{!inline && indicator ? <div className="consult-indicator"><strong>{indicator.amountsByCurrency?.length ? formatCurrencyGroups(indicator.amountsByCurrency) : formatNumber(indicator.value)}{indicator.unit ? " " + indicator.unit : ""}</strong><span>{indicator.label}</span></div> : null}
    <ResultTable remote={remote} query={entry.query} onQueryChange={(patch) => update({ query: { ...entry.query, ...patch } })} fields={fields} open={open} showControls={inline} kind={kind} onReady={onReady} exportPath={"/api/logistique/indicateurs/" + entry.id + "/export.xlsx"} />
  </>;
}

export function IndicatorDetails({ metricKey, criteria, onReady }) {
  const { openProduct, openOrder } = useConsultations();
  const [query, setQuery] = useState(() => ({ ...criteria, populationQ: criteria.q || "", q: "", timeZone:Intl.DateTimeFormat().resolvedOptions().timeZone, take: 50, skip: 0 }));
  const entry = { id: metricKey, query };
  const open = (kind, id, label) => kind === "produit" ? openProduct({ ID_Article: id, NomArticle: label }) : openOrder({ ID_Commande: id, CodeCmd: label });
  return <IndicatorContent entry={entry} update={(patch) => setQuery(patch.query)} open={open} inline onReady={onReady} />;
}

function Dialog({ children, title, onClose, onBack }) {
  return <DrawerDialog id="consultation-dialog" titleId="consult-title" title={title} onClose={onClose} onBack={onBack} className="consultation-dialog" headerClassName="consult-header" bodyClassName="consult-content" closeClassName="consult-close" closeLabel="Fermer la consultation" storageKey="sauverndeko.consultation.width">{children}</DrawerDialog>;
}

export function ConsultationProvider({ children }) {
  const navigate=useNavigate();
  const openFolder=(key)=>{setHistory([]);navigate("/logistique?onglet=dossiers&dossier="+encodeURIComponent(key));};
  const { user, isAuthenticated } = useAuth();
  const [history, setHistory] = useState([]);
  useEffect(() => { setHistory([]); }, [user?.IdUser, user?.IdEntiteFk, user?.permissions?.canAccessAdmin, isAuthenticated, accessSignature(user)]);
  const open = useCallback((kind, id, label = "", criteria = {}, section = "identite") => {
    if (!user?.permissions?.canAccessAdmin || !moduleRights(user,"logistique").canRead || !id || !["produit", "commande", "indicateur"].includes(kind)) return;
    setHistory((current) => [...current.slice(-7), { kind, id, label, section, query: { ...criteria, take: 25, skip: 0 } }]);
  }, [user?.permissions?.canAccessAdmin, accessSignature(user)]);
  const update = (patch) => setHistory((current) => current.map((item, index) => index === current.length - 1 ? { ...item, ...patch } : item));
  const entry = history[history.length - 1];
  return <Context.Provider value={{ openProductLots:(row)=>open("produit",row.ID_Article,row.NomArticle,{},"lots"), openProduct: (row) => open("produit", typeof row === "object" ? row.ID_Article || row.ID_ArticleFk : row, row?.NomArticle || ""), openOrder: (row) => open("commande", typeof row === "object" ? row.ID_Commande || row.ID_CmdFk || row.ID_cmdFk : row, row?.CodeCmd || ""), openFolder, openMetric: (key, criteria = {}, label = "") => open("indicateur", key, label, criteria) }}>{children}
    {entry && isAuthenticated ? <Dialog title={entry.kind === "produit" ? "Produit 360" + (entry.label ? " · " + entry.label : "") : entry.kind === "commande" ? "Bon de stock 360" + (entry.label ? " · " + entry.label : "") : entry.label || "Détail de l’indicateur"} onClose={() => setHistory([])} onBack={history.length > 1 ? () => setHistory((current) => current.slice(0, -1)) : null}>
      {entry.kind === "indicateur" ? <IndicatorContent key={entry.kind + entry.id} entry={entry} update={update} open={open} /> : <ObjectContent key={entry.kind + entry.id} entry={entry} update={update} open={open} openFolder={openFolder} />}
    </Dialog> : null}
  </Context.Provider>;
}
export function useConsultations() {
  const context = useContext(Context);
  if (!context) throw new Error("ConsultationProvider manquant.");
  return context;
}
