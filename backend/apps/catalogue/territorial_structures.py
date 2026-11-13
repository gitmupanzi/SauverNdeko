"""Annuaire des structures et territoires authentifié, distinct des entreprises ERP.

La projection SQL masque les contacts sans publication explicite. La position
géographique appartient au territoire publié lui-même. Une identité associe niveau et clé physique.
Les lectures n'accordent aucun droit de gestion et ne créent aucun contact.
"""
from rest_framework.views import APIView

from apps.core import db
from apps.core.module_access import access_snapshot
from apps.core.permissions import HasModuleAccess
from apps.core.repository import positive
from apps.core.responses import APIError, ok
from . import products

SOURCE = 'geolocalisation."V_StructureSanitairePublique"'
CHOICES = 'geolocalisation."V_ChoixTerritorial"'
DETAIL_COLUMNS = '''v.*, subdivision."TypeTerritoire" AS "TypeNiveau_2",
    zone."TypeTerritoire" AS "TypeNiveau_3", area."TypeTerritoire" AS "TypeNiveau_4",
    position.latitude, position.longitude'''
DETAIL_JOINS = f'''
    LEFT JOIN {CHOICES} subdivision ON subdivision.niveau=2 AND subdivision.id=v."ID_Niveau_2"
    LEFT JOIN {CHOICES} zone ON zone.niveau=3 AND zone.id=v."ID_Niveau_3"
    LEFT JOIN {CHOICES} area ON area.niveau=4 AND area.id=v."ID_Niveau_4"
    LEFT JOIN LATERAL (
        SELECT p.latitude, p.longitude
        FROM (
            SELECT n."LatitudeNiveau_2" latitude, n."LongitudeNiveau_2" longitude
            FROM geolocalisation."T_Niveau_2" n
            WHERE v."NiveauStructure"=2 AND n."ID_Niveau_2"=v."ID_Structure"
            UNION ALL
            SELECT n."LatitudeNiveau_3", n."LongitudeNiveau_3"
            FROM geolocalisation."T_Niveau_3" n
            WHERE v."NiveauStructure"=3 AND n."ID_Niveau_3"=v."ID_Structure"
            UNION ALL
            SELECT n."LatitudeNiveau_4", n."LongitudeNiveau_4"
            FROM geolocalisation."T_Niveau_4" n
            WHERE v."NiveauStructure"=4 AND n."ID_Niveau_4"=v."ID_Structure"
            UNION ALL
            SELECT n."LatitudeNiveau_5", n."LongitudeNiveau_5"
            FROM geolocalisation."T_Niveau_5" n
            WHERE v."NiveauStructure"=5 AND n."ID_Niveau_5"=v."ID_Structure"
        ) p
        WHERE p.latitude BETWEEN -90 AND 90 AND p.longitude BETWEEN -180 AND 180
          AND (p.latitude <> 0 OR p.longitude <> 0)
    ) position ON TRUE'''
PARAMETERS = {'q', 'typeId', 'level', 'provinceId', 'locality', 'take', 'skip', 'sortBy', 'sortDir'}
LEVELS = [{'id': 2, 'label': 'Niveau 2 — Antennes et subdivisions'},
          {'id': 3, 'label': 'Niveau 3'}, {'id': 4, 'label': 'Niveau 4'},
          {'id': 5, 'label': 'Niveau 5 — Structures et sites'}]


def parameters(query, allowed=PARAMETERS):
    if set(query) - allowed or any(len(query.getlist(key)) != 1 for key in query):
        raise APIError('Un critère de recherche est inconnu ou répété.', 'STRUCTURE_QUERY_INVALID', 400)
    return query.dict()


def text(value, maximum=300):
    value = value.strip()
    if len(value) > maximum or any(ord(char) < 32 for char in value):
        raise APIError('Utilisez une recherche courte, sans caractère de contrôle.', 'STRUCTURE_QUERY_INVALID', 400)
    return value


def pattern(value):
    return '%' + value.replace('\\', '\\\\').replace('%', '\\%').replace('_', '\\_') + '%'


def level(value):
    identifier = positive(value, 'Niveau territorial')
    if identifier not in {item["id"] for item in LEVELS}:
        raise APIError('Choisissez un niveau territorial de 2 à 5.', 'STRUCTURE_QUERY_INVALID', 400)
    return identifier


def can_manage_territories(actor):
    # L'accès à l'écran territorial exige déjà un rôle ERP de gestionnaire.
    # Cette capacité n'accorde jamais la mutation, réservée au global.
    rights = access_snapshot(actor)['modules'].get('territoires', {})
    return bool(actor.admin and rights.get('canRead'))


def projected(row):
    def territory(number):
        return {'id': row.get(f'ID_Niveau_{number}'), 'name': row.get(f'NomNiveau_{number}'),
                'type': row.get(f'TypeNiveau_{number}')}

    latitude, longitude = row.get('latitude'), row.get('longitude')
    position = {'latitude': float(latitude), 'longitude': float(longitude)} if latitude is not None and longitude is not None else None
    return {'key': row['StructureKey'], 'level': row['NiveauStructure'], 'id': row['ID_Structure'],
            'name': row.get('NomStructure'), 'code': row.get('CodeStructure'),
            'typeId': row['ID_TypeStructureFk'], 'type': row.get('TypeStructure'),
            'address': row.get('AdresseTerritoire'), 'phone': row.get('TelephoneTerritoire'),
            'secondaryPhone': row.get('TelephoneSecondaireTerritoire'), 'email': row.get('EmailTerritoire'),
            'website': row.get('SiteWebTerritoire'), 'reception': row.get('InformationsAccueilTerritoire'),
            'hours': row.get('HorairesOuvertureTerritoire'), 'contactsPublished': row['CoordonneesPubliees'] is True,
            'position': position, 'province': territory(1), 'subdivision': territory(2),
            'zone': territory(3), 'area': territory(4)}


