"""Portail d’administration : lectures et exports partagent un périmètre fermé.

Les vues existantes restent la source ; aucune copie, DDL ou écriture lors des
lectures. Les journaux et réglages globaux restent réservés à la plateforme.
"""
import json
from datetime import date, datetime, time, timedelta
from tempfile import SpooledTemporaryFile

from django.conf import settings
from django.db import connection, transaction
from django.http import FileResponse
from rest_framework.views import APIView

from apps.accounts.authentication import Actor
from apps.core import db
from apps.core.module_access import access_snapshot, require_module
from apps.core.permissions import IsERPAdmin, scope_for
from apps.core.registry import model, view
from apps.core.repository import clean, page, positive, predicate
from apps.core.responses import APIError, ok
from apps.core.tenancy import read_entity
from apps.logistique.excel import ExcelDownloadView, MAX_EXPORT_ROWS, XLSX_MEDIA_TYPE, write_workbook
from apps.logistique.table_queries import document_zone


# Identités exactes des vues : ni nom d’objet ni nom de colonne ne vient du client.
SOURCES = {
    "utilisateurs": ("systeme", "V_User_profil", "IdUser", "NomUser", "DatecreationUser"),
    "profils": ("systeme", "V_User_profil", "IdUser", "NomUser", "DatecreationUser"),
    "entites": ("systeme", "T_Entite", "IdEntite", "NomEntite", "DateCreationEntite"),
    "roles": ("referentiel", "V_Generique", "ID_Generique", "NomGenerique", None),
    "audit": ("systeme", "V_Audit_log", "IdLog", "ChangedAt", "ChangedAt"),
    "correspondances": ("systeme", "V_Fk_Correspondance_Detail", "IdFkCorrespondance", "ModuleName", "UpdatedAt"),
    "localisations": ("systeme", "V_Entite_Localisation_Detail", "IdEntiteLocalisation", "NomEntite", "DateCreation"),
    "licences": ("systeme", "V_Licence_active", "IdLicence", "DateFin", "DateFin"),
    "connexions": ("systeme", "V_Login_history", "IdLogin", "DateLogin", "DateLogin"),
    "parametres": ("systeme", "V_Admin_UI_Setting", "IdAdminUISetting", "SettingGroup", "UpdatedAt"),
    "audit-parametres": ("systeme", "V_Admin_UI_Setting_Audit", "IdLog", "ChangedAt", "ChangedAt"),
}
GLOBAL_ONLY = {"audit", "correspondances", "connexions", "parametres", "audit-parametres"}
TITLES = {
    "utilisateurs": "Utilisateurs", "profils": "Profils utilisateurs", "entites": "Entreprises",
    "roles": "Rôles", "audit": "Journaux d’audit", "correspondances": "Correspondances des références",
    "localisations": "Localisations des entreprises", "licences": "Licences", "connexions": "Historique de connexion",
    "parametres": "Paramètres de l’application", "audit-parametres": "Historique des paramètres",
}
LABELS = {
    "MatriculeUser":"Matricule", "ID_ServiceFk":"Identifiant service", "ID_FonctionFk":"Identifiant fonction",
    "Service":"Service", "Fonction":"Fonction", "DateEmbauche":"Date d’embauche", "DateFinEmploi":"Fin d’emploi",
    "ObservationProfessionnelle":"Observations professionnelles", "EstAffectable":"Affectation possible",
    "IdUser": "Identifiant utilisateur", "NomUser": "Nom", "PrenomUser": "Prénom", "EmailUser": "Adresse e-mail",
    "PhoneUser": "Téléphone", "SexeUser": "Sexe", "ValideUser": "État", "Is_staff": "Gestionnaire", "Is_Admin": "Administrateur global",
    "DatecreationUser": "Créé le", "IdEntite": "Identifiant entreprise", "IdEntiteFk": "Identifiant entreprise", "NomEntite": "Entreprise",
    "IdRoleFk": "Identifiant rôle", "Role": "Rôle",
    "EmailEntite": "E-mail de l’entreprise", "PhoneEntite": "Téléphone de l’entreprise", "AdresseEntite": "Adresse",
    "DateCreationEntite": "Créée le", "IdTypeEntiteFk": "Type d’entreprise", "ValideEntite": "État",
    "ID_Generique": "Identifiant rôle", "ID_CategorieGeneriqueFk": "Identifiant catégorie", "NomGenerique": "Rôle",
    "AbrGenerique": "Code", "ObsGenerique": "Description", "ValideGenerique": "État", "NomCategorieGenerique": "Catégorie",
    "ModuleCategorieGenerique": "Modules associés", "IdLicence": "Identifiant licence", "DateDebut": "Début", "DateFin": "Fin",
    "ValideLicence": "Valide", "ExpireeLicence": "Expirée", "statut_licence": "Statut",
    "IdLog": "Identifiant événement", "TableName": "Objet", "Operation": "Opération", "ChangedAt": "Date et heure",
    "OldData": "Avant", "NewData": "Après", "IdLogin": "Identifiant connexion", "DateLogin": "Date et heure",
    "IdTypeLoginFk": "Identifiant type", "TypeLogin": "Événement", "IdEntiteLocalisation": "Identifiant localisation",
    "TypeEntite": "Type d’entreprise", "Latitude": "Latitude", "Longitude": "Longitude", "AdresseDetaillee": "Adresse détaillée",
    "DateCreation": "Créée le", "IdNiveau_3_Fk": "Identifiant niveau 3", "NomNiveau_3": "Niveau 3",
    "IdNiveau_4_Fk": "Identifiant niveau 4", "NomNiveau_4": "Niveau 4", "IdNiveau_5_Fk": "Identifiant niveau 5", "NomNiveau_5": "Niveau 5",
    "IdFkCorrespondance": "Identifiant correspondance", "ModuleName": "Module", "SchemaName": "Schéma", "ViewName": "Vue",
    "SourceKey": "Source", "FieldName": "Champ", "FieldLabel": "Libellé du champ", "MappingType": "Type de correspondance",
    "ReferenceSchemaName": "Schéma référencé", "ReferenceObjectName": "Objet référencé", "ReferenceFieldName": "Clé référencée",
    "TargetCategoryIdFk": "Identifiant catégorie", "MappingValue": "Valeur", "IsDefaultMapping": "Configuration standard",
    "ValideFkCorrespondance": "État", "SettingScope": "Portée", "ScopeValue": "Périmètre", "DisplayOrder": "Ordre",
    "UpdatedAt": "Modifié le", "UpdatedByUserFk": "Identifiant auteur", "UpdatedByName": "Modifié par", "ObsFkCorrespondance": "Observations",
    "IdAdminUISetting": "Identifiant paramètre", "SettingKey": "Clé", "SettingLabel": "Paramètre", "SettingGroup": "Groupe",
    "SettingValue": "Valeur", "SettingValueJson": "Valeur structurée", "SettingType": "Type", "IsEditable": "Modifiable",
    "IsSystem": "Paramètre système", "ValideSetting": "État", "CreatedAt": "Créé le", "ObsSetting": "Observations",
    "UpdatedByUserId": "Identifiant auteur", "UpdatedSettingAt": "Date du réglage",
}
DEFAULTS = {
    "utilisateurs": ["NomUser", "MatriculeUser", "NomEntite", "Service", "Fonction", "Role", "ValideUser", "Is_Admin"],
    "profils": ["NomUser", "MatriculeUser", "NomEntite", "Service", "Fonction", "ValideUser"],
    "entites": ["NomEntite", "EmailEntite", "PhoneEntite", "AdresseEntite", "ValideEntite"],
    "roles": ["NomGenerique", "AbrGenerique", "ObsGenerique", "ValideGenerique"],
    "audit": ["ChangedAt", "TableName", "Operation", "NomEntite"],
    "correspondances": ["ModuleName", "FieldLabel", "NomCategorieGenerique", "MappingType", "SettingScope", "ValideFkCorrespondance", "UpdatedAt"],
    "localisations": ["NomEntite", "TypeEntite", "NomNiveau_3", "NomNiveau_4", "NomNiveau_5", "AdresseDetaillee"],
    "licences": ["NomEntite", "DateDebut", "DateFin", "statut_licence"],
    "connexions": ["DateLogin", "TypeLogin", "NomUser", "PrenomUser", "NomEntite"],
    "parametres": ["SettingLabel", "SettingGroup", "SettingValue", "SettingScope", "IsEditable", "UpdatedAt"],
    "audit-parametres": ["ChangedAt", "SettingLabel", "SettingGroup", "Operation", "UpdatedByName"],
}


