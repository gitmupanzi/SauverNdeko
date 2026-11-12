"""Reprise des codes sur une base privée05 avec dictionnaire fermé, sans client.

La fixture réinstalle temporairement une politique de numéros cmd-ID pour
créer des antécédents fictifs avec tous les triggers actifs. Elle restaure
la fonction canonique05 avant la reprise06. Aucun trigger n'est désactivé.
"""
import hashlib,json,os,runpy,sys,uuid
from datetime import datetime,timedelta,timezone
from pathlib import Path
from urllib.parse import urlsplit
import psycopg
from psycopg import sql
from psycopg.rows import dict_row

ROOT=Path(__file__).resolve().parents[2]
DSN=os.environ.get('SAUVERNDEKO_TEST_DATABASE_URL','')
location=urlsplit(DSN)
if location.hostname not in {'127.0.0.1','localhost'} or not location.path[1:].startswith('sauverndeko_test_'):raise RuntimeError('Base locale privée obligatoire')
os.environ.update(DATABASE_URL=DSN,DJANGO_SETTINGS_MODULE='config.settings',SAUVERNDEKO_DB_READ_ONLY='0',DJANGO_ALLOWED_HOSTS='localhost,127.0.0.1,testserver')
sys.path.insert(0,str(ROOT/'backend'))
import django;django.setup()
from django.db import transaction,DatabaseError
from apps.core import db,repository
from apps.logistique import order_composer
from apps.logistique.document_rules import revision
checks=[]
def check(value,label):
 assert value,label
 checks.append(label)
def rejected(callback,label):
 try:
  with transaction.atomic():callback()
 except DatabaseError as exc:
  code=getattr(getattr(exc,'__cause__',None),'sqlstate',None)
  assert code not in ('42601','42703','42883','42P01'),(label,str(exc))
  check(True,label)
 else:raise AssertionError(label)
