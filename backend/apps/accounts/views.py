import re
from django.db import transaction
from rest_framework.views import APIView
from rest_framework.permissions import AllowAny
from rest_framework.throttling import AnonRateThrottle
from rest_framework.exceptions import AuthenticationFailed
from apps.core import db
from apps.core.repository import clean
from apps.core.responses import ok, APIError
from .authentication import actor_by_id, decode_token, password_matches, tokens, profile


class LoginThrottle(AnonRateThrottle):
    scope = "login"


class LoginView(APIView):
    authentication_classes = []
    permission_classes = [AllowAny]
    throttle_classes = [LoginThrottle]

    def post(self, request):
        email = request.data.get("EmailUser")
        password = request.data.get("MotdepasseUser")
        if not isinstance(email, str) or not isinstance(password, str):
            raise APIError("EmailUser et MotdepasseUser sont obligatoires.")
        if not email.strip() or len(email.strip()) > 150 or not password or len(password) > 4096:
            raise AuthenticationFailed("Identifiants incorrects.")
        row = db.one(
            'SELECT "IdUser","MotdepasseUser" FROM systeme."T_Utilisateurs" WHERE lower("EmailUser")=lower(%s)',
            [email.strip()],
        )
        if not row or not password_matches(password, row["MotdepasseUser"]):
            raise AuthenticationFailed("Identifiants incorrects.")
        return ok(**tokens(actor_by_id(row["IdUser"])))


class RefreshView(APIView):
    authentication_classes = []
    permission_classes = [AllowAny]
    throttle_classes = [LoginThrottle]

    def post(self, request):
        value = request.data.get("refreshToken")
        if not isinstance(value, str):
            raise AuthenticationFailed("Refresh token requis.")
        return ok(**tokens(actor_by_id(decode_token(value, "refresh"))))


class RegisterView(APIView):
    authentication_classes = []
    permission_classes = [AllowAny]

    def post(self, request):
        raise APIError(
            "La création des comptes est réservée à l’administration.",
            "REGISTRATION_DISABLED",
            403,
        )


class MeView(APIView):
    def get(self, request):
        return ok(profile(request.user))

    def put(self, request):
        db.ensure_writable()
        body = request.data
        allowed = {
            "NomUser",
            "PrenomUser",
            "EmailUser",
            "PhoneUser",
            "SexeUser",
            "UrlPhoto",
        }
        if not body or set(body) - allowed:
            raise APIError("Champ de profil non autorisé.")
        from apps.core.registry import model
        from apps.core.repository import coerce

        cols = {c["column_name"]: c for c in model("T_Utilisateurs")["columns"]}
        values = {k: coerce(cols[k], v) for k, v in body.items()}
        if "EmailUser" in values and not re.fullmatch(
            r"[^\s@]+@[^\s@]+\.[^\s@]+", values["EmailUser"]
        ):
            raise APIError("Email invalide.")
        if any(
            k in values and not values[k].strip() for k in ["NomUser", "PrenomUser"]
        ):
            raise APIError("Nom et prénom obligatoires.")
        if "SexeUser" in values and values["SexeUser"] not in {"M", "F"}:
            raise APIError("Sexe invalide.")
        with transaction.atomic():
            db.query(
                'UPDATE systeme."T_Utilisateurs" SET '
                + ",".join(db.ident(k) + "=%s" for k in values)
                + ',"DateModificationUser"=CURRENT_TIMESTAMP WHERE "IdUser"=%s',
                [*values.values(), request.user.pk],
            )
        return ok(profile(actor_by_id(request.user.pk)))


class VerifyView(APIView):
    def get(self, request):
        return ok(
            {"userId": request.user.pk, "valid": True}, user=profile(request.user)
        )


class LogoutView(APIView):
    def post(self, request):
        # Comme les JWT historiques, les jetons expirent ; aucun stockage de révocation ajouté.
        return ok(message="Session fermée côté client.")
