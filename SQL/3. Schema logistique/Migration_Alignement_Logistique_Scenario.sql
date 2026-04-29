/* ============================================================================
   MIGRATION D'ALIGNEMENT DU MODULE LOGISTIQUE
   SauverNdeko - alignement sur scenario_metier_logistique.md

   Objectif :
   - conserver T_Article comme stock courant
   - conserver T_Mouvement comme historique
   - appliquer la regle :
       INSERT applique l'effet
       DELETE annule l'effet
       UPDATE annule l'ancien effet puis applique le nouveau
   - interdire les ecritures directes sur T_Mouvement
   - eviter les doublons de mouvements quand T_CommandeDetail pilote le stock

   Notes :
   - ce script ne modifie pas les tables de base si leur schema actuel est sain
   - T_Mouvement.QteMvt etant en integer dans le schema actuel, les quantites
     fractionnaires sont bloquees par la logique metier pour preserver la
     coherence historique
   ============================================================================ */

BEGIN;

/* ============================================================================
   0. CONTROLES PREALABLES
   ============================================================================ */

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.tables
        WHERE table_schema = 'logistique'
          AND table_name = 'T_Article'
    ) THEN
        RAISE EXCEPTION 'Table logistique.T_Article introuvable.';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.tables
        WHERE table_schema = 'logistique'
          AND table_name = 'T_Commande'
    ) THEN
        RAISE EXCEPTION 'Table logistique.T_Commande introuvable.';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.tables
        WHERE table_schema = 'logistique'
          AND table_name = 'T_CommandeDetail'
    ) THEN
        RAISE EXCEPTION 'Table logistique.T_CommandeDetail introuvable.';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.tables
        WHERE table_schema = 'logistique'
          AND table_name = 'T_Mouvement'
    ) THEN
        RAISE EXCEPTION 'Table logistique.T_Mouvement introuvable.';
    END IF;
END $$;

DROP FUNCTION IF EXISTS logistique.fn_assert_generique_category(integer, integer, text, text) CASCADE;

CREATE OR REPLACE FUNCTION logistique.fn_assert_generique_category(
    IN p_id_generique integer,
    IN p_id_categorie_generique integer,
    IN p_contexte text,
    IN p_nom_colonne text
)
RETURNS void
LANGUAGE plpgsql
AS $BODY$
DECLARE
    v_nom_categorie text;
BEGIN
    IF p_id_generique IS NULL THEN
        RETURN;
    END IF;

    SELECT cg."NomCategorieGenerique"
    INTO v_nom_categorie
    FROM referentiel."T_CategorieGenerique" cg
    WHERE cg."ID_CategorieGenerique" = p_id_categorie_generique;

    IF NOT EXISTS (
        SELECT 1
        FROM referentiel."T_Generique" g
        WHERE g."ID_Generique" = p_id_generique
          AND g."ID_CategorieGeneriqueFk" = p_id_categorie_generique
    ) THEN
        IF EXISTS (
            SELECT 1
            FROM referentiel."T_Generique" g
            WHERE g."ID_Generique" = p_id_generique
        ) THEN
            RAISE EXCEPTION
                '% : %= % present dans T_Generique mais hors categorie attendue % (%).',
                p_contexte,
                p_nom_colonne,
                p_id_generique,
                p_id_categorie_generique,
                COALESCE(v_nom_categorie, 'Categorie inconnue');
        END IF;

        RAISE EXCEPTION
            '% : %= % introuvable dans T_Generique pour la categorie % (%).',
            p_contexte,
            p_nom_colonne,
            p_id_generique,
            p_id_categorie_generique,
            COALESCE(v_nom_categorie, 'Categorie inconnue');
    END IF;
END;
$BODY$;


/* ============================================================================
   1. OUTIL CENTRAL : variation de stock sur T_Article
   ============================================================================ */

DROP PROCEDURE IF EXISTS logistique.ps_update_qte_article(integer, numeric, character varying);

CREATE OR REPLACE PROCEDURE logistique.ps_update_qte_article(
    IN p_id_article_fk integer,
    IN p_qte numeric,
    IN p_operateur character varying
)
LANGUAGE plpgsql
AS $BODY$
DECLARE
    v_delta numeric;
    v_operateur varchar(1);
    v_new_stock numeric;
BEGIN
    IF p_qte IS NULL OR p_qte <= 0 THEN
        RAISE EXCEPTION
            'ps_update_qte_article : la quantite doit etre strictement positive (recu=%).',
            p_qte;
    END IF;

    v_operateur := trim(p_operateur);

    IF v_operateur NOT IN ('+', '-') THEN
        RAISE EXCEPTION
            'ps_update_qte_article : operateur invalide (recu=%). Utiliser seulement + ou -.',
            p_operateur;
    END IF;

    v_delta := CASE WHEN v_operateur = '+' THEN p_qte ELSE -p_qte END;

    UPDATE logistique."T_Article"
    SET "QteArticle" = COALESCE("QteArticle", 0)::numeric + v_delta
    WHERE "ID_Article" = p_id_article_fk
    RETURNING "QteArticle" INTO v_new_stock;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'ps_update_qte_article : article % introuvable.',
            p_id_article_fk;
    END IF;

    IF v_new_stock < 0 THEN
        RAISE EXCEPTION
            'ps_update_qte_article : la mise a jour ferait passer le stock de l''article % en negatif (stock final=%).',
            p_id_article_fk, v_new_stock;
    END IF;
END;
$BODY$;


/* ============================================================================
   2. T_Article : validation + mouvements de rapport directs
   ============================================================================ */

DROP PROCEDURE IF EXISTS logistique.ps_crud_article(integer, numeric, numeric, character varying);
DROP PROCEDURE IF EXISTS logistique.ps_crud_article(integer, integer, integer, integer, numeric, numeric, character varying);

CREATE OR REPLACE PROCEDURE logistique.ps_crud_article(
    IN p_id_article integer,
    IN p_id_type_article integer,
    IN p_id_categorie_article integer,
    IN p_id_unite integer,
    IN p_old_qte numeric(14,3),
    IN p_new_qte numeric(14,3),
    IN p_operation character varying
)
LANGUAGE plpgsql
AS $BODY$
DECLARE
    v_op text;
    v_new_qte numeric(14,3);
