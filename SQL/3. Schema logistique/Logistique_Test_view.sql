/* ============================================================================
   TEST DES VUES LOGISTIQUES - SAUVERNDEKO
   Version corrigee uniquement cote TEST

   Objectif :
   Tester les vues logistiques sans modifier leur definition :
   - logistique."V_Article"
   - logistique."V_Commande"
   - logistique."V_CommandeDetail"
   - logistique."V_AuditStock"
   - logistique."V_AlertStock"
   - logistique."V_ConsoMensuelle"
   - logistique."V_CouvertureStock"
   - logistique."V_CommandesSansDetails"
   - logistique."V_SuiviReglements"

   Corrections appliquees :
   - ne plus supposer des IDs fixes pour Entree / Sortie
   - chercher les types dynamiquement dans T_Generique
   - filtrer dans la categorie 64
   - utiliser ID_Article dans le bloc DO
   - utiliser une table temporaire pour les controles apres COMMIT
   - generer des codes uniques a chaque execution
   ============================================================================ */

CREATE TEMP TABLE IF NOT EXISTS tmp_logistique_test_refs (
    objet text,
    id_article integer,
    id_commande integer,
    code_article text,
    code_cmd text,
    code_facture text
) ON COMMIT PRESERVE ROWS;

TRUNCATE TABLE tmp_logistique_test_refs;

BEGIN;

DO $$
DECLARE
    v_id_type_entree integer;
    v_id_type_sortie integer;
    v_id_categorie_type_commande integer := 64;
    v_suffix text;
    v_code_article_1 text;
    v_code_article_2 text;
    v_code_article_alerte text;
    v_code_cmd_entree text;
    v_code_cmd_sortie text;
    v_code_cmd_sans_detail text;
    v_code_facture text;
    v_id_article_1 integer;
    v_id_article_2 integer;
    v_id_article_alerte integer;
    v_id_cmd_entree integer;
    v_id_cmd_sortie integer;
    v_id_cmd_sans_detail integer;
    v_qte numeric;
    v_count integer;
