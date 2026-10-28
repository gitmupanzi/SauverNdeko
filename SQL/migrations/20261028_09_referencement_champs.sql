-- Référencement canonique des champs physiques vers T_Generique, sans reprise des données métier.
BEGIN;
SET LOCAL lock_timeout='10s';
SET LOCAL statement_timeout='120s';
DO $guard$ BEGIN
 IF current_database()<>'SauverNdeko' AND current_database() NOT LIKE 'sauverndeko_test_%' THEN RAISE EXCEPTION 'Base non autorisée'; END IF;
 IF to_regclass('logistique."T_Immobilisation"') IS NULL OR to_regclass('referentiel."T_ChampReferentiel"') IS NOT NULL THEN RAISE EXCEPTION 'Socle08 requis, migration09 déjà présente ou état inattendu'; END IF;
 IF (SELECT count(*) FROM pg_constraint WHERE contype='f' AND confrelid='referentiel."T_Generique"'::regclass)<>60 THEN RAISE EXCEPTION 'Inventaire des FK inattendu : réexaminer le catalogue avant migration'; END IF;
END $guard$;
CREATE TABLE referentiel."T_ChampReferentiel"(
 "ID_ChampReferentiel" integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 "SchemaName" varchar(80) NOT NULL,"TableName" varchar(120) NOT NULL,"ColumnName" varchar(120) NOT NULL,
 "ChampLabel" varchar(255) NOT NULL,"ModuleName" varchar(80) NOT NULL,
 "ID_CategorieDefautFk" integer REFERENCES referentiel."T_CategorieGenerique"("ID_CategorieGenerique") ON DELETE RESTRICT,
 "AliasSourceKeys" text[] NOT NULL DEFAULT '{}'::text[],"CanConfigure" boolean NOT NULL DEFAULT true,
 "SupportsEntityScope" boolean NOT NULL DEFAULT false,
 "Revision" bigint NOT NULL DEFAULT 1 CHECK("Revision">0),
 "CreeLe" timestamptz NOT NULL DEFAULT clock_timestamp(),"ModifieLe" timestamptz NOT NULL DEFAULT clock_timestamp(),
 "ModifieParUserFk" integer REFERENCES systeme."T_Utilisateurs"("IdUser") ON DELETE SET NULL,
 CONSTRAINT uq_champ_referentiel_physique UNIQUE("SchemaName","TableName","ColumnName"),
 CONSTRAINT ck_champ_identifiants CHECK("SchemaName"=btrim("SchemaName") AND "TableName"=btrim("TableName") AND "ColumnName"=btrim("ColumnName") AND length("SchemaName")>0 AND length("TableName")>0 AND length("ColumnName")>0)
);
COMMENT ON TABLE referentiel."T_ChampReferentiel" IS 'Catalogue unique des colonnes physiques à FK vers T_Generique ; famille de référence immuable et alias explicites, aucun choix courant dupliqué.';
COMMENT ON SEQUENCE referentiel."T_ChampReferentiel_ID_ChampReferentiel_seq" IS 'Identités techniques du catalogue physique ; aucune relation par nom affiché ou position de ligne.';
ALTER TABLE systeme."T_Fk_Correspondance" ADD COLUMN "IdChampReferentielFk" integer REFERENCES referentiel."T_ChampReferentiel"("ID_ChampReferentiel") ON DELETE RESTRICT;
COMMENT ON COLUMN systeme."T_Fk_Correspondance"."IdChampReferentielFk" IS 'Champ physique canonique pour un jeu de catégories courant ; NULL conserve une correspondance historique ou non catégorielle.';
CREATE UNIQUE INDEX uq_fk_champ_categorie_scope ON systeme."T_Fk_Correspondance"("IdChampReferentielFk","SettingScope","ScopeValue","MappingValue") NULLS NOT DISTINCT WHERE "IdChampReferentielFk" IS NOT NULL;
COMMENT ON INDEX systeme.uq_fk_champ_categorie_scope IS 'Une occurrence par catégorie et portée dans le jeu canonique ; plusieurs catégories historiques restent représentables sans CSV.';
CREATE INDEX ix_champ_referentiel_alias ON referentiel."T_ChampReferentiel" USING gin("AliasSourceKeys");
COMMENT ON INDEX referentiel.ix_champ_referentiel_alias IS 'Résolution explicite des anciens SourceKey partagés vers leurs colonnes physiques, sans supposer que les alias sont des noms de champs.';
WITH seed(schema_name,table_name,column_name,label,module_name,family_name,aliases,configurable) AS (VALUES
('analytics','T_Recherche','IdSpecialiteFk','IdSpecialiteFk','analytics','Spécialité',ARRAY[]::text[],true),
('communication','T_Communication','IdTypeCommunication','IdTypeCommunication','communication','Type communication',ARRAY[]::text[],true),
('geolocalisation','T_Niveau_2','ID_TypeNiveau_2_Fk','Type niveau 2','geolocalisation','Type de site',ARRAY['niveau2Types']::text[],true),
('geolocalisation','T_Niveau_2','ID_StatutNiveau_2','Statut niveau 2','geolocalisation','Statut site',ARRAY['niveau2Statuses']::text[],true),
('geolocalisation','T_Niveau_2','ID_StatusDeploiFk','Statut deploiement','geolocalisation','Status Deploiement',ARRAY['deploymentStatuses']::text[],true),
('geolocalisation','T_Niveau_2','ID_VoieAccesDPSANTFk','Voie acces DPS','geolocalisation','Transport',ARRAY['dpsAccessRoutes']::text[],true),
('geolocalisation','T_Niveau_3','ID_TypeNiveau_2_Fk','Type niveau 3','geolocalisation','Type de site',ARRAY['niveau3Types']::text[],true),
('geolocalisation','T_Niveau_3','ID_StatutNiveau_3_Fk','Statut niveau 3','geolocalisation','Statut site',ARRAY['niveau3Statuses']::text[],true),
('geolocalisation','T_Niveau_3','ID_StatutDeploieFk','Statut deploiement','geolocalisation','Status Deploiement',ARRAY['deploymentStatuses']::text[],true),
('geolocalisation','T_Niveau_3','ID_VoieAccesANTBCZFk','Voie acces antenne BCZS','geolocalisation','Transport',ARRAY['antBczAccessRoutes']::text[],true),
('geolocalisation','T_Niveau_3','ID_VoieAccesDPSBCZFk','Voie acces DPS BCZS','geolocalisation','Transport',ARRAY['dpsBczAccessRoutes']::text[],true),
('geolocalisation','T_Niveau_4','ID_TypeNiveau_4_Fk','Type niveau 4','geolocalisation','Type de site',ARRAY['niveau4Types']::text[],true),
('geolocalisation','T_Niveau_4','ID_DispoReseauNiveau_4','Disponibilite reseau','geolocalisation','Disponibilité réseau',ARRAY['networkAvailabilities']::text[],true),
('geolocalisation','T_Niveau_4','ID_VoieAccesZsASFk','Voie acces ZS-AS','geolocalisation','Transport',ARRAY['zsAsAccessRoutes']::text[],true),
('geolocalisation','T_Niveau_4','ID_StatutNiveau_4','Statut niveau 4','geolocalisation','Statut site',ARRAY['niveau4Statuses']::text[],true),
('geolocalisation','T_Niveau_4','ID_StatutDeploiementFk','Statut deploiement','geolocalisation','Status Deploiement',ARRAY['deploymentStatuses']::text[],true),
('geolocalisation','T_Niveau_5','ID_DispoReseauNiveau_5','Disponibilite reseau','geolocalisation','Disponibilité réseau',ARRAY['networkAvailabilities']::text[],true),
('geolocalisation','T_Niveau_5','ID_VoieAccesZsSiteFk','Voie acces ZS-Site','geolocalisation','Transport',ARRAY['zsSiteAccessRoutes']::text[],true),
('geolocalisation','T_Niveau_5','ID_StatutNiveau_5','Statut niveau 5','geolocalisation','Statut site',ARRAY['niveau5Statuses']::text[],true),
('geolocalisation','T_Niveau_5','ID_StatutDeploiementFk','Statut deploiement','geolocalisation','Status Deploiement',ARRAY['deploymentStatuses']::text[],true),
('geolocalisation','T_Niveau_5','ID_TypeToitFk','Type de toit','geolocalisation','Type de toiture',ARRAY['roofTypes']::text[],true),
('logistique','T_Article','ID_TypeArticleFk','Type d''article','logistique','Type produit',ARRAY['logistique.articleTypes']::text[],true),
('logistique','T_Article','ID_CategorieArticleFk','Categorie d''article','logistique','Catégorie produit',ARRAY['logistique.articleCategories']::text[],true),
('logistique','T_Article','ID_UniteFk','Unite','logistique','Unités',ARRAY['logistique.articleUnits']::text[],true),
('logistique','T_Article','ID_UnitePoidsFk','ID_UnitePoidsFk','logistique','Unités',ARRAY[]::text[],true),
('logistique','T_Article','ID_DeviseFk','ID_DeviseFk','logistique','Devise',ARRAY[]::text[],true),
('logistique','T_Avoir','ID_DeviseFk','ID_DeviseFk','logistique','Devise',ARRAY[]::text[],true),
('logistique','T_Client','ID_TypeClientFk','ID_TypeClientFk','logistique','Type de personne',ARRAY[]::text[],true),
('logistique','T_Commande','ID_TypeCmdFk','Type de commande','logistique','Type de commande',ARRAY['logistique.commandeTypes']::text[],true),
('logistique','T_Commande','ID_StatutCmdFk','Statut commande','logistique','Statut',ARRAY['logistique.commandeStatuses']::text[],true),
('logistique','T_Commande','ID_ConditionPaiementFk','Condition de paiement','logistique','Condition de paiement',ARRAY['logistique.commandeConditionPaiements']::text[],true),
('logistique','T_Commande','ID_ModePaiementFk','Mode de paiement','logistique','Mode paiement',ARRAY['logistique.commandeModesPaiement']::text[],true),
('logistique','T_Commande','ID_DeviseFk','ID_DeviseFk','logistique','Devise',ARRAY[]::text[],true),
('logistique','T_Facture','ID_ModePaiementFk','ID_ModePaiementFk','logistique','Mode paiement',ARRAY[]::text[],true),
('logistique','T_Facture','ID_ConditionPaiementFk','ID_ConditionPaiementFk','logistique','Condition de paiement',ARRAY[]::text[],true),
('logistique','T_Facture','ID_DeviseFk','ID_DeviseFk','logistique','Devise',ARRAY[]::text[],true),
('logistique','T_Immobilisation','ID_DeviseFk','ID_DeviseFk','logistique','Devise',ARRAY[]::text[],true),
('logistique','T_Immobilisation','ID_CategorieFk','ID_CategorieFk','logistique','Type de matériel',ARRAY['logistique.immobilisations.categories']::text[],true),
('logistique','T_Immobilisation','ID_EtatFk','ID_EtatFk','logistique','Etat',ARRAY['logistique.immobilisations.etats']::text[],true),
('logistique','T_Immobilisation','ID_ServiceFk','ID_ServiceFk','logistique','Service',ARRAY['logistique.immobilisations.services']::text[],true),
('logistique','T_Mouvement','ID_TypeMvtFk','ID_TypeMvtFk','logistique','Type de commande',ARRAY[]::text[],true),
('logistique','T_Mouvement','ID_DeviseFk','ID_DeviseFk','logistique','Devise',ARRAY[]::text[],true),
('logistique','T_PrecisionStock','ID_UniteFk','ID_UniteFk','logistique','Unités',ARRAY[]::text[],true),
('logistique','T_Reglements','ID_ModeReglementFk','Mode de reglement','logistique','Mode paiement',ARRAY['logistique.reglementModes']::text[],true),
('logistique','T_Reglements','ID_DeviseFk','ID_DeviseFk','logistique','Devise',ARRAY[]::text[],true),
('logistique','T_Remboursement','ID_ModePaiementFk','ID_ModePaiementFk','logistique','Mode paiement',ARRAY[]::text[],true),
('logistique','T_ValorisationOuverture','ID_DeviseFk','ID_DeviseFk','logistique','Devise',ARRAY[]::text[],true),
('operations','T_Caisse','IdDeviseFk','IdDeviseFk','operations','Devise',ARRAY[]::text[],true),
('operations','T_Paiement','IdTypePaiementFk','IdTypePaiementFk','operations',NULL,ARRAY[]::text[],true),
('operations','T_Paiement','IdDeviseFk','IdDeviseFk','operations','Devise',ARRAY[]::text[],true),
('professionnel','T_Professionnel','IdTypeProfessionnelFk','IdTypeProfessionnelFk','professionnel',NULL,ARRAY[]::text[],true),
('professionnel','T_Professionnel','IdSpecialiteFk','IdSpecialiteFk','professionnel','Spécialité',ARRAY[]::text[],true),
('professionnel','T_Professionnel_Entite','IdTypeLienFk','IdTypeLienFk','professionnel',NULL,ARRAY[]::text[],true),
('systeme','T_Entite','IdTypeEntiteFk','Type entite','systeme','Type entite',ARRAY['entityTypes']::text[],true),
('systeme','T_Licence','IdStatutLicenceFk','Statut licence','systeme','Statut licence',ARRAY['licenseStatuses']::text[],true),
('systeme','T_Login','IdTypeLoginFk','IdTypeLoginFk','systeme','Type login',ARRAY[]::text[],true),
('systeme','T_RoleModule','IdRoleFk','Role','systeme','Role',ARRAY['roles']::text[],false),
('systeme','T_Utilisateurs','IdRoleFk','Role','systeme','Role',ARRAY['roles']::text[],false),
('systeme','T_Utilisateurs','ID_ServiceFk','ID_ServiceFk','systeme','Service',ARRAY[]::text[],true),
('systeme','T_Utilisateurs','ID_FonctionFk','ID_FonctionFk','systeme','Fonction',ARRAY[]::text[],true)
)
INSERT INTO referentiel."T_ChampReferentiel"("SchemaName","TableName","ColumnName","ChampLabel","ModuleName","ID_CategorieDefautFk","AliasSourceKeys","CanConfigure","SupportsEntityScope")
SELECT s.schema_name,s.table_name,s.column_name,s.label,s.module_name,
 (SELECT c."ID_CategorieGenerique" FROM referentiel."T_CategorieGenerique" c WHERE lower(btrim(c."NomCategorieGenerique"))=lower(s.family_name)),s.aliases,s.configurable,
 NOT(s.schema_name='geolocalisation' OR (s.schema_name,s.table_name) IN(('analytics','T_Recherche'),('professionnel','T_Professionnel'),('logistique','T_PrecisionStock'))) FROM seed s;
