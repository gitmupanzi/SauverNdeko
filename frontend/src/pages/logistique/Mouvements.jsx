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
  ToneBadge,
} from "./logistiqueShared";
import { getLogistiqueGenericSourceHint, getLogistiqueViewConfig } from "./views";

const MOUVEMENTS_VIEW_CONFIG = getLogistiqueViewConfig("mouvements");

function buildReferenceHelperText(sourceKey, options) {
  const count = Array.isArray(options) ? options.length : 0;
  return `${getLogistiqueGenericSourceHint(sourceKey)} | ${count} option(s) chargee(s)`;
}

function getMovementTone(row) {
  const label = String(row?.NomTypeMvt || row?.TypeMvt || "").toLowerCase();

  if (label.includes("sort")) {
    return "warning";
  }

  if (label.includes("entr")) {
    return "success";
  }

  return "info";
}

export default function Mouvements({ references, refreshKey, sharedTable }) {
  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [articleFilter, setArticleFilter] = useState("");
  const [typeFilter, setTypeFilter] = useState("");
  const [commandeFilter, setCommandeFilter] = useState("");
  const [originFilter, setOriginFilter] = useState("all");
  const [stockDirectionFilter, setStockDirectionFilter] = useState("all");
  const [dateFrom, setDateFrom] = useState("");
  const [dateTo, setDateTo] = useState("");
  const selectedMouvement = sharedTable?.selectedRow || null;
  const deferredSearch = useDeferredValue(sharedTable?.searchValue || "");

  const articleOptions = useMemo(() => buildReferenceOptions(references?.articles, "Article"), [references]);
  const mouvementTypeOptions = useMemo(() => buildReferenceOptions(references?.commandeTypes, "Type"), [references]);
  const typeLabelMap = useMemo(() => buildReferenceLabelMap(mouvementTypeOptions), [mouvementTypeOptions]);
  const visibleRows = useMemo(
    () =>
      rows.filter((row) => {
        if (commandeFilter && !String(row.CodeCmd || "").toLowerCase().includes(String(commandeFilter).toLowerCase())) {
          return false;
        }

        if (originFilter !== "all" && String(row.OrigineMouvement || "") !== originFilter) {
          return false;
        }

        if (stockDirectionFilter === "entree" && Number(row.SigneStock || 0) <= 0) {
          return false;
        }

        if (stockDirectionFilter === "sortie" && Number(row.SigneStock || 0) >= 0) {
          return false;
        }

        return true;
      }),
    [commandeFilter, originFilter, rows, stockDirectionFilter]
  );
  const summary = useMemo(
    () =>
      visibleRows.reduce(
        (accumulator, row) => {
          accumulator.total += 1;
          accumulator.quantite += Number(row.QteMvt || 0);

          const label = String(row.NomTypeMvt || row.TypeMvt || typeLabelMap.get(String(row.ID_TypeMvtFk)) || "").toLowerCase();

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
      { key: "ID_Mvt", label: "ID mouvement", renderText: (row) => String(row.ID_Mvt || "-") },
      { key: "DateMvt", label: "Date mouvement", renderText: (row) => formatDate(row.DateMvt, { withTime: true }) },
      { key: "CodeArticleInterne", label: "Code article", renderText: (row) => row.CodeArticleInterne || "-" },
      { key: "NomArticle", label: "Article" },
      { key: "CodeCmd", label: "Code commande", renderText: (row) => row.CodeCmd || "-" },
      {
        key: "ID_TypeMvtFk",
        label: "Type mouvement",
        renderText: (row) =>
          row.NomTypeMvt || row.TypeMvt || typeLabelMap.get(String(row.ID_TypeMvtFk)) || `#${row.ID_TypeMvtFk ?? "-"}`,
      },
      { key: "QteMvt", label: "Quantite", renderText: (row) => formatNumber(row.QteMvt) },
      { key: "QteMvtSigned", label: "Quantite signee", renderText: (row) => formatNumber(row.QteMvtSigned) },
      { key: "PUMvt", label: "PU mouvement", renderText: (row) => formatCurrency(row.PUMvt) },
      { key: "MontantMvt", label: "Montant mouvement", renderText: (row) => formatCurrency(row.MontantMvt) },
      {
        key: "MontantMvtSigned",
        label: "Montant signe",
        renderText: (row) =>
          formatCurrency(
            row.MontantMvtSigned != null ? row.MontantMvtSigned : Number(row.MontantMvt || 0) * Number(row.SigneStock || 0)
          ),
      },
      { key: "OrigineMouvement", label: "Origine mouvement", renderText: (row) => row.OrigineMouvement || "-" },
      { key: "actions", label: "Actions", renderText: () => "" },
    ],
    [typeLabelMap]
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
    <div className="logistics-screen">
      <header className="logistics-screen-copy">
        <h1>Historique des mouvements</h1>
        <p>Trace les entrees et sorties de stock issues de la logique metier existante</p>
      </header>

      <section className="logistics-screen-search-card">
        <label className="admin-form-field logistics-screen-search-field">
          <span>{sharedTable?.searchLabel || "Recherche"}</span>
          <input
            type="search"
            value={sharedTable?.searchValue || ""}
            onChange={(event) => sharedTable?.setSearchValue?.(event.target.value)}
            placeholder="Rechercher un mouvement, article ou commande..."
          />
        </label>
      </section>

      <section className="logistics-top-actions">
        <button type="button" className="logistics-top-action is-cyan" onClick={() => selectedMouvement && sharedTable?.setSelectedRow?.(selectedMouvement)} disabled={!selectedMouvement}>
          Voir
        </button>
        <button type="button" className="logistics-top-action is-green" onClick={() => exportRowsToCsv("logistique-mouvements.csv", compactColumns, visibleRows)} disabled={visibleRows.length === 0}>
          Exporter
        </button>
        <button type="button" className="logistics-top-action is-purple" onClick={() => exportRowsToPdf("logistique-mouvements", compactColumns, visibleRows)} disabled={visibleRows.length === 0}>
          Imprimer
        </button>
        <button type="button" className="logistics-top-action is-muted" disabled>
          Autres filtres
        </button>
      </section>

      <section className="logistics-screen-filter-card">
        <div className="logistics-mockup-filter-grid">
          <SelectField label="Type mouvement" value={typeFilter} onChange={(event) => setTypeFilter(event.target.value)} options={mouvementTypeOptions} />
          <label className="admin-form-field">
            <span>Origine mouvement</span>
            <select value={originFilter} onChange={(event) => setOriginFilter(event.target.value)}>
              <option value="all">Toutes</option>
              <option value="Commande">Commande</option>
              <option value="Ajustement direct article">Ajustement direct article</option>
            </select>
          </label>
          <SelectField label="Article" value={articleFilter} onChange={(event) => setArticleFilter(event.target.value)} options={articleOptions} />
          <label className="admin-form-field">
            <span>Commande</span>
            <input type="search" value={commandeFilter} onChange={(event) => setCommandeFilter(event.target.value)} placeholder="Code commande..." />
          </label>
          <label className="admin-form-field">
            <span>Sens stock</span>
            <select value={stockDirectionFilter} onChange={(event) => setStockDirectionFilter(event.target.value)}>
              <option value="all">Tous</option>
              <option value="entree">Entree</option>
              <option value="sortie">Sortie</option>
            </select>
          </label>
          <label className="admin-form-field">
            <span>Periode</span>
            <input type="text" readOnly value={dateFrom || dateTo ? `${dateFrom || "..."} - ${dateTo || "..."}` : "Toutes"} />
          </label>
        </div>
      </section>

      <section className="logistics-screen-table-card">
        <LoadingErrorEmpty loading={loading} error={error} rows={visibleRows} emptyMessage="Aucun mouvement a afficher." />

        {!loading && !error && visibleRows.length > 0 ? (
          <SimpleTable
            rows={visibleRows}
            selectedRowId={selectedMouvement?.ID_Mvt || null}
            onRowSelect={sharedTable?.setSelectedRow}
            enableSelection={false}
            showControls={false}
            defaultPinnedColumns={["DateMvt", "NomArticle"]}
            defaultSortColumn="DateMvt"
            defaultRowsPerPage={10}
            exportFilename={sharedTable?.exportFilename || "logistique-v_mouvement.csv"}
            columns={compactColumns.map((column) => ({
              ...column,
              render: (row) => {
                if (column.key === "ID_Mvt") {
                  return row.ID_Mvt;
                }

                if (column.key === "DateMvt") {
                  return formatDate(row.DateMvt, { withTime: true });
                }

                if (column.key === "ID_TypeMvtFk") {
                  return (
                    <ToneBadge tone={getMovementTone(row)}>
                      {row.NomTypeMvt || row.TypeMvt || typeLabelMap.get(String(row.ID_TypeMvtFk)) || `#${row.ID_TypeMvtFk ?? "-"}`}
                    </ToneBadge>
                  );
                }

                if (column.key === "CodeArticleInterne") {
                  return row.CodeArticleInterne || "-";
                }

                if (column.key === "CodeCmd") {
                  return row.CodeCmd || "-";
                }

                if (column.key === "QteMvt" || column.key === "QteMvtSigned") {
                  return formatNumber(row[column.key]);
                }

                if (column.key === "PUMvt" || column.key === "MontantMvt") {
                  return formatCurrency(row[column.key]);
                }

                if (column.key === "MontantMvtSigned") {
                  return formatCurrency(
                    row.MontantMvtSigned != null
                      ? row.MontantMvtSigned
                      : Number(row.MontantMvt || 0) * Number(row.SigneStock || 0)
                  );
                }

                if (column.key === "OrigineMouvement") {
                  return (
                    <ToneBadge tone={row.OrigineMouvement === "Commande" ? "info" : "warning"}>
                      {row.OrigineMouvement || "-"}
                    </ToneBadge>
                  );
                }

                if (column.key === "actions") {
                  return (
                    <div className="logistics-table-actions" onClick={(event) => event.stopPropagation()}>
                      <button
                        type="button"
                        className="logistics-kebab-button"
                        onClick={() => sharedTable?.setSelectedRow?.(row)}
                        aria-label={`Actions ${row.CodeArticleInterne || "mouvement"}`}
                      >
                        &#8942;
                      </button>
                    </div>
                  );
                }

                return row[column.key] ?? "-";
              },
            }))}
          />
        ) : null}
      </section>
    </div>
  );
}
