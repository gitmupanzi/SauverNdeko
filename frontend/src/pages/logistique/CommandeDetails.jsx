import { useEffect, useMemo, useState } from "react";
import {
  createLogistiqueCommandeDetail,
  deleteLogistiqueCommandeDetail,
  fetchLogistiqueCommandeDetails,
  updateLogistiqueCommandeDetail,
} from "../../services/logistique";
import {
  asArrayPayload,
  buildReferenceOptions,
  FkMappingCard,
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
} from "./logistiqueShared";

function createDetailFormState() {
  return {
    ID_ArticleFk: "",
    QteCmdDetail: "",
    PUCmdDetail: "",
    ObsCmdDetail: "",
    RemiseCmdDetail: false,
    LieuCmdDetail: "",
    SelectCmdDetail: false,
  };
}

function mapDetailToForm(detail) {
  return {
    ID_ArticleFk: detail.ID_ArticleFk ? String(detail.ID_ArticleFk) : "",
    QteCmdDetail: detail.QteCmdDetail != null ? String(detail.QteCmdDetail) : "",
    PUCmdDetail: detail.PUCmdDetail != null ? String(detail.PUCmdDetail) : "",
    ObsCmdDetail: detail.ObsCmdDetail || "",
    RemiseCmdDetail: Boolean(detail.RemiseCmdDetail),
    LieuCmdDetail: detail.LieuCmdDetail != null ? String(detail.LieuCmdDetail) : "",
    SelectCmdDetail: Boolean(detail.SelectCmdDetail),
  };
}