def source(actor, kind, action="read"):
    require_module(actor, "administration", action)
    if kind not in SOURCES:
        raise APIError("Registre non disponible.", "NOT_FOUND", 404)
    if kind in GLOBAL_ONLY and not actor.global_admin:
        raise APIError("Registre réservé à l’administration de la plateforme.", "PLATFORM_ADMIN_REQUIRED", 403)
    schema, name, pk, default_sort, date_field = SOURCES[kind]
    obj = model(name) if name.startswith("T_") else view(schema, name)
    # Les projections se limitent aux champs documentés de cette interface.
    obj = {**obj, "columns": [c for c in obj["columns"] if c["column_name"] in LABELS], "primaryKey": [pk]}
    if kind in {"utilisateurs", "profils"}:
        # La vue demeure la source de profil. Ses deux FK de présentation
        # manquantes sont jointes une seule fois, avant filtre/tri/pagination.
        obj["columns"] = [*obj["columns"],
            {"column_name": "IdRoleFk", "data_type": "integer", "is_nullable": "YES"},
            {"column_name": "Role", "data_type": "text", "is_nullable": "YES", "character_maximum_length": 255}]
        obj["portalProfile"] = True
        # Un seul registre utilisateur réunit désormais compte et affectation.
        # L'ancienne clé profils conserve exactement le même périmètre privé.
        fields={'MatriculeUser','ID_ServiceFk','ID_FonctionFk','Service','Fonction','DateEmbauche','DateFinEmploi','ObservationProfessionnelle','EstAffectable'}
        professional=view('systeme','V_User_Affectation')
        obj['columns']=[*obj['columns'],*[c for c in professional['columns'] if c['column_name'] in fields]]
        obj['portalProfessional']=True
    return obj, pk, default_sort, date_field


