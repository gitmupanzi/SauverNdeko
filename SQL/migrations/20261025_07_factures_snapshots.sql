-- Migration 20261025_07 : instantanés de facturation après retours partiels.
-- Prérequis : migration 06 retours. Aucun document historique n’est réécrit.
-- Migration revue sur structure privée ; sauvegarde vérifiée avant application.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='60s';
DO $preflight$
BEGIN
 IF current_database() NOT IN ('SauverNdeko','sauverndeko_test_restitutions') THEN
   RAISE EXCEPTION 'Base hors périmètre'; END IF;
 IF to_regclass('logistique."T_RetourBon"') IS NULL THEN RAISE EXCEPTION 'Migration retours06 requise'; END IF;
 IF to_regclass('logistique."T_Facture"') IS NOT NULL THEN RAISE EXCEPTION 'Facturation déjà installée'; END IF;
 IF md5(pg_get_viewdef('logistique."V_Commande"'::regclass,true))<>'0eff2b6f8ec85b5659ab6e0a6c6f6856' THEN RAISE EXCEPTION 'Définition de V_Commande modifiée depuis la revue'; END IF;
 IF md5(pg_get_viewdef('logistique."V_SuiviReglements"'::regclass,true))<>'2089d8b5fd11d575148aa8ffd909b432' THEN RAISE EXCEPTION 'Définition de V_SuiviReglements modifiée depuis la revue'; END IF;
END $preflight$;
LOCK TABLE logistique."T_Commande",logistique."T_CommandeDetail",logistique."T_Reglements",logistique."T_RetourBon",logistique."T_Article",logistique."T_Mouvement",logistique."T_MouvementLot",logistique."T_LotArticle" IN SHARE ROW EXCLUSIVE MODE;
CREATE TEMP TABLE facture_07_before ON COMMIT DROP AS
 SELECT 'T_Commande' AS object,count(*) AS n,md5(COALESCE(string_agg(md5(to_jsonb(t)::text),'' ORDER BY "ID_Commande"),'')) AS fingerprint FROM logistique."T_Commande" t
 UNION ALL SELECT 'T_CommandeDetail',count(*),md5(COALESCE(string_agg(md5(to_jsonb(t)::text),'' ORDER BY "ID_CmdFk","ID_ArticleFk"),'')) FROM logistique."T_CommandeDetail" t
 UNION ALL SELECT 'T_Reglements',count(*),md5(COALESCE(string_agg(md5(to_jsonb(t)::text),'' ORDER BY "ID_Reglement"),'')) FROM logistique."T_Reglements" t
 UNION ALL SELECT 'T_Article',count(*),md5(COALESCE(string_agg(md5(to_jsonb(t)::text),'' ORDER BY "ID_Article"),'')) FROM logistique."T_Article" t
 UNION ALL SELECT 'T_Mouvement',count(*),md5(COALESCE(string_agg(md5(to_jsonb(t)::text),'' ORDER BY "ID_Mvt"),'')) FROM logistique."T_Mouvement" t
 UNION ALL SELECT 'T_MouvementLot',count(*),md5(COALESCE(string_agg(md5(to_jsonb(t)::text),'' ORDER BY "ID_MvtFk","ID_LotArticleFk"),'')) FROM logistique."T_MouvementLot" t
 UNION ALL SELECT 'T_LotArticle',count(*),md5(COALESCE(string_agg(md5(to_jsonb(t)::text),'' ORDER BY "ID_LotArticle"),'')) FROM logistique."T_LotArticle" t;
CREATE TABLE logistique."T_Facture" (
 "ID_Facture" bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 "ID_CommandeFk" integer NOT NULL UNIQUE REFERENCES logistique."T_Commande"("ID_Commande") ON DELETE RESTRICT,
 "CodeFacture" varchar(255) NOT NULL UNIQUE,
 "ID_UserFk" integer NOT NULL REFERENCES systeme."T_Utilisateurs"("IdUser") ON DELETE RESTRICT,
 "IdEntiteFk" integer NOT NULL REFERENCES systeme."T_Entite"("IdEntite") ON DELETE RESTRICT,
 "RequestId" uuid NOT NULL,
 "PayloadHash" text NOT NULL CHECK("PayloadHash" ~ '^[0-9a-f]{64}$'),
 "DateFacture" timestamptz NOT NULL,
 "DateEcheancePaiement" timestamptz NOT NULL,
 "ID_ModePaiementFk" integer REFERENCES referentiel."T_Generique"("ID_Generique") ON DELETE RESTRICT,
 "ID_ConditionPaiementFk" integer REFERENCES referentiel."T_Generique"("ID_Generique") ON DELETE RESTRICT,
 "DelaiJours" integer CHECK("DelaiJours">=0),
 "ID_DeviseFk" integer NOT NULL REFERENCES referentiel."T_Generique"("ID_Generique") ON DELETE RESTRICT,
 "DeviseCode" text NOT NULL CHECK("DeviseCode" ~ '^[A-Z]{3}$'),
 "DeviseLibelle" text NOT NULL,
 "MontantHT" numeric(12,2) NOT NULL CHECK("MontantHT">0),
 "MontantTTC" numeric(12,2) NOT NULL CHECK("MontantTTC"="MontantHT"),
 "TransactionCreation" bigint NOT NULL DEFAULT txid_current(),
 "CreeLe" timestamptz NOT NULL DEFAULT clock_timestamp(),
 "ModifieLe" timestamptz NOT NULL DEFAULT clock_timestamp(),
 CONSTRAINT uq_facture_request UNIQUE("ID_UserFk","RequestId"),
 CONSTRAINT ck_facture_echeance CHECK("DateEcheancePaiement">="DateFacture")
);
CREATE TABLE logistique."T_FactureLigne" (
 "ID_FactureLigne" bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 "ID_FactureFk" bigint NOT NULL REFERENCES logistique."T_Facture"("ID_Facture") ON DELETE RESTRICT,
 "ID_CmdFk" integer NOT NULL,
 "ID_ArticleFk" integer NOT NULL,
 "NomArticle" text NOT NULL,
 "CodeArticleInterne" text,
 "Unite" text,
 "QteSortie" integer NOT NULL CHECK("QteSortie">0),
 "QteRetourAvantFacture" integer NOT NULL CHECK("QteRetourAvantFacture">=0),
 "QteFacturee" integer NOT NULL CHECK("QteFacturee">0 AND "QteFacturee"="QteSortie"-"QteRetourAvantFacture"),
 "PUFacture" numeric(12,2) NOT NULL CHECK("PUFacture">=0),
 "MontantLigne" numeric(12,2) NOT NULL CHECK("MontantLigne"="QteFacturee"*"PUFacture"),
 CONSTRAINT uq_facture_article UNIQUE("ID_FactureFk","ID_ArticleFk"),
 CONSTRAINT fk_facture_ligne_origine FOREIGN KEY("ID_CmdFk","ID_ArticleFk")
   REFERENCES logistique."T_CommandeDetail"("ID_CmdFk","ID_ArticleFk") ON DELETE RESTRICT
);

