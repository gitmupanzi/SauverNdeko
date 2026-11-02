-- Paramètres par entreprise et TVA figée à l’émission des factures.
-- Les prix unitaires du bon forment la base HT ; aucune réécriture des documents émis.
BEGIN;
SET LOCAL lock_timeout='10s';
SET LOCAL statement_timeout='120s';
ALTER TABLE systeme."T_Entite" ADD COLUMN "TauxTVAEntite" numeric(7,4) NOT NULL DEFAULT 0,
  ADD CONSTRAINT ck_entite_taux_tva CHECK ("TauxTVAEntite" BETWEEN 0 AND 100);
COMMENT ON COLUMN systeme."T_Entite"."TauxTVAEntite" IS 'Taux de TVA en pourcentage proposé aux nouvelles factures de cette entreprise, de 0 à 100 avec quatre décimales maximum ; défaut 0, sans réécriture des factures émises.';
COMMENT ON CONSTRAINT ck_entite_taux_tva ON systeme."T_Entite" IS 'Le taux paramétrable de l’entreprise reste compris entre 0 et 100 pour cent ; aucune valeur réglementaire n’est déduite.';
ALTER TABLE logistique."T_Facture" ADD COLUMN "TauxTVA" numeric(7,4) NOT NULL DEFAULT 0,
 ADD COLUMN "MontantTVA" numeric(12,2) NOT NULL DEFAULT 0,
 DROP CONSTRAINT "T_Facture_check",
 ADD CONSTRAINT ck_facture_taux_tva CHECK ("TauxTVA" BETWEEN 0 AND 100),
 ADD CONSTRAINT ck_facture_tva CHECK ("MontantTVA">=0 AND "MontantTTC"="MontantHT"+"MontantTVA");
ALTER TABLE logistique."T_FactureLigne" ADD COLUMN "MontantTVA" numeric(12,2) NOT NULL DEFAULT 0,
 ADD COLUMN "MontantTTC" numeric(12,2) GENERATED ALWAYS AS ("MontantLigne"+"MontantTVA") STORED,
 ADD CONSTRAINT ck_facture_ligne_tva CHECK ("MontantTVA">=0);
ALTER TABLE logistique."T_Avoir" ADD COLUMN "TauxTVA" numeric(7,4) NOT NULL DEFAULT 0,
 ADD COLUMN "MontantTVA" numeric(12,2) NOT NULL DEFAULT 0,
 ADD COLUMN "MontantHT" numeric(12,2) GENERATED ALWAYS AS ("MontantTTC"-"MontantTVA") STORED,
 ADD CONSTRAINT ck_avoir_taux_tva CHECK ("TauxTVA" BETWEEN 0 AND 100),
 ADD CONSTRAINT ck_avoir_tva CHECK ("MontantTVA">=0 AND "MontantTTC">="MontantTVA");
ALTER TABLE logistique."T_AvoirLigne" ADD COLUMN "MontantTVA" numeric(12,2) NOT NULL DEFAULT 0,
 ADD COLUMN "MontantTTC" numeric(12,2) GENERATED ALWAYS AS ("MontantLigne"+"MontantTVA") STORED,
 DROP CONSTRAINT "T_AvoirLigne_check",
 ADD CONSTRAINT ck_avoir_ligne_tva CHECK ("MontantTVA">=0 AND "MontantLigne">=0);
COMMENT ON COLUMN logistique."T_Facture"."TauxTVA" IS 'Taux de TVA de l’entreprise copié et figé à l’émission ; zéro pour les factures antérieures à ce paramétrage.';
COMMENT ON COLUMN logistique."T_Facture"."MontantTVA" IS 'Somme des TVA de lignes arrondies à deux décimales lors de l’émission, immuable ensuite.';
COMMENT ON COLUMN logistique."T_Facture"."MontantHT" IS 'Somme des montants HT arrondis des lignes facturées nettes des retours antérieurs à l’émission.';
COMMENT ON COLUMN logistique."T_Facture"."MontantTTC" IS 'Montant émis égal au HT plus la TVA figée ; base des soldes et règlements.';
COMMENT ON COLUMN logistique."T_FactureLigne"."MontantLigne" IS 'Montant HT de la ligne, quantité facturée multipliée par le prix unitaire HT et arrondie à deux décimales.';
COMMENT ON COLUMN logistique."T_FactureLigne"."MontantTVA" IS 'TVA arrondie de cette ligne au taux figé de sa facture ; conservée pour les restitutions.';
COMMENT ON COLUMN logistique."T_FactureLigne"."MontantTTC" IS 'Somme stockée et calculée du montant HT de ligne et de sa TVA.';
COMMENT ON COLUMN logistique."T_Avoir"."TauxTVA" IS 'Taux figé de la facture d’origine, jamais le taux courant de l’entreprise à la date du retour.';
COMMENT ON COLUMN logistique."T_Avoir"."MontantTVA" IS 'TVA effectivement créditée selon les quantités retournées et les arrondis cumulés de la facture originale.';
COMMENT ON COLUMN logistique."T_Avoir"."MontantHT" IS 'Base HT calculée du montant TTC de l’avoir moins la TVA créditée ; conserve le montant historique lorsque la TVA vaut zéro.';
COMMENT ON COLUMN logistique."T_AvoirLigne"."MontantLigne" IS 'Base HT créditée par différence des arrondis cumulés ; la dernière restitution reprend exactement le reliquat de la ligne facturée.';
COMMENT ON COLUMN logistique."T_AvoirLigne"."MontantTVA" IS 'Fraction de TVA créditée, calculée sur la TVA figée de la ligne et plafonnée au reliquat après les avoirs antérieurs.';
COMMENT ON COLUMN logistique."T_AvoirLigne"."MontantTTC" IS 'Total TTC calculé de la ligne d’avoir, base HT plus TVA restituée.';
COMMENT ON CONSTRAINT ck_facture_taux_tva ON logistique."T_Facture" IS 'Bornes du taux historique de la facture, en pourcentage.';
COMMENT ON CONSTRAINT ck_facture_tva ON logistique."T_Facture" IS 'Total TTC cohérent avec sa base HT et sa taxe non négative ; le trigger différé vérifie les sommes de lignes.';
COMMENT ON CONSTRAINT ck_facture_ligne_tva ON logistique."T_FactureLigne" IS 'La taxe facturée d’une ligne ne peut être négative.';
COMMENT ON CONSTRAINT ck_avoir_taux_tva ON logistique."T_Avoir" IS 'Bornes du taux repris de la facture d’origine.';
COMMENT ON CONSTRAINT ck_avoir_tva ON logistique."T_Avoir" IS 'TVA et base HT d’avoir non négatives ; contrôle différé des sommes exactes de lignes.';
COMMENT ON CONSTRAINT ck_avoir_ligne_tva ON logistique."T_AvoirLigne" IS 'Bases et taxes de restitution non négatives, calculées par la garde des lignes à partir de l’instantané et des avoirs antérieurs.';

CREATE FUNCTION logistique.fn_facturation_tva(p_commande integer)
RETURNS TABLE("TauxTVA" numeric,"MontantHT" numeric,"MontantTVA" numeric,"MontantTTC" numeric)
LANGUAGE sql STABLE SET search_path=pg_catalog AS $$
 WITH returned AS (
  SELECT d."ID_ArticleFk",sum(d."QteCmdDetail") quantite
  FROM logistique."T_RetourBon" r JOIN logistique."T_CommandeDetail" d ON d."ID_CmdFk"=r."ID_CommandeRetourFk"
  WHERE r."ID_CommandeOrigineFk"=p_commande GROUP BY d."ID_ArticleFk"
 ), base AS (
  SELECT round((d."QteCmdDetail"-coalesce(r.quantite,0))*d."PUCmdDetail",2) ht
  FROM logistique."T_CommandeDetail" d LEFT JOIN returned r ON r."ID_ArticleFk"=d."ID_ArticleFk"
  WHERE d."ID_CmdFk"=p_commande AND d."QteCmdDetail">coalesce(r.quantite,0)
 )
 SELECT e."TauxTVAEntite",coalesce(sum(b.ht),0)::numeric(12,2),
  coalesce(sum(round(b.ht*e."TauxTVAEntite"/100,2)),0)::numeric(12,2),
  (coalesce(sum(b.ht),0)+coalesce(sum(round(b.ht*e."TauxTVAEntite"/100,2)),0))::numeric(12,2)
 FROM logistique."T_Commande" c JOIN systeme."T_Entite" e ON e."IdEntite"=c."IdEntiteFk"
 LEFT JOIN base b ON true WHERE c."ID_Commande"=p_commande GROUP BY e."TauxTVAEntite";
$$;
COMMENT ON FUNCTION logistique.fn_facturation_tva(integer) IS 'Prévisualisation des nouvelles factures : base nette HT des lignes du bon, taux courant de son propriétaire durable, taxe arrondie par ligne puis sommes ; ne modifie aucun stock ni document émis.';

CREATE FUNCTION logistique.tr_initialiser_tva_facture() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE totals record; owner_id integer;
BEGIN
 SELECT "IdEntiteFk" INTO owner_id FROM logistique."T_Commande" WHERE "ID_Commande"=NEW."ID_CommandeFk" FOR UPDATE;
 PERFORM 1 FROM systeme."T_Entite" WHERE "IdEntite"=owner_id FOR SHARE;
 SELECT * INTO totals FROM logistique.fn_facturation_tva(NEW."ID_CommandeFk");
 IF NOT FOUND OR totals."MontantHT"<=0 THEN RAISE EXCEPTION 'Aucune base hors taxes positive à facturer.' USING ERRCODE='23514';END IF;
 NEW."TauxTVA"=totals."TauxTVA"; NEW."MontantHT"=totals."MontantHT";
 NEW."MontantTVA"=totals."MontantTVA"; NEW."MontantTTC"=totals."MontantTTC";
 RETURN NEW;
