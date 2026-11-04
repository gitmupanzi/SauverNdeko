"""Audit reproductible DHIS2 / GRID3 / géographie, sans écriture PostgreSQL.

La normalisation des noms produit des candidats, jamais une autorisation de
modifier une identité ou un parent. Les UID externes restent distincts des PK.
Lecture XLSX par la bibliothèque standard ; aucune dépendance Office requise.
"""
from __future__ import annotations

import argparse
import collections
import csv
import hashlib
import io
import json
import os
from pathlib import Path
import re
import sys
import unicodedata
import xml.etree.ElementTree as ET
import zipfile

NS = {"s": "http://schemas.openxmlformats.org/spreadsheetml/2006/main"}
REL = "{http://schemas.openxmlformats.org/officeDocument/2006/relationships}id"
UID = re.compile(r"[A-Za-z][A-Za-z0-9]{10}\Z")
DHIS_FIELDS = {
    "provinces": ("DHIS2_ID_Province", "Province", None),
    "zones": ("DHIS2_ID_Zone_de_sante", "Zone_de_sante", "DHIS2_ID_Province"),
    "aires": ("DHIS2_ID_Aire_de_sante", "Aire_de_sante", "DHIS2_ID_Zone_de_sante"),
}
GRID_FIELDS = {
    "provinces": ("prov_uid", "province", None),
    "zones": ("zs_uid", "zonesante", "prov_uid"),
    "aires": ("as_uid", "airesante", "zs_uid"),
}


def clean(value):
    return str(value if value is not None else "").strip()


def norm(value):
    return "".join(c for c in unicodedata.normalize("NFKD", clean(value)).casefold() if c.isalnum())


def json_bytes(value):
    return (json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True, default=str) + "\n").encode("utf8")


def read_xlsx(path):
    """Lire toutes les feuilles et conserver les numéros de ligne physiques."""
    path = Path(path)
    with zipfile.ZipFile(path) as archive:
        if any(i.file_size > 128 * 1024 * 1024 for i in archive.infolist()):
            raise ValueError("Un élément XLSX dépasse la taille maximale d'audit (128 Mo).")
        strings = []
        if "xl/sharedStrings.xml" in archive.namelist():
            root = ET.fromstring(archive.read("xl/sharedStrings.xml"))
            strings = ["".join(si.itertext()) for si in root.findall("s:si", NS)]
        rels = ET.fromstring(archive.read("xl/_rels/workbook.xml.rels"))
        targets = {r.attrib["Id"]: r.attrib["Target"] for r in rels}
        book = ET.fromstring(archive.read("xl/workbook.xml"))
        sheets = {}
        for sheet in book.findall("s:sheets/s:sheet", NS):
            target = targets[sheet.attrib[REL]]
            part = target.lstrip("/") if target.startswith("/") else "xl/" + target
            if ".." in Path(part).parts:
                raise ValueError("Chemin de feuille XLSX non pris en charge.")
            root = ET.fromstring(archive.read(part))
            rows = []
            for row in root.findall("s:sheetData/s:row", NS):
                cells = {}
                for cell in row.findall("s:c", NS):
                    address = cell.attrib.get("r", "")
                    column = re.sub(r"\d", "", address)
                    number = 0
                    for letter in column:
                        number = number * 26 + ord(letter) - 64
                    if not number:
                        raise ValueError("Cellule XLSX sans adresse.")
                    kind = cell.attrib.get("t")
                    value = cell.findtext("s:v", default="", namespaces=NS)
                    if kind == "s":
                        value = strings[int(value)]
                    elif kind == "inlineStr":
                        inline = cell.find("s:is", NS)
                        value = "".join(inline.itertext()) if inline is not None else ""
                    elif kind == "b":
                        value = value == "1"
                    cells[number - 1] = value
                if cells and any(v not in (None, "") for v in cells.values()):
                    values = [cells.get(i) for i in range(max(cells) + 1)]
                    rows.append({"row": int(row.attrib["r"]), "values": values})
            sheets[sheet.attrib["name"]] = rows
        return sheets


def records_with_headers(sheets, required):
    matches = []
    for name, rows in sheets.items():
        for header in rows[:20]:
            columns = [clean(v) for v in header["values"]]
            if not set(required).issubset(columns):
                continue
            if len([c for c in columns if c]) != len(set(c for c in columns if c)):
                raise ValueError("En-têtes de colonnes dupliqués dans " + name)
            records = []
            for row in rows:
                if row["row"] <= header["row"]:
                    continue
                records.append(dict(zip(columns, row["values"])) | {"_row": row["row"], "_sheet": name})
            matches.append((name, records))
            break
    if len(matches) != 1:
        raise ValueError("Une seule feuille doit contenir les colonnes attendues ; trouvées : " + str(len(matches)))
    return matches[0]


