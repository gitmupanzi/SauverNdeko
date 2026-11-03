"""Identité courante partagée ; logo privé en base, instantanés conservés."""
import hashlib
import io
import json
import unicodedata
import uuid
import warnings
from copy import copy
from decimal import Decimal, InvalidOperation
from urllib.parse import urlsplit
from PIL import Image, ImageOps, UnidentifiedImageError
from django.conf import settings
from django.core.exceptions import ValidationError
from django.core.validators import URLValidator, validate_email
from django.db import IntegrityError, transaction
from django.http import HttpResponse
from psycopg.types.json import Jsonb
from rest_framework.parsers import MultiPartParser
from rest_framework.permissions import IsAuthenticated
from rest_framework.views import APIView
from apps.core import db
from apps.core.module_access import access_snapshot, require_module
from apps.core.parsers import ExactJSONParser
from apps.core.permissions import IsERPAdmin
from apps.core.repository import audit, clean, positive
from apps.core.responses import APIError, ExactEncoder, ok
from apps.core.tenancy import read_entity, require_entity

FIELDS = {'NomEntite', 'AdresseEntite', 'EmailEntite', 'PhoneEntite', 'PhoneSecondaireEntite', 'IdentifiantsLegauxEntite', 'MentionDocumentaireEntite', 'SiteWebEntite', 'AfficherEnteteDocument', 'AfficherPiedDocument', 'TauxTVAEntite', 'PartageArticlesPublicParDefaut', 'VisibleAnnuaireEntite', 'PresentationPubliqueEntite'}
OPTIONAL_FIELDS = {'PhoneSecondaireEntite', 'TauxTVAEntite', 'PartageArticlesPublicParDefaut', 'VisibleAnnuaireEntite', 'PresentationPubliqueEntite'}
ADMIN_FIELDS = {'IdTypeEntiteFk', 'ValideEntite'}
LOGO_FIELDS = {'LogoEntite', 'LogoMimeEntite', 'LogoSha256Entite', 'LogoModifieLe'}
OPERATION = 'ENTITY_DOCUMENT_PROFILE'
MAX_LOGO_BYTES = 2 * 1024 * 1024


def current_identity(entity_id, include_logo=False, *, include_locations=False):
    """Lecture interne APRÈS contrôle du document/entreprise par le demandeur.

    Le binaire ne doit jamais rejoindre un profil JSON, export ou journal.
    include_logo est réservé au renderer et au téléchargement image contrôlé.
    """
    entity_id = positive(entity_id, 'Entreprise')
    projection = ',e."LogoEntite"' if include_logo else ''
    locations_join=''
    if include_locations:
        from apps.core.entity_locations import snapshot_projection
        projection+=',points."CollectionRevision",points."Localisations"'
        locations_join=' LEFT JOIN LATERAL (SELECT '+snapshot_projection()+' FROM systeme."T_Entite_Localisation" l WHERE l."IdEntiteFk"=e."IdEntite") points ON TRUE '
    row = db.one('SELECT v.*,e."IdTypeEntiteFk",e."ValideEntite",e."PartageArticlesPublicParDefaut",e."VisibleAnnuaireEntite",e."PresentationPubliqueEntite"' + projection + '''
        FROM systeme."V_IdentiteDocumentaire" v JOIN systeme."T_Entite" e ON e."IdEntite"=v."IdEntite"
        '''+locations_join+''' WHERE v."IdEntite"=%s''', [entity_id])
    if not row:
        raise APIError('Entreprise introuvable.', 'NOT_FOUND', 404)
    if include_logo:
        # Métadonnées et pixels proviennent du même instantané SQL, même si un
        # autre éditeur remplace le logo pendant le téléchargement.
        row['LogoEntite'] = bytes(row['LogoEntite']) if row['LogoEntite'] is not None else None
    return row


def workspace_module(administration=False, workspace=None):
    if workspace is not None and workspace not in {'parametres', 'structures'}:
        raise APIError('Espace de paramétrage invalide.')
    return workspace or ('administration' if administration else 'logistique')


