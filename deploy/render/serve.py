"""Deux processus supervisés : Caddy public et Waitress limité à la boucle locale."""
import os
import signal
import subprocess
import sys
import time
from pathlib import Path
from environment import configure


def stop(processes):
    for process in processes:
        if process.poll() is None:
            process.terminate()
    deadline = time.monotonic() + 20
    for process in processes:
        try:
            process.wait(timeout=max(0.1, deadline - time.monotonic()))
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=5)


def main():
    processes = []
    requested_stop = False
    def shutdown(_signum, _frame):
        nonlocal requested_stop
        requested_stop = True
    for name in ("SIGTERM", "SIGINT"):
        signal.signal(getattr(signal, name), shutdown)
    try:
        configure()
        root = Path(__file__).resolve().parents[2]
        media = Path(os.environ["SAUVERNDEKO_MEDIA_ROOT"])
        media.mkdir(parents=True, exist_ok=True)
        # Le rôle runtime est vérifié par le pré-déploiement ; aucun migrate au démarrage.
        processes.append(subprocess.Popen([sys.executable, "serve_production.py"], cwd=root / "backend"))
        processes.append(subprocess.Popen(["caddy", "run", "--config", str(root / "deploy/render/Caddyfile"), "--adapter", "caddyfile"], cwd=root))
        while not requested_stop:
            if any(process.poll() is not None for process in processes):
                print("Un service s'est arrêté ; arrêt de l'instance.", file=sys.stderr)
                return 1
            time.sleep(0.25)
        return 0
    except (OSError, RuntimeError) as error:
        print("Démarrage Render refusé : " + str(error), file=sys.stderr)
        return 1
    finally:
        stop(processes)


if __name__ == "__main__":
    raise SystemExit(main())