BEGIN
    v_op := upper(trim(p_operation));
    v_new_qte := COALESCE(p_new_qte, 0)::numeric(14,3);

    IF v_op IN ('INSERT', 'UPDATE') THEN
        PERFORM logistique.fn_assert_generique_category(
            p_id_type_article,
            46,
            format('ps_crud_article(%s)', v_op),
            'ID_TypeArticleFk'
        );
        PERFORM logistique.fn_assert_generique_category(
            p_id_categorie_article,
            40,
            format('ps_crud_article(%s)', v_op),
            'ID_CategorieArticleFk'
        );
        PERFORM logistique.fn_assert_generique_category(
            p_id_unite,
            34,
            format('ps_crud_article(%s)', v_op),
            'ID_UniteFk'
        );
    END IF;

    IF v_op IN ('INSERT', 'UPDATE') AND v_new_qte < 0 THEN
        RAISE EXCEPTION
            'ps_crud_article(%) : QteArticle negative interdite pour ID_Article=%.',
            v_op, p_id_article;
    END IF;
END;
$BODY$;

DROP FUNCTION IF EXISTS logistique.tr_crud_article_before() CASCADE;
DROP FUNCTION IF EXISTS logistique.tr_crud_article_after() CASCADE;
DROP FUNCTION IF EXISTS logistique.tr_crud_article() CASCADE;

CREATE OR REPLACE FUNCTION logistique.tr_crud_article_before()
RETURNS trigger
LANGUAGE plpgsql
AS $BODY$
DECLARE
    v_new_qte numeric(14,3);
BEGIN
    IF TG_OP = 'INSERT' THEN
        v_new_qte := COALESCE(NEW."QteArticle", 0)::numeric(14,3);
        NEW."QteArticle" := v_new_qte;

        CALL logistique.ps_crud_article(
            NEW."ID_Article",
            NEW."ID_TypeArticleFk",
            NEW."ID_CategorieArticleFk",
            NEW."ID_UniteFk",
            NULL,
            v_new_qte,
            'INSERT'
        );
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        NEW."QteArticle" := COALESCE(NEW."QteArticle", 0)::numeric(14,3);

        CALL logistique.ps_crud_article(
            NEW."ID_Article",
            NEW."ID_TypeArticleFk",
            NEW."ID_CategorieArticleFk",
            NEW."ID_UniteFk",
            COALESCE(OLD."QteArticle", 0)::numeric(14,3),
            NEW."QteArticle",
            'UPDATE'
        );
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        IF EXISTS (
            SELECT 1
            FROM logistique."T_CommandeDetail" cd
            WHERE cd."ID_ArticleFk" = OLD."ID_Article"
        ) THEN
            RAISE EXCEPTION
                'tr_crud_article(DELETE) : suppression interdite, article % lie a T_CommandeDetail.',
                OLD."ID_Article";
        END IF;

        IF EXISTS (
            SELECT 1
            FROM logistique."T_Mouvement" m
            WHERE m."ID_ArticleFk" = OLD."ID_Article"
        ) THEN
            RAISE EXCEPTION
                'tr_crud_article(DELETE) : suppression interdite, article % lie a T_Mouvement.',
                OLD."ID_Article";
        END IF;

        RETURN OLD;
    END IF;

    RETURN NEW;
END;
$BODY$;

CREATE OR REPLACE FUNCTION logistique.tr_crud_article_after()
RETURNS trigger
LANGUAGE plpgsql
AS $BODY$
DECLARE
    v_new_qte numeric(14,3);
    v_old_qte numeric(14,3);
    v_delta numeric(14,3);
    v_type_mvt integer;
    v_qte_mvt integer;
    v_skip_report_mvt boolean;
BEGIN
    v_skip_report_mvt := COALESCE(current_setting('logistique.skip_article_report_mvt', true), 'off') = 'on';

    IF v_skip_report_mvt THEN
        RETURN NEW;
    END IF;

    IF TG_OP = 'INSERT' THEN
        v_new_qte := COALESCE(NEW."QteArticle", 0)::numeric(14,3);

        IF v_new_qte = 0 THEN
            RETURN NEW;
        END IF;

        IF v_new_qte <> trunc(v_new_qte) THEN
            RAISE EXCEPTION
                'tr_crud_article_after(INSERT) : QteArticle=% ne peut pas etre historisee dans T_Mouvement.QteMvt entier.',
                v_new_qte;
        END IF;

        SELECT g."ID_Generique"
        INTO v_type_mvt
        FROM referentiel."T_Generique" g
        WHERE g."AbrGenerique" ILIKE 'entr%'
          AND g."ID_CategorieGeneriqueFk" = 64
        ORDER BY g."ID_Generique"
        LIMIT 1;

        IF v_type_mvt IS NULL THEN
            RAISE EXCEPTION 'tr_crud_article_after(INSERT) : type de mouvement Entree introuvable.';
        END IF;

        v_qte_mvt := v_new_qte::integer;
    ELSIF TG_OP = 'UPDATE' THEN
        v_old_qte := COALESCE(OLD."QteArticle", 0)::numeric(14,3);
        v_new_qte := COALESCE(NEW."QteArticle", 0)::numeric(14,3);
        v_delta := v_new_qte - v_old_qte;

        IF v_delta = 0 THEN
            RETURN NEW;
        END IF;

        IF abs(v_delta) <> trunc(abs(v_delta)) THEN
            RAISE EXCEPTION
                'tr_crud_article_after(UPDATE) : delta=% ne peut pas etre historise dans T_Mouvement.QteMvt entier.',
                v_delta;
        END IF;

        IF v_delta > 0 THEN
            SELECT g."ID_Generique"
            INTO v_type_mvt
            FROM referentiel."T_Generique" g
            WHERE g."AbrGenerique" ILIKE 'entr%'
              AND g."ID_CategorieGeneriqueFk" = 64
            ORDER BY g."ID_Generique"
            LIMIT 1;

            IF v_type_mvt IS NULL THEN
                RAISE EXCEPTION 'tr_crud_article_after(UPDATE) : type de mouvement Entree introuvable.';
            END IF;

            v_qte_mvt := v_delta::integer;
        ELSE
            SELECT g."ID_Generique"
            INTO v_type_mvt
            FROM referentiel."T_Generique" g
            WHERE g."AbrGenerique" ILIKE 'sort%'
              AND g."ID_CategorieGeneriqueFk" = 64
            ORDER BY g."ID_Generique"
            LIMIT 1;

            IF v_type_mvt IS NULL THEN
                RAISE EXCEPTION 'tr_crud_article_after(UPDATE) : type de mouvement Sortie introuvable.';
            END IF;

            v_qte_mvt := abs(v_delta)::integer;
        END IF;
    ELSE
        RETURN NEW;
    END IF;

    PERFORM set_config('logistique.allow_t_mouvement_write', 'on', true);

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
        v_type_mvt,
        NEW."ID_Article",
        NULL,
        now()::timestamp without time zone,
        now()::timestamp without time zone,
        v_qte_mvt,
        COALESCE(NEW."PVArticle", 0)
    );

    PERFORM set_config('logistique.allow_t_mouvement_write', 'off', true);
    RETURN NEW;
