import { useDeferredValue, useEffect, useMemo, useRef, useState } from "react";
import { useAuth } from "../../contexts/AuthContext";
import {
  asArrayPayload,
  buildReferenceLabelMap,
  buildReferenceOptions,
  exportRowsToCsv,
  exportRowsToPdf,
  formatCurrency,
  formatDate,
  formatNumber,
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

function getCommandeStatusTone(label) {
  const normalized = String(label || "")
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "");

  if (normalized.includes("term") || normalized.includes("clot")) {
    return "success";
  }

  if (normalized.includes("retard") || normalized.includes("manque")) {
    return "danger";
  }

  return "warning";
}

function formatUserDisplayName(user) {
  if (!user) {
    return "";
  }

  return [user.NomUser, user.PrenomUser].filter(Boolean).join(" ").trim() || user.EmailUser || "Utilisateur connecte";
}

function buildDefaultCommandeDateTime() {
  const now = new Date();
  return new Date(now.getTime() - now.getTimezoneOffset() * 60000).toISOString().slice(0, 16);
}

function getCommandeProduitsCount(row) {
  return Number(row?.Produits ?? 0);
}

function getCommandeQteTotale(row) {
  return Number(row?.QteTotale ?? 0);
}

export default function Commandes({ references, refreshKey, onDataChanged, onOpenDetails, sharedTable }) {
  const { user: currentUser } = useAuth();
  const editorRef = useRef(null);
  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [feedback, setFeedback] = useState(null);
  const [typeFilter, setTypeFilter] = useState("");
  const [statusFilter, setStatusFilter] = useState("");
  const [clientFilter, setClientFilter] = useState("");
  const [dateFrom, setDateFrom] = useState("");
  const [dateTo, setDateTo] = useState("");
  const [editorMode, setEditorMode] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [createdCommandeAction, setCreatedCommandeAction] = useState(null);
  const [showAdvancedFields, setShowAdvancedFields] = useState(false);
  const [formValues, setFormValues] = useState(() => COMMANDES_CRUD_CONFIG.createFormState());
  const deferredSearch = useDeferredValue(sharedTable?.searchValue || "");
  const selectedCommande = sharedTable?.selectedRow || null;
  const currentUserId = currentUser?.IdUser != null ? String(currentUser.IdUser) : "";
  const currentUserDisplayName = useMemo(() => formatUserDisplayName(currentUser), [currentUser]);

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
  const editorUserLabel = useMemo(() => {
    if (editorMode === "create") {
      return currentUserDisplayName || "Utilisateur connecte";
    }

    return (
      userLabelMap.get(String(formValues.ID_UserFk || "")) ||
      selectedCommande?.NomComplet ||
      currentUserDisplayName ||
      "-"
    );
  }, [currentUserDisplayName, editorMode, formValues.ID_UserFk, selectedCommande, userLabelMap]);
  const summary = useMemo(
    () =>
      rows.reduce(
        (accumulator, row) => {
          accumulator.total += 1;
          accumulator.totalLignes += getCommandeProduitsCount(row);
          accumulator.totalQuantite += getCommandeQteTotale(row);

          if (row.EstCommandeSansDetails) {
            accumulator.sansDetails += 1;
          }

          if (row.EstPaiementEnRetard) {
            accumulator.enRetard += 1;
          }

          return accumulator;
        },
        {
          total: 0,
          totalLignes: 0,
          totalQuantite: 0,
          sansDetails: 0,
          enRetard: 0,
        }
      ),
    [rows]
  );
  const tableColumns = useMemo(
    () => [
      {
        key: "DateCmd",
        label: "Date",
        render: (row) => formatDate(row.DateCmd, { withTime: true }),
        renderText: (row) => formatDate(row.DateCmd, { withTime: true }),
      },
      { key: "CodeCmd", label: "Code" },
      { key: "RefCmd", label: "Reference", renderText: (row) => row.RefCmd || "-" },
      {
        key: "ID_TypeCmdFk",
        label: "Type",
        render: (row) => typeLabelMap.get(String(row.ID_TypeCmdFk)) || `#${row.ID_TypeCmdFk ?? "-"}`,
        renderText: (row) => typeLabelMap.get(String(row.ID_TypeCmdFk)) || `#${row.ID_TypeCmdFk ?? "-"}`,
      },
      {
        key: "ID_StatutCmdFk",
        label: "Statut commande",
        render: (row) => {
          const label = statusLabelMap.get(String(row.ID_StatutCmdFk)) || `#${row.ID_StatutCmdFk ?? "-"}`;
          return <ToneBadge tone={getCommandeStatusTone(label)}>{label}</ToneBadge>;
        },
        renderText: (row) => statusLabelMap.get(String(row.ID_StatutCmdFk)) || `#${row.ID_StatutCmdFk ?? "-"}`,
      },
      {
        key: "ID_ClientFk",
        label: "Client",
        render: (row) => getCommandeClientLabel(row, clientLabelMap),
        renderText: (row) => getCommandeClientLabel(row, clientLabelMap),
      },
      { key: "NomComplet", label: "Utilisateur", renderText: (row) => row.NomComplet || row.NomUser || "-" },
      { key: "geolocalisationCmd", label: "Localisation", renderText: (row) => row.geolocalisationCmd || "-" },
      { key: "MontantHT", label: "HT", render: (row) => formatCurrency(row.MontantHT), renderText: (row) => formatCurrency(row.MontantHT) },
      { key: "MontantTTC", label: "TTC", render: (row) => formatCurrency(row.MontantTTC), renderText: (row) => formatCurrency(row.MontantTTC) },
      {
        key: "Produits",
        label: "Produits",
        render: (row) => formatNumber(getCommandeProduitsCount(row)),
        renderText: (row) => formatNumber(getCommandeProduitsCount(row)),
      },
      {
        key: "QteTotale",
        label: "Qte totale",
        render: (row) => formatNumber(getCommandeQteTotale(row)),
        renderText: (row) => formatNumber(getCommandeQteTotale(row)),
      },
      { key: "ObsCmd", label: "Obs", renderText: (row) => row.ObsCmd || "-" },
      {
        key: "StatusFacture",
        label: "Facture",
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
            <button type="button" className="secondary-action" onClick={() => onOpenDetails?.(row, "view")}>
              Voir produits
            </button>
            <button type="button" className="secondary-action" onClick={() => onOpenDetails?.(row, "create")}>
              Ajouter produits
            </button>
            <button type="button" className="admin-danger-button" onClick={() => handleDeleteCommande(row)}>
              Supprimer
            </button>
          </div>
        ),
        exportValue: () => "",
      },
    ],
    [clientLabelMap, handleDeleteCommande, handleEditCommande, onOpenDetails, sharedTable, statusLabelMap, typeLabelMap]
  );

  useEffect(() => {
    let isMounted = true;

    async function loadCommandes() {
      setLoading(true);
      setError("");

      const response = await COMMANDES_VIEW_CONFIG.fetchRows({
        q: deferredSearch,
        typeId: typeFilter,
        statutId: statusFilter,
        client: clientFilter,
        dateFrom,
        dateTo,
        take: 200,
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
  }, [clientFilter, dateFrom, dateTo, deferredSearch, refreshKey, statusFilter, typeFilter]);

  useEffect(() => {
    if (editorMode !== "create") {
      return;
    }

    setFormValues((current) => {
      const nextValues = { ...current };
      let changed = false;

      if (currentUserId && nextValues.ID_UserFk !== currentUserId) {
        nextValues.ID_UserFk = currentUserId;
        changed = true;
      }

      if (!nextValues.DateCmd) {
        nextValues.DateCmd = buildDefaultCommandeDateTime();
        changed = true;
      }

      return changed ? nextValues : current;
    });
  }, [currentUserId, editorMode]);

  function resetEditor() {
    setEditorMode("");
    setShowAdvancedFields(false);
    setFormValues(COMMANDES_CRUD_CONFIG.createFormState());
  }

  function handleNewCommande() {
    sharedTable?.clearSelectedRow?.();
    setEditorMode("create");
    setCreatedCommandeAction(null);
    setShowAdvancedFields(false);
    setFormValues({
      ...COMMANDES_CRUD_CONFIG.createFormState(),
      ID_UserFk: currentUserId,
      DateCmd: buildDefaultCommandeDateTime(),
    });
    window.requestAnimationFrame(() => {
      editorRef.current?.scrollIntoView({ behavior: "smooth", block: "start" });
    });
  }

  function handleEditCommande(commande) {
    sharedTable?.setSelectedRow?.(commande);
    setEditorMode("edit");
    setShowAdvancedFields(true);
    setFormValues(COMMANDES_CRUD_CONFIG.mapRecordToForm(commande));
    window.requestAnimationFrame(() => {
      editorRef.current?.scrollIntoView({ behavior: "smooth", block: "start" });
    });
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

    if (editorMode !== "edit" && response?.data) {
      sharedTable?.setSelectedRow?.(response.data);
      setCreatedCommandeAction(response.data);
    } else {
      setCreatedCommandeAction(null);
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

  async function handleDeleteCommande(commande) {
    if (!window.confirm(`Supprimer la commande "${commande.CodeCmd || `#${commande.ID_Commande}`}" ?`)) {
      return;
    }

    const response = await COMMANDES_CRUD_CONFIG.deleteRecord({ record: commande });

    if (!response?.success) {
      setFeedback({ type: "error", message: getApiMessage(response, "Suppression de la commande impossible.") });
      return;
    }

    if (selectedCommande?.ID_Commande === commande.ID_Commande) {
      sharedTable?.clearSelectedRow?.();
    }

    if (createdCommandeAction?.ID_Commande === commande.ID_Commande) {
      setCreatedCommandeAction(null);
    }

    setFeedback({ type: "success", message: getApiMessage(response, "Commande supprimee avec succes.") });
    onDataChanged?.();
  }

  return (
    <div className="logistics-stack">
      <StatusBanner feedback={feedback} />
      <div className="logistics-workbench">
        <div className="logistics-primary-pane">
          <SectionCard
            title="Suivi des commandes"
            subtitle="Liste compacte de commandes avec lecture rapide, filtres metier et acces direct aux produits."
            actions={
              <div className="logistics-inline-actions">
                <button type="button" className="secondary-action" onClick={handleNewCommande}>
                  Ajouter commande
                </button>
                <button
                  type="button"
                  className="secondary-action"
                  onClick={() =>
                    exportRowsToCsv("logistique-commandes.csv", tableColumns.filter((column) => column.key !== "actions"), rows)
                  }
                  disabled={rows.length === 0}
                >
                  Exporter
                </button>
                <button
                  type="button"
                  className="secondary-action"
                  onClick={() =>
                    exportRowsToPdf("logistique-commandes", tableColumns.filter((column) => column.key !== "actions"), rows)
                  }
                  disabled={rows.length === 0}
                >
                  Imprimer
                </button>
              </div>
            }
          >
            <div className="logistics-summary-grid">
              <SummaryCard title="Commandes visibles" value={formatNumber(summary.total)} caption="Filtre courant" />
              <SummaryCard title="Produits lies" value={formatNumber(summary.totalLignes)} caption="Nombre total de lignes" />
              <SummaryCard title="Quantite totale" value={formatNumber(summary.totalQuantite)} tone="success" />
              <SummaryCard title="Sans details" value={formatNumber(summary.sansDetails)} tone="warning" />
              <SummaryCard title="Paiements en retard" value={formatNumber(summary.enRetard)} tone="danger" />
            </div>

            {createdCommandeAction ? (
              <SelectionStrip
                selectedRow={createdCommandeAction}
                label={`Commande creee: ${createdCommandeAction.CodeCmd || `#${createdCommandeAction.ID_Commande}`}`}
                description="Vous pouvez enchainer directement avec l'ajout des produits sans rechercher la commande."
                actionLabel="Suite immediate"
                actionDescription="Ouvrez maintenant l'ecran d'ajout des produits pour cette commande."
                actions={
                  <button type="button" className="primary-action" onClick={() => onOpenDetails?.(createdCommandeAction, "create")}>
                    Ajouter les produits
                  </button>
                }
              />
            ) : null}

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

              <SelectField
                label="Type commande"
                value={typeFilter}
                onChange={(event) => setTypeFilter(event.target.value)}
                options={commandeTypeOptions}
              />

              <SelectField
                label="Statut commande"
                value={statusFilter}
                onChange={(event) => setStatusFilter(event.target.value)}
                options={commandeStatusOptions}
              />

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
                  ? `${selectedCommande.CodeCmd || "-"} | ${getCommandeClientLabel(selectedCommande, clientLabelMap)} | ${formatNumber(getCommandeProduitsCount(selectedCommande))} produit(s)`
                  : "Selectionnez une commande pour agir dessus plus rapidement."
              }
              actions={
                selectedCommande ? (
                  <>
                    <button type="button" className="secondary-action" onClick={() => handleEditCommande(selectedCommande)}>
                      Modifier
                    </button>
                    <button type="button" className="secondary-action" onClick={() => onOpenDetails?.(selectedCommande, "view")}>
                      Voir produits
                    </button>
                    <button type="button" className="secondary-action" onClick={() => onOpenDetails?.(selectedCommande, "create")}>
                      Ajouter produits
                    </button>
                    <button type="button" className="admin-danger-button" onClick={() => handleDeleteCommande(selectedCommande)}>
                      Supprimer
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
        </div>

        {selectedCommande || editorMode ? (
          <aside className="logistics-side-pane">
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
                    <p>Produits: {formatNumber(getCommandeProduitsCount(selectedCommande))}</p>
                  </article>
                  <article>
                    <p>Client: {getCommandeClientLabel(selectedCommande, clientLabelMap)}</p>
                    <p>Client saisi: {selectedCommande.NomClientSaisi || "-"}</p>
                    <p>Utilisateur: {selectedCommande.NomComplet || userLabelMap.get(String(selectedCommande.ID_UserFk)) || "-"}</p>
                    <p>Facture: {selectedCommande.CodeFacture || "-"}</p>
                    <p>TTC: {formatCurrency(selectedCommande.MontantTTC)}</p>
                    <p>Regle: {formatCurrency(selectedCommande.MontantRegleFacture)}</p>
                    <p>Reste: {formatCurrency(selectedCommande.MontantResteFacture)}</p>
                    <p>Qte totale: {formatNumber(getCommandeQteTotale(selectedCommande))}</p>
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
                subtitle="Renseignez d'abord l'entete de la commande, puis enchainez avec l'ajout des produits."
              >
          {commandeReferenceWarnings.length > 0 ? (
            <section className="table-empty-state">
              {`References logistiques a completer: ${commandeReferenceWarnings.join(" ")}`}
            </section>
          ) : null}

          <div className="logistics-inline-alert is-warning">
            Enregistrez d'abord l'entete. L'application vous proposera ensuite d'ajouter directement les produits de la commande.
          </div>

          <form ref={editorRef} className="admin-editor-form logistics-command-form" onSubmit={handleSubmit}>
            <div className="logistics-command-form-shell">
              <section className="logistics-card-nested logistics-command-form-main">
                <div className="section-head">
                  <h4>Entete essentielle</h4>
                  <p>Les champs ci-dessous suffisent pour creer rapidement la commande.</p>
                </div>

                <div className="logistics-command-editor-grid">
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

                  <label className="admin-form-field">
                    <span>Date commande</span>
                    <input
                      type="datetime-local"
                      value={formValues.DateCmd}
                      onChange={(event) => setFormValues((current) => ({ ...current, DateCmd: event.target.value }))}
                    />
                  </label>

                  <label className="admin-form-field">
                    <span>Utilisateur connecte</span>
                    <input type="text" value={editorUserLabel} readOnly />
                  </label>

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
                      placeholder="Utiliser si le client n'existe pas encore"
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

                  <label className="admin-form-field admin-form-field-wide">
                    <span>Geolocalisation / province</span>
                    <input
                      type="text"
                      value={formValues.geolocalisationCmd}
                      onChange={(event) =>
                        setFormValues((current) => ({ ...current, geolocalisationCmd: event.target.value }))
                      }
                      placeholder="Lieu de la commande, province, site..."
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
              </section>

              <aside className="logistics-card-nested logistics-command-form-side">
                <div className="section-head">
                  <h4>Flux de travail</h4>
                  <p>Creation de l'entete puis ajout direct des produits sans repartir chercher la commande.</p>
                </div>

                <div className="logistics-summary-grid logistics-summary-grid-compact">
                  <SummaryCard title="Etape 1" value="Entete" tone="info" caption="Type, date, client, reference" />
                  <SummaryCard title="Etape 2" value="Produits" tone="success" caption="Ajout direct apres creation" />
                </div>

                <div className="logistics-detail-grid">
                  <article>
                    <strong>Commande en cours</strong>
                    <p>Type: {typeLabelMap.get(String(formValues.ID_TypeCmdFk || "")) || "A choisir"}</p>
                    <p>Statut: {statusLabelMap.get(String(formValues.ID_StatutCmdFk || "")) || "A choisir"}</p>
                  </article>
                  <article>
                    <p>Client: {clientLabelMap.get(String(formValues.ID_ClientFk || "")) || formValues.NomClientSaisi || "-"}</p>
                    <p>Date: {formValues.DateCmd ? formatDate(formValues.DateCmd, { withTime: true }) : "-"}</p>
                  </article>
                </div>

                <button
                  type="button"
                  className="secondary-action"
                  onClick={() => setShowAdvancedFields((current) => !current)}
                >
                  {showAdvancedFields ? "Masquer options avancees" : "Afficher options avancees"}
                </button>
              </aside>
            </div>

            {showAdvancedFields ? (
              <div className="logistics-command-advanced-grid">
                <section className="logistics-card-nested">
                  <div className="section-head">
                    <h4>Totaux et documents</h4>
                    <p>Complements utiles si le montant ou les documents sont deja connus.</p>
                  </div>

                  <div className="logistics-command-editor-grid">
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
                      <span>Bon de livraison URL</span>
                      <input
                        type="url"
                        value={formValues.UrlBL}
                        onChange={(event) => setFormValues((current) => ({ ...current, UrlBL: event.target.value }))}
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
                  </div>
                </section>

                <section className="logistics-card-nested">
                  <div className="section-head">
                    <h4>Facture et paiement</h4>
                    <p>Ces champs restent disponibles, mais ne sont plus imposes a l'ouverture du formulaire.</p>
                  </div>

                  <div className="logistics-command-editor-grid">
                    <label className="admin-form-field">
                      <span>Code facture</span>
                      <input
                        type="text"
                        value={formValues.CodeFacture}
                        onChange={(event) => setFormValues((current) => ({ ...current, CodeFacture: event.target.value }))}
                      />
                    </label>

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
                      <span>Facture URL</span>
                      <input
                        type="url"
                        value={formValues.UrlFacture}
                        onChange={(event) => setFormValues((current) => ({ ...current, UrlFacture: event.target.value }))}
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
                        checked={formValues.ValideRemiseFacture}
                        onChange={(event) =>
                          setFormValues((current) => ({ ...current, ValideRemiseFacture: event.target.checked }))
                        }
                      />
                      <span>Remise facture validee</span>
                    </label>
                  </div>
                </section>
              </div>
            ) : null}

            <div className="admin-editor-actions">
              <button type="button" className="secondary-action" onClick={resetEditor} disabled={submitting}>
                Annuler
              </button>
              <button type="submit" className="primary-action" disabled={submitting || isCommandeFormBlocked}>
                {isCommandeFormBlocked ? "Type de commande indisponible" : submitting ? "Enregistrement..." : "Enregistrer l'entete"}
              </button>
            </div>
          </form>
              </SectionCard>
            ) : null}
          </aside>
        ) : null}
      </div>
    </div>
  );
}
