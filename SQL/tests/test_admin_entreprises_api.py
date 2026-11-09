"""Recette API réelle privée de l'administration ; aucune donnée dans SauverNdeko."""
import json,os,sys,unittest,uuid,time,threading
from concurrent.futures import ThreadPoolExecutor
from unittest.mock import patch
from pathlib import Path
from urllib.parse import urlsplit
import psycopg
from psycopg.rows import dict_row
DSN=os.environ.get('SAUVERNDEKO_TEST_DATABASE_URL','');target=urlsplit(DSN)
if target.hostname not in {'127.0.0.1','localhost'} or not target.path[1:].startswith('sauverndeko_test_'):raise RuntimeError('Recette réservée au PostgreSQL privé sauverndeko_test_*.')
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'backend'))
os.environ.update(DATABASE_URL=DSN,DJANGO_SETTINGS_MODULE='config.settings',SAUVERNDEKO_DB_READ_ONLY='0')
import django;django.setup()
from django.db import transaction,connections
from django.test import override_settings
from rest_framework.test import APIClient
from apps.accounts.authentication import Actor
from apps.core import db
from apps.core.field_references import reference_options
from apps.core.module_access import access_snapshot
from apps.core.registry import model
from apps.core.repository import mutate
from apps.logistique import entity_documents as entities
BASE='/api/systeme/administration/'
PRESENTATION='/api/logistique/presentation'
PRESENTATION_SETTINGS='/api/parametres/logistique/presentation'
PRESENTATION_MODULES='/api/parametres/presentation'
CAISSE_PRESENTATION='/api/caisse/presentation'
CAISSE_PRESENTATION_SETTINGS='/api/parametres/caisse/presentation'

