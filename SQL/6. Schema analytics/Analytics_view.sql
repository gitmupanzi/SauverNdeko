-- View: analytics.V_Recherche

-- DROP VIEW analytics."V_Recherche";

CREATE OR REPLACE VIEW analytics."V_Recherche"
 AS
 SELECT a."ID_Article",
    a."NomArticle",
    count(r."IdRecherche") AS nbrerecherches
   FROM analytics."T_Recherche" r
     JOIN logistique."T_Article" a ON a."ID_Article" = r."ID_ArticleResultFk"
  GROUP BY a."ID_Article", a."NomArticle"
  ORDER BY (count(r."IdRecherche")) DESC;

ALTER TABLE analytics."V_Recherche"
    OWNER TO postgres;

