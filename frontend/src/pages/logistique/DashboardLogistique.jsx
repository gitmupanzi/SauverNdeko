import { useEffect, useState } from "react";
import { fetchLogistiqueDashboard } from "../../services/logistique";
import {
  formatCurrency,
  formatNumber,
  LoadingErrorEmpty,
  SectionCard,
  SimpleTable,
  SummaryCard,
  ToneBadge,
} from "./logistiqueShared";

function formatPercent(value) {
  return `${formatNumber(Number(value || 0).toFixed(1))} %`;
}

function resolveIndicatorTone(value, warningThreshold, dangerThreshold, reverse = false) {
  const numericValue = Number(value || 0);

  if (reverse) {
    if (numericValue >= dangerThreshold) {
      return "danger";
    }

    if (numericValue >= warningThreshold) {
      return "warning";
    }

    return "success";
  }

  if (numericValue <= dangerThreshold) {
    return "danger";
  }

  if (numericValue <= warningThreshold) {
    return "warning";
  }

  return "success";
}

export default function DashboardLogistique({ refreshKey, onNavigate }) {
  const [summary, setSummary] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    let isMounted = true;

    async function loadSummary() {
      setLoading(true);
      setError("");

      const response = await fetchLogistiqueDashboard();

      if (!isMounted) {
        return;
      }

      if (!response?.success) {
        setSummary(null);
        setError(response?.message || "Impossible de charger le tableau de bord logistique.");
        setLoading(false);
        return;
      }

      setSummary(response.data);
      setLoading(false);
    }

    loadSummary();

    return () => {
      isMounted = false;
    };
  }, [refreshKey]);

  const totals = summary?.totals || {};
  const highlights = summary?.highlights || {};
  const paiementRate =
    Number(totals.montantTotalFacture || 0) > 0
      ? Number(
          (
            (Number(totals.montantTotalRegle || 0) / Number(totals.montantTotalFacture || 0)) *
            100
          ).toFixed(1)
        )
      : 0;
  const detailCompletionRate =
    Number(totals.commandes || 0) > 0
      ? Number(
          (((Number(totals.commandes || 0) - Number(totals.commandesSansDetails || 0)) / Number(totals.commandes || 0)) * 100).toFixed(
            1
          )
        )
      : 0;
  const stockRiskRate =
    Number(totals.articles || 0) > 0
      ? Number(((Number(totals.alertesStock || 0) / Number(totals.articles || 0)) * 100).toFixed(1))
      : 0;
  const remainingCoverageRisk =
    Number(totals.articles || 0) > 0
      ? Number(((Number(totals.couvertureCritique || 0) / Number(totals.articles || 0)) * 100).toFixed(1))
      : 0;
  const completionTone = resolveIndicatorTone(detailCompletionRate, 90, 75);
  const paymentTone = resolveIndicatorTone(paiementRate, 80, 55);
  const stockTone = resolveIndicatorTone(stockRiskRate, 15, 30, true);
  const coverageTone = resolveIndicatorTone(Number(totals.couvertureMinimale || 0), 2, 1);
  const viewIndicators = [
    {
      view: "V_Article",
      label: "Articles suivis",
      value: formatNumber(totals.articles),
      caption: `${formatNumber(totals.alertesStock)} articles en alerte`,
      tone: "info",
    },
    {
      view: "V_Commande",
      label: "Commandes",
      value: formatNumber(totals.commandes),
      caption: `${formatCurrency(totals.montantTotalFacture)} factures TTC`,
      tone: "default",
    },
    {
      view: "V_CommandesSansDetails",
      label: "Taux de completion",
      value: formatPercent(detailCompletionRate),
      caption: `${formatNumber(totals.commandesSansDetails)} commandes a completer`,
      tone: Number(totals.commandesSansDetails || 0) > 0 ? "warning" : "success",
      actionKey: "commandes",
    },
    {
      view: "V_AlertStock",
      label: "Pression stock",
      value: formatPercent(stockRiskRate),
      caption: `${formatNumber(totals.prochesRupture)} proches rupture`,
      tone: Number(totals.alertesStock || 0) > 0 ? "danger" : "success",
      actionKey: "alertes",
    },
    {
      view: "V_CouvertureStock",
      label: "Couverture minimale",
      value: `${formatNumber(totals.couvertureMinimale)} mois`,
      caption: `${formatNumber(totals.couvertureCritique)} articles <= 1 mois`,
      tone: Number(totals.couvertureCritique || 0) > 0 ? "warning" : "success",
      actionKey: "couverture",
    },
    {
      view: "V_SuiviReglements",
      label: "Taux d'encaissement",
      value: formatPercent(paiementRate),
      caption: `${formatCurrency(totals.montantRestant)} reste a payer`,
      tone: Number(totals.montantRestant || 0) > 0 ? "warning" : "success",
      actionKey: "reglements",
    },
  ];
  const actions = [
    { key: "articles", label: "Articles" },
    { key: "commandes", label: "Commandes" },
    { key: "details", label: "Details" },
    { key: "audit", label: "Audit stock" },
    { key: "alertes", label: "Alertes" },
    { key: "reglements", label: "Reglements" },
  ];

  return (
    <div className="logistics-stack">
      <SectionCard
        title="Vue d'ensemble logistique"
        subtitle="Synthese des stocks, commandes et reglements a partir des vues SQL metier."
        actions={
          <div className="logistics-inline-actions">
            {actions.map((action) => (
              <button key={action.key} type="button" className="secondary-action" onClick={() => onNavigate(action.key)}>
                {action.label}
              </button>
            ))}
          </div>
        }
      >
        <LoadingErrorEmpty loading={loading} error={error} rows={summary ? [summary] : []} emptyMessage="Aucune synthese disponible." />

        {summary ? (
          <>
            <div className="logistics-summary-grid">
              <SummaryCard title="Articles" value={formatNumber(totals.articles)} tone="info" />
              <SummaryCard title="Commandes" value={formatNumber(totals.commandes)} tone="default" />
              <SummaryCard title="Sans details" value={formatNumber(totals.commandesSansDetails)} tone="warning" />
              <SummaryCard title="Alertes stock" value={formatNumber(totals.alertesStock)} tone="danger" />
              <SummaryCard
                title="Proches rupture"
                value={formatNumber(totals.prochesRupture)}
                tone="warning"
                caption={`Marge <= ${summary.assumptions?.procheRuptureMargeMax ?? 5}`}
              />
              <SummaryCard title="Facture TTC" value={formatCurrency(totals.montantTotalFacture)} tone="default" />
              <SummaryCard title="Total regle" value={formatCurrency(totals.montantTotalRegle)} tone="success" />
              <SummaryCard title="Reste a payer" value={formatCurrency(totals.montantRestant)} tone="danger" />
              <SummaryCard title="Couverture moyenne" value={`${formatNumber(totals.couvertureMoyenne)} mois`} tone="info" />
              <SummaryCard title="Conso du mois" value={formatNumber(totals.consommationMensuelle)} tone="default" />
            </div>

            <div className="logistics-kpi-board">
              <article className={`logistics-kpi-card is-${completionTone}`}>
                <div className="logistics-kpi-card-head">
                  <span>Execution des commandes</span>
                  <ToneBadge tone={completionTone}>{formatNumber(totals.commandesSansDetails)} a traiter</ToneBadge>
                </div>
                <strong>{formatPercent(detailCompletionRate)}</strong>
                <p>Part des commandes deja documentees avec leurs lignes de detail.</p>
                <div className="logistics-kpi-progress">
                  <span style={{ width: `${Math.min(100, Math.max(6, detailCompletionRate))}%` }} />
                </div>
              </article>

              <article className={`logistics-kpi-card is-${paymentTone}`}>
                <div className="logistics-kpi-card-head">
                  <span>Encaissement facture</span>
                  <ToneBadge tone={paymentTone}>{formatCurrency(totals.montantRestant)} ouverts</ToneBadge>
                </div>
                <strong>{formatPercent(paiementRate)}</strong>
                <p>Part du chiffre facture deja reglee par les clients.</p>
                <div className="logistics-kpi-progress">
                  <span style={{ width: `${Math.min(100, Math.max(6, paiementRate))}%` }} />
                </div>
              </article>

              <article className={`logistics-kpi-card is-${stockTone}`}>
                <div className="logistics-kpi-card-head">
                  <span>Exposition stock</span>
                  <ToneBadge tone={stockTone}>{formatNumber(totals.alertesStock)} alertes</ToneBadge>
                </div>
                <strong>{formatPercent(stockRiskRate)}</strong>
                <p>Part du catalogue actuellement exposee a une tension de stock.</p>
                <div className="logistics-kpi-progress">
                  <span style={{ width: `${Math.min(100, Math.max(6, stockRiskRate))}%` }} />
                </div>
              </article>

              <article className={`logistics-kpi-card is-${coverageTone}`}>
                <div className="logistics-kpi-card-head">
                  <span>Couverture critique</span>
                  <ToneBadge tone={coverageTone}>{formatNumber(totals.couvertureCritique)} sensibles</ToneBadge>
                </div>
                <strong>{`${formatNumber(totals.couvertureMinimale)} mois`}</strong>
                <p>Couverture la plus basse relevee sur les articles suivis.</p>
                <div className="logistics-kpi-progress">
                  <span style={{ width: `${Math.min(100, Math.max(6, 100 - remainingCoverageRisk))}%` }} />
                </div>
              </article>
            </div>

            <SectionCard
              title="Indicateurs par vue"
              subtitle="Lecture de pilotage alignee sur les principales vues metier du schema logistique."
              className="logistics-card-nested"
            >
              <div className="logistics-view-indicator-grid">
                {viewIndicators.map((indicator) => (
                  <button
                    key={indicator.view}
                    type="button"
                    className={`logistics-view-indicator logistics-view-indicator-button is-${indicator.tone}`}
                    onClick={() => indicator.actionKey && onNavigate(indicator.actionKey)}
                  >
                    <div className="logistics-view-indicator-head">
                      <span>{indicator.view}</span>
                      <strong>{indicator.label}</strong>
                    </div>
                    <h4>{indicator.value}</h4>
                    <p>{indicator.caption}</p>
                  </button>
                ))}
              </div>
            </SectionCard>

            <div className="logistics-grid-2">
              <SectionCard title="Articles critiques" subtitle="Les cinq alertes les plus sensibles du stock." className="logistics-card-nested">
                <SimpleTable
                  emptyMessage="Aucune alerte critique."
                  rows={highlights.alertes || []}
                  showControls={false}
                  defaultPinnedColumns={["NomArticle"]}
                  defaultSortColumn="Marge"
                  columns={[
                    { key: "NomArticle", label: "Article" },
                    { key: "QteArticle", label: "Stock", render: (row) => formatNumber(row.QteArticle) },
                    { key: "QteMinArticle", label: "Seuil", render: (row) => formatNumber(row.QteMinArticle) },
                    {
                      key: "Marge",
                      label: "Marge",
                      render: (row) =>
                        Number(row.Marge) <= 0 ? <ToneBadge tone="danger">{formatNumber(row.Marge)}</ToneBadge> : formatNumber(row.Marge),
                    },
                  ]}
                />
              </SectionCard>

              <SectionCard title="Consommation du mois" subtitle="Articles les plus consommes sur le mois courant." className="logistics-card-nested">
                <div className="logistics-bars">
                  {(highlights.consommation || []).map((row) => {
                    const maxValue = Math.max(
                      1,
                      ...(highlights.consommation || []).map((item) => Number(item.ConsoMensuelle || 0))
                    );
                    const width = `${Math.max(10, (Number(row.ConsoMensuelle || 0) / maxValue) * 100)}%`;

                    return (
                      <article key={`${row.ID_Article}-${row.Mois}`} className="logistics-bar-row">
                        <div>
                          <strong>{row.NomArticle}</strong>
                          <small>{row.Mois ? new Date(row.Mois).toLocaleDateString("fr-FR", { month: "long", year: "numeric" }) : "-"}</small>
                        </div>
                        <div className="logistics-bar-track">
                          <span style={{ width }} />
                        </div>
                        <strong>{formatNumber(row.ConsoMensuelle)}</strong>
                      </article>
                    );
                  })}
                </div>
              </SectionCard>
            </div>

            <div className="logistics-grid-2">
              <SectionCard
                title="Reglements a suivre"
                subtitle="Factures avec reste a payer prioritaires."
                className="logistics-card-nested"
              >
                <SimpleTable
                  emptyMessage="Aucune facture en attente de reglement."
                  rows={highlights.reglements || []}
                  showControls={false}
                  defaultPinnedColumns={["CodeFacture"]}
                  defaultSortColumn="Reste"
                  columns={[
                    { key: "CodeFacture", label: "Facture" },
                    { key: "MontantTTC", label: "TTC", render: (row) => formatCurrency(row.MontantTTC) },
                    { key: "TotalRegle", label: "Regle", render: (row) => formatCurrency(row.TotalRegle) },
                    {
                      key: "Reste",
                      label: "Reste",
                      render: (row) => <ToneBadge tone="warning">{formatCurrency(row.Reste)}</ToneBadge>,
                    },
                  ]}
                />
              </SectionCard>

              <SectionCard
                title="Commandes a completer"
                subtitle="Commandes creees sans lignes de detail a enrichir."
                className="logistics-card-nested"
              >
                <SimpleTable
                  emptyMessage="Toutes les commandes visibles ont deja leurs details."
                  rows={highlights.commandesSansDetails || []}
                  showControls={false}
                  defaultPinnedColumns={["CodeCmd"]}
                  defaultSortColumn="ID_Commande"
                  columns={[
                    { key: "ID_Commande", label: "Commande", render: (row) => formatNumber(row.ID_Commande) },
                    { key: "CodeCmd", label: "Code" },
                  ]}
                />
              </SectionCard>
            </div>

            <div className="logistics-grid-2">
              <SectionCard
                title="Audit prioritaire"
                subtitle="Ecarts de stock qui meritent une verification rapide."
                className="logistics-card-nested"
              >
                <SimpleTable
                  emptyMessage="Aucun ecart de stock remonte actuellement."
                  rows={highlights.audit || []}
                  showControls={false}
                  defaultPinnedColumns={["NomArticle"]}
                  defaultSortColumn="Ecart"
                  columns={[
                    { key: "NomArticle", label: "Article" },
                    { key: "StockArticle", label: "Stock fiche", render: (row) => formatNumber(row.StockArticle) },
                    { key: "StockMouvements", label: "Stock mouvements", render: (row) => formatNumber(row.StockMouvements) },
                    {
                      key: "Ecart",
                      label: "Ecart",
                      render: (row) => <ToneBadge tone={Number(row.Ecart || 0) === 0 ? "success" : "danger"}>{formatNumber(row.Ecart)}</ToneBadge>,
                    },
                  ]}
                />
              </SectionCard>

              <SectionCard
                title="Commandes recentes"
                subtitle="Dernieres commandes visibles pour un point de situation rapide."
                className="logistics-card-nested"
              >
                <SimpleTable
                  emptyMessage="Aucune commande recente disponible."
                  rows={highlights.commandesRecentes || []}
                  showControls={false}
                  defaultPinnedColumns={["CodeCmd"]}
                  defaultSortColumn="DateCmd"
                  columns={[
                    { key: "CodeCmd", label: "Commande" },
                    { key: "DateCmd", label: "Date", render: (row) => (row.DateCmd ? new Date(row.DateCmd).toLocaleDateString("fr-FR") : "-") },
                    { key: "AbrTypeCmd", label: "Type" },
                    { key: "MontantTTC", label: "TTC", render: (row) => formatCurrency(row.MontantTTC) },
                    {
                      key: "EtatPaiement",
                      label: "Paiement",
                      render: (row) => (
                        <ToneBadge tone={Number(row.MontantResteFacture || 0) > 0 ? "warning" : "success"}>
                          {row.EtatPaiement || "-"}
                        </ToneBadge>
                      ),
                    },
                  ]}
                />
              </SectionCard>
            </div>
          </>
        ) : null}
      </SectionCard>
    </div>
  );
}
