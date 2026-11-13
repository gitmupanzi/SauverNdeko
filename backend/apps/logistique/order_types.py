"""Nature d'un document résolue depuis le référentiel, sans déduire CMD d'un signe nul."""
from apps.core import db
from apps.core.category_values import category_key
from apps.core.responses import APIError


def type_context(identifier, *, required=True):
    # La fonction SQL est aussi celle des triggers : une technologie cliente
    # différente conserve exactement la même classification métier.
    row = db.one('SELECT logistique.fn_nature_bon(%s) AS kind, logistique.fn_effet_type_bon(%s) AS effect',
                 [identifier, identifier])
    kind = (row or {}).get('kind') or 'inconnu'
    effect = (row or {}).get('effect')
    key = category_key(kind)
    result = {'kind': kind, 'stockEffect': effect, 'sign': effect, 'canInvoice': key == 'sortie'}
    if required and key == 'inconnu':
        raise APIError({'ID_TypeCmdFk': 'Choisissez un type de bon pris en charge.'}, 'ORDER_TYPE_UNSUPPORTED', 400)
    return result


def reject_order_lots(lots):
    # Aucun numéro de lot n'est réservé ou créé par une commande préparatoire.
    if lots not in (None, []):
        raise APIError({'Lots': 'Les lots sont affectés à la réception ou à la sortie effective.'},
                       'ORDER_LOTS_FORBIDDEN', 400)
