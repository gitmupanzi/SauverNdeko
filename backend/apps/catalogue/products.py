"""Annuaire authentifié d'offres locales publiées, sans écriture ni télémétrie.

Une offre reste un article d'une entreprise. Les prix d'unités ou de devises
différentes ne sont ni additionnés ni classés comme s'ils étaient comparables.
"""
import re

from django.conf import settings
from rest_framework.views import APIView

from apps.core import db
from apps.core.module_access import access_snapshot
from apps.core.permissions import HasModuleAccess
from apps.core.repository import positive
from apps.core.responses import APIError, ok
from .offers import public_offer

SOURCE = 'logistique."V_OffreArticle"'
FILTERS = {'categoryId': 'ID_CategorieArticleFk', 'typeId': 'ID_TypeArticleFk',
           'companyId': 'IdEntite', 'currencyId': 'ID_DeviseFk'}
SORTS = {'name': 'NomArticle', 'company': 'NomEntite'}
PARAMETERS = {'q', *FILTERS, 'availability', 'take', 'skip', 'sortBy', 'sortDir'}
EXTRA_FIELDS = ('ID_CategorieArticleFk', 'CategorieArticle', 'ID_TypeArticleFk', 'TypeArticle', 'ID_DeviseFk')
AVAILABILITY = [{'id': 'positive', 'label': 'Stock déclaré positif'},
                {'id': 'zero', 'label': 'Stock nul déclaré'}]


def parameters(query, allowed):
    if set(query) - allowed or any(len(query.getlist(key)) != 1 for key in query):
        raise APIError('Un critère de recherche est inconnu ou répété.', 'PRODUCT_QUERY_INVALID', 400)
    return query.dict()


def natural(value, label, *, minimum=0, maximum=2147483647):
    if not isinstance(value, str) or not re.fullmatch(r'[0-9]+', value) or len(value) > 10:
        raise APIError(label + ' invalide.', 'PRODUCT_QUERY_INVALID', 400)
    result = int(value)
    if not minimum <= result <= maximum:
        raise APIError(label + ' hors limites.', 'PRODUCT_QUERY_INVALID', 400)
    return result


def criteria(params):
    where, values = ['TRUE'], []
    search = params.get('q', '').strip()
    if len(search) > 300 or any(ord(char) < 32 for char in search):
        raise APIError('Utilisez une recherche de 300 caractères maximum, sans caractère de contrôle.', 'PRODUCT_QUERY_INVALID', 400)
    if search:
        # Les caractères Excel/SQL % et _ restent du texte saisi, pas des jokers.
        pattern = '%' + search.replace('\\', '\\\\').replace('%', '\\%').replace('_', '\\_') + '%'
        columns = ('NomArticle', 'RefArticle', 'NomEntite', 'AdresseEntite', 'CategorieArticle', 'TypeArticle')
        # Une restauration peut utiliser la locale C. La collation Unicode
        # conserve le rapprochement É/é sans supprimer les accents des termes.
        where.append('(' + ' OR '.join('v.' + db.ident(column) + ' COLLATE pg_catalog."und-x-icu" ILIKE %s'
                                     for column in columns) + ')')
        values.extend([pattern] * len(columns))
    for key, column in FILTERS.items():
        if params.get(key) not in (None, ''):
            where.append('v.' + db.ident(column) + '=%s')
            values.append(positive(params[key], key))
    availability = params.get('availability')
    if availability not in (None, ''):
        labels = {option['id']: ('Stock déclaré' if option['id'] == 'positive' else 'Stock nul déclaré') for option in AVAILABILITY}
        if availability not in labels:
            raise APIError('Choisissez un état de stock proposé.', 'PRODUCT_QUERY_INVALID', 400)
        where.append('v."EtatDisponibilite"=%s')
        values.append(labels[availability])
    return ' AND '.join(where), values


def can_contact(actor):
    rights = access_snapshot(actor)['modules']
    return bool(not settings.DB_READ_ONLY and rights.get('discussions', {}).get('canManage')
                and rights.get('structures', {}).get('canRead'))


def offer(row):
    return {**public_offer(row), **{key: row.get(key) for key in EXTRA_FIELDS}}