DO $proof$ BEGIN
 IF (SELECT count(*) FROM referentiel."T_ChampReferentiel")<>60 OR EXISTS(
 SELECT FROM referentiel."T_ChampReferentiel" r WHERE NOT EXISTS(
 SELECT FROM pg_constraint k JOIN pg_class t ON t.oid=k.conrelid JOIN pg_namespace n ON n.oid=t.relnamespace
 JOIN pg_attribute a ON a.attrelid=t.oid AND a.attnum=ANY(k.conkey)
 WHERE k.contype='f' AND k.confrelid='referentiel."T_Generique"'::regclass AND n.nspname=r."SchemaName" AND t.relname=r."TableName" AND a.attname=r."ColumnName")) THEN RAISE EXCEPTION 'Catalogue physique non conforme';END IF;
END $proof$;
CREATE FUNCTION referentiel.fn_resolution_champ(p_schema text,p_table text,p_colonne text,p_entite integer DEFAULT NULL)
RETURNS TABLE("CategoryIds" integer[],"OrigineReglage" text) LANGUAGE sql STABLE SET search_path=pg_catalog AS $$
 WITH champ AS (SELECT * FROM referentiel."T_ChampReferentiel" WHERE "SchemaName"=p_schema AND "TableName"=p_table AND "ColumnName"=p_colonne),
 candidates AS (
 SELECT f.*,CASE WHEN f."SettingScope"='entity' THEN CASE WHEN f."IdChampReferentielFk" IS NOT NULL THEN 1 ELSE 2 END ELSE CASE WHEN f."IdChampReferentielFk" IS NOT NULL THEN 3 ELSE 4 END END priority
 FROM champ c JOIN systeme."T_Fk_Correspondance" f ON (f."IdChampReferentielFk"=c."ID_ChampReferentiel" OR (f."IdChampReferentielFk" IS NULL AND f."SourceKey"=ANY(c."AliasSourceKeys")))
 WHERE c."CanConfigure" AND f."MappingType"='generic_category' AND f."ValideFkCorrespondance"
 AND ((f."SettingScope"='global' AND f."ScopeValue" IS NULL) OR (c."SupportsEntityScope" AND f."SettingScope"='entity' AND f."ScopeValue"=p_entite::text))
 ), chosen AS (SELECT * FROM candidates WHERE priority=(SELECT min(priority) FROM candidates)),
 resolved AS (SELECT CASE WHEN EXISTS(SELECT FROM chosen) THEN
 CASE WHEN EXISTS(SELECT FROM chosen WHERE "MappingValue"='@default') THEN ARRAY_REMOVE(ARRAY[c."ID_CategorieDefautFk"],NULL)
 ELSE ARRAY(SELECT DISTINCT "TargetCategoryIdFk" FROM chosen WHERE "TargetCategoryIdFk" IS NOT NULL ORDER BY "TargetCategoryIdFk") END
 ELSE ARRAY_REMOVE(ARRAY[c."ID_CategorieDefautFk"],NULL) END ids,
 CASE WHEN EXISTS(SELECT FROM chosen WHERE "MappingValue"='@default') THEN CASE WHEN c."ID_CategorieDefautFk" IS NULL THEN 'non_configure' ELSE 'defaut' END
 WHEN EXISTS(SELECT FROM chosen WHERE "SettingScope"='entity') THEN 'entity'
 WHEN EXISTS(SELECT FROM chosen) THEN 'global'
 WHEN c."ID_CategorieDefautFk" IS NULL THEN 'non_configure' ELSE 'defaut' END origin FROM champ c)
 SELECT coalesce((SELECT ids FROM resolved),'{}'::integer[]),coalesce((SELECT origin FROM resolved),'inconnu') $$;
COMMENT ON FUNCTION referentiel.fn_resolution_champ(text,text,text,integer) IS 'Résolution canonique : entreprise puis global, jeu canonique avant alias au même scope, puis défaut immuable. Un marqueur explicite @default ne retombe jamais sur une ancienne surcharge.';
CREATE FUNCTION referentiel.fn_categories_champ(p_schema text,p_table text,p_colonne text,p_entite integer DEFAULT NULL) RETURNS integer[]
LANGUAGE sql STABLE SET search_path=pg_catalog AS $$ SELECT "CategoryIds" FROM referentiel.fn_resolution_champ(p_schema,p_table,p_colonne,p_entite) $$;
COMMENT ON FUNCTION referentiel.fn_categories_champ(text,text,text,integer) IS 'Familles effectives du champ physique et de son entreprise. Vide signifie non configuré ; les scopes pays et visibilités historiques ne sont pas implicitement activés.';
CREATE FUNCTION referentiel.fn_valider_reference_champ(p_schema text,p_table text,p_colonne text,p_valeur integer,p_entite integer DEFAULT NULL) RETURNS boolean
LANGUAGE sql STABLE SET search_path=pg_catalog AS $$ SELECT p_valeur IS NULL OR EXISTS(
 SELECT FROM referentiel."T_Generique" g JOIN referentiel."T_CategorieGenerique" c ON c."ID_CategorieGenerique"=g."ID_CategorieGeneriqueFk"
 WHERE g."ID_Generique"=p_valeur AND g."ValideGenerique" AND c."ValideCategorieGenerique" AND g."ID_CategorieGeneriqueFk"=ANY(referentiel.fn_categories_champ(p_schema,p_table,p_colonne,p_entite))) $$;
COMMENT ON FUNCTION referentiel.fn_valider_reference_champ(text,text,text,integer,integer) IS 'Vérifie une nouvelle affectation de référence : valeur et famille actives, famille courante du champ et de l’entreprise. NULL reste soumis à la contrainte NOT NULL de la vraie colonne.';
CREATE FUNCTION referentiel.fn_reference_champ_connue(p_schema text,p_table text,p_colonne text,p_valeur integer) RETURNS boolean
LANGUAGE plpgsql STABLE SET search_path=pg_catalog AS $$
DECLARE r referentiel."T_ChampReferentiel"; cat integer; used boolean;
BEGIN
 IF p_valeur IS NULL THEN RETURN true;END IF;
 SELECT * INTO r FROM referentiel."T_ChampReferentiel" WHERE "SchemaName"=p_schema AND "TableName"=p_table AND "ColumnName"=p_colonne;
 IF NOT FOUND THEN RETURN false;END IF;
 SELECT "ID_CategorieGeneriqueFk" INTO cat FROM referentiel."T_Generique" WHERE "ID_Generique"=p_valeur;
 IF NOT FOUND THEN RETURN false;END IF;
 IF cat=r."ID_CategorieDefautFk" OR (r."CanConfigure" AND EXISTS(SELECT FROM systeme."T_Fk_Correspondance" f
 WHERE f."MappingType"='generic_category' AND f."TargetCategoryIdFk"=cat AND (f."IdChampReferentielFk"=r."ID_ChampReferentiel" OR (f."IdChampReferentielFk" IS NULL AND f."SourceKey"=ANY(r."AliasSourceKeys"))))) THEN RETURN true;END IF;
 EXECUTE format('SELECT EXISTS(SELECT FROM %I.%I WHERE %I=$1)',p_schema,p_table,p_colonne) INTO used USING p_valeur;
 RETURN used;
END $$;
COMMENT ON FUNCTION referentiel.fn_reference_champ_connue(text,text,text,integer) IS 'Reconnaissance de lecture et des procédures historiques : famille de référence, catégorie déclarée ou valeur déjà utilisée dans la vraie FK. Ne remplace jamais la validation stricte d’une nouvelle affectation.';
CREATE FUNCTION referentiel.fn_entite_reference_champ(p_schema text,p_table text,p_ligne jsonb) RETURNS integer
LANGUAGE plpgsql STABLE SET search_path=pg_catalog AS $$
DECLARE owner_id integer;
BEGIN
 -- L'entreprise de l'utilisateur ou d'un résultat de recherche n'est pas
 -- un propriétaire durable d'une ligne partagée.
 IF p_ligne IS NULL OR NOT EXISTS(SELECT FROM referentiel."T_ChampReferentiel" WHERE "SchemaName"=p_schema AND "TableName"=p_table AND "SupportsEntityScope") THEN RETURN NULL;END IF;
 IF (p_schema,p_table)=('systeme','T_Entite') THEN RETURN nullif(p_ligne->>'IdEntite','')::integer;END IF;
 owner_id:=coalesce(nullif(p_ligne->>'IdEntiteFk','')::integer,nullif(p_ligne->>'ID_EntiteFk','')::integer);
 IF owner_id IS NOT NULL THEN RETURN owner_id;END IF;
 IF p_schema='logistique' THEN
  CASE p_table
   WHEN 'T_Mouvement' THEN
    SELECT "IdEntiteFk" INTO owner_id FROM logistique."T_Commande" WHERE "ID_Commande"=nullif(p_ligne->>'ID_cmdFk','')::integer;
    IF owner_id IS NULL THEN SELECT "IdEntiteFk" INTO owner_id FROM logistique."T_Article" WHERE "ID_Article"=nullif(p_ligne->>'ID_ArticleFk','')::integer;END IF;
   WHEN 'T_Reglements' THEN
    SELECT "IdEntiteFk" INTO owner_id FROM logistique."T_Facture" WHERE "CodeFacture"=p_ligne->>'CodeFactureFk';
    IF owner_id IS NULL THEN SELECT "IdEntiteFk" INTO owner_id FROM logistique."T_Commande" WHERE "CodeFacture"=p_ligne->>'CodeFactureFk';END IF;
   WHEN 'T_Remboursement' THEN SELECT "IdEntiteFk" INTO owner_id FROM logistique."T_Avoir" WHERE "ID_Avoir"=nullif(p_ligne->>'ID_AvoirFk','')::bigint;
   ELSE NULL;
  END CASE;
 END IF;
 RETURN owner_id;
END $$;
COMMENT ON FUNCTION referentiel.fn_entite_reference_champ(text,text,jsonb) IS 'Entreprise de la vraie ligne : FK directe, PK de T_Entite ou parent logistique prouvé. Retourne NULL pour les tables partagées ; ne déduit jamais une propriété depuis l’utilisateur, la session ou un résultat de recherche. Fonction de lecture sans autorisation supplémentaire.';
CREATE FUNCTION referentiel.tr_valider_champ_referentiel() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE r record; before_data jsonb; after_data jsonb:=to_jsonb(NEW); owner_id integer; old_owner integer; value_id integer; parent_data jsonb; parent_column text;
BEGIN
 IF TG_OP='UPDATE' THEN before_data:=to_jsonb(OLD);END IF;
 owner_id:=referentiel.fn_entite_reference_champ(TG_TABLE_SCHEMA,TG_TABLE_NAME,after_data);
 old_owner:=referentiel.fn_entite_reference_champ(TG_TABLE_SCHEMA,TG_TABLE_NAME,before_data);
 IF TG_TABLE_SCHEMA='logistique' THEN
  IF TG_TABLE_NAME='T_Mouvement' THEN
   SELECT to_jsonb(c) INTO parent_data FROM logistique."T_Commande" c WHERE c."ID_Commande"=(after_data->>'ID_cmdFk')::integer;
   IF parent_data IS NULL THEN SELECT to_jsonb(a) INTO parent_data FROM logistique."T_Article" a WHERE a."ID_Article"=(after_data->>'ID_ArticleFk')::integer;END IF;
  ELSIF TG_TABLE_NAME IN('T_Facture','T_Avoir') THEN SELECT to_jsonb(c) INTO parent_data FROM logistique."T_Commande" c WHERE c."ID_Commande"=(after_data->>'ID_CommandeFk')::integer;
  ELSIF TG_TABLE_NAME='T_Reglements' THEN SELECT to_jsonb(c) INTO parent_data FROM logistique."T_Facture" c WHERE c."CodeFacture"=after_data->>'CodeFactureFk';
  ELSIF TG_TABLE_NAME='T_Remboursement' THEN SELECT to_jsonb(c) INTO parent_data FROM logistique."T_Avoir" c WHERE c."ID_Avoir"=(after_data->>'ID_AvoirFk')::bigint;
  ELSIF TG_TABLE_NAME='T_ValorisationOuverture' THEN SELECT to_jsonb(a) INTO parent_data FROM logistique."T_Article" a WHERE a."ID_Article"=(after_data->>'ID_ArticleFk')::integer;
  END IF;
 END IF;
 FOR r IN SELECT * FROM referentiel."T_ChampReferentiel" WHERE "SchemaName"=TG_TABLE_SCHEMA AND "TableName"=TG_TABLE_NAME ORDER BY "ID_ChampReferentiel" LOOP
  IF TG_OP='UPDATE' AND after_data->r."ColumnName" IS NOT DISTINCT FROM before_data->r."ColumnName" AND owner_id IS NOT DISTINCT FROM old_owner THEN CONTINUE;END IF;
  value_id:=nullif(after_data->>r."ColumnName",'')::integer;
  IF value_id IS NOT NULL THEN PERFORM 1 FROM referentiel."T_Generique" WHERE "ID_Generique"=value_id FOR SHARE;END IF;
  -- Une référence financière/physique copiée exactement du parent historique
  -- reste celle du parent, même après changement de la catégorie proposée.
  parent_column:=CASE WHEN TG_TABLE_NAME='T_Mouvement' AND r."ColumnName"='ID_TypeMvtFk' THEN 'ID_TypeCmdFk' ELSE r."ColumnName" END;
  IF TG_TABLE_SCHEMA='logistique' AND parent_data IS NOT NULL AND (
   r."ColumnName"='ID_DeviseFk' OR (TG_TABLE_NAME='T_Mouvement' AND r."ColumnName"='ID_TypeMvtFk')
   OR (TG_TABLE_NAME='T_Facture' AND r."ColumnName" IN('ID_ModePaiementFk','ID_ConditionPaiementFk')))
   AND owner_id IS NOT DISTINCT FROM (parent_data->>'IdEntiteFk')::integer
   AND value_id IS NOT NULL AND after_data->r."ColumnName" IS NOT DISTINCT FROM parent_data->parent_column THEN CONTINUE;END IF;
  IF NOT referentiel.fn_valider_reference_champ(TG_TABLE_SCHEMA,TG_TABLE_NAME,r."ColumnName",value_id,owner_id) THEN
   RAISE EXCEPTION 'Référence inactive ou incompatible pour %.%.%.',TG_TABLE_SCHEMA,TG_TABLE_NAME,r."ColumnName" USING ERRCODE='23514';END IF;
 END LOOP;
 RETURN NEW;
