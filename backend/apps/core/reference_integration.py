"""Validation des nouvelles sélections, sans reclasser les références historiques."""
from copy import copy
import json
from . import db
from .responses import APIError, ExactEncoder
from .tenancy import read_entity


def entity_actor(actor, entity):
    """Contexte interne d'un objet déjà autorisé par son service propriétaire."""
    if actor is None:
        from types import SimpleNamespace
        return SimpleNamespace(global_admin=True, organisation=entity, _context_entity=entity)
    result = copy(actor)
    if entity is not None:
        result._context_entity = entity
    return result


def validate_changed(obj, data, old, actor):
    fields = db.query('SELECT "ColumnName" FROM referentiel."T_ChampReferentiel" '
                     'WHERE "SchemaName"=%s AND "TableName"=%s', [obj['schema'], obj['name']])
    if not fields:
        return
    effective = {**(old or {}), **data}
    # Même propriétaire durable que la garde PostgreSQL ; une table partagée
    # ne change pas de portée selon l'entreprise courante de son éditeur.
    entity = db.one('SELECT referentiel.fn_entite_reference_champ(%s,%s,%s::jsonb) AS entity',
                    [obj['schema'], obj['name'], json.dumps(effective, cls=ExactEncoder)])['entity']
    for entry in fields:
        field = entry['ColumnName']
        if field not in data or data[field] is None or old and data[field] == old.get(field):
            continue
        valid = db.one('SELECT referentiel.fn_valider_reference_champ(%s,%s,%s,%s,%s) AS valid',
                       [obj['schema'], obj['name'], field, data[field], entity])['valid']
        if not valid:
            raise APIError({field: 'Choisissez une valeur active de la catégorie configurée.'},
                           'REFERENCE_INCOMPATIBLE', 400)
