-- Lectures logistiques et facturation compatibles avec les familles configurees.
-- Evolution distincte du socle30_01 ; aucune ecriture de donnees.
BEGIN;
SET LOCAL lock_timeout='10s';
SET LOCAL statement_timeout='120s';
DO $guard$ BEGIN
 IF current_database()<>'SauverNdeko' AND current_database() NOT LIKE 'sauverndeko_test_%' THEN RAISE EXCEPTION 'Base non autorisee';END IF;
 IF to_regprocedure('referentiel.fn_reference_visible(integer,integer)') IS NULL OR position('ID_CategorieGeneriqueFk' IN pg_get_viewdef('logistique."V_MouvementStock"'::regclass,true))=0 THEN
  RAISE EXCEPTION 'Socle30_01 requis ou correction deja installee';END IF;
END $guard$;

CREATE OR REPLACE VIEW logistique."V_Article" AS
 SELECT source."ID_Article",
    source."DateHeureAuto",
    source."CodeArticleInterne",
    source."CodeArticleExterne",
    source."NomArticle",
    source."RefArticle",
    source."PhotoArticle",
    source."ObsArticle",
    source."ValideArticle",
    source."ID_TypeArticleFk",
    source."AbrTypeArticle",
    source."TypeArticle",
    source."ID_CategorieArticleFk",
    source."AbrCategorieArticle",
    source."CategorieArticle",
    source."ID_UniteFk",
    source."AbrUnite",
    source."Unite",
    source."QteArticle",
    source."QteMinArticle",
    source."QteACommander",
    source."EtatStock",
    source."EstRupture",
    source."EstAlerteStock",
    source."PrioriteStock",
    source."PUArticle",
    source."PVArticle",
    source."ValeurStockAchat",
    source."ValeurStockVente",
    source."MargeUnitaire",
    source."TauxMargePct",
    source."DatePeremptionArticle",
    source."DatePeremptionAlerteArticle",
    source."NbreJoursAlerteArticle",
    p."EtatPeremption",
    p."JoursAvantPeremption",
    p."EstPerime",
    p."EstAlertePeremption",
    p."PrioritePeremption",
    source."ID_UserFK",
    source."IdUser",
    source."NomComplet",
    source."EtatArticle",
    source."PoidsUnitaire",
    source."ID_UnitePoidsFk",
    source."UnitePoids",
    source."NombreLots",
    source."StockVentileLots",
    source."StockSansLot",
    source."InformationArticle",
    source."ID_DeviseFk",
    source."DeviseCode",
    source."DeviseLibelle",
    source."IdEntiteFk",
    p."StockPerime",
    p."StockProchePeremption",
    p."StockSansDatePeremption",
    p."DateProchainePeremption",
    p."LotsPerimes",
    p."LotsProchesPeremption",
    p."SeuilAlerteJours"
   FROM (( SELECT source_1."ID_Article",
            source_1."DateHeureAuto",
            source_1."CodeArticleInterne",
            source_1."CodeArticleExterne",
            source_1."NomArticle",
            source_1."RefArticle",
            source_1."PhotoArticle",
            source_1."ObsArticle",
            source_1."ValideArticle",
            source_1."ID_TypeArticleFk",
            source_1."AbrTypeArticle",
            source_1."TypeArticle",
            source_1."ID_CategorieArticleFk",
            source_1."AbrCategorieArticle",
            source_1."CategorieArticle",
            source_1."ID_UniteFk",
            source_1."AbrUnite",
            source_1."Unite",
            source_1."QteArticle",
            source_1."QteMinArticle",
            source_1."QteACommander",
            source_1."EtatStock",
            source_1."EstRupture",
            source_1."EstAlerteStock",
            source_1."PrioriteStock",
            source_1."PUArticle",
            source_1."PVArticle",
            source_1."ValeurStockAchat",
            source_1."ValeurStockVente",
            source_1."MargeUnitaire",
            source_1."TauxMargePct",
            source_1."DatePeremptionArticle",
            source_1."DatePeremptionAlerteArticle",
            source_1."NbreJoursAlerteArticle",
            source_1."EtatPeremption",
            source_1."JoursAvantPeremption",
            source_1."EstPerime",
            source_1."EstAlertePeremption",
            source_1."PrioritePeremption",
            source_1."ID_UserFK",
            source_1."IdUser",
            source_1."NomComplet",
            source_1."EtatArticle",
            source_1."PoidsUnitaire",
            source_1."ID_UnitePoidsFk",
            source_1."UnitePoids",
            source_1."NombreLots",
            source_1."StockVentileLots",
            source_1."StockSansLot",
            source_1."InformationArticle",
            source_1."ID_DeviseFk",
            source_1."DeviseCode",
            source_1."DeviseLibelle",
            r."IdEntiteFk"
           FROM (( SELECT historique."ID_Article",
                    historique."DateHeureAuto",
                    historique."CodeArticleInterne",
                    historique."CodeArticleExterne",
                    historique."NomArticle",
                    historique."RefArticle",
                    historique."PhotoArticle",
                    historique."ObsArticle",
                    historique."ValideArticle",
                    historique."ID_TypeArticleFk",
                    historique."AbrTypeArticle",
                    historique."TypeArticle",
                    historique."ID_CategorieArticleFk",
                    historique."AbrCategorieArticle",
                    historique."CategorieArticle",
                    historique."ID_UniteFk",
                    historique."AbrUnite",
                    historique."Unite",
                    historique."QteArticle",
                    historique."QteMinArticle",
                    historique."QteACommander",
                    historique."EtatStock",
                    historique."EstRupture",
                    historique."EstAlerteStock",
                    historique."PrioriteStock",
                    historique."PUArticle",
                    historique."PVArticle",
                    historique."ValeurStockAchat",
                    historique."ValeurStockVente",
                    historique."MargeUnitaire",
                    historique."TauxMargePct",
                    historique."DatePeremptionArticle",
                    historique."DatePeremptionAlerteArticle",
                    historique."NbreJoursAlerteArticle",
                    historique."EtatPeremption",
                    historique."JoursAvantPeremption",
                    historique."EstPerime",
                    historique."EstAlertePeremption",
                    historique."PrioritePeremption",
                    historique."ID_UserFK",
                    historique."IdUser",
                    historique."NomComplet",
                    historique."EtatArticle",
                    historique."PoidsUnitaire",
                    historique."ID_UnitePoidsFk",
                    historique."UnitePoids",
                    historique."NombreLots",
                    historique."StockVentileLots",
                    historique."StockSansLot",
                    historique."InformationArticle",
                    source_1_1."ID_DeviseFk",
                    logistique.fn_code_devise((devise."AbrGenerique")::text) AS "DeviseCode",
                    (devise."NomGenerique")::text AS "DeviseLibelle"
                   FROM ((( SELECT a."ID_Article",
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
                            (COALESCE(a."QteArticle", (0)::numeric))::numeric(14,3) AS "QteArticle",
                            a."QteMinArticle",
                            (GREATEST((COALESCE(a."QteMinArticle", (0)::numeric) - COALESCE(a."QteArticle", (0)::numeric)), (0)::numeric))::numeric(14,3) AS "QteACommander",
                                CASE
                                    WHEN (COALESCE(a."QteArticle", (0)::numeric) <= (0)::numeric) THEN 'Rupture'::text
                                    WHEN ((a."QteMinArticle" IS NOT NULL) AND (COALESCE(a."QteArticle", (0)::numeric) <= (a."QteMinArticle")::numeric)) THEN 'Stock faible'::text
                                    ELSE 'Disponible'::text
                                END AS "EtatStock",
                            (COALESCE(a."QteArticle", (0)::numeric) <= (0)::numeric) AS "EstRupture",
                            ((a."QteMinArticle" IS NOT NULL) AND (COALESCE(a."QteArticle", (0)::numeric) <= (a."QteMinArticle")::numeric)) AS "EstAlerteStock",
                                CASE
                                    WHEN (COALESCE(a."QteArticle", (0)::numeric) <= (0)::numeric) THEN 1
                                    WHEN ((a."QteMinArticle" IS NOT NULL) AND (COALESCE(a."QteArticle", (0)::numeric) <= (a."QteMinArticle")::numeric)) THEN 2
                                    ELSE 3
                                END AS "PrioriteStock",
                            (COALESCE(a."PUArticle", (0)::numeric))::numeric(12,2) AS "PUArticle",
                            (COALESCE(a."PVArticle", (0)::numeric))::numeric(12,2) AS "PVArticle",
                            ((COALESCE(a."QteArticle", (0)::numeric) * COALESCE(a."PUArticle", (0)::numeric)))::numeric(14,2) AS "ValeurStockAchat",
                            ((COALESCE(a."QteArticle", (0)::numeric) * COALESCE(a."PVArticle", (0)::numeric)))::numeric(14,2) AS "ValeurStockVente",
                            ((COALESCE(a."PVArticle", (0)::numeric) - COALESCE(a."PUArticle", (0)::numeric)))::numeric(12,2) AS "MargeUnitaire",
                                CASE
                                    WHEN (COALESCE(a."PUArticle", (0)::numeric) = (0)::numeric) THEN NULL::numeric
                                    ELSE round((((COALESCE(a."PVArticle", (0)::numeric) - COALESCE(a."PUArticle", (0)::numeric)) / NULLIF(a."PUArticle", (0)::numeric)) * (100)::numeric), 2)
                                END AS "TauxMargePct",
                            a."DatePeremptionArticle",
                            a."DatePeremptionAlerteArticle",
                            a."NbreJoursAlerteArticle",
                                CASE
                                    WHEN (a."DatePeremptionArticle" IS NULL) THEN 'Non renseignée'::text
                                    WHEN ((a."DatePeremptionArticle")::date < CURRENT_DATE) THEN 'Périmé'::text
                                    WHEN ((a."DatePeremptionAlerteArticle" IS NOT NULL) AND ((a."DatePeremptionAlerteArticle")::date <= CURRENT_DATE)) THEN 'Alerte péremption'::text
                                    WHEN ((a."NbreJoursAlerteArticle" IS NOT NULL) AND ((a."DatePeremptionArticle")::date <= (CURRENT_DATE + a."NbreJoursAlerteArticle"))) THEN 'Alerte péremption'::text
                                    ELSE 'Valide'::text
                                END AS "EtatPeremption",
                                CASE
                                    WHEN (a."DatePeremptionArticle" IS NOT NULL) THEN ((a."DatePeremptionArticle")::date - CURRENT_DATE)
                                    ELSE NULL::integer
                                END AS "JoursAvantPeremption",
                            ((a."DatePeremptionArticle" IS NOT NULL) AND ((a."DatePeremptionArticle")::date < CURRENT_DATE)) AS "EstPerime",
                            ((a."DatePeremptionArticle" IS NOT NULL) AND ((a."DatePeremptionArticle")::date >= CURRENT_DATE) AND (((a."DatePeremptionAlerteArticle" IS NOT NULL) AND ((a."DatePeremptionAlerteArticle")::date <= CURRENT_DATE)) OR ((a."NbreJoursAlerteArticle" IS NOT NULL) AND ((a."DatePeremptionArticle")::date <= (CURRENT_DATE + a."NbreJoursAlerteArticle"))))) AS "EstAlertePeremption",
                                CASE
                                    WHEN (a."DatePeremptionArticle" IS NULL) THEN 4
                                    WHEN ((a."DatePeremptionArticle")::date < CURRENT_DATE) THEN 1
                                    WHEN (((a."DatePeremptionAlerteArticle" IS NOT NULL) AND ((a."DatePeremptionAlerteArticle")::date <= CURRENT_DATE)) OR ((a."NbreJoursAlerteArticle" IS NOT NULL) AND ((a."DatePeremptionArticle")::date <= (CURRENT_DATE + a."NbreJoursAlerteArticle")))) THEN 2
                                    ELSE 3
                                END AS "PrioritePeremption",
                            a."ID_UserFK",
                            u."IdUser",
                            NULLIF(TRIM(BOTH FROM concat(COALESCE(u."PrenomUser", ''::character varying), ' ', COALESCE(u."NomUser", ''::character varying))), ''::text) AS "NomComplet",
                                CASE
                                    WHEN (COALESCE(a."ValideArticle", true) = false) THEN 'Inactif'::text
                                    ELSE 'Actif'::text
                                END AS "EtatArticle",
                            a."PoidsUnitaire",
                            a."ID_UnitePoidsFk",
                            ( SELECT g."AbrGenerique"
                                   FROM referentiel."T_Generique" g
                                  WHERE (g."ID_Generique" = a."ID_UnitePoidsFk")) AS "UnitePoids",
                            ( SELECT (count(*))::integer AS count
                                   FROM logistique."T_LotArticle" l
                                  WHERE (l."ID_ArticleFk" = a."ID_Article")) AS "NombreLots",
                            ( SELECT COALESCE(sum(l."StockLot"), (0)::numeric) AS "coalesce"
                                   FROM logistique."V_LotArticleStock" l
                                  WHERE (l."ID_ArticleFk" = a."ID_Article")) AS "StockVentileLots",
                            (a."QteArticle" - ( SELECT COALESCE(sum(l."StockLot"), (0)::numeric) AS "coalesce"
                                   FROM logistique."V_LotArticleStock" l
                                  WHERE (l."ID_ArticleFk" = a."ID_Article"))) AS "StockSansLot",
                            a."InformationArticle"
                           FROM ((((logistique."T_Article" a
                             LEFT JOIN referentiel."T_Generique" type_article ON (((a."ID_TypeArticleFk" = type_article."ID_Generique"))))
                             LEFT JOIN referentiel."T_Generique" categorie_article ON (((a."ID_CategorieArticleFk" = categorie_article."ID_Generique"))))
                             LEFT JOIN referentiel."T_Generique" unite ON (((a."ID_UniteFk" = unite."ID_Generique"))))
                             LEFT JOIN systeme."T_Utilisateurs" u ON ((a."ID_UserFK" = u."IdUser")))) historique
                     LEFT JOIN logistique."T_Article" source_1_1 ON ((source_1_1."ID_Article" = historique."ID_Article")))
                     LEFT JOIN referentiel."T_Generique" devise ON ((devise."ID_Generique" = source_1_1."ID_DeviseFk")))) source_1
             LEFT JOIN logistique."T_Article" r ON ((r."ID_Article" = source_1."ID_Article")))) source
     JOIN logistique."V_ArticlePeremption" p ON ((p."ID_Article" = source."ID_Article")));

