/* ============================================================================
   T_CommandeDetail : ps_crud_commandeDetail + tr_crud_commandeDetail
   RÔLE :
     - T_CommandeDetail pilote directement le stock T_Article.QteArticle
       via ps_update_qte_article.
     - T_Mouvement sert d'inventaire / journal des mouvements.
   ============================================================================ */

DROP PROCEDURE IF EXISTS logistique.ps_crud_commandeDetail(
    integer, integer, numeric,
    integer, integer, numeric,
    character varying
);

CREATE OR REPLACE PROCEDURE logistique.ps_crud_commandeDetail(
    IN p_old_cmd_fk      integer,
    IN p_old_article_fk  integer,
    IN p_old_qte         numeric,
    IN p_new_cmd_fk      integer,
    IN p_new_article_fk  integer,
    IN p_new_qte         numeric,
    IN p_operation       character varying
)
LANGUAGE plpgsql
AS $BODY$
DECLARE
    v_op                text;

    -- Pour les types Entrée/Sortie (via T_Commande + T_Generique)
    v_old_type_cmd_id   integer;
    v_old_abr_type      text;   -- 'Entrée' / 'Sortie'
    v_new_type_cmd_id   integer;
    v_new_abr_type      text;   -- 'Entrée' / 'Sortie'

    v_oper_stock_old    varchar(1);  -- '+' ou '-'
    v_oper_stock_new    varchar(1);  -- '+' ou '-'

    v_pu_mvt            integer;
