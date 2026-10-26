"""Validation et concurrence du CRUD article ; aucun effet de stock dupliqué."""
import hashlib
import hmac
import json
from datetime import timedelta
from urllib.parse import urlsplit
from apps.core import db
from apps.core.responses import APIError, ExactEncoder

# Le stock varie avec les bons : il ne doit jamais être réécrit par l'édition d'identité.
VERSION_FIELDS = ("ID_DeviseFk","PoidsUnitaire","ID_UnitePoidsFk","InformationArticle","ID_Article", "NomArticle", "RefArticle", "CodeArticleInterne",
    "CodeArticleExterne", "ID_TypeArticleFk", "ID_CategorieArticleFk", "ID_UniteFk",
    "ID_UserFK", "PUArticle", "PVArticle", "QteMinArticle", "PhotoArticle",
    "ObsArticle", "ValideArticle", "DatePeremptionArticle",
    "DatePeremptionAlerteArticle", "NbreJoursAlerteArticle")

def revision(record):
    encoded = json.dumps({key: record.get(key) for key in VERSION_FIELDS},
        cls=ExactEncoder, sort_keys=True, ensure_ascii=False, separators=(",", ":"))
    return hashlib.sha256(encoded.encode("utf-8")).hexdigest()

def check_revision(record, received):
    if not isinstance(received, str) or not hmac.compare_digest(revision(record), received):
        raise APIError("Cet article a changé ou sa version n’est plus disponible. Rechargez la fiche avant d’enregistrer.", "ARTICLE_CONFLICT", 409)

def usage(record, actor):
    links = db.one('''SELECT
        EXISTS(SELECT 1 FROM logistique."T_CommandeDetail" WHERE "ID_ArticleFk"=%s) AS bons,
        EXISTS(SELECT 1 FROM logistique."T_Mouvement" WHERE "ID_ArticleFk"=%s) AS mouvements,
        EXISTS(SELECT 1 FROM analytics."T_Recherche" WHERE "ID_ArticleResultFk"=%s) AS recherches''',
        [record["ID_Article"]] * 3)
    if db.one("""SELECT to_regclass('logistique."T_DossierSuiviMembre"') IS NOT NULL AS ready""")["ready"]:
        links["dossiers"] = db.one('SELECT EXISTS(SELECT 1 FROM logistique."T_DossierSuiviMembre" WHERE "ID_ArticleFk"=%s) AS linked', [record["ID_Article"]])["linked"]
    else:
        links["dossiers"] = False
    reason = ("La suppression définitive est réservée à l’administration de la plateforme." if not actor.global_admin
        else "Désactivez d’abord l’article." if record["ValideArticle"]
        else "Un article avec un stock ne peut pas être supprimé." if record.get("QteArticle")
        else "Cet article possède un historique ou un classement. Conservez-le désactivé." if any(links.values())
        else "")
    if db.one("""SELECT to_regclass('logistique."T_LotArticle"') IS NOT NULL AS ready""")["ready"]:
        linked_lots=db.one('SELECT EXISTS(SELECT 1 FROM logistique."T_LotArticle" WHERE "ID_ArticleFk"=%s) AS present',[record["ID_Article"]])["present"]
        if linked_lots and actor.global_admin:reason="Cet article possède des lots. Conservez-le désactivé."
    return {"revision": revision(record), "canChangeUnit": not links["bons"] and not links["mouvements"],
        "canChangeCurrency": not links["bons"] and not links["mouvements"], "canDelete": not reason, "deleteReason": reason}

