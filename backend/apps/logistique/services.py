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
    from apps.core.tenancy import require_entity,assert_document,validate_tiers
    if name in {'T_Article','T_Commande'}:
        require_entity(actor)
        if old:assert_document(actor,old)
        else:data['IdEntiteFk']=actor.organisation
    if name=='T_Commande':
        validate_tiers(actor,data,old)
        from .destinations import validate_destination
        validate_destination(data,old)
    effective = {**(old or {}), **data}
    if name in {'T_Article', 'T_Commande'}:
        from apps.core.reference_integration import validate_changed
        validate_changed(obj, data, old, actor)
    elif name == 'T_Reglements' and data.get('ID_ModeReglementFk') is not None and (not old or data['ID_ModeReglementFk'] != old.get('ID_ModeReglementFk')):
        from apps.core.reference_integration import validate_changed
        validate_changed(obj, {'ID_ModeReglementFk': data['ID_ModeReglementFk']}, old, actor)
    if name == "T_Commande":
        from .order_types import type_context
        type_context(effective.get('ID_TypeCmdFk'))
        from .document_rules import validate_header as validate_document
        validate_document(data,old,actor)
        from .currency import write_currency
        write_currency(data, old, actor=actor, table='T_Commande')
        effective = {**(old or {}), **data}
        if old and "ID_DeviseFk" in data and data["ID_DeviseFk"] != old.get("ID_DeviseFk"):
            linked = db.one('''SELECT EXISTS(SELECT 1 FROM logistique."T_CommandeDetail" WHERE "ID_CmdFk"=%s)
                OR EXISTS(SELECT 1 FROM logistique."T_Mouvement" WHERE "ID_cmdFk"=%s)
                OR EXISTS(SELECT 1 FROM logistique."T_Reglements" WHERE "CodeFactureFk"=%s) AS present''',
                [old["ID_Commande"],old["ID_Commande"],old.get("CodeFacture")])["present"]
            if linked or old.get("CodeFacture"):
                raise APIError("La devise du bon ne peut plus changer après une ligne, un mouvement ou une facture.", "CURRENCY_LOCKED", 409)
        if str(effective.get("CodeFacture") or "").strip() and not str((old or {}).get("CodeFacture") or "").strip():
            data["DateHeureAutoFacture"]=datetime.now(timezone.utc)
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
        # La précision explicite de l’unité est vérifiée par article_rules et PostgreSQL.
    if name == "T_Reglements":
        code = effective.get("CodeFactureFk")
        if not isinstance(code, str) or not code.strip():
            raise APIError("CodeFactureFk obligatoire.")
        invoice = get_record(model("T_Commande"), actor, {"CodeFacture": code}, lock=True)
        parent_currency = invoice.get("ID_DeviseFk")
        if parent_currency is None:
            raise APIError("La facture doit posséder une devise avant son règlement.", "CURRENCY_REQUIRED", 409)
        if ("ID_DeviseFk" in data and data["ID_DeviseFk"] != parent_currency) or (old and old.get("ID_DeviseFk") != parent_currency):
            raise APIError("Le règlement doit conserver la devise de sa facture.", "CURRENCY_MISMATCH", 409)
        data["ID_DeviseFk"] = parent_currency
        if effective.get("MontantRegle") is None or effective["MontantRegle"] <= 0:
            raise APIError("MontantRegle doit être positif.")


