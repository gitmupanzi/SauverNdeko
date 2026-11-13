"""Profils professionnels : publications explicites, périmètre durable et références SQL.

La projection publique et la recherche restent dans PostgreSQL. Les données de
compte, les notes de gestion et les identifiants professionnels n'en sortent pas.
"""
import hashlib
import hmac
import json
import re
import uuid
from datetime import datetime
from urllib.parse import urlsplit

from django.conf import settings
from django.db import transaction

from apps.core import db
from apps.core.field_references import reference_context, reference_options
from apps.core.module_access import access_snapshot, can_use_tab, require_module, require_tab
from apps.core.reference_integration import entity_actor
from apps.core.repository import audit, positive, set_admin_actor
from apps.core.responses import APIError, ExactEncoder
from apps.core.tenancy import read_entity, require_entity
from .photos import parse_photo, photo_transaction, save_photo

PROFILE_FIELDS = {
    'IdUserFk', 'IdTypeProfessionnelFk', 'IdSpecialiteFk', 'IdSecteurFk',
    'TitrePublic', 'PresentationPublique', 'LocalitePublique', 'ExperienceAns',
    'NumeroIdentification', 'ObsProfessionnel', 'ContactAutorise',
}
TEXT_FIELDS = {'TitrePublic': 180, 'PresentationPublique': 10000,
               'LocalitePublique': 255, 'NumeroIdentification': 50, 'ObsProfessionnel': 5000}
REFERENCES = {
    'types': ('T_Professionnel', 'IdTypeProfessionnelFk'),
    'secteurs': ('T_Professionnel', 'IdSecteurFk'),
    'specialites': ('T_Professionnel', 'IdSpecialiteFk'),
    'competences': ('T_Professionnel_Competence', 'IdCompetenceFk'),
    'prestations': ('T_Professionnel_Prestation', 'IdPrestationFk'),
    'typesLiens': ('T_Professionnel_Entite', 'IdTypeLienFk'),
}
PRIVATE_FIELDS = {'CreationRequestId', 'CreationPayloadHash', 'RechercheVecteur', 'TexteRecherche'}
PUBLISH_FIELDS = ('IdSecteurFk', 'TitrePublic', 'PresentationPublique')
ACTIONS = {'publier', 'depublier', 'archiver', 'reactiver'}


def fail(message, field=None, code='PROFESSIONAL_VALIDATION', status=422):
    raise APIError({field: message} if field else message, code, status)


def capabilities(actor):
    require_module(actor, 'professionnels')
    rights = access_snapshot(actor)['modules']['professionnels']
    entity = read_entity(actor)
    owner = db.one('SELECT "ValideEntite" active,"PartageProfilsPublicParDefaut" publication FROM systeme."T_Entite" WHERE "IdEntite"=%s', [entity]) if entity else None
    manage = bool(actor.admin and can_use_tab(actor, 'professionnels', 'profils', 'manage')
                  and entity and owner and owner['active'] is not False and not settings.DB_READ_ONLY)
    return {'entityId': entity, 'activeEntityId': entity, 'platformAdmin': actor.global_admin,
            'canRead': can_use_tab(actor, 'professionnels', 'annuaire'),
            'canReadRegistry': bool(actor.admin and rights['canManage'] and can_use_tab(actor, 'professionnels', 'profils')),
            'canManage': manage, 'canPublish': manage, 'readOnly': settings.DB_READ_ONLY,
            'defaultProfileVisibility': owner['publication'] if manage else None,
            'policyReason': '' if manage else 'Choisissez une entreprise active pour gérer ses profils.' if actor.global_admin and not entity else 'Consultation uniquement.'}


def writable(actor):
    require_tab(actor, 'professionnels', 'profils', 'manage')
    db.ensure_writable()
    if not actor.admin:
        fail('Votre rôle ne permet pas de gérer les profils professionnels.', code='PROFESSIONAL_FORBIDDEN', status=403)
    return require_entity(actor)


@transaction.atomic
def publication_settings(actor, body):
    owner = writable(actor)
    if not isinstance(body, dict) or set(body) != {'enabled', 'motif'} or type(body['enabled']) is not bool:
        fail('Choisissez Oui ou Non et indiquez le motif du changement.')
    motive = text_value(body['motif'], 'motif', 1000, required=True)
    row = db.one(
        'SELECT "PartageProfilsPublicParDefaut" AS publication FROM systeme."T_Entite" '
        'WHERE "IdEntite"=%s AND "ValideEntite" IS TRUE FOR UPDATE', [owner]
    )
    if not row:
        fail('Choisissez une entreprise active.', code='ENTITY_REQUIRED', status=403)
    enabled = body['enabled']
    if row['publication'] != enabled:
        set_admin_actor(actor)
        db.query('UPDATE systeme."T_Entite" SET "PartageProfilsPublicParDefaut"=%s WHERE "IdEntite"=%s', [enabled, owner])
        audit({'schema': 'systeme', 'name': 'T_Entite'}, 'PROFESSIONAL_PUBLICATION_SETTINGS',
              {'PartageProfilsPublicParDefaut': row['publication']},
              {'PartageProfilsPublicParDefaut': enabled, 'motif': motive}, actor, entity_id=owner)
    return capabilities(actor)


