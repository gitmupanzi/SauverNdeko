/* ============================================================================
 TEST METIER LOGISTIQUE AVEC EVOLUTION DES VALEURS
 SauverNdeko - T_Article, T_Commande, T_CommandeDetail
 
 Objectif :
 - conserver le test metier existant ;
 - afficher l'evolution des valeurs lors des operations :
 INSERT / UPDATE / DELETE sur T_Article ;
 INSERT / UPDATE / DELETE sur T_Commande ;
 INSERT / UPDATE / DELETE sur T_CommandeDetail ;
 - afficher les impacts sur :
 stock article ;
 quantite detail ;
 prix detail ;
 montant commande ;
 mouvements ;
 quantite mouvement signee ;
 type de commande ;
 - terminer par ROLLBACK pour ne pas polluer la base.
 
 Important :
 - les resultats visuels sont disponibles dans les SELECT avant le ROLLBACK ;
 - aucune donnee de test n'est conservee apres execution.
 ============================================================================ */
BEGIN;
CREATE TEMP TABLE tmp_logistique_evolution (
    ordre integer,
    phase text,
    operation text,
    table_cible text,
    moment text,
    id_article integer,
    id_commande integer,
    code_cmd text,
    type_cmd text,
    qte_article numeric(14, 3),
    qte_cmd_detail numeric(14, 3),
    pu_cmd_detail numeric(12, 2),
    montant_ht numeric(12, 2),
    montant_details numeric(12, 2),
    nb_lignes bigint,
    nb_mouvements integer,
    qte_mvt_signed numeric,
    dernier_pumvt numeric(12, 2),
    commentaire text
) ON COMMIT DROP;
DO $$
DECLARE v_type_entree integer;
v_type_sortie integer;
v_categorie_type_commande integer := 64;
v_suffix text;
v_code_article text;
v_code_cmd_entree text;
v_code_cmd_sortie text;
v_code_cmd_fail text;
v_code_cmd_fraction text;
v_id_article integer;
v_id_cmd_entree integer;
v_id_cmd_sortie integer;
v_id_cmd_fail integer;
v_id_cmd_fraction integer;
v_stock numeric(14, 3);
v_stock_before numeric(14, 3);
v_montant numeric(12, 2);
v_pu_mvt numeric(12, 2);
v_qte_signed numeric;
v_signe integer;
v_ecart numeric;
v_count integer;
v_ordre integer := 0;
BEGIN
/* ========================================================================
 0. RECUPERATION DES TYPES ENTREE / SORTIE
 ======================================================================== */
SELECT g."ID_Generique" INTO v_type_entree
FROM referentiel."T_Generique" g
WHERE g."ID_CategorieGeneriqueFk" = v_categorie_type_commande
    AND g."AbrGenerique" ILIKE 'entr%'
ORDER BY g."ID_Generique"
LIMIT 1;
SELECT g."ID_Generique" INTO v_type_sortie
FROM referentiel."T_Generique" g
WHERE g."ID_CategorieGeneriqueFk" = v_categorie_type_commande
    AND g."AbrGenerique" ILIKE 'sort%'
ORDER BY g."ID_Generique"
LIMIT 1;
IF v_type_entree IS NULL
OR v_type_sortie IS NULL THEN RAISE EXCEPTION 'Types Entree / Sortie introuvables dans referentiel.T_Generique pour la categorie %.',
v_categorie_type_commande;
END IF;
v_suffix := to_char(clock_timestamp(), 'YYYYMMDDHH24MISSMS');
v_code_article := 'EVOL-ART-' || right(v_suffix, 10);
v_code_cmd_entree := 'EVOL-E-' || right(v_suffix, 8);
v_code_cmd_sortie := 'EVOL-S-' || right(v_suffix, 8);
v_code_cmd_fail := 'EVOL-F-' || right(v_suffix, 8);
v_code_cmd_fraction := 'EVOL-Q-' || right(v_suffix, 8);
RAISE NOTICE '============================================================';
RAISE NOTICE 'TEST METIER LOGISTIQUE AVEC EVOLUTION DES VALEURS';
RAISE NOTICE 'Types detectes : Entree=%, Sortie=%',
v_type_entree,
v_type_sortie;
RAISE NOTICE 'Code article test : %',
v_code_article;
RAISE NOTICE '============================================================';
/* ========================================================================
 1. INSERT T_ARTICLE AVEC STOCK INITIAL
 ======================================================================== */
RAISE NOTICE '=== 1. INSERT T_Article avec stock initial ===';
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
        'Article evolution scenario logistique',
        'REF-' || v_code_article,
        20,
        100,
        150,
        2,
        'Article de test evolution',
        TRUE,
        v_code_article
    )
RETURNING "ID_Article" INTO v_id_article;
v_ordre := v_ordre + 1;
INSERT INTO tmp_logistique_evolution (
        ordre,
        phase,
        operation,
        table_cible,
        moment,
        id_article,
        qte_article,
        nb_mouvements,
        qte_mvt_signed,
        commentaire
    )
SELECT v_ordre,
    '1. Article',
    'INSERT',
    'T_Article',
    'APRES',
    a."ID_Article",
    a."QteArticle",
    COALESCE(m.nb_mouvements, 0),
    COALESCE(m.qte_mvt_signed, 0),
    'Création article avec QteArticle=20 : création automatique mouvement entrée +20.'
FROM logistique."V_Article" a
    LEFT JOIN LATERAL (
        SELECT COUNT(*)::integer AS nb_mouvements,
            COALESCE(SUM(v."QteMvtSigned"), 0)::numeric AS qte_mvt_signed
        FROM logistique."V_MouvementStock" v
        WHERE v."ID_ArticleFk" = a."ID_Article"
    ) m ON true
WHERE a."ID_Article" = v_id_article;
SELECT "QteArticle" INTO v_stock
FROM logistique."T_Article"
WHERE "ID_Article" = v_id_article;
IF v_stock <> 20 THEN RAISE EXCEPTION 'Echec 1A : stock article attendu=20, obtenu=%.',
v_stock;
END IF;
SELECT COUNT(*)::int INTO v_count
FROM logistique."T_Mouvement"
WHERE "ID_ArticleFk" = v_id_article
    AND "ID_cmdFk" IS NULL
    AND "ID_TypeMvtFk" = v_type_entree
    AND "QteMvt" = 20;
IF v_count <> 1 THEN RAISE EXCEPTION 'Echec 1B : creation article QteArticle=20 devait creer un mouvement direct Entree de 20. Nombre obtenu=%',
v_count;
END IF;
/* ========================================================================
 2. UPDATE T_ARTICLE : STOCK DIRECT 20 -> 25
 ======================================================================== */
