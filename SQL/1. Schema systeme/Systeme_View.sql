-- View: systeme.V_Audit_log
-- DROP VIEW systeme."V_Audit_log";
CREATE OR REPLACE VIEW systeme."V_Audit_log" AS
SELECT a."IdLog",
    a."TableName",
    a."Operation",
    a."ChangedAt",
    e."NomEntite",
    a."OldData",
    a."NewData"
FROM systeme."T_Audit_Log" a
    LEFT JOIN systeme."T_Entite" e ON e."IdEntite" = a."IdEntiteFk";
ALTER TABLE systeme."V_Audit_log" OWNER TO postgres;
-- View: systeme.V_Admin_UI_Setting_Audit
-- DROP VIEW systeme."V_Admin_UI_Setting_Audit";
CREATE OR REPLACE VIEW systeme."V_Admin_UI_Setting_Audit" AS
SELECT a."IdLog",
    a."TableName",
    a."Operation",
    a."ChangedAt",
    COALESCE(
        a."NewData"->>'settingScope'::text,
        a."OldData"->>'settingScope'::text,
        'global'::text
    ) AS "SettingScope",
    COALESCE(
        a."NewData"->>'updatedByName'::text,
        a."OldData"->>'updatedByName'::text
    ) AS "UpdatedByName",
    COALESCE(
        a."NewData"->>'updatedByUserId'::text,
        a."OldData"->>'updatedByUserId'::text
    ) AS "UpdatedByUserId",
    COALESCE(
        a."NewData"->>'updatedAt'::text,
        a."OldData"->>'updatedAt'::text
    ) AS "UpdatedSettingAt",
    a."OldData",
    a."NewData"
FROM systeme."T_Audit_Log" a
WHERE a."TableName"::text = 'T_Admin_UI_Setting'::text
ORDER BY a."ChangedAt" DESC;
ALTER TABLE systeme."V_Admin_UI_Setting_Audit" OWNER TO postgres;
-- View: systeme.V_Fk_Correspondance_Detail
-- DROP VIEW systeme."V_Fk_Correspondance_Detail";
CREATE OR REPLACE VIEW systeme."V_Fk_Correspondance_Detail" AS
SELECT fc."IdFkCorrespondance",
    fc."ModuleName",
    fc."SchemaName",
    fc."ViewName",
    fc."SourceKey",
    fc."FieldName",
    fc."FieldLabel",
    fc."MappingType",
    fc."ReferenceSchemaName",
    fc."ReferenceObjectName",
    fc."ReferenceFieldName",
    fc."TargetCategoryIdFk",
    c."NomCategorieGenerique",
    fc."MappingValue",
    fc."IsDefaultMapping",
    fc."ValideFkCorrespondance",
    fc."SettingScope",
    fc."ScopeValue",
    fc."DisplayOrder",
    fc."UpdatedAt",
    fc."UpdatedByUserFk",
    COALESCE(
        NULLIF(
            TRIM(
                BOTH
                FROM concat(
                        COALESCE(u."PrenomUser", ''::character varying),
                        ' ',
                        COALESCE(u."NomUser", ''::character varying)
                    )
            ),
            ''::text
        ),
        CASE
            WHEN fc."UpdatedByUserFk" IS NOT NULL THEN 'Utilisateur #'::text || fc."UpdatedByUserFk"
            ELSE NULL::text
        END
    ) AS "UpdatedByName",
    fc."ObsFkCorrespondance"
FROM systeme."T_Fk_Correspondance" fc
    LEFT JOIN referentiel."T_CategorieGenerique" c ON c."ID_CategorieGenerique" = fc."TargetCategoryIdFk"
    LEFT JOIN systeme."T_Utilisateurs" u ON u."IdUser" = fc."UpdatedByUserFk";
