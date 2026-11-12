"""Recette pré/post migration06 sur un clone local fictif au socle05 exclusivement.

Les codes anciens sont simulés avant émission des factures. Seule cette préparation
privée neutralise les triggers pendant leur UPDATE ciblé ; la migration et tous
les parcours métier s'exécutent ensuite avec leurs protections activées.
"""
import csv
import hashlib
import io
import json
import os
import re
import sys
import uuid
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import urlsplit

import psycopg
from psycopg.rows import dict_row

ROOT = Path(__file__).resolve().parents[2]
DSN = os.environ.get('SAUVERNDEKO_TEST_DATABASE_URL', '')
location = urlsplit(DSN)
if location.hostname not in {'localhost','127.0.0.1','::1'} or not location.path[1:].startswith('sauverndeko_test_'):
    raise RuntimeError('Un clone privé local sauverndeko_test_* au socle05 est obligatoire.')
with psycopg.connect(DSN) as guard:
    if not guard.execute('SELECT current_database()').fetchone()[0].startswith('sauverndeko_test_'):
        raise RuntimeError('Base privée obligatoire.')
    if guard.execute("SELECT to_regclass('logistique.\"T_BonCodeHistorique\"') IS NOT NULL").fetchone()[0]:
        raise RuntimeError('Cette recette nécessite un clone05 neuf ; ne pas rejouer après06.')
migrations = list((ROOT/'backend/database/migrations').glob('20261028_06_*.sql'))
if len(migrations)!=1: raise RuntimeError('Migration06 finale unique requise.')
sys.path.insert(0,str(ROOT/'SQL/tests'))
from test_bons_commande_api import BonsCommandeAPI
from django.db import connections
from django.core.files.uploadedfile import SimpleUploadedFile
from apps.core import db, repository
from apps.core.responses import ExactEncoder
from apps.logistique.documents import document_data, render_pdf

checks=[]
def check(condition,label):
    if not condition: raise AssertionError(label)
    checks.append(label)
def successful(response,status=200):
    check(response.status_code==status,f'HTTP {status} : {getattr(response,"data",{})}' if response.status_code!=status else 'HTTP '+str(status))
    return response.data
def digest(value):return hashlib.sha256(json.dumps(value,cls=ExactEncoder,sort_keys=True,ensure_ascii=False).encode('utf8')).hexdigest()

BonsCommandeAPI.setUpClass()
fixture=BonsCommandeAPI(methodName='runTest')
c=fixture.connection
# Les recettes précédentes peuvent avoir créé plusieurs types Entrée actifs.
# Ce clone fictif impose sa référence unique avant de tester les restitutions.
c.execute('UPDATE referentiel."T_Generique" SET "ValideGenerique"=false WHERE "ID_CategorieGeneriqueFk"=64 AND "AbrGenerique" ILIKE \'entr%%\' AND "ID_Generique"<>%s',[fixture.be])
if not c.execute('SELECT 1 FROM referentiel."T_InterfaceTableau" WHERE "CleInterface"=\'logistique.lignes\'').fetchone():
    source=(ROOT/'backend/database/migrations/20261028_02_preferences_tableaux.sql').read_text(encoding='utf8')
    entry=re.search(r"^\('logistique[.]lignes','logistique','(.*)'::jsonb\)[,;]$",source,re.MULTILINE)
    if not entry:raise RuntimeError('Catalogue des lignes versionné absent.')
    c.execute('INSERT INTO referentiel."T_InterfaceTableau" ("CleInterface","Module","Colonnes") VALUES (\'logistique.lignes\',\'logistique\',%s::jsonb)',[json.dumps(json.loads(entry.group(1).replace("''","'")),ensure_ascii=False)])