def scope(actor, alias='v'):
    entity = read_entity(actor)
    if actor.global_admin and entity is None:
        return 'TRUE', []
    if entity is None:
        fail('Votre compte doit être rattaché à une entreprise.', code='ENTITY_REQUIRED', status=403)
    return alias+'."IdEntiteFk"=%s', [entity]


def record(actor, pk, *, lock=False):
    require_module(actor, 'professionnels', 'manage')
    require_tab(actor, 'professionnels', 'profils', 'manage' if lock else 'read')
    if not actor.admin:
        fail('La gestion des profils est réservée aux administrateurs autorisés.', code='PROFESSIONAL_FORBIDDEN', status=403)
    predicate, values = scope(actor)
    row = db.one('SELECT v.* FROM professionnel.'+db.ident('T_Professionnel' if lock else 'V_Professionnel_Registre')+
                 ' v WHERE '+predicate+' AND v."IdProfessionnel"=%s'+(' FOR UPDATE' if lock else ''), [*values, positive(pk)])
    if not row:
        fail('Profil introuvable dans cette entreprise.', code='NOT_FOUND', status=404)
    return row


def _label(value):
    from apps.core.reference_labels import reference_label
    return reference_label(value)


def _reference(value):
    return {'id': value.get('ID_Generique'), 'label': _label(value), 'name': value.get('NomGenerique') or ''}


def _photo(value, profile_id, *, management=False):
    if not isinstance(value, str) or not value:
        return ''
    from apps.accounts.photos import PHOTO_PATTERN
    if PHOTO_PATTERN.fullmatch(value):
        version = hashlib.sha256(value.encode('utf8')).hexdigest()[:16]
        return '/api/professionnels/'+('profils' if management else 'annuaire')+'/'+str(profile_id)+'/photo?v='+version
    try:
        parsed = urlsplit(value)
        return value if parsed.scheme in {'http', 'https'} and parsed.netloc and not parsed.username and not parsed.password else ''
    except ValueError:
        return ''


def public_profile(row, actor=None):
    """Liste fermée : jamais de compte complet, de note privée ni de numéro."""
    user = row.get('T_Utilisateurs') or {}
    affiliations = row.get('T_Professionnel_Entite') or [
        {**link, 'T_Entite': {'IdEntite': link.get('IdEntiteFk'), 'NomEntite': link.get('NomEntite')}}
        for link in row.get('Affiliations') or []]
    structures = []
    for link in affiliations:
        entity = link.get('T_Entite') or {}
        structures.append({'id': entity.get('IdEntite'), 'name': entity.get('NomEntite') or '',
                           'address': entity.get('AdresseEntite') or '', 'phone': entity.get('PhoneEntite') or '',
                           'type': _label(link.get('T_GeneriqueTypeLien') or {}), 'principal': link.get('EstPrincipal') is True})
    first, last = user.get('PrenomUser') or '', user.get('NomUser') or ''
    owner_user = row.get('IdUserFk') or user.get('IdUser')
    result = {'id': row['IdProfessionnel'], 'firstName': first, 'lastName': last,
              'fullName': (first+' '+last).strip(), 'photo': _photo(user.get('UrlPhoto'), row['IdProfessionnel']),
              'professionalType': _label(row.get('T_GeneriqueType') or {}),
              'specialty': _label(row.get('T_GeneriqueSpecialite') or {}),
              'sector': _label(row.get('T_GeneriqueSecteur') or {}), 'title': row.get('TitrePublic') or '',
              'summary': row.get('PresentationPublique') or '', 'locality': row.get('LocalitePublique') or '',
              'experience': row.get('ExperienceAns'), 'skills': [_reference(v) for v in row.get('Competences') or []],
              'services': [_reference(v) for v in row.get('Prestations') or []], 'structures': structures,
              'structure': structures[0]['name'] if structures else '',
              'canContact': bool(not settings.DB_READ_ONLY and row.get('ContactAutorise') and (actor is None or owner_user != actor.pk
                  and can_use_tab(actor, 'discussions', 'messages', 'manage')))}
    result['availability'] = 'Contact disponible' if result['canContact'] else 'Contact indisponible'
    return result


def public_record(pk, *, actor=None, contact=False, lock=False):
    row = db.one('SELECT p.* FROM professionnel."V_Professionnel_Public" p WHERE p."IdProfessionnel"=%s', [positive(pk)])
    if not row:
        fail('Ce profil n’est pas disponible.', code='NOT_FOUND', status=404)
    if lock:
        # La publication ne peut être retirée entre ce contrôle et la création
        # de la conversation dans la transaction de l'appelant.
        locked = db.one('SELECT "IdProfessionnel" FROM professionnel."T_Professionnel" WHERE "IdProfessionnel"=%s FOR SHARE', [positive(pk)])
        if not locked:
            fail('Ce profil n’est pas disponible.', code='NOT_FOUND', status=404)
        active = db.one('''SELECT u."IdUser",e."IdEntite" FROM professionnel."T_Professionnel" p
            JOIN systeme."T_Utilisateurs" u ON u."IdUser"=p."IdUserFk"
            JOIN systeme."T_Entite" e ON e."IdEntite"=p."IdEntiteFk"
            WHERE p."IdProfessionnel"=%s AND u."ValideUser" IS TRUE AND e."ValideEntite" IS TRUE
            FOR SHARE OF u,e''', [positive(pk)])
        if not active:
            fail('Ce profil n’est plus disponible.', code='NOT_FOUND', status=404)
        row = db.one('SELECT p.* FROM professionnel."V_Professionnel_Public" p WHERE p."IdProfessionnel"=%s', [positive(pk)])
        if not row:
            fail('Ce profil n’est plus disponible.', code='NOT_FOUND', status=404)
    projected = public_profile(row, actor)
    if contact and not projected['canContact']:
        fail('Ce professionnel ne peut pas être contacté depuis ce profil.', code='PROFESSIONAL_CONTACT_UNAVAILABLE', status=409)
    return row


