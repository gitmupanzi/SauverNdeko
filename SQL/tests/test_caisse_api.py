"""Recette API Caisse, uniquement sur un clone PostgreSQL local explicitement nommé."""
import csv
import io
import json
import os
import sys
import unittest
import uuid
from datetime import datetime, timedelta, timezone
from decimal import Decimal
from pathlib import Path
from urllib.parse import urlsplit

import psycopg
from psycopg.rows import dict_row

ROOT = Path(__file__).resolve().parents[2]
DSN = os.environ.get('SAUVERNDEKO_TEST_DATABASE_URL','')
target = urlsplit(DSN)
if target.hostname not in {'localhost','127.0.0.1','::1'} or not target.path[1:].startswith('sauverndeko_test_'):
    raise RuntimeError('Tests réservés à PostgreSQL local sauverndeko_test_*.')
with psycopg.connect(DSN) as connection:
    if not connection.execute('SELECT current_database()').fetchone()[0].startswith('sauverndeko_test_'):
        raise RuntimeError('Base de recette privée requise.')
os.environ.update(DATABASE_URL=DSN,DJANGO_SETTINGS_MODULE='config.settings',SAUVERNDEKO_DB_READ_ONLY='0')
sys.path.insert(0,str(ROOT/'backend'))
import django
django.setup()
from django.test import override_settings
from rest_framework.test import APIClient
from apps.accounts.authentication import Actor
from apps.core import db
from apps.core.module_access import WORKSPACE_MODULES

BASE='/api/caisse'


