"""Boîte de discussion privée et envois, limités aux participants autorisés."""

from uuid import UUID

from django.conf import settings
from django.db import transaction
from rest_framework.permissions import IsAuthenticated
from rest_framework.views import APIView

from apps.catalogue.views import recipient
from apps.core import db
from apps.core.module_access import can_use_tab, require_tab
from apps.core.repository import page, positive
from apps.core.responses import APIError, ok

MESSAGE_COLUMNS = '''
    c."IdChat", c."TextChat", c."ChatFile", c."ChatLink", c."DateChat", c."LuChat",
    jsonb_build_object('IdUser', c."IdUser", 'NomUser', c."NomUser",
        'PrenomUser', c."PrenomUser", 'UrlPhoto', u."UrlPhoto") AS author
'''
MESSAGE_SOURCE = '''
    FROM communication."V_Chat" c
    LEFT JOIN systeme."T_Utilisateurs" u ON u."IdUser"=c."IdUser"
'''
UNREAD_CONDITION = '''
    c."SuiviLectureChat" IS TRUE AND {author} IS DISTINCT FROM %s
    AND NOT EXISTS (
        SELECT 1 FROM communication."T_ChatLecture" l
        WHERE l."IdChatFk"=c."IdChat" AND l."IdUserFk"=%s
    )
'''
UNREAD_PER_DISCUSSION = '''
    SELECT count(*) AS "UnreadCount"
    FROM communication."T_Chat" c
    WHERE c."IdDiscussionFk"={discussion_id} AND
''' + UNREAD_CONDITION.format(author='c."AuthorIdFk"')
MAX_READ_BATCH = 100
_DEMAND_UNSET = object()
DEMAND_FIELDS = '''"IdDemande", "CodeDemande", "SujetDemande", "IdDemandeurFk", "NomDemandeur",
    "IdDestinataireUserFk", "IdEntiteDestinataireFk", "NomDestinataire"'''


def access(actor):
    entity = actor.row.get("IdEntiteFk")
    return (
        '''(
            (d."TypeDiscussion"='user' AND d."IdEntiteFk"=%s
                AND %s IN (d."IdUserClientFk", d."IdUserDestinataireFk"))
            OR (d."TypeDiscussion" IN ('expert','structure') AND d."IdUserClientFk"=%s)
            OR (d."TypeDiscussion"='expert' AND EXISTS (
                SELECT 1 FROM professionnel."T_Professionnel" p
                WHERE p."IdProfessionnel"=d."IdProfessionnelFk" AND p."IdUserFk"=%s
            ))
            OR (d."TypeDiscussion"='structure' AND d."IdEntiteFk"=%s)
            OR (d."TypeDiscussion"='demande' AND communication.fn_demande_participant(%s,d."IdDemandeFk"))
        )''',
        [entity, actor.pk, actor.pk, actor.pk, entity if actor.admin else None, actor.pk],
    )


def discussion(actor, pk, lock=False):
    where, values = access(actor)
    source = 'communication."T_Discussion"' if lock else 'communication."V_DiscussionBoite"'
    row = db.one(
        'SELECT d.* FROM ' + source + ' d WHERE d."IdDiscussion"=%s AND d."ValideDiscussion" IS TRUE AND '
        + where + (' FOR NO KEY UPDATE OF d' if lock else ''),
        [pk, *values],
    )
    if not row:
        raise APIError("Discussion introuvable dans votre périmètre.", "NOT_FOUND", 404)
    return row


def linked_demand(row, actor, demand=_DEMAND_UNSET):
    if row["TypeDiscussion"] != "demande":
        return None
    if demand is _DEMAND_UNSET:
        demand = db.one('SELECT ' + DEMAND_FIELDS + ''' FROM communication."V_Demande"
            WHERE "IdDemande"=%s AND communication.fn_demande_participant(%s,"IdDemande")''',
            [row["IdDemandeFk"], actor.pk])
    if not demand:
        raise APIError("Discussion introuvable dans votre périmètre.", "NOT_FOUND", 404)
    return demand


