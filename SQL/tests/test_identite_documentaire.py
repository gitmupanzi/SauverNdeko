"""Profil documentaire : données fictives uniquement dans une base sauverndeko_test_* explicite."""
import os,sys,uuid,copy,json,threading
from pathlib import Path
from urllib.parse import urlsplit
import psycopg
root=Path(__file__).resolve().parents[2];dsn=os.environ.get('SAUVERNDEKO_TEST_DATABASE_URL','')
if urlsplit(dsn).scheme not in {'postgres','postgresql'} or not urlsplit(dsn).path[1:].startswith('sauverndeko_test_'):raise RuntimeError('Base privée explicite obligatoire')
with psycopg.connect(dsn) as c:
 if not c.execute('SELECT current_database()').fetchone()[0].startswith('sauverndeko_test_'):raise RuntimeError('Base privée obligatoire')
os.environ.update(DJANGO_SETTINGS_MODULE='config.settings',DATABASE_URL=dsn,SAUVERNDEKO_DB_READ_ONLY='0',DJANGO_SECRET_KEY='private-test',JWT_SECRET='private-test',JWT_REFRESH_SECRET='private-test')
sys.path.insert(0,str(root/'backend'))
import django;django.setup()
from django.db import transaction,DatabaseError,connections
from django.test import override_settings
from rest_framework.test import APIClient
from types import SimpleNamespace
from apps.core import db,repository
from apps.core.responses import APIError
from apps.core.tenancy import bind_context
from apps.accounts.authentication import actor_by_id
from apps.logistique.entity_documents import profile,save,FIELDS,OPERATION
checks=[]
def check(value,name):assert value,name;checks.append(name)
def insert(schema,table,values,key):
 names=list(values);return db.one('INSERT INTO '+db.ident(schema)+'.'+db.ident(table)+' ('+','.join(db.ident(n) for n in names)+') VALUES ('+','.join(['%s']*len(names))+') RETURNING '+db.ident(key)+' id',list(values.values()))['id']
def reject(fn,status,name):
 try:fn()
 except APIError as e:check(e.status_code==status,name)
 else:raise AssertionError(name)
entity=insert('systeme','T_Entite',{'NomEntite':'Entreprise fictive documentaire','EmailEntite':uuid.uuid4().hex+'@example.invalid','ValideEntite':True},'IdEntite')
other=insert('systeme','T_Entite',{'NomEntite':'Autre entreprise fictive','EmailEntite':uuid.uuid4().hex+'@example.invalid','ValideEntite':True},'IdEntite')
uid=insert('systeme','T_Utilisateurs',{'NomUser':'Recette','PrenomUser':'Identité','EmailUser':uuid.uuid4().hex+'@example.invalid','MotdepasseUser':'inutilisable','SexeUser':'M','ValideUser':True,'Is_Admin':True},'IdUser')
def actor(e=entity):return bind_context(actor_by_id(uid),SimpleNamespace(headers={'X-Entite-ID':str(e)}))
a=actor();before=profile(a);check(before['IdentifiantsLegauxEntite']==[],'optional identifiers empty');check(before['canConfigure'] is True,'global context configure');check(isinstance(before['_version'],str),'opaque revision')
reject(lambda:profile(actor_by_id(uid)),409,'global context required')
def body():
 p=profile(a);return {**{key:p.get(key) for key in FIELDS},'IdEntite':entity,'_version':p['_version'],'motif':'Paramétrage fictif de recette','requestId':str(uuid.uuid4())}
b=body();b.update(NomEntite='Entreprise & partenaires',AdresseEntite='Adresse fictive\nDeuxième ligne',EmailEntite=uuid.uuid4().hex+'@example.invalid',PhoneEntite='+999'+str(uuid.uuid4().int)[:12],IdentifiantsLegauxEntite=[{'libelle':'Registre','valeur':'RECETTE-123'},{'libelle':'Identifiant fiscal','valeur':'FICTIF-456'}],MentionDocumentaireEntite='Mention de recette\nSans régime fiscal imposé')
p,replayed=save(a,b);check(not replayed,'first save');check(p['NomEntite']==b['NomEntite'],'name persisted');check(p['IdentifiantsLegauxEntite']==b['IdentifiantsLegauxEntite'],'identifiers persisted');check(p['_version']!=before['_version'],'revision advances')
p2,replayed=save(a,b);check(replayed,'same request replay');check(p2['_version']==p['_version'],'replay no write')
changed=copy.deepcopy(b);changed['PhoneEntite']='123';reject(lambda:save(a,changed),409,'changed replay refused')
stale=copy.deepcopy(b);stale['requestId']=str(uuid.uuid4());reject(lambda:save(a,stale),409,'stale revision refused')
reject(lambda:save(actor(other),body()),403,'other context cannot write owner')
with override_settings(DB_READ_ONLY=True):reject(lambda:save(a,body()),503,'read only refuses')
for key,value in [('NomEntite',''),('EmailEntite','invalid'),('PhoneEntite','1'*21),('MentionDocumentaireEntite','x'*1001),('IdentifiantsLegauxEntite',[{'libelle':'A','valeur':'1'},{'libelle':' a ','valeur':'2'}]),('IdentifiantsLegauxEntite',[{'libelle':'x','valeur':'1','secret':'non'}]),('IdentifiantsLegauxEntite',[{'libelle':'x','valeur':'1'}]*11),('motif','')]:
 bad=body();bad[key]=value;reject(lambda:save(a,bad),400,'invalid field '+key+str(len(checks)))
