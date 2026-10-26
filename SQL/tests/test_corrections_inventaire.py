"""Bons d'inventaire non commerciaux : recette SQL/API et concurrence privée.
Nécessite les migrations jusqu'au 20261026_08, aucune donnée fictive en base applicative.
"""
import os,sys,uuid,time,threading
from pathlib import Path
from decimal import Decimal
from datetime import datetime,timedelta,timezone
from types import SimpleNamespace
from urllib.parse import urlsplit
from concurrent.futures import ThreadPoolExecutor
import psycopg
root=Path(__file__).resolve().parents[2];dsn=os.environ.get('SAUVERNDEKO_TEST_DATABASE_URL','');u=urlsplit(dsn)
if u.scheme not in ('postgres','postgresql') or not u.path[1:].startswith('sauverndeko_test_'):raise RuntimeError('Base privée sauverndeko_test_* requise sans repli vers DATABASE_URL.')
with psycopg.connect(dsn) as guard:
 if not guard.execute('SELECT current_database()').fetchone()[0].startswith('sauverndeko_test_'):raise RuntimeError('Base interdite.')
os.environ.update(DJANGO_SETTINGS_MODULE='config.settings',DATABASE_URL=dsn,SAUVERNDEKO_DB_READ_ONLY='0',DJANGO_SECRET_KEY='inventory-private-test',JWT_SECRET='inventory-private-test',JWT_REFRESH_SECRET='inventory-private-test')
sys.path.insert(0,str(root/'backend'))
import django;django.setup()
from django.db import transaction,IntegrityError,close_old_connections
from rest_framework.test import APIClient
from apps.core import db,repository
from apps.core.responses import APIError
from apps.core.tenancy import bind_context
from apps.accounts.authentication import actor_by_id
from apps.logistique.inventories import save,validate,snapshot
from apps.logistique.inventory_cancellation import cancel
from apps.logistique.services import mutate_line
from apps.logistique.invoices import context,write_invoice
from apps.logistique.stock_returns import return_snapshot,return_policy,annotate_return_context
checks=[]
def check(v,label):
 assert v,label
 checks.append(label)
def insert(schema,table,data,key):
 return db.one('INSERT INTO '+db.qualified(schema,table)+' ('+','.join(db.ident(k) for k in data)+') VALUES ('+','.join(['%s']*len(data))+') RETURNING '+db.ident(key)+' id',list(data.values()))['id']
for category,label in [(34,'Unités'),(40,'Catégorie produit'),(42,'Devise'),(46,'Type produit'),(64,'Type de commande')]:
 db.query('INSERT INTO referentiel."T_CategorieGenerique"("ID_CategorieGenerique","NomCategorieGenerique","ValideCategorieGenerique") OVERRIDING SYSTEM VALUE VALUES(%s,%s,true) ON CONFLICT DO NOTHING',[category,label])
 db.query('UPDATE referentiel."T_CategorieGenerique" SET "ValideCategorieGenerique"=true WHERE "ID_CategorieGenerique"=%s',[category])
