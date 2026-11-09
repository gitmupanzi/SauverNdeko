"""Annuaire transversal des structures et gestion du profil de son entreprise.

La publication est un choix explicite, distinct du partage des articles. Les
lectures n'écrivent ni recherche, ni message, ni donnée commerciale. Le profil
privé réutilise le service d'identité versionné et ses contrôles d'entreprise.
"""
import re

from django.conf import settings
from rest_framework.parsers import MultiPartParser
from rest_framework.renderers import BaseRenderer
from rest_framework.views import APIView

from apps.core import db
from apps.core.module_access import access_snapshot, can_use_tab, require_module, require_tab
from apps.core.parsers import ExactJSONParser
from apps.core.permissions import HasModuleAccess
from apps.core.repository import positive
from apps.core.responses import APIError, ExactJSONRenderer, ok
from apps.core.tenancy import read_entity
from apps.logistique import entity_documents
from . import products

SOURCE = 'systeme."V_StructurePublique"'
QUERY = {'q', 'typeId', 'locality', 'take', 'skip', 'sortBy', 'sortDir'}
PROFILE_QUERY = {'q', 'take', 'skip', 'sortBy', 'sortDir'}


def text(value, maximum=300):
    value = value.strip()
    if len(value) > maximum or any(ord(char) < 32 for char in value):
        raise APIError('Utilisez une recherche courte, sans caractère de contrôle.', 'STRUCTURE_QUERY_INVALID', 400)
    return value


def pattern(value):
    return '%' + value.replace('\\', '\\\\').replace('%', '\\%').replace('_', '\\_') + '%'


def paging(params):
    take = products.natural(params.get('take', '25'), 'Nombre de lignes', minimum=1, maximum=100)
    skip = products.natural(params.get('skip', '0'), 'Décalage')
    key, direction = params.get('sortBy', 'name'), params.get('sortDir', 'asc')
    if key not in {'name', 'type'} or direction not in {'asc', 'desc'}:
        raise APIError('Choisissez un tri par nom ou type.', 'STRUCTURE_QUERY_INVALID', 400)
    order = db.ident('NomEntite' if key == 'name' else 'TypeEntite') + ' COLLATE pg_catalog."und-x-icu" ' + direction.upper()
    return take, skip, order + ' NULLS LAST,"IdEntite" ASC'


def logo_url(row, private=False):
    if row.get('HasLogo') and row.get('LogoMimeEntite') == 'image/png' and re.fullmatch(r'[a-f0-9]{64}', row.get('LogoSha256Entite') or ''):
        return '/api/structures/' + ('profils' if private else 'annuaire') + '/' + str(row['IdEntite']) + '/logo'
    return None


def projected(row, private=False):
    result = {'id': row['IdEntite'], 'name': row['NomEntite'], 'typeId': row.get('IdTypeEntiteFk'),
              'type': row.get('TypeEntite'), 'address': row.get('AdresseEntite'), 'phone': row.get('PhoneEntite'),
              'website': row.get('SiteWebEntite'), 'summary': row.get('PresentationPubliqueEntite'),
              'logoUrl': logo_url(row, private)}
    if private:
        result.update(email=row.get('EmailEntite'), published=row['VisibleAnnuaireEntite'], active=row['ValideEntite'])
    return result


def public_record(pk):
    row = db.one('SELECT * FROM ' + SOURCE + ' WHERE "IdEntite"=%s', [positive(pk, 'Structure')])
    if not row:
        raise APIError('Cette structure est introuvable ou n’est plus publiée.', 'NOT_FOUND', 404)
    return row


