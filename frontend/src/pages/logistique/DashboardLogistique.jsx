import AppIcon from "../../components/AppIcon";
import ActionButton from "../../components/ActionButton";
import "./DashboardLogistique.css";
import { useEffect, useRef, useState } from "react";
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
function IndicatorBlock({ id, title, icon, scope, children }) {
  const [open, setOpen] = useState(true);
  return <section className="erp-indicator-block" aria-labelledby={id + "-title"}>
    <header className="erp-block-header"><h2 id={id + "-title"}><span className="erp-block-icon"><AppIcon name={icon} size={18} /></span>{title}{scope ? <span className="erp-block-scope">{scope}</span> : null}</h2><button type="button" aria-expanded={open} aria-controls={id + "-body"} onClick={() => setOpen((current) => !current)} aria-label={(open ? "Masquer " : "Afficher ") + title} title={open ? "Masquer" : "Afficher"}><AppIcon name={open ? "chevron-up" : "chevron-down"} /></button></header>
    <div id={id + "-body"} className="erp-block-body" hidden={!open}>{children}</div>
  </section>;
}

export default function DashboardLogistique({ refreshKey }) {
  const [periodMode, setPeriodMode] = useState("all");
  const [draft, setDraft] = useState({ q: "", dateFrom: "", dateTo: "" });
  const [criteria, setCriteria] = useState({ q: "", dateFrom: "", dateTo: "" });
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
  function showMetric(key, label, event, filters = {}) { detailTrigger.current = event.currentTarget; setSelectedMetric({ key, label, filters }); }
  function closeMetric() {
    setSelectedMetric(null);
    const origin = detailTrigger.current;
    if (origin?.isConnected) { const target = origin.closest("[hidden]") ? origin.closest(".erp-indicator-block")?.querySelector(".erp-block-header > button") : origin; target?.scrollIntoView({ block:"center",behavior:"auto" }); target?.focus({preventScroll:true}); }
  }
  useEffect(() => {
    if (!selectedMetric) return;
    detailPanel.current?.scrollIntoView({ block: "start", behavior: window.matchMedia("(prefers-reduced-motion: reduce)").matches ? "auto" : "smooth" });
    detailReturn.current?.focus({ preventScroll: true });
  }, [selectedMetric]);
  useEffect(() => {
    const controller = new AbortController();
    setLoading(true);
    setError("");
    const params = new URLSearchParams(Object.entries(criteria).filter(([, value]) => value));
    requestJson("/api/logistique/synthese?" + params, { requiresAuth: true, signal: controller.signal }).then((payload) => {
      if (controller.signal.aborted) return;
      if (!payload?.success) { setSummary(null); setError("La synthèse n’a pas pu être chargée."); }
      else setSummary(payload.data);
      setLoading(false);
    });
    return () => controller.abort();
  }, [criteria, refreshKey, version]);
  function apply(event) {
    event.preventDefault();
    if (draft.dateFrom && draft.dateTo && draft.dateFrom > draft.dateTo) { setFilterError("La date de fin doit suivre la date de début."); return; }
    setFilterError("");
    setCriteria({ ...draft, q: draft.q.trim() });
  }
  const totals = summary?.totals || {};
  function metric(key, label, icon = "bi-bar-chart", tone = "blue", suffix = "", options = {}) {
    const value = options.value !== undefined ? options.value : totals[key];
    const selected = selectedMetric?.key === key && JSON.stringify(selectedMetric?.filters || {}) === JSON.stringify(options.filters || {});
    const open = (event) => showMetric(key, label, event, options.filters || {});
    return <article key={options.rowKey || key} className={"erp-kpi is-" + tone}>
      <button type="button" className="erp-kpi-main" disabled={loading} aria-label={label + " : " + formatNumber(value) + (value != null ? suffix : "") + ". Voir la liste"} aria-expanded={selected} aria-controls="dashboard-indicator-details" onClick={open}>
        <span className="erp-kpi-icon"><AppIcon name={icon} size={17} /></span><span className="erp-kpi-label" title={label}>{label}</span><strong>{formatNumber(value)}{value != null ? suffix : ""}</strong><AppIcon name="chevron-right" size={12} className="erp-kpi-chevron" />
      </button>
    </article>;
  }
  return <div className="erp-dashboard">
    <div className="erp-screen-head"><div className="logistics-screen-copy"><h1>Tableau de bord</h1></div></div>
    <form className="erp-dashboard-filters" role="search" onSubmit={apply}>
      <label className="admin-form-field erp-dashboard-query"><span>Recherche</span><span className="erp-dashboard-search"><AppIcon name="search" /><input type="search" placeholder="Article, bon de stock, tiers…" value={draft.q} onChange={(event) => setDraft((current) => ({ ...current, q: event.target.value }))} /></span></label>
      <label className="admin-form-field erp-dashboard-period"><span>Période</span><select value={periodMode} onChange={(event) => { setPeriodMode(event.target.value); if(event.target.value !== "custom") setDraft(current => ({...current,...periodDates(event.target.value)})); }}><option value="all">Toutes les dates</option><option value="month">Ce mois</option><option value="quarter">Ce trimestre</option><option value="year">Cette année</option><option value="custom">Personnalisée</option></select></label>
      <label className="admin-form-field"><span>Du</span><input type="date" value={draft.dateFrom} onChange={(event) => { setPeriodMode("custom"); setDraft((current) => ({ ...current, dateFrom: event.target.value })); }} /></label>
      <label className="admin-form-field"><span>Au</span><input type="date" value={draft.dateTo} onChange={(event) => { setPeriodMode("custom"); setDraft((current) => ({ ...current, dateTo: event.target.value })); }} /></label>
      <ActionButton type="submit" variant="primary" disabled={loading}>Rechercher</ActionButton><ActionButton icon="reset" disabled={loading} onClick={() => { const empty = { q: "", dateFrom: "", dateTo: "" }; setPeriodMode("all"); setDraft(empty); setCriteria(empty); setFilterError(""); }}>Réinitialiser</ActionButton>
    </form>
    {filterError ? <p role="alert" className="erp-filter-error">{filterError}</p> : null}
    {loading ? <p role="status" className="erp-data-note">Actualisation…</p> : null}
    {error ? <div className="table-empty-state" role="alert">{error} <button type="button" onClick={() => setVersion((value) => value + 1)}>Réessayer</button></div> : null}
    {summary ? <div aria-busy={loading}>
      <div className="erp-dashboard-sections"><div className="erp-dashboard-column">
      <IndicatorBlock id="dashboard-articles" title="Articles" icon="bi-box-seam" scope="Stock courant">
        <div className="erp-group-grid">
          {metric("articles", "Nombre d’articles", "bi-box", "blue")}
          {summary.categories?.length ? summary.categories.map((category) => metric("articlesCategorie", category.label, "bi-tag", "teal", "", { value: category.count, rowKey: "category-" + (category.id ?? "none"), filters: { categorieId: category.id ?? "sans-categorie" } })) : null}
        </div>
        <details className="erp-stock-controls"><summary>Contrôle du stock</summary><div className="erp-group-grid">{metric("auditTotal", "Articles contrôlés")}{metric("auditCoherents", "Stocks cohérents", "bi-check2-circle", "teal")}{metric("auditEcarts", "Écarts", "bi-exclamation-circle", "coral")}{metric("coherenceRate", "Cohérence", "bi-percent", "slate", " %")}</div></details>
      </IndicatorBlock>
      <IndicatorBlock id="dashboard-bons" title="Bons de stock" icon="bi-receipt">
        <div className="erp-group-grid">
          {metric("commandes", "Nombre de bons", "bi-receipt", "purple")}
          {metric("commandesEnAttente", "En attente", "bi-hourglass-split", "amber")}
          {metric("commandesEnCours", "En cours", "bi-arrow-repeat", "slate")}
          {metric("commandesEntree", "Entrées", "bi-box-arrow-in-down", "teal")}
          {metric("commandesSortie", "Sorties", "bi-box-arrow-up", "blue")}
          {metric("commandesSansDetails", "Sans lignes", "bi-list-check", "coral")}
          {metric("commandesNonFacturees", "Non facturés", "bi-file-earmark", "slate")}
          {metric("montantBons", "Valeur des bons", "bi-cash-stack", "purple")}
        </div>
        <p className="erp-data-note erp-block-note">Montants sans devise précisée.</p>
      </IndicatorBlock>
      </div><div className="erp-dashboard-column">
      <IndicatorBlock id="dashboard-factures" title="Factures" icon="bi-file-earmark-text">
        <div className="erp-group-grid">
          {metric("factures", "Nombre de factures", "bi-file-earmark-text", "blue")}
          {metric("facturesSoldees", "Soldées", "bi-check2-circle", "teal")}
          {metric("facturesPartielles", "Partiellement réglées", "bi-wallet2", "slate")}
          {metric("facturesARegler", "À régler", "bi-hourglass-split", "amber")}
          {metric("facturesEnRetard", "En retard", "bi-calendar-event", "coral")}
        </div>
        <h3 className="erp-block-subtitle">Montants</h3>
        <div className="erp-group-grid">
          {metric("montantTotalFacture", "Facturé", "bi-cash-stack", "blue")}
          {metric("montantTotalRegle", "Réglé", "bi-check2-circle", "teal")}
          {metric("montantRestant", "Solde à régler", "bi-hourglass-split", "amber")}
        </div>
        <p className="erp-data-note erp-block-note">Montants sans devise précisée.</p>
      </IndicatorBlock>
      <IndicatorBlock id="dashboard-alertes" title="Alertes" icon="bi-bell">
        <div className="erp-group-grid">
          {metric("alertesStock", "Stock faible", "bi-exclamation-triangle", "amber")}
          {metric("ruptures", "Ruptures", "bi-box-seam", "coral")}
          {metric("peremptionProche", "Péremption proche", "bi-calendar-event", "amber")}
          {metric("articlesPerimes", "Articles périmés", "bi-calendar-x", "coral")}
          {metric("auditEcarts", "Écarts de stock", "bi-exclamation-circle", "rose")}
          {metric("couvertureCritique", "Couverture courte", "bi-hourglass-split", "slate")}
        </div>
      </IndicatorBlock>
      </div></div>
      {selectedMetric ? <div ref={detailPanel} id="dashboard-indicator-details" className="erp-detail-entry">
        <ActionButton ref={detailReturn} className="erp-detail-return" icon="arrow-up" onClick={closeMetric}>Revenir à l’indicateur</ActionButton>
        <section className="erp-panel erp-indicator-details" aria-labelledby="dashboard-detail-title">
        <div className="erp-detail-header"><div><span>Liste détaillée</span><h2 ref={detailTitle} tabIndex="-1" id="dashboard-detail-title">{selectedMetric.label}</h2></div><button type="button" className="erp-detail-close" aria-label="Fermer la liste" onClick={closeMetric}><AppIcon name="close" /></button></div>
        {(criteria.q || criteria.dateFrom || criteria.dateTo) ? <p className="erp-detail-criteria">{[criteria.q && "Recherche : " + criteria.q, criteria.dateFrom && "Du " + formatDate(criteria.dateFrom), criteria.dateTo && "au " + formatDate(criteria.dateTo)].filter(Boolean).join(" · ")}</p> : null}
        <IndicatorDetails key={selectedMetric.key + JSON.stringify(criteria) + JSON.stringify(selectedMetric.filters)} metricKey={selectedMetric.key} criteria={{ ...criteria, ...selectedMetric.filters }} />
        </section>
      </div> : null}

    </div> : null}
  </div>;
}
