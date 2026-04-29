import { useDeferredValue, useEffect, useMemo, useState } from "react";
import {
  asArrayPayload,
  buildReferenceLabelMap,
  buildReferenceOptions,
  formatCurrency,
  formatDate,
  formatNumber,
  LoadingErrorEmpty,
  SectionCard,
  SelectionStrip,
  SelectField,
  SimpleTable,
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
  const [dateFrom, setDateFrom] = useState("");
  const [dateTo, setDateTo] = useState("");
  const selectedMouvement = sharedTable?.selectedRow || null;
  const deferredSearch = useDeferredValue(sharedTable?.searchValue || "");

  const articleOptions = useMemo(() => buildReferenceOptions(references?.articles, "Article"), [references]);
  const mouvementTypeOptions = useMemo(() => buildReferenceOptions(references?.commandeTypes, "Type"), [references]);
  const typeLabelMap = useMemo(() => buildReferenceLabelMap(mouvementTypeOptions), [mouvementTypeOptions]);

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
    <div className="logistics-stack">
      <SectionCard
        title="Historique des mouvements"
        subtitle='Lecture seule via la vue V_Mouvement. Aucun CRUD direct sur T_Mouvement.'
      >
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
          title={sharedTable?.toolbarTitle || "Tableau V_Mouvement"}
          rows={rows}
          columns={[
            { key: "DateMvt", label: "Date", renderText: (row) => formatDate(row.DateMvt, { withTime: true }) },
            {
              key: "ID_TypeMvtFk",
              label: "Type",
              renderText: (row) => row.TypeMvt || typeLabelMap.get(String(row.ID_TypeMvtFk)) || `#${row.ID_TypeMvtFk ?? "-"}`,
            },
            { key: "NomArticle", label: "Article" },
            { key: "CodeCmd", label: "Commande", renderText: (row) => row.CodeCmd || "-" },
            { key: "QteMvt", label: "Quantite", renderText: (row) => formatNumber(row.QteMvt) },
            { key: "PUMvt", label: "PU", renderText: (row) => formatCurrency(row.PUMvt) },
          ]}
          exportFilename={sharedTable?.exportFilename || "logistique-v_mouvement.csv"}
        />

        <LoadingErrorEmpty loading={loading} error={error} rows={rows} emptyMessage="Aucun mouvement a afficher." />

        {!loading && !error && rows.length > 0 ? (
          <SimpleTable
            rows={rows}
            selectedRowId={selectedMouvement?.ID_Mvt || null}
            onRowSelect={sharedTable?.setSelectedRow}
            defaultPinnedColumns={["DateMvt", "NomArticle"]}
            defaultSortColumn="DateMvt"
            exportFilename={sharedTable?.exportFilename || "logistique-v_mouvement.csv"}
            columns={[
              { key: "DateMvt", label: "Date", render: (row) => formatDate(row.DateMvt, { withTime: true }) },
              {
                key: "ID_TypeMvtFk",
                label: "Type",
                render: (row) => row.TypeMvt || typeLabelMap.get(String(row.ID_TypeMvtFk)) || `#${row.ID_TypeMvtFk ?? "-"}`,
              },
              { key: "NomArticle", label: "Article" },
              { key: "CodeCmd", label: "Commande", render: (row) => row.CodeCmd || "-" },
              { key: "QteMvt", label: "Quantite", render: (row) => formatNumber(row.QteMvt) },
              { key: "PUMvt", label: "PU", render: (row) => formatCurrency(row.PUMvt) },
            ]}
          />
        ) : null}
      </SectionCard>
    </div>
  );
}
