/* =============================================================================
   LOGISTIQUE – SCRIPT COMPLET D’OUTILS MÉTIER
   Contenu :
     1) ps_update_totaux_commande + trigger tr_totaux_commande
     2) Verrouillage des écritures directes sur T_Mouvement
     3) Vue logistique."V_MouvementStock" (mouvements signés)
     4) Fonction logistique.fn_audit_stock(p_id_article, p_date_max)
     5) Vue logistique."V_AuditStock"
     6) Verrouillage des commandes clôturées (StatusFacture = 'Clôturée')
     7) Vue logistique."V_AuditStock_Theorique" (audit stock simple)
     8) Vue logistique."V_AlertStock" (alerte seuils mini)
     9) Vue logistique."V_ConsoMensuelle" (consommation par article et par mois)
    10) Vue logistique."V_CouvertureStock" (couverture de stock en mois)
    11) Vues logistique."V_CommandeOverview" et "V_CommandesSansDetails"
    12) Vue logistique."V_SuiviReglements" (règlements vs factures)
   ========================================================================== */


-- ============================================================================
-- 1. MISE À JOUR AUTOMATIQUE DES MONTANTS DE LA COMMANDE (HT / TTC)
--    - Procédure : logistique.ps_update_totaux_commande(p_id_commande)
--    - Trigger   : tr_totaux_commande sur T_CommandeDetail
-- ============================================================================

/**
 * Procédure : logistique.ps_update_totaux_commande
 * Objectif :
 *   Recalculer les montants d'une commande (MontantHT, MontantTTC) à partir
 *   des lignes de T_CommandeDetail :
 *     MontantHT  = somme(QteCmdDetail * PUCmdDetail)
 *     MontantTTC = MontantHT (ou MontantHT * 1.16 si TVA 16%, à adapter)
 *
 * Paramètres :
 *   p_id_commande : ID de la commande à mettre à jour.
 */

DROP PROCEDURE IF EXISTS logistique.ps_update_totaux_commande(integer);

CREATE OR REPLACE PROCEDURE logistique.ps_update_totaux_commande(
    IN p_id_commande integer
)
LANGUAGE plpgsql
AS $BODY$
DECLARE
    v_montant_ht numeric(100,2);
BEGIN
    -- 1) Recalcul du montant HT sur la base des lignes de détail
    SELECT COALESCE(SUM(cd."QteCmdDetail" * cd."PUCmdDetail"), 0)
    INTO   v_montant_ht
    FROM   logistique."T_CommandeDetail" cd
    WHERE  cd."ID_CmdFk" = p_id_commande;

    -- 2) Mise à jour des montants HT/TTC dans la commande
    UPDATE logistique."T_Commande"
    SET "MontantHT"  = v_montant_ht,
        "MontantTTC" = v_montant_ht   -- adapter si TVA, remise, etc.
    WHERE "ID_Commande" = p_id_commande;
END;
$BODY$;

COMMENT ON PROCEDURE logistique.ps_update_totaux_commande(integer)
    IS 'Recalcule MontantHT/MontantTTC d''une commande à partir de T_CommandeDetail (somme des QteCmdDetail * PUCmdDetail).';


/**
 * Fonction de trigger : logistique.tr_totaux_commande
 * Table :
 *   logistique."T_CommandeDetail"
 *
 * Objectif :
 *   - Après chaque INSERT / UPDATE / DELETE sur une ligne de détail,
 *     recalculer les totaux de la commande correspondante via
 *     ps_update_totaux_commande.
 */

DROP FUNCTION IF EXISTS logistique.tr_totaux_commande() CASCADE;

CREATE OR REPLACE FUNCTION logistique.tr_totaux_commande()
RETURNS trigger
LANGUAGE plpgsql
AS $BODY$
DECLARE
    v_id_cmd integer;
