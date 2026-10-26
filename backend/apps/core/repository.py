"""Lectures communes depuis le registre autorisé ; écritures transactionnelles."""

import json, math, re
from decimal import Decimal, InvalidOperation
from datetime import datetime, date
from django.db import transaction, IntegrityError
from django.contrib.auth.hashers import make_password
from . import db
from .registry import model, MODELS
from .permissions import scope_for, check_global_write
from .responses import APIError

PRIVATE = {"MotdepasseUser", "password", "Password", "MotDePasse"}
READONLY = {"T_Mouvement", "T_Login", "T_Audit_Log", "T_Paiement_Archive", "T_RetourBon", "T_Facture", "T_FactureLigne"}


def secret_key(value):
    """Reconnaît les clés sensibles sans dépendre de leur casse ou séparateurs."""
    key = re.sub(r"[^a-z0-9]", "", str(value).lower())
    return (key in {"token", "authorization", "credentials", "credential", "secret"}
            or key.endswith("secret")
            or any(word in key for word in ("password", "motdepasse", "privatekey", "apikey", "accesstoken", "refreshtoken", "idtoken")))


def clean(value):
    if isinstance(value, dict):
        result = {}
        protected_setting = secret_key(value.get("SettingKey", ""))
        for key, item in value.items():
            if key in PRIVATE or secret_key(key):
                continue
            if protected_setting and key in {"SettingValue", "SettingValueJson"}:
                result[key] = "[Masqué]"
                continue
            # Certains anciens journaux ont enregistré un objet JSON sous forme
            # de chaîne dans JSONB : l’inspecter avant de masquer récursivement.
            if key in {"OldData", "NewData", "SettingValueJson"} and isinstance(item, str):
                try:
                    decoded = json.loads(item)
                    if isinstance(decoded, (dict, list)):
                        item = decoded
                except (ValueError, TypeError):
                    pass
            result[key] = clean(item)
        return result
    if isinstance(value, list):
        return [clean(x) for x in value]
    return value


def positive(value, label="identifiant"):
    if type(value) is bool or not re.fullmatch(r"[1-9][0-9]*", str(value)):
        raise APIError(label + " invalide.")
    n = int(value)
    if n > 2147483647:
        raise APIError(label + " hors limites.")
    return n


def page(params):
    try:
        take = int(params.get("take", 25))
        skip = int(params.get("skip", 0))
    except (ValueError, TypeError):
        raise APIError("Pagination invalide.")
    if take <= 0 or skip < 0:
        raise APIError("Pagination invalide.")
    return min(take, 500), skip


def coerce(col, value):
    if value is None:
        if col["is_nullable"] != "YES":
            raise APIError(col["column_name"] + " obligatoire.")
        return None
    t = col["data_type"]
    name = col["column_name"]
    if t in {"integer", "smallint", "bigint"}:
        if type(value) is bool or not re.fullmatch(r"-?[0-9]+", str(value)):
            raise APIError(name + " doit être entier.")
        value = int(value)
        bits = {"smallint": 16, "integer": 32, "bigint": 64}[t]
        if not -(2 ** (bits - 1)) <= value < 2 ** (bits - 1):
            raise APIError(name + " hors limites.")
    elif t == "numeric":
        if type(value) is bool:
            raise APIError(name + " invalide.")
        try:
            value = Decimal(str(value))
        except (InvalidOperation, ValueError):
            raise APIError(name + " invalide.")
        if not value.is_finite():
            raise APIError(name + " invalide.")
        scale = col["numeric_scale"] or 0
        precision = col["numeric_precision"] or 38
        if value.as_tuple().exponent < -scale or abs(value) >= Decimal(10) ** (
            precision - scale
        ):
            raise APIError(name + " dépasse la précision autorisée.")
    elif t == "boolean":
        if value in ("true", "false"):
            value = value == "true"
        if type(value) is not bool:
            raise APIError(name + " doit être booléen.")
    elif t.startswith("timestamp") or t == "date":
        if not isinstance(value, (str, datetime, date)):
            raise APIError(name + " invalide.")
        try:
            value = (
                (
                    date.fromisoformat(value)
                    if t == "date"
                    else datetime.fromisoformat(value.replace("Z", "+00:00"))
                )
                if isinstance(value, str)
                else value
            )
        except ValueError:
            raise APIError(name + " doit être une date ISO.")
    elif t in {"jsonb", "json"}:
        from psycopg.types.json import Jsonb

        value = Jsonb(value)
    else:
        if not isinstance(value, str):
            raise APIError(name + " doit être un texte.")
        if (
            col["character_maximum_length"]
            and len(value) > col["character_maximum_length"]
        ):
            raise APIError(name + " trop long.")
    return value


