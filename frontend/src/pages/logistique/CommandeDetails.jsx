import { useEffect, useMemo, useState } from "react";
import {
  asArrayPayload,
  buildReferenceLabelMap,
  formatCurrency,
  formatDate,
  formatNumber,
  getApiMessage,
  LoadingErrorEmpty,
  SectionCard,
  SelectionStrip,
  SimpleTable,
  StatusBanner,
  SummaryCard,
  TableToolbar,
  ToneBadge,
} from "./logistiqueShared";
import { getLogistiqueCrudConfig, getLogistiqueViewConfig } from "./views";

const COMMANDE_DETAILS_VIEW_CONFIG = getLogistiqueViewConfig("details");
const COMMANDE_DETAILS_CRUD_CONFIG = getLogistiqueCrudConfig("details");

function normalizeSearchText(value) {
  return String(value || "")
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "");
}

function detectCommandeDirection(commande) {
  const abr = normalizeSearchText(commande?.AbrTypeCmd);

  if (commande?.EstCommandeSortie === true || abr.includes("sortie")) {
    return "sortie";
  }

  if (commande?.EstCommandeEntree === true || abr.includes("entree")) {
    return "entree";
  }

  return "indeterminee";
}

function getDefaultUnitPrice(article, commandeDirection) {
  if (!article) {
    return "";
  }

  if (commandeDirection === "sortie" && article.salePrice != null) {
    return String(article.salePrice);
  }

  if (article.purchasePrice != null) {
    return String(article.purchasePrice);
  }

  if (article.salePrice != null) {
    return String(article.salePrice);
  }

  return "";
}

