from rest_framework.parsers import MultiPartParser
from apps.core.parsers import ExactJSONParser
import json
from pathlib import Path
from rest_framework.views import APIView
from rest_framework.permissions import AllowAny
from django.db import transaction
from . import db
from .registry import MODELS, VIEWS, model, view
from .permissions import IsERPAdmin, scope_for
from .module_access import module_for_object, require_module
from .repository import listing, get_record, mutate, positive, clean, secret_key
from .responses import ok, APIError

MODULES = json.loads(
    Path(__file__).with_name("modules.json").read_text(encoding="utf8")
)


class HealthView(APIView):
    authentication_classes = []
    permission_classes = [AllowAny]

    def get(self, request):
        db.one("SELECT 1 AS ready")
        return ok(
            {
                "backend": "django",
                "databaseReadOnly": __import__(
                    "django.conf", fromlist=["settings"]
                ).settings.DB_READ_ONLY,
            },
            message="SauverNdeko backend is running.",
        )


class ModuleView(APIView):
    permission_classes = [IsERPAdmin]
    parser_classes = [ExactJSONParser, MultiPartParser]

    def objects(self, module=None, model_name=None):
        conf = MODULES.get(module) if module else {"model": model_name, "view": None}
        if not conf:
            raise APIError("Module introuvable.", "NOT_FOUND", 404)
        obj = model(conf["model"])
        if (
            model_name is not None
            and obj["schema"] not in {"referentiel", "geolocalisation"}
            and obj["name"] != "T_Entite_Localisation"
        ):
            raise APIError(
                "Utiliser la route métier dédiée.", "DEDICATED_ROUTE_REQUIRED", 403
            )
        v = view(obj["schema"], conf["view"]) if conf.get("view") else obj
        v = {
            **v,
            "primaryKey": [
                pk
                for pk in obj["primaryKey"]
                if pk in {c["column_name"] for c in v["columns"]}
            ],
        }
        return obj, v

    def get(
        self,
        request,
        module=None,
        model_name=None,
        pk=None,
        search=False,
        category=None,
    ):
        obj, source = self.objects(module, model_name)
        params = request.query_params.dict()
        if search and not params.get("q"):
            raise APIError("Le paramètre q est obligatoire.")
        if category:
            params["categorie"] = category
        if pk is not None:
            if len(obj["primaryKey"]) != 1:
                raise APIError("Clé composée : utiliser la route métier.")
            source = (
                source
                if obj["primaryKey"][0] in {c["column_name"] for c in source["columns"]}
                else obj
            )
            # Le formulaire recharge les valeurs brutes de ses FK. Les vues de
            # présentation ne contiennent pas toutes les clés d’édition.
            if obj["name"] in {"T_Utilisateurs", "T_Licence"}:
                source = obj
            if obj["name"]=="T_Reglements":
                from apps.logistique.payments import get_payment
                data,meta=get_payment(request.user,positive(pk));response=ok(data,meta=meta);response["ETag"]='"'+meta["revision"]+'"';return response
            if obj["name"] == "T_Commande":
                from apps.logistique.document_rules import editable_record
                record = editable_record(obj,source,request.user,{obj["primaryKey"][0]:positive(pk)})
            else:
                record = get_record(source, request.user, {obj["primaryKey"][0]: positive(pk)})
            if obj["name"] == "T_Article":
                from apps.logistique.article_rules import usage
                return ok(clean(record), meta=usage(record, request.user))
            if obj["name"] == "T_Commande":
                from apps.logistique.document_rules import usage
                return ok(clean(record), meta=usage(record, request.user))
            if obj["name"] == "T_Admin_UI_Setting":
                return ok(clean(record), meta={"sensitive": secret_key(record.get("SettingKey", ""))})
            return ok(clean(record))
        rows, meta = listing(source, request.user, params)
        return ok(rows, meta=meta)

    def post(self, request, module=None, model_name=None):
        obj, _ = self.objects(module, model_name)
        if obj["name"] == "T_Article":
            from apps.logistique.photos import request_data, save_article
            body, photo = request_data(request)
            return ok(save_article(request.user, body, photo), status=201)
        result=mutate(obj["name"],request.user,request.data)
        return ok(result,status=200 if obj["name"]=="T_Reglements" and result.get("replayed") else 201)

    def put(self, request, module=None, model_name=None, pk=None):
        obj, _ = self.objects(module, model_name)
        if pk is None or len(obj["primaryKey"]) != 1:
            raise APIError("Identifiant requis.")
        if obj["name"] == "T_Article":
            from apps.logistique.photos import request_data, save_article
            body, photo = request_data(request)
            return ok(save_article(request.user, body, photo, positive(pk)))
        return ok(
            mutate(
                obj["name"],
                request.user,
                request.data,
                {obj["primaryKey"][0]: positive(pk)},
                "update",
            )
        )

    patch = put

    def delete(self, request, module=None, model_name=None, pk=None):
        obj, _ = self.objects(module, model_name)
        if pk is None or len(obj["primaryKey"]) != 1:
            raise APIError("Identifiant requis.")
        return ok(
            mutate(
                obj["name"],
                request.user,
                body=request.data if obj["name"] in {"T_Article","T_Commande","T_Reglements"} else None,
                keys={obj["primaryKey"][0]: positive(pk)},
                operation="delete",
                hard=request.query_params.get("mode") == "hard",
            )
        )


