"""Transferts internes : bons liés, preuves de rejeu et verrouillage transactionnel."""
import hmac
import json
import uuid
from decimal import Decimal, ROUND_HALF_UP
from datetime import datetime
from django.db import transaction
from psycopg.types.json import Jsonb
from rest_framework.views import APIView
from apps.core import db
from apps.core.permissions import IsERPAdmin
from apps.core.repository import audit, clean, get_record, mutate, page, positive
from apps.core.registry import model
from apps.core.responses import APIError, ExactEncoder, ok
from apps.core.tenancy import assert_document
from .depots import access, can_manage, depot, fingerprint, internal_transfer, stock
from .inventories import date_value
from .quantities import quantity, for_unit

OBJECT = {'schema': 'logistique', 'name': 'T_TransfertDepot'}
ZERO = Decimal(0)
HEADER = {'ID_DepotSourceFk', 'ID_DepotDestinationFk', 'ID_DeviseFk', 'DateTransfert', 'Motif', 'ReferenceTransfert'}


def request_id(body):
    try: return str(uuid.UUID(body.get('requestId')))
    except (ValueError, TypeError, AttributeError): raise APIError('Rouvrez le formulaire pour préparer une nouvelle demande.')


def header(actor, identifier, lock=False):
    owner = access(actor)
    clauses = ['"ID_TransfertDepot"=%s']; values = [positive(identifier)]
    if owner: clauses.append('"IdEntiteFk"=%s'); values.append(owner)
    row = db.one('SELECT * FROM logistique."T_TransfertDepot" WHERE ' + ' AND '.join(clauses) + (' FOR UPDATE' if lock else ''), values)
    if not row: raise APIError('Transfert introuvable dans cette entreprise.', 'NOT_FOUND', 404)
    return row


def state(identifier):
    return db.one('SELECT "EtatCode" FROM logistique."V_TransfertDepot" WHERE "ID_TransfertDepot"=%s', [identifier])['EtatCode']


def set_state(identifier, code):
    db.query('UPDATE logistique."T_TransfertDepot" SET "ID_EtatFk"=logistique.fn_etat_transfert(%s) WHERE "ID_TransfertDepot"=%s', [code, identifier])


def capabilities(actor, row):
    editable = can_manage(actor) and actor.organisation == row['IdEntiteFk']
    code = row.get('EtatCode') or state(row['ID_TransfertDepot'])
    return {'canEdit': editable and code == 'TR_BROUILLON', 'canValidate': editable and code == 'TR_BROUILLON',
            'canDispatch': editable and code == 'TR_VALIDE', 'canReceive': editable and code in {'TR_TRANSIT', 'TR_PARTIEL'},
            'canCancel': editable and code in {'TR_BROUILLON', 'TR_VALIDE', 'TR_TRANSIT', 'TR_PARTIEL'},
            'canResolveGap': editable and code in {'TR_TRANSIT', 'TR_PARTIEL'}}


def snapshot(actor, identifier):
    current = header(actor, identifier)
    row = db.one('SELECT v.*,s."NomDepot" AS "DepotSource",d."NomDepot" AS "DepotDestination" FROM logistique."V_TransfertDepot" v JOIN logistique."T_Depot" s ON s."ID_Depot"=v."ID_DepotSourceFk" JOIN logistique."T_Depot" d ON d."ID_Depot"=v."ID_DepotDestinationFk" WHERE v."ID_TransfertDepot"=%s', [current['ID_TransfertDepot']])
    row['lignes'] = db.query('SELECT l.*,a."NomArticle",a."ID_UniteFk",g."AbrGenerique" AS "Unite" FROM logistique."V_TransfertDepotLigne" l JOIN logistique."T_Article" a ON a."ID_Article"=l."ID_ArticleFk" LEFT JOIN referentiel."T_Generique" g ON g."ID_Generique"=a."ID_UniteFk" WHERE l."ID_TransfertDepotFk"=%s ORDER BY a."NomArticle",l."ID_ArticleFk"', [identifier])
    row['actions'] = db.query('SELECT a.*,c."CodeCmd" FROM logistique."T_TransfertDepotAction" a LEFT JOIN logistique."T_Commande" c ON c."ID_Commande"=a."ID_CommandeFk" WHERE a."ID_TransfertDepotFk"=%s ORDER BY a."ID_Action"', [identifier])
    row['bons']=[{'ID_Commande':item['ID_CommandeFk'],'CodeCmd':item['CodeCmd'],'Sens':'sortie' if item['Action']=='expedier' else 'entree'} for item in row['actions'] if item['ID_CommandeFk']]
    row['revision'] = str(row['Version']); row['capabilities'] = capabilities(actor, row)
    return clean(row)


