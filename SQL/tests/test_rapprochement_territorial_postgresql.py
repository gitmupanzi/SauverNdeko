"""Socle de rapprochement proposé : mutations uniquement sur copie privée locale.

SAUVERNDEKO_TEST_DATABASE_URL est obligatoire ; aucun repli vers SauverNdeko.
Les scénarios synthétiques se terminent par ROLLBACK, y compris les DDL de rejeu.
"""
import os
from pathlib import Path
import re
import unittest
from urllib.parse import urlsplit
import uuid

import psycopg
from psycopg import sql
from psycopg.rows import dict_row
from psycopg.types.json import Jsonb

DSN = os.environ.get('SAUVERNDEKO_TEST_DATABASE_URL', '')
LOCATION = urlsplit(DSN)
if LOCATION.hostname not in {'localhost', '127.0.0.1', '::1'} or not LOCATION.path.lstrip('/').startswith('sauverndeko_test_'):
    raise RuntimeError('Copie privée locale sauverndeko_test_* obligatoire ; aucun repli source.')
DIRECTORY = Path(__file__).resolve().parents[2] / 'backend/database/migrations'
MIGRATION = DIRECTORY / '20261104_02_rapprochement_territorial.sql'
ROLLBACK = DIRECTORY / 'rollback/20261104_02_rapprochement_territorial.sql'
NEW_TABLES = ['T_SourceRapprochementTerritorial', 'T_CorrespondanceTerritoriale', 'T_LienTerritorial']


def without_envelope(path):
    return re.sub(r'^(BEGIN|COMMIT);\s*$', '', path.read_text(encoding='utf8'), flags=re.M)


