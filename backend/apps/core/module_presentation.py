"""Présentation d’un module, partagée dans l’entreprise active."""

import hashlib
import json
import unicodedata

from django.conf import settings
from django.db import transaction
from psycopg.types.json import Jsonb
from rest_framework.views import APIView

from . import db
from .module_access import MODULE_BY_KEY, access_snapshot, require_module
from .parsers import ExactJSONParser
from .permissions import HasModuleAccess
from .repository import set_admin_actor
from .responses import APIError, ExactEncoder, ok
from .tenancy import read_entity


PRESENTATIONS = {
    "logistique": {
        "settingKey": "logistique.presentation",
        "label": "Présentation de la Logistique",
        "tabDefaults": {
            "dashboard": "Tableau de bord",
            "dossiers": "Dossiers de suivi",
            "tiers": "Clients et fournisseurs",
            "depots": "Dépôts",
            "articles": "Articles",
            "lots": "Lots de stock",
            "stocks-depots": "Stocks par dépôt",
            "commandes": "Bons de stock",
            "details": "Lignes des bons",
            "transferts": "Transferts internes",
            "mouvements": "Mouvements de stock",
            "inventaires": "Inventaires",
            "factures": "Factures",
            "reglements": "Règlements",
            "immobilisations": "Immobilisations",
        },
        "dashboardBlockDefaults": {
            "articles": "Articles",
            "commandes": "Bons de stock",
            "factures": "Factures",
            "alertes": "Alertes",
        },
    },
    "caisse": {
        "settingKey": "caisse.presentation",
        "label": "Présentation de la Caisse",
        "tabDefaults": {
            "tableau-de-bord": "Tableau de bord",
            "caisses": "Caisses",
            "ecritures": "Écritures",
            "clotures": "Clôtures",
        },
        "dashboardBlockDefaults": {
            "synthese": "Indicateurs par devise",
            "flux": "Flux quotidiens",
        },
    },
}

PRESENTATION_SETTING_KEYS = frozenset(item["settingKey"] for item in PRESENTATIONS.values())
REQUIRED_FIELDS = {"tabLabels", "hiddenDashboardBlocks"}
PRESENTATION_FIELDS = REQUIRED_FIELDS | {"hiddenTabs"}
IDENTITY_FIELDS = {"entityId", "revision"}
REQUIRED_PAYLOAD_FIELDS = REQUIRED_FIELDS | IDENTITY_FIELDS
ALLOWED_PAYLOAD_FIELDS = PRESENTATION_FIELDS | IDENTITY_FIELDS


def definition_for(module):
    definition = PRESENTATIONS.get(module)
    if definition is None:
        raise APIError("Ce module ne propose pas de réglage d’affichage.", "NOT_FOUND", 404)
    return definition


def validate_hidden(values, choices, field):
    if (not isinstance(values, list) or len(values) > len(choices)
            or any(not isinstance(key, str) or key not in choices for key in values)
            or len(set(values)) != len(values)):
        raise APIError({field: "Sélectionnez chaque élément proposé une seule fois."},
                       "PRESENTATION_VALIDATION", 422)
    return [key for key in choices if key in values]


def validate_values(definition, values):
    if not isinstance(values, dict) or not REQUIRED_FIELDS <= values.keys() <= PRESENTATION_FIELDS:
        raise APIError("Renseignez les noms d’onglets et les blocs à masquer.", "PRESENTATION_VALIDATION", 422)
    labels = values["tabLabels"]
    tab_defaults = definition["tabDefaults"]
    if not isinstance(labels, dict) or set(labels) - tab_defaults.keys():
        raise APIError({"tabLabels": "Sélectionnez les onglets proposés."}, "PRESENTATION_VALIDATION", 422)

    overrides = {}
    for key, label in labels.items():
        if (not isinstance(label, str) or not 1 <= len(label.strip()) <= 60
                or any(unicodedata.category(char) in {"Cc", "Cs", "Zl", "Zp"} for char in label)):
            raise APIError({"tabLabels": {key: "Saisissez un libellé de 1 à 60 caractères sur une seule ligne."}},
                           "PRESENTATION_VALIDATION", 422)
        label = label.strip()
        if label != tab_defaults[key]:
            overrides[key] = label

    return {
        "tabLabels": overrides,
        "hiddenTabs": validate_hidden(values.get("hiddenTabs", []), tab_defaults, "hiddenTabs"),
        "hiddenDashboardBlocks": validate_hidden(values["hiddenDashboardBlocks"],
                                                 definition["dashboardBlockDefaults"], "hiddenDashboardBlocks"),
    }


