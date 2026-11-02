-- Initialisation par defaut de systeme.T_Fk_Correspondance
-- Portee : globale
-- Usage :
-- - a executer sur une base vide ou juste apres migration
-- - le script est rejouable
-- - il reinitialise uniquement les correspondances gerees en portee globale

BEGIN;

DO $$
BEGIN
    IF to_regclass('systeme."T_Fk_Correspondance"') IS NULL THEN
        RAISE EXCEPTION
            'Initialisation impossible : systeme.T_Fk_Correspondance est absente.';
    END IF;
END $$;

DELETE FROM systeme."T_Fk_Correspondance"
WHERE "SettingScope" = 'global'
  AND "ScopeValue" IS NULL
  AND "MappingType" IN ('generic_category', 'hierarchy_mode');

WITH seed_rows AS (
    SELECT *
    FROM (
        VALUES
            ('admin','referentiel',NULL,'roles','roles','Role','generic_category','referentiel','T_Generique','ID_Generique',39,'39',true,true,'global',NULL,0,NULL,'Initialisation par defaut'),
            ('admin','referentiel',NULL,'entityTypes','entityTypes','Type entite','generic_category','referentiel','T_Generique','ID_Generique',48,'48',true,true,'global',NULL,0,NULL,'Initialisation par defaut'),
            ('admin','referentiel',NULL,'licenseStatuses','licenseStatuses','Statut licence','generic_category','referentiel','T_Generique','ID_Generique',55,'55',true,true,'global',NULL,0,NULL,'Initialisation par defaut'),
            ('admin','geolocalisation',NULL,'niveau2Types','niveau2Types','Type niveau 2','generic_category','referentiel','T_Generique','ID_Generique',32,'32',true,true,'global',NULL,0,NULL,'Initialisation par defaut'),
            ('admin','geolocalisation',NULL,'niveau3Types','niveau3Types','Type niveau 3','generic_category','referentiel','T_Generique','ID_Generique',32,'32',true,true,'global',NULL,0,NULL,'Initialisation par defaut'),
            ('admin','geolocalisation',NULL,'niveau2Statuses','niveau2Statuses','Statut niveau 2','generic_category','referentiel','T_Generique','ID_Generique',4,'4',true,true,'global',NULL,0,NULL,'Initialisation par defaut'),
            ('admin','geolocalisation',NULL,'niveau3Statuses','niveau3Statuses','Statut niveau 3','generic_category','referentiel','T_Generique','ID_Generique',4,'4',true,true,'global',NULL,0,NULL,'Initialisation par defaut'),
            ('admin','geolocalisation',NULL,'deploymentStatuses','deploymentStatuses','Statut deploiement','generic_category','referentiel','T_Generique','ID_Generique',27,'27',true,true,'global',NULL,0,NULL,'Initialisation par defaut'),
            ('admin','geolocalisation',NULL,'dpsAccessRoutes','dpsAccessRoutes','Voie acces DPS','generic_category','referentiel','T_Generique','ID_Generique',29,'29',true,true,'global',NULL,0,NULL,'Initialisation par defaut'),
            ('admin','geolocalisation',NULL,'antBczAccessRoutes','antBczAccessRoutes','Voie acces antenne BCZS','generic_category','referentiel','T_Generique','ID_Generique',29,'29',true,true,'global',NULL,0,NULL,'Initialisation par defaut'),
            ('admin','geolocalisation',NULL,'dpsBczAccessRoutes','dpsBczAccessRoutes','Voie acces DPS BCZS','generic_category','referentiel','T_Generique','ID_Generique',29,'29',true,true,'global',NULL,0,NULL,'Initialisation par defaut'),
            ('admin','geolocalisation',NULL,'niveau4Types','niveau4Types','Type niveau 4','generic_category','referentiel','T_Generique','ID_Generique',32,'32',true,true,'global',NULL,0,NULL,'Initialisation par defaut'),
            ('admin','geolocalisation',NULL,'niveau5Types','niveau5Types','Type niveau 5','generic_category','referentiel','T_Generique','ID_Generique',32,'32',true,true,'global',NULL,0,NULL,'Initialisation par defaut'),
            ('admin','geolocalisation',NULL,'niveau4Statuses','niveau4Statuses','Statut niveau 4','generic_category','referentiel','T_Generique','ID_Generique',4,'4',true,true,'global',NULL,0,NULL,'Initialisation par defaut'),
            ('admin','geolocalisation',NULL,'niveau5Statuses','niveau5Statuses','Statut niveau 5','generic_category','referentiel','T_Generique','ID_Generique',4,'4',true,true,'global',NULL,0,NULL,'Initialisation par defaut'),
            ('admin','geolocalisation',NULL,'networkAvailabilities','networkAvailabilities','Disponibilite reseau','generic_category','referentiel','T_Generique','ID_Generique',19,'19',true,true,'global',NULL,0,NULL,'Initialisation par defaut'),
            ('admin','geolocalisation',NULL,'zsAsAccessRoutes','zsAsAccessRoutes','Voie acces ZS-AS','generic_category','referentiel','T_Generique','ID_Generique',29,'29',true,true,'global',NULL,0,NULL,'Initialisation par defaut'),
            ('admin','geolocalisation',NULL,'zsSiteAccessRoutes','zsSiteAccessRoutes','Voie acces ZS-Site','generic_category','referentiel','T_Generique','ID_Generique',29,'29',true,true,'global',NULL,0,NULL,'Initialisation par defaut'),
            ('admin','geolocalisation',NULL,'roofTypes','roofTypes','Type de toit','generic_category','referentiel','T_Generique','ID_Generique',18,'18',true,true,'global',NULL,0,NULL,'Initialisation par defaut'),
            ('logistique','logistique','V_Article','logistique.articleTypes','ID_TypeArticleFk','Type d''article','generic_category','referentiel','T_Generique','ID_Generique',46,'46',true,true,'global',NULL,0,NULL,'Initialisation par defaut'),
            ('logistique','logistique','V_Article','logistique.articleCategories','ID_CategorieArticleFk','Categorie d''article','generic_category','referentiel','T_Generique','ID_Generique',40,'40',true,true,'global',NULL,0,NULL,'Initialisation par defaut'),
            ('logistique','logistique','V_Article','logistique.articleUnits','ID_UniteFk','Unite','generic_category','referentiel','T_Generique','ID_Generique',34,'34',true,true,'global',NULL,0,NULL,'Initialisation par defaut'),
            ('logistique','logistique',NULL,'logistique.commandeTypes','ID_TypeCmdFk','Type de commande','generic_category','referentiel','T_Generique','ID_Generique',64,'64',true,true,'global',NULL,0,NULL,'Initialisation par defaut'),
            ('logistique','logistique','V_Commande','logistique.commandeStatuses','ID_StatutCmdFk','Statut commande','generic_category','referentiel','T_Generique','ID_Generique',28,'28',true,true,'global',NULL,0,NULL,'Initialisation par defaut'),
            ('logistique','logistique','V_Commande','logistique.commandeConditionPaiements','ID_ConditionPaiementFk','Condition de paiement','generic_category','referentiel','T_Generique','ID_Generique',37,'37',true,true,'global',NULL,0,NULL,'Initialisation par defaut'),
            ('logistique','logistique','V_Commande','logistique.commandeModesPaiement','ID_ModePaiementFk','Mode de paiement','generic_category','referentiel','T_Generique','ID_Generique',36,'36',true,true,'global',NULL,0,NULL,'Initialisation par defaut'),
            ('logistique','logistique','V_SuiviReglements','logistique.reglementModes','ID_ModeReglementFk','Mode de reglement','generic_category','referentiel','T_Generique','ID_Generique',36,'36',true,true,'global',NULL,0,NULL,'Initialisation par defaut'),
            ('admin','geolocalisation',NULL,'niveaux0','niveaux0','Niveau 0','hierarchy_mode',NULL,NULL,NULL,NULL,'all',true,true,'global',NULL,0,NULL,'Initialisation par defaut'),
            ('admin','geolocalisation',NULL,'niveaux1Old','niveaux1Old','Niveau 1 historique','hierarchy_mode',NULL,NULL,NULL,NULL,'all',true,true,'global',NULL,0,NULL,'Initialisation par defaut'),
            ('admin','geolocalisation',NULL,'niveaux1','niveaux1','Niveau 1','hierarchy_mode',NULL,NULL,NULL,NULL,'filtered',true,true,'global',NULL,0,NULL,'Initialisation par defaut'),
            ('admin','geolocalisation',NULL,'niveaux2','niveaux2','Niveau 2','hierarchy_mode',NULL,NULL,NULL,NULL,'filtered',true,true,'global',NULL,0,NULL,'Initialisation par defaut'),
            ('admin','geolocalisation',NULL,'niveaux3','niveaux3','Niveau 3','hierarchy_mode',NULL,NULL,NULL,NULL,'filtered',true,true,'global',NULL,0,NULL,'Initialisation par defaut'),
            ('admin','geolocalisation',NULL,'niveaux4','niveaux4','Niveau 4','hierarchy_mode',NULL,NULL,NULL,NULL,'filtered',true,true,'global',NULL,0,NULL,'Initialisation par defaut'),
            ('admin','geolocalisation',NULL,'niveaux5','niveaux5','Niveau 5','hierarchy_mode',NULL,NULL,NULL,NULL,'filtered',true,true,'global',NULL,0,NULL,'Initialisation par defaut')
    ) AS t(
        module_name,
        schema_name,
        view_name,
        source_key,
        field_name,
        field_label,
        mapping_type,
        reference_schema_name,
        reference_object_name,
        reference_field_name,
        target_category_id_fk,
        mapping_value,
        is_default_mapping,
        valide_fk_correspondance,
        setting_scope,
        scope_value,
        display_order,
        updated_by_user_fk,
        obs_fk_correspondance
    )
)
INSERT INTO systeme."T_Fk_Correspondance" (
    "ModuleName",
    "SchemaName",
    "ViewName",
    "SourceKey",
    "FieldName",
    "FieldLabel",
    "MappingType",
    "ReferenceSchemaName",
    "ReferenceObjectName",
    "ReferenceFieldName",
    "TargetCategoryIdFk",
    "MappingValue",
    "IsDefaultMapping",
    "ValideFkCorrespondance",
    "SettingScope",
    "ScopeValue",
    "DisplayOrder",
    "UpdatedAt",
    "UpdatedByUserFk",
    "ObsFkCorrespondance"
)
SELECT
    sr.module_name,
    sr.schema_name,
    sr.view_name,
    sr.source_key,
    sr.field_name,
    sr.field_label,
    sr.mapping_type,
    sr.reference_schema_name,
    sr.reference_object_name,
    sr.reference_field_name,
    sr.target_category_id_fk::integer,
    sr.mapping_value,
    sr.is_default_mapping,
    sr.valide_fk_correspondance,
    sr.setting_scope,
    sr.scope_value,
    sr.display_order,
    CURRENT_TIMESTAMP,
    sr.updated_by_user_fk::integer,
    sr.obs_fk_correspondance
