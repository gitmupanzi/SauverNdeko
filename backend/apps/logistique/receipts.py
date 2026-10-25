"""Réception depuis un article : bon d’entrée, ligne et lots dans une transaction."""
import hashlib
import hmac
import json
import unicodedata
import uuid
from datetime import datetime, timezone
from decimal import Decimal
from zoneinfo import ZoneInfo

from django.conf import settings
from django.db import transaction
from rest_framework.views import APIView

from apps.core import db
from apps.core.module_access import require_module
from apps.core.permissions import IsERPAdmin
from apps.core.registry import model, view
from apps.core.repository import audit, coerce, get_record, mutate, positive
from apps.core.responses import APIError, ExactEncoder, ok
from apps.core.ui_settings import SOURCES
from .currency import validate_currency
from .lots import normalize as normalize_lots
from .services import mutate_line

ALLOWED = {"requestId", "QteCmdDetail", "PUCmdDetail", "ID_DeviseFk", "DateCmd", "RefCmd",
           "ID_ClientFk", "NomClientSaisi", "ObsCmd", "ObsCmdDetail", "Lots", "ID_TypeCmdFk"}
TEXT_LIMITS = {"RefCmd":255, "NomClientSaisi":255, "ObsCmd":255, "ObsCmdDetail":255}


def field_error(key, message):
    raise APIError({key:message}, "RECEIPT_VALIDATION", 400)


def normalized(value):
    return "".join(char for char in unicodedata.normalize("NFD", str(value or ""))
                   if not unicodedata.combining(char)).strip().lower()


def entry_types(*, lock=False):
    source=SOURCES["generic"].get("logistique.commandeTypes",{})
    relation=next((item for item in model("T_Commande")["relations"]
        if item.get("from")==["ID_TypeCmdFk"] and item.get("target")=="T_Generique"
        and item.get("to")==["ID_Generique"]),None)
    if not relation or source.get("fieldName")!="ID_TypeCmdFk" or source.get("referenceSchemaName")!="referentiel" or source.get("referenceObjectName")!="T_Generique" or source.get("referenceFieldName")!="ID_Generique":
        raise APIError("La liste des types de bon n’est pas configurée.", "RECEIPT_CONFIGURATION", 503)
    categories=source.get("defaultCategoryIds",[])
    if not isinstance(categories,list) or not categories:
        raise APIError("La catégorie des types de bon n’est pas configurée.", "RECEIPT_CONFIGURATION", 503)
    category_ids=[positive(value,"Catégorie de type de bon") for value in categories]
    rows=db.query('''SELECT g."ID_Generique" AS id,g."NomGenerique" AS label,g."AbrGenerique" AS abbreviation
        FROM referentiel."T_Generique" g
        JOIN referentiel."T_CategorieGenerique" c ON c."ID_CategorieGenerique"=g."ID_CategorieGeneriqueFk"
        WHERE g."ID_CategorieGeneriqueFk"=ANY(%s)
          AND c."ValideCategorieGenerique" IS TRUE AND g."ValideGenerique" IS TRUE
          AND g."AbrGenerique" ILIKE %s
        ORDER BY LOWER(g."NomGenerique"),g."ID_Generique" ''' + ('FOR SHARE OF g,c' if lock else ''),[category_ids,'entr%'])
    if not rows:
        raise APIError("Ajoutez un type de bon d’entrée actif dans le référentiel.", "RECEIPT_CONFIGURATION", 503)
    return rows


def default_entry_type(rows):
    exact=[row for row in rows if normalized(row["label"])=="entree" or normalized(row.get("abbreviation"))=="entree"]
    preferred=exact[0] if len(exact)==1 else rows[0] if len(rows)==1 else None
    return {"id":preferred["id"],"label":preferred["label"]} if preferred else None


def entry_type(identifier=None, *, lock=False):
    rows=entry_types(lock=lock)
    if identifier is None:
        selected=default_entry_type(rows)
    else:
        selected=next(({"id":row["id"],"label":row["label"]} for row in rows if row["id"]==identifier),None)
    if not selected:
        field_error("ID_TypeCmdFk","Choisissez un type de bon d’entrée actif dans la liste proposée.")
    return selected


def article_context(actor, pk, *, active=True):
    record = get_record(view("logistique", "V_Article"), actor, {"ID_Article":positive(pk)})
    owner = db.one('SELECT "IdEntiteFk" FROM systeme."T_Utilisateurs" WHERE "IdUser"=%s', [record.get("ID_UserFK")])
    if not owner or owner["IdEntiteFk"] != actor.organisation:
        raise APIError("Effectuez cette réception dans l’organisation de cet article.", "RECEIPT_ORGANISATION", 403)
    if active and record.get("ValideArticle") is not True:
        raise APIError("Activez l’article avant d’enregistrer une réception.", "ARTICLE_INACTIVE", 409)
    return record