def gen(category,label,abbr):return insert('referentiel','T_Generique',{'ID_CategorieGeneriqueFk':category,'NomGenerique':label+' '+uuid.uuid4().hex[:8],'AbrGenerique':abbr,'ValideGenerique':True},'ID_Generique')
unit,category,kind=gen(34,'Unité recette','pcs'),gen(40,'Catégorie recette','test'),gen(46,'Type recette','test')
entry,exit_type=gen(64,'Entrée recette','Entree'),gen(64,'Sortie recette','Sortie')
currency=db.one('SELECT "ID_Generique" id FROM referentiel."T_Generique" WHERE "ID_CategorieGeneriqueFk"=42 AND upper("AbrGenerique")=%s AND "ValideGenerique" LIMIT 1',['USD'])
currency=currency['id'] if currency else gen(42,'USD','USD')
entity=insert('systeme','T_Entite',{'NomEntite':'Recette corrections internes','EmailEntite':uuid.uuid4().hex+'@example.invalid','ValideEntite':True},'IdEntite')
uid=insert('systeme','T_Utilisateurs',{'NomUser':'Recette','PrenomUser':'Corrections','EmailUser':uuid.uuid4().hex+'@example.invalid','MotdepasseUser':'inutilisable','SexeUser':'M','ValideUser':True,'Is_Admin':True},'IdUser')
actor=bind_context(actor_by_id(uid),SimpleNamespace(headers={'X-Entite-ID':str(entity)}))
def article():return repository.mutate('T_Article',actor,{'NomArticle':'Recette interne '+uuid.uuid4().hex,'ID_TypeArticleFk':kind,'ID_CategorieArticleFk':category,'ID_UniteFk':unit,'ID_DeviseFk':currency,'QteArticle':'10','PUArticle':'10','PVArticle':'15','ValideArticle':True})['ID_Article']
def stock(pk):return db.one('SELECT "QteArticle" q FROM logistique."T_Article" WHERE "ID_Article"=%s',[pk])['q']
def draft(pk,delta):
 q=stock(pk)
 result,_=save(actor,None,{'requestId':str(uuid.uuid4()),'DateInventaire':datetime.now(timezone.utc).isoformat(),'Motif':'Comptage fictif','lignes':[{'ID_ArticleFk':pk,'QteTheorique':str(q),'QteComptee':str(q+Decimal(delta)),'Justification':'Écart fictif','Lots':[],'PUCorrection':'10'}]})
 return result

def ordinary(pk,quantity='1',incoming=False):
 command=repository.mutate('T_Commande',actor,{'ID_TypeCmdFk':entry if incoming else exit_type,'ID_DeviseFk':currency,'DateCmd':datetime.now(timezone.utc).isoformat(),'NomClientSaisi':'Tiers fictif'})
 mutate_line(actor,command['ID_Commande'],{'ID_ArticleFk':pk,'QteCmdDetail':quantity,'PUCmdDetail':'15','Lots':[]})
 return command['ID_Commande']

def reject_sql(statement,params,label,own_guard=True):
 try:
  with transaction.atomic():db.query(statement,params)
 except IntegrityError as error:check(getattr(error.__cause__.diag,'constraint_name',None)=='inventaire_bon_non_commercial' if own_guard else error.__cause__.sqlstate=='23514',label);return
 raise AssertionError(label+' accepté')

pk=article();corrections=[]
for delta in ('-2','3'):
 record=draft(pk,delta);record,_=validate(actor,record['ID_Inventaire'],{'requestId':str(uuid.uuid4()),'_version':record['Version']})
 record,_=cancel(actor,record['ID_Inventaire'],{'requestId':str(uuid.uuid4()),'_version':record['Version'],'motif':'Annulation de recette'})
 for field in ('ID_CommandeCorrectionFk','ID_CommandeAnnulationFk'):corrections.append(record['lignes'][0][field])
check(stock(pk)==10,'corrections and cancellations conserve stock')
normal=ordinary(pk);normal_entry=ordinary(pk,incoming=True)
for cmd in corrections:
 check(db.one('SELECT logistique.fn_bon_inventaire(%s) linked',[cmd])['linked'],'SQL classifies inventory document')
 info=context(actor,cmd);check(not info['meta']['canIssue'] and 'inventaire' in info['meta']['reason'].lower(),'invoice context excludes inventory')
 policy=return_policy(actor,return_snapshot(actor,cmd));check(not policy['canReturn'] and 'inventaire' in policy['reason'].lower(),'return policy excludes inventory')
 rows=annotate_return_context([{'ID_Commande':cmd}],actor);check(not rows[0]['returnContext']['canReturn'] and 'inventaire' in rows[0]['returnContext']['reason'].lower(),'batch row actions exclude inventory')
 reject_sql('INSERT INTO logistique."T_Facture"("ID_CommandeFk") VALUES(%s)',[cmd],'direct invoice refused')
 reject_sql('INSERT INTO logistique."T_RetourBon"("ID_CommandeOrigineFk","ID_CommandeRetourFk") VALUES(%s,%s)',[cmd,normal_entry],'direct source return refused')
 reject_sql('INSERT INTO logistique."T_RetourBon"("ID_CommandeOrigineFk","ID_CommandeRetourFk") VALUES(%s,%s)',[normal,cmd],'direct counterpart return refused')
 reject_sql('UPDATE logistique."T_Commande" SET "CodeFacture"=\'fac-forbidden\' WHERE "ID_Commande"=%s',[cmd],'direct invoice code refused',False)
