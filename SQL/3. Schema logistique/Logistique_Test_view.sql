/* ============================================================================
 TEST AMELIORE DES VUES LOGISTIQUES - SAUVERNDEKO
 
 Objectif :
 Tester les vues logistiques ameliorees sans polluer la base.
 
 Vues testees :
 - logistique."V_Article"
 - logistique."V_Commande"
 - logistique."V_CommandeDetail"
 - logistique."V_Mouvement"
 - logistique."V_MouvementStock"
 - logistique."V_AuditStock"
 - logistique."V_AuditStock_Theorique"
 - logistique."V_AlertStock"
 - logistique."V_ConsoMensuelle"
 - logistique."V_CouvertureStock"
 - logistique."V_CommandesSansDetails"
 - logistique."V_SuiviReglements"
 
 Principes :
 - aucun ID fixe n'est suppose ;
 - les types Entree / Sortie sont recherches dynamiquement dans referentiel.T_Generique ;
 - le mode de reglement est recherche dynamiquement dans referentiel.T_Generique ;
 - les donnees de test sont creees dans une transaction ;
 - les controles visuels sont executes avant le ROLLBACK ;
 - le script se termine par ROLLBACK pour ne pas polluer la base.
 
 Prerequis :
 - triggers metier logistique deja installes ;
 - vues logistiques ameliorees deja installees ;
 - categorie 64 = types Entree / Sortie ;
 - categorie 36 = modes de paiement / reglement.
 ============================================================================ */
BEGIN;
CREATE TEMP TABLE tmp_logistique_vue_test_refs (
    objet text,
    id_article integer,
    id_commande integer,
    code_article text,
    code_cmd text,
    code_facture text
) ON COMMIT DROP;
DO $$
DECLARE v_id_type_entree integer;
v_id_type_sortie integer;
v_id_mode_reglement integer;
v_categorie_type_commande integer := 64;
v_categorie_mode_paiement integer := 36;
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
v_montant numeric;
v_count integer;
v_bool boolean;
v_text text;
BEGIN RAISE NOTICE '============================================================';
RAISE NOTICE 'DEBUT TEST AMELIORE DES VUES LOGISTIQUES';
RAISE NOTICE '============================================================';
/* ========================================================================
 0. REFERENTIELS DYNAMIQUES
 ======================================================================== */
SELECT g."ID_Generique" INTO v_id_type_entree
FROM referentiel."T_Generique" g
WHERE g."ID_CategorieGeneriqueFk" = v_categorie_type_commande
    AND g."AbrGenerique" ILIKE 'entr%'
ORDER BY g."ID_Generique"
LIMIT 1;
SELECT g."ID_Generique" INTO v_id_type_sortie
FROM referentiel."T_Generique" g
WHERE g."ID_CategorieGeneriqueFk" = v_categorie_type_commande
    AND g."AbrGenerique" ILIKE 'sort%'
ORDER BY g."ID_Generique"
LIMIT 1;
IF v_id_type_entree IS NULL
OR v_id_type_sortie IS NULL THEN RAISE EXCEPTION 'Types Entree / Sortie introuvables dans referentiel.T_Generique pour la categorie %.',
v_categorie_type_commande;
END IF;
SELECT g."ID_Generique" INTO v_id_mode_reglement
FROM referentiel."T_Generique" g
WHERE g."ID_CategorieGeneriqueFk" = v_categorie_mode_paiement
ORDER BY g."ID_Generique"
LIMIT 1;
IF v_id_mode_reglement IS NULL THEN RAISE EXCEPTION 'Mode de reglement introuvable dans referentiel.T_Generique pour la categorie %.',
v_categorie_mode_paiement;
END IF;
RAISE NOTICE 'OK - Type Entree=% ; Type Sortie=% ; Mode reglement=%',
v_id_type_entree,
v_id_type_sortie,
v_id_mode_reglement;
/* ========================================================================
 1. CODES UNIQUES
 ======================================================================== */
v_suffix := to_char(clock_timestamp(), 'YYYYMMDDHH24MISSMS') || lpad((floor(random() * 1000))::int::text, 3, '0');
v_code_article_1 := 'VIEW-ART-001-' || right(v_suffix, 12);
v_code_article_2 := 'VIEW-ART-002-' || right(v_suffix, 12);
v_code_article_alerte := 'VIEW-ART-ALT-' || right(v_suffix, 12);
v_code_cmd_entree := 'VIEW-E-' || right(v_suffix, 10);
v_code_cmd_sortie := 'VIEW-S-' || right(v_suffix, 10);
v_code_cmd_sans_detail := 'VIEW-SD-' || right(v_suffix, 9);
v_code_facture := 'VIEW-FAC-' || right(v_suffix, 10);
/* ========================================================================
 2. CREATION ARTICLES
 Les articles sont crees avec QteArticle = 0 puis ajustes par UPDATE.
 Cela teste aussi les mouvements directs generes par les triggers article.
 ======================================================================== */
