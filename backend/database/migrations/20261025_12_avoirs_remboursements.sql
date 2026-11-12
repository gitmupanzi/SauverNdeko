-- Avoirs après retour facturé : aucune écriture de stock supplémentaire.
BEGIN;
SET LOCAL lock_timeout='10s'; SET LOCAL statement_timeout='120s';
CREATE TABLE logistique."T_Avoir" (
 "ID_Avoir" bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 "ID_FactureFk" bigint NOT NULL REFERENCES logistique."T_Facture"("ID_Facture") ON DELETE RESTRICT,
 "ID_CommandeFk" integer NOT NULL REFERENCES logistique."T_Commande"("ID_Commande") ON DELETE RESTRICT,
 "IdEntiteFk" integer NOT NULL REFERENCES systeme."T_Entite"("IdEntite") ON DELETE RESTRICT,
 "ID_UserFk" integer NOT NULL REFERENCES systeme."T_Utilisateurs"("IdUser") ON DELETE RESTRICT,
 "CodeAvoir" text NOT NULL UNIQUE,
 "DateAvoir" timestamptz NOT NULL,
 "Motif" text NOT NULL CHECK(length(btrim("Motif")) BETWEEN 3 AND 2000),
 "ID_DeviseFk" integer NOT NULL REFERENCES referentiel."T_Generique"("ID_Generique") ON DELETE RESTRICT,
 "DeviseCode" text NOT NULL,
 "MontantTTC" numeric(12,2) NOT NULL CHECK("MontantTTC">0),
 "RequestId" uuid NOT NULL,"PayloadHash" text NOT NULL CHECK("PayloadHash" ~ '^[a-f0-9]{64}$'),
 "TransactionCreation" bigint NOT NULL DEFAULT txid_current(),
 "CreeLe" timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE("ID_UserFk","RequestId")
);
CREATE TABLE logistique."T_AvoirLigne" (
 "ID_AvoirFk" bigint NOT NULL REFERENCES logistique."T_Avoir"("ID_Avoir") ON DELETE RESTRICT,
 "ID_ArticleFk" integer NOT NULL REFERENCES logistique."T_Article"("ID_Article") ON DELETE RESTRICT,
 "NomArticle" text NOT NULL,"Unite" text,
 "Quantite" numeric(14,3) NOT NULL CHECK("Quantite">0),
 "PUAvoir" numeric(12,2) NOT NULL CHECK("PUAvoir">=0),
 "MontantLigne" numeric(12,2) NOT NULL CHECK("MontantLigne"=round("Quantite"*"PUAvoir",2)),
 PRIMARY KEY("ID_AvoirFk","ID_ArticleFk")
);
CREATE TABLE logistique."T_AvoirAffectation" (
 "ID_Affectation" bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 "ID_AvoirFk" bigint NOT NULL REFERENCES logistique."T_Avoir"("ID_Avoir") ON DELETE RESTRICT,
 "ID_CommandeCibleFk" integer NOT NULL REFERENCES logistique."T_Commande"("ID_Commande") ON DELETE RESTRICT,
 "Montant" numeric(12,2) NOT NULL CHECK("Montant">0),
 "ID_UserFk" integer NOT NULL REFERENCES systeme."T_Utilisateurs"("IdUser") ON DELETE RESTRICT,
 "RequestId" uuid NOT NULL,"PayloadHash" text NOT NULL,
 "CreeLe" timestamptz NOT NULL DEFAULT clock_timestamp(), UNIQUE("ID_UserFk","RequestId")
);
CREATE TABLE logistique."T_Remboursement" (
 "ID_Remboursement" bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 "ID_AvoirFk" bigint NOT NULL REFERENCES logistique."T_Avoir"("ID_Avoir") ON DELETE RESTRICT,
 "Montant" numeric(12,2) NOT NULL CHECK("Montant">0),
 "DateRemboursement" timestamptz NOT NULL,
 "ID_ModePaiementFk" integer NOT NULL REFERENCES referentiel."T_Generique"("ID_Generique") ON DELETE RESTRICT,
 "ReferenceRemboursement" varchar(200),
 "ID_UserFk" integer NOT NULL REFERENCES systeme."T_Utilisateurs"("IdUser") ON DELETE RESTRICT,
 "RequestId" uuid NOT NULL,"PayloadHash" text NOT NULL,
 "CreeLe" timestamptz NOT NULL DEFAULT clock_timestamp(), UNIQUE("ID_UserFk","RequestId")
);
CREATE INDEX ix_avoir_facture ON logistique."T_Avoir"("ID_FactureFk");
CREATE INDEX ix_avoir_entite ON logistique."T_Avoir"("IdEntiteFk");
CREATE INDEX ix_affectation_cible ON logistique."T_AvoirAffectation"("ID_CommandeCibleFk");
CREATE INDEX ix_affectation_avoir ON logistique."T_AvoirAffectation"("ID_AvoirFk");
CREATE INDEX ix_remboursement_avoir ON logistique."T_Remboursement"("ID_AvoirFk");
CREATE FUNCTION logistique.tr_avoir_immuable() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $fn$
DECLARE f logistique."T_Facture";
BEGIN
 IF TG_OP<>'INSERT' THEN RAISE EXCEPTION 'Un avoir émis est conservé.' USING ERRCODE='23514'; END IF;
 SELECT * INTO f FROM logistique."T_Facture" WHERE "ID_Facture"=NEW."ID_FactureFk";
 IF NOT FOUND OR NEW."ID_CommandeFk"<>f."ID_CommandeFk" OR NEW."IdEntiteFk"<>f."IdEntiteFk" OR NEW."ID_DeviseFk"<>f."ID_DeviseFk" OR NEW."DeviseCode"<>f."DeviseCode" THEN RAISE EXCEPTION 'Avoir incompatible avec sa facture.' USING ERRCODE='23514'; END IF;
 PERFORM 1 FROM logistique."T_Commande" WHERE "ID_Commande"=f."ID_CommandeFk" FOR UPDATE;
 IF NEW."DateAvoir"<f."DateFacture" THEN RAISE EXCEPTION 'La date d’avoir précède la facture.' USING ERRCODE='23514'; END IF;
 NEW."CodeAvoir"='avr-'||NEW."ID_Avoir"::text;
 RETURN NEW;