END;
$BODY$;

DROP TRIGGER IF EXISTS tr_crud_article ON logistique."T_Article";
DROP TRIGGER IF EXISTS tr_crud_article_before ON logistique."T_Article";
DROP TRIGGER IF EXISTS tr_crud_article_after ON logistique."T_Article";

CREATE TRIGGER tr_crud_article_before
BEFORE INSERT OR UPDATE OR DELETE
ON logistique."T_Article"
FOR EACH ROW
EXECUTE FUNCTION logistique.tr_crud_article_before();

CREATE TRIGGER tr_crud_article_after
AFTER INSERT OR UPDATE
ON logistique."T_Article"
FOR EACH ROW
EXECUTE FUNCTION logistique.tr_crud_article_after();


/* ============================================================================
   3. T_Commande : validation, realignement, suppression metier
   ============================================================================ */

DROP PROCEDURE IF EXISTS logistique.ps_crud_commande(integer, integer, integer, character varying);
DROP PROCEDURE IF EXISTS logistique.ps_crud_commande(integer, integer, integer, integer, integer, integer, character varying);

CREATE OR REPLACE PROCEDURE logistique.ps_crud_commande(
    IN p_id_commande integer,
    IN p_old_id_type_cmd integer,
    IN p_new_id_type_cmd integer,
    IN p_new_id_statut_cmd integer,
    IN p_new_id_condition_paiement integer,
    IN p_new_id_mode_paiement integer,
    IN p_operation character varying
)
LANGUAGE plpgsql
AS $BODY$
DECLARE
    v_op text;
BEGIN
    v_op := upper(trim(p_operation));

    IF v_op IN ('INSERT', 'UPDATE') THEN
        PERFORM logistique.fn_assert_generique_category(
            p_new_id_type_cmd,
            64,
            format('ps_crud_commande(%s)', v_op),
            'ID_TypeCmdFk'
        );
        PERFORM logistique.fn_assert_generique_category(
            p_new_id_statut_cmd,
            28,
            format('ps_crud_commande(%s)', v_op),
            'ID_StatutCmdFk'
        );
        PERFORM logistique.fn_assert_generique_category(
            p_new_id_condition_paiement,
            37,
            format('ps_crud_commande(%s)', v_op),
            'ID_ConditionPaiementFk'
        );
        PERFORM logistique.fn_assert_generique_category(
            p_new_id_mode_paiement,
            36,
            format('ps_crud_commande(%s)', v_op),
            'ID_ModePaiementFk'
        );
    END IF;

    IF v_op = 'INSERT' THEN
        RETURN;
    END IF;

    IF v_op = 'UPDATE' THEN
        IF p_new_id_type_cmd IS NULL THEN
            RAISE EXCEPTION
                'ps_crud_commande(UPDATE) : nouveau ID_TypeCmdFk NULL pour commande %.',
                p_id_commande;
        END IF;

        IF p_old_id_type_cmd IS NOT DISTINCT FROM p_new_id_type_cmd THEN
            RETURN;
        END IF;

        PERFORM set_config('logistique.allow_t_mouvement_write', 'on', true);

        UPDATE logistique."T_Mouvement"
        SET "ID_TypeMvtFk" = p_new_id_type_cmd
        WHERE "ID_cmdFk" = p_id_commande;

        PERFORM set_config('logistique.allow_t_mouvement_write', 'off', true);
        RETURN;
    END IF;

    IF v_op = 'DELETE' THEN
        RETURN;
    END IF;
END;
$BODY$;

DROP FUNCTION IF EXISTS logistique.tr_crud_commande() CASCADE;

CREATE OR REPLACE FUNCTION logistique.tr_crud_commande()
RETURNS trigger
LANGUAGE plpgsql
AS $BODY$
BEGIN
    IF TG_OP = 'INSERT' THEN
        CALL logistique.ps_crud_commande(
            NEW."ID_Commande",
            NULL,
            NEW."ID_TypeCmdFk",
            NEW."ID_StatutCmdFk",
            NEW."ID_ConditionPaiementFk",
            NEW."ID_ModePaiementFk",
            'INSERT'
        );
        RETURN NEW;
    END IF;

    IF TG_OP = 'UPDATE' THEN
        CALL logistique.ps_crud_commande(
            NEW."ID_Commande",
            OLD."ID_TypeCmdFk",
            NEW."ID_TypeCmdFk",
            NEW."ID_StatutCmdFk",
            NEW."ID_ConditionPaiementFk",
            NEW."ID_ModePaiementFk",
            'UPDATE'
        );
        RETURN NEW;
    END IF;

    RETURN NEW;
END;
$BODY$;

DROP TRIGGER IF EXISTS tr_crud_commande ON logistique."T_Commande";
DROP TRIGGER IF EXISTS tr_delete_commande ON logistique."T_Commande";

CREATE TRIGGER tr_crud_commande
AFTER INSERT OR UPDATE
ON logistique."T_Commande"
FOR EACH ROW
EXECUTE FUNCTION logistique.tr_crud_commande();


/* ============================================================================
   4. T_CommandeDetail : applique l'effet commande sur stock + mouvement
   ============================================================================ */

DROP PROCEDURE IF EXISTS logistique.ps_crud_commandeDetail(
    integer, integer, numeric,
    integer, integer, numeric,
    character varying
);