out=ROOT/'.runtime/renommage-bons-api';out.mkdir(parents=True,exist_ok=True)
client=fixture.client();actor=fixture.actor()
article=fixture.article()
receipt={'requestId':str(uuid.uuid4()),'ID_TypeCmdFk':fixture.be,'ID_DeviseFk':fixture.currency,
         'DateCmd':'2026-10-28T10:00:00','QteCmdDetail':'10','PUCmdDetail':'8','Lots':[]}
received=successful(client.post(f'/api/logistique/articles/{article}/receptions',receipt,format='json'),201)['data']
entry_id=received['bon']['ID_Commande']
stock_body=fixture.payload(article,kind=fixture.bs,quantity='2',price='12')
sold=fixture.create(stock_body);sold_id=sold['bon']['ID_Commande']
later=fixture.create(fixture.payload(article,kind=fixture.bs,quantity='1',price='13'));later_id=later['bon']['ID_Commande']
planned_body=fixture.payload(article,quantity='7',price='11')
planned=fixture.create(planned_body);planned_id=planned['bon']['ID_Commande']
ids=[entry_id,sold_id,later_id,planned_id]
legacy={key:'cmd-'+str(key) for key in ids}
with c.transaction():
    assert c.execute('SELECT current_database() name').fetchone()['name'].startswith('sauverndeko_test_')
    c.execute('ALTER TABLE logistique."T_Commande" DISABLE TRIGGER USER')
    for key,code in legacy.items():c.execute('UPDATE logistique."T_Commande" SET "CodeCmd"=%s WHERE "ID_Commande"=%s',[code,key])
    c.execute('ALTER TABLE logistique."T_Commande" ENABLE TRIGGER USER')
check(not c.execute('SELECT 1 FROM pg_trigger WHERE tgrelid=\'logistique."T_Commande"\'::regclass AND NOT tgisinternal AND tgenabled=\'D\'').fetchone(),'Protections réactivées après préparation privée des codes historiques')

current=successful(client.get(f'/api/logistique/commandes/{planned_id}/composition'))
edit_body={'requestId':str(uuid.uuid4()),'bon':planned_body['bon'],
           'lignes':[{**planned_body['lignes'][0],'QteCmdDetail':'8'}],'_version':current['meta']['revision']}
successful(client.put(f'/api/logistique/commandes/{planned_id}/composition',edit_body,format='json'))
stale_revision=successful(client.get(f'/api/logistique/commandes/{planned_id}/composition'))['meta']['revision']
invoice_context=successful(client.get(f'/api/logistique/commandes/{sold_id}/facture'))
invoice_body={'requestId':str(uuid.uuid4()),'_version':invoice_context['meta']['revision'],
              'DateFacture':'2026-10-28T12:00:00','DateEcheancePaiement':'2026-11-28T12:00:00'}
invoice=successful(client.post(f'/api/logistique/commandes/{sold_id}/facture',invoice_body,format='json'),201)['data']['facture']
# Un mode partagé fictif suffit, sans intégrer une donnée d'entreprise existante.
mode=c.execute('SELECT "ID_Generique" id FROM referentiel."T_Generique" WHERE "ID_CategorieGeneriqueFk"=36 AND "ValideGenerique" IS TRUE LIMIT 1').fetchone()
if not mode:
    c.execute('INSERT INTO referentiel."T_CategorieGenerique" ("ID_CategorieGenerique","NomCategorieGenerique","ValideCategorieGenerique") OVERRIDING SYSTEM VALUE VALUES (36,\'Mode de paiement\',true) ON CONFLICT DO NOTHING')
    mode=c.execute('INSERT INTO referentiel."T_Generique" ("ID_CategorieGeneriqueFk","NomGenerique","AbrGenerique","ValideGenerique") VALUES (36,\'Espèces fictives\',\'TEST-CASH\',true) RETURNING "ID_Generique" id').fetchone()
prepared=successful(client.get('/api/logistique/reglements/preparation',{'commandeId':sold_id}))
payment_body={'requestId':str(uuid.uuid4()),'_version':prepared['meta']['revision'],'CodeFactureFk':invoice['CodeFacture'],
              'ID_ModeReglementFk':mode['id'],'DateReglement':'2026-10-28T12:30:00','MontantRegle':'5'}
