-- Renommage autorisé des bons existants selon leur nature BE/BS/CMD.
-- Identifiants, factures émises, mouvements, coûts et audits anciens conservés.
BEGIN;
SET LOCAL lock_timeout='15s';
SET LOCAL statement_timeout='120s';
DO $preconditions$
BEGIN
 IF current_database()<>'SauverNdeko' AND left(current_database(),17)<>'sauverndeko_test_' THEN RAISE EXCEPTION 'Base cible non autorisée.';END IF;
 IF to_regprocedure('logistique.fn_nature_bon(integer)') IS NULL OR NOT EXISTS(SELECT FROM information_schema.columns WHERE table_schema='logistique' AND table_name='V_Commande' AND column_name='NatureBon') THEN RAISE EXCEPTION 'Socle des bons explicites 20261028_05 requis.';END IF;
 IF to_regclass('logistique."T_BonCodeHistorique"') IS NOT NULL THEN RAISE EXCEPTION 'Migration06 déjà installée : rejeu interdit.';END IF;
 IF EXISTS(SELECT FROM logistique."T_Commande" WHERE logistique.fn_nature_bon("ID_TypeCmdFk") IS NULL) THEN RAISE EXCEPTION 'Un type historique doit être rapproché avant le renommage.';END IF;
END $preconditions$;

LOCK TABLE logistique."T_Commande" IN ACCESS EXCLUSIVE MODE;
CREATE TEMP TABLE sn06_avant ON COMMIT DROP AS
 SELECT "ID_Commande" id,to_jsonb(c)-'CodeCmd' sans_code,"CodeCmd" ancien
 FROM logistique."T_Commande" c;
CREATE TEMP TABLE sn06_correspondance ON COMMIT DROP AS
 SELECT c."ID_Commande" id,c."IdEntiteFk" entreprise,c."CodeCmd" ancien,
 logistique.fn_code_bon(c."ID_Commande",c."ID_TypeCmdFk") nouveau
 FROM logistique."T_Commande" c
 WHERE c."CodeCmd" IS DISTINCT FROM logistique.fn_code_bon(c."ID_Commande",c."ID_TypeCmdFk");
ALTER TABLE pg_temp.sn06_correspondance ADD PRIMARY KEY(id);
DO $collisions$
BEGIN
 IF EXISTS(SELECT FROM pg_temp.sn06_correspondance m JOIN logistique."T_Commande" c ON c."CodeCmd"=m.nouveau AND c."ID_Commande"<>m.id) THEN
  RAISE EXCEPTION 'Un code cible est déjà porté par un autre bon ; rapprochement préalable requis.' USING ERRCODE='23514';
 END IF;
END $collisions$;

