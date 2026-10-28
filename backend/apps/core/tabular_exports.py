"""Sélection exacte et CSV compatible Excel, partagés par les trois portails."""
import csv
import io
import json
from datetime import date, datetime
from decimal import Decimal

from apps.core import db
from apps.core.responses import APIError, ExactEncoder


def selected_scope(raw, identity):
    """Le client fournit des identités, jamais une expression SQL ou un périmètre."""
    value = raw.get("selection")
    if value is None:
        return "", []
    try:
        items = json.loads(value) if isinstance(value, str) else value
    except (ValueError, TypeError):
        raise APIError("Sélection d’export invalide.")
    if not isinstance(items, list) or not items or len(items) > 10000:
        raise APIError("Sélection d’export vide ou trop volumineuse.")
    fields = [identity] if isinstance(identity, str) else list(identity)
    normalized = []
    for item in items:
        if len(fields) == 1:
            values = [item]
        elif isinstance(item, str):
            values = item.split(":")
        elif isinstance(item, dict) and set(item) == set(fields):
            values = [item[key] for key in fields]
        else:
            raise APIError("Identité de sélection invalide.")
        if len(values) != len(fields):
            raise APIError("Identité de sélection invalide.")
        if any(type(value) is bool or not str(value).isascii() or not str(value).isdigit()
               or int(value) <= 0 or int(value) > 9223372036854775807 for value in values):
            raise APIError("Identité de sélection invalide.")
        values = tuple(map(int, values))
        if values in normalized:
            raise APIError("Sélection d’export en doublon.")
        normalized.append(values)
    if len(fields) == 1:
        return " AND v." + db.ident(fields[0]) + "=ANY(%s)", [[row[0] for row in normalized]]
    clauses, params = [], []
    for item in normalized:
        clauses.append("(" + " AND ".join("v." + db.ident(field) + "=%s" for field in fields) + ")")
        params.extend(item)
    return " AND (" + " OR ".join(clauses) + ")", params


def csv_text(value):
    # Un texte source peut commencer par des espaces avant un signe de formule.
    # L'apostrophe empêche l'exécution ; XLSX conserve exactement le texte source.
    if value.lstrip(" \t\r\n").startswith(("=", "+", "-", "@")) or value.startswith(("\t", "\r", "\n")):
        return "'" + value
    return value


def write_csv(target, columns, rows, context):
    from apps.logistique.excel import MAX_EXPORT_ROWS
    target.write(b"\xef\xbb\xbf")
    wrapper = io.TextIOWrapper(target, encoding="utf-8", newline="", write_through=True)
    writer = csv.writer(wrapper, delimiter=";", quoting=csv.QUOTE_MINIMAL, lineterminator="\r\n")
    count = 0
    try:
        writer.writerow([field["label"] for field in columns])
        for row in rows:
            count += 1
            if count > MAX_EXPORT_ROWS:
                raise APIError("L’export dépasse 100 000 lignes. Affinez les filtres.", "EXPORT_TOO_LARGE", 413)
            values = []
            for field in columns:
                value = row.get(field["column_name"])
                if value is None:
                    values.append("")
                elif isinstance(value, bool):
                    values.append("Oui" if value else "Non")
                elif isinstance(value, (int, float, Decimal)) and field["data_type"] not in {"text", "character varying", "character"}:
                    number = Decimal(str(value))
                    if not number.is_finite():
                        raise APIError("Valeur numérique non exportable.")
                    values.append(format(number, "f").replace(".", ","))
                elif isinstance(value, datetime):
                    if value.tzinfo is not None:
                        value = value.astimezone(context["tz"]).replace(tzinfo=None)
                    values.append(value.strftime("%d/%m/%Y %H:%M:%S"))
                elif isinstance(value, date):
                    values.append(value.strftime("%d/%m/%Y"))
                else:
                    text = json.dumps(value, ensure_ascii=False, cls=ExactEncoder) if isinstance(value, (dict, list)) else str(value)
                    values.append(csv_text(text))
            writer.writerow(values)
        wrapper.flush()
    finally:
        wrapper.detach()  # FileResponse reste propriétaire du fichier temporaire.
    return count


def write_tabular(target, columns, rows, context, file_format="xlsx"):
    if file_format == "csv":
        return write_csv(target, columns, rows, context)
    if file_format != "xlsx":
        raise APIError("Format d’export non disponible.")
    from apps.logistique.excel import write_workbook
    return write_workbook(target, columns, rows, context)
