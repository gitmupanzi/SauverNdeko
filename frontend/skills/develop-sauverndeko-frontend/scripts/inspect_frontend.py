from __future__ import annotations

import argparse
from pathlib import Path
import re


FRONTEND = Path(__file__).resolve().parents[3]
SRC = FRONTEND / "src"
EXCLUDED = {"node_modules", "dist", "skills", ".git"}
ROUTE_BLOCK = re.compile(r"<Route\b.*?/>", re.DOTALL)
ROUTE_PATH = re.compile(r"\bpath\s*=\s*['\"](?P<path>[^'\"]+)['\"]")
EXPORT = re.compile(r"(?m)^export\s+(?:async\s+)?function\s+(?P<name>\w+)|^export\s+const\s+(?P<const>\w+)")
ENDPOINT = re.compile(r"(?P<quote>`|['\"])(?P<path>/(?:api|SauverNdeko|health)[^`'\"]*)(?P=quote)")


def source_files():
    for path in SRC.rglob("*"):
        if path.is_file() and path.suffix in {".js", ".jsx", ".css"} and not EXCLUDED.intersection(path.parts):
            yield path


def text(path: Path) -> str:
    return path.read_text(encoding="utf-8-sig", errors="replace")


def routes() -> None:
    app = SRC / "App.jsx"
    for block_match in ROUTE_BLOCK.finditer(text(app)):
        block = block_match.group(0)
        path_match = ROUTE_PATH.search(block)
        if not path_match:
            continue
        guard = "AdminRoute" if "AdminRoute" in block else "ProtectedRoute" if "ProtectedRoute" in block else "public"
        print(f"{path_match.group('path'):20} {guard}")


def services() -> None:
    service_dir = SRC / "services"
    for path in sorted(service_dir.glob("*.js")):
        content = text(path)
        names = [(m.group("name") or m.group("const")) for m in EXPORT.finditer(content)]
        endpoints = sorted({m.group("path") for m in ENDPOINT.finditer(content)})
        print(f"\n# {path.relative_to(FRONTEND).as_posix()}")
        if names:
            print("Exports: " + ", ".join(names))
        for endpoint in endpoints:
            print(f"  {endpoint}")


def search(query: str, limit: int) -> None:
    needle = query.casefold()
    count = 0
    for path in sorted(source_files()):
        for line_number, line in enumerate(text(path).splitlines(), start=1):
            if needle in line.casefold():
                print(f"{path.relative_to(FRONTEND).as_posix()}:{line_number}: {' '.join(line.strip().split())[:260]}")
                count += 1
                if count >= limit:
                    print(f"Limite atteinte ({limit}).")
                    return
    if count == 0:
        print("Aucun résultat.")


def main() -> None:
    parser = argparse.ArgumentParser(description="Inspecter statiquement le frontend SauverNdeko.")
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--routes", action="store_true")
    group.add_argument("--services", action="store_true")
    group.add_argument("--query")
    parser.add_argument("--limit", type=int, default=80)
    args = parser.parse_args()
    if args.routes:
        routes()
    elif args.services:
        services()
    else:
        search(args.query, args.limit)


if __name__ == "__main__":
    main()
