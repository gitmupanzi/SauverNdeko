-- Backfill legacy admin/logistique FK settings into systeme.T_Fk_Correspondance
-- Source legacy : systeme.T_Admin_UI_Setting / SettingKey = 'admin-ui.select-settings'
-- Cible standard : systeme.T_Fk_Correspondance

DROP TABLE IF EXISTS tmp_legacy_admin_ui_setting;

DO $$
BEGIN
    IF to_regclass('systeme."T_Fk_Correspondance"') IS NULL THEN
        RAISE EXCEPTION 'Backfill impossible : systeme.T_Fk_Correspondance est absente.';
    END IF;

    IF to_regclass('systeme."T_Admin_UI_Setting"') IS NULL THEN
        CREATE TEMP TABLE tmp_legacy_admin_ui_setting (
            "SettingScope" character varying(60),
            "ScopeValue" character varying(120),
            "SettingValue" jsonb,
            "UpdatedAt" timestamp(6),
            "UpdatedByUserFk" integer
        ) ON COMMIT DROP;

        RAISE NOTICE 'Backfill ignore : systeme.T_Admin_UI_Setting est absente.';
        RETURN;
    END IF;

    EXECUTE '
        CREATE TEMP TABLE tmp_legacy_admin_ui_setting
        ON COMMIT DROP
        AS
        SELECT
            s."SettingScope",
            s."ScopeValue",
            s."SettingValue",
            s."UpdatedAt",
            s."UpdatedByUserFk"
        FROM systeme."T_Admin_UI_Setting" s
        WHERE s."SettingKey" = ''admin-ui.select-settings''
    ';
END $$;