FROM seed_rows sr
ON CONFLICT ("ModuleName", "SchemaName", "ViewName", "SourceKey", "FieldName", "MappingType", "MappingValue", "SettingScope", "ScopeValue")
DO UPDATE SET
    "FieldLabel" = EXCLUDED."FieldLabel",
    "ReferenceSchemaName" = EXCLUDED."ReferenceSchemaName",
    "ReferenceObjectName" = EXCLUDED."ReferenceObjectName",
    "ReferenceFieldName" = EXCLUDED."ReferenceFieldName",
    "TargetCategoryIdFk" = EXCLUDED."TargetCategoryIdFk",
    "IsDefaultMapping" = EXCLUDED."IsDefaultMapping",
    "ValideFkCorrespondance" = EXCLUDED."ValideFkCorrespondance",
    "DisplayOrder" = EXCLUDED."DisplayOrder",
    "UpdatedAt" = EXCLUDED."UpdatedAt",
    "UpdatedByUserFk" = EXCLUDED."UpdatedByUserFk",
    "ObsFkCorrespondance" = EXCLUDED."ObsFkCorrespondance";

-- Les identifiants de la nouvelle famille de patrimoine varient entre
-- installations : résoudre les catégories, jamais recopier un ID de serveur.
DO $immobilisations$
DECLARE item record;category_id integer;family_count integer;
BEGIN
 IF to_regclass('logistique."T_Immobilisation"') IS NULL THEN RETURN;END IF;
 FOR item IN SELECT * FROM (VALUES
  ('categories','ID_CategorieFk','Type de matériel','Type de matériel'),
  ('etats','ID_EtatFk','État du matériel','Etat'),
  ('services','ID_ServiceFk','Service','Service')) AS seed(source,field,label,family) LOOP
  SELECT count(*),min("ID_CategorieGenerique") INTO family_count,category_id
   FROM referentiel."T_CategorieGenerique" WHERE lower(btrim("NomCategorieGenerique"))=lower(item.family);
  IF family_count<>1 THEN RAISE EXCEPTION 'Famille % absente ou ambiguë pour le patrimoine.',item.family;END IF;
  INSERT INTO systeme."T_Fk_Correspondance"("ModuleName","SchemaName","ViewName","SourceKey","FieldName","FieldLabel","MappingType","ReferenceSchemaName","ReferenceObjectName","ReferenceFieldName","TargetCategoryIdFk","MappingValue","IsDefaultMapping","ValideFkCorrespondance","SettingScope","ScopeValue","DisplayOrder","ObsFkCorrespondance")
  VALUES('logistique','logistique','V_Immobilisation','logistique.immobilisations.'||item.source,item.field,item.label,'generic_category','referentiel','T_Generique','ID_Generique',category_id,category_id::text,true,true,'global',NULL,0,'Initialisation patrimoine08 par catégorie résolue.');
 END LOOP;
