CREATE VIEW logistique."V_ArticleCompositionDepot" AS
SELECT
    a."ID_Article", a."IdEntiteFk", s."ID_DepotFk",
    a."NomArticle", a."CodeArticleInterne", a."CodeArticleExterne", a."RefArticle",
    a."ValideArticle", a."ID_TypeArticleFk", a."ID_CategorieArticleFk", a."ID_UniteFk",
    type_article."AbrGenerique" AS "AbrTypeArticle",
    categorie."AbrGenerique" AS "AbrCategorieArticle",
    COALESCE(NULLIF(btrim(type_article."AbrGenerique"), ''), type_article."NomGenerique") AS "TypeArticle",
    COALESCE(NULLIF(btrim(categorie."AbrGenerique"), ''), categorie."NomGenerique") AS "CategorieArticle",
    unite."AbrGenerique" AS "AbrUnite", unite."NomGenerique" AS "Unite",
    a."PUArticle", a."PVArticle", a."ID_DeviseFk",
    coalesce(p."DecimalesStock", 0)::smallint AS "DecimalesStock",
    s."StockDisponible" AS "QteArticle",
    s."StockPhysique" AS "StockDepot", s."StockDisponible", s."StockReserve",
    coalesce(a."QteArticle", 0) AS "StockEntreprise"
FROM logistique."V_StockDepot" s
JOIN logistique."T_Article" a ON a."ID_Article" = s."ID_ArticleFk" AND a."IdEntiteFk" = s."IdEntiteFk"
LEFT JOIN referentiel."T_Generique" type_article ON type_article."ID_Generique" = a."ID_TypeArticleFk"
LEFT JOIN referentiel."T_Generique" categorie ON categorie."ID_Generique" = a."ID_CategorieArticleFk"
LEFT JOIN referentiel."T_Generique" unite ON unite."ID_Generique" = a."ID_UniteFk"
LEFT JOIN logistique."T_PrecisionStock" p ON p."ID_UniteFk" = a."ID_UniteFk";

COMMENT ON VIEW logistique."V_ArticleCompositionDepot" IS
    'Catalogue opérationnel des bons et transferts. Réutilise le stock disponible par dépôt, sans calculer les indicateurs de péremption du registre complet.';
COMMENT ON COLUMN logistique."V_ArticleCompositionDepot"."QteArticle" IS
    'Quantité disponible à la sortie. Déduit les réservations et le stock indisponible selon V_StockDepot.';

DO $$
BEGIN
    IF EXISTS (SELECT FROM pg_roles WHERE rolname = 'sauverndeko_runtime') THEN
        GRANT SELECT ON logistique."V_ArticleCompositionDepot" TO sauverndeko_runtime;
    END IF;
END;
$$;
