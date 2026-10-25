"""Réinitialisation personnelle par lien signé, sans table ni secret dans les journaux."""
import logging
import re
from email.utils import formataddr
from html import escape
from urllib.parse import urlencode, urlsplit

from django.conf import settings
from django.contrib.auth.hashers import make_password
from django.contrib.auth.models import User
from django.contrib.auth.password_validation import validate_password
from django.contrib.auth.tokens import PasswordResetTokenGenerator
from django.core.exceptions import ValidationError
from django.core.mail import EmailMultiAlternatives, get_connection
from django.core.validators import validate_email
from django.db import transaction
from django.utils.decorators import method_decorator
from django.utils.encoding import force_bytes
from django.utils.http import urlsafe_base64_decode, urlsafe_base64_encode
from django.views.decorators.debug import sensitive_post_parameters, sensitive_variables
from rest_framework.permissions import AllowAny
from rest_framework.throttling import AnonRateThrottle, SimpleRateThrottle
from rest_framework.views import APIView

from apps.core import db
from apps.core.repository import audit
from apps.core.responses import APIError, ok
from .authentication import Actor, password_matches
from .passwords import MAX_LENGTH, MIN_LENGTH, validators

log=logging.getLogger(__name__)
REQUEST_MESSAGE="Si un compte actif correspond à cette adresse, vous recevrez un lien de réinitialisation."
UNAVAILABLE_MESSAGE="La réinitialisation par e-mail est momentanément indisponible. Contactez votre administrateur."
LINK_MESSAGE="Ce lien n’est plus valide. Demandez un nouveau lien."
SMTP_BACKEND="django.core.mail.backends.smtp.EmailBackend"
ACCOUNT_COLUMNS='u."IdUser",u."MotdepasseUser",u."NomUser",u."PrenomUser",u."EmailUser",u."ValideUser",u."IdEntiteFk"'
ACTIVE_ACCOUNT='u."ValideUser" IS TRUE AND (u."IdEntiteFk" IS NULL OR e."ValideEntite" IS TRUE)'


class LegacyResetTokenGenerator(PasswordResetTokenGenerator):
    key_salt="SauverNdeko.accounts.password-reset.v1"


token_generator=LegacyResetTokenGenerator()


def unavailable():
    raise APIError(UNAVAILABLE_MESSAGE,"RESET_UNAVAILABLE",503)


def invalid_link():
    raise APIError(LINK_MESSAGE,"RESET_LINK_INVALID",400)


def reset_error(errors):
    raise APIError(errors,"RESET_VALIDATION",400)


def frontend_base_url():
    value=settings.PASSWORD_RESET_FRONTEND_URL
    if not isinstance(value,str) or not value or len(value)>2048 or any(c.isspace() for c in value):
        raise ValueError("Invalid frontend URL")
    parsed=urlsplit(value)
    if parsed.scheme not in {"http","https"} or not parsed.hostname or parsed.username or parsed.password or parsed.query or parsed.fragment or parsed.path not in {"","/"}:
        raise ValueError("Invalid frontend URL")
    parsed.port  # Valide aussi un port mal formé ; aucune valeur du Host HTTP n’est utilisée.
    return value.rstrip("/")


def mail_configuration():
    if settings.EMAIL_BACKEND!=SMTP_BACKEND or not settings.EMAIL_HOST or not settings.EMAIL_HOST_USER or not settings.EMAIL_HOST_PASSWORD:
        return None
    if not isinstance(settings.EMAIL_PORT,int) or not 1<=settings.EMAIL_PORT<=65535:
        return None
    if bool(settings.EMAIL_USE_TLS)==bool(settings.EMAIL_USE_SSL):
        return None
    try:
        frontend=frontend_base_url()
        from .mail_settings import get_sender
        sender=get_sender()
        validate_email(sender["email"])
        name=sender["name"]
        if not isinstance(name,str) or not name.strip() or len(name)>100 or "\r" in name or "\n" in name:
            return None
        sender["email"].encode("utf8")
        name.encode("utf8")
        return {"sender":sender,"frontend":frontend}
    except (APIError,ValidationError,KeyError,TypeError,ValueError,UnicodeError):
        return None