BEGIN
    IF TG_OP = 'INSERT' THEN
        v_id_cmd := NEW."ID_CmdFk";

    ELSIF TG_OP = 'UPDATE' THEN
        -- Cas où la ligne change de commande : on recalcule l’ancienne
        IF OLD."ID_CmdFk" IS DISTINCT FROM NEW."ID_CmdFk" THEN
            CALL logistique.ps_update_totaux_commande(OLD."ID_CmdFk");
        END IF;
        v_id_cmd := NEW."ID_CmdFk";

    ELSIF TG_OP = 'DELETE' THEN
        v_id_cmd := OLD."ID_CmdFk";

    ELSE
        RETURN NEW;
    END IF;

    -- Recalcul des totaux pour la commande concernée
    CALL logistique.ps_update_totaux_commande(v_id_cmd);

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$BODY$;

COMMENT ON FUNCTION logistique.tr_totaux_commande()
    IS 'Trigger AFTER sur T_CommandeDetail : recalcul des totaux MontantHT/MontantTTC de la commande via ps_update_totaux_commande.';


-- Trigger sur T_CommandeDetail
DROP TRIGGER IF EXISTS tr_totaux_commande ON logistique."T_CommandeDetail";

CREATE TRIGGER tr_totaux_commande
AFTER INSERT OR UPDATE OR DELETE
ON logistique."T_CommandeDetail"
FOR EACH ROW
EXECUTE FUNCTION logistique.tr_totaux_commande();

COMMENT ON TRIGGER tr_totaux_commande ON logistique."T_CommandeDetail"
    IS 'After INSERT/UPDATE/DELETE sur T_CommandeDetail → tr_totaux_commande → ps_update_totaux_commande.';



-- ============================================================================
-- 2. VERROUILLAGE DES ÉCRITURES DIRECTES SUR T_Mouvement
--    - Fonction : logistique.tr_lock_mouvement_direct
--    - Trigger  : tr_lock_mouvement_direct sur T_Mouvement
-- ============================================================================

/**
 * Fonction de trigger : logistique.tr_lock_mouvement_direct
 * Table :
 *   logistique."T_Mouvement"
 *
 * Objectif :
 *   Empêcher toute écriture directe (INSERT/UPDATE/DELETE) sur T_Mouvement,
 *   qui doit être gérée exclusivement par la logique métier (T_CommandeDetail,
 *   T_Article, etc.).
 */

DROP FUNCTION IF EXISTS logistique.tr_lock_mouvement_direct() CASCADE;

CREATE OR REPLACE FUNCTION logistique.tr_lock_mouvement_direct()
RETURNS trigger
LANGUAGE plpgsql
AS $BODY$
BEGIN
    RAISE EXCEPTION
        'T_Mouvement est une table d''inventaire gérée par la logique métier (T_CommandeDetail / T_Article). Écriture directe interdite.';
END;
$BODY$;

DROP TRIGGER IF EXISTS tr_lock_mouvement_direct ON logistique."T_Mouvement";

CREATE TRIGGER tr_lock_mouvement_direct
BEFORE INSERT OR UPDATE OR DELETE
ON logistique."T_Mouvement"
FOR EACH ROW
EXECUTE FUNCTION logistique.tr_lock_mouvement_direct();

COMMENT ON TRIGGER tr_lock_mouvement_direct ON logistique."T_Mouvement"
    IS 'Verrouille toute écriture directe sur T_Mouvement : la table est gérée par la logique métier.';



-- ============================================================================
-- 3. VUE logistique."V_MouvementStock"
--    Mouvements avec quantités signées selon Entrée / Sortie
-- ============================================================================

/**
 * Vue : logistique."V_MouvementStock"
 *
 * Objectif :
 *   Fournir une vision unifiée des mouvements de stock avec :
 *     - ID_TypeMvt (ID_Generique)
 *     - AbrTypeMvt  ('Entrée' / 'Sortie')
 *     - SigneStock  (+1, -1, 0)
 *     - QteMvtSigned (= QteMvt * signe)
 *
 * Sources :
 *   - logistique."T_Mouvement"        (mouvements bruts)
 *   - logistique."T_Commande"         (type de commande)
 *   - referentiel."T_Generique" (AbrGenerique : 'Entrée' / 'Sortie')
 */

DROP VIEW IF EXISTS logistique."V_MouvementStock";

