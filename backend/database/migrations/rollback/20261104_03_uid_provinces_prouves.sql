-- Retour conditionnel du seul lot provincial 03, sans effacer son historique.
-- À exécuter après examen DBA, avant toute autre correction de ces provinces.
BEGIN;
SET LOCAL lock_timeout='10s';
SET LOCAL statement_timeout='120s';
SELECT pg_advisory_xact_lock(hashtextextended('geolocalisation:hierarchy-writes',0));
DO $rollback$
DECLARE event record; item jsonb; old_item jsonb; actual jsonb; actor integer;
BEGIN
 IF current_database()<>'SauverNdeko' AND current_database() NOT LIKE 'sauverndeko_test_%' THEN
  RAISE EXCEPTION 'Base non autorisée';
 END IF;
 IF current_database()='SauverNdeko' THEN
  actor := systeme.fn_admin_actor_user_id();
  IF actor IS NULL OR NOT EXISTS(SELECT FROM systeme."T_Utilisateurs" WHERE "IdUser"=actor AND "Is_Admin" IS TRUE AND "ValideUser" IS TRUE) THEN
   RAISE EXCEPTION 'Acteur administrateur global actif requis';
  END IF;
 END IF;
 SELECT a.* INTO event FROM systeme."T_Audit_Log" a
  WHERE a."TableName"='geolocalisation.T_Niveau_1' AND a."Operation"='SNIS_PROVINCE_UID_20261104'
   AND NOT EXISTS(SELECT FROM systeme."T_Audit_Log" r WHERE r."Operation"='SNIS_PROVINCE_UID_20261104_RETOUR'
    AND r."NewData"->>'applicationLogId'=a."IdLog"::text)
  ORDER BY a."IdLog" DESC LIMIT 1;
 IF NOT FOUND THEN RETURN; END IF;
 IF jsonb_typeof(event."OldData")<>'array' OR jsonb_typeof(event."NewData"->'rows')<>'array'
  OR jsonb_array_length(event."OldData")<>jsonb_array_length(event."NewData"->'rows') THEN
  RAISE EXCEPTION 'Journal de reprise non conforme';
 END IF;
 FOR item IN SELECT value FROM jsonb_array_elements(event."NewData"->'rows') LOOP
  SELECT to_jsonb(t) INTO actual FROM geolocalisation."T_Niveau_1" t
   WHERE "ID_Niveau_1"=(item->>'ID_Niveau_1')::integer FOR UPDATE;
  IF actual IS DISTINCT FROM item THEN
   RAISE EXCEPTION 'Province % modifiée depuis la reprise ; retour automatique refusé',item->>'ID_Niveau_1';
  END IF;
  SELECT value INTO old_item FROM jsonb_array_elements(event."OldData") WHERE value->>'ID_Niveau_1'=item->>'ID_Niveau_1';
  IF old_item IS NULL OR (old_item-'uidSNIS') IS DISTINCT FROM (item-'uidSNIS') THEN
   RAISE EXCEPTION 'État antérieur non conforme';
  END IF;
  UPDATE geolocalisation."T_Niveau_1" SET "uidSNIS"=old_item->>'uidSNIS' WHERE "ID_Niveau_1"=(item->>'ID_Niveau_1')::integer;
 END LOOP;
 INSERT INTO systeme."T_Audit_Log"("TableName","Operation","OldData","NewData") VALUES
  ('geolocalisation.T_Niveau_1','SNIS_PROVINCE_UID_20261104_RETOUR',event."NewData"->'rows',
   jsonb_build_object('applicationLogId',event."IdLog",'rows',event."OldData",'_actor',jsonb_build_object('IdUser',actor)));
END $rollback$;
COMMIT;