COMMENT ON VIEW logistique."V_Article" IS 'Lecture historique par les identifiants exacts des references stockees, sans filtre numerique de famille. Les nouvelles selections restent validees par le catalogue physique ; les identifiants et colonnes de la vue sont conserves.';

COMMENT ON COLUMN logistique."V_Article"."AbrTypeArticle" IS 'Libelle ou abbreviation du seul ID_Generique enregistre ; conserve sa lecture lors du changement de categorie configuree.';

COMMENT ON COLUMN logistique."V_Article"."TypeArticle" IS 'Libelle ou abbreviation du seul ID_Generique enregistre ; conserve sa lecture lors du changement de categorie configuree.';

COMMENT ON COLUMN logistique."V_Article"."AbrCategorieArticle" IS 'Libelle ou abbreviation du seul ID_Generique enregistre ; conserve sa lecture lors du changement de categorie configuree.';

COMMENT ON COLUMN logistique."V_Article"."CategorieArticle" IS 'Libelle ou abbreviation du seul ID_Generique enregistre ; conserve sa lecture lors du changement de categorie configuree.';

COMMENT ON COLUMN logistique."V_Article"."AbrUnite" IS 'Libelle ou abbreviation du seul ID_Generique enregistre ; conserve sa lecture lors du changement de categorie configuree.';

COMMENT ON COLUMN logistique."V_Article"."Unite" IS 'Libelle ou abbreviation du seul ID_Generique enregistre ; conserve sa lecture lors du changement de categorie configuree.';

