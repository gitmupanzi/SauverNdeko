"""Numérotation indexée : recette sur une base sauverndeko_test_* migrée au 20261028_01.
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
from psycopg.types.json import Jsonb
from concurrent.futures import ThreadPoolExecutor
from django.db import connections

def identities(value):return db.one('SELECT logistique.fn_identites_audit(%s) ids',[Jsonb(value) if value is not None else None])['ids']
check(identities(None) is None,'NULL input keeps STRICT contract')
check(identities({})==[] and identities([])==[] and identities('text')==[],'Non-object and empty data ignored')
check(identities({'ID_Commande':'000042','CodeCmd':'C_000042','CodeFacture':'fac-000042'})==[Decimal(42)],'Leading zeros normalized and deduplicated')
check(identities({'ID_CommandeFk':'11','ID_CommandeRetourFk':'00012','CodeCmd':'CmD-00013','CodeFacture':'f_00014'})==list(map(Decimal,[11,12,13,14])),'All identity fields and case-insensitive formats recognized')
check(identities({'CodeCmd':'BE-00042'})==[Decimal(42)] and identities({'CodeCmd':'BS-00043'})==[Decimal(43)],'Typed BE/BS identities retain the same non-reuse protection')
check(identities({'ID_Commande':True,'ID_CommandeFk':'-1','ID_CommandeRetourFk':'12oops','CodeCmd':'cmd-4xx','CodeFacture':{}})==[],'Malformed identities do not reserve numbers')
check(identities({'CodeCmd':'C_'+('9'*1000)})==[Decimal('9'*1000)],'Large historical identities do not overflow integer or bigint')
check(identities({'CodeCmd':'cmd-'+('9'*1001)})==[],'Impossible oversized numeric identities bounded for GIN')
check(identities({'CodeFacture':'F_'+('0'*10000)+'51'})==[Decimal(51)],'Long zero padding safely normalized')
check(db.one('SELECT logistique.fn_identite_commande_deja_utilisee(NULL) v')['v'] is None,'NULL lookup keeps STRICT contract')
base=1900000000+(uuid.uuid4().int%10000000)
with transaction.atomic():
 for offset,payload,column,table in [(0,{'ID_Commande':'000'+str(base)},'OldData','T_Commande'),(1,{'CodeCmd':'c_'+str(base+1)},'NewData','logistique.T_Commande'),(2,{'CodeFacture':'F_000'+str(base+2)},'OldData','logistique.T_Facture'),(3,{'ID_CommandeRetourFk':str(base+3)},'NewData','logistique.T_Commande'),(4,{'CodeFacture':'FAC-000'+str(base+4)},'NewData','logistique.T_Facture')]:
  db.query('INSERT INTO systeme."T_Audit_Log" ("TableName","Operation",'+db.ident(column)+',"IdEntiteFk") VALUES (%s,%s,%s,%s)',[table,'RECETTE_PRIVATE',Jsonb(payload),entity])
  check(db.one('SELECT logistique.fn_identite_commande_deja_utilisee(%s) used',[base+offset])['used'],'History reserves identity '+str(offset))
 db.query('INSERT INTO systeme."T_Audit_Log" ("TableName","Operation","NewData","IdEntiteFk") VALUES (%s,%s,%s,%s)',['logistique.T_Article','RECETTE_PRIVATE',Jsonb({'CodeCmd':'cmd-'+str(base+5)}),entity])
 check(not db.one('SELECT logistique.fn_identite_commande_deja_utilisee(%s) used',[base+5])['used'],'Unrelated audit tables cannot reserve a document identity')
 try:
  with transaction.atomic():
   db.query('INSERT INTO logistique."T_Commande" ("ID_Commande","ID_TypeCmdFk","ID_UserFk","IdEntiteFk","ID_DeviseFk","DateCmd") OVERRIDING SYSTEM VALUE VALUES (%s,%s,%s,%s,%s,clock_timestamp())',[base,entry,uid,entity,currency])
  raise AssertionError('Historical identity was reused')
 except IntegrityError:check(True,'Insert cannot reuse a removed identity retained in audit')
 # Volume représentatif pour vérifier un plan réellement indexé, sans désactiver Seq Scan.
 db.query('''INSERT INTO systeme."T_Audit_Log" ("TableName","Operation","OldData","NewData","IdEntiteFk")
 SELECT 'logistique.T_Commande','RECETTE_PRIVATE',jsonb_build_object('ID_Commande',700000000000000::numeric+n),jsonb_build_object('CodeCmd','cmd-'||(700000000000000::numeric+n)::text),%s FROM generate_series(1,5000) n''',[entity])
 db.query('ANALYZE systeme."T_Audit_Log"')
 for column,index in [('OldData','audit_document_identites_old_gin'),('NewData','audit_document_identites_new_gin')]:
  plan=db.query('EXPLAIN (FORMAT JSON) SELECT 1 FROM systeme."T_Audit_Log" WHERE "TableName" IN (\'logistique.T_Commande\',\'T_Commande\',\'logistique.T_Facture\') AND logistique.fn_identites_audit('+db.ident(column)+') @> ARRAY[%s::numeric]',[base])[0]
  check(index in str(plan),'Planner uses '+index)
 transaction.set_rollback(True)

# Les créations concurrentes conservent l’unicité et la protection d’historique.
def concurrent_create(_):
 try:
  row=repository.mutate('T_Commande',g,{'ID_TypeCmdFk':entry,'ID_DeviseFk':currency,'DateCmd':'2026-10-26T10:00:00'},operation='create')
  return row['ID_Commande']
 finally:connections.close_all()
with ThreadPoolExecutor(max_workers=4) as workers:ids=list(workers.map(concurrent_create,range(16)))
check(len(set(ids))==16,'Concurrent creations get distinct identities')
check(all(db.one('SELECT "CodeCmd" FROM logistique."T_Commande" WHERE "ID_Commande"=%s',[i])['CodeCmd']=='BE-'+str(i) for i in ids),'New entry notes use BE-ID')
check(all(db.one('SELECT logistique.fn_identite_commande_deja_utilisee(%s) used',[i])['used'] for i in ids),'Every concurrent identity retained in current rows and audit')
check(db.one('SELECT count(*) n FROM systeme."T_Audit_Log" WHERE "Operation"=\'DOCUMENT_NUMBER\' AND ("NewData"->>\'ID_Commande\')::integer=ANY(%s)',[ids])['n']==16,'Exactly one first-number audit per concurrent creation')
print('PASS',len(checks),'contrôles de numérotation sur base privée.')
