"""Validation des nouvelles sélections, sans reclasser les références historiques."""
from copy import copy
import json
from . import db
from .responses import APIError, ExactEncoder
from .tenancy import read_entity

TERRITORIAL_TYPE_VISIBILITY = {
    ('geolocalisation', 'T_Niveau_3', 'ID_TypeNiveau_2_Fk'): 'VisibleNiveau_3',
    ('geolocalisation', 'T_Niveau_4', 'ID_TypeNiveau_4_Fk'): 'VisibleNiveau_4',
    ('geolocalisation', 'T_Niveau_5', 'ID_TypeNiveau_5_Fk'): 'VisibleNiveau_5',
}


def territorial_type_visibility(schema, table, column):
    """Même indicateur existant pour les choix et les nouvelles affectations."""
    return TERRITORIAL_TYPE_VISIBILITY.get((schema, table, column))


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
        visibility = territorial_type_visibility(obj['schema'], obj['name'], field)
        if visibility:
            selected = db.one('SELECT ' + db.ident(visibility) + ' IS TRUE AS visible FROM referentiel."T_Generique" '
                              'WHERE "ID_Generique"=%s', [data[field]])
            if not selected or not selected['visible']:
                number = obj['name'][-1]
                raise APIError({field: 'Ce type n’est pas proposé au niveau ' + number
                                + '. Vérifiez sa visibilité dans Référentiels ou choisissez une autre valeur.'},
                               'REFERENCE_NOT_VISIBLE', 400)
