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
    "parentModule": None, "showInWorkspace": True, "base": True, "platformOnly": False,
}
def reference_feature(actor):
    if not actor.admin:
        return []
    try:
        require_module(actor, "referentiels")
    except APIError as error:
        if error.status_code != 403:
            raise
        return []
    return [dict(REFERENCE_FEATURE)]


def workspace_cards(actor, *, catalogue=False):
    rights = access_snapshot(actor)["modules"]
    metadata = application_metadata()
    cards = []
    for module in WORKSPACE_MODULES:
        key = module["key"]
        classification = metadata.get(key)
        if classification is None:
            continue
        if classification["platformOnly"] and not actor.global_admin:
            continue
        if catalogue:
            if not (classification["showInWorkspace"] or classification["commercialisable"]):
                continue
            if not rights[key]["canRead"] and not classification["commercialisable"]:
                continue
        elif not (classification["showInWorkspace"] and rights[key]["canRead"]):
            continue
        cards.append({
            **{key: value for key, value in module.items() if key != "admin"},
            **classification, **rights[key],
        })
    references = reference_feature(actor)

    if catalogue:
        references = [{**item, "canRead": True, "available": True} for item in references]
    return cards + references


def available_modules(actor):
    return workspace_cards(actor)


class WorkspaceModulesView(APIView):
    permission_classes=[IsAuthenticated]
    def get(self,request):return ok(available_modules(request.user))

class WorkspaceCatalogueView(APIView):
    permission_classes=[IsAuthenticated]
    def get(self,request):
        snapshot=access_snapshot(request.user)
        return ok({"platformAdmin": snapshot["platformAdmin"], "entityId": snapshot["entityId"],
                   "modules": workspace_cards(request.user, catalogue=True)})
