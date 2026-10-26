"""Annulation d’inventaire : recette sur une base sauverndeko_test_* migrée au 20261026_03.
Crée des données fictives dans cette base dédiée ; aucun repli sur DATABASE_URL.
"""
import os,sys,uuid
from pathlib import Path
from decimal import Decimal
from urllib.parse import urlsplit
import psycopg
root=Path(__file__).resolve().parents[2]
dsn=os.environ.get('SAUVERNDEKO_TEST_DATABASE_URL','')
u=urlsplit(dsn)
if u.scheme not in {'postgres','postgresql'} or not u.path[1:].startswith('sauverndeko_test_'):
 raise RuntimeError('URL PostgreSQL de recette sauverndeko_test_* obligatoire.')
with psycopg.connect(dsn) as guard:
 if not guard.execute('SELECT current_database()').fetchone()[0].startswith('sauverndeko_test_'):
  raise RuntimeError('Base de recette dédiée obligatoire.')
os.environ.update(DJANGO_SETTINGS_MODULE='config.settings',DATABASE_URL=dsn,SAUVERNDEKO_DB_READ_ONLY='0',DJANGO_SECRET_KEY='private-test',JWT_SECRET='private-test',JWT_REFRESH_SECRET='private-test')
sys.path.insert(0,str(root/'backend'))
import django;django.setup()
from django.db import transaction,IntegrityError
from types import SimpleNamespace
from rest_framework.test import APIClient
from apps.core import db,repository
from apps.accounts.authentication import actor_by_id
from apps.core.tenancy import bind_context
from apps.core.responses import APIError
from apps.logistique.inventories import save,validate,snapshot
from apps.logistique.inventory_cancellation import cancel
from apps.logistique.services import mutate_line
from apps.logistique.quantities import for_unit
checks=[]
def check(v,name):
 assert v,name
 checks.append(name)
def insert(schema,table,values,key):
 names=list(values)
 return db.one('INSERT INTO '+db.ident(schema)+'.'+db.ident(table)+' ('+','.join(db.ident(n) for n in names)+') VALUES ('+','.join(['%s']*len(names))+') RETURNING '+db.ident(key)+' AS id',list(values.values()))['id']
for category in [34,40,42,46,64]:
 db.query('INSERT INTO referentiel."T_CategorieGenerique" ("ID_CategorieGenerique","NomCategorieGenerique","ValideCategorieGenerique") OVERRIDING SYSTEM VALUE VALUES(%s,%s,true) ON CONFLICT DO NOTHING',[category,'Catégorie de recette '+str(category)])
 db.query('UPDATE referentiel."T_CategorieGenerique" SET "ValideCategorieGenerique"=true WHERE "ID_CategorieGenerique"=%s',[category])
def generic(category,label,abbr):
 return insert('referentiel','T_Generique',{'ID_CategorieGeneriqueFk':category,'NomGenerique':label,'AbrGenerique':abbr,'ValideGenerique':True},'ID_Generique')
unit=generic(34,'Unité de recette '+uuid.uuid4().hex,'pcs')
category=generic(40,'Articles de recette '+uuid.uuid4().hex,'test')
kind=generic(46,'Type de recette '+uuid.uuid4().hex,'test')
entry=generic(64,'Entrée de recette '+uuid.uuid4().hex,'Entree')
exit_kind=generic(64,'Sortie de recette '+uuid.uuid4().hex,'Sortie')
currency=db.one('SELECT "ID_Generique" id FROM referentiel."T_Generique" WHERE "ID_CategorieGeneriqueFk"=42 AND "AbrGenerique"=%s AND "ValideGenerique" IS TRUE LIMIT 1',['USD'])
currency=currency['id'] if currency else generic(42,'USD','USD')
entity=insert('systeme','T_Entite',{'NomEntite':'Recette annulation','EmailEntite':uuid.uuid4().hex+'@example.invalid','ValideEntite':True},'IdEntite')
other_entity=insert('systeme','T_Entite',{'NomEntite':'Autre entreprise fictive','EmailEntite':uuid.uuid4().hex+'@example.invalid','ValideEntite':True},'IdEntite')
uid=insert('systeme','T_Utilisateurs',{'NomUser':'Recette','PrenomUser':'Annulation','EmailUser':uuid.uuid4().hex+'@example.invalid','MotdepasseUser':'inutilisable','SexeUser':'M','ValideUser':True,'Is_Admin':True},'IdUser')
g=bind_context(actor_by_id(uid),SimpleNamespace(headers={'X-Entite-ID':str(entity)}))
check(db.one('SELECT current_database() d')['d'].startswith('sauverndeko_test_'),'private database')
def art():
 return repository.mutate('T_Article',g,{'NomArticle':'Annulation fictive '+str(uuid.uuid4()),'ID_TypeArticleFk':kind,'ID_CategorieArticleFk':category,'ID_UniteFk':unit,'ID_DeviseFk':currency,'QteArticle':10,'PUArticle':'10.00','PVArticle':'15.00','ValideArticle':True},operation='create')['ID_Article']