END $fn$;
CREATE TRIGGER avoir_immuable BEFORE INSERT OR UPDATE OR DELETE ON logistique."T_Avoir" FOR EACH ROW EXECUTE FUNCTION logistique.tr_avoir_immuable();
CREATE FUNCTION logistique.tr_avoir_ligne_immuable() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $fn$
DECLARE a logistique."T_Avoir"; f logistique."T_FactureLigne"; available numeric; credited numeric;
BEGIN
 IF TG_OP<>'INSERT' THEN RAISE EXCEPTION 'Les lignes d’avoir sont conservées.' USING ERRCODE='23514'; END IF;
 SELECT * INTO a FROM logistique."T_Avoir" WHERE "ID_Avoir"=NEW."ID_AvoirFk";
 IF a."TransactionCreation"<>txid_current() THEN RAISE EXCEPTION 'Un avoir émis ne reçoit pas de nouvelle ligne.' USING ERRCODE='23514'; END IF;
 PERFORM 1 FROM logistique."T_Commande" WHERE "ID_Commande"=a."ID_CommandeFk" FOR UPDATE;
 SELECT * INTO f FROM logistique."T_FactureLigne" WHERE "ID_FactureFk"=a."ID_FactureFk" AND "ID_ArticleFk"=NEW."ID_ArticleFk";
 IF NOT FOUND OR NEW."PUAvoir"<>f."PUFacture" OR NEW."NomArticle"<>f."NomArticle" OR NEW."Unite" IS DISTINCT FROM f."Unite" THEN RAISE EXCEPTION 'La ligne d’avoir reprend l’instantané facturé.' USING ERRCODE='23514'; END IF;
 SELECT COALESCE(sum(d."QteCmdDetail"),0)-f."QteRetourAvantFacture" INTO available FROM logistique."T_RetourBon" r JOIN logistique."T_CommandeDetail" d ON d."ID_CmdFk"=r."ID_CommandeRetourFk" WHERE r."ID_CommandeOrigineFk"=a."ID_CommandeFk" AND d."ID_ArticleFk"=NEW."ID_ArticleFk";
 SELECT COALESCE(sum(l."Quantite"),0) INTO credited FROM logistique."T_AvoirLigne" l JOIN logistique."T_Avoir" n ON n."ID_Avoir"=l."ID_AvoirFk" WHERE n."ID_FactureFk"=a."ID_FactureFk" AND l."ID_ArticleFk"=NEW."ID_ArticleFk";
 IF NEW."Quantite"+credited>available OR NEW."Quantite"+credited>f."QteFacturee" THEN RAISE EXCEPTION 'Quantité retournée déjà créditée ou insuffisante.' USING ERRCODE='23514'; END IF;
 RETURN NEW;