CREATE FUNCTION logistique.tr_proteger_facture() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $fn$
DECLARE parent logistique."T_Commande"; source_entity integer;
BEGIN
 IF TG_OP='DELETE' THEN RAISE EXCEPTION 'Une facture émise est conservée.' USING ERRCODE='23514'; END IF;
 SELECT * INTO parent FROM logistique."T_Commande" WHERE "ID_Commande"=NEW."ID_CommandeFk" FOR UPDATE;
 IF NOT FOUND OR logistique.fn_commande_cloturee(parent."StatusFacture") THEN RAISE EXCEPTION 'Bon absent ou clôturé.' USING ERRCODE='23514'; END IF;
 IF TG_OP='UPDATE' THEN
  IF (to_jsonb(NEW)-ARRAY['DateFacture','DateEcheancePaiement','ID_ModePaiementFk','ID_ConditionPaiementFk','DelaiJours','ModifieLe']) IS DISTINCT FROM
     (to_jsonb(OLD)-ARRAY['DateFacture','DateEcheancePaiement','ID_ModePaiementFk','ID_ConditionPaiementFk','DelaiJours','ModifieLe']) THEN
     RAISE EXCEPTION 'Identité, devise et montants facturés immuables.' USING ERRCODE='23514'; END IF;
  IF EXISTS(SELECT 1 FROM logistique."T_Reglements" WHERE "CodeFactureFk"=OLD."CodeFacture") THEN
     RAISE EXCEPTION 'Facture réglée en tout ou partie : métadonnées conservées.' USING ERRCODE='23514'; END IF;
 ELSE
  IF NULLIF(btrim(parent."CodeFacture"),'') IS NOT NULL THEN RAISE EXCEPTION 'Une facture historique existe déjà.' USING ERRCODE='23514'; END IF;
  IF NOT EXISTS(SELECT 1 FROM referentiel."T_Generique" WHERE "ID_Generique"=parent."ID_TypeCmdFk"
    AND "ID_CategorieGeneriqueFk"=64 AND "AbrGenerique" ILIKE 'sort%')
    OR EXISTS(SELECT 1 FROM logistique."T_RetourBon" WHERE "ID_CommandeRetourFk"=parent."ID_Commande") THEN
    RAISE EXCEPTION 'Seul un bon de sortie original peut être facturé.' USING ERRCODE='23514'; END IF;
  SELECT "IdEntiteFk" INTO source_entity FROM systeme."T_Utilisateurs" WHERE "IdUser"=parent."ID_UserFk" FOR SHARE;
  IF NEW."IdEntiteFk" IS DISTINCT FROM source_entity OR NEW."ID_DeviseFk" IS DISTINCT FROM parent."ID_DeviseFk" THEN
     RAISE EXCEPTION 'Organisation ou devise incompatible avec le bon.' USING ERRCODE='23514'; END IF;
  PERFORM logistique.fn_verifier_devise(NEW."ID_DeviseFk");
  IF NOT EXISTS(SELECT 1 FROM referentiel."T_Generique" WHERE "ID_Generique"=NEW."ID_DeviseFk"
    AND logistique.fn_code_devise("AbrGenerique")=NEW."DeviseCode") THEN
    RAISE EXCEPTION 'Le code de devise doit correspondre au référentiel.' USING ERRCODE='23514'; END IF;
 END IF;
 PERFORM logistique.fn_assert_generique_category(NEW."ID_ModePaiementFk",36,'Facture','ID_ModePaiementFk');
 PERFORM logistique.fn_assert_generique_category(NEW."ID_ConditionPaiementFk",37,'Facture','ID_ConditionPaiementFk');
 IF (TG_OP='INSERT' OR NEW."ID_ModePaiementFk" IS DISTINCT FROM OLD."ID_ModePaiementFk") AND NEW."ID_ModePaiementFk" IS NOT NULL
 AND NOT EXISTS(SELECT 1 FROM referentiel."T_Generique" g JOIN referentiel."T_CategorieGenerique" c ON c."ID_CategorieGenerique"=g."ID_CategorieGeneriqueFk"
   WHERE g."ID_Generique"=NEW."ID_ModePaiementFk" AND g."ValideGenerique" IS TRUE AND c."ValideCategorieGenerique" IS TRUE) THEN
  RAISE EXCEPTION 'Mode de paiement inactif.' USING ERRCODE='23514'; END IF;
 IF (TG_OP='INSERT' OR NEW."ID_ConditionPaiementFk" IS DISTINCT FROM OLD."ID_ConditionPaiementFk") AND NEW."ID_ConditionPaiementFk" IS NOT NULL
 AND NOT EXISTS(SELECT 1 FROM referentiel."T_Generique" g JOIN referentiel."T_CategorieGenerique" c ON c."ID_CategorieGenerique"=g."ID_CategorieGeneriqueFk"
   WHERE g."ID_Generique"=NEW."ID_ConditionPaiementFk" AND g."ValideGenerique" IS TRUE AND c."ValideCategorieGenerique" IS TRUE) THEN
  RAISE EXCEPTION 'Condition de paiement inactive.' USING ERRCODE='23514'; END IF;
 RETURN NEW;
END $fn$;
CREATE TRIGGER facture_protection BEFORE INSERT OR UPDATE OR DELETE ON logistique."T_Facture"
 FOR EACH ROW EXECUTE FUNCTION logistique.tr_proteger_facture();

CREATE FUNCTION logistique.tr_proteger_ligne_facture() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $fn$
DECLARE invoice logistique."T_Facture"; created_xid bigint;
BEGIN
 IF TG_OP<>'INSERT' THEN RAISE EXCEPTION 'Les lignes d’une facture émise sont immuables.' USING ERRCODE='23514'; END IF;
 SELECT f.* INTO invoice FROM logistique."T_Facture" f WHERE f."ID_Facture"=NEW."ID_FactureFk";
 SELECT f."TransactionCreation" INTO created_xid FROM logistique."T_Facture" f WHERE f."ID_Facture"=NEW."ID_FactureFk";
 IF created_xid IS DISTINCT FROM txid_current() OR NEW."ID_CmdFk" IS DISTINCT FROM invoice."ID_CommandeFk" THEN
    RAISE EXCEPTION 'Les lignes sont figées lors de l’émission.' USING ERRCODE='23514'; END IF;
 RETURN NEW;
END $fn$;
CREATE TRIGGER facture_ligne_protection BEFORE INSERT OR UPDATE OR DELETE ON logistique."T_FactureLigne"
 FOR EACH ROW EXECUTE FUNCTION logistique.tr_proteger_ligne_facture();

CREATE FUNCTION logistique.tr_verifier_snapshot_facture() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $fn$
DECLARE invoice logistique."T_Facture"; parent logistique."T_Commande"; total numeric;
BEGIN
 IF TG_TABLE_NAME='T_FactureLigne' THEN
  SELECT * INTO invoice FROM logistique."T_Facture" WHERE "ID_Facture"=NEW."ID_FactureFk";
 ELSE SELECT * INTO invoice FROM logistique."T_Facture" WHERE "ID_Facture"=NEW."ID_Facture"; END IF;
 SELECT * INTO parent FROM logistique."T_Commande" WHERE "ID_Commande"=invoice."ID_CommandeFk";
 IF parent."CodeFacture" IS DISTINCT FROM invoice."CodeFacture" OR parent."DateFacture" IS DISTINCT FROM invoice."DateFacture"
 OR parent."DateEcheancePaiement" IS DISTINCT FROM invoice."DateEcheancePaiement"
 OR parent."ID_ModePaiementFk" IS DISTINCT FROM invoice."ID_ModePaiementFk"
 OR parent."ID_ConditionPaiementFk" IS DISTINCT FROM invoice."ID_ConditionPaiementFk" THEN
   RAISE EXCEPTION 'Le miroir de facture du bon doit rester cohérent.' USING ERRCODE='23514'; END IF;
 IF TG_OP='INSERT' THEN
  SELECT sum("MontantLigne") INTO total FROM logistique."T_FactureLigne" WHERE "ID_FactureFk"=invoice."ID_Facture";
  IF total IS DISTINCT FROM invoice."MontantTTC" THEN RAISE EXCEPTION 'Total de facture différent de ses lignes.' USING ERRCODE='23514'; END IF;
  IF EXISTS(
   WITH returned AS (SELECT d."ID_ArticleFk",sum(d."QteCmdDetail") AS n FROM logistique."T_RetourBon" r
     JOIN logistique."T_CommandeDetail" d ON d."ID_CmdFk"=r."ID_CommandeRetourFk"
     WHERE r."ID_CommandeOrigineFk"=invoice."ID_CommandeFk" GROUP BY d."ID_ArticleFk")
   SELECT 1 FROM (SELECT * FROM logistique."T_CommandeDetail" WHERE "ID_CmdFk"=invoice."ID_CommandeFk") d
   LEFT JOIN returned r ON r."ID_ArticleFk"=d."ID_ArticleFk"
   FULL JOIN (SELECT * FROM logistique."T_FactureLigne" WHERE "ID_FactureFk"=invoice."ID_Facture") l ON l."ID_ArticleFk"=d."ID_ArticleFk"
   WHERE (d."ID_CmdFk"=invoice."ID_CommandeFk" OR l."ID_FactureFk"=invoice."ID_Facture")
    AND ((COALESCE(d."QteCmdDetail",0)-COALESCE(r.n,0)>0 AND
          (l."ID_FactureLigne" IS NULL OR l."ID_CmdFk"<>invoice."ID_CommandeFk"
           OR l."QteSortie" IS DISTINCT FROM d."QteCmdDetail" OR l."PUFacture" IS DISTINCT FROM d."PUCmdDetail"
           OR l."QteRetourAvantFacture" IS DISTINCT FROM COALESCE(r.n,0)))
         OR (COALESCE(d."QteCmdDetail",0)-COALESCE(r.n,0)<=0 AND l."ID_FactureLigne" IS NOT NULL))) THEN
   RAISE EXCEPTION 'Les lignes facturées doivent correspondre aux quantités nettes du bon.' USING ERRCODE='23514'; END IF;
 END IF;
 RETURN NULL;
