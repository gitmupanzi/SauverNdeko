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

db.query('UPDATE referentiel.\"T_Generique\" SET \"ValideGenerique\"=false WHERE \"ID_CategorieGeneriqueFk\"=64 AND \"ID_Generique\" NOT IN (%s,%s)',[entry,exit_kind])
from apps.logistique.valuation import snapshot as valuation,save as save_cost
from apps.logistique.stock_returns import preview_returns,record_return
from apps.core.registry import model
from django.test import override_settings
from rest_framework.test import APIRequestFactory,force_authenticate
from apps.logistique.valuation import ArticleValuationView,ArticleValuationExcelView
from zipfile import ZipFile
from xml.etree import ElementTree as ET

def a(q='0',price='10',curr=None):
 return repository.mutate('T_Article',g,{'NomArticle':'CUMP fictif '+uuid.uuid4().hex,'ID_TypeArticleFk':kind,'ID_CategorieArticleFk':category,'ID_UniteFk':unit,'ID_DeviseFk':curr or currency,'QteArticle':q,'PUArticle':price,'PVArticle':'99.00','ValideArticle':True},operation='create')['ID_Article']
def movement(aid,sense,qty,price,curr=None):
 c=repository.mutate('T_Commande',g,{'ID_TypeCmdFk':entry if sense==1 else exit_kind,'ID_DeviseFk':curr or currency,'DateCmd':'2026-10-26T10:00:00'},operation='create')
 mutate_line(g,c['ID_Commande'],{'ID_ArticleFk':aid,'QteCmdDetail':qty,'PUCmdDetail':price})
 return c['ID_Commande']
def position(aid):return valuation(g,aid)['positions'][0]
def equal(actual,expected,label):check(Decimal(str(actual))==Decimal(expected),label)
def rejected(fn,label):
 try:
  with transaction.atomic():fn()
 except (APIError,IntegrityError):check(True,label);return
 raise AssertionError(label+' accepted')
