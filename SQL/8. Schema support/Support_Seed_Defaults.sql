-- Installation vierge uniquement, après références.sql et correspondances.sql.
-- Valeur standard issue du dictionnaire livré ; aucune surcharge client source.
BEGIN;
INSERT INTO systeme."T_Admin_UI_Setting"("SettingScope","SettingKey","SettingLabel","SettingGroup","SettingType","SettingValueJson","IsEditable","IsSystem","ValideSetting","ObsSetting")
SELECT 'global','support.workflow','Circuit de traitement du Support','support','json',systeme.fn_support_circuit_defaut(),true,true,true,'Circuit initial standard d’installation ; les nouvelles copies par dossier conservent sa version.'
WHERE NOT EXISTS(SELECT FROM systeme."T_Admin_UI_Setting" WHERE "SettingScope"='global' AND "ScopeValue" IS NULL AND "SettingKey"='support.workflow');
COMMIT;
