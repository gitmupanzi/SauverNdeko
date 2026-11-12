-- Réparer les identités territoriales après reprise historique avec IDs explicites.
-- Aucun identifiant ni aucune ligne n'est réécrit. RESTART est transactionnel.
BEGIN;
SET LOCAL lock_timeout='10s';
SET LOCAL statement_timeout='120s';
DO $$ BEGIN
 IF current_database()<>'SauverNdeko' AND current_database() NOT LIKE 'sauverndeko_test_%' THEN
  RAISE EXCEPTION 'Base non autorisée';
 END IF;
END $$;

DO $$ DECLARE suffix text; table_name text; column_name text; sequence_name text;
 maximum_id bigint; last_id bigint; called boolean; next_id bigint;
 increment_id bigint; ceiling_id bigint; cache_size bigint; cycling boolean;
BEGIN
 -- L'ordre commun empêche deux installations concurrentes de prendre les
 -- tables dans un ordre différent. Les INSERT ordinaires attendent ce verrou.
 FOREACH suffix IN ARRAY ARRAY['0','1','1_Old','2','3','4','5'] LOOP
  table_name:='T_Niveau_'||suffix;
  IF to_regclass(format('geolocalisation.%I',table_name)) IS NULL THEN
   RAISE EXCEPTION 'Table territoriale requise : %',table_name;
  END IF;
  EXECUTE format('LOCK TABLE geolocalisation.%I IN ACCESS EXCLUSIVE MODE',table_name);
 END LOOP;
 FOREACH suffix IN ARRAY ARRAY['0','1','1_Old','2','3','4','5'] LOOP
  table_name:='T_Niveau_'||suffix;column_name:='ID_Niveau_'||suffix;
  sequence_name:=pg_get_serial_sequence(format('geolocalisation.%I',table_name),column_name);
  IF sequence_name IS NULL THEN RAISE EXCEPTION 'Identité territoriale requise : %.%',table_name,column_name;END IF;
  SELECT seqincrement,seqmax,seqcache,seqcycle INTO increment_id,ceiling_id,cache_size,cycling
   FROM pg_sequence WHERE seqrelid=sequence_name::regclass;
  IF increment_id<>1 OR cycling THEN
   RAISE EXCEPTION 'Séquence territoriale non standard : % ; examen requis sans changement.',sequence_name;
  END IF;
  EXECUTE format('SELECT max(%I)::bigint FROM geolocalisation.%I',column_name,table_name) INTO maximum_id;
  IF maximum_id IS NULL THEN CONTINUE;END IF;
  EXECUTE format('SELECT last_value,is_called FROM %s',sequence_name) INTO last_id,called;
  next_id:=last_id+CASE WHEN called THEN increment_id ELSE 0 END;
  IF next_id<=maximum_id THEN
   -- Reprendre la valeur existante de CACHE obtient le verrou de séquence sans
   -- changer son paramétrage ; relire ensuite protège aussi d'un nextval direct.
   -- Aucun setval n'est employé : une annulation restaure l'état antérieur.
   EXECUTE format('ALTER SEQUENCE %s CACHE %s',sequence_name,cache_size);
   EXECUTE format('SELECT last_value,is_called FROM %s',sequence_name) INTO last_id,called;
   next_id:=last_id+CASE WHEN called THEN increment_id ELSE 0 END;
   IF next_id<=maximum_id THEN
    IF maximum_id>=ceiling_id THEN RAISE EXCEPTION 'Séquence territoriale épuisée : %',sequence_name;END IF;
    EXECUTE format('ALTER SEQUENCE %s RESTART WITH %s',sequence_name,maximum_id+1);
   END IF;
  END IF;
 END LOOP;
END $$;
COMMIT;