END $fn$;
CREATE CONSTRAINT TRIGGER facture_snapshot_coherent AFTER INSERT OR UPDATE ON logistique."T_Facture"
 DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION logistique.tr_verifier_snapshot_facture();
CREATE CONSTRAINT TRIGGER facture_ligne_coherente AFTER INSERT ON logistique."T_FactureLigne"
 DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION logistique.tr_verifier_snapshot_facture();

CREATE FUNCTION logistique.tr_proteger_bon_facture() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $fn$
DECLARE invoice logistique."T_Facture";
BEGIN
 SELECT * INTO invoice FROM logistique."T_Facture" WHERE "ID_CommandeFk"=OLD."ID_Commande";
 IF NOT FOUND THEN RETURN CASE WHEN TG_OP='DELETE' THEN OLD ELSE NEW END; END IF;
 IF TG_OP='DELETE' THEN RAISE EXCEPTION 'Le bon d’une facture émise est conservé.' USING ERRCODE='23514'; END IF;
 IF (to_jsonb(NEW)-ARRAY['DateFacture','DateEcheancePaiement','CodeFacture','ID_ModePaiementFk','ID_ConditionPaiementFk','DateHeureAutoFacture','StatusFacture','MontantRegleFacture','MontantResteFacture']) IS DISTINCT FROM
    (to_jsonb(OLD)-ARRAY['DateFacture','DateEcheancePaiement','CodeFacture','ID_ModePaiementFk','ID_ConditionPaiementFk','DateHeureAutoFacture','StatusFacture','MontantRegleFacture','MontantResteFacture']) THEN
   RAISE EXCEPTION 'Le panier et les informations de stock d’un bon facturé sont conservés.' USING ERRCODE='23514'; END IF;
 IF NEW."CodeFacture" IS DISTINCT FROM invoice."CodeFacture" OR NEW."DateFacture" IS DISTINCT FROM invoice."DateFacture"
 OR NEW."DateEcheancePaiement" IS DISTINCT FROM invoice."DateEcheancePaiement"
 OR NEW."ID_ModePaiementFk" IS DISTINCT FROM invoice."ID_ModePaiementFk" OR NEW."ID_ConditionPaiementFk" IS DISTINCT FROM invoice."ID_ConditionPaiementFk" THEN
   RAISE EXCEPTION 'Utilisez le service de facturation pour modifier ses métadonnées.' USING ERRCODE='23514'; END IF;
 RETURN NEW;
END $fn$;
CREATE TRIGGER facture_bon_protection BEFORE UPDATE OR DELETE ON logistique."T_Commande"
 FOR EACH ROW EXECUTE FUNCTION logistique.tr_proteger_bon_facture();

CREATE FUNCTION logistique.tr_proteger_stock_facture() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $fn$
DECLARE old_id integer; new_id integer; command_ids integer[];
BEGIN
 IF TG_TABLE_NAME='T_CommandeDetail' THEN
   IF TG_OP<>'INSERT' THEN old_id:=OLD."ID_CmdFk"; END IF;
   IF TG_OP<>'DELETE' THEN new_id:=NEW."ID_CmdFk"; END IF;
 ELSIF TG_TABLE_NAME='T_Mouvement' THEN
   IF TG_OP<>'INSERT' THEN old_id:=OLD."ID_cmdFk"; END IF;
   IF TG_OP<>'DELETE' THEN new_id:=NEW."ID_cmdFk"; END IF;
 ELSE
   IF TG_OP<>'INSERT' THEN SELECT "ID_cmdFk" INTO old_id FROM logistique."T_Mouvement" WHERE "ID_Mvt"=OLD."ID_MvtFk"; END IF;
   IF TG_OP<>'DELETE' THEN SELECT "ID_cmdFk" INTO new_id FROM logistique."T_Mouvement" WHERE "ID_Mvt"=NEW."ID_MvtFk"; END IF;
 END IF;
 command_ids:=ARRAY[old_id,new_id];
 PERFORM 1 FROM logistique."T_Commande" WHERE "ID_Commande"=ANY(command_ids) ORDER BY "ID_Commande" FOR UPDATE;
 IF EXISTS(SELECT 1 FROM logistique."T_Facture" WHERE "ID_CommandeFk"=ANY(command_ids)) THEN
   RAISE EXCEPTION 'Les lignes et mouvements d’un bon facturé sont immuables.' USING ERRCODE='23514'; END IF;
 IF TG_OP='DELETE' THEN RETURN OLD; ELSE RETURN NEW; END IF;
END $fn$;
CREATE TRIGGER facture_detail_protection BEFORE INSERT OR UPDATE OR DELETE ON logistique."T_CommandeDetail"
 FOR EACH ROW EXECUTE FUNCTION logistique.tr_proteger_stock_facture();
CREATE TRIGGER facture_mouvement_protection BEFORE INSERT OR UPDATE OR DELETE ON logistique."T_Mouvement"
 FOR EACH ROW EXECUTE FUNCTION logistique.tr_proteger_stock_facture();
CREATE TRIGGER facture_mouvement_lot_protection BEFORE INSERT OR UPDATE OR DELETE ON logistique."T_MouvementLot"
 FOR EACH ROW EXECUTE FUNCTION logistique.tr_proteger_stock_facture();

CREATE FUNCTION logistique.tr_proteger_identite_lot_facture() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $fn$
BEGIN
 IF (NEW."NumeroLot",NEW."DatePeremptionLot",NEW."ID_ArticleFk") IS DISTINCT FROM
    (OLD."NumeroLot",OLD."DatePeremptionLot",OLD."ID_ArticleFk") THEN
  PERFORM 1 FROM logistique."T_Commande" c WHERE c."ID_Commande" IN
    (SELECT m."ID_cmdFk" FROM logistique."T_MouvementLot" ml JOIN logistique."T_Mouvement" m ON m."ID_Mvt"=ml."ID_MvtFk"
     WHERE ml."ID_LotArticleFk"=OLD."ID_LotArticle") ORDER BY c."ID_Commande" FOR UPDATE;
  IF EXISTS(SELECT 1 FROM logistique."T_MouvementLot" ml JOIN logistique."T_Mouvement" m ON m."ID_Mvt"=ml."ID_MvtFk"
    JOIN logistique."T_Facture" f ON f."ID_CommandeFk"=m."ID_cmdFk" WHERE ml."ID_LotArticleFk"=OLD."ID_LotArticle") THEN
    RAISE EXCEPTION 'L’identité d’un lot présent sur une facture est conservée.' USING ERRCODE='23514'; END IF;
 END IF;
 RETURN NEW;
END $fn$;
CREATE TRIGGER facture_lot_identite BEFORE UPDATE ON logistique."T_LotArticle"
 FOR EACH ROW EXECUTE FUNCTION logistique.tr_proteger_identite_lot_facture();

CREATE VIEW logistique."V_FactureLigne" AS
 SELECT l.*,f."ID_CommandeFk",f."CodeFacture",f."ID_DeviseFk",f."DeviseCode",f."DeviseLibelle"
 FROM logistique."T_FactureLigne" l JOIN logistique."T_Facture" f ON f."ID_Facture"=l."ID_FactureFk";