END $fn$;
CREATE TRIGGER avoir_ligne_immuable BEFORE INSERT OR UPDATE OR DELETE ON logistique."T_AvoirLigne" FOR EACH ROW EXECUTE FUNCTION logistique.tr_avoir_ligne_immuable();
CREATE FUNCTION logistique.tr_avoir_total() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $fn$
DECLARE key_id bigint; total numeric; expected numeric;
BEGIN
 key_id=COALESCE((to_jsonb(NEW)->>'ID_Avoir')::bigint,(to_jsonb(NEW)->>'ID_AvoirFk')::bigint);
 SELECT "MontantTTC" INTO expected FROM logistique."T_Avoir" WHERE "ID_Avoir"=key_id;
 SELECT sum("MontantLigne") INTO total FROM logistique."T_AvoirLigne" WHERE "ID_AvoirFk"=key_id;
 IF total IS NULL OR total<>expected THEN RAISE EXCEPTION 'Le montant de l’avoir doit correspondre à ses lignes.' USING ERRCODE='23514'; END IF;
 RETURN NULL;
END $fn$;
CREATE CONSTRAINT TRIGGER avoir_total AFTER INSERT ON logistique."T_Avoir" DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION logistique.tr_avoir_total();
CREATE CONSTRAINT TRIGGER avoir_lignes_total AFTER INSERT ON logistique."T_AvoirLigne" DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION logistique.tr_avoir_total();
CREATE FUNCTION logistique.tr_utilisation_avoir() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $fn$
DECLARE a logistique."T_Avoir"; target logistique."T_Facture"; source_client bigint; target_client bigint; used numeric; due numeric; target_id integer;
BEGIN
 IF TG_OP<>'INSERT' THEN RAISE EXCEPTION 'L’historique des imputations et remboursements est conservé.' USING ERRCODE='23514'; END IF;
 SELECT * INTO a FROM logistique."T_Avoir" WHERE "ID_Avoir"=NEW."ID_AvoirFk";
 IF TG_TABLE_NAME='T_AvoirAffectation' THEN target_id=NEW."ID_CommandeCibleFk"; END IF;
 PERFORM 1 FROM logistique."T_Commande" WHERE "ID_Commande" IN (a."ID_CommandeFk",target_id) ORDER BY "ID_Commande" FOR UPDATE;
 SELECT * INTO a FROM logistique."T_Avoir" WHERE "ID_Avoir"=NEW."ID_AvoirFk" FOR UPDATE;
 SELECT COALESCE((SELECT sum("Montant") FROM logistique."T_AvoirAffectation" WHERE "ID_AvoirFk"=a."ID_Avoir"),0)+COALESCE((SELECT sum("Montant") FROM logistique."T_Remboursement" WHERE "ID_AvoirFk"=a."ID_Avoir"),0) INTO used;
 IF used+NEW."Montant">a."MontantTTC" THEN RAISE EXCEPTION 'Le disponible de l’avoir est insuffisant.' USING ERRCODE='23514'; END IF;
 IF target_id IS NOT NULL THEN
  SELECT * INTO target FROM logistique."T_Facture" WHERE "ID_CommandeFk"=target_id;
  IF NOT FOUND OR target."IdEntiteFk"<>a."IdEntiteFk" OR target."ID_DeviseFk"<>a."ID_DeviseFk" THEN RAISE EXCEPTION 'Facture cible d’entreprise ou devise différente.' USING ERRCODE='23514'; END IF;
  IF target_id<>a."ID_CommandeFk" THEN
   SELECT "ID_TiersFk" INTO source_client FROM logistique."T_Commande" WHERE "ID_Commande"=a."ID_CommandeFk";
   SELECT "ID_TiersFk" INTO target_client FROM logistique."T_Commande" WHERE "ID_Commande"=target_id;
   IF source_client IS NULL OR source_client IS DISTINCT FROM target_client THEN RAISE EXCEPTION 'L’imputation concerne le même tiers référencé.' USING ERRCODE='23514'; END IF;
  END IF;
  SELECT target."MontantTTC"-COALESCE((SELECT sum("MontantRegle") FROM logistique."T_Reglements" WHERE "CodeFactureFk"=target."CodeFacture"),0)-COALESCE((SELECT sum("Montant") FROM logistique."T_AvoirAffectation" WHERE "ID_CommandeCibleFk"=target_id),0) INTO due;
  IF NEW."Montant">due THEN RAISE EXCEPTION 'L’imputation dépasse le solde de la facture cible.' USING ERRCODE='23514'; END IF;
 ELSE
  PERFORM logistique.fn_assert_generique_category(NEW."ID_ModePaiementFk",36,'Remboursement','ID_ModePaiementFk');
  IF NOT EXISTS(SELECT 1 FROM referentiel."T_Generique" g JOIN referentiel."T_CategorieGenerique" c ON c."ID_CategorieGenerique"=g."ID_CategorieGeneriqueFk" WHERE g."ID_Generique"=NEW."ID_ModePaiementFk" AND g."ValideGenerique" IS TRUE AND c."ValideCategorieGenerique" IS TRUE) THEN RAISE EXCEPTION 'Mode de remboursement inactif.' USING ERRCODE='23514'; END IF;
  IF NEW."DateRemboursement"<a."DateAvoir" THEN RAISE EXCEPTION 'Le remboursement précède l’avoir.' USING ERRCODE='23514'; END IF;
 END IF;
 RETURN NEW;
