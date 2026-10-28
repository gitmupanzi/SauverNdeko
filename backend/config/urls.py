from apps.core.table_preferences import TablePreferencesView
from apps.core.reference_exports import ReferenceCSVView
from apps.core.admin_portal import AdminCSVView
from apps.logistique.excel import RegisterCSVView
from apps.core.reference_exports import ReferenceExcelView
from apps.core.admin_portal import AdminOverviewView, AdminRegisterView, AdminExcelView
from apps.logistique.expiry import ExpiryPolicyView
from apps.logistique.entity_documents import EntityDocumentIdentityView
from apps.logistique.valuation import ArticleValuationView, ArticleValuationExcelView
from apps.logistique.lot_register import LotDetailView, LotMovementsView, LotMovementsExcelView
from apps.logistique.inventories import InventoriesView, UnitPrecisionView
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
from apps.logistique.receipts import ArticleReceiptView
from apps.accounts.photos import ProfilePhotoView
from apps.logistique.photos import ArticlePhotoView, PublicArticlePhotoView
from django.contrib import admin
from django.urls import re_path
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
from apps.core.workspace import WorkspaceModulesView, WorkspaceCatalogueView
from apps.core.application_licences import OrganisationApplicationsView, LicenceApplicationsView, LicenceModulesView, RoleApplicationsView
from apps.catalogue.views import PublicView
from apps.communication.views import DiscussionsView, StartView, MessagesView
from apps.communication.notifications import NotificationsView, NotificationReadView
from apps.logistique.views import DetailView, StockView, DashboardView, ReferencesView

from apps.logistique.excel import IndicatorExcelView, RegisterExcelView, FolderExcelView
from apps.logistique.followup_folders import FoldersView, FolderCategoriesView, FolderMembersView, FolderPreviewView
from apps.logistique.reads import RegisterReadView, OverviewReadView, IndicatorReadView, ConsultationReadView

