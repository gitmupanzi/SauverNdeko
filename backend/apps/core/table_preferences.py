"""Catalogue fermé et préférences personnelles, séparées entre tableau et export.

Les définitions et choix sont persistés dans PostgreSQL. Les permissions de la
source restent vérifiées à chaque appel ; une préférence ne donne aucun accès.
"""
import json

from django.db import transaction
from rest_framework.permissions import IsAuthenticated
from rest_framework.views import APIView

from apps.core import db
from apps.core.module_access import access_snapshot, can_use_tab, require_module, require_tab
from apps.core.repository import set_admin_actor
from apps.core.responses import APIError, ok
from apps.core.tenancy import read_entity


def source_definition(actor, interface_key):
    try:
        module, kind = interface_key.split(".", 1)
    except (ValueError, AttributeError):
        raise APIError("Interface inconnue.", "NOT_FOUND", 404)
    if module == "logistique":
        from apps.logistique.depot_registers import KINDS, source as depot_source, LABELS as depot_labels
        from apps.logistique.tab_access import table_tab
        tab = table_tab(interface_key)
        if tab:
            require_tab(actor, module, tab)
        if kind in KINDS:
            return depot_source(actor, kind), depot_labels, module, tab
        from apps.logistique.reads import register_source
        from apps.logistique.tab_access import FINANCE_PROJECTIONS, restricted_fields
        from apps.logistique.table_queries import LABELS
        obj, _, _ = register_source(kind, {}, for_export=True)
        if obj["name"] in FINANCE_PROJECTIONS:
            denied = restricted_fields(actor, invoices=kind == "factures")
            obj = {**obj, "columns": [col for col in obj["columns"] if col["column_name"] not in denied]}
        return obj, LABELS, module, tab
    if module == "referentiels":
        if kind == 'tableaux':
            from .reference_tables import table_source, LABELS
            require_module(actor, 'referentiels')
            return table_source(), LABELS, module, None
        if kind == "champs":
            from apps.core.field_references import table_source, LABELS, _admin
            _admin(actor)
            return table_source(), LABELS, module, None
        from apps.core.reference_exports import SOURCES, LABELS
        from apps.core.registry import view
        require_module(actor, "referentiels")
        if kind not in SOURCES:
            raise APIError("Interface inconnue.", "NOT_FOUND", 404)
        return view("referentiel", SOURCES[kind][0]), LABELS, module, None
    if module == "admin":
        from apps.core.admin_portal import source, LABELS
        from apps.core.admin_tabs import require_admin_tab
        tab = {"profils": "utilisateurs", "localisations": "entites"}.get(kind, kind)
        require_admin_tab(actor, tab)
        obj, *_ = source(actor, kind)
        return obj, LABELS, "administration", tab
    if module == "territoires":
        from apps.core.territorial_portal import source, LABELS, INTERFACE_KEYS
        kind = next((key for key, value in INTERFACE_KEYS.items() if value == interface_key), None)
        if kind is None:
            raise APIError("Interface inconnue.", "NOT_FOUND", 404)
        obj, *_ = source(actor, kind)
        return obj, LABELS, module, None
    if module == "support" and kind == "tickets":
        from apps.support.portal import table_source, LABELS
        require_tab(actor, module, kind)
        return table_source(actor), LABELS, module, kind
    if module == "caisse":
        from apps.caisse.services import columns, descriptor
        from apps.caisse.views import LABELS
        view_name, _, primary_key, _ = descriptor(kind)
        require_tab(actor, module, kind)
        return {'schema':'operations', 'name':view_name, 'primaryKey':[primary_key],
                'columns':list(columns(kind, actor).values())}, LABELS, module, kind
    raise APIError("Interface inconnue.", "NOT_FOUND", 404)


def catalogue(actor, interface_key):
    obj, labels, module, tab = source_definition(actor, interface_key)
    row = db.one('SELECT "Version", "Colonnes" FROM referentiel."T_InterfaceTableau" '
                 'WHERE "CleInterface"=%s AND "Actif"=true', [interface_key])
    if row is None:
        raise APIError("Les réglages de ce tableau sont indisponibles.", "TABLE_CONFIGURATION_UNAVAILABLE", 503)
    available = {col["column_name"] for col in obj["columns"] if col["column_name"] in labels}
    # La permission reste la liste fermée du service, même si le catalogue SQL a
    # été enrichi manuellement par un administrateur de base de données.
    columns = [col for col in row["Colonnes"] if col["id"] == "actions" or col["id"] in available]
    if module == "logistique":
        from apps.logistique.tab_access import FINANCE_PROJECTIONS, restricted_fields
        if obj["name"] in FINANCE_PROJECTIONS:
            denied = restricted_fields(actor, invoices=tab == "factures", action="export")
            columns = [{**col, "exportable": False, "defaultExport": False} if col["id"] in denied else col
                       for col in columns]
    snapshot = access_snapshot(actor)
    rights = snapshot["modules"]
    if tab:
        can_export = can_use_tab(actor, module, tab, "export")
    else:
        can_export = any(item["canExport"] for item in rights.values()) if module == "referentiels" else rights[module]["canExport"]
    return columns, row["Version"], bool(can_export)


def default_columns(columns, usage):
    flag = "defaultExport" if usage == "export" else "defaultVisible"
    return [col["id"] for col in sorted(columns, key=lambda col: col.get("defaultExportOrder", col["defaultOrder"]) if usage == "export" else col["defaultOrder"])
            if col.get(flag) and (col["exportable"] if usage == "export" else col.get("tableAvailable", True))]


