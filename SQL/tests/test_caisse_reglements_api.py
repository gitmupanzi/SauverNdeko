"""Encaissements optionnels atomiques ; PostgreSQL privé obligatoire via fixture CMD."""
import uuid
import unittest
from datetime import datetime,timedelta,timezone
from zoneinfo import ZoneInfo
from decimal import Decimal

import test_bons_commande_api as fixtures
from apps.caisse import services
from apps.core import db
from rest_framework.test import APIClient


class CaisseReglementsAPI(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        fixtures.BonsCommandeAPI.setUpClass()
        cls.fixture=fixtures.BonsCommandeAPI(methodName='runTest')

    @classmethod
    def tearDownClass(cls):
        fixtures.BonsCommandeAPI.tearDownClass()

    def actor(self,entity=0,manage=True):
        actor=self.fixture.actor(entity)
        actor._module_access['modules']['caisse']={'canRead':True,'canManage':manage,'canExport':True}
        return actor

    def client(self,actor=None):
        client=APIClient();client.force_authenticate(actor or self.actor());return client

    def result(self,response,status=200):
        self.assertEqual(response.status_code,status,getattr(response,'data',None));return response.data

    def cash(self,entity=0,currency=None,active=True):
        return services.create_cash(self.actor(entity),{'requestId':str(uuid.uuid4()),'data':{
            'NomCaisse':'Caisse fictive règlement '+uuid.uuid4().hex,
            'IdDeviseFk':currency or self.fixture.currency,'Actif':active}})['record']

    def invoice(self):
        article=self.fixture.article()
        self.fixture.create(self.fixture.payload(article,kind=self.fixture.be,quantity='20',price='10'))
        command=self.fixture.create(self.fixture.payload(article,kind=self.fixture.bs,quantity='4',price='25'))['bon']['ID_Commande']
        client=self.client()
        prep=self.result(client.get(f'/api/logistique/commandes/{command}/facture'))
        self.result(client.post(f'/api/logistique/commandes/{command}/facture',{
            'requestId':str(uuid.uuid4()),'_version':prep['meta']['revision'],
            'DateFacture':'2026-11-02T09:00:00','DateEcheancePaiement':'2026-12-02T09:00:00'},format='json'),201)
        return command

    def prepared(self,command,client=None):
        return self.result((client or self.client()).get('/api/logistique/reglements/preparation',{'commandeId':command}))

    def payload(self,prep,cash=None):
        modes=[row for row in prep['data']['references']['reglementModes'] if row['active']]
        self.assertTrue(modes)
        body={'requestId':str(uuid.uuid4()),'_version':prep['meta']['revision'],
            'CodeFactureFk':prep['data']['facture']['CodeFacture'],
            'ID_ModeReglementFk':modes[0]['id'],'MontantRegle':'25.00','DateReglement':'2026-11-02T10:00:00'}
        if cash is not None:body['caisseId']=str(cash['IdCaisse'])
        return body

    def balances(self,command,cash):
        return db.one('''SELECT c."MontantCaisse" cash,
          (SELECT count(*) FROM logistique."T_Reglements" WHERE "CodeFactureFk"=cmd."CodeFacture") payments,
          (SELECT count(*) FROM operations."T_Paiement" WHERE "IdCaisseFk"=c."IdCaisse") entries
          FROM operations."T_Caisse" c CROSS JOIN logistique."T_Commande" cmd
          WHERE c."IdCaisse"=%s AND cmd."ID_Commande"=%s''',[cash['IdCaisse'],command])

    def test_01_payment_cash_and_replay_are_one_transaction(self):
        cash=self.cash();command=self.invoice();prep=self.prepared(command)
        self.assertIn(cash['IdCaisse'],[r['id'] for r in prep['data']['references']['caisses']])
        body=self.payload(prep,cash)
        created=self.result(self.client().post('/api/logistique/reglements',body,format='json'),201)['data']
        self.assertTrue(created['caisse'])
        first=self.balances(command,cash)
        self.assertEqual(first,{'cash':Decimal('25.00'),'payments':1,'entries':1})
        self.result(self.client().post('/api/logistique/reglements',body,format='json'),200)
        self.assertEqual(self.balances(command,cash),first)
        linked=db.one('SELECT "DatePaiement","IdReglementFk","EtatEcriture" FROM operations."T_Paiement" WHERE "IdCaisseFk"=%s',[cash['IdCaisse']])
        self.assertEqual(linked['DatePaiement'].hour,9) # 10:00 Kinshasa = 09:00 UTC.
        self.assertEqual(linked['IdReglementFk'],created['ID_Reglement'])
        self.assertEqual(linked['EtatEcriture'],'POSTED')

    def test_02_inactive_or_other_company_cash_rolls_back_payment(self):
        command=self.invoice()
        for cash in [self.cash(active=False),self.cash(entity=1)]:
            before=self.balances(command,cash)
            response=self.client().post('/api/logistique/reglements',self.payload(self.prepared(command),cash),format='json')
            self.assertIn(response.status_code,[403,404,409],response.data)
            self.assertEqual(self.balances(command,cash),before)

    def test_03_cash_permission_required_and_choices_hidden(self):
        cash=self.cash();command=self.invoice();client=self.client(self.actor(manage=False))
        prep=self.prepared(command,client)
        self.assertEqual(prep['data']['references']['caisses'],[])
        before=self.balances(command,cash)
        self.result(client.post('/api/logistique/reglements',self.payload(prep,cash),format='json'),403)
        self.assertEqual(self.balances(command,cash),before)

    def test_04_no_selection_keeps_existing_payment_behavior(self):
        cash=self.cash();command=self.invoice()
        self.result(self.client().post('/api/logistique/reglements',self.payload(self.prepared(command)),format='json'),201)
        self.assertEqual(self.balances(command,cash),{'cash':Decimal('0'),'payments':1,'entries':0})

    def test_05_linked_payment_cannot_be_edited_deleted_or_repointed(self):
        cash=self.cash();command=self.invoice();body=self.payload(self.prepared(command),cash)
        row=self.result(self.client().post('/api/logistique/reglements',body,format='json'),201)['data']
        path='/api/logistique/reglements/'+str(row['ID_Reglement'])
        detail=self.result(self.client().get(path))
        self.assertFalse(detail['meta']['canEdit']);self.assertFalse(detail['meta']['canDelete'])
        for method,payload in [('put',{'MontantRegle':'20'}),('delete',{})]:
            data={'requestId':str(uuid.uuid4()),'_version':detail['meta']['revision'],**payload}
            self.result(getattr(self.client(),method)(path,data,format='json'),409)
        conflict={**body,'caisseId':str(self.cash()['IdCaisse'])}
        self.result(self.client().post('/api/logistique/reglements',conflict,format='json'),409)
        self.assertEqual(self.balances(command,cash),{'cash':Decimal('25'),'payments':1,'entries':1})

    def test_06_wrong_currency_hidden_and_atomic_rollback(self):
        currencies=db.query('''SELECT "ID_Generique" id FROM referentiel."T_Generique"
            WHERE "ID_CategorieGeneriqueFk"=(SELECT "ID_CategorieGeneriqueFk" FROM referentiel."T_Generique" WHERE "ID_Generique"=%s)
            AND "ID_Generique"<>%s AND "IdEntiteFk" IS NULL AND "ValideGenerique" IS TRUE ORDER BY "ID_Generique"''',[self.fixture.currency,self.fixture.currency])
        self.assertTrue(currencies)
        cash=self.cash(currency=currencies[0]['id']);command=self.invoice();prep=self.prepared(command)
        self.assertNotIn(cash['IdCaisse'],[row['id'] for row in prep['data']['references']['caisses']])
        before=self.balances(command,cash)
        response=self.client().post('/api/logistique/reglements',self.payload(prep,cash),format='json')
        self.result(response,409)
        self.assertEqual(self.balances(command,cash),before)

    def test_07_closed_cash_rejects_backdated_receipt_and_rolls_back_invoice(self):
        cash=self.cash();command=self.invoice()
        now=datetime.now(timezone.utc)
        services.close_cash(self.actor(),{'data':{'IdCaisseFk':cash['IdCaisse'],
            'ClotureLe':(now-timedelta(minutes=1)).isoformat(),'MontantCompte':'0'},
            'requestId':str(uuid.uuid4()),'_version':str(cash['Revision'])})
        prep=self.prepared(command);body=self.payload(prep,cash)
        body['DateReglement']=(now-timedelta(minutes=2)).astimezone(ZoneInfo('Africa/Kinshasa')).replace(tzinfo=None).isoformat(timespec='seconds')
        before=self.balances(command,cash)
        response=self.client().post('/api/logistique/reglements',body,format='json')
        self.result(response,409)
        self.assertIn('clôture',response.data['error']['details']['caisseId'])
        self.assertEqual(self.balances(command,cash),before)
        # La facture conserve exactement son solde : aucun règlement partiel.
        after=self.prepared(command)
        self.assertEqual(Decimal(after['data']['facture']['Reste']),Decimal(prep['data']['facture']['Reste']))

    def test_08_linked_entry_cannot_be_reversed_separately(self):
        cash=self.cash();command=self.invoice()
        row=self.result(self.client().post('/api/logistique/reglements',self.payload(self.prepared(command),cash),format='json'),201)['data']
        entry=row['caisse']['IdPaiement']
        detail=self.result(self.client().get('/api/caisse/ecritures/'+str(entry)))['data']
        self.assertFalse(detail['canReverse'])
        before=self.balances(command,cash)
        self.result(self.client().post('/api/caisse/ecritures/'+str(entry)+'/contrepasser',{
            '_version':detail['_version'],'requestId':str(uuid.uuid4()),'motif':'Tentative correction isolée'},format='json'),409)
        self.assertEqual(self.balances(command,cash),before)

    def test_09_replay_cannot_add_cash_to_existing_plain_payment(self):
        cash=self.cash();command=self.invoice();body=self.payload(self.prepared(command))
        self.result(self.client().post('/api/logistique/reglements',body,format='json'),201)
        before=self.balances(command,cash)
        self.result(self.client().post('/api/logistique/reglements',{**body,'caisseId':str(cash['IdCaisse'])},format='json'),409)
        self.assertEqual(self.balances(command,cash),before)


if __name__=='__main__':unittest.main(verbosity=2)
