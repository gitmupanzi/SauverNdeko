"""Fiches de patrimoine PDF réelles : données fictives, base privée obligatoire."""
import hashlib
import io
import json
import os
import sys
import uuid
from pathlib import Path

packages=os.environ.get('SAUVERNDEKO_TEST_PDF_PACKAGES')
if packages:sys.path.append(packages)
from pypdf import PdfReader
from PIL import Image
from test_immobilisations_api import ImmobilisationsAPI,ROOT,DSN,location
from django.core.files.uploadedfile import SimpleUploadedFile
from rest_framework.test import APIClient
from django.db import connections
from apps.core.responses import ExactEncoder
from apps.logistique import entity_documents,documents

checks=[]
def check(condition,label):
    assert condition,label
    checks.append(label)

def data(response,status=200):
    check(response.status_code==status,'HTTP attendu '+str(status)+(' '+str(getattr(response,'data',{})) if response.status_code!=status else ''))
    return getattr(response,'data',{}).get('data')

def digest(value):return hashlib.sha256(json.dumps(value,cls=ExactEncoder,sort_keys=True,ensure_ascii=False).encode()).hexdigest()

ImmobilisationsAPI.setUpClass()
fixture=ImmobilisationsAPI(methodName='runTest');sql=fixture.sql;actor=fixture.actor();client=fixture.client()
out=ROOT/'.runtime/immobilisations-pdf-api';out.mkdir(parents=True,exist_ok=True)
tag=uuid.uuid4().hex[:8]
old_company='PATRIMOINE ANCIEN EMETTEUR '+tag
current_company='PATRIMOINE EMETTEUR ACTUEL '+tag
address='Adresse actuelle fictive '+tag
footer='MENTION PATRIMOINE COURANTE '+tag
site='https://example.invalid/'+tag

def profile(**changes):
    current=entity_documents.profile(actor)
    payload={key:current.get(key) for key in entity_documents.FIELDS}
    payload.update(IdEntite=actor.organisation,_version=current['_version'],motif='Recette PDF fictive du patrimoine',requestId=str(uuid.uuid4()))
    payload.update(changes)
    return payload

def logo(color):
    output=io.BytesIO();Image.new('RGB',(64,32),color).save(output,format='PNG')
    return SimpleUploadedFile('logo-fictif.png',output.getvalue(),content_type='image/png')

entity_documents.save(actor,profile(NomEntite=old_company,AdresseEntite='Adresse antérieure fictive',logoAction='replace'),logo((201,31,21)))
assigned=fixture.create(NomImmobilisation='BIEN AFFECTE PDF '+tag,Reference='REF-000001',NumeroSerie='SERIE-000002',
    ID_EtatFk=fixture.refs['etats'][0]['id'],ID_ServiceFk=fixture.refs['services'][0]['id'],ID_ResponsableFk=fixture.users[0]['IdUser'],
    ID_LocalisationFk=fixture.locations[0],LocalisationComplement='Bureau test',PrixUnitaire='125.50',Caracteristiques='Équipement fictif pour recette PDF')
unassigned=fixture.create(NomImmobilisation='BIEN NON AFFECTE PDF '+tag,PrixUnitaire='18.25',ID_EtatFk=None,ID_ResponsableFk=None,ID_ServiceFk=None)
group=fixture.create(NomImmobilisation='LOT HOMOGENE PDF '+tag,SuiviIndividuel=False,Quantite='12',PrixUnitaire='11.25')
unknown=fixture.create(NomImmobilisation='COUT INCONNU PDF '+tag,PrixUnitaire=None,ID_DeviseFk=None)
zero=fixture.create(NomImmobilisation='COUT NUL PDF '+tag,PrixUnitaire='0.00')
archived=fixture.create(NomImmobilisation='BIEN ARCHIVE PDF '+tag,PrixUnitaire='4.10')
archived=data(client.delete('/api/logistique/immobilisations/'+str(archived['ID_Immobilisation']),
    {'_version':archived['_version'],'requestId':str(uuid.uuid4()),'motif':'Archivage fictif de recette PDF'},format='json'))
