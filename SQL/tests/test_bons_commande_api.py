"""Recette réelle CMD/BE/BS ; base locale sauverndeko_test_* obligatoire, aucune donnée client."""
import csv
import io
import json
import os
import re
import sys
import unittest
import uuid
from decimal import Decimal
from pathlib import Path
from urllib.parse import urlsplit

import psycopg
from psycopg.rows import dict_row

ROOT = Path(__file__).resolve().parents[2]
DSN = os.environ.get('SAUVERNDEKO_TEST_DATABASE_URL', '')
location = urlsplit(DSN)
if location.hostname not in {'127.0.0.1', 'localhost', '::1'} or not location.path[1:].startswith('sauverndeko_test_'):
    raise RuntimeError('Une base PostgreSQL privée locale sauverndeko_test_* est obligatoire.')
with psycopg.connect(DSN) as guard:
    if not guard.execute('SELECT current_database()').fetchone()[0].startswith('sauverndeko_test_'):
        raise RuntimeError('Recette refusée hors base privée.')
os.environ.update(DATABASE_URL=DSN, DJANGO_SETTINGS_MODULE='config.settings', SAUVERNDEKO_DB_READ_ONLY='0')
sys.path.insert(0, str(ROOT / 'backend'))
import django
django.setup()
from django.test import override_settings
from rest_framework.test import APIClient
from apps.accounts.authentication import Actor
from apps.core import repository
from apps.logistique import reads


