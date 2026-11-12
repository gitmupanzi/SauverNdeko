"""Annuaire sanitaire : données fictives et PostgreSQL privé local obligatoires."""
import os
from pathlib import Path
import unittest
from urllib.parse import urlsplit
import uuid

import psycopg
from psycopg import sql
from psycopg.rows import dict_row

DSN = os.environ.get('SAUVERNDEKO_TEST_DATABASE_URL', '')
location = urlsplit(DSN)
if location.hostname not in {'localhost', '127.0.0.1', '::1'} or not location.path.lstrip('/').startswith('sauverndeko_test_'):
    raise RuntimeError('Base privée locale sauverndeko_test_* obligatoire, sans repli source.')
MIGRATION = Path(__file__).resolve().parents[2] / 'backend/database/migrations/20261104_01_annuaire_sanitaire_territorial.sql'
CONTACTS = ['AdresseTerritoire', 'TelephoneTerritoire', 'TelephoneSecondaireTerritoire',
            'EmailTerritoire', 'SiteWebTerritoire', 'InformationsAccueilTerritoire',
            'HorairesOuvertureTerritoire']
PUBLIC = ['StructureKey', 'NiveauStructure', 'ID_Structure', 'NomStructure', 'CodeStructure',
          'ID_TypeStructureFk', 'TypeStructure', 'ID_Niveau_1', 'NomNiveau_1', 'ID_Niveau_2',
          'NomNiveau_2', 'ID_Niveau_3', 'NomNiveau_3', 'ID_Niveau_4', 'NomNiveau_4',
          *CONTACTS, 'CoordonneesPubliees']


