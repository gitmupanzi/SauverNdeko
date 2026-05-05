import { useEffect, useMemo, useState } from "react";
import {
  asArrayPayload,
  buildReferenceOptions,
  exportRowsToCsv,
  formatCurrency,
  formatDate,
  formatNumber,
  LoadingErrorEmpty,
  ToneBadge,
} from "./logistiqueShared";
import { getLogistiqueViewConfig } from "./views";

const DASHBOARD_VIEW_CONFIG = getLogistiqueViewConfig("dashboard");
const AUDIT_VIEW_CONFIG = getLogistiqueViewConfig("audit");
const ALERTES_VIEW_CONFIG = getLogistiqueViewConfig("alertes");
const CONSOMMATION_VIEW_CONFIG = getLogistiqueViewConfig("consommation");
const COUVERTURE_VIEW_CONFIG = getLogistiqueViewConfig("couverture");

function formatPercent(value) {
  return `${formatNumber(Number(value || 0).toFixed(1))} %`;
}

function formatShortCurrency(value) {
  const numericValue = Number(value || 0);

  if (Math.abs(numericValue) >= 1000000) {
    return `${formatNumber((numericValue / 1000000).toFixed(1))}M`;
  }

  if (Math.abs(numericValue) >= 1000) {
    return `${formatNumber((numericValue / 1000).toFixed(0))}k`;
  }

  return formatNumber(numericValue);
}

function normalizeText(value) {
  return String(value || "")
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "");
}

function getAuditTone(row) {
  return Number(row?.Ecart || 0) === 0 ? "success" : Number(row?.Ecart || 0) > 0 ? "warning" : "danger";
}

function getAlertStockTone(row) {
  if (row?.EstRupture) {
    return "danger";
  }

  if (row?.EstAlerteStock) {
    return "warning";
  }

  return "info";
}

function getExpirationTone(row) {
  if (row?.EstPerime) {
    return "danger";
  }

  if (row?.EstAlertePeremption) {
    return "warning";
  }

  return "success";
}

function getPaymentTone(label) {
  const normalized = normalizeText(label);

  if (normalized.includes("part")) {
    return "warning";
  }

  if (normalized.includes("non")) {
    return "danger";
  }

  if (normalized.includes("regl")) {
    return "success";
  }

  return "info";
}

function getControlTone(label) {
  const normalized = normalizeText(label);

  if (normalized.includes("sans")) {
    return "warning";
  }

  if (normalized.includes("incoher")) {
    return "danger";
  }

  if (normalized.includes("coher")) {
    return "success";
  }

  return "info";
}

function getCoverageTone(label) {
  const normalized = normalizeText(label);

  if (normalized.includes("crit")) {
    return "danger";
  }

  if (normalized.includes("faible")) {
    return "warning";
  }

  if (normalized.includes("aucune")) {
    return "info";
  }

  return "success";
}

function getMovementTone(label) {
  const normalized = normalizeText(label);
  return normalized.includes("sort") ? "warning" : normalized.includes("entr") ? "success" : "info";
}

function buildMonthLabel(value) {
  if (!value) {
    return "-";
  }

  return new Date(value).toLocaleDateString("fr-FR", { month: "short" });
}

function buildReportRows(totals) {
  return [
    { label: "Articles", value: totals.articles || 0 },
    { label: "Commandes", value: totals.commandes || 0 },
    { label: "Stock faible", value: totals.prochesRupture || 0 },
    { label: "Ruptures", value: totals.alertesStock || 0 },
    { label: "Commandes sans details", value: totals.commandesSansDetails || 0 },
    { label: "Reglements en retard", value: totals.facturesEnRetard || 0 },
  ];
}

function DashboardKpiCard({ colorClass, label, value, iconText }) {
  return (
    <article className="logistics-dashboard-kpi-card">
      <div className={`logistics-dashboard-kpi-icon ${colorClass}`}>{iconText}</div>
      <div className="logistics-dashboard-kpi-copy">
        <span>{label}</span>
        <strong>{value}</strong>
      </div>
    </article>
  );
}

function DashboardMetricTile({ label, value, tone = "default" }) {
  return (
    <article className={`logistics-dashboard-metric-tile is-${tone}`}>
      <span>{label}</span>
      <strong>{value}</strong>
    </article>
  );
}

