"""Photo du compte connecté : stockage privé, validation et écriture atomique."""
import json
import logging
import re
import uuid
from pathlib import Path
from urllib.parse import urlsplit

from django.conf import settings
from django.db import transaction
from django.http import FileResponse
from rest_framework.parsers import FormParser, MultiPartParser
from rest_framework.permissions import IsAuthenticated
from rest_framework.views import APIView
from rest_framework.renderers import BaseRenderer

from apps.core import db
from apps.core.registry import model
from apps.core.repository import audit, coerce
from apps.core.responses import APIError, ExactJSONRenderer, ok
from apps.logistique.photos import normalize_photo
from .authentication import actor_by_id, profile

log = logging.getLogger(__name__)
PROFILE_FIELDS = {"NomUser", "PrenomUser", "EmailUser", "PhoneUser", "SexeUser", "UrlPhoto"}
PHOTO_PATTERN = re.compile(r"Profils/([1-9][0-9]*)_[a-f0-9]{32}\.jpg")


def stored_photo(value, user_id):
    match = PHOTO_PATTERN.fullmatch(value) if isinstance(value, str) else None
    return bool(match and int(match[1]) == user_id)


def photo_path(value, user_id):
    if not stored_photo(value, user_id):
        raise APIError("Photo indisponible.", "NOT_FOUND", 404)
    root = Path(settings.ARTICLE_MEDIA_ROOT).resolve()
    target = (root / value).resolve()
    if not target.is_relative_to(root / "Profils"):
        raise APIError("Photo indisponible.", "NOT_FOUND", 404)
    return target


def remove_stored_photo(value, user_id):
    if not stored_photo(value, user_id):
        return
    try:
        photo_path(value, user_id).unlink(missing_ok=True)
    except OSError:
        log.warning("Une ancienne photo de profil n’a pas pu être supprimée.")


def profile_values(body):
    if not isinstance(body, dict) or set(body) - PROFILE_FIELDS:
        raise APIError("Champ de profil non autorisé.")
    columns = {column["column_name"]: column for column in model("T_Utilisateurs")["columns"]}
    values = {key: coerce(columns[key], value) for key, value in body.items()}
    if "EmailUser" in values and (
        not isinstance(values["EmailUser"], str)
        or not re.fullmatch(r"[^\s@]+@[^\s@]+\.[^\s@]+", values["EmailUser"])
    ):
        raise APIError("Indiquez une adresse e-mail valide.")
    for key in ("NomUser", "PrenomUser"):
        if key in values and (not isinstance(values[key], str) or not values[key].strip()):
            raise APIError("Nom et prénom obligatoires.")
    if "SexeUser" in values and values["SexeUser"] not in {"M", "F"}:
        raise APIError("Choisissez un sexe proposé.")
    return values