CREATE OR REPLACE PROCEDURE logistique.ps_crud_commandeDetail(
    IN p_old_cmd_fk integer,
    IN p_old_article_fk integer,
    IN p_old_qte numeric,
    IN p_new_cmd_fk integer,
    IN p_new_article_fk integer,
    IN p_new_qte numeric,
    IN p_operation character varying
)
LANGUAGE plpgsql
AS $BODY$
DECLARE
    v_op text;
    v_old_type_cmd_id integer;
    v_old_abr_type text;
    v_new_type_cmd_id integer;
    v_new_abr_type text;
    v_oper_stock_old varchar(1);
    v_oper_stock_new varchar(1);
    v_pu_mvt numeric(12,2);
BEGIN
    v_op := upper(trim(p_operation));

    IF v_op = 'INSERT' THEN
        IF p_new_qte IS NULL OR p_new_qte <= 0 THEN
            RAISE EXCEPTION
                'ps_crud_commandeDetail(INSERT) : QteCmdDetail invalide (=%).',
                p_new_qte;
        END IF;

        IF p_new_qte <> trunc(p_new_qte) THEN
            RAISE EXCEPTION
                'ps_crud_commandeDetail(INSERT) : QteCmdDetail=% incompatible avec T_Mouvement.QteMvt entier.',
                p_new_qte;
        END IF;

        SELECT c."ID_TypeCmdFk", g."AbrGenerique"
        INTO v_new_type_cmd_id, v_new_abr_type
        FROM logistique."T_Commande" c
        JOIN referentiel."T_Generique" g
          ON c."ID_TypeCmdFk" = g."ID_Generique"
         AND g."ID_CategorieGeneriqueFk" = 64
        WHERE c."ID_Commande" = p_new_cmd_fk
        LIMIT 1;

        IF NOT FOUND THEN
            RAISE EXCEPTION
                'ps_crud_commandeDetail(INSERT) : commande % introuvable ou sans type.',
                p_new_cmd_fk;
        END IF;

        IF v_new_abr_type ILIKE 'entr%' THEN
            v_oper_stock_new := '+';
        ELSIF v_new_abr_type ILIKE 'sort%' THEN
            v_oper_stock_new := '-';
        ELSE
            RAISE EXCEPTION
                'ps_crud_commandeDetail(INSERT) : type de commande non gere (ID_TypeCmdFk=%).',
                v_new_type_cmd_id;
        END IF;

        PERFORM set_config('logistique.skip_article_report_mvt', 'on', true);
        CALL logistique.ps_update_qte_article(p_new_article_fk, p_new_qte, v_oper_stock_new);
        PERFORM set_config('logistique.skip_article_report_mvt', 'off', true);

        SELECT COALESCE("PVArticle", 0)
        INTO v_pu_mvt
        FROM logistique."T_Article"
        WHERE "ID_Article" = p_new_article_fk;

        IF NOT FOUND OR v_pu_mvt IS NULL THEN
            v_pu_mvt := 0;
        END IF;

        PERFORM set_config('logistique.allow_t_mouvement_write', 'on', true);

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
            v_new_type_cmd_id,
            p_new_article_fk,
            p_new_cmd_fk,
            now()::timestamp without time zone,
            now()::timestamp without time zone,
            p_new_qte::integer,
            v_pu_mvt
        );

        PERFORM set_config('logistique.allow_t_mouvement_write', 'off', true);
        RETURN;
    END IF;

    IF v_op = 'UPDATE' THEN
        IF p_old_cmd_fk IS NOT DISTINCT FROM p_new_cmd_fk
           AND p_old_article_fk IS NOT DISTINCT FROM p_new_article_fk
           AND p_old_qte IS NOT DISTINCT FROM p_new_qte THEN
            RETURN;
        END IF;

        IF p_new_qte IS NULL OR p_new_qte <= 0 THEN
            RAISE EXCEPTION
                'ps_crud_commandeDetail(UPDATE) : nouvelle QteCmdDetail invalide (=%).',
                p_new_qte;
        END IF;

        IF p_new_qte <> trunc(p_new_qte) THEN
            RAISE EXCEPTION
                'ps_crud_commandeDetail(UPDATE) : nouvelle QteCmdDetail=% incompatible avec T_Mouvement.QteMvt entier.',
                p_new_qte;
        END IF;

        IF p_old_cmd_fk IS NOT NULL AND p_old_article_fk IS NOT NULL AND p_old_qte IS NOT NULL THEN
            IF p_old_qte <> trunc(p_old_qte) THEN
                RAISE EXCEPTION
                    'ps_crud_commandeDetail(UPDATE) : ancienne QteCmdDetail=% incompatible avec T_Mouvement.QteMvt entier.',
                    p_old_qte;
            END IF;

            SELECT c."ID_TypeCmdFk", g."AbrGenerique"
            INTO v_old_type_cmd_id, v_old_abr_type
            FROM logistique."T_Commande" c
            JOIN referentiel."T_Generique" g
              ON c."ID_TypeCmdFk" = g."ID_Generique"
             AND g."ID_CategorieGeneriqueFk" = 64
            WHERE c."ID_Commande" = p_old_cmd_fk
            LIMIT 1;

            IF NOT FOUND THEN
                SELECT m."ID_TypeMvtFk", g."AbrGenerique"
                INTO v_old_type_cmd_id, v_old_abr_type
                FROM logistique."T_Mouvement" m
                JOIN referentiel."T_Generique" g
                  ON m."ID_TypeMvtFk" = g."ID_Generique"
                 AND g."ID_CategorieGeneriqueFk" = 64
                WHERE m."ID_ArticleFk" = p_old_article_fk
                  AND m."ID_cmdFk" = p_old_cmd_fk
                LIMIT 1;
            END IF;

            IF NOT FOUND THEN
                RAISE EXCEPTION
                    'ps_crud_commandeDetail(UPDATE) : ancienne commande % introuvable.',
                    p_old_cmd_fk;
            END IF;

            IF v_old_abr_type ILIKE 'entr%' THEN
                v_oper_stock_old := '-';
            ELSIF v_old_abr_type ILIKE 'sort%' THEN
                v_oper_stock_old := '+';
            ELSE
                RAISE EXCEPTION
                    'ps_crud_commandeDetail(UPDATE) : ancien type non gere (ID_TypeCmdFk=%).',
                    v_old_type_cmd_id;
            END IF;

            PERFORM set_config('logistique.skip_article_report_mvt', 'on', true);
            CALL logistique.ps_update_qte_article(p_old_article_fk, p_old_qte, v_oper_stock_old);
            PERFORM set_config('logistique.skip_article_report_mvt', 'off', true);

            PERFORM set_config('logistique.allow_t_mouvement_write', 'on', true);

            DELETE FROM logistique."T_Mouvement"
            WHERE "ID_TypeMvtFk" = v_old_type_cmd_id
              AND "ID_ArticleFk" = p_old_article_fk
              AND "ID_cmdFk" = p_old_cmd_fk;

            PERFORM set_config('logistique.allow_t_mouvement_write', 'off', true);
        END IF;

        SELECT c."ID_TypeCmdFk", g."AbrGenerique"
        INTO v_new_type_cmd_id, v_new_abr_type
        FROM logistique."T_Commande" c
        JOIN referentiel."T_Generique" g
          ON c."ID_TypeCmdFk" = g."ID_Generique"
         AND g."ID_CategorieGeneriqueFk" = 64
        WHERE c."ID_Commande" = p_new_cmd_fk
        LIMIT 1;

        IF NOT FOUND THEN
            RAISE EXCEPTION
                'ps_crud_commandeDetail(UPDATE) : nouvelle commande % introuvable.',
                p_new_cmd_fk;
        END IF;

        IF v_new_abr_type ILIKE 'entr%' THEN
            v_oper_stock_new := '+';
        ELSIF v_new_abr_type ILIKE 'sort%' THEN
            v_oper_stock_new := '-';
        ELSE
            RAISE EXCEPTION
                'ps_crud_commandeDetail(UPDATE) : nouveau type non gere (ID_TypeCmdFk=%).',
                v_new_type_cmd_id;
        END IF;

        PERFORM set_config('logistique.skip_article_report_mvt', 'on', true);
        CALL logistique.ps_update_qte_article(p_new_article_fk, p_new_qte, v_oper_stock_new);
        PERFORM set_config('logistique.skip_article_report_mvt', 'off', true);

        SELECT COALESCE("PVArticle", 0)
        INTO v_pu_mvt
        FROM logistique."T_Article"
        WHERE "ID_Article" = p_new_article_fk;

        IF NOT FOUND OR v_pu_mvt IS NULL THEN
            v_pu_mvt := 0;
        END IF;

        PERFORM set_config('logistique.allow_t_mouvement_write', 'on', true);

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
            v_new_type_cmd_id,
            p_new_article_fk,
            p_new_cmd_fk,
            now()::timestamp without time zone,
            now()::timestamp without time zone,
            p_new_qte::integer,
            v_pu_mvt
        );

        PERFORM set_config('logistique.allow_t_mouvement_write', 'off', true);
        RETURN;
    END IF;

    IF v_op = 'DELETE' THEN
        IF p_old_cmd_fk IS NULL OR p_old_article_fk IS NULL OR p_old_qte IS NULL THEN
            RAISE EXCEPTION
                'ps_crud_commandeDetail(DELETE) : parametres OLD incomplets.';
        END IF;

        IF p_old_qte <> trunc(p_old_qte) THEN
            RAISE EXCEPTION
                'ps_crud_commandeDetail(DELETE) : ancienne QteCmdDetail=% incompatible avec T_Mouvement.QteMvt entier.',
                p_old_qte;
        END IF;

        SELECT c."ID_TypeCmdFk", g."AbrGenerique"
        INTO v_old_type_cmd_id, v_old_abr_type
        FROM logistique."T_Commande" c
        JOIN referentiel."T_Generique" g
          ON c."ID_TypeCmdFk" = g."ID_Generique"
         AND g."ID_CategorieGeneriqueFk" = 64
        WHERE c."ID_Commande" = p_old_cmd_fk
        LIMIT 1;

        IF NOT FOUND THEN
            SELECT m."ID_TypeMvtFk", g."AbrGenerique"
            INTO v_old_type_cmd_id, v_old_abr_type
            FROM logistique."T_Mouvement" m
            JOIN referentiel."T_Generique" g
              ON m."ID_TypeMvtFk" = g."ID_Generique"
             AND g."ID_CategorieGeneriqueFk" = 64
            WHERE m."ID_ArticleFk" = p_old_article_fk
              AND m."ID_cmdFk" = p_old_cmd_fk
            LIMIT 1;
        END IF;

        IF NOT FOUND THEN
            RAISE EXCEPTION
                'ps_crud_commandeDetail(DELETE) : commande % introuvable.',
                p_old_cmd_fk;
        END IF;

        IF v_old_abr_type ILIKE 'entr%' THEN
            v_oper_stock_old := '-';
        ELSIF v_old_abr_type ILIKE 'sort%' THEN
            v_oper_stock_old := '+';
        ELSE
            RAISE EXCEPTION
                'ps_crud_commandeDetail(DELETE) : type non gere (ID_TypeCmdFk=%).',
                v_old_type_cmd_id;
        END IF;

        PERFORM set_config('logistique.skip_article_report_mvt', 'on', true);
        CALL logistique.ps_update_qte_article(p_old_article_fk, p_old_qte, v_oper_stock_old);
        PERFORM set_config('logistique.skip_article_report_mvt', 'off', true);

        PERFORM set_config('logistique.allow_t_mouvement_write', 'on', true);

        DELETE FROM logistique."T_Mouvement"
        WHERE "ID_TypeMvtFk" = v_old_type_cmd_id
          AND "ID_ArticleFk" = p_old_article_fk
          AND "ID_cmdFk" = p_old_cmd_fk;

        PERFORM set_config('logistique.allow_t_mouvement_write', 'off', true);
        RETURN;
    END IF;