def contact_available(actor, entity=None):
    rights = access_snapshot(actor)['modules']
    available = bool(not settings.DB_READ_ONLY and can_use_tab(actor, 'discussions', 'messages', 'manage')
                     and rights['structures']['canRead'])
    if not available or entity is None:
        return available
    # L'offre est une publication volontaire indépendante de l'annuaire de
    # structures. Son lecteur peut contacter son fournisseur publié, sans lire
    # sa fiche privée. Sans aucune publication actuelle, le contact est refusé.
    row = db.one('''SELECT EXISTS(SELECT 1 FROM systeme."V_StructurePublique" WHERE "IdEntite"=%s)
        OR (%s AND EXISTS(SELECT 1 FROM logistique."V_OffreArticle" WHERE "IdEntite"=%s)) available''',
        [entity, bool(rights['produits']['canRead']), entity])
    return bool(row['available'])


def capabilities(actor):
    rights = access_snapshot(actor)['modules']
    return {'canContact': contact_available(actor), 'canReadProducts': bool(rights['produits']['canRead']),
            'canReadProfessionals': can_use_tab(actor, 'professionnels', 'annuaire')}


def listing(params):
    take, skip, order = paging(params)
    conditions, values = ['TRUE'], []
    search = text(params.get('q', ''))
    if search:
        columns = ('NomEntite', 'TypeEntite', 'AdresseEntite', 'PresentationPubliqueEntite')
        conditions.append('(' + ' OR '.join('v.' + db.ident(col) + ' COLLATE pg_catalog."und-x-icu" ILIKE %s' for col in columns) + ')')
        values.extend([pattern(search)] * len(columns))
    if params.get('typeId') not in (None, ''):
        conditions.append('v."IdTypeEntiteFk"=%s')
        values.append(positive(params['typeId'], 'Type'))
    locality = text(params.get('locality', ''), 255)
    if locality:
        conditions.append('''(v."AdresseEntite" COLLATE pg_catalog."und-x-icu" ILIKE %s OR EXISTS(
            SELECT 1 FROM systeme."V_StructureLocalisation" l WHERE l."IdEntite"=v."IdEntite"
              AND concat_ws(' ',l.label,l.address,l.zone,l.area,l.site) COLLATE pg_catalog."und-x-icu" ILIKE %s))''')
        values += [pattern(locality)] * 2
    result = db.one('''WITH population AS MATERIALIZED (SELECT v.* FROM ''' + SOURCE + ''' v WHERE ''' + ' AND '.join(conditions) + '''),
        page AS (SELECT * FROM population ORDER BY ''' + order + ''' LIMIT %s OFFSET %s)
        SELECT (SELECT count(*) FROM population) total,
          COALESCE((SELECT jsonb_agg(to_jsonb(p) ORDER BY ''' + order + ''') FROM page p),'[]'::jsonb) rows''', [*values, take, skip])
    return {'rows': [projected(row) for row in result['rows']], 'total': result['total'], 'take': take, 'skip': skip}


def references(actor):
    types = db.query('SELECT DISTINCT "IdTypeEntiteFk" id,"TypeEntite" label FROM ' + SOURCE +
        ' WHERE "IdTypeEntiteFk" IS NOT NULL ORDER BY label,id')
    return {'types': types, **capabilities(actor)}


def detail(actor, pk):
    row = public_record(pk)
    locations = db.query('SELECT label,address,zone,area,site FROM systeme."V_StructureLocalisation" WHERE "IdEntite"=%s '
        'ORDER BY label NULLS LAST,address NULLS LAST,zone NULLS LAST,area NULLS LAST,site NULLS LAST', [row['IdEntite']])
    return {'record': projected(row), 'locations': locations, **capabilities(actor)}


