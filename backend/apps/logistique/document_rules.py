"""Révisions et limites des bons/lignes, sans doubler les effets de stock des triggers."""
import hashlib
import hmac
import json
from apps.core import db
from apps.core.registry import model
from apps.core.responses import APIError, ExactEncoder


def revision(record, kind='bon'):
    fields = [column['column_name'] for column in model('T_Commande' if kind == 'bon' else 'T_CommandeDetail')['columns']]
    snapshot = {field: record.get(field) for field in fields}
    if kind == 'ligne':
        snapshot['Lots'] = [{key: item.get(key) for key in ('ID_LotArticle','NumeroLot','DatePeremptionLot','Quantite')}
                            for item in record.get('Lots', [])]
    encoded = json.dumps(snapshot, cls=ExactEncoder, sort_keys=True, ensure_ascii=False, separators=(',', ':'))
    return hashlib.sha256(encoded.encode('utf8')).hexdigest()


def check_revision(record, received, kind='bon'):
    if not isinstance(received,str) or not hmac.compare_digest(revision(record,kind),received):
        raise APIError('Ce bon a changé. Rechargez la fiche avant d’enregistrer.' if kind == 'bon' else
                       'Cette ligne ou ses lots ont changé. Rechargez la fiche avant d’enregistrer.',
                       'ORDER_CONFLICT' if kind == 'bon' else 'LINE_CONFLICT',409)


def closed(record):
    return bool(db.one('SELECT logistique.fn_commande_cloturee(%s) AS closed',[record.get('StatusFacture')])['closed'])



def stock_write_state(record):
    """Le panier devient historique après émission ou restitution ; les métadonnées financières restent distinctes."""
    from .stock_returns import return_context
    inventory=bool(db.one('SELECT EXISTS(SELECT FROM logistique."T_InventaireLigne" l JOIN logistique."T_Inventaire" h ON h."ID_Inventaire"=l."ID_InventaireFk" WHERE (%s IN (l."ID_CommandeCorrectionFk",l."ID_CommandeAnnulationFk")) AND h."Etat" IN (\'valide\',\'annule\')) AS present',[record['ID_Commande']])['present'])
    returns=return_context(record['ID_Commande'])
    invoice=bool(str(record.get('CodeFacture') or '').strip())
    if not invoice and db.one("SELECT to_regclass('logistique.\"T_Facture\"') IS NOT NULL AS ready")['ready']:
        invoice=bool(db.one('SELECT EXISTS(SELECT 1 FROM logistique."T_Facture" WHERE "ID_CommandeFk"=%s) AS present',[record['ID_Commande']])['present'])
    is_closed=closed(record)
    reason=('Ce bon corrige un inventaire validé. Créez un nouveau comptage pour le corriger.' if inventory else 'Ce bon est clôturé.' if is_closed else
            'Un bon de retour est conservé avec son historique.' if returns['isReturn'] else
            'Ce bon possède des retours. Son panier est conservé.' if returns['hasReturns'] else
            'Une facture a été émise. Le panier est conservé.' if invoice else '')
    return {'canEdit':not reason,'reason':reason,'invoice':invoice,'closed':is_closed,'returns':returns}


def assert_stock_editable(record):
    state=stock_write_state(record)
    if not state['canEdit']:raise APIError(state['reason'],'ORDER_HISTORY_LOCKED',409)
    return state


FINANCIAL_METADATA={'CodeFacture','DateFacture','DateEcheancePaiement','DateHeureAutoFacture','StatusFacture',
                    'ID_ModePaiementFk','ID_ConditionPaiementFk','MontantRegleFacture','MontantResteFacture'}


def protect_stock_header(data,old):
    if not old:return
    state=stock_write_state(old)
    if state['canEdit']:return
    if state['returns']['isReturn']:
        if any(value!=old.get(key) for key,value in data.items()):
            raise APIError(state['reason'],'ORDER_HISTORY_LOCKED',409)
    elif any(key not in FINANCIAL_METADATA and value!=old.get(key) for key,value in data.items()):
        raise APIError(state['reason'],'ORDER_HISTORY_LOCKED',409)