END;
$BODY$;

DROP FUNCTION IF EXISTS logistique.tr_crud_commandedetail() CASCADE;

CREATE OR REPLACE FUNCTION logistique.tr_crud_commandeDetail()
RETURNS trigger
LANGUAGE plpgsql
AS $BODY$
BEGIN
    IF TG_OP = 'INSERT' THEN
        CALL logistique.ps_crud_commandeDetail(
            NULL, NULL, NULL,
            NEW."ID_CmdFk", NEW."ID_ArticleFk", NEW."QteCmdDetail",
            'INSERT'
        );
        RETURN NEW;
    END IF;

    IF TG_OP = 'UPDATE' THEN
        CALL logistique.ps_crud_commandeDetail(
            OLD."ID_CmdFk", OLD."ID_ArticleFk", OLD."QteCmdDetail",
            NEW."ID_CmdFk", NEW."ID_ArticleFk", NEW."QteCmdDetail",
            'UPDATE'
        );
        RETURN NEW;
    END IF;

    IF TG_OP = 'DELETE' THEN
        CALL logistique.ps_crud_commandeDetail(
            OLD."ID_CmdFk", OLD."ID_ArticleFk", OLD."QteCmdDetail",
            NULL, NULL, NULL,
            'DELETE'
        );
        RETURN OLD;
    END IF;

    RETURN NEW;
