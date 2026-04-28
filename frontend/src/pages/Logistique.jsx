import { startTransition, useEffect, useMemo, useState } from "react";
import { fetchLogistiqueReferences } from "../services/logistique";
import AlertesStock from "./logistique/AlertesStock";
import Articles from "./logistique/Articles";
import CommandeDetails from "./logistique/CommandeDetails";
import Commandes from "./logistique/Commandes";
import ConsommationMensuelle from "./logistique/ConsommationMensuelle";
import CouvertureStock from "./logistique/CouvertureStock";
import DashboardLogistique from "./logistique/DashboardLogistique";
import Mouvements from "./logistique/Mouvements";
import Reglements from "./logistique/Reglements";
import StockAudit from "./logistique/StockAudit";

const TABLE_FEATURE_CONFIG = {
  articles: {
    searchLabel: "Recherche globale",
    toolbarTitle: "Tableau V_Article",
    exportFilename: "logistique-v_article.csv",
    fkMappings: [
      { field: "ID_TypeArticleFk", label: "Type d'article", source: "referentiel.T_Generique | categorie 46" },
      { field: "ID_CategorieArticleFk", label: "Categorie d'article", source: "referentiel.T_Generique | categorie 40" },
      { field: "ID_UserFK", label: "Utilisateur", source: "systeme.T_Utilisateurs" },
      { field: "ID_UniteFk", label: "Unite", source: "referentiel.T_Generique | categorie 34" },
    ],
  },
  commandes: {
    searchLabel: "Recherche globale",
    toolbarTitle: "Tableau V_Commande",
    exportFilename: "logistique-v_commande.csv",
    fkMappings: [
      { field: "ID_TypeCmdFk", label: "Type de commande", source: "referentiel.T_Generique | categorie de commande active en base" },
      { field: "ID_StatutCmd", label: "Statut commande", source: "referentiel.T_Generique | categorie 28" },
      { field: "ID_ClientFk", label: "Client", source: "Source client disponible dans la base actuelle" },
      { field: "ID_UserFk", label: "Utilisateur", source: "systeme.T_Utilisateurs" },
      { field: "ID_ConditionPaiementFk", label: "Condition de paiement", source: "referentiel.T_Generique | categorie 37" },
      { field: "ID_ModePaiementFk", label: "Mode de paiement", source: "referentiel.T_Generique | categorie 36" },
    ],
  },
  details: {
    searchLabel: "Recherche globale",
    toolbarTitle: "Tableau V_CommandeDetail",
    exportFilename: "logistique-v_commandedetail.csv",
    fkMappings: [
      { field: "ID_CmdFk", label: "Commande parent", source: "Vue V_CommandeDetail / logistique.T_Commande" },
      { field: "ID_ArticleFk", label: "Article", source: "logistique.T_Article" },
    ],
  },
  mouvements: {
    searchLabel: "Recherche globale",
    toolbarTitle: "Tableau V_Mouvement",
    exportFilename: "logistique-v_mouvement.csv",
    fkMappings: [
      { field: "ID_TypeMvtFk", label: "Type de mouvement", source: "Vue V_Mouvement / referentiel.T_Generique" },
      { field: "ID_ArticleFk", label: "Article", source: "logistique.T_Article via V_Mouvement" },
      { field: "ID_cmdFk", label: "Commande", source: "logistique.T_Commande via V_Mouvement" },
    ],
  },
  reglements: {
    searchLabel: "Filtre facture",
    toolbarTitle: "Tableau V_SuiviReglements",
    exportFilename: "logistique-v_suivi_reglements.csv",
    fkMappings: [
      { field: "CodeFactureFk", label: "Facture", source: "Codes issus de logistique.T_Commande" },
      { field: "ID_ModeReglementFk", label: "Mode de reglement", source: "referentiel.T_Generique | categorie 36" },
      { field: "ID_ClientFk", label: "Client", source: "Source client disponible dans la base actuelle" },
    ],
  },
};

const TABS = [
  { key: "dashboard", label: "Dashboard" },
  { key: "articles", label: "Articles" },
  { key: "commandes", label: "Commandes" },
  { key: "details", label: "Details" },
  { key: "mouvements", label: "Mouvements" },
  { key: "audit", label: "Audit stock" },
  { key: "alertes", label: "Alertes stock" },
  { key: "consommation", label: "Consommation" },
  { key: "couverture", label: "Couverture" },
  { key: "reglements", label: "Reglements" },
];

