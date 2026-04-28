import { useDeferredValue, useEffect, useMemo, useState } from "react";
import {
  createLogistiqueArticle,
  deleteLogistiqueArticle,
  fetchLogistiqueArticles,
  updateLogistiqueArticle,
} from "../../services/logistique";
import {
  asArrayPayload,
  buildReferenceLabelMap,
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
  ToneBadge,
  toInputDateValue,
} from "./logistiqueShared";

function createArticleFormState() {
  return {
    NomArticle: "",
    RefArticle: "",
    CodeArticleInterne: "",
    ID_TypeArticleFk: "",
    ID_CategorieArticleFk: "",
    ID_UserFK: "",
    ID_UniteFk: "",
    QteArticle: "0",
    QteMinArticle: "",
    PUArticle: "",
    PVArticle: "",
    DatePeremptionArticle: "",
    ObsArticle: "",
    ValideArticle: true,
  };
}

function mapArticleToForm(article) {
  return {
    NomArticle: article.NomArticle || "",
    RefArticle: article.RefArticle || "",
    CodeArticleInterne: article.CodeArticleInterne || "",
    ID_TypeArticleFk: article.ID_TypeArticleFk ? String(article.ID_TypeArticleFk) : "",
    ID_CategorieArticleFk: article.ID_CategorieArticleFk ? String(article.ID_CategorieArticleFk) : "",
    ID_UserFK: article.ID_UserFK ? String(article.ID_UserFK) : article.IdUser ? String(article.IdUser) : "",
    ID_UniteFk: article.ID_UniteFk ? String(article.ID_UniteFk) : "",
    QteArticle: article.QteArticle != null ? String(article.QteArticle) : "0",
    QteMinArticle: article.QteMinArticle != null ? String(article.QteMinArticle) : "",
    PUArticle: article.PUArticle != null ? String(article.PUArticle) : "",
    PVArticle: article.PVArticle != null ? String(article.PVArticle) : "",
    DatePeremptionArticle: toInputDateValue(article.DatePeremptionArticle),
    ObsArticle: article.ObsArticle || "",
    ValideArticle: article.ValideArticle !== false,
  };
}

