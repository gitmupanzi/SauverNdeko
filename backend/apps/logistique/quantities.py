"""Quantités exactes : trois décimales, politique d'unité explicite, aucun effet de stock."""
from decimal import Decimal, InvalidOperation, ROUND_HALF_UP
from apps.core import db
from apps.core.responses import APIError

MAX_QUANTITY = Decimal('99999999999.999')
QUANTUM = Decimal('0.001')
CENT = Decimal('0.01')


def quantity(value, field='Quantite', *, zero=False):
    try:
        if isinstance(value, (bool, float)) or value is None:raise ValueError()
        parsed = Decimal(str(value).strip().replace(',','.'))
        if not parsed.is_finite() or parsed < 0 or not zero and parsed == 0 or parsed > MAX_QUANTITY:
            raise ValueError()
        if parsed != parsed.quantize(QUANTUM):raise ValueError()
    except (ValueError, TypeError, InvalidOperation):
        raise APIError({field:'Indiquez une quantité '+('positive ou nulle' if zero else 'strictement positive')+', avec trois décimales au maximum.'}, 'QUANTITY_VALIDATION', 400)
    return parsed.quantize(QUANTUM)


def policy(unit_id):
    row = db.one('''SELECT "DecimalesStock" AS decimals
        FROM logistique."V_PrecisionStock" WHERE "ID_UniteFk"=%s''', [unit_id])
    if not row:raise APIError('L’unité de stock doit être vérifiée.', 'QUANTITY_UNIT_REQUIRED', 409)
    return int(row['decimals'])


def for_unit(value, unit_id, field='Quantite', *, zero=False):
    parsed = quantity(value, field, zero=zero)
    decimals = policy(unit_id)
    if parsed != parsed.quantize(Decimal(1).scaleb(-decimals)):
        raise APIError({field:'Cette unité exige une quantité entière.' if decimals == 0 else 'Cette unité autorise '+str(decimals)+' décimale(s).'}, 'QUANTITY_UNIT_PRECISION', 400)
    return parsed


def line_amount(qty, price):
    """Même arrondi par ligne que PostgreSQL round(numeric,2), jamais float/bancaire."""
    return (Decimal(str(qty)) * Decimal(str(price))).quantize(CENT, rounding=ROUND_HALF_UP)
