"""Recette du stock initial, uniquement dans une base sauverndeko_test_*.

La base contient soit la structure historique au 20261026_12 (la recette y
applique migration01), soit le socle actuel déjà migré. Les attentes de
numérotation distinguent le contrat01 du type CMD explicite ajouté en05.
Elle ne charge aucune donnée d'une entreprise cliente.
"""
import copy
import json
import os
import sys
import uuid
from concurrent.futures import ThreadPoolExecutor
from decimal import Decimal
from pathlib import Path
from types import SimpleNamespace
from urllib.parse import urlsplit

import psycopg

ROOT=Path(__file__).resolve().parents[2]
DSN=os.environ.get('SAUVERNDEKO_TEST_DATABASE_URL','')
if not urlsplit(DSN).path.lstrip('/').startswith('sauverndeko_test_'):
    raise RuntimeError('Base de recette privee obligatoire.')
with psycopg.connect(DSN) as guard:
    if not guard.execute('SELECT current_database()').fetchone()[0].startswith('sauverndeko_test_'):
        raise RuntimeError('Base de recette privee obligatoire.')
os.environ.update(DJANGO_SETTINGS_MODULE='config.settings',DATABASE_URL=DSN,SAUVERNDEKO_DB_READ_ONLY='0',DJANGO_SECRET_KEY='private-test',JWT_SECRET='private-test',JWT_REFRESH_SECRET='private-test')
sys.path.insert(0,str(ROOT/'backend'))
import django
django.setup()
from django.db import transaction,connections,DatabaseError
from apps.core import db,repository
from apps.core.registry import model
from apps.core.responses import APIError
from apps.core.tenancy import bind_context
from apps.accounts.authentication import actor_by_id
from apps.logistique.photos import save_article
from apps.logistique.article_rules import revision
from apps.logistique.services import mutate_line

checks=[]
def check(condition,label):
    assert condition,label
    checks.append(label)
def insert(schema,table,body,key):
    return db.one('INSERT INTO '+db.ident(schema)+'.'+db.ident(table)+'('+','.join(db.ident(x) for x in body)+') VALUES('+','.join(['%s']*len(body))+') RETURNING '+db.ident(key)+' id',list(body.values()))['id']
def rejected(callback,label):
    try:
        with transaction.atomic():callback()
    except (DatabaseError,APIError):check(True,label)
    else:raise AssertionError(label)
for cid,label in [(34,'Unités'),(40,'Catégorie produit'),(42,'Devise'),(46,'Type produit'),(64,'Type de commande')]:
    db.query('INSERT INTO referentiel."T_CategorieGenerique"("ID_CategorieGenerique","NomCategorieGenerique","ValideCategorieGenerique") OVERRIDING SYSTEM VALUE VALUES(%s,%s,true) ON CONFLICT DO NOTHING',[cid,label])
    db.query('UPDATE referentiel."T_CategorieGenerique" SET "NomCategorieGenerique"=%s,"ValideCategorieGenerique"=true WHERE "ID_CategorieGenerique"=%s',[label,cid])
def generic(category,label,abbr):
    # Les bases de recette récentes contiennent déjà le dictionnaire commun
    # et refusent désormais les nouvelles identités ambiguës.
    owner=db.one("SELECT EXISTS(SELECT FROM information_schema.columns WHERE table_schema='referentiel' AND table_name='T_Generique' AND column_name='IdEntiteFk') present")['present']
    present=db.one('SELECT "ID_Generique" id FROM referentiel."T_Generique" WHERE "ID_CategorieGeneriqueFk"=%s AND lower(btrim("AbrGenerique"))=lower(btrim(%s))'+(' AND "IdEntiteFk" IS NULL' if owner else '')+' ORDER BY "ID_Generique" LIMIT 1',[category,abbr])
    if present:return present['id']
    return insert('referentiel','T_Generique',{'ID_CategorieGeneriqueFk':category,'NomGenerique':label,'AbrGenerique':abbr,'ValideGenerique':True},'ID_Generique')