def target(actor, entity=None, *, administration=False, writing=False, creating=False, workspace=None):
    module = workspace_module(administration, workspace)
    require_module(actor, module, 'manage' if writing else 'read')
    if not actor.admin and (writing or workspace != 'parametres'):
        raise APIError('Ce réglage est réservé à l’administrateur de l’entreprise.', 'FORBIDDEN', 403)
    if creating:
        if workspace in {'parametres', 'structures'}:
            raise APIError('La création d’une entreprise se fait dans Administration.', 'GLOBAL_ADMIN_REQUIRED', 403)
        if not actor.global_admin:
            raise APIError('La création d’une entreprise est réservée à la plateforme.', 'GLOBAL_ADMIN_REQUIRED', 403)
        return None
    if workspace == 'structures':
        # La fiche de structure réutilise l'entreprise existante. Sa gestion
        # relève du module Structures, sans licence Logistique/Administration.
        require_module(actor, 'structures', 'manage')
        entity = positive(entity, 'Entreprise')
        if not actor.global_admin and entity != actor.row.get('IdEntiteFk'):
            raise APIError('Entreprise introuvable dans votre périmètre.', 'NOT_FOUND', 404)
        if not db.one('SELECT "IdEntite" FROM systeme."T_Entite" WHERE "IdEntite"=%s', [entity]):
            raise APIError('Entreprise introuvable dans votre périmètre.', 'NOT_FOUND', 404)
        if writing and require_entity(actor) != entity:
            raise APIError('L’entreprise active a changé. Rechargez la fiche.', 'ENTITY_MISMATCH', 403)
        return entity
    if workspace == 'parametres':
        # Le contexte d’entreprise provient de tenancy, jamais d’un identifiant
        # libre envoyé dans le profil. La consultation globale ne cible rien.
        active = read_entity(actor)
        if active is None:
            raise APIError('Choisissez une entreprise pour consulter ses paramètres.', 'ENTITY_REQUIRED', 409)
        if entity is not None and entity != active:
            raise APIError('L’entreprise active a changé. Rechargez la fiche.', 'ENTITY_MISMATCH', 403)
        if writing:
            return require_entity(actor)
        if not db.one('SELECT "IdEntite" FROM systeme."T_Entite" WHERE "IdEntite"=%s', [active]):
            raise APIError('Entreprise introuvable.', 'NOT_FOUND', 404)
        return active
    if not administration:
        active = require_entity(actor)
        if entity is not None and entity != active:
            raise APIError('L’entreprise active a changé. Rechargez la fiche.', 'ENTITY_MISMATCH', 403)
        return active
    entity = positive(entity, 'Entreprise')
    # Le global peut ouvrir une fiche explicite sans changer son contexte actif.
    if not actor.global_admin and entity != actor.row.get('IdEntiteFk'):
        raise APIError('Entreprise introuvable dans votre périmètre.', 'NOT_FOUND', 404)
    row = db.one('SELECT "ValideEntite" FROM systeme."T_Entite" WHERE "IdEntite"=%s', [entity])
    if not row:
        raise APIError('Entreprise introuvable dans votre périmètre.', 'NOT_FOUND', 404)
    if writing and row['ValideEntite'] is False and not actor.global_admin:
        raise APIError('Les écritures de cette entreprise sont désactivées.', 'ENTITY_INACTIVE', 409)
    return entity


def profile(actor, entity=None, *, administration=False, workspace=None):
    entity = target(actor, entity, administration=administration, workspace=workspace)
    # Une lecture SQL unique fournit le parent, les points et leur révision.
    # Aucun verrou d'écriture n'est nécessaire, même en transaction read-only.
    row = current_identity(entity,include_locations=True)
    # Le profil est aussi consommé par les services/formulaires partagés : le
    # pourcentage y conserve son contrat JSON décimal exact, sans flottant.
    row['TauxTVAEntite'] = format(row['TauxTVAEntite'], 'f')
    from apps.core.entity_locations import profile_revision
    row['_version']=profile_revision(entity,row['_version'],row.pop('CollectionRevision'))
    row['documentsExistants'] = db.one('SELECT count(*) AS n FROM logistique."T_DocumentIdentite" WHERE "IdEntiteFk"=%s', [entity])['n']
    rights = access_snapshot(actor)['modules'][workspace_module(administration, workspace)]
    row['canConfigure'] = bool(actor.admin and not settings.DB_READ_ONLY and rights['canManage']
        and (workspace not in {'parametres', 'structures'} or row['ValideEntite'] is not False)
        and (workspace != 'structures' or read_entity(actor) == entity))
    row['canManageEntity'] = actor.global_admin and not settings.DB_READ_ONLY and workspace not in {'parametres', 'structures'}
    row['logoUrl'] = ((f'/api/parametres/entreprises/{entity}/logo' if workspace == 'parametres'
        else f'/api/structures/profils/{entity}/logo' if workspace == 'structures'
        else f'/api/systeme/entites/{entity}/logo') if row.get('HasLogo') else None)
    if administration or workspace in {'parametres', 'structures'}:
        from apps.core.entity_locations import geographical_references
        row['references'] = {'entityTypes': entity_types(entity, row.get('IdTypeEntiteFk'), actor=actor), **geographical_references()}
    if not administration and workspace not in {'parametres', 'structures'}:
        row.pop('Localisations',None)
        for key in ADMIN_FIELDS:
            row.pop(key, None)
    return clean(row)


