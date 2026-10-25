"""Notifications personnelles : vues existantes, destinataire et entité imposés."""

from django.conf import settings
from django.db import transaction
from rest_framework.permissions import IsAuthenticated
from rest_framework.views import APIView

from apps.core import db
from apps.core.repository import audit, positive
from apps.core.responses import APIError, ok

MAX_PAGE_SIZE = 50
ITEM_COLUMNS = '''n."IdCommunication", n."ContenuCommunication", n."DateCommunication",
                  n."LectureCommunication", n."TypeCommunicationLibelle", n."TypeCommunicationAbr"'''


def personal_scope(actor, *, table=False):
    # Aucun privilège global ne retire le destinataire de ce parcours personnel.
    if table:
        clause = 'n."IdUserFk"=%s AND (n."IdEntiteFk" IS NULL OR n."IdEntiteFk"=%s)'
    else:
        clause = 'n."IdUser"=%s AND (n."IdEntite" IS NULL OR n."IdEntite"=%s)'
    return clause, [actor.pk, actor.organisation]


def list_options(params):
    read = params.get("read", "all")
    if read not in {"all", "unread"}:
        raise APIError("Le filtre de lecture doit être all ou unread.")
    page = positive(params.get("page", 1), "Page")
    size = min(positive(params.get("pageSize", 20), "Taille de page"), MAX_PAGE_SIZE)
    return read, page, size


def personal_counts(actor):
    where, values = personal_scope(actor)
    row = db.one(
        '''SELECT COUNT(*) AS total,
                  COUNT(*) FILTER (WHERE n."LectureCommunication" IS FALSE) AS unread_count
           FROM communication."V_Communication" n
           WHERE n."ValideCommunication" IS TRUE AND ''' + where,
        values,
    )
    return int(row["total"]), int(row["unread_count"])


def item(row):
    created = row.get("DateCommunication")
    title = row.get("TypeCommunicationLibelle") or row.get("TypeCommunicationAbr") or "Notification"
    return {
        "id": row["IdCommunication"],
        "title": str(title).strip() or "Notification",
        "body": row.get("ContenuCommunication") or "",
        "createdAt": created.isoformat() if hasattr(created, "isoformat") else created,
        "read": row.get("LectureCommunication") is True,
    }


class NotificationsView(APIView):
    # Fonction du compte connecté, indépendante des licences des modules métier.
    permission_classes = [IsAuthenticated]
    http_method_names = ["get", "head", "options"]

    def get(self, request):
        read, page, size = list_options(request.query_params)
        all_count, unread = personal_counts(request.user)
        total = unread if read == "unread" else all_count
        offset = (page - 1) * size
        where, values = personal_scope(request.user)
        if read == "unread":
            where += ' AND n."LectureCommunication" IS FALSE'
        rows = db.query(
            "SELECT " + ITEM_COLUMNS + ''' FROM communication."V_Communication" n
            WHERE n."ValideCommunication" IS TRUE AND ''' + where + '''
            ORDER BY n."DateCommunication" DESC, n."IdCommunication" DESC LIMIT %s OFFSET %s''',
            [*values, size, offset],
        ) if offset < total else []
        return ok(
            [item(row) for row in rows],
            meta={
                "total": total, "unreadCount": unread, "page": page, "pageSize": size,
                "hasNext": offset + size < total, "hasPrevious": page > 1,
                "canMarkRead": not settings.DB_READ_ONLY,
            },
        )


class NotificationReadView(APIView):
    permission_classes = [IsAuthenticated]
    http_method_names = ["patch", "options"]

    def patch(self, request, pk):
        db.ensure_writable()
        body = request.data
        if not isinstance(body, dict) or set(body) - {"read"} or ("read" in body and body["read"] is not True):
            raise APIError("Cette action permet uniquement de marquer la notification comme lue.")
        notification_id = positive(pk)
        where, values = personal_scope(request.user, table=True)
        with transaction.atomic():
            current = db.one(
                '''SELECT n."IdCommunication", n."LectureCommunication"
                   FROM communication."T_Communication" n
                   WHERE n."IdCommunication"=%s AND n."ValideCommunication" IS TRUE AND '''
                + where + " FOR UPDATE OF n",
                [notification_id, *values],
            )
            if not current:
                raise APIError("Notification introuvable dans votre périmètre.", "NOT_FOUND", 404)
            if current["LectureCommunication"] is not True:
                updated = db.one(
                    '''UPDATE communication."T_Communication" n SET "LectureCommunication"=true
                       WHERE n."IdCommunication"=%s AND n."ValideCommunication" IS TRUE AND '''
                    + where + ' RETURNING n."IdCommunication", n."LectureCommunication"',
                    [notification_id, *values],
                )
                if not updated:
                    raise APIError("La notification n’a pas pu être marquée comme lue.", "NOTIFICATION_CONFLICT", 409)
                audit(
                    {"schema": "communication", "name": "T_Communication"}, "UPDATE",
                    old=current, new=updated, actor=request.user,
                )
            view_where, view_values = personal_scope(request.user)
            row = db.one(
                "SELECT " + ITEM_COLUMNS + ''' FROM communication."V_Communication" n
                WHERE n."IdCommunication"=%s AND n."ValideCommunication" IS TRUE AND ''' + view_where,
                [notification_id, *view_values],
            )
            if not row:
                raise APIError("Notification introuvable dans votre périmètre.", "NOT_FOUND", 404)
            total, unread = personal_counts(request.user)
        return ok(item(row), meta={"total": total, "unreadCount": unread, "canMarkRead": True})
