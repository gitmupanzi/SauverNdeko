"""Connexion de maintenance CLI, distincte du service HTTP de production."""
import os
import secrets
from django.core.exceptions import ImproperlyConfigured

# Une commande de livraison ne doit pas choisir implicitement le DSN du .env local.
if not os.environ.get("DATABASE_URL", "").strip():
    raise ImproperlyConfigured("DATABASE_URL explicite requis dans le processus de maintenance.")

# Clé éphémère pour initialiser Django en CLI ; jamais une clé d'authentification web.
os.environ.setdefault("DJANGO_SECRET_KEY", secrets.token_urlsafe(64))
from .settings import *

DEBUG = False
LEGACY_PLAINTEXT_PASSWORDS = False
mode = os.environ.get("SAUVERNDEKO_DB_SSLMODE", "verify-full")
if mode not in {"verify-full", "verify-ca", "require", "disable"}:
    raise ImproperlyConfigured("Mode TLS PostgreSQL de maintenance non autorisé.")
if mode == "disable" and DATABASES["default"]["HOST"] not in {"localhost", "127.0.0.1", "::1"}:
    raise ImproperlyConfigured("TLS PostgreSQL requis pour la maintenance distante.")
DATABASES["default"]["OPTIONS"]["sslmode"] = mode
if os.environ.get("SAUVERNDEKO_DB_SSLROOTCERT"):
    DATABASES["default"]["OPTIONS"]["sslrootcert"] = os.environ["SAUVERNDEKO_DB_SSLROOTCERT"]
