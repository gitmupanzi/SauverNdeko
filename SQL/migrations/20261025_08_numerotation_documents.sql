-- 20261025_08 : numérotation courte des bons et factures, existants et futurs.
-- Autorisation du propriétaire : tous les codes actuels deviennent cmd-ID / fac-IDBon.
-- Aucun prix, quantité, date, lot, mouvement, facture émise ou paiement n’est recalculé.
-- Mapping ancien/nouveau appendé au journal existant ; aucun audit historique réécrit.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='60s';
SET LOCAL search_path=pg_catalog;
DO $preflight$
BEGIN
 IF current_database()<>'SauverNdeko' AND current_database() NOT LIKE 'sauverndeko_test_%' THEN RAISE EXCEPTION 'Base hors périmètre'; END IF;
 IF to_regclass('logistique."T_Facture"') IS NULL OR to_regclass('logistique."T_RetourBon"') IS NULL THEN
  RAISE EXCEPTION 'Migrations06/07 requises'; END IF;
 IF to_regprocedure('logistique.fn_code_commande(integer)') IS NOT NULL OR to_regprocedure('logistique.fn_code_facture(integer)') IS NOT NULL
 OR to_regprocedure('logistique.fn_reserver_identite_commande()') IS NOT NULL THEN RAISE EXCEPTION 'Numérotation08 déjà présente ou installation partielle'; END IF;
 IF md5(pg_get_functiondef('logistique.proteger_bon_retour()'::regprocedure))<>'03c8587330a5d99bce059651d2f3559b' THEN RAISE EXCEPTION 'Garde proteger_bon_retour modifiée depuis la revue'; END IF;
 IF md5(pg_get_functiondef('logistique.tr_proteger_bon_facture()'::regprocedure))<>'274e1bd79c90e046396abec7e05f0a28' THEN RAISE EXCEPTION 'Garde tr_proteger_bon_facture modifiée depuis la revue'; END IF;
 IF md5(pg_get_functiondef('logistique.tr_proteger_facture()'::regprocedure))<>'9a2bd85002410a400bafbbc7d4fb6426' THEN RAISE EXCEPTION 'Garde tr_proteger_facture modifiée depuis la revue'; END IF;
 IF md5(pg_get_functiondef('logistique.tr_lock_commande_cloturee()'::regprocedure))<>'500904388ed6eae1d9c4efe12614d7ae' THEN RAISE EXCEPTION 'Garde tr_lock_commande_cloturee modifiée depuis la revue'; END IF;
 IF md5(pg_get_functiondef('logistique.tr_devise_reglement()'::regprocedure))<>'723b2d1d65c22f27a3d812d1ee6fd948' THEN RAISE EXCEPTION 'Garde tr_devise_reglement modifiée depuis la revue'; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='logistique."T_Reglements"'::regclass AND conname='Fk_CodeFacture'
  AND pg_get_constraintdef(oid,true)='FOREIGN KEY ("CodeFactureFk") REFERENCES logistique."T_Commande"("CodeFacture")'
  AND NOT condeferrable AND NOT condeferred) THEN RAISE EXCEPTION 'Clé étrangère facture modifiée depuis la revue'; END IF;
 IF (SELECT count(*) FROM pg_constraint c JOIN pg_attribute a ON a.attrelid=c.confrelid AND a.attnum=ANY(c.confkey)
     WHERE c.contype='f' AND c.confrelid='logistique."T_Commande"'::regclass AND a.attname IN ('CodeCmd','CodeFacture'))<>1 THEN
  RAISE EXCEPTION 'Une autre liaison texte doit être prise en compte'; END IF;
END $preflight$;
LOCK TABLE logistique."T_Commande",logistique."T_CommandeDetail",logistique."T_Article",logistique."T_Mouvement",
 logistique."T_MouvementLot",logistique."T_LotArticle",logistique."T_Reglements",logistique."T_RetourBon",
 logistique."T_Facture",logistique."T_FactureLigne",systeme."T_Audit_Log" IN SHARE ROW EXCLUSIVE MODE;