RAISE NOTICE '=== 2. UPDATE T_Article : QteArticle 20 -> 25 ===';
v_ordre := v_ordre + 1;
INSERT INTO tmp_logistique_evolution (
        ordre,
        phase,
        operation,
        table_cible,
        moment,
        id_article,
        qte_article,
        nb_mouvements,
        qte_mvt_signed,
        commentaire
    )
SELECT v_ordre,
    '2. Article',
    'UPDATE',
    'T_Article',
    'AVANT',
    a."ID_Article",
    a."QteArticle",
    COALESCE(m.nb_mouvements, 0),
    COALESCE(m.qte_mvt_signed, 0),
    'Avant modification directe du stock article.'
FROM logistique."V_Article" a
    LEFT JOIN LATERAL (
        SELECT COUNT(*)::integer AS nb_mouvements,
            COALESCE(SUM(v."QteMvtSigned"), 0)::numeric AS qte_mvt_signed
        FROM logistique."V_MouvementStock" v
        WHERE v."ID_ArticleFk" = a."ID_Article"
    ) m ON true
WHERE a."ID_Article" = v_id_article;
UPDATE logistique."T_Article"
SET "QteArticle" = 25
WHERE "ID_Article" = v_id_article;
v_ordre := v_ordre + 1;
INSERT INTO tmp_logistique_evolution (
        ordre,
        phase,
        operation,
        table_cible,
        moment,
        id_article,
        qte_article,
        nb_mouvements,
        qte_mvt_signed,
        commentaire
    )
SELECT v_ordre,
    '2. Article',
    'UPDATE',
    'T_Article',
    'APRES',
    a."ID_Article",
    a."QteArticle",
    COALESCE(m.nb_mouvements, 0),
    COALESCE(m.qte_mvt_signed, 0),
    'Après QteArticle 20 -> 25 : création mouvement entrée +5.'
FROM logistique."V_Article" a
    LEFT JOIN LATERAL (
        SELECT COUNT(*)::integer AS nb_mouvements,
            COALESCE(SUM(v."QteMvtSigned"), 0)::numeric AS qte_mvt_signed
        FROM logistique."V_MouvementStock" v
        WHERE v."ID_ArticleFk" = a."ID_Article"
    ) m ON true
WHERE a."ID_Article" = v_id_article;
SELECT "QteArticle" INTO v_stock
FROM logistique."T_Article"
WHERE "ID_Article" = v_id_article;
IF v_stock <> 25 THEN RAISE EXCEPTION 'Echec 2A : stock attendu=25 apres update direct, obtenu=%.',
v_stock;
END IF;
/* ========================================================================
 3. INSERT T_COMMANDE ENTREE SANS DETAIL
 ======================================================================== */
RAISE NOTICE '=== 3. INSERT T_Commande entrée sans détail ===';
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
        'Commande entree test evolution',
        FALSE
    )
RETURNING "ID_Commande" INTO v_id_cmd_entree;
v_ordre := v_ordre + 1;
INSERT INTO tmp_logistique_evolution (
        ordre,
        phase,
        operation,
        table_cible,
        moment,
        id_article,
        id_commande,
        code_cmd,
        type_cmd,
        qte_article,
        montant_ht,
        montant_details,
        nb_lignes,
        nb_mouvements,
        qte_mvt_signed,
        commentaire
    )
SELECT v_ordre,
    '3. Commande',
    'INSERT',
    'T_Commande',
    'APRES',
    v_id_article,
    c."ID_Commande",
    c."CodeCmd",
    c."AbrTypeCmd",
    a."QteArticle",
    c."MontantHT",
    c."MontantDetails",
    c."NbLignes",
    COALESCE(m.nb_mouvements, 0),
    COALESCE(m.qte_mvt_signed, 0),
    'Création entête commande entrée : aucun impact stock tant qu’il n’y a pas de détail.'
FROM logistique."V_Commande" c
    CROSS JOIN logistique."V_Article" a
    LEFT JOIN LATERAL (
        SELECT COUNT(*)::integer AS nb_mouvements,
            COALESCE(SUM(v."QteMvtSigned"), 0)::numeric AS qte_mvt_signed
        FROM logistique."V_MouvementStock" v
        WHERE v."ID_ArticleFk" = a."ID_Article"
    ) m ON true
WHERE c."ID_Commande" = v_id_cmd_entree
    AND a."ID_Article" = v_id_article;
/* ========================================================================
 4. INSERT T_COMMANDEDETAIL ENTREE
 Stock 25 + 5 = 30
 ======================================================================== */
RAISE NOTICE '=== 4. INSERT T_CommandeDetail entrée ===';
v_ordre := v_ordre + 1;
INSERT INTO tmp_logistique_evolution (
        ordre,
        phase,
        operation,
        table_cible,
        moment,
        id_article,
        id_commande,
        code_cmd,
        type_cmd,
        qte_article,
        montant_ht,
        montant_details,
        nb_lignes,
        nb_mouvements,
        qte_mvt_signed,
        commentaire
    )
SELECT v_ordre,
    '4. Détail commande',
    'INSERT',
    'T_CommandeDetail',
    'AVANT',
    v_id_article,
    c."ID_Commande",
    c."CodeCmd",
    c."AbrTypeCmd",
    a."QteArticle",
    c."MontantHT",
    c."MontantDetails",
    c."NbLignes",
    COALESCE(m.nb_mouvements, 0),
    COALESCE(m.qte_mvt_signed, 0),
    'Avant ajout détail entrée : stock encore inchangé.'
FROM logistique."V_Commande" c
    CROSS JOIN logistique."V_Article" a
    LEFT JOIN LATERAL (
        SELECT COUNT(*)::integer AS nb_mouvements,
            COALESCE(SUM(v."QteMvtSigned"), 0)::numeric AS qte_mvt_signed
        FROM logistique."V_MouvementStock" v
        WHERE v."ID_ArticleFk" = a."ID_Article"
    ) m ON true
WHERE c."ID_Commande" = v_id_cmd_entree
    AND a."ID_Article" = v_id_article;
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
        111.25,
        'Detail entree test evolution',
        FALSE,
        FALSE
    );
v_ordre := v_ordre + 1;
INSERT INTO tmp_logistique_evolution (
        ordre,
        phase,
        operation,
        table_cible,
        moment,
        id_article,
        id_commande,
        code_cmd,
        type_cmd,
        qte_article,
        qte_cmd_detail,
        pu_cmd_detail,
        montant_ht,
        montant_details,
        nb_lignes,
        nb_mouvements,
        qte_mvt_signed,
        dernier_pumvt,
        commentaire
    )
