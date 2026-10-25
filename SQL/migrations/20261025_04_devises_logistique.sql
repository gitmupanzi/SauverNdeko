-- Devises logistiques : catalogue, bons/factures et instantanés des flux.
-- Accord du propriétaire du 25/10/2026 : tous les montants historiques sont USD.
-- Aucun taux, aucune conversion ni recalcul des montants/quantités existants.
-- Appliquer après sauvegarde complète. Arrêter les écritures applicatives pendant la fenêtre.
-- Le retour arrière après usage multidevise exige une restauration contrôlée ; ne pas supprimer
-- les colonnes d'instantané sur une base ayant reçu de nouvelles écritures.
BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '120s';
SET LOCAL search_path = pg_catalog, public;

DO $preconditions$
BEGIN
 IF current_database() <> 'SauverNdeko' AND current_setting('sauverndeko.fixture_devises', true) IS DISTINCT FROM 'on' THEN
  RAISE EXCEPTION 'Migration réservée à SauverNdeko ou à une recette isolée explicitement identifiée.';
 END IF;
 IF EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'logistique."T_Article"'::regclass
             AND attname = 'ID_DeviseFk' AND NOT attisdropped) THEN
  RAISE EXCEPTION 'Migration devises déjà appliquée ou état partiel à examiner.';
 END IF;
 IF to_regclass('logistique."V_ConsoMensuelleDevise"') IS NOT NULL
    OR to_regclass('logistique."V_Reglements"') IS NOT NULL THEN
  RAISE EXCEPTION 'Une projection devise existe déjà : examiner ses dépendances avant application.';
 END IF;
END;
$preconditions$;

-- Verrous pris avant empreinte : une écriture concurrente ne peut fausser le contrôle.
LOCK TABLE logistique."T_Article", logistique."T_Commande", logistique."T_Mouvement", logistique."T_Reglements"
 IN ACCESS EXCLUSIVE MODE;
CREATE TEMP TABLE migration_devises_before (objet text PRIMARY KEY, lignes bigint, empreinte text) ON COMMIT DROP;
DO $empreintes$
DECLARE t text;
BEGIN
 FOREACH t IN ARRAY ARRAY['T_Article','T_Commande','T_Mouvement','T_Reglements'] LOOP
  EXECUTE format('INSERT INTO migration_devises_before SELECT %L,count(*),md5(coalesce(string_agg(md5(to_jsonb(x)::text),%L ORDER BY to_jsonb(x)::text),%L)) FROM logistique.%I x',t,'','',t);
 END LOOP;
END;
$empreintes$;

CREATE FUNCTION logistique.fn_code_devise(p_abreviation text) RETURNS text
 LANGUAGE sql IMMUTABLE PARALLEL SAFE RETURNS NULL ON NULL INPUT
 SET search_path = pg_catalog
 AS $$ SELECT CASE upper(btrim(p_abreviation)) WHEN 'EURO' THEN 'EUR' ELSE upper(btrim(p_abreviation)) END $$;
COMMENT ON FUNCTION logistique.fn_code_devise(text) IS
 'Code de devise normalisé du référentiel ; EURO est présenté EUR, sans conversion monétaire.';

CREATE FUNCTION logistique.fn_devise_usd() RETURNS integer
 LANGUAGE plpgsql STABLE SET search_path = pg_catalog
 AS $$
DECLARE identifiant integer; nombre bigint;
BEGIN
 SELECT min(g."ID_Generique"),count(*) INTO identifiant,nombre
 FROM referentiel."T_Generique" g JOIN referentiel."T_CategorieGenerique" c
  ON c."ID_CategorieGenerique"=g."ID_CategorieGeneriqueFk"
 WHERE lower(btrim(c."NomCategorieGenerique"))='devise'
   AND c."ValideCategorieGenerique" IS TRUE AND g."ValideGenerique" IS TRUE
   AND logistique.fn_code_devise(g."AbrGenerique")='USD';
 IF nombre<>1 THEN
  RAISE EXCEPTION 'Une seule devise USD active est requise dans la catégorie Devise active (trouvées : %).',nombre USING ERRCODE='23514';
 END IF;
 RETURN identifiant;
END;
$$;
COMMENT ON FUNCTION logistique.fn_devise_usd() IS
 'Résout exactement une référence USD active dans la catégorie Devise active ; aucun identifiant numérique codé en dur.';