class SanitaryDirectorySQL(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.c = psycopg.connect(DSN, autocommit=True, row_factory=dict_row)
        actual = cls.c.execute('SELECT current_database() AS name').fetchone()['name']
        if actual != location.path.lstrip('/') or not actual.startswith('sauverndeko_test_'):
            raise RuntimeError('Identité de la base privée incohérente.')

    @classmethod
    def tearDownClass(cls):
        cls.c.close()

    def setUp(self):
        self.tx = self.c.transaction(); self.tx.__enter__()
        self.tag = uuid.uuid4().hex
        self.family = self.c.execute("SELECT referentiel.fn_categories_champ('geolocalisation','T_Niveau_5','ID_TypeNiveau_5_Fk',NULL) AS ids").fetchone()['ids'][0]
        self.types = {r['abbr']: r['id'] for r in self.c.execute('''SELECT "ID_Generique" AS id,"AbrGenerique" AS abbr
            FROM referentiel."T_Generique" WHERE "ID_CategorieGeneriqueFk"=%s AND "IdEntiteFk" IS NULL''', [self.family])}
        self.parents = {}
        self.parents[0] = self.insert('geolocalisation', 'T_Niveau_0', {'NomNiveau_0': 'Pays fictif '+self.tag}, 'ID_Niveau_0')
        self.parents[1] = self.insert('geolocalisation', 'T_Niveau_1', {'NomNiveau_1': 'Province fictive',
            'ID_Niveau_0_Fk': self.parents[0], 'VisibleNiveau_1': False, 'VisibleNiveau_5': False}, 'ID_Niveau_1')
        self.parents[2] = self.insert('geolocalisation', 'T_Niveau_2', {'NomNiveau_2': 'Subdivision fictive',
            'ID_Niveau_1_FK': self.parents[1]}, 'ID_Niveau_2')
        self.parents[3] = self.insert('geolocalisation', 'T_Niveau_3', {'NomNiveau_3': 'BCZS fictif',
            'ID_Niveau_2_FK': self.parents[2], 'ID_TypeNiveau_2_Fk': self.types['BCZS']}, 'ID_Niveau_3')
        self.parents[4] = self.insert('geolocalisation', 'T_Niveau_4', {'NomNiveau_4': 'DPS fictive',
            'ID_Niveau_3_Fk': self.parents[3], 'ID_TypeNiveau_4_Fk': self.types['DPS']}, 'ID_Niveau_4')
        self.parents[5] = self.insert('geolocalisation', 'T_Niveau_5', {'NomNiveau_5': 'Centre fictif',
            'ID_Niveau_4_Fk': self.parents[4], 'ID_TypeNiveau_5_Fk': self.types['CS']}, 'ID_Niveau_5')

    def tearDown(self):
        self.c.execute('ROLLBACK'); self.tx.__exit__(None, None, None)

    def insert(self, schema, table, values, key):
        statement = sql.SQL('INSERT INTO {}.{} ({}) OVERRIDING SYSTEM VALUE VALUES ({}) RETURNING {} AS id').format(
            sql.Identifier(schema), sql.Identifier(table), sql.SQL(',').join(map(sql.Identifier, values)),
            sql.SQL(',').join(sql.Placeholder() for _ in values), sql.Identifier(key))
        return self.c.execute(statement, list(values.values())).fetchone()['id']

    def record(self, level=5, identifier=None):
        key = f'n{level}:{self.parents[level] if identifier is None else identifier}'
        return self.c.execute('SELECT * FROM geolocalisation."V_StructureSanitairePublique" WHERE "StructureKey"=%s', [key]).fetchone()

    def contacts(self, level=5, **changes):
        values = {'ID_Niveau_'+str(level)+'Fk': self.parents[level], 'AdresseTerritoire': 'Adresse fictive',
            'TelephoneTerritoire': '+243000000001', 'TelephoneSecondaireTerritoire': '+243000000002',
            'EmailTerritoire': 'institution@example.invalid', 'SiteWebTerritoire': 'https://example.invalid',
            'InformationsAccueilTerritoire': 'Accueil déclaré', 'HorairesOuvertureTerritoire': 'Lundi : 8 h à 16 h', **changes}
        return self.insert('geolocalisation', 'T_CoordonneesTerritoire', values, 'ID_CoordonneesTerritoire')

    def test_01_closed_contract_composite_identity_and_no_gps_or_company(self):
        for level in (3, 4, 5):
            row = self.record(level)
            self.assertEqual(list(row), PUBLIC)
            self.assertEqual(row['StructureKey'], f'n{level}:{self.parents[level]}')
            self.assertEqual((row['NiveauStructure'], row['ID_Structure']), (level, self.parents[level]))
            self.assertIs(row['CoordonneesPubliees'], False)
            self.assertTrue(all(row[field] is None for field in CONTACTS))

    def test_02_hierarchy_comes_from_shared_views_and_supports_site_without_direct_zone(self):
        site = self.record()
        for level in (1, 2, 3, 4):
            self.assertEqual(site['ID_Niveau_'+str(level)], self.parents[level])
        self.assertIsNone(self.record(3)['ID_Niveau_4'])
        self.c.execute('UPDATE geolocalisation."T_Niveau_5" SET "ID_Niveau_4_Fk"=NULL,"ID_Niveau_3_Fk"=%s WHERE "ID_Niveau_5"=%s', [self.parents[3], self.parents[5]])
        self.assertEqual(self.record()['ID_Niveau_3'], self.parents[3])
        self.assertIsNone(self.record()['ID_Niveau_4'])

    def test_03_same_integer_in_three_levels_never_collides(self):
        identifier = 1900000000
        for level, field, typ in [(3, 'ID_TypeNiveau_2_Fk', 'BCZS'), (4, 'ID_TypeNiveau_4_Fk', 'DPS'), (5, 'ID_TypeNiveau_5_Fk', 'CS')]:
            self.insert('geolocalisation', 'T_Niveau_'+str(level), {'ID_Niveau_'+str(level): identifier,
                'NomNiveau_'+str(level): 'Homonyme fictif', field: self.types[typ]}, 'ID_Niveau_'+str(level))
        rows = self.c.execute('SELECT "StructureKey" FROM geolocalisation."V_StructureSanitairePublique" WHERE "ID_Structure"=%s ORDER BY "NiveauStructure"', [identifier]).fetchall()
        self.assertEqual([r['StructureKey'] for r in rows], [f'n{n}:{identifier}' for n in (3, 4, 5)])

    def test_04_private_contacts_do_not_leak_and_retraction_is_immediate(self):
        key = self.contacts()
        private = self.c.execute('SELECT * FROM geolocalisation."V_Niveau_5" WHERE "ID_Niveau_5"=%s', [self.parents[5]]).fetchone()
        self.assertEqual(private['AdresseTerritoire'], 'Adresse fictive')
        self.assertTrue(all(self.record()[field] is None for field in CONTACTS))
        self.c.execute('UPDATE geolocalisation."T_CoordonneesTerritoire" SET "PublierCoordonneesAnnuaire"=true WHERE "ID_CoordonneesTerritoire"=%s', [key])
        row = self.record()
        self.assertIs(row['CoordonneesPubliees'], True)
        for field in CONTACTS:
            self.assertEqual(row[field], private[field])
        self.c.execute('UPDATE geolocalisation."T_CoordonneesTerritoire" SET "PublierCoordonneesAnnuaire"=false WHERE "ID_CoordonneesTerritoire"=%s', [key])
        self.assertIsNotNone(self.record())
        self.assertTrue(all(self.record()[field] is None for field in CONTACTS))
        self.assertEqual(self.c.execute('SELECT "AdresseTerritoire" FROM geolocalisation."T_CoordonneesTerritoire" WHERE "ID_CoordonneesTerritoire"=%s', [key]).fetchone()['AdresseTerritoire'], 'Adresse fictive')

    def test_05_published_parent_contacts_are_not_inherited_by_site(self):
        self.contacts(3, PublierCoordonneesAnnuaire=True)
        self.assertEqual(self.record(3)['AdresseTerritoire'], 'Adresse fictive')
        self.assertIs(self.record()['CoordonneesPubliees'], False)
        self.assertTrue(all(self.record()[field] is None for field in CONTACTS))

    def test_06_activity_and_category_gate_records_without_legacy_flags(self):
        self.assertIsNotNone(self.record())
        for column in ('ValideGenerique',):
            self.c.execute(sql.SQL('UPDATE referentiel."T_Generique" SET {}=false WHERE "ID_Generique"=%s').format(sql.Identifier(column)), [self.types['CS']])
            self.assertIsNone(self.record())
            self.c.execute(sql.SQL('UPDATE referentiel."T_Generique" SET {}=true WHERE "ID_Generique"=%s').format(sql.Identifier(column)), [self.types['CS']])
        self.c.execute('UPDATE referentiel."T_CategorieGenerique" SET "ValideCategorieGenerique"=false WHERE "ID_CategorieGenerique"=%s', [self.family])
        self.assertIsNone(self.record())
        self.c.execute('UPDATE referentiel."T_CategorieGenerique" SET "ValideCategorieGenerique"=true WHERE "ID_CategorieGenerique"=%s', [self.family])
        self.c.execute('UPDATE referentiel."T_Generique" SET "VisibleNiveau_3"=false,"VisibleNiveau_4"=false,"VisibleNiveau_5"=false,"VisibleAll"=false WHERE "ID_Generique"=%s', [self.types['CS']])
        self.assertIsNotNone(self.record())

    def test_07_physical_field_mapping_changes_view_without_hardcoded_family(self):
        family = self.insert('referentiel', 'T_CategorieGenerique', {'NomCategorieGenerique': 'Famille fictive '+self.tag,
            'ValideCategorieGenerique': True}, 'ID_CategorieGenerique')
        typ = self.insert('referentiel', 'T_Generique', {'ID_CategorieGeneriqueFk': family, 'NomGenerique': 'Type fictif '+self.tag,
            'AbrGenerique': 'FICTIF-'+self.tag, 'ValideGenerique': True}, 'ID_Generique')
        field = self.c.execute('''SELECT * FROM referentiel."T_ChampReferentiel" WHERE "SchemaName"='geolocalisation'
            AND "TableName"='T_Niveau_5' AND "ColumnName"='ID_TypeNiveau_5_Fk' ''').fetchone()
        values = {'IdChampReferentielFk': field['ID_ChampReferentiel'], 'ModuleName': field['ModuleName'],
            'SchemaName': field['SchemaName'], 'SourceKey': 'champ.'+str(field['ID_ChampReferentiel']),
            'FieldName': field['ColumnName'], 'FieldLabel': field['ChampLabel'], 'MappingType': 'generic_category',
            'ReferenceSchemaName': 'referentiel', 'ReferenceObjectName': 'T_Generique', 'ReferenceFieldName': 'ID_Generique',
            'TargetCategoryIdFk': family, 'MappingValue': str(family), 'IsDefaultMapping': False,
            'SettingScope': 'global', 'DisplayOrder': 0}
        self.insert('systeme', 'T_Fk_Correspondance', values, 'IdFkCorrespondance')
        self.assertIsNone(self.record())
        self.c.execute('UPDATE geolocalisation."T_Niveau_5" SET "ID_TypeNiveau_5_Fk"=%s WHERE "ID_Niveau_5"=%s', [typ, self.parents[5]])
        self.assertEqual(self.record()['ID_TypeStructureFk'], typ)
        self.assertIsNotNone(self.record(3))

    def test_08_abbreviation_is_canonical_and_missing_abbreviation_stays_identifiable(self):
        self.c.execute('UPDATE referentiel."T_Generique" SET "NomGenerique"=%s,"AbrGenerique"=%s WHERE "ID_Generique"=%s',
            ['Nom différent '+self.tag, 'Abréviation fictive '+self.tag, self.types['CS']])
        self.assertEqual(self.record()['TypeStructure'], 'Abréviation fictive '+self.tag)
        self.c.execute('UPDATE referentiel."T_Generique" SET "AbrGenerique"=NULL WHERE "ID_Generique"=%s', [self.types['CS']])
        self.assertEqual(self.record()['TypeStructure'], 'Valeur sans abréviation #'+str(self.types['CS']))

    def test_09_all_territorial_types_remain_visible_and_existing_defaults_are_unchanged(self):
        typ = self.insert('referentiel', 'T_Generique', {'ID_CategorieGeneriqueFk': self.family,
            'NomGenerique': 'Nouveau type '+self.tag, 'AbrGenerique': 'NOUVEAU-'+self.tag}, 'ID_Generique')
        defaults = self.c.execute('SELECT "VisibleNiveau_3","VisibleNiveau_4","VisibleNiveau_5" FROM referentiel."T_Generique" WHERE "ID_Generique"=%s', [typ]).fetchone()
        self.assertEqual(defaults, {'VisibleNiveau_3': True, 'VisibleNiveau_4': True, 'VisibleNiveau_5': True})
        for abbr in ('District', 'Grp', 'Secteur'):
            self.c.execute('UPDATE geolocalisation."T_Niveau_5" SET "ID_TypeNiveau_5_Fk"=%s WHERE "ID_Niveau_5"=%s', [self.types[abbr], self.parents[5]])
            self.assertEqual(self.record()['TypeStructure'], abbr)
        for abbr in ('Pharmacie', 'Dépôt pharmaceutique'):
            self.assertIs(self.c.execute('SELECT "VisibleNiveau_5" FROM referentiel."T_Generique" WHERE "ID_Generique"=%s', [self.types[abbr]]).fetchone()['VisibleNiveau_5'], True)
        self.assertFalse(self.c.execute("SELECT EXISTS(SELECT FROM information_schema.columns WHERE table_schema='referentiel' AND table_name='T_Generique' AND column_name='InclureAnnuaireSanitaire') AS present").fetchone()['present'])

    def test_10_hours_accept_plain_multiline_text_and_reject_invalid_bounds(self):
        for raw in ('', ' leading', 'trailing ', 'x'*1001, 'x\x01y'):
            with self.assertRaises(psycopg.errors.CheckViolation):
                with self.c.transaction(): self.contacts(HorairesOuvertureTerritoire=raw)
        key = self.contacts(HorairesOuvertureTerritoire='Lundi\n'+'x'*994, PublierCoordonneesAnnuaire=True)
        self.assertEqual(len(self.record()['HorairesOuvertureTerritoire']), 1000)
        with self.assertRaises(psycopg.errors.NotNullViolation):
            with self.c.transaction():
                self.c.execute('UPDATE geolocalisation."T_CoordonneesTerritoire" SET "PublierCoordonneesAnnuaire"=NULL WHERE "ID_CoordonneesTerritoire"=%s', [key])

    def test_11_all_projection_columns_and_new_columns_have_comments(self):
        rows = self.c.execute('''SELECT c.relname,a.attname FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
            JOIN pg_attribute a ON a.attrelid=c.oid WHERE a.attnum>0 AND NOT a.attisdropped AND
            ((n.nspname='geolocalisation' AND c.relname='V_StructureSanitairePublique') OR
             (n.nspname='geolocalisation' AND c.relname IN ('T_CoordonneesTerritoire','V_Niveau_1','V_Niveau_2','V_Niveau_3','V_Niveau_4','V_Niveau_5')
              AND a.attname IN ('PublierCoordonneesAnnuaire','HorairesOuvertureTerritoire')))
            AND col_description(c.oid,a.attnum) IS NULL''').fetchall()
        self.assertEqual(rows, [])
        self.assertTrue(self.c.execute("SELECT obj_description('geolocalisation.\"V_StructureSanitairePublique\"'::regclass) AS value").fetchone()['value'])
        grants = self.c.execute('''SELECT p.privilege_type FROM pg_class c CROSS JOIN LATERAL aclexplode(c.relacl) p
            WHERE c.oid='geolocalisation."V_StructureSanitairePublique"'::regclass AND p.grantee=0''').fetchall()
        self.assertEqual(grants, [])

    def test_12_private_view_suffix_and_table_catalogue_are_optional(self):
        for level, suffix in enumerate(('un', 'deux', 'trois', 'quatre', 'cinq'), 1):
            columns = self.c.execute('SELECT column_name FROM information_schema.columns WHERE table_schema=\'geolocalisation\' AND table_name=%s ORDER BY ordinal_position', ['V_Niveau_'+str(level)]).fetchall()
            self.assertEqual([r['column_name'] for r in columns[-2:]], ['PublierCoordonneesAnnuaire', 'HorairesOuvertureTerritoire'])
            catalogue = self.c.execute('SELECT "Colonnes" FROM referentiel."T_InterfaceTableau" WHERE "CleInterface"=%s', ['territoires.niveaux-'+suffix]).fetchone()['Colonnes']
            for field in ('PublierCoordonneesAnnuaire', 'HorairesOuvertureTerritoire'):
                found = [column for column in catalogue if column['id'] == field]
                self.assertEqual(len(found), 1)
                self.assertIs(found[0]['defaultVisible'], False); self.assertIs(found[0]['defaultExport'], False)
                self.assertIs(found[0]['exportable'], True); self.assertIs(found[0]['tableAvailable'], True)
        reference_columns = self.c.execute('SELECT "Colonnes" FROM referentiel."T_InterfaceTableau" WHERE "CleInterface"=\'referentiels.valeurs\'').fetchone()['Colonnes']
        self.assertFalse(any(column['id'] == 'InclureAnnuaireSanitaire' for column in reference_columns))

    def test_13_replay_preserves_validity_visibility_rows_and_view_definitions(self):
        self.c.execute('UPDATE referentiel."T_Generique" SET "ValideGenerique"=false WHERE "ID_Generique"=%s', [self.types['CS']])
        self.c.execute('UPDATE referentiel."T_Generique" SET "VisibleNiveau_5"=false WHERE "ID_Generique"=%s', [self.types['Pharmacie']])
        self.contacts(PublierCoordonneesAnnuaire=True)
        def snapshot():
            tables = [('referentiel', 'T_Generique'), ('referentiel', 'T_InterfaceTableau'),
                ('geolocalisation', 'T_CoordonneesTerritoire'), *[('geolocalisation', 'T_Niveau_'+str(n)) for n in range(6)]]
            return [self.c.execute(sql.SQL("SELECT md5(coalesce(jsonb_agg(to_jsonb(t) ORDER BY to_jsonb(t)::text)::text,'[]')) AS value FROM {}.{} t").format(
                sql.Identifier(schema), sql.Identifier(table))).fetchone()['value'] for schema, table in tables]
        before = snapshot()
        view_sql = "SELECT relname,pg_get_viewdef(oid,true) AS definition FROM pg_class WHERE relkind='v' AND (relnamespace='geolocalisation'::regnamespace OR oid='referentiel.\"V_Generique\"'::regclass) ORDER BY relname"
        views = self.c.execute(view_sql).fetchall()
        statement = MIGRATION.read_text(encoding='utf8').replace('\nBEGIN;\n', '\n', 1).removesuffix('COMMIT;\n')
        for _ in range(2): self.c.execute(statement)
        self.assertEqual(before, snapshot())
        self.assertEqual(views, self.c.execute(view_sql).fetchall())
        self.assertIsNone(self.record())

    def test_14_pharmacy_seed_uses_configured_family_and_preserves_existing_flags(self):
        family = self.insert('referentiel', 'T_CategorieGenerique', {'NomCategorieGenerique': 'Famille pharmacie fictive '+self.tag,
            'ValideCategorieGenerique': True}, 'ID_CategorieGenerique')
        field = self.c.execute('''SELECT * FROM referentiel."T_ChampReferentiel" WHERE "SchemaName"='geolocalisation'
            AND "TableName"='T_Niveau_5' AND "ColumnName"='ID_TypeNiveau_5_Fk' ''').fetchone()
        self.insert('systeme', 'T_Fk_Correspondance', {'IdChampReferentielFk': field['ID_ChampReferentiel'],
            'ModuleName': field['ModuleName'], 'SchemaName': field['SchemaName'], 'SourceKey': 'champ.'+str(field['ID_ChampReferentiel']),
            'FieldName': field['ColumnName'], 'FieldLabel': field['ChampLabel'], 'MappingType': 'generic_category',
            'ReferenceSchemaName': 'referentiel', 'ReferenceObjectName': 'T_Generique', 'ReferenceFieldName': 'ID_Generique',
            'TargetCategoryIdFk': family, 'MappingValue': str(family), 'IsDefaultMapping': False,
            'SettingScope': 'global', 'DisplayOrder': 0}, 'IdFkCorrespondance')
        seed = MIGRATION.read_text(encoding='utf8').split('-- Types pharmaceutiques', 1)[1]
        seed = seed[seed.index('DO $$'):seed.index('ALTER TABLE geolocalisation."T_CoordonneesTerritoire"')]
        self.c.execute(seed)
        rows = self.c.execute('''SELECT "ID_Generique","NomGenerique","VisibleNiveau_3","VisibleNiveau_4","VisibleNiveau_5"
            FROM referentiel."T_Generique" WHERE "ID_CategorieGeneriqueFk"=%s ORDER BY "NomGenerique"''', [family]).fetchall()
        self.assertEqual({row['NomGenerique'] for row in rows}, {'Pharmacie', 'Dépôt pharmaceutique'})
        self.assertTrue(all(row['VisibleNiveau_3'] and row['VisibleNiveau_4'] and row['VisibleNiveau_5'] for row in rows))
        self.c.execute('''UPDATE referentiel."T_Generique" SET "VisibleNiveau_5"=false,"ValideGenerique"=false,"AbrGenerique"='Abréviation conservée '||"ID_Generique"::text
            WHERE "ID_CategorieGeneriqueFk"=%s''', [family])
        before = self.c.execute('SELECT to_jsonb(g) FROM referentiel."T_Generique" g WHERE "ID_CategorieGeneriqueFk"=%s ORDER BY "ID_Generique"', [family]).fetchall()
        self.c.execute(seed)
        self.assertEqual(before, self.c.execute('SELECT to_jsonb(g) FROM referentiel."T_Generique" g WHERE "ID_CategorieGeneriqueFk"=%s ORDER BY "ID_Generique"', [family]).fetchall())


if __name__ == '__main__':
    unittest.main(verbosity=2)