def version(row, body):
    if str(row['Version']) != str(body.get('_version')): raise APIError('Ce transfert a changé. Rechargez sa fiche.', 'TRANSFER_CONFLICT', 409)


def proof(actor, request, signature, identifier=None):
    db.one('SELECT pg_advisory_xact_lock(hashtextextended(%s,0)) AS locked', ['transfer:' + str(actor.pk) + ':' + request])
    row = db.one('SELECT * FROM logistique."T_TransfertDepotAction" WHERE "ID_UserFk"=%s AND "RequestId"=%s', [actor.pk, request])
    if row:
        if (identifier is not None and row['ID_TransfertDepotFk'] != identifier) or not hmac.compare_digest(row['PayloadHash'], signature):
            raise APIError('Cette demande a déjà été utilisée avec d’autres informations.', 'TRANSFER_REPLAY_CONFLICT', 409)
        header(actor, row['ID_TransfertDepotFk'])
    return row


def action(actor, identifier, name, request, signature, motif='', command=None, lines=None):
    row = db.one('INSERT INTO logistique."T_TransfertDepotAction" ("ID_TransfertDepotFk","Action","RequestId","PayloadHash","ID_UserFk","Motif","ID_CommandeFk","Lignes") VALUES (%s,%s,%s,%s,%s,%s,%s,%s) RETURNING *', [identifier, name, request, signature, actor.pk, motif, command, Jsonb(json.loads(json.dumps(lines or [], cls=ExactEncoder)))])
    audit(OBJECT, 'TRANSFER_' + name.upper(), new={'ID_TransfertDepot': identifier, 'ID_Action': row['ID_Action'], 'requestId': request, 'ID_CommandeFk': command}, actor=actor)


def lock_articles(actor, rows):
    result = {}
    for item in sorted(rows, key=lambda x: x['ID_ArticleFk']):
        article = get_record(model('T_Article'), actor, {'ID_Article': item['ID_ArticleFk']}, lock=True)
        assert_document(actor, article)
        result[article['ID_Article']] = article
    return result


def parse(actor, body, editing):
    expected = {'requestId', 'transfert', 'lignes'} | ({'_version'} if editing else set())
    if not isinstance(body, dict) or set(body) != expected: raise APIError('Renseignez le transfert et son panier.')
    values = body['transfert']
    if not isinstance(values, dict) or set(values) - HEADER: raise APIError('Informations du transfert invalides.')
    data = dict(values)
    for key in ('ID_DepotSourceFk', 'ID_DepotDestinationFk', 'ID_DeviseFk'): data[key] = positive(data.get(key), key)
    if data['ID_DepotSourceFk'] == data['ID_DepotDestinationFk']: raise APIError({'ID_DepotDestinationFk': 'Choisissez un autre dépôt.'})
    for key in ('Motif', 'ReferenceTransfert'):
        value = data.get(key, '')
        if not isinstance(value, str) or len(value.strip()) > (255 if key == 'ReferenceTransfert' else 1000): raise APIError({key: 'Texte invalide ou trop long.'})
        data[key] = value.strip()
    if not data['Motif']: raise APIError({'Motif': 'Indiquez le motif du transfert.'})
    data['DateTransfert'] = date_value(data.get('DateTransfert'))
    from .currency import validate_currency
    validate_currency(data['ID_DeviseFk'], actor=actor, table='T_TransfertDepot')
    if not isinstance(body['lignes'], list) or not 1 <= len(body['lignes']) <= 100: raise APIError({'lignes': 'Ajoutez entre 1 et 100 articles.'})
    rows = []; seen = set()
    for index, item in enumerate(body['lignes']):
        if not isinstance(item, dict) or set(item) - {'ID_ArticleFk', 'QteDemandee', 'Lots', 'ObsLigne'}: raise APIError({'lignes.' + str(index): 'Ligne invalide.'})
        identifier = positive(item.get('ID_ArticleFk'))
        if identifier in seen: raise APIError({'lignes.' + str(index): 'Regroupez les quantités d’un même article.'})
        seen.add(identifier)
        amount = quantity(item.get('QteDemandee'), 'QteDemandee')
        from .lots import normalize
        lots = normalize(item.get('Lots', []), amount, allow_partial=True)
        obs = item.get('ObsLigne', '')
        if not isinstance(obs, str) or len(obs) > 1000: raise APIError({'ObsLigne': 'Observation trop longue.'})
        rows.append({'ID_ArticleFk': identifier, 'QteDemandee': amount, 'Lots': lots, 'ObsLigne': obs})
    return data, rows


