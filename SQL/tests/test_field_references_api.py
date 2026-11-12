"""Référencement : API et helpers réels, exclusivement PostgreSQL privé fictif."""
import csv
import hashlib
import io
import json
import os
import sys
import unittest
import uuid
import zipfile
from pathlib import Path
from urllib.parse import urlsplit
from xml.etree import ElementTree as ET

import psycopg
from psycopg.rows import dict_row

ROOT = Path(__file__).resolve().parents[2]
DSN = os.environ.get('SAUVERNDEKO_TEST_DATABASE_URL', '')
location = urlsplit(DSN)
if location.hostname not in {'localhost', '127.0.0.1', '::1'} or not location.path[1:].startswith('sauverndeko_test_'):
    raise RuntimeError('Recette réservée à PostgreSQL privé local sauverndeko_test_*.')
with psycopg.connect(DSN) as check:
    if not check.execute('SELECT current_database()').fetchone()[0].startswith('sauverndeko_test_'):
        raise RuntimeError('Base privée requise.')
os.environ.update(DATABASE_URL=DSN, DJANGO_SETTINGS_MODULE='config.settings', SAUVERNDEKO_DB_READ_ONLY='0')
sys.path.insert(0, str(ROOT/'backend'))
import django
django.setup()
from django.db import transaction
from django.test import override_settings
from rest_framework.test import APIClient
from apps.accounts.authentication import Actor
from apps.core import db
from apps.core import field_references as service
from apps.core.module_access import MODULE_BY_KEY

BASE = '/api/referentiel/champs-references'


