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
from apps.catalogue.views import PublicView
from apps.communication.views import DiscussionsView, StartView, MessagesView
from apps.logistique.views import DetailView, StockView, DashboardView, ReferencesView

urlpatterns = [
    re_path(r"^django-admin/", admin.site.urls),
    re_path(r"^api/recherches(?:/(?P<pk>[0-9]+))?/?$", RecherchesView.as_view()),
    re_path(
        r"^api/systeme/admin-ui-settings/audit/?$",
        ViewsView.as_view(),
        {"schema": "systeme", "name": "V_Fk_Correspondance_Audit"},
    ),
    re_path(r"^health/?$", HealthView.as_view()),
    re_path(r"^SauverNdeko/auth/login/?$", LoginView.as_view()),
    re_path(r"^SauverNdeko/auth/register/?$", RegisterView.as_view()),
    re_path(r"^SauverNdeko/auth/refresh/?$", RefreshView.as_view()),
    re_path(r"^SauverNdeko/auth/me/?$", MeView.as_view()),
    re_path(r"^SauverNdeko/auth/verify/?$", VerifyView.as_view()),
    re_path(r"^SauverNdeko/auth/logout/?$", LogoutView.as_view()),
    re_path(
        r"^api/public/(?P<kind>stats|articles|pharmacies|experts|maladies|chat/context)/?$",
        PublicView.as_view(),
    ),
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