def save(actor, identifier, body):
    owner = access(actor, True); data, rows = parse(actor, body, identifier is not None)
    request = request_id(body); signature = fingerprint({'entity': owner, 'id': identifier, 'body': body})
    with transaction.atomic():
        prior = proof(actor, request, signature, identifier)
        if prior: return snapshot(actor, prior['ID_TransfertDepotFk']), True
        old = header(actor, identifier, True) if identifier else None
        if old:
            assert_document(actor, old); version(old, body)
            if state(identifier) != 'TR_BROUILLON': raise APIError('Seul un transfert en préparation peut être modifié.', 'TRANSFER_LOCKED', 409)
        for key in sorted((data['ID_DepotSourceFk'], data['ID_DepotDestinationFk'])): depot(actor, key, lock=True)
        articles = lock_articles(actor, rows)
        for item in rows:
            article = articles[item['ID_ArticleFk']]
            if article['ValideArticle'] is not True: raise APIError('Un article désactivé ne peut pas être transféré.', 'ARTICLE_INACTIVE', 409)
            if article.get('ID_DeviseFk')!=data['ID_DeviseFk']:raise APIError({'ID_DeviseFk':'Les articles du transfert doivent partager la devise du transfert ; aucun taux de change implicite n’est appliqué.'},'TRANSFER_CURRENCY',409)
            for_unit(item['QteDemandee'], article['ID_UniteFk'], 'QteDemandee')
        if old:
            row = db.one('UPDATE logistique."T_TransfertDepot" SET ' + ','.join(db.ident(k) + '=%s' for k in data) + ' WHERE "ID_TransfertDepot"=%s RETURNING *', [*data.values(), identifier])
            db.query('DELETE FROM logistique."T_TransfertDepotLigne" WHERE "ID_TransfertDepotFk"=%s', [identifier])
        else:
            data.update(IdEntiteFk=owner, ID_UserFk=actor.pk)
            row = db.one('INSERT INTO logistique."T_TransfertDepot" (' + ','.join(db.ident(k) for k in data) + ',"ID_EtatFk") VALUES (' + ','.join(['%s'] * len(data)) + ',logistique.fn_etat_transfert(%s)) RETURNING *', [*data.values(), 'TR_BROUILLON'])
            identifier = row['ID_TransfertDepot']
        for item in rows:
            db.query('INSERT INTO logistique."T_TransfertDepotLigne" ("ID_TransfertDepotFk","ID_ArticleFk","QteDemandee","Lots","ObsLigne") VALUES (%s,%s,%s,%s,%s)', [identifier, item['ID_ArticleFk'], item['QteDemandee'], Jsonb(json.loads(json.dumps(item['Lots'], cls=ExactEncoder))), item['ObsLigne']])
        action(actor, identifier, 'modifier' if old else 'creer', request, signature, data['Motif'])
        db.query('SET CONSTRAINTS ALL IMMEDIATE')
        return snapshot(actor, identifier), False