unit=generic(34,'Piece de recette','pcs')
category=generic(40,'Materiel de recette','MAT')
kind=generic(46,'Type de recette','T')
existing_usd=db.one('SELECT "ID_Generique" id FROM referentiel."T_Generique" WHERE "ID_CategorieGeneriqueFk"=42 AND "AbrGenerique"=%s AND "ValideGenerique" IS TRUE',['USD'])
currency=existing_usd['id'] if existing_usd else generic(42,'USD','USD')
entry=generic(64,'Entree','Entree')
outgoing=generic(64,'Sortie','Sortie')
neutral=generic(64,'Commande','Commande')
entity=insert('systeme','T_Entite',{'NomEntite':'Entreprise fictive initiale','EmailEntite':uuid.uuid4().hex+'@example.invalid','ValideEntite':True},'IdEntite')
other=insert('systeme','T_Entite',{'NomEntite':'Autre entreprise fictive','EmailEntite':uuid.uuid4().hex+'@example.invalid','ValideEntite':True},'IdEntite')
uid=insert('systeme','T_Utilisateurs',{'NomUser':'Recette','PrenomUser':'Stock','EmailUser':uuid.uuid4().hex+'@example.invalid','MotdepasseUser':'inutilisable','ValideUser':True,'SexeUser':'M','Is_Admin':True},'IdUser')
actor=bind_context(actor_by_id(uid),SimpleNamespace(headers={'X-Entite-ID':str(entity)}))
body={'NomArticle':'Article fictif','ID_TypeArticleFk':kind,'ID_CategorieArticleFk':category,'ID_UniteFk':unit,'ID_DeviseFk':currency,'PUArticle':'10.00','PVArticle':'15.00','QteArticle':'3','QteMinArticle':'1'}
if not db.one("SELECT EXISTS(SELECT FROM information_schema.columns WHERE table_schema='logistique' AND table_name='T_Commande' AND column_name='OrigineBon') ready")['ready']:
    historical=repository.mutate('T_Article',actor,{**body,'NomArticle':'Historique fictif'})
    old_movement=db.one('SELECT * FROM logistique."T_Mouvement" WHERE "ID_ArticleFk"=%s',[historical['ID_Article']])
    old_bon=repository.mutate('T_Commande',actor,{'ID_TypeCmdFk':outgoing,'ID_DeviseFk':currency})
    cost_revision=db.one('SELECT logistique.fn_revision_valorisation(%s,%s,0) revision',[historical['ID_Article'],currency])['revision']
    db.query('SELECT logistique.enregistrer_cout_ouverture(%s,%s,10,%s,%s,0,%s,%s,%s)',[historical['ID_Article'],currency,'Coût fictif confirmé avant reprise',uid,str(uuid.uuid4()),entity,cost_revision])
    old_cost=db.one('SELECT * FROM logistique."T_ValorisationOuverture" WHERE "ID_ArticleFk"=%s',[historical['ID_Article']])
    old_value=db.one('SELECT "ValeurStock" value FROM logistique."V_ValorisationStock" WHERE "ID_Article"=%s',[historical['ID_Article']])['value']
    with psycopg.connect(DSN,autocommit=True) as connection:
        connection.execute((ROOT/'backend/database/migrations/20261028_01_stock_initial_documents.sql').read_text(encoding='utf8'))
    after=db.one('SELECT * FROM logistique."T_Mouvement" WHERE "ID_Mvt"=%s',[old_movement['ID_Mvt']])
    check({k:v for k,v in after.items() if k!='ID_cmdFk'}=={k:v for k,v in old_movement.items() if k!='ID_cmdFk'},'Reprise conserve id, quantite, prix, devise et dates du mouvement')
    check(after['ID_cmdFk'] is not None,'Reprise rattache le mouvement existant a un bon')
    check(db.one('SELECT "CodeCmd" FROM logistique."T_Commande" WHERE "ID_Commande"=%s',[old_bon['ID_Commande']])['CodeCmd']==old_bon['CodeCmd'],'Codes historiques non renumerotes')
    check(db.one('SELECT "QteArticle" q FROM logistique."T_Article" WHERE "ID_Article"=%s',[historical['ID_Article']])['q']==Decimal('3'),'Reprise sans variation de stock')
    check(db.one('SELECT logistique.fn_materialiser_stock_initial(%s,%s) id',[historical['ID_Article'],old_movement['ID_Mvt']])['id']==after['ID_cmdFk'],'Reprise idempotente par mouvement')
    check(db.one('SELECT * FROM logistique."T_ValorisationOuverture" WHERE "ID_ArticleFk"=%s',[historical['ID_Article']])==old_cost,'Reprise conserve integralement l arrete CUMP confirme')
    check(db.one('SELECT "ValeurStock" value FROM logistique."V_ValorisationStock" WHERE "ID_Article"=%s',[historical['ID_Article']])['value']==old_value,'Valeur CUMP inchangee apres rattachement documentaire')

def create(**overrides):
    return save_article(actor,{**body,'requestId':str(uuid.uuid4()),**overrides})