END $immobilisations$;

-- Le module Caisse utilise le catalogue physique commun et ses catégories
-- prouvées. L'ancien schéma non migré ne reçoit aucune correspondance fictive.
DO $caisse$
DECLARE item record;
BEGIN
 IF NOT EXISTS(SELECT FROM information_schema.columns WHERE table_schema='operations' AND table_name='T_Caisse' AND column_name='CodeCaisse') THEN RETURN;END IF;
 FOR item IN SELECT * FROM referentiel."T_ChampReferentiel"
  WHERE "SchemaName"='operations' AND "TableName" IN('T_Caisse','T_Paiement')
    AND "ID_CategorieDefautFk" IS NOT NULL LOOP
  INSERT INTO systeme."T_Fk_Correspondance"(
   "ModuleName","SchemaName","ViewName","SourceKey","FieldName","FieldLabel","MappingType",
   "ReferenceSchemaName","ReferenceObjectName","ReferenceFieldName","TargetCategoryIdFk","MappingValue",
   "IsDefaultMapping","ValideFkCorrespondance","SettingScope","ScopeValue","DisplayOrder","ObsFkCorrespondance","IdChampReferentielFk")
  VALUES(item."ModuleName",'operations',NULL,
   'champ.'||item."ID_ChampReferentiel",item."ColumnName",item."ChampLabel",'generic_category',
   'referentiel','T_Generique','ID_Generique',item."ID_CategorieDefautFk",item."ID_CategorieDefautFk"::text,
   true,true,'global',NULL,0,'Défaut Caisse issu du catalogue physique, sans affectation client.',item."ID_ChampReferentiel");
 END LOOP;
END $caisse$;

DO $$
DECLARE
    v_count integer;
BEGIN
    SELECT COUNT(*)::integer
    INTO v_count
    FROM systeme."T_Fk_Correspondance"
    WHERE "MappingType" IN ('generic_category', 'hierarchy_mode');

    RAISE NOTICE 'Initialisation FK terminee. % correspondance(s) geree(s) presente(s) dans systeme.T_Fk_Correspondance.', COALESCE(v_count, 0);
END $$;

COMMIT;
