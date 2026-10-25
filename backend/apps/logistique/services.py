"""La ligne commande déclenche le stock PostgreSQL ; aucun mouvement écrit en Python."""

import json, re
from pathlib import Path
from datetime import datetime, timezone
from decimal import Decimal
from django.db import transaction
from apps.core import db
from apps.core.registry import model, view, MODELS, VIEWS
from apps.core.permissions import scope_for
from apps.core.repository import get_record, coerce, positive, clean, audit, predicate
from apps.core.responses import APIError


def validate_header(obj, data, old, actor):
    name = obj["name"]
    effective = {**(old or {}), **data}
    rules = {
        "T_Article": {
            "ID_TypeArticleFk": 46,
            "ID_CategorieArticleFk": 40,
            "ID_UniteFk": 34,
        },
        "T_Commande": {
            "ID_TypeCmdFk": 64,
            "ID_StatutCmdFk": 28,
            "ID_ConditionPaiementFk": 37,
            "ID_ModePaiementFk": 36,
        },
        "T_Reglements": {"ID_ModeReglementFk": 36},
    }
    for field, category in rules.get(name, {}).items():
        if field in data and data[field] is not None:
            row = db.one(
                'SELECT "ID_CategorieGeneriqueFk" FROM referentiel."T_Generique" WHERE "ID_Generique"=%s',
                [data[field]],
            )
            if not row or row["ID_CategorieGeneriqueFk"] != category:
                raise APIError("Référence incompatible : " + field)
    if name == "T_Commande":
        if old is None:
            if not effective.get("ID_TypeCmdFk"):
                raise APIError("ID_TypeCmdFk obligatoire.")
            data.setdefault("DateCmd", datetime.now(timezone.utc))
        protected = {
            "MontantHT",
            "MontantTTC",
            "MontantRegleFacture",
            "MontantResteFacture",
        }
        for field in protected.intersection(data):
            received = data[field]
            previous = (old or {}).get(field)
            if (
                received not in (None, Decimal("0"))
                if previous is None
                else received != previous
            ):
                raise APIError("Les montants de commande sont calculés par PostgreSQL.")
            # Les formulaires historiques renvoient ces champs même sans modification.
            del data[field]
    if name == "T_Article":
        from .article_rules import validate
        validate(data, old, actor)
        for field in ["QteArticle", "PUArticle", "PVArticle", "QteMinArticle"]:
            if effective.get(field) is not None and effective[field] < 0:
                raise APIError(field + " ne peut pas être négatif.")
        if effective.get("QteArticle") is not None and effective["QteArticle"] != int(
            effective["QteArticle"]
        ):
            raise APIError("Stock entier requis par T_Mouvement.QteMvt.")
    if name == "T_Reglements":
        code = effective.get("CodeFactureFk")
        if not isinstance(code, str) or not code.strip():
            raise APIError("CodeFactureFk obligatoire.")
        get_record(model("T_Commande"), actor, {"CodeFacture": code}, lock=True)
        if effective.get("MontantRegle") is None or effective["MontantRegle"] <= 0:
            raise APIError("MontantRegle doit être positif.")


