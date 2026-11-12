-- Retour arrière ADDITIF, uniquement avant toute conservation de preuves.
-- Si des preuves existent, restaurer la sauvegarde vérifiée ou prévoir une
-- migration inverse contrôlée ; ne jamais les supprimer avec CASCADE.
BEGIN;
SET LOCAL lock_timeout='10s';
DO $$ DECLARE tab text; populated boolean; BEGIN
 IF current_database()<>'SauverNdeko' AND current_database() NOT LIKE 'sauverndeko_test_%' THEN RAISE EXCEPTION 'Base non autorisée';END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('geolocalisation:rapprochement-installation',0));
 FOREACH tab IN ARRAY ARRAY['T_LienTerritorial','T_CorrespondanceTerritoriale','T_SourceRapprochementTerritorial'] LOOP
  IF to_regclass(format('geolocalisation.%I',tab)) IS NOT NULL THEN
   EXECUTE format('LOCK TABLE geolocalisation.%I IN ACCESS EXCLUSIVE MODE',tab);
   EXECUTE format('SELECT EXISTS(SELECT FROM geolocalisation.%I)',tab) INTO populated;
   IF populated THEN RAISE EXCEPTION 'Retour arrière refusé : % conserve des preuves à préserver.',tab;END IF;
  END IF;
 END LOOP;
END $$;
DROP VIEW IF EXISTS geolocalisation."V_PyramideSanitaireRapprochee";
DROP TABLE IF EXISTS geolocalisation."T_LienTerritorial";
DROP TABLE IF EXISTS geolocalisation."T_CorrespondanceTerritoriale";
DROP TABLE IF EXISTS geolocalisation."T_SourceRapprochementTerritorial";
DROP FUNCTION IF EXISTS geolocalisation.tr_rapprochement_territorial_integrite();
COMMIT;
