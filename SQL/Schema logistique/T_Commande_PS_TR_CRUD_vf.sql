/* ============================================================================
   T_Commande : ps_crud_commande + tr_crud_commande

   RÔLE :
     - INSERT : pour l'instant simple NOTICE (hook si tu veux ajouter des règles)
     - UPDATE : si changement de ID_TypeCmdFk →
                  met à jour T_Mouvement."ID_TypeMvtFk" = nouveau ID_TypeCmdFk
                (en supposant que ID_TypeMvtFk est INTEGER référant à T_Generique)
     - DELETE : supprimé "proprement" via les détails :
                  1) DELETE FROM T_CommandeDetail
                     → déclenche tr_delete_commandeDetail (BEFORE DELETE)
                        → ps_crud_commandeDetail('DELETE')
                           - restitue le stock via ps_update_qte_article
                           - supprime les mouvements liés
                  2) DELETE FROM T_Commande
   ============================================================================ */

-- 1) PROCEDURE : logistique.ps_crud_commande
-- ------------------------------------------------------------

DROP PROCEDURE IF EXISTS logistique.ps_crud_commande(
    integer, integer, integer, character varying
);

CREATE OR REPLACE PROCEDURE logistique.ps_crud_commande(
    IN p_id_commande     integer,
    IN p_old_id_type_cmd integer,
    IN p_new_id_type_cmd integer,
    IN p_operation       character varying
)
LANGUAGE plpgsql
AS $BODY$
DECLARE
    v_op   text;
BEGIN
    v_op := upper(trim(p_operation));

    /* =============================== INSERT =============================== */

    IF v_op = 'INSERT' THEN

        -- Option : vérifier que le type de commande existe bien
        IF p_new_id_type_cmd IS NOT NULL THEN
            PERFORM 1
            FROM   referentiel."T_Generique" g
            WHERE  g."ID_Generique" = p_new_id_type_cmd;

            IF NOT FOUND THEN
                RAISE EXCEPTION
                    'ps_crud_commande(INSERT) : ID_TypeCmdFk=% introuvable dans referentiel."T_Generique".',
                    p_new_id_type_cmd;
            END IF;
        END IF;

        RAISE NOTICE
            'ps_crud_commande(INSERT) : commande % (ID_TypeCmdFk=%).',
            p_id_commande, p_new_id_type_cmd;

        RETURN;
    END IF;

    /* =============================== UPDATE =============================== */

    IF v_op = 'UPDATE' THEN

        -- Si le type n'a pas changé, rien à faire
        IF p_old_id_type_cmd IS NOT DISTINCT FROM p_new_id_type_cmd THEN
            RAISE NOTICE
                'ps_crud_commande(UPDATE) : type de commande inchangé pour commande %.',
                p_id_commande;
            RETURN;
        END IF;

        -- Vérifier que le nouveau type existe bien
        IF p_new_id_type_cmd IS NULL THEN
            RAISE EXCEPTION
                'ps_crud_commande(UPDATE) : nouveau ID_TypeCmdFk NULL pour commande %.',
                p_id_commande;
        END IF;

        PERFORM 1
        FROM   referentiel."T_Generique" g
        WHERE  g."ID_Generique" = p_new_id_type_cmd;

        IF NOT FOUND THEN
            RAISE EXCEPTION
                'ps_crud_commande(UPDATE) : ID_TypeCmdFk=% introuvable dans referentiel."T_Generique".',
                p_new_id_type_cmd;
        END IF;

        -- Mettre à jour le type de mouvement dans T_Mouvement
        UPDATE logistique."T_Mouvement"
        SET "ID_TypeMvtFk" = p_new_id_type_cmd   -- INTEGER = ID_Generique
        WHERE "ID_cmdFk"   = p_id_commande;

        RAISE NOTICE
            'ps_crud_commande(UPDATE) : commande % changée de type (% -> %), mouvements mis à jour avec ID_TypeMvtFk=%.',
            p_id_commande, p_old_id_type_cmd, p_new_id_type_cmd, p_new_id_type_cmd;

        RETURN;
    END IF;

    /* =============================== DELETE =============================== */

    IF v_op = 'DELETE' THEN

        -- 1) Vérifier que la commande existe encore
        PERFORM 1
        FROM logistique."T_Commande"
        WHERE "ID_Commande" = p_id_commande;

        IF NOT FOUND THEN
            RAISE NOTICE
                'ps_crud_commande(DELETE) : aucune commande trouvée avec ID_Commande=%.',
                p_id_commande;
            RETURN;
        END IF;

        -- 2) Supprimer les détails :
        --    → déclenche le BEFORE DELETE tr_delete_commandeDetail
        --      qui :
        --        - ajuste le stock via ps_update_qte_article
        --        - supprime les mouvements correspondants
        DELETE FROM logistique."T_CommandeDetail"
        WHERE "ID_CmdFk" = p_id_commande;


        -- 3) Sécurité : supprimer tout mouvement restant lié à cette commande
        --    (par ex. mouvements saisis manuellement, non liés à un détail)
        DELETE FROM logistique."T_Mouvement"
        WHERE "ID_cmdFk" = p_id_commande;

        -- 4) Supprimer la commande elle-même
        DELETE FROM logistique."T_Commande"
        WHERE "ID_Commande" = p_id_commande;

        RAISE NOTICE
            'ps_crud_commande(DELETE) : commande % et ses détails supprimés (stock corrigé via triggers sur T_CommandeDetail).',
            p_id_commande;

        RETURN;
    END IF;

    /* ============================== AUTRES ================================ */

    RAISE NOTICE
        'ps_crud_commande : opération non gérée [%] pour commande %.',
        v_op, p_id_commande;
END;
$BODY$;

COMMENT ON PROCEDURE logistique.ps_crud_commande(integer, integer, integer, character varying)
    IS 'Procédure centrale CRUD logique pour T_Commande : INSERT/UPDATE via trigger, DELETE métier (supprime détails → triggers corrigent le stock → supprime la commande).';


/* ============================================================================
   FONCTION DE TRIGGER : logistique.tr_crud_commande
   TABLE :
     logistique."T_Commande"
   OBJET :
     Déléguer INSERT / UPDATE à ps_crud_commande.
   ============================================================================ */

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
            'INSERT'
        );
        RETURN NEW;

    ELSIF TG_OP = 'UPDATE' THEN

        CALL logistique.ps_crud_commande(
            NEW."ID_Commande",
            OLD."ID_TypeCmdFk",
            NEW."ID_TypeCmdFk",
            'UPDATE'
        );
        RETURN NEW;

    ELSE
        RETURN NEW;
    END IF;
END;
$BODY$;

COMMENT ON FUNCTION logistique.tr_crud_commande()
    IS 'Trigger logique sur T_Commande : délègue INSERT/UPDATE à ps_crud_commande.';


/* ============================================================================
   TRIGGER : tr_crud_commande
   TABLE :
     logistique."T_Commande"
   ============================================================================ */

DROP TRIGGER IF EXISTS tr_crud_commande ON logistique."T_Commande";

CREATE TRIGGER tr_crud_commande
AFTER INSERT OR UPDATE
ON logistique."T_Commande"
FOR EACH ROW
EXECUTE FUNCTION logistique.tr_crud_commande();

COMMENT ON TRIGGER tr_crud_commande ON logistique."T_Commande"
    IS 'After INSERT/UPDATE sur T_Commande → tr_crud_commande → ps_crud_commande.';
