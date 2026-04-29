-- Table: systeme.T_Fk_Correspondance
-- Standardise les correspondances FK et les comportements de listes
-- pour l'ensemble des modules et vues de l'application.

-- DROP TABLE IF EXISTS systeme."T_Fk_Correspondance";

CREATE TABLE IF NOT EXISTS systeme."T_Fk_Correspondance"
(
    "IdFkCorrespondance" integer NOT NULL GENERATED ALWAYS AS IDENTITY
        ( INCREMENT 1 START 1 MINVALUE 1 MAXVALUE 2147483647 CACHE 1 ),
    "ModuleName" character varying(80) COLLATE pg_catalog."default" NOT NULL,
    "SchemaName" character varying(80) COLLATE pg_catalog."default" NOT NULL,
    "ViewName" character varying(120) COLLATE pg_catalog."default",
    "SourceKey" character varying(120) COLLATE pg_catalog."default" NOT NULL,
    "FieldName" character varying(120) COLLATE pg_catalog."default" NOT NULL,
    "FieldLabel" character varying(255) COLLATE pg_catalog."default",
    "MappingType" character varying(40) COLLATE pg_catalog."default" NOT NULL DEFAULT 'generic_category'::character varying,
    "ReferenceSchemaName" character varying(80) COLLATE pg_catalog."default",
    "ReferenceObjectName" character varying(120) COLLATE pg_catalog."default",
    "ReferenceFieldName" character varying(120) COLLATE pg_catalog."default",
    "TargetCategoryIdFk" integer,
    "MappingValue" character varying(120) COLLATE pg_catalog."default" NOT NULL,
    "IsDefaultMapping" boolean NOT NULL DEFAULT false,
    "ValideFkCorrespondance" boolean NOT NULL DEFAULT true,
    "SettingScope" character varying(60) COLLATE pg_catalog."default" NOT NULL DEFAULT 'global'::character varying,
    "ScopeValue" character varying(120) COLLATE pg_catalog."default",
    "DisplayOrder" integer NOT NULL DEFAULT 0,
    "UpdatedAt" timestamp(6) without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "UpdatedByUserFk" integer,
    "ObsFkCorrespondance" text COLLATE pg_catalog."default",
    CONSTRAINT "T_Fk_Correspondance_pkey" PRIMARY KEY ("IdFkCorrespondance"),
    CONSTRAINT "UQ_FkCorrespondance_SourceValueScope" UNIQUE
    (
        "ModuleName",
        "SchemaName",
        "ViewName",
        "SourceKey",
        "FieldName",
        "MappingType",
        "MappingValue",
        "SettingScope",
        "ScopeValue"
    ),
    CONSTRAINT "Fk_FkCorrespondance_Category" FOREIGN KEY ("TargetCategoryIdFk")
        REFERENCES referentiel."T_CategorieGenerique" ("ID_CategorieGenerique") MATCH SIMPLE
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT "Fk_FkCorrespondance_User" FOREIGN KEY ("UpdatedByUserFk")
        REFERENCES systeme."T_Utilisateurs" ("IdUser") MATCH SIMPLE
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT "chk_fkcorrespondance_mappingtype" CHECK
    (
        "MappingType"::text = ANY
        (
            ARRAY[
                'generic_category'::character varying,
                'direct_source'::character varying,
                'hierarchy_mode'::character varying
            ]::text[]
        )
    ),
    CONSTRAINT "chk_fkcorrespondance_scope" CHECK
    (
        "SettingScope"::text = ANY
        (
            ARRAY[
                'global'::character varying,
                'country'::character varying,
                'entity'::character varying
            ]::text[]
        )
    )
);

ALTER TABLE IF EXISTS systeme."T_Fk_Correspondance"
    OWNER to postgres;

CREATE INDEX IF NOT EXISTS idx_fkcorrespondance_source
    ON systeme."T_Fk_Correspondance" USING btree
    ("SchemaName" ASC NULLS LAST, "ViewName" ASC NULLS LAST, "SourceKey" ASC NULLS LAST)
    TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_fkcorrespondance_scope
    ON systeme."T_Fk_Correspondance" USING btree
    ("SettingScope" ASC NULLS LAST, "ScopeValue" ASC NULLS LAST)
    TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_fkcorrespondance_category
    ON systeme."T_Fk_Correspondance" USING btree
    ("TargetCategoryIdFk" ASC NULLS LAST)
    TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_fkcorrespondance_updatedby
    ON systeme."T_Fk_Correspondance" USING btree
    ("UpdatedByUserFk" ASC NULLS LAST)
    TABLESPACE pg_default;
