"""Patrimoine : parcours API réel, exclusivement PostgreSQL privé et fictif."""
import csv
import hashlib
import io
import json
import os
import sys
import threading
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
if location.hostname not in {'localhost', '127.0.0.1', '::1'} or not location.path[1:].startswith('sauverndeko_test_'):
    raise RuntimeError('Recette réservée à PostgreSQL privé local sauverndeko_test_*.')
with psycopg.connect(DSN) as check:
    if not check.execute('SELECT current_database()').fetchone()[0].startswith('sauverndeko_test_'):
        raise RuntimeError('Base privée requise.')
os.environ.update(DATABASE_URL=DSN, DJANGO_SETTINGS_MODULE='config.settings', SAUVERNDEKO_DB_READ_ONLY='0')
sys.path.insert(0, str(ROOT / 'backend'))
import django
django.setup()
from django.test import override_settings
from django.db import connections, transaction
from rest_framework.test import APIClient
from apps.accounts.authentication import Actor
from apps.core import db
from apps.logistique import immobilisations as service

BASE = '/api/logistique/immobilisations'


class ImmobilisationsAPI(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.settings = override_settings(ALLOWED_HOSTS=['testserver'])
        cls.settings.enable()
        cls.sql = psycopg.connect(DSN, autocommit=True, row_factory=dict_row)
        cls.entities = [cls.sql.execute('INSERT INTO systeme."T_Entite"("NomEntite","EmailEntite","ValideEntite") VALUES(%s,%s,true) RETURNING "IdEntite" id', ['Patrimoine fictif '+uuid.uuid4().hex,uuid.uuid4().hex+'@example.invalid']).fetchone()['id'] for _ in range(3)]
        cls.users = [cls.sql.execute('''INSERT INTO systeme."T_Utilisateurs"("NomUser","PrenomUser","EmailUser","MotdepasseUser","ValideUser","SexeUser","Is_Admin","Is_staff","IdEntiteFk")
          VALUES('Fictif','Patrimoine',%s,'inutilisable',true,'M',true,true,%s) RETURNING *''', [uuid.uuid4().hex+'@example.invalid', entity]).fetchone() for entity in cls.entities]
        cls.locations = [cls.sql.execute('INSERT INTO systeme."T_Entite_Localisation"("IdEntiteFk","AdresseDetaillee") VALUES(%s,%s) RETURNING "IdEntiteLocalisation" id', [entity,'Adresse fictive '+str(entity)]).fetchone()['id'] for entity in cls.entities]
        cls.refs = cls.client().get(BASE+'/references').data['data']
        cls.category = cls.refs['types'][0]['id']
        cls.usd = cls.refs['defaultCurrencyId']
        cls.second_currency = next(row['id'] for row in cls.refs['currencies'] if row['id'] != cls.usd)

    @classmethod
    def tearDownClass(cls):
        cls.sql.close()
        cls.settings.disable()

    @classmethod
    def actor(cls, index=0, *, global_admin=True, manage=True, export=True, read=True, all_entities=False):
        actor = Actor({**cls.users[0 if global_admin else index], 'Is_Admin': global_admin})
        if global_admin and not all_entities:
            actor._context_entity = cls.entities[index]
        rights = {'canRead': read, 'canManage': manage, 'canExport': export, 'reason': 'MODULE_ROLE_FORBIDDEN'}
        actor._module_access = {
            'modules': {module: rights for module in ['logistique', 'administration']},
            'tabs': {'logistique': {'immobilisations': rights}},
        }
        return actor

    @classmethod
    def client(cls, index=0, **rights):
        client = APIClient()
        client.force_authenticate(cls.actor(index, **rights))
        return client

    def body(self, **changes):
        result = {'NomImmobilisation':'Bien fictif '+uuid.uuid4().hex, 'ID_CategorieFk':self.category,
            'DateEntree':'2026-10-28T13:35:00+01:00','Quantite':'1','SuiviIndividuel':True,
            'requestId':str(uuid.uuid4()),'motif':'Recette fictive de patrimoine'}
        result.update(changes)
        return result

    def assert_response(self, response, status=200):
        self.assertEqual(response.status_code, status, getattr(response,'data', 'Réponse binaire'))
        return getattr(response,'data',{}).get('data')

    def create(self, index=0, **changes):
        return self.assert_response(self.client(index).post(BASE,self.body(**changes),format='json'),201)

    def update(self, row, index=0, **changes):
        body = {'_version':row['_version'],'requestId':str(uuid.uuid4()),'motif':'Modification fictive',**changes}
        return self.client(index).put(BASE+'/'+str(row['ID_Immobilisation']),body,format='json')

    def test_01_complete_form_exact_prices_and_unknown(self):
        row = self.create(Reference='0000123',Caracteristiques='Ordinateur\nPortable',PrixUnitaire='12.34',
            ID_EtatFk=self.refs['etats'][0]['id'],ID_ResponsableFk=self.users[0]['IdUser'],
            ID_ServiceFk=self.refs['services'][0]['id'],ID_LocalisationFk=self.locations[0],LocalisationComplement='Bureau A',
            DateAcquisition='2026-10-20',NumeroSerie='0000099',Observations='Information complémentaire')
        response = self.client().get(BASE+'/'+str(row['ID_Immobilisation']))
        full = self.assert_response(response)
        self.assertEqual(full['ID_DeviseFk'], self.usd)
        self.assertEqual(full['PrixUnitaire'],Decimal('12.34'))
        self.assertEqual(full['ValeurAcquisition'],Decimal('12.34'))
        self.assertEqual(full['Reference'],'0000123')
        self.assertEqual(full['NumeroSerie'],'0000099')
        self.assertTrue(full['Responsable'])
        self.assertTrue(full['Localisation'])
        self.assertTrue(response.data['meta']['canArchive'])
        self.assertTrue(response.data['meta']['canExport'])
        unknown = self.create(PrixUnitaire=None,ID_DeviseFk=None)
        self.assertIsNone(unknown['PrixUnitaire'])
        self.assertIsNone(unknown['ValeurAcquisition'])
        self.assertIsNone(unknown['ID_DeviseFk'])
        self.assert_response(self.update(unknown,Observations='Coût toujours inconnu'))
        zero = self.create(PrixUnitaire='0')
        self.assertEqual(zero['ValeurAcquisition'],Decimal('0.00'))

    def test_02_groups_precision_and_validation(self):
        row = self.create(SuiviIndividuel=False,Quantite='999999999999999999')
        self.assertEqual(row['Quantite'],Decimal('999999999999999999'))
        for changes in [dict(Quantite='0'),dict(Quantite='0.5'),dict(Quantite='1000000000000000000',SuiviIndividuel=False),
            dict(Quantite='2'),dict(Quantite='2',NumeroSerie='SERIE',SuiviIndividuel=False),dict(Quantite=True),
            dict(PrixUnitaire='-1'),dict(PrixUnitaire='1.001'),dict(ID_CategorieFk=None),dict(NomImmobilisation=''),
            dict(NomImmobilisation='\tNom'),dict(SuiviIndividuel='false'),dict(Actif=None),dict(CodeImmobilisation='IMMO-1'),
            dict(IdEntiteFk=self.entities[1]),dict(PrixUnitaire='1',ID_DeviseFk=None)]:
            with self.subTest(changes=changes):
                self.assert_response(self.client().post(BASE,self.body(**changes),format='json'),400)
        naive = self.create(DateEntree='2026-10-28T13:35:00')
        self.assertEqual(naive['DateEntree'].hour,12)

    def test_03_scopes_and_disabled_rights(self):
        own = self.create(); foreign = self.create(1)
        for global_admin in [False,True]:
            client = self.client(global_admin=global_admin)
            self.assert_response(client.get(BASE+'/'+str(foreign['ID_Immobilisation'])),404)
            self.assert_response(client.get(BASE+'/'+str(foreign['ID_Immobilisation'])+'/historique'),404)
            self.assert_response(client.get(BASE+'/references',{'immobilisationId':foreign['ID_Immobilisation']}),404)
        all_rows = self.assert_response(self.client(all_entities=True).get(BASE))
        self.assertTrue(any(row['ID_Immobilisation']==foreign['ID_Immobilisation'] for row in all_rows))
        self.assert_response(self.client(all_entities=True).post(BASE,self.body(),format='json'),409)
        self.assert_response(self.client(manage=False).post(BASE,self.body(),format='json'),403)
        self.assert_response(self.client(read=False).get(BASE),403)
        self.assert_response(self.client().post(BASE,self.body(ID_ResponsableFk=self.users[1]['IdUser']),format='json'),400)
        self.assert_response(self.client().post(BASE,self.body(ID_LocalisationFk=self.locations[1]),format='json'),400)
        with override_settings(DB_READ_ONLY=True):
            self.assert_response(self.client().post(BASE,self.body(),format='json'),503)
        # Le CRUD générique ne peut éviter ni motif, ni révision, ni auteur.
        self.assert_response(self.client().post('/api/models/T_Immobilisation',self.body(),format='json'),403)

    def test_04_replay_versions_archive_and_history(self):
        body = self.body(PrixUnitaire='25.00')
        first = self.assert_response(self.client().post(BASE,body,format='json'),201)
        replay = self.client().post(BASE,body,format='json')
        self.assert_response(replay)
        self.assertTrue(replay.data['meta']['replayed'])
        self.assertEqual(replay.data['data']['ID_Immobilisation'],first['ID_Immobilisation'])
        self.assert_response(self.client().post(BASE,{**body,'NomImmobilisation':'Autre contenu'},format='json'),409)
        self.assert_response(self.client(1).post(BASE,body,format='json'),409)
        updated = self.assert_response(self.update(first,Reference='REF-EDIT'))
        self.assert_response(self.update(first,Reference='Périmé'),409)
        path = BASE+'/'+str(updated['ID_Immobilisation'])
        self.assert_response(self.client().delete(path,{'_version':updated['_version'],'requestId':str(uuid.uuid4()),'motif':''},format='json'),400)
        archived = self.assert_response(self.client().delete(path,{'_version':updated['_version'],'requestId':str(uuid.uuid4()),'motif':'Bien archivé'},format='json'))
        self.assertFalse(archived['Actif'])
        restored = self.assert_response(self.client().patch(path,{'_version':archived['_version'],'requestId':str(uuid.uuid4()),'motif':'Remise en service','Actif':True},format='json'))
        self.assertTrue(restored['Actif'])
        history = self.client().get(path+'/historique',{'take':2})
        rows = self.assert_response(history)
        self.assertEqual(history.data['meta']['filteredCount'],4)
        self.assertEqual([row['Operation'] for row in rows],['RESTORE','ARCHIVE'])
        self.assertEqual(rows[0]['OldData']['Reference'],'REF-EDIT')
        self.assertTrue(rows[0]['Auteur'])
        ordered=self.client().get(path+'/historique',{'take':2,'sortBy':'motif','sortDir':'asc'})
        self.assert_response(ordered)
        self.assertEqual(ordered.data['meta']['sortBy'],'motif')
        self.assert_response(self.client().get(path+'/historique',{'sortBy':'MotdepasseUser'}),400)
        self.assertEqual(self.sql.execute('SELECT count(*) n FROM systeme."T_Audit_Log" WHERE "TableName"=%s AND "NewData"->>\'requestId\'=%s',['logistique.T_Immobilisation',body['requestId']]).fetchone()['n'],1)

    def test_05_retained_inactive_references_and_rh_independence(self):
        row = self.create(2,ID_ResponsableFk=self.users[2]['IdUser'],ID_ServiceFk=self.refs['services'][0]['id'])
        self.sql.execute('UPDATE systeme."T_Utilisateurs" SET "ValideUser"=false WHERE "IdUser"=%s',[self.users[2]['IdUser']])
        try:
            refs = self.assert_response(self.client(2).get(BASE+'/references',{'immobilisationId':row['ID_Immobilisation']}))
            retained = next(item for item in refs['responsables'] if item['id']==self.users[2]['IdUser'])
            self.assertTrue(retained['disabled'])
            self.assert_response(self.update(row,2,Observations='Responsable historique conservé'))
            self.assert_response(self.client(2).post(BASE,self.body(ID_ResponsableFk=self.users[2]['IdUser']),format='json'),400)
        finally:
            self.sql.execute('UPDATE systeme."T_Utilisateurs" SET "ValideUser"=true WHERE "IdUser"=%s',[self.users[2]['IdUser']])
        self.sql.execute('UPDATE systeme."T_Utilisateurs" SET "ID_ServiceFk"=NULL,"DateEmbauche"=CURRENT_DATE+1 WHERE "IdUser"=%s',[self.users[2]['IdUser']])
        try:
            self.assert_response(self.client(2).post(BASE,self.body(ID_ResponsableFk=self.users[2]['IdUser']),format='json'),400)
            current = self.assert_response(self.client(2).get(BASE+'/'+str(row['ID_Immobilisation'])))
            self.assertEqual(current['ID_ServiceFk'],row['ID_ServiceFk'])
        finally:
            self.sql.execute('UPDATE systeme."T_Utilisateurs" SET "DateEmbauche"=NULL WHERE "IdUser"=%s',[self.users[2]['IdUser']])

    def test_06_search_filter_summary_and_paginated_export(self):
        tag = 'FILTRAGE-'+uuid.uuid4().hex
        first = self.create(NomImmobilisation=tag+' A',SuiviIndividuel=False,Quantite='3',PrixUnitaire='12.34')
        second = self.create(NomImmobilisation=tag+' B',PrixUnitaire='4.10',ID_DeviseFk=self.second_currency)
        third = self.create(NomImmobilisation=tag+' C',PrixUnitaire=None)
        page = self.client().get(BASE,{'q':tag,'take':1,'sortBy':'NomImmobilisation','sortDir':'asc'})
        self.assert_response(page)
        self.assertEqual(page.data['meta']['filteredCount'],3)
        self.assertEqual(len(page.data['data']),1)
        groups = {row['id']:row for row in page.data['meta']['amountsByCurrency']}
        self.assertEqual(groups[self.usd]['value'],Decimal('37.02'))
        self.assertEqual(groups[self.usd]['unknownCount'],1)
        self.assertEqual(groups[self.second_currency]['value'],Decimal('4.10'))
        subset = self.client().get(BASE,{'q':tag,'suiviIndividuel':'false','responsableId':'sans-affectation'})
        self.assert_response(subset)
        self.assertEqual(subset.data['meta']['filteredCount'],1)
        self.assertEqual(subset.data['data'][0]['ID_Immobilisation'],first['ID_Immobilisation'])
        self.assert_response(self.client().get(BASE,{'q':tag,'columnFilters':json.dumps({'PrixUnitaire':'>=10'})}))
        columns = ['NomImmobilisation','Quantite','PrixUnitaire','ValeurAcquisition']
        export = self.client().get(BASE+'/export.csv',{'q':tag,'take':1,'columns':json.dumps(columns),'sortBy':'NomImmobilisation','sortDir':'asc'},HTTP_ACCEPT='text/csv')
        self.assertEqual(export.status_code,200,getattr(export,'data',None))
        rows = list(csv.reader(io.StringIO(b''.join(export.streaming_content).decode('utf-8-sig')),delimiter=';'))
        export.close()
        self.assertEqual(len(rows),4)
        self.assertEqual(rows[1][1:],['3','12,34','37,02'])
        self.assertEqual(rows[3][-2:],['',''])
        selected = self.client().get(BASE+'/export.csv',{'q':tag,'columns':'["CodeImmobilisation"]','selection':json.dumps([second['ID_Immobilisation']])},HTTP_ACCEPT='text/csv')
        self.assertEqual(selected.status_code,200,getattr(selected,'data',None))
        chosen = list(csv.reader(io.StringIO(b''.join(selected.streaming_content).decode('utf-8-sig')),delimiter=';'))
        selected.close()
        self.assertEqual(chosen[1],[second['CodeImmobilisation']])
        self.assert_response(self.client().get(BASE+'/export.csv',{'columns':'["_version"]'},HTTP_ACCEPT='application/json'),400)
        self.assert_response(self.client(export=False).get(BASE+'/export.csv',{'columns':'["CodeImmobilisation"]'},HTTP_ACCEPT='application/json'),403)
        # Aucune lecture de l'entreprise voisine ne traverse le choix des PK.
        foreign = self.create(1)
        out = self.client().get(BASE+'/export.csv',{'selection':json.dumps([foreign['ID_Immobilisation']]),'columns':'["CodeImmobilisation"]'},HTTP_ACCEPT='text/csv')
        self.assertEqual(out.status_code,200,getattr(out,'data',None))
        self.assertEqual(out['X-Export-Row-Count'],'0')
        out.close()

    def test_07_excel_native_types_preferences_and_no_stock(self):
        row = self.create(Reference='00000123',Quantite='2',SuiviIndividuel=False,PrixUnitaire='10.00')
        pref = self.assert_response(self.client().get('/api/tableaux/logistique.immobilisations/preferences'))
        self.assertIn('CodeImmobilisation',[col['id'] for col in pref['columns']])
        self.assert_response(self.client().put('/api/tableaux/logistique.immobilisations/preferences',{'usage':'export','version':pref['export']['version'],'columns':['Reference','Quantite','ValeurAcquisition']},format='json'))
        response = self.client().get(BASE+'/export.xlsx',{'selection':json.dumps([row['ID_Immobilisation']])},HTTP_ACCEPT='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
        self.assertEqual(response.status_code,200,getattr(response,'data',None))
        binary = b''.join(response.streaming_content); response.close()
        import zipfile
        from xml.etree import ElementTree as ET
        with zipfile.ZipFile(io.BytesIO(binary)) as archive:
            content = ET.fromstring(archive.read('xl/worksheets/sheet1.xml'))
            ns = {'s':'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
            cells = {cell.attrib['r']:cell for cell in content.findall('.//s:sheetData/s:row/s:c',ns)}
            self.assertIn(cells['A2'].attrib.get('t'),{'s','inlineStr'})
            if cells['A2'].attrib.get('t')=='inlineStr':
                self.assertEqual(cells['A2'].find('s:is/s:t',ns).text,'00000123')
            self.assertEqual(cells['B2'].find('s:v',ns).text,'2')
            self.assertEqual(cells['C2'].find('s:v',ns).text,'20')
        for entity in self.entities:
            for table in ['T_Article','T_Commande','T_Mouvement']:
                if table=='T_Mouvement':
                    count=self.sql.execute('SELECT count(*) n FROM logistique."T_Mouvement" m JOIN logistique."T_Article" a ON a."ID_Article"=m."ID_ArticleFk" WHERE a."IdEntiteFk"=%s',[entity]).fetchone()['n']
                else: count=self.sql.execute('SELECT count(*) n FROM logistique."'+table+'" WHERE "IdEntiteFk"=%s',[entity]).fetchone()['n']
                self.assertEqual(count,0)

    def test_08_concurrent_replay_single_business_audit(self):
        body=self.body(); results=[]; barrier=threading.Barrier(2)
        def submit():
            try:
                barrier.wait(timeout=15)
                response=self.client().post(BASE,body,format='json')
                results.append((response.status_code,getattr(response,'data',None)))
            finally: connections.close_all()
        workers=[threading.Thread(target=submit) for _ in range(2)]
        for worker in workers:worker.start()
        for worker in workers:worker.join(timeout=30)
        self.assertEqual(sorted(status for status,_ in results),[200,201],results)
        self.assertEqual(len({data['data']['ID_Immobilisation'] for _,data in results}),1)
        self.assertEqual(self.sql.execute('SELECT count(*) n FROM systeme."T_Audit_Log" WHERE "TableName"=%s AND "NewData"->>\'requestId\'=%s',['logistique.T_Immobilisation',body['requestId']]).fetchone()['n'],1)

    def test_09_legacy_settings_keep_database_only_correspondences(self):
        from apps.core.ui_settings import rows_for
        with transaction.atomic():
            before=[row for row in rows_for('global',None) if row['SourceKey'].startswith('logistique.immobilisations.')]
            self.assertEqual(len(before),3)
            response=self.client().put('/api/systeme/admin-ui-settings',{'scope':'global','genericCategoryOverrides':{},'hierarchyFilterModes':{}},format='json')
            self.assert_response(response)
            after=[row for row in rows_for('global',None) if row['SourceKey'].startswith('logistique.immobilisations.')]
            self.assertEqual([(row['IdFkCorrespondance'],row['MappingValue']) for row in before],[(row['IdFkCorrespondance'],row['MappingValue']) for row in after])
            self.assert_response(self.client().get(BASE+'/references'))
            transaction.set_rollback(True)

    def test_10_archived_currency_retained_without_allowing_new_use(self):
        row=self.create(ID_DeviseFk=self.second_currency,PrixUnitaire='5.00')
        with transaction.atomic():
            db.query('UPDATE referentiel."T_Generique" SET "ValideGenerique"=false WHERE "ID_Generique"=%s',[self.second_currency])
            refs=self.assert_response(self.client().get(BASE+'/references',{'immobilisationId':row['ID_Immobilisation']}))
            currency=next(item for item in refs['currencies'] if item['id']==self.second_currency)
            self.assertTrue(currency['disabled'])
            self.assert_response(self.update(row,Observations='Devise historique conservée'))
            self.assert_response(self.client().post(BASE,self.body(ID_DeviseFk=self.second_currency,PrixUnitaire='1'),format='json'),400)
            transaction.set_rollback(True)

    def test_11_professional_profile_update_and_private_projection(self):
        refs=self.assert_response(self.client().get('/api/systeme/personnel/references'))
        body={'MatriculeUser':'000-'+uuid.uuid4().hex[:10], 'ID_ServiceFk':refs['personnelServices'][0]['id'],
            'ID_FonctionFk':refs['personnelFonctions'][0]['id'], 'DateEmbauche':'2020-01-02',
            'DateFinEmploi':None,'ObservationProfessionnelle':'Note professionnelle fictive\nDeuxième ligne'}
        target=self.users[2]['IdUser']
        original=self.sql.execute('SELECT * FROM systeme."T_Utilisateurs" WHERE "IdUser"=%s',[target]).fetchone()
        current=self.assert_response(self.client(2).put('/api/systeme/utilisateurs/'+str(target),body,format='json'))
        for key,value in body.items():
            self.assertEqual(str(current[key]) if current[key] is not None else None,str(value) if value is not None else None)
        saved=self.sql.execute('SELECT * FROM systeme."T_Utilisateurs" WHERE "IdUser"=%s',[target]).fetchone()
        for key in ('MotdepasseUser','IdRoleFk','Is_staff','Is_Admin','EmailUser','IdEntiteFk'):
            self.assertEqual(saved[key],original[key])
        profile=self.assert_response(self.client(2).get('/api/systeme/administration/registres/profils/'+str(target)))
        for field in body:self.assertIn(field,profile)
        self.assertTrue(profile['Service']);self.assertTrue(profile['Fonction']);self.assertTrue(profile['EstAffectable'])
        generic=self.assert_response(self.client(2).get('/api/systeme/administration/registres/utilisateurs/'+str(target)))
        for field in body:self.assertIn(field,generic)
        self.assertEqual(profile,generic)
        me=self.assert_response(self.client().get('/SauverNdeko/auth/me'))
        for field in body:self.assertNotIn(field,me)
        # Les responsables sont une sélection d'affectation, pas une fuite du dossier RH.
        responsible=self.assert_response(self.client(2).get(BASE+'/references'))['responsables']
        for row in responsible:
            for field in ['DateEmbauche','DateFinEmploi','ObservationProfessionnelle']:
                self.assertNotIn(field,row)

    def test_12_professional_references_and_tenant_rejections(self):
        target=self.users[2]['IdUser']
        self.assert_response(self.client(global_admin=False).put('/api/systeme/utilisateurs/'+str(target),{'MatriculeUser':'Autre entreprise'},format='json'),404)
        self.assert_response(self.client(manage=False).put('/api/systeme/utilisateurs/'+str(target),{'MatriculeUser':'Interdit'},format='json'),403)
        refs=self.assert_response(self.client().get('/api/systeme/personnel/references'))
        wrong_family=self.refs['types'][0]['id']
        response=self.client(2).put('/api/systeme/utilisateurs/'+str(target),{'ID_ServiceFk':wrong_family},format='json')
        self.assertIn(response.status_code,{400,409},response.data)
        response=self.client(2).put('/api/systeme/utilisateurs/'+str(target),{'DateFinEmploi':'2019-01-01'},format='json')
        self.assertEqual(response.status_code,409,response.data)
        response=self.client(2).put('/api/systeme/utilisateurs/'+str(target),{'DateFinEmploi':'2020-01-01','DateEmbauche':'2020-01-02'},format='json')
        self.assertEqual(response.status_code,400,response.data)
        self.assert_response(self.client(2).put('/api/systeme/utilisateurs/'+str(target),{'MatriculeUser':'a'*51},format='json'),400)
        duplicate=self.sql.execute('SELECT "MatriculeUser" FROM systeme."T_Utilisateurs" WHERE "IdUser"=%s',[target]).fetchone()['MatriculeUser']
        payload={'NomUser':'Fictif','PrenomUser':'RH','EmailUser':uuid.uuid4().hex+'@example.invalid','MotdepasseUser':'SecretFictif-UsageTest-123',
            'SexeUser':'M','IdEntiteFk':self.entities[2],'MatriculeUser':duplicate.upper()}
        self.assert_response(self.client(2).post('/api/systeme/utilisateurs',payload,format='json'),409)
        payload['MatriculeUser']='NEW-'+uuid.uuid4().hex[:10]
        payload['ID_ServiceFk']=refs['personnelServices'][0]['id']
        created=self.assert_response(self.client(2).post('/api/systeme/utilisateurs',payload,format='json'),201)
        self.assertEqual(created['MatriculeUser'],payload['MatriculeUser'])
        self.assertEqual(created['ID_ServiceFk'],payload['ID_ServiceFk'])

    def test_13_professional_catalogue_and_filtered_export(self):
        target=self.users[2]['IdUser']
        for kind in ['utilisateurs','profils']:
            snapshot=self.assert_response(self.client(2).get('/api/tableaux/admin.'+kind+'/preferences'))
            catalogue={row['id'] for row in snapshot['columns']}
            self.assertTrue({'MatriculeUser','Service','Fonction','DateEmbauche','DateFinEmploi','ObservationProfessionnelle'}.issubset(catalogue))
            columns=['MatriculeUser','Service','Fonction','DateEmbauche']
            response=self.client(2).get('/api/systeme/administration/registres/'+kind+'/export.csv',{'selection':json.dumps([target]),'columns':json.dumps(columns)},HTTP_ACCEPT='text/csv')
            self.assertEqual(response.status_code,200,getattr(response,'data',None))
            rows=list(csv.reader(io.StringIO(b''.join(response.streaming_content).decode('utf-8-sig')),delimiter=';'));response.close()
            self.assertEqual(len(rows),2)
            self.assertTrue(rows[1][0].startswith('000-'))
            self.assertEqual(rows[1][3],'02/01/2020')

    def test_14_company_without_location_has_no_null_option(self):
        empty=self.sql.execute('INSERT INTO systeme."T_Entite"("NomEntite","EmailEntite","ValideEntite") VALUES(%s,%s,true) RETURNING "IdEntite" id',
            ['Entreprise sans localisation fictive '+uuid.uuid4().hex,uuid.uuid4().hex+'@example.invalid']).fetchone()['id']
        actor=self.actor();actor._context_entity=empty
        client=APIClient();client.force_authenticate(actor)
        refs=self.assert_response(client.get(BASE+'/references'))
        self.assertEqual(refs['localisations'],[])

    def test_15_assignment_history_labels_unassignment_and_foreign_transfer(self):
        person=self.sql.execute('''INSERT INTO systeme."T_Utilisateurs"("NomUser","PrenomUser","EmailUser","MotdepasseUser","SexeUser","IdEntiteFk","ValideUser")
            VALUES(%s,'Ancien',%s,'inutilisable','M',%s,true) RETURNING *''',
            ['Affectataire-'+uuid.uuid4().hex[:10],uuid.uuid4().hex+'@example.invalid',self.entities[0]]).fetchone()
        place=self.sql.execute('INSERT INTO systeme."T_Entite_Localisation"("IdEntiteFk","AdresseDetaillee") VALUES(%s,%s) RETURNING "IdEntiteLocalisation" id',
            [self.entities[0],'Localisation historique fictive']).fetchone()['id']
        row=self.create(ID_ResponsableFk=self.users[0]['IdUser'],ID_ServiceFk=self.refs['services'][0]['id'],
            ID_EtatFk=self.refs['etats'][0]['id'],ID_LocalisationFk=self.locations[0],LocalisationComplement='Bureau A')
        path=BASE+'/'+str(row['ID_Immobilisation'])+'/historique'
        created=self.assert_response(self.client().get(path))[0]
        self.assertIsNone(created['AffectationAvant'])
        self.assertEqual(created['AffectationApres']['responsable'],row['Responsable'])
        self.assertEqual(created['AffectationApres']['service'],row['Service'])
        self.assertEqual(created['AffectationApres']['etat'],row['EtatMateriel'])
        self.assertIn('Bureau A',created['AffectationApres']['localisation'])
        service_id=self.refs['services'][1]['id'] if len(self.refs['services'])>1 else None
        state_id=self.refs['etats'][1]['id'] if len(self.refs['etats'])>1 else None
        updated=self.assert_response(self.update(row,ID_ResponsableFk=person['IdUser'],ID_LocalisationFk=place,
            LocalisationComplement='Bureau B',ID_ServiceFk=service_id,ID_EtatFk=state_id))
        event=self.assert_response(self.client().get(path))[0]
        self.assertEqual(event['AffectationAvant'],created['AffectationApres'])
        self.assertEqual(event['AffectationApres']['responsable'],updated['Responsable'])
        self.assertEqual(event['AffectationApres']['service'],updated['Service'])
        self.assertEqual(event['AffectationApres']['etat'],updated['EtatMateriel'])
        self.assertIn('Localisation historique fictive',event['AffectationApres']['localisation'])
        self.assertIn('Bureau B',event['AffectationApres']['localisation'])
        unassigned=self.assert_response(self.update(updated,ID_ResponsableFk=None,ID_ServiceFk=None,ID_EtatFk=None,ID_LocalisationFk=None,LocalisationComplement=None))
        released=self.assert_response(self.client().get(path))[0]
        self.assertEqual(released['AffectationAvant'],event['AffectationApres'])
        self.assertEqual(released['AffectationApres'],dict.fromkeys(['responsable','service','etat','localisation']))
        archived=self.assert_response(self.client().delete(BASE+'/'+str(row['ID_Immobilisation']),{'_version':unassigned['_version'],
            'requestId':str(uuid.uuid4()),'motif':'Archivage sans changement d’affectation'},format='json'))
        archive_event=self.assert_response(self.client().get(path))[0]
        self.assertEqual(archive_event['Operation'],'ARCHIVE')
        self.assertEqual(archive_event['AffectationAvant'],archive_event['AffectationApres'])
        # Une ancienne référence détachée puis transférée ne révèle pas les
        # informations courantes d'une autre entreprise dans cette histoire.
        self.sql.execute('UPDATE systeme."T_Utilisateurs" SET "IdEntiteFk"=%s WHERE "IdUser"=%s',[self.entities[1],person['IdUser']])
        self.sql.execute('UPDATE systeme."T_Entite_Localisation" SET "IdEntiteFk"=%s WHERE "IdEntiteLocalisation"=%s',[self.entities[1],place])
        guarded=self.assert_response(self.client().get(path))
        prior=next(item for item in guarded if item['IdLog']==event['IdLog'])
        self.assertEqual(prior['AffectationApres']['responsable'],'Libellé indisponible')
        self.assertEqual(prior['AffectationApres']['localisation'],'Libellé indisponible · Bureau B')
        self.assertIn('OldData',prior);self.assertIn('NewData',prior)
        self.assert_response(self.client(1,global_admin=False).get(path),404)


    def test_cycle_inventory_attachments_disposal_and_tenant(self):
        from django.core.files.uploadedfile import SimpleUploadedFile
        row = self.create(DateAcquisition='2026-09-01', DateMiseEnService='2026-09-02')
        self.assertEqual(row['StatutCycle'], 'EN_SERVICE')
        pk = row['ID_Immobilisation']
        url = f'{BASE}/{pk}/cycle-vie'
        pieces = f'/api/logistique/documents/immobilisation/{pk}/pieces'
        client = self.client()
        outsider = self.client(1, global_admin=False)
        self.assert_response(outsider.get(url), 404)
        self.assert_response(outsider.get(pieces), 404)
        self.assert_response(self.update(row, ID_LocalisationFk=self.locations[0]))
        row = self.assert_response(client.get(f'{BASE}/{pk}'))
        content = b'%PDF-1.7\nFixture privee\n%%EOF'
        doc = self.assert_response(client.post(pieces, {'file': SimpleUploadedFile('inventaire.pdf', content)}, format='multipart'), 201)
        file_url = f"{pieces}/{doc['ID_Piece']}"
        readonly = self.client(global_admin=False, manage=False, export=False)
        self.assertEqual(self.assert_response(readonly.get(pieces))[0]['ID_Piece'], doc['ID_Piece'])
        denied = readonly.get(file_url, HTTP_ACCEPT='application/pdf')
        self.assert_response(denied, 403)
        self.assertEqual(denied.data['error']['code'], 'MODULE_ACTION_FORBIDDEN')
        exporter = self.client(global_admin=False, manage=False, export=True)
        self.assertEqual(exporter.get(file_url, HTTP_ACCEPT='application/pdf').content, content)
        self.assertEqual(client.get(file_url).content, content)
        self.assert_response(outsider.get(file_url), 404)
        event = {'type':'INVENTAIRE','date':'2026-09-03','quantiteComptee':'0','motif':'Comptage fictif',
            'pieceId':doc['ID_Piece'],'requestId':str(uuid.uuid4()),'_version':row['_version']}
        self.assert_response(self.client(manage=False).post(url,event,format='json'),403)
        data = self.assert_response(client.post(url,event,format='json'))
        self.assertEqual(data['events'][0]['QuantiteTheorique'], 1)
        self.assertEqual(data['events'][0]['EcartInventaire'], -1)
        self.assertEqual(data['documents'][0]['ID_Piece'], doc['ID_Piece'])
        self.assertEqual(len(self.assert_response(client.post(url,event,format='json'))['events']),1)
        self.assert_response(client.post(url,{**event,'quantiteComptee':'1'},format='json'),409)
        self.assert_response(client.delete(file_url),409)
        disposal = {'type':'REBUT','date':'2026-09-04','motif':'Mise au rebut fictive','pieceId':doc['ID_Piece'],
            'requestId':str(uuid.uuid4()),'_version':row['_version']}
        self.assert_response(client.post(url,disposal,format='json'))
        self.assert_response(client.post(url,{**disposal,'requestId':str(uuid.uuid4())},format='json'),409)
        details = client.get(f'{BASE}/{pk}')
        self.assertEqual(self.assert_response(details)['StatutCycle'],'SORTI')
        self.assertFalse(details.data['meta']['canEdit'])
        self.assert_response(self.update(row, Observations='Tentative après sortie'),409)
        matches = self.assert_response(client.get(BASE, {'statutCycle':'SORTI','q':row['NomImmobilisation']}))
        self.assertEqual([item['ID_Immobilisation'] for item in matches],[pk])

    def test_valuation_schedule_replay_exit_and_close(self):
        row = self.create(DateAcquisition='2026-09-01', DateMiseEnService='2026-10-01', PrixUnitaire='100.00')
        pk = row['ID_Immobilisation']
        url = f'{BASE}/{pk}/valorisation'
        client = self.client()
        outsider = self.client(1, global_admin=False)

        def action(payload, status=200):
            return self.assert_response(client.post(url,payload,format='json'),status)

        plan = {'action':'CREER','usage':'COMPTABLE','referentiel':'SYSCOHADA','methode':'LINEAIRE_JOURS',
            'cout':'100.00','residuel':'7.00','debut':'2026-10-01','duree':'1','deviseId':self.usd,
            'motif':'Paramètres validés dans la recette fictive','requestId':str(uuid.uuid4()),'_version':row['_version']}
        self.assert_response(outsider.post(url,plan,format='json'),404)
        self.assert_response(self.client(manage=False).post(url,plan,format='json'),403)
        action({**plan,'motif':''},400)
        action({**plan,'_version':'0'},409)
        data = action(plan)
        accounting = data['plans'][0]
        self.assertEqual(accounting['schedule'][0]['Montant'], Decimal('93.00'))
        self.assertEqual(accounting['ValeurNetteComptable'], Decimal('100.00'))
        self.assertEqual(len(action(plan)['plans']),1)
        action({**plan,'cout':'200.00'},409)
        fiscal = {**plan,'usage':'FISCAL','referentiel':'FISCAL','methode':'NON_AMORTISSABLE','duree':None,
            'requestId':str(uuid.uuid4())}
        self.assertEqual(action(fiscal)['plans'][1]['schedule'],[])
        dotation = {'action':'EVENEMENT','planId':accounting['ID_Plan'],'type':'DOTATION','date':'2026-10-10',
            'motif':'Dotation fictive','requestId':str(uuid.uuid4()),'_version':accounting['_version']}
        accounting = action(dotation)['plans'][0]
        self.assertEqual(accounting['AmortissementsCumules'], Decimal('30.00'))
        self.assertEqual(accounting['ValeurNetteComptable'], Decimal('70.00'))
        self.assertEqual(len(action(dotation)['plans'][0]['events']),1)
        action({**dotation,'date':'2026-10-11','requestId':str(uuid.uuid4())},409)
        close = {'action':'CLOTURER','usage':'COMPTABLE','date':'2026-10-10','motif':'Clôture fictive',
            'requestId':str(uuid.uuid4())}
        accounting = action(close)['plans'][0]
        self.assertEqual(len(action(close)['periods']),1)
        action({**dotation,'_version':accounting['_version'],'requestId':str(uuid.uuid4())},409)
        physical = {'type':'CESSION','date':'2026-10-11','motif':'Cession fictive','requestId':str(uuid.uuid4()),
            '_version':row['_version']}
        self.assert_response(client.post(f'{BASE}/{pk}/cycle-vie',physical,format='json'))
        accounting = self.assert_response(client.get(url))['plans'][0]
        disposal = {**dotation,'type':'CESSION','montant':'75.00','date':'2026-10-11','_version':accounting['_version'],
            'requestId':str(uuid.uuid4())}
        disposed = action(disposal)['plans'][0]
        self.assertEqual(disposed['ValeurNetteComptable'],Decimal('0'))
        self.assertEqual(disposed['events'][0]['ValeurAvantSortie'],Decimal('70.00'))
        self.assertEqual(len(action(disposal)['plans'][0]['events']),2)
        self.assert_response(outsider.get(url),404)


if __name__=='__main__':
    result=unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(ImmobilisationsAPI))
    paths=['backend/apps/logistique/immobilisations.py','backend/apps/logistique/reads.py','backend/apps/logistique/excel.py',
        'backend/apps/logistique/currency.py','backend/apps/logistique/table_queries.py','backend/apps/core/ui_settings.py',
        'backend/apps/core/repository.py','backend/apps/core/models.py','backend/apps/core/registry.json','backend/config/urls.py',
        'backend/apps/core/personnel.py','backend/apps/core/admin_portal.py','backend/apps/core/views.py',
        'SQL/migrations/20261028_08_immobilisations_affectations.sql','SQL/tests/test_immobilisations_api.py']
    output=ROOT/'.runtime/immobilisations-api/verification.json'
    output.parent.mkdir(parents=True,exist_ok=True)
    output.write_text(json.dumps({'passed':result.wasSuccessful(),'tests':result.testsRun,'failures':len(result.failures),'errors':len(result.errors),
        'database':location.path[1:],'scope':'Trois entreprises fictives ; aucun appel à SauverNdeko ; aucune connexion à une base réelle.',
        'sha256':{path:hashlib.sha256((ROOT/path).read_bytes()).hexdigest() for path in paths}},ensure_ascii=False,indent=2),encoding='utf8')
    raise SystemExit(0 if result.wasSuccessful() else 1)
