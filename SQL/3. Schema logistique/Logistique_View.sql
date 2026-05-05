-- View: logistique.V_AlertStock
-- DROP VIEW logistique."V_AlertStock";
CREATE OR REPLACE VIEW logistique."V_AlertStock" AS
SELECT "ID_Article",
    "CodeArticleInterne",
    "NomArticle",
    "AbrUnite",
    "QteArticle",
    "QteMinArticle",
    "QteACommander",
    (
        COALESCE("QteArticle", 0::numeric) - COALESCE("QteMinArticle", 0)::numeric
    )::numeric(14, 3) AS "Marge",
    "EtatStock",
    "EstRupture",
    "EstAlerteStock",
    "PrioriteStock",
    "EtatPeremption",
    "JoursAvantPeremption",
    "EstPerime",
    "EstAlertePeremption"
FROM logistique."V_Article" a
WHERE "QteMinArticle" IS NOT NULL
    AND (
        "EstRupture" = true
        OR "EstAlerteStock" = true
    );
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
    type_article."NomGenerique" AS "TypeArticle",
    a."ID_CategorieArticleFk",
    categorie_article."AbrGenerique" AS "AbrCategorieArticle",
    categorie_article."NomGenerique" AS "CategorieArticle",
    a."ID_UniteFk",
    unite."AbrGenerique" AS "AbrUnite",
    unite."NomGenerique" AS "Unite",
    COALESCE(a."QteArticle", 0::numeric)::numeric(14, 3) AS "QteArticle",
    a."QteMinArticle",
    GREATEST(
        COALESCE(a."QteMinArticle", 0)::numeric - COALESCE(a."QteArticle", 0::numeric),
        0::numeric
    )::numeric(14, 3) AS "QteACommander",
    CASE
        WHEN COALESCE(a."QteArticle", 0::numeric) <= 0::numeric THEN 'Rupture'::text
        WHEN a."QteMinArticle" IS NOT NULL
        AND COALESCE(a."QteArticle", 0::numeric) <= a."QteMinArticle"::numeric THEN 'Stock faible'::text
        ELSE 'Disponible'::text
    END AS "EtatStock",
    COALESCE(a."QteArticle", 0::numeric) <= 0::numeric AS "EstRupture",
    a."QteMinArticle" IS NOT NULL
    AND COALESCE(a."QteArticle", 0::numeric) <= a."QteMinArticle"::numeric AS "EstAlerteStock",
    CASE
        WHEN COALESCE(a."QteArticle", 0::numeric) <= 0::numeric THEN 1
        WHEN a."QteMinArticle" IS NOT NULL
        AND COALESCE(a."QteArticle", 0::numeric) <= a."QteMinArticle"::numeric THEN 2
        ELSE 3
    END AS "PrioriteStock",
    COALESCE(a."PUArticle", 0::numeric)::numeric(12, 2) AS "PUArticle",
    COALESCE(a."PVArticle", 0::numeric)::numeric(12, 2) AS "PVArticle",
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
        WHEN a."DatePeremptionArticle"::date < CURRENT_DATE THEN 'Périmé'::text
        WHEN a."DatePeremptionAlerteArticle" IS NOT NULL
        AND a."DatePeremptionAlerteArticle"::date <= CURRENT_DATE THEN 'Alerte péremption'::text
        WHEN a."NbreJoursAlerteArticle" IS NOT NULL
        AND a."DatePeremptionArticle"::date <= (CURRENT_DATE + a."NbreJoursAlerteArticle") THEN 'Alerte péremption'::text
        ELSE 'Valide'::text
    END AS "EtatPeremption",
    CASE
        WHEN a."DatePeremptionArticle" IS NOT NULL THEN a."DatePeremptionArticle"::date - CURRENT_DATE
        ELSE NULL::integer
    END AS "JoursAvantPeremption",
    a."DatePeremptionArticle" IS NOT NULL
    AND a."DatePeremptionArticle"::date < CURRENT_DATE AS "EstPerime",
    a."DatePeremptionArticle" IS NOT NULL
    AND a."DatePeremptionArticle"::date >= CURRENT_DATE
    AND (
        a."DatePeremptionAlerteArticle" IS NOT NULL
        AND a."DatePeremptionAlerteArticle"::date <= CURRENT_DATE
        OR a."NbreJoursAlerteArticle" IS NOT NULL
        AND a."DatePeremptionArticle"::date <= (CURRENT_DATE + a."NbreJoursAlerteArticle")
    ) AS "EstAlertePeremption",
    CASE
        WHEN a."DatePeremptionArticle" IS NULL THEN 4
        WHEN a."DatePeremptionArticle"::date < CURRENT_DATE THEN 1
        WHEN a."DatePeremptionAlerteArticle" IS NOT NULL
        AND a."DatePeremptionAlerteArticle"::date <= CURRENT_DATE
        OR a."NbreJoursAlerteArticle" IS NOT NULL
        AND a."DatePeremptionArticle"::date <= (CURRENT_DATE + a."NbreJoursAlerteArticle") THEN 2
        ELSE 3
    END AS "PrioritePeremption",
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
    "QteSortie",
    "Ecart" = 0::numeric AS "EstStockCoherent",
    CASE
        WHEN "Ecart" = 0::numeric THEN 'Cohérent'::text
        WHEN "Ecart" > 0::numeric THEN 'Stock article supérieur aux mouvements'::text
        ELSE 'Stock article inférieur aux mouvements'::text
    END AS "EtatAuditStock"
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
        SELECT v."ID_ArticleFk",
            sum(v."QteMvtSigned") AS stock_mouvement
        FROM logistique."V_MouvementStock" v
        GROUP BY v."ID_ArticleFk"
    )