def mutate_line(actor, commande_id, body=None, article_id=None, operation="create"):
    db.ensure_writable()
    commande_id = positive(commande_id)
    body = dict(body or {})
    lots = body.pop("Lots", None)
    received = body.pop("_version", None)
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
        from apps.core.tenancy import assert_document
        assert_document(actor,commande)
        from .order_types import type_context, reject_order_lots
        order_kind = type_context(commande.get('ID_TypeCmdFk'))['kind']
        if order_kind == 'commande':
            reject_order_lots(lots)
            lots = None
        from .document_rules import assert_stock_editable
        from .stock_returns import is_historical_return_line
        assert_stock_editable(commande)
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
        from .lots import line_lots, sync_movement, validate_stock, unchanged as lots_unchanged
        previous_lots = line_lots(commande_id, positive(article_id)) if old else []
        if old:
            from .document_rules import check_revision
            check_revision({**old,"Lots":previous_lots},received,"ligne")
            if "ID_ArticleFk" in data and data["ID_ArticleFk"] != old["ID_ArticleFk"]:
                raise APIError("L’article d’une ligne existante doit être conservé.","LINE_IDENTITY_LOCKED",409)
        elif received is not None:raise APIError("Version inattendue à la création.")
        next_id = positive(effective.get("ID_ArticleFk"))
        if previous_lots and operation != "delete" and lots is None and (next_id != positive(article_id) or effective.get("QteCmdDetail") != old.get("QteCmdDetail")):
            raise APIError({"Lots":"Répartissez la nouvelle quantité entre les lots de cette ligne."}, "LOT_REQUIRED", 409)
        # Parent commande puis articles dans un ordre stable, comme les triggers existants.
        selected_article = None
        for current_id in sorted(
            {next_id, *([positive(article_id)] if article_id is not None else [])}
        ):
            article = get_record(
                model("T_Article"), actor, {"ID_Article": current_id}, lock=True
            )
            assert_document(actor,article)
            if current_id == next_id:
                selected_article = article
            if (
                operation != "delete"
                and current_id == next_id
                and article.get("ValideArticle") is False
                and not is_historical_return_line(commande_id,current_id)
            ):
                raise APIError("Article inactif.")
        if operation != "delete":
            if commande.get("ID_DeviseFk") is None:
                raise APIError("Choisissez la devise du bon avant ses lignes.", "CURRENCY_REQUIRED", 409)
            if selected_article.get("ID_DeviseFk") != commande.get("ID_DeviseFk") and (old is None or next_id != article_id) and data.get("PUCmdDetail") is None:
                raise APIError("Saisissez le prix de cette ligne dans la devise du bon.", "CURRENCY_PRICE_REQUIRED", 400)
            qty = effective.get("QteCmdDetail")
            from .quantities import for_unit
            qty=for_unit(qty,selected_article["ID_UniteFk"],"QteCmdDetail")
            price = effective.get("PUCmdDetail")
            if price is None:
                raise APIError({"PUCmdDetail":"Renseignez le prix unitaire dans la devise du bon."},"LINE_VALIDATION",400)
            if price < 0:
                raise APIError("PUCmdDetail ne peut pas être négatif.")
            from .document_rules import validate_line_total
            validate_line_total(commande_id, positive(article_id) if old else None, qty, price)
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
            try:
                unchanged=old is not None and effective.get("QteCmdDetail")==old.get("QteCmdDetail") and lots_unchanged(lots,previous_lots,effective["QteCmdDetail"])
                if not unchanged:sync_movement(next_id,movement["ID_Mvt"],lots,effective["QteCmdDetail"],actor=actor)
            except APIError as error:
                raise APIError({"Lots":str(error.detail)},error.default_code,error.status_code) from error
        # Les contraintes de lots sont différées : cibler la ligne avant de quitter sa transaction.
        if order_kind != 'commande':
            for current_id in sorted({next_id,*([positive(article_id)] if article_id is not None else [])}):validate_stock(current_id)
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
        from .reads import read_predicate
        if name == "V_ConsoMensuelle" and (params or {}).get("deviseId") not in (None,"","all"):
            name = "V_ConsoMensuelleDevise"
            obj = view("logistique", name)
        where, bind = read_predicate(obj, actor, params)
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
    from .reads import overview
    monetary = overview(actor, params or {})
    for key in ("montantTotalFacture", "montantTotalRegle", "montantRestant"):
        totals[key] = monetary["totals"][key]
    return {
        "totals": totals,
        "amountsByCurrency": monetary["amountsByCurrency"],
        "activeCurrency": monetary.get("activeCurrency"),
        "highlights": dict(zip(names, highlights)),
        "assumptions": {
            "procheRuptureMargeMax": 5,
            "peremptionWindowDays": 30,
            "currency": None,
        },
    }


