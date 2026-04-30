import { useDeferredValue, useEffect, useMemo, useState } from "react";
import {
  asArrayPayload,
  buildReferenceLabelMap,
  buildReferenceOptions,
  exportRowsToCsv,
  exportRowsToPdf,
  formatCurrency,
  formatDate,
  formatNumber,
  LoadingErrorEmpty,
  SectionCard,
  SelectionStrip,
  SelectField,
  SimpleTable,
  SummaryCard,
  TableToolbar,
} from "./logistiqueShared";
import { getLogistiqueGenericSourceHint, getLogistiqueViewConfig } from "./views";

const MOUVEMENTS_VIEW_CONFIG = getLogistiqueViewConfig("mouvements");

function buildReferenceHelperText(sourceKey, options) {
  const count = Array.isArray(options) ? options.length : 0;
  return `${getLogistiqueGenericSourceHint(sourceKey)} | ${count} option(s) chargee(s)`;
}

export default function Mouvements({ references, refreshKey, sharedTable }) {
  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [articleFilter, setArticleFilter] = useState("");
  const [typeFilter, setTypeFilter] = useState("");
  const [commandeFilter, setCommandeFilter] = useState("");
  const [dateFrom, setDateFrom] = useState("");
  const [dateTo, setDateTo] = useState("");
  const selectedMouvement = sharedTable?.selectedRow || null;
  const deferredSearch = useDeferredValue(sharedTable?.searchValue || "");

  const articleOptions = useMemo(() => buildReferenceOptions(references?.articles, "Article"), [references]);
  const mouvementTypeOptions = useMemo(() => buildReferenceOptions(references?.commandeTypes, "Type"), [references]);
  const typeLabelMap = useMemo(() => buildReferenceLabelMap(mouvementTypeOptions), [mouvementTypeOptions]);
  const articleMetaMap = useMemo(
    () =>
      new Map(
        (Array.isArray(references?.articles) ? references.articles : []).map((article) => [String(article.id), article])
      ),
    [references]
  );
  const visibleRows = useMemo(
    () =>
      rows.filter((row) =>
        commandeFilter ? String(row.CodeCmd || "").toLowerCase().includes(String(commandeFilter).toLowerCase()) : true
      ),
    [commandeFilter, rows]
  );
  const summary = useMemo(
    () =>
      visibleRows.reduce(
        (accumulator, row) => {
          accumulator.total += 1;
          accumulator.quantite += Number(row.QteMvt || 0);

          const label = String(row.TypeMvt || typeLabelMap.get(String(row.ID_TypeMvtFk)) || "").toLowerCase();

          if (label.includes("sort")) {
            accumulator.sorties += Number(row.QteMvt || 0);
          } else if (label.includes("entr")) {
            accumulator.entrees += Number(row.QteMvt || 0);
          }

          return accumulator;
        },
        { total: 0, quantite: 0, entrees: 0, sorties: 0 }
      ),
    [typeLabelMap, visibleRows]
  );
  const compactColumns = useMemo(
    () => [
      { key: "DateMvt", label: "Date", renderText: (row) => formatDate(row.DateMvt, { withTime: true }) },
      {
        key: "ID_TypeMvtFk",
        label: "Type",
        renderText: (row) => row.TypeMvt || typeLabelMap.get(String(row.ID_TypeMvtFk)) || `#${row.ID_TypeMvtFk ?? "-"}`,
      },
      { key: "NomArticle", label: "Designation" },
      {
        key: "Reference",
        label: "Reference",
        renderText: (row) => articleMetaMap.get(String(row.ID_ArticleFk))?.reference || "-",
      },
      { key: "CodeCmd", label: "Commande", renderText: (row) => row.CodeCmd || "-" },
      { key: "QteMvt", label: "Qte", renderText: (row) => formatNumber(row.QteMvt) },
      {
        key: "StockActuel",
        label: "Stock actuel",
        renderText: (row) => formatNumber(articleMetaMap.get(String(row.ID_ArticleFk))?.stock),
      },
      { key: "PUMvt", label: "PU", renderText: (row) => formatCurrency(row.PUMvt) },
    ],
    [articleMetaMap, typeLabelMap]
  );

  useEffect(() => {
    let isMounted = true;

    async function loadMouvements() {
      setLoading(true);
      setError("");

      const response = await MOUVEMENTS_VIEW_CONFIG.fetchRows({
        q: deferredSearch,
        article: articleFilter,
        typeId: typeFilter,
        dateFrom,
        dateTo,
        take: 150,
      });

      if (!isMounted) {
        return;
      }

      if (!response?.success) {
        setRows([]);
        setError(response?.message || "Impossible de charger les mouvements.");
        setLoading(false);
        return;
      }

      const nextRows = asArrayPayload(response);
      setRows(nextRows);
      if (selectedMouvement?.ID_Mvt != null) {
        const matchedMouvement = nextRows.find((row) => row.ID_Mvt === selectedMouvement.ID_Mvt);
        if (matchedMouvement) {
          sharedTable?.setSelectedRow?.(matchedMouvement);
        } else {
          sharedTable?.clearSelectedRow?.();
        }
      }
      setLoading(false);
    }

    loadMouvements();

    return () => {
      isMounted = false;
    };
  }, [articleFilter, dateFrom, dateTo, deferredSearch, refreshKey, typeFilter]);

  return (
    <div className="logistics-workbench">
      <div className="logistics-primary-pane">
        <SectionCard
          title="Historique des mouvements"
          subtitle="Lecture compacte de l'inventaire de mouvements, sans CRUD direct sur T_Mouvement."
          actions={
            <div className="logistics-inline-actions">
              <button
                type="button"
                className="secondary-action"
                onClick={() => exportRowsToCsv("logistique-mouvements.csv", compactColumns, visibleRows)}
                disabled={visibleRows.length === 0}
              >
                Exporter
              </button>
              <button
                type="button"
                className="secondary-action"
                onClick={() => exportRowsToPdf("logistique-mouvements", compactColumns, visibleRows)}
                disabled={visibleRows.length === 0}
              >
                Imprimer
              </button>
            </div>
          }
        >
          <div className="logistics-summary-grid">
            <SummaryCard title="Mouvements visibles" value={formatNumber(summary.total)} />
            <SummaryCard title="Quantite totale" value={formatNumber(summary.quantite)} tone="info" />
            <SummaryCard title="Entrees" value={formatNumber(summary.entrees)} tone="success" />
            <SummaryCard title="Sorties" value={formatNumber(summary.sorties)} tone="warning" />
          </div>

          <div className="logistics-filter-grid logistics-filter-grid-wide">
            <label className="admin-form-field">
              <span>{sharedTable?.searchLabel || "Recherche globale"}</span>
              <input
                type="search"
                value={sharedTable?.searchValue || ""}
                onChange={(event) => sharedTable?.setSearchValue?.(event.target.value)}
                placeholder="Type, article, code commande..."
              />
            </label>

            <SelectField
              label="Article"
              value={articleFilter}
              onChange={(event) => setArticleFilter(event.target.value)}
              options={articleOptions}
            />

            <SelectField
              label="Type mouvement"
              value={typeFilter}
              onChange={(event) => setTypeFilter(event.target.value)}
              options={mouvementTypeOptions}
              disabled={mouvementTypeOptions.length === 0}
              emptyLabel={mouvementTypeOptions.length === 0 ? "Aucune option disponible" : "Choisir"}
              helperText={buildReferenceHelperText("logistique.commandeTypes", mouvementTypeOptions)}
            />

            <label className="admin-form-field">
              <span>Commande</span>
              <input
                type="search"
                value={commandeFilter}
                onChange={(event) => setCommandeFilter(event.target.value)}
                placeholder="Code commande..."
              />
            </label>

            <label className="admin-form-field">
              <span>Date debut</span>
              <input type="date" value={dateFrom} onChange={(event) => setDateFrom(event.target.value)} />
            </label>

            <label className="admin-form-field">
              <span>Date fin</span>
              <input type="date" value={dateTo} onChange={(event) => setDateTo(event.target.value)} />
            </label>
          </div>

          <SelectionStrip
            selectedRow={selectedMouvement}
            label={selectedMouvement ? `Ligne selectionnee: mouvement #${selectedMouvement.ID_Mvt}` : "Aucune ligne selectionnee"}
            description={
              selectedMouvement
                ? `${selectedMouvement.TypeMvt || "-"} | ${selectedMouvement.NomArticle || "-"} | ${formatNumber(selectedMouvement.QteMvt)}`
                : "Selectionnez un mouvement pour le lire plus facilement."
            }
          />

          <TableToolbar
            title={sharedTable?.toolbarTitle || "Inventaire / mouvements"}
            rows={visibleRows}
            columns={compactColumns}
            exportFilename={sharedTable?.exportFilename || "logistique-v_mouvement.csv"}
          />

          <LoadingErrorEmpty loading={loading} error={error} rows={visibleRows} emptyMessage="Aucun mouvement a afficher." />

          {!loading && !error && visibleRows.length > 0 ? (
            <SimpleTable
              rows={visibleRows}
              selectedRowId={selectedMouvement?.ID_Mvt || null}
              onRowSelect={sharedTable?.setSelectedRow}
              defaultPinnedColumns={["DateMvt", "NomArticle"]}
              defaultSortColumn="DateMvt"
              exportFilename={sharedTable?.exportFilename || "logistique-v_mouvement.csv"}
              columns={compactColumns.map((column) => ({
                ...column,
                render:
                  column.key === "DateMvt"
                    ? (row) => formatDate(row.DateMvt, { withTime: true })
                    : column.key === "ID_TypeMvtFk"
                      ? (row) => row.TypeMvt || typeLabelMap.get(String(row.ID_TypeMvtFk)) || `#${row.ID_TypeMvtFk ?? "-"}`
                      : column.key === "Reference"
                        ? (row) => articleMetaMap.get(String(row.ID_ArticleFk))?.reference || "-"
                        : column.key === "StockActuel"
                          ? (row) => formatNumber(articleMetaMap.get(String(row.ID_ArticleFk))?.stock)
                          : column.key === "QteMvt"
                            ? (row) => formatNumber(row.QteMvt)
                            : column.key === "PUMvt"
                              ? (row) => formatCurrency(row.PUMvt)
                              : undefined,
              }))}
            />
          ) : null}
        </SectionCard>
      </div>

      {selectedMouvement ? (
        <aside className="logistics-side-pane">
          <SectionCard title="Detail mouvement" subtitle="Lecture rapide du mouvement selectionne.">
            <div className="logistics-detail-grid">
              <article>
                <strong>{selectedMouvement.NomArticle || `Article #${selectedMouvement.ID_ArticleFk}`}</strong>
                <p>Date: {formatDate(selectedMouvement.DateMvt, { withTime: true })}</p>
                <p>Type: {selectedMouvement.TypeMvt || typeLabelMap.get(String(selectedMouvement.ID_TypeMvtFk)) || "-"}</p>
                <p>Reference: {articleMetaMap.get(String(selectedMouvement.ID_ArticleFk))?.reference || "-"}</p>
              </article>
              <article>
                <p>Commande: {selectedMouvement.CodeCmd || "-"}</p>
                <p>Quantite: {formatNumber(selectedMouvement.QteMvt)}</p>
                <p>PU: {formatCurrency(selectedMouvement.PUMvt)}</p>
                <p>Stock actuel: {formatNumber(articleMetaMap.get(String(selectedMouvement.ID_ArticleFk))?.stock)}</p>
              </article>
            </div>
          </SectionCard>
        </aside>
      ) : null}
    </div>
  );
}
