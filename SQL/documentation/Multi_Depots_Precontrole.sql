-- Exécution explicitement READ ONLY ; aucune correction automatique.
BEGIN TRANSACTION READ ONLY;
SELECT current_database() AS base_controlee,current_timestamp AS verifie_le;
SELECT 'article_sans_proprietaire' AS anomalie,count(*) AS nombre FROM logistique."T_Article" WHERE "IdEntiteFk" IS NULL
UNION ALL SELECT 'bon_sans_proprietaire',count(*) FROM logistique."T_Commande" WHERE "IdEntiteFk" IS NULL
UNION ALL SELECT 'comptage_sans_proprietaire',count(*) FROM logistique."T_Inventaire" WHERE "IdEntiteFk" IS NULL
UNION ALL SELECT 'stock_historique_non_rapproche',count(*) FROM logistique."T_Article" a WHERE a."QteArticle" IS DISTINCT FROM
 (SELECT coalesce(sum(m."QteMvt"*logistique.fn_effet_type_bon(m."ID_TypeMvtFk")),0) FROM logistique."T_Mouvement" m WHERE m."ID_ArticleFk"=a."ID_Article")
UNION ALL SELECT 'lot_negatif',count(*) FROM logistique."V_LotArticleStock" WHERE "StockLot"<0
UNION ALL SELECT 'stock_sans_lot_negatif',count(*) FROM logistique."T_Article" a WHERE a."QteArticle"<
 (SELECT coalesce(sum(l."StockLot"),0) FROM logistique."V_LotArticleStock" l WHERE l."ID_ArticleFk"=a."ID_Article")
UNION ALL SELECT 'stock_article_negatif',count(*) FROM logistique."T_Article" WHERE "QteArticle"<0
UNION ALL SELECT 'mouvement_article_entreprise_incompatible',count(*) FROM logistique."T_Mouvement" m JOIN logistique."T_Commande" c ON c."ID_Commande"=m."ID_cmdFk" JOIN logistique."T_Article" a ON a."ID_Article"=m."ID_ArticleFk" WHERE a."IdEntiteFk"<>c."IdEntiteFk";
SELECT a."IdEntiteFk",count(*) AS articles,sum(a."QteArticle") AS controle_quantites_heterogenes
 FROM logistique."T_Article" a GROUP BY a."IdEntiteFk" ORDER BY a."IdEntiteFk";
-- Le total ci-dessus ne représente pas une unité physique homogène : conserver
-- aussi la photographie exacte ID_Article/QteArticle et les empreintes par table.
COMMIT;