payment=successful(client.post('/api/logistique/reglements',payment_body,format='json'),201)['data']
payment_id=payment['ID_Reglement']
returns=successful(client.get(f'/api/logistique/commandes/{sold_id}/retours'))
return_body={'requestId':str(uuid.uuid4()),'_version':returns['meta']['revision'],'DateCmd':'2026-10-28T13:00:00',
             'motif':'Retour fictif historique','lignes':[{'ID_ArticleFk':article,'QteRetour':'1','Lots':[]}]}
returned=successful(client.post(f'/api/logistique/commandes/{sold_id}/retours',return_body,format='json'),201)['data']
credit_context=successful(client.get(f'/api/logistique/commandes/{sold_id}/avoirs'))
credit_body={'requestId':str(uuid.uuid4()),'_version':credit_context['meta']['revision'],'DateAvoir':'2026-10-28T13:30:00','Motif':'Avoir fictif après restitution'}
credit=successful(client.post(f'/api/logistique/commandes/{sold_id}/avoirs',credit_body,format='json'),201)['data']['avoir']
credit_id=credit['ID_Avoir']
uploaded=SimpleUploadedFile('bon-'+legacy[sold_id]+'.pdf',(ROOT/'.runtime/bons-commande-api/bon-commande.pdf').read_bytes(),content_type='application/pdf')
piece=successful(client.post(f'/api/logistique/documents/bon/{sold_id}/pieces',{'file':uploaded},format='multipart'),201)['data']['ID_Piece']
folder=c.execute('''INSERT INTO logistique."T_DossierSuivi" ("ID_UserFk","IdEntiteFk","Nom","Description","Couleur","Mode","Regles","TypeObjet")
    VALUES (%s,%s,%s,'Dossier fictif par ancienne référence','bleu','automatique',%s::jsonb,'bon') RETURNING "ID_DossierSuivi" id,"Regles"''',
    [actor.pk,actor.organisation,'Dossier historique '+uuid.uuid4().hex,json.dumps({'q':legacy[sold_id]})]).fetchone()

def row(table,key,column):
    return c.execute('SELECT to_jsonb(t) data FROM logistique."'+table+'" t WHERE t."'+column+'"=%s',[key]).fetchone()['data']
before={
    'stock':fixture.state(article),
    'invoice':row('T_Facture',invoice['ID_Facture'],'ID_Facture'),
    'invoiceLines':c.execute('SELECT to_jsonb(t) data FROM logistique."T_FactureLigne" t WHERE "ID_FactureFk"=%s ORDER BY "ID_FactureLigne"',[invoice['ID_Facture']]).fetchall(),
    'payment':row('T_Reglements',payment_id,'ID_Reglement'),
    'credit':row('T_Avoir',credit_id,'ID_Avoir'),
    'piece':row('T_PieceJustificative',piece,'ID_Piece'),
    'identities':c.execute('SELECT to_jsonb(t) data FROM logistique."T_DocumentIdentite" t WHERE "IdEntiteFk"=%s ORDER BY "ID_DocumentIdentite"',[fixture.entities[0]]).fetchall(),
    'refReturn':c.execute('SELECT "RefCmd" ref FROM logistique."T_Commande" WHERE "ID_Commande"=%s',[returned['bonRetour']['ID_Commande']]).fetchone()['ref'],
}
audit_max=c.execute('SELECT max("IdLog") id FROM systeme."T_Audit_Log"').fetchone()['id']
audit_before=digest(c.execute('SELECT to_jsonb(t) data FROM systeme."T_Audit_Log" t WHERE "IdLog"<=%s ORDER BY "IdLog"',[audit_max]).fetchall())
connections.close_all()
with psycopg.connect(DSN,autocommit=True) as migration_connection:
    migration_connection.execute(migrations[0].read_text(encoding='utf8'))