client=APIClient();client.force_authenticate(actor)
response=client.get('/api/logistique/commandes/'+str(corrections[0])+'/facture')
check(response.status_code==200 and not response.data['meta']['canIssue'],'invoice API unavailable for inventory')
# Un document commercial normal reste facturable et son rattachement inverse est refusé.
info=context(actor,normal);check(info['meta']['canIssue'],'ordinary invoice remains available')
now=datetime.now(timezone.utc)
body={'requestId':str(uuid.uuid4()),'_version':info['meta']['revision'],'DateFacture':now.isoformat(),'DateEcheancePaiement':(now+timedelta(days=1)).isoformat(),'ID_ModePaiementFk':None,'ID_ConditionPaiementFk':None}
write_invoice(actor,normal,body,'issue');check(bool(db.one('SELECT "ID_Facture" FROM logistique."T_Facture" WHERE "ID_CommandeFk"=%s',[normal])),'ordinary invoice succeeds')
record=draft(pk,'-1')
reject_sql('UPDATE logistique."T_InventaireLigne" SET "ID_CommandeCorrectionFk"=%s WHERE "ID_InventaireFk"=%s',[normal,record['ID_Inventaire']],'issued invoice cannot become inventory correction')
check(db.one("SELECT condeferrable AND condeferred AS deferred FROM pg_constraint WHERE conname='inventaire_ligne_non_commerciale'")['deferred'],'deferred bidirectional guard installed')
# Le rattachement qui détient le verrou gagne ; l’INSERT de facture en attente doit voir son lien.
other=article();candidate=ordinary(other);count=draft(other,'-1');linked=threading.Event();release=threading.Event();started=threading.Event()
def attach_first():
 with psycopg.connect(dsn) as con:
  con.execute('UPDATE logistique."T_InventaireLigne" SET "ID_CommandeCorrectionFk"=%s WHERE "ID_InventaireFk"=%s',[candidate,count['ID_Inventaire']]);linked.set()
  if not release.wait(10):raise RuntimeError('Timeout de recette')
 return 'linked'
def invoice_second():
 if not linked.wait(10):raise RuntimeError('Timeout de recette')
 started.set()
 try:
  with psycopg.connect(dsn) as con:con.execute('INSERT INTO logistique."T_Facture"("ID_CommandeFk") VALUES(%s)',[candidate])
 except psycopg.errors.CheckViolation as error:return error.diag.constraint_name
 return 'unexpected'
with ThreadPoolExecutor(max_workers=2) as pool:
 a=pool.submit(attach_first);b=pool.submit(invoice_second)
 if not started.wait(10):raise RuntimeError('Timeout démarrage facture')
 time.sleep(.2);release.set();results=[a.result(12),b.result(12)]
check(results==['linked','inventaire_bon_non_commercial'],'concurrent invoice sees committed inventory link')
check(not db.one('SELECT "ID_Facture" FROM logistique."T_Facture" WHERE "ID_CommandeFk"=%s',[candidate]),'no concurrent invoice persisted')
print('PASS',len(checks),'contrôles corrections inventaire non commerciales.')
