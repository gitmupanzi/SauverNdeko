from rest_framework.permissions import IsAuthenticated
from rest_framework.views import APIView
from .responses import APIError, ok
from .module_access import WORKSPACE_MODULES, access_snapshot, application_metadata, require_module

# Le référentiel n'est pas une licence autonome. Le lanceur conserve la barrière
# ERP administrateur de ses API, puis leur contrôle require_module existant.
REFERENCE_FEATURE = {
    "key": "referentiels", "label": "Référentiels",
    "description": "Catégories, valeurs et référencement des champs.",
    "path": "/referentiels", "icon": "tags", "tone": "slate",
    "type": "FONCTIONNALITE", "commercialisable": False,
    "parentModule": None, "showInWorkspace": True, "base": True,
}

def available_modules(actor):
    snapshot=access_snapshot(actor)
    metadata=application_metadata()
    modules = [
        {**{key:value for key,value in module.items() if key!="admin"},
         **metadata[module['key']], "base":snapshot["modules"][module["key"]]["base"]}
        for module in WORKSPACE_MODULES
        if snapshot["modules"][module["key"]]["canRead"]
        and metadata[module["key"]]["showInWorkspace"]
    ]
    if actor.admin:
        try:
            require_module(actor, "referentiels")
        except APIError as error:
            if error.status_code != 403:
                raise
        else:
            modules.append(dict(REFERENCE_FEATURE))
    return modules

class WorkspaceModulesView(APIView):
    permission_classes=[IsAuthenticated]
    def get(self,request):return ok(available_modules(request.user))

class WorkspaceCatalogueView(APIView):
    permission_classes=[IsAuthenticated]
    def get(self,request):
        snapshot=access_snapshot(request.user)
        metadata=application_metadata()
        return ok({"platformAdmin":snapshot["platformAdmin"],"entityId":snapshot["entityId"],"modules":[{**{key:value for key,value in module.items() if key!="admin"},**metadata[module['key']],**snapshot["modules"][module["key"]]} for module in WORKSPACE_MODULES]})