SELECT v_ordre,
    '4. Détail commande',
    'INSERT',
    'T_CommandeDetail',
    'APRES',
    d."ID_ArticleFk",
    d."ID_CmdFk",
    d."CodeCmd",
    d."AbrTypeCmd",
    d."StockActuel",
    d."QteCmdDetail",
    d."PUCmdDetail",
    c."MontantHT",
    c."MontantDetails",
    c."NbLignes",
    COALESCE(m.nb_mouvements, 0),
    COALESCE(m.qte_mvt_signed, 0),
    COALESCE(m.dernier_pumvt, 0),
    'Après ajout détail entrée : stock +5, mouvement commande créé, PUMvt=PUCmdDetail.'
FROM logistique."V_CommandeDetail" d
    JOIN logistique."V_Commande" c ON c."ID_Commande" = d."ID_CmdFk"
    LEFT JOIN LATERAL (
        SELECT COUNT(*)::integer AS nb_mouvements,
            COALESCE(SUM(v."QteMvtSigned"), 0)::numeric AS qte_mvt_signed,
            MAX(v."PUMvt")::numeric(12, 2) AS dernier_pumvt
        FROM logistique."V_MouvementStock" v
        WHERE v."ID_ArticleFk" = d."ID_ArticleFk"
            AND v."ID_cmdFk" = d."ID_CmdFk"
    ) m ON true
WHERE d."ID_CmdFk" = v_id_cmd_entree
    AND d."ID_ArticleFk" = v_id_article;
SELECT "QteArticle" INTO v_stock
FROM logistique."T_Article"
WHERE "ID_Article" = v_id_article;
IF v_stock <> 30 THEN RAISE EXCEPTION 'Echec 4A : entree de 5 devait porter le stock a 30, obtenu=%.',
v_stock;
END IF;
/* ========================================================================
 5. UPDATE T_COMMANDEDETAIL : PRIX UNIQUEMENT
 ======================================================================== */
RAISE NOTICE '=== 5. UPDATE T_CommandeDetail prix uniquement ===';
v_ordre := v_ordre + 1;
INSERT INTO tmp_logistique_evolution (
        ordre,
        phase,
        operation,
        table_cible,
        moment,
        id_article,
        id_commande,
        code_cmd,
        type_cmd,
        qte_article,
        qte_cmd_detail,
        pu_cmd_detail,
        montant_ht,
        montant_details,
        nb_lignes,
        nb_mouvements,
        qte_mvt_signed,
        dernier_pumvt,
        commentaire
    )
SELECT v_ordre,
    '5. Détail commande',
    'UPDATE PRIX',
    'T_CommandeDetail',
    'AVANT',
    d."ID_ArticleFk",
    d."ID_CmdFk",
    d."CodeCmd",
    d."AbrTypeCmd",
    d."StockActuel",
    d."QteCmdDetail",
    d."PUCmdDetail",
    c."MontantHT",
    c."MontantDetails",
    c."NbLignes",
    COALESCE(m.nb_mouvements, 0),
    COALESCE(m.qte_mvt_signed, 0),
    COALESCE(m.dernier_pumvt, 0),
    'Avant modification du prix uniquement.'
FROM logistique."V_CommandeDetail" d
    JOIN logistique."V_Commande" c ON c."ID_Commande" = d."ID_CmdFk"
    LEFT JOIN LATERAL (
        SELECT COUNT(*)::integer AS nb_mouvements,
            COALESCE(SUM(v."QteMvtSigned"), 0)::numeric AS qte_mvt_signed,
            MAX(v."PUMvt")::numeric(12, 2) AS dernier_pumvt
        FROM logistique."V_MouvementStock" v
        WHERE v."ID_ArticleFk" = d."ID_ArticleFk"
            AND v."ID_cmdFk" = d."ID_CmdFk"
    ) m ON true
WHERE d."ID_CmdFk" = v_id_cmd_entree
    AND d."ID_ArticleFk" = v_id_article;
UPDATE logistique."T_CommandeDetail"
SET "PUCmdDetail" = 222.50
WHERE "ID_CmdFk" = v_id_cmd_entree
    AND "ID_ArticleFk" = v_id_article;
v_ordre := v_ordre + 1;
INSERT INTO tmp_logistique_evolution (
        ordre,
        phase,
        operation,
        table_cible,
        moment,
        id_article,
        id_commande,
        code_cmd,
        type_cmd,
        qte_article,
        qte_cmd_detail,
        pu_cmd_detail,
        montant_ht,
        montant_details,
        nb_lignes,
        nb_mouvements,
        qte_mvt_signed,
        dernier_pumvt,
        commentaire
    )
SELECT v_ordre,
    '5. Détail commande',
    'UPDATE PRIX',
    'T_CommandeDetail',
    'APRES',
    d."ID_ArticleFk",
    d."ID_CmdFk",
    d."CodeCmd",
    d."AbrTypeCmd",
    d."StockActuel",
    d."QteCmdDetail",
    d."PUCmdDetail",
    c."MontantHT",
    c."MontantDetails",
    c."NbLignes",
    COALESCE(m.nb_mouvements, 0),
    COALESCE(m.qte_mvt_signed, 0),
    COALESCE(m.dernier_pumvt, 0),
    'Après modification prix : stock inchangé, MontantHT recalculé, PUMvt mis à jour.'
FROM logistique."V_CommandeDetail" d
    JOIN logistique."V_Commande" c ON c."ID_Commande" = d."ID_CmdFk"
    LEFT JOIN LATERAL (
        SELECT COUNT(*)::integer AS nb_mouvements,
            COALESCE(SUM(v."QteMvtSigned"), 0)::numeric AS qte_mvt_signed,
            MAX(v."PUMvt")::numeric(12, 2) AS dernier_pumvt
        FROM logistique."V_MouvementStock" v
        WHERE v."ID_ArticleFk" = d."ID_ArticleFk"
            AND v."ID_cmdFk" = d."ID_CmdFk"
    ) m ON true
WHERE d."ID_CmdFk" = v_id_cmd_entree
    AND d."ID_ArticleFk" = v_id_article;
SELECT "QteArticle" INTO v_stock
FROM logistique."T_Article"
WHERE "ID_Article" = v_id_article;
IF v_stock <> 30 THEN RAISE EXCEPTION 'Echec 5A : modification prix uniquement ne doit pas changer le stock. Stock obtenu=%.',
v_stock;
END IF;
SELECT "MontantHT" INTO v_montant
FROM logistique."T_Commande"
WHERE "ID_Commande" = v_id_cmd_entree;
IF v_montant <> 1112.50 THEN RAISE EXCEPTION 'Echec 5B : MontantHT attendu=1112.50, obtenu=%.',
v_montant;
END IF;
/* ========================================================================
 6. UPDATE T_COMMANDEDETAIL : QUANTITE 5 -> 7
 ======================================================================== */