CREATE TEMP TABLE sn08_functions ON COMMIT DROP AS
 SELECT p.proname,pg_get_functiondef(p.oid) AS definition,md5(pg_get_functiondef(p.oid)) AS fingerprint
 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='logistique'
 AND p.proname IN ('proteger_bon_retour','tr_proteger_bon_facture','tr_proteger_facture','tr_lock_commande_cloturee','tr_devise_reglement');
CREATE TEMP TABLE sn08_before(object text PRIMARY KEY,n bigint,fingerprint text) ON COMMIT DROP;
DO $capture$
DECLARE item record; ignored text[];
BEGIN
 FOR item IN SELECT * FROM (VALUES('T_Commande',ARRAY['CodeCmd','CodeFacture']),('T_Facture',ARRAY['CodeFacture']),
  ('T_Reglements',ARRAY['CodeFactureFk']),('T_CommandeDetail',ARRAY[]::text[]),('T_Article',ARRAY[]::text[]),
  ('T_Mouvement',ARRAY[]::text[]),('T_MouvementLot',ARRAY[]::text[]),('T_LotArticle',ARRAY[]::text[]),
  ('T_RetourBon',ARRAY[]::text[]),('T_FactureLigne',ARRAY[]::text[]),('T_DossierSuiviMembre',ARRAY[]::text[])) AS x(name,ignored)
 LOOP
  IF to_regclass(format('logistique.%I',item.name)) IS NOT NULL THEN
   EXECUTE format($sql$INSERT INTO pg_temp.sn08_before SELECT %L,count(*),md5(COALESCE(string_agg(md5((to_jsonb(t)-$1)::text),'' ORDER BY md5((to_jsonb(t)-$1)::text)),'')) FROM logistique.%I t$sql$,item.name,item.name) USING item.ignored;
  END IF;
 END LOOP;
END $capture$;
CREATE TEMP TABLE sn08_audit_before ON COMMIT DROP AS SELECT COALESCE(max("IdLog"),0) AS last_id,count(*) AS n,
 md5(COALESCE(string_agg(md5(to_jsonb(a)::text),'' ORDER BY "IdLog"),'')) AS fingerprint FROM systeme."T_Audit_Log" a;
CREATE TEMP TABLE sn08_mapping ON COMMIT DROP AS
 SELECT c."ID_Commande" AS id,c."CodeCmd" AS old_command,c."CodeFacture" AS old_invoice,
 ('cmd-'||c."ID_Commande"::text)::varchar(20) AS new_command,
 CASE WHEN NULLIF(btrim(c."CodeFacture"),'') IS NOT NULL THEN ('fac-'||c."ID_Commande"::text)::varchar(255) END AS new_invoice,
 ('~08c-'||c."ID_Commande"::text)::varchar(20) AS temporary_command,
 CASE WHEN NULLIF(btrim(c."CodeFacture"),'') IS NOT NULL THEN ('~08f-'||c."ID_Commande"::text)::varchar(255) END AS temporary_invoice,
 u."IdEntiteFk" AS entity_id
 FROM logistique."T_Commande" c LEFT JOIN systeme."T_Utilisateurs" u ON u."IdUser"=c."ID_UserFk";
ALTER TABLE pg_temp.sn08_mapping ADD PRIMARY KEY(id);
CREATE TEMP TABLE sn08_invoice_before ON COMMIT DROP AS
 SELECT f."ID_Facture" AS id,f."ID_CommandeFk" AS command_id,f."CodeFacture" AS old_code,f."IdEntiteFk" AS entity_id FROM logistique."T_Facture" f;
CREATE TEMP TABLE sn08_payment_before ON COMMIT DROP AS
 SELECT r."ID_Reglement" AS id,m.id AS command_id,r."CodeFactureFk" AS old_code,m.entity_id FROM logistique."T_Reglements" r
 JOIN pg_temp.sn08_mapping m ON m.old_invoice=r."CodeFactureFk";