CREATE TABLE logistique."T_BonCodeHistorique" (
 "ID_BonCodeHistorique" bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 "ID_Commande" integer NOT NULL UNIQUE,
 "IdEntiteFk" integer,
 "AncienCodeCmd" character varying(20),
 "NouveauCodeCmd" character varying(20) NOT NULL UNIQUE,
 "RenumeroteLe" timestamp with time zone NOT NULL DEFAULT clock_timestamp(),
 "Motif" text NOT NULL,
 "VersionMigration" character varying(20) NOT NULL,
 "UtilisateurBase" text NOT NULL DEFAULT current_user,
 CONSTRAINT bon_code_historique_identite CHECK("ID_Commande">0),
 CONSTRAINT bon_code_historique_nouveau CHECK("NouveauCodeCmd" ~ '^(BE|BS|CMD)-[1-9][0-9]*$' AND regexp_replace("NouveauCodeCmd",'^[A-Z]+-','')="ID_Commande"::text),
 CONSTRAINT bon_code_historique_motif CHECK(length(btrim("Motif")) BETWEEN 10 AND 1000),
 CONSTRAINT bon_code_historique_version CHECK("VersionMigration"='20261028_06'),
 CONSTRAINT bon_code_historique_utilisateur CHECK(length(btrim("UtilisateurBase"))>0)
);
COMMENT ON TABLE logistique."T_BonCodeHistorique" IS 'Correspondances factuelles de la reprise autorisée06 : anciens codes vers BE-/BS-/CMD-, date, entreprise, motif et utilisateur SQL. Journal fermé et immuable ; conserve la référence même après suppression d’un bon non protégé. Aucun CRUD applicatif.';
COMMENT ON COLUMN logistique."T_BonCodeHistorique"."ID_BonCodeHistorique" IS 'Identité technique de la correspondance ; ne réalloue jamais l’identité du bon.';
COMMENT ON COLUMN logistique."T_BonCodeHistorique"."ID_Commande" IS 'Identité stable du bon renommé, sans FK de suppression pour conserver la preuve historique.';
COMMENT ON COLUMN logistique."T_BonCodeHistorique"."IdEntiteFk" IS 'Entreprise propriétaire constatée lors du renommage ; la conservation historique ne dépend pas d’une suppression ultérieure de l’entreprise.';
COMMENT ON COLUMN logistique."T_BonCodeHistorique"."AncienCodeCmd" IS 'Code exact avant06 ; NULL reste l’absence historique réelle de code.';
COMMENT ON COLUMN logistique."T_BonCodeHistorique"."NouveauCodeCmd" IS 'Code canonique BE-ID, BS-ID ou CMD-ID attribué au même identifiant de bon.';
COMMENT ON COLUMN logistique."T_BonCodeHistorique"."RenumeroteLe" IS 'Instant PostgreSQL réel du changement de nomenclature ; distingue les références des documents émis avant et après la reprise.';
COMMENT ON COLUMN logistique."T_BonCodeHistorique"."Motif" IS 'Motif de la reprise documentaire autorisée ; aucun ajustement de stock ou de montant.';
COMMENT ON COLUMN logistique."T_BonCodeHistorique"."VersionMigration" IS 'Migration ayant produit cette correspondance ; valeur contrôlée 20261028_06.';
COMMENT ON COLUMN logistique."T_BonCodeHistorique"."UtilisateurBase" IS 'Utilisateur PostgreSQL ayant exécuté la reprise ; ne prétend pas identifier une personne applicative absente du contexte de migration.';
COMMENT ON SEQUENCE logistique."T_BonCodeHistorique_ID_BonCodeHistorique_seq" IS 'Séquence technique du journal de correspondance ; indépendante des identités et numéros des bons.';
DO $commentaires$
DECLARE objet record;
BEGIN
 FOR objet IN SELECT conname FROM pg_constraint WHERE conrelid='logistique."T_BonCodeHistorique"'::regclass LOOP
  EXECUTE format('COMMENT ON CONSTRAINT %I ON logistique."T_BonCodeHistorique" IS %L',objet.conname,'Intégrité du journal de nomenclature06 : identité, unicité, champs obligatoires et métadonnées factuelles conservées.');
 END LOOP;
 FOR objet IN SELECT c.relname FROM pg_index i JOIN pg_class c ON c.oid=i.indexrelid WHERE i.indrelid='logistique."T_BonCodeHistorique"'::regclass LOOP
  EXECUTE format('COMMENT ON INDEX logistique.%I IS %L',objet.relname,'Index d’intégrité et de recherche du journal06 : une correspondance par bon et un nouveau code unique.');
 END LOOP;
END $commentaires$;

INSERT INTO logistique."T_BonCodeHistorique"("ID_Commande","IdEntiteFk","AncienCodeCmd","NouveauCodeCmd","Motif","VersionMigration","UtilisateurBase")
 SELECT id,entreprise,ancien,nouveau,'Harmonisation autorisée des anciens codes selon la nature du bon, sans changement métier.','20261028_06',current_user
 FROM pg_temp.sn06_correspondance ORDER BY id;

-- Dérogations privées à cette transaction : seul le code de chaque ligne du
-- mapping peut changer. Aucun drapeau applicatif durable n'est introduit.
CREATE FUNCTION pg_temp.sn06_reprise_autorisee(p_ancien jsonb,p_nouveau jsonb)
RETURNS boolean LANGUAGE sql STABLE SET search_path=pg_catalog AS $$
 SELECT EXISTS(SELECT FROM pg_temp.sn06_correspondance m
  WHERE m.id=(p_ancien->>'ID_Commande')::integer
   AND p_ancien->>'CodeCmd' IS NOT DISTINCT FROM m.ancien
   AND p_nouveau->>'CodeCmd'=m.nouveau
   AND (p_ancien-'CodeCmd')=(p_nouveau-'CodeCmd'))
$$;
CREATE TEMP TABLE sn06_definitions(signature text PRIMARY KEY,definition text NOT NULL) ON COMMIT DROP;
INSERT INTO pg_temp.sn06_definitions(signature,definition)
 SELECT sig,pg_get_functiondef(sig::regprocedure) FROM unnest(ARRAY[
 'logistique.tr_numero_commande()','logistique.tr_bon_initial_protection()',
 'logistique.proteger_bon_inventaire()','logistique.proteger_bon_retour()',
 'logistique.tr_proteger_bon_facture()','logistique.tr_lock_commande_cloturee()',
 'logistique.tr_crud_commande()']) sig;