class TerritorialReconciliationSQL(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.c = psycopg.connect(DSN, autocommit=True, row_factory=dict_row)
        actual = cls.c.execute('SELECT current_database() AS name').fetchone()['name']
        if actual != LOCATION.path.lstrip('/') or not actual.startswith('sauverndeko_test_'):
            raise RuntimeError('Identité de la copie privée incohérente.')
        before = cls.territories_digest()
        cls.c.execute(MIGRATION.read_text(encoding='utf8'))
        if before != cls.territories_digest():
            raise AssertionError('La migration additive a modifié les territoires existants.')

    @classmethod
    def tearDownClass(cls):
        cls.c.close()

    @classmethod
    def territories_digest(cls):
        return [cls.c.execute(sql.SQL('SELECT count(*) AS count,md5(coalesce(string_agg(to_jsonb(t)::text,E\'\\n\' ORDER BY {}),\'\')) AS digest FROM geolocalisation.{} t').format(
            sql.Identifier(f'ID_Niveau_{level}'), sql.Identifier(f'T_Niveau_{level}'))).fetchone() for level in range(6)]

    def setUp(self):
        self.tx = self.c.transaction(); self.tx.__enter__()
        self.tag = uuid.uuid4().hex
        self.actor = self.c.execute('SELECT "IdUser" AS id FROM systeme."T_Utilisateurs" ORDER BY "IdUser" LIMIT 1').fetchone()['id']
        self.parents = None

    def tearDown(self):
        self.c.execute('ROLLBACK'); self.tx.__exit__(None, None, None)

    def insert(self, table, values, key):
        statement = sql.SQL('INSERT INTO geolocalisation.{} ({}) VALUES ({}) RETURNING {} AS id').format(
            sql.Identifier(table), sql.SQL(',').join(map(sql.Identifier, values)),
            sql.SQL(',').join(sql.Placeholder() for _ in values), sql.Identifier(key))
        return self.c.execute(statement, list(values.values())).fetchone()['id']

    def source(self, **changes):
        return self.insert(NEW_TABLES[0], {'CodeSource': 'TEST', 'VersionSource': self.tag,
            'Sha256Source': self.tag * 2, 'NomFichierSource': 'fictif.xlsx', **changes}, 'ID_SourceRapprochementTerritorial')

    def fixture(self):
        if self.parents:
            return self.parents
        self.parents = {}
        for level in (0, 1, 2, 3, 4, 5):
            fields = {f'NomNiveau_{level}': 'Fictif ' + self.tag}
            if level:
                parent_field = {1: 'ID_Niveau_0_Fk', 2: 'ID_Niveau_1_FK', 3: 'ID_Niveau_2_FK', 4: 'ID_Niveau_3_Fk', 5: 'ID_Niveau_3_Fk'}[level]
                fields[parent_field] = self.parents[{5: 3}.get(level, level - 1)]
            if level == 1:
                fields.update(VisibleNiveau_1=False, VisibleNiveau_5=False)
            if level in (4, 5):
                families = self.c.execute("SELECT referentiel.fn_categories_champ('geolocalisation','T_Niveau_5','ID_TypeNiveau_5_Fk',NULL) AS ids").fetchone()['ids']
                self.as_type = self.c.execute('SELECT "ID_Generique" AS id FROM referentiel."T_Generique" WHERE "ID_CategorieGeneriqueFk"=ANY(%s) AND "AbrGenerique"=\'AS\' AND "IdEntiteFk" IS NULL ORDER BY "ID_Generique" LIMIT 1', [families]).fetchone()['id']
                fields[f'ID_TypeNiveau_{level}_Fk'] = self.as_type
            if level == 3:
                fields['ID_TypeNiveau_2_Fk'] = self.type_id('BCZS', 3)
            self.parents[level] = self.insert(f'T_Niveau_{level}', fields, f'ID_Niveau_{level}')
        return self.parents

    def type_id(self, abbr, level):
        field = f'ID_TypeNiveau_{level}_Fk' if level in (4, 5) else 'ID_TypeNiveau_2_Fk'
        families = self.c.execute('SELECT referentiel.fn_categories_champ(%s,%s,%s,NULL) AS ids', ['geolocalisation', f'T_Niveau_{level}', field]).fetchone()['ids']
        return self.c.execute('SELECT "ID_Generique" AS id FROM referentiel."T_Generique" WHERE "ID_CategorieGeneriqueFk"=ANY(%s) AND "AbrGenerique"=%s AND "IdEntiteFk" IS NULL ORDER BY "ID_Generique" LIMIT 1', [families, abbr]).fetchone()['id']

    def correspondence(self, source=None, level=4, **changes):
        parents = self.fixture()
        return self.insert(NEW_TABLES[1], {'ID_SourceRapprochementFk': source or self.source(),
            'CleLigneSource': uuid.uuid4().hex, f'ID_Niveau_{level}Fk': parents[level],
            'Preuves': Jsonb({'methode': 'fixture exact', 'parent_verifie': True}), **changes}, 'ID_CorrespondanceTerritoriale')

    def confirmed(self):
        return {'Decision': 'confirmee', 'MotifDecision': 'Preuve fictive de recette', 'DecideParUserFk': self.actor}

    def link(self, source=None, **changes):
        parents = self.fixture()
        return self.insert(NEW_TABLES[2], {'ID_SourceRapprochementFk': source or self.source(),
            'CleLienSource': uuid.uuid4().hex, 'NatureLien': 'copie_n5_n4', 'DomaineLien': 'sanitaire',
            'ID_OrigineNiveau_5Fk': parents[5], 'ID_CibleNiveau_4Fk': parents[4],
            'Preuves': Jsonb({'methode': 'fixture exact', 'parent_verifie': True}), **changes}, 'ID_LienTerritorial')

    def zone(self, province=None):
        parents = self.fixture()
        parent = parents[2]
        if province is not None:
            parent = self.insert('T_Niveau_2', {'NomNiveau_2': 'Subdivision autre', 'ID_Niveau_1_FK': province}, 'ID_Niveau_2')
        return self.insert('T_Niveau_3', {'NomNiveau_3': 'ZS fictive ' + uuid.uuid4().hex,
            'ID_Niveau_2_FK': parent, 'ID_TypeNiveau_2_Fk': self.type_id('ZS', 3)}, 'ID_Niveau_3')

    def area_link(self, source, zone, **changes):
        return self.link(source, NatureLien='aire_de_zone', ID_OrigineNiveau_5Fk=None,
            ID_OrigineNiveau_4Fk=self.fixture()[4], ID_CibleNiveau_4Fk=None,
            ID_CibleNiveau_3Fk=zone, **changes)

    def pyramid_area(self):
        return self.c.execute('SELECT * FROM geolocalisation."V_PyramideSanitaireRapprochee" WHERE "ID_AireSante"=%s', [self.fixture()[4]]).fetchall()

    def rejected(self, statement, values=None):
        with self.assertRaises(psycopg.Error):
            with self.c.transaction():
                if callable(statement):
                    statement()
                else:
                    self.c.execute(statement, values)

    def test_01_three_additive_tables_comment_every_column(self):
        for table in NEW_TABLES:
            info = self.c.execute('''SELECT obj_description(c.oid,'pg_class') AS comment,
                bool_and(col_description(c.oid,a.attnum) IS NOT NULL) AS all_columns
                FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
                JOIN pg_attribute a ON a.attrelid=c.oid AND a.attnum>0 AND NOT a.attisdropped
                WHERE n.nspname='geolocalisation' AND c.relname=%s GROUP BY c.oid''', [table]).fetchone()
            self.assertTrue(info['comment']); self.assertIs(info['all_columns'], True)

    def test_02_one_source_hash_is_unique(self):
        self.source()
        self.rejected(lambda: self.source())

    def test_03_source_identity_and_provenance_are_immutable(self):
        identifier = self.source()
        self.rejected('UPDATE geolocalisation."T_SourceRapprochementTerritorial" SET "NomFichierSource"=\'autre.xlsx\' WHERE "ID_SourceRapprochementTerritorial"=%s', [identifier])
        self.rejected('DELETE FROM geolocalisation."T_SourceRapprochementTerritorial" WHERE "ID_SourceRapprochementTerritorial"=%s', [identifier])

    def test_04_exactly_one_real_local_fk(self):
        parents = self.fixture(); source = self.source()
        self.rejected(lambda: self.correspondence(source, ID_Niveau_3Fk=parents[3]))
        self.rejected(lambda: self.correspondence(source, ID_Niveau_4Fk=None))
        self.rejected(lambda: self.correspondence(source, ID_Niveau_4Fk=1900000000))

    def test_05_multiple_grid3_objects_can_point_to_one_area(self):
        source = self.source(CodeSource='GRID3')
        a = self.correspondence(source, Grid3Id='object-1', UidSNISSource='UID-area', **self.confirmed())
        b = self.correspondence(source, Grid3Id='object-2', UidSNISSource='UID-area', **self.confirmed())
        self.assertNotEqual(a, b)
        self.assertEqual(self.c.execute('SELECT count(*) AS n FROM geolocalisation."T_CorrespondanceTerritoriale" WHERE "ID_SourceRapprochementFk"=%s', [source]).fetchone()['n'], 2)

    def test_06_source_row_identity_deduplicates_replay(self):
        source = self.source(); self.correspondence(source, CleLigneSource='sheet:2')
        self.rejected(lambda: self.correspondence(source, CleLigneSource='sheet:2'))

    def test_07_conflicting_proposal_is_retained_but_not_confirmed(self):
        source = self.source(); identifier = self.correspondence(source, ConflitSource=True)
        self.rejected('UPDATE geolocalisation."T_CorrespondanceTerritoriale" SET "Decision"=\'confirmee\',"MotifDecision"=\'invalide\',"DecideParUserFk"=%s WHERE "ID_CorrespondanceTerritoriale"=%s', [self.actor, identifier])
        self.assertEqual(self.c.execute('SELECT "Decision" FROM geolocalisation."T_CorrespondanceTerritoriale" WHERE "ID_CorrespondanceTerritoriale"=%s', [identifier]).fetchone()['Decision'], 'proposee')

    def test_08_existing_target_uid_conflict_is_never_overwritten(self):
        self.fixture()
        self.c.execute('UPDATE geolocalisation."T_Niveau_4" SET "uidSNIS"=\'ExistingUID\' WHERE "ID_Niveau_4"=%s', [self.parents[4]])
        source = self.source(); self.correspondence(source, UidSNISSource='different')
        self.rejected(lambda: self.correspondence(source, UidSNISSource='different', **self.confirmed()))
        self.assertEqual(self.c.execute('SELECT "uidSNIS" FROM geolocalisation."T_Niveau_4" WHERE "ID_Niveau_4"=%s', [self.parents[4]]).fetchone()['uidSNIS'], 'ExistingUID')

    def test_09_existing_parent_uid_conflict_blocks_confirmation(self):
        self.fixture()
        self.c.execute('UPDATE geolocalisation."T_Niveau_3" SET "uidSNIS"=\'ZoneOld0001\' WHERE "ID_Niveau_3"=%s', [self.parents[3]])
        source = self.source()
        self.rejected(lambda: self.correspondence(source, UidZoneSource='zone-other', **self.confirmed()))

    def test_10_decision_requires_actor_reason_and_evidence(self):
        source = self.source()
        for changes in ({'DecideParUserFk': None}, {'MotifDecision': ''}, {'Preuves': Jsonb({})}):
            self.rejected(lambda changes=changes: self.correspondence(source, **{**self.confirmed(), **changes}))

    def test_11_final_decision_and_imported_proof_are_immutable(self):
        source = self.source(); identifier = self.correspondence(source)
        self.rejected('UPDATE geolocalisation."T_CorrespondanceTerritoriale" SET "NomSource"=\'replace\' WHERE "ID_CorrespondanceTerritoriale"=%s', [identifier])
        self.c.execute('UPDATE geolocalisation."T_CorrespondanceTerritoriale" SET "Decision"=\'refusee\',"MotifDecision"=\'ambigu\',"DecideParUserFk"=%s WHERE "ID_CorrespondanceTerritoriale"=%s', [self.actor, identifier])
        self.rejected('UPDATE geolocalisation."T_CorrespondanceTerritoriale" SET "Decision"=\'proposee\' WHERE "ID_CorrespondanceTerritoriale"=%s', [identifier])
        self.rejected('DELETE FROM geolocalisation."T_CorrespondanceTerritoriale" WHERE "ID_CorrespondanceTerritoriale"=%s', [identifier])

    def test_12_alias_same_type_parent_preserves_both_local_records(self):
        self.fixture(); before = self.territories_digest()
        self.link(**self.confirmed())
        self.assertEqual(before, self.territories_digest())

    def test_13_alias_cannot_merge_area_and_groupment_or_different_zone(self):
        self.fixture(); source = self.source()
        self.c.execute('UPDATE geolocalisation."T_Niveau_4" SET "ID_TypeNiveau_4_Fk"=NULL WHERE "ID_Niveau_4"=%s', [self.parents[4]])
        self.rejected(lambda: self.link(source, **self.confirmed()))
        self.c.execute('UPDATE geolocalisation."T_Niveau_4" SET "ID_TypeNiveau_4_Fk"=%s,"ID_Niveau_3_Fk"=NULL WHERE "ID_Niveau_4"=%s', [self.as_type, self.parents[4]])
        self.rejected(lambda: self.link(source, **self.confirmed()))

    def test_14_link_shapes_and_self_bureau_link_are_rejected(self):
        self.fixture(); source = self.source()
        self.rejected(lambda: self.link(source, ID_CibleNiveau_3Fk=self.parents[3]))
        self.rejected(lambda: self.link(source, NatureLien='bureau_de_zone', ID_OrigineNiveau_3Fk=self.parents[3], ID_OrigineNiveau_5Fk=None, ID_CibleNiveau_3Fk=self.parents[3], ID_CibleNiveau_4Fk=None))

    def test_15_cross_province_link_cannot_be_confirmed(self):
        parents = self.fixture(); source = self.source()
        self.c.execute('UPDATE geolocalisation."T_Niveau_3" SET "ID_TypeNiveau_2_Fk"=%s WHERE "ID_Niveau_3"=%s', [self.type_id('ZS', 3), parents[3]])
        p1 = self.insert('T_Niveau_1', {'NomNiveau_1': 'Autre province', 'ID_Niveau_0_Fk': parents[0], 'VisibleNiveau_1': False, 'VisibleNiveau_5': False}, 'ID_Niveau_1')
        p2 = self.insert('T_Niveau_2', {'NomNiveau_2': 'Autre antenne', 'ID_Niveau_1_FK': p1, 'ID_TypeNiveau_2_Fk': self.type_id('Ant PEV', 2)}, 'ID_Niveau_2')
        self.rejected(lambda: self.link(source, NatureLien='rattachement_sanitaire', ID_OrigineNiveau_5Fk=None, ID_OrigineNiveau_3Fk=parents[3], ID_CibleNiveau_4Fk=None, ID_CibleNiveau_2Fk=p2, **self.confirmed()))

    def test_16_same_province_antenna_link_does_not_change_physical_parent(self):
        parents = self.fixture(); source = self.source()
        self.c.execute('UPDATE geolocalisation."T_Niveau_3" SET "ID_TypeNiveau_2_Fk"=%s WHERE "ID_Niveau_3"=%s', [self.type_id('ZS', 3), parents[3]])
        second = self.insert('T_Niveau_2', {'NomNiveau_2': 'Ant PEV fictive', 'ID_Niveau_1_FK': parents[1], 'ID_TypeNiveau_2_Fk': self.type_id('Ant PEV', 2)}, 'ID_Niveau_2')
        self.link(source, NatureLien='rattachement_sanitaire', ID_OrigineNiveau_5Fk=None, ID_OrigineNiveau_3Fk=parents[3], ID_CibleNiveau_4Fk=None, ID_CibleNiveau_2Fk=second, **self.confirmed())
        self.assertEqual(self.c.execute('SELECT "ID_Niveau_2_FK" FROM geolocalisation."T_Niveau_3" WHERE "ID_Niveau_3"=%s', [parents[3]]).fetchone()['ID_Niveau_2_FK'], parents[2])

    def test_17_same_uid_different_local_identity_cannot_be_confirmed(self):
        self.fixture(); source = self.source()
        self.correspondence(source, UidSNISSource='globally-unique', **self.confirmed())
        self.rejected(lambda: self.correspondence(source, level=3, UidSNISSource='globally-unique', **self.confirmed()))

    def test_18_migration_replay_preserves_staged_decisions_and_territories(self):
        source = self.source(); identifier = self.correspondence(source, **self.confirmed())
        before = self.c.execute('SELECT * FROM geolocalisation."T_CorrespondanceTerritoriale" WHERE "ID_CorrespondanceTerritoriale"=%s', [identifier]).fetchone()
        territorial = self.territories_digest()
        self.c.execute(without_envelope(MIGRATION))
        self.assertEqual(before, self.c.execute('SELECT * FROM geolocalisation."T_CorrespondanceTerritoriale" WHERE "ID_CorrespondanceTerritoriale"=%s', [identifier]).fetchone())
        self.assertEqual(territorial, self.territories_digest())

    def test_19_rollback_empty_only_preserves_original_territories(self):
        before = self.territories_digest()
        self.c.execute(without_envelope(ROLLBACK))
        for table in NEW_TABLES:
            self.assertIsNone(self.c.execute('SELECT to_regclass(%s) AS relation', ['geolocalisation."'+table+'"']).fetchone()['relation'])
        self.assertIsNone(self.c.execute('SELECT to_regclass(\'geolocalisation."V_PyramideSanitaireRapprochee"\') AS relation').fetchone()['relation'])
        self.assertEqual(before, self.territories_digest())
        self.c.execute(without_envelope(MIGRATION))

    def test_20_rollback_refuses_to_erase_retained_sources(self):
        source = self.source()
        self.rejected(lambda: self.c.execute(without_envelope(ROLLBACK)))
        self.assertEqual(self.c.execute('SELECT count(*) AS n FROM geolocalisation."T_SourceRapprochementTerritorial" WHERE "ID_SourceRapprochementTerritorial"=%s', [source]).fetchone()['n'], 1)

    def test_21_same_province_wrong_antenna_type_is_rejected(self):
        parents = self.fixture(); source = self.source()
        self.c.execute('UPDATE geolocalisation."T_Niveau_3" SET "ID_TypeNiveau_2_Fk"=%s WHERE "ID_Niveau_3"=%s', [self.type_id('ZS', 3), parents[3]])
        self.rejected(lambda: self.link(source, NatureLien='rattachement_sanitaire', ID_OrigineNiveau_5Fk=None, ID_OrigineNiveau_3Fk=parents[3], ID_CibleNiveau_4Fk=None, ID_CibleNiveau_2Fk=parents[2], **self.confirmed()))

    def test_22_bureau_of_zone_is_explicit_and_keeps_both_distinct_records(self):
        parents = self.fixture(); source = self.source()
        zone = self.insert('T_Niveau_3', {'NomNiveau_3': 'Zone fictive', 'ID_Niveau_2_FK': parents[2], 'ID_TypeNiveau_2_Fk': self.type_id('ZS', 3)}, 'ID_Niveau_3')
        before = self.territories_digest()
        self.link(source, NatureLien='bureau_de_zone', ID_OrigineNiveau_5Fk=None, ID_OrigineNiveau_3Fk=parents[3], ID_CibleNiveau_4Fk=None, ID_CibleNiveau_3Fk=zone, **self.confirmed())
        self.assertEqual(before, self.territories_digest())

    def test_23_arbitrary_n3_types_cannot_be_confirmed_as_bureau_of_zone(self):
        parents = self.fixture(); source = self.source()
        zone = self.insert('T_Niveau_3', {'NomNiveau_3': 'Autre BCZS', 'ID_Niveau_2_FK': parents[2], 'ID_TypeNiveau_2_Fk': self.type_id('BCZS', 3)}, 'ID_Niveau_3')
        self.rejected(lambda: self.link(source, NatureLien='bureau_de_zone', ID_OrigineNiveau_5Fk=None, ID_OrigineNiveau_3Fk=parents[3], ID_CibleNiveau_4Fk=None, ID_CibleNiveau_3Fk=zone, **self.confirmed()))

    def test_24_zone_cannot_be_declared_the_bureau_of_another_zone(self):
        parents = self.fixture(); source = self.source()
        zone = self.insert('T_Niveau_3', {'NomNiveau_3': 'Zone distincte', 'ID_Niveau_2_FK': parents[2], 'ID_TypeNiveau_2_Fk': self.type_id('ZS', 3)}, 'ID_Niveau_3')
        self.rejected(lambda: self.link(source, NatureLien='bureau_de_zone', ID_OrigineNiveau_5Fk=None, ID_OrigineNiveau_3Fk=zone, ID_CibleNiveau_4Fk=None, ID_CibleNiveau_3Fk=parents[3], **self.confirmed()))

    def test_25_one_grid3_object_per_source_version_without_unique_area(self):
        source = self.source(CodeSource='GRID3')
        self.correspondence(source, Grid3Id='same-object')
        self.rejected(lambda: self.correspondence(source, Grid3Id='same-object'))
        second = self.source(CodeSource='GRID3', VersionSource='v2', Sha256Source=uuid.uuid4().hex*2)
        self.correspondence(second, Grid3Id='same-object')

    def test_26_area_zone_link_keeps_legacy_bureau_parent(self):
        parents = self.fixture(); source = self.source(); zone = self.zone()
        self.link(source, NatureLien='bureau_de_zone', ID_OrigineNiveau_5Fk=None,
            ID_OrigineNiveau_3Fk=parents[3], ID_CibleNiveau_4Fk=None, ID_CibleNiveau_3Fk=zone, **self.confirmed())
        self.area_link(source, zone, **self.confirmed())
        row = self.pyramid_area()[0]
        self.assertEqual((row['ID_ZoneSante'], row['ID_ParentPhysiqueAire'], row['NbBureauxZone']), (zone, parents[3], 1))
        self.assertEqual(self.c.execute('SELECT "ID_Niveau_3_Fk" FROM geolocalisation."T_Niveau_4" WHERE "ID_Niveau_4"=%s', [parents[4]]).fetchone()['ID_Niveau_3_Fk'], parents[3])

    def test_27_wrong_area_type_or_cross_province_is_never_confirmed(self):
        parents = self.fixture(); source = self.source(); zone = self.zone()
        self.c.execute('UPDATE geolocalisation."T_Niveau_4" SET "ID_TypeNiveau_4_Fk"=%s WHERE "ID_Niveau_4"=%s', [self.type_id('Grp', 4), parents[4]])
        self.rejected(lambda: self.area_link(source, zone, **self.confirmed()))
        self.c.execute('UPDATE geolocalisation."T_Niveau_4" SET "ID_TypeNiveau_4_Fk"=%s WHERE "ID_Niveau_4"=%s', [self.as_type, parents[4]])
        other = self.insert('T_Niveau_1', {'NomNiveau_1': 'Autre province', 'ID_Niveau_0_Fk': parents[0], 'VisibleNiveau_1': False, 'VisibleNiveau_5': False}, 'ID_Niveau_1')
        other_zone = self.zone(other)
        self.rejected(lambda: self.area_link(source, other_zone, **self.confirmed()))

    def test_28_area_link_cannot_contradict_confirmed_bureau_or_direct_zone(self):
        parents = self.fixture(); source = self.source(); zone = self.zone(); other = self.zone()
        self.link(source, NatureLien='bureau_de_zone', ID_OrigineNiveau_5Fk=None,
            ID_OrigineNiveau_3Fk=parents[3], ID_CibleNiveau_4Fk=None, ID_CibleNiveau_3Fk=zone, **self.confirmed())
        self.rejected(lambda: self.area_link(source, other, **self.confirmed()))
        self.c.execute('UPDATE geolocalisation."T_Niveau_4" SET "ID_Niveau_3_Fk"=%s WHERE "ID_Niveau_4"=%s', [zone, parents[4]])
        self.rejected(lambda: self.area_link(source, other, **self.confirmed()))

    def test_29_unlinked_zone_and_area_are_visible_without_invented_join(self):
        self.fixture(); zone = self.zone()
        row = self.pyramid_area()[0]
        self.assertIsNone(row['ID_ZoneSante']); self.assertIs(row['AireSansZoneRapprochee'], True)
        zs = self.c.execute('SELECT * FROM geolocalisation."V_PyramideSanitaireRapprochee" WHERE "ClePyramide"=%s', ['zs:'+str(zone)]).fetchone()
        self.assertIs(zs['ZoneSansAireRapprochee'], True); self.assertIsNone(zs['ID_AireSante'])

    def test_30_multiple_antennas_and_bureaux_never_multiply_area_rows(self):
        parents = self.fixture(); source = self.source(); zone = self.zone()
        self.area_link(source, zone, **self.confirmed())
        for index in range(2):
            bureau = parents[3] if index == 0 else self.insert('T_Niveau_3', {'NomNiveau_3': 'Bureau additionnel',
                'ID_Niveau_2_FK': parents[2], 'ID_TypeNiveau_2_Fk': self.type_id('BCZS', 3)}, 'ID_Niveau_3')
            self.link(source, NatureLien='bureau_de_zone', ID_OrigineNiveau_5Fk=None,
                ID_OrigineNiveau_3Fk=bureau, ID_CibleNiveau_4Fk=None, ID_CibleNiveau_3Fk=zone, **self.confirmed())
            antenna = self.insert('T_Niveau_2', {'NomNiveau_2': 'Antenne '+str(index), 'ID_Niveau_1_FK': parents[1],
                'ID_TypeNiveau_2_Fk': self.type_id('Ant PEV', 2)}, 'ID_Niveau_2')
            self.link(source, NatureLien='rattachement_sanitaire', ID_OrigineNiveau_5Fk=None,
                ID_OrigineNiveau_3Fk=zone, ID_CibleNiveau_4Fk=None, ID_CibleNiveau_2Fk=antenna, **self.confirmed())
        rows = self.pyramid_area(); self.assertEqual(len(rows), 1)
        self.assertEqual((rows[0]['NbAntennesCandidates'], rows[0]['NbConflitsAntenne'], rows[0]['NbBureauxZone']), (2, 2, 2))
        self.assertIsNone(rows[0]['ID_AntennePEV']); self.assertIsNone(rows[0]['NomAntennePEV'])

    def test_31_multiple_zone_candidates_remain_null_with_conflict_count(self):
        self.fixture(); source = self.source(); zone = self.zone(); other = self.zone()
        self.area_link(source, zone, **self.confirmed()); self.area_link(source, other, **self.confirmed())
        row = self.pyramid_area()[0]
        self.assertEqual((row['NbZonesCandidates'], row['NbConflitsZone']), (2, 2))
        self.assertIsNone(row['ID_ZoneSante']); self.assertIsNone(row['UidZoneSNIS'])

    def test_32_direct_zone_parent_and_duplicate_version_link_count_once(self):
        parents = self.fixture(); source = self.source(); zone = self.zone()
        self.c.execute('UPDATE geolocalisation."T_Niveau_4" SET "ID_Niveau_3_Fk"=%s WHERE "ID_Niveau_4"=%s', [zone, parents[4]])
        self.area_link(source, zone, **self.confirmed())
        second = self.source(VersionSource='v2', Sha256Source=uuid.uuid4().hex*2)
        self.area_link(second, zone, **self.confirmed())
        row = self.pyramid_area()[0]
        self.assertEqual((row['ID_ZoneSante'], row['NbZonesCandidates'], row['NbConflitsZone']), (zone, 1, 0))

    def test_33_pyramid_is_private_documented_and_without_inferred_gps(self):
        info = self.c.execute('''SELECT obj_description(c.oid,'pg_class') AS comment,
            bool_and(col_description(c.oid,a.attnum) IS NOT NULL) AS columns_documented,
            NOT EXISTS(SELECT FROM aclexplode(coalesce(c.relacl,acldefault('r',c.relowner))) x WHERE x.grantee=0 AND x.privilege_type='SELECT') AS private
            FROM pg_class c JOIN pg_attribute a ON a.attrelid=c.oid AND a.attnum>0 AND NOT a.attisdropped
            WHERE c.oid='geolocalisation."V_PyramideSanitaireRapprochee"'::regclass GROUP BY c.oid''').fetchone()
        self.assertTrue(info['comment']); self.assertIs(info['columns_documented'], True); self.assertIs(info['private'], True)
        names = [x['column_name'] for x in self.c.execute("SELECT column_name FROM information_schema.columns WHERE table_schema='geolocalisation' AND table_name='V_PyramideSanitaireRapprochee'")]
        self.assertFalse(any(any(term in name.lower() for term in ('latitude','longitude','geometry','telephone')) for name in names))

    def test_34_alias_name_ambiguity_or_uid_conflict_is_not_a_confirmation(self):
        parents = self.fixture(); source = self.source()
        self.c.execute('UPDATE geolocalisation."T_Niveau_4" SET "NomNiveau_4"=\'Autre aire\' WHERE "ID_Niveau_4"=%s', [parents[4]])
        self.rejected(lambda: self.link(source, **self.confirmed()))
        self.c.execute('UPDATE geolocalisation."T_Niveau_4" SET "NomNiveau_4"=%s WHERE "ID_Niveau_4"=%s', ['Fictif '+self.tag, parents[4]])
        self.insert('T_Niveau_4', {'NomNiveau_4': 'Fictif '+self.tag, 'ID_Niveau_3_Fk': parents[3], 'ID_TypeNiveau_4_Fk': self.as_type}, 'ID_Niveau_4')
        self.rejected(lambda: self.link(source, **self.confirmed()))

    def test_35_only_recorded_zone_uid_is_displayed_not_bureau_uid(self):
        parents = self.fixture(); source = self.source(); zone = self.zone()
        self.c.execute('UPDATE geolocalisation."T_Niveau_3" SET "uidSNIS"=\'BureauUID01\' WHERE "ID_Niveau_3"=%s', [parents[3]])
        self.link(source, NatureLien='bureau_de_zone', ID_OrigineNiveau_5Fk=None,
            ID_OrigineNiveau_3Fk=parents[3], ID_CibleNiveau_4Fk=None, ID_CibleNiveau_3Fk=zone, **self.confirmed())
        self.area_link(source, zone, **self.confirmed())
        self.assertIsNone(self.pyramid_area()[0]['UidZoneSNIS'])
        self.c.execute('UPDATE geolocalisation."T_Niveau_3" SET "uidSNIS"=\'ZoneUID0001\' WHERE "ID_Niveau_3"=%s', [zone])
        self.assertEqual(self.pyramid_area()[0]['UidZoneSNIS'], 'ZoneUID0001')


if __name__ == '__main__':
    unittest.main(verbosity=2)