RAISE NOTICE '=== 6. UPDATE T_CommandeDetail quantité 5 -> 7 ===';
v_ordre := v_ordre + 1;
INSERT INTO tmp_logistique_evolution (
        ordre,
        phase,
        operation,
        table_cible,
        moment,
        id_article,
        id_commande,
        code_cmd,
        type_cmd,
        qte_article,
        qte_cmd_detail,
        pu_cmd_detail,
        montant_ht,
        montant_details,
        nb_lignes,
        nb_mouvements,
        qte_mvt_signed,
        dernier_pumvt,
        commentaire
    )
SELECT v_ordre,
    '6. Détail commande',
    'UPDATE QTE',
    'T_CommandeDetail',
    'AVANT',
    d."ID_ArticleFk",
    d."ID_CmdFk",
    d."CodeCmd",
    d."AbrTypeCmd",
    d."StockActuel",
    d."QteCmdDetail",
    d."PUCmdDetail",
    c."MontantHT",
    c."MontantDetails",
    c."NbLignes",
    COALESCE(m.nb_mouvements, 0),
    COALESCE(m.qte_mvt_signed, 0),
    COALESCE(m.dernier_pumvt, 0),
    'Avant modification quantité entrée.'
FROM logistique."V_CommandeDetail" d
    JOIN logistique."V_Commande" c ON c."ID_Commande" = d."ID_CmdFk"
    LEFT JOIN LATERAL (
        SELECT COUNT(*)::integer AS nb_mouvements,
            COALESCE(SUM(v."QteMvtSigned"), 0)::numeric AS qte_mvt_signed,
            MAX(v."PUMvt")::numeric(12, 2) AS dernier_pumvt
        FROM logistique."V_MouvementStock" v
        WHERE v."ID_ArticleFk" = d."ID_ArticleFk"
            AND v."ID_cmdFk" = d."ID_CmdFk"
    ) m ON true
WHERE d."ID_CmdFk" = v_id_cmd_entree
    AND d."ID_ArticleFk" = v_id_article;
UPDATE logistique."T_CommandeDetail"
SET "QteCmdDetail" = 7
WHERE "ID_CmdFk" = v_id_cmd_entree
    AND "ID_ArticleFk" = v_id_article;
v_ordre := v_ordre + 1;
INSERT INTO tmp_logistique_evolution (
        ordre,
        phase,
        operation,
        table_cible,
        moment,
        id_article,
        id_commande,
        code_cmd,
        type_cmd,
        qte_article,
        qte_cmd_detail,
        pu_cmd_detail,
        montant_ht,
        montant_details,
        nb_lignes,
        nb_mouvements,
        qte_mvt_signed,
        dernier_pumvt,
        commentaire
    )
SELECT v_ordre,
    '6. Détail commande',
    'UPDATE QTE',
    'T_CommandeDetail',
    'APRES',
    d."ID_ArticleFk",
    d."ID_CmdFk",
    d."CodeCmd",
    d."AbrTypeCmd",
    d."StockActuel",
    d."QteCmdDetail",
    d."PUCmdDetail",
    c."MontantHT",
    c."MontantDetails",
    c."NbLignes",
    COALESCE(m.nb_mouvements, 0),
    COALESCE(m.qte_mvt_signed, 0),
    COALESCE(m.dernier_pumvt, 0),
    'Après quantité 5 -> 7 : stock +2 net, mouvement remplacé en qte=7.'
FROM logistique."V_CommandeDetail" d
    JOIN logistique."V_Commande" c ON c."ID_Commande" = d."ID_CmdFk"
    LEFT JOIN LATERAL (
        SELECT COUNT(*)::integer AS nb_mouvements,
            COALESCE(SUM(v."QteMvtSigned"), 0)::numeric AS qte_mvt_signed,
            MAX(v."PUMvt")::numeric(12, 2) AS dernier_pumvt
        FROM logistique."V_MouvementStock" v
        WHERE v."ID_ArticleFk" = d."ID_ArticleFk"
            AND v."ID_cmdFk" = d."ID_CmdFk"
    ) m ON true
WHERE d."ID_CmdFk" = v_id_cmd_entree
    AND d."ID_ArticleFk" = v_id_article;
SELECT "QteArticle" INTO v_stock
FROM logistique."T_Article"
WHERE "ID_Article" = v_id_article;
IF v_stock <> 32 THEN RAISE EXCEPTION 'Echec 6A : update qte entree 5 -> 7 devait porter stock a 32, obtenu=%.',
v_stock;
END IF;
/* ========================================================================
 7. UPDATE T_COMMANDE : TYPE ENTREE -> SORTIE
 ======================================================================== */
RAISE NOTICE '=== 7. UPDATE T_Commande type Entrée -> Sortie ===';
v_ordre := v_ordre + 1;
INSERT INTO tmp_logistique_evolution (
        ordre,
        phase,
        operation,
        table_cible,
        moment,
        id_article,
        id_commande,
        code_cmd,
        type_cmd,
        qte_article,
        qte_cmd_detail,
        pu_cmd_detail,
        montant_ht,
        montant_details,
        nb_lignes,
        nb_mouvements,
        qte_mvt_signed,
        dernier_pumvt,
        commentaire
    )
SELECT v_ordre,
    '7. Commande',
    'UPDATE TYPE',
    'T_Commande',
    'AVANT',
    d."ID_ArticleFk",
    d."ID_CmdFk",
    d."CodeCmd",
    d."AbrTypeCmd",
    d."StockActuel",
    d."QteCmdDetail",
    d."PUCmdDetail",
    c."MontantHT",
    c."MontantDetails",
    c."NbLignes",
    COALESCE(m.nb_mouvements, 0),
    COALESCE(m.qte_mvt_signed, 0),
    COALESCE(m.dernier_pumvt, 0),
    'Avant changement type commande : mouvement encore Entrée.'
FROM logistique."V_CommandeDetail" d
    JOIN logistique."V_Commande" c ON c."ID_Commande" = d."ID_CmdFk"
    LEFT JOIN LATERAL (
        SELECT COUNT(*)::integer AS nb_mouvements,
            COALESCE(SUM(v."QteMvtSigned"), 0)::numeric AS qte_mvt_signed,
            MAX(v."PUMvt")::numeric(12, 2) AS dernier_pumvt
        FROM logistique."V_MouvementStock" v
        WHERE v."ID_ArticleFk" = d."ID_ArticleFk"
            AND v."ID_cmdFk" = d."ID_CmdFk"
    ) m ON true
WHERE d."ID_CmdFk" = v_id_cmd_entree
    AND d."ID_ArticleFk" = v_id_article;