def affiliated_professionals(actor, pk, params):
    require_tab(actor, 'professionnels', 'annuaire')
    public_record(pk)
    from apps.professionnels.services import _query, public_profile
    conditions, values, order, order_values, take, skip = _query(params)
    conditions.append('''EXISTS(SELECT 1 FROM professionnel."T_Professionnel_Entite" link
        WHERE link."IdProfessionnelFk"=v."IdProfessionnel" AND link."IdEntiteFk"=%s
          AND (link."DateDebut" IS NULL OR link."DateDebut"<=LOCALTIMESTAMP)
          AND (link."DateFin" IS NULL OR link."DateFin">LOCALTIMESTAMP))''')
    values.append(positive(pk))
    # Un seul instantané pour le total et la page des affiliations actuelles.
    result = db.one('''WITH population AS MATERIALIZED (SELECT v.* FROM professionnel."V_Professionnel_Public" v WHERE ''' +
        ' AND '.join(conditions) + '''), page AS (SELECT v.*,row_number() OVER(ORDER BY ''' + order + ''') position
        FROM population v ORDER BY ''' + order + ''' LIMIT %s OFFSET %s)
        SELECT (SELECT count(*) FROM population) total,
        COALESCE((SELECT jsonb_agg(to_jsonb(p)-'position' ORDER BY p.position) FROM page p),'[]'::jsonb) rows''',
        [*values, *order_values, *order_values, take, skip])
    return {'rows': [public_profile(row, actor) for row in result['rows']], 'total': result['total'], 'take': take, 'skip': skip}


def management(actor):
    require_module(actor, 'structures', 'manage')
    if not actor.admin:
        raise APIError('Accès réservé aux gestionnaires de structures autorisés.', 'FORBIDDEN', 403)


def context(actor):
    from .territorial_structures import can_manage_territories
    require_module(actor, 'structures')
    entity = read_entity(actor)
    rights = access_snapshot(actor)['modules']['structures']
    registry = bool(actor.admin and rights['canManage'])
    row = db.one('SELECT "ValideEntite" active FROM systeme."T_Entite" WHERE "IdEntite"=%s', [entity]) if entity else None
    manage = bool(registry and row and row['active'] is True and not settings.DB_READ_ONLY)
    return {'entityId': entity, 'activeEntityId': entity, 'platformAdmin': actor.global_admin, 'canRead': True,
            'canManageTerritories': can_manage_territories(actor),
            'canReadRegistry': registry, 'canManage': manage, 'readOnly': settings.DB_READ_ONLY,
            'policyReason': '' if manage else 'Choisissez une entreprise active pour modifier son profil.' if registry else 'Consultation de l’annuaire uniquement.'}


def entity_choices(actor):
    management(actor)
    rows = db.query('SELECT "IdEntite","NomEntite","ValideEntite" FROM systeme."T_Entite"' +
        ('' if actor.global_admin else ' WHERE "IdEntite"=%s') + ' ORDER BY lower("NomEntite"),"IdEntite"',
        [] if actor.global_admin else [actor.row.get('IdEntiteFk')])
    return [{**row, 'id': row['IdEntite'], 'label': row['NomEntite'], 'active': row['ValideEntite'] is True} for row in rows]


def profiles(actor, params):
    management(actor)
    take, skip, order = paging(params)
    entity = read_entity(actor)
    if entity is None and not actor.global_admin:
        raise APIError('Votre compte doit être lié à une entreprise.', 'ORGANISATION_REQUIRED', 403)
    where, values = ['TRUE'], []
    if entity is not None:
        where.append('v."IdEntite"=%s')
        values.append(entity)
    search = text(params.get('q', ''))
    if search:
        where.append('concat_ws(\' \',v."NomEntite",v."TypeEntite",v."AdresseEntite",v."PresentationPubliqueEntite") COLLATE pg_catalog."und-x-icu" ILIKE %s')
        values.append(pattern(search))
    result = db.one('''WITH population AS MATERIALIZED (SELECT e."IdEntite",e."NomEntite",e."IdTypeEntiteFk",
        coalesce(nullif(t."AbrGenerique",''),t."NomGenerique")::text "TypeEntite",e."AdresseEntite",e."PhoneEntite",
        e."EmailEntite",e."SiteWebEntite",e."PresentationPubliqueEntite",e."VisibleAnnuaireEntite",e."ValideEntite",
        (e."LogoEntite" IS NOT NULL) "HasLogo",e."LogoMimeEntite",e."LogoSha256Entite"
        FROM systeme."T_Entite" e LEFT JOIN referentiel."T_Generique" t ON t."ID_Generique"=e."IdTypeEntiteFk"),
        filtered AS MATERIALIZED (SELECT * FROM population v WHERE ''' + ' AND '.join(where) + '''),
        page AS (SELECT * FROM filtered ORDER BY ''' + order + ''' LIMIT %s OFFSET %s)
        SELECT (SELECT count(*) FROM filtered) total,
        COALESCE((SELECT jsonb_agg(to_jsonb(p) ORDER BY ''' + order + ''') FROM page p),'[]'::jsonb) rows''', [*values, take, skip])
    can_manage = context(actor)['canManage']
    return {'rows': [{**projected(row, True), 'canManage': bool(can_manage and row['ValideEntite'] is True and row['IdEntite'] == entity)}
                     for row in result['rows']], 'total': result['total'], 'take': take, 'skip': skip}


