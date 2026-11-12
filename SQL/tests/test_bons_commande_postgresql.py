"""Recette SQL de CMD neutre, uniquement sur structure privée sans données client.

Restaurer le socle canonique 20261028_04 dans une base sauverndeko_test_* vide,
puis fournir SAUVERNDEKO_TEST_DATABASE_URL. Le script prépare ses seules
fixtures fictives et applique lui-même la migration05 avant les assertions.
"""
import hashlib
import json
import os
import uuid
from concurrent.futures import ThreadPoolExecutor
from decimal import Decimal
from pathlib import Path
from urllib.parse import urlsplit

import psycopg
from psycopg import sql
from psycopg.rows import dict_row

ROOT=Path(__file__).resolve().parents[2]
DSN=os.environ.get('SAUVERNDEKO_TEST_DATABASE_URL','')
if not urlsplit(DSN).path.lstrip('/').startswith('sauverndeko_test_'):
    raise RuntimeError('Base privée sauverndeko_test_* obligatoire.')
connection=psycopg.connect(DSN,autocommit=True,row_factory=dict_row)
if not connection.execute('SELECT current_database() n').fetchone()['n'].startswith('sauverndeko_test_'):
    raise RuntimeError('Base privée obligatoire.')
if connection.execute('SELECT count(*) n FROM systeme."T_Utilisateurs"').fetchone()['n']:
    raise RuntimeError('Cette recette prépare une structure vide sans compte existant.')
checks=[]
def query(text,params=()):return connection.execute(text,params)
def one(text,params=()):return query(text,params).fetchone()
def check(value,label):
    assert value,label
    checks.append(label)
def rejected(callback,label):
    try:
        with connection.transaction():callback()
    except psycopg.Error as exc:
        assert exc.sqlstate not in ('42601','42703','42883','42P01'),(label,str(exc))
        check(True,label)
    else:raise AssertionError(label)
def insert(schema,table,body,key):
    statement=sql.SQL('INSERT INTO {}.{} ({}) VALUES ({}) RETURNING {} id').format(
        sql.Identifier(schema),sql.Identifier(table),sql.SQL(',').join(map(sql.Identifier,body)),
        sql.SQL(',').join(sql.Placeholder() for _ in body),sql.Identifier(key))
    return connection.execute(statement,list(body.values())).fetchone()['id']
def generic(cat,label,abbr):
    return insert('referentiel','T_Generique',{'ID_CategorieGeneriqueFk':cat,'NomGenerique':label,'AbrGenerique':abbr,'ValideGenerique':True},'ID_Generique')
for cat,label in [(28,'Statut commande'),(34,'Unités'),(36,'Mode paiement'),(37,'Condition de paiement'),(40,'Catégorie produit'),(42,'Devise'),(46,'Type produit'),(64,'Type de commande')]:
    query('INSERT INTO referentiel."T_CategorieGenerique"("ID_CategorieGenerique","NomCategorieGenerique","ValideCategorieGenerique") OVERRIDING SYSTEM VALUE VALUES(%s,%s,true)',[cat,label])
unit=generic(34,'Pièce fictive','pcs');category=generic(40,'Matériel fictif','MAT');kind=generic(46,'Type fictif','TYPE')
currency=generic(42,'Dollar fictif','USD');entry=generic(64,'Entrée','Entrée');outgoing=generic(64,'Sortie','Sortie')
unknown=generic(64,'Type non classé fictif','AUTRE');mode=generic(36,'Espèces fictives','ESP');condition=generic(37,'Au comptant','0')
entity=insert('systeme','T_Entite',{'NomEntite':'Entreprise fictive CMD','EmailEntite':uuid.uuid4().hex+'@example.invalid','ValideEntite':True},'IdEntite')
other=insert('systeme','T_Entite',{'NomEntite':'Autre entreprise fictive CMD','EmailEntite':uuid.uuid4().hex+'@example.invalid','ValideEntite':True},'IdEntite')
user=insert('systeme','T_Utilisateurs',{'NomUser':'Recette','PrenomUser':'Commande','EmailUser':uuid.uuid4().hex+'@example.invalid','MotdepasseUser':'inutilisable','ValideUser':True,'SexeUser':'M','Is_Admin':True},'IdUser')
def article(name,owner=entity,stock=0):
    return insert('logistique','T_Article',{'NomArticle':name,'ID_TypeArticleFk':kind,'ID_CategorieArticleFk':category,'ID_UniteFk':unit,'ID_DeviseFk':currency,'PUArticle':Decimal('10'),'PVArticle':Decimal('15'),'QteArticle':stock,'ID_UserFK':user,'IdEntiteFk':owner},'ID_Article')