export default function CommandeDetails({ selectedCommande, references, refreshKey, onDataChanged, sharedTable }) {
  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [feedback, setFeedback] = useState(null);
  const [editorMode, setEditorMode] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [formValues, setFormValues] = useState(() => COMMANDE_DETAILS_CRUD_CONFIG.createFormState());
  const [articleSearch, setArticleSearch] = useState("");
  const selectedDetail = sharedTable?.selectedRow || null;
  const composerMode = sharedTable?.composerMode || "view";
  const commandeDirection = useMemo(() => detectCommandeDirection(selectedCommande), [selectedCommande]);
  const articleTypeLabelMap = useMemo(
    () => buildReferenceLabelMap(Array.isArray(references?.articleTypes) ? references.articleTypes : []),
    [references]
  );
  const articleCategoryLabelMap = useMemo(
    () => buildReferenceLabelMap(Array.isArray(references?.articleCategories) ? references.articleCategories : []),
    [references]
  );
  const articleUnitLabelMap = useMemo(
    () => buildReferenceLabelMap(Array.isArray(references?.articleUnits) ? references.articleUnits : []),
    [references]
  );
  const articleCatalog = useMemo(
    () =>
      Array.isArray(references?.articles)
        ? references.articles.map((article) => ({
            ...article,
            id: String(article.id),
            typeLabel: articleTypeLabelMap.get(String(article.typeId || "")) || "-",
            categoryLabel: articleCategoryLabelMap.get(String(article.categoryId || "")) || "-",
            unitLabel: articleUnitLabelMap.get(String(article.unitId || "")) || "-",
            searchText: normalizeSearchText(
              [
                article.code,
                article.reference,
                article.label,
                articleTypeLabelMap.get(String(article.typeId || "")),
                articleCategoryLabelMap.get(String(article.categoryId || "")),
                article.id,
              ]
                .filter(Boolean)
                .join(" ")
            ),
          }))
        : [],
    [articleCategoryLabelMap, articleTypeLabelMap, articleUnitLabelMap, references]
  );
  const selectedArticle = useMemo(
    () => articleCatalog.find((article) => article.id === String(formValues.ID_ArticleFk || "")) || null,
    [articleCatalog, formValues.ID_ArticleFk]
  );
  const filteredArticles = useMemo(() => {
    const normalizedSearch = normalizeSearchText(articleSearch).trim();

    if (!normalizedSearch) {
      return articleCatalog.slice(0, 24);
    }

    return articleCatalog.filter((article) => article.searchText.includes(normalizedSearch)).slice(0, 24);
  }, [articleCatalog, articleSearch]);
  const quantityNumber = Number(formValues.QteCmdDetail || 0);
  const unitPriceNumber = Number(formValues.PUCmdDetail || 0);
  const selectedArticleStock = Number(selectedArticle?.stock || 0);
  const lineTotal = Number.isFinite(quantityNumber) && Number.isFinite(unitPriceNumber) ? quantityNumber * unitPriceNumber : 0;
  const projectedStock =
    commandeDirection === "sortie"
      ? selectedArticleStock - quantityNumber
      : commandeDirection === "entree"
        ? selectedArticleStock + quantityNumber
        : selectedArticleStock;
  const stockError =
    commandeDirection === "sortie" &&
    selectedArticle &&
    Number.isFinite(quantityNumber) &&
    quantityNumber > 0 &&
    quantityNumber > selectedArticleStock;
  const duplicateArticleInCommande = useMemo(
    () =>
      selectedArticle
        ? rows.some(
            (row) =>
              String(row.ID_ArticleFk) === selectedArticle.id &&
              (!selectedDetail ||
                String(row.ID_CmdFk) !== String(selectedDetail.ID_CmdFk) ||
                String(row.ID_ArticleFk) !== String(selectedDetail.ID_ArticleFk))
          )
        : false,
    [rows, selectedArticle, selectedDetail]
  );
  const articleCatalogColumns = useMemo(
    () => [
      { key: "typeLabel", label: "Type" },
      { key: "label", label: "Article" },
      { key: "categoryLabel", label: "Categorie" },
      { key: "reference", label: "Reference", renderText: (row) => row.reference || "-" },
      { key: "stock", label: "Stock", renderText: (row) => formatNumber(row.stock) },
      {
        key: "unitPrice",
        label: commandeDirection === "sortie" ? "PV" : "PU",
        render: (row) =>
          formatCurrency(commandeDirection === "sortie" ? row.salePrice : row.purchasePrice ?? row.salePrice),
        renderText: (row) =>
          formatCurrency(commandeDirection === "sortie" ? row.salePrice : row.purchasePrice ?? row.salePrice),
      },
      {
        key: "actions",
        label: "Action",
        render: (row) => (
          <div className="logistics-table-actions" onClick={(event) => event.stopPropagation()}>
            <button type="button" className="secondary-action" onClick={() => selectArticle(row)}>
              Choisir
            </button>
          </div>
        ),
      },
    ],
    [commandeDirection]
  );

  function selectArticle(article) {
    setFormValues((current) => ({
      ...current,
      ID_ArticleFk: article.id,
      PUCmdDetail:
        current.ID_ArticleFk === article.id && current.PUCmdDetail
          ? current.PUCmdDetail
          : getDefaultUnitPrice(article, commandeDirection),
    }));
  }

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

      const response = await COMMANDE_DETAILS_VIEW_CONFIG.fetchRows({
        commandeId: selectedCommande.ID_Commande,
        take: 150,
      });

      if (!isMounted) {
        return;
      }

      if (!response?.success) {
        setRows([]);
        setError(response?.message || "Impossible de charger les details de commande.");
        setLoading(false);
        return;
      }

      const nextRows = asArrayPayload(response);
      setRows(nextRows);
      if (selectedDetail?.ID_CmdFk != null && selectedDetail?.ID_ArticleFk != null) {
        const matchedDetail = nextRows.find(
          (row) => row.ID_CmdFk === selectedDetail.ID_CmdFk && row.ID_ArticleFk === selectedDetail.ID_ArticleFk
        );
        if (matchedDetail) {
          sharedTable?.setSelectedRow?.(matchedDetail);
        } else {
          sharedTable?.clearSelectedRow?.();
        }
      }
      setLoading(false);
    }

    loadDetails();

    return () => {
      isMounted = false;
    };
  }, [refreshKey, selectedCommande]);

  useEffect(() => {
    if (!selectedCommande?.ID_Commande) {
      return;
    }

    if (composerMode === "create") {
      sharedTable?.clearSelectedRow?.();
      setEditorMode("create");
      setFormValues(COMMANDE_DETAILS_CRUD_CONFIG.createFormState());
      setArticleSearch("");
      return;
    }

    if (composerMode === "view") {
      setEditorMode("");
      setFormValues(COMMANDE_DETAILS_CRUD_CONFIG.createFormState());
      setArticleSearch("");
    }
  }, [composerMode, selectedCommande?.ID_Commande]);

  function resetEditor() {
    sharedTable?.setComposerMode?.("view");
    setEditorMode("");
    sharedTable?.clearSelectedRow?.();
    setFormValues(COMMANDE_DETAILS_CRUD_CONFIG.createFormState());
    setArticleSearch("");
  }

  function handleNewLine() {
    sharedTable?.setComposerMode?.("create");
    setEditorMode("create");
    sharedTable?.clearSelectedRow?.();
    setFormValues(COMMANDE_DETAILS_CRUD_CONFIG.createFormState());
    setArticleSearch("");
  }

  function handleEditLine(detail) {
    sharedTable?.setComposerMode?.("edit");
    setEditorMode("edit");
    sharedTable?.setSelectedRow?.(detail);
    setFormValues(COMMANDE_DETAILS_CRUD_CONFIG.mapRecordToForm(detail));
    setArticleSearch(detail.NomArticle || "");
  }

  async function handleDeleteLine(detail) {
    if (!selectedCommande?.ID_Commande) {
      return;
    }

    if (!window.confirm(`Supprimer la ligne article #${detail.ID_ArticleFk} ?`)) {
      return;
    }

    const response = await COMMANDE_DETAILS_CRUD_CONFIG.deleteRecord({
      parentRecord: selectedCommande,
      record: detail,
    });

    if (!response?.success) {
      setFeedback({ type: "error", message: getApiMessage(response, "Suppression de la ligne impossible.") });
      return;
    }

    setFeedback({ type: "success", message: COMMANDE_DETAILS_CRUD_CONFIG.messages.deleteSuccess });
    onDataChanged?.();
  }

  async function handleSubmit(event) {
    event.preventDefault();

    if (!selectedCommande?.ID_Commande) {
      return;
    }

    if (!formValues.ID_ArticleFk) {
      setFeedback({ type: "error", message: "Selectionnez d'abord un article pour cette ligne." });
      return;
    }

    if (duplicateArticleInCommande) {
      setFeedback({ type: "error", message: "Cet article existe deja dans la commande. Modifiez la ligne existante." });
      return;
    }

    if (stockError) {
      setFeedback({
        type: "error",
        message: "La quantite demandee depasse le stock disponible pour cette commande de sortie.",
      });
      return;
    }

    setSubmitting(true);

    const payload = COMMANDE_DETAILS_CRUD_CONFIG.buildPayload(formValues, {
      mode: editorMode,
      record: selectedDetail,
      parentRecord: selectedCommande,
    });

    const response =
      editorMode === "edit" && selectedDetail
        ? await COMMANDE_DETAILS_CRUD_CONFIG.updateRecord({
            parentRecord: selectedCommande,
            record: selectedDetail,
            payload,
          })
        : await COMMANDE_DETAILS_CRUD_CONFIG.createRecord({
            parentRecord: selectedCommande,
            payload,
          });

    setSubmitting(false);

    if (!response?.success) {
      setFeedback({ type: "error", message: getApiMessage(response, "Enregistrement du detail impossible.") });
      return;
    }

    setFeedback({
      type: "success",
      message:
        editorMode === "edit"
          ? COMMANDE_DETAILS_CRUD_CONFIG.messages.updateSuccess
          : COMMANDE_DETAILS_CRUD_CONFIG.messages.createSuccess,
    });

    if (editorMode === "edit") {
      resetEditor();
    } else {
      sharedTable?.clearSelectedRow?.();
      setEditorMode("create");
      setFormValues(COMMANDE_DETAILS_CRUD_CONFIG.createFormState());
      setArticleSearch("");
    }

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
          <div className="logistics-inline-actions">
            <button type="button" className="secondary-action" onClick={handleNewLine}>
              Ajouter un produit
            </button>
            {editorMode ? (
              <button type="button" className="secondary-action" onClick={resetEditor}>
                Fermer le compositeur
              </button>
            ) : null}
          </div>
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

        <div className="logistics-summary-grid">
          <SummaryCard
            title="Type de flux"
            value={
              commandeDirection === "sortie"
                ? "Sortie"
                : commandeDirection === "entree"
                  ? "Entree"
                  : "A confirmer"
            }
            tone={commandeDirection === "sortie" ? "warning" : "success"}
            caption="Le sens du stock vient du type de commande parent."
          />
          <SummaryCard
            title="Articles deja ajoutes"
            value={formatNumber(rows.length)}
            caption="Une ligne par article dans la commande."
          />
        </div>

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
            defaultPinnedColumns={["NomArticle", "QteCmdDetail"]}
            defaultSortColumn="NomArticle"
            exportFilename={sharedTable?.exportFilename || "logistique-v_commandedetail.csv"}
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
                  <div className="logistics-table-actions" onClick={(event) => event.stopPropagation()}>
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
          title={editorMode === "edit" ? "Modifier la ligne produit" : "Ajouter un produit a la commande"}
          subtitle="Selectionnez un article deja present dans T_Article, renseignez la quantite voulue, puis validez la ligne."
        >
          <div className="logistics-command-builder">
            <section className="logistics-command-builder-panel">
              <div className="section-head">
                <h4>Catalogue disponible</h4>
                <p>Filtrez les articles disponibles, choisissez-en un, puis saisissez directement la quantite d'entree ou de sortie.</p>
              </div>

              <label className="admin-form-field">
                <span>Recherche article</span>
                <input
                  type="search"
                  value={articleSearch}
                  onChange={(event) => setArticleSearch(event.target.value)}
                  placeholder="Type, designation, code, reference..."
                />
              </label>

              <div className="logistics-command-builder-meta">
                <span className="status-pill is-muted">{`${formatNumber(filteredArticles.length)} article(s) visible(s)`}</span>
                <span className="status-pill is-muted">
                  {commandeDirection === "sortie" ? "Flux sortie" : commandeDirection === "entree" ? "Flux entree" : "Flux a confirmer"}
                </span>
              </div>

              <div className="logistics-command-builder-table">
                <SimpleTable
                  rows={filteredArticles}
                  columns={articleCatalogColumns}
                  selectedRowId={selectedArticle?.id || null}
                  getRowId={(row) => row.id}
                  onRowSelect={selectArticle}
                  enableSelection={false}
                  showControls={false}
                  defaultPinnedColumns={["label", "stock"]}
                  defaultSortColumn="label"
                  defaultRowsPerPage={12}
                  exportFilename="logistique-articles-disponibles.csv"
                />
              </div>
            </section>

            <section className="logistics-command-builder-panel logistics-command-builder-panel-accent">
              <div className="section-head">
                <h4>Preparation de la ligne</h4>
                <p>Le produit selectionne pilote la quantite, le prix applique et le controle de stock.</p>
              </div>

              {selectedArticle ? (
                <form className="admin-editor-form logistics-command-line-form" onSubmit={handleSubmit}>
                  <div className="logistics-summary-grid">
                    <SummaryCard title="Stock actuel" value={formatNumber(selectedArticle.stock)} caption="Quantite disponible dans T_Article" />
                    <SummaryCard title="Prix achat" value={formatCurrency(selectedArticle.purchasePrice)} caption="PU article" />
                    <SummaryCard title="Prix vente" value={formatCurrency(selectedArticle.salePrice)} caption="PV article" />
                    <SummaryCard title="Total ligne" value={formatCurrency(lineTotal)} caption="Quantite x prix unitaire" />
                  </div>

                  <div className="logistics-detail-grid">
                    <article>
                      <strong>{selectedArticle.label}</strong>
                      <p>Type: {selectedArticle.typeLabel}</p>
                      <p>Categorie: {selectedArticle.categoryLabel}</p>
                      <p>Unite: {selectedArticle.unitLabel}</p>
                      <p>Code: {selectedArticle.code || "-"}</p>
                      <p>Reference: {selectedArticle.reference || "-"}</p>
                    </article>
                    <article>
                      <p>Seuil minimum: {selectedArticle.minStock != null ? formatNumber(selectedArticle.minStock) : "-"}</p>
                      <p>
                        Stock apres ligne:{" "}
                        <strong>{formatNumber(projectedStock)}</strong>
                      </p>
                      <p>
                        Sens du mouvement:{" "}
                        <ToneBadge tone={commandeDirection === "sortie" ? "warning" : "success"}>
                          {commandeDirection === "sortie" ? "Sortie" : commandeDirection === "entree" ? "Entree" : "Indetermine"}
                        </ToneBadge>
                      </p>
                    </article>
                  </div>

                  {duplicateArticleInCommande ? (
                    <section className="logistics-inline-alert is-warning">
                      Cet article est deja present dans la commande. Modifiez plutot la ligne existante.
                    </section>
                  ) : null}

                  {stockError ? (
                    <section className="logistics-inline-alert is-error">
                      Stock insuffisant pour cette sortie: disponible {formatNumber(selectedArticleStock)}, demande {formatNumber(quantityNumber)}.
                    </section>
                  ) : null}

                  <div className="admin-editor-grid">
                    <label className="admin-form-field">
                      <span>Article retenu</span>
                      <input type="text" value={selectedArticle.label} readOnly />
                    </label>

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
                    <button type="submit" className="primary-action" disabled={submitting || stockError || duplicateArticleInCommande}>
                      {submitting
                        ? "Enregistrement..."
                        : editorMode === "edit"
                          ? "Mettre a jour la ligne"
                          : "Ajouter la ligne"}
                    </button>
                  </div>
                </form>
              ) : (
                <section className="table-empty-state">
                  Selectionnez un article dans la liste de gauche pour preparer la ligne de commande.
                </section>
              )}
            </section>
          </div>
        </SectionCard>
      ) : null}
    </div>
  );
}
