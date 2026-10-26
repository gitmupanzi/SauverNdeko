"""Droits PostgreSQL runtime : appliquer seulement sur une base locale privée.
Nécessite un compte d'administration du cluster de recette ; aucun repli vers DATABASE_URL.
"""
import os,sys,secrets,uuid
from pathlib import Path
from urllib.parse import urlsplit,unquote,quote
import psycopg
from psycopg import sql
root=Path(__file__).resolve().parents[2];dsn=os.environ.get('SAUVERNDEKO_TEST_DATABASE_URL','');u=urlsplit(dsn)
if u.scheme not in ('postgres','postgresql') or u.hostname not in ('localhost','127.0.0.1') or not u.path[1:].startswith('sauverndeko_test_'):raise RuntimeError('Cluster local et base privée sauverndeko_test_* requis.')
password=secrets.token_urlsafe(32)
with psycopg.connect(dsn,autocommit=True) as owner:
 if not owner.execute('SELECT current_database()').fetchone()[0].startswith('sauverndeko_test_'):raise RuntimeError('Base interdite.')
 owner.execute((root/'deploy/production/role-runtime.sql').read_text(encoding='utf-8-sig'))
 owner.execute(sql.SQL('ALTER ROLE sauverndeko_runtime LOGIN PASSWORD {}').format(sql.Literal(password)))
runtime=f'postgresql://sauverndeko_runtime:{quote(password)}@{u.hostname}:{u.port or 5432}{u.path}'
checks=[]
def check(value,label):
 assert value,label
 checks.append(label)
with psycopg.connect(runtime,autocommit=True) as connection:
 flags=connection.execute("SELECT rolsuper,rolcreatedb,rolcreaterole,rolreplication,rolbypassrls FROM pg_roles WHERE rolname=current_user").fetchone();check(not any(flags),'restricted role attributes')
 check(connection.execute('SHOW search_path').fetchone()[0]=='public','public search path')
 for statement,label in [('CREATE TABLE public.runtime_forbidden(id integer)','CREATE TABLE'),('CREATE SCHEMA runtime_forbidden','CREATE SCHEMA'),('CREATE TEMP TABLE runtime_forbidden(id integer)','CREATE TEMP'),('ALTER TABLE logistique."T_Article" ADD COLUMN runtime_forbidden integer','ALTER TABLE'),('TRUNCATE logistique."T_Article"','TRUNCATE'),('CREATE ROLE runtime_forbidden','CREATE ROLE'),('CREATE DATABASE runtime_forbidden','CREATE DATABASE'),('UPDATE systeme."T_Audit_Log" SET "Operation"=\'FORBIDDEN\' WHERE false','UPDATE AUDIT'),('DELETE FROM operations."T_Paiement_Archive" WHERE false','DELETE ARCHIVE'),("SELECT setval(pg_get_serial_sequence('logistique.\"T_Article\"','ID_Article'),1,true)",'RESET SEQUENCE')]:
  try:connection.execute(statement)
  except psycopg.errors.InsufficientPrivilege:check(True,label+' refused')
  else:raise AssertionError(label+' accepted')
os.environ.update(DJANGO_SETTINGS_MODULE='config.settings',DATABASE_URL=runtime,SAUVERNDEKO_DB_READ_ONLY='0',DJANGO_SECRET_KEY=secrets.token_urlsafe(64),JWT_SECRET=secrets.token_urlsafe(48),JWT_REFRESH_SECRET=secrets.token_urlsafe(48))
sys.path.insert(0,str(root/'backend'))
import django;django.setup()
from django.db import transaction
from types import SimpleNamespace
from datetime import datetime
from zoneinfo import ZoneInfo
from apps.core import db,repository
from apps.core.tenancy import bind_context
from apps.accounts.authentication import actor_by_id
from apps.logistique.services import mutate_line
from apps.logistique.article_rules import revision
admin=db.one('SELECT "IdUser" FROM systeme."T_Utilisateurs" WHERE "Is_Admin" AND "ValideUser" ORDER BY "IdUser" LIMIT 1')
if not admin:raise RuntimeError('Administrateur fictif requis dans la base privée.')
actor=actor_by_id(admin['IdUser']);tag=uuid.uuid4().hex[:10]
entity=repository.mutate('T_Entite',actor,{'NomEntite':'Runtime recette '+tag,'EmailEntite':'runtime-'+tag+'@example.invalid','ValideEntite':True})
actor=bind_context(actor,SimpleNamespace(headers={'X-Entite-ID':str(entity['IdEntite'])}))
def generic(category):
 row=db.one('SELECT "ID_Generique" id FROM referentiel."T_Generique" WHERE "ID_CategorieGeneriqueFk"=%s AND "ValideGenerique" ORDER BY "ID_Generique" LIMIT 1',[category])
 if not row:raise RuntimeError('Dictionnaire requis pour recette runtime.')
 return row['id']
