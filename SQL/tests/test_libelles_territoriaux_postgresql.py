"""Libellés hiérarchiques : PostgreSQL privé et vraies API, sans repli source.

Les fixtures et le DDL sont annulés à la fin de la classe. Les identifiants
fictifs négatifs évitent de consommer ou de réinitialiser les séquences.
"""
import os
from pathlib import Path
import re
import sys
import unittest
from urllib.parse import unquote, urlsplit
import uuid

DSN = os.environ.get('SAUVERNDEKO_TEST_DATABASE_URL', '')
TARGET = urlsplit(DSN)
DATABASE = unquote(TARGET.path.lstrip('/'))
if TARGET.hostname not in {'localhost', '127.0.0.1', '::1'} or not DATABASE.startswith('sauverndeko_test_'):
    raise RuntimeError('Copie privée locale sauverndeko_test_* obligatoire ; aucun repli source.')
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'backend'))
os.environ.update(DATABASE_URL=DSN, DJANGO_SETTINGS_MODULE='config.settings', SAUVERNDEKO_DB_READ_ONLY='0')

import django
django.setup()
from django.db import connection, transaction
from django.test import override_settings
from rest_framework.test import APIClient
from apps.accounts.authentication import Actor
from apps.core import db
from apps.core.entity_locations import geographical_references

MIGRATION = ROOT / 'backend/database/migrations/20261104_06_libelles_territoriaux.sql'
ROLLBACK = ROOT / 'backend/database/migrations/rollback/20261104_06_libelles_territoriaux.sql'
PARENTS = {1: 'ID_Niveau_0_Fk', 2: 'ID_Niveau_1_FK', 3: 'ID_Niveau_2_FK', 4: 'ID_Niveau_3_Fk'}
TYPE_FIELDS = {2: 'ID_TypeNiveau_2_Fk', 3: 'ID_TypeNiveau_2_Fk', 4: 'ID_TypeNiveau_4_Fk', 5: 'ID_TypeNiveau_5_Fk'}
BASE = '/api/geolocalisation/territoires/references/'


def execute_migration(path):
    body = re.sub(r'^(BEGIN|COMMIT);\s*$', '', path.read_text(encoding='utf8'), flags=re.M)
    # Pas de tuple de paramètres : les pourcentages éventuels du SQL restent du SQL.
    with connection.cursor() as cursor:
        cursor.execute(body)


