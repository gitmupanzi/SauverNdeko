from rest_framework.permissions import IsAuthenticated
from rest_framework.views import APIView
from .responses import ok

WORKSPACE_MODULES = (
    {"key": "catalogue", "label": "Catalogue", "description": "Produits, structures et informations de santé.", "path": "/catalogue", "icon": "grid", "tone": "blue"},
    {"key": "produits", "label": "Produits", "description": "Rechercher et consulter les produits disponibles.", "path": "/produits", "icon": "capsule", "tone": "teal"},
    {"key": "structures", "label": "Structures", "description": "Pharmacies, dépôts et établissements.", "path": "/pharmacies", "icon": "hospital", "tone": "coral"},
    {"key": "professionnels", "label": "Professionnels", "description": "Consulter les profils des professionnels.", "path": "/experts", "icon": "people", "tone": "purple"},
    {"key": "sante", "label": "Informations santé", "description": "Consulter les informations par maladie.", "path": "/maladies", "icon": "heart-pulse", "tone": "rose"},
    {"key": "discussions", "label": "Discussions", "description": "Retrouver vos échanges et messages.", "path": "/discussions", "icon": "chat-dots", "tone": "sky"},
    {"key": "logistique", "label": "Logistique", "description": "Articles, commandes, stock et règlements.", "path": "/logistique", "icon": "box-seam", "tone": "amber", "admin": True},
    {"key": "administration", "label": "Administration", "description": "Utilisateurs, organisations et paramètres.", "path": "/admin", "icon": "sliders", "tone": "slate", "admin": True},
)


def available_modules(actor):
    return [
        {key: value for key, value in module.items() if key != "admin"}
        for module in WORKSPACE_MODULES
        if not module.get("admin") or actor.admin
    ]


class WorkspaceModulesView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        return ok(available_modules(request.user))