ALTER TABLE systeme."V_Fk_Correspondance_Detail" OWNER TO postgres;
-- View: systeme.V_Fk_Correspondance
-- DROP VIEW systeme."V_Fk_Correspondance";
CREATE OR REPLACE VIEW systeme."V_Fk_Correspondance" AS
SELECT fc."ModuleName",
    fc."SchemaName",
    fc."ViewName",
    fc."SourceKey",
    fc."FieldName",
    max(fc."FieldLabel") AS "FieldLabel",
    fc."MappingType",
    max(fc."ReferenceSchemaName") AS "ReferenceSchemaName",
    max(fc."ReferenceObjectName") AS "ReferenceObjectName",
    max(fc."ReferenceFieldName") AS "ReferenceFieldName",
    string_agg(
        DISTINCT fc."MappingValue"::text,
        ', '::text
        ORDER BY fc."MappingValue"::text
    ) AS "MappingValues",
    string_agg(
        DISTINCT c."NomCategorieGenerique"::text,
        ', '::text
        ORDER BY c."NomCategorieGenerique"::text
    ) AS "CategoryLabels",
    bool_or(fc."IsDefaultMapping") AS "HasDefaultMapping",
    bool_or(fc."ValideFkCorrespondance") AS "HasActiveMapping",
    fc."SettingScope",
    fc."ScopeValue",
    count(*) AS "NbCorrespondances",
    max(fc."UpdatedAt") AS "UpdatedAt"
FROM systeme."T_Fk_Correspondance" fc
    LEFT JOIN referentiel."T_CategorieGenerique" c ON c."ID_CategorieGenerique" = fc."TargetCategoryIdFk"
GROUP BY fc."ModuleName",
    fc."SchemaName",
    fc."ViewName",
    fc."SourceKey",
    fc."FieldName",
    fc."MappingType",
    fc."SettingScope",
    fc."ScopeValue";
ALTER TABLE systeme."V_Fk_Correspondance" OWNER TO postgres;
-- View: systeme.V_Fk_Correspondance_Audit
-- DROP VIEW systeme."V_Fk_Correspondance_Audit";
CREATE OR REPLACE VIEW systeme."V_Fk_Correspondance_Audit" AS
SELECT a."IdLog",
    a."TableName",
    a."Operation",
    a."ChangedAt",
    COALESCE(
        a."NewData"->>'settingScope'::text,
        a."OldData"->>'settingScope'::text,
        'global'::text
    ) AS "SettingScope",
    COALESCE(
        a."NewData"->>'scopeValue'::text,
        a."OldData"->>'scopeValue'::text
    ) AS "ScopeValue",
    COALESCE(
        a."NewData"->>'updatedByName'::text,
        a."OldData"->>'updatedByName'::text
    ) AS "UpdatedByName",
    COALESCE(
        a."NewData"->>'updatedByUserId'::text,
        a."OldData"->>'updatedByUserId'::text
    ) AS "UpdatedByUserId",
    COALESCE(
        a."NewData"->>'updatedAt'::text,
        a."OldData"->>'updatedAt'::text
    ) AS "UpdatedSettingAt",
    a."OldData",
    a."NewData"
FROM systeme."T_Audit_Log" a
WHERE a."TableName"::text = 'T_Fk_Correspondance'::text
ORDER BY a."ChangedAt" DESC;
ALTER TABLE systeme."V_Fk_Correspondance_Audit" OWNER TO postgres;
-- View: systeme.V_Entite_Localisation_Detail
-- DROP VIEW systeme."V_Entite_Localisation_Detail";
CREATE OR REPLACE VIEW systeme."V_Entite_Localisation_Detail" AS
SELECT el."IdEntiteLocalisation",
    e."IdEntite",
    e."NomEntite",
    e."PhoneEntite",
    e."EmailEntite",
    e."AdresseEntite",
    e."IdTypeEntiteFk",
    te."NomGenerique" AS "TypeEntite",
    el."Latitude",
    el."Longitude",
    el."AdresseDetaillee",
    el."DateCreation",
    el."IdNiveau_3_Fk",
    n3."NomNiveau_3",
    el."IdNiveau_4_Fk",
    n4."NomNiveau_4",
    el."IdNiveau_5_Fk",
    n5."NomNiveau_5"
