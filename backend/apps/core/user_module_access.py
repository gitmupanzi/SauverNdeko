"""Administration des restrictions individuelles d’accès."""
from django.conf import settings
from django.db import transaction
from rest_framework.views import APIView

from . import db
from .application_licences import catalogue_rows, company_catalogue, entity_scope, platform_write, validate_versions
from .module_access import PROTECTED_TABS, RIGHT_FIELDS, individual_rule_rows, individual_rules
from .permissions import IsERPAdmin
from .repository import audit, clean, positive
from .responses import APIError, ok


USER_MODULE_TABLE = {"schema": "systeme", "name": "T_UtilisateurModule"}


def individual_catalogue():
    catalogue = []
    for module in company_catalogue(catalogue_rows()):
        code = module["CodeModule"]
        catalogue.append(module)
        catalogue.extend(
            {"CodeModule": f"{code}.{tab}", "Nom": f"{module['Nom']} · {label}"}
            for tab, label in PROTECTED_TABS.get(code, {}).items()
        )
    return catalogue


def rule_key(code):
    module, _, tab = code.partition(".")
    return module, tab


def require_platform(actor):
    if not actor.global_admin:
        raise APIError("Les restrictions individuelles sont réservées à l’administration de la plateforme.",
                       "PLATFORM_ADMIN_REQUIRED", 403)


def individual_configuration(actor, entity_id):
    require_platform(actor)
    entity_id = entity_scope(actor, entity_id)
    catalogue = individual_catalogue()
    users = db.query(
        """SELECT "IdUser", "NomUser", "PrenomUser", "EmailUser"
           FROM systeme."T_Utilisateurs" WHERE "IdEntiteFk"=%s AND "Is_Admin" IS NOT TRUE
           ORDER BY "NomUser", "PrenomUser", "IdUser" """,
        [entity_id],
    )
    permissions_by_user = {}
    for rule in individual_rule_rows(entity_id):
        permissions_by_user.setdefault(rule["IdUserFk"], {})[rule["CodeModule"], rule["CodeOnglet"]] = rule
    for user in users:
        rules = permissions_by_user.get(user["IdUser"], {})
        user["permissions"] = [
            {**rules[rule_key(code)], "CodeModule": code, "Actif": True}
            for module in catalogue if rule_key(code := module["CodeModule"]) in rules
        ]
        user["baseline"] = {
            module["CodeModule"]: dict.fromkeys(RIGHT_FIELDS, True) for module in catalogue
        }
    return clean({"entityId": entity_id, "catalogue": catalogue, "users": users,
                  "canManage": not settings.DB_READ_ONLY})


def save_individual_rules(actor, user_id, body):
    platform_write(actor)
    if not isinstance(body, dict) or set(body) != {"entityId", "versions", "permissions"}:
        raise APIError("Droits de l’utilisateur invalides.")
    entity_id = entity_scope(actor, body["entityId"])
    user_id = positive(user_id)
    codes = [module["CodeModule"] for module in individual_catalogue()]
    permissions = body["permissions"]
    if not isinstance(permissions, dict) or set(permissions) != set(codes):
        raise APIError("Applications de l’utilisateur invalides.")
    for rights in permissions.values():
        if (not isinstance(rights, dict) or set(rights) != set(RIGHT_FIELDS)
                or any(type(value) is not bool for value in rights.values())):
            raise APIError("Droits de l’utilisateur invalides.")
        if not rights["canRead"] and (rights["canManage"] or rights["canExport"]):
            raise APIError("La consultation est requise pour gérer ou exporter.")
    with transaction.atomic():
        user = db.one(
            """SELECT "IdUser" FROM systeme."T_Utilisateurs"
               WHERE "IdUser"=%s AND "IdEntiteFk"=%s AND "Is_Admin" IS NOT TRUE FOR UPDATE""",
            [user_id, entity_id],
        )
        if not user:
            raise APIError("Utilisateur de cette entreprise introuvable.", "NOT_FOUND", 404)
        rules = individual_rules(entity_id, user_id)
        current = {code: rules[rule_key(code)] for code in codes if rule_key(code) in rules}
        validate_versions(body, codes, current)
        changed = []
        for code, rights in permissions.items():
            old = current.get(code)
            if (old is None and all(rights.values())) or (
                old is not None and all(rights[name] == old[field] for name, field in RIGHT_FIELDS.items())
            ):
                continue
            module, tab = rule_key(code)
            changed.append(db.one(
                """INSERT INTO systeme."T_UtilisateurModule" AS r
                   ("IdEntiteFk", "IdUserFk", "CodeModule", "CodeOnglet", "PeutConsulter",
                    "PeutGerer", "PeutExporter", "ModifieParUserFk")
                   VALUES (%s,%s,%s,%s,%s,%s,%s,%s)
                   ON CONFLICT ("IdEntiteFk", "IdUserFk", "CodeModule", "CodeOnglet")
                   DO UPDATE SET "PeutConsulter"=EXCLUDED."PeutConsulter", "PeutGerer"=EXCLUDED."PeutGerer",
                     "PeutExporter"=EXCLUDED."PeutExporter", "ModifieParUserFk"=EXCLUDED."ModifieParUserFk",
                     "Version"=r."Version"+1, "ModifieLe"=statement_timestamp()
                   RETURNING *""",
                [entity_id, user_id, module, tab, *(rights[name] for name in RIGHT_FIELDS), actor.pk],
            ))
        if changed:
            audit(USER_MODULE_TABLE, "UPDATE",
                  old={"entityId": entity_id, "userId": user_id, "rules": list(current.values())},
                  new={"entityId": entity_id, "userId": user_id, "rules": changed}, actor=actor, entity_id=entity_id)
    return individual_configuration(actor, entity_id)


class UserApplicationsView(APIView):
    permission_classes = [IsERPAdmin]

    def get(self, request, pk=None):
        if pk is not None or set(request.query_params) - {"entite"}:
            raise APIError("Filtre non autorisé.")
        return ok(individual_configuration(request.user, request.query_params.get("entite")))

    def put(self, request, pk=None):
        if pk is None or request.query_params:
            raise APIError("Choisissez un utilisateur.")
        return ok(save_individual_rules(request.user, pk, request.data))