END $fn$;
CREATE TRIGGER affectation_avoir_controle BEFORE INSERT OR UPDATE OR DELETE ON logistique."T_AvoirAffectation" FOR EACH ROW EXECUTE FUNCTION logistique.tr_utilisation_avoir();
CREATE TRIGGER remboursement_avoir_controle BEFORE INSERT OR UPDATE OR DELETE ON logistique."T_Remboursement" FOR EACH ROW EXECUTE FUNCTION logistique.tr_utilisation_avoir();
CREATE TRIGGER document_identite_avoir AFTER INSERT ON logistique."T_Avoir" FOR EACH ROW EXECUTE FUNCTION logistique.tr_document_identite();
CREATE VIEW logistique."V_Avoir" AS SELECT a.*,COALESCE(s.impute,0)::numeric(12,2) AS "MontantImpute",COALESCE(r.rembourse,0)::numeric(12,2) AS "MontantRembourse",(a."MontantTTC"-COALESCE(s.impute,0)-COALESCE(r.rembourse,0))::numeric(12,2) AS "Disponible" FROM logistique."T_Avoir" a LEFT JOIN LATERAL(SELECT sum("Montant") AS impute FROM logistique."T_AvoirAffectation" WHERE "ID_AvoirFk"=a."ID_Avoir") s ON true LEFT JOIN LATERAL(SELECT sum("Montant") AS rembourse FROM logistique."T_Remboursement" WHERE "ID_AvoirFk"=a."ID_Avoir") r ON true;


CREATE FUNCTION logistique.fn_montant_avoir_attente(command_id integer) RETURNS numeric LANGUAGE sql STABLE SET search_path=pg_catalog AS $fn$
 SELECT COALESCE(sum(round(greatest(COALESCE(r.qty,0)-l."QteRetourAvantFacture"-COALESCE(c.qty,0),0)*l."PUFacture",2)),0)::numeric(12,2)
 FROM logistique."T_Facture" f JOIN logistique."T_FactureLigne" l ON l."ID_FactureFk"=f."ID_Facture"
 LEFT JOIN LATERAL(SELECT sum(d."QteCmdDetail") AS qty FROM logistique."T_RetourBon" b JOIN logistique."T_CommandeDetail" d ON d."ID_CmdFk"=b."ID_CommandeRetourFk" WHERE b."ID_CommandeOrigineFk"=command_id AND d."ID_ArticleFk"=l."ID_ArticleFk") r ON true
 LEFT JOIN LATERAL(SELECT sum(al."Quantite") AS qty FROM logistique."T_Avoir" a JOIN logistique."T_AvoirLigne" al ON al."ID_AvoirFk"=a."ID_Avoir" WHERE a."ID_CommandeFk"=command_id AND al."ID_ArticleFk"=l."ID_ArticleFk") c ON true
 WHERE f."ID_CommandeFk"=command_id