END $$;
COMMENT ON FUNCTION referentiel.tr_valider_champ_referentiel() IS 'Garde de toutes les FK cataloguées : INSERT ou changement effectif de valeur/entreprise seulement. Une référence historique inchangée reste consultable et autorise une modification descriptive.';
CREATE FUNCTION referentiel.tr_catalogue_champ_integrite() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $$
BEGIN
 IF TG_OP='DELETE' THEN RAISE EXCEPTION 'Catalogue physique conservé.' USING ERRCODE='23514';END IF;
 IF TG_OP='INSERT' THEN
  IF NOT EXISTS(SELECT FROM pg_constraint k JOIN pg_class t ON t.oid=k.conrelid JOIN pg_namespace n ON n.oid=t.relnamespace
   JOIN pg_attribute a ON a.attrelid=t.oid AND a.attnum=ANY(k.conkey) WHERE k.contype='f' AND k.confrelid='referentiel."T_Generique"'::regclass
   AND n.nspname=NEW."SchemaName" AND t.relname=NEW."TableName" AND a.attname=NEW."ColumnName") THEN RAISE EXCEPTION 'Colonne physique à FK non prouvée.' USING ERRCODE='23514';END IF;
  RETURN NEW;
 END IF;
 IF (to_jsonb(NEW)-ARRAY['Revision','ModifieLe','ModifieParUserFk']) IS DISTINCT FROM (to_jsonb(OLD)-ARRAY['Revision','ModifieLe','ModifieParUserFk']) OR pg_trigger_depth()<2 THEN
  RAISE EXCEPTION 'Définition et catégorie de référence immuables ; utilisez les correspondances courantes.' USING ERRCODE='23514';END IF;
 RETURN NEW;
END $$;
COMMENT ON FUNCTION referentiel.tr_catalogue_champ_integrite() IS 'Conserve la clé physique, le défaut prouvé et la politique de sécurité ; seule une révision interne issue des correspondances peut modifier les métadonnées. Un chargement initial doit prouver la vraie FK ; les clés déjà installées sont uniques.';
CREATE TRIGGER tr_catalogue_champ_integrite BEFORE INSERT OR UPDATE OR DELETE ON referentiel."T_ChampReferentiel" FOR EACH ROW EXECUTE FUNCTION referentiel.tr_catalogue_champ_integrite();
COMMENT ON TRIGGER tr_catalogue_champ_integrite ON referentiel."T_ChampReferentiel" IS 'Catalogue et défauts fermés aux écritures ordinaires ; version alimentée par les jeux de correspondances.';
CREATE FUNCTION systeme.tr_correspondance_champ_integrite() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE row_data jsonb; r referentiel."T_ChampReferentiel"; cat integer;
BEGIN
 row_data:=CASE WHEN TG_OP='DELETE' THEN to_jsonb(OLD) ELSE to_jsonb(NEW) END;
 IF (row_data->>'IdChampReferentielFk') IS NULL THEN
  PERFORM 1 FROM referentiel."T_ChampReferentiel" c WHERE row_data->>'SourceKey'=ANY(c."AliasSourceKeys") ORDER BY c."ID_ChampReferentiel" FOR UPDATE;
  IF row_data->>'SourceKey' LIKE 'champ.%' THEN RAISE EXCEPTION 'Identité de champ canonique obligatoire' USING ERRCODE='23514';END IF;
  IF EXISTS(SELECT FROM referentiel."T_ChampReferentiel" c WHERE NOT c."CanConfigure" AND row_data->>'SourceKey'=ANY(c."AliasSourceKeys") AND (row_data->>'TargetCategoryIdFk')::integer IS DISTINCT FROM c."ID_CategorieDefautFk") THEN
   RAISE EXCEPTION 'Famille de sécurité protégée.' USING ERRCODE='23514';END IF;
  RETURN CASE WHEN TG_OP='DELETE' THEN OLD ELSE NEW END;
 END IF;
 SELECT * INTO r FROM referentiel."T_ChampReferentiel" WHERE "ID_ChampReferentiel"=(row_data->>'IdChampReferentielFk')::integer FOR UPDATE;
 IF NOT FOUND OR NOT r."CanConfigure" THEN RAISE EXCEPTION 'Champ absent ou protégé.' USING ERRCODE='23514';END IF;
 IF TG_OP='UPDATE' AND NEW."IdChampReferentielFk" IS DISTINCT FROM OLD."IdChampReferentielFk" THEN RAISE EXCEPTION 'Identité du réglage conservée.' USING ERRCODE='23514';END IF;
 IF TG_OP='DELETE' THEN RETURN OLD;END IF;
 IF NEW."MappingType"<>'generic_category' OR NEW."SourceKey"<>'champ.'||r."ID_ChampReferentiel"::text OR NEW."SchemaName"<>r."SchemaName" OR NEW."FieldName"<>r."ColumnName" OR NEW."ModuleName"<>r."ModuleName" OR NEW."ViewName" IS NOT NULL
  OR NEW."ReferenceSchemaName" IS DISTINCT FROM 'referentiel' OR NEW."ReferenceObjectName" IS DISTINCT FROM 'T_Generique' OR NEW."ReferenceFieldName" IS DISTINCT FROM 'ID_Generique'
  OR NEW."SettingScope" NOT IN ('global','entity') OR NEW."DisplayOrder"<0 THEN RAISE EXCEPTION 'Correspondance et colonne physique incohérentes.' USING ERRCODE='23514';END IF;
 IF NEW."SettingScope"='entity' AND NOT r."SupportsEntityScope" THEN RAISE EXCEPTION 'Ce champ partagé ne possède pas de portée entreprise.' USING ERRCODE='23514';END IF;
 IF NEW."SettingScope"='entity' AND (NEW."ScopeValue" !~ '^[1-9][0-9]{0,9}$' OR NOT EXISTS(SELECT FROM systeme."T_Entite" WHERE "IdEntite"::text=NEW."ScopeValue")) THEN RAISE EXCEPTION 'Entreprise de réglage introuvable.' USING ERRCODE='23514';END IF;
 IF NEW."MappingValue"='@default' THEN
  IF NEW."TargetCategoryIdFk" IS NOT NULL OR NOT NEW."IsDefaultMapping" THEN RAISE EXCEPTION 'Marqueur de restauration invalide.' USING ERRCODE='23514';END IF;
 ELSE
  IF NEW."TargetCategoryIdFk" IS NULL OR NEW."MappingValue"<>NEW."TargetCategoryIdFk"::text OR NOT EXISTS(SELECT FROM referentiel."T_CategorieGenerique" WHERE "ID_CategorieGenerique"=NEW."TargetCategoryIdFk" AND "ValideCategorieGenerique") THEN
   RAISE EXCEPTION 'Catégorie courante active requise.' USING ERRCODE='23514';END IF;
 END IF;
 IF EXISTS(SELECT FROM systeme."T_Fk_Correspondance" f WHERE f."IdChampReferentielFk"=r."ID_ChampReferentiel" AND f."SettingScope"=NEW."SettingScope" AND f."ScopeValue" IS NOT DISTINCT FROM NEW."ScopeValue" AND f."IdFkCorrespondance"<>coalesce(NEW."IdFkCorrespondance",-1)
  AND ((NEW."MappingValue"='@default')<>(f."MappingValue"='@default'))) THEN RAISE EXCEPTION 'Un jeu de réglage ne mélange pas restauration et catégories.' USING ERRCODE='23514';END IF;
 RETURN NEW;
END $$;
COMMENT ON FUNCTION systeme.tr_correspondance_champ_integrite() IS 'Contrôle des jeux canoniques : champ physique, famille active, portée existante, restauration explicite et verrou du catalogue. Les anciens réglages restent conservés, les rôles de sécurité ne changent pas de famille.';
CREATE TRIGGER a_correspondance_champ_integrite BEFORE INSERT OR UPDATE OR DELETE ON systeme."T_Fk_Correspondance" FOR EACH ROW EXECUTE FUNCTION systeme.tr_correspondance_champ_integrite();
COMMENT ON TRIGGER a_correspondance_champ_integrite ON systeme."T_Fk_Correspondance" IS 'Valide une correspondance canonique avant les dates/audits existants, sans remplacer les contrôles de droits applicatifs.';
CREATE FUNCTION systeme.tr_correspondance_champ_revision() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE before_data jsonb; after_data jsonb;
BEGIN
 IF TG_OP<>'INSERT' THEN before_data:=to_jsonb(OLD);END IF;
 IF TG_OP<>'DELETE' THEN after_data:=to_jsonb(NEW);END IF;
 UPDATE referentiel."T_ChampReferentiel" c SET "Revision"=c."Revision"+1,"ModifieLe"=clock_timestamp(),"ModifieParUserFk"=systeme.fn_admin_actor_user_id()
 WHERE c."ID_ChampReferentiel" IN (nullif(before_data->>'IdChampReferentielFk','')::integer,nullif(after_data->>'IdChampReferentielFk','')::integer)
 OR coalesce(before_data->>'SourceKey','')=ANY(c."AliasSourceKeys") OR coalesce(after_data->>'SourceKey','')=ANY(c."AliasSourceKeys");
 RETURN NULL;
END $$;
COMMENT ON FUNCTION systeme.tr_correspondance_champ_revision() IS 'Révision opaque commune au champ : chaque modification canonique ou de son alias historique invalide les lectures concurrentes, toutes portées confondues, avec auteur et horodatage factuels.';
CREATE TRIGGER zz_correspondance_champ_revision AFTER INSERT OR UPDATE OR DELETE ON systeme."T_Fk_Correspondance" FOR EACH ROW EXECUTE FUNCTION systeme.tr_correspondance_champ_revision();
COMMENT ON TRIGGER zz_correspondance_champ_revision ON systeme."T_Fk_Correspondance" IS 'Invalide la révision du catalogue après changement de correspondance et conserve les audits existants.';
DO $guards$ DECLARE r record;BEGIN
 FOR r IN SELECT DISTINCT "SchemaName" s,"TableName" t FROM referentiel."T_ChampReferentiel" ORDER BY 1,2 LOOP
 EXECUTE format('CREATE TRIGGER aa_reference_champ BEFORE INSERT OR UPDATE ON %I.%I FOR EACH ROW EXECUTE FUNCTION referentiel.tr_valider_champ_referentiel()',r.s,r.t);
 EXECUTE format('COMMENT ON TRIGGER aa_reference_champ ON %I.%I IS %L',r.s,r.t,'Valide les nouvelles références du catalogue physique ; conserve les valeurs historiques inchangées, même devenues hors famille.');
 END LOOP;
END $guards$;
CREATE VIEW referentiel."V_ReferencementChamp" AS
 SELECT c.*,s."CategoryIds",ARRAY(SELECT x."NomCategorieGenerique" FROM unnest(s."CategoryIds") WITH ORDINALITY a(id,ord) JOIN referentiel."T_CategorieGenerique" x ON x."ID_CategorieGenerique"=a.id ORDER BY a.ord) AS "CategoryLabels",
 array_to_string(ARRAY(SELECT x."NomCategorieGenerique" FROM unnest(s."CategoryIds") WITH ORDINALITY a(id,ord) JOIN referentiel."T_CategorieGenerique" x ON x."ID_CategorieGenerique"=a.id ORDER BY a.ord),', ') AS "CategoriesActuelles",
 d."NomCategorieGenerique" AS "CategorieDefaut",c."ID_CategorieDefautFk" AS "DefaultCategoryId",s."OrigineReglage",c."Revision"::text AS "_version",
 (c."SchemaName"='logistique' AND ((c."TableName" IN('T_Mouvement','T_Facture','T_Avoir','T_Reglements','T_ValorisationOuverture') AND c."ColumnName"='ID_DeviseFk') OR (c."TableName"='T_Mouvement' AND c."ColumnName"='ID_TypeMvtFk') OR (c."TableName"='T_Facture' AND c."ColumnName" IN('ID_ModePaiementFk','ID_ConditionPaiementFk')))) AS "ReferenceHeriteeParent"
 FROM referentiel."T_ChampReferentiel" c LEFT JOIN referentiel."T_CategorieGenerique" d ON d."ID_CategorieGenerique"=c."ID_CategorieDefautFk"
 CROSS JOIN LATERAL referentiel.fn_resolution_champ(c."SchemaName",c."TableName",c."ColumnName",NULL) s;
COMMENT ON VIEW referentiel."V_ReferencementChamp" IS 'Registre des 60 champs physiques, familles globales effectives et défauts prouvés ; pour un contexte entreprise utiliser le même résolveur avec son identifiant autorisé.';

-- Les procédures antérieures restent les points de calcul ; leurs validations de
-- famille délèguent au catalogue. La garde de table applique le scope strict.
CREATE OR REPLACE FUNCTION logistique.fn_assert_generique_category(p_id_generique integer,p_id_categorie_generique integer,p_contexte text,p_nom_colonne text) RETURNS void
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE table_name text;
BEGIN
 IF p_id_generique IS NULL THEN RETURN;END IF;
 table_name:=CASE WHEN p_contexte ILIKE '%article%' THEN 'T_Article' WHEN p_contexte ILIKE '%commande%' THEN 'T_Commande'
 WHEN p_contexte ILIKE '%reglement%' THEN 'T_Reglements' WHEN p_contexte ILIKE '%mouvement%' THEN 'T_Mouvement'
 WHEN p_contexte ILIKE '%remboursement%' THEN 'T_Remboursement' WHEN p_contexte ILIKE '%facture%' THEN 'T_Facture' END;
 IF table_name='T_Mouvement' AND p_nom_colonne='ID_TypeMvtFk' AND referentiel.fn_reference_champ_connue('logistique','T_Commande','ID_TypeCmdFk',p_id_generique) THEN RETURN;END IF;
 IF table_name='T_Facture' AND p_nom_colonne IN('ID_ModePaiementFk','ID_ConditionPaiementFk') AND referentiel.fn_reference_champ_connue('logistique','T_Commande',p_nom_colonne,p_id_generique) THEN RETURN;END IF;
 IF table_name IS NULL OR NOT referentiel.fn_reference_champ_connue('logistique',table_name,p_nom_colonne,p_id_generique) THEN
  RAISE EXCEPTION 'Référence incompatible pour %.%.',coalesce(table_name,p_contexte),p_nom_colonne USING ERRCODE='23514';END IF;
