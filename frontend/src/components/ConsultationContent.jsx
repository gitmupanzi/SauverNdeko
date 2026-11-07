import StocksDepots from "../pages/logistique/StocksDepots";
import BusinessDocuments from "./BusinessDocuments";
import CreditNotes from "../pages/logistique/CreditNotes";
import { formatConsumptionMoney, formatCurrencyGroups } from "../utils/money";
import { moduleRights } from "../services/moduleAccess";
import {isStockOrder,stockDocumentKind,canCreateStockInvoice} from "../utils/stockDocumentTypes";
import { RecordFolderLinks } from "./FollowupFolderWidgets";
import { useFollowupFolders } from "../contexts/FollowupFoldersContext";
import ProductOverview, { ProductHeading } from "./ProductOverview";
import OrderOverview, { OrderHeading, OrderBillingHeading, OrderControl, ORDER_SECTION_FIELDS, hasOrderInvoice, orderConsultationTabs, orderReadSection } from "./OrderOverview";
import AppIcon from "./AppIcon";
import ActionButton from "./ActionButton";
import OrderReturnHistory from "./OrderReturnHistory";
import InvoiceEditor from "../pages/logistique/InvoiceEditor";
import BonReturnEditor from "../pages/logistique/BonReturnEditor";
import DataTableToolbar from "./DataTableToolbar";
import { useEffect, useLayoutEffect, useRef, useState } from "react";
import ConsultationTabs from "./ConsultationTabs";
import { useAuth } from "../contexts/AuthContext";
import { downloadApiFile } from "../services/api";
import { SimpleTable, formatCurrency, formatNumber, formatDate } from "../pages/logistique/logistiqueShared";
import "./Consultation.css";

