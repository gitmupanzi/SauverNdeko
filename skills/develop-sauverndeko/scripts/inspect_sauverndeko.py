from __future__ import annotations

import argparse
from collections import Counter
from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[3]
EXCLUDED = {".git", "node_modules", "generated", "dist", "build", "skills"}
TEXT_SUFFIXES = {".js", ".jsx", ".json", ".md", ".prisma", ".sql"}
SQL_OBJECT = re.compile(
    r'(?im)^\s*CREATE\s+(?:OR\s+REPLACE\s+)?(?:TABLE(?:\s+IF\s+NOT\s+EXISTS)?|VIEW|FUNCTION|PROCEDURE|TRIGGER)\s+'
    r'(?:(?P<schema>[a-z_][\w]*)\.)?"?(?P<name>[A-Za-z_][\w]*)"?'
)
PRISMA_MODEL = re.compile(r"(?ms)^model\s+(?P<name>\w+)\s*\{(?P<body>.*?)^\}")
SENSITIVE = re.compile(
    r"(?i)(DATABASE_URL|JWT_SECRET|JWT_REFRESH_SECRET|password|token)(\s*[=:]\s*)([^\s,;]+)"
)


def iter_files():
    for path in ROOT.rglob("*"):
        if path.is_file() and path.suffix.lower() in TEXT_SUFFIXES and not EXCLUDED.intersection(path.parts):
            yield path


def safe_text(path: Path) -> str:
    return path.read_text(encoding="utf-8-sig", errors="replace")


def redact(value: str) -> str:
    return SENSITIVE.sub(r"\1\2***REDACTED***", value)


def sql_objects():
    for path in sorted((ROOT / "SQL").rglob("*.sql")):
        text = safe_text(path)
        for match in SQL_OBJECT.finditer(text):
            yield path, match.group("schema") or "(non qualifié)", match.group("name"), match.start()


def summary() -> None:
    objects = list(sql_objects())
    by_schema = Counter(schema for _, schema, _, _ in objects)
    prisma = safe_text(ROOT / "backend" / "prisma" / "schema.prisma")
    models = list(PRISMA_MODEL.finditer(prisma))
    print("# Objets SQL détectés")
    for schema, count in sorted(by_schema.items()):
        print(f"{schema}: {count}")
    print(f"\nModèles Prisma: {len(models)}")
    print(f"Fichiers backend JS source: {sum(1 for p in (ROOT / 'backend').rglob('*.js') if not EXCLUDED.intersection(p.parts))}")
    print(f"Fichiers frontend JS/JSX source: {sum(1 for p in (ROOT / 'frontend').rglob('*') if p.suffix in {'.js', '.jsx'} and not EXCLUDED.intersection(p.parts))}")


def search(query: str, limit: int) -> None:
    needle = query.casefold()
    count = 0
    for path in iter_files():
        for line_number, line in enumerate(safe_text(path).splitlines(), start=1):
            if needle not in line.casefold():
                continue
            preview = " ".join(redact(line).strip().split())[:260]
            print(f"{path.relative_to(ROOT).as_posix()}:{line_number}: {preview}")
            count += 1
            if count >= limit:
                print(f"Limite atteinte ({limit}).")
                return
    if count == 0:
        print("Aucun résultat.")


def print_sql_object(value: str) -> None:
    wanted_schema, separator, wanted_name = value.partition(".")
    if not separator:
        wanted_name, wanted_schema = wanted_schema, ""
    matches = [
        item for item in sql_objects()
        if item[2].casefold() == wanted_name.casefold()
        and (not wanted_schema or item[1].casefold() == wanted_schema.casefold())
    ]
    if not matches:
        raise SystemExit(f"Objet SQL introuvable : {value}")
    for path, schema, name, offset in matches:
        text = safe_text(path)
        line = text.count("\n", 0, offset) + 1
        lines = text.splitlines()
        start = max(0, line - 1)
        end = min(len(lines), start + 80)
        print(f"\n# {schema}.{name} — {path.relative_to(ROOT).as_posix()}:{line}")
        print("\n".join(lines[start:end]))


def print_prisma_model(name: str) -> None:
    text = safe_text(ROOT / "backend" / "prisma" / "schema.prisma")
    for match in PRISMA_MODEL.finditer(text):
        if match.group("name").casefold() == name.casefold():
            print(f"model {match.group('name')} {{{match.group('body')}\n}}")
            return
    raise SystemExit(f"Modèle Prisma introuvable : {name}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Inspecter les contrats de SauverNdeko sans exécuter l'application.")
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--summary", action="store_true")
    group.add_argument("--query")
    group.add_argument("--sql-object")
    group.add_argument("--prisma-model")
    parser.add_argument("--limit", type=int, default=80)
    args = parser.parse_args()
    if args.summary:
        summary()
    elif args.query:
        search(args.query, args.limit)
    elif args.sql_object:
        print_sql_object(args.sql_object)
    else:
        print_prisma_model(args.prisma_model)


if __name__ == "__main__":
    main()