def _query(raw, *, management=False):
    allowed = {'take', 'skip', 'q', 'sectorId', 'specialtyId', 'competenceId', 'prestationId', 'locality', 'sortBy', 'sortDir'}
    if management:
        allowed |= {'published', 'active'}
    if set(raw)-allowed:
        fail('Filtre non autorisé.')
    take, skip = page_values(raw)
    q = text_value(raw.get('q'), 'q', 300) or ''
    conditions, values = [], []
    if q:
        conditions.append('(v."RechercheVecteur" @@ professionnel.fn_expert_recherche(%s) OR v."TexteRecherche" ILIKE %s)')
        values += [q, '%'+q+'%']
    for key, column in [('sectorId', 'IdSecteurFk'), ('specialtyId', 'IdSpecialiteFk')]:
        if raw.get(key) not in (None, ''):
            # Les vues publique et de gestion portent les identifiants de
            # référence ; aucun libellé n'est transformé en code métier.
            expression = 'v.'+db.ident(column) if management else '(v.'+db.ident('T_GeneriqueSecteur' if key == 'sectorId' else 'T_GeneriqueSpecialite')+'->>\'ID_Generique\')::integer'
            conditions.append(expression+'=%s')
            values.append(positive(raw[key], key))
    for key, relation, column in [('competenceId', 'T_Professionnel_Competence', 'IdCompetenceFk'),
                                  ('prestationId', 'T_Professionnel_Prestation', 'IdPrestationFk')]:
        if raw.get(key) not in (None, ''):
            identifier = positive(raw[key], key)
            if management:
                conditions.append('EXISTS(SELECT 1 FROM professionnel.'+db.ident(relation)+' x WHERE x."IdProfessionnelFk"=v."IdProfessionnel" AND x.'+db.ident(column)+'=%s)')
                values.append(identifier)
            else:
                conditions.append('EXISTS(SELECT 1 FROM jsonb_array_elements(v.'+db.ident('Competences' if key == 'competenceId' else 'Prestations')+') x WHERE x->>\'ID_Generique\'=%s)')
                values.append(str(identifier))
    if raw.get('locality'):
        conditions.append('v."LocalitePublique" ILIKE %s')
        values.append('%'+text_value(raw['locality'], 'locality', 255)+'%')
    if management:
        for key, field in [('published', 'Publie'), ('active', 'ValideProfessionnel')]:
            if raw.get(key) not in (None, ''):
                if raw[key] not in {'true', 'false'}:
                    fail('Choisissez Oui ou Non.', key)
                conditions.append('v.'+db.ident(field)+' IS NOT DISTINCT FROM %s')
                values.append(raw[key] == 'true')
    sort = raw.get('sortBy', 'ModifieLe' if management else 'fullName')
    permitted = {'fullName': 'lower(v."NomComplet")', 'experience': 'v."ExperienceAns"', 'title': 'lower(v."TitrePublic")'}
    if management:
        permitted.update({'ModifieLe': 'v."ModifieLe"', 'Publie': 'v."Publie"'})
    if sort not in permitted or raw.get('sortDir', 'asc') not in {'asc', 'desc'}:
        fail('Tri non autorisé.')
    ordering = permitted[sort]+' '+raw.get('sortDir', 'desc' if management else 'asc')+' NULLS LAST,v."IdProfessionnel"'
    # Une recherche par besoin privilégie les termes présents dans le profil
    # et ses référentiels/synonymes plutôt que l'ordre d'insertion.
    if q and not raw.get('sortBy'):
        ordering = 'ts_rank_cd(v."RechercheVecteur",professionnel.fn_expert_recherche(%s)) DESC,'+ordering
    return conditions, values, ordering, ([q] if q and not raw.get('sortBy') else []), take, skip


def page_values(raw):
    from apps.core.repository import page
    take, skip = page(raw)
    return min(take, 100), skip


def directory(actor, raw):
    require_tab(actor, 'professionnels', 'annuaire')
    conditions, values, order, order_values, take, skip = _query(raw)
    where = ' AND '.join(conditions) or 'TRUE'
    source = 'professionnel."V_Professionnel_Public" v'
    total = db.one('SELECT count(*) n FROM '+source+' WHERE '+where, values)['n']
    rows = db.query('SELECT v.* FROM '+source+' WHERE '+where+' ORDER BY '+order+' LIMIT %s OFFSET %s', [*values, *order_values, take, skip])
    return {'rows': [public_profile(row, actor) for row in rows], 'total': total, 'take': take, 'skip': skip}


def directory_detail(actor, pk):
    require_tab(actor, 'professionnels', 'annuaire')
    row = public_record(pk, actor=actor)
    projected = public_profile(row, actor)
    return {'record': projected, 'canContact': projected['canContact'], 'canEdit': False, 'canPublish': False}