def correspondent(row, actor, demand=_DEMAND_UNSET):
    kind = row["TypeDiscussion"]
    initiator = row["IdUserClientFk"] == actor.pk
    if kind == "demande":
        demand = linked_demand(row, actor, demand)
        if not initiator:
            return {"type": "user", "id": demand["IdDemandeurFk"], "fullName": demand["NomDemandeur"], "name": demand["NomDemandeur"]}
        return {"type": "user" if demand["IdDestinataireUserFk"] else "structure",
                "id": demand["IdDestinataireUserFk"] or demand["IdEntiteDestinataireFk"],
                "name": demand["NomDestinataire"], "fullName": demand["NomDestinataire"]}
    if kind == "user":
        pk = row["IdUserDestinataireFk"] if initiator else row["IdUserClientFk"]
        name = row["NomDestinataire"] if initiator else row["NomInitiateur"]
        return {"type": "user", "id": pk, "fullName": name, "name": name}
    if not initiator:
        name = row["NomInitiateur"]
        return {"type": "user", "id": row["IdUserClientFk"], "fullName": name, "name": name}
    if kind == "expert":
        return {
            "type": kind, "id": row["IdProfessionnelFk"], "fullName": row["NomProfessionnel"],
            "specialty": row["SpecialiteProfessionnel"],
        }
    return {"type": kind, "id": row["IdEntiteFk"], "name": row["NomStructure"]}


def summary(row, actor, demand=_DEMAND_UNSET):
    demand = linked_demand(row, actor, demand)
    return {
        **{field: row[field] for field in (
            "IdDiscussion", "TypeDiscussion", "SujetDiscussion", "DateCreation", "DernierMessageAt",
        )},
        "recipient": correspondent(row, actor, demand),
        "lastMessage": row["DernierMessage"],
        "demand": {"id": demand["IdDemande"], "code": demand["CodeDemande"],
                   "subject": demand["SujetDemande"]} if demand else None,
    }


def may_send(actor):
    return not settings.DB_READ_ONLY and can_use_tab(actor, "discussions", "messages", "manage")


def active_members(entity, ids, *, lock=False):
    if not entity or None in ids:
        return []
    return db.query(
        '''SELECT u."IdUser", btrim(concat_ws(' ',u."PrenomUser",u."NomUser")) AS name
           FROM systeme."T_Utilisateurs" u
           JOIN systeme."T_Entite" e ON e."IdEntite"=u."IdEntiteFk"
           WHERE u."IdUser"=ANY(%s::integer[]) AND u."IdEntiteFk"=%s
             AND u."ValideUser" IS TRUE AND e."ValideEntite" IS TRUE
           ORDER BY u."IdUser"''' + (' FOR SHARE OF u, e' if lock else ''),
        [ids, entity],
    )


def can_reply(row, actor):
    if row["TypeDiscussion"] == "demande":
        return may_send(actor) and db.one('SELECT communication.fn_demande_participant(%s,%s) AS allowed',
            [actor.pk, row["IdDemandeFk"]])["allowed"]
    return may_send(actor) and (
        row["TypeDiscussion"] != "user"
        or len(active_members(row["IdEntiteFk"], [row["IdUserClientFk"], row["IdUserDestinataireFk"]])) == 2
    )


def search_text(params):
    term = str(params.get("q", "")).strip()
    if len(term) > 200 or "\0" in term:
        raise APIError("La recherche doit contenir au plus 200 caractères valides.")
    return term


def message_data(row):
    return {key: row[key] for key in ("IdChat", "TextChat", "ChatFile", "ChatLink", "DateChat", "LuChat", "author")}