CREATE OR REPLACE VIEW logistique."V_MouvementStock" AS
SELECT
    m."ID_Mvt",
    m."ID_ArticleFk",
    m."ID_cmdFk",
    m."DateMvt",
    m."QteMvt",
    m."PUMvt",

    -- Type de mouvement (ID_Generique) :
    -- priorité : type de la commande, sinon ID_TypeMvtFk directement
    COALESCE(c."ID_TypeCmdFk", m."ID_TypeMvtFk")::integer AS "ID_TypeMvt",

    -- Abréviation du type ('Entrée' / 'Sortie')
    COALESCE(g."AbrGenerique", g2."AbrGenerique")        AS "AbrTypeMvt",

    -- Signe de l'impact stock : +1 (Entrée), -1 (Sortie), 0 (autre)
    CASE
        WHEN COALESCE(g."AbrGenerique", g2."AbrGenerique") ILIKE 'entr%' THEN  1
        WHEN COALESCE(g."AbrGenerique", g2."AbrGenerique") ILIKE 'sort%' THEN -1
        ELSE 0
    END::integer AS "SigneStock",

    -- Quantité signée (= QteMvt * signe)
    (m."QteMvt" * CASE
        WHEN COALESCE(g."AbrGenerique", g2."AbrGenerique") ILIKE 'entr%' THEN  1
        WHEN COALESCE(g."AbrGenerique", g2."AbrGenerique") ILIKE 'sort%' THEN -1
        ELSE 0
     END)::numeric AS "QteMvtSigned"

FROM logistique."T_Mouvement" m
LEFT JOIN logistique."T_Commande"       c  ON c."ID_Commande"   = m."ID_cmdFk"
LEFT JOIN referentiel."T_Generique"     g  ON g."ID_Generique"  = c."ID_TypeCmdFk"
LEFT JOIN referentiel."T_Generique"     g2 ON g2."ID_Generique" = m."ID_TypeMvtFk";

COMMENT ON VIEW logistique."V_MouvementStock"
    IS 'Vue des mouvements avec quantité signée selon Entrée/Sortie (via T_Commande + referentiel.T_Generique).';



-- ============================================================================
-- 4. FONCTION logistique.fn_audit_stock(p_id_article, p_date_max)
--    Audit des stocks article par article
-- ============================================================================

/**
 * Fonction : logistique.fn_audit_stock
 *
 * Objectif :
 *   Comparer, pour chaque article (ou un article ciblé), le stock courant
 *   T_Article."QteArticle" avec le stock théorique recalculé à partir
 *   de logistique."V_MouvementStock".
 *
 * Paramètres :
 *   p_id_article : NULL = tous les articles, sinon ID_Article ciblé
 *   p_date_max   : NULL = tous les mouvements, sinon on ne prend en compte
 *                          que les mouvements avec DateMvt <= p_date_max
 *
 * Retour :
 *   - ID_Article
 *   - CodeArticleInterne
 *   - NomArticle
 *   - StockArticle     : valeur actuelle dans T_Article
 *   - StockMouvements  : somme des QteMvtSigned (Entrée/Sortie)
 *   - Ecart            : StockArticle - StockMouvements
 *   - N_Mouvements     : nombre de mouvements considérés
 *   - QteEntree        : somme des QteMvt (Entrée, positive)
 *   - QteSortie        : somme des QteMvt (Sortie, positive)
 */

DROP FUNCTION IF EXISTS logistique.fn_audit_stock(
    integer,
    timestamp without time zone
) CASCADE;