def preference(actor, interface_key, usage, columns=None):
    if columns is None:
        columns, _, _ = catalogue(actor, interface_key)
    row = db.one('SELECT "Colonnes", "Version" FROM referentiel."T_PreferenceTableau" '
        'WHERE "CleInterfaceFk"=%s AND "IdUserFk"=%s AND "IdEntiteFk" IS NOT DISTINCT FROM %s AND "Usage"=%s',
        [interface_key, actor.pk, read_entity(actor), usage])
    allowed = {col["id"] for col in columns if (col["exportable"] if usage == "export" else col.get("tableAvailable", True))}
    if row:
        # Les colonnes supprimées du catalogue disparaissent sans réécrire les
        # préférences ; les nouvelles colonnes restent disponibles, non imposées.
        selected = [key for key in row["Colonnes"] if key in allowed]
        return {"columns": selected, "version": row["Version"], "personal": True}
    return {"columns": default_columns(columns, usage), "version": 0, "personal": False}


def settings_snapshot(actor, interface_key):
    columns, version, can_export = catalogue(actor, interface_key)
    return {"interfaceKey": interface_key, "catalogueVersion": version, "columns": columns,
            "table": preference(actor, interface_key, "table", columns),
            "export": preference(actor, interface_key, "export", columns),
            "scope": {"entityId": read_entity(actor)}, "canExport": can_export}


def export_keys(actor, interface_key, raw):
    """Valide un choix explicite ou reprend uniquement la préférence d'export."""
    columns, _, can_export = catalogue(actor, interface_key)
    if not can_export:
        raise APIError("Votre rôle ne permet pas l’export.", "MODULE_ACTION_FORBIDDEN", 403)
    wanted = raw.get("columns")
    if wanted is None or wanted == "":
        wanted = preference(actor, interface_key, "export", columns)["columns"]
    elif isinstance(wanted, str):
        try:
            wanted = json.loads(wanted)
        except (ValueError, TypeError):
            raise APIError("Colonnes d’export invalides.")
    allowed = {col["id"] for col in columns if col["exportable"]}
    validate_columns(wanted, allowed)
    return wanted


def validate_columns(wanted, allowed):
    if (not isinstance(wanted, list) or not wanted or len(wanted) > 100
        or any(not isinstance(key, str) or key not in allowed for key in wanted)
        or len(set(wanted)) != len(wanted)):
        raise APIError("Choisissez des colonnes autorisées, sans doublon.", "TABLE_COLUMNS_INVALID", 400)


class TablePreferencesView(APIView):
    # Un utilisateur qui peut consulter une interface peut régler sa propre vue,
    # sans obtenir le droit de modifier les données ou réglages communs.
    permission_classes = [IsAuthenticated]

    def get(self, request, interface_key):
        if request.query_params:
            raise APIError("Critère non autorisé.")
        return ok(settings_snapshot(request.user, interface_key))

    def put(self, request, interface_key):
        return self.mutate(request, interface_key, reset=False)

    def delete(self, request, interface_key):
        return self.mutate(request, interface_key, reset=True)

    def mutate(self, request, interface_key, reset):
        db.ensure_writable()
        body, actor = request.data, request.user
        if not isinstance(body, dict) or set(body) - {"usage", "columns", "version"}:
            raise APIError("Réglages invalides.")
        usage, version = body.get("usage"), body.get("version")
        if usage not in {"table", "export"} or type(version) is not int or version < 0:
            raise APIError("Réglages invalides.")
        columns, _, _ = catalogue(actor, interface_key)
        allowed = {col["id"] for col in columns if (col["exportable"] if usage == "export" else col.get("tableAvailable", True))}
        if not reset:
            validate_columns(body.get("columns"), allowed)
        entity = read_entity(actor)
        with transaction.atomic():
            # La clé inclut utilisateur, entreprise, interface et usage : deux
            # navigateurs n'écrasent jamais silencieusement leurs modifications.
            db.query("SELECT pg_advisory_xact_lock(hashtextextended(%s,0))",
                     [f"table-pref:{actor.pk}:{entity}:{interface_key}:{usage}"])
            current = preference(actor, interface_key, usage, columns)
            if current["version"] != version:
                raise APIError("Ces réglages ont changé. Rechargez-les avant d’enregistrer.", "TABLE_PREFERENCE_CONFLICT", 409)
            set_admin_actor(actor)
            keys = [interface_key, actor.pk, entity, usage]
            if reset:
                db.query('DELETE FROM referentiel."T_PreferenceTableau" WHERE "CleInterfaceFk"=%s '
                    'AND "IdUserFk"=%s AND "IdEntiteFk" IS NOT DISTINCT FROM %s AND "Usage"=%s', keys)
            elif current["personal"]:
                db.query('UPDATE referentiel."T_PreferenceTableau" SET "Colonnes"=%s::jsonb '
                    'WHERE "CleInterfaceFk"=%s AND "IdUserFk"=%s AND "IdEntiteFk" IS NOT DISTINCT FROM %s AND "Usage"=%s',
                    [json.dumps(body["columns"]), *keys])
            else:
                db.query('INSERT INTO referentiel."T_PreferenceTableau" '
                    '("CleInterfaceFk","IdUserFk","IdEntiteFk","Usage","Colonnes") VALUES (%s,%s,%s,%s,%s::jsonb)',
                    [*keys, json.dumps(body["columns"])])
            result = settings_snapshot(actor, interface_key)
        return ok(result, message="Configuration de référence rétablie." if reset else "Préférences enregistrées.")