WITH source_registry AS (
    SELECT *
    FROM (
        VALUES
            ('admin','referentiel',NULL,'roles','roles','Role','generic_category','referentiel','T_Generique','ID_Generique',ARRAY['39']::text[],NULL),
            ('admin','referentiel',NULL,'entityTypes','entityTypes','Type entite','generic_category','referentiel','T_Generique','ID_Generique',ARRAY['48']::text[],NULL),
            ('admin','referentiel',NULL,'licenseStatuses','licenseStatuses','Statut licence','generic_category','referentiel','T_Generique','ID_Generique',ARRAY['55']::text[],NULL),
            ('admin','geolocalisation',NULL,'niveau2Types','niveau2Types','Type niveau 2','generic_category','referentiel','T_Generique','ID_Generique',ARRAY['32']::text[],NULL),
            ('admin','geolocalisation',NULL,'niveau3Types','niveau3Types','Type niveau 3','generic_category','referentiel','T_Generique','ID_Generique',ARRAY['32']::text[],NULL),
            ('admin','geolocalisation',NULL,'niveau2Statuses','niveau2Statuses','Statut niveau 2','generic_category','referentiel','T_Generique','ID_Generique',ARRAY['4']::text[],NULL),
            ('admin','geolocalisation',NULL,'niveau3Statuses','niveau3Statuses','Statut niveau 3','generic_category','referentiel','T_Generique','ID_Generique',ARRAY['4']::text[],NULL),
            ('admin','geolocalisation',NULL,'deploymentStatuses','deploymentStatuses','Statut deploiement','generic_category','referentiel','T_Generique','ID_Generique',ARRAY['27']::text[],NULL),
            ('admin','geolocalisation',NULL,'dpsAccessRoutes','dpsAccessRoutes','Voie acces DPS','generic_category','referentiel','T_Generique','ID_Generique',ARRAY['29']::text[],NULL),
            ('admin','geolocalisation',NULL,'antBczAccessRoutes','antBczAccessRoutes','Voie acces antenne BCZS','generic_category','referentiel','T_Generique','ID_Generique',ARRAY['29']::text[],NULL),
            ('admin','geolocalisation',NULL,'dpsBczAccessRoutes','dpsBczAccessRoutes','Voie acces DPS BCZS','generic_category','referentiel','T_Generique','ID_Generique',ARRAY['29']::text[],NULL),
            ('admin','geolocalisation',NULL,'niveau4Types','niveau4Types','Type niveau 4','generic_category','referentiel','T_Generique','ID_Generique',ARRAY['32']::text[],NULL),
            ('admin','geolocalisation',NULL,'niveau5Types','niveau5Types','Type niveau 5','generic_category','referentiel','T_Generique','ID_Generique',ARRAY['32']::text[],NULL),
            ('admin','geolocalisation',NULL,'niveau4Statuses','niveau4Statuses','Statut niveau 4','generic_category','referentiel','T_Generique','ID_Generique',ARRAY['4']::text[],NULL),
            ('admin','geolocalisation',NULL,'niveau5Statuses','niveau5Statuses','Statut niveau 5','generic_category','referentiel','T_Generique','ID_Generique',ARRAY['4']::text[],NULL),
            ('admin','geolocalisation',NULL,'networkAvailabilities','networkAvailabilities','Disponibilite reseau','generic_category','referentiel','T_Generique','ID_Generique',ARRAY['19']::text[],NULL),
            ('admin','geolocalisation',NULL,'zsAsAccessRoutes','zsAsAccessRoutes','Voie acces ZS-AS','generic_category','referentiel','T_Generique','ID_Generique',ARRAY['29']::text[],NULL),
            ('admin','geolocalisation',NULL,'zsSiteAccessRoutes','zsSiteAccessRoutes','Voie acces ZS-Site','generic_category','referentiel','T_Generique','ID_Generique',ARRAY['29']::text[],NULL),
            ('admin','geolocalisation',NULL,'roofTypes','roofTypes','Type de toit','generic_category','referentiel','T_Generique','ID_Generique',ARRAY['18']::text[],NULL),
            ('logistique','logistique','V_Article','logistique.articleTypes','ID_TypeArticleFk','Type d''article','generic_category','referentiel','T_Generique','ID_Generique',ARRAY['46']::text[],NULL),
            ('logistique','logistique','V_Article','logistique.articleCategories','ID_CategorieArticleFk','Categorie d''article','generic_category','referentiel','T_Generique','ID_Generique',ARRAY['40']::text[],NULL),
            ('logistique','logistique','V_Article','logistique.articleUnits','ID_UniteFk','Unite','generic_category','referentiel','T_Generique','ID_Generique',ARRAY['34']::text[],NULL),
            ('logistique','logistique',NULL,'logistique.commandeTypes','ID_TypeCmdFk','Type de commande','generic_category','referentiel','T_Generique','ID_Generique',ARRAY['64']::text[],NULL),
            ('logistique','logistique','V_Commande','logistique.commandeStatuses','ID_StatutCmdFk','Statut commande','generic_category','referentiel','T_Generique','ID_Generique',ARRAY['28']::text[],NULL),
            ('logistique','logistique','V_Commande','logistique.commandeConditionPaiements','ID_ConditionPaiementFk','Condition de paiement','generic_category','referentiel','T_Generique','ID_Generique',ARRAY['37']::text[],NULL),
            ('logistique','logistique','V_Commande','logistique.commandeModesPaiement','ID_ModePaiementFk','Mode de paiement','generic_category','referentiel','T_Generique','ID_Generique',ARRAY['36']::text[],NULL),
            ('logistique','logistique','V_SuiviReglements','logistique.reglementModes','ID_ModeReglementFk','Mode de reglement','generic_category','referentiel','T_Generique','ID_Generique',ARRAY['36']::text[],NULL),
            ('admin','geolocalisation',NULL,'niveaux0','niveaux0','Niveau 0','hierarchy_mode',NULL,NULL,NULL,NULL,'all'),
            ('admin','geolocalisation',NULL,'niveaux1Old','niveaux1Old','Niveau 1 historique','hierarchy_mode',NULL,NULL,NULL,NULL,'all'),
            ('admin','geolocalisation',NULL,'niveaux1','niveaux1','Niveau 1','hierarchy_mode',NULL,NULL,NULL,NULL,'filtered'),
            ('admin','geolocalisation',NULL,'niveaux2','niveaux2','Niveau 2','hierarchy_mode',NULL,NULL,NULL,NULL,'filtered'),
            ('admin','geolocalisation',NULL,'niveaux3','niveaux3','Niveau 3','hierarchy_mode',NULL,NULL,NULL,NULL,'filtered'),
            ('admin','geolocalisation',NULL,'niveaux4','niveaux4','Niveau 4','hierarchy_mode',NULL,NULL,NULL,NULL,'filtered'),
            ('admin','geolocalisation',NULL,'niveaux5','niveaux5','Niveau 5','hierarchy_mode',NULL,NULL,NULL,NULL,'filtered')
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
        default_category_ids,
        default_mode
    )
),
legacy_rows AS (
    SELECT
        s."SettingScope",
        s."ScopeValue",
        s."SettingValue",
        s."UpdatedAt",
        s."UpdatedByUserFk"
    FROM tmp_legacy_admin_ui_setting s
),
generic_rows AS (
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
        legacy."SettingScope" AS setting_scope,
        legacy."ScopeValue" AS scope_value,
        legacy."UpdatedAt" AS updated_at,
        legacy."UpdatedByUserFk" AS updated_by_user_fk,
        COALESCE(
            legacy."SettingValue"->'genericCategoryOverrides'->>sr.source_key,
            array_to_string(sr.default_category_ids, ', ')
        ) AS category_text,
        array_to_string(sr.default_category_ids, ', ') AS default_category_text
    FROM source_registry sr
    CROSS JOIN legacy_rows legacy
    WHERE sr.mapping_type = 'generic_category'
),
generic_expanded AS (
    SELECT
        gr.module_name,
        gr.schema_name,
        gr.view_name,
        gr.source_key,
        gr.field_name,
        gr.field_label,
        gr.mapping_type,
        gr.reference_schema_name,
        gr.reference_object_name,
        gr.reference_field_name,
        gr.setting_scope,
        gr.scope_value,
        gr.updated_at,
        gr.updated_by_user_fk,
        trim(value_item) AS mapping_value,
        ordinality - 1 AS display_order,
        gr.category_text = gr.default_category_text AS is_default_mapping
    FROM generic_rows gr,
         regexp_split_to_table(gr.category_text, '\s*,\s*') WITH ORDINALITY AS split_value(value_item, ordinality)
    WHERE trim(value_item) <> ''
),
hierarchy_rows AS (
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
        legacy."SettingScope" AS setting_scope,
        legacy."ScopeValue" AS scope_value,
        legacy."UpdatedAt" AS updated_at,
        legacy."UpdatedByUserFk" AS updated_by_user_fk,
        COALESCE(
            legacy."SettingValue"->'hierarchyFilterModes'->>sr.source_key,
            sr.default_mode
        ) AS mapping_value,
        sr.default_mode AS default_mode
    FROM source_registry sr
    CROSS JOIN legacy_rows legacy
    WHERE sr.mapping_type = 'hierarchy_mode'
),
merged_rows AS (
    SELECT
        ge.module_name,
        ge.schema_name,
        ge.view_name,
        ge.source_key,
        ge.field_name,
        ge.field_label,
        ge.mapping_type,
        ge.reference_schema_name,
        ge.reference_object_name,
        ge.reference_field_name,
        ge.mapping_value,
        ge.mapping_value::integer AS target_category_id_fk,
        ge.is_default_mapping,
        true AS valide_fk_correspondance,
        ge.setting_scope,
        ge.scope_value,
        ge.display_order,
        ge.updated_at,
        ge.updated_by_user_fk,
        ('Backfill legacy ' || ge.source_key) AS obs_fk_correspondance
    FROM generic_expanded ge

    UNION ALL

    SELECT
        hr.module_name,
        hr.schema_name,
        hr.view_name,
        hr.source_key,
        hr.field_name,
        hr.field_label,
        hr.mapping_type,
        hr.reference_schema_name,
        hr.reference_object_name,
        hr.reference_field_name,
        hr.mapping_value,
        NULL::integer AS target_category_id_fk,
        hr.mapping_value = hr.default_mode AS is_default_mapping,
        true AS valide_fk_correspondance,
        hr.setting_scope,
        hr.scope_value,
        0 AS display_order,
        hr.updated_at,
        hr.updated_by_user_fk,
        ('Backfill legacy ' || hr.source_key) AS obs_fk_correspondance
    FROM hierarchy_rows hr
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
    mr.module_name,
    mr.schema_name,
    mr.view_name,
    mr.source_key,
    mr.field_name,
    mr.field_label,
    mr.mapping_type,
    mr.reference_schema_name,
    mr.reference_object_name,
    mr.reference_field_name,
    mr.target_category_id_fk,
    mr.mapping_value,
    mr.is_default_mapping,
    mr.valide_fk_correspondance,
    mr.setting_scope,
    mr.scope_value,
    mr.display_order,
    COALESCE(mr.updated_at, CURRENT_TIMESTAMP),
    mr.updated_by_user_fk,
    mr.obs_fk_correspondance
FROM merged_rows mr
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

DO $$
DECLARE
    v_count integer;
BEGIN
    SELECT COUNT(*)::integer
    INTO v_count
    FROM systeme."T_Fk_Correspondance"
    WHERE "MappingType" IN ('generic_category', 'hierarchy_mode');

    RAISE NOTICE 'Backfill FK termine. % correspondance(s) geree(s) presente(s) dans systeme.T_Fk_Correspondance.', COALESCE(v_count, 0);
END $$;