class TerritorialChoiceLabels(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        actual = db.one('SELECT current_database() AS name')['name']
        if actual != DATABASE or not actual.startswith('sauverndeko_test_'):
            raise RuntimeError('Identité PostgreSQL privée incohérente ; recette interrompue.')
        cls.override = override_settings(ALLOWED_HOSTS=['testserver'])
        cls.override.enable()
        cls.outer = transaction.atomic()
        cls.outer.__enter__()
        try:
            execute_migration(MIGRATION)
            cls.user = db.one('SELECT * FROM systeme."T_Utilisateurs" WHERE "Is_Admin" IS TRUE AND "ValideUser" IS TRUE ORDER BY "IdUser" LIMIT 1')
            if not cls.user:
                raise RuntimeError('Un compte global actif de la copie privée est nécessaire à la recette API.')
        except Exception:
            transaction.set_rollback(True)
            cls.outer.__exit__(*sys.exc_info())
            cls.override.disable()
            raise

    @classmethod
    def tearDownClass(cls):
        transaction.set_rollback(True)
        cls.outer.__exit__(None, None, None)
        cls.override.disable()
        super().tearDownClass()

    def setUp(self):
        self.tx = transaction.atomic()
        self.tx.__enter__()
        self.addCleanup(self.rollback_fixture)
        self.next_id = -1_000_000_000 - int(uuid.uuid4().hex[:6], 16)
        self.tag = uuid.uuid4().hex[:12]
        self.types = {}
        # Les fixtures respectent les familles effectives et les gardes SQL ;
        # une famille fictive ne peut pas être injectée dans une FK cataloguée.
        families = {}
        for level in range(2,6):
            resolved = db.one('SELECT referentiel.fn_categories_champ(%s,%s,%s,NULL) AS ids',
                ['geolocalisation', f'T_Niveau_{level}', TYPE_FIELDS[level]])['ids']
            family = db.one('SELECT "ID_CategorieGenerique" AS id FROM referentiel."T_CategorieGenerique" WHERE "ID_CategorieGenerique"=ANY(%s::integer[]) AND "IdEntiteFk" IS NULL AND "ValideCategorieGenerique" IS TRUE ORDER BY "ID_CategorieGenerique" LIMIT 1', [resolved])
            self.assertIsNotNone(family, f'Famille territoriale active absente pour N{level}.')
            families[level] = family['id']
        for level, abbreviations in ((2, ('Ant PEV','Secteur')), (3, ('ZS','BCZS','Secteur')), (4, ('AS',)), (5, ('CS',))):
            for abbreviation in abbreviations:
                existing = db.one('SELECT "ID_Generique" AS id FROM referentiel."T_Generique" WHERE "ID_CategorieGeneriqueFk"=%s AND "AbrGenerique"=%s AND "IdEntiteFk" IS NULL AND "ValideGenerique" IS TRUE ORDER BY "ID_Generique" LIMIT 1', [families[level], abbreviation])
                if existing:
                    identifier = existing['id']
                    db.query('UPDATE referentiel."T_Generique" SET "NomGenerique"=%s,' + db.ident(f'VisibleNiveau_{level}') + '=true WHERE "ID_Generique"=%s', ['Nom long distinct '+abbreviation+' '+str(level)+' '+self.tag, identifier])
                else:
                    identifier = self.insert('referentiel', 'T_Generique', 'ID_Generique', {
                        'ID_CategorieGeneriqueFk': families[level], 'NomGenerique': 'Nom long distinct '+abbreviation+' '+str(level)+' '+self.tag,
                        'AbrGenerique': abbreviation, 'ValideGenerique': True, f'VisibleNiveau_{level}': True,
                    })
                self.types[level, abbreviation] = identifier
        self.blank_type = self.insert('referentiel', 'T_Generique', 'ID_Generique', {
            'ID_CategorieGeneriqueFk': families[3], 'NomGenerique': 'Nom long sans abréviation ' + self.tag,
            'AbrGenerique': None, 'ValideGenerique': True,
        })
        self.ids = {}
        self.ids[0] = self.level(0, 'République démocratique du Congo ' + self.tag, iso=' COD ')
        self.ids[1] = self.level(1, 'Province fictive ' + self.tag, parent=self.ids[0])
        self.ids[2] = self.level(2, 'Antenne fictive ' + self.tag, parent=self.ids[1], type_name='Ant PEV')
        self.ids[3] = self.level(3, 'Ngiri Ngiri ' + self.tag, parent=self.ids[2], type_name='ZS')
        self.ids[4] = self.level(4, 'Aire fictive ' + self.tag, parent=self.ids[3], type_name='AS')
        self.ids[5] = self.level(5, 'Site fictif ' + self.tag, zone=self.ids[3], area=self.ids[4], type_name='CS')
        self.expected = {
            0: 'COD', 1: 'COD / Province fictive ' + self.tag,
        }
        for level, abbreviation, name in ((2, 'Ant PEV', 'Antenne fictive'), (3, 'ZS', 'Ngiri Ngiri'), (4, 'AS', 'Aire fictive'), (5, 'CS', 'Site fictif')):
            self.expected[level] = self.expected[level-1] + ' / ' + abbreviation + ' - ' + name + ' ' + self.tag

    def rollback_fixture(self):
        transaction.set_rollback(True)
        self.tx.__exit__(None, None, None)

    def insert(self, schema, table, primary, values):
        self.next_id -= 1
        fields = {primary: self.next_id, **values}
        statement = ('INSERT INTO ' + db.qualified(schema, table) + ' (' + ','.join(map(db.ident, fields))
            + ') OVERRIDING SYSTEM VALUE VALUES (' + ','.join(['%s']*len(fields)) + ') RETURNING ' + db.ident(primary) + ' AS id')
        return db.one(statement, list(fields.values()))['id']

    def level(self, level, name, parent=None, type_name=None, zone=None, area=None, **extra):
        values = {f'NomNiveau_{level}': name, **extra}
        if parent is not None:
            values[PARENTS[level]] = parent
        if type_name is not None:
            values[TYPE_FIELDS[level]] = self.types[level, type_name]
        if level == 5:
            values.update(ID_Niveau_3_Fk=zone, ID_Niveau_4_Fk=area)
        return self.insert('geolocalisation', f'T_Niveau_{level}', f'ID_Niveau_{level}', values)

    def choice(self, level, identifier=None):
        result = db.one('SELECT * FROM geolocalisation."V_ChoixTerritorial" WHERE niveau=%s AND id=%s', [level, self.ids[level] if identifier is None else identifier])
        self.assertIsNotNone(result)
        return result

    def actor(self, read=True):
        actor = Actor(dict(self.user))
        actor._module_access = {'modules': {name: {'canRead': read, 'canManage': True, 'canExport': True, 'reason': 'MODULE_ROLE_FORBIDDEN'}
            for name in ('territoires', 'administration', 'logistique')}}
        return actor

    def client(self, read=True):
        client = APIClient()
        client.force_authenticate(self.actor(read))
        return client

    def response_data(self, response):
        self.assertEqual(response.status_code, 200, getattr(response, 'data', None))
        return response.json()['data']

    def test_01_complete_paths_use_iso_and_every_real_type(self):
        # La visibilité gouverne les nouvelles saisies, pas le libellé d'une
        # affectation déjà enregistrée. Aucune garde n'est désactivée.
        for (level, abbreviation), identifier in self.types.items():
            db.query('UPDATE referentiel."T_Generique" SET ' + db.ident(f'VisibleNiveau_{level}') + '=false WHERE "ID_Generique"=%s', [identifier])
        for level in range(6):
            with self.subTest(level=level):
                row = self.choice(level)
                self.assertEqual(row['label'], self.expected[level])
                self.assertIs(type(row['id']), int)
                self.assertNotIn('République démocratique', row['label'])
                self.assertNotIn('Nom long distinct', row['label'])
        self.assertEqual(self.choice(5)['parentId'], self.ids[4])
        self.assertEqual(self.choice(5)['parentNiveau'], 4)

    def test_02_same_name_is_distinguished_by_real_type(self):
        choices = [self.ids[3]]
        for type_name in ('BCZS', 'Secteur'):
            choices.append(self.level(3, 'Ngiri Ngiri ' + self.tag, parent=self.ids[2], type_name=type_name))
        labels = [self.choice(3, identifier)['label'] for identifier in choices]
        self.assertEqual(len(set(labels)), 3)
        self.assertTrue(labels[0].endswith('ZS - Ngiri Ngiri ' + self.tag))
        self.assertTrue(labels[1].endswith('BCZS - Ngiri Ngiri ' + self.tag))
        self.assertTrue(labels[2].endswith('Secteur - Ngiri Ngiri ' + self.tag))

    def test_03_reference_rename_is_live_and_does_not_change_fk(self):
        abbreviation = 'ZONE-' + self.tag
        db.query('UPDATE referentiel."T_Generique" SET "AbrGenerique"=%s WHERE "ID_Generique"=%s', [abbreviation, self.types[3, 'ZS']])
        self.assertIn('/ ' + abbreviation + ' - Ngiri Ngiri ', self.choice(5)['label'])
        physical = db.one('SELECT "ID_TypeNiveau_2_Fk" AS type FROM geolocalisation."T_Niveau_3" WHERE "ID_Niveau_3"=%s', [self.ids[3]])
        self.assertEqual(physical['type'], self.types[3, 'ZS'])

    def test_04_missing_iso_type_and_name_have_neutral_identifiable_fallback(self):
        db.query('UPDATE geolocalisation."T_Niveau_0" SET iso=NULL WHERE "ID_Niveau_0"=%s', [self.ids[0]])
        self.assertEqual(self.choice(0)['label'], f'Pays #{self.ids[0]} (ISO absent)')
        db.query('UPDATE geolocalisation."T_Niveau_3" SET "ID_TypeNiveau_2_Fk"=%s,"NomNiveau_3"=NULL WHERE "ID_Niveau_3"=%s', [self.blank_type, self.ids[3]])
        label = self.choice(3)['label']
        self.assertTrue(label.endswith(f'Type #{self.blank_type} - Sans nom #{self.ids[3]}'))
        self.assertNotIn('Nom long sans abréviation', label)
        self.assertNotIn('République démocratique', label)
        without_type = self.level(3, 'Sans type ' + self.tag, parent=self.ids[2])
        self.assertTrue(self.choice(3, without_type)['label'].endswith('Niveau 3 - Sans type ' + self.tag))

    def test_05_missing_parents_do_not_remove_rows_or_invent_ancestors(self):
        for level in range(1,6):
            identifier = self.level(level, 'Sans parent ' + self.tag, type_name={2:'Secteur',3:'ZS',4:'AS',5:'CS'}.get(level))
            with self.subTest(level=level):
                row = self.choice(level, identifier)
                self.assertIsNone(row['parentId'])
                self.assertNotIn('COD', row['label'])
                self.assertNotIn('Province fictive', row['label'])
                self.assertIn('Sans parent ' + self.tag, row['label'])
        destination = db.one('SELECT "EstCoherente" AS coherent FROM geolocalisation."V_DestinationLogistique" WHERE id=%s', [identifier])
        self.assertFalse(destination['coherent'])

    def test_06_direct_zone_and_area_inheritance_remain_different_real_paths(self):
        direct = self.level(5, 'Direct ' + self.tag, zone=self.ids[3], type_name='CS')
        via_area = self.level(5, 'Hérité ' + self.tag, area=self.ids[4], type_name='CS')
        self.assertEqual(self.choice(5, direct)['label'], self.expected[3] + ' / CS - Direct ' + self.tag)
        self.assertEqual(self.choice(5, direct)['parentId'], self.ids[3])
        self.assertEqual(self.choice(5, direct)['parentNiveau'], 3)
        self.assertEqual(self.choice(5, via_area)['label'], self.expected[4] + ' / CS - Hérité ' + self.tag)
        self.assertEqual(self.choice(5, via_area)['parentId'], self.ids[4])
        for identifier in (direct, via_area):
            self.assertTrue(db.one('SELECT "EstCoherente" AS coherent FROM geolocalisation."V_DestinationLogistique" WHERE id=%s', [identifier])['coherent'])

    def test_07_inconsistent_area_is_marked_without_false_breadcrumb_or_rewrite(self):
        other_zone = self.level(3, 'Autre zone ' + self.tag, parent=self.ids[2], type_name='BCZS')
        identifier = self.level(5, 'Ancien conflit ' + self.tag, zone=other_zone, area=self.ids[4], type_name='CS')
        label = self.choice(5, identifier)['label']
        self.assertIn('BCZS - Autre zone ' + self.tag, label)
        self.assertNotIn('AS - Aire fictive', label)
        self.assertIn('(aire hors zone)', label)
        self.assertFalse(db.one('SELECT "EstCoherente" AS coherent FROM geolocalisation."V_DestinationLogistique" WHERE id=%s', [identifier])['coherent'])
        physical = db.one('SELECT "ID_Niveau_3_Fk" AS zone,"ID_Niveau_4_Fk" AS area FROM geolocalisation."T_Niveau_5" WHERE "ID_Niveau_5"=%s', [identifier])
        self.assertEqual(physical, {'zone': other_zone, 'area': self.ids[4]})

    def test_08_every_physical_row_has_one_composite_identity(self):
        self.assertEqual(db.one('SELECT count(*) AS n FROM (SELECT niveau,id FROM geolocalisation."V_ChoixTerritorial" GROUP BY niveau,id HAVING count(*)<>1) duplicates')['n'], 0)
        for level in range(6):
            actual = db.one('SELECT count(*) AS n FROM geolocalisation."V_ChoixTerritorial" WHERE niveau=%s', [level])['n']
            expected = db.one('SELECT count(*) AS n FROM geolocalisation.' + db.ident(f'T_Niveau_{level}'))['n']
            self.assertEqual(actual, expected)

    def test_09_replay_rollback_preserve_tables_and_destination_nonlabel_contract(self):
        def fingerprints():
            return {level: db.one('SELECT md5(COALESCE(jsonb_agg(to_jsonb(n) ORDER BY ' + db.ident(f'ID_Niveau_{level}') + "),'[]'::jsonb)::text) AS hash FROM geolocalisation." + db.ident(f'T_Niveau_{level}') + ' n')['hash'] for level in range(6)}
        def destinations():
            return db.query('SELECT id,"NomNiveau_5","CodeNiveau_5","ID_Niveau_3_Fk","ID_Niveau_4_Fk","EstCoherente" FROM geolocalisation."V_DestinationLogistique" ORDER BY id')
        before, rows = fingerprints(), destinations()
        columns = db.query("SELECT column_name,data_type FROM information_schema.columns WHERE table_schema='geolocalisation' AND table_name='V_DestinationLogistique' ORDER BY ordinal_position")
        execute_migration(MIGRATION)
        execute_migration(MIGRATION)
        self.assertEqual(destinations(), rows)
        execute_migration(ROLLBACK)
        self.assertIsNone(db.one("SELECT to_regclass('geolocalisation.\"V_ChoixTerritorial\"') AS name")['name'])
        self.assertEqual(destinations(), rows)
        self.assertEqual(fingerprints(), before)
        execute_migration(MIGRATION)
        self.assertEqual(destinations(), rows)
        self.assertEqual(fingerprints(), before)
        self.assertEqual(db.query("SELECT column_name,data_type FROM information_schema.columns WHERE table_schema='geolocalisation' AND table_name='V_DestinationLogistique' ORDER BY ordinal_position"), columns)
        self.assertEqual(self.choice(5)['label'], self.expected[5])

    def test_10_territory_reference_api_keeps_full_labels_numeric_ids_and_parent_fields(self):
        client = self.client()
        for kind in ('niveaux2', 'niveaux3', 'niveaux4', 'niveaux5'):
            support = self.response_data(client.get(BASE + kind))
            for level in range(5):
                row = next(item for item in support['options']['niveaux'+str(level)] if item['id'] == self.ids[level])
                self.assertEqual(row['label'], self.expected[level])
                self.assertIs(type(row['id']), int)
                if level:
                    self.assertEqual(row['parentId'], self.ids[level-1])
                    self.assertEqual(row['parentKey'], PARENTS[level])
                    self.assertEqual(row[PARENTS[level]], self.ids[level-1])
                else:
                    self.assertIsNone(row['parentId'])

    def test_11_company_location_service_and_creation_api_share_labels_and_parents(self):
        inherited = self.level(5, 'Localisation héritée ' + self.tag, area=self.ids[4], type_name='CS')
        for references in (geographical_references(), self.response_data(self.client().get('/api/systeme/entites/identite-defaut'))['references']):
            for level in (3,4,5):
                row = next(item for item in references['niveaux'+str(level)] if item['id'] == self.ids[level])
                self.assertEqual(row['label'], self.expected[level])
                self.assertIs(type(row['id']), int)
                if level >= 4:
                    self.assertEqual(row['parent3'], self.ids[3])
                if level == 5:
                    self.assertEqual(row['parent4'], self.ids[4])
            row = next(item for item in references['niveaux5'] if item['id'] == inherited)
            self.assertEqual(row['parent3'], self.ids[3])
            self.assertEqual(row['parent4'], self.ids[4])
            self.assertEqual(row['label'], self.expected[4] + ' / CS - Localisation héritée ' + self.tag)

    def test_12_reference_api_permissions_are_not_bypassed_by_label_view(self):
        self.assertEqual(APIClient().get(BASE+'niveaux2').status_code, 401)
        self.assertEqual(self.client(read=False).get(BASE+'niveaux2').status_code, 403)
        self.assertEqual(APIClient().get('/api/systeme/entites/identite-defaut').status_code, 401)
        self.assertEqual(self.client(read=False).get('/api/systeme/entites/identite-defaut').status_code, 403)

    def test_13_shared_view_is_documented_without_public_select_grant(self):
        comments = db.query("SELECT col_description(a.attrelid,a.attnum) AS comment FROM pg_attribute a WHERE a.attrelid='geolocalisation.\"V_ChoixTerritorial\"'::regclass AND a.attnum>0 AND NOT a.attisdropped")
        self.assertEqual(len(comments), 7)
        self.assertTrue(all(row['comment'] for row in comments))
        self.assertTrue(db.one("SELECT obj_description('geolocalisation.\"V_ChoixTerritorial\"'::regclass,'pg_class') AS comment")['comment'])
        grants = db.query("SELECT a.privilege_type FROM pg_class c CROSS JOIN LATERAL aclexplode(COALESCE(c.relacl,acldefault('r',c.relowner))) a WHERE c.oid='geolocalisation.\"V_ChoixTerritorial\"'::regclass AND a.grantee=0")
        self.assertEqual(grants, [])


if __name__ == '__main__':
    unittest.main(verbosity=2)