CREATE OR REPLACE VIEW logistique."V_Commande" AS
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
   FROM (( SELECT source_1."ID_Commande",
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
            (
                CASE
                    WHEN (logistique.fn_nature_bon(source_1."ID_TypeCmdFk") = 'commande'::text) THEN NULL::numeric
                    ELSE source_1."MontantRegleFactureCalc"
                END)::numeric(12,2) AS "MontantRegleFactureCalc",
            (
                CASE
                    WHEN (logistique.fn_nature_bon(source_1."ID_TypeCmdFk") = 'commande'::text) THEN NULL::numeric
                    ELSE source_1."MontantResteFactureCalc"
                END)::numeric(12,2) AS "MontantResteFactureCalc",
            (
                CASE
                    WHEN (logistique.fn_nature_bon(source_1."ID_TypeCmdFk") = 'commande'::text) THEN NULL::numeric
                    ELSE source_1."TotalRegleReel"
                END)::numeric(12,2) AS "TotalRegleReel",
            (
                CASE
                    WHEN (logistique.fn_nature_bon(source_1."ID_TypeCmdFk") = 'commande'::text) THEN NULL::numeric
                    ELSE source_1."ResteReel"
                END)::numeric(12,2) AS "ResteReel",
            source_1."NbReglements",
            source_1."DernierReglement",
                CASE
                    WHEN (logistique.fn_nature_bon(source_1."ID_TypeCmdFk") = 'commande'::text) THEN 'Sans facturation'::text
                    ELSE source_1."EtatPaiement"
                END AS "EtatPaiement",
                CASE
                    WHEN (logistique.fn_nature_bon(source_1."ID_TypeCmdFk") = 'commande'::text) THEN false
                    ELSE source_1."EstPaiementEnRetard"
                END AS "EstPaiementEnRetard",
                CASE
                    WHEN (logistique.fn_nature_bon(source_1."ID_TypeCmdFk") = 'commande'::text) THEN NULL::integer
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
                   FROM (( SELECT b."ID_Commande",
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
                            (pending.amount)::numeric(12,2) AS "MontantAvoirAEtablir",
                            (pending.amount > (0)::numeric) AS "AvoirAEtablir",
                            b."IdEntiteFk",
                            b."ID_TiersFk",
                            b."TiersNom",
                            b."ID_DestinationFk",
                            b."DestinationLibelle",
                            (COALESCE(cr.total, (0)::numeric))::numeric(12,2) AS "AvoirImpute"
                           FROM ((( SELECT s."ID_Commande",
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
                                   FROM ((( SELECT source_1_1_1."ID_Commande",
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
   FROM ((( SELECT base."ID_Commande",
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
      (f."ID_Facture" IS NOT NULL) AS "EstFactureSnapshot",
      (
    CASE
     WHEN (NULLIF(btrim((base."CodeFacture")::text), ''::text) IS NOT NULL) THEN COALESCE(f."MontantTTC", base."MontantTTC")
     ELSE NULL::numeric
    END)::numeric(12,2) AS "MontantFacture",
      (COALESCE(f."MontantAvoirAEtablir", (0)::numeric))::numeric(12,2) AS "MontantAvoirAEtablir",
      COALESCE(f."AvoirAEtablir", false) AS "AvoirAEtablir"
     FROM (( SELECT historique."ID_Commande",
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
        logistique.fn_code_devise((devise."AbrGenerique")::text) AS "DeviseCode",
        (devise."NomGenerique")::text AS "DeviseLibelle"
       FROM ((( WITH cd_stats AS (
         SELECT cd."ID_CmdFk",
            (count(*))::integer AS "NbLignes",
            (count(DISTINCT cd."ID_ArticleFk"))::integer AS "NbArticlesDistincts",
            (COALESCE(sum(COALESCE(cd."QteCmdDetail", (0)::numeric)), (0)::numeric))::numeric(14,3) AS "QteTotale",
            (COALESCE(sum(round((COALESCE(cd."QteCmdDetail", (0)::numeric) * COALESCE(cd."PUCmdDetail", (0)::numeric)), 2)), (0)::numeric))::numeric(12,2) AS "MontantDetails",
            string_agg(DISTINCT (a."NomArticle")::text, ', '::text ORDER BY (a."NomArticle")::text) AS "ListeArticles"
           FROM (logistique."T_CommandeDetail" cd
             LEFT JOIN logistique."T_Article" a ON ((a."ID_Article" = cd."ID_ArticleFk")))
          GROUP BY cd."ID_CmdFk"
        ), reg_stats AS (
         SELECT r_1."CodeFactureFk",
            (COALESCE(sum(COALESCE(r_1."MontantRegle", (0)::numeric)), (0)::numeric))::numeric(12,2) AS "TotalRegleReel",
            (count(*))::integer AS "NbReglements",
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
         WHEN ((type_cmd."AbrGenerique")::text ~~* 'entr%'::text) THEN 1
         WHEN ((type_cmd."AbrGenerique")::text ~~* 'sort%'::text) THEN '-1'::integer
         ELSE 0
        END AS "SigneCommande",
          COALESCE(((type_cmd."AbrGenerique")::text ~~* 'entr%'::text), false) AS "EstCommandeEntree",
          COALESCE(((type_cmd."AbrGenerique")::text ~~* 'sort%'::text), false) AS "EstCommandeSortie",
          statut_cmd."AbrGenerique" AS "AbrStatutCmd",
          statut_cmd."NomGenerique" AS "StatutCmd",
          u."NomUser",
          u."PrenomUser",
          NULLIF(TRIM(BOTH FROM concat(COALESCE(u."PrenomUser", ''::character varying), ' ', COALESCE(u."NomUser", ''::character varying))), ''::text) AS "NomComplet",
          condition_paiement."AbrGenerique" AS "AbrConditionPaiement",
          condition_paiement."NomGenerique" AS "ConditionPaiement",
          mode_paiement."AbrGenerique" AS "AbrModePaiement",
          mode_paiement."NomGenerique" AS "ModePaiement",
          (COALESCE(c_1_1."MontantHT", (0)::numeric))::numeric(12,2) AS "MontantHTCalc",
          (COALESCE(c_1_1."MontantTTC", (0)::numeric))::numeric(12,2) AS "MontantTTCCalc",
          (COALESCE(c_1_1."MontantRegleFacture", (0)::numeric))::numeric(12,2) AS "MontantRegleFactureCalc",
          (COALESCE(c_1_1."MontantResteFacture", (0)::numeric))::numeric(12,2) AS "MontantResteFactureCalc",
          (COALESCE(reg_stats."TotalRegleReel", (0)::numeric))::numeric(12,2) AS "TotalRegleReel",
          ((COALESCE(c_1_1."MontantTTC", (0)::numeric) - COALESCE(reg_stats."TotalRegleReel", (0)::numeric)))::numeric(12,2) AS "ResteReel",
          COALESCE(reg_stats."NbReglements", 0) AS "NbReglements",
          reg_stats."DernierReglement",
        CASE
         WHEN (c_1_1."CodeFacture" IS NULL) THEN 'Non facturée'::text
         WHEN (COALESCE(c_1_1."MontantTTC", (0)::numeric) = (0)::numeric) THEN 'Montant nul'::text
         WHEN (COALESCE(reg_stats."TotalRegleReel", COALESCE(c_1_1."MontantRegleFacture", (0)::numeric), (0)::numeric) <= (0)::numeric) THEN 'Non réglée'::text
         WHEN (COALESCE(reg_stats."TotalRegleReel", COALESCE(c_1_1."MontantRegleFacture", (0)::numeric), (0)::numeric) < COALESCE(c_1_1."MontantTTC", (0)::numeric)) THEN 'Partiellement réglée'::text
         WHEN (COALESCE(reg_stats."TotalRegleReel", COALESCE(c_1_1."MontantRegleFacture", (0)::numeric), (0)::numeric) >= COALESCE(c_1_1."MontantTTC", (0)::numeric)) THEN 'Réglée'::text
         ELSE 'Indéterminé'::text
        END AS "EtatPaiement",
          ((c_1_1."DateEcheancePaiement" IS NOT NULL) AND ((c_1_1."DateEcheancePaiement")::date < CURRENT_DATE) AND ((COALESCE(c_1_1."MontantTTC", (0)::numeric) - COALESCE(reg_stats."TotalRegleReel", COALESCE(c_1_1."MontantRegleFacture", (0)::numeric), (0)::numeric)) > (0)::numeric)) AS "EstPaiementEnRetard",
        CASE
         WHEN (c_1_1."DateEcheancePaiement" IS NOT NULL) THEN ((c_1_1."DateEcheancePaiement")::date - CURRENT_DATE)
         ELSE NULL::integer
        END AS "JoursAvantEcheance",
          COALESCE(cd_stats."NbLignes", 0) AS "NbLignes",
          COALESCE(cd_stats."NbArticlesDistincts", 0) AS "NbArticlesDistincts",
          (COALESCE(cd_stats."QteTotale", (0)::numeric))::numeric(14,3) AS "QteTotale",
          (COALESCE(cd_stats."MontantDetails", (0)::numeric))::numeric(12,2) AS "MontantDetails",
          cd_stats."ListeArticles",
          (COALESCE(cd_stats."NbLignes", 0) = 0) AS "EstCommandeSansDetails",
          ((COALESCE(c_1_1."MontantHT", (0)::numeric) - COALESCE(cd_stats."MontantDetails", (0)::numeric)))::numeric(12,2) AS "EcartMontantDetails",
          (abs((COALESCE(c_1_1."MontantHT", (0)::numeric) - COALESCE(cd_stats."MontantDetails", (0)::numeric))) > 0.01) AS "EstMontantIncoherent",
        CASE
         WHEN (COALESCE(cd_stats."NbLignes", 0) = 0) THEN 'Sans détails'::text
         WHEN (abs((COALESCE(c_1_1."MontantHT", (0)::numeric) - COALESCE(cd_stats."MontantDetails", (0)::numeric))) > 0.01) THEN 'Montant incohérent'::text
         ELSE 'Cohérente'::text
        END AS "EtatControleCommande"
         FROM (((((((logistique."T_Commande" c_1_1
           LEFT JOIN systeme."T_Utilisateurs" u ON ((c_1_1."ID_UserFk" = u."IdUser")))
           LEFT JOIN referentiel."T_Generique" type_cmd ON (((c_1_1."ID_TypeCmdFk" = type_cmd."ID_Generique"))))
           LEFT JOIN referentiel."T_Generique" statut_cmd ON (((c_1_1."ID_StatutCmdFk" = statut_cmd."ID_Generique"))))
           LEFT JOIN referentiel."T_Generique" condition_paiement ON (((c_1_1."ID_ConditionPaiementFk" = condition_paiement."ID_Generique"))))
           LEFT JOIN referentiel."T_Generique" mode_paiement ON (((c_1_1."ID_ModePaiementFk" = mode_paiement."ID_Generique"))))
           LEFT JOIN cd_stats ON ((cd_stats."ID_CmdFk" = c_1_1."ID_Commande")))
           LEFT JOIN reg_stats ON (((reg_stats."CodeFactureFk")::text = (c_1_1."CodeFacture")::text)))) historique
         LEFT JOIN logistique."T_Commande" source_1_1_1_1 ON ((source_1_1_1_1."ID_Commande" = historique."ID_Commande")))
         LEFT JOIN referentiel."T_Generique" devise ON ((devise."ID_Generique" = source_1_1_1_1."ID_DeviseFk")))) base
       LEFT JOIN logistique."V_Facture" f ON ((f."ID_CommandeFk" = base."ID_Commande")))) source_1_1_1
     LEFT JOIN logistique."T_Commande" r ON ((r."ID_Commande" = source_1_1_1."ID_Commande")))
     LEFT JOIN logistique."T_Client" t ON ((t."ID_Client" = r."ID_TiersFk")))) s
                                     JOIN logistique."T_Commande" c_1 ON ((c_1."ID_Commande" = s."ID_Commande")))
                                     LEFT JOIN geolocalisation."V_DestinationLogistique" d ON ((d.id = c_1."ID_DestinationFk")))) b
                             LEFT JOIN LATERAL ( SELECT sum("T_AvoirAffectation"."Montant") AS total
                                   FROM logistique."T_AvoirAffectation"
                                  WHERE ("T_AvoirAffectation"."ID_CommandeCibleFk" = b."ID_Commande")) cr ON (true))
                             LEFT JOIN LATERAL ( SELECT logistique.fn_montant_avoir_attente(b."ID_Commande") AS amount) pending ON (true))) source_1_1
                     JOIN logistique."T_Commande" c ON ((c."ID_Commande" = source_1_1."ID_Commande")))) source_1) source
     LEFT JOIN logistique."T_BonCodeHistorique" h ON ((h."ID_Commande" = source."ID_Commande")));