zero=create(NomArticle='Fiche sans stock',QteArticle='0')
check(not db.one('SELECT EXISTS(SELECT FROM logistique."T_Mouvement" WHERE "ID_ArticleFk"=%s) present',[zero['ID_Article']])['present'],'Zero ne cree aucun mouvement fictif')
check(not db.one('SELECT EXISTS(SELECT FROM logistique."T_Commande" WHERE "ID_ArticleInitialFk"=%s) present',[zero['ID_Article']])['present'],'Zero ne cree aucun bon fictif')
request={**body,'NomArticle':'Avec stock initial','requestId':str(uuid.uuid4()),'LotsInitiaux':[{'NumeroLot':'INIT-01','Quantite':'3'}]}
article=save_article(actor,request)
pk=article['ID_Article']
initial=db.one('SELECT * FROM logistique."T_Commande" WHERE "ID_ArticleInitialFk"=%s AND "OrigineBon"=%s',[pk,'stock_initial'])
check(initial is not None and initial['CodeCmd'].startswith('BE-'),'Creation positive genere un bon entree court BE-ID')
check(initial['ID_ClientFk'] is None and initial['ID_TiersFk'] is None,'Stock initial sans fournisseur fictif')
check(initial['ID_UserFk']==uid and initial['IdEntiteFk']==entity,'Auteur et entreprise de creation conserves')
check(db.one('SELECT count(*) n FROM logistique."T_CommandeDetail" WHERE "ID_CmdFk"=%s AND "ID_ArticleFk"=%s',[initial['ID_Commande'],pk])['n']==1,'Une seule ligne relie le bon et l article')
check(db.one('SELECT count(*) n FROM logistique."T_Mouvement" WHERE "ID_ArticleFk"=%s',[pk])['n']==1,'Un seul mouvement initial')
check(db.one('SELECT "QteArticle" q FROM logistique."T_Article" WHERE "ID_Article"=%s',[pk])['q']==Decimal('3'),'Quantite initiale appliquee une fois')
check(db.one('SELECT sum("Quantite") q FROM logistique."T_MouvementLot" ml JOIN logistique."T_Mouvement" m ON m."ID_Mvt"=ml."ID_MvtFk" WHERE m."ID_ArticleFk"=%s',[pk])['q']==Decimal('3'),'Lots rattaches au mouvement documente')
check(save_article(actor,request)['ID_Article']==pk,'Retry du meme UUID et contenu retourne le meme article')
rejected(lambda:save_article(actor,{**request,'NomArticle':'Autre contenu'}),'UUID reutilise avec contenu different refuse')
row=db.one('SELECT * FROM logistique."T_Article" WHERE "ID_Article"=%s',[pk])
save_article(actor,{'_version':revision(row),'InformationArticle':'Description corrigee'},pk=pk)
check(db.one('SELECT count(*) n FROM logistique."T_Mouvement" WHERE "ID_ArticleFk"=%s',[pk])['n']==1,'Edition descriptive sans nouvelle entree')
rejected(lambda:db.query('UPDATE logistique."T_Article" SET "QteArticle"=4 WHERE "ID_Article"=%s',[pk]),'Ajustement direct silencieux refuse en SQL')
rejected(lambda:db.query('UPDATE logistique."T_CommandeDetail" SET "QteCmdDetail"=4 WHERE "ID_CmdFk"=%s',[initial['ID_Commande']]),'Ligne du stock initial immutable')
rejected(lambda:db.query('DELETE FROM logistique."T_Commande" WHERE "ID_Commande"=%s',[initial['ID_Commande']]),'Bon initial conserve')
before=db.one('SELECT count(*) n FROM logistique."T_Article"')['n']
bad={**body,'requestId':str(uuid.uuid4()),'NomArticle':'Echec atomique','LotsInitiaux':[{'NumeroLot':'FAUX','Quantite':'4'}]}
rejected(lambda:save_article(actor,bad),'Lot incorrect annule article, bon, ligne et mouvement')
check(db.one('SELECT count(*) n FROM logistique."T_Article"')['n']==before,'Aucun article partiel apres echec')
check(not db.one('SELECT EXISTS(SELECT FROM logistique."T_Commande" c LEFT JOIN logistique."T_Article" a ON a."ID_Article"=c."ID_ArticleInitialFk" WHERE c."OrigineBon" IS NOT NULL AND a."ID_Article" IS NULL) present')['present'],'Aucun bon initial orphelin')

concurrent={**body,'NomArticle':'Double clic concurrent','requestId':str(uuid.uuid4())}
def duplicate(_):
    try:return save_article(bind_context(actor_by_id(uid),SimpleNamespace(headers={'X-Entite-ID':str(entity)})),copy.deepcopy(concurrent))['ID_Article']
    finally:connections.close_all()
with ThreadPoolExecutor(max_workers=4) as pool:ids=list(pool.map(duplicate,range(4)))
check(len(set(ids))==1,'Double clic et tentatives simultanees conservent un seul article')
check(db.one('SELECT count(*) n FROM logistique."T_Mouvement" WHERE "ID_ArticleFk"=%s',[ids[0]])['n']==1,'Concurrence conserve un seul mouvement')
other_actor=bind_context(actor_by_id(uid),SimpleNamespace(headers={'X-Entite-ID':str(other)}))
check(save_article(other_actor,concurrent)['ID_Article']!=ids[0],'Meme UUID dans autre entreprise reste isole')

