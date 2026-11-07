"""Recette multi-dépôts sur copie privée locale uniquement, jamais la base de l'entreprise."""
import unittest
import uuid
from decimal import Decimal
from concurrent.futures import ThreadPoolExecutor
from threading import Barrier
from django.db import connections
from test_bons_commande_api import BonsCommandeAPI


class MultiDepotsAPI(BonsCommandeAPI):
    """Réutilise le vrai socle et les comptes de recette déjà protégés du projet."""

    def depot_id(self, entity=0):
        return self.connection.execute('SELECT "ID_Depot" id FROM logistique."T_Depot" WHERE "IdEntiteFk"=%s AND "Principal"', [self.entities[entity]]).fetchone()['id']

    def other_depot(self):
        response = self.client().post('/api/logistique/depots', {'requestId': str(uuid.uuid4()), 'NomDepot': 'Dépôt recette ' + uuid.uuid4().hex, 'AdresseDepot': 'Adresse fictive', 'Actif': True}, format='json')
        self.assertEqual(response.status_code, 201, response.data)
        return response.data['data']

    def stocked(self, qty='10', lots=None):
        article = self.article()
        body = self.payload(article, kind=self.be, quantity=qty, price='10', lots=lots)
        body['bon']['ID_DepotFk'] = self.depot_id()
        self.create(body)
        return article

    def local(self, article, depot):
        return self.connection.execute('SELECT * FROM logistique."V_StockDepot" WHERE "ID_ArticleFk"=%s AND "ID_DepotFk"=%s', [article, depot]).fetchone()

    def transfer(self, article, destination, qty='6', lots=None):
        body = {'requestId': str(uuid.uuid4()), 'transfert': {'ID_DepotSourceFk': self.depot_id(), 'ID_DepotDestinationFk': destination, 'ID_DeviseFk': self.currency, 'DateTransfert': '2026-11-07T10:00:00+01:00', 'Motif': 'Transfert fictif de recette'}, 'lignes': [{'ID_ArticleFk': article, 'QteDemandee': qty, 'Lots': lots or []}]}
        response = self.client().post('/api/logistique/transferts', body, format='json')
        self.assertEqual(response.status_code, 201, response.data)
        return response.data['data'], body

    def transition(self, transfer, action, **values):
        body = {'requestId': str(uuid.uuid4()), '_version': str(transfer['Version']), **values}
        response = self.client().post(f'/api/logistique/transferts/{transfer["ID_TransfertDepot"]}/{action}', body, format='json')
        self.assertEqual(response.status_code, 201, response.data)
        repeated = self.client().post(f'/api/logistique/transferts/{transfer["ID_TransfertDepot"]}/{action}', body, format='json')
        self.assertEqual(repeated.status_code, 200, repeated.data)
        return response.data['data']

    def simultaneous(self, calls):
        """Deux connexions PostgreSQL réelles, démarrées à la même barrière."""
        barrier=Barrier(len(calls))
        def run(call):
            try:
                with connections['default'].cursor() as cursor:
                    cursor.execute('SELECT pg_backend_pid()');pid=cursor.fetchone()[0]
                client=self.client();barrier.wait(timeout=10)
                return pid,call(client)
            finally:connections.close_all()
        with ThreadPoolExecutor(max_workers=len(calls)) as pool:
            results=list(pool.map(run,calls))
        self.assertEqual(len({pid for pid,_ in results}),len(calls))
        return [response for _,response in results]

    def test_multi_01_depot_creation_revision_isolation_and_deactivation(self):
        row = self.other_depot(); pk = row['ID_Depot']
        update = {'requestId': str(uuid.uuid4()), '_version': str(row['Version']), 'NomDepot': 'Dépôt corrigé de recette', 'Actif': False}
        changed = self.client().put(f'/api/logistique/depots/{pk}', update, format='json')
        self.assertEqual(changed.status_code, 200, changed.data)
        self.assertFalse(changed.data['data']['Actif'])
        self.assertEqual(self.client(1).get(f'/api/logistique/depots/{pk}').status_code, 404)
        denied = self.client(manage=False).post('/api/logistique/depots', {'requestId': str(uuid.uuid4()), 'NomDepot': 'Interdit'}, format='json')
        self.assertEqual(denied.status_code, 403, denied.data)

    def test_multi_02_complete_partial_transfer_preserves_cash_and_journal(self):
        article = self.stocked(); destination = self.other_depot()['ID_Depot']; source = self.depot_id()
        cash = self.connection.execute('SELECT count(*) n FROM operations."T_Paiement"').fetchone()['n']
        transfer, body = self.transfer(article, destination)
        replay = self.client().post('/api/logistique/transferts', body, format='json')
        self.assertEqual(replay.status_code, 200, replay.data)
        self.assertEqual(transfer['ID_TransfertDepot'], replay.data['data']['ID_TransfertDepot'])
        transfer = self.transition(transfer, 'valider')
        self.assertEqual(self.local(article, source)['StockReserve'], Decimal('6'))
        self.assertEqual(self.local(article, source)['StockDisponible'], Decimal('4'))
        transfer = self.transition(transfer, 'expedier')
        self.assertEqual(self.local(article, source)['StockPhysique'], Decimal('4'))
        self.assertEqual(transfer['lignes'][0]['QteTransit'], Decimal('6'))
        transfer = self.transition(transfer, 'receptionner', lignes=[{'ID_ArticleFk': article, 'Quantite': '2'}])
        self.assertEqual(transfer['EtatCode'], 'TR_PARTIEL')
        self.assertEqual(self.local(article, destination)['StockPhysique'], Decimal('2'))
        transfer = self.transition(transfer, 'receptionner', lignes=[{'ID_ArticleFk': article, 'Quantite': '4'}])
        self.assertEqual(transfer['EtatCode'], 'TR_TERMINE')
        self.assertEqual(self.local(article, destination)['StockPhysique'], Decimal('6'))
        self.assertEqual(self.state(article)['stock'], Decimal('10'))
        self.assertEqual(self.state(article)['movements'], 4)
        self.assertEqual(self.connection.execute('SELECT count(*) n FROM operations."T_Paiement"').fetchone()['n'], cash)
        commands = [action['ID_CommandeFk'] for action in transfer['actions'] if action['ID_CommandeFk']]
        self.assertEqual(len(commands), 3)
        for command in commands:
            response = self.client().get(f'/api/logistique/commandes/{command}/composition')
            self.assertEqual(response.status_code, 200, response.data)
            self.assertFalse(response.data['meta']['canEdit'])

    def test_multi_03_cancel_and_close_gap_keep_proof(self):
        article = self.stocked(); destination = self.other_depot()['ID_Depot']
        transfer, _ = self.transfer(article, destination, qty='5')
        transfer = self.transition(self.transition(transfer, 'valider'), 'expedier')
        transfer = self.transition(transfer, 'receptionner', lignes=[{'ID_ArticleFk': article, 'Quantite': '2'}])
        transfer = self.transition(transfer, 'annuler', motif='Retour physique du solde de transit')
        self.assertEqual(transfer['lignes'][0]['QteRetournee'], Decimal('3'))
        self.assertEqual(transfer['lignes'][0]['QteTransit'], Decimal('0'))
        self.assertEqual(self.state(article)['stock'], Decimal('10'))
        transfer, _ = self.transfer(article, destination, qty='2')
        transfer = self.transition(self.transition(transfer, 'valider'), 'expedier')
        transfer = self.transition(transfer, 'traiter-ecart', motif='Perte documentée pendant le transport', lignes=[{'ID_ArticleFk': article, 'Quantite': '2'}])
        self.assertEqual(transfer['lignes'][0]['QteEcart'], Decimal('2'))
        self.assertEqual(transfer['lignes'][0]['QteTransit'], Decimal('0'))
        self.assertEqual(self.state(article)['stock'], Decimal('8'))

    def test_multi_04_insufficient_reserved_and_cross_entity_are_rejected(self):
        article = self.stocked(); destination = self.other_depot()['ID_Depot']
        transfer, _ = self.transfer(article, destination, qty='8')
        self.transition(transfer, 'valider')
        second, _ = self.transfer(article, destination, qty='3')
        response = self.client().post(f'/api/logistique/transferts/{second["ID_TransfertDepot"]}/valider', {'requestId': str(uuid.uuid4()), '_version': str(second['Version'])}, format='json')
        self.assertEqual(response.status_code, 409, response.data)
        foreign = {'requestId': str(uuid.uuid4()), 'transfert': {'ID_DepotSourceFk': self.depot_id(), 'ID_DepotDestinationFk': self.depot_id(1), 'ID_DeviseFk': self.currency, 'DateTransfert': '2026-11-07T12:00:00+01:00', 'Motif': 'Interdit'}, 'lignes': [{'ID_ArticleFk': article, 'QteDemandee': '1'}]}
        denied = self.client().post('/api/logistique/transferts', foreign, format='json')
        self.assertIn(denied.status_code, {403, 409}, denied.data)
        self.assertEqual(self.client(1).get(f'/api/logistique/transferts/{transfer["ID_TransfertDepot"]}').status_code, 404)

    def test_multi_05_lots_receipts_and_local_catalogue(self):
        lot = {'NumeroLot': 'LOT-' + uuid.uuid4().hex[:12], 'Quantite': '10', 'DatePeremptionLot': '2030-01-01'}
        article = self.stocked(lots=[lot]); destination = self.other_depot()['ID_Depot']
        transfer, _ = self.transfer(article, destination, qty='4', lots=[{**lot, 'Quantite': '4'}])
        transfer = self.transition(self.transition(transfer, 'valider'), 'expedier')
        transfer = self.transition(transfer, 'receptionner', lignes=[{'ID_ArticleFk': article, 'Quantite': '4'}])
        self.assertEqual(self.local(article, destination)['StockPhysique'], Decimal('4'))
        self.assertEqual(self.local(article, destination)['StockSansLot'], Decimal('0'))
        response = self.client().get('/api/logistique/registre/articles', {'depotId': destination, 'q': self.connection.execute('SELECT "NomArticle" FROM logistique."T_Article" WHERE "ID_Article"=%s', [article]).fetchone()['NomArticle']})
        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(Decimal(str(response.data['data'][0]['StockDepot'])), Decimal('4'))
        self.assertEqual(Decimal(str(response.data['data'][0]['StockEntreprise'])), Decimal('10'))
        fefo = self.client().get(f'/api/logistique/articles/{article}/lots/fefo', {'depotId': destination, 'quantite': '4'})
        self.assertEqual(fefo.status_code, 200, fefo.data)
        self.assertEqual(Decimal(str(fefo.data['data']['Lots'][0]['Quantite'])), Decimal('4'))

    def test_multi_06_receipt_and_initial_article_use_selected_depot_once(self):
        destination=self.other_depot()['ID_Depot'];article=self.article()
        body={'requestId':str(uuid.uuid4()),'ID_DepotFk':destination,'ID_TypeCmdFk':self.be,'ID_DeviseFk':self.currency,
              'DateCmd':'2026-11-07T10:00:00','QteCmdDetail':'7','PUCmdDetail':'11','Lots':[]}
        first=self.client().post(f'/api/logistique/articles/{article}/receptions',body,format='json')
        self.assertEqual(first.status_code,201,first.data)
        self.assertEqual(self.client().post(f'/api/logistique/articles/{article}/receptions',body,format='json').status_code,200)
        self.assertEqual(self.local(article,destination)['StockPhysique'],Decimal('7'))
        self.assertEqual(self.local(article,self.depot_id())['StockPhysique'],Decimal('0'))
        self.assertEqual(self.state(article)['movements'],1)
        for endpoint in (f'/api/logistique/articles/{article}',f'/api/logistique/articles/{article}/receptions'):
            response=self.client().get(endpoint,{'depotId':destination})
            self.assertEqual(response.status_code,200,response.data)
            record=response.data['data'].get('article',response.data['data'])
            self.assertEqual(Decimal(str(record['QteArticle'])),Decimal('7'))
        data={'requestId':str(uuid.uuid4()),'ID_DepotFk':destination,'NomArticle':'Ouverture dépôt '+uuid.uuid4().hex,
              'ID_CategorieArticleFk':self.category,'ID_TypeArticleFk':self.article_type,'ID_UniteFk':self.unit,
              'ID_DeviseFk':self.currency,'QteArticle':'3','PUArticle':'10','PVArticle':'15','ValideArticle':True}
        first=self.client().post('/api/logistique/articles',data,format='json')
        self.assertEqual(first.status_code,201,first.data)
        key=first.data['data']['ID_Article']
        replay=self.client().post('/api/logistique/articles',data,format='json')
        self.assertIn(replay.status_code,(200,201),replay.data)
        self.assertEqual(replay.data['data']['ID_Article'],key)
        self.assertEqual(self.local(key,destination)['StockPhysique'],Decimal('3'))
        self.assertEqual(self.state(key)['movements'],1)

    def test_multi_07_inventory_correction_cancellation_is_local(self):
        article=self.stocked();destination=self.other_depot()['ID_Depot']
        transfer,_=self.transfer(article,destination,qty='4')
        transfer=self.transition(self.transition(transfer,'valider'),'expedier')
        self.transition(transfer,'receptionner',lignes=[{'ID_ArticleFk':article,'Quantite':'4'}])
        payload={'requestId':str(uuid.uuid4()),'ID_DepotFk':destination,'DateInventaire':'2026-11-07T10:00:00+01:00','Motif':'Écart fictif dépôt',
                 'lignes':[{'ID_ArticleFk':article,'QteTheorique':'4','QteComptee':'3','Justification':'Écart compté','Lots':[],'PUCorrection':'10'}]}
        response=self.client().post('/api/logistique/inventaires',payload,format='json')
        self.assertEqual(response.status_code,201,response.data);inventory=response.data['data'];key=inventory['ID_Inventaire']
        response=self.client().post(f'/api/logistique/inventaires/{key}/valider',{'requestId':str(uuid.uuid4()),'_version':str(inventory['Version'])},format='json')
        self.assertEqual(response.status_code,201,response.data);inventory=response.data['data']
        self.assertEqual(self.local(article,destination)['StockPhysique'],Decimal('3'))
        self.assertEqual(self.local(article,self.depot_id())['StockPhysique'],Decimal('6'))
        response=self.client().post(f'/api/logistique/inventaires/{key}/annuler',{'requestId':str(uuid.uuid4()),'_version':str(inventory['Version']),'motif':'Reprise comptage'},format='json')
        self.assertEqual(response.status_code,201,response.data)
        self.assertEqual(self.local(article,destination)['StockPhysique'],Decimal('4'))
        catalogue=self.client().get('/api/logistique/inventaires/catalogue',{'depotId':destination,'q':self.connection.execute('SELECT "NomArticle" FROM logistique."T_Article" WHERE "ID_Article"=%s',[article]).fetchone()['NomArticle'],'sortBy':'QteArticle'})
        self.assertEqual(catalogue.status_code,200,catalogue.data)
        self.assertEqual(Decimal(str(catalogue.data['data'][0]['QteArticle'])),Decimal('4'))

    def test_multi_08_lot_reservations_and_missing_allocation_are_rejected(self):
        lots=[{'NumeroLot':'A-'+uuid.uuid4().hex,'Quantite':'5','DatePeremptionLot':'2030-01-01'},
              {'NumeroLot':'B-'+uuid.uuid4().hex,'Quantite':'5','DatePeremptionLot':'2031-01-01'}]
        article=self.stocked(lots=lots);destination=self.other_depot()['ID_Depot']
        first,_=self.transfer(article,destination,qty='4',lots=[{**lots[0],'Quantite':'4'}]);self.transition(first,'valider')
        second,_=self.transfer(article,destination,qty='4',lots=[{**lots[0],'Quantite':'4'}])
        denied=self.client().post(f'/api/logistique/transferts/{second["ID_TransfertDepot"]}/valider',{'requestId':str(uuid.uuid4()),'_version':str(second['Version'])},format='json')
        self.assertEqual(denied.status_code,409,denied.data)
        absent,_=self.transfer(article,destination,qty='1')
        denied=self.client().post(f'/api/logistique/transferts/{absent["ID_TransfertDepot"]}/valider',{'requestId':str(uuid.uuid4()),'_version':str(absent['Version'])},format='json')
        self.assertEqual(denied.status_code,409,denied.data)
        self.assertEqual(denied.data['error']['code'],'TRANSFER_LOT_REQUIRED')
        self.assertEqual(self.local(article,self.depot_id())['StockReserve'],Decimal('4'))

    def test_multi_09_gap_closes_one_article_balance_keeps_other_in_transit(self):
        article=self.stocked();other=self.stocked();destination=self.other_depot()['ID_Depot']
        _,body=self.transfer(article,destination,qty='5')
        body['requestId']=str(uuid.uuid4());body['lignes'].append({'ID_ArticleFk':other,'QteDemandee':'2'})
        response=self.client().post('/api/logistique/transferts',body,format='json');self.assertEqual(response.status_code,201,response.data)
        transfer=self.transition(self.transition(response.data['data'],'valider'),'expedier')
        transfer=self.transition(transfer,'receptionner',lignes=[{'ID_ArticleFk':article,'Quantite':'2'}])
        denied=self.client().post(f'/api/logistique/transferts/{transfer["ID_TransfertDepot"]}/traiter-ecart',{'requestId':str(uuid.uuid4()),'_version':str(transfer['Version']),'motif':'Perte','lignes':[{'ID_ArticleFk':article,'Quantite':'1'}]},format='json')
        self.assertEqual(denied.status_code,409,denied.data)
        transfer=self.transition(transfer,'traiter-ecart',motif='Solde définitivement perdu',lignes=[{'ID_ArticleFk':article,'Quantite':'3'}])
        self.assertEqual(transfer['EtatCode'],'TR_PARTIEL')
        transfer=self.transition(transfer,'receptionner',lignes=[{'ID_ArticleFk':other,'Quantite':'2'}])
        self.assertEqual(transfer['EtatCode'],'TR_TERMINE')
        self.assertEqual(self.state(article)['stock'],Decimal('7'))
        self.assertEqual(self.state(other)['stock'],Decimal('10'))

    def test_multi_10_internal_documents_cannot_enter_commercial_or_generic_circuits(self):
        article=self.stocked();destination=self.other_depot()['ID_Depot']
        transfer,_=self.transfer(article,destination,qty='2');transfer=self.transition(self.transition(transfer,'valider'),'expedier')
        command=next(row['ID_CommandeFk'] for row in transfer['actions'] if row['ID_CommandeFk'])
        current=self.client().get(f'/api/logistique/commandes/{command}/composition');self.assertEqual(current.status_code,200,current.data)
        self.assertFalse(current.data['meta']['canEdit']);self.assertFalse(current.data['meta']['canInvoice'])
        for field,value in [('ID_DepotFk',destination),('ID_TypeCmdFk',self.be),('ID_DeviseFk',self.currency),('ID_ModePaiementFk',1)]:
            payload={'requestId':str(uuid.uuid4()),'_version':current.data['meta']['revision'],'bon':{field:value},'lignes':[{'ID_ArticleFk':article,'QteCmdDetail':'1','PUCmdDetail':'10'}]}
            denied=self.client().put(f'/api/logistique/commandes/{command}/composition',payload,format='json')
            self.assertIn(denied.status_code,(400,409),denied.data)
        invoice=self.client().get(f'/api/logistique/commandes/{command}/facture');self.assertEqual(invoice.status_code,200,invoice.data)
        self.assertFalse(invoice.data['meta']['canIssue'])
        returned=self.client().get(f'/api/logistique/commandes/{command}/retours');self.assertEqual(returned.status_code,200,returned.data)
        self.assertFalse(returned.data['meta']['canReturn'])
        pdf=self.client().get(f'/api/logistique/documents/bon/{command}/sortie.pdf')
        self.assertEqual(pdf.status_code,200,pdf.data if hasattr(pdf,'data') else None)
        self.assertTrue(pdf.content.startswith(b'%PDF-'))

    def test_multi_11_old_request_replay_and_local_stock_sort(self):
        article=self.stocked();destination=self.other_depot()['ID_Depot'];transfer,creation=self.transfer(article,destination,qty='2')
        body={'requestId':str(uuid.uuid4()),'_version':str(transfer['Version'])};key=transfer['ID_TransfertDepot']
        response=self.client().post(f'/api/logistique/transferts/{key}/valider',body,format='json');self.assertEqual(response.status_code,201,response.data)
        transfer=self.transition(response.data['data'],'expedier');self.transition(transfer,'receptionner',lignes=[{'ID_ArticleFk':article,'Quantite':'2'}])
        replay=self.client().post(f'/api/logistique/transferts/{key}/valider',body,format='json')
        self.assertEqual(replay.status_code,200,replay.data);self.assertEqual(replay.data['data']['EtatCode'],'TR_TERMINE')
        replay=self.client().post('/api/logistique/transferts',creation,format='json');self.assertEqual(replay.status_code,200,replay.data)
        self.assertEqual(self.state(article)['movements'],3)
        response=self.client().get('/api/logistique/stocks-depots',{'articleId':article,'sortBy':'StockPhysique','sortDir':'desc'})
        self.assertEqual(response.status_code,200,response.data);rows=response.data['data']
        amounts=[Decimal(str(row['StockPhysique'])) for row in rows]
        self.assertEqual(amounts,sorted(amounts,reverse=True))
        self.assertEqual([amount for amount in amounts if amount>0],[Decimal('8'),Decimal('2')])
        self.assertEqual(rows[0]['AbrUnite'],'test-cmd-pcs')

    def test_multi_12_simultaneous_reservations_cannot_overdraw(self):
        article=self.stocked();destination=self.other_depot()['ID_Depot']
        first,_=self.transfer(article,destination,qty='8');second,_=self.transfer(article,destination,qty='8')
        calls=[]
        for transfer in (first,second):
            url=f'/api/logistique/transferts/{transfer["ID_TransfertDepot"]}/valider'
            body={'requestId':str(uuid.uuid4()),'_version':str(transfer['Version'])}
            calls.append(lambda client,url=url,body=body:client.post(url,body,format='json'))
        responses=self.simultaneous(calls)
        self.assertEqual(sorted(response.status_code for response in responses),[201,409],[response.data for response in responses])
        self.assertEqual(self.local(article,self.depot_id())['StockReserve'],Decimal('8'))
        self.assertEqual(self.local(article,self.depot_id())['StockDisponible'],Decimal('2'))

    def test_multi_13_simultaneous_replay_and_receive_cancel_have_one_effect(self):
        article=self.stocked();destination=self.other_depot()['ID_Depot'];transfer,_=self.transfer(article,destination)
        transfer=self.transition(transfer,'valider');key=transfer['ID_TransfertDepot']
        body={'requestId':str(uuid.uuid4()),'_version':str(transfer['Version'])};url=f'/api/logistique/transferts/{key}/expedier'
        responses=self.simultaneous([lambda client:client.post(url,body,format='json')]*2)
        self.assertEqual(sorted(response.status_code for response in responses),[200,201],[response.data for response in responses])
        transfer=responses[0].data['data'];revision=str(transfer['Version'])
        receive={'requestId':str(uuid.uuid4()),'_version':revision,'lignes':[{'ID_ArticleFk':article,'Quantite':'6'}]}
        cancel={'requestId':str(uuid.uuid4()),'_version':revision,'motif':'Annulation simultanée de recette'}
        responses=self.simultaneous([lambda client:client.post(f'/api/logistique/transferts/{key}/receptionner',receive,format='json'),lambda client:client.post(f'/api/logistique/transferts/{key}/annuler',cancel,format='json')])
        self.assertEqual(sorted(response.status_code for response in responses),[201,409],[response.data for response in responses])
        self.assertEqual(self.state(article)['stock'],Decimal('10'));self.assertEqual(self.state(article)['movements'],3)
        final=self.client().get(f'/api/logistique/transferts/{key}').data['data']
        self.assertEqual(final['lignes'][0]['QteTransit'],Decimal('0'))
        self.assertEqual(len(final['bons']),2)

    def test_multi_14_batch_opening_is_atomic_in_selected_depot(self):
        destination=self.other_depot()['ID_Depot']
        data={'NomArticle':'Panier dépôt '+uuid.uuid4().hex,'ID_CategorieArticleFk':self.category,'ID_TypeArticleFk':self.article_type,
              'ID_UniteFk':self.unit,'ID_DeviseFk':self.currency,'QteArticle':'3','PUArticle':'10','PVArticle':'15','ValideArticle':True}
        body={'requestId':str(uuid.uuid4()),'ID_DepotFk':destination,'openingReceipt':True,'rows':[{'clientRowId':'ligne-1','data':data},{'clientRowId':'ligne-2','data':{**data,'NomArticle':'Panier dépôt '+uuid.uuid4().hex,'QteArticle':'2'}}]}
        first=self.client().post('/api/logistique/saisie-multiple/articles',body,format='json')
        self.assertEqual(first.status_code,201,first.data);result=first.data['data'];command=result['openingReceipt']['id']
        self.assertEqual(self.connection.execute('SELECT "ID_DepotFk" id FROM logistique."T_Commande" WHERE "ID_Commande"=%s',[command]).fetchone()['id'],destination)
        self.assertEqual(self.connection.execute('SELECT count(*) n FROM logistique."T_Mouvement" WHERE "ID_cmdFk"=%s',[command]).fetchone()['n'],2)
        for record in result['records']:self.assertGreater(self.local(record['ID_Article'],destination)['StockPhysique'],0)
        self.assertEqual(self.client().post('/api/logistique/saisie-multiple/articles',body,format='json').status_code,200)
        body['requestId']=str(uuid.uuid4());body['rows'][0]['data']['NomArticle']='Atomicité '+uuid.uuid4().hex
        body['rows'][1]['data']['QteArticle']='-1'
        denied=self.client().post('/api/logistique/saisie-multiple/articles',body,format='json');self.assertEqual(denied.status_code,422,denied.data)
        self.assertEqual(self.connection.execute('SELECT count(*) n FROM logistique."T_Article" WHERE "NomArticle"=%s',[body['rows'][0]['data']['NomArticle']]).fetchone()['n'],0)

    def test_multi_15_foreign_depot_lot_and_deactivation_are_rejected(self):
        lot={'NumeroLot':'MAUVAIS-DEPOT-'+uuid.uuid4().hex,'Quantite':'10','DatePeremptionLot':'2030-01-01'}
        article=self.stocked(lots=[lot]);destination=self.other_depot();pk=destination['ID_Depot']
        body=self.payload(article,kind=self.bs,quantity='1',lots=[{**lot,'Quantite':'1'}]);body['bon']['ID_DepotFk']=pk
        denied=self.client().post('/api/logistique/commandes/composees',body,format='json');self.assertEqual(denied.status_code,409,denied.data)
        principal=self.client().get(f'/api/logistique/depots/{self.depot_id()}').data['data']
        for changes in ({'Actif':False},{'Principal':False}):
            denied=self.client().put(f'/api/logistique/depots/{principal["ID_Depot"]}',{'requestId':str(uuid.uuid4()),'_version':str(principal['Version']),**changes},format='json')
            self.assertEqual(denied.status_code,409,denied.data)
        pending=self.payload(article,kind=self.cmd,quantity='1');pending['bon']['ID_DepotFk']=pk;self.create(pending)
        denied=self.client().put(f'/api/logistique/depots/{pk}',{'requestId':str(uuid.uuid4()),'_version':str(destination['Version']),'Actif':False},format='json')
        self.assertEqual(denied.status_code,409,denied.data)

    def test_multi_16_transfer_supports_unit_precision(self):
        unit=self.connection.execute('INSERT INTO referentiel."T_Generique" ("ID_CategorieGeneriqueFk","NomGenerique","AbrGenerique","ValideGenerique") VALUES (34,%s,%s,true) RETURNING "ID_Generique" id',['Kilogramme fictif '+uuid.uuid4().hex,'kg-'+uuid.uuid4().hex]).fetchone()['id']
        self.connection.execute('INSERT INTO logistique."T_PrecisionStock" ("ID_UniteFk","DecimalesStock") VALUES (%s,3)',[unit])
        from apps.core import repository
        article=repository.mutate('T_Article',self.actor(),{'NomArticle':'Fraction dépôt '+uuid.uuid4().hex,'ID_CategorieArticleFk':self.category,'ID_TypeArticleFk':self.article_type,'ID_UniteFk':unit,'ID_DeviseFk':self.currency,'QteArticle':'0','PUArticle':'10','PVArticle':'15','ValideArticle':True})['ID_Article']
        body=self.payload(article,kind=self.be,quantity='1.25');body['bon']['ID_DepotFk']=self.depot_id();self.create(body)
        destination=self.other_depot()['ID_Depot'];transfer,_=self.transfer(article,destination,qty='0.5')
        transfer=self.transition(self.transition(transfer,'valider'),'expedier');self.transition(transfer,'receptionner',lignes=[{'ID_ArticleFk':article,'Quantite':'0.5'}])
        self.assertEqual(self.local(article,self.depot_id())['StockPhysique'],Decimal('0.75'))
        self.assertEqual(self.local(article,destination)['StockPhysique'],Decimal('0.5'))

    def test_multi_17_scoped_alerts_replenishment_dashboard_and_exports(self):
        lot={'NumeroLot':'PERIME-DEPOT-'+uuid.uuid4().hex,'Quantite':'10','DatePeremptionLot':'2020-01-01'}
        article=self.stocked(lots=[lot]);destination=self.other_depot()['ID_Depot']
        self.connection.execute('UPDATE logistique."T_Article" SET "QteMinArticle"=6 WHERE "ID_Article"=%s',[article])
        name=self.connection.execute('SELECT "NomArticle" FROM logistique."T_Article" WHERE "ID_Article"=%s',[article]).fetchone()['NomArticle']
        for depot,expired,qty,reorder in [(self.depot_id(),True,10,0),(destination,False,0,6)]:
            criteria={'depotId':depot,'q':name}
            response=self.client().get('/api/logistique/registre/articles',criteria);self.assertEqual(response.status_code,200,response.data)
            row=response.data['data'][0];self.assertEqual(row['EstPerime'],expired);self.assertEqual(Decimal(str(row['QteArticle'])),qty)
            self.assertEqual(Decimal(str(row['QteACommander'])),reorder)
            identity=self.client().get(f'/api/logistique/consultations/produit/{article}',criteria);self.assertEqual(identity.status_code,200,identity.data)
            self.assertEqual(identity.data['data']['record']['EstPerime'],expired)
            overview=self.client().get('/api/logistique/synthese',criteria);self.assertEqual(overview.status_code,200,overview.data)
            self.assertEqual(int(overview.data['data']['totals']['articlesPerimes']),int(expired))
            for suffix in ('audit','alertes','consommation','couverture'):
                response=self.client().get('/api/logistique/stock/'+suffix,criteria);self.assertEqual(response.status_code,200,response.data)
            for suffix in ('consommation','couverture','controle'):
                response=self.client().get(f'/api/logistique/consultations/produit/{article}/{suffix}',{'depotId':depot,'deviseId':self.currency});self.assertEqual(response.status_code,200,response.data)
            movements=self.client().get('/api/logistique/registre/mouvements',{'depotId':depot,'articleId':article});self.assertEqual(movements.status_code,200,movements.data)
            self.assertTrue(all(Decimal(str(row['StockActuel']))==qty for row in movements.data['data']))
            export=self.client().get('/api/logistique/registre/articles/export.xlsx',criteria);self.assertEqual(export.status_code,200)
            self.assertTrue(b''.join(export.streaming_content).startswith(b'PK') if export.streaming else export.content.startswith(b'PK'))
        response=self.client().get('/api/logistique/transferts',{'take':100})
        self.assertEqual(response.status_code,200,response.data)
        self.assertTrue(all('DepotSource' in row and 'DepotDestination' in row for row in response.data['data']))


    def test_multi_18_transfer_uses_original_cump_and_preserves_held_value(self):
        article=self.stocked(qty='10')
        body=self.payload(article,kind=self.be,quantity='10',price='20');body['bon']['ID_DepotFk']=self.depot_id();self.create(body)
        self.connection.execute('UPDATE logistique."T_Article" SET "PUArticle"=999,"PVArticle"=1999 WHERE "ID_Article"=%s',[article])
        def value():
            row=self.connection.execute('SELECT "ValeurStock" value,"CoutUnitaireMoyen" cost FROM logistique."V_ValorisationStock" WHERE "ID_Article"=%s AND "ID_DeviseFk"=%s',[article,self.currency]).fetchone()
            transit=self.connection.execute('SELECT coalesce(sum("QteTransit"*"CoutUnitaireSource"),0) value FROM logistique."V_StockTransit" WHERE "ID_ArticleFk"=%s',[article]).fetchone()['value']
            return Decimal(str(row['value'])),Decimal(str(row['cost'])),Decimal(str(transit))
        self.assertEqual(value(),(Decimal('300'),Decimal('15'),Decimal('0')))
        destination=self.other_depot()['ID_Depot'];transfer,_=self.transfer(article,destination,qty='6')
        transfer=self.transition(self.transition(transfer,'valider'),'expedier')
        physical,cost,transit=value();self.assertEqual((physical,cost,transit),(Decimal('210'),Decimal('15'),Decimal('90')))
        transfer=self.transition(transfer,'receptionner',lignes=[{'ID_ArticleFk':article,'Quantite':'2'}])
        physical,cost,transit=value();self.assertEqual((physical,cost,transit),(Decimal('240'),Decimal('15'),Decimal('60')))
        self.assertEqual(physical+transit,Decimal('300'))
        transfer=self.transition(transfer,'annuler',motif='Retour de transit avec coût origine')
        self.assertEqual(value(),(Decimal('300'),Decimal('15'),Decimal('0')))
        costs=self.connection.execute('SELECT c."CoutUnitaire" cost FROM logistique."V_CoutMouvement" c JOIN logistique."T_Mouvement" m ON m."ID_Mvt"=c."ID_Mvt" JOIN logistique."T_Commande" b ON b."ID_Commande"=m."ID_cmdFk" WHERE b."ID_TransfertDepotFk"=%s',[transfer['ID_TransfertDepot']]).fetchall()
        self.assertEqual(len(costs),3);self.assertTrue(all(row['cost']==Decimal('15') for row in costs))
        prices=self.connection.execute('SELECT l."PUCmdDetail" price FROM logistique."T_CommandeDetail" l JOIN logistique."T_Commande" b ON b."ID_Commande"=l."ID_CmdFk" WHERE b."ID_TransfertDepotFk"=%s',[transfer['ID_TransfertDepot']]).fetchall()
        self.assertEqual(len(prices),3);self.assertTrue(all(row['price']==Decimal('15') for row in prices))


if __name__ == '__main__':
    # Les recettes héritées restent disponibles séparément dans leur fichier.
    suite = unittest.TestSuite(MultiDepotsAPI(name) for name in unittest.defaultTestLoader.getTestCaseNames(MultiDepotsAPI) if name.startswith('test_multi_'))
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    raise SystemExit(0 if result.wasSuccessful() else 1)