BEGIN
    v_op := upper(trim(p_operation));

    /* =============================== INSERT =============================== */

    IF v_op = 'INSERT' THEN

        IF p_new_qte IS NULL OR p_new_qte <= 0 THEN
            RAISE EXCEPTION
                'ps_crud_commandeDetail(INSERT) : QteCmdDetail invalide (=%) pour Cmd %, Art %.',
                p_new_qte, p_new_cmd_fk, p_new_article_fk;
        END IF;

        -- 1) Récupérer le type de commande (ID_TypeCmdFk + AbrGenerique)
        SELECT c."ID_TypeCmdFk", g."AbrGenerique"
        INTO   v_new_type_cmd_id, v_new_abr_type
        FROM   logistique."T_Commande" c
        JOIN   referentiel."T_Generique" g
               ON c."ID_TypeCmdFk" = g."ID_Generique"
        WHERE  c."ID_Commande" = p_new_cmd_fk
        LIMIT  1;

        IF NOT FOUND THEN
            RAISE EXCEPTION
                'ps_crud_commandeDetail(INSERT) : aucun type de commande trouvé pour ID_Commande=%.',
                p_new_cmd_fk;
        END IF;

        -- 2) Déterminer le sens stock
        IF v_new_abr_type = 'Entrée' THEN
            v_oper_stock_new := '+';
        ELSIF v_new_abr_type = 'Sortie' THEN
            v_oper_stock_new := '-';
        ELSE
            RAISE EXCEPTION
                'ps_crud_commandeDetail(INSERT) : AbrGenerique inattendu (%) pour ID_TypeCmdFk=%. Attendu : ''Entrée'' ou ''Sortie''.',
                v_new_abr_type, v_new_type_cmd_id;
        END IF;

        -- 3) Mettre à jour le stock de T_Article
        CALL logistique.ps_update_qte_article(
            p_new_article_fk,
            p_new_qte,
            v_oper_stock_new
        );

        -- 4) Prix unitaire mouvement (PVArticle par défaut)
        SELECT COALESCE("PVArticle", 0)
        INTO   v_pu_mvt
        FROM   logistique."T_Article"
        WHERE  "ID_Article" = p_new_article_fk;

        IF NOT FOUND OR v_pu_mvt IS NULL THEN
            v_pu_mvt := 0;
        END IF;

        -- 5) Créer le mouvement d'inventaire
        INSERT INTO logistique."T_Mouvement" (
            "ID_TypeMvtFk",   -- même type que commande, INTEGER (ID_Generique)
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
            now(),
            now(),
            p_new_qte::integer,
            v_pu_mvt
        );

        RAISE NOTICE
            'ps_crud_commandeDetail(INSERT) : Cmd %, Art %, TypeCmd %, Abr %, Qte %, OpStock %, stock mis à jour + mouvement créé.',
            p_new_cmd_fk, p_new_article_fk,
            v_new_type_cmd_id, v_new_abr_type,
            p_new_qte, v_oper_stock_new;

        RETURN;
    END IF;

    /* =============================== UPDATE =============================== */

    IF v_op = 'UPDATE' THEN

        -- Si rien n'a changé, on ne fait rien
        IF p_old_cmd_fk     IS NOT DISTINCT FROM p_new_cmd_fk
           AND p_old_article_fk IS NOT DISTINCT FROM p_new_article_fk
           AND p_old_qte     IS NOT DISTINCT FROM p_new_qte THEN

            RAISE NOTICE
                'ps_crud_commandeDetail(UPDATE) : aucune modification impactant stock et mouvements.';
            RETURN;
        END IF;

        IF p_new_qte IS NULL OR p_new_qte <= 0 THEN
            RAISE EXCEPTION
                'ps_crud_commandeDetail(UPDATE) : nouvelle QteCmdDetail invalide (=%) pour Cmd %, Art %.',
                p_new_qte, p_new_cmd_fk, p_new_article_fk;
        END IF;

        /* ---- 1) ANNULER L’EFFET DE L’ANCIENNE LIGNE ---- */

        IF p_old_cmd_fk IS NOT NULL
           AND p_old_article_fk IS NOT NULL
           AND p_old_qte IS NOT NULL
        THEN
            SELECT c."ID_TypeCmdFk", g."AbrGenerique"
            INTO   v_old_type_cmd_id, v_old_abr_type
            FROM   logistique."T_Commande" c
            JOIN   referentiel."T_Generique" g
                   ON c."ID_TypeCmdFk" = g."ID_Generique"
            WHERE  c."ID_Commande" = p_old_cmd_fk
            LIMIT  1;

            IF NOT FOUND THEN
                RAISE EXCEPTION
                    'ps_crud_commandeDetail(UPDATE) : aucun type de commande trouvé pour ancienne Cmd=%.',
                    p_old_cmd_fk;
            END IF;

            -- Pour annuler l'effet :
            --  - si ancienne commande = Entrée : on fait une Sortie (op '-')
            --  - si ancienne commande = Sortie : on fait une Entrée (op '+')
            IF v_old_abr_type = 'Entrée' THEN
                v_oper_stock_old := '-';
            ELSIF v_old_abr_type = 'Sortie' THEN
                v_oper_stock_old := '+';
            ELSE
                RAISE EXCEPTION
                    'ps_crud_commandeDetail(UPDATE) : AbrGenerique ancien inattendu (%) pour ID_TypeCmdFk=%.',
                    v_old_abr_type, v_old_type_cmd_id;
            END IF;

            CALL logistique.ps_update_qte_article(
                p_old_article_fk,
                p_old_qte,
                v_oper_stock_old
            );

            -- Supprimer les mouvements correspondant à l'ancien couple (Cmd, Article)
            DELETE FROM logistique."T_Mouvement"
            WHERE "ID_cmdFk"     = p_old_cmd_fk
              AND "ID_ArticleFk" = p_old_article_fk;
        END IF;

        /* ---- 2) APPLIQUER L’EFFET DE LA NOUVELLE LIGNE (COMME UN INSERT) ---- */

        SELECT c."ID_TypeCmdFk", g."AbrGenerique"
        INTO   v_new_type_cmd_id, v_new_abr_type
        FROM   logistique."T_Commande" c
        JOIN   referentiel."T_Generique" g
               ON c."ID_TypeCmdFk" = g."ID_Generique"
        WHERE  c."ID_Commande" = p_new_cmd_fk
        LIMIT  1;

        IF NOT FOUND THEN
            RAISE EXCEPTION
                'ps_crud_commandeDetail(UPDATE) : aucun type de commande trouvé pour nouvelle Cmd=%.',
                p_new_cmd_fk;
        END IF;

        IF v_new_abr_type = 'Entrée' THEN
            v_oper_stock_new := '+';
        ELSIF v_new_abr_type = 'Sortie' THEN
            v_oper_stock_new := '-';
        ELSE
            RAISE EXCEPTION
                'ps_crud_commandeDetail(UPDATE) : AbrGenerique nouveau inattendu (%) pour ID_TypeCmdFk=%.',
                v_new_abr_type, v_new_type_cmd_id;
        END IF;

        CALL logistique.ps_update_qte_article(
            p_new_article_fk,
            p_new_qte,
            v_oper_stock_new
        );

        SELECT COALESCE("PVArticle", 0)
        INTO   v_pu_mvt
        FROM   logistique."T_Article"
        WHERE  "ID_Article" = p_new_article_fk;

        IF NOT FOUND OR v_pu_mvt IS NULL THEN
            v_pu_mvt := 0;
        END IF;

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
            now(),
            now(),
            p_new_qte::integer,
            v_pu_mvt
        );

        RAISE NOTICE
            'ps_crud_commandeDetail(UPDATE) : Cmd_old %, Art_old %, Qte_old %, Cmd_new %, Art_new %, Qte_new %, stock corrigé + mouvement recréé.',
            p_old_cmd_fk, p_old_article_fk, p_old_qte,
            p_new_cmd_fk, p_new_article_fk, p_new_qte;

        RETURN;
    END IF;

    /* =============================== DELETE =============================== */

    IF v_op = 'DELETE' THEN

        IF p_old_cmd_fk IS NULL
           OR p_old_article_fk IS NULL
           OR p_old_qte IS NULL THEN
            RAISE EXCEPTION
                'ps_crud_commandeDetail(DELETE) : paramètres OLD incomplets (Cmd %, Art %, Qte %).',
                p_old_cmd_fk, p_old_article_fk, p_old_qte;
        END IF;

        -- 1) Récupérer le type de commande pour l'ancienne commande
        SELECT c."ID_TypeCmdFk", g."AbrGenerique"
        INTO   v_old_type_cmd_id, v_old_abr_type
        FROM   logistique."T_Commande" c
        JOIN   referentiel."T_Generique" g
               ON c."ID_TypeCmdFk" = g."ID_Generique"
        WHERE  c."ID_Commande" = p_old_cmd_fk
        LIMIT  1;

        IF NOT FOUND THEN
            RAISE EXCEPTION
                'ps_crud_commandeDetail(DELETE) : aucun type de commande trouvé pour Cmd=%.',
                p_old_cmd_fk;
        END IF;

        -- 2) Pour annuler l'effet :
        --    - si commande = Entrée : on fait une Sortie (op '-')
        --    - si commande = Sortie : on fait une Entrée (op '+')
        IF v_old_abr_type = 'Entrée' THEN
            v_oper_stock_old := '-';
        ELSIF v_old_abr_type = 'Sortie' THEN
            v_oper_stock_old := '+';
        ELSE
            RAISE EXCEPTION
                'ps_crud_commandeDetail(DELETE) : AbrGenerique inattendu (%) pour ID_TypeCmdFk=%.',
                v_old_abr_type, v_old_type_cmd_id;
        END IF;

        -- 3) Corriger le stock
        CALL logistique.ps_update_qte_article(
            p_old_article_fk,
            p_old_qte,
            v_oper_stock_old
        );

        -- 4) Supprimer les mouvements correspondants
        DELETE FROM logistique."T_Mouvement"
        WHERE "ID_cmdFk"     = p_old_cmd_fk
          AND "ID_ArticleFk" = p_old_article_fk;

        RAISE NOTICE
            'ps_crud_commandeDetail(DELETE) : Cmd %, Art %, Qte %, Abr %, opérateur %, stock corrigé + mouvements supprimés.',
            p_old_cmd_fk, p_old_article_fk, p_old_qte,
            v_old_abr_type, v_oper_stock_old;

        RETURN;
    END IF;

    /* ============================== AUTRES ================================ */

    RAISE NOTICE
        'ps_crud_commandeDetail : opération non gérée [%].',
        v_op;
