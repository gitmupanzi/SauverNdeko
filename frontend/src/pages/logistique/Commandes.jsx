import { useDeferredValue, useEffect, useMemo, useState } from "react";
import {
  createLogistiqueCommande,
  fetchLogistiqueCommandes,
  updateLogistiqueCommande,
} from "../../services/logistique";
import {
  asArrayPayload,
  buildReferenceLabelMap,
  buildReferenceOptions,
  formatCurrency,
  formatDate,
  formatNumber,
  getApiMessage,
  LoadingErrorEmpty,
  SectionCard,
  SelectionStrip,
  SelectField,
  SimpleTable,
  StatusBanner,
  TableToolbar,
  ToneBadge,
  toInputDateTimeValue,
} from "./logistiqueShared";

function createCommandeFormState() {
  return {
    ID_TypeCmdFk: "",
    ID_StatutCmd: "",
    ID_ClientFk: "",
    ID_UserFk: "",
    ID_ConditionPaiementFk: "",
    ID_ModePaiementFk: "",
    DateCmd: "",
    CodeCmd: "",
    RefCmd: "",
    MontantHT: "",
    MontantTTC: "",
    ObsCmd: "",
    CodeFacture: "",
    DateFacture: "",
    StatusFacture: "",
    DateEcheancePaiement: "",
  };
}

function mapCommandeToForm(commande) {
  return {
    ID_TypeCmdFk: commande.ID_TypeCmdFk ? String(commande.ID_TypeCmdFk) : "",
    ID_StatutCmd: commande.ID_StatutCmd ? String(commande.ID_StatutCmd) : "",
    ID_ClientFk: commande.ID_ClientFk ? String(commande.ID_ClientFk) : "",
    ID_UserFk: commande.ID_UserFk ? String(commande.ID_UserFk) : "",
    ID_ConditionPaiementFk: commande.ID_ConditionPaiementFk ? String(commande.ID_ConditionPaiementFk) : "",
    ID_ModePaiementFk: commande.ID_ModePaiementFk ? String(commande.ID_ModePaiementFk) : "",
    DateCmd: toInputDateTimeValue(commande.DateCmd),
    CodeCmd: commande.CodeCmd || "",
    RefCmd: commande.RefCmd || "",
    MontantHT: commande.MontantHT != null ? String(commande.MontantHT) : "",
    MontantTTC: commande.MontantTTC != null ? String(commande.MontantTTC) : "",
    ObsCmd: commande.ObsCmd || "",
    CodeFacture: commande.CodeFacture || "",
    DateFacture: toInputDateTimeValue(commande.DateFacture),
    StatusFacture: commande.StatusFacture || "",
    DateEcheancePaiement: toInputDateTimeValue(commande.DateEcheancePaiement),
  };
}