class DiscussionsView(APIView):
    http_method_names = ["get", "head", "options"]

    def get(self, request):
        actor = request.user
        params = request.query_params
        take, skip = page({"take": params.get("take", 100), "skip": params.get("skip", 0)})
        where, values = access(actor)
        term = search_text(params)
        if term:
            where += ''' AND strpos(lower(concat_ws(' ', d."SujetDiscussion", d."NomInitiateur",
                d."NomDestinataire", d."NomProfessionnel", d."NomStructure")),lower(%s))>0'''
            values.append(term)
        if params.get("unread") == "1":
            where += ' AND lecture."UnreadCount">0'
        rows = db.query(
            '''SELECT d.*, lecture."UnreadCount" FROM communication."V_DiscussionBoite" d
               CROSS JOIN LATERAL (''' + UNREAD_PER_DISCUSSION.format(discussion_id='d."IdDiscussion"')
            + ') lecture WHERE d."ValideDiscussion" IS TRUE AND ' + where + '''
            ORDER BY COALESCE(d."DernierMessageAt",d."DateCreation") DESC,d."IdDiscussion" DESC
            LIMIT %s OFFSET %s''',
            [actor.pk, actor.pk, *values, take + 1, skip],
        )
        demand_ids = [row["IdDemandeFk"] for row in rows[:take] if row.get("IdDemandeFk")]
        demands = {row["IdDemande"]: row for row in db.query(
            'SELECT ' + DEMAND_FIELDS + ''' FROM communication."V_Demande"
            WHERE "IdDemande"=ANY(%s::bigint[]) AND communication.fn_demande_participant(%s,"IdDemande")''',
            [demand_ids, actor.pk],
        )} if demand_ids else {}
        send = may_send(actor)
        return ok(
            [{**summary(row, actor, demands.get(row.get("IdDemandeFk"))),
              "unreadCount": row["UnreadCount"]} for row in rows[:take]],
            meta={
                "currentUserId": actor.pk, "take": take, "skip": skip, "hasNext": len(rows) > take,
                "canSend": send, "contactsAvailable": send and bool(actor.row.get("IdEntiteFk")),
            },
        )


class ContactsView(APIView):
    http_method_names = ["get", "head", "options"]

    def get(self, request):
        actor = request.user
        params = request.query_params
        take, skip = page(params)
        take = min(take, 50)
        term = search_text(params)
        rows = db.query(
            '''SELECT u."IdUser" id, btrim(concat_ws(' ',u."PrenomUser",u."NomUser")) name
               FROM systeme."T_Utilisateurs" u
               JOIN systeme."T_Entite" e ON e."IdEntite"=u."IdEntiteFk"
               WHERE u."IdEntiteFk"=%s AND u."IdUser"<>%s
                 AND u."ValideUser" IS TRUE AND e."ValideEntite" IS TRUE
                 AND strpos(lower(concat_ws(' ',u."PrenomUser",u."NomUser")),lower(%s))>0
               ORDER BY lower(concat_ws(' ',u."PrenomUser",u."NomUser")),u."IdUser"
               LIMIT %s OFFSET %s''',
            [actor.row.get("IdEntiteFk"), actor.pk, term, take + 1, skip],
        )
        return ok(
            [{"type": "user", "id": row["id"], "fullName": row["name"], "name": row["name"]} for row in rows[:take]],
            meta={"take": take, "skip": skip, "hasNext": len(rows) > take},
        )


def start_direct(actor, target):
    if target == actor.pk:
        raise APIError("Choisissez un autre destinataire.")
    entity = actor.row.get("IdEntiteFk")
    members = active_members(entity, [actor.pk, target], lock=True)
    if len(members) != 2:
        raise APIError("Ce destinataire n’est pas disponible dans votre entreprise.", "NOT_FOUND", 404)
    first, second = sorted((actor.pk, target))
    db.one("SELECT pg_advisory_xact_lock(hashtextextended(%s,0))", [f"discussion:user:{entity}:{first}:{second}"])
    row = db.one(
        '''SELECT "IdDiscussion" FROM communication."T_Discussion"
           WHERE "TypeDiscussion"='user' AND "ValideDiscussion" IS TRUE AND "IdEntiteFk"=%s
             AND LEAST("IdUserClientFk","IdUserDestinataireFk")=%s
             AND GREATEST("IdUserClientFk","IdUserDestinataireFk")=%s''',
        [entity, first, second],
    )
    if row:
        return row["IdDiscussion"], False
    row = db.one(
        '''INSERT INTO communication."T_Discussion"
           ("IdUserClientFk","IdUserDestinataireFk","IdEntiteFk","TypeDiscussion")
           VALUES (%s,%s,%s,'user') RETURNING "IdDiscussion"''',
        [actor.pk, target, entity],
    )
    return row["IdDiscussion"], True