END;
$BODY$;

COMMENT ON PROCEDURE logistique.ps_crud_commandeDetail(
    integer, integer, numeric,
    integer, integer, numeric,
    character varying
)
    IS 'CRUD logique complet pour T_CommandeDetail : INSERT/UPDATE/DELETE → MAJ stock (T_Article) + inventaire (T_Mouvement).';


DROP FUNCTION IF EXISTS logistique.tr_crud_commandeDetail() CASCADE;

CREATE OR REPLACE FUNCTION logistique.tr_crud_commandeDetail()
RETURNS trigger
LANGUAGE plpgsql
AS $BODY$
BEGIN
    IF TG_OP = 'INSERT' THEN

        CALL logistique.ps_crud_commandeDetail(
            NULL,
            NULL,
            NULL,
            NEW."ID_CmdFk",
            NEW."ID_ArticleFk",
            NEW."QteCmdDetail",
            'INSERT'
        );
        RETURN NEW;

    ELSIF TG_OP = 'UPDATE' THEN

        CALL logistique.ps_crud_commandeDetail(
            OLD."ID_CmdFk",
            OLD."ID_ArticleFk",
            OLD."QteCmdDetail",
            NEW."ID_CmdFk",
            NEW."ID_ArticleFk",
            NEW."QteCmdDetail",
            'UPDATE'
        );
        RETURN NEW;

    ELSIF TG_OP = 'DELETE' THEN

        CALL logistique.ps_crud_commandeDetail(
            OLD."ID_CmdFk",
            OLD."ID_ArticleFk",
            OLD."QteCmdDetail",
            NULL,
            NULL,
            NULL,
            'DELETE'
        );
        RETURN OLD;

    ELSE
        RETURN NEW;
    END IF;
END;
$BODY$;

COMMENT ON FUNCTION logistique.tr_crud_commandeDetail()
    IS 'Trigger sur T_CommandeDetail : délègue INSERT/UPDATE/DELETE à ps_crud_commandeDetail (stock + mouvements).';


DROP TRIGGER IF EXISTS tr_crud_commandedetail   ON logistique."T_CommandeDetail";
DROP TRIGGER IF EXISTS tr_crud_commandeDetail   ON logistique."T_CommandeDetail";
DROP TRIGGER IF EXISTS tr_delete_commandedetail ON logistique."T_CommandeDetail";

CREATE TRIGGER tr_crud_commandeDetail
AFTER INSERT OR UPDATE
ON logistique."T_CommandeDetail"
FOR EACH ROW
EXECUTE FUNCTION logistique.tr_crud_commandeDetail();

CREATE TRIGGER tr_delete_commandeDetail
BEFORE DELETE
ON logistique."T_CommandeDetail"
FOR EACH ROW
EXECUTE FUNCTION logistique.tr_crud_commandeDetail();
