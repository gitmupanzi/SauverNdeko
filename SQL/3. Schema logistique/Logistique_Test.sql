
SELECT * FROM referentiel."T_Generique"
Where "ID_Generique"=102
ORDER BY "ID_Generique" ASC 


DELETE FROM logistique."T_Mouvement";
DELETE FROM logistique."T_Article";
DELETE FROM logistique."T_Commande";
DELETE FROM logistique."T_CommandeDetail";


SELECT * FROM logistique."T_Article";
SELECT * FROM logistique."T_Commande";
SELECT * FROM logistique."T_CommandeDetail";
SELECT * FROM logistique."T_Mouvement";

/ Entrée : 448
Select "ID_Generique" FROM referentiel."T_Generique"
where "AbrGenerique"='Entrée'
/Sortie : 449
Select "ID_Generique" FROM referentiel."T_Generique"
where "AbrGenerique"='Sortie'


/* ============================================================================
   JEU DE TEST LOGISTIQUE
   Objectif : vérifier le comportement coordonné de :
     - T_Article (CRUD + mouvements de rapport)
     - T_Commande
     - T_CommandeDetail
     - T_Mouvement (mise à jour du stock)
   ATTENTION :
     - Adapte les ID_TypeCmdFk (Entrée / Sortie) à ton référentiel.
   ============================================================================ */

-- Optionnel : travailler dans une transaction de test
BEGIN;

-------------------------------------------------------------------------------
-- 0. NETTOYAGE MINIMAL DES DONNÉES DE TEST (facultatif, à adapter)
-------------------------------------------------------------------------------
-- On supprime d'abord les détails et mouvements liés à nos commandes de test
-- (si tu relances le script plusieurs fois)

DELETE FROM logistique."T_Mouvement"
WHERE "ID_cmdFk" IN (10001, 10002);

DELETE FROM logistique."T_CommandeDetail"
WHERE "ID_CmdFk" IN (10001, 10002);

DELETE FROM logistique."T_Commande"
WHERE "ID_Commande" IN (10001, 10002);

-- On peut aussi supprimer l'article de test s'il existe (si pas encore lié)
-- (Si déjà lié, la suppression sera bloquée par le trigger → c'est bon signe)
DELETE FROM logistique."T_Article"
WHERE "CodeArticleInterne" = 'TEST-ART-001'
      AND NOT EXISTS (
          SELECT 1 FROM logistique."T_CommandeDetail" cd
          WHERE cd."ID_ArticleFk" = logistique."T_Article"."ID_Article"
      )
      AND NOT EXISTS (
          SELECT 1 FROM logistique."T_Mouvement" m
          WHERE m."ID_ArticleFk" = logistique."T_Article"."ID_Article"
      );

-------------------------------------------------------------------------------
-- 1. CRÉATION D’UN ARTICLE DE TEST
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
    now(),
    999,
    'Gants médicaux test',
    'REF-TEST-ART-001',
    100,                -- QteArticle initiale
    1.00,
    2,                  -- PVArticle (pour info)
    10,
    NULL,
    'Article de test logistique',
    TRUE,
    NULL,
    NULL,
    NULL,
    'TEST-ART-001'
)
RETURNING "ID_Article" AS id_article_test;

-- Vérifier l'article et le mouvement de rapport
SELECT * FROM logistique."T_Article"
WHERE "CodeArticleInterne" = 'TEST-ART-001';

SELECT * FROM logistique."T_Mouvement"
WHERE "ID_ArticleFk" IN (
    SELECT "ID_Article" FROM logistique."T_Article"
    WHERE "CodeArticleInterne" = 'TEST-ART-001'
)
ORDER BY "ID_Mvt" DESC;

-------------------------------------------------------------------------------
-- 2. MODIFICATION DIRECTE DE QTEARTICLE (test mouvements de rapport)
-------------------------------------------------------------------------------
-- On récupère l'ID_Article créé
WITH art AS (
    SELECT "ID_Article"
    FROM logistique."T_Article"
    WHERE "CodeArticleInterne" = 'TEST-ART-001'
    LIMIT 1
)
UPDATE logistique."T_Article" a
SET "QteArticle" = 130
FROM art
WHERE a."ID_Article" = art."ID_Article";

-- Puis on redescend à 90
WITH art AS (
    SELECT "ID_Article"
    FROM logistique."T_Article"
    WHERE "CodeArticleInterne" = 'TEST-ART-001'
    LIMIT 1
)
UPDATE logistique."T_Article" a
SET "QteArticle" = 90
FROM art
WHERE a."ID_Article" = art."ID_Article";