class BonsCommandeAPI(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.context = override_settings(ALLOWED_HOSTS=['testserver'])
        cls.context.enable()
        cls.connection = psycopg.connect(DSN, autocommit=True, row_factory=dict_row)
        c = cls.connection
        # Les clones de structure n'ont pas le catalogue initial de données.
        # Reprendre uniquement la définition versionnée, jamais un réglage client.
        if not c.execute('SELECT 1 FROM referentiel."T_InterfaceTableau" WHERE "CleInterface"=\'logistique.commandes\'').fetchone():
            source = (ROOT / 'backend/database/migrations/20261028_02_preferences_tableaux.sql').read_text(encoding='utf8')
            entry = re.search(r"^\('logistique[.]commandes','logistique','(.*)'::jsonb\)[,;]$", source, re.MULTILINE)
            if not entry: raise RuntimeError('Catalogue versionné des bons absent de la migration02.')
            columns = json.loads(entry.group(1).replace("''", "'"))
            c.execute('INSERT INTO referentiel."T_InterfaceTableau" ("CleInterface","Module","Colonnes") VALUES (\'logistique.commandes\',\'logistique\',%s::jsonb)', [json.dumps(columns, ensure_ascii=False)])
        for key, label in [(34, 'Unités'), (40, 'Catégorie produit'), (42, 'Devise'), (46, 'Type produit'), (64, 'Type de commande')]:
            c.execute('INSERT INTO referentiel."T_CategorieGenerique" ("ID_CategorieGenerique","NomCategorieGenerique","ValideCategorieGenerique") OVERRIDING SYSTEM VALUE VALUES (%s,%s,true) ON CONFLICT DO NOTHING', [key, label])
        def reference(category, label, code):
            # Une reprise historique peut conserver « Entrée » comme code.
            # Réutiliser la valeur commune par code ou libellé, sans créer de
            # doublon ni modifier la nomenclature déjà présente dans le clone.
            existing = c.execute('SELECT "ID_Generique" id FROM referentiel."T_Generique" WHERE "ID_CategorieGeneriqueFk"=%s AND "IdEntiteFk" IS NULL AND (referentiel.fn_normaliser_libelle("AbrGenerique")=referentiel.fn_normaliser_libelle(%s) OR referentiel.fn_normaliser_libelle("NomGenerique")=referentiel.fn_normaliser_libelle(%s)) AND "ValideGenerique" IS TRUE ORDER BY "ID_Generique" LIMIT 1', [category, code, label]).fetchone()
            return existing['id'] if existing else c.execute('INSERT INTO referentiel."T_Generique" ("ID_CategorieGeneriqueFk","NomGenerique","AbrGenerique","ValideGenerique") VALUES (%s,%s,%s,true) RETURNING "ID_Generique" id', [category, label, code]).fetchone()['id']
        cls.currency = reference(42, 'USD', 'USD')
        cls.unit = reference(34, 'Pièce fictive CMD', 'test-cmd-pcs')
        cls.category = reference(40, 'Catégorie fictive CMD', 'test-cmd-cat')
        cls.article_type = reference(46, 'Type fictif CMD', 'test-cmd-type')
        cls.cmd = reference(64, 'Bon de commande', 'CMD')
        cls.be = reference(64, 'Entrée', 'Entree')
        cls.bs = reference(64, 'Sortie', 'Sortie')
        cls.unknown = reference(64, 'Type non pris en charge', 'test-unknown')
        cls.entities = [c.execute('INSERT INTO systeme."T_Entite" ("NomEntite","EmailEntite","ValideEntite") VALUES (%s,%s,true) RETURNING "IdEntite" id',
                                  ['Entreprise fictive CMD ' + uuid.uuid4().hex, uuid.uuid4().hex + '@example.invalid']).fetchone()['id'] for _ in range(2)]
        cls.user = c.execute('INSERT INTO systeme."T_Utilisateurs" ("NomUser","PrenomUser","EmailUser","MotdepasseUser","ValideUser","SexeUser","Is_Admin","IdEntiteFk") VALUES (\'Fictif\',\'CMD\',%s,\'inutilisable\',true,\'M\',true,%s) RETURNING *',
                             [uuid.uuid4().hex + '@example.invalid', cls.entities[0]]).fetchone()

    @classmethod
    def tearDownClass(cls):
        cls.connection.close()
        cls.context.disable()

    def actor(self, entity=0, *, global_admin=True, manage=True):
        row = {**self.user, 'Is_Admin': global_admin, 'Is_staff': True, 'IdEntiteFk': self.entities[entity]}
        actor = Actor(row)
        if global_admin: actor._context_entity = self.entities[entity]
        actor._module_access = {'modules': {'logistique': {'canRead': True, 'canManage': manage, 'canExport': True}}}
        return actor

    def client(self, entity=0, **rights):
        client = APIClient()
        client.force_authenticate(self.actor(entity, **rights))
        return client

    def article(self, entity=0, *, active=True):
        return repository.mutate('T_Article', self.actor(entity), {
            'NomArticle': 'Article fictif CMD ' + uuid.uuid4().hex, 'ID_CategorieArticleFk': self.category,
            'ID_TypeArticleFk': self.article_type, 'ID_UniteFk': self.unit, 'ID_DeviseFk': self.currency,
            'QteArticle': '0', 'PUArticle': '10', 'PVArticle': '15', 'ValideArticle': active,
        })['ID_Article']

    def payload(self, article, *, kind=None, quantity='7', price='12.34', lots=None):
        return {'requestId': str(uuid.uuid4()), 'bon': {'ID_TypeCmdFk': kind or self.cmd, 'ID_DeviseFk': self.currency,
                'DateCmd': '2026-10-28T12:00:00', 'ObsCmd': 'Document fictif de recette'},
                'lignes': [{'ID_ArticleFk': article, 'QteCmdDetail': quantity, 'PUCmdDetail': price, 'Lots': lots or []}]}

    def create(self, payload, entity=0, expected=201):
        response = self.client(entity).post('/api/logistique/commandes/composees', payload, format='json')
        self.assertEqual(response.status_code, expected, response.data)
        return response.data['data']

    def state(self, article):
        return self.connection.execute('SELECT a."QteArticle" stock,(SELECT count(*) FROM logistique."T_Mouvement" m WHERE m."ID_ArticleFk"=a."ID_Article") movements,(SELECT count(*) FROM logistique."T_LotArticle" l WHERE l."ID_ArticleFk"=a."ID_Article") lots FROM logistique."T_Article" a WHERE a."ID_Article"=%s', [article]).fetchone()

    def test_01_references_are_dynamic_and_explicit(self):
        response = self.client().get('/api/logistique/references')
        self.assertEqual(response.status_code, 200, response.data)
        options = {row['id']: row for row in response.data['data']['commandeTypes']}
        self.assertEqual(options[self.cmd]['kind'], 'commande')
        self.assertEqual(options[self.cmd]['stockEffect'], 0)
        self.assertFalse(options[self.cmd]['canInvoice'])
        self.assertEqual(options[self.be]['stockEffect'], 1)
        self.assertTrue(options[self.bs]['canInvoice'])
        self.assertEqual(options[self.unknown]['kind'], 'inconnu')

    def test_02_cmd_create_edit_and_replay_never_touch_stock_or_lots(self):
        article = self.article(); before = self.state(article)
        body = self.payload(article)
        created = self.create(body); command = created['bon']['ID_Commande']
        self.assertEqual(created['bon']['NatureBon'], 'commande')
        self.assertTrue(created['bon']['CodeCmd'].startswith('CMD-'))
        self.assertEqual(self.state(article), before)
        self.assertEqual(self.create(body, expected=200)['bon']['ID_Commande'], command)
        response = self.client().get(f'/api/logistique/commandes/{command}/composition')
        self.assertEqual(response.status_code, 200, response.data)
        self.assertFalse(response.data['meta']['canChangeType'])
        self.assertFalse(response.data['meta']['canInvoice'])
        edit = {'requestId': str(uuid.uuid4()), 'bon': body['bon'], 'lignes': [{**body['lignes'][0], 'QteCmdDetail': '23', 'PUCmdDetail': '4.50'}], '_version': response.data['meta']['revision']}
        response = self.client().put(f'/api/logistique/commandes/{command}/composition', edit, format='json')
        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(Decimal(str(response.data['data']['bon']['MontantTTC'])), Decimal('103.50'))
        self.assertEqual(self.state(article), before)
        repeated = self.client().put(f'/api/logistique/commandes/{command}/composition', edit, format='json')
        self.assertEqual(repeated.status_code, 200, repeated.data)
        self.assertTrue(repeated.data['data']['replayed'])

    def test_03_cmd_refuses_lot_allocation_and_missing_agreed_price(self):
        article = self.article(); before = self.state(article)
        for body in [self.payload(article, lots=[{'NumeroLot': 'FICTIF', 'Quantite': '7'}]), self.payload(article, price=None)]:
            response = self.client().post('/api/logistique/commandes/composees', body, format='json')
            self.assertEqual(response.status_code, 400, response.data)
        self.assertEqual(self.state(article), before)

    def test_04_precision_applies_without_any_stock_reservation(self):
        article = self.article()
        rejected = self.client().post('/api/logistique/commandes/composees', self.payload(article, quantity='0.5'), format='json')
        self.assertEqual(rejected.status_code, 400, rejected.data)
        self.create(self.payload(article, quantity='999'))
        self.assertEqual(self.state(article)['stock'], Decimal(0))

    def test_05_scope_inactive_article_and_rights_still_apply(self):
        foreign = self.article(1); inactive = self.article(active=False)
        for article in (foreign, inactive):
            response = self.client().post('/api/logistique/commandes/composees', self.payload(article), format='json')
            self.assertIn(response.status_code, (403, 404, 409), response.data)
        response = self.client(manage=False).post('/api/logistique/commandes/composees', self.payload(self.article()), format='json')
        self.assertEqual(response.status_code, 403, response.data)
        created = self.create(self.payload(self.article()))
        command = created['bon']['ID_Commande']
        response = self.client(1, global_admin=False).get(f'/api/logistique/commandes/{command}/composition')
        self.assertEqual(response.status_code, 404, response.data)

    def test_06_cmd_type_immutable_and_unknown_not_a_neutral_fallback(self):
        article = self.article(); created = self.create(self.payload(article)); command = created['bon']['ID_Commande']
        current = self.client().get(f'/api/logistique/commandes/{command}/composition').data
        payload = self.payload(article, kind=self.be); payload['_version'] = current['meta']['revision']
        response = self.client().put(f'/api/logistique/commandes/{command}/composition', payload, format='json')
        self.assertEqual(response.status_code, 409, response.data)
        response = self.client().post('/api/logistique/commandes/composees', self.payload(article, kind=self.unknown), format='json')
        self.assertEqual(response.status_code, 400, response.data)
        self.assertEqual(self.state(article)['movements'], 0)

    def test_07_cmd_not_billable_returnable_or_a_physical_pdf(self):
        article = self.article(); command = self.create(self.payload(article))['bon']['ID_Commande']
        invoice = self.client().get(f'/api/logistique/commandes/{command}/facture')
        self.assertEqual(invoice.status_code, 200, invoice.data)
        self.assertFalse(invoice.data['meta']['canIssue'])
        issued = self.client().post(f'/api/logistique/commandes/{command}/facture', {
            'requestId': str(uuid.uuid4()), '_version': invoice.data['meta']['revision'],
            'DateFacture': '2026-10-28T12:00:00', 'DateEcheancePaiement': '2026-11-28T12:00:00',
        }, format='json')
        self.assertEqual(issued.status_code, 409, issued.data)
        returns = self.client().get(f'/api/logistique/commandes/{command}/retours')
        self.assertEqual(returns.status_code, 200, returns.data)
        self.assertFalse(returns.data['meta']['canReturn'])
        returned = self.client().post(f'/api/logistique/commandes/{command}/retours', {
            'requestId': str(uuid.uuid4()), '_version': returns.data['meta']['revision'],
            'DateCmd': '2026-10-28T12:00:00', 'motif': 'Retour fictif interdit sur commande',
            'lignes': [{'ID_ArticleFk': article, 'QteRetour': '1', 'Lots': []}],
        }, format='json')
        self.assertEqual(returned.status_code, 409, returned.data)
        for kind in ('entree', 'sortie', 'livraison'):
            response = self.client().get(f'/api/logistique/documents/bon/{command}/{kind}.pdf')
            self.assertEqual(response.status_code, 409, response.data)
        response = self.client().get(f'/api/logistique/documents/bon/{command}/commande.pdf')
        self.assertEqual(response.status_code, 200, response.data if hasattr(response, 'data') else None)
        self.assertTrue(response.content.startswith(b'%PDF-'))
        artifact = ROOT / '.runtime' / 'bons-commande-api' / 'bon-commande.pdf'
        artifact.parent.mkdir(parents=True, exist_ok=True)
        artifact.write_bytes(response.content)

    def test_08_entry_receipt_and_exit_keep_one_actual_movement(self):
        article = self.article()
        receipt = {'requestId': str(uuid.uuid4()), 'ID_TypeCmdFk': self.be, 'ID_DeviseFk': self.currency,
                   'DateCmd': '2026-10-28T12:00:00', 'QteCmdDetail': '5', 'PUCmdDetail': '8', 'Lots': []}
        response = self.client().post(f'/api/logistique/articles/{article}/receptions', receipt, format='json')
        self.assertEqual(response.status_code, 201, response.data)
        self.assertTrue(response.data['data']['bon']['CodeCmd'].startswith('BE-'))
        outgoing = self.create(self.payload(article, kind=self.bs, quantity='2', price='13'))
        self.assertTrue(outgoing['bon']['CodeCmd'].startswith('BS-'))
        self.assertEqual(self.state(article), {'stock': Decimal(3), 'movements': 2, 'lots': 0})
        rejected = self.client().post('/api/logistique/commandes/composees', self.payload(article, kind=self.bs, quantity='20'), format='json')
        self.assertEqual(rejected.status_code, 409, rejected.data)
        self.assertEqual(self.state(article)['stock'], Decimal(3))

    def test_09_cmd_filters_folders_and_excel_keep_document_semantics(self):
        article = self.article(); created = self.create(self.payload(article)); command = created['bon']['ID_Commande']
        response = self.client().get('/api/logistique/registre/commandes', {'typeId': self.cmd, 'payment': 'non-facturee'})
        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(response.data['meta']['filteredCount'], 0)
        response = self.client().get('/api/logistique/registre/factures', {'commandeId': command})
        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(response.data['meta']['filteredCount'], 0)
        response = self.client().get('/api/logistique/registre/commandes/export.csv', {'columns': '["CodeCmd","TypeCmd","MontantTTC"]', 'selection': json.dumps([command])}, HTTP_ACCEPT='text/csv')
        self.assertEqual(response.status_code, 200, response.data if not response.streaming else None)
        rows = list(csv.reader(io.StringIO(b''.join(response.streaming_content).decode('utf-8-sig')), delimiter=';'))
        response.close()
        self.assertEqual(len(rows), 2)
        self.assertEqual(rows[1], [created['bon']['CodeCmd'], 'Bon de commande', '86,38'])
        # Même condition que les dossiers automatiques et le détail de leur indicateur.
        rows, _ = reads.indicator_details(self.actor(), 'commandesNonFacturees', {'q': created['bon']['CodeCmd']})
        self.assertEqual(rows, [])

    def test_10_cmd_can_remove_lines_without_a_source_movement(self):
        article = self.article(); created = self.create(self.payload(article)); command = created['bon']['ID_Commande']
        current = self.client().get(f'/api/logistique/commandes/{command}/composition').data
        payload = {'requestId': str(uuid.uuid4()), 'bon': {}, 'lignes': [], '_version': current['meta']['revision']}
        response = self.client().put(f'/api/logistique/commandes/{command}/composition', payload, format='json')
        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(self.state(article)['movements'], 0)
        self.assertEqual(response.data['data']['lignes'], [])


if __name__ == '__main__':
    unittest.main(verbosity=2)
