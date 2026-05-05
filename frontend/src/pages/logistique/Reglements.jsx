import { useEffect, useMemo, useState } from "react";
import {
  asArrayPayload,
  buildReferenceLabelMap,
  buildReferenceOptions,
  exportRowsToCsv,
  exportRowsToPdf,
  formatCurrency,
  formatDate,
  getApiMessage,
  LoadingErrorEmpty,
  SectionCard,
  SelectionStrip,
  SelectField,
  SimpleTable,
  SummaryCard,
  StatusBanner,
  TableToolbar,
  ToneBadge,
} from "./logistiqueShared";
import {
  getLogistiqueCrudConfig,
  getLogistiqueGenericSourceHint,
  getLogistiqueViewConfig,
} from "./views";

const REGLEMENTS_VIEW_CONFIG = getLogistiqueViewConfig("reglements");
const REGLEMENTS_CRUD_CONFIG = getLogistiqueCrudConfig("reglements");

function buildReferenceHelperText(sourceKey, options) {
  const count = Array.isArray(options) ? options.length : 0;
  return `${getLogistiqueGenericSourceHint(sourceKey)} | ${count} option(s) chargee(s)`;
}

function getReglementState(row) {
  const label = String(row?.EtatReglement || "");
  const normalized = label
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "");

  if (normalized.includes("part")) {
    return { key: "partielle", label: label || "Partiellement reglee", tone: "warning" };
  }

  if (normalized.includes("non facture")) {
    return { key: "non-facturee", label: label || "Non facturee", tone: "info" };
  }

  if (normalized.includes("non reglee")) {
    return { key: "non-reglee", label: label || "Non reglee", tone: "danger" };
  }

  return { key: "reglee", label: label || "Reglee", tone: "success" };
}

