"""Registre des lots : recette sur une base sauverndeko_test_* migrée aux 03, 05 et 07.
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


from apps.logistique.reads import register
from apps.logistique.lot_register import lot_detail,lot_movements,lot_movement_workbook
from apps.logistique.excel import register_workbook
from apps.core.registry import view
from zipfile import ZipFile
from xml.etree import ElementTree as ET

def only(a,**filters):return register(g,'lots',{'articleId':str(a),**filters})
def as_rows(stream):
 stream.seek(0)
 with ZipFile(stream) as zipped:
  sheet=ET.fromstring(zipped.read('xl/worksheets/sheet1.xml'))
  ns={'s':'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
  return [[cell.find('s:is/s:t',ns).text if cell.find('s:is/s:t',ns) is not None else cell.find('s:v',ns).text if cell.find('s:v',ns) is not None else None for cell in row.findall('s:c',ns)] for row in sheet.findall('s:sheetData/s:row',ns)]

marker='REGISTRE-'+uuid.uuid4().hex
a=article()
h,_=bon(a,12,[lot(marker+'-EXPIRED',2,-1),lot(marker+'-NEAR',3,5),lot(marker+'-VALID',4,120),lot(marker+'-NO-DATE',3)])
bon(a,2,[lot(marker+'-EXPIRED',2,-1)],False)
lots=db.query('SELECT * FROM logistique."V_RegistreLots" WHERE "ID_ArticleFk"=%s ORDER BY "NumeroLot"',[a]);ids={row['NumeroLot'].split('-')[-1]:row['ID_LotArticle'] for row in lots}
expired=next(row for row in lots if row['NumeroLot'].endswith('EXPIRED'));near=next(row for row in lots if row['NumeroLot'].endswith('NEAR'));valid=next(row for row in lots if row['NumeroLot'].endswith('VALID'))
db.query('UPDATE logistique."T_LotArticle" SET "Actif"=false WHERE "ID_LotArticle"=%s',[valid['ID_LotArticle']])
r,meta=only(a)
check(len(r)==4 and meta['filteredCount']==4,'Default includes exhausted and archived lots')
check(meta['summary']['total']==4 and meta['summary']['articles']==1,'Summary counts lots and articles')
check(meta['summary']['epuises']==1 and meta['summary']['perimes']==0 and meta['summary']['proches']==1,'Summary distinguishes exhausted expired history and remaining alerts')
check(all(x['AbrUnite']=='pcs' and x['Unite']=='pcs' for x in r),'All quantities carry unit abbreviation')
check(expired['StockLot']==0 and expired['QuantiteEntree']==2 and expired['QuantiteSortie']==2,'Lot stock is actual entries minus exits')
check(only(a,stockState='epuise')[1]['filteredCount']==1,'Exhausted filter')
check(only(a,stockState='disponible')[1]['filteredCount']==3,'Available filter')
check(only(a,stockState='incoherent')[1]['filteredCount']==0,'Negative filter does not coerce zero')
check(only(a,peremption='perime')[1]['filteredCount']==1,'Expired filter includes exhausted historical lot')
check(only(a,peremption='alerte')[1]['filteredCount']==1,'Near filter')
check(only(a,peremption='valide')[1]['filteredCount']==1,'Valid filter')
check(only(a,peremption='non-renseignee')[1]['filteredCount']==1,'Undated filter')
check(only(a,archive='archive')[1]['filteredCount']==1 and only(a,archive='actif')[1]['filteredCount']==3,'Archival filter independent of remaining stock')
check(only(a,categorieId=str(category))[1]['filteredCount']==4,'Category FK filter')
check(only(a,articleTypeId=str(kind))[1]['filteredCount']==4,'Type FK filter')
check(only(a,q=marker+'-NEAR')[1]['filteredCount']==1,'Search runs server side across all matching lots')
first,m1=only(a,take='2',skip='0',sortBy='NumeroLot',sortDir='asc');second,m2=only(a,take='2',skip='2',sortBy='NumeroLot',sortDir='asc')
check(len(first)==2 and len(second)==2 and not ({x['ID_LotArticle'] for x in first}&{x['ID_LotArticle'] for x in second}),'Pagination stable and disjoint')
check(m1['filteredCount']==m2['filteredCount']==4,'Counts exhaustive beyond page')
reverse,_=only(a,take='100',sortBy='NumeroLot',sortDir='desc');check(reverse[0]['NumeroLot']>reverse[-1]['NumeroLot'],'Server sort')
check(only(a,columnFilters='{"StockLot":">=4"}')[1]['filteredCount']==1,'Column filters run on server')
check(lot_detail(g,expired['ID_LotArticle'])['StockLot']==Decimal('0'),'Header returns exact zero without fallback')
journal,jm=lot_movements(g,expired['ID_LotArticle'],{'take':'1','skip':'0','sortBy':'DateMvt','sortDir':'desc'})
check(len(journal)==1 and jm['filteredCount']==2 and jm['totalCount']==2,'Lot movement journal counts only selected lot and paginates')
check(all(x['ID_LotArticleFk']==expired['ID_LotArticle'] for x in journal),'Lot journal never includes another lot')
check(lot_movements(g,expired['ID_LotArticle'],{'sens':'sortie'})[1]['filteredCount']==1,'Lot journal direction filter')
check(lot_movements(g,near['ID_LotArticle'],{})[1]['filteredCount']==1,'Other lot journal independent')

uid_local=insert('systeme','T_Utilisateurs',{'NomUser':'Recette','PrenomUser':'Local','EmailUser':uuid.uuid4().hex+'@example.invalid','MotdepasseUser':'inutilisable','SexeUser':'M','ValideUser':True,'Is_Admin':False,'Is_staff':True,'IdEntiteFk':entity},'IdUser')
local=actor_by_id(uid_local);local._module_access={'modules':{'logistique':{'canRead':True,'canManage':True,'canExport':True}}}
check(lot_detail(local,near['ID_LotArticle'])['ID_LotArticle']==near['ID_LotArticle'],'Enterprise colleague reads same lot')
other=bind_context(actor_by_id(uid),SimpleNamespace(headers={'X-Entite-ID':str(other_entity)}))
reject(lambda:lot_detail(other,near['ID_LotArticle']),'NOT_FOUND','Other entity cannot read lot header')
reject(lambda:lot_movements(other,near['ID_LotArticle'],{}),'NOT_FOUND','Other entity cannot read lot journal')
check(register(other,'lots',{'lotId':str(near['ID_LotArticle'])})[1]['filteredCount']==0,'Other entity register cannot see lot')
reject(lambda:lot_movement_workbook(other,near['ID_LotArticle'],{}),'NOT_FOUND','Other entity cannot export journal')
stream,count,name=register_workbook(other,'lots',{'lotId':str(near['ID_LotArticle'])});check(count==0,'Other entity export is scoped identically');stream.close()
unbound=actor_by_id(uid);check(lot_detail(unbound,near['ID_LotArticle'])['ID_LotArticle']==near['ID_LotArticle'],'Global unscoped account keeps access')
original_actor=g;g=other
foreign_article=article();bon(foreign_article,1,[lot(marker+'-FOREIGN',1)])
foreign_lot=db.one('SELECT "ID_LotArticle" id FROM logistique."V_RegistreLots" WHERE "ID_ArticleFk"=%s',[foreign_article])['id'];g=original_actor
reject(lambda:lot_detail(local,foreign_lot),'NOT_FOUND','Local account cannot read foreign existing lot')
check(register(local,'lots',{'lotId':str(foreign_lot)})[1]['filteredCount']==0,'Local register excludes foreign existing lot')
check(register(unbound,'lots',{'q':marker})[1]['filteredCount']==5,'Global unscoped register includes both test enterprises')
check(lot_detail(unbound,foreign_lot)['IdEntiteFk']==other_entity,'Global header can read second enterprise')
# Quantités fractionnaires et unités distinctes : aucun total arithmétique entre lots.
original_unit=unit;unit=generic(34,'Masse de recette '+uuid.uuid4().hex,'kg')
db.query('UPDATE referentiel."T_Generique" SET "DecimalesStock"=3 WHERE "ID_Generique"=%s',[unit])
fractional=article();bon(fractional,'1.250',[lot(marker+'-MASS',Decimal('1.250'))]);unit=original_unit
fractional_rows,_=only(fractional);check(fractional_rows[0]['StockLot']==Decimal('1.250') and fractional_rows[0]['AbrUnite']=='kg','Fractional lot stock stays exact with its unit')
stream,count,name=register_workbook(g,'lots',{'articleId':str(fractional),'columns':'["NumeroLot","StockLot"]'});fractional_xlsx=as_rows(stream);stream.close()
check(Decimal(fractional_xlsx[1][1])==Decimal('1.250') and fractional_xlsx[1][2]=='kg','Fractional XLSX quantity is native numeric with kg')


stream,count,name=register_workbook(g,'lots',{'articleId':str(a),'stockState':'disponible','columns':'["NumeroLot","StockLot"]','sortBy':'NumeroLot','sortDir':'asc'});xlsx=as_rows(stream);stream.close()
check(count==3 and len(xlsx)==4,'Excel exports complete filtered population, not only a page')
check(xlsx[0]==['N° de lot','Stock du lot','Unité'],'Excel header is row 1 with mandatory unit')
check(all(row[-1]=='pcs' for row in xlsx[1:]),'Excel unit abbreviations preserved')
stream,count,name=lot_movement_workbook(g,expired['ID_LotArticle'],{'columns':'["DateMvt","NumeroLot","Quantite"]'});xlsx=as_rows(stream);stream.close();check(count==2 and xlsx[0][-1]=='Unité','Lot journal Excel exhaustive and typed with unit')
for criteria in [{'stockState':'DROP'},{'archive':'false'},{'peremption':'none'},{'articleState':'none'},{'articleId':'-1'},{'take':'0'},{'sortBy':'no_column'},{'columnFilters':'{"PhotoArticle":"anything"}'},{'extra':'anything'},{'dateFrom':'2026-10-27','dateTo':'2026-10-26'}]:
 try:only(a,**criteria);raise AssertionError('Criterion accepted '+repr(criteria))
 except APIError:checks.append('Invalid criterion refused '+str(next(iter(criteria))))
reject(lambda:lot_movements(g,expired['ID_LotArticle'],{'lotId':str(near['ID_LotArticle'])}),'INVALID_REQUEST','Journal target cannot be overridden')
reject(lambda:lot_detail(g,'-1'),'INVALID_REQUEST','Negative lot identity refused')
check(db.one('SELECT count(*) n FROM logistique."T_Mouvement" WHERE "ID_ArticleFk"=%s',[a])['n']==2,'Reads and exports never create stock movements')
check(db.one("SELECT count(*) n FROM pg_class WHERE oid IN ('logistique.\"V_RegistreLots\"'::regclass,'logistique.\"V_RegistreMouvementLot\"'::regclass) AND obj_description(oid,'pg_class') IS NOT NULL")['n']==2,'Views documented')
from rest_framework.test import APIRequestFactory,force_authenticate
from apps.logistique.lot_register import LotDetailView,LotMovementsView,LotMovementsExcelView
from apps.logistique.reads import RegisterReadView
from apps.logistique.excel import RegisterExcelView
factory=APIRequestFactory()
def request(target,path,actor=g,**kwargs):
 req=factory.get(path)
 if actor is not None:force_authenticate(req,user=actor)
 return target.as_view()(req,**kwargs)
http=request(LotDetailView,'/api/logistique/lots/'+str(near['ID_LotArticle']),pk=near['ID_LotArticle']);http.render();check(http.status_code==200 and b'NumeroLot' in http.content,'HTTP header serializes exact JSON')
http=request(LotMovementsView,'/api/logistique/lots/'+str(expired['ID_LotArticle'])+'/mouvements?take=1',pk=expired['ID_LotArticle']);http.render();check(http.status_code==200 and http.data['meta']['filteredCount']==2,'HTTP journal paginated')
http=request(LotDetailView,'/api/logistique/lots/'+str(near['ID_LotArticle']),other,pk=near['ID_LotArticle']);check(http.status_code==404,'HTTP cross entity header denied')
http=request(LotDetailView,'/api/logistique/lots/'+str(near['ID_LotArticle']),None,pk=near['ID_LotArticle']);check(http.status_code in {401,403},'HTTP unauthenticated header refused')
http=request(RegisterReadView,'/api/logistique/registre/lots?articleId='+str(a),kind='lots');http.render();check(http.status_code==200 and http.data['meta']['filteredCount']==4,'HTTP register JSON')
http=request(LotMovementsExcelView,'/api/logistique/lots/'+str(near['ID_LotArticle'])+'/mouvements/export.xlsx',pk=near['ID_LotArticle']);check(http.status_code==200 and http['Content-Type'].startswith('application/vnd.openxmlformats') and http['X-Export-Row-Count']=='1','HTTP journal XLSX native');http.close()
http=request(RegisterExcelView,'/api/logistique/registre/lots/export.xlsx?articleId='+str(a),kind='lots');check(http.status_code==200 and http['X-Export-Row-Count']=='4','HTTP register XLSX native');http.close()
local._module_access={'modules':{'logistique':{'canRead':True,'canManage':True,'canExport':False}}}
http=request(RegisterExcelView,'/api/logistique/registre/lots/export.xlsx?articleId='+str(a),local,kind='lots');check(http.status_code==403,'HTTP export respects role permission')
print('PASS',len(checks),'contrôles du registre des lots sur base privée.')