class CaisseAPI(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.settings=override_settings(ALLOWED_HOSTS=['testserver'])
        cls.settings.enable()
        cls.sql=psycopg.connect(DSN,autocommit=True,row_factory=dict_row)
        cls.entities=[cls.sql.execute('INSERT INTO systeme."T_Entite"("NomEntite","EmailEntite","ValideEntite") VALUES(%s,%s,true) RETURNING "IdEntite" id', ['Caisse fictive '+uuid.uuid4().hex,uuid.uuid4().hex+'@example.invalid']).fetchone()['id'] for _ in range(2)]
        cls.users=[cls.sql.execute('''INSERT INTO systeme."T_Utilisateurs"("NomUser","PrenomUser","EmailUser","MotdepasseUser","ValideUser","SexeUser","Is_Admin","Is_staff","IdEntiteFk")
         VALUES('Recette','Caisse',%s,'inutilisable',true,'M',true,true,%s) RETURNING *''',[uuid.uuid4().hex+'@example.invalid',entity]).fetchone() for entity in cls.entities]
        refs=cls.client().get(BASE+'/references')
        assert refs.status_code==200, str(refs.data)
        cls.refs=refs.data['data']
        cls.usd=next(value['id'] for value in cls.refs['devises'] if value['label']=='USD')

    @classmethod
    def tearDownClass(cls):
        cls.sql.close()
        cls.settings.disable()

    @classmethod
    def actor(cls,index=0,global_admin=True,manage=True,export=True,read=True,all_entities=False):
        actor=Actor({**cls.users[index],'Is_Admin':global_admin})
        if global_admin and not all_entities: actor._context_entity=cls.entities[index]
        actor._module_access={'modules':{item['key']:{'canRead':read,'canManage':manage,'canExport':export,'reason':'MODULE_ROLE_FORBIDDEN'} for item in WORKSPACE_MODULES}}
        return actor

    @classmethod
    def client(cls,index=0,**rights):
        client=APIClient()
        client.force_authenticate(cls.actor(index,**rights))
        return client

    def post(self,path,body,client=None,status=201):
        response=(client or self.client()).post(BASE+path,body,format='json')
        self.assertEqual(response.status_code,status,response.data)
        return response.data['data']

    def cash(self,**changes):
        body={'data':{'NomCaisse':'Caisse '+uuid.uuid4().hex,'IdDeviseFk':self.usd,'Actif':True},'requestId':str(uuid.uuid4())}
        body['data'].update(changes)
        return self.post('/caisses',body)

    def entry(self,cash,amount='100.00',sens=1,posted=True,**changes):
        data={'IdCaisseFk':cash['record']['IdCaisse'],'LibellePaiement':'Opération fictive','DatePaiement':(datetime.now(timezone.utc)-timedelta(days=2)).isoformat(),
            'MontantPaiement':amount,'SensMouvement':sens}
        data.update(changes)
        return self.post('/ecritures',{'data':data,'valider':posted,'requestId':str(uuid.uuid4()),'motif':'Recette caisse'})

    def test_cash_batch_is_atomic_and_binds_entire_request(self):
        label = 'Lot caisse '+uuid.uuid4().hex
        rows = [{'clientRowId':key,'data':{'NomCaisse':name,'IdDeviseFk':self.usd}}
                for key,name in [('first',label),('second','')]]
        body = {'requestId':str(uuid.uuid4()), 'rows':rows}
        response = self.client().post(BASE+'/caisses',body,format='json')
        self.assertEqual(response.status_code,422,response.data)
        self.assertIn('NomCaisse', response.data['error']['details']['rows']['second'])
        self.assertEqual(self.client().get(BASE+'/caisses',{'q':label}).data['data']['total'],0)
        rows[1]['data']['NomCaisse'] = label+' deuxième'
        self.assertEqual(self.client(manage=False).post(BASE+'/caisses',body,format='json').status_code,403)
        first = self.post('/caisses',body)
        self.assertEqual(first['count'],2)
        self.assertEqual(first,self.post('/caisses',body,status=200))
        self.post('/caisses',{**body,'rows':rows[:1]},status=409)
        self.assertEqual(self.client().get(BASE+'/caisses',{'q':label}).data['data']['total'],2)

    def test_entry_batch_drafts_and_rollback_of_posted_balance(self):
        cash = self.cash()['record']
        date = (datetime.now(timezone.utc)-timedelta(days=1)).isoformat()
        def line(key, amount, sense):
            return {'clientRowId':key,'data':{'IdCaisseFk':cash['IdCaisse'],'LibellePaiement':key,
                'DatePaiement':date,'MontantPaiement':amount,'SensMouvement':sense}}
        rows = [line('entree','100.25',1),line('sortie','105.00',-1)]
        body = {'requestId':str(uuid.uuid4()), 'rows':rows, 'valider':True}
        response = self.client().post(BASE+'/ecritures',body,format='json')
        self.assertEqual(response.status_code,422,response.data)
        self.assertIn('sortie',response.data['error']['details']['rows'])
        self.assertEqual(self.sql.execute('SELECT count(*) n FROM operations."T_Paiement" WHERE "IdCaisseFk"=%s',
                                         [cash['IdCaisse']]).fetchone()['n'],0)
        posted = self.post('/ecritures',{**body,'rows':[rows[0],line('sortie','99.75',-1)]})
        self.assertEqual(posted['count'],2)
        drafts = self.post('/ecritures',{'requestId':str(uuid.uuid4()),'rows':rows})
        self.assertEqual(drafts['count'],2)
        for item in drafts['records']:
            detail = self.client().get(BASE+'/ecritures/'+str(item['id'])).data['data']
            self.assertEqual(detail['record']['EtatEcriture'],'DRAFT')
        detail = self.client().get(BASE+'/caisses/'+str(cash['IdCaisse'])).data['data']
        self.assertEqual(Decimal(detail['record']['MontantCaisse']),Decimal('0.50'))

    def test_closure_batch_keeps_snapshots_and_rolls_back_on_stale_revision(self):
        cashboxes = [self.cash(), self.cash()]
        date = (datetime.now(timezone.utc)-timedelta(days=1)).isoformat()
        rows = [{'clientRowId':str(index),'_version':cash['_version'],'motif':'Comptage fictif',
                 'data':{'IdCaisseFk':cash['record']['IdCaisse'],'ClotureLe':date,'MontantCompte':'0'}}
                for index,cash in enumerate(cashboxes)]
        body = {'requestId':str(uuid.uuid4()), 'rows':rows}
        other = self.cash()
        foreign = self.client(index=1).get(BASE+'/caisses/'+str(other['record']['IdCaisse']))
        self.assertEqual(foreign.status_code,404)
        refs = self.client().get(BASE+'/references').data['data']['caisses']
        snapshot = next(cash for cash in refs if cash['IdCaisse']==rows[0]['data']['IdCaisseFk'])
        self.assertEqual(snapshot['_version'],rows[0]['_version'])
        self.entry(cashboxes[1],amount='12.50')
        response = self.client().post(BASE+'/clotures',body,format='json')
        self.assertEqual(response.status_code,422,response.data)
        self.assertIn('_version',response.data['error']['details']['rows']['1'])
        result = self.client().get(BASE+'/caisses/'+str(rows[0]['data']['IdCaisseFk'])).data['data']
        self.assertIsNone(result['record']['DerniereClotureLe'])
        fresh = self.client().get(BASE+'/clotures/preparation',{'caisseId':rows[1]['data']['IdCaisseFk']}).data['data']
        rows[1]['_version'] = fresh['_version']
        result = self.post('/clotures',body)
        self.assertEqual(result,self.post('/clotures',body,status=200))
        detail = self.client().get(BASE+'/clotures/'+str(result['records'][1]['id'])).data['data']
        self.assertEqual(Decimal(detail['record']['Ecart']),Decimal('-12.50'))

    def test_01_context_and_zero_cash_no_implicit_funds(self):
        cash=self.cash()
        self.assertEqual(Decimal(cash['record']['SoldeTheorique']),0)
        self.assertEqual(cash['record']['NombreEcritures'],0)
        self.assertNotIn('CreationPayloadHash',cash['record'])
        self.assertTrue(cash['record']['CodeCaisse'].startswith('CAI-'))
        self.assertFalse(self.client(all_entities=True).get(BASE+'/contexte').data['data']['canManage'])
        self.assertEqual(self.client(all_entities=True).post(BASE+'/caisses',{'data':{'NomCaisse':'Erreur','IdDeviseFk':self.usd},'requestId':str(uuid.uuid4())},format='json').status_code,409)

    def test_02_draft_update_validate_and_replay(self):
        cash=self.cash()
        draft=self.entry(cash,posted=False)
        pk=draft['record']['IdPaiement']
        self.assertTrue(draft['canValidate'])
        body={'data':{'MontantPaiement':'125.25'},'_version':draft['_version'],'requestId':str(uuid.uuid4()),'motif':'Correction brouillon'}
        result=self.client().put(BASE+'/ecritures/'+str(pk),body,format='json')
        self.assertEqual(result.status_code,200,result.data)
        replay=self.client().put(BASE+'/ecritures/'+str(pk),body,format='json')
        self.assertEqual(replay.status_code,200,replay.data)
        self.assertTrue(replay.data['data']['replayed'])
        updated=result.data['data']
        validated=self.post('/ecritures/'+str(pk)+'/valider',{'_version':updated['_version'],'requestId':str(uuid.uuid4()),'motif':'Pièce vérifiée'},status=200)
        self.assertEqual(validated['record']['EtatEcriture'],'POSTED')
        balance=self.client().get(BASE+'/caisses/'+str(cash['record']['IdCaisse'])).data['data']
        self.assertEqual(Decimal(balance['record']['MontantCaisse']),Decimal('125.25'))
        denied=self.client().put(BASE+'/ecritures/'+str(pk),{'data':{'MontantPaiement':'2'},'_version':validated['_version'],'requestId':str(uuid.uuid4())},format='json')
        self.assertEqual(denied.status_code,409)

    def test_03_exact_compensation_history_and_idempotence(self):
        cash=self.cash()
        posted=self.entry(cash)
        body={'_version':posted['_version'],'requestId':str(uuid.uuid4()),'motif':'Erreur de caisse justifiée'}
        path='/ecritures/'+str(posted['record']['IdPaiement'])+'/contrepasser'
        inverse=self.post(path,body,status=200)
        self.assertEqual(inverse['record']['SensMouvement'],-1)
        self.assertEqual(Decimal(inverse['record']['MontantPaiement']),100)
        self.assertEqual(inverse['record']['IdPaiementOrigineFk'],posted['record']['IdPaiement'])
        replay=self.post(path,body,status=200)
        self.assertTrue(replay['replayed'])
        original=self.client().get(BASE+'/ecritures/'+str(posted['record']['IdPaiement'])).data['data']
        self.assertFalse(original['canReverse'])
        balance=self.client().get(BASE+'/caisses/'+str(cash['record']['IdCaisse'])).data['data']['record']
        self.assertEqual(Decimal(balance['SoldeTheorique']),0)
        self.assertEqual(balance['NombreEcritures'],2)
        self.assertEqual(self.client().delete(BASE+'/ecritures/'+str(posted['record']['IdPaiement'])).status_code,405)

    def test_04_insufficient_balance_and_fraction_validation(self):
        cash=self.cash()
        with self.assertRaises(AssertionError): self.entry(cash,amount='1.01',sens=-1)
        count=self.sql.execute('SELECT count(*) n FROM operations."T_Paiement" WHERE "IdCaisseFk"=%s',[cash['record']['IdCaisse']]).fetchone()['n']
        self.assertEqual(count,0)
        body={'data':{'IdCaisseFk':cash['record']['IdCaisse'],'LibellePaiement':'Centimes invalides','DatePaiement':datetime.now(timezone.utc).isoformat(),'MontantPaiement':'0.001','SensMouvement':1},'valider':True,'requestId':str(uuid.uuid4())}
        self.assertEqual(self.client().post(BASE+'/ecritures',body,format='json').status_code,422)

    def test_05_tenant_isolation_and_generic_write_guard(self):
        cash=self.cash()
        pk=cash['record']['IdCaisse']
        other=self.client(index=1,global_admin=False)
        self.assertEqual(other.get(BASE+'/caisses/'+str(pk)).status_code,404)
        listed=other.get(BASE+'/registres/caisses').data['data']
        self.assertNotIn(pk,[row['IdCaisse'] for row in listed['rows']])
        injected=other.post(BASE+'/ecritures',{'data':{'IdCaisseFk':pk,'LibellePaiement':'Refus','DatePaiement':datetime.now(timezone.utc).isoformat(),'MontantPaiement':'10','SensMouvement':1},'requestId':str(uuid.uuid4())},format='json')
        self.assertEqual(injected.status_code,404)
        from apps.core.repository import _mutate
        from apps.core.responses import APIError
        with self.assertRaises(APIError) as failure: _mutate('T_Caisse',self.actor(),body={'MontantCaisse':'100'})
        self.assertEqual(failure.exception.status_code,405)

    def test_06_permissions_and_read_only(self):
        cash=self.cash()
        denied=self.client(manage=False)
        self.assertEqual(denied.post(BASE+'/caisses',{'data':{'NomCaisse':'Refus','IdDeviseFk':self.usd},'requestId':str(uuid.uuid4())},format='json').status_code,403)
        self.assertEqual(self.client(read=False).get(BASE+'/registres/caisses').status_code,403)
        self.assertEqual(self.client(export=False).get(BASE+'/registres/caisses.xlsx').status_code,403)
        with override_settings(DB_READ_ONLY=True):
            self.assertFalse(self.client().get(BASE+'/contexte').data['data']['canManage'])
            self.assertEqual(self.client().post(BASE+'/caisses',{'data':{'NomCaisse':'Refus','IdDeviseFk':self.usd},'requestId':str(uuid.uuid4())},format='json').status_code,503)

    def test_07_closure_capture_replay_and_no_adjustment(self):
        cash=self.cash()
        self.entry(cash)
        fresh=self.client().get(BASE+'/clotures/preparation',{'caisseId':cash['record']['IdCaisse']}).data['data']
        date_value=(datetime.now(timezone.utc)-timedelta(days=1)).isoformat()
        body={'data':{'IdCaisseFk':cash['record']['IdCaisse'],'ClotureLe':date_value,'MontantCompte':'99.00'},'_version':fresh['_version'],'requestId':str(uuid.uuid4()),'motif':'Écart physique justifié'}
        closed=self.post('/clotures',body)
        self.assertEqual(Decimal(closed['record']['Ecart']),-1)
        self.assertTrue(self.post('/clotures',body)['replayed'])
        balance=self.client().get(BASE+'/caisses/'+str(cash['record']['IdCaisse'])).data['data']['record']
        self.assertEqual(Decimal(balance['MontantCaisse']),100)
        with self.assertRaises(AssertionError): self.entry(cash,amount='1')
        self.assertEqual(self.sql.execute('SELECT count(*) n FROM operations."T_Paiement" WHERE "IdCaisseFk"=%s',[cash['record']['IdCaisse']]).fetchone()['n'],1)

    def test_08_closure_requires_no_pending_draft_and_motive_for_gap(self):
        cash=self.cash()
        draft=self.entry(cash,posted=False)
        fresh=self.client().get(BASE+'/caisses/'+str(cash['record']['IdCaisse'])).data['data']
        body={'data':{'IdCaisseFk':cash['record']['IdCaisse'],'ClotureLe':(datetime.now(timezone.utc)-timedelta(days=1)).isoformat(),'MontantCompte':'0'},'_version':fresh['_version'],'requestId':str(uuid.uuid4())}
        self.post('/clotures',body,status=409)
        archived=self.client().put(BASE+'/ecritures/'+str(draft['record']['IdPaiement']),{'data':{'ValidePaiement':False},'_version':draft['_version'],'requestId':str(uuid.uuid4())},format='json')
        self.assertEqual(archived.status_code,200,archived.data)
        self.assertFalse(archived.data['data']['canManage'])
        self.assertFalse(archived.data['data']['canValidate'])
        self.post('/clotures',body)

    def test_09_cash_revision_and_idempotency_conflict(self):
        body={'data':{'NomCaisse':'Rejeu '+uuid.uuid4().hex,'IdDeviseFk':self.usd},'requestId':str(uuid.uuid4())}
        created=self.post('/caisses',body)
        self.assertTrue(self.post('/caisses',body)['replayed'])
        self.post('/caisses',{**body,'data':{**body['data'],'NomCaisse':'Autre'}},status=409)
        mutation={'data':{'NomCaisse':'Correction '+uuid.uuid4().hex},'_version':created['_version'],'requestId':str(uuid.uuid4())}
        url=BASE+'/caisses/'+str(created['record']['IdCaisse'])
        updated=self.client().put(url,mutation,format='json')
        self.assertEqual(updated.status_code,200,updated.data)
        replay=self.client().put(url,mutation,format='json')
        self.assertEqual(replay.status_code,200,replay.data)
        self.assertTrue(replay.data['data']['replayed'])
        stale=self.client().put(url,{**mutation,'requestId':str(uuid.uuid4())},format='json')
        self.assertEqual(stale.status_code,409)

    def test_10_filters_sql_totals_export_and_sort(self):
        cash=self.cash()
        self.entry(cash,amount='25.15')
        self.entry(cash,amount='5.05',sens=-1)
        filters=json.dumps({'IdCaisseFk':cash['record']['IdCaisse']})
        page=self.client().get(BASE+'/registres/ecritures',{'filters':filters,'take':1,'page':2,'sort':'IdPaiement','direction':'asc'})
        self.assertEqual(page.status_code,200,page.data)
        self.assertEqual(page.data['data']['total'],2)
        synthesis=self.client().get(BASE+'/synthese',{'filters':filters}).data['data']['totals'][0]
        self.assertEqual(Decimal(synthesis['Solde']),Decimal('20.10'))
        self.assertEqual(Decimal(synthesis['Entrees']),Decimal('25.15'))
        for kind in ['caisses','ecritures','clotures']:
            response=self.client().get(BASE+'/registres/'+kind+'.xlsx')
            self.assertEqual(response.status_code,200,getattr(response,'data',None))
            self.assertTrue(b''.join(response.streaming_content).startswith(b'PK'))
        response=self.client().get(BASE+'/registres/ecritures.csv',{'filters':filters,'columns':json.dumps(['CodePaiement','MontantPaiement','DeviseCode'])})
        self.assertEqual(response.status_code,200,getattr(response,'data',None))
        content=b''.join(response.streaming_content).decode('utf-8-sig')
        lines=list(csv.reader(io.StringIO(content),delimiter=';'))
        self.assertEqual(lines[0],['Écriture','Montant','Devise'])
        self.assertEqual(len(lines),3)
        self.assertEqual(self.client().get(BASE+'/registres/ecritures',{'sort':'CreationPayloadHash'}).status_code,422)
        self.assertEqual(self.client().get(BASE+'/registres/ecritures.csv',{'columns':json.dumps(['CreationPayloadHash'])}).status_code,400)

    def test_11_real_licence_denial_and_table_catalogue(self):
        actor=Actor({**self.users[1],'Is_Admin':False})
        client=APIClient(); client.force_authenticate(actor)
        response=client.get(BASE+'/registres/caisses')
        self.assertEqual(response.status_code,403,response.data)
        for kind in ['caisses','ecritures','clotures']:
            snapshot=self.client().get('/api/tableaux/caisse.'+kind+'/preferences')
            self.assertEqual(snapshot.status_code,200,snapshot.data)
            self.assertTrue(snapshot.data['data']['columns'])
            self.assertTrue(snapshot.data['data']['export']['columns'])

    def test_12_currency_identity_protection_and_label_keep_all_flows(self):
        cash=self.cash()
        first=self.entry(cash,amount='12.15')
        currency=db.one('SELECT "AbrGenerique","NomGenerique" FROM referentiel."T_Generique" WHERE "ID_Generique"=%s',[self.usd])
        old_code=currency['AbrGenerique'];new_code='USDQA'+uuid.uuid4().hex[:8]
        with self.assertRaises(psycopg.errors.CheckViolation):
            self.sql.execute('UPDATE referentiel."T_Generique" SET "AbrGenerique"=%s WHERE "ID_Generique"=%s',[new_code,self.usd])
        try:
            self.sql.execute('UPDATE referentiel."T_Generique" SET "NomGenerique"=%s WHERE "ID_Generique"=%s',['Dollar fictif '+uuid.uuid4().hex[:8],self.usd])
            self.entry(cash,amount='3.05')
            result=self.client().get(BASE+'/synthese',{'filters':json.dumps({'IdCaisseFk':cash['record']['IdCaisse']})})
            self.assertEqual(result.status_code,200,result.data)
            data=result.data['data'];self.assertEqual(len(data['totals']),1)
            self.assertEqual(Decimal(data['totals'][0]['Entrees']),Decimal('15.20'))
            self.assertEqual(Decimal(data['totals'][0]['Solde']),Decimal('15.20'))
            self.assertEqual(sum(Decimal(row['Entrees']) for row in data['flux']),Decimal('15.20'))
            original=self.client().get(BASE+'/ecritures/'+str(first['record']['IdPaiement']))
            self.assertEqual(original.data['data']['record']['DeviseCode'],old_code)
        finally:
            self.sql.execute('UPDATE referentiel."T_Generique" SET "NomGenerique"=%s WHERE "ID_Generique"=%s',[currency['NomGenerique'],self.usd])


if __name__=='__main__': unittest.main(verbosity=2)