def entities(actor):
    require_module(actor, 'professionnels')
    if not actor.global_admin:
        entity = read_entity(actor)
        return db.query('SELECT "IdEntite" id,"NomEntite" label FROM systeme."T_Entite" WHERE "IdEntite"=%s AND "ValideEntite" IS TRUE', [entity])
    return db.query('SELECT "IdEntite" id,"NomEntite" label FROM systeme."T_Entite" WHERE "ValideEntite" IS TRUE ORDER BY lower("NomEntite"),"IdEntite"')


def _ids(rows, field):
    return [row[field] for row in rows]


def references(actor, profile_id=None):
    require_module(actor, 'professionnels')
    old = record(actor, profile_id) if profile_id is not None else None
    owner = old['IdEntiteFk'] if old else read_entity(actor)
    ref_actor = entity_actor(actor, owner)
    current = {
        'types': old.get('IdTypeProfessionnelFk') if old else None,
        'secteurs': old.get('IdSecteurFk') if old else None,
        'specialites': old.get('IdSpecialiteFk') if old else None,
        'competences': _ids(db.query('SELECT "IdCompetenceFk" FROM professionnel."T_Professionnel_Competence" WHERE "IdProfessionnelFk"=%s', [old['IdProfessionnel']]), 'IdCompetenceFk') if old else [],
        'prestations': _ids(db.query('SELECT "IdPrestationFk" FROM professionnel."T_Professionnel_Prestation" WHERE "IdProfessionnelFk"=%s', [old['IdProfessionnel']]), 'IdPrestationFk') if old else [],
        'typesLiens': [link['IdTypeLienFk'] for link in _affiliations(old['IdProfessionnel']) if link.get('IdTypeLienFk')] if old else [],
    }
    result = {key: reference_options(ref_actor, 'professionnel', table, field, current=current.get(key)) for key, (table, field) in REFERENCES.items()}
    result['configuration'] = {key: reference_context(ref_actor, 'professionnel', table, field) for key, (table, field) in REFERENCES.items()}
    result['referenceMeta'] = {key: {'categoryIds': value['categoryIds'], 'categoryLabels': value['categoryLabels'],
        'defaultCategoryId': value['defaultCategoryId']} for key, value in result['configuration'].items()}
    result['users'] = []
    result['entities'] = []
    # Les options privées de compte ne sont disponibles qu'à un gestionnaire
    # du propriétaire. L'annuaire n'expose aucun email ou liste de comptes.
    caps = capabilities(actor)
    if old or caps['canManage']:
        users = db.query('''SELECT "IdUser" id,concat_ws(' ',"PrenomUser","NomUser") label,
             "ValideUser" active FROM systeme."T_Utilisateurs" WHERE
             ("IdEntiteFk"=%s AND "ValideUser" IS TRUE) OR "IdUser"=%s ORDER BY lower(concat_ws(' ',"PrenomUser","NomUser")),"IdUser"''',
             [owner, old['IdUserFk'] if old else actor.pk if actor.global_admin else None])
        result['users'] = [{**row, 'disabled': row['active'] is not True,
                            'label': row['label']+(' (Inactif)' if row['active'] is not True else '')} for row in users]
        retained = [link['IdEntiteFk'] for link in _affiliations(old['IdProfessionnel'])] if old else []
        structures = db.query('SELECT "IdEntite" id,"NomEntite" label,"ValideEntite" active FROM systeme."T_Entite" WHERE "ValideEntite" IS TRUE OR "IdEntite"=ANY(%s::integer[]) ORDER BY lower("NomEntite"),"IdEntite"', [retained])
        result['entities'] = [{**row, 'disabled': row['active'] is not True,
                               'label': row['label']+(' (Inactive)' if row['active'] is not True else '')} for row in structures]
    return result


def _affiliations(pk):
    return db.query('SELECT * FROM professionnel."T_Professionnel_Entite" WHERE "IdProfessionnelFk"=%s ORDER BY "IdEntiteFk"', [pk])


def detail(actor, pk, replayed=False):
    row = record(actor, pk)
    caps = capabilities(actor)
    projected = public_profile(row, actor)
    safe = {key: value for key, value in row.items() if key not in PRIVATE_FIELDS}
    safe.update({key: projected[key] for key in ('fullName', 'firstName', 'lastName', 'photo', 'professionalType',
        'specialty', 'sector', 'title', 'skills', 'services', 'structures', 'summary', 'locality', 'experience')})
    safe['photo'] = _photo(row.get('UrlPhoto'), row['IdProfessionnel'], management=True)
    safe['photoSharedWithAccount'] = True
    safe['competenceIds'] = _ids(db.query('SELECT "IdCompetenceFk" FROM professionnel."T_Professionnel_Competence" WHERE "IdProfessionnelFk"=%s ORDER BY "IdCompetenceFk"', [pk]), 'IdCompetenceFk')
    safe['prestationIds'] = _ids(db.query('SELECT "IdPrestationFk" FROM professionnel."T_Professionnel_Prestation" WHERE "IdProfessionnelFk"=%s ORDER BY "IdPrestationFk"', [pk]), 'IdPrestationFk')
    safe['affiliations'] = _affiliations(pk)
    manage = caps['canManage'] and caps['entityId'] == row['IdEntiteFk']
    return {'record': safe, '_version': str(row['Revision']), 'canManage': manage,
            'canPublish': manage and row['ValideProfessionnel'] is True, 'replayed': replayed}