def source_sql(obj):
    if obj.get("portalProfile"):
        extra=''
        join=''
        if obj.get('portalProfessional'):
            fields=('MatriculeUser','ID_ServiceFk','ID_FonctionFk','Service','Fonction','DateEmbauche','DateFinEmploi','ObservationProfessionnelle','EstAffectable')
            extra=','+','.join('a.'+db.ident(name) for name in fields)
            join=' LEFT JOIN systeme."V_User_Affectation" a ON a."IdUser"=u."IdUser"'
        return '''(SELECT p.*,u."IdRoleFk",g."NomGenerique" AS "Role"'''+extra+'''
          FROM systeme."V_User_profil" p JOIN systeme."T_Utilisateurs" u ON u."IdUser"=p."IdUser"
          LEFT JOIN referentiel."T_Generique" g ON g."ID_Generique"=u."IdRoleFk"'''+join+') v'
    return db.qualified(obj["schema"], obj["name"]) + " v"


def scope_actor(actor, kind):
    # Les réglages et journaux de plateforme gardent leur portée explicite,
    # même si un administrateur global vient d’un module d’entreprise.
    return Actor(actor.row) if actor.global_admin and kind in GLOBAL_ONLY else actor


def parse_filters(raw):
    try:
        result = json.loads(raw) if isinstance(raw, str) else dict(raw or {})
    except (ValueError, TypeError):
        raise APIError("Filtres invalides.")
    if not isinstance(result, dict):
        raise APIError("Filtres invalides.")
    return result