class ModelListView(APIView):
    permission_classes = [IsERPAdmin]

    def get(self, request):
        return ok(
            [
                {
                    "model": m["name"],
                    "schema": m["schema"],
                    "primaryKey": m["primaryKey"][0],
                    "writable": m["name"]
                    not in {
                        "T_Mouvement",
                        "T_Login",
                        "T_Audit_Log",
                        "T_Paiement_Archive",
                    },
                }
                for m in MODELS.values()
                if m["schema"] in {"referentiel", "geolocalisation"}
                or m["name"] == "T_Entite_Localisation"
            ]
        )


class ViewsView(APIView):
    permission_classes = [IsERPAdmin]

    def get(self, request, schema=None, name=None):
        if schema is not None:
            obj = view(schema, name)
            rows, meta = listing(obj, request.user, request.query_params.dict())
            return ok(rows, meta=meta)
        result = []
        for obj in VIEWS.values():
            try:
                scope_for(obj, request.user)
                require_module(request.user,module_for_object(obj))
            except APIError:
                continue
            result.append(
                {
                    "schema": obj["schema"],
                    "name": obj["name"],
                    "columns": [c["column_name"] for c in obj["columns"]],
                }
            )
        return ok(result)


class HierarchyView(APIView):
    permission_classes = [IsERPAdmin]

    def get(self, request, level=None, pk=None):
        if level is None:
            return ok(
                {
                    "niveau"
                    + str(i): listing(
                        view("geolocalisation", "V_Niveau_" + str(i)),
                        request.user,
                        {"take": 50, "sortDir": "asc"},
                    )[0]
                    for i in range(6)
                }
            )
        level = positive(int(level) + 1) - 1
        pk = positive(pk)
        choices = {
            0: [(1, "ID_Niveau_0_Fk")],
            1: [(2, "ID_Niveau_1_FK")],
            2: [(3, "ID_Niveau_2_FK")],
            3: [(4, "ID_Niveau_3_Fk"), (5, "ID_Niveau_3_Fk")],
            4: [(5, "ID_Niveau_4_Fk")],
        }
        if level not in choices:
            raise APIError("Niveau invalide.")
        result = {
            "niveau"
            + str(n): listing(
                model("T_Niveau_" + str(n)),
                request.user,
                {"filters": {field: pk}, "take": 500, "sortDir": "asc"},
            )[0]
            for n, field in choices[level]
        }
        return ok(result if level == 3 else next(iter(result.values())))


class RecherchesView(APIView):
    permission_classes = [IsERPAdmin]

    def get(self, request, pk=None):
        if not request.user.global_admin:
            raise APIError(
                "Historique de recherche réservé à l’administration globale.",
                "GLOBAL_ADMIN_REQUIRED",
                403,
            )
        obj = model("T_Recherche")
        if pk is not None:
            return ok(
                clean(get_record(obj, request.user, {"IdRecherche": positive(pk)}))
            )
        rows, meta = listing(obj, request.user, request.query_params.dict())
        return ok(rows, meta=meta)
