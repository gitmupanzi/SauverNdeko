-- Complément documentaire des objets d'administration créés par la migration 11.
-- Aucune donnée ni règle n'est modifiée ; conserver la migration 11 déjà appliquée.
BEGIN;
SET LOCAL lock_timeout='10s';
SET LOCAL statement_timeout='30s';
DO $$ BEGIN
 IF to_regprocedure('systeme.fn_admin_reglage_audit()') IS NULL THEN
  RAISE EXCEPTION 'La migration 20261026_11 doit être installée avant ses commentaires';
 END IF;
END $$;

COMMENT ON INDEX systeme."Uq_Admin_UI_Setting_Key_Scope" IS 'Index unique de la clé de paramètre par portée et contexte ; NULLS NOT DISTINCT interdit aussi les doublons globaux.';
COMMENT ON INDEX systeme."UQ_FkCorrespondance_SourceValueScope" IS 'Index unique de la correspondance source/valeur/portée ; une vue ou un contexte NULL ne permet pas de doublon.';
COMMENT ON COLUMN systeme."T_Admin_UI_Setting"."CreatedAt" IS 'Instant de création imposé par PostgreSQL ; conservé lors des modifications ultérieures.';

COMMENT ON COLUMN systeme."V_Admin_UI_Setting_Audit"."IdLog" IS 'Identifiant stable de l’événement de T_Audit_Log.';
COMMENT ON COLUMN systeme."V_Admin_UI_Setting_Audit"."TableName" IS 'Table de paramètres concernée par l’événement.';
COMMENT ON COLUMN systeme."V_Admin_UI_Setting_Audit"."Operation" IS 'Opération SQL INSERT, UPDATE ou DELETE enregistrée.';
COMMENT ON COLUMN systeme."V_Admin_UI_Setting_Audit"."ChangedAt" IS 'Date et heure civiles de l’événement ; les nouveaux triggers utilisent Africa/Kinshasa.';
COMMENT ON COLUMN systeme."V_Admin_UI_Setting_Audit"."SettingScope" IS 'Portée du paramètre, extraite de la ligne SQL ou de l’image applicative historique.';
COMMENT ON COLUMN systeme."V_Admin_UI_Setting_Audit"."ScopeValue" IS 'Contexte de la portée ; NULL pour un paramètre global.';
COMMENT ON COLUMN systeme."V_Admin_UI_Setting_Audit"."SettingKey" IS 'Clé du paramètre extraite des images avant ou après l’écriture.';
COMMENT ON COLUMN systeme."V_Admin_UI_Setting_Audit"."SettingLabel" IS 'Libellé du paramètre au moment de l’événement.';
COMMENT ON COLUMN systeme."V_Admin_UI_Setting_Audit"."SettingGroup" IS 'Groupe du paramètre au moment de l’événement.';
COMMENT ON COLUMN systeme."V_Admin_UI_Setting_Audit"."SettingValue" IS 'Valeur après l’écriture, avant pour DELETE ; NULL explicite conservé et valeur sensible masquée.';
COMMENT ON COLUMN systeme."V_Admin_UI_Setting_Audit"."UpdatedByName" IS 'Nom de l’auteur de l’opération SQL, sinon auteur déclaré par l’ancien format applicatif ; absence conservée.';
COMMENT ON COLUMN systeme."V_Admin_UI_Setting_Audit"."UpdatedByUserId" IS 'Identifiant textuel de l’auteur de l’opération, distinct du dernier modificateur de la ligne supprimée.';
COMMENT ON COLUMN systeme."V_Admin_UI_Setting_Audit"."UpdatedSettingAt" IS 'Horodatage de la ligne de paramètre extrait de l’image SQL ou du format historique ; texte conservé.';
COMMENT ON COLUMN systeme."V_Admin_UI_Setting_Audit"."OldData" IS 'Image avant l’écriture, nettoyée récursivement à la lecture ; NULL pour INSERT.';
COMMENT ON COLUMN systeme."V_Admin_UI_Setting_Audit"."NewData" IS 'Image après l’écriture, nettoyée récursivement à la lecture ; NULL pour DELETE.';

COMMENT ON COLUMN systeme."V_Fk_Correspondance_Audit"."IdLog" IS 'Identifiant stable de l’événement de T_Audit_Log.';
COMMENT ON COLUMN systeme."V_Fk_Correspondance_Audit"."TableName" IS 'Table de correspondances concernée par l’événement.';
COMMENT ON COLUMN systeme."V_Fk_Correspondance_Audit"."Operation" IS 'Opération SQL INSERT, UPDATE ou DELETE enregistrée.';
COMMENT ON COLUMN systeme."V_Fk_Correspondance_Audit"."ChangedAt" IS 'Date et heure civiles de l’événement ; les nouveaux triggers utilisent Africa/Kinshasa.';
COMMENT ON COLUMN systeme."V_Fk_Correspondance_Audit"."SettingScope" IS 'Portée FK global, country ou entity, compatible avec l’ancien format applicatif.';
COMMENT ON COLUMN systeme."V_Fk_Correspondance_Audit"."ScopeValue" IS 'Contexte de la portée FK ; NULL pour une correspondance globale.';
COMMENT ON COLUMN systeme."V_Fk_Correspondance_Audit"."UpdatedByName" IS 'Nom de l’auteur de l’opération SQL, sinon auteur déclaré par l’ancien format applicatif ; absence conservée.';
COMMENT ON COLUMN systeme."V_Fk_Correspondance_Audit"."UpdatedByUserId" IS 'Identifiant textuel de l’auteur de l’opération, distinct du dernier modificateur de la ligne supprimée.';
COMMENT ON COLUMN systeme."V_Fk_Correspondance_Audit"."UpdatedSettingAt" IS 'Horodatage de la correspondance extrait de l’image SQL ou du format historique ; texte conservé.';
COMMENT ON COLUMN systeme."V_Fk_Correspondance_Audit"."OldData" IS 'Image avant l’écriture, nettoyée récursivement à la lecture ; NULL pour INSERT.';
COMMENT ON COLUMN systeme."V_Fk_Correspondance_Audit"."NewData" IS 'Image après l’écriture, nettoyée récursivement à la lecture ; NULL pour DELETE.';
COMMIT;
