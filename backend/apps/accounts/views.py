import hashlib
import hmac
import logging

from django.conf import settings
from django.contrib.auth.hashers import make_password
from django.db import DatabaseError, transaction
from rest_framework.views import APIView
from rest_framework.permissions import AllowAny
from django.utils.decorators import method_decorator
from django.views.decorators.debug import sensitive_post_parameters, sensitive_variables
from rest_framework.throttling import AnonRateThrottle, SimpleRateThrottle
from rest_framework.exceptions import AuthenticationFailed
from apps.core import db
from apps.core.responses import ok, APIError
from .authentication import actor_by_id, password_matches, profile, refresh_tokens, revoke_session, tokens
from .passwords import ProfileWriteThrottle


logger = logging.getLogger(__name__)


def record_session_event(user_id, event):
    if settings.DB_READ_ONLY:
        return

    try:
        with transaction.atomic():
            row = db.one(
                """INSERT INTO systeme."T_Login" ("IdUserFk", "IdTypeLoginFk", "IdEntiteFk")
                   SELECT u."IdUser", t.id, u."IdEntiteFk"
                   FROM systeme."T_Utilisateurs" u
                   CROSS JOIN (
                       SELECT min(g."ID_Generique") AS id
                       FROM referentiel."T_Generique" g
                       JOIN referentiel."T_CategorieGenerique" c
                         ON c."ID_CategorieGenerique" = g."ID_CategorieGeneriqueFk"
                       WHERE g."ID_CategorieGeneriqueFk" = ANY(
                           referentiel.fn_categories_champ('systeme', 'T_Login', 'IdTypeLoginFk', NULL))
                         AND g."IdEntiteFk" IS NULL AND c."IdEntiteFk" IS NULL
                         AND g."ValideGenerique" IS TRUE AND c."ValideCategorieGenerique" IS TRUE
                         AND lower(btrim(g."NomGenerique")) = %s
                       HAVING count(*) = 1
                   ) t
                   WHERE u."IdUser" = %s AND u."ValideUser" IS TRUE
                   RETURNING "IdLogin" """,
                [event.lower(), user_id],
            )
    except DatabaseError as exc:
        logger.error(
            "Écriture du journal de session impossible pour %s (SQLSTATE %s).",
            event, getattr(exc.__cause__, "sqlstate", None),
        )
        return

    if row is None:
        logger.error("Compte inactif ou type d’événement de session absent ou ambigu pour %s.", event)


class LoginThrottle(AnonRateThrottle):
    scope = "login"


class LoginAccountThrottle(SimpleRateThrottle):
    scope = "login_account"
    rate = "15/min"

    def get_cache_key(self, request, view):
        if request.method != "POST" or not isinstance(request.data, dict):
            return None
        email = request.data.get("EmailUser")
        if not isinstance(email, str) or not email.strip() or len(email.strip()) > 150:
            return None
        try:
            digest = hashlib.sha256(email.strip().casefold().encode("utf8")).hexdigest()
        except UnicodeError:
            return None
        return self.cache_format % {"scope": self.scope, "ident": digest}


@method_decorator(sensitive_post_parameters("MotdepasseUser"), name="dispatch")
class LoginView(APIView):
    authentication_classes = []
    permission_classes = [AllowAny]
    throttle_classes = [LoginThrottle, LoginAccountThrottle]

    @sensitive_variables()
    def post(self, request):
        if not isinstance(request.data, dict):
            raise APIError("Renseignez votre adresse e-mail et votre mot de passe.")
        email = request.data.get("EmailUser")
        password = request.data.get("MotdepasseUser")
        if not isinstance(email, str) or not isinstance(password, str):
            raise APIError("Renseignez votre adresse e-mail et votre mot de passe.")
        email = email.strip()
        if not email or len(email) > 150 or "\x00" in email or not password or len(password) > 4096:
            raise AuthenticationFailed("Identifiants incorrects.")
        try:
            email.encode("utf8")
            password.encode("utf8")
        except UnicodeError:
            raise AuthenticationFailed("Identifiants incorrects.") from None
        rows = db.query(
            'SELECT "IdUser","MotdepasseUser" FROM systeme."T_Utilisateurs" '
            'WHERE lower("EmailUser")=lower(%s) LIMIT 2',
            [email],
        )
        if len(rows) != 1:
            # Exécute aussi un hachage pour une adresse absente ou ambiguë.
            make_password(password)
            raise AuthenticationFailed("Identifiants incorrects.")
        row = rows[0]
        if not password_matches(password, row["MotdepasseUser"]):
            raise AuthenticationFailed("Identifiants incorrects.")
        try:
            actor = actor_by_id(row["IdUser"])
        except AuthenticationFailed:
            raise AuthenticationFailed("Identifiants incorrects.") from None
        # Un changement concurrent ne peut transformer un ancien secret en session à jour.
        if not hmac.compare_digest((actor.row.get("MotdepasseUser") or "").encode("utf8"),row["MotdepasseUser"].encode("utf8")):
            raise AuthenticationFailed("Identifiants incorrects.")
        payload = tokens(actor)
        record_session_event(actor.pk, "Connexion")
        return ok(**payload)


@method_decorator(sensitive_post_parameters("refreshToken"), name="dispatch")
class RefreshView(APIView):
    authentication_classes = []
    permission_classes = [AllowAny]
    throttle_classes = [LoginThrottle]

    @sensitive_variables()
    def post(self, request):
        value = request.data.get("refreshToken") if isinstance(request.data, dict) else None
        if not isinstance(value, str):
            raise AuthenticationFailed("Refresh token requis.")
        return ok(**refresh_tokens(value))


class RegisterView(APIView):
    authentication_classes = []
    permission_classes = [AllowAny]

    def post(self, request):
        raise APIError(
            "La création des comptes est réservée à l’administration.",
            "REGISTRATION_DISABLED",
            403,
        )


@method_decorator(sensitive_post_parameters("currentPassword"), name="dispatch")
class MeView(APIView):
    throttle_classes = [ProfileWriteThrottle]

    def get(self, request):
        return ok(profile(request.user))

    @sensitive_variables()
    def put(self, request):
        from .photos import save_profile
        return ok(save_profile(request.user, request.data), message="Profil mis à jour.")

class VerifyView(APIView):
    def get(self, request):
        return ok(
            {"userId": request.user.pk, "valid": True}, user=profile(request.user)
        )


class LogoutView(APIView):
    def post(self, request):
        revoked = revoke_session(request.auth)
        if revoked:
            record_session_event(request.user.pk, "Déconnexion")
        return ok(
            {"revoked": revoked},
            message="Session fermée." if revoked or not settings.DB_READ_ONLY else "Session fermée sur cet appareil.",
        )
