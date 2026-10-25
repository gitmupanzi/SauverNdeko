"""Recette Articles/lots/photos/concurrence, exclusivement sur une base sauverndeko_test_* indépendante. Appliquer les migrations 20261025_01 à 03 avant exécution."""
import os,sys,json,io,zipfile,copy,uuid
from pathlib import Path
from urllib.parse import quote
from decimal import Decimal
import psycopg
from psycopg.conninfo import make_conninfo
from PIL import Image
from tempfile import TemporaryDirectory
from psycopg.conninfo import conninfo_to_dict
root=Path(__file__).resolve().parents[2]
dsn=os.environ.get('SAUVERNDEKO_TEST_DATABASE_URL')
if not dsn: raise RuntimeError('SAUVERNDEKO_TEST_DATABASE_URL obligatoire.')
cfg=conninfo_to_dict(dsn)
with psycopg.connect(dsn) as guard:
 dbname=guard.execute('SELECT current_database()').fetchone()[0]
 if not dbname.startswith('sauverndeko_test_'): raise RuntimeError('Base de recette dédiée obligatoire.')
os.environ['DATABASE_URL']='postgresql://'+quote(cfg.get('user',''),safe='')+':'+quote(cfg.get('password',''),safe='')+'@'+cfg.get('host','localhost')+':'+str(cfg.get('port','5432'))+'/'+quote(dbname,safe='')
os.environ['SAUVERNDEKO_DB_READ_ONLY']='0'
os.environ['JWT_SECRET']='recette-temporaire-articles-jwt-sans-validite-client'
os.environ['JWT_REFRESH_SECRET']='recette-temporaire-refresh-sans-validite-client'
os.environ['DJANGO_SETTINGS_MODULE']='config.settings'
sys.path.insert(0,str(root/'backend'))
sys.path.insert(0,str(root/'SQL'/'tests'))
from test_metier_postgresql import Metier
Metier.setUpClass()
import django;django.setup()
from django.conf import settings
from django.test import override_settings
from django.core.files.uploadedfile import SimpleUploadedFile
from rest_framework.test import APIClient
from apps.accounts.authentication import Actor
from apps.core import db
from django.db import connection
checks=0
def check(value,label):
 global checks
 checks+=1
 assert value,label
def expect(method,url,body=None,status=200,format='json'):
 response=getattr(client,method)(url,body,format=format) if body is not None else getattr(client,method)(url)
 check(response.status_code==status,str((method,url,response.status_code,getattr(response,'data',None))))
 return response
def read(pk):
 result=expect('get','/api/logistique/articles/'+str(pk))
 return result.data['data'],result.data['meta']['revision']
def update(pk,body,status=200,version=None):
 if version is None:_,version=read(pk)
 return expect('put','/api/logistique/articles/'+str(pk),{**body,'_version':version},status)
def stock(pk):
 return db.one('SELECT "QteArticle" AS n FROM logistique."T_Article" WHERE "ID_Article"=%s',[pk])['n']
def lots(pk):
 return {row['NumeroLot']:row['StockLot'] for row in db.query('SELECT * FROM logistique."V_LotArticleStock" WHERE "ID_ArticleFk"=%s',[pk])}
for gid,cat,label,abbr in [(1101,46,'Type de recette','Type'),(1102,40,'Catégorie de recette','Cat'),(1103,34,'Pièce','pcs'),(1104,34,'Kilogramme','kg'),(1105,34,'Gramme','g')]:
 Metier.c.execute('INSERT INTO referentiel."T_Generique" ("ID_Generique","ID_CategorieGeneriqueFk","NomGenerique","AbrGenerique") OVERRIDING SYSTEM VALUE VALUES(%s,%s,%s,%s) ON CONFLICT DO NOTHING',[gid,cat,label,abbr])
uid=Metier.insert('systeme','T_Utilisateurs',{'NomUser':'Recette','PrenomUser':'Fictive','EmailUser':'articles-'+uuid.uuid4().hex+'@example.invalid','MotdepasseUser':'fictif-sans-connexion','SexeUser':'M','IdEntiteFk':Metier.entity,'Is_Admin':True},'IdUser')
actor=Actor({'IdUser':uid,'Is_Admin':True,'Is_staff':False,'IdEntiteFk':Metier.entity})
client=APIClient();client.force_authenticate(actor)
def commande(kind):
 return Metier.insert('logistique','T_Commande',{'ID_TypeCmdFk':kind,'ID_StatutCmdFk':1003,'ID_UserFk':uid,'StatusFacture':'Ouverte'},'ID_Commande')
