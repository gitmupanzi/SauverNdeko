"""Recette autonome sans DB ni données clients : python -m unittest discover ..."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
import zipfile

PATH = Path(__file__).resolve().parents[1] / "auditer_pyramide_sanitaire.py"
spec = importlib.util.spec_from_file_location("pyramide_audit", PATH)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


def fixture():
    dhis = [{"DHIS2_ID_Province": "P0000000001", "Province": "Province A", "DHIS2_ID_Zone_de_sante": "Z0000000001",
             "Zone_de_sante": "Zone A", "DHIS2_ID_Aire_de_sante": "A0000000001", "Aire_de_sante": "Aire A", "_row": 2}]
    grid = [{"prov_uid": "P0000000001", "province": "Province A", "zs_uid": "Z0000000001", "zonesante": "Zone A",
             "as_uid": "A0000000001", "airesante": "Aire A", "grid3id": "GRID3_OBJECT_1", "_row": 2}]
    snapshot = {"database": "fixture", "rows": {
        "1": [{"ID_Niveau_1": 100, "NomNiveau_1": "Province A", "prov_uid": "P0000000001\n", "uidSNIS": None}],
        "2": [{"ID_Niveau_2": 200, "ID_Niveau_1_FK": 100}],
        "3": [{"ID_Niveau_3": 300, "NomNiveau_3": "Zone A", "ID_Niveau_2_FK": 200, "ID_TypeNiveau_2_Fk": 903}],
        "4": [{"ID_Niveau_4": 400, "NomNiveau_4": "Aire A", "ID_Niveau_3_Fk": 300, "ID_TypeNiveau_4_Fk": 904}],
        "5": [{"ID_Niveau_5": 500, "NomNiveau_5": "Aire A", "ID_Niveau_3_Fk": 300, "ID_Niveau_4_Fk": None, "ID_TypeNiveau_5_Fk": 904}],
    }, "references": [{"ID_Generique": 903, "AbrGenerique": "ZS"}, {"ID_Generique": 904, "AbrGenerique": "AS"}]}
    return dhis, grid, snapshot


class AuditTests(unittest.TestCase):
    def test_existing_uid_proof_is_distinct_from_local_key_and_name_candidate(self):
        d, g, s = fixture()
        result = module.audit(d, g, s)
        self.assertEqual(result["actions_sures_uid_seulement"][0]["local_id"], 100)
        self.assertEqual(result["actions_sures_uid_seulement"][0]["proposed_after"], "P0000000001")
        self.assertEqual(result["zones"][0]["status"], "CANDIDAT_NOM_PARENT")
        self.assertEqual(result["aires_existantes"][0]["status"], "CANDIDAT_NOM_PARENT")
        self.assertFalse(result["summary"]["database_mutated"])
        self.assertIsNone(s["rows"]["1"][0]["uidSNIS"])

    def test_uid_name_conflict_is_never_approved(self):
        d, g, s = fixture()
        s["rows"]["1"][0]["NomNiveau_1"] = "Autre province"
        result = module.audit(d, g, s)
        self.assertEqual(result["actions_sures_uid_seulement"], [])
        self.assertEqual(result["zones"][0]["status"], "SANS_CORRESPONDANCE")

    def test_duplicate_existing_province_uid_requires_validation(self):
        d, g, s = fixture()
        s["rows"]["1"].append(s["rows"]["1"][0] | {"ID_Niveau_1": 101})
        self.assertEqual(module.audit(d, g, s)["actions_sures_uid_seulement"], [])

    def test_csv_neutralizes_spreadsheet_formulas_without_changing_raw_json(self):
        rows = [{"name": "=1+1", "uid": "A0000000001"}]
        self.assertIn("'=1+1", module.csv_bytes(rows).decode("utf-8-sig"))
        self.assertEqual(json.loads(module.json_bytes(rows))[0]["name"], "=1+1")

    def test_contradictory_source_zone_uid_blocks_descendant_proposals(self):
        d, g, s = fixture()
        d.append(d[0] | {"Zone_de_sante": "Autre zone", "DHIS2_ID_Province": "P0000000002", "_row": 3})
        result = module.audit(d, g, s)
        self.assertEqual(result["summary"]["dhis2"]["zones"]["conflicting_uid_identities"], 1)
        self.assertEqual(result["zones"][0]["status"], "SANS_CORRESPONDANCE")
        self.assertTrue(all(x["status"] == "SANS_CORRESPONDANCE" for x in result["aires_existantes"]))

    def test_alias_and_same_parent_produce_candidate_not_automatic_match(self):
        d, g, s = fixture()
        s["rows"]["3"][0].update(NomNiveau_3="Ancien nom", Alt_Niveau_3="Zone-A")
        result = module.audit(d, g, s)
        self.assertEqual(result["zones"][0]["candidate_uid"], "Z0000000001")
        self.assertEqual(result["zones"][0]["status"], "CANDIDAT_NOM_PARENT")
        s["rows"]["2"][0]["ID_Niveau_1_FK"] = 999
        self.assertEqual(module.audit(d, g, s)["zones"][0]["status"], "SANS_CORRESPONDANCE")

    def test_grid3_many_objects_per_area_and_parent_conflict_are_preserved(self):
        d, g, s = fixture()
        g.append(g[0] | {"grid3id": "GRID3_OBJECT_2", "_row": 3})
        result = module.audit(d, g, s)
        self.assertEqual(len(result["objets_grid3"]), 2)
        self.assertEqual(result["summary"]["grid3"]["areas_with_multiple_objects"], 1)
        g[0]["zs_uid"] = g[1]["zs_uid"] = "Z0000000002"
        # Garder la zone initiale représentée par une autre aire GRID3.
        g.append(g[0] | {"zs_uid": "Z0000000001", "as_uid": "A0000000002", "grid3id": "GRID3_OBJECT_3", "_row": 4})
        result = module.audit(d, g, s)
        self.assertEqual([r for r in result["rapprochement_sources"] if r["level"] == "aires"][0]["status"], "CONFLIT_PARENT")
        self.assertEqual(result["aires_existantes"][0]["status"], "CONFLIT_PARENT_GRID3")

    def test_xlsx_parser_keeps_sparse_rows_and_shared_inline_values(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "fixture.xlsx"
            with zipfile.ZipFile(path, "w") as z:
                z.writestr("xl/workbook.xml", '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Source" sheetId="1" r:id="r1"/></sheets></workbook>')
                z.writestr("xl/_rels/workbook.xml.rels", '<Relationships><Relationship Id="r1" Target="worksheets/sheet1.xml"/></Relationships>')
                z.writestr("xl/sharedStrings.xml", '<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><si><t>UID</t></si></sst>')
                z.writestr("xl/worksheets/sheet1.xml", '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData><row r="2"><c r="A2" t="s"><v>0</v></c></row><row r="5"><c r="A5" t="inlineStr"><is><t>P0000000001</t></is></c><c r="C5"><v>12</v></c></row></sheetData></worksheet>')
            sheets = module.read_xlsx(path)
            self.assertEqual(sheets["Source"][1], {"row": 5, "values": ["P0000000001", None, "12"]})
            name, records = module.records_with_headers(sheets, {"UID"})
            self.assertEqual((name, records[0]["_row"], records[0]["UID"]), ("Source", 5, "P0000000001"))

    def test_report_replay_preserves_files_and_rejects_overwrite(self):
        with tempfile.TemporaryDirectory() as temp:
            base = Path(temp)
            source = base / "source.xlsx"
            source.write_bytes(b"original")
            output = base / "report"
            report = {"summary": {"written": False}, "rows": [{"id": 1}]}
            module.save_report(output, report, [source])
            before = {p.name: (p.read_bytes(), p.stat().st_mtime_ns) for p in output.iterdir()}
            module.save_report(output, report, [source])
            self.assertEqual(before, {p.name: (p.read_bytes(), p.stat().st_mtime_ns) for p in output.iterdir()})
            with self.assertRaises(ValueError): module.save_report(output, {"rows": [{"id": 2}]}, [source])
            with self.assertRaises(ValueError): module.save_report(base, report, [source])
            self.assertEqual(source.read_bytes(), b"original")


if __name__ == "__main__":
    unittest.main()