check(fixture.state(article)==before['stock'],'Renumérotation sans variation de stock, mouvement ni lot')
for table,key,column,label in [('T_Facture',invoice['ID_Facture'],'ID_Facture','invoice'),('T_Reglements',payment_id,'ID_Reglement','payment'),('T_Avoir',credit_id,'ID_Avoir','credit'),('T_PieceJustificative',piece,'ID_Piece','piece')]:
    check(row(table,key,column)==before[label],label+' intégralement conservé')
check(c.execute('SELECT to_jsonb(t) data FROM logistique."T_FactureLigne" t WHERE "ID_FactureFk"=%s ORDER BY "ID_FactureLigne"',[invoice['ID_Facture']]).fetchall()==before['invoiceLines'],'Lignes facturées figées intactes')
check(c.execute('SELECT to_jsonb(t) data FROM logistique."T_DocumentIdentite" t WHERE "IdEntiteFk"=%s ORDER BY "ID_DocumentIdentite"',[fixture.entities[0]]).fetchall()==before['identities'],'Identités documentaires originales inchangées')
check(digest(c.execute('SELECT to_jsonb(t) data FROM systeme."T_Audit_Log" t WHERE "IdLog"<=%s ORDER BY "IdLog"',[audit_max]).fetchall())==audit_before,'Audits originaux jamais réécrits')
check(c.execute('SELECT "RefCmd" ref FROM logistique."T_Commande" WHERE "ID_Commande"=%s',[returned['bonRetour']['ID_Commande']]).fetchone()['ref']==before['refReturn'],'Référence historique du retour conservée')
check(c.execute('SELECT "Regles" FROM logistique."T_DossierSuivi" WHERE "ID_DossierSuivi"=%s',[folder['id']]).fetchone()['Regles']==folder['Regles'],'Règles JSON du dossier jamais réécrites')
check(successful(client.post('/api/logistique/commandes/composees',stock_body,format='json'))['data']['replayed'],'Création composée rejouée sans doublon après changement de code')
check(successful(client.post(f'/api/logistique/articles/{article}/receptions',receipt,format='json'))['data']['replayed'],'Réception rejouée sans double mouvement après changement de code')
check(successful(client.put(f'/api/logistique/commandes/{planned_id}/composition',edit_body,format='json'))['data']['replayed'],'Modification composée rejouée sans doublon après changement de code')
check(successful(client.post(f'/api/logistique/commandes/{sold_id}/facture',invoice_body,format='json'))['data']['replayed'],'Émission de facture rejouée sans nouvelle facture')
check(successful(client.post('/api/logistique/reglements',payment_body,format='json'))['data']['replayed'],'Règlement rejoué sans écriture financière en double')
check(successful(client.post(f'/api/logistique/commandes/{sold_id}/retours',return_body,format='json'))['data']['replayed'],'Restitution rejouée sans mouvement compensateur en double')
check(successful(client.post(f'/api/logistique/commandes/{sold_id}/avoirs',credit_body,format='json'))['data']['replayed'],'Avoir rejoué sans émission supplémentaire')
stale={**edit_body,'requestId':str(uuid.uuid4()),'_version':stale_revision}
successful(client.put(f'/api/logistique/commandes/{planned_id}/composition',stale,format='json'),409)
check(fixture.state(article)==before['stock'],'Tous les rejeux conservent les mouvements et le stock')

