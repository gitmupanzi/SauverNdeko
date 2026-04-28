import { useEffect, useState } from "react";
import { fetchLogistiqueCouverture } from "../../services/logistique";
import { asArrayPayload, formatNumber, LoadingErrorEmpty, SectionCard, SimpleTable, ToneBadge } from "./logistiqueShared";

export default function CouvertureStock({ refreshKey }) {
  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    let isMounted = true;

    async function loadCouverture() {
      setLoading(true);
      setError("");

      const response = await fetchLogistiqueCouverture({
        take: 120,
      });

      if (!isMounted) {
        return;
      }

      if (!response?.success) {
        setRows([]);
        setError(response?.message || "Impossible de charger la couverture de stock.");
        setLoading(false);
        return;
      }

      setRows(asArrayPayload(response));
      setLoading(false);
    }

    loadCouverture();

    return () => {
      isMounted = false;
    };
  }, [refreshKey]);

  return (
    <SectionCard title="Couverture du stock" subtitle="Lecture seule sur V_CouvertureStock.">
      <LoadingErrorEmpty loading={loading} error={error} rows={rows} emptyMessage="Aucune couverture de stock disponible." />

      {!loading && !error && rows.length > 0 ? (
        <SimpleTable
          rows={rows}
          rowClassName={(row) => (Number(row.CouvertureMois || 0) <= 1 ? "logistics-row-critical" : "")}
          columns={[
            { key: "NomArticle", label: "Article" },
            { key: "StockActuel", label: "Stock actuel", render: (row) => formatNumber(row.StockActuel) },
            { key: "Conso6Mois", label: "Conso 6 mois", render: (row) => formatNumber(row.Conso6Mois) },
            { key: "ConsoMoyMensuelle", label: "Moyenne mensuelle", render: (row) => formatNumber(row.ConsoMoyMensuelle) },
            {
              key: "CouvertureMois",
              label: "Couverture",
              render: (row) =>
                Number(row.CouvertureMois || 0) <= 1 ? (
                  <ToneBadge tone="danger">{`${formatNumber(row.CouvertureMois)} mois`}</ToneBadge>
                ) : (
                  `${formatNumber(row.CouvertureMois)} mois`
                ),
            },
          ]}
        />
      ) : null}
    </SectionCard>
  );
}