def allocation(identifier, article_id, amount, supplied=None):
    """Réception/retour : seulement les lots effectivement expédiés, restant en transit."""
    rows = db.query('''SELECT l."ID_LotArticle",l."NumeroLot",l."DatePeremptionLot",sum(CASE WHEN a."Action"='expedier' THEN ml."Quantite" ELSE -ml."Quantite" END) AS remaining FROM logistique."T_TransfertDepotAction" a JOIN logistique."T_Mouvement" m ON m."ID_cmdFk"=a."ID_CommandeFk" JOIN logistique."T_MouvementLot" ml ON ml."ID_MvtFk"=m."ID_Mvt" JOIN logistique."T_LotArticle" l ON l."ID_LotArticle"=ml."ID_LotArticleFk" WHERE a."ID_TransfertDepotFk"=%s AND m."ID_ArticleFk"=%s AND a."Action" IN ('expedier','recevoir','retourner') GROUP BY l."ID_LotArticle",l."NumeroLot",l."DatePeremptionLot" ORDER BY l."DatePeremptionLot" NULLS LAST,l."ID_LotArticle"''', [identifier, article_id])
    available = {r['ID_LotArticle']: r for r in rows}
    result = []; remaining = amount
    if supplied:
        seen = set()
        for item in supplied:
            key = positive(item.get('ID_LotArticle')); qty = quantity(item.get('Quantite'))
            if key in seen or key not in available or qty > available[key]['remaining']: raise APIError({'Lots': 'La quantité du lot dépasse le solde réellement en transit.'}, 'TRANSFER_LOT_EXCEEDED', 409)
            seen.add(key); r = available[key]
            result.append({'NumeroLot': r['NumeroLot'], 'DatePeremptionLot': r['DatePeremptionLot'].isoformat() if r['DatePeremptionLot'] else None, 'Quantite': qty}); remaining -= qty
        if remaining < 0: raise APIError({'Lots': 'La ventilation dépasse la quantité de la ligne.'})
    else:
        for r in rows:
            qty = min(max(r['remaining'], ZERO), remaining)
            if qty: result.append({'NumeroLot': r['NumeroLot'], 'DatePeremptionLot': r['DatePeremptionLot'].isoformat() if r['DatePeremptionLot'] else None, 'Quantite': qty}); remaining -= qty
    # Sans lot n'est autorisé que pour la part initialement expédiée sans lot.
    transit = db.one('SELECT "QteTransit" FROM logistique."V_TransfertDepotLigne" WHERE "ID_TransfertDepotFk"=%s AND "ID_ArticleFk"=%s', [identifier, article_id])['QteTransit']
    if remaining > transit - sum((max(r['remaining'], ZERO) for r in rows), ZERO): raise APIError({'Lots': 'Ventilez cette quantité sur les lots expédiés.'}, 'TRANSFER_LOT_REQUIRED', 409)
    return result


