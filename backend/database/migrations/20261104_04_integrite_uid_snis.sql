-- Identifiants SNIS/DHIS2 canoniques : validation des nouvelles saisies et
-- unicité locale par niveau N1/N3/N4. Aucun UID ni parent n'est créé ou déplacé.
-- La concordance INTER-NIVEAUX et avec les sources reste contrôlée par l'import
-- documenté ; ce script ne prétend pas garantir cette concordance concurrente.
BEGIN;
SET LOCAL lock_timeout='10s';
SET LOCAL statement_timeout='120s';
DO $$ DECLARE level integer; tab text; invalid_count bigint; duplicate_count bigint; BEGIN
 IF current_database()<>'SauverNdeko' AND current_database() NOT LIKE 'sauverndeko_test_%' THEN RAISE EXCEPTION 'Base non autorisée';END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('geolocalisation:uid-snis-installation',0));
 FOREACH level IN ARRAY ARRAY[1,3,4] LOOP
  tab:='T_Niveau_'||level;
  EXECUTE format('SELECT count(*) FROM geolocalisation.%I WHERE nullif(btrim("uidSNIS"),'''') IS NOT NULL AND "uidSNIS" !~ ''^[A-Za-z][A-Za-z0-9]{10}$''',tab) INTO invalid_count;
  EXECUTE format('SELECT count(*) FROM (SELECT btrim("uidSNIS") FROM geolocalisation.%I WHERE nullif(btrim("uidSNIS"),'''') IS NOT NULL GROUP BY 1 HAVING count(*)>1) d',tab) INTO duplicate_count;
  IF invalid_count>0 OR duplicate_count>0 THEN
   RAISE EXCEPTION 'Installation UID refusée pour % : % valeurs invalides, % groupes en doublon ; examiner les preuves avant correction.',tab,invalid_count,duplicate_count;
  END IF;
 END LOOP;
END $$;

CREATE OR REPLACE FUNCTION geolocalisation.tr_uid_snis_integrite()
RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $$
BEGIN
 -- Une modification descriptive n'oblige pas à réécrire une identité historique.
 IF TG_OP='UPDATE' AND NEW."uidSNIS" IS NOT DISTINCT FROM OLD."uidSNIS" THEN RETURN NEW;END IF;
 IF NEW."uidSNIS" IS NULL THEN RETURN NEW;END IF;
 IF NEW."uidSNIS" !~ '^[A-Za-z][A-Za-z0-9]{10}$' THEN
  RAISE EXCEPTION 'Identifiant SNIS invalide : saisir les 11 caractères DHIS2 (une lettre puis lettres ou chiffres), ou laisser vide.' USING ERRCODE='23514', CONSTRAINT='ck_uid_snis_format';
 END IF;
 RETURN NEW;
END $$;
COMMENT ON FUNCTION geolocalisation.tr_uid_snis_integrite() IS 'Contrôle des nouveaux UID SNIS/DHIS2 N1/N3/N4 : NULL ou 11 caractères, première lettre, sans espaces et avec casse conservée. Les valeurs inchangées sont conservées ; une correction d’UID valide reste possible sous les droits et audits métier existants. Ne valide pas la correspondance scientifique d’un UID ni son unicité entre niveaux.';

DO $$ DECLARE level integer; tab text; idx text; BEGIN
 FOREACH level IN ARRAY ARRAY[1,3,4] LOOP
  tab:='T_Niveau_'||level;idx:='uq_uid_snis_niveau_'||level;
  EXECUTE format('CREATE UNIQUE INDEX IF NOT EXISTS %I ON geolocalisation.%I (btrim("uidSNIS")) WHERE nullif(btrim("uidSNIS"),'''') IS NOT NULL',idx,tab);
  IF NOT EXISTS(SELECT FROM pg_trigger WHERE tgrelid=to_regclass(format('geolocalisation.%I',tab)) AND tgname='uid_snis_integrite' AND NOT tgisinternal) THEN
   EXECUTE format('CREATE TRIGGER uid_snis_integrite BEFORE INSERT OR UPDATE OF "uidSNIS" ON geolocalisation.%I FOR EACH ROW EXECUTE FUNCTION geolocalisation.tr_uid_snis_integrite()',tab);
  END IF;
  EXECUTE format('COMMENT ON INDEX geolocalisation.%I IS %L',idx,'Unicité locale d’un UID SNIS non vide dans ce niveau territorial, casse conservée. Plusieurs NULL restent possibles. Ne garantit pas l’unicité inter-niveaux ni la correspondance avec une source externe.');
  EXECUTE format('COMMENT ON TRIGGER uid_snis_integrite ON geolocalisation.%I IS %L',tab,'Refuse un nouvel UID SNIS mal formé, conserve les valeurs inchangées et les NULL ; correction explicite toujours possible.');
  EXECUTE format('COMMENT ON COLUMN geolocalisation.%I."uidSNIS" IS %L',tab,'Identifiant SNIS/DHIS2 propre à cette identité territoriale, NULL si non rapprochée avec preuve. Les nouvelles valeurs ont 11 caractères (lettre puis lettres ou chiffres), sans espaces ; leur casse est significative. Unique localement dans ce niveau, sans copie vers un bureau, une autre organisation ou un autre niveau. L’import vérifie aussi la cohérence inter-niveaux et la provenance.');
 END LOOP;
END $$;
COMMIT;