END;
$BODY$;

DROP TRIGGER IF EXISTS tr_crud_commandedetail ON logistique."T_CommandeDetail";
DROP TRIGGER IF EXISTS tr_crud_commandeDetail ON logistique."T_CommandeDetail";
DROP TRIGGER IF EXISTS tr_delete_commandedetail ON logistique."T_CommandeDetail";
DROP TRIGGER IF EXISTS tr_delete_commandeDetail ON logistique."T_CommandeDetail";

CREATE TRIGGER tr_crud_commandedetail
AFTER INSERT OR UPDATE
ON logistique."T_CommandeDetail"
FOR EACH ROW
EXECUTE FUNCTION logistique.tr_crud_commandeDetail();

CREATE TRIGGER tr_delete_commandedetail
BEFORE DELETE
ON logistique."T_CommandeDetail"
FOR EACH ROW
EXECUTE FUNCTION logistique.tr_crud_commandeDetail();


/* ============================================================================
   5. Recalcul des totaux de commande
   ============================================================================ */

DROP PROCEDURE IF EXISTS logistique.ps_update_totaux_commande(integer);

CREATE OR REPLACE PROCEDURE logistique.ps_update_totaux_commande(IN p_id_commande integer)
LANGUAGE plpgsql
AS $BODY$
DECLARE
    v_montant_ht numeric(12,2);
BEGIN
    SELECT COALESCE(SUM(cd."QteCmdDetail" * cd."PUCmdDetail"), 0)
    INTO v_montant_ht
    FROM logistique."T_CommandeDetail" cd
    WHERE cd."ID_CmdFk" = p_id_commande;

    UPDATE logistique."T_Commande"
    SET "MontantHT" = v_montant_ht,
        "MontantTTC" = v_montant_ht
    WHERE "ID_Commande" = p_id_commande;
END;
$BODY$;

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
        IF OLD."ID_CmdFk" IS DISTINCT FROM NEW."ID_CmdFk" THEN
            CALL logistique.ps_update_totaux_commande(OLD."ID_CmdFk");
        END IF;
        v_id_cmd := NEW."ID_CmdFk";
    ELSIF TG_OP = 'DELETE' THEN
        v_id_cmd := OLD."ID_CmdFk";
    ELSE
        RETURN NEW;
    END IF;

    CALL logistique.ps_update_totaux_commande(v_id_cmd);

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;

    RETURN NEW;
END;
$BODY$;

DROP TRIGGER IF EXISTS tr_totaux_commande ON logistique."T_CommandeDetail";

CREATE TRIGGER tr_totaux_commande
AFTER INSERT OR UPDATE OR DELETE
ON logistique."T_CommandeDetail"
FOR EACH ROW
EXECUTE FUNCTION logistique.tr_totaux_commande();


/* ============================================================================
   6. Verrou intelligent sur T_Mouvement
   ============================================================================ */

DROP FUNCTION IF EXISTS logistique.tr_lock_mouvement_direct() CASCADE;

CREATE OR REPLACE FUNCTION logistique.tr_lock_mouvement_direct()
RETURNS trigger
LANGUAGE plpgsql
AS $BODY$
BEGIN
    IF COALESCE(current_setting('logistique.allow_t_mouvement_write', true), 'off') = 'on' THEN
        IF TG_OP = 'DELETE' THEN
            RETURN OLD;
        END IF;

        PERFORM logistique.fn_assert_generique_category(
            NEW."ID_TypeMvtFk",
            64,
            format('tr_lock_mouvement_direct(%s)', TG_OP),
            'ID_TypeMvtFk'
        );

        RETURN NEW;
    END IF;

    RAISE EXCEPTION
        'T_Mouvement est geree par la logique metier. Ecriture directe interdite.';
END;
$BODY$;

DROP TRIGGER IF EXISTS tr_lock_mouvement_direct ON logistique."T_Mouvement";

CREATE TRIGGER tr_lock_mouvement_direct
BEFORE INSERT OR UPDATE OR DELETE
ON logistique."T_Mouvement"
FOR EACH ROW
EXECUTE FUNCTION logistique.tr_lock_mouvement_direct();


/* ============================================================================
   7. Verrou sur commandes cloturees
   ============================================================================ */

DROP FUNCTION IF EXISTS logistique.tr_lock_commande_cloturee() CASCADE;

CREATE OR REPLACE FUNCTION logistique.tr_lock_commande_cloturee()
RETURNS trigger
LANGUAGE plpgsql
AS $BODY$
BEGIN
    IF OLD."StatusFacture" = 'Clôturée' THEN
        RAISE EXCEPTION
            'Commande % cloturee/facturee : modification ou suppression interdite.',
            OLD."ID_Commande";
    END IF;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
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


/* ============================================================================
   8. Validation des reglements
   ============================================================================ */

DROP PROCEDURE IF EXISTS logistique.ps_crud_reglement(integer, integer, character varying);

CREATE OR REPLACE PROCEDURE logistique.ps_crud_reglement(
    IN p_id_reglement integer,
    IN p_id_mode_reglement integer,
    IN p_operation character varying
)
LANGUAGE plpgsql
AS $BODY$
DECLARE
    v_op text;