unit,category,kind=generic(34),generic(40),generic(46)
currency=db.one('SELECT "ID_Generique" id FROM referentiel."T_Generique" WHERE "ID_CategorieGeneriqueFk"=42 AND upper("AbrGenerique")=%s',['USD'])['id']
article=repository.mutate('T_Article',actor,{'NomArticle':'Runtime article '+tag,'ID_TypeArticleFk':kind,'ID_CategorieArticleFk':category,'ID_UniteFk':unit,'ID_DeviseFk':currency,'QteArticle':'0','PUArticle':'10','PVArticle':'15','ValideArticle':True})
check(article['QteArticle']=='0.000' or float(article['QteArticle'])==0,'article created')
for direction,quantity,expected in [('entr','3',3),('sort','1',2)]:
 type_id=db.one('SELECT "ID_Generique" id FROM referentiel."T_Generique" WHERE "ID_CategorieGeneriqueFk"=64 AND "ValideGenerique" AND "AbrGenerique" ILIKE %s ORDER BY "ID_Generique" LIMIT 1',[direction+'%'])['id']
 command=repository.mutate('T_Commande',actor,{'ID_TypeCmdFk':type_id,'ID_DeviseFk':currency,'DateCmd':datetime.now(ZoneInfo('Africa/Kinshasa')).replace(tzinfo=None).isoformat(),'RefCmd':'Runtime '+tag})
 mutate_line(actor,command['ID_Commande'],{'ID_ArticleFk':article['ID_Article'],'QteCmdDetail':quantity,'PUCmdDetail':'10','Lots':[]})
 check(db.one('SELECT "QteArticle" q FROM logistique."T_Article" WHERE "ID_Article"=%s',[article['ID_Article']])['q']==expected,direction+' stock')
 check(db.one('SELECT count(*) n FROM logistique."T_Mouvement" WHERE "ID_cmdFk"=%s',[command['ID_Commande']])['n']==1,direction+' one movement')
check(db.one('SELECT count(*) n FROM systeme."T_Audit_Log" WHERE "NewData"->>\'IdEntite\'=%s',[str(entity['IdEntite'])])['n']>=1,'audit written')
empty=repository.mutate('T_Article',actor,{'NomArticle':'Runtime vide '+tag,'ID_TypeArticleFk':kind,'ID_CategorieArticleFk':category,'ID_UniteFk':unit,'ID_DeviseFk':currency,'QteArticle':'0','PUArticle':'10','PVArticle':'15','ValideArticle':True})
empty=repository.mutate('T_Article',actor,keys={'ID_Article':empty['ID_Article']},body={'_version':revision(empty),'ObsArticle':'Mise à jour contrôlée'},operation='update')
check(empty['ObsArticle']=='Mise à jour contrôlée','article updated')
empty=repository.mutate('T_Article',actor,keys={'ID_Article':empty['ID_Article']},body={'_version':revision(empty)},operation='delete')
repository.mutate('T_Article',actor,keys={'ID_Article':empty['ID_Article']},body={'_version':revision(empty)},operation='delete',hard=True)
check(not db.one('SELECT "ID_Article" FROM logistique."T_Article" WHERE "ID_Article"=%s',[empty['ID_Article']]),'unused article deleted')
print('PASS',len(checks),'contrôles rôle runtime restreint ; aucune configuration locale modifiée.')
