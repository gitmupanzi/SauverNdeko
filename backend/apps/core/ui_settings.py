"""Paramétrage existant T_Fk_Correspondance, sans CREATE TABLE au premier appel."""

import json
from pathlib import Path
from datetime import datetime, timezone
from django.db import transaction
from rest_framework.views import APIView
from . import db
from .registry import model
from .repository import positive, audit
from .permissions import IsERPAdmin
from .responses import ok, APIError

SOURCES = json.loads(
    Path(__file__).with_name("settings_sources.json").read_text(encoding="utf8")
)


def normalize_scope(body, actor, write=False):
    scope = str(body.get("scope", "global")).lower()
    value = body.get("scopeValue")
    if scope not in {"global", "country", "entity"}:
        raise APIError("Périmètre de paramétrage invalide.")
    value = None if scope == "global" else str(value or "").strip()
    if scope != "global" and not value:
        raise APIError("scopeValue obligatoire.")
    if not actor.global_admin:
        if write and (scope != "entity" or value != str(actor.organisation)):
            raise APIError(
                "Paramétrage limité à votre organisation.", "FORBIDDEN_SCOPE", 403
            )
        if scope == "country" or scope == "entity" and value != str(actor.organisation):
            raise APIError("Périmètre interdit.", "FORBIDDEN_SCOPE", 403)
    return scope, value


def rows_for(scope, value):
    return db.query(
        'SELECT f.*,concat_ws(\' \',u."PrenomUser",u."NomUser") AS "UpdatedByName" FROM systeme."T_Fk_Correspondance" f LEFT JOIN systeme."T_Utilisateurs" u ON u."IdUser"=f."UpdatedByUserFk" WHERE f."SettingScope"=%s AND f."ScopeValue" IS NOT DISTINCT FROM %s AND f."MappingType" IN (\'generic_category\',\'hierarchy_mode\') AND f."ValideFkCorrespondance"=true ORDER BY f."DisplayOrder",f."IdFkCorrespondance"',
        [scope, value],
    )


def format_rows(rows, scope, value):
    generic = {}
    hierarchy = {}
    for key, config in SOURCES["generic"].items():
        found = [
            str(r["MappingValue"])
            for r in rows
            if r["SourceKey"] == key and r["MappingType"] == "generic_category"
        ]
        if found and found != list(map(str, config["defaultCategoryIds"])):
            generic[key] = ", ".join(found)
    for key, config in SOURCES["hierarchy"].items():
        found = next(
            (
                r
                for r in rows
                if r["SourceKey"] == key and r["MappingType"] == "hierarchy_mode"
            ),
            None,
        )
        if found and found["MappingValue"] != config.get("defaultMode", "filtered"):
            hierarchy[key] = found["MappingValue"]
    latest = max(
        (r for r in rows if r.get("UpdatedAt")),
        key=lambda r: r["UpdatedAt"],
        default={},
    )
    return {
        "settingKey": "fk-correspondance.standard",
        "settingScope": scope,
        "scopeValue": value,
        "genericCategoryOverrides": generic,
        "hierarchyFilterModes": hierarchy,
        "updatedAt": latest.get("UpdatedAt"),
        "updatedByUserId": latest.get("UpdatedByUserFk"),
        "updatedByName": latest.get("UpdatedByName"),
        "exists": bool(rows),
        "requestedScope": scope,
        "requestedScopeValue": value,
    }


class UISettingsView(APIView):
    permission_classes = [IsERPAdmin]

    def get(self, request):
        scope, value = normalize_scope(request.query_params, request.user)
        return ok(format_rows(rows_for(scope, value), scope, value))

    def put(self, request):
        db.ensure_writable()
        scope, value = normalize_scope(request.data, request.user, True)
        generic = request.data.get("genericCategoryOverrides", {})
        hierarchy = request.data.get("hierarchyFilterModes", {})
        if not isinstance(generic, dict) or not isinstance(hierarchy, dict):
            raise APIError("Paramètres invalides.")
        if (
            set(generic) - SOURCES["generic"].keys()
            or set(hierarchy) - SOURCES["hierarchy"].keys()
        ):
            raise APIError("Source de paramétrage non autorisée.")
        rows = []
        for group, mapping in [
            ("generic", "generic_category"),
            ("hierarchy", "hierarchy_mode"),
        ]:
            for key, config in SOURCES[group].items():
                vals = (
                    list(
                        dict.fromkeys(
                            positive(v.strip()) for v in str(generic[key]).split(",")
                        )
                    )
                    if group == "generic" and key in generic
                    else (
                        config.get("defaultCategoryIds")
                        if group == "generic"
                        else [hierarchy.get(key, config.get("defaultMode", "filtered"))]
                    )
                )
                if group == "hierarchy" and vals[0] not in {"filtered", "all"}:
                    raise APIError("Mode hiérarchique invalide.")
                for index, current in enumerate(vals):
                    if group == "generic" and not db.one(
                        'SELECT "ID_CategorieGenerique" FROM referentiel."T_CategorieGenerique" WHERE "ID_CategorieGenerique"=%s',
                        [current],
                    ):
                        raise APIError("Catégorie générique introuvable.")
                    row = {
                        "ModuleName": config["moduleName"],
                        "SchemaName": config["schemaName"],
                        "ViewName": config.get("viewName"),
                        "SourceKey": key,
                        "FieldName": config["fieldName"],
                        "FieldLabel": config["fieldLabel"],
                        "MappingType": mapping,
                        "ReferenceSchemaName": config.get("referenceSchemaName"),
                        "ReferenceObjectName": config.get("referenceObjectName"),
                        "ReferenceFieldName": config.get("referenceFieldName"),
                        "TargetCategoryIdFk": current if group == "generic" else None,
                        "MappingValue": str(current),
                        "IsDefaultMapping": (
                            vals == config.get("defaultCategoryIds")
                            if group == "generic"
                            else current == config.get("defaultMode", "filtered")
                        ),
                        "ValideFkCorrespondance": True,
                        "SettingScope": scope,
                        "ScopeValue": value,
                        "DisplayOrder": index,
                        "UpdatedAt": datetime.now(timezone.utc),
                        "UpdatedByUserFk": request.user.pk,
                        "ObsFkCorrespondance": "Source " + key,
                    }
                    rows.append(row)
        with transaction.atomic():
            db.query(
                "SELECT pg_advisory_xact_lock(hashtextextended(%s,0))",
                ["settings:" + scope + ":" + str(value)],
            )
            old = rows_for(scope, value)
            db.query(
                'DELETE FROM systeme."T_Fk_Correspondance" WHERE "SettingScope"=%s AND "ScopeValue" IS NOT DISTINCT FROM %s AND "MappingType" IN (\'generic_category\',\'hierarchy_mode\')',
                [scope, value],
            )
            for row in rows:
                db.query(
                    'INSERT INTO systeme."T_Fk_Correspondance" ('
                    + ",".join(db.ident(k) for k in row)
                    + ") VALUES ("
                    + ",".join(["%s"] * len(row))
                    + ")",
                    list(row.values()),
                )
            audit(
                model("T_Fk_Correspondance"),
                "UPDATE",
                format_rows(old, scope, value),
                format_rows(rows, scope, value),
                request.user,
            )
        return ok(
            format_rows(rows_for(scope, value), scope, value),
            message="Paramétrage FK partagé enregistré.",
        )

    def post(self, request):
        from .repository import mutate

        return ok(mutate("T_Admin_UI_Setting", request.user, request.data), status=201)