export default function Reglements({ references, refreshKey, onDataChanged, sharedTable, onOpenCommande, onToggleFkMappings }) {
  const [summaryRows, setSummaryRows] = useState([]);
  const [entryRows, setEntryRows] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [feedback, setFeedback] = useState(null);
  const [codeFactureFilter, setCodeFactureFilter] = useState("");
  const [clientFilter, setClientFilter] = useState("");
  const [lateFilter, setLateFilter] = useState("all");
  const [factureDateFilter, setFactureDateFilter] = useState("");
  const [echeanceFilter, setEcheanceFilter] = useState("");
  const [dateFrom, setDateFrom] = useState("");
  const [dateTo, setDateTo] = useState("");
  const [paymentStateFilter, setPaymentStateFilter] = useState("all");
  const [editorMode, setEditorMode] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [formValues, setFormValues] = useState(() => REGLEMENTS_CRUD_CONFIG.createFormState());
  const selectedEntry = sharedTable?.selectedRow || null;
  const [selectedSummary, setSelectedSummary] = useState(null);

  const modeOptions = useMemo(() => buildReferenceOptions(references?.reglementModes, "Mode"), [references]);
  const clientOptions = useMemo(() => buildReferenceOptions(references?.clients, "Client"), [references]);
  const modeLabelMap = useMemo(() => buildReferenceLabelMap(modeOptions), [modeOptions]);
  const clientLabelMap = useMemo(() => buildReferenceLabelMap(clientOptions), [clientOptions]);
  const factureOptions = useMemo(
    () =>
      Array.isArray(references?.factures)
        ? references.factures.map((item) => ({
            value: item.code,
            label: item.label,
          }))
        : [],
    [references]
  );
  const summaryVisibleRows = useMemo(
    () =>
      summaryRows.filter((row) => {
        const paymentState = getReglementState(row);
        const normalizedSearch = String(codeFactureFilter || "")
          .toLowerCase()
          .normalize("NFD")
          .replace(/[\u0300-\u036f]/g, "");
        const rowSearch = [row.CodeCmd, row.CodeFacture, row.NomClientSaisi]
          .filter(Boolean)
          .join(" ")
          .toLowerCase()
          .normalize("NFD")
          .replace(/[\u0300-\u036f]/g, "");

        if (normalizedSearch && !rowSearch.includes(normalizedSearch)) {
          return false;
        }

        if (paymentStateFilter !== "all" && paymentState.key !== paymentStateFilter) {
          return false;
        }

        if (lateFilter === "oui" && !row.EstEnRetard) {
          return false;
        }

        if (lateFilter === "non" && row.EstEnRetard) {
          return false;
        }

        if (factureDateFilter && row.DateFacture) {
          const currentDate = new Date(row.DateFacture).toISOString().slice(0, 10);
          if (currentDate !== factureDateFilter) {
            return false;
          }
        }

        if (echeanceFilter && row.DateEcheancePaiement) {
          const currentDate = new Date(row.DateEcheancePaiement).toISOString().slice(0, 10);
          if (currentDate !== echeanceFilter) {
            return false;
          }
        }

        if (
          clientFilter &&
          String(row.NomClientSaisi || "") !== String(clientLabelMap.get(String(clientFilter)) || clientFilter)
        ) {
          return false;
        }

        if (dateFrom && row.DateFacture && new Date(row.DateFacture) < new Date(dateFrom)) {
          return false;
        }

        if (dateTo && row.DateFacture && new Date(row.DateFacture) > new Date(`${dateTo}T23:59:59`)) {
          return false;
        }

        return true;
      }),
    [clientFilter, clientLabelMap, codeFactureFilter, dateFrom, dateTo, echeanceFilter, factureDateFilter, lateFilter, paymentStateFilter, summaryRows]
  );
  const summaryByFacture = useMemo(
    () => new Map(summaryRows.map((row) => [String(row.CodeFacture || ""), row])),
    [summaryRows]
  );
  const summaryMetrics = useMemo(
    () =>
      summaryVisibleRows.reduce(
        (accumulator, row) => {
          accumulator.total += 1;
          accumulator.totalFacture += Number(row.MontantTTC || 0);
          accumulator.totalRegle += Number(row.TotalRegle || 0);

          if (Number(row.Reste || 0) > 0) {
            accumulator.impayes += 1;
          } else {
            accumulator.payes += 1;
          }

          return accumulator;
        },
        { total: 0, totalFacture: 0, totalRegle: 0, payes: 0, impayes: 0 }
      ),
    [summaryVisibleRows]
  );
  const summaryColumns = useMemo(
    () => [
      { key: "ID_Commande", label: "Commande", exportValue: (row) => `#${row.ID_Commande}` },
      { key: "CodeFacture", label: "Facture" },
      { key: "MontantTTC", label: "Facture TTC", renderText: (row) => formatCurrency(row.MontantTTC) },
      { key: "TotalRegle", label: "Regle", renderText: (row) => formatCurrency(row.TotalRegle) },
      { key: "Reste", label: "Reste", renderText: (row) => formatCurrency(row.Reste) },
    ],
    []
  );

  useEffect(() => {
    let isMounted = true;

    async function loadReglements() {
      setLoading(true);
      setError("");

      const [summaryResponse, entriesResponse] = await Promise.all([
        REGLEMENTS_VIEW_CONFIG.fetchRows({
          codeFacture: codeFactureFilter,
          resteOnly: paymentStateFilter === "non-reglee" || paymentStateFilter === "partielle" ? "true" : "",
          take: 200,
        }),
        REGLEMENTS_VIEW_CONFIG.fetchEntries({
          codeFacture: codeFactureFilter,
          client: clientFilter,
          dateFrom,
          dateTo,
          take: 200,
        }),
      ]);

      if (!isMounted) {
        return;
      }

      if (!summaryResponse?.success || !entriesResponse?.success) {
        setSummaryRows([]);
        setEntryRows([]);
        setError(summaryResponse?.message || entriesResponse?.message || "Impossible de charger les reglements.");
        setLoading(false);
        return;
      }

      const nextSummaryRows = asArrayPayload(summaryResponse);
      const nextEntryRows = asArrayPayload(entriesResponse);
      setSummaryRows(nextSummaryRows);
      setEntryRows(nextEntryRows);
      if (selectedSummary?.ID_Commande != null) {
        const matchedSummary = nextSummaryRows.find((row) => row.ID_Commande === selectedSummary.ID_Commande);
        setSelectedSummary(matchedSummary || null);
      }
      if (selectedEntry?.ID_Reglement != null) {
        const matchedEntry = nextEntryRows.find((row) => row.ID_Reglement === selectedEntry.ID_Reglement);
        if (matchedEntry) {
          sharedTable?.setSelectedRow?.(matchedEntry);
        } else {
          sharedTable?.clearSelectedRow?.();
        }
      }
      setLoading(false);
    }

    loadReglements();

    return () => {
      isMounted = false;
    };
  }, [clientFilter, codeFactureFilter, dateFrom, dateTo, paymentStateFilter, refreshKey]);

  function resetEditor() {
    setEditorMode("");
    sharedTable?.clearSelectedRow?.();
    setFormValues(REGLEMENTS_CRUD_CONFIG.createFormState());
  }

  function handleNewReglement() {
    sharedTable?.clearSelectedRow?.();
    setEditorMode("create");
    setFormValues({
      ...REGLEMENTS_CRUD_CONFIG.createFormState(),
      CodeFactureFk: selectedSummary?.CodeFacture || "",
    });
  }

  function handleEditReglement(entry) {
    sharedTable?.setSelectedRow?.(entry);
    setEditorMode("edit");
    setFormValues(REGLEMENTS_CRUD_CONFIG.mapRecordToForm(entry));
  }

  async function handleSubmit(event) {
    event.preventDefault();
    setSubmitting(true);

    const payload = REGLEMENTS_CRUD_CONFIG.buildPayload(formValues, {
      mode: editorMode,
      record: selectedEntry,
    });

    const response =
      editorMode === "edit" && selectedEntry
        ? await REGLEMENTS_CRUD_CONFIG.updateRecord({ record: selectedEntry, payload })
        : await REGLEMENTS_CRUD_CONFIG.createRecord({ payload });

    setSubmitting(false);

    if (!response?.success) {
      setFeedback({ type: "error", message: getApiMessage(response, "Enregistrement du reglement impossible.") });
      return;
    }

    setFeedback({
      type: "success",
      message:
        editorMode === "edit"
          ? REGLEMENTS_CRUD_CONFIG.messages.updateSuccess
          : REGLEMENTS_CRUD_CONFIG.messages.createSuccess,
    });
    resetEditor();
    onDataChanged?.();
  }

  return (
    <div className="logistics-screen">
      <StatusBanner feedback={feedback} />
      <header className="logistics-screen-copy">
        <h1>Reglements</h1>
        <p>Suivi des factures, paiements, restes a payer et retards</p>
      </header>

      <section className="logistics-screen-search-card">
        <label className="admin-form-field logistics-screen-search-field">
          <span>{sharedTable?.searchLabel || "Recherche"}</span>
          <input
            type="search"
            value={codeFactureFilter}
            onChange={(event) => setCodeFactureFilter(event.target.value)}
            placeholder="Rechercher une facture, commande ou client..."
          />
        </label>
      </section>

      <section className="logistics-top-actions">
        <button type="button" className="logistics-top-action is-blue" onClick={handleNewReglement}>
          Ajouter reglement
        </button>
        <button type="button" className="logistics-top-action is-indigo" onClick={() => selectedEntry && handleEditReglement(selectedEntry)} disabled={!selectedEntry}>
          Modifier reglement
        </button>
        <button
          type="button"
          className="logistics-top-action is-cyan"
          onClick={() => selectedSummary && onOpenCommande?.({ ID_Commande: selectedSummary.ID_Commande, CodeCmd: selectedSummary.CodeCmd }, "view")}
          disabled={!selectedSummary || !onOpenCommande}
        >
          Voir commande
        </button>
        <button
          type="button"
          className="logistics-top-action is-green"
          onClick={() => exportRowsToCsv("logistique-reglements-synthese.csv", summaryColumns, summaryVisibleRows)}
          disabled={summaryVisibleRows.length === 0}
        >
          Exporter
        </button>
        <button
          type="button"
          className="logistics-top-action is-purple"
          onClick={() => exportRowsToPdf("logistique-reglements-synthese", summaryColumns, summaryVisibleRows)}
          disabled={summaryVisibleRows.length === 0}
        >
          Imprimer
        </button>
        <button type="button" className="logistics-top-action is-sky" onClick={onToggleFkMappings}>
          Correspondance FK
        </button>
        <button type="button" className="logistics-top-action is-muted" disabled>
          Autres filtres
        </button>
      </section>

      <section className="logistics-screen-filter-card">
        <div className="logistics-mockup-filter-grid">
          <label className="admin-form-field">
            <span>Etat reglement</span>
            <select value={paymentStateFilter} onChange={(event) => setPaymentStateFilter(event.target.value)}>
              <option value="all">Toutes</option>
              <option value="reglee">Reglee</option>
              <option value="partielle">Partiellement reglee</option>
              <option value="non-reglee">Non reglee</option>
              <option value="non-facturee">Non facturee</option>
            </select>
          </label>

          <label className="admin-form-field">
            <span>Retard paiement</span>
            <select value={lateFilter} onChange={(event) => setLateFilter(event.target.value)}>
              <option value="all">Toutes</option>
              <option value="oui">Oui</option>
              <option value="non">Non</option>
            </select>
          </label>

          <SelectField label="Client" value={clientFilter} onChange={(event) => setClientFilter(event.target.value)} options={clientOptions} />

          <label className="admin-form-field">
            <span>Date facture</span>
            <input type="date" value={factureDateFilter} onChange={(event) => setFactureDateFilter(event.target.value)} />
          </label>

          <label className="admin-form-field">
            <span>Echeance</span>
            <input type="date" value={echeanceFilter} onChange={(event) => setEcheanceFilter(event.target.value)} />
          </label>

          <label className="admin-form-field">
            <span>Periode</span>
            <input type="text" readOnly value={dateFrom || dateTo ? `${dateFrom || "..."} - ${dateTo || "..."}` : "Selectionner"} />
          </label>
        </div>
      </section>

      <section className="logistics-screen-table-card">
        <LoadingErrorEmpty loading={loading} error={error} rows={summaryVisibleRows} emptyMessage="Aucun suivi de reglement disponible." />

        {!loading && !error && summaryVisibleRows.length > 0 ? (
          <SimpleTable
            rows={summaryVisibleRows}
            selectedRowId={selectedSummary?.ID_Commande || null}
            onRowSelect={setSelectedSummary}
            enableSelection
            showControls={false}
            defaultPinnedColumns={["CodeFacture", "DateFacture"]}
            defaultSortColumn="Reste"
            defaultRowsPerPage={10}
            columns={[
              { key: "CodeCmd", label: "Code commande", render: (row) => row.CodeCmd || `#${row.ID_Commande}` },
              { key: "CodeFacture", label: "Code facture", render: (row) => row.CodeFacture || "-" },
              { key: "DateFacture", label: "Date facture", render: (row) => formatDate(row.DateFacture) },
              { key: "DateEcheancePaiement", label: "Echeance", render: (row) => formatDate(row.DateEcheancePaiement) },
              { key: "NomClientSaisi", label: "Client", render: (row) => row.NomClientSaisi || "-" },
              { key: "MontantTTC", label: "Montant TTC", render: (row) => formatCurrency(row.MontantTTC) },
              { key: "TotalRegle", label: "Total regle", render: (row) => formatCurrency(row.TotalRegle) },
              {
                key: "Reste",
                label: "Reste",
                render: (row) => <ToneBadge tone={Number(row.Reste || 0) > 0 ? "danger" : "success"}>{formatCurrency(row.Reste)}</ToneBadge>,
              },
              { key: "NbReglements", label: "Nombre reglements", render: (row) => row.NbReglements ?? 0 },
              { key: "DernierReglement", label: "Dernier reglement", render: (row) => formatDate(row.DernierReglement) },
              { key: "JoursAvantEcheance", label: "Jours avant echeance", render: (row) => row.JoursAvantEcheance ?? "-" },
              {
                key: "EtatReglement",
                label: "Etat reglement",
                render: (row) => {
                  const state = getReglementState(row);
                  return <ToneBadge tone={state.tone}>{state.label}</ToneBadge>;
                },
              },
              {
                key: "Retard",
                label: "Retard",
                render: (row) => <ToneBadge tone={row.EstEnRetard ? "danger" : "success"}>{row.EstEnRetard ? "Oui" : "Non"}</ToneBadge>,
              },
            ]}
          />
        ) : null}
      </section>

      <SectionCard title="Ecritures de reglement" subtitle="Historique modifiable des lignes de T_Reglements.">
        <SelectionStrip
          selectedRow={selectedEntry}
          label={selectedEntry ? `Ligne selectionnee: reglement #${selectedEntry.ID_Reglement}` : "Aucune ligne selectionnee"}
          description={
            selectedEntry
              ? `${selectedEntry.CodeFactureFk || "-"} | ${formatCurrency(selectedEntry.MontantRegle)}`
              : "Selectionnez une ecriture pour la consulter ou la modifier plus vite."
          }
          actions={
            selectedEntry ? (
              <button type="button" className="secondary-action" onClick={() => handleEditReglement(selectedEntry)}>
                Modifier
              </button>
            ) : null
          }
        />

        <TableToolbar
          title="Ecritures T_Reglements"
          rows={entryRows}
          columns={[
            { key: "DateReglement", label: "Date", renderText: (row) => formatDate(row.DateReglement) },
            { key: "CodeFactureFk", label: "Facture" },
            { key: "ID_ClientFk", label: "Client", renderText: (row) => clientLabelMap.get(String(row.ID_ClientFk)) || row.ID_ClientFk || "-" },
            {
              key: "ID_ModeReglementFk",
              label: "Mode",
              renderText: (row) => row.T_Generique?.NomGenerique || modeLabelMap.get(String(row.ID_ModeReglementFk)) || row.ID_ModeReglementFk,
            },
            { key: "MontantRegle", label: "Montant", renderText: (row) => formatCurrency(row.MontantRegle) },
          ]}
          exportFilename="logistique-reglements.csv"
        />

        <LoadingErrorEmpty loading={loading} error={error} rows={entryRows} emptyMessage="Aucune ecriture de reglement disponible." />

        {!loading && !error && entryRows.length > 0 ? (
          <SimpleTable
            rows={entryRows}
            selectedRowId={selectedEntry?.ID_Reglement || null}
            onRowSelect={sharedTable?.setSelectedRow}
            defaultPinnedColumns={["DateReglement", "CodeFactureFk"]}
            defaultSortColumn="DateReglement"
            exportFilename="logistique-reglements.csv"
            columns={[
              { key: "DateReglement", label: "Date", render: (row) => formatDate(row.DateReglement) },
              { key: "CodeFactureFk", label: "Facture" },
              {
                key: "ID_ClientFk",
                label: "Client",
                render: (row) => clientLabelMap.get(String(row.ID_ClientFk)) || (row.ID_ClientFk ? `#${row.ID_ClientFk}` : "-"),
              },
              {
                key: "T_Generique",
                label: "Mode",
                render: (row) =>
                  row.T_Generique?.NomGenerique ||
                  modeLabelMap.get(String(row.ID_ModeReglementFk)) ||
                  `#${row.ID_ModeReglementFk}`,
              },
              { key: "MontantRegle", label: "Montant", render: (row) => formatCurrency(row.MontantRegle) },
              {
                key: "EtatPaiement",
                label: "Etat",
                render: (row) =>
                  Number(summaryByFacture.get(String(row.CodeFactureFk || ""))?.Reste || 0) > 0 ? (
                    <ToneBadge tone="warning">Impaye</ToneBadge>
                  ) : (
                    <ToneBadge tone="success">Paye</ToneBadge>
                  ),
              },
              {
                key: "actions",
                label: "Actions",
                render: (row) => (
                  <div className="logistics-table-actions" onClick={(event) => event.stopPropagation()}>
                    <button type="button" className="secondary-action" onClick={() => sharedTable?.setSelectedRow?.(row)}>
                      Voir
                    </button>
                    <button type="button" className="secondary-action" onClick={() => handleEditReglement(row)}>
                      Modifier
                    </button>
                  </div>
                ),
              },
            ]}
          />
        ) : null}
      </SectionCard>

      {selectedEntry ? (
        <SectionCard title="Reglement selectionne" subtitle="Lecture detaillee de l'ecriture choisie.">
          <div className="logistics-detail-grid">
            <article>
              <strong>{selectedEntry.CodeFactureFk}</strong>
              <p>Montant: {formatCurrency(selectedEntry.MontantRegle)}</p>
            </article>
            <article>
              <p>Date: {formatDate(selectedEntry.DateReglement)}</p>
              <p>
                Mode:{" "}
                {selectedEntry.T_Generique?.NomGenerique ||
                  modeLabelMap.get(String(selectedEntry.ID_ModeReglementFk)) ||
                  `#${selectedEntry.ID_ModeReglementFk}`}
              </p>
              <p>Client: {clientLabelMap.get(String(selectedEntry.ID_ClientFk)) || (selectedEntry.ID_ClientFk ? `#${selectedEntry.ID_ClientFk}` : "-")}</p>
              <p>
                Etat:{" "}
                {Number(summaryByFacture.get(String(selectedEntry.CodeFactureFk || ""))?.Reste || 0) > 0
                  ? "Impaye"
                  : "Paye"}
              </p>
            </article>
          </div>
        </SectionCard>
      ) : null}

      {editorMode ? (
        <SectionCard
          title={editorMode === "edit" ? "Modifier le reglement" : "Saisir un reglement"}
          subtitle="Creation et modification dans T_Reglements seulement."
        >
          <form className="admin-editor-form" onSubmit={handleSubmit}>
            <div className="admin-editor-grid">
              <SelectField
                label="Code facture"
                value={formValues.CodeFactureFk}
                onChange={(event) => setFormValues((current) => ({ ...current, CodeFactureFk: event.target.value }))}
                options={factureOptions}
                allowEmpty={false}
              />

              <SelectField
                label="Mode de reglement"
                value={formValues.ID_ModeReglementFk}
                onChange={(event) =>
                  setFormValues((current) => ({ ...current, ID_ModeReglementFk: event.target.value }))
                }
                options={modeOptions}
                allowEmpty={false}
                disabled={modeOptions.length === 0}
                helperText={buildReferenceHelperText("logistique.reglementModes", modeOptions)}
              />

              <SelectField
                label="Client"
                value={formValues.ID_ClientFk}
                onChange={(event) => setFormValues((current) => ({ ...current, ID_ClientFk: event.target.value }))}
                options={clientOptions}
              />

              <label className="admin-form-field">
                <span>Date reglement</span>
                <input
                  type="date"
                  value={formValues.DateReglement}
                  onChange={(event) => setFormValues((current) => ({ ...current, DateReglement: event.target.value }))}
                />
              </label>

              <label className="admin-form-field">
                <span>Montant regle</span>
                <input
                  type="number"
                  min="0"
                  step="0.01"
                  value={formValues.MontantRegle}
                  onChange={(event) => setFormValues((current) => ({ ...current, MontantRegle: event.target.value }))}
                  required
                />
              </label>
            </div>

            <div className="admin-editor-actions">
              <button type="button" className="secondary-action" onClick={resetEditor} disabled={submitting}>
                Annuler
              </button>
              <button type="submit" className="primary-action" disabled={submitting}>
                {submitting ? "Enregistrement..." : "Enregistrer"}
              </button>
            </div>
          </form>
        </SectionCard>
      ) : null}
    </div>
  );
}