def selection(actor, kind, raw, *, action="read", pk=None):
    if set(raw) - {"q", "filters", "sortBy", "sortDir", "take", "skip", "dateFrom", "dateTo", "timeZone", "columns", "selection"}:
        raise APIError("Critère non autorisé.")
    obj, identity, default_sort, date_field = source(actor, kind, action)
    available = {c["column_name"]: c for c in obj["columns"]}
    filters = parse_filters(raw.get("filters"))
    # Une valeur de réglage potentiellement secrète n’est pas un oracle de recherche.
    if set(filters) & {"SettingValue", "SettingValueJson", "OldData", "NewData"}:
        raise APIError("Colonne de filtre non autorisée.")
    if kind == "roles":
        if "ID_CategorieGeneriqueFk" in filters and filters["ID_CategorieGeneriqueFk"] != 39:
            raise APIError("Choisissez un rôle de la catégorie Rôle.")
        filters["ID_CategorieGeneriqueFk"] = 39
    sort = raw.get("sortBy") or default_sort
    direction = str(raw.get("sortDir", "desc" if date_field else "asc")).lower()
    if sort not in available or sort in {"OldData", "NewData", "SettingValue", "SettingValueJson"} or direction not in {"asc", "desc"}:
        raise APIError("Tri non autorisé.")
    query_obj = {**obj, "columns": [c for c in obj["columns"] if c["column_name"] not in {"OldData", "NewData", "SettingValue", "SettingValueJson"}]}
    where, values = predicate(query_obj, scope_actor(actor, kind), {"q": raw.get("q", ""), "filters": filters}, keys={identity: positive(pk)} if pk is not None else None)
    if kind == "localisations":
        # Cette vue LEFT JOIN inclut aussi les entreprises sans localisation.
        # Elles ne constituent pas des points identifiables/consultables.
        where += ' AND v."IdEntiteLocalisation" IS NOT NULL'
    date_limits = {}
    for key in ("dateFrom", "dateTo"):
        if raw.get(key):
            if not date_field:
                raise APIError("Ce registre ne propose pas de filtre de date.")
            try:
                date_limits[key] = date.fromisoformat(raw[key])
            except (ValueError, TypeError):
                raise APIError("Date de filtre invalide.")
    if len(date_limits) == 2 and date_limits["dateFrom"] > date_limits["dateTo"]:
        raise APIError("La date de début doit précéder la date de fin.")
    zone = document_zone(raw)
    for key, day in date_limits.items():
        if key == "dateTo":
            day += timedelta(days=1)
        value = datetime.combine(day, time.min)
        if available[date_field]["data_type"] == "timestamp with time zone":
            value = value.replace(tzinfo=zone)
        where += " AND v." + db.ident(date_field) + (">=%s" if key == "dateFrom" else "<%s")
        values.append(value)
    order = "v." + db.ident(sort) + " " + direction.upper() + " NULLS LAST"
    if sort != identity:
        order += ",v." + db.ident(identity) + " ASC"
    return obj, where, values, order, sort, direction


def capabilities(actor):
    rights = access_snapshot(actor)["modules"]["administration"]
    return {"canManage": actor.global_admin and not settings.DB_READ_ONLY,
            "canExport": rights["canExport"], "platformAdmin": actor.global_admin}


class AdminRegisterView(APIView):
    permission_classes = [IsERPAdmin]

    def get(self, request, kind, pk=None):
        raw = request.query_params.dict()
        obj, where, values, order, sort, direction = selection(request.user, kind, raw, pk=pk)
        fields = [c["column_name"] for c in obj["columns"]]
        sql_source = source_sql(obj)
        projection = ",".join("v." + db.ident(name) for name in fields)
        if pk is not None:
            row = db.one("SELECT " + projection + " FROM " + sql_source + " WHERE " + where, values)
            if row is None:
                raise APIError("Enregistrement introuvable dans votre périmètre.", "NOT_FOUND", 404)
            return ok(clean(row), meta=capabilities(request.user))
        take, skip = page(raw)
        scope, scope_values = scope_for(obj, scope_actor(request.user, kind))
        if kind == "roles":
            scope += ' AND v."ID_CategorieGeneriqueFk"=%s'
            scope_values.append(39)
        if kind == "localisations":
            scope += ' AND v."IdEntiteLocalisation" IS NOT NULL'
        total = db.one("SELECT count(*) AS n FROM " + sql_source + " WHERE " + scope, scope_values)["n"]
        count = db.one("SELECT count(*) AS n FROM " + sql_source + " WHERE " + where, values)["n"]
        rows = db.query("SELECT " + projection + " FROM " + sql_source + " WHERE " + where + " ORDER BY " + order + " LIMIT %s OFFSET %s", [*values, take, skip])
        return ok(clean(rows), meta={"columns": fields, "count": len(rows), "filteredCount": count, "totalCount": total,
            "take": take, "skip": skip, "sortBy": sort, "sortDir": direction, **capabilities(request.user)})