def usage(record, actor):
    pk=record['ID_Commande']
    links=db.one('''SELECT
        EXISTS(SELECT 1 FROM logistique."T_CommandeDetail" WHERE "ID_CmdFk"=%s) AS lignes,
        EXISTS(SELECT 1 FROM logistique."T_Mouvement" WHERE "ID_cmdFk"=%s) AS mouvements,
        EXISTS(SELECT 1 FROM logistique."T_Reglements" WHERE "CodeFactureFk"=%s) AS reglements''',
        [pk,pk,record.get('CodeFacture')])
    links['dossiers']=False
    if db.one('''SELECT to_regclass('logistique."T_DossierSuiviMembre"') IS NOT NULL AS ready''')['ready']:
        links['dossiers']=bool(db.one('''SELECT EXISTS(SELECT 1 FROM logistique."T_DossierSuiviMembre" WHERE "ID_CommandeFk"=%s) AS present''',[pk])['present'])
    invoice=bool(str(record.get('CodeFacture') or '').strip())
    state=stock_write_state(record)
    is_closed=state['closed']
    reason=state['reason']
    delete_reason=reason or ('Un bon avec des lignes ou un historique ne peut pas être supprimé.' if any(links.values()) else
                            'Un bon facturé ne peut pas être supprimé.' if invoice else '')
    fixed=links['lignes'] or links['mouvements'] or links['reglements'] or invoice
    return {'revision':revision(record),'canEdit':not is_closed,'editReason':reason,
            'canDelete':not delete_reason,'deleteReason':delete_reason,
            'canChangeType':not fixed and not is_closed,'canChangeCurrency':not fixed and not is_closed,
            'canChangeInvoiceCode':not invoice and not links['reglements'] and not is_closed and not state['returns']['isReturn']}


def line_usage(record, parent):
    state=stock_write_state(parent)
    return {'revision':revision(record,'ligne'),'canEdit':state['canEdit'],'canDelete':state['canEdit'],
            'editReason':state['reason']}


def validate_header(data, old, actor):
    protect_stock_header(data,old)
    if old:
        for field in ('ID_UserFk','DateHeureAutoCmd','DateHeureAutoFacture'):
            if field in data:
                if data[field] != old.get(field):
                    raise APIError('L’auteur et les dates automatiques sont conservés.','ORDER_VALIDATION',400)
                del data[field]
        if data.get('CodeFacture',old.get('CodeFacture')) != old.get('CodeFacture') and db.one('SELECT EXISTS(SELECT 1 FROM logistique."T_Reglements" WHERE "CodeFactureFk"=%s) AS present',[old.get('CodeFacture')])['present']:
            raise APIError('La référence de facture est conservée après un règlement.','INVOICE_LOCKED',409)
        if data.get('ID_TypeCmdFk',old.get('ID_TypeCmdFk')) != old.get('ID_TypeCmdFk') and not usage(old,actor)['canChangeType']:
            raise APIError('Le type ne peut plus changer après une ligne, un mouvement ou une facture.','ORDER_TYPE_LOCKED',409)
    else:
        if data.get('ID_UserFk',actor.pk) != actor.pk:
            raise APIError('Le responsable du bon est le compte connecté.','ORDER_VALIDATION',400)
        data['ID_UserFk']=actor.pk
        from datetime import datetime,timezone
        data['DateHeureAutoCmd']=datetime.now(timezone.utc)
        data.pop('DateHeureAutoFacture',None)


def assert_deletable(record,actor):
    state=usage(record,actor)
    if not state['canDelete']:
        raise APIError(state['deleteReason'],'ORDER_IN_USE',409)