CREATE VIEW logistique."V_Facture" AS
 WITH payments AS (SELECT "CodeFactureFk",COALESCE(sum("MontantRegle"),0)::numeric(12,2) AS total,
                  count(*) AS n,max("DateReglement") AS last FROM logistique."T_Reglements" GROUP BY "CodeFactureFk"),
 returned AS (SELECT r."ID_CommandeOrigineFk" AS command_id,d."ID_ArticleFk",sum(d."QteCmdDetail") AS quantity
             FROM logistique."T_RetourBon" r JOIN logistique."T_CommandeDetail" d ON d."ID_CmdFk"=r."ID_CommandeRetourFk"
             GROUP BY r."ID_CommandeOrigineFk",d."ID_ArticleFk"),
 credit AS (SELECT l."ID_FactureFk",sum(greatest(COALESCE(r.quantity,0)-l."QteRetourAvantFacture",0)*l."PUFacture")::numeric(12,2) AS total
            FROM logistique."T_FactureLigne" l LEFT JOIN returned r ON r.command_id=l."ID_CmdFk" AND r."ID_ArticleFk"=l."ID_ArticleFk"
            GROUP BY l."ID_FactureFk")
 SELECT f.*,f."MontantTTC" AS "MontantFacture",COALESCE(p.total,0)::numeric(12,2) AS "TotalRegle",
  (f."MontantTTC"-COALESCE(p.total,0))::numeric(12,2) AS "Reste",COALESCE(p.n,0)::bigint AS "NbReglements",p.last AS "DernierReglement",
  CASE WHEN COALESCE(p.total,0)<=0 THEN 'Non réglée' WHEN p.total<f."MontantTTC" THEN 'Partiellement réglée' ELSE 'Réglée' END AS "EtatReglement",
  (f."DateEcheancePaiement"::date<CURRENT_DATE AND f."MontantTTC">COALESCE(p.total,0)) AS "EstEnRetard",
  (f."DateEcheancePaiement"::date-CURRENT_DATE)::integer AS "JoursAvantEcheance",
  COALESCE(c.total,0)::numeric(12,2) AS "MontantAvoirAEtablir",COALESCE(c.total,0)>0 AS "AvoirAEtablir"
 FROM logistique."T_Facture" f LEFT JOIN payments p ON p."CodeFactureFk"=f."CodeFacture"
 LEFT JOIN credit c ON c."ID_FactureFk"=f."ID_Facture";

CREATE OR REPLACE VIEW logistique."V_Commande" AS SELECT
 (base."ID_Commande")::integer AS "ID_Commande",
 (base."ID_TypeCmdFk")::integer AS "ID_TypeCmdFk",
 (base."ID_StatutCmdFk")::integer AS "ID_StatutCmdFk",
 (base."ID_ClientFk")::integer AS "ID_ClientFk",
 (base."ID_UserFk")::integer AS "ID_UserFk",
 (base."geolocalisationCmd")::character varying(255) AS "geolocalisationCmd",
 (base."DateHeureAutoCmd")::timestamp with time zone AS "DateHeureAutoCmd",
 (base."DateCmd")::timestamp with time zone AS "DateCmd",
 (base."CodeCmd")::character varying(20) AS "CodeCmd",
 (base."RefCmd")::character varying(255) AS "RefCmd",
 (base."MontantHT")::numeric(12,2) AS "MontantHT",
 (base."MontantTTC")::numeric(12,2) AS "MontantTTC",
 (base."UrlBL")::character varying(255) AS "UrlBL",
 (base."ObsCmd")::character varying(255) AS "ObsCmd",
 (base."SelectCmd")::boolean AS "SelectCmd",
 (base."DateHeureAutoFacture")::timestamp with time zone AS "DateHeureAutoFacture",
 (base."DateFacture")::timestamp with time zone AS "DateFacture",
 (base."CodeFacture")::character varying(255) AS "CodeFacture",
 (COALESCE(f."TotalRegle",base."MontantRegleFacture"))::numeric(12,2) AS "MontantRegleFacture",
 (COALESCE(f."Reste",base."MontantResteFacture"))::numeric(12,2) AS "MontantResteFacture",
 (base."StatusFacture")::character varying(243) AS "StatusFacture",
 (base."ValideRemiseFacture")::boolean AS "ValideRemiseFacture",
 (base."UrlFacture")::character varying(255) AS "UrlFacture",
 (base."ID_ConditionPaiementFk")::integer AS "ID_ConditionPaiementFk",
 (base."DateEcheancePaiement")::timestamp with time zone AS "DateEcheancePaiement",
 (base."ID_ModePaiementFk")::integer AS "ID_ModePaiementFk",
 (base."NomClientSaisi")::character varying(255) AS "NomClientSaisi",
 (base."AbrTypeCmd")::character varying(255) AS "AbrTypeCmd",
 (base."TypeCmd")::character varying(255) AS "TypeCmd",
 (base."SigneCommande")::integer AS "SigneCommande",
 (base."EstCommandeEntree")::boolean AS "EstCommandeEntree",
 (base."EstCommandeSortie")::boolean AS "EstCommandeSortie",
 (base."AbrStatutCmd")::character varying(255) AS "AbrStatutCmd",
 (base."StatutCmd")::character varying(255) AS "StatutCmd",
 (base."NomUser")::character varying(100) AS "NomUser",
 (base."PrenomUser")::character varying(100) AS "PrenomUser",
 (base."NomComplet")::text AS "NomComplet",
 (base."AbrConditionPaiement")::character varying(255) AS "AbrConditionPaiement",
 (base."ConditionPaiement")::character varying(255) AS "ConditionPaiement",
 (base."AbrModePaiement")::character varying(255) AS "AbrModePaiement",
 (base."ModePaiement")::character varying(255) AS "ModePaiement",
 (base."MontantHTCalc")::numeric(12,2) AS "MontantHTCalc",
 (base."MontantTTCCalc")::numeric(12,2) AS "MontantTTCCalc",
 (COALESCE(f."TotalRegle",base."MontantRegleFactureCalc"))::numeric(12,2) AS "MontantRegleFactureCalc",
 (COALESCE(f."Reste",base."MontantResteFactureCalc"))::numeric(12,2) AS "MontantResteFactureCalc",
 (COALESCE(f."TotalRegle",base."TotalRegleReel"))::numeric(12,2) AS "TotalRegleReel",
 (COALESCE(f."Reste",base."ResteReel"))::numeric(12,2) AS "ResteReel",
 (base."NbReglements")::integer AS "NbReglements",
 (base."DernierReglement")::timestamp without time zone AS "DernierReglement",
 (COALESCE(f."EtatReglement",base."EtatPaiement"))::text AS "EtatPaiement",
 (COALESCE(f."EstEnRetard",base."EstPaiementEnRetard"))::boolean AS "EstPaiementEnRetard",
 (base."JoursAvantEcheance")::integer AS "JoursAvantEcheance",
 (base."NbLignes")::integer AS "NbLignes",
 (base."NbArticlesDistincts")::integer AS "NbArticlesDistincts",
 (base."QteTotale")::numeric(14,3) AS "QteTotale",
 (base."MontantDetails")::numeric(12,2) AS "MontantDetails",
 (base."ListeArticles")::text AS "ListeArticles",
 (base."EstCommandeSansDetails")::boolean AS "EstCommandeSansDetails",
 (base."EcartMontantDetails")::numeric(12,2) AS "EcartMontantDetails",
 (base."EstMontantIncoherent")::boolean AS "EstMontantIncoherent",
 (base."EtatControleCommande")::text AS "EtatControleCommande",
 (base."ID_DeviseFk")::integer AS "ID_DeviseFk",
 (COALESCE(f."DeviseCode",base."DeviseCode"))::text AS "DeviseCode",
 (COALESCE(f."DeviseLibelle",base."DeviseLibelle"))::text AS "DeviseLibelle",
 f."ID_Facture",
 (f."ID_Facture" IS NOT NULL) AS "EstFactureSnapshot",
 (CASE WHEN NULLIF(btrim(base."CodeFacture"),'') IS NOT NULL THEN COALESCE(f."MontantTTC",base."MontantTTC") ELSE NULL END)::numeric(12,2) AS "MontantFacture",
 COALESCE(f."MontantAvoirAEtablir",0)::numeric(12,2) AS "MontantAvoirAEtablir",
 COALESCE(f."AvoirAEtablir",false) AS "AvoirAEtablir"