def register(actor, raw):
    require_module(actor, 'professionnels', 'manage')
    require_tab(actor, 'professionnels', 'profils')
    if not actor.admin:
        fail('La gestion des profils est réservée aux administrateurs autorisés.', code='PROFESSIONAL_FORBIDDEN', status=403)
    conditions, values, order, order_values, take, skip = _query(raw, management=True)
    predicate, scope_values = scope(actor)
    where = ' AND '.join([predicate, *conditions])
    total = db.one('SELECT count(*) n FROM professionnel."V_Professionnel_Registre" v WHERE '+where, [*scope_values, *values])['n']
    rows = db.query('SELECT v.* FROM professionnel."V_Professionnel_Registre" v WHERE '+where+' ORDER BY '+order+' LIMIT %s OFFSET %s', [*scope_values, *values, *order_values, take, skip])
    caps = capabilities(actor)
    results = []
    for row in rows:
        projected = public_profile(row, actor)
        safe = {key: value for key, value in row.items() if key not in PRIVATE_FIELDS}
        safe.update({key: projected[key] for key in ('fullName', 'firstName', 'lastName', 'photo', 'professionalType', 'specialty', 'sector', 'title')})
        safe['photo'] = _photo(row.get('UrlPhoto'), row['IdProfessionnel'], management=True)
        safe.update(canManage=bool(caps['canManage'] and caps['entityId'] == row['IdEntiteFk']), canPublish=bool(caps['canPublish'] and caps['entityId'] == row['IdEntiteFk'] and row['ValideProfessionnel']))
        results.append(safe)
    return {'rows': results, 'total': total, 'take': take, 'skip': skip}


def text_value(raw, field, limit=255, required=False):
    if raw is None and not required:
        return None
    if not isinstance(raw, str) or len(raw.strip()) > limit or any((ord(c) < 32 and c not in '\t\n\r') or 0xD800 <= ord(c) <= 0xDFFF for c in raw):
        fail('Texte invalide ou trop long.', field)
    value = raw.strip()
    if required and not value:
        fail('Ce champ est obligatoire.', field)
    return value or None


def envelope(actor, body, operation, pk=None, *, batch_digest=None):
    allowed = {'data', 'competenceIds', 'prestationIds', 'affiliations', 'requestId', '_version', 'motif', 'photoDataUrl', 'removePhoto'} if operation in {'create', 'update'} else {'action', 'requestId', '_version', 'motif'}
    if operation == 'create':
        allowed.add('publish')
    if not isinstance(body, dict) or set(body)-allowed:
        fail('Demande invalide.')
    try:
        request_id = str(uuid.UUID(str(body.get('requestId'))))
    except (ValueError, TypeError):
        fail('Identifiant de demande requis.', 'requestId')
    motive = text_value(body.get('motif'), 'motif', 1000, operation != 'create')
    proof = {'actor': actor.pk, 'entity': read_entity(actor), 'id': pk,
             'operation': operation, 'body': body}
    # Réservé au service de panier : un rejeu lie chaque profil au contenu du
    # lot entier, même si une ligne a été retirée après une réponse incertaine.
    # Les demandes individuelles conservent exactement leur empreinte initiale.
    if batch_digest is not None:
        proof['batchDigest'] = batch_digest
    digest = hashlib.sha256(json.dumps(proof, sort_keys=True, ensure_ascii=True, cls=ExactEncoder).encode('utf8')).hexdigest()
    return request_id, digest, motive


def _request(actor, request_id, digest, motive, operation):
    db.query('SELECT pg_advisory_xact_lock(hashtextextended(%s,0))', ['professionnel:'+request_id])
    set_admin_actor(actor)
    for key, value in {'actor_id': actor.pk, 'request_id': request_id, 'payload_hash': digest,
                       'operation': operation, 'motif': motive or ''}.items():
        db.query('SELECT set_config(%s,%s,true)', ['professionnel.'+key, str(value)])


def _replay(request_id, digest, pk=None):
    created = db.one('SELECT "IdProfessionnel" id,"CreationPayloadHash" hash FROM professionnel."T_Professionnel" WHERE "CreationRequestId"=%s', [request_id])
    if created:
        if created['hash'] != digest or pk is not None:
            fail('Cette demande a déjà été utilisée avec un autre contenu.', code='IDEMPOTENCY_CONFLICT', status=409)
        return created['id']
    entry = db.one('''SELECT "NewData" proof FROM systeme."T_Audit_Log"
        WHERE "TableName"='professionnel.T_Professionnel' AND "NewData"->>'_requestId'=%s
        ORDER BY "IdLog" DESC LIMIT 1''', [request_id])
    if entry:
        proof = entry['proof']
        if proof.get('_payloadHash') != digest or str(proof.get('IdProfessionnel')) != str(pk):
            fail('Cette demande a déjà été utilisée avec un autre contenu.', code='IDEMPOTENCY_CONFLICT', status=409)
        return pk
    return None


def _revision(raw, old):
    if not isinstance(raw, str) or not re.fullmatch(r'[1-9][0-9]*', raw) or not hmac.compare_digest(raw, str(old['Revision'])):
        fail('Cette fiche a changé. Rechargez-la avant d’enregistrer.', code='STALE_REVISION', status=409)