export default function CommandeDetails({ selectedCommande, references, refreshKey, onDataChanged, sharedTable }) {
  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [feedback, setFeedback] = useState(null);
  const [editorMode, setEditorMode] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [formValues, setFormValues] = useState(createDetailFormState());
  const articleOptions = useMemo(() => buildReferenceOptions(references?.articles, "Article"), [references]);
  const selectedDetail = sharedTable?.selectedRow || null;

  useEffect(() => {
    let isMounted = true;

    async function loadDetails() {
      if (!selectedCommande?.ID_Commande) {
        setRows([]);
        setLoading(false);
        return;
      }

      setLoading(true);
      setError("");

      const response = await fetchLogistiqueCommandeDetails(selectedCommande.ID_Commande, { take: 150 });

      if (!isMounted) {
        return;
      }

      if (!response?.success) {
        setRows([]);
        setError(response?.message || "Impossible de charger les details de commande.");
        setLoading(false);
        return;
      }

      setRows(asArrayPayload(response));
      setLoading(false);
    }

    loadDetails();

    return () => {
      isMounted = false;
    };
  }, [refreshKey, selectedCommande]);

  function resetEditor() {
    setEditorMode("");
    sharedTable?.clearSelectedRow?.();
    setFormValues(createDetailFormState());
  }

  function handleNewLine() {
    setEditorMode("create");
    sharedTable?.clearSelectedRow?.();
    setFormValues(createDetailFormState());
  }

  function handleEditLine(detail) {
    setEditorMode("edit");
    sharedTable?.setSelectedRow?.(detail);
    setFormValues(mapDetailToForm(detail));
  }

  async function handleDeleteLine(detail) {
    if (!selectedCommande?.ID_Commande) {
      return;
    }

    if (!window.confirm(`Supprimer la ligne article #${detail.ID_ArticleFk} ?`)) {
      return;
    }

    const response = await deleteLogistiqueCommandeDetail(selectedCommande.ID_Commande, detail.ID_ArticleFk);

    if (!response?.success) {
      setFeedback({ type: "error", message: getApiMessage(response, "Suppression de la ligne impossible.") });
      return;
    }

    setFeedback({ type: "success", message: "Ligne de commande supprimee avec succes." });
    onDataChanged?.();
  }

  async function handleSubmit(event) {
    event.preventDefault();

    if (!selectedCommande?.ID_Commande) {
      return;
    }

    setSubmitting(true);

    const payload = {
      ...formValues,
      PUCmdDetail: formValues.PUCmdDetail || null,
      LieuCmdDetail: formValues.LieuCmdDetail || null,
    };

    const response =
      editorMode === "edit" && selectedDetail
        ? await updateLogistiqueCommandeDetail(selectedCommande.ID_Commande, selectedDetail.ID_ArticleFk, payload)
        : await createLogistiqueCommandeDetail(selectedCommande.ID_Commande, payload);

    setSubmitting(false);

    if (!response?.success) {
      setFeedback({ type: "error", message: getApiMessage(response, "Enregistrement du detail impossible.") });
      return;
    }

    setFeedback({
      type: "success",
      message: editorMode === "edit" ? "Detail de commande mis a jour." : "Ligne ajoutee a la commande.",
    });
    resetEditor();
    onDataChanged?.();
  }

  if (!selectedCommande) {
    return (
      <SectionCard title="Details de commande" subtitle="Selectionnez d'abord une commande depuis l'onglet Commandes.">
        <section className="table-empty-state">Aucune commande selectionnee pour afficher les details.</section>
      </SectionCard>
    );
  }

  return (
    <div className="logistics-stack">
      <StatusBanner feedback={feedback} />

      <SectionCard
        title={`Details de ${selectedCommande.CodeCmd || `commande #${selectedCommande.ID_Commande}`}`}
        subtitle="Les ajouts, modifications et suppressions laissent les triggers SQL mettre a jour T_Mouvement et le stock."
        actions={
          <button type="button" className="secondary-action" onClick={handleNewLine}>
            Ajouter une ligne
          </button>
        }
      >
        <div className="logistics-detail-grid">
          <article>
            <strong>{selectedCommande.CodeCmd || `Commande #${selectedCommande.ID_Commande}`}</strong>
            <p>Date: {formatDate(selectedCommande.DateCmd, { withTime: true })}</p>
          </article>
          <article>
            <p>Facture: {selectedCommande.CodeFacture || "-"}</p>
            <p>Montant TTC: {formatCurrency(selectedCommande.MontantTTC)}</p>
          </article>
        </div>

        <TableToolbar
          title={sharedTable?.toolbarTitle || "Tableau V_CommandeDetail"}
          rows={rows}
          columns={[
            { key: "NomArticle", label: "Article" },
            { key: "QteCmdDetail", label: "Quantite", renderText: (row) => formatNumber(row.QteCmdDetail) },
            { key: "PUCmdDetail", label: "Prix", renderText: (row) => formatCurrency(row.PUCmdDetail) },
            { key: "RemiseCmdDetail", label: "Remise", renderText: (row) => (row.RemiseCmdDetail ? "Oui" : "Non") },
            { key: "LieuCmdDetail", label: "Lieu", renderText: (row) => row.LieuCmdDetail ?? "-" },
          ]}
          exportFilename={sharedTable?.exportFilename || "logistique-v_commandedetail.csv"}
        />

        <LoadingErrorEmpty loading={loading} error={error} rows={rows} emptyMessage="Aucune ligne de commande a afficher." />

        {!loading && !error && rows.length > 0 ? (
          <SimpleTable
            rows={rows}
            selectedRowId={selectedDetail ? `${selectedDetail.ID_CmdFk}-${selectedDetail.ID_ArticleFk}` : null}
            getRowId={(row) => `${row.ID_CmdFk}-${row.ID_ArticleFk}`}
            onRowSelect={sharedTable?.setSelectedRow}
            columns={[
              { key: "NomArticle", label: "Article" },
              { key: "QteCmdDetail", label: "Quantite", render: (row) => formatNumber(row.QteCmdDetail) },
              { key: "PUCmdDetail", label: "Prix", render: (row) => formatCurrency(row.PUCmdDetail) },
              { key: "RemiseCmdDetail", label: "Remise", render: (row) => (row.RemiseCmdDetail ? "Oui" : "Non") },
              { key: "LieuCmdDetail", label: "Lieu", render: (row) => row.LieuCmdDetail ?? "-" },
              {
                key: "actions",
                label: "Actions",
                render: (row) => (
                  <div className="logistics-table-actions">
                    <button type="button" className="secondary-action" onClick={() => sharedTable?.setSelectedRow?.(row)}>
                      Voir
                    </button>
                    <button type="button" className="secondary-action" onClick={() => handleEditLine(row)}>
                      Modifier
                    </button>
                    <button type="button" className="admin-danger-button" onClick={() => handleDeleteLine(row)}>
                      Supprimer
                    </button>
                  </div>
                ),
              },
            ]}
          />
        ) : null}
      </SectionCard>

      <SelectionStrip
        selectedRow={selectedDetail}
        label={
          selectedDetail
            ? `Ligne selectionnee: commande #${selectedDetail.ID_CmdFk} / article #${selectedDetail.ID_ArticleFk}`
            : "Aucune ligne selectionnee"
        }
        description={
          selectedDetail
            ? `${selectedDetail.NomArticle || "-"} | ${formatNumber(selectedDetail.QteCmdDetail)}`
            : "Selectionnez une ligne du detail pour la modifier plus rapidement."
        }
        actions={
          selectedDetail ? (
            <>
              <button type="button" className="secondary-action" onClick={() => handleEditLine(selectedDetail)}>
                Modifier
              </button>
              <button type="button" className="admin-danger-button" onClick={() => handleDeleteLine(selectedDetail)}>
                Supprimer
              </button>
            </>
          ) : null
        }
      />

      <FkMappingCard
        mappings={sharedTable?.fkMappings || []}
      />

      {selectedDetail ? (
        <SectionCard title="Ligne selectionnee" subtitle="Controle rapide avant modification.">
          <div className="logistics-detail-grid">
            <article>
              <strong>{selectedDetail.NomArticle}</strong>
              <p>Quantite: {formatNumber(selectedDetail.QteCmdDetail)}</p>
            </article>
            <article>
              <p>Prix: {formatCurrency(selectedDetail.PUCmdDetail)}</p>
              <p>Lieu: {selectedDetail.LieuCmdDetail ?? "-"}</p>
            </article>
          </div>
        </SectionCard>
      ) : null}

      {editorMode ? (
        <SectionCard
          title={editorMode === "edit" ? "Modifier la ligne" : "Ajouter une ligne"}
          subtitle="Le type de commande parent pilote la logique d'entree ou sortie de stock."
        >
          <form className="admin-editor-form" onSubmit={handleSubmit}>
            <div className="admin-editor-grid">
              <SelectField
                label="Article"
                value={formValues.ID_ArticleFk}
                onChange={(event) => setFormValues((current) => ({ ...current, ID_ArticleFk: event.target.value }))}
                options={articleOptions}
                allowEmpty={false}
              />

              <label className="admin-form-field">
                <span>Quantite</span>
                <input
                  type="number"
                  min="0.001"
                  step="0.001"
                  value={formValues.QteCmdDetail}
                  onChange={(event) => setFormValues((current) => ({ ...current, QteCmdDetail: event.target.value }))}
                  required
                />
              </label>

              <label className="admin-form-field">
                <span>Prix unitaire</span>
                <input
                  type="number"
                  min="0"
                  step="0.01"
                  value={formValues.PUCmdDetail}
                  onChange={(event) => setFormValues((current) => ({ ...current, PUCmdDetail: event.target.value }))}
                />
              </label>

              <label className="admin-form-field">
                <span>Lieu</span>
                <input
                  type="number"
                  min="1"
                  step="1"
                  value={formValues.LieuCmdDetail}
                  onChange={(event) => setFormValues((current) => ({ ...current, LieuCmdDetail: event.target.value }))}
                />
              </label>

              <label className="admin-checkbox-field">
                <input
                  type="checkbox"
                  checked={formValues.RemiseCmdDetail}
                  onChange={(event) =>
                    setFormValues((current) => ({ ...current, RemiseCmdDetail: event.target.checked }))
                  }
                />
                <span>Remise appliquee</span>
              </label>

              <label className="admin-checkbox-field">
                <input
                  type="checkbox"
                  checked={formValues.SelectCmdDetail}
                  onChange={(event) =>
                    setFormValues((current) => ({ ...current, SelectCmdDetail: event.target.checked }))
                  }
                />
                <span>Ligne selectionnee</span>
              </label>

              <label className="admin-form-field admin-form-field-wide">
                <span>Observation</span>
                <textarea
                  value={formValues.ObsCmdDetail}
                  onChange={(event) => setFormValues((current) => ({ ...current, ObsCmdDetail: event.target.value }))}
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
