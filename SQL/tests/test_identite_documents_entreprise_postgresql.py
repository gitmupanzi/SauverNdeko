"""Identité courante SQL07 sur fixtures privées06, sans données clientes.

La base privée comporte les fixtures chaîne/inventaires de test_nomenclature_bons.
La recette compare toutes les anciennes tables avant/après, puis vérifie le
profil, les options, le PNG, le masquage binaire et les instantanés immuables.
"""
import hashlib,io,json,os,uuid
from pathlib import Path
from urllib.parse import urlsplit
import psycopg
from psycopg import sql
from psycopg.rows import dict_row
from psycopg.types.json import Jsonb
from PIL import Image

ROOT=Path(__file__).resolve().parents[2];DSN=os.environ.get('SAUVERNDEKO_TEST_DATABASE_URL','');location=urlsplit(DSN)
if location.hostname not in {'127.0.0.1','localhost'} or not location.path[1:].startswith('sauverndeko_test_'):raise RuntimeError('Base locale privée obligatoire')
checks=[]
def check(value,label):assert value,label;checks.append(label)
with psycopg.connect(DSN,autocommit=True,row_factory=dict_row) as connection:
 if not connection.execute('SELECT current_database() n').fetchone()['n'].startswith('sauverndeko_test_'):raise RuntimeError('Base privée requise')
 if connection.execute("SELECT to_regclass('logistique.\"T_BonCodeHistorique\"') present").fetchone()['present'] is None:raise RuntimeError('Socle06 requis')
 def query(statement,params=()):return connection.execute(statement,params)
 def one(statement,params=()):return query(statement,params).fetchone()
 def rejected(callback,label):
  try:
   with connection.transaction():callback()
  except psycopg.Error as error:
   assert error.sqlstate not in ('42601','42703','42883','42P01'),(label,str(error))
   check(True,label)
  else:raise AssertionError(label)
 def all_rows(schema,table):return query(sql.SQL('SELECT to_jsonb(t)::text row FROM {}.{} t ORDER BY to_jsonb(t)::text').format(sql.Identifier(schema),sql.Identifier(table))).fetchall()
 def digest(schema,table):return hashlib.sha256(json.dumps(all_rows(schema,table),ensure_ascii=False).encode()).hexdigest()
 tables=query("SELECT n.nspname schema,c.relname name FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE c.relkind='r' AND n.nspname=ANY(%s) ORDER BY 1,2",[['analytics','communication','geolocalisation','logistique','operations','professionnel','referentiel','systeme']]).fetchall()
 before={row['schema']+'.'+row['name']:digest(row['schema'],row['name']) for row in tables}
 entities={row['IdEntite']:row for row in query('SELECT * FROM systeme."T_Entite"')}
 check(len(entities)>=2 and one('SELECT count(*) n FROM logistique."T_Facture"')['n']>0 and one('SELECT count(*) n FROM logistique."T_DocumentIdentite"')['n']>0,'Fixtures couvrent deux entreprises, factures émises et identités conservées')
 migration=ROOT/'backend/database/migrations/20261028_07_identite_documents_entreprise.sql'
 connection.execute(migration.read_text(encoding='utf8'))
 check(all(digest(row['schema'],row['name'])==before[row['schema']+'.'+row['name']] for row in tables if row['schema']+'.'+row['name']!='systeme.T_Entite'),'Migration conserve intégralement toutes les autres tables : finance, identité historique, coûts, mouvements, audits et journal des codes')
 added={'SiteWebEntite','AfficherEnteteDocument','AfficherPiedDocument','LogoEntite','LogoMimeEntite','LogoSha256Entite','LogoModifieLe','PhoneSecondaireEntite'}
 after={row['IdEntite']:row for row in query('SELECT * FROM systeme."T_Entite"')}
 check(set(after)==set(entities) and all({key:value for key,value in row.items() if key not in added}==entities[pk] for pk,row in after.items()),'Tous les champs existants des entreprises restent strictement identiques')
 check(all(row['AfficherEnteteDocument'] is True and row['AfficherPiedDocument'] is True and all(row[key] is None for key in added-{'AfficherEnteteDocument','AfficherPiedDocument'}) for row in after.values()),'Défauts true pour en-tête et pied ; absence réelle du site et logo')
 entity=min(entities);other=max(entities);old_other=one('SELECT to_jsonb(e) row FROM systeme."T_Entite" e WHERE "IdEntite"=%s',[other])['row']
 old_identity=all_rows('logistique','T_DocumentIdentite');old_finance={table:digest('logistique',table) for table in ['T_Facture','T_FactureLigne','T_Reglements','T_Avoir','T_AvoirLigne','T_Mouvement','T_ValorisationEvenement']}
 profile=one('SELECT * FROM systeme."V_IdentiteDocumentaire" WHERE "IdEntite"=%s',[entity])
 check(profile['HasLogo'] is False and 'LogoEntite' not in profile,'Vue de profil sans octets et sans logo inventé')
 check(one("SELECT count(*) n FROM information_schema.columns WHERE table_schema='systeme' AND table_name='V_IdentiteDocumentaire' AND data_type='bytea'")['n']==0,'Aucun champ binaire dans la projection de profil')
 check(one("SELECT column_name FROM information_schema.columns WHERE table_schema='systeme' AND table_name='V_IdentiteDocumentaire' ORDER BY ordinal_position DESC LIMIT 1")['column_name']=='PhoneSecondaireEntite','Téléphone secondaire ajouté en fin de vue pour conserver les positions existantes')
 query('UPDATE systeme."T_Entite" SET "PhoneSecondaireEntite"=%s WHERE "IdEntite"=%s',['+243 810 123 456',entity])
 phone=one('SELECT systeme.fn_identite_documentaire(%s) identity',[entity])['identity']
 check(phone['PhoneSecondaireEntite']=='+243 810 123 456' and one('SELECT "PhoneSecondaireEntite" phone FROM systeme."V_IdentiteDocumentaire" WHERE "IdEntite"=%s',[entity])['phone']==phone['PhoneSecondaireEntite'],'Téléphone secondaire validé partagé par la vue et la fonction courante')
 for invalid_phone in [' +243810123456','+243810123456 ','+243\n810123456','x'*21,'']:
  rejected(lambda invalid_phone=invalid_phone:query('UPDATE systeme."T_Entite" SET "PhoneSecondaireEntite"=%s WHERE "IdEntite"=%s',[invalid_phone,entity]),'Téléphone secondaire vide, trop long, contrôlé ou non nettoyé refusé : '+str(len(checks)))
 query('UPDATE systeme."T_Entite" SET "PhoneSecondaireEntite"=NULL WHERE "IdEntite"=%s',[entity])
 check(one('SELECT systeme.fn_identite_documentaire(%s) identity',[entity])['identity']['PhoneSecondaireEntite'] is None,'Téléphone secondaire facultatif supprimable sans modifier le numéro principal')
 legal=[{'libelle':'RCCM','valeur':'FICTIF-RCCM-123'},{'libelle':'NIF','valeur':'FICTIF-NIF-456'}]
 query('UPDATE systeme."T_Entite" SET "NomEntite"=%s,"AdresseEntite"=%s,"SiteWebEntite"=%s,"IdentifiantsLegauxEntite"=%s,"MentionDocumentaireEntite"=%s WHERE "IdEntite"=%s',['Nom courant fictif '+uuid.uuid4().hex,'Adresse fictive\nDeuxième ligne','https://entreprise.example.invalid',Jsonb(legal),'Mention courante\nDeuxième ligne',entity])
 identity=one('SELECT systeme.fn_identite_documentaire(%s) identity',[entity])['identity']
 check(identity['NomEntite'].startswith('Nom courant fictif') and identity['IdentifiantsLegauxEntite']==legal and identity['SiteWebEntite']=='https://entreprise.example.invalid','Source canonique fournit immédiatement le nom, site et identifiants courants')
 check(identity['AfficherEnteteDocument'] is True and identity['AfficherPiedDocument'] is True and identity['HasLogo'] is False and 'LogoEntite' not in identity,'JSON canonique expose seulement options et métadonnées du logo')
 check(all_rows('logistique','T_DocumentIdentite')==old_identity,'Changement du nom et du profil ne réécrit aucun instantané d’identité émis')
 check(all(digest('logistique',table)==value for table,value in old_finance.items()),'Changement de présentation ne modifie ni facture, tiers figé, règlement, avoir, coût ou mouvement')
 query('UPDATE systeme."T_Entite" SET "AfficherEnteteDocument"=false WHERE "IdEntite"=%s',[entity])
 opts=one('SELECT systeme.fn_identite_documentaire(%s) identity',[entity])['identity']
 check(opts['AfficherEnteteDocument'] is False and opts['AfficherPiedDocument'] is True,'En-tête désactivable sans affecter le pied')
 query('UPDATE systeme."T_Entite" SET "AfficherEnteteDocument"=true,"AfficherPiedDocument"=false WHERE "IdEntite"=%s',[entity])
 opts=one('SELECT * FROM systeme."V_IdentiteDocumentaire" WHERE "IdEntite"=%s',[entity])
 check(opts['AfficherEnteteDocument'] is True and opts['AfficherPiedDocument'] is False,'Pied désactivable indépendamment et persisté en base')
 rejected(lambda:query('UPDATE systeme."T_Entite" SET "AfficherEnteteDocument"=NULL WHERE "IdEntite"=%s',[entity]),'Option d’en-tête ne peut pas devenir NULL')
 rejected(lambda:query('UPDATE systeme."T_Entite" SET "AfficherPiedDocument"=NULL WHERE "IdEntite"=%s',[entity]),'Option de pied ne peut pas devenir NULL')
 for website in ['javascript:alert(1)','data:text/html,test','ftp://example.invalid','https://user:password@example.invalid','https://example.invalid/ avec espace','https://','https://example.invalid/\n','https://example.invalid/'+'x'*256]:
  rejected(lambda website=website:query('UPDATE systeme."T_Entite" SET "SiteWebEntite"=%s WHERE "IdEntite"=%s',[website,entity]),'Site non HTTP(S), mal formé ou trop long refusé : '+str(len(checks)))
 query('UPDATE systeme."T_Entite" SET "SiteWebEntite"=%s,"AdresseEntite"=%s WHERE "IdEntite"=%s',['http://serveur-interne:8080/contact','Adresse\r\nDeuxième ligne',entity])
 check(True,'Site HTTP intranet et adresse CRLF autorisés sans imposer de domaine public')
 rejected(lambda:query('UPDATE systeme."T_Entite" SET "AdresseEntite"=%s WHERE "IdEntite"=%s',['Adresse\tContrôle',entity]),'Contrôle de tabulation interdit dans une nouvelle adresse')
 rejected(lambda:query('UPDATE systeme."T_Entite" SET "AdresseEntite"=%s WHERE "IdEntite"=%s',['x'*1001,entity]),'Adresse documentaire trop longue refusée en SQL')
 rejected(lambda:query('UPDATE systeme."T_Entite" SET "MentionDocumentaireEntite"=%s WHERE "IdEntite"=%s',['Mention\tContrôle',entity]),'Garde de mention documentaire existante conservée')
 for invalid in [[{'libelle':'RCCM','valeur':'A'},{'libelle':' rccm ','valeur':'B'}],[{'libelle':'RCCM','valeur':'A','extra':'B'}],[{'libelle':'NIF','valeur':'A'}]*11,[{'libelle':'NIF','valeur':'x\t'}]]:
  rejected(lambda invalid=invalid:query('UPDATE systeme."T_Entite" SET "IdentifiantsLegauxEntite"=%s WHERE "IdEntite"=%s',[Jsonb(invalid),entity]),'Identifiants déclaratifs arbitraires, doublons ou contrôles refusés : '+str(len(checks)))
 image=Image.new('RGB',(160,60),(30,100,140));stream=io.BytesIO();image.save(stream,format='PNG');png=stream.getvalue();sha=hashlib.sha256(png).hexdigest()
 def logo(data=png,mime='image/png',fingerprint=sha,date=True):
  query('UPDATE systeme."T_Entite" SET "LogoEntite"=%s,"LogoMimeEntite"=%s,"LogoSha256Entite"=%s,"LogoModifieLe"=CASE WHEN %s THEN clock_timestamp() ELSE NULL END WHERE "IdEntite"=%s',[data,mime,fingerprint,date,entity])
 logo()
 profile=one('SELECT * FROM systeme."V_IdentiteDocumentaire" WHERE "IdEntite"=%s',[entity])
 check(profile['HasLogo'] is True and profile['LogoMimeEntite']=='image/png' and profile['LogoSha256Entite']==sha and profile['LogoModifieLe'] is not None,'PNG normalisé conservé avec MIME, SHA et date dans les métadonnées courantes')
 check(one('SELECT "LogoEntite" data FROM systeme."T_Entite" WHERE "IdEntite"=%s',[entity])['data']==png,'Octets du logo conservés exactement dans PostgreSQL')
 check(profile['_version']!=opts['_version'],'Révision du profil évolue lors de la pose du logo')
 rejected(lambda:logo(fingerprint='0'*64),'SHA falsifié refusé indépendamment du backend')
 rejected(lambda:logo(mime='image/jpeg'),'MIME non PNG refusé même sur des octets PNG')
 rejected(lambda:logo(date=False),'Logo partiel sans date refusé')
 rejected(lambda:query('UPDATE systeme."T_Entite" SET "LogoEntite"=NULL WHERE "IdEntite"=%s',[entity]),'Effacement partiel sans les métadonnées refusé')
 bad=b'not-a-png'+png[9:]
 rejected(lambda:logo(data=bad,fingerprint=hashlib.sha256(bad).hexdigest()),'Fausse signature PNG refusée même avec SHA correspondant')
 bad=png[:-12]+b'bad-end-data'
 rejected(lambda:logo(data=bad,fingerprint=hashlib.sha256(bad).hexdigest()),'Fausse fin IEND refusée même avec SHA correspondant')
 huge=png[:33]+b'x'*(2097153-45)+png[-12:]
 rejected(lambda:logo(data=huge,fingerprint=hashlib.sha256(huge).hexdigest()),'PNG dépassant2Mo refusé en SQL')
 masked=one('SELECT systeme.fn_audit_sans_secrets(to_jsonb(e)) clean FROM systeme."T_Entite" e WHERE "IdEntite"=%s',[entity])['clean']
 check('LogoEntite' not in masked and masked['LogoSha256Entite']==sha and masked['LogoMimeEntite']=='image/png','Audit supprime les octets et conserve les métadonnées d’intégrité')
 nested={'nested':[json.dumps({'LogoEntite':'octets privés fictifs','LogoSha256Entite':sha,'password':'secret fictif'})]}
 masked=one('SELECT systeme.fn_audit_sans_secrets(%s) clean',[Jsonb(nested)])['clean']
 check(masked=={'nested':[{'LogoSha256Entite':sha}]},'Masquage binaire et secret fonctionne aussi sur listes et JSON encodé')
 check(all_rows('logistique','T_DocumentIdentite')==old_identity and all(digest('logistique',table)==value for table,value in old_finance.items()),'Logo et options restent sans effet sur les instantanés et écritures financières')
 check(one('SELECT to_jsonb(e) row FROM systeme."T_Entite" e WHERE "IdEntite"=%s',[other])['row']==old_other,'Profil d’une autre entreprise inchangé')
 query('UPDATE systeme."T_Entite" SET "LogoEntite"=NULL,"LogoMimeEntite"=NULL,"LogoSha256Entite"=NULL,"LogoModifieLe"=NULL WHERE "IdEntite"=%s',[entity])
 check(one('SELECT "HasLogo" present FROM systeme."V_IdentiteDocumentaire" WHERE "IdEntite"=%s',[entity])['present'] is False,'Suppression complète du logo conserve le reste du profil')
 new=one('INSERT INTO systeme."T_Entite"("NomEntite","EmailEntite") VALUES(%s,%s) RETURNING "AfficherEnteteDocument" head,"AfficherPiedDocument" foot',['Nouvelle entreprise fictive',uuid.uuid4().hex+'@example.invalid'])
 check(new=={'head':True,'foot':True},'Nouvelles entreprises reçoivent les deux options activées par défaut')
 constraints=['ck_entite_site_web','ck_entite_logo_complet','ck_entite_logo_png','ck_entite_adresse_documentaire','ck_entite_phone_secondaire','T_Entite_AfficherEnteteDocument_not_null','T_Entite_AfficherPiedDocument_not_null']
 check(one("SELECT count(*) n FROM pg_constraint WHERE conrelid='systeme.\"T_Entite\"'::regclass AND conname=ANY(%s) AND obj_description(oid,'pg_constraint') IS NOT NULL",[constraints])['n']==7,'Sept contraintes nouvelles, dont NOT NULL, documentées par COMMENT ON')
 check(one("SELECT count(*) n FROM pg_attribute WHERE attrelid='systeme.\"T_Entite\"'::regclass AND attname=ANY(%s) AND col_description(attrelid,attnum) IS NOT NULL",[list(added)])['n']==8,'Huit nouveaux champs de présentation documentés en base')
 check(one("SELECT count(*) n FROM information_schema.columns c JOIN pg_class r ON r.relname=c.table_name JOIN pg_namespace n ON n.oid=r.relnamespace AND n.nspname=c.table_schema JOIN pg_attribute a ON a.attrelid=r.oid AND a.attname=c.column_name WHERE c.table_schema='systeme' AND c.table_name='V_IdentiteDocumentaire' AND c.column_name=ANY(%s) AND col_description(r.oid,a.attnum) IS NOT NULL",[['SiteWebEntite','AfficherEnteteDocument','AfficherPiedDocument','HasLogo','LogoMimeEntite','LogoSha256Entite','LogoModifieLe','PhoneSecondaireEntite']])['n']==8,'Vue courante et ses huit nouvelles métadonnées documentées')
 result={'checks':len(checks),'details':checks,'database':location.path[1:],'migrationSHA256':hashlib.sha256(migration.read_bytes()).hexdigest(),'productionWrites':False,'sourceSnapshotsPreserved':True,'financePreserved':True}
 target=ROOT/'.runtime/identite-pdf07/verification.json';target.parent.mkdir(exist_ok=True);target.write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf8')
 print(json.dumps(result,ensure_ascii=False))
