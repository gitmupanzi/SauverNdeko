"""JWT compatible React/Express ; droits relus en base à chaque requête."""

import os, hmac, hashlib, re
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
import bcrypt, jwt
from django.conf import settings
from django.contrib.auth.hashers import check_password, make_password
from rest_framework.authentication import BaseAuthentication, get_authorization_header
from rest_framework.exceptions import AuthenticationFailed
from apps.core import db
from apps.core.responses import APIError


@dataclass
class Actor:
    row: dict

    @property
    def is_authenticated(self):
        return True

    @property
    def pk(self):
        return self.row["IdUser"]

    @property
    def organisation(self):
        return getattr(self, "_context_entity", self.row.get("IdEntiteFk"))

    @property
    def global_admin(self):
        return self.row.get("Is_Admin") is True

    @property
    def admin(self):
        return (
            self.global_admin
            or self.row.get("Is_staff") is True
            or str(self.row.get("RoleName", "")).lower() in {"admin", "administrateur"}
        )


def actor_by_id(user_id):
    row = db.one(
        'SELECT u.*,g."NomGenerique" AS "RoleName",g."AbrGenerique" AS "RoleAbr",e."ValideEntite" AS "EntityActive" FROM systeme."T_Utilisateurs" u LEFT JOIN referentiel."T_Generique" g ON g."ID_Generique"=u."IdRoleFk" LEFT JOIN systeme."T_Entite" e ON e."IdEntite"=u."IdEntiteFk" WHERE u."IdUser"=%s',
        (user_id,),
    )
    if not row or not row.get("ValideUser") or (row.get("EntityActive") is False and row.get("Is_Admin") is not True):
        raise AuthenticationFailed("Session inactive ou utilisateur introuvable.")
    return Actor(row)


def decode_claims(value, kind="access"):
    if kind not in {"access","refresh"}:
        raise AuthenticationFailed("Type de session invalide.")
    secret = settings.JWT_SECRET if kind == "access" else settings.JWT_REFRESH_SECRET
    if not secret:
        raise AuthenticationFailed("Configuration de session incomplète.")
    try:
        claims = jwt.decode(
            value, secret, algorithms=["HS256"], options={"require": ["exp", "userId"]}
        )
        if type(claims["userId"]) is not int or claims["userId"] <= 0:
            raise ValueError()
        # Les anciens JWT n’avaient pas de token_type. Les nouveaux le portent.
        if claims.get("token_type", kind) != kind:
            raise ValueError()
        return claims
    except (jwt.PyJWTError, ValueError, TypeError):
        raise AuthenticationFailed("Token invalide ou expiré.")


def password_version(actor):
    stored=actor.row.get("MotdepasseUser")
    if not isinstance(stored,str) or not stored:
        raise AuthenticationFailed("Compte indisponible.")
    secret=settings.JWT_SECRET
    if not secret:
        raise APIError("Configuration de session incomplète.","AUTH_CONFIGURATION",503)
    message=f"SauverNdeko:password-version:v1:{actor.pk}:{stored}".encode("utf8")
    return hmac.new(secret.encode("utf8"),message,hashlib.sha256).hexdigest()


def token_actor(value,kind="access"):
    claims=decode_claims(value,kind)
    actor=actor_by_id(claims["userId"])
    if "pwdv" in claims:
        version=claims["pwdv"]
        if not isinstance(version,str) or not re.fullmatch(r"[a-f0-9]{64}",version) or not hmac.compare_digest(version,password_version(actor)):
            raise AuthenticationFailed("Votre session a expiré. Reconnectez-vous.")
    else:
        # Compatibilité au déploiement ; un changement révoque ensuite tous les anciens JWT du compte.
        changed=db.one('''SELECT EXISTS(SELECT 1 FROM systeme."T_Audit_Log"
            WHERE "TableName"=%s AND "Operation"=%s AND "NewData"->>'IdUser'=%s) AS changed''',
            ["systeme.T_Utilisateurs","PASSWORD_CHANGE",str(actor.pk)])
        if not changed or "changed" not in changed:
            raise APIError("La vérification de session est indisponible.","SESSION_UNAVAILABLE",503)
        if changed["changed"]:
            raise AuthenticationFailed("Votre session a expiré. Reconnectez-vous.")
    return actor


def decode_token(value,kind="access"):
    # Conserve le retour historique tout en imposant la révocation sur ce chemin aussi.
    return token_actor(value,kind).pk