def command(kind,**extra):
    return insert('logistique','T_Commande',{'ID_TypeCmdFk':kind,'ID_DeviseFk':currency,'ID_UserFk':user,'IdEntiteFk':entity,'DateCmd':'2026-10-28 10:00:00+01',**extra},'ID_Commande')
def line(cmd,art,quantity=1,price='12.34'):
    query('INSERT INTO logistique."T_CommandeDetail"("ID_CmdFk","ID_ArticleFk","QteCmdDetail","PUCmdDetail") VALUES(%s,%s,%s,%s)',[cmd,art,quantity,price])
a=article('Article fictif A');b=article('Article fictif B');foreign=article('Article autre entreprise',other)
be=command(entry);line(be,a,20,'10.00')
bs=command(outgoing);line(bs,a,1,'15.00')
def table_snapshot(table):
    return query(sql.SQL('SELECT to_jsonb(t) row FROM logistique.{} t ORDER BY to_jsonb(t)::text').format(sql.Identifier(table))).fetchall()
protected=['T_Article','T_Commande','T_CommandeDetail','T_Mouvement','T_LotArticle','T_MouvementLot','T_ValorisationEvenement','T_ValorisationOuverture']
if one("SELECT to_regclass('logistique.\"T_ValorisationArrete\"') table_name")['table_name']:
    protected.append('T_ValorisationArrete')