def predicate(obj, actor, params=None, keys=None):
    params = params or {}
    columns = {c["column_name"]: c for c in obj["columns"]}
    scope, values = scope_for(obj, actor)
    clauses = [scope]
    if keys:
        for key, value in keys.items():
            if key not in columns:
                raise APIError("Clé invalide.")
            clauses.append("v." + db.ident(key) + "=%s")
            values.append(coerce(columns[key], value))
    raw = params.get("filters", {})
    try:
        filters = json.loads(raw) if isinstance(raw, str) else dict(raw)
    except (ValueError, TypeError):
        raise APIError("Filtres JSON invalides.")
    if not isinstance(filters, dict):
        raise APIError("Filtres invalides.")
    aliases = {
        "article": ["ID_Article", "ID_ArticleFk"],
        "commande": ["ID_Commande", "ID_CmdFk", "ID_cmdFk"],
        "typeId": ["ID_TypeArticleFk", "ID_TypeCmdFk", "ID_TypeMvtFk"],
        "categorieId": ["ID_CategorieArticleFk"],
        "deviseId": ["ID_DeviseFk"],
        "statutId": ["ID_StatutCmdFk"],
        "client": ["ID_ClientFk"],
        "userId": ["ID_UserFK", "ID_UserFk"],
        "codeFacture": ["CodeFactureFk", "CodeFacture"],
        "code": ["CodeCmd"],
        "categorie": ["ID_CategorieGeneriqueFk"],
    }
    for alias, choices in aliases.items():
        if params.get(alias) not in (None, ""):
            if alias == "deviseId" and params[alias] == "all":
                continue
            found = next((c for c in choices if c in columns), None)
            if found:
                filters[found] = (None if params[alias] == "sans-devise" else positive(params[alias], "Devise")) if alias == "deviseId" else params[alias]
            elif alias == "deviseId":
                raise APIError("Le filtre de devise n’est pas disponible pour cette liste.")
    for key, value in filters.items():
        if key not in columns or key in PRIVATE:
            raise APIError("Colonne de filtre non autorisée.")
        if value is None:
            clauses.append("v." + db.ident(key) + " IS NULL")
        else:
            clauses.append("v." + db.ident(key) + "=%s")
            values.append(coerce(columns[key], value))
    q = str(params.get("q", "")).strip()
    if len(q) > 300:
        raise APIError("Recherche trop longue.")
    search = [
        c["column_name"]
        for c in obj["columns"]
        if c["data_type"] in {"text", "character varying", "character"}
        and c["column_name"] not in PRIVATE
    ]
    if q and search:
        clauses.append(
            "(" + " OR ".join("v." + db.ident(c) + " ILIKE %s" for c in search) + ")"
        )
        values.extend(["%" + q + "%"] * len(search))
    datefield = next(
        (f for f in ["DateCmd", "DateMvt", "DateReglement", "Mois"] if f in columns),
        None,
    )
    if datefield:
        for k, operator in [("dateFrom", ">="), ("dateTo", "<")]:
            if params.get(k):
                try:
                    value = date.fromisoformat(params[k])
                except (ValueError, TypeError):
                    raise APIError("Date de filtre invalide.")
                clauses.append(
                    "v."
                    + db.ident(datefield)
                    + operator
                    + ("%s::date + INTERVAL '1 day'" if k == "dateTo" else "%s::date")
                )
                values.append(value)
    if (
        str(params.get("criticalOnly", "")).lower() in {"true", "1"}
        and "Marge" in columns
    ):
        clauses.append('v."Marge"<=0')
    if str(params.get("resteOnly", "")).lower() in {"true", "1"} and "Reste" in columns:
        clauses.append('v."Reste">0')
    return " AND ".join("(" + c + ")" for c in clauses), values