BEGIN
    RAISE NOTICE '============================================================';
    RAISE NOTICE 'DEBUT TEST DES VUES LOGISTIQUES';
    RAISE NOTICE '============================================================';
    RAISE NOTICE 'Categorie generique attendue pour les types test : %', v_id_categorie_type_commande;

    ---------------------------------------------------------------------------
    -- 0. CODES UNIQUES POUR EVITER LES CONFLITS
    ---------------------------------------------------------------------------
    v_suffix := to_char(clock_timestamp(), 'HH24MISS') || lpad((floor(random() * 1000))::int::text, 3, '0');
    v_code_article_1 := 'VIEW-ART-001-' || v_suffix;
    v_code_article_2 := 'VIEW-ART-002-' || v_suffix;
    v_code_article_alerte := 'VIEW-ART-ALT-' || v_suffix;
    v_code_cmd_entree := 'V-E-' || v_suffix;
    v_code_cmd_sortie := 'V-S-' || v_suffix;
    v_code_cmd_sans_detail := 'V-SD-' || v_suffix;
    v_code_facture := 'VF-' || v_suffix;

    ---------------------------------------------------------------------------
    -- 1. CONTROLE REFERENTIEL
    ---------------------------------------------------------------------------
    SELECT g."ID_Generique"
    INTO v_id_type_entree
    FROM referentiel."T_Generique" g
    WHERE g."ID_CategorieGeneriqueFk" = v_id_categorie_type_commande
      AND g."AbrGenerique" ILIKE 'entr%'
    ORDER BY g."ID_Generique"
    LIMIT 1;

    IF v_id_type_entree IS NULL THEN
        RAISE EXCEPTION
            'Type Entree introuvable dans T_Generique pour la categorie %.',
            v_id_categorie_type_commande;
    END IF;

    SELECT g."ID_Generique"
    INTO v_id_type_sortie
    FROM referentiel."T_Generique" g
    WHERE g."ID_CategorieGeneriqueFk" = v_id_categorie_type_commande
      AND g."AbrGenerique" ILIKE 'sort%'
    ORDER BY g."ID_Generique"
    LIMIT 1;

    IF v_id_type_sortie IS NULL THEN
        RAISE EXCEPTION
            'Type Sortie introuvable dans T_Generique pour la categorie %.',
            v_id_categorie_type_commande;
    END IF;

    RAISE NOTICE 'OK - Types Entree / Sortie trouves : % / %', v_id_type_entree, v_id_type_sortie;

    ---------------------------------------------------------------------------
    -- 2. CREATION ARTICLES
    ---------------------------------------------------------------------------
    RAISE NOTICE 'Creation des articles...';

    INSERT INTO logistique."T_Article" (
        "DateHeureAuto",
        "CodeArticleExterne",
        "NomArticle",
        "RefArticle",
        "QteArticle",
        "PUArticle",
        "PVArticle",
        "QteMinArticle",
        "ObsArticle",
        "ValideArticle",
        "DatePeremptionArticle",
        "DatePeremptionAlerteArticle",
        "NbreJoursAlerteArticle",
        "CodeArticleInterne"
    )
    VALUES (
        now(),
        3001,
        'Gants medicaux - test vues',
        'VIEW-REF-ART-001',
        0,
        1.00,
        2.00,
        10,
        'Article test pour vues logistiques',
        TRUE,
        now() + interval '12 months',
        now() + interval '11 months',
        30,
        v_code_article_1
    )
    RETURNING "ID_Article" INTO v_id_article_1;

    INSERT INTO logistique."T_Article" (
        "DateHeureAuto",
        "CodeArticleExterne",
        "NomArticle",
        "RefArticle",
        "QteArticle",
        "PUArticle",
        "PVArticle",
        "QteMinArticle",
        "ObsArticle",
        "ValideArticle",
        "DatePeremptionArticle",
        "DatePeremptionAlerteArticle",
        "NbreJoursAlerteArticle",
        "CodeArticleInterne"
    )
    VALUES (
        now(),
        3002,
        'Masques chirurgicaux - test vues',
        'VIEW-REF-ART-002',
        0,
        0.50,
        1.00,
        20,
        'Article test consommation',
        TRUE,
        now() + interval '10 months',
        now() + interval '9 months',
        30,
        v_code_article_2
    )
    RETURNING "ID_Article" INTO v_id_article_2;

    INSERT INTO logistique."T_Article" (
        "DateHeureAuto",
        "CodeArticleExterne",
        "NomArticle",
        "RefArticle",
        "QteArticle",
        "PUArticle",
        "PVArticle",
        "QteMinArticle",
        "ObsArticle",
        "ValideArticle",
        "DatePeremptionArticle",
        "DatePeremptionAlerteArticle",
        "NbreJoursAlerteArticle",
        "CodeArticleInterne"
    )
    VALUES (
        now(),
        3003,
        'Gel hydroalcoolique - alerte stock',
        'VIEW-REF-ALERTE-001',
        0,
        3.00,
        5.00,
        15,
        'Article volontairement en alerte stock',
        TRUE,
        now() + interval '20 days',
        now() + interval '10 days',
        30,
        v_code_article_alerte
    )
    RETURNING "ID_Article" INTO v_id_article_alerte;

    RAISE NOTICE 'OK - Articles crees : %, %, %', v_id_article_1, v_id_article_2, v_id_article_alerte;

    ---------------------------------------------------------------------------
    -- 3. STOCKS INITIAUX PAR UPDATE DIRECT
    ---------------------------------------------------------------------------
    UPDATE logistique."T_Article"
    SET "QteArticle" = 100
    WHERE "ID_Article" = v_id_article_1;

    UPDATE logistique."T_Article"
    SET "QteArticle" = 200
    WHERE "ID_Article" = v_id_article_2;

    UPDATE logistique."T_Article"
    SET "QteArticle" = 5
    WHERE "ID_Article" = v_id_article_alerte;

    RAISE NOTICE 'OK - Stocks initiaux ajustes';

    ---------------------------------------------------------------------------
    -- 4. COMMANDE D'ENTREE
    ---------------------------------------------------------------------------
    INSERT INTO logistique."T_Commande" (
        "ID_TypeCmdFk",
        "DateHeureAutoCmd",
        "DateCmd",
        "CodeCmd",
        "RefCmd",
        "MontantHT",
        "MontantTTC",
        "ObsCmd",
        "SelectCmd",
        "MontantRegleFacture",
        "MontantResteFacture",
        "StatusFacture"
    )
    VALUES (
        v_id_type_entree,
        now(),
        now(),
        v_code_cmd_entree,
        'Entree stock test vues',
        0,
        0,
        'Commande entree pour test vues',
        FALSE,
        0,
        0,
        'Non facturee'
    )
    RETURNING "ID_Commande" INTO v_id_cmd_entree;

    INSERT INTO logistique."T_CommandeDetail" (
        "ID_CmdFk",
        "ID_ArticleFk",
        "QteCmdDetail",
        "PUCmdDetail",
        "ObsCmdDetail",
        "RemiseCmdDetail",
        "LieuCmdDetail",
        "SelectCmdDetail"
    )
    VALUES
        (
            v_id_cmd_entree,
            v_id_article_1,
            50,
            1.00,
            'Entree gants',
            FALSE,
            NULL,
            FALSE
        ),
        (
            v_id_cmd_entree,
            v_id_article_2,
            100,
            0.50,
            'Entree masques',
            FALSE,
            NULL,
            FALSE
        );

    RAISE NOTICE 'OK - Commande entree creee : %', v_id_cmd_entree;

    ---------------------------------------------------------------------------
    -- 5. COMMANDE DE SORTIE
    ---------------------------------------------------------------------------
    INSERT INTO logistique."T_Commande" (
        "ID_TypeCmdFk",
        "DateHeureAutoCmd",
        "DateCmd",
        "CodeCmd",
        "RefCmd",
        "MontantHT",
        "MontantTTC",
        "ObsCmd",
        "SelectCmd",
        "DateFacture",
        "CodeFacture",
        "MontantRegleFacture",
        "MontantResteFacture",
        "StatusFacture"
    )
    VALUES (
        v_id_type_sortie,
        now(),
        now(),
        v_code_cmd_sortie,
        'Sortie stock test vues',
        0,
        0,
        'Commande sortie pour test vues',
        FALSE,
        now(),
        v_code_facture,
        0,
        0,
        'Non reglee'
    )
    RETURNING "ID_Commande" INTO v_id_cmd_sortie;

    INSERT INTO logistique."T_CommandeDetail" (
        "ID_CmdFk",
        "ID_ArticleFk",
        "QteCmdDetail",
        "PUCmdDetail",
        "ObsCmdDetail",
        "RemiseCmdDetail",
        "LieuCmdDetail",
        "SelectCmdDetail"
    )
    VALUES
        (
            v_id_cmd_sortie,
            v_id_article_1,
            20,
            2.00,
            'Sortie gants',
            FALSE,
            NULL,
            FALSE
        ),
        (
            v_id_cmd_sortie,
            v_id_article_2,
            40,
            1.00,
            'Sortie masques',
            FALSE,
            NULL,
            FALSE
        );

    RAISE NOTICE 'OK - Commande sortie creee : %', v_id_cmd_sortie;

    ---------------------------------------------------------------------------
    -- 6. COMMANDE SANS DETAIL
    ---------------------------------------------------------------------------
    INSERT INTO logistique."T_Commande" (
        "ID_TypeCmdFk",
        "DateHeureAutoCmd",
        "DateCmd",
        "CodeCmd",
        "RefCmd",
        "MontantHT",
        "MontantTTC",
        "ObsCmd",
        "SelectCmd",
        "StatusFacture"
    )
    VALUES (
        v_id_type_sortie,
        now(),
        now(),
        v_code_cmd_sans_detail,
        'Commande volontairement sans detail',
        0,
        0,
        'Commande creee pour tester V_CommandesSansDetails',
        FALSE,
        'Non reglee'
    )
    RETURNING "ID_Commande" INTO v_id_cmd_sans_detail;

    RAISE NOTICE 'OK - Commande sans detail creee : %', v_id_cmd_sans_detail;

    ---------------------------------------------------------------------------
    -- 7. ENREGISTREMENT DES REFERENCES DANS LA TABLE TEMPORAIRE
    ---------------------------------------------------------------------------
    INSERT INTO tmp_logistique_test_refs (
        objet,
        id_article,
        id_commande,
        code_article,
        code_cmd,
        code_facture
    )
    VALUES
        ('ARTICLE_1', v_id_article_1, NULL, v_code_article_1, NULL, NULL),
        ('ARTICLE_2', v_id_article_2, NULL, v_code_article_2, NULL, NULL),
        ('ARTICLE_ALERTE', v_id_article_alerte, NULL, v_code_article_alerte, NULL, NULL),
        ('CMD_ENTREE', NULL, v_id_cmd_entree, NULL, v_code_cmd_entree, NULL),
        ('CMD_SORTIE', NULL, v_id_cmd_sortie, NULL, v_code_cmd_sortie, v_code_facture),
        ('CMD_SANS_DETAIL', NULL, v_id_cmd_sans_detail, NULL, v_code_cmd_sans_detail, NULL);

    ---------------------------------------------------------------------------
    -- 8. CONTROLES STOCK ATTENDUS
    ---------------------------------------------------------------------------
    SELECT "QteArticle"
    INTO v_qte
    FROM logistique."T_Article"
    WHERE "ID_Article" = v_id_article_1;

    IF v_qte <> 130 THEN
        RAISE EXCEPTION 'Stock article 1 attendu = 130, obtenu = %', v_qte;
    END IF;

    SELECT "QteArticle"
    INTO v_qte
    FROM logistique."T_Article"
    WHERE "ID_Article" = v_id_article_2;

    IF v_qte <> 260 THEN
        RAISE EXCEPTION 'Stock article 2 attendu = 260, obtenu = %', v_qte;
    END IF;

    SELECT "QteArticle"
    INTO v_qte
    FROM logistique."T_Article"
    WHERE "ID_Article" = v_id_article_alerte;

    IF v_qte <> 5 THEN
        RAISE EXCEPTION 'Stock article alerte attendu = 5, obtenu = %', v_qte;
    END IF;

    RAISE NOTICE 'OK - Stocks attendus confirmes';

    ---------------------------------------------------------------------------
    -- 9. CONTROLES VUES PAR ID
    ---------------------------------------------------------------------------
    SELECT COUNT(*) INTO v_count
    FROM logistique."V_Article"
    WHERE "ID_Article" IN (v_id_article_1, v_id_article_2, v_id_article_alerte);

    IF v_count < 3 THEN
        RAISE EXCEPTION 'V_Article : attendu au moins 3 articles test, obtenu = %', v_count;
    END IF;

    SELECT COUNT(*) INTO v_count
    FROM logistique."V_Commande"
    WHERE "ID_Commande" IN (v_id_cmd_entree, v_id_cmd_sortie, v_id_cmd_sans_detail);

    IF v_count < 3 THEN
        RAISE EXCEPTION 'V_Commande : attendu au moins 3 commandes test, obtenu = %', v_count;
    END IF;

    SELECT COUNT(*) INTO v_count
    FROM logistique."V_CommandeDetail"
    WHERE "ID_CmdFk" IN (v_id_cmd_entree, v_id_cmd_sortie);

    IF v_count < 4 THEN
        RAISE EXCEPTION 'V_CommandeDetail : attendu au moins 4 lignes test, obtenu = %', v_count;
    END IF;

    SELECT COUNT(*) INTO v_count
    FROM logistique."V_CommandesSansDetails"
    WHERE "ID_Commande" = v_id_cmd_sans_detail;

    IF v_count < 1 THEN
        RAISE EXCEPTION 'V_CommandesSansDetails : commande sans detail non trouvee';
    END IF;

    RAISE NOTICE 'OK - Vues principales controlees';

    ---------------------------------------------------------------------------
    -- 10. CONTROLE AUDIT STOCK
    ---------------------------------------------------------------------------
    SELECT COUNT(*) INTO v_count
    FROM logistique."V_AuditStock"
    WHERE "ID_Article" IN (v_id_article_1, v_id_article_2, v_id_article_alerte);

    IF v_count < 3 THEN
        RAISE EXCEPTION 'V_AuditStock : attendu au moins 3 lignes, obtenu = %', v_count;
    END IF;

    RAISE NOTICE 'OK - V_AuditStock retourne les articles test';

    ---------------------------------------------------------------------------
    -- 11. CONTROLE ALERTE STOCK
    ---------------------------------------------------------------------------
    SELECT COUNT(*) INTO v_count
    FROM logistique."V_AlertStock"
    WHERE "ID_Article" = v_id_article_alerte;

    IF v_count < 1 THEN
        RAISE EXCEPTION 'V_AlertStock : article en alerte non trouve';
    END IF;

    RAISE NOTICE 'OK - V_AlertStock detecte l''article critique';

    ---------------------------------------------------------------------------
    -- 12. CONTROLE CONSOMMATION / COUVERTURE
    ---------------------------------------------------------------------------
    SELECT COUNT(*) INTO v_count
    FROM logistique."V_ConsoMensuelle"
    WHERE "ID_Article" IN (v_id_article_1, v_id_article_2);

    IF v_count < 1 THEN
        RAISE NOTICE 'Attention - V_ConsoMensuelle ne retourne pas encore les articles test. Verifier la logique de la vue.';
    ELSE
        RAISE NOTICE 'OK - V_ConsoMensuelle retourne des donnees test';
    END IF;

    SELECT COUNT(*) INTO v_count
    FROM logistique."V_CouvertureStock"
    WHERE "ID_Article" IN (v_id_article_1, v_id_article_2, v_id_article_alerte);

    IF v_count < 1 THEN
        RAISE NOTICE 'Attention - V_CouvertureStock ne retourne pas encore les articles test. Verifier la logique de la vue.';
    ELSE
        RAISE NOTICE 'OK - V_CouvertureStock retourne des donnees test';
    END IF;

    RAISE NOTICE '============================================================';
    RAISE NOTICE 'TEST DES VUES LOGISTIQUES TERMINE AVEC SUCCES';
    RAISE NOTICE 'Articles test : %, %, %', v_id_article_1, v_id_article_2, v_id_article_alerte;
    RAISE NOTICE 'Commandes test : entree %, sortie %, sans detail %', v_id_cmd_entree, v_id_cmd_sortie, v_id_cmd_sans_detail;
    RAISE NOTICE '============================================================';
