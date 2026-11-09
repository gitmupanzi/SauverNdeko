"""Adapter le même service HTTPS à Render sans modifier les réglages locaux."""
import os
from urllib.parse import urlsplit


def configure(environment=None):
    values = os.environ if environment is None else environment
    if any(values.get(name) for name in (
        "MAINTENANCE_DATABASE_URL", "SAUVERNDEKO_MIGRATION_DATABASE_URL",
        "SAUVERNDEKO_MAINTENANCE_DATABASE_URL",
    )):
        raise RuntimeError("Le service web ne doit pas recevoir de connexion PostgreSQL de maintenance.")
    hostname = values.get("RENDER_EXTERNAL_HOSTNAME", "").strip()
    if hostname and (
        any(char not in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-" for char in hostname)
        or hostname.startswith(".") or hostname.endswith(".") or ".." in hostname
    ):
        raise RuntimeError("Le nom d'hôte Render est invalide.")
    if not values.get("DJANGO_ALLOWED_HOSTS") and hostname:
        values["DJANGO_ALLOWED_HOSTS"] = hostname
    if not values.get("SAUVERNDEKO_FRONTEND_URL") and hostname:
        values["SAUVERNDEKO_FRONTEND_URL"] = "https://" + hostname
    frontend_url = values.get("SAUVERNDEKO_FRONTEND_URL", "")
    try:
        origin = urlsplit(frontend_url)
        origin_port = origin.port
    except ValueError:
        raise RuntimeError("Configurer l'hôte exact et l'origine HTTPS de SauverNdeko.") from None
    hosts = [item.strip() for item in values.get("DJANGO_ALLOWED_HOSTS", "").split(",")]
    if (origin.scheme != "https" or not origin.hostname or origin.hostname not in hosts
            or origin.username is not None or origin.password is not None
            or "?" in frontend_url or "#" in frontend_url or origin.path not in {"", "/"}
            or origin_port == 0 or any(host.startswith(".") or "*" in host for host in hosts)):
        raise RuntimeError("Configurer l'hôte exact et l'origine HTTPS de SauverNdeko.")
    values["DJANGO_SETTINGS_MODULE"] = "config.production"
    values["SAUVERNDEKO_TRUSTED_PROXY"] = "127.0.0.1"
    values["SAUVERNDEKO_WSGI_LISTEN"] = "127.0.0.1:5000"
    values.setdefault("SAUVERNDEKO_MEDIA_ROOT", "/var/data/media")
    try:
        port = int(values.get("PORT", "10000"))
    except (TypeError, ValueError):
        raise RuntimeError("Le port Render est invalide.") from None
    if not 1024 <= port <= 65535 or port == 5000:
        raise RuntimeError("Le port Render doit être distinct du port privé Django.")
    values["PORT"] = str(port)
    return values