END $$;
COMMENT ON FUNCTION logistique.fn_assert_generique_category(integer,integer,text,text) IS 'Compatibilité des procédures historiques avec le catalogue physique. Le paramètre de famille ancien conserve la signature, sans imposer une constante ; la nouvelle affectation est validée au scope par la garde de table.';
CREATE OR REPLACE FUNCTION logistique.fn_nature_bon(p_type integer) RETURNS text LANGUAGE sql STABLE SET search_path=pg_catalog AS $$
 SELECT logistique.fn_nature_type_bon(g."AbrGenerique") FROM referentiel."T_Generique" g WHERE g."ID_Generique"=p_type
 AND (referentiel.fn_reference_champ_connue('logistique','T_Commande','ID_TypeCmdFk',p_type) OR referentiel.fn_reference_champ_connue('logistique','T_Mouvement','ID_TypeMvtFk',p_type)) $$;
COMMENT ON FUNCTION logistique.fn_nature_bon(integer) IS 'Nature par code Entrée/Sortie/CMD uniquement pour un type déclaré ou déjà utilisé. Retirer une famille du choix courant ne requalifie aucun document historique ; un type inconnu reste refusé.';
CREATE OR REPLACE FUNCTION referentiel.fn_guard_sens_stock() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $$
BEGIN
 IF EXISTS(SELECT FROM logistique."T_Commande" WHERE "ID_TypeCmdFk"=OLD."ID_Generique") OR EXISTS(SELECT FROM logistique."T_Mouvement" WHERE "ID_TypeMvtFk"=OLD."ID_Generique") THEN
  IF NEW."ID_CategorieGeneriqueFk" IS DISTINCT FROM OLD."ID_CategorieGeneriqueFk" OR logistique.fn_nature_type_bon(NEW."AbrGenerique") IS DISTINCT FROM logistique.fn_nature_type_bon(OLD."AbrGenerique") THEN
   RAISE EXCEPTION 'La nature d’un type de bon déjà utilisé ne peut pas changer.' USING ERRCODE='23514';END IF;
 END IF;RETURN NEW;
END $$;
COMMENT ON FUNCTION referentiel.fn_guard_sens_stock() IS 'Conserve le sens des types de bon déjà utilisés, dans toute famille actuelle ou ancienne, sans dépendre de l’identifiant historique64.';
CREATE OR REPLACE FUNCTION logistique.fn_reference_immobilisation_valide(p_id integer,p_famille text,p_entite integer) RETURNS boolean LANGUAGE sql STABLE SET search_path=pg_catalog AS $$
 SELECT referentiel.fn_valider_reference_champ(CASE WHEN p_famille IN('service-rh','fonction-rh') THEN 'systeme' ELSE 'logistique' END,
 CASE WHEN p_famille IN('service-rh','fonction-rh') THEN 'T_Utilisateurs' ELSE 'T_Immobilisation' END,
 CASE p_famille WHEN 'categories' THEN 'ID_CategorieFk' WHEN 'etats' THEN 'ID_EtatFk' WHEN 'services' THEN 'ID_ServiceFk' WHEN 'service-rh' THEN 'ID_ServiceFk' WHEN 'fonction-rh' THEN 'ID_FonctionFk' WHEN 'devise' THEN 'ID_DeviseFk' END,p_id,p_entite) $$;
COMMENT ON FUNCTION logistique.fn_reference_immobilisation_valide(integer,text,integer) IS 'Références du patrimoine et des données professionnelles résolues par le catalogue commun, sans seconde règle de catégorie dans ce domaine.';
CREATE OR REPLACE FUNCTION logistique.fn_verifier_devise(p_id integer) RETURNS void LANGUAGE plpgsql SET search_path=pg_catalog AS $$
BEGIN
 PERFORM 1 FROM referentiel."T_Generique" g JOIN referentiel."T_CategorieGenerique" c ON c."ID_CategorieGenerique"=g."ID_CategorieGeneriqueFk"
 WHERE g."ID_Generique"=p_id AND g."ValideGenerique" AND c."ValideCategorieGenerique" AND logistique.fn_code_devise(g."AbrGenerique") ~ '^[A-Z]{3}$'
 AND EXISTS(SELECT FROM referentiel."T_ChampReferentiel" r WHERE r."ColumnName" IN('ID_DeviseFk','IdDeviseFk') AND referentiel.fn_reference_champ_connue(r."SchemaName",r."TableName",r."ColumnName",p_id)) FOR SHARE OF g,c;
 IF NOT FOUND THEN RAISE EXCEPTION 'Une devise active de référence, avec code ISO, est requise.' USING ERRCODE='23514';END IF;
END $$;
COMMENT ON FUNCTION logistique.fn_verifier_devise(integer) IS 'Contrôle sémantique financier conservé : référence déclarée ou historique, valeur active et code ISO trois lettres. Le scope de la nouvelle affectation relève de la garde physique.';
CREATE OR REPLACE FUNCTION referentiel.tr_reference_utilisee_integrite() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE r record; used boolean;
BEGIN
 IF TG_OP='UPDATE' AND NEW."ID_Generique" IS NOT DISTINCT FROM OLD."ID_Generique" AND NEW."ID_CategorieGeneriqueFk" IS NOT DISTINCT FROM OLD."ID_CategorieGeneriqueFk" THEN RETURN NEW;END IF;
 FOR r IN SELECT "SchemaName" s,"TableName" t,"ColumnName" col FROM referentiel."T_ChampReferentiel" LOOP
  EXECUTE format('SELECT EXISTS(SELECT FROM %I.%I WHERE %I=$1)',r.s,r.t,r.col) INTO used USING OLD."ID_Generique";
  IF used THEN RAISE EXCEPTION 'Identité et famille d’une référence utilisée sont conservées ; désactivez-la si nécessaire.' USING ERRCODE='23514';END IF;
 END LOOP;
 RETURN CASE WHEN TG_OP='DELETE' THEN OLD ELSE NEW END;
END $$;
COMMENT ON FUNCTION referentiel.tr_reference_utilisee_integrite() IS 'Empêche une suppression/cascade ou migration de famille d’une valeur déjà utilisée dans les FK physiques, afin de préserver les historiques. Désactivation et changement de libellé restent distincts.';
CREATE TRIGGER aa_reference_utilisee_integrite BEFORE UPDATE OR DELETE ON referentiel."T_Generique" FOR EACH ROW EXECUTE FUNCTION referentiel.tr_reference_utilisee_integrite();
COMMENT ON TRIGGER aa_reference_utilisee_integrite ON referentiel."T_Generique" IS 'Protection transversale des références utilisées, sans réécrire les anciennes données hors famille.';

CREATE OR REPLACE PROCEDURE logistique.ps_crud_commande(IN p_id_commande integer, IN p_old_id_type_cmd integer, IN p_new_id_type_cmd integer, IN p_new_id_statut_cmd integer, IN p_new_id_condition_paiement integer, IN p_new_id_mode_paiement integer, IN p_operation character varying)
 LANGUAGE plpgsql
AS $procedure$
DECLARE op text:=upper(btrim(p_operation)); old_abr text; new_abr text; old_sign integer; new_sign integer; item record;
 prior_skip text:=coalesce(current_setting('logistique.skip_article_report_mvt',true),'off');
 prior_write text:=coalesce(current_setting('logistique.allow_t_mouvement_write',true),'off');
BEGIN
 IF op='DELETE' THEN RETURN; END IF;
 IF op NOT IN ('INSERT','UPDATE') OR op IS NULL THEN RAISE EXCEPTION 'Opération de commande inconnue.' USING ERRCODE='23514'; END IF;
 PERFORM logistique.fn_assert_generique_category(p_new_id_type_cmd,64,'Commande','ID_TypeCmdFk');
 PERFORM logistique.fn_assert_generique_category(p_new_id_statut_cmd,28,'Commande','ID_StatutCmdFk');
 PERFORM logistique.fn_assert_generique_category(p_new_id_condition_paiement,37,'Commande','ID_ConditionPaiementFk');
 PERFORM logistique.fn_assert_generique_category(p_new_id_mode_paiement,36,'Commande','ID_ModePaiementFk');
 SELECT "AbrGenerique" INTO new_abr FROM referentiel."T_Generique" WHERE "ID_Generique"=p_new_id_type_cmd AND referentiel.fn_reference_champ_connue('logistique','T_Commande','ID_TypeCmdFk',"ID_Generique");
 new_sign:=CASE WHEN new_abr ILIKE 'entr%' THEN 1 WHEN new_abr ILIKE 'sort%' THEN -1 ELSE 0 END;
 IF logistique.fn_nature_bon(p_new_id_type_cmd) IS NULL THEN RAISE EXCEPTION 'Type de bon inconnu.' USING ERRCODE='23514'; END IF;
 IF op='INSERT' OR p_old_id_type_cmd IS NOT DISTINCT FROM p_new_id_type_cmd THEN RETURN; END IF;
 IF logistique.fn_nature_bon(p_old_id_type_cmd)='commande' OR logistique.fn_nature_bon(p_new_id_type_cmd)='commande' THEN RAISE EXCEPTION 'Un bon de commande ne se convertit pas en mouvement physique ; créez un BE ou BS distinct.' USING ERRCODE='23514';END IF;
 IF NOT EXISTS(SELECT 1 FROM logistique."T_CommandeDetail" WHERE "ID_CmdFk"=p_id_commande) THEN RETURN; END IF;
 SELECT "AbrGenerique" INTO old_abr FROM referentiel."T_Generique" WHERE "ID_Generique"=p_old_id_type_cmd AND referentiel.fn_reference_champ_connue('logistique','T_Commande','ID_TypeCmdFk',"ID_Generique");
 old_sign:=CASE WHEN old_abr ILIKE 'entr%' THEN 1 WHEN old_abr ILIKE 'sort%' THEN -1 ELSE 0 END;
 IF old_sign=0 THEN RAISE EXCEPTION 'Ancien type inconnu : changement de sens impossible.' USING ERRCODE='23514'; END IF;
 PERFORM 1 FROM logistique."T_Article" a WHERE a."ID_Article" IN
 (SELECT "ID_ArticleFk" FROM logistique."T_CommandeDetail" WHERE "ID_CmdFk"=p_id_commande)
 ORDER BY a."ID_Article" FOR NO KEY UPDATE;
 PERFORM set_config('logistique.skip_article_report_mvt','on',true);
 FOR item IN SELECT "ID_ArticleFk" id,"QteCmdDetail"*(new_sign-old_sign) delta FROM logistique."T_CommandeDetail" WHERE "ID_CmdFk"=p_id_commande ORDER BY "ID_ArticleFk"
 LOOP IF item.delta<>0 THEN CALL logistique.ps_update_qte_article(item.id,abs(item.delta),CASE WHEN item.delta>0 THEN '+' ELSE '-' END); END IF; END LOOP;
 PERFORM set_config('logistique.skip_article_report_mvt',prior_skip,true);
 PERFORM set_config('logistique.allow_t_mouvement_write','on',true);
 UPDATE logistique."T_Mouvement" SET "ID_TypeMvtFk"=p_new_id_type_cmd WHERE "ID_cmdFk"=p_id_commande;
 PERFORM set_config('logistique.allow_t_mouvement_write',prior_write,true);
END;
$procedure$;
COMMENT ON PROCEDURE logistique.ps_crud_commande(IN p_id_commande integer, IN p_old_id_type_cmd integer, IN p_new_id_type_cmd integer, IN p_new_id_statut_cmd integer, IN p_new_id_condition_paiement integer, IN p_new_id_mode_paiement integer, IN p_operation character varying) IS 'Procédure de sens des bons conservée ; familles déléguées au catalogue sans modifier le sens, les codes, les lignes ou les mouvements historiques.';

CREATE OR REPLACE FUNCTION logistique.fn_verifier_quantite(p_unite integer, p_qte numeric)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE d integer;
BEGIN
 IF p_qte IS NULL THEN RETURN;END IF;
 IF p_qte<0 OR p_qte::text IN ('NaN','Infinity','-Infinity') OR p_qte>99999999999.999 OR p_qte<>round(p_qte,3) THEN
  RAISE EXCEPTION 'Quantité hors précision' USING ERRCODE='23514';
 END IF;
 PERFORM 1 FROM referentiel."T_Generique" WHERE "ID_Generique"=p_unite AND (referentiel.fn_reference_champ_connue('logistique','T_Article','ID_UniteFk',p_unite) OR referentiel.fn_reference_champ_connue('logistique','T_PrecisionStock','ID_UniteFk',p_unite)) FOR SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Unité de stock requise' USING ERRCODE='23514';END IF;
 SELECT "DecimalesStock" INTO d FROM logistique."V_PrecisionStock" WHERE "ID_UniteFk"=p_unite;
 IF d IS NULL OR p_qte<>round(p_qte,d) THEN
  RAISE EXCEPTION 'Quantité incompatible avec la précision de son unité' USING ERRCODE='23514';
 END IF;
END $function$;
COMMENT ON FUNCTION logistique.fn_verifier_quantite(p_unite integer, p_qte numeric) IS 'Contrôle exact des quantités et de la politique de précision ; unités déclarées ou déjà utilisées sans arrondi silencieux, même après changement des choix proposés.';

CREATE OR REPLACE FUNCTION logistique.tr_precision_stock()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
 IF TG_OP='DELETE' THEN
  RAISE EXCEPTION 'Conservez la politique ; choisissez explicitement zéro décimale si nécessaire' USING ERRCODE='23514';
 END IF;
 IF TG_OP='UPDATE' AND
 (NEW."ID_PrecisionStock"<>OLD."ID_PrecisionStock" OR NEW."ID_UniteFk"<>OLD."ID_UniteFk") THEN
  RAISE EXCEPTION 'L’identité et l’unité de la politique sont conservées' USING ERRCODE='23514';
 END IF;
 -- Même clé de verrou que fn_verifier_quantite : la réduction attend les opérations en cours.
 PERFORM 1 FROM referentiel."T_Generique"
  WHERE "ID_Generique"=NEW."ID_UniteFk" AND (referentiel.fn_reference_champ_connue('logistique','T_Article','ID_UniteFk',NEW."ID_UniteFk") OR referentiel.fn_reference_champ_connue('logistique','T_PrecisionStock','ID_UniteFk',NEW."ID_UniteFk")) FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Une unité du référentiel Unités est requise' USING ERRCODE='23514';END IF;
 IF TG_OP='UPDATE' AND NEW."DecimalesStock" IS NOT DISTINCT FROM OLD."DecimalesStock" THEN
  NEW."ModifieLe"=OLD."ModifieLe";RETURN NEW;
 END IF;
 PERFORM logistique.fn_precision_stock_compatible(NEW."ID_UniteFk",NEW."DecimalesStock");
 NEW."ModifieLe"=clock_timestamp();
 RETURN NEW;