UPDATE logistique."T_Commande"
SET "ID_TypeCmdFk" = v_type_sortie
WHERE "ID_Commande" = v_id_cmd_entree;
v_ordre := v_ordre + 1;
INSERT INTO tmp_logistique_evolution (
        ordre,
        phase,
        operation,
        table_cible,
        moment,
        id_article,
        id_commande,
        code_cmd,
        type_cmd,
        qte_article,
        qte_cmd_detail,
        pu_cmd_detail,
        montant_ht,
        montant_details,
        nb_lignes,
        nb_mouvements,
        qte_mvt_signed,
        dernier_pumvt,
        commentaire
    )
SELECT v_ordre,
    '7. Commande',
    'UPDATE TYPE',
    'T_Commande',
    'APRES',
    d."ID_ArticleFk",
    d."ID_CmdFk",
    d."CodeCmd",
    d."AbrTypeCmd",
    d."StockActuel",
    d."QteCmdDetail",
    d."PUCmdDetail",
    c."MontantHT",
    c."MontantDetails",
    c."NbLignes",
    COALESCE(m.nb_mouvements, 0),
    COALESCE(m.qte_mvt_signed, 0),
    COALESCE(m.dernier_pumvt, 0),
    'Après Entrée -> Sortie : ancien effet annulé puis nouveau type appliqué ; mouvement signé -7.'
FROM logistique."V_CommandeDetail" d
    JOIN logistique."V_Commande" c ON c."ID_Commande" = d."ID_CmdFk"
    LEFT JOIN LATERAL (
        SELECT COUNT(*)::integer AS nb_mouvements,
            COALESCE(SUM(v."QteMvtSigned"), 0)::numeric AS qte_mvt_signed,
            MAX(v."PUMvt")::numeric(12, 2) AS dernier_pumvt
        FROM logistique."V_MouvementStock" v
        WHERE v."ID_ArticleFk" = d."ID_ArticleFk"
            AND v."ID_cmdFk" = d."ID_CmdFk"
    ) m ON true
WHERE d."ID_CmdFk" = v_id_cmd_entree
    AND d."ID_ArticleFk" = v_id_article;
SELECT "QteArticle" INTO v_stock
FROM logistique."T_Article"
WHERE "ID_Article" = v_id_article;
IF v_stock <> 18 THEN RAISE EXCEPTION 'Echec 7A : Entree -> Sortie devait porter le stock a 18, obtenu=%.',
v_stock;
END IF;
/* ========================================================================
 8. UPDATE T_COMMANDE : TYPE SORTIE -> ENTREE
 ======================================================================== */
RAISE NOTICE '=== 8. UPDATE T_Commande type Sortie -> Entrée ===';
UPDATE logistique."T_Commande"
SET "ID_TypeCmdFk" = v_type_entree
WHERE "ID_Commande" = v_id_cmd_entree;
v_ordre := v_ordre + 1;
INSERT INTO tmp_logistique_evolution (
        ordre,
        phase,
        operation,
        table_cible,
        moment,
        id_article,
        id_commande,
        code_cmd,
        type_cmd,
        qte_article,
        qte_cmd_detail,
        pu_cmd_detail,
        montant_ht,
        montant_details,
        nb_lignes,
        nb_mouvements,
        qte_mvt_signed,
        dernier_pumvt,
        commentaire
    )
SELECT v_ordre,
    '8. Commande',
    'UPDATE TYPE',
    'T_Commande',
    'APRES',
    d."ID_ArticleFk",
    d."ID_CmdFk",
    d."CodeCmd",
    d."AbrTypeCmd",
    d."StockActuel",
    d."QteCmdDetail",
    d."PUCmdDetail",
    c."MontantHT",
    c."MontantDetails",
    c."NbLignes",
    COALESCE(m.nb_mouvements, 0),
    COALESCE(m.qte_mvt_signed, 0),
    COALESCE(m.dernier_pumvt, 0),
    'Après Sortie -> Entrée : stock revient à 32, mouvement signé +7.'
FROM logistique."V_CommandeDetail" d
    JOIN logistique."V_Commande" c ON c."ID_Commande" = d."ID_CmdFk"
    LEFT JOIN LATERAL (
        SELECT COUNT(*)::integer AS nb_mouvements,
            COALESCE(SUM(v."QteMvtSigned"), 0)::numeric AS qte_mvt_signed,
            MAX(v."PUMvt")::numeric(12, 2) AS dernier_pumvt
        FROM logistique."V_MouvementStock" v
        WHERE v."ID_ArticleFk" = d."ID_ArticleFk"
            AND v."ID_cmdFk" = d."ID_CmdFk"
    ) m ON true
WHERE d."ID_CmdFk" = v_id_cmd_entree
    AND d."ID_ArticleFk" = v_id_article;
SELECT "QteArticle" INTO v_stock
FROM logistique."T_Article"
WHERE "ID_Article" = v_id_article;
IF v_stock <> 32 THEN RAISE EXCEPTION 'Echec 8A : Sortie -> Entree devait ramener le stock a 32, obtenu=%.',
v_stock;
END IF;
/* ========================================================================
 9. INSERT / UPDATE / DELETE T_COMMANDEDETAIL SORTIE
 ======================================================================== */
RAISE NOTICE '=== 9. INSERT/UPDATE/DELETE T_CommandeDetail sortie ===';
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
        'Commande sortie test evolution',
        FALSE
    )
RETURNING "ID_Commande" INTO v_id_cmd_sortie;
v_ordre := v_ordre + 1;
INSERT INTO tmp_logistique_evolution (
        ordre,
        phase,
        operation,
        table_cible,
        moment,
        id_article,
        id_commande,
        code_cmd,
        type_cmd,
        qte_article,
        montant_ht,
        montant_details,
        nb_lignes,
        commentaire
    )
SELECT v_ordre,
    '9. Commande sortie',
    'INSERT',
    'T_Commande',
    'APRES',
    v_id_article,
    c."ID_Commande",
    c."CodeCmd",
    c."AbrTypeCmd",
    a."QteArticle",
    c."MontantHT",
    c."MontantDetails",
    c."NbLignes",
    'Création commande sortie sans détail : aucun impact stock.'
FROM logistique."V_Commande" c
    CROSS JOIN logistique."V_Article" a
WHERE c."ID_Commande" = v_id_cmd_sortie
    AND a."ID_Article" = v_id_article;
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
        333.00,
        'Detail sortie test evolution',
        FALSE,
        FALSE
    );
v_ordre := v_ordre + 1;
INSERT INTO tmp_logistique_evolution (
        ordre,
        phase,
        operation,
        table_cible,
        moment,
        id_article,
        id_commande,
        code_cmd,
        type_cmd,
        qte_article,
        qte_cmd_detail,
        pu_cmd_detail,
        montant_ht,
        montant_details,
        nb_lignes,
        nb_mouvements,
        qte_mvt_signed,
        dernier_pumvt,
        commentaire
    )