RAISE NOTICE '=== 1. Creation articles ===';
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
        'Gants medicaux - test vues ameliore',
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
        'Masques chirurgicaux - test vues ameliore',
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
        'Gel hydroalcoolique - alerte stock test vues',
        'VIEW-REF-ALERTE-001',
        0,
        3.00,
        5.00,
        15,
        'Article volontairement en alerte stock et alerte peremption',
        TRUE,
        now() + interval '20 days',
        now() + interval '10 days',
        30,
        v_code_article_alerte
    )
RETURNING "ID_Article" INTO v_id_article_alerte;
UPDATE logistique."T_Article"
SET "QteArticle" = 100
WHERE "ID_Article" = v_id_article_1;
UPDATE logistique."T_Article"
SET "QteArticle" = 200
WHERE "ID_Article" = v_id_article_2;
UPDATE logistique."T_Article"
SET "QteArticle" = 5
WHERE "ID_Article" = v_id_article_alerte;
RAISE NOTICE 'OK - Articles crees : %, %, %',
v_id_article_1,
v_id_article_2,
v_id_article_alerte;
/* ========================================================================
 3. COMMANDE ENTREE
 Article 1 : +50
 Article 2 : +100
 ======================================================================== */
RAISE NOTICE '=== 2. Creation commande entree ===';
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
VALUES (
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
/* ========================================================================
 4. COMMANDE SORTIE + FACTURE + REGLEMENT
 Article 1 : -20
 Article 2 : -40
 Montant details sortie = 20*2 + 40*1 = 80
 Reglement partiel = 30
 Reste attendu = 50
 ======================================================================== */
RAISE NOTICE '=== 3. Creation commande sortie facturee et reglement partiel ===';
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
        "StatusFacture",
        "DateEcheancePaiement"
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
        'Non reglee',
        now() + interval '15 days'
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
VALUES (
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
INSERT INTO logistique."T_Reglements" (
        "CodeFactureFk",
        "ID_ModeReglementFk",
        "ID_ClientFk",
        "DateReglement",
        "MontantRegle"
    )
VALUES (
        v_code_facture,
        v_id_mode_reglement,
        NULL,
        now(),
        30
    );
/* ========================================================================
 5. COMMANDE SANS DETAIL
 ======================================================================== */
RAISE NOTICE '=== 4. Creation commande sans detail ===';
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
/* ========================================================================
 6. REFERENCES TEMPORAIRES
 ======================================================================== */
INSERT INTO tmp_logistique_vue_test_refs (
        objet,
        id_article,
        id_commande,
        code_article,
        code_cmd,
        code_facture
    )
VALUES (
        'ARTICLE_1',
        v_id_article_1,
        NULL,
        v_code_article_1,
        NULL,
        NULL
    ),
    (
        'ARTICLE_2',
        v_id_article_2,
        NULL,
        v_code_article_2,
        NULL,
        NULL
    ),
    (
        'ARTICLE_ALERTE',
        v_id_article_alerte,
        NULL,
        v_code_article_alerte,
        NULL,
        NULL
    ),
    (
        'CMD_ENTREE',
        NULL,
        v_id_cmd_entree,
        NULL,
        v_code_cmd_entree,
        NULL
    ),
    (
        'CMD_SORTIE',
        NULL,
        v_id_cmd_sortie,
        NULL,
        v_code_cmd_sortie,
        v_code_facture
    ),
    (
        'CMD_SANS_DETAIL',
        NULL,
        v_id_cmd_sans_detail,
        NULL,
        v_code_cmd_sans_detail,
        NULL
    );
/* ========================================================================
 7. CONTROLES STOCK ATTENDUS
 Article 1 : 100 + 50 - 20 = 130
 Article 2 : 200 + 100 - 40 = 260
 Article alerte : 5
 ======================================================================== */
RAISE NOTICE '=== 5. Controle stocks attendus ===';
SELECT "QteArticle" INTO v_qte
FROM logistique."T_Article"
WHERE "ID_Article" = v_id_article_1;
IF v_qte <> 130 THEN RAISE EXCEPTION 'Stock article 1 attendu=130, obtenu=%',
v_qte;
END IF;
SELECT "QteArticle" INTO v_qte
FROM logistique."T_Article"
WHERE "ID_Article" = v_id_article_2;
IF v_qte <> 260 THEN RAISE EXCEPTION 'Stock article 2 attendu=260, obtenu=%',
v_qte;
END IF;
SELECT "QteArticle" INTO v_qte
FROM logistique."T_Article"
WHERE "ID_Article" = v_id_article_alerte;
IF v_qte <> 5 THEN RAISE EXCEPTION 'Stock article alerte attendu=5, obtenu=%',
v_qte;
END IF;
/* ========================================================================
 8. CONTROLE V_ARTICLE
 ======================================================================== */
RAISE NOTICE '=== 6. Controle V_Article ===';
SELECT COUNT(*)::int INTO v_count
FROM logistique."V_Article"
WHERE "ID_Article" IN (
        v_id_article_1,
        v_id_article_2,
        v_id_article_alerte
    );
IF v_count <> 3 THEN RAISE EXCEPTION 'V_Article : attendu=3 articles, obtenu=%',
v_count;
END IF;
SELECT "EtatStock" INTO v_text
FROM logistique."V_Article"
WHERE "ID_Article" = v_id_article_alerte;
IF v_text <> 'Stock faible' THEN RAISE EXCEPTION 'V_Article : article alerte attendu EtatStock=Stock faible, obtenu=%',
v_text;
END IF;
SELECT "EstAlertePeremption" INTO v_bool
FROM logistique."V_Article"
WHERE "ID_Article" = v_id_article_alerte;
IF v_bool IS DISTINCT
FROM true THEN RAISE EXCEPTION 'V_Article : article alerte attendu EstAlertePeremption=true, obtenu=%',
    v_bool;
END IF;
/* ========================================================================
 9. CONTROLE V_COMMANDE
 ======================================================================== */
RAISE NOTICE '=== 7. Controle V_Commande ===';
SELECT COUNT(*)::int INTO v_count
FROM logistique."V_Commande"
WHERE "ID_Commande" IN (
        v_id_cmd_entree,
        v_id_cmd_sortie,
        v_id_cmd_sans_detail
    );
IF v_count <> 3 THEN RAISE EXCEPTION 'V_Commande : attendu=3 commandes, obtenu=%',
v_count;
END IF;
SELECT "NbLignes",
    "QteTotale",
    "MontantDetails",
    "MontantHT",
    "EstMontantIncoherent" INTO v_count,
    v_qte,
    v_montant,
    v_montant,
    v_bool
FROM logistique."V_Commande"
WHERE "ID_Commande" = v_id_cmd_sortie;
IF v_count <> 2 THEN RAISE EXCEPTION 'V_Commande sortie : NbLignes attendu=2, obtenu=%',
v_count;
END IF;
IF v_qte <> 60 THEN RAISE EXCEPTION 'V_Commande sortie : QteTotale attendue=60, obtenue=%',
v_qte;
END IF;
SELECT "MontantDetails" INTO v_montant
FROM logistique."V_Commande"
WHERE "ID_Commande" = v_id_cmd_sortie;
IF v_montant <> 80 THEN RAISE EXCEPTION 'V_Commande sortie : MontantDetails attendu=80, obtenu=%',
v_montant;
END IF;
SELECT "EstMontantIncoherent" INTO v_bool
FROM logistique."V_Commande"
WHERE "ID_Commande" = v_id_cmd_sortie;
IF v_bool IS DISTINCT
FROM false THEN RAISE EXCEPTION 'V_Commande sortie : EstMontantIncoherent attendu=false, obtenu=%',
    v_bool;
END IF;
SELECT "EtatPaiement",
    "TotalRegleReel",
    "ResteReel" INTO v_text,
    v_montant,
    v_qte
FROM logistique."V_Commande"
WHERE "ID_Commande" = v_id_cmd_sortie;
IF v_text <> 'Partiellement réglée' THEN RAISE EXCEPTION 'V_Commande sortie : EtatPaiement attendu=Partiellement réglée, obtenu=%',
v_text;
END IF;
IF v_montant <> 30 THEN RAISE EXCEPTION 'V_Commande sortie : TotalRegleReel attendu=30, obtenu=%',
v_montant;
END IF;
IF v_qte <> 50 THEN RAISE EXCEPTION 'V_Commande sortie : ResteReel attendu=50, obtenu=%',
v_qte;
END IF;
/* ========================================================================
 10. CONTROLE V_COMMANDEDETAIL
 ======================================================================== */
RAISE NOTICE '=== 8. Controle V_CommandeDetail ===';
SELECT COUNT(*)::int INTO v_count
FROM logistique."V_CommandeDetail"
WHERE "ID_CmdFk" IN (v_id_cmd_entree, v_id_cmd_sortie);
IF v_count <> 4 THEN RAISE EXCEPTION 'V_CommandeDetail : attendu=4 lignes, obtenu=%',
v_count;
END IF;
SELECT "MontantLigne" INTO v_montant
FROM logistique."V_CommandeDetail"
WHERE "ID_CmdFk" = v_id_cmd_sortie
    AND "ID_ArticleFk" = v_id_article_1;
IF v_montant <> 40 THEN RAISE EXCEPTION 'V_CommandeDetail : MontantLigne attendu=40 pour article 1 sortie, obtenu=%',
v_montant;
END IF;
/* ========================================================================
 11. CONTROLE V_MOUVEMENTSTOCK
 ======================================================================== */
RAISE NOTICE '=== 9. Controle V_MouvementStock ===';
SELECT COUNT(*)::int INTO v_count
FROM logistique."V_MouvementStock"
WHERE "ID_ArticleFk" IN (
        v_id_article_1,
        v_id_article_2,
        v_id_article_alerte
    );
IF v_count < 7 THEN RAISE EXCEPTION 'V_MouvementStock : attendu au moins 7 mouvements test, obtenu=%',
v_count;
END IF;
SELECT "SigneStock",
    "QteMvtSigned",
    "MontantMvt" INTO v_count,
    v_qte,
    v_montant
FROM logistique."V_MouvementStock"
WHERE "ID_ArticleFk" = v_id_article_1
    AND "ID_cmdFk" = v_id_cmd_sortie;
IF v_count <> -1
OR v_qte <> -20
OR v_montant <> 40 THEN RAISE EXCEPTION 'V_MouvementStock sortie article 1 : attendu signe=-1, qte=-20, montant=40. Obtenu signe=%, qte=%, montant=%',
v_count,
v_qte,
v_montant;
END IF;
/* ========================================================================
 12. CONTROLE V_MOUVEMENT
 ======================================================================== */
RAISE NOTICE '=== 10. Controle V_Mouvement ===';
SELECT COUNT(*)::int INTO v_count
FROM logistique."V_Mouvement"
WHERE "ID_ArticleFk" IN (
        v_id_article_1,
        v_id_article_2,
        v_id_article_alerte
    );
IF v_count < 7 THEN RAISE EXCEPTION 'V_Mouvement : attendu au moins 7 mouvements test, obtenu=%',
v_count;
END IF;
/* ========================================================================
 13. CONTROLE V_AUDITSTOCK / V_AUDITSTOCK_THEORIQUE
 ======================================================================== */
RAISE NOTICE '=== 11. Controle audit stock ===';
SELECT COUNT(*)::int INTO v_count
FROM logistique."V_AuditStock"
WHERE "ID_Article" IN (
        v_id_article_1,
        v_id_article_2,
        v_id_article_alerte
    )
    AND "Ecart" = 0;
IF v_count <> 3 THEN RAISE EXCEPTION 'V_AuditStock : attendu=3 lignes coherentes, obtenu=%',
v_count;
END IF;
SELECT COUNT(*)::int INTO v_count
FROM logistique."V_AuditStock_Theorique"
WHERE "ID_Article" IN (
        v_id_article_1,
        v_id_article_2,
        v_id_article_alerte
    )
    AND "Ecart" = 0
    AND "EstStockCoherent" = true;
IF v_count <> 3 THEN RAISE EXCEPTION 'V_AuditStock_Theorique : attendu=3 lignes coherentes, obtenu=%',
v_count;
END IF;
/* ========================================================================
 14. CONTROLE V_ALERTSTOCK
 ======================================================================== */
RAISE NOTICE '=== 12. Controle V_AlertStock ===';
SELECT COUNT(*)::int INTO v_count
FROM logistique."V_AlertStock"
WHERE "ID_Article" = v_id_article_alerte
    AND "EstAlerteStock" = true
    AND "QteACommander" = 10;
IF v_count <> 1 THEN RAISE EXCEPTION 'V_AlertStock : article alerte attendu avec QteACommander=10, obtenu=%',
v_count;
END IF;
/* ========================================================================
 15. CONTROLE V_COMMANDESSANSDETAILS
 ======================================================================== */
RAISE NOTICE '=== 13. Controle V_CommandesSansDetails ===';
SELECT COUNT(*)::int INTO v_count
FROM logistique."V_CommandesSansDetails"
WHERE "ID_Commande" = v_id_cmd_sans_detail;
IF v_count <> 1 THEN RAISE EXCEPTION 'V_CommandesSansDetails : commande sans detail attendue=1, obtenu=%',
v_count;
END IF;
/* ========================================================================
 16. CONTROLE V_CONSOMENSUELLE
 ======================================================================== */
RAISE NOTICE '=== 14. Controle V_ConsoMensuelle ===';
SELECT "ConsoMensuelle" INTO v_qte
FROM logistique."V_ConsoMensuelle"
WHERE "ID_Article" = v_id_article_1
    AND "Mois" = date_trunc('month', CURRENT_DATE)::date;
IF v_qte <> 20 THEN RAISE EXCEPTION 'V_ConsoMensuelle : article 1 conso attendue=20, obtenue=%',
v_qte;
END IF;
SELECT "ConsoMensuelle" INTO v_qte
FROM logistique."V_ConsoMensuelle"
WHERE "ID_Article" = v_id_article_2
    AND "Mois" = date_trunc('month', CURRENT_DATE)::date;
IF v_qte <> 40 THEN RAISE EXCEPTION 'V_ConsoMensuelle : article 2 conso attendue=40, obtenue=%',
v_qte;
END IF;
/* ========================================================================
 17. CONTROLE V_COUVERTURESTOCK
 ======================================================================== */
RAISE NOTICE '=== 15. Controle V_CouvertureStock ===';
SELECT "Conso6Mois" INTO v_qte
FROM logistique."V_CouvertureStock"
WHERE "ID_Article" = v_id_article_1;
IF v_qte <> 20 THEN RAISE EXCEPTION 'V_CouvertureStock : article 1 Conso6Mois attendue=20, obtenue=%',
v_qte;
END IF;
SELECT "EtatCouverture" INTO v_text
FROM logistique."V_CouvertureStock"
WHERE "ID_Article" = v_id_article_alerte;
IF v_text <> 'Aucune consommation récente' THEN RAISE EXCEPTION 'V_CouvertureStock : article alerte EtatCouverture attendu=Aucune consommation récente, obtenu=%',
v_text;
END IF;
/* ========================================================================
 18. CONTROLE V_SUIVIREGLEMENTS
 ======================================================================== */
RAISE NOTICE '=== 16. Controle V_SuiviReglements ===';
SELECT "TotalRegle",
    "Reste",
    "EtatReglement" INTO v_montant,
    v_qte,
    v_text
FROM logistique."V_SuiviReglements"
WHERE "CodeFacture" = v_code_facture;
IF v_montant <> 30 THEN RAISE EXCEPTION 'V_SuiviReglements : TotalRegle attendu=30, obtenu=%',
v_montant;
END IF;
IF v_qte <> 50 THEN RAISE EXCEPTION 'V_SuiviReglements : Reste attendu=50, obtenu=%',
v_qte;
END IF;
IF v_text <> 'Partiellement réglée' THEN RAISE EXCEPTION 'V_SuiviReglements : EtatReglement attendu=Partiellement réglée, obtenu=%',
v_text;
END IF;
RAISE NOTICE '============================================================';
RAISE NOTICE 'TEST AMELIORE DES VUES LOGISTIQUES TERMINE AVEC SUCCES';
RAISE NOTICE 'Articles test : %, %, %',
v_id_article_1,
v_id_article_2,
v_id_article_alerte;
RAISE NOTICE 'Commandes test : entree %, sortie %, sans detail %',
v_id_cmd_entree,
v_id_cmd_sortie,
v_id_cmd_sans_detail;
RAISE NOTICE 'ROLLBACK attendu apres les SELECT visuels.';
RAISE NOTICE '============================================================';
END $$;
-------------------------------------------------------------------------------
-- CONTROLES VISUELS AVANT ROLLBACK
-- Ces SELECT permettent de voir les lignes de test dans pgAdmin/DBeaver.
-- Les donnees seront ensuite annulees par le ROLLBACK final.
-------------------------------------------------------------------------------
-- 1. Articles depuis V_Article
SELECT v."ID_Article",
    v."CodeArticleInterne",
    v."NomArticle",
    v."QteArticle",
    v."QteMinArticle",
    v."QteACommander",
    v."EtatStock",
    v."EstAlerteStock",
    v."EtatPeremption",
    v."EstAlertePeremption",
    v."ValeurStockAchat",
    v."ValeurStockVente"
FROM logistique."V_Article" v
    JOIN tmp_logistique_vue_test_refs r ON r.id_article = v."ID_Article"
WHERE r.objet IN ('ARTICLE_1', 'ARTICLE_2', 'ARTICLE_ALERTE')
ORDER BY v."ID_Article";
-- 2. Commandes depuis V_Commande
SELECT v."ID_Commande",
    v."CodeCmd",
    v."AbrTypeCmd",
    v."TypeCmd",
    v."NbLignes",
    v."QteTotale",
    v."MontantHT",
    v."MontantDetails",
    v."TotalRegleReel",
    v."ResteReel",
    v."EtatPaiement",
    v."EtatControleCommande",
    v."EstCommandeSansDetails"
FROM logistique."V_Commande" v
    JOIN tmp_logistique_vue_test_refs r ON r.id_commande = v."ID_Commande"
WHERE r.objet IN ('CMD_ENTREE', 'CMD_SORTIE', 'CMD_SANS_DETAIL')
ORDER BY v."ID_Commande";
-- 3. Details des commandes
SELECT v."ID_CmdFk",
    v."CodeCmd",
    v."AbrTypeCmd",
    v."ID_ArticleFk",
    v."NomArticle",
    v."QteCmdDetail",
    v."PUCmdDetail",
    v."MontantLigne",
    v."StockActuel",
    v."StockAvantLigneTheorique",
    v."EtatLigne"
FROM logistique."V_CommandeDetail" v
    JOIN tmp_logistique_vue_test_refs r ON r.id_commande = v."ID_CmdFk"
WHERE r.objet IN ('CMD_ENTREE', 'CMD_SORTIE')
ORDER BY v."ID_CmdFk",
    v."ID_ArticleFk";
-- 4. Mouvements stock
SELECT v."ID_Mvt",
    v."NomArticle",
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
    JOIN tmp_logistique_vue_test_refs r ON r.id_article = v."ID_ArticleFk"
WHERE r.objet IN ('ARTICLE_1', 'ARTICLE_2', 'ARTICLE_ALERTE')
ORDER BY v."ID_ArticleFk",
    v."ID_cmdFk" NULLS FIRST,
    v."ID_Mvt";
-- 5. Audit stock
SELECT v.*
FROM logistique."V_AuditStock" v
    JOIN tmp_logistique_vue_test_refs r ON r.id_article = v."ID_Article"
WHERE r.objet IN ('ARTICLE_1', 'ARTICLE_2', 'ARTICLE_ALERTE')
ORDER BY v."ID_Article";
-- 6. Alertes stock
SELECT v.*
FROM logistique."V_AlertStock" v
    JOIN tmp_logistique_vue_test_refs r ON r.id_article = v."ID_Article"
WHERE r.objet IN ('ARTICLE_1', 'ARTICLE_2', 'ARTICLE_ALERTE')
ORDER BY v."PrioriteStock",
    v."NomArticle";
-- 7. Commandes sans details
SELECT v.*
FROM logistique."V_CommandesSansDetails" v
    JOIN tmp_logistique_vue_test_refs r ON r.id_commande = v."ID_Commande"
WHERE r.objet = 'CMD_SANS_DETAIL';
-- 8. Consommation mensuelle
SELECT v.*
FROM logistique."V_ConsoMensuelle" v
    JOIN tmp_logistique_vue_test_refs r ON r.id_article = v."ID_Article"
WHERE r.objet IN ('ARTICLE_1', 'ARTICLE_2', 'ARTICLE_ALERTE')
ORDER BY v."ID_Article",
    v."Mois";
-- 9. Couverture stock
SELECT v.*
FROM logistique."V_CouvertureStock" v
    JOIN tmp_logistique_vue_test_refs r ON r.id_article = v."ID_Article"
WHERE r.objet IN ('ARTICLE_1', 'ARTICLE_2', 'ARTICLE_ALERTE')
ORDER BY v."ID_Article";
-- 10. Suivi reglements
SELECT v.*
FROM logistique."V_SuiviReglements" v
    JOIN tmp_logistique_vue_test_refs r ON r.code_facture = v."CodeFacture"
WHERE r.objet = 'CMD_SORTIE';
ROLLBACK;