def make_document(actor, current, rows, operation):
    from .lots import stock_document_types
    from .services import mutate_line
    types = stock_document_types(actor, lock=True); sign = -1 if operation == 'expedition' else 1
    if sign not in types: raise APIError('Configurez les bons d’entrée et de sortie.', 'TRANSFER_CONFIGURATION', 409)
    selected = current['ID_DepotDestinationFk'] if operation == 'reception' else current['ID_DepotSourceFk']
    priced=[]
    for item in rows:
        article=get_record(model('T_Article'),actor,{'ID_Article':item['ID_ArticleFk']})
        if operation=='expedition':
            cost=db.one('SELECT "CoutUnitaireMoyen" cost FROM logistique."V_ValorisationStock" WHERE "ID_Article"=%s AND "ID_DeviseFk"=%s',[item['ID_ArticleFk'],current['ID_DeviseFk']])
        else:
            cost=db.one('SELECT c."CoutUnitaire" cost FROM logistique."V_CoutMouvement" c JOIN logistique."T_Mouvement" m ON m."ID_Mvt"=c."ID_Mvt" JOIN logistique."T_Commande" b ON b."ID_Commande"=m."ID_cmdFk" WHERE b."ID_TransfertDepotFk"=%s AND b."OperationTransfert"=%s AND m."ID_ArticleFk"=%s',[current['ID_TransfertDepot'],'expedition',item['ID_ArticleFk']])
        known=cost is not None and cost['cost'] is not None
        price=Decimal(str(cost['cost'] if known else article.get('PUArticle') or ZERO)).quantize(Decimal('0.01'),rounding=ROUND_HALF_UP)
        priced.append((item,price,known))
    with internal_transfer():
        command = mutate('T_Commande', actor, {'ID_TypeCmdFk': types[sign], 'ID_DeviseFk': current['ID_DeviseFk'], 'ID_DepotFk': selected,
            'ID_TransfertDepotFk': current['ID_TransfertDepot'], 'OperationTransfert': operation, 'DateCmd': datetime.now().astimezone(),
            'RefCmd': current['CodeTransfert'], 'ObsCmd': ('Transfert interne — ' + current['Motif'])[:255]}, operation='create')
        for item,price,known in priced:
            # Le journal conserve le coût d'origine exact, indépendamment des deux décimales du bon.
            mutate_line(actor, command['ID_Commande'], {'ID_ArticleFk': item['ID_ArticleFk'], 'QteCmdDetail': item['Quantite'], 'PUCmdDetail': price, 'Lots': item.get('Lots', []),
                'ObsCmdDetail':'Coût CUMP source connu.' if known else 'Prix indicatif catalogue ; coût de stock non déterminé.'})
    return command['ID_Commande']