before={table:table_snapshot(table) for table in protected}
migration=ROOT/'backend/database/migrations/20261028_05_bons_commande.sql'
connection.execute(migration.read_text(encoding='utf8'))
check(all(table_snapshot(t)==rows for t,rows in before.items()),'Installation05 ne réécrit aucun document, code, stock, lot, coût ou mouvement antérieur')
cmdtype=one('SELECT "ID_Generique" id,"NomGenerique" label FROM referentiel."T_Generique" WHERE "ID_CategorieGeneriqueFk"=64 AND "AbrGenerique"=%s',['CMD'])
check(cmdtype is not None and cmdtype['label']=='Bon de commande','Référentiel crée Bon de commande avec code CMD sans identifiant figé')
cmdtype=cmdtype['id']
check(one('SELECT logistique.fn_nature_bon(%s) n,logistique.fn_effet_type_bon(%s) s',[cmdtype,cmdtype])=={'n':'commande','s':0},'CMD possède une nature explicite et un effet nul connu')
check(one('SELECT logistique.fn_nature_bon(%s) n,logistique.fn_effet_type_bon(%s) s',[unknown,unknown])=={'n':None,'s':None},'Type inconnu distinct de CMD neutre')
rejected(lambda:command(unknown),'En-tête de type inconnu refusé')
rejected(lambda:generic(64,'Commande dupliquée','cmd'),'Code sémantique CMD unique même avec casse différente')
cmd=command(cmdtype,ID_ConditionPaiementFk=condition,ID_ModePaiementFk=mode)
code=one('SELECT "CodeCmd" c FROM logistique."T_Commande" WHERE "ID_Commande"=%s',[cmd])['c']
check(code==f'CMD-{cmd}','Nouveau numéro CMD-ID court et automatique')
check(one('SELECT "CodeCmd" c FROM logistique."T_Commande" WHERE "ID_Commande"=%s',[be])['c']==f'BE-{be}' and one('SELECT "CodeCmd" c FROM logistique."T_Commande" WHERE "ID_Commande"=%s',[bs])['c']==f'BS-{bs}','Codes BE et BS antérieurs inchangés')
no_effect_tables=['T_Article','T_Mouvement','T_LotArticle','T_MouvementLot','T_ValorisationEvenement','T_ValorisationOuverture']
if 'T_ValorisationArrete' in protected:no_effect_tables.append('T_ValorisationArrete')
physical={t:table_snapshot(t) for t in no_effect_tables}
valuation=query('SELECT to_jsonb(v) row FROM logistique."V_ValorisationStock" v ORDER BY to_jsonb(v)::text').fetchall()
line(cmd,a,999,'12.34');line(cmd,b,2,'5.05')
v=one('SELECT "NatureBon","SigneCommande","QteTotale","MontantDetails","MontantTTC","EtatPaiement","EstPaiementEnRetard","ResteReel","MontantRegleFactureCalc" FROM logistique."V_Commande" WHERE "ID_Commande"=%s',[cmd])
check(v['NatureBon']=='commande' and v['SigneCommande']==0,'Vue commune distingue CMD des documents physiques')
check(v['QteTotale']==1001 and v['MontantDetails']==Decimal('12337.76') and v['MontantTTC']==Decimal('12337.76'),'Quantités et montants CMD exacts même au-delà du disponible')
check(v['EtatPaiement']=='Sans facturation' and v['EstPaiementEnRetard'] is False and v['ResteReel'] is None and v['MontantRegleFactureCalc'] is None,'Aucune dette, alerte de retard ou fausse facture manquante pour CMD')
check(one('SELECT "NatureBon","StockAvantLigneTheorique" s FROM logistique."V_CommandeDetail" WHERE "ID_CmdFk"=%s AND "ID_ArticleFk"=%s',[cmd,a])=={'NatureBon':'commande','s':None},'Vue des lignes ne présente aucun stock avant fictif pour CMD')
check(one('SELECT "NatureBon","EtatPaiement" FROM logistique."V_CommandeOverview" WHERE "ID_Commande"=%s',[cmd])=={'NatureBon':'commande','EtatPaiement':'Sans facturation'},'Projection historique partage nature et état sans facturation')
query('UPDATE logistique."T_CommandeDetail" SET "QteCmdDetail"=3,"PUCmdDetail"=4.25 WHERE "ID_CmdFk"=%s AND "ID_ArticleFk"=%s',[cmd,a])
query('DELETE FROM logistique."T_CommandeDetail" WHERE "ID_CmdFk"=%s AND "ID_ArticleFk"=%s',[cmd,b])
check(one('SELECT "MontantTTC" m FROM logistique."T_Commande" WHERE "ID_Commande"=%s',[cmd])['m']==Decimal('12.75'),'Modification et retrait des articles recalculent les totaux CMD')
check(all(table_snapshot(t)==rows for t,rows in physical.items()),'DML de lignes CMD conserve intégralement stocks, mouvements, lots et journaux/arrêtés de valorisation')
check(query('SELECT to_jsonb(v) row FROM logistique."V_ValorisationStock" v ORDER BY to_jsonb(v)::text').fetchall()==valuation,'Valeurs et états CUMP inchangés par les lignes CMD')
rejected(lambda:line(cmd,foreign),'Article d’une autre entreprise refusé en SQL direct')
rejected(lambda:line(cmd,b,Decimal('0.5')),'Précision entière de l’unité conservée pour CMD')
rejected(lambda:line(cmd,b,1,None),'Prix convenu obligatoire sur une ligne CMD')
rejected(lambda:line(cmd,b,0),'Quantité CMD strictement positive')
rejected(lambda:line(cmd,b,1,'-1'),'Prix négatif CMD refusé')
query('UPDATE logistique."T_Article" SET "ValideArticle"=false WHERE "ID_Article"=%s',[b])
rejected(lambda:line(cmd,b),'Article désactivé refusé sur une nouvelle ligne CMD')
query('UPDATE logistique."T_Article" SET "ValideArticle"=true WHERE "ID_Article"=%s',[b])
rejected(lambda:query('DELETE FROM logistique."T_Commande" WHERE "ID_Commande"=%s',[cmd]),'Suppression du parent CMD avec lignes refusée explicitement')
for target,label in [(entry,'CMD vers BE'),(outgoing,'CMD vers BS')]:
    rejected(lambda target=target:query('UPDATE logistique."T_Commande" SET "ID_TypeCmdFk"=%s WHERE "ID_Commande"=%s',[target,cmd]),label+' refusé')
