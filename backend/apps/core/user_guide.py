"""Guide commun versionné ; visibilité calculée par les droits métier courants.

Le contenu pédagogique ne copie aucune donnée d'entreprise. Son catalogue et
chaque accès direct repassent par le même contrôle de licence et de rôle que
l'application documentée, même après un changement de licence dans une session.
"""
import copy
import hashlib
import json
import re
from pathlib import Path
from urllib.parse import urlsplit

from rest_framework.views import APIView

from . import db
from .module_access import MODULE_BY_KEY, require_module
from .permissions import HasModuleAccess
from .responses import APIError, ok
from .tenancy import read_entity


CONTENT_PATH = Path(__file__).with_name('guide_content.json')
SLUG = re.compile(r'[a-z][a-z0-9-]{0,79}\Z')
REFERENCE_MODULE = {'key': 'referentiels', 'label': 'Référentiels', 'path': '/referentiels'}


def configuration_error():
    return APIError('Le guide utilisateur est momentanément indisponible.', 'GUIDE_UNAVAILABLE', 503)


def text(value, maximum=12000):
    if not isinstance(value, str) or not value.strip() or len(value) > maximum:
        raise ValueError('Texte pédagogique invalide.')
    return value


def content():
    """Charger seulement le fichier livré ; aucune résolution de chemin utilisateur."""
    try:
        raw = CONTENT_PATH.read_bytes()
        data = json.loads(raw)
        if not isinstance(data, dict) or set(data) != {'version', 'modules'}:
            raise ValueError('Catalogue invalide.')
        text(data['version'], 40)
        if not isinstance(data['modules'], list) or not data['modules']:
            raise ValueError('Modules absents.')
        modules, seen = {}, set()
        expected = (set(MODULE_BY_KEY) - {'guide'}) | {'referentiels'}
        for module in data['modules']:
            if not isinstance(module, dict) or set(module) != {'key', 'label', 'path', 'icon', 'description', 'articles'}:
                raise ValueError('Module invalide.')
            key = module['key']
            if key not in expected or key in seen:
                raise ValueError('Module inconnu ou répété.')
            seen.add(key)
            target = REFERENCE_MODULE if key == 'referentiels' else MODULE_BY_KEY[key]
            if module['path'] != target['path'] or module['label'] != target['label']:
                raise ValueError('Module incohérent.')
            text(module['icon'], 80)
            text(module['description'], 700)
            if not isinstance(module['articles'], list) or not module['articles']:
                raise ValueError('Parcours absent.')
            article_ids = set()
            for article in module['articles']:
                if not isinstance(article, dict) or set(article) != {'id', 'title', 'summary', 'steps', 'example', 'notes', 'links'}:
                    raise ValueError('Article invalide.')
                if not isinstance(article['id'], str) or not SLUG.fullmatch(article['id']) or article['id'] in article_ids:
                    raise ValueError('Identité de parcours invalide.')
                article_ids.add(article['id'])
                text(article['title'], 200)
                text(article['summary'], 1000)
                if not isinstance(article['steps'], list) or not article['steps']:
                    raise ValueError('Étapes absentes.')
                for step in article['steps']:
                    if not isinstance(step, dict) or set(step) != {'title', 'text'}:
                        raise ValueError('Étape invalide.')
                    text(step['title'], 200)
                    text(step['text'])
                example = article['example']
                if not isinstance(example, dict) or set(example) != {'title', 'text'}:
                    raise ValueError('Exemple absent.')
                text(example['title'], 200)
                text(example['text'])
                if not isinstance(article['notes'], list) or not isinstance(article['links'], list):
                    raise ValueError('Informations associées invalides.')
                for note in article['notes']:
                    text(note)
                for link in article['links']:
                    if not isinstance(link, dict) or set(link) != {'label', 'path'}:
                        raise ValueError('Lien invalide.')
                    text(link['label'], 200)
                    text(link['path'], 500)
                    parsed = urlsplit(link['path'])
                    if parsed.scheme or parsed.netloc or parsed.fragment or parsed.path != target['path']:
                        raise ValueError('Lien hors application.')
            modules[key] = module
        if seen != expected:
            raise ValueError('Catalogue incomplet.')
        return data['version'] + ':' + hashlib.sha256(raw).hexdigest()[:16], modules
    except (OSError, UnicodeError, ValueError, TypeError, KeyError):
        raise configuration_error() from None


def no_criteria(request):
    if request.query_params:
        raise APIError('Aucun critère attendu pour le guide utilisateur.')


def context(actor):
    require_module(actor, 'guide')
    revision, modules = content()
    visible = []
    for key, module in modules.items():
        try:
            require_module(actor, key)
        except APIError as error:
            if error.status_code == 403:
                continue
            raise
        visible.append({name: module[name] for name in ('key', 'label', 'path', 'icon', 'description')})
        visible[-1]['articles'] = [{name: article[name] for name in ('id', 'title', 'summary')}
                                   for article in module['articles']]
    return {'entityId': read_entity(actor), 'platformAdmin': actor.global_admin,
            'modules': visible, 'revision': revision}


def enterprise_choices(actor):
    require_module(actor, 'guide')
    entity = read_entity(actor)
    if entity is None and not actor.global_admin:
        raise APIError('Votre compte doit être rattaché à une entreprise.', 'ORGANISATION_REQUIRED', 403)
    rows = db.query('SELECT "IdEntite","NomEntite","ValideEntite" FROM systeme."T_Entite"'
                    + (' WHERE "IdEntite"=%s' if not actor.global_admin else '')
                    + ' ORDER BY lower("NomEntite"),"IdEntite"', [entity] if not actor.global_admin else [])
    return [{**row, 'id': row['IdEntite'], 'label': row['NomEntite'],
             'active': row['ValideEntite'] is True} for row in rows]


def article(actor, module_key, article_id):
    require_module(actor, 'guide')
    if module_key not in MODULE_BY_KEY and module_key != 'referentiels' or module_key == 'guide':
        raise APIError('Ce parcours est introuvable.', 'GUIDE_ARTICLE_NOT_FOUND', 404)
    # Vérifier avant de charger le texte : un lien conservé ne contourne pas la licence.
    require_module(actor, module_key)
    revision, modules = content()
    module = modules[module_key]
    selected = next((item for item in module['articles'] if item['id'] == article_id), None)
    if selected is None:
        raise APIError('Ce parcours est introuvable.', 'GUIDE_ARTICLE_NOT_FOUND', 404)
    return {'module': {name: module[name] for name in ('key', 'label', 'path')},
            'article': copy.deepcopy(selected), 'revision': revision}


class GuideContextView(APIView):
    permission_classes = [HasModuleAccess]
    http_method_names = ['get', 'head', 'options']

    def get(self, request):
        no_criteria(request)
        return ok(context(request.user))


class GuideArticleView(APIView):
    permission_classes = [HasModuleAccess]
    http_method_names = ['get', 'head', 'options']

    def get(self, request, module_key, article_id):
        no_criteria(request)
        return ok(article(request.user, module_key, article_id))


class GuideEntitiesView(APIView):
    permission_classes = [HasModuleAccess]
    http_method_names = ['get', 'head', 'options']

    def get(self, request):
        no_criteria(request)
        return ok(enterprise_choices(request.user))