END $function$;
COMMENT ON FUNCTION logistique.tr_precision_stock() IS 'Politique de décimales conservée et protégée par l’historique ; sélection d’unité résolue au catalogue, identité toujours immuable.';

CREATE OR REPLACE FUNCTION logistique.verifier_article_poids()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
 IF NEW."ID_UnitePoidsFk" IS NOT NULL AND NOT EXISTS (
 SELECT 1 FROM referentiel."T_Generique" WHERE "ID_Generique"=NEW."ID_UnitePoidsFk" AND referentiel.fn_reference_champ_connue('logistique','T_Article','ID_UnitePoidsFk',NEW."ID_UnitePoidsFk") AND lower(btrim("AbrGenerique")) IN ('mg','g','kg','t')) THEN
 RAISE EXCEPTION 'Unité de masse requise pour le poids unitaire.' USING ERRCODE='23514';
 END IF;
 RETURN NEW;
END;
$function$;
COMMENT ON FUNCTION logistique.verifier_article_poids() IS 'Unité de poids issue de la famille du champ, avec les codes de masse mg/g/kg/t toujours obligatoires ; aucun poids ni unité historique recalculé.';

CREATE OR REPLACE FUNCTION logistique.controler_propriete_logistique()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog'
AS $function$
DECLARE parent_entity integer; article_entity integer; client_entity integer; parent_tiers bigint;
BEGIN
 IF TG_TABLE_NAME IN('T_Article','T_Commande','T_Client') THEN
  IF NEW."IdEntiteFk" IS NULL THEN RAISE EXCEPTION 'Entreprise propriétaire requise.' USING ERRCODE='23514';END IF;
  IF TG_OP='UPDATE' AND NEW."IdEntiteFk" IS DISTINCT FROM OLD."IdEntiteFk" AND NOT (OLD."IdEntiteFk" IS NULL AND NEW."IdEntiteFk" IS NOT NULL AND current_setting('sauverndeko.owner_assignment',true)='on') THEN RAISE EXCEPTION 'Entreprise propriétaire immuable.' USING ERRCODE='23514';END IF;
 END IF;
 IF TG_TABLE_NAME='T_Client' THEN
  IF TG_OP='UPDATE' AND (NEW."CreeParUserFk" IS DISTINCT FROM OLD."CreeParUserFk" OR NEW."DateCreation" IS DISTINCT FROM OLD."DateCreation") THEN RAISE EXCEPTION 'Auteur et date de création immuables.' USING ERRCODE='23514';END IF;
  IF NEW."IdProfessionnelFk" IS NOT NULL AND NEW."IdUserFk" IS NOT NULL AND NOT EXISTS(SELECT 1 FROM professionnel."T_Professionnel" p WHERE p."IdProfessionnel"=NEW."IdProfessionnelFk" AND p."IdUserFk"=NEW."IdUserFk") THEN RAISE EXCEPTION 'Identités du tiers incompatibles.' USING ERRCODE='23514';END IF;
  IF NEW."ID_TypeClientFk" IS NOT NULL AND NOT EXISTS(SELECT 1 FROM referentiel."T_Generique" g JOIN referentiel."T_CategorieGenerique" c ON c."ID_CategorieGenerique"=g."ID_CategorieGeneriqueFk" WHERE g."ID_Generique"=NEW."ID_TypeClientFk" AND referentiel.fn_reference_champ_connue('logistique','T_Client','ID_TypeClientFk',NEW."ID_TypeClientFk")) THEN RAISE EXCEPTION 'Type de client incompatible.' USING ERRCODE='23514';END IF;
 ELSIF TG_TABLE_NAME='T_Commande' THEN
  IF NEW."ID_TiersFk" IS NOT NULL THEN SELECT "IdEntiteFk" INTO client_entity FROM logistique."T_Client" WHERE "ID_Client"=NEW."ID_TiersFk" FOR SHARE;IF client_entity IS DISTINCT FROM NEW."IdEntiteFk" THEN RAISE EXCEPTION 'Tiers d’une autre entreprise.' USING ERRCODE='23514';END IF;END IF;
 ELSIF TG_TABLE_NAME='T_CommandeDetail' OR TG_TABLE_NAME='T_Mouvement' THEN
  SELECT "IdEntiteFk" INTO article_entity FROM logistique."T_Article" WHERE "ID_Article"=NEW."ID_ArticleFk" FOR SHARE;
  IF TG_TABLE_NAME='T_CommandeDetail' THEN SELECT "IdEntiteFk" INTO parent_entity FROM logistique."T_Commande" WHERE "ID_Commande"=NEW."ID_CmdFk" FOR SHARE;
  ELSIF NEW."ID_cmdFk" IS NOT NULL THEN SELECT "IdEntiteFk" INTO parent_entity FROM logistique."T_Commande" WHERE "ID_Commande"=NEW."ID_cmdFk" FOR SHARE;
  ELSE parent_entity:=article_entity;END IF;
  IF article_entity IS NULL OR article_entity IS DISTINCT FROM parent_entity THEN RAISE EXCEPTION 'Article et bon doivent appartenir à la même entreprise.' USING ERRCODE='23514';END IF;
 ELSIF TG_TABLE_NAME='T_Reglements' THEN
  SELECT "ID_TiersFk" INTO parent_tiers FROM logistique."T_Commande" WHERE "CodeFacture"=NEW."CodeFactureFk" FOR SHARE;
  IF NEW."ID_TiersFk" IS DISTINCT FROM parent_tiers THEN RAISE EXCEPTION 'Le règlement conserve le tiers de sa facture.' USING ERRCODE='23514';END IF;
 END IF;
 RETURN NEW;
END $function$;
COMMENT ON FUNCTION logistique.controler_propriete_logistique() IS 'Propriété durable et cohérence des tiers conservées ; leur famille de référence est déléguée au catalogue commun.';

CREATE OR REPLACE FUNCTION logistique.controler_retour_bon()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog'
AS $function$
DECLARE origine record; entree record; source_entite integer; acteur_entite integer; candidat record; disponible record; lot record; lignes integer;
BEGIN
 IF TG_OP<>'INSERT' THEN RAISE EXCEPTION 'Un retour validé est conservé dans son historique.' USING ERRCODE='23514';END IF;
 SELECT c.*,t."AbrGenerique" AS sens,t."ID_CategorieGeneriqueFk" AS categorie INTO origine
 FROM logistique."T_Commande" c LEFT JOIN referentiel."T_Generique" t ON t."ID_Generique"=c."ID_TypeCmdFk"
 WHERE c."ID_Commande"=NEW."ID_CommandeOrigineFk" FOR UPDATE OF c;
 IF NOT FOUND OR logistique.fn_nature_bon(origine."ID_TypeCmdFk") IS DISTINCT FROM 'sortie' OR origine.sens NOT ILIKE 'sort%' OR origine.sens IS NULL THEN
  RAISE EXCEPTION 'Le retour exige un bon de sortie historique.' USING ERRCODE='23514';END IF;
 SELECT c.*,t."AbrGenerique" AS sens,t."ID_CategorieGeneriqueFk" AS categorie INTO entree
 FROM logistique."T_Commande" c LEFT JOIN referentiel."T_Generique" t ON t."ID_Generique"=c."ID_TypeCmdFk"
 WHERE c."ID_Commande"=NEW."ID_CommandeRetourFk" FOR UPDATE OF c;
 IF NOT FOUND OR logistique.fn_nature_bon(entree."ID_TypeCmdFk") IS DISTINCT FROM 'entree' OR entree.sens NOT ILIKE 'entr%' OR entree.sens IS NULL THEN
  RAISE EXCEPTION 'Le document compensateur doit être un bon d’entrée.' USING ERRCODE='23514';END IF;
 IF EXISTS(SELECT 1 FROM logistique."T_RetourBon" WHERE "ID_CommandeRetourFk"=origine."ID_Commande" OR "ID_CommandeOrigineFk"=entree."ID_Commande") THEN
  RAISE EXCEPTION 'Un retour ne peut pas devenir une nouvelle origine.' USING ERRCODE='23514';END IF;
 SELECT "IdEntiteFk" INTO source_entite FROM logistique."T_Commande" WHERE "ID_Commande"=origine."ID_Commande" FOR SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Organisation source introuvable.' USING ERRCODE='23514';END IF;
 SELECT "IdEntiteFk" INTO acteur_entite FROM systeme."T_Utilisateurs" WHERE "IdUser"=NEW."ID_UserFk" FOR SHARE;
 IF NOT FOUND OR source_entite IS DISTINCT FROM NEW."IdEntiteFk" OR (acteur_entite IS DISTINCT FROM NEW."IdEntiteFk" AND NOT EXISTS(SELECT 1 FROM systeme."T_Utilisateurs" u WHERE u."IdUser"=NEW."ID_UserFk" AND u."Is_Admin" IS TRUE)) OR entree."ID_UserFk" IS DISTINCT FROM NEW."ID_UserFk" THEN
  RAISE EXCEPTION 'Retour et sortie doivent appartenir à la même organisation.' USING ERRCODE='23514';END IF;
 IF origine."ID_DeviseFk" IS NULL OR entree."ID_DeviseFk" IS DISTINCT FROM origine."ID_DeviseFk" THEN
  RAISE EXCEPTION 'La contre-écriture conserve la devise de la sortie.' USING ERRCODE='23514';END IF;
 IF NULLIF(btrim(entree."CodeFacture"),'') IS NOT NULL OR logistique.fn_commande_cloturee(entree."StatusFacture") OR entree."DateCmd" IS DISTINCT FROM NEW."DateRetour" THEN
  RAISE EXCEPTION 'Le bon de retour conserve sa date et ne porte pas de facture.' USING ERRCODE='23514';END IF;
 IF EXISTS(SELECT 1 FROM logistique."V_RetourArticle" WHERE "ID_CommandeOrigineFk"=origine."ID_Commande" AND NOT "SourceCoherente") THEN
  RAISE EXCEPTION 'La sortie doit être rapprochée de ses mouvements avant un retour.' USING ERRCODE='23514';END IF;
 lignes=0;
 FOR candidat IN SELECT d.*,m."ID_Mvt",m."QteMvt",m."PUMvt",m."ID_DeviseFk",m."ID_TypeMvtFk",
   COALESCE((SELECT sum(ml."Quantite") FROM logistique."T_MouvementLot" ml WHERE ml."ID_MvtFk"=m."ID_Mvt"),0) AS lots_qte
   FROM logistique."T_CommandeDetail" d LEFT JOIN logistique."T_Mouvement" m ON m."ID_cmdFk"=d."ID_CmdFk" AND m."ID_ArticleFk"=d."ID_ArticleFk"
   WHERE d."ID_CmdFk"=entree."ID_Commande" ORDER BY d."ID_ArticleFk"
 LOOP
  lignes=lignes+1;
  SELECT * INTO disponible FROM logistique."V_RetourArticle" WHERE "ID_CommandeOrigineFk"=origine."ID_Commande" AND "ID_ArticleFk"=candidat."ID_ArticleFk";
  IF NOT FOUND OR NOT disponible."SourceCoherente" OR candidat."QteCmdDetail" IS NULL OR candidat."QteCmdDetail"<=0 OR candidat."QteCmdDetail">disponible."QteRestante" THEN
   RAISE EXCEPTION 'La quantité rendue dépasse la sortie restante.' USING ERRCODE='23514';END IF;
  IF candidat."PUCmdDetail" IS DISTINCT FROM disponible."PUHistorique" OR candidat."PUMvt" IS DISTINCT FROM disponible."PUHistorique" OR candidat."QteMvt" IS DISTINCT FROM candidat."QteCmdDetail" OR candidat."ID_DeviseFk" IS DISTINCT FROM origine."ID_DeviseFk" OR candidat."ID_TypeMvtFk" IS DISTINCT FROM entree."ID_TypeCmdFk" THEN
   RAISE EXCEPTION 'La contre-écriture conserve le prix, la devise et la quantité historiques.' USING ERRCODE='23514';END IF;
  IF candidat.lots_qte>candidat."QteCmdDetail" OR candidat."QteCmdDetail"-candidat.lots_qte>disponible."QteSansLotRestante" THEN
   RAISE EXCEPTION 'La quantité sans lot dépasse la quantité sortie sans lot.' USING ERRCODE='23514';END IF;
  FOR lot IN SELECT ml."ID_LotArticleFk",ml."Quantite" FROM logistique."T_MouvementLot" ml WHERE ml."ID_MvtFk"=candidat."ID_Mvt"
  LOOP
   IF NOT EXISTS(SELECT 1 FROM logistique."V_RetourLot" rl WHERE rl."ID_CommandeOrigineFk"=origine."ID_Commande" AND rl."ID_ArticleFk"=candidat."ID_ArticleFk" AND rl."ID_LotArticle"=lot."ID_LotArticleFk" AND rl."QteRestante">=lot."Quantite") THEN
    RAISE EXCEPTION 'La quantité ou le lot ne provient pas de la sortie restante.' USING ERRCODE='23514';END IF;
  END LOOP;
 END LOOP;
 IF lignes=0 OR EXISTS(SELECT 1 FROM logistique."T_Mouvement" m WHERE m."ID_cmdFk"=entree."ID_Commande" AND NOT EXISTS(SELECT 1 FROM logistique."T_CommandeDetail" d WHERE d."ID_CmdFk"=m."ID_cmdFk" AND d."ID_ArticleFk"=m."ID_ArticleFk")) THEN
  RAISE EXCEPTION 'Un retour exige ses lignes et leurs seuls mouvements source.' USING ERRCODE='23514';END IF;
 IF entree."MontantHT" IS DISTINCT FROM (SELECT sum(round("QteCmdDetail"*"PUCmdDetail",2)) FROM logistique."T_CommandeDetail" WHERE "ID_CmdFk"=entree."ID_Commande") OR entree."MontantTTC" IS DISTINCT FROM entree."MontantHT" THEN
  RAISE EXCEPTION 'La valeur du retour doit correspondre à ses quantités et prix historiques.' USING ERRCODE='23514';END IF;
 NEW."CreeLe"=clock_timestamp();
 NEW."Motif"=btrim(NEW."Motif");
 RETURN NEW;
END;
$function$;
COMMENT ON FUNCTION logistique.controler_retour_bon() IS 'Restitution conservée par document de sortie et entrée compensatrice, types déclarés ou historiques au lieu d’une constante de famille ; aucun mouvement ou montant antérieur modifié.';