FROM (
 SELECT historique."ID_Commande",
    historique."ID_TypeCmdFk",
    historique."ID_StatutCmdFk",
    historique."ID_ClientFk",
    historique."ID_UserFk",
    historique."geolocalisationCmd",
    historique."DateHeureAutoCmd",
    historique."DateCmd",
    historique."CodeCmd",
    historique."RefCmd",
    historique."MontantHT",
    historique."MontantTTC",
    historique."UrlBL",
    historique."ObsCmd",
    historique."SelectCmd",
    historique."DateHeureAutoFacture",
    historique."DateFacture",
    historique."CodeFacture",
    historique."MontantRegleFacture",
    historique."MontantResteFacture",
    historique."StatusFacture",
    historique."ValideRemiseFacture",
    historique."UrlFacture",
    historique."ID_ConditionPaiementFk",
    historique."DateEcheancePaiement",
    historique."ID_ModePaiementFk",
    historique."NomClientSaisi",
    historique."AbrTypeCmd",
    historique."TypeCmd",
    historique."SigneCommande",
    historique."EstCommandeEntree",
    historique."EstCommandeSortie",
    historique."AbrStatutCmd",
    historique."StatutCmd",
    historique."NomUser",
    historique."PrenomUser",
    historique."NomComplet",
    historique."AbrConditionPaiement",
    historique."ConditionPaiement",
    historique."AbrModePaiement",
    historique."ModePaiement",
    historique."MontantHTCalc",
    historique."MontantTTCCalc",
    historique."MontantRegleFactureCalc",
    historique."MontantResteFactureCalc",
    historique."TotalRegleReel",
    historique."ResteReel",
    historique."NbReglements",
    historique."DernierReglement",
    historique."EtatPaiement",
    historique."EstPaiementEnRetard",
    historique."JoursAvantEcheance",
    historique."NbLignes",
    historique."NbArticlesDistincts",
    historique."QteTotale",
    historique."MontantDetails",
    historique."ListeArticles",
    historique."EstCommandeSansDetails",
    historique."EcartMontantDetails",
    historique."EstMontantIncoherent",
    historique."EtatControleCommande",
    source."ID_DeviseFk",
    logistique.fn_code_devise(devise."AbrGenerique"::text) AS "DeviseCode",
    devise."NomGenerique"::text AS "DeviseLibelle"
   FROM ( WITH cd_stats AS (
                 SELECT cd."ID_CmdFk",
                    count(*)::integer AS "NbLignes",
                    count(DISTINCT cd."ID_ArticleFk")::integer AS "NbArticlesDistincts",
                    COALESCE(sum(COALESCE(cd."QteCmdDetail", 0::numeric)), 0::numeric)::numeric(14,3) AS "QteTotale",
                    COALESCE(sum(COALESCE(cd."QteCmdDetail", 0::numeric) * COALESCE(cd."PUCmdDetail", 0::numeric)), 0::numeric)::numeric(12,2) AS "MontantDetails",
                    string_agg(DISTINCT a."NomArticle"::text, ', '::text ORDER BY (a."NomArticle"::text)) AS "ListeArticles"
                   FROM logistique."T_CommandeDetail" cd
                     LEFT JOIN logistique."T_Article" a ON a."ID_Article" = cd."ID_ArticleFk"
                  GROUP BY cd."ID_CmdFk"
                ), reg_stats AS (
                 SELECT r."CodeFactureFk",
                    COALESCE(sum(COALESCE(r."MontantRegle", 0::numeric)), 0::numeric)::numeric(12,2) AS "TotalRegleReel",
                    count(*)::integer AS "NbReglements",
                    max(r."DateReglement") AS "DernierReglement"
                   FROM logistique."T_Reglements" r
                  GROUP BY r."CodeFactureFk"
                )
         SELECT c."ID_Commande",
            c."ID_TypeCmdFk",
            c."ID_StatutCmdFk",
            c."ID_ClientFk",
            c."ID_UserFk",
            c."geolocalisationCmd",
            c."DateHeureAutoCmd",
            c."DateCmd",
            c."CodeCmd",
            c."RefCmd",
            c."MontantHT",
            c."MontantTTC",
            c."UrlBL",
            c."ObsCmd",
            c."SelectCmd",
            c."DateHeureAutoFacture",
            c."DateFacture",
            c."CodeFacture",
            c."MontantRegleFacture",
            c."MontantResteFacture",
            c."StatusFacture",
            c."ValideRemiseFacture",
            c."UrlFacture",
            c."ID_ConditionPaiementFk",
            c."DateEcheancePaiement",
            c."ID_ModePaiementFk",
            c."NomClientSaisi",
            type_cmd."AbrGenerique" AS "AbrTypeCmd",
            type_cmd."NomGenerique" AS "TypeCmd",
                CASE
                    WHEN type_cmd."AbrGenerique"::text ~~* 'entr%'::text THEN 1
                    WHEN type_cmd."AbrGenerique"::text ~~* 'sort%'::text THEN '-1'::integer
                    ELSE 0
                END AS "SigneCommande",
            COALESCE(type_cmd."AbrGenerique"::text ~~* 'entr%'::text, false) AS "EstCommandeEntree",
            COALESCE(type_cmd."AbrGenerique"::text ~~* 'sort%'::text, false) AS "EstCommandeSortie",
            statut_cmd."AbrGenerique" AS "AbrStatutCmd",
            statut_cmd."NomGenerique" AS "StatutCmd",
            u."NomUser",
            u."PrenomUser",
            NULLIF(TRIM(BOTH FROM concat(COALESCE(u."PrenomUser", ''::character varying), ' ', COALESCE(u."NomUser", ''::character varying))), ''::text) AS "NomComplet",
            condition_paiement."AbrGenerique" AS "AbrConditionPaiement",
            condition_paiement."NomGenerique" AS "ConditionPaiement",
            mode_paiement."AbrGenerique" AS "AbrModePaiement",
            mode_paiement."NomGenerique" AS "ModePaiement",
            COALESCE(c."MontantHT", 0::numeric)::numeric(12,2) AS "MontantHTCalc",
            COALESCE(c."MontantTTC", 0::numeric)::numeric(12,2) AS "MontantTTCCalc",
            COALESCE(c."MontantRegleFacture", 0::numeric)::numeric(12,2) AS "MontantRegleFactureCalc",
            COALESCE(c."MontantResteFacture", 0::numeric)::numeric(12,2) AS "MontantResteFactureCalc",
            COALESCE(reg_stats."TotalRegleReel", 0::numeric)::numeric(12,2) AS "TotalRegleReel",
            (COALESCE(c."MontantTTC", 0::numeric) - COALESCE(reg_stats."TotalRegleReel", 0::numeric))::numeric(12,2) AS "ResteReel",
            COALESCE(reg_stats."NbReglements", 0) AS "NbReglements",
            reg_stats."DernierReglement",
                CASE
                    WHEN c."CodeFacture" IS NULL THEN 'Non facturée'::text
                    WHEN COALESCE(c."MontantTTC", 0::numeric) = 0::numeric THEN 'Montant nul'::text
                    WHEN COALESCE(reg_stats."TotalRegleReel", COALESCE(c."MontantRegleFacture", 0::numeric), 0::numeric) <= 0::numeric THEN 'Non réglée'::text
                    WHEN COALESCE(reg_stats."TotalRegleReel", COALESCE(c."MontantRegleFacture", 0::numeric), 0::numeric) < COALESCE(c."MontantTTC", 0::numeric) THEN 'Partiellement réglée'::text
                    WHEN COALESCE(reg_stats."TotalRegleReel", COALESCE(c."MontantRegleFacture", 0::numeric), 0::numeric) >= COALESCE(c."MontantTTC", 0::numeric) THEN 'Réglée'::text
                    ELSE 'Indéterminé'::text
                END AS "EtatPaiement",
            c."DateEcheancePaiement" IS NOT NULL AND c."DateEcheancePaiement"::date < CURRENT_DATE AND (COALESCE(c."MontantTTC", 0::numeric) - COALESCE(reg_stats."TotalRegleReel", COALESCE(c."MontantRegleFacture", 0::numeric), 0::numeric)) > 0::numeric AS "EstPaiementEnRetard",
                CASE
                    WHEN c."DateEcheancePaiement" IS NOT NULL THEN c."DateEcheancePaiement"::date - CURRENT_DATE
                    ELSE NULL::integer
                END AS "JoursAvantEcheance",
            COALESCE(cd_stats."NbLignes", 0) AS "NbLignes",
            COALESCE(cd_stats."NbArticlesDistincts", 0) AS "NbArticlesDistincts",
            COALESCE(cd_stats."QteTotale", 0::numeric)::numeric(14,3) AS "QteTotale",
            COALESCE(cd_stats."MontantDetails", 0::numeric)::numeric(12,2) AS "MontantDetails",
            cd_stats."ListeArticles",
            COALESCE(cd_stats."NbLignes", 0) = 0 AS "EstCommandeSansDetails",
            (COALESCE(c."MontantHT", 0::numeric) - COALESCE(cd_stats."MontantDetails", 0::numeric))::numeric(12,2) AS "EcartMontantDetails",
            abs(COALESCE(c."MontantHT", 0::numeric) - COALESCE(cd_stats."MontantDetails", 0::numeric)) > 0.01 AS "EstMontantIncoherent",
                CASE
                    WHEN COALESCE(cd_stats."NbLignes", 0) = 0 THEN 'Sans détails'::text
                    WHEN abs(COALESCE(c."MontantHT", 0::numeric) - COALESCE(cd_stats."MontantDetails", 0::numeric)) > 0.01 THEN 'Montant incohérent'::text
                    ELSE 'Cohérente'::text
                END AS "EtatControleCommande"
           FROM logistique."T_Commande" c
             LEFT JOIN systeme."T_Utilisateurs" u ON c."ID_UserFk" = u."IdUser"
             LEFT JOIN referentiel."T_Generique" type_cmd ON c."ID_TypeCmdFk" = type_cmd."ID_Generique" AND type_cmd."ID_CategorieGeneriqueFk" = 64
             LEFT JOIN referentiel."T_Generique" statut_cmd ON c."ID_StatutCmdFk" = statut_cmd."ID_Generique" AND statut_cmd."ID_CategorieGeneriqueFk" = 28
             LEFT JOIN referentiel."T_Generique" condition_paiement ON c."ID_ConditionPaiementFk" = condition_paiement."ID_Generique" AND condition_paiement."ID_CategorieGeneriqueFk" = 37
             LEFT JOIN referentiel."T_Generique" mode_paiement ON c."ID_ModePaiementFk" = mode_paiement."ID_Generique" AND mode_paiement."ID_CategorieGeneriqueFk" = 36
             LEFT JOIN cd_stats ON cd_stats."ID_CmdFk" = c."ID_Commande"
             LEFT JOIN reg_stats ON reg_stats."CodeFactureFk"::text = c."CodeFacture"::text) historique
     LEFT JOIN logistique."T_Commande" source ON source."ID_Commande" = historique."ID_Commande"
     LEFT JOIN referentiel."T_Generique" devise ON devise."ID_Generique" = source."ID_DeviseFk"
) base LEFT JOIN logistique."V_Facture" f ON f."ID_CommandeFk"=base."ID_Commande";

