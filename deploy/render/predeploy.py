"""Refuser un déploiement si le schéma n'est pas prêt ; aucune écriture SQL."""
import os
import subprocess
import sys
from pathlib import Path
from environment import configure


def main():
    try:
        configure()
    except RuntimeError as error:
        print(str(error), file=sys.stderr)
        return 1
    root = Path(__file__).resolve().parents[2]
    environment = os.environ.copy()
    environment["SAUVERNDEKO_DB_READ_ONLY"] = "1"
    role = subprocess.run([sys.executable, str(root / "deploy/render/runtime_role.py")],
                          cwd=root, env=environment, check=False)
    if role.returncode:
        return role.returncode
    for arguments in (("check",), ("migrer_metier", "--check"), ("migrate", "--check")):
        result = subprocess.run(
            [sys.executable, str(root / "backend/manage.py"), *arguments],
            cwd=root, env=environment, check=False,
        )
        if result.returncode:
            if arguments in (("migrer_metier", "--check"), ("migrate", "--check")):
                print(
                    "Vérifiez le diagnostic de la base ci-dessus. Pour des migrations en attente, "
                    "utilisez la livraison Render contrôlée après vérification des sauvegardes "
                    "PostgreSQL et médias (docs/deploiement-render.md).",
                    file=sys.stderr,
                )
            return result.returncode
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