export default function Articles({ references, refreshKey, onDataChanged, sharedTable }) {
  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [feedback, setFeedback] = useState(null);
  const [statusFilter, setStatusFilter] = useState("all");
  const [editorMode, setEditorMode] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [formValues, setFormValues] = useState(createArticleFormState());
  const deferredSearch = useDeferredValue(sharedTable?.searchValue || "");
  const selectedArticle = sharedTable?.selectedRow || null;

  const articleTypeOptions = useMemo(() => buildReferenceOptions(references?.articleTypes, "Type"), [references]);
  const articleCategoryOptions = useMemo(
    () => buildReferenceOptions(references?.articleCategories, "Categorie"),
    [references]
  );
  const userOptions = useMemo(() => buildReferenceOptions(references?.users, "Utilisateur"), [references]);
  const articleUnitOptions = useMemo(() => buildReferenceOptions(references?.articleUnits, "Unite"), [references]);
  const typeLabelMap = useMemo(() => buildReferenceLabelMap(articleTypeOptions), [articleTypeOptions]);
  const categoryLabelMap = useMemo(() => buildReferenceLabelMap(articleCategoryOptions), [articleCategoryOptions]);
  const unitLabelMap = useMemo(() => buildReferenceLabelMap(articleUnitOptions), [articleUnitOptions]);
  const userLabelMap = useMemo(() => buildReferenceLabelMap(userOptions), [userOptions]);
  const tableColumns = useMemo(
    () => [
      { key: "NomArticle", label: "Article" },
      { key: "CodeArticleInterne", label: "Code" },
      { key: "RefArticle", label: "Reference" },
      { key: "QteArticle", label: "Stock", render: (row) => formatNumber(row.QteArticle), renderText: (row) => formatNumber(row.QteArticle) },
      { key: "QteMinArticle", label: "Seuil", render: (row) => formatNumber(row.QteMinArticle), renderText: (row) => formatNumber(row.QteMinArticle) },
      { key: "PUArticle", label: "PU", render: (row) => formatCurrency(row.PUArticle), renderText: (row) => formatCurrency(row.PUArticle) },
      { key: "PVArticle", label: "PV", render: (row) => formatCurrency(row.PVArticle), renderText: (row) => formatCurrency(row.PVArticle) },
      { key: "NomComplet", label: "Auteur" },
      {
        key: "ValideArticle",
        label: "Statut",
        render: (row) =>
          row.ValideArticle ? <ToneBadge tone="success">Actif</ToneBadge> : <ToneBadge tone="warning">Desactive</ToneBadge>,
        renderText: (row) => (row.ValideArticle ? "Actif" : "Desactive"),
      },
      {
        key: "actions",
        label: "Actions",
        render: (row) => (
          <div className="logistics-table-actions" onClick={(event) => event.stopPropagation()}>
            <button type="button" className="secondary-action" onClick={() => sharedTable?.setSelectedRow?.(row)}>
              Voir
            </button>
            <button type="button" className="secondary-action" onClick={() => handleEditArticle(row)}>
              Modifier
            </button>
            <button type="button" className="admin-danger-button" onClick={() => handleDisableArticle(row)}>
              Desactiver
            </button>
          </div>
        ),
        exportValue: () => "",
      },
    ],
    [handleDisableArticle, sharedTable]
  );

  useEffect(() => {
    let isMounted = true;

    async function loadArticles() {
      setLoading(true);
      setError("");

      const response = await fetchLogistiqueArticles({
        q: deferredSearch,
        statut: statusFilter === "all" ? "" : statusFilter,
        take: 100,
      });

      if (!isMounted) {
        return;
      }

      if (!response?.success) {
        setRows([]);
        setError(response?.message || "Impossible de charger les articles.");
        setLoading(false);
        return;
      }

      setRows(asArrayPayload(response));
      setLoading(false);
    }

    loadArticles();

    return () => {
      isMounted = false;
    };
  }, [deferredSearch, statusFilter, refreshKey]);

  function resetEditor() {
    setEditorMode("");
    setFormValues(createArticleFormState());
  }

  function handleNewArticle() {
    sharedTable?.clearSelectedRow?.();
    setEditorMode("create");
    setFormValues(createArticleFormState());
  }

  function handleEditArticle(article) {
    sharedTable?.setSelectedRow?.(article);
    setEditorMode("edit");
    setFormValues(mapArticleToForm(article));
  }

  async function handleDisableArticle(article) {
    if (!window.confirm(`Desactiver l'article "${article.NomArticle}" ?`)) {
      return;
    }

    const response = await deleteLogistiqueArticle(article.ID_Article);

    if (!response?.success) {
      setFeedback({ type: "error", message: getApiMessage(response, "Impossible de desactiver l'article.") });
      return;
    }

    setFeedback({ type: "success", message: "Article desactive avec succes." });
    onDataChanged?.();
  }

  async function handleSubmit(event) {
    event.preventDefault();
    setSubmitting(true);

    const payload = {
      ...formValues,
      ID_TypeArticleFk: formValues.ID_TypeArticleFk || null,
      ID_CategorieArticleFk: formValues.ID_CategorieArticleFk || null,
      QteMinArticle: formValues.QteMinArticle || null,
    };

    if (editorMode === "create" || formValues.ID_UserFK || selectedArticle?.IdUser != null || selectedArticle?.ID_UserFK != null) {
      payload.ID_UserFK = formValues.ID_UserFK || null;
    }

    if (editorMode === "create" || formValues.ID_UniteFk || selectedArticle?.ID_UniteFk != null) {
      payload.ID_UniteFk = formValues.ID_UniteFk || null;
    }

    if (
      editorMode === "create" ||
      formValues.DatePeremptionArticle ||
      selectedArticle?.DatePeremptionArticle != null
    ) {
      payload.DatePeremptionArticle = formValues.DatePeremptionArticle || null;
    }

    const response =
      editorMode === "edit" && selectedArticle
        ? await updateLogistiqueArticle(selectedArticle.ID_Article, payload)
        : await createLogistiqueArticle(payload);

    setSubmitting(false);

    if (!response?.success) {
      setFeedback({ type: "error", message: getApiMessage(response, "Enregistrement de l'article impossible.") });
      return;
    }

    setFeedback({
      type: "success",
      message: editorMode === "edit" ? "Article mis a jour avec succes." : "Article cree avec succes.",
    });
    resetEditor();
    onDataChanged?.();
  }

  return (
    <div className="logistics-stack">
      <StatusBanner feedback={feedback} />

      <SectionCard
        title="Catalogue des articles"
        subtitle="Lecture via la vue V_Article et ecriture maitrisee dans T_Article."
        actions={
          <div className="logistics-inline-actions">
            <button type="button" className="secondary-action" onClick={handleNewArticle}>
              Nouveau article
            </button>
          </div>
        }
      >
        <div className="logistics-filter-grid">
          <label className="admin-form-field">
            <span>{sharedTable?.searchLabel || "Recherche globale"}</span>
            <input
              type="search"
              value={sharedTable?.searchValue || ""}
              onChange={(event) => sharedTable?.setSearchValue?.(event.target.value)}
              placeholder="Nom, reference, code interne..."
            />
          </label>

          <label className="admin-form-field">
            <span>Statut</span>
            <select value={statusFilter} onChange={(event) => setStatusFilter(event.target.value)}>
              <option value="all">Tous</option>
              <option value="true">Actifs</option>
              <option value="false">Desactives</option>
            </select>
          </label>
        </div>

        <TableToolbar
          title={sharedTable?.toolbarTitle || "Tableau V_Article"}
          rows={rows}
          columns={tableColumns.filter((column) => column.key !== "actions")}
          exportFilename={sharedTable?.exportFilename || "logistique-v_article.csv"}
        />

        <LoadingErrorEmpty loading={loading} error={error} rows={rows} emptyMessage="Aucun article a afficher." />

        {!loading && !error && rows.length > 0 ? (
          <SimpleTable
            rows={rows}
            columns={tableColumns}
            selectedRowId={selectedArticle?.ID_Article || null}
            onRowSelect={sharedTable?.setSelectedRow}
          />
        ) : null}
      </SectionCard>

      <SelectionStrip
        selectedRow={selectedArticle}
        label={selectedArticle ? `Ligne selectionnee: article #${selectedArticle.ID_Article}` : "Aucune ligne selectionnee"}
        description={
          selectedArticle
            ? `${selectedArticle.NomArticle || "-"} | ${selectedArticle.CodeArticleInterne || "Sans code"}`
            : "Cliquez une ligne pour l'activer et reutiliser ses actions hors du tableau."
        }
        actions={
          selectedArticle ? (
            <>
              <button type="button" className="secondary-action" onClick={() => handleEditArticle(selectedArticle)}>
                Modifier
              </button>
              <button type="button" className="admin-danger-button" onClick={() => handleDisableArticle(selectedArticle)}>
                Desactiver
              </button>
            </>
          ) : null
        }
      />

      <FkMappingCard
        mappings={sharedTable?.fkMappings || []}
      />

      {selectedArticle ? (
        <SectionCard title="Fiche article" subtitle="Lecture detaillee issue de la vue logistique.">
          <div className="logistics-detail-grid">
            <article>
              <strong>{selectedArticle.NomArticle}</strong>
              <p>Code interne: {selectedArticle.CodeArticleInterne || "-"}</p>
              <p>Reference: {selectedArticle.RefArticle || "-"}</p>
              <p>Type: {typeLabelMap.get(String(selectedArticle.ID_TypeArticleFk)) || "-"}</p>
              <p>Categorie: {categoryLabelMap.get(String(selectedArticle.ID_CategorieArticleFk)) || "-"}</p>
            </article>
            <article>
              <p>Utilisateur: {selectedArticle.NomComplet || userLabelMap.get(String(selectedArticle.IdUser)) || "-"}</p>
              <p>Unite: {unitLabelMap.get(String(selectedArticle.ID_UniteFk)) || "-"}</p>
              <p>Stock courant: {formatNumber(selectedArticle.QteArticle)}</p>
              <p>Seuil minimum: {formatNumber(selectedArticle.QteMinArticle)}</p>
              <p>PU: {formatCurrency(selectedArticle.PUArticle)}</p>
              <p>PV: {formatCurrency(selectedArticle.PVArticle)}</p>
              <p>Peremption: {formatDate(selectedArticle.DatePeremptionArticle)}</p>
            </article>
          </div>
        </SectionCard>
      ) : null}

      {editorMode ? (
        <SectionCard
          title={editorMode === "edit" ? "Modifier l'article" : "Creer un article"}
          subtitle="Le formulaire ecrit directement dans T_Article sans toucher aux triggers existants."
        >
          <form className="admin-editor-form" onSubmit={handleSubmit}>
            <div className="admin-editor-grid">
              <label className="admin-form-field">
                <span>Nom article</span>
                <input
                  type="text"
                  value={formValues.NomArticle}
                  onChange={(event) => setFormValues((current) => ({ ...current, NomArticle: event.target.value }))}
                  required
                />
              </label>

              <label className="admin-form-field">
                <span>Reference</span>
                <input
                  type="text"
                  value={formValues.RefArticle}
                  onChange={(event) => setFormValues((current) => ({ ...current, RefArticle: event.target.value }))}
                />
              </label>

              <label className="admin-form-field">
                <span>Code interne</span>
                <input
                  type="text"
                  value={formValues.CodeArticleInterne}
                  onChange={(event) =>
                    setFormValues((current) => ({ ...current, CodeArticleInterne: event.target.value }))
                  }
                />
              </label>

              <SelectField
                label="Type article"
                value={formValues.ID_TypeArticleFk}
                onChange={(event) => setFormValues((current) => ({ ...current, ID_TypeArticleFk: event.target.value }))}
                options={articleTypeOptions}
              />

              <SelectField
                label="Categorie article"
                value={formValues.ID_CategorieArticleFk}
                onChange={(event) =>
                  setFormValues((current) => ({ ...current, ID_CategorieArticleFk: event.target.value }))
                }
                options={articleCategoryOptions}
              />

              <SelectField
                label="Utilisateur"
                value={formValues.ID_UserFK}
                onChange={(event) => setFormValues((current) => ({ ...current, ID_UserFK: event.target.value }))}
                options={userOptions}
              />

              <SelectField
                label="Unite"
                value={formValues.ID_UniteFk}
                onChange={(event) => setFormValues((current) => ({ ...current, ID_UniteFk: event.target.value }))}
                options={articleUnitOptions}
              />

              <label className="admin-form-field">
                <span>Stock initial</span>
                <input
                  type="number"
                  min="0"
                  step="0.001"
                  value={formValues.QteArticle}
                  onChange={(event) => setFormValues((current) => ({ ...current, QteArticle: event.target.value }))}
                />
              </label>

              <label className="admin-form-field">
                <span>Seuil minimum</span>
                <input
                  type="number"
                  min="0"
                  step="1"
                  value={formValues.QteMinArticle}
                  onChange={(event) => setFormValues((current) => ({ ...current, QteMinArticle: event.target.value }))}
                />
              </label>

              <label className="admin-form-field">
                <span>Prix achat</span>
                <input
                  type="number"
                  min="0"
                  step="0.01"
                  value={formValues.PUArticle}
                  onChange={(event) => setFormValues((current) => ({ ...current, PUArticle: event.target.value }))}
                  required
                />
              </label>

              <label className="admin-form-field">
                <span>Prix vente</span>
                <input
                  type="number"
                  min="0"
                  step="0.01"
                  value={formValues.PVArticle}
                  onChange={(event) => setFormValues((current) => ({ ...current, PVArticle: event.target.value }))}
                  required
                />
              </label>

              <label className="admin-form-field">
                <span>Date peremption</span>
                <input
                  type="date"
                  value={formValues.DatePeremptionArticle}
                  onChange={(event) =>
                    setFormValues((current) => ({ ...current, DatePeremptionArticle: event.target.value }))
                  }
                />
              </label>

              <label className="admin-checkbox-field">
                <input
                  type="checkbox"
                  checked={formValues.ValideArticle}
                  onChange={(event) => setFormValues((current) => ({ ...current, ValideArticle: event.target.checked }))}
                />
                <span>Article actif</span>
              </label>

              <label className="admin-form-field admin-form-field-wide">
                <span>Observation</span>
                <textarea
                  value={formValues.ObsArticle}
                  onChange={(event) => setFormValues((current) => ({ ...current, ObsArticle: event.target.value }))}
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
