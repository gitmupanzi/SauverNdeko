"""Coordonnées centralisées N1–N5 : vraies API, uniquement PostgreSQL privé."""
import json
import unittest
import uuid

import test_territoires_api as territorial
from apps.core import db
from apps.core.territorial_contacts import FIELDS, TABLE, BOOLEAN_FIELD
from apps.core.territorial_portal import record, SOURCES

BASE = territorial.BASE


class TerritorialContactsAPI(unittest.TestCase):
    setUpClass = territorial.TerritorialAPI.__dict__['setUpClass']
    tearDownClass = territorial.TerritorialAPI.__dict__['tearDownClass']
    setUp = territorial.TerritorialAPI.setUp
    tearDown = territorial.TerritorialAPI.tearDown
    actor = territorial.TerritorialAPI.actor
    client = territorial.TerritorialAPI.client
    payload = territorial.TerritorialAPI.payload
    status = territorial.TerritorialAPI.status
    create = territorial.TerritorialAPI.create
    chain = territorial.TerritorialAPI.chain

    def path(self, level, pk=None):
        return BASE+'registres/niveaux'+str(level)+(('/'+str(pk)) if pk is not None else '')

    def edit(self, level, row, **changes):
        return self.client().put(self.path(level,row['ID_Niveau_'+str(level)]),
            {'requestId':str(uuid.uuid4()),'_version':row['_version'],**changes},format='json')

    def contacts(self, **changes):
        return {'AdresseTerritoire':'Adresse professionnelle\nBâtiment de recette',
            'TelephoneTerritoire':'+243 000 000 001','TelephoneSecondaireTerritoire':'+243 000 000 002',
            'EmailTerritoire':'contact@example.invalid','SiteWebTerritoire':'https://example.invalid/accueil',
            'InformationsAccueilTerritoire':'Accueil déclaré\nSur rendez-vous',**changes}

    def test_01_create_all_five_levels_and_shared_flat_projection(self):
        chain = [self.create('niveaux0')]
        for level in range(1,6):
            fk='ID_Niveau_'+str(level-1)+'_'+('Fk' if level in {1,4,5} else 'FK')
            body={**self.payload('niveaux'+str(level),(fk,chain[-1]['ID_Niveau_'+str(level-1)])),**self.contacts()}
            row=self.create('niveaux'+str(level),body);chain.append(row)
            for key,value in self.contacts().items():self.assertEqual(row[key],value)
            identifier=row['ID_Niveau_'+str(level)]
            saved=db.one('SELECT * FROM '+TABLE+' WHERE '+db.ident('ID_Niveau_'+str(level)+'Fk')+'=%s',[identifier])
            self.assertEqual(saved['ModifieParUserFk'],self.user['IdUser'])
            self.assertIsNotNone(row['CoordonneesModifieLe'])
            page=self.client().get(self.path(level),{'filters':json.dumps({'ID_Niveau_'+str(level):identifier})})
            self.assertEqual(self.status(page)[0]['TelephoneTerritoire'],self.contacts()['TelephoneTerritoire'])
            labels={col['key']:col['label'] for col in page.json()['meta']['columns']}
            self.assertEqual(labels['TelephoneTerritoire'],'Téléphone principal')
            self.assertEqual(labels['CoordonneesModifieLe'],'Coordonnées mises à jour le')
        self.assertNotIn('AdresseTerritoire',chain[0])

    def test_02_child_update_changes_revision_even_when_parent_does_not_change(self):
        chain=self.chain();row=chain[1];pk=row['ID_Niveau_1']
        before=db.one('SELECT xmin::text revision FROM geolocalisation."T_Niveau_1" WHERE "ID_Niveau_1"=%s',[pk])['revision']
        saved=self.status(self.edit(1,row,TelephoneTerritoire='+243123'))
        after=db.one('SELECT xmin::text revision FROM geolocalisation."T_Niveau_1" WHERE "ID_Niveau_1"=%s',[pk])['revision']
        self.assertEqual(before,after)
        self.assertNotEqual(row['_version'],saved['_version'])
        self.status(self.edit(1,row,TelephoneTerritoire='+243999'),409)
        # Une édition SQL directe dans la même transaction reste détectée par
        # le contenu et l'horodatage, pas seulement par xmin.
        db.query('UPDATE '+TABLE+' SET "TelephoneTerritoire"=%s WHERE "ID_Niveau_1Fk"=%s',['+243456',pk])
        self.status(self.edit(1,saved,TelephoneTerritoire='+243789'),409)
        self.assertEqual(record(self.actor(),'niveaux1',pk)['TelephoneTerritoire'],'+243456')

    def test_03_omitted_fields_are_preserved_and_explicit_blanks_clear(self):
        row=self.chain()[2];saved=self.status(self.edit(2,row,**self.contacts()))
        changed=self.status(self.edit(2,saved,NomNiveau_2='Territoire renommé '+uuid.uuid4().hex))
        self.assertEqual(changed['EmailTerritoire'],self.contacts()['EmailTerritoire'])
        cleared=self.status(self.edit(2,changed,**{key:False if key==BOOLEAN_FIELD else '' for key in FIELDS}))
        self.assertTrue(all(cleared[key] is None for key in FIELDS if key!=BOOLEAN_FIELD))
        self.assertIs(cleared[BOOLEAN_FIELD],False)
        self.assertIsNone(cleared['CoordonneesModifieLe'])
        self.assertEqual(db.one('SELECT count(*) n FROM '+TABLE+' WHERE "ID_Niveau_2Fk"=%s',[row['ID_Niveau_2']])['n'],0)

    def test_04_validation_is_per_field_and_does_not_mutate_parent(self):
        row=self.chain()[3];original=row['NomNiveau_3']
        for fields in ({'EmailTerritoire':'invalide'},{'SiteWebTerritoire':'javascript:alert(1)'},
            {'SiteWebTerritoire':'https://secret:password@example.invalid'}, {'TelephoneTerritoire':'x'*51},
            {'AdresseTerritoire':'x'*2001},{'InformationsAccueilTerritoire':'x'*3001},
            {'TelephoneTerritoire':'a\nb'},{'AdresseTerritoire':123},{'EmailTerritoire':['test']}):
            response=self.edit(3,row,NomNiveau_3='Ne doit pas être sauvé',**fields)
            self.status(response,422)
            self.assertEqual(response.json()['error']['code'],'TERRITORIAL_CONTACTS_VALIDATION')
        self.assertEqual(record(self.actor(),'niveaux3',row['ID_Niveau_3'])['NomNiveau_3'],original)
        self.status(self.edit(3,row,CoordonneesModifieLe='2020-01-01'),422)

    def test_05_global_permissions_and_generic_child_writes_are_closed(self):
        row=self.chain()[4];path=self.path(4,row['ID_Niveau_4'])
        self.status(self.client(global_admin=False).get(path))
        self.status(self.client(global_admin=False).put(path,{'requestId':str(uuid.uuid4()),'_version':row['_version'],'EmailTerritoire':'contact@example.invalid'},format='json'),403)
        self.status(self.client(manage=False).put(path,{'requestId':str(uuid.uuid4()),'_version':row['_version'],'TelephoneTerritoire':'123'},format='json'),403)
        response=self.client().post('/api/models/T_CoordonneesTerritoire',{'ID_Niveau_4Fk':row['ID_Niveau_4'],'TelephoneTerritoire':'123'},format='json')
        self.status(response,405)
        self.assertEqual(response.json()['error']['code'],'DEDICATED_TERRITORIAL_PROFILE_REQUIRED')
        self.status(self.client().post(self.path(0),{**self.payload('niveaux0'),'TelephoneTerritoire':'123'},format='json'),422)

    def test_06_batch_keeps_one_atomic_transaction_and_targeted_errors(self):
        country=self.create('niveaux0');tag=uuid.uuid4().hex
        good,bad=str(uuid.uuid4()),str(uuid.uuid4())
        body={'requestId':str(uuid.uuid4()),'header':{'ID_Niveau_0_Fk':country['ID_Niveau_0']},
            'rows':[{'rowId':good,'NomNiveau_1':'Batch A '+tag,**self.contacts()},
                    {'rowId':bad,'NomNiveau_1':'Batch B '+tag,**self.contacts(EmailTerritoire='erreur')}]}
        response=self.client().post(BASE+'registres/niveaux1/panier',body,format='json')
        self.status(response,422)
        self.assertIn('EmailTerritoire',response.json()['error']['details']['rows'][bad])
        self.assertEqual(db.one('SELECT count(*) n FROM geolocalisation."T_Niveau_1" WHERE "NomNiveau_1" LIKE %s',['%'+tag])['n'],0)
        body['rows'][1]['EmailTerritoire']='autre@example.invalid'
        saved=self.status(self.client().post(BASE+'registres/niveaux1/panier',body,format='json'),201)
        self.assertEqual(saved['createdCount'],2)
        self.assertTrue(all(item['record']['CoordonneesModifieLe'] for item in saved['rows']))
        replay=self.client().post(BASE+'registres/niveaux1/panier',body,format='json')
        self.assertEqual(self.status(replay),saved)
        self.assertTrue(replay.json()['meta']['replayed'])
        body['rows'][0]['TelephoneTerritoire']='456'
        self.status(self.client().post(BASE+'registres/niveaux1/panier',body,format='json'),409)

    def test_07_batches_support_all_five_levels_without_parent_duplication(self):
        chain=self.chain()
        for level in range(1,6):
            fk='ID_Niveau_'+str(level-1)+'_'+('Fk' if level in {1,4,5} else 'FK')
            body={'requestId':str(uuid.uuid4()),'header':{fk:chain[level-1]['ID_Niveau_'+str(level-1)]},
                'rows':[{'rowId':str(uuid.uuid4()),'NomNiveau_'+str(level):'Batch contacts '+uuid.uuid4().hex,**self.contacts()}]}
            if level==5:body['header']['ID_Niveau_3_Fk']=chain[3]['ID_Niveau_3']
            saved=self.status(self.client().post(BASE+'registres/niveaux'+str(level)+'/panier',body,format='json'),201)
            self.assertEqual(saved['rows'][0]['record']['EmailTerritoire'],'contact@example.invalid')

    def test_08_leaf_delete_removes_child_and_linked_delete_rolls_back(self):
        chain=self.chain();province=self.status(self.edit(1,chain[1],**self.contacts()))
        response=self.client().delete(self.path(1,province['ID_Niveau_1']),{'requestId':str(uuid.uuid4()),'_version':province['_version']},format='json')
        self.status(response,409)
        self.assertEqual(db.one('SELECT count(*) n FROM '+TABLE+' WHERE "ID_Niveau_1Fk"=%s',[province['ID_Niveau_1']])['n'],1)
        site=self.status(self.edit(5,chain[5],**self.contacts()))
        body={'requestId':str(uuid.uuid4()),'_version':site['_version']}
        self.status(self.client().delete(self.path(5,site['ID_Niveau_5']),body,format='json'))
        self.status(self.client().delete(self.path(5,site['ID_Niveau_5']),body,format='json'))
        self.assertEqual(db.one('SELECT count(*) n FROM '+TABLE+' WHERE "ID_Niveau_5Fk"=%s',[site['ID_Niveau_5']])['n'],0)

    def test_09_child_contacts_search_filter_and_export_catalogue(self):
        row=self.status(self.edit(5,self.chain()[5],**self.contacts(TelephoneTerritoire='uniquephone'+uuid.uuid4().hex)))
        page=self.status(self.client().get(self.path(5),{'q':row['TelephoneTerritoire']}))
        self.assertEqual([item['ID_Niveau_5'] for item in page],[row['ID_Niveau_5']])
        page=self.status(self.client().get(self.path(5),{'filters':json.dumps({'EmailTerritoire':'contact@example.invalid'})}))
        self.assertTrue(any(item['ID_Niveau_5']==row['ID_Niveau_5'] for item in page))
        prefs=self.status(self.client().get('/api/tableaux/territoires.niveaux-cinq/preferences'))
        keys={item['id'] for item in prefs['columns']}
        self.assertTrue(set(FIELDS)<=keys)

    def test_10_read_does_not_create_a_contact_and_replay_does_not_duplicate_audit(self):
        row=self.chain()[1];pk=row['ID_Niveau_1']
        before=db.one('SELECT count(*) n FROM '+TABLE)['n']
        self.status(self.client().get(self.path(1,pk)))
        self.assertEqual(before,db.one('SELECT count(*) n FROM '+TABLE)['n'])
        body={'requestId':str(uuid.uuid4()),'_version':row['_version'],'TelephoneTerritoire':'123'}
        self.status(self.client().put(self.path(1,pk),body,format='json'))
        audit_before=db.one('SELECT count(*) n FROM systeme."T_Audit_Log" WHERE "TableName"=%s',['geolocalisation.T_CoordonneesTerritoire'])['n']
        self.status(self.client().put(self.path(1,pk),body,format='json'))
        self.assertEqual(audit_before,db.one('SELECT count(*) n FROM systeme."T_Audit_Log" WHERE "TableName"=%s',['geolocalisation.T_CoordonneesTerritoire'])['n'])

    def test_11_hours_and_explicit_consent_are_versioned_and_omissions_preserve(self):
        row=self.chain()[5]
        self.assertIs(row[BOOLEAN_FIELD],False)
        saved=self.status(self.edit(5,row,HorairesOuvertureTerritoire='Lundi–vendredi\n08:00–17:00',PublierCoordonneesAnnuaire=True))
        self.assertNotEqual(saved['_version'],row['_version'])
        self.assertIs(saved[BOOLEAN_FIELD],True)
        self.status(self.edit(5,row,PublierCoordonneesAnnuaire=False),409)
        kept=self.status(self.edit(5,saved,InformationsAccueilTerritoire='Sur rendez-vous'))
        self.assertIs(kept[BOOLEAN_FIELD],True)
        self.assertEqual(kept['HorairesOuvertureTerritoire'],saved['HorairesOuvertureTerritoire'])
        for changes in ({BOOLEAN_FIELD:'true'},{BOOLEAN_FIELD:1},{BOOLEAN_FIELD:None},
                        {'HorairesOuvertureTerritoire':'x'*1001},{'HorairesOuvertureTerritoire':'a\x00b'}):
            self.status(self.edit(5,kept,**changes),422)
        unpublished=self.status(self.edit(5,kept,PublierCoordonneesAnnuaire=False))
        self.assertIs(unpublished[BOOLEAN_FIELD],False)
        self.assertEqual(unpublished['HorairesOuvertureTerritoire'],saved['HorairesOuvertureTerritoire'])


if __name__ == '__main__':
    unittest.main(verbosity=2)