def command(kind):return repository.mutate('T_Commande',actor,{'ID_TypeCmdFk':kind,'ID_DeviseFk':currency})
new_entry=command(entry)
check(new_entry['CodeCmd'].startswith('BE-'),'Entree manuelle numerotee BE-ID')
rejected(lambda:db.query('UPDATE logistique."T_Commande" SET "ID_TypeCmdFk"=%s WHERE "ID_Commande"=%s',[outgoing,new_entry['ID_Commande']]),'Changement de sens ne contredit pas le prefixe BE du bon')
check(command(outgoing)['CodeCmd'].startswith('BS-'),'Sortie manuelle numerotee BS-ID')
if db.one("SELECT to_regprocedure('logistique.fn_nature_bon(integer)') IS NOT NULL installed")['installed']:
    # Depuis05, seul le code de référence CMD connu peut être neutre ;
    # une abréviation quelconque de signe zéro n'est plus autorisée.
    cmd_kind=db.one('SELECT "ID_Generique" id FROM referentiel."T_Generique" WHERE "ID_CategorieGeneriqueFk"=64 AND upper(btrim("AbrGenerique"))=%s',['CMD'])
    cmd_kind=cmd_kind['id'] if cmd_kind else generic(64,'Bon de commande','CMD')
    check(db.one('SELECT logistique.fn_code_bon(42,%s) code',[cmd_kind])['code']=='CMD-42','Prefixe CMD court reserve au type explicite Bon de commande en05')
    rejected(lambda:db.query('SELECT logistique.fn_code_bon(42,%s)',[neutral]),'Type neutre inconnu refuse depuis05')
else:
    check(db.one('SELECT logistique.fn_code_bon(42,%s) code',[neutral])['code']=='cmd-42','Contrat historique01 : prefixe generique cmd avant type CMD explicite')
def simultaneous(i):
    try:return repository.mutate('T_Commande',bind_context(actor_by_id(uid),SimpleNamespace(headers={'X-Entite-ID':str(entity)})),{'ID_TypeCmdFk':entry if i%2 else outgoing,'ID_DeviseFk':currency})['CodeCmd']
    finally:connections.close_all()
with ThreadPoolExecutor(max_workers=4) as pool:codes=list(pool.map(simultaneous,range(16)))
check(len(set(codes))==16,'Numerotation entree sortie unique en concurrence')
check(db.one("SELECT logistique.fn_identites_audit('{\"CodeCmd\":\"BE-00042\"}'::jsonb) ids")['ids']==[42],'Audit reserve aussi BE avec zeros initiaux')
check(db.one("SELECT logistique.fn_identites_audit('{\"CodeCmd\":\"BS-00043\"}'::jsonb) ids")['ids']==[43],'Audit reserve aussi BS avec zeros initiaux')
check(db.one('SELECT count(*) n FROM logistique."T_Article" a WHERE a."QteArticle" IS DISTINCT FROM (SELECT coalesce(sum(m."QteMvt"*v."SigneStock"),0) FROM logistique."T_Mouvement" m JOIN logistique."V_MouvementStock" v ON v."ID_Mvt"=m."ID_Mvt" WHERE m."ID_ArticleFk"=a."ID_Article")')['n']==0,'Concordance exhaustive stock et mouvements')
from django.test import override_settings
from rest_framework.test import APIClient
with override_settings(ALLOWED_HOSTS=['testserver','localhost']):
    client=APIClient();client.force_authenticate(actor);client.credentials(HTTP_X_ENTITE_ID=str(entity))
    api_request={**body,'NomArticle':'Fiche API avec stock','requestId':str(uuid.uuid4())}
    response=client.post('/api/logistique/articles',api_request,format='json')
    if response.status_code!=201:raise AssertionError(str((response.status_code,getattr(response,'data',None))))
    check(True,'Route HTTP Articles accepte le contrat de creation UUID')
    api_id=response.data['data']['ID_Article']
    response=client.post('/api/logistique/articles',api_request,format='json')
    check(response.status_code==201 and response.data['data']['ID_Article']==api_id,'Route HTTP rejoue la meme demande sans doublon')
    check(client.post('/api/logistique/articles',{**api_request,'NomArticle':'Contenu modifie'},format='json').status_code==409,'Route HTTP refuse un UUID avec contenu different')
    check(client.post('/api/logistique/articles',body,format='json').status_code==400,'Route HTTP exige un identifiant stable de creation')
    check(client.post('/api/logistique/articles',{**body,'requestId':str(uuid.uuid4()),'CreationRequestId':str(uuid.uuid4())},format='json').status_code==400,'Colonnes techniques ne sont pas controlables par le navigateur')
print(json.dumps({'assertions':len(checks),'checks':checks,'productionWrites':False},ensure_ascii=False))