COMMENT ON VIEW logistique."V_Commande" IS 'Lecture historique par les identifiants exacts des references stockees, sans filtre numerique de famille. Les nouvelles selections restent validees par le catalogue physique ; les identifiants et colonnes de la vue sont conserves.';

COMMENT ON COLUMN logistique."V_Commande"."AbrTypeCmd" IS 'Libelle ou abbreviation du seul ID_Generique enregistre ; conserve sa lecture lors du changement de categorie configuree.';

COMMENT ON COLUMN logistique."V_Commande"."TypeCmd" IS 'Libelle ou abbreviation du seul ID_Generique enregistre ; conserve sa lecture lors du changement de categorie configuree.';

COMMENT ON COLUMN logistique."V_Commande"."AbrStatutCmd" IS 'Libelle ou abbreviation du seul ID_Generique enregistre ; conserve sa lecture lors du changement de categorie configuree.';

COMMENT ON COLUMN logistique."V_Commande"."StatutCmd" IS 'Libelle ou abbreviation du seul ID_Generique enregistre ; conserve sa lecture lors du changement de categorie configuree.';

COMMENT ON COLUMN logistique."V_Commande"."AbrConditionPaiement" IS 'Libelle ou abbreviation du seul ID_Generique enregistre ; conserve sa lecture lors du changement de categorie configuree.';

COMMENT ON COLUMN logistique."V_Commande"."ConditionPaiement" IS 'Libelle ou abbreviation du seul ID_Generique enregistre ; conserve sa lecture lors du changement de categorie configuree.';

COMMENT ON COLUMN logistique."V_Commande"."AbrModePaiement" IS 'Libelle ou abbreviation du seul ID_Generique enregistre ; conserve sa lecture lors du changement de categorie configuree.';

COMMENT ON COLUMN logistique."V_Commande"."ModePaiement" IS 'Libelle ou abbreviation du seul ID_Generique enregistre ; conserve sa lecture lors du changement de categorie configuree.';