$fn$;
CREATE FUNCTION logistique.tr_reglement_apres_avoir() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $fn$
DECLARE code text; command_id integer; invoice numeric; credit numeric; paid numeric;
BEGIN
 code=CASE WHEN TG_OP='DELETE' THEN OLD."CodeFactureFk" ELSE NEW."CodeFactureFk" END;
 SELECT "ID_Commande" INTO command_id FROM logistique."T_Commande" WHERE "CodeFacture"=code FOR UPDATE;
 IF TG_OP IN ('UPDATE','DELETE') AND (EXISTS(SELECT 1 FROM logistique."T_Avoir" WHERE "ID_CommandeFk"=command_id) OR EXISTS(SELECT 1 FROM logistique."T_AvoirAffectation" WHERE "ID_CommandeCibleFk"=command_id)) THEN RAISE EXCEPTION 'Un avoir existe : le règlement doit être conservé.' USING ERRCODE='23514'; END IF;
 IF TG_OP='INSERT' THEN
  SELECT "MontantTTC" INTO invoice FROM logistique."T_Facture" WHERE "ID_CommandeFk"=command_id;
  SELECT COALESCE(sum("Montant"),0) INTO credit FROM logistique."T_AvoirAffectation" WHERE "ID_CommandeCibleFk"=command_id;
  SELECT COALESCE(sum("MontantRegle"),0) INTO paid FROM logistique."T_Reglements" WHERE "CodeFactureFk"=code;
  IF invoice IS NOT NULL AND paid+NEW."MontantRegle">invoice-credit THEN RAISE EXCEPTION 'Le règlement dépasse le solde net des avoirs.' USING ERRCODE='23514'; END IF;
 END IF;
 RETURN CASE WHEN TG_OP='DELETE' THEN OLD ELSE NEW END;
END $fn$;
CREATE TRIGGER reglement_apres_avoir BEFORE INSERT OR UPDATE OR DELETE ON logistique."T_Reglements" FOR EACH ROW EXECUTE FUNCTION logistique.tr_reglement_apres_avoir();
CREATE FUNCTION logistique.tr_facture_apres_avoir() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $fn$
BEGIN
 IF EXISTS(SELECT 1 FROM logistique."T_Avoir" WHERE "ID_FactureFk"=OLD."ID_Facture") OR EXISTS(SELECT 1 FROM logistique."T_AvoirAffectation" WHERE "ID_CommandeCibleFk"=OLD."ID_CommandeFk") THEN RAISE EXCEPTION 'Un avoir existe : la facture d’origine est conservée.' USING ERRCODE='23514'; END IF;
 RETURN CASE WHEN TG_OP='DELETE' THEN OLD ELSE NEW END;
END $fn$;
CREATE TRIGGER facture_apres_avoir BEFORE UPDATE OR DELETE ON logistique."T_Facture" FOR EACH ROW EXECUTE FUNCTION logistique.tr_facture_apres_avoir();

