"""Publication en lot des articles de l’entreprise active."""
from django.db import transaction
from rest_framework.views import APIView

from apps.core import db
from apps.core.module_access import require_module
from apps.core.permissions import IsERPAdmin
from apps.core.registry import model
from apps.core.repository import audit
from apps.core.responses import APIError, ok
from apps.core.tenancy import require_entity

from .tab_access import require_tabs


@transaction.atomic
def set_article_publication(actor, body):
    require_module(actor, "logistique", "manage")
    require_tabs(actor, "articles", action="manage")
    db.ensure_writable()
    entity_id = require_entity(actor)

    if not isinstance(body, dict) or body.keys() != {"ids", "visible"}:
        raise APIError("Indiquez les articles et leur visibilité.", "ARTICLE_PUBLICATION_INVALID", 400)
    ids, visible = body["ids"], body["visible"]
    if (
        type(visible) is not bool
        or not isinstance(ids, list)
        or not 1 <= len(ids) <= 600
        or any(type(identifier) is not int or not 1 <= identifier <= 2_147_483_647 for identifier in ids)
        or len(set(ids)) != len(ids)
    ):
        raise APIError("Sélectionnez de 1 à 600 articles distincts et indiquez leur visibilité.", "ARTICLE_PUBLICATION_INVALID", 400)

    rows = db.query(
        'SELECT "ID_Article", "VisibleCatalogue", "ValideArticle" FROM logistique."T_Article" '
        'WHERE "IdEntiteFk"=%s AND "ID_Article"=ANY(%s) ORDER BY "ID_Article" FOR UPDATE',
        [entity_id, ids],
    )
    if len(rows) != len(ids):
        raise APIError("Un ou plusieurs articles ne sont plus disponibles dans cette entreprise.", "ARTICLE_PUBLICATION_NOT_FOUND", 404)
    if visible and any(row["ValideArticle"] is not True for row in rows):
        raise APIError("La sélection contient des articles inactifs. Retirez-les avant de publier.", "ARTICLE_PUBLICATION_INACTIVE", 409)

    changes = [row for row in rows if row["VisibleCatalogue"] is not visible]
    if changes:
        changed_ids = [row["ID_Article"] for row in changes]
        db.query(
            'UPDATE logistique."T_Article" SET "VisibleCatalogue"=%s WHERE "IdEntiteFk"=%s AND "ID_Article"=ANY(%s)',
            [visible, entity_id, changed_ids],
        )
        audit(
            model("T_Article"),
            "ARTICLE_PUBLICATION_BATCH",
            old={"articles": [dict(ID_Article=row["ID_Article"], VisibleCatalogue=row["VisibleCatalogue"]) for row in changes]},
            new={"ids": changed_ids, "VisibleCatalogue": visible},
            actor=actor,
            entity_id=entity_id,
        )
    return {"changed": len(changes), "unchanged": len(ids) - len(changes)}


class ArticlePublicationView(APIView):
    permission_classes = [IsERPAdmin]

    def post(self, request):
        return ok(set_article_publication(request.user, request.data))