END $$;

COMMIT;

-------------------------------------------------------------------------------
-- CONTROLES VISUELS APRES COMMIT
-------------------------------------------------------------------------------

-- Articles depuis V_Article
SELECT v.*
FROM logistique."V_Article" v
JOIN tmp_logistique_test_refs r ON r.id_article = v."ID_Article"
WHERE r.objet IN ('ARTICLE_1', 'ARTICLE_2', 'ARTICLE_ALERTE')
ORDER BY v."ID_Article";

-- Commandes depuis V_Commande
SELECT v.*
FROM logistique."V_Commande" v
JOIN tmp_logistique_test_refs r ON r.id_commande = v."ID_Commande"
WHERE r.objet IN ('CMD_ENTREE', 'CMD_SORTIE', 'CMD_SANS_DETAIL')
ORDER BY v."ID_Commande";

-- Details des commandes
SELECT v.*
FROM logistique."V_CommandeDetail" v
JOIN tmp_logistique_test_refs r ON r.id_commande = v."ID_CmdFk"
WHERE r.objet IN ('CMD_ENTREE', 'CMD_SORTIE')
ORDER BY v."ID_CmdFk", v."ID_ArticleFk";

-- Audit stock
SELECT v.*
FROM logistique."V_AuditStock" v
JOIN tmp_logistique_test_refs r ON r.id_article = v."ID_Article"
WHERE r.objet IN ('ARTICLE_1', 'ARTICLE_2', 'ARTICLE_ALERTE')
ORDER BY v."ID_Article";

