"""Paramètres d’entreprise : la fiche commune, avec ses propres droits de module.

Le socle Paramètres ne dépend pas d’une licence Logistique ou de l’Administration.
Les mutations réutilisent leur service unique, révision, logo et audit atomiques.
"""
from django.conf import settings
from rest_framework.parsers import MultiPartParser
from rest_framework.views import APIView

from . import db
from .module_access import access_snapshot, require_module
from .parsers import ExactJSONParser
from .permissions import HasModuleAccess
from .repository import clean, positive
from .responses import APIError, ok
from .tenancy import read_entity
from apps.logistique import entity_documents


def no_criteria(request):
    if request.query_params:
        raise APIError('Aucun critère attendu pour les paramètres de l’entreprise.')


def enterprise_choices(actor):
    require_module(actor, 'parametres')
    entity = read_entity(actor)
    if entity is None and not actor.global_admin:
        raise APIError('Votre compte doit être rattaché à une entreprise.', 'ORGANISATION_REQUIRED', 403)
    rows = db.query('SELECT "IdEntite", "NomEntite", "ValideEntite" FROM systeme."T_Entite"'
        + (' WHERE "IdEntite"=%s' if not actor.global_admin else '')
        + ' ORDER BY lower("NomEntite"),"IdEntite"', [entity] if not actor.global_admin else [])
    return [{**row, 'id': row['IdEntite'], 'label': row['NomEntite'], 'active': row['ValideEntite'] is True} for row in rows]


def context(actor):
    require_module(actor, 'parametres')
    entity = read_entity(actor)
    if entity is None and not actor.global_admin:
        raise APIError('Votre compte doit être rattaché à une entreprise.', 'ORGANISATION_REQUIRED', 403)
    record = entity_documents.profile(actor, workspace='parametres') if entity is not None else None
    rights = access_snapshot(actor)['modules']['parametres']
    return {'entityId': entity, 'platformAdmin': actor.global_admin,
        'canRead': bool(rights['canRead']), 'canManage': bool(record and record['canConfigure']),
        'readOnly': settings.DB_READ_ONLY, 'profile': record}


class EntitySettingsContextView(APIView):
    permission_classes = [HasModuleAccess]
    http_method_names = ['get', 'head', 'options']

    def get(self, request):
        no_criteria(request)
        return ok(context(request.user))


class EntitySettingsChoicesView(APIView):
    permission_classes = [HasModuleAccess]
    http_method_names = ['get', 'head', 'options']

    def get(self, request):
        no_criteria(request)
        return ok(clean(enterprise_choices(request.user)))


class EntitySettingsProfileView(APIView):
    permission_classes = [HasModuleAccess]
    parser_classes = [ExactJSONParser, MultiPartParser]
    http_method_names = ['get', 'put', 'head', 'options']

    def get(self, request):
        no_criteria(request)
        return ok(entity_documents.profile(request.user, workspace='parametres'))

    def put(self, request):
        no_criteria(request)
        body, upload = entity_documents.request_data(request)
        data, replayed = entity_documents.save(request.user, body, upload, workspace='parametres')
        return ok(data, message='Paramètres de l’entreprise enregistrés.', meta={'replayed': replayed})


class EntitySettingsLogoView(APIView):
    permission_classes = [HasModuleAccess]
    http_method_names = ['get', 'head', 'options']

    def get(self, request, pk):
        no_criteria(request)
        entity = entity_documents.target(request.user, positive(pk, 'Entreprise'), workspace='parametres')
        return entity_documents.logo_response(entity)
