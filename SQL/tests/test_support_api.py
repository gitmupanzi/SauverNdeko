"""Recette Support de bout en bout, uniquement PostgreSQL privé local.

Les utilisateurs, tiers et documents ci-dessous sont fictifs. Chaque scénario
est annulé en fin de test, sauf les deux demandes concurrentes isolées dans une
base dont le nom est obligatoirement sauverndeko_test_*.
"""
import hashlib
import io
import json
import os
import sys
import unittest
import uuid
import zipfile
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from urllib.parse import urlsplit

import psycopg
from psycopg.rows import dict_row

ROOT=Path(__file__).resolve().parents[2]
DSN=os.environ.get('SAUVERNDEKO_TEST_DATABASE_URL','');target=urlsplit(DSN)
if target.hostname not in {'127.0.0.1','localhost'} or not target.path[1:].startswith('sauverndeko_test_'):
    raise RuntimeError('Recette exclusivement PostgreSQL privé sauverndeko_test_*.')
with psycopg.connect(DSN) as guard:
    if not guard.execute('SELECT current_database()').fetchone()[0].startswith('sauverndeko_test_'):raise RuntimeError('Base privée obligatoire.')
sys.path.insert(0,str(ROOT/'backend'))
os.environ.update(DATABASE_URL=DSN,DJANGO_SETTINGS_MODULE='config.settings',SAUVERNDEKO_DB_READ_ONLY='0')
import django;django.setup()
from django.core.files.uploadedfile import SimpleUploadedFile
from django.db import connections, transaction
from django.test import override_settings
from rest_framework.test import APIClient
from apps.accounts.authentication import Actor
from apps.core import db
from apps.core.field_references import reference_context,reference_options,save as reference_save
from apps.support import portal

BASE='/api/support/'


