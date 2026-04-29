-- View: logistique.V_AlertStock
-- DROP VIEW logistique."V_AlertStock";
CREATE OR REPLACE VIEW logistique."V_AlertStock" AS
SELECT "ID_Article",
    "NomArticle",
    "QteArticle",
    "QteMinArticle",
    "QteArticle" - "QteMinArticle"::numeric AS "Marge"
FROM logistique."T_Article" a
WHERE "QteMinArticle" IS NOT NULL;
ALTER TABLE logistique."V_AlertStock" OWNER TO postgres;
-- View: logistique.V_Article
-- DROP VIEW logistique."V_Article";
CREATE OR REPLACE VIEW logistique."V_Article" AS
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
    a."ID_CategorieArticleFk",
    categorie_article."AbrGenerique" AS "AbrCategorieArticle",
    a."ID_UniteFk",
    unite."AbrGenerique" AS "AbrUnite",
    a."QteArticle",
    a."QteMinArticle",
    CASE
        WHEN COALESCE(a."QteArticle", 0::numeric) <= 0::numeric THEN 'Rupture'::text
        WHEN a."QteMinArticle" IS NOT NULL
        AND a."QteArticle" <= a."QteMinArticle"::numeric THEN 'Stock faible'::text
        ELSE 'Disponible'::text
    END AS "EtatStock",
    CASE
        WHEN COALESCE(a."QteArticle", 0::numeric) <= 0::numeric THEN true
        ELSE false
    END AS "EstRupture",
    CASE
        WHEN a."QteMinArticle" IS NOT NULL
        AND a."QteArticle" <= a."QteMinArticle"::numeric THEN true
        ELSE false
    END AS "EstAlerteStock",
    a."PUArticle",
    a."PVArticle",
    COALESCE(a."QteArticle", 0::numeric) * COALESCE(a."PUArticle", 0::numeric) AS "ValeurStockAchat",
    COALESCE(a."QteArticle", 0::numeric) * COALESCE(a."PVArticle", 0::numeric) AS "ValeurStockVente",
    COALESCE(a."PVArticle", 0::numeric) - COALESCE(a."PUArticle", 0::numeric) AS "MargeUnitaire",
    CASE
        WHEN COALESCE(a."PUArticle", 0::numeric) = 0::numeric THEN NULL::numeric
        ELSE round(
            (
                COALESCE(a."PVArticle", 0::numeric) - COALESCE(a."PUArticle", 0::numeric)
            ) / NULLIF(a."PUArticle", 0::numeric) * 100::numeric,
            2
        )
    END AS "TauxMargePct",
    a."DatePeremptionArticle",
    a."DatePeremptionAlerteArticle",
    a."NbreJoursAlerteArticle",
    CASE
        WHEN a."DatePeremptionArticle" IS NULL THEN 'Non renseignée'::text
        WHEN a."DatePeremptionArticle" < now() THEN 'Périmé'::text
        WHEN a."DatePeremptionAlerteArticle" IS NOT NULL
        AND a."DatePeremptionAlerteArticle" <= now() THEN 'Alerte péremption'::text
        WHEN a."NbreJoursAlerteArticle" IS NOT NULL
        AND a."DatePeremptionArticle" <= (
            now() + (
                (a."NbreJoursAlerteArticle" || ' days'::text)::interval
            )
        ) THEN 'Alerte péremption'::text
        ELSE 'Valide'::text
    END AS "EtatPeremption",
    CASE
        WHEN a."DatePeremptionArticle" IS NOT NULL THEN date_part('day'::text, a."DatePeremptionArticle" - now())::integer
        ELSE NULL::integer
    END AS "JoursAvantPeremption",
    a."ID_UserFK",
    u."IdUser",
    NULLIF(
        TRIM(
            BOTH
            FROM concat(
                    COALESCE(u."PrenomUser", ''::character varying),
                    ' ',
                    COALESCE(u."NomUser", ''::character varying)
                )
        ),
        ''::text
    ) AS "NomComplet"
FROM logistique."T_Article" a
    LEFT JOIN referentiel."T_Generique" type_article ON a."ID_TypeArticleFk" = type_article."ID_Generique"
        AND type_article."ID_CategorieGeneriqueFk" = 46
    LEFT JOIN referentiel."T_Generique" categorie_article ON a."ID_CategorieArticleFk" = categorie_article."ID_Generique"
        AND categorie_article."ID_CategorieGeneriqueFk" = 40
    LEFT JOIN referentiel."T_Generique" unite ON a."ID_UniteFk" = unite."ID_Generique"
        AND unite."ID_CategorieGeneriqueFk" = 34
    LEFT JOIN systeme."T_Utilisateurs" u ON a."ID_UserFK" = u."IdUser";