CREATE OR REPLACE VIEW logistique."V_CommandeDetail" AS
 SELECT source."ID_CmdFk",
    source."ID_Commande",
    source."DateCmd",
    source."CodeCmd",
    source."CodeFacture",
    source."ID_TypeCmdFk",
    source."AbrTypeCmd",
    source."TypeCmd",
    source."SigneCommande",
    source."ID_StatutCmdFk",
    source."ID_StatutCmd",
    source."AbrStatutCmd",
    source."StatutCmd",
    source."ID_ArticleFk",
    source."CodeArticleInterne",
    source."NomArticle",
    source."ID_UniteFk",
    source."AbrUnite",
    source."StockActuel",
    source."StockAvantLigneTheorique",
    source."QteCmdDetail",
    source."PUCmdDetail",
    source."MontantLigne",
    source."ObsCmdDetail",
    source."RemiseCmdDetail",
    source."LieuCmdDetail",
    source."SelectCmdDetail",
    source."EtatLigne",
    source."ID_DeviseFk",
    source."DeviseCode",
    source."DeviseLibelle",
    source."IdEntiteFk",
    source."ID_TiersFk",
    source."TiersNom",
    source."NatureBon",
    h."AncienCodeCmd",
    h."RenumeroteLe"
   FROM (( SELECT source_1."ID_CmdFk",
            source_1."ID_Commande",
            source_1."DateCmd",
            source_1."CodeCmd",
            source_1."CodeFacture",
            source_1."ID_TypeCmdFk",
            source_1."AbrTypeCmd",
            source_1."TypeCmd",
            source_1."SigneCommande",
            source_1."ID_StatutCmdFk",
            source_1."ID_StatutCmd",
            source_1."AbrStatutCmd",
            source_1."StatutCmd",
            source_1."ID_ArticleFk",
            source_1."CodeArticleInterne",
            source_1."NomArticle",
            source_1."ID_UniteFk",
            source_1."AbrUnite",
            source_1."StockActuel",
            (
                CASE
                    WHEN (logistique.fn_nature_bon(source_1."ID_TypeCmdFk") = 'commande'::text) THEN NULL::numeric
                    ELSE source_1."StockAvantLigneTheorique"
                END)::numeric(14,3) AS "StockAvantLigneTheorique",
            source_1."QteCmdDetail",
            source_1."PUCmdDetail",
            source_1."MontantLigne",
            source_1."ObsCmdDetail",
            source_1."RemiseCmdDetail",
            source_1."LieuCmdDetail",
            source_1."SelectCmdDetail",
            source_1."EtatLigne",
            source_1."ID_DeviseFk",
            source_1."DeviseCode",
            source_1."DeviseLibelle",
            source_1."IdEntiteFk",
            source_1."ID_TiersFk",
            source_1."TiersNom",
            logistique.fn_nature_bon(source_1."ID_TypeCmdFk") AS "NatureBon"
           FROM ( SELECT source_1_1."ID_CmdFk",
                    source_1_1."ID_Commande",
                    source_1_1."DateCmd",
                    source_1_1."CodeCmd",
                    source_1_1."CodeFacture",
                    source_1_1."ID_TypeCmdFk",
                    source_1_1."AbrTypeCmd",
                    source_1_1."TypeCmd",
                    source_1_1."SigneCommande",
                    source_1_1."ID_StatutCmdFk",
                    source_1_1."ID_StatutCmd",
                    source_1_1."AbrStatutCmd",
                    source_1_1."StatutCmd",
                    source_1_1."ID_ArticleFk",
                    source_1_1."CodeArticleInterne",
                    source_1_1."NomArticle",
                    source_1_1."ID_UniteFk",
                    source_1_1."AbrUnite",
                    source_1_1."StockActuel",
                    source_1_1."StockAvantLigneTheorique",
                    source_1_1."QteCmdDetail",
                    source_1_1."PUCmdDetail",
                    source_1_1."MontantLigne",
                    source_1_1."ObsCmdDetail",
                    source_1_1."RemiseCmdDetail",
                    source_1_1."LieuCmdDetail",
                    source_1_1."SelectCmdDetail",
                    source_1_1."EtatLigne",
                    source_1_1."ID_DeviseFk",
                    source_1_1."DeviseCode",
                    source_1_1."DeviseLibelle",
                    r."IdEntiteFk",
                    r."ID_TiersFk",
                    t."Nom" AS "TiersNom"
                   FROM ((( SELECT historique."ID_CmdFk",
                            historique."ID_Commande",
                            historique."DateCmd",
                            historique."CodeCmd",
                            historique."CodeFacture",
                            historique."ID_TypeCmdFk",
                            historique."AbrTypeCmd",
                            historique."TypeCmd",
                            historique."SigneCommande",
                            historique."ID_StatutCmdFk",
                            historique."ID_StatutCmd",
                            historique."AbrStatutCmd",
                            historique."StatutCmd",
                            historique."ID_ArticleFk",
                            historique."CodeArticleInterne",
                            historique."NomArticle",
                            historique."ID_UniteFk",
                            historique."AbrUnite",
                            historique."StockActuel",
                            historique."StockAvantLigneTheorique",
                            historique."QteCmdDetail",
                            historique."PUCmdDetail",
                            historique."MontantLigne",
                            historique."ObsCmdDetail",
                            historique."RemiseCmdDetail",
                            historique."LieuCmdDetail",
                            historique."SelectCmdDetail",
                            historique."EtatLigne",
                            source_1_1_1."ID_DeviseFk",
                            logistique.fn_code_devise((devise."AbrGenerique")::text) AS "DeviseCode",
                            (devise."NomGenerique")::text AS "DeviseLibelle"
                           FROM ((( SELECT d."ID_CmdFk",
                                    c."ID_Commande",
                                    c."DateCmd",
                                    c."CodeCmd",
                                    c."CodeFacture",
                                    c."ID_TypeCmdFk",
                                    type_cmd."AbrGenerique" AS "AbrTypeCmd",
                                    type_cmd."NomGenerique" AS "TypeCmd",
CASE
 WHEN ((type_cmd."AbrGenerique")::text ~~* 'entr%'::text) THEN 1
 WHEN ((type_cmd."AbrGenerique")::text ~~* 'sort%'::text) THEN '-1'::integer
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
                                    (COALESCE(a."QteArticle", (0)::numeric))::numeric(14,3) AS "StockActuel",
CASE
 WHEN ((type_cmd."AbrGenerique")::text ~~* 'sort%'::text) THEN ((COALESCE(a."QteArticle", (0)::numeric) + COALESCE(d."QteCmdDetail", (0)::numeric)))::numeric(14,3)
 WHEN ((type_cmd."AbrGenerique")::text ~~* 'entr%'::text) THEN ((COALESCE(a."QteArticle", (0)::numeric) - COALESCE(d."QteCmdDetail", (0)::numeric)))::numeric(14,3)
 ELSE (COALESCE(a."QteArticle", (0)::numeric))::numeric(14,3)
END AS "StockAvantLigneTheorique",
                                    (COALESCE(d."QteCmdDetail", (0)::numeric))::numeric(14,3) AS "QteCmdDetail",
                                    (COALESCE(d."PUCmdDetail", (0)::numeric))::numeric(12,2) AS "PUCmdDetail",
                                    ((COALESCE(d."QteCmdDetail", (0)::numeric) * COALESCE(d."PUCmdDetail", (0)::numeric)))::numeric(12,2) AS "MontantLigne",
                                    d."ObsCmdDetail",
                                    d."RemiseCmdDetail",
                                    d."LieuCmdDetail",
                                    d."SelectCmdDetail",
CASE
 WHEN ((d."QteCmdDetail" IS NULL) OR (d."QteCmdDetail" <= (0)::numeric)) THEN 'Quantité invalide'::text
 WHEN (d."PUCmdDetail" IS NULL) THEN 'Prix non renseigné'::text
 ELSE 'Valide'::text
END AS "EtatLigne"
                                   FROM (((((logistique."T_CommandeDetail" d
                                     JOIN logistique."T_Commande" c ON ((c."ID_Commande" = d."ID_CmdFk")))
                                     JOIN logistique."T_Article" a ON ((a."ID_Article" = d."ID_ArticleFk")))
                                     LEFT JOIN referentiel."T_Generique" type_cmd ON (((c."ID_TypeCmdFk" = type_cmd."ID_Generique"))))
                                     LEFT JOIN referentiel."T_Generique" statut_cmd ON (((c."ID_StatutCmdFk" = statut_cmd."ID_Generique"))))
                                     LEFT JOIN referentiel."T_Generique" unite ON (((a."ID_UniteFk" = unite."ID_Generique"))))) historique
                             LEFT JOIN logistique."T_Commande" source_1_1_1 ON ((source_1_1_1."ID_Commande" = historique."ID_CmdFk")))
                             LEFT JOIN referentiel."T_Generique" devise ON ((devise."ID_Generique" = source_1_1_1."ID_DeviseFk")))) source_1_1
                     LEFT JOIN logistique."T_Commande" r ON ((r."ID_Commande" = source_1_1."ID_Commande")))
                     LEFT JOIN logistique."T_Client" t ON ((t."ID_Client" = r."ID_TiersFk")))) source_1) source
     LEFT JOIN logistique."T_BonCodeHistorique" h ON ((h."ID_Commande" = source."ID_Commande")));

COMMENT ON VIEW logistique."V_CommandeDetail" IS 'Lecture historique par les identifiants exacts des references stockees, sans filtre numerique de famille. Les nouvelles selections restent validees par le catalogue physique ; les identifiants et colonnes de la vue sont conserves.';