empty=command(cmdtype)
rejected(lambda:query('UPDATE logistique."T_Commande" SET "ID_TypeCmdFk"=%s WHERE "ID_Commande"=%s',[entry,empty]),'CMD vide ne se convertit pas non plus en BE')
rejected(lambda:query('UPDATE logistique."T_Commande" SET "ID_TypeCmdFk"=%s WHERE "ID_Commande"=%s',[cmdtype,be]),'BE ne se convertit pas en CMD')
rejected(lambda:query('UPDATE logistique."T_CommandeDetail" SET "ID_CmdFk"=%s WHERE "ID_CmdFk"=%s',[be,cmd]),'Une ligne CMD ne peut pas être déplacée dans un BE')
rejected(lambda:query('UPDATE logistique."T_CommandeDetail" SET "ID_CmdFk"=%s WHERE "ID_CmdFk"=%s',[cmd,bs]),'Une ligne BS ne peut pas être déplacée dans un CMD')
def movement(kind,parent):
    with connection.transaction():
        query("SET LOCAL logistique.allow_t_mouvement_write='on'")
        insert('logistique','T_Mouvement',{'ID_TypeMvtFk':kind,'ID_cmdFk':parent,'ID_ArticleFk':a,'QteMvt':1,'PUMvt':10,'ID_DeviseFk':currency},'ID_Mvt')
rejected(lambda:movement(entry,cmd),'Mouvement Entrée frauduleusement rattaché à CMD refusé malgré drapeau interne')
rejected(lambda:movement(outgoing,cmd),'Mouvement Sortie frauduleusement rattaché à CMD refusé malgré drapeau interne')
rejected(lambda:movement(cmdtype,None),'Mouvement de type CMD autonome refusé')
rejected(lambda:movement(unknown,None),'Mouvement de type inconnu autonome refusé')
rejected(lambda:query('UPDATE referentiel."T_Generique" SET "AbrGenerique"=%s WHERE "ID_Generique"=%s',['AUTRE',cmdtype]),'Type CMD utilisé ne devient pas un neutre inconnu')
rejected(lambda:query('UPDATE referentiel."T_Generique" SET "AbrGenerique"=%s WHERE "ID_Generique"=%s',['Entrée',cmdtype]),'Type CMD utilisé ne devient pas une entrée')
query('UPDATE referentiel."T_Generique" SET "NomGenerique"=%s WHERE "ID_Generique"=%s',['Bon de commande',cmdtype])
for field,value in [('UrlBL','fichier.pdf'),('DateFacture','2026-10-28 10:00:00+01'),('CodeFacture','fac-invalide'),('ValideRemiseFacture',True),('MontantResteFacture',Decimal('12.75'))]:
    rejected(lambda field=field,value=value:query(sql.SQL('UPDATE logistique."T_Commande" SET {}=%s WHERE "ID_Commande"=%s').format(sql.Identifier(field)),[value,cmd]),'Métadonnée physique ou financière CMD interdite : '+field)
invoice={'ID_CommandeFk':cmd,'CodeFacture':f'fac-{cmd}','ID_UserFk':user,'IdEntiteFk':entity,'RequestId':uuid.uuid4(),'PayloadHash':'a'*64,'DateFacture':'2026-10-28 10:00:00+01','DateEcheancePaiement':'2026-10-28 10:00:00+01','ID_ModePaiementFk':mode,'ID_ConditionPaiementFk':condition,'DelaiJours':0,'ID_DeviseFk':currency,'DeviseCode':'USD','DeviseLibelle':'Dollar fictif','MontantHT':'12.75','MontantTTC':'12.75'}
rejected(lambda:insert('logistique','T_Facture',invoice,'ID_Facture'),'Création directe d’une facture CMD refusée par les triggers métier')
return_entry=command(entry)
ret={'ID_CommandeOrigineFk':cmd,'ID_CommandeRetourFk':return_entry,'ID_UserFk':user,'IdEntiteFk':entity,'RequestId':uuid.uuid4(),'PayloadHash':'b'*64,'Motif':'Retour fictif interdit','DateRetour':'2026-10-28 10:00:00+01'}
rejected(lambda:insert('logistique','T_RetourBon',ret,'ID_RetourBon'),'Création directe de restitution commerciale CMD refusée')
lot=insert('logistique','T_LotArticle',{'ID_ArticleFk':a,'NumeroLot':'LOT-PHYSIQUE-FICTIF'},'ID_LotArticle')
def fake_lot():
    with connection.transaction():
        query("SET LOCAL logistique.allow_t_mouvement_write='on'")
        m=insert('logistique','T_Mouvement',{'ID_TypeMvtFk':entry,'ID_cmdFk':cmd,'ID_ArticleFk':a,'QteMvt':1,'PUMvt':10,'ID_DeviseFk':currency},'ID_Mvt')
        query('INSERT INTO logistique."T_MouvementLot"("ID_MvtFk","ID_LotArticleFk","Quantite") VALUES(%s,%s,1)',[m,lot])