-- Précondition USD évaluée avant toute modification des tables.
SELECT logistique.fn_devise_usd();
-- DEFAULT STABLE alimente les lignes existantes sans UPDATE ni effets des triggers de stock.
ALTER TABLE logistique."T_Article" ADD COLUMN "ID_DeviseFk" integer NOT NULL DEFAULT logistique.fn_devise_usd(),
 ADD CONSTRAINT article_devise_fk FOREIGN KEY ("ID_DeviseFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON DELETE RESTRICT;
ALTER TABLE logistique."T_Commande" ADD COLUMN "ID_DeviseFk" integer NOT NULL DEFAULT logistique.fn_devise_usd(),
 ADD CONSTRAINT commande_devise_fk FOREIGN KEY ("ID_DeviseFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON DELETE RESTRICT;
ALTER TABLE logistique."T_Mouvement" ADD COLUMN "ID_DeviseFk" integer NOT NULL DEFAULT logistique.fn_devise_usd(),
 ADD CONSTRAINT mouvement_devise_fk FOREIGN KEY ("ID_DeviseFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON DELETE RESTRICT;
ALTER TABLE logistique."T_Reglements" ADD COLUMN "ID_DeviseFk" integer NOT NULL DEFAULT logistique.fn_devise_usd(),
 ADD CONSTRAINT reglement_devise_fk FOREIGN KEY ("ID_DeviseFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON DELETE RESTRICT;
ALTER TABLE logistique."T_Mouvement" ALTER COLUMN "ID_DeviseFk" DROP DEFAULT;
ALTER TABLE logistique."T_Reglements" ALTER COLUMN "ID_DeviseFk" DROP DEFAULT;

COMMENT ON COLUMN logistique."T_Article"."ID_DeviseFk" IS 'Devise des prix achat/vente et valorisations du catalogue ; USD historique confirmé. Immuable dès usage par ligne ou mouvement.';
COMMENT ON COLUMN logistique."T_Commande"."ID_DeviseFk" IS 'Devise unique des prix de ligne, totaux du bon et de sa facture ; aucun taux implicite. Immuable dès ligne, mouvement ou règlement.';
COMMENT ON COLUMN logistique."T_Mouvement"."ID_DeviseFk" IS 'Instantané de la devise du bon source ou de l’article pour un ajustement initial/direct ; conservé même si le bon disparaît.';
COMMENT ON COLUMN logistique."T_Reglements"."ID_DeviseFk" IS 'Instantané de la devise de la facture rattachée par CodeFactureFk ; règlement en autre devise interdit sans traitement explicite.';
COMMENT ON CONSTRAINT article_devise_fk ON logistique."T_Article" IS 'Conserve la référence monétaire historique du catalogue ; suppression de la devise utilisée refusée.';
COMMENT ON CONSTRAINT commande_devise_fk ON logistique."T_Commande" IS 'Conserve la référence monétaire historique du bon et de sa facture.';
COMMENT ON CONSTRAINT mouvement_devise_fk ON logistique."T_Mouvement" IS 'Conserve la référence monétaire du mouvement sans dépendre de la devise actuelle du catalogue.';
COMMENT ON CONSTRAINT reglement_devise_fk ON logistique."T_Reglements" IS 'Conserve la référence monétaire du règlement après son enregistrement.';

CREATE FUNCTION logistique.fn_verifier_devise(p_id integer) RETURNS void
 LANGUAGE plpgsql VOLATILE SET search_path = pg_catalog
 AS $$
BEGIN
 PERFORM 1 FROM referentiel."T_Generique" g JOIN referentiel."T_CategorieGenerique" c
   ON c."ID_CategorieGenerique"=g."ID_CategorieGeneriqueFk"
  WHERE g."ID_Generique"=p_id AND g."ValideGenerique" IS TRUE
   AND c."ValideCategorieGenerique" IS TRUE AND lower(btrim(c."NomCategorieGenerique"))='devise'
   AND logistique.fn_code_devise(g."AbrGenerique") ~ '^[A-Z]{3}$'
 FOR SHARE OF g,c;
 IF NOT FOUND THEN RAISE EXCEPTION 'Une devise active du référentiel Devise est requise.' USING ERRCODE='23514'; END IF;
END;
$$;
COMMENT ON FUNCTION logistique.fn_verifier_devise(integer) IS 'Verrouille la référence et sa catégorie contre une reclassification concurrente ; refuse devise absente, inactive ou sans code de trois lettres.';

CREATE FUNCTION logistique.tr_devise_article() RETURNS trigger
 LANGUAGE plpgsql SET search_path = pg_catalog
 AS $$
BEGIN
 PERFORM logistique.fn_verifier_devise(NEW."ID_DeviseFk");
 IF TG_OP='UPDATE' AND NEW."ID_DeviseFk" IS DISTINCT FROM OLD."ID_DeviseFk" AND (
  EXISTS (SELECT 1 FROM logistique."T_CommandeDetail" WHERE "ID_ArticleFk"=OLD."ID_Article")
  OR EXISTS (SELECT 1 FROM logistique."T_Mouvement" WHERE "ID_ArticleFk"=OLD."ID_Article")
 ) THEN RAISE EXCEPTION 'La devise d’un article déjà utilisé ne peut plus être changée.' USING ERRCODE='23514'; END IF;
 RETURN NEW;
END;
$$;
CREATE TRIGGER tr_00_devise_article BEFORE INSERT OR UPDATE OF "ID_DeviseFk","PUArticle","PVArticle"
 ON logistique."T_Article" FOR EACH ROW EXECUTE FUNCTION logistique.tr_devise_article();
COMMENT ON FUNCTION logistique.tr_devise_article() IS 'Valide la devise du catalogue et interdit sa réinterprétation après usage, sans écrire de stock.';
COMMENT ON TRIGGER tr_00_devise_article ON logistique."T_Article" IS 'Devise active et verrouillage de la dénomination monétaire du catalogue déjà utilisé.';

CREATE FUNCTION logistique.tr_devise_commande() RETURNS trigger
 LANGUAGE plpgsql SET search_path = pg_catalog
 AS $$
BEGIN
 PERFORM logistique.fn_verifier_devise(NEW."ID_DeviseFk");
 IF TG_OP='UPDATE' AND NEW."ID_DeviseFk" IS DISTINCT FROM OLD."ID_DeviseFk" AND (
  EXISTS (SELECT 1 FROM logistique."T_CommandeDetail" WHERE "ID_CmdFk"=OLD."ID_Commande")
  OR EXISTS (SELECT 1 FROM logistique."T_Mouvement" WHERE "ID_cmdFk"=OLD."ID_Commande")
  OR EXISTS (SELECT 1 FROM logistique."T_Reglements" WHERE "CodeFactureFk"=OLD."CodeFacture")
 ) THEN RAISE EXCEPTION 'La devise d’un bon comportant des lignes ou des flux ne peut plus être changée.' USING ERRCODE='23514'; END IF;
 RETURN NEW;
END;
$$;
CREATE TRIGGER tr_00_devise_commande BEFORE INSERT OR UPDATE OF "ID_DeviseFk","MontantHT","MontantTTC","MontantRegleFacture","MontantResteFacture"
 ON logistique."T_Commande" FOR EACH ROW EXECUTE FUNCTION logistique.tr_devise_commande();
COMMENT ON FUNCTION logistique.tr_devise_commande() IS 'Verrouille la devise du bon et de sa facture dès usage ; les prix des lignes sont exprimés dans cette devise sans conversion automatique.';
COMMENT ON TRIGGER tr_00_devise_commande ON logistique."T_Commande" IS 'Contrôle monétaire avant les effets existants de lignes, totaux et mouvements.';

CREATE FUNCTION logistique.tr_devise_mouvement() RETURNS trigger
 LANGUAGE plpgsql SET search_path = pg_catalog
 AS $$
DECLARE devise_source integer;
BEGIN
 IF TG_OP='UPDATE' THEN
  IF NEW."ID_DeviseFk" IS DISTINCT FROM OLD."ID_DeviseFk" THEN
   RAISE EXCEPTION 'La devise historique d’un mouvement est immuable.' USING ERRCODE='23514';
  END IF;
  -- ON DELETE SET NULL du bon ne doit jamais réinterpréter l’instantané.
  IF NEW."ID_cmdFk" IS NULL AND OLD."ID_cmdFk" IS NOT NULL THEN RETURN NEW; END IF;
 END IF;
 IF NEW."ID_cmdFk" IS NOT NULL THEN
  SELECT "ID_DeviseFk" INTO devise_source FROM logistique."T_Commande"
   WHERE "ID_Commande"=NEW."ID_cmdFk" FOR NO KEY UPDATE;
 ELSE
  SELECT "ID_DeviseFk" INTO devise_source FROM logistique."T_Article" WHERE "ID_Article"=NEW."ID_ArticleFk";
 END IF;
 IF devise_source IS NULL THEN RAISE EXCEPTION 'Source de devise du mouvement introuvable.' USING ERRCODE='23503'; END IF;
 IF TG_OP='INSERT' AND NEW."ID_DeviseFk" IS NULL THEN NEW."ID_DeviseFk"=devise_source; END IF;
 IF NEW."ID_DeviseFk" IS DISTINCT FROM devise_source THEN
  RAISE EXCEPTION 'La devise du mouvement doit correspondre à son bon ou à son article source.' USING ERRCODE='23514';
 END IF;
 PERFORM logistique.fn_verifier_devise(NEW."ID_DeviseFk");
 RETURN NEW;
END;
$$;
CREATE TRIGGER tr_00_devise_mouvement BEFORE INSERT OR UPDATE ON logistique."T_Mouvement"
 FOR EACH ROW EXECUTE FUNCTION logistique.tr_devise_mouvement();
COMMENT ON FUNCTION logistique.tr_devise_mouvement() IS 'Affecte une seule fois la devise du bon, ou de l’article initial/direct ; ne modifie ni quantité, ni prix, ni effet stock.';
COMMENT ON TRIGGER tr_00_devise_mouvement ON logistique."T_Mouvement" IS 'Instantané de devise conservé ; le verrou métier existant sur les écritures directes reste actif.';

CREATE FUNCTION logistique.tr_devise_reglement() RETURNS trigger
 LANGUAGE plpgsql SET search_path = pg_catalog
 AS $$
DECLARE devise_source integer;
BEGIN
 SELECT "ID_DeviseFk" INTO devise_source FROM logistique."T_Commande"
  WHERE "CodeFacture"=NEW."CodeFactureFk" FOR NO KEY UPDATE;
 IF devise_source IS NULL THEN RAISE EXCEPTION 'Une facture existante est requise pour le règlement.' USING ERRCODE='23503'; END IF;
 IF TG_OP='INSERT' AND NEW."ID_DeviseFk" IS NULL THEN NEW."ID_DeviseFk"=devise_source; END IF;
 IF TG_OP='UPDATE' AND NEW."ID_DeviseFk" IS DISTINCT FROM OLD."ID_DeviseFk" THEN
  RAISE EXCEPTION 'La devise historique d’un règlement est immuable.' USING ERRCODE='23514';
 END IF;
 IF NEW."ID_DeviseFk" IS DISTINCT FROM devise_source THEN
  RAISE EXCEPTION 'Le règlement doit être exprimé dans la devise de sa facture.' USING ERRCODE='23514';
 END IF;
 PERFORM logistique.fn_verifier_devise(NEW."ID_DeviseFk");
 RETURN NEW;
END;
$$;
CREATE TRIGGER tr_00_devise_reglement BEFORE INSERT OR UPDATE ON logistique."T_Reglements"
 FOR EACH ROW EXECUTE FUNCTION logistique.tr_devise_reglement();
COMMENT ON FUNCTION logistique.tr_devise_reglement() IS 'Rattache le règlement à la devise de sa facture unique, verrouille le parent et refuse tout paiement implicite en autre devise.';
COMMENT ON TRIGGER tr_00_devise_reglement ON logistique."T_Reglements" IS 'Conserve la devise de règlement sans second calcul des montants ou du stock.';

CREATE FUNCTION logistique.tr_proteger_reference_devise() RETURNS trigger
 LANGUAGE plpgsql SET search_path = pg_catalog
 AS $$
DECLARE utilisee boolean;
BEGIN
 SELECT EXISTS (SELECT 1 FROM logistique."T_Article" WHERE "ID_DeviseFk"=OLD."ID_Generique")
  OR EXISTS (SELECT 1 FROM logistique."T_Commande" WHERE "ID_DeviseFk"=OLD."ID_Generique")
  OR EXISTS (SELECT 1 FROM logistique."T_Mouvement" WHERE "ID_DeviseFk"=OLD."ID_Generique")
  OR EXISTS (SELECT 1 FROM logistique."T_Reglements" WHERE "ID_DeviseFk"=OLD."ID_Generique") INTO utilisee;
 IF utilisee AND (NEW."ID_CategorieGeneriqueFk" IS DISTINCT FROM OLD."ID_CategorieGeneriqueFk"
  OR logistique.fn_code_devise(NEW."AbrGenerique") IS DISTINCT FROM logistique.fn_code_devise(OLD."AbrGenerique")) THEN
  RAISE EXCEPTION 'Le code et la catégorie d’une devise utilisée sont immuables.' USING ERRCODE='23514';
 END IF;
 RETURN NEW;
END;
$$;
CREATE TRIGGER devise_logistique_reference_integrite BEFORE UPDATE OF "ID_CategorieGeneriqueFk","AbrGenerique"
 ON referentiel."T_Generique" FOR EACH ROW EXECUTE FUNCTION logistique.tr_proteger_reference_devise();
COMMENT ON FUNCTION logistique.tr_proteger_reference_devise() IS 'Empêche de renommer le code ou de reclasser une devise déjà utilisée ; la désactivation ne supprime pas l’historique.';
COMMENT ON TRIGGER devise_logistique_reference_integrite ON referentiel."T_Generique" IS 'Stabilité du code monétaire des montants historiques logistiques.';

-- Les vues existantes gardent leurs anciennes colonnes, dans le même ordre et type.
-- La sous-requête reprend la définition vérifiée en base avant cette migration.
CREATE OR REPLACE VIEW logistique."V_Article" AS
 SELECT historique.*, source."ID_DeviseFk", logistique.fn_code_devise(devise."AbrGenerique") AS "DeviseCode",
        devise."NomGenerique"::text AS "DeviseLibelle"
 FROM (
 SELECT a."ID_Article",
    a."DateHeureAuto",
    a."CodeArticleInterne",
    a."CodeArticleExterne",
    a."NomArticle",
    a."RefArticle",
    a."PhotoArticle",
    a."ObsArticle",
    a."ValideArticle",
    a."ID_TypeArticleFk",
    type_article."AbrGenerique" AS "AbrTypeArticle",
    type_article."NomGenerique" AS "TypeArticle",
    a."ID_CategorieArticleFk",
    categorie_article."AbrGenerique" AS "AbrCategorieArticle",
    categorie_article."NomGenerique" AS "CategorieArticle",
    a."ID_UniteFk",
    unite."AbrGenerique" AS "AbrUnite",
    unite."NomGenerique" AS "Unite",
    COALESCE(a."QteArticle", 0::numeric)::numeric(14,3) AS "QteArticle",
    a."QteMinArticle",
    GREATEST(COALESCE(a."QteMinArticle", 0)::numeric - COALESCE(a."QteArticle", 0::numeric), 0::numeric)::numeric(14,3) AS "QteACommander",
        CASE
            WHEN COALESCE(a."QteArticle", 0::numeric) <= 0::numeric THEN 'Rupture'::text
            WHEN a."QteMinArticle" IS NOT NULL AND COALESCE(a."QteArticle", 0::numeric) <= a."QteMinArticle"::numeric THEN 'Stock faible'::text
            ELSE 'Disponible'::text
        END AS "EtatStock",
    COALESCE(a."QteArticle", 0::numeric) <= 0::numeric AS "EstRupture",
    a."QteMinArticle" IS NOT NULL AND COALESCE(a."QteArticle", 0::numeric) <= a."QteMinArticle"::numeric AS "EstAlerteStock",
        CASE
            WHEN COALESCE(a."QteArticle", 0::numeric) <= 0::numeric THEN 1
            WHEN a."QteMinArticle" IS NOT NULL AND COALESCE(a."QteArticle", 0::numeric) <= a."QteMinArticle"::numeric THEN 2
            ELSE 3
        END AS "PrioriteStock",
    COALESCE(a."PUArticle", 0::numeric)::numeric(12,2) AS "PUArticle",
    COALESCE(a."PVArticle", 0::numeric)::numeric(12,2) AS "PVArticle",
    (COALESCE(a."QteArticle", 0::numeric) * COALESCE(a."PUArticle", 0::numeric))::numeric(14,2) AS "ValeurStockAchat",
    (COALESCE(a."QteArticle", 0::numeric) * COALESCE(a."PVArticle", 0::numeric))::numeric(14,2) AS "ValeurStockVente",
    (COALESCE(a."PVArticle", 0::numeric) - COALESCE(a."PUArticle", 0::numeric))::numeric(12,2) AS "MargeUnitaire",
        CASE
            WHEN COALESCE(a."PUArticle", 0::numeric) = 0::numeric THEN NULL::numeric
            ELSE round((COALESCE(a."PVArticle", 0::numeric) - COALESCE(a."PUArticle", 0::numeric)) / NULLIF(a."PUArticle", 0::numeric) * 100::numeric, 2)
        END AS "TauxMargePct",
    a."DatePeremptionArticle",
    a."DatePeremptionAlerteArticle",
    a."NbreJoursAlerteArticle",
        CASE
            WHEN a."DatePeremptionArticle" IS NULL THEN 'Non renseignée'::text
            WHEN a."DatePeremptionArticle"::date < CURRENT_DATE THEN 'Périmé'::text
            WHEN a."DatePeremptionAlerteArticle" IS NOT NULL AND a."DatePeremptionAlerteArticle"::date <= CURRENT_DATE THEN 'Alerte péremption'::text
            WHEN a."NbreJoursAlerteArticle" IS NOT NULL AND a."DatePeremptionArticle"::date <= (CURRENT_DATE + a."NbreJoursAlerteArticle") THEN 'Alerte péremption'::text
            ELSE 'Valide'::text
        END AS "EtatPeremption",
        CASE
            WHEN a."DatePeremptionArticle" IS NOT NULL THEN a."DatePeremptionArticle"::date - CURRENT_DATE
            ELSE NULL::integer
        END AS "JoursAvantPeremption",
    a."DatePeremptionArticle" IS NOT NULL AND a."DatePeremptionArticle"::date < CURRENT_DATE AS "EstPerime",
    a."DatePeremptionArticle" IS NOT NULL AND a."DatePeremptionArticle"::date >= CURRENT_DATE AND (a."DatePeremptionAlerteArticle" IS NOT NULL AND a."DatePeremptionAlerteArticle"::date <= CURRENT_DATE OR a."NbreJoursAlerteArticle" IS NOT NULL AND a."DatePeremptionArticle"::date <= (CURRENT_DATE + a."NbreJoursAlerteArticle")) AS "EstAlertePeremption",
        CASE
            WHEN a."DatePeremptionArticle" IS NULL THEN 4
            WHEN a."DatePeremptionArticle"::date < CURRENT_DATE THEN 1
            WHEN a."DatePeremptionAlerteArticle" IS NOT NULL AND a."DatePeremptionAlerteArticle"::date <= CURRENT_DATE OR a."NbreJoursAlerteArticle" IS NOT NULL AND a."DatePeremptionArticle"::date <= (CURRENT_DATE + a."NbreJoursAlerteArticle") THEN 2
            ELSE 3
        END AS "PrioritePeremption",
    a."ID_UserFK",
    u."IdUser",
    NULLIF(TRIM(BOTH FROM concat(COALESCE(u."PrenomUser", ''::character varying), ' ', COALESCE(u."NomUser", ''::character varying))), ''::text) AS "NomComplet",
        CASE
            WHEN COALESCE(a."ValideArticle", true) = false THEN 'Inactif'::text
            ELSE 'Actif'::text
        END AS "EtatArticle",
    a."PoidsUnitaire",
    a."ID_UnitePoidsFk",
    ( SELECT g."AbrGenerique"
           FROM referentiel."T_Generique" g
          WHERE g."ID_Generique" = a."ID_UnitePoidsFk") AS "UnitePoids",
    ( SELECT count(*)::integer AS count
           FROM logistique."T_LotArticle" l
          WHERE l."ID_ArticleFk" = a."ID_Article") AS "NombreLots",
    ( SELECT COALESCE(sum(l."StockLot"), 0::numeric) AS "coalesce"
           FROM logistique."V_LotArticleStock" l
          WHERE l."ID_ArticleFk" = a."ID_Article") AS "StockVentileLots",
    a."QteArticle" - (( SELECT COALESCE(sum(l."StockLot"), 0::numeric) AS "coalesce"
           FROM logistique."V_LotArticleStock" l
          WHERE l."ID_ArticleFk" = a."ID_Article")) AS "StockSansLot",
    a."InformationArticle"
   FROM logistique."T_Article" a
     LEFT JOIN referentiel."T_Generique" type_article ON a."ID_TypeArticleFk" = type_article."ID_Generique" AND type_article."ID_CategorieGeneriqueFk" = 46
     LEFT JOIN referentiel."T_Generique" categorie_article ON a."ID_CategorieArticleFk" = categorie_article."ID_Generique" AND categorie_article."ID_CategorieGeneriqueFk" = 40
     LEFT JOIN referentiel."T_Generique" unite ON a."ID_UniteFk" = unite."ID_Generique" AND unite."ID_CategorieGeneriqueFk" = 34
     LEFT JOIN systeme."T_Utilisateurs" u ON a."ID_UserFK" = u."IdUser"
 ) historique
 LEFT JOIN logistique."T_Article" source ON source."ID_Article"=historique."ID_Article"
 LEFT JOIN referentiel."T_Generique" devise ON devise."ID_Generique"=source."ID_DeviseFk";
COMMENT ON VIEW logistique."V_Article" IS 'Catalogue enrichi au grain article : nomenclatures, stock courant, seuils, prix, valorisations, péremption et utilisateur. Les états de stock et de péremption sont calculés à la lecture ; aucune restriction d’organisation n’est intégrée à la vue. Devise du catalogue article explicitée ; anciens grain et périmètre conservés.';
COMMENT ON COLUMN logistique."V_Article"."ID_DeviseFk" IS 'Référence de devise du catalogue article ; aucune conversion.';
COMMENT ON COLUMN logistique."V_Article"."DeviseCode" IS 'Code monétaire du référentiel ; EURO est normalisé EUR.';
COMMENT ON COLUMN logistique."V_Article"."DeviseLibelle" IS 'Libellé de la devise conservée dans le référentiel, y compris après désactivation.';

CREATE OR REPLACE VIEW logistique."V_Commande" AS
 SELECT historique.*, source."ID_DeviseFk", logistique.fn_code_devise(devise."AbrGenerique") AS "DeviseCode",
        devise."NomGenerique"::text AS "DeviseLibelle"
 FROM (
 WITH cd_stats AS (
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
     LEFT JOIN reg_stats ON reg_stats."CodeFactureFk"::text = c."CodeFacture"::text
 ) historique
 LEFT JOIN logistique."T_Commande" source ON source."ID_Commande"=historique."ID_Commande"
 LEFT JOIN referentiel."T_Generique" devise ON devise."ID_Generique"=source."ID_DeviseFk";
COMMENT ON VIEW logistique."V_Commande" IS 'Suivi au grain commande : en-tête, nomenclatures, agrégats de lignes et règlements, reste, échéance et contrôles de cohérence. L’autorisation et le périmètre d’organisation relèvent du consommateur serveur. Devise du bon et de sa facture explicitée ; anciens grain et périmètre conservés.';
COMMENT ON COLUMN logistique."V_Commande"."ID_DeviseFk" IS 'Référence de devise du bon et de sa facture ; aucune conversion.';
COMMENT ON COLUMN logistique."V_Commande"."DeviseCode" IS 'Code monétaire du référentiel ; EURO est normalisé EUR.';
COMMENT ON COLUMN logistique."V_Commande"."DeviseLibelle" IS 'Libellé de la devise conservée dans le référentiel, y compris après désactivation.';

CREATE OR REPLACE VIEW logistique."V_CommandeDetail" AS
 SELECT historique.*, source."ID_DeviseFk", logistique.fn_code_devise(devise."AbrGenerique") AS "DeviseCode",
        devise."NomGenerique"::text AS "DeviseLibelle"
 FROM (
 SELECT d."ID_CmdFk",
    c."ID_Commande",
    c."DateCmd",
    c."CodeCmd",
    c."CodeFacture",
    c."ID_TypeCmdFk",
    type_cmd."AbrGenerique" AS "AbrTypeCmd",
    type_cmd."NomGenerique" AS "TypeCmd",
        CASE
            WHEN type_cmd."AbrGenerique"::text ~~* 'entr%'::text THEN 1
            WHEN type_cmd."AbrGenerique"::text ~~* 'sort%'::text THEN '-1'::integer
            ELSE 0
        END AS "SigneCommande",
    c."ID_StatutCmdFk",
    c."ID_StatutCmdFk" AS "ID_StatutCmd",
    statut_cmd."AbrGenerique" AS "AbrStatutCmd",
    statut_cmd."NomGenerique" AS "StatutCmd",
    d."ID_ArticleFk",
    a."CodeArticleInterne",
    a."NomArticle",
    a."ID_UniteFk",
    unite."AbrGenerique" AS "AbrUnite",
    COALESCE(a."QteArticle", 0::numeric)::numeric(14,3) AS "StockActuel",
        CASE
            WHEN type_cmd."AbrGenerique"::text ~~* 'sort%'::text THEN (COALESCE(a."QteArticle", 0::numeric) + COALESCE(d."QteCmdDetail", 0::numeric))::numeric(14,3)
            WHEN type_cmd."AbrGenerique"::text ~~* 'entr%'::text THEN (COALESCE(a."QteArticle", 0::numeric) - COALESCE(d."QteCmdDetail", 0::numeric))::numeric(14,3)
            ELSE COALESCE(a."QteArticle", 0::numeric)::numeric(14,3)
        END AS "StockAvantLigneTheorique",
    COALESCE(d."QteCmdDetail", 0::numeric)::numeric(14,3) AS "QteCmdDetail",
    COALESCE(d."PUCmdDetail", 0::numeric)::numeric(12,2) AS "PUCmdDetail",
    (COALESCE(d."QteCmdDetail", 0::numeric) * COALESCE(d."PUCmdDetail", 0::numeric))::numeric(12,2) AS "MontantLigne",
    d."ObsCmdDetail",
    d."RemiseCmdDetail",
    d."LieuCmdDetail",
    d."SelectCmdDetail",
        CASE
            WHEN d."QteCmdDetail" IS NULL OR d."QteCmdDetail" <= 0::numeric THEN 'Quantité invalide'::text
            WHEN d."PUCmdDetail" IS NULL THEN 'Prix non renseigné'::text
            ELSE 'Valide'::text
        END AS "EtatLigne"
   FROM logistique."T_CommandeDetail" d
     JOIN logistique."T_Commande" c ON c."ID_Commande" = d."ID_CmdFk"
     JOIN logistique."T_Article" a ON a."ID_Article" = d."ID_ArticleFk"
     LEFT JOIN referentiel."T_Generique" type_cmd ON c."ID_TypeCmdFk" = type_cmd."ID_Generique" AND type_cmd."ID_CategorieGeneriqueFk" = 64
     LEFT JOIN referentiel."T_Generique" statut_cmd ON c."ID_StatutCmdFk" = statut_cmd."ID_Generique" AND statut_cmd."ID_CategorieGeneriqueFk" = 28
     LEFT JOIN referentiel."T_Generique" unite ON a."ID_UniteFk" = unite."ID_Generique" AND unite."ID_CategorieGeneriqueFk" = 34
 ) historique
 LEFT JOIN logistique."T_Commande" source ON source."ID_Commande"=historique."ID_CmdFk"
 LEFT JOIN referentiel."T_Generique" devise ON devise."ID_Generique"=source."ID_DeviseFk";
COMMENT ON VIEW logistique."V_CommandeDetail" IS 'Détail au grain couple commande/article : références, quantité et prix de ligne, montant, stock actuel et stock avant ligne théorique reconstruit depuis le stock courant ; ce dernier n’est pas un instantané historique. Devise du bon et de sa facture explicitée ; anciens grain et périmètre conservés.';
COMMENT ON COLUMN logistique."V_CommandeDetail"."ID_DeviseFk" IS 'Référence de devise du bon et de sa facture ; aucune conversion.';
COMMENT ON COLUMN logistique."V_CommandeDetail"."DeviseCode" IS 'Code monétaire du référentiel ; EURO est normalisé EUR.';
COMMENT ON COLUMN logistique."V_CommandeDetail"."DeviseLibelle" IS 'Libellé de la devise conservée dans le référentiel, y compris après désactivation.';

CREATE OR REPLACE VIEW logistique."V_Mouvement" AS
 SELECT historique.*, source."ID_DeviseFk", logistique.fn_code_devise(devise."AbrGenerique") AS "DeviseCode",
        devise."NomGenerique"::text AS "DeviseLibelle"
 FROM (
 SELECT m."DateHeureAutoMvt",
    m."DateMvt",
    m."ID_Mvt",
    m."ID_TypeMvtFk",
    g_typemvt."AbrGenerique" AS "TypeMvt",
    g_typemvt."NomGenerique" AS "NomTypeMvt",
    m."ID_ArticleFk",
    a."CodeArticleInterne",
    a."NomArticle",
    m."ID_cmdFk",
    c."CodeCmd",
    c."DateCmd",
    COALESCE(m."QteMvt", 0) AS "QteMvt",
    COALESCE(m."PUMvt", 0::numeric)::numeric(12,2) AS "PUMvt",
        CASE
            WHEN g_typemvt."AbrGenerique"::text ~~* 'entr%'::text THEN 1
            WHEN g_typemvt."AbrGenerique"::text ~~* 'sort%'::text THEN '-1'::integer
            ELSE 0
        END AS "SigneStock",
    (COALESCE(m."QteMvt", 0) *
        CASE
            WHEN g_typemvt."AbrGenerique"::text ~~* 'entr%'::text THEN 1
            WHEN g_typemvt."AbrGenerique"::text ~~* 'sort%'::text THEN '-1'::integer
            ELSE 0
        END)::numeric AS "QteMvtSigned",
    (COALESCE(m."QteMvt", 0)::numeric * COALESCE(m."PUMvt", 0::numeric))::numeric(14,2) AS "MontantMvt",
        CASE
            WHEN m."ID_cmdFk" IS NULL THEN 'Ajustement direct article'::text
            ELSE 'Commande'::text
        END AS "OrigineMouvement"
   FROM logistique."T_Mouvement" m
     LEFT JOIN logistique."T_Article" a ON m."ID_ArticleFk" = a."ID_Article"
     LEFT JOIN logistique."T_Commande" c ON m."ID_cmdFk" = c."ID_Commande"
     LEFT JOIN referentiel."T_Generique" g_typemvt ON m."ID_TypeMvtFk" = g_typemvt."ID_Generique" AND g_typemvt."ID_CategorieGeneriqueFk" = 64
 ) historique
 LEFT JOIN logistique."T_Mouvement" source ON source."ID_Mvt"=historique."ID_Mvt"
 LEFT JOIN referentiel."T_Generique" devise ON devise."ID_Generique"=source."ID_DeviseFk";
COMMENT ON VIEW logistique."V_Mouvement" IS 'Historique enrichi au grain mouvement : article, commande, type historique, quantité, signe, prix et origine. TypeMvt contient ici l’abréviation ; les ajustements directs ont une commande NULL. Devise du mouvement historique explicitée ; anciens grain et périmètre conservés.';
COMMENT ON COLUMN logistique."V_Mouvement"."ID_DeviseFk" IS 'Référence de devise du mouvement historique ; aucune conversion.';
COMMENT ON COLUMN logistique."V_Mouvement"."DeviseCode" IS 'Code monétaire du référentiel ; EURO est normalisé EUR.';
COMMENT ON COLUMN logistique."V_Mouvement"."DeviseLibelle" IS 'Libellé de la devise conservée dans le référentiel, y compris après désactivation.';

CREATE OR REPLACE VIEW logistique."V_MouvementStock" AS
 SELECT historique.*, source."ID_DeviseFk", logistique.fn_code_devise(devise."AbrGenerique") AS "DeviseCode",
        devise."NomGenerique"::text AS "DeviseLibelle"
 FROM (
 SELECT m."ID_Mvt",
    m."ID_ArticleFk",
    a."CodeArticleInterne",
    a."NomArticle",
    m."ID_cmdFk",
    c."CodeCmd",
    c."DateCmd",
    c."ID_TypeCmdFk" AS "ID_TypeCmdActuel",
    m."DateHeureAutoMvt",
    m."DateMvt",
    m."ID_TypeMvtFk" AS "ID_TypeMvt",
    g."AbrGenerique" AS "AbrTypeMvt",
    g."NomGenerique" AS "TypeMvt",
    COALESCE(m."QteMvt", 0) AS "QteMvt",
    COALESCE(m."PUMvt", 0::numeric)::numeric(12,2) AS "PUMvt",
        CASE
            WHEN g."AbrGenerique"::text ~~* 'entr%'::text THEN 1
            WHEN g."AbrGenerique"::text ~~* 'sort%'::text THEN '-1'::integer
            ELSE 0
        END AS "SigneStock",
    (COALESCE(m."QteMvt", 0) *
        CASE
            WHEN g."AbrGenerique"::text ~~* 'entr%'::text THEN 1
            WHEN g."AbrGenerique"::text ~~* 'sort%'::text THEN '-1'::integer
            ELSE 0
        END)::numeric AS "QteMvtSigned",
    (COALESCE(m."QteMvt", 0)::numeric * COALESCE(m."PUMvt", 0::numeric))::numeric(14,2) AS "MontantMvt",
    (COALESCE(m."QteMvt", 0)::numeric * COALESCE(m."PUMvt", 0::numeric) *
        CASE
            WHEN g."AbrGenerique"::text ~~* 'entr%'::text THEN 1
            WHEN g."AbrGenerique"::text ~~* 'sort%'::text THEN '-1'::integer
            ELSE 0
        END::numeric)::numeric(14,2) AS "MontantMvtSigned",
        CASE
            WHEN m."ID_cmdFk" IS NULL THEN 'Ajustement direct article'::text
            ELSE 'Commande'::text
        END AS "OrigineMouvement"
   FROM logistique."T_Mouvement" m
     LEFT JOIN logistique."T_Article" a ON a."ID_Article" = m."ID_ArticleFk"
     LEFT JOIN logistique."T_Commande" c ON c."ID_Commande" = m."ID_cmdFk"
     LEFT JOIN referentiel."T_Generique" g ON g."ID_Generique" = m."ID_TypeMvtFk" AND g."ID_CategorieGeneriqueFk" = 64
 ) historique
 LEFT JOIN logistique."T_Mouvement" source ON source."ID_Mvt"=historique."ID_Mvt"
 LEFT JOIN referentiel."T_Generique" devise ON devise."ID_Generique"=source."ID_DeviseFk";
COMMENT ON VIEW logistique."V_MouvementStock" IS 'Source commune au grain mouvement pour les calculs de stock : signe tiré du type historique catégorie 64, quantité/valeur signées et origine. Le type de commande actuel est exposé séparément. Devise du mouvement historique explicitée ; anciens grain et périmètre conservés.';
COMMENT ON COLUMN logistique."V_MouvementStock"."ID_DeviseFk" IS 'Référence de devise du mouvement historique ; aucune conversion.';
COMMENT ON COLUMN logistique."V_MouvementStock"."DeviseCode" IS 'Code monétaire du référentiel ; EURO est normalisé EUR.';
COMMENT ON COLUMN logistique."V_MouvementStock"."DeviseLibelle" IS 'Libellé de la devise conservée dans le référentiel, y compris après désactivation.';

CREATE OR REPLACE VIEW logistique."V_SuiviReglements" AS
 SELECT historique.*, source."ID_DeviseFk", logistique.fn_code_devise(devise."AbrGenerique") AS "DeviseCode",
        devise."NomGenerique"::text AS "DeviseLibelle"
 FROM (
 SELECT c."ID_Commande",
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
  GROUP BY c."ID_Commande", c."CodeCmd", c."CodeFacture", c."DateFacture", c."DateEcheancePaiement", c."NomClientSaisi", c."MontantTTC"
 ) historique
 LEFT JOIN logistique."T_Commande" source ON source."ID_Commande"=historique."ID_Commande"
 LEFT JOIN referentiel."T_Generique" devise ON devise."ID_Generique"=source."ID_DeviseFk";
COMMENT ON VIEW logistique."V_SuiviReglements" IS 'Suivi au grain commande/facture : somme des règlements rattachés par CodeFactureFk, reste TTC moins total réglé, dernière date et retard. Inclut aussi les commandes non facturées. Devise du bon et de sa facture explicitée ; anciens grain et périmètre conservés.';
COMMENT ON COLUMN logistique."V_SuiviReglements"."ID_DeviseFk" IS 'Référence de devise du bon et de sa facture ; aucune conversion.';
COMMENT ON COLUMN logistique."V_SuiviReglements"."DeviseCode" IS 'Code monétaire du référentiel ; EURO est normalisé EUR.';
COMMENT ON COLUMN logistique."V_SuiviReglements"."DeviseLibelle" IS 'Libellé de la devise conservée dans le référentiel, y compris après désactivation.';

CREATE OR REPLACE VIEW logistique."V_AuditStock" AS
 SELECT historique.*, source."ID_DeviseFk", logistique.fn_code_devise(devise."AbrGenerique") AS "DeviseCode",
        devise."NomGenerique"::text AS "DeviseLibelle"
 FROM (
 SELECT "ID_Article",
    "CodeArticleInterne",
    "NomArticle",
    "StockArticle",
    "StockMouvements",
    "Ecart",
    "N_Mouvements",
    "QteEntree",
    "QteSortie",
    "Ecart" = 0::numeric AS "EstStockCoherent",
        CASE
            WHEN "Ecart" = 0::numeric THEN 'Cohérent'::text
            WHEN "Ecart" > 0::numeric THEN 'Stock article supérieur aux mouvements'::text
            ELSE 'Stock article inférieur aux mouvements'::text
        END AS "EtatAuditStock"
   FROM logistique.fn_audit_stock(NULL::integer, NULL::timestamp without time zone) fn_audit_stock("ID_Article", "CodeArticleInterne", "NomArticle", "StockArticle", "StockMouvements", "Ecart", "N_Mouvements", "QteEntree", "QteSortie")
 ) historique
 LEFT JOIN logistique."T_Article" source ON source."ID_Article"=historique."ID_Article"
 LEFT JOIN referentiel."T_Generique" devise ON devise."ID_Generique"=source."ID_DeviseFk";
COMMENT ON VIEW logistique."V_AuditStock" IS 'Audit courant au grain article depuis fn_audit_stock(NULL,NULL) : stock enregistré, somme des mouvements signés, écart, entrées/sorties et état de cohérence. Devise du catalogue article explicitée ; anciens grain et périmètre conservés.';
COMMENT ON COLUMN logistique."V_AuditStock"."ID_DeviseFk" IS 'Référence de devise du catalogue article ; aucune conversion.';
COMMENT ON COLUMN logistique."V_AuditStock"."DeviseCode" IS 'Code monétaire du référentiel ; EURO est normalisé EUR.';
COMMENT ON COLUMN logistique."V_AuditStock"."DeviseLibelle" IS 'Libellé de la devise conservée dans le référentiel, y compris après désactivation.';

CREATE OR REPLACE VIEW logistique."V_AuditStock_Theorique" AS
 SELECT historique.*, source."ID_DeviseFk", logistique.fn_code_devise(devise."AbrGenerique") AS "DeviseCode",
        devise."NomGenerique"::text AS "DeviseLibelle"
 FROM (
 WITH mvt AS (
         SELECT v."ID_ArticleFk",
            sum(v."QteMvtSigned") AS stock_mouvement
           FROM logistique."V_MouvementStock" v
          GROUP BY v."ID_ArticleFk"
        )
 SELECT a."ID_Article",
    a."CodeArticleInterne",
    a."NomArticle",
    COALESCE(a."QteArticle", 0::numeric) AS "StockEnregistre",
    COALESCE(mvt.stock_mouvement, 0::numeric) AS "StockCalcule",
    COALESCE(a."QteArticle", 0::numeric) - COALESCE(mvt.stock_mouvement, 0::numeric) AS "Ecart",
    (COALESCE(a."QteArticle", 0::numeric) - COALESCE(mvt.stock_mouvement, 0::numeric)) = 0::numeric AS "EstStockCoherent"
   FROM logistique."T_Article" a
     LEFT JOIN mvt ON mvt."ID_ArticleFk" = a."ID_Article"
 ) historique
 LEFT JOIN logistique."T_Article" source ON source."ID_Article"=historique."ID_Article"
 LEFT JOIN referentiel."T_Generique" devise ON devise."ID_Generique"=source."ID_DeviseFk";
COMMENT ON VIEW logistique."V_AuditStock_Theorique" IS 'Rapprochement au grain article entre QteArticle courant et somme de V_MouvementStock.QteMvtSigned ; écart = stock enregistré moins stock calculé. Devise du catalogue article explicitée ; anciens grain et périmètre conservés.';
COMMENT ON COLUMN logistique."V_AuditStock_Theorique"."ID_DeviseFk" IS 'Référence de devise du catalogue article ; aucune conversion.';
COMMENT ON COLUMN logistique."V_AuditStock_Theorique"."DeviseCode" IS 'Code monétaire du référentiel ; EURO est normalisé EUR.';
COMMENT ON COLUMN logistique."V_AuditStock_Theorique"."DeviseLibelle" IS 'Libellé de la devise conservée dans le référentiel, y compris après désactivation.';

CREATE OR REPLACE VIEW logistique."V_AlertStock" AS
 SELECT historique.*, source."ID_DeviseFk", logistique.fn_code_devise(devise."AbrGenerique") AS "DeviseCode",
        devise."NomGenerique"::text AS "DeviseLibelle"
 FROM (
 SELECT "ID_Article",
    "CodeArticleInterne",
    "NomArticle",
    "AbrUnite",
    "QteArticle",
    "QteMinArticle",
    "QteACommander",
    (COALESCE("QteArticle", 0::numeric) - COALESCE("QteMinArticle", 0)::numeric)::numeric(14,3) AS "Marge",
    "EtatStock",
    "EstRupture",
    "EstAlerteStock",
    "PrioriteStock",
    "EtatPeremption",
    "JoursAvantPeremption",
    "EstPerime",
    "EstAlertePeremption"
   FROM logistique."V_Article" a
  WHERE "EstRupture" = true OR "EstAlerteStock" = true
 ) historique
 LEFT JOIN logistique."T_Article" source ON source."ID_Article"=historique."ID_Article"
 LEFT JOIN referentiel."T_Generique" devise ON devise."ID_Generique"=source."ID_DeviseFk";
COMMENT ON VIEW logistique."V_AlertStock" IS 'Articles en rupture ou au seuil minimal depuis V_Article, au grain article. Les ruptures sont incluses même sans seuil renseigné ; les autres alertes exigent le seuil défini dans V_Article. Devise du catalogue article explicitée ; anciens grain et périmètre conservés.';
COMMENT ON COLUMN logistique."V_AlertStock"."ID_DeviseFk" IS 'Référence de devise du catalogue article ; aucune conversion.';
COMMENT ON COLUMN logistique."V_AlertStock"."DeviseCode" IS 'Code monétaire du référentiel ; EURO est normalisé EUR.';
COMMENT ON COLUMN logistique."V_AlertStock"."DeviseLibelle" IS 'Libellé de la devise conservée dans le référentiel, y compris après désactivation.';

CREATE OR REPLACE VIEW logistique."V_CouvertureStock" AS
 SELECT historique.*, source."ID_DeviseFk", logistique.fn_code_devise(devise."AbrGenerique") AS "DeviseCode",
        devise."NomGenerique"::text AS "DeviseLibelle"
 FROM (
 WITH conso AS (
         SELECT v."ID_ArticleFk",
            sum(
                CASE
                    WHEN v."SigneStock" = '-1'::integer THEN COALESCE(v."QteMvt", 0)
                    ELSE 0
                END)::numeric AS conso_6m
           FROM logistique."V_MouvementStock" v
          WHERE v."DateMvt" >= (CURRENT_DATE - '6 mons'::interval) AND v."DateMvt" < (CURRENT_DATE + '1 day'::interval)
          GROUP BY v."ID_ArticleFk"
        )
 SELECT a."ID_Article",
    a."CodeArticleInterne",
    a."NomArticle",
    a."AbrUnite",
    a."QteArticle" AS "StockActuel",
    COALESCE(conso.conso_6m, 0::numeric) AS "Conso6Mois",
    round(COALESCE(conso.conso_6m, 0::numeric) / 6.0, 2) AS "ConsoMoyMensuelle",
        CASE
            WHEN COALESCE(conso.conso_6m, 0::numeric) = 0::numeric THEN NULL::numeric
            ELSE round(a."QteArticle" / NULLIF(conso.conso_6m / 6.0, 0::numeric), 1)
        END AS "CouvertureMois",
        CASE
            WHEN COALESCE(conso.conso_6m, 0::numeric) = 0::numeric THEN 'Aucune consommation récente'::text
            WHEN round(a."QteArticle" / NULLIF(conso.conso_6m / 6.0, 0::numeric), 1) < 1::numeric THEN 'Critique'::text
            WHEN round(a."QteArticle" / NULLIF(conso.conso_6m / 6.0, 0::numeric), 1) < 3::numeric THEN 'Faible'::text
            ELSE 'Correcte'::text
        END AS "EtatCouverture"
   FROM logistique."V_Article" a
     LEFT JOIN conso ON conso."ID_ArticleFk" = a."ID_Article"
 ) historique
 LEFT JOIN logistique."T_Article" source ON source."ID_Article"=historique."ID_Article"
 LEFT JOIN referentiel."T_Generique" devise ON devise."ID_Generique"=source."ID_DeviseFk";
COMMENT ON VIEW logistique."V_CouvertureStock" IS 'Couverture au grain article : sorties depuis CURRENT_DATE moins six mois et avant le lendemain de CURRENT_DATE. Moyenne divisée par six puis stock/moyenne ; les jours futurs sont exclus, NULL sans consommation. Devise du catalogue article explicitée ; anciens grain et périmètre conservés.';
COMMENT ON COLUMN logistique."V_CouvertureStock"."ID_DeviseFk" IS 'Référence de devise du catalogue article ; aucune conversion.';
COMMENT ON COLUMN logistique."V_CouvertureStock"."DeviseCode" IS 'Code monétaire du référentiel ; EURO est normalisé EUR.';
COMMENT ON COLUMN logistique."V_CouvertureStock"."DeviseLibelle" IS 'Libellé de la devise conservée dans le référentiel, y compris après désactivation.';

CREATE OR REPLACE VIEW logistique."V_CommandeOverview" AS
 SELECT historique.*, source."ID_DeviseFk", logistique.fn_code_devise(devise."AbrGenerique") AS "DeviseCode",
        devise."NomGenerique"::text AS "DeviseLibelle"
 FROM (
 SELECT "ID_Commande",
    "DateCmd",
    "CodeCmd",
    "ID_TypeCmdFk",
    "AbrTypeCmd",
    "TypeCmd",
    "ID_StatutCmdFk",
    "AbrStatutCmd",
    "StatutCmd",
    "ID_ClientFk",
    "NomClientSaisi",
    "MontantHT",
    "MontantTTC",
    "MontantRegleFacture",
    "MontantResteFacture",
    "EtatPaiement",
    "StatusFacture",
    "DateFacture",
    "CodeFacture",
    "DateEcheancePaiement",
    "NbLignes",
    "NbArticlesDistincts",
    "QteTotale",
    "MontantDetails",
    "ListeArticles",
    "EstCommandeSansDetails",
    "EstMontantIncoherent",
    "EtatControleCommande"
   FROM logistique."V_Commande" c
 ) historique
 LEFT JOIN logistique."T_Commande" source ON source."ID_Commande"=historique."ID_Commande"
 LEFT JOIN referentiel."T_Generique" devise ON devise."ID_Generique"=source."ID_DeviseFk";
COMMENT ON VIEW logistique."V_CommandeOverview" IS 'Projection synthétique de V_Commande, au même grain commande, pour le suivi des lignes, montants, facturation et états de contrôle. Devise du bon et de sa facture explicitée ; anciens grain et périmètre conservés.';
COMMENT ON COLUMN logistique."V_CommandeOverview"."ID_DeviseFk" IS 'Référence de devise du bon et de sa facture ; aucune conversion.';
COMMENT ON COLUMN logistique."V_CommandeOverview"."DeviseCode" IS 'Code monétaire du référentiel ; EURO est normalisé EUR.';
COMMENT ON COLUMN logistique."V_CommandeOverview"."DeviseLibelle" IS 'Libellé de la devise conservée dans le référentiel, y compris après désactivation.';

CREATE OR REPLACE VIEW logistique."V_CommandesSansDetails" AS
 SELECT historique.*, source."ID_DeviseFk", logistique.fn_code_devise(devise."AbrGenerique") AS "DeviseCode",
        devise."NomGenerique"::text AS "DeviseLibelle"
 FROM (
 SELECT c."ID_Commande",
    c."DateCmd",
    c."CodeCmd",
    c."ID_TypeCmdFk",
    type_cmd."AbrGenerique" AS "AbrTypeCmd",
    type_cmd."NomGenerique" AS "TypeCmd",
    c."NomClientSaisi",
    c."ObsCmd"
   FROM logistique."T_Commande" c
     LEFT JOIN logistique."T_CommandeDetail" d ON d."ID_CmdFk" = c."ID_Commande"
     LEFT JOIN referentiel."T_Generique" type_cmd ON c."ID_TypeCmdFk" = type_cmd."ID_Generique" AND type_cmd."ID_CategorieGeneriqueFk" = 64
  WHERE d."ID_CmdFk" IS NULL AND (COALESCE(c."CodeCmd", ''::character varying)::text <> ALL (ARRAY['C_000E'::character varying::text, 'C_000S'::character varying::text]))
 ) historique
 LEFT JOIN logistique."T_Commande" source ON source."ID_Commande"=historique."ID_Commande"
 LEFT JOIN referentiel."T_Generique" devise ON devise."ID_Generique"=source."ID_DeviseFk";
COMMENT ON VIEW logistique."V_CommandesSansDetails" IS 'Commandes sans aucune ligne dans T_CommandeDetail ; les références C_000E et C_000S sont exclues. Grain : commande. Devise du bon et de sa facture explicitée ; anciens grain et périmètre conservés.';
COMMENT ON COLUMN logistique."V_CommandesSansDetails"."ID_DeviseFk" IS 'Référence de devise du bon et de sa facture ; aucune conversion.';
COMMENT ON COLUMN logistique."V_CommandesSansDetails"."DeviseCode" IS 'Code monétaire du référentiel ; EURO est normalisé EUR.';
COMMENT ON COLUMN logistique."V_CommandesSansDetails"."DeviseLibelle" IS 'Libellé de la devise conservée dans le référentiel, y compris après désactivation.';

CREATE OR REPLACE VIEW logistique."V_LotArticleStock" AS
 SELECT historique.*, source."ID_DeviseFk", logistique.fn_code_devise(devise."AbrGenerique") AS "DeviseCode",
        devise."NomGenerique"::text AS "DeviseLibelle"
 FROM (
 SELECT l."ID_LotArticle",
    l."ID_ArticleFk",
    l."NumeroLot",
    l."DatePeremptionLot",
    l."Actif",
    l."CreeLe",
    COALESCE(sum(ml."Quantite" * m."SigneStock"), 0::bigint)::numeric AS "StockLot",
    COALESCE(sum(ml."Quantite") FILTER (WHERE m."SigneStock" = 1), 0::bigint)::numeric AS "QuantiteEntree",
    COALESCE(sum(ml."Quantite") FILTER (WHERE m."SigneStock" = '-1'::integer), 0::bigint)::numeric AS "QuantiteSortie"
   FROM logistique."T_LotArticle" l
     LEFT JOIN logistique."T_MouvementLot" ml ON ml."ID_LotArticleFk" = l."ID_LotArticle"
     LEFT JOIN logistique."V_MouvementStock" m ON m."ID_Mvt" = ml."ID_MvtFk"
  GROUP BY l."ID_LotArticle"
 ) historique
 LEFT JOIN logistique."T_Article" source ON source."ID_Article"=historique."ID_ArticleFk"
 LEFT JOIN referentiel."T_Generique" devise ON devise."ID_Generique"=source."ID_DeviseFk";
COMMENT ON VIEW logistique."V_LotArticleStock" IS 'Stock signé par lot issu exclusivement de la ventilation des mouvements existants. Devise du catalogue article explicitée ; anciens grain et périmètre conservés.';
COMMENT ON COLUMN logistique."V_LotArticleStock"."ID_DeviseFk" IS 'Référence de devise du catalogue article ; aucune conversion.';
COMMENT ON COLUMN logistique."V_LotArticleStock"."DeviseCode" IS 'Code monétaire du référentiel ; EURO est normalisé EUR.';
COMMENT ON COLUMN logistique."V_LotArticleStock"."DeviseLibelle" IS 'Libellé de la devise conservée dans le référentiel, y compris après désactivation.';

CREATE OR REPLACE VIEW logistique."V_MouvementLot" AS
 SELECT historique.*, source."ID_DeviseFk", logistique.fn_code_devise(devise."AbrGenerique") AS "DeviseCode",
        devise."NomGenerique"::text AS "DeviseLibelle"
 FROM (
 SELECT ml."ID_MvtFk",
    ml."ID_LotArticleFk",
    l."ID_ArticleFk",
    l."NumeroLot",
    l."DatePeremptionLot",
    ml."Quantite",
    m."DateMvt",
    m."ID_cmdFk",
    m."SigneStock",
    (ml."Quantite" * m."SigneStock")::numeric AS "QuantiteSignee",
    m."NomArticle",
    m."CodeCmd"
   FROM logistique."T_MouvementLot" ml
     JOIN logistique."T_LotArticle" l ON l."ID_LotArticle" = ml."ID_LotArticleFk"
     JOIN logistique."V_MouvementStock" m ON m."ID_Mvt" = ml."ID_MvtFk"
 ) historique
 LEFT JOIN logistique."T_Mouvement" source ON source."ID_Mvt"=historique."ID_MvtFk"
 LEFT JOIN referentiel."T_Generique" devise ON devise."ID_Generique"=source."ID_DeviseFk";
COMMENT ON VIEW logistique."V_MouvementLot" IS 'Traçabilité des numéros de lot par mouvement et bon de stock. Devise du mouvement historique explicitée ; anciens grain et périmètre conservés.';
COMMENT ON COLUMN logistique."V_MouvementLot"."ID_DeviseFk" IS 'Référence de devise du mouvement historique ; aucune conversion.';
COMMENT ON COLUMN logistique."V_MouvementLot"."DeviseCode" IS 'Code monétaire du référentiel ; EURO est normalisé EUR.';
COMMENT ON COLUMN logistique."V_MouvementLot"."DeviseLibelle" IS 'Libellé de la devise conservée dans le référentiel, y compris après désactivation.';

CREATE VIEW logistique."V_Reglements" AS
 SELECT r."ID_Reglement",r."CodeFactureFk",r."ID_ModeReglementFk",r."ID_ClientFk",r."DateReglement",r."MontantRegle",
 r."ID_DeviseFk",logistique.fn_code_devise(g."AbrGenerique") AS "DeviseCode",g."NomGenerique"::text AS "DeviseLibelle"
 FROM logistique."T_Reglements" r LEFT JOIN referentiel."T_Generique" g ON g."ID_Generique"=r."ID_DeviseFk";
COMMENT ON VIEW logistique."V_Reglements" IS 'Écritures unitaires de règlement avec devise historique de la facture ; le service impose utilisateur, organisation et facture autorisés.';
COMMENT ON COLUMN logistique."V_Reglements"."ID_Reglement" IS 'Identifiant unique du règlement.';
COMMENT ON COLUMN logistique."V_Reglements"."CodeFactureFk" IS 'Référence unique de la facture du bon source.';
COMMENT ON COLUMN logistique."V_Reglements"."ID_ModeReglementFk" IS 'Mode de paiement validé par la logique métier existante.';
COMMENT ON COLUMN logistique."V_Reglements"."ID_ClientFk" IS 'Client rattaché au règlement.';
COMMENT ON COLUMN logistique."V_Reglements"."DateReglement" IS 'Horodatage métier du règlement, sans fuseau dans le modèle existant.';
COMMENT ON COLUMN logistique."V_Reglements"."MontantRegle" IS 'Montant exact dans la devise de la facture ; aucune conversion.';
COMMENT ON COLUMN logistique."V_Reglements"."ID_DeviseFk" IS 'Référence de devise du règlement historique ; aucune conversion.';
COMMENT ON COLUMN logistique."V_Reglements"."DeviseCode" IS 'Code monétaire du référentiel ; EURO est normalisé EUR.';
COMMENT ON COLUMN logistique."V_Reglements"."DeviseLibelle" IS 'Libellé de la devise conservée dans le référentiel, y compris après désactivation.';
-- Projection fine pour filtrer les flux par devise, sans modifier le grain de la vue historique.
CREATE VIEW logistique."V_ConsoMensuelleDevise" AS
 SELECT v."ID_ArticleFk" AS "ID_Article",v."NomArticle",date_trunc('month',v."DateMvt")::date AS "Mois",
 sum(CASE WHEN v."SigneStock"=-1 THEN coalesce(v."QteMvt",0) ELSE 0 END)::numeric AS "ConsoMensuelle",
 sum(CASE WHEN v."SigneStock"=-1 THEN coalesce(v."MontantMvt",0) ELSE 0 END)::numeric(14,2) AS "ValeurConsoMensuelle",
 v."ID_DeviseFk",v."DeviseCode",v."DeviseLibelle",
 jsonb_build_array(jsonb_build_object('id',v."ID_DeviseFk",'code',v."DeviseCode",'label',v."DeviseLibelle",
  'value',sum(CASE WHEN v."SigneStock"=-1 THEN coalesce(v."MontantMvt",0) ELSE 0 END)::numeric(14,2)::text,
  'count',count(*) FILTER (WHERE v."SigneStock"=-1))) AS "MontantsParDevise"
 FROM logistique."V_MouvementStock" v WHERE v."DateMvt" IS NOT NULL
 GROUP BY v."ID_ArticleFk",v."NomArticle",date_trunc('month',v."DateMvt")::date,v."ID_DeviseFk",v."DeviseCode",v."DeviseLibelle";

CREATE OR REPLACE VIEW logistique."V_ConsoMensuelle" AS
 SELECT d."ID_Article",d."NomArticle",d."Mois",sum(d."ConsoMensuelle")::numeric AS "ConsoMensuelle",
 CASE WHEN count(*)=1 THEN min(d."ValeurConsoMensuelle") ELSE NULL END::numeric(14,2) AS "ValeurConsoMensuelle",
 CASE WHEN count(*)=1 THEN min(d."ID_DeviseFk") ELSE NULL END AS "ID_DeviseFk",
 CASE WHEN count(*)=1 THEN min(d."DeviseCode") ELSE NULL END AS "DeviseCode",
 CASE WHEN count(*)=1 THEN min(d."DeviseLibelle") ELSE NULL END AS "DeviseLibelle",
 jsonb_agg(d."MontantsParDevise"->0 ORDER BY d."DeviseCode",d."ID_DeviseFk") AS "MontantsParDevise"
 FROM logistique."V_ConsoMensuelleDevise" d GROUP BY d."ID_Article",d."NomArticle",d."Mois";
COMMENT ON VIEW logistique."V_ConsoMensuelleDevise" IS 'Consommation au grain article/mois/devise historique des mouvements ; source des filtres par devise, sans changement de quantité ni conversion.';
COMMENT ON VIEW logistique."V_ConsoMensuelle" IS 'Consommation au grain historique article/mois : quantités toutes devises, valeur scalaire NULL si plusieurs devises ; répartition exacte dans MontantsParDevise. Un filtre devise doit employer V_ConsoMensuelleDevise.';
COMMENT ON COLUMN logistique."V_ConsoMensuelleDevise"."ID_DeviseFk" IS 'Référence de devise des mouvements du mois ; aucune conversion.';
COMMENT ON COLUMN logistique."V_ConsoMensuelleDevise"."DeviseCode" IS 'Code monétaire du référentiel ; EURO est normalisé EUR.';
COMMENT ON COLUMN logistique."V_ConsoMensuelleDevise"."DeviseLibelle" IS 'Libellé de la devise conservée dans le référentiel, y compris après désactivation.';
COMMENT ON COLUMN logistique."V_ConsoMensuelleDevise"."ID_Article" IS 'Article commun aux mouvements de consommation.';
COMMENT ON COLUMN logistique."V_ConsoMensuelleDevise"."NomArticle" IS 'Nom du catalogue article, sans filtrage métier supplémentaire.';
COMMENT ON COLUMN logistique."V_ConsoMensuelleDevise"."Mois" IS 'Premier jour du mois de DateMvt ; les dates absentes sont exclues.';
COMMENT ON COLUMN logistique."V_ConsoMensuelleDevise"."ConsoMensuelle" IS 'Somme des quantités de sortie, dans l’unité de stock de cet article.';
COMMENT ON COLUMN logistique."V_ConsoMensuelleDevise"."ValeurConsoMensuelle" IS 'Valeur des sorties dans la devise indiquée ; NULL si plusieurs devises au grain article/mois. Aucune conversion.';
COMMENT ON COLUMN logistique."V_ConsoMensuelleDevise"."MontantsParDevise" IS 'Tableau JSON de {id,code,label,value,count} ; value est une chaîne décimale exacte, count le nombre de mouvements de sortie. Ne jamais sommer les devises.';
COMMENT ON COLUMN logistique."V_ConsoMensuelle"."ID_DeviseFk" IS 'Référence de devise des sorties historiques ; NULL scalaire si plusieurs devises dans le mois ; aucune conversion.';
COMMENT ON COLUMN logistique."V_ConsoMensuelle"."DeviseCode" IS 'Code monétaire du référentiel ; EURO est normalisé EUR.';
COMMENT ON COLUMN logistique."V_ConsoMensuelle"."DeviseLibelle" IS 'Libellé de la devise conservée dans le référentiel, y compris après désactivation.';
COMMENT ON COLUMN logistique."V_ConsoMensuelle"."ID_Article" IS 'Article commun aux mouvements de consommation.';
COMMENT ON COLUMN logistique."V_ConsoMensuelle"."NomArticle" IS 'Nom du catalogue article, sans filtrage métier supplémentaire.';
COMMENT ON COLUMN logistique."V_ConsoMensuelle"."Mois" IS 'Premier jour du mois de DateMvt ; les dates absentes sont exclues.';
COMMENT ON COLUMN logistique."V_ConsoMensuelle"."ConsoMensuelle" IS 'Somme des quantités de sortie, dans l’unité de stock de cet article.';
COMMENT ON COLUMN logistique."V_ConsoMensuelle"."ValeurConsoMensuelle" IS 'Valeur des sorties dans la devise indiquée ; NULL si plusieurs devises au grain article/mois. Aucune conversion.';
COMMENT ON COLUMN logistique."V_ConsoMensuelle"."MontantsParDevise" IS 'Tableau JSON de {id,code,label,value,count} ; value est une chaîne décimale exacte, count le nombre de mouvements de sortie. Ne jamais sommer les devises.';
-- Aucun UPDATE de données historiques : preuve des lignes, dates, prix et stocks inchangés.
DO $verification$
DECLARE t text; avant record; lignes_apres bigint; empreinte_apres text; usd integer;
BEGIN
 usd := logistique.fn_devise_usd();
 FOREACH t IN ARRAY ARRAY['T_Article','T_Commande','T_Mouvement','T_Reglements'] LOOP
  SELECT * INTO STRICT avant FROM migration_devises_before WHERE objet=t;
  EXECUTE format('SELECT count(*),md5(coalesce(string_agg(md5((to_jsonb(x)-%L)::text),%L ORDER BY (to_jsonb(x)-%L)::text),%L)) FROM logistique.%I x','ID_DeviseFk','','ID_DeviseFk','',t)
   INTO lignes_apres,empreinte_apres;
  IF avant.lignes IS DISTINCT FROM lignes_apres OR avant.empreinte IS DISTINCT FROM empreinte_apres THEN
   RAISE EXCEPTION 'Intégrité historique altérée sur % : transaction annulée.',t;
  END IF;
  EXECUTE format('SELECT count(*) FROM logistique.%I WHERE "ID_DeviseFk" IS DISTINCT FROM $1',t) INTO lignes_apres USING usd;
  IF lignes_apres<>0 THEN RAISE EXCEPTION 'Rattachement USD historique incomplet sur %.',t; END IF;
 END LOOP;
 IF EXISTS (SELECT 1 FROM logistique."V_ConsoMensuelle" GROUP BY "ID_Article","Mois" HAVING count(*)>1) THEN
  RAISE EXCEPTION 'Le grain article/mois de consommation a changé.';
 END IF;
END;
$verification$;
COMMIT;
