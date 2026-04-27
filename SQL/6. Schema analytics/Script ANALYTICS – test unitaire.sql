/* ============================================================================
   TEST UNITAIRE – MODULE ANALYTICS
   Scénario :
     - Garantir qu’il existe un user, une entité (pharmacie) et un article
     - Enregistrer une recherche de médicament
     - Vérifier T_Recherche + V_Recherche

   Hypothèses :
     - analytics."T_Recherche" existe avec les colonnes :
         IdUserFk, TexteRecherche, TypeRecherche,
         ID_ArticleResultFk, IdEntiteResultFk, IdSpecialiteFk,
         LatitudeUser, LongitudeUser, DateRecherche
     - analytics."V_Recherche" agrège les recherches par article
   ========================================================================== */

BEGIN;

-------------------------------------------------------------------------------
-- 0. CRÉATION / VÉRIFICATION DES PRÉ-REQUIS (USER / ENTITÉ / ARTICLE)
-------------------------------------------------------------------------------

-- a) User de test analytics
INSERT INTO systeme."T_Utilisateurs" (
    "NomUser",
    "PrenomUser",
    "EmailUser",
    "MotdepasseUser",
    "PhoneUser",
    "IdRoleFk",
    "ValideUser",
    "SexeUser",
    "IdEntiteFk",
    "Is_staff",
    "Is_Admin"
)
SELECT
    'PATIENT',
    'Analytics',
    'patient.analytics@sauverndeko.cd',
    'hashed_password_analytics',
    '+243810001234',
    NULL,
    TRUE,
    'M'::char(1),
    NULL,
    FALSE,
    FALSE
WHERE NOT EXISTS (
    SELECT 1 FROM systeme."T_Utilisateurs"
    WHERE "EmailUser" = 'patient.analytics@sauverndeko.cd'
);

-- b) Entité de test analytics (Pharmacie)
INSERT INTO systeme."T_Entite" (
    "NomEntite",
    "PhoneEntite",
    "EmailEntite",
    "AdresseEntite",
    "IdTypeEntiteFk",
    "ValideEntite"
)
SELECT
    'Pharmacie Analytics TEST',
    '+243820001234',
    'pharmacie.analytics@sauverndeko.cd',
    'Kinshasa – test analytics',
    (
        SELECT g."ID_Generique"
        FROM   referentiel."T_Generique" g
        JOIN   referentiel."T_CategorieGenerique" c
               ON c."ID_CategorieGenerique" = g."ID_CategorieGeneriqueFk"
        WHERE  c."NomCategorieGenerique" = 'Type entite'
        AND    g."NomGenerique" = 'Pharmacie'
        LIMIT  1
    ),
    TRUE
WHERE NOT EXISTS (
    SELECT 1 FROM systeme."T_Entite"
    WHERE "EmailEntite" = 'pharmacie.analytics@sauverndeko.cd'
);

-- c) Article de test analytics
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
SELECT
    NULL,
    NULL,
    NULL,
    NULL,
    NOW(),
    3001,
    'Paracétamol 500 mg comprime (ANALYTICS)',
    'PARA500-ANALYTICS',
    100,
    2.00,
    3.00,
    10,
    NULL,
    'Article test – analytics',
    TRUE,
    NULL,
    NULL,
    NULL,
    'MED_ANALYTICS_PARA500'
WHERE NOT EXISTS (
    SELECT 1
    FROM   logistique."T_Article"
    WHERE  "CodeArticleInterne" = 'MED_ANALYTICS_PARA500'
);

-------------------------------------------------------------------------------
-- 1. INSERTION D’UNE RECHERCHE DE TEST
-------------------------------------------------------------------------------

INSERT INTO analytics."T_Recherche" (
    "IdUserFk",
    "TexteRecherche",
    "TypeRecherche",
    "ID_ArticleResultFk",
    "IdEntiteResultFk",
    "IdSpecialiteFk",
    "LatitudeUser",
    "LongitudeUser",
    "DateRecherche"
)
SELECT
    u."IdUser",
    'paracetamol 500',
    'Produit pharmaceutique',
    a."ID_Article",
    e."IdEntite",
    NULL,
    -4.33::numeric(9,6),
    15.30::numeric(9,6),
    NOW()
FROM   systeme."T_Utilisateurs" u
CROSS JOIN logistique."T_Article" a
CROSS JOIN systeme."T_Entite" e
WHERE  u."EmailUser" = 'patient.analytics@sauverndeko.cd'
AND    a."CodeArticleInterne" = 'MED_ANALYTICS_PARA500'
AND    e."EmailEntite" = 'pharmacie.analytics@sauverndeko.cd';

-------------------------------------------------------------------------------
-- 2. CONTRÔLES ANALYTICS
-------------------------------------------------------------------------------

-- Dernières recherches (brutes)
SELECT *
FROM   analytics."T_Recherche"
ORDER BY "IdRecherche" DESC
LIMIT 20;

-- Synthèse par article (si la vue existe)
SELECT *
FROM   analytics."V_Recherche"
ORDER BY nbrerecherches DESC
LIMIT 20;

-------------------------------------------------------------------------------
-- FIN TEST ANALYTICS
-------------------------------------------------------------------------------

-- Pour garder l’historique de test :
-- COMMIT;

-- Pour annuler :
ROLLBACK;