def mutate_line(actor, commande_id, body=None, article_id=None, operation="create"):
    db.ensure_writable()
    commande_id = positive(commande_id)
    body = dict(body or {})
    lots = body.pop("Lots", None)
    obj = model("T_CommandeDetail")
    allowed = {c["column_name"] for c in obj["columns"]} - {"ID_CmdFk"}
    if set(body) - allowed - {"ID_CmdFk"}:
        raise APIError("Champ de ligne non autorisé.")
    if "ID_CmdFk" in body and positive(body["ID_CmdFk"]) != commande_id:
        raise APIError("Déplacement entre commandes non autorisé sur cette route.")
    with transaction.atomic():
        commande = get_record(
            model("T_Commande"), actor, {"ID_Commande": commande_id}, lock=True
        )
        if db.one(
            "SELECT logistique.fn_commande_cloturee(%s) AS closed",
            [commande.get("StatusFacture")],
        )["closed"]:
            raise APIError("Commande clôturée.", "CLOSED_ORDER", 409)
        old = (
            get_record(
                obj,
                actor,
                {"ID_CmdFk": commande_id, "ID_ArticleFk": positive(article_id)},
            )
            if article_id is not None
            else None
        )
        data = {
            key: coerce(
                next(c for c in obj["columns"] if c["column_name"] == key), value
            )
            for key, value in body.items()
            if key in allowed
        }
        effective = {**(old or {}), **data}
        from .lots import line_lots, sync_movement
        previous_lots = line_lots(commande_id, positive(article_id)) if old else []
        next_id = positive(effective.get("ID_ArticleFk"))
        if previous_lots and operation != "delete" and lots is None and (next_id != positive(article_id) or effective.get("QteCmdDetail") != old.get("QteCmdDetail")):
            raise APIError("Répartissez la nouvelle quantité entre les lots de cette ligne.", "LOT_REQUIRED", 409)
        # Parent commande puis articles dans un ordre stable, comme les triggers existants.
        for current_id in sorted(
            {next_id, *([positive(article_id)] if article_id is not None else [])}
        ):
            article = get_record(
                model("T_Article"), actor, {"ID_Article": current_id}, lock=True
            )
            if (
                operation != "delete"
                and current_id == next_id
                and article.get("ValideArticle") is False
            ):
                raise APIError("Article inactif.")
        if operation != "delete":
            qty = effective.get("QteCmdDetail")
            if qty is None or qty <= 0 or qty > 2147483647 or qty != int(qty):
                raise APIError("QteCmdDetail doit être un entier strictement positif.")
            price = effective.get("PUCmdDetail")
            if price is not None and price < 0:
                raise APIError("PUCmdDetail ne peut pas être négatif.")
        if operation == "create":
            fields = ["ID_CmdFk", *data]
            row = db.one(
                'INSERT INTO logistique."T_CommandeDetail" ('
                + ",".join(db.ident(x) for x in fields)
                + ") VALUES ("
                + ",".join(["%s"] * len(fields))
                + ") RETURNING *",
                [commande_id, *data.values()],
            )
        elif operation == "delete":
            row = db.one(
                'DELETE FROM logistique."T_CommandeDetail" WHERE "ID_CmdFk"=%s AND "ID_ArticleFk"=%s RETURNING *',
                [commande_id, article_id],
            )
        elif next_id != article_id:
            db.query(
                'DELETE FROM logistique."T_CommandeDetail" WHERE "ID_CmdFk"=%s AND "ID_ArticleFk"=%s',
                [commande_id, article_id],
            )
            fields = list(effective)
            row = db.one(
                'INSERT INTO logistique."T_CommandeDetail" ('
                + ",".join(db.ident(x) for x in fields)
                + ") VALUES ("
                + ",".join(["%s"] * len(fields))
                + ") RETURNING *",
                list(effective.values()),
            )
        elif data:
            row = db.one(
                'UPDATE logistique."T_CommandeDetail" SET '
                + ",".join(db.ident(k) + "=%s" for k in data)
                + ' WHERE "ID_CmdFk"=%s AND "ID_ArticleFk"=%s RETURNING *',
                [*data.values(), commande_id, article_id],
            )
        else:
            row = old
        if operation != "delete" and lots is not None:
            movement = db.one('SELECT "ID_Mvt" FROM logistique."T_Mouvement" WHERE "ID_cmdFk"=%s AND "ID_ArticleFk"=%s',[commande_id,next_id])
            if not movement:raise APIError("Mouvement source introuvable.", "LOT_MOVEMENT_MISSING", 409)
            sync_movement(next_id,movement["ID_Mvt"],lots,effective["QteCmdDetail"])
        next_lots=line_lots(commande_id,next_id) if operation!="delete" else []
        audit(obj, operation.upper(), {**old,"Lots":previous_lots} if old else None, {**row,"Lots":next_lots}, actor)
        return clean({**row,"Lots":next_lots})


def scoped_query(sql, actor, params=None):
    values = []

    def replace(match):
        name = match.group(1)
        obj = VIEWS.get("logistique." + name) or MODELS.get(name)
        if obj is None:
            raise APIError("Source SQL non reconnue.", "INVALID_SOURCE", 500)
        where, bind = predicate(obj, actor, params)
        values.extend(bind)
        return (
            "(SELECT v.* FROM logistique." + db.ident(name) + " v WHERE " + where + ")"
        )

    text = re.sub(r'logistique\."([A-Za-z0-9_]+)"', replace, sql)
    return db.query(text, values)


def dashboard(actor, params=None):
    sqls = json.loads(
        Path(__file__).with_name("dashboard_queries.json").read_text(encoding="utf8")
    )
    results = [scoped_query(s, actor, params) for s in sqls]
    a, ah, c, ch, empty, alerts, total, paid, cover, conso, mvt, *highlights = results

    def row(rows):
        return rows[0] if rows else {}

    ah, ch, alerts, paid, cover, mvt = map(row, [ah, ch, alerts, paid, cover, mvt])
    totals = {
        "articles": row(a).get("count", 0),
        "commandes": row(c).get("count", 0),
        **ah,
        **ch,
        "commandesSansDetails": row(empty).get("count", 0),
        "alertesStock": alerts.get("alertes", 0),
        "prochesRupture": alerts.get("prochesRupture", 0),
        "montantTotalFacture": row(total).get("totalFacture", 0),
        "montantTotalRegle": paid.get("totalRegle", 0),
        "montantRestant": paid.get("totalReste", 0),
        "couvertureMoyenne": cover.get("couvertureMoyenne"),
        "couvertureMinimale": cover.get("couvertureMin"),
        "couvertureCritique": cover.get("couvertureCritique", 0),
        "consommationMensuelle": row(conso).get("consommationMois", 0),
        **mvt,
    }
    names = [
        "alertes",
        "consommation",
        "reglements",
        "commandesSansDetails",
        "audit",
        "commandesRecentes",
        "peremption",
        "echeances",
        "documentsManquants",
        "mouvementsRecents",
    ]
    return {
        "totals": totals,
        "highlights": dict(zip(names, highlights)),
        "assumptions": {
            "procheRuptureMargeMax": 5,
            "peremptionWindowDays": 30,
            "currency": None,
        },
    }


