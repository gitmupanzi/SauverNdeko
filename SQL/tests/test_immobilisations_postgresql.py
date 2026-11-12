"""Patrimoine08 : recette SQL directe sur copie07 exclusivement fictive.

Le script applique08 sur une base sauverndeko_test_* sans T_Immobilisation,
compare les anciennes lignes, puis crée ses propres entreprises et acteurs.
Pas de connexion de repli vers la base applicative, ni d'effet de stock.
"""
import hashlib,json,os,threading,time,uuid
from concurrent.futures import ThreadPoolExecutor
from datetime import date,timedelta
from decimal import Decimal
from pathlib import Path
from urllib.parse import urlsplit
import psycopg
from psycopg import sql
from psycopg.rows import dict_row
from psycopg.types.json import Jsonb

ROOT=Path(__file__).resolve().parents[2]
DSN=os.environ.get('SAUVERNDEKO_TEST_DATABASE_URL','');target=urlsplit(DSN)
if target.hostname not in {'localhost','127.0.0.1'} or not target.path[1:].startswith('sauverndeko_test_'):raise RuntimeError('Base locale privée obligatoire')
checks=[];tag=uuid.uuid4().hex[:12]
def check(value,label):assert value,label;checks.append(label)
with psycopg.connect(DSN,autocommit=True,row_factory=dict_row) as c:
 def q(statement,params=None):return c.execute(statement,params)
 def one(statement,params=None):return q(statement,params).fetchone()
 def rows(schema,table):return [r['data'] for r in q(sql.SQL('SELECT to_jsonb(t) data FROM {}.{} t ORDER BY to_jsonb(t)::text').format(sql.Identifier(schema),sql.Identifier(table)))]
 def fingerprint(schema,table):return hashlib.sha256(json.dumps(rows(schema,table),sort_keys=True,default=str).encode()).hexdigest()
 def rejected(callback,label):
  try:
   with c.transaction():callback()
  except psycopg.Error as error:
   assert error.sqlstate not in ['42601','42703','42883','42P01'],(label,str(error))
   check(True,label)
  else:raise AssertionError(label)
 check(one('SELECT current_database() name')['name']==target.path[1:],'Connexion effectivement privée')
 if one("SELECT to_regclass('logistique.\"T_Immobilisation\"') t")['t'] is not None:raise RuntimeError('Recette exige le socle07 avant migration08')
 tables=q("SELECT n.nspname schema,c.relname name FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE c.relkind='r' AND n.nspname=ANY(%s) ORDER BY 1,2",[['analytics','communication','geolocalisation','logistique','operations','professionnel','referentiel','systeme']]).fetchall()
 before={(r['schema'],r['name']):rows(r['schema'],r['name']) for r in tables}
 old_profile=q("SELECT column_name FROM information_schema.columns WHERE table_schema='systeme' AND table_name='V_User_profil' ORDER BY ordinal_position").fetchall()
 source=ROOT/'backend/database/migrations/20261028_08_immobilisations_affectations.sql'
 q(source.read_text(encoding='utf8'))
 new_rh={'MatriculeUser','ID_ServiceFk','ID_FonctionFk','DateEmbauche','DateFinEmploi','ObservationProfessionnelle'}
 append_only={('referentiel','T_CategorieGenerique'):1,('referentiel','T_Generique'):6,('referentiel','T_InterfaceTableau'):1,('systeme','T_Fk_Correspondance'):3,('systeme','T_Audit_Log'):3}
 for key,old_rows in before.items():
  actual=rows(*key)
  if key==('systeme','T_Utilisateurs'):
   stripped=[{k:v for k,v in r.items() if k not in new_rh} for r in actual]
   check(sorted(map(lambda r:json.dumps(r,sort_keys=True,default=str),stripped))==sorted(map(lambda r:json.dumps(r,sort_keys=True,default=str),old_rows)) and all(all(r[k] is None for k in new_rh) for r in actual),'Migration conserve les comptes existants et leurs anciens champs sans valeur RH inventée')
  elif key==('referentiel','T_InterfaceTableau'):
   old_other=[r for r in old_rows if r['CleInterface'] not in ['admin.profils','admin.utilisateurs']];new_other=[r for r in actual if r['CleInterface'] not in ['admin.profils','admin.utilisateurs']]
   check({json.dumps(r,sort_keys=True,default=str) for r in old_other}<={json.dumps(r,sort_keys=True,default=str) for r in new_other} and len(actual)==len(old_rows)+1,'Nouveau catalogue patrimoine et tous les autres catalogues inchangés hors utilisateurs/profils privés')
   old_prof=next(r for r in old_rows if r['CleInterface']=='admin.profils');new_prof=next(r for r in actual if r['CleInterface']=='admin.profils')
   prior_columns={r['id']:r for r in old_prof['Colonnes']};new_columns={r['id']:r for r in new_prof['Colonnes']}
   check(new_prof['Version']==old_prof['Version']+1 and len(new_columns)==len(prior_columns)+9 and all({k:v for k,v in item.items() if k not in ['defaultVisible','defaultOrder']}=={k:v for k,v in new_columns[name].items() if k not in ['defaultVisible','defaultOrder']} for name,item in prior_columns.items()),'Catalogue profils : neuf colonnes ajoutées, version+1, politique d’export et définitions précédentes conservées')
   check([r['id'] for r in sorted(new_prof['Colonnes'],key=lambda row:row['defaultOrder']) if r['defaultVisible']]==['NomUser','MatriculeUser','NomEntite','Service','Fonction','ValideUser','actions'],'Ordre tableau profils par défaut conforme au contrat RH')
   old_user=next(r for r in old_rows if r['CleInterface']=='admin.utilisateurs');new_user=next(r for r in actual if r['CleInterface']=='admin.utilisateurs')
   prior_user_columns={r['id']:r for r in old_user['Colonnes']};new_user_columns={r['id']:r for r in new_user['Colonnes']}
   check(new_user['Version']==old_user['Version']+1 and len(new_user_columns)==len(prior_user_columns)+9 and all({k:v for k,v in item.items() if k not in ['defaultVisible','defaultOrder']}=={k:v for k,v in new_user_columns[name].items() if k not in ['defaultVisible','defaultOrder']} for name,item in prior_user_columns.items()),'Fusion utilisateurs : neuf colonnes ajoutées, version+1 et politique d’export précédente conservée')
   check([r['id'] for r in sorted(new_user['Colonnes'],key=lambda row:row['defaultOrder']) if r['defaultVisible']]==['NomUser','MatriculeUser','NomEntite','Service','Fonction','Role','ValideUser','Is_Admin','actions'],'Ordre tableau utilisateurs fusionné conforme au contrat RH et sécurité')
  elif key in append_only:
   old_set={json.dumps(r,sort_keys=True,default=str) for r in old_rows};new_set={json.dumps(r,sort_keys=True,default=str) for r in actual}
   check(old_set<=new_set and len(actual)-len(old_rows)==append_only[key],'Reprise strictement additive '+'.'.join(key))
  else:
   check(actual==old_rows,'Table existante inchangée '+'.'.join(key))
 check(q("SELECT column_name FROM information_schema.columns WHERE table_schema='systeme' AND table_name='V_User_profil' ORDER BY ordinal_position").fetchall()==old_profile,'Profil utilisateur antérieur non élargi avec des données RH')
 check(one('SELECT count(*) n FROM logistique."T_Immobilisation"')['n']==0,'Aucun équipement fictif créé par la migration')
 catalogue={r['id']:r for r in one('SELECT "Colonnes" columns FROM referentiel."T_InterfaceTableau" WHERE "CleInterface"=%s',['logistique.immobilisations'])['columns']}
 hidden_ids=['ID_Immobilisation','ID_CategorieFk','ID_EtatFk','ID_ResponsableFk','ID_ServiceFk','ID_LocalisationFk','ID_DeviseFk']
 check(all(catalogue[key]['tableAvailable'] is False and catalogue[key]['exportable'] is True and catalogue[key]['defaultVisible'] is False for key in hidden_ids),'Identifiants techniques sans renderer absents des choix du tableau, exportables seulement si choisis')
 check(all(catalogue[key]['label']==label for key,label in {'Reference':'Référence','Quantite':'Quantité','PrixUnitaire':'Prix unitaire','SuiviIndividuel':'Mode de suivi','DateAcquisition':'Date d’acquisition','NumeroSerie':'N° de série','LocalisationComplement':'Bureau ou salle','NomEntite':'Entreprise','CreeLe':'Créé le','ModifieLe':'Modifié le','Actif':'État de la fiche'}.items()),'Libellés métier du catalogue humains et cohérents avec les renderers')
 untouched=['T_Article','T_Commande','T_CommandeDetail','T_Mouvement','T_LotArticle','T_MouvementLot','T_Facture','T_Reglements','T_ValorisationEvenement']
 unchanged={t:fingerprint('logistique',t) for t in untouched if one('SELECT to_regclass(%s) present',['logistique."'+t+'"'])['present']}
 def category(name):return one('SELECT "ID_CategorieGenerique" id FROM referentiel."T_CategorieGenerique" WHERE lower(btrim("NomCategorieGenerique"))=lower(%s)',[name])['id']
 def ref(family):return one('SELECT "ID_Generique" id FROM referentiel."T_Generique" WHERE "ID_CategorieGeneriqueFk"=%s AND "ValideGenerique" ORDER BY "ID_Generique" LIMIT 1',[category(family)])['id']
 typ=ref('Type de matériel');state=ref('Etat');service=ref('Service');function=ref('Fonction');currency=ref('Devise')
 check(one('SELECT count(*) n FROM referentiel."T_Generique" WHERE "ID_CategorieGeneriqueFk"=%s',[category('Type de matériel')])['n']==5,'Cinq types de matériel dans le référentiel partagé')
 check(one('SELECT count(*) n FROM referentiel."T_Generique" WHERE "ID_CategorieGeneriqueFk"=%s AND "NomGenerique"=%s',[category('Etat'),'Hors usage'])['n']==1,'État Hors usage ajouté dans la famille existante')
 def entity(label):return one('INSERT INTO systeme."T_Entite"("NomEntite","EmailEntite") VALUES(%s,%s) RETURNING "IdEntite" id',[label+' '+tag,uuid.uuid4().hex+'@example.invalid'])['id']
 ea=entity('Patrimoine A fictif');eb=entity('Patrimoine B fictif')
 def user(company,label='Acteur',**extra):
  body={'NomUser':label,'PrenomUser':'Fictif','EmailUser':uuid.uuid4().hex+'@example.invalid','MotdepasseUser':'empreinte-fictive-inutilisable','SexeUser':'M','IdEntiteFk':company,**extra}
  return one(sql.SQL('INSERT INTO systeme."T_Utilisateurs"({}) VALUES({}) RETURNING "IdUser" id').format(sql.SQL(',').join(map(sql.Identifier,body)),sql.SQL(',').join(sql.Placeholder() for _ in body)),list(body.values()))['id']
 actor=user(ea);global_actor=user(None,'Plateforme',Is_Admin=True);employee=user(ea,'Responsable',ID_ServiceFk=service,ID_FonctionFk=function);other_employee=user(eb,'Autre entreprise')
 def context(actor_id=actor,request=None):
  q("SELECT set_config('systeme.actor_user_id',%s,false)",[str(actor_id) if actor_id else ''])
  q("SELECT set_config('logistique.immobilisation_request',%s,false)",[json.dumps(request) if request else ''])
 context()
 la=one('INSERT INTO systeme."T_Entite_Localisation"("IdEntiteFk","AdresseDetaillee") VALUES(%s,%s) RETURNING "IdEntiteLocalisation" id',[ea,'Adresse A fictive'])['id']
 lb=one('INSERT INTO systeme."T_Entite_Localisation"("IdEntiteFk","AdresseDetaillee") VALUES(%s,%s) RETURNING "IdEntiteLocalisation" id',[eb,'Adresse B fictive'])['id']
 def create(**extra):
  body={'IdEntiteFk':ea,'NomImmobilisation':'Bien fictif '+tag,'ID_CategorieFk':typ,**extra}
  return one(sql.SQL('INSERT INTO logistique."T_Immobilisation"({}) VALUES({}) RETURNING *').format(sql.SQL(',').join(map(sql.Identifier,body)),sql.SQL(',').join(sql.Placeholder() for _ in body)),list(body.values()))
 def update(pk,**extra):return one(sql.SQL('UPDATE logistique."T_Immobilisation" SET {} WHERE "ID_Immobilisation"=%s RETURNING *').format(sql.SQL(',').join(sql.SQL('{}=%s').format(sql.Identifier(k)) for k in extra)),[*extra.values(),pk])
 def view(pk):return one('SELECT * FROM logistique."V_Immobilisation" WHERE "ID_Immobilisation"=%s',[pk])
 unknown=create(ID_ResponsableFk=employee,ID_LocalisationFk=la)
 pk=unknown['ID_Immobilisation']
 check(unknown['Quantite']==1 and unknown['SuiviIndividuel'] and unknown['Actif'],'Fiche individuelle et quantité1 par défaut')
 check(unknown['CodeImmobilisation']=='IMMO-'+str(pk),'Code automatique court depuis le même identifiant')
 check(unknown['PrixUnitaire'] is None and view(pk)['ValeurAcquisition'] is None and unknown['ID_EtatFk'] is None,'Prix et état inconnus restent NULL sans zéro ou bon état inventés')
 check(unknown['CreeParUserFk']==actor and unknown['ModifieParUserFk']==actor and unknown['CreeLe'] is not None,'Auteur et dates techniques imposés par SQL')
 check(view(pk)['Responsable']=='Fictif Responsable' and view(pk)['Localisation']=='Adresse A fictive','Responsable et localisation joints dans leur entreprise')
 check(view(pk)['_version'] is not None and view(pk)['ID_Immobilisation']==pk,'Révision opaque et grain un bien dans la vue commune')
 before_revision=view(pk)['_version'];update(pk,Observations='Note\nDeuxième ligne',Caracteristiques='Détail\r\nDeuxième ligne')
 check(view(pk)['_version']!=before_revision,'Révision mise à jour après écriture')
 grp=create(SuiviIndividuel=False,Quantite=3,PrixUnitaire=Decimal('10.25'),ID_DeviseFk=currency,ID_ServiceFk=service,ID_EtatFk=state)
 check(view(grp['ID_Immobilisation'])['ValeurAcquisition']==Decimal('30.75'),'Valeur SQL exacte d’un groupe homogène, arrondie à2 décimales')
 zero=create(PrixUnitaire=0,ID_DeviseFk=currency)
 check(view(zero['ID_Immobilisation'])['ValeurAcquisition']==0,'Prix nul connu distinct du coût absent')
 for qty in ['0','-1','0.5','1.0000000001','1000000000000000000','NaN','Infinity']:
  rejected(lambda qty=qty:create(SuiviIndividuel=False,Quantite=Decimal(qty)),'Quantité non entière, hors borne ou non finie refusée : '+qty)
 huge=create(SuiviIndividuel=False,Quantite=Decimal('999999999999999999'))
 check(huge['Quantite']==Decimal('999999999999999999'),'Maximum entier18 chiffres conservé exactement')
 rejected(lambda:create(Quantite=2),'Suivi individuel interdit plusieurs biens')
 rejected(lambda:create(SuiviIndividuel=False,Quantite=2,NumeroSerie='SERIE-'+tag),'Numéro de série impose une seule pièce même en mode groupe')
 for body in [{'PrixUnitaire':-1,'ID_DeviseFk':currency},{'PrixUnitaire':Decimal('NaN'),'ID_DeviseFk':currency},{'PrixUnitaire':10},{'ID_CategorieFk':currency},{'ID_EtatFk':currency},{'ID_ServiceFk':currency},{'ID_DeviseFk':service}]:
  rejected(lambda body=body:create(**body),'Prix, devise ou famille générique invalide refusés : '+str(len(checks)))
 for body in [{'NomImmobilisation':''},{'NomImmobilisation':' nom '},{'NomImmobilisation':'x'*201},{'Reference':'x'*256},{'NumeroSerie':'\tserie'},{'LocalisationComplement':' x '},{'Caracteristiques':'x'*4001},{'Observations':'a\tb'},{'DateEntree':'infinity'},{'DateAcquisition':'infinity'}]:
  rejected(lambda body=body:create(**body),'Borne ou format de champ refusé : '+str(len(checks)))
 for field,value in [('CodeImmobilisation','IMMO-FAUX'),('IdEntiteFk',eb),('CreeLe',date(2000,1,1)),('CreeParUserFk',global_actor)]:
  rejected(lambda field=field,value=value:update(pk,**{field:value}),'Champ immuable protégé '+field)
 rejected(lambda:create(CodeImmobilisation='IMMO-MANUEL'),'Code manuel interdit à la création')
 rejected(lambda:q('DELETE FROM logistique."T_Immobilisation" WHERE "ID_Immobilisation"=%s',[pk]),'Suppression physique refusée : archivage conservant l’historique')
 rejected(lambda:create(IdEntiteFk=eb),'Auteur local ne crée pas de bien dans une autre entreprise')
 rejected(lambda:create(ID_ResponsableFk=other_employee),'Responsable d’une autre entreprise refusé')
 rejected(lambda:create(ID_LocalisationFk=lb),'Localisation d’une autre entreprise refusée')
 context(global_actor);other=create(IdEntiteFk=eb,ID_ResponsableFk=other_employee,ID_LocalisationFk=lb)
 check(other['IdEntiteFk']==eb and view(other['ID_Immobilisation'])['Localisation']=='Adresse B fictive','Compte global crée explicitement dans une autre entreprise sans mélanger les affectations')
 rejected(lambda:create(IdEntiteFk=eb,ID_ResponsableFk=employee),'Le compte global ne contourne pas la cohérence entreprise du responsable')
 context()
 inactive=user(ea,'Inactif',ValideUser=False);past=user(ea,'Ancien emploi',DateEmbauche=date.today()-timedelta(days=20),DateFinEmploi=date.today()-timedelta(days=1));future=user(ea,'Emploi futur',DateEmbauche=date.today()+timedelta(days=1))
 for uid in [inactive,past,future]:rejected(lambda uid=uid:create(ID_ResponsableFk=uid),'Nouvelle affectation de compte inactif ou emploi hors date refusée')
 q('UPDATE systeme."T_Utilisateurs" SET "ValideUser"=false WHERE "IdUser"=%s',[employee]);update(pk,Observations='Affectation ancienne conservée')
 check(view(pk)['ID_ResponsableFk']==employee,'Responsable devenu inactif reste conservé sur les anciennes affectations')
 rejected(lambda:q('UPDATE systeme."T_Utilisateurs" SET "IdEntiteFk"=%s WHERE "IdUser"=%s',[eb,employee]),'Entreprise du responsable lié immuable')
 rejected(lambda:q('UPDATE systeme."T_Entite_Localisation" SET "IdEntiteFk"=%s WHERE "IdEntiteLocalisation"=%s',[eb,la]),'Propriétaire du lieu lié immuable')
 rejected(lambda:q('DELETE FROM systeme."T_Entite_Localisation" WHERE "IdEntiteLocalisation"=%s',[la]),'Lieu lié conservé par sa clé étrangère RESTRICT')
 archived=update(pk,Actif=False)
 rejected(lambda:q('UPDATE systeme."T_Utilisateurs" SET "IdEntiteFk"=%s WHERE "IdUser"=%s',[eb,employee]),'Bien archivé conserve aussi le rattachement du responsable')
 check(view(pk)['Actif'] is False,'Archivage ne supprime pas la fiche de consultation')
 update(pk,Actif=True)
 operations=[r['Operation'] for r in q('SELECT "Operation" FROM systeme."T_Audit_Log" WHERE "TableName"=%s AND "NewData"->>\'ID_Immobilisation\'=%s ORDER BY "IdLog"',['logistique.T_Immobilisation',str(pk)])]
 check(operations==['CREATE','UPDATE','UPDATE','ARCHIVE','RESTORE'],'Une seule écriture d’audit par création/modification/archivage/restauration')
 history=one('SELECT "OldData","NewData" FROM systeme."T_Audit_Log" WHERE "TableName"=%s AND "Operation"=%s AND "NewData"->>\'ID_Immobilisation\'=%s',['logistique.T_Immobilisation','ARCHIVE',str(pk)])
 check(history['OldData']['ID_ResponsableFk']==employee and history['NewData']['_actor']['IdUser']==actor,'Audit conserve anciennes affectations et auteur prouvé')
 matricule='MAT-'+tag
 user(ea,'Matricule A',MatriculeUser=matricule)
 user(eb,'Matricule B',MatriculeUser=matricule.lower())
 check(True,'Même matricule possible dans deux entreprises distinctes')
 rejected(lambda:user(ea,'Doublon matricule',MatriculeUser=matricule.lower()),'Matricule unique sans distinction de casse par entreprise')
 for body in [{'MatriculeUser':' x '},{'MatriculeUser':'x'*51},{'ID_ServiceFk':currency},{'ID_FonctionFk':currency},{'DateEmbauche':date(2026,2,2),'DateFinEmploi':date(2026,1,1)},{'ObservationProfessionnelle':'x'*1001}]:rejected(lambda body=body:user(ea,'RH invalide',**body),'Métadonnée RH invalide refusée : '+str(len(checks)))
 check(not one('SELECT "EstAffectable" ok FROM systeme."V_User_Affectation" WHERE "IdUser"=%s',[past])['ok'],'Vue RH distingue un emploi terminé')
 request={'requestId':str(uuid.uuid4()),'payloadHash':'a'*64,'operation':'CREATE','motif':'Recette privée'}
 context(request=request);proof_asset=create()
 rejected(lambda:create(),'Même UUID SQL ne crée pas un deuxième bien ni une deuxième preuve')
 proof_count=one('SELECT count(*) n FROM systeme."T_Audit_Log" WHERE "TableName"=%s AND "NewData"->>\'requestId\'=%s',['logistique.T_Immobilisation',request['requestId']])['n']
 check(proof_count==1,'Unicité de preuve UUID par auteur et entreprise')
 context(request={**request,'requestId':str(uuid.uuid4()),'operation':'UPDATE'});rejected(lambda:create(),'Opération du contexte ne peut pas contredire l’écriture réelle')
 context(request={**request,'requestId':'invalide'});rejected(lambda:create(),'UUID invalide refusé en SQL')
 context(request={**request,'requestId':str(uuid.uuid4()),'payloadHash':'fake'});rejected(lambda:create(),'Empreinte invalide refusée en SQL')
 context(None);rejected(lambda:create(),'Auteur absent ou non prouvé refusé en SQL')
 context(inactive);rejected(lambda:create(),'Auteur inactif refusé en SQL')
 context()
 # Le changement de correspondance d'entreprise s'applique à SQL et aux listes.
 q('INSERT INTO systeme."T_Fk_Correspondance"("ModuleName","SchemaName","ViewName","SourceKey","FieldName","FieldLabel","MappingType","ReferenceSchemaName","ReferenceObjectName","ReferenceFieldName","TargetCategoryIdFk","MappingValue","SettingScope","ScopeValue") VALUES(%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)',
  ['logistique','logistique','V_Immobilisation','logistique.immobilisations.categories','ID_CategorieFk','Type choisi','generic_category','referentiel','T_Generique','ID_Generique',category('Service'),str(category('Service')),'entity',str(ea)])
 custom=create(ID_CategorieFk=service)
 check(custom['ID_CategorieFk']==service,'Correspondance d’entreprise prioritaire dynamique sans identifiant figé')
 rejected(lambda:create(),'Famille globale remplacée refusée pour les nouvelles affectations locales')
 update(pk,Observations='Ancienne catégorie conservée après réglage')
 check(view(pk)['ID_CategorieFk']==typ,'Changer le réglage ne réécrit pas les références historiques inchangées')
 # Concurrence de création : une preuve et un seul bien gagnants.
 concurrent_request={'requestId':str(uuid.uuid4()),'payloadHash':'b'*64,'operation':'CREATE','motif':'Concurrence privée'}
 barrier=threading.Barrier(2)
 def concurrent_create():
  try:
   with psycopg.connect(DSN) as worker:
    worker.execute("SELECT set_config('systeme.actor_user_id',%s,true)",[str(actor)])
    worker.execute("SELECT set_config('logistique.immobilisation_request',%s,true)",[json.dumps(concurrent_request)])
    barrier.wait(timeout=10)
    worker.execute('INSERT INTO logistique."T_Immobilisation"("IdEntiteFk","NomImmobilisation","ID_CategorieFk") VALUES(%s,%s,%s)',[ea,'Concurrence '+tag,service])
   return 'ok'
  except psycopg.errors.UniqueViolation:return 'duplicate'
 with ThreadPoolExecutor(max_workers=2) as pool:outcomes=list(pool.map(lambda _:concurrent_create(),range(2)))
 check(sorted(outcomes)==['duplicate','ok'],'Deux créations concurrentes de même UUID produisent un seul gagnant SQL')
 check(one('SELECT count(*) n FROM logistique."T_Immobilisation" WHERE "NomImmobilisation"=%s',['Concurrence '+tag])['n']==1,'Transaction perdante ne laisse aucun bien orphelin')
 # Le verrou du responsable sérialise transfert et affectation.
 movable=user(ea,'Responsable concurrent');held=threading.Event();release=threading.Event()
 def hold_asset():
  with psycopg.connect(DSN) as worker:
   worker.execute("SELECT set_config('systeme.actor_user_id',%s,true)",[str(actor)])
   worker.execute('INSERT INTO logistique."T_Immobilisation"("IdEntiteFk","NomImmobilisation","ID_CategorieFk","ID_ResponsableFk") VALUES(%s,%s,%s,%s)',[ea,'Affectation concurrente '+tag,service,movable])
   held.set();release.wait(timeout=10)
  return 'asset'
 def transfer_user():
  held.wait(timeout=10)
  try:
   with psycopg.connect(DSN) as worker:worker.execute('UPDATE systeme."T_Utilisateurs" SET "IdEntiteFk"=%s WHERE "IdUser"=%s',[eb,movable])
   return 'moved'
  except psycopg.errors.CheckViolation:return 'blocked'
 with ThreadPoolExecutor(max_workers=2) as pool:
  first=pool.submit(hold_asset);second=pool.submit(transfer_user);held.wait(timeout=10);time.sleep(.2);release.set();outcomes=[first.result(timeout=15),second.result(timeout=15)]
 check(outcomes==['asset','blocked'],'Transfert concurrent du responsable refusé après l’affectation engagée')
 check(one('SELECT "IdEntiteFk" entity FROM systeme."T_Utilisateurs" WHERE "IdUser"=%s',[movable])['entity']==ea,'Aucune affectation croisée après concurrence')
 check(all(fingerprint('logistique',table)==value for table,value in unchanged.items()),'Tout le patrimoine reste sans effet sur articles, bons, stocks, lots, finance et CUMP')
 check(one("SELECT count(*) n FROM pg_attribute WHERE attrelid='logistique.\"T_Immobilisation\"'::regclass AND attnum>0 AND NOT attisdropped AND col_description(attrelid,attnum) IS NULL")['n']==0,'Toutes les colonnes de patrimoine documentées')
 check(one("SELECT count(*) n FROM pg_constraint WHERE conrelid='logistique.\"T_Immobilisation\"'::regclass AND obj_description(oid,'pg_constraint') IS NULL")['n']==0,'Toutes les contraintes de patrimoine, y compris NOT NULL et FK, documentées')
 for name in ['logistique.V_Immobilisation','systeme.V_User_Affectation']:
  schema,table=name.split('.')
  check(one('SELECT count(*) n FROM pg_attribute WHERE attrelid=to_regclass(%s) AND attnum>0 AND NOT attisdropped AND col_description(attrelid,attnum) IS NULL',[schema+'."'+table+'"'])['n']==0,'Vue et colonnes documentées '+name)
 check(one("SELECT count(*) n FROM pg_index WHERE indrelid='logistique.\"T_Immobilisation\"'::regclass AND obj_description(indexrelid,'pg_class') IS NULL")['n']==0,'Tous les index du patrimoine, y compris les index implicites, commentés')
 check(one("SELECT obj_description('logistique.\"T_Immobilisation_ID_Immobilisation_seq\"'::regclass,'pg_class') description")['description'] is not None,'Séquence technique documentée')
 # Recette explicite d'installation/reset sur cette seule base fictive.
 q((ROOT/'SQL/1. Schema systeme/Systeme_FK_Correspondance_Seed_Defaults.sql').read_text(encoding='utf8'))
 check(one('SELECT count(*) n FROM systeme."T_Fk_Correspondance" WHERE "SourceKey" LIKE %s AND "SettingScope"=%s',['logistique.immobilisations.%','global'])['n']==3,'Seed d’installation conserve trois correspondances patrimoine avec catégories dynamiques')
 context(global_actor);seed_asset=create(IdEntiteFk=eb,ID_CategorieFk=typ)
 check(seed_asset['ID_CategorieFk']==typ,'Patrimoine utilisable après initialisation standard des correspondances')
 check(all(fingerprint('logistique',table)==value for table,value in unchanged.items()),'Réinitialisation privée des correspondances sans effet sur stock et finance')
 result={'checks':len(checks),'details':checks,'database':target.path[1:],'migrationSHA256':hashlib.sha256(source.read_bytes()).hexdigest(),'productionWrites':False,'existingBusinessRowsPreserved':True,'profileCataloguePolicyUpdated':True,'commercialStockFinanceUnchanged':True,'concurrencyCases':2,'installationMappingSeedVerified':True}
 output=ROOT/'.runtime/immobilisations08/verification.json';output.parent.mkdir(exist_ok=True);output.write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf8')
 print(json.dumps(result,ensure_ascii=False))
