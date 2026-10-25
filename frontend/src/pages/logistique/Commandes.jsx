import CurrencySelect from "../../components/CurrencySelect";
import { newCurrencyId, compareDecimal } from "../../utils/money";
import CategoricalSelect from "../../components/CategoricalSelect";
import ActionButton from "../../components/ActionButton";
import { useConsultations } from "../../components/ConsultationProvider";
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

function getCommandeFlowState(commande, typeLabelMap) {
  if (commande?.EstCommandeEntree || Number(commande?.SigneCommande) > 0) {
    return { label: commande.TypeCmd || typeLabelMap.get(String(commande.ID_TypeCmdFk)) || "Entree", tone: "success" };
  }

  if (commande?.EstCommandeSortie || Number(commande?.SigneCommande) < 0) {
    return { label: commande.TypeCmd || typeLabelMap.get(String(commande.ID_TypeCmdFk)) || "Sortie", tone: "warning" };
  }

  return { label: commande?.TypeCmd || typeLabelMap.get(String(commande?.ID_TypeCmdFk)) || "-", tone: "info" };
}

function getCommandePaymentState(commande) {
  const label = String(commande?.EtatPaiement || commande?.StatusFacture || "");
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

  if (normalized.includes("non reglee") || normalized.includes("retard")) {
    return { key: "non-reglee", label: label || "Non reglee", tone: "danger" };
  }

  if (normalized.includes("reglee")) {
    return { key: "reglee", label: label || "Reglee", tone: "success" };
  }

  return { key: "autre", label: label || "A confirmer", tone: "info" };
}

function getCommandeControlState(commande) {
  const label = String(commande?.EtatControleCommande || "");
  const normalized = label
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "");

  if (normalized.includes("sans")) {
    return { key: "sans-details", label: label || "Sans details", tone: "warning" };
  }

  if (normalized.includes("incoher")) {
    return { key: "incoherente", label: label || "Montant incoherent", tone: "danger" };
  }

  if (normalized.includes("coher")) {
    return { key: "coherente", label: label || "Coherente", tone: "success" };
  }

  return { key: "autre", label: label || "A controler", tone: "info" };
}

function isCommandeLockedForUi(commande) {
  const normalized = String(commande?.StatusFacture || "")
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "");

  return normalized === "cloturee" || normalized === "facturee";
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
  return Number(row?.NbLignes ?? row?.Produits ?? 0);
}

function getCommandeQteTotale(row) {
  return Number(row?.QteTotale ?? 0);
}