def listing(params):
    where, values = criteria(params)
    take = natural(params.get('take', '25'), 'Nombre de lignes', minimum=1, maximum=100)
    skip = natural(params.get('skip', '0'), 'Décalage')
    sort_key = params.get('sortBy', 'name')
    direction = params.get('sortDir', 'asc')
    if sort_key not in SORTS or direction not in {'asc', 'desc'}:
        raise APIError('Choisissez un tri par produit ou entreprise.', 'PRODUCT_QUERY_INVALID', 400)
    # Identifiants et sens proviennent exclusivement de listes fermées.
    order = db.ident(SORTS[sort_key]) + ' ' + direction.upper() + ' NULLS LAST,"ID_Article" ASC'
    # Compteur et page partagent le même instantané, même lors d'une publication
    # ou d'un retrait concurrent. L'agrégat ne porte jamais sur les prix.
    result = db.one('''WITH population AS MATERIALIZED (SELECT v.* FROM ''' + SOURCE + ''' v WHERE ''' + where + '''),
        page AS (SELECT * FROM population ORDER BY ''' + order + ''' LIMIT %s OFFSET %s)
        SELECT (SELECT count(*) FROM population) AS total,
          COALESCE((SELECT jsonb_agg(to_jsonb(p) ORDER BY ''' + order + ''') FROM page p),'[]'::jsonb) AS rows''',
        [*values, take, skip])
    return {'rows': [offer(row) for row in result['rows']], 'total': result['total'], 'take': take, 'skip': skip}


def references(actor):
    # Les options sont exhaustives, mais proviennent seulement des offres
    # publiées. Un dictionnaire privé sans offre publiée n'est pas dévoilé.
    pairs = {'categories': ('ID_CategorieArticleFk', 'CategorieArticle'),
             'types': ('ID_TypeArticleFk', 'TypeArticle'),
             'companies': ('IdEntite', 'NomEntite'), 'currencies': ('ID_DeviseFk', 'DeviseCode')}
    projections = []
    for key, (identifier, label) in pairs.items():
        projections.append('COALESCE((SELECT jsonb_agg(to_jsonb(choice) ORDER BY choice.label,choice.id) '
            'FROM (SELECT DISTINCT ' + db.ident(identifier) + ' AS id,' + db.ident(label) + ' AS label FROM population '
            'WHERE ' + db.ident(identifier) + ' IS NOT NULL) choice),\'[]\'::jsonb) AS ' + db.ident(key))
    result = db.one('WITH population AS MATERIALIZED (SELECT * FROM ' + SOURCE + ') SELECT ' + ','.join(projections))
    return {**result, 'availability': AVAILABILITY, 'canContact': can_contact(actor)}


def detail(actor, pk):
    row = db.one('SELECT * FROM ' + SOURCE + ' WHERE "ID_Article"=%s', [positive(pk)])
    if not row:
        raise APIError('Cette offre est introuvable ou n’est plus publiée.', 'NOT_FOUND', 404)
    # La projection SQL revérifie la publication ; pas d'accès arbitraire à la
    # fiche administrative, aux points bruts ni aux coordonnées personnelles.
    locations = db.query('''SELECT label,address,zone,area,site
        FROM logistique."V_OffreArticleLocalisation" WHERE "ID_Article"=%s
        ORDER BY label NULLS LAST,address NULLS LAST,zone NULLS LAST,area NULLS LAST,site NULLS LAST''', [row['ID_Article']])
    return {'record': offer(row), 'locations': locations, 'canContact': can_contact(actor)}


class ProductReferencesView(APIView):
    permission_classes = [HasModuleAccess]
    http_method_names = ['get', 'head', 'options']

    def get(self, request):
        parameters(request.query_params, set())
        return ok(references(request.user))


class ProductOffersView(APIView):
    permission_classes = [HasModuleAccess]
    http_method_names = ['get', 'head', 'options']

    def get(self, request, pk=None):
        params = parameters(request.query_params, PARAMETERS if pk is None else set())
        return ok(detail(request.user, pk) if pk is not None else listing(params))