def validate(data, old, actor):
    from .currency import write_currency
    write_currency(data, old)
    errors = {}
    effective = {**(old or {}), **data}
    if old and "ID_DeviseFk" in data and data["ID_DeviseFk"] != old.get("ID_DeviseFk") and not usage(old, actor)["canChangeCurrency"]:
        errors["ID_DeviseFk"] = "La devise ne peut plus changer après un mouvement ou une ligne de bon."
    for key in ("NomArticle", "RefArticle", "CodeArticleInterne", "PhotoArticle", "ObsArticle", "InformationArticle"):
        if key in data and isinstance(data[key], str):
            data[key] = data[key].strip() or ("" if key == "NomArticle" else None)
            effective[key] = data[key]
    if not effective.get("NomArticle"):
        errors["NomArticle"] = "Renseignez le nom de l’article."
    for key, label in (("PUArticle", "Prix d’achat"), ("PVArticle", "Prix de vente"), ("QteArticle", "Stock"), ("QteMinArticle", "Seuil minimum")):
        value = effective.get(key)
        if value is not None and value < 0:
            errors[key] = label + " : la valeur doit être positive ou nulle."
    stock = effective.get("QteArticle")
    from .quantities import for_unit
    for key in ("QteArticle","QteMinArticle"):
        if effective.get(key) is not None:
            try:for_unit(effective[key],effective.get("ID_UniteFk"),key,zero=True)
            except APIError as error:errors[key]=str(error.detail.get(key,error.detail)) if isinstance(error.detail,dict) else str(error.detail)
    if old:
        if "QteArticle" in data:
            if data["QteArticle"] != old["QteArticle"]:
                errors["QteArticle"] = "Le stock se met à jour avec les bons de stock."
            else:
                del data["QteArticle"]
        if "ID_UserFK" in data:
            if data["ID_UserFK"] != old.get("ID_UserFK"):
                errors["ID_UserFK"] = "Le responsable d’origine doit être conservé."
            else:
                del data["ID_UserFK"]
        if "ID_UniteFk" in data and data["ID_UniteFk"] != old.get("ID_UniteFk") and not usage(old, actor)["canChangeUnit"]:
            errors["ID_UniteFk"] = "L’unité ne peut plus changer après un mouvement ou une ligne de bon."
    for key, category, label in (("ID_TypeArticleFk", 46, "type"), ("ID_CategorieArticleFk", 40, "catégorie"), ("ID_UniteFk", 34, "unité")):
        value = effective.get(key)
        if not old and value is None:
            errors[key] = "Choisissez une " + label + "." if key != "ID_TypeArticleFk" else "Choisissez un type."
        if key in data and value is not None and (not old or value != old.get(key)):
            row = db.one('SELECT "ValideGenerique","ID_CategorieGeneriqueFk" FROM referentiel."T_Generique" WHERE "ID_Generique"=%s', [value])
            if not row or row["ID_CategorieGeneriqueFk"] != category or row["ValideGenerique"] is not True:
                errors[key] = "Choisissez une valeur active dans la liste proposée."
    days = effective.get("NbreJoursAlerteArticle")
    expiry = effective.get("DatePeremptionArticle")
    if days is not None and (days < 0 or days > 36500):
        errors["NbreJoursAlerteArticle"] = "Le délai doit être compris entre 0 et 36 500 jours."
    if {"DatePeremptionArticle", "NbreJoursAlerteArticle", "DatePeremptionAlerteArticle"}.intersection(data):
        try:
            data["DatePeremptionAlerteArticle"] = expiry - timedelta(days=days) if expiry is not None and days is not None and 0 <= days <= 36500 else None
        except (OverflowError, ValueError):
            errors["NbreJoursAlerteArticle"] = "Le délai dépasse la plage de dates autorisée."
    info=effective.get("InformationArticle")
    if info is not None and len(info)>20000:errors["InformationArticle"]="Limitez les informations complémentaires à 20 000 caractères."
    weight=effective.get("PoidsUnitaire");weight_unit=effective.get("ID_UnitePoidsFk")
    if (weight is None)!=(weight_unit is None):
        errors["PoidsUnitaire"]="Renseignez le poids et son unité, ou laissez les deux vides."
    if weight is not None and weight<0:errors["PoidsUnitaire"]="Le poids doit être positif ou nul."
    if weight_unit is not None:
        unit=db.one('SELECT "AbrGenerique","ID_CategorieGeneriqueFk","ValideGenerique" FROM referentiel."T_Generique" WHERE "ID_Generique"=%s',[weight_unit])
        if not unit or unit["ID_CategorieGeneriqueFk"]!=34 or str(unit["AbrGenerique"] or "").strip().lower() not in {"mg","g","kg","t"}:
            errors["ID_UnitePoidsFk"]="Choisissez une unité de masse."
    if effective.get("CodeArticleExterne") is not None and effective["CodeArticleExterne"]<1:errors["CodeArticleExterne"]="Le code externe doit être supérieur à zéro."
    if old is None:
        from datetime import datetime, timezone
        data["DateHeureAuto"]=datetime.now(timezone.utc)
    photo = effective.get("PhotoArticle")
    from .photos import stored_photo
    if photo and not stored_photo(photo):
        try:
            parsed = urlsplit(photo)
            if parsed.scheme not in {"https", "http"} or not parsed.netloc or parsed.username or parsed.password:
                errors["PhotoArticle"] = "Utilisez une adresse http ou https sans identifiants."
        except ValueError:
            errors["PhotoArticle"] = "Renseignez une adresse d’image valide."
    if errors:
        raise APIError(errors, "ARTICLE_VALIDATION", 400)

def assert_deletable(record, actor):
    meta = usage(record, actor)
    if not meta["canDelete"]:
        raise APIError(meta["deleteReason"], "ARTICLE_IN_USE", 409)