class AdminEnterpriseAPI(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.override=override_settings(ALLOWED_HOSTS=['testserver']);cls.override.enable();cls.sql=psycopg.connect(DSN,autocommit=True,row_factory=dict_row)
  cls.entities=[cls.sql.execute('INSERT INTO systeme."T_Entite"("NomEntite","EmailEntite","ValideEntite") VALUES(%s,%s,true) RETURNING "IdEntite" id',['Admin fictif '+uuid.uuid4().hex,uuid.uuid4().hex+'@example.invalid']).fetchone()['id'] for _ in range(2)]
  cls.users=[cls.sql.execute('INSERT INTO systeme."T_Utilisateurs"("NomUser","PrenomUser","EmailUser","MotdepasseUser","ValideUser","SexeUser","Is_Admin","Is_staff","IdEntiteFk") VALUES(\'Admin\',\'Fictif\',%s,\'inutilisable\',true,\'M\',true,true,%s) RETURNING *',[uuid.uuid4().hex+'@example.invalid',entity]).fetchone() for entity in cls.entities]
 @classmethod
 def tearDownClass(cls):cls.sql.close();cls.override.disable()
 def setUp(self):
  self.tx=None if self._testMethodName in {"test_16_concurrent_replay","test_24_common_scope_and_export_parity","test_28_legacy_location_waits_for_parent","test_29_profile_in_real_readonly_transaction","test_33_presentation_in_real_readonly_transaction"} else transaction.atomic()
  if self.tx:self.tx.__enter__()
 def tearDown(self):
  if self.tx:transaction.set_rollback(True);self.tx.__exit__(None,None,None)
 def actor(self,index=0,*,global_admin=True,manage=True,scope=True,staff=True):
  actor=Actor({**self.users[index],'Is_Admin':global_admin,'Is_staff':staff})
  if global_admin and scope:actor._context_entity=self.entities[index]
  snapshot={'modules':{},'tabs':{'logistique':{}}} if global_admin else access_snapshot(actor)
  actor._module_access=snapshot
  for key in ('administration','logistique'):
   snapshot['modules'][key]={'canRead':True,'canManage':manage,'canExport':True,'reason':'MODULE_ROLE_FORBIDDEN'}
  snapshot['tabs']['logistique']['immobilisations']=snapshot['modules']['logistique']
  return actor
 def client(self,**rights):c=APIClient();c.force_authenticate(self.actor(**rights));return c
 def role(self):
  from apps.core.admin_operations import privileged_user
  return next(row['id'] for row in reference_options(self.actor(),'systeme','T_Utilisateurs','IdRoleFk') if not privileged_user({'IdRoleFk':row['id']}))
 def row(self,kind,**changes):
  token=uuid.uuid4().hex
  if kind=='utilisateurs':data={'NomUser':'Compte '+token,'PrenomUser':'Fictif','EmailUser':token+'@example.invalid','MotdepasseUser':'MotDePasse-fictif-123456789','SexeUser':'M','ValideUser':True,'Is_Admin':False,'Is_staff':False,'IdEntiteFk':self.entities[0],'IdRoleFk':self.role()}
  elif kind=='roles':data={'NomGenerique':'Rôle fictif '+token,'AbrGenerique':token,'ValideGenerique':True}
  elif kind=='parametres':data={'SettingKey':'recette.'+token,'SettingLabel':'Paramètre fictif','SettingScope':'entite','ScopeValue':str(self.entities[0]),'SettingValue':'Vrai','SettingType':'text','IsEditable':True,'ValideSetting':True}
  else:
   from apps.core.field_references import reference_context
   category=reference_context(self.actor(),'systeme','T_Utilisateurs','IdRoleFk')['categoryIds'][0]
   data={'ModuleName':'administration','SchemaName':'systeme','ViewName':'V_User_profil','SourceKey':'recette.'+token,'FieldName':'IdRoleFk','FieldLabel':'Rôle','MappingType':'generic_category','ReferenceSchemaName':'referentiel','ReferenceObjectName':'T_Generique','ReferenceFieldName':'ID_Generique','TargetCategoryIdFk':category,'MappingValue':str(category),'SettingScope':'entity','ScopeValue':str(self.entities[0]),'ValideFkCorrespondance':True}
  return {'clientRowId':token,'data':{**data,**changes}}
 def body(self,kind,n=2,**changes):return {'requestId':str(uuid.uuid4()),'rows':[self.row(kind,**changes) for _ in range(n)]}
 def post(self,kind,body=None,**rights):return self.client(**rights).post(BASE+'saisie-multiple/'+kind,body or self.body(kind),format='json')
 def assert_status(self,result,status=200):self.assertEqual(result.status_code,status,getattr(result,'data',None));return result.json()['data']
 def test_01_each_kind_and_replay(self):
  for kind in ('utilisateurs','roles','correspondances','parametres'):
   for n in (1,2):
    with self.subTest(kind=kind,n=n):
     body=self.body(kind,n);result=self.assert_status(self.post(kind,body),201);self.assertEqual(result['count'],n);self.assertNotIn('MotdepasseUser',json.dumps(result,default=str));self.assertEqual(json.loads(json.dumps(self.assert_status(self.post(kind,body)),default=str)),json.loads(json.dumps(result,default=str)))
     body['rows'][0]['data']['NomUser' if kind=='utilisateurs' else 'NomGenerique' if kind=='roles' else 'FieldLabel' if kind=='correspondances' else 'SettingLabel']='Autre contenu';self.assert_status(self.post(kind,body),409)
 def test_02_atomic_error_keeps_no_rows_or_audit(self):
  for kind,field in [('utilisateurs','EmailUser'),('roles','NomGenerique'),('parametres','SettingKey'),('correspondances','MappingValue')]:
   body=self.body(kind);body['rows'][1]['data'][field]='';before=db.one('SELECT count(*) n FROM systeme."T_Audit_Log"')['n'];self.assert_status(self.post(kind,body),422);self.assertEqual(before,db.one('SELECT count(*) n FROM systeme."T_Audit_Log"')['n'])
 def test_03_local_creates_ordinary_user_only(self):
  body=self.body('utilisateurs');result=self.assert_status(self.post('utilisateurs',body,global_admin=False),201)
  self.assertTrue(all(r['IdEntiteFk']==self.entities[0] and not r['Is_Admin'] and not r['Is_staff'] for r in result['records']))
  for field,value in [('Is_Admin',True),('Is_staff',True),('IdEntiteFk',self.entities[1])]:self.assert_status(self.post('utilisateurs',self.body('utilisateurs',**{field:value}),global_admin=False),403)
 def test_local_user_creation_and_role_change_cannot_exceed_own_rights(self):
  payload=self.row('utilisateurs')['data']
  created=self.assert_status(self.client(global_admin=False).post('/api/systeme/utilisateurs',payload,format='json'),201)
  actor=self.actor(global_admin=False)
  actor._module_access['modules']['produits'].update(canRead=False,canManage=False,canExport=False)
  client=APIClient();client.force_authenticate(actor)
  denied=client.post(BASE+'saisie-multiple/utilisateurs',self.body('utilisateurs',n=1,IdRoleFk=None),format='json')
  self.assert_status(denied,403)
  self.assertEqual(denied.data['error']['code'],'USER_GRANT_EXCEEDS_OWN')
  url='/api/systeme/utilisateurs/'+str(created['IdUser'])
  denied=client.patch(url,{'IdRoleFk':None},format='json')
  self.assert_status(denied,403)
  self.assertEqual(denied.data['error']['code'],'USER_GRANT_EXCEEDS_OWN')
  self.assertEqual(db.one('SELECT "IdRoleFk" FROM systeme."T_Utilisateurs" WHERE "IdUser"=%s',[created['IdUser']])['IdRoleFk'],payload['IdRoleFk'])
 def test_04_structure_reserved_to_platform(self):
  for kind in ('roles','correspondances','parametres'):self.assert_status(self.post(kind,global_admin=False),403)
 def test_05_old_user_routes_share_guards(self):
  payload=self.row('utilisateurs')['data'];client=self.client(global_admin=False)
  result=self.assert_status(client.post('/api/systeme/utilisateurs',payload,format='json'),201);identifier=result['IdUser']
  url='/api/systeme/utilisateurs/'+str(identifier)
  email=f'{uuid.uuid4()}@example.invalid'
  initial_hash=db.one('SELECT "MotdepasseUser" FROM systeme."T_Utilisateurs" WHERE "IdUser"=%s',[identifier])['MotdepasseUser']
  for change in ({'EmailUser':email},{'MotdepasseUser':'Nouveau-mot-de-passe-123456789'}):
   refused=client.patch(url,change,format='json')
   self.assert_status(refused,403)
   self.assertEqual(refused.data['error']['code'],'USER_CREDENTIALS_PROTECTED')
  updated=self.assert_status(client.put(url,{'NomUser':'Modifié','EmailUser':payload['EmailUser']},format='json'))
  self.assertEqual(updated['NomUser'],'Modifié')
  self.assertEqual(updated['EmailUser'],payload['EmailUser'])
  self.assertEqual(db.one('SELECT "MotdepasseUser" FROM systeme."T_Utilisateurs" WHERE "IdUser"=%s',[identifier])['MotdepasseUser'],initial_hash)
  self.assertEqual(self.assert_status(self.client().patch(url,{'EmailUser':email},format='json'))['EmailUser'],email)
  for field,value in [('Is_staff',True),('Is_Admin',True),('IdEntiteFk',self.entities[1])]:self.assert_status(client.patch('/api/systeme/utilisateurs/'+str(identifier),{field:value},format='json'),403)
  self.assert_status(client.delete('/api/systeme/utilisateurs/'+str(self.users[0]['IdUser'])),409)
  self.assert_status(client.delete('/api/systeme/utilisateurs/'+str(self.users[1]['IdUser'])),404)
  self.assert_status(client.delete('/api/systeme/utilisateurs/'+str(identifier)))
 def test_06_readonly_and_permission(self):
  self.assert_status(self.post('utilisateurs',manage=False),403)
  with override_settings(DB_READ_ONLY=True):self.assert_status(self.post('utilisateurs'),503)
  anonymous=APIClient();self.assert_status(anonymous.get(BASE+'entreprises'),401)
 def test_07_cross_context_is_refused(self):
  self.assert_status(self.post('utilisateurs',self.body('utilisateurs',IdEntiteFk=self.entities[1])),403)
  for kind,scope in [('parametres','entite'),('correspondances','entity')]:self.assert_status(self.post(kind,self.body(kind,SettingScope=scope,ScopeValue=str(self.entities[1]))),403)
 def test_08_local_reference_rights(self):
  for kind in ('utilisateurs','roles','correspondances','parametres'):
   refs=self.assert_status(self.client(global_admin=False).get(BASE+'references/'+kind));self.assertEqual(refs['canCreate'],kind=='utilisateurs');self.assertEqual(len(refs['entities']),1)
  self.assertEqual(len(self.assert_status(self.client(global_admin=False).get(BASE+'entreprises'))),1)
  self.assertGreaterEqual(len(self.assert_status(self.client(scope=False).get(BASE+'entreprises'))),2)
 def test_09_settings_and_mappings_scoped_reads(self):
  for kind in ('parametres','correspondances'):
   a=self.assert_status(self.post(kind,self.body(kind,n=1)),201)['records'][0]
   b=self.body(kind,n=1);b['rows'][0]['data']['ScopeValue']=str(self.entities[1]);self.assert_status(self.client(index=1).post(BASE+'saisie-multiple/'+kind,b,format='json'),201)
   result=self.assert_status(self.client(global_admin=False).get(BASE+'registres/'+kind));self.assertTrue(all(r['SettingScope']=='global' or r['ScopeValue']==str(self.entities[0]) for r in result));self.assertTrue(any(r.get('ScopeValue')==str(self.entities[0]) for r in result))
 def test_10_licences_local_read_only(self):
  self.assert_status(self.client(global_admin=False).get(BASE+'registres/licences'))
  self.assert_status(self.client(global_admin=False).post('/api/systeme/licences',{'IdEntiteFk':self.entities[0],'ValideLicence':True},format='json'),403)
 def profile_body(self,**changes):
  p=entities.profile(self.actor(),self.entities[0],administration=True);body={key:p.get(key) for key in entities.FIELDS|entities.ADMIN_FIELDS};body.update(IdEntite=self.entities[0],_version=p['_version'],requestId=str(uuid.uuid4()),motif='Recette privée entreprise',Localisations=p['Localisations']);body.update(changes);return body
 def entity_put(self,body,**rights):return self.client(**rights).put('/api/systeme/entites/'+str(self.entities[0]),body,format='json')
 def test_11_locations_in_profile_atomic(self):
  body=self.profile_body(NomEntite='Nom modifié fictif',Localisations=[{'AdresseDetaillee':'Bureau fictif','Latitude':'-4.123456','Longitude':'15.123456'}]);result=self.assert_status(self.entity_put(body));self.assertEqual(len(result['Localisations']),1);self.assertIsInstance(result['Localisations'][0]['_version'],str);self.assertEqual(self.assert_status(self.entity_put(body))['Localisations'],result['Localisations'])
  body=self.profile_body(NomEntite='Nom à ne pas garder',Localisations=[{'AdresseDetaillee':'Bureau 1'},{'Latitude':'100','Longitude':'10'}]);self.assert_status(self.entity_put(body),422);self.assertEqual(db.one('SELECT "NomEntite" FROM systeme."T_Entite" WHERE "IdEntite"=%s',[self.entities[0]])['NomEntite'],'Nom modifié fictif')
 def test_12_location_owner_and_revision(self):
  saved=self.assert_status(self.entity_put(self.profile_body(Localisations=[{'AdresseDetaillee':'Lieu fictif'}])))['Localisations'][0]
  bad={**saved,'_version':'périmée'};self.assert_status(self.entity_put(self.profile_body(Localisations=[bad])),409)
  identifier=db.one('INSERT INTO systeme."T_Entite_Localisation"("IdEntiteFk","AdresseDetaillee") VALUES(%s,%s) RETURNING "IdEntiteLocalisation" id',[self.entities[1],'Ailleurs'])['id']
  self.assert_status(self.entity_put(self.profile_body(Localisations=[{'IdEntiteLocalisation':identifier,'_version':'1','AdresseDetaillee':'Interdit'}])),422)
 def test_13_dashboard_scoped_counts_targets(self):
  result=self.assert_status(self.client(global_admin=False).get(BASE+'synthese'));self.assertEqual(result['scope']['id'],self.entities[0]);self.assertEqual(len(result['userActivity']),7);self.assertIn('activeUsers',result['metricTargets']);self.assertIsNone(result['metrics']['auditEvents'])
  for metric in ('users','activeUsers','inactiveUsers','roles','entities','activeLicences','expiredLicences','settings','fkMappings'):
   target=result['metricTargets'][metric];register=self.client(global_admin=False).get(BASE+'registres/'+target['kind'],{'filters':json.dumps(target['filters'])});self.assert_status(register);self.assertEqual(result['metrics'][metric],register.data['meta']['filteredCount'])
 def test_14_limits_and_closed_keys(self):
  for body in ({'requestId':str(uuid.uuid4()),'rows':[]},{'requestId':str(uuid.uuid4()),'rows':[self.row('roles')]*101}):self.assert_status(self.post('roles',body),422)
  body=self.body('roles');body['rows'][1]['clientRowId']=body['rows'][0]['clientRowId'];self.assert_status(self.post('roles',body),400)
  self.assert_status(self.post('utilisateurs',self.body('utilisateurs',DatecreationUser='2000-01-01')),422)
 def test_15_secrets_never_in_response_or_audit(self):
  body=self.body('utilisateurs',n=1);self.assert_status(self.post('utilisateurs',body),201);raw=json.dumps(db.query('SELECT "NewData" FROM systeme."T_Audit_Log" WHERE "Operation"=\'ADMIN_BATCH_CREATE\''),default=str);self.assertNotIn(body['rows'][0]['data']['MotdepasseUser'],raw);self.assertNotIn('pbkdf2_',raw)
  self.assert_status(self.post('parametres',self.body('parametres',SettingKey='SMTP_PASSWORD')),422)

 def test_16_concurrent_replay(self):
  body=self.body('roles',n=1)
  def send(_):
   try:
    result=self.post('roles',body);return result.status_code,result.json()
   finally:connections.close_all()
  with ThreadPoolExecutor(max_workers=2) as executor:results=list(executor.map(send,range(2)))
  self.assertEqual(sorted(status for status,_ in results),[200,201]);self.assertEqual(results[0][1]['data'],results[1][1]['data'])
  self.assertEqual(db.one('SELECT count(*) n FROM referentiel."T_Generique" WHERE "NomGenerique"=%s',[body['rows'][0]['data']['NomGenerique']])['n'],1)
 def test_17_hundred_roles_and_duplicate_batch_rollback(self):
  result=self.assert_status(self.post('roles',self.body('roles',n=100)),201);self.assertEqual(result['count'],100)
  body=self.body('roles');body['rows'][1]['data']=dict(body['rows'][0]['data']);before=db.one('SELECT count(*) n FROM referentiel."T_Generique"')['n'];self.assert_status(self.post('roles',body),422);self.assertEqual(before,db.one('SELECT count(*) n FROM referentiel."T_Generique"')['n'])
 def test_18_last_admin_guard(self):
  from apps.core.admin_operations import user_change
  from apps.core.responses import APIError
  with patch('apps.core.admin_operations.db.one',return_value={'n':1}),patch('apps.core.admin_operations.db.query'):
   with self.assertRaises(APIError) as error:user_change(self.actor(scope=False),{'Is_Admin':False},self.users[1],'update')
  self.assertEqual(error.exception.default_code,'LAST_PLATFORM_ADMIN')
 def test_19_no_admin_role_delegation(self):
  admin=db.one('SELECT "ID_Generique" id FROM referentiel."T_Generique" WHERE lower("NomGenerique") IN (\'admin\',\'administrateur\') LIMIT 1')
  self.assertIsNotNone(admin)
  self.assert_status(self.post('utilisateurs',self.body('utilisateurs',IdRoleFk=admin['id']),global_admin=False),403)
 def test_20_licence_detail_and_old_mutations(self):
  status=reference_options(self.actor(),'systeme','T_Licence','IdStatutLicenceFk')[0]['id']
  ids=[db.one('INSERT INTO systeme."T_Licence"("IdEntiteFk","DateDebut","DateFin","ValideLicence","IdStatutLicenceFk") VALUES(%s,CURRENT_TIMESTAMP,CURRENT_TIMESTAMP+INTERVAL \'1 year\',true,%s) RETURNING "IdLicence" id',[entity,status])['id'] for entity in self.entities]
  client=self.client(global_admin=False)
  self.assert_status(client.get(BASE+'registres/licences/'+str(ids[0])))
  self.assert_status(client.get(BASE+'registres/licences/'+str(ids[1])),404)
  for method in ('patch','delete'):
   result=getattr(client,method)('/api/systeme/licences/'+str(ids[0]),{'ValideLicence':False},format='json');self.assert_status(result,403)
 def test_21_location_used_by_asset_cannot_be_removed(self):
  from apps.logistique.immobilisations import save
  place=self.assert_status(self.entity_put(self.profile_body(Localisations=[{'AdresseDetaillee':'Lieu du bien fictif'}])))['Localisations'][0]
  actor=self.actor();category=reference_options(actor,'logistique','T_Immobilisation','ID_CategorieFk')[0]['id']
  save(actor,{'NomImmobilisation':'Bien fictif '+uuid.uuid4().hex,'ID_CategorieFk':category,'ID_LocalisationFk':place['IdEntiteLocalisation'],'DateEntree':'2026-10-30T12:00:00+01:00','Quantite':'1','SuiviIndividuel':True,'PrixUnitaire':'10','motif':'Recette privée','requestId':str(uuid.uuid4())})
  self.assert_status(self.entity_put(self.profile_body(Localisations=[])),409)
  self.assertEqual(len(entities.profile(actor,self.entities[0],administration=True)['Localisations']),1)
 def test_22_entity_creation_with_locations(self):
  defaults=self.assert_status(self.client().get('/api/systeme/entites/identite-defaut'));body={key:defaults.get(key) for key in entities.FIELDS|entities.ADMIN_FIELDS};body.update(NomEntite='Nouvelle entreprise fictive '+uuid.uuid4().hex,EmailEntite=uuid.uuid4().hex+'@example.invalid',requestId=str(uuid.uuid4()),motif='Recette création et localisation',Localisations=[{'AdresseDetaillee':'Siège fictif'}])
  result=self.assert_status(self.client().post('/api/systeme/entites',body,format='json'),201);self.assertEqual(len(result['Localisations']),1)
  result2=self.assert_status(self.client().post('/api/systeme/entites',body,format='json'));self.assertEqual(result2['IdEntite'],result['IdEntite'])
  self.assertNotEqual(result['IdEntite'],self.entities[0])

 def test_23_location_territorial_hierarchy(self):
  n3=[db.one('INSERT INTO geolocalisation."T_Niveau_3"("NomNiveau_3") VALUES(%s) RETURNING "ID_Niveau_3" id',['N3 fictif '+uuid.uuid4().hex])['id'] for _ in range(2)]
  n4=db.one('INSERT INTO geolocalisation."T_Niveau_4"("NomNiveau_4","ID_Niveau_3_Fk") VALUES(%s,%s) RETURNING "ID_Niveau_4" id',['N4 fictif',n3[0]])['id']
  n5=db.one('INSERT INTO geolocalisation."T_Niveau_5"("NomNiveau_5","ID_Niveau_4_Fk") VALUES(%s,%s) RETURNING "ID_Niveau_5" id',['N5 fictif',n4])['id']
  place={'IdNiveau_3_Fk':n3[0],'IdNiveau_4_Fk':n4,'IdNiveau_5_Fk':n5}
  saved=self.assert_status(self.entity_put(self.profile_body(Localisations=[place])))
  self.assertEqual(next(row['parent3'] for row in saved['references']['niveaux5'] if row['id']==n5),n3[0])
  self.assert_status(self.entity_put(self.profile_body(Localisations=[{**place,'IdNiveau_3_Fk':n3[1]}])),422)
 def test_24_common_scope_and_export_parity(self):
  for kind in ('parametres','correspondances'):
   shared=self.body(kind,n=1,SettingScope='global',ScopeValue=None);self.assert_status(self.post(kind,shared),201)
   client=self.client(global_admin=False);listing=client.get(BASE+'registres/'+kind);self.assert_status(listing)
   self.assertTrue(any(row['SettingScope']=='global' for row in listing.json()['data']))
   export=client.get(BASE+'registres/'+kind+'/export.csv',HTTP_ACCEPT='text/csv');self.assertEqual(export.status_code,200,getattr(export,'data',None));self.assertEqual(int(export['X-Export-Row-Count']),listing.json()['meta']['filteredCount']);b''.join(export.streaming_content);export.close()

 def test_25_malformed_role_and_text_are_input_errors(self):
  for value in (True,'texte',-1):self.assert_status(self.post('utilisateurs',self.body('utilisateurs',IdRoleFk=value)),422)
  body=self.body('roles',NomGenerique='\ud800');self.assert_status(self.client().post(BASE+'saisie-multiple/roles',json.dumps(body,ensure_ascii=True),content_type='application/json'),422)

 def test_26_collection_revision_refuses_legacy_insert_then_omission(self):
  baseline=self.profile_body();baseline['NomEntite']='Nom périmé à ne pas enregistrer'
  point=self.assert_status(self.client().post('/api/models/T_Entite_Localisation',{'IdEntiteFk':self.entities[0],'AdresseDetaillee':'Point ajouté via ancienne route'},format='json'),201)
  count=db.one('SELECT count(*) n FROM systeme."T_Audit_Log"')['n']
  self.assert_status(self.entity_put(baseline),409)
  self.assertEqual(db.one('SELECT count(*) n FROM systeme."T_Audit_Log"')['n'],count)
  self.assertEqual(db.one('SELECT "AdresseDetaillee" FROM systeme."T_Entite_Localisation" WHERE "IdEntiteLocalisation"=%s',[point['IdEntiteLocalisation']])['AdresseDetaillee'],'Point ajouté via ancienne route')
  fresh=self.profile_body();self.assertNotEqual(fresh['_version'],baseline['_version']);fresh['Localisations']=[]
  self.assert_status(self.entity_put(fresh));self.assertIsNone(db.one('SELECT 1 n FROM systeme."T_Entite_Localisation" WHERE "IdEntiteLocalisation"=%s',[point['IdEntiteLocalisation']]))

 def test_27_collection_revision_refuses_omitted_changed_or_deleted_point(self):
  self.assert_status(self.entity_put(self.profile_body(Localisations=[{'AdresseDetaillee':'Point initial'}])))
  baseline=self.profile_body();identifier=baseline['Localisations'][0]['IdEntiteLocalisation'];baseline['Localisations']=[]
  self.assert_status(self.client().patch('/api/models/T_Entite_Localisation/'+str(identifier),{'AdresseDetaillee':'Point corrigé ailleurs'},format='json'))
  self.assert_status(self.entity_put(baseline),409)
  self.assertEqual(db.one('SELECT "AdresseDetaillee" FROM systeme."T_Entite_Localisation" WHERE "IdEntiteLocalisation"=%s',[identifier])['AdresseDetaillee'],'Point corrigé ailleurs')
  fresh=self.profile_body();self.assert_status(self.client().delete('/api/models/T_Entite_Localisation/'+str(identifier)))
  self.assert_status(self.entity_put(fresh),409)
  self.assertEqual(self.profile_body()['Localisations'],[])

 def test_28_legacy_location_waits_for_parent(self):
  # La route historique doit attendre la sauvegarde imbriquée avant de toucher
  # un enfant ; elle ne peut pas insérer un point entre contrôle et remplacement.
  ready=threading.Event();worker={}
  def send():
   try:
    worker['pid']=db.one('SELECT pg_backend_pid() pid')['pid'];ready.set()
    response=self.client().post('/api/models/T_Entite_Localisation',{'IdEntiteFk':self.entities[0],'AdresseDetaillee':'Point concurrent fictif'},format='json')
    return response.status_code,response.json()
   finally:connections.close_all()
  with psycopg.connect(DSN,row_factory=dict_row) as guard,ThreadPoolExecutor(max_workers=1) as executor:
   with guard.transaction():
    guard.execute('SELECT "IdEntite" FROM systeme."T_Entite" WHERE "IdEntite"=%s FOR UPDATE',[self.entities[0]])
    future=executor.submit(send);self.assertTrue(ready.wait(5))
    deadline=time.monotonic()+5;waited=False
    while time.monotonic()<deadline:
     state=self.sql.execute('SELECT wait_event_type,query FROM pg_stat_activity WHERE pid=%s',[worker['pid']]).fetchone()
     if state and state['wait_event_type']=='Lock' and 'FOR UPDATE' in state['query']:
      waited=True;break
     time.sleep(.02)
    self.assertTrue(waited,state);self.assertFalse(future.done())
   status,result=future.result(timeout=10);self.assertEqual(status,201,result)

 def test_29_profile_in_real_readonly_transaction(self):
  for application_readonly in (False,True):
   with self.subTest(application_readonly=application_readonly),override_settings(DB_READ_ONLY=application_readonly),transaction.atomic():
    db.query('SET TRANSACTION READ ONLY')
    self.assertEqual(db.one("SELECT current_setting('transaction_read_only') AS mode")['mode'],'on')
    admin=self.assert_status(self.client().get('/api/systeme/entites/'+str(self.entities[0])))
    documentary=self.assert_status(self.client().get('/api/logistique/entreprise/identite'))
    self.assertEqual(admin['_version'],documentary['_version']);self.assertIsInstance(admin['Localisations'],list)
    self.assertNotIn('CollectionRevision',admin);self.assertNotIn('Localisations',documentary)
    self.assertEqual(admin['canConfigure'],not application_readonly)

 def presentation_client(self,index=0,*,global_admin=False,scope=True,staff=True,logistics_read=True,settings_manage=True,cash_read=False):
  actor=self.actor(index,global_admin=global_admin,scope=scope,staff=staff)
  actor._module_access['modules']['logistique'].update(canRead=logistics_read,canManage=False)
  actor._module_access['modules']['parametres']={'canRead':True,'canManage':settings_manage,'reason':'MODULE_ROLE_FORBIDDEN'}
  actor._module_access['modules']['caisse']={'canRead':cash_read,'canManage':False,'reason':'MODULE_ROLE_FORBIDDEN'}
  client=APIClient()
  client.force_authenticate(actor)
  return client

 def presentation_body(self,revision=None,**changes):
  return {'entityId':self.entities[0],'revision':revision,'tabLabels':{'articles':'Matériel'},
          'hiddenDashboardBlocks':['alertes','factures'],**changes}

 def test_30_presentation_isolation_revision_and_single_audit(self):
  client=self.presentation_client()
  defaults=self.assert_status(client.get(PRESENTATION_SETTINGS))
  self.assertTrue(defaults['canManage'])
  self.assertIsNone(defaults['revision'])
  self.assertEqual(defaults['hiddenTabs'],[])
  body=self.presentation_body(tabLabels={'articles':'  Matériel  '},hiddenTabs=['factures','tiers'])
  saved=self.assert_status(client.put(PRESENTATION_SETTINGS,body,format='json'))
  self.assertEqual(saved['tabLabels'],{'articles':'Matériel'})
  self.assertEqual(saved['hiddenTabs'],['tiers','factures'])
  self.assertEqual(saved['hiddenDashboardBlocks'],['factures','alertes'])
  self.assertEqual(self.assert_status(client.get(PRESENTATION)),saved)
  other=self.assert_status(self.presentation_client(index=1).get(PRESENTATION))
  self.assertEqual(other['tabLabels'],{})
  self.assertEqual(other['hiddenTabs'],[])
  self.assertEqual(other['hiddenDashboardBlocks'],[])
  self.assert_status(client.put(PRESENTATION_SETTINGS,body,format='json'),409)
  unchanged=self.assert_status(client.put(PRESENTATION_SETTINGS,self.presentation_body(saved['revision']),format='json'))
  self.assertEqual(unchanged,saved)
  audits=db.query('''SELECT "NewData"->'_actor'->>'IdUser' AS actor FROM systeme."T_Audit_Log"
    WHERE "IdEntiteFk"=%s AND "TableName"='T_Admin_UI_Setting' AND "NewData"->>'SettingKey'='logistique.presentation' ''',[self.entities[0]])
  self.assertEqual(audits,[{'actor':str(self.users[0]['IdUser'])}])
  reset=self.assert_status(client.put(PRESENTATION_SETTINGS,self.presentation_body(saved['revision'],tabLabels={},hiddenTabs=[],hiddenDashboardBlocks=[]),format='json'))
  self.assertEqual(reset['tabLabels'],{})
  self.assertEqual(reset['hiddenTabs'],[])
  self.assertEqual(reset['hiddenDashboardBlocks'],[])
  self.assertNotEqual(reset['revision'],saved['revision'])

 def test_31_presentation_access_and_inactive_company(self):
  reader=self.presentation_client(staff=False,settings_manage=False)
  self.assertFalse(self.assert_status(reader.get(PRESENTATION))['canManage'])
  self.assert_status(reader.put(PRESENTATION_SETTINGS,self.presentation_body(),format='json'),403)
  no_logistics=self.presentation_client(logistics_read=False)
  self.assert_status(no_logistics.get(PRESENTATION_SETTINGS),403)
  self.assert_status(no_logistics.put(PRESENTATION_SETTINGS,self.presentation_body(),format='json'),403)
  global_view=self.presentation_client(global_admin=True,scope=False)
  unscoped=self.assert_status(global_view.get(PRESENTATION))
  self.assertIsNone(unscoped['entityId'])
  self.assertFalse(unscoped['canManage'])
  self.assert_status(global_view.put(PRESENTATION_SETTINGS,self.presentation_body(),format='json'),409)
  editor=self.presentation_client()
  self.assert_status(editor.put(PRESENTATION_SETTINGS,self.presentation_body(entityId=self.entities[1]),format='json'),403)
  with override_settings(DB_READ_ONLY=True):
   self.assertFalse(self.assert_status(editor.get(PRESENTATION_SETTINGS))['canManage'])
   self.assert_status(editor.put(PRESENTATION_SETTINGS,self.presentation_body(),format='json'),503)
  db.query('UPDATE systeme."T_Entite" SET "ValideEntite"=false WHERE "IdEntite"=%s',[self.entities[0]])
  self.assertFalse(self.assert_status(editor.get(PRESENTATION_SETTINGS))['canManage'])
  self.assert_status(editor.put(PRESENTATION_SETTINGS,self.presentation_body(),format='json'),409)

 def license_presentation_module(self,module,index=0):
  status=reference_options(self.actor(),'systeme','T_Licence','IdStatutLicenceFk')[0]['id']
  licence=db.one('''INSERT INTO systeme."T_Licence"("IdEntiteFk","DateDebut","DateFin","ValideLicence","IdStatutLicenceFk")
    VALUES(%s,CURRENT_TIMESTAMP,CURRENT_TIMESTAMP+INTERVAL '1 year',true,%s) RETURNING "IdLicence"''',
    [self.entities[index],status])['IdLicence']
  db.query('INSERT INTO systeme."T_LicenceModule"("IdLicenceFk","CodeModule") VALUES(%s,%s)',[licence,module])

 def test_32_presentation_validates_keys_and_guards_generic_crud(self):
  self.license_presentation_module('logistique')
  client=self.presentation_client(global_admin=True)
  for changes in ({'tabLabels':{'inconnu':'Matériel'}},{'tabLabels':{'articles':'x'*61}},
                  {'tabLabels':{'articles':'x\ny'}},{'hiddenDashboardBlocks':['inconnu']},
                  {'hiddenDashboardBlocks':['alertes','alertes']},{'hiddenTabs':['inconnu']},
                  {'hiddenTabs':['tiers','tiers']},{'hiddenTabs':['tiers',{}]},{'hiddenTabs':None},{'extra':True}):
   with self.subTest(changes=changes):
    self.assert_status(client.put(PRESENTATION_SETTINGS,self.presentation_body(**changes),format='json'),422)
  self.assertIsNone(self.assert_status(client.get(PRESENTATION_SETTINGS))['revision'])
  generic='/api/systeme/admin-ui-settings'
  reserved=self.row('parametres',SettingKey='logistique.presentation')['data']
  self.assert_status(client.post(generic,reserved,format='json'),405)
  self.assert_status(self.post('parametres',self.body('parametres',n=1,SettingKey='logistique.presentation')),422)
  normal=self.assert_status(client.post(generic,self.row('parametres')['data'],format='json'),201)
  self.assert_status(client.patch(generic+'/'+str(normal['IdAdminUISetting']),{'SettingKey':'logistique.presentation'},format='json'),405)
  self.assert_status(client.put(PRESENTATION_SETTINGS,self.presentation_body(),format='json'))
  setting=db.one('''SELECT "IdAdminUISetting" FROM systeme."T_Admin_UI_Setting"
    WHERE "SettingKey"='logistique.presentation' AND "SettingScope"='entite' AND "ScopeValue"=%s''',[str(self.entities[0])])
  reserved_path=generic+'/'+str(setting['IdAdminUISetting'])
  self.assert_status(client.patch(reserved_path,{'ValideSetting':False},format='json'),405)
  self.assert_status(client.delete(reserved_path),405)

 def test_33_presentation_in_real_readonly_transaction(self):
  client=self.presentation_client()
  with transaction.atomic():
   db.query('SET TRANSACTION READ ONLY')
   self.assertEqual(db.one("SELECT current_setting('transaction_read_only') AS mode")['mode'],'on')
   self.assertEqual(self.assert_status(client.get(PRESENTATION)),self.assert_status(client.get(PRESENTATION_SETTINGS)))


 def test_34_presentation_available_modules_and_legacy_storage(self):
  self.license_presentation_module('logistique')
  self.license_presentation_module('caisse',index=1)
  global_client=self.presentation_client(global_admin=True,cash_read=True)
  other=self.presentation_client(index=1,global_admin=True,cash_read=True)
  self.assertEqual(self.assert_status(global_client.get(PRESENTATION_MODULES)),
                   {'entityId':self.entities[0],'modules':[{'key':'logistique','label':'Logistique'}]})
  self.assertEqual(self.assert_status(other.get(PRESENTATION_MODULES)),
                   {'entityId':self.entities[1],'modules':[{'key':'caisse','label':'Caisse'}]})
  self.assertEqual(self.assert_status(self.presentation_client(global_admin=True,scope=False).get(PRESENTATION_MODULES)),
                   {'entityId':None,'modules':[]})
  self.assert_status(other.get(PRESENTATION_SETTINGS),403)
  self.assert_status(other.put(PRESENTATION_SETTINGS,self.presentation_body(entityId=self.entities[1]),format='json'),403)
  self.assertFalse(self.assert_status(other.get(PRESENTATION))['canManage'])
  self.assert_status(global_client.get(CAISSE_PRESENTATION_SETTINGS),403)

  original=self.assert_status(global_client.put(PRESENTATION_SETTINGS,self.presentation_body(),format='json'))
  db.query('''UPDATE systeme."T_Admin_UI_Setting" SET "SettingValueJson"="SettingValueJson"-'hiddenTabs'
    WHERE "SettingScope"='entite' AND "ScopeValue"=%s AND "SettingKey"='logistique.presentation' ''',[str(self.entities[0])])
  legacy=self.assert_status(global_client.get(PRESENTATION_SETTINGS))
  self.assertEqual(legacy['tabLabels'],original['tabLabels'])
  self.assertEqual(legacy['hiddenDashboardBlocks'],original['hiddenDashboardBlocks'])
  self.assertEqual(legacy['hiddenTabs'],[])

  cash=self.assert_status(other.get(CAISSE_PRESENTATION_SETTINGS))
  tabs=['tableau-de-bord','caisses','ecritures','clotures']
  self.assertCountEqual(cash['tabDefaults'],tabs)
  updated=self.assert_status(other.put(CAISSE_PRESENTATION_SETTINGS,
    self.presentation_body(cash['revision'],entityId=self.entities[1],tabLabels={'caisses':'Guichets'},
                           hiddenTabs=tabs,hiddenDashboardBlocks=['flux']),format='json'))
  self.assertEqual(updated['hiddenTabs'],tabs)
  self.assertEqual(updated['hiddenDashboardBlocks'],['flux'])
  self.assertEqual(self.assert_status(other.get(CAISSE_PRESENTATION)),updated)
  self.assertEqual(self.assert_status(global_client.get(PRESENTATION_SETTINGS)),legacy)

if __name__=='__main__':
 result=unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(AdminEnterpriseAPI))
 Path('.runtime/admin-entreprises-api.json').write_text(json.dumps({'passed':result.wasSuccessful(),'tests':result.testsRun,'failures':len(result.failures),'errors':len(result.errors),'database':target.path[1:]}),encoding='utf8');raise SystemExit(0 if result.wasSuccessful() else 1)