DO $consistency$
BEGIN
 IF EXISTS(SELECT 1 FROM logistique."T_Commande" WHERE "ID_Commande"<=0) THEN RAISE EXCEPTION 'Identité de bon non positive'; END IF;
 IF EXISTS(SELECT 1 FROM logistique."T_Commande" WHERE "CodeCmd" LIKE '~08c-%' OR "CodeFacture" LIKE '~08f-%')
 OR EXISTS(SELECT 1 FROM logistique."T_Facture" WHERE "CodeFacture" LIKE '~08f-%') THEN RAISE EXCEPTION 'Préfixe temporaire déjà utilisé'; END IF;
 IF EXISTS(SELECT 1 FROM logistique."T_Facture" f JOIN logistique."T_Commande" c ON c."ID_Commande"=f."ID_CommandeFk"
  WHERE NULLIF(btrim(c."CodeFacture"),'') IS NULL OR f."CodeFacture" IS DISTINCT FROM c."CodeFacture") THEN
  RAISE EXCEPTION 'Miroir de facture incohérent avant migration'; END IF;
 IF EXISTS(SELECT 1 FROM logistique."T_Reglements" r LEFT JOIN logistique."T_Commande" c ON c."CodeFacture"=r."CodeFactureFk"
  WHERE c."ID_Commande" IS NULL OR NULLIF(btrim(c."CodeFacture"),'') IS NULL) THEN
  RAISE EXCEPTION 'Règlement sans facture exploitable avant migration'; END IF;
END $consistency$;

CREATE FUNCTION logistique.fn_code_commande(p_id integer) RETURNS varchar LANGUAGE plpgsql IMMUTABLE STRICT PARALLEL SAFE SET search_path=pg_catalog AS $fn$
BEGIN
 IF p_id<=0 THEN RAISE EXCEPTION 'Identité de bon positive requise.' USING ERRCODE='23514'; END IF;
 RETURN 'cmd-'||p_id::text;
END $fn$;
CREATE FUNCTION logistique.fn_code_facture(p_id_commande integer) RETURNS varchar LANGUAGE plpgsql IMMUTABLE STRICT PARALLEL SAFE SET search_path=pg_catalog AS $fn$
BEGIN
 IF p_id_commande<=0 THEN RAISE EXCEPTION 'Identité du bon facturé positive requise.' USING ERRCODE='23514'; END IF;
 RETURN 'fac-'||p_id_commande::text;
END $fn$;
CREATE FUNCTION logistique.fn_identite_commande_deja_utilisee(p_id integer) RETURNS boolean LANGUAGE sql STABLE STRICT PARALLEL SAFE SET search_path=pg_catalog AS $fn$
 SELECT EXISTS(SELECT 1 FROM logistique."T_Commande" c WHERE c."ID_Commande"=p_id
  OR c."CodeCmd"=logistique.fn_code_commande(p_id) OR c."CodeFacture"=logistique.fn_code_facture(p_id))
 OR EXISTS(SELECT 1 FROM systeme."T_Audit_Log" a CROSS JOIN LATERAL (VALUES(a."OldData"),(a."NewData")) saved(data)
  WHERE a."TableName" IN ('logistique.T_Commande','T_Commande','logistique.T_Facture') AND
   (saved.data->>'ID_Commande'=p_id::text OR saved.data->>'ID_CommandeFk'=p_id::text OR saved.data->>'ID_CommandeRetourFk'=p_id::text
    OR CASE WHEN UPPER(saved.data->>'CodeCmd') ~ '^C_[0-9]+$' THEN substring(saved.data->>'CodeCmd' FROM 3)::numeric
            WHEN lower(saved.data->>'CodeCmd') ~ '^cmd-[0-9]+$' THEN substring(saved.data->>'CodeCmd' FROM 5)::numeric END=p_id
    OR CASE WHEN UPPER(saved.data->>'CodeFacture') ~ '^F_[0-9]+$' THEN substring(saved.data->>'CodeFacture' FROM 3)::numeric
            WHEN lower(saved.data->>'CodeFacture') ~ '^fac-[0-9]+$' THEN substring(saved.data->>'CodeFacture' FROM 5)::numeric END=p_id));