def _valid_reference(actor, table, field, value, previous=None):
    if value is None or value == previous:
        return
    choices = reference_options(actor, 'professionnel', table, field)
    if not any(row['id'] == value and not row.get('disabled') and not row.get('incompatible') for row in choices):
        fail('Choisissez une valeur active de la catégorie configurée.', field)


def profile_values(actor, raw, old=None):
    if not isinstance(raw, dict) or set(raw)-PROFILE_FIELDS:
        fail('Champ de profil non autorisé.')
    values = {}
    for field, value in raw.items():
        if field in TEXT_FIELDS:
            values[field] = text_value(value, field, TEXT_FIELDS[field])
        elif field == 'ContactAutorise':
            if type(value) is not bool:
                fail('Choisissez Oui ou Non.', field)
            values[field] = value
        elif field == 'ExperienceAns':
            if value in (None, ''):
                values[field] = None
            elif type(value) is bool or not re.fullmatch(r'[0-9]{1,3}', str(value)) or int(value) > 100:
                fail('L’expérience doit être comprise entre 0 et 100 ans.', field)
            else:
                values[field] = int(value)
        else:
            values[field] = None if value in (None, '') else positive(value, field)
    effective = {**(old or {}), **values}
    if not effective.get('IdUserFk') or not effective.get('IdTypeProfessionnelFk'):
        fail('Choisissez un compte et un type de professionnel.')
    if old and values.get('IdUserFk', old['IdUserFk']) != old['IdUserFk']:
        fail('Le compte d’un profil ne peut pas être remplacé.', 'IdUserFk')
    owner = require_entity(actor)
    ref_actor = entity_actor(actor, owner)
    for field in ('IdTypeProfessionnelFk', 'IdSpecialiteFk', 'IdSecteurFk'):
        _valid_reference(ref_actor, 'T_Professionnel', field, effective.get(field), (old or {}).get(field))
    if not old:
        user = db.one('SELECT "IdUser","IdEntiteFk","ValideUser","Is_Admin" FROM systeme."T_Utilisateurs" WHERE "IdUser"=%s FOR SHARE', [effective['IdUserFk']])
        if not user or user['ValideUser'] is not True or not (user['IdEntiteFk'] == owner or actor.global_admin and user['IdUser'] == actor.pk and user['IdEntiteFk'] is None):
            fail('Choisissez un compte actif de cette entreprise.', 'IdUserFk', status=403)
    return values


def _reference_list(actor, pk, relation, field, raw):
    if not isinstance(raw, list) or len(raw) > 100:
        fail('Choisissez au maximum 100 valeurs.', field)
    identifiers = [positive(value, field) for value in raw]
    if len(set(identifiers)) != len(identifiers):
        fail('Cette liste comporte des doublons.', field)
    current = _ids(db.query('SELECT '+db.ident(field)+' FROM professionnel.'+db.ident(relation)+' WHERE "IdProfessionnelFk"=%s', [pk]), field)
    for value in identifiers:
        _valid_reference(actor, relation, field, value, value if value in current else None)
    removed = set(current)-set(identifiers)
    if removed:
        db.query('DELETE FROM professionnel.'+db.ident(relation)+' WHERE "IdProfessionnelFk"=%s AND '+db.ident(field)+'=ANY(%s::integer[])', [pk, list(removed)])
    for value in identifiers:
        if value not in current:
            db.query('INSERT INTO professionnel.'+db.ident(relation)+'("IdProfessionnelFk",'+db.ident(field)+') VALUES(%s,%s)', [pk, value])


def _date(value, field):
    if value in (None, ''):
        return None
    if not isinstance(value, str) or len(value) > 40:
        fail('Date invalide.', field)
    try:
        parsed = datetime.fromisoformat(value.replace('Z', '+00:00'))
        if parsed.tzinfo is None:
            from zoneinfo import ZoneInfo
            parsed = parsed.replace(tzinfo=ZoneInfo('Africa/Kinshasa'))
        return parsed
    except ValueError:
        fail('Date invalide.', field)


