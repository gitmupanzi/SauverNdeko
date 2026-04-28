-- Table: systeme.T_Admin_UI_Setting
-- DROP TABLE IF EXISTS systeme."T_Admin_UI_Setting";

CREATE TABLE IF NOT EXISTS systeme."T_Admin_UI_Setting"
(
    "IdAdminUiSetting" integer NOT NULL GENERATED ALWAYS AS IDENTITY
        ( INCREMENT 1 START 1 MINVALUE 1 MAXVALUE 2147483647 CACHE 1 ),
    "SettingKey" character varying(120) COLLATE pg_catalog."default" NOT NULL,
    "SettingScope" character varying(60) COLLATE pg_catalog."default" NOT NULL DEFAULT 'global',
    "ScopeValue" character varying(120) COLLATE pg_catalog."default",
    "SettingValue" jsonb NOT NULL DEFAULT '{}'::jsonb,
    "UpdatedAt" timestamp(6) without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "UpdatedByUserFk" integer,
    "ObsAdminUiSetting" text COLLATE pg_catalog."default",
    CONSTRAINT "T_Admin_UI_Setting_pkey" PRIMARY KEY ("IdAdminUiSetting"),
    CONSTRAINT "UQ_AdminUiSetting_Scope" UNIQUE ("SettingKey", "SettingScope", "ScopeValue"),
    CONSTRAINT "Fk_AdminUiSetting_User" FOREIGN KEY ("UpdatedByUserFk")
        REFERENCES systeme."T_Utilisateurs" ("IdUser") MATCH SIMPLE
        ON UPDATE CASCADE
        ON DELETE SET NULL
);

ALTER TABLE IF EXISTS systeme."T_Admin_UI_Setting"
    OWNER to postgres;

CREATE INDEX IF NOT EXISTS "idx_adminuisetting_updatedby"
    ON systeme."T_Admin_UI_Setting"("UpdatedByUserFk");