export default function Commandes({ references, refreshKey, onDataChanged, onOpenDetails, sharedTable }) {
  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [feedback, setFeedback] = useState(null);
  const [statusFilter, setStatusFilter] = useState("");
  const [clientFilter, setClientFilter] = useState("");
  const [dateFrom, setDateFrom] = useState("");
  const [dateTo, setDateTo] = useState("");
  const [editorMode, setEditorMode] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [formValues, setFormValues] = useState(createCommandeFormState());
  const deferredSearch = useDeferredValue(sharedTable?.searchValue || "");
  const selectedCommande = sharedTable?.selectedRow || null;

  const commandeTypeOptions = useMemo(() => buildReferenceOptions(references?.commandeTypes, "Type"), [references]);
  const commandeStatusOptions = useMemo(
    () => buildReferenceOptions(references?.commandeStatuses, "Statut"),
    [references]
  );
  const clientOptions = useMemo(() => buildReferenceOptions(references?.clients, "Client"), [references]);
  const userOptions = useMemo(() => buildReferenceOptions(references?.users, "Utilisateur"), [references]);
  const conditionPaiementOptions = useMemo(
    () => buildReferenceOptions(references?.commandeConditionPaiements, "Condition"),
    [references]
  );
  const modePaiementOptions = useMemo(
    () => buildReferenceOptions(references?.commandeModesPaiement, "Mode"),
    [references]
  );
  const typeLabelMap = useMemo(() => buildReferenceLabelMap(commandeTypeOptions), [commandeTypeOptions]);
  const statusLabelMap = useMemo(() => buildReferenceLabelMap(commandeStatusOptions), [commandeStatusOptions]);
  const clientLabelMap = useMemo(() => buildReferenceLabelMap(clientOptions), [clientOptions]);
  const userLabelMap = useMemo(() => buildReferenceLabelMap(userOptions), [userOptions]);
  const tableColumns = useMemo(
    () => [
      { key: "CodeCmd", label: "Code" },
      {
        key: "DateCmd",
        label: "Date",
        render: (row) => formatDate(row.DateCmd, { withTime: true }),
        renderText: (row) => formatDate(row.DateCmd, { withTime: true }),
      },
      {
        key: "ID_TypeCmdFk",
        label: "Type",
        render: (row) => typeLabelMap.get(String(row.ID_TypeCmdFk)) || `#${row.ID_TypeCmdFk ?? "-"}`,
        renderText: (row) => typeLabelMap.get(String(row.ID_TypeCmdFk)) || `#${row.ID_TypeCmdFk ?? "-"}`,
      },
      {
        key: "ID_ClientFk",
        label: "Client",
        render: (row) => clientLabelMap.get(String(row.ID_ClientFk)) || (row.ID_ClientFk ? `#${row.ID_ClientFk}` : "-"),
        renderText: (row) => clientLabelMap.get(String(row.ID_ClientFk)) || (row.ID_ClientFk ? `#${row.ID_ClientFk}` : "-"),
      },
      { key: "NomUser", label: "Utilisateur" },
      { key: "MontantHT", label: "HT", render: (row) => formatCurrency(row.MontantHT), renderText: (row) => formatCurrency(row.MontantHT) },
      { key: "MontantTTC", label: "TTC", render: (row) => formatCurrency(row.MontantTTC), renderText: (row) => formatCurrency(row.MontantTTC) },
      {
        key: "StatusFacture",
        label: "Statut",
        render: (row) =>
          row.StatusFacture ? <ToneBadge tone="info">{row.StatusFacture}</ToneBadge> : <ToneBadge tone="warning">Non renseigne</ToneBadge>,
        renderText: (row) => row.StatusFacture || "Non renseigne",
      },
      {
        key: "actions",
        label: "Actions",
        render: (row) => (
          <div className="logistics-table-actions" onClick={(event) => event.stopPropagation()}>
            <button type="button" className="secondary-action" onClick={() => sharedTable?.setSelectedRow?.(row)}>
              Voir
            </button>
            <button type="button" className="secondary-action" onClick={() => handleEditCommande(row)}>
              Modifier
            </button>
            <button type="button" className="secondary-action" onClick={() => onOpenDetails?.(row)}>
              Details
            </button>
          </div>
        ),
        exportValue: () => "",
      },
    ],
    [clientLabelMap, handleEditCommande, onOpenDetails, sharedTable, typeLabelMap]
  );

  useEffect(() => {
    let isMounted = true;

    async function loadCommandes() {
      setLoading(true);
      setError("");

      const response = await fetchLogistiqueCommandes({
        q: deferredSearch,
        statut: statusFilter,
        client: clientFilter,
        dateFrom,
        dateTo,
        take: 100,
      });

      if (!isMounted) {
        return;
      }

      if (!response?.success) {
        setRows([]);
        setError(response?.message || "Impossible de charger les commandes.");
        setLoading(false);
        return;
      }

      const nextRows = asArrayPayload(response);
      setRows(nextRows);
      if (selectedCommande?.ID_Commande != null) {
        const matchedCommande = nextRows.find((row) => row.ID_Commande === selectedCommande.ID_Commande);
        if (matchedCommande) {
          sharedTable?.setSelectedRow?.(matchedCommande);
        } else {
          sharedTable?.clearSelectedRow?.();
        }
      }
      setLoading(false);
    }

    loadCommandes();

    return () => {
      isMounted = false;
    };
  }, [clientFilter, dateFrom, dateTo, deferredSearch, refreshKey, statusFilter]);

  function resetEditor() {
    setEditorMode("");
    setFormValues(createCommandeFormState());
  }

  function handleNewCommande() {
    sharedTable?.clearSelectedRow?.();
    setEditorMode("create");
    setFormValues(createCommandeFormState());
  }

  function handleEditCommande(commande) {
    sharedTable?.setSelectedRow?.(commande);
    setEditorMode("edit");
    setFormValues(mapCommandeToForm(commande));
  }

  async function handleSubmit(event) {
    event.preventDefault();
    setSubmitting(true);

    const payload = {
      ...formValues,
      ID_StatutCmd: formValues.ID_StatutCmd || null,
      ID_ClientFk: formValues.ID_ClientFk || null,
      DateCmd: formValues.DateCmd || null,
      MontantHT: formValues.MontantHT || null,
      MontantTTC: formValues.MontantTTC || null,
    };

    if (editorMode === "create" || formValues.ID_UserFk || selectedCommande?.ID_UserFk != null) {
      payload.ID_UserFk = formValues.ID_UserFk || null;
    }

    if (
      editorMode === "create" ||
      formValues.ID_ConditionPaiementFk ||
      selectedCommande?.ID_ConditionPaiementFk != null
    ) {
      payload.ID_ConditionPaiementFk = formValues.ID_ConditionPaiementFk || null;
    }

    if (editorMode === "create" || formValues.ID_ModePaiementFk || selectedCommande?.ID_ModePaiementFk != null) {
      payload.ID_ModePaiementFk = formValues.ID_ModePaiementFk || null;
    }

    if (editorMode === "create" || formValues.DateFacture || selectedCommande?.DateFacture != null) {
      payload.DateFacture = formValues.DateFacture || null;
    }

    if (
      editorMode === "create" ||
      formValues.DateEcheancePaiement ||
      selectedCommande?.DateEcheancePaiement != null
    ) {
      payload.DateEcheancePaiement = formValues.DateEcheancePaiement || null;
    }

    const response =
      editorMode === "edit" && selectedCommande
        ? await updateLogistiqueCommande(selectedCommande.ID_Commande, payload)
        : await createLogistiqueCommande(payload);

    setSubmitting(false);

    if (!response?.success) {
      setFeedback({ type: "error", message: getApiMessage(response, "Enregistrement de la commande impossible.") });
      return;
    }

    setFeedback({
      type: "success",
      message: editorMode === "edit" ? "Commande mise a jour avec succes." : "Commande creee avec succes.",
    });
    resetEditor();
    onDataChanged?.();
  }

  return (
    <div className="logistics-stack">
      <StatusBanner feedback={feedback} />

      <SectionCard
        title="Suivi des commandes"
        subtitle="Lecture via V_Commande, mise a jour dans T_Commande, details geres separement."
        actions={
          <button type="button" className="secondary-action" onClick={handleNewCommande}>
            Nouvelle commande
          </button>
        }
      >
        <div className="logistics-filter-grid logistics-filter-grid-wide">
          <label className="admin-form-field">
            <span>{sharedTable?.searchLabel || "Recherche globale"}</span>
            <input
              type="search"
              value={sharedTable?.searchValue || ""}
              onChange={(event) => sharedTable?.setSearchValue?.(event.target.value)}
              placeholder="Code, reference, utilisateur, statut facture..."
            />
          </label>

          <label className="admin-form-field">
            <span>Statut facture</span>
            <input type="search" value={statusFilter} onChange={(event) => setStatusFilter(event.target.value)} />
          </label>

          <SelectField
            label="Client"
            value={clientFilter}
            onChange={(event) => setClientFilter(event.target.value)}
            options={clientOptions}
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
          selectedRow={selectedCommande}
          label={selectedCommande ? `Ligne selectionnee: commande #${selectedCommande.ID_Commande}` : "Aucune ligne selectionnee"}
          description={
            selectedCommande
              ? `${selectedCommande.CodeCmd || "-"} | ${clientLabelMap.get(String(selectedCommande.ID_ClientFk)) || "Sans client"}`
              : "Selectionnez une commande pour agir dessus plus rapidement."
          }
          actions={
            selectedCommande ? (
              <>
                <button type="button" className="secondary-action" onClick={() => handleEditCommande(selectedCommande)}>
                  Modifier
                </button>
                <button type="button" className="secondary-action" onClick={() => onOpenDetails?.(selectedCommande)}>
                  Ouvrir details
                </button>
              </>
            ) : null
          }
        />

        <TableToolbar
          title={sharedTable?.toolbarTitle || "Tableau V_Commande"}
          rows={rows}
          columns={tableColumns.filter((column) => column.key !== "actions")}
          exportFilename={sharedTable?.exportFilename || "logistique-v_commande.csv"}
        />

        <LoadingErrorEmpty loading={loading} error={error} rows={rows} emptyMessage="Aucune commande a afficher." />

        {!loading && !error && rows.length > 0 ? (
          <SimpleTable
            rows={rows}
            columns={tableColumns}
            selectedRowId={selectedCommande?.ID_Commande || null}
            onRowSelect={sharedTable?.setSelectedRow}
            defaultPinnedColumns={["CodeCmd", "DateCmd"]}
            defaultSortColumn="DateCmd"
            exportFilename={sharedTable?.exportFilename || "logistique-v_commande.csv"}
          />
        ) : null}
      </SectionCard>

      {selectedCommande ? (
        <SectionCard title="Fiche commande" subtitle="Synthese de la commande selectionnee.">
          <div className="logistics-detail-grid">
            <article>
              <strong>{selectedCommande.CodeCmd || `Commande #${selectedCommande.ID_Commande}`}</strong>
              <p>Date: {formatDate(selectedCommande.DateCmd, { withTime: true })}</p>
              <p>Type: {typeLabelMap.get(String(selectedCommande.ID_TypeCmdFk)) || `#${selectedCommande.ID_TypeCmdFk ?? "-"}`}</p>
              <p>Statut commande: {statusLabelMap.get(String(selectedCommande.ID_StatutCmd)) || `#${selectedCommande.ID_StatutCmd ?? "-"}`}</p>
            </article>
            <article>
              <p>Client: {clientLabelMap.get(String(selectedCommande.ID_ClientFk)) || (selectedCommande.ID_ClientFk ? `#${selectedCommande.ID_ClientFk}` : "-")}</p>
              <p>Utilisateur: {selectedCommande.NomComplet || userLabelMap.get(String(selectedCommande.ID_UserFk)) || "-"}</p>
              <p>Facture: {selectedCommande.CodeFacture || "-"}</p>
              <p>TTC: {formatCurrency(selectedCommande.MontantTTC)}</p>
              <p>Observation: {selectedCommande.ObsCmd || "-"}</p>
            </article>
          </div>
        </SectionCard>
      ) : null}

      {editorMode ? (
        <SectionCard
          title={editorMode === "edit" ? "Modifier la commande" : "Creer une commande"}
          subtitle="Le type de commande doit correspondre a la logique SQL existante pour les mouvements de stock."
        >
          <form className="admin-editor-form" onSubmit={handleSubmit}>
            <div className="admin-editor-grid">
              <SelectField
                label="Type commande"
                value={formValues.ID_TypeCmdFk}
                onChange={(event) => setFormValues((current) => ({ ...current, ID_TypeCmdFk: event.target.value }))}
                options={commandeTypeOptions}
                allowEmpty={false}
              />

              <SelectField
                label="Statut commande"
                value={formValues.ID_StatutCmd}
                onChange={(event) => setFormValues((current) => ({ ...current, ID_StatutCmd: event.target.value }))}
                options={commandeStatusOptions}
              />

              <SelectField
                label="Client"
                value={formValues.ID_ClientFk}
                onChange={(event) => setFormValues((current) => ({ ...current, ID_ClientFk: event.target.value }))}
                options={clientOptions}
              />

              <SelectField
                label="Utilisateur"
                value={formValues.ID_UserFk}
                onChange={(event) => setFormValues((current) => ({ ...current, ID_UserFk: event.target.value }))}
                options={userOptions}
              />

              <label className="admin-form-field">
                <span>Date commande</span>
                <input
                  type="datetime-local"
                  value={formValues.DateCmd}
                  onChange={(event) => setFormValues((current) => ({ ...current, DateCmd: event.target.value }))}
                />
              </label>

              <label className="admin-form-field">
                <span>Code commande</span>
                <input
                  type="text"
                  value={formValues.CodeCmd}
                  onChange={(event) => setFormValues((current) => ({ ...current, CodeCmd: event.target.value }))}
                />
              </label>

              <label className="admin-form-field">
                <span>Reference</span>
                <input
                  type="text"
                  value={formValues.RefCmd}
                  onChange={(event) => setFormValues((current) => ({ ...current, RefCmd: event.target.value }))}
                />
              </label>

              <label className="admin-form-field">
                <span>Montant HT</span>
                <input
                  type="number"
                  min="0"
                  step="0.01"
                  value={formValues.MontantHT}
                  onChange={(event) => setFormValues((current) => ({ ...current, MontantHT: event.target.value }))}
                />
              </label>

              <label className="admin-form-field">
                <span>Montant TTC</span>
                <input
                  type="number"
                  min="0"
                  step="0.01"
                  value={formValues.MontantTTC}
                  onChange={(event) => setFormValues((current) => ({ ...current, MontantTTC: event.target.value }))}
                />
              </label>

              <label className="admin-form-field">
                <span>Code facture</span>
                <input
                  type="text"
                  value={formValues.CodeFacture}
                  onChange={(event) => setFormValues((current) => ({ ...current, CodeFacture: event.target.value }))}
                />
              </label>

              <SelectField
                label="Condition paiement"
                value={formValues.ID_ConditionPaiementFk}
                onChange={(event) =>
                  setFormValues((current) => ({ ...current, ID_ConditionPaiementFk: event.target.value }))
                }
                options={conditionPaiementOptions}
              />

              <SelectField
                label="Mode paiement"
                value={formValues.ID_ModePaiementFk}
                onChange={(event) =>
                  setFormValues((current) => ({ ...current, ID_ModePaiementFk: event.target.value }))
                }
                options={modePaiementOptions}
              />

              <label className="admin-form-field">
                <span>Date facture</span>
                <input
                  type="datetime-local"
                  value={formValues.DateFacture}
                  onChange={(event) => setFormValues((current) => ({ ...current, DateFacture: event.target.value }))}
                />
              </label>

              <label className="admin-form-field">
                <span>Statut facture</span>
                <input
                  type="text"
                  value={formValues.StatusFacture}
                  onChange={(event) => setFormValues((current) => ({ ...current, StatusFacture: event.target.value }))}
                />
              </label>

              <label className="admin-form-field">
                <span>Date echeance paiement</span>
                <input
                  type="datetime-local"
                  value={formValues.DateEcheancePaiement}
                  onChange={(event) =>
                    setFormValues((current) => ({ ...current, DateEcheancePaiement: event.target.value }))
                  }
                />
              </label>

              <label className="admin-form-field admin-form-field-wide">
                <span>Observation</span>
                <textarea
                  value={formValues.ObsCmd}
                  onChange={(event) => setFormValues((current) => ({ ...current, ObsCmd: event.target.value }))}
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
