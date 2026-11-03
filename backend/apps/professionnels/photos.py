"""Photo commune au compte et au profil, conservée dans le stockage privé.

Le service métier autorise le profil avant d'appeler ce module. Seuls UrlPhoto
et sa date technique sont écrits sur le compte, sans usurper son identité.
"""
import base64
import binascii
from functools import wraps
import uuid

from django.core.files.uploadedfile import SimpleUploadedFile
from django.db import transaction

from apps.accounts.photos import photo_path, remove_stored_photo
from apps.core import db
from apps.core.repository import audit
from apps.core.responses import APIError
from apps.logistique.photos import MAX_BYTES, normalize_photo

MIME_TYPES = {'image/jpeg': ('jpg', b'\xff\xd8'), 'image/png': ('png', b'\x89PNG\r\n\x1a\n'),
              'image/webp': ('webp', b'RIFF')}


def invalid(message, status=422):
    raise APIError({'photoDataUrl': message}, 'PROFESSIONAL_PHOTO_VALIDATION', status)


def parse_photo(body):
    """L'absence ou null conserve l'image ; le retrait exige une intention explicite."""
    remove = body.get('removePhoto', False)
    if remove is None:
        remove = False
    if type(remove) is not bool:
        invalid('Choisissez Oui ou Non pour le retrait de la photo.')
    raw = body.get('photoDataUrl')
    if raw is None:
        return None, remove
    if remove:
        invalid('Choisissez une seule action pour la photo.')
    if not isinstance(raw, str) or len(raw) > ((MAX_BYTES+2)//3)*4+50:
        invalid('Choisissez une photo de 8 Mo au maximum.')
    header, separator, encoded = raw.partition(',')
    mime = header.removeprefix('data:').removesuffix(';base64')
    if not separator or header != 'data:'+mime+';base64' or mime not in MIME_TYPES or not encoded:
        invalid('Choisissez une photo JPEG, PNG ou WebP.')
    try:
        binary = base64.b64decode(encoded, validate=True)
    except (binascii.Error, ValueError, TypeError):
        invalid('Le fichier image est invalide. Sélectionnez de nouveau la photo.')
    if not binary or len(binary) > MAX_BYTES:
        invalid('Choisissez une photo de 8 Mo au maximum.')
    extension, magic = MIME_TYPES[mime]
    if not binary.startswith(magic) or mime == 'image/webp' and binary[8:12] != b'WEBP':
        invalid('Le contenu du fichier ne correspond pas au type d’image annoncé.')
    try:
        return normalize_photo(SimpleUploadedFile('professionnel.'+extension, binary, content_type=mime)), False
    except APIError as error:
        detail = getattr(error, 'detail', {})
        message = detail.get('photo') if isinstance(detail, dict) else None
        invalid(str(message or 'Choisissez une image JPEG, PNG ou WebP valide.'))


def photo_transaction(function):
    """Couvre aussi les erreurs au COMMIT et efface tout fichier non enregistré."""
    @wraps(function)
    def wrapped(*args, **kwargs):
        created = []
        try:
            with transaction.atomic():
                return function(*args, **kwargs, _photo_files=created)
        except BaseException:
            for value, user_id in created:
                remove_stored_photo(value, user_id)
            raise
    return wrapped


def save_photo(actor, profile, change, created):
    encoded, remove = change
    if encoded is None and not remove:
        return
    user_id = profile['IdUserFk']
    account = db.one('SELECT "IdUser","IdEntiteFk","Is_Admin","UrlPhoto" FROM systeme."T_Utilisateurs" WHERE "IdUser"=%s FOR UPDATE', [user_id])
    if not account:
        raise APIError('Compte professionnel introuvable.', 'NOT_FOUND', 404)
    if account['Is_Admin'] is True and not actor.global_admin and actor.pk != user_id:
        raise APIError('La photo d’un administrateur de la plateforme est protégée.', 'PROFESSIONAL_PHOTO_FORBIDDEN', 403)
    if account['IdEntiteFk'] != profile['IdEntiteFk'] and not (account['IdEntiteFk'] is None and account['Is_Admin'] is True and actor.global_admin):
        raise APIError('Ce compte n’appartient pas à l’entreprise du profil.', 'PROFESSIONAL_PHOTO_FORBIDDEN', 403)
    previous = account['UrlPhoto']
    value = None
    if encoded is not None:
        value = 'Profils/'+str(user_id)+'_'+uuid.uuid4().hex+'.jpg'
        path = photo_path(value, user_id)
        path.parent.mkdir(parents=True, exist_ok=True)
        created.append((value, user_id))
        with path.open('xb') as destination:
            destination.write(encoded)
    if value == previous:
        return
    db.query('UPDATE systeme."T_Utilisateurs" SET "UrlPhoto"=%s,"DateModificationUser"=CURRENT_TIMESTAMP WHERE "IdUser"=%s', [value, user_id])
    audit({'schema': 'systeme', 'name': 'T_Utilisateurs'}, 'PROFESSIONAL_PHOTO_CHANGE',
          old={'IdUser': user_id, 'UrlPhoto': previous}, new={'IdUser': user_id, 'UrlPhoto': value}, actor=actor)
    # Le helper vérifie un nom Profils/<ce compte>_<uuid>.jpg. Aucun chemin
    # importé ou URL externe ne peut provoquer une suppression arbitraire.
    if previous != value:
        transaction.on_commit(lambda: remove_stored_photo(previous, user_id), robust=True)