def listing(obj, actor, params=None):
    params = params or {}
    take, skip = page(params)
    columns = [
        c["column_name"] for c in obj["columns"] if c["column_name"] not in PRIVATE
    ]
    sort = params.get("sortBy") or (obj.get("primaryKey") or columns)[0]
    if sort not in columns:
        raise APIError("Tri non autorisé.")
    direction = str(params.get("sortDir", "desc")).lower()
    if direction not in {"asc", "desc"}:
        raise APIError("Sens du tri invalide.")
    where, values = predicate(obj, actor, params)
    scope, scopevalues = scope_for(obj, actor)
    source = db.qualified(obj["schema"], obj["name"]) + " v"
    total = db.one(
        "SELECT count(*) AS n FROM " + source + " WHERE " + scope, scopevalues
    )["n"]
    count = db.one("SELECT count(*) AS n FROM " + source + " WHERE " + where, values)[
        "n"
    ]
    order = "v." + db.ident(sort) + " " + direction.upper() + " NULLS LAST"
    # Clé secondaire stable pour une pagination reproductible.
    for pk in obj.get("primaryKey", []):
        if pk != sort:
            order += ",v." + db.ident(pk) + " ASC"
    rows = db.query(
        "SELECT "
        + ",".join("v." + db.ident(c) for c in columns)
        + " FROM "
        + source
        + " WHERE "
        + where
        + " ORDER BY "
        + order
        + " LIMIT %s OFFSET %s",
        [*values, take, skip],
    )
    return clean(rows), {
        "columns": columns,
        "count": len(rows),
        "filteredCount": count,
        "totalCount": total,
        "take": take,
        "skip": skip,
        "sortBy": sort,
        "sortDir": direction,
    }


def get_record(obj, actor, keys, lock=False):
    where, values = predicate(obj, actor, keys=keys)
    row = db.one(
        "SELECT v.* FROM "
        + db.qualified(obj["schema"], obj["name"])
        + " v WHERE "
        + where
        + (" FOR NO KEY UPDATE OF v" if lock else ""),
        values,
    )
    if row is None:
        raise APIError("Objet introuvable dans votre périmètre.", "NOT_FOUND", 404)
    return row


def payload(obj, body, actor, creating=False):
    if not isinstance(body, dict):
        raise APIError("Objet JSON attendu.")
    columns = {c["column_name"]: c for c in obj["columns"]}
    result = {}
    for key, value in body.items():
        if key not in columns:
            raise APIError("Champ non autorisé : " + key)
        if (
            key in obj["primaryKey"]
            or key.endswith("_tsv")
            or columns[key]["is_identity"] == "YES"
        ):
            raise APIError("Champ calculé ou identifiant non modifiable : " + key)
        if obj["schema"]=="logistique" and obj["name"] in {"T_Article","T_Commande"} and key=="IdEntiteFk":
            from .tenancy import require_entity
            if value is not None and coerce(columns[key],value)!=require_entity(actor):raise APIError("Entreprise propriétaire non modifiable.","ENTITY_MISMATCH",403)
            continue
        if key in {"ID_UserFK", "ID_UserFk"} and not actor.global_admin:
            if coerce(columns[key], value) != actor.pk:
                raise APIError(
                    "Propriétaire non autorisé.", "PRIVILEGE_ESCALATION", 403
                )
            # React transmet l’éditeur connecté : conserver le créateur existant.
            continue
        if (
            key
            in {
                "Is_Admin",
                "Is_staff",
                "IdRoleFk",
                "IdEntiteFk",
                "ID_UserFK",
                "ID_UserFk",
            }
            and not actor.global_admin
        ):
            raise APIError(
                "Modification de propriété ou de privilège interdite.",
                "PRIVILEGE_ESCALATION",
                403,
            )
        result[key] = coerce(columns[key], value)
    if obj["name"] == "T_Utilisateurs" and "MotdepasseUser" in result:
        if len(result["MotdepasseUser"]) < 12:
            raise APIError("Le mot de passe doit comporter au moins 12 caractères.")
        result["MotdepasseUser"] = make_password(result["MotdepasseUser"])
    if creating:
        if obj['schema']=='logistique' and obj['name'] in {'T_Article','T_Commande'}:
            from .tenancy import require_entity
            result['IdEntiteFk']=require_entity(actor)
        if "ID_UserFK" in columns:
            result["ID_UserFK"] = actor.pk
        if "ID_UserFk" in columns:
            result["ID_UserFk"] = actor.pk
        if "IdEntiteFk" in columns and not actor.global_admin:
            result["IdEntiteFk"] = actor.organisation
    for relation in obj["relations"]:
        if obj['schema']=='logistique' and obj['name'] in {'T_Article','T_Commande'} and relation['from'] in [['ID_UserFK'],['ID_UserFk']]:
            continue  # Auteur authentifié à la création, immuable ensuite ; indépendant de l'entreprise active.
        if (
            len(relation["from"]) == 1
            and relation["from"][0] in result
            and result[relation["from"][0]] is not None
            and relation["target"] in MODELS
        ):
            get_record(
                model(relation["target"]),
                actor,
                {relation["to"][0]: result[relation["from"][0]]},
            )
    return result


