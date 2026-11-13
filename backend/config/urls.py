from apps.core.admin_operations import AdminBatchView, AdminReferencesView, AdminEntitiesView
from apps.core.admin_excel import AdminExcelTemplateView, AdminExcelPreviewView
from apps.professionnels.batches import ProfessionalTemplateView, ProfessionalExcelPreviewView, ProfessionalBatchView
from apps.professionnels.views import (ContextView as ProfessionalContextView, EntitiesView as ProfessionalEntitiesView,
    ReferencesView as ProfessionalReferencesView, DirectoryView as ProfessionalDirectoryView,
    ProfilesView as ProfessionalProfilesView, ProfileActionView, PublicPhotoView as ProfessionalPublicPhotoView,
    ManagementPhotoView as ProfessionalManagementPhotoView)
from apps.caisse.views import (ContextView as CashContextView, EntitiesView as CashEntitiesView,
    ReferencesView as CashReferencesView, SynthesisView as CashSynthesisView, RegisterView as CashRegisterView,
    CashAccountsView, EntriesView as CashEntriesView, EntryActionView as CashEntryActionView,
    ClosuresView as CashClosuresView, ClosurePreparationView, RegisterExportView as CashExportView,
    ValidationSettingsView as CashValidationSettingsView, ValidationPreviewView as CashValidationPreviewView,
    ValidationSelectionView as CashValidationSelectionView)
from apps.caisse.excel_import import CashExcelPreviewView, CashExcelTemplateView
from apps.logistique.batch_excel import LogisticsExcelPreviewView, LogisticsExcelTemplateView
from apps.core.entity_settings import (EntitySettingsContextView, EntitySettingsChoicesView,
    EntitySettingsProfileView, EntitySettingsLogoView)
from apps.core.user_guide import GuideContextView, GuideArticleView, GuideEntitiesView
from apps.support.portal import (SupportContextView, SupportEntitiesView, SupportDashboardView,
    SupportKanbanView, SupportTicketsView, SupportActionsView, SupportCommentsView,
    SupportDocumentsView, SupportDocumentDownloadView, SupportExcelView, SupportCSVView)
from apps.support.batches import SupportTemplateView, SupportExcelPreviewView, SupportBatchView
from apps.core.territorial_portal import TerritorialOverviewView,TerritorialRegisterView,TerritorialReferencesView,TerritorialExcelView,TerritorialCSVView,TerritorialPublicationView
from apps.core.territorial_batches import TerritorialBatchView
from apps.core.territorial_excel import TerritorialExcelTemplateView, TerritorialExcelImportView
from apps.core.table_preferences import TablePreferencesView
from apps.core.reference_batches import ReferenceBatchView
from apps.core.reference_excel import ReferenceExcelTemplateView, ReferenceExcelImportView
from apps.core.reference_tables import ReferenceTablesView, ReferenceTablesExcelView, ReferenceTablesCSVView
from apps.core.field_references import (FieldReferencesView, FieldReferenceRestoreView,
    FieldReferenceOptionsView, FieldReferenceHistoryView, FieldReferenceExportView)
