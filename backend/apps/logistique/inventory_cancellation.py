"""Annulation tracée : une ligne inverse, les mêmes lots, aucun stock écrit directement."""
import hmac
from django.db import transaction
from django.utils import timezone
from apps.core import db
from apps.core.repository import mutate, audit
from apps.core.responses import APIError
from .inventories import access, header, snapshot, check_version, request_id, digest, OBJECT
from .lots import validate_stock


def cancel(actor, identifier, body):
    entity = access(actor, True)
    if not isinstance(body, dict) or set(body) != {'requestId', '_version', 'motif'}:
        raise APIError('Demande d’annulation invalide.')
    reason = body.get('motif')
    if not isinstance(reason, str) or not 1 <= len(reason.strip()) <= 1000:
        raise APIError({'motif': 'Précisez le motif de l’annulation (1 à 1 000 caractères).'})
    reason = reason.strip()
    request = request_id(body)
    fingerprint = digest({'entity': entity, 'inventory': identifier, 'version': str(body['_version']), 'motif': reason})
    with transaction.atomic():
        record = header(actor, identifier, True)
        if record['Etat'] == 'annule':
            if str(record['AnnulationRequest']) == request and hmac.compare_digest(record['AnnulationHash'], fingerprint):
                return snapshot(actor, identifier), True
            raise APIError('La validation de cet inventaire a déjà été annulée.', 'INVENTORY_CLOSED', 409)
        if record['Etat'] != 'valide':
            raise APIError('Seul un inventaire validé peut être annulé.', 'INVENTORY_NOT_VALIDATED', 409)
        check_version(record, body['_version'])
        lines = db.query('SELECT * FROM logistique."T_InventaireLigne" WHERE "ID_InventaireFk"=%s ORDER BY "ID_ArticleFk"', [identifier])
        # Ordre stable des verrous ; le stock courant peut avoir évolué depuis le comptage.
        for line in lines:
            article = db.one('SELECT "ID_Article" FROM logistique."T_Article" WHERE "ID_Article"=%s AND "IdEntiteFk"=%s FOR UPDATE', [line['ID_ArticleFk'], entity])
            if not article:
                raise APIError('Article hors de cette entreprise.', 'FORBIDDEN', 403)
        db.query('''UPDATE logistique."T_Inventaire" SET "Etat"='annule',"AnnuleLe"=clock_timestamp(),
            "ID_AnnulateurFk"=%s,"MotifAnnulation"=%s,"AnnulationRequest"=%s,"AnnulationHash"=%s WHERE "ID_Inventaire"=%s''',
            [actor.pk, reason, request, fingerprint, identifier])
        commands = []
        for line in lines:
            if line['QteComptee'] == line['QteTheorique']:
                continue
            original = db.one('''SELECT d.*,c."ID_DeviseFk",m."ID_Mvt",m."SigneStock" FROM logistique."T_CommandeDetail" d
                JOIN logistique."T_Commande" c ON c."ID_Commande"=d."ID_CmdFk"
                JOIN logistique."V_MouvementStock" m ON m."ID_cmdFk"=d."ID_CmdFk" AND m."ID_ArticleFk"=d."ID_ArticleFk"
                WHERE d."ID_CmdFk"=%s AND d."ID_ArticleFk"=%s AND c."IdEntiteFk"=%s''',
                [line['ID_CommandeCorrectionFk'], line['ID_ArticleFk'], entity])
            if not original or original['SigneStock'] not in (-1, 1):
                raise APIError('Le mouvement d’origine doit être vérifié avant annulation.', 'INVENTORY_SOURCE_INVALID', 409)
            kind = db.one('''SELECT g."ID_Generique" FROM referentiel."T_Generique" g JOIN referentiel."T_CategorieGenerique" c ON c."ID_CategorieGenerique"=g."ID_CategorieGeneriqueFk"
                WHERE g."ID_CategorieGeneriqueFk"=64 AND g."AbrGenerique" ILIKE %s AND g."ValideGenerique" IS TRUE AND c."ValideCategorieGenerique" IS TRUE ORDER BY g."ID_Generique" LIMIT 1''',
                ['sort%' if original['SigneStock'] == 1 else 'entr%'])
            if not kind:
                raise APIError('Configurez les types de bon Entrée et Sortie dans les références.', 'INVENTORY_TYPE_REQUIRED', 409)
            command = mutate('T_Commande', actor, {'ID_TypeCmdFk': kind['ID_Generique'], 'ID_DeviseFk': original['ID_DeviseFk'],
                'DateCmd': timezone.now(), 'RefCmd': f'Annulation inv-{identifier}', 'ObsCmd': reason[:255]}, operation='create')
            cid = command['ID_Commande']
            # Les triggers existants créent l’unique mouvement. On conserve le prix réellement utilisé,
            # y compris pour un article devenu inactif, sans le réactiver ni recalculer son prix catalogue.
            db.query('''INSERT INTO logistique."T_CommandeDetail" ("ID_CmdFk","ID_ArticleFk","QteCmdDetail","PUCmdDetail","ObsCmdDetail")
                VALUES (%s,%s,%s,%s,%s)''', [cid, line['ID_ArticleFk'], original['QteCmdDetail'], original['PUCmdDetail'], reason[:255]])
            movement = db.one('SELECT "ID_Mvt" FROM logistique."T_Mouvement" WHERE "ID_cmdFk"=%s AND "ID_ArticleFk"=%s', [cid, line['ID_ArticleFk']])
            db.query('''INSERT INTO logistique."T_MouvementLot" ("ID_MvtFk","ID_LotArticleFk","Quantite")
                SELECT %s,"ID_LotArticleFk","Quantite" FROM logistique."T_MouvementLot" WHERE "ID_MvtFk"=%s''', [movement['ID_Mvt'], original['ID_Mvt']])
            validate_stock(line['ID_ArticleFk'])
            db.query('UPDATE logistique."T_InventaireLigne" SET "ID_CommandeAnnulationFk"=%s WHERE "ID_InventaireFk"=%s AND "ID_ArticleFk"=%s', [cid, identifier, line['ID_ArticleFk']])
            commands.append(cid)
        # Vérifie les contraintes différées avant de construire la réponse.
        db.query('SET CONSTRAINTS ALL IMMEDIATE')
        audit(OBJECT, 'INVENTORY_CANCEL', old=record, new={'ID_Inventaire': identifier, 'requestId': request, 'hash': fingerprint, 'motif': reason, 'bons': commands}, actor=actor)
        return snapshot(actor, identifier), False
