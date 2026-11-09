import codecs
import json
from decimal import Decimal, InvalidOperation

from rest_framework.exceptions import ParseError
from rest_framework.parsers import BaseParser


MAX_DECIMAL_LITERAL_LENGTH = 128
MAX_FIXED_DECIMAL_EXPONENT = 128


def fits_fixed_decimal(value):
    return (
        value.is_finite()
        and abs(value.as_tuple().exponent) <= MAX_FIXED_DECIMAL_EXPONENT
        and abs(value.adjusted()) <= MAX_FIXED_DECIMAL_EXPONENT
    )


def _parse_decimal(literal):
    if len(literal) > MAX_DECIMAL_LITERAL_LENGTH:
        raise ValueError("Nombre JSON trop long.")
    try:
        value = Decimal(literal)
    except InvalidOperation as exc:
        raise ValueError("Nombre JSON invalide.") from exc
    if not fits_fixed_decimal(value):
        raise ValueError("Exposant JSON hors limites.")
    return value


def _reject_constant(value):
    raise ValueError("Constante JSON non finie interdite.")


def loads_exact_json(source):
    try:
        return json.loads(source, parse_float=_parse_decimal, parse_constant=_reject_constant)
    except RecursionError as exc:
        raise ValueError("JSON trop imbriqué.") from exc


class ExactJSONParser(BaseParser):
    media_type = "application/json"

    def parse(self, stream, media_type=None, parser_context=None):
        encoding = (parser_context or {}).get("encoding", "utf-8")
        try:
            # str.encode refuse les codecs binaires tels que bz2 et zlib.
            "".encode(encoding)
            return loads_exact_json(codecs.getreader(encoding)(stream).read())
        except (LookupError, ValueError) as exc:
            raise ParseError("JSON invalide.") from exc