def editable_record(obj, source, actor, keys):
    """Une projection brute et descriptive au même instant, sans COALESCE pour les champs éditables."""
    sources={'T_Commande':'V_Commande','T_CommandeDetail':'V_CommandeDetail'}
    if obj['schema']!='logistique' or source['schema']!='logistique' or sources.get(obj['name'])!=source['name']:
        raise APIError('Source de modification non autorisée.','INVALID_EDIT_SOURCE',500)
    from apps.core.repository import predicate
    raw_names=[column['column_name'] for column in obj['columns']]
    view_names=[column['column_name'] for column in source['columns']]
    if not obj['primaryKey'] or any(key not in view_names for key in obj['primaryKey']):
        raise APIError('La clé de modification est indisponible.','INVALID_EDIT_SOURCE',503)
    names=[*view_names,*(name for name in raw_names if name not in view_names)]
    columns=[('t.' if name in raw_names else 'v.')+db.ident(name)+' AS '+db.ident(name) for name in names]
    if obj['name']=='T_CommandeDetail':
        # Même snapshot que la ligne : une correction concurrente ne mélange pas ancien prix et nouveaux lots.
        columns.append('''(SELECT COALESCE(jsonb_agg(jsonb_build_object(
            'ID_LotArticle',l."ID_LotArticle",'NumeroLot',l."NumeroLot",
            'DatePeremptionLot',l."DatePeremptionLot",'Quantite',ml."Quantite")
            ORDER BY l."NumeroLot",l."ID_LotArticle"),'[]'::jsonb)
            FROM logistique."T_Mouvement" m JOIN logistique."T_MouvementLot" ml ON ml."ID_MvtFk"=m."ID_Mvt"
            JOIN logistique."T_LotArticle" l ON l."ID_LotArticle"=ml."ID_LotArticleFk"
            WHERE m."ID_cmdFk"=t."ID_CmdFk" AND m."ID_ArticleFk"=t."ID_ArticleFk") AS "Lots"''')
    join=' AND '.join('t.'+db.ident(key)+'=v.'+db.ident(key) for key in obj['primaryKey'])
    where,values=predicate(source,actor,keys=keys)
    row=db.one('SELECT '+','.join(columns)+' FROM '+db.qualified(source['schema'],source['name'])+
               ' v JOIN '+db.qualified(obj['schema'],obj['name'])+' t ON '+join+' WHERE '+where,values)
    if row is None:raise APIError('Objet introuvable dans votre périmètre.','NOT_FOUND',404)
    return row


def validate_line_total(commande_id, article_id, quantity, price):
    """Le parent est déjà verrouillé ; les autres lignes et le candidat restent en Decimal exact."""
    from decimal import Decimal
    where='"ID_CmdFk"=%s'
    values=[commande_id]
    if article_id is not None:
        where+=' AND "ID_ArticleFk"<>%s'
        values.append(article_id)
    row=db.one('''SELECT COALESCE(SUM(round(COALESCE("QteCmdDetail",0)*COALESCE("PUCmdDetail",0),2)),0) AS total
        FROM logistique."T_CommandeDetail" WHERE '''+where,values)
    other_total=Decimal(str(row['total']))
    if not other_total.is_finite():
        raise APIError('Le montant de ce bon doit être vérifié.','ORDER_AMOUNT_INVALID',409)
    from .quantities import line_amount
    if other_total+line_amount(quantity,price)>Decimal('9999999999.99'):
        raise APIError({'PUCmdDetail':'Le total du bon ne peut pas dépasser 9 999 999 999,99 dans sa devise.'},'LINE_AMOUNT_LIMIT',400)


def protect_command_code(body, old=None):
    """Le code est une référence serveur ; un ancien client peut seulement renvoyer la même valeur."""
    if 'CodeCmd' not in body:return
    supplied=body['CodeCmd']
    if old is None:
        automatic=supplied is None or (isinstance(supplied,str) and not supplied.strip())
        if not automatic:raise APIError({'CodeCmd':'Le code du bon est attribué automatiquement.'},'ORDER_CODE_READ_ONLY',400)
    elif supplied!=old.get('CodeCmd'):
        raise APIError({'CodeCmd':'Le code du bon est conservé et ne peut pas être modifié.'},'ORDER_CODE_READ_ONLY',400)
    del body['CodeCmd']


def generate_command_identity():
    """La fonction PostgreSQL réserve l’identité existante et sa référence ; aucune allocation parallèle."""
    from django.db import DatabaseError
    from apps.core.repository import positive
    db.ensure_writable()
    try:
        row=db.one('SELECT * FROM logistique.fn_reserver_identite_commande()')
        identifier=positive(row.get('ID_Commande') if isinstance(row,dict) else None,'Numéro de bon')
        code=row.get('CodeCmd')
        if not isinstance(code,str) or not code or code.strip()!=code or len(code)>20:raise ValueError()
    except (APIError,DatabaseError,ValueError,TypeError):
        raise APIError('La numérotation des bons est indisponible. Contactez votre administrateur.','ORDER_NUMBERING_UNAVAILABLE',503)
    return {'ID_Commande':identifier,'CodeCmd':code}