$fn$;
CREATE FUNCTION logistique.fn_reserver_identite_commande() RETURNS TABLE("ID_Commande" integer,"CodeCmd" varchar)
 LANGUAGE plpgsql VOLATILE SET search_path=pg_catalog AS $fn$
DECLARE candidate bigint; attempt integer;
BEGIN
 FOR attempt IN 1..1000 LOOP
  SELECT nextval(pg_get_serial_sequence('logistique."T_Commande"','ID_Commande')::regclass) INTO candidate;
  IF candidate IS NULL OR candidate<=0 OR candidate>2147483647 THEN RAISE EXCEPTION 'Séquence de bons hors limites.' USING ERRCODE='22003'; END IF;
  IF NOT logistique.fn_identite_commande_deja_utilisee(candidate::integer) THEN
   RETURN QUERY SELECT candidate::integer,logistique.fn_code_commande(candidate::integer);RETURN;
  END IF;
 END LOOP;
 RAISE EXCEPTION 'La numérotation des bons doit être contrôlée.' USING ERRCODE='23514';
END $fn$;

-- Portée DDL temporaire, visible uniquement dans cette transaction sous verrous.
-- Les cinq définitions originales sont restaurées byte pour byte avant validation finale.
-- Aucun flag de session/GUC de contournement, aucune désactivation de trigger.
DO $temporary_guards$
DECLARE item record; guard text; command_guard text;
BEGIN
 command_guard=$guard$
 IF TG_OP='UPDATE' AND TG_TABLE_NAME='T_Commande' AND NEW."ID_Commande"=OLD."ID_Commande"
  AND NEW."CodeCmd" IN (logistique.fn_code_commande(OLD."ID_Commande"),'~08c-'||OLD."ID_Commande"::text)
  AND ((NULLIF(btrim(OLD."CodeFacture"),'') IS NULL AND NEW."CodeFacture" IS NULL)
    OR (NULLIF(btrim(OLD."CodeFacture"),'') IS NOT NULL AND NEW."CodeFacture" IN
      (logistique.fn_code_facture(OLD."ID_Commande"),'~08f-'||OLD."ID_Commande"::text)))
  AND (to_jsonb(NEW)-ARRAY['CodeCmd','CodeFacture'])=(to_jsonb(OLD)-ARRAY['CodeCmd','CodeFacture']) THEN RETURN NEW; END IF;
 $guard$;
 FOR item IN SELECT * FROM pg_temp.sn08_functions ORDER BY proname LOOP
  IF item.proname='tr_proteger_facture' THEN
   guard=$guard$
 IF TG_OP='UPDATE' AND NEW."ID_CommandeFk"=OLD."ID_CommandeFk"
  AND NEW."CodeFacture" IN (logistique.fn_code_facture(OLD."ID_CommandeFk"),'~08f-'||OLD."ID_CommandeFk"::text)
  AND (to_jsonb(NEW)-'CodeFacture')=(to_jsonb(OLD)-'CodeFacture') THEN RETURN NEW; END IF;
 $guard$;
  ELSIF item.proname='tr_devise_reglement' THEN
   guard=$guard$
 IF TG_OP='UPDATE' AND (to_jsonb(NEW)-'CodeFactureFk')=(to_jsonb(OLD)-'CodeFactureFk')
  AND EXISTS(SELECT 1 FROM logistique."T_Commande" c WHERE c."CodeFacture"=NEW."CodeFactureFk" AND c."ID_DeviseFk"=NEW."ID_DeviseFk"
    AND NEW."CodeFactureFk" IN (logistique.fn_code_facture(c."ID_Commande"),'~08f-'||c."ID_Commande"::text)) THEN RETURN NEW; END IF;
 $guard$;
  ELSE guard=command_guard; END IF;
  EXECUTE regexp_replace(item.definition,'\mBEGIN\M','BEGIN'||E'\n'||guard);
 END LOOP;