rejected(fake_lot,'Ventilation d’un lot via un mouvement falsifié CMD refusée atomiquement')
check(not one('SELECT EXISTS(SELECT FROM logistique."T_Mouvement" WHERE "ID_cmdFk"=%s) e',[cmd])['e'],'Aucun mouvement CMD après tous les contournements SQL')
initial=article('Stock initial fictif après05',stock=3)
check(one('SELECT count(*) n FROM logistique."T_Mouvement" WHERE "ID_ArticleFk"=%s',[initial])['n']==1 and one('SELECT "QteArticle" q FROM logistique."T_Article" WHERE "ID_Article"=%s',[initial])['q']==3,'Flux de stock initial préservé : un BE et un seul mouvement')
def concurrent(_):
    with psycopg.connect(DSN,autocommit=True) as c:
        return c.execute('INSERT INTO logistique."T_Commande"("ID_TypeCmdFk","ID_DeviseFk","ID_UserFk","IdEntiteFk","DateCmd") VALUES(%s,%s,%s,%s,now()) RETURNING "ID_Commande","CodeCmd"',[cmdtype,currency,user,entity]).fetchone()
with ThreadPoolExecutor(max_workers=4) as pool:codes=list(pool.map(concurrent,range(12)))
check(len(set(code for _,code in codes))==12 and all(code==f'CMD-{pk}' for pk,code in codes),'Numérotation CMD unique et courte sous 12 créations concurrentes')
query('DELETE FROM logistique."T_CommandeDetail" WHERE "ID_CmdFk"=%s',[cmd]);query('DELETE FROM logistique."T_Commande" WHERE "ID_Commande"=%s',[cmd])
rejected(lambda:query('INSERT INTO logistique."T_Commande"("ID_Commande","ID_TypeCmdFk","ID_DeviseFk","ID_UserFk","IdEntiteFk") OVERRIDING SYSTEM VALUE VALUES(%s,%s,%s,%s,%s)',[cmd,cmdtype,currency,user,entity]),'Identité d’un CMD supprimé reste réservée dans l’audit')
check(one('SELECT logistique.fn_identites_audit(%s::jsonb) ids',[json.dumps({'CodeCmd':f'CMD-{cmd}'})])['ids']==[Decimal(cmd)],'Analyse des identités de l’audit reconnaît CMD uppercase')
functions=['fn_nature_type_bon','fn_nature_bon','fn_effet_type_bon','fn_code_bon','ps_crud_commande','ps_crud_commandedetail','tr_numero_commande','tr_commande_sans_stock','tr_mouvement_physique']
check(one("SELECT count(*) n FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='logistique' AND p.proname=ANY(%s) AND obj_description(p.oid,'pg_proc') IS NULL",[functions])['n']==0,'Tous les nouveaux contrats et routines modifiées portent COMMENT ON')
check(one("SELECT count(*) n FROM pg_trigger WHERE tgname=ANY(%s) AND obj_description(oid,'pg_trigger') IS NULL",[['a01_commande_sans_stock','a01_mouvement_physique']])['n']==0,'Nouveaux triggers documentés dans PostgreSQL')
check(one("SELECT count(*) n FROM information_schema.columns c JOIN pg_class r ON r.relname=c.table_name JOIN pg_namespace n ON n.oid=r.relnamespace AND n.nspname=c.table_schema JOIN pg_attribute a ON a.attrelid=r.oid AND a.attname=c.column_name WHERE c.table_schema='logistique' AND c.column_name='NatureBon' AND col_description(r.oid,a.attnum) IS NULL")['n']==0,'Colonnes NatureBon documentées dans les trois vues')
connection.close()
result={'assertions':len(checks),'checks':checks,'migration':migration.name,'sha256':hashlib.sha256(migration.read_bytes()).hexdigest(),'database':urlsplit(DSN).path.lstrip('/'),'productionWrites':False}
out=ROOT/'.runtime/bons-commande-20261028/verification.json';out.parent.mkdir(exist_ok=True);out.write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf8')
print(json.dumps(result,ensure_ascii=False))
