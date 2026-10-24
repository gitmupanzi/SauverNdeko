import json, codecs
from decimal import Decimal
from rest_framework.parsers import BaseParser
from rest_framework.exceptions import ParseError


class ExactJSONParser(BaseParser):
    media_type = "application/json"

    def parse(self, stream, media_type=None, parser_context=None):
        encoding = (parser_context or {}).get("encoding", "utf-8")

        def invalid(value):
            raise ValueError("Constante JSON non finie interdite.")

        try:
            return json.load(
                codecs.getreader(encoding)(stream),
                parse_float=Decimal,
                parse_constant=invalid,
            )
        except (ValueError, UnicodeError) as exc:
            raise ParseError("JSON invalide.") from exc
