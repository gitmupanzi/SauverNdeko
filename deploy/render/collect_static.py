"""Collecter uniquement les fichiers statiques embarqués, sans connexion DB."""
import os
import sys
from pathlib import Path


def main(output_dir=None):
    # Valeurs factices réservées à ce processus de construction, jamais au serveur.
    os.environ["DJANGO_SETTINGS_MODULE"] = "config.settings"
    os.environ["DJANGO_SECRET_KEY"] = "build-only-static-collection-no-runtime-secret"
    os.environ["DATABASE_URL"] = "postgresql://build:unused@127.0.0.1:1/build"
    os.environ["SAUVERNDEKO_DB_READ_ONLY"] = "1"
    sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "backend"))
    import django
    django.setup()
    if output_dir is not None:
        from django.conf import settings
        settings.STATIC_ROOT = Path(output_dir)
    from django.core.management import call_command
    call_command("collectstatic", interactive=False, verbosity=0)


if __name__ == "__main__":
    main()
