-- ============================================================================
-- VUES DU MODULE LOGISTIQUE
-- Alignees sur le scenario metier officiel.
-- ============================================================================

-- ============================================================================
-- V_AlertStock
-- ============================================================================

CREATE OR REPLACE VIEW logistique."V_AlertStock" AS
SELECT a."ID_Article",
    a."NomArticle",
    a."QteArticle",
    a."QteMinArticle",
    a."QteArticle" - a."QteMinArticle"::numeric AS "Marge"
FROM logistique."T_Article" a
WHERE a."QteMinArticle" IS NOT NULL;

ALTER TABLE logistique."V_AlertStock" OWNER TO postgres;

COMMENT ON VIEW logistique."V_AlertStock"
    IS 'Articles avec seuil minimal defini et marge par rapport au stock de securite.';


-- ============================================================================
-- V_Article
-- ============================================================================

CREATE OR REPLACE VIEW logistique."V_Article" AS
SELECT a."DateHeureAuto",
    a."ID_Article",
    a."ID_TypeArticleFk",
    a."ID_CategorieArticleFk",
    a."CodeArticleInterne",
    a."NomArticle",
    a."ID_UniteFk",
    a."RefArticle",
    a."QteArticle",
    a."QteMinArticle",
    a."PUArticle",
    a."PVArticle",
    a."ObsArticle",
    a."ValideArticle",
    u."IdUser",
    TRIM(BOTH FROM CONCAT(COALESCE(u."PrenomUser", ''), ' ', COALESCE(u."NomUser", ''))) AS "NomComplet"
FROM logistique."T_Article" a
LEFT JOIN systeme."T_Utilisateurs" u ON a."ID_UserFK" = u."IdUser";

ALTER TABLE logistique."V_Article" OWNER TO postgres;


-- ============================================================================
-- V_AuditStock
-- ============================================================================

CREATE OR REPLACE VIEW logistique."V_AuditStock" AS
SELECT "ID_Article",
    "CodeArticleInterne",
    "NomArticle",
    "StockArticle",
    "StockMouvements",
    "Ecart",
    "N_Mouvements",
    "QteEntree",
    "QteSortie"
FROM logistique.fn_audit_stock(NULL::integer, NULL::timestamp without time zone)
    fn_audit_stock("ID_Article", "CodeArticleInterne", "NomArticle", "StockArticle", "StockMouvements", "Ecart", "N_Mouvements", "QteEntree", "QteSortie");

ALTER TABLE logistique."V_AuditStock" OWNER TO postgres;

COMMENT ON VIEW logistique."V_AuditStock"
    IS 'Vue d''audit global des stocks.';


-- ============================================================================
-- V_AuditStock_Theorique
-- ============================================================================

CREATE OR REPLACE VIEW logistique."V_AuditStock_Theorique" AS
WITH mvt AS (
    SELECT m."ID_ArticleFk",
        SUM(
            CASE
                WHEN g."AbrGenerique"::text ~~* 'entr%'::text THEN m."QteMvt"
                WHEN g."AbrGenerique"::text ~~* 'sort%'::text THEN -m."QteMvt"
                ELSE 0
            END
        ) AS stock_mouvement
    FROM logistique."T_Mouvement" m
    LEFT JOIN referentiel."T_Generique" g ON g."ID_Generique" = m."ID_TypeMvtFk"
    GROUP BY m."ID_ArticleFk"
)
SELECT a."ID_Article",
    a."NomArticle",
    a."QteArticle" AS "StockEnregistre",
    COALESCE(mvt.stock_mouvement, 0::bigint) AS "StockCalcule",
    a."QteArticle" - COALESCE(mvt.stock_mouvement, 0::bigint)::numeric AS "Ecart"
FROM logistique."T_Article" a
LEFT JOIN mvt ON mvt."ID_ArticleFk" = a."ID_Article";

ALTER TABLE logistique."V_AuditStock_Theorique" OWNER TO postgres;

COMMENT ON VIEW logistique."V_AuditStock_Theorique"
    IS 'Audit simple : compare T_Article.QteArticle avec le stock theorique issu de T_Mouvement.';


-- ============================================================================
-- V_Commande
-- ============================================================================

CREATE OR REPLACE VIEW logistique."V_Commande" AS
SELECT c."DateHeureAutoCmd",
    c."DateCmd",
    c."ID_Commande",
    c."ID_TypeCmdFk",
    c."ID_StatutCmd",
    c."ID_ClientFk",
    c."ID_UserFk",
    u."NomUser",
    u."PrenomUser",
    TRIM(BOTH FROM CONCAT(COALESCE(u."PrenomUser", ''), ' ', COALESCE(u."NomUser", ''))) AS "NomComplet",
    c."CodeCmd",
    c."RefCmd",
    c."CodeFacture",
    c."MontantHT",
    c."MontantTTC",
    c."MontantRegleFacture",
    c."MontantResteFacture",
    c."ObsCmd",
    c."StatusFacture"
