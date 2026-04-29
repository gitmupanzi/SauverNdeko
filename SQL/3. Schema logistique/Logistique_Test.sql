/* ============================================================================
   TEST METIER DU MODULE LOGISTIQUE
   Aligne sur scenario_metier_logistique.md

   Principe :
   - le script travaille dans une transaction de test
   - il n'ecrit jamais directement dans T_Mouvement
   - il verifie les regles officielles :
       INSERT applique l'effet
       DELETE annule l'effet
       UPDATE annule l'ancien effet puis applique le nouveau
   - il se termine par ROLLBACK pour ne pas polluer la base
   ============================================================================ */

BEGIN;

DO $$
DECLARE
    v_type_entree integer;
    v_type_sortie integer;
    v_categorie_type_commande integer := 64;
    v_suffix text;
    v_code_article text;
    v_code_cmd_entree text;
    v_code_cmd_sortie text;
    v_id_article integer;
    v_id_cmd_entree integer;
    v_id_cmd_sortie integer;
    v_id_cmd_sortie_fail integer;
    v_stock numeric;
    v_count integer;
BEGIN
    SELECT g."ID_Generique"
    INTO v_type_entree
    FROM referentiel."T_Generique" g
    WHERE g."ID_CategorieGeneriqueFk" = v_categorie_type_commande
      AND g."AbrGenerique" ILIKE 'entr%'
    ORDER BY g."ID_Generique"
    LIMIT 1;

    SELECT g."ID_Generique"
    INTO v_type_sortie
    FROM referentiel."T_Generique" g
    WHERE g."ID_CategorieGeneriqueFk" = v_categorie_type_commande
      AND g."AbrGenerique" ILIKE 'sort%'
    ORDER BY g."ID_Generique"
    LIMIT 1;

    IF v_type_entree IS NULL OR v_type_sortie IS NULL THEN
        RAISE EXCEPTION
            'Les types Entree / Sortie sont introuvables dans T_Generique pour la categorie %.',
            v_categorie_type_commande;
    END IF;

    RAISE NOTICE 'Categorie generique attendue pour Entree / Sortie : %', v_categorie_type_commande;

    v_suffix := to_char(clock_timestamp(), 'YYYYMMDDHH24MISSMS');
    v_code_article := 'SCN-ART-' || right(v_suffix, 10);
    v_code_cmd_entree := 'SCN-E-' || right(v_suffix, 8);
    v_code_cmd_sortie := 'SCN-S-' || right(v_suffix, 8);

    RAISE NOTICE '=== 1. Creation article avec stock initial positif ===';

    INSERT INTO logistique."T_Article" (
        "DateHeureAuto",
        "NomArticle",
        "RefArticle",
        "QteArticle",
        "PUArticle",
        "PVArticle",
        "QteMinArticle",
        "ObsArticle",
        "ValideArticle",
        "CodeArticleInterne"
    )
    VALUES (
        now(),
        'Article scenario logistique',
        'REF-' || v_code_article,
        5,
        100,
        150,
        2,
        'Article de test scenario',
        TRUE,
        v_code_article
    )
    RETURNING "ID_Article" INTO v_id_article;

    SELECT COUNT(*)::int
    INTO v_count
    FROM logistique."T_Mouvement"
    WHERE "ID_ArticleFk" = v_id_article
      AND "ID_cmdFk" IS NULL
      AND "ID_TypeMvtFk" = v_type_entree
      AND "QteMvt" = 5;

    IF v_count <> 1 THEN
        RAISE EXCEPTION
            'Echec: la creation de l''article avec QteArticle=5 devait creer 1 mouvement d''entree de 5.';
    END IF;

    RAISE NOTICE '=== 2. Mise a jour directe de l''article ===';

    UPDATE logistique."T_Article"
    SET "QteArticle" = 10
    WHERE "ID_Article" = v_id_article;

    SELECT COUNT(*)::int
    INTO v_count
    FROM logistique."T_Mouvement"
    WHERE "ID_ArticleFk" = v_id_article
      AND "ID_cmdFk" IS NULL
      AND "ID_TypeMvtFk" = v_type_entree
      AND "QteMvt" = 5;

    IF v_count < 2 THEN
        RAISE EXCEPTION
            'Echec: l''augmentation directe du stock devait creer un second mouvement d''entree de 5.';
    END IF;

    RAISE NOTICE '=== 3. Commande d''entree ===';

    INSERT INTO logistique."T_Commande" (
        "ID_TypeCmdFk",
        "DateHeureAutoCmd",
        "DateCmd",
        "CodeCmd",
        "ObsCmd",
        "SelectCmd"
    )
    VALUES (
        v_type_entree,
        now(),
        now(),
        v_code_cmd_entree,
        'Commande entree scenario',
        FALSE
    )
    RETURNING "ID_Commande" INTO v_id_cmd_entree;

    INSERT INTO logistique."T_CommandeDetail" (
        "ID_CmdFk",
        "ID_ArticleFk",
        "QteCmdDetail",
        "PUCmdDetail",
        "ObsCmdDetail",
        "RemiseCmdDetail",
        "SelectCmdDetail"
    )
    VALUES (
        v_id_cmd_entree,
        v_id_article,
        5,
        150,
        'Detail entree scenario',
        FALSE,
        FALSE
    );

    SELECT "QteArticle"
    INTO v_stock
    FROM logistique."T_Article"
    WHERE "ID_Article" = v_id_article;

    IF v_stock <> 15 THEN
        RAISE EXCEPTION
            'Echec: la ligne de commande entree devait porter le stock a 15, stock obtenu=%.',
            v_stock;
    END IF;

    SELECT COUNT(*)::int
    INTO v_count
    FROM logistique."T_Mouvement"
    WHERE "ID_TypeMvtFk" = v_type_entree
      AND "ID_ArticleFk" = v_id_article
      AND "ID_cmdFk" = v_id_cmd_entree
      AND "QteMvt" = 5;

    IF v_count <> 1 THEN
        RAISE EXCEPTION
            'Echec: la ligne de commande entree devait creer 1 mouvement de commande.';
    END IF;

    RAISE NOTICE '=== 4. Mise a jour du detail de commande d''entree ===';

    UPDATE logistique."T_CommandeDetail"
    SET "QteCmdDetail" = 7
    WHERE "ID_CmdFk" = v_id_cmd_entree
      AND "ID_ArticleFk" = v_id_article;

    SELECT "QteArticle"
    INTO v_stock
    FROM logistique."T_Article"
    WHERE "ID_Article" = v_id_article;

    IF v_stock <> 17 THEN
        RAISE EXCEPTION
            'Echec: la mise a jour de la ligne d''entree devait porter le stock a 17, stock obtenu=%.',
            v_stock;
    END IF;

    SELECT COUNT(*)::int
    INTO v_count
    FROM logistique."T_Mouvement"
    WHERE "ID_TypeMvtFk" = v_type_entree
      AND "ID_ArticleFk" = v_id_article
      AND "ID_cmdFk" = v_id_cmd_entree;

    IF v_count <> 1 THEN
        RAISE EXCEPTION
            'Echec: l''UPDATE devait laisser un seul mouvement de commande pour le triplet type/article/commande.';
    END IF;

    SELECT COUNT(*)::int
    INTO v_count
    FROM logistique."T_Mouvement"
    WHERE "ID_TypeMvtFk" = v_type_entree
      AND "ID_ArticleFk" = v_id_article
      AND "ID_cmdFk" = v_id_cmd_entree
      AND "QteMvt" = 7;

    IF v_count <> 1 THEN
        RAISE EXCEPTION
            'Echec: le mouvement final devait representer la nouvelle quantite 7.';
    END IF;

    RAISE NOTICE '=== 5. Commande de sortie ===';

    INSERT INTO logistique."T_Commande" (
        "ID_TypeCmdFk",
        "DateHeureAutoCmd",
        "DateCmd",
        "CodeCmd",
        "ObsCmd",
        "SelectCmd"
    )
    VALUES (
        v_type_sortie,
        now(),
        now(),
        v_code_cmd_sortie,
        'Commande sortie scenario',
        FALSE
    )
    RETURNING "ID_Commande" INTO v_id_cmd_sortie;

    INSERT INTO logistique."T_CommandeDetail" (
        "ID_CmdFk",
        "ID_ArticleFk",
        "QteCmdDetail",
        "PUCmdDetail",
        "ObsCmdDetail",
        "RemiseCmdDetail",
        "SelectCmdDetail"
    )
    VALUES (
        v_id_cmd_sortie,
        v_id_article,
        4,
        150,
        'Detail sortie scenario',
        FALSE,
        FALSE
    );

    SELECT "QteArticle"
    INTO v_stock
    FROM logistique."T_Article"
    WHERE "ID_Article" = v_id_article;

    IF v_stock <> 13 THEN
        RAISE EXCEPTION
            'Echec: la ligne de commande sortie devait porter le stock a 13, stock obtenu=%.',
            v_stock;
    END IF;

    RAISE NOTICE '=== 6. Sortie impossible si stock insuffisant ===';

    BEGIN
        INSERT INTO logistique."T_Commande" (
            "ID_TypeCmdFk",
            "DateHeureAutoCmd",
            "DateCmd",
            "CodeCmd",
            "ObsCmd",
            "SelectCmd"
        )
        VALUES (
            v_type_sortie,
            now(),
            now(),
            v_code_cmd_sortie || '-X',
            'Commande sortie echec scenario',
            FALSE
        )
        RETURNING "ID_Commande" INTO v_id_cmd_sortie_fail;

        INSERT INTO logistique."T_CommandeDetail" (
            "ID_CmdFk",
            "ID_ArticleFk",
            "QteCmdDetail",
            "PUCmdDetail",
            "ObsCmdDetail",
            "RemiseCmdDetail",
            "SelectCmdDetail"
        )
        VALUES (
            v_id_cmd_sortie_fail,
            v_id_article,
            1000,
            150,
            'Sortie impossible',
            FALSE,
            FALSE
        );

        RAISE EXCEPTION
            'Echec: une sortie qui rend le stock negatif aurait du etre bloquee.';
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'Blocage attendu recu pour la sortie insuffisante: %', SQLERRM;
    END;

    RAISE NOTICE '=== 7. Suppression du detail de sortie ===';

    DELETE FROM logistique."T_CommandeDetail"
    WHERE "ID_CmdFk" = v_id_cmd_sortie
      AND "ID_ArticleFk" = v_id_article;

    SELECT "QteArticle"
    INTO v_stock
    FROM logistique."T_Article"
    WHERE "ID_Article" = v_id_article;

    IF v_stock <> 17 THEN
        RAISE EXCEPTION
            'Echec: la suppression de la sortie devait restituer le stock a 17, stock obtenu=%.',
            v_stock;
    END IF;

    SELECT COUNT(*)::int
    INTO v_count
    FROM logistique."T_Mouvement"
    WHERE "ID_TypeMvtFk" = v_type_sortie
      AND "ID_ArticleFk" = v_id_article
      AND "ID_cmdFk" = v_id_cmd_sortie;

    IF v_count <> 0 THEN
        RAISE EXCEPTION
            'Echec: la suppression du detail de sortie devait supprimer son mouvement associe.';
    END IF;

    RAISE NOTICE '=== 8. Suppression de la commande d''entree ===';

    DELETE FROM logistique."T_Commande"
    WHERE "ID_Commande" = v_id_cmd_entree;

    SELECT "QteArticle"
    INTO v_stock
    FROM logistique."T_Article"
    WHERE "ID_Article" = v_id_article;

    IF v_stock <> 10 THEN
        RAISE EXCEPTION
            'Echec: la suppression de la commande d''entree devait annuler son effet et ramener le stock a 10, stock obtenu=%.',
            v_stock;
    END IF;

    SELECT COUNT(*)::int
    INTO v_count
    FROM logistique."T_Mouvement"
    WHERE "ID_TypeMvtFk" = v_type_entree
      AND "ID_ArticleFk" = v_id_article
      AND "ID_cmdFk" = v_id_cmd_entree;

    IF v_count <> 0 THEN
        RAISE EXCEPTION
            'Echec: la suppression de la commande d''entree devait nettoyer ses mouvements associes.';
    END IF;

    RAISE NOTICE '=== 9. Suppression article lie a un mouvement interdite ===';

    BEGIN
        DELETE FROM logistique."T_Article"
        WHERE "ID_Article" = v_id_article;

        RAISE EXCEPTION
            'Echec: la suppression d''un article lie a T_Mouvement aurait du etre interdite.';
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'Blocage attendu recu pour la suppression de l''article: %', SQLERRM;
    END;

    RAISE NOTICE '=== TEST METIER LOGISTIQUE TERMINE AVEC SUCCES ===';
END $$;

ROLLBACK;
