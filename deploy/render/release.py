"""Gardes de la livraison GitHub et demande Render du commit exact, sans secret en sortie."""
import json
import os
import re
import subprocess
import sys
from pathlib import Path
from urllib.parse import parse_qsl, unquote, urlencode, urlsplit, urlunsplit
from urllib.request import Request, urlopen


def validate_release(environment=None):
    values = os.environ if environment is None else environment
    if values.get("GITHUB_REF") != "refs/heads/main":
        raise ValueError("La livraison doit être lancée depuis main.")
    if not re.fullmatch(r"[0-9a-f]{40}", values.get("GITHUB_SHA", "")):
        raise ValueError("Le commit de livraison est invalide.")
    if values.get("CONFIRM_MAINTENANCE") != "true":
        raise ValueError("Confirmer la sauvegarde et la fenêtre de maintenance.")
    reference = values.get("BACKUP_REFERENCE", "").strip()
    if not 8 <= len(reference) <= 500 or any(ord(c) < 32 for c in reference):
        raise ValueError("Renseigner la référence de la sauvegarde vérifiée hors CI.")
    for name in ("MAINTENANCE_DATABASE_URL", "RENDER_DEPLOY_HOOK_URL"):
        if not values.get(name):
            raise ValueError("Configurer les secrets de livraison dans GitHub.")
    database = urlsplit(values["MAINTENANCE_DATABASE_URL"])
    if database.scheme not in {"postgres", "postgresql"} or not database.hostname or not database.username or not database.password or not database.path.strip("/"):
        raise ValueError("La connexion de maintenance est incomplète.")
    deploy_url(values["RENDER_DEPLOY_HOOK_URL"], values["GITHUB_SHA"])
    return values["GITHUB_SHA"]


def deploy_url(secret_url, commit):
    parsed = urlsplit(secret_url)
    if (parsed.scheme != "https" or parsed.hostname != "api.render.com"
            or parsed.username or parsed.password or parsed.fragment
            or parsed.port not in {None, 443} or not parsed.path.startswith("/deploy/")):
        raise ValueError("Le hook de déploiement Render est invalide.")
    query = dict(parse_qsl(parsed.query, keep_blank_values=True))
    if not query.get("key") or not re.fullmatch(r"[0-9a-f]{40}", commit):
        raise ValueError("Le hook ou le commit de déploiement est incomplet.")
    query["ref"] = commit
    return urlunsplit((parsed.scheme, parsed.netloc, parsed.path, urlencode(query), ""))


def refresh_runtime_grants():
    """Rejouer le script contrôlé avec le rôle d'administration déjà préparé."""
    validate_release()
    apply_runtime_grants(os.environ)


def apply_runtime_grants(values):
    """Étape SQL commune ; l'orchestrateur valide d'abord sa livraison."""
    parsed = urlsplit(values["MAINTENANCE_DATABASE_URL"])
    environment = {key: value for key, value in os.environ.items() if not key.startswith("PG")}
    environment.update(
        PGHOST=parsed.hostname, PGPORT=str(parsed.port or 5432),
        PGUSER=unquote(parsed.username), PGPASSWORD=unquote(parsed.password),
        PGDATABASE=unquote(parsed.path[1:]), PGCONNECT_TIMEOUT="10",
        PGCLIENTENCODING="UTF8",
        PGSSLMODE=values.get("SAUVERNDEKO_DB_SSLMODE", "verify-full"),
        PGOPTIONS="-c lock_timeout=5000 -c statement_timeout=120000",
    )
    if values.get("SAUVERNDEKO_DB_SSLROOTCERT"):
        environment["PGSSLROOTCERT"] = values["SAUVERNDEKO_DB_SSLROOTCERT"]
    result = subprocess.run(
        ["psql", "-X", "--set=ON_ERROR_STOP=1", "--file",
         str(Path(__file__).resolve().parents[2] / "deploy/production/role-runtime.sql")],
        env=environment, capture_output=True, timeout=180, check=False,
    )
    if result.returncode:
        raise RuntimeError("Droits runtime non actualisés ; vérifier le rôle de maintenance.")


def main():
    try:
        if sys.argv[1:] == ["validate"]:
            commit = validate_release()
            print("Livraison autorisée pour le commit " + commit + ". Sauvegarde attestée par l'opérateur.")
        elif sys.argv[1:] == ["grants"]:
            refresh_runtime_grants()
            print("Droits du compte runtime actualisés par le script contrôlé.")
        elif sys.argv[1:] == ["deploy"]:
            commit = os.environ.get("GITHUB_SHA", "")
            target = deploy_url(os.environ.get("RENDER_DEPLOY_HOOK_URL", ""), commit)
            request = Request(target, data=b"", method="POST")
            with urlopen(request, timeout=30) as response:
                if response.status not in {200, 202}:
                    raise RuntimeError("Demande refusée.")
                # Lire une réponse bornée sans imprimer les liens/valeurs retournés.
                json.loads(response.read(65536))
            print("Déploiement demandé à Render pour " + commit + ". Vérifier son état final dans Render.")
        else:
            raise ValueError("Utiliser validate, grants ou deploy.")
        return 0
    except Exception:
        print("Livraison interrompue : vérifier les confirmations, secrets et état Render. Aucun secret n'est affiché.", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