def save_profile(actor, body, upload=None):
    """Conserve le PUT JSON historique et atomise le profil/photo multipart."""
    db.ensure_writable()
    if not isinstance(body, dict):
        raise APIError("Formulaire de profil invalide.")
    data = dict(body)
    remove = data.pop("_removePhoto", False)
    if type(remove) is not bool or (remove and upload is not None):
        raise APIError("Choisissez une seule action pour la photo.")
    if not data and upload is None and not remove:
        raise APIError("Aucune modification à enregistrer.")
    values = profile_values(data)
    if upload is not None:
        try:
            encoded = normalize_photo(upload)
        except APIError as error:
            detail = getattr(error, "detail", {})
            message = detail.get("photo") if isinstance(detail, dict) else None
            raise APIError(str(message or "Choisissez une photo JPEG, PNG ou WebP valide."), "PROFILE_PHOTO_VALIDATION", 400) from error
    new_path = None
    try:
        with transaction.atomic():
            old = db.one(
                'SELECT "IdUser","NomUser","PrenomUser","EmailUser","PhoneUser","SexeUser","UrlPhoto" '
                'FROM systeme."T_Utilisateurs" WHERE "IdUser"=%s AND "ValideUser" IS TRUE FOR UPDATE',
                [actor.pk],
            )
            if not old:
                raise APIError("Compte indisponible.", "NOT_FOUND", 404)
            if "UrlPhoto" in values and values["UrlPhoto"] not in (None, "", old.get("UrlPhoto")):
                candidate = values["UrlPhoto"]
                try:
                    parsed = urlsplit(candidate) if isinstance(candidate, str) else None
                except ValueError:
                    parsed = None
                if not parsed or parsed.scheme not in {"http", "https"} or not parsed.netloc or parsed.username or parsed.password:
                    raise APIError("Ajoutez votre photo avec le sélecteur d’image.", "PROFILE_PHOTO_VALIDATION", 400)
            if upload is not None:
                relative = f"Profils/{actor.pk}_{uuid.uuid4().hex}.jpg"
                new_path = photo_path(relative, actor.pk)
                new_path.parent.mkdir(parents=True, exist_ok=True)
                with new_path.open("xb") as destination:
                    destination.write(encoded)
                values["UrlPhoto"] = relative
            elif remove:
                values["UrlPhoto"] = None
            db.query(
                'UPDATE systeme."T_Utilisateurs" SET '
                + ",".join(db.ident(key) + "=%s" for key in values)
                + ',"DateModificationUser"=CURRENT_TIMESTAMP WHERE "IdUser"=%s AND "ValideUser" IS TRUE',
                [*values.values(), actor.pk],
            )
            updated = {**old, **values}
            audit({"schema": "systeme", "name": "T_Utilisateurs"}, "UPDATE", old=old, new=updated, actor=actor)
            result = profile(actor_by_id(actor.pk))
            previous_photo = old.get("UrlPhoto")
            if "UrlPhoto" in values and previous_photo != values["UrlPhoto"]:
                transaction.on_commit(lambda: remove_stored_photo(previous_photo, actor.pk))
        return result
    except BaseException:
        if new_path is not None:
            try:
                new_path.unlink(missing_ok=True)
            except OSError:
                log.warning("Une photo de profil non enregistrée n’a pas pu être supprimée.")
        raise


class ProfilePhotoFileRenderer(BaseRenderer):
    media_type = 'image/jpeg'
    format = 'jpg'
    charset = None

    def render(self, data, accepted_media_type=None, renderer_context=None):
        return ExactJSONRenderer().render(data, renderer_context=renderer_context)


class ProfilePhotoView(APIView):
    permission_classes = [IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser]
    renderer_classes = [ExactJSONRenderer, ProfilePhotoFileRenderer]
    http_method_names = ["get", "post", "options"]

    def get(self, request):
        target = photo_path(request.user.row.get("UrlPhoto"), request.user.pk)
        try:
            response = FileResponse(target.open("rb"), content_type="image/jpeg", as_attachment=False, filename="profil.jpg")
        except FileNotFoundError as error:
            raise APIError("Photo indisponible.", "NOT_FOUND", 404) from error
        response["Cache-Control"] = "no-store, private"
        response["X-Content-Type-Options"] = "nosniff"
        response["Content-Security-Policy"] = "default-src 'none'; sandbox"
        return response

    def post(self, request):
        db.ensure_writable()
        if set(request.data) - {"payload", "photo"} or set(request.FILES) - {"photo"}:
            raise APIError("Contenu de formulaire non autorisé.")
        if len(request.data.getlist("payload")) != 1 or len(request.FILES.getlist("photo")) > 1:
            raise APIError("Formulaire de profil invalide.")
        raw = request.data.get("payload", "")
        try:
            if not isinstance(raw, str) or len(raw) > 65536:
                raise ValueError()
            body = json.loads(raw)
        except (ValueError, TypeError) as error:
            raise APIError("Formulaire de profil invalide.") from error
        return ok(save_profile(request.user, body, request.FILES.get("photo")), message="Profil mis à jour.")