END $$;
COMMENT ON FUNCTION logistique.tr_initialiser_tva_facture() IS 'Capture atomiquement le taux de l’entreprise et les montants HT/TVA/TTC de la nouvelle facture ; conserve les anciens documents et ne touche jamais aux totaux physiques du bon.';
CREATE TRIGGER ab_initialiser_tva_facture BEFORE INSERT ON logistique."T_Facture" FOR EACH ROW EXECUTE FUNCTION logistique.tr_initialiser_tva_facture();
COMMENT ON TRIGGER ab_initialiser_tva_facture ON logistique."T_Facture" IS 'Avant émission, verrouille l’entreprise et calcule le snapshot fiscal depuis les lignes autorisées du bon.';
CREATE FUNCTION logistique.tr_initialiser_tva_facture_ligne() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE taux numeric;
BEGIN
 SELECT "TauxTVA" INTO taux FROM logistique."T_Facture" WHERE "ID_Facture"=NEW."ID_FactureFk";
 NEW."MontantTVA"=round(NEW."MontantLigne"*taux/100,2);
 RETURN NEW;
END $$;
COMMENT ON FUNCTION logistique.tr_initialiser_tva_facture_ligne() IS 'Calcule une seule fois la TVA arrondie de ligne selon le taux immuable de la facture ; le TTC est une colonne calculée.';
CREATE TRIGGER ab_initialiser_tva_facture_ligne BEFORE INSERT ON logistique."T_FactureLigne" FOR EACH ROW EXECUTE FUNCTION logistique.tr_initialiser_tva_facture_ligne();
COMMENT ON TRIGGER ab_initialiser_tva_facture_ligne ON logistique."T_FactureLigne" IS 'Génère la taxe de ligne avant le contrôle de l’instantané et des totaux différés.';

CREATE OR REPLACE FUNCTION logistique.tr_verifier_snapshot_facture()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog'
AS $function$

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

  IF total IS DISTINCT FROM invoice."MontantHT" OR (SELECT sum("MontantTVA") FROM logistique."T_FactureLigne" WHERE "ID_FactureFk"=invoice."ID_Facture") IS DISTINCT FROM invoice."MontantTVA" OR invoice."MontantTTC" IS DISTINCT FROM invoice."MontantHT"+invoice."MontantTVA" THEN RAISE EXCEPTION 'Total de facture différent de ses lignes.' USING ERRCODE='23514'; END IF;

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

END $function$
;

COMMENT ON FUNCTION logistique.tr_verifier_snapshot_facture() IS 'Contrôle différé du miroir documentaire, des lignes nettes de retours et des sommes exactes HT/TVA/TTC ; n’assimile pas la taxe à un second mouvement de stock.';

CREATE OR REPLACE FUNCTION logistique.tr_avoir_immuable()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog'
AS $function$
DECLARE f logistique."T_Facture";
BEGIN
 IF TG_OP<>'INSERT' THEN RAISE EXCEPTION 'Un avoir émis est conservé.' USING ERRCODE='23514'; END IF;
 SELECT * INTO f FROM logistique."T_Facture" WHERE "ID_Facture"=NEW."ID_FactureFk";
 IF NOT FOUND OR NEW."ID_CommandeFk"<>f."ID_CommandeFk" OR NEW."IdEntiteFk"<>f."IdEntiteFk" OR NEW."ID_DeviseFk"<>f."ID_DeviseFk" OR NEW."DeviseCode"<>f."DeviseCode" THEN RAISE EXCEPTION 'Avoir incompatible avec sa facture.' USING ERRCODE='23514'; END IF;
 PERFORM 1 FROM logistique."T_Commande" WHERE "ID_Commande"=f."ID_CommandeFk" FOR UPDATE;
 IF NEW."DateAvoir"<f."DateFacture" THEN RAISE EXCEPTION 'La date d’avoir précède la facture.' USING ERRCODE='23514'; END IF;
 NEW."TauxTVA"=f."TauxTVA";
 NEW."CodeAvoir"='avr-'||NEW."ID_Avoir"::text;
 RETURN NEW;
END $function$
;

COMMENT ON FUNCTION logistique.tr_avoir_immuable() IS 'Conserve les avoirs émis, verrouille leur bon original et reprend sa facture, sa devise et son taux historique de TVA, sans utiliser le paramétrage courant.';

CREATE OR REPLACE FUNCTION logistique.tr_avoir_ligne_immuable()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog'
AS $function$
DECLARE a logistique."T_Avoir"; f logistique."T_FactureLigne"; available numeric; credited numeric; credited_ht numeric; credited_tva numeric;
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
 SELECT coalesce(sum(l."MontantLigne"),0),coalesce(sum(l."MontantTVA"),0) INTO credited_ht,credited_tva
 FROM logistique."T_AvoirLigne" l JOIN logistique."T_Avoir" n ON n."ID_Avoir"=l."ID_AvoirFk"
 WHERE n."ID_FactureFk"=a."ID_FactureFk" AND l."ID_ArticleFk"=NEW."ID_ArticleFk";
 NEW."MontantLigne"=CASE WHEN credited+NEW."Quantite"=f."QteFacturee" THEN f."MontantLigne"
   ELSE round((credited+NEW."Quantite")*f."PUFacture",2) END-credited_ht;
 NEW."MontantTVA"=round(f."MontantTVA"*(credited+NEW."Quantite")/f."QteFacturee",2)-credited_tva;
 IF NEW."MontantLigne"<0 OR NEW."MontantTVA"<0 THEN RAISE EXCEPTION 'Les montants déjà crédités doivent être vérifiés.' USING ERRCODE='23514';END IF;
 RETURN NEW;
END $function$
;

COMMENT ON FUNCTION logistique.tr_avoir_ligne_immuable() IS 'Contrôle les quantités réellement retournées et non déjà créditées ; calcule le HT et la TVA par différence des arrondis cumulés, pour restituer exactement le reliquat de chaque ligne facturée.';

CREATE OR REPLACE FUNCTION logistique.tr_avoir_total() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE key_id bigint; a logistique."T_Avoir"; ht numeric; tva numeric; ttc numeric;
BEGIN
 key_id=coalesce((to_jsonb(NEW)->>'ID_Avoir')::bigint,(to_jsonb(NEW)->>'ID_AvoirFk')::bigint);
 SELECT * INTO a FROM logistique."T_Avoir" WHERE "ID_Avoir"=key_id;
 SELECT sum("MontantLigne"),sum("MontantTVA"),sum("MontantTTC") INTO ht,tva,ttc FROM logistique."T_AvoirLigne" WHERE "ID_AvoirFk"=key_id;
 IF ht IS DISTINCT FROM a."MontantHT" OR tva IS DISTINCT FROM a."MontantTVA" OR ttc IS DISTINCT FROM a."MontantTTC" THEN
  RAISE EXCEPTION 'Le montant HT, la TVA et le TTC de l’avoir doivent correspondre à ses lignes.' USING ERRCODE='23514';END IF;
 RETURN NULL;
END $$;
COMMENT ON FUNCTION logistique.tr_avoir_total() IS 'Contrôle différé des sommes HT, TVA historique et TTC des lignes d’avoir, sans effet supplémentaire sur le stock.';

CREATE FUNCTION logistique.fn_lignes_avoir_attente(p_commande integer)
RETURNS TABLE("ID_ArticleFk" integer,"NomArticle" text,"Unite" text,"Quantite" numeric,"PUAvoir" numeric,"MontantLigne" numeric,"MontantTVA" numeric,"MontantTTC" numeric)
LANGUAGE sql STABLE SET search_path=pg_catalog AS $$
 WITH source AS (
  SELECT l.*,greatest(coalesce(r.qty,0)-l."QteRetourAvantFacture"-coalesce(c.qty,0),0) pending,
    coalesce(c.qty,0) credited,coalesce(c.ht,0) credited_ht,coalesce(c.tva,0) credited_tva
  FROM logistique."T_Facture" f JOIN logistique."T_FactureLigne" l ON l."ID_FactureFk"=f."ID_Facture"
  LEFT JOIN LATERAL(SELECT sum(d."QteCmdDetail") qty FROM logistique."T_RetourBon" b JOIN logistique."T_CommandeDetail" d ON d."ID_CmdFk"=b."ID_CommandeRetourFk" WHERE b."ID_CommandeOrigineFk"=p_commande AND d."ID_ArticleFk"=l."ID_ArticleFk") r ON true
  LEFT JOIN LATERAL(SELECT sum(al."Quantite") qty,sum(al."MontantLigne") ht,sum(al."MontantTVA") tva FROM logistique."T_Avoir" a JOIN logistique."T_AvoirLigne" al ON al."ID_AvoirFk"=a."ID_Avoir" WHERE a."ID_CommandeFk"=p_commande AND al."ID_ArticleFk"=l."ID_ArticleFk") c ON true
  WHERE f."ID_CommandeFk"=p_commande
 ), amounts AS (
  SELECT s.*,CASE WHEN credited+pending="QteFacturee" THEN "MontantLigne" ELSE round((credited+pending)*"PUFacture",2) END-credited_ht ht,
   round("MontantTVA"*(credited+pending)/"QteFacturee",2)-credited_tva tva FROM source s WHERE pending>0
 )
 SELECT "ID_ArticleFk","NomArticle","Unite",pending,"PUFacture",ht::numeric(12,2),tva::numeric(12,2),(ht+tva)::numeric(12,2)
 FROM amounts ORDER BY "ID_ArticleFk";