-- Vérifier la QteArticle et les mouvements de rapport (ID_cmdFk NULL)
SELECT * FROM logistique."T_Article"
WHERE "CodeArticleInterne" = 'TEST-ART-001';

SELECT * FROM logistique."T_Mouvement"
WHERE "ID_ArticleFk" IN (
    SELECT "ID_Article" FROM logistique."T_Article"
    WHERE "CodeArticleInterne" = 'TEST-ART-001'
)
ORDER BY "ID_Mvt";

-- À ce stade :
-- - La QteArticle doit être 90
-- - Il doit y avoir plusieurs mouvements
-- - Ces mouvements de rapport NE doivent PAS avoir modifié la QteArticle
--   via tr_crud_mouvement (le trigger les ignore pour le stock).

-------------------------------------------------------------------------------
-- 3. CRÉATION D’UNE COMMANDE D’ENTRÉE (ID_Commande = 10001)
-------------------------------------------------------------------------------
-- ⚠️ Adapter ID_TypeCmdFk_Entree (ici 101) à ton référentiel
--    101 doit être un ID_Generique dont NomGenerique ILIKE 'entr%'

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
    10001,              -- ID_Commande fixé pour le test
    448,                -- ID_TypeCmdFk (Entrée)
    NULL,
    NULL,
    NULL,
    NULL,
    now(),
    now(),
    'CMD-ENTREE-TEST',
    'CMD-ENTREE-TEST',
    0,
    0,
    NULL,
    'Commande d''ENTRÉE de test',
    FALSE,
    NULL,
    NULL,
    NULL,
    0,
    0,
    NULL,
    FALSE,
    NULL,
    NULL,
    NULL,
    NULL
);

SELECT * FROM logistique."T_Commande"
WHERE "ID_Commande" = 10001;

-------------------------------------------------------------------------------
-- 4. CRÉATION D’UN DÉTAIL D’ENTRÉE (QteCmdDetail = 20)
-------------------------------------------------------------------------------
-- On prend l'article de test et on ajoute 20 en entrée
WITH art AS (
    SELECT "ID_Article"
    FROM logistique."T_Article"
    WHERE "CodeArticleInterne" = 'TEST-ART-001'
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
    10001,              -- ID_CmdFk
    art."ID_Article",
    20,                 -- QteCmdDetail
    1.5,
    'Ligne entrée test',
    FALSE,
    NULL,
    FALSE
FROM art;

-- Vérifier stock + mouvement
SELECT * FROM logistique."T_Article"
WHERE "CodeArticleInterne" = 'TEST-ART-001';

SELECT * FROM logistique."T_Mouvement"
WHERE "ID_cmdFk" = 10001
ORDER BY "ID_Mvt";

-- ATTENDU :
-- - QteArticle : 90 + 20 = 110
-- - 1 mouvement avec ID_cmdFk = 10001, Type 'Entrée', QteMvt = 20

-------------------------------------------------------------------------------
-- 5. CRÉATION D’UNE COMMANDE DE SORTIE (ID_Commande = 10002)
-------------------------------------------------------------------------------
-- ⚠️ Adapter ID_TypeCmdFk_Sortie (ici 102) à ton référentiel
--    102 doit être un ID_Generique dont NomGenerique ILIKE 'sort%'

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
    10002,
    449,                -- ID_TypeCmdFk (Sortie) → À ADAPTER
    NULL,
    NULL,
    NULL,
    NULL,
    now(),
    now(),
    'CMD-SORTIE-TEST',
    'CMD-SORTIE-TEST',
    0,
    0,
    NULL,
    'Commande de SORTIE de test',
    FALSE,
    NULL,
    NULL,
    NULL,
    0,
    0,
    NULL,
    FALSE,
    NULL,
    NULL,
    NULL,
    NULL
);

SELECT * FROM logistique."T_Commande"
WHERE "ID_Commande" = 10002;

