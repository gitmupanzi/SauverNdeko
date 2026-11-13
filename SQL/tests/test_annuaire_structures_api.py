"""Structures : annuaire publié et profils autorisés, sur copie privée uniquement."""
import hashlib
import io
import json
import unittest
import uuid

import test_publication_articles_api as publication
from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import override_settings
from PIL import Image
from rest_framework.test import APIClient
from apps.accounts.authentication import actor_by_id
from apps.core import db
from apps.logistique import entity_documents

BASE = '/api/structures'


class StructuresDirectoryAPI(unittest.TestCase):
    setUpClass = publication.ArticlePublicationAPI.__dict__['setUpClass']
    tearDownClass = publication.ArticlePublicationAPI.__dict__['tearDownClass']
    actor = publication.ArticlePublicationAPI.actor
    client = publication.ArticlePublicationAPI.client
    data = publication.ArticlePublicationAPI.data
    body = publication.ArticlePublicationAPI.body
    create = publication.ArticlePublicationAPI.create
    stock_proof = publication.ArticlePublicationAPI.stock_proof
    company_body = publication.ArticlePublicationAPI.company_body

    def setUp(self):
        publication.ArticlePublicationAPI.setUp(self)
        self.typ = self.connection.execute('''SELECT g."ID_Generique" id FROM referentiel."T_Generique" g
            WHERE g."ID_CategorieGeneriqueFk"=ANY(referentiel.fn_categories_champ('systeme','T_Entite','IdTypeEntiteFk',NULL))
            AND g."NomGenerique"='Pharmacie' AND g."ValideGenerique" IS TRUE LIMIT 1''').fetchone()['id']

    def publish(self, index=0, **changes):
        body = self.company_body(index, VisibleAnnuaireEntite=True, PresentationPubliqueEntite='Présentation publique ' + self.tag, **changes)
        return self.data(self.client(index).put(f'/api/systeme/entites/{self.entities[index]}', body, format='json'))

    def listing(self, **params):
        return self.data(self.client(local=True).get(BASE+'/annuaire', {'q': self.tag, **params}))

    def private_body(self, index=0, **changes):
        row = self.data(self.client(index, local=True).get(BASE+'/profils/'+str(self.entities[index])))
        return {**{key: row.get(key) for key in entity_documents.FIELDS | entity_documents.ADMIN_FIELDS},
                'IdEntite': self.entities[index], '_version': row['_version'], 'motif': 'Recette de profil structure',
                'requestId': str(uuid.uuid4()), **changes}

    def test_01_publication_defaults_and_legacy_are_explicit(self):
        defaults = self.data(self.client().get('/api/systeme/entites/identite-defaut'))
        self.assertIs(defaults['VisibleAnnuaireEntite'], False)
        self.assertIsNone(defaults['PresentationPubliqueEntite'])
        self.assertEqual(self.listing()['total'], 0)
        self.publish(IdTypeEntiteFk=self.typ)
        result = self.listing()
        self.assertEqual(result['total'], 1)
        self.assertEqual(result['rows'][0]['type'], 'Pharmacie')
        old = self.data(self.client(local=True).get('/api/public/pharmacies', {'q': self.tag}))
        # La compatibilité pharmacies lit désormais la pyramide sanitaire ;
        # une entreprise publiée n'est jamais convertie en territoire.
        self.assertEqual(old, [])
        self.connection.execute('UPDATE systeme."T_Entite" SET "ValideEntite"=false WHERE "IdEntite"=%s', [self.entities[0]])
        self.assertEqual(self.data(self.client().get(BASE+'/annuaire', {'q': self.tag}))['total'], 0)

    def test_13_contact_type_uses_abbreviation_with_same_reference(self):
        self.publish(IdTypeEntiteFk=self.typ)
        self.connection.execute(
            """INSERT INTO systeme."T_LicenceModule" ("IdLicenceFk","CodeModule","Actif")
            SELECT "IdLicence",'discussions',true FROM systeme."T_Licence" WHERE "IdEntiteFk"=%s
            ON CONFLICT DO NOTHING""",
            [self.entities[1]],
        )
        original = self.connection.execute('SELECT "NomGenerique","AbrGenerique" FROM referentiel."T_Generique" WHERE "ID_Generique"=%s', [self.typ]).fetchone()
        try:
            self.connection.execute('UPDATE referentiel."T_Generique" SET "NomGenerique"=%s,"AbrGenerique"=%s WHERE "ID_Generique"=%s',
                ['Nom descriptif distinct '+self.tag, 'Type affiché '+self.tag, self.typ])
            path='/api/public/chat/context'
            params={'type':'structure','id':self.entities[0]}
            target=self.data(self.client(1, local=True).get(path,params))['target']
            self.assertEqual(target['specialty'],'Type affiché '+self.tag)
            self.assertEqual(target['id'],self.entities[0])
            self.connection.execute('UPDATE referentiel."T_Generique" SET "AbrGenerique"=NULL WHERE "ID_Generique"=%s',[self.typ])
            target=self.data(self.client(1, local=True).get(path,params))['target']
            self.assertEqual(target['specialty'],'Valeur sans abréviation #'+str(self.typ))
            row=self.connection.execute('SELECT "IdTypeEntiteFk" FROM systeme."T_Entite" WHERE "IdEntite"=%s',[self.entities[0]]).fetchone()
            self.assertEqual(row['IdTypeEntiteFk'],self.typ)
        finally:
            self.connection.execute('UPDATE referentiel."T_Generique" SET "NomGenerique"=%s,"AbrGenerique"=%s WHERE "ID_Generique"=%s',
                [original['NomGenerique'], original['AbrGenerique'], self.typ])

    def test_02_safe_projection_and_declared_locations_only(self):
        self.publish(IdTypeEntiteFk=self.typ, IdentifiantsLegauxEntite=[{'libelle':'RCCM','valeur':'SECRET-'+self.tag}],
                     MentionDocumentaireEntite='INTERNE-'+self.tag)
        self.connection.execute('''INSERT INTO systeme."T_Entite_Localisation"
            ("IdEntiteFk","AdresseDetaillee","Latitude","Longitude") VALUES(%s,%s,-4.3,15.3)''',
            [self.entities[0], 'Lieu déclaré '+self.tag])
        result = self.data(self.client(1, local=True).get(BASE+'/annuaire/'+str(self.entities[0])))
        self.assertEqual(set(result['record']), {'id','name','typeId','type','address','phone','website','summary','logoUrl'})
        self.assertEqual(result['locations'], [{'label':'Lieu déclaré '+self.tag,'address':'Lieu déclaré '+self.tag,'zone':None,'area':None,'site':None}])
        encoded = json.dumps(result)
        for private in ('SECRET-','INTERNE-','EmailEntite','Latitude','Longitude','LogoEntite','Motdepasse','IdUser'):
            self.assertNotIn(private, encoded)
        self.assertEqual(self.listing(q='SECRET-'+self.tag)['total'], 0)

    def test_03_exhaustive_pagination_search_filters_and_sort(self):
        identifiers = []
        for number in range(107):
            identifiers.append(self.connection.execute('''INSERT INTO systeme."T_Entite"
                ("NomEntite","EmailEntite","ValideEntite","VisibleAnnuaireEntite","IdTypeEntiteFk","AdresseEntite")
                VALUES(%s,%s,true,true,%s,'Équateur déclaré') RETURNING "IdEntite" id''',
                [self.tag+'-visible-'+str(number).zfill(3), self.tag+str(number)+'@example.invalid', self.typ]).fetchone()['id'])
        all_ids = []
        for offset in range(0, 125, 25):
            page = self.listing(take=25, skip=offset)
            self.assertEqual(page['total'], 107)
            all_ids.extend(row['id'] for row in page['rows'])
        self.assertEqual(all_ids, identifiers)
        self.assertEqual(self.listing(skip=107)['rows'], [])
        self.assertEqual(self.listing(typeId=self.typ)['total'], 107)
        self.assertEqual(self.listing(locality='ÉQUATEUR')['total'], 107)
        self.assertEqual(self.listing(sortDir='desc', take=1)['rows'][0]['id'], identifiers[-1])
        self.assertEqual(self.listing(q="' OR true --")['total'], 0)
        self.assertEqual(self.listing(q=self.tag+'%')['total'], 0)
        for query in ({'take':0},{'take':101},{'skip':-1},{'sortBy':'price'},{'sortDir':'asc;DROP'},{'typeId':'1 OR 1=1'},{'locality':'x'*256},{'unknown':1}):
            self.data(self.client().get(BASE+'/annuaire', query), 400)
        self.data(self.client().get(BASE+'/annuaire?q=a&q=b'), 400)

    def test_04_profile_management_needs_structures_only_and_owner(self):
        # Le registre Structures est inclus, même sans module commercial activé.
        licence = self.connection.execute('SELECT "IdLicence" id FROM systeme."T_Licence" WHERE "IdEntiteFk"=%s', [self.entities[1]]).fetchone()['id']
        self.connection.execute('DELETE FROM systeme."T_LicenceModule" WHERE "IdLicenceFk"=%s', [licence])
        context = self.data(self.client(1, local=True).get(BASE+'/contexte'))
        self.assertTrue(context['canReadRegistry'])
        self.assertTrue(context['canManage'])
        row = self.data(self.client(1, local=True).get(BASE+'/profils/'+str(self.entities[1])))
        self.assertFalse(row['canManageEntity'])
        body = self.private_body(1, VisibleAnnuaireEntite=True)
        self.data(self.client(1, local=True).put(BASE+'/profils/'+str(self.entities[1]), body, format='json'))
        self.data(self.client(1, local=True).get(BASE+'/profils/'+str(self.entities[0])), 404)
        listing = self.data(self.client(1, local=True).get(BASE+'/profils'))
        self.assertEqual([item['id'] for item in listing['rows']], [self.entities[1]])
        self.data(self.client(1, local=True).post(BASE+'/profils', {}, format='json'), 405)
        self.assertTrue(self.data(self.client(2, local=True).get(BASE+'/contexte'))['canManage'])

    def test_05_reader_permissions_and_global_selection(self):
        self.connection.execute('UPDATE systeme."T_Utilisateurs" SET "Is_staff"=false WHERE "IdUser"=%s', [self.locals[0]])
        context = self.data(self.client(local=True).get(BASE+'/contexte'))
        self.assertFalse(context['canReadRegistry'])
        for path in ('/profils','/entreprises','/profils/'+str(self.entities[0])):
            self.data(self.client(local=True).get(BASE+path), 403)
        self.data(self.client(local=True).get(BASE+'/annuaire'))
        other = self.data(self.client(all_entities=True).get(BASE+'/profils/'+str(self.entities[1])))
        self.assertFalse(other['canConfigure'])
        body = self.company_body(1, VisibleAnnuaireEntite=True)
        self.data(self.client(all_entities=True).put(BASE+'/profils/'+str(self.entities[1]), body, format='json'), 409)
        self.data(self.client(0).put(BASE+'/profils/'+str(self.entities[1]), body, format='json'), 403)

    def test_06_profile_validation_version_replay_and_old_forms(self):
        path = BASE+'/profils/'+str(self.entities[0])
        body = self.private_body(VisibleAnnuaireEntite=True, PresentationPubliqueEntite='<b>Texte sans interprétation</b>')
        saved = self.data(self.client(local=True).put(path, body, format='json'))
        self.assertTrue(saved['VisibleAnnuaireEntite'])
        self.assertEqual(saved['PresentationPubliqueEntite'], '<b>Texte sans interprétation</b>')
        response = self.client(local=True).put(path, body, format='json')
        self.data(response)
        self.assertTrue(response.json()['meta']['replayed'])
        self.data(self.client(local=True).put(path, {**body,'PresentationPubliqueEntite':'Autre'}, format='json'), 409)
        self.data(self.client(local=True).put(path, {**body,'requestId':str(uuid.uuid4())}, format='json'), 409)
        for changes in ({'VisibleAnnuaireEntite':'true'},{'PresentationPubliqueEntite':'x'*5001},{'PresentationPubliqueEntite':'a\x00b'},{'motif':''}):
            self.data(self.client(local=True).put(path, self.private_body(**changes), format='json'), 400)
        old = self.private_body(NomEntite=self.tag+'-renommee')
        old.pop('VisibleAnnuaireEntite');old.pop('PresentationPubliqueEntite')
        kept = self.data(self.client(local=True).put(path, old, format='json'))
        self.assertTrue(kept['VisibleAnnuaireEntite'])
        self.assertEqual(kept['PresentationPubliqueEntite'], saved['PresentationPubliqueEntite'])
        for changes in ({'IdTypeEntiteFk':self.typ},{'ValideEntite':False}):
            self.data(self.client().put(path, self.company_body(**changes), format='json'), 403)

    def test_07_offers_are_owner_bound_and_independently_published(self):
        first = self.create(VisibleCatalogue=True)
        self.create(VisibleCatalogue=False)
        self.create(1, VisibleCatalogue=True)
        proof = self.stock_proof(first['ID_Article'])
        self.publish()
        result = self.data(self.client(local=True).get(BASE+'/annuaire/'+str(self.entities[0])+'/offres', {'q':self.tag}))
        self.assertEqual(result['total'], 1)
        self.assertEqual(result['rows'][0]['ID_Article'], first['ID_Article'])
        self.assertNotIn('PUArticle',result['rows'][0])
        self.data(self.client().get(BASE+'/annuaire/'+str(self.entities[0])+'/offres', {'companyId':self.entities[1]}), 400)
        self.assertEqual(proof, self.stock_proof(first['ID_Article']))
        self.connection.execute('UPDATE systeme."T_Entite" SET "VisibleAnnuaireEntite"=false WHERE "IdEntite"=%s', [self.entities[0]])
        self.data(self.client(local=True).get(BASE+'/annuaire/'+str(self.entities[0])+'/offres'), 404)
        self.data(self.client(local=True).get('/api/produits/offres/'+str(first['ID_Article'])))

    def test_08_related_module_denial_is_not_a_fake_empty_list(self):
        self.publish()
        actor = self.actor(1, local=True)
        from apps.core.module_access import access_snapshot
        rights = access_snapshot(actor)['modules']
        for key in ('produits', 'professionnels'):
            rights[key].update(canRead=False, reason='MODULE_ROLE_FORBIDDEN')
        client = APIClient()
        client.force_authenticate(actor)
        result = self.data(client.get(BASE+'/annuaire/'+str(self.entities[0])))
        self.assertFalse(result['canReadProducts']);self.assertFalse(result['canReadProfessionals'])
        for section in ('offres','professionnels'):
            response = client.get(BASE+'/annuaire/'+str(self.entities[0])+'/'+section)
            self.data(response,403)
            self.assertIsNone(response.json()['data'])

    def test_09_logo_bytes_require_publication_and_appropriate_rights(self):
        stream = io.BytesIO();Image.new('RGB',(12,8),(20,90,120)).save(stream,format='PNG')
        body = self.private_body(VisibleAnnuaireEntite=True,logoAction='replace')
        response = self.client(local=True).put(BASE+'/profils/'+str(self.entities[0]),
            {'payload':json.dumps(body), 'logo':SimpleUploadedFile('logo.png',stream.getvalue(),content_type='image/png')},format='multipart')
        self.data(response)
        path = BASE+'/annuaire/'+str(self.entities[0])+'/logo'
        response = self.client(1,local=True).get(path,HTTP_ACCEPT='image/png')
        self.assertEqual(response.status_code,200)
        self.assertEqual(response['Content-Type'],'image/png')
        self.assertIn('no-store',response['Cache-Control'])
        self.assertEqual(Image.open(io.BytesIO(response.content)).size,(12,8))
        digest = self.connection.execute('SELECT "LogoSha256Entite" digest FROM systeme."T_Entite" WHERE "IdEntite"=%s',[self.entities[0]]).fetchone()['digest']
        self.assertEqual(hashlib.sha256(response.content).hexdigest(),digest)
        self.data(APIClient().get(path),401)
        self.data(self.client().get(path,{'v':'broken'}),400)
        self.connection.execute('UPDATE systeme."T_Entite" SET "VisibleAnnuaireEntite"=false WHERE "IdEntite"=%s',[self.entities[0]])
        self.data(self.client().get(path),404)
        self.assertEqual(self.client(local=True).get(BASE+'/profils/'+str(self.entities[0])+'/logo',HTTP_ACCEPT='image/png').status_code,200)
        self.data(self.client(1,local=True).get(BASE+'/profils/'+str(self.entities[0])+'/logo'),404)

    def test_10_contact_publication_guard_and_history_preserved(self):
        target = self.entities[0]
        starter = self.client(1,local=True)
        body = {'type':'structure','targetId':target}
        self.data(starter.post('/api/discussions/start',body,format='json'),403)
        self.connection.execute(
            """INSERT INTO systeme."T_LicenceModule" ("IdLicenceFk","CodeModule","Actif")
               SELECT "IdLicence",'discussions',true FROM systeme."T_Licence" WHERE "IdEntiteFk"=%s""",
            [self.entities[1]],
        )
        starter = self.client(1,local=True)
        self.data(starter.post('/api/discussions/start',body,format='json'),404)
        self.publish()
        thread = self.data(starter.post('/api/discussions/start',body,format='json'),201)
        pk = thread['IdDiscussion']
        self.data(starter.post(f'/api/discussions/{pk}/messages',{'message':'Message de recette volontaire'},format='json'),201)
        self.connection.execute('UPDATE systeme."T_Entite" SET "VisibleAnnuaireEntite"=false WHERE "IdEntite"=%s',[target])
        self.data(starter.post('/api/discussions/start',body,format='json'),404)
        history = self.data(starter.get('/api/discussions'))
        self.assertEqual(next(row for row in history if row['IdDiscussion']==pk)['recipient']['id'],target)
        self.assertEqual(len(self.data(starter.get(f'/api/discussions/{pk}/messages'))),1)
        # Une offre volontaire reste une autre origine autorisée de contact.
        article = self.create(VisibleCatalogue=True)
        detail = self.data(starter.get('/api/produits/offres/'+str(article['ID_Article'])))
        self.assertTrue(detail['canContact'])
        self.data(starter.post('/api/discussions/start',body,format='json'))
        self.connection.execute('UPDATE logistique."T_Article" SET "VisibleCatalogue"=false WHERE "ID_Article"=%s',[article['ID_Article']])
        self.data(starter.post('/api/discussions/start',body,format='json'),404)

    def test_11_anonymous_readonly_and_get_without_side_effects(self):
        for path in ('/annuaire','/references','/contexte','/profils'):
            self.data(APIClient().get(BASE+path),401)
        self.publish()
        count = lambda: self.connection.execute('''SELECT (SELECT count(*) FROM communication."T_Discussion") discussions,
            (SELECT count(*) FROM communication."T_Chat") chats,(SELECT count(*) FROM analytics."T_Recherche") searches''').fetchone()
        before = count()
        for path in ('/references','/annuaire','/annuaire/'+str(self.entities[0])):
            self.data(self.client(local=True).get(BASE+path))
        self.assertEqual(before,count())
        with override_settings(DB_READ_ONLY=True):
            self.assertFalse(self.data(self.client(local=True).get(BASE+'/contexte'))['canManage'])
            self.assertFalse(self.data(self.client(local=True).get(BASE+'/annuaire/'+str(self.entities[0])))['canContact'])
            self.data(self.client(local=True).put(BASE+'/profils/'+str(self.entities[0]),self.private_body(),format='json'),503)

    def test_12_professional_list_requires_current_explicit_published_affiliation(self):
        self.publish()
        refs = self.data(self.client().get('/api/professionnels/references'))
        typ = refs['types'][0]['id']
        def create_profile(user, affiliates, publish=True):
            body = {'data':{'IdUserFk':user,'IdTypeProfessionnelFk':typ,'IdSecteurFk':refs['secteurs'][0]['id'],
                           'IdSpecialiteFk':refs['specialites'][0]['id'],'TitrePublic':'Expert fictif '+self.tag,
                           'PresentationPublique':'Présentation de recette fictive'},
                    'affiliations':affiliates,'competenceIds':[],'prestationIds':[],'requestId':str(uuid.uuid4()),'publish':False}
            profile = self.data(self.client().post('/api/professionnels/profils',body,format='json'),201)
            if publish:
                profile = self.data(self.client().post('/api/professionnels/profils/'+str(profile['record']['IdProfessionnel'])+'/actions',
                    {'action':'publier','_version':profile['_version'],'motif':'Publication fictive','requestId':str(uuid.uuid4())},format='json'))
            return profile['record']['IdProfessionnel']
        def account():
            return self.connection.execute('''INSERT INTO systeme."T_Utilisateurs"
                ("NomUser","PrenomUser","EmailUser","MotdepasseUser","ValideUser","SexeUser","Is_Admin","Is_staff","IdEntiteFk")
                VALUES('Expert','Fictif',%s,'inutilisable',true,'M',false,false,%s) RETURNING "IdUser" id''',
                [uuid.uuid4().hex+'@example.invalid',self.entities[0]]).fetchone()['id']
        valid = create_profile(account(),[{'IdEntiteFk':self.entities[0],'DateDebut':'2020-01-01T00:00:00','DateFin':None,'EstPrincipal':True}])
        create_profile(account(),[])
        create_profile(account(),[{'IdEntiteFk':self.entities[0],'DateDebut':'2020-01-01T00:00:00','DateFin':'2021-01-01T00:00:00','EstPrincipal':True}])
        create_profile(account(),[{'IdEntiteFk':self.entities[0],'EstPrincipal':True}],False)
        result = self.data(self.client(local=True).get(BASE+'/annuaire/'+str(self.entities[0])+'/professionnels',{'q':self.tag}))
        self.assertEqual(result['total'],1)
        self.assertEqual([row['id'] for row in result['rows']],[valid])
        self.data(self.client().get(BASE+'/annuaire/'+str(self.entities[0])+'/professionnels',{'sortBy':'experience'}))


if __name__ == '__main__':
    unittest.main(verbosity=2)