def admin_workbook(actor, kind, raw, file_format="xlsx"):
    from apps.core.table_preferences import export_keys
    from apps.core.tabular_exports import selected_scope, write_tabular
    raw = {**raw,"columns":json.dumps(export_keys(actor,"admin."+kind,raw))}
    obj, where, values, order, sort, direction = selection(actor, kind, raw, action="export")
    clause,params=selected_scope(raw,SOURCES[kind][2])
    where += clause; values = [*values,*params]
    available = {c["column_name"]: c for c in obj["columns"]}
    try:
        wanted = json.loads(raw["columns"]) if raw.get("columns") else DEFAULTS[kind]
    except (ValueError, TypeError):
        raise APIError("Colonnes d’export invalides.")
    if not isinstance(wanted, list) or not wanted or len(wanted) > 40 or any(not isinstance(k, str) or k not in available for k in wanted) or len(set(wanted)) != len(wanted):
        raise APIError("Colonnes d’export invalides.")
    fields = [{**available[name], "label": LABELS[name], **({"data_type": "text"} if name.lower().startswith("id") else {})} for name in wanted]
    zone = document_zone(raw)
    generated = datetime.now(zone)
    stream = SpooledTemporaryFile(max_size=8 * 1024 * 1024, mode="w+b")
    context = {"title": TITLES[kind], "scope": "Administration de la plateforme" if read_entity(actor) is None else "Entreprise autorisée",
        "generated": generated.strftime("%d/%m/%Y %H:%M"), "zone": str(zone), "tz": zone,
        "source": obj["schema"] + "." + obj["name"], "raw": raw, "filters": {}, "order": LABELS[sort] + " " + direction.upper()}
    criteria = parse_filters(raw.get("filters"))
    if criteria:
        context["scope"] += " — " + " ; ".join(LABELS[key] + " : " + ("Non renseigné" if value is None else "Oui" if value is True else "Non" if value is False else str(value)) for key, value in criteria.items())
    try:
        # Charger SettingKey protège aussi un export de SettingValue seul.
        projected = list(dict.fromkeys([*wanted, *(["SettingKey"] if "SettingKey" in available else [])]))
        with connection.cursor() as cursor:
            cursor.execute("SELECT " + ",".join("v." + db.ident(name) for name in projected) + " FROM " + source_sql(obj) + " WHERE " + where + " ORDER BY " + order + " LIMIT %s", [*values, MAX_EXPORT_ROWS + 1])
            def rows():
                while batch := cursor.fetchmany(500):
                    for values_row in batch:
                        row = clean(dict(zip(projected, values_row)))
                        yield {name: str(row[name]) if name.lower().startswith("id") and row.get(name) is not None else row.get(name) for name in wanted}
            count = write_tabular(stream, fields, rows(), context,file_format)
        stream.seek(0)
        return stream, count, "SauverNdeko_Administration_" + kind + "_" + generated.strftime("%Y-%m-%d") + ("_Selection." if raw.get("selection") is not None else ".") + file_format
    except Exception:
        stream.close()
        raise


class AdminExcelView(ExcelDownloadView):
    def get(self, request, kind):
        stream, count, filename = admin_workbook(request.user, kind, request.query_params.dict())
        response = FileResponse(stream, as_attachment=True, filename=filename, content_type=XLSX_MEDIA_TYPE)
        response["X-Export-Row-Count"] = str(count)
        response["Cache-Control"] = "no-store, private"
        return response


def scoped_count(actor, kind, raw=None):
    obj, where, values, *_ = selection(actor, kind, raw or {})
    return db.one("SELECT count(*) AS n FROM " + source_sql(obj) + " WHERE " + where, values)["n"]