CREATE OR REPLACE FUNCTION logistique.fn_materialiser_stock_initial(p_article integer, p_mouvement integer DEFAULT NULL::integer)
 RETURNS integer
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog'
AS $function$
DECLARE a record;m logistique."T_Mouvement"%ROWTYPE;num record;kind integer;command_id integer;qty numeric;price numeric;business_date timestamp;origin text;prior_article text:=coalesce(current_setting('logistique.stock_initial_article',true),'');prior_movement text:=coalesce(current_setting('logistique.stock_initial_mouvement',true),'');
BEGIN
 SELECT * INTO a FROM logistique."T_Article" WHERE "ID_Article"=p_article FOR NO KEY UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Article absent.' USING ERRCODE='23503';END IF;
 IF p_mouvement IS NULL THEN
  SELECT "ID_Commande" INTO command_id FROM logistique."T_Commande" WHERE "ID_ArticleInitialFk"=p_article AND "OrigineBon"='stock_initial';
  IF FOUND THEN RETURN command_id;END IF;
  qty=a."QteArticle";price=a."PUArticle";business_date=coalesce(a."DateHeureAuto"::timestamp,clock_timestamp()::timestamp);origin='stock_initial';
  IF coalesce(qty,0)=0 THEN RETURN NULL;END IF;
  IF EXISTS(SELECT FROM logistique."T_Mouvement" WHERE "ID_ArticleFk"=p_article) THEN RAISE EXCEPTION 'Stock deja historise: rapprochez les mouvements existants.' USING ERRCODE='23514';END IF;
  SELECT g."ID_Generique" INTO kind FROM referentiel."T_Generique" g JOIN referentiel."T_CategorieGenerique" c ON c."ID_CategorieGenerique"=g."ID_CategorieGeneriqueFk" WHERE g."ID_CategorieGeneriqueFk"=ANY(referentiel.fn_categories_champ('logistique','T_Commande','ID_TypeCmdFk',a."IdEntiteFk")) AND g."AbrGenerique" ILIKE 'entr%' AND g."ValideGenerique" IS TRUE AND c."ValideCategorieGenerique" IS TRUE ORDER BY g."ID_Generique" LIMIT 1;
 ELSE
  SELECT * INTO m FROM logistique."T_Mouvement" WHERE "ID_Mvt"=p_mouvement AND "ID_ArticleFk"=p_article FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Mouvement absent.' USING ERRCODE='23503';END IF;
  IF m."ID_cmdFk" IS NOT NULL THEN RETURN m."ID_cmdFk";END IF;
  qty=m."QteMvt";price=m."PUMvt";business_date=m."DateMvt";kind=m."ID_TypeMvtFk";origin='reprise_mouvement';
 END IF;
 IF qty IS NULL OR qty<=0 OR price IS NULL OR price<0 OR kind IS NULL THEN RAISE EXCEPTION 'Quantite, prix d achat et type requis pour le stock initial.' USING ERRCODE='23514';END IF;
 PERFORM set_config('logistique.stock_initial_article',p_article::text,true);
 PERFORM set_config('logistique.stock_initial_mouvement',coalesce(p_mouvement::text,''),true);
 SELECT * INTO num FROM logistique.fn_reserver_identite_commande();
 INSERT INTO logistique."T_Commande"("ID_Commande","ID_TypeCmdFk","ID_UserFk","IdEntiteFk","ID_DeviseFk","DateCmd","DateHeureAutoCmd","RefCmd","ObsCmd","OrigineBon","ID_ArticleInitialFk")
 VALUES(num."ID_Commande",kind,CASE WHEN p_mouvement IS NULL THEN a."ID_UserFK" END,a."IdEntiteFk",coalesce(m."ID_DeviseFk",a."ID_DeviseFk"),business_date,clock_timestamp(),CASE WHEN p_mouvement IS NULL THEN 'Création depuis Articles / Stock initial' ELSE 'Reprise mouvement historique / '||p_mouvement::text END,CASE WHEN p_mouvement IS NULL THEN 'Création depuis Articles / Stock initial' ELSE 'Rattachement documentaire sans variation de stock. Auteur historique non prouvé; dates, prix et mouvement conservés.' END,origin,p_article)
 RETURNING "ID_Commande" INTO command_id;
 INSERT INTO logistique."T_CommandeDetail"("ID_CmdFk","ID_ArticleFk","QteCmdDetail","PUCmdDetail","ObsCmdDetail") VALUES(command_id,p_article,qty,price,CASE WHEN p_mouvement IS NULL THEN 'Stock initial de la fiche article' ELSE 'Mouvement historique conservé #'||p_mouvement::text END);
 INSERT INTO systeme."T_Audit_Log"("TableName","Operation","NewData","IdEntiteFk") VALUES('logistique.T_Commande',CASE WHEN p_mouvement IS NULL THEN 'INITIAL_STOCK_DOCUMENT' ELSE 'HISTORICAL_STOCK_DOCUMENT' END,jsonb_build_object('ID_Commande',command_id,'ID_Article',p_article,'ID_Mvt',coalesce(p_mouvement,(SELECT "ID_Mvt" FROM logistique."T_Mouvement" WHERE "ID_cmdFk"=command_id AND "ID_ArticleFk"=p_article)),'OrigineBon',origin,'AuteurOrigineProuve',p_mouvement IS NULL),a."IdEntiteFk");
 PERFORM set_config('logistique.stock_initial_article',prior_article,true);
 PERFORM set_config('logistique.stock_initial_mouvement',prior_movement,true);
 RETURN command_id;
END $function$;
COMMENT ON FUNCTION logistique.fn_materialiser_stock_initial(p_article integer, p_mouvement integer) IS 'Stock initial positif matérialisé une seule fois par BE, ligne et mouvement ; type d’entrée actif résolu dans la famille de commande effective de son entreprise. Reprise historique inchangée.';

CREATE OR REPLACE FUNCTION logistique.tr_reglement_apres_avoir()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog'
AS $function$
DECLARE code text; parent logistique."T_Commande"%ROWTYPE; invoice numeric; credit numeric; paid numeric; old_total numeric;
BEGIN
 IF TG_OP='UPDATE' AND (NEW."CodeFactureFk" IS DISTINCT FROM OLD."CodeFactureFk"
   OR NEW."ID_DeviseFk" IS DISTINCT FROM OLD."ID_DeviseFk"
   OR NEW."ID_TiersFk" IS DISTINCT FROM OLD."ID_TiersFk"
   OR NEW."ID_ClientFk" IS DISTINCT FROM OLD."ID_ClientFk") THEN
  RAISE EXCEPTION 'La facture, sa devise et le tiers du reglement sont immuables.' USING ERRCODE='23514';
 END IF;
 code:=CASE WHEN TG_OP='DELETE' THEN OLD."CodeFactureFk" ELSE NEW."CodeFactureFk" END;
 SELECT * INTO parent FROM logistique."T_Commande" WHERE "CodeFacture"=code FOR UPDATE;
 IF NOT FOUND OR nullif(btrim(code),'') IS NULL THEN
  RAISE EXCEPTION 'Le reglement doit etre rattache a une facture existante.' USING ERRCODE='23514';
 END IF;
 IF logistique.fn_commande_cloturee(parent."StatusFacture") THEN
  RAISE EXCEPTION 'Cette facture est cloturee ; ses reglements sont conserves.' USING ERRCODE='23514';
 END IF;
 IF TG_OP IN ('UPDATE','DELETE') AND (EXISTS(SELECT 1 FROM logistique."T_Avoir" WHERE "ID_CommandeFk"=parent."ID_Commande")
  OR EXISTS(SELECT 1 FROM logistique."T_AvoirAffectation" WHERE "ID_CommandeCibleFk"=parent."ID_Commande")) THEN
  RAISE EXCEPTION 'Un avoir existe : le reglement doit etre conserve.' USING ERRCODE='23514';
 END IF;
 IF TG_OP='DELETE' THEN RETURN OLD; END IF;
 IF NEW."MontantRegle" IS NULL OR NEW."MontantRegle"<=0 OR NEW."DateReglement" IS NULL THEN
  RAISE EXCEPTION 'Renseignez une date et un montant de reglement strictement positif.' USING ERRCODE='23514';
 END IF;
 IF TG_OP='INSERT' THEN
  IF NEW."ID_TiersFk" IS DISTINCT FROM parent."ID_TiersFk" OR NEW."ID_ClientFk" IS DISTINCT FROM parent."ID_ClientFk" THEN
   RAISE EXCEPTION 'Le tiers du reglement doit correspondre a celui de la facture.' USING ERRCODE='23514';
  END IF;
 END IF;
 IF TG_OP='INSERT' OR NEW."ID_ModeReglementFk" IS DISTINCT FROM OLD."ID_ModeReglementFk" THEN
  PERFORM 1 FROM referentiel."T_Generique" g JOIN referentiel."T_CategorieGenerique" c
   ON c."ID_CategorieGenerique"=g."ID_CategorieGeneriqueFk"
   WHERE g."ID_Generique"=NEW."ID_ModeReglementFk" AND referentiel.fn_reference_champ_connue('logistique','T_Reglements','ID_ModeReglementFk',NEW."ID_ModeReglementFk")
     AND g."ValideGenerique" IS TRUE AND c."ValideCategorieGenerique" IS TRUE FOR SHARE OF g,c;
  IF NOT FOUND THEN RAISE EXCEPTION 'Mode de reglement indisponible.' USING ERRCODE='23514'; END IF;
 END IF;
 SELECT coalesce(f."MontantTTC",parent."MontantTTC") INTO invoice
  FROM (SELECT 1) source LEFT JOIN logistique."T_Facture" f ON f."ID_CommandeFk"=parent."ID_Commande";
 IF invoice IS NULL THEN RAISE EXCEPTION 'Le montant de cette facture doit etre verifie.' USING ERRCODE='23514'; END IF;
 SELECT coalesce(sum("Montant"),0) INTO credit FROM logistique."T_AvoirAffectation" WHERE "ID_CommandeCibleFk"=parent."ID_Commande";
 SELECT coalesce(sum("MontantRegle"),0) INTO paid FROM logistique."T_Reglements"
  WHERE "CodeFactureFk"=code AND (TG_OP='INSERT' OR "ID_Reglement"<>NEW."ID_Reglement");
 old_total:=paid+CASE WHEN TG_OP='UPDATE' THEN coalesce(OLD."MontantRegle",0) ELSE 0 END;
 IF paid+NEW."MontantRegle">invoice-credit AND NOT (TG_OP='UPDATE' AND old_total>invoice-credit AND paid+NEW."MontantRegle"<old_total) THEN
  RAISE EXCEPTION 'Le reglement depasse le solde net. Un excedent historique peut seulement etre reduit.' USING ERRCODE='23514';
 END IF;
 RETURN NEW;
END $function$;
COMMENT ON FUNCTION logistique.tr_reglement_apres_avoir() IS 'Protections du règlement conservées : valeur active, solde après avoir et dates ; famille du mode déléguée au référencement physique.';

CREATE OR REPLACE FUNCTION logistique.fn_devise_usd()
 RETURNS integer
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'pg_catalog'
AS $function$
DECLARE identifiant integer; nombre bigint;
BEGIN
 SELECT min(g."ID_Generique"),count(*) INTO identifiant,nombre
 FROM referentiel."T_Generique" g JOIN referentiel."T_CategorieGenerique" c
  ON c."ID_CategorieGenerique"=g."ID_CategorieGeneriqueFk"
 WHERE g."ID_CategorieGeneriqueFk"=ANY(referentiel.fn_categories_champ('logistique','T_Article','ID_DeviseFk',NULL))
   AND c."ValideCategorieGenerique" IS TRUE AND g."ValideGenerique" IS TRUE
   AND logistique.fn_code_devise(g."AbrGenerique")='USD';
 IF nombre<>1 THEN
  RAISE EXCEPTION 'Une seule devise USD active est requise dans la catégorie Devise active (trouvées : %).',nombre USING ERRCODE='23514';
 END IF;
 RETURN identifiant;
END;
$function$;
COMMENT ON FUNCTION logistique.fn_devise_usd() IS 'Défaut USD global résolu dans la catégorie courante du champ devise Article ; exige une seule valeur USD active et conserve son code ISO. Les choix d’entreprise sont explicitement transmis par les services.';

CREATE OR REPLACE FUNCTION operations.gestion_caisse_on_paiement()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
DECLARE
    -- Deltas à appliquer sur la caisse
    v_delta_old NUMERIC := 0;
    v_delta_new NUMERIC := 0;

    -- Variables de travail
    v_sign       INTEGER;
    v_is_paid    BOOLEAN;
    v_is_devise  BOOLEAN;
