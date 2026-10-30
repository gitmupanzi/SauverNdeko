"""Recette réelle de la géographie, exclusivement sur PostgreSQL privé local."""
import json,os,sys,unittest,uuid,zipfile,io,threading,time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from urllib.parse import urlsplit
from unittest.mock import patch
import psycopg
from psycopg.rows import dict_row
DSN=os.environ.get('SAUVERNDEKO_TEST_DATABASE_URL','');target=urlsplit(DSN)
if target.hostname not in {'127.0.0.1','localhost'} or not target.path[1:].startswith('sauverndeko_test_'):raise RuntimeError('Recette réservée au PostgreSQL privé sauverndeko_test_*.')
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'backend'))
os.environ.update(DATABASE_URL=DSN,DJANGO_SETTINGS_MODULE='config.settings',SAUVERNDEKO_DB_READ_ONLY='0')
import django;django.setup()
from django.db import transaction,connections,DatabaseError
from django.test import override_settings
from rest_framework.test import APIClient
from apps.accounts.authentication import Actor
from apps.core import db
from apps.core.territorial_portal import SOURCES,MODELS,INTERFACE_KEYS,DEFAULTS,record,source,source_sql,references
BASE='/api/geolocalisation/territoires/'

class TerritorialAPI(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.override=override_settings(ALLOWED_HOSTS=['testserver']);cls.override.enable()
  cls.sql=psycopg.connect(DSN,autocommit=True,row_factory=dict_row)
  cls.user=cls.sql.execute('INSERT INTO systeme."T_Utilisateurs"("NomUser","PrenomUser","EmailUser","MotdepasseUser","ValideUser","SexeUser","Is_Admin","Is_staff") VALUES(\'Territoire\',\'Fictif\',%s,\'inutilisable\',true,\'M\',true,true) RETURNING *',[uuid.uuid4().hex+'@example.invalid']).fetchone()
 @classmethod
 def tearDownClass(cls):cls.sql.close();cls.override.disable()
 def setUp(self):
  self.tx=None if self._testMethodName in {'test_21_concurrent_replay','test_22_legacy_hierarchy_serialized','test_25_type_site_migration_replay','test_34_concurrent_batch_replay','test_35_concurrent_batch_duplicate'} else transaction.atomic()
  if self.tx:self.tx.__enter__()
 def tearDown(self):
  if self.tx:transaction.set_rollback(True);self.tx.__exit__(None,None,None)
 def actor(self,global_admin=True,read=True,manage=True,export=True,entity=None):
  actor=Actor({**self.user,'Is_Admin':global_admin,'Is_staff':True,'IdEntiteFk':entity})
  if global_admin and entity:actor._context_entity=entity
  actor._module_access={'modules':{key:{'canRead':read,'canManage':manage,'canExport':export,'reason':'MODULE_ROLE_FORBIDDEN'} for key in ('territoires','administration','logistique')}};return actor
 def client(self,**rights):client=APIClient();client.force_authenticate(self.actor(**rights));return client
 def payload(self,kind,parent=None):
  name='NomNiveau_1_Old' if kind=='niveaux1-historique' else 'NomNiveau_'+kind[-1]
  row={'requestId':str(uuid.uuid4()),name:'Géographie fictive '+uuid.uuid4().hex}
  if parent:row[parent[0]]=parent[1]
  return row
 def status(self,response,expected=200):self.assertEqual(response.status_code,expected,getattr(response,'data',None));return response.json().get('data')
 def create(self,kind,body=None):return self.status(self.client().post(BASE+'registres/'+kind,body or self.payload(kind),format='json'),201)
 def chain(self):
  rows=[self.create('niveaux0')]
  for n in range(1,6):
   parent='ID_Niveau_'+str(n-1)+'_'+('Fk' if n in {1,4,5} else 'FK')
   rows.append(self.create('niveaux'+str(n),self.payload('niveaux'+str(n),(parent,rows[-1]['ID_Niveau_'+str(n-1)]))))
  return rows
 def test_01_thirteen_views_real_queries(self):
  for kind in SOURCES:
   with self.subTest(kind=kind):
    response=self.client().get(BASE+'registres/'+kind,{'take':2,'skip':0});self.status(response);meta=response.json()['meta'];self.assertGreaterEqual(meta['totalCount'],len(response.json()['data']));self.assertLessEqual(len(response.json()['data']),2);self.assertTrue(meta['columns']);self.assertTrue(meta['shared'])
    if kind not in MODELS:self.assertFalse(meta['canCreate']);self.assertTrue(all('_rowId' in row for row in response.json()['data']))
 def test_02_create_edit_seven_identities(self):
  chain=self.chain();chain.append(self.create('niveaux1-historique'))
  for kind,row in zip([*['niveaux'+str(n) for n in range(6)],'niveaux1-historique'],chain):
   pk=SOURCES[kind][2];identifier=row[pk];field=SOURCES[kind][3]
   self.assertEqual(self.status(self.client().get(BASE+'registres/'+kind+'/'+str(identifier)))[pk],identifier)
   body={'requestId':str(uuid.uuid4()),'_version':row['_version'],field:row[field]+' modifié'}
   saved=self.status(self.client().patch(BASE+'registres/'+kind+'/'+str(identifier),body,format='json'));self.assertEqual(saved[field],body[field]);self.assertNotEqual(saved['_version'],'')
 def test_03_create_and_update_replay(self):
  body=self.payload('niveaux0');one=self.create('niveaux0',body);two=self.status(self.client().post(BASE+'registres/niveaux0',body,format='json'));self.assertEqual(one,two)
  edit={'requestId':str(uuid.uuid4()),'_version':one['_version'],'NomNiveau_0':'Modification fictive'}
  saved=self.status(self.client().put(BASE+'registres/niveaux0/'+str(one['ID_Niveau_0']),edit,format='json'));self.assertEqual(saved,self.status(self.client().put(BASE+'registres/niveaux0/'+str(one['ID_Niveau_0']),edit,format='json')))
  edit['NomNiveau_0']='Autre contenu';self.status(self.client().put(BASE+'registres/niveaux0/'+str(one['ID_Niveau_0']),edit,format='json'),409)
 def test_04_conflict_and_fk_delete(self):
  rows=self.chain();country=rows[0];pk=country['ID_Niveau_0'];body={'requestId':str(uuid.uuid4()),'_version':'ancienne','NomNiveau_0':'Perdu'}
  self.status(self.client().patch(BASE+'registres/niveaux0/'+str(pk),body,format='json'),409);self.assertEqual(record(self.actor(),'niveaux0',pk)['NomNiveau_0'],country['NomNiveau_0'])
  self.status(self.client().delete(BASE+'registres/niveaux0/'+str(pk),{'requestId':str(uuid.uuid4()),'_version':country['_version']},format='json'),409)
  self.assertEqual(db.one('SELECT count(*) n FROM geolocalisation."T_Niveau_0" WHERE "ID_Niveau_0"=%s',[pk])['n'],1)
 def test_05_delete_leaf_and_replay(self):
  row=self.create('niveaux0');pk=row['ID_Niveau_0'];body={'requestId':str(uuid.uuid4()),'_version':row['_version']};response=self.client().delete(BASE+'registres/niveaux0/'+str(pk),body,format='json');self.status(response);self.status(self.client().delete(BASE+'registres/niveaux0/'+str(pk),body,format='json'));self.status(self.client().get(BASE+'registres/niveaux0/'+str(pk)),404)
 def test_06_rights_enforced_every_path(self):
  self.status(APIClient().get(BASE+'synthese'),401);self.status(self.client(read=False).get(BASE+'registres/niveaux0'),403)
  local=self.client(global_admin=False);self.status(local.get(BASE+'registres/niveaux0'));self.assertFalse(self.status(local.get(BASE+'references/niveaux0'))['canCreate']);self.status(local.post(BASE+'registres/niveaux0',self.payload('niveaux0'),format='json'),403)
  self.status(self.client(manage=False).post(BASE+'registres/niveaux0',self.payload('niveaux0'),format='json'),403)
  with override_settings(DB_READ_ONLY=True):self.status(self.client().post(BASE+'registres/niveaux0',self.payload('niveaux0'),format='json'),503)
 def test_07_shared_geography_no_owner_from_context(self):
  row=self.create('niveaux0');one=self.status(self.client().get(BASE+'registres/niveaux0',{'filters':json.dumps({'ID_Niveau_0':row['ID_Niveau_0']})}));two=self.status(self.client(entity=987654321).get(BASE+'registres/niveaux0',{'filters':json.dumps({'ID_Niveau_0':row['ID_Niveau_0']})}));self.assertEqual(one,two)
 def test_08_closed_criteria(self):
  for args in ({'sortBy':'nom;drop table'},{'sortDir':'sideways'},{'filters':'[]'},{'filters':'{"geometryNiveau_0":"abc"}'},{'dateFrom':'2026-01-01'},{'q':'x'*301}):
   self.status(self.client().get(BASE+'registres/niveaux0',args),400)
  self.status(self.client().get(BASE+'registres/inconnu'),404)
 def test_09_snapshot_indicator_list_parity(self):
  self.chain();data=self.status(self.client().get(BASE+'synthese'))
  for key,target in data['metricTargets'].items():
   result=self.client().get(BASE+'registres/'+target['kind'],{'take':1,'filters':json.dumps(target['filters'])});self.status(result);self.assertEqual(data['metrics'][key],result.json()['meta']['filteredCount'])
  for values,filter_key in [(data['charts']['structuresParProvince'],'ID_Niveau_1'),(data['charts']['sitesParType'],'ID_TypeNiveau_5_Fk')]:
   self.assertEqual(sum(r['count'] for r in values),data['metrics']['niveaux5'])
   for group in values[:3]:
    result=self.client().get(BASE+'registres/niveaux5',{'take':1,'filters':json.dumps({filter_key:group[filter_key]})});self.status(result);self.assertEqual(group['count'],result.json()['meta']['filteredCount'])
 def test_10_parent_labels_filters_and_raw_fk(self):
  rows=self.chain();province=rows[1]['ID_Niveau_1'];zone=rows[3]
  result=self.status(self.client().get(BASE+'registres/niveaux3',{'filters':json.dumps({'ID_Niveau_1':province})}));found=next(r for r in result if r['ID_Niveau_3']==zone['ID_Niveau_3']);self.assertEqual(found['NomNiveau_2'],rows[2]['NomNiveau_2']);self.assertEqual(found['NomNiveau_1'],rows[1]['NomNiveau_1']);self.assertEqual(self.status(self.client().get(BASE+'registres/niveaux3/'+str(zone['ID_Niveau_3'])))['ID_Niveau_2_FK'],rows[2]['ID_Niveau_2'])
 def test_11_validation_preserves_rows(self):
  country=self.create('niveaux0')
  for fields in ({'NomNiveau_1':' '},{'PopulationNiveau_1':'-1'},{'LatitudeNiveau_1':'91'},{'LatitudeNiveau_1':'1','LongitudeNiveau_1':None},{'PopulationNiveau_1':'0.5'}):
   body={**self.payload('niveaux1',('ID_Niveau_0_Fk',country['ID_Niveau_0'])),**fields};before=db.one('SELECT count(*) n FROM geolocalisation."T_Niveau_1"')['n'];self.status(self.client().post(BASE+'registres/niveaux1',body,format='json'),422);self.assertEqual(before,db.one('SELECT count(*) n FROM geolocalisation."T_Niveau_1"')['n'])
 def test_12_references_dynamic_and_hierarchy(self):
  rows=self.chain();support=self.status(self.client().get(BASE+'references/niveaux5',{'currentId':rows[5]['ID_Niveau_5']}));self.assertIn('niveaux4',support['options']);self.assertTrue(support['fieldReferences']);area=next(r for r in support['options']['niveaux4'] if r['id']==rows[4]['ID_Niveau_4']);self.assertEqual(area['parentId'],rows[3]['ID_Niveau_3'])
  for field,context in support['fieldReferences'].items():
   self.assertIn('categoryIds',context);self.assertIn('categoryLabels',context);self.assertIn('options',context)
 def test_13_nonmatching_parent_rejected(self):
  first=self.chain();other=self.chain();site=first[-1];body={'requestId':str(uuid.uuid4()),'_version':site['_version'],'ID_Niveau_3_Fk':other[3]['ID_Niveau_3']};self.status(self.client().patch(BASE+'registres/niveaux5/'+str(site['ID_Niveau_5']),body,format='json'),422)
 def test_14_reports_read_only_and_stable_grain(self):
  for kind in (k for k in SOURCES if k not in MODELS):
   response=self.client().get(BASE+'registres/'+kind,{'take':100});rows=self.status(response);self.assertEqual(len(rows),len({r['_rowId'] for r in rows}));self.status(self.client().post(BASE+'registres/'+kind,{'requestId':str(uuid.uuid4())},format='json'),405)
 def test_15_profiles_readonly_database(self):
  with transaction.atomic():
   db.query('SET TRANSACTION READ ONLY');self.assertEqual(db.one("SHOW transaction_read_only")['transaction_read_only'],'on');self.status(self.client().get(BASE+'synthese'))
   for kind in SOURCES:self.status(self.client().get(BASE+'registres/'+kind,{'take':1}))
 def test_16_exports_complete_filtered_selected(self):
  rows=[self.create('niveaux0') for _ in range(3)];ids=[r['ID_Niveau_0'] for r in rows]
  for kind in SOURCES:
   with self.subTest(kind=kind):
    response=self.client().get(BASE+'registres/'+kind+'/export.xlsx',{'take':1,'columns':json.dumps(DEFAULTS[kind])},HTTP_ACCEPT='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');self.assertEqual(response.status_code,200,getattr(response,'data',None));contents=b''.join(response.streaming_content);self.assertTrue(zipfile.is_zipfile(io.BytesIO(contents)))
  selected=self.client().get(BASE+'registres/niveaux0/export.csv',{'selection':json.dumps(ids[:2]),'columns':json.dumps(['NomNiveau_0'])},HTTP_ACCEPT='text/csv');self.assertEqual(selected.status_code,200,getattr(selected,'data',None));self.assertEqual(int(selected['X-Export-Row-Count']),2)
  self.status(self.client(export=False).get(BASE+'registres/niveaux0/export.xlsx'),403)
 def test_17_sites_can_reference_zone_without_area(self):
  rows=self.chain();zone=rows[3]['ID_Niveau_3'];site=self.create('niveaux5',self.payload('niveaux5',('ID_Niveau_3_Fk',zone)));self.assertIsNone(site['ID_Niveau_4_Fk']);self.assertEqual(site['ID_Niveau_3_Fk'],zone)
  edited=self.status(self.client().patch(BASE+'registres/niveaux5/'+str(site['ID_Niveau_5']),{'requestId':str(uuid.uuid4()),'_version':site['_version'],'ObsNiveau_5':'Description sans aire'},format='json'));self.assertIsNone(edited['ID_Niveau_4_Fk']);self.assertEqual(edited['ID_Niveau_3_Fk'],zone)
 def test_18_area_move_protected_on_both_routes(self):
  first=self.chain();other=self.chain();area=first[4];newzone=other[3]['ID_Niveau_3']
  self.status(self.client().patch(BASE+'registres/niveaux4/'+str(area['ID_Niveau_4']),{'requestId':str(uuid.uuid4()),'_version':area['_version'],'ID_Niveau_3_Fk':newzone},format='json'),422)
  self.status(self.client().patch('/api/models/T_Niveau_4/'+str(area['ID_Niveau_4']),{'ID_Niveau_3_Fk':newzone},format='json'),422)
  self.assertEqual(record(self.actor(),'niveaux4',area['ID_Niveau_4'])['ID_Niveau_3_Fk'],first[3]['ID_Niveau_3'])
 def test_19_legacy_routes_validate_new_saisie(self):
  self.status(self.client().post('/api/models/T_Niveau_0',{'NomNiveau_0':'   '},format='json'),422)
  rows=self.chain();site=rows[5]
  self.status(self.client().patch('/api/models/T_Niveau_5/'+str(site['ID_Niveau_5']),{'LatitudeNiveau_5':'-91','LongitudeNiveau_5':'10'},format='json'),422)
  # Une ancienne incohérence conservée n'interdit pas une correction descriptive.
  db.query('UPDATE geolocalisation."T_Niveau_5" SET "ID_Niveau_3_Fk"=NULL WHERE "ID_Niveau_5"=%s',[site['ID_Niveau_5']])
  edited=self.status(self.client().patch('/api/models/T_Niveau_5/'+str(site['ID_Niveau_5']),{'ObsNiveau_5':'Historique conservé'},format='json'));self.assertIsNone(edited['ID_Niveau_3_Fk'])
 def test_20_dynamic_references_and_incompatible_retained(self):
  from apps.core.field_references import reference_context,save as save_reference
  rows=self.chain();parent=rows[1]['ID_Niveau_1'];field='ID_TypeNiveau_2_Fk';table='T_Niveau_2';context=reference_context(self.actor(),'geolocalisation',table,field)
  category=context['categoryIds'][0]
  old_value=db.one('INSERT INTO referentiel."T_Generique"("ID_CategorieGeneriqueFk","NomGenerique","AbrGenerique","ValideGenerique") VALUES(%s,%s,%s,true) RETURNING "ID_Generique" id',[category,'Type fictif '+uuid.uuid4().hex,'TF'])['id']
  row=self.create('niveaux2',{**self.payload('niveaux2',('ID_Niveau_1_FK',parent)),field:old_value})
  new_category=db.one('INSERT INTO referentiel."T_CategorieGenerique"("NomCategorieGenerique","ValideCategorieGenerique") VALUES(%s,true) RETURNING "ID_CategorieGenerique" id',['Famille fictive '+uuid.uuid4().hex])['id']
  new_value=db.one('INSERT INTO referentiel."T_Generique"("ID_CategorieGeneriqueFk","NomGenerique","AbrGenerique","ValideGenerique") VALUES(%s,%s,%s,true) RETURNING "ID_Generique" id',[new_category,'Nouveau type fictif','NF'])['id']
  identifier=db.one('SELECT "ID_ChampReferentiel" id FROM referentiel."T_ChampReferentiel" WHERE "SchemaName"=\'geolocalisation\' AND "TableName"=%s AND "ColumnName"=%s',[table,field])['id']
  _,_=save_reference(self.actor(),identifier,{'scope':'global','_version':context['_version'],'requestId':str(uuid.uuid4()),'motif':'Recette de la famille territoriale','categoryIds':[new_category]})
  support=references(self.actor(),'niveaux2',row['ID_Niveau_2']);current=support['fieldReferences'][field];self.assertEqual(current['categoryIds'],[new_category]);self.assertIn(new_value,[item['id'] for item in current['options']]);retained=next(item for item in current['options'] if item['id']==old_value);self.assertTrue(retained['incompatible']);self.assertTrue(retained['disabled'])
  edited=self.status(self.client().patch(BASE+'registres/niveaux2/'+str(row['ID_Niveau_2']),{'requestId':str(uuid.uuid4()),'_version':row['_version'],'ObsNiveau_2':'Description conservée'},format='json'));self.assertEqual(edited[field],old_value)
  fresh=reference_context(self.actor(),'geolocalisation',table,field);save_reference(self.actor(),identifier,{'scope':'global','_version':fresh['_version'],'requestId':str(uuid.uuid4()),'motif':'Rétablir la configuration de recette'},restore=True);self.assertEqual(reference_context(self.actor(),'geolocalisation',table,field)['categoryIds'],context['categoryIds'])
  for kind,alias in [('population-sites','niveau5Types'),('statistiques-provinces','niveau2Types'),('statistiques-zones','niveau4Types')]:self.assertIn(alias,references(self.actor(),kind)['options'])
 def test_21_concurrent_replay(self):
  body=self.payload('niveaux0')
  def send():
   try:response=self.client().post(BASE+'registres/niveaux0',body,format='json');return response.status_code,response.json()
   finally:connections.close_all()
  with ThreadPoolExecutor(max_workers=2) as pool:results=list(pool.map(lambda _:send(),range(2)))
  self.assertEqual(sorted(status for status,_ in results),[200,201]);self.assertEqual(results[0][1]['data'],results[1][1]['data']);self.assertEqual(db.one('SELECT count(*) n FROM geolocalisation."T_Niveau_0" WHERE "NomNiveau_0"=%s',[body['NomNiveau_0']])['n'],1)
 def test_22_legacy_hierarchy_serialized(self):
  ready=threading.Event();worker={}
  def send():
   try:
    worker['pid']=db.one('SELECT pg_backend_pid() pid')['pid'];ready.set();response=self.client().post('/api/models/T_Niveau_0',{'NomNiveau_0':'Verrou fictif '+uuid.uuid4().hex},format='json');return response.status_code,response.json()
   finally:connections.close_all()
  with psycopg.connect(DSN,row_factory=dict_row) as guard,ThreadPoolExecutor(max_workers=1) as pool:
   with guard.transaction():
    guard.execute("SELECT pg_advisory_xact_lock(hashtextextended('geolocalisation:hierarchy-writes',0))");future=pool.submit(send);self.assertTrue(ready.wait(5));deadline=time.monotonic()+5;waited=False
    while time.monotonic()<deadline:
     state=self.sql.execute('SELECT wait_event_type FROM pg_stat_activity WHERE pid=%s',[worker['pid']]).fetchone()
     if state and state['wait_event_type']=='Lock':waited=True;break
     time.sleep(.02)
    self.assertTrue(waited);self.assertFalse(future.done())
   status,response=future.result(timeout=10);self.assertEqual(status,201,response)
 def test_23_nullable_and_decimal_precision_errors(self):
  country=self.create('niveaux0');parent=('ID_Niveau_0_Fk',country['ID_Niveau_0'])
  for values in ({'VisibleNiveau_1':None},{'VisibleNiveau_5':None},{'LatitudeNiveau_1':'1.1234567','LongitudeNiveau_1':'1'},{'PopulationNiveau_1':'99999999999999999999999999999999999999999999999'}):
   response=self.client().post(BASE+'registres/niveaux1',{**self.payload('niveaux1',parent),**values},format='json');self.status(response,422);self.assertTrue(response.json()['error']['details'])
  precise=self.create('niveaux1',{**self.payload('niveaux1',parent),'LatitudeNiveau_1':'1.123456000','LongitudeNiveau_1':'1.000000000'});self.assertEqual(str(precise['LatitudeNiveau_1']),'1.123456')
 def test_24_type_site_fk_catalogue_and_direct_guard(self):
  field=db.one('SELECT * FROM referentiel."T_ChampReferentiel" WHERE "SchemaName"=\'geolocalisation\' AND "TableName"=\'T_Niveau_5\' AND "ColumnName"=\'ID_TypeNiveau_5_Fk\'');self.assertIsNotNone(field);self.assertFalse(field['SupportsEntityScope']);self.assertIn('niveau5Types',field['AliasSourceKeys'])
  fk=db.one('SELECT convalidated FROM pg_constraint WHERE conrelid=\'geolocalisation."T_Niveau_5"\'::regclass AND conname=\'Fk_TypeNiveau_5_Generique\'');self.assertTrue(fk['convalidated'])
  zone=self.chain()[3]['ID_Niveau_3']
  with self.assertRaises(DatabaseError):
   with transaction.atomic():db.query('INSERT INTO geolocalisation."T_Niveau_5"("NomNiveau_5","ID_Niveau_3_Fk","ID_TypeNiveau_5_Fk") VALUES(%s,%s,%s)',['Type orphelin fictif',zone,2147483647])
  support=references(self.actor(),'niveaux5');self.assertTrue(support['options']['niveau5Types'])
 def test_25_type_site_migration_replay(self):
  sql=(ROOT/'SQL/migrations/20261030_04_type_site_referentiel.sql').read_text(encoding='utf8')
  query='SELECT to_jsonb(c) AS row FROM referentiel."T_ChampReferentiel" c WHERE "SchemaName"=\'geolocalisation\' AND "TableName"=\'T_Niveau_5\' AND "ColumnName"=\'ID_TypeNiveau_5_Fk\''
  before=self.sql.execute(query).fetchone()['row'];fingerprint=self.sql.execute('SELECT md5(COALESCE(jsonb_agg(to_jsonb(n) ORDER BY "ID_Niveau_5"),\'[]\'::jsonb)::text) AS digest FROM geolocalisation."T_Niveau_5" n').fetchone()['digest']
  self.sql.execute(sql);self.sql.execute(sql);self.assertEqual(before,self.sql.execute(query).fetchone()['row']);self.assertEqual(fingerprint,self.sql.execute('SELECT md5(COALESCE(jsonb_agg(to_jsonb(n) ORDER BY "ID_Niveau_5"),\'[]\'::jsonb)::text) AS digest FROM geolocalisation."T_Niveau_5" n').fetchone()['digest'])
 def basket(self,kind,header=None,rows=None):
  return {'requestId':str(uuid.uuid4()),'header':header or {},'rows':rows or [{'rowId':str(uuid.uuid4()),'NomNiveau_'+kind[-1]:'Panier fictif '+uuid.uuid4().hex}]}
 def batch(self,kind,body,client=None,expected=201):return self.status((client or self.client()).post(BASE+'registres/'+kind+'/panier',body,format='json'),expected)
 def test_26_batch_creation_six_levels(self):
  from apps.core.territorial_batches import PARENTS
  chain=self.chain()
  for n in range(6):
   kind='niveaux'+str(n);header={key:chain[int(key[10])]['ID_Niveau_'+key[10]] for key in PARENTS[kind]}
   rows=[{'rowId':str(uuid.uuid4()),'NomNiveau_'+str(n):'Panier complet '+uuid.uuid4().hex,'CodeNiveau_'+str(n):'C'+uuid.uuid4().hex[:5]} for _ in range(2)]
   if n in range(1,6):rows[0].update({'ObsNiveau_'+str(n):'Texte complémentaire','PopulationNiveau_'+str(n):'123','LatitudeNiveau_'+str(n):'1.25000','LongitudeNiveau_'+str(n):'2.50000'})
   body=self.basket(kind,header,rows);result=self.batch(kind,body);self.assertEqual(result['requestId'],body['requestId']);self.assertEqual(result['createdCount'],2);self.assertEqual([r['rowId'] for r in result['rows']],[r['rowId'] for r in rows])
   for item in result['rows']:
    record_data=item['record'];self.assertIn('_version',record_data);self.assertGreater(record_data['ID_Niveau_'+str(n)],0)
    for key,value in header.items():self.assertEqual(record_data[key],value)
   self.assertEqual(self.batch(kind,body,expected=200),result)
 def test_27_batch_errors_keep_transaction_empty(self):
  country=self.create('niveaux0');kind='niveaux1';rows=[{'rowId':str(uuid.uuid4()),'NomNiveau_1':'Bonne ligne '+uuid.uuid4().hex},{'rowId':str(uuid.uuid4()),'NomNiveau_1':' '},{'rowId':str(uuid.uuid4()),'NomNiveau_1':'GPS fictif','LatitudeNiveau_1':'999','LongitudeNiveau_1':'5'}];body=self.basket(kind,{'ID_Niveau_0_Fk':country['ID_Niveau_0']},rows)
  before=db.one('SELECT count(*) n FROM geolocalisation."T_Niveau_1"')['n'];audits=db.one('SELECT count(*) n FROM systeme."T_Audit_Log"')['n'];response=self.client().post(BASE+'registres/'+kind+'/panier',body,format='json');self.status(response,422);errors=response.json()['error']['details'];self.assertIn('NomNiveau_1',errors['rows'][rows[1]['rowId']]);self.assertIn('LatitudeNiveau_1',errors['rows'][rows[2]['rowId']]);self.assertEqual(before,db.one('SELECT count(*) n FROM geolocalisation."T_Niveau_1"')['n']);self.assertEqual(audits,db.one('SELECT count(*) n FROM systeme."T_Audit_Log"')['n'])
  body['rows'][1]['NomNiveau_1']='Corrigé '+uuid.uuid4().hex;body['rows'][2]['LatitudeNiveau_1']='1.123456000';self.assertEqual(self.batch(kind,body)['createdCount'],3)
 def test_28_batch_duplicate_identity_only(self):
  name='Identite '+uuid.uuid4().hex;rows=[{'rowId':str(uuid.uuid4()),'NomNiveau_0':name,'CodeNiveau_0':'CODE'},{'rowId':str(uuid.uuid4()),'NomNiveau_0':' '+name.upper()+' ','CodeNiveau_0':'code'}];body=self.basket('niveaux0',rows=rows);response=self.client().post(BASE+'registres/niveaux0/panier',body,format='json');self.status(response,422);self.assertEqual(set(response.json()['error']['details']['rows']),{r['rowId'] for r in rows})
  body['rows'][1]['CodeNiveau_0']='AUTRE';self.batch('niveaux0',body)
  duplicate=self.basket('niveaux0',rows=[{**rows[0],'rowId':str(uuid.uuid4())}]);self.batch('niveaux0',duplicate,expected=422)
  first=self.create('niveaux0');second=self.create('niveaux0');row={'rowId':str(uuid.uuid4()),'NomNiveau_1':'Même nom '+uuid.uuid4().hex,'CodeNiveau_1':'MEME'}
  self.batch('niveaux1',self.basket('niveaux1',{'ID_Niveau_0_Fk':first['ID_Niveau_0']},[row]));self.batch('niveaux1',self.basket('niveaux1',{'ID_Niveau_0_Fk':second['ID_Niveau_0']},[row]))
 def test_29_batch_header_and_bounds(self):
  chain=self.chain();other=self.chain()
  for header in ({},{'ID_Niveau_0_Fk':2147483647},{'ID_Niveau_0_Fk':True},{'ID_Niveau_0_Fk':chain[0]['ID_Niveau_0'],'unexpected':'x'}):
   response=self.client().post(BASE+'registres/niveaux1/panier',self.basket('niveaux1',header),format='json');self.status(response,422);self.assertTrue(response.json()['error']['details']['header'])
  self.batch('niveaux5',self.basket('niveaux5',{'ID_Niveau_3_Fk':chain[3]['ID_Niveau_3'],'ID_Niveau_4_Fk':other[4]['ID_Niveau_4']}),expected=422)
  direct=self.batch('niveaux5',self.basket('niveaux5',{'ID_Niveau_3_Fk':chain[3]['ID_Niveau_3'],'ID_Niveau_4_Fk':None}));self.assertIsNone(direct['rows'][0]['record']['ID_Niveau_4_Fk'])
  misplaced=self.basket('niveaux1',{'ID_Niveau_0_Fk':chain[0]['ID_Niveau_0']});misplaced['rows'][0]['ID_Niveau_0_Fk']=other[0]['ID_Niveau_0'];self.batch('niveaux1',misplaced,expected=422)
  empty=self.basket('niveaux0');empty['rows']=[];self.batch('niveaux0',empty,expected=422)
  excessive=self.basket('niveaux0',rows=[{'rowId':str(uuid.uuid4()),'NomNiveau_0':'Trop '+str(i)} for i in range(101)]);self.batch('niveaux0',excessive,expected=422)
  self.batch('niveaux1-historique',self.basket('niveaux1'),expected=404)
  bad=self.basket('niveaux0');bad['rows'][0]['ID_Niveau_0']=123;self.batch('niveaux0',bad,expected=422)
 def test_30_batch_dynamic_references(self):
  chain=self.chain();field='ID_TypeNiveau_2_Fk';support=references(self.actor(),'niveaux2');active=next(item for item in support['options'][field] if not item.get('disabled'))['id'];wrong=db.one('SELECT g."ID_Generique" id FROM referentiel."T_Generique" g WHERE NOT (g."ID_CategorieGeneriqueFk"=ANY(%s::int[])) LIMIT 1',[support['fieldReferences'][field]['categoryIds']])['id']
  body=self.basket('niveaux2',{'ID_Niveau_1_FK':chain[1]['ID_Niveau_1']},[{'rowId':str(uuid.uuid4()),'NomNiveau_2':'Valide '+uuid.uuid4().hex,field:active},{'rowId':str(uuid.uuid4()),'NomNiveau_2':'Incompatible '+uuid.uuid4().hex,field:wrong}]);response=self.client().post(BASE+'registres/niveaux2/panier',body,format='json');self.status(response,422);self.assertIn(field,response.json()['error']['details']['rows'][body['rows'][1]['rowId']]);body['rows'][1][field]=active;self.batch('niveaux2',body)
 def test_31_batch_rights_closed_payload(self):
  body=self.basket('niveaux0');self.status(APIClient().post(BASE+'registres/niveaux0/panier',body,format='json'),401)
  for rights in ({'global_admin':False},{'manage':False},{'read':False}):self.batch('niveaux0',body,client=self.client(**rights),expected=403)
  with override_settings(DB_READ_ONLY=True):self.batch('niveaux0',body,expected=503)
  invalid={**body,'entity':9};self.batch('niveaux0',invalid,expected=400)
  body['rows']=[body['rows'][0],body['rows'][0]];self.batch('niveaux0',body,expected=400)
 def test_32_batch_idempotence_conflict(self):
  body=self.basket('niveaux0');result=self.batch('niveaux0',body);self.assertEqual(result,self.batch('niveaux0',body,expected=200));body['rows'][0]['NomNiveau_0']='Autre contenu';self.batch('niveaux0',body,expected=409)
  other=self.basket('niveaux1');other['requestId']=body['requestId'];self.batch('niveaux1',other,expected=409)
 def test_33_batch_late_database_error_rolls_back_all(self):
  marker='Refus tardif '+uuid.uuid4().hex;trigger='test_batch_'+uuid.uuid4().hex
  db.query("CREATE FUNCTION pg_temp.test_territorial_batch_guard() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN IF left(NEW.\"NomNiveau_0\",13)='Refus tardif ' THEN RAISE EXCEPTION USING ERRCODE='23514',MESSAGE='Refus privé de recette'; END IF; RETURN NEW; END $$")
  db.query('CREATE TRIGGER '+db.ident(trigger)+' BEFORE INSERT ON geolocalisation."T_Niveau_0" FOR EACH ROW EXECUTE FUNCTION pg_temp.test_territorial_batch_guard()')
  body=self.basket('niveaux0',rows=[{'rowId':str(uuid.uuid4()),'NomNiveau_0':'Doit annuler '+uuid.uuid4().hex},{'rowId':str(uuid.uuid4()),'NomNiveau_0':marker}]);before=db.one('SELECT count(*) n FROM geolocalisation."T_Niveau_0"')['n'];audits=db.one('SELECT count(*) n FROM systeme."T_Audit_Log"')['n'];response=self.client().post(BASE+'registres/niveaux0/panier',body,format='json');self.status(response,422);self.assertIn(body['rows'][1]['rowId'],response.json()['error']['details']['rows']);self.assertEqual(before,db.one('SELECT count(*) n FROM geolocalisation."T_Niveau_0"')['n']);self.assertEqual(audits,db.one('SELECT count(*) n FROM systeme."T_Audit_Log"')['n'])
 def test_34_concurrent_batch_replay(self):
  body=self.basket('niveaux0',rows=[{'rowId':str(uuid.uuid4()),'NomNiveau_0':'Parallèle '+uuid.uuid4().hex} for _ in range(2)])
  def send():
   try:response=self.client().post(BASE+'registres/niveaux0/panier',body,format='json');return response.status_code,response.json()
   finally:connections.close_all()
  with ThreadPoolExecutor(max_workers=2) as pool:results=list(pool.map(lambda _:send(),range(2)))
  self.assertEqual(sorted(status for status,_ in results),[200,201]);self.assertEqual(results[0][1]['data'],results[1][1]['data']);self.assertEqual(db.one('SELECT count(*) n FROM geolocalisation."T_Niveau_0" WHERE "NomNiveau_0"=ANY(%s::text[])',[[r['NomNiveau_0'] for r in body['rows']]])['n'],2)
 def test_35_concurrent_batch_duplicate(self):
  row={'rowId':str(uuid.uuid4()),'NomNiveau_0':'Doublon concurrent '+uuid.uuid4().hex};bodies=[self.basket('niveaux0',rows=[row]) for _ in range(2)]
  def send(body):
   try:response=self.client().post(BASE+'registres/niveaux0/panier',body,format='json');return response.status_code,response.json()
   finally:connections.close_all()
  with ThreadPoolExecutor(max_workers=2) as pool:results=list(pool.map(send,bodies))
  self.assertEqual(sorted(status for status,_ in results),[201,422]);self.assertEqual(db.one('SELECT count(*) n FROM geolocalisation."T_Niveau_0" WHERE "NomNiveau_0"=%s',[row['NomNiveau_0']])['n'],1)
 def resolve_target(self,row,target):return {key:row[rule['field']] if 'field' in rule else rule['value'] for key,rule in target['filters'].items()}
 def test_36_hierarchy_counters_and_links(self):
  rows=self.chain();zone=rows[3]['ID_Niveau_3'];self.create('niveaux5',self.payload('niveaux5',('ID_Niveau_3_Fk',zone)))
  # Un site ancien peut hériter de sa zone à travers l'aire sans réécriture.
  db.query('UPDATE geolocalisation."T_Niveau_5" SET "ID_Niveau_3_Fk"=NULL WHERE "ID_Niveau_5"=%s',[rows[5]['ID_Niveau_5']])
  for n in range(5):
   kind='niveaux'+str(n);response=self.client().get(BASE+'registres/'+kind,{'filters':json.dumps({'ID_Niveau_'+str(n):rows[n]['ID_Niveau_'+str(n)]})});data=self.status(response);meta=response.json()['meta'];self.assertEqual(len(data),1)
   for column,target in meta['drilldowns'].items():
    children=self.client().get(BASE+'registres/'+target['kind'],{'filters':json.dumps(self.resolve_target(data[0],target)),'take':1});self.status(children);self.assertEqual(data[0][column],children.json()['meta']['filteredCount'],(kind,column))
   for column,link in meta['records'].items():
    if data[0].get(link['idField']) is not None:self.status(self.client().get(BASE+'registres/'+link['kind']+'/'+str(data[0][link['idField']])))
  response=self.client().get(BASE+'registres/niveaux3',{'filters':json.dumps({'ID_Niveau_3':zone})});self.assertEqual(self.status(response)[0]['Nb_Niveau_5'],2)
 def test_37_analysis_provenance_counters(self):
  first=self.chain();second=self.chain();zone=first[3]['ID_Niveau_3'];area=first[4]['ID_Niveau_4'];types=references(self.actor(),'niveaux5')['options']['niveau5Types'];types=[item['id'] for item in types if not item.get('disabled')][:2];self.assertEqual(len(types),2)
  for type_id in types:self.create('niveaux5',{**self.payload('niveaux5',('ID_Niveau_3_Fk',zone)),'ID_Niveau_4_Fk':area,'ID_TypeNiveau_5_Fk':type_id})
  self.create('niveaux5',{**self.payload('niveaux5',('ID_Niveau_3_Fk',zone)),'ID_TypeNiveau_5_Fk':types[0]})
  self.create('niveaux4',self.payload('niveaux4',('ID_Niveau_3_Fk',zone)))
  # L'ancien site d'une aire d'une autre zone reste classé selon sa zone explicite.
  db.query('UPDATE geolocalisation."T_Niveau_5" SET "ID_Niveau_3_Fk"=%s,"ID_TypeNiveau_5_Fk"=%s WHERE "ID_Niveau_5"=%s',[zone,types[1],second[5]['ID_Niveau_5']])
  for kind,filters in [('statistiques-zones',{'ID_Niveau_3':zone}),('statistiques-provinces',{'ID_Niveau_1':first[1]['ID_Niveau_1']}),('population-sites',{'ID_Niveau_3':zone})]:
   response=self.client().get(BASE+'registres/'+kind,{'filters':json.dumps(filters),'take':100});data=self.status(response);meta=response.json()['meta'];self.assertTrue(data)
   for row in data:
    for column,target in meta['drilldowns'].items():
     child_filters=self.resolve_target(row,target);children=self.client().get(BASE+'registres/'+target['kind'],{'filters':json.dumps(child_filters),'take':1});self.status(children)
     if target.get('mode')=='sources':self.assertIn('sources',target['label'])
     else:self.assertEqual(row[column],children.json()['meta']['filteredCount'],(kind,column,row,child_filters))
     exported=self.client().get(BASE+'registres/'+target['kind']+'/export.csv',{'filters':json.dumps(child_filters),'columns':json.dumps(DEFAULTS[target['kind']]),'take':1},HTTP_ACCEPT='text/csv');self.assertEqual(exported.status_code,200,getattr(exported,'data',None));self.assertEqual(int(exported['X-Export-Row-Count']),children.json()['meta']['filteredCount']);b''.join(exported.streaming_content)
 def test_38_network_report_matches_declared_areas(self):
  rows=self.chain();zone=rows[3]['ID_Niveau_3'];options=references(self.actor(),'niveaux4')['options']['networkAvailabilities'];ids=[row['id'] for row in options if not row.get('disabled')];self.assertTrue(ids)
  for value in ids:
   self.create('niveaux4',{**self.payload('niveaux4',('ID_Niveau_3_Fk',zone)),'ID_DispoReseauNiveau_4':value})
  response=self.client().get(BASE+'registres/reseau-as',{'filters':json.dumps({'ID_Niveau_3':zone})});row=self.status(response)[0]
  for column,target in response.json()['meta']['drilldowns'].items():
   children=self.client().get(BASE+'registres/'+target['kind'],{'filters':json.dumps(self.resolve_target(row,target)),'take':1});self.status(children)
   if target.get('mode')=='sources':self.assertEqual(target['label'],'Voir les aires sources')
   else:self.assertEqual(row[column],children.json()['meta']['filteredCount'])
  self.assertIsNotNone(row['Pct_AS_Avec_Reseau'])
  missing=self.client().get(BASE+'registres/niveaux4',{'filters':json.dumps({'StructuresZone':zone})});self.status(missing,400)
  wrong=self.client().get(BASE+'registres/niveaux5',{'filters':json.dumps({'StructuresZone':zone,'StructuresTypeSite':None})});self.status(wrong,400)
 def test_39_shared_view_context_metadata(self):
  for n in range(6):
   kind='niveaux'+str(n);obj=source(self.actor(),kind)[0];self.assertFalse(obj['territorialDerived'],kind);cols=[c['column_name'] for c in obj['columns']];self.assertEqual(len(cols),len(set(cols)))
  self.assertIn('niveau4Types',references(self.actor(),'niveaux5')['options']);self.assertIn('niveau5Types',references(self.actor(),'niveaux4')['options'])
  response=self.client().get(BASE+'registres/niveaux4',{'take':1});self.status(response);meta=response.json()['meta'];self.assertEqual(meta['filterGroups'],[['StructuresZone','StructuresTypeSite']]);self.assertEqual(meta['filterSources']['StructuresTypeSite'],'niveau5Types')

if __name__=='__main__':
 result=unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(TerritorialAPI));Path('.runtime/territoires-api-tests.json').write_text(json.dumps({'passed':result.wasSuccessful(),'tests':result.testsRun,'failures':len(result.failures),'errors':len(result.errors),'privateDatabase':target.path[1:]}),encoding='utf8');raise SystemExit(0 if result.wasSuccessful() else 1)