FROM systeme."T_Entite" e
    LEFT JOIN systeme."T_Entite_Localisation" el ON el."IdEntiteFk" = e."IdEntite"
    LEFT JOIN referentiel."T_Generique" te ON te."ID_Generique" = e."IdTypeEntiteFk"
    LEFT JOIN geolocalisation."T_Niveau_3" n3 ON n3."ID_Niveau_3" = el."IdNiveau_3_Fk"
    LEFT JOIN geolocalisation."T_Niveau_4" n4 ON n4."ID_Niveau_4" = el."IdNiveau_4_Fk"
    LEFT JOIN geolocalisation."T_Niveau_5" n5 ON n5."ID_Niveau_5" = el."IdNiveau_5_Fk";
ALTER TABLE systeme."V_Entite_Localisation_Detail" OWNER TO postgres;
-- View: systeme.V_Licence_active
-- DROP VIEW systeme."V_Licence_active";
CREATE OR REPLACE VIEW systeme."V_Licence_active" AS
SELECT l."IdLicence",
    l."IdEntiteFk",
    e."NomEntite",
    l."DateDebut",
    l."DateFin",
    l."ValideLicence",
    l."ExpireeLicence",
    CASE
        WHEN l."DateFin" < CURRENT_DATE THEN 'Expirée'::text
        WHEN l."ExpireeLicence" = true THEN 'Expirée'::text
        ELSE 'Active'::text
    END AS statut_licence
FROM systeme."T_Licence" l
    LEFT JOIN systeme."T_Entite" e ON e."IdEntite" = l."IdEntiteFk";
ALTER TABLE systeme."V_Licence_active" OWNER TO postgres;
-- View: systeme.V_Login_history
-- DROP VIEW systeme."V_Login_history";
CREATE OR REPLACE VIEW systeme."V_Login_history" AS
SELECT lg."IdLogin",
    lg."DateLogin",
    lg."IdTypeLoginFk",
    type_log."AbrGenerique" AS "TypeLogin",
    u."IdUser",
    u."NomUser",
    u."PrenomUser",
    u."EmailUser",
    e."IdEntite",
    e."NomEntite"
FROM systeme."T_Login" lg
    JOIN systeme."T_Utilisateurs" u ON u."IdUser" = lg."IdUserFk"
    LEFT JOIN systeme."T_Entite" e ON e."IdEntite" = lg."IdEntiteFk"
    LEFT JOIN referentiel."T_Generique" type_log ON lg."IdTypeLoginFk" = type_log."ID_Generique";
ALTER TABLE systeme."V_Login_history" OWNER TO postgres;
-- View: systeme.V_User_profil
-- DROP VIEW systeme."V_User_profil";
CREATE OR REPLACE VIEW systeme."V_User_profil" AS
SELECT u."IdUser",
    u."NomUser",
    u."PrenomUser",
    u."EmailUser",
    u."PhoneUser",
    u."SexeUser",
    u."ValideUser",
    u."Is_staff",
    u."Is_Admin",
    u."DatecreationUser",
    e."IdEntite",
    e."NomEntite",
    e."EmailEntite",
    e."PhoneEntite"
FROM systeme."T_Utilisateurs" u
    LEFT JOIN systeme."T_Entite" e ON e."IdEntite" = u."IdEntiteFk";