def tokens(actor):
    if not settings.JWT_REFRESH_SECRET:
        raise APIError("JWT_REFRESH_SECRET est obligatoire.", "AUTH_CONFIGURATION", 503)
    now = datetime.now(timezone.utc)
    version = password_version(actor)

    def issue(kind, secret, delta):
        return jwt.encode(
            {"userId": actor.pk, "token_type": kind, "iat": now, "exp": now + delta, "pwdv": version},
            secret,
            algorithm="HS256",
        )

    return {
        "accessToken": issue(
            "access",
            settings.JWT_SECRET,
            timedelta(minutes=settings.ACCESS_TOKEN_MINUTES),
        ),
        "refreshToken": issue(
            "refresh",
            settings.JWT_REFRESH_SECRET,
            timedelta(days=settings.REFRESH_TOKEN_DAYS),
        ),
        "user": profile(actor),
    }


def password_matches(plain, stored):
    if (
        not isinstance(plain, str)
        or not isinstance(stored, str)
        or not plain
        or len(plain) > 4096
    ):
        return False
    try:
        plain.encode("utf8")
    except UnicodeError:
        return False
    if stored.startswith(("$2a$", "$2b$", "$2y$")):
        if len(plain.encode("utf8")) > 72:
            return False
        try:
            return bcrypt.checkpw(plain.encode("utf8"), stored.encode("ascii"))
        except (ValueError, UnicodeError):
            return False
    if stored.startswith(
        ("pbkdf2_sha256$", "pbkdf2_sha1$", "argon2$", "bcrypt_sha256$", "scrypt$")
    ):
        try:
            return check_password(plain, stored)
        except (ValueError, ImportError):
            return False
    return settings.LEGACY_PLAINTEXT_PASSWORDS and hmac.compare_digest(
        plain.encode(), stored.encode()
    )


def profile(actor):
    row = actor.row
    result = {
        k: row.get(k)
        for k in [
            "IdUser",
            "NomUser",
            "PrenomUser",
            "EmailUser",
            "PhoneUser",
            "SexeUser",
            "ValideUser",
            "IdRoleFk",
            "IdEntiteFk",
            "DatecreationUser",
            "DateModificationUser",
            "UrlPhoto",
            "Is_staff",
            "Is_Admin",
        ]
    }
    from apps.core.module_access import access_snapshot
    result["moduleAccess"] = access_snapshot(actor)
    result["canAccessAdmin"] = actor.admin
    result["permissions"] = {"canAccessAdmin": actor.admin, "canWriteData": not settings.DB_READ_ONLY}
    result["role"] = (
        {
            "id": row.get("IdRoleFk"),
            "name": row.get("RoleName"),
            "abbreviation": row.get("RoleAbr"),
        }
        if row.get("IdRoleFk")
        else None
    )
    result["entite"] = (
        db.one(
            'SELECT "IdEntite","NomEntite","EmailEntite","PhoneEntite","AdresseEntite" FROM systeme."T_Entite" WHERE "IdEntite"=%s',
            (actor.organisation,),
        )
        if actor.organisation
        else None
    )
    if result["entite"]:
        loc = db.one(
            """SELECT l."IdEntiteLocalisation",l."IdNiveau_3_Fk",l."IdNiveau_4_Fk",l."IdNiveau_5_Fk",n0."ID_Niveau_0" AS country_id,n0."NomNiveau_0" AS country_name,n0."CodeNiveau_0" AS country_code FROM systeme."T_Entite_Localisation" l LEFT JOIN geolocalisation."T_Niveau_3" n3 ON n3."ID_Niveau_3"=l."IdNiveau_3_Fk" LEFT JOIN geolocalisation."T_Niveau_2" n2 ON n2."ID_Niveau_2"=n3."ID_Niveau_2_FK" LEFT JOIN geolocalisation."T_Niveau_1" n1 ON n1."ID_Niveau_1"=n2."ID_Niveau_1_FK" LEFT JOIN geolocalisation."T_Niveau_0" n0 ON n0."ID_Niveau_0"=n1."ID_Niveau_0_Fk" WHERE l."IdEntiteFk"=%s ORDER BY l."IdEntiteLocalisation" LIMIT 1""",
            [actor.organisation],
        )
        if loc:
            loc["country"] = {
                "id": loc.pop("country_id"),
                "name": loc.pop("country_name"),
                "code": loc.pop("country_code"),
            }
        result["entite"]["localisation"] = loc
    entity = result.get("entite")
    location = entity.get("localisation") if entity else None
    result["scopeContext"] = {
        "entity": (
            {"id": entity["IdEntite"], "name": entity["NomEntite"]} if entity else None
        ),
        "country": location.get("country") if location else None,
    }
    return result


class LegacyJWTAuthentication(BaseAuthentication):
    def authenticate(self, request):
        parts = get_authorization_header(request).split()
        if not parts:
            return None
        if len(parts) != 2 or parts[0].lower() != b"bearer":
            raise AuthenticationFailed("En-tête Bearer invalide.")
        try:
            token = parts[1].decode("ascii")
        except UnicodeError:
            raise AuthenticationFailed("Token invalide.")
        from apps.core.tenancy import bind_context
        return bind_context(token_actor(token), request), token

    def authenticate_header(self, request):
        return "Bearer"
