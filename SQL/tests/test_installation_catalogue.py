"""Contrat du seed d'applications : indépendant du heap, sans requête source."""
import json
import os
from pathlib import Path
import re
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0,str(Path(__file__).resolve().parents[2]/"backend"))
os.environ.setdefault("DJANGO_SETTINGS_MODULE","config.settings")
import django
django.setup()
from django.core.management.base import CommandError
from apps.core.management.commands.preparer_installation import application_catalogue_seed


class ApplicationCatalogueSeed(unittest.TestCase):
    def seed(self,rows):
        with patch("apps.core.management.commands.preparer_installation.db.query",return_value=[{"payload":row} for row in rows]):
            return application_catalogue_seed()

    @staticmethod
    def rows(text):
        return [json.loads(value.replace("''","'")) for value in re.findall(
            r'jsonb_populate_record\(NULL::systeme\."T_ModuleApplication",\'((?:[^\']|\'\')*)\'::jsonb\);',text)]

    def test_parents_before_children_even_with_opposite_physical_order(self):
        rows=[
            {"CodeModule":"child","Nom":"Enfant","CodeIncluant":"middle","ModuleParentCode":None,"Ordre":1},
            {"CodeModule":"function","Nom":"Fonction","CodeIncluant":None,"ModuleParentCode":"root","Ordre":0},
            {"CodeModule":"middle","Nom":"Module inclus","CodeIncluant":"root","ModuleParentCode":None,"Ordre":5},
            {"CodeModule":"root","Nom":"Parent","CodeIncluant":None,"ModuleParentCode":None,"Ordre":10},
        ]
        text,count=self.seed(rows)
        ordered=self.rows(text)
        keys=[row["CodeModule"] for row in ordered]
        self.assertEqual(count,4)
        self.assertLess(keys.index("root"),keys.index("middle"))
        self.assertLess(keys.index("middle"),keys.index("child"))
        self.assertLess(keys.index("root"),keys.index("function"))
        self.assertEqual({row["CodeModule"]:row for row in ordered},{row["CodeModule"]:row for row in rows})
        self.assertNotIn("DISABLE TRIGGER",text)

    def test_cycles_and_missing_parents_refuse_export(self):
        for rows in [
            [{"CodeModule":"child","CodeIncluant":"missing","Ordre":0}],
            [{"CodeModule":"a","CodeIncluant":"b","Ordre":0},{"CodeModule":"b","CodeIncluant":"a","Ordre":1}],
            [{"CodeModule":"self","ModuleParentCode":"self","Ordre":0}],
        ]:
            with self.subTest(rows=rows),self.assertRaises(CommandError):
                self.seed(rows)

    def test_labels_are_literal_data(self):
        value={"CodeModule":"root","Nom":"L'entreprise « Exemple »","Ordre":1}
        text,count=self.seed([value])
        self.assertEqual(count,1)
        self.assertEqual(self.rows(text),[value])
        self.assertIn("L''entreprise",text)
        self.assertIn("Catalogue des applications non vide",text)

    def test_empty_catalogue_remains_empty(self):
        text,count=self.seed([])
        self.assertEqual(count,0)
        self.assertEqual(self.rows(text),[])


if __name__=="__main__":
    unittest.main(verbosity=2)