SELECT a."ID_Article",
    a."CodeArticleInterne",
    a."NomArticle",
    COALESCE(a."QteArticle", 0::numeric) AS "StockEnregistre",
    COALESCE(mvt.stock_mouvement, 0::numeric) AS "StockCalcule",
    COALESCE(a."QteArticle", 0::numeric) - COALESCE(mvt.stock_mouvement, 0::numeric) AS "Ecart",
    (
        COALESCE(a."QteArticle", 0::numeric) - COALESCE(mvt.stock_mouvement, 0::numeric)
    ) = 0::numeric AS "EstStockCoherent"
FROM logistique."T_Article" a
    LEFT JOIN mvt ON mvt."ID_ArticleFk" = a."ID_Article";
ALTER TABLE logistique."V_AuditStock_Theorique" OWNER TO postgres;
-- View: logistique.V_Commande
-- DROP VIEW logistique."V_Commande";
CREATE OR REPLACE VIEW logistique."V_Commande" AS WITH cd_stats AS (
        SELECT cd."ID_CmdFk",
            count(*) AS "NbLignes",
            count(DISTINCT cd."ID_ArticleFk") AS "NbArticlesDistincts",
            sum(COALESCE(cd."QteCmdDetail", 0::numeric)) AS "QteTotale",
            sum(
                COALESCE(cd."QteCmdDetail", 0::numeric) * COALESCE(cd."PUCmdDetail", 0::numeric)
            ) AS "MontantDetails",
            string_agg(
                DISTINCT a."NomArticle"::text,
                ', '::text
                ORDER BY (a."NomArticle"::text)
            ) AS "ListeArticles"
        FROM logistique."T_CommandeDetail" cd
            LEFT JOIN logistique."T_Article" a ON a."ID_Article" = cd."ID_ArticleFk"
        GROUP BY cd."ID_CmdFk"
    ),
    reg_stats AS (
        SELECT r."CodeFactureFk",
            sum(COALESCE(r."MontantRegle", 0::numeric)) AS "TotalRegleReel",
            count(*) AS "NbReglements",
            max(r."DateReglement") AS "DernierReglement"
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
        WHEN type_cmd."AbrGenerique"::text ~~* 'entr%'::text THEN 1
        WHEN type_cmd."AbrGenerique"::text ~~* 'sort%'::text THEN '-1'::integer
        ELSE 0
    END AS "SigneCommande",
    type_cmd."AbrGenerique"::text ~~* 'entr%'::text AS "EstCommandeEntree",
    type_cmd."AbrGenerique"::text ~~* 'sort%'::text AS "EstCommandeSortie",
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
    COALESCE(reg_stats."NbReglements", 0::bigint) AS "NbReglements",
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
    c."DateEcheancePaiement" IS NOT NULL
    AND c."DateEcheancePaiement"::date < CURRENT_DATE
    AND (
        COALESCE(c."MontantTTC", 0::numeric) - COALESCE(
            reg_stats."TotalRegleReel",
            COALESCE(c."MontantRegleFacture", 0::numeric),
            0::numeric
        )
    ) > 0::numeric AS "EstPaiementEnRetard",
    CASE
        WHEN c."DateEcheancePaiement" IS NOT NULL THEN c."DateEcheancePaiement"::date - CURRENT_DATE
        ELSE NULL::integer
    END AS "JoursAvantEcheance",
    COALESCE(cd_stats."NbLignes", 0::bigint) AS "NbLignes",
    COALESCE(cd_stats."NbArticlesDistincts", 0::bigint) AS "NbArticlesDistincts",
    COALESCE(cd_stats."QteTotale", 0::numeric)::numeric(14, 3) AS "QteTotale",
    COALESCE(cd_stats."MontantDetails", 0::numeric)::numeric(12, 2) AS "MontantDetails",
    cd_stats."ListeArticles",
    COALESCE(cd_stats."NbLignes", 0::bigint) = 0 AS "EstCommandeSansDetails",
    (
        COALESCE(c."MontantHT", 0::numeric) - COALESCE(cd_stats."MontantDetails", 0::numeric)
    )::numeric(12, 2) AS "EcartMontantDetails",
    abs(
        COALESCE(c."MontantHT", 0::numeric) - COALESCE(cd_stats."MontantDetails", 0::numeric)
    ) > 0.01 AS "EstMontantIncoherent",
    CASE
        WHEN COALESCE(cd_stats."NbLignes", 0::bigint) = 0 THEN 'Sans détails'::text
        WHEN abs(
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
ALTER TABLE logistique."V_Commande" OWNER TO postgres;
-- View: logistique.V_CommandeDetail
-- DROP VIEW logistique."V_CommandeDetail";
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
        WHEN type_cmd."AbrGenerique"::text ~~* 'entr%'::text THEN 1
        WHEN type_cmd."AbrGenerique"::text ~~* 'sort%'::text THEN '-1'::integer
        ELSE 0
    END AS "SigneCommande",
    c."ID_StatutCmdFk",
    c."ID_StatutCmdFk" AS "ID_StatutCmd",
    statut_cmd."AbrGenerique" AS "AbrStatutCmd",
    statut_cmd."NomGenerique" AS "StatutCmd",
    d."ID_ArticleFk",
    a."CodeArticleInterne",
    a."NomArticle",
    a."ID_UniteFk",
    unite."AbrGenerique" AS "AbrUnite",
    COALESCE(a."QteArticle", 0::numeric)::numeric(14, 3) AS "StockActuel",
    CASE
        WHEN type_cmd."AbrGenerique"::text ~~* 'sort%'::text THEN (
            COALESCE(a."QteArticle", 0::numeric) + COALESCE(d."QteCmdDetail", 0::numeric)
        )::numeric(14, 3)
        WHEN type_cmd."AbrGenerique"::text ~~* 'entr%'::text THEN (
            COALESCE(a."QteArticle", 0::numeric) - COALESCE(d."QteCmdDetail", 0::numeric)
        )::numeric(14, 3)
        ELSE COALESCE(a."QteArticle", 0::numeric)::numeric(14, 3)
    END AS "StockAvantLigneTheorique",
    COALESCE(d."QteCmdDetail", 0::numeric)::numeric(14, 3) AS "QteCmdDetail",
    COALESCE(d."PUCmdDetail", 0::numeric)::numeric(12, 2) AS "PUCmdDetail",
    (
        COALESCE(d."QteCmdDetail", 0::numeric) * COALESCE(d."PUCmdDetail", 0::numeric)
    )::numeric(12, 2) AS "MontantLigne",
    d."ObsCmdDetail",
    d."RemiseCmdDetail",
    d."LieuCmdDetail",
    d."SelectCmdDetail",
    CASE
        WHEN d."QteCmdDetail" IS NULL
        OR d."QteCmdDetail" <= 0::numeric THEN 'Quantité invalide'::text
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
ALTER TABLE logistique."V_CommandeDetail" OWNER TO postgres;
-- View: logistique.V_CommandeOverview
-- DROP VIEW logistique."V_CommandeOverview";
CREATE OR REPLACE VIEW logistique."V_CommandeOverview" AS
SELECT "ID_Commande",
    "DateCmd",
    "CodeCmd",
    "AbrTypeCmd",
    "TypeCmd",
    "AbrStatutCmd",
    "StatutCmd",
    "NomClientSaisi",
    "MontantHT",
    "MontantTTC",
    "EtatPaiement",
    "StatusFacture",
    "NbLignes",
    "NbArticlesDistincts",
    "QteTotale",
    "MontantDetails",
    "EstCommandeSansDetails",
    "EstMontantIncoherent",
    "EtatControleCommande"
FROM logistique."V_Commande" c;
ALTER TABLE logistique."V_CommandeOverview" OWNER TO postgres;
-- View: logistique.V_CommandesSansDetails
-- DROP VIEW logistique."V_CommandesSansDetails";
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
    AND (
        COALESCE(c."CodeCmd", ''::character varying)::text <> ALL (
            ARRAY ['C_000E'::character varying, 'C_000S'::character varying]::text []
        )
    );
ALTER TABLE logistique."V_CommandesSansDetails" OWNER TO postgres;
-- View: logistique.V_ConsoMensuelle
-- DROP VIEW logistique."V_ConsoMensuelle";
CREATE OR REPLACE VIEW logistique."V_ConsoMensuelle" AS
SELECT "ID_ArticleFk" AS "ID_Article",
    "NomArticle",
    date_trunc('month'::text, "DateMvt")::date AS "Mois",
    sum(
        CASE
            WHEN "SigneStock" = '-1'::integer THEN COALESCE("QteMvt", 0)
            ELSE 0
        END
    )::numeric AS "ConsoMensuelle",
    sum(
        CASE
            WHEN "SigneStock" = '-1'::integer THEN COALESCE("MontantMvt", 0::numeric)
            ELSE 0::numeric
        END
    )::numeric(14, 2) AS "ValeurConsoMensuelle"
FROM logistique."V_MouvementStock" v
WHERE "DateMvt" IS NOT NULL
GROUP BY "ID_ArticleFk",
    "NomArticle",
    (date_trunc('month'::text, "DateMvt")::date);
ALTER TABLE logistique."V_ConsoMensuelle" OWNER TO postgres;
-- View: logistique.V_CouvertureStock
-- DROP VIEW logistique."V_CouvertureStock";
CREATE OR REPLACE VIEW logistique."V_CouvertureStock" AS WITH conso AS (
        SELECT v."ID_ArticleFk",
            sum(
                CASE
                    WHEN v."SigneStock" = '-1'::integer THEN COALESCE(v."QteMvt", 0)
                    ELSE 0
                END
            )::numeric AS conso_6m
        FROM logistique."V_MouvementStock" v
        WHERE v."DateMvt" >= (CURRENT_DATE - '6 mons'::interval)
        GROUP BY v."ID_ArticleFk"
    )
SELECT a."ID_Article",
    a."CodeArticleInterne",
    a."NomArticle",
    a."AbrUnite",
    a."QteArticle" AS "StockActuel",
    COALESCE(conso.conso_6m, 0::numeric) AS "Conso6Mois",
    round(COALESCE(conso.conso_6m, 0::numeric) / 6.0, 2) AS "ConsoMoyMensuelle",
    CASE
        WHEN COALESCE(conso.conso_6m, 0::numeric) = 0::numeric THEN NULL::numeric
        ELSE round(
            a."QteArticle" / NULLIF(conso.conso_6m / 6.0, 0::numeric),
            1
        )
    END AS "CouvertureMois",
    CASE
        WHEN COALESCE(conso.conso_6m, 0::numeric) = 0::numeric THEN 'Aucune consommation récente'::text
        WHEN round(
            a."QteArticle" / NULLIF(conso.conso_6m / 6.0, 0::numeric),
            1
        ) < 1::numeric THEN 'Critique'::text
        WHEN round(
            a."QteArticle" / NULLIF(conso.conso_6m / 6.0, 0::numeric),
            1
        ) < 3::numeric THEN 'Faible'::text
        ELSE 'Correcte'::text
    END AS "EtatCouverture"
FROM logistique."V_Article" a
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
    g_typemvt."NomGenerique" AS "NomTypeMvt",
    m."ID_ArticleFk",
    a."CodeArticleInterne",
    a."NomArticle",
    m."ID_cmdFk",
    c."CodeCmd",
    c."DateCmd",
    COALESCE(m."QteMvt", 0) AS "QteMvt",
    COALESCE(m."PUMvt", 0::numeric)::numeric(12, 2) AS "PUMvt",
    CASE
        WHEN g_typemvt."AbrGenerique"::text ~~* 'entr%'::text THEN 1
        WHEN g_typemvt."AbrGenerique"::text ~~* 'sort%'::text THEN '-1'::integer
        ELSE 0
    END AS "SigneStock",
    (
        COALESCE(m."QteMvt", 0) * CASE
            WHEN g_typemvt."AbrGenerique"::text ~~* 'entr%'::text THEN 1
            WHEN g_typemvt."AbrGenerique"::text ~~* 'sort%'::text THEN '-1'::integer
            ELSE 0
        END
    )::numeric AS "QteMvtSigned",
    (
        COALESCE(m."QteMvt", 0)::numeric * COALESCE(m."PUMvt", 0::numeric)
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
ALTER TABLE logistique."V_Mouvement" OWNER TO postgres;
-- View: logistique.V_MouvementStock
-- DROP VIEW logistique."V_MouvementStock";
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
    m."ID_TypeMvtFk" AS "ID_TypeMvt",
    g."AbrGenerique" AS "AbrTypeMvt",
    g."NomGenerique" AS "TypeMvt",
    COALESCE(m."QteMvt", 0) AS "QteMvt",
    COALESCE(m."PUMvt", 0::numeric)::numeric(12, 2) AS "PUMvt",
    CASE
        WHEN g."AbrGenerique"::text ~~* 'entr%'::text THEN 1
        WHEN g."AbrGenerique"::text ~~* 'sort%'::text THEN '-1'::integer
        ELSE 0
    END AS "SigneStock",
    (
        COALESCE(m."QteMvt", 0) * CASE
            WHEN g."AbrGenerique"::text ~~* 'entr%'::text THEN 1
            WHEN g."AbrGenerique"::text ~~* 'sort%'::text THEN '-1'::integer
            ELSE 0
        END
    )::numeric AS "QteMvtSigned",
    (
        COALESCE(m."QteMvt", 0)::numeric * COALESCE(m."PUMvt", 0::numeric)
    )::numeric(14, 2) AS "MontantMvt",
    (
        COALESCE(m."QteMvt", 0)::numeric * COALESCE(m."PUMvt", 0::numeric) * CASE
            WHEN g."AbrGenerique"::text ~~* 'entr%'::text THEN 1
            WHEN g."AbrGenerique"::text ~~* 'sort%'::text THEN '-1'::integer
            ELSE 0
        END::numeric
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
ALTER TABLE logistique."V_MouvementStock" OWNER TO postgres;
-- View: logistique.V_SuiviReglements
-- DROP VIEW logistique."V_SuiviReglements";
CREATE OR REPLACE VIEW logistique."V_SuiviReglements" AS
SELECT c."ID_Commande",
    c."CodeCmd",
    c."CodeFacture",
    c."DateFacture",
    c."DateEcheancePaiement",
    c."NomClientSaisi",
    COALESCE(c."MontantTTC", 0::numeric)::numeric(12, 2) AS "MontantTTC",
    COALESCE(sum(r."MontantRegle"), 0::numeric)::numeric(12, 2) AS "TotalRegle",
    (
        COALESCE(c."MontantTTC", 0::numeric) - COALESCE(sum(r."MontantRegle"), 0::numeric)
    )::numeric(12, 2) AS "Reste",
    count(r."ID_Reglement") AS "NbReglements",
    max(r."DateReglement") AS "DernierReglement",
    CASE
        WHEN c."CodeFacture" IS NULL THEN 'Non facturée'::text
        WHEN COALESCE(c."MontantTTC", 0::numeric) = 0::numeric THEN 'Montant nul'::text
        WHEN COALESCE(sum(r."MontantRegle"), 0::numeric) <= 0::numeric THEN 'Non réglée'::text
        WHEN COALESCE(sum(r."MontantRegle"), 0::numeric) < COALESCE(c."MontantTTC", 0::numeric) THEN 'Partiellement réglée'::text
        ELSE 'Réglée'::text
    END AS "EtatReglement",
    c."DateEcheancePaiement" IS NOT NULL
    AND c."DateEcheancePaiement"::date < CURRENT_DATE
    AND (
        COALESCE(c."MontantTTC", 0::numeric) - COALESCE(sum(r."MontantRegle"), 0::numeric)
    ) > 0::numeric AS "EstEnRetard",
    CASE
        WHEN c."DateEcheancePaiement" IS NOT NULL THEN c."DateEcheancePaiement"::date - CURRENT_DATE
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
ALTER TABLE logistique."V_SuiviReglements" OWNER TO postgres;