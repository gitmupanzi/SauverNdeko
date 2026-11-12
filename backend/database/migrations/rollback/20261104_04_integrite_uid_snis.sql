-- Retire uniquement les contrôles ajoutés ; aucune identité ou preuve effacée.
-- La documentation de la colonne reste utile. Pour un retour exact de toutes
-- les métadonnées, restaurer la sauvegarde préalable vérifiée.
BEGIN;
SET LOCAL lock_timeout='10s';
DO $$ DECLARE level integer; BEGIN
 IF current_database()<>'SauverNdeko' AND current_database() NOT LIKE 'sauverndeko_test_%' THEN RAISE EXCEPTION 'Base non autorisée';END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('geolocalisation:uid-snis-installation',0));
 FOREACH level IN ARRAY ARRAY[1,3,4] LOOP
  EXECUTE format('DROP TRIGGER IF EXISTS uid_snis_integrite ON geolocalisation.%I','T_Niveau_'||level);
  EXECUTE format('DROP INDEX IF EXISTS geolocalisation.%I','uq_uid_snis_niveau_'||level);
 END LOOP;
END $$;
DROP FUNCTION IF EXISTS geolocalisation.tr_uid_snis_integrite();
COMMIT;