with psycopg.connect(DSN,autocommit=True,row_factory=dict_row) as direct:
 if not direct.execute('SELECT current_database() n').fetchone()['n'].startswith('sauverndeko_test_'):raise RuntimeError('Base privée obligatoire')
 if direct.execute('SELECT count(*) n FROM systeme."T_Utilisateurs"').fetchone()['n']:raise RuntimeError('Structure de recette vide attendue')
 original=direct.execute("SELECT pg_get_functiondef('logistique.fn_code_bon(integer,integer)'::regprocedure) definition").fetchone()['definition']
 direct.execute("""CREATE OR REPLACE FUNCTION logistique.fn_code_bon(p_id integer,p_type integer) RETURNS character varying LANGUAGE plpgsql STABLE STRICT SET search_path=pg_catalog AS $$ BEGIN IF p_id<=0 OR logistique.fn_nature_bon(p_type) IS NULL THEN RAISE EXCEPTION 'Type fictif invalide';END IF;RETURN 'cmd-'||p_id::text;END $$""")
 # The backend under test already calls the upcoming temporal resolver.
 # During the pre-migration fixture only, resolve its current legacy code.
 direct.execute('''CREATE FUNCTION logistique.fn_code_bon_a_date(p_id integer,p_emis_le timestamp with time zone) RETURNS character varying LANGUAGE sql STABLE AS $$ SELECT "CodeCmd" FROM logistique."T_Commande" WHERE "ID_Commande"=p_id $$''')
 # Both suites create entirely fictitious entities, documents and snapshots.
 chaine=runpy.run_path(str(ROOT/'SQL/tests/test_chaine_logistique.py'))
 inventaire=runpy.run_path(str(ROOT/'SQL/tests/test_annulation_inventaire.py'))
 check(len(chaine['checks'])==112,'Préparation complète avec 112 contrôles physiques, financiers, PDF et isolation')
 check(len(inventaire['checks'])==31,'Préparation inventaires validés/annulés avec 31 contrôles et vrais bons compensateurs')
 # Exercise a closed, issued and settled sale as well as technical documents.
 db.query('UPDATE logistique."T_Commande" SET "StatusFacture"=%s WHERE "ID_Commande"=%s',['Clôturée',chaine['sale_id']])
 check(db.one('SELECT logistique.fn_commande_cloturee("StatusFacture") closed FROM logistique."T_Commande" WHERE "ID_Commande"=%s',[chaine['sale_id']])['closed'],'Fixture avec bon facturé et clôturé')
 cmd=db.one('SELECT "ID_Generique" id FROM referentiel."T_Generique" WHERE "ID_CategorieGeneriqueFk"=64 AND "AbrGenerique"=%s',['CMD'])
 if not cmd:cmd=db.one('INSERT INTO referentiel."T_Generique"("ID_CategorieGeneriqueFk","NomGenerique","AbrGenerique","ValideGenerique") VALUES(64,%s,%s,true) RETURNING "ID_Generique" id',['Bon de commande','CMD'])
 neutral=repository.mutate('T_Commande',chaine['a'],{'ID_TypeCmdFk':cmd['id'],'ID_DeviseFk':chaine['currency']})
 # After fixture preparation, the canonical numbering function is restored.
 direct.execute(original)
 direct.execute('DROP FUNCTION logistique.fn_code_bon_a_date(integer,timestamp with time zone)')
 normal=repository.mutate('T_Commande',chaine['a'],{'ID_TypeCmdFk':chaine['entry'],'ID_DeviseFk':chaine['currency']})
 tables=direct.execute("SELECT n.nspname schema,c.relname name FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE c.relkind='r' AND n.nspname=ANY(%s) ORDER BY 1,2",[['analytics','communication','geolocalisation','logistique','operations','professionnel','referentiel','systeme']]).fetchall()
 def snapshot(schema,table):
  rows=direct.execute(sql.SQL('SELECT to_jsonb(t)::text row FROM {}.{} t ORDER BY to_jsonb(t)::text').format(sql.Identifier(schema),sql.Identifier(table))).fetchall()
  return hashlib.sha256(json.dumps(rows,ensure_ascii=False).encode()).hexdigest()
 before={row['schema']+'.'+row['name']:snapshot(row['schema'],row['name']) for row in tables}
 bons={row['ID_Commande']:row for row in db.query('SELECT * FROM logistique."T_Commande"')}
 catalogue={row['CleInterface']:row for row in db.query('SELECT * FROM referentiel."T_InterfaceTableau"')}
 rules=['tr_numero_commande','tr_bon_initial_protection','proteger_bon_inventaire','proteger_bon_retour','tr_proteger_bon_facture','tr_lock_commande_cloturee','tr_crud_commande']
 definitions={name:direct.execute('SELECT pg_get_functiondef(to_regprocedure(%s)) definition',['logistique.'+name+'()']).fetchone()['definition'] for name in rules}
 emitted=datetime.now(timezone.utc)
 migration=ROOT/'backend/database/migrations/20261028_06_nomenclature_bons_historiques.sql'
 direct.execute(migration.read_text(encoding='utf8'))
 check(all(snapshot(row['schema'],row['name'])==before[row['schema']+'.'+row['name']] for row in tables if row['schema']+'.'+row['name'] not in ['logistique.T_Commande','referentiel.T_InterfaceTableau']),'Toutes les autres tables, anciens audits, factures, identités, lignes, mouvements, coûts et requêtes idempotentes restent strictement identiques')
 after={row['ID_Commande']:row for row in db.query('SELECT * FROM logistique."T_Commande"')}
 check(set(after)==set(bons),'Aucune identité de bon créée, réallouée ou supprimée')
 check(all({k:v for k,v in row.items() if k!='CodeCmd'}=={k:v for k,v in bons[key].items() if k!='CodeCmd'} for key,row in after.items()),'CodeCmd est la seule valeur changée dans T_Commande, même pour les bons protégés')
 check(all(row['CodeCmd']==db.one('SELECT logistique.fn_code_bon(%s,%s) code',[key,row['ID_TypeCmdFk']])['code'] for key,row in after.items()),'Chaque bon historique suit sa nature BE/BS/CMD sans changer ID ou type')
 check(after[neutral['ID_Commande']]['CodeCmd'].startswith('CMD-'),'Ancien code cmd d’une commande préparatoire devient CMD uppercase')
 check(after[normal['ID_Commande']]==bons[normal['ID_Commande']],'Bon déjà canonique inchangé et sans fausse correspondance')
 mapping={row['ID_Commande']:row for row in db.query('SELECT * FROM logistique."T_BonCodeHistorique"')}
 expected={key for key,row in bons.items() if row['CodeCmd']!=after[key]['CodeCmd']}
 check(set(mapping)==expected,'Journal contient exactement les bons effectivement renommés')
 check(all(mapping[key]['AncienCodeCmd']==bons[key]['CodeCmd'] and mapping[key]['NouveauCodeCmd']==after[key]['CodeCmd'] and mapping[key]['IdEntiteFk']==bons[key]['IdEntiteFk'] for key in expected),'Correspondance ancien/nouveau exacte et propriétaire historique durable')
 check(all(row['UtilisateurBase']=='precision_test_admin' and row['VersionMigration']=='20261028_06' and row['RenumeroteLe']>=emitted for row in mapping.values()),'Date réelle, version et utilisateur PostgreSQL factuels')
 check(all(direct.execute('SELECT pg_get_functiondef(to_regprocedure(%s)) definition',['logistique.'+name+'()']).fetchone()['definition']==definition for name,definition in definitions.items()),'Sept fonctions de garde/restock entièrement restaurées après la reprise')
 check(direct.execute("SELECT to_regprocedure('pg_temp.sn06_reprise_autorisee(jsonb,jsonb)') present").fetchone()['present'] is None,'Fonction de dérogation temporaire supprimée, aucun bypass durable')
 for interface,old in catalogue.items():
  new=db.one('SELECT * FROM referentiel."T_InterfaceTableau" WHERE "CleInterface"=%s',[interface])
  if interface in ['logistique.commandes','logistique.lignes']:
   check(new['Colonnes'][:-2]==old['Colonnes'] and new['Version']==old['Version']+1,'Catalogue conserve ordre/champs existants et incrémente une seule version : '+interface)
   check([row['id'] for row in new['Colonnes'][-2:]]==['AncienCodeCmd','RenumeroteLe'] and all(row['defaultVisible'] is False and row['defaultExport'] is False and row['exportable'] is True for row in new['Colonnes'][-2:]),'Nouveaux champs facultatifs masqués et non exportés par défaut : '+interface)
  else:check(new==old,'Autre catalogue inchangé : '+interface)
 sample=next(iter(expected));renamed=mapping[sample]
 check(db.one('SELECT logistique.fn_code_bon_a_date(%s,%s) code',[sample,emitted])['code']==bons[sample]['CodeCmd'],'Document émis avant la reprise garde son ancien code')
 check(db.one('SELECT logistique.fn_code_bon_a_date(%s,%s) code',[sample,renamed['RenumeroteLe']])['code']==bons[sample]['CodeCmd'],'Borne exacte de reprise conserve l’ancienne référence')
 check(db.one('SELECT logistique.fn_code_bon_a_date(%s,%s) code',[sample,renamed['RenumeroteLe']+timedelta(microseconds=1)])['code']==after[sample]['CodeCmd'],'Document émis ensuite porte le code actuel')
 check(db.one('SELECT logistique.fn_code_bon_a_date(%s,NULL) code',[sample])['code']==bons[sample]['CodeCmd'],'Date d’émission historique absente conserve l’ancienne référence')
 for name in ['V_Commande','V_CommandeDetail','V_CommandeOverview']:
  rows=db.query('SELECT "AncienCodeCmd","RenumeroteLe" FROM '+db.qualified('logistique',name)+' WHERE "ID_Commande"=%s',[sample])
  check(name=='V_CommandeDetail' and not rows or all(row['AncienCodeCmd']==renamed['AncienCodeCmd'] and row['RenumeroteLe']==renamed['RenumeroteLe'] for row in rows),'Correspondance exposée dans '+name)
 rejected(lambda:db.query('UPDATE logistique."T_Commande" SET "CodeCmd"=%s WHERE "ID_Commande"=%s',['ALTERE',normal['ID_Commande']]),'Code toujours immuable après la migration')
 rejected(lambda:db.query('UPDATE logistique."T_Commande" SET "ObsCmd"=%s WHERE "ID_Commande"=%s',['altéré',chaine['sale_id']]),'Protection du bon facturé et clôturé rétablie')
 protected_initial=db.one('SELECT "ID_Commande" id FROM logistique."T_Commande" WHERE "OrigineBon" IS NOT NULL LIMIT 1')['id']
 rejected(lambda:db.query('UPDATE logistique."T_Commande" SET "ObsCmd"=%s WHERE "ID_Commande"=%s',['altéré',protected_initial]),'Protection du stock initial rétablie')
 rejected(lambda:db.query('UPDATE logistique."T_BonCodeHistorique" SET "Motif"=%s WHERE "ID_Commande"=%s',['Altération fictive',sample]),'Journal refuse une modification directe')
 rejected(lambda:db.query('DELETE FROM logistique."T_BonCodeHistorique" WHERE "ID_Commande"=%s',[sample]),'Journal refuse une suppression directe')
 rejected(lambda:db.query('INSERT INTO logistique."T_BonCodeHistorique"("ID_Commande","NouveauCodeCmd","Motif","VersionMigration") VALUES(%s,%s,%s,%s)',[normal['ID_Commande'],normal['CodeCmd'],'Insertion fictive interdite','20261028_06']),'Journal refuse une insertion applicative après clôture de reprise')
 # A removable CMD without lines can be deleted; its alias proof must survive.
 deleted=neutral['ID_Commande'];old=after[deleted]['CodeCmd'];ancient=bons[deleted]['CodeCmd']
 db.query('DELETE FROM logistique."T_Commande" WHERE "ID_Commande"=%s',[deleted])
 check(db.one('SELECT logistique.fn_code_bon_a_date(%s,NULL) code',[deleted])['code']==ancient and db.one('SELECT logistique.fn_code_bon_a_date(%s,clock_timestamp()) code',[deleted])['code']==old,'Correspondance et résolution temporelle survivent à une suppression autorisée du bon')
 check(db.one("SELECT count(*) n FROM pg_constraint WHERE conrelid='logistique.\"T_BonCodeHistorique\"'::regclass AND obj_description(oid,'pg_constraint') IS NULL")['n']==0,'Toutes les contraintes, y compris NOT NULL, du journal sont commentées')
 check(db.one("SELECT count(*) n FROM pg_attribute WHERE attrelid='logistique.\"T_BonCodeHistorique\"'::regclass AND attnum>0 AND NOT attisdropped AND col_description(attrelid,attnum) IS NULL")['n']==0,'Toutes les colonnes factuelles du journal sont commentées')
 result={'checks':len(checks),'details':checks,'fixtureChain':112,'fixtureInventory':31,'database':location.path[1:],'renamedDocuments':len(expected),'migrationSHA256':hashlib.sha256(migration.read_bytes()).hexdigest(),'productionWrites':False}
 target=ROOT/'.runtime/nomenclature06/verification.json';target.parent.mkdir(exist_ok=True);target.write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf8')
 print(json.dumps(result,ensure_ascii=False))
