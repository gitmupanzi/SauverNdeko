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

            <div className="logistics-grid-2">
              <SectionCard title="Articles critiques" subtitle="Les cinq alertes les plus sensibles du stock." className="logistics-card-nested">
                <SimpleTable
                  emptyMessage="Aucune alerte critique."
                  rows={highlights.alertes || []}
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
          </>
        ) : null}
      </SectionCard>
    </div>
  );
}