aid=a('10');p=position(aid);equal(p['CoutUnitaireMoyen'],'10','opening uses purchase price, not sale price')
r1=movement(aid,1,'10','20');p=position(aid);equal(p['CoutUnitaireMoyen'],'15','weighted reception cost');equal(p['ValeurStock'],'300','weighted value')
s1=movement(aid,-1,'4','100');p=position(aid);equal(p['ValeurStock'],'240','sale valued at cost, not sales price');equal(p['CoutUnitaireMoyen'],'15','outgoing mean unchanged')
movement(aid,1,'4','30');equal(position(aid)['CoutUnitaireMoyen'],'18','subsequent weighted cost')
data,meta=preview_returns(g,s1)
check(meta['canReturn'],'return available: '+str(meta.get('reason')))
rr=record_return(g,s1,{'requestId':str(uuid.uuid4()),'_version':meta['revision'],'DateCmd':'2026-10-26T12:00:00','motif':'Retour privé CUMP','lignes':[{'ID_ArticleFk':aid,'QteRetour':'2','Lots':[]}]})
p=position(aid);equal(p['ValeurStock'],'390','partial return at original cost');equal(p['QteValorisee'],'22','quantity return once');equal(p['CoutUnitaireMoyen'],'17.727273','mean after partial return')
last=valuation(g,aid)['movements'][0];equal(last['CoutUnitaire'],'15','return historical unit cost')
# Revaluation keeps quantities and costs of old exits for future returns.
old_stock=stock(aid) if 'stock' in globals() else db.one('SELECT "QteArticle" q FROM logistique."T_Article" WHERE "ID_Article"=%s',[aid])['q']
body={'deviseId':currency,'coutUnitaire':'20.123456','motif':'Coût confirmé pour recette','_version':p['Version'],'requestId':str(uuid.uuid4())}
new,replay=save_cost(g,aid,body);check(not replay,'first revaluation');equal(new['positions'][0]['ValeurStock'],'442.72','revalued current stock');equal(db.one('SELECT "QteArticle" q FROM logistique."T_Article" WHERE "ID_Article"=%s',[aid])['q'],str(old_stock),'no extra stock movement')
new,replay=save_cost(g,aid,body);check(replay,'same request is idempotent')
rejected(lambda:save_cost(g,aid,{**body,'coutUnitaire':'21'}),'different content same request rejected')
rejected(lambda:save_cost(g,aid,{**body,'requestId':str(uuid.uuid4())}),'stale revision rejected')
rejected(lambda:save_cost(g,aid,{**body,'_version':position(aid)['Version'],'motif':'','requestId':str(uuid.uuid4())}),'reason required')
rejected(lambda:save_cost(g,aid,{**body,'_version':position(aid)['Version'],'coutUnitaire':'1.1234567','requestId':str(uuid.uuid4())}),'cost precision enforced')
rejected(lambda:db.query('UPDATE logistique."T_ValorisationOuverture" SET "CoutOuverture"=1 WHERE "ID_ArticleFk"=%s',[aid]),'direct opening update protected')
rejected(lambda:db.query('DELETE FROM logistique."T_ValorisationEvenement" WHERE "ID_ArticleFk"=%s',[aid]),'journal immutable')
# A remaining return still uses its historical exit cost after revaluation.
data,meta=preview_returns(g,s1)
record_return(g,s1,{'requestId':str(uuid.uuid4()),'_version':meta['revision'],'DateCmd':'2026-10-26T12:01:00','motif':'Second retour privé CUMP','lignes':[{'ID_ArticleFk':aid,'QteRetour':'1','Lots':[]}]})
equal(valuation(g,aid)['movements'][0]['CoutUnitaire'],'15','pre-revaluation exit cost retained')
other=bind_context(actor_by_id(uid),SimpleNamespace(headers={'X-Entite-ID':str(other_entity)}))
rejected(lambda:valuation(other,aid),'cross company read denied')
# Retroactive commercial edit after the opening recomputes costs, while confirmed opening source stays protected.
fresh=a('0');r=movement(fresh,1,'10','10');movement(fresh,1,'10','20');movement(fresh,-1,'5','99');equal(position(fresh)['ValeurStock'],'225','initial retroactive scenario')
row=repository.get_record(model('T_CommandeDetail'),g,{'ID_CmdFk':r,'ID_ArticleFk':fresh})
from apps.logistique.document_rules import revision as document_revision
from apps.logistique.lots import line_lots
mutate_line(g,r,{'QteCmdDetail':'10','PUCmdDetail':'30','_version':document_revision({**row,'Lots':line_lots(r,fresh)},'ligne')},article_id=fresh,operation='update')
equal(position(fresh)['ValeurStock'],'375','retroactive purchase correction recalculates following costs')
# Decimal arithmetic, zero stock and separate currency balances.
db.query('UPDATE referentiel."T_Generique" SET "DecimalesStock"=3 WHERE "ID_Generique"=%s',[unit])
fraction=a('0');movement(fraction,1,'1.125','0.10');movement(fraction,-1,'0.125','5');equal(position(fraction)['CoutUnitaireMoyen'],'0.1','fraction mean exact');equal(position(fraction)['QteValorisee'],'1','fraction stock exact');movement(fraction,-1,'1','5');equal(position(fraction)['ValeurStock'],'0','zero stock no residual value')
second_currency=generic(42,'Monnaie fictive','ZQT');movement(fresh,1,'2','7',second_currency)
check(len(valuation(g,fresh)['positions'])==2,'currencies remain separate')
# Export and route permissions use the same parent, no hidden company rows.
factory=APIRequestFactory();request=factory.get('/api/logistique/articles/'+str(aid)+'/valorisation');force_authenticate(request,user=g)
response=ArticleValuationView.as_view()(request,pk=aid);check(response.status_code==200,'valuation GET route')
request=factory.get('/api/logistique/articles/'+str(aid)+'/valorisation/export.xlsx');force_authenticate(request,user=g)
response=ArticleValuationExcelView.as_view()(request,pk=aid);check(response.status_code==200,'valuation Excel route')
from io import BytesIO
book=ZipFile(BytesIO(b''.join(response.streaming_content)));content=book.read('xl/worksheets/sheet1.xml').decode();check('Mouvement' in content,'Excel contains column header');book.close();response.close()
with override_settings(SAUVERNDEKO_DB_READ_ONLY=True,DB_READ_ONLY=True):
 rejected(lambda:save_cost(g,aid,{**body,'_version':position(aid)['Version'],'requestId':str(uuid.uuid4())}),'read only blocks revaluation')

# Concurrent repeated submission produces a single event and no quantity movement.
from concurrent.futures import ThreadPoolExecutor
from django.db import connections
body2={**body,'_version':position(aid)['Version'],'requestId':str(uuid.uuid4()),'coutUnitaire':'19.25'}
def concurrent_save(_):
 try:return save_cost(g,aid,body2)[1]
 finally:connections.close_all()
with ThreadPoolExecutor(max_workers=2) as workers:results=list(workers.map(concurrent_save,range(2)))
check(sorted(results)==[False,True],'concurrent repeat one event')
check(db.one('SELECT count(*) n FROM logistique."T_ValorisationEvenement" WHERE "RequestId"=%s',[body2['requestId']])['n']==1,'one financial proof for concurrent repeat')
# Historic migration does not invent an opening purchase cost.
legacy=a('10');legacy_sale=movement(legacy,-1,'2','99')
mid=db.one('SELECT max("ID_Mvt") id FROM logistique."T_Mouvement" WHERE "ID_ArticleFk"=%s',[legacy])['id']
with transaction.atomic():
 db.query("SELECT set_config('logistique.allow_valuation_write','on',true)")
 db.query('INSERT INTO logistique."T_ValorisationOuverture"("ID_ArticleFk","ID_DeviseFk","IdEntiteFk","ID_MvtArrete","QuantiteOuverture") VALUES(%s,%s,%s,%s,8)',[legacy,currency,entity,mid])
