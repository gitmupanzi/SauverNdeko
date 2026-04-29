import { useDeferredValue, useEffect, useMemo, useState } from "react";
import { useAuth } from "../../contexts/AuthContext";
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
  computeArticleAlertDate,
  computeArticleAlertDays,
  getLogistiqueCrudConfig,
  getLogistiqueGenericSourceHint,
  getLogistiqueViewConfig,
} from "./views";

const ARTICLES_VIEW_CONFIG = getLogistiqueViewConfig("articles");
const ARTICLES_CRUD_CONFIG = getLogistiqueCrudConfig("articles");

function buildReferenceHelperText(sourceKey, options) {
  const count = Array.isArray(options) ? options.length : 0;
  return `${getLogistiqueGenericSourceHint(sourceKey)} | ${count} option(s) chargee(s)`;
}

function formatUserDisplayName(user) {
  if (!user) {
    return "";
  }

  return [user.NomUser, user.PrenomUser].filter(Boolean).join(" ").trim() || user.EmailUser || "Utilisateur connecte";
}

export default function Articles({ references, refreshKey, onDataChanged, sharedTable }) {
  const { user: currentUser } = useAuth();
  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [feedback, setFeedback] = useState(null);
  const [statusFilter, setStatusFilter] = useState("all");
  const [editorMode, setEditorMode] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [formValues, setFormValues] = useState(() => ARTICLES_CRUD_CONFIG.createFormState());
  const deferredSearch = useDeferredValue(sharedTable?.searchValue || "");
  const selectedArticle = sharedTable?.selectedRow || null;
  const currentUserId = currentUser?.IdUser != null ? String(currentUser.IdUser) : "";
  const currentUserDisplayName = useMemo(() => formatUserDisplayName(currentUser), [currentUser]);

  const articleTypeOptions = useMemo(() => buildReferenceOptions(references?.articleTypes, "Type"), [references]);
  const articleCategoryOptions = useMemo(
    () => buildReferenceOptions(references?.articleCategories, "Categorie"),
    [references]
  );
  const userOptions = useMemo(() => buildReferenceOptions(references?.users, "Utilisateur"), [references]);
  const articleUnitOptions = useMemo(() => buildReferenceOptions(references?.articleUnits, "Unite"), [references]);
  const articleReferenceWarnings = useMemo(
    () =>
      [
        articleTypeOptions.length === 0 ? "La liste Type d'article est vide." : "",
        articleCategoryOptions.length === 0 ? "La liste Categorie d'article est vide." : "",
        articleUnitOptions.length === 0 ? "La liste Unite est vide." : "",
      ].filter(Boolean),
    [articleCategoryOptions.length, articleTypeOptions.length, articleUnitOptions.length]
  );
  const typeLabelMap = useMemo(() => buildReferenceLabelMap(articleTypeOptions), [articleTypeOptions]);
  const categoryLabelMap = useMemo(() => buildReferenceLabelMap(articleCategoryOptions), [articleCategoryOptions]);
  const unitLabelMap = useMemo(() => buildReferenceLabelMap(articleUnitOptions), [articleUnitOptions]);
  const userLabelMap = useMemo(() => buildReferenceLabelMap(userOptions), [userOptions]);
  const computedAlertDate = useMemo(
    () => computeArticleAlertDate(formValues.DatePeremptionArticle, formValues.NbreJoursAlerteArticle),
    [formValues.DatePeremptionArticle, formValues.NbreJoursAlerteArticle]
  );
  const articleEditorUserLabel = useMemo(() => {
    if (editorMode === "create") {
      return currentUserDisplayName || "Utilisateur connecte indisponible";
    }

    return (
      userLabelMap.get(String(formValues.ID_UserFK || "")) ||
      selectedArticle?.NomComplet ||
      currentUserDisplayName ||
      "-"
    );
  }, [currentUserDisplayName, editorMode, formValues.ID_UserFK, selectedArticle, userLabelMap]);
  const tableColumns = useMemo(
    () => [
      { key: "NomArticle", label: "Article" },
      { key: "CodeArticleInterne", label: "Code" },
      { key: "CodeArticleExterne", label: "Code externe", renderText: (row) => row.CodeArticleExterne || "-" },
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

      const response = await ARTICLES_VIEW_CONFIG.fetchRows({
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

      const nextRows = asArrayPayload(response);
      setRows(nextRows);
      if (selectedArticle?.ID_Article != null) {
        const matchedArticle = nextRows.find((row) => row.ID_Article === selectedArticle.ID_Article);
        if (matchedArticle) {
          sharedTable?.setSelectedRow?.(matchedArticle);
        } else {
          sharedTable?.clearSelectedRow?.();
        }
      }
      setLoading(false);
    }

    loadArticles();

    return () => {
      isMounted = false;
    };
  }, [deferredSearch, statusFilter, refreshKey]);

  useEffect(() => {
    if (editorMode !== "create" || !currentUserId) {
      return;
    }

    setFormValues((current) =>
      current.ID_UserFK === currentUserId
        ? current
        : {
            ...current,
            ID_UserFK: currentUserId,
          }
    );
  }, [currentUserId, editorMode]);

  useEffect(() => {
    if (!editorMode) {
      return;
    }

    const nextValue = computedAlertDate || "";

    setFormValues((current) =>
      current.DatePeremptionAlerteArticle === nextValue
        ? current
        : {
            ...current,
            DatePeremptionAlerteArticle: nextValue,
          }
    );
  }, [computedAlertDate, editorMode]);

  function resetEditor() {
    setEditorMode("");
    setFormValues(ARTICLES_CRUD_CONFIG.createFormState());
  }

  function handleNewArticle() {
    sharedTable?.clearSelectedRow?.();
    setEditorMode("create");
    setFormValues({
      ...ARTICLES_CRUD_CONFIG.createFormState(),
      ID_UserFK: currentUserId,
    });
  }

  function handleEditArticle(article) {
    sharedTable?.setSelectedRow?.(article);
    setEditorMode("edit");
    setFormValues(ARTICLES_CRUD_CONFIG.mapRecordToForm(article));
  }

  async function handleDisableArticle(article) {
    if (!window.confirm(`Desactiver l'article "${article.NomArticle}" ?`)) {
      return;
    }

    const response = await ARTICLES_CRUD_CONFIG.deleteRecord({ record: article });

    if (!response?.success) {
      setFeedback({ type: "error", message: getApiMessage(response, "Impossible de desactiver l'article.") });
      return;
    }

    setFeedback({ type: "success", message: ARTICLES_CRUD_CONFIG.messages.deleteSuccess });
    onDataChanged?.();
  }

  async function handleSubmit(event) {
    event.preventDefault();
    setSubmitting(true);

    const payload = ARTICLES_CRUD_CONFIG.buildPayload(formValues, {
      mode: editorMode,
      record: selectedArticle,
    });

    const response =
      editorMode === "edit" && selectedArticle
        ? await ARTICLES_CRUD_CONFIG.updateRecord({ record: selectedArticle, payload })
        : await ARTICLES_CRUD_CONFIG.createRecord({ payload });

    setSubmitting(false);

    if (!response?.success) {
      setFeedback({ type: "error", message: getApiMessage(response, "Enregistrement de l'article impossible.") });
      return;
    }

    setFeedback({
      type: "success",
      message:
        editorMode === "edit"
          ? ARTICLES_CRUD_CONFIG.messages.updateSuccess
          : ARTICLES_CRUD_CONFIG.messages.createSuccess,
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
            defaultPinnedColumns={["NomArticle", "CodeArticleInterne"]}
            defaultSortColumn="NomArticle"
            exportFilename={sharedTable?.exportFilename || "logistique-v_article.csv"}
          />
        ) : null}
      </SectionCard>

      {selectedArticle ? (
        <SectionCard title="Fiche article" subtitle="Lecture detaillee issue de la vue logistique.">
          <div className="logistics-detail-grid">
            <article>
              <strong>{selectedArticle.NomArticle}</strong>
              <p>Code interne: {selectedArticle.CodeArticleInterne || "-"}</p>
              <p>Code externe: {selectedArticle.CodeArticleExterne ?? "-"}</p>
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
              <p>Alerte peremption: {formatDate(selectedArticle.DatePeremptionAlerteArticle)}</p>
              <p>
                Jours d'alerte:{" "}
                {(selectedArticle.NbreJoursAlerteArticle ??
                  computeArticleAlertDays(
                    selectedArticle.DatePeremptionArticle,
                    selectedArticle.DatePeremptionAlerteArticle
                  )) ||
                  "-"}
              </p>
              <p>Photo: {selectedArticle.PhotoArticle || "-"}</p>
            </article>
          </div>
        </SectionCard>
      ) : null}

      {editorMode ? (
        <SectionCard
          title={editorMode === "edit" ? "Modifier l'article" : "Creer un article"}
          subtitle="Le formulaire ecrit directement dans T_Article sans toucher aux triggers existants."
        >
          {articleReferenceWarnings.length > 0 ? (
            <section className="table-empty-state">
              {`References logistiques a completer: ${articleReferenceWarnings.join(" ")}`}
            </section>
          ) : null}

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

              <label className="admin-form-field">
                <span>Code externe</span>
                <input
                  type="number"
                  min="1"
                  step="1"
                  value={formValues.CodeArticleExterne}
                  onChange={(event) =>
                    setFormValues((current) => ({ ...current, CodeArticleExterne: event.target.value }))
                  }
                />
              </label>

              <SelectField
                label="Type article"
                value={formValues.ID_TypeArticleFk}
                onChange={(event) => setFormValues((current) => ({ ...current, ID_TypeArticleFk: event.target.value }))}
                options={articleTypeOptions}
                disabled={articleTypeOptions.length === 0}
                emptyLabel={articleTypeOptions.length === 0 ? "Aucune option disponible" : "Choisir"}
                helperText={buildReferenceHelperText("logistique.articleTypes", articleTypeOptions)}
              />

              <SelectField
                label="Categorie article"
                value={formValues.ID_CategorieArticleFk}
                onChange={(event) =>
                  setFormValues((current) => ({ ...current, ID_CategorieArticleFk: event.target.value }))
                }
                options={articleCategoryOptions}
                disabled={articleCategoryOptions.length === 0}
                emptyLabel={articleCategoryOptions.length === 0 ? "Aucune option disponible" : "Choisir"}
                helperText={buildReferenceHelperText("logistique.articleCategories", articleCategoryOptions)}
              />

              <label className="admin-form-field">
                <span>Utilisateur</span>
                <input type="text" value={articleEditorUserLabel} disabled readOnly />
                <small>
                  {editorMode === "create"
                    ? `Attribue automatiquement a l'utilisateur connecte${currentUserId ? ` (ID ${currentUserId})` : ""}.`
                    : `Identifiant utilisateur: ${formValues.ID_UserFK || "-"}.`}
                </small>
              </label>

              <SelectField
                label="Unite"
                value={formValues.ID_UniteFk}
                onChange={(event) => setFormValues((current) => ({ ...current, ID_UniteFk: event.target.value }))}
                options={articleUnitOptions}
                disabled={articleUnitOptions.length === 0}
                emptyLabel={articleUnitOptions.length === 0 ? "Aucune option disponible" : "Choisir"}
                helperText={buildReferenceHelperText("logistique.articleUnits", articleUnitOptions)}
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

              <label className="admin-form-field">
                <span>Date alerte peremption</span>
                <input
                  type="date"
                  value={formValues.DatePeremptionAlerteArticle}
                  disabled
                  readOnly
                />
                <small>
                  {computedAlertDate
                    ? "Calculee automatiquement a partir de la date de peremption et du nombre de jours."
                    : "Renseignez la date de peremption et le nombre de jours pour calculer automatiquement la date d'alerte."}
                </small>
              </label>

              <label className="admin-form-field">
                <span>Nb jours alerte</span>
                <input
                  type="number"
                  min="0"
                  step="1"
                  value={formValues.NbreJoursAlerteArticle}
                  onChange={(event) =>
                    setFormValues((current) => ({ ...current, NbreJoursAlerteArticle: event.target.value }))
                  }
                />
                <small>
                  La date d'alerte de peremption est calculee automatiquement a partir de cette valeur.
                </small>
              </label>

              <label className="admin-form-field">
                <span>Photo URL</span>
                <input
                  type="url"
                  value={formValues.PhotoArticle}
                  onChange={(event) => setFormValues((current) => ({ ...current, PhotoArticle: event.target.value }))}
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