body={'NomArticle':'Produit de recette','ID_TypeArticleFk':1101,'ID_CategorieArticleFk':1102,'ID_UniteFk':1103,'PUArticle':'12.50','PVArticle':'15.75','QteArticle':'6','PoidsUnitaire':'0.125000','ID_UnitePoidsFk':1104,'InformationArticle':'Description libre =SUM(A1:A2)','LotsInitiaux':[{'NumeroLot':'L-A','Quantite':'4','DatePeremptionLot':'2027-12-31'},{'NumeroLot':'L-B','Quantite':'2'}]}
with TemporaryDirectory(prefix='sauverndeko-photos-recette-') as media_root, override_settings(ALLOWED_HOSTS=['testserver','localhost','127.0.0.1'],ARTICLE_MEDIA_ROOT=media_root):
 created=expect('post','/api/logistique/articles',body,201).data['data'];pk=created['ID_Article']
 check(stock(pk)==6,'stock initial une seule fois')
 check(lots(pk)=={'L-A':4,'L-B':2},'ventilation initiale')
 record,version=read(pk)
 check(record['InformationArticle']==body['InformationArticle'],'champ libre conservé')
 check(record['PoidsUnitaire']==Decimal('0.125000'),'poids exact')
 check(record['StockSansLot']==0,'stock sans lot nul')
 expect('get','/api/logistique/consultations/produit/'+str(pk)+'/lots?take=10',status=200)
 old_version=version
 update(pk,{'NomArticle':'Produit corrigé'},version=version)
 check(stock(pk)==6 and lots(pk)=={'L-A':4,'L-B':2},'métadonnées sans mouvement supplémentaire')
 update(pk,{'RefArticle':'conflit'},409,old_version)
 update(pk,{'QteArticle':'99'},400)
 update(pk,{'ID_UniteFk':1104},400)
 update(pk,{'PoidsUnitaire':'1.000001'},200)
 update(pk,{'ID_UnitePoidsFk':1103},400)
 update(pk,{'DatePeremptionArticle':'2027-01-20','NbreJoursAlerteArticle':10})
 updated,_=read(pk);check(str(updated['DatePeremptionAlerteArticle']).startswith('2027-01-10'),'alerte calculée serveur')
 outgoing=commande(1002)
 expect('post','/api/logistique/commande-details',{'ID_CmdFk':outgoing,'ID_ArticleFk':pk,'QteCmdDetail':'3','PUCmdDetail':'15.75','Lots':[{'NumeroLot':'L-A','Quantite':'2'},{'NumeroLot':'L-B','Quantite':'1'}]},201)
 check(stock(pk)==3 and lots(pk)=={'L-A':2,'L-B':1},'sortie ventilée')
 line=expect('get','/api/logistique/commande-details/'+str(outgoing)+'/'+str(pk)).data['data']
 check(len(line['Lots'])==2,'lecture des lots du bon')
 expect('put','/api/logistique/commande-details/'+str(outgoing)+'/'+str(pk),{'QteCmdDetail':'4'},409)
 expect('put','/api/logistique/commande-details/'+str(outgoing)+'/'+str(pk),{'QteCmdDetail':'4','Lots':[{'NumeroLot':'L-A','Quantite':'3'},{'NumeroLot':'L-B','Quantite':'1'}]})
 check(stock(pk)==2 and lots(pk)=={'L-A':1,'L-B':1},'correction de quantité par delta')
 # Quantités fausses, lot inexistant, lot consommé et sortie sans lot doivent être atomiquement refusés.
 fail=commande(1002)
 expect('post','/api/logistique/commande-details',{'ID_CmdFk':fail,'ID_ArticleFk':pk,'QteCmdDetail':'1','Lots':[{'NumeroLot':'L-A','Quantite':'2'}]},400)
 expect('post','/api/logistique/commande-details',{'ID_CmdFk':fail,'ID_ArticleFk':pk,'QteCmdDetail':'1','Lots':[{'NumeroLot':'inconnu','Quantite':'1'}]},409)
 expect('post','/api/logistique/commande-details',{'ID_CmdFk':fail,'ID_ArticleFk':pk,'QteCmdDetail':'2','Lots':[{'NumeroLot':'L-A','Quantite':'2'}]},409)
 expect('post','/api/logistique/commande-details',{'ID_CmdFk':fail,'ID_ArticleFk':pk,'QteCmdDetail':'1'},409)
 check(stock(pk)==2 and lots(pk)=={'L-A':1,'L-B':1},'échecs sans résidu de stock')
 receipt=commande(1001)
 expect('post','/api/logistique/commande-details',{'ID_CmdFk':receipt,'ID_ArticleFk':pk,'QteCmdDetail':'5','PUCmdDetail':'12.50','Lots':[{'NumeroLot':'L-C','Quantite':'2'},{'NumeroLot':'L-D','Quantite':'3'}]},201)
 check(stock(pk)==7 and lots(pk)=={'L-A':1,'L-B':1,'L-C':2,'L-D':3},'réception multi-lots')
 expect('get','/api/logistique/consultations/commande/'+str(receipt)+'/lots?take=10')
 expect('delete','/api/logistique/commande-details/'+str(receipt)+'/'+str(pk))
 check(stock(pk)==2 and lots(pk)['L-C']==0,'annulation de réception')
 # Une photo valide est normalisée, privée, et son chemin vient du serveur.
 image=io.BytesIO();Image.new('RGB',(80,60),'#2e7c8d').save(image,format='PNG');png=image.getvalue()
 upload=SimpleUploadedFile('../../nom-dangereux.png',png,content_type='image/png')
 _,version=read(pk)
 photo=expect('put','/api/logistique/articles/'+str(pk),{'payload':json.dumps({'_version':version}),'photo':upload},200,'multipart').data['data']
 check(photo['PhotoArticle'].startswith('Article/Produit-corrige_') and photo['PhotoArticle'].endswith('.jpg'),'nom du produit et chemin serveur')
 response=expect('get','/api/logistique/articles/'+str(pk)+'/photo')
 image_bytes=b''.join(response.streaming_content);response.close()
 check(image_bytes.startswith(b'\xff\xd8'),'JPEG réel')
 check(response['Cache-Control']=='no-store, private','photo privée sans cache')
 _,version=read(pk)
 file_count=len(list((Path(settings.ARTICLE_MEDIA_ROOT)/'Article').glob('*')))
 bad=SimpleUploadedFile('image.svg',b'<svg><script>alert(1)</script></svg>',content_type='image/svg+xml')
 expect('put','/api/logistique/articles/'+str(pk),{'payload':json.dumps({'_version':version}),'photo':bad},400,'multipart')
 _,version=read(pk)
 expect('put','/api/logistique/articles/'+str(pk),{'payload':json.dumps({'_version':version,'NomArticle':''}),'photo':SimpleUploadedFile('valide.png',png,content_type='image/png')},400,'multipart')
 check(len(list((Path(settings.ARTICLE_MEDIA_ROOT)/'Article').glob('*')))==file_count,'nettoyage du fichier si validation refusée')
 update(pk,{'PhotoArticle':'Article/autre_'+('a'*32)+'.jpg'},400)
 # Suppression logique réversible ; suppression définitive uniquement sans historique.
 update(pk,{'ValideArticle':False})
 _,version=read(pk);expect('delete','/api/logistique/articles/'+str(pk)+'?mode=hard',{'_version':version},409)
 update(pk,{'ValideArticle':True})
 unused=expect('post','/api/logistique/articles',{**body,'NomArticle':'Article inutilisé','QteArticle':'0','LotsInitiaux':[]},201).data['data']['ID_Article']
 update(unused,{'ValideArticle':False})
 _,version=read(unused)
 expect('delete','/api/logistique/articles/'+str(unused)+'?mode=hard',{'_version':version})
 expect('get','/api/logistique/articles/'+str(unused),status=404)

 # Deux sorties simultanées sur la dernière unité d’un même lot : un seul succès.
 from concurrent.futures import ThreadPoolExecutor
 from django.db import connections
 commands=[commande(1002),commande(1002)]
 def concurrent_output(cmd):
  local=APIClient();local.force_authenticate(Actor(copy.deepcopy(actor.row)))
  try:return local.post('/api/logistique/commande-details',{'ID_CmdFk':cmd,'ID_ArticleFk':pk,'QteCmdDetail':'1','Lots':[{'NumeroLot':'L-A','Quantite':'1'}]},format='json').status_code
  finally:connections.close_all()
 with ThreadPoolExecutor(max_workers=2) as pool:statuses=list(pool.map(concurrent_output,commands))
 check(sorted(statuses)==[201,409],'pas de survente concurrente d’un lot')
 check(stock(pk)==1 and lots(pk)['L-A']==0,'stock final de la concurrence')
 # Deux éditeurs issus d’une même version : une seule mise à jour.
 _,base_version=read(pk)
 def concurrent_edit(label):
  local=APIClient();local.force_authenticate(Actor(copy.deepcopy(actor.row)))
  try:return local.put('/api/logistique/articles/'+str(pk),{'_version':base_version,'InformationArticle':label},format='json').status_code
  finally:connections.close_all()
 with ThreadPoolExecutor(max_workers=2) as pool:statuses=list(pool.map(concurrent_edit,['Éditeur A','Éditeur B']))
 check(sorted(statuses)==[200,409],'conflit de modification concurrente')
 check(db.one('SELECT "Ecart" AS n FROM logistique.fn_audit_stock(%s)',[pk])['n']==0,'audit stock cohérent après CRUD et lots')
print(json.dumps({'assertions':checks,'base':'base dédiée indépendante','CRUD':'création, lecture, modification, désactivation, réactivation, suppression protégée','lots':'stock initial, réception et sortie multi-lots, correction, annulation, erreurs atomiques','photo':'enregistrement JPEG privé, validation et compensation fichier','stock':'cohérent','baseApplicativeModifiee':False},ensure_ascii=False))
