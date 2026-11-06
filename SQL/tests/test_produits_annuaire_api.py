"""Annuaire produits : vraie pagination, filtres, licence et projection publiée.

Les écritures de préparation et de recette sont limitées par le garde commun
à une base PostgreSQL privée locale sauverndeko_test_*.
"""
import unittest
import uuid

import test_publication_articles_api as publication
from django.test import override_settings
from rest_framework.test import APIClient

class ProductsDirectoryAPI(unittest.TestCase):
    # Réutiliser uniquement la préparation fictive et les helpers, sans recopier
    # ni relancer implicitement les dix méthodes de la recette Publication.
    setUpClass = publication.ArticlePublicationAPI.__dict__['setUpClass']
    tearDownClass = publication.ArticlePublicationAPI.__dict__['tearDownClass']
    setUp = publication.ArticlePublicationAPI.setUp
    actor = publication.ArticlePublicationAPI.actor
    client = publication.ArticlePublicationAPI.client
    data = publication.ArticlePublicationAPI.data
    body = publication.ArticlePublicationAPI.body
    create = publication.ArticlePublicationAPI.create
    get_article = publication.ArticlePublicationAPI.get_article

    def direct_article(self, index=0, **changes):
        values = {**self.references, 'NomArticle': self.tag + '-offre-' + uuid.uuid4().hex,
            'RefArticle': 'REF_' + uuid.uuid4().hex, 'PUArticle': '7.31', 'PVArticle': '12.50',
            'QteArticle': 0, 'ValideArticle': True, 'VisibleCatalogue': True,
            'IdEntiteFk': self.entities[index], 'ID_UserFK': self.locals[index],
            'ObsArticle': 'INTERNE_' + self.tag, 'InformationArticle': 'CONFIDENTIEL_' + self.tag,
            **changes}
        from psycopg import sql
        return self.connection.execute(sql.SQL('INSERT INTO logistique."T_Article" ({}) VALUES ({}) RETURNING "ID_Article" id').format(
            sql.SQL(',').join(map(sql.Identifier, values)), sql.SQL(',').join(sql.Placeholder() for _ in values)),
            list(values.values())).fetchone()['id']

    def get_list(self, params=None, index=0, **rights):
        return self.data(self.client(index, **rights).get('/api/produits/offres', {'q': self.tag, **(params or {})}))

    def get_detail(self, pk, index=0, **rights):
        return self.data(self.client(index, **rights).get('/api/produits/offres/' + str(pk)))

    def reference(self, field, *, different=None):
        result = self.connection.execute('''SELECT g."ID_Generique" id
            FROM referentiel."T_Generique" g WHERE g."ValideGenerique" IS TRUE AND g."IdEntiteFk" IS NULL
              AND g."ID_CategorieGeneriqueFk"=ANY(referentiel.fn_categories_champ('logistique','T_Article',%s,NULL))
              AND g."ID_Generique"<>%s ORDER BY g."ID_Generique" LIMIT 1''',
            [field, different if different is not None else -1]).fetchone()
        self.assertIsNotNone(result, 'Une autre référence commune doit exister pour ' + field)
        return result['id']

    def test_01_deep_pagination_is_exhaustive_and_stable(self):
        identifiers = [self.direct_article(NomArticle=self.tag + '-article-' + str(number).zfill(3)) for number in range(107)]
        self.direct_article(NomArticle=self.tag + '-prive', VisibleCatalogue=False)
        first = self.get_list({'take': 25})
        self.assertEqual(first['total'], 107)
        self.assertEqual((first['take'], first['skip']), (25, 0))
        all_ids = []
        for skip in range(0, 125, 25):
            page = self.get_list({'take': 25, 'skip': skip}, local=True)
            self.assertEqual(page['total'], 107)
            all_ids.extend(row['ID_Article'] for row in page['rows'])
        self.assertEqual(all_ids, identifiers)
        self.assertEqual(len(set(all_ids)), 107)
        self.assertEqual(self.get_list({'take': 25, 'skip': 107})['rows'], [])

    def test_02_category_type_company_currency_and_stock_filters(self):
        category = self.reference('ID_CategorieArticleFk', different=self.references['ID_CategorieArticleFk'])
        typ = self.reference('ID_TypeArticleFk', different=self.references['ID_TypeArticleFk'])
        currency = self.reference('ID_DeviseFk', different=self.references['ID_DeviseFk'])
        a = self.direct_article(QteArticle=1)
        b = self.direct_article(1, ID_CategorieArticleFk=category, ID_TypeArticleFk=typ, ID_DeviseFk=currency)
        for params, expected in [({'categoryId': category}, b), ({'typeId': typ}, b),
                ({'companyId': self.entities[1]}, b), ({'currencyId': currency}, b),
                ({'availability': 'positive'}, a), ({'availability': 'zero'}, b)]:
            result = self.get_list(params)
            self.assertEqual(result['total'], 1, params)
            self.assertEqual(result['rows'][0]['ID_Article'], expected, params)
        self.assertEqual(self.get_list({'categoryId': category, 'availability': 'positive'})['total'], 0)
        combined = self.get_list({'categoryId': category, 'typeId': typ, 'companyId': self.entities[1],
                                 'currencyId': currency, 'availability': 'zero'})
        self.assertEqual([row['ID_Article'] for row in combined['rows']], [b])

    def test_03_references_come_from_published_offers_only(self):
        pk = self.direct_article()
        hidden_id = self.connection.execute('''INSERT INTO referentiel."T_Generique"
            ("NomGenerique","AbrGenerique","ID_CategorieGeneriqueFk","ValideGenerique","IdEntiteFk")
            SELECT %s,%s,"ID_CategorieGeneriqueFk",true,%s FROM referentiel."T_Generique" WHERE "ID_Generique"=%s
            RETURNING "ID_Generique" id''', [self.tag + '-private-type', 'PRIVATE', self.entities[0], self.references['ID_TypeArticleFk']]).fetchone()['id']
        self.direct_article(ID_TypeArticleFk=hidden_id, VisibleCatalogue=False)
        refs = self.data(self.client(local=True).get('/api/produits/references'))
        for key in ('categories', 'types', 'companies', 'currencies'):
            self.assertIsInstance(refs[key], list)
            self.assertTrue(all(set(item) == {'id', 'label'} for item in refs[key]))
        self.assertIn(self.references['ID_TypeArticleFk'], {item['id'] for item in refs['types']})
        self.assertNotIn(hidden_id, {item['id'] for item in refs['types']})
        self.assertEqual({item['id'] for item in refs['availability']}, {'positive', 'zero'})
        self.assertFalse(refs['canContact'])
        record = self.get_detail(pk)['record']
        self.assertEqual(next(item['label'] for item in refs['types'] if item['id'] == record['ID_TypeArticleFk']), record['TypeArticle'])

    def test_04_search_is_server_side_and_never_queries_internal_notes(self):
        a = self.direct_article(NomArticle='Traitement de démonstration ' + self.tag)
        b = self.direct_article(1, RefArticle='UniqueReference' + self.tag)
        self.assertEqual([row['ID_Article'] for row in self.get_list({'q': 'UniqueReference' + self.tag})['rows']], [b])
        self.assertEqual([row['ID_Article'] for row in self.get_list({'q': 'TRAITEMENT DE DÉMONSTRATION ' + self.tag})['rows']], [a])
        self.assertEqual(self.get_list({'q': 'CONFIDENTIEL_' + self.tag})['total'], 0)
        self.assertEqual(self.get_list({'q': 'INTERNE_' + self.tag})['total'], 0)
        self.assertEqual(self.get_list({'companyId': self.entities[1], 'q': self.tag})['total'], 1)

    def test_05_sort_is_closed_stable_and_no_cross_currency_price_ranking(self):
        a = self.direct_article(NomArticle=self.tag + '-A')
        b = self.direct_article(1, NomArticle=self.tag + '-B')
        self.assertEqual([row['ID_Article'] for row in self.get_list({'sortBy': 'name', 'sortDir': 'desc'})['rows']], [b, a])
        self.assertEqual([row['ID_Article'] for row in self.get_list({'sortBy': 'company', 'sortDir': 'asc'})['rows']], [a, b])
        c = self.direct_article(NomArticle=self.tag + '-A')
        self.assertEqual([row['ID_Article'] for row in self.get_list({'sortBy': 'name', 'sortDir': 'asc'})['rows']], [a, c, b])
        self.data(self.client().get('/api/produits/offres', {'sortBy': 'price'}), 400)

    def test_06_detail_is_minimal_and_locations_are_declared_text_only(self):
        article = self.create(VisibleCatalogue=True)
        self.connection.execute('''INSERT INTO systeme."T_Entite_Localisation"
            ("IdEntiteFk","AdresseDetaillee","Latitude","Longitude")
            VALUES (%s,%s,-4.3,15.3)''', [self.entities[0], 'Adresse déclarée ' + self.tag])
        result = self.get_detail(article['ID_Article'], index=1, local=True)
        self.assertEqual(set(result), {'record', 'locations', 'canContact'})
        row = result['record']
        self.assertEqual(set(row), {'ID_Article','NomArticle','RefArticle','PVArticle','DeviseCode','DeviseLibelle',
            'Unite','EtatDisponibilite','IdEntite','NomEntite','AdresseEntite','PhoneEntite','PhotoArticle',
            'ID_CategorieArticleFk','CategorieArticle','ID_TypeArticleFk','TypeArticle','ID_DeviseFk'})
        self.assertEqual(row['EtatDisponibilite'], 'Stock déclaré')
        self.assertEqual(row['DeviseCode'], 'USD')
        self.assertEqual(row['PVArticle'], '15.75')
        self.assertEqual(len(result['locations']), 1)
        location = result['locations'][0]
        self.assertEqual(set(location), {'label','address','zone','area','site'})
        self.assertEqual(location['address'], 'Adresse déclarée ' + self.tag)
        self.assertIsNone(location['zone'])
        self.assertTrue(result['canContact'])

    def test_07_detail_without_locations_and_depublication(self):
        article = self.create(VisibleCatalogue=True)
        pk = article['ID_Article']
        self.assertEqual(self.get_detail(pk)['locations'], [])
        _, meta = self.get_article(pk)
        self.data(self.client().put(f'/api/logistique/articles/{pk}',
            {'VisibleCatalogue': False, '_version': meta['revision']}, format='json'))
        self.data(self.client().get('/api/produits/offres/' + str(pk)), 404)
        self.assertEqual(self.get_list()['total'], 0)
        self.assertNotIn(self.entities[0], {item['id'] for item in self.data(self.client().get('/api/produits/references'))['companies']})

    def test_08_inactive_articles_and_enterprises_cannot_leak(self):
        hidden = self.direct_article(ValideArticle=False)
        active = self.direct_article(1)
        self.connection.execute('UPDATE systeme."T_Entite" SET "ValideEntite"=false WHERE "IdEntite"=%s', [self.entities[1]])
        for pk in (hidden, active):
            self.data(self.client().get('/api/produits/offres/' + str(pk)), 404)
        self.assertEqual(self.get_list()['total'], 0)

    def test_09_licences_auth_and_contact_rights_remain_separate(self):
        pk = self.direct_article()
        for path in ('/api/produits/references', '/api/produits/offres', '/api/produits/offres/' + str(pk)):
            self.data(APIClient().get(path), 401)
            self.data(self.client(2, local=True).get(path))
        # L’annuaire inclus ne donne pas le droit d’envoyer des messages.
        self.connection.execute('UPDATE systeme."T_Utilisateurs" SET "Is_staff"=false WHERE "IdUser"=%s', [self.locals[0]])
        self.assertFalse(self.actor(local=True).admin)
        self.assertEqual(self.get_detail(pk, local=True)['record']['ID_Article'], pk)
        self.assertFalse(self.get_detail(pk, local=True)['canContact'])
        self.assertFalse(self.data(self.client(local=True).get('/api/produits/references'))['canContact'])
        with override_settings(DB_READ_ONLY=True):
            self.assertFalse(self.get_detail(pk)['canContact'])

    def test_10_invalid_criteria_and_sql_like_characters_are_safe(self):
        pk = self.direct_article(NomArticle='Literal_A_%_' + self.tag)
        self.assertEqual([row['ID_Article'] for row in self.get_list({'q': 'Literal_A_%_' + self.tag})['rows']], [pk])
        self.assertEqual(self.get_list({'q': "%' OR true; SELECT * FROM systeme.\"T_Utilisateurs\" --"})['total'], 0)
        invalid = [{'categoryId': '1 OR 1=1'}, {'typeId': '-1'}, {'companyId': '0'}, {'currencyId': '1.5'},
            {'availability': 'verified'}, {'sortBy': 'NomArticle;DROP TABLE x'}, {'sortDir': 'ASC NULLS FIRST'},
            {'take': '0'}, {'take': '101'}, {'skip': '-1'}, {'skip': '2147483648'}, {'take': '1.5'},
            {'q': 'x' * 301}, {'q': 'a\nb'}, {'secret': 'true'}]
        for params in invalid:
            self.data(self.client().get('/api/produits/offres', params), 400)
        self.data(self.client().get('/api/produits/offres?q=a&q=b'), 400)
        self.data(self.client().get('/api/produits/references?companyId=1'), 400)
        self.data(self.client().get('/api/produits/offres/' + str(pk), {'q': self.tag}), 400)

    def test_11_all_directory_reads_leave_stock_events_and_messages_unchanged(self):
        pk = self.direct_article(QteArticle=1)
        def proof():
            result = {}
            for schema, name in [('logistique','T_Article'), ('logistique','T_Commande'), ('logistique','T_Mouvement'),
                                  ('analytics','T_Recherche'), ('communication','T_Discussion'), ('communication','T_Chat')]:
                result[schema + '.' + name] = self.connection.execute('SELECT count(*) n FROM "' + schema + '"."' + name + '"').fetchone()['n']
            result['article'] = self.connection.execute('SELECT to_jsonb(a) value FROM logistique."T_Article" a WHERE "ID_Article"=%s', [pk]).fetchone()['value']
            return result
        before = proof()
        self.get_list({'q': self.tag})
        self.get_detail(pk)
        self.data(self.client().get('/api/produits/references'))
        self.assertEqual(proof(), before)

    def test_12_legacy_catalogue_contract_remains_unchanged(self):
        pk = self.direct_article()
        response = self.client().get('/api/public/articles', {'q': self.tag})
        rows = self.data(response)
        self.assertEqual(rows[0]['ID_Article'], pk)
        self.assertEqual(response.data['meta']['total'], 1)
        self.assertNotIn('CategorieArticle', rows[0])
        self.assertIn('CategorieArticle', self.get_detail(pk)['record'])
        self.assertNotIn('ID_DeviseFk', rows[0])


if __name__ == '__main__':
    unittest.main(verbosity=2)