ALTER TABLE logistique."V_Article" OWNER TO postgres;
-- View: logistique.V_AuditStock
-- DROP VIEW logistique."V_AuditStock";
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
FROM logistique.fn_audit_stock(NULL::integer, NULL::timestamp without time zone) fn_audit_stock(
        "ID_Article",
        "CodeArticleInterne",
        "NomArticle",
        "StockArticle",
        "StockMouvements",
        "Ecart",
        "N_Mouvements",
        "QteEntree",
        "QteSortie"
    );
ALTER TABLE logistique."V_AuditStock" OWNER TO postgres;
-- View: logistique.V_AuditStock_Theorique
-- DROP VIEW logistique."V_AuditStock_Theorique";
CREATE OR REPLACE VIEW logistique."V_AuditStock_Theorique" AS WITH mvt AS (
        SELECT m."ID_ArticleFk",
            sum(
                CASE
                    WHEN g."AbrGenerique"::text ~~* 'entr%'::text THEN m."QteMvt"
                    WHEN g."AbrGenerique"::text ~~* 'sort%'::text THEN - m."QteMvt"
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
-- View: logistique.V_Commande
-- DROP VIEW logistique."V_Commande";
CREATE OR REPLACE VIEW logistique."V_Commande" AS
SELECT c."ID_Commande",
    c."DateHeureAutoCmd",
    c."DateCmd",
    c."ID_TypeCmdFk",
    type_cmd."AbrGenerique" AS "AbrTypeCmd",
    c."ID_StatutCmdFk",
    c."ID_StatutCmdFk" AS "ID_StatutCmd",
    statut_cmd."AbrGenerique" AS "AbrStatutCmd",
    c."ID_ClientFk",
    c."ID_UserFk",
    u."NomUser",
    u."PrenomUser",
    NULLIF(
        TRIM(
            BOTH
            FROM concat(
                    COALESCE(u."PrenomUser", ''::character varying),
                    ' ',
                    COALESCE(u."NomUser", ''::character varying)
                )
        ),
        ''::text
    ) AS "NomComplet",
    c."CodeCmd",
    c."RefCmd",
    c."geolocalisationCmd",
    c."UrlBL",
    c."ObsCmd",
    c."SelectCmd",
    COALESCE(c."MontantHT", 0::numeric) AS "MontantHT",
    COALESCE(c."MontantTTC", 0::numeric) AS "MontantTTC",
    c."DateHeureAutoFacture",
    c."DateFacture",
    c."CodeFacture",
    COALESCE(c."MontantRegleFacture", 0::numeric) AS "MontantRegleFacture",
    COALESCE(c."MontantResteFacture", 0::numeric) AS "MontantResteFacture",
    c."StatusFacture",
    c."ValideRemiseFacture",
    c."UrlFacture",
    c."ID_ConditionPaiementFk",
    condition_paiement."AbrGenerique" AS "AbrConditionPaiement",
    condition_paiement."NomGenerique" AS "ConditionPaiement",
    c."ID_ModePaiementFk",
    mode_paiement."AbrGenerique" AS "AbrModePaiement",
    mode_paiement."NomGenerique" AS "ModePaiement",
    c."DateEcheancePaiement",
    CASE
        WHEN c."CodeFacture" IS NULL THEN 'Non facturée'::text
        WHEN COALESCE(c."MontantTTC", 0::numeric) = 0::numeric THEN 'Montant nul'::text
        WHEN COALESCE(c."MontantRegleFacture", 0::numeric) <= 0::numeric THEN 'Non réglée'::text
        WHEN COALESCE(c."MontantRegleFacture", 0::numeric) < COALESCE(c."MontantTTC", 0::numeric) THEN 'Partiellement réglée'::text
        WHEN COALESCE(c."MontantRegleFacture", 0::numeric) >= COALESCE(c."MontantTTC", 0::numeric) THEN 'Réglée'::text
        ELSE 'Indéterminé'::text
    END AS "EtatPaiement",
    CASE
        WHEN c."DateEcheancePaiement" IS NOT NULL
        AND c."DateEcheancePaiement" < now()
        AND COALESCE(c."MontantResteFacture", 0::numeric) > 0::numeric THEN true
        ELSE false
    END AS "EstPaiementEnRetard",
    CASE
        WHEN c."DateEcheancePaiement" IS NOT NULL THEN date_part('day'::text, c."DateEcheancePaiement" - now())::integer
        ELSE NULL::integer
    END AS "JoursAvantEcheance",
    CASE
        WHEN type_cmd."AbrGenerique"::text = 'Entrée'::text THEN true
        ELSE false
    END AS "EstCommandeEntree",
    CASE
        WHEN type_cmd."AbrGenerique"::text = 'Sortie'::text THEN true
        ELSE false
    END AS "EstCommandeSortie",
    COALESCE(cd_stats."NbLignes", 0::bigint) AS "NbLignes",
    COALESCE(cd_stats."NbArticlesDistincts", 0::bigint) AS "NbArticlesDistincts",
    COALESCE(cd_stats."QteTotale", 0::numeric) AS "QteTotale",
    COALESCE(cd_stats."MontantDetails", 0::numeric) AS "MontantDetails",
    CASE
        WHEN COALESCE(cd_stats."NbLignes", 0::bigint) = 0 THEN true
        ELSE false
    END AS "EstCommandeSansDetails",
    COALESCE(c."MontantHT", 0::numeric) - COALESCE(cd_stats."MontantDetails", 0::numeric) AS "EcartMontantDetails",
    CASE
        WHEN abs(
            COALESCE(c."MontantHT", 0::numeric) - COALESCE(cd_stats."MontantDetails", 0::numeric)
        ) > 0.01 THEN true
        ELSE false
    END AS "EstMontantIncoherent"
FROM logistique."T_Commande" c
    LEFT JOIN systeme."T_Utilisateurs" u ON c."ID_UserFk" = u."IdUser"
    LEFT JOIN referentiel."T_Generique" type_cmd ON c."ID_TypeCmdFk" = type_cmd."ID_Generique"
        AND type_cmd."ID_CategorieGeneriqueFk" = 64
    LEFT JOIN referentiel."T_Generique" statut_cmd ON c."ID_StatutCmdFk" = statut_cmd."ID_Generique"
        AND statut_cmd."ID_CategorieGeneriqueFk" = 28
    LEFT JOIN referentiel."T_Generique" condition_paiement ON c."ID_ConditionPaiementFk" = condition_paiement."ID_Generique"
        AND condition_paiement."ID_CategorieGeneriqueFk" = 37
    LEFT JOIN referentiel."T_Generique" mode_paiement ON c."ID_ModePaiementFk" = mode_paiement."ID_Generique"
        AND mode_paiement."ID_CategorieGeneriqueFk" = 36
    LEFT JOIN (
        SELECT cd."ID_CmdFk",
            count(*) AS "NbLignes",
            count(DISTINCT cd."ID_ArticleFk") AS "NbArticlesDistincts",
            sum(COALESCE(cd."QteCmdDetail", 0::numeric)) AS "QteTotale",
            sum(
                COALESCE(cd."QteCmdDetail", 0::numeric) * COALESCE(cd."PUCmdDetail", 0::numeric)
            ) AS "MontantDetails"
        FROM logistique."T_CommandeDetail" cd
        GROUP BY cd."ID_CmdFk"
    ) cd_stats ON cd_stats."ID_CmdFk" = c."ID_Commande";
ALTER TABLE logistique."V_Commande" OWNER TO postgres;
-- View: logistique.V_CommandeDetail
-- DROP VIEW logistique."V_CommandeDetail";
CREATE OR REPLACE VIEW logistique."V_CommandeDetail" AS
SELECT d."ID_CmdFk",
    c."ID_TypeCmdFk",
    c."ID_StatutCmdFk",
    c."ID_StatutCmdFk" AS "ID_StatutCmd",
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
-- View: logistique.V_CommandeOverview
-- DROP VIEW logistique."V_CommandeOverview";
CREATE OR REPLACE VIEW logistique."V_CommandeOverview" AS
SELECT "ID_Commande",
    "DateCmd",
    "MontantHT",
    "MontantTTC",
    "StatusFacture"
FROM logistique."T_Commande" c;
ALTER TABLE logistique."V_CommandeOverview" OWNER TO postgres;
-- View: logistique.V_CommandesSansDetails
-- DROP VIEW logistique."V_CommandesSansDetails";
CREATE OR REPLACE VIEW logistique."V_CommandesSansDetails" AS
SELECT c."ID_Commande",
    c."CodeCmd"
FROM logistique."T_Commande" c
    LEFT JOIN logistique."T_CommandeDetail" d ON d."ID_CmdFk" = c."ID_Commande"
WHERE d."ID_CmdFk" IS NULL
    AND (
        COALESCE(c."CodeCmd", ''::character varying)::text <> ALL (
            ARRAY ['C_000E'::character varying, 'C_000S'::character varying]::text []
        )
    );
ALTER TABLE logistique."V_CommandesSansDetails" OWNER TO postgres;
-- View: logistique.V_ConsoMensuelle
-- DROP VIEW logistique."V_ConsoMensuelle";
CREATE OR REPLACE VIEW logistique."V_ConsoMensuelle" AS
SELECT a."ID_Article",
    a."NomArticle",
    date_trunc('month'::text, m."DateMvt") AS "Mois",
    sum(
        CASE
            WHEN g."AbrGenerique"::text ~~* 'sort%'::text THEN m."QteMvt"
            ELSE 0
        END
    ) AS "ConsoMensuelle"
FROM logistique."T_Mouvement" m
    JOIN logistique."T_Article" a ON a."ID_Article" = m."ID_ArticleFk"
    LEFT JOIN referentiel."T_Generique" g ON g."ID_Generique" = m."ID_TypeMvtFk"
GROUP BY a."ID_Article",
    a."NomArticle",
    (date_trunc('month'::text, m."DateMvt"));
ALTER TABLE logistique."V_ConsoMensuelle" OWNER TO postgres;
-- View: logistique.V_CouvertureStock
-- DROP VIEW logistique."V_CouvertureStock";
CREATE OR REPLACE VIEW logistique."V_CouvertureStock" AS WITH conso AS (
        SELECT m."ID_ArticleFk",
            sum(
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
    round(conso.conso_6m::numeric / 6.0, 2) AS "ConsoMoyMensuelle",
    CASE
        WHEN conso.conso_6m = 0 THEN NULL::numeric
        ELSE round(
            a."QteArticle" / (conso.conso_6m::numeric / 6.0),
            1
        )
    END AS "CouvertureMois"
FROM logistique."T_Article" a
    LEFT JOIN conso ON conso."ID_ArticleFk" = a."ID_Article";
ALTER TABLE logistique."V_CouvertureStock" OWNER TO postgres;
-- View: logistique.V_Mouvement
-- DROP VIEW logistique."V_Mouvement";
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
    LEFT JOIN logistique."T_Article" a ON m."ID_ArticleFk" = a."ID_Article"
    LEFT JOIN logistique."T_Commande" c ON m."ID_cmdFk" = c."ID_Commande"
    LEFT JOIN referentiel."T_Generique" g_typemvt ON m."ID_TypeMvtFk" = g_typemvt."ID_Generique"
        AND g_typemvt."ID_CategorieGeneriqueFk" = 64;
ALTER TABLE logistique."V_Mouvement" OWNER TO postgres;
-- View: logistique.V_MouvementStock
-- DROP VIEW logistique."V_MouvementStock";
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
        WHEN COALESCE(g."AbrGenerique", g2."AbrGenerique")::text ~~* 'sort%'::text THEN '-1'::integer
        ELSE 0
    END AS "SigneStock",
    (
        m."QteMvt" * CASE
            WHEN COALESCE(g."AbrGenerique", g2."AbrGenerique")::text ~~* 'entr%'::text THEN 1
            WHEN COALESCE(g."AbrGenerique", g2."AbrGenerique")::text ~~* 'sort%'::text THEN '-1'::integer
            ELSE 0
        END
    )::numeric AS "QteMvtSigned"
FROM logistique."T_Mouvement" m
    LEFT JOIN logistique."T_Commande" c ON c."ID_Commande" = m."ID_cmdFk"
    LEFT JOIN referentiel."T_Generique" g ON g."ID_Generique" = c."ID_TypeCmdFk"
        AND g."ID_CategorieGeneriqueFk" = 64
    LEFT JOIN referentiel."T_Generique" g2 ON g2."ID_Generique" = m."ID_TypeMvtFk"
        AND g2."ID_CategorieGeneriqueFk" = 64;
ALTER TABLE logistique."V_MouvementStock" OWNER TO postgres;
-- View: logistique.V_SuiviReglements
-- DROP VIEW logistique."V_SuiviReglements";
CREATE OR REPLACE VIEW logistique."V_SuiviReglements" AS
SELECT c."ID_Commande",
    c."CodeFacture",
    c."MontantTTC",
    COALESCE(sum(r."MontantRegle"), 0::numeric) AS "TotalRegle",
    c."MontantTTC" - COALESCE(sum(r."MontantRegle"), 0::numeric) AS "Reste"
FROM logistique."T_Commande" c
    LEFT JOIN logistique."T_Reglements" r ON r."CodeFactureFk"::text = c."CodeFacture"::text
GROUP BY c."ID_Commande",
    c."CodeFacture",
    c."MontantTTC";
ALTER TABLE logistique."V_SuiviReglements" OWNER TO postgres;