FROM logistique."T_Commande" c
LEFT JOIN systeme."T_Utilisateurs" u ON c."ID_UserFk" = u."IdUser";

ALTER TABLE logistique."V_Commande" OWNER TO postgres;


-- ============================================================================
-- V_CommandeDetail
-- ============================================================================

CREATE OR REPLACE VIEW logistique."V_CommandeDetail" AS
SELECT d."ID_CmdFk",
    c."ID_TypeCmdFk",
    c."ID_StatutCmd",
    c."DateCmd",
    c."CodeCmd",
    c."CodeFacture",
    d."ID_ArticleFk",
    a."CodeArticleInterne",
    a."NomArticle",
    d."QteCmdDetail",
    d."PUCmdDetail",
    d."ObsCmdDetail",
    d."RemiseCmdDetail",
    d."LieuCmdDetail",
    d."SelectCmdDetail"
FROM logistique."T_CommandeDetail" d
JOIN logistique."T_Commande" c ON c."ID_Commande" = d."ID_CmdFk"
JOIN logistique."T_Article" a ON a."ID_Article" = d."ID_ArticleFk";

ALTER TABLE logistique."V_CommandeDetail" OWNER TO postgres;


-- ============================================================================
-- V_CommandeOverview
-- ============================================================================

CREATE OR REPLACE VIEW logistique."V_CommandeOverview" AS
SELECT c."ID_Commande",
    c."DateCmd",
    c."MontantHT",
    c."MontantTTC",
    c."StatusFacture"
FROM logistique."T_Commande" c;

ALTER TABLE logistique."V_CommandeOverview" OWNER TO postgres;

COMMENT ON VIEW logistique."V_CommandeOverview"
    IS 'Vue synthetique des commandes : montants HT/TTC et statut de facturation.';


-- ============================================================================
-- V_CommandesSansDetails
-- ============================================================================

CREATE OR REPLACE VIEW logistique."V_CommandesSansDetails" AS
SELECT c."ID_Commande",
    c."CodeCmd"
FROM logistique."T_Commande" c
LEFT JOIN logistique."T_CommandeDetail" d ON d."ID_CmdFk" = c."ID_Commande"
WHERE d."ID_CmdFk" IS NULL
  AND COALESCE(c."CodeCmd", '') NOT IN ('C_000E', 'C_000S');

ALTER TABLE logistique."V_CommandesSansDetails" OWNER TO postgres;

COMMENT ON VIEW logistique."V_CommandesSansDetails"
    IS 'Commandes sans detail, hors commandes techniques historiques.';


-- ============================================================================
-- V_ConsoMensuelle
-- ============================================================================

CREATE OR REPLACE VIEW logistique."V_ConsoMensuelle" AS
SELECT a."ID_Article",
    a."NomArticle",
    date_trunc('month'::text, m."DateMvt") AS "Mois",
    SUM(
        CASE
            WHEN g."AbrGenerique"::text ~~* 'sort%'::text THEN m."QteMvt"
            ELSE 0
        END
    ) AS "ConsoMensuelle"
FROM logistique."T_Mouvement" m
JOIN logistique."T_Article" a ON a."ID_Article" = m."ID_ArticleFk"
LEFT JOIN referentiel."T_Generique" g ON g."ID_Generique" = m."ID_TypeMvtFk"
GROUP BY a."ID_Article", a."NomArticle", date_trunc('month'::text, m."DateMvt");

ALTER TABLE logistique."V_ConsoMensuelle" OWNER TO postgres;

COMMENT ON VIEW logistique."V_ConsoMensuelle"
    IS 'Consommation mensuelle par article : somme des mouvements de type Sortie.';


-- ============================================================================
-- V_CouvertureStock
-- ============================================================================

CREATE OR REPLACE VIEW logistique."V_CouvertureStock" AS
WITH conso AS (
    SELECT m."ID_ArticleFk",
        SUM(
            CASE
                WHEN g."AbrGenerique"::text ~~* 'sort%'::text THEN m."QteMvt"
                ELSE 0
            END
        ) AS conso_6m
    FROM logistique."T_Mouvement" m
    LEFT JOIN referentiel."T_Generique" g ON g."ID_Generique" = m."ID_TypeMvtFk"
    WHERE m."DateMvt" >= (CURRENT_DATE - '6 mons'::interval)
    GROUP BY m."ID_ArticleFk"
)
SELECT a."ID_Article",
    a."NomArticle",
    a."QteArticle" AS "StockActuel",
    conso.conso_6m AS "Conso6Mois",
    ROUND(conso.conso_6m::numeric / 6.0, 2) AS "ConsoMoyMensuelle",
    CASE
        WHEN conso.conso_6m = 0 THEN NULL::numeric
        ELSE ROUND(a."QteArticle" / (conso.conso_6m::numeric / 6.0), 1)
    END AS "CouvertureMois"