BEGIN
    --------------------------------------------------------------------
    -- 1) TRAITEMENT DE L'ANCIEN ENREGISTREMENT (OLD) → DELETE / UPDATE
    --------------------------------------------------------------------
    IF TG_OP IN ('UPDATE', 'DELETE') THEN
        v_delta_old := 0;
        v_sign      := 0;
        v_is_paid   := FALSE;
        v_is_devise := FALSE;

        -- a) Statut paiement = 'Payé(e)' dans catégorie 'Statut paiement' ?
        IF OLD."IdStatutPaiementFk" IS NOT NULL THEN
            SELECT
                ( lower(cg."NomCategorieGenerique") = 'statut paiement'
                  AND trim(g."NomGenerique") = 'Payé(e)' )
            INTO v_is_paid
            FROM referentiel."T_Generique" g
            JOIN referentiel."T_CategorieGenerique" cg
              ON cg."ID_CategorieGenerique" = g."ID_CategorieGeneriqueFk"
            WHERE g."ID_Generique" = OLD."IdStatutPaiementFk";
        END IF;

        -- b) Devise appartenant à la catégorie 'Devise' ?
        IF OLD."IdDeviseFk" IS NOT NULL THEN
            SELECT
                ( referentiel.fn_reference_champ_connue('operations','T_Paiement','IdDeviseFk',g."ID_Generique") )
            INTO v_is_devise
            FROM referentiel."T_Generique" g
            JOIN referentiel."T_CategorieGenerique" cg
              ON cg."ID_CategorieGenerique" = g."ID_CategorieGeneriqueFk"
            WHERE g."ID_Generique" = OLD."IdDeviseFk";
        END IF;

        -- c) Type mouvement paiement : 'Entrée' / 'Sortie' ?
        IF OLD."IdTypeMouvementFk" IS NOT NULL THEN
            SELECT
                CASE
                    WHEN lower(cg."NomCategorieGenerique") = 'type mouvement paiement'
                         AND g."NomGenerique" ILIKE 'entr%' THEN  1   -- Entrée
                    WHEN lower(cg."NomCategorieGenerique") = 'type mouvement paiement'
                         AND g."NomGenerique" ILIKE 'sort%' THEN -1   -- Sortie
                    ELSE 0
                END
            INTO v_sign
            FROM referentiel."T_Generique" g
            JOIN referentiel."T_CategorieGenerique" cg
              ON cg."ID_CategorieGenerique" = g."ID_CategorieGeneriqueFk"
            WHERE g."ID_Generique" = OLD."IdTypeMouvementFk";
        END IF;

        -- d) Calcul de l'effet OLD sur la caisse (qu'on doit annuler)
        IF OLD."ValidePaiement" IS TRUE
           AND v_is_paid
           AND v_is_devise
           AND v_sign <> 0
           AND OLD."IdEntiteFk" IS NOT NULL
        THEN
            -- Pour un DELETE ou la "sortie" de l'ancien état :
            -- delta_old = - (signe * MontantPaiement)
            v_delta_old := - v_sign * OLD."MontantPaiement";

            -- Appliquer delta_old à la caisse correspondante
            INSERT INTO operations."T_Caisse" AS c (
                "IdEntiteFk", "IdDeviseFk", "MontantCaisse"
            )
            VALUES (
                OLD."IdEntiteFk",
                OLD."IdDeviseFk",
                v_delta_old
            )
            ON CONFLICT ("IdEntiteFk", "IdDeviseFk")
            DO UPDATE
            SET "MontantCaisse" = c."MontantCaisse" + EXCLUDED."MontantCaisse";
        END IF;
    END IF;

    --------------------------------------------------------------------
    -- 2) TRAITEMENT DU NOUVEL ENREGISTREMENT (NEW) → INSERT / UPDATE
    --------------------------------------------------------------------
    IF TG_OP IN ('INSERT', 'UPDATE') THEN
        v_delta_new := 0;
        v_sign      := 0;
        v_is_paid   := FALSE;
        v_is_devise := FALSE;

        -- a) Statut paiement = 'Payé(e)' ?
        IF NEW."IdStatutPaiementFk" IS NOT NULL THEN
            SELECT
                ( lower(cg."NomCategorieGenerique") = 'statut paiement'
                  AND trim(g."NomGenerique") = 'Payé(e)' )
            INTO v_is_paid
            FROM referentiel."T_Generique" g
            JOIN referentiel."T_CategorieGenerique" cg
              ON cg."ID_CategorieGenerique" = g."ID_CategorieGeneriqueFk"
            WHERE g."ID_Generique" = NEW."IdStatutPaiementFk";
        END IF;

        -- b) Devise appartenant à la catégorie 'Devise' ?
        IF NEW."IdDeviseFk" IS NOT NULL THEN
            SELECT
                ( referentiel.fn_reference_champ_connue('operations','T_Paiement','IdDeviseFk',g."ID_Generique") )
            INTO v_is_devise
            FROM referentiel."T_Generique" g
            JOIN referentiel."T_CategorieGenerique" cg
              ON cg."ID_CategorieGenerique" = g."ID_CategorieGeneriqueFk"
            WHERE g."ID_Generique" = NEW."IdDeviseFk";
        END IF;

        -- c) Type mouvement : 'Entrée' / 'Sortie' ?
        IF NEW."IdTypeMouvementFk" IS NOT NULL THEN
            SELECT
                CASE
                    WHEN lower(cg."NomCategorieGenerique") = 'type mouvement paiement'
                         AND g."NomGenerique" ILIKE 'entr%' THEN  1
                    WHEN lower(cg."NomCategorieGenerique") = 'type mouvement paiement'
                         AND g."NomGenerique" ILIKE 'sort%' THEN -1
                    ELSE 0
                END
            INTO v_sign
            FROM referentiel."T_Generique" g
            JOIN referentiel."T_CategorieGenerique" cg
              ON cg."ID_CategorieGenerique" = g."ID_CategorieGeneriqueFk"
            WHERE g."ID_Generique" = NEW."IdTypeMouvementFk";
        END IF;

        -- d) Calcul de l'effet NEW sur la caisse
        IF NEW."ValidePaiement" IS TRUE
           AND v_is_paid
           AND v_is_devise
           AND v_sign <> 0
           AND NEW."IdEntiteFk" IS NOT NULL
        THEN
            -- Pour un INSERT ou la "nouvelle" version en UPDATE :
            -- delta_new = signe * MontantPaiement
            v_delta_new := v_sign * NEW."MontantPaiement";

            -- Appliquer delta_new à la caisse correspondante
            INSERT INTO operations."T_Caisse" AS c (
                "IdEntiteFk", "IdDeviseFk", "MontantCaisse"
            )
            VALUES (
                NEW."IdEntiteFk",
                NEW."IdDeviseFk",
                v_delta_new
            )
            ON CONFLICT ("IdEntiteFk", "IdDeviseFk")
            DO UPDATE
            SET "MontantCaisse" = c."MontantCaisse" + EXCLUDED."MontantCaisse";
        END IF;
    END IF;

    -- 3) Retour standard pour un trigger AFTER ROW
    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$function$;
COMMENT ON FUNCTION operations.gestion_caisse_on_paiement() IS 'Gestion de caisse existante conservée ; contrôle de devise délégué au catalogue de la vraie FK, sans modifier les règles de statut, de sens ou les écritures antérieures.';

CREATE OR REPLACE VIEW logistique."V_PrecisionStock" AS  SELECT p."ID_PrecisionStock",
    g."ID_Generique" AS "ID_UniteFk",
    g."NomGenerique" AS "Unite",
    g."AbrGenerique" AS "Abreviation",
    COALESCE(p."DecimalesStock"::integer, 0)::smallint AS "DecimalesStock",
    p."ModifieLe",
    g."ValideGenerique" AS "ValideUnite"
   FROM referentiel."T_Generique" g
     LEFT JOIN logistique."T_PrecisionStock" p ON p."ID_UniteFk" = g."ID_Generique"
  WHERE (referentiel.fn_reference_champ_connue('logistique','T_Article','ID_UniteFk',g."ID_Generique") OR referentiel.fn_reference_champ_connue('logistique','T_PrecisionStock','ID_UniteFk',g."ID_Generique"));;
COMMENT ON VIEW logistique."V_PrecisionStock" IS 'Précision des unités déclarées ou utilisées ; défaut explicite zéro décimale, paramètres historiques conservés et aucune quantité transformée.';

CREATE OR REPLACE PROCEDURE logistique.ps_crud_commandedetail(IN p_old_cmd_fk integer, IN p_old_article_fk integer, IN p_old_qte numeric, IN p_old_pu numeric, IN p_new_cmd_fk integer, IN p_new_article_fk integer, IN p_new_qte numeric, IN p_new_pu numeric, IN p_operation character varying)
 LANGUAGE plpgsql
AS $procedure$
DECLARE
 op text := upper(btrim(p_operation)); old_type integer; new_type integer;
 old_abr text; new_abr text; old_sign integer := 0; new_sign integer := 0;
 item record; touched integer;
 prior_skip text := coalesce(current_setting('logistique.skip_article_report_mvt',true),'off');
 prior_write text := coalesce(current_setting('logistique.allow_t_mouvement_write',true),'off');
BEGIN

 IF op='INSERT' AND EXISTS(SELECT FROM logistique."T_Commande" c WHERE c."ID_Commande"=p_new_cmd_fk AND c."OrigineBon" IN ('stock_initial','reprise_mouvement')) THEN
  IF current_setting('logistique.stock_initial_article',true) IS DISTINCT FROM p_new_article_fk::text THEN RAISE EXCEPTION 'Creation de stock initial hors procedure.' USING ERRCODE='23514';END IF;
  SELECT c."ID_TypeCmdFk",g."AbrGenerique" INTO new_type,new_abr FROM logistique."T_Commande" c JOIN referentiel."T_Generique" g ON g."ID_Generique"=c."ID_TypeCmdFk" WHERE c."ID_Commande"=p_new_cmd_fk AND c."ID_ArticleInitialFk"=p_new_article_fk;
  IF new_type IS NULL OR p_new_qte<=0 OR p_new_pu<0 THEN RAISE EXCEPTION 'Stock initial invalide.' USING ERRCODE='23514';END IF;
  PERFORM set_config('logistique.allow_t_mouvement_write','on',true);
  IF nullif(current_setting('logistique.stock_initial_mouvement',true),'') IS NOT NULL THEN
   UPDATE logistique."T_Mouvement" SET "ID_cmdFk"=p_new_cmd_fk WHERE "ID_Mvt"=current_setting('logistique.stock_initial_mouvement')::integer AND "ID_cmdFk" IS NULL AND "ID_ArticleFk"=p_new_article_fk AND "ID_TypeMvtFk"=new_type AND "QteMvt"=p_new_qte AND "PUMvt" IS NOT DISTINCT FROM p_new_pu;
   GET DIAGNOSTICS touched=ROW_COUNT;
   IF touched<>1 THEN RAISE EXCEPTION 'Mouvement historique modifie ou deja rattache.' USING ERRCODE='23514';END IF;
  ELSE
   INSERT INTO logistique."T_Mouvement"("ID_TypeMvtFk","ID_ArticleFk","ID_cmdFk","DateHeureAutoMvt","DateMvt","QteMvt","PUMvt") SELECT new_type,p_new_article_fk,p_new_cmd_fk,clock_timestamp(),c."DateCmd",p_new_qte,p_new_pu FROM logistique."T_Commande" c WHERE c."ID_Commande"=p_new_cmd_fk;
  END IF;
  PERFORM set_config('logistique.allow_t_mouvement_write',prior_write,true);
  RETURN;
 END IF;

 IF op NOT IN ('INSERT','UPDATE','DELETE') OR op IS NULL THEN
  RAISE EXCEPTION 'Opération de ligne inconnue.' USING ERRCODE='23514';
 END IF;
 -- Le cas neutre est explicite ; l'absence de mouvement ne prouve jamais un CMD.
 IF op IN ('INSERT','UPDATE') AND logistique.fn_nature_bon((SELECT c."ID_TypeCmdFk" FROM logistique."T_Commande" c WHERE c."ID_Commande"=p_new_cmd_fk))='commande' THEN
  IF p_new_qte IS NULL OR p_new_qte<=0 OR p_new_pu IS NULL OR p_new_pu<0 THEN RAISE EXCEPTION 'Quantité positive et prix convenu non négatif requis.' USING ERRCODE='23514';END IF;
  IF op='UPDATE' AND logistique.fn_nature_bon((SELECT c."ID_TypeCmdFk" FROM logistique."T_Commande" c WHERE c."ID_Commande"=p_old_cmd_fk)) IS DISTINCT FROM 'commande' THEN RAISE EXCEPTION 'Déplacement entre commande et opération physique interdit.' USING ERRCODE='23514';END IF;
  IF EXISTS(SELECT FROM logistique."T_Mouvement" m WHERE m."ID_cmdFk"=ANY(ARRAY[p_old_cmd_fk,p_new_cmd_fk])) THEN RAISE EXCEPTION 'Un bon de commande ne doit avoir aucun mouvement.' USING ERRCODE='23514';END IF;
  PERFORM 1 FROM logistique."T_Article" a WHERE a."ID_Article"=ANY(ARRAY[p_old_article_fk,p_new_article_fk]) ORDER BY a."ID_Article" FOR NO KEY UPDATE;
  IF NOT EXISTS(SELECT FROM logistique."T_Article" a WHERE a."ID_Article"=p_new_article_fk AND a."ValideArticle" IS TRUE) THEN RAISE EXCEPTION 'Article absent ou désactivé.' USING ERRCODE='23514';END IF;
  RETURN;
 END IF;
 IF op IN ('UPDATE','DELETE') AND logistique.fn_nature_bon((SELECT c."ID_TypeCmdFk" FROM logistique."T_Commande" c WHERE c."ID_Commande"=p_old_cmd_fk))='commande' THEN
  IF op='UPDATE' THEN RAISE EXCEPTION 'Déplacement entre commande et opération physique interdit.' USING ERRCODE='23514';END IF;
  IF EXISTS(SELECT FROM logistique."T_Mouvement" m WHERE m."ID_cmdFk"=p_old_cmd_fk) THEN RAISE EXCEPTION 'Un bon de commande ne doit avoir aucun mouvement.' USING ERRCODE='23514';END IF;
  PERFORM 1 FROM logistique."T_Article" a WHERE a."ID_Article"=p_old_article_fk FOR NO KEY UPDATE;
  RETURN;
 END IF;
 IF op IN ('UPDATE','DELETE') THEN
  IF p_old_qte IS NULL OR p_old_qte<=0 THEN
   RAISE EXCEPTION 'Ancienne quantité de ligne invalide.' USING ERRCODE='23514';
  END IF;
  SELECT c."ID_TypeCmdFk",g."AbrGenerique" INTO old_type,old_abr
  FROM logistique."T_Commande" c JOIN referentiel."T_Generique" g ON g."ID_Generique"=c."ID_TypeCmdFk" AND (referentiel.fn_reference_champ_connue('logistique','T_Mouvement','ID_TypeMvtFk',g."ID_Generique") OR referentiel.fn_reference_champ_connue('logistique','T_Commande','ID_TypeCmdFk',g."ID_Generique"))
  WHERE c."ID_Commande"=p_old_cmd_fk;
  IF NOT FOUND THEN
   SELECT m."ID_TypeMvtFk",g."AbrGenerique" INTO old_type,old_abr
   FROM logistique."T_Mouvement" m JOIN referentiel."T_Generique" g ON g."ID_Generique"=m."ID_TypeMvtFk" AND (referentiel.fn_reference_champ_connue('logistique','T_Mouvement','ID_TypeMvtFk',g."ID_Generique") OR referentiel.fn_reference_champ_connue('logistique','T_Commande','ID_TypeCmdFk',g."ID_Generique"))
   WHERE m."ID_cmdFk"=p_old_cmd_fk AND m."ID_ArticleFk"=p_old_article_fk;
  END IF;
  old_sign := CASE WHEN old_abr ILIKE 'entr%' THEN 1 WHEN old_abr ILIKE 'sort%' THEN -1 ELSE 0 END;
  IF old_sign=0 THEN RAISE EXCEPTION 'Ancien type de mouvement inconnu.' USING ERRCODE='23514'; END IF;
 END IF;
 IF op IN ('INSERT','UPDATE') THEN
  IF p_new_qte IS NULL OR p_new_qte<=0 OR p_new_pu<0 THEN
   RAISE EXCEPTION 'Quantité entière positive et prix non négatif requis.' USING ERRCODE='23514';
  END IF;
  SELECT c."ID_TypeCmdFk",g."AbrGenerique" INTO new_type,new_abr
  FROM logistique."T_Commande" c JOIN referentiel."T_Generique" g ON g."ID_Generique"=c."ID_TypeCmdFk" AND (referentiel.fn_reference_champ_connue('logistique','T_Mouvement','ID_TypeMvtFk',g."ID_Generique") OR referentiel.fn_reference_champ_connue('logistique','T_Commande','ID_TypeCmdFk',g."ID_Generique"))
  WHERE c."ID_Commande"=p_new_cmd_fk;
  new_sign := CASE WHEN new_abr ILIKE 'entr%' THEN 1 WHEN new_abr ILIKE 'sort%' THEN -1 ELSE 0 END;
  IF new_sign=0 THEN RAISE EXCEPTION 'Nouveau type de mouvement inconnu.' USING ERRCODE='23514'; END IF;
 END IF;
 -- Une quantité modifiée applique le delta net : aucun stock négatif intermédiaire artificiel.
 PERFORM 1 FROM logistique."T_Article" a
 WHERE a."ID_Article"=ANY(ARRAY[p_old_article_fk,p_new_article_fk])
 ORDER BY a."ID_Article" FOR NO KEY UPDATE;
 PERFORM set_config('logistique.skip_article_report_mvt','on',true);
 FOR item IN
  SELECT id,sum(delta) delta FROM (VALUES
   (p_old_article_fk,CASE WHEN op IN ('UPDATE','DELETE') THEN -old_sign*p_old_qte ELSE 0 END),
   (p_new_article_fk,CASE WHEN op IN ('INSERT','UPDATE') THEN new_sign*p_new_qte ELSE 0 END)
  ) x(id,delta) WHERE id IS NOT NULL GROUP BY id ORDER BY id
 LOOP
  IF item.delta<>0 THEN
   CALL logistique.ps_update_qte_article(item.id,abs(item.delta),CASE WHEN item.delta>0 THEN '+' ELSE '-' END);
  END IF;
 END LOOP;
 PERFORM set_config('logistique.skip_article_report_mvt',prior_skip,true);
 PERFORM set_config('logistique.allow_t_mouvement_write','on',true);
 IF op='UPDATE' AND p_old_cmd_fk=p_new_cmd_fk AND p_old_article_fk=p_new_article_fk THEN
  IF p_old_qte IS DISTINCT FROM p_new_qte OR p_old_pu IS DISTINCT FROM p_new_pu THEN
   UPDATE logistique."T_Mouvement" SET "QteMvt"=p_new_qte,"PUMvt"=coalesce(p_new_pu,0),"ID_TypeMvtFk"=new_type
   WHERE "ID_cmdFk"=p_old_cmd_fk AND "ID_ArticleFk"=p_old_article_fk;
   GET DIAGNOSTICS touched=ROW_COUNT;
   IF touched<>1 THEN RAISE EXCEPTION 'La ligne doit posséder exactement un mouvement source.' USING ERRCODE='23514'; END IF;
  END IF;
 ELSE
  IF op IN ('UPDATE','DELETE') THEN
   DELETE FROM logistique."T_Mouvement" WHERE "ID_cmdFk"=p_old_cmd_fk AND "ID_ArticleFk"=p_old_article_fk;
   GET DIAGNOSTICS touched=ROW_COUNT;
   IF touched<>1 THEN RAISE EXCEPTION 'Mouvement source absent ou dupliqué.' USING ERRCODE='23514'; END IF;
  END IF;
  IF op IN ('INSERT','UPDATE') THEN
   INSERT INTO logistique."T_Mouvement"("ID_TypeMvtFk","ID_ArticleFk","ID_cmdFk","DateHeureAutoMvt","DateMvt","QteMvt","PUMvt")
   VALUES(new_type,p_new_article_fk,p_new_cmd_fk,now(),now(),p_new_qte,coalesce(p_new_pu,0));
  END IF;
 END IF;
 PERFORM set_config('logistique.allow_t_mouvement_write',prior_write,true);
