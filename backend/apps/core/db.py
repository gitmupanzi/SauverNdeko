"""SQL paramétré sur la connexion Django ; aucun pool parallèle et aucun DDL."""

import json
from decimal import Decimal

from django.conf import settings
from django.db import connection
from .responses import APIError


def ident(value):
    return '"' + str(value).replace('"', '""') + '"'


def qualified(schema, name):
    return ident(schema) + "." + ident(name)


def query(sql, params=()):
    with connection.cursor() as cursor:
        cursor.execute(sql, params)
        if not cursor.description:
            return []
        columns = cursor.description
        # Django laisse les JSON des curseurs bruts en texte ; les API attendent des objets.
        # Décoder uniquement les OID JSON/JSONB conserve les vrais champs texte intacts.
        return [
            {
                column[0]: (
                    json.loads(value, parse_float=Decimal)
                    if column[1] in {114, 3802} and isinstance(value, str)
                    else value
                )
                for column, value in zip(columns, row)
            }
            for row in cursor.fetchall()
        ]


def one(sql, params=()):
    rows = query(sql, params)
    return rows[0] if rows else None


def ensure_writable():
    if settings.DB_READ_ONLY:
        raise APIError(
            "Backend en lecture seule : activer explicitement SAUVERNDEKO_DB_READ_ONLY=0 pour autoriser les écritures métier.",
            "READ_ONLY",
            503,
        )