urlpatterns = [
    re_path(r"^api/tableaux/(?P<interface_key>[a-z]+[.][a-z-]+)/preferences/?$", TablePreferencesView.as_view()),
    re_path(r"^api/referentiel/exports/(?P<kind>categories|valeurs)\.csv/?$", ReferenceCSVView.as_view()),
    re_path(r"^api/systeme/administration/registres/(?P<kind>utilisateurs|entites|roles|audit|correspondances|localisations|licences|connexions|profils|parametres|audit-parametres)/export\.csv/?$", AdminCSVView.as_view()),
    re_path(r"^api/logistique/registre/(?P<kind>articles|lots|commandes|lignes|mouvements|factures|reglements)/export\.csv/?$", RegisterCSVView.as_view()),
    re_path(r"^api/systeme/administration/synthese/?$", AdminOverviewView.as_view()),
    re_path(r"^api/systeme/administration/registres/(?P<kind>utilisateurs|entites|roles|audit|correspondances|localisations|licences|connexions|profils|parametres|audit-parametres)/export\.xlsx/?$", AdminExcelView.as_view()),
    re_path(r"^api/systeme/administration/registres/(?P<kind>utilisateurs|entites|roles|audit|correspondances|localisations|licences|connexions|profils|parametres|audit-parametres)(?:/(?P<pk>[0-9]+))?/?$", AdminRegisterView.as_view()),
    re_path(r"^api/referentiel/exports/(?P<kind>categories|valeurs)\.xlsx/?$", ReferenceExcelView.as_view()),
    re_path(r"^api/logistique/articles/(?P<pk>[0-9]+)/valorisation/export\.xlsx/?$", ArticleValuationExcelView.as_view()),
    re_path(r"^api/logistique/articles/(?P<pk>[0-9]+)/valorisation/?$", ArticleValuationView.as_view()),
    re_path(r"^api/logistique/entreprise/identite/?$", EntityDocumentIdentityView.as_view()),
    re_path(r"^api/logistique/peremption/politique/?$", ExpiryPolicyView.as_view()),
    re_path(r"^api/logistique/lots/(?P<pk>[0-9]+)/mouvements/export\.xlsx/?$", LotMovementsExcelView.as_view()),
    re_path(r"^api/logistique/lots/(?P<pk>[0-9]+)/mouvements/?$", LotMovementsView.as_view()),
    re_path(r"^api/logistique/lots/(?P<pk>[0-9]+)/?$", LotDetailView.as_view()),
    re_path(r"^api/logistique/documents/(?P<kind>bon|facture|reglement|avoir)/(?P<pk>[0-9]+)/(?P<document_type>entree|sortie|livraison|facture|recu|avoir)\.pdf/?$", DocumentPdfView.as_view()),
    re_path(r"^api/logistique/documents/(?P<kind>bon|facture|reglement|avoir)/(?P<pk>[0-9]+)/pieces(?:/(?P<piece_id>[0-9]+))?/?$", AttachmentsView.as_view()),
    re_path(r"^api/logistique/commandes/(?P<pk>[0-9]+)/avoirs/?$", OrderCreditsView.as_view()),
    re_path(r"^api/logistique/avoirs/(?P<pk>[0-9]+)(?:/(?P<operation>affectation|remboursement))?/?$", CreditView.as_view()),
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
    re_path(r"^api/logistique/articles/(?P<pk>[0-9]+)/receptions/?$", ArticleReceiptView.as_view()),
    re_path(r"^api/logistique/articles/(?P<pk>[0-9]+)/photo/?$", ArticlePhotoView.as_view()),
    re_path(r"^api/public/articles/(?P<pk>[0-9]+)/photo/?$", PublicArticlePhotoView.as_view(), {"kind":"articles"}),
    re_path(r"^api/workspace/catalogue/?$", WorkspaceCatalogueView.as_view()),
    re_path(r"^api/workspace/organisations/?$", OrganisationApplicationsView.as_view()),
    re_path(r"^api/workspace/licences/?$", LicenceApplicationsView.as_view()),
    re_path(r"^api/workspace/licences/(?P<pk>[0-9]+)/modules/?$", LicenceModulesView.as_view()),
    re_path(r"^api/workspace/roles/?$", RoleApplicationsView.as_view()),
    re_path(r"^api/workspace/roles/(?P<pk>[0-9]+)/?$", RoleApplicationsView.as_view()),
    re_path(r"^api/logistique/dossiers-suivi/apercu/?$", FolderPreviewView.as_view()),
    re_path(r"^api/logistique/dossiers-suivi/categories/?$", FolderCategoriesView.as_view()),
    re_path(r"^api/logistique/dossiers-suivi/(?P<key>[a-z0-9-]+)/export\.xlsx/?$", FolderExcelView.as_view()),
    re_path(r"^api/logistique/dossiers-suivi/(?P<key>[a-z0-9-]+)/membres/?$", FolderMembersView.as_view()),
    re_path(r"^api/logistique/dossiers-suivi(?:/(?P<key>[a-z0-9-]+))?/?$", FoldersView.as_view()),
    re_path(r"^api/logistique/registre/(?P<kind>articles|lots|commandes|lignes|mouvements|factures|reglements)/?$", RegisterReadView.as_view()),
    re_path(r"^api/logistique/registre/(?P<kind>articles|lots|commandes|lignes|mouvements|factures|reglements)/export\.xlsx/?$", RegisterExcelView.as_view()),
    re_path(r"^api/logistique/synthese/?$", OverviewReadView.as_view()),
    re_path(r"^api/logistique/indicateurs/(?P<key>[A-Za-z]+)/export\.xlsx/?$", IndicatorExcelView.as_view()),
    re_path(r"^api/logistique/indicateurs/(?P<key>[A-Za-z]+)/?$", IndicatorReadView.as_view()),
    re_path(r"^api/logistique/consultations/(?P<kind>produit|commande)/(?P<pk>[0-9]+)(?:/(?P<section>[a-z]+))?/?$", ConsultationReadView.as_view()),
    re_path(r"^api/workspace/modules/?$", WorkspaceModulesView.as_view()),
    re_path(r"^django-admin/", admin.site.urls),
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
        r"^api/public/(?P<kind>stats|articles|pharmacies|experts|maladies|chat/context)/?$",
        PublicView.as_view(),
    ),
    re_path(r"^api/notifications/?$", NotificationsView.as_view()),
    re_path(r"^api/notifications/(?P<pk>[0-9]+)/read/?$", NotificationReadView.as_view()),
    re_path(r"^api/discussions/start/?$", StartView.as_view()),
    re_path(r"^api/discussions/?$", DiscussionsView.as_view()),
    re_path(r"^api/discussions/(?P<pk>[0-9]+)/messages/?$", MessagesView.as_view()),
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
