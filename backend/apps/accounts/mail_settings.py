"""Expéditeur de plateforme dans une clé JSON dédiée du registre de réglages existant."""
import unicodedata
import smtplib,ssl
from django.core.mail import get_connection
from django.utils import timezone
from rest_framework.throttling import SimpleRateThrottle

from django.conf import settings
from django.core.exceptions import ValidationError
from django.core.validators import validate_email
from django.db import transaction
from psycopg.types.json import Jsonb
from rest_framework.permissions import IsAuthenticated
from rest_framework.views import APIView

from apps.core import db
from apps.core.registry import model
from apps.core.repository import audit
from apps.core.responses import APIError, ok

SETTING_KEY = "messagerie.sender"
DEFAULT_EMAIL = "benjaminmupanzi@gmail.com"
DEFAULT_NAME = "SauverNdeko"
FIELDS = {"senderEmail", "senderName"}
EMAIL_MAX_LENGTH = 254
NAME_MAX_LENGTH = 100


def require_platform_admin(actor):
    if not actor or not getattr(actor, "is_authenticated", False) or not getattr(actor, "global_admin", False):
        raise APIError("Réglage réservé à l’administration de la plateforme.", "PLATFORM_ADMIN_REQUIRED", 403)


def validated_sender(body):
    if not isinstance(body, dict) or set(body) != FIELDS:
        raise APIError("Renseignez uniquement l’adresse et le nom de l’expéditeur.", "MAIL_SETTINGS_VALIDATION", 400)
    errors = {}
    values = {}
    for field, maximum in (("senderEmail", EMAIL_MAX_LENGTH), ("senderName", NAME_MAX_LENGTH)):
        raw = body[field]
        if not isinstance(raw, str) or not raw.strip():
            errors[field] = "Renseignez ce champ."
            continue
        if any(unicodedata.category(character) in {"Cc", "Cs", "Zl", "Zp"} for character in raw):
            errors[field] = "Les caractères de contrôle et les retours à la ligne sont interdits."
            continue
        value = raw.strip()
        if len(value) > maximum:
            errors[field] = f"Utilisez au maximum {maximum} caractères."
            continue
        values[field] = value
    if "senderEmail" in values:
        try:
            validate_email(values["senderEmail"])
        except ValidationError:
            errors["senderEmail"] = "Renseignez une adresse e-mail valide."
    if errors:
        raise APIError(errors, "MAIL_SETTINGS_VALIDATION", 400)
    return values


def setting_row(*, lock=False):
    rows = db.query('''SELECT "IdAdminUISetting","SettingValueJson","ValideSetting","IsEditable",
        "UpdatedAt","UpdatedByUserFk" FROM systeme."T_Admin_UI_Setting"
        WHERE "SettingScope"=%s AND "ScopeValue" IS NULL AND "SettingKey"=%s
        ORDER BY "IdAdminUISetting" LIMIT 2''' + (" FOR UPDATE" if lock else ""), ["global", SETTING_KEY])
    # L’index historique admet plusieurs ScopeValue NULL : ne jamais choisir un doublon arbitraire.
    if len(rows) > 1:
        raise APIError("Le réglage de messagerie doit être vérifié par l’administrateur.", "MAIL_SETTINGS_DUPLICATE", 503)
    return rows[0] if rows else None


def defaults():
    email=getattr(settings,'EMAIL_HOST_USER','') or DEFAULT_EMAIL
    try:validate_email(email)
    except ValidationError:email=DEFAULT_EMAIL
    return {'senderEmail':email,'senderName':DEFAULT_NAME}


def sender_state(row):
    if row is None or row.get("ValideSetting") is not True:
        return {**defaults(), "source": "default",
                "updatedAt": None, "updatedByUserId": None}
    value = row.get("SettingValueJson")
    if not isinstance(value, dict):
        raise APIError("Le réglage de messagerie est invalide.", "MAIL_SETTINGS_INVALID", 503)
    try:
        sender = validated_sender({key: value.get(key) for key in FIELDS})
    except APIError as error:
        raise APIError("Le réglage de messagerie est invalide.", "MAIL_SETTINGS_INVALID", 503) from error
    return {**sender, "source": "global", "updatedAt": row.get("UpdatedAt"),
            "updatedByUserId": row.get("UpdatedByUserFk")}


def get_sender():
    """Contrat interne SMTP ; aucune configuration ni valeur JSON étrangère n’est exposée."""
    value = sender_state(setting_row())
    return {"email": value["senderEmail"], "name": value["senderName"], "source": value["source"]}


def mail_settings(actor):
    require_platform_admin(actor)
    value = sender_state(setting_row())
    # Import local : le service de réinitialisation consomme lui-même get_sender().
    from .password_reset import smtp_configured
    return {**value, "defaults": defaults(), "canTest": not settings.DB_READ_ONLY, "canManage": not settings.DB_READ_ONLY,
            "canSend": not settings.DB_READ_ONLY and bool(smtp_configured())}