def values(body):
    errors, result = {}, {}
    def text(raw, key, maximum, required=False, multiline=False):
        if raw is None and not required:
            return None
        if not isinstance(raw, str):
            errors[key] = 'Renseignez une valeur texte.'
            return None
        if multiline:
            raw = raw.replace('\r\n', '\n')
        if any(unicodedata.category(c) in {'Cc', 'Cs', 'Zl', 'Zp'} and not (multiline and c == '\n') for c in raw):
            errors[key] = 'Les caractères de contrôle sont interdits.'
            return None
        value = raw.strip()
        if len(value) > maximum or (required and not value):
            errors[key] = f'Utilisez entre 1 et {maximum} caractères.' if required else f'Utilisez au maximum {maximum} caractères.'
        return value or None
    for key, maximum in [('NomEntite', 200), ('AdresseEntite', 1000), ('EmailEntite', 255), ('PhoneEntite', 20), ('PhoneSecondaireEntite', 20), ('MentionDocumentaireEntite', 1000), ('SiteWebEntite', 255), ('PresentationPubliqueEntite', 5000)]:
        # Un ancien formulaire ignorant la nouvelle coordonnée ne l’efface pas.
        if key in OPTIONAL_FIELDS and key not in body:
            continue
        result[key] = text(body.get(key), key, maximum, key == 'NomEntite', key in {'AdresseEntite', 'MentionDocumentaireEntite', 'PresentationPubliqueEntite'})
    result['EmailEntite'] = result.get('EmailEntite') or ''
    if result['EmailEntite']:
        try:
            validate_email(result['EmailEntite'])
        except ValidationError:
            errors['EmailEntite'] = 'Renseignez une adresse e-mail valide.'
    if result.get('SiteWebEntite'):
        try:
            parsed = urlsplit(result['SiteWebEntite'])
            if parsed.username is not None or parsed.password is not None:
                raise ValueError()
            # Les URL intranet à hôte DNS simple sont utiles en installation
            # locale. Valider cet hôte avec un suffixe réservé sans changer la
            # valeur stockée et sans effectuer de résolution réseau.
            candidate = result['SiteWebEntite']
            host = parsed.hostname or ''
            port = parsed.port  # Refuse également les ports hors limites.
            if host and '.' not in host and ':' not in host and host != 'localhost':
                candidate = parsed._replace(netloc=host + '.invalid' + (':' + str(port) if port is not None else '')).geturl()
            URLValidator(schemes=['http', 'https'])(candidate)
        except (ValidationError, ValueError):
            errors['SiteWebEntite'] = 'Renseignez une adresse web http ou https valide, sans identifiants.'
    for key in ('AfficherEnteteDocument', 'AfficherPiedDocument'):
        if type(body.get(key)) is not bool:
            errors[key] = 'Choisissez une option activée ou désactivée.'
        else:
            result[key] = body[key]
    for key in ('PartageArticlesPublicParDefaut', 'VisibleAnnuaireEntite'):
        if key in body:
            if type(body[key]) is not bool:
                errors[key] = 'Choisissez une option activée ou désactivée.'
            else:
                result[key] = body[key]
    if 'TauxTVAEntite' in body:
        raw = body['TauxTVAEntite']
        try:
            if type(raw) is bool or raw is None or (isinstance(raw, str) and not raw.strip()):
                raise ValueError()
            tax = Decimal(str(raw))
            if not tax.is_finite() or tax < 0 or tax > 100 or tax.as_tuple().exponent < -4:
                raise ValueError()
            result['TauxTVAEntite'] = tax
        except (ValueError, InvalidOperation):
            errors['TauxTVAEntite'] = 'Renseignez un taux entre 0 et 100 %, avec quatre décimales au maximum.'
    identifiers, parsed_ids, labels = body.get('IdentifiantsLegauxEntite'), [], set()
    if not isinstance(identifiers, list) or len(identifiers) > 10:
        errors['IdentifiantsLegauxEntite'] = 'Ajoutez au maximum dix identifiants.'
    else:
        for item in identifiers:
            if not isinstance(item, dict) or set(item) != {'libelle', 'valeur'}:
                errors['IdentifiantsLegauxEntite'] = 'Renseignez un libellé et une valeur pour chaque identifiant.'
                continue
            label = text(item['libelle'], 'IdentifiantsLegauxEntite', 60, True)
            value = text(item['valeur'], 'IdentifiantsLegauxEntite', 180, True)
            if label and label.casefold() in labels:
                errors['IdentifiantsLegauxEntite'] = 'Chaque libellé doit être unique.'
            if label:
                labels.add(label.casefold())
            parsed_ids.append({'libelle': label, 'valeur': value})
    result['IdentifiantsLegauxEntite'] = parsed_ids
    reason = text(body.get('motif'), 'motif', 1000, True, True)
    if errors:
        raise APIError(errors, 'ENTITY_PROFILE_VALIDATION', 400)
    return result, reason


