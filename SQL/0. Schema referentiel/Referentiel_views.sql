-- View: referentiel.V_Generique

-- DROP VIEW referentiel."V_Generique";

CREATE OR REPLACE VIEW referentiel."V_Generique"
 AS
 SELECT g."ID_CategorieGeneriqueFk",
    c."NomCategorieGenerique",
    c."ModuleCategorieGenerique",
    g."ID_Generique",
    g."NomGenerique",
    g."AbrGenerique",
    g."VisibleNiveau_2",
    g."VisibleNiveau_3",
    g."VisibleNiveau_4",
    g."VisibleNiveau_5",
    g."VisibleArticle",
    g."VisibleCmd",
    g."VisibleFacture",
    g."VisibleUsers",
    g."VisibleVoie",
    g."VisibleAll",
    g."ObsGenerique",
    g."ValideGenerique"
   FROM referentiel."T_Generique" g
     JOIN referentiel."T_CategorieGenerique" c ON g."ID_CategorieGeneriqueFk" = c."ID_CategorieGenerique"
  ORDER BY c."NomCategorieGenerique", g."NomGenerique", g."AbrGenerique";

ALTER TABLE referentiel."V_Generique"
    OWNER TO postgres;