-- La facture est la source unique du solde net ; les vues aval le reprennent.
DO $invoice_balance$ DECLARE definition text; fields text; BEGIN
 definition=regexp_replace(pg_get_viewdef('logistique."V_Facture"'::regclass,true),';[[:space:]]*$','');
 SELECT string_agg(CASE
 WHEN attname='Reste' THEN format('(b."Reste"-COALESCE(cr.total,0))::%s AS "Reste"',format_type(atttypid,atttypmod))
 WHEN attname='EtatReglement' THEN 'CASE WHEN b."Reste"-COALESCE(cr.total,0)<=0 THEN ''Réglée'' WHEN b."TotalRegle">0 OR COALESCE(cr.total,0)>0 THEN ''Partiellement réglée'' ELSE ''Non réglée'' END AS "EtatReglement"'
 WHEN attname='EstEnRetard' THEN '(b."EstEnRetard" AND b."Reste"-COALESCE(cr.total,0)>0) AS "EstEnRetard"'
 WHEN attname='MontantAvoirAEtablir' THEN 'logistique.fn_montant_avoir_attente(b."ID_CommandeFk")::numeric(12,2) AS "MontantAvoirAEtablir"'
 WHEN attname='AvoirAEtablir' THEN '(logistique.fn_montant_avoir_attente(b."ID_CommandeFk")>0) AS "AvoirAEtablir"'
 ELSE format('b.%I',attname) END,',' ORDER BY attnum) INTO fields FROM pg_attribute WHERE attrelid='logistique."V_Facture"'::regclass AND attnum>0 AND NOT attisdropped;
 EXECUTE 'CREATE OR REPLACE VIEW logistique."V_Facture" AS SELECT '||fields||',COALESCE(cr.total,0)::numeric(12,2) AS "AvoirImpute",(b."MontantTTC"-COALESCE(cr.total,0))::numeric(12,2) AS "MontantNetARegler" FROM ('||definition||') b LEFT JOIN LATERAL(SELECT sum("Montant") AS total FROM logistique."T_AvoirAffectation" WHERE "ID_CommandeCibleFk"=b."ID_CommandeFk") cr ON true';
END $invoice_balance$;
COMMENT ON COLUMN logistique."V_Facture"."Reste" IS 'Solde unique de référence : montant émis diminué des encaissements et des avoirs imputés.';
COMMENT ON COLUMN logistique."V_Facture"."AvoirImpute" IS 'Imputations d’avoirs distinctes des encaissements.';
COMMENT ON COLUMN logistique."V_Facture"."MontantNetARegler" IS 'Montant émis diminué des imputations avant encaissements.';

-- Reste et état du bon reflètent les imputations, sans confondre avoir et encaissement.
DO $order_balance$ DECLARE definition text; fields text; BEGIN
 definition=regexp_replace(pg_get_viewdef('logistique."V_Commande"'::regclass,true),';[[:space:]]*$','');
 SELECT string_agg(CASE
 WHEN attname='MontantAvoirAEtablir' THEN 'pending.amount::numeric(12,2) AS "MontantAvoirAEtablir"'
 WHEN attname='AvoirAEtablir' THEN '(pending.amount>0) AS "AvoirAEtablir"'
 ELSE format('b.%I',attname) END,',' ORDER BY attnum) INTO fields FROM pg_attribute WHERE attrelid='logistique."V_Commande"'::regclass AND attnum>0 AND NOT attisdropped;
 EXECUTE 'CREATE OR REPLACE VIEW logistique."V_Commande" AS SELECT '||fields||',COALESCE(cr.total,0)::numeric(12,2) AS "AvoirImpute" FROM ('||definition||') b LEFT JOIN LATERAL(SELECT sum("Montant") AS total FROM logistique."T_AvoirAffectation" WHERE "ID_CommandeCibleFk"=b."ID_Commande") cr ON true LEFT JOIN LATERAL(SELECT logistique.fn_montant_avoir_attente(b."ID_Commande") AS amount) pending ON true';
END $order_balance$;
COMMENT ON FUNCTION logistique.fn_montant_avoir_attente(integer) IS 'Montant exact des retours après facture qui ne sont pas encore couverts par un avoir émis.';
COMMENT ON FUNCTION logistique.tr_reglement_apres_avoir() IS 'Protège les règlements déjà liés à un avoir et borne les nouveaux paiements au solde net.';
COMMENT ON FUNCTION logistique.tr_facture_apres_avoir() IS 'Conserve l’identité et les dates de la facture après émission d’un avoir.';
COMMENT ON TRIGGER reglement_apres_avoir ON logistique."T_Reglements" IS 'Contrôle financier des règlements après émission ou imputation d’un avoir.';
COMMENT ON TRIGGER facture_apres_avoir ON logistique."T_Facture" IS 'Protection de la facture d’origine des avoirs.';
COMMENT ON COLUMN logistique."V_Commande"."AvoirImpute" IS 'Imputations d’avoirs au bon facturé, distinctes des encaissements.';

