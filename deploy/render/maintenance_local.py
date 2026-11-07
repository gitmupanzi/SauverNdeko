"""Maintenance explicite depuis un poste équipé ; plan en lecture seule par défaut.

N'utilise jamais backend/.env comme destination implicite. Ne déclenche aucun
déploiement. L'application doit être placée dans sa fenêtre de maintenance par
l'opérateur. Une attestation ne réalise pas une sauvegarde ni sa restauration.
"""
import argparse
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
from urllib.parse import unquote, urlsplit

from release import apply_runtime_grants

ROOT = Path(__file__).resolve().parents[2]
KEYS = {"MAINTENANCE_DATABASE_URL", "SAUVERNDEKO_DB_SSLMODE", "SAUVERNDEKO_DB_SSLROOTCERT"}


def git(*arguments):
    result = subprocess.run(["git", *arguments], cwd=ROOT, capture_output=True, text=True,
                            encoding="utf-8", errors="replace", check=False)
    if result.returncode:
        raise ValueError("Lecture Git impossible dans ce dépôt.")
    return result.stdout.strip()


def verify_source(commit, *, clean):
    if not re.fullmatch(r"[0-9a-f]{40}", commit or "") or git("rev-parse", "HEAD") != commit:
        raise ValueError("Le SHA demandé doit être le commit courant complet.")
    if clean:
        if git("branch", "--show-current") != "main":
            raise ValueError("La maintenance exige une copie de main.")
        if git("status", "--porcelain", "--untracked-files=normal"):
            raise ValueError("Le dépôt contient des modifications non validées.")
        if git("rev-parse", "refs/remotes/origin/main") != commit:
            raise ValueError("Actualiser origin/main et utiliser exactement son commit.")


def read_values(env_file):
    if not env_file:
        return {key: os.environ[key] for key in KEYS if key in os.environ}
    path = Path(env_file).resolve(strict=True)
    # Ne pas accepter un fichier de secrets déjà suivi par Git.
    try:
        relative = path.relative_to(ROOT).as_posix()
    except ValueError:
        relative = None
    if relative:
        if not path.is_relative_to(ROOT / ".runtime"):
            raise ValueError("Un fichier privé interne doit résider dans .runtime, exclu du contexte Docker.")
        if git("ls-files", "--", relative):
            raise ValueError("Le fichier privé ne doit pas être suivi par Git.")
        result = subprocess.run(["git", "check-ignore", "--quiet", "--", relative], cwd=ROOT, check=False)
        if result.returncode:
            raise ValueError("Le fichier privé doit être ignoré par Git.")
    from dotenv import dotenv_values
    values = dict(dotenv_values(path, interpolate=False))
    if set(values) - KEYS:
        raise ValueError("Le fichier doit contenir uniquement les trois variables de maintenance documentées.")
    return {key: value for key, value in values.items() if value is not None}


def database_environment(values, *, host, name, write, port=5432):
    dsn = values.get("MAINTENANCE_DATABASE_URL", "")
    parsed = urlsplit(dsn)
    if (parsed.scheme not in {"postgres", "postgresql"} or not parsed.hostname
            or not parsed.username or not parsed.password or not parsed.path.strip("/")):
        raise ValueError("MAINTENANCE_DATABASE_URL explicite et complète requise.")
    if (parsed.hostname != host or unquote(parsed.path[1:]) != name or parsed.fragment
            or (parsed.port or 5432) != port):
        raise ValueError("La destination PostgreSQL ne correspond pas à l'hôte, au port et à la base demandés.")
    if unquote(parsed.username) == "sauverndeko_runtime":
        raise ValueError("Utiliser le propriétaire de maintenance, jamais le compte du service web.")
    mode = values.get("SAUVERNDEKO_DB_SSLMODE", "verify-full")
    local = host in {"localhost", "127.0.0.1", "::1"}
    if mode != "verify-full" and not (local and mode == "disable"):
        raise ValueError("La maintenance externe exige TLS verify-full.")
    certificate = values.get("SAUVERNDEKO_DB_SSLROOTCERT", "")
    if not local and (not certificate or not Path(certificate).is_file()):
        raise ValueError("Renseigner le fichier CA de confiance pour la maintenance externe.")
    environment = build_environment()
    environment.update(values)
    environment.update(DATABASE_URL=dsn, DJANGO_SETTINGS_MODULE="config.maintenance",
                       SAUVERNDEKO_DB_READ_ONLY="0" if write else "1",
                       SAUVERNDEKO_DB_SSLMODE=mode, PYTHONUTF8="1")
    return environment


