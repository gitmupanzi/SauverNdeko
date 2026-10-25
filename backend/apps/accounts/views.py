import hmac
from rest_framework.views import APIView
from rest_framework.permissions import AllowAny
from rest_framework.throttling import AnonRateThrottle
from rest_framework.exceptions import AuthenticationFailed
from apps.core import db
from apps.core.responses import ok, APIError
from .authentication import actor_by_id, token_actor, password_matches, tokens, profile


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
        actor=actor_by_id(row["IdUser"])
        # Un changement concurrent ne peut transformer un ancien secret en session à jour.
        if not hmac.compare_digest((actor.row.get("MotdepasseUser") or "").encode("utf8"),row["MotdepasseUser"].encode("utf8")):
            raise AuthenticationFailed("Identifiants incorrects.")
        return ok(**tokens(actor))


class RefreshView(APIView):
    authentication_classes = []
    permission_classes = [AllowAny]
    throttle_classes = [LoginThrottle]

    def post(self, request):
        value = request.data.get("refreshToken")
        if not isinstance(value, str):
            raise AuthenticationFailed("Refresh token requis.")
        return ok(**tokens(token_actor(value, "refresh")))


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
        from .photos import save_profile
        return ok(save_profile(request.user, request.data), message="Profil mis à jour.")

class VerifyView(APIView):
    def get(self, request):
        return ok(
            {"userId": request.user.pk, "valid": True}, user=profile(request.user)
        )


class LogoutView(APIView):
    def post(self, request):
        # Comme les JWT historiques, les jetons expirent ; aucun stockage de révocation ajouté.
        return ok(message="Session fermée côté client.")
