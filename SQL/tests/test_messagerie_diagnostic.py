"""Diagnostic SMTP : transport simulé, aucune connexion ni aucun e-mail réel."""
import os,sys,uuid,smtplib
import psycopg
from pathlib import Path
from urllib.parse import urlsplit
from unittest.mock import patch,MagicMock
root=Path(__file__).resolve().parents[2];dsn=os.environ.get('SAUVERNDEKO_TEST_DATABASE_URL','')
if urlsplit(dsn).scheme not in {'postgres','postgresql'} or not urlsplit(dsn).path[1:].startswith('sauverndeko_test_'):raise RuntimeError('Base privée explicite obligatoire')
with psycopg.connect(dsn) as guard:
 if not guard.execute('SELECT current_database()').fetchone()[0].startswith('sauverndeko_test_'):raise RuntimeError('Base privée obligatoire')
os.environ.update(DJANGO_SETTINGS_MODULE='config.settings',DATABASE_URL=dsn,SAUVERNDEKO_DB_READ_ONLY='0');sys.path.insert(0,str(root/'backend'))
import django;django.setup()
from django.test import override_settings
from django.core.cache import cache
from rest_framework.test import APIClient
from apps.accounts.authentication import Actor
from apps.accounts.mail_settings import test_mail_connection,sender_state
from apps.core.responses import APIError
checks=[]
def check(value,name):assert value,name;checks.append(name)
def refusal(fn,code,name):
 try:fn()
 except APIError as e:check(e.default_code==code,name);return e
 raise AssertionError(name)
a=Actor({'IdUser':2147483500,'Is_Admin':True,'ValideUser':True,'IdEntiteFk':None})
with patch('apps.accounts.password_reset.smtp_configured',return_value=True),patch('apps.accounts.mail_settings.get_connection') as transport:
 conn=transport.return_value;conn.open.return_value=True
 r=test_mail_connection(a);check(r['connected'] and not r['messageSent'],'auth only successful');check(bool(r['checkedAt']),'timestamp');check(conn.open.call_count==1 and conn.close.call_count==1,'open close once');check(not conn.send_messages.called,'no message call')
 transport.reset_mock();refusal(lambda:test_mail_connection(None),'PLATFORM_ADMIN_REQUIRED','anonymous refused');check(not transport.called,'no transport before permission')
 with override_settings(DB_READ_ONLY=True):refusal(lambda:test_mail_connection(a),'READ_ONLY','read only refuses')
 check(not transport.called,'no transport in read only')
 for error,code in [(smtplib.SMTPAuthenticationError(535,b'PRIVATE-ERROR'),'SMTP_AUTHENTICATION_FAILED'),(smtplib.SMTPServerDisconnected('PRIVATE-ERROR'),'SMTP_CONNECTION_FAILED'),(TimeoutError('PRIVATE-ERROR'),'SMTP_CONNECTION_FAILED')]:
  conn.open.side_effect=error;exc=refusal(lambda:test_mail_connection(a),code,'safe failure '+code);check('PRIVATE-ERROR' not in str(exc.detail),'no raw server detail')
 conn.open.side_effect=None
 with patch('apps.accounts.password_reset.smtp_configured',return_value=False):refusal(lambda:test_mail_connection(a),'SMTP_CONFIGURATION_REQUIRED','incomplete config')
 with override_settings(EMAIL_HOST_USER='sauverndekordc@gmail.com'):check(sender_state(None)['senderEmail']=='sauverndekordc@gmail.com','default uses configured account')
 cache.clear();client=APIClient();client.force_authenticate(a)
 with override_settings(ALLOWED_HOSTS=['testserver']):
  check(client.post('/api/systeme/messagerie/test',{},format='json').status_code==200,'mounted POST')
  check(client.post('/api/systeme/messagerie/test',{'recipient':'x@example.invalid'},format='json').status_code==400,'no recipient or payload')
  check(client.post('/api/systeme/messagerie/test',{},format='json').status_code==200,'third request')
  check(client.post('/api/systeme/messagerie/test',{},format='json').status_code==429,'throttled fourth request')
 check(not conn.send_messages.called,'route never sends mail')
print('PASS',len(checks),'contrôles diagnostic messagerie simulé.')
