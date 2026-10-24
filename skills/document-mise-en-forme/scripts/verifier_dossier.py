"""Contrôle en lecture seule du skill documentaire SauverNdeko.

Vérifie liens, charte, logo et empreintes ; ne valide pas des exports réels.
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import re
import sys
from urllib.parse import unquote, urlsplit


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--strict-external", action="store_true",
                        help="Exiger les dépendances du dépôt et la source du logo")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    project = root.parents[1]
    errors: list[str] = []
    required = ["SKILL.md", "README.md", "references/charte_documentaire.md",
                "references/integration_plateforme.md", "references/documents_types.md",
                "references/excel.md", "references/word_pdf.md", "references/tableaux.md",
                "references/sources_et_migrations.json", "assets/charte_sauverndeko.json",
                "assets/sauverndeko-logo.jpg", "SHA256SUMS.txt"]
    for name in required:
        item = root / name
        if not item.is_file() or item.stat().st_size == 0:
            errors.append(f"Fichier absent ou vide : {name}")
    files = [p for p in root.rglob("*") if p.is_file() and "__pycache__" not in p.parts
             and p.suffix != ".pyc"]
    for item in files:
        if item.is_symlink():
            errors.append(f"Lien symbolique inattendu : {item.relative_to(root)}")
        if item.suffix.lower() in {".ttf", ".otf", ".woff", ".woff2", ".ttc"}:
            errors.append(f"Police distribuée dans le skill : {item.relative_to(root)}")
        if item.suffix.lower() == ".json":
            try:
                json.loads(item.read_text(encoding="utf-8"))
            except (ValueError, UnicodeError) as exc:
                errors.append(f"JSON invalide {item.relative_to(root)} : {exc}")
    try:
        registry = json.loads((root / "references/sources_et_migrations.json").read_text(encoding="utf-8"))
        logo = registry["assets"]["logo"]
        logo_path = (root / logo["chemin"]).resolve()
        if not logo_path.is_relative_to(root) or sha(logo_path) != logo["sha256"]:
            errors.append("Le logo local ne correspond pas à la source SauverNdeko enregistrée")
        source = project / logo["source_projet"]
        if source.is_file():
            if sha(source) != logo["sha256"]:
                errors.append("Le logo de l’application a changé : actualiser la copie et sa provenance")
        elif args.strict_external:
            errors.append("Source du logo absente du dépôt")
        theme = json.loads((root / "assets/charte_sauverndeko.json").read_text(encoding="utf-8"))
        if theme["projet"] != "SauverNdeko" or theme["identite"]["logo"] != logo["chemin"]:
            errors.append("Identité ou logo incohérent dans la charte")
        if any(not re.fullmatch(r"[0-9A-F]{6}", value) for value in theme["palette"].values()):
            errors.append("Couleur de charte invalide")
        if theme["semantique"]["devise_par_defaut"] is not None:
            errors.append("La charte ne doit pas déduire une devise par défaut")
        if theme["excel"]["extension"] != ".xlsx" or theme["excel"]["formats"]["identifiant"] != "@":
            errors.append("Contrat Excel natif ou identifiant texte incohérent")
    except (OSError, ValueError, KeyError, TypeError) as exc:
        errors.append(f"Contrôle de charte/provenance impossible : {exc}")
    manifest = root / "SHA256SUMS.txt"
    if manifest.is_file():
        listed = set()
        for line in manifest.read_text(encoding="utf-8").splitlines():
            if not line.strip():
                continue
            try:
                expected, name = line.split("  ", 1)
                target = (root / name).resolve()
                if not re.fullmatch(r"[0-9a-f]{64}", expected) or not target.is_relative_to(root) or not target.is_file():
                    raise ValueError(f"Chemin ou empreinte invalide : {name}")
                if name in listed:
                    errors.append(f"Empreinte répétée : {name}")
                listed.add(name)
                if sha(target) != expected:
                    errors.append(f"Empreinte différente : {name}")
            except (ValueError, OSError) as exc:
                errors.append(str(exc))
        actual = {p.relative_to(root).as_posix() for p in files if p != manifest}
        errors.extend("Fichier non répertorié : " + name for name in sorted(actual - listed))
    internal = 0
    external: dict[str, bool] = {}
    for item in files:
        if item.suffix.lower() != ".md":
            continue
        for raw in re.findall(r"\]\(([^)]+)\)", item.read_text(encoding="utf-8")):
            raw = raw.strip().split(' "', 1)[0].removeprefix("<").removesuffix(">")
            if raw.startswith(("http:", "https:", "mailto:", "#")):
                continue
            local = unquote(urlsplit(raw).path)
            if not local:
                continue
            target = (item.parent / local).resolve()
            if target.is_relative_to(root):
                internal += 1
                if not target.exists():
                    errors.append(f"Lien interne rompu : {item.relative_to(root)} -> {raw}")
            else:
                external[str(target)] = target.exists()
    missing = [name for name, exists in external.items() if not exists]
    if args.strict_external:
        errors.extend("Dépendance requise absente : " + name for name in missing)
    print(f"Fichiers contrôlés : {len(files)} ; liens internes : {internal}")
    print(f"Dépendances hors dossier : {len(external)} ; absentes : {len(missing)}")
    if errors:
        for error in errors:
            print("ERREUR : " + error, file=sys.stderr)
        return 1
    print("Skill SauverNdeko vérifié. Aucun rendu ou export applicatif réel n’est validé par ce contrôle.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