END $temporary_guards$;
ALTER TABLE logistique."T_Reglements" ALTER CONSTRAINT "Fk_CodeFacture" DEFERRABLE INITIALLY DEFERRED;
SET CONSTRAINTS logistique."Fk_CodeFacture" DEFERRED;
-- Phase1 : libérer tous les codes, y compris lorsqu’un ancien code ressemble à la cible d’un autre bon.
UPDATE logistique."T_Facture" f SET "CodeFacture"=m.temporary_invoice FROM pg_temp.sn08_mapping m WHERE m.id=f."ID_CommandeFk";
UPDATE logistique."T_Commande" c SET "CodeCmd"=m.temporary_command,"CodeFacture"=m.temporary_invoice FROM pg_temp.sn08_mapping m WHERE m.id=c."ID_Commande";
UPDATE logistique."T_Reglements" r SET "CodeFactureFk"=m.temporary_invoice FROM pg_temp.sn08_mapping m WHERE r."CodeFactureFk"=m.old_invoice;
-- Phase2 : références publiques définitives. Les montants et PayloadHash ne figurent dans aucun SET.
UPDATE logistique."T_Facture" f SET "CodeFacture"=m.new_invoice FROM pg_temp.sn08_mapping m WHERE m.id=f."ID_CommandeFk";
UPDATE logistique."T_Commande" c SET "CodeCmd"=m.new_command,"CodeFacture"=m.new_invoice FROM pg_temp.sn08_mapping m WHERE m.id=c."ID_Commande";
UPDATE logistique."T_Reglements" r SET "CodeFactureFk"=m.new_invoice FROM pg_temp.sn08_mapping m WHERE r."CodeFactureFk"=m.temporary_invoice;
SET CONSTRAINTS ALL IMMEDIATE;
ALTER TABLE logistique."T_Reglements" ALTER CONSTRAINT "Fk_CodeFacture" NOT DEFERRABLE INITIALLY IMMEDIATE;
DO $restore_guards$
DECLARE item record;
BEGIN
 FOR item IN SELECT * FROM pg_temp.sn08_functions ORDER BY proname LOOP
  EXECUTE item.definition;
  IF md5(pg_get_functiondef(('logistique.'||item.proname||'()')::regprocedure))<>item.fingerprint THEN
   RAISE EXCEPTION 'Restauration exacte de % impossible',item.proname; END IF;
 END LOOP;
END $restore_guards$;

CREATE FUNCTION logistique.tr_numero_commande() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $fn$
DECLARE expected_code varchar;
BEGIN
 expected_code=logistique.fn_code_commande(NEW."ID_Commande");
 IF TG_OP='INSERT' THEN
  IF expected_code IS NULL OR logistique.fn_identite_commande_deja_utilisee(NEW."ID_Commande") THEN
   RAISE EXCEPTION 'Cette identité de bon a déjà été utilisée.' USING ERRCODE='23514'; END IF;
  IF NULLIF(btrim(NEW."CodeCmd"),'') IS NOT NULL AND NEW."CodeCmd"<>expected_code THEN
   RAISE EXCEPTION 'Le code du bon est attribué automatiquement.' USING ERRCODE='23514'; END IF;
  NEW."CodeCmd"=expected_code;
  IF NULLIF(btrim(NEW."CodeFacture"),'') IS NOT NULL THEN
   RAISE EXCEPTION 'Une facture est émise par le service dédié après création du bon.' USING ERRCODE='23514'; END IF;
  NEW."CodeFacture"=NULL;
 ELSE
  IF NEW."ID_Commande" IS DISTINCT FROM OLD."ID_Commande" OR NEW."CodeCmd" IS DISTINCT FROM OLD."CodeCmd" THEN
   RAISE EXCEPTION 'Identité et code du bon sont immuables.' USING ERRCODE='23514'; END IF;
  IF NEW."CodeFacture" IS DISTINCT FROM OLD."CodeFacture" THEN
   IF NULLIF(btrim(OLD."CodeFacture"),'') IS NOT NULL OR NEW."CodeFacture" IS DISTINCT FROM logistique.fn_code_facture(NEW."ID_Commande")
    OR NOT EXISTS(SELECT 1 FROM logistique."T_Facture" f WHERE f."ID_CommandeFk"=NEW."ID_Commande" AND f."CodeFacture"=NEW."CodeFacture") THEN
    RAISE EXCEPTION 'Le numéro de facture est automatique et immuable après émission.' USING ERRCODE='23514'; END IF;
  END IF;
 END IF;
 RETURN NEW;