class SupportAPI(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.overrides=override_settings(ALLOWED_HOSTS=['testserver']);cls.overrides.enable()
        cls.sql=psycopg.connect(DSN,autocommit=True,row_factory=dict_row)
        cls.entities=[cls.sql.execute('INSERT INTO systeme."T_Entite"("NomEntite","EmailEntite","ValideEntite") VALUES(%s,%s,true) RETURNING "IdEntite" id',['Support fictif '+uuid.uuid4().hex,uuid.uuid4().hex+'@example.invalid']).fetchone()['id'] for _ in range(2)]
        cls.users=[cls.sql.execute('''INSERT INTO systeme."T_Utilisateurs"("NomUser","PrenomUser","EmailUser","MotdepasseUser","ValideUser","SexeUser","Is_Admin","Is_staff","IdEntiteFk")
            VALUES('Support','Fictif',%s,'inutilisable',true,'M',%s,true,%s) RETURNING *''',[uuid.uuid4().hex+'@example.invalid',index==0,entity]).fetchone() for index,entity in enumerate([cls.entities[0],cls.entities[0],cls.entities[1]])]
        cls.refs=portal.references(cls.actor())
        cls.tiers_type=reference_options(cls.actor(),'logistique','T_Client','ID_TypeClientFk')[0]['id']

    @classmethod
    def tearDownClass(cls):cls.sql.close();cls.overrides.disable()

    @classmethod
    def actor(cls,index=0,*,manage=True,read=True,export=True,all_entities=False,entity_index=None,asset_access=True,asset_export=True):
        actor=Actor(dict(cls.users[index]));entity=cls.entities[entity_index if entity_index is not None else 1 if index==2 else 0]
        if actor.global_admin and not all_entities:actor._context_entity=entity
        rights = {'canRead': read, 'canManage': manage, 'canExport': export, 'reason': 'MODULE_ROLE_FORBIDDEN'}
        actor._module_access = {
            'modules': {module: rights for module in ('support', 'administration', 'logistique', 'referentiels')},
            'tabs': {'logistique': {'immobilisations': {
                'canRead': read and asset_access,
                'canManage': manage and asset_access,
                'canExport': export and asset_access and asset_export,
            }}},
        }
        return actor

    @classmethod
    def client(cls,index=0,**rights):
        client=APIClient();client.force_authenticate(cls.actor(index,**rights));return client

    def setUp(self):
        self.tx=None if self._testMethodName in {'test_25_concurrent_create_replay','test_26_concurrent_conflicting_update'} else transaction.atomic()
        if self.tx:self.tx.__enter__()

    def tearDown(self):
        if self.tx:transaction.set_rollback(True);self.tx.__exit__(None,None,None)

    def status(self,response,code=200):
        self.assertEqual(response.status_code,code,getattr(response,'data',response.content[:100] if not getattr(response,'streaming',False) else 'binaire'))
        return response.data.get('data') if hasattr(response,'data') else None

    def body(self,**changes):
        data={**self.refs['defaults'],'Objet':'Assistance fictive '+uuid.uuid4().hex,'Description':'Incident fictif à traiter pour la recette privée.','requestId':str(uuid.uuid4())}
        data.update(changes);return data

    def create(self,index=0,**changes):return self.status(self.client(index).post(BASE+'tickets',self.body(**changes),format='json'),201)
    def get_detail(self,row,index=0,**rights):return self.status(self.client(index,**rights).get(BASE+'tickets/'+str(row['ID_Support'])))
    def edit(self,row,index=0,**changes):return self.client(index).patch(BASE+'tickets/'+str(row['ID_Support']),{'requestId':str(uuid.uuid4()),'_version':row['_version'],**changes},format='json')
    def action(self,row,action,index=0,**changes):
        result=self.status(self.client(index).post(BASE+'tickets/'+str(row['ID_Support'])+'/actions',{'action':action,'requestId':str(uuid.uuid4()),'_version':row['_version'],**changes},format='json'))
        return result['record']
    def active(self):return self.action(self.create(ID_ResponsableFk=self.users[0]['IdUser']),'start')
    def resolved(self):return self.action(self.active(),'resolve',CauseIdentifiee='Cause de recette',SolutionAppliquee='Solution fictive démontrée.')

    def test_01_context_references_labels_and_entity_selector(self):
        context=self.status(self.client().get(BASE+'contexte'));self.assertTrue(context['canCreate']);self.assertTrue(context['defaults']);self.assertEqual(context['entityId'],self.entities[0])
        for field,value in context['fieldReferences'].items():self.assertIn('categoryIds',value);self.assertIn('categoryLabels',value);self.assertIn('options',value)
        for options in context['references'].values():
            for item in options:
                expected=db.one('SELECT "AbrGenerique" FROM referentiel."T_Generique" WHERE "ID_Generique"=%s',[item['id']])['AbrGenerique']
                self.assertEqual(item['label'],str(expected).strip() if expected and str(expected).strip() else 'Valeur sans abréviation #'+str(item['id']))
        self.assertEqual(len(self.status(self.client(2).get(BASE+'entreprises'))),1)

    def test_02_create_real_fk_number_and_version(self):
        row=self.create();self.assertRegex(row['NumeroSupport'],r'^SUP-\d+$');self.assertEqual(row['StatutCode'],'new');self.assertEqual(row['_version'],'1');self.assertEqual(row['IdEntiteFk'],self.entities[0]);self.assertEqual(row['ID_CreateurFk'],self.users[0]['IdUser']);self.assertNotIn('CircuitSnapshot',row)
        info=self.get_detail(row);self.assertEqual(info['record']['ID_Support'],row['ID_Support']);self.assertTrue(info['history']);self.assertTrue(info['circuitVersion'])

    def test_03_create_replay_and_content_guard(self):
        body=self.body();a=self.status(self.client().post(BASE+'tickets',body,format='json'),201);b=self.status(self.client().post(BASE+'tickets',body,format='json'));self.assertEqual(a,b)
        self.status(self.client().post(BASE+'tickets',{**body,'Objet':'Contenu différent'},format='json'),409)
        self.assertEqual(db.one('SELECT count(*) n FROM support."T_Support" WHERE "ID_Support"=%s',[a['ID_Support']])['n'],1)

    def test_04_edit_optimistic_lock_and_identity_protection(self):
        row=self.create();saved=self.status(self.edit(row,Objet='Objet corrigé'));self.assertEqual(saved['Objet'],'Objet corrigé');self.assertNotEqual(row['_version'],saved['_version'])
        self.status(self.edit(row,Objet='Perdu'),409)
        for field,value in [('NumeroSupport','X'),('IdEntiteFk',self.entities[1]),('ID_StatutFk',self.refs['references']['statuses'][0]['id']),('VersionEnregistrement',99),('Archive',True)]:self.status(self.edit(saved,**{field:value}),422)

    def test_05_responsible_required_before_processing(self):
        row=self.create();self.status(self.client().post(BASE+'tickets/'+str(row['ID_Support'])+'/actions',{'requestId':str(uuid.uuid4()),'_version':row['_version'],'action':'start'},format='json'),422)
        assigned=self.status(self.edit(row,ID_ResponsableFk=self.users[0]['IdUser']));self.assertEqual(self.action(assigned,'start')['StatutCode'],'active')

    def test_06_wait_reason_and_resume(self):
        row=self.active();self.status(self.client().post(BASE+'tickets/'+str(row['ID_Support'])+'/actions',{'requestId':str(uuid.uuid4()),'_version':row['_version'],'action':'pause'},format='json'),422)
        waiting=self.action(row,'pause',motif='Attente d’une preuve.');self.assertEqual(waiting['StatutCode'],'pending');resumed=self.action(waiting,'resume');self.assertEqual(resumed['StatutCode'],'active')

    def test_07_resolution_verification_closure_and_reopen(self):
        row=self.resolved();self.assertEqual(row['StatutCode'],'resolved');self.assertIsNotNone(row['DateResolution'])
        before=self.get_detail(row);self.assertNotIn('close',[item['key'] for item in before['transitions']]);accepted=db.one('SELECT "CircuitSnapshot" FROM support."T_Support" WHERE "ID_Support"=%s',[row['ID_Support']])['CircuitSnapshot']['verification']['accepted']
        verified=self.action(row,'verify',1,ID_ResultatVerificationFk=accepted,CommentaireVerification='Vérification contradictoire conforme.')
        closed=self.action(verified,'close',1);self.assertEqual(closed['StatutCode'],'closed');self.assertIsNotNone(closed['DateCloture']);self.status(self.edit(closed,Objet='Modification interdite'),409)
        reopened=self.action(closed,'reopen',1,motif='Le demandeur signale une récidive.');self.assertEqual(reopened['StatutCode'],'active');self.assertIsNone(reopened['DateCloture']);self.assertEqual(len(self.get_detail(reopened)['resolutions']),1)

    def test_08_no_self_verification_and_invalid_edges(self):
        row=self.resolved();value=db.one('SELECT "CircuitSnapshot" FROM support."T_Support" WHERE "ID_Support"=%s',[row['ID_Support']])['CircuitSnapshot']['verification']['accepted']
        self.status(self.client().post(BASE+'tickets/'+str(row['ID_Support'])+'/actions',{'requestId':str(uuid.uuid4()),'_version':row['_version'],'action':'verify','ID_ResultatVerificationFk':value,'CommentaireVerification':'Auto validation'},format='json'),409)
        self.status(self.client().post(BASE+'tickets/'+str(row['ID_Support'])+'/actions',{'requestId':str(uuid.uuid4()),'_version':row['_version'],'action':'close'},format='json'),409)

    def test_09_rejected_attempt_preserved_then_second_attempt(self):
        row=self.resolved();rejected=db.one('SELECT "CircuitSnapshot" FROM support."T_Support" WHERE "ID_Support"=%s',[row['ID_Support']])['CircuitSnapshot']['verification']['rejected']
        verified=self.action(row,'verify',1,ID_ResultatVerificationFk=rejected,CommentaireVerification='La panne reste présente.');self.assertNotIn('close',[item['key'] for item in self.get_detail(verified)['transitions']])
        reopened=self.action(verified,'reopen',1,motif='Reprise après contrôle non conforme.');second=self.action(reopened,'resolve',CauseIdentifiee='Autre cause',SolutionAppliquee='Autre solution');self.assertEqual(len(self.get_detail(second)['resolutions']),2)

    def test_10_comments_visibility_and_revision(self):
        row=self.active();payload={'requestId':str(uuid.uuid4()),'_version':row['_version'],'Contenu':'Note interne fictive','Visibilite':'interne'}
        updated=self.status(self.client().post(BASE+'tickets/'+str(row['ID_Support'])+'/commentaires',payload,format='json'),201)
        self.assertEqual(len(updated['comments']),1);self.assertNotEqual(updated['record']['_version'],row['_version'])
        self.status(self.client().post(BASE+'tickets/'+str(row['ID_Support'])+'/commentaires',payload,format='json'))
        public=self.get_detail(updated['record'],1,manage=False);self.assertEqual(public['comments'],[]);self.assertEqual(public['history'],[])

    def test_11_documents_private_visibility_exact_bytes(self):
        row=self.active();blob=b'%PDF-1.4\nprivate fixture\n%%EOF'
        payload={'requestId':str(uuid.uuid4()),'_version':row['_version'],'Visibilite':'interne','file':SimpleUploadedFile('preuve.pdf',blob,content_type='application/pdf')}
        updated=self.status(self.client().post(BASE+'tickets/'+str(row['ID_Support'])+'/documents',payload,format='multipart'),201)
        piece=updated['documents'][0]['ID_PieceFk'];url=BASE+'tickets/'+str(row['ID_Support'])+'/documents/'+str(piece)+'/download'
        downloaded=self.client().get(url,HTTP_ACCEPT='application/pdf');self.assertEqual(downloaded.status_code,200);self.assertEqual(downloaded.content,blob);self.assertEqual(set(part.strip() for part in downloaded['Cache-Control'].split(',')),{'private','no-store'})
        self.status(self.client(1,manage=False).get(url),404);self.status(self.client(2).get(url),404)

    def test_12_document_comment_same_parent_visibility_guard(self):
        one=self.active();two=self.active();created=self.status(self.client().post(BASE+'tickets/'+str(one['ID_Support'])+'/commentaires',{'requestId':str(uuid.uuid4()),'_version':one['_version'],'Contenu':'Interne','Visibilite':'interne'},format='json'),201);comment=created['comments'][0]['ID_CommentaireSupport']
        for parent,version,visibility in [(two['ID_Support'],two['_version'],'interne'),(one['ID_Support'],created['record']['_version'],'public')]:
            response=self.client().post(BASE+'tickets/'+str(parent)+'/documents',{'requestId':str(uuid.uuid4()),'_version':version,'Visibilite':visibility,'ID_CommentaireSupportFk':str(comment),'file':SimpleUploadedFile('x.pdf',b'%PDF-1.4\nfixture\n%%EOF',content_type='application/pdf')},format='multipart');self.status(response,422)

    def test_13_invalid_documents_do_not_write(self):
        row=self.active();before=db.one('SELECT count(*) n FROM logistique."T_PieceJustificative"')['n']
        self.status(self.client().post(BASE+'tickets/'+str(row['ID_Support'])+'/documents',{'requestId':str(uuid.uuid4()),'_version':row['_version'],'file':SimpleUploadedFile('script.pdf',b'<script>untrusted</script>',content_type='application/pdf')},format='multipart'),400)
        self.assertEqual(before,db.one('SELECT count(*) n FROM logistique."T_PieceJustificative"')['n'])

    def test_14_isolation_lists_details_links_and_downloads(self):
        one=self.create();two=self.create(2)
        rows=self.status(self.client(2).get(BASE+'tickets'));self.assertNotIn(one['ID_Support'],[row['ID_Support'] for row in rows]);self.assertIn(two['ID_Support'],[row['ID_Support'] for row in rows]);self.status(self.client(2).get(BASE+'tickets/'+str(one['ID_Support'])),404)
        self.status(self.edit(one,ID_ResponsableFk=self.users[2]['IdUser']),422)
        allrows=self.status(self.client(all_entities=True).get(BASE+'tickets'));self.assertIn(one['ID_Support'],[row['ID_Support'] for row in allrows]);self.assertIn(two['ID_Support'],[row['ID_Support'] for row in allrows])

    def test_15_permissions_read_write_export_and_readonly(self):
        self.status(APIClient().get(BASE+'tickets'),401);self.status(self.client(read=False).get(BASE+'tickets'),403)
        self.status(self.client(manage=False).post(BASE+'tickets',self.body(),format='json'),403)
        self.status(self.client(export=False).get(BASE+'tickets/export.xlsx'),403)
        with override_settings(DB_READ_ONLY=True):self.status(self.client().post(BASE+'tickets',self.body(),format='json'),503)
        self.status(self.client(all_entities=True).post(BASE+'tickets',self.body(),format='json'),409)

    def test_16_referencement_dynamic_preserves_old_values(self):
        row=self.create();field='ID_TypeSupportFk';context=reference_context(self.actor(),'support','T_Support',field)
        cat=db.one('INSERT INTO referentiel."T_CategorieGenerique"("NomCategorieGenerique","ValideCategorieGenerique") VALUES(%s,true) RETURNING "ID_CategorieGenerique" id',['Support nouveau fictif '+uuid.uuid4().hex])['id']
        new=db.one('INSERT INTO referentiel."T_Generique"("ID_CategorieGeneriqueFk","NomGenerique","AbrGenerique","ValideGenerique") VALUES(%s,\'Nouveau choix\',\'Nouveau\',true) RETURNING "ID_Generique" id',[cat])['id']
        field_id=db.one('SELECT "ID_ChampReferentiel" id FROM referentiel."T_ChampReferentiel" WHERE "SchemaName"=\'support\' AND "TableName"=\'T_Support\' AND "ColumnName"=%s',[field])['id']
        reference_save(self.actor(),field_id,{'scope':'entity','scopeValue':str(self.entities[0]),'_version':context['_version'],'requestId':str(uuid.uuid4()),'motif':'Recette de famille dynamique','categoryIds':[cat]})
        current=self.status(self.client().get(BASE+'contexte',{'currentId':row['ID_Support']}));self.assertIn(new,[option['id'] for option in current['references']['types']]);self.assertTrue(next(option for option in current['references']['types'] if option['id']==row[field])['incompatible'])
        saved=self.status(self.edit(row,Objet='Correction descriptive sans migration'));self.assertEqual(saved[field],row[field]);self.status(self.client().post(BASE+'tickets',self.body(),format='json'),422)

    def test_17_dashboard_detail_parity(self):
        self.create();self.active();self.resolved();dashboard=self.status(self.client().get(BASE+'tableau-de-bord'))
        for metric,indicator in [('ouverts','ouverts'),('enAttente','attente'),('enRetard','retard'),('resolus','resolus'),('clotures','clotures')]:
            response=self.client().get(BASE+'tickets',{'indicator':indicator});self.status(response);self.assertEqual(response.data['meta']['filteredCount'],dashboard['metrics'][metric])

    def test_18_kanban_counts_and_no_duplicates(self):
        rows=[self.create() for _ in range(24)];kanban=self.status(self.client().get(BASE+'kanban'));group=next(item for item in kanban['columns'] if item['id']==rows[0]['ID_StatutFk']);self.assertEqual(len(group['rows']),20);self.assertTrue(group['hasMore']);self.assertGreaterEqual(group['count'],24)
        self.assertEqual(len({row['ID_Support'] for row in group['rows']}),20)

    def test_19_closed_criteria_and_pagination(self):
        for args in [{'sortBy':'Objet;DELETE'},{'sortDir':'sideways'},{'filters':'[]'},{'filters':'{"CircuitSnapshot":"x"}'},{'dateFrom':'impossible'},{'indicator':'autre'},{'archive':'maybe'}]:self.status(self.client().get(BASE+'tickets',args),400)
        for _ in range(3):self.create()
        first=self.client().get(BASE+'tickets',{'take':1,'skip':0});second=self.client().get(BASE+'tickets',{'take':1,'skip':1});self.status(first);self.status(second);self.assertEqual(len(first.data['data']),1);self.assertNotEqual(first.data['data'][0]['ID_Support'],second.data['data'][0]['ID_Support'])

    def test_20_exports_filtered_selected_and_native_xlsx(self):
        one=self.create(Objet='001 = formule');self.create();args={'selection':json.dumps([one['ID_Support']]),'columns':json.dumps(['NumeroSupport','Objet','DateCreation'])}
        response=self.client().get(BASE+'tickets/export.xlsx',args,HTTP_ACCEPT=XLSX);self.assertEqual(response.status_code,200,getattr(response,'data',None));blob=b''.join(response.streaming_content);self.assertTrue(zipfile.is_zipfile(io.BytesIO(blob)));self.assertEqual(response['X-Export-Row-Count'],'1')
        response=self.client().get(BASE+'tickets/export.csv',args,HTTP_ACCEPT='text/csv');self.assertEqual(response.status_code,200);self.assertTrue(b''.join(response.streaming_content).startswith(b'\xef\xbb\xbf'));self.assertEqual(response['X-Export-Row-Count'],'1')

    def test_21_resolution_errors_roll_back_tentative_and_audit(self):
        row=self.active();before=db.one('SELECT count(*) n FROM support."T_ResolutionSupport"')['n'];audit=db.one('SELECT count(*) n FROM systeme."T_Audit_Log"')['n']
        self.status(self.client().post(BASE+'tickets/'+str(row['ID_Support'])+'/actions',{'requestId':str(uuid.uuid4()),'_version':row['_version'],'action':'resolve','CauseIdentifiee':'x','SolutionAppliquee':''},format='json'),422)
        self.assertEqual(before,db.one('SELECT count(*) n FROM support."T_ResolutionSupport"')['n']);self.assertEqual(audit,db.one('SELECT count(*) n FROM systeme."T_Audit_Log"')['n'])

    def test_22_verified_archive_restore_and_replay(self):
        row=self.resolved();accepted=db.one('SELECT "CircuitSnapshot" FROM support."T_Support" WHERE "ID_Support"=%s',[row['ID_Support']])['CircuitSnapshot']['verification']['accepted'];verified=self.action(row,'verify',1,ID_ResultatVerificationFk=accepted,CommentaireVerification='Conforme');closed=self.action(verified,'close',1);archived=self.action(closed,'archive',1,motif='Dossier terminé')
        self.assertTrue(archived['Archive']);self.assertNotIn(row['ID_Support'],[item['ID_Support'] for item in self.status(self.client().get(BASE+'tickets'))]);self.assertIn(row['ID_Support'],[item['ID_Support'] for item in self.status(self.client().get(BASE+'tickets',{'archive':'true'}))]);restored=self.action(archived,'restore',1,motif='Reprise de consultation');self.assertFalse(restored['Archive']);self.assertEqual(restored['StatutCode'],'closed')
        closed_detail=self.get_detail(restored);self.assertFalse(closed_detail['canEdit']);self.assertFalse(closed_detail['canComment']);self.assertFalse(closed_detail['canUpload']);self.assertTrue(next(action for action in closed_detail['transitions'] if action['key']=='archive')['requiresReason'])

    def test_23_existing_circuit_not_silently_changed(self):
        row=self.active();snapshot=db.one('SELECT "CircuitSnapshot" FROM support."T_Support" WHERE "ID_Support"=%s',[row['ID_Support']])['CircuitSnapshot']
        setting=db.one('SELECT * FROM systeme."T_Admin_UI_Setting" WHERE "SettingKey"=\'support.workflow\' AND "SettingScope"=\'global\'');config={**setting['SettingValueJson'],'version':setting['SettingValueJson']['version']+1}
        from apps.core.repository import set_admin_actor
        set_admin_actor(self.actor());db.query('UPDATE systeme."T_Admin_UI_Setting" SET "SettingValueJson"=%s::jsonb WHERE "IdAdminUISetting"=%s',[json.dumps(config),setting['IdAdminUISetting']])
        resolved=self.action(row,'resolve',CauseIdentifiee='Cause',SolutionAppliquee='Solution');self.assertEqual(self.get_detail(resolved)['circuitVersion'],snapshot['version']);fresh=self.create();self.assertEqual(self.get_detail(fresh)['circuitVersion'],config['version'])

    def test_24_dates_and_empty_fields_validation(self):
        for changes in [{'Objet':' '},{'Description':' '},{'Description':'x'*20001},{'DateEcheance':'2026-02-31'},{'ID_ResponsableFk':True},{'Objet':'x'*201},{'Description':'\x00secret'}]:self.status(self.client().post(BASE+'tickets',self.body(**changes),format='json'),422)
        row=self.create(DateEcheance='2020-01-01T01:00:00+01:00');self.assertTrue(row['EnRetard']);response=self.client().get(BASE+'tickets',{'dateFrom':'2026-10-30','dateTo':'2026-10-30'});self.status(response)

    def test_25_concurrent_create_replay(self):
        body=self.body()
        def send(_):
            try:
                response=self.client().post(BASE+'tickets',body,format='json');return response.status_code,response.data
            finally:connections.close_all()
        with ThreadPoolExecutor(max_workers=2) as executor:results=list(executor.map(send,range(2)))
        self.assertEqual(sorted(status for status,_ in results),[200,201],results);self.assertEqual(results[0][1]['data']['ID_Support'],results[1][1]['data']['ID_Support'])

    def test_26_concurrent_conflicting_update(self):
        row=self.create()
        def send(index):
            try:
                response=self.edit(row,Objet='Concurrence '+str(index));return response.status_code
            finally:connections.close_all()
        with ThreadPoolExecutor(max_workers=2) as executor:results=list(executor.map(send,range(2)))
        self.assertEqual(sorted(results),[200,409])

    def test_27_readonly_profiles_queries(self):
        with transaction.atomic():
            db.query('SET TRANSACTION READ ONLY');self.assertEqual(db.one('SHOW transaction_read_only')['transaction_read_only'],'on')
            for path in ('contexte','tableau-de-bord','kanban','tickets','entreprises'):self.status(self.client().get(BASE+path))

    def test_28_ordinary_readers_cannot_promote_write(self):
        actor=self.actor(1);actor.row['Is_staff']=False
        client=APIClient();client.force_authenticate(actor)
        context=self.status(client.get(BASE+'contexte'));self.assertFalse(context['canCreate']);self.status(client.post(BASE+'tickets',self.body(),format='json'),403)

    def test_29_closed_methods_are_rejected_without_server_error(self):
        row=self.create()
        self.status(self.client().post(BASE+'tickets/'+str(row['ID_Support']),{},format='json'),405)
        self.status(self.client().patch(BASE+'tickets',{},format='json'),405)
        self.status(self.client().delete(BASE+'tickets/'+str(row['ID_Support']),{},format='json'),405)

    def test_30_exact_filters_null_and_kanban_zero_labels(self):
        row=self.create();response=self.client().get(BASE+'tickets',{'filters':json.dumps({'ID_ResponsableFk':None})});found=self.status(response);self.assertIn(row['ID_Support'],[item['ID_Support'] for item in found])
        empty=self.status(self.client().get(BASE+'kanban',{'q':uuid.uuid4().hex}));self.assertTrue(empty['columns']);self.assertTrue(all(item['count']==0 for item in empty['columns']))
        for item in empty['columns']:
            abbreviation=db.one('SELECT "AbrGenerique" AS abbr FROM referentiel."T_Generique" WHERE "ID_Generique"=%s',[item['id']])['abbr']
            self.assertEqual(item['label'],str(abbreviation).strip() if abbreviation and str(abbreviation).strip() else 'Valeur sans abréviation #'+str(item['id']))

    def test_31_comment_mutation_replay_and_global_context_safety(self):
        row=self.active();body={'requestId':str(uuid.uuid4()),'_version':row['_version'],'Contenu':'Échange public fictif','Visibilite':'public'}
        first=self.status(self.client().post(BASE+'tickets/'+str(row['ID_Support'])+'/commentaires',body,format='json'),201)
        again=self.status(self.client().post(BASE+'tickets/'+str(row['ID_Support'])+'/commentaires',body,format='json'));self.assertEqual(len(first['comments']),len(again['comments']))
        self.status(self.client().post(BASE+'tickets/'+str(row['ID_Support'])+'/commentaires',{**body,'Contenu':'Autre texte'},format='json'),409)
        global_detail=self.status(self.client(all_entities=True).get(BASE+'tickets/'+str(row['ID_Support'])));self.assertFalse(global_detail['canManage']);self.assertFalse(global_detail['context']['canManage']);self.assertTrue(global_detail['context']['users'])

    def test_32_mutation_actor_and_audit_same_transaction(self):
        row=self.create();audit=db.query('SELECT "NewData","IdEntiteFk" FROM systeme."T_Audit_Log" WHERE "TableName"=\'support.T_Support\' AND "NewData"->>\'ID_Support\'=%s',[str(row['ID_Support'])]);self.assertEqual(len(audit),1);self.assertEqual(audit[0]['NewData']['_actor']['IdUser'],self.users[0]['IdUser']);self.assertEqual(audit[0]['IdEntiteFk'],self.entities[0]);self.assertTrue(audit[0]['NewData']['requestId'])
        detail=self.get_detail(row);self.assertTrue(all('payloadHash' not in event.get('NouvellesValeurs',{}) for event in detail['history']))
        self.assertNotIn('NbCommentaires',detail['record']);self.assertNotIn('NbDocuments',detail['record']);self.assertNotIn('NbCommentaires',{column['column_name'] for column in portal.table_source()['columns']})

    def test_33_generic_system_audits_do_not_bypass_internal_visibility(self):
        row=self.active();self.status(self.client().post(BASE+'tickets/'+str(row['ID_Support'])+'/commentaires',{'requestId':str(uuid.uuid4()),'_version':row['_version'],'Contenu':'Note interne fictive privée','Visibilite':'interne'},format='json'),201)
        local=self.client(1,manage=False)
        for path in ('/api/models/T_Audit_Log','/api/systeme/audit-logs','/api/views/systeme/V_Audit_log'):
            with self.subTest(path=path):self.assertEqual(local.get(path).status_code,403)
        for extension in ('xlsx','csv'):
            self.assertEqual(local.get('/api/systeme/administration/registres/audit/export.'+extension).status_code,403)
        listing=self.status(local.get('/api/views'));self.assertNotIn(('systeme','V_Audit_log'),[(item['schema'],item['name']) for item in listing])
        # La plateforme garde son audit commun ; le traitement Support fournit
        # l'historique métier filtré aux seules personnes habilitées du dossier.
        self.status(self.client(all_entities=True).get('/api/systeme/audit-logs'))
        self.assertTrue(self.get_detail(row,1)['history']);self.assertFalse(self.get_detail(row,1,manage=False)['history'])


    def test_asset_tab_restriction_covers_support_links(self):
        asset_base = '/api/logistique/immobilisations'
        references = self.status(self.client().get(asset_base + '/references'))
        name = 'Immobilisation confidentielle ' + uuid.uuid4().hex
        asset = self.status(self.client().post(asset_base, {
            'NomImmobilisation': name, 'ID_CategorieFk': references['types'][0]['id'],
            'DateEntree': '2026-10-28T13:35:00+01:00', 'Quantite': '1', 'SuiviIndividuel': True,
            'requestId': str(uuid.uuid4()), 'motif': 'Recette de liaison',
        }, format='json'), 201)
        asset_id = asset['ID_Immobilisation']
        required_fields = {
            field: next(item['id'] for item in self.refs['references'][alias] if not item.get('disabled'))
            for field, alias in (('ID_TypeSupportFk', 'types'), ('ID_PrioriteFk', 'priorities'),
                                 ('ID_CanalOrigineFk', 'channels'))
        }
        row = self.create(ID_ImmobilisationFk=asset_id, **required_fields)
        ticket_url = BASE + 'tickets/' + str(row['ID_Support'])
        authorized = self.get_detail(row, 1)
        self.assertEqual(authorized['record']['Immobilisation'], name)
        self.assertIn(asset_id, [item['id'] for item in authorized['links']['immobilisations']])

        restricted = self.client(1, asset_access=False)
        hidden = self.status(restricted.get(ticket_url))
        self.assertFalse(hidden['canLinkAsset'])
        self.assertEqual(hidden['links']['immobilisations'], [])
        for key in portal.ASSET_COLUMNS:
            self.assertNotIn(key, hidden['record'])
        self.assertTrue(hidden['history'])
        for event in hidden['history']:
            for key in portal.ASSET_COLUMNS:
                self.assertNotIn(key, event['NouvellesValeurs'] or {})
            self.assertNotIn(portal.ASSET_FIELD, [change['field'] for change in event['Changements']])

        found = self.status(restricted.get(BASE+'tickets', {'q': row['NumeroSupport']}))
        self.assertEqual([item['ID_Support'] for item in found], [row['ID_Support']])
        for key in portal.ASSET_COLUMNS:
            self.assertNotIn(key, found[0])
        kanban = self.status(restricted.get(BASE+'kanban', {'q': row['NumeroSupport']}))
        cards = [item for group in kanban['columns'] for item in group['rows']]
        self.assertEqual([item['ID_Support'] for item in cards], [row['ID_Support']])
        for key in portal.ASSET_COLUMNS:
            self.assertNotIn(key, cards[0])
        asset_filter = {'filters': json.dumps({portal.ASSET_FIELD: asset_id})}
        self.status(restricted.get(BASE+'tickets', asset_filter), 403)
        self.status(restricted.get(BASE+'tickets', {'sortBy': 'CodeImmobilisation'}), 403)
        asset_read_only = self.client(1, asset_export=False)
        self.status(asset_read_only.get(BASE+'tickets', asset_filter))
        self.status(asset_read_only.get(BASE+'tickets/export.csv', asset_filter), 403)
        self.status(restricted.get(BASE+'tickets/export.csv', {'columns': json.dumps(['CodeImmobilisation'])}), 400)
        self.status(restricted.post(BASE+'tickets', self.body(ID_ImmobilisationFk=asset_id, **required_fields), format='json'), 403)
        changed = self.status(restricted.patch(ticket_url, {
            'requestId': str(uuid.uuid4()), '_version': row['_version'],
            'Objet': 'Objet modifié depuis Support', 'ID_ImmobilisationFk': None,
        }, format='json'))
        self.assertNotIn(portal.ASSET_FIELD, changed)
        self.assertEqual(self.get_detail(row)['record']['ID_ImmobilisationFk'], asset_id)

    def test_reference_labels_use_abbreviation_and_keep_ids_and_rules(self):
        refs=portal.references(self.actor())
        identifier=refs['references']['categories'][0]['id']
        row=self.create(ID_CategorieSupportFk=identifier)
        db.query('UPDATE referentiel."T_Generique" SET "NomGenerique"=%s,"AbrGenerique"=%s WHERE "ID_Generique"=%s',
                 ['Nom descriptif de recette '+uuid.uuid4().hex,'ABR-'+uuid.uuid4().hex[:8],identifier])
        expected=db.one('SELECT "AbrGenerique" FROM referentiel."T_Generique" WHERE "ID_Generique"=%s',[identifier])['AbrGenerique']
        choices=portal.references(self.actor(),portal.record(self.actor(),row['ID_Support']))['references']['categories']
        self.assertEqual(next(item['label'] for item in choices if item['id']==identifier),expected)
        info=self.get_detail(row)['record'];self.assertEqual(info['ID_CategorieSupportFk'],identifier)
        self.assertEqual(info['CategorieSupport'],expected)
        self.assertEqual(info['StatutCode'],row['StatutCode'])
        db.query('UPDATE referentiel."T_Generique" SET "AbrGenerique"=NULL WHERE "ID_Generique"=%s',[identifier])
        choices=portal.references(self.actor(),portal.record(self.actor(),row['ID_Support']))['references']['categories']
        self.assertEqual(next(item['label'] for item in choices if item['id']==identifier),'Valeur sans abréviation #'+str(identifier))
        self.assertEqual(self.get_detail(row)['record']['CategorieSupport'],'Valeur sans abréviation #'+str(identifier))

XLSX='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
if __name__=='__main__':unittest.main(verbosity=2)
