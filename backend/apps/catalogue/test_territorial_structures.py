from unittest.mock import patch

from django.test import SimpleTestCase

from apps.catalogue import territorial_structures as directory
from apps.core.responses import APIError
from apps.core.territorial_portal import validate_body


class TerritorialStructuresTests(SimpleTestCase):
    def test_level_two_filter_and_unpublished_levels(self):
        where, parameters = directory.selection({"level": "2"})
        self.assertIn('v."NiveauStructure"=%s', where)
        self.assertEqual(parameters, [2])
        for excluded in (1, 6):
            with self.subTest(excluded=excluded), self.assertRaises(APIError):
                directory.selection({"level": str(excluded)})

    def test_level_two_publication_can_be_disabled_in_the_editor(self):
        current = {"NomNiveau_2": "Buta", "PublierDansAnnuaire": True}
        changes = validate_body("niveaux2", {"PublierDansAnnuaire": False}, current)
        self.assertEqual(changes, {"PublierDansAnnuaire": False})

    @patch.object(directory, "can_manage_territories", return_value=False)
    @patch.object(directory.db, "one")
    def test_level_two_detail_has_position_without_private_contacts(self, query, management):
        query.return_value = {
            "StructureKey": "n2:17",
            "NiveauStructure": 2,
            "ID_Structure": 17,
            "NomStructure": "Buta",
            "ID_TypeStructureFk": 32,
            "TypeStructure": "Ant PEV",
            "latitude": 2.78,
            "longitude": 24.73,
            "CoordonneesPubliees": False,
        }
        record = directory.detail(object(), 2, 17)["record"]
        self.assertEqual(query.call_args.args[1], [2, 17])
        self.assertEqual(record["type"], "Ant PEV")
        self.assertEqual(record["position"], {"latitude": 2.78, "longitude": 24.73})
        self.assertFalse(record["contactsPublished"])
        self.assertIsNone(record["address"])
        self.assertIsNone(record["phone"])
