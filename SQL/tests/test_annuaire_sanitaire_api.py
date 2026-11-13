"""Annuaire sanitaire N3–N5 : API réelle sur copie privée locale uniquement.

Le module importé impose avant toute connexion une base sauverndeko_test_*.
Toutes les entreprises, identités, territoires et coordonnées créés sont fictifs.
"""
import json
import unittest
import uuid

import test_publication_articles_api as publication
from django.db import transaction
from django.test import override_settings
from rest_framework.test import APIClient
from apps.core import db
from apps.core.module_access import access_snapshot

BASE = '/api/structures/annuaire-sanitaire'
TERRITORIES = '/api/geolocalisation/territoires/registres/'


class SanitaryDirectoryAPI(unittest.TestCase):
    setUpClass = publication.ArticlePublicationAPI.__dict__['setUpClass']
    tearDownClass = publication.ArticlePublicationAPI.__dict__['tearDownClass']
    actor = publication.ArticlePublicationAPI.actor
    client = publication.ArticlePublicationAPI.client
    data = publication.ArticlePublicationAPI.data

    def setUp(self):
        publication.ArticlePublicationAPI.setUp(self)
        family = self.connection.execute("SELECT unnest(referentiel.fn_categories_champ('geolocalisation','T_Niveau_5','ID_TypeNiveau_5_Fk',NULL)) id LIMIT 1").fetchone()['id']
        body = {'requestId': str(uuid.uuid4()), 'scope': 'global', 'categoryId': family,
                'rows': [{'clientRowId': str(uuid.uuid4()), 'NomGenerique': self.tag + '-type-territorial',
                          'AbrGenerique': self.tag + '-T', 'VisibleNiveau_3': True,
                          'VisibleNiveau_4': True, 'VisibleNiveau_5': True}]}
        self.typ = self.data(self.client(all_entities=True).post('/api/referentiel/saisie-multiple/valeurs', body, format='json'), 201)['records'][0]['ID_Generique']

    def create_territory(self, number, parent=None, **changes):
        body = {'requestId': str(uuid.uuid4()), 'NomNiveau_' + str(number): self.tag + '-niveau-' + str(number)}
        if parent is not None:
            fk = 'ID_Niveau_' + str(number - 1) + '_' + ('Fk' if number in {1, 4, 5} else 'FK')
            body[fk] = parent['ID_Niveau_' + str(number - 1)]
        if number in {3, 4, 5}:
            body['ID_TypeNiveau_' + str(2 if number == 3 else number) + '_Fk'] = self.typ
        return self.data(self.client(all_entities=True).post(TERRITORIES + 'niveaux' + str(number), {**body, **changes}, format='json'), 201)

    def chain(self):
        rows = [self.create_territory(0)]
        for number in range(1, 6):
            rows.append(self.create_territory(number, rows[-1]))
        return rows

    def listing(self, **params):
        return self.data(self.client(local=True).get(BASE, {'q': self.tag, **params}))

    def edit(self, number, row, **changes):
        return self.data(self.client(all_entities=True).put(TERRITORIES + 'niveaux' + str(number) + '/' + str(row['ID_Niveau_' + str(number)]),
            {'requestId': str(uuid.uuid4()), '_version': row['_version'], **changes}, format='json'))

    def test_01_closed_projection_and_effective_hierarchy(self):
        chain = self.chain()
        rows = self.listing()['rows']
        self.assertEqual(len(rows), 3)
        self.assertEqual({row['level'] for row in rows}, {3, 4, 5})
        required = {'key', 'level', 'id', 'name', 'code', 'typeId', 'type', 'address', 'phone', 'secondaryPhone',
                    'email', 'website', 'reception', 'hours', 'contactsPublished', 'position', 'province', 'subdivision', 'zone', 'area'}
        for row in rows:
            self.assertEqual(set(row), required)
            self.assertEqual(row['key'], 'n' + str(row['level']) + ':' + str(row['id']))
            self.assertEqual(row['province']['id'], chain[1]['ID_Niveau_1'])
            self.assertEqual(row['zone']['id'], chain[3]['ID_Niveau_3'])
            self.assertIs(row['contactsPublished'], False)
            detail = self.data(self.client(local=True).get(BASE + '/' + str(row['level']) + '/' + str(row['id'])))
            self.assertEqual(detail['record'], row)
        encoded = json.dumps(rows)
        for forbidden in ('IdEntite', 'ObsNiveau', 'geometry', 'Latitude', 'logoUrl', 'canContact', 'IdUser'):
            self.assertNotIn(forbidden, encoded)

    def test_own_position_and_ancestor_types(self):
        chain = self.chain()
        self.connection.execute(
            'UPDATE geolocalisation."T_Niveau_3" SET "LatitudeNiveau_3"=-4.4, "LongitudeNiveau_3"=15.4 WHERE "ID_Niveau_3"=%s',
            [chain[3]['ID_Niveau_3']],
        )
        self.connection.execute(
            'UPDATE geolocalisation."T_Niveau_5" SET "LatitudeNiveau_5"=-4.5, "LongitudeNiveau_5"=15.5 WHERE "ID_Niveau_5"=%s',
            [chain[5]['ID_Niveau_5']],
        )
        results = {row['level']: row for row in self.listing()['rows']}
        self.assertEqual(results[3]['position'], {'latitude': -4.4, 'longitude': 15.4})
        self.assertIsNone(results[4]['position'])
        self.assertEqual(results[5]['position'], {'latitude': -4.5, 'longitude': 15.5})
        for parent in ('zone', 'area'):
            self.assertEqual(results[5][parent]['type'], self.tag + '-T')
        detail = self.data(self.client(local=True).get(BASE + '/5/' + str(chain[5]['ID_Niveau_5'])))
        self.assertEqual(detail['record'], results[5])

    def test_02_contact_publication_is_explicit_reversible_and_not_inherited(self):
        chain = self.chain()
        private = {'AdresseTerritoire': 'Adresse confidentielle ' + self.tag, 'TelephoneTerritoire': '+243000000',
                   'TelephoneSecondaireTerritoire': '+243000001', 'EmailTerritoire': 'sanitaire@example.invalid',
                   'SiteWebTerritoire': 'https://example.invalid', 'InformationsAccueilTerritoire': 'Sur rendez-vous',
                   'HorairesOuvertureTerritoire': 'Lundi–vendredi\n08:00–17:00'}
        saved = self.edit(3, chain[3], **private)
        hidden = next(row for row in self.listing()['rows'] if row['level'] == 3)
        for key in ('address', 'phone', 'secondaryPhone', 'email', 'website', 'reception', 'hours'):
            self.assertIsNone(hidden[key])
        self.assertEqual(self.listing(q=private['AdresseTerritoire'])['total'], 0)
        saved = self.edit(3, saved, PublierCoordonneesAnnuaire=True)
        visible = next(row for row in self.listing()['rows'] if row['level'] == 3)
        self.assertTrue(visible['contactsPublished'])
        self.assertEqual(visible['hours'], private['HorairesOuvertureTerritoire'])
        self.assertEqual(visible['address'], private['AdresseTerritoire'])
        self.assertTrue(all(row['phone'] is None for row in self.listing()['rows'] if row['level'] != 3))
        self.edit(3, saved, PublierCoordonneesAnnuaire=False)
        self.assertIsNone(self.data(self.client(local=True).get(BASE + '/3/' + str(chain[3]['ID_Niveau_3'])))['record']['phone'])

    def test_03_pagination_filters_and_closed_criteria(self):
        chain = self.chain()
        for number in range(107):
            self.connection.execute('''INSERT INTO geolocalisation."T_Niveau_5"
                ("NomNiveau_5","ID_Niveau_3_Fk","ID_TypeNiveau_5_Fk") VALUES(%s,%s,%s)''',
                [self.tag + '-page-' + str(number).zfill(3), chain[3]['ID_Niveau_3'], self.typ])
        keys = []
        for offset in range(0, 125, 25):
            page = self.listing(q=self.tag + '-page-', take=25, skip=offset, level=5, provinceId=chain[1]['ID_Niveau_1'], typeId=self.typ)
            self.assertEqual(page['total'], 107)
            keys.extend(row['key'] for row in page['rows'])
        self.assertEqual(len(set(keys)), 107)
        self.assertEqual(self.listing(q=self.tag + '-page-', skip=107)['rows'], [])
        self.assertEqual(self.listing(locality=chain[1]['NomNiveau_1'])['total'], 110)
        self.assertEqual(self.listing(q="' OR true --")['total'], 0)
        self.assertEqual(self.listing(q=self.tag + '%')['total'], 0)
        for params in ({'take': 0}, {'take': 101}, {'skip': -1}, {'level': 2}, {'level': '5 OR true'},
                       {'typeId': '1 OR true'}, {'provinceId': 0}, {'sortBy': 'IdEntite'}, {'sortDir': 'asc;DROP'},
                       {'locality': 'x' * 256}, {'q': 'x' * 301}, {'unknown': 1}):
            self.data(self.client(local=True).get(BASE, params), 400)
        self.data(self.client(local=True).get(BASE + '?q=a&q=b'), 400)
        self.data(self.client(local=True).get(BASE + '/2/1'), 400)
        self.data(self.client(local=True).get(BASE + '/5/2147483647'), 404)

    def test_04_included_structures_reader_without_territorial_access(self):
        self.chain()
        actor = self.actor(local=True)
        snapshot = access_snapshot(actor)
        snapshot['modules']['territoires']['canRead'] = False
        snapshot['modules']['territoires']['canManage'] = False
        client = APIClient(); client.force_authenticate(actor)
        self.data(client.get(BASE, {'q': self.tag}))
        self.assertIs(self.data(client.get(BASE + '/references'))['canManageTerritories'], False)
        self.assertIs(self.data(client.get('/api/structures/contexte'))['canManageTerritories'], False)
        self.data(client.get(TERRITORIES + 'niveaux5'), 403)
        self.data(self.client(2, local=True).get(BASE))
        for suffix in ('', '/references', '/5/1'):
            self.data(APIClient().get(BASE + suffix), 401)
        with override_settings(DB_READ_ONLY=True):
            self.assertEqual(len(self.data(client.get(BASE, {'q': self.tag}))['rows']), 3)
        self.data(client.post(BASE, {}, format='json'), 405)

    def test_05_compatibility_and_statistics_use_territorial_identities_without_writes(self):
        self.chain()
        count = lambda: self.connection.execute('''SELECT
            (SELECT count(*) FROM communication."T_Discussion") discussions,
            (SELECT count(*) FROM communication."T_Chat") chats,
            (SELECT count(*) FROM analytics."T_Recherche") searches,
            (SELECT count(*) FROM geolocalisation."T_CoordonneesTerritoire") contacts''').fetchone()
        before = count()
        response = self.client(local=True).get('/api/public/pharmacies', {'q': self.tag})
        rows = self.data(response)
        self.assertEqual(rows, self.listing()['rows'])
        self.assertEqual(response.json()['meta']['total'], 3)
        refs = self.data(self.client(local=True).get(BASE + '/references'))
        self.assertTrue(any(row['id'] == self.typ and 5 in row['levels'] for row in refs['types']))
        stats = self.data(self.client(local=True).get('/api/public/stats'))
        total = db.one('SELECT count(*) total FROM geolocalisation."V_StructureSanitairePublique"')['total']
        self.assertEqual(stats['structuresCount'], total)
        self.assertEqual(stats['activeStructures'], total)
        self.assertEqual(before, count())

    def test_06_colliding_ids_never_become_company_identity(self):
        chain = self.chain()
        identifier = self.connection.execute('''SELECT GREATEST(
            (SELECT COALESCE(max("ID_Niveau_3"),0) FROM geolocalisation."T_Niveau_3"),
            (SELECT COALESCE(max("ID_Niveau_4"),0) FROM geolocalisation."T_Niveau_4"),
            (SELECT COALESCE(max("ID_Niveau_5"),0) FROM geolocalisation."T_Niveau_5"),
            (SELECT COALESCE(max("IdEntite"),0) FROM systeme."T_Entite"))+1000 id''').fetchone()['id']
        self.connection.execute('''INSERT INTO systeme."T_Entite"("IdEntite","NomEntite","EmailEntite","ValideEntite","VisibleAnnuaireEntite")
            OVERRIDING SYSTEM VALUE VALUES(%s,%s,%s,true,true)''', [identifier, 'Entreprise distincte ' + self.tag, uuid.uuid4().hex + '@example.invalid'])
        for number, parent_id in ((3, chain[2]['ID_Niveau_2']), (4, identifier), (5, identifier)):
            parent = 'ID_Niveau_' + str(number - 1) + '_' + ('FK' if number == 3 else 'Fk')
            type_column = 'ID_TypeNiveau_' + str(2 if number == 3 else number) + '_Fk'
            self.connection.execute('INSERT INTO geolocalisation."T_Niveau_' + str(number) + '" (' + db.ident('ID_Niveau_' + str(number))
                + ',' + db.ident('NomNiveau_' + str(number)) + ',' + db.ident(parent) + ',' + db.ident(type_column) + ') OVERRIDING SYSTEM VALUE VALUES(%s,%s,%s,%s)',
                [identifier, self.tag + '-collision-' + str(number), parent_id, self.typ])
        for number in (3, 4, 5):
            row = self.data(self.client(local=True).get(BASE + '/' + str(number) + '/' + str(identifier)))['record']
            self.assertEqual(row['key'], 'n' + str(number) + ':' + str(identifier))
            self.assertEqual(row['name'], self.tag + '-collision-' + str(number))
        company = self.data(self.client(local=True).get('/api/structures/annuaire/' + str(identifier)))['record']
        self.assertEqual(company['name'], 'Entreprise distincte ' + self.tag)

    def test_07_detail_rechecks_active_type_without_deleting_territory(self):
        chain = self.chain()
        target = BASE + '/5/' + str(chain[5]['ID_Niveau_5'])
        reference = '/api/models/T_Generique/' + str(self.typ)
        self.data(self.client(local=True).get(target))
        self.data(self.client(local=True).put(reference, {'ValideGenerique': False}, format='json'), 403)
        try:
            self.data(self.client(all_entities=True).put(reference, {'ValideGenerique': False}, format='json'))
            self.assertEqual(self.listing()['total'], 0)
            self.data(self.client(local=True).get(target), 404)
            self.assertIsNotNone(db.one('SELECT 1 existing FROM geolocalisation."T_Niveau_5" WHERE "ID_Niveau_5"=%s', [chain[5]['ID_Niveau_5']]))
        finally:
            self.data(self.client(all_entities=True).put(reference, {'ValideGenerique': True}, format='json'))

    def test_08_visibility_controls_new_choices_and_preserves_existing_directory(self):
        chain = self.chain()
        reference = '/api/models/T_Generique/' + str(self.typ)
        for number in (3, 4, 5):
            field = 'ID_TypeNiveau_' + str(2 if number == 3 else number) + '_Fk'
            visibility = 'VisibleNiveau_' + str(number)
            choices_url = '/api/geolocalisation/territoires/references/niveaux' + str(number)
            choices = self.data(self.client(all_entities=True).get(choices_url))
            self.assertTrue(any(row['id'] == self.typ and not row['disabled'] for row in choices['fieldReferences'][field]['options']))
            self.data(self.client(all_entities=True).put(reference, {visibility: False}, format='json'))
            choices = self.data(self.client(all_entities=True).get(choices_url))
            self.assertFalse(any(row['id'] == self.typ for row in choices['fieldReferences'][field]['options']))
            retained = self.data(self.client(all_entities=True).get(choices_url, {'currentId': chain[number]['ID_Niveau_' + str(number)]}))
            current = next(row for row in retained['fieldReferences'][field]['options'] if row['id'] == self.typ)
            self.assertIs(current['disabled'], True)
            self.assertEqual(self.listing()['total'], 3)
            body = {'requestId': str(uuid.uuid4()), 'NomNiveau_' + str(number): self.tag + '-forbidden-' + str(number), field: self.typ}
            parent = 'ID_Niveau_' + str(number - 1) + '_' + ('FK' if number == 3 else 'Fk')
            body[parent] = chain[number - 1]['ID_Niveau_' + str(number - 1)]
            response = self.client(all_entities=True).post(TERRITORIES + 'niveaux' + str(number), body, format='json')
            self.data(response, 400)
            self.assertEqual(response.json()['error']['code'], 'REFERENCE_NOT_VISIBLE')
            changed = self.edit(number, chain[number], **{field: self.typ, 'ObsNiveau_' + str(number): 'Description historique conservée'})
            self.assertEqual(changed[field], self.typ)
            chain[number] = changed
            self.data(self.client(all_entities=True).put(reference, {visibility: True}, format='json'))
            choices = self.data(self.client(all_entities=True).get(choices_url))
            self.assertTrue(any(row['id'] == self.typ and not row['disabled'] for row in choices['fieldReferences'][field]['options']))

        family = self.connection.execute('SELECT "ID_CategorieGeneriqueFk" id FROM referentiel."T_Generique" WHERE "ID_Generique"=%s', [self.typ]).fetchone()['id']
        body = {'requestId': str(uuid.uuid4()), 'scope': 'global', 'categoryId': family,
                'rows': [{'clientRowId': str(uuid.uuid4()), 'NomGenerique': self.tag + '-type-n5-masque',
                          'AbrGenerique': self.tag + '-M', 'VisibleNiveau_5': False}]}
        hidden = self.data(self.client(all_entities=True).post('/api/referentiel/saisie-multiple/valeurs', body, format='json'), 201)['records'][0]['ID_Generique']
        choices = self.data(self.client(all_entities=True).get('/api/geolocalisation/territoires/references/niveaux5'))
        self.assertFalse(any(row['id'] == hidden for row in choices['fieldReferences']['ID_TypeNiveau_5_Fk']['options']))
        response = self.client(all_entities=True).put(TERRITORIES + 'niveaux5/' + str(chain[5]['ID_Niveau_5']),
            {'requestId': str(uuid.uuid4()), '_version': chain[5]['_version'], 'ID_TypeNiveau_5_Fk': hidden}, format='json')
        self.data(response, 400)
        self.assertEqual(response.json()['error']['code'], 'REFERENCE_NOT_VISIBLE')

    def test_09_searches_descriptive_type_name_while_displaying_its_abbreviation(self):
        chain = self.chain(); site = chain[5]
        family = self.connection.execute('SELECT "ID_CategorieGeneriqueFk" id FROM referentiel."T_Generique" WHERE "ID_Generique"=%s', [self.typ]).fetchone()['id']
        for query, label, abbreviation in (('HÔPITAL', 'Hôpital ' + self.tag, 'HOP-' + self.tag),
                                           ('centre de santé', 'Centre de santé ' + self.tag, 'CS-' + self.tag)):
            body = {'requestId': str(uuid.uuid4()), 'scope': 'global', 'categoryId': family,
                    'rows': [{'clientRowId': str(uuid.uuid4()), 'NomGenerique': label, 'AbrGenerique': abbreviation,
                              'VisibleNiveau_5': True}]}
            reference = self.data(self.client(all_entities=True).post('/api/referentiel/saisie-multiple/valeurs', body, format='json'), 201)['records'][0]
            site = self.edit(5, site, ID_TypeNiveau_5_Fk=reference['ID_Generique'])
            found = self.listing(q=query, typeId=reference['ID_Generique'], provinceId=chain[1]['ID_Niveau_1'])
            self.assertEqual(found['total'], 1)
            self.assertEqual(found['rows'][0]['key'], 'n5:' + str(site['ID_Niveau_5']))
            self.assertEqual(found['rows'][0]['type'], abbreviation)
            self.assertNotIn(label, json.dumps(found))
            self.assertNotIn('NomGenerique', json.dumps(found))
            self.assertIsNone(found['rows'][0]['phone'])

    def test_10_administrative_types_at_all_three_levels_remain_searchable(self):
        chain = self.chain()
        family = self.connection.execute('SELECT "ID_CategorieGeneriqueFk" id FROM referentiel."T_Generique" WHERE "ID_Generique"=%s', [self.typ]).fetchone()['id']
        for number, label, abbreviation in ((3, 'District', 'DIST'), (4, 'Secteur', 'SECT'), (5, 'Groupement', 'GRPT')):
            body = {'requestId': str(uuid.uuid4()), 'scope': 'global', 'categoryId': family,
                    'rows': [{'clientRowId': str(uuid.uuid4()), 'NomGenerique': label + ' ' + self.tag,
                              'AbrGenerique': abbreviation + '-' + self.tag, 'VisibleNiveau_' + str(number): True}]}
            reference = self.data(self.client(all_entities=True).post('/api/referentiel/saisie-multiple/valeurs', body, format='json'), 201)['records'][0]
            field = 'ID_TypeNiveau_' + str(2 if number == 3 else number) + '_Fk'
            self.edit(number, chain[number], **{field: reference['ID_Generique']})
            found = self.listing(q=label, level=number, typeId=reference['ID_Generique'], provinceId=chain[1]['ID_Niveau_1'])
            self.assertEqual(found['total'], 1)
            self.assertEqual(found['rows'][0]['key'], 'n' + str(number) + ':' + str(chain[number]['ID_Niveau_' + str(number)]))
            self.assertEqual(found['rows'][0]['type'], abbreviation + '-' + self.tag)
        refs = self.data(self.client(local=True).get(BASE + '/references'))
        self.assertEqual([item['label'] for item in refs['levels']], ['Niveau 3', 'Niveau 4', 'Niveau 5 — Structures et sites'])

    def test_11_empty_level_four_choices_are_explained_and_update_dynamically(self):
        from apps.core.field_references import reference_context, save as save_reference
        chain = self.chain()
        actor = self.actor(all_entities=True)
        # Une famille de recette temporaire isole ce cas sans modifier les
        # visibilités des valeurs historiques ni conserver son paramétrage.
        with transaction.atomic():
            family = db.one('INSERT INTO referentiel."T_CategorieGenerique"("NomCategorieGenerique","ValideCategorieGenerique") '
                            'VALUES(%s,true) RETURNING "ID_CategorieGenerique" id', [self.tag + '-famille-n4'])['id']
            value = db.one('''INSERT INTO referentiel."T_Generique"
                ("ID_CategorieGeneriqueFk","NomGenerique","AbrGenerique","ValideGenerique","VisibleNiveau_4")
                VALUES(%s,%s,%s,true,false) RETURNING "ID_Generique" id''', [family, self.tag + '-type-n4', 'N4-' + self.tag])['id']
            context = reference_context(actor, 'geolocalisation', 'T_Niveau_4', 'ID_TypeNiveau_4_Fk')
            save_reference(actor, context['ID_ChampReferentiel'], {'scope': 'global', '_version': context['_version'],
                'requestId': str(uuid.uuid4()), 'motif': 'Vérifier les choix N4 sans toucher aux valeurs historiques', 'categoryIds': [family]})
            url = '/api/geolocalisation/territoires/references/niveaux4'
            choices = self.data(self.client(all_entities=True).get(url))['fieldReferences']['ID_TypeNiveau_4_Fk']
            self.assertEqual(choices['options'], [])
            self.assertEqual(choices['availableCount'], 0)
            self.assertIn('Référentiels', choices['choiceMessage'])
            self.data(self.client(all_entities=True).put('/api/models/T_Generique/' + str(value), {'VisibleNiveau_4': True}, format='json'))
            choices = self.data(self.client(all_entities=True).get(url))['fieldReferences']['ID_TypeNiveau_4_Fk']
            self.assertEqual([row['id'] for row in choices['options']], [value])
            self.assertEqual(choices['choiceMessage'], '')
            self.create_territory(4, chain[3], NomNiveau_4=self.tag + '-n4-autorise', ID_TypeNiveau_4_Fk=value)
            transaction.set_rollback(True)


if __name__ == '__main__':
    unittest.main(verbosity=2)