export default function Logistique() {
  const [activeTab, setActiveTab] = useState("dashboard");
  const [selectedCommande, setSelectedCommande] = useState(null);
  const [refreshKey, setRefreshKey] = useState(0);
  const [sharedTableState, setSharedTableState] = useState({
    articles: { search: "", selectedRow: null },
    commandes: { search: "", selectedRow: null },
    details: { search: "", selectedRow: null },
    mouvements: { search: "", selectedRow: null },
    reglements: { search: "", selectedRow: null },
  });
  const [references, setReferences] = useState(null);
  const [referencesLoading, setReferencesLoading] = useState(true);
  const [referencesError, setReferencesError] = useState("");

  useEffect(() => {
    let isMounted = true;

    async function loadReferences() {
      setReferencesLoading(true);
      setReferencesError("");

      const response = await fetchLogistiqueReferences();

      if (!isMounted) {
        return;
      }

      if (!response?.success) {
        setReferences(null);
        setReferencesError(response?.message || "Impossible de charger les references logistiques.");
        setReferencesLoading(false);
        return;
      }

      setReferences(response.data);
      setReferencesLoading(false);
    }

    loadReferences();

    return () => {
      isMounted = false;
    };
  }, []);

  function bumpRefresh() {
    setRefreshKey((current) => current + 1);
  }

  function handleNavigate(tabKey) {
    startTransition(() => {
      setActiveTab(tabKey);
    });
  }

  function handleOpenDetails(commande) {
    setSelectedCommande(commande);
    setSharedTableState((current) => ({
      ...current,
      commandes: {
        ...current.commandes,
        selectedRow: commande,
      },
    }));
    handleNavigate("details");
  }

  function updateSharedTableState(tabKey, patch) {
    setSharedTableState((current) => ({
      ...current,
      [tabKey]: {
        ...current[tabKey],
        ...patch,
      },
    }));
  }

  const headerStats = useMemo(
    () => [
      { label: "Articles references", value: references?.articles?.length || 0 },
      { label: "Types de commande connus", value: references?.commandeTypes?.length || 0 },
      { label: "Factures repertoriees", value: references?.factures?.length || 0 },
    ],
    [references]
  );

  const sharedTableFeatures = useMemo(
    () =>
      Object.fromEntries(
        Object.entries(TABLE_FEATURE_CONFIG).map(([tabKey, config]) => [
          tabKey,
          {
            ...config,
            searchValue: sharedTableState[tabKey]?.search || "",
            setSearchValue: (value) => updateSharedTableState(tabKey, { search: value }),
            selectedRow: sharedTableState[tabKey]?.selectedRow || null,
            setSelectedRow: (row) => updateSharedTableState(tabKey, { selectedRow: row }),
            clearSelectedRow: () => updateSharedTableState(tabKey, { selectedRow: null }),
          },
        ])
      ),
    [sharedTableState]
  );

  return (
    <div className="page-shell logistics-page">
      <section className="logistics-hero">
        <div className="section-head">
          <span className="search-kicker">Module logistique</span>
          <h2>Stocks, commandes et reglements</h2>
          <p>
            Tableau de bord centralise du schema logistique, avec lectures depuis les vues SQL et ecritures bornees aux tables autorisees.
          </p>
        </div>

        <div className="logistics-hero-stats">
          {headerStats.map((item) => (
            <article key={item.label}>
              <strong>{item.value}</strong>
              <span>{item.label}</span>
            </article>
          ))}
        </div>
      </section>

      <section className="logistics-workspace">
        <aside className="logistics-tabs-card logistics-sidebar-card">
          <div className="section-head">
            <h3>Sources logistiques</h3>
            <p>Choisissez le volet a consulter.</p>
          </div>

          <div className="logistics-tab-list" role="tablist" aria-label="Navigation interne logistique">
            {TABS.map((tab) => (
              <button
                key={tab.key}
                type="button"
                role="tab"
                aria-selected={activeTab === tab.key}
                className={`logistics-tab ${activeTab === tab.key ? "is-active" : ""}`}
                onClick={() => handleNavigate(tab.key)}
              >
                {tab.label}
              </button>
            ))}
          </div>
        </aside>

        <div className="logistics-main-column">
          {referencesLoading ? <section className="table-empty-state">Chargement des references logistiques...</section> : null}
          {!referencesLoading && referencesError ? <section className="table-empty-state">{referencesError}</section> : null}

          {!referencesLoading && !referencesError ? (
            <>
              {activeTab === "dashboard" ? <DashboardLogistique refreshKey={refreshKey} onNavigate={handleNavigate} /> : null}
              {activeTab === "articles" ? (
                <Articles
                  references={references}
                  refreshKey={refreshKey}
                  onDataChanged={bumpRefresh}
                  sharedTable={sharedTableFeatures.articles}
                />
              ) : null}
              {activeTab === "commandes" ? (
                <Commandes
                  references={references}
                  refreshKey={refreshKey}
                  onDataChanged={bumpRefresh}
                  onOpenDetails={handleOpenDetails}
                  sharedTable={sharedTableFeatures.commandes}
                />
              ) : null}
              {activeTab === "details" ? (
                <CommandeDetails
                  selectedCommande={selectedCommande}
                  references={references}
                  refreshKey={refreshKey}
                  onDataChanged={bumpRefresh}
                  sharedTable={sharedTableFeatures.details}
                />
              ) : null}
              {activeTab === "mouvements" ? (
                <Mouvements references={references} refreshKey={refreshKey} sharedTable={sharedTableFeatures.mouvements} />
              ) : null}
              {activeTab === "audit" ? <StockAudit refreshKey={refreshKey} /> : null}
              {activeTab === "alertes" ? <AlertesStock refreshKey={refreshKey} /> : null}
              {activeTab === "consommation" ? (
                <ConsommationMensuelle references={references} refreshKey={refreshKey} />
              ) : null}
              {activeTab === "couverture" ? <CouvertureStock refreshKey={refreshKey} /> : null}
              {activeTab === "reglements" ? (
                <Reglements
                  references={references}
                  refreshKey={refreshKey}
                  onDataChanged={bumpRefresh}
                  sharedTable={sharedTableFeatures.reglements}
                />
              ) : null}
            </>
          ) : null}
        </div>
      </section>
    </div>
  );
}
