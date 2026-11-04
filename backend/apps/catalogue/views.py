from django.conf import settings
from rest_framework.views import APIView
from apps.core.permissions import HasModuleAccess
from apps.core import db
from apps.core.repository import page, positive
from apps.core.responses import ok, APIError
from apps.core.tenancy import read_entity
from apps.core.reference_labels import reference_label

EXPERT_SQL = 'SELECT p.* FROM professionnel."V_Professionnel_Public" p'


def recipient(kind, target_id, *, actor=None, contact=False, lock=False):
    if kind == "expert":
        from apps.professionnels.services import public_record, public_profile
        expert = public_profile(public_record(target_id, actor=actor, contact=contact, lock=lock), actor)
        structure = expert['structures'][0] if expert['structures'] else {}
        return {**expert, 'type': 'expert', 'structureId': structure.get('id'),
                'publicAddress': structure.get('address'), 'publicPhone': structure.get('phone')}
    if kind == "structure":
        if contact:
            from .structures import contact_available
            if lock:
                # Même verrou parent que la fiche versionnée : une publication
                # ne peut être retirée entre ce contrôle et la conversation.
                db.one('SELECT "IdEntite" FROM systeme."T_Entite" WHERE "IdEntite"=%s FOR SHARE', [target_id])
            if actor is None or not contact_available(actor, target_id):
                raise APIError('Structure introuvable ou contact indisponible.', 'NOT_FOUND', 404)
        # L'historique d'une conversation déjà autorisée conserve son identité
        # sûre après retrait de publication. Cette projection n'est pas un
        # accès au profil privé, au logo ni aux identifiants légaux.
        entity = db.one('''SELECT e."IdEntite",e."NomEntite",e."AdresseEntite",e."PhoneEntite",
            jsonb_build_object('ID_Generique',g."ID_Generique",'AbrGenerique',g."AbrGenerique",'NomGenerique',g."NomGenerique") "T_Generique"
            FROM systeme."T_Entite" e LEFT JOIN referentiel."T_Generique" g ON g."ID_Generique"=e."IdTypeEntiteFk"
            WHERE e."IdEntite"=%s''', [target_id])
        if not entity:
            raise APIError("Structure introuvable.", "NOT_FOUND", 404)
        return {
            "type": "structure",
            "id": entity["IdEntite"],
            "name": entity["NomEntite"],
            "structureType": reference_label(entity["T_Generique"]) if entity["T_Generique"].get("ID_Generique") is not None else None,
            "publicAddress": entity["AdresseEntite"],
            "publicPhone": entity["PhoneEntite"],
        }
    raise APIError("type doit être expert ou structure.")


class PublicView(APIView):
    # Le nom conserve le contrat des projections ; leur accès ERP exige un compte actif.
    permission_classes = [HasModuleAccess]

    def get(self, request, kind):
        if kind == 'pharmacies':
            from .territorial_structures import listing, parameters
            result = listing(parameters(request.query_params))
            return ok(result['rows'], meta={key: result[key] for key in ('total', 'take', 'skip')} | {'count': len(result['rows'])})
        params = request.query_params.dict()
        take, skip = page({**params, "take": params.get("take", 20)})
        take = min(take, 100)
        q = str(params.get("q", "")).strip()
        if len(q) > 300:
            raise APIError("Recherche trop longue.")
        if kind == "chat/context":
            typ = params.get("type")
            r = recipient(typ, positive(params.get("id")), actor=request.user, contact=True)
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
            sql = '''SELECT
              (SELECT count(*) FROM logistique."V_OffreArticle") AS "productsCount",
              (SELECT count(*) FROM geolocalisation."V_StructureSanitairePublique") AS "structuresCount",
              (SELECT count(*) FROM professionnel."V_Professionnel_Public") AS "expertsCount",
              (SELECT count(*) FROM referentiel."T_Generique" g
                JOIN referentiel."T_CategorieGenerique" c ON c."ID_CategorieGenerique"=g."ID_CategorieGeneriqueFk"
                WHERE g."ValideGenerique"=true AND lower(c."NomCategorieGenerique")='maladie'
                  AND referentiel.fn_reference_visible(g."ID_Generique",%s)) AS "diseasesCount",
              (SELECT count(*) FROM geolocalisation."V_StructureSanitairePublique") AS "activeStructures"'''
            data = db.one(sql, [read_entity(request.user)])
            return ok(data)
        if kind == "articles":
            from .offers import offers
            rows, meta = offers(q, take, skip)
            return ok(rows, meta=meta)
        elif kind == "experts":
            from apps.professionnels.services import directory
            result = directory(request.user, {**params, 'take': take, 'skip': skip})
            return ok(result['rows'], meta={'take': take, 'skip': skip, 'count': len(result['rows']), 'total': result['total']})
        else:
            raise APIError("Ressource publique introuvable.", "NOT_FOUND", 404)