ALTER TABLE systeme."V_User_profil" OWNER TO postgres;
-- View: systeme.V_Admin_UI_Setting
-- DROP VIEW systeme."V_Admin_UI_Setting";
CREATE OR REPLACE VIEW systeme."V_Admin_UI_Setting" AS
SELECT s."IdAdminUISetting",
    s."SettingScope",
    s."ScopeValue",
    s."SettingKey",
    s."SettingLabel",
    s."SettingGroup",
    s."SettingValue",
    s."SettingValueJson",
    s."SettingType",
    s."DisplayOrder",
    s."IsEditable",
    s."IsSystem",
    s."ValideSetting",
    s."CreatedAt",
    s."UpdatedAt",
    s."UpdatedByUserFk",
    COALESCE(
        NULLIF(
            TRIM(
                BOTH
                FROM concat(
                        COALESCE(u."PrenomUser", ''::character varying),
                        ' ',
                        COALESCE(u."NomUser", ''::character varying)
                    )
            ),
            ''::text
        ),
        CASE
            WHEN s."UpdatedByUserFk" IS NOT NULL THEN 'Utilisateur #'::text || s."UpdatedByUserFk"
            ELSE NULL::text
        END
    ) AS "UpdatedByName",
    s."ObsSetting"
FROM systeme."T_Admin_UI_Setting" s
    LEFT JOIN systeme."T_Utilisateurs" u ON u."IdUser" = s."UpdatedByUserFk"
WHERE s."ValideSetting" = true
ORDER BY s."SettingGroup",
    s."DisplayOrder",
    s."SettingLabel";
ALTER TABLE systeme."V_Admin_UI_Setting" OWNER TO postgres;
-- View: systeme.V_Admin_UI_Setting_Group
-- DROP VIEW systeme."V_Admin_UI_Setting_Group";
CREATE OR REPLACE VIEW systeme."V_Admin_UI_Setting_Group" AS
SELECT "SettingGroup",
    count(*) AS "NbParametres",
    count(*) FILTER (
        WHERE "IsEditable" = true
    ) AS "NbEditables",
    count(*) FILTER (
        WHERE "IsSystem" = true
    ) AS "NbSysteme",
    max("UpdatedAt") AS "DerniereModification"
FROM systeme."T_Admin_UI_Setting"
WHERE "ValideSetting" = true
GROUP BY "SettingGroup"
ORDER BY "SettingGroup";
ALTER TABLE systeme."V_Admin_UI_Setting_Group" OWNER TO postgres;
-- View: systeme.V_Admin_UI_Setting_Audit
-- DROP VIEW systeme."V_Admin_UI_Setting_Audit";
CREATE OR REPLACE VIEW systeme."V_Admin_UI_Setting_Audit" AS
SELECT "IdLog",
    "TableName",
    "Operation",
    "ChangedAt",
    COALESCE(
        "NewData"->>'settingScope'::text,
        "OldData"->>'settingScope'::text,
        'global'::text
    ) AS "SettingScope",
    COALESCE(
        "NewData"->>'scopeValue'::text,
        "OldData"->>'scopeValue'::text
    ) AS "ScopeValue",
    COALESCE(
        "NewData"->>'settingKey'::text,
        "OldData"->>'settingKey'::text
    ) AS "SettingKey",
    COALESCE(
        "NewData"->>'settingLabel'::text,
        "OldData"->>'settingLabel'::text
    ) AS "SettingLabel",
    COALESCE(
        "NewData"->>'settingGroup'::text,
        "OldData"->>'settingGroup'::text
    ) AS "SettingGroup",
    COALESCE(
        "NewData"->>'settingValue'::text,
        "OldData"->>'settingValue'::text
    ) AS "SettingValue",
    COALESCE(
        "NewData"->>'updatedByName'::text,
        "OldData"->>'updatedByName'::text
    ) AS "UpdatedByName",
    COALESCE(
        "NewData"->>'updatedByUserId'::text,
        "OldData"->>'updatedByUserId'::text
    ) AS "UpdatedByUserId",
    COALESCE(
        "NewData"->>'updatedAt'::text,
        "OldData"->>'updatedAt'::text
    ) AS "UpdatedSettingAt",
    "OldData",
    "NewData"
FROM systeme."T_Audit_Log" a
WHERE "TableName" = 'T_Admin_UI_Setting'::text
ORDER BY "ChangedAt" DESC;
ALTER TABLE systeme."V_Admin_UI_Setting_Audit" OWNER TO postgres;