lp=position(legacy);check(lp['EtatValorisation']=='À initialiser' and lp['CoutUnitaireMoyen'] is None and lp['ValeurStock'] is None,'unknown opening stays unknown')
save_cost(g,legacy,{'deviseId':currency,'coutUnitaire':'10','motif':'Reprise de recette','_version':lp['Version'],'requestId':str(uuid.uuid4())})
_,meta=preview_returns(g,legacy_sale)
record_return(g,legacy_sale,{'requestId':str(uuid.uuid4()),'_version':meta['revision'],'DateCmd':'2026-10-26T12:02:00','motif':'Retour historique privé','lignes':[{'ID_ArticleFk':legacy,'QteRetour':'1','Lots':[]}]})
lp=position(legacy);check(lp['EtatValorisation']=='Coût à vérifier' and lp['CoutUnitaireMoyen'] is None,'unknown historical return cost never uses sale price')

# Surplus at zero stock has only an indicative catalogue price and must not validate an accounting cost.
from apps.logistique.inventories import save as count_save,validate as count_validate
empty=a('0',price='987.65')
count,_=count_save(g,None,{'requestId':str(uuid.uuid4()),'DateInventaire':'2026-10-26T09:00:00','Motif':'Surplus fictif','lignes':[{'ID_ArticleFk':empty,'QteTheorique':'0','QteComptee':'2','Justification':'Comptage fictif','Lots':[],'PUCorrection':'987.65'}]})
count,_=count_validate(g,count['ID_Inventaire'],{'requestId':str(uuid.uuid4()),'_version':count['Version']})
ep=position(empty);check(ep['EtatValorisation']=='Coût à vérifier' and ep['CoutUnitaireMoyen'] is None and ep['ValeurStock'] is None,'zero-stock inventory surplus does not turn catalogue into confirmed cost')

# A stock change between packet retrieval and serialization cannot update an old packet's revision.
from unittest.mock import patch
race=a('10');original_query=db.query;interleaved=[False]
def changing_query(sql,params=()):
 result=original_query(sql,params)
 if 'V_ValorisationStock' in sql and not interleaved[0]:
  interleaved[0]=True;movement(race,1,'10','20')
 return result
with patch.object(db,'query',side_effect=changing_query):stale=position(race)
current=position(race)
equal(stale['QteValorisee'],'10','snapshot holds displayed quantity before concurrent arrival')
equal(current['QteValorisee'],'20','next snapshot sees arrival')
check(stale['Version']!=current['Version'],'old display never receives new stock revision')
rejected(lambda:save_cost(g,race,{'deviseId':currency,'coutUnitaire':'10','motif':'Coût devenu obsolète','_version':stale['Version'],'requestId':str(uuid.uuid4())}),'cannot approve unseen stock')
# Fractional historical mean retained beyond display precision across a revaluation.
precise=a('0');movement(precise,1,'100000','1');movement(precise,1,'200000','0');precise_sale=movement(precise,-1,'100000','2')
pp=position(precise);save_cost(g,precise,{'deviseId':currency,'coutUnitaire':'1','motif':'Arrêté fictif précis','_version':pp['Version'],'requestId':str(uuid.uuid4())})
_,meta=preview_returns(g,precise_sale)
record_return(g,precise_sale,{'requestId':str(uuid.uuid4()),'_version':meta['revision'],'DateCmd':'2026-10-26T12:03:00','motif':'Retour de précision','lignes':[{'ID_ArticleFk':precise,'QteRetour':'100000','Lots':[]}]})
equal(position(precise)['ValeurStock'],'233333.33','historical return retains full internal cost after revaluation')

# Stored procedure enforces the same source revision even without the Python check.
from django.db import DatabaseError
stale_sql=position(race);movement(race,1,'1','30')
try:
 with transaction.atomic():db.query('SELECT logistique.enregistrer_cout_ouverture(%s,%s,%s,%s,%s,%s,%s,%s,%s)',[race,currency,10,'Révision SQL ancienne',uid,int(stale_sql['Version'].split(':')[0]),str(uuid.uuid4()),entity,stale_sql['Version']])
except DatabaseError as error:check(getattr(error.__cause__,'sqlstate',None)=='40001','stored procedure rejects stale stock revision')
else:raise AssertionError('SQL stale revision accepted')
print('PASS',len(checks),'CUMP regression checks on private database')