$$;
COMMENT ON FUNCTION logistique.fn_lignes_avoir_attente(integer) IS 'Projection unique des retours facturés non crédités : quantité, base HT et TVA calculées sur le reliquat de l’instantané d’origine, avec arrondis cumulés sans surremboursement.';
CREATE OR REPLACE FUNCTION logistique.fn_montant_avoir_attente(command_id integer) RETURNS numeric
LANGUAGE sql STABLE SET search_path=pg_catalog AS $$
 SELECT coalesce(sum("MontantTTC"),0)::numeric(12,2) FROM logistique.fn_lignes_avoir_attente(command_id);
$$;
COMMENT ON FUNCTION logistique.fn_montant_avoir_attente(integer) IS 'Montant TTC exact des retours postérieurs à facture non couverts par des avoirs, incluant leur TVA historique et les reliquats d’arrondi.';

CREATE OR REPLACE VIEW logistique."V_Avoir" AS SELECT v.*,a."TauxTVA",a."MontantHT",a."MontantTVA" FROM (
 SELECT a."ID_Avoir",
    a."ID_FactureFk",
    a."ID_CommandeFk",
    a."IdEntiteFk",
    a."ID_UserFk",
    a."CodeAvoir",
    a."DateAvoir",
    a."Motif",
    a."ID_DeviseFk",
    a."DeviseCode",
    a."MontantTTC",
    a."RequestId",
    a."PayloadHash",
    a."TransactionCreation",
    a."CreeLe",
    COALESCE(s.impute, 0::numeric)::numeric(12,2) AS "MontantImpute",
    COALESCE(r.rembourse, 0::numeric)::numeric(12,2) AS "MontantRembourse",
    (a."MontantTTC" - COALESCE(s.impute, 0::numeric) - COALESCE(r.rembourse, 0::numeric))::numeric(12,2) AS "Disponible"
   FROM logistique."T_Avoir" a
     LEFT JOIN LATERAL ( SELECT sum("T_AvoirAffectation"."Montant") AS impute
           FROM logistique."T_AvoirAffectation"
          WHERE "T_AvoirAffectation"."ID_AvoirFk" = a."ID_Avoir") s ON true
     LEFT JOIN LATERAL ( SELECT sum("T_Remboursement"."Montant") AS rembourse
           FROM logistique."T_Remboursement"
          WHERE "T_Remboursement"."ID_AvoirFk" = a."ID_Avoir") r ON true
) v JOIN logistique."T_Avoir" a ON a."ID_Avoir"=v."ID_Avoir";

COMMENT ON COLUMN logistique."V_Avoir"."TauxTVA" IS 'Taux historique de la facture créditée.';

COMMENT ON COLUMN logistique."V_Avoir"."MontantHT" IS 'Montant HT restitué par cet avoir.';

COMMENT ON COLUMN logistique."V_Avoir"."MontantTVA" IS 'Taxe historique restituée par cet avoir.';

CREATE OR REPLACE VIEW logistique."V_Facture" AS SELECT v.*,f."TauxTVA",f."MontantTVA" FROM (
 SELECT b."ID_Facture",
    b."ID_CommandeFk",
    b."CodeFacture",
    b."ID_UserFk",
    b."IdEntiteFk",
    b."RequestId",
    b."PayloadHash",
    b."DateFacture",
    b."DateEcheancePaiement",
    b."ID_ModePaiementFk",
    b."ID_ConditionPaiementFk",
    b."DelaiJours",
    b."ID_DeviseFk",
    b."DeviseCode",
    b."DeviseLibelle",
    b."MontantHT",
    b."MontantTTC",
    b."TransactionCreation",
    b."CreeLe",
    b."ModifieLe",
    b."MontantFacture",
    b."TotalRegle",
    (b."Reste" - COALESCE(cr.total, 0::numeric))::numeric(12,2) AS "Reste",
    b."NbReglements",
    b."DernierReglement",
        CASE
            WHEN (b."Reste" - COALESCE(cr.total, 0::numeric)) <= 0::numeric THEN 'Réglée'::text
            WHEN b."TotalRegle" > 0::numeric OR COALESCE(cr.total, 0::numeric) > 0::numeric THEN 'Partiellement réglée'::text
            ELSE 'Non réglée'::text
        END AS "EtatReglement",
    b."EstEnRetard" AND (b."Reste" - COALESCE(cr.total, 0::numeric)) > 0::numeric AS "EstEnRetard",
    b."JoursAvantEcheance",
    logistique.fn_montant_avoir_attente(b."ID_CommandeFk")::numeric(12,2) AS "MontantAvoirAEtablir",
    logistique.fn_montant_avoir_attente(b."ID_CommandeFk") > 0::numeric AS "AvoirAEtablir",
    COALESCE(cr.total, 0::numeric)::numeric(12,2) AS "AvoirImpute",
    (b."MontantTTC" - COALESCE(cr.total, 0::numeric))::numeric(12,2) AS "MontantNetARegler"
   FROM ( WITH payments AS (
                 SELECT "T_Reglements"."CodeFactureFk",
                    COALESCE(sum("T_Reglements"."MontantRegle"), 0::numeric)::numeric(12,2) AS total,
                    count(*) AS n,
                    max("T_Reglements"."DateReglement") AS last
                   FROM logistique."T_Reglements"
                  GROUP BY "T_Reglements"."CodeFactureFk"
                ), returned AS (
                 SELECT r."ID_CommandeOrigineFk" AS command_id,
                    d."ID_ArticleFk",
                    sum(d."QteCmdDetail") AS quantity
                   FROM logistique."T_RetourBon" r
                     JOIN logistique."T_CommandeDetail" d ON d."ID_CmdFk" = r."ID_CommandeRetourFk"
                  GROUP BY r."ID_CommandeOrigineFk", d."ID_ArticleFk"
                ), credit AS (
                 SELECT l."ID_FactureFk",
                    sum(GREATEST(COALESCE(r.quantity, 0::numeric) - l."QteRetourAvantFacture"::numeric, 0::numeric) * l."PUFacture")::numeric(12,2) AS total
                   FROM logistique."T_FactureLigne" l
                     LEFT JOIN returned r ON r.command_id = l."ID_CmdFk" AND r."ID_ArticleFk" = l."ID_ArticleFk"
                  GROUP BY l."ID_FactureFk"
                )
         SELECT f."ID_Facture",
            f."ID_CommandeFk",
            f."CodeFacture",
            f."ID_UserFk",
            f."IdEntiteFk",
            f."RequestId",
            f."PayloadHash",
            f."DateFacture",
            f."DateEcheancePaiement",
            f."ID_ModePaiementFk",
            f."ID_ConditionPaiementFk",
            f."DelaiJours",
            f."ID_DeviseFk",
            f."DeviseCode",
            f."DeviseLibelle",
            f."MontantHT",
            f."MontantTTC",
            f."TransactionCreation",
            f."CreeLe",
            f."ModifieLe",
            f."MontantTTC" AS "MontantFacture",
            COALESCE(p.total, 0::numeric)::numeric(12,2) AS "TotalRegle",
            (f."MontantTTC" - COALESCE(p.total, 0::numeric))::numeric(12,2) AS "Reste",
            COALESCE(p.n, 0::bigint) AS "NbReglements",
            p.last AS "DernierReglement",
                CASE
                    WHEN COALESCE(p.total, 0::numeric) <= 0::numeric THEN 'Non réglée'::text
                    WHEN p.total < f."MontantTTC" THEN 'Partiellement réglée'::text
                    ELSE 'Réglée'::text
                END AS "EtatReglement",
            f."DateEcheancePaiement"::date < CURRENT_DATE AND f."MontantTTC" > COALESCE(p.total, 0::numeric) AS "EstEnRetard",
            f."DateEcheancePaiement"::date - CURRENT_DATE AS "JoursAvantEcheance",
            COALESCE(c.total, 0::numeric)::numeric(12,2) AS "MontantAvoirAEtablir",
            COALESCE(c.total, 0::numeric) > 0::numeric AS "AvoirAEtablir"
           FROM logistique."T_Facture" f
             LEFT JOIN payments p ON p."CodeFactureFk"::text = f."CodeFacture"::text
             LEFT JOIN credit c ON c."ID_FactureFk" = f."ID_Facture") b
     LEFT JOIN LATERAL ( SELECT sum("T_AvoirAffectation"."Montant") AS total
           FROM logistique."T_AvoirAffectation"
          WHERE "T_AvoirAffectation"."ID_CommandeCibleFk" = b."ID_CommandeFk") cr ON true
) v JOIN logistique."T_Facture" f ON f."ID_Facture"=v."ID_Facture";

COMMENT ON COLUMN logistique."V_Facture"."TauxTVA" IS 'Taux figé à l’émission de la facture.';

COMMENT ON COLUMN logistique."V_Facture"."MontantTVA" IS 'Somme figée des taxes arrondies de lignes.';

CREATE OR REPLACE VIEW logistique."V_FactureLigne" AS SELECT v.*,f."TauxTVA",l."MontantTVA",l."MontantTTC" FROM (
 SELECT l."ID_FactureLigne",
    l."ID_FactureFk",
    l."ID_CmdFk",
    l."ID_ArticleFk",
    l."NomArticle",
    l."CodeArticleInterne",
    l."Unite",
    l."QteSortie",
    l."QteRetourAvantFacture",
    l."QteFacturee",
    l."PUFacture",
    l."MontantLigne",
    f."ID_CommandeFk",
    f."CodeFacture",
    f."ID_DeviseFk",
    f."DeviseCode",
    f."DeviseLibelle"
   FROM logistique."T_FactureLigne" l
     JOIN logistique."T_Facture" f ON f."ID_Facture" = l."ID_FactureFk"
) v JOIN logistique."T_FactureLigne" l JOIN logistique."T_Facture" f ON f."ID_Facture"=l."ID_FactureFk" ON l."ID_FactureLigne"=v."ID_FactureLigne";

COMMENT ON COLUMN logistique."V_FactureLigne"."TauxTVA" IS 'Taux de la facture d’origine, conservé pour réimpression et avoir.';