def normalize_logo(upload):
    """Décode des pixels locaux et réencode un PNG sans métadonnées."""
    if upload.size > MAX_LOGO_BYTES:
        raise APIError({'logo': 'Le logo ne doit pas dépasser 2 Mo.'}, 'ENTITY_LOGO_VALIDATION', 400)
    raw = upload.read(MAX_LOGO_BYTES + 1)
    if not raw or len(raw) > MAX_LOGO_BYTES:
        raise APIError({'logo': 'Le logo ne doit pas dépasser 2 Mo.'}, 'ENTITY_LOGO_VALIDATION', 400)
    try:
        with warnings.catch_warnings():
            warnings.simplefilter('error', Image.DecompressionBombWarning)
            with Image.open(io.BytesIO(raw)) as source:
                if source.format not in {'PNG', 'JPEG', 'WEBP'} or getattr(source, 'n_frames', 1) != 1:
                    raise ValueError()
                if not 1 <= source.width <= 4096 or not 1 <= source.height <= 4096 or source.width * source.height > 12000000:
                    raise ValueError()
                source.load()
                pixels = ImageOps.exif_transpose(source).convert('RGBA')
                pixels.thumbnail((1024, 1024), Image.Resampling.LANCZOS)
                normalized = Image.new('RGBA', pixels.size)
                normalized.paste(pixels)
                stream = io.BytesIO()
                normalized.save(stream, format='PNG', optimize=True)
                result = stream.getvalue()
                if len(result) > MAX_LOGO_BYTES:
                    raise ValueError()
                return result
    except (UnidentifiedImageError, ValueError, OSError, Image.DecompressionBombError, Image.DecompressionBombWarning) as error:
        raise APIError({'logo': 'Choisissez un logo PNG, JPEG ou WebP fixe, de 4096 pixels par côté et 12 millions de pixels au maximum.'}, 'ENTITY_LOGO_VALIDATION', 400) from error


def request_data(request):
    if (request.content_type or '').startswith('multipart/form-data'):
        if set(request.data) - {'payload', 'logo'} or set(request.FILES) - {'logo'}:
            raise APIError('Contenu de formulaire non autorisé.')
        if len(request.data.getlist('payload')) != 1 or len(request.FILES.getlist('logo')) > 1:
            raise APIError('Formulaire d’entreprise invalide.')
        try:
            raw = request.data.get('payload', '')
            if not isinstance(raw, str) or len(raw) > 32768:
                raise ValueError()
            def unique(items):
                value = {}
                for key, item in items:
                    if key in value:
                        raise ValueError()
                    value[key] = item
                return value
            body = json.loads(raw, object_pairs_hook=unique)
        except (ValueError, TypeError, UnicodeError):
            raise APIError('Formulaire d’entreprise invalide.')
        if 'logo' in request.data and 'logo' not in request.FILES:
            raise APIError({'logo': 'Choisissez un fichier image local.'}, 'ENTITY_LOGO_VALIDATION', 400)
        return body, request.FILES.get('logo')
    return request.data, None