class StructuresReadView(APIView):
    permission_classes = [HasModuleAccess]
    http_method_names = ['get', 'head', 'options']

    def get(self, request, kind, pk=None):
        allowed = QUERY if kind == 'annuaire' and pk is None else PROFILE_QUERY if kind == 'profils' and pk is None else set()
        if kind == 'offres':
            allowed = {'q', 'take', 'skip', 'sortBy', 'sortDir'}
        elif kind == 'professionnels':
            allowed = {'q', 'take', 'skip', 'sortBy', 'sortDir'}
        params = products.parameters(request.query_params, allowed)
        if kind == 'references':
            result = references(request.user)
        elif kind == 'contexte':
            result = context(request.user)
        elif kind == 'entreprises':
            result = entity_choices(request.user)
        elif kind == 'profils':
            result = profiles(request.user, params)
        elif kind == 'offres':
            require_module(request.user, 'produits')
            public_record(pk)
            result = products.listing({**params, 'companyId': str(positive(pk))})
        elif kind == 'professionnels':
            result = affiliated_professionals(request.user, pk, params)
        else:
            result = detail(request.user, pk) if pk is not None else listing(params)
        return ok(result)


class StructureProfileView(APIView):
    permission_classes = [HasModuleAccess]
    parser_classes = [ExactJSONParser, MultiPartParser]
    http_method_names = ['get', 'put', 'head', 'options']

    def get(self, request, pk):
        products.parameters(request.query_params, set())
        return ok(entity_documents.profile(request.user, positive(pk), workspace='structures'))

    def put(self, request, pk):
        products.parameters(request.query_params, set())
        body, upload = entity_documents.request_data(request)
        data, replayed = entity_documents.save(request.user, body, upload, entity=positive(pk), workspace='structures')
        return ok(data, message='Profil de la structure enregistré.', meta={'replayed': replayed})


class StructureLogoRenderer(BaseRenderer):
    media_type = 'image/png'
    format = 'png'
    charset = None

    def render(self, data, accepted_media_type=None, renderer_context=None):
        return ExactJSONRenderer().render(data, renderer_context=renderer_context)


class StructureLogoView(APIView):
    permission_classes = [HasModuleAccess]
    renderer_classes = [ExactJSONRenderer, StructureLogoRenderer]
    http_method_names = ['get', 'head', 'options']

    def get(self, request, pk, private=False):
        params = products.parameters(request.query_params, {'v'})
        if params.get('v') is not None and not re.fullmatch(r'[a-f0-9]{16,64}', params['v']):
            raise APIError('Révision de logo invalide.', 'STRUCTURE_QUERY_INVALID', 400)
        entity = entity_documents.target(request.user, positive(pk), workspace='structures') if private else public_record(pk)['IdEntite']
        return entity_documents.logo_response(entity)