COMMENT ON COLUMN logistique."V_FactureLigne"."MontantTVA" IS 'Taxe figée de cette ligne.';

COMMENT ON COLUMN logistique."V_FactureLigne"."MontantTTC" IS 'Montant HT de ligne plus sa taxe.';

CREATE OR REPLACE VIEW systeme."V_IdentiteDocumentaire" AS SELECT v.*,e."TauxTVAEntite" FROM (
 SELECT "IdEntite",
    "NomEntite",
    "AdresseEntite",
    "EmailEntite",
    "PhoneEntite",
    "IdentifiantsLegauxEntite",
    "MentionDocumentaireEntite",
    xmin::text AS _version,
    "SiteWebEntite",
    "AfficherEnteteDocument",
    "AfficherPiedDocument",
    "LogoEntite" IS NOT NULL AS "HasLogo",
    "LogoMimeEntite",
    "LogoSha256Entite",
    "LogoModifieLe",
    "PhoneSecondaireEntite"
   FROM systeme."T_Entite"
) v JOIN systeme."T_Entite" e ON e."IdEntite"=v."IdEntite";

COMMENT ON COLUMN systeme."V_IdentiteDocumentaire"."TauxTVAEntite" IS 'Taux de TVA courant des nouvelles factures de cette entreprise, en pourcentage.';

COMMENT ON VIEW systeme."V_IdentiteDocumentaire" IS 'Identité documentaire courante et taux de TVA paramétrable de l’entreprise ; sans contenu binaire du logo ni information de compte.';
COMMENT ON VIEW logistique."V_Facture" IS 'Facture figée, taxe historique, règlements, imputations et solde net ; une modification du taux d’entreprise ne modifie aucun montant émis.';
COMMENT ON VIEW logistique."V_FactureLigne" IS 'Lignes historiques HT/TVA/TTC d’une facture, avec désignations, quantités nettes et devise figées.';
COMMENT ON VIEW logistique."V_Avoir" IS 'Avoir historique HT/TVA/TTC et disponible après imputations et remboursements ; sans réécriture de sa facture ni mouvement de stock.';
INSERT INTO systeme."T_ModuleApplication"("CodeModule","Nom","EstSocle","CodeIncluant","Actif","Ordre")
VALUES('parametres','Paramètres',true,NULL,true,100)
ON CONFLICT("CodeModule") DO NOTHING;
CREATE OR REPLACE VIEW logistique."V_SuiviReglements" AS SELECT v.*,f."TauxTVA",f."MontantTVA",f."MontantHT" AS "MontantHTFacture" FROM (
 SELECT b."ID_Commande",
    b."CodeCmd",
    b."CodeFacture",
    b."DateFacture",
    b."DateEcheancePaiement",
    b."NomClientSaisi",
    b."MontantTTC",
    b."TotalRegle",
    b."Reste",
    b."NbReglements",
    b."DernierReglement",
    b."EtatReglement",
    b."EstEnRetard",
    b."JoursAvantEcheance",
    b."ID_DeviseFk",
    b."DeviseCode",
    b."DeviseLibelle",
    b."ID_Facture",
    b."EstFactureSnapshot",
    b."MontantFacture",
    logistique.fn_montant_avoir_attente(b."ID_Commande")::numeric(12,2) AS "MontantAvoirAEtablir",
    logistique.fn_montant_avoir_attente(b."ID_Commande") > 0::numeric AS "AvoirAEtablir",
    b."MontantBon",
    b."IdEntiteFk",
    b."ID_TiersFk",
    b."TiersNom",
    b."ID_DestinationFk",
    b."DestinationLibelle",
    COALESCE(cr.total, 0::numeric)::numeric(12,2) AS "AvoirImpute",
    (b."MontantFacture" - COALESCE(cr.total, 0::numeric))::numeric(12,2) AS "MontantNetARegler"
   FROM ( SELECT s."ID_Commande",
            s."CodeCmd",
            s."CodeFacture",
            s."DateFacture",
            s."DateEcheancePaiement",
            s."NomClientSaisi",
            s."MontantTTC",
            s."TotalRegle",
            s."Reste",
            s."NbReglements",
            s."DernierReglement",
            s."EtatReglement",
            s."EstEnRetard",
            s."JoursAvantEcheance",
            s."ID_DeviseFk",
            s."DeviseCode",
            s."DeviseLibelle",
            s."ID_Facture",
            s."EstFactureSnapshot",
            s."MontantFacture",
            s."MontantAvoirAEtablir",
            s."AvoirAEtablir",
            s."MontantBon",
            s."IdEntiteFk",
            s."ID_TiersFk",
            s."TiersNom",
            c."ID_DestinationFk",
            d.label AS "DestinationLibelle"
           FROM ( SELECT source."ID_Commande",
                    source."CodeCmd",
                    source."CodeFacture",
                    source."DateFacture",
                    source."DateEcheancePaiement",
                    source."NomClientSaisi",
                    source."MontantTTC",
                    source."TotalRegle",
                    source."Reste",
                    source."NbReglements",
                    source."DernierReglement",
                    source."EtatReglement",
                    source."EstEnRetard",
                    source."JoursAvantEcheance",
                    source."ID_DeviseFk",
                    source."DeviseCode",
                    source."DeviseLibelle",
                    source."ID_Facture",
                    source."EstFactureSnapshot",
                    source."MontantFacture",
                    source."MontantAvoirAEtablir",
                    source."AvoirAEtablir",
                    source."MontantBon",
                    r."IdEntiteFk",
                    r."ID_TiersFk",
                    t."Nom" AS "TiersNom"
                   FROM ( SELECT base."ID_Commande",
                            base."CodeCmd",
                            base."CodeFacture",
                            base."DateFacture",
                            base."DateEcheancePaiement",
                            base."NomClientSaisi",
                            COALESCE(f."MontantTTC", base."MontantTTC") AS "MontantTTC",
                            COALESCE(f."TotalRegle", base."TotalRegle") AS "TotalRegle",
                            COALESCE(f."Reste", base."Reste") AS "Reste",
                            base."NbReglements",
                            base."DernierReglement",
                            COALESCE(f."EtatReglement", base."EtatReglement") AS "EtatReglement",
                            COALESCE(f."EstEnRetard", base."EstEnRetard") AS "EstEnRetard",
                            base."JoursAvantEcheance",
                            base."ID_DeviseFk",
                            COALESCE(f."DeviseCode", base."DeviseCode") AS "DeviseCode",
                            COALESCE(f."DeviseLibelle", base."DeviseLibelle") AS "DeviseLibelle",
                            f."ID_Facture",
                            f."ID_Facture" IS NOT NULL AS "EstFactureSnapshot",
                                CASE
                                    WHEN NULLIF(btrim(base."CodeFacture"::text), ''::text) IS NOT NULL THEN COALESCE(f."MontantTTC", base."MontantTTC")
                                    ELSE NULL::numeric
                                END::numeric(12,2) AS "MontantFacture",
                            COALESCE(f."MontantAvoirAEtablir", 0::numeric)::numeric(12,2) AS "MontantAvoirAEtablir",
                            COALESCE(f."AvoirAEtablir", false) AS "AvoirAEtablir",
                            base."MontantTTC" AS "MontantBon"
                           FROM ( SELECT historique."ID_Commande",
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
                                    source_1."ID_DeviseFk",
                                    logistique.fn_code_devise(devise."AbrGenerique"::text) AS "DeviseCode",
                                    devise."NomGenerique"::text AS "DeviseLibelle"
                                   FROM ( SELECT c_1."ID_Commande",
    c_1."CodeCmd",
    c_1."CodeFacture",
    c_1."DateFacture",
    c_1."DateEcheancePaiement",
    c_1."NomClientSaisi",
    COALESCE(c_1."MontantTTC", 0::numeric)::numeric(12,2) AS "MontantTTC",
    COALESCE(sum(r_1."MontantRegle"), 0::numeric)::numeric(12,2) AS "TotalRegle",
    (COALESCE(c_1."MontantTTC", 0::numeric) - COALESCE(sum(r_1."MontantRegle"), 0::numeric))::numeric(12,2) AS "Reste",
    count(r_1."ID_Reglement") AS "NbReglements",
    max(r_1."DateReglement") AS "DernierReglement",
  CASE
   WHEN c_1."CodeFacture" IS NULL THEN 'Non facturée'::text
   WHEN COALESCE(c_1."MontantTTC", 0::numeric) = 0::numeric THEN 'Montant nul'::text
   WHEN COALESCE(sum(r_1."MontantRegle"), 0::numeric) <= 0::numeric THEN 'Non réglée'::text
   WHEN COALESCE(sum(r_1."MontantRegle"), 0::numeric) < COALESCE(c_1."MontantTTC", 0::numeric) THEN 'Partiellement réglée'::text
   ELSE 'Réglée'::text
  END AS "EtatReglement",
    c_1."DateEcheancePaiement" IS NOT NULL AND c_1."DateEcheancePaiement"::date < CURRENT_DATE AND (COALESCE(c_1."MontantTTC", 0::numeric) - COALESCE(sum(r_1."MontantRegle"), 0::numeric)) > 0::numeric AS "EstEnRetard",
  CASE
   WHEN c_1."DateEcheancePaiement" IS NOT NULL THEN c_1."DateEcheancePaiement"::date - CURRENT_DATE
   ELSE NULL::integer
  END AS "JoursAvantEcheance"
   FROM logistique."T_Commande" c_1
     LEFT JOIN logistique."T_Reglements" r_1 ON r_1."CodeFactureFk"::text = c_1."CodeFacture"::text
  GROUP BY c_1."ID_Commande", c_1."CodeCmd", c_1."CodeFacture", c_1."DateFacture", c_1."DateEcheancePaiement", c_1."NomClientSaisi", c_1."MontantTTC") historique
                                     LEFT JOIN logistique."T_Commande" source_1 ON source_1."ID_Commande" = historique."ID_Commande"
                                     LEFT JOIN referentiel."T_Generique" devise ON devise."ID_Generique" = source_1."ID_DeviseFk") base
                             LEFT JOIN logistique."V_Facture" f ON f."ID_CommandeFk" = base."ID_Commande") source
                     LEFT JOIN logistique."T_Commande" r ON r."ID_Commande" = source."ID_Commande"
                     LEFT JOIN logistique."T_Client" t ON t."ID_Client" = r."ID_TiersFk") s
             JOIN logistique."T_Commande" c ON c."ID_Commande" = s."ID_Commande"
             LEFT JOIN geolocalisation."V_DestinationLogistique" d ON d.id = c."ID_DestinationFk") b
     LEFT JOIN LATERAL ( SELECT sum("T_AvoirAffectation"."Montant") AS total
           FROM logistique."T_AvoirAffectation"
          WHERE "T_AvoirAffectation"."ID_CommandeCibleFk" = b."ID_Commande") cr ON true
) v LEFT JOIN logistique."T_Facture" f ON f."ID_CommandeFk"=v."ID_Commande";

