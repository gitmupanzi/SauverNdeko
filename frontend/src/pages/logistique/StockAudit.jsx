import { useEffect, useState } from "react";
import { asArrayPayload, formatNumber, LoadingErrorEmpty, SectionCard, SimpleTable, ToneBadge } from "./logistiqueShared";
import { getLogistiqueViewConfig } from "./views";

const STOCK_AUDIT_VIEW_CONFIG = getLogistiqueViewConfig("audit");

export default function StockAudit({ refreshKey }) {
  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [search, setSearch] = useState("");

  useEffect(() => {
    let isMounted = true;

    async function loadAudit() {
      setLoading(true);
      setError("");

      const response = await STOCK_AUDIT_VIEW_CONFIG.fetchRows({
        q: search,
        take: 120,
      });

      if (!isMounted) {
        return;
      }

      if (!response?.success) {
        setRows([]);
        setError(response?.message || "Impossible de charger l'audit du stock.");
        setLoading(false);
        return;
      }

      setRows(asArrayPayload(response));
      setLoading(false);
    }

    loadAudit();

    return () => {
      isMounted = false;
    };
  }, [refreshKey, search]);

  return (
    <SectionCard title="Audit de stock" subtitle="Lecture seule sur la vue V_AuditStock.">
      <div className="logistics-filter-grid">
        <label className="admin-form-field">
          <span>Recherche</span>
          <input type="search" value={search} onChange={(event) => setSearch(event.target.value)} placeholder="Article ou code interne" />
        </label>
      </div>

      <LoadingErrorEmpty loading={loading} error={error} rows={rows} emptyMessage="Aucun audit de stock disponible." />

      {!loading && !error && rows.length > 0 ? (
        <SimpleTable
          rows={rows}
          enableSelection
          defaultPinnedColumns={["CodeArticleInterne", "NomArticle"]}
          defaultSortColumn="Ecart"
          columns={[
            { key: "CodeArticleInterne", label: "Code" },
            { key: "NomArticle", label: "Article" },
            { key: "StockArticle", label: "Stock table", render: (row) => formatNumber(row.StockArticle) },
            { key: "StockMouvements", label: "Stock mvt", render: (row) => formatNumber(row.StockMouvements) },
            {
              key: "Ecart",
              label: "Ecart",
              render: (row) =>
                Number(row.Ecart) === 0 ? <ToneBadge tone="success">0</ToneBadge> : <ToneBadge tone="danger">{formatNumber(row.Ecart)}</ToneBadge>,
            },
            { key: "N_Mouvements", label: "Nb mvt", render: (row) => formatNumber(row.N_Mouvements) },
            { key: "QteEntree", label: "Entrees", render: (row) => formatNumber(row.QteEntree) },
            { key: "QteSortie", label: "Sorties", render: (row) => formatNumber(row.QteSortie) },
          ]}
        />
      ) : null}
    </SectionCard>
  );
}
