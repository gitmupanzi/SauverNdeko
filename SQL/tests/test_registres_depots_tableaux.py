"""Préférences et exports multi-dépôts réels, sur copie privée uniquement."""
import csv
import io
import json
import unittest
import uuid
from decimal import Decimal

from test_bons_commande_api import BonsCommandeAPI
from django.test import override_settings
from openpyxl import load_workbook
from rest_framework.test import APIClient


class DepotRegistersAPI(BonsCommandeAPI):
    kinds = ('depots', 'stocks-depots', 'transferts', 'inventaires')

    def depot(self, name=None, entity=0):
        response = self.client(entity).post('/api/logistique/depots', {
            'requestId': str(uuid.uuid4()), 'NomDepot': name or 'Dépôt de recette ' + uuid.uuid4().hex,
            'AdresseDepot': 'Adresse de recette', 'Actif': True,
        }, format='json')
        self.assertEqual(response.status_code, 201, response.data)
        return response.data['data']['ID_Depot']

    def principal(self, entity=0):
        return self.connection.execute('SELECT "ID_Depot" id FROM logistique."T_Depot" WHERE "IdEntiteFk"=%s AND "Principal"', [self.entities[entity]]).fetchone()['id']

    def csv_rows(self, kind, params=None, client=None):
        response = (client or self.client()).get('/api/logistique/' + kind + '/export.csv', params or {}, HTTP_ACCEPT='text/csv')
        self.assertEqual(response.status_code, 200, getattr(response, 'data', None))
        rows = list(csv.reader(io.StringIO(b''.join(response.streaming_content).decode('utf-8-sig')), delimiter=';'))
        self.assertEqual(int(response['X-Export-Row-Count']), len(rows) - 1)
        return rows

    def prefs(self, kind, client=None):
        response = (client or self.client()).get('/api/tableaux/logistique.' + kind + '/preferences')
        self.assertEqual(response.status_code, 200, response.data)
        return response.data['data']

    def test_register_01_four_persistent_catalogues_and_separate_scopes(self):
        for kind in self.kinds:
            with self.subTest(kind=kind):
                snapshot = self.prefs(kind)
                defaults = snapshot['table']['columns']
                self.assertTrue(defaults)
                self.assertNotIn('actions', snapshot['export']['columns'])
                wanted = list(reversed(defaults))
                endpoint = '/api/tableaux/logistique.' + kind + '/preferences'
                response = self.client().put(endpoint, {'usage': 'table', 'version': snapshot['table']['version'], 'columns': wanted}, format='json')
                self.assertEqual(response.status_code, 200, response.data)
                self.assertEqual(self.prefs(kind)['table']['columns'], wanted)
                self.assertFalse(self.prefs(kind, self.client(1))['table']['personal'])
                stale = self.client().put(endpoint, {'usage': 'table', 'version': snapshot['table']['version'], 'columns': defaults}, format='json')
                self.assertEqual(stale.status_code, 409)
                current = self.prefs(kind)
                reset = self.client().delete(endpoint, {'usage': 'table', 'version': current['table']['version']}, format='json')
                self.assertEqual(reset.status_code, 200, reset.data)
                self.assertEqual(reset.data['data']['table']['columns'], defaults)

    def test_register_02_depots_full_filtered_csv_and_typed_xlsx(self):
        prefix = 'Registre ' + uuid.uuid4().hex
        for n in range(6):
            self.depot(prefix + ' ' + str(n))
        self.depot(prefix + ' étranger', entity=1)
        params = {'q': prefix, 'actif': 'true', 'sortBy': 'NomDepot', 'sortDir': 'desc', 'take': 2}
        page = self.client().get('/api/logistique/depots', params)
        self.assertEqual(page.status_code, 200, page.data)
        self.assertEqual(page.data['meta']['filteredCount'], 6)
        self.assertEqual(len(page.data['data']), 2)
        params['columns'] = json.dumps(['NomDepot', 'Principal', 'Actif', 'CreeLe'])
        rows = self.csv_rows('depots', params)
        self.assertEqual(len(rows), 7)
        self.assertEqual([row[0] for row in rows[1:]], [prefix + ' ' + str(n) for n in reversed(range(6))])
        self.assertEqual([row[0] for row in rows[1:3]], [row['NomDepot'] for row in page.data['data']])
        self.assertNotIn(prefix + ' étranger', [row[0] for row in rows[1:]])
        response = self.client().get('/api/logistique/depots/export.xlsx', params, HTTP_ACCEPT='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
        self.assertEqual(response.status_code, 200, getattr(response, 'data', None))
        book = load_workbook(io.BytesIO(b''.join(response.streaming_content)), data_only=True)
        sheet = book['Données']
        self.assertEqual(sheet.max_row, 7)
        self.assertEqual(sheet['A1'].value, 'Dépôt')
        self.assertEqual(sheet['B2'].value, 'Non')
        self.assertEqual(sheet['D2'].data_type, 'd')
        self.assertIn('Informations', book.sheetnames)

    def test_register_03_stock_full_export_matches_depot_and_article_search(self):
        prefix = 'Stock de recette ' + uuid.uuid4().hex
        depot = self.depot(prefix)
        for n in range(4):
            article = self.article()
            self.connection.execute('UPDATE logistique."T_Article" SET "NomArticle"=%s WHERE "ID_Article"=%s', [prefix + str(n), article])
        params = {'depotId': depot, 'q': prefix, 'take': 1, 'sortBy': 'NomArticle', 'sortDir': 'desc'}
        page = self.client().get('/api/logistique/stocks-depots', params)
        self.assertEqual(page.status_code, 200, page.data)
        self.assertEqual(page.data['meta']['filteredCount'], 4)
        rows = self.csv_rows('stocks-depots', {**params, 'columns': json.dumps(['NomArticle', 'NomDepot', 'StockPhysique'])})
        self.assertEqual(len(rows), 5)
        self.assertEqual(rows[1][0], page.data['data'][0]['NomArticle'])
        self.assertTrue(all(row[1] == prefix for row in rows[1:]))
        self.assertTrue(all(Decimal(row[2].replace(',', '.')) == 0 for row in rows[1:]))
        denied = self.client(1).get('/api/logistique/stocks-depots/export.csv', params, HTTP_ACCEPT='text/csv')
        self.assertEqual(denied.status_code, 404)

    def test_register_04_transfers_state_depot_and_sorted_export(self):
        article = self.article(); depot = self.depot()
        prefix = 'Transferts de recette ' + uuid.uuid4().hex
        for n in range(4):
            body = {'requestId': str(uuid.uuid4()), 'transfert': {
                'ID_DepotSourceFk': self.principal(), 'ID_DepotDestinationFk': depot,
                'ID_DeviseFk': self.currency, 'DateTransfert': '2026-11-07T12:00:00+01:00',
                'Motif': prefix, 'ReferenceTransfert': str(n)},
                'lignes': [{'ID_ArticleFk': article, 'QteDemandee': '1', 'Lots': [], 'ObsLigne': ''}]}
            response = self.client().post('/api/logistique/transferts', body, format='json')
            self.assertEqual(response.status_code, 201, response.data)
        params = {'depotId': depot, 'etat': 'TR_BROUILLON', 'q': prefix, 'take': 1, 'sortBy': 'CodeTransfert', 'sortDir': 'asc'}
        page = self.client().get('/api/logistique/transferts', params)
        self.assertEqual(page.status_code, 200, page.data)
        self.assertEqual(page.data['meta']['filteredCount'], 4)
        rows = self.csv_rows('transferts', {**params, 'columns': json.dumps(['CodeTransfert', 'EtatCode', 'DateTransfert'])})
        self.assertEqual(len(rows), 5)
        self.assertEqual(rows[1][0], page.data['data'][0]['CodeTransfert'])
        self.assertTrue(all(row[1] == 'TR_BROUILLON' for row in rows[1:]))
        self.assertEqual(len(self.csv_rows('transferts', {**params, 'etat': 'TR_TERMINE'})), 1)

    def test_register_05_inventories_full_export_and_no_stock_side_effect(self):
        article = self.article(); depot = self.principal()
        prefix = 'Comptage de recette ' + uuid.uuid4().hex
        for n in range(4):
            body = {'requestId': str(uuid.uuid4()), 'ID_DepotFk': depot,
                    'DateInventaire': '2026-11-07T12:00:00+01:00', 'Motif': prefix + str(n),
                    'lignes': [{'ID_ArticleFk': article, 'QteTheorique': '0', 'QteComptee': '0',
                                'Justification': 'Comptage de recette', 'Lots': [], 'PUCorrection': '10'}]}
            response = self.client().post('/api/logistique/inventaires', body, format='json')
            self.assertEqual(response.status_code, 201, response.data)
        before = self.state(article)
        params = {'q': prefix, 'depotId': depot, 'take': 1, 'sortBy': 'Motif', 'sortDir': 'asc'}
        page = self.client().get('/api/logistique/inventaires', params)
        self.assertEqual(page.status_code, 200, page.data)
        self.assertEqual(page.data['meta']['filteredCount'], 4)
        rows = self.csv_rows('inventaires', {**params, 'columns': json.dumps(['Motif', 'NbArticles', 'NbEcarts'])})
        self.assertEqual(len(rows), 5)
        self.assertEqual(rows[1][0], page.data['data'][0]['Motif'])
        self.assertTrue(all(row[1:] == ['1', '0'] for row in rows[1:]))
        self.assertEqual(before, self.state(article))

    def test_register_06_permissions_forbidden_columns_and_read_only_exports(self):
        client = APIClient(); actor = self.actor()
        actor._module_access['modules']['logistique']['canExport'] = False
        client.force_authenticate(actor)
        for kind in self.kinds:
            with self.subTest(kind=kind):
                self.assertFalse(self.prefs(kind, client)['canExport'])
                denied = client.get('/api/logistique/' + kind + '/export.csv', HTTP_ACCEPT='text/csv')
                self.assertEqual(denied.status_code, 403)
                for columns in [['actions'], ['ValidationHash'], ['Version'], ['NomArticle; DROP TABLE x']]:
                    denied = self.client().get('/api/logistique/' + kind + '/export.csv', {'columns': json.dumps(columns)}, HTTP_ACCEPT='text/csv')
                    self.assertEqual(denied.status_code, 400)
                with override_settings(DB_READ_ONLY=True):
                    self.csv_rows(kind)
                    response = self.client().get('/api/logistique/' + kind + '/export.xlsx', HTTP_ACCEPT='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
                    self.assertEqual(response.status_code, 200, getattr(response, 'data', None))
                    book = load_workbook(io.BytesIO(b''.join(response.streaming_content)), data_only=True)
                    self.assertEqual(book['Données'].max_column, len(self.prefs(kind)['export']['columns']))
                    book.close()
                    snapshot = self.prefs(kind)
                    denied = self.client().put('/api/tableaux/logistique.' + kind + '/preferences', {'usage': 'table', 'columns': snapshot['table']['columns'], 'version': snapshot['table']['version']}, format='json')
                    self.assertEqual(denied.status_code, 503)


if __name__ == '__main__':
    unittest.main()