def audit_sender(row):
    if not row:
        return None
    value = row.get("SettingValueJson")
    value = value if isinstance(value, dict) else {}
    return {"IdAdminUISetting": row["IdAdminUISetting"], "SettingKey": SETTING_KEY,
            "SettingScope": "global", "senderEmail": value.get("senderEmail"),
            "senderName": value.get("senderName")}


def save_mail_settings(actor, body):
    require_platform_admin(actor)
    db.ensure_writable()
    sender = validated_sender(body)
    with transaction.atomic():
        db.query("SELECT pg_advisory_xact_lock(hashtextextended(%s,0))", ["mail-settings:global:" + SETTING_KEY])
        old = setting_row(lock=True)
        if old and old.get("IsEditable") is False:
            raise APIError("Ce réglage de messagerie est protégé.", "MAIL_SETTINGS_LOCKED", 409)
        if old:
            # Fusion JSONB côté PostgreSQL : ne sérialiser ni écraser aucune autre clé existante.
            row = db.one('''UPDATE systeme."T_Admin_UI_Setting"
                SET "SettingValueJson"=coalesce("SettingValueJson",'{}'::jsonb) || %s,
                    "SettingType"='json',"ValideSetting"=true,"UpdatedByUserFk"=%s,"UpdatedAt"=CURRENT_TIMESTAMP
                WHERE "IdAdminUISetting"=%s AND "SettingScope"=%s AND "ScopeValue" IS NULL AND "SettingKey"=%s
                RETURNING "IdAdminUISetting","SettingValueJson","ValideSetting","IsEditable","UpdatedAt","UpdatedByUserFk"''',
                [Jsonb(sender), actor.pk, old["IdAdminUISetting"], "global", SETTING_KEY])
        else:
            row = db.one('''INSERT INTO systeme."T_Admin_UI_Setting"
                ("SettingScope","ScopeValue","SettingKey","SettingLabel","SettingGroup","SettingType",
                 "SettingValueJson","IsEditable","IsSystem","ValideSetting","UpdatedByUserFk")
                VALUES (%s,NULL,%s,%s,%s,'json',%s,true,true,true,%s)
                RETURNING "IdAdminUISetting","SettingValueJson","ValideSetting","IsEditable","UpdatedAt","UpdatedByUserFk"''',
                ["global", SETTING_KEY, "Expéditeur de la plateforme", "messagerie", Jsonb(sender), actor.pk])
        if not row:
            raise APIError("Le réglage n’a pas pu être enregistré. Réessayez.", "MAIL_SETTINGS_CONFLICT", 409)
        audit(model("T_Admin_UI_Setting"), "UPDATE" if old else "INSERT",
              old=audit_sender(old), new=audit_sender(row), actor=actor)
        # Valider les seules données publiques avant de terminer la transaction.
        sender_state(row)
    return mail_settings(actor)


class MailSettingsView(APIView):
    # Accès technique explicite, distinct des licences et droits des gestionnaires locaux.
    permission_classes = [IsAuthenticated]
    http_method_names = ["get", "put", "options"]

    def get(self, request):
        return ok(mail_settings(request.user))

    def put(self, request):
        return ok(save_mail_settings(request.user, request.data), message="Expéditeur mis à jour.")


class MailConnectionThrottle(SimpleRateThrottle):
    scope='mail_connection_test'
    rate='3/min'
    def get_cache_key(self,request,view):
        return self.cache_format % {'scope':self.scope,'ident':str(request.user.pk)}


def test_mail_connection(actor):
    """Authentification du transport courant uniquement ; jamais de destinataire ni de message."""
    require_platform_admin(actor)
    db.ensure_writable()
    from .password_reset import smtp_configured
    if not smtp_configured():
        raise APIError('Complétez la configuration du service d’envoi.','SMTP_CONFIGURATION_REQUIRED',503)
    connection=None
    try:
        connection=get_connection(fail_silently=False,timeout=10)
        opened=connection.open()
        if opened is False and getattr(connection,'connection',None) is None:
            raise smtplib.SMTPConnectError(421,'Transport unavailable')
        return {'connected':True,'messageSent':False,'checkedAt':timezone.now()}
    except smtplib.SMTPAuthenticationError as error:
        raise APIError('Le service d’envoi a refusé les identifiants. Vérifiez le compte et son mot de passe d’application.','SMTP_AUTHENTICATION_FAILED',503) from error
    except (smtplib.SMTPException,OSError,ssl.SSLError,ValueError) as error:
        raise APIError('La connexion au service d’envoi n’a pas abouti. Vérifiez les paramètres et l’accès réseau.','SMTP_CONNECTION_FAILED',503) from error
    finally:
        if connection:
            try:connection.close()
            except (smtplib.SMTPException,OSError):pass


class MailConnectionTestView(APIView):
    permission_classes=[IsAuthenticated]
    throttle_classes=[MailConnectionThrottle]
    http_method_names=['post','options']
    def post(self,request):
        require_platform_admin(request.user)
        if not isinstance(request.data,dict) or request.data:
            raise APIError('Aucun paramètre attendu pour le test de connexion.')
        return ok(test_mail_connection(request.user),message='Connexion au service d’envoi réussie. Aucun e-mail envoyé.')