def setting_row(entity, definition, *, lock=False):
    return db.one('''SELECT "IdAdminUISetting", "SettingValueJson", "ValideSetting", "IsEditable",
        xmin::text AS revision FROM systeme."T_Admin_UI_Setting"
        WHERE "SettingScope"='entite' AND "ScopeValue"=%s AND "SettingKey"=%s'''
        + (' FOR UPDATE' if lock else ''), [str(entity), definition["settingKey"]])


def revision_for(row):
    if row is None:
        return None
    # La révision détecte aussi les changements au sein d’une même transaction.
    snapshot = json.dumps(row, sort_keys=True, cls=ExactEncoder, separators=(",", ":"))
    return hashlib.sha256(snapshot.encode()).hexdigest()


def stored_values(definition, row):
    if row and row["ValideSetting"] is True:
        try:
            return validate_values(definition, row["SettingValueJson"])
        except APIError:
            # Un réglage SQL invalide reste réparable depuis l’interface.
            return None
    return None


def presentation_data(definition, entity, row=None, *, can_manage=False):
    values = stored_values(definition, row) or {"tabLabels": {}, "hiddenTabs": [], "hiddenDashboardBlocks": []}
    return {"entityId": entity, **values, "tabDefaults": definition["tabDefaults"],
            "dashboardBlockDefaults": definition["dashboardBlockDefaults"], "revision": revision_for(row),
            "canManage": bool(can_manage and (row is None or row["IsEditable"] is True))}


def available_presentation_modules(actor, entity):
    if entity is None:
        return []
    rights = access_snapshot(actor)["modules"]
    modules = [key for key in PRESENTATIONS if rights.get(key, {}).get("canRead")]
    if actor.global_admin and modules:
        # Le droit global de consulter un module ne constitue pas une licence de l’entreprise.
        licensed = {row["CodeModule"] for row in db.query('''SELECT "CodeModule"
            FROM systeme."V_EntiteModuleActif" WHERE "IdEntiteFk"=%s AND "CodeModule"=ANY(%s::text[])''',
            [entity, modules])}
        return [key for key in modules if key in licensed]
    return modules


def require_company_presentation(actor, module, entity):
    if module not in available_presentation_modules(actor, entity):
        raise APIError("Ce module n’est pas disponible pour cette entreprise.", "MODULE_NOT_INCLUDED", 403)


def read_presentation(actor, module, *, in_settings=False):
    definition = definition_for(module)
    require_module(actor, module)
    if in_settings:
        require_module(actor, "parametres")
    entity = read_entity(actor)
    if entity is None:
        if not actor.global_admin:
            raise APIError("Votre compte doit être rattaché à une entreprise.", "ORGANISATION_REQUIRED", 403)
        return presentation_data(definition, None)
    company = db.one('SELECT "ValideEntite" FROM systeme."T_Entite" WHERE "IdEntite"=%s', [entity])
    if company is None:
        raise APIError("Entreprise introuvable.", "NOT_FOUND", 404)
    settings_rights = access_snapshot(actor)["modules"].get("parametres", {})
    can_manage = (actor.admin and not settings.DB_READ_ONLY and company["ValideEntite"] is True
                  and settings_rights.get("canManage") is True)
    if in_settings:
        require_company_presentation(actor, module, entity)
    elif can_manage:
        can_manage = module in available_presentation_modules(actor, entity)
    return presentation_data(definition, entity, setting_row(entity, definition), can_manage=can_manage)