COMMENT ON COLUMN logistique."V_CommandeDetail"."AbrTypeCmd" IS 'Libelle ou abbreviation du seul ID_Generique enregistre ; conserve sa lecture lors du changement de categorie configuree.';

COMMENT ON COLUMN logistique."V_CommandeDetail"."TypeCmd" IS 'Libelle ou abbreviation du seul ID_Generique enregistre ; conserve sa lecture lors du changement de categorie configuree.';

COMMENT ON COLUMN logistique."V_CommandeDetail"."AbrStatutCmd" IS 'Libelle ou abbreviation du seul ID_Generique enregistre ; conserve sa lecture lors du changement de categorie configuree.';

COMMENT ON COLUMN logistique."V_CommandeDetail"."StatutCmd" IS 'Libelle ou abbreviation du seul ID_Generique enregistre ; conserve sa lecture lors du changement de categorie configuree.';

COMMENT ON COLUMN logistique."V_CommandeDetail"."AbrUnite" IS 'Libelle ou abbreviation du seul ID_Generique enregistre ; conserve sa lecture lors du changement de categorie configuree.';

CREATE OR REPLACE VIEW logistique."V_CommandesSansDetails" AS
 SELECT s."ID_Commande",
    s."DateCmd",
    s."CodeCmd",
    s."ID_TypeCmdFk",
    s."AbrTypeCmd",
    s."TypeCmd",
    s."NomClientSaisi",
    s."ObsCmd",
    s."ID_DeviseFk",
    s."DeviseCode",
    s."DeviseLibelle",
    s."IdEntiteFk",
    s."ID_TiersFk",
    s."TiersNom",
    c."ID_DestinationFk",
    d.label AS "DestinationLibelle"
   FROM ((( SELECT source."ID_Commande",
            source."DateCmd",
            source."CodeCmd",
            source."ID_TypeCmdFk",
            source."AbrTypeCmd",
            source."TypeCmd",
            source."NomClientSaisi",
            source."ObsCmd",
            source."ID_DeviseFk",
            source."DeviseCode",
            source."DeviseLibelle",
            r."IdEntiteFk",
            r."ID_TiersFk",
            t."Nom" AS "TiersNom"
           FROM ((( SELECT historique."ID_Commande",
                    historique."DateCmd",
                    historique."CodeCmd",
                    historique."ID_TypeCmdFk",
                    historique."AbrTypeCmd",
                    historique."TypeCmd",
                    historique."NomClientSaisi",
                    historique."ObsCmd",
                    source_1."ID_DeviseFk",
                    logistique.fn_code_devise((devise."AbrGenerique")::text) AS "DeviseCode",
                    (devise."NomGenerique")::text AS "DeviseLibelle"
                   FROM ((( SELECT c_1."ID_Commande",
                            c_1."DateCmd",
                            c_1."CodeCmd",
                            c_1."ID_TypeCmdFk",
                            type_cmd."AbrGenerique" AS "AbrTypeCmd",
                            type_cmd."NomGenerique" AS "TypeCmd",
                            c_1."NomClientSaisi",
                            c_1."ObsCmd"
                           FROM ((logistique."T_Commande" c_1
                             LEFT JOIN logistique."T_CommandeDetail" d_1 ON ((d_1."ID_CmdFk" = c_1."ID_Commande")))
                             LEFT JOIN referentiel."T_Generique" type_cmd ON (((c_1."ID_TypeCmdFk" = type_cmd."ID_Generique"))))
                          WHERE ((d_1."ID_CmdFk" IS NULL) AND ((COALESCE(c_1."CodeCmd", ''::character varying))::text <> ALL (ARRAY[('C_000E'::character varying)::text, ('C_000S'::character varying)::text])))) historique
                     LEFT JOIN logistique."T_Commande" source_1 ON ((source_1."ID_Commande" = historique."ID_Commande")))
                     LEFT JOIN referentiel."T_Generique" devise ON ((devise."ID_Generique" = source_1."ID_DeviseFk")))) source
             LEFT JOIN logistique."T_Commande" r ON ((r."ID_Commande" = source."ID_Commande")))
             LEFT JOIN logistique."T_Client" t ON ((t."ID_Client" = r."ID_TiersFk")))) s
     JOIN logistique."T_Commande" c ON ((c."ID_Commande" = s."ID_Commande")))
     LEFT JOIN geolocalisation."V_DestinationLogistique" d ON ((d.id = c."ID_DestinationFk")));

COMMENT ON VIEW logistique."V_CommandesSansDetails" IS 'Lecture historique par les identifiants exacts des references stockees, sans filtre numerique de famille. Les nouvelles selections restent validees par le catalogue physique ; les identifiants et colonnes de la vue sont conserves.';

COMMENT ON COLUMN logistique."V_CommandesSansDetails"."AbrTypeCmd" IS 'Libelle ou abbreviation du seul ID_Generique enregistre ; conserve sa lecture lors du changement de categorie configuree.';

COMMENT ON COLUMN logistique."V_CommandesSansDetails"."TypeCmd" IS 'Libelle ou abbreviation du seul ID_Generique enregistre ; conserve sa lecture lors du changement de categorie configuree.';

CREATE OR REPLACE VIEW logistique."V_Mouvement" AS
 SELECT source."DateHeureAutoMvt",
    source."DateMvt",
    source."ID_Mvt",
    source."ID_TypeMvtFk",
    source."TypeMvt",
    source."NomTypeMvt",
    source."ID_ArticleFk",
    source."CodeArticleInterne",
    source."NomArticle",
    source."ID_cmdFk",
    source."CodeCmd",
    source."DateCmd",
    source."QteMvt",
    source."PUMvt",
    source."SigneStock",
    source."QteMvtSigned",
    source."MontantMvt",
    source."OrigineMouvement",
    source."ID_DeviseFk",
    source."DeviseCode",
    source."DeviseLibelle",
    r."IdEntiteFk",
    r."ID_TiersFk",
    t."Nom" AS "TiersNom"
   FROM ((( SELECT historique."DateHeureAutoMvt",
            historique."DateMvt",
            historique."ID_Mvt",
            historique."ID_TypeMvtFk",
            historique."TypeMvt",
            historique."NomTypeMvt",
            historique."ID_ArticleFk",
            historique."CodeArticleInterne",
            historique."NomArticle",
            historique."ID_cmdFk",
            historique."CodeCmd",
            historique."DateCmd",
            historique."QteMvt",
            historique."PUMvt",
            historique."SigneStock",
            historique."QteMvtSigned",
            historique."MontantMvt",
            historique."OrigineMouvement",
            source_1."ID_DeviseFk",
            logistique.fn_code_devise((devise."AbrGenerique")::text) AS "DeviseCode",
            (devise."NomGenerique")::text AS "DeviseLibelle"
           FROM ((( SELECT m."DateHeureAutoMvt",
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
                    COALESCE(m."QteMvt", (0)::numeric) AS "QteMvt",
                    (COALESCE(m."PUMvt", (0)::numeric))::numeric(12,2) AS "PUMvt",
                        COALESCE(logistique.fn_effet_type_bon(m."ID_TypeMvtFk")::integer,0) AS "SigneStock",
                    (COALESCE(m."QteMvt", (0)::numeric) * (
                        COALESCE(logistique.fn_effet_type_bon(m."ID_TypeMvtFk")::integer,0))::numeric) AS "QteMvtSigned",
                    ((COALESCE(m."QteMvt", (0)::numeric) * COALESCE(m."PUMvt", (0)::numeric)))::numeric(14,2) AS "MontantMvt",
                        CASE
                            WHEN (m."ID_cmdFk" IS NULL) THEN 'Ajustement direct article'::text
                            ELSE 'Commande'::text
                        END AS "OrigineMouvement"
                   FROM (((logistique."T_Mouvement" m
                     LEFT JOIN logistique."T_Article" a ON ((m."ID_ArticleFk" = a."ID_Article")))
                     LEFT JOIN logistique."T_Commande" c ON ((m."ID_cmdFk" = c."ID_Commande")))
                     LEFT JOIN referentiel."T_Generique" g_typemvt ON (((m."ID_TypeMvtFk" = g_typemvt."ID_Generique"))))) historique
             LEFT JOIN logistique."T_Mouvement" source_1 ON ((source_1."ID_Mvt" = historique."ID_Mvt")))
             LEFT JOIN referentiel."T_Generique" devise ON ((devise."ID_Generique" = source_1."ID_DeviseFk")))) source
     LEFT JOIN logistique."T_Commande" r ON ((r."ID_Commande" = source."ID_cmdFk")))
     LEFT JOIN logistique."T_Client" t ON ((t."ID_Client" = r."ID_TiersFk")));

