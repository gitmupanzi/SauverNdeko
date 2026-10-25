import LotFields, {lotErrors} from "../../components/LotFields";
import {requestJson} from "../../services/api";
import { useAuth } from "../../contexts/AuthContext";
import { useConsultations } from "../../components/ConsultationProvider";
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

function getDetailLineState(detail) {
  const label = String(detail?.EtatLigne || "");
  const normalized = normalizeSearchText(label);

  if (normalized.includes("quantite invalide")) {
    return { key: "quantite-invalide", label: label || "Quantite invalide", tone: "danger" };
  }

  if (normalized.includes("prix")) {
    return { key: "prix-manquant", label: label || "Prix non renseigne", tone: "warning" };
  }

  return { key: "valide", label: label || "Valide", tone: "success" };
}

export default function CommandeDetails({ selectedCommande, references, refreshKey, onDataChanged, sharedTable, onToggleFkMappings }) {
  const { openProduct, openOrder } = useConsultations();
  const { user } = useAuth();
  const canWrite = user?.permissions?.canWriteData === true;
  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [feedback, setFeedback] = useState(null);
  const [editorMode, setEditorMode] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [formValues, setFormValues] = useState(() => COMMANDE_DETAILS_CRUD_CONFIG.createFormState());
  const [lotsLoaded,setLotsLoaded]=useState(false),[lotsRevision,setLotsRevision]=useState(0);
  const [lots,setLots]=useState([]),[lotsLoading,setLotsLoading]=useState(false),[lotsError,setLotsError]=useState(""),[knownLots,setKnownLots]=useState([]);
  const [articleSearch, setArticleSearch] = useState("");
  const [commandeFilter, setCommandeFilter] = useState("");
  const [typeFilter, setTypeFilter] = useState("all");
  const [statusFilter, setStatusFilter] = useState("all");
  const [articleFilter, setArticleFilter] = useState("");
  const [lineStateFilter, setLineStateFilter] = useState("all");
  const [dateFrom, setDateFrom] = useState("");
  const [dateTo, setDateTo] = useState("");
  const selectedDetail = sharedTable?.selectedRow || null;
  const composerMode = sharedTable?.composerMode || "view";
  const sharedSearchTerm = normalizeSearchText(sharedTable?.searchValue || "").trim();
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
  const commandeTypeLabelMap = useMemo(
    () => buildReferenceLabelMap(Array.isArray(references?.commandeTypes) ? references.commandeTypes : []),
    [references]
  );
  const commandeStatusLabelMap = useMemo(
    () => buildReferenceLabelMap(Array.isArray(references?.commandeStatuses) ? references.commandeStatuses : []),
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
  const previousQuantity=editorMode==="edit" && String(selectedDetail?.ID_ArticleFk)===String(selectedArticle?.id)?Number(selectedDetail.QteCmdDetail||0):0;
  const quantityDelta=quantityNumber-previousQuantity;
  const projectedStock =
    commandeDirection === "sortie"
      ? selectedArticleStock - quantityDelta
      : commandeDirection === "entree"
        ? selectedArticleStock + quantityDelta
        : selectedArticleStock;
  const stockError =
    commandeDirection === "sortie" &&
    selectedArticle &&
    Number.isFinite(quantityNumber) &&
    quantityNumber > 0 &&
    projectedStock < 0;
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
  const visibleRows = useMemo(
    () =>
      rows.filter((row) => {
        if (
          sharedSearchTerm &&
          !normalizeSearchText(
            [row.CodeCmd, row.CodeFacture, row.CodeArticleInterne, row.NomArticle, row.TypeCmd, row.StatutCmd]
              .filter(Boolean)
              .join(" ")
          ).includes(sharedSearchTerm)
        ) {
          return false;
        }

        if (commandeFilter && !String(row.CodeCmd || "").toLowerCase().includes(String(commandeFilter).toLowerCase())) {
          return false;
        }

        if (typeFilter !== "all") {
          const rowType = String(row.TypeCmd || commandeTypeLabelMap.get(String(row.ID_TypeCmdFk)) || "");
          if (normalizeSearchText(rowType) !== normalizeSearchText(typeFilter)) {
            return false;
          }
        }

        if (statusFilter !== "all") {
          const rowStatus = String(row.StatutCmd || commandeStatusLabelMap.get(String(row.ID_StatutCmdFk)) || "");
          if (normalizeSearchText(rowStatus) !== normalizeSearchText(statusFilter)) {
            return false;
          }
        }

        if (articleFilter && String(row.ID_ArticleFk || "") !== String(articleFilter)) {
          return false;
        }

        if (lineStateFilter !== "all" && getDetailLineState(row).key !== lineStateFilter) {
          return false;
        }

        if (dateFrom && row.DateCmd && new Date(row.DateCmd) < new Date(dateFrom)) {
          return false;
        }

        if (dateTo && row.DateCmd && new Date(row.DateCmd) > new Date(`${dateTo}T23:59:59`)) {
          return false;
        }

        return true;
      }),
    [articleFilter, commandeFilter, commandeStatusLabelMap, commandeTypeLabelMap, dateFrom, dateTo, lineStateFilter, rows, sharedSearchTerm, statusFilter, typeFilter]
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
      setLoading(true);
      setError("");

      const response = await COMMANDE_DETAILS_VIEW_CONFIG.fetchRows({
        commandeId: selectedCommande?.ID_Commande,
        take: 150,
      });

      if (!isMounted) {
        return;
      }

      if (!response?.success) {
        setRows([]);
        setError(response?.message || "Impossible de charger les lignes du bon.");
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
  }, [refreshKey, selectedCommande?.ID_Commande]);

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

  useEffect(()=>{
    if(!editorMode||!formValues.ID_ArticleFk){setLots([]);setKnownLots([]);return;}
    let active=true;setLotsLoading(true);setLotsLoaded(false);setLotsError("");setLots([]);
    const articleId=formValues.ID_ArticleFk;
    const url=editorMode==="edit"&&selectedDetail&&String(selectedDetail.ID_ArticleFk)===String(articleId)
      ?"/api/logistique/commande-details/"+selectedDetail.ID_CmdFk+"/"+articleId:null;
    Promise.all([requestJson("/api/logistique/consultations/produit/"+articleId+"/lots?take=500",{requiresAuth:true}),url?requestJson(url,{requiresAuth:true}):Promise.resolve(null)]).then(([available,current])=>{
      if(!active)return;
      if(!available?.success || (url&&!current?.success)){setLotsError("Les lots n’ont pas pu être chargés.");setLotsLoading(false);return;}
      setKnownLots(available.data || []);setLotsLoaded(true);
      setLots((current?.data?.Lots || []).map(row=>({NumeroLot:row.NumeroLot,Quantite:String(row.Quantite),DatePeremptionLot:row.DatePeremptionLot?String(row.DatePeremptionLot).slice(0,10):""})));
      setLotsLoading(false);
    });
    return()=>{active=false;};
  },[editorMode,formValues.ID_ArticleFk,selectedDetail?.ID_CmdFk,selectedDetail?.ID_ArticleFk,lotsRevision]);

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
      setFeedback({ type: "error", message: "Cet article existe deja dans le bon de stock. Modifiez la ligne existante." });
      return;
    }

    if (stockError) {
      setFeedback({
        type: "error",
        message: "La quantite demandee depasse le stock disponible pour ce bon de sortie.",
      });
      return;
    }

    if(!canWrite||submitting||lotsLoading||!lotsLoaded)return;
    const lotError=lotErrors(lots,formValues.QteCmdDetail);setLotsError(lotError);if(lotError)return;
    setSubmitting(true);

    const payload = COMMANDE_DETAILS_CRUD_CONFIG.buildPayload(formValues, {
      mode: editorMode,
      record: selectedDetail,
      parentRecord: selectedCommande,
    });

    payload.Lots=lots;
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

  return (
    <div className="logistics-screen">
      <StatusBanner feedback={feedback} />
      <header className="logistics-screen-copy">
        <h1>Lignes des bons</h1>
        <p>Lignes des bons, quantites, prix et controle du stock</p>
      </header>

      <section className="logistics-screen-search-card">
        <label className="admin-form-field logistics-screen-search-field">
          <span>{sharedTable?.searchLabel || "Recherche"}</span>
          <input
            type="search"
            value={sharedTable?.searchValue || ""}
            onChange={(event) => sharedTable?.setSearchValue?.(event.target.value)}
            placeholder="Rechercher une ligne, bon de stock, article ou facture..."
          />
        </label>
      </section>

      <section className="logistics-top-actions">
        <button type="button" className="logistics-top-action is-blue" onClick={handleNewLine} disabled={!canWrite || !selectedCommande}>
          Ajouter ligne
        </button>
        <button type="button" className="logistics-top-action is-indigo" onClick={() => selectedDetail && handleEditLine(selectedDetail)} disabled={!canWrite || !selectedCommande || !selectedDetail}>
          Modifier ligne
        </button>
        <button type="button" className="logistics-top-action is-red" onClick={() => selectedDetail && handleDeleteLine(selectedDetail)} disabled={!selectedCommande || !selectedDetail}>
          Supprimer ligne
        </button>
        <button type="button" className="logistics-top-action is-cyan" onClick={() => selectedDetail && openOrder(selectedDetail)} disabled={!selectedDetail}>
          Voir
        </button>
        <button type="button" className="logistics-top-action is-sky" onClick={onToggleFkMappings}>Réglages</button>
      </section>

      <section className="logistics-screen-filter-card">
        <div className="logistics-mockup-filter-grid">
          <label className="admin-form-field">
            <span>Bon de stock</span>
            <input type="search" value={commandeFilter} onChange={(event) => setCommandeFilter(event.target.value)} placeholder="N° de bon..." />
          </label>

          <label className="admin-form-field">
            <span>Type de bon</span>
            <select value={typeFilter} onChange={(event) => setTypeFilter(event.target.value)}>
              <option value="all">Toutes</option>
              {Array.from(new Set(rows.map((row) => row.TypeCmd).filter(Boolean))).map((label) => (
                <option key={label} value={label}>
                  {label}
                </option>
              ))}
            </select>
          </label>

          <label className="admin-form-field">
            <span>Statut du bon</span>
            <select value={statusFilter} onChange={(event) => setStatusFilter(event.target.value)}>
              <option value="all">Toutes</option>
              {Array.from(new Set(rows.map((row) => row.StatutCmd).filter(Boolean))).map((label) => (
                <option key={label} value={label}>
                  {label}
                </option>
              ))}
            </select>
          </label>

          <label className="admin-form-field">
            <span>Article</span>
            <select value={articleFilter} onChange={(event) => setArticleFilter(event.target.value)}>
              <option value="">Toutes</option>
              {articleCatalog.map((article) => (
                <option key={article.id} value={article.id}>
                  {article.label}
                </option>
              ))}
            </select>
          </label>

          <label className="admin-form-field">
            <span>Etat ligne</span>
            <select value={lineStateFilter} onChange={(event) => setLineStateFilter(event.target.value)}>
              <option value="all">Toutes</option>
              <option value="valide">Valide</option>
              <option value="quantite-invalide">Quantite invalide</option>
              <option value="prix-manquant">Prix non renseigne</option>
            </select>
          </label>

          <label className="admin-form-field">
            <span>Periode</span>
            <div className="logistics-period-range">
              <input
                type="date"
                value={dateFrom}
                onChange={(event) => setDateFrom(event.target.value)}
                aria-label="Date de debut detail bon de stock"
              />
              <input
                type="date"
                value={dateTo}
                onChange={(event) => setDateTo(event.target.value)}
                aria-label="Date de fin detail bon de stock"
              />
            </div>
          </label>
        </div>
      </section>

      <section className="logistics-screen-table-card">
        {!selectedCommande ? (
          <section className="table-empty-state">
            Selectionnez un bon de stock depuis l'onglet Bons de stock pour ajouter ou modifier des lignes. La vue reste consultable globalement.
          </section>
        ) : null}

        <LoadingErrorEmpty loading={loading} error={error} rows={visibleRows} emptyMessage="Aucune ligne de bon de stock a afficher." />

        {!loading && !error && visibleRows.length > 0 ? (
          <SimpleTable
            rows={visibleRows}
            onRowConsult={(row, key) => key === "CodeCmd" ? openOrder(row) : openProduct(row)}
            consultColumns={["CodeCmd", "NomArticle", "CodeArticleInterne", "ID_ArticleFk"]}
            isCellConsultable={(row, key) => key === "CodeCmd" ? Boolean(row.ID_Commande || row.ID_CmdFk || row.ID_cmdFk) : Boolean(row.ID_Article || row.ID_ArticleFk)}
            selectedRowId={selectedDetail ? `${selectedDetail.ID_CmdFk}-${selectedDetail.ID_ArticleFk}` : null}
            getRowId={(row) => `${row.ID_CmdFk}-${row.ID_ArticleFk}`}
            onRowSelect={sharedTable?.setSelectedRow}
            enableSelection
            showControls
            defaultPinnedColumns={["CodeCmd", "NomArticle"]}
            defaultSortColumn="DateCmd"
            defaultRowsPerPage={10}
            exportFilename={sharedTable?.exportFilename || "logistique-v_commandedetail.csv"}
            columns={[
              { key: "CodeCmd", label: "N° de bon" },
              { key: "CodeFacture", label: "Facture", render: (row) => row.CodeFacture || "-" },
              { key: "DateCmd", label: "Date du bon", render: (row) => formatDate(row.DateCmd, { withTime: true }) },
              {
                key: "TypeCmd",
                label: "Type de bon",
                render: (row) => <ToneBadge tone={normalizeSearchText(row.TypeCmd).includes("sort") ? "warning" : "success"}>{row.TypeCmd || "-"}</ToneBadge>,
              },
              {
                key: "StatutCmd",
                label: "Statut du bon",
                render: (row) => <ToneBadge tone="info">{row.StatutCmd || "-"}</ToneBadge>,
              },
              { key: "CodeArticleInterne", label: "Code article", render: (row) => row.CodeArticleInterne || "-" },
              { key: "NomArticle", label: "Article" },
              { key: "AbrUnite", label: "Unite", render: (row) => row.AbrUnite || "-" },
              {
                key: "StockAvantLigneTheorique",
                label: "Stock avant theorique",
                render: (row) => formatNumber(row.StockAvantLigneTheorique),
              },
              { key: "StockActuel", label: "Stock actuel", render: (row) => formatNumber(row.StockActuel) },
              { key: "QteCmdDetail", label: "Quantite", render: (row) => formatNumber(row.QteCmdDetail) },
              { key: "PUCmdDetail", label: "PU", render: (row) => formatCurrency(row.PUCmdDetail) },
              {
                key: "MontantLigne",
                label: "Montant ligne",
                render: (row) => formatCurrency(row.MontantLigne ?? Number(row.QteCmdDetail || 0) * Number(row.PUCmdDetail || 0)),
              },
              { key: "LieuCmdDetail", label: "Lieu", render: (row) => row.LieuCmdDetail ?? "-" },
              {
                key: "EtatLigne",
                label: "Etat ligne",
                render: (row) => {
                  const lineState = getDetailLineState(row);
                  return <ToneBadge tone={lineState.tone}>{lineState.label}</ToneBadge>;
                },
              },
              {
                key: "actions",
                label: "Actions",
                render: (row) => (
                  <div className="logistics-table-actions" onClick={(event) => event.stopPropagation()}>
                    <button type="button" className="logistics-kebab-button" onClick={() => sharedTable?.setSelectedRow?.(row)} aria-label={`Actions ${row.NomArticle || "ligne"}`}>
                      ⋮
                    </button>
                  </div>
                ),
              },
            ]}
          />
        ) : null}
      </section>

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
          title={editorMode === "edit" ? "Modifier la ligne produit" : "Ajouter un produit au bon de stock"}
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
                  enableSelection
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
                      Cet article est deja present dans le bon de stock. Modifiez plutot la ligne existante.
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
                        min="1"
                        step="1"
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
                        type="text"
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

                  <LotFields value={lots} onChange={setLots} total={formValues.QteCmdDetail} disabled={submitting||lotsLoading} known={knownLots} outgoing={commandeDirection==="sortie"} title={commandeDirection==="sortie"?"Lots à sortir":"Lots reçus"} error={lotsError}/>
                  {lotsLoading?<p role="status">Chargement des lots…</p>:!lotsLoaded?<button type="button" className="secondary-action" onClick={()=>setLotsRevision(x=>x+1)}>Recharger les lots</button>:null}
                  <div className="admin-editor-actions">
                    <button type="button" className="secondary-action" onClick={resetEditor} disabled={submitting}>
                      Annuler
                    </button>
                    <button type="submit" className="primary-action" disabled={!canWrite || submitting || lotsLoading || !lotsLoaded || stockError || duplicateArticleInCommande}>
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
                  Selectionnez un article dans la liste de gauche pour preparer la ligne de bon de stock.
                </section>
              )}
            </section>
          </div>
        </SectionCard>
      ) : null}
    </div>
  );
}
