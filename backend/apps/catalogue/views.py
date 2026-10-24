from django.conf import settings
from rest_framework.views import APIView
from rest_framework.permissions import AllowAny
from apps.core import db
from apps.core.repository import page, positive
from apps.core.responses import ok, APIError

EXPERT_SQL = 'SELECT p.* FROM professionnel."V_Professionnel_Public" p'
ENTITY_SQL = 'SELECT e.* FROM systeme."V_Entite_Public" e'


def recipient(kind, target_id):
    if kind == "expert":
        expert = db.one(
            EXPERT_SQL
            + ' WHERE p."IdProfessionnel"=%s AND p."ValideProfessionnel"=true',
            [target_id],
        )
        if not expert:
            raise APIError("Expert introuvable.", "NOT_FOUND", 404)
        user = expert["T_Utilisateurs"]
        links = expert["T_Professionnel_Entite"]
        entity = links[0]["T_Entite"] if links else {}
        return {
            "type": "expert",
            "id": expert["IdProfessionnel"],
            "firstName": user.get("PrenomUser") or "",
            "lastName": user.get("NomUser") or "",
            "fullName": (
                (user.get("PrenomUser") or "") + " " + (user.get("NomUser") or "")
            ).strip(),
            "photo": user.get("UrlPhoto"),
            "professionalType": expert["T_GeneriqueType"].get("NomGenerique"),
            "specialty": expert["T_GeneriqueSpecialite"].get("NomGenerique"),
            "experience": expert["ExperienceAns"],
            "structure": entity.get("NomEntite"),
            "structureId": entity.get("IdEntite"),
            "publicAddress": entity.get("AdresseEntite"),
            "publicPhone": entity.get("PhoneEntite"),
        }
    if kind == "structure":
        entity = db.one(
            ENTITY_SQL + ' WHERE e."IdEntite"=%s AND e."ValideEntite"=true', [target_id]
        )
        if not entity:
            raise APIError("Structure introuvable.", "NOT_FOUND", 404)
        return {
            "type": "structure",
            "id": entity["IdEntite"],
            "name": entity["NomEntite"],
            "structureType": entity["T_Generique"].get("NomGenerique"),
            "publicAddress": entity["AdresseEntite"],
            "publicPhone": entity["PhoneEntite"],
        }
    raise APIError("type doit être expert ou structure.")


class PublicView(APIView):
    authentication_classes = []
    permission_classes = [AllowAny]

    def get(self, request, kind):
        params = request.query_params.dict()
        take, skip = page({**params, "take": params.get("take", 20)})
        take = min(take, 100)
        q = str(params.get("q", "")).strip()
        if len(q) > 300:
            raise APIError("Recherche trop longue.")
        values = []
        if kind == "chat/context":
            typ = params.get("type")
            r = recipient(typ, positive(params.get("id")))
            target = {
                "id": r["id"],
                "type": typ,
                "name": r.get("fullName") or r.get("name"),
                "specialty": r.get("specialty") or r.get("structureType"),
                "structure": r.get("structure") or r.get("publicPhone"),
            }
            return ok(
                {
                    "threadKey": typ + ":" + str(r["id"]),
                    "target": target,
                    "capabilities": {
                        "canBootstrapThread": True,
                        "canPersistMessages": not settings.DB_READ_ONLY,
                    },
                }
            )
        if kind == "stats":
            sql = '''SELECT (SELECT count(*) FROM logistique."V_Article" WHERE "ValideArticle"=true) AS "productsCount",(SELECT count(*) FROM systeme."V_Entite_Public") AS "pharmaciesCount",(SELECT count(*) FROM professionnel."V_Professionnel_Public") AS "expertsCount",(SELECT count(*) FROM referentiel."T_Generique" g JOIN referentiel."T_CategorieGenerique" c ON c."ID_CategorieGenerique"=g."ID_CategorieGeneriqueFk" WHERE g."ValideGenerique"=true AND lower(c."NomCategorieGenerique")='maladie') AS "diseasesCount",(SELECT count(*) FROM systeme."T_Entite" WHERE "ValideEntite"=true) AS "activeStructures"'''
            data = db.one(sql)
            data.update(
                latestAnnouncements=min(data["productsCount"], 6),
                responseLabel="Réponse rapide",
            )
            return ok(data)
        if kind == "articles":
            sql = 'SELECT "ID_Article","NomArticle","RefArticle","PVArticle","PhotoArticle","ObsArticle","ValideArticle" FROM logistique."V_Article" WHERE "ValideArticle"=true'
            fields = ['"NomArticle"', '"RefArticle"', '"ObsArticle"']
            order = '"NomArticle" ASC,"ID_Article" DESC'
        elif kind == "pharmacies":
            sql = ENTITY_SQL + ' WHERE e."ValideEntite"=true'
            fields = ['e."NomEntite"', 'e."AdresseEntite"', 'e."PhoneEntite"']
            order = 'e."NomEntite" ASC,e."IdEntite" DESC'
        elif kind == "experts":
            sql = EXPERT_SQL + ' WHERE p."ValideProfessionnel"=true'
            fields = [
                "(p.\"T_Utilisateurs\"->>'NomUser')",
                "(p.\"T_Utilisateurs\"->>'PrenomUser')",
                "(p.\"T_GeneriqueSpecialite\"->>'NomGenerique')",
                "(p.\"T_GeneriqueType\"->>'NomGenerique')",
            ]
            order = 'p."IdProfessionnel" DESC'
        elif kind == "maladies":
            sql = """SELECT g."ID_Generique",g."NomGenerique",g."AbrGenerique",g."ObsGenerique",jsonb_build_object('ID_CategorieGenerique',c."ID_CategorieGenerique",'NomCategorieGenerique',c."NomCategorieGenerique") AS "T_CategorieGenerique" FROM referentiel."T_Generique" g JOIN referentiel."T_CategorieGenerique" c ON c."ID_CategorieGenerique"=g."ID_CategorieGeneriqueFk" WHERE g."ValideGenerique"=true AND lower(c."NomCategorieGenerique")='maladie' """
            fields = ['g."NomGenerique"', 'g."AbrGenerique"', 'g."ObsGenerique"']
            order = 'g."NomGenerique" ASC,g."ID_Generique" DESC'
        else:
            raise APIError("Ressource publique introuvable.", "NOT_FOUND", 404)
        if q:
            sql += " AND (" + " OR ".join(f + " ILIKE %s" for f in fields) + ")"
            values.extend(["%" + q + "%"] * len(fields))
        rows = db.query(
            sql + " ORDER BY " + order + " LIMIT %s OFFSET %s", [*values, take, skip]
        )
        return ok(rows, meta={"take": take, "skip": skip, "count": len(rows)})
