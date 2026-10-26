"""Exports XLSX des références partagées, depuis les vues autorisées."""
import json
from datetime import datetime
from tempfile import SpooledTemporaryFile

from django.db import connection
from django.http import FileResponse

from apps.core import db
from apps.core.module_access import require_module
from apps.core.registry import view
from apps.core.repository import PRIVATE, predicate
from apps.core.responses import APIError
from apps.logistique.excel import (
    ExcelDownloadView, MAX_EXPORT_ROWS, XLSX_MEDIA_TYPE, write_workbook,
)
from apps.logistique.table_queries import document_zone

SOURCES = {
    "categories": ("V_CategorieGenerique", "Catégories de référence", "ID_CategorieGenerique", "NomCategorieGenerique"),
    "valeurs": ("V_Generique", "Valeurs de référence", "ID_Generique", "NomGenerique"),
}
LABELS = {
    "ID_CategorieGenerique": "Identifiant catégorie",
    "ID_CategorieGeneriqueFk": "Identifiant catégorie",
    "ID_Generique": "Identifiant valeur",
    "NomCategorieGenerique": "Catégorie",
    "ModuleCategorieGenerique": "Modules associés",
    "ValideCategorieGenerique": "État",
    "NomGenerique": "Libellé",
    "AbrGenerique": "Abréviation ou code",
    "ObsGenerique": "Observations",
    "ValideGenerique": "État",
    "VisibleNiveau_2": "Visible au niveau 2",
    "VisibleNiveau_3": "Visible au niveau 3",
    "VisibleNiveau_4": "Visible au niveau 4",
    "VisibleNiveau_5": "Visible au niveau 5",
    "VisibleArticle": "Visible dans Articles",
    "VisibleCmd": "Visible dans Bons de stock",
    "VisibleFacture": "Visible dans Factures",
    "VisibleUsers": "Visible dans Utilisateurs",
    "VisibleVoie": "Visible dans Voies",
    "VisibleAll": "Visible partout",
}
DEFAULT_FIELDS = {
    "categories": ["NomCategorieGenerique", "ModuleCategorieGenerique", "ValideCategorieGenerique"],
    "valeurs": ["NomCategorieGenerique", "NomGenerique", "AbrGenerique", "ValideGenerique"],
}


def export_columns(obj, kind, raw):
    available = {
        col["column_name"]: col for col in obj["columns"]
        if col["column_name"] in LABELS and col["column_name"] not in PRIVATE
    }
    wanted = raw.get("columns")
    try:
        wanted = json.loads(wanted) if wanted else DEFAULT_FIELDS[kind]
    except (ValueError, TypeError):
        raise APIError("Colonnes d’export invalides.")
    if (
        not isinstance(wanted, list) or not wanted or len(wanted) > 30
        or any(not isinstance(key, str) or key not in available for key in wanted)
        or len(set(wanted)) != len(wanted)
    ):
        raise APIError("Colonnes d’export invalides.")
    # Les identifiants restent textuels dans Excel, même si PostgreSQL les stocke en entier.
    return [
        {**available[key], "label": LABELS[key],
         **({"data_type": "text"} if key.startswith("ID_") else {})}
        for key in wanted
    ]


def reference_workbook(actor, kind, raw):
    require_module(actor, "referentiels", "export")
    if set(raw) - {"q", "filters", "sortBy", "sortDir", "columns", "timeZone", "take", "skip"}:
        raise APIError("Critère non autorisé.")
    if kind not in SOURCES:
        raise APIError("Référentiel non disponible.", "NOT_FOUND", 404)
    name, label, primary_key, default_sort = SOURCES[kind]
    obj = view("referentiel", name)
    fields = export_columns(obj, kind, raw)
    available = {col["column_name"] for col in obj["columns"] if col["column_name"] not in PRIVATE}
    sort = raw.get("sortBy") or default_sort
    direction = str(raw.get("sortDir", "asc")).lower()
    if sort not in available or sort not in LABELS or direction not in {"asc", "desc"}:
        raise APIError("Tri non autorisé.")
    # Le même prédicat applique recherche et filtres avant pagination sur la liste et l’export.
    where, values = predicate(obj, actor, raw)
    order = "v." + db.ident(sort) + " " + direction.upper() + " NULLS LAST"
    if sort != primary_key:
        order += ",v." + db.ident(primary_key) + " ASC"
    zone = document_zone(raw)
    generated = datetime.now(zone)
    filters = raw.get("filters", {})
    if isinstance(filters, str):
        filters = json.loads(filters)
    scope = "Référentiel partagé"
    if filters:
        descriptions = [
            LABELS.get(key, key) + " : " + ("Non renseigné" if value is None else "Oui" if value is True else "Non" if value is False else str(value))
            for key, value in filters.items()
        ]
        scope += " — " + " ; ".join(descriptions)
    context = {
        "title": label, "scope": scope, "generated": generated.strftime("%d/%m/%Y %H:%M"),
        "zone": str(zone), "tz": zone, "source": "referentiel." + name,
        "raw": raw, "filters": {}, "order": LABELS[sort] + " " + direction.upper(),
    }
    stream = SpooledTemporaryFile(max_size=8 * 1024 * 1024, mode="w+b")
    try:
        with connection.cursor() as cursor:
            cursor.execute(
                "SELECT " + ",".join("v." + db.ident(field["column_name"]) for field in fields)
                + " FROM " + db.qualified(obj["schema"], obj["name"]) + " v WHERE " + where
                + " ORDER BY " + order + " LIMIT %s",
                [*values, MAX_EXPORT_ROWS + 1],
            )
            def rows():
                keys = [field["column_name"] for field in fields]
                while batch := cursor.fetchmany(500):
                    for values_row in batch:
                        yield {
                            key: str(value) if key.startswith("ID_") and value is not None else value
                            for key, value in zip(keys, values_row)
                        }
            count = write_workbook(stream, fields, rows(), context)
        stream.seek(0)
        filename = "SauverNdeko_Referentiels_" + kind + "_" + generated.strftime("%Y-%m-%d") + "_Complet.xlsx"
        return stream, count, filename
    except Exception:
        stream.close()
        raise


class ReferenceExcelView(ExcelDownloadView):
    """Conserve les erreurs JSON, même lorsque le navigateur demande un fichier Excel."""

    def get(self, request, kind):
        stream, count, filename = reference_workbook(request.user, kind, request.query_params.dict())
        response = FileResponse(stream, as_attachment=True, filename=filename, content_type=XLSX_MEDIA_TYPE)
        response["X-Export-Row-Count"] = str(count)
        response["Cache-Control"] = "no-store, private"
        return response
