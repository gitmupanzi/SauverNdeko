/* ============================================================================
 VUES LOGISTIQUES AMELIOREES
 SauverNdeko - module logistique
 
 Objectifs :
 - rendre les vues plus utiles pour le frontend ;
 - fiabiliser les calculs stock, paiement et montants ;
 - aligner les vues analytiques sur le scenario metier valide ;
 - utiliser T_Mouvement.ID_TypeMvtFk comme verite historique du mouvement ;
 - garder les noms de vues existants.
 ============================================================================ */
BEGIN;
/* ============================================================================
 0. SUPPRESSION DES VUES EXISTANTES
 ============================================================================ */
DROP VIEW IF EXISTS logistique."V_AuditStock";
DROP VIEW IF EXISTS logistique."V_AuditStock_Theorique";
DROP VIEW IF EXISTS logistique."V_AlertStock";
DROP VIEW IF EXISTS logistique."V_Article";
DROP VIEW IF EXISTS logistique."V_CommandeDetail";
DROP VIEW IF EXISTS logistique."V_CommandeOverview";
DROP VIEW IF EXISTS logistique."V_CommandesSansDetails";
DROP VIEW IF EXISTS logistique."V_ConsoMensuelle";
DROP VIEW IF EXISTS logistique."V_CouvertureStock";
DROP VIEW IF EXISTS logistique."V_Mouvement";
DROP VIEW IF EXISTS logistique."V_SuiviReglements";
DROP VIEW IF EXISTS logistique."V_Commande";
DROP VIEW IF EXISTS logistique."V_MouvementStock";
/* ============================================================================
 1. V_MOUVEMENTSTOCK
 Verite historique : T_Mouvement.ID_TypeMvtFk.
 La commande est jointe uniquement pour contexte, pas pour determiner le signe.
 ============================================================================ */
CREATE OR REPLACE VIEW logistique."V_MouvementStock" AS
SELECT m."ID_Mvt",
    m."ID_ArticleFk",
    a."CodeArticleInterne",
    a."NomArticle",
    m."ID_cmdFk",
    c."CodeCmd",
    c."DateCmd",
    c."ID_TypeCmdFk" AS "ID_TypeCmdActuel",
    m."DateHeureAutoMvt",
    m."DateMvt",
    m."ID_TypeMvtFk"::integer AS "ID_TypeMvt",
    g."AbrGenerique" AS "AbrTypeMvt",
    g."NomGenerique" AS "TypeMvt",
    COALESCE(m."QteMvt", 0)::integer AS "QteMvt",
    COALESCE(m."PUMvt", 0)::numeric(12, 2) AS "PUMvt",
    CASE
        WHEN g."AbrGenerique" ILIKE 'entr%' THEN 1
        WHEN g."AbrGenerique" ILIKE 'sort%' THEN -1
        ELSE 0
    END::integer AS "SigneStock",
    (
        COALESCE(m."QteMvt", 0) * CASE
            WHEN g."AbrGenerique" ILIKE 'entr%' THEN 1
            WHEN g."AbrGenerique" ILIKE 'sort%' THEN -1
            ELSE 0
        END
    )::numeric AS "QteMvtSigned",
    (
        COALESCE(m."QteMvt", 0)::numeric * COALESCE(m."PUMvt", 0)::numeric
    )::numeric(14, 2) AS "MontantMvt",
    (
        COALESCE(m."QteMvt", 0)::numeric * COALESCE(m."PUMvt", 0)::numeric * CASE
            WHEN g."AbrGenerique" ILIKE 'entr%' THEN 1
            WHEN g."AbrGenerique" ILIKE 'sort%' THEN -1
            ELSE 0
        END
    )::numeric(14, 2) AS "MontantMvtSigned",
    CASE
        WHEN m."ID_cmdFk" IS NULL THEN 'Ajustement direct article'::text
        ELSE 'Commande'::text
    END AS "OrigineMouvement"
FROM logistique."T_Mouvement" m
    LEFT JOIN logistique."T_Article" a ON a."ID_Article" = m."ID_ArticleFk"
    LEFT JOIN logistique."T_Commande" c ON c."ID_Commande" = m."ID_cmdFk"
    LEFT JOIN referentiel."T_Generique" g ON g."ID_Generique" = m."ID_TypeMvtFk"
    AND g."ID_CategorieGeneriqueFk" = 64;