def audit(obj, operation, old=None, new=None, actor=None):
    from psycopg.types.json import Jsonb
    from .responses import ExactEncoder

    def packed(data):
        if data is None:
            return None
        safe = clean(data)
        if actor is not None:
            safe = (
                {**safe, "_actor": {"IdUser": actor.pk}}
                if isinstance(safe, dict)
                else {"rows": safe, "_actor": {"IdUser": actor.pk}}
            )
        return Jsonb(json.loads(json.dumps(safe, cls=ExactEncoder)))

    db.query(
        'INSERT INTO systeme."T_Audit_Log" ("TableName","Operation","OldData","NewData","IdEntiteFk") VALUES (%s,%s,%s,%s,%s)',
        [
            (
                obj["name"]
                if obj["name"] in {"T_Fk_Correspondance", "T_Admin_UI_Setting"}
                else obj["schema"] + "." + obj["name"]
            ),
            operation,
            packed(old),
            packed(new),
            actor.organisation if actor else None,
        ],
    )


def set_admin_actor(actor):
    """Contexte transactionnel transmis aux déclencheurs d’administration.

    La connexion ne porte aucune identité durable : SET LOCAL disparaît au
    COMMIT/ROLLBACK. La base vérifie que le compte existe avant de l’auditer.
    """
    db.query("SELECT set_config('systeme.actor_user_id',%s,true)", [str(actor.pk)])