COMMENT ON VIEW logistique."V_Mouvement" IS 'Lecture historique par les identifiants exacts des references stockees, sans filtre numerique de famille. Les nouvelles selections restent validees par le catalogue physique ; les identifiants et colonnes de la vue sont conserves. Le signe de stock est celui du type historique, calcule par fn_effet_type_bon, jamais par la categorie actuelle.';

COMMENT ON COLUMN logistique."V_Mouvement"."TypeMvt" IS 'Libelle ou abbreviation du seul ID_Generique enregistre ; conserve sa lecture lors du changement de categorie configuree.';

COMMENT ON COLUMN logistique."V_Mouvement"."NomTypeMvt" IS 'Libelle ou abbreviation du seul ID_Generique enregistre ; conserve sa lecture lors du changement de categorie configuree.';

COMMENT ON COLUMN logistique."V_Mouvement"."SigneStock" IS 'Effet du type historique reconnu par fn_effet_type_bon : +1 entree, -1 sortie, 0 CMD/neutre ; les quantites et montants signes conservent cet effet sans categorie numerique fixe.';

COMMENT ON COLUMN logistique."V_Mouvement"."QteMvtSigned" IS 'Effet du type historique reconnu par fn_effet_type_bon : +1 entree, -1 sortie, 0 CMD/neutre ; les quantites et montants signes conservent cet effet sans categorie numerique fixe.';

CREATE OR REPLACE VIEW logistique."V_MouvementStock" AS
 SELECT source."ID_Mvt",
    source."ID_ArticleFk",
    source."CodeArticleInterne",
    source."NomArticle",
    source."ID_cmdFk",
    source."CodeCmd",
    source."DateCmd",
    source."ID_TypeCmdActuel",
    source."DateHeureAutoMvt",
    source."DateMvt",
    source."ID_TypeMvt",
    source."AbrTypeMvt",
    source."TypeMvt",
    source."QteMvt",
    source."PUMvt",
    source."SigneStock",
    source."QteMvtSigned",
    source."MontantMvt",
    source."MontantMvtSigned",
    source."OrigineMouvement",
    source."ID_DeviseFk",
    source."DeviseCode",
    source."DeviseLibelle",
    r."IdEntiteFk",
    r."ID_TiersFk",
    t."Nom" AS "TiersNom"
   FROM ((( SELECT historique."ID_Mvt",
            historique."ID_ArticleFk",
            historique."CodeArticleInterne",
            historique."NomArticle",
            historique."ID_cmdFk",
            historique."CodeCmd",
            historique."DateCmd",
            historique."ID_TypeCmdActuel",
            historique."DateHeureAutoMvt",
            historique."DateMvt",
            historique."ID_TypeMvt",
            historique."AbrTypeMvt",
            historique."TypeMvt",
            historique."QteMvt",
            historique."PUMvt",
            historique."SigneStock",
            historique."QteMvtSigned",
            historique."MontantMvt",
            historique."MontantMvtSigned",
            historique."OrigineMouvement",
            source_1."ID_DeviseFk",
            logistique.fn_code_devise((devise."AbrGenerique")::text) AS "DeviseCode",
            (devise."NomGenerique")::text AS "DeviseLibelle"
           FROM ((( SELECT m."ID_Mvt",
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
                    COALESCE(m."QteMvt", (0)::numeric) AS "QteMvt",
                    (COALESCE(m."PUMvt", (0)::numeric))::numeric(12,2) AS "PUMvt",
                        COALESCE(logistique.fn_effet_type_bon(m."ID_TypeMvtFk")::integer,0) AS "SigneStock",
                    (COALESCE(m."QteMvt", (0)::numeric) * (
                        COALESCE(logistique.fn_effet_type_bon(m."ID_TypeMvtFk")::integer,0))::numeric) AS "QteMvtSigned",
                    ((COALESCE(m."QteMvt", (0)::numeric) * COALESCE(m."PUMvt", (0)::numeric)))::numeric(14,2) AS "MontantMvt",
                    (((COALESCE(m."QteMvt", (0)::numeric) * COALESCE(m."PUMvt", (0)::numeric)) * (
                        COALESCE(logistique.fn_effet_type_bon(m."ID_TypeMvtFk")::integer,0))::numeric))::numeric(14,2) AS "MontantMvtSigned",
                        CASE
                            WHEN (m."ID_cmdFk" IS NULL) THEN 'Ajustement direct article'::text
                            ELSE 'Commande'::text
                        END AS "OrigineMouvement"
                   FROM (((logistique."T_Mouvement" m
                     LEFT JOIN logistique."T_Article" a ON ((a."ID_Article" = m."ID_ArticleFk")))
                     LEFT JOIN logistique."T_Commande" c ON ((c."ID_Commande" = m."ID_cmdFk")))
                     LEFT JOIN referentiel."T_Generique" g ON (((g."ID_Generique" = m."ID_TypeMvtFk"))))) historique
             LEFT JOIN logistique."T_Mouvement" source_1 ON ((source_1."ID_Mvt" = historique."ID_Mvt")))
             LEFT JOIN referentiel."T_Generique" devise ON ((devise."ID_Generique" = source_1."ID_DeviseFk")))) source
     LEFT JOIN logistique."T_Commande" r ON ((r."ID_Commande" = source."ID_cmdFk")))
     LEFT JOIN logistique."T_Client" t ON ((t."ID_Client" = r."ID_TiersFk")));

COMMENT ON VIEW logistique."V_MouvementStock" IS 'Lecture historique par les identifiants exacts des references stockees, sans filtre numerique de famille. Les nouvelles selections restent validees par le catalogue physique ; les identifiants et colonnes de la vue sont conserves. Le signe de stock est celui du type historique, calcule par fn_effet_type_bon, jamais par la categorie actuelle.';

COMMENT ON COLUMN logistique."V_MouvementStock"."AbrTypeMvt" IS 'Libelle ou abbreviation du seul ID_Generique enregistre ; conserve sa lecture lors du changement de categorie configuree.';

COMMENT ON COLUMN logistique."V_MouvementStock"."TypeMvt" IS 'Libelle ou abbreviation du seul ID_Generique enregistre ; conserve sa lecture lors du changement de categorie configuree.';

COMMENT ON COLUMN logistique."V_MouvementStock"."SigneStock" IS 'Effet du type historique reconnu par fn_effet_type_bon : +1 entree, -1 sortie, 0 CMD/neutre ; les quantites et montants signes conservent cet effet sans categorie numerique fixe.';

COMMENT ON COLUMN logistique."V_MouvementStock"."QteMvtSigned" IS 'Effet du type historique reconnu par fn_effet_type_bon : +1 entree, -1 sortie, 0 CMD/neutre ; les quantites et montants signes conservent cet effet sans categorie numerique fixe.';

COMMENT ON COLUMN logistique."V_MouvementStock"."MontantMvtSigned" IS 'Effet du type historique reconnu par fn_effet_type_bon : +1 entree, -1 sortie, 0 CMD/neutre ; les quantites et montants signes conservent cet effet sans categorie numerique fixe.';