END $fn$;
CREATE TRIGGER a0_numero_commande BEFORE INSERT OR UPDATE OF "ID_Commande","CodeCmd","CodeFacture" ON logistique."T_Commande"
 FOR EACH ROW EXECUTE FUNCTION logistique.tr_numero_commande();
CREATE FUNCTION logistique.tr_numero_facture() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $fn$
DECLARE expected_code varchar;
BEGIN
 expected_code=logistique.fn_code_facture(NEW."ID_CommandeFk");
 IF TG_OP='INSERT' THEN
  IF expected_code IS NULL OR (NULLIF(btrim(NEW."CodeFacture"),'') IS NOT NULL AND NEW."CodeFacture"<>expected_code) THEN
   RAISE EXCEPTION 'Le numéro de facture est attribué depuis le bon.' USING ERRCODE='23514'; END IF;
  NEW."CodeFacture"=expected_code;
 ELSE
  IF NEW."ID_CommandeFk" IS DISTINCT FROM OLD."ID_CommandeFk" OR NEW."CodeFacture" IS DISTINCT FROM OLD."CodeFacture" THEN
   RAISE EXCEPTION 'La référence et le bon d’une facture émise sont immuables.' USING ERRCODE='23514'; END IF;
 END IF;
 RETURN NEW;
END $fn$;
CREATE TRIGGER a0_numero_facture BEFORE INSERT OR UPDATE OF "ID_CommandeFk","CodeFacture" ON logistique."T_Facture"
 FOR EACH ROW EXECUTE FUNCTION logistique.tr_numero_facture();
CREATE FUNCTION logistique.tr_audit_numero_document() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $fn$
DECLARE payload jsonb; entity_id integer;
BEGIN
 IF TG_TABLE_NAME='T_Commande' THEN
  payload=jsonb_build_object('ID_Commande',NEW."ID_Commande",'CodeCmd',NEW."CodeCmd");
  SELECT "IdEntiteFk" INTO entity_id FROM systeme."T_Utilisateurs" WHERE "IdUser"=NEW."ID_UserFk";
 ELSE
  payload=jsonb_build_object('ID_Facture',NEW."ID_Facture",'ID_CommandeFk',NEW."ID_CommandeFk",'CodeFacture',NEW."CodeFacture");
  entity_id=NEW."IdEntiteFk";
 END IF;
 INSERT INTO systeme."T_Audit_Log"("TableName","Operation","NewData","IdEntiteFk")
 VALUES('logistique.'||TG_TABLE_NAME,'DOCUMENT_NUMBER',payload||jsonb_build_object('version','20261025_08','sqlUser',current_user),entity_id);
 RETURN NEW;
END $fn$;
CREATE TRIGGER numero_commande_audit AFTER INSERT ON logistique."T_Commande" FOR EACH ROW EXECUTE FUNCTION logistique.tr_audit_numero_document();
CREATE TRIGGER numero_facture_audit AFTER INSERT ON logistique."T_Facture" FOR EACH ROW EXECUTE FUNCTION logistique.tr_audit_numero_document();

-- Archive de correspondance append-only dans le journal existant ; les anciennes preuves restent intactes.
INSERT INTO systeme."T_Audit_Log"("TableName","Operation","OldData","NewData","IdEntiteFk")
 SELECT 'logistique.T_Commande','DOCUMENT_RENUMBER',jsonb_build_object('ID_Commande',m.id,'CodeCmd',m.old_command,'CodeFacture',m.old_invoice),
 jsonb_build_object('ID_Commande',m.id,'CodeCmd',m.new_command,'CodeFacture',m.new_invoice,'migration','20261025_08','sqlUser',current_user),m.entity_id
 FROM pg_temp.sn08_mapping m WHERE m.old_command IS DISTINCT FROM m.new_command OR m.old_invoice IS DISTINCT FROM m.new_invoice;