-------------------------------------------------------------------------------
-- 6. DÉTAIL DE SORTIE (QteCmdDetail = 10)
-------------------------------------------------------------------------------
WITH art AS (
    SELECT "ID_Article"
    FROM logistique."T_Article"
    WHERE "CodeArticleInterne" = 'TEST-ART-001'
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
    10002,
    art."ID_Article",
    10,                 -- QteCmdDetail = 10 (Sortie)
    1.5,
    'Ligne sortie test',
    FALSE,
    NULL,
    FALSE
FROM art;

-- Vérifier stock + mouvements
SELECT * FROM logistique."T_Article"
WHERE "CodeArticleInterne" = 'TEST-ART-001';

SELECT * FROM logistique."T_Mouvement"
WHERE "ID_cmdFk" IN (10001, 10002)
ORDER BY "ID_Mvt";

-- ATTENDU :
-- QteArticle = 110 (après entrée) - 10 = 100

-------------------------------------------------------------------------------
-- 7. UPDATE DU DÉTAIL DE SORTIE (QteCmdDetail 10 → 15)
-------------------------------------------------------------------------------
WITH art AS (
    SELECT "ID_Article"
    FROM logistique."T_Article"
    WHERE "CodeArticleInterne" = 'TEST-ART-001'
    LIMIT 1
)
UPDATE logistique."T_CommandeDetail" cd
SET "QteCmdDetail" = 15
FROM art
WHERE cd."ID_CmdFk"   = 10002
  AND cd."ID_ArticleFk" = art."ID_Article";

-- Vérifier stock + mouvements (le trigger de T_Mouvement
-- a dû annuler -10 et appliquer -15 → delta -5)
SELECT * FROM logistique."T_Article"
WHERE "CodeArticleInterne" = 'TEST-ART-001';

SELECT * FROM logistique."T_Mouvement"
WHERE "ID_cmdFk" = 10002
ORDER BY "ID_Mvt";

-- ATTENDU :
-- - Avant l'UPDATE : 100
-- - Après l'UPDATE : 100 - 5 = 95

-------------------------------------------------------------------------------
-- 8. DELETE DU DÉTAIL DE SORTIE (via tr_delete_commandeDetail)
-------------------------------------------------------------------------------
WITH art AS (
    SELECT "ID_Article"
    FROM logistique."T_Article"
    WHERE "CodeArticleInterne" = 'TEST-ART-001'
    LIMIT 1
)
DELETE FROM logistique."T_CommandeDetail" cd
USING art
WHERE cd."ID_CmdFk"   = 10002
  AND cd."ID_ArticleFk" = art."ID_Article";

-- Vérifier stock + mouvements
SELECT * FROM logistique."T_Article"
WHERE "CodeArticleInterne" = 'TEST-ART-001';

SELECT * FROM logistique."T_Mouvement"
WHERE "ID_cmdFk" = 10002
ORDER BY "ID_Mvt";

-- ATTENDU :
-- Le trigger BEFORE DELETE sur T_CommandeDetail :
--  - voit une Sortie (mouvement '-')
--  - applique l'opération inverse '+' de 15
-- Donc QteArticle : 95 + 15 = 110
-- Et les mouvements liés à la commande 10002 doivent être supprimés.

-------------------------------------------------------------------------------
-- 9. DELETE DE LA COMMANDE D’ENTRÉE (10001) VIA ps_crud_commande
-------------------------------------------------------------------------------
-- Vérifier que :
--  - la commande 10001 est supprimée
--  - ses détails le sont aussi
--  - les mouvements liés ont disparu
--  - le stock a été restitué à 90 (stock avant la commande d’entrée)
DELETE FROM logistique."T_Commande"
WHERE "ID_Commande" = 10001;

SELECT * FROM logistique."T_Commande"
WHERE "ID_Commande" = 10001;

SELECT * FROM logistique."T_CommandeDetail"
WHERE "ID_CmdFk" = 10001;

SELECT * FROM logistique."T_Mouvement"
WHERE "ID_cmdFk" = 10001;

SELECT * FROM logistique."T_Article"
WHERE "CodeArticleInterne" = 'TEST-ART-001';

-------------------------------------------------------------------------------
-- 10. TEST : SUPPRESSION DE L’ARTICLE LIÉ (DOIT ÉCHOUER)
-------------------------------------------------------------------------------
-- Ici, la suppression devrait être BLOQUÉE par tr_crud_article
-- car l’article a des mouvements d’historique (de rapport).

DELETE FROM logistique."T_Article"
WHERE "CodeArticleInterne" = 'TEST-ART-001';

-- Tu dois obtenir une erreur du style :
--  tr_crud_article(DELETE) : suppression interdite, article % lié à T_Mouvement.

-------------------------------------------------------------------------------
-- FIN DU TEST
-------------------------------------------------------------------------------

-- Pour annuler tous les tests :
ROLLBACK;

-- Si tu veux garder les données de test, commente le ROLLBACK et mets :
-- COMMIT;
