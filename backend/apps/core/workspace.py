from rest_framework.permissions import IsAuthenticated
from rest_framework.views import APIView
from .responses import ok
from .module_access import WORKSPACE_MODULES, access_snapshot

def available_modules(actor):
    snapshot=access_snapshot(actor)
    return [{**{key:value for key,value in module.items() if key!="admin"},"base":snapshot["modules"][module["key"]]["base"]} for module in WORKSPACE_MODULES if snapshot["modules"][module["key"]]["canRead"]]

class WorkspaceModulesView(APIView):
    permission_classes=[IsAuthenticated]
    def get(self,request):return ok(available_modules(request.user))

class WorkspaceCatalogueView(APIView):
    permission_classes=[IsAuthenticated]
    def get(self,request):
        snapshot=access_snapshot(request.user)
        return ok({"platformAdmin":snapshot["platformAdmin"],"entityId":snapshot["entityId"],"modules":[{**{key:value for key,value in module.items() if key!="admin"},**snapshot["modules"][module["key"]]} for module in WORKSPACE_MODULES]})