long=fixture.create(NomImmobilisation='FICHE LONGUE PDF '+tag,Caracteristiques=('Caractéristique détaillée de recette.\n'*100).strip(),
    Observations=('Observation de recette uniquement.\n'*110).strip(),PrixUnitaire='5.20')
cases={'affecte':assigned,'sans-affectation':unassigned,'groupe':group,'prix-inconnu':unknown,'prix-zero':zero,'archive':archived,'multipage':long}
foreign=fixture.create(1)

def asset_state():
    return digest(sql.execute('SELECT to_jsonb(t) row FROM logistique."T_Immobilisation" t WHERE "IdEntiteFk"=ANY(%s) ORDER BY "ID_Immobilisation"',[fixture.entities]).fetchall())

def commercial_state():
    result={}
    for table in ['T_Article','T_Commande','T_CommandeDetail','T_Mouvement','T_LotArticle','T_MouvementLot','T_Facture','T_Reglements','T_Avoir']:
        result[table]=digest(sql.execute('SELECT to_jsonb(t) row FROM logistique."'+table+'" t ORDER BY to_jsonb(t)::text').fetchall())
    return result

before_asset,before_commercial=asset_state(),commercial_state()
audit_before=digest(sql.execute('SELECT to_jsonb(t) row FROM systeme."T_Audit_Log" t WHERE "TableName"=%s AND "IdEntiteFk"=ANY(%s) ORDER BY "IdLog"',['logistique.T_Immobilisation',fixture.entities]).fetchall())
entity_documents.save(actor,profile(NomEntite=current_company,AdresseEntite=address,PhoneEntite='+243 81 000 00 01',PhoneSecondaireEntite='+243 81 000 00 02',
    EmailEntite='patrimoine-fictif@example.invalid',SiteWebEntite=site,MentionDocumentaireEntite=footer,
    IdentifiantsLegauxEntite=[{'libelle':'RCCM','valeur':'FICTIF-RCCM-'+tag}],logoAction='replace'),logo((21,111,211)))
paths=[];pages_count={}
for show_head,show_foot in [(True,True),(True,False),(False,True),(False,False)]:
    entity_documents.save(actor,profile(AfficherEnteteDocument=show_head,AfficherPiedDocument=show_foot))
    for name,row in cases.items():
        pk=row['ID_Immobilisation'];route='/api/logistique/documents/immobilisation/'+str(pk)+'/fiche.pdf'
        projected=documents.document_data(actor,'immobilisation',pk,'fiche')
        check(projected['emitter']['NomEntite']==current_company,name+' utilise l’entreprise émettrice actuelle')
        check(projected['lines'][0]['amount']==row['ValeurAcquisition'],name+' valeur exacte de la vue SQL')
        check(projected['lines'][0]['quantity']==row['Quantite'],name+' quantité exacte conservée')
        response=client.get(route,HTTP_ACCEPT='application/pdf')
        check(response.status_code==200,name+' PDF200 : '+str(getattr(response,'data','')))
        check(response['Content-Type']=='application/pdf' and 'no-store' in response['Cache-Control'],name+' PDF privé non mis en cache')
        check(response['X-Content-Type-Options']=='nosniff',name+' type binaire protégé')
        reader=PdfReader(io.BytesIO(response.content));text='\n'.join(page.extract_text() or '' for page in reader.pages)
        check(current_company in text and old_company not in text,name+' renommage de l’émetteur répercuté')
        check(row['NomImmobilisation'] in text and row['CodeImmobilisation'] in text,name+' identité du bon bien')
        check((address in text)==show_head and (site in text)==show_head,name+' coordonnées selon option en-tête')
        check((footer in text)==show_foot and ('FICTIF-RCCM-'+tag in text)==show_foot,name+' identité légale selon option pied')
        check(('Page 1 sur' in text)==show_foot,name+' pagination masquée avec le pied')
        check('Amortissement' not in text and 'TVA' not in text,name+' aucune comptabilisation ou TVA inventée')
        images=[image.image for page in reader.pages for image in page.images]
        check(bool(images)==show_head,name+' logo selon option persistée')
        if images:check(any(image.convert('RGB').getpixel((0,0))==(21,111,211) for image in images),name+' logo courant remplacé')
        if name=='affecte':
            for value in [assigned['CategorieMateriel'],assigned['EtatMateriel'],assigned['Service'],assigned['Responsable'],'Bureau test','SERIE-000002']:
                check(value in text,'Affectation et références métier imprimées : '+value)
        if name=='groupe':check('Lot homogène' in text and '135,00' in text,'Groupe homogène, quantité et valeur135USD imprimés')
        if name=='prix-inconnu':check('Valeur d’acquisition' not in text and '0,00' not in text,'Prix inconnu jamais assimilé à zéro')
        if name=='prix-zero':check('0,00 USD' in text,'Prix nul explicitement conservé')
        if name=='archive':check('Archivé' in text,'Fiche archivée reste consultable et identifiée')
        if name=='multipage':
            check(len(reader.pages)>1,'Texte long réparti sur plusieurs pages sans erreur')
            check('Caractéristique détaillée de recette.' in text and 'Observation de recette uniquement.' in text,'Caractéristiques et observations longues imprimées')
        for page in reader.pages:check(float(page.mediabox.width)>590 and float(page.mediabox.height)>840,'Format papier A4')
        path=out/(name+'-entete'+str(int(show_head))+'-pied'+str(int(show_foot))+'.pdf');path.write_bytes(response.content)
        paths.append(str(path));pages_count[path.name]=len(reader.pages)