BEGIN
    v_op := upper(trim(p_operation));

    IF v_op IN ('INSERT', 'UPDATE') THEN
        PERFORM logistique.fn_assert_generique_category(
            p_id_mode_reglement,
            36,
            format('ps_crud_reglement(%s)', v_op),
            'ID_ModeReglementFk'
        );
    END IF;
END;
$BODY$;

DROP FUNCTION IF EXISTS logistique.tr_crud_reglement() CASCADE;

CREATE OR REPLACE FUNCTION logistique.tr_crud_reglement()
RETURNS trigger
LANGUAGE plpgsql
AS $BODY$
BEGIN
    IF TG_OP IN ('INSERT', 'UPDATE') THEN
        CALL logistique.ps_crud_reglement(
            NEW."ID_Reglement",
            NEW."ID_ModeReglementFk",
            TG_OP
        );
    END IF;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;

    RETURN NEW;
END;
$BODY$;

DROP TRIGGER IF EXISTS tr_crud_reglement ON logistique."T_Reglements";

CREATE TRIGGER tr_crud_reglement
BEFORE INSERT OR UPDATE
ON logistique."T_Reglements"
FOR EACH ROW
EXECUTE FUNCTION logistique.tr_crud_reglement();


/* ============================================================================
   9. Vues metier et analytiques
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

CREATE OR REPLACE VIEW logistique."V_MouvementStock" AS
SELECT m."ID_Mvt",
    m."ID_ArticleFk",
    m."ID_cmdFk",
    m."DateMvt",
    m."QteMvt",
    m."PUMvt",
    COALESCE(c."ID_TypeCmdFk", m."ID_TypeMvtFk")::integer AS "ID_TypeMvt",
    COALESCE(g."AbrGenerique", g2."AbrGenerique") AS "AbrTypeMvt",
    CASE
        WHEN COALESCE(g."AbrGenerique", g2."AbrGenerique") ILIKE 'entr%' THEN 1
        WHEN COALESCE(g."AbrGenerique", g2."AbrGenerique") ILIKE 'sort%' THEN -1
        ELSE 0
    END::integer AS "SigneStock",
    (
        m."QteMvt" * CASE
            WHEN COALESCE(g."AbrGenerique", g2."AbrGenerique") ILIKE 'entr%' THEN 1
            WHEN COALESCE(g."AbrGenerique", g2."AbrGenerique") ILIKE 'sort%' THEN -1
            ELSE 0
        END
    )::numeric AS "QteMvtSigned"
FROM logistique."T_Mouvement" m
LEFT JOIN logistique."T_Commande" c ON c."ID_Commande" = m."ID_cmdFk"
LEFT JOIN referentiel."T_Generique" g
  ON g."ID_Generique" = c."ID_TypeCmdFk"
 AND g."ID_CategorieGeneriqueFk" = 64
LEFT JOIN referentiel."T_Generique" g2
  ON g2."ID_Generique" = m."ID_TypeMvtFk"
 AND g2."ID_CategorieGeneriqueFk" = 64;

DROP FUNCTION IF EXISTS logistique.fn_audit_stock(integer, timestamp without time zone) CASCADE;
CREATE OR REPLACE FUNCTION logistique.fn_audit_stock(
    IN p_id_article integer DEFAULT NULL,
    IN p_date_max timestamp without time zone DEFAULT NULL
)
RETURNS TABLE(
    "ID_Article" integer,
    "CodeArticleInterne" character varying,
    "NomArticle" character varying,
    "StockArticle" numeric,
    "StockMouvements" numeric,
    "Ecart" numeric,
    "N_Mouvements" integer,
    "QteEntree" numeric,
    "QteSortie" numeric
)
LANGUAGE plpgsql
AS $BODY$
BEGIN
    RETURN QUERY
    SELECT a."ID_Article",
        a."CodeArticleInterne",
        a."NomArticle",
        COALESCE(a."QteArticle", 0)::numeric AS "StockArticle",
        COALESCE(SUM(v."QteMvtSigned"), 0)::numeric AS "StockMouvements",
        COALESCE(a."QteArticle", 0)::numeric - COALESCE(SUM(v."QteMvtSigned"), 0)::numeric AS "Ecart",
        COUNT(v."ID_Mvt")::integer AS "N_Mouvements",
        COALESCE(SUM(CASE WHEN v."SigneStock" = 1 THEN v."QteMvt" ELSE 0 END), 0)::numeric AS "QteEntree",
        COALESCE(SUM(CASE WHEN v."SigneStock" = -1 THEN v."QteMvt" ELSE 0 END), 0)::numeric AS "QteSortie"
    FROM logistique."T_Article" a
    LEFT JOIN logistique."V_MouvementStock" v
        ON v."ID_ArticleFk" = a."ID_Article"
       AND (p_date_max IS NULL OR v."DateMvt" <= p_date_max)
    WHERE p_id_article IS NULL OR a."ID_Article" = p_id_article
    GROUP BY a."ID_Article", a."CodeArticleInterne", a."NomArticle", a."QteArticle"
    ORDER BY a."NomArticle", a."ID_Article";
END;
$BODY$;

CREATE OR REPLACE VIEW logistique."V_AlertStock" AS
SELECT a."ID_Article",
    a."NomArticle",
    a."QteArticle",
    a."QteMinArticle",
    a."QteArticle" - a."QteMinArticle"::numeric AS "Marge"
FROM logistique."T_Article" a
WHERE a."QteMinArticle" IS NOT NULL;

CREATE OR REPLACE VIEW logistique."V_Article" AS
SELECT a."DateHeureAuto",
    a."ID_Article",
    a."ID_TypeArticleFk",
    a."ID_CategorieArticleFk",
    a."ID_UserFK",
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
    a."DatePeremptionArticle",
    u."IdUser",
    trim(both FROM concat(COALESCE(u."PrenomUser", ''), ' ', COALESCE(u."NomUser", ''))) AS "NomComplet"
FROM logistique."T_Article" a
LEFT JOIN systeme."T_Utilisateurs" u ON a."ID_UserFK" = u."IdUser";

CREATE OR REPLACE VIEW logistique."V_AuditStock" AS
SELECT *
FROM logistique.fn_audit_stock(NULL, NULL);

CREATE OR REPLACE VIEW logistique."V_AuditStock_Theorique" AS
WITH mvt AS (
    SELECT m."ID_ArticleFk",
        SUM(
            CASE
                WHEN g."AbrGenerique" ILIKE 'entr%' THEN m."QteMvt"
                WHEN g."AbrGenerique" ILIKE 'sort%' THEN -m."QteMvt"
                ELSE 0
            END
        ) AS stock_mouvement
    FROM logistique."T_Mouvement" m
    LEFT JOIN referentiel."T_Generique" g
      ON g."ID_Generique" = m."ID_TypeMvtFk"
     AND g."ID_CategorieGeneriqueFk" = 64
    GROUP BY m."ID_ArticleFk"
)
SELECT a."ID_Article",
    a."NomArticle",
    a."QteArticle" AS "StockEnregistre",
    COALESCE(mvt.stock_mouvement, 0) AS "StockCalcule",
    a."QteArticle" - COALESCE(mvt.stock_mouvement, 0)::numeric AS "Ecart"
FROM logistique."T_Article" a
LEFT JOIN mvt ON mvt."ID_ArticleFk" = a."ID_Article";

CREATE OR REPLACE VIEW logistique."V_Commande" AS
SELECT c."DateHeureAutoCmd",
    c."DateCmd",
    c."ID_Commande",
    c."ID_TypeCmdFk",
    c."ID_StatutCmdFk",
    c."ID_StatutCmdFk" AS "ID_StatutCmd",
    c."ID_ClientFk",
    c."ID_UserFk",
    u."NomUser",
    u."PrenomUser",
    trim(both FROM concat(COALESCE(u."PrenomUser", ''), ' ', COALESCE(u."NomUser", ''))) AS "NomComplet",
    c."CodeCmd",
    c."RefCmd",
    c."CodeFacture",
    c."DateFacture",
    c."MontantHT",
    c."MontantTTC",
    c."MontantRegleFacture",
    c."MontantResteFacture",
    c."ObsCmd",
    c."StatusFacture",
    c."ID_ConditionPaiementFk",
    c."DateEcheancePaiement",
    c."ID_ModePaiementFk"
FROM logistique."T_Commande" c
LEFT JOIN systeme."T_Utilisateurs" u ON c."ID_UserFk" = u."IdUser";

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

CREATE OR REPLACE VIEW logistique."V_CommandeOverview" AS
SELECT c."ID_Commande",
    c."DateCmd",
    c."MontantHT",
    c."MontantTTC",
    c."StatusFacture"
FROM logistique."T_Commande" c;

CREATE OR REPLACE VIEW logistique."V_CommandesSansDetails" AS
SELECT c."ID_Commande",
    c."CodeCmd"
FROM logistique."T_Commande" c
LEFT JOIN logistique."T_CommandeDetail" d ON d."ID_CmdFk" = c."ID_Commande"
WHERE d."ID_CmdFk" IS NULL
  AND COALESCE(c."CodeCmd", '') NOT IN ('C_000E', 'C_000S');

CREATE OR REPLACE VIEW logistique."V_ConsoMensuelle" AS
SELECT a."ID_Article",
    a."NomArticle",
    date_trunc('month', m."DateMvt") AS "Mois",
    SUM(
        CASE
            WHEN g."AbrGenerique" ILIKE 'sort%' THEN m."QteMvt"
            ELSE 0
        END
    ) AS "ConsoMensuelle"
FROM logistique."T_Mouvement" m
JOIN logistique."T_Article" a ON a."ID_Article" = m."ID_ArticleFk"
LEFT JOIN referentiel."T_Generique" g
  ON g."ID_Generique" = m."ID_TypeMvtFk"
 AND g."ID_CategorieGeneriqueFk" = 64
GROUP BY a."ID_Article", a."NomArticle", date_trunc('month', m."DateMvt");

CREATE OR REPLACE VIEW logistique."V_CouvertureStock" AS
WITH conso AS (
    SELECT m."ID_ArticleFk",
        SUM(
            CASE
                WHEN g."AbrGenerique" ILIKE 'sort%' THEN m."QteMvt"
                ELSE 0
            END
        ) AS conso_6m
    FROM logistique."T_Mouvement" m
    LEFT JOIN referentiel."T_Generique" g
      ON g."ID_Generique" = m."ID_TypeMvtFk"
     AND g."ID_CategorieGeneriqueFk" = 64
    WHERE m."DateMvt" >= CURRENT_DATE - INTERVAL '6 months'
    GROUP BY m."ID_ArticleFk"
)
SELECT a."ID_Article",
    a."NomArticle",
    a."QteArticle" AS "StockActuel",
    conso.conso_6m AS "Conso6Mois",
    ROUND(conso.conso_6m / 6.0, 2) AS "ConsoMoyMensuelle",
    CASE
        WHEN conso.conso_6m = 0 THEN NULL
        ELSE ROUND(a."QteArticle" / (conso.conso_6m / 6.0), 1)
    END AS "CouvertureMois"
FROM logistique."T_Article" a
LEFT JOIN conso ON conso."ID_ArticleFk" = a."ID_Article";

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
LEFT JOIN referentiel."T_Generique" g_typemvt
  ON m."ID_TypeMvtFk" = g_typemvt."ID_Generique"
 AND g_typemvt."ID_CategorieGeneriqueFk" = 64;

CREATE OR REPLACE VIEW logistique."V_SuiviReglements" AS
SELECT c."ID_Commande",
    c."CodeFacture",
    c."MontantTTC",
    COALESCE(SUM(r."MontantRegle"), 0::numeric) AS "TotalRegle",
    c."MontantTTC" - COALESCE(SUM(r."MontantRegle"), 0::numeric) AS "Reste"
FROM logistique."T_Commande" c
LEFT JOIN logistique."T_Reglements" r ON r."CodeFactureFk"::text = c."CodeFacture"::text
GROUP BY c."ID_Commande", c."CodeFacture", c."MontantTTC";


/* ============================================================================
   9. VERIFICATION RAPIDE
   ============================================================================ */

DO $$
BEGIN
    RAISE NOTICE 'Migration logistique terminee.';
    RAISE NOTICE 'Conseil : executer ensuite Logistique_Test.sql puis Logistique_Test_view.sql.';
END $$;

COMMIT;
