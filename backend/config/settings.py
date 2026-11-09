"""Django : tables techniques dans public, modèles métier unmanaged."""

import os
from pathlib import Path
from urllib.parse import urlsplit, unquote
from django.core.exceptions import ImproperlyConfigured
from dotenv import load_dotenv

BASE_DIR = Path(__file__).resolve().parent.parent
load_dotenv(BASE_DIR / ".env", override=False)


def flag(name, default=False):
    return os.getenv(name, str(int(default))).lower() in {"1", "true", "yes", "on"}


SECRET_KEY = os.getenv("DJANGO_SECRET_KEY") or os.getenv("JWT_SECRET") or ""
if not SECRET_KEY:
    raise ImproperlyConfigured(
        "Définir DJANGO_SECRET_KEY ou JWT_SECRET dans backend/.env."
    )
DEBUG = flag("DJANGO_DEBUG")
DJANGO_ADMIN_ENABLED = True
ALLOWED_HOSTS = [
    v.strip()
    for v in os.getenv("DJANGO_ALLOWED_HOSTS", "localhost,127.0.0.1,testserver").split(
        ","
    )
    if v.strip()
]
ROOT_URLCONF = "config.urls"
WSGI_APPLICATION = "config.wsgi.application"
ASGI_APPLICATION = "config.asgi.application"
INSTALLED_APPS = [
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    "rest_framework",
    "apps.core",
]
MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",
    "apps.core.middleware.CorsMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
    "django.middleware.common.CommonMiddleware",
]
APPEND_SLASH = False
TIME_ZONE = "Africa/Kinshasa"
USE_TZ = True
LANGUAGE_CODE = "fr-fr"
DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"
DB_READ_ONLY = flag("SAUVERNDEKO_DB_READ_ONLY", True)
u = urlsplit(os.getenv("DATABASE_URL", ""))
if (
    u.scheme not in {"postgres", "postgresql"}
    or not u.hostname
    or not u.path.strip("/")
):
    raise ImproperlyConfigured(
        "DATABASE_URL PostgreSQL est obligatoire ; aucune base de secours ne sera créée."
    )
DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.postgresql",
        "NAME": unquote(u.path[1:]),
        "USER": unquote(u.username or ""),
        "PASSWORD": unquote(u.password or ""),
        "HOST": u.hostname,
        "PORT": u.port or 5432,
        "CONN_MAX_AGE": 0,
        "CONN_HEALTH_CHECKS": True,
        "OPTIONS": {
            "application_name": "SauverNdeko-Django",
            "options": "-c search_path=public -c statement_timeout=15000 -c lock_timeout=3000"
            + (" -c default_transaction_read_only=on" if DB_READ_ONLY else "")
        },
    }
}
# Les modèles métier sont unmanaged ; les migrations natives ciblent public.
MIGRATION_MODULES = {"core": None}
REST_FRAMEWORK = {
    "DEFAULT_AUTHENTICATION_CLASSES": [
        "apps.accounts.authentication.LegacyJWTAuthentication"
    ],
    "DEFAULT_PERMISSION_CLASSES": ["apps.core.permissions.HasModuleAccess"],
    "UNAUTHENTICATED_USER": None,
    "DEFAULT_RENDERER_CLASSES": ["apps.core.responses.ExactJSONRenderer"],
    "DEFAULT_PARSER_CLASSES": ["apps.core.parsers.ExactJSONParser"],
    "EXCEPTION_HANDLER": "apps.core.responses.exception_handler",
    "DEFAULT_THROTTLE_RATES": {"login": "10/min"},
    # Waitress normalise REMOTE_ADDR après validation du frontal de confiance.
    "NUM_PROXIES": 0,
}
CORS_ALLOWED_ORIGINS = [
    v.strip()
    for v in os.getenv(
        "CORS_ALLOWED_ORIGINS", "http://localhost:5174,http://127.0.0.1:5174"
    ).split(",")
    if v.strip()
]
SECURE_CONTENT_TYPE_NOSNIFF = True
SECURE_SSL_REDIRECT = flag("DJANGO_SECURE_SSL_REDIRECT")
LEGACY_PLAINTEXT_PASSWORDS = flag("SAUVERNDEKO_ALLOW_LEGACY_PLAINTEXT_PASSWORDS")
ACCESS_TOKEN_MINUTES = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "30"))
REFRESH_TOKEN_DAYS = int(os.getenv("REFRESH_TOKEN_EXPIRE_DAYS", "7"))
JWT_SECRET = os.getenv("JWT_SECRET", SECRET_KEY)
JWT_REFRESH_SECRET = os.getenv("JWT_REFRESH_SECRET", "")


TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
            ]
        },
    }
]
STATIC_URL = "/static/"
STATIC_ROOT = BASE_DIR / "staticfiles"
SESSION_COOKIE_HTTPONLY = True
SESSION_COOKIE_SAMESITE = "Lax"
CSRF_COOKIE_HTTPONLY = False
CSRF_TRUSTED_ORIGINS = [
    x.strip()
    for x in os.getenv("DJANGO_CSRF_TRUSTED_ORIGINS", "").split(",")
    if x.strip()
]

# Stockage local privé ; aucun répertoire média n’est exposé par un serveur statique.
ARTICLE_MEDIA_ROOT = Path(os.getenv("SAUVERNDEKO_MEDIA_ROOT", str(BASE_DIR / "media")))
# Une photo professionnelle de 8 Mio devient environ 10,7 Mio en JSON/base64.
# Cette marge couvre son formulaire ; chaque service conserve ses propres
# limites, notamment 8 Mio binaires et 24 Mpx pour une image réellement décodée.
DATA_UPLOAD_MAX_MEMORY_SIZE = 12 * 1024 * 1024

# SMTP réel : le secret est un mot de passe d’application Google, jamais celui de SauverNdeko.
EMAIL_BACKEND = "django.core.mail.backends.smtp.EmailBackend"
EMAIL_HOST = os.getenv("SAUVERNDEKO_EMAIL_HOST", "smtp.gmail.com")
EMAIL_PORT = int(os.getenv("SAUVERNDEKO_EMAIL_PORT", "587"))
EMAIL_USE_TLS = flag("SAUVERNDEKO_EMAIL_USE_TLS", True)
EMAIL_USE_SSL = flag("SAUVERNDEKO_EMAIL_USE_SSL")
EMAIL_HOST_USER = os.getenv("SAUVERNDEKO_EMAIL_HOST_USER", "benjaminmupanzi@gmail.com")
EMAIL_HOST_PASSWORD = os.getenv("SAUVERNDEKO_EMAIL_HOST_PASSWORD", "")
EMAIL_TIMEOUT = 10
DEFAULT_FROM_EMAIL = "benjaminmupanzi@gmail.com"
# L’expéditeur applicatif est résolu par accounts.mail_settings (réglage administratif).
# Origine explicite du frontend ; aucun lien n’est construit depuis l’en-tête Host reçu.
PASSWORD_RESET_FRONTEND_URL = os.getenv("SAUVERNDEKO_FRONTEND_URL", "http://localhost:5174")
PASSWORD_RESET_TIMEOUT = 20 * 60
