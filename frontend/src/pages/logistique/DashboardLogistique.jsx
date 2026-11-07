import {useDepotScope} from "../../contexts/DepotScopeContext";
import CurrencySelect from "../../components/CurrencySelect";
import { formatCurrency } from "../../utils/money";
import AppIcon from "../../components/AppIcon";
import ActionButton from "../../components/ActionButton";
import SearchSelect from "../../components/SearchSelect";
import "./DashboardLogistique.css";
import { useCallback, useEffect, useId, useRef, useState } from "react";
import { Link } from "react-router-dom";
import { requestJson } from "../../services/api";
import { IndicatorDetails } from "../../components/ConsultationProvider";
import { formatNumber, formatDate } from "./logistiqueShared";

function periodDates(key) {
  const today = new Date();
  const year = today.getFullYear(), month = today.getMonth();
  const iso = date => [date.getFullYear(),String(date.getMonth()+1).padStart(2,"0"),String(date.getDate()).padStart(2,"0")].join("-");
  if (key === "all") return { dateFrom:"",dateTo:"" };
  const from = new Date(year,key === "year" ? 0 : key === "quarter" ? Math.floor(month/3)*3 : month,1);
  const to = new Date(year,key === "year" ? 12 : key === "quarter" ? Math.floor(month/3)*3+3 : month+1,0);
  return { dateFrom:iso(from),dateTo:iso(to) };
}
function describeStockWeight({ poidsStockKg, articlesSansPoids } = {}) {
  if (poidsStockKg === undefined) return null;

  const missing = Number(articlesSansPoids) || 0;
  const hasWeight = poidsStockKg !== null;
  const label = hasWeight ? formatNumber(poidsStockKg) + "\u00a0kg" : "Poids indisponible";
  const missingLabel = missing === 1
    ? "1 article en stock sans poids exploitable."
    : formatNumber(missing) + " articles en stock sans poids exploitable.";
  const description = hasWeight ? "Poids du stock : " + label + "." : "Poids du stock indisponible.";
  return { label, description: missing ? description + " " + missingLabel : description, partial: hasWeight && missing > 0 };
}

function IndicatorBlock({ id, title, icon, scope, children }) {
  const [open, setOpen] = useState(true);
  return <section className="erp-indicator-block" aria-labelledby={id + "-title"}>
    <header className="erp-block-header"><h2 id={id + "-title"}><span className="erp-block-icon"><AppIcon name={icon} size={18} /></span>{title}{scope ? <span className="erp-block-scope">{scope}</span> : null}</h2><button type="button" aria-expanded={open} aria-controls={id + "-body"} onClick={() => setOpen((current) => !current)} aria-label={(open ? "Masquer " : "Afficher ") + title} title={open ? "Masquer" : "Afficher"}><AppIcon name={open ? "chevron-up" : "chevron-down"} /></button></header>
    <div id={id + "-body"} className="erp-block-body" hidden={!open}>{children}</div>
  </section>;
}