FROM logistique."T_Article" a
LEFT JOIN conso ON conso."ID_ArticleFk" = a."ID_Article";

ALTER TABLE logistique."V_CouvertureStock" OWNER TO postgres;

COMMENT ON VIEW logistique."V_CouvertureStock"
    IS 'Couverture de stock estimee en mois a partir de la consommation des 6 derniers mois.';


-- ============================================================================
-- V_Mouvement
-- ============================================================================

CREATE OR REPLACE VIEW logistique."V_Mouvement" AS
SELECT m."DateHeureAutoMvt",
    m."DateMvt",
    m."ID_Mvt",
    m."ID_TypeMvtFk",
    g_typemvt."AbrGenerique" AS "TypeMvt",
    m."ID_ArticleFk",
    a."NomArticle",
    m."ID_cmdFk",
    c."CodeCmd",
    m."QteMvt",
    m."PUMvt"
FROM logistique."T_Mouvement" m
JOIN logistique."T_Article" a ON m."ID_ArticleFk" = a."ID_Article"
LEFT JOIN logistique."T_Commande" c ON m."ID_cmdFk" = c."ID_Commande"
LEFT JOIN referentiel."T_Generique" g_typemvt ON m."ID_TypeMvtFk" = g_typemvt."ID_Generique";

ALTER TABLE logistique."V_Mouvement" OWNER TO postgres;


-- ============================================================================
-- V_MouvementStock
-- ============================================================================

CREATE OR REPLACE VIEW logistique."V_MouvementStock" AS
SELECT m."ID_Mvt",
    m."ID_ArticleFk",
    m."ID_cmdFk",
    m."DateMvt",
    m."QteMvt",
    m."PUMvt",
    COALESCE(c."ID_TypeCmdFk", m."ID_TypeMvtFk") AS "ID_TypeMvt",
    COALESCE(g."AbrGenerique", g2."AbrGenerique") AS "AbrTypeMvt",
    CASE
        WHEN COALESCE(g."AbrGenerique", g2."AbrGenerique")::text ~~* 'entr%'::text THEN 1
        WHEN COALESCE(g."AbrGenerique", g2."AbrGenerique")::text ~~* 'sort%'::text THEN -1
        ELSE 0
    END AS "SigneStock",
    (m."QteMvt" *
        CASE
            WHEN COALESCE(g."AbrGenerique", g2."AbrGenerique")::text ~~* 'entr%'::text THEN 1
            WHEN COALESCE(g."AbrGenerique", g2."AbrGenerique")::text ~~* 'sort%'::text THEN -1
            ELSE 0
        END)::numeric AS "QteMvtSigned"
FROM logistique."T_Mouvement" m
LEFT JOIN logistique."T_Commande" c ON c."ID_Commande" = m."ID_cmdFk"
LEFT JOIN referentiel."T_Generique" g ON g."ID_Generique" = c."ID_TypeCmdFk"
LEFT JOIN referentiel."T_Generique" g2 ON g2."ID_Generique" = m."ID_TypeMvtFk";

ALTER TABLE logistique."V_MouvementStock" OWNER TO postgres;

COMMENT ON VIEW logistique."V_MouvementStock"
    IS 'Vue des mouvements avec quantite signee selon Entree/Sortie.';


-- ============================================================================
-- V_SuiviReglements
-- ============================================================================

CREATE OR REPLACE VIEW logistique."V_SuiviReglements" AS
SELECT c."ID_Commande",
    c."CodeFacture",
    c."MontantTTC",
    COALESCE(SUM(r."MontantRegle"), 0::numeric) AS "TotalRegle",
    c."MontantTTC" - COALESCE(SUM(r."MontantRegle"), 0::numeric) AS "Reste"
FROM logistique."T_Commande" c
LEFT JOIN logistique."T_Reglements" r ON r."CodeFactureFk"::text = c."CodeFacture"::text
GROUP BY c."ID_Commande", c."CodeFacture", c."MontantTTC";

ALTER TABLE logistique."V_SuiviReglements" OWNER TO postgres;

COMMENT ON VIEW logistique."V_SuiviReglements"
    IS 'Suivi des reglements : total regle et reste a payer par facture.';