def start_directory(actor, kind, target):
    entry = recipient(kind, target, actor=actor, contact=True, lock=True)
    db.one("SELECT pg_advisory_xact_lock(hashtextextended(%s,0))", [f"{actor.pk}:{kind}:{target}"])
    field = db.ident("IdProfessionnelFk" if kind == "expert" else "IdEntiteFk")
    row = db.one(
        'SELECT "IdDiscussion" FROM communication."T_Discussion" WHERE "IdUserClientFk"=%s '
        'AND "TypeDiscussion"=%s AND ' + field + '=%s AND "ValideDiscussion" IS TRUE '
        'ORDER BY "IdDiscussion" DESC LIMIT 1',
        [actor.pk, kind, target],
    )
    if row:
        return row["IdDiscussion"], False
    row = db.one(
        'INSERT INTO communication."T_Discussion" ("IdUserClientFk","TypeDiscussion",'
        + field + ',"SujetDiscussion") VALUES (%s,%s,%s,%s) RETURNING "IdDiscussion"',
        [actor.pk, kind, target, "Discussion avec " + (entry.get("fullName") or entry.get("name") or "")],
    )
    return row["IdDiscussion"], True


class StartView(APIView):
    http_method_names = ["post", "options"]

    def post(self, request):
        db.ensure_writable()
        if not hasattr(request.data, "get"):
            raise APIError("La demande de discussion est invalide.")
        kind = request.data.get("type")
        if kind not in ("user", "expert", "structure"):
            raise APIError("Choisissez un utilisateur, un professionnel ou une structure.")
        target = positive(request.data.get("targetId"))
        actor = request.user
        with transaction.atomic():
            if kind == "user":
                pk, created = start_direct(actor, target)
            else:
                pk, created = start_directory(actor, kind, target)
            result = summary(discussion(actor, pk), actor)
        return ok(result, status=201 if created else 200, meta={"currentUserId": actor.pk, "created": created})


def message_page(pk, actor, params):
    take, skip = page({"take": params.get("take", 100), "skip": params.get("skip", 0)})
    before = params.get("before")
    if before and "skip" in params:
        raise APIError("Choisissez une seule méthode de pagination.")
    where = 'c."IdDiscussionFk"=%s'
    values = [pk]
    if before:
        where += ''' AND (c."DateChat",c."IdChat") < (
            SELECT b."DateChat",b."IdChat" FROM communication."T_Chat" b
            WHERE b."IdDiscussionFk"=%s AND b."IdChat"=%s)'''
        values.extend([pk, positive(before)])
    descending = "skip" not in params
    direction = " DESC" if descending else " ASC"
    rows = db.query(
        "SELECT " + MESSAGE_COLUMNS + ", (" + UNREAD_CONDITION.format(author='c."IdUser"')
        + ") AS unread " + MESSAGE_SOURCE + " WHERE " + where
        + ' ORDER BY c."DateChat"' + direction + ',c."IdChat"' + direction + ' LIMIT %s OFFSET %s',
        [actor.pk, actor.pk, *values, take + 1, skip],
    )
    shown = rows[:take]
    if descending:
        shown.reverse()
    has_previous = len(rows) > take if descending else skip > 0 and bool(shown)
    return shown, {"take": take, "skip": skip, "hasPrevious": has_previous,
                   "nextBefore": shown[0]["IdChat"] if has_previous else None}