/* ============================================================================
 2. V_ARTICLE
 Vue complete pour catalogue, stock, valorisation et peremption.
 ============================================================================ */
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
    type_article."NomGenerique" AS "TypeArticle",
    a."ID_CategorieArticleFk",
    categorie_article."AbrGenerique" AS "AbrCategorieArticle",
    categorie_article."NomGenerique" AS "CategorieArticle",
    a."ID_UniteFk",
    unite."AbrGenerique" AS "AbrUnite",
    unite."NomGenerique" AS "Unite",
    COALESCE(a."QteArticle", 0)::numeric(14, 3) AS "QteArticle",
    a."QteMinArticle",
    GREATEST(
        COALESCE(a."QteMinArticle", 0)::numeric - COALESCE(a."QteArticle", 0)::numeric,
        0::numeric
    )::numeric(14, 3) AS "QteACommander",
    CASE
        WHEN COALESCE(a."QteArticle", 0::numeric) <= 0::numeric THEN 'Rupture'::text
        WHEN a."QteMinArticle" IS NOT NULL
        AND COALESCE(a."QteArticle", 0::numeric) <= a."QteMinArticle"::numeric THEN 'Stock faible'::text
        ELSE 'Disponible'::text
    END AS "EtatStock",
    (
        COALESCE(a."QteArticle", 0::numeric) <= 0::numeric
    ) AS "EstRupture",
    (
        a."QteMinArticle" IS NOT NULL
        AND COALESCE(a."QteArticle", 0::numeric) <= a."QteMinArticle"::numeric
    ) AS "EstAlerteStock",
    CASE
        WHEN COALESCE(a."QteArticle", 0::numeric) <= 0::numeric THEN 1
        WHEN a."QteMinArticle" IS NOT NULL
        AND COALESCE(a."QteArticle", 0::numeric) <= a."QteMinArticle"::numeric THEN 2
        ELSE 3
    END AS "PrioriteStock",
    COALESCE(a."PUArticle", 0)::numeric(12, 2) AS "PUArticle",
    COALESCE(a."PVArticle", 0)::numeric(12, 2) AS "PVArticle",
    (
        COALESCE(a."QteArticle", 0::numeric) * COALESCE(a."PUArticle", 0::numeric)
    )::numeric(14, 2) AS "ValeurStockAchat",
    (
        COALESCE(a."QteArticle", 0::numeric) * COALESCE(a."PVArticle", 0::numeric)
    )::numeric(14, 2) AS "ValeurStockVente",
    (
        COALESCE(a."PVArticle", 0::numeric) - COALESCE(a."PUArticle", 0::numeric)
    )::numeric(12, 2) AS "MargeUnitaire",
    CASE
        WHEN COALESCE(a."PUArticle", 0::numeric) = 0::numeric THEN NULL::numeric
        ELSE ROUND(
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
        WHEN a."DatePeremptionArticle"::date < CURRENT_DATE THEN 'Périmé'::text
        WHEN a."DatePeremptionAlerteArticle" IS NOT NULL
        AND a."DatePeremptionAlerteArticle"::date <= CURRENT_DATE THEN 'Alerte péremption'::text
        WHEN a."NbreJoursAlerteArticle" IS NOT NULL
        AND a."DatePeremptionArticle"::date <= CURRENT_DATE + a."NbreJoursAlerteArticle" THEN 'Alerte péremption'::text
        ELSE 'Valide'::text
    END AS "EtatPeremption",
    CASE
        WHEN a."DatePeremptionArticle" IS NOT NULL THEN (a."DatePeremptionArticle"::date - CURRENT_DATE)::integer
        ELSE NULL::integer
    END AS "JoursAvantPeremption",
    (
        a."DatePeremptionArticle" IS NOT NULL
        AND a."DatePeremptionArticle"::date < CURRENT_DATE
    ) AS "EstPerime",
    (
        a."DatePeremptionArticle" IS NOT NULL
        AND a."DatePeremptionArticle"::date >= CURRENT_DATE
        AND (
            (
                a."DatePeremptionAlerteArticle" IS NOT NULL
                AND a."DatePeremptionAlerteArticle"::date <= CURRENT_DATE
            )
            OR (
                a."NbreJoursAlerteArticle" IS NOT NULL
                AND a."DatePeremptionArticle"::date <= CURRENT_DATE + a."NbreJoursAlerteArticle"
            )
        )
    ) AS "EstAlertePeremption",
    CASE
        WHEN a."DatePeremptionArticle" IS NULL THEN 4
        WHEN a."DatePeremptionArticle"::date < CURRENT_DATE THEN 1
        WHEN (
            a."DatePeremptionAlerteArticle" IS NOT NULL
            AND a."DatePeremptionAlerteArticle"::date <= CURRENT_DATE
        )
        OR (
            a."NbreJoursAlerteArticle" IS NOT NULL
            AND a."DatePeremptionArticle"::date <= CURRENT_DATE + a."NbreJoursAlerteArticle"
        ) THEN 2
        ELSE 3
    END AS "PrioritePeremption",
    a."ID_UserFK",
    u."IdUser",
    NULLIF(
        TRIM(
            BOTH
            FROM concat(
                    COALESCE(u."PrenomUser", ''),
                    ' ',
                    COALESCE(u."NomUser", '')
                )
        ),
        ''
    ) AS "NomComplet",
    CASE
        WHEN COALESCE(a."ValideArticle", true) = false THEN 'Inactif'::text
        ELSE 'Actif'::text
    END AS "EtatArticle"
FROM logistique."T_Article" a
    LEFT JOIN referentiel."T_Generique" type_article ON a."ID_TypeArticleFk" = type_article."ID_Generique"
    AND type_article."ID_CategorieGeneriqueFk" = 46
    LEFT JOIN referentiel."T_Generique" categorie_article ON a."ID_CategorieArticleFk" = categorie_article."ID_Generique"
    AND categorie_article."ID_CategorieGeneriqueFk" = 40
    LEFT JOIN referentiel."T_Generique" unite ON a."ID_UniteFk" = unite."ID_Generique"
    AND unite."ID_CategorieGeneriqueFk" = 34
    LEFT JOIN systeme."T_Utilisateurs" u ON a."ID_UserFK" = u."IdUser";
/* ============================================================================
 3. V_COMMANDE
 Vue principale pour liste de commandes, paiement, details et controle montant.
 ============================================================================ */
CREATE OR REPLACE VIEW logistique."V_Commande" AS WITH cd_stats AS (
        SELECT cd."ID_CmdFk",
            COUNT(*) AS "NbLignes",
            COUNT(DISTINCT cd."ID_ArticleFk") AS "NbArticlesDistincts",
            SUM(COALESCE(cd."QteCmdDetail", 0::numeric)) AS "QteTotale",
            SUM(
                COALESCE(cd."QteCmdDetail", 0::numeric) * COALESCE(cd."PUCmdDetail", 0::numeric)
            ) AS "MontantDetails",
            string_agg(
                DISTINCT a."NomArticle"::text,
                ', '::text
                ORDER BY a."NomArticle"::text
            ) AS "ListeArticles"
        FROM logistique."T_CommandeDetail" cd
            LEFT JOIN logistique."T_Article" a ON a."ID_Article" = cd."ID_ArticleFk"
        GROUP BY cd."ID_CmdFk"
    ),
    reg_stats AS (
        SELECT r."CodeFactureFk",
            SUM(COALESCE(r."MontantRegle", 0::numeric)) AS "TotalRegleReel",
            COUNT(*) AS "NbReglements",
            MAX(r."DateReglement") AS "DernierReglement"
        FROM logistique."T_Reglements" r
        GROUP BY r."CodeFactureFk"
    )
SELECT c."ID_Commande",
    c."DateHeureAutoCmd",
    c."DateCmd",
    c."ID_TypeCmdFk",
    type_cmd."AbrGenerique" AS "AbrTypeCmd",
    type_cmd."NomGenerique" AS "TypeCmd",
    CASE
        WHEN type_cmd."AbrGenerique" ILIKE 'entr%' THEN 1
        WHEN type_cmd."AbrGenerique" ILIKE 'sort%' THEN -1
        ELSE 0
    END::integer AS "SigneCommande",
    (type_cmd."AbrGenerique" ILIKE 'entr%') AS "EstCommandeEntree",
    (type_cmd."AbrGenerique" ILIKE 'sort%') AS "EstCommandeSortie",
    c."ID_StatutCmdFk",
    c."ID_StatutCmdFk" AS "ID_StatutCmd",
    statut_cmd."AbrGenerique" AS "AbrStatutCmd",
    statut_cmd."NomGenerique" AS "StatutCmd",
    c."ID_ClientFk",
    c."NomClientSaisi",
    c."ID_UserFk",
    u."NomUser",
    u."PrenomUser",
    NULLIF(
        TRIM(
            BOTH
            FROM concat(
                    COALESCE(u."PrenomUser", ''),
                    ' ',
                    COALESCE(u."NomUser", '')
                )
        ),
        ''
    ) AS "NomComplet",
    c."CodeCmd",
    c."RefCmd",
    c."geolocalisationCmd",
    c."UrlBL",
    c."ObsCmd",
    c."SelectCmd",
    COALESCE(c."MontantHT", 0::numeric)::numeric(12, 2) AS "MontantHT",
    COALESCE(c."MontantTTC", 0::numeric)::numeric(12, 2) AS "MontantTTC",
    c."DateHeureAutoFacture",
    c."DateFacture",
    c."CodeFacture",
    COALESCE(c."MontantRegleFacture", 0::numeric)::numeric(12, 2) AS "MontantRegleFacture",
    COALESCE(c."MontantResteFacture", 0::numeric)::numeric(12, 2) AS "MontantResteFacture",
    COALESCE(reg_stats."TotalRegleReel", 0::numeric)::numeric(12, 2) AS "TotalRegleReel",
    (
        COALESCE(c."MontantTTC", 0::numeric) - COALESCE(reg_stats."TotalRegleReel", 0::numeric)
    )::numeric(12, 2) AS "ResteReel",
    COALESCE(reg_stats."NbReglements", 0)::bigint AS "NbReglements",
    reg_stats."DernierReglement",
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
        WHEN COALESCE(
            reg_stats."TotalRegleReel",
            COALESCE(c."MontantRegleFacture", 0::numeric),
            0::numeric
        ) <= 0::numeric THEN 'Non réglée'::text
        WHEN COALESCE(
            reg_stats."TotalRegleReel",
            COALESCE(c."MontantRegleFacture", 0::numeric),
            0::numeric
        ) < COALESCE(c."MontantTTC", 0::numeric) THEN 'Partiellement réglée'::text
        WHEN COALESCE(
            reg_stats."TotalRegleReel",
            COALESCE(c."MontantRegleFacture", 0::numeric),
            0::numeric
        ) >= COALESCE(c."MontantTTC", 0::numeric) THEN 'Réglée'::text
        ELSE 'Indéterminé'::text
    END AS "EtatPaiement",
    (
        c."DateEcheancePaiement" IS NOT NULL
        AND c."DateEcheancePaiement"::date < CURRENT_DATE
        AND (
            COALESCE(c."MontantTTC", 0::numeric) - COALESCE(
                reg_stats."TotalRegleReel",
                COALESCE(c."MontantRegleFacture", 0::numeric),
                0::numeric
            )
        ) > 0::numeric
    ) AS "EstPaiementEnRetard",
    CASE
        WHEN c."DateEcheancePaiement" IS NOT NULL THEN (c."DateEcheancePaiement"::date - CURRENT_DATE)::integer
        ELSE NULL::integer
    END AS "JoursAvantEcheance",
    COALESCE(cd_stats."NbLignes", 0)::bigint AS "NbLignes",
    COALESCE(cd_stats."NbArticlesDistincts", 0)::bigint AS "NbArticlesDistincts",
    COALESCE(cd_stats."QteTotale", 0::numeric)::numeric(14, 3) AS "QteTotale",
    COALESCE(cd_stats."MontantDetails", 0::numeric)::numeric(12, 2) AS "MontantDetails",
    cd_stats."ListeArticles",
    (COALESCE(cd_stats."NbLignes", 0) = 0) AS "EstCommandeSansDetails",
    (
        COALESCE(c."MontantHT", 0::numeric) - COALESCE(cd_stats."MontantDetails", 0::numeric)
    )::numeric(12, 2) AS "EcartMontantDetails",
    (
        ABS(
            COALESCE(c."MontantHT", 0::numeric) - COALESCE(cd_stats."MontantDetails", 0::numeric)
        ) > 0.01
    ) AS "EstMontantIncoherent",
    CASE
        WHEN COALESCE(cd_stats."NbLignes", 0) = 0 THEN 'Sans détails'::text
        WHEN ABS(
            COALESCE(c."MontantHT", 0::numeric) - COALESCE(cd_stats."MontantDetails", 0::numeric)
        ) > 0.01 THEN 'Montant incohérent'::text
        ELSE 'Cohérente'::text
    END AS "EtatControleCommande"
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
    LEFT JOIN cd_stats ON cd_stats."ID_CmdFk" = c."ID_Commande"
    LEFT JOIN reg_stats ON reg_stats."CodeFactureFk"::text = c."CodeFacture"::text;
/* ============================================================================
 4. V_COMMANDEDETAIL
 Vue detaillee pour lignes de commande.
 ============================================================================ */
CREATE OR REPLACE VIEW logistique."V_CommandeDetail" AS
SELECT d."ID_CmdFk",
    c."ID_Commande",
    c."DateCmd",
    c."CodeCmd",
    c."CodeFacture",
    c."ID_TypeCmdFk",
    type_cmd."AbrGenerique" AS "AbrTypeCmd",
    type_cmd."NomGenerique" AS "TypeCmd",
    CASE
        WHEN type_cmd."AbrGenerique" ILIKE 'entr%' THEN 1
        WHEN type_cmd."AbrGenerique" ILIKE 'sort%' THEN -1
        ELSE 0
    END::integer AS "SigneCommande",
    c."ID_StatutCmdFk",
    c."ID_StatutCmdFk" AS "ID_StatutCmd",
    statut_cmd."AbrGenerique" AS "AbrStatutCmd",
    statut_cmd."NomGenerique" AS "StatutCmd",
    d."ID_ArticleFk",
    a."CodeArticleInterne",
    a."NomArticle",
    a."ID_UniteFk",
    unite."AbrGenerique" AS "AbrUnite",
    COALESCE(a."QteArticle", 0)::numeric(14, 3) AS "StockActuel",
    CASE
        WHEN type_cmd."AbrGenerique" ILIKE 'sort%' THEN (
            COALESCE(a."QteArticle", 0::numeric) + COALESCE(d."QteCmdDetail", 0::numeric)
        )::numeric(14, 3)
        WHEN type_cmd."AbrGenerique" ILIKE 'entr%' THEN (
            COALESCE(a."QteArticle", 0::numeric) - COALESCE(d."QteCmdDetail", 0::numeric)
        )::numeric(14, 3)
        ELSE COALESCE(a."QteArticle", 0::numeric)::numeric(14, 3)
    END AS "StockAvantLigneTheorique",
    COALESCE(d."QteCmdDetail", 0)::numeric(14, 3) AS "QteCmdDetail",
    COALESCE(d."PUCmdDetail", 0)::numeric(12, 2) AS "PUCmdDetail",
    (
        COALESCE(d."QteCmdDetail", 0::numeric) * COALESCE(d."PUCmdDetail", 0::numeric)
    )::numeric(12, 2) AS "MontantLigne",
    d."ObsCmdDetail",
    d."RemiseCmdDetail",
    d."LieuCmdDetail",
    d."SelectCmdDetail",
    CASE
        WHEN d."QteCmdDetail" IS NULL
        OR d."QteCmdDetail" <= 0 THEN 'Quantité invalide'::text
        WHEN d."PUCmdDetail" IS NULL THEN 'Prix non renseigné'::text
        ELSE 'Valide'::text
    END AS "EtatLigne"
FROM logistique."T_CommandeDetail" d
    JOIN logistique."T_Commande" c ON c."ID_Commande" = d."ID_CmdFk"
    JOIN logistique."T_Article" a ON a."ID_Article" = d."ID_ArticleFk"
    LEFT JOIN referentiel."T_Generique" type_cmd ON c."ID_TypeCmdFk" = type_cmd."ID_Generique"
    AND type_cmd."ID_CategorieGeneriqueFk" = 64
    LEFT JOIN referentiel."T_Generique" statut_cmd ON c."ID_StatutCmdFk" = statut_cmd."ID_Generique"
    AND statut_cmd."ID_CategorieGeneriqueFk" = 28
    LEFT JOIN referentiel."T_Generique" unite ON a."ID_UniteFk" = unite."ID_Generique"
    AND unite."ID_CategorieGeneriqueFk" = 34;
/* ============================================================================
 5. V_MOUVEMENT
 Vue de lecture des mouvements avec article, commande, signe et montant.
 ============================================================================ */
CREATE OR REPLACE VIEW logistique."V_Mouvement" AS
SELECT m."DateHeureAutoMvt",
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
    COALESCE(m."QteMvt", 0)::integer AS "QteMvt",
    COALESCE(m."PUMvt", 0)::numeric(12, 2) AS "PUMvt",
    CASE
        WHEN g_typemvt."AbrGenerique" ILIKE 'entr%' THEN 1
        WHEN g_typemvt."AbrGenerique" ILIKE 'sort%' THEN -1
        ELSE 0
    END::integer AS "SigneStock",
    (
        COALESCE(m."QteMvt", 0) * CASE
            WHEN g_typemvt."AbrGenerique" ILIKE 'entr%' THEN 1
            WHEN g_typemvt."AbrGenerique" ILIKE 'sort%' THEN -1
            ELSE 0
        END
    )::numeric AS "QteMvtSigned",
    (
        COALESCE(m."QteMvt", 0)::numeric * COALESCE(m."PUMvt", 0)::numeric
    )::numeric(14, 2) AS "MontantMvt",
    CASE
        WHEN m."ID_cmdFk" IS NULL THEN 'Ajustement direct article'::text
        ELSE 'Commande'::text
    END AS "OrigineMouvement"
FROM logistique."T_Mouvement" m
    LEFT JOIN logistique."T_Article" a ON m."ID_ArticleFk" = a."ID_Article"
    LEFT JOIN logistique."T_Commande" c ON m."ID_cmdFk" = c."ID_Commande"
    LEFT JOIN referentiel."T_Generique" g_typemvt ON m."ID_TypeMvtFk" = g_typemvt."ID_Generique"
    AND g_typemvt."ID_CategorieGeneriqueFk" = 64;
/* ============================================================================
 6. V_AUDITSTOCK
 Audit base sur la fonction officielle existante.
 ============================================================================ */
CREATE OR REPLACE VIEW logistique."V_AuditStock" AS
SELECT "ID_Article",
    "CodeArticleInterne",
    "NomArticle",
    "StockArticle",
    "StockMouvements",
    "Ecart",
    "N_Mouvements",
    "QteEntree",
    "QteSortie",
    ("Ecart" = 0) AS "EstStockCoherent",
    CASE
        WHEN "Ecart" = 0 THEN 'Cohérent'::text
        WHEN "Ecart" > 0 THEN 'Stock article supérieur aux mouvements'::text
        ELSE 'Stock article inférieur aux mouvements'::text
    END AS "EtatAuditStock"
FROM logistique.fn_audit_stock(NULL::integer, NULL::timestamp without time zone);
/* ============================================================================
 7. V_AUDITSTOCK_THEORIQUE
 Audit direct base sur V_MouvementStock.
 ============================================================================ */
CREATE OR REPLACE VIEW logistique."V_AuditStock_Theorique" AS WITH mvt AS (
        SELECT v."ID_ArticleFk",
            SUM(v."QteMvtSigned") AS stock_mouvement
        FROM logistique."V_MouvementStock" v
        GROUP BY v."ID_ArticleFk"
    )
SELECT a."ID_Article",
    a."CodeArticleInterne",
    a."NomArticle",
    COALESCE(a."QteArticle", 0)::numeric AS "StockEnregistre",
    COALESCE(mvt.stock_mouvement, 0)::numeric AS "StockCalcule",
    (
        COALESCE(a."QteArticle", 0)::numeric - COALESCE(mvt.stock_mouvement, 0)::numeric
    ) AS "Ecart",
    (
        COALESCE(a."QteArticle", 0)::numeric - COALESCE(mvt.stock_mouvement, 0)::numeric = 0
    ) AS "EstStockCoherent"
FROM logistique."T_Article" a
    LEFT JOIN mvt ON mvt."ID_ArticleFk" = a."ID_Article";
/* ============================================================================
 8. V_ALERTSTOCK
 Articles en rupture ou en stock faible uniquement.
 ============================================================================ */
CREATE OR REPLACE VIEW logistique."V_AlertStock" AS
SELECT a."ID_Article",
    a."CodeArticleInterne",
    a."NomArticle",
    a."AbrUnite",
    a."QteArticle",
    a."QteMinArticle",
    a."QteACommander",
    (
        COALESCE(a."QteArticle", 0::numeric) - COALESCE(a."QteMinArticle", 0)::numeric
    )::numeric(14, 3) AS "Marge",
    a."EtatStock",
    a."EstRupture",
    a."EstAlerteStock",
    a."PrioriteStock",
    a."EtatPeremption",
    a."JoursAvantPeremption",
    a."EstPerime",
    a."EstAlertePeremption"
FROM logistique."V_Article" a
WHERE a."QteMinArticle" IS NOT NULL
    AND (
        a."EstRupture" = true
        OR a."EstAlerteStock" = true
    );
/* ============================================================================
 9. V_COMMANDEOVERVIEW
 Vue compacte pour cards/tableaux.
 ============================================================================ */
CREATE OR REPLACE VIEW logistique."V_CommandeOverview" AS
SELECT c."ID_Commande",
    c."DateCmd",
    c."CodeCmd",
    c."AbrTypeCmd",
    c."TypeCmd",
    c."AbrStatutCmd",
    c."StatutCmd",
    c."NomClientSaisi",
    c."MontantHT",
    c."MontantTTC",
    c."EtatPaiement",
    c."StatusFacture",
    c."NbLignes",
    c."NbArticlesDistincts",
    c."QteTotale",
    c."MontantDetails",
    c."EstCommandeSansDetails",
    c."EstMontantIncoherent",
    c."EtatControleCommande"
FROM logistique."V_Commande" c;
/* ============================================================================
 10. V_COMMANDESSANSDETAILS
 Commandes vides a traiter.
 ============================================================================ */
CREATE OR REPLACE VIEW logistique."V_CommandesSansDetails" AS
SELECT c."ID_Commande",
    c."DateCmd",
    c."CodeCmd",
    c."ID_TypeCmdFk",
    type_cmd."AbrGenerique" AS "AbrTypeCmd",
    type_cmd."NomGenerique" AS "TypeCmd",
    c."NomClientSaisi",
    c."ObsCmd"
FROM logistique."T_Commande" c
    LEFT JOIN logistique."T_CommandeDetail" d ON d."ID_CmdFk" = c."ID_Commande"
    LEFT JOIN referentiel."T_Generique" type_cmd ON c."ID_TypeCmdFk" = type_cmd."ID_Generique"
    AND type_cmd."ID_CategorieGeneriqueFk" = 64
WHERE d."ID_CmdFk" IS NULL
    AND COALESCE(c."CodeCmd", '') NOT IN ('C_000E', 'C_000S');
/* ============================================================================
 11. V_CONSOMENSUELLE
 Consommation mensuelle basee uniquement sur les sorties historiques.
 ============================================================================ */
CREATE OR REPLACE VIEW logistique."V_ConsoMensuelle" AS
SELECT v."ID_ArticleFk" AS "ID_Article",
    v."NomArticle",
    date_trunc('month', v."DateMvt")::date AS "Mois",
    SUM(
        CASE
            WHEN v."SigneStock" = -1 THEN COALESCE(v."QteMvt", 0)
            ELSE 0
        END
    )::numeric AS "ConsoMensuelle",
    SUM(
        CASE
            WHEN v."SigneStock" = -1 THEN COALESCE(v."MontantMvt", 0)
            ELSE 0
        END
    )::numeric(14, 2) AS "ValeurConsoMensuelle"
FROM logistique."V_MouvementStock" v
WHERE v."DateMvt" IS NOT NULL
GROUP BY v."ID_ArticleFk",
    v."NomArticle",
    date_trunc('month', v."DateMvt")::date;
/* ============================================================================
 12. V_COUVERTURESTOCK
 Couverture basee sur les sorties des 6 derniers mois.
 ============================================================================ */
CREATE OR REPLACE VIEW logistique."V_CouvertureStock" AS WITH conso AS (
        SELECT v."ID_ArticleFk",
            SUM(
                CASE
                    WHEN v."SigneStock" = -1 THEN COALESCE(v."QteMvt", 0)
                    ELSE 0
                END
            )::numeric AS conso_6m
        FROM logistique."V_MouvementStock" v
        WHERE v."DateMvt" >= (CURRENT_DATE - INTERVAL '6 months')
        GROUP BY v."ID_ArticleFk"
    )
SELECT a."ID_Article",
    a."CodeArticleInterne",
    a."NomArticle",
    a."AbrUnite",
    a."QteArticle" AS "StockActuel",
    COALESCE(conso.conso_6m, 0)::numeric AS "Conso6Mois",
    ROUND(COALESCE(conso.conso_6m, 0)::numeric / 6.0, 2) AS "ConsoMoyMensuelle",
    CASE
        WHEN COALESCE(conso.conso_6m, 0) = 0 THEN NULL::numeric
        ELSE ROUND(
            a."QteArticle" / NULLIF((conso.conso_6m / 6.0), 0),
            1
        )
    END AS "CouvertureMois",
    CASE
        WHEN COALESCE(conso.conso_6m, 0) = 0 THEN 'Aucune consommation récente'::text
        WHEN ROUND(
            a."QteArticle" / NULLIF((conso.conso_6m / 6.0), 0),
            1
        ) < 1 THEN 'Critique'::text
        WHEN ROUND(
            a."QteArticle" / NULLIF((conso.conso_6m / 6.0), 0),
            1
        ) < 3 THEN 'Faible'::text
        ELSE 'Correcte'::text
    END AS "EtatCouverture"
FROM logistique."V_Article" a
    LEFT JOIN conso ON conso."ID_ArticleFk" = a."ID_Article";
/* ============================================================================
 13. V_SUIVIREGLEMENTS
 Suivi des reglements par facture.
 ============================================================================ */
CREATE OR REPLACE VIEW logistique."V_SuiviReglements" AS
SELECT c."ID_Commande",
    c."CodeCmd",
    c."CodeFacture",
    c."DateFacture",
    c."DateEcheancePaiement",
    c."NomClientSaisi",
    COALESCE(c."MontantTTC", 0::numeric)::numeric(12, 2) AS "MontantTTC",
    COALESCE(SUM(r."MontantRegle"), 0::numeric)::numeric(12, 2) AS "TotalRegle",
    (
        COALESCE(c."MontantTTC", 0::numeric) - COALESCE(SUM(r."MontantRegle"), 0::numeric)
    )::numeric(12, 2) AS "Reste",
    COUNT(r."ID_Reglement")::bigint AS "NbReglements",
    MAX(r."DateReglement") AS "DernierReglement",
    CASE
        WHEN c."CodeFacture" IS NULL THEN 'Non facturée'::text
        WHEN COALESCE(c."MontantTTC", 0::numeric) = 0 THEN 'Montant nul'::text
        WHEN COALESCE(SUM(r."MontantRegle"), 0::numeric) <= 0 THEN 'Non réglée'::text
        WHEN COALESCE(SUM(r."MontantRegle"), 0::numeric) < COALESCE(c."MontantTTC", 0::numeric) THEN 'Partiellement réglée'::text
        ELSE 'Réglée'::text
    END AS "EtatReglement",
    (
        c."DateEcheancePaiement" IS NOT NULL
        AND c."DateEcheancePaiement"::date < CURRENT_DATE
        AND (
            COALESCE(c."MontantTTC", 0::numeric) - COALESCE(SUM(r."MontantRegle"), 0::numeric)
        ) > 0
    ) AS "EstEnRetard",
    CASE
        WHEN c."DateEcheancePaiement" IS NOT NULL THEN (c."DateEcheancePaiement"::date - CURRENT_DATE)::integer
        ELSE NULL::integer
    END AS "JoursAvantEcheance"
FROM logistique."T_Commande" c
    LEFT JOIN logistique."T_Reglements" r ON r."CodeFactureFk"::text = c."CodeFacture"::text
GROUP BY c."ID_Commande",
    c."CodeCmd",
    c."CodeFacture",
    c."DateFacture",
    c."DateEcheancePaiement",
    c."NomClientSaisi",
    c."MontantTTC";
/* ============================================================================
 14. VERIFICATION RAPIDE
 ============================================================================ */
DO $$ BEGIN RAISE NOTICE 'Vues logistiques ameliorees creees avec succes.';
RAISE NOTICE 'Correction cle : V_MouvementStock utilise uniquement T_Mouvement.ID_TypeMvtFk pour le signe.';
RAISE NOTICE 'Conseil : executer les SELECT de controle apres ce script.';
END $$;
COMMIT;