def entity_types(entity, current=None, actor=None):
    """La présentation et la validation utilisent les mêmes correspondances FK."""
    from apps.core.field_references import reference_options
    # target() a déjà autorisé cette entreprise explicite. Une création n’a pas
    # encore d’entreprise propriétaire et reprend donc le défaut global.
    context=copy(actor) if actor is not None else None
    if context is not None:
        context._context_entity=entity
    elif entity is not None:
        raise APIError('Le contexte de l’entreprise doit être vérifié.', 'ENTITY_CONTEXT_REQUIRED', 403)
    return reference_options(context,'systeme','T_Entite','IdTypeEntiteFk',current=current)


def admin_values(body, actor, old, entity):
    result = {}
    for key in ADMIN_FIELDS:
        if key not in body:
            continue
        raw = body[key]
        if key == 'ValideEntite':
            if type(raw) is not bool:
                raise APIError({key: 'Choisissez un état activé ou désactivé.'}, 'ENTITY_PROFILE_VALIDATION', 400)
            result[key] = raw
        else:
            result[key] = positive(raw, 'Type d’entreprise') if raw is not None else None
        if not actor.global_admin and result[key] != (old or {}).get(key):
            raise APIError('Le type et l’état de l’entreprise sont gérés par la plateforme.', 'GLOBAL_ADMIN_REQUIRED', 403)
    type_id = result.get('IdTypeEntiteFk')
    if type_id is not None and type_id != (old or {}).get('IdTypeEntiteFk'):
        if not any(row['id'] == type_id for row in entity_types(entity,actor=actor)):
            raise APIError({'IdTypeEntiteFk': 'Choisissez un type d’entreprise actif dans le référentiel.'}, 'ENTITY_PROFILE_VALIDATION', 400)
    return result