from apps.core.personnel import PersonnelReferencesView
from apps.core.reference_exports import ReferenceCSVView
from apps.core.admin_portal import AdminCSVView
from apps.logistique.excel import RegisterCSVView
from apps.core.reference_exports import ReferenceExcelView
from apps.core.admin_portal import AdminOverviewView, AdminRegisterView, AdminExcelView
from apps.logistique.expiry import ExpiryPolicyView
from apps.logistique.entity_documents import EntityDocumentIdentityView, EntityLogoView, EntityIdentityDefaultsView
from apps.logistique.valuation import ArticleValuationView, ArticleValuationExcelView
from apps.logistique.lot_register import LotDetailView, LotMovementsView, LotMovementsExcelView
from apps.logistique.inventories import InventoriesView, UnitPrecisionView
from apps.logistique.depots import DepotsView, DepotStocksView
from apps.logistique.depot_registers import DepotRegisterExportView, InventoryLinesView
from apps.logistique.transfers import TransfersView
from apps.logistique.immobilisation_lifecycle import ImmobilisationCycleView, ImmobilisationValuationView
from apps.logistique.immobilisations import ImmobilisationsView, ImmobilisationReferencesView, ImmobilisationHistoryView, ImmobilisationExportView
from apps.logistique.lot_fefo import LotFefoView
from apps.logistique.destinations import DestinationsView
from apps.logistique.tiers import EntreprisesView,TiersView,TiersReferencesView,TiersConsultationView
from apps.accounts.mail_settings import MailSettingsView, MailConnectionTestView
from apps.accounts.password_reset import PasswordResetView, PasswordResetCheckView, PasswordResetConfirmView
from apps.accounts.passwords import PasswordChangeView
from apps.logistique.documents import DocumentPdfView, AttachmentsView
from apps.logistique.credit_notes import OrderCreditsView, CreditView
from apps.logistique.payments import PaymentPreparationView, PaymentBatchView
from apps.logistique.invoices import InvoiceView
from apps.logistique.stock_returns import StockReturnsView
from apps.logistique.order_composer import OrderComposerView, OrderCompositionView
from apps.logistique.article_publication import ArticlePublicationView
from apps.logistique.receipts import ArticleReceiptView
from apps.accounts.photos import ProfilePhotoView
from apps.logistique.photos import ArticlePhotoView, PublicArticlePhotoView
from apps.logistique.article_xlsx import ArticleExcelPreviewView
from apps.logistique.batch_creation import LogisticsBatchView
from django.conf import settings
from django.contrib import admin
from django.urls import include, re_path
from apps.accounts.views import (
    LoginView,
    RegisterView,
    RefreshView,
    MeView,
    VerifyView,
    LogoutView,
)
from apps.core.views import (
    HealthView,
    ModuleView,
    ModelListView,
    ViewsView,
    HierarchyView,
    RecherchesView,
    MODULES,
)
from apps.core.ui_settings import UISettingsView
from apps.core.module_presentation import ModulePresentationView, ModulePresentationSettingsView, PresentationModulesView
from apps.core.workspace import WorkspaceModulesView, WorkspaceCatalogueView
from apps.core.application_licences import OrganisationApplicationsView, LicenceApplicationsView, LicenceModulesView, RoleApplicationsView
from apps.core.user_module_access import UserApplicationsView
from apps.catalogue.views import PublicView
from apps.catalogue.summary import CatalogueSummaryView
from apps.catalogue.products import ProductReferencesView, ProductOffersView
from apps.catalogue.structures import StructuresReadView, StructureProfileView, StructureLogoView
from apps.catalogue.territorial_structures import TerritorialStructuresView
from apps.communication.views import ContactsView, DiscussionReadView, DiscussionsView, MessagesView, StartView
from apps.communication.announcements import AnnouncementContextView, AnnouncementsView
from apps.communication.demandes import (SourceContextView as DemandeSourceView, DemandesView,
    DemandeDetailView, DemandeTransitionView, DemandeDiscussionView, DemandeRoutingView)
from apps.communication.notifications import NotificationsView, NotificationReadView, ReceivedAnnouncementsView
from apps.logistique.views import DetailView, StockView, DashboardView, ReferencesView

from apps.logistique.excel import IndicatorExcelView, RegisterExcelView, FolderExcelView
from apps.logistique.followup_folders import FoldersView, FolderCategoriesView, FolderMembersView, FolderPreviewView
from apps.logistique.reads import RegisterReadView, OverviewReadView, IndicatorReadView, ConsultationReadView

