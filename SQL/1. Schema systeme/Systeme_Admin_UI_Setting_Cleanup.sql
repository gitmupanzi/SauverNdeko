-- Cleanup legacy admin UI FK storage
-- A executer uniquement apres verification que :
-- 1. le backend tourne avec la nouvelle logique T_Fk_Correspondance
-- 2. les ecrans Admin et Logistique lisent bien les correspondances
-- 3. les donnees ont ete migrees ou regenerees dans systeme."T_Fk_Correspondance"
-- 4. si l'ancienne table contenait des reglages, executer d'abord
--    Systeme_FK_Correspondance_Backfill.sql si le backend ne l'a pas deja fait

DO $$
DECLARE
    v_new_count integer := 0;
    v_old_count integer := 0;
    v_has_legacy_table boolean := false;
BEGIN
    SELECT to_regclass('systeme."T_Admin_UI_Setting"') IS NOT NULL
    INTO v_has_legacy_table;

    SELECT COUNT(*)::integer
    INTO v_new_count
    FROM systeme."T_Fk_Correspondance"
    WHERE "MappingType" IN ('generic_category', 'hierarchy_mode');

    IF v_has_legacy_table THEN
        SELECT COUNT(*)::integer
        INTO v_old_count
        FROM systeme."T_Admin_UI_Setting"
        WHERE "SettingKey" = 'admin-ui.select-settings';
    END IF;

    IF COALESCE(v_new_count, 0) <= 0 AND COALESCE(v_old_count, 0) > 0 THEN
        RAISE EXCEPTION
            'Cleanup annule : % reglage(s) legacy detecte(s) dans T_Admin_UI_Setting et aucune correspondance geree dans T_Fk_Correspondance. Executez Systeme_FK_Correspondance_Backfill.sql ou redemarrez le backend avant suppression.',
            v_old_count;
    END IF;
END $$;

DROP VIEW IF EXISTS systeme."V_Admin_UI_Setting_Audit";
DROP TABLE IF EXISTS systeme."T_Admin_UI_Setting";