def article_reference(x):
    return {
        "id": x["ID_Article"],
        "label": x["NomArticle"],
        "code": x["CodeArticleInterne"] or x["RefArticle"],
        "reference": x["RefArticle"] or None,
        "typeId": x["ID_TypeArticleFk"],
        "categoryId": x["ID_CategorieArticleFk"],
        "unitId": x["ID_UniteFk"],
        "stock": x["QteArticle"],
        "minStock": x["QteMinArticle"],
        "purchasePrice": x["PUArticle"],
        "salePrice": x["PVArticle"],
    }


def references(actor):
    result = {}
    meta = {}
    rules = [
        ("articleTypes", 46, "Type produit", "Type d’article"),
        ("articleCategories", 40, "Categorie produit", "Categorie d’article"),
        ("articleUnits", 34, "Unites", "Unite"),
        ("commandeTypes", 64, "Type de commande", "Type de commande"),
        ("commandeStatuses", 28, "Statut", "Statut de commande"),
        (
            "commandeConditionPaiements",
            37,
            "Condition de paiement",
            "Condition de paiement",
        ),
        ("commandeModesPaiement", 36, "Mode paiement", "Mode de paiement"),
        ("reglementModes", 36, "Mode paiement", "Mode de reglement"),
    ]
    for key, category, label, field in rules:
        result[key] = db.query(
            'SELECT "ID_Generique" AS id,"NomGenerique" AS label,"AbrGenerique" AS abbr,"ID_CategorieGeneriqueFk" AS "categoryId" FROM referentiel."T_Generique" WHERE "ID_CategorieGeneriqueFk"=%s ORDER BY COALESCE(NULLIF(trim("AbrGenerique"),\'\'),"NomGenerique"),"ID_Generique"',
            [category],
        )
        meta[key] = {
            "referenceKey": key,
            "sourceKey": "logistique." + key,
            "locked": True,
            "categoryIds": [category],
            "categoryLabel": label,
            "fieldLabel": field,
        }
    uobj = model("T_Utilisateurs")
    where, values = scope_for(uobj, actor)
    users = db.query(
        'SELECT v."IdUser",v."NomUser",v."PrenomUser" FROM systeme."T_Utilisateurs" v WHERE '
        + where
        + ' ORDER BY v."NomUser",v."PrenomUser" LIMIT 200',
        values,
    )
    articles = scoped_query(
        'SELECT * FROM logistique."V_Article" ORDER BY "NomArticle","ID_Article" LIMIT 1000',
        actor,
    )
    factures = scoped_query(
        'SELECT DISTINCT "CodeFacture" AS code FROM logistique."T_Commande" WHERE "CodeFacture" IS NOT NULL AND trim("CodeFacture")<>\'\' ORDER BY "CodeFacture"',
        actor,
    )
    # Le modèle installé ne possède pas T_Personne : conserver les clients déjà utilisés,
    # filtrés par les commandes/règlements autorisés avant la jointure du libellé public.
    clients = scoped_query(
        'SELECT DISTINCT s.value AS id,COALESCE(NULLIF(trim(e."NomEntite"),\'\'),\'Client #\'||s.value::text) AS label FROM (SELECT "ID_ClientFk" AS value FROM logistique."T_Commande" UNION SELECT "ID_ClientFk" AS value FROM logistique."T_Reglements") s LEFT JOIN systeme."T_Entite" e ON e."IdEntite"=s.value WHERE s.value IS NOT NULL ORDER BY label,id',
        actor,
    )
    result["weightUnits"] = db.query('SELECT "ID_Generique" AS id,"NomGenerique" AS label,"AbrGenerique" AS abbr FROM referentiel."T_Generique" WHERE "ID_CategorieGeneriqueFk"=34 AND "ValideGenerique" IS TRUE AND lower(btrim("AbrGenerique")) IN (%s,%s,%s,%s) ORDER BY "NomGenerique"',["mg","g","kg","t"])
    result.update(
        users=[
            {"id": x["IdUser"], "label": (x["NomUser"] + " " + x["PrenomUser"]).strip()}
            for x in users
        ],
        clients=clients,
        articles=[article_reference(x) for x in articles],
        factures=[{"code": x["code"], "label": x["code"]} for x in factures],
        referenceMeta=meta,
    )
    return result