@transaction.atomic
def _mutate(name, actor, body=None, keys=None, operation="create", hard=False):
    db.ensure_writable()
    if name=="T_Reglements":
        if hard and not actor.global_admin:raise APIError("Suppression définitive réservée à un administrateur global.","GLOBAL_ADMIN_REQUIRED",403)
        from apps.logistique.payments import mutate_payment
        return mutate_payment(actor,body,keys,operation)
    if body is not None and not isinstance(body, dict):
        raise APIError("Objet JSON attendu.")
    obj = model(name)
    check_global_write(obj, actor)
    if name in READONLY:
        raise APIError("Registre en lecture seule.", "READ_ONLY_REGISTER", 405)
    if name in {"T_Fk_Correspondance", "T_Admin_UI_Setting"}:
        if isinstance(body, dict):
            # Ces valeurs sont produites par PostgreSQL ; le navigateur ne
            # peut ni antidater une modification ni choisir son auteur.
            body = {key: value for key, value in body.items()
                    if key not in {"UpdatedAt", "UpdatedByUserFk", "CreatedAt"}}
    old = get_record(obj, actor, keys, lock=True) if keys else None
    if name == "T_Admin_UI_Setting" and not old and isinstance(body, dict) and secret_key(body.get("SettingKey", "")):
        raise APIError("Ce secret se configure dans le paramétrage privé du serveur.", "SETTING_SECRET_PRIVATE", 409)
    if name == "T_Admin_UI_Setting" and old:
        if secret_key(old.get("SettingKey", "")) and set(body or {}) & {"SettingValue", "SettingValueJson"}:
            raise APIError("Ce secret se configure dans le paramétrage privé du serveur.", "SETTING_SECRET_PRIVATE", 409)
        if old.get("IsEditable") is not True:
            raise APIError("Ce paramètre est protégé et reste en consultation.", "SETTING_PROTECTED", 409)
        if old.get("IsSystem") is True:
            if operation == "delete":
                raise APIError("Un paramètre système doit être conservé.", "SETTING_PROTECTED", 409)
            identity_fields = {"SettingKey", "SettingType", "SettingScope", "ScopeValue", "IsEditable", "IsSystem"}
            if any(key in (body or {}) and body[key] != old.get(key) for key in identity_fields):
                raise APIError("L’identité et les protections de ce paramètre système sont conservées.", "SETTING_PROTECTED", 409)
    if name in {"T_Article","T_Commande"}:
        from .tenancy import require_entity,assert_document
        require_entity(actor)
        if old:
            assert_document(actor,old)
            body=dict(body or {})
            for creator in ('ID_UserFK','ID_UserFk'):
                if creator in body:
                    if str(body[creator])!=str(old.get(creator)):raise APIError('L’auteur initial est conservé.','AUTHOR_IMMUTABLE',409)
                    del body[creator]
    if name == "T_Commande":
        from apps.logistique.document_rules import check_revision, assert_deletable, protect_command_code
        if not isinstance(body or {},dict):raise APIError("Objet JSON attendu.")
        body=dict(body or {})
        received=body.pop("_version",None)
        protect_command_code(body,old)
        from apps.logistique.invoices import protect_invoice_fields
        protect_invoice_fields(body,old)
        if old:check_revision(old,received)
        elif received is not None:raise APIError("Version inattendue à la création.")
        if operation == "delete":
            db.one('SELECT "ID_Commande" FROM logistique."T_Commande" WHERE "ID_Commande"=%s FOR UPDATE',[old["ID_Commande"]])
            assert_deletable(old,actor)
    if name == "T_Article":
        from apps.logistique.article_rules import check_revision, assert_deletable
        if not isinstance(body or {}, dict):
            raise APIError("Objet JSON attendu.")
        body = dict(body or {})
        received = body.pop("_version", None)
        if old:
            check_revision(old, received)
        elif received is not None:
            raise APIError("Version inattendue à la création.")
        if operation == "delete" and hard:
            if not actor.global_admin:raise APIError("Suppression définitive réservée à un administrateur global.", "GLOBAL_ADMIN_REQUIRED", 403)
            assert_deletable(old, actor)
    if name == "T_Commande" and old:
        locked = db.one(
            "SELECT logistique.fn_commande_cloturee(%s) AS closed",
            [old.get("StatusFacture")],
        )["closed"]
        if locked:
            raise APIError("Commande clôturée.", "CLOSED_ORDER", 409)
    soft = {
        "T_Article": "ValideArticle",
        "T_Utilisateurs": "ValideUser",
        "T_Entite": "ValideEntite",
        "T_Licence": "ValideLicence",
        "T_Generique": "ValideGenerique",
        "T_CategorieGenerique": "ValideCategorieGenerique",
    }
    if operation == "delete" and name in soft and not hard:
        operation = "update"
        body = {soft[name]: False}
    if operation == "delete" and hard and not actor.global_admin:
        raise APIError(
            "Suppression définitive réservée à un administrateur global.",
            "GLOBAL_ADMIN_REQUIRED",
            403,
        )
    data = (
        payload(obj, body or {}, actor, creating=operation == "create")
        if operation != "delete"
        else {}
    )
    if name in {"T_Article", "T_Commande", "T_Reglements"} and operation != "delete":
        from apps.logistique.services import validate_header

        validate_header(obj, data, old, actor)
    if name in {"T_Fk_Correspondance", "T_Admin_UI_Setting"}:
        set_admin_actor(actor)
    table = db.qualified(obj["schema"], obj["name"])
    if operation == "create":
        if name == "T_Commande":
            from apps.logistique.document_rules import generate_command_identity
            data.update(generate_command_identity())
        for col in obj["columns"]:
            key = col["column_name"]
            if (
                col["is_nullable"] == "NO"
                and not col["column_default"]
                and col["is_identity"] != "YES"
                and key not in data
                and key not in obj["primaryKey"]
            ):
                raise APIError("Champ obligatoire : " + key)
        fields = list(data)
        sql = (
            "INSERT INTO "
            + table
            + " ("
            + ",".join(db.ident(x) for x in fields)
            + ") VALUES ("
            + ",".join(["%s"] * len(fields))
            + ") RETURNING *"
            if fields
            else "INSERT INTO " + table + " DEFAULT VALUES RETURNING *"
        )
        row = db.one(sql, list(data.values()))
    else:
        where, values = predicate(obj, actor, keys=keys)
        if operation == "delete":
            row = db.one(
                "DELETE FROM " + table + " v WHERE " + where + " RETURNING v.*", values
            )
        elif not data:
            row = old
        else:
            row = db.one(
                "UPDATE "
                + table
                + " v SET "
                + ",".join(db.ident(k) + "=%s" for k in data)
                + " WHERE "
                + where
                + " RETURNING v.*",
                [*data.values(), *values],
            )
    # Les réglages partagés sont audités par leurs déclencheurs SQL, y compris
    # lors d’une intervention directe. Une seconde écriture ici les doublerait.
    if name not in {"T_Fk_Correspondance", "T_Admin_UI_Setting"}:
        audit(obj, operation.upper(), old, row, actor)
    if name == "T_Utilisateurs" and old and "MotdepasseUser" in data and data["MotdepasseUser"] != old.get("MotdepasseUser"):
        audit(obj,"PASSWORD_CHANGE",new={"IdUser":row["IdUser"],"passwordChanged":True},actor=actor)
    return clean(row)


def mutate(name, actor, body=None, keys=None, operation="create", hard=False):
    db.ensure_writable()
    try:
        return _mutate(name, actor, body, keys, operation, hard)
    except IntegrityError as exc:
        constraint = getattr(getattr(exc.__cause__, "diag", None), "constraint_name", "")
        if name == "T_Article" and constraint == "uq_article_codeinterne":
            raise APIError({"CodeArticleInterne": "Ce code interne est déjà utilisé."}, "ARTICLE_VALIDATION", 409) from exc
        raise