def receipt_defaults(actor, pk):
    require_module(actor, "logistique")
    record = article_context(actor, pk)
    types=entry_types()
    selected=default_entry_type(types)
    return {"article":record, "defaults":{"ID_TypeCmdFk":selected["id"] if selected else None,"ID_DeviseFk":record.get("ID_DeviseFk"),
            "PUCmdDetail":record.get("PUArticle"),
            "DateCmd":datetime.now(ZoneInfo(settings.TIME_ZONE)).replace(tzinfo=None).isoformat(timespec="minutes")},
            "types":[{"id":row["id"],"label":row["label"]} for row in types], "type":selected, "timeZone":settings.TIME_ZONE, "canReceive":not settings.DB_READ_ONLY}


def receipt_data(body):
    if not isinstance(body, dict) or set(body)-ALLOWED:
        raise APIError("Champ de réception non autorisé.", "RECEIPT_VALIDATION", 400)
    try:
        request_id = str(uuid.UUID(body.get("requestId", "")))
    except (ValueError, TypeError, AttributeError):
        field_error("requestId", "La demande n’est plus valide. Rouvrez le formulaire.")
    line_columns = {column["column_name"]:column for column in model("T_CommandeDetail")["columns"]}
    command_columns = {column["column_name"]:column for column in model("T_Commande")["columns"]}
    data = {"requestId":request_id}
    if "ID_TypeCmdFk" in body:
        try:data["ID_TypeCmdFk"]=positive(body["ID_TypeCmdFk"],"Type de bon")
        except APIError:field_error("ID_TypeCmdFk","Choisissez un type de bon d’entrée.")
    for key,label in (("QteCmdDetail","Quantité"),("PUCmdDetail","Prix d’achat")):
        try:
            data[key] = coerce(line_columns[key], body.get(key))
        except APIError:
            field_error(key, label+" : valeur ou précision non valide.")
    quantity, price = data["QteCmdDetail"],data["PUCmdDetail"]
    if quantity is None or quantity <= 0 or quantity != int(quantity) or quantity > 2147483647:
        field_error("QteCmdDetail", "Indiquez une quantité entière entre 1 et 2 147 483 647.")
    if price is None or price < 0:
        field_error("PUCmdDetail", "Indiquez un prix d’achat positif ou nul.")
    try:
        coerce(command_columns["MontantTTC"], quantity*price)
    except APIError:
        field_error("PUCmdDetail", "Le montant de la réception dépasse la limite autorisée.")
    try:
        data["ID_DeviseFk"] = positive(body.get("ID_DeviseFk"), "Devise")
    except APIError:
        field_error("ID_DeviseFk", "Choisissez une devise.")
    raw_date = body.get("DateCmd")
    try:
        if not isinstance(raw_date,str) or "T" not in raw_date or len(raw_date)>40:
            raise ValueError()
        received = datetime.fromisoformat(raw_date.replace("Z", "+00:00"))
        if command_columns["DateCmd"]["data_type"] == "timestamp with time zone":
            if received.tzinfo is None:
                received=received.replace(tzinfo=ZoneInfo(settings.TIME_ZONE))
        elif received.tzinfo is not None:
            raise ValueError()
        data["DateCmd"]=received
    except (ValueError,TypeError,OverflowError):
        field_error("DateCmd", "Indiquez la date et l’heure du bon.")
    for key,maximum in TEXT_LIMITS.items():
        value=body.get(key)
        if value is not None:
            if not isinstance(value,str):field_error(key, "Indiquez un texte valide.")
            value=value.strip()
            metadata=(line_columns if key=="ObsCmdDetail" else command_columns)[key]
            maximum=min(maximum,metadata.get("character_maximum_length") or maximum)
            if len(value)>maximum:field_error(key, f"Utilisez au maximum {maximum} caractères.")
            data[key]=value or None
    if body.get("ID_ClientFk") not in (None, ""):
        try:data["ID_ClientFk"]=positive(body["ID_ClientFk"], "Fournisseur")
        except APIError:field_error("ID_ClientFk", "Choisissez un tiers valide.")
    try:
        lots=normalize_lots(body.get("Lots",[]),quantity)
    except APIError as error:
        detail=error.detail
        field_error("Lots", str(detail) if isinstance(detail,str) else "Vérifiez les lots et leurs quantités.")
    data["Lots"]=[{**row,"DatePeremptionLot":row["DatePeremptionLot"].isoformat() if row["DatePeremptionLot"] else None} for row in lots]
    data["QteCmdDetail"]=int(quantity)
    data["PUCmdDetail"]=price.quantize(Decimal("0.01"))
    return data