CREATE OR REPLACE VIEW logistique."V_SuiviReglements" AS SELECT
 (base."ID_Commande")::integer AS "ID_Commande",
 (base."CodeCmd")::character varying(20) AS "CodeCmd",
 (base."CodeFacture")::character varying(255) AS "CodeFacture",
 (base."DateFacture")::timestamp with time zone AS "DateFacture",
 (base."DateEcheancePaiement")::timestamp with time zone AS "DateEcheancePaiement",
 (base."NomClientSaisi")::character varying(255) AS "NomClientSaisi",
 (COALESCE(f."MontantTTC",base."MontantTTC"))::numeric(12,2) AS "MontantTTC",
 (COALESCE(f."TotalRegle",base."TotalRegle"))::numeric(12,2) AS "TotalRegle",
 (COALESCE(f."Reste",base."Reste"))::numeric(12,2) AS "Reste",
 (base."NbReglements")::bigint AS "NbReglements",
 (base."DernierReglement")::timestamp without time zone AS "DernierReglement",
 (COALESCE(f."EtatReglement",base."EtatReglement"))::text AS "EtatReglement",
 (COALESCE(f."EstEnRetard",base."EstEnRetard"))::boolean AS "EstEnRetard",
 (base."JoursAvantEcheance")::integer AS "JoursAvantEcheance",
 (base."ID_DeviseFk")::integer AS "ID_DeviseFk",
 (COALESCE(f."DeviseCode",base."DeviseCode"))::text AS "DeviseCode",
 (COALESCE(f."DeviseLibelle",base."DeviseLibelle"))::text AS "DeviseLibelle",
 f."ID_Facture",
 (f."ID_Facture" IS NOT NULL) AS "EstFactureSnapshot",
 (CASE WHEN NULLIF(btrim(base."CodeFacture"),'') IS NOT NULL THEN COALESCE(f."MontantTTC",base."MontantTTC") ELSE NULL END)::numeric(12,2) AS "MontantFacture",
 COALESCE(f."MontantAvoirAEtablir",0)::numeric(12,2) AS "MontantAvoirAEtablir",
 COALESCE(f."AvoirAEtablir",false) AS "AvoirAEtablir",
 base."MontantTTC" AS "MontantBon"