DO $balances$ DECLARE definition text; fields text; BEGIN
 definition=pg_get_viewdef('logistique."V_SuiviReglements"'::regclass,true); definition=regexp_replace(definition,';[[:space:]]*$','');
 SELECT string_agg(CASE
 WHEN attname='MontantAvoirAEtablir' THEN 'logistique.fn_montant_avoir_attente(b."ID_Commande")::numeric(12,2) AS "MontantAvoirAEtablir"'
 WHEN attname='AvoirAEtablir' THEN '(logistique.fn_montant_avoir_attente(b."ID_Commande")>0) AS "AvoirAEtablir"'
 ELSE format('b.%I',attname) END,',' ORDER BY attnum) INTO fields FROM pg_attribute WHERE attrelid='logistique."V_SuiviReglements"'::regclass AND attnum>0 AND NOT attisdropped;
 EXECUTE 'CREATE OR REPLACE VIEW logistique."V_SuiviReglements" AS SELECT '||fields||',COALESCE(cr.total,0)::numeric(12,2) AS "AvoirImpute",(b."MontantFacture"-COALESCE(cr.total,0))::numeric(12,2) AS "MontantNetARegler" FROM ('||definition||') b LEFT JOIN LATERAL(SELECT sum("Montant") AS total FROM logistique."T_AvoirAffectation" WHERE "ID_CommandeCibleFk"=b."ID_Commande") cr ON true';