function DashboardMiniTable({ columns, rows, emptyMessage = "Aucune donnee." }) {
  if (!Array.isArray(rows) || rows.length === 0) {
    return <div className="table-empty-state">{emptyMessage}</div>;
  }

  return (
    <div className="logistics-dashboard-mini-table-wrap">
      <table className="logistics-dashboard-mini-table">
        <thead>
          <tr>
            {columns.map((column) => (
              <th key={column.key}>{column.label}</th>
            ))}
          </tr>
        </thead>
        <tbody>
          {rows.map((row, index) => (
            <tr key={row.ID_Article || row.ID_Commande || row.ID_Mvt || `${columnKey(row)}-${index}`}>
              {columns.map((column) => (
                <td key={`${column.key}-${index}`}>{column.render ? column.render(row, index) : row[column.key] ?? "-"}</td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

function columnKey(row) {
  return row?.CodeCmd || row?.CodeArticleInterne || row?.NomArticle || row?.CodeFacture || "row";
}

export default function DashboardLogistique({ refreshKey, onNavigate, references }) {
  const [summary, setSummary] = useState(null);
  const [auditRows, setAuditRows] = useState([]);
  const [alertRows, setAlertRows] = useState([]);
  const [consoRows, setConsoRows] = useState([]);
  const [coverageRows, setCoverageRows] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [periodFilter, setPeriodFilter] = useState("ce-mois");
  const [categoryFilter, setCategoryFilter] = useState("");
  const [typeFilter, setTypeFilter] = useState("");
  const [commandeTypeFilter, setCommandeTypeFilter] = useState("");
  const [commandeStatusFilter, setCommandeStatusFilter] = useState("");
  const [paymentFilter, setPaymentFilter] = useState("");

  useEffect(() => {
    let isMounted = true;

    async function loadDashboard() {
      setLoading(true);
      setError("");

      const [summaryResponse, auditResponse, alertResponse, consoResponse, coverageResponse] = await Promise.all([
        DASHBOARD_VIEW_CONFIG.fetchSummary(),
        AUDIT_VIEW_CONFIG.fetchRows({ take: 200 }),
        ALERTES_VIEW_CONFIG.fetchRows({ take: 200 }),
        CONSOMMATION_VIEW_CONFIG.fetchRows({ take: 400 }),
        COUVERTURE_VIEW_CONFIG.fetchRows({ take: 400 }),
      ]);

      if (!isMounted) {
        return;
      }

      if (!summaryResponse?.success) {
        setSummary(null);
        setAuditRows([]);
        setAlertRows([]);
        setConsoRows([]);
        setCoverageRows([]);
        setError(summaryResponse?.message || "Impossible de charger le tableau de bord logistique.");
        setLoading(false);
        return;
      }

      setSummary(summaryResponse.data);
      setAuditRows(asArrayPayload(auditResponse));
      setAlertRows(asArrayPayload(alertResponse));
      setConsoRows(asArrayPayload(consoResponse));
      setCoverageRows(asArrayPayload(coverageResponse));
      setLoading(false);
    }

    loadDashboard();

    return () => {
      isMounted = false;
    };
  }, [refreshKey]);

  const totals = summary?.totals || {};
  const highlights = summary?.highlights || {};
  const categoryOptions = useMemo(() => buildReferenceOptions(references?.articleCategories, "Categorie"), [references]);
  const typeOptions = useMemo(() => buildReferenceOptions(references?.articleTypes, "Type"), [references]);
  const commandeTypeOptions = useMemo(() => buildReferenceOptions(references?.commandeTypes, "Type"), [references]);
  const commandeStatusOptions = useMemo(() => buildReferenceOptions(references?.commandeStatuses, "Statut"), [references]);

  const auditStats = useMemo(() => {
    const coherentRows = auditRows.filter((row) => row.EstStockCoherent);
    const totalEntrees = auditRows.reduce((sum, row) => sum + Number(row.QteEntree || 0), 0);
    const totalSorties = auditRows.reduce((sum, row) => sum + Number(row.QteSortie || 0), 0);

    return {
      total: auditRows.length,
      coherent: coherentRows.length,
      ecarts: auditRows.filter((row) => Number(row.Ecart || 0) !== 0).length,
      coherenceRate: auditRows.length > 0 ? (coherentRows.length / auditRows.length) * 100 : 0,
      totalEntrees,
      totalSorties,
    };
  }, [auditRows]);

  const alertStats = useMemo(() => {
    const stockFaible = alertRows.filter((row) => !row.EstRupture && row.EstAlerteStock).length;
    const ruptures = alertRows.filter((row) => row.EstRupture).length;
    const qteACommander = alertRows.reduce((sum, row) => sum + Number(row.QteACommander || 0), 0);
    const peremption = alertRows.filter((row) => row.EstAlertePeremption || row.EstPerime).length;

    return { stockFaible, ruptures, qteACommander, peremption };
  }, [alertRows]);

  const monthlyConsumption = useMemo(() => {
    const monthMap = new Map();

    consoRows.forEach((row) => {
      const monthKey = String(row.Mois || "");

      if (!monthKey) {
        return;
      }

      const current = monthMap.get(monthKey) || {
        month: monthKey,
        totalQuantity: 0,
        totalValue: 0,
      };

      current.totalQuantity += Number(row.ConsoMensuelle || 0);
      current.totalValue += Number(row.ValeurConsoMensuelle || 0);
      monthMap.set(monthKey, current);
    });

    return Array.from(monthMap.values())
      .sort((left, right) => new Date(left.month) - new Date(right.month))
      .slice(-6);
  }, [consoRows]);

  const totalConsumedValue = useMemo(
    () => monthlyConsumption.reduce((sum, row) => sum + Number(row.totalValue || 0), 0),
    [monthlyConsumption]
  );

  const coverageStats = useMemo(() => {
    const totalStock = coverageRows.reduce((sum, row) => sum + Number(row.StockActuel || 0), 0);
    const totalConso6 = coverageRows.reduce((sum, row) => sum + Number(row.Conso6Mois || 0), 0);
    const totalConsoMonthly = coverageRows.reduce((sum, row) => sum + Number(row.ConsoMoyMensuelle || 0), 0);
    const validCoverageRows = coverageRows.filter((row) => Number.isFinite(Number(row.CouvertureMois)));
    const averageCoverageMonths =
      validCoverageRows.length > 0
        ? validCoverageRows.reduce((sum, row) => sum + Number(row.CouvertureMois || 0), 0) / validCoverageRows.length
        : 0;
    const coverageDays = Math.round(averageCoverageMonths * 30);
    const stateCount = coverageRows.reduce((accumulator, row) => {
      const state = String(row.EtatCouverture || "Correcte");
      accumulator[state] = (accumulator[state] || 0) + 1;
      return accumulator;
    }, {});
    const dominantState =
      Object.entries(stateCount).sort((left, right) => right[1] - left[1])[0]?.[0] || "Correcte";

    return {
      totalStock,
      totalConso6,
      totalConsoMonthly,
      averageCoverageMonths,
      coverageDays,
      dominantState,
    };
  }, [coverageRows]);

  const recentCommandes = useMemo(() => (Array.isArray(highlights.commandesRecentes) ? highlights.commandesRecentes.slice(0, 5) : []), [highlights]);
  const recentMouvements = useMemo(() => (Array.isArray(highlights.mouvementsRecents) ? highlights.mouvementsRecents.slice(0, 5) : []), [highlights]);
  const reportRows = useMemo(() => buildReportRows(totals), [totals]);
  const maxMonthlyValue = useMemo(
    () => Math.max(1, ...monthlyConsumption.map((row) => Number(row.totalValue || 0))),
    [monthlyConsumption]
  );

  return (
    <div className="logistics-dashboard-page">
      <div className="logistics-dashboard-head">
        <div className="logistics-screen-copy">
          <h1>Tableau de bord</h1>
          <p>Vue synthetique du stock, des commandes, des mouvements et des reglements</p>
        </div>

        <div className="logistics-dashboard-userbar" aria-hidden="true">
          <div className="logistics-dashboard-bell">
            <span>3</span>
          </div>
          <div className="logistics-dashboard-avatar">AD</div>
        </div>
      </div>

      <LoadingErrorEmpty loading={loading} error={error} rows={summary ? [summary] : []} emptyMessage="Aucune synthese disponible." />

      {summary ? (
        <>
          <section className="logistics-dashboard-kpi-grid">
            <DashboardKpiCard colorClass="is-blue" iconText="A" label="Articles" value={formatNumber(totals.articles)} />
            <DashboardKpiCard colorClass="is-violet" iconText="C" label="Commandes" value={formatNumber(totals.commandes)} />
            <DashboardKpiCard colorClass="is-amber" iconText="!" label="Stock faible" value={formatNumber(totals.prochesRupture)} />
            <DashboardKpiCard colorClass="is-red" iconText="X" label="Ruptures" value={formatNumber(totals.alertesStock)} />
            <DashboardKpiCard colorClass="is-sky" iconText="D" label="Commandes sans details" value={formatNumber(totals.commandesSansDetails)} />
            <DashboardKpiCard colorClass="is-green" iconText="R" label="Reglements en retard" value={formatNumber(totals.facturesEnRetard)} />
          </section>

          <section className="logistics-top-actions">
            <button type="button" className="logistics-top-action is-blue" onClick={() => onNavigate("articles")}>
              Nouvel article
            </button>
            <button type="button" className="logistics-top-action is-indigo" onClick={() => onNavigate("commandes")}>
              Nouvelle commande
            </button>
            <button type="button" className="logistics-top-action is-orange" onClick={() => onNavigate("alertes")}>
              Voir alertes stock
            </button>
            <button type="button" className="logistics-top-action is-sky" onClick={() => onNavigate("commandes")}>
              Voir commandes sans details
            </button>
            <button
              type="button"
              className="logistics-top-action is-green"
              onClick={() => exportRowsToCsv("logistique-dashboard.csv", [
                { key: "label", label: "Indicateur" },
                { key: "value", label: "Valeur" },
              ], reportRows)}
            >
              Exporter rapport
            </button>
            <button type="button" className="logistics-top-action is-purple" onClick={() => window.print()}>
              Imprimer
            </button>
            <button type="button" className="logistics-top-action is-muted" disabled>
              Autres filtres
            </button>
          </section>

          <section className="logistics-screen-filter-card">
            <div className="logistics-mockup-filter-grid">
              <label className="admin-form-field">
                <span>Periode</span>
                <select value={periodFilter} onChange={(event) => setPeriodFilter(event.target.value)}>
                  <option value="ce-mois">Ce mois</option>
                  <option value="trois-mois">3 derniers mois</option>
                  <option value="six-mois">6 derniers mois</option>
                </select>
              </label>

              <label className="admin-form-field">
                <span>Categorie article</span>
                <select value={categoryFilter} onChange={(event) => setCategoryFilter(event.target.value)}>
                  <option value="">Toutes</option>
                  {categoryOptions.map((option) => (
                    <option key={option.value} value={option.value}>
                      {option.label}
                    </option>
                  ))}
                </select>
              </label>

              <label className="admin-form-field">
                <span>Type article</span>
                <select value={typeFilter} onChange={(event) => setTypeFilter(event.target.value)}>
                  <option value="">Toutes</option>
                  {typeOptions.map((option) => (
                    <option key={option.value} value={option.value}>
                      {option.label}
                    </option>
                  ))}
                </select>
              </label>

              <label className="admin-form-field">
                <span>Type commande</span>
                <select value={commandeTypeFilter} onChange={(event) => setCommandeTypeFilter(event.target.value)}>
                  <option value="">Toutes</option>
                  {commandeTypeOptions.map((option) => (
                    <option key={option.value} value={option.value}>
                      {option.label}
                    </option>
                  ))}
                </select>
              </label>

              <label className="admin-form-field">
                <span>Statut commande</span>
                <select value={commandeStatusFilter} onChange={(event) => setCommandeStatusFilter(event.target.value)}>
                  <option value="">Tous</option>
                  {commandeStatusOptions.map((option) => (
                    <option key={option.value} value={option.value}>
                      {option.label}
                    </option>
                  ))}
                </select>
              </label>

              <label className="admin-form-field">
                <span>Etat paiement</span>
                <select value={paymentFilter} onChange={(event) => setPaymentFilter(event.target.value)}>
                  <option value="">Tous</option>
                  <option value="reglee">Reglee</option>
                  <option value="partielle">Partiellement reglee</option>
                  <option value="non-reglee">Non reglee</option>
                  <option value="non-facturee">Non facturee</option>
                </select>
              </label>
            </div>
          </section>

          <section className="logistics-dashboard-grid">
            <article className="logistics-dashboard-panel">
              <div className="logistics-dashboard-panel-head">
                <div>
                  <h3>Audit de stock</h3>
                  <p>Comparaison entre stock article et stock mouvements</p>
                </div>
              </div>

              <div className="logistics-dashboard-metric-row">
                <DashboardMetricTile label="Articles audites" value={formatNumber(auditStats.total)} />
                <DashboardMetricTile label="Stocks coherents" value={formatNumber(auditStats.coherent)} tone="success" />
                <DashboardMetricTile label="Ecarts detectes" value={formatNumber(auditStats.ecarts)} tone="danger" />
                <DashboardMetricTile label="Taux de coherence" value={formatPercent(auditStats.coherenceRate)} tone="info" />
              </div>

              <DashboardMiniTable
                emptyMessage="Aucun audit disponible."
                rows={auditRows.slice(0, 5)}
                columns={[
                  { key: "CodeArticleInterne", label: "Code article" },
                  { key: "NomArticle", label: "Article" },
                  { key: "StockArticle", label: "Stock article", render: (row) => formatNumber(row.StockArticle) },
                  { key: "StockMouvements", label: "Stock mouvements", render: (row) => formatNumber(row.StockMouvements) },
                  { key: "Ecart", label: "Ecart", render: (row) => formatNumber(row.Ecart) },
                  { key: "EtatAuditStock", label: "Etat audit", render: (row) => <ToneBadge tone={getAuditTone(row)}>{row.EtatAuditStock || "-"}</ToneBadge> },
                ]}
              />

              <button type="button" className="logistics-dashboard-link" onClick={() => onNavigate("audit")}>
                Voir le rapport complet
              </button>
            </article>

            <article className="logistics-dashboard-panel">
              <div className="logistics-dashboard-panel-head">
                <div>
                  <h3>Alertes de stock</h3>
                  <p>Articles en rupture ou en stock faible</p>
                </div>
              </div>

              <div className="logistics-dashboard-metric-row">
                <DashboardMetricTile label="Stock faible" value={formatNumber(alertStats.stockFaible)} tone="warning" />
                <DashboardMetricTile label="Ruptures" value={formatNumber(alertStats.ruptures)} tone="danger" />
                <DashboardMetricTile label="Quantite a commander" value={formatNumber(alertStats.qteACommander)} tone="info" />
                <DashboardMetricTile label="Alertes peremption" value={formatNumber(alertStats.peremption)} tone="warning" />
              </div>

              <DashboardMiniTable
                emptyMessage="Aucune alerte de stock."
                rows={alertRows.slice(0, 4)}
                columns={[
                  { key: "CodeArticleInterne", label: "Code article" },
                  { key: "NomArticle", label: "Article" },
                  { key: "QteArticle", label: "Stock actuel", render: (row) => formatNumber(row.QteArticle) },
                  { key: "QteMinArticle", label: "Seuil d'alerte", render: (row) => formatNumber(row.QteMinArticle) },
                  {
                    key: "EtatStock",
                    label: "Etat",
                    render: (row) => <ToneBadge tone={getAlertStockTone(row)}>{row.EtatStock || (row.EstRupture ? "Rupture" : "Stock faible")}</ToneBadge>,
                  },
                ]}
              />

              <button type="button" className="logistics-dashboard-link" onClick={() => onNavigate("alertes")}>
                Voir toutes les alertes
              </button>
            </article>

            <article className="logistics-dashboard-panel">
              <div className="logistics-dashboard-panel-head">
                <div>
                  <h3>Consommation mensuelle</h3>
                  <p>Sorties de stock par mois</p>
                </div>
              </div>

              <div className="logistics-dashboard-chart">
                {monthlyConsumption.map((row) => (
                  <article key={row.month} className="logistics-dashboard-chart-bar">
                    <strong>{formatShortCurrency(row.totalValue)}</strong>
                    <div className="logistics-dashboard-chart-track">
                      <span style={{ height: `${Math.max(12, (Number(row.totalValue || 0) / maxMonthlyValue) * 100)}%` }} />
                    </div>
                    <small>{buildMonthLabel(row.month)}</small>
                  </article>
                ))}
              </div>

              <div className="logistics-dashboard-chart-footer">
                <span>Valeur consommee</span>
                <strong>{formatCurrency(totalConsumedValue)}</strong>
              </div>
            </article>

            <article className="logistics-dashboard-panel">
              <div className="logistics-dashboard-panel-head">
                <div>
                  <h3>Couverture stock</h3>
                  <p>Duree estimee de stock selon la consommation des 6 derniers mois</p>
                </div>
              </div>

              <div className="logistics-dashboard-metric-row">
                <DashboardMetricTile label="Stock actuel" value={`${formatNumber(coverageStats.totalStock)} u.`} />
                <DashboardMetricTile label="Conso 6 mois" value={`${formatNumber(coverageStats.totalConso6)} u.`} />
                <DashboardMetricTile label="Conso moyenne mensuelle" value={`${formatNumber(coverageStats.totalConsoMonthly)} u.`} />
                <DashboardMetricTile label="Couverture" value={`${formatNumber(coverageStats.coverageDays)} jours`} tone="info" />
                <DashboardMetricTile label="Etat couverture" value={coverageStats.dominantState} tone={getCoverageTone(coverageStats.dominantState)} />
              </div>

              <div className="logistics-dashboard-legend">
                <span><i className="is-success" />Correcte</span>
                <span><i className="is-warning" />Faible</span>
                <span><i className="is-danger" />Critique</span>
                <span><i className="is-info" />Aucune consommation recente</span>
              </div>

              <button type="button" className="logistics-dashboard-link" onClick={() => onNavigate("couverture")}>
                Voir le detail de la couverture
              </button>
            </article>
          </section>

          <section className="logistics-dashboard-grid">
            <article className="logistics-dashboard-panel">
              <div className="logistics-dashboard-panel-head">
                <div>
                  <h3>Dernieres commandes</h3>
                </div>
              </div>

              <DashboardMiniTable
                emptyMessage="Aucune commande recente."
                rows={recentCommandes}
                columns={[
                  { key: "CodeCmd", label: "Code commande" },
                  { key: "DateCmd", label: "Date", render: (row) => formatDate(row.DateCmd) },
                  { key: "TypeCmd", label: "Type", render: (row) => row.TypeCmd || "-" },
                  { key: "StatutCmd", label: "Statut", render: (row) => <ToneBadge tone="info">{row.StatutCmd || "-"}</ToneBadge> },
                  { key: "NomClientSaisi", label: "Client", render: (row) => row.NomClientSaisi || "-" },
                  { key: "MontantTTC", label: "Montant TTC", render: (row) => formatCurrency(row.MontantTTC) },
                  { key: "EtatPaiement", label: "Etat paiement", render: (row) => <ToneBadge tone={getPaymentTone(row.EtatPaiement)}>{row.EtatPaiement || "-"}</ToneBadge> },
                  { key: "EtatControleCommande", label: "Controle commande", render: (row) => <ToneBadge tone={getControlTone(row.EtatControleCommande)}>{row.EtatControleCommande || "-"}</ToneBadge> },
                ]}
              />

              <button type="button" className="logistics-dashboard-link" onClick={() => onNavigate("commandes")}>
                Voir toutes les commandes
              </button>
            </article>

            <article className="logistics-dashboard-panel">
              <div className="logistics-dashboard-panel-head">
                <div>
                  <h3>Derniers mouvements</h3>
                </div>
              </div>

              <DashboardMiniTable
                emptyMessage="Aucun mouvement recent."
                rows={recentMouvements}
                columns={[
                  { key: "DateMvt", label: "Date mouvement", render: (row) => formatDate(row.DateMvt, { withTime: true }) },
                  { key: "NomArticle", label: "Article" },
                  { key: "TypeMvt", label: "Type mouvement", render: (row) => <ToneBadge tone={getMovementTone(row.TypeMvt)}>{row.TypeMvt || "-"}</ToneBadge> },
                  { key: "QteMvt", label: "Quantite", render: (row) => formatNumber(row.QteMvtSigned ?? row.QteMvt) },
                  { key: "MontantMvt", label: "Montant mouvement", render: (row) => formatCurrency(row.MontantMvtSigned ?? row.MontantMvt) },
                  { key: "OrigineMouvement", label: "Origine mouvement", render: (row) => row.OrigineMouvement || "-" },
                ]}
              />

              <button type="button" className="logistics-dashboard-link" onClick={() => onNavigate("mouvements")}>
                Voir tous les mouvements
              </button>
            </article>
          </section>
        </>
      ) : null}
    </div>
  );
}