class MessagesView(APIView):
    http_method_names = ["get", "post", "head", "options"]

    def get(self, request, pk):
        pk = positive(pk)
        actor = request.user
        row = discussion(actor, pk)
        rows, pagination = message_page(pk, actor, request.query_params)
        return ok(rows, meta={
            **pagination, "currentUserId": actor.pk, "count": len(rows),
            "canSend": can_reply(row, actor), "canMarkRead": not settings.DB_READ_ONLY,
            "discussion": summary(row, actor),
        })

    def post(self, request, pk):
        db.ensure_writable()
        pk = positive(pk)
        actor = request.user
        if not hasattr(request.data, "get"):
            raise APIError("Le message doit être fourni dans un objet.")
        text = request.data.get("message")
        if not isinstance(text, str) or not text.strip() or "\0" in text or len(text) > 10000:
            raise APIError("Saisissez un message de 1 à 10 000 caractères.")
        text = text.strip()
        request_id = request.data.get("requestId")
        if request_id is not None:
            try:
                request_id = str(UUID(request_id))
            except (TypeError, ValueError, AttributeError):
                raise APIError("Identifiant d’envoi invalide.")
        with transaction.atomic():
            thread = discussion(actor, pk, lock=True)
            row = None
            if request_id:
                row = db.one(
                    '''SELECT "IdChat","TextChat","ChatFile","ChatLink","DateChat","LuChat"
                       FROM communication."T_Chat" WHERE "IdDiscussionFk"=%s
                         AND "AuthorIdFk"=%s AND "CleRequeteChat"=%s::uuid''',
                    [pk, actor.pk, request_id],
                )
                if row and row["TextChat"] != text:
                    raise APIError("Cet identifiant a déjà été utilisé pour un autre message.", "REQUEST_CONFLICT", 409)
            created = row is None
            if created:
                if thread["TypeDiscussion"] == "user" and len(active_members(
                    thread["IdEntiteFk"], [thread["IdUserClientFk"], thread["IdUserDestinataireFk"]], lock=True,
                )) != 2:
                    raise APIError("Ce correspondant n’est plus disponible dans cette entreprise.", "CONTACT_INACTIVE", 409)
                row = db.one(
                    '''INSERT INTO communication."T_Chat" ("IdDiscussionFk","AuthorIdFk","TextChat","CleRequeteChat")
                       VALUES (%s,%s,%s,%s::uuid) RETURNING "IdChat","TextChat","ChatFile","ChatLink","DateChat","LuChat"''',
                    [pk, actor.pk, text, request_id],
                )
        row["author"] = {key: actor.row.get(key) for key in ("IdUser", "NomUser", "PrenomUser", "UrlPhoto")}
        return ok(
            {**message_data(row), "unread": False}, status=201 if created else 200,
            meta={"currentUserId": actor.pk, "created": created},
        )


class DiscussionReadView(APIView):
    http_method_names = ["post", "options"]
    # Un lecteur peut classer ses propres messages reçus même sans droit d’envoi.
    permission_classes = [IsAuthenticated]

    def post(self, request, pk):
        actor = request.user
        require_tab(actor, "discussions", "messages")
        db.ensure_writable()
        pk = positive(pk)
        ids = request.data.get("messageIds") if isinstance(request.data, dict) else None
        if not isinstance(ids, list) or not 1 <= len(ids) <= MAX_READ_BATCH:
            raise APIError(f"Indiquez de 1 à {MAX_READ_BATCH} messages à marquer comme lus.")
        ids = list(dict.fromkeys(positive(value, "Identifiant du message") for value in ids))
        with transaction.atomic():
            discussion(actor, pk, lock=True)
            result = db.one(
                '''WITH selection AS (
                    SELECT c.* FROM communication."T_Chat" c
                    WHERE c."IdDiscussionFk"=%s AND c."IdChat"=ANY(%s::integer[])
                ), validated AS (
                    SELECT count(*)=%s AS valid FROM selection
                ), marked AS (
                    INSERT INTO communication."T_ChatLecture" ("IdChatFk","IdUserFk")
                    SELECT c."IdChat",%s FROM selection c
                    WHERE (SELECT valid FROM validated) AND '''
                + UNREAD_CONDITION.format(author='c."AuthorIdFk"') + '''
                    ORDER BY c."IdChat"
                    ON CONFLICT ("IdChatFk","IdUserFk") DO NOTHING
                    RETURNING 1
                )
                SELECT valid,(SELECT count(*) FROM marked) AS marked FROM validated''',
                [pk, ids, len(ids), actor.pk, actor.pk, actor.pk],
            )
            if not result["valid"]:
                raise APIError("Certains messages ne sont pas disponibles dans cette discussion.", "NOT_FOUND", 404)
            counts = db.one(UNREAD_PER_DISCUSSION.format(discussion_id="%s"), [pk, actor.pk, actor.pk])
        return ok({"markedCount": result["marked"], "unreadCount": counts["UnreadCount"]})
