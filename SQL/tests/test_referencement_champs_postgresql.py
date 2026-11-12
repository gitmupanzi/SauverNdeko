"""Catalogue09 et références réelles : socle08 fictif, URL privée explicite.

Le script applique09 lui-même, préserve les anciennes lignes/contraintes et
exerce les changements de catégories sans désactiver un trigger métier.
"""
import hashlib,json,os,threading,time,uuid
from concurrent.futures import ThreadPoolExecutor
from decimal import Decimal
from pathlib import Path
from urllib.parse import urlsplit

import psycopg
from psycopg import sql
from psycopg.rows import dict_row

ROOT=Path(__file__).resolve().parents[2]
DSN=os.environ.get('SAUVERNDEKO_TEST_DATABASE_URL','');target=urlsplit(DSN)
if target.hostname not in {'localhost','127.0.0.1'} or not target.path[1:].startswith('sauverndeko_test_'):raise RuntimeError('URL PostgreSQL locale de recette explicite obligatoire')
checks=[];tag=uuid.uuid4().hex[:12]
def check(condition,label):assert condition,label;checks.append(label)
with psycopg.connect(DSN,autocommit=True,row_factory=dict_row) as c:
 def q(statement,params=None):return c.execute(statement,params)
 def one(statement,params=None):return q(statement,params).fetchone()
 def reject(callback,label):
  try:
   with c.transaction():callback()
  except psycopg.Error as error:
   assert error.sqlstate not in {'42601','42703','42P01','42883'},(label,str(error));check(True,label)
  else:raise AssertionError(label)
 def table_rows(schema,table):return [r['data'] for r in q(sql.SQL('SELECT to_jsonb(t) data FROM {}.{} t ORDER BY to_jsonb(t)::text').format(sql.Identifier(schema),sql.Identifier(table)))]
 def fingerprint(schema,table):return hashlib.sha256(json.dumps(table_rows(schema,table),sort_keys=True,default=str).encode()).hexdigest()
 def category(label):return one('SELECT "ID_CategorieGenerique" id FROM referentiel."T_CategorieGenerique" WHERE "NomCategorieGenerique"=%s',[label])['id']
 def value(label):return one('SELECT "ID_Generique" id FROM referentiel."T_Generique" WHERE "ID_CategorieGeneriqueFk"=%s AND "ValideGenerique" ORDER BY "ID_Generique" LIMIT 1',[category(label)])['id']
 def add_value(cat,label,code=None):return one('INSERT INTO referentiel."T_Generique"("ID_CategorieGeneriqueFk","NomGenerique","AbrGenerique") VALUES(%s,%s,%s) RETURNING "ID_Generique" id',[cat,label,code or label])['id']
 def add_category(label):return one('INSERT INTO referentiel."T_CategorieGenerique"("NomCategorieGenerique") VALUES(%s) RETURNING "ID_CategorieGenerique" id',[label])['id']
 check(one('SELECT current_database() name')['name']==target.path[1:],'Connexion privée réellement vérifiée')
 if one('SELECT to_regclass(%s) t',['referentiel."T_ChampReferentiel"'])['t'] is not None:raise RuntimeError('Socle08 requis avant migration09')
 # Problème historique reproduit uniquement dans une donnée fictive de recette.
 wrong_geo=value('Indicateurs démographiques')
 geo=one('INSERT INTO geolocalisation."T_Niveau_4"("NomNiveau_4","ID_StatutDeploiementFk") VALUES(%s,%s) RETURNING "ID_Niveau_4" id',['Géographie fictive '+tag,wrong_geo])['id']
 tables=q("SELECT n.nspname s,t.relname t FROM pg_class t JOIN pg_namespace n ON n.oid=t.relnamespace WHERE t.relkind='r' AND n.nspname=ANY(%s) ORDER BY 1,2",[['analytics','communication','geolocalisation','logistique','operations','professionnel','referentiel','systeme']]).fetchall()
 before={(r['s'],r['t']):table_rows(r['s'],r['t']) for r in tables}
 foreign_keys=q("SELECT conrelid::regclass::text table_name,conname,pg_get_constraintdef(oid,true) def FROM pg_constraint WHERE contype='f' AND confrelid='referentiel.\"T_Generique\"'::regclass ORDER BY 1,2").fetchall()
 source=ROOT/'backend/database/migrations/20261028_09_referencement_champs.sql'
 q(source.read_text(encoding='utf8'))
 for key,old in before.items():
  actual=table_rows(*key)
  if key==('systeme','T_Fk_Correspondance'):
   check([{k:v for k,v in r.items() if k!='IdChampReferentielFk'} for r in actual]==old and all(r['IdChampReferentielFk'] is None for r in actual),'Tous les réglages historiques conservés avec la nouvelle relation NULL')
  elif key==('referentiel','T_InterfaceTableau'):
   check([r for r in actual if r['CleInterface']!='referentiels.champs']==old and len(actual)==len(old)+1,'Un seul catalogue ajouté sans modifier les autres catalogues ni préférences')
  else:check(actual==old,'Migration sans changement des anciennes lignes : '+'.'.join(key))
 check(q("SELECT conrelid::regclass::text table_name,conname,pg_get_constraintdef(oid,true) def FROM pg_constraint WHERE contype='f' AND confrelid='referentiel.\"T_Generique\"'::regclass ORDER BY 1,2").fetchall()==foreign_keys,'Les60 clés étrangères physiques ne sont ni supprimées ni recréées')
 fields=q('SELECT * FROM referentiel."V_ReferencementChamp" ORDER BY "SchemaName","TableName","ColumnName"').fetchall()
 check(len(fields)==60 and len({(x['SchemaName'],x['TableName'],x['ColumnName']) for x in fields})==60,'60 champs physiques distincts dans une vue unique')
 check(sum(x['DefaultCategoryId'] is None for x in fields)==3,'Trois familles non prouvées restent explicitement inconnues')
 check(all(x['CategoryIds'] is not None and x['CategoryLabels'] is not None for x in fields),'Listes SQL typées non NULL, y compris pour un champ non configuré')
 check(sum(not x['CanConfigure'] for x in fields)==2 and all(x['DefaultCategoryId']==category('Role') for x in fields if not x['CanConfigure']),'Les deux références de rôle de sécurité restent protégées')
 check(sum(x['SupportsEntityScope'] for x in fields)==37 and sum(not x['SupportsEntityScope'] for x in fields)==23,'Matrice prouvée :37 champs avec entreprise durable et23 champs partagés globaux')
 check(all(not x['SupportsEntityScope'] for x in fields if x['SchemaName']=='geolocalisation' or (x['SchemaName'],x['TableName']) in [('analytics','T_Recherche'),('professionnel','T_Professionnel'),('logistique','T_PrecisionStock')]),'Géographie, recherche, professionnel partagé et précision ne déduisent pas une propriété de leur utilisateur')
 cat=one('SELECT "Colonnes" cols FROM referentiel."T_InterfaceTableau" WHERE "CleInterface"=%s',['referentiels.champs'])['cols']
 check([x['id'] for x in sorted(cat,key=lambda x:x['defaultOrder']) if x['defaultVisible']]==['SchemaName','TableName','ColumnName','CategoryIds','CategoryLabels','DefaultCategoryId','actions'],'Sept colonnes et ordre par défaut demandés par le propriétaire')
 check(all(x['ReferenceHeriteeParent'] for x in fields if x['TableName']=='T_Mouvement'),'Références dérivées de mouvement signalées dans le catalogue')
 def field(table,column,schema='logistique'):return one('SELECT * FROM referentiel."V_ReferencementChamp" WHERE "SchemaName"=%s AND "TableName"=%s AND "ColumnName"=%s',[schema,table,column])
 def resolved(table,column,entity=None,schema='logistique'):return one('SELECT referentiel.fn_categories_champ(%s,%s,%s,%s) ids',[schema,table,column,entity])['ids']
 def configure(f,categories,scope='global',scope_value=None,restore=False,**changes):
  with c.transaction():
   q('SELECT 1 FROM referentiel."T_ChampReferentiel" WHERE "ID_ChampReferentiel"=%s FOR UPDATE',[f['ID_ChampReferentiel']])
   q('DELETE FROM systeme."T_Fk_Correspondance" WHERE "IdChampReferentielFk"=%s AND "SettingScope"=%s AND "ScopeValue" IS NOT DISTINCT FROM %s',[f['ID_ChampReferentiel'],scope,str(scope_value) if scope_value is not None else None])
   for order,current in enumerate([None] if restore else categories):
    body={'IdChampReferentielFk':f['ID_ChampReferentiel'],'ModuleName':f['ModuleName'],'SchemaName':f['SchemaName'],'SourceKey':'champ.'+str(f['ID_ChampReferentiel']),'FieldName':f['ColumnName'],'FieldLabel':f['ChampLabel'],'MappingType':'generic_category','ReferenceSchemaName':'referentiel','ReferenceObjectName':'T_Generique','ReferenceFieldName':'ID_Generique','TargetCategoryIdFk':current,'MappingValue':'@default' if restore else str(current),'IsDefaultMapping':restore,'SettingScope':scope,'ScopeValue':str(scope_value) if scope_value is not None else None,'DisplayOrder':order,**changes}
    q(sql.SQL('INSERT INTO systeme."T_Fk_Correspondance"({}) VALUES({})').format(sql.SQL(',').join(map(sql.Identifier,body)),sql.SQL(',').join(sql.Placeholder() for _ in body)),list(body.values()))
 def entity(label):return one('INSERT INTO systeme."T_Entite"("NomEntite","EmailEntite") VALUES(%s,%s) RETURNING "IdEntite" id',[label+tag,uuid.uuid4().hex+'@example.invalid'])['id']
 ea,eb=entity('Référence A '),entity('Référence B ')
 actor=one('INSERT INTO systeme."T_Utilisateurs"("NomUser","PrenomUser","EmailUser","MotdepasseUser","SexeUser","IdEntiteFk","Is_Admin") VALUES(%s,%s,%s,%s,%s,%s,true) RETURNING "IdUser" id',['Recette','Fictive',tag+'@example.invalid','empreinte-fictive-inutilisable','M',ea])['id']
 q("SELECT set_config('systeme.actor_user_id',%s,false)",[str(actor)])
 original=category('Type produit');alternate=category('Type de matériel');third=category('Catégorie produit')
 from psycopg.types.json import Jsonb
 def owner(schema,table,data):return one('SELECT referentiel.fn_entite_reference_champ(%s,%s,%s) id',[schema,table,Jsonb(data)])['id']
 check(owner('systeme','T_Entite',{'IdEntite':ea})==ea and owner('logistique','T_Article',{'IdEntiteFk':ea})==ea,'Résolveur de propriétaire : PK Entité et FK durable explicites')
 check(all(owner(x['SchemaName'],x['TableName'],{'IdEntiteFk':ea,'IdUserFk':actor,'IdEntiteResultFk':eb}) is None for x in fields if not x['SupportsEntityScope']),'Les23 champs partagés restent globaux même avec un utilisateur ou résultat de recherche d’entreprise')
 entity_field=field('T_Entite','IdTypeEntiteFk','systeme')
 configure(entity_field,[alternate],scope='entity',scope_value=ea)
 q('UPDATE systeme."T_Entite" SET "IdTypeEntiteFk"=%s WHERE "IdEntite"=%s',[value('Type de matériel'),ea])
 check(True,'Écriture directe T_Entite applique sa propre PK comme contexte de catégorie')
 reject(lambda:q('UPDATE systeme."T_Entite" SET "IdTypeEntiteFk"=%s WHERE "IdEntite"=%s',[value('Type de matériel'),eb]),'Une autre Entité ne reçoit pas la surcharge de catégorie de sa voisine')
 configure(entity_field,[],scope='entity',scope_value=ea,restore=True)
 q('UPDATE systeme."T_Entite" SET "NomEntite"="NomEntite"||%s WHERE "IdEntite"=%s',[' renommée',ea])
 check(True,'Une Entité conserve sa référence historique lors d’une modification descriptive après restauration')
 shared=field('T_Niveau_4','ID_StatutDeploiementFk','geolocalisation')
 reject(lambda:configure(shared,[alternate],scope='entity',scope_value=ea),'Nouvelle surcharge entreprise refusée en SQL pour un champ géographique partagé')
 q('INSERT INTO systeme."T_Fk_Correspondance"("ModuleName","SchemaName","SourceKey","FieldName","MappingType","TargetCategoryIdFk","MappingValue","SettingScope","ScopeValue") VALUES(%s,%s,%s,%s,%s,%s,%s,%s,%s)',['admin','geolocalisation','deploymentStatuses','ID_StatutDeploiementFk','generic_category',alternate,str(alternate),'entity',str(ea)])
 check(resolved('T_Niveau_4','ID_StatutDeploiementFk',ea,'geolocalisation')==resolved('T_Niveau_4','ID_StatutDeploiementFk',None,'geolocalisation') and one('SELECT count(*) n FROM systeme."T_Fk_Correspondance" WHERE "SourceKey"=%s AND "SettingScope"=%s AND "ScopeValue"=%s',['deploymentStatuses','entity',str(ea)])['n']==1,'Ancienne surcharge géographique conservée physiquement mais jamais appliquée comme propriété fictive')
 f=field('T_Article','ID_TypeArticleFk')
 check(resolved('T_Article','ID_TypeArticleFk',ea)==[original],'Famille historique globale résolue avant toute surcharge canonique')
 revision=f['Revision'];configure(f,[alternate]);f=field('T_Article','ID_TypeArticleFk')
 check(resolved('T_Article','ID_TypeArticleFk',ea)==[alternate] and f['Revision']>revision,'Nouvelle famille globale et révision réelle persistées')
 q('INSERT INTO systeme."T_Fk_Correspondance"("ModuleName","SchemaName","SourceKey","FieldName","MappingType","TargetCategoryIdFk","MappingValue","SettingScope","ScopeValue") VALUES(%s,%s,%s,%s,%s,%s,%s,%s,%s)',['logistique','logistique','logistique.articleTypes','ID_TypeArticleFk','generic_category',third,str(third),'entity',str(ea)])
 check(resolved('T_Article','ID_TypeArticleFk',ea)==[third] and resolved('T_Article','ID_TypeArticleFk',eb)==[alternate],'Alias entreprise prioritaire sur global, sans contaminer une autre entreprise')
 configure(f,[],scope='entity',scope_value=ea,restore=True)
 check(resolved('T_Article','ID_TypeArticleFk',ea)==[original] and resolved('T_Article','ID_TypeArticleFk',eb)==[alternate],'Rétablir persiste le défaut au scope choisi sans retomber sur alias entreprise ou global personnalisé')
 unknown=field('T_Professionnel','IdTypeProfessionnelFk','professionnel')
 configure(unknown,[alternate]);check(resolved('T_Professionnel','IdTypeProfessionnelFk',schema='professionnel')==[alternate],'Un champ sans défaut prouvé peut recevoir une configuration explicite')
 configure(unknown,[],restore=True);check(resolved('T_Professionnel','IdTypeProfessionnelFk',schema='professionnel')==[],'Restauration sans défaut revient à non configuré sans famille inventée')
 configure(f,[alternate,third],scope='entity',scope_value=eb)
 check(resolved('T_Article','ID_TypeArticleFk',eb)==sorted([alternate,third]),'Ancien jeu multicatégorie représentable sans perte ni CSV')
 role=field('T_Utilisateurs','IdRoleFk','systeme')
 reject(lambda:configure(role,[alternate]),'Famille des rôles non reconfigurable en SQL direct')
 reject(lambda:q('UPDATE systeme."T_Fk_Correspondance" SET "TargetCategoryIdFk"=%s,"MappingValue"=%s WHERE "SourceKey"=%s AND "SettingScope"=%s',[alternate,str(alternate),'roles','global']),'Un alias ancien ne permet pas de contourner la famille de sécurité')
 for column,new in [('SchemaName','autre'),('TableName','T_Article'),('ColumnName','autre'),('ID_CategorieDefautFk',alternate),('CanConfigure',False),('SupportsEntityScope',False),('Revision',999)]:
  reject(lambda column=column,new=new:q(sql.SQL('UPDATE referentiel."T_ChampReferentiel" SET {}=%s WHERE "ID_ChampReferentiel"=%s').format(sql.Identifier(column)),[new,f['ID_ChampReferentiel']]),'Métadonnée de référence immuable : '+column)
 reject(lambda:q('DELETE FROM referentiel."T_ChampReferentiel" WHERE "ID_ChampReferentiel"=%s',[f['ID_ChampReferentiel']]),'Catalogue non supprimable par écriture ordinaire')
 reject(lambda:q('INSERT INTO referentiel."T_ChampReferentiel"("SchemaName","TableName","ColumnName","ChampLabel","ModuleName") VALUES(%s,%s,%s,%s,%s)',['logistique','T_Article','NomArticle','Texte','logistique']),'Une colonne sans vraie FK ne peut pas être ajoutée au catalogue')
 for changes in [{'FieldName':'nom_faux'},{'SchemaName':'systeme'},{'ModuleName':'admin'},{'ViewName':'V_Article'},{'SourceKey':'faux'},{'ReferenceObjectName':'T_Entite'},{'TargetCategoryIdFk':third},{'DisplayOrder':-1}]:
  reject(lambda changes=changes:configure(f,[alternate],**changes),'Correspondance canonique physiquement incohérente refusée : '+next(iter(changes)))
 reject(lambda:configure(f,[alternate],scope='country',scope_value=1),'Scope pays non activé implicitement')
 reject(lambda:configure(f,[alternate],scope='entity',scope_value=2147483647),'Entreprise de réglage inexistante refusée')
 reject(lambda:configure(f,[alternate,alternate]),'Catégorie dupliquée refusée dans un jeu')
 q('UPDATE geolocalisation."T_Niveau_4" SET "NomNiveau_4"=%s WHERE "ID_Niveau_4"=%s',['Libellé fictif modifié '+tag,geo])
 check(one('SELECT "ID_StatutDeploiementFk" v FROM geolocalisation."T_Niveau_4" WHERE "ID_Niveau_4"=%s',[geo])['v']==wrong_geo,'Valeur géographique historique hors famille conservée lors d’une modification descriptive')
 reject(lambda:q('INSERT INTO geolocalisation."T_Niveau_4"("NomNiveau_4","ID_StatutDeploiementFk") VALUES(%s,%s)',['Nouvelle géographie',wrong_geo]),'Nouvelle affectation géographique hors famille refusée')
 good_geo=value('Status Deploiement')
 q('UPDATE geolocalisation."T_Niveau_4" SET "ID_StatutDeploiementFk"=%s WHERE "ID_Niveau_4"=%s',[good_geo,geo]);check(True,'Correction explicite de la vieille référence possible vers la bonne famille')
 # La visibilité historique ne masque pas une valeur active de la bonne famille.
 good_type=value('Type produit');check(one('SELECT referentiel.fn_valider_reference_champ(%s,%s,%s,%s,%s) ok',['logistique','T_Article','ID_TypeArticleFk',good_type,ea])['ok'],'Valeur active acceptée sans globaliser VisibleArticle ou VisibleAll')
 q('UPDATE referentiel."T_Generique" SET "ValideGenerique"=false WHERE "ID_Generique"=%s',[good_type])
 check(not one('SELECT referentiel.fn_valider_reference_champ(%s,%s,%s,%s,%s) ok',['logistique','T_Article','ID_TypeArticleFk',good_type,ea])['ok'],'Nouvelle valeur inactive refusée par la fonction de validation commune')
 q('UPDATE referentiel."T_Generique" SET "ValideGenerique"=true WHERE "ID_Generique"=%s',[good_type])
 # Affectations de biens suivent exactement le même résolveur que les listes.
 f_immo=field('T_Immobilisation','ID_CategorieFk');configure(f_immo,[third],scope='entity',scope_value=ea)
 stock_tables=['T_Article','T_Commande','T_CommandeDetail','T_Mouvement','T_LotArticle','T_MouvementLot','T_ValorisationEvenement','T_Facture','T_Reglements']
 stock_before={name:fingerprint('logistique',name) for name in stock_tables}
 asset=one('INSERT INTO logistique."T_Immobilisation"("IdEntiteFk","NomImmobilisation","ID_CategorieFk") VALUES(%s,%s,%s) RETURNING "ID_Immobilisation" id',[ea,'Bien de recette '+tag,value('Catégorie produit')])['id']
 reject(lambda:q('INSERT INTO logistique."T_Immobilisation"("IdEntiteFk","NomImmobilisation","ID_CategorieFk") VALUES(%s,%s,%s)',[ea,'Famille antérieure refusée',value('Type de matériel')]),'Garde patrimoine liée à la même catégorie entreprise que la nouvelle liste')
 configure(f_immo,[],scope='entity',scope_value=ea,restore=True)
 q('UPDATE logistique."T_Immobilisation" SET "Observations"=%s WHERE "ID_Immobilisation"=%s',['Historique conservé',asset]);check(True,'Bien existant éditable descriptivement après restauration de son ancienne famille')
 check(all(fingerprint('logistique',name)==h for name,h in stock_before.items()),'Réglages et patrimoine sans effet sur stock, mouvements, lots, CUMP, factures ou paiements')
 usd_before=one('SELECT logistique.fn_devise_usd() id')['id']
 q('UPDATE referentiel."T_CategorieGenerique" SET "NomCategorieGenerique"=%s WHERE "ID_CategorieGenerique"=%s',['Devises renommées '+tag,category('Devise')])
 check(one('SELECT logistique.fn_devise_usd() id')['id']==usd_before,'Renommer la catégorie de devise ne casse pas le défautUSD lié à son identifiant de référence')
 q('UPDATE referentiel."T_CategorieGenerique" SET "NomCategorieGenerique"=%s WHERE "NomCategorieGenerique"=%s',['Devise','Devises renommées '+tag])
 # Une famille de types de bon reconfigurée doit marcher jusqu'aux mouvements,
 # puis rester interprétable lorsque le choix proposé est rétabli.
 family_bons=add_category('Types privés de recette '+tag)
 entry_type=add_value(family_bons,'Entrée privée '+tag,'Entrée')
 exit_type=add_value(family_bons,'Sortie privée '+tag,'Sortie')
 order_type=add_value(family_bons,'Commande privée '+tag,'CMD')
 f_bon=field('T_Commande','ID_TypeCmdFk');configure(f_bon,[family_bons],scope='entity',scope_value=ea)
 currency=one('SELECT "ID_Generique" id FROM referentiel."T_Generique" WHERE "ID_CategorieGeneriqueFk"=%s AND "AbrGenerique"=%s',[category('Devise'),'USD'])['id']
 unit=one('SELECT "ID_Generique" id FROM referentiel."T_Generique" WHERE "ID_CategorieGeneriqueFk"=%s AND "AbrGenerique"=%s',[category('Unités'),'pcs'])['id']
 article=one('INSERT INTO logistique."T_Article"("NomArticle","ID_TypeArticleFk","ID_CategorieArticleFk","ID_UniteFk","ID_DeviseFk","QteArticle","PUArticle","PVArticle","ID_UserFK","IdEntiteFk") VALUES(%s,%s,%s,%s,%s,5,10,15,%s,%s) RETURNING "ID_Article" id',['Article physique fictif '+tag,good_type,value('Catégorie produit'),unit,currency,actor,ea])['id']
 check(one('SELECT "QteArticle" q FROM logistique."T_Article" WHERE "ID_Article"=%s',[article])['q']==5,'Stock initial exact après changement de la famille des types de bon')
 initial=one('SELECT c."ID_TypeCmdFk" kind,c."CodeCmd" code FROM logistique."T_Commande" c JOIN logistique."T_CommandeDetail" d ON d."ID_CmdFk"=c."ID_Commande" WHERE d."ID_ArticleFk"=%s',[article])
 check(initial['kind']==entry_type and initial['code'].startswith('BE-'),'Bon initial prérempli dans la catégorie courante de son entreprise et codeBE')
 def stock_bon(kind,qty):
  with c.transaction():
   pk=one('INSERT INTO logistique."T_Commande"("ID_TypeCmdFk","ID_UserFk","IdEntiteFk","ID_DeviseFk","DateCmd") VALUES(%s,%s,%s,%s,clock_timestamp()) RETURNING "ID_Commande" id',[kind,actor,ea,currency])['id']
   q('INSERT INTO logistique."T_CommandeDetail"("ID_CmdFk","ID_ArticleFk","QteCmdDetail","PUCmdDetail") VALUES(%s,%s,%s,15)',[pk,article,qty])
  return pk
 sortie=stock_bon(exit_type,2)
 check(one('SELECT "QteArticle" q FROM logistique."T_Article" WHERE "ID_Article"=%s',[article])['q']==3,'Une sortie de nouvelle famille produit exactement la baisse attendue')
 check(one('SELECT count(*) n FROM logistique."T_Mouvement" WHERE "ID_cmdFk"=%s AND "ID_TypeMvtFk"=%s',[sortie,exit_type])['n']==1,'La copie du type réel dans le mouvement suit le parent sans deuxième configuration artificielle')
 check(owner('logistique','T_Mouvement',{'ID_cmdFk':sortie,'ID_ArticleFk':article})==ea,'Entreprise du mouvement lue dans son parent durable, sans déduction par utilisateur')
 cmd=stock_bon(order_type,2)
 check(one('SELECT count(*) n FROM logistique."T_Mouvement" WHERE "ID_cmdFk"=%s',[cmd])['n']==0 and one('SELECT "QteArticle" q FROM logistique."T_Article" WHERE "ID_Article"=%s',[article])['q']==3,'CMD de famille courante reste neutre sans mouvement ni changement de stock')
 check(one('SELECT "MontantTTC" total FROM logistique."V_Commande" WHERE "ID_Commande"=%s',[cmd])['total']==30,'Quantités et total de commande neutre restent calculés exactement')
 configure(f_bon,[],scope='entity',scope_value=ea,restore=True)
 check(one('SELECT logistique.fn_nature_bon(%s) s,logistique.fn_nature_bon(%s) e,logistique.fn_nature_bon(%s) c',[exit_type,entry_type,order_type])=={'s':'sortie','e':'entree','c':'commande'},'Rétablir la famille ne requalifie pas les types déjà utilisés enBE/BS/CMD')
 q('UPDATE logistique."T_Commande" SET "RefCmd"=%s WHERE "ID_Commande"=%s',['Référence descriptive '+tag,sortie]);check(True,'Bon historique éditable sans changer sa nature après restauration du réglage')
 reject(lambda:stock_bon(exit_type,1),'Nouvelle sortie hors famille courante refusée même si son type est historique')
 reject(lambda:q('UPDATE referentiel."T_Generique" SET "AbrGenerique"=%s WHERE "ID_Generique"=%s',['Entrée',exit_type]),'Code de sens physique utilisé reste protégé dans une nouvelle famille')
 reject(lambda:q('UPDATE referentiel."T_Generique" SET "ID_CategorieGeneriqueFk"=%s WHERE "ID_Generique"=%s',[original,exit_type]),'Famille d’un type déjà utilisé ne peut pas être déplacée')
 reject(lambda:q('DELETE FROM referentiel."T_Generique" WHERE "ID_Generique"=%s',[exit_type]),'Suppression en cascade d’une référence utilisée refusée')
 check(one('SELECT "QteArticle" q FROM logistique."T_Article" WHERE "ID_Article"=%s',[article])['q']==3 and one('SELECT count(*) n FROM logistique."T_Mouvement" WHERE "ID_ArticleFk"=%s',[article])['n']==2,'Restauration et essais refusés ne rejouent aucun ancien mouvement')
 # Le verrou commun couvre aussi l'écriture SQL directe, pas seulement le service.
 concurrent=field('T_Utilisateurs','ID_FonctionFk','systeme');held=threading.Event();release=threading.Event();entered=threading.Event()
 def first_writer():
  with psycopg.connect(DSN) as worker:
   worker.execute('SELECT 1 FROM referentiel."T_ChampReferentiel" WHERE "ID_ChampReferentiel"=%s FOR UPDATE',[concurrent['ID_ChampReferentiel']])
   worker.execute('INSERT INTO systeme."T_Fk_Correspondance"("IdChampReferentielFk","ModuleName","SchemaName","SourceKey","FieldName","MappingType","ReferenceSchemaName","ReferenceObjectName","ReferenceFieldName","TargetCategoryIdFk","MappingValue") VALUES(%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)',[concurrent['ID_ChampReferentiel'],'systeme','systeme','champ.'+str(concurrent['ID_ChampReferentiel']),'ID_FonctionFk','generic_category','referentiel','T_Generique','ID_Generique',category('Service'),str(category('Service'))])
   held.set();release.wait(timeout=5)
  return True
 def next_reader():
  held.wait(timeout=5)
  with psycopg.connect(DSN) as worker:
   entered.set()
   return worker.execute('SELECT "Revision" FROM referentiel."T_ChampReferentiel" WHERE "ID_ChampReferentiel"=%s FOR UPDATE',[concurrent['ID_ChampReferentiel']]).fetchone()[0]
 with ThreadPoolExecutor(max_workers=2) as pool:
  first=pool.submit(first_writer);second=pool.submit(next_reader)
  assert entered.wait(timeout=5);time.sleep(0.15)
  waiting=not second.done();release.set();first.result(timeout=8);new_revision=second.result(timeout=8)
 check(waiting and new_revision>concurrent['Revision'],'Un second rédacteur attend le verrou et lit la nouvelle révision, permettant le refus de version périmée')
 # Tous les nouveaux objets portent des commentaires, y compris NOT NULL PG18.
 check(one("SELECT count(*) n FROM pg_constraint WHERE conrelid='referentiel.\"T_ChampReferentiel\"'::regclass AND obj_description(oid,'pg_constraint') IS NULL")['n']==0,'Toutes les contraintes du catalogue commentées')
 check(one("SELECT count(*) n FROM pg_attribute WHERE attrelid='referentiel.\"T_ChampReferentiel\"'::regclass AND attnum>0 AND NOT attisdropped AND col_description(attrelid,attnum) IS NULL")['n']==0,'Toutes les colonnes de catalogue commentées')
 check(one("SELECT count(*) n FROM pg_attribute WHERE attrelid='referentiel.\"V_ReferencementChamp\"'::regclass AND attnum>0 AND NOT attisdropped AND col_description(attrelid,attnum) IS NULL")['n']==0,'Toutes les projections de la vue commentées')
 check(one("SELECT count(*) n FROM pg_indexes i JOIN pg_class c ON c.relname=i.indexname JOIN pg_namespace ns ON ns.oid=c.relnamespace AND ns.nspname=i.schemaname WHERE i.schemaname='referentiel' AND i.tablename='T_ChampReferentiel' AND obj_description(c.oid,'pg_class') IS NULL")['n']==0,'Tous les index du catalogue commentés')
 reject(lambda:q(source.read_text(encoding='utf8')),'Rejeu de migration09 refusé, sans réinitialisation du catalogue')
 proof={'passed':True,'checks':len(checks),'details':checks,'database':target.path[1:],'migrationSHA256':hashlib.sha256(source.read_bytes()).hexdigest(),'sourceTouched':False}
 directory=Path(os.environ.get('SAUVERNDEKO_TEST_ARTIFACTS',str(ROOT/'.runtime/referencement09')));directory.mkdir(parents=True,exist_ok=True)
 (directory/'verification.json').write_text(json.dumps(proof,ensure_ascii=False,indent=2),encoding='utf8')
 print(json.dumps({'passed':True,'checks':len(checks),'database':target.path[1:],'migrationSHA256':proof['migrationSHA256']},ensure_ascii=True))