SELECT v_ordre,
    '9. Détail sortie',
    'INSERT',
    'T_CommandeDetail',
    'APRES',
    d."ID_ArticleFk",
    d."ID_CmdFk",
    d."CodeCmd",
    d."AbrTypeCmd",
    d."StockActuel",
    d."QteCmdDetail",
    d."PUCmdDetail",
    c."MontantHT",
    c."MontantDetails",
    c."NbLignes",
    COALESCE(m.nb_mouvements, 0),
    COALESCE(m.qte_mvt_signed, 0),
    COALESCE(m.dernier_pumvt, 0),
    'Après ajout détail sortie : stock -4, mouvement signé -4.'
FROM logistique."V_CommandeDetail" d
    JOIN logistique."V_Commande" c ON c."ID_Commande" = d."ID_CmdFk"
    LEFT JOIN LATERAL (
        SELECT COUNT(*)::integer AS nb_mouvements,
            COALESCE(SUM(v."QteMvtSigned"), 0)::numeric AS qte_mvt_signed,
            MAX(v."PUMvt")::numeric(12, 2) AS dernier_pumvt
        FROM logistique."V_MouvementStock" v
        WHERE v."ID_ArticleFk" = d."ID_ArticleFk"
            AND v."ID_cmdFk" = d."ID_CmdFk"
    ) m ON true
WHERE d."ID_CmdFk" = v_id_cmd_sortie
    AND d."ID_ArticleFk" = v_id_article;
SELECT "QteArticle" INTO v_stock
FROM logistique."T_Article"
WHERE "ID_Article" = v_id_article;
IF v_stock <> 28 THEN RAISE EXCEPTION 'Echec 9A : sortie de 4 devait porter stock a 28, obtenu=%.',
v_stock;
END IF;
UPDATE logistique."T_CommandeDetail"
SET "QteCmdDetail" = 6
WHERE "ID_CmdFk" = v_id_cmd_sortie
    AND "ID_ArticleFk" = v_id_article;
v_ordre := v_ordre + 1;
INSERT INTO tmp_logistique_evolution (
        ordre,
        phase,
        operation,
        table_cible,
        moment,
        id_article,
        id_commande,
        code_cmd,
        type_cmd,
        qte_article,
        qte_cmd_detail,
        pu_cmd_detail,
        montant_ht,
        montant_details,
        nb_lignes,
        nb_mouvements,
        qte_mvt_signed,
        dernier_pumvt,
        commentaire
    )
SELECT v_ordre,
    '9. Détail sortie',
    'UPDATE QTE',
    'T_CommandeDetail',
    'APRES',
    d."ID_ArticleFk",
    d."ID_CmdFk",
    d."CodeCmd",
    d."AbrTypeCmd",
    d."StockActuel",
    d."QteCmdDetail",
    d."PUCmdDetail",
    c."MontantHT",
    c."MontantDetails",
    c."NbLignes",
    COALESCE(m.nb_mouvements, 0),
    COALESCE(m.qte_mvt_signed, 0),
    COALESCE(m.dernier_pumvt, 0),
    'Après sortie 4 -> 6 : stock -2 net, mouvement remplacé en qte=6.'
FROM logistique."V_CommandeDetail" d
    JOIN logistique."V_Commande" c ON c."ID_Commande" = d."ID_CmdFk"
    LEFT JOIN LATERAL (
        SELECT COUNT(*)::integer AS nb_mouvements,
            COALESCE(SUM(v."QteMvtSigned"), 0)::numeric AS qte_mvt_signed,
            MAX(v."PUMvt")::numeric(12, 2) AS dernier_pumvt
        FROM logistique."V_MouvementStock" v
        WHERE v."ID_ArticleFk" = d."ID_ArticleFk"
            AND v."ID_cmdFk" = d."ID_CmdFk"
    ) m ON true
WHERE d."ID_CmdFk" = v_id_cmd_sortie
    AND d."ID_ArticleFk" = v_id_article;
SELECT "QteArticle" INTO v_stock
FROM logistique."T_Article"
WHERE "ID_Article" = v_id_article;
IF v_stock <> 26 THEN RAISE EXCEPTION 'Echec 9B : update sortie 4 -> 6 devait porter stock a 26, obtenu=%.',
v_stock;
END IF;
v_ordre := v_ordre + 1;
INSERT INTO tmp_logistique_evolution (
        ordre,
        phase,
        operation,
        table_cible,
        moment,
        id_article,
        id_commande,
        code_cmd,
        type_cmd,
        qte_article,
        qte_cmd_detail,
        pu_cmd_detail,
        montant_ht,
        montant_details,
        nb_lignes,
        nb_mouvements,
        qte_mvt_signed,
        dernier_pumvt,
        commentaire
    )
SELECT v_ordre,
    '9. Détail sortie',
    'DELETE',
    'T_CommandeDetail',
    'AVANT',
    d."ID_ArticleFk",
    d."ID_CmdFk",
    d."CodeCmd",
    d."AbrTypeCmd",
    d."StockActuel",
    d."QteCmdDetail",
    d."PUCmdDetail",
    c."MontantHT",
    c."MontantDetails",
    c."NbLignes",
    COALESCE(m.nb_mouvements, 0),
    COALESCE(m.qte_mvt_signed, 0),
    COALESCE(m.dernier_pumvt, 0),
    'Avant suppression détail sortie.'
FROM logistique."V_CommandeDetail" d
    JOIN logistique."V_Commande" c ON c."ID_Commande" = d."ID_CmdFk"
    LEFT JOIN LATERAL (
        SELECT COUNT(*)::integer AS nb_mouvements,
            COALESCE(SUM(v."QteMvtSigned"), 0)::numeric AS qte_mvt_signed,
            MAX(v."PUMvt")::numeric(12, 2) AS dernier_pumvt
        FROM logistique."V_MouvementStock" v
        WHERE v."ID_ArticleFk" = d."ID_ArticleFk"
            AND v."ID_cmdFk" = d."ID_CmdFk"
    ) m ON true
WHERE d."ID_CmdFk" = v_id_cmd_sortie
    AND d."ID_ArticleFk" = v_id_article;
DELETE FROM logistique."T_CommandeDetail"
WHERE "ID_CmdFk" = v_id_cmd_sortie
    AND "ID_ArticleFk" = v_id_article;
v_ordre := v_ordre + 1;
INSERT INTO tmp_logistique_evolution (
        ordre,
        phase,
        operation,
        table_cible,
        moment,
        id_article,
        id_commande,
        code_cmd,
        type_cmd,
        qte_article,
        montant_ht,
        montant_details,
        nb_lignes,
        nb_mouvements,
        qte_mvt_signed,
        commentaire
    )
