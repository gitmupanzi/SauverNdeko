"""Recette de récupération d'accès ; mutations exclusivement sur sauverndeko_test_*.
Le transport locmem remplace SMTP pendant ce script : aucun e-mail réel n'est envoyé.
"""
import os,sys,uuid,secrets,re
from pathlib import Path
from datetime import datetime,timedelta
from urllib.parse import urlsplit,parse_qs
from concurrent.futures import ThreadPoolExecutor
from threading import Barrier
from unittest.mock import patch
import psycopg
root=Path(__file__).resolve().parents[2]
dsn=os.environ.get('SAUVERNDEKO_TEST_DATABASE_URL','');parsed=urlsplit(dsn)
if parsed.scheme not in ('postgres','postgresql') or not parsed.path[1:].startswith('sauverndeko_test_'):raise RuntimeError('Base privée sauverndeko_test_* obligatoire ; aucun repli vers DATABASE_URL.')
with psycopg.connect(dsn) as guard:
 if not guard.execute('SELECT current_database()').fetchone()[0].startswith('sauverndeko_test_'):raise RuntimeError('Base non autorisée.')
os.environ.update(DJANGO_SETTINGS_MODULE='config.settings',DATABASE_URL=dsn,SAUVERNDEKO_DB_READ_ONLY='0',DJANGO_SECRET_KEY=secrets.token_urlsafe(64),JWT_SECRET=secrets.token_urlsafe(48),JWT_REFRESH_SECRET=secrets.token_urlsafe(48))
sys.path.insert(0,str(root/'backend'))
import django;django.setup()
from django.conf import settings
from django.core import mail
from django.core.cache import cache
from django.core.mail.backends.locmem import EmailBackend
from django.contrib.auth.hashers import make_password
from django.db import close_old_connections
from django.test import override_settings
from rest_framework.test import APIClient
from rest_framework.exceptions import AuthenticationFailed
from apps.accounts import password_reset as reset
from apps.accounts.authentication import actor_by_id,tokens,token_actor,password_matches
from apps.accounts.passwords import change_password
from apps.core import db
from apps.core.responses import APIError
checks=[]
def check(value,name):
 assert value,name
 checks.append(name)
def fails(fn,name,code=None):
 try:fn()
 except (APIError,AuthenticationFailed) as error:
  if code:check(getattr(error,'default_code',None)==code,name+' code')
  else:check(True,name)
 else:raise AssertionError(name)
def insert(table,data,key):
 return db.one('INSERT INTO '+table+' ('+','.join(db.ident(k) for k in data)+') VALUES ('+','.join(['%s']*len(data))+') RETURNING '+db.ident(key)+' id',list(data.values()))['id']
# Le catalogue appartient aux fixtures de cette base privée ; aucune dépendance à un seed client.
from apps.core.module_access import WORKSPACE_MODULES,BASE_MODULES,INCLUSIONS
for index,item in enumerate(WORKSPACE_MODULES):
 parent=next((parent for parent,children in INCLUSIONS.items() if item['key'] in children),None)
 db.query('INSERT INTO systeme."T_ModuleApplication"("CodeModule","Nom","EstSocle","CodeIncluant","Actif","Ordre") VALUES(%s,%s,%s,%s,true,%s) ON CONFLICT("CodeModule") DO NOTHING',[item['key'],item['label'],item['key'] in BASE_MODULES,parent,(index+1)*10])