def build_environment():
    # Les outils de build ne reçoivent aucune connexion ni clé de maintenance.
    return {key: value for key, value in os.environ.items()
            if key not in {"DATABASE_URL", "RENDER_DEPLOY_HOOK_URL", "DJANGO_SETTINGS_MODULE"}
            and not key.startswith(("MAINTENANCE_", "SAUVERNDEKO_", "PG", "DJANGO_", "JWT_"))
            and not any(word in key.upper() for word in ("SECRET", "PASSWORD", "TOKEN", "DATABASE_URL", "DEPLOY_HOOK"))}


def run_step(label, arguments, environment, *, cwd=ROOT, private=False):
    print(label, flush=True)
    result = subprocess.run(arguments, cwd=cwd, env=environment, check=False,
                            capture_output=private, text=True, encoding="utf-8", errors="replace")
    if private:
        output = (result.stdout or "") + (result.stderr or "")
        dsn = environment.get("MAINTENANCE_DATABASE_URL", "")
        password = urlsplit(dsn).password if dsn else None
        for secret in (dsn, password, unquote(password) if password else None):
            if secret:
                output = output.replace(secret, "[masqué]")
        if output.strip():
            print(output.strip(), flush=True)
    if result.returncode:
        raise RuntimeError(label + " — échec, étapes suivantes interrompues.")


def execute(args):
    write = args.action == "apply"
    verify_source(args.commit, clean=write)
    if write:
        reference = (args.backup_reference or "").strip()
        if (not args.confirm_maintenance or not 8 <= len(reference) <= 500
                or any(ord(char) < 32 for char in reference)):
            raise ValueError("Attester la sauvegarde DB/médias restaurée et la fenêtre de maintenance.")
    values = read_values(args.env_file)
    destination = dict(host=args.database_host, name=args.database_name, port=args.database_port)
    environment = database_environment(values, **destination, write=False)
    print("Commit " + args.commit + " — " + args.database_host + ":" + str(args.database_port) + "/" + args.database_name, flush=True)
    if write:
        npm = shutil.which("npm.cmd" if os.name == "nt" else "npm")
        docker = shutil.which("docker")
        if not npm or not docker or not shutil.which("psql"):
            raise ValueError("Installer Node/npm, Docker et psql avant toute application.")
        build = build_environment()
        run_step("Tests de livraison", [sys.executable, "-m", "unittest", "discover", "-s", "scripts/tests", "-p", "test_render*.py"], build)
        run_step("Tests du complément de sauvegarde", [sys.executable, "-m", "unittest", "discover", "-s", "scripts/tests", "-p", "test_backup_constraint_comments.py"], build)
        for script in ([npm, "ci"], [npm, "run", "test:ux"], [npm, "run", "build"]):
            run_step("Vérification frontend", script, build, cwd=ROOT / "frontend")
        run_step("Construction Docker du commit", [docker, "build", "--file", "deploy/render/Dockerfile",
                 "--tag", "sauverndeko-render-check:" + args.commit, "."], build)
        verify_source(args.commit, clean=True)
    manage = [sys.executable, str(ROOT / "backend/manage.py")]
    run_step("Plan métier (lecture seule)", [*manage, "migrer_metier"], environment, private=True)
    run_step("Plan Django (lecture seule)", [*manage, "migrate", "--plan"], environment, private=True)
    if not write:
        print("Plan terminé. Aucune migration, aucun déploiement demandé.")
        return
    environment = database_environment(values, **destination, write=True)
    for label, command in (
            ("Migrations métier", ["migrer_metier", "--apply", "--release", args.commit]),
            ("Migrations Django dans public", ["migrate", "--noinput"])):
        verify_source(args.commit, clean=True)
        run_step(label, [*manage, *command], environment, private=True)
    verify_source(args.commit, clean=True)
    apply_runtime_grants(environment)
    readonly = database_environment(values, **destination, write=False)
    run_step("Contrôle métier final", [*manage, "migrer_metier", "--check"], readonly, private=True)
    run_step("Contrôle Django final", [*manage, "migrate", "--check"], readonly, private=True)
    print("Maintenance terminée pour " + args.commit + ". Aucun déploiement demandé.")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", nargs="?", choices=("plan", "apply"), default="plan")
    parser.add_argument("--commit", required=True, help="SHA complet de HEAD ; apply exige main propre = origin/main.")
    parser.add_argument("--env-file", help="Fichier privé dédié, jamais backend/.env.")
    parser.add_argument("--database-host", required=True)
    parser.add_argument("--database-name", required=True)
    parser.add_argument("--database-port", type=int, default=5432)
    parser.add_argument("--backup-reference")
    parser.add_argument("--confirm-maintenance", action="store_true")
    args = parser.parse_args(argv)
    try:
        execute(args)
        return 0
    except Exception as error:
        # Ne pas laisser remonter un DSN depuis une exception de bibliothèque.
        message = str(error) if isinstance(error, (ValueError, RuntimeError)) else "Vérifier les prérequis et la connexion privée."
        print("Maintenance interrompue. " + message, file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
