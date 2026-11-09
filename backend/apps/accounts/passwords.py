"""Changement du mot de passe personnel, sans exposer aucun secret à l’audit."""
from functools import lru_cache

from django.conf import settings
from django.contrib.auth.hashers import make_password
from django.contrib.auth.models import User
from django.contrib.auth.password_validation import get_password_validators, validate_password
from django.core.exceptions import ValidationError
from django.db import transaction
from django.utils.decorators import method_decorator
from django.views.decorators.debug import sensitive_post_parameters, sensitive_variables
from rest_framework.exceptions import AuthenticationFailed
from rest_framework.permissions import IsAuthenticated
from rest_framework.throttling import UserRateThrottle
from rest_framework.views import APIView

from apps.core import db
from apps.core.repository import audit
from apps.core.responses import APIError, ok
from .authentication import Actor, password_matches

MIN_LENGTH=12
MAX_LENGTH=128
CURRENT_MAX_LENGTH=4096
FIELDS={"currentPassword","newPassword","confirmPassword"}


@lru_cache(maxsize=1)
def validators():
    base="django.contrib.auth.password_validation."
    return get_password_validators([
        {"NAME":base+"MinimumLengthValidator","OPTIONS":{"min_length":MIN_LENGTH}},
        {"NAME":base+"UserAttributeSimilarityValidator"},
        {"NAME":base+"CommonPasswordValidator"},
        {"NAME":base+"NumericPasswordValidator"},
    ])


def password_policy():
    return {"minLength":MIN_LENGTH,"maxLength":MAX_LENGTH,"currentPasswordMaxLength":CURRENT_MAX_LENGTH,
            "canChangePassword":not settings.DB_READ_ONLY,"requiresReauthentication":True,"otherSessionsRevoked":True}


def validation_error(errors):
    raise APIError(errors,"PASSWORD_CHANGE_VALIDATION",400)


@sensitive_variables()
def password_input(body):
    if not isinstance(body,dict) or set(body)-FIELDS:
        raise APIError("Champ de changement de mot de passe non autorisé.","PASSWORD_CHANGE_VALIDATION",400)
    errors={}
    for key,maximum in (("currentPassword",CURRENT_MAX_LENGTH),("newPassword",MAX_LENGTH),("confirmPassword",MAX_LENGTH)):
        value=body.get(key)
        if not isinstance(value,str) or not value:
            errors[key]="Renseignez ce champ."
        elif len(value)>maximum:
            errors[key]=f"Utilisez au maximum {maximum} caractères."
        else:
            try:value.encode("utf8")
            except UnicodeError:errors[key]="Ce champ contient un caractère non valide."
    if not errors:
        if len(body["newPassword"])<MIN_LENGTH:
            errors["newPassword"]=f"Utilisez au moins {MIN_LENGTH} caractères."
        elif body["newPassword"].isspace():
            errors["newPassword"]="Choisissez un mot de passe contenant d’autres caractères que des espaces."
        if body["newPassword"]!=body["confirmPassword"]:
            errors["confirmPassword"]="Les deux mots de passe ne correspondent pas."
    if errors:validation_error(errors)
    # Les espaces, accents et autres caractères saisis restent inchangés.
    return body["currentPassword"],body["newPassword"]


@sensitive_variables()
def change_password(actor,body):
    db.ensure_writable()
    current,new=password_input(body)
    with transaction.atomic():
        row=db.one('''SELECT "IdUser","MotdepasseUser","NomUser","PrenomUser","EmailUser","ValideUser","IdEntiteFk"
            FROM systeme."T_Utilisateurs" WHERE "IdUser"=%s FOR UPDATE''',[actor.pk])
        if not row or row.get("ValideUser") is not True:
            raise AuthenticationFailed("Votre session n’est plus active. Reconnectez-vous.")
        if not password_matches(current,row.get("MotdepasseUser")):
            validation_error({"currentPassword":"Le mot de passe actuel est incorrect."})
        if password_matches(new,row["MotdepasseUser"]):
            validation_error({"newPassword":"Choisissez un mot de passe différent du mot de passe actuel."})
        # Objet de validation non enregistré ; aucune copie de compte dans auth_user.
        identity=User(username=row.get("EmailUser") or "",email=row.get("EmailUser") or "",
                      first_name=row.get("PrenomUser") or "",last_name=row.get("NomUser") or "")
        try:validate_password(new,user=identity,password_validators=validators())
        except ValidationError as error:validation_error({"newPassword":error.messages})
        encoded=make_password(new)
        updated=db.one('''UPDATE systeme."T_Utilisateurs" SET "MotdepasseUser"=%s,"DateModificationUser"=CURRENT_TIMESTAMP
            WHERE "IdUser"=%s AND "ValideUser" IS TRUE RETURNING "IdUser"''',[encoded,actor.pk])
        if not updated:
            raise APIError("Le compte n’a pas pu être mis à jour. Réessayez.","PASSWORD_CHANGE_CONFLICT",409)
        audit({"schema":"systeme","name":"T_Utilisateurs"},"PASSWORD_CHANGE",
              new={"IdUser":actor.pk,"passwordChanged":True},actor=Actor({**actor.row,**row}))
    return {"requiresReauthentication":True,"otherSessionsRevoked":True}


class PasswordChangeThrottle(UserRateThrottle):
    scope="password_change"
    rate="5/min"

    def get_cache_key(self,request,view):
        return super().get_cache_key(request,view) if request.method=="POST" else None


class ProfileWriteThrottle(UserRateThrottle):
    scope = "profile_write"
    rate = "5/min"

    def get_cache_key(self, request, view):
        return super().get_cache_key(request, view) if request.method in {"PUT", "POST"} else None


@method_decorator(sensitive_post_parameters("currentPassword","newPassword","confirmPassword"),name="dispatch")
class PasswordChangeView(APIView):
    # La sécurité du compte reste disponible sans licence de module métier.
    permission_classes=[IsAuthenticated]
    throttle_classes=[PasswordChangeThrottle]
    http_method_names=["get","post","options"]

    def get(self,request):
        return ok(password_policy())

    def post(self,request):
        return ok(change_password(request.user,request.data),message="Mot de passe modifié. Reconnectez-vous.")