tag=uuid.uuid4().hex[:12];old=secrets.token_urlsafe(25);new=secrets.token_urlsafe(25)
entity=insert('systeme."T_Entite"',{'NomEntite':'Recette accès '+tag,'EmailEntite':'entity-'+tag+'@example.invalid','ValideEntite':True},'IdEntite')
uid=insert('systeme."T_Utilisateurs"',{'NomUser':'Recette','PrenomUser':'Accès','EmailUser':'reset-'+tag+'@example.invalid','MotdepasseUser':make_password(old),'SexeUser':'M','IdEntiteFk':entity,'Is_Admin':False,'Is_staff':False,'ValideUser':True},'IdUser')
email='reset-'+tag+'@example.invalid';session=tokens(actor_by_id(uid));client=APIClient();cache.clear()
with override_settings(EMAIL_BACKEND=reset.SMTP_BACKEND,EMAIL_HOST='smtp.example.invalid',EMAIL_HOST_USER='sender@example.invalid',EMAIL_HOST_PASSWORD='locmem-fixture-only',EMAIL_USE_TLS=True,EMAIL_USE_SSL=False,PASSWORD_RESET_FRONTEND_URL='https://recette.invalid'),patch.object(reset,'get_connection',side_effect=lambda **kw:EmailBackend(fail_silently=False)):
 response=client.get('/SauverNdeko/auth/password-reset');check(response.status_code==200 and response.data['data']['available'],'policy available')
 response=client.post('/SauverNdeko/auth/password-reset',{'email':email},format='json');check(response.status_code==202,'request accepted')
 check(len(mail.outbox)==1,'one local email')
 message=mail.outbox[0];check(message.to==[email],'correct recipient');check(len(message.alternatives)==1 and 'Choisir un nouveau mot de passe' in message.alternatives[0].content,'html call to action')
 check(old not in message.body and new not in message.body,'no password in email')
 link=re.search(r'https://recette.invalid/reset-password#[^\s]+',message.body).group();parts=urlsplit(link)
 check(not parts.query and bool(parts.fragment),'token in fragment only')
 body={key:values[0] for key,values in parse_qs(parts.fragment).items()}
 check(reset.check_reset_link(body)['valid'],'valid signed link')
 unknown=client.post('/SauverNdeko/auth/password-reset',{'email':'absent-'+tag+'@example.invalid'},format='json');check(unknown.status_code==202 and unknown.data['message']==response.data['message'],'non enumeration')
 check(len(mail.outbox)==1,'unknown recipient no email')
 expires=reset.token_generator._now()-timedelta(seconds=settings.PASSWORD_RESET_TIMEOUT+5)
 with patch.object(reset.token_generator,'_now',return_value=expires):expired=reset.token_generator.make_token(reset.reset_identity(reset.active_reset_account(uid)))
 fails(lambda:reset.check_reset_link({'uid':body['uid'],'token':expired}),'expired link refused','RESET_LINK_INVALID')
 fails(lambda:reset.confirm_reset({**body,'newPassword':'short','confirmPassword':'short'}),'short password refused','RESET_VALIDATION')
 check(reset.check_reset_link(body)['valid'],'failed input retains link')
 result=reset.confirm_reset({**body,'newPassword':new,'confirmPassword':new});check(result['otherSessionsRevoked'],'reset requires login')
 check(password_matches(new,actor_by_id(uid).row['MotdepasseUser']),'new password stored as verified hash')
 fails(lambda:reset.check_reset_link(body),'link single use','RESET_LINK_INVALID')
 fails(lambda:token_actor(session['accessToken']),'access token revoked');fails(lambda:token_actor(session['refreshToken'],'refresh'),'refresh token revoked')
 current=actor_by_id(uid);check(not current.global_admin and not current.admin and current.organisation==entity,'permissions and entity retained')
 fresh=tokens(current);check(token_actor(fresh['accessToken']).pk==uid,'fresh session valid')
 # Les deux confirmations passent la même barrière ; une seule peut modifier le hash.
 concurrent_token=reset.token_generator.make_token(reset.reset_identity(reset.active_reset_account(uid)));barrier=Barrier(2)
 def confirm_concurrently(index):
  close_old_connections();barrier.wait();candidate=secrets.token_urlsafe(24)
  try:reset.confirm_reset({'uid':body['uid'],'token':concurrent_token,'newPassword':candidate,'confirmPassword':candidate});return 'success'
  except APIError as error:return error.default_code
  finally:close_old_connections()
 with ThreadPoolExecutor(max_workers=2) as pool:results=list(pool.map(confirm_concurrently,[0,1]))
 check(results.count('success')==1 and results.count('RESET_LINK_INVALID')==1,'concurrent link exactly once')
 audit=db.query('SELECT "NewData" FROM systeme."T_Audit_Log" WHERE "Operation"=%s AND "NewData"->>\'IdUser\'=%s',['PASSWORD_CHANGE',str(uid)])
 check(len(audit)==2,'one audit per successful reset');check(all(set(row['NewData'])<={'IdUser','passwordChanged','method','_actor'} for row in audit),'audit contains no password or token')
 inactive_token=reset.token_generator.make_token(reset.reset_identity(reset.active_reset_account(uid)))
 db.query('UPDATE systeme."T_Utilisateurs" SET "ValideUser"=false WHERE "IdUser"=%s',[uid])
 fails(lambda:reset.check_reset_link({'uid':body['uid'],'token':inactive_token}),'inactive account refused','RESET_LINK_INVALID')
 db.query('UPDATE systeme."T_Utilisateurs" SET "ValideUser"=true WHERE "IdUser"=%s',[uid])
 db.query('UPDATE systeme."T_Entite" SET "ValideEntite"=false WHERE "IdEntite"=%s',[entity])
 fails(lambda:reset.check_reset_link({'uid':body['uid'],'token':inactive_token}),'inactive entity refused','RESET_LINK_INVALID')
 db.query('UPDATE systeme."T_Entite" SET "ValideEntite"=true WHERE "IdEntite"=%s',[entity])
 unauth=client.post('/SauverNdeko/auth/me/password',{'currentPassword':old,'newPassword':new,'confirmPassword':new},format='json');check(unauth.status_code in (401,403),'personal password change authenticated')
 with override_settings(DB_READ_ONLY=True):fails(lambda:reset.confirm_reset({**body,'newPassword':new,'confirmPassword':new}),'read only reset refused','READ_ONLY')
print('PASS',len(checks),'contrôles récupération d’accès ; transport local uniquement.')
