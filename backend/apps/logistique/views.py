from rest_framework.views import APIView
from apps.core.permissions import IsERPAdmin
from apps.core.registry import model, view
from apps.core.repository import listing, get_record, positive, clean
from apps.core.responses import ok, APIError
from .services import mutate_line, dashboard, references


class DetailView(APIView):
    permission_classes = [IsERPAdmin]

    def get(self, request, commande=None, article=None, search=False):
        if article is not None:
            from .document_rules import editable_record, line_usage
            record=editable_record(model("T_CommandeDetail"),view("logistique","V_CommandeDetail"),request.user,{"ID_CmdFk":positive(commande),"ID_ArticleFk":positive(article)})
            parent=get_record(model("T_Commande"),request.user,{"ID_Commande":positive(commande)})
            return ok(clean(record),meta=line_usage(record,parent))
        params = request.query_params.dict()
        if commande:
            params["commande"] = commande
        if search and not params.get("q"):
            raise APIError("Recherche requise.")
        rows, meta = listing(
            view("logistique", "V_CommandeDetail"), request.user, params
        )
        return ok(rows, meta=meta)

    def post(self, request, commande=None):
        return ok(
            mutate_line(
                request.user, commande or request.data.get("ID_CmdFk"), request.data
            ),
            status=201,
        )

    def put(self, request, commande, article):
        return ok(
            mutate_line(
                request.user, commande, request.data, positive(article), "update"
            )
        )

    patch = put

    def delete(self, request, commande, article):
        return ok(
            mutate_line(
                request.user, commande, body=request.data, article_id=positive(article), operation="delete"
            )
        )


class StockView(APIView):
    permission_classes = [IsERPAdmin]

    def get(self, request, kind=None):
        names = {
            "audit": "V_AuditStock",
            "alertes": "V_AlertStock",
            "consommation": "V_ConsoMensuelle",
            "couverture": "V_CouvertureStock",
            "sans-details": "V_CommandesSansDetails",
            "entries": "V_Reglements",
        }
        if kind is None:
            return ok(
                {
                    k: listing(
                        view("logistique", v), request.user, request.query_params.dict()
                    )[0]
                    for k, v in names.items()
                    if k in {"audit", "alertes", "consommation", "couverture"}
                }
            )
        if kind not in names:
            raise APIError("Registre introuvable.", "NOT_FOUND", 404)
        obj = view("logistique", names[kind])
        rows, meta = listing(obj, request.user, request.query_params.dict())
        return ok(rows, meta=meta)


class DashboardView(APIView):
    permission_classes = [IsERPAdmin]

    def get(self, request):
        return ok(dashboard(request.user, request.query_params.dict()))


class ReferencesView(APIView):
    permission_classes = [IsERPAdmin]

    def get(self, request):
        return ok(references(request.user))