CREATE OR REPLACE FUNCTION logistique.fn_audit_stock(
    IN p_id_article integer DEFAULT NULL,
    IN p_date_max   timestamp without time zone DEFAULT NULL
)
RETURNS TABLE(
    "ID_Article"         integer,
    "CodeArticleInterne" character varying,
    "NomArticle"         character varying,
    "StockArticle"       numeric,
    "StockMouvements"    numeric,
    "Ecart"              numeric,
    "N_Mouvements"       integer,
    "QteEntree"          numeric,
    "QteSortie"          numeric
)
LANGUAGE plpgsql
AS $BODY$
BEGIN
    RETURN QUERY
    SELECT
        a."ID_Article",
        a."CodeArticleInterne",
        a."NomArticle",

        COALESCE(a."QteArticle", 0)::numeric                          AS "StockArticle",

        COALESCE(SUM(v."QteMvtSigned"), 0)::numeric                   AS "StockMouvements",

        COALESCE(a."QteArticle", 0)::numeric
          - COALESCE(SUM(v."QteMvtSigned"), 0)::numeric               AS "Ecart",

        COUNT(v."ID_Mvt")::integer                                    AS "N_Mouvements",

        COALESCE(SUM(
            CASE WHEN v."SigneStock" = 1 THEN v."QteMvt" ELSE 0 END
        ), 0)::numeric                                                AS "QteEntree",

        COALESCE(SUM(
            CASE WHEN v."SigneStock" = -1 THEN v."QteMvt" ELSE 0 END
        ), 0)::numeric                                                AS "QteSortie"

    FROM logistique."T_Article" a
    LEFT JOIN logistique."V_MouvementStock" v
           ON v."ID_ArticleFk" = a."ID_Article"
          AND (p_date_max IS NULL OR v."DateMvt" <= p_date_max)

    WHERE (p_id_article IS NULL OR a."ID_Article" = p_id_article)

    GROUP BY
        a."ID_Article",
        a."CodeArticleInterne",
        a."NomArticle",
        a."QteArticle"

    ORDER BY
        a."NomArticle", a."ID_Article";
END;
$BODY$;

COMMENT ON FUNCTION logistique.fn_audit_stock(integer, timestamp without time zone)
    IS 'Audit des stocks : compare T_Article.QteArticle avec la somme des mouvements signés (Entrée/Sortie) via V_MouvementStock.';



-- ============================================================================
-- 5. VUE DE CONFORT : logistique."V_AuditStock"
--    Pour un audit global en un SELECT
-- ============================================================================

/**
 * Vue : logistique."V_AuditStock"
 *
 * Objectif :
 *   Permettre un audit global simple :
 *     SELECT * FROM logistique."V_AuditStock";
 */

DROP VIEW IF EXISTS logistique."V_AuditStock";

CREATE OR REPLACE VIEW logistique."V_AuditStock" AS
SELECT *
FROM logistique.fn_audit_stock(NULL, NULL);

COMMENT ON VIEW logistique."V_AuditStock"
    IS 'Vue d’audit global des stocks (tous les articles, tous les mouvements).';



-- ============================================================================
-- 6. SÉCURISATION DES COMMANDES “FACTURÉES / CLÔTURÉES”
--    - Fonction : logistique.tr_lock_commande_cloturee
--    - Trigger  : tr_lock_commande_cloturee sur T_Commande
-- ============================================================================

/**
 * Fonction de trigger : logistique.tr_lock_commande_cloturee
 * Table :
 *   logistique."T_Commande"
 *
 * Objectif :
 *   Interdire toute modification ou suppression d'une commande dont
 *   StatusFacture = 'Clôturée'.
 *
 * Remarque :
 *   - Le passage d'un statut non clôturé vers 'Clôturée' reste possible.
 *   - Une fois clôturée, toute tentative de UPDATE/DELETE est bloquée.
 */

DROP FUNCTION IF EXISTS logistique.tr_lock_commande_cloturee() CASCADE;

CREATE OR REPLACE FUNCTION logistique.tr_lock_commande_cloturee()
RETURNS trigger
LANGUAGE plpgsql
AS $BODY$
BEGIN
    IF OLD."StatusFacture" = 'Clôturée' THEN
        RAISE EXCEPTION
            'Commande % clôturée/facturée : modification ou suppression interdite.',
            OLD."ID_Commande";
    END IF;

    RETURN NEW;
END;
$BODY$;

DROP TRIGGER IF EXISTS tr_lock_commande_cloturee ON logistique."T_Commande";

CREATE TRIGGER tr_lock_commande_cloturee
BEFORE UPDATE OR DELETE
ON logistique."T_Commande"
FOR EACH ROW
EXECUTE FUNCTION logistique.tr_lock_commande_cloturee();