def smtp_configured():
    """Disponibilité de la configuration seulement, sans connexion ni exposition de secret."""
    return mail_configuration() is not None


def reset_policy():
    return {"available":not settings.DB_READ_ONLY and smtp_configured(),"minLength":MIN_LENGTH,"maxLength":MAX_LENGTH,
            "expiresInMinutes":settings.PASSWORD_RESET_TIMEOUT//60,"requiresReauthentication":True}


def reset_identity(row):
    # Proxy natif non enregistré : aucun compte métier n’est copié vers auth_user.
    return User(pk=row["IdUser"],username=row.get("EmailUser") or "",email=row.get("EmailUser") or "",
                password=row.get("MotdepasseUser") or "",first_name=row.get("PrenomUser") or "",last_name=row.get("NomUser") or "",last_login=None)


@sensitive_variables()
def request_email(body):
    if not isinstance(body,dict) or set(body)-{"email"}:
        reset_error({"email":"Renseignez une adresse e-mail valide."})
    email=body.get("email")
    if not isinstance(email,str) or not email.strip() or len(email.strip())>150:
        reset_error({"email":"Renseignez une adresse e-mail valide."})
    email=email.strip()
    try:
        email.encode("utf8")
        validate_email(email)
    except (UnicodeError,ValidationError):reset_error({"email":"Renseignez une adresse e-mail valide."})
    return email


@sensitive_variables()
def token_input(body,confirm=False):
    allowed={"uid","token","newPassword","confirmPassword"} if confirm else {"uid","token"}
    if not isinstance(body,dict) or set(body)-allowed:
        invalid_link()
    uid,token=body.get("uid"),body.get("token")
    if not isinstance(uid,str) or not re.fullmatch(r"[A-Za-z0-9_-]{1,16}",uid) or not isinstance(token,str) or not re.fullmatch(r"[a-z0-9]{1,13}-[a-f0-9]{32}",token):
        invalid_link()
    try:
        decoded=urlsafe_base64_decode(uid).decode("ascii")
        if not re.fullmatch(r"[1-9][0-9]{0,9}",decoded):invalid_link()
        pk=int(decoded)
        if pk>2147483647 or urlsafe_base64_encode(force_bytes(pk))!=uid:invalid_link()
    except (ValueError,UnicodeError,OverflowError):invalid_link()
    return pk,token


@sensitive_variables()
def new_password_input(body):
    errors={}
    for key in ("newPassword","confirmPassword"):
        value=body.get(key)
        if not isinstance(value,str) or not value:errors[key]="Renseignez ce champ."
        elif len(value)>MAX_LENGTH:errors[key]=f"Utilisez au maximum {MAX_LENGTH} caractères."
        else:
            try:value.encode("utf8")
            except UnicodeError:errors[key]="Ce champ contient un caractère non valide."
    if not errors:
        if len(body["newPassword"])<MIN_LENGTH:errors["newPassword"]=f"Utilisez au moins {MIN_LENGTH} caractères."
        elif body["newPassword"].isspace():errors["newPassword"]="Choisissez un mot de passe contenant d’autres caractères que des espaces."
        if body["newPassword"]!=body["confirmPassword"]:errors["confirmPassword"]="Les deux mots de passe ne correspondent pas."
    if errors:reset_error(errors)
    return body["newPassword"]


@sensitive_variables()
def active_reset_account(pk,lock=False):
    return db.one(f'''SELECT {ACCOUNT_COLUMNS} FROM systeme."T_Utilisateurs" u
        LEFT JOIN systeme."T_Entite" e ON e."IdEntite"=u."IdEntiteFk"
        WHERE u."IdUser"=%s AND {ACTIVE_ACCOUNT}'''+(' FOR UPDATE OF u' if lock else ''),[pk])


@sensitive_variables()
def checked_account(pk,token,lock=False):
    row=active_reset_account(pk,lock=lock)
    if not row or not token_generator.check_token(reset_identity(row),token):invalid_link()
    return row


@sensitive_variables()
def build_reset_email(row,configuration,connection):
    uid=urlsafe_base64_encode(force_bytes(row["IdUser"]))
    token=token_generator.make_token(reset_identity(row))
    link=configuration["frontend"]+"/reset-password#"+urlencode({"uid":uid,"token":token})
    minutes=settings.PASSWORD_RESET_TIMEOUT//60
    text=("Bonjour,\n\nVous avez demandé à réinitialiser votre mot de passe SauverNdeko.\n\n"
          +link+f"\n\nCe lien est valable {minutes} minutes et ne peut être utilisé qu’une fois.\n"
          "Si vous n’êtes pas à l’origine de cette demande, ignorez ce message.\n\nSauverNdeko")
    sender=configuration["sender"]
    message=EmailMultiAlternatives("Réinitialiser votre mot de passe SauverNdeko",text,
                                  formataddr((sender["name"],sender["email"])),[row["EmailUser"]],connection=connection)
    html=('<!doctype html><html lang="fr"><body style="margin:0;background:#f3f5f9;color:#243b53;font-family:Arial,sans-serif">'
          '<main style="max-width:520px;margin:40px auto;padding:32px;background:#fff;border:1px solid #e4e7ec;border-radius:16px">'
          '<p style="font-size:20px;font-weight:700;margin:0 0 28px">SauverNdeko</p>'
          '<h1 style="font-size:24px;margin:0 0 16px">Réinitialiser votre mot de passe</h1>'
          '<p style="font-size:15px;line-height:1.6">Vous avez demandé à réinitialiser votre mot de passe.</p>'
          f'<p style="margin:28px 0"><a href="{escape(link,quote=True)}" style="display:inline-block;padding:14px 22px;border-radius:8px;background:#1d7975;color:white;text-decoration:none;font-weight:700">Choisir un nouveau mot de passe</a></p>'
          f'<p style="font-size:14px;line-height:1.6">Ce lien est valable {minutes} minutes et ne peut être utilisé qu’une fois.</p>'
          '<p style="font-size:13px;line-height:1.6;color:#667085">Si vous n’êtes pas à l’origine de cette demande, ignorez ce message.</p>'
          '</main></body></html>')
    message.attach_alternative(html,"text/html")
    return message


@sensitive_variables()
def send_reset_request(body):
    email=request_email(body)
    if settings.DB_READ_ONLY:unavailable()
    configuration=mail_configuration()
    if not configuration:unavailable()
    connection=get_connection(backend=SMTP_BACKEND,fail_silently=False)
    # Ce contrôle commun ne dépend jamais de l’existence de l’adresse demandée.
    try:connection.open()
    except Exception as error:
        log.warning("Réinitialisation : connexion SMTP indisponible (%s).",type(error).__name__)
        try:connection.close()
        except Exception:pass
        unavailable()
    try:
        rows=db.query(f'''SELECT {ACCOUNT_COLUMNS},e."ValideEntite" AS "EntityActive" FROM systeme."T_Utilisateurs" u
            LEFT JOIN systeme."T_Entite" e ON e."IdEntite"=u."IdEntiteFk"
            WHERE lower(u."EmailUser")=lower(%s) ORDER BY u."IdUser" LIMIT 2''',[email])
        if len(rows)==1 and rows[0].get("ValideUser") is True and (rows[0].get("IdEntiteFk") is None or rows[0].get("EntityActive") is True):
            try:
                delivered=build_reset_email(rows[0],configuration,connection).send(fail_silently=False)
                if delivered!=1:log.warning("Réinitialisation : message non accepté par le serveur SMTP.")
            except Exception as error:
                # Réponse et journal sans adresse, jeton ni détail du serveur destinataire.
                log.warning("Réinitialisation : remise SMTP non aboutie (%s).",type(error).__name__)
    finally:
        try:connection.close()
        except Exception:pass
    return {"accepted":True}


@sensitive_variables()
def check_reset_link(body):
    pk,token=token_input(body)
    checked_account(pk,token)
    return {"valid":True,"minLength":MIN_LENGTH,"maxLength":MAX_LENGTH}


@sensitive_variables()
def confirm_reset(body):
    db.ensure_writable()
    pk,token=token_input(body,confirm=True)
    new=new_password_input(body)
    with transaction.atomic():
        # Un second envoi attend le verrou, puis vérifie le jeton contre le nouveau hash.
        row=checked_account(pk,token,lock=True)
        if password_matches(new,row.get("MotdepasseUser")):
            reset_error({"newPassword":"Choisissez un mot de passe différent du mot de passe actuel."})
        try:validate_password(new,user=reset_identity(row),password_validators=validators())
        except ValidationError as error:reset_error({"newPassword":error.messages})
        encoded=make_password(new)
        changed=db.one('''UPDATE systeme."T_Utilisateurs" SET "MotdepasseUser"=%s,"DateModificationUser"=CURRENT_TIMESTAMP
            WHERE "IdUser"=%s AND "ValideUser" IS TRUE RETURNING "IdUser"''',[encoded,pk])
        if not changed:raise APIError("Le compte n’a pas pu être mis à jour. Réessayez.","RESET_CONFLICT",409)
        audit({"schema":"systeme","name":"T_Utilisateurs"},"PASSWORD_CHANGE",
              new={"IdUser":pk,"passwordChanged":True,"method":"email_reset"},actor=Actor(row))
    return {"requiresReauthentication":True,"otherSessionsRevoked":True}


class ResetRequestIPThrottle(AnonRateThrottle):
    scope="password_reset_request"
    rate="5/hour"

    def get_cache_key(self,request,view):
        return super().get_cache_key(request,view) if request.method=="POST" else None


class ResetRequestEmailThrottle(SimpleRateThrottle):
    scope="password_reset_email"
    rate="3/hour"

    def get_cache_key(self,request,view):
        if request.method!="POST" or not isinstance(request.data,dict):return None
        import hashlib
        email=request.data.get("email")
        if not isinstance(email,str) or len(email)>150:return None
        try:digest=hashlib.sha256(email.strip().casefold().encode("utf8")).hexdigest()
        except UnicodeError:return None
        return self.cache_format % {"scope":self.scope,"ident":digest}


class ResetCheckThrottle(AnonRateThrottle):
    scope="password_reset_check"
    rate="20/min"


class ResetConfirmThrottle(AnonRateThrottle):
    scope="password_reset_confirm"
    rate="5/min"


@method_decorator(sensitive_post_parameters(),name="dispatch")
class PasswordResetView(APIView):
    authentication_classes=[]
    permission_classes=[AllowAny]
    throttle_classes=[ResetRequestIPThrottle,ResetRequestEmailThrottle]
    http_method_names=["get","post","options"]

    def get(self,request):return ok(reset_policy())

    @sensitive_variables()
    def post(self,request):return ok(send_reset_request(request.data),status=202,message=REQUEST_MESSAGE)


@method_decorator(sensitive_post_parameters(),name="dispatch")
class PasswordResetCheckView(APIView):
    authentication_classes=[]
    permission_classes=[AllowAny]
    throttle_classes=[ResetCheckThrottle]
    http_method_names=["post","options"]

    @sensitive_variables()
    def post(self,request):return ok(check_reset_link(request.data))


@method_decorator(sensitive_post_parameters(),name="dispatch")
class PasswordResetConfirmView(APIView):
    authentication_classes=[]
    permission_classes=[AllowAny]
    throttle_classes=[ResetConfirmThrottle]
    http_method_names=["post","options"]

    @sensitive_variables()
    def post(self,request):return ok(confirm_reset(request.data),message="Mot de passe réinitialisé. Connectez-vous.")