target=assigned['ID_Immobilisation'];url='/api/logistique/documents/immobilisation/'+str(target)+'/fiche.pdf'
data(fixture.client(1,global_admin=False).get(url),404)
data(fixture.client(export=False).get(url),403)
data(fixture.client(read=False).get(url),403)
check(APIClient().get(url).status_code in {401,403},'Téléchargement anonyme refusé')
data(client.get('/api/logistique/documents/immobilisation/'+str(foreign['ID_Immobilisation'])+'/fiche.pdf'),404)
data(client.get('/api/logistique/documents/immobilisation/'+str(target)+'/facture.pdf'),404)
check(client.get('/api/logistique/documents/immobilisation/'+str(target)+'/pieces').status_code==404,'Aucune route justificatifs incompatible avec le stockage existant')
global_read=fixture.client(all_entities=True).get(url,HTTP_ACCEPT='application/pdf')
check(global_read.status_code==200,'Administrateur global consulte sans changer les données ou choisir une entreprise')
check(asset_state()==before_asset,'PDF ne modifie aucun bien ou affectation')
check(commercial_state()==before_commercial,'PDF ne crée ni mouvement de stock ni écriture financière')
check(digest(sql.execute('SELECT to_jsonb(t) row FROM systeme."T_Audit_Log" t WHERE "TableName"=%s AND "IdEntiteFk"=ANY(%s) ORDER BY "IdLog"',['logistique.T_Immobilisation',fixture.entities]).fetchall())==audit_before,'Historique des immobilisations inchangé par la lecture PDF')
proof={'passed':True,'checks':len(checks),'details':checks,'database':location.path[1:],'productionWrites':False,'pdfs':paths,'pages':pages_count,
    'forms':7,'combinations':4,'currentEnterpriseIdentity':True,'assetsCommercialHistoryPreserved':True,
    'sha256':{name:hashlib.sha256((ROOT/name).read_bytes()).hexdigest() for name in ['backend/apps/logistique/documents.py','backend/apps/logistique/entity_documents.py','backend/config/urls.py','SQL/tests/test_immobilisations_pdf_api.py']}}
(out/'verification.json').write_text(json.dumps(proof,ensure_ascii=False,indent=2),encoding='utf8')
fixture.tearDownClass();connections.close_all()
print('PASS',len(checks),'contrôles ; 7fiches×4options persistées ; aucune donnée cliente.')