DO $gardes_temporaires$
DECLARE fonction record; position_debut integer; prefixe text;
BEGIN
 prefixe:=E'\n IF TG_TABLE_NAME=''T_Commande'' AND TG_OP=''UPDATE'' THEN\n  IF pg_temp.sn06_reprise_autorisee(to_jsonb(OLD),to_jsonb(NEW)) THEN RETURN NEW; END IF;\n END IF;\n';
 FOR fonction IN SELECT * FROM pg_temp.sn06_definitions ORDER BY signature LOOP
  position_debut:=position('BEGIN' IN fonction.definition);
  IF position_debut=0 THEN RAISE EXCEPTION 'Garde non reconnue : %',fonction.signature;END IF;
  EXECUTE substring(fonction.definition FROM 1 FOR position_debut+4)||prefixe||substring(fonction.definition FROM position_debut+5);
 END LOOP;
END $gardes_temporaires$;

UPDATE logistique."T_Commande" c SET "CodeCmd"=m.nouveau
 FROM pg_temp.sn06_correspondance m WHERE c."ID_Commande"=m.id;

DO $restaurer_gardes$
DECLARE fonction record;
BEGIN
 FOR fonction IN SELECT * FROM pg_temp.sn06_definitions ORDER BY signature LOOP EXECUTE fonction.definition;END LOOP;
 IF EXISTS(SELECT FROM pg_temp.sn06_definitions WHERE pg_get_functiondef(signature::regprocedure) IS DISTINCT FROM definition) THEN RAISE EXCEPTION 'Une garde n’a pas été intégralement restaurée.';END IF;
 IF EXISTS(SELECT FROM logistique."T_Commande" c FULL JOIN pg_temp.sn06_avant a ON a.id=c."ID_Commande" WHERE a.id IS NULL OR c."ID_Commande" IS NULL OR (to_jsonb(c)-'CodeCmd') IS DISTINCT FROM a.sans_code) THEN
  RAISE EXCEPTION 'Le renommage ne doit modifier que CodeCmd.';
 END IF;
 IF EXISTS(SELECT FROM logistique."T_Commande" WHERE "CodeCmd" IS DISTINCT FROM logistique.fn_code_bon("ID_Commande","ID_TypeCmdFk")) THEN RAISE EXCEPTION 'Nomenclature finale incohérente.';END IF;
 IF (SELECT count(*) FROM logistique."T_BonCodeHistorique")<>(SELECT count(*) FROM pg_temp.sn06_correspondance) THEN RAISE EXCEPTION 'Journal de correspondance incomplet.';END IF;
END $restaurer_gardes$;
DROP FUNCTION pg_temp.sn06_reprise_autorisee(jsonb,jsonb);

CREATE FUNCTION logistique.tr_bon_code_historique_immuable() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
BEGIN RAISE EXCEPTION 'Journal de nomenclature conservé ; alimentation réservée aux migrations contrôlées.' USING ERRCODE='23514';END $$;
COMMENT ON FUNCTION logistique.tr_bon_code_historique_immuable() IS 'Ferme le journal après la reprise06 : aucune insertion, modification ni suppression applicative ; une évolution ultérieure exige sa propre migration contrôlée.';
CREATE TRIGGER bon_code_historique_immuable BEFORE INSERT OR UPDATE OR DELETE ON logistique."T_BonCodeHistorique" FOR EACH ROW EXECUTE FUNCTION logistique.tr_bon_code_historique_immuable();
COMMENT ON TRIGGER bon_code_historique_immuable ON logistique."T_BonCodeHistorique" IS 'Conserve toutes les correspondances, sans dérogation applicative ni GUC permanent.';

CREATE FUNCTION logistique.fn_code_bon_a_date(p_id integer,p_emis_le timestamp with time zone)
RETURNS character varying LANGUAGE sql STABLE PARALLEL SAFE SET search_path=pg_catalog AS $$
 SELECT CASE WHEN h."ID_Commande" IS NOT NULL AND (p_emis_le IS NULL OR p_emis_le<=h."RenumeroteLe") THEN h."AncienCodeCmd"
  ELSE coalesce(c."CodeCmd",h."NouveauCodeCmd") END
 FROM (SELECT 1) source
 LEFT JOIN logistique."T_Commande" c ON c."ID_Commande"=p_id
 LEFT JOIN logistique."T_BonCodeHistorique" h ON h."ID_Commande"=p_id
 WHERE c."ID_Commande" IS NOT NULL OR h."ID_Commande" IS NOT NULL
$$;
COMMENT ON FUNCTION logistique.fn_code_bon_a_date(integer,timestamp with time zone) IS 'Référence du bon à l’émission documentaire : ancien code exact si émission antérieure/égale à la reprise06 ou date historique absente, sinon code courant. Le service appelant doit d’abord autoriser le parent et son entreprise.';