urlpatterns = [
    re_path(r"^api/public/catalogue/synthese/?$", CatalogueSummaryView.as_view()),
    re_path(r"^api/structures/annuaire-sanitaire/references/?$", TerritorialStructuresView.as_view(), {'reference': True}),
    re_path(r"^api/structures/annuaire-sanitaire/(?P<niveau>[0-9]+)/(?P<pk>[0-9]+)/?$", TerritorialStructuresView.as_view()),
    re_path(r"^api/structures/annuaire-sanitaire/?$", TerritorialStructuresView.as_view()),
    re_path(r"^api/structures/(?P<kind>contexte|references|entreprises)/?$", StructuresReadView.as_view()),
    re_path(r"^api/structures/annuaire/(?P<pk>[0-9]+)/(?P<kind>offres|professionnels)/?$", StructuresReadView.as_view()),
    re_path(r"^api/structures/annuaire/(?P<pk>[0-9]+)/logo/?$", StructureLogoView.as_view()),
    re_path(r"^api/structures/profils/(?P<pk>[0-9]+)/logo/?$", StructureLogoView.as_view(), {'private': True}),
    re_path(r"^api/structures/annuaire(?:/(?P<pk>[0-9]+))?/?$", StructuresReadView.as_view(), {'kind': 'annuaire'}),
    re_path(r"^api/structures/profils/?$", StructuresReadView.as_view(), {'kind': 'profils'}),
    re_path(r"^api/structures/profils/(?P<pk>[0-9]+)/?$", StructureProfileView.as_view()),
    re_path(r"^api/produits/references/?$", ProductReferencesView.as_view()),
    re_path(r"^api/produits/offres(?:/(?P<pk>[0-9]+))?/?$", ProductOffersView.as_view()),
    re_path(r"^api/professionnels/contexte/?$", ProfessionalContextView.as_view()),
    re_path(r"^api/professionnels/profils/modele-excel/?$", ProfessionalTemplateView.as_view()),
    re_path(r"^api/professionnels/profils/import-excel/?$", ProfessionalExcelPreviewView.as_view()),
    re_path(r"^api/professionnels/profils/batch/?$", ProfessionalBatchView.as_view()),
    re_path(r"^api/professionnels/entreprises/?$", ProfessionalEntitiesView.as_view()),
    re_path(r"^api/professionnels/references/?$", ProfessionalReferencesView.as_view()),
    re_path(r"^api/professionnels/annuaire/(?P<pk>[0-9]+)/photo/?$", ProfessionalPublicPhotoView.as_view()),
    re_path(r"^api/professionnels/profils/(?P<pk>[0-9]+)/photo/?$", ProfessionalManagementPhotoView.as_view()),
    re_path(r"^api/professionnels/annuaire(?:/(?P<pk>[0-9]+))?/?$", ProfessionalDirectoryView.as_view()),
    re_path(r"^api/professionnels/profils/actions/?$", ProfileActionView.as_view()),
    re_path(r"^api/professionnels/profils/(?P<pk>[0-9]+)/actions/?$", ProfileActionView.as_view()),
    re_path(r"^api/professionnels/profils(?:/(?P<pk>[0-9]+))?/?$", ProfessionalProfilesView.as_view()),
    re_path(r"^api/caisse/contexte/?$", CashContextView.as_view()),
    re_path(r"^api/caisse/entreprises/?$", CashEntitiesView.as_view()),
    re_path(r"^api/caisse/references/?$", CashReferencesView.as_view()),
    re_path(r"^api/caisse/synthese/?$", CashSynthesisView.as_view()),
    re_path(r"^api/caisse/registres/(?P<kind>caisses|ecritures|clotures)(?:/export)?\.(?P<file_format>xlsx|csv)/?$", CashExportView.as_view()),
    re_path(r"^api/caisse/registres/(?P<kind>caisses|ecritures|clotures)/?$", CashRegisterView.as_view()),
    re_path(r"^api/caisse/clotures/preparation/?$", ClosurePreparationView.as_view()),
    re_path(r"^api/caisse/caisses/modele-excel/?$", CashExcelTemplateView.as_view()),
    re_path(r"^api/caisse/caisses/import-excel/?$", CashExcelPreviewView.as_view()),
    re_path(r"^api/caisse/(?P<kind>ecritures|clotures)/modele-excel/?$", CashExcelTemplateView.as_view()),
    re_path(r"^api/caisse/(?P<kind>ecritures|clotures)/import-excel/?$", CashExcelPreviewView.as_view()),
    re_path(r"^api/caisse/caisses(?:/(?P<pk>[0-9]+))?/?$", CashAccountsView.as_view()),
    re_path(r"^api/caisse/parametres-validation/?$", CashValidationSettingsView.as_view()),
    re_path(r"^api/caisse/ecritures/validation/apercu/?$", CashValidationPreviewView.as_view()),
    re_path(r"^api/caisse/ecritures/validation/?$", CashValidationSelectionView.as_view()),
    re_path(r"^api/caisse/ecritures/(?P<pk>[0-9]+)/(?P<action>valider|contrepasser)/?$", CashEntryActionView.as_view()),
    re_path(r"^api/caisse/ecritures(?:/(?P<pk>[0-9]+))?/?$", CashEntriesView.as_view()),
    re_path(r"^api/caisse/clotures(?:/(?P<pk>[0-9]+))?/?$", CashClosuresView.as_view()),
    re_path(r"^api/parametres/contexte/?$", EntitySettingsContextView.as_view()),
    re_path(r"^api/parametres/presentation/?$", PresentationModulesView.as_view()),
    re_path(r"^api/parametres/(?P<module_key>logistique|caisse|support|discussions)/presentation/?$", ModulePresentationSettingsView.as_view()),
    re_path(r"^api/(?P<module_key>logistique|caisse|support|discussions)/presentation/?$", ModulePresentationView.as_view()),
    re_path(r"^api/guide/contexte/?$", GuideContextView.as_view()),
    re_path(r"^api/guide/entreprises/?$", GuideEntitiesView.as_view()),
    re_path(r"^api/guide/articles/(?P<module_key>[a-z][a-z0-9-]*)/(?P<article_id>[a-z][a-z0-9-]*)/?$", GuideArticleView.as_view()),
    re_path(r"^api/parametres/entreprises/?$", EntitySettingsChoicesView.as_view()),
    re_path(r"^api/parametres/profil/?$", EntitySettingsProfileView.as_view()),
    re_path(r"^api/parametres/entreprises/(?P<pk>[0-9]+)/logo/?$", EntitySettingsLogoView.as_view()),
    re_path(r"^api/support/contexte/?$", SupportContextView.as_view()),
    re_path(r"^api/support/entreprises/?$", SupportEntitiesView.as_view()),
    re_path(r"^api/support/tableau-de-bord/?$", SupportDashboardView.as_view()),
    re_path(r"^api/support/kanban/?$", SupportKanbanView.as_view()),
    re_path(r"^api/support/tickets/export\.xlsx$", SupportExcelView.as_view()),
    re_path(r"^api/support/tickets/export\.csv$", SupportCSVView.as_view()),
    re_path(r"^api/support/tickets/modele\.xlsx/?$", SupportTemplateView.as_view()),
    re_path(r"^api/support/tickets/import-excel/?$", SupportExcelPreviewView.as_view()),
    re_path(r"^api/support/tickets/batch/?$", SupportBatchView.as_view()),
    re_path(r"^api/support/tickets/(?P<pk>[0-9]+)/actions/?$", SupportActionsView.as_view()),
    re_path(r"^api/support/tickets/(?P<pk>[0-9]+)/commentaires/?$", SupportCommentsView.as_view()),
    re_path(r"^api/support/tickets/(?P<pk>[0-9]+)/documents/(?P<piece_id>[0-9]+)/download/?$", SupportDocumentDownloadView.as_view()),
    re_path(r"^api/support/tickets/(?P<pk>[0-9]+)/documents/?$", SupportDocumentsView.as_view()),
    re_path(r"^api/support/tickets/(?P<pk>[0-9]+)/?$", SupportTicketsView.as_view()),
    re_path(r"^api/support/tickets/?$", SupportTicketsView.as_view()),
    re_path(r"^api/support/", include("apps.support.process_urls")),
    re_path(r"^api/geolocalisation/territoires/registres/(?P<kind>[a-z0-9-]+)/panier/?$",TerritorialBatchView.as_view()),
    re_path(r"^api/geolocalisation/territoires/registres/(?P<kind>[a-z0-9-]+)/modele-excel/?$",TerritorialExcelTemplateView.as_view()),
    re_path(r"^api/geolocalisation/territoires/registres/(?P<kind>[a-z0-9-]+)/import-excel/?$",TerritorialExcelImportView.as_view()),
    re_path(r"^api/geolocalisation/territoires/registres/(?P<kind>[a-z0-9-]+)/publication/?$",TerritorialPublicationView.as_view()),
    re_path(r"^api/geolocalisation/territoires/synthese/?$",TerritorialOverviewView.as_view()),
    re_path(r"^api/geolocalisation/territoires/references/(?P<kind>[a-z0-9-]+)/?$",TerritorialReferencesView.as_view()),
    re_path(r"^api/geolocalisation/territoires/registres/(?P<kind>[a-z0-9-]+)/export\.xlsx$",TerritorialExcelView.as_view()),
    re_path(r"^api/geolocalisation/territoires/registres/(?P<kind>[a-z0-9-]+)/export\.csv$",TerritorialCSVView.as_view()),
    re_path(r"^api/geolocalisation/territoires/registres/(?P<kind>[a-z0-9-]+)/(?P<pk>[0-9]+)/?$",TerritorialRegisterView.as_view()),
    re_path(r"^api/geolocalisation/territoires/registres/(?P<kind>[a-z0-9-]+)/?$",TerritorialRegisterView.as_view()),
    re_path(r"^api/systeme/administration/entreprises/?$", AdminEntitiesView.as_view()),
    re_path(r"^api/systeme/administration/references/(?P<kind>utilisateurs|roles|correspondances|parametres|entites|licences|connexions)/?$", AdminReferencesView.as_view()),
    re_path(r"^api/systeme/administration/saisie-multiple/(?P<kind>utilisateurs|roles|correspondances|parametres)/?$", AdminBatchView.as_view()),
    re_path(r"^api/systeme/administration/saisie-multiple/(?P<kind>utilisateurs|roles|correspondances|parametres)/modele-excel/?$", AdminExcelTemplateView.as_view()),
    re_path(r"^api/systeme/administration/saisie-multiple/(?P<kind>utilisateurs|roles|correspondances|parametres)/import-excel/?$", AdminExcelPreviewView.as_view()),
    re_path(r"^api/logistique/saisie-multiple/articles/apercu-excel/?$", ArticleExcelPreviewView.as_view()),
    re_path(r"^api/logistique/saisie-multiple/(?P<kind>tiers|immobilisations)/modele-excel/?$", LogisticsExcelTemplateView.as_view()),
    re_path(r"^api/logistique/saisie-multiple/(?P<kind>tiers|immobilisations)/import-excel/?$", LogisticsExcelPreviewView.as_view()),
    re_path(r"^api/logistique/saisie-multiple/(?P<kind>tiers|articles|immobilisations)/?$", LogisticsBatchView.as_view()),
    re_path(r"^api/referentiel/saisie-multiple/(?P<kind>categories|valeurs)/?$", ReferenceBatchView.as_view()),
    re_path(r"^api/referentiel/saisie-multiple/(?P<kind>categories|valeurs)/modele-excel/?$", ReferenceExcelTemplateView.as_view()),
    re_path(r"^api/referentiel/saisie-multiple/(?P<kind>categories|valeurs)/import-excel/?$", ReferenceExcelImportView.as_view()),
    re_path(r"^api/referentiel/tableaux/export\.xlsx/?$", ReferenceTablesExcelView.as_view()),
    re_path(r"^api/referentiel/tableaux/export\.csv/?$", ReferenceTablesCSVView.as_view()),
    re_path(r"^api/referentiel/tableaux/(?P<interface_key>[a-z]+[.][a-z-]+)/?$", ReferenceTablesView.as_view()),
    re_path(r"^api/referentiel/tableaux/?$", ReferenceTablesView.as_view()),
    re_path(r"^api/referentiel/champs-references/valeurs/?$", FieldReferenceOptionsView.as_view()),
    re_path(r"^api/referentiel/champs-references/export\.(?P<file_format>xlsx|csv)/?$", FieldReferenceExportView.as_view()),
    re_path(r"^api/referentiel/champs-references/(?P<pk>[0-9]+)/retablir/?$", FieldReferenceRestoreView.as_view()),
    re_path(r"^api/referentiel/champs-references/(?P<pk>[0-9]+)/valeurs/?$", FieldReferenceOptionsView.as_view()),
    re_path(r"^api/referentiel/champs-references/(?P<pk>[0-9]+)/historique/?$", FieldReferenceHistoryView.as_view()),
    re_path(r"^api/referentiel/champs-references(?:/(?P<pk>[0-9]+))?/?$", FieldReferencesView.as_view()),
    re_path(r"^api/systeme/personnel/references/?$", PersonnelReferencesView.as_view()),
    re_path(r"^api/logistique/immobilisations/references/?$", ImmobilisationReferencesView.as_view()),
    re_path(r"^api/logistique/immobilisations/export\.(?P<file_format>xlsx|csv)/?$", ImmobilisationExportView.as_view()),
    re_path(r"^api/logistique/immobilisations/(?P<pk>[0-9]+)/cycle-vie/?$", ImmobilisationCycleView.as_view()),
    re_path(r"^api/logistique/immobilisations/(?P<pk>[0-9]+)/valorisation/?$", ImmobilisationValuationView.as_view()),
    re_path(r"^api/logistique/immobilisations/(?P<pk>[0-9]+)/historique/?$", ImmobilisationHistoryView.as_view()),
    re_path(r"^api/logistique/immobilisations/(?P<pk>[0-9]+)/?$", ImmobilisationsView.as_view()),
    re_path(r"^api/logistique/immobilisations/?$", ImmobilisationsView.as_view()),
    re_path(r"^api/tableaux/(?P<interface_key>[a-z]+[.][a-z-]+)/preferences/?$", TablePreferencesView.as_view()),
    re_path(r"^api/referentiel/exports/(?P<kind>categories|valeurs)\.csv/?$", ReferenceCSVView.as_view()),
    re_path(r"^api/systeme/administration/registres/(?P<kind>utilisateurs|entites|roles|audit|correspondances|localisations|licences|connexions|profils|parametres|audit-parametres)/export\.csv/?$", AdminCSVView.as_view()),
    re_path(r"^api/logistique/registre/(?P<kind>articles|lots|commandes|lignes|mouvements|factures|reglements|immobilisations)/export\.csv/?$", RegisterCSVView.as_view()),
    re_path(r"^api/systeme/administration/synthese/?$", AdminOverviewView.as_view()),
    re_path(r"^api/systeme/administration/registres/(?P<kind>utilisateurs|entites|roles|audit|correspondances|localisations|licences|connexions|profils|parametres|audit-parametres)/export\.xlsx/?$", AdminExcelView.as_view()),
    re_path(r"^api/systeme/administration/registres/(?P<kind>utilisateurs|entites|roles|audit|correspondances|localisations|licences|connexions|profils|parametres|audit-parametres)(?:/(?P<pk>[0-9]+))?/?$", AdminRegisterView.as_view()),
    re_path(r"^api/referentiel/exports/(?P<kind>categories|valeurs)\.xlsx/?$", ReferenceExcelView.as_view()),
    re_path(r"^api/logistique/articles/(?P<pk>[0-9]+)/valorisation/export\.xlsx/?$", ArticleValuationExcelView.as_view()),
    re_path(r"^api/logistique/articles/(?P<pk>[0-9]+)/valorisation/?$", ArticleValuationView.as_view()),
    re_path(r"^api/logistique/entreprise/identite/?$", EntityDocumentIdentityView.as_view()),
    re_path(r"^api/systeme/entites/identite-defaut/?$", EntityIdentityDefaultsView.as_view()),
    re_path(r"^api/systeme/entites/(?P<pk>[0-9]+)/logo/?$", EntityLogoView.as_view()),
    re_path(r"^api/logistique/peremption/politique/?$", ExpiryPolicyView.as_view()),
    re_path(r"^api/logistique/lots/(?P<pk>[0-9]+)/mouvements/export\.xlsx/?$", LotMovementsExcelView.as_view()),
    re_path(r"^api/logistique/lots/(?P<pk>[0-9]+)/mouvements/?$", LotMovementsView.as_view()),
    re_path(r"^api/logistique/lots/(?P<pk>[0-9]+)/?$", LotDetailView.as_view()),
    re_path(r"^api/logistique/documents/(?P<kind>bon|facture|reglement|avoir|immobilisation)/(?P<pk>[0-9]+)/(?P<document_type>entree|sortie|livraison|commande|facture|recu|avoir|fiche)\.pdf/?$", DocumentPdfView.as_view()),
    re_path(r"^api/logistique/documents/(?P<kind>bon|facture|reglement|avoir|immobilisation)/(?P<pk>[0-9]+)/pieces(?:/(?P<piece_id>[0-9]+))?/?$", AttachmentsView.as_view()),
    re_path(r"^api/logistique/commandes/(?P<pk>[0-9]+)/avoirs/?$", OrderCreditsView.as_view()),
    re_path(r"^api/logistique/avoirs/(?P<pk>[0-9]+)(?:/(?P<operation>affectation|remboursement))?/?$", CreditView.as_view()),
    re_path(r"^api/logistique/(?P<kind>depots|stocks-depots|transferts|inventaires|lignes-inventaires)/export\.(?P<file_format>xlsx|csv)/?$", DepotRegisterExportView.as_view()),
    re_path(r"^api/logistique/lignes-inventaires/?$", InventoryLinesView.as_view()),
    re_path(r"^api/logistique/depots/(?P<pk>[0-9]+)/?$", DepotsView.as_view()),
    re_path(r"^api/logistique/depots/?$", DepotsView.as_view()),
    re_path(r"^api/logistique/stocks-depots/?$", DepotStocksView.as_view()),
    re_path(r"^api/logistique/transferts/(?P<pk>[0-9]+)/(?P<action>valider|expedier|receptionner|annuler|traiter-ecart)/?$", TransfersView.as_view()),
    re_path(r"^api/logistique/transferts/(?P<pk>[0-9]+)/?$", TransfersView.as_view()),
    re_path(r"^api/logistique/transferts/?$", TransfersView.as_view()),
    re_path(r"^api/logistique/inventaires/unites/?$", UnitPrecisionView.as_view()),
    re_path(r"^api/logistique/inventaires/catalogue/?$", InventoriesView.as_view(), {"action":"catalogue"}),
    re_path(r"^api/logistique/inventaires/(?P<pk>[0-9]+)/annuler/?$", InventoriesView.as_view(), {"action":"annuler"}),
    re_path(r"^api/logistique/inventaires/(?P<pk>[0-9]+)/valider/?$", InventoriesView.as_view(), {"action":"valider"}),
    re_path(r"^api/logistique/inventaires/(?P<pk>[0-9]+)/?$", InventoriesView.as_view()),
    re_path(r"^api/logistique/inventaires/?$", InventoriesView.as_view()),
    re_path(r"^api/logistique/articles/(?P<pk>[0-9]+)/lots/fefo/?$", LotFefoView.as_view()),
    re_path(r"^api/logistique/destinations/?$",DestinationsView.as_view()),
    re_path(r"^api/logistique/entreprises/?$",EntreprisesView.as_view()),
    re_path(r"^api/logistique/tiers/references/?$",TiersReferencesView.as_view()),
    re_path(r"^api/logistique/tiers(?:/(?P<pk>[0-9]+))?/?$",TiersView.as_view()),
    re_path(r"^api/logistique/consultations/tiers/(?P<pk>[0-9]+)(?:/(?P<section>identite|bons|factures|reglements))?/?$",TiersConsultationView.as_view()),
    re_path(r"^api/logistique/reglements/groupes/?$", PaymentBatchView.as_view()),
    re_path(r"^api/logistique/reglements/preparation/?$", PaymentPreparationView.as_view()),
    re_path(r"^api/logistique/commandes/(?P<pk>[0-9]+)/retours/?$", StockReturnsView.as_view()),
    re_path(r"^api/logistique/commandes/(?P<pk>[0-9]+)/facture/?$", InvoiceView.as_view()),
    re_path(r"^api/logistique/commandes/(?P<pk>[0-9]+)/composition/?$", OrderCompositionView.as_view()),
    re_path(r"^api/logistique/commandes/composees/?$", OrderComposerView.as_view()),
    re_path(r"^api/logistique/articles/publication/?$", ArticlePublicationView.as_view()),
    re_path(r"^api/logistique/articles/(?P<pk>[0-9]+)/receptions/?$", ArticleReceiptView.as_view()),
    re_path(r"^api/logistique/articles/(?P<pk>[0-9]+)/photo/?$", ArticlePhotoView.as_view()),
    re_path(r"^api/public/articles/(?P<pk>[0-9]+)/photo/?$", PublicArticlePhotoView.as_view(), {"kind":"articles"}),
    re_path(r"^api/workspace/catalogue/?$", WorkspaceCatalogueView.as_view()),
    re_path(r"^api/workspace/organisations/?$", OrganisationApplicationsView.as_view()),
    re_path(r"^api/workspace/licences/?$", LicenceApplicationsView.as_view()),
    re_path(r"^api/workspace/licences/(?P<pk>[0-9]+)/modules/?$", LicenceModulesView.as_view()),
    re_path(r"^api/workspace/roles/?$", RoleApplicationsView.as_view()),
    re_path(r"^api/workspace/droits-utilisateurs(?:/(?P<pk>[0-9]+))?/?$", UserApplicationsView.as_view()),
    re_path(r"^api/workspace/roles/(?P<pk>[0-9]+)/?$", RoleApplicationsView.as_view()),
    re_path(r"^api/logistique/dossiers-suivi/apercu/?$", FolderPreviewView.as_view()),
    re_path(r"^api/logistique/dossiers-suivi/categories/?$", FolderCategoriesView.as_view()),
    re_path(r"^api/logistique/dossiers-suivi/(?P<key>[a-z0-9-]+)/export\.xlsx/?$", FolderExcelView.as_view()),
    re_path(r"^api/logistique/dossiers-suivi/(?P<key>[a-z0-9-]+)/membres/?$", FolderMembersView.as_view()),
    re_path(r"^api/logistique/dossiers-suivi(?:/(?P<key>[a-z0-9-]+))?/?$", FoldersView.as_view()),
    re_path(r"^api/logistique/registre/(?P<kind>articles|lots|commandes|lignes|mouvements|factures|reglements|immobilisations)/?$", RegisterReadView.as_view()),
    re_path(r"^api/logistique/registre/(?P<kind>articles|lots|commandes|lignes|mouvements|factures|reglements|immobilisations)/export\.xlsx/?$", RegisterExcelView.as_view()),
    re_path(r"^api/logistique/synthese/?$", OverviewReadView.as_view()),
    re_path(r"^api/logistique/indicateurs/(?P<key>[A-Za-z]+)/export\.xlsx/?$", IndicatorExcelView.as_view()),
    re_path(r"^api/logistique/indicateurs/(?P<key>[A-Za-z]+)/?$", IndicatorReadView.as_view()),
    re_path(r"^api/logistique/consultations/(?P<kind>produit|commande)/(?P<pk>[0-9]+)(?:/(?P<section>[a-z]+))?/?$", ConsultationReadView.as_view()),
    re_path(r"^api/workspace/modules/?$", WorkspaceModulesView.as_view()),
    re_path(r"^api/recherches(?:/(?P<pk>[0-9]+))?/?$", RecherchesView.as_view()),
    re_path(
        r"^api/systeme/admin-ui-settings/audit/?$",
        ViewsView.as_view(),
        {"schema": "systeme", "name": "V_Fk_Correspondance_Audit"},
    ),
    re_path(r"^health/?$", HealthView.as_view()),
    re_path(r"^SauverNdeko/auth/password-reset/?$", PasswordResetView.as_view()),
    re_path(r"^SauverNdeko/auth/password-reset/check/?$", PasswordResetCheckView.as_view()),
    re_path(r"^SauverNdeko/auth/password-reset/confirm/?$", PasswordResetConfirmView.as_view()),
    re_path(r"^SauverNdeko/auth/login/?$", LoginView.as_view()),
    re_path(r"^SauverNdeko/auth/register/?$", RegisterView.as_view()),
    re_path(r"^SauverNdeko/auth/refresh/?$", RefreshView.as_view()),
    re_path(r"^SauverNdeko/auth/me/?$", MeView.as_view()),
    re_path(r"^SauverNdeko/auth/me/password/?$", PasswordChangeView.as_view()),
    re_path(r"^SauverNdeko/auth/me/photo/?$", ProfilePhotoView.as_view()),
    re_path(r"^SauverNdeko/auth/verify/?$", VerifyView.as_view()),
    re_path(r"^SauverNdeko/auth/logout/?$", LogoutView.as_view()),
    re_path(
        r"^api/public/(?P<kind>stats|articles|pharmacies|experts|chat/context)/?$",
        PublicView.as_view(),
    ),
    re_path(r"^api/notifications/?$", NotificationsView.as_view()),
    re_path(r"^api/notifications/(?P<pk>[0-9]+)/read/?$", NotificationReadView.as_view()),
    re_path(r"^api/discussions/start/?$", StartView.as_view()),
    re_path(r"^api/discussions/demandes/contexte-source/?$", DemandeSourceView.as_view()),
    re_path(r"^api/discussions/demandes/routage/?$", DemandeRoutingView.as_view()),
    re_path(r"^api/discussions/demandes/?$", DemandesView.as_view()),
    re_path(r"^api/discussions/demandes/(?P<pk>[0-9]+)/transition/?$", DemandeTransitionView.as_view()),
    re_path(r"^api/discussions/demandes/(?P<pk>[0-9]+)/discussion/?$", DemandeDiscussionView.as_view()),
    re_path(r"^api/discussions/demandes/(?P<pk>[0-9]+)/?$", DemandeDetailView.as_view()),
    re_path(r"^api/discussions/contacts/?$", ContactsView.as_view()),
    re_path(r"^api/discussions/annonces/contexte/?$", AnnouncementContextView.as_view()),
    re_path(r"^api/discussions/annonces/recues/?$", ReceivedAnnouncementsView.as_view()),
    re_path(r"^api/discussions/annonces/?$", AnnouncementsView.as_view()),
    re_path(r"^api/discussions/?$", DiscussionsView.as_view()),
    re_path(r"^api/discussions/(?P<pk>[0-9]+)/messages/?$", MessagesView.as_view()),
    re_path(r"^api/discussions/(?P<pk>[0-9]+)/lecture/?$", DiscussionReadView.as_view()),
    re_path(r"^api/views/?$", ViewsView.as_view()),
    re_path(
        r"^api/views/(?P<schema>[a-z_]+)/(?P<name>[A-Za-z0-9_]+)/?$",
        ViewsView.as_view(),
    ),
    re_path(r"^api/models/?$", ModelListView.as_view()),
    re_path(
        r"^api/models/(?P<model_name>[A-Za-z0-9_]+)/(?P<pk>[0-9]+)/?$",
        ModuleView.as_view(),
    ),
    re_path(r"^api/models/(?P<model_name>[A-Za-z0-9_]+)/?$", ModuleView.as_view()),
    re_path(
        r"^api/geolocalisation/hierarchie/children/(?P<level>[0-4])/(?P<pk>[0-9]+)/?$",
        HierarchyView.as_view(),
    ),
    re_path(r"^api/geolocalisation/hierarchie/?$", HierarchyView.as_view()),
    re_path(r"^api/logistique/references/?$", ReferencesView.as_view()),
    re_path(r"^api/logistique/dashboard/?$", DashboardView.as_view()),
    re_path(
        r"^api/logistique/commande-details/search/?$",
        DetailView.as_view(),
        {"search": True},
    ),
    re_path(
        r"^api/logistique/commande-details/(?P<commande>[0-9]+)/(?P<article>[0-9]+)/?$",
        DetailView.as_view(),
    ),
    re_path(r"^api/logistique/commande-details/?$", DetailView.as_view()),
    re_path(
        r"^api/logistique/commandes/(?P<commande>[0-9]+)/details/(?P<article>[0-9]+)/?$",
        DetailView.as_view(),
    ),
    re_path(
        r"^api/logistique/commandes/(?P<commande>[0-9]+)/details/?$",
        DetailView.as_view(),
    ),
    re_path(
        r"^api/logistique/stock/(?P<kind>audit|alertes|consommation|couverture)/?$",
        StockView.as_view(),
    ),
    re_path(r"^api/logistique/stock/?$", StockView.as_view()),
    re_path(
        r"^api/logistique/commandes-sans-details/?$",
        StockView.as_view(),
        {"kind": "sans-details"},
    ),
    re_path(
        r"^api/logistique/reglements/entries/?$",
        StockView.as_view(),
        {"kind": "entries"},
    ),
    re_path(
        r"^api/referentiel/generiques/categorie/(?P<category>[0-9]+)/?$",
        ModuleView.as_view(),
        {"module": "referentiel/generiques"},
    ),
    re_path(r"^api/systeme/messagerie/?$", MailSettingsView.as_view()),
    re_path(r"^api/systeme/messagerie/test/?$", MailConnectionTestView.as_view()),
    re_path(r"^api/systeme/admin-ui-settings/?$", UISettingsView.as_view()),
    re_path(r"^api/admin-ui-settings/?$", UISettingsView.as_view()),
    re_path(
        r"^api/admin-ui-settings/audit/?$",
        ViewsView.as_view(),
        {"schema": "systeme", "name": "V_Fk_Correspondance_Audit"},
    ),
]
if settings.DJANGO_ADMIN_ENABLED:
    urlpatterns.append(re_path(r"^django-admin/", admin.site.urls))

for module in MODULES:
    if module != "systeme/admin-ui-settings":
        urlpatterns.append(
            re_path(
                r"^api/" + module + r"/?$", ModuleView.as_view(), {"module": module}
            )
        )
    urlpatterns.append(
        re_path(
            r"^api/" + module + r"/search/?$",
            ModuleView.as_view(),
            {"module": module, "search": True},
        )
    )
    urlpatterns.append(
        re_path(
            r"^api/" + module + r"/(?P<pk>[0-9]+)/?$",
            ModuleView.as_view(),
            {"module": module},
        )
    )
for alias, module in {
    "utilisateurs": "systeme/utilisateurs",
    "entites": "systeme/entites",
    "licences": "systeme/licences",
    "articles": "logistique/articles",
    "commandes": "logistique/commandes",
}.items():
    urlpatterns.extend(
        [
            re_path(
                r"^api/" + alias + r"/?$", ModuleView.as_view(), {"module": module}
            ),
            re_path(
                r"^api/" + alias + r"/(?P<pk>[0-9]+)/?$",
                ModuleView.as_view(),
                {"module": module},
            ),
        ]
    )
