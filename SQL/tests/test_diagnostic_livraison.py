"""Diagnostic de livraison : recette privée sur le socle logistique actuel.
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


from copy import deepcopy
from datetime import datetime,timezone
from io import StringIO
import hashlib,json,tempfile,time,warnings
from unittest.mock import patch
from django.conf import settings
from django.core.management import call_command
from django.core.management.base import CommandError
from django.test import override_settings
from django.db import connection,DatabaseError
from apps.core.management.commands import verifier_livraison as diagnostic

def by_code(rows):
 return {row['code']:row for row in rows}

# Fixtures privées seulement : les valeurs ne sont ni proposées ni copiées à l’instance réelle.
db.query('UPDATE systeme."T_Entite" SET "AdresseEntite"=%s,"PhoneEntite"=%s WHERE "IdEntite"=%s',['Adresse privée de recette',None,entity])
status=db.one('''SELECT g."ID_Generique" id FROM referentiel."T_Generique" g JOIN referentiel."T_CategorieGenerique" c ON c."ID_CategorieGenerique"=g."ID_CategorieGeneriqueFk" WHERE lower(c."NomCategorieGenerique")='statut licence' AND lower(g."NomGenerique") IN ('active','actif') AND g."ValideGenerique" LIMIT 1''')['id']
licence=db.one('''INSERT INTO systeme."T_Licence" ("IdEntiteFk","DateDebut","DateFin","IdStatutLicenceFk","ValideLicence") VALUES(%s,LOCALTIMESTAMP-interval '1 day',LOCALTIMESTAMP+interval '5 years',%s,true) RETURNING "IdLicence" id''',[entity,status])['id']
db.query('INSERT INTO systeme."T_LicenceModule" ("IdLicenceFk","CodeModule","Actif") VALUES(%s,%s,true)',[licence,'logistique'])

with patch('smtplib.SMTP',side_effect=AssertionError('Network SMTP forbidden')),patch('smtplib.SMTP_SSL',side_effect=AssertionError('Network SMTP forbidden')):
 rows=by_code(diagnostic.database_checks(entity))
 check(rows['diagnostic_read_only']['mesures']['lectureSeule'] is True,'PostgreSQL actual transaction read only')
 check(rows['identite_entreprise']['etat']=='pret','Complete real-shaped private identity ready')
 check(rows['licence_logistique']['etat']=='pret' and rows['licence_logistique']['mesures']['acces_logistique']==1,'Current licence from shared view ready')
 check(rows['audit_stock']['etat']=='pret' and rows['integrite_lots']['etat']=='pret','Empty private enterprise stock integrity ready')
 check(rows['valorisation_cump']['etat']=='pret' and rows['valorisation_cump']['mesures']['positions']==0,'No stock does not invent valuation problem')
 check(rows['role_runtime']['etat']=='a_configurer','Maintenance account never labelled runtime ready')
 check(rows['transport_mail']['mesures']['connexionTestee'] is False and rows['transport_mail']['mesures']['messageEnvoye'] is False,'Mail configuration never claims SMTP execution')
 check(by_code(diagnostic.database_checks(2147483646))['identite_entreprise']['etat']=='bloquant','Unknown explicit entity blocks delivery')
 with patch.object(diagnostic,'VIEWS',[*diagnostic.VIEWS,('logistique','V_AbsenteRecetteDiagnostic')]):
  check(by_code(diagnostic.database_checks(entity))['socle_vues']['etat']=='bloquant','Missing view reported without querying nonexistent business source')
 db.query('UPDATE systeme."T_Entite" SET "AdresseEntite"=%s WHERE "IdEntite"=%s',['',entity])
 check(by_code(diagnostic.database_checks(entity))['identite_entreprise']['etat']=='a_configurer','Incomplete identity actionable')
 db.query('UPDATE systeme."T_Entite" SET "AdresseEntite"=%s WHERE "IdEntite"=%s',['Adresse privée de recette',entity])
 db.query('UPDATE systeme."T_Licence" SET "DateFin"=LOCALTIMESTAMP-interval %s WHERE "IdLicence"=%s',['1 hour',licence])
 check(by_code(diagnostic.database_checks(entity))['licence_logistique']['etat']=='a_configurer','Expired licence actionable for explicit enterprise')
 db.query('UPDATE systeme."T_Licence" SET "DateFin"=LOCALTIMESTAMP+interval %s WHERE "IdLicence"=%s',['5 years',licence])
 # Un stock initial sans coût démontré doit rester à confirmer.
 a=article(5)
 last_movement=db.one('SELECT max("ID_Mvt") n FROM logistique."T_Mouvement" WHERE "ID_ArticleFk"=%s',[a])['n']
 # Simule uniquement en recette une ouverture historique dont le coût reste inconnu.
 with transaction.atomic():
  db.query("SET LOCAL logistique.allow_valuation_write='on'")
  db.query('INSERT INTO logistique."T_ValorisationOuverture" ("ID_ArticleFk","ID_DeviseFk","IdEntiteFk","ID_MvtArrete","QuantiteOuverture","CoutOuverture") VALUES(%s,%s,%s,%s,5,NULL)',[a,currency,entity,last_movement])
 checks_before=db.one('SELECT count(*) n FROM logistique."T_Mouvement" WHERE "ID_ArticleFk"=%s',[a])['n']
 result=diagnostic.report(entity)
 valued=by_code(result['checks'])['valorisation_cump']
 check(valued['etat']=='a_configurer' and valued['mesures']['stocks_cout_inconnu']==1,'Unknown CUMP is not replaced by catalogue price or zero')
 check(db.one('SELECT count(*) n FROM logistique."T_Mouvement" WHERE "ID_ArticleFk"=%s',[a])['n']==checks_before,'Diagnostic does not create movements')
 check(db.one('SELECT "CoutUnitaireMoyen" c FROM logistique."V_ValorisationStock" WHERE "ID_Article"=%s',[a])['c'] is None,'Diagnostic never validates or fills cost')
 dump=json.dumps(result)
 for private in (settings.SECRET_KEY,settings.JWT_SECRET,settings.JWT_REFRESH_SECRET,settings.EMAIL_HOST_PASSWORD,settings.EMAIL_HOST_USER):
  if private:check(private not in dump,'No secret or account email in diagnostic output')
 check(result['connexionSmtpExecutee'] is False and result['controleLectureSeule'] is True,'Report safety flags truthful')
 check(all(row['etat']=='non_verifie' for row in result['checks'] if row['externe']),'Unexecuted external verifications never green')
 with override_settings(EMAIL_HOST_PASSWORD=''):
  check(by_code(diagnostic.database_checks(entity))['transport_mail']['etat']=='a_configurer','Missing mail configuration actionable without SMTP')
 # Garde applicative puis protection serveur contre une écriture dissimulée dans un CTE SELECT.
 with transaction.atomic():
  with connection.execute_wrapper(diagnostic.sql_guard):
   try:db.query('UPDATE systeme."T_Entite" SET "NomEntite"=%s WHERE "IdEntite"=%s',['Jamais appliqué',entity]);raise AssertionError('Write accepted')
   except CommandError:checks.append('SQL guard rejects UPDATE before execution')
 try:
  with transaction.atomic(),connection.execute_wrapper(diagnostic.sql_guard):
   db.query('SET TRANSACTION ISOLATION LEVEL REPEATABLE READ, READ ONLY')
   db.query('WITH changed AS (UPDATE systeme."T_Entite" SET "NomEntite"=%s WHERE "IdEntite"=%s RETURNING 1) SELECT * FROM changed',['Jamais appliqué',entity])
  raise AssertionError('Read-only CTE accepted write')
 except DatabaseError as error:check(getattr(error.__cause__,'sqlstate',None)=='25006','PostgreSQL read only rejects writing CTE')
 with override_settings(DB_READ_ONLY=True):
  check(by_code(diagnostic.database_checks(entity))['diagnostic_read_only']['etat']=='pret','Diagnostic works when entire service is read only')

# Configuration production fictive en mémoire, aucun domaine/réseau réellement contacté.
cfg=deepcopy(settings.DATABASES);cfg['default']['OPTIONS']['sslmode']='verify-full'
with warnings.catch_warnings():
 warnings.simplefilter('ignore',UserWarning)
 with override_settings(SETTINGS_MODULE='config.production',DEBUG=False,ALLOWED_HOSTS=['erp.example.invalid'],PASSWORD_RESET_FRONTEND_URL='https://erp.example.invalid',SECURE_SSL_REDIRECT=True,SESSION_COOKIE_SECURE=True,CSRF_COOKIE_SECURE=True,SECURE_HSTS_SECONDS=31536000,SECRET_KEY='S'*54,JWT_SECRET='A'*36,JWT_REFRESH_SECRET='B'*36,LEGACY_PLAINTEXT_PASSWORDS=False,DB_READ_ONLY=False,DATABASES=cfg):
  good=diagnostic.runtime_checks(True)
  check(all(row['etat']=='pret' for row in good if not row['externe']),'Configured production static prerequisites ready without claiming deployment')
  check(all(row['etat']=='non_verifie' for row in good if row['externe']),'Actual HTTPS/email/backups still unverified')
  with override_settings(DEBUG=True,LEGACY_PLAINTEXT_PASSWORDS=True,SECRET_KEY='bad',PASSWORD_RESET_FRONTEND_URL='https://[bad'):
   bad=by_code(diagnostic.runtime_checks(True))
   check(bad['debug']['etat']=='bloquant' and bad['mots_de_passe_herites']['etat']=='bloquant' and bad['secrets_distincts']['etat']=='bloquant','Unsafe production flags block delivery')
   check(bad['origine_https']['etat']=='bloquant','Malformed origin reported without crash')
  with override_settings(ARTICLE_MEDIA_ROOT=Path(settings.BASE_DIR).parent/'frontend'/'public'/'private-photos'):
   check(by_code(diagnostic.runtime_checks(True))['stockage_media']['etat']=='bloquant','Public media directory rejected')

with tempfile.TemporaryDirectory(prefix='sauverndeko-diagnostic-test-') as temp:
 path=Path(temp);dump=path/'database.dump';media=path/'media.tar.gz';manifest=path/'manifest.json'
 dump.write_bytes(b'private-test-dump');media.write_bytes(b'private-test-media')
 data={'format':1,'database':settings.DATABASES['default']['NAME'],'method':'repeatable_read_snapshot','fingerprintTimeZone':'UTC','databaseSha256':hashlib.sha256(dump.read_bytes()).hexdigest(),'mediaSha256':hashlib.sha256(media.read_bytes()).hexdigest(),'tables':{},'mediaFiles':[],'restored':True}
 def manifest_write():manifest.write_text(json.dumps(data),encoding='utf8')
 manifest_write()
 with patch.object(Path,'rglob',side_effect=AssertionError('Recursive search forbidden')),patch.object(Path,'glob',side_effect=AssertionError('Automatic search forbidden')):
  checks_backup=by_code(diagnostic.backup_checks(path))
 check(checks_backup['sauvegarde_empreintes']['etat']=='pret','Explicit backup checksums match')
 check(checks_backup['sauvegarde_anciennete']['etat']=='pret','Recent manifest file observation')
 check(checks_backup['restauration']['etat']=='non_verifie','Manifest restored flag is not restoration proof')
 old=time.time()-96*3600;os.utime(manifest,(old,old))
 check(by_code(diagnostic.backup_checks(path))['sauvegarde_anciennete']['etat']=='a_configurer','Old manifest actionable')
 manifest_write();dump.write_bytes(b'corrupted-private-test')
 check(by_code(diagnostic.backup_checks(path))['sauvegarde_empreintes']['etat']=='bloquant','Altered backup checksum blocks delivery')
 data['database']='another-private-instance';manifest_write()
 check(diagnostic.backup_checks(path)[0]['etat']=='bloquant','Manifest of another database rejected without exposing its name')
 check(diagnostic.backup_checks(path/'does-not-exist')[0]['etat']=='bloquant','Missing explicit backup directory does not fall back')
check(diagnostic.backup_checks()[0]['etat']=='non_verifie','No automatic backup discovery')

for kwargs in ({'entity':0},{'entity':True},{'entity':2147483648},{'max_backup_age_hours':float('nan')},{'max_backup_age_hours':0}):
 try:diagnostic.report(**kwargs);raise AssertionError('Invalid argument accepted')
 except CommandError:checks.append('Invalid argument rejected '+str(next(iter(kwargs))))
out=StringIO()
with patch.object(diagnostic,'report',return_value=result):
 call_command('verifier_livraison',json=True,stdout=out)
 check(json.loads(out.getvalue())['etat']==result['etat'],'CLI emits machine readable JSON only')
 try:call_command('verifier_livraison',json=True,strict=True,stdout=StringIO());raise AssertionError('Strict accepted warnings')
 except CommandError:checks.append('Strict nonzero on blocking or configuration requirements')
ready_result={**result,'etat':'non_verifie','totaux':{'pret':1,'a_configurer':0,'bloquant':0,'non_verifie':1}}
with patch.object(diagnostic,'report',return_value=ready_result):
 call_command('verifier_livraison',strict=True,stdout=StringIO())
 checks.append('Strict allows only external unverified without certifying readiness')
print('PASS',len(checks),'contrôles du diagnostic de livraison sur base privée.')