def save(actor, body, upload=None, *, entity=None, administration=False, creating=False, workspace=None):
    entity = target(actor, entity, administration=administration, writing=True, creating=creating, workspace=workspace)
    db.ensure_writable()
    includes_locations = administration or workspace in {'parametres', 'structures'}
    allowed = FIELDS | {'logoAction', 'motif', 'requestId'} | (ADMIN_FIELDS | {'Localisations'} if includes_locations else set())
    required = (FIELDS - OPTIONAL_FIELDS) | {'motif', 'requestId'}
    if not creating:
        allowed |= {'IdEntite', '_version'}
        required |= {'IdEntite', '_version'}
    if not isinstance(body, dict) or set(body) - allowed or required - set(body):
        raise APIError('Demande d’identité d’entreprise invalide.')
    if not creating:
        if type(body['IdEntite']) is not int or body['IdEntite'] != entity:
            raise APIError('L’entreprise ciblée a changé. Rechargez la fiche.', 'ENTITY_MISMATCH', 403)
        if not isinstance(body['_version'], str) or not 1 <= len(body['_version']) <= 120:
            raise APIError('Rechargez le profil avant de modifier.', 'ENTITY_PROFILE_VERSION', 409)
    try:
        request_id = str(uuid.UUID(body['requestId']))
    except (ValueError, TypeError, AttributeError):
        raise APIError('Identifiant de demande invalide.')
    data, reason = values(body)
    action = body.get('logoAction', 'keep')
    if not isinstance(action, str) or action not in {'keep', 'replace', 'remove'} or (action == 'replace') != (upload is not None):
        raise APIError({'logo': 'Choisissez une seule action pour le logo.'}, 'ENTITY_LOGO_VALIDATION', 400)
    encoded = normalize_logo(upload) if upload is not None else None
    digest = hashlib.sha256(encoded).hexdigest() if encoded is not None else None
    operation = OPERATION + ('_CREATE' if creating else '')
    fingerprint = hashlib.sha256(json.dumps({'entity': entity, 'values': data, 'admin': {key: body[key] for key in sorted(ADMIN_FIELDS) if key in body}, 'motif': reason, 'logoAction': action, 'logoSha256': digest, **({'Localisations': body['Localisations']} if 'Localisations' in body else {})}, sort_keys=True, ensure_ascii=False, separators=(',', ':'), cls=ExactEncoder).encode()).hexdigest()
    with transaction.atomic():
        db.query('SELECT pg_advisory_xact_lock(hashtextextended(%s,0))', [operation + ':' + str(actor.pk) + ':' + request_id])
        previous = db.one('SELECT "NewData" FROM systeme."T_Audit_Log" WHERE "Operation"=%s AND "NewData" @> %s ORDER BY "IdLog" DESC LIMIT 1', [operation, Jsonb({'requestId': request_id, '_actor': {'IdUser': actor.pk}})])
        if previous:
            if previous['NewData'].get('fingerprint') != fingerprint:
                raise APIError('Cette demande a déjà été utilisée avec un autre contenu.', 'REQUEST_CONFLICT', 409)
            return profile(actor, previous['NewData']['IdEntite'], administration=administration, workspace=workspace), True
        old = None if creating else db.one('SELECT "IdEntite","IdTypeEntiteFk","ValideEntite",xmin::text AS "_version",'
            + ','.join(db.ident(key) for key in sorted(FIELDS | (LOGO_FIELDS - {'LogoEntite'})))
            + ' FROM systeme."T_Entite" WHERE "IdEntite"=%s FOR UPDATE', [entity])
        from apps.core.entity_locations import profile_revision
        if not creating and (not old or profile_revision(entity,old['_version']) != body['_version']):
            raise APIError('Le profil a changé. Rechargez la fiche avant de confirmer.', 'VERSION_CONFLICT', 409)
        if old and old['ValideEntite'] is False and (not administration or not actor.global_admin):
            raise APIError('Les écritures de cette entreprise sont désactivées.', 'ENTITY_INACTIVE', 409)
        if workspace in {'parametres', 'structures'} and any(key in body and body[key] != (old or {}).get(key) for key in ADMIN_FIELDS):
            raise APIError('Le type et l’état de l’entreprise se modifient dans Administration.', 'ENTITY_ADMIN_FIELDS', 403)
        if administration:
            data.update(admin_values(body, actor, old, entity))
        fields, params = [], []
        for key in sorted(data):
            fields.append(db.ident(key) + '=%s')
            params.append(Jsonb(data[key]) if key == 'IdentifiantsLegauxEntite' else data[key])
        if action != 'keep':
            fields += ['"LogoEntite"=%s', '"LogoMimeEntite"=%s', '"LogoSha256Entite"=%s', '"LogoModifieLe"=' + ('clock_timestamp()' if action == 'replace' else 'NULL')]
            params += [encoded, 'image/png' if encoded is not None else None, digest]
        try:
            with transaction.atomic():
                if creating:
                    insert_data = dict(data)
                    if action == 'replace':
                        insert_data.update(LogoEntite=encoded, LogoMimeEntite='image/png', LogoSha256Entite=digest)
                    names = sorted(insert_data)
                    entity = db.one('INSERT INTO systeme."T_Entite" (' + ','.join(db.ident(key) for key in names)
                        + (',"LogoModifieLe"' if action == 'replace' else '') + ') VALUES (' + ','.join(['%s'] * len(names))
                        + (',clock_timestamp()' if action == 'replace' else '') + ') RETURNING "IdEntite"',
                        [Jsonb(insert_data[key]) if key == 'IdentifiantsLegauxEntite' else insert_data[key] for key in names])['IdEntite']
                else:
                    db.query('UPDATE systeme."T_Entite" SET ' + ','.join(fields) + ' WHERE "IdEntite"=%s', [*params, entity])
        except IntegrityError as error:
            if getattr(error.__cause__, 'sqlstate', None) == '23505':
                constraint = getattr(getattr(error.__cause__, 'diag', None), 'constraint_name', '') or ''
                key = 'PhoneEntite' if 'PhoneEntite' in constraint else 'EmailEntite'
                raise APIError({key: 'Cette coordonnée est déjà utilisée. Vérifiez la valeur de cette entreprise.'}, 'ENTITY_PROFILE_VALIDATION', 400) from error
            raise
        if 'Localisations' in body:
            from apps.core.entity_locations import save_locations
            location_actor=copy(actor)
            location_actor._context_entity=entity
            save_locations(location_actor,entity,body['Localisations'])
        updated = current_identity(entity)
        audit_actor = copy(actor)
        audit_actor._context_entity = entity
        audit({'schema': 'systeme', 'name': 'T_Entite'}, operation,
            old={key: old.get(key) for key in FIELDS | ADMIN_FIELDS | {'IdEntite', 'LogoMimeEntite', 'LogoSha256Entite', 'LogoModifieLe'}} if old else None,
            new={**{key: updated.get(key) for key in FIELDS | ADMIN_FIELDS | {'IdEntite', 'HasLogo', 'LogoMimeEntite', 'LogoSha256Entite', 'LogoModifieLe'}}, 'motif': reason, 'requestId': request_id, 'fingerprint': fingerprint}, actor=audit_actor)
        return profile(actor, entity, administration=administration, workspace=workspace), False