@transaction.atomic
def save_presentation(actor, module, body):
    definition = definition_for(module)
    require_module(actor, module)
    require_module(actor, "parametres", "manage")
    if not actor.admin:
        raise APIError("Ce réglage est réservé à l’administration de l’entreprise.", "FORBIDDEN", 403)
    db.ensure_writable()
    entity = read_entity(actor)
    if entity is None:
        raise APIError("Choisissez une entreprise avant d’enregistrer.", "ENTITY_REQUIRED", 409)
    if not isinstance(body, dict) or not REQUIRED_PAYLOAD_FIELDS <= body.keys() <= ALLOWED_PAYLOAD_FIELDS:
        raise APIError("Les paramètres d’affichage transmis sont incomplets.", "PRESENTATION_VALIDATION", 422)
    if type(body["entityId"]) is not int or body["entityId"] != entity:
        raise APIError("L’entreprise active a changé. Rechargez les réglages.", "ENTITY_MISMATCH", 403)
    revision = body["revision"]
    if revision is not None and (not isinstance(revision, str) or not 1 <= len(revision) <= 128):
        raise APIError("Rechargez les réglages avant d’enregistrer.", "PRESENTATION_VALIDATION", 422)
    values = validate_values(definition, {key: body[key] for key in PRESENTATION_FIELDS & body.keys()})

    company = db.one('SELECT "ValideEntite" FROM systeme."T_Entite" WHERE "IdEntite"=%s FOR SHARE', [entity])
    if company is None or company["ValideEntite"] is not True:
        raise APIError("Les écritures de cette entreprise sont désactivées.", "ENTITY_INACTIVE", 409)
    require_company_presentation(actor, module, entity)
    setting_key = definition["settingKey"]
    db.query('SELECT pg_advisory_xact_lock(hashtextextended(%s,0))', [f"module-presentation:{setting_key}:{entity}"])
    row = setting_row(entity, definition, lock=True)
    if revision != revision_for(row):
        raise APIError("Les réglages ont changé. Rechargez-les avant d’enregistrer.", "VERSION_CONFLICT", 409)
    if row and row["IsEditable"] is not True:
        raise APIError("Ce réglage est protégé et reste en consultation.", "SETTING_PROTECTED", 409)
    previous = stored_values(definition, row)
    if "hiddenTabs" not in body and previous is not None:
        values["hiddenTabs"] = previous["hiddenTabs"]
    if (row is None and not any(values.values())) or previous == values:
        return presentation_data(definition, entity, row, can_manage=True)

    set_admin_actor(actor)
    if row:
        db.query('''UPDATE systeme."T_Admin_UI_Setting"
            SET "SettingValueJson"=%s,"ValideSetting"=true WHERE "IdAdminUISetting"=%s''',
            [Jsonb(values), row["IdAdminUISetting"]])
    else:
        db.query('''INSERT INTO systeme."T_Admin_UI_Setting"
            ("SettingScope","ScopeValue","SettingKey","SettingLabel","SettingGroup","SettingType",
             "SettingValueJson","ValideSetting","IsEditable","IsSystem")
            VALUES ('entite',%s,%s,%s,%s,'json',%s,true,true,true)''',
            [str(entity), setting_key, definition["label"], module, Jsonb(values)])
    return presentation_data(definition, entity, setting_row(entity, definition), can_manage=True)


class ModulePresentationView(APIView):
    permission_classes = [HasModuleAccess]
    http_method_names = ["get", "head", "options"]

    def get(self, request, module_key):
        if request.query_params:
            raise APIError("Aucun critère attendu pour les réglages d’affichage.")
        return ok(read_presentation(request.user, module_key))


class PresentationModulesView(ModulePresentationView):
    def get(self, request):
        if request.query_params:
            raise APIError("Aucun critère attendu pour les réglages d’affichage.")
        entity = read_entity(request.user)
        return ok({
            "entityId": entity,
            "modules": [{"key": key, "label": MODULE_BY_KEY[key]["label"]}
                        for key in available_presentation_modules(request.user, entity)],
        })


class ModulePresentationSettingsView(ModulePresentationView):
    parser_classes = [ExactJSONParser]
    http_method_names = ["get", "put", "head", "options"]

    def get(self, request, module_key):
        if request.query_params:
            raise APIError("Aucun critère attendu pour les réglages d’affichage.")
        return ok(read_presentation(request.user, module_key, in_settings=True))

    def put(self, request, module_key):
        if request.query_params:
            raise APIError("Aucun critère attendu pour les réglages d’affichage.")
        return ok(save_presentation(request.user, module_key, request.data), message="Présentation enregistrée.")
