"""Fiche de coordonnées partagée, liée à une vraie FK territoriale N1 à N5."""
import unicodedata
from urllib.parse import urlsplit

from django.core.exceptions import ValidationError
from django.core.validators import URLValidator, validate_email

from . import db
from .repository import audit, set_admin_actor
from .responses import APIError

FIELDS = {'AdresseTerritoire': 2000, 'TelephoneTerritoire': 50,
          'TelephoneSecondaireTerritoire': 50, 'EmailTerritoire': 255,
          'SiteWebTerritoire': 255, 'InformationsAccueilTerritoire': 3000,
          'HorairesOuvertureTerritoire': 1000, 'PublierCoordonneesAnnuaire': None}
BOOLEAN_FIELD = 'PublierCoordonneesAnnuaire'
KINDS = {f'niveaux{level}' for level in range(1, 6)}
TABLE = 'geolocalisation."T_CoordonneesTerritoire"'


def foreign_key(kind):
    if kind not in KINDS:
        raise APIError('Ces coordonnées concernent les niveaux territoriaux 1 à 5.', 'TERRITORIAL_CONTACTS_VALIDATION', 422)
    return 'ID_Niveau_' + kind[-1] + 'Fk'


def split(kind, data, old=None):
    if not isinstance(data, dict):
        raise APIError('Objet JSON attendu.', 'TERRITORIAL_CONTACTS_VALIDATION', 422)
    contacts = {key: value for key, value in data.items() if key in FIELDS}
    if contacts and kind not in KINDS:
        foreign_key(kind)
    result, errors = {}, {}
    for key, raw in contacts.items():
        if key == BOOLEAN_FIELD:
            if type(raw) is not bool:
                errors[key] = 'Choisissez explicitement de publier ou non ces coordonnées.'
            else:
                result[key] = raw
            continue
        if old is not None and raw == old.get(key):
            result[key] = raw
            continue
        if raw is None:
            result[key] = None
            continue
        if not isinstance(raw, str):
            errors[key] = 'Renseignez une valeur texte.'
            continue
        multiline = key in {'AdresseTerritoire', 'InformationsAccueilTerritoire', 'HorairesOuvertureTerritoire'}
        raw = raw.replace('\r\n', '\n') if multiline else raw
        if any(unicodedata.category(char) in {'Cc', 'Cs', 'Zl', 'Zp'} and not (multiline and char in '\r\n') for char in raw):
            errors[key] = 'Retirez les caractères de contrôle.'
            continue
        value = raw.strip() or None
        if value is not None and len(value) > FIELDS[key]:
            errors[key] = f'Utilisez au maximum {FIELDS[key]} caractères.'
            continue
        if key == 'EmailTerritoire' and value:
            try:
                validate_email(value)
            except ValidationError:
                errors[key] = 'Renseignez une adresse e-mail valide.'
        if key == 'SiteWebTerritoire' and value:
            try:
                parsed = urlsplit(value)
                if parsed.username is not None or parsed.password is not None:
                    raise ValueError()
                URLValidator(schemes=['http', 'https'])(value)
            except (ValidationError, ValueError):
                errors[key] = 'Renseignez une adresse web http ou https valide, sans identifiants.'
        result[key] = value
    if errors:
        raise APIError(errors, 'TERRITORIAL_CONTACTS_VALIDATION', 422)
    return {key: value for key, value in data.items() if key not in FIELDS}, result


def save(actor, kind, parent_id, data, *, delete=False):
    """Appel sous verrou du parent et dans la transaction territoriale globale.

    Une omission préserve les coordonnées ; effacer explicitement tous leurs
    champs supprime la fiche facultative. Aucun contact ni entreprise n'est
    attribué par déduction. La suppression liée est annulée si le parent reste
    référencé par un autre objet et refuse finalement sa propre suppression.
    """
    if kind not in KINDS or not data and not delete:
        return
    fk = foreign_key(kind)
    old = db.one('SELECT * FROM ' + TABLE + ' WHERE ' + db.ident(fk) + '=%s FOR UPDATE', [parent_id])
    effective = {**{key: (old or {}).get(key, False if key == BOOLEAN_FIELD else None) for key in FIELDS}, **data}
    if not delete and old and all(old.get(key) == effective[key] for key in FIELDS):
        return
    obj = {'schema': 'geolocalisation', 'name': 'T_CoordonneesTerritoire'}
    set_admin_actor(actor)
    if delete or not any(value is not None for key, value in effective.items() if key != BOOLEAN_FIELD) and not effective[BOOLEAN_FIELD]:
        if old:
            db.query('DELETE FROM ' + TABLE + ' WHERE ' + db.ident(fk) + '=%s', [parent_id])
            audit(obj, 'DELETE', old=old, actor=actor)
        return
    names = sorted(FIELDS)
    if old:
        updated = db.one('UPDATE ' + TABLE + ' SET ' + ','.join(db.ident(key) + '=%s' for key in names)
            + ' WHERE ' + db.ident(fk) + '=%s RETURNING *', [*[effective[key] for key in names], parent_id])
    else:
        updated = db.one('INSERT INTO ' + TABLE + ' (' + db.ident(fk) + ',' + ','.join(map(db.ident, names))
            + ') VALUES (' + ','.join(['%s'] * (len(names) + 1)) + ') RETURNING *', [parent_id, *[effective[key] for key in names]])
    audit(obj, 'UPDATE' if old else 'INSERT', old=old, new=updated, actor=actor)


def projection():
    fields = ','.join(('COALESCE(c.' + db.ident(key) + ',false) AS ' + db.ident(key))
                      if key == BOOLEAN_FIELD else 'c.' + db.ident(key) for key in FIELDS)
    # xmin ET contenu détectent également deux changements réalisés dans une
    # même transaction. Un parent inchangé ne masque pas une édition de sa fiche.
    revision = '''concat('territory:',v.xmin::text,':',md5(jsonb_build_array(
        c."ID_CoordonneesTerritoire",c.xmin::text,to_jsonb(c))::text)) AS "_version"'''
    return fields + ',c."ModifieLe" AS "CoordonneesModifieLe",' + revision