COMMENT ON TRIGGER tr_lock_commande_cloturee ON logistique."T_Commande"
    IS 'Verrouille les commandes dont StatusFacture = ''Clôturée'' contre toute modification ou suppression.';

-- ============================================================================
-- 7. AUDIT COMPLET DU STOCK (THÉORIQUE VS STOCK ARTICLE)
--    - Vue : logistique."V_AuditStock_Theorique"
-- ============================================================================
/**
 * Vue : logistique."V_AuditStock_Theorique"
 *
 * Objectif :
 *   Comparer, pour chaque article, la quantité enregistrée dans T_Article
 *   ("QteArticle") avec le stock théorique calculé à partir des mouvements
 *   (logistique."T_Mouvement") en appliquant un signe selon le type de
 *   mouvement ('Entrée' / 'Sortie').
 *
 * Logique :
 *   - CTE "mvt" : agrégation des mouvements par article, avec :
 *       * 'Entr%'  → +QteMvt   (entrée)
 *       * 'Sort%'  → -QteMvt   (sortie)
 *       * sinon    →  0
 *   - Jointure sur logistique."T_Article" pour calculer l'écart :
 *       Ecart = QteArticle - stock_mouvement
 *
 * Utilisation :
 *   SELECT * FROM logistique."V_AuditStock_Theorique";
 */

DROP VIEW IF EXISTS logistique."V_AuditStock_Theorique";

CREATE OR REPLACE VIEW logistique."V_AuditStock_Theorique" AS
WITH mvt AS (
    SELECT
        m."ID_ArticleFk",
        SUM(
            CASE
                WHEN g."AbrGenerique" ILIKE 'entr%' THEN m."QteMvt"   -- mouvements d'entrée
                WHEN g."AbrGenerique" ILIKE 'sort%' THEN -m."QteMvt"  -- mouvements de sortie
                ELSE 0                                               -- autres types ignorés
            END
        ) AS stock_mouvement
    FROM logistique."T_Mouvement" m
    LEFT JOIN referentiel."T_Generique" g
        ON g."ID_Generique" = m."ID_TypeMvtFk"
    GROUP BY m."ID_ArticleFk"
)
SELECT
    a."ID_Article",
    a."NomArticle",
    a."QteArticle"                  AS "StockEnregistre",             -- stock saisi
    COALESCE(m.stock_mouvement, 0)  AS "StockCalcule",                -- stock théorique
    (a."QteArticle" - COALESCE(m.stock_mouvement, 0)) AS "Ecart"      -- écart à investiguer
FROM logistique."T_Article" a
LEFT JOIN mvt m
       ON m."ID_ArticleFk" = a."ID_Article";

COMMENT ON VIEW logistique."V_AuditStock_Theorique"
    IS 'Audit simple : compare T_Article.QteArticle avec stock théorique issu de T_Mouvement (entrées/sorties).';



-- ============================================================================
-- 8. ARTICLES EN ALERTE : RISQUE DE RUPTURE / SURSTOCK
--    - Vue : logistique."V_AlertStock"
-- ============================================================================
/**
 * Vue : logistique."V_AlertStock"
 *
 * Objectif :
 *   Lister les articles pour lesquels un seuil minimal de stock
 *   est défini ("QteMinArticle") et calculer la marge par rapport
 *   à ce seuil.
 *
 * Logique :
 *   Marge = QteArticle - QteMinArticle
 *     - Marge < 0  → article en dessous du stock minimum (risque de rupture)
 *     - Marge = 0  → article au minimum
 *     - Marge > 0  → au-dessus du minimum (zone confortable / surstock possible)
 *
 * Utilisation :
 *   SELECT * FROM logistique."V_AlertStock"
 *   ORDER BY "Marge" ASC;
 */

DROP VIEW IF EXISTS logistique."V_AlertStock";

CREATE OR REPLACE VIEW logistique."V_AlertStock" AS
SELECT
    a."ID_Article",
    a."NomArticle",
    a."QteArticle",
    a."QteMinArticle",
    (a."QteArticle" - a."QteMinArticle") AS "Marge"
FROM logistique."T_Article" a
WHERE a."QteMinArticle" IS NOT NULL;

