"""Devises du référentiel : validation et agrégats sans conversion implicite."""
import re
from apps.core import db
from apps.core.repository import positive
from apps.core.responses import APIError

MONETARY_KEYS = {"montantBons", "montantTotalFacture", "montantTotalRegle", "montantRestant"}
AMOUNT_FIELDS = {
    "PrixUnitaire", "ValeurAcquisition",
    "PUArticle", "PVArticle", "ValeurStockAchat", "MargeUnitaire", "MontantHT", "MontantTTC",
    "MontantRegleFacture", "MontantResteFacture", "TotalRegleReel", "ResteReel", "PUCmdDetail",
    "MontantLigne", "PUMvt", "MontantMvt", "MontantMvtSigned", "ValeurConsoMensuelle", "MontantRegle", "TotalRegle", "Reste",
}


def normalize_code(value):
    code = str(value or "").strip().upper()
    code = "EUR" if code == "EURO" else code
    if not re.fullmatch(r"[A-Z]{3}", code):
        raise APIError("Le référentiel des devises doit contenir un code de trois lettres.", "CURRENCY_CONFIGURATION", 503)
    return code


def currency_references(*, active=True):
    rows = db.query('''SELECT g."ID_Generique" AS id, g."NomGenerique" AS label,
        COALESCE(NULLIF(BTRIM(g."AbrGenerique"),''),g."NomGenerique") AS code
        FROM referentiel."T_Generique" g
        JOIN referentiel."T_CategorieGenerique" c ON c."ID_CategorieGenerique"=g."ID_CategorieGeneriqueFk"
        WHERE LOWER(BTRIM(c."NomCategorieGenerique"))='devise' '''
        + ('AND c."ValideCategorieGenerique" IS TRUE AND g."ValideGenerique" IS TRUE ' if active else '')
        + 'ORDER BY g."ID_Generique"')
    return sorted([{**row, "code": normalize_code(row["code"])} for row in rows], key=lambda row: (row["code"],row["id"]))


def default_currency():
    rows = [row for row in currency_references() if row["code"] == "USD"]
    if len(rows) != 1:
        raise APIError("Une devise USD active et unique doit être définie dans le référentiel.", "CURRENCY_CONFIGURATION", 503)
    return rows[0]


def validate_currency(value, *, unchanged=False):
    identifier = positive(value, "Devise")
    row = next((row for row in currency_references(active=not unchanged) if row["id"] == identifier), None)
    if not row:
        raise APIError("Choisissez une devise active dans la liste proposée.", "CURRENCY_VALIDATION", 400)
    return row


def write_currency(data, old):
    if old is None and "ID_DeviseFk" not in data:
        data["ID_DeviseFk"] = default_currency()["id"]
    value = data.get("ID_DeviseFk", (old or {}).get("ID_DeviseFk"))
    if value is None:
        raise APIError("Choisissez une devise.", "CURRENCY_VALIDATION", 400)
    unchanged = old is not None and value == old.get("ID_DeviseFk")
    if "ID_DeviseFk" in data or old is None:
        validate_currency(value, unchanged=unchanged)
    return value


def currency_filter(obj, value):
    if value in (None, "", "all"):
        return "", []
    columns = {column["column_name"] for column in obj["columns"]}
    if "ID_DeviseFk" not in columns:
        raise APIError("Le filtre de devise n’est pas disponible pour cette source.", "CURRENCY_SOURCE_UNAVAILABLE", 503)
    if value == "sans-devise":
        return 'v."ID_DeviseFk" IS NULL', []
    return 'v."ID_DeviseFk"=%s', [positive(value, "Devise")]


def currency_projection(obj):
    columns = {column["column_name"] for column in obj["columns"]}
    if "ID_DeviseFk" not in columns:
        raise APIError("La devise n’est pas disponible pour cette source.", "CURRENCY_SOURCE_UNAVAILABLE", 503)
    if {"DeviseCode", "DeviseLibelle"}.issubset(columns):
        return 'v."ID_DeviseFk",v."DeviseCode",v."DeviseLibelle"', ""
    return '''v."ID_DeviseFk",
        CASE UPPER(BTRIM(COALESCE(NULLIF(cu."AbrGenerique",''),cu."NomGenerique"))) WHEN 'EURO' THEN 'EUR'
        ELSE UPPER(BTRIM(COALESCE(NULLIF(cu."AbrGenerique",''),cu."NomGenerique"))) END,
        cu."NomGenerique"''', ' LEFT JOIN referentiel."T_Generique" cu ON cu."ID_Generique"=v."ID_DeviseFk" '


def amounts_by_currency(obj, source, where, values, expression):
    projection, join = currency_projection(obj)
    # Les expressions monétaires sont des constantes des services, jamais une saisie.
    identity, code, label = projection.split(",", 2) if not join else (None,None,None)
    if join:
        identity='v."ID_DeviseFk"'
        code='''CASE UPPER(BTRIM(COALESCE(NULLIF(cu."AbrGenerique",''),cu."NomGenerique"))) WHEN 'EURO' THEN 'EUR' ELSE UPPER(BTRIM(COALESCE(NULLIF(cu."AbrGenerique",''),cu."NomGenerique"))) END'''
        label='cu."NomGenerique"'
    rows = db.query("SELECT " + identity + " AS id," + code + " AS code," + label + " AS label,"
                    + expression + " AS value,COUNT(*) AS count FROM " + source + join + " WHERE " + where
                    + " GROUP BY " + identity + "," + code + "," + label + " ORDER BY code NULLS LAST,id NULLS LAST", values)
    return [{**row, "count": int(row["count"])} for row in rows]


def scalar_amount(groups):
    return 0 if not groups else groups[0]["value"] if len(groups) == 1 and groups[0].get("id") is not None else None


def currencies_in_scope(obj, source, where, values):
    groups = amounts_by_currency(obj, source, where, values, "COUNT(*)")
    return [{"id":row["id"], "code":row["code"], "label":row["label"], "count":row["count"]} for row in groups]