SELECT v_ordre,
    '9. Détail sortie',
    'DELETE',
    'T_CommandeDetail',
    'APRES',
    v_id_article,
    c."ID_Commande",
    c."CodeCmd",
    c."AbrTypeCmd",
    a."QteArticle",
    c."MontantHT",
    c."MontantDetails",
    c."NbLignes",
    COALESCE(m.nb_mouvements, 0),
    COALESCE(m.qte_mvt_signed, 0),
    'Après suppression détail sortie : stock restitué +6, mouvement commande supprimé.'
FROM logistique."V_Commande" c
    CROSS JOIN logistique."V_Article" a
    LEFT JOIN LATERAL (
        SELECT COUNT(*)::integer AS nb_mouvements,
            COALESCE(SUM(v."QteMvtSigned"), 0)::numeric AS qte_mvt_signed
        FROM logistique."V_MouvementStock" v
        WHERE v."ID_ArticleFk" = a."ID_Article"
            AND v."ID_cmdFk" = c."ID_Commande"
    ) m ON true
WHERE c."ID_Commande" = v_id_cmd_sortie
    AND a."ID_Article" = v_id_article;
SELECT "QteArticle" INTO v_stock
FROM logistique."T_Article"
WHERE "ID_Article" = v_id_article;
IF v_stock <> 32 THEN RAISE EXCEPTION 'Echec 9C : suppression detail sortie devait restituer stock a 32, obtenu=%.',
v_stock;
END IF;
/* ========================================================================
 10. DELETE T_COMMANDE ENTREE
 Selon FK ON DELETE CASCADE : detail supprime, trigger detail annule stock.
 Stock 32 - 7 = 25
 ======================================================================== */
RAISE NOTICE '=== 10. DELETE T_Commande entrée ===';
v_ordre := v_ordre + 1;
INSERT INTO tmp_logistique_evolution (
        ordre,
        phase,
        operation,
        table_cible,
        moment,
        id_article,
        id_commande,
        code_cmd,
        type_cmd,
        qte_article,
        qte_cmd_detail,
        pu_cmd_detail,
        montant_ht,
        montant_details,
        nb_lignes,
        nb_mouvements,
        qte_mvt_signed,
        commentaire
    )
SELECT v_ordre,
    '10. Commande',
    'DELETE',
    'T_Commande',
    'AVANT',
    d."ID_ArticleFk",
    d."ID_CmdFk",
    d."CodeCmd",
    d."AbrTypeCmd",
    d."StockActuel",
    d."QteCmdDetail",
    d."PUCmdDetail",
    c."MontantHT",
    c."MontantDetails",
    c."NbLignes",
    COALESCE(m.nb_mouvements, 0),
    COALESCE(m.qte_mvt_signed, 0),
    'Avant suppression commande entrée : détail actif et mouvement présent.'
FROM logistique."V_CommandeDetail" d
    JOIN logistique."V_Commande" c ON c."ID_Commande" = d."ID_CmdFk"
    LEFT JOIN LATERAL (
        SELECT COUNT(*)::integer AS nb_mouvements,
            COALESCE(SUM(v."QteMvtSigned"), 0)::numeric AS qte_mvt_signed
        FROM logistique."V_MouvementStock" v
        WHERE v."ID_ArticleFk" = d."ID_ArticleFk"
            AND v."ID_cmdFk" = d."ID_CmdFk"
    ) m ON true
WHERE d."ID_CmdFk" = v_id_cmd_entree
    AND d."ID_ArticleFk" = v_id_article;
DELETE FROM logistique."T_Commande"
WHERE "ID_Commande" = v_id_cmd_entree;
v_ordre := v_ordre + 1;
INSERT INTO tmp_logistique_evolution (
        ordre,
        phase,
        operation,
        table_cible,
        moment,
        id_article,
        id_commande,
        qte_article,
        nb_mouvements,
        qte_mvt_signed,
        commentaire
    )
SELECT v_ordre,
    '10. Commande',
    'DELETE',
    'T_Commande',
    'APRES',
    a."ID_Article",
    v_id_cmd_entree,
    a."QteArticle",
    COALESCE(m.nb_mouvements, 0),
    COALESCE(m.qte_mvt_signed, 0),
    'Après suppression commande entrée : stock -7, détail et mouvement de commande supprimés.'
FROM logistique."V_Article" a
    LEFT JOIN LATERAL (
        SELECT COUNT(*)::integer AS nb_mouvements,
            COALESCE(SUM(v."QteMvtSigned"), 0)::numeric AS qte_mvt_signed
        FROM logistique."V_MouvementStock" v
        WHERE v."ID_ArticleFk" = a."ID_Article"
            AND v."ID_cmdFk" = v_id_cmd_entree
    ) m ON true
WHERE a."ID_Article" = v_id_article;
SELECT "QteArticle" INTO v_stock
FROM logistique."T_Article"
WHERE "ID_Article" = v_id_article;
IF v_stock <> 25 THEN RAISE EXCEPTION 'Echec 10A : suppression commande entree devait ramener stock a 25, obtenu=%.',
v_stock;
END IF;
/* ========================================================================
 11. TESTS DE BLOCAGE EXISTANTS
 ======================================================================== */
RAISE NOTICE '=== 11. Blocage stock insuffisant ===';
SELECT "QteArticle" INTO v_stock_before
FROM logistique."T_Article"
WHERE "ID_Article" = v_id_article;
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
        v_code_cmd_fail,
        'Commande sortie impossible test evolution',
        FALSE
    )
RETURNING "ID_Commande" INTO v_id_cmd_fail;
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
        v_id_cmd_fail,
        v_id_article,
        100000,
        100,
        'Sortie impossible',
        FALSE,
        FALSE
    );
RAISE EXCEPTION 'Echec 11A : une sortie qui rend le stock negatif aurait du etre bloquee.';
EXCEPTION
WHEN OTHERS THEN RAISE NOTICE 'Blocage attendu stock insuffisant : %',
SQLERRM;
END;
SELECT "QteArticle" INTO v_stock
FROM logistique."T_Article"
WHERE "ID_Article" = v_id_article;
IF v_stock <> v_stock_before THEN RAISE EXCEPTION 'Echec 11B : apres blocage stock insuffisant, stock devait rester %. Obtenu=%.',
v_stock_before,
v_stock;
END IF;
RAISE NOTICE '=== 12. Blocage doublon article dans meme commande ===';
SELECT "QteArticle" INTO v_stock_before
FROM logistique."T_Article"
WHERE "ID_Article" = v_id_article;
BEGIN
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
        1,
        10,
        'Doublon interdit',
        FALSE,
        FALSE
    );
