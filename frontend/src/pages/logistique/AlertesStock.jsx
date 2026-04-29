import { useEffect, useMemo, useState } from "react";
import { fetchLogistiqueAlertesStock } from "../../services/logistique";
import { asArrayPayload, formatNumber, LoadingErrorEmpty, SectionCard, SimpleTable, SummaryCard, ToneBadge } from "./logistiqueShared";

export default function AlertesStock({ refreshKey }) {
  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [criticalOnly, setCriticalOnly] = useState(false);

  useEffect(() => {
    let isMounted = true;

    async function loadAlertes() {
      setLoading(true);
      setError("");

      const response = await fetchLogistiqueAlertesStock({
        criticalOnly,
        take: 120,
      });

      if (!isMounted) {
        return;
      }

      if (!response?.success) {
        setRows([]);
        setError(response?.message || "Impossible de charger les alertes de stock.");
        setLoading(false);
        return;
      }

      setRows(asArrayPayload(response));
      setLoading(false);
    }

    loadAlertes();

    return () => {
      isMounted = false;
    };
  }, [criticalOnly, refreshKey]);

  const stats = useMemo(() => {
    const critical = rows.filter((row) => Number(row.Marge) <= 0).length;
    const warning = rows.filter((row) => Number(row.Marge) > 0).length;

    return {
      critical,
      warning,
    };
  }, [rows]);

  return (
    <SectionCard
      title="Alertes stock"
      subtitle="Lecture seule de V_AlertStock avec mise en evidence des articles critiques."
      actions={
        <label className="logistics-inline-toggle">
          <input type="checkbox" checked={criticalOnly} onChange={(event) => setCriticalOnly(event.target.checked)} />
          <span>Seulement critiques</span>
        </label>
      }
    >
      <div className="logistics-summary-grid logistics-summary-grid-compact">
        <SummaryCard title="Critiques" value={formatNumber(stats.critical)} tone="danger" />
        <SummaryCard title="Sous surveillance" value={formatNumber(stats.warning)} tone="warning" />
      </div>

      <LoadingErrorEmpty loading={loading} error={error} rows={rows} emptyMessage="Aucune alerte de stock disponible." />

      {!loading && !error && rows.length > 0 ? (
        <SimpleTable
          rows={rows}
          enableSelection
          defaultPinnedColumns={["NomArticle"]}
          defaultSortColumn="Marge"
          rowClassName={(row) => (Number(row.Marge) <= 0 ? "logistics-row-critical" : "logistics-row-warning")}
          columns={[
            { key: "NomArticle", label: "Article" },
            { key: "QteArticle", label: "Stock", render: (row) => formatNumber(row.QteArticle) },
            { key: "QteMinArticle", label: "Seuil", render: (row) => formatNumber(row.QteMinArticle) },
            {
              key: "Marge",
              label: "Marge",
              render: (row) =>
                Number(row.Marge) <= 0 ? <ToneBadge tone="danger">{formatNumber(row.Marge)}</ToneBadge> : <ToneBadge tone="warning">{formatNumber(row.Marge)}</ToneBadge>,
            },
          ]}
        />
      ) : null}
    </SectionCard>
  );
}