CREATE OR REPLACE VIEW logistique."V_RetourArticle" AS
 WITH mouvements AS (
         SELECT "T_Mouvement"."ID_cmdFk",
            "T_Mouvement"."ID_ArticleFk",
            count(*) AS n,
            max("T_Mouvement"."ID_Mvt") AS mvt,
            max("T_Mouvement"."QteMvt") AS qte,
            max("T_Mouvement"."PUMvt") AS pu,
            max("T_Mouvement"."ID_DeviseFk") AS devise,
            max("T_Mouvement"."ID_TypeMvtFk") AS type_id
           FROM logistique."T_Mouvement"
          WHERE ("T_Mouvement"."ID_cmdFk" IS NOT NULL)
          GROUP BY "T_Mouvement"."ID_cmdFk", "T_Mouvement"."ID_ArticleFk"
        ), lots AS (
         SELECT m_1."ID_cmdFk",
            m_1."ID_ArticleFk",
            sum(l_1."Quantite") AS qte
           FROM (logistique."T_Mouvement" m_1
             JOIN logistique."T_MouvementLot" l_1 ON ((l_1."ID_MvtFk" = m_1."ID_Mvt")))
          GROUP BY m_1."ID_cmdFk", m_1."ID_ArticleFk"
        ), rendus AS (
         SELECT r_1."ID_CommandeOrigineFk" AS origine,
            d_1."ID_ArticleFk",
            sum(d_1."QteCmdDetail") AS qte,
            sum((d_1."QteCmdDetail" - COALESCE(l_1.qte, ((0)::bigint)::numeric))) AS sans_lot
           FROM ((logistique."T_RetourBon" r_1
             JOIN logistique."T_CommandeDetail" d_1 ON ((d_1."ID_CmdFk" = r_1."ID_CommandeRetourFk")))
             LEFT JOIN lots l_1 ON (((l_1."ID_cmdFk" = d_1."ID_CmdFk") AND (l_1."ID_ArticleFk" = d_1."ID_ArticleFk"))))
          GROUP BY r_1."ID_CommandeOrigineFk", d_1."ID_ArticleFk"
        )
 SELECT c."ID_Commande" AS "ID_CommandeOrigineFk",
    d."ID_ArticleFk",
    m.mvt AS "ID_MouvementOrigineFk",
    a."NomArticle",
    a."CodeArticleInterne",
    u."AbrGenerique" AS "AbrUnite",
    c."ID_DeviseFk",
    cv."DeviseCode",
    cv."DeviseLibelle",
    m.pu AS "PUHistorique",
    d."QteCmdDetail" AS "QteSortie",
    COALESCE(r.qte, (0)::numeric) AS "QteDejaRetournee",
    (d."QteCmdDetail" - COALESCE(r.qte, (0)::numeric)) AS "QteRestante",
    (d."QteCmdDetail" - COALESCE(l.qte, ((0)::bigint)::numeric)) AS "QteSansLotSortie",
    COALESCE(r.sans_lot, (0)::numeric) AS "QteSansLotDejaRetournee",
    ((d."QteCmdDetail" - COALESCE(l.qte, ((0)::bigint)::numeric)) - COALESCE(r.sans_lot, (0)::numeric)) AS "QteSansLotRestante",
    (((m.n = 1) AND (m.qte = d."QteCmdDetail") AND (m.pu IS NOT NULL) AND (m.pu >= (0)::numeric) AND (m.pu <= 9999999999.99) AND (m.devise = c."ID_DeviseFk") AND (c."ID_DeviseFk" IS NOT NULL) AND (m.type_id = c."ID_TypeCmdFk") AND (d."QteCmdDetail" > (0)::numeric) AND (COALESCE(l.qte, ((0)::bigint)::numeric) <= d."QteCmdDetail")) IS TRUE) AS "SourceCoherente"
   FROM ((((((((logistique."T_Commande" c
     JOIN referentiel."T_Generique" t ON ((t."ID_Generique" = c."ID_TypeCmdFk")))
     JOIN logistique."T_CommandeDetail" d ON ((d."ID_CmdFk" = c."ID_Commande")))
     JOIN logistique."T_Article" a ON ((a."ID_Article" = d."ID_ArticleFk")))
     LEFT JOIN referentiel."T_Generique" u ON ((u."ID_Generique" = a."ID_UniteFk")))
     LEFT JOIN logistique."V_Commande" cv ON ((cv."ID_Commande" = c."ID_Commande")))
     LEFT JOIN mouvements m ON (((m."ID_cmdFk" = d."ID_CmdFk") AND (m."ID_ArticleFk" = d."ID_ArticleFk"))))
     LEFT JOIN lots l ON (((l."ID_cmdFk" = d."ID_CmdFk") AND (l."ID_ArticleFk" = d."ID_ArticleFk"))))
     LEFT JOIN rendus r ON (((r.origine = d."ID_CmdFk") AND (r."ID_ArticleFk" = d."ID_ArticleFk"))))
  WHERE (logistique.fn_nature_bon(c."ID_TypeCmdFk") = 'sortie'::text);

COMMENT ON VIEW logistique."V_RetourArticle" IS 'Lecture historique par les identifiants exacts des references stockees, sans filtre numerique de famille. Les nouvelles selections restent validees par le catalogue physique ; les identifiants et colonnes de la vue sont conserves.';

CREATE OR REPLACE VIEW logistique."V_RetourLot" AS
 WITH rendus AS (
         SELECT r_1."ID_CommandeOrigineFk" AS origine,
            m_1."ID_ArticleFk",
            ml_1."ID_LotArticleFk",
            sum(ml_1."Quantite") AS qte
           FROM ((logistique."T_RetourBon" r_1
             JOIN logistique."T_Mouvement" m_1 ON ((m_1."ID_cmdFk" = r_1."ID_CommandeRetourFk")))
             JOIN logistique."T_MouvementLot" ml_1 ON ((ml_1."ID_MvtFk" = m_1."ID_Mvt")))
          GROUP BY r_1."ID_CommandeOrigineFk", m_1."ID_ArticleFk", ml_1."ID_LotArticleFk"
        )
 SELECT m."ID_cmdFk" AS "ID_CommandeOrigineFk",
    m."ID_ArticleFk",
    l."ID_LotArticle",
    l."NumeroLot",
    l."DatePeremptionLot",
    sum(ml."Quantite") AS "QteSortie",
    COALESCE(max(r.qte), ((0)::bigint)::numeric) AS "QteDejaRetournee",
    (sum(ml."Quantite") - COALESCE(max(r.qte), ((0)::bigint)::numeric)) AS "QteRestante"
   FROM (((((logistique."T_Mouvement" m
     JOIN logistique."T_Commande" c ON ((c."ID_Commande" = m."ID_cmdFk")))
     JOIN referentiel."T_Generique" t ON ((t."ID_Generique" = c."ID_TypeCmdFk")))
     JOIN logistique."T_MouvementLot" ml ON ((ml."ID_MvtFk" = m."ID_Mvt")))
     JOIN logistique."T_LotArticle" l ON ((l."ID_LotArticle" = ml."ID_LotArticleFk")))
     LEFT JOIN rendus r ON (((r.origine = m."ID_cmdFk") AND (r."ID_ArticleFk" = m."ID_ArticleFk") AND (r."ID_LotArticleFk" = l."ID_LotArticle"))))
  WHERE (logistique.fn_nature_bon(c."ID_TypeCmdFk") = 'sortie'::text)
  GROUP BY m."ID_cmdFk", m."ID_ArticleFk", l."ID_LotArticle", l."NumeroLot", l."DatePeremptionLot";

COMMENT ON VIEW logistique."V_RetourLot" IS 'Lecture historique par les identifiants exacts des references stockees, sans filtre numerique de famille. Les nouvelles selections restent validees par le catalogue physique ; les identifiants et colonnes de la vue sont conserves.';

CREATE OR REPLACE FUNCTION logistique.tr_proteger_facture()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog'
AS $function$
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
  IF logistique.fn_nature_bon(parent."ID_TypeCmdFk") IS DISTINCT FROM 'sortie'
    OR EXISTS(SELECT 1 FROM logistique."T_RetourBon" WHERE "ID_CommandeRetourFk"=parent."ID_Commande") THEN
    RAISE EXCEPTION 'Seul un bon de sortie original peut être facturé.' USING ERRCODE='23514'; END IF;
  source_entity:=parent."IdEntiteFk";
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
END $function$;

COMMENT ON FUNCTION logistique.tr_proteger_facture() IS 'Protection des factures emises et de leurs instantanes. La nature sortie du document est reconnue par le catalogue actuel ou historique via fn_nature_bon, sans categorie fixe ; aucune facture de retour ou CMD physique ne devient admissible.';

COMMIT;
