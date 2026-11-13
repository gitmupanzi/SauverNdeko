"""Recette des politiques Caisse sur une base PostgreSQL locale de test."""
import unittest
import uuid
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timedelta, timezone
from decimal import Decimal
from threading import Barrier

import test_caisse_api as recipe
from django.db import connections


class ValidationCaisseAPI(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        recipe.CaisseAPI.setUpClass()
        cls.fixture = recipe.CaisseAPI
        cls.sql = cls.fixture.sql
        cls.author = cls.fixture.users[0]
        cls.other = cls.sql.execute('''INSERT INTO systeme."T_Utilisateurs"
            ("NomUser","PrenomUser","EmailUser","MotdepasseUser","ValideUser","SexeUser","Is_Admin","Is_staff","IdEntiteFk")
            VALUES('Validation','Agent',%s,'inutilisable',true,'M',false,true,%s) RETURNING *''',
            [uuid.uuid4().hex + '@example.invalid', cls.fixture.entities[0]]).fetchone()
        licence = cls.sql.execute('''INSERT INTO systeme."T_Licence"
            ("IdEntiteFk","DateDebut","DateFin","ValideLicence","IdStatutLicenceFk")
            SELECT %s, LOCALTIMESTAMP - interval '1 day', LOCALTIMESTAMP + interval '1 year', true, g."ID_Generique"
            FROM referentiel."T_Generique" g JOIN referentiel."T_CategorieGenerique" c
            ON c."ID_CategorieGenerique"=g."ID_CategorieGeneriqueFk"
            WHERE lower(c."NomCategorieGenerique")='statut licence' AND lower(g."NomGenerique") IN ('active','actif')
            AND g."ValideGenerique" IS TRUE AND g."IdEntiteFk" IS NULL ORDER BY g."ID_Generique" LIMIT 1
            RETURNING "IdLicence"''', [cls.fixture.entities[0]]).fetchone()['IdLicence']
        cls.sql.execute('INSERT INTO systeme."T_LicenceModule" ("IdLicenceFk","CodeModule","Actif") VALUES (%s,%s,true)',
                        [licence, 'caisse'])

    @classmethod
    def tearDownClass(cls):
        cls.fixture.tearDownClass()

    def request(self, method, path, body=None, *, actor='author', status=200):
        if actor == 'agent':
            user = recipe.Actor(self.other)
            user._context_entity = self.fixture.entities[0]
            client = recipe.APIClient()
            client.force_authenticate(user)
        else:
            client = self.fixture.client(index=1 if actor == 'foreign' else 0, manage=actor != 'denied')
        target = recipe.BASE + path
        response = getattr(client, method)(target, body, format='json') if method != 'get' else client.get(target, body)
        self.assertEqual(response.status_code, status, response.data)
        return response.data.get('data', response.data.get('error'))

    def configure(self, mode, validators=(), *, status=200):
        current = self.request('get', '/parametres-validation')
        return self.request('put', '/parametres-validation', {
            'mode': mode, 'validatorIds': list(validators), '_version': current['_version'],
            'requestId': str(uuid.uuid4()), 'motif': 'Recette des droits de validation',
        }, status=status)

    def cash(self, currency=None):
        result = self.request('post', '/caisses', {
            'data': {'NomCaisse': 'Validation ' + uuid.uuid4().hex, 'IdDeviseFk': currency or self.fixture.usd},
            'requestId': str(uuid.uuid4()),
        }, status=201)
        return result['record']['IdCaisse']

    def entry(self, cash, amount, sense=1, *, status=201, validate=False):
        result = self.request('post', '/ecritures', {
            'data': {'IdCaisseFk': cash, 'LibellePaiement': 'Recette validation',
                     'DatePaiement': (datetime.now(timezone.utc) - timedelta(days=1)).isoformat(),
                     'MontantPaiement': amount, 'SensMouvement': sense},
            'requestId': str(uuid.uuid4()), 'valider': validate,
        }, status=status)
        if status != 201:
            return result
        return {'id': result['record']['IdPaiement'], '_version': result['_version']}

    def preview(self, rows, *, actor='author'):
        return self.request('post', '/ecritures/validation/apercu', {'rows': rows}, actor=actor)

    def confirmation(self, rows):
        return {'rows': rows, 'requestId': str(uuid.uuid4()), 'motif': 'Contrôle volontaire des écritures'}

    def confirm(self, body, *, actor='author', status=200):
        return self.request('post', '/ecritures/validation', body, actor=actor, status=status)

    def restrict(self, *keys):
        for key in keys:
            self.sql.execute('''INSERT INTO systeme."T_UtilisateurModule"
                ("IdEntiteFk","IdUserFk","CodeModule","CodeOnglet","PeutConsulter","PeutGerer","PeutExporter","ModifieParUserFk")
                VALUES (%s,%s,'caisse',%s,true,false,true,%s)''',
                [self.fixture.entities[0], self.other['IdUser'], key, self.author['IdUser']])

    def restore_rights(self):
        self.sql.execute('DELETE FROM systeme."T_UtilisateurModule" WHERE "IdEntiteFk"=%s AND "IdUserFk"=%s',
                         [self.fixture.entities[0], self.other['IdUser']])

    def state(self, row):
        return self.request('get', f"/ecritures/{row['id']}")['record']

    def test_01_default_manual_and_atomic_lot_per_currency(self):
        self.assertEqual(self.request('get', '/parametres-validation')['mode'], 'MANUAL')
        other_currency = next(item['id'] for item in self.fixture.refs['devises'] if item['id'] != self.fixture.usd)
        cash = self.cash()
        foreign_currency_cash = self.cash(other_currency)
        outgoing = self.entry(cash, '30.00', -1)
        incoming = self.entry(cash, '50.00')
        other_currency_in = self.entry(foreign_currency_cash, '17.50')
        untouched = self.entry(cash, '24.00')
        self.assertEqual(self.state(incoming)['EtatEcriture'], 'DRAFT')
        self.assertFalse(self.preview([outgoing])['rows'][0]['eligible'])
        report = self.preview([outgoing, incoming, other_currency_in])
        self.assertEqual(report['count'], 3)
        self.assertTrue(all(row['eligible'] for row in report['rows']))
        totals = {row['currencyId']: (Decimal(row['entries']), Decimal(row['exits'])) for row in report['totals']}
        self.assertEqual(totals, {self.fixture.usd: (Decimal('50'), Decimal('30')), other_currency: (Decimal('17.50'), Decimal(0))})
        body = self.confirmation([outgoing, incoming, other_currency_in])
        self.assertFalse(self.confirm(body)['replayed'])
        self.assertTrue(self.confirm({**body, 'rows': list(reversed(body['rows']))})['replayed'])
        self.confirm({**body, 'rows': [incoming]}, status=409)
        self.assertEqual(self.state(outgoing)['MecanismeValidation'], 'MANUAL')
        self.assertEqual(self.state(untouched)['EtatEcriture'], 'DRAFT')
        prep = self.request('get', '/clotures/preparation', {
            'caisseId': cash, 'date': datetime.now(timezone.utc).isoformat(), 'montantCompte': '25.00',
        })['record']
        for key, expected in {'SoldeValide': '20', 'EntreesBrouillon': '24', 'SortiesBrouillon': '0',
                              'SoldePrevisionnel': '44', 'EcartComptage': '5'}.items():
            self.assertEqual(Decimal(prep[key]), Decimal(expected))
        self.assertEqual(prep['NombreBrouillons'], 1)
        self.request('post', '/clotures', {
            'data': {'IdCaisseFk': cash, 'ClotureLe': datetime.now(timezone.utc).isoformat(), 'MontantCompte': '25.00'},
            'requestId': str(uuid.uuid4()), 'motif': 'Comptage fictif',
            '_version': self.request('get', f'/caisses/{cash}')['_version'],
        }, status=409)
        self.assertEqual(self.state(untouched)['EtatEcriture'], 'DRAFT')

    def test_02_separate_agent_and_configuration_history(self):
        self.configure('OTHER_AGENT', status=422)
        self.configure('OTHER_AGENT', [self.fixture.users[1]['IdUser']], status=422)
        user_id = self.other['IdUser']
        configured = self.configure('OTHER_AGENT', [user_id])
        self.assertEqual(configured['validatorIds'], [user_id])
        self.assertEqual(self.request('get', '/parametres-validation', actor='foreign')['mode'], 'MANUAL')
        cash = self.cash()
        line = self.entry(cash, '10.00')
        self.assertIn('autre agent', self.preview([line])['rows'][0]['reason'])
        self.confirm(self.confirmation([line]), status=409)
        self.assertTrue(self.preview([line], actor='agent')['rows'][0]['eligible'])
        self.configure('AUTO', [user_id])
        self.assertEqual(self.state(line)['ModeValidation'], 'OTHER_AGENT')
        self.configure('AUTO', status=422)
        self.restrict('validation-ecritures')
        try:
            self.confirm(self.confirmation([line]), actor='agent', status=403)
        finally:
            self.restore_rights()
        self.confirm(self.confirmation([line]), actor='agent')
        posted = self.state(line)
        self.assertEqual(posted['IdValidateurFk'], user_id)
        self.assertEqual(posted['MecanismeValidation'], 'MANUAL')
        audit = self.sql.execute('''SELECT "NewData"->>'MotifModification' reason FROM systeme."T_Audit_Log"
            WHERE "TableName"='operations.T_ParametreValidationCaisse' AND "NewData"->>'IdEntiteFk'=%s
            ORDER BY "IdLog" DESC LIMIT 1''', [str(self.fixture.entities[0])]).fetchone()
        self.assertEqual(audit['reason'], 'Recette des droits de validation')

    def test_03_automatic_atomicity_and_permissions(self):
        self.configure('AUTO')
        cash = self.cash()
        line = self.entry(cash, '16.50')
        record = self.state(line)
        self.assertEqual(record['EtatEcriture'], 'POSTED')
        self.assertEqual(record['MecanismeValidation'], 'AUTO')
        self.assertIsNone(record['IdValidateurFk'])
        self.entry(cash, '100', -1, status=409)
        entries = self.sql.execute('''SELECT count(*) n, sum("MontantPaiement") total FROM operations."T_Paiement"
            WHERE "IdCaisseFk"=%s''', [cash]).fetchone()
        self.assertEqual(entries, {'n': 1, 'total': Decimal('16.50')})
        self.confirm(self.confirmation([line]), actor='denied', status=403)
        self.confirm(self.confirmation([line]), actor='foreign', status=409)

    def test_04_stale_row_blocks_entire_selection(self):
        self.configure('MANUAL')
        cash = self.cash()
        first, stale = self.entry(cash, '20'), self.entry(cash, '50')
        stale_revision = {**stale, '_version': str(int(stale['_version']) + 1)}
        report = self.preview([first, stale_revision])
        self.assertIn('changé', report['rows'][1]['reason'])
        self.confirm(self.confirmation([first, stale_revision]), status=409)
        self.assertEqual(self.state(first)['EtatEcriture'], 'DRAFT')
        self.assertEqual(self.state(stale)['EtatEcriture'], 'DRAFT')

    def test_05_distinct_permissions_are_enforced(self):
        self.configure('MANUAL')
        cash = self.cash()
        line = self.entry(cash, '20')
        self.restrict('saisie-ecritures', 'modification-brouillons', 'parametres-validation', 'clotures')
        try:
            self.request('post', '/ecritures', {}, actor='agent', status=403)
            self.request('put', f"/ecritures/{line['id']}", {}, actor='agent', status=403)
            self.request('put', '/parametres-validation', {}, actor='agent', status=403)
            self.request('post', '/clotures', {}, actor='agent', status=403)
            self.assertTrue(self.preview([line], actor='agent')['rows'][0]['eligible'])
            self.confirm(self.confirmation([line]), actor='agent')
        finally:
            self.restore_rights()

    def test_06_concurrent_withdrawals_do_not_double_spend(self):
        self.configure('MANUAL')
        cash = self.cash()
        incoming = self.entry(cash, '100')
        self.confirm(self.confirmation([incoming]))
        candidates = [self.confirmation([self.entry(cash, '75', -1)]) for _ in range(2)]
        barrier = Barrier(2, timeout=15)
        def run(body):
            try:
                client = self.fixture.client()
                barrier.wait()
                return client.post(recipe.BASE + '/ecritures/validation', body, format='json').status_code
            finally:
                connections.close_all()
        with ThreadPoolExecutor(max_workers=2) as pool:
            results = list(pool.map(run, candidates))
        self.assertEqual(sorted(results), [200, 409])
        ledger = self.request('get', f'/caisses/{cash}')['record']
        self.assertEqual(Decimal(ledger['MontantCaisse']), Decimal('25'))


if __name__ == '__main__':
    unittest.main(verbosity=2)