def selection(params):
    where, values = ['TRUE'], []
    search = text(params.get('q', ''))
    if search:
        columns = ('NomStructure', 'CodeStructure', 'TypeStructure', 'AdresseTerritoire',
                   'NomNiveau_1', 'NomNiveau_2', 'NomNiveau_3', 'NomNiveau_4')
        # Le nom descriptif aide la recherche (Hôpital pour HOP), sans changer
        # le contrat d'affichage fondé sur l'abréviation du vrai type central.
        where.append('(' + ' OR '.join('v.' + db.ident(column) + ' COLLATE pg_catalog."und-x-icu" ILIKE %s'
                                      for column in columns) + ''' OR EXISTS(SELECT 1 FROM referentiel."T_Generique" g
            WHERE g."ID_Generique"=v."ID_TypeStructureFk"
              AND g."NomGenerique" COLLATE pg_catalog."und-x-icu" ILIKE %s))''')
        values.extend([pattern(search)] * (len(columns) + 1))
    for key, column in (('typeId', 'ID_TypeStructureFk'), ('provinceId', 'ID_Niveau_1')):
        if params.get(key) not in (None, ''):
            where.append('v.' + db.ident(column) + '=%s')
            values.append(positive(params[key], key))
    if params.get('level') not in (None, ''):
        where.append('v."NiveauStructure"=%s')
        values.append(level(params['level']))
    locality = text(params.get('locality', ''), 255)
    if locality:
        where.append('concat_ws(\' \',v."AdresseTerritoire",v."NomNiveau_1",v."NomNiveau_2",'
                     'v."NomNiveau_3",v."NomNiveau_4") COLLATE pg_catalog."und-x-icu" ILIKE %s')
        values.append(pattern(locality))
    return ' AND '.join(where), values


def listing(params):
    take = products.natural(params.get('take', '25'), 'Nombre de lignes', minimum=1, maximum=100)
    skip = products.natural(params.get('skip', '0'), 'Décalage')
    sort, direction = params.get('sortBy', 'name'), params.get('sortDir', 'asc')
    if sort not in {'name', 'type'} or direction not in {'asc', 'desc'}:
        raise APIError('Choisissez un tri par nom ou type.', 'STRUCTURE_QUERY_INVALID', 400)
    column = 'NomStructure' if sort == 'name' else 'TypeStructure'
    order = db.ident(column) + ' COLLATE pg_catalog."und-x-icu" ' + direction.upper() + \
        ' NULLS LAST,"NiveauStructure" ASC,"ID_Structure" ASC'
    where, values = selection(params)
    result = db.one(f'''
        WITH population AS MATERIALIZED (SELECT v.* FROM {SOURCE} v WHERE {where}),
        page AS (SELECT * FROM population ORDER BY {order} LIMIT %s OFFSET %s),
        enriched AS (SELECT {DETAIL_COLUMNS} FROM page v {DETAIL_JOINS})
        SELECT (SELECT count(*) FROM population) total,
               COALESCE((SELECT jsonb_agg(to_jsonb(p) ORDER BY {order}) FROM enriched p), '[]'::jsonb) rows
        ''', [*values, take, skip])
    return {'rows': [projected(row) for row in result['rows']], 'total': result['total'], 'take': take, 'skip': skip}


def references(actor):
    types = db.query('''SELECT "ID_TypeStructureFk" id,"TypeStructure" label,
        array_agg(DISTINCT "NiveauStructure" ORDER BY "NiveauStructure") levels
        FROM ''' + SOURCE + ''' GROUP BY "ID_TypeStructureFk","TypeStructure" ORDER BY label,id''')
    # Garder les seuls parents de l'annuaire autorisé ; le chemin partagé
    # différencie les homonymes sans élargir la population des structures.
    provinces = db.query('''SELECT DISTINCT v."ID_Niveau_1" id,c.label FROM ''' + SOURCE + ''' v
        JOIN geolocalisation."V_ChoixTerritorial" c ON c.niveau=1 AND c.id=v."ID_Niveau_1"
        WHERE v."ID_Niveau_1" IS NOT NULL ORDER BY label NULLS LAST,id''')
    return {'types': types, 'levels': LEVELS, 'provinces': provinces,
            'canManageTerritories': can_manage_territories(actor)}


def detail(actor, structure_level, pk):
    row = db.one(f'SELECT {DETAIL_COLUMNS} FROM {SOURCE} v {DETAIL_JOINS} '
                 'WHERE v."NiveauStructure"=%s AND v."ID_Structure"=%s',
                 [level(structure_level), positive(pk, 'Structure sanitaire')])
    if not row:
        raise APIError('Cette structure ou ce territoire est introuvable.', 'NOT_FOUND', 404)
    return {'record': projected(row), 'canManageTerritories': can_manage_territories(actor)}


class TerritorialStructuresView(APIView):
    permission_classes = [HasModuleAccess]
    http_method_names = ['get', 'head', 'options']

    def get(self, request, niveau=None, pk=None, reference=False):
        params = parameters(request.query_params, set() if reference or pk is not None else PARAMETERS)
        result = references(request.user) if reference else detail(request.user, niveau, pk) if pk is not None else listing(params)
        return ok(result)
