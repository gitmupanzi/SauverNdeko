-- Libellés catégoriels Support : AbrGenerique, sans modification des références.
BEGIN;
SET LOCAL lock_timeout='10s';
DO $$
DECLARE item record; definition text; expression text; target_type text; existing text;
BEGIN
 IF current_database()<>'SauverNdeko' AND current_database() NOT LIKE 'sauverndeko_test_%' THEN
  RAISE EXCEPTION 'Base non autorisée';
 END IF;
 -- Les seuls alias remplacés sont des projections de libellés. Les codes du
 -- circuit, les clés, filtres de visibilité et règles d’état restent inchangés.
 FOR item IN SELECT * FROM (VALUES
  ('V_Support','typ','TypeSupport'),('V_Support','cat','CategorieSupport'),
  ('V_Support','pri','Priorite'),('V_Support','sta','Statut'),
  ('V_Support','can','CanalOrigine'),('V_Support','ser','ServiceConcerne'),
  ('V_ResolutionSupport','g','ResultatVerification')) AS changes(view_name,source_alias,column_name)
 LOOP
  IF to_regclass(format('support.%I',item.view_name)) IS NULL THEN
   RAISE EXCEPTION 'Vue Support requise : %',item.view_name;
  END IF;
  SELECT format_type(atttypid,atttypmod) INTO target_type FROM pg_attribute
   WHERE attrelid=to_regclass(format('support.%I',item.view_name))
    AND attname=item.column_name AND attnum>0 AND NOT attisdropped;
  IF target_type IS NULL THEN RAISE EXCEPTION 'Colonne Support requise : %',item.column_name;END IF;
  SELECT rtrim(pg_get_viewdef(to_regclass(format('support.%I',item.view_name)),true),E';\n ') INTO definition;
  expression:=format('(CASE WHEN %1$I."ID_Generique" IS NULL THEN NULL ELSE coalesce(nullif(btrim(%1$I."AbrGenerique"),''''),''Valeur sans abréviation #''||%1$I."ID_Generique"::text) END)::%2$s',item.source_alias,target_type);
  existing:=format('%I."NomGenerique"',item.source_alias);
  IF position(existing IN definition)>0 THEN
   definition:=replace(definition,existing,expression);
   EXECUTE format('CREATE OR REPLACE VIEW support.%I AS %s',item.view_name,definition);
  ELSIF position('Valeur sans abréviation #' IN definition)=0 THEN
   RAISE EXCEPTION 'Projection de libellé Support inattendue : %.%',item.view_name,item.column_name;
  END IF;
  EXECUTE format('COMMENT ON COLUMN support.%I.%I IS %L',item.view_name,item.column_name,
   'Libellé courant de la valeur centrale liée : AbrGenerique nettoyée, ou indication neutre avec ID_Generique si elle manque. Les identifiants, codes du circuit et données historiques ne sont pas réécrits.');
 END LOOP;
END $$;
COMMIT;