-- Si la commande sortie n'a plus de détail, le doublon ne s'appliquera pas.
-- On supprime immédiatement cette ligne pour ne pas perturber le scénario.
DELETE FROM logistique."T_CommandeDetail"
WHERE "ID_CmdFk" = v_id_cmd_sortie
    AND "ID_ArticleFk" = v_id_article;
RAISE NOTICE 'Info : la commande sortie n’avait plus de détail actif, le test doublon strict est ignoré ici.';
EXCEPTION
WHEN unique_violation THEN RAISE NOTICE 'Blocage attendu doublon article/commande : %',
SQLERRM;
WHEN OTHERS THEN RAISE NOTICE 'Blocage recu pour doublon article/commande : %',
SQLERRM;
END;
RAISE NOTICE '=== 13. Blocage quantite fractionnaire ===';
SELECT "QteArticle" INTO v_stock_before
FROM logistique."T_Article"
WHERE "ID_Article" = v_id_article;
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
        v_type_entree,
        now(),
        now(),
        v_code_cmd_fraction,
        'Commande fractionnaire impossible test evolution',
        FALSE
    )
RETURNING "ID_Commande" INTO v_id_cmd_fraction;
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
        v_id_cmd_fraction,
        v_id_article,
        1.5,
        10,
        'Quantite fractionnaire interdite',
        FALSE,
        FALSE
    );
RAISE EXCEPTION 'Echec 13A : une quantite fractionnaire aurait du etre bloquee.';
EXCEPTION
WHEN OTHERS THEN RAISE NOTICE 'Blocage attendu quantite fractionnaire : %',
SQLERRM;
END;
SELECT "QteArticle" INTO v_stock
FROM logistique."T_Article"
WHERE "ID_Article" = v_id_article;
IF v_stock <> v_stock_before THEN RAISE EXCEPTION 'Echec 13B : quantite fractionnaire bloquee ne devait pas modifier le stock. Attendu=%, obtenu=%.',
v_stock_before,
v_stock;
END IF;
RAISE NOTICE '=== 14. Blocage ecriture directe sur T_Mouvement ===';
BEGIN
INSERT INTO logistique."T_Mouvement" (
        "ID_TypeMvtFk",
        "ID_ArticleFk",
        "ID_cmdFk",
        "DateHeureAutoMvt",
        "DateMvt",
        "QteMvt",
        "PUMvt"
    )
VALUES (
        v_type_entree,
        v_id_article,
        NULL,
        now(),
        now(),
        1,
        1
    );
RAISE EXCEPTION 'Echec 14A : insertion directe dans T_Mouvement aurait du etre bloquee.';
EXCEPTION
WHEN OTHERS THEN RAISE NOTICE 'Blocage attendu ecriture directe T_Mouvement : %',
SQLERRM;
END;
/* ========================================================================
 12. AUDIT FINAL
 A ce stade :
 - mouvements directs : +20 +5 = 25
 - commande entree supprimee
 - detail sortie supprime
 - stock attendu = 25
 - audit attendu : ecart = 0
 ======================================================================== */
RAISE NOTICE '=== 15. Audit stock final ===';
SELECT "Ecart" INTO v_ecart
FROM logistique."V_AuditStock"
WHERE "ID_Article" = v_id_article;
IF COALESCE(v_ecart, 999999) <> 0 THEN RAISE EXCEPTION 'Echec 15A : V_AuditStock devait retourner Ecart=0 pour article %, obtenu=%.',
v_id_article,
v_ecart;
END IF;
v_ordre := v_ordre + 1;
INSERT INTO tmp_logistique_evolution (
        ordre,
        phase,
        operation,
        table_cible,
        moment,
        id_article,
        qte_article,
        nb_mouvements,
        qte_mvt_signed,
        commentaire
    )
SELECT v_ordre,
    '15. Audit',
    'SELECT',
    'V_AuditStock',
    'FINAL',
    a."ID_Article",
    a."QteArticle",
    COALESCE(m.nb_mouvements, 0),
    COALESCE(m.qte_mvt_signed, 0),
    'Audit final : stock courant = mouvements signés ; écart attendu = 0.'
FROM logistique."V_Article" a
    LEFT JOIN LATERAL (
        SELECT COUNT(*)::integer AS nb_mouvements,
            COALESCE(SUM(v."QteMvtSigned"), 0)::numeric AS qte_mvt_signed
        FROM logistique."V_MouvementStock" v
        WHERE v."ID_ArticleFk" = a."ID_Article"
    ) m ON true
WHERE a."ID_Article" = v_id_article;
RAISE NOTICE '=== TEST METIER LOGISTIQUE AVEC EVOLUTION TERMINE AVEC SUCCES ===';
RAISE NOTICE 'Consulte le SELECT tmp_logistique_evolution avant le ROLLBACK.';
END $$;
-------------------------------------------------------------------------------
-- RESULTAT VISUEL 1 : EVOLUTION DES VALEURS
-------------------------------------------------------------------------------
SELECT ordre,
    phase,
    operation,
    table_cible,
    moment,
    id_article,
    id_commande,
    code_cmd,
    type_cmd,
    qte_article,
    qte_cmd_detail,
    pu_cmd_detail,
    montant_ht,
    montant_details,
    nb_lignes,
    nb_mouvements,
    qte_mvt_signed,
    dernier_pumvt,
    commentaire
FROM tmp_logistique_evolution
ORDER BY ordre;
-------------------------------------------------------------------------------
-- RESULTAT VISUEL 2 : MOUVEMENTS DETAILLES DE L'ARTICLE TEST
-------------------------------------------------------------------------------
SELECT v."ID_Mvt",
    v."ID_ArticleFk",
    v."NomArticle",
    v."ID_cmdFk",
    v."CodeCmd",
    v."AbrTypeMvt",
    v."SigneStock",
    v."QteMvt",
    v."QteMvtSigned",
    v."PUMvt",
    v."MontantMvt",
    v."MontantMvtSigned",
    v."OrigineMouvement"
FROM logistique."V_MouvementStock" v
WHERE v."ID_ArticleFk" IN (
        SELECT DISTINCT id_article
        FROM tmp_logistique_evolution
        WHERE id_article IS NOT NULL
    )
ORDER BY v."ID_Mvt";
-------------------------------------------------------------------------------
-- RESULTAT VISUEL 3 : AUDIT FINAL DE L'ARTICLE TEST
-------------------------------------------------------------------------------
SELECT a.*
FROM logistique."V_AuditStock" a
WHERE a."ID_Article" IN (
        SELECT DISTINCT id_article
        FROM tmp_logistique_evolution
        WHERE id_article IS NOT NULL
    )
ORDER BY a."ID_Article";
ROLLBACK;