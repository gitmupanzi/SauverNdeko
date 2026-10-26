"""Péremption par lot : recette sur une base sauverndeko_test_* migrée au 20261026_05.
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
entity=insert('systeme','T_Entite',{'NomEntite':'Recette péremption','EmailEntite':uuid.uuid4().hex+'@example.invalid','ValideEntite':True},'IdEntite')
other_entity=insert('systeme','T_Entite',{'NomEntite':'Autre entreprise fictive','EmailEntite':uuid.uuid4().hex+'@example.invalid','ValideEntite':True},'IdEntite')
uid=insert('systeme','T_Utilisateurs',{'NomUser':'Recette','PrenomUser':'Annulation','EmailUser':uuid.uuid4().hex+'@example.invalid','MotdepasseUser':'inutilisable','SexeUser':'M','ValideUser':True,'Is_Admin':True},'IdUser')
g=bind_context(actor_by_id(uid),SimpleNamespace(headers={'X-Entite-ID':str(entity)}))
check(db.one('SELECT current_database() d')['d'].startswith('sauverndeko_test_'),'private database')
from datetime import date,timedelta
from apps.logistique.expiry import policy,update
from apps.logistique.lot_fefo import proposal
from apps.logistique.reads import register_source
from apps.logistique.lots import sync_movement

def article(qty=0,expiry=None,days=None):
 return repository.mutate('T_Article',g,{'NomArticle':'Conservation fictive '+str(uuid.uuid4()),'ID_TypeArticleFk':kind,'ID_CategorieArticleFk':category,'ID_UniteFk':unit,'ID_DeviseFk':currency,'QteArticle':qty,'PUArticle':'10.00','PVArticle':'15.00','ValideArticle':True,'DatePeremptionArticle':expiry,'NbreJoursAlerteArticle':days},operation='create')['ID_Article']

def bon(a,qty,lots,incoming=True):
 h=repository.mutate('T_Commande',g,{'ID_TypeCmdFk':entry if incoming else exit_kind,'ID_DeviseFk':currency,'DateCmd':date.today().isoformat()+'T09:00:00'},operation='create')
 with transaction.atomic():r=mutate_line(g,h['ID_Commande'],{'ID_ArticleFk':a,'QteCmdDetail':str(qty),'PUCmdDetail':'10.00','Lots':lots})
 return h,r

def stock(a):return db.one('SELECT "QteArticle" q FROM logistique."T_Article" WHERE "ID_Article"=%s',[a])['q']
def conservation(a):return db.one('SELECT * FROM logistique."V_ArticlePeremption" WHERE "ID_Article"=%s',[a])
def lot(n,qty,delta=None,reason=None):return {'NumeroLot':n,'Quantite':str(qty),'DatePeremptionLot':(date.today()+timedelta(days=delta)).isoformat() if delta is not None else None,**({'MotifDerogationPeremption':reason} if reason else {})}
def reject(fn,code,name):
 try:fn();raise AssertionError('Expected refusal: '+name)
 except APIError as e:check(e.default_code==code,name)

p=policy(g);check(p['AlertePeremptionJours']==30 and p['BloquerLotsPerimes'] is False,'Informative default per entity')
a=article(expiry=(date.today()-timedelta(days=40)).isoformat())
h,_=bon(a,10,[lot('EXP',3,-1),lot('SOON',2,5),lot('VALID',4,100),lot('UNDATED',1)])
r=conservation(a)
check(r['StockPerime']==3,'Only expired lot remaining stock')
check(r['StockProchePeremption']==2,'Near expiry remaining stock')
check(r['StockSansDatePeremption']==1,'Undated remaining lot reported')
check(r['EstPerime'] and r['EstAlertePeremption'],'Mixed stock has simultaneous expired and near flags')
check(r['StockSansLot']==0,'Allocated stock excludes general expiry date')
v=db.one('SELECT * FROM logistique."V_Article" WHERE "ID_Article"=%s',[a])
check(v['StockPerime']==r['StockPerime'] and v['EstAlertePeremption'],'Article view shares source')
check(r['DateProchainePeremption']==date.today()-timedelta(days=1),'Earliest remaining date')
suggest=proposal(g,a,{'quantite':'5'})
check(all(not x['EstPerime'] for x in suggest['Lots']),'FEFO excludes expired by default')
check(suggest['Lots'][0]['NumeroLot']=='SOON','FEFO earliest expiry first')
bon(a,3,[lot('EXP',3,-1)],False)
r=conservation(a);check(r['StockPerime']==0 and not r['EstPerime'],'Exhausted expired lot disappears from alert')
check(r['StockProchePeremption']==2,'Other lot alert preserved')
check(db.one('SELECT count(*) n FROM logistique."T_Mouvement" WHERE "ID_ArticleFk"=%s',[a])['n']==2,'One movement per receipt or issue')
b=article(4,(date.today()-timedelta(days=1)).isoformat())
check(conservation(b)['StockPerime']==4,'Without-lot stock uses general date')
z=article(0,(date.today()-timedelta(days=1)).isoformat());check(not conservation(z)['EstPerime'],'Zero stock is not expired stock')
c=article();bon(c,2,[lot('EDGE',2,35)])
check(not conservation(c)['EstAlertePeremption'],'Entity threshold respected')
updated=update(g,{'IdEntite':entity,'AlertePeremptionJours':40,'BloquerLotsPerimes':True,'_version':p['_version']})
check(conservation(c)['EstAlertePeremption'],'Entity threshold changes all derived views')
reject(lambda:update(g,{'IdEntite':entity,'AlertePeremptionJours':20,'BloquerLotsPerimes':False,'_version':p['_version']}),'VERSION_CONFLICT','Stale policy version refused')
d=article(days=3);bon(d,1,[lot('SPECIFIC',1,5)]);check(not conservation(d)['EstAlertePeremption'],'Article threshold overrides company default')
e=article();bon(e,4,[lot('BLOCK',4,-2)])
reject(lambda:bon(e,1,[lot('BLOCK',1,-2)],False),'EXPIRED_LOT_BLOCKED','Blocked expired issue needs reason')
check(stock(e)==4,'Refused issue rolled back stock')
h2,row=bon(e,1,[lot('BLOCK',1,-2,'Usage autorisé après contrôle écrit')],False)
waiver=db.one('SELECT ml.* FROM logistique."T_MouvementLot" ml JOIN logistique."T_Mouvement" m ON m."ID_Mvt"=ml."ID_MvtFk" WHERE m."ID_cmdFk"=%s',[h2['ID_Commande']])
check(waiver['ID_DerogationUserFk']==uid and waiver['DateDerogationPeremption'] is not None,'Waiver retains actual administrator and server timestamp')
check(waiver['MotifDerogationPeremption']=='Usage autorisé après contrôle écrit','Waiver retains reason')
check(stock(e)==3,'Authorized waiver has exactly one stock effect')
reject(lambda:proposal(g,e,{'quantite':'1','inclurePerimes':'unexpected'}),'INVALID_REQUEST','Invalid FEFO option refused')
fake=SimpleNamespace(global_admin=False,pk=uid)
movement=db.one('SELECT "ID_Mvt" id FROM logistique."T_Mouvement" WHERE "ID_cmdFk"=%s',[h2['ID_Commande']])['id']
try:
 with transaction.atomic():sync_movement(e,movement,[lot('BLOCK',1,-2,'Tentative sans droits suffisants')],Decimal('1'),actor=fake)
 raise AssertionError('Expected permission refusal')
except APIError as error:check(error.default_code=='EXPIRY_OVERRIDE_FORBIDDEN','Non-global override refused')
check(stock(e)==3,'Unauthorized override leaves stock unchanged')
g2=bind_context(actor_by_id(uid),SimpleNamespace(headers={'X-Entite-ID':str(other_entity)}))
check(policy(g2)['BloquerLotsPerimes'] is False and policy(g2)['AlertePeremptionJours']==30,'Other company policy remains independent')
reject(lambda:proposal(g2,e,{'quantite':'1'}),'NOT_FOUND','Cross-company lot proposal refused')
obj,condition,filters=register_source('articles',{'peremption':'alerte'})
check('EstAlertePeremption' in condition and 'EstPerime' not in condition,'Near filter includes mixed article stock')
obj,condition,filters=register_source('articles',{'peremption':'non-renseignee'})
check('StockSansDatePeremption' in condition,'Unknown expiry filter uses remaining stock')
check(db.one("SELECT count(*) n FROM systeme.\"T_Audit_Log\" WHERE \"Operation\"='EXPIRY_POLICY' AND \"IdEntiteFk\"=%s",[entity])['n']==1,'Policy change audited')
reject(lambda:update(g,{'IdEntite':other_entity,'AlertePeremptionJours':20,'BloquerLotsPerimes':False,'_version':updated['_version']}),'ENTITY_MISMATCH','Cross-context policy write refused')
try:
 with transaction.atomic():
  db.query('DELETE FROM logistique."T_MouvementLot" WHERE "ID_MvtFk"=%s',[movement])
  db.query('INSERT INTO logistique."T_MouvementLot" ("ID_MvtFk","ID_LotArticleFk","Quantite") VALUES (%s,%s,%s)',[movement,waiver['ID_LotArticleFk'],1])
 raise AssertionError('SQL expiry bypass accepted')
except IntegrityError:check(True,'SQL trigger blocks expired lot without override')
check(stock(e)==3,'SQL refusal preserves stock and history')
db.query('UPDATE logistique."T_LotArticle" SET "Actif"=false WHERE "ID_ArticleFk"=%s',[e])
check(conservation(e)['StockPerime']==3,'Archived lot with remaining stock still alerts')
check(proposal(g,e,{'quantite':'1'})['Lots']==[],'Archived lots never proposed')
# Annuler une correction d’entrée périmée : correction inverse exacte et dérogation nominative.
k=article();inventory,_=save(g,None,{'requestId':str(uuid.uuid4()),'DateInventaire':date.today().isoformat()+'T09:00:00','Motif':'Recomptage de recette','lignes':[{'ID_ArticleFk':k,'QteTheorique':'0','QteComptee':'2','Justification':'Deux unités effectivement comptées','Lots':[lot('COUNT-EXPIRED',2,-1)],'PUCorrection':'10.00'}]})
validated,_=validate(g,inventory['ID_Inventaire'],{'requestId':str(uuid.uuid4()),'_version':str(inventory['Version'])})
local_id=insert('systeme','T_Utilisateurs',{'NomUser':'Recette locale','PrenomUser':'Lots','EmailUser':uuid.uuid4().hex+'@example.invalid','MotdepasseUser':'inutilisable','SexeUser':'M','ValideUser':True,'Is_Admin':False,'Is_staff':True,'IdEntiteFk':entity},'IdUser')
local=actor_by_id(local_id);local._module_access={'modules':{'logistique':{'canRead':True,'canManage':True,'canExport':True}}}
request={'requestId':str(uuid.uuid4()),'_version':str(validated['Version']),'motif':'Comptage corrigé après contrôle contradictoire'}
reject(lambda:cancel(local,inventory['ID_Inventaire'],request),'EXPIRED_LOT_OVERRIDE_REQUIRED','Local cancellation cannot override expired-lot block')
check(stock(k)==2 and snapshot(g,inventory['ID_Inventaire'])['Etat']=='valide','Refused compensation remains atomic')
cancelled,replay=cancel(g,inventory['ID_Inventaire'],request)
check(not replay and cancelled['Etat']=='annule' and stock(k)==0,'Global compensation restores exact opening stock')
inverse=db.one('SELECT ml.* FROM logistique."T_InventaireLigne" il JOIN logistique."T_Mouvement" m ON m."ID_cmdFk"=il."ID_CommandeAnnulationFk" JOIN logistique."T_MouvementLot" ml ON ml."ID_MvtFk"=m."ID_Mvt" WHERE il."ID_InventaireFk"=%s',[inventory['ID_Inventaire']])
check(inverse['ID_DerogationUserFk']==uid and request['motif'] in inverse['MotifDerogationPeremption'],'Compensation waiver retains reason and actual actor')
again,replay=cancel(g,inventory['ID_Inventaire'],request)
check(replay and stock(k)==0 and db.one('SELECT count(*) n FROM logistique."T_Mouvement" WHERE "ID_ArticleFk"=%s',[k])['n']==2,'Compensation replay never duplicates a movement')
m=article();bon(m,3,[lot('COUNT-REMOVE',3,-1)])
counted,_=save(g,None,{'requestId':str(uuid.uuid4()),'DateInventaire':date.today().isoformat()+'T09:00:00','Motif':'Retrait constaté en recette','lignes':[{'ID_ArticleFk':m,'QteTheorique':'3','QteComptee':'2','Justification':'Une unité absente au recomptage','Lots':[lot('COUNT-REMOVE',1,-1,'Écart physique vérifié par l’administrateur')],'PUCorrection':'10.00'}]})
validation_request={'requestId':str(uuid.uuid4()),'_version':str(counted['Version'])}
reject(lambda:validate(local,counted['ID_Inventaire'],validation_request),'EXPIRY_OVERRIDE_FORBIDDEN','Local validator cannot reuse a saved global waiver reason')
check(stock(m)==3,'Refused inventory validation does not change stock')
validated,_=validate(g,counted['ID_Inventaire'],validation_request)
check(stock(m)==2 and validated['Etat']=='valide','Saved waiver reason reaches inventory correction service')
tz=article();bon(tz,2,[lot('BUSINESS-DATE',2,-1)])
with transaction.atomic():
 db.query("SET LOCAL TimeZone='Pacific/Midway'")
 check(conservation(tz)['StockPerime']==2,'Business expiry date independent of connection time zone')
 check(proposal(g,tz,{'quantite':'1'})['Lots']==[],'FEFO shares Kinshasa business day')
 reject(lambda:bon(tz,1,[lot('BUSINESS-DATE',1,-1)],False),'EXPIRED_LOT_BLOCKED','API and SQL expiry agree across time zones')
print('PASS',len(checks),'contrôles de péremption sur base privée.')