COMMENT ON COLUMN logistique."V_SuiviReglements"."TauxTVA" IS 'Taux historique de la facture émise, distinct du taux courant de l’entreprise.';

COMMENT ON COLUMN logistique."V_SuiviReglements"."MontantTVA" IS 'TVA de la facture émise, sans modification des totaux physiques du bon.';

COMMENT ON COLUMN logistique."V_SuiviReglements"."MontantHTFacture" IS 'Montant HT immuable de la facture émise ; les retours postérieurs produisent un avoir séparé.';

COMMENT ON VIEW logistique."V_SuiviReglements" IS 'Registre documentaire et suivi des montants, avec fiscalité de la facture émise jointe sans modifier le stock ni les totaux physiques du bon.';

CREATE OR REPLACE VIEW logistique."V_Commande" AS SELECT v.*,f."TauxTVA" AS "TauxTVAFacture",f."MontantTVA" AS "MontantTVAFacture",f."MontantHT" AS "MontantHTFacture" FROM (
 SELECT source."ID_Commande",
    source."ID_TypeCmdFk",
    source."ID_StatutCmdFk",
    source."ID_ClientFk",
    source."ID_UserFk",
    source."geolocalisationCmd",
    source."DateHeureAutoCmd",
    source."DateCmd",
    source."CodeCmd",
    source."RefCmd",
    source."MontantHT",
    source."MontantTTC",
    source."UrlBL",
    source."ObsCmd",
    source."SelectCmd",
    source."DateHeureAutoFacture",
    source."DateFacture",
    source."CodeFacture",
    source."MontantRegleFacture",
    source."MontantResteFacture",
    source."StatusFacture",
    source."ValideRemiseFacture",
    source."UrlFacture",
    source."ID_ConditionPaiementFk",
    source."DateEcheancePaiement",
    source."ID_ModePaiementFk",
    source."NomClientSaisi",
    source."AbrTypeCmd",
    source."TypeCmd",
    source."SigneCommande",
    source."EstCommandeEntree",
    source."EstCommandeSortie",
    source."AbrStatutCmd",
    source."StatutCmd",
    source."NomUser",
    source."PrenomUser",
    source."NomComplet",
    source."AbrConditionPaiement",
    source."ConditionPaiement",
    source."AbrModePaiement",
    source."ModePaiement",
    source."MontantHTCalc",
    source."MontantTTCCalc",
    source."MontantRegleFactureCalc",
    source."MontantResteFactureCalc",
    source."TotalRegleReel",
    source."ResteReel",
    source."NbReglements",
    source."DernierReglement",
    source."EtatPaiement",
    source."EstPaiementEnRetard",
    source."JoursAvantEcheance",
    source."NbLignes",
    source."NbArticlesDistincts",
    source."QteTotale",
    source."MontantDetails",
    source."ListeArticles",
    source."EstCommandeSansDetails",
    source."EcartMontantDetails",
    source."EstMontantIncoherent",
    source."EtatControleCommande",
    source."ID_DeviseFk",
    source."DeviseCode",
    source."DeviseLibelle",
    source."ID_Facture",
    source."EstFactureSnapshot",
    source."MontantFacture",
    source."MontantAvoirAEtablir",
    source."AvoirAEtablir",
    source."IdEntiteFk",
    source."ID_TiersFk",
    source."TiersNom",
    source."ID_DestinationFk",
    source."DestinationLibelle",
    source."AvoirImpute",
    source."OrigineBon",
    source."ID_ArticleInitialFk",
    source."NatureBon",
    h."AncienCodeCmd",
    h."RenumeroteLe"
   FROM ( SELECT source_1."ID_Commande",
            source_1."ID_TypeCmdFk",
            source_1."ID_StatutCmdFk",
            source_1."ID_ClientFk",
            source_1."ID_UserFk",
            source_1."geolocalisationCmd",
            source_1."DateHeureAutoCmd",
            source_1."DateCmd",
            source_1."CodeCmd",
            source_1."RefCmd",
            source_1."MontantHT",
            source_1."MontantTTC",
            source_1."UrlBL",
            source_1."ObsCmd",
            source_1."SelectCmd",
            source_1."DateHeureAutoFacture",
            source_1."DateFacture",
            source_1."CodeFacture",
            source_1."MontantRegleFacture",
            source_1."MontantResteFacture",
            source_1."StatusFacture",
            source_1."ValideRemiseFacture",
            source_1."UrlFacture",
            source_1."ID_ConditionPaiementFk",
            source_1."DateEcheancePaiement",
            source_1."ID_ModePaiementFk",
            source_1."NomClientSaisi",
            source_1."AbrTypeCmd",
            source_1."TypeCmd",
            source_1."SigneCommande",
            source_1."EstCommandeEntree",
            source_1."EstCommandeSortie",
            source_1."AbrStatutCmd",
            source_1."StatutCmd",
            source_1."NomUser",
            source_1."PrenomUser",
            source_1."NomComplet",
            source_1."AbrConditionPaiement",
            source_1."ConditionPaiement",
            source_1."AbrModePaiement",
            source_1."ModePaiement",
            source_1."MontantHTCalc",
            source_1."MontantTTCCalc",
                CASE
                    WHEN logistique.fn_nature_bon(source_1."ID_TypeCmdFk") = 'commande'::text THEN NULL::numeric
                    ELSE source_1."MontantRegleFactureCalc"
                END::numeric(12,2) AS "MontantRegleFactureCalc",
                CASE
                    WHEN logistique.fn_nature_bon(source_1."ID_TypeCmdFk") = 'commande'::text THEN NULL::numeric
                    ELSE source_1."MontantResteFactureCalc"
                END::numeric(12,2) AS "MontantResteFactureCalc",
                CASE
                    WHEN logistique.fn_nature_bon(source_1."ID_TypeCmdFk") = 'commande'::text THEN NULL::numeric
                    ELSE source_1."TotalRegleReel"
                END::numeric(12,2) AS "TotalRegleReel",
                CASE
                    WHEN logistique.fn_nature_bon(source_1."ID_TypeCmdFk") = 'commande'::text THEN NULL::numeric
                    ELSE source_1."ResteReel"
                END::numeric(12,2) AS "ResteReel",
            source_1."NbReglements",
            source_1."DernierReglement",
                CASE
                    WHEN logistique.fn_nature_bon(source_1."ID_TypeCmdFk") = 'commande'::text THEN 'Sans facturation'::text
                    ELSE source_1."EtatPaiement"
                END AS "EtatPaiement",
                CASE
                    WHEN logistique.fn_nature_bon(source_1."ID_TypeCmdFk") = 'commande'::text THEN false
                    ELSE source_1."EstPaiementEnRetard"
                END AS "EstPaiementEnRetard",
                CASE
                    WHEN logistique.fn_nature_bon(source_1."ID_TypeCmdFk") = 'commande'::text THEN NULL::integer
                    ELSE source_1."JoursAvantEcheance"
                END AS "JoursAvantEcheance",
            source_1."NbLignes",
            source_1."NbArticlesDistincts",
            source_1."QteTotale",
            source_1."MontantDetails",
            source_1."ListeArticles",
            source_1."EstCommandeSansDetails",
            source_1."EcartMontantDetails",
            source_1."EstMontantIncoherent",
            source_1."EtatControleCommande",
            source_1."ID_DeviseFk",
            source_1."DeviseCode",
            source_1."DeviseLibelle",
            source_1."ID_Facture",
            source_1."EstFactureSnapshot",
            source_1."MontantFacture",
            source_1."MontantAvoirAEtablir",
            source_1."AvoirAEtablir",
            source_1."IdEntiteFk",
            source_1."ID_TiersFk",
            source_1."TiersNom",
            source_1."ID_DestinationFk",
            source_1."DestinationLibelle",
            source_1."AvoirImpute",
            source_1."OrigineBon",
            source_1."ID_ArticleInitialFk",
            logistique.fn_nature_bon(source_1."ID_TypeCmdFk") AS "NatureBon"
           FROM ( SELECT source_1_1."ID_Commande",
                    source_1_1."ID_TypeCmdFk",
                    source_1_1."ID_StatutCmdFk",
                    source_1_1."ID_ClientFk",
                    source_1_1."ID_UserFk",
                    source_1_1."geolocalisationCmd",
                    source_1_1."DateHeureAutoCmd",
                    source_1_1."DateCmd",
                    source_1_1."CodeCmd",
                    source_1_1."RefCmd",
                    source_1_1."MontantHT",
                    source_1_1."MontantTTC",
                    source_1_1."UrlBL",
                    source_1_1."ObsCmd",
                    source_1_1."SelectCmd",
                    source_1_1."DateHeureAutoFacture",
                    source_1_1."DateFacture",
                    source_1_1."CodeFacture",
                    source_1_1."MontantRegleFacture",
                    source_1_1."MontantResteFacture",
                    source_1_1."StatusFacture",
                    source_1_1."ValideRemiseFacture",
                    source_1_1."UrlFacture",
                    source_1_1."ID_ConditionPaiementFk",
                    source_1_1."DateEcheancePaiement",
                    source_1_1."ID_ModePaiementFk",
                    source_1_1."NomClientSaisi",
                    source_1_1."AbrTypeCmd",
                    source_1_1."TypeCmd",
                    source_1_1."SigneCommande",
                    source_1_1."EstCommandeEntree",
                    source_1_1."EstCommandeSortie",
                    source_1_1."AbrStatutCmd",
                    source_1_1."StatutCmd",
                    source_1_1."NomUser",
                    source_1_1."PrenomUser",
                    source_1_1."NomComplet",
                    source_1_1."AbrConditionPaiement",
                    source_1_1."ConditionPaiement",
                    source_1_1."AbrModePaiement",
                    source_1_1."ModePaiement",
                    source_1_1."MontantHTCalc",
                    source_1_1."MontantTTCCalc",
                    source_1_1."MontantRegleFactureCalc",
                    source_1_1."MontantResteFactureCalc",
                    source_1_1."TotalRegleReel",
                    source_1_1."ResteReel",
                    source_1_1."NbReglements",
                    source_1_1."DernierReglement",
                    source_1_1."EtatPaiement",
                    source_1_1."EstPaiementEnRetard",
                    source_1_1."JoursAvantEcheance",
                    source_1_1."NbLignes",
                    source_1_1."NbArticlesDistincts",
                    source_1_1."QteTotale",
                    source_1_1."MontantDetails",
                    source_1_1."ListeArticles",
                    source_1_1."EstCommandeSansDetails",
                    source_1_1."EcartMontantDetails",
                    source_1_1."EstMontantIncoherent",
                    source_1_1."EtatControleCommande",
                    source_1_1."ID_DeviseFk",
                    source_1_1."DeviseCode",
                    source_1_1."DeviseLibelle",
                    source_1_1."ID_Facture",
                    source_1_1."EstFactureSnapshot",
                    source_1_1."MontantFacture",
                    source_1_1."MontantAvoirAEtablir",
                    source_1_1."AvoirAEtablir",
                    source_1_1."IdEntiteFk",
                    source_1_1."ID_TiersFk",
                    source_1_1."TiersNom",
                    source_1_1."ID_DestinationFk",
                    source_1_1."DestinationLibelle",
                    source_1_1."AvoirImpute",
                    c."OrigineBon",
                    c."ID_ArticleInitialFk"
                   FROM ( SELECT b."ID_Commande",
                            b."ID_TypeCmdFk",
                            b."ID_StatutCmdFk",
                            b."ID_ClientFk",
                            b."ID_UserFk",
                            b."geolocalisationCmd",
                            b."DateHeureAutoCmd",
                            b."DateCmd",
                            b."CodeCmd",
                            b."RefCmd",
                            b."MontantHT",
                            b."MontantTTC",
                            b."UrlBL",
                            b."ObsCmd",
                            b."SelectCmd",
                            b."DateHeureAutoFacture",
                            b."DateFacture",
                            b."CodeFacture",
                            b."MontantRegleFacture",
                            b."MontantResteFacture",
                            b."StatusFacture",
                            b."ValideRemiseFacture",
                            b."UrlFacture",
                            b."ID_ConditionPaiementFk",
                            b."DateEcheancePaiement",
                            b."ID_ModePaiementFk",
                            b."NomClientSaisi",
                            b."AbrTypeCmd",
                            b."TypeCmd",
                            b."SigneCommande",
                            b."EstCommandeEntree",
                            b."EstCommandeSortie",
                            b."AbrStatutCmd",
                            b."StatutCmd",
                            b."NomUser",
                            b."PrenomUser",
                            b."NomComplet",
                            b."AbrConditionPaiement",
                            b."ConditionPaiement",
                            b."AbrModePaiement",
                            b."ModePaiement",
                            b."MontantHTCalc",
                            b."MontantTTCCalc",
                            b."MontantRegleFactureCalc",
                            b."MontantResteFactureCalc",
                            b."TotalRegleReel",
                            b."ResteReel",
                            b."NbReglements",
                            b."DernierReglement",
                            b."EtatPaiement",
                            b."EstPaiementEnRetard",
                            b."JoursAvantEcheance",
                            b."NbLignes",
                            b."NbArticlesDistincts",
                            b."QteTotale",
                            b."MontantDetails",
                            b."ListeArticles",
                            b."EstCommandeSansDetails",
                            b."EcartMontantDetails",
                            b."EstMontantIncoherent",
                            b."EtatControleCommande",
                            b."ID_DeviseFk",
                            b."DeviseCode",
                            b."DeviseLibelle",
                            b."ID_Facture",
                            b."EstFactureSnapshot",
                            b."MontantFacture",
                            pending.amount::numeric(12,2) AS "MontantAvoirAEtablir",
                            pending.amount > 0::numeric AS "AvoirAEtablir",
                            b."IdEntiteFk",
                            b."ID_TiersFk",
                            b."TiersNom",
                            b."ID_DestinationFk",
                            b."DestinationLibelle",
                            COALESCE(cr.total, 0::numeric)::numeric(12,2) AS "AvoirImpute"
                           FROM ( SELECT s."ID_Commande",
                                    s."ID_TypeCmdFk",
                                    s."ID_StatutCmdFk",
                                    s."ID_ClientFk",
                                    s."ID_UserFk",
                                    s."geolocalisationCmd",
                                    s."DateHeureAutoCmd",
                                    s."DateCmd",
                                    s."CodeCmd",
                                    s."RefCmd",
                                    s."MontantHT",
                                    s."MontantTTC",
                                    s."UrlBL",
                                    s."ObsCmd",
                                    s."SelectCmd",
                                    s."DateHeureAutoFacture",
                                    s."DateFacture",
                                    s."CodeFacture",
                                    s."MontantRegleFacture",
                                    s."MontantResteFacture",
                                    s."StatusFacture",
                                    s."ValideRemiseFacture",
                                    s."UrlFacture",
                                    s."ID_ConditionPaiementFk",
                                    s."DateEcheancePaiement",
                                    s."ID_ModePaiementFk",
                                    s."NomClientSaisi",
                                    s."AbrTypeCmd",
                                    s."TypeCmd",
                                    s."SigneCommande",
                                    s."EstCommandeEntree",
                                    s."EstCommandeSortie",
                                    s."AbrStatutCmd",
                                    s."StatutCmd",
                                    s."NomUser",
                                    s."PrenomUser",
                                    s."NomComplet",
                                    s."AbrConditionPaiement",
                                    s."ConditionPaiement",
                                    s."AbrModePaiement",
                                    s."ModePaiement",
                                    s."MontantHTCalc",
                                    s."MontantTTCCalc",
                                    s."MontantRegleFactureCalc",
                                    s."MontantResteFactureCalc",
                                    s."TotalRegleReel",
                                    s."ResteReel",
                                    s."NbReglements",
                                    s."DernierReglement",
                                    s."EtatPaiement",
                                    s."EstPaiementEnRetard",
                                    s."JoursAvantEcheance",
                                    s."NbLignes",
                                    s."NbArticlesDistincts",
                                    s."QteTotale",
                                    s."MontantDetails",
                                    s."ListeArticles",
                                    s."EstCommandeSansDetails",
                                    s."EcartMontantDetails",
                                    s."EstMontantIncoherent",
                                    s."EtatControleCommande",
                                    s."ID_DeviseFk",
                                    s."DeviseCode",
                                    s."DeviseLibelle",
                                    s."ID_Facture",
                                    s."EstFactureSnapshot",
                                    s."MontantFacture",
                                    s."MontantAvoirAEtablir",
                                    s."AvoirAEtablir",
                                    s."IdEntiteFk",
                                    s."ID_TiersFk",
                                    s."TiersNom",
                                    c_1."ID_DestinationFk",
                                    d.label AS "DestinationLibelle"
                                   FROM ( SELECT source_1_1_1."ID_Commande",
    source_1_1_1."ID_TypeCmdFk",
    source_1_1_1."ID_StatutCmdFk",
    source_1_1_1."ID_ClientFk",
    source_1_1_1."ID_UserFk",
    source_1_1_1."geolocalisationCmd",
    source_1_1_1."DateHeureAutoCmd",
    source_1_1_1."DateCmd",
    source_1_1_1."CodeCmd",
    source_1_1_1."RefCmd",
    source_1_1_1."MontantHT",
    source_1_1_1."MontantTTC",
    source_1_1_1."UrlBL",
    source_1_1_1."ObsCmd",
    source_1_1_1."SelectCmd",
    source_1_1_1."DateHeureAutoFacture",
    source_1_1_1."DateFacture",
    source_1_1_1."CodeFacture",
    source_1_1_1."MontantRegleFacture",
    source_1_1_1."MontantResteFacture",
    source_1_1_1."StatusFacture",
    source_1_1_1."ValideRemiseFacture",
    source_1_1_1."UrlFacture",
    source_1_1_1."ID_ConditionPaiementFk",
    source_1_1_1."DateEcheancePaiement",
    source_1_1_1."ID_ModePaiementFk",
    source_1_1_1."NomClientSaisi",
    source_1_1_1."AbrTypeCmd",
    source_1_1_1."TypeCmd",
    source_1_1_1."SigneCommande",
    source_1_1_1."EstCommandeEntree",
    source_1_1_1."EstCommandeSortie",
    source_1_1_1."AbrStatutCmd",
    source_1_1_1."StatutCmd",
    source_1_1_1."NomUser",
    source_1_1_1."PrenomUser",
    source_1_1_1."NomComplet",
    source_1_1_1."AbrConditionPaiement",
    source_1_1_1."ConditionPaiement",
    source_1_1_1."AbrModePaiement",
    source_1_1_1."ModePaiement",
    source_1_1_1."MontantHTCalc",
    source_1_1_1."MontantTTCCalc",
    source_1_1_1."MontantRegleFactureCalc",
    source_1_1_1."MontantResteFactureCalc",
    source_1_1_1."TotalRegleReel",
    source_1_1_1."ResteReel",
    source_1_1_1."NbReglements",
    source_1_1_1."DernierReglement",
    source_1_1_1."EtatPaiement",
    source_1_1_1."EstPaiementEnRetard",
    source_1_1_1."JoursAvantEcheance",
    source_1_1_1."NbLignes",
    source_1_1_1."NbArticlesDistincts",
    source_1_1_1."QteTotale",
    source_1_1_1."MontantDetails",
    source_1_1_1."ListeArticles",
    source_1_1_1."EstCommandeSansDetails",
    source_1_1_1."EcartMontantDetails",
    source_1_1_1."EstMontantIncoherent",
    source_1_1_1."EtatControleCommande",
    source_1_1_1."ID_DeviseFk",
    source_1_1_1."DeviseCode",
    source_1_1_1."DeviseLibelle",
    source_1_1_1."ID_Facture",
    source_1_1_1."EstFactureSnapshot",
    source_1_1_1."MontantFacture",
    source_1_1_1."MontantAvoirAEtablir",
    source_1_1_1."AvoirAEtablir",
    r."IdEntiteFk",
    r."ID_TiersFk",
    t."Nom" AS "TiersNom"
   FROM ( SELECT base."ID_Commande",
      base."ID_TypeCmdFk",
      base."ID_StatutCmdFk",
      base."ID_ClientFk",
      base."ID_UserFk",
      base."geolocalisationCmd",
      base."DateHeureAutoCmd",
      base."DateCmd",
      base."CodeCmd",
      base."RefCmd",
      base."MontantHT",
      base."MontantTTC",
      base."UrlBL",
      base."ObsCmd",
      base."SelectCmd",
      base."DateHeureAutoFacture",
      base."DateFacture",
      base."CodeFacture",
      COALESCE(f."TotalRegle", base."MontantRegleFacture") AS "MontantRegleFacture",
      COALESCE(f."Reste", base."MontantResteFacture") AS "MontantResteFacture",
      base."StatusFacture",
      base."ValideRemiseFacture",
      base."UrlFacture",
      base."ID_ConditionPaiementFk",
      base."DateEcheancePaiement",
      base."ID_ModePaiementFk",
      base."NomClientSaisi",
      base."AbrTypeCmd",
      base."TypeCmd",
      base."SigneCommande",
      base."EstCommandeEntree",
      base."EstCommandeSortie",
      base."AbrStatutCmd",
      base."StatutCmd",
      base."NomUser",
      base."PrenomUser",
      base."NomComplet",
      base."AbrConditionPaiement",
      base."ConditionPaiement",
      base."AbrModePaiement",
      base."ModePaiement",
      base."MontantHTCalc",
      base."MontantTTCCalc",
      COALESCE(f."TotalRegle", base."MontantRegleFactureCalc") AS "MontantRegleFactureCalc",
      COALESCE(f."Reste", base."MontantResteFactureCalc") AS "MontantResteFactureCalc",
      COALESCE(f."TotalRegle", base."TotalRegleReel") AS "TotalRegleReel",
      COALESCE(f."Reste", base."ResteReel") AS "ResteReel",
      base."NbReglements",
      base."DernierReglement",
      COALESCE(f."EtatReglement", base."EtatPaiement") AS "EtatPaiement",
      COALESCE(f."EstEnRetard", base."EstPaiementEnRetard") AS "EstPaiementEnRetard",
      base."JoursAvantEcheance",
      base."NbLignes",
      base."NbArticlesDistincts",
      base."QteTotale",
      base."MontantDetails",
      base."ListeArticles",
      base."EstCommandeSansDetails",
      base."EcartMontantDetails",
      base."EstMontantIncoherent",
      base."EtatControleCommande",
      base."ID_DeviseFk",
      COALESCE(f."DeviseCode", base."DeviseCode") AS "DeviseCode",
      COALESCE(f."DeviseLibelle", base."DeviseLibelle") AS "DeviseLibelle",
      f."ID_Facture",
      f."ID_Facture" IS NOT NULL AS "EstFactureSnapshot",
    CASE
     WHEN NULLIF(btrim(base."CodeFacture"::text), ''::text) IS NOT NULL THEN COALESCE(f."MontantTTC", base."MontantTTC")
     ELSE NULL::numeric
    END::numeric(12,2) AS "MontantFacture",
      COALESCE(f."MontantAvoirAEtablir", 0::numeric)::numeric(12,2) AS "MontantAvoirAEtablir",
      COALESCE(f."AvoirAEtablir", false) AS "AvoirAEtablir"
     FROM ( SELECT historique."ID_Commande",
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
        source_1_1_1_1."ID_DeviseFk",
        logistique.fn_code_devise(devise."AbrGenerique"::text) AS "DeviseCode",
        devise."NomGenerique"::text AS "DeviseLibelle"
       FROM ( WITH cd_stats AS (
         SELECT cd."ID_CmdFk",
            count(*)::integer AS "NbLignes",
            count(DISTINCT cd."ID_ArticleFk")::integer AS "NbArticlesDistincts",
            COALESCE(sum(COALESCE(cd."QteCmdDetail", 0::numeric)), 0::numeric)::numeric(14,3) AS "QteTotale",
            COALESCE(sum(round(COALESCE(cd."QteCmdDetail", 0::numeric) * COALESCE(cd."PUCmdDetail", 0::numeric), 2)), 0::numeric)::numeric(12,2) AS "MontantDetails",
            string_agg(DISTINCT a."NomArticle"::text, ', '::text ORDER BY (a."NomArticle"::text)) AS "ListeArticles"
           FROM logistique."T_CommandeDetail" cd
             LEFT JOIN logistique."T_Article" a ON a."ID_Article" = cd."ID_ArticleFk"
          GROUP BY cd."ID_CmdFk"
        ), reg_stats AS (
         SELECT r_1."CodeFactureFk",
            COALESCE(sum(COALESCE(r_1."MontantRegle", 0::numeric)), 0::numeric)::numeric(12,2) AS "TotalRegleReel",
            count(*)::integer AS "NbReglements",
            max(r_1."DateReglement") AS "DernierReglement"
           FROM logistique."T_Reglements" r_1
          GROUP BY r_1."CodeFactureFk"
        )
       SELECT c_1_1."ID_Commande",
          c_1_1."ID_TypeCmdFk",
          c_1_1."ID_StatutCmdFk",
          c_1_1."ID_ClientFk",
          c_1_1."ID_UserFk",
          c_1_1."geolocalisationCmd",
          c_1_1."DateHeureAutoCmd",
          c_1_1."DateCmd",
          c_1_1."CodeCmd",
          c_1_1."RefCmd",
          c_1_1."MontantHT",
          c_1_1."MontantTTC",
          c_1_1."UrlBL",
          c_1_1."ObsCmd",
          c_1_1."SelectCmd",
          c_1_1."DateHeureAutoFacture",
          c_1_1."DateFacture",
          c_1_1."CodeFacture",
          c_1_1."MontantRegleFacture",
          c_1_1."MontantResteFacture",
          c_1_1."StatusFacture",
          c_1_1."ValideRemiseFacture",
          c_1_1."UrlFacture",
          c_1_1."ID_ConditionPaiementFk",
          c_1_1."DateEcheancePaiement",
          c_1_1."ID_ModePaiementFk",
          c_1_1."NomClientSaisi",
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
          COALESCE(c_1_1."MontantHT", 0::numeric)::numeric(12,2) AS "MontantHTCalc",
          COALESCE(c_1_1."MontantTTC", 0::numeric)::numeric(12,2) AS "MontantTTCCalc",
          COALESCE(c_1_1."MontantRegleFacture", 0::numeric)::numeric(12,2) AS "MontantRegleFactureCalc",
          COALESCE(c_1_1."MontantResteFacture", 0::numeric)::numeric(12,2) AS "MontantResteFactureCalc",
          COALESCE(reg_stats."TotalRegleReel", 0::numeric)::numeric(12,2) AS "TotalRegleReel",
          (COALESCE(c_1_1."MontantTTC", 0::numeric) - COALESCE(reg_stats."TotalRegleReel", 0::numeric))::numeric(12,2) AS "ResteReel",
          COALESCE(reg_stats."NbReglements", 0) AS "NbReglements",
          reg_stats."DernierReglement",
        CASE
         WHEN c_1_1."CodeFacture" IS NULL THEN 'Non facturée'::text
         WHEN COALESCE(c_1_1."MontantTTC", 0::numeric) = 0::numeric THEN 'Montant nul'::text
         WHEN COALESCE(reg_stats."TotalRegleReel", COALESCE(c_1_1."MontantRegleFacture", 0::numeric), 0::numeric) <= 0::numeric THEN 'Non réglée'::text
         WHEN COALESCE(reg_stats."TotalRegleReel", COALESCE(c_1_1."MontantRegleFacture", 0::numeric), 0::numeric) < COALESCE(c_1_1."MontantTTC", 0::numeric) THEN 'Partiellement réglée'::text
         WHEN COALESCE(reg_stats."TotalRegleReel", COALESCE(c_1_1."MontantRegleFacture", 0::numeric), 0::numeric) >= COALESCE(c_1_1."MontantTTC", 0::numeric) THEN 'Réglée'::text
         ELSE 'Indéterminé'::text
        END AS "EtatPaiement",
          c_1_1."DateEcheancePaiement" IS NOT NULL AND c_1_1."DateEcheancePaiement"::date < CURRENT_DATE AND (COALESCE(c_1_1."MontantTTC", 0::numeric) - COALESCE(reg_stats."TotalRegleReel", COALESCE(c_1_1."MontantRegleFacture", 0::numeric), 0::numeric)) > 0::numeric AS "EstPaiementEnRetard",
        CASE
         WHEN c_1_1."DateEcheancePaiement" IS NOT NULL THEN c_1_1."DateEcheancePaiement"::date - CURRENT_DATE
         ELSE NULL::integer
        END AS "JoursAvantEcheance",
          COALESCE(cd_stats."NbLignes", 0) AS "NbLignes",
          COALESCE(cd_stats."NbArticlesDistincts", 0) AS "NbArticlesDistincts",
          COALESCE(cd_stats."QteTotale", 0::numeric)::numeric(14,3) AS "QteTotale",
          COALESCE(cd_stats."MontantDetails", 0::numeric)::numeric(12,2) AS "MontantDetails",
          cd_stats."ListeArticles",
          COALESCE(cd_stats."NbLignes", 0) = 0 AS "EstCommandeSansDetails",
          (COALESCE(c_1_1."MontantHT", 0::numeric) - COALESCE(cd_stats."MontantDetails", 0::numeric))::numeric(12,2) AS "EcartMontantDetails",
          abs(COALESCE(c_1_1."MontantHT", 0::numeric) - COALESCE(cd_stats."MontantDetails", 0::numeric)) > 0.01 AS "EstMontantIncoherent",
        CASE
         WHEN COALESCE(cd_stats."NbLignes", 0) = 0 THEN 'Sans détails'::text
         WHEN abs(COALESCE(c_1_1."MontantHT", 0::numeric) - COALESCE(cd_stats."MontantDetails", 0::numeric)) > 0.01 THEN 'Montant incohérent'::text
         ELSE 'Cohérente'::text
        END AS "EtatControleCommande"
         FROM logistique."T_Commande" c_1_1
           LEFT JOIN systeme."T_Utilisateurs" u ON c_1_1."ID_UserFk" = u."IdUser"
           LEFT JOIN referentiel."T_Generique" type_cmd ON c_1_1."ID_TypeCmdFk" = type_cmd."ID_Generique"
           LEFT JOIN referentiel."T_Generique" statut_cmd ON c_1_1."ID_StatutCmdFk" = statut_cmd."ID_Generique"
           LEFT JOIN referentiel."T_Generique" condition_paiement ON c_1_1."ID_ConditionPaiementFk" = condition_paiement."ID_Generique"
           LEFT JOIN referentiel."T_Generique" mode_paiement ON c_1_1."ID_ModePaiementFk" = mode_paiement."ID_Generique"
           LEFT JOIN cd_stats ON cd_stats."ID_CmdFk" = c_1_1."ID_Commande"
           LEFT JOIN reg_stats ON reg_stats."CodeFactureFk"::text = c_1_1."CodeFacture"::text) historique
         LEFT JOIN logistique."T_Commande" source_1_1_1_1 ON source_1_1_1_1."ID_Commande" = historique."ID_Commande"
         LEFT JOIN referentiel."T_Generique" devise ON devise."ID_Generique" = source_1_1_1_1."ID_DeviseFk") base
       LEFT JOIN logistique."V_Facture" f ON f."ID_CommandeFk" = base."ID_Commande") source_1_1_1
     LEFT JOIN logistique."T_Commande" r ON r."ID_Commande" = source_1_1_1."ID_Commande"
     LEFT JOIN logistique."T_Client" t ON t."ID_Client" = r."ID_TiersFk") s
                                     JOIN logistique."T_Commande" c_1 ON c_1."ID_Commande" = s."ID_Commande"
                                     LEFT JOIN geolocalisation."V_DestinationLogistique" d ON d.id = c_1."ID_DestinationFk") b
                             LEFT JOIN LATERAL ( SELECT sum("T_AvoirAffectation"."Montant") AS total
                                   FROM logistique."T_AvoirAffectation"
                                  WHERE "T_AvoirAffectation"."ID_CommandeCibleFk" = b."ID_Commande") cr ON true
                             LEFT JOIN LATERAL ( SELECT logistique.fn_montant_avoir_attente(b."ID_Commande") AS amount) pending ON true) source_1_1
                     JOIN logistique."T_Commande" c ON c."ID_Commande" = source_1_1."ID_Commande") source_1) source
     LEFT JOIN logistique."T_BonCodeHistorique" h ON h."ID_Commande" = source."ID_Commande"
) v LEFT JOIN logistique."T_Facture" f ON f."ID_CommandeFk"=v."ID_Commande";