DO $vues$
DECLARE nom text; definition text;
BEGIN
 FOREACH nom IN ARRAY ARRAY['V_Commande','V_CommandeDetail','V_CommandeOverview'] LOOP
  definition:=regexp_replace(pg_get_viewdef(format('logistique.%I',nom)::regclass,true),';[[:space:]]*$','');
  EXECUTE format('CREATE OR REPLACE VIEW logistique.%I AS SELECT source.*,h."AncienCodeCmd",h."RenumeroteLe" FROM (%s) source LEFT JOIN logistique."T_BonCodeHistorique" h ON h."ID_Commande"=source."ID_Commande"',nom,definition);
  EXECUTE format('COMMENT ON COLUMN logistique.%I."AncienCodeCmd" IS %L',nom,'Code exact avant la nomenclature06 si ce bon a été renommé ; issu du journal immuable, sans réécrire le document ni les écritures émises.');
  EXECUTE format('COMMENT ON COLUMN logistique.%I."RenumeroteLe" IS %L',nom,'Instant de la reprise06 de ce bon ; absent pour un code déjà canonique ou une création ultérieure.');
  EXECUTE format('COMMENT ON VIEW logistique.%I IS %L',nom,'Projection commune des bons ou lignes avec nature BE/BS/CMD, montants exacts et correspondance historique de code issue du journal06. Les identifiants et écritures métier restent inchangés.');
 END LOOP;
END $vues$;
COMMENT ON COLUMN logistique."T_Commande"."CodeCmd" IS 'Code serveur immuable BE-ID pour une entrée effective, BS-ID pour une sortie, CMD-ID pour une commande préparatoire. Les anciens codes renommés par06 restent dans T_BonCodeHistorique.';
COMMENT ON COLUMN logistique."V_Commande"."CodeCmd" IS 'Code actuel du bon après nomenclature06 ; AncienCodeCmd et RenumeroteLe conservent sa correspondance historique.';
COMMENT ON COLUMN logistique."V_CommandeDetail"."CodeCmd" IS 'Code actuel du bon parent ; l’ancien code reste consultable dans AncienCodeCmd, sans changer la clé ID_CmdFk.';
COMMENT ON COLUMN logistique."V_CommandeOverview"."CodeCmd" IS 'Code courant BE-/BS-/CMD- ; les références documentaires émises se résolvent par fn_code_bon_a_date.';

-- Ajouter des possibilités facultatives sans déplacer les définitions
-- existantes ni modifier les préférences personnelles de tableau/export.
DO $catalogues$
DECLARE interface record; definitions jsonb; ordre integer; ordre_export integer;
BEGIN
 IF (SELECT count(*) FROM referentiel."T_InterfaceTableau" WHERE "CleInterface" IN ('logistique.commandes','logistique.lignes'))<>2 THEN RAISE EXCEPTION 'Catalogues Bons de stock et Lignes requis.';END IF;
 FOR interface IN SELECT * FROM referentiel."T_InterfaceTableau" WHERE "CleInterface" IN ('logistique.commandes','logistique.lignes') ORDER BY "CleInterface" FOR UPDATE LOOP
  definitions:=interface."Colonnes";
  IF EXISTS(SELECT FROM jsonb_array_elements(definitions) c WHERE c->>'id' IN ('AncienCodeCmd','RenumeroteLe')) THEN RAISE EXCEPTION 'Colonnes de nomenclature déjà présentes dans le catalogue %.',interface."CleInterface";END IF;
  SELECT coalesce(max((c->>'defaultOrder')::integer),-1)+1,coalesce(max((c->>'defaultExportOrder')::integer),-1)+1 INTO ordre,ordre_export FROM jsonb_array_elements(definitions) c;
  definitions:=definitions||jsonb_build_array(
   jsonb_build_object('id','AncienCodeCmd','label','Ancien code','type','character varying','exportable',true,'defaultVisible',false,'defaultExport',false,'defaultOrder',ordre,'defaultExportOrder',ordre_export,'tableAvailable',interface."CleInterface"='logistique.commandes'),
   jsonb_build_object('id','RenumeroteLe','label','Renuméroté le','type','timestamp with time zone','exportable',true,'defaultVisible',false,'defaultExport',false,'defaultOrder',ordre+1,'defaultExportOrder',ordre_export+1,'tableAvailable',false));
  UPDATE referentiel."T_InterfaceTableau" SET "Colonnes"=definitions WHERE "CleInterface"=interface."CleInterface";
 END LOOP;
END $catalogues$;

COMMIT;