def canonical(records, fields):
    result, quality = {}, {}
    for level, (uid_field, name_field, parent_field) in fields.items():
        groups = collections.defaultdict(list)
        for row in records:
            groups[clean(row.get(uid_field))].append(row)
        items = []
        for uid, rows in sorted(groups.items()):
            if not uid:
                continue
            variants = sorted({(clean(r.get(name_field)), clean(r.get(parent_field))) for r in rows})
            signatures = {(norm(name), parent) for name, parent in variants}
            items.append({"uid": uid, "name": variants[0][0], "parent_uid": variants[0][1],
                          "source_rows": sorted(r["_row"] for r in rows), "variants": variants,
                          "valid_uid": bool(UID.fullmatch(uid)), "identity_consistent": len(signatures) == 1})
        names = collections.defaultdict(list)
        for item in items:
            names[(item["parent_uid"], norm(item["name"]))].append(item["uid"])
        quality[level] = {"distinct_uids": len(items), "missing_uid_rows": len(groups.get("", [])),
                          "invalid_uids": sum(not x["valid_uid"] for x in items),
                          "conflicting_uid_identities": sum(not x["identity_consistent"] for x in items),
                          "duplicate_parent_name_keys": sum(len(v) > 1 for v in names.values())}
        result[level] = items
    return result, quality


def read_database():
    """Projection limitée, transaction indépendante REPEATABLE READ READ ONLY."""
    root = Path(__file__).resolve().parents[1]
    sys.path.insert(0, str(root / "backend"))
    os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings")
    os.environ["SAUVERNDEKO_DB_READ_ONLY"] = "1"
    import django
    django.setup()
    from django.db import connection, transaction
    allowed = {
        "1": ["ID_Niveau_1", "NomNiveau_1", "ID_Niveau_0_Fk", "prov_uid", "uidSNIS"],
        "2": ["ID_Niveau_2", "NomNiveau_2", "ID_Niveau_1_FK", "ID_TypeNiveau_2_Fk", "uidSNIS"],
        "3": ["ID_Niveau_3", "NomNiveau_3", "Alt_Niveau_3", "ID_Niveau_2_FK", "ID_TypeNiveau_2_Fk", "uidSNIS"],
        "4": ["ID_Niveau_4", "NomNiveau_4", "ID_Niveau_3_Fk", "ID_TypeNiveau_4_Fk", "uidSNIS"],
        "5": ["ID_Niveau_5", "NomNiveau_5", "ID_Niveau_3_Fk", "ID_Niveau_4_Fk", "ID_TypeNiveau_5_Fk", "uidSNIS"],
    }
    with transaction.atomic():
        with connection.cursor() as cur:
            cur.execute("SET TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY")
            cur.execute("SHOW transaction_read_only")
            if cur.fetchone()[0] != "on":
                raise RuntimeError("La transaction n'est pas en lecture seule.")
            cur.execute("SELECT current_database()")
            database = cur.fetchone()[0]
            rows = {}
            for level, columns in allowed.items():
                columns_sql = ",".join(connection.ops.quote_name(c) for c in columns)
                cur.execute('SELECT ' + columns_sql + ' FROM geolocalisation."T_Niveau_' + level + '" ORDER BY "ID_Niveau_' + level + '"')
                rows[level] = [dict(zip(columns, row)) for row in cur.fetchall()]
            cur.execute('SELECT "ID_Generique", "AbrGenerique", "NomGenerique" FROM referentiel."T_Generique" ORDER BY "ID_Generique"')
            references = [dict(zip(["ID_Generique", "AbrGenerique", "NomGenerique"], row)) for row in cur.fetchall()]
    return {"database": database, "read_only": True, "rows": rows, "references": references}