old=legacy[sold_id]
query=successful(client.get('/api/logistique/registre/commandes',{'q':old}))
check(any(x['ID_Commande']==sold_id for x in query['data']),'Recherche du bon par ancienne référence')
lines=successful(client.get('/api/logistique/registre/lignes',{'q':old}))
check(any(x['ID_CmdFk']==sold_id for x in lines['data']),'Recherche des lignes par ancienne référence')
folder_result=successful(client.get('/api/logistique/dossiers-suivi/dossier-'+str(folder['id'])))
check(any(x['ID_Commande']==sold_id for x in folder_result['data']),'Ancienne recherche de dossier reste fonctionnelle sans réécriture JSON')
column=successful(client.get('/api/logistique/registre/commandes',{'columnFilters':json.dumps({'CodeCmd':old})}))
check(any(x['ID_Commande']==sold_id for x in column['data']),'Filtre CodeCmd retrouve aussi son alias historique')
exact=successful(client.get('/api/logistique/commandes',{'code':old}))
check(any(x['ID_Commande']==sold_id for x in exact['data']),'Ancien paramètre exact code conserve sa résolution')
other=fixture.client(1,global_admin=False)
check(successful(other.get('/api/logistique/registre/commandes',{'q':old}))['data']==[],'Alias historique ne franchit pas le périmètre entreprise')
successful(other.get(f'/api/logistique/documents/facture/{sold_id}/facture.pdf'),404)
successful(client.get('/api/models/T_BonCodeHistorique'),403)
successful(client.post('/api/models/T_BonCodeHistorique',{},format='json'),403)
response=client.get('/api/logistique/registre/commandes/export.csv',{'columns':'["CodeCmd","AncienCodeCmd"]','selection':json.dumps([sold_id])},HTTP_ACCEPT='text/csv')
check(response.status_code==200,'Export CSV de la référence courante et ancienne autorisé')
csv_rows=list(csv.reader(io.StringIO(b''.join(response.streaming_content).decode('utf-8-sig')),delimiter=';'));response.close()
check(csv_rows[1]==['BS-'+str(sold_id),old],'Export exact, sans doublon ni substitution de l’ancien code')

for kind,key,variant,name in [('facture',sold_id,'facture','facture-historique'),('reglement',payment_id,'recu','recu-historique'),('avoir',credit_id,'avoir','avoir-historique')]:
    data=document_data(actor,kind,key,variant)
    check(data['parentCode']==old,name+' conserve la référence du bon à son émission')
    (out/(name+'.pdf')).write_bytes(render_pdf(data))
bon=document_data(actor,'bon',sold_id,'sortie')
check(bon['code']=='BS-'+str(sold_id) and any(old in note for note in bon['notes']),'Bon courant : nouveau code avec ancienne référence discrète')
(out/'bon-courant.pdf').write_bytes(render_pdf(bon))
new_context=successful(client.get(f'/api/logistique/commandes/{later_id}/facture'))
new_body={**invoice_body,'requestId':str(uuid.uuid4()),'_version':new_context['meta']['revision']}
successful(client.post(f'/api/logistique/commandes/{later_id}/facture',new_body,format='json'),201)
new_pdf=document_data(actor,'facture',later_id,'facture')
check(new_pdf['parentCode']=='BS-'+str(later_id),'Facture émise après renumérotation utilise le nouveau code du bon')
(out/'facture-nouvelle.pdf').write_bytes(render_pdf(new_pdf))
check(c.execute('SELECT logistique.fn_code_bon_a_date(%s,NULL) code',[sold_id]).fetchone()['code']==old,'Création historique inconnue reste associée à l’ancienne référence')

proof={'checkedAt':datetime.now(timezone.utc).isoformat(),'database':location.path[1:],'result':'PASS','checks':checks,'count':len(checks),
       'businessSnapshotsPreserved':True,'originalAuditPreserved':True,'productionBusinessWrites':False,
       'migration':migrations[0].name,'migrationSHA256':hashlib.sha256(migrations[0].read_bytes()).hexdigest(),
       'pdfs':[str(path) for path in out.glob('*.pdf')]}
(out/'verification.json').write_text(json.dumps(proof,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
fixture.tearDownClass();connections.close_all()
print('PASS',len(checks),'contrôles de renumérotation API/PDF sur clone fictif uniquement.')