COMMENT ON COLUMN logistique."V_Commande"."TauxTVAFacture" IS 'Taux historique de la facture émise, distinct du taux courant de l’entreprise.';

COMMENT ON COLUMN logistique."V_Commande"."MontantTVAFacture" IS 'TVA de la facture émise, sans modification des totaux physiques du bon.';

COMMENT ON COLUMN logistique."V_Commande"."MontantHTFacture" IS 'Montant HT immuable de la facture émise ; les retours postérieurs produisent un avoir séparé.';

COMMENT ON VIEW logistique."V_Commande" IS 'Registre documentaire et suivi des montants, avec fiscalité de la facture émise jointe sans modifier le stock ni les totaux physiques du bon.';


-- Les colonnes fiscales restent optionnelles dans les registres et exports.
DO $$
DECLARE interface_key text; field_name text; field_label text; additions jsonb; ordinal integer; current_columns jsonb;
BEGIN
 FOREACH interface_key IN ARRAY ARRAY['logistique.factures','logistique.commandes'] LOOP
  SELECT "Colonnes" INTO current_columns FROM referentiel."T_InterfaceTableau" WHERE "CleInterface"=interface_key FOR UPDATE;
  IF NOT FOUND THEN CONTINUE;END IF;
  additions='[]'::jsonb;
  SELECT coalesce(max((v->>'defaultOrder')::integer),-1)+1 INTO ordinal FROM jsonb_array_elements(current_columns) v;
  FOREACH field_name IN ARRAY CASE WHEN interface_key='logistique.factures' THEN ARRAY['MontantHTFacture','TauxTVA','MontantTVA'] ELSE ARRAY['MontantHTFacture','TauxTVAFacture','MontantTVAFacture'] END LOOP
   IF EXISTS(SELECT FROM jsonb_array_elements(current_columns) v WHERE v->>'id'=field_name) THEN CONTINUE;END IF;
   field_label=CASE WHEN field_name='MontantHTFacture' THEN 'Montant HT facturé' WHEN field_name LIKE 'TauxTVA%' THEN 'TVA (%)' ELSE 'Montant TVA facturé' END;
   additions=additions||jsonb_build_array(jsonb_build_object('id',field_name,'type','numeric','label',field_label,'exportable',true,'tableAvailable',true,'defaultVisible',false,'defaultExport',false,'defaultOrder',ordinal,'defaultExportOrder',ordinal+100));
   ordinal=ordinal+1;
  END LOOP;
  IF jsonb_array_length(additions)>0 THEN UPDATE referentiel."T_InterfaceTableau" SET "Colonnes"="Colonnes"||additions,"Version"="Version"+1,"ModifieLe"=clock_timestamp() WHERE "CleInterface"=interface_key;END IF;
 END LOOP;