def audit(dhis, grid, snapshot):
    dc, dq = canonical(dhis, DHIS_FIELDS)
    gc, gq = canonical(grid, GRID_FIELDS)
    cross = []
    for level in DHIS_FIELDS:
        a = {x["uid"]: x for x in dc[level]}
        b = {x["uid"]: x for x in gc[level]}
        for uid in sorted(a.keys() | b.keys()):
            x, y = a.get(uid), b.get(uid)
            status = "UID_EXACT" if x and y else "ABSENT_GRID3" if x else "ABSENT_DHIS2"
            if (x and not x["identity_consistent"]) or (y and not y["identity_consistent"]):
                status = "UID_CONTRADICTOIRE"
            elif (x and not x["valid_uid"]) or (y and not y["valid_uid"]):
                status = "UID_INVALIDE"
            elif x and y and x["parent_uid"] != y["parent_uid"]:
                status = "CONFLIT_PARENT"
            elif x and y and norm(x["name"]) != norm(y["name"]):
                status = "NOMS_DIFFERENTS"
            cross.append({"level": level, "uid": uid, "dhis2_name": x["name"] if x else "",
                          "grid3_name": y["name"] if y else "", "dhis2_parent_uid": x["parent_uid"] if x else "",
                          "grid3_parent_uid": y["parent_uid"] if y else "", "dhis2_rows": x["source_rows"] if x else [],
                          "grid3_rows": y["source_rows"] if y else [], "status": status})
    rows = snapshot["rows"]
    byid = {n: {r["ID_Niveau_" + n]: r for r in values} for n, values in rows.items()}
    refs = {r["ID_Generique"]: r for r in snapshot["references"]}

    def province(row, level):
        if level == "1": return row.get("ID_Niveau_1")
        if level == "2": return row.get("ID_Niveau_1_FK")
        if level == "3": return province(byid["2"].get(row.get("ID_Niveau_2_FK"), {}), "2")
        return province(byid["3"].get(row.get("ID_Niveau_3_Fk"), {}), "3")

    def type_label(row, level):
        key = "ID_TypeNiveau_2_Fk" if level in ("2", "3") else "ID_TypeNiveau_" + level + "_Fk"
        return clean(refs.get(row.get(key), {}).get("AbrGenerique"))

    dp = {x["uid"]: x for x in dc["provinces"]}
    gp = {x["uid"]: x for x in gc["provinces"]}
    province_rows, safe, province_matches = [], [], {}
    province_uid_counts = collections.Counter(clean(r.get("uidSNIS")) or clean(r.get("prov_uid")) for r in rows["1"])
    for row in rows["1"]:
        uid = clean(row.get("uidSNIS")) or clean(row.get("prov_uid"))
        x, y = dp.get(uid), gp.get(uid)
        verified = bool(x and y and x["identity_consistent"] and y["identity_consistent"] and x["valid_uid"]
                        and norm(x["name"]) == norm(row["NomNiveau_1"]) == norm(y["name"]))
        incompatible = bool(clean(row.get("uidSNIS")) and clean(row.get("prov_uid")) and clean(row["uidSNIS"]) != clean(row["prov_uid"]))
        status = "SURE_UID_EXISTANT" if verified and not incompatible and province_uid_counts[uid] == 1 else "CONFLIT_OU_UID_NON_PROUVE"
        item = {"level": 1, "local_id": row["ID_Niveau_1"], "name": row["NomNiveau_1"], "uid_existing": row.get("uidSNIS"),
                "legacy_prov_uid": row.get("prov_uid"), "source_uid": uid, "dhis2_name": x["name"] if x else "",
                "grid3_name": y["name"] if y else "", "source_rows": x["source_rows"] if x else [], "status": status}
        province_rows.append(item)
        if status == "SURE_UID_EXISTANT":
            province_matches[row["ID_Niveau_1"]] = uid
            if not clean(row.get("uidSNIS")):
                safe.append({"table": "T_Niveau_1", "local_id": row["ID_Niveau_1"], "column": "uidSNIS",
                             "expected_before": row.get("uidSNIS"), "proposed_after": uid,
                             "proof": "UID prov_uid déjà présent ; même nom dans DHIS2 et GRID3", "source_rows": x["source_rows"]})
    bad_zone_uids = {x["uid"] for x in dc["zones"] if not x["identity_consistent"] or not x["valid_uid"]}
    source_zones = collections.defaultdict(list)
    gz = {x["uid"]: x for x in gc["zones"]}
    for z in dc["zones"]:
        if z["uid"] not in bad_zone_uids:
            source_zones[(z["parent_uid"], norm(z["name"]))].append(z)
    zone_rows, zone_matches = [], {}
    for row in rows["3"]:
        typ = type_label(row, "3")
        if norm(typ) not in {"zs", "bczs"}: continue
        parent_uid = province_matches.get(province(row, "3"), "")
        aliases = {norm(row.get("NomNiveau_3")), norm(row.get("Alt_Niveau_3"))} - {""}
        found = {z["uid"]: z for name in aliases for z in source_zones.get((parent_uid, name), [])}
        z = next(iter(found.values())) if len(found) == 1 else None
        status = "CANDIDAT_NOM_PARENT" if z else "AMBIGU" if found else "SANS_CORRESPONDANCE"
        if z and clean(row.get("uidSNIS")) and clean(row["uidSNIS"]) != z["uid"]: status = "CONFLIT_UID_EXISTANT"
        zone_rows.append({"level": 3, "local_id": row["ID_Niveau_3"], "type": typ, "name": row["NomNiveau_3"],
                          "province_id": province(row, "3"), "uid_existing": row.get("uidSNIS"), "candidate_uid": z["uid"] if z else "",
                          "source_rows": z["source_rows"] if z else [], "status": status,
                          "reason": "Nom et parent ne prouvent pas une identité ; validation nécessaire"})
        g = gz.get(z["uid"]) if z else None
        if z and g and status == "CANDIDAT_NOM_PARENT" and g["parent_uid"] == z["parent_uid"] and norm(g["name"]) == norm(z["name"]):
            zone_matches[row["ID_Niveau_3"]] = z["uid"]
    source_areas = collections.defaultdict(list)
    ga = {x["uid"]: x for x in gc["aires"]}
    for a in dc["aires"]:
        if a["valid_uid"] and a["identity_consistent"] and a["parent_uid"] not in bad_zone_uids:
            source_areas[(a["parent_uid"], norm(a["name"]))].append(a)
    area_rows, legacy_rows = [], []
    for level in ("4", "5"):
        for row in rows[level]:
            typ = type_label(row, level)
            if norm(typ) != "as": continue
            parent = row.get("ID_Niveau_3_Fk")
            found = source_areas.get((zone_matches.get(parent, ""), norm(row["NomNiveau_" + level])), [])
            a = found[0] if len(found) == 1 else None
            status = "CANDIDAT_NOM_PARENT" if a else "AMBIGU" if found else "SANS_CORRESPONDANCE"
            if a and clean(row.get("uidSNIS")) and clean(row["uidSNIS"]) != a["uid"]: status = "CONFLIT_UID_EXISTANT"
            g = ga.get(a["uid"]) if a else None
            if a and g and g["parent_uid"] != a["parent_uid"]: status = "CONFLIT_PARENT_GRID3"
            area_rows.append({"level": int(level), "local_id": row["ID_Niveau_" + level], "name": row["NomNiveau_" + level],
                              "parent_n3_id": parent, "uid_existing": row.get("uidSNIS"), "candidate_uid": a["uid"] if a else "",
                              "source_rows": a["source_rows"] if a else [], "status": status,
                              "reason": "Nom et zone candidate ; aucune modification automatique"})
    n4_index = collections.defaultdict(list)
    for row in rows["4"]:
        n4_index[(row.get("ID_Niveau_3_Fk"), norm(type_label(row, "4")), norm(row["NomNiveau_4"]))].append(row["ID_Niveau_4"])
    unlinked = []
    for row in rows["5"]:
        typ = type_label(row, "5")
        if row.get("ID_Niveau_4_Fk") is None:
            unlinked.append({"local_id": row["ID_Niveau_5"], "name": row["NomNiveau_5"], "type": typ,
                             "parent_n3_id": row.get("ID_Niveau_3_Fk"), "status": "AIRE_NON_RENSEIGNEE"})
        if norm(typ) not in {"as", "grp"}: continue
        matches = n4_index.get((row.get("ID_Niveau_3_Fk"), norm(typ), norm(row["NomNiveau_5"])), [])
        legacy_rows.append({"local_id_n5": row["ID_Niveau_5"], "name": row["NomNiveau_5"], "type": typ,
                            "parent_n3_id": row.get("ID_Niveau_3_Fk"), "candidate_n4_ids": matches,
                            "status": "COPIE_POSSIBLE" if len(matches) == 1 else "AMBIGU" if matches else "SANS_CORRESPONDANCE"})
    counts = collections.Counter(clean(r.get("as_uid")) for r in grid if clean(r.get("as_uid")))
    gridids = collections.Counter(clean(r.get("grid3id")) for r in grid)
    summary = {"dhis2": dq | {"rows": len(dhis)}, "grid3": gq | {"rows": len(grid),
               "objects_with_missing_as_uid": sum(not clean(r.get("as_uid")) for r in grid),
               "grid3id_missing": gridids.get("", 0), "duplicate_grid3id_keys": sum(k != "" and v > 1 for k, v in gridids.items()),
               "areas_with_multiple_objects": sum(v > 1 for v in counts.values()), "maximum_objects_per_area": max(counts.values(), default=0)},
               "safe_uid_fills": len(safe), "database_mutated": False, "geometry_generated": False,
               "counts_before": {n: len(v) for n, v in rows.items()}, "counts_after": {n: len(v) for n, v in rows.items()},
               "matching_rule": "Les noms/parents produisent des candidats. Aucune réaffectation, fusion, suppression ni création.",
               "province_status": dict(collections.Counter(x["status"] for x in province_rows)),
               "zone_status": {t: dict(collections.Counter(x["status"] for x in zone_rows if x["type"] == t)) for t in sorted({x["type"] for x in zone_rows})}}
    return {"summary": summary, "canonical_dhis2": dc, "canonical_grid3": gc, "provinces": province_rows,
            "zones": zone_rows, "aires_existantes": area_rows, "copies_n5_as_grp": legacy_rows,
            "n5_sans_aire": unlinked, "rapprochement_sources": cross, "actions_sures_uid_seulement": safe,
            "objets_grid3": [{k: row.get(k) for k in ["OBJECTID", "grid3id", "province", "prov_uid", "antenne", "zonesante", "zs_uid", "airesante", "as_uid", "asnom_alt", "date", "source_acronym", "sourceid", "edit_par"]} | {"source_row": row["_row"]} for row in grid]}