class EntityDocumentIdentityView(APIView):
    permission_classes = [IsERPAdmin]
    parser_classes = [ExactJSONParser, MultiPartParser]
    def get(self, request):
        if request.query_params:
            raise APIError('Aucun critère attendu pour le profil documentaire.')
        return ok(profile(request.user))
    def put(self, request):
        body, upload = request_data(request)
        data, replayed = save(request.user, body, upload)
        return ok(data, message='Identité de l’entreprise enregistrée.', meta={'replayed': replayed})


class EntityIdentityDefaultsView(APIView):
    permission_classes = [IsERPAdmin]

    def get(self, request):
        require_module(request.user, 'administration')
        if not request.user.global_admin:
            raise APIError('La création d’une entreprise est réservée à la plateforme.', 'GLOBAL_ADMIN_REQUIRED', 403)
        if request.query_params:
            raise APIError('Aucun critère attendu pour les valeurs initiales.')
        data = {key: None for key in FIELDS | ADMIN_FIELDS}
        data.update(IdentifiantsLegauxEntite=[], AfficherEnteteDocument=True,
            AfficherPiedDocument=True, TauxTVAEntite='0', PartageArticlesPublicParDefaut=True, VisibleAnnuaireEntite=False, ValideEntite=True, HasLogo=False,
            canConfigure=not settings.DB_READ_ONLY and access_snapshot(request.user)['modules']['administration']['canManage'],
            canManageEntity=not settings.DB_READ_ONLY, references={'entityTypes': entity_types(None,actor=request.user)})
        from apps.core.entity_locations import geographical_references
        data['Localisations']=[]
        data['references'].update(geographical_references())
        return ok(data)


class EntityLogoView(APIView):
    permission_classes = [IsAuthenticated]
    http_method_names = ['get', 'head', 'options']
    def get(self, request, pk):
        if request.query_params:
            raise APIError('Aucun critère attendu pour le logo.')
        actor, entity = request.user, positive(pk, 'Entreprise')
        if not actor.admin:
            raise APIError('Accès réservé aux gestionnaires autorisés.', 'FORBIDDEN', 403)
        rights = access_snapshot(actor)['modules']
        if not any(rights.get(key, {}).get('canRead') for key in ('logistique', 'administration')):
            raise APIError('Votre rôle ne permet pas cet accès.', 'MODULE_ROLE_FORBIDDEN', 403)
        if not actor.global_admin and entity != actor.row.get('IdEntiteFk'):
            raise APIError('Logo indisponible dans votre périmètre.', 'NOT_FOUND', 404)
        return logo_response(entity)


def logo_response(entity):
    """Binaire partagé, seulement APRÈS autorisation du parent par l'appelant."""
    row = current_identity(entity, include_logo=True)
    blob = row.get('LogoEntite')
    if blob is None:
        raise APIError('Aucun logo enregistré.', 'NOT_FOUND', 404)
    if row.get('LogoMimeEntite') != 'image/png' or hashlib.sha256(blob).hexdigest() != row.get('LogoSha256Entite'):
        raise APIError('Le logo enregistré doit être vérifié.', 'ENTITY_LOGO_INTEGRITY', 409)
    response = HttpResponse(blob, content_type='image/png')
    response['Content-Disposition'] = 'inline; filename="logo.png"'
    response['Cache-Control'] = 'no-store, private'
    response['X-Content-Type-Options'] = 'nosniff'
    response['Content-Security-Policy'] = "default-src 'none'; sandbox"
    response['ETag'] = '"' + row['LogoSha256Entite'] + '"'
    return response