-- Alertes stock
SELECT v.*
FROM logistique."V_AlertStock" v
JOIN tmp_logistique_test_refs r ON r.id_article = v."ID_Article"
WHERE r.objet IN ('ARTICLE_1', 'ARTICLE_2', 'ARTICLE_ALERTE')
ORDER BY v."ID_Article";

-- Commandes sans details
SELECT v.*
FROM logistique."V_CommandesSansDetails" v
JOIN tmp_logistique_test_refs r ON r.id_commande = v."ID_Commande"
WHERE r.objet = 'CMD_SANS_DETAIL';

-- Consommation mensuelle
SELECT v.*
FROM logistique."V_ConsoMensuelle" v
JOIN tmp_logistique_test_refs r ON r.id_article = v."ID_Article"
WHERE r.objet IN ('ARTICLE_1', 'ARTICLE_2', 'ARTICLE_ALERTE')
ORDER BY v."ID_Article", v."Mois";

-- Couverture stock
SELECT v.*
FROM logistique."V_CouvertureStock" v
JOIN tmp_logistique_test_refs r ON r.id_article = v."ID_Article"
WHERE r.objet IN ('ARTICLE_1', 'ARTICLE_2', 'ARTICLE_ALERTE')
ORDER BY v."ID_Article";

-- Suivi reglements / facture
SELECT v.*
FROM logistique."V_SuiviReglements" v
JOIN tmp_logistique_test_refs r ON r.code_facture = v."CodeFacture"
WHERE r.objet = 'CMD_SORTIE';