def payload_hash(pk, data, actor):
    canonical={**data,"ID_Article":pk,"IdEntiteFk":actor.organisation}
    canonical.pop("requestId")
    canonical["Lots"]=sorted(canonical["Lots"],key=lambda row:row["NumeroLot"].casefold())
    value=canonical["DateCmd"]
    canonical["DateCmd"]=(value.astimezone(timezone.utc) if value.tzinfo else value).isoformat()
    return hashlib.sha256(json.dumps(canonical,ensure_ascii=False,sort_keys=True,separators=(",",":"),cls=ExactEncoder).encode("utf8")).hexdigest()


def receipt_result(actor, article_id, command_id, *, replayed):
    return {"bon":get_record(view("logistique","V_Commande"),actor,{"ID_Commande":command_id}),
            "ligne":get_record(view("logistique","V_CommandeDetail"),actor,{"ID_CmdFk":command_id,"ID_ArticleFk":article_id}),
            "article":get_record(view("logistique","V_Article"),actor,{"ID_Article":article_id}),
            "replayed":replayed}


def receive_article(actor, pk, body):
    db.ensure_writable()
    if not actor.admin:raise APIError("Accès réservé aux gestionnaires autorisés.", "FORBIDDEN", 403)
    require_module(actor,"logistique","manage")
    article_id=positive(pk)
    data=receipt_data(body)
    operation_key=f"receipt:{actor.pk}:{data['requestId']}"
    with transaction.atomic():
        # Même demande sérialisée, sans nouvelle table ni changement de stock applicatif.
        db.one("SELECT pg_advisory_xact_lock(hashtextextended(%s,0)) AS locked",[operation_key])
        proof=db.one('''SELECT "NewData" AS proof FROM systeme."T_Audit_Log"
            WHERE "TableName"='logistique.T_Commande' AND "Operation"='RECEIVE'
              AND "NewData"->>'requestId'=%s AND "NewData"->'_actor'->>'IdUser'=%s
            ORDER BY "IdLog" DESC LIMIT 1''',[data["requestId"],str(actor.pk)])
        if proof:
            saved=proof["proof"]
            original_type=saved.get("ID_TypeCmdFk")
            if original_type is None:
                previous=get_record(model("T_Commande"),actor,{"ID_Commande":positive(saved.get("ID_Commande"))})
                original_type=previous.get("ID_TypeCmdFk")
            comparison=dict(data)
            if "ID_TypeCmdFk" in saved:
                comparison["ID_TypeCmdFk"]=original_type
            else:
                comparison.pop("ID_TypeCmdFk",None)
            fingerprint=payload_hash(article_id,comparison,actor)
            if saved.get("ID_Article")!=article_id or ("ID_TypeCmdFk" in data and data["ID_TypeCmdFk"]!=original_type) or not hmac.compare_digest(str(saved.get("payloadHash","")),fingerprint):
                raise APIError("Cette demande a déjà été enregistrée avec d’autres informations. Rouvrez le formulaire.", "RECEIPT_REPLAY_CONFLICT", 409)
            article_context(actor,article_id,active=False)
            return receipt_result(actor,article_id,positive(saved.get("ID_Commande")),replayed=True)
        article_context(actor,article_id)
        validate_currency(data["ID_DeviseFk"])
        received_type=entry_type(data.get("ID_TypeCmdFk"),lock=True)
        data["ID_TypeCmdFk"]=received_type["id"]
        fingerprint=payload_hash(article_id,data,actor)
        header={key:data[key] for key in ("ID_DeviseFk","DateCmd","RefCmd","ID_ClientFk","NomClientSaisi","ObsCmd") if key in data}
        header.update(ID_TypeCmdFk=received_type["id"],DateHeureAutoCmd=datetime.now(timezone.utc))
        command=mutate("T_Commande",actor,header,operation="create")
        line={"ID_ArticleFk":article_id,"QteCmdDetail":data["QteCmdDetail"],"PUCmdDetail":data["PUCmdDetail"]}
        if data.get("ObsCmdDetail") is not None:line["ObsCmdDetail"]=data["ObsCmdDetail"]
        if data["Lots"]:line["Lots"]=data["Lots"]
        mutate_line(actor,command["ID_Commande"],line)
        audit(model("T_Commande"),"RECEIVE",new={"ID_Commande":command["ID_Commande"],"ID_Article":article_id,
            "requestId":data["requestId"],"payloadHash":fingerprint,"ID_TypeCmdFk":received_type["id"]},actor=actor)
        return receipt_result(actor,article_id,command["ID_Commande"],replayed=False)


class ArticleReceiptView(APIView):
    permission_classes=[IsERPAdmin]
    http_method_names=["get","post","options"]

    def get(self, request, pk):
        return ok(receipt_defaults(request.user,pk))

    def post(self, request, pk):
        result=receive_article(request.user,pk,request.data)
        return ok(result,status=200 if result["replayed"] else 201,message="Réception enregistrée.")