INSERT INTO systeme."T_Audit_Log"("TableName","Operation","OldData","NewData","IdEntiteFk")
 SELECT 'logistique.T_Facture','DOCUMENT_RENUMBER',jsonb_build_object('ID_Facture',f.id,'ID_CommandeFk',f.command_id,'CodeFacture',f.old_code),
 jsonb_build_object('ID_Facture',f.id,'ID_CommandeFk',f.command_id,'CodeFacture',m.new_invoice,'migration','20261025_08','sqlUser',current_user),f.entity_id
 FROM pg_temp.sn08_invoice_before f JOIN pg_temp.sn08_mapping m ON m.id=f.command_id WHERE f.old_code IS DISTINCT FROM m.new_invoice;
INSERT INTO systeme."T_Audit_Log"("TableName","Operation","OldData","NewData","IdEntiteFk")
 SELECT 'logistique.T_Reglements','DOCUMENT_RENUMBER',jsonb_build_object('ID_Reglement',r.id,'CodeFactureFk',r.old_code),
 jsonb_build_object('ID_Reglement',r.id,'ID_CommandeFk',r.command_id,'CodeFactureFk',m.new_invoice,'migration','20261025_08','sqlUser',current_user),r.entity_id
 FROM pg_temp.sn08_payment_before r JOIN pg_temp.sn08_mapping m ON m.id=r.command_id WHERE r.old_code IS DISTINCT FROM m.new_invoice;

COMMENT ON FUNCTION logistique.fn_code_commande(integer) IS 'Code déterministe court cmd-ID_Commande, sans padding ni réservation de séquence.';
COMMENT ON FUNCTION logistique.fn_code_facture(integer) IS 'Code déterministe court fac-ID_Commande du bon facturé ; ne consomme aucune identité.';
COMMENT ON FUNCTION logistique.fn_identite_commande_deja_utilisee(integer) IS 'Détecte les identités et références courantes ou archivées dans les audits, y compris les anciens formats C_/F_.';
COMMENT ON FUNCTION logistique.fn_reserver_identite_commande() IS 'Réserve une identité dans la séquence existante puis retourne cmd-ID ; saute les identités déjà utilisées, jamais MAX+1 ni réutilisation après suppression.';
COMMENT ON FUNCTION logistique.tr_numero_commande() IS 'Génère le code du bon depuis son identité et impose l’immutabilité des identités/références ; une facture exige son snapshot dédié.';
COMMENT ON FUNCTION logistique.tr_numero_facture() IS 'Génère fac-IDBon lors de l’émission et conserve la référence et le parent ensuite.';
COMMENT ON FUNCTION logistique.tr_audit_numero_document() IS 'Mémorise uniquement identité, code et organisation, même pour une création SQL directe, pour prévenir leur réutilisation.';
COMMENT ON TRIGGER a0_numero_commande ON logistique."T_Commande" IS 'Référence automatique cmd-ID et immutabilité ; aucun effet stock.';
COMMENT ON TRIGGER a0_numero_facture ON logistique."T_Facture" IS 'Référence automatique fac-IDBon ; aucun mouvement ni recalcul financier.';
COMMENT ON TRIGGER numero_commande_audit ON logistique."T_Commande" IS 'Trace la première attribution d’une référence dans le journal existant.';
COMMENT ON TRIGGER numero_facture_audit ON logistique."T_Facture" IS 'Trace la première attribution du numéro de facture, sans secret ni copie du panier.';
COMMENT ON COLUMN logistique."T_Commande"."CodeCmd" IS 'Référence serveur courte immuable : cmd-ID_Commande ; anciens codes conservés dans l’audit de migration20261025_08.';
COMMENT ON COLUMN logistique."T_Commande"."CodeFacture" IS 'Miroir du numéro de facture fac-ID_Commande ; NULL avant émission ; immuable ensuite.';
COMMENT ON COLUMN logistique."T_Facture"."CodeFacture" IS 'Numéro serveur immuable fac-ID_Commande du bon facturé ; valeurs historiques renommées et mappées dans l’audit08.';
COMMENT ON COLUMN logistique."T_Reglements"."CodeFactureFk" IS 'Référence de facture fac-IDBon, conservée atomiquement avec le miroir et le snapshot lors de la renumérotation08.';