def transition(actor, identifier, name, body):
    owner = access(actor, True)
    if not isinstance(body, dict) or set(body) - {'requestId', '_version', 'motif', 'lignes'}: raise APIError('Demande de transfert invalide.')
    request = request_id(body); signature = fingerprint({'entity': owner, 'id': identifier, 'action': name, 'body': body})
    with transaction.atomic():
        prior = proof(actor, request, signature, identifier)
        if prior: return snapshot(actor, identifier), True
        current = header(actor, identifier, True); assert_document(actor, current); version(current, body)
        code = state(identifier)
        permitted = {'valider': {'TR_BROUILLON'}, 'expedier': {'TR_VALIDE'}, 'receptionner': {'TR_TRANSIT', 'TR_PARTIEL'}, 'annuler': {'TR_BROUILLON', 'TR_VALIDE', 'TR_TRANSIT', 'TR_PARTIEL'}, 'traiter-ecart': {'TR_TRANSIT', 'TR_PARTIEL'}}
        if name not in permitted or code not in permitted[name]: raise APIError('Cette action n’est plus possible dans l’état actuel du transfert.', 'TRANSFER_STATE', 409)
        lines = db.query('SELECT * FROM logistique."V_TransfertDepotLigne" WHERE "ID_TransfertDepotFk"=%s ORDER BY "ID_ArticleFk"', [identifier])
        if not lines: raise APIError('Ajoutez les articles à transférer.')
        for key in sorted((current['ID_DepotSourceFk'], current['ID_DepotDestinationFk'])): depot(actor, key, lock=True)
        articles = lock_articles(actor, lines)
        motif = body.get('motif', '')
        if not isinstance(motif, str) or len(motif.strip()) > 1000: raise APIError({'motif': 'Motif invalide.'})
        motif = motif.strip(); command = None; action_name = name; action_lines = []
        if name in {'valider', 'expedier'}:
            for item in lines:
                local = stock(item['ID_ArticleFk'], current['ID_DepotSourceFk'])
                available = local['StockDisponible'] + (item['QteReservee'] if name == 'expedier' else ZERO)
                if item['QteDemandee'] > available: raise APIError({'lignes': articles[item['ID_ArticleFk']]['NomArticle'] + ' : quantité disponible insuffisante au dépôt source.'}, 'DEPOT_STOCK_INSUFFICIENT', 409)
                allocated=sum((quantity(lot.get('Quantite')) for lot in item.get('Lots') or []),ZERO)
                if item['QteDemandee']-allocated>local['StockSansLot']:
                    raise APIError({'lignes':articles[item['ID_ArticleFk']]['NomArticle']+' : sélectionnez les lots du dépôt source ou utilisez la proposition par péremption.'},'TRANSFER_LOT_REQUIRED',409)
            if name == 'valider': set_state(identifier, 'TR_VALIDE')
            else:
                set_state(identifier, 'TR_TRANSIT')
                command = make_document(actor, current, [{'ID_ArticleFk': item['ID_ArticleFk'], 'Quantite': item['QteDemandee'], 'Lots': item.get('Lots') or []} for item in lines], 'expedition')
        elif name == 'annuler' and code in {'TR_BROUILLON', 'TR_VALIDE'}:
            if not motif: raise APIError({'motif': 'Indiquez le motif de l’annulation.'})
            set_state(identifier, 'TR_ANNULE')
        else:
            if name in {'annuler', 'traiter-ecart'} and not motif: raise APIError({'motif': 'Indiquez un motif pour conserver l’historique.'})
            selected = body.get('lignes')
            if selected is None and name == 'annuler': selected = [{'ID_ArticleFk': item['ID_ArticleFk'], 'Quantite': item['QteTransit']} for item in lines if item['QteTransit'] > 0]
            if not isinstance(selected, list) or not selected: raise APIError({'lignes': 'Indiquez les quantités concernées.'})
            by_id = {item['ID_ArticleFk']: item for item in lines}; seen = set(); prepared = []
            for item in selected:
                if not isinstance(item, dict) or set(item) - {'ID_ArticleFk', 'Quantite', 'Lots'}: raise APIError({'lignes': 'Ligne invalide.'})
                key = positive(item.get('ID_ArticleFk')); qty = quantity(item.get('Quantite'))
                if key in seen or key not in by_id or qty > by_id[key]['QteTransit']: raise APIError({'lignes': 'La quantité dépasse le solde encore en transit.'}, 'TRANSFER_QUANTITY_EXCEEDED', 409)
                if name == 'traiter-ecart' and qty != by_id[key]['QteTransit']:
                    raise APIError({'lignes':'Le constat d’écart clôture tout le solde encore en transit de cet article. Réceptionnez d’abord les quantités retrouvées.'},'TRANSFER_GAP_BALANCE',409)
                seen.add(key); for_unit(qty, articles[key]['ID_UniteFk'], 'Quantite')
                prepared.append({'ID_ArticleFk': key, 'Quantite': qty, 'Lots': allocation(identifier, key, qty, item.get('Lots')) if name != 'traiter-ecart' else []})
            remaining = sum((item['QteTransit'] for item in lines), ZERO) - sum((item['Quantite'] for item in prepared), ZERO)
            received = sum((item['QteRecue'] for item in lines), ZERO)
            next_code = 'TR_PARTIEL' if remaining > 0 else 'TR_ANNULE' if name == 'annuler' and received == 0 else 'TR_TERMINE'
            set_state(identifier, next_code)
            if name == 'traiter-ecart':
                action_name = 'clore_ecart'; action_lines = [{'ID_ArticleFk': item['ID_ArticleFk'], 'Quantite': item['Quantite']} for item in prepared]
            else:
                action_name = 'retourner' if name == 'annuler' else 'recevoir'
                command = make_document(actor, current, prepared, 'retour' if name == 'annuler' else 'reception')
        action(actor, identifier, action_name, request, signature, motif, command, action_lines)
        db.query('SET CONSTRAINTS ALL IMMEDIATE')
        return snapshot(actor, identifier), False


class TransfersView(APIView):
    permission_classes = [IsERPAdmin]
    def get(self, request, pk=None, action=None):
        owner = access(request.user)
        if pk:
            row = snapshot(request.user, pk)
            return ok(row, meta={'revision': row['revision'], **row['capabilities']})
        from .depot_registers import listing
        rows, meta = listing(request.user, 'transferts', request.query_params)
        return ok(rows, meta=meta)
    def post(self, request, pk=None, action=None):
        row, replayed = transition(request.user, positive(pk), action, request.data) if pk else save(request.user, None, request.data)
        return ok(row, status=200 if replayed else 201)
    def put(self, request, pk): return ok(save(request.user, positive(pk), request.data)[0])
