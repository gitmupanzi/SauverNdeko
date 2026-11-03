from django.db import transaction
from rest_framework.views import APIView
from apps.core import db
from apps.core.repository import positive, page
from apps.core.responses import ok, APIError
from apps.catalogue.views import recipient


def access(actor, alias="d"):
    return (
        f'({alias}."IdUserClientFk"=%s OR EXISTS (SELECT 1 FROM professionnel."T_Professionnel" p WHERE p."IdProfessionnel"={alias}."IdProfessionnelFk" AND p."IdUserFk"=%s) OR (%s IS NOT NULL AND {alias}."IdEntiteFk"=%s))',
        [
            actor.pk,
            actor.pk,
            actor.organisation if actor.admin else None,
            actor.organisation if actor.admin else None,
        ],
    )


def discussion(actor, pk, lock=False):
    where, params = access(actor)
    row = db.one(
        'SELECT d.* FROM communication."T_Discussion" d WHERE d."IdDiscussion"=%s AND d."ValideDiscussion"=true AND '
        + where
        + (" FOR UPDATE OF d" if lock else ""),
        [positive(pk), *params],
    )
    if not row:
        raise APIError("Discussion introuvable dans votre périmètre.", "NOT_FOUND", 404)
    return row


def messages(pk, params=None):
    take, skip = page(params or {"take": 100})
    rows = db.query(
        """SELECT c."IdChat",c."TextChat",c."ChatFile",c."ChatLink",c."DateChat",c."LuChat",jsonb_build_object('IdUser',u."IdUser",'NomUser',u."NomUser",'PrenomUser',u."PrenomUser",'UrlPhoto',u."UrlPhoto") AS author FROM communication."T_Chat" c LEFT JOIN systeme."T_Utilisateurs" u ON u."IdUser"=c."AuthorIdFk" WHERE c."IdDiscussionFk"=%s ORDER BY c."DateChat",c."IdChat" LIMIT %s OFFSET %s""",
        [pk, take, skip],
    )
    return rows


def summary(row):
    data = {
        k: row.get(k)
        for k in [
            "IdDiscussion",
            "TypeDiscussion",
            "SujetDiscussion",
            "DateCreation",
            "DernierMessageAt",
        ]
    }
    target = (
        row.get("IdProfessionnelFk")
        if row["TypeDiscussion"] == "expert"
        else row.get("IdEntiteFk")
    )
    try:
        data["recipient"] = recipient(row["TypeDiscussion"], target)
    except APIError:
        data["recipient"] = None
    last = db.one(
        'SELECT "IdChat" FROM communication."T_Chat" WHERE "IdDiscussionFk"=%s ORDER BY "DateChat" DESC,"IdChat" DESC LIMIT 1',
        [row["IdDiscussion"]],
    )
    if last:
        data["lastMessage"] = db.one(
            """SELECT c."IdChat",c."TextChat",c."ChatFile",c."ChatLink",c."DateChat",c."LuChat",jsonb_build_object('IdUser',u."IdUser",'NomUser',u."NomUser",'PrenomUser',u."PrenomUser",'UrlPhoto',u."UrlPhoto") AS author FROM communication."T_Chat" c LEFT JOIN systeme."T_Utilisateurs" u ON u."IdUser"=c."AuthorIdFk" WHERE c."IdChat"=%s""",
            [last["IdChat"]],
        )
    else:
        data["lastMessage"] = None
    return data


class DiscussionsView(APIView):
    def get(self, request):
        where, params = access(request.user)
        take, skip = page(
            {
                **request.query_params.dict(),
                "take": request.query_params.get("take", 100),
            }
        )
        rows = db.query(
            'SELECT d.* FROM communication."T_Discussion" d WHERE d."ValideDiscussion"=true AND '
            + where
            + ' ORDER BY d."DernierMessageAt" DESC NULLS LAST,d."IdDiscussion" DESC LIMIT %s OFFSET %s',
            [*params, take, skip],
        )
        return ok(
            [summary(r) for r in rows],
            meta={"currentUserId": request.user.pk, "take": take, "skip": skip},
        )


class StartView(APIView):
    def post(self, request):
        db.ensure_writable()
        kind = request.data.get("type")
        target = positive(request.data.get("targetId"))
        field = "IdProfessionnelFk" if kind == "expert" else "IdEntiteFk"
        with transaction.atomic():
            r = recipient(kind, target, actor=request.user, contact=True, lock=True)
            db.query(
                "SELECT pg_advisory_xact_lock(hashtextextended(%s,0))",
                [str(request.user.pk) + ":" + kind + ":" + str(target)],
            )
            row = db.one(
                'SELECT * FROM communication."T_Discussion" WHERE "IdUserClientFk"=%s AND "TypeDiscussion"=%s AND '
                + db.ident(field)
                + '=%s AND "ValideDiscussion"=true ORDER BY "IdDiscussion" DESC LIMIT 1',
                [request.user.pk, kind, target],
            )
            created = row is None
            if created:
                row = db.one(
                    'INSERT INTO communication."T_Discussion" ("IdUserClientFk","TypeDiscussion",'
                    + db.ident(field)
                    + ',"SujetDiscussion") VALUES (%s,%s,%s,%s) RETURNING *',
                    [
                        request.user.pk,
                        kind,
                        target,
                        "Discussion avec " + (r.get("fullName") or r.get("name") or ""),
                    ],
                )
        return ok(
            summary(row),
            status=201 if created else 200,
            meta={"currentUserId": request.user.pk, "created": created},
        )


class MessagesView(APIView):
    def get(self, request, pk):
        discussion(request.user, pk)
        rows = messages(positive(pk), request.query_params.dict() or {"take": 100})
        return ok(rows, meta={"currentUserId": request.user.pk, "count": len(rows)})

    def post(self, request, pk):
        db.ensure_writable()
        text = request.data.get("message")
        if not isinstance(text, str) or not text.strip() or len(text) > 10000:
            raise APIError("Message vide ou trop long.")
        with transaction.atomic():
            discussion(request.user, pk, lock=True)
            row = db.one(
                'INSERT INTO communication."T_Chat" ("IdDiscussionFk","AuthorIdFk","TextChat") VALUES (%s,%s,%s) RETURNING *',
                [positive(pk), request.user.pk, text.strip()],
            )
            # PostgreSQL maintient la dernière activité pour tous les producteurs de messages.
        row["author"] = {
            k: request.user.row.get(k)
            for k in ["IdUser", "NomUser", "PrenomUser", "UrlPhoto"]
        }
        return ok(
            {
                k: row[k]
                for k in [
                    "IdChat",
                    "TextChat",
                    "ChatFile",
                    "ChatLink",
                    "DateChat",
                    "LuChat",
                    "author",
                ]
            },
            status=201,
            meta={"currentUserId": request.user.pk},
        )