for value in [{'x':1},[{'libelle':'x','valeur':'1','other':'x'}],[{'libelle':'x','valeur':'1'},{'libelle':'X','valeur':'2'}],[{'libelle':'x','valeur':'tab\t'}]]:
 try:
  with transaction.atomic():db.query('UPDATE systeme."T_Entite" SET "IdentifiantsLegauxEntite"=%s WHERE "IdEntite"=%s',[psycopg.types.json.Jsonb(value),entity])
 except DatabaseError as e:check(getattr(e.__cause__,'sqlstate',None)=='23514','direct SQL invalid identifiers')
 else:raise AssertionError('Invalid JSON accepted')
# New documents freeze the current profile; changes never rewrite prior snapshots.
type_row=db.one('SELECT "ID_Generique" id FROM referentiel."T_Generique" WHERE "ID_CategorieGeneriqueFk"=64 AND "ValideGenerique" IS TRUE ORDER BY "ID_Generique" LIMIT 1')
currency=db.one('SELECT "ID_Generique" id FROM referentiel."T_Generique" WHERE "ID_CategorieGeneriqueFk"=42 AND "AbrGenerique"=%s AND "ValideGenerique" IS TRUE LIMIT 1',['USD'])
def bon():return repository.mutate('T_Commande',a,{'DateCmd':'2026-10-26T12:00:00','ID_TypeCmdFk':type_row['id'],'ID_DeviseFk':currency['id']},operation='create')['ID_Commande']
order=bon();frozen=db.one('SELECT * FROM logistique."T_DocumentIdentite" WHERE "TypeObjet"=%s AND "ID_Objet"=%s',['bon',order])
check(frozen['IdentiteEmetteur']['IdentifiantsLegauxEntite']==b['IdentifiantsLegauxEntite'],'snapshot contains legal identifiers')
next_body=body();next_body['NomEntite']='Nouveau nom fictif';save(a,next_body)
check(db.one('SELECT * FROM logistique."T_DocumentIdentite" WHERE "TypeObjet"=%s AND "ID_Objet"=%s',['bon',order])==frozen,'old identity unchanged')
second=bon();check(db.one('SELECT "IdentiteEmetteur" i FROM logistique."T_DocumentIdentite" WHERE "TypeObjet"=%s AND "ID_Objet"=%s',['bon',second])['i']['NomEntite']=='Nouveau nom fictif','new document uses new profile')
try:
 with transaction.atomic():db.query('UPDATE logistique."T_DocumentIdentite" SET "IdentiteEmetteur"=%s WHERE "ID_DocumentIdentite"=%s',[psycopg.types.json.Jsonb({}),frozen['ID_DocumentIdentite']])
except DatabaseError as e:check(getattr(e.__cause__,'sqlstate',None)=='23514','snapshot immutable SQL')
else:raise AssertionError('Identity rewritten')
# Duplicate concurrent confirmation produces one audit record and no side effect.
request=body();gate=threading.Barrier(2);results=[]
def worker():
 try:gate.wait();results.append(save(actor(),copy.deepcopy(request))[1])
 except Exception as e:results.append(type(e).__name__)
 finally:connections.close_all()
threads=[threading.Thread(target=worker) for _ in range(2)]
for t in threads:t.start()
for t in threads:t.join(20)
check(sorted(results)==[False,True],'concurrent same request one save one replay')
check(db.one('SELECT count(*) n FROM systeme."T_Audit_Log" WHERE "Operation"=%s AND "NewData" @> %s',[OPERATION,psycopg.types.json.Jsonb({'requestId':request['requestId']})])['n']==1,'single audit confirmation')
client=APIClient();client.force_authenticate(a)
with override_settings(ALLOWED_HOSTS=['testserver']):
 check(client.get('/api/logistique/entreprise/identite',HTTP_X_ENTITE_ID=str(entity)).status_code==200,'mounted GET route')
 check(client.get('/api/logistique/entreprise/identite?x=1',HTTP_X_ENTITE_ID=str(entity)).status_code==400,'unknown query rejected')
 client.force_authenticate(None);check(client.get('/api/logistique/entreprise/identite').status_code in {401,403},'anonymous forbidden')
from apps.logistique.documents import render_pdf
pdf=render_pdf({'emitter':frozen['IdentiteEmetteur'],'title':'Bon de sortie','lines':[{'name':'Article fictif','quantity':'1','unit':'pcs','price':'10','amount':'10'}],'totals':[('Total','10')],'currency':'USD','code':'recette-1','date':'2026-10-26T12:00:00'})
check(pdf.startswith(b'%PDF'),'PDF with declared identity')
# Optional artifact outside the working tree for visual inspection.
if os.environ.get('SAUVERNDEKO_TEST_PDF_OUTPUT'):Path(os.environ['SAUVERNDEKO_TEST_PDF_OUTPUT']).write_bytes(pdf)
check(db.one('SELECT count(*) n FROM logistique."T_Mouvement" WHERE "ID_cmdFk"=ANY(%s)',[[order,second]])['n']==0,'profile and empty documents create no stock')
print('PASS',len(checks),'contrôles identité documentaire sur base privée.')