FROM (
 SELECT historique."ID_Commande",
    historique."CodeCmd",
    historique."CodeFacture",
    historique."DateFacture",
    historique."DateEcheancePaiement",
    historique."NomClientSaisi",
    historique."MontantTTC",
    historique."TotalRegle",
    historique."Reste",
    historique."NbReglements",
    historique."DernierReglement",
    historique."EtatReglement",
    historique."EstEnRetard",
    historique."JoursAvantEcheance",
    source."ID_DeviseFk",
    logistique.fn_code_devise(devise."AbrGenerique"::text) AS "DeviseCode",
    devise."NomGenerique"::text AS "DeviseLibelle"
   FROM ( SELECT c."ID_Commande",
            c."CodeCmd",
            c."CodeFacture",
            c."DateFacture",
            c."DateEcheancePaiement",
            c."NomClientSaisi",
            COALESCE(c."MontantTTC", 0::numeric)::numeric(12,2) AS "MontantTTC",
            COALESCE(sum(r."MontantRegle"), 0::numeric)::numeric(12,2) AS "TotalRegle",
            (COALESCE(c."MontantTTC", 0::numeric) - COALESCE(sum(r."MontantRegle"), 0::numeric))::numeric(12,2) AS "Reste",
            count(r."ID_Reglement") AS "NbReglements",
            max(r."DateReglement") AS "DernierReglement",
                CASE
                    WHEN c."CodeFacture" IS NULL THEN 'Non facturée'::text
                    WHEN COALESCE(c."MontantTTC", 0::numeric) = 0::numeric THEN 'Montant nul'::text
                    WHEN COALESCE(sum(r."MontantRegle"), 0::numeric) <= 0::numeric THEN 'Non réglée'::text
                    WHEN COALESCE(sum(r."MontantRegle"), 0::numeric) < COALESCE(c."MontantTTC", 0::numeric) THEN 'Partiellement réglée'::text
                    ELSE 'Réglée'::text
                END AS "EtatReglement",
            c."DateEcheancePaiement" IS NOT NULL AND c."DateEcheancePaiement"::date < CURRENT_DATE AND (COALESCE(c."MontantTTC", 0::numeric) - COALESCE(sum(r."MontantRegle"), 0::numeric)) > 0::numeric AS "EstEnRetard",
                CASE
                    WHEN c."DateEcheancePaiement" IS NOT NULL THEN c."DateEcheancePaiement"::date - CURRENT_DATE
                    ELSE NULL::integer
                END AS "JoursAvantEcheance"
           FROM logistique."T_Commande" c
             LEFT JOIN logistique."T_Reglements" r ON r."CodeFactureFk"::text = c."CodeFacture"::text
          GROUP BY c."ID_Commande", c."CodeCmd", c."CodeFacture", c."DateFacture", c."DateEcheancePaiement", c."NomClientSaisi", c."MontantTTC") historique
     LEFT JOIN logistique."T_Commande" source ON source."ID_Commande" = historique."ID_Commande"
     LEFT JOIN referentiel."T_Generique" devise ON devise."ID_Generique" = source."ID_DeviseFk"
) base LEFT JOIN logistique."V_Facture" f ON f."ID_CommandeFk"=base."ID_Commande";
COMMENT ON TABLE logistique."T_Facture" IS 'Une facture par bon de sortie ; total net figé à l’émission, sans effet de stock ni taxe implicite.';
COMMENT ON TABLE logistique."T_FactureLigne" IS 'Copie financière des lignes nettes au moment de l’émission ; noms, unité, prix et quantités historiques immuables.';
COMMENT ON VIEW logistique."V_Facture" IS 'Facture figée et suivi financier calculé depuis les règlements réels ; retours postérieurs signalés comme avoir à établir, sans remboursement automatique.';
COMMENT ON VIEW logistique."V_FactureLigne" IS 'Lignes financières historiques liées à leur bon, article et devise de facturation.';
COMMENT ON VIEW logistique."V_Commande" IS 'Bons de stock et contrôle des lignes d’origine ; MontantTTC reste le montant du bon, MontantFacture et suivi financier viennent du snapshot émis.';
COMMENT ON VIEW logistique."V_SuiviReglements" IS 'Suivi de facturation : montant de facture émise, règlements exhaustifs et solde ; montant du bon disponible séparément.';
COMMENT ON COLUMN logistique."T_Facture"."ID_Facture" IS 'Identité interne de la facture, indépendante du code lisible.';
COMMENT ON COLUMN logistique."T_Facture"."ID_CommandeFk" IS 'Bon de sortie d’origine ; une seule facture émise par bon.';
COMMENT ON COLUMN logistique."T_Facture"."CodeFacture" IS 'Numéro serveur unique et immuable ; aucun numéro fourni par le client.';
COMMENT ON COLUMN logistique."T_Facture"."ID_UserFk" IS 'Auteur de l’émission de la facture.';
COMMENT ON COLUMN logistique."T_Facture"."IdEntiteFk" IS 'Organisation figée lors de l’émission.';
COMMENT ON COLUMN logistique."T_Facture"."RequestId" IS 'Identifiant de la demande pour les rejeux idempotents.';
COMMENT ON COLUMN logistique."T_Facture"."PayloadHash" IS 'Empreinte exacte de la demande d’émission, sans secret.';
COMMENT ON COLUMN logistique."T_Facture"."DateFacture" IS 'Date et heure d’émission métier, modifiables seulement avant règlement.';
COMMENT ON COLUMN logistique."T_Facture"."DateEcheancePaiement" IS 'Échéance explicite ; jamais déduite d’un identifiant de référence.';
COMMENT ON COLUMN logistique."T_Facture"."ID_ModePaiementFk" IS 'Mode de paiement du référentiel catégorie36.';
COMMENT ON COLUMN logistique."T_Facture"."ID_ConditionPaiementFk" IS 'Condition de paiement du référentiel catégorie37.';
COMMENT ON COLUMN logistique."T_Facture"."DelaiJours" IS 'Nombre de jours uniquement lorsque la condition les écrit explicitement ; NULL sinon.';
COMMENT ON COLUMN logistique."T_Facture"."ID_DeviseFk" IS 'Devise du bon figée à l’émission.';
COMMENT ON COLUMN logistique."T_Facture"."DeviseCode" IS 'Code de devise copié à l’émission.';
COMMENT ON COLUMN logistique."T_Facture"."DeviseLibelle" IS 'Libellé de devise copié à l’émission.';
COMMENT ON COLUMN logistique."T_Facture"."MontantHT" IS 'Somme des lignes nettes facturées ; aucune taxe créée implicitement.';
COMMENT ON COLUMN logistique."T_Facture"."MontantTTC" IS 'Montant exigible figé, égal au HT en l’absence de taxe explicite.';
COMMENT ON COLUMN logistique."T_Facture"."TransactionCreation" IS 'Transaction d’émission ; borne la création des lignes à la même transaction.';
COMMENT ON COLUMN logistique."T_Facture"."CreeLe" IS 'Horodatage technique de création immuable.';
COMMENT ON COLUMN logistique."T_Facture"."ModifieLe" IS 'Dernière modification autorisée des métadonnées.';
COMMENT ON COLUMN logistique."T_FactureLigne"."ID_FactureLigne" IS 'Identité interne de la ligne financière.';
COMMENT ON COLUMN logistique."T_FactureLigne"."ID_FactureFk" IS 'Facture à laquelle appartient la ligne.';
COMMENT ON COLUMN logistique."T_FactureLigne"."ID_CmdFk" IS 'Bon de sortie de la ligne d’origine.';
COMMENT ON COLUMN logistique."T_FactureLigne"."ID_ArticleFk" IS 'Article de la ligne d’origine.';
COMMENT ON COLUMN logistique."T_FactureLigne"."NomArticle" IS 'Désignation copiée lors de l’émission.';
COMMENT ON COLUMN logistique."T_FactureLigne"."CodeArticleInterne" IS 'Code article copié lors de l’émission.';
COMMENT ON COLUMN logistique."T_FactureLigne"."Unite" IS 'Unité copiée lors de l’émission ; aucune somme entre unités incompatibles.';
COMMENT ON COLUMN logistique."T_FactureLigne"."QteSortie" IS 'Quantité de la ligne de sortie d’origine.';
COMMENT ON COLUMN logistique."T_FactureLigne"."QteRetourAvantFacture" IS 'Quantité déjà retournée au moment de l’émission, déduite une seule fois.';
COMMENT ON COLUMN logistique."T_FactureLigne"."QteFacturee" IS 'Quantité nette positive : sortie moins retours antérieurs.';
COMMENT ON COLUMN logistique."T_FactureLigne"."PUFacture" IS 'Prix unitaire explicite du bon, copié sans conversion.';
COMMENT ON COLUMN logistique."T_FactureLigne"."MontantLigne" IS 'Quantité nette facturée multipliée par le prix historique.';
COMMENT ON COLUMN logistique."V_Commande"."ID_Facture" IS 'Identité interne de la facture, indépendante du code lisible.';
COMMENT ON COLUMN logistique."V_Commande"."EstFactureSnapshot" IS 'Vrai lorsqu’un instantané financier versionné existe.';
COMMENT ON COLUMN logistique."V_Commande"."MontantFacture" IS 'Montant du snapshot émis, NULL pour un bon non facturé ; historique conservé en compatibilité.';
COMMENT ON COLUMN logistique."V_Commande"."MontantAvoirAEtablir" IS 'Contrevaleur des retours postérieurs à l’émission ; aucun remboursement créé.';
COMMENT ON COLUMN logistique."V_Commande"."AvoirAEtablir" IS 'Des retours postérieurs nécessitent un avoir distinct ; la facture émise reste inchangée.';
COMMENT ON COLUMN logistique."V_SuiviReglements"."ID_Facture" IS 'Identité interne de la facture, indépendante du code lisible.';
COMMENT ON COLUMN logistique."V_SuiviReglements"."EstFactureSnapshot" IS 'Vrai lorsqu’un instantané financier versionné existe.';
COMMENT ON COLUMN logistique."V_SuiviReglements"."MontantFacture" IS 'Montant du snapshot émis, NULL pour un bon non facturé ; historique conservé en compatibilité.';
COMMENT ON COLUMN logistique."V_SuiviReglements"."MontantAvoirAEtablir" IS 'Contrevaleur des retours postérieurs à l’émission ; aucun remboursement créé.';
COMMENT ON COLUMN logistique."V_SuiviReglements"."AvoirAEtablir" IS 'Des retours postérieurs nécessitent un avoir distinct ; la facture émise reste inchangée.';
COMMENT ON COLUMN logistique."V_SuiviReglements"."MontantBon" IS 'Montant initial du bon de stock, indépendant du net facturé.';
COMMENT ON COLUMN logistique."V_Commande"."MontantRegleFacture" IS 'Suivi financier calculé sur le snapshot émis et ses règlements ; compatibilité des factures historiques sans réécriture.';
COMMENT ON COLUMN logistique."V_Commande"."MontantResteFacture" IS 'Suivi financier calculé sur le snapshot émis et ses règlements ; compatibilité des factures historiques sans réécriture.';
COMMENT ON COLUMN logistique."V_Commande"."MontantRegleFactureCalc" IS 'Suivi financier calculé sur le snapshot émis et ses règlements ; compatibilité des factures historiques sans réécriture.';
COMMENT ON COLUMN logistique."V_Commande"."MontantResteFactureCalc" IS 'Suivi financier calculé sur le snapshot émis et ses règlements ; compatibilité des factures historiques sans réécriture.';
COMMENT ON COLUMN logistique."V_Commande"."TotalRegleReel" IS 'Suivi financier calculé sur le snapshot émis et ses règlements ; compatibilité des factures historiques sans réécriture.';
COMMENT ON COLUMN logistique."V_Commande"."ResteReel" IS 'Suivi financier calculé sur le snapshot émis et ses règlements ; compatibilité des factures historiques sans réécriture.';
COMMENT ON COLUMN logistique."V_Commande"."EtatPaiement" IS 'Suivi financier calculé sur le snapshot émis et ses règlements ; compatibilité des factures historiques sans réécriture.';
COMMENT ON COLUMN logistique."V_Commande"."EstPaiementEnRetard" IS 'Suivi financier calculé sur le snapshot émis et ses règlements ; compatibilité des factures historiques sans réécriture.';
COMMENT ON COLUMN logistique."V_Commande"."DeviseCode" IS 'Suivi financier calculé sur le snapshot émis et ses règlements ; compatibilité des factures historiques sans réécriture.';
COMMENT ON COLUMN logistique."V_Commande"."DeviseLibelle" IS 'Suivi financier calculé sur le snapshot émis et ses règlements ; compatibilité des factures historiques sans réécriture.';
COMMENT ON COLUMN logistique."V_SuiviReglements"."MontantTTC" IS 'Suivi financier calculé sur le snapshot émis et ses règlements ; compatibilité des factures historiques sans réécriture.';
COMMENT ON COLUMN logistique."V_SuiviReglements"."TotalRegle" IS 'Suivi financier calculé sur le snapshot émis et ses règlements ; compatibilité des factures historiques sans réécriture.';
COMMENT ON COLUMN logistique."V_SuiviReglements"."Reste" IS 'Suivi financier calculé sur le snapshot émis et ses règlements ; compatibilité des factures historiques sans réécriture.';
COMMENT ON COLUMN logistique."V_SuiviReglements"."EtatReglement" IS 'Suivi financier calculé sur le snapshot émis et ses règlements ; compatibilité des factures historiques sans réécriture.';
COMMENT ON COLUMN logistique."V_SuiviReglements"."EstEnRetard" IS 'Suivi financier calculé sur le snapshot émis et ses règlements ; compatibilité des factures historiques sans réécriture.';
COMMENT ON COLUMN logistique."V_SuiviReglements"."DeviseCode" IS 'Suivi financier calculé sur le snapshot émis et ses règlements ; compatibilité des factures historiques sans réécriture.';
COMMENT ON COLUMN logistique."V_SuiviReglements"."DeviseLibelle" IS 'Suivi financier calculé sur le snapshot émis et ses règlements ; compatibilité des factures historiques sans réécriture.';
DO $comments$
DECLARE row record;
BEGIN
 FOR row IN SELECT c.conname,n.nspname,t.relname FROM pg_constraint c JOIN pg_class t ON t.oid=c.conrelid
 JOIN pg_namespace n ON n.oid=t.relnamespace WHERE n.nspname='logistique' AND t.relname IN ('T_Facture','T_FactureLigne')
 LOOP EXECUTE format('COMMENT ON CONSTRAINT %I ON %I.%I IS %L',row.conname,row.nspname,row.relname,
  'Intégrité de l’instantané financier : source conservée, unicité, quantités et montants cohérents.'); END LOOP;
 FOR row IN SELECT i.relname FROM pg_index x JOIN pg_class i ON i.oid=x.indexrelid JOIN pg_class t ON t.oid=x.indrelid
 JOIN pg_namespace n ON n.oid=t.relnamespace WHERE n.nspname='logistique' AND t.relname IN ('T_Facture','T_FactureLigne')
 LOOP EXECUTE format('COMMENT ON INDEX logistique.%I IS %L',row.relname,
  'Unicité et accès aux instantanés de facturation par identité, bon, article ou demande idempotente.'); END LOOP;
 FOR row IN SELECT t.relname,c.attname FROM pg_attribute c JOIN pg_class t ON t.oid=c.attrelid JOIN pg_namespace n ON n.oid=t.relnamespace
 WHERE n.nspname='logistique' AND t.relname IN ('V_Facture','V_FactureLigne') AND c.attnum>0 AND NOT c.attisdropped
 LOOP EXECUTE format('COMMENT ON COLUMN logistique.%I.%I IS %L',row.relname,row.attname,
  'Projection financière : '||row.attname||' ; snapshot émis ou agrégat exhaustif de ses règlements/retours.'); END LOOP;