export default function Commandes({ references, refreshKey, onDataChanged, onOpenDetails, sharedTable, onToggleFkMappings }) {
  const { user: currentUser } = useAuth();
  const { openOrder } = useConsultations();
  const [gridState, setGridState] = useState({ take: 25, skip: 0, sortBy: "DateCmd", sortDir: "desc" });
  const [serverMeta, setServerMeta] = useState(null);
  const canWrite = currentUser?.permissions?.canWriteData !== false;
  function changeGrid(patch) {
    if ("q" in patch) { sharedTable?.setSearchValue?.(patch.q); delete patch.q; }
    setGridState((current) => ({ ...current, ...patch }));
  }
  const editorRef = useRef(null);
  useEffect(() => {
    if (sharedTable?.composerMode === "create") {
      if (canWrite) handleNewCommande();
      sharedTable?.setComposerMode?.("view");
    }
  }, [sharedTable?.composerMode, canWrite]);
  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [feedback, setFeedback] = useState(null);
  const [currencyFilter,setCurrencyFilter]=useState("");
  const [typeFilter, setTypeFilter] = useState("");
  const [statusFilter, setStatusFilter] = useState("");
  const [paymentFilter, setPaymentFilter] = useState("all");
  const [controlFilter, setControlFilter] = useState("all");
  const [clientFilter, setClientFilter] = useState("");
  const [dateFrom, setDateFrom] = useState("");
  const [dateTo, setDateTo] = useState("");
  const [editorMode, setEditorMode] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [createdCommandeAction, setCreatedCommandeAction] = useState(null);
  const [showAdvancedFields, setShowAdvancedFields] = useState(false);
  const [formValues, setFormValues] = useState(() => ({...COMMANDES_CRUD_CONFIG.createFormState(),ID_DeviseFk:newCurrencyId(references)}));
  const deferredSearch = useDeferredValue(sharedTable?.searchValue || "");
  const selectedCommande = sharedTable?.selectedRow || null;
  const currencyLocked=editorMode==="edit" && (Number(selectedCommande?.NbLignes || 0)>0 || Boolean(selectedCommande?.CodeFacture?.trim()) || compareDecimal(selectedCommande?.MontantRegleFacture,"0")===1);
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
        commandeTypeOptions.length === 0 ? "La liste Type de bon est vide." : "",
        commandeStatusOptions.length === 0 ? "La liste Statut du bon est vide." : "",
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
  const visibleRows = rows;

  const summary = useMemo(
    () =>
      visibleRows.reduce(
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
    [visibleRows]
  );
  const tableColumns = useMemo(
    () => [
      { key: "CodeCmd", label: "N° de bon" },
      { key: "RefCmd", label: "Reference", renderText: (row) => row.RefCmd || "-" },
      {
        key: "DateCmd",
        label: "Date du bon",
        render: (row) => formatDate(row.DateCmd, { withTime: true }),
        renderText: (row) => formatDate(row.DateCmd, { withTime: true }),
      },
      {
        key: "ID_TypeCmdFk",
        label: "Type",
        render: (row) => {
          const flow = getCommandeFlowState(row, typeLabelMap);
          return <ToneBadge tone={flow.tone}>{flow.label}</ToneBadge>;
        },
        renderText: (row) => getCommandeFlowState(row, typeLabelMap).label,
      },
      {
        key: "ID_StatutCmdFk",
        label: "Statut",
        render: (row) => {
          const label = row.StatutCmd || statusLabelMap.get(String(row.ID_StatutCmdFk)) || `#${row.ID_StatutCmdFk ?? "-"}`;
          return <ToneBadge tone={getCommandeStatusTone(label)}>{label}</ToneBadge>;
        },
        renderText: (row) => row.StatutCmd || statusLabelMap.get(String(row.ID_StatutCmdFk)) || `#${row.ID_StatutCmdFk ?? "-"}`,
      },
      {
        key: "ID_ClientFk",
        label: "Tiers",
        render: (row) => getCommandeClientLabel(row, clientLabelMap),
        renderText: (row) => getCommandeClientLabel(row, clientLabelMap),
      },
      {
        key: "NbLignes",
        label: "Nb lignes",
        render: (row) => formatNumber(row.NbLignes ?? getCommandeProduitsCount(row)),
        renderText: (row) => formatNumber(row.NbLignes ?? getCommandeProduitsCount(row)),
      },
      {
        key: "NbArticlesDistincts",
        label: "Articles distincts",
        render: (row) => formatNumber(row.NbArticlesDistincts),
        renderText: (row) => formatNumber(row.NbArticlesDistincts),
      },
      {
        key: "QteTotale",
        label: "Quantite totale",
        render: (row) => formatNumber(row.QteTotale ?? getCommandeQteTotale(row)),
        renderText: (row) => formatNumber(row.QteTotale ?? getCommandeQteTotale(row)),
      },
      { key:"DeviseCode",label:"Devise",renderText:row=>row.DeviseCode || "Non renseignée" },
      { key: "MontantHT", label: "HT", render: (row) => formatCurrency(row.MontantHT,row.DeviseCode), renderText: (row) => formatCurrency(row.MontantHT,row.DeviseCode) },
      { key: "MontantTTC", label: "TTC", render: (row) => formatCurrency(row.MontantTTC,row.DeviseCode), renderText: (row) => formatCurrency(row.MontantTTC,row.DeviseCode) },
      {
        key: "TotalRegleReel",
        label: "Total regle",
        render: (row) => formatCurrency(row.TotalRegleReel ?? row.MontantRegleFacture,row.DeviseCode),
        renderText: (row) => formatCurrency(row.TotalRegleReel ?? row.MontantRegleFacture,row.DeviseCode),
      },
      {
        key: "ResteReel",
        label: "Reste reel",
        render: (row) => formatCurrency(row.ResteReel ?? row.MontantResteFacture,row.DeviseCode),
        renderText: (row) => formatCurrency(row.ResteReel ?? row.MontantResteFacture,row.DeviseCode),
      },
      {
        key: "EtatPaiement",
        label: "Etat paiement",
        render: (row) => {
          const paymentState = getCommandePaymentState(row);
          return <ToneBadge tone={paymentState.tone}>{paymentState.label}</ToneBadge>;
        },
        renderText: (row) => getCommandePaymentState(row).label,
      },
      {
        key: "EtatControleCommande",
        label: "Contrôle du bon",
        render: (row) => {
          const controlState = getCommandeControlState(row);
          return <ToneBadge tone={controlState.tone}>{controlState.label}</ToneBadge>;
        },
        renderText: (row) => getCommandeControlState(row).label,
      },
      {
        key: "actions", sortable: false,
        label: "Actions",
        render: (row) => (
          <div className="logistics-table-actions" onClick={(event) => event.stopPropagation()}>
            <button type="button" className="logistics-kebab-button" onClick={() => sharedTable?.setSelectedRow?.(row)} aria-label={`Actions ${row.CodeCmd || "commande"}`}>
              ⋮
            </button>
          </div>
        ),
        exportValue: () => "",
      },
    ],
    [clientLabelMap, sharedTable, statusLabelMap, typeLabelMap]
  );

  useEffect(() => {
    let isMounted = true;

    async function loadCommandes() {
      setLoading(true);
      setError("");

      const response = await COMMANDES_VIEW_CONFIG.fetchRows({
        q: deferredSearch,
        deviseId:currencyFilter,
        typeId: typeFilter,
        statutId: statusFilter,
        client: clientFilter,
        dateFrom,
        dateTo,
        payment: paymentFilter,
        control: controlFilter,
        ...gridState,
      });

      if (!isMounted) {
        return;
      }

      if (!response?.success) {
        setRows([]);
        setServerMeta(null);
        setError(response?.message || "Impossible de charger les bons de stock.");
        setLoading(false);
        return;
      }

      const nextRows = asArrayPayload(response);
      setServerMeta(response.meta || null);
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
  }, [clientFilter, dateFrom, dateTo, deferredSearch, refreshKey, statusFilter, typeFilter, paymentFilter, controlFilter, currencyFilter, gridState]);

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
    setFormValues(({...COMMANDES_CRUD_CONFIG.createFormState(),ID_DeviseFk:newCurrencyId(references)}));
  }

  function handleNewCommande() {
    sharedTable?.clearSelectedRow?.();
    setEditorMode("create");
    setCreatedCommandeAction(null);
    setShowAdvancedFields(false);
    setFormValues({
      ...({...COMMANDES_CRUD_CONFIG.createFormState(),ID_DeviseFk:newCurrencyId(references)}),
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
    if(submitting||!canWrite)return;
    if(!formValues.ID_DeviseFk){setFeedback({type:"error",message:"Choisissez une devise pour le bon de stock."});return;}
    setSubmitting(true);

    const payload = COMMANDES_CRUD_CONFIG.buildPayload(formValues, {
      mode: editorMode,
      record: selectedCommande,
    });

    if(currencyLocked)delete payload.ID_DeviseFk;
    const response =
      editorMode === "edit" && selectedCommande
        ? await COMMANDES_CRUD_CONFIG.updateRecord({ record: selectedCommande, payload })
        : await COMMANDES_CRUD_CONFIG.createRecord({ payload });

    setSubmitting(false);

    if (!response?.success) {
      setFeedback({ type: "error", message: getApiMessage(response, "Enregistrement du bon de stock impossible.") });
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
    if (!window.confirm(`Supprimer le bon de stock "${commande.CodeCmd || `#${commande.ID_Commande}`}" ?`)) {
      return;
    }

    const response = await COMMANDES_CRUD_CONFIG.deleteRecord({ record: commande });

    if (!response?.success) {
      setFeedback({ type: "error", message: getApiMessage(response, "Suppression du bon de stock impossible.") });
      return;
    }

    if (selectedCommande?.ID_Commande === commande.ID_Commande) {
      sharedTable?.clearSelectedRow?.();
    }

    if (createdCommandeAction?.ID_Commande === commande.ID_Commande) {
      setCreatedCommandeAction(null);
    }

    setFeedback({ type: "success", message: getApiMessage(response, "Bon de stock supprimé avec succes.") });
    onDataChanged?.();
  }

  return (
    <div className="logistics-screen">
      <StatusBanner feedback={feedback} />
      <header className="logistics-screen-copy">
        <h1>Bons de stock</h1>
        <p>Liste des bons de stock, facturation, reglement et controle des montants</p>
      </header>

      <section className="logistics-screen-search-card">
        <label className="admin-form-field logistics-screen-search-field">
          <span>{sharedTable?.searchLabel || "Recherche"}</span>
          <input
            type="search"
            value={sharedTable?.searchValue || ""}
            onChange={(event) => sharedTable?.setSearchValue?.(event.target.value)}
            placeholder="Rechercher un bon de stock, facture, tiers ou reference..."
          />
        </label>
      </section>

      <section className="logistics-top-actions">
        <button type="button" className="logistics-top-action is-blue" onClick={handleNewCommande} disabled={!canWrite}>
          Ajouter
        </button>
        <button type="button" className="logistics-top-action is-indigo" onClick={() => selectedCommande && handleEditCommande(selectedCommande)} disabled={!canWrite || !selectedCommande || isCommandeLockedForUi(selectedCommande)}>
          Modifier
        </button>
        <button type="button" className="logistics-top-action is-red" onClick={() => selectedCommande && handleDeleteCommande(selectedCommande)} disabled={!canWrite || !selectedCommande || isCommandeLockedForUi(selectedCommande)}>
          Supprimer
        </button>
        <button type="button" className="logistics-top-action is-cyan" onClick={() => selectedCommande && openOrder(selectedCommande)} disabled={!selectedCommande}>Consulter</button>
        <button type="button" className="logistics-top-action is-blue" onClick={() => selectedCommande && onOpenDetails?.(selectedCommande, "create")} disabled={!canWrite || !selectedCommande || isCommandeLockedForUi(selectedCommande)}>
          Ajouter produits
        </button>
        <ActionButton icon="download"
          type="button"

          onClick={() => exportRowsToCsv("logistique-commandes.csv", tableColumns.filter((column) => column.key !== "actions"), visibleRows)}
          disabled={visibleRows.length === 0}
        >CSV · page</ActionButton>
        <ActionButton icon="print"
          type="button"

          onClick={() => exportRowsToPdf("logistique-commandes", tableColumns.filter((column) => column.key !== "actions"), visibleRows)}
          disabled={visibleRows.length === 0}
        >Imprimer · page</ActionButton>
        <button type="button" className="logistics-top-action is-sky" onClick={onToggleFkMappings}>Réglages</button>
      </section>

      {createdCommandeAction ? (
        <section className="logistics-inline-alert is-success">
          {`Bon de stock créé: ${createdCommandeAction.CodeCmd || `#${createdCommandeAction.ID_Commande}`}. Vous pouvez maintenant ajouter les produits.`}
        </section>
      ) : null}

      <section className="logistics-screen-filter-card">
        <div className="logistics-mockup-filter-grid">
          <CurrencySelect references={references} filter value={currencyFilter} onChange={value=>{setCurrencyFilter(value);changeGrid({skip:0});}}/>
          <SelectField label="Type de bon" value={typeFilter} onChange={(event) => { setTypeFilter(event.target.value); setGridState((current) => ({ ...current, skip: 0 })); }} options={commandeTypeOptions} />
          <SelectField label="Statut du bon" value={statusFilter} onChange={(event) => { setStatusFilter(event.target.value); setGridState((current) => ({ ...current, skip: 0 })); }} options={commandeStatusOptions} />

          <label className="admin-form-field">
            <span>Etat paiement</span>
            <CategoricalSelect aria-label="État du paiement" value={paymentFilter} onChange={(event) => { setPaymentFilter(event.target.value); setGridState((current) => ({ ...current, skip: 0 })); }}>
              <option value="all">Toutes</option>
              <option value="reglee">Reglee</option>
              <option value="partielle">Partiellement reglee</option>
              <option value="non-reglee">Non reglee</option>
              <option value="non-facturee">Non facturee</option>
            </CategoricalSelect>
          </label>

          <label className="admin-form-field">
            <span>Contrôle du bon</span>
            <CategoricalSelect aria-label="Contrôle du bon" value={controlFilter} onChange={(event) => { setControlFilter(event.target.value); setGridState((current) => ({ ...current, skip: 0 })); }}>
              <option value="all">Toutes</option>
              <option value="coherente">Coherente</option>
              <option value="sans-details">Sans details</option>
              <option value="incoherente">Montant incoherent</option>
            </CategoricalSelect>
          </label>

          <SelectField label="Tiers" value={clientFilter} onChange={(event) => { setClientFilter(event.target.value); setGridState((current) => ({ ...current, skip: 0 })); }} options={clientOptions} />

          <label className="admin-form-field">
            <span>Periode</span>
            <div className="logistics-period-range">
              <input
                type="date"
                value={dateFrom}
                onChange={(event) => { setDateFrom(event.target.value); setGridState((current) => ({ ...current, skip: 0 })); }}
                aria-label="Date de debut bon de stock"
              />
              <input
                type="date"
                value={dateTo}
                onChange={(event) => { setDateTo(event.target.value); setGridState((current) => ({ ...current, skip: 0 })); }}
                aria-label="Date de fin bon de stock"
              />
            </div>
          </label>
        </div>
      </section>

      <section className="logistics-screen-table-card">
        <p className="erp-result-count" role="status">{serverMeta?.filteredCount ?? "—"} résultat(s)</p>
        <LoadingErrorEmpty loading={false} error={error} rows={null} emptyMessage="Aucun bon de stock a afficher." />

          <SimpleTable
            rows={visibleRows}
            emptyMessage={error ? "Les données ne sont pas disponibles." : "Aucun bon de stock pour ces critères."}
            columns={tableColumns}
            selectedRowId={selectedCommande?.ID_Commande || null}
            onRowSelect={sharedTable?.setSelectedRow}
            enableSelection
            showControls
            serverMeta={serverMeta}
            serverState={{ ...gridState, q: sharedTable?.searchValue || "" }}
            onServerChange={changeGrid}
            onRowConsult={openOrder}
            consultColumns={["CodeCmd", "RefCmd"]}
            loading={loading}
            defaultPinnedColumns={["CodeCmd", "DateCmd"]}
            defaultSortColumn="DateCmd"
            defaultRowsPerPage={10}
            exportFilename={sharedTable?.exportFilename || "logistique-v_commande.csv"}
          />
      </section>



      {editorMode ? (
        <SectionCard
          title={editorMode === "edit" ? "Modifier le bon de stock" : "Creer un bon de stock"}
          subtitle="Renseignez d'abord l'entete du bon de stock, puis enchainez avec l'ajout des produits."
        >
          {commandeReferenceWarnings.length > 0 ? (
            <section className="table-empty-state">
              {`References logistiques a completer: ${commandeReferenceWarnings.join(" ")}`}
            </section>
          ) : null}

          <div className="logistics-inline-alert is-warning">
            Enregistrez d'abord l'entete. L'application vous proposera ensuite d'ajouter directement les produits du bon de stock.
          </div>

          <form ref={editorRef} className="admin-editor-form logistics-command-form" onSubmit={handleSubmit}>
            <div className="logistics-command-form-shell">
              <section className="logistics-card-nested logistics-command-form-main">
                <div className="section-head">
                  <h4>Entete essentielle</h4>
                  <p>Les champs ci-dessous suffisent pour creer rapidement le bon de stock.</p>
                </div>

                <div className="logistics-command-editor-grid">
                  <CurrencySelect references={references} value={formValues.ID_DeviseFk} currentCode={selectedCommande?.DeviseCode} onChange={value=>setFormValues(current=>({...current,ID_DeviseFk:value}))} disabled={submitting||currencyLocked} hint={currencyLocked?"La devise est conservée après ajout de lignes ou facturation.":"Les prix des lignes seront exprimés dans cette devise."}/>
                  <SelectField
                    label="Type de bon"
                    value={formValues.ID_TypeCmdFk}
                    onChange={(event) => setFormValues((current) => ({ ...current, ID_TypeCmdFk: event.target.value }))}
                    options={commandeTypeOptions}
                    allowEmpty={false}
                    disabled={commandeTypeOptions.length === 0}
                    helperText={buildReferenceHelperText("logistique.commandeTypes", commandeTypeOptions)}
                  />

                  <SelectField
                    label="Statut du bon"
                    value={formValues.ID_StatutCmdFk}
                    onChange={(event) => setFormValues((current) => ({ ...current, ID_StatutCmdFk: event.target.value }))}
                    options={commandeStatusOptions}
                    disabled={commandeStatusOptions.length === 0}
                    emptyLabel={commandeStatusOptions.length === 0 ? "Aucune option disponible" : "Choisir"}
                    helperText={buildReferenceHelperText("logistique.commandeStatuses", commandeStatusOptions)}
                  />

                  <label className="admin-form-field">
                    <span>Date du bon</span>
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
                    label="Tiers"
                    value={formValues.ID_ClientFk}
                    onChange={(event) => setFormValues((current) => ({ ...current, ID_ClientFk: event.target.value }))}
                    options={clientOptions}
                  />

                  <label className="admin-form-field">
                    <span>Nom tiers saisi</span>
                    <input
                      type="text"
                      value={formValues.NomClientSaisi}
                      onChange={(event) =>
                        setFormValues((current) => ({ ...current, NomClientSaisi: event.target.value }))
                      }
                      placeholder="Utiliser si le tiers n'existe pas encore"
                    />
                  </label>

                  <label className="admin-form-field">
                    <span>N° de bon</span>
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
                      placeholder="Lieu du bon de stock, province, site..."
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
                  <p>Creation de l'entete puis ajout direct des produits sans repartir chercher le bon de stock.</p>
                </div>

                <div className="logistics-summary-grid logistics-summary-grid-compact">
                  <SummaryCard title="Etape 1" value="Entete" tone="info" caption="Type, date, tiers, reference" />
                  <SummaryCard title="Etape 2" value="Produits" tone="success" caption="Ajout direct apres creation" />
                </div>

                <div className="logistics-detail-grid">
                  <article>
                    <strong>Bon de stock en cours</strong>
                    <p>Type: {typeLabelMap.get(String(formValues.ID_TypeCmdFk || "")) || "A choisir"}</p>
                    <p>Statut: {statusLabelMap.get(String(formValues.ID_StatutCmdFk || "")) || "A choisir"}</p>
                  </article>
                  <article>
                    <p>Tiers: {clientLabelMap.get(String(formValues.ID_ClientFk || "")) || formValues.NomClientSaisi || "-"}</p>
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
                      <span>Bon de stock selectionnee</span>
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
                {isCommandeFormBlocked ? "Type de bon indisponible" : submitting ? "Enregistrement..." : "Enregistrer l'entete"}
              </button>
            </div>
          </form>
        </SectionCard>
      ) : null}
    </div>
  );
}