export default function DashboardLogistique({
  refreshKey, references, hiddenDashboardBlocks, title = "Tableau de bord", canConfigurePresentation = false,
}) {
 const depotScope=useDepotScope();
  const hidden = new Set(Array.isArray(hiddenDashboardBlocks) ? hiddenDashboardBlocks : []);
  const showLeftColumn = !hidden.has("articles") || !hidden.has("commandes");
  const showRightColumn = !hidden.has("factures") || !hidden.has("alertes");
  const hasVisibleBlocks = showLeftColumn || showRightColumn;
  const selectPrefix = useId();
  const [periodMode, setPeriodMode] = useState("all");
  const [draft, setDraft] = useState({ q: "", dateFrom: "", dateTo: "", deviseId:"" });
  const [criteria, setCriteria] = useState({ q: "", dateFrom: "", dateTo: "", deviseId:"" });
  const [summary, setSummary] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [filterError, setFilterError] = useState("");
  const [version, setVersion] = useState(0);
  const [selectedMetric, setSelectedMetric] = useState(null);
  const detailPanel = useRef(null);
  const detailTitle = useRef(null);
  const detailReturn = useRef(null);
  const detailTrigger = useRef(null);
  const activeMetric = useRef(null), scrolledMetric = useRef(null), scrollFrame = useRef(null);
  const visibleMetric = selectedMetric && !hidden.has(selectedMetric.blockKey) ? selectedMetric : null;
  activeMetric.current = visibleMetric;
  function showMetric(blockKey, key, label, event, filters) {
    detailTrigger.current = event.currentTarget;
    setSelectedMetric({ blockKey, key, label, filters });
  }
  const closeMetric = useCallback(() => {
    cancelAnimationFrame(scrollFrame.current);
    activeMetric.current = null;
    scrolledMetric.current = null;
    setSelectedMetric(null);
    const origin = detailTrigger.current;
    detailTrigger.current = null;
    if (origin?.isConnected) { const target = origin.closest("[hidden]") ? origin.closest(".erp-indicator-block")?.querySelector(".erp-block-header > button") : origin; target?.scrollIntoView({ block:"center",behavior:"auto" }); target?.focus({preventScroll:true}); }
  }, []);
  useEffect(() => {
    if (selectedMetric && !visibleMetric) closeMetric();
  }, [selectedMetric, visibleMetric, closeMetric]);
  const detailsReady = useCallback(() => {
    const metric = visibleMetric;
    if (!metric || scrolledMetric.current === metric) return;
    scrolledMetric.current = metric;
    cancelAnimationFrame(scrollFrame.current);
    scrollFrame.current = requestAnimationFrame(() => {
      scrollFrame.current = requestAnimationFrame(() => {
        scrollFrame.current = null;
        const panel = detailPanel.current;
        if (activeMetric.current !== metric || !panel?.isConnected) return;
        const bounds = panel.getBoundingClientRect();
        if (!bounds.width || !bounds.height) return;
        panel.scrollIntoView({ block:"start", behavior:"auto" });
        detailReturn.current?.focus({ preventScroll:true });
      });
    });
  }, [visibleMetric]);
  useEffect(() => () => cancelAnimationFrame(scrollFrame.current), []);
  useEffect(() => {
    if (!hasVisibleBlocks) return;
    const controller = new AbortController();
    setLoading(true);
    setError("");
    const params = new URLSearchParams(Object.entries({...criteria,depotId:depotScope.depotId}).filter(([, value]) => value));
    requestJson("/api/logistique/synthese?" + params, { requiresAuth: true, signal: controller.signal }).then((payload) => {
      if (controller.signal.aborted) return;
      if (!payload?.success) { setSummary(null); setError("La synthèse n’a pas pu être chargée."); }
      else setSummary(payload.data);
      setLoading(false);
    });
    return () => controller.abort();
  }, [criteria, refreshKey, version, hasVisibleBlocks,depotScope.depotId]);
  function apply(event) {
    event.preventDefault();
    if (draft.dateFrom && draft.dateTo && draft.dateFrom > draft.dateTo) { setFilterError("La date de fin doit suivre la date de début."); return; }
    setFilterError("");
    setCriteria({ ...draft, q: draft.q.trim() });
  }
  const totals = summary?.totals || {};
  function metric(blockKey, key, label, icon = "bi-bar-chart", tone = "blue", suffix = "", options = {}) {
    const value = options.value !== undefined ? options.value : totals[key];
    const selected = visibleMetric?.blockKey === blockKey && visibleMetric.key === key
      && JSON.stringify(visibleMetric.filters) === JSON.stringify(options.filters || {});
    const displayValue=options.currency !== undefined ? formatCurrency(value,options.currency) : formatNumber(value)+(value != null ? suffix : "");
    const detailLabel=options.currency !== undefined ? label+" · "+(options.currency || "Devise non renseignée") : label;
    const stockWeight = describeStockWeight(options.stockWeight);
    const accessibleLabel = [detailLabel + " : " + displayValue + ".", stockWeight?.description, "Voir la liste"].filter(Boolean).join(" ");
    const open = (event) => showMetric(blockKey, key, detailLabel, event, options.filters || {});
    return <article key={options.rowKey || key} className={"erp-kpi is-" + tone}>
      <button type="button" className="erp-kpi-main" disabled={loading} aria-label={accessibleLabel} aria-expanded={selected} aria-controls="dashboard-indicator-details" onClick={open}>
        <span className="erp-kpi-icon"><AppIcon name={icon} size={17} /></span>
        <span className="erp-kpi-copy">
          <span className="erp-kpi-label" title={label}>{label}</span>
          {stockWeight ? <span className="erp-kpi-weight" title={stockWeight.description}>
            {stockWeight.label}{stockWeight.partial ? " · Partiel" : ""}
          </span> : null}
        </span>
        <strong>{displayValue}</strong>
        <AppIcon name="chevron-right" size={12} className="erp-kpi-chevron" />
      </button>
    </article>;
  }
  function moneyMetrics(blockKey,key,label,icon,tone) {
    const groups=summary?.amountsByCurrency?.[key];
    if (!Array.isArray(groups) || !groups.length) return <p key={key} className="erp-data-note">{label} : {totals[key] === "0" || totals[key] === 0 ? "0" : "—"}</p>;
    return groups.map(group=>metric(blockKey,key,label,icon,tone,"",{value:group.value,currency:group.code || "",rowKey:key+":"+(group.id??"none"),filters:{deviseId:group.id??"sans-devise"}}));
  }
  const header = <div className="erp-screen-head">
    <div className="logistics-screen-copy"><h1>{title}</h1></div>
    {canConfigurePresentation ? <Link className="ui-action is-secondary" to="/parametres?onglet=presentation&module=logistique">
      <AppIcon name="settings" />Paramètres d’affichage
    </Link> : null}
  </div>;
  if (!hasVisibleBlocks) return <div className="erp-dashboard">
    {header}
    <section className="table-empty-state erp-dashboard-empty" aria-labelledby={selectPrefix+"-empty"}>
      <h2 id={selectPrefix+"-empty"}>Aucun bloc affiché</h2>
      <p>Les blocs du tableau de bord sont masqués pour cette entreprise.</p>
    </section>
  </div>;

  return <div className="erp-dashboard">
    {header}
    <form className="erp-dashboard-filters" role="search" onSubmit={apply}>
      <label className="admin-form-field erp-dashboard-query"><span>Recherche</span><span className="erp-dashboard-search"><AppIcon name="search" /><input type="search" placeholder="Article, bon de stock, tiers…" value={draft.q} onChange={(event) => setDraft((current) => ({ ...current, q: event.target.value }))} /></span></label>
      <label className="admin-form-field erp-dashboard-period" htmlFor={selectPrefix+"-period"}><span>Période</span><SearchSelect id={selectPrefix+"-period"} label="Période" value={periodMode} options={[{value:"all",label:"Toutes les dates"},{value:"month",label:"Ce mois"},{value:"quarter",label:"Ce trimestre"},{value:"year",label:"Cette année"},{value:"custom",label:"Personnalisée"}]} onChange={value => { setPeriodMode(value); if(value !== "custom") setDraft(current => ({...current,...periodDates(value)})); }}/></label>
      <CurrencySelect references={references} filter value={draft.deviseId} onChange={value=>setDraft(current=>({...current,deviseId:value}))}/>
      <label className="admin-form-field"><span>Du</span><input type="date" value={draft.dateFrom} onChange={(event) => { setPeriodMode("custom"); setDraft((current) => ({ ...current, dateFrom: event.target.value })); }} /></label>
      <label className="admin-form-field"><span>Au</span><input type="date" value={draft.dateTo} onChange={(event) => { setPeriodMode("custom"); setDraft((current) => ({ ...current, dateTo: event.target.value })); }} /></label>
      <ActionButton type="submit" variant="primary" disabled={loading}>Rechercher</ActionButton><ActionButton icon="reset" disabled={loading} onClick={() => { const empty = { q: "", dateFrom: "", dateTo: "", deviseId:"" }; setPeriodMode("all"); setDraft(empty); setCriteria(empty); setFilterError(""); }}>Réinitialiser</ActionButton>
    </form>
    {filterError ? <p role="alert" className="erp-filter-error">{filterError}</p> : null}
    {loading ? <span role="status" className="erp-dashboard-loading">Actualisation…</span> : null}
    {error ? <div className="table-empty-state" role="alert">{error} <button type="button" onClick={() => setVersion((value) => value + 1)}>Réessayer</button></div> : null}
    {summary ? <div aria-busy={loading}>
      <div className={"erp-dashboard-sections" + (showLeftColumn && showRightColumn ? "" : " is-single-column")}>
        {showLeftColumn ? <div className="erp-dashboard-column">
          {!hidden.has("articles") ? <IndicatorBlock id="dashboard-articles" title="Articles" icon="bi-box-seam" scope="Stock courant">
            <div className="erp-group-grid">
              {metric("articles", "articles", "Nombre d’articles", "bi-box", "blue", "", { stockWeight: summary.stockWeight })}
              {summary.categories?.map((category) => metric("articles", "articlesCategorie", category.label, "bi-tag", "teal", "", {
                value: category.count,
                rowKey: "category-" + (category.id ?? "none"),
                filters: { categorieId: category.id ?? "sans-categorie" },
                stockWeight: category,
              }))}
            </div>
            <details className="erp-stock-controls"><summary>Contrôle du stock</summary><div className="erp-group-grid">{metric("articles", "auditTotal", "Articles contrôlés")}{metric("articles", "auditCoherents", "Stocks cohérents", "bi-check2-circle", "teal")}{metric("articles", "auditEcarts", "Écarts", "bi-exclamation-circle", "coral")}{metric("articles", "coherenceRate", "Cohérence", "bi-percent", "slate", " %")}</div></details>
          </IndicatorBlock> : null}
          {!hidden.has("commandes") ? <IndicatorBlock id="dashboard-bons" title="Bons de stock" icon="bi-receipt">
            <div className="erp-group-grid">
              {metric("commandes", "commandes", "Nombre de bons", "bi-receipt", "purple")}
              {metric("commandes", "commandesEnAttente", "En attente", "bi-hourglass-split", "amber")}
              {metric("commandes", "commandesEnCours", "En cours", "bi-arrow-repeat", "slate")}
              {metric("commandes", "commandesEntree", "Entrées", "bi-box-arrow-in-down", "teal")}
              {metric("commandes", "commandesSortie", "Sorties", "bi-box-arrow-up", "blue")}
              {metric("commandes", "commandesSansDetails", "Sans lignes", "bi-list-check", "coral")}
              {metric("commandes", "commandesNonFacturees", "Non facturés", "bi-file-earmark", "slate")}
              {moneyMetrics("commandes", "montantBons", "Valeur des bons", "bi-cash-stack", "purple")}
            </div>
          </IndicatorBlock> : null}
        </div> : null}
        {showRightColumn ? <div className="erp-dashboard-column">
          {!hidden.has("factures") ? <IndicatorBlock id="dashboard-factures" title="Factures" icon="bi-file-earmark-text">
            <div className="erp-group-grid">
              {metric("factures", "factures", "Nombre de factures", "bi-file-earmark-text", "blue")}
              {metric("factures", "facturesSoldees", "Soldées", "bi-check2-circle", "teal")}
              {metric("factures", "facturesPartielles", "Partiellement réglées", "bi-wallet2", "slate")}
              {metric("factures", "facturesARegler", "À régler", "bi-hourglass-split", "amber")}
              {metric("factures", "facturesEnRetard", "En retard", "bi-calendar-event", "coral")}
            </div>
            <h3 className="erp-block-subtitle">Montants</h3>
            <div className="erp-group-grid">
              {moneyMetrics("factures", "montantTotalFacture", "Facturé", "bi-cash-stack", "blue")}
              {moneyMetrics("factures", "montantTotalRegle", "Réglé", "bi-check2-circle", "teal")}
              {moneyMetrics("factures", "montantRestant", "Solde à régler", "bi-hourglass-split", "amber")}
            </div>
          </IndicatorBlock> : null}
          {!hidden.has("alertes") ? <IndicatorBlock id="dashboard-alertes" title="Alertes" icon="bi-bell">
            <div className="erp-group-grid">
              {metric("alertes", "alertesStock", "Stock faible", "bi-exclamation-triangle", "amber")}
              {metric("alertes", "ruptures", "Ruptures", "bi-box-seam", "coral")}
              {metric("alertes", "peremptionProche", "Péremption proche", "bi-calendar-event", "amber")}
              {metric("alertes", "articlesPerimes", "Articles périmés", "bi-calendar-x", "coral")}
              {metric("alertes", "auditEcarts", "Écarts de stock", "bi-exclamation-circle", "rose")}
              {metric("alertes", "couvertureCritique", "Couverture courte", "bi-hourglass-split", "slate")}
            </div>
          </IndicatorBlock> : null}
        </div> : null}
      </div>
      {visibleMetric ? <div ref={detailPanel} id="dashboard-indicator-details" className="erp-detail-entry">
        <ActionButton ref={detailReturn} className="erp-detail-return" icon="arrow-up" onClick={closeMetric}>Revenir à l’indicateur</ActionButton>
        <section className="erp-panel erp-indicator-details" aria-labelledby="dashboard-detail-title">
        <div className="erp-detail-header"><div><span>Liste détaillée</span><h2 ref={detailTitle} tabIndex="-1" id="dashboard-detail-title">{visibleMetric.label}</h2></div><button type="button" className="erp-detail-close" aria-label="Fermer la liste" onClick={closeMetric}><AppIcon name="close" /></button></div>
        {(criteria.q || criteria.dateFrom || criteria.dateTo || criteria.deviseId) ? <p className="erp-detail-criteria">{[criteria.deviseId && "Devise : "+(references?.currencies?.find(item=>String(item.id)===String(criteria.deviseId))?.code || "Non renseignée"),criteria.q && "Recherche : " + criteria.q, criteria.dateFrom && "Du " + formatDate(criteria.dateFrom), criteria.dateTo && "au " + formatDate(criteria.dateTo)].filter(Boolean).join(" · ")}</p> : null}
        <IndicatorDetails key={JSON.stringify([visibleMetric.blockKey, visibleMetric.key, criteria, visibleMetric.filters])} metricKey={visibleMetric.key} criteria={{ ...criteria, ...visibleMetric.filters, depotId:depotScope.depotId }} onReady={detailsReady} />
        </section>
      </div> : null}

    </div> : null}
  </div>;
}