END;
$procedure$;

CREATE OR REPLACE FUNCTION logistique.tr_proteger_unite_precision_stock()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
 IF TG_OP='UPDATE' AND NEW."ID_Generique"=OLD."ID_Generique" AND NEW."ID_CategorieGeneriqueFk"=OLD."ID_CategorieGeneriqueFk" THEN RETURN NEW;END IF;
 IF
 (EXISTS(SELECT FROM logistique."T_PrecisionStock" WHERE "ID_UniteFk"=OLD."ID_Generique")
 OR EXISTS(SELECT FROM logistique."T_Article" WHERE "ID_UniteFk"=OLD."ID_Generique")) THEN
  RAISE EXCEPTION 'La catégorie et l’identité d’une unité utilisée sont conservées' USING ERRCODE='23514';
 END IF;
 IF TG_OP='DELETE' THEN RETURN OLD;END IF;
 RETURN NEW;
END $function$;

INSERT INTO referentiel."T_InterfaceTableau"("CleInterface","Module","Version","Colonnes") VALUES ('referentiels.champs','referentiels',1,'[{"id": "SchemaName", "label": "Schéma", "type": "text", "defaultVisible": true, "defaultOrder": 0, "defaultExportOrder": 0, "defaultExport": true, "exportable": true, "tableAvailable": true}, {"id": "TableName", "label": "Table", "type": "text", "defaultVisible": true, "defaultOrder": 1, "defaultExportOrder": 1, "defaultExport": true, "exportable": true, "tableAvailable": true}, {"id": "ColumnName", "label": "Colonne", "type": "text", "defaultVisible": true, "defaultOrder": 2, "defaultExportOrder": 2, "defaultExport": true, "exportable": true, "tableAvailable": true}, {"id": "CategoryIds", "label": "ID catégorie", "type": "integer[]", "defaultVisible": true, "defaultOrder": 3, "defaultExportOrder": 3, "defaultExport": true, "exportable": true, "tableAvailable": true}, {"id": "CategoryLabels", "label": "Libellé catégorie", "type": "text[]", "defaultVisible": true, "defaultOrder": 4, "defaultExportOrder": 4, "defaultExport": true, "exportable": true, "tableAvailable": true}, {"id": "DefaultCategoryId", "label": "ID catégorie par défaut", "type": "integer", "defaultVisible": true, "defaultOrder": 5, "defaultExportOrder": 5, "defaultExport": true, "exportable": true, "tableAvailable": true}, {"id": "actions", "label": "Actions", "type": "text", "defaultVisible": true, "defaultOrder": 6, "defaultExportOrder": 6, "defaultExport": false, "exportable": false, "tableAvailable": true}, {"id": "ChampLabel", "label": "Libellé du champ", "type": "text", "defaultVisible": false, "defaultOrder": 7, "defaultExportOrder": 7, "defaultExport": false, "exportable": true, "tableAvailable": true}, {"id": "ModuleName", "label": "Module", "type": "text", "defaultVisible": false, "defaultOrder": 8, "defaultExportOrder": 8, "defaultExport": false, "exportable": true, "tableAvailable": true}, {"id": "CategoriesActuelles", "label": "Catégories actuelles", "type": "text", "defaultVisible": false, "defaultOrder": 9, "defaultExportOrder": 9, "defaultExport": false, "exportable": true, "tableAvailable": false}, {"id": "CategorieDefaut", "label": "Catégorie par défaut", "type": "text", "defaultVisible": false, "defaultOrder": 10, "defaultExportOrder": 10, "defaultExport": false, "exportable": true, "tableAvailable": false}, {"id": "OrigineReglage", "label": "Origine du réglage", "type": "text", "defaultVisible": false, "defaultOrder": 11, "defaultExportOrder": 11, "defaultExport": false, "exportable": true, "tableAvailable": true}, {"id": "CanConfigure", "label": "Configuration autorisée", "type": "boolean", "defaultVisible": false, "defaultOrder": 12, "defaultExportOrder": 12, "defaultExport": false, "exportable": true, "tableAvailable": false}, {"id": "SupportsEntityScope", "label": "SupportsEntityScope", "type": "boolean", "defaultVisible": false, "defaultOrder": 13, "defaultExportOrder": 13, "defaultExport": false, "exportable": true, "tableAvailable": false}, {"id": "ReferenceHeriteeParent", "label": "Référence héritée du parent", "type": "boolean", "defaultVisible": false, "defaultOrder": 14, "defaultExportOrder": 14, "defaultExport": false, "exportable": true, "tableAvailable": false}, {"id": "ModifieLe", "label": "Modifié le", "type": "timestamp with time zone", "defaultVisible": false, "defaultOrder": 15, "defaultExportOrder": 15, "defaultExport": false, "exportable": true, "tableAvailable": true}, {"id": "CreeLe", "label": "Créé le", "type": "timestamp with time zone", "defaultVisible": false, "defaultOrder": 16, "defaultExportOrder": 16, "defaultExport": false, "exportable": true, "tableAvailable": false}, {"id": "ID_ChampReferentiel", "label": "ID_ChampReferentiel", "type": "integer", "defaultVisible": false, "defaultOrder": 17, "defaultExportOrder": 17, "defaultExport": false, "exportable": true, "tableAvailable": false}, {"id": "ID_CategorieDefautFk", "label": "ID_CategorieDefautFk", "type": "integer", "defaultVisible": false, "defaultOrder": 18, "defaultExportOrder": 18, "defaultExport": false, "exportable": true, "tableAvailable": false}, {"id": "AliasSourceKeys", "label": "AliasSourceKeys", "type": "text[]", "defaultVisible": false, "defaultOrder": 19, "defaultExportOrder": 19, "defaultExport": false, "exportable": true, "tableAvailable": false}, {"id": "Revision", "label": "Revision", "type": "integer", "defaultVisible": false, "defaultOrder": 20, "defaultExportOrder": 20, "defaultExport": false, "exportable": true, "tableAvailable": false}, {"id": "ModifieParUserFk", "label": "ModifieParUserFk", "type": "integer", "defaultVisible": false, "defaultOrder": 21, "defaultExportOrder": 21, "defaultExport": false, "exportable": false, "tableAvailable": false}]'::jsonb);
COMMENT ON COLUMN referentiel."T_ChampReferentiel"."ID_ChampReferentiel" IS 'Identifiant immuable d’une colonne physique cataloguée, jamais déduit de sa position affichée.';
COMMENT ON COLUMN referentiel."T_ChampReferentiel"."SchemaName" IS 'Schéma réel de la table possédant une clé étrangère vers T_Generique.';
COMMENT ON COLUMN referentiel."T_ChampReferentiel"."TableName" IS 'Nom réel et sensible à la casse de la table propriétaire de la clé étrangère.';
COMMENT ON COLUMN referentiel."T_ChampReferentiel"."ColumnName" IS 'Nom physique exact de la colonne de référence ; la clé étrangère est prouvée au catalogue PostgreSQL.';
COMMENT ON COLUMN referentiel."T_ChampReferentiel"."ChampLabel" IS 'Libellé métier du champ pour lecture et diagnostic, distinct de son identifiant SQL.';
COMMENT ON COLUMN referentiel."T_ChampReferentiel"."ModuleName" IS 'Domaine du champ, utilisé pour le catalogue et les correspondances, sans accorder de droits.';
COMMENT ON COLUMN referentiel."T_ChampReferentiel"."ID_CategorieDefautFk" IS 'Famille de référence prouvée et immuable ; NULL signifie absence de preuve, aucune famille inventée.';
COMMENT ON COLUMN referentiel."T_ChampReferentiel"."AliasSourceKeys" IS 'Anciens SourceKey explicitement associés à cette vraie FK pour compatibilité des réglages hérités.';
COMMENT ON COLUMN referentiel."T_ChampReferentiel"."CanConfigure" IS 'Autorise une surcharge de catégorie ; false protège notamment la famille des rôles de sécurité.';
COMMENT ON COLUMN referentiel."T_ChampReferentiel"."SupportsEntityScope" IS 'Politique immuable de portée : true seulement si la vraie ligne possède une entreprise directe, sa propre PK Entité ou un parent logistique prouvé. Les tables partagées restent globales, sans entreprise déduite de leur utilisateur.';
COMMENT ON COLUMN referentiel."T_ChampReferentiel"."Revision" IS 'Révision opaque incrémentée pour toute modification de jeu canonique ou alias, afin de détecter les écritures concurrentes.';
COMMENT ON COLUMN referentiel."T_ChampReferentiel"."CreeLe" IS 'Instant réel de création du catalogue physique.';
COMMENT ON COLUMN referentiel."T_ChampReferentiel"."ModifieLe" IS 'Instant réel de la dernière modification de correspondance touchant le champ.';
COMMENT ON COLUMN referentiel."T_ChampReferentiel"."ModifieParUserFk" IS 'Auteur factuel du dernier réglage si prouvé ; NULL pour installation et absence de contexte.';
DO $comments$ DECLARE r record;BEGIN
 FOR r IN SELECT a.attname FROM pg_attribute a WHERE a.attrelid='referentiel."V_ReferencementChamp"'::regclass AND a.attnum>0 AND NOT a.attisdropped LOOP
 EXECUTE format('COMMENT ON COLUMN referentiel."V_ReferencementChamp".%I IS %L',r.attname,'Projection de référencement : '||r.attname||'. Les identités techniques et catégories restent issues du même catalogue et du même résolveur.');END LOOP;
 FOR r IN SELECT conrelid::regclass obj,conname,pg_get_constraintdef(oid,true) def FROM pg_constraint WHERE conrelid='referentiel."T_ChampReferentiel"'::regclass OR (conrelid='systeme."T_Fk_Correspondance"'::regclass AND conname='T_Fk_Correspondance_IdChampReferentielFk_fkey') LOOP
 EXECUTE format('COMMENT ON CONSTRAINT %I ON %s IS %L',r.conname,r.obj,'Intégrité du référencement physique : '||r.def);END LOOP;
END $comments$;
COMMENT ON INDEX referentiel."T_ChampReferentiel_pkey" IS 'Accès par identité immuable au catalogue des champs.';
COMMENT ON INDEX referentiel.uq_champ_referentiel_physique IS 'Une seule définition et un seul défaut de référence par colonne physique à clé étrangère.';
COMMIT;