END $$;
COMMENT ON TABLE logistique."T_Facture" IS 'Facture émise immuable : base HT, taux et TVA capturés par entreprise, TTC de règlement et instantanés des lignes ; aucune seconde sortie de stock.';
COMMENT ON TABLE logistique."T_FactureLigne" IS 'Ligne de facture figée : désignation, quantité nette et prix HT, taxe arrondie et total TTC ; source des restitutions financières.';
COMMENT ON TABLE logistique."T_Avoir" IS 'Avoir immuable lié aux retours postérieurs à facture : HT et TVA de l’instantané original, TTC imputable ou remboursable, sans effet de stock supplémentaire.';
COMMENT ON TABLE logistique."T_AvoirLigne" IS 'Quantité retournée après facture et montants HT/TVA/TTC crédités par différences cumulées, au prix et à la taxe historiques.';
COMMENT ON CONSTRAINT "T_Entite_TauxTVAEntite_not_null" ON systeme."T_Entite" IS 'Le défaut fiscal explicite de l’entreprise existe toujours ; zéro ne signifie pas un régime légal déduit.';
COMMENT ON CONSTRAINT "T_Facture_TauxTVA_not_null" ON logistique."T_Facture" IS 'Chaque facture possède son taux historique, y compris zéro pour les documents antérieurs.';
COMMENT ON CONSTRAINT "T_Facture_MontantTVA_not_null" ON logistique."T_Facture" IS 'Montant de TVA émis explicite, même lorsqu’il vaut zéro.';
COMMENT ON CONSTRAINT "T_FactureLigne_MontantTVA_not_null" ON logistique."T_FactureLigne" IS 'Taxe de ligne toujours déterminée par le taux figé.';
COMMENT ON CONSTRAINT "T_Avoir_TauxTVA_not_null" ON logistique."T_Avoir" IS 'Taux de la facture créditée toujours conservé.';
COMMENT ON CONSTRAINT "T_Avoir_MontantTVA_not_null" ON logistique."T_Avoir" IS 'Taxe créditée explicite, même lorsque nulle.';
COMMENT ON CONSTRAINT "T_AvoirLigne_MontantTVA_not_null" ON logistique."T_AvoirLigne" IS 'La taxe restituée de la ligne est toujours explicite.';

COMMIT;