DO $verify$
DECLARE item record; current_n bigint; current_hash text; ignored text[]; audit_n bigint; audit_hash text;
BEGIN
 IF EXISTS(SELECT 1 FROM logistique."T_Commande" c WHERE c."CodeCmd" IS DISTINCT FROM logistique.fn_code_commande(c."ID_Commande")
  OR (NULLIF(btrim(c."CodeFacture"),'') IS NOT NULL AND c."CodeFacture"<>logistique.fn_code_facture(c."ID_Commande"))) THEN RAISE EXCEPTION 'Codes de bon non canoniques'; END IF;
 IF EXISTS(SELECT 1 FROM logistique."T_Facture" f JOIN logistique."T_Commande" c ON c."ID_Commande"=f."ID_CommandeFk"
  WHERE f."CodeFacture" IS DISTINCT FROM logistique.fn_code_facture(f."ID_CommandeFk") OR f."CodeFacture" IS DISTINCT FROM c."CodeFacture") THEN
  RAISE EXCEPTION 'Miroir de facture incohérent après migration'; END IF;
 IF EXISTS(SELECT 1 FROM logistique."T_Reglements" r LEFT JOIN logistique."T_Commande" c ON c."CodeFacture"=r."CodeFactureFk"
  WHERE c."ID_Commande" IS NULL) THEN RAISE EXCEPTION 'Référence de règlement orpheline après migration'; END IF;
 IF EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='logistique."T_Reglements"'::regclass AND conname='Fk_CodeFacture' AND (condeferrable OR condeferred)) THEN
  RAISE EXCEPTION 'Différabilité initiale de la FK non restaurée'; END IF;
 FOR item IN SELECT * FROM pg_temp.sn08_before LOOP
  ignored=CASE item.object WHEN 'T_Commande' THEN ARRAY['CodeCmd','CodeFacture'] WHEN 'T_Facture' THEN ARRAY['CodeFacture']
   WHEN 'T_Reglements' THEN ARRAY['CodeFactureFk'] ELSE ARRAY[]::text[] END;
  EXECUTE format($sql$SELECT count(*),md5(COALESCE(string_agg(md5((to_jsonb(t)-$1)::text),'' ORDER BY md5((to_jsonb(t)-$1)::text)),'')) FROM logistique.%I t$sql$,item.object)
   INTO current_n,current_hash USING ignored;
  IF current_n<>item.n OR current_hash<>item.fingerprint THEN RAISE EXCEPTION 'Données métier modifiées hors codes dans %',item.object; END IF;
 END LOOP;
 SELECT count(*),md5(COALESCE(string_agg(md5(to_jsonb(a)::text),'' ORDER BY "IdLog"),'')) INTO audit_n,audit_hash
 FROM systeme."T_Audit_Log" a WHERE a."IdLog"<=(SELECT last_id FROM pg_temp.sn08_audit_before);
 IF EXISTS(SELECT 1 FROM pg_temp.sn08_audit_before WHERE n<>audit_n OR fingerprint<>audit_hash) THEN RAISE EXCEPTION 'Un audit historique a été modifié'; END IF;
 IF (SELECT count(*) FROM systeme."T_Audit_Log" WHERE "IdLog">(SELECT last_id FROM pg_temp.sn08_audit_before))<>
  ((SELECT count(*) FROM pg_temp.sn08_mapping WHERE old_command IS DISTINCT FROM new_command OR old_invoice IS DISTINCT FROM new_invoice)
   +(SELECT count(*) FROM pg_temp.sn08_invoice_before f JOIN pg_temp.sn08_mapping m ON m.id=f.command_id WHERE f.old_code IS DISTINCT FROM m.new_invoice)
   +(SELECT count(*) FROM pg_temp.sn08_payment_before r JOIN pg_temp.sn08_mapping m ON m.id=r.command_id WHERE r.old_code IS DISTINCT FROM m.new_invoice)) THEN
  RAISE EXCEPTION 'Nombre de traces de correspondance inattendu'; END IF;
END $verify$;
COMMIT;