class AdminOverviewView(APIView):
    permission_classes = [IsERPAdmin]

    def get(self, request):
        if set(request.query_params) - {"timeZone"}:
            raise APIError("Critère non autorisé.")
        actor = request.user
        require_module(actor, "administration")
        zone = document_zone(request.query_params.dict())
        now = datetime.now(zone)
        # Une seule photographie cohérente pour les compteurs et les listes.
        with transaction.atomic():
            metrics = {}
            unavailable = []
            for key, kind, filters in [
                ("users", "utilisateurs", {}), ("entities", "entites", {}),
                ("activeLicences", "licences", {"statut_licence": "Active"}),
                ("expiredLicences", "licences", {"ExpireeLicence": True}),
                ("auditEvents", "audit", {}), ("fkMappings", "correspondances", {"ValideFkCorrespondance": True}),
                ("settings", "parametres", {"ValideSetting": True}),
            ]:
                if kind in GLOBAL_ONLY and not actor.global_admin:
                    metrics[key] = None; unavailable.append(key); continue
                metrics[key] = scoped_count(actor, kind, {"filters": filters})
            if actor.global_admin:
                metrics["loginsToday"] = scoped_count(actor, "connexions", {"dateFrom": now.date().isoformat(), "dateTo": now.date().isoformat(), "filters": {"TypeLogin": "Connexion"}, "timeZone": str(zone)})
            else:
                metrics["loginsToday"] = None; unavailable.append("loginsToday")
            users = model("T_Utilisateurs")
            scope, scope_values = scope_for(users, actor, "u")
            roles = db.query('''SELECT u."IdRoleFk",COALESCE(g."NomGenerique",'Non renseigné') AS "Role",count(*) AS count
              FROM systeme."T_Utilisateurs" u LEFT JOIN referentiel."T_Generique" g ON g."ID_Generique"=u."IdRoleFk"
              WHERE ''' + scope + ' GROUP BY u."IdRoleFk",g."NomGenerique" ORDER BY count DESC,u."IdRoleFk"', scope_values)
            recent = []
            activity = []
            if actor.global_admin:
                recent = clean(db.query('SELECT * FROM systeme."V_Audit_log" ORDER BY "ChangedAt" DESC,"IdLog" DESC LIMIT 5'))
                start = datetime.combine(now.date() - timedelta(days=6), time.min, tzinfo=zone)
                login_days = {row["day"].isoformat(): row["n"] for row in db.query('SELECT ("DateLogin" AT TIME ZONE %s)::date AS day,count(*) AS n FROM systeme."V_Login_history" WHERE "DateLogin">=%s AND "TypeLogin"=%s GROUP BY 1', [str(zone), start, "Connexion"])}
                audit_days = {row["day"].isoformat(): row["n"] for row in db.query('SELECT "ChangedAt"::date AS day,count(*) AS n FROM systeme."V_Audit_log" WHERE "ChangedAt">=%s GROUP BY 1', [start.replace(tzinfo=None)])}
                activity = [{"date": (now.date() - timedelta(days=i)).isoformat(), "logins": login_days.get((now.date() - timedelta(days=i)).isoformat(), 0), "audit": audit_days.get((now.date() - timedelta(days=i)).isoformat(), 0)} for i in range(6, -1, -1)]
            obj, where, values, *_ = selection(actor, "licences", {"filters": {"statut_licence": "Active"}})
            expiring = clean(db.query("SELECT v.* FROM " + db.qualified(obj["schema"], obj["name"]) + ' v WHERE ' + where + ' AND v."DateFin"<%s ORDER BY v."DateFin",v."IdLicence" LIMIT 5', [*values, (now + timedelta(days=30)).replace(tzinfo=None)]))
        return ok({"generatedAt": now.isoformat(), "scope": {"kind": "global" if read_entity(actor) is None else "entity", "id": read_entity(actor)},
            "metrics": metrics, "unavailable": unavailable, "roleDistribution": roles, "activity": activity,
            "recentAudit": recent, "expiringLicences": expiring, **capabilities(actor)})


class AdminCSVView(ExcelDownloadView):
    from apps.logistique.excel import CSVFileRenderer
    from apps.core.responses import ExactJSONRenderer
    renderer_classes=[ExactJSONRenderer,CSVFileRenderer]

    def get(self,request,kind):
        stream,count,filename=admin_workbook(request.user,kind,request.query_params.dict(),file_format="csv")
        response=FileResponse(stream,as_attachment=True,filename=filename,content_type="text/csv; charset=utf-8")
        response["X-Export-Row-Count"]=str(count)
        response["Cache-Control"]="no-store, private"
        return response
