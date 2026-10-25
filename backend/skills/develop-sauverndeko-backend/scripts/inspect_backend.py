"""Inspecteur historique Express/Prisma ; ne pas utiliser pour le backend Django actuel.

Conservé pour provenance. Consulter ../SKILL.md pour les outils et commandes maintenus.
"""
from __future__ import annotations

import argparse
from pathlib import Path
import re


BACKEND = Path(__file__).resolve().parents[3]
EXCLUDED = {"node_modules", "generated", "skills", ".git"}
MOUNT = re.compile(r"app\.use\(\s*['\"](?P<prefix>[^'\"]+)['\"]\s*,\s*(?P<handler>[\w.]+)")
ROUTE = re.compile(r"router\.(?P<method>get|post|put|patch|delete)\(\s*['\"](?P<path>[^'\"]*)['\"]")
EXPORT = re.compile(r"(?:module\.exports\s*=|exports\.(?P<name>\w+)\s*=)")


def js_files():
    for path in BACKEND.rglob("*.js"):
        if not EXCLUDED.intersection(path.parts):
            yield path


def text(path: Path) -> str:
    return path.read_text(encoding="utf-8-sig", errors="replace")


def routes() -> None:
    print("# Montages Express")
    for path in [BACKEND / "app.js", BACKEND / "src/modules/register-module-routes.js"]:
        for match in MOUNT.finditer(text(path)):
            print(f"{match.group('prefix')} -> {match.group('handler')} ({path.relative_to(BACKEND).as_posix()})")
    print("\n# Routes de routers")
    for path in sorted(js_files()):
        matches = list(ROUTE.finditer(text(path)))
        for match in matches:
            print(f"{match.group('method').upper():6} {match.group('path') or '/':35} {path.relative_to(BACKEND).as_posix()}")


def module(value: str) -> None:
    base = BACKEND / "src" / "modules"
    normalized = value.replace("\\", "/").strip("/").casefold()
    matches = [p for p in base.rglob("index.js") if p.parent.relative_to(base).as_posix().casefold().endswith(normalized)]
    if len(matches) != 1:
        choices = "\n".join(str(p.parent.relative_to(base)) for p in matches) or "aucun"
        raise SystemExit(f"Module ambigu ou introuvable : {value}\n{choices}")
    index = matches[0]
    print(f"# {index.relative_to(BACKEND).as_posix()}\n{text(index)}")
    aliases = sorted(p for p in index.parent.glob("*.js") if p != index)
    if aliases:
        print("\n# Fichiers associés")
        for path in aliases:
            print(path.name)


def search(query: str, limit: int) -> None:
    needle = query.casefold()
    count = 0
    candidates = list(js_files()) + [BACKEND / "prisma/schema.prisma"]
    for path in sorted(set(candidates)):
        for line_number, line in enumerate(text(path).splitlines(), start=1):
            if needle in line.casefold():
                preview = " ".join(line.strip().split())[:260]
                print(f"{path.relative_to(BACKEND).as_posix()}:{line_number}: {preview}")
                count += 1
                if count >= limit:
                    print(f"Limite atteinte ({limit}).")
                    return
    if count == 0:
        print("Aucun résultat.")


def main() -> None:
    parser = argparse.ArgumentParser(description="Inspecter statiquement le backend SauverNdeko.")
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--routes", action="store_true")
    group.add_argument("--module")
    group.add_argument("--query")
    parser.add_argument("--limit", type=int, default=80)
    args = parser.parse_args()
    if args.routes:
        routes()
    elif args.module:
        module(args.module)
    else:
        search(args.query, args.limit)


if __name__ == "__main__":
    main()