COMMENT ON VIEW logistique."V_AlertStock"
    IS 'Articles avec seuil minimal défini et marge par rapport au stock de sécurité (QteArticle - QteMinArticle).';



-- ============================================================================
-- 9. CONSOMMATION (SORTIES) MENSUELLE PAR ARTICLE
--    - Vue : logistique."V_ConsoMensuelle"
-- ============================================================================
/**
 * Vue : logistique."V_ConsoMensuelle"
 *
 * Objectif :
 *   Calculer, pour chaque article et pour chaque mois, la consommation
 *   en stock (sorties) à partir des mouvements de stock.
 *
 * Logique :
 *   - Agrégation par :
 *       * article
 *       * mois = DATE_TRUNC('month', DateMvt)
 *   - On ne somme que les mouvements de type "Sortie" (AbrGenerique ILIKE 'sort%').
 *
 * Utilisation :
 *   SELECT * FROM logistique."V_ConsoMensuelle"
 *   ORDER BY "NomArticle", "Mois";
 */

DROP VIEW IF EXISTS logistique."V_ConsoMensuelle";

CREATE OR REPLACE VIEW logistique."V_ConsoMensuelle" AS
SELECT
    a."ID_Article",
    a."NomArticle",
    DATE_TRUNC('month', m."DateMvt") AS "Mois",
    SUM(
        CASE
            WHEN g."AbrGenerique" ILIKE 'sort%' THEN m."QteMvt"
            ELSE 0
        END
    ) AS "ConsoMensuelle"
FROM logistique."T_Mouvement" m
JOIN logistique."T_Article" a
     ON a."ID_Article" = m."ID_ArticleFk"
LEFT JOIN referentiel."T_Generique" g
       ON g."ID_Generique" = m."ID_TypeMvtFk"
GROUP BY
    a."ID_Article",
    a."NomArticle",
    DATE_TRUNC('month', m."DateMvt");

COMMENT ON VIEW logistique."V_ConsoMensuelle"
    IS 'Consommation mensuelle par article : somme des mouvements de type Sortie (AbrGenerique ILIKE ''sort%'').';



-- ============================================================================
-- 10. COUVERTURE DU STOCK (COMBIEN DE MOIS RESTANTS ?)
--     - Vue : logistique."V_CouvertureStock"
-- ============================================================================
/**
 * Vue : logistique."V_CouvertureStock"
 *
 * Objectif :
 *   Estimer, pour chaque article, le nombre de mois de couverture que
 *   représente le stock actuel, en se basant sur la consommation des
 *   6 derniers mois.
 *
 * Logique :
 *   - CTE "conso" :
 *       conso_6m = somme des sorties (AbrGenerique ILIKE 'sort%')
 *                  sur les 6 derniers mois.
 *   - conso_moy_mois = conso_6m / 6
 *   - couverture_mois = QteArticle / conso_moy_mois (NULL si conso_6m = 0)
 *
 * Utilisation :
 *   SELECT * FROM logistique."V_CouvertureStock"
 *   ORDER BY "CouvertureMois" ASC NULLS LAST;
 */

DROP VIEW IF EXISTS logistique."V_CouvertureStock";

CREATE OR REPLACE VIEW logistique."V_CouvertureStock" AS
WITH conso AS (
    SELECT
        m."ID_ArticleFk",
        SUM(
            CASE
                WHEN g."AbrGenerique" ILIKE 'sort%' THEN m."QteMvt"
                ELSE 0
            END
        ) AS conso_6m
    FROM logistique."T_Mouvement" m
    LEFT JOIN referentiel."T_Generique" g
           ON g."ID_Generique" = m."ID_TypeMvtFk"
    WHERE m."DateMvt" >= CURRENT_DATE - INTERVAL '6 months'
    GROUP BY m."ID_ArticleFk"
)
SELECT
    a."ID_Article",
    a."NomArticle",
    a."QteArticle"                 AS "StockActuel",
    conso.conso_6m                 AS "Conso6Mois",
    ROUND(conso.conso_6m / 6.0, 2) AS "ConsoMoyMensuelle",
    CASE
        WHEN conso.conso_6m = 0 THEN NULL
        ELSE ROUND(a."QteArticle" / (conso.conso_6m / 6.0), 1)
    END AS "CouvertureMois"
