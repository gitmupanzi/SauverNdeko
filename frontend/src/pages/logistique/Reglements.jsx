import { useEffect, useMemo, useState } from "react";
import {
  createLogistiqueReglement,
  fetchLogistiqueReglementEntries,
  fetchLogistiqueReglements,
  updateLogistiqueReglement,
} from "../../services/logistique";
import {
  asArrayPayload,
  buildReferenceLabelMap,
  buildReferenceOptions,
  formatCurrency,
  formatDate,
  getApiMessage,
  LoadingErrorEmpty,
  SectionCard,
  SelectionStrip,
  SelectField,
  SimpleTable,
  StatusBanner,
  TableToolbar,
  ToneBadge,
  toInputDateValue,
} from "./logistiqueShared";

function createReglementFormState() {
  return {
    CodeFactureFk: "",
    ID_ModeReglementFk: "",
    ID_ClientFk: "",
    DateReglement: "",
    MontantRegle: "",
  };
}

function mapReglementToForm(reglement) {
  return {
    CodeFactureFk: reglement.CodeFactureFk || "",
    ID_ModeReglementFk: reglement.ID_ModeReglementFk ? String(reglement.ID_ModeReglementFk) : "",
    ID_ClientFk: reglement.ID_ClientFk ? String(reglement.ID_ClientFk) : "",
    DateReglement: toInputDateValue(reglement.DateReglement),
    MontantRegle: reglement.MontantRegle != null ? String(reglement.MontantRegle) : "",
  };
}

export default function Reglements({ references, refreshKey, onDataChanged, sharedTable }) {
  const [summaryRows, setSummaryRows] = useState([]);
  const [entryRows, setEntryRows] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [feedback, setFeedback] = useState(null);
  const [codeFactureFilter, setCodeFactureFilter] = useState("");
  const [editorMode, setEditorMode] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [formValues, setFormValues] = useState(createReglementFormState());
  const selectedEntry = sharedTable?.selectedRow || null;

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

  useEffect(() => {
    let isMounted = true;

    async function loadReglements() {
      setLoading(true);
      setError("");

      const [summaryResponse, entriesResponse] = await Promise.all([
        fetchLogistiqueReglements({
          codeFacture: codeFactureFilter,
          take: 120,
        }),
        fetchLogistiqueReglementEntries({
          codeFacture: codeFactureFilter,
          take: 120,
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
  }, [codeFactureFilter, refreshKey]);

  function resetEditor() {
    setEditorMode("");
    sharedTable?.clearSelectedRow?.();
    setFormValues(createReglementFormState());
  }

  function handleNewReglement() {
    sharedTable?.clearSelectedRow?.();
    setEditorMode("create");
    setFormValues(createReglementFormState());
  }

  function handleEditReglement(entry) {
    sharedTable?.setSelectedRow?.(entry);
    setEditorMode("edit");
    setFormValues(mapReglementToForm(entry));
  }

  async function handleSubmit(event) {
    event.preventDefault();
    setSubmitting(true);

    const payload = {
      ...formValues,
      ID_ClientFk: formValues.ID_ClientFk || null,
      DateReglement: formValues.DateReglement || null,
    };

    const response =
      editorMode === "edit" && selectedEntry
        ? await updateLogistiqueReglement(selectedEntry.ID_Reglement, payload)
        : await createLogistiqueReglement(payload);

    setSubmitting(false);

    if (!response?.success) {
      setFeedback({ type: "error", message: getApiMessage(response, "Enregistrement du reglement impossible.") });
      return;
    }

    setFeedback({
      type: "success",
      message: editorMode === "edit" ? "Reglement mis a jour avec succes." : "Reglement cree avec succes.",
    });
    resetEditor();
    onDataChanged?.();
  }

  return (
    <div className="logistics-stack">
      <StatusBanner feedback={feedback} />

      <SectionCard
        title="Suivi des reglements"
        subtitle="Vue V_SuiviReglements pour la synthese et T_Reglements pour la saisie."
        actions={
          <button type="button" className="secondary-action" onClick={handleNewReglement}>
            Nouveau reglement
          </button>
        }
      >
        <div className="logistics-filter-grid">
          <SelectField
            label={sharedTable?.searchLabel || "Code facture"}
            value={codeFactureFilter}
            onChange={(event) => setCodeFactureFilter(event.target.value)}
            options={factureOptions}
          />
        </div>

        <TableToolbar
          title={sharedTable?.toolbarTitle || "Tableau V_SuiviReglements"}
          rows={summaryRows}
          columns={[
            { key: "ID_Commande", label: "Commande", exportValue: (row) => `#${row.ID_Commande}` },
            { key: "CodeFacture", label: "Facture" },
            { key: "MontantTTC", label: "Facture TTC", renderText: (row) => formatCurrency(row.MontantTTC) },
            { key: "TotalRegle", label: "Regle", renderText: (row) => formatCurrency(row.TotalRegle) },
            { key: "Reste", label: "Reste", renderText: (row) => formatCurrency(row.Reste) },
          ]}
          exportFilename={sharedTable?.exportFilename || "logistique-v_suivi_reglements.csv"}
        />

        <LoadingErrorEmpty loading={loading} error={error} rows={summaryRows} emptyMessage="Aucun suivi de reglement disponible." />

        {!loading && !error && summaryRows.length > 0 ? (
          <SimpleTable
            rows={summaryRows}
            enableSelection
            defaultPinnedColumns={["ID_Commande", "CodeFacture"]}
            defaultSortColumn="Reste"
            columns={[
              { key: "ID_Commande", label: "Commande", render: (row) => `#${row.ID_Commande}` },
              { key: "CodeFacture", label: "Facture" },
              { key: "MontantTTC", label: "Facture TTC", render: (row) => formatCurrency(row.MontantTTC) },
              { key: "TotalRegle", label: "Regle", render: (row) => formatCurrency(row.TotalRegle) },
              {
                key: "Reste",
                label: "Reste",
                render: (row) =>
                  Number(row.Reste || 0) > 0 ? <ToneBadge tone="danger">{formatCurrency(row.Reste)}</ToneBadge> : <ToneBadge tone="success">Solde</ToneBadge>,
              },
            ]}
          />
        ) : null}
      </SectionCard>

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