END $comments$;
COMMENT ON FUNCTION logistique.tr_proteger_facture() IS 'Interdit suppression et modification du snapshot ; seules les métadonnées restent modifiables avant règlement.';
COMMENT ON FUNCTION logistique.tr_proteger_ligne_facture() IS 'Les lignes sont créées dans la transaction de leur facture puis conservées sans modification.';
COMMENT ON FUNCTION logistique.tr_verifier_snapshot_facture() IS 'Contrôle différé du miroir, du total et des quantités nettes avant émission ; aucun mouvement de stock.';
COMMENT ON FUNCTION logistique.tr_proteger_bon_facture() IS 'Conserve les valeurs du bon facturé et vérifie le miroir financier sans mise à jour de stock.';
COMMENT ON FUNCTION logistique.tr_proteger_stock_facture() IS 'Refuse les écritures de lignes et mouvements d’un bon déjà facturé.';
COMMENT ON FUNCTION logistique.tr_proteger_identite_lot_facture() IS 'Conserve numéro, péremption et article des lots ventilés sur un bon facturé ; leur stock futur reste géré par de nouveaux mouvements.';
COMMENT ON TRIGGER facture_protection ON logistique."T_Facture" IS 'Protection des données financières historiques.';
COMMENT ON TRIGGER facture_ligne_protection ON logistique."T_FactureLigne" IS 'Copie initiale unique des lignes nettes.';
COMMENT ON TRIGGER facture_snapshot_coherent ON logistique."T_Facture" IS 'Validation atomique en fin de transaction de l’émission et de son miroir.';
COMMENT ON TRIGGER facture_ligne_coherente ON logistique."T_FactureLigne" IS 'Revalide le snapshot après chaque ajout initial, même si un appelant a déjà forcé des contraintes immédiates.';
COMMENT ON TRIGGER facture_bon_protection ON logistique."T_Commande" IS 'Immutabilité du bon de stock après émission de sa facture.';
COMMENT ON TRIGGER facture_detail_protection ON logistique."T_CommandeDetail" IS 'Empêche une modification du panier après facturation.';
COMMENT ON TRIGGER facture_mouvement_protection ON logistique."T_Mouvement" IS 'Empêche une modification des mouvements d’origine après facturation.';
COMMENT ON TRIGGER facture_mouvement_lot_protection ON logistique."T_MouvementLot" IS 'Vérifie les parents ancien et nouveau et conserve les ventilations historiques facturées.';
COMMENT ON TRIGGER facture_lot_identite ON logistique."T_LotArticle" IS 'Empêche un renommage ou une autre identité de lot de modifier les références d’une facture historique.';
DO $unchanged$
BEGIN
 IF EXISTS(
  (SELECT 'T_Commande' AS object,count(*) AS n,md5(COALESCE(string_agg(md5(to_jsonb(t)::text),'' ORDER BY "ID_Commande"),'')) AS fingerprint FROM logistique."T_Commande" t
   UNION ALL SELECT 'T_CommandeDetail',count(*),md5(COALESCE(string_agg(md5(to_jsonb(t)::text),'' ORDER BY "ID_CmdFk","ID_ArticleFk"),'')) FROM logistique."T_CommandeDetail" t
   UNION ALL SELECT 'T_Reglements',count(*),md5(COALESCE(string_agg(md5(to_jsonb(t)::text),'' ORDER BY "ID_Reglement"),'')) FROM logistique."T_Reglements" t
 UNION ALL SELECT 'T_Article',count(*),md5(COALESCE(string_agg(md5(to_jsonb(t)::text),'' ORDER BY "ID_Article"),'')) FROM logistique."T_Article" t
 UNION ALL SELECT 'T_Mouvement',count(*),md5(COALESCE(string_agg(md5(to_jsonb(t)::text),'' ORDER BY "ID_Mvt"),'')) FROM logistique."T_Mouvement" t
 UNION ALL SELECT 'T_MouvementLot',count(*),md5(COALESCE(string_agg(md5(to_jsonb(t)::text),'' ORDER BY "ID_MvtFk","ID_LotArticleFk"),'')) FROM logistique."T_MouvementLot" t
 UNION ALL SELECT 'T_LotArticle',count(*),md5(COALESCE(string_agg(md5(to_jsonb(t)::text),'' ORDER BY "ID_LotArticle"),'')) FROM logistique."T_LotArticle" t)
  EXCEPT SELECT * FROM facture_07_before) THEN RAISE EXCEPTION 'Des documents historiques ont changé'; END IF;
END $unchanged$;
COMMIT;