FROM logistique."T_Article" a
LEFT JOIN conso
       ON conso."ID_ArticleFk" = a."ID_Article";

COMMENT ON VIEW logistique."V_CouvertureStock"
    IS 'Couverture de stock estimée (en mois) à partir de la consommation des 6 derniers mois.';



-- ============================================================================
-- 11. COMMANDES : VALEUR, STATUT, ANOMALIES
--     - Vue : logistique."V_CommandeOverview"
--     - Vue : logistique."V_CommandesSansDetails"
-- ============================================================================
/**
 * Vue : logistique."V_CommandeOverview"
 *
 * Objectif :
 *   Fournir un résumé des commandes avec leurs montants HT/TTC et le
 *   statut de facturation.
 *
 * Utilisation :
 *   SELECT * FROM logistique."V_CommandeOverview";
 */

DROP VIEW IF EXISTS logistique."V_CommandeOverview";

CREATE OR REPLACE VIEW logistique."V_CommandeOverview" AS
SELECT
    c."ID_Commande",
    c."DateCmd",
    c."MontantHT",
    c."MontantTTC",
    c."StatusFacture"
FROM logistique."T_Commande" c;

COMMENT ON VIEW logistique."V_CommandeOverview"
    IS 'Vue synthétique des commandes : montants HT/TTC et statut de facturation.';



/**
 * Vue : logistique."V_CommandesSansDetails"
 *
 * Objectif :
 *   Identifier les commandes qui ne possèdent aucune ligne dans
 *   logistique."T_CommandeDetail" (commandes « vides », potentiellement
 *   anormales).
 *
 * Utilisation :
 *   SELECT * FROM logistique."V_CommandesSansDetails";
 */

DROP VIEW IF EXISTS logistique."V_CommandesSansDetails";

CREATE OR REPLACE VIEW logistique."V_CommandesSansDetails" AS
SELECT
    c."ID_Commande",
    c."CodeCmd"
FROM logistique."T_Commande" c
LEFT JOIN logistique."T_CommandeDetail" d
       ON d."ID_CmdFk" = c."ID_Commande"
WHERE d."ID_CmdFk" IS NULL;

COMMENT ON VIEW logistique."V_CommandesSansDetails"
    IS 'Commandes sans aucune ligne de détail dans T_CommandeDetail (anomalies potentielles).';



-- ============================================================================
-- 12. SUIVI RÈGLEMENTS VS FACTURES (RESTE À PAYER)
--     - Vue : logistique."V_SuiviReglements"
-- ============================================================================
/**
 * Vue : logistique."V_SuiviReglements"
 *
 * Objectif :
 *   Comparer le montant TTC de chaque commande/facture au total des
 *   règlements enregistrés, afin de calculer le reste à payer.
 *
 * Logique :
 *   - Jointure T_Commande ↔ T_Reglements via CodeFacture/CodeFactureFk.
 *   - total_regle = somme de MontantRegle.
 *   - reste       = MontantTTC - total_regle.
 *
 * Utilisation :
 *   SELECT * FROM logistique."V_SuiviReglements"
 *   ORDER BY "Reste" DESC;
 */

DROP VIEW IF EXISTS logistique."V_SuiviReglements";

CREATE OR REPLACE VIEW logistique."V_SuiviReglements" AS
SELECT
    c."ID_Commande",
    c."CodeFacture",
    c."MontantTTC",
    COALESCE(SUM(r."MontantRegle"), 0)           AS "TotalRegle",
    (c."MontantTTC" - COALESCE(SUM(r."MontantRegle"), 0)) AS "Reste"
FROM logistique."T_Commande" c
LEFT JOIN logistique."T_Reglements" r
       ON r."CodeFactureFk" = c."CodeFacture"
GROUP BY
    c."ID_Commande",
    c."CodeFacture",
    c."MontantTTC";

COMMENT ON VIEW logistique."V_SuiviReglements"
    IS 'Suivi des règlements : total réglé et reste à payer par facture (T_Commande vs T_Reglements).';