def csv_bytes(rows):
    stream = io.StringIO(newline="")
    fields = list(dict.fromkeys(k for row in rows for k in row)) or ["aucune_ligne"]
    writer = csv.DictWriter(stream, fields, delimiter=";", lineterminator="\n")
    writer.writeheader()
    for row in rows:
        values = {k: json.dumps(v, ensure_ascii=False) if isinstance(v, (dict, list, tuple)) else v for k, v in row.items()}
        # CSV est lisible dans Excel ; les données brutes exactes restent dans JSON.
        values = {k: "'" + v if isinstance(v, str) and v.lstrip().startswith(("=", "+", "-", "@")) else v for k, v in values.items()}
        writer.writerow(values)
    return ("\ufeff" + stream.getvalue()).encode("utf8")


def save_report(destination, report, inputs):
    destination = Path(destination).resolve()
    for source in inputs:
        source = Path(source).resolve()
        if source == destination or destination in source.parents:
            raise ValueError("Le dossier de rapport ne peut pas contenir un fichier source.")
    outputs = {"rapport.json": json_bytes(report)}
    for name, value in report.items():
        if isinstance(value, list): outputs[name + ".csv"] = csv_bytes(value)
    for name, data in outputs.items():
        target = destination / name
        if target.exists() and target.read_bytes() != data:
            raise ValueError("Rapport existant différent ; choisir un nouveau dossier : " + str(target))
    destination.mkdir(parents=True, exist_ok=True)
    for name, data in outputs.items():
        target = destination / name
        if not target.exists():
            with target.open("xb") as output: output.write(data)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dhis2", required=True, type=Path)
    parser.add_argument("--grid3", required=True, type=Path)
    parser.add_argument("--destination", required=True, type=Path)
    parser.add_argument("--snapshot", type=Path, help="Projection d'audit JSON antérieure ; évite toute connexion DB.")
    args = parser.parse_args()
    sheets_d, sheets_g = read_xlsx(args.dhis2), read_xlsx(args.grid3)
    dsheet, drows = records_with_headers(sheets_d, {"DHIS2_ID_Province", "DHIS2_ID_Zone_de_sante", "DHIS2_ID_Aire_de_sante"})
    gsheet, grows = records_with_headers(sheets_g, {"prov_uid", "zs_uid", "as_uid", "grid3id"})
    snapshot = json.loads(args.snapshot.read_text(encoding="utf8")) if args.snapshot else read_database()
    result = audit(drows, grows, snapshot)
    result["sources"] = {"dhis2": {"file": args.dhis2.name, "sha256": hashlib.sha256(args.dhis2.read_bytes()).hexdigest(), "sheet": dsheet},
                         "grid3": {"file": args.grid3.name, "sha256": hashlib.sha256(args.grid3.read_bytes()).hexdigest(), "sheet": gsheet}}
    result["sheets_inspected"] = {"dhis2": {k: len(v) for k, v in sheets_d.items()}, "grid3": {k: len(v) for k, v in sheets_g.items()}}
    result["database"] = snapshot.get("database")
    save_report(args.destination, result, [args.dhis2, args.grid3] + ([args.snapshot] if args.snapshot else []))
    print(json.dumps(result["summary"], ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
