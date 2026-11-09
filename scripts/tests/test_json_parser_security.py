"""Tests du parseur JSON sans connexion à PostgreSQL."""
from decimal import Decimal
from io import BytesIO
import json
from pathlib import Path
import sys
from types import SimpleNamespace
import unittest
from unittest.mock import patch

from django.conf import settings
from django.http import QueryDict
from django.utils.datastructures import MultiValueDict

if not settings.configured:
    settings.configure()

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "backend"))
from apps.core.parsers import ExactJSONParser
from apps.core.responses import APIError, ExactEncoder
from apps.logistique.batch_creation import parse_request
from apps.logistique.photos import request_data
from rest_framework.exceptions import ParseError


class ExactJSONParserTests(unittest.TestCase):
    def test_preserves_decimal_and_text_charsets(self):
        parser = ExactJSONParser()
        for encoding in ("utf-8", "iso-8859-1"):
            with self.subTest(encoding=encoding):
                source = BytesIO('{"montant": 1.2500, "libellé": "Règlement"}'.encode(encoding))
                result = parser.parse(source, parser_context={"encoding": encoding})
                self.assertIsInstance(result["montant"], Decimal)
                self.assertEqual(str(result["montant"]), "1.2500")
                self.assertEqual(result["libellé"], "Règlement")

    def test_rejects_binary_and_unknown_codecs_before_reading_the_body(self):
        parser = ExactJSONParser()
        for encoding in ("bz2_codec", "zlib_codec", "base64_codec", "inconnu"):
            with self.subTest(encoding=encoding), patch("apps.core.parsers.codecs.getreader") as reader:
                with self.assertRaises(ParseError):
                    parser.parse(BytesIO(), parser_context={"encoding": encoding})
                reader.assert_not_called()

    def test_rejects_invalid_or_deeply_nested_json(self):
        parser = ExactJSONParser()
        for source in (b'{"montant": NaN}', b'"\xff"', b'[' * 3000 + b'0' + b']' * 3000):
            with self.assertRaises(ParseError):
                parser.parse(BytesIO(source))

    def test_limits_numeric_literals_without_rounding(self):
        parser = ExactJSONParser()
        for literal in (b"1e999999999", b"1e-999999999", b"0e-999999999",
                        b"1e999999999999999999999999", b"1." + b"2" * 128):
            with self.subTest(literal=literal), self.assertRaises(ParseError):
                parser.parse(BytesIO(b'{"value":' + literal + b'}'))
        result = parser.parse(BytesIO(b'{"value":-1.2500e-12, "zero": -0.000}'))
        self.assertEqual(result["value"].as_tuple(), Decimal("-1.2500e-12").as_tuple())
        self.assertEqual(result["zero"].as_tuple(), Decimal("-0.000").as_tuple())

    def test_multipart_article_and_batch_use_the_same_numeric_limits(self):
        form = QueryDict(mutable=True)
        request = SimpleNamespace(content_type="multipart/form-data; boundary=test", data=form, FILES=MultiValueDict())
        for read in (request_data, lambda req: parse_request(req, "articles")):
            with self.subTest(read=read):
                for payload in ('{"value": 1e-999999999}', '{"value": Infinity}', '[' * 3000 + ']' * 3000):
                    form["payload"] = payload
                    with self.assertRaises(APIError) as raised:
                        read(request)
                    self.assertEqual(raised.exception.status_code, 400)
                form["payload"] = '{"value": 1.2500}'
                result, _ = read(request)
                self.assertEqual(result["value"].as_tuple(), Decimal("1.2500").as_tuple())

    def test_encoder_preserves_normal_fixed_format_and_bounds_extreme_scale(self):
        values = [Decimal("1.2500"), Decimal("-1e10000"), Decimal("1e-10000"), Decimal("0e-10000")]
        encoded = json.dumps(values, cls=ExactEncoder)
        result = json.loads(encoded)
        self.assertEqual(result[0], "1.2500")
        self.assertLess(len(encoded), 60)
        self.assertEqual([Decimal(value).as_tuple() for value in result], [value.as_tuple() for value in values])


if __name__ == "__main__":
    unittest.main()
