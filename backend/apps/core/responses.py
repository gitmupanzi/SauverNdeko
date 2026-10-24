import json, logging
from uuid import UUID
from datetime import datetime, date
from decimal import Decimal
from django.db import DatabaseError, IntegrityError
from rest_framework.renderers import JSONRenderer
from rest_framework.response import Response
from rest_framework.exceptions import APIException

log = logging.getLogger(__name__)


class APIError(APIException):
    def __init__(self, message, code="INVALID_REQUEST", status=400):
        self.status_code = status
        self.default_code = code
        super().__init__(message, code)


class ExactEncoder(json.JSONEncoder):
    def default(self, value):
        if isinstance(value, UUID):
            return str(value)
        if isinstance(value, Decimal):
            return format(value, "f")
        if isinstance(value, (datetime, date)):
            return value.isoformat()
        return super().default(value)


class ExactJSONRenderer(JSONRenderer):
    def render(self, data, accepted_media_type=None, renderer_context=None):
        if data is None:
            return b""
        return json.dumps(
            data,
            ensure_ascii=False,
            allow_nan=False,
            cls=ExactEncoder,
            separators=(",", ":"),
        ).encode("utf8")


def ok(data=None, *, status=200, message="", meta=None, **extra):
    body = {"success": True, "data": data, "message": message, "error": None, **extra}
    if meta is not None:
        body["meta"] = meta
    return Response(body, status=status)


def exception_handler(exc, context):
    if isinstance(exc, IntegrityError):
        exc = APIError(
            "Écriture refusée par les contraintes PostgreSQL.",
            "CONSTRAINT_VIOLATION",
            409,
        )
    elif isinstance(exc, DatabaseError):
        state = getattr(exc.__cause__, "sqlstate", None)
        if state in {"P0001", "23514", "23503", "23505", "55P03", "40P01"}:
            exc = APIError(
                "Opération incompatible avec le stock, les références ou l’état de la commande.",
                "BUSINESS_CONFLICT",
                409,
            )
        else:
            log.error("Erreur PostgreSQL sur API (%s).", state)
            exc = APIError(
                "La source de données est indisponible.", "DATABASE_UNAVAILABLE", 503
            )
    from rest_framework.views import exception_handler as drf_exception_handler

    result = drf_exception_handler(exc, context)
    if result is None:
        log.exception("Erreur API inattendue")
        result = Response(status=500)
    detail = getattr(exc, "detail", None)
    result.data = {
        "success": False,
        "data": None,
        "message": str(detail) if isinstance(detail, str) else "Requête refusée.",
        "error": {
            "code": getattr(exc, "default_code", "INTERNAL_ERROR"),
            "details": detail,
        },
    }
    return result