END $balances$;
COMMENT ON TABLE logistique."T_Avoir" IS 'Avoir immuable correspondant aux retours postérieurs à une facture émise ; sans effet de stock supplémentaire.';
COMMENT ON TABLE logistique."T_AvoirLigne" IS 'Quantités retournées après facturation, au prix de l’instantané original, créditées une seule fois.';
COMMENT ON TABLE logistique."T_AvoirAffectation" IS 'Imputation immuable d’un avoir sur un solde de facture de même entreprise, devise et tiers.';
COMMENT ON TABLE logistique."T_Remboursement" IS 'Remboursement effectivement enregistré contre le disponible d’un avoir ; aucun transfert bancaire automatique.';
COMMENT ON VIEW logistique."V_Avoir" IS 'Disponible exact de chaque avoir après imputations et remboursements.';
COMMENT ON COLUMN logistique."V_SuiviReglements"."AvoirImpute" IS 'Total des avoirs imputés à la facture, dans sa devise.';
COMMENT ON COLUMN logistique."V_SuiviReglements"."MontantNetARegler" IS 'Montant facturé diminué des imputations d’avoirs, avant déduction des règlements.';
COMMENT ON COLUMN logistique."V_SuiviReglements"."Reste" IS 'Montant de la facture diminué des règlements et des avoirs imputés.';
COMMENT ON COLUMN logistique."V_Commande"."AvoirAEtablir" IS 'Vrai si des retours postérieurs à la facture ne sont pas encore couverts par un avoir.';
COMMENT ON FUNCTION logistique.tr_avoir_immuable() IS 'Valide entreprise, devise et facture, attribue avr-ID et conserve l’avoir émis.';
COMMENT ON FUNCTION logistique.tr_avoir_ligne_immuable() IS 'Empêche la double créditation des retours après facturation et conserve le prix facturé.';
COMMENT ON FUNCTION logistique.tr_avoir_total() IS 'Vérifie au commit que les lignes couvrent exactement le montant émis.';
COMMENT ON FUNCTION logistique.tr_utilisation_avoir() IS 'Sérialise l’utilisation des avoirs, vérifie disponible, solde cible, tiers, devise et mode de remboursement.';
COMMENT ON TRIGGER avoir_immuable ON logistique."T_Avoir" IS 'Avoir émis non modifiable ni supprimable.';
COMMENT ON TRIGGER avoir_ligne_immuable ON logistique."T_AvoirLigne" IS 'Instantané des articles et budget retourné.';
COMMENT ON TRIGGER avoir_total ON logistique."T_Avoir" IS 'Contrôle différé de la somme émise.';
COMMENT ON TRIGGER avoir_lignes_total ON logistique."T_AvoirLigne" IS 'Contrôle différé de la somme des lignes d’avoir.';
COMMENT ON TRIGGER affectation_avoir_controle ON logistique."T_AvoirAffectation" IS 'Imputation bornée au disponible et au solde de la facture cible.';
COMMENT ON TRIGGER remboursement_avoir_controle ON logistique."T_Remboursement" IS 'Remboursement borné au disponible de l’avoir.';
COMMENT ON TRIGGER document_identite_avoir ON logistique."T_Avoir" IS 'Identité de l’émetteur figée lors de l’émission.';
DO $comments$ DECLARE r record; description text; BEGIN
 FOR r IN SELECT c.relname,a.attname FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace JOIN pg_attribute a ON a.attrelid=c.oid AND a.attnum>0 AND NOT a.attisdropped WHERE n.nspname='logistique' AND c.relname IN ('T_Avoir','T_AvoirLigne','T_AvoirAffectation','T_Remboursement','V_Avoir') LOOP
 description=CASE r.attname
 WHEN 'ID_Avoir' THEN 'Identifiant interne et stable de l’avoir émis.' WHEN 'ID_AvoirFk' THEN 'Avoir émis dont dépend cette ligne, imputation ou remboursement.'
 WHEN 'ID_FactureFk' THEN 'Facture originale et immuable à laquelle se rapporte l’avoir.' WHEN 'ID_CommandeFk' THEN 'Bon original facturé dont les articles ont été retournés.'
 WHEN 'IdEntiteFk' THEN 'Entreprise propriétaire durable de l’avoir et de sa facture.' WHEN 'ID_UserFk' THEN 'Auteur réel de l’émission, imputation ou remboursement.'
 WHEN 'NomArticle' THEN 'Désignation figée sur la facture d’origine.' WHEN 'Unite' THEN 'Unité figée sur la facture d’origine.'
 WHEN 'Quantite' THEN 'Quantité retournée après émission, non encore créditée, dans l’unité facturée.' WHEN 'PUAvoir' THEN 'Prix unitaire figé de la facture d’origine.'
 WHEN 'Disponible' THEN 'Montant émis non encore imputé ni remboursé.' WHEN 'MontantImpute' THEN 'Cumul des imputations sur des factures autorisées.' WHEN 'MontantRembourse' THEN 'Cumul des remboursements effectivement enregistrés.'
 WHEN 'TransactionCreation' THEN 'Transaction autorisée à insérer les lignes du nouvel avoir.' WHEN 'RequestId' THEN 'Identifiant unique du traitement empêchant les doubles envois.'
 WHEN 'PayloadHash' THEN 'Empreinte canonique à comparer lors du rejeu d’une demande.' WHEN 'CodeAvoir' THEN 'Référence automatique et immuable avr-identifiant.'
 WHEN 'Montant' THEN 'Montant positif dans la devise de l’avoir.' WHEN 'MontantTTC' THEN 'Montant émis égal à la somme des lignes.'
 WHEN 'MontantLigne' THEN 'Quantité au prix facturé, arrondie à deux décimales.' WHEN 'ID_CommandeCibleFk' THEN 'Bon dont la facture reçoit une imputation, sans effet de stock.'
 WHEN 'ID_ArticleFk' THEN 'Article de la ligne facturée à l’origine.' WHEN 'ID_DeviseFk' THEN 'Devise de la facture d’origine, issue du référentiel.' WHEN 'DeviseCode' THEN 'Code de la devise de la facture, conservé à l’émission.'
 WHEN 'Motif' THEN 'Justification métier de l’avoir après retour facturé.' WHEN 'DateAvoir' THEN 'Date et heure effectives de l’émission de l’avoir.' WHEN 'CreeLe' THEN 'Horodatage serveur de l’enregistrement.'
 WHEN 'DateRemboursement' THEN 'Date et heure du montant effectivement restitué au client.' WHEN 'ReferenceRemboursement' THEN 'Référence de caisse, banque ou autre preuve du paiement restitué.' WHEN 'ID_ModePaiementFk' THEN 'Mode de remboursement actif issu du référentiel partagé.'
 WHEN 'ID_Affectation' THEN 'Identifiant stable de l’imputation.' WHEN 'ID_Remboursement' THEN 'Identifiant stable de la preuve de remboursement.' ELSE 'Identifiant et donnée de gestion de l’avoir.' END;
 EXECUTE format('COMMENT ON COLUMN logistique.%I.%I IS %L',r.relname,r.attname,description);
 END LOOP;
END $comments$;
COMMIT;
