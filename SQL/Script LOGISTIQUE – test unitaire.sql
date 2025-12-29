/* ============================================================================
   TEST UNITAIRE – MODULE LOGISTIQUE
   Scénario :
     - Création d’un article MÉDICAMENT de test
     - Création d’une commande de SORTIE (vente)
     - Vérification de T_Article, T_CommandeDetail, T_Mouvement

   Hypothèses :
     - Les triggers / fonctions stock gèrent le stock à partir de T_CommandeDetail
     - ID_TypeCmdFk = 449 correspond à une commande de type "Sortie"
   ========================================================================== */

BEGIN;

-------------------------------------------------------------------------------
-- 0. NETTOYAGE MINIMAL DES DONNÉES DE TEST (si relance du script)
-------------------------------------------------------------------------------

-- Suppression des détails de commande liés à notre commande de test
DELETE FROM logistique."T_CommandeDetail"
WHERE "ID_CmdFk" IN (
    SELECT "ID_Commande"
    FROM logistique."T_Commande"
    WHERE "CodeCmd" = 'CMD_MED_UNIT_001'
);

-- Suppression des mouvements liés à notre commande de test
DELETE FROM logistique."T_Mouvement"
WHERE "ID_cmdFk" IN (
    SELECT "ID_Commande"
    FROM logistique."T_Commande"
    WHERE "CodeCmd" = 'CMD_MED_UNIT_001'
);

-- Suppression de la commande de test
DELETE FROM logistique."T_Commande"
WHERE "CodeCmd" = 'CMD_MED_UNIT_001';

-- Suppression de l’article de test si possible (pas lié à d’autres mouvements)
DELETE FROM logistique."T_Mouvement"
WHERE "ID_ArticleFk" IN (
    SELECT "ID_Article"
    FROM logistique."T_Article"
    WHERE "CodeArticleInterne" = 'MED_UNIT_AMOXI_500'
);

DELETE FROM logistique."T_Article"
WHERE "CodeArticleInterne" = 'MED_UNIT_AMOXI_500';

-------------------------------------------------------------------------------
-- 1. CRÉATION D’UN ARTICLE DE TEST (MÉDICAMENT)
-------------------------------------------------------------------------------

INSERT INTO logistique."T_Article" (
    "ID_TypeArticleFk",
    "ID_CategorieArticleFk",
    "ID_UserFK",
    "ID_UniteFk",
    "DateHeureAuto",
    "CodeArticleExterne",
    "NomArticle",
    "RefArticle",
    "QteArticle",
    "PUArticle",
    "PVArticle",
    "QteMinArticle",
    "PhotoArticle",
    "ObsArticle",
    "ValideArticle",
    "DatePeremptionArticle",
    "DatePeremptionAlerteArticle",
    "NbreJoursAlerteArticle",
    "CodeArticleInterne"
)
VALUES (
    NULL,
    NULL,
    NULL,
    NULL,
    NOW(),
    2001,
    'Amoxicilline 500 mg gélule (UNIT)',
    'AMOX500-UNIT-TEST',
    50,                  -- stock initial
    5.00,
    7.00,                -- prix de vente
    10,
    NULL,
    'Article médicamenteux test – logistique',
    TRUE,
    NULL,
    NULL,
    NULL,
    'MED_UNIT_AMOXI_500'
)
RETURNING "ID_Article" AS id_article_unit;

-- Vérification article
SELECT "ID_Article", "NomArticle", "QteArticle", "PVArticle", "CodeArticleInterne"
FROM   logistique."T_Article"
WHERE  "CodeArticleInterne" = 'MED_UNIT_AMOXI_500';

-------------------------------------------------------------------------------
-- 2. CRÉATION D’UNE COMMANDE DE SORTIE (VENTE)
-------------------------------------------------------------------------------

-- On force un ID_Commande pour ce test (mais tu peux laisser en auto si ton PK est en serial)
INSERT INTO logistique."T_Commande" (
    "ID_Commande",
    "ID_TypeCmdFk",
    "ID_StatutCmd",
    "ID_ClientFk",
    "ID_UserFk",
    "geolocalisationCmd",
    "DateHeureAutoCmd",
    "DateCmd",
    "CodeCmd",
    "RefCmd",
    "MontantHT",
    "MontantTTC",
    "UrlBL",
    "ObsCmd",
    "SelectCmd",
    "DateHeureAutoFacture",
    "DateFacture",
    "CodeFacture",
    "MontantRegleFacture",
    "MontantResteFacture",
    "StatusFacture",
    "ValideRemiseFacture",
    "UrlFacture",
    "ID_ConditionPaiementFk",
    "DateEcheancePaiement",
    "ID_ModePaiementFk"
)
VALUES (
    20001,                        -- ID_Commande de test
    449,                          -- TypeCmd = Sortie
    NULL,
    NULL,
    NULL,
    'Kinshasa – test logistique',
    NOW(),
    NOW(),
    'CMD_MED_UNIT_001',
    'Commande unitaire test Amoxicilline',
    0,
    0,
    NULL,
    'Commande de SORTIE test (logistique)',
    FALSE,
    NULL,
    NULL,
    NULL,
    0,
    0,
    'Non réglée (test logistique)',
    FALSE,
    NULL,
    NULL,
    NULL,
    NULL
);

-- Vérification commande
SELECT * FROM logistique."T_Commande"
WHERE "ID_Commande" = 20001;

-------------------------------------------------------------------------------
-- 3. DÉTAIL DE COMMANDE : 3 UNITÉS D’AMOXICILLINE
-------------------------------------------------------------------------------

WITH art AS (
    SELECT "ID_Article"
    FROM   logistique."T_Article"
    WHERE  "CodeArticleInterne" = 'MED_UNIT_AMOXI_500'
    LIMIT 1
)
INSERT INTO logistique."T_CommandeDetail" (
    "ID_CmdFk",
    "ID_ArticleFk",
    "QteCmdDetail",
    "PUCmdDetail",
    "ObsCmdDetail",
    "RemiseCmdDetail",
    "LieuCmdDetail",
    "SelectCmdDetail"
)
SELECT
    20001,
    art."ID_Article",
    3,                      -- le client achète 3 unités
    7.00,
    'Ligne sortie UNIT – Amoxicilline 500',
    FALSE,
    NULL,
    FALSE
FROM art;

-- Vérification : détail de commande
SELECT *
FROM   logistique."T_CommandeDetail"
WHERE  "ID_CmdFk" = 20001;

-- Vérification : stock de l’article (attendu : 50 – 3 = 47 si triggers OK)
SELECT "ID_Article", "NomArticle", "QteArticle"
FROM   logistique."T_Article"
WHERE  "CodeArticleInterne" = 'MED_UNIT_AMOXI_500';

-- Vérification : mouvements générés
SELECT *
FROM   logistique."T_Mouvement"
WHERE  "ID_cmdFk" = 20001
ORDER BY "ID_Mvt" DESC;

-------------------------------------------------------------------------------
-- FIN DU TEST LOGISTIQUE
-------------------------------------------------------------------------------

-- Pour garder les données de test :
-- COMMIT;

-- Pour annuler les modifications (test non persistant) :
ROLLBACK;
