import { useDeferredValue, useEffect, useMemo, useState } from "react";
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
} from "./logistiqueShared";
import {
  getLogistiqueCrudConfig,
  getLogistiqueGenericSourceHint,
  getLogistiqueViewConfig,
} from "./views";

const COMMANDES_VIEW_CONFIG = getLogistiqueViewConfig("commandes");
const COMMANDES_CRUD_CONFIG = getLogistiqueCrudConfig("commandes");

function buildReferenceHelperText(sourceKey, options) {
  const count = Array.isArray(options) ? options.length : 0;
  return `${getLogistiqueGenericSourceHint(sourceKey)} | ${count} option(s) chargee(s)`;
}

function getCommandeClientLabel(commande, clientLabelMap) {
  if (!commande) {
    return "-";
  }

  const mappedLabel = commande.ID_ClientFk ? clientLabelMap.get(String(commande.ID_ClientFk)) : "";

  if (mappedLabel) {
    return mappedLabel;
  }

  if (commande.NomClientSaisi) {
    return commande.NomClientSaisi;
  }

  return commande.ID_ClientFk ? `#${commande.ID_ClientFk}` : "-";
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
  const [formValues, setFormValues] = useState(() => COMMANDES_CRUD_CONFIG.createFormState());
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
  const commandeReferenceWarnings = useMemo(
    () =>
      [
        commandeTypeOptions.length === 0 ? "La liste Type de commande est vide." : "",
        commandeStatusOptions.length === 0 ? "La liste Statut commande est vide." : "",
        conditionPaiementOptions.length === 0 ? "La liste Condition de paiement est vide." : "",
        modePaiementOptions.length === 0 ? "La liste Mode de paiement est vide." : "",
      ].filter(Boolean),
    [
      commandeStatusOptions.length,
      commandeTypeOptions.length,
      conditionPaiementOptions.length,
      modePaiementOptions.length,
    ]
  );
  const isCommandeFormBlocked = commandeTypeOptions.length === 0;
  const typeLabelMap = useMemo(() => buildReferenceLabelMap(commandeTypeOptions), [commandeTypeOptions]);
  const statusLabelMap = useMemo(() => buildReferenceLabelMap(commandeStatusOptions), [commandeStatusOptions]);
  const clientLabelMap = useMemo(() => buildReferenceLabelMap(clientOptions), [clientOptions]);
  const userLabelMap = useMemo(() => buildReferenceLabelMap(userOptions), [userOptions]);
  const tableColumns = useMemo(
    () => [
      { key: "CodeCmd", label: "Code" },
      { key: "CodeFacture", label: "Facture", renderText: (row) => row.CodeFacture || "-" },
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
        render: (row) => getCommandeClientLabel(row, clientLabelMap),
        renderText: (row) => getCommandeClientLabel(row, clientLabelMap),
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
        key: "documents",
        label: "Docs",
        render: (row) => (
          <>
            <ToneBadge tone={row.UrlBL ? "success" : "warning"}>{row.UrlBL ? "BL" : "BL manquant"}</ToneBadge>{" "}
            {row.CodeFacture ? (
              <ToneBadge tone={row.UrlFacture ? "success" : "warning"}>{row.UrlFacture ? "Facture" : "Facture manquante"}</ToneBadge>
            ) : null}
          </>
        ),
        renderText: (row) =>
          `${row.UrlBL ? "BL present" : "BL manquant"}${row.CodeFacture ? ` | ${row.UrlFacture ? "Facture presente" : "Facture manquante"}` : ""}`,
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

      const response = await COMMANDES_VIEW_CONFIG.fetchRows({
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
    setFormValues(COMMANDES_CRUD_CONFIG.createFormState());
  }

  function handleNewCommande() {
    sharedTable?.clearSelectedRow?.();
    setEditorMode("create");
    setFormValues(COMMANDES_CRUD_CONFIG.createFormState());
  }

  function handleEditCommande(commande) {
    sharedTable?.setSelectedRow?.(commande);
    setEditorMode("edit");
    setFormValues(COMMANDES_CRUD_CONFIG.mapRecordToForm(commande));
  }

  async function handleSubmit(event) {
    event.preventDefault();
    setSubmitting(true);

    const payload = COMMANDES_CRUD_CONFIG.buildPayload(formValues, {
      mode: editorMode,
      record: selectedCommande,
    });

    const response =
      editorMode === "edit" && selectedCommande
        ? await COMMANDES_CRUD_CONFIG.updateRecord({ record: selectedCommande, payload })
        : await COMMANDES_CRUD_CONFIG.createRecord({ payload });

    setSubmitting(false);

    if (!response?.success) {
      setFeedback({ type: "error", message: getApiMessage(response, "Enregistrement de la commande impossible.") });
      return;
    }

    setFeedback({
      type: "success",
      message:
        editorMode === "edit"
          ? COMMANDES_CRUD_CONFIG.messages.updateSuccess
          : COMMANDES_CRUD_CONFIG.messages.createSuccess,
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
              ? `${selectedCommande.CodeCmd || "-"} | ${getCommandeClientLabel(selectedCommande, clientLabelMap)}`
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
              <p>
                Statut commande:{" "}
                {statusLabelMap.get(String(selectedCommande.ID_StatutCmdFk)) ||
                  `#${selectedCommande.ID_StatutCmdFk ?? "-"}`}
              </p>
              <p>Geolocalisation: {selectedCommande.geolocalisationCmd || "-"}</p>
            </article>
            <article>
              <p>Client: {getCommandeClientLabel(selectedCommande, clientLabelMap)}</p>
              <p>Client saisi: {selectedCommande.NomClientSaisi || "-"}</p>
              <p>Utilisateur: {selectedCommande.NomComplet || userLabelMap.get(String(selectedCommande.ID_UserFk)) || "-"}</p>
              <p>Facture: {selectedCommande.CodeFacture || "-"}</p>
              <p>TTC: {formatCurrency(selectedCommande.MontantTTC)}</p>
              <p>Regle: {formatCurrency(selectedCommande.MontantRegleFacture)}</p>
              <p>Reste: {formatCurrency(selectedCommande.MontantResteFacture)}</p>
              <p>BL URL: {selectedCommande.UrlBL || "-"}</p>
              <p>Facture URL: {selectedCommande.UrlFacture || "-"}</p>
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
          {commandeReferenceWarnings.length > 0 ? (
            <section className="table-empty-state">
              {`References logistiques a completer: ${commandeReferenceWarnings.join(" ")}`}
            </section>
          ) : null}

          <form className="admin-editor-form" onSubmit={handleSubmit}>
            <div className="admin-editor-grid">
              <SelectField
                label="Type commande"
                value={formValues.ID_TypeCmdFk}
                onChange={(event) => setFormValues((current) => ({ ...current, ID_TypeCmdFk: event.target.value }))}
                options={commandeTypeOptions}
                allowEmpty={false}
                disabled={commandeTypeOptions.length === 0}
                helperText={buildReferenceHelperText("logistique.commandeTypes", commandeTypeOptions)}
              />

              <SelectField
                label="Statut commande"
                value={formValues.ID_StatutCmdFk}
                onChange={(event) => setFormValues((current) => ({ ...current, ID_StatutCmdFk: event.target.value }))}
                options={commandeStatusOptions}
                disabled={commandeStatusOptions.length === 0}
                emptyLabel={commandeStatusOptions.length === 0 ? "Aucune option disponible" : "Choisir"}
                helperText={buildReferenceHelperText("logistique.commandeStatuses", commandeStatusOptions)}
              />

              <SelectField
                label="Client"
                value={formValues.ID_ClientFk}
                onChange={(event) => setFormValues((current) => ({ ...current, ID_ClientFk: event.target.value }))}
                options={clientOptions}
              />

              <label className="admin-form-field">
                <span>Nom client saisi</span>
                <input
                  type="text"
                  value={formValues.NomClientSaisi}
                  onChange={(event) =>
                    setFormValues((current) => ({ ...current, NomClientSaisi: event.target.value }))
                  }
                  placeholder="A renseigner si le client n'existe pas encore dans la liste"
                />
              </label>

              <SelectField
                label="Utilisateur"
                value={formValues.ID_UserFk}
                onChange={(event) => setFormValues((current) => ({ ...current, ID_UserFk: event.target.value }))}
                options={userOptions}
              />

              <label className="admin-form-field">
                <span>Geolocalisation</span>
                <input
                  type="text"
                  value={formValues.geolocalisationCmd}
                  onChange={(event) =>
                    setFormValues((current) => ({ ...current, geolocalisationCmd: event.target.value }))
                  }
                />
              </label>

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

              <label className="admin-form-field">
                <span>Bon de livraison URL</span>
                <input
                  type="url"
                  value={formValues.UrlBL}
                  onChange={(event) => setFormValues((current) => ({ ...current, UrlBL: event.target.value }))}
                />
              </label>

              <SelectField
                label="Condition paiement"
                value={formValues.ID_ConditionPaiementFk}
                onChange={(event) =>
                  setFormValues((current) => ({ ...current, ID_ConditionPaiementFk: event.target.value }))
                }
                options={conditionPaiementOptions}
                disabled={conditionPaiementOptions.length === 0}
                emptyLabel={conditionPaiementOptions.length === 0 ? "Aucune option disponible" : "Choisir"}
                helperText={buildReferenceHelperText("logistique.commandeConditionPaiements", conditionPaiementOptions)}
              />

              <SelectField
                label="Mode paiement"
                value={formValues.ID_ModePaiementFk}
                onChange={(event) =>
                  setFormValues((current) => ({ ...current, ID_ModePaiementFk: event.target.value }))
                }
                options={modePaiementOptions}
                disabled={modePaiementOptions.length === 0}
                emptyLabel={modePaiementOptions.length === 0 ? "Aucune option disponible" : "Choisir"}
                helperText={buildReferenceHelperText("logistique.commandeModesPaiement", modePaiementOptions)}
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
                <span>Montant regle facture</span>
                <input
                  type="number"
                  min="0"
                  step="0.01"
                  value={formValues.MontantRegleFacture}
                  onChange={(event) =>
                    setFormValues((current) => ({ ...current, MontantRegleFacture: event.target.value }))
                  }
                />
              </label>

              <label className="admin-form-field">
                <span>Montant reste facture</span>
                <input
                  type="number"
                  min="0"
                  step="0.01"
                  value={formValues.MontantResteFacture}
                  onChange={(event) =>
                    setFormValues((current) => ({ ...current, MontantResteFacture: event.target.value }))
                  }
                />
              </label>

              <label className="admin-form-field">
                <span>Facture URL</span>
                <input
                  type="url"
                  value={formValues.UrlFacture}
                  onChange={(event) => setFormValues((current) => ({ ...current, UrlFacture: event.target.value }))}
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

              <label className="admin-checkbox-field">
                <input
                  type="checkbox"
                  checked={formValues.SelectCmd}
                  onChange={(event) => setFormValues((current) => ({ ...current, SelectCmd: event.target.checked }))}
                />
                <span>Commande selectionnee</span>
              </label>

              <label className="admin-checkbox-field">
                <input
                  type="checkbox"
                  checked={formValues.ValideRemiseFacture}
                  onChange={(event) =>
                    setFormValues((current) => ({ ...current, ValideRemiseFacture: event.target.checked }))
                  }
                />
                <span>Remise facture validee</span>
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
              <button type="submit" className="primary-action" disabled={submitting || isCommandeFormBlocked}>
                {isCommandeFormBlocked ? "Type de commande indisponible" : submitting ? "Enregistrement..." : "Enregistrer"}
              </button>
            </div>
          </form>
        </SectionCard>
      ) : null}
    </div>
  );
}