class FieldReferencesAPI(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.settings = override_settings(ALLOWED_HOSTS=['testserver'])
        cls.settings.enable()
        cls.sql = psycopg.connect(DSN, autocommit=True, row_factory=dict_row)
        cls.entities = [cls.sql.execute('INSERT INTO systeme."T_Entite"("NomEntite","EmailEntite","ValideEntite") '
            'VALUES(%s,%s,true) RETURNING "IdEntite" id', ['Références fictives '+uuid.uuid4().hex,
            uuid.uuid4().hex+'@example.invalid']).fetchone()['id'] for _ in range(3)]
        cls.users = [cls.sql.execute('''INSERT INTO systeme."T_Utilisateurs"
            ("NomUser","PrenomUser","EmailUser","MotdepasseUser","ValideUser","SexeUser","Is_Admin","Is_staff","IdEntiteFk")
            VALUES('Fictif','Références',%s,'inutilisable',true,'M',true,true,%s) RETURNING *''',
            [uuid.uuid4().hex+'@example.invalid', entity]).fetchone() for entity in cls.entities]
        cls.fields = cls.sql.execute('SELECT * FROM referentiel."T_ChampReferentiel" ORDER BY "ID_ChampReferentiel"').fetchall()
        cls.field = next(f for f in cls.fields if (f['SchemaName'], f['TableName'], f['ColumnName']) ==
                         ('logistique', 'T_Article', 'ID_CategorieArticleFk'))
        cls.field_id = cls.field['ID_ChampReferentiel']
        cls.path = BASE+'/'+str(cls.field_id)
        cls.categories = [cls.sql.execute('INSERT INTO referentiel."T_CategorieGenerique" '
            '("NomCategorieGenerique","ModuleCategorieGenerique","ValideCategorieGenerique") VALUES(%s,\'RECETTE_FICTIVE\',true) '
            'RETURNING "ID_CategorieGenerique" id', ['Famille fictive '+uuid.uuid4().hex]).fetchone()['id'] for _ in range(2)]
        cls.generics = [cls.sql.execute('INSERT INTO referentiel."T_Generique" '
            '("ID_CategorieGeneriqueFk","NomGenerique","AbrGenerique","ValideGenerique") VALUES(%s,%s,%s,true) '
            'RETURNING "ID_Generique" id', [category,'Libellé fictif '+str(n),'REF-'+str(n)]).fetchone()['id']
            for n, category in enumerate(cls.categories)]

    @classmethod
    def tearDownClass(cls):
        cls.sql.close(); cls.settings.disable()

    def setUp(self):
        # Toutes les modifications de configuration sont annulées entre recettes.
        self.tx = transaction.atomic(); self.tx.__enter__()

    def tearDown(self):
        transaction.set_rollback(True); self.tx.__exit__(None, None, None)

    @classmethod
    def actor(cls, index=0, *, global_admin=True, read=True, manage=True, export=True):
        actor = Actor({**cls.users[index], 'Is_Admin': global_admin})
        actor._context_entity = cls.entities[index]
        actor._module_access = {'modules': {key: {'canRead': read, 'canManage': manage, 'canExport': export,
            'reason': 'MODULE_ROLE_FORBIDDEN'} for key in MODULE_BY_KEY}}
        return actor

    @classmethod
    def client(cls, index=0, **rights):
        client = APIClient(); client.force_authenticate(cls.actor(index, **rights)); return client

    def response(self, result, status=200):
        self.assertEqual(result.status_code, status, getattr(result, 'data', 'Réponse binaire'))
        return getattr(result, 'data', {}).get('data')

    def detail(self, *, index=0, scope='global', path=None):
        raw = {'scope': scope}
        if scope == 'entity': raw['scopeValue'] = self.entities[index]
        return self.response(self.client(index).get(path or self.path, raw))

    def put(self, category=None, *, scope='global', index=0, current=None, path=None, **changes):
        record = current or self.detail(scope=scope, index=index, path=path)
        body = {'scope': scope, '_version': record['_version'], 'categoryIds': [category or self.categories[0]],
                'requestId': str(uuid.uuid4()), 'motif': 'Recette fictive du référencement'}
        if scope == 'entity': body['scopeValue'] = self.entities[index]
        body.update(changes)
        return self.client(index).put(path or self.path, body, format='json'), body

    def restore(self, *, scope='global', index=0, path=None):
        old = self.detail(scope=scope, index=index, path=path)
        body = {'scope': scope, '_version': old['_version'], 'requestId': str(uuid.uuid4()), 'motif': 'Restaurer le défaut fictif'}
        if scope == 'entity': body['scopeValue'] = self.entities[index]
        return self.client(index).post((path or self.path)+'/retablir', body, format='json'), body

    def article(self):
        actor = self.actor()
        def chosen(field):
            return service.reference_options(actor, 'logistique', 'T_Article', field)[0]['id']
        return self.response(self.client().post('/api/logistique/articles', {
            'NomArticle': 'Article fictif '+uuid.uuid4().hex, 'ID_CategorieArticleFk': chosen('ID_CategorieArticleFk'),
            'ID_TypeArticleFk': chosen('ID_TypeArticleFk'), 'ID_UniteFk': chosen('ID_UniteFk'),
            'PUArticle': '10.00', 'PVArticle': '15.00', 'QteArticle': '0', 'ValideArticle': True,
            'requestId': str(uuid.uuid4())}, format='json'), 201)

    def test_01_real_catalogue_defaults_and_detail(self):
        rows = self.response(self.client().get(BASE, {'q': 'T_Article', 'take': 2, 'sortBy': 'ColumnName'}))
        self.assertEqual(len(rows), 2)
        self.assertTrue(all(row['TableName'] == 'T_Article' for row in rows))
        record = self.detail()
        self.assertEqual(record['DefaultCategoryId'], self.field['ID_CategorieDefautFk'])
        self.assertEqual(record['SchemaName'], 'logistique')
        self.assertTrue(record['_version'])
        self.assertIsInstance(record['categories'], list)
        self.assertIsInstance(record['incompatibleExistingCount'], int)
        prefs = self.response(self.client().get('/api/tableaux/referentiels.champs/preferences'))
        self.assertEqual(prefs['table']['columns'], [*service.DEFAULT_FIELDS, 'actions'])

    def test_02_configuration_options_sql_and_no_business_change(self):
        before = db.one('SELECT count(*) n,coalesce(sum("QteArticle"),0) quantity FROM logistique."T_Article"')
        changed = self.response(self.put()[0])
        self.assertEqual(changed['categoryIds'], [self.categories[0]])
        options = service.reference_options(self.actor(), 'logistique', 'T_Article', 'ID_CategorieArticleFk')
        self.assertEqual([o['id'] for o in options], [self.generics[0]])
        self.assertEqual(options[0]['label'], 'REF-0')
        self.assertEqual(options[0]['name'], 'Libellé fictif 0')
        self.assertTrue(db.one('SELECT referentiel.fn_valider_reference_champ(%s,%s,%s,%s,%s) valid',
            ['logistique', 'T_Article', 'ID_CategorieArticleFk', self.generics[0], self.entities[0]])['valid'])
        self.assertEqual(db.one('SELECT count(*) n,coalesce(sum("QteArticle"),0) quantity FROM logistique."T_Article"'), before)

    def test_03_entity_priority_and_explicit_restore(self):
        self.response(self.put()[0])
        self.response(self.put(self.categories[1], scope='entity')[0])
        own = service.reference_context(self.actor(), 'logistique', 'T_Article', 'ID_CategorieArticleFk')
        foreign = service.reference_context(self.actor(1), 'logistique', 'T_Article', 'ID_CategorieArticleFk')
        self.assertEqual(own['categoryIds'], [self.categories[1]])
        self.assertEqual(foreign['categoryIds'], [self.categories[0]])
        restored = self.response(self.restore(scope='entity')[0])
        self.assertEqual(restored['categoryIds'], [self.field['ID_CategorieDefautFk']])
        self.assertEqual(restored['effectiveSource'], 'default')
        self.assertEqual(service.reference_context(self.actor(1), 'logistique', 'T_Article', 'ID_CategorieArticleFk')['categoryIds'], [self.categories[0]])

    def test_04_null_default_restore_does_not_inherit(self):
        # Une évolution peut compléter tous les défauts de production. Ce cas
        # crée donc sa propre définition, adossée à une vraie FK existante,
        # dans la transaction privée annulée en fin de test.
        field = db.one('''INSERT INTO referentiel."T_ChampReferentiel"
            ("SchemaName","TableName","ColumnName","ChampLabel","ModuleName",
             "ID_CategorieDefautFk","CanConfigure","SupportsEntityScope")
            VALUES('professionnel','T_SynonymeRecherche','IdGeneriqueFk',
             'Référence lexicale fictive','professionnel',NULL,true,false)
            RETURNING *''')
        path = BASE+'/'+str(field['ID_ChampReferentiel'])
        self.response(self.put(path=path)[0])
        result = self.response(self.restore(path=path)[0])
        self.assertEqual(result['categoryIds'], [])
        self.assertFalse(result['configured'])
        self.assertIsNone(result['DefaultCategoryId'])

    def test_05_replay_revision_and_reason(self):
        current = self.detail()
        answer, body = self.put(current=current)
        self.response(answer)
        replay = self.client().put(self.path, body, format='json')
        self.response(replay); self.assertTrue(replay.data['meta']['replayed'])
        self.response(self.client().put(self.path, {**body, 'motif': 'Autre contenu'}, format='json'), 409)
        self.response(self.put(current=current)[0], 409)
        audit = self.response(self.client().get(self.path+'/historique'))
        self.assertEqual(len(audit), 1)
        self.assertEqual(audit[0]['NewData']['requestId'], body['requestId'])
        self.response(self.put(motif='')[0], 400)
        self.response(self.put(requestId='invalide')[0], 400)

    def test_06_protected_roles_and_writes_restricted(self):
        protected = next(f for f in self.fields if f['TableName'] == 'T_Utilisateurs' and f['ColumnName'] == 'IdRoleFk')
        self.response(self.put(path=BASE+'/'+str(protected['ID_ChampReferentiel']))[0], 403)
        self.response(self.client(global_admin=False).get(BASE), 403)
        self.response(self.client(global_admin=False).get(self.path), 403)
        self.response(self.client(global_admin=False).get(self.path+'/historique'), 403)
        with override_settings(DB_READ_ONLY=True): self.response(self.put()[0], 503)
        self.response(self.client(read=False).get(BASE), 403)
        self.response(APIClient().get(BASE), 401)
        limited = self.client(manage=False,export=False).get(BASE)
        self.response(limited)
        self.assertFalse(limited.data['meta']['canExport'])

    def test_07_single_active_category_and_immutable_defaults(self):
        inactive = db.one('INSERT INTO referentiel."T_CategorieGenerique"("NomCategorieGenerique","ValideCategorieGenerique") '
                          'VALUES(%s,false) RETURNING "ID_CategorieGenerique" id', ['Inactif fictif '+uuid.uuid4().hex])['id']
        for changes in [{'categoryIds': []}, {'categoryIds': self.categories}, {'categoryIds': [True]},
                        {'categoryIds': ['abc']}, {'DefaultCategoryId': self.categories[0]}, {'categoryIds': [inactive]}]:
            self.response(self.put(**changes)[0], 400)
        self.response(self.put(scope='country', current=self.detail())[0], 400)
        self.response(self.client().get(BASE, {'scope': 'entity', 'scopeValue': 2147483600}), 404)

    def test_08_retained_values_and_visibility_do_not_fallback(self):
        self.response(self.put()[0])
        old = db.one('SELECT "ID_Generique" id FROM referentiel."T_Generique" WHERE "ID_CategorieGeneriqueFk"=%s LIMIT 1', [self.field['ID_CategorieDefautFk']])['id']
        retained = service.reference_options(self.actor(), 'logistique', 'T_Article', 'ID_CategorieArticleFk', old)
        item = next(o for o in retained if o['id'] == old)
        self.assertTrue(item['disabled']); self.assertTrue(item['incompatible'])
        db.query('UPDATE referentiel."T_Generique" SET "NomGenerique"=%s,"AbrGenerique"=%s WHERE "ID_Generique"=%s', ['Nom historique non affiché',' RETENU-ABR ',old])
        again = service.reference_options(self.actor(), 'logistique', 'T_Article', 'ID_CategorieArticleFk', old)
        kept = next(o for o in again if o['id'] == old)
        self.assertEqual(kept['label'], 'RETENU-ABR'); self.assertEqual(kept['id'], old)
        self.assertTrue(kept['disabled']); self.assertTrue(kept['incompatible'])
        db.query('UPDATE referentiel."T_Generique" SET "VisibleArticle"=false WHERE "ID_Generique"=%s', [self.generics[0]])
        self.assertEqual(service.reference_options(self.actor(), 'logistique', 'T_Article', 'ID_CategorieArticleFk', visibility={'VisibleArticle': True}), [])
        db.query('UPDATE referentiel."T_Generique" SET "AbrGenerique"=\'  \',"NomGenerique"=\'Nom de remplacement\' WHERE "ID_Generique"=%s', [self.generics[0]])
        self.assertEqual(service.reference_options(self.actor(), 'logistique', 'T_Article', 'ID_CategorieArticleFk')[0]['label'], 'Valeur sans abréviation #'+str(self.generics[0]))

    def test_09_normal_lookup_scope_rights_and_closed_targets(self):
        self.response(self.put(scope='entity')[0])
        raw = {'schema': 'logistique', 'table': 'T_Article', 'column': 'ID_CategorieArticleFk'}
        result = self.response(self.client(global_admin=False).get(BASE+'/valeurs', raw))
        self.assertEqual(result['categoryIds'], [self.categories[0]])
        self.assertEqual(result['options'][0]['id'], self.generics[0])
        self.assertNotIn('existingCount', result)
        self.response(self.client(read=False).get(BASE+'/valeurs', raw), 403)
        self.response(self.client().get(BASE+'/valeurs', {**raw, 'column': 'MotdepasseUser'}), 404)
        self.response(self.client().get(BASE+'/valeurs', {**raw, 'table': 'T_Article;DROP TABLE'}), 404)
        self.response(self.client().get(BASE+'/valeurs', {**raw, 'visibility': '{"MotdepasseUser":true}'}), 400)
        self.response(self.client().get(BASE+'/valeurs', {**raw, 'scopeValue': self.entities[1]}), 400)

    def test_10_register_filters_exports_selection_and_preferences(self):
        raw = {'q': 'T_Article', 'filters': json.dumps({'SchemaName': 'logistique'}), 'sortBy': 'ColumnName', 'sortDir': 'desc', 'take': 1}
        listed = self.response(self.client().get(BASE, {**raw, 'take': 500}))
        self.assertTrue(listed)
        fields = ['ColumnName', 'DefaultCategoryId', 'SchemaName']
        exported = self.client().get(BASE+'/export.csv', {**raw, 'columns': json.dumps(fields)})
        self.assertEqual(exported.status_code, 200)
        rows = list(csv.reader(io.StringIO(b''.join(exported.streaming_content).decode('utf-8-sig')), delimiter=';'))
        self.assertEqual(rows[0], [service.LABELS[k] for k in fields])
        self.assertEqual([r[0] for r in rows[1:]], [r['ColumnName'] for r in listed])
        selected = self.client().get(BASE+'/export.csv', {**raw, 'columns': json.dumps(fields), 'selection': json.dumps([listed[-1]['ID_ChampReferentiel']])})
        selected_rows = list(csv.reader(io.StringIO(b''.join(selected.streaming_content).decode('utf-8-sig')), delimiter=';'))
        self.assertEqual(len(selected_rows), 2); self.assertEqual(selected_rows[1][0], listed[-1]['ColumnName'])
        xlsx = self.client().get(BASE+'/export.xlsx', {**raw, 'columns': json.dumps(fields)})
        self.assertEqual(xlsx.status_code, 200)
        with zipfile.ZipFile(io.BytesIO(b''.join(xlsx.streaming_content))) as book:
            sheet = ET.fromstring(book.read('xl/worksheets/sheet1.xml'))
            ns = {'s': 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
            self.assertEqual(len(sheet.findall('s:sheetData/s:row', ns)), len(listed)+1)
        self.response(self.client().get(BASE+'/export.csv', {'columns': '["MotdepasseUser"]'}), 400)
        self.response(self.client(global_admin=False).get(BASE+'/export.csv'), 403)

    def test_11_invoice_reference_families_delay_and_retained_values(self):
        from apps.logistique.invoices import payment_references
        fields = {f['ColumnName']: f for f in self.fields if f['TableName'] == 'T_Commande'}
        mode_path = BASE+'/'+str(fields['ID_ModePaiementFk']['ID_ChampReferentiel'])
        condition_path = BASE+'/'+str(fields['ID_ConditionPaiementFk']['ID_ChampReferentiel'])
        original = payment_references(actor=self.actor())
        old_mode = original['modesPaiement'][0]['id']
        self.response(self.put(path=mode_path)[0])
        self.response(self.put(self.categories[1], path=condition_path)[0])
        db.query('UPDATE referentiel."T_Generique" SET "NomGenerique"=\'14 Jours\',"AbrGenerique"=\'J14\' WHERE "ID_Generique"=%s', [self.generics[1]])
        configured = payment_references({'ID_ModePaiementFk': old_mode}, actor=self.actor())
        self.assertEqual(configured['conditionsPaiement'][0]['label'], 'J14')
        self.assertEqual(configured['conditionsPaiement'][0]['delayDays'], 14)
        retained = next(r for r in configured['modesPaiement'] if r['id'] == old_mode)
        self.assertTrue(retained['disabled']); self.assertFalse(retained['active'])
        self.assertTrue(any(r['id'] == self.generics[0] for r in configured['modesPaiement']))

    def test_12_currency_per_field_and_historical_preservation(self):
        from apps.logistique.currency import default_currency, validate_currency
        original = default_currency(self.actor(), table='T_Commande')
        family = db.one('INSERT INTO referentiel."T_CategorieGenerique"("NomCategorieGenerique","ValideCategorieGenerique") '
            'VALUES(%s,true) RETURNING "ID_CategorieGenerique" id', ['Devises fictives '+uuid.uuid4().hex])['id']
        currency = db.one('INSERT INTO referentiel."T_Generique"("ID_CategorieGeneriqueFk","NomGenerique","AbrGenerique","ValideGenerique") '
            'VALUES(%s,\'Dollar de recette\',\'USD\',true) RETURNING "ID_Generique" id', [family])['id']
        field = next(f for f in self.fields if f['TableName'] == 'T_Commande' and f['ColumnName'] == 'ID_DeviseFk')
        self.response(self.put(family, scope='entity', path=BASE+'/'+str(field['ID_ChampReferentiel']))[0])
        self.assertEqual(default_currency(self.actor(), table='T_Commande')['id'], currency)
        self.assertNotEqual(default_currency(self.actor(), table='T_Article')['id'], currency)
        retained = validate_currency(original['id'], unchanged=True, actor=self.actor(), table='T_Commande')
        self.assertEqual(retained['id'], original['id']); self.assertEqual(retained['code'], 'USD')
        self.assertEqual(default_currency(self.actor(1), table='T_Commande')['id'], original['id'])

    def test_13_business_fk_preserved_and_new_choices_effective(self):
        actor = self.actor()
        def chosen(field):
            return service.reference_options(actor, 'logistique', 'T_Article', field)[0]['id']
        body = {'NomArticle': 'Article fictif '+uuid.uuid4().hex, 'ID_CategorieArticleFk': chosen('ID_CategorieArticleFk'),
                'ID_TypeArticleFk': chosen('ID_TypeArticleFk'), 'ID_UniteFk': chosen('ID_UniteFk'),
                'PUArticle': '10.00', 'PVArticle': '15.00', 'QteArticle': '0', 'ValideArticle': True,
                'requestId': str(uuid.uuid4())}
        created = self.response(self.client().post('/api/logistique/articles', body, format='json'), 201)
        pk = created['ID_Article']
        before = db.one('SELECT "ID_CategorieArticleFk","QteArticle" FROM logistique."T_Article" WHERE "ID_Article"=%s', [pk])
        changed = self.response(self.put(scope='entity')[0])
        self.assertGreaterEqual(changed['incompatibleExistingCount'], 1)
        self.assertEqual(db.one('SELECT "ID_CategorieArticleFk","QteArticle" FROM logistique."T_Article" WHERE "ID_Article"=%s', [pk]), before)
        response = self.client().get('/api/logistique/articles/'+str(pk))
        current = self.response(response)
        edited = self.response(self.client().put('/api/logistique/articles/'+str(pk),
            {'NomArticle': 'Identité fictive corrigée', '_version': response.data['meta']['revision']}, format='json'))
        self.assertEqual(edited['ID_CategorieArticleFk'], before['ID_CategorieArticleFk'])
        added = self.response(self.client().post('/api/logistique/articles',
            {**body, 'requestId': str(uuid.uuid4()), 'NomArticle': 'Nouvelle famille fictive', 'ID_CategorieArticleFk': self.generics[0]}, format='json'), 201)
        self.assertEqual(added['ID_CategorieArticleFk'], self.generics[0])
        self.assertEqual(db.one('SELECT count(*) n FROM logistique."T_Mouvement" WHERE "ID_ArticleFk"=ANY(%s::integer[])', [[pk, added['ID_Article']]])['n'], 0)

    def test_14_receipt_price_and_currency_need_confirmation_without_conversion(self):
        article = self.article()
        path = '/api/logistique/articles/'+str(article['ID_Article'])+'/receptions'
        before = self.response(self.client().get(path))
        self.assertFalse(before['currencyToConfirm'])
        self.assertEqual(str(before['defaults']['PUCmdDetail']), '10.00')
        field = next(f for f in self.fields if f['TableName'] == 'T_Commande' and f['ColumnName'] == 'ID_DeviseFk')
        self.response(self.put(scope='entity', path=BASE+'/'+str(field['ID_ChampReferentiel']))[0])
        after = self.response(self.client().get(path))
        self.assertTrue(after['currencyToConfirm']); self.assertTrue(after['priceToConfirm'])
        self.assertIsNone(after['defaults']['ID_DeviseFk']); self.assertIsNone(after['defaults']['PUCmdDetail'])
        self.assertEqual(after['article']['PUArticle'], before['article']['PUArticle'])
        self.assertEqual(after['article']['ID_DeviseFk'], before['article']['ID_DeviseFk'])

    def test_15_professional_and_entity_references_share_field_configuration(self):
        from apps.logistique.entity_documents import entity_types, profile
        fields = {(f['TableName'], f['ColumnName']): f for f in self.fields}
        for name in ('ID_ServiceFk', 'ID_FonctionFk'):
            self.response(self.put(scope='entity', path=BASE+'/'+str(fields[('T_Utilisateurs',name)]['ID_ChampReferentiel']))[0])
        personnel = self.response(self.client().get('/api/systeme/personnel/references'))
        self.assertEqual([v['id'] for v in personnel['personnelServices']], [self.generics[0]])
        self.assertEqual([v['label'] for v in personnel['personnelFonctions']], ['REF-0'])
        field = fields[('T_Entite','IdTypeEntiteFk')]
        self.response(self.put(scope='entity', path=BASE+'/'+str(field['ID_ChampReferentiel']))[0])
        self.assertEqual([v['id'] for v in entity_types(self.entities[0],actor=self.actor())], [self.generics[0]])
        result = profile(self.actor(),self.entities[0],administration=True)
        self.assertEqual(result['references']['entityTypes'][0]['label'], 'REF-0')
        self.assertNotIn(self.generics[0], [v['id'] for v in entity_types(self.entities[1],actor=self.actor())])
        # Créer une entreprise utilise la portée globale, jamais la surcharge
        # de l'entreprise depuis laquelle l'administrateur a ouvert la page.
        defaults = self.response(self.client().get('/api/systeme/entites/identite-defaut'))
        self.assertNotIn(self.generics[0], [v['id'] for v in defaults['references']['entityTypes']])
        roles = self.response(self.client().get('/api/systeme/administration/registres/roles', {'take':500}))
        allowed = service.reference_context(self.actor(),'systeme','T_Utilisateurs','IdRoleFk')['categoryIds']
        self.assertTrue(all(v['ID_CategorieGeneriqueFk'] in allowed for v in roles))

    def test_16_legacy_override_revision_and_explicit_default(self):
        self.assertTrue(self.field['AliasSourceKeys'])
        previous = self.detail(scope='entity')
        db.one('''INSERT INTO systeme."T_Fk_Correspondance"
            ("ModuleName","SchemaName","SourceKey","FieldName","MappingType","ReferenceSchemaName",
             "ReferenceObjectName","ReferenceFieldName","MappingValue","TargetCategoryIdFk","SettingScope","ScopeValue","ValideFkCorrespondance")
            VALUES('RECETTE_FICTIVE','logistique',%s,'ID_CategorieArticleFk','generic_category','referentiel',
             'T_Generique','ID_Generique',%s,%s,'entity',%s,true) RETURNING "IdFkCorrespondance"''',
            [self.field['AliasSourceKeys'][0],str(self.categories[1]),self.categories[1],str(self.entities[0])])
        legacy = self.detail(scope='entity')
        self.assertNotEqual(legacy['_version'], previous['_version'])
        self.assertEqual(legacy['categoryIds'], [self.categories[1]])
        self.assertEqual(legacy['effectiveSource'], 'legacy')
        self.response(self.put(scope='entity', current=previous)[0],409)
        canonical = self.response(self.put(scope='entity')[0])
        self.assertEqual(canonical['categoryIds'], [self.categories[0]])
        self.assertEqual(canonical['effectiveSource'],'canonical')
        restored = self.response(self.restore(scope='entity')[0])
        self.assertEqual(restored['categoryIds'], [self.field['ID_CategorieDefautFk']])
        self.assertEqual(restored['effectiveSource'],'default')

    def test_17_type_metadata_and_inherited_parent_info(self):
        from apps.logistique.receipts import entry_types
        family = db.one('INSERT INTO referentiel."T_CategorieGenerique"("NomCategorieGenerique","ValideCategorieGenerique") '
            'VALUES(%s,true) RETURNING "ID_CategorieGenerique" id',['Bons fictifs '+uuid.uuid4().hex])['id']
        for label,code in [('Réception fictive','Entrée'),('Expédition fictive','Sortie'),('Projet fictif','CMD')]:
            db.one('INSERT INTO referentiel."T_Generique"("ID_CategorieGeneriqueFk","NomGenerique","AbrGenerique","ValideGenerique") '
                'VALUES(%s,%s,%s,true) RETURNING "ID_Generique" id',[family,label,code])
        field = next(f for f in self.fields if f['TableName']=='T_Commande' and f['ColumnName']=='ID_TypeCmdFk')
        self.response(self.put(family,scope='entity',path=BASE+'/'+str(field['ID_ChampReferentiel']))[0])
        rows = service.reference_options(self.actor(),'logistique','T_Commande','ID_TypeCmdFk')
        self.assertEqual({v['kind']:v['stockEffect'] for v in rows},{'entree':1,'sortie':-1,'commande':0})
        self.assertEqual([(v['label'],v['canInvoice']) for v in rows if v['kind']=='sortie'], [('Sortie',True)])
        self.assertEqual([v['kind'] for v in entry_types(self.actor())], ['entree'])
        movement = next(f for f in self.fields if f['TableName']=='T_Mouvement' and f['ColumnName']=='ID_TypeMvtFk')
        inherited = self.detail(path=BASE+'/'+str(movement['ID_ChampReferentiel']))
        self.assertTrue(inherited['ReferenceHeriteeParent'])

    def test_18_all_logistics_reference_consumers_use_effective_categories(self):
        targets = [('T_Article','ID_CategorieArticleFk','articleCategories'),
                   ('T_Immobilisation','ID_CategorieFk','types'),('T_Client','ID_TypeClientFk','typesClients')]
        for table,column,_ in targets:
            field=next(f for f in self.fields if f['TableName']==table and f['ColumnName']==column)
            self.response(self.put(scope='entity',path=BASE+'/'+str(field['ID_ChampReferentiel']))[0])
        for route,key in [('/api/logistique/references','articleCategories'),
                          ('/api/logistique/immobilisations/references','types'),
                          ('/api/logistique/tiers/references','typesClients')]:
            answer=self.response(self.client().get(route))
            self.assertEqual([v['id'] for v in answer[key]],[self.generics[0]],route)
            self.assertEqual(answer[key][0]['label'],'REF-0')
            foreign=self.response(self.client(1).get(route))
            self.assertNotIn(self.generics[0],[v['id'] for v in foreign[key]])

    def test_19_tiers_historical_fk_stays_editable_after_remapping(self):
        before=self.response(self.client().get('/api/logistique/tiers/references'))
        old_type=before['typesClients'][0]['id']
        created=self.response(self.client().post('/api/logistique/tiers',{'Nom':'Tiers fictif '+uuid.uuid4().hex,
            'Nature':'personne','ID_TypeClientFk':old_type,'requestId':str(uuid.uuid4())},format='json'),201)
        path='/api/logistique/tiers/'+str(created['ID_Client'])
        field=next(f for f in self.fields if f['TableName']=='T_Client' and f['ColumnName']=='ID_TypeClientFk')
        self.response(self.put(scope='entity',path=BASE+'/'+str(field['ID_ChampReferentiel']))[0])
        shown=self.client().get(path);self.response(shown)
        changed=self.response(self.client().put(path,{'Nom':'Tiers fictif corrigé','_version':shown.data['meta']['revision']},format='json'))
        self.assertEqual(changed['ID_TypeClientFk'],old_type)
        added=self.response(self.client().post('/api/logistique/tiers',{'Nom':'Nouvelle famille fictive',
            'Nature':'personne','ID_TypeClientFk':self.generics[0],'requestId':str(uuid.uuid4())},format='json'),201)
        self.assertEqual(added['ID_TypeClientFk'],self.generics[0])
        self.response(self.client(1,global_admin=False).get(path),404)

    def test_20_canonical_correspondence_refuses_generic_crud(self):
        self.response(self.put(scope='entity')[0])
        row=db.one('SELECT "IdFkCorrespondance" id FROM systeme."T_Fk_Correspondance" WHERE "IdChampReferentielFk"=%s '
            'AND "SettingScope"=\'entity\' AND "ScopeValue"=%s',[self.field_id,str(self.entities[0])])
        path='/api/systeme/fk-correspondances/'+str(row['id'])
        self.response(self.client().put(path,{'MappingValue':str(self.categories[1])},format='json'),405)
        self.response(self.client().delete(path),405)
        self.response(self.client().post('/api/systeme/fk-correspondances',{'IdChampReferentielFk':self.field_id},format='json'),405)
        self.response(self.client().put('/api/models/T_Fk_Correspondance/'+str(row['id']),{},format='json'),403)
        self.assertEqual(self.detail(scope='entity')['categoryIds'],[self.categories[0]])

    def test_21_legacy_settings_reads_canonical_and_cannot_reset_it(self):
        from apps.core.ui_settings import SOURCES
        alias=next(key for key in self.field['AliasSourceKeys'] if key in SOURCES['generic'])
        self.response(self.put(scope='entity')[0])
        criteria={'scope':'entity','scopeValue':str(self.entities[0])}
        route='/api/systeme/admin-ui-settings'
        read=self.response(self.client().get(route,criteria))
        self.assertEqual(read['genericCategoryOverrides'][alias],str(self.categories[0]))
        self.response(self.client().put(route,{**criteria,'genericCategoryOverrides':{alias:str(self.categories[1])}},format='json'),409)
        before=db.query('SELECT * FROM systeme."T_Fk_Correspondance" WHERE "IdChampReferentielFk"=%s AND "SettingScope"=\'entity\' '
            'AND "ScopeValue"=%s',[self.field_id,str(self.entities[0])])
        hierarchy=next(iter(SOURCES['hierarchy']))
        self.response(self.client().put(route,{**criteria,'hierarchyFilterModes':{hierarchy:'all'}},format='json'))
        after=db.query('SELECT * FROM systeme."T_Fk_Correspondance" WHERE "IdChampReferentielFk"=%s AND "SettingScope"=\'entity\' '
            'AND "ScopeValue"=%s',[self.field_id,str(self.entities[0])])
        self.assertEqual(after,before)
        self.assertEqual(self.detail(scope='entity')['categoryIds'],[self.categories[0]])

    def test_22_category_filter_includes_inherited_multiple_categories(self):
        for index,category in enumerate(self.categories):
            db.one('''INSERT INTO systeme."T_Fk_Correspondance"
                ("ModuleName","SchemaName","SourceKey","FieldName","MappingType","ReferenceSchemaName",
                 "ReferenceObjectName","ReferenceFieldName","MappingValue","TargetCategoryIdFk","SettingScope","ScopeValue","ValideFkCorrespondance","DisplayOrder")
                VALUES('RECETTE_FICTIVE','logistique',%s,'ID_CategorieArticleFk','generic_category','referentiel',
                 'T_Generique','ID_Generique',%s,%s,'entity',%s,true,%s) RETURNING "IdFkCorrespondance"''',
                [self.field['AliasSourceKeys'][0],str(category),category,str(self.entities[0]),1-index])
        raw={'scope':'entity','scopeValue':str(self.entities[0]),'filters':json.dumps({'CategoryIds':[self.categories[0]]})}
        found=self.response(self.client().get(BASE,raw))
        row=next(v for v in found if v['ID_ChampReferentiel']==self.field_id)
        self.assertEqual(set(row['CategoryIds']),set(self.categories))
        labels={v['id']:v['name'] for v in db.query('SELECT "ID_CategorieGenerique" id,"NomCategorieGenerique" name '
            'FROM referentiel."T_CategorieGenerique" WHERE "ID_CategorieGenerique"=ANY(%s::integer[])',[self.categories])}
        self.assertEqual(row['CategoryLabels'],[labels[v] for v in row['CategoryIds']])
        self.assertEqual(self.detail(scope='entity')['CategoryLabels'],row['CategoryLabels'])

    def test_23_history_uses_real_editor_scope_query(self):
        self.response(self.put()[0])
        self.response(self.put(self.categories[1],scope='entity')[0])
        global_rows=self.response(self.client().get(self.path+'/historique',{'scope':'global'}))
        entity_rows=self.response(self.client().get(self.path+'/historique',{'scope':'entity','scopeValue':str(self.entities[0])}))
        self.assertEqual(len(global_rows),1);self.assertEqual(len(entity_rows),1)
        self.assertEqual(global_rows[0]['NewData']['scope'],'global')
        self.assertEqual(entity_rows[0]['NewData']['scopeValue'],str(self.entities[0]))
        self.assertEqual(self.response(self.client().get(self.path+'/historique',{'scope':'entity','scopeValue':str(self.entities[1])})),[])
        self.response(self.client().get(self.path+'/historique',{'scope':'entity','scopeValue':'non-numerique'}),400)

    def test_24_create_entity_uses_global_type_not_active_company_override(self):
        from apps.logistique.entity_documents import FIELDS,ADMIN_FIELDS
        field=next(f for f in self.fields if f['TableName']=='T_Entite' and f['ColumnName']=='IdTypeEntiteFk')
        self.response(self.put(scope='entity',path=BASE+'/'+str(field['ID_ChampReferentiel']))[0])
        defaults=self.response(self.client().get('/api/systeme/entites/identite-defaut'))
        selected=defaults['references']['entityTypes'][0]['id']
        self.assertNotEqual(selected,self.generics[0])
        body={key:defaults[key] for key in FIELDS|ADMIN_FIELDS}
        body.update(NomEntite='Nouvelle entreprise fictive '+uuid.uuid4().hex,
            EmailEntite=uuid.uuid4().hex+'@example.invalid',IdTypeEntiteFk=selected,
            motif='Création de recette hors surcharge du contexte',requestId=str(uuid.uuid4()))
        created=self.response(self.client().post('/api/systeme/entites',body,format='json'),201)
        self.assertNotEqual(created['IdEntite'],self.entities[0])
        self.assertEqual(created['IdTypeEntiteFk'],selected)

    def test_25_generic_reference_view_keeps_platform_permission(self):
        route='/api/views/referentiel/V_ReferencementChamp'
        self.assertTrue(self.response(self.client().get(route)))
        self.response(self.client(global_admin=False).get(route),403)
        local_views=self.response(self.client(global_admin=False).get('/api/views'))
        self.assertFalse(any(v['schema']=='referentiel' and v['name']=='V_ReferencementChamp' for v in local_views))

    def test_26_shared_fields_use_global_options_and_refuse_entity_writes(self):
        shared=[f for f in self.fields if not f['SupportsEntityScope']]
        # Vérifier la politique du domaine partagé, sans figer le nombre global
        # de champs quand d'autres modules acquièrent un propriétaire durable.
        territorial=[f for f in self.fields if f['SchemaName']=='geolocalisation']
        self.assertTrue(territorial)
        self.assertTrue(all(not f['SupportsEntityScope'] for f in territorial))
        field=next(f for f in shared if f['CanConfigure'] and f['TableName']=='T_Niveau_2'
                   and f['ColumnName']=='ID_TypeNiveau_2_Fk')
        path=BASE+'/'+str(field['ID_ChampReferentiel'])
        self.response(self.put(path=path)[0])
        current=self.detail(path=path,scope='entity')
        self.assertEqual(current['categoryIds'],[self.categories[0]])
        self.assertFalse(current['CanConfigure']);self.assertFalse(current['SupportsEntityScope'])
        shown=self.client().get(path,{'scope':'entity','scopeValue':str(self.entities[0])})
        self.response(shown);self.assertFalse(shown.data['meta']['canWrite'])
        listed=self.response(self.client().get(BASE,{'scope':'entity','scopeValue':str(self.entities[0]),'take':500}))
        self.assertFalse(next(v for v in listed if v['ID_ChampReferentiel']==field['ID_ChampReferentiel'])['CanConfigure'])
        self.response(self.put(path=path,scope='entity')[0],400)
        self.response(self.restore(path=path,scope='entity')[0],400)
        for index in (0,1):
            options=service.reference_options(self.actor(index),field['SchemaName'],field['TableName'],field['ColumnName'])
            self.assertEqual([v['id'] for v in options],[self.generics[0]])
        self.assertEqual(self.detail(path=path)['categoryIds'],[self.categories[0]])

    def test_27_shared_geography_crud_ignores_legacy_company_override(self):
        field=next(f for f in self.fields if f['TableName']=='T_Niveau_2' and f['ColumnName']=='ID_TypeNiveau_2_Fk')
        base='/api/geolocalisation/territoires/registres/'
        route=base+'niveaux2'
        # Le clone de recette possède le référentiel territorial commun :
        # réutiliser un vrai parent sans tester ici une autre création de pays.
        parent=db.one('SELECT "ID_Niveau_1" FROM geolocalisation."T_Niveau_1" ORDER BY "ID_Niveau_1" LIMIT 1')
        self.assertIsNotNone(parent, 'La recette requiert un parent territorial commun dans le clone privé.')
        # Le dictionnaire géographique copié conserve ses identifiants importés.
        # Préparer son générateur dans cette seule base privée permet de créer
        # les deux fixtures sans collision avec ces lignes ; aucun ID existant
        # n'est modifié et cette suite refuse une connexion applicative.
        db.query('SELECT setval(pg_get_serial_sequence(%s,%s),'
            'GREATEST(coalesce((SELECT max("ID_Niveau_2") FROM geolocalisation."T_Niveau_2"),1),1),true)',
            ['geolocalisation."T_Niveau_2"','ID_Niveau_2'])
        original=service.reference_options(self.actor(),'geolocalisation','T_Niveau_2','ID_TypeNiveau_2_Fk')[0]['id']
        previous=self.response(self.client().post(route,{'requestId':str(uuid.uuid4()),
            'ID_Niveau_1_FK':parent['ID_Niveau_1'],'NomNiveau_2':'Ancien site fictif '+uuid.uuid4().hex,
            'ID_TypeNiveau_2_Fk':original},format='json'),201)
        self.response(self.put(path=BASE+'/'+str(field['ID_ChampReferentiel']))[0])
        db.one('''INSERT INTO systeme."T_Fk_Correspondance"
            ("ModuleName","SchemaName","SourceKey","FieldName","MappingType","ReferenceSchemaName",
             "ReferenceObjectName","ReferenceFieldName","MappingValue","TargetCategoryIdFk","SettingScope","ScopeValue","ValideFkCorrespondance")
            VALUES('RECETTE_FICTIVE','geolocalisation',%s,'ID_TypeNiveau_2_Fk','generic_category','referentiel',
             'T_Generique','ID_Generique',%s,%s,'entity',%s,true) RETURNING "IdFkCorrespondance"''',
            [field['AliasSourceKeys'][0],str(self.categories[1]),self.categories[1],str(self.entities[0])])
        options=service.reference_options(self.actor(),'geolocalisation','T_Niveau_2','ID_TypeNiveau_2_Fk')
        self.assertEqual([v['id'] for v in options],[self.generics[0]])
        created=self.response(self.client().post(route,{'requestId':str(uuid.uuid4()),
            'ID_Niveau_1_FK':parent['ID_Niveau_1'],'NomNiveau_2':'Site global fictif '+uuid.uuid4().hex,
            'ID_TypeNiveau_2_Fk':self.generics[0]},format='json'),201)
        self.assertEqual(created['ID_TypeNiveau_2_Fk'],self.generics[0])
        self.response(self.client().post(route,{'requestId':str(uuid.uuid4()),
            'ID_Niveau_1_FK':parent['ID_Niveau_1'],'NomNiveau_2':'Site refusé fictif',
            'ID_TypeNiveau_2_Fk':self.generics[1]},format='json'),400)
        edited=self.response(self.client().put(route+'/'+str(previous['ID_Niveau_2']),
            {'requestId':str(uuid.uuid4()),'_version':previous['_version'],
             'NomNiveau_2':'Ancienne référence conservée'},format='json'))
        self.assertEqual(edited['ID_TypeNiveau_2_Fk'],original)
        self.response(self.client(global_admin=False).post(route,{'NomNiveau_2':'Interdit'},format='json'),403)


if __name__ == '__main__':
    result = unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(FieldReferencesAPI))
    paths = ['backend/apps/core/field_references.py', 'backend/apps/core/table_preferences.py', 'backend/config/urls.py',
             'backend/apps/core/registry.json','backend/apps/core/registry.py','backend/apps/core/models.py',
             'backend/apps/core/personnel.py','backend/apps/core/admin_portal.py','backend/apps/logistique/entity_documents.py',
             'backend/apps/logistique/currency.py','backend/apps/logistique/invoices.py','backend/apps/logistique/receipts.py','backend/apps/logistique/stock_returns.py',
             'backend/apps/logistique/services.py','backend/apps/logistique/article_rules.py','backend/apps/logistique/tiers.py',
             'backend/apps/logistique/immobilisations.py','backend/apps/logistique/inventories.py','backend/apps/logistique/quantities.py',
             'backend/apps/core/repository.py','backend/apps/core/reference_integration.py','backend/apps/core/ui_settings.py',
             'backend/apps/core/views.py',
             'SQL/tests/test_field_references_api.py', 'backend/database/migrations/20261028_09_referencement_champs.sql']
    output = ROOT/'.runtime/field-references-api/verification.json'; output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps({'passed': result.wasSuccessful(), 'tests': result.testsRun,
        'failures': len(result.failures), 'errors': len(result.errors), 'database': location.path[1:],
        'scope': 'Entreprises, catégories, utilisateurs et valeurs exclusivement fictifs en base privée locale.',
        'sha256': {p: hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in paths if (ROOT/p).exists()}},
        ensure_ascii=False, indent=2), encoding='utf8')
    raise SystemExit(0 if result.wasSuccessful() else 1)