def _save_affiliations(actor, pk, raw):
    if not isinstance(raw, list) or len(raw) > 50:
        fail('Choisissez au maximum 50 structures.', 'affiliations')
    current = {row['IdEntiteFk']: row for row in _affiliations(pk)}
    prepared, seen = [], set()
    for index, entry in enumerate(raw):
        prefix = 'affiliations.'+str(index)
        if not isinstance(entry, dict) or set(entry)-{'IdEntiteFk', 'IdTypeLienFk', 'DateDebut', 'DateFin', 'EstPrincipal', 'ObsLien'}:
            fail('Affiliation invalide.', prefix)
        entity = positive(entry.get('IdEntiteFk'), prefix+'.IdEntiteFk')
        if entity in seen:
            fail('Cette structure est déjà présente.', prefix+'.IdEntiteFk')
        seen.add(entity)
        existing = current.get(entity) or {}
        start, end = _date(entry.get('DateDebut'), prefix+'.DateDebut'), _date(entry.get('DateFin'), prefix+'.DateFin')
        if start and end and end <= start:
            fail('La date de fin doit suivre la date de début.', prefix+'.DateFin')
        main = entry.get('EstPrincipal', False)
        if type(main) is not bool:
            fail('Choisissez Oui ou Non.', prefix+'.EstPrincipal')
        type_id = None if entry.get('IdTypeLienFk') in (None, '') else positive(entry['IdTypeLienFk'], prefix+'.IdTypeLienFk')
        _valid_reference(actor, 'T_Professionnel_Entite', 'IdTypeLienFk', type_id, existing.get('IdTypeLienFk'))
        target = db.one('SELECT "ValideEntite" active FROM systeme."T_Entite" WHERE "IdEntite"=%s FOR SHARE', [entity])
        if not target or target['active'] is not True and not existing:
            fail('Choisissez une structure active.', prefix+'.IdEntiteFk')
        prepared.append((entity, type_id, start, end, main, text_value(entry.get('ObsLien'), prefix+'.ObsLien', 2000)))
    removed = set(current)-seen
    if removed:
        db.query('DELETE FROM professionnel."T_Professionnel_Entite" WHERE "IdProfessionnelFk"=%s AND "IdEntiteFk"=ANY(%s::integer[])', [pk, list(removed)])
    clear_main = [entry[0] for entry in prepared if not entry[4] and current.get(entry[0], {}).get('EstPrincipal')]
    if clear_main:
        # Retirer l'ancien principal avant d'en poser un autre, quelle que
        # soit la position des lignes dans le panier reçu.
        db.query('UPDATE professionnel."T_Professionnel_Entite" SET "EstPrincipal"=false WHERE "IdProfessionnelFk"=%s AND "IdEntiteFk"=ANY(%s::integer[])', [pk, clear_main])
    for row in prepared:
        if row[0] in current:
            # UPDATE conserve une affiliation ancienne devenue inactive.
            # Un UPSERT exécuterait les gardes INSERT avant son conflit et
            # traiterait à tort cette conservation comme une nouvelle liaison.
            db.query('''UPDATE professionnel."T_Professionnel_Entite" SET "IdTypeLienFk"=%s,"DateDebut"=%s,"DateFin"=%s,
              "EstPrincipal"=%s,"ObsLien"=%s WHERE "IdProfessionnelFk"=%s AND "IdEntiteFk"=%s''', [*row[1:], pk, row[0]])
        else:
            db.query('''INSERT INTO professionnel."T_Professionnel_Entite"("IdProfessionnelFk","IdEntiteFk","IdTypeLienFk","DateDebut","DateFin","EstPrincipal","ObsLien")
              VALUES(%s,%s,%s,%s,%s,%s,%s)''', [pk, *row])


def _children(actor, pk, body):
    if 'competenceIds' in body:
        _reference_list(actor, pk, 'T_Professionnel_Competence', 'IdCompetenceFk', body['competenceIds'])
    if 'prestationIds' in body:
        _reference_list(actor, pk, 'T_Professionnel_Prestation', 'IdPrestationFk', body['prestationIds'])
    if 'affiliations' in body:
        _save_affiliations(actor, pk, body['affiliations'])


@photo_transaction
def create(actor, body, *, _photo_files, _batch_digest=None):
    owner = writable(actor)
    request_id, digest, motive = envelope(actor, body, 'create', batch_digest=_batch_digest)
    _request(actor, request_id, digest, motive, 'create')
    replayed = _replay(request_id, digest)
    if replayed:
        return detail(actor, replayed, True)
    values = profile_values(actor, body.get('data'))
    publication = body.get('publish')
    if 'publish' in body and type(publication) is not bool:
        fail('Choisissez Oui ou Non.', 'publish')
    if publication is None:
        preference = db.one('SELECT "PartageProfilsPublicParDefaut" AS publication FROM systeme."T_Entite" WHERE "IdEntite"=%s', [owner])
        publication = bool(preference and preference['publication'] and all(values.get(field) for field in PUBLISH_FIELDS))
    if publication:
        _check_publication(entity_actor(actor, owner), values)
    photo_change = parse_photo(body)
    values.update(IdEntiteFk=owner, ValideProfessionnel=True, Publie=publication, CreeParUserFk=actor.pk,
                  ModifieParUserFk=actor.pk, CreationRequestId=request_id, CreationPayloadHash=digest)
    row = db.one('INSERT INTO professionnel."T_Professionnel"('+','.join(db.ident(k) for k in values)+') VALUES('+','.join(['%s']*len(values))+') RETURNING "IdProfessionnel"', list(values.values()))
    pk = row['IdProfessionnel']
    save_photo(actor, {**values, 'IdProfessionnel': pk}, photo_change, _photo_files)
    _children(entity_actor(actor, owner), pk, body)
    return detail(actor, pk)


@photo_transaction
def modify(actor, pk, body, *, _photo_files):
    owner = writable(actor)
    pk = positive(pk)
    request_id, digest, motive = envelope(actor, body, 'update', pk)
    _request(actor, request_id, digest, motive, 'update')
    old = record(actor, pk, lock=True)
    if old['IdEntiteFk'] != owner:
        fail('Choisissez l’entreprise propriétaire de ce profil.', code='ENTITY_MISMATCH', status=403)
    if _replay(request_id, digest, pk):
        return detail(actor, pk, True)
    _revision(body.get('_version'), old)
    values = profile_values(actor, body.get('data', {}), old)
    photo_change = parse_photo(body)
    if old['ValideProfessionnel'] is not True:
        fail('Réactivez ce profil avant de le modifier.', code='PROFILE_ARCHIVED', status=409)
    values['ModifieParUserFk'] = actor.pk
    db.query('UPDATE professionnel."T_Professionnel" SET '+','.join(db.ident(key)+'=%s' for key in values)+' WHERE "IdProfessionnel"=%s', [*values.values(), pk])
    save_photo(actor, old, photo_change, _photo_files)
    _children(entity_actor(actor, owner), pk, body)
    return detail(actor, pk)