def article_reference(x):
    return {
        "currencyId": x.get("ID_DeviseFk"),
        "currencyCode": x.get("DeviseCode"),
        "currencyLabel": x.get("DeviseLibelle"),
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
    from apps.core.field_references import reference_context, reference_options
    from .currency import currency_references
    currencies = currency_references(actor, table='T_Article')
    usd = [item for item in currencies if item["code"] == "USD"]
    if len(usd) != 1:
        raise APIError("Une devise USD active et unique doit être définie dans le référentiel.", "CURRENCY_CONFIGURATION", 503)
    result = {"currencies": currencies, "articleCurrencies": currencies,
              "commandeCurrencies": currency_references(actor, table='T_Commande'),
              "defaultCurrencyId": usd[0]["id"], "defaultCurrencyCode": "USD"}
    from apps.core.tenancy import read_entity
    entity = read_entity(actor)
    publication = db.one('SELECT "PartageArticlesPublicParDefaut" value FROM systeme."T_Entite" WHERE "IdEntite"=%s', [entity]) if entity else None
    result['defaultArticleVisibility'] = publication['value'] if publication else None
    result['defaultCommandeCurrencyId'] = next((item['id'] for item in result['commandeCurrencies'] if item['code'] == 'USD'), None)
    meta = {}
    rules = [
        ('articleTypes', 'T_Article', 'ID_TypeArticleFk', 'Type d’article'),
        ('articleCategories', 'T_Article', 'ID_CategorieArticleFk', 'Catégorie d’article'),
        ('articleUnits', 'T_Article', 'ID_UniteFk', 'Unité'),
        ('weightUnits', 'T_Article', 'ID_UnitePoidsFk', 'Unité de poids'),
        ('commandeTypes', 'T_Commande', 'ID_TypeCmdFk', 'Type de bon'),
        ('movementTypes', 'T_Mouvement', 'ID_TypeMvtFk', 'Type de mouvement'),
        ('commandeStatuses', 'T_Commande', 'ID_StatutCmdFk', 'Statut du bon'),
        ('commandeConditionPaiements', 'T_Commande', 'ID_ConditionPaiementFk', 'Condition de paiement'),
        ('commandeModesPaiement', 'T_Commande', 'ID_ModePaiementFk', 'Mode de paiement'),
        ('reglementModes', 'T_Reglements', 'ID_ModeReglementFk', 'Mode de règlement'),
        ('currencies', 'T_Article', 'ID_DeviseFk', 'Devise des articles'),
        ('commandeCurrencies', 'T_Commande', 'ID_DeviseFk', 'Devise du bon'),
    ]
    for key, table, column, field in rules:
        if key not in {'currencies', 'commandeCurrencies'}:
            result[key] = reference_options(actor, 'logistique', table, column)
        if key == 'weightUnits':
            result[key] = [item for item in result[key] if str(item.get('abbr') or '').strip().lower() in {'mg', 'g', 'kg', 't'}]
        context = reference_context(actor, 'logistique', table, column)
        meta[key] = {**context,
            "referenceKey": key,
            "sourceKey": "logistique." + key,
            "locked": True,
            'schemaName': 'logistique', 'tableName': table, 'fieldName': column,
            "categoryLabel": ' · '.join(context.get('categoryLabels', [])),
            "fieldLabel": field,
        }
    meta['articleCurrencies'] = meta['currencies']
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
    from .tiers import scope as tiers_scope
    tiers_where,tiers_args=tiers_scope(actor)
    clients=db.query('SELECT t."ID_Client" AS id,t."Nom" AS label,t."ID_TypeClientFk" AS "typeId",t."TypeClient" AS "typeLabel" FROM logistique."V_Client" t WHERE '+tiers_where+' AND t."Actif" ORDER BY t."Nom",t."ID_Client"',tiers_args)
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