def stock(a):return db.one('SELECT "QteArticle" q FROM logistique."T_Article" WHERE "ID_Article"=%s',[a])['q']
def count(a,delta,lots=[]):
 n=stock(a)
 r,_=save(g,None,{'requestId':str(uuid.uuid4()),'DateInventaire':'2026-10-26T09:00:00','Motif':'Test privé','lignes':[{'ID_ArticleFk':a,'QteTheorique':str(n),'QteComptee':str(n+Decimal(delta)),'Justification':'Test privé','Lots':lots,'PUCorrection':'10.00'}]})
 r,_=validate(g,r['ID_Inventaire'],{'requestId':str(uuid.uuid4()),'_version':r['Version']})
 return r
def req(r,reason='Correction fictive'):return {'requestId':str(uuid.uuid4()),'_version':r['Version'],'motif':reason}
def reject(fn,label):
 try:
  with transaction.atomic():fn()
 except (APIError,IntegrityError):check(True,label);return
 raise AssertionError(label+' accepted')
for delta in ['-2','3','0']:
 a=art();r=count(a,delta);body=req(r);n0=db.one('SELECT count(*) n FROM logistique."T_Mouvement"')['n']
 s,replayed=cancel(g,r['ID_Inventaire'],body)
 check(s['Etat']=='annule' and not replayed and stock(a)==10,'reverse '+delta)
 n1=db.one('SELECT count(*) n FROM logistique."T_Mouvement"')['n'];check(n1-n0==(0 if delta=='0' else 1),'one movement '+delta)
 s,replayed=cancel(g,r['ID_Inventaire'],body);check(replayed and db.one('SELECT count(*) n FROM logistique."T_Mouvement"')['n']==n1,'idempotence '+delta)
 reject(lambda:cancel(g,r['ID_Inventaire'],req(r)),'second cancellation rejected')
 reject(lambda:validate(g,r['ID_Inventaire'],{'requestId':str(uuid.uuid4()),'_version':s['Version']}),'cannot revalidate')
 if delta!='0':
  for field in ['ID_CommandeCorrectionFk','ID_CommandeAnnulationFk']:
   cid=s['lignes'][0][field]
   reject(lambda:db.query('UPDATE logistique."T_Commande" SET "RefCmd"=\'changed\' WHERE "ID_Commande"=%s',[cid]),'immutable '+field)
# Lots: receive a counted surplus, then cancel against the same lot.
a=art();lot='LOT-'+uuid.uuid4().hex[:8];r=count(a,'3',[{'NumeroLot':lot,'Quantite':'3','DatePeremptionLot':'2027-12-31'}]);s,_=cancel(g,r['ID_Inventaire'],req(r))
check(stock(a)==10,'lot reversal stock')
check(db.one('SELECT "StockLot" q FROM logistique."V_LotArticleStock" WHERE "ID_ArticleFk"=%s',[a])['q']==0,'lot reversal quantity')
# Already consumed surplus: cancellation must be entirely rolled back.
a=art();r=count(a,'3');cmd=repository.mutate('T_Commande',g,{'ID_TypeCmdFk':exit_kind,'ID_DeviseFk':currency,'DateCmd':'2026-10-26T10:00:00'},operation='create');mutate_line(g,cmd['ID_Commande'],{'ID_ArticleFk':a,'QteCmdDetail':'12','PUCmdDetail':'15.00'})
n0=db.one('SELECT count(*) n FROM logistique."T_Mouvement"')['n'];reject(lambda:cancel(g,r['ID_Inventaire'],req(r)),'insufficient stock')
check(stock(a)==1 and snapshot(g,r['ID_Inventaire'])['Etat']=='valide' and db.one('SELECT count(*) n FROM logistique."T_Mouvement"')['n']==n0,'atomic rollback')
reject(lambda:cancel(g,r['ID_Inventaire'],req(r,'')),'reason required')
b=req(r);b['_version']='stale';reject(lambda:cancel(g,r['ID_Inventaire'],b),'stale version')
other=bind_context(actor_by_id(uid),SimpleNamespace(headers={'X-Entite-ID':str(other_entity)}));reject(lambda:cancel(other,r['ID_Inventaire'],req(r)),'other entity')
c=APIClient();resp=c.post('/api/logistique/inventaires/'+str(r['ID_Inventaire'])+'/annuler',req(r),format='json');check(resp.status_code in (401,403),'authentication required')
c.force_authenticate(g);resp=c.post('/api/logistique/inventaires/'+str(r['ID_Inventaire'])+'/annuler',req(r,''),format='json');check(resp.status_code==400,'API validation')
# Precision shared reference.
with transaction.atomic():
 db.query('INSERT INTO logistique."T_PrecisionStock" ("ID_UniteFk","DecimalesStock") VALUES (%s,3) ON CONFLICT ("ID_UniteFk") DO UPDATE SET "DecimalesStock"=EXCLUDED."DecimalesStock"',[unit])
 check(for_unit('1.125',unit,'q')==Decimal('1.125'),'fractional quantity')
 a=art();db.query('UPDATE logistique."T_Article" SET "QteArticle"=10.125 WHERE "ID_Article"=%s',[a])
 reject(lambda:db.query('UPDATE logistique."T_PrecisionStock" SET "DecimalesStock"=0 WHERE "ID_UniteFk"=%s',[unit]),'incompatible precision reduction')
 transaction.set_rollback(True)
print('PASS',len(checks),checks)