import { useRead } from "./ConsultationProvider";
const PRODUCT_INDICATORS = new Set(["articles","articlesCategorie","alertesStock","ruptures","auditTotal","auditCoherents","auditEcarts","coherenceRate","couvertureCritique","peremptionProche","articlesPerimes"]);
const ARTICLE_WEIGHT_INDICATORS = new Set(["articles", "articlesCategorie"]);
const WEIGHT_FIELD_LABELS = { PoidsUnitaire: "Poids unitaire", PoidsStockKg: "Poids du stock (kg)" };
const LABELS = {stocks:"Stocks par dépôt",lots:"Lots", identite: "Synthèse", commandes: "Bons de stock", lignes: "Lignes", mouvements: "Mouvements", consommation: "Consommation", couverture: "Couverture", controle: "Contrôle", reglements: "Règlements", facture: "Facture" };
const FIELD_LABELS = {TauxTVA:"TVA (%)",MontantHTFacture:"Montant HT",MontantTVA:"TVA",EtatPeremptionLot:"Conservation",MotifDerogationPeremption:"Motif de dérogation",DateDerogationPeremption:"Dérogation du",MontantFacture:"Montant facturé",DeviseCode:"Devise",MontantsParDevise:"Valeurs par devise",NumeroLot:"N° de lot",StockLot:"Stock du lot",Quantite:"Quantité",QuantiteSignee:"Quantité signée",DatePeremptionLot:"Péremption du lot",QuantiteEntree:"Entrées",QuantiteSortie:"Sorties", CodeArticleInterne: "Code", NomArticle: "Produit", RefArticle: "Référence", TypeArticle: "Type", CategorieArticle: "Catégorie", Unite: "Unité", QteArticle: "Stock actuel", QteMinArticle: "Seuil", QteACommander: "À commander", EtatStock: "État du stock", PUArticle: "Prix d’achat", PVArticle: "Prix de vente", ValeurStockAchat: "Valeur catalogue (achat)", MargeUnitaire: "Marge unitaire", DatePeremptionArticle: "Péremption", EtatPeremption: "État de péremption", NomComplet: "Responsable", ObsArticle: "Observation", CodeCmd: "Bon de stock", RefCmd: "Référence", TypeCmd: "Type", StatutCmd: "Statut", DateCmd: "Date", NomClientSaisi: "Tiers", NbLignes: "Lignes", MontantTTC: "Montant TTC", TotalRegleReel: "Réglé", ResteReel: "Reste", EtatPaiement: "Paiement", CodeFacture: "Facture", DateFacture: "Date de facture", MontantRegleFacture: "Réglé", DateEcheancePaiement: "Échéance", EtatControleCommande: "Contrôle", ObsCmd: "Observation", AbrUnite: "Unité", QteCmdDetail: "Quantité", PUCmdDetail: "Prix unitaire", MontantLigne: "Montant", DateMvt: "Date", NomTypeMvt: "Type", QteMvtSigned: "Quantité", PUMvt: "Prix unitaire", MontantMvt: "Montant", OrigineMouvement: "Origine", Mois: "Mois", ConsoMensuelle: "Consommation", ValeurConsoMensuelle: "Valeur", StockActuel: "Stock", ConsoMoyMensuelle: "Consommation moyenne", CouvertureMois: "Couverture · mois", EtatCouverture: "État", StockArticle: "Stock courant", StockMouvements: "Stock des mouvements", Ecart: "Écart", EtatAuditStock: "Contrôle", MontantRegle: "Réglé", DateReglement: "Date", TotalRegle: "Réglé", Reste: "Reste", EtatReglement: "Paiement", CodeFactureFk: "Facture", MontantResteFacture: "Solde à régler" };
const SECTION_FIELDS = {lots:["NomArticle","NumeroLot","StockLot","Quantite","DateMvt","CodeCmd","DatePeremptionLot","EtatPeremptionLot","QuantiteEntree","QuantiteSortie","MotifDerogationPeremption","DateDerogationPeremption"],
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
  if (field === "TauxTVA") return value==null?"—":formatNumber(value)+" %";
  if (field === "ValeurConsoMensuelle" || field === "MontantsParDevise") return formatConsumptionMoney(row);
  if (/^(PU|PV|Valeur|Montant|Marge|TotalRegle|Reste)/.test(field)) return formatCurrency(value,row.DeviseCode);
  if (value == null || value === "") return "—";
  if (field === "PoidsUnitaire") return [formatNumber(value), row.UnitePoids].filter(Boolean).join(" ");
  if (field === "PoidsStockKg") return formatNumber(value);
  if (field === "Mois") return formatDate(value, {withTime:false});
  if (field === "DatePeremptionLot") return formatDate(value,{withTime:false});
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

function ErrorState({ payload, retry }) {
  return <div className="consult-state" role="alert"><p>{payload?.status === 403 ? "Accès refusé." : payload?.status === 404 ? "Fiche introuvable." : "Le chargement a échoué."}</p><button type="button" onClick={retry}>Réessayer</button></div>;
}

function parseFilters(value) { try { return typeof value === "string" ? JSON.parse(value || "{}") : value || {}; } catch { return {}; } }
function compactFilters(filters) { return Object.fromEntries(Object.entries(filters).filter(([,value]) => String(value).trim()).map(([key,value]) => [key,String(value).trim()])); }
export function ResultTable({ remote, query, onQueryChange, fields, open, kind = null, exportPath = null, onSelectionChange, selectionResetKey=0, onReady }) {
  const {user}=useAuth();
  const canExport=user?.permissions?.canExportData!==false&&moduleRights(user,"logistique").canExport===true;
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
    if(!canExport||!exportPath||remote.loading||pending||exporting)return;
    const controller = new AbortController();
    exportRequest.current?.abort(); exportRequest.current = controller;
    setExporting(true); setExportError("");
    const keys = (visibleColumns.length ? visibleColumns : shown).filter(key => shown.includes(key));
    const exportColumns = keys.flatMap(key =>
      key === "PoidsUnitaire" && available.includes("UnitePoids") ? [key, "UnitePoids"] : [key]
    );
    const params = new URLSearchParams({ ...query, timeZone:Intl.DateTimeFormat().resolvedOptions().timeZone, columns:JSON.stringify(exportColumns) });
    params.delete("take"); params.delete("skip");
    try { await downloadApiFile(exportPath + "?" + params,{ signal:controller.signal }); }
    catch(error) { if (!controller.signal.aborted && error.name !== "AbortError") setExportError(error.message || "L’export a échoué."); }
    finally { if (!controller.signal.aborted) setExporting(false); }
  }
  const columns = shown.map((field) => {
    const sqlType = types[field] || "";
    const numeric = /^(numeric|decimal|integer|bigint|smallint|real|double precision)$/.test(sqlType);
    const timestamp = /^timestamp/.test(sqlType) && field !== "Mois";
    const label = WEIGHT_FIELD_LABELS[field] || FIELD_LABELS[field] || field;
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
  const toolbar = <DataTableToolbar search={search} setSearch={setSearch} onApply={apply} onReset={reset} pending={pending} take={Number(query.take || 25)} onTake={(take) => onQueryChange({take,skip:0})} filtersOpen={filtersOpen} toggleFilters={() => setFiltersOpen(value => !value)} activeFilters={activeFilters} density={density} toggleDensity={() => setDensity(value => value === "airy" ? "compact" : "airy")} columnsOpen={columnsOpen} columnsButtonRef={columnsAnchorRef} toggleColumns={() => setColumnsOpen(value => !value)} loading={remote.loading} exportFile={exportPath&&canExport ? exportFile : null} exporting={exporting} exportDisabled={!data?.success || !data?.meta?.filteredCount} error={exportError} />;
  return <div className="erp-results" data-density={density} aria-busy={remote.loading}>
    {data && !data.success ? <ErrorState payload={data} retry={remote.retry} /> : null}
    <SimpleTable columns={fields.includes("QteCmdDetail")?[{key:"__ordre",label:"N°",width:60,sortable:false,render:(_row,index)=>Number(query.skip||0)+index+1},...columns]:columns} defaultVisibleColumns={[...(fields.includes("QteCmdDetail")?["__ordre"]:[]),...columns.filter(column => column.key !== "DeviseCode").map(column => column.key)]} rows={data?.success ? data.data || [] : []} toolbar={toolbar} columnsPanelOpen={columnsOpen} columnsAnchorRef={columnsAnchorRef} onColumnsPanelClose={()=>setColumnsOpen(false)} onVisibleColumnsChange={setVisibleColumns} filtersVisible={filtersOpen} columnFilters={filters} onColumnFilterChange={(key,value) => setFilters(current => ({...current,[key]:value}))} onApplyColumnFilters={apply} showControls serverMeta={data?.meta} serverState={query} onServerChange={onQueryChange} enableSelection={Boolean(onSelectionChange)} onSelectionChange={onSelectionChange} selectionResetKey={selectionResetKey} loading={remote.loading} getRowId={(row,index) => ([row.ID_LotArticle || row.ID_Mvt || row.IdReglement || row.ID_Commande || row.ID_CmdFk || row.ID_Article || "",row.ID_ArticleFk || "",row.Mois || ""].some(Boolean) ? [row.ID_LotArticle || row.ID_Mvt || row.IdReglement || row.ID_Commande || row.ID_CmdFk || row.ID_Article || "",row.ID_ArticleFk || "",row.Mois || ""].join(":") : "row:"+index)} />
  </div>;
}

function ProductObjectContent({ entry, update, open, openFolder }) {
  const {version}=useFollowupFolders();
  const base = "/api/logistique/consultations/" + entry.kind + "/" + entry.id;
  const header = useRead(base,version);
  const queryString = new URLSearchParams(entry.query).toString();
  const section = entry.section || "identite";
  const tabPrefix = "consultation-"+entry.kind+"-"+entry.id;
  const details = useRead(section === "identite"||section === "stocks" ? null : base + "/" + section + "?" + queryString);
  const record = header.payload?.data?.record;
  if (header.loading && !record) return <p className="consult-loading" role="status">Chargement…</p>;
  if (!header.payload?.success) return <ErrorState payload={header.payload} retry={header.retry} />;
  return <>
    <div className="consult-object-overview">{entry.kind === "produit" ? <ProductHeading record={record}/> : <div className="consult-record-heading"><h3>{record.CodeCmd || "Bon de stock"}</h3><span>{record.StatutCmd || ""}</span></div>}
    <RecordFolderLinks data={header.payload.data.dossiers} recordId={entry.id} objectType={entry.kind === "produit"?"article":"bon"} hasInvoice={entry.kind==="commande" && Boolean(record.CodeFacture?.trim())} onOpen={openFolder}/></div>
    <ConsultationTabs tabs={[...new Set([...header.payload.data.sections,...(entry.kind==="produit"?["stocks"]:[])])].map(key=>({key,label:LABELS[key] || key,icon:({identite:"box",lots:"box",commandes:"receipt",lignes:"list",mouvements:"movements",consommation:"chart",couverture:"clock",controle:"check-circle",reglements:"wallet",facture:"document"})[key] || "list"}))} value={section} onChange={key=>update({section:key,query:{...entry.query,take:25,skip:0}})} label={entry.kind==="produit"?"Rubriques du produit":"Rubriques du bon de stock"} idPrefix={tabPrefix}/>
    {[...new Set([...header.payload.data.sections,...(entry.kind==="produit"?["stocks"]:[])])].map(key=><section key={key} className="consultation-tabpanel" role="tabpanel" id={tabPrefix+"-panel-"+key} aria-labelledby={tabPrefix+"-tab-"+key} tabIndex={key===section?0:-1} hidden={key!==section}>
    {key===section?<>
    {section==="lots"&&entry.kind==="produit"?<p className="consult-note">{entry.query?.depotId?"Lots du dépôt sélectionné.":<>Stock identifié par lot : {formatNumber(record.StockVentileLots)} · Stock sans lot : {formatNumber(record.StockSansLot)}{record.Unite?" "+record.Unite:""}</>}</p>:null}
    {section === "stocks"?<StocksDepots embedded articleId={entry.id} selectedDepotId={entry.query?.depotId||""}/>:section === "identite" ? entry.kind === "produit" ? <ProductOverview record={record}/> : <><dl className="consult-fields">{ORDER_FIELDS.map((field) => <div key={field}><dt>{FIELD_LABELS[field]}</dt><dd>{display(field, record[field],record)}</dd></div>)}</dl></> :
      <ResultTable key={section} remote={details} query={entry.query} onQueryChange={(patch) => update({ query: { ...entry.query, ...patch } })} fields={SECTION_FIELDS[section] || []} open={open} />}
    </>:null}
    </section>)}
  </>;
}

function OrderObjectContent({entry,update,open,openFolder}){
  const {version,refresh}=useFollowupFolders();
  const {user}=useAuth();
  const [editor,setEditor]=useState(null),[workflowVersion,setWorkflowVersion]=useState(0);
  const canWrite=user?.permissions?.canWriteData===true&&moduleRights(user,"logistique").canManage;
  useEffect(()=>{setEditor(null);},[entry.id]);
  const root=useRef(null),restored=useRef(false);
  const base="/api/logistique/consultations/commande/"+entry.id;
  const header=useRead(base,version+":"+workflowVersion);
  const record=header.payload?.data?.record;
  const sections=header.payload?.data?.sections || [];
  const features=header.payload?.meta?.features||{},returnContext=header.payload?.meta?.returnContext||{};
  const order=isStockOrder(record),outgoing=stockDocumentKind(record)==="sortie";
  const tabs=orderConsultationTabs(sections,{returns:features.returns===true&&outgoing&&!returnContext.isReturn,stockOrder:order});
  const requested=["facture","reglements"].includes(entry.section)?"facturation":entry.section || "identite";
  const section=tabs.some(tab=>tab.key===requested)?requested:"identite";
  const invoiceTabs=[{key:"facture",label:"Facture",icon:"document"},{key:"reglements",label:"Règlements",icon:"wallet"}].filter(tab=>sections.includes(tab.key));
  const preferredInvoice=["facture","reglements"].includes(entry.section)?entry.section:entry.invoiceSection;
  const invoiceSection=invoiceTabs.some(tab=>tab.key===preferredInvoice)?preferredInvoice:invoiceTabs[0]?.key;
  const dataSection=orderReadSection(section,invoiceSection,record,sections);
  const queryKey=section==="facturation"?section+"."+invoiceSection:section;
  const query=entry.query;
  const details=useRead(dataSection?base+"/"+dataSection+"?"+new URLSearchParams(query):null,workflowVersion);
  const returns=useRead(section==="retours"?"/api/logistique/commandes/"+entry.id+"/retours":null,version+":"+workflowVersion);
  const prefix="consultation-commande-"+entry.id;
  function restoreContext(){
    if(restored.current || !record || (dataSection && details.loading))return;
    const body=root.current?.closest(".consult-content");
    if(!body)return;
    const focusIndex=entry.returnFocusIndex;
    if(Number.isInteger(focusIndex))root.current.querySelectorAll("button.erp-object-link")[focusIndex]?.focus({preventScroll:true});
    body.scrollTop=entry.scrollTop || 0;
    restored.current=true;
  }
  useLayoutEffect(()=>{restoreContext();},[record,details.loading]);
  function changeSection(key,preferred){
    if(!tabs.some(tab=>tab.key===key))return;
    const invoice=preferred || invoiceSection;
    const nextKey=key==="facturation"?key+"."+invoice:key;
    if(nextKey===queryKey)return;
    const queries={...entry.sectionQueries,[queryKey]:query};
    update({section:key,invoiceSection:invoice,sectionQueries:queries,query:queries[nextKey] || {take:25,skip:0},scrollTop:0,returnFocusIndex:null});
  }
  function changeQuery(patch){
    const next={...query,...patch};
    update({query:next,sectionQueries:{...entry.sectionQueries,[queryKey]:next}});
  }
  function openRelated(kind,id,label){
    const body=root.current?.closest(".consult-content");
    const index=Array.from(root.current?.querySelectorAll("button.erp-object-link") || []).indexOf(document.activeElement);
    update({scrollTop:body?.scrollTop || 0,returnFocusIndex:index>=0?index:null});
    open(kind,id,label);
  }
  if(header.loading && !record)return <div className="commande360" aria-busy="true"><div className="commande360-placeholder" role="status"><p>Chargement du bon…</p><div aria-hidden="true"><span/><span/><span/></div></div></div>;
  if(!header.payload?.success)return <div className="commande360"><ErrorState payload={header.payload} retry={header.retry}/></div>;
  const invoiced=hasOrderInvoice(record);
  function workflowSaved(){setEditor(null);setWorkflowVersion(value=>value+1);refresh();}
  return <div ref={root} className="commande360">
    <div className="consult-object-overview commande360-heading"><OrderHeading record={record}/><RecordFolderLinks data={header.payload.data.dossiers} recordId={entry.id} objectType="bon" hasInvoice={invoiced} onOpen={openFolder}/></div>
    <div className="commande360-workflow-actions">
      {returnContext.isReturn&&returnContext.originId?<ActionButton icon="receipt" onClick={()=>openRelated("commande",returnContext.originId,"Bon d’origine")}>Voir le bon d’origine</ActionButton>:null}
      {canWrite&&features.returns===true&&outgoing&&!returnContext.isReturn?<ActionButton icon="stock-in" onClick={()=>setEditor("retour")}>Restituer des articles</ActionButton>:null}
      {canWrite&&features.invoices===true&&canCreateStockInvoice(record)&&!returnContext.isReturn?<ActionButton icon="document" onClick={()=>setEditor("facture")}>{invoiced?"Consulter la facture":"Créer la facture"}</ActionButton>:null}
    </div>
    {!order&&record.AvoirAEtablir===true?<p className="commande360-return-notice"><AppIcon name="alert"/>Avoir à établir · {formatCurrency(record.MontantAvoirAEtablir,record.DeviseCode)}. La facture émise reste conservée.</p>:null}
    <ConsultationTabs tabs={tabs} value={section} onChange={changeSection} label="Rubriques du bon de stock" idPrefix={prefix}/>
    {tabs.map(tab=><section key={tab.key} className="commande360-tabpanel consultation-tabpanel" role="tabpanel" id={prefix+"-panel-"+tab.key} aria-labelledby={prefix+"-tab-"+tab.key} tabIndex={tab.key===section?0:-1} hidden={tab.key!==section}>
      {tab.key===section?<>
        {section==="identite"?<><OrderOverview record={record} onSection={changeSection}/><BusinessDocuments kind="bon" objectId={entry.id} types={order?["commande"]:outgoing?["sortie","livraison"]:stockDocumentKind(record)==="entree"?["entree"]:[]}/></>:section==="retours"?<OrderReturnHistory remote={returns} onOpen={openRelated} onReturn={()=>setEditor("retour")} canWrite={canWrite}/>:section==="controle"?<OrderControl record={record} onSection={changeSection}/>:section==="facturation"?<>
          <OrderBillingHeading record={record}/>
          {invoiced?<><BusinessDocuments kind="facture" objectId={entry.id} types={["facture"]}/><CreditNotes commandId={entry.id} refreshKey={workflowVersion} onChanged={()=>{setWorkflowVersion(v=>v+1);refresh();}}/></>:null}
          {invoiced?<><div className="commande360-invoice-tabs"><ConsultationTabs tabs={invoiceTabs} value={invoiceSection} onChange={key=>changeSection("facturation",key)} label="Facture et règlements du bon" idPrefix={prefix+"-billing"}/></div>
            {invoiceTabs.map(item=><section key={item.key} role="tabpanel" id={prefix+"-billing-panel-"+item.key} aria-labelledby={prefix+"-billing-tab-"+item.key} tabIndex={item.key===invoiceSection?0:-1} hidden={item.key!==invoiceSection}>{item.key===invoiceSection?<ResultTable key={dataSection} remote={details} query={query} onQueryChange={changeQuery} fields={ORDER_SECTION_FIELDS[dataSection] || []} open={openRelated} onReady={restoreContext}/>:null}</section>)}
          </>:null}
        </>:<ResultTable key={dataSection} remote={details} query={query} onQueryChange={changeQuery} fields={ORDER_SECTION_FIELDS[dataSection] || []} open={openRelated} onReady={restoreContext}/>}
      </>:null}
    </section>)}
    {editor==="facture"?<InvoiceEditor commandeId={entry.id} onClose={()=>setEditor(null)} onSaved={workflowSaved}/>:editor==="retour"?<BonReturnEditor commandeId={entry.id} onClose={()=>setEditor(null)} onSaved={workflowSaved}/>:null}
  </div>;
}
export function ObjectContent(props){
  return props.entry.kind==="commande"?<OrderObjectContent {...props}/>:<ProductObjectContent {...props}/>;
}

export function IndicatorContent({ entry, update, open, inline = false, onReady }) {
  const remote = useRead("/api/logistique/indicateurs/" + entry.id + "?" + new URLSearchParams(entry.query));
  const indicator = remote.payload?.meta?.indicator;
  const kind = indicator?.kind || (PRODUCT_INDICATORS.has(entry.id) ? "produit" : "commande");
  const isInvoice = entry.id.startsWith("factures") || ["montantTotalFacture", "montantTotalRegle", "montantRestant"].includes(entry.id);
  const fields = kind === "produit" ? ["CodeArticleInterne", "NomArticle", "QteArticle", "QteMinArticle", "EtatStock", "StockArticle", "StockMouvements", "Ecart", "EtatAuditStock", "CouvertureMois"] : isInvoice ? ["CodeFacture", "CodeCmd", "DateFacture", "DateEcheancePaiement", "NomClientSaisi", "MontantFacture", "MontantRegleFacture", "TotalRegle", "MontantResteFacture", "Reste"] : ["CodeCmd", "DateCmd", "TypeCmd", "StatutCmd", "NomClientSaisi", "NbLignes", "MontantTTC", "EtatPaiement"];
  if (ARTICLE_WEIGHT_INDICATORS.has(entry.id)) fields.splice(3, 0, "PoidsUnitaire", "PoidsStockKg");
  return <>{!inline && indicator ? <div className="consult-indicator"><strong>{indicator.amountsByCurrency?.length ? formatCurrencyGroups(indicator.amountsByCurrency) : formatNumber(indicator.value)}{indicator.unit ? " " + indicator.unit : ""}</strong><span>{indicator.label}</span></div> : null}
    <ResultTable remote={remote} query={entry.query} onQueryChange={(patch) => update({ query: { ...entry.query, ...patch } })} fields={fields} open={open} showControls={inline} kind={kind} onReady={onReady} exportPath={"/api/logistique/indicateurs/" + entry.id + "/export.xlsx"} />
  </>;
}
