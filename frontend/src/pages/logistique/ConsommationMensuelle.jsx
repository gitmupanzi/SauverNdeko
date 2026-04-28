import { useEffect, useMemo, useState } from "react";
import { fetchLogistiqueConsommation } from "../../services/logistique";
import {
  asArrayPayload,
  buildReferenceOptions,
  formatDate,
  formatNumber,
  LoadingErrorEmpty,
  SectionCard,
  SelectField,
  SimpleTable,
} from "./logistiqueShared";

export default function ConsommationMensuelle({ references, refreshKey }) {
  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [articleFilter, setArticleFilter] = useState("");
  const [dateFrom, setDateFrom] = useState("");
  const [dateTo, setDateTo] = useState("");
  const articleOptions = useMemo(() => buildReferenceOptions(references?.articles, "Article"), [references]);

  useEffect(() => {
    let isMounted = true;

    async function loadConsommation() {
      setLoading(true);
      setError("");

      const response = await fetchLogistiqueConsommation({
        article: articleFilter,
        dateFrom,
        dateTo,
        take: 120,
      });

      if (!isMounted) {
        return;
      }

      if (!response?.success) {
        setRows([]);
        setError(response?.message || "Impossible de charger la consommation mensuelle.");
        setLoading(false);
        return;
      }

      setRows(asArrayPayload(response));
      setLoading(false);
    }

    loadConsommation();

    return () => {
      isMounted = false;
    };
  }, [articleFilter, dateFrom, dateTo, refreshKey]);

  const maxValue = useMemo(
    () => Math.max(1, ...rows.map((row) => Number(row.ConsoMensuelle || 0))),
    [rows]
  );

  return (
    <div className="logistics-stack">
      <SectionCard title="Consommation mensuelle" subtitle="Vue V_ConsoMensuelle avec representation graphique simple.">
        <div className="logistics-filter-grid logistics-filter-grid-wide">
          <SelectField
            label="Article"
            value={articleFilter}
            onChange={(event) => setArticleFilter(event.target.value)}
            options={articleOptions}
          />

          <label className="admin-form-field">
            <span>Du mois</span>
            <input type="date" value={dateFrom} onChange={(event) => setDateFrom(event.target.value)} />
          </label>

          <label className="admin-form-field">
            <span>Au mois</span>
            <input type="date" value={dateTo} onChange={(event) => setDateTo(event.target.value)} />
          </label>
        </div>

        <LoadingErrorEmpty loading={loading} error={error} rows={rows} emptyMessage="Aucune consommation mensuelle disponible." />

        {!loading && !error && rows.length > 0 ? (
          <div className="logistics-bars">
            {rows.slice(0, 8).map((row) => (
              <article key={`${row.ID_Article}-${row.Mois}`} className="logistics-bar-row">
                <div>
                  <strong>{row.NomArticle}</strong>
                  <small>{formatDate(row.Mois)}</small>
                </div>
                <div className="logistics-bar-track">
                  <span style={{ width: `${Math.max(10, (Number(row.ConsoMensuelle || 0) / maxValue) * 100)}%` }} />
                </div>
                <strong>{formatNumber(row.ConsoMensuelle)}</strong>
              </article>
            ))}
          </div>
        ) : null}
      </SectionCard>

      {!loading && !error && rows.length > 0 ? (
        <SectionCard title="Tableau detaille" subtitle="Detail mensuel par article.">
          <SimpleTable
            rows={rows}
            columns={[
              { key: "NomArticle", label: "Article" },
              { key: "Mois", label: "Mois", render: (row) => formatDate(row.Mois) },
              { key: "ConsoMensuelle", label: "Consommation", render: (row) => formatNumber(row.ConsoMensuelle) },
            ]}
          />
        </SectionCard>
      ) : null}
    </div>
  );
}
