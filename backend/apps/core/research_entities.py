"""Entreprises proposées dans le sélecteur de Data Science."""
from rest_framework.views import APIView

from . import db
from .module_access import require_module
from .permissions import HasModuleAccess
from .responses import APIError, ok


class ResearchEntitiesView(APIView):
    permission_classes = [HasModuleAccess]

    def get(self, request):
        actor = request.user
        require_module(actor, "data-science")
        if request.query_params:
            raise APIError("Ce registre ne comporte pas de filtre.")
        condition = "TRUE" if actor.global_admin else '"IdEntite" = %s'
        rows = db.query(
            f'''SELECT "IdEntite" AS id, "NomEntite" AS label, "ValideEntite" AS active
                FROM systeme."T_Entite"
                WHERE {condition} ORDER BY lower("NomEntite"), "IdEntite"''',
            [] if actor.global_admin else [actor.organisation],
        )
        return ok(rows)