def _check_publication(actor, values):
    for field in PUBLISH_FIELDS:
        if not values.get(field):
            fail('Complétez cette information avant de publier le profil.', field)
    for field in ('IdTypeProfessionnelFk', 'IdSecteurFk', 'IdSpecialiteFk'):
        _valid_reference(actor, 'T_Professionnel', field, values.get(field))


@transaction.atomic
def action(actor, pk, body, *, _batch_digest=None):
    owner = writable(actor)
    pk = positive(pk)
    operation = body.get('action') if isinstance(body, dict) else None
    if operation not in ACTIONS:
        fail('Action non autorisée.')
    request_id, digest, motive = envelope(actor, body, operation, pk, batch_digest=_batch_digest)
    _request(actor, request_id, digest, motive, operation)
    old = record(actor, pk, lock=True)
    if old['IdEntiteFk'] != owner:
        fail('Choisissez l’entreprise propriétaire de ce profil.', code='ENTITY_MISMATCH', status=403)
    if _replay(request_id, digest, pk):
        return detail(actor, pk, True)
    _revision(body.get('_version'), old)
    if _batch_digest is not None:
        if old['ValideProfessionnel'] is not True:
            fail('Réactivez ce profil avant de modifier sa publication.', code='PROFILE_ARCHIVED', status=409)
        if old['Publie'] is (operation == 'publier'):
            return
    if operation == 'publier' and old['ValideProfessionnel'] is not True:
        fail('Réactivez ce profil avant de le publier.', code='PROFILE_ARCHIVED', status=409)
    if operation == 'publier':
        _check_publication(entity_actor(actor, owner), old)
    values = {'ModifieParUserFk': actor.pk}
    if operation in {'publier', 'depublier'}:
        values['Publie'] = operation == 'publier'
    elif operation == 'archiver':
        values.update(ValideProfessionnel=False, Publie=False)
    else:
        values.update(ValideProfessionnel=True, Publie=False)
    db.query('UPDATE professionnel."T_Professionnel" SET '+','.join(db.ident(key)+'=%s' for key in values)+' WHERE "IdProfessionnel"=%s', [*values.values(), pk])
    if _batch_digest is None:
        return detail(actor, pk)


@transaction.atomic
def publication_batch(actor, body):
    owner = writable(actor)
    if not isinstance(body, dict) or set(body) != {'requestId', 'action', 'motif', 'rows'}:
        fail('Vérifiez le format de la sélection.')
    operation = body['action']
    if operation not in ('publier', 'depublier'):
        fail('Action non autorisée.')
    try:
        request_id = uuid.UUID(str(body['requestId']))
    except (TypeError, ValueError):
        fail('Identifiant de demande requis.', 'requestId')
    motive = text_value(body['motif'], 'motif', 1000, required=True)
    rows = body['rows']
    if not isinstance(rows, list) or not 1 <= len(rows) <= 100:
        fail('Sélectionnez de 1 à 100 profils.')
    versions = {}
    for row in rows:
        if not isinstance(row, dict) or set(row) != {'id', '_version'}:
            fail('Vérifiez la sélection des profils.')
        pk = positive(row['id'])
        version = row['_version']
        if pk in versions or not isinstance(version, str) or not re.fullmatch(r'[1-9][0-9]{0,18}', version):
            fail('Rechargez les profils avant de les sélectionner.')
        versions[pk] = version

    selected = sorted(versions.items())
    proof = {'actor': actor.pk, 'entity': owner, 'action': operation, 'motif': motive, 'rows': selected}
    digest = hashlib.sha256(json.dumps(proof, sort_keys=True).encode('utf8')).hexdigest()
    db.query('SELECT pg_advisory_xact_lock(hashtextextended(%s,0))', [f'professionnel:publication:{request_id}'])
    previous = db.one(
        '''SELECT "NewData"->>'digest' AS digest FROM systeme."T_Audit_Log"
           WHERE "TableName"='professionnel.T_Professionnel'
             AND "Operation"='PUBLICATION_BATCH' AND "NewData"->>'requestId'=%s
           ORDER BY "IdLog" DESC LIMIT 1''', [str(request_id)]
    )
    result = {'count': len(selected), 'action': operation}
    if previous:
        if previous['digest'] != digest:
            fail('Cette demande a déjà été utilisée avec un autre contenu.', code='IDEMPOTENCY_CONFLICT', status=409)
        return result
    for pk, version in selected:
        try:
            action(actor, pk, {'requestId': str(uuid.uuid5(request_id, f'publication:{pk}')),
                               'action': operation, 'motif': motive, '_version': version},
                   _batch_digest=digest)
        except APIError as error:
            if error.status_code == 422 and 'PresentationPublique' in error.detail:
                fail(f'Le profil n° {pk} doit avoir une présentation avant d’être publié.')
            raise
    audit({'schema': 'professionnel', 'name': 'T_Professionnel'}, 'PUBLICATION_BATCH',
          new={**result, 'requestId': str(request_id), 'digest': digest}, actor=actor, entity_id=owner)
    return result
