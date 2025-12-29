/* ============================================================================
   PROCEDURE : logistique.ps_update_qte_article
   OBJET :
     Appliquer une variation de stock sur logistique."T_Article"."QteArticle"
     pour un article donné, selon un opérateur :
       - '+' : entrée (augmentation du stock)
       - '-' : sortie (diminution du stock)

   SIGNATURE :
     (integer, numeric, character varying)

   PARAMÈTRES :
     p_id_article_fk : ID de l'article (logistique."T_Article"."ID_Article")
     p_qte           : quantité à ajouter/retirer (numeric)
     p_operateur     : '+' pour Entrée, '-' pour Sortie

   CONTRÔLES :
     - p_qte > 0
     - p_operateur ∈ { '+', '-' }
     - article existe
     - stock final ne peut pas devenir négatif
   ============================================================================ */

DROP PROCEDURE IF EXISTS logistique.ps_update_qte_article(
    integer, numeric, character varying
);

CREATE OR REPLACE PROCEDURE logistique.ps_update_qte_article(
    IN p_id_article_fk integer,
    IN p_qte           numeric,
    IN p_operateur     character varying
)
LANGUAGE plpgsql
AS $BODY$
DECLARE
    v_delta      numeric;
    v_operateur  varchar(1);
    v_new_stock  numeric;
BEGIN
    -- 1) Quantité valide ?
    IF p_qte IS NULL OR p_qte <= 0 THEN
        RAISE EXCEPTION
            'ps_update_qte_article : la quantité (p_qte=%) doit être un nombre strictement positif.',
            p_qte;
    END IF;

    -- 2) Normaliser et valider l''opérateur
    v_operateur := TRIM(p_operateur);

    IF v_operateur NOT IN ('+', '-') THEN
        RAISE EXCEPTION
            'ps_update_qte_article : opérateur invalide (p_operateur=%). Utilisez seulement ''+'' ou ''-''.',
            p_operateur;
    END IF;

    -- 3) Calcul du delta (+ ou -)
    v_delta := CASE
                   WHEN v_operateur = '+' THEN p_qte
                   WHEN v_operateur = '-' THEN -p_qte
               END;

    -- 4) Mise à jour de la quantité dans T_Article + récupération du stock final
    UPDATE logistique."T_Article"
    SET "QteArticle" = COALESCE("QteArticle", 0)::numeric + v_delta
    WHERE "ID_Article" = p_id_article_fk
    RETURNING "QteArticle" INTO v_new_stock;

    -- 5) Vérifier que l'article existe
    IF NOT FOUND THEN
        RAISE EXCEPTION
            'ps_update_qte_article : aucun article trouvé avec ID_Article=%.',
            p_id_article_fk;
    END IF;

    -- 6) Interdire stock négatif
    IF v_new_stock < 0 THEN
        RAISE EXCEPTION
            'ps_update_qte_article : la mise à jour ferait passer le stock de l''article % en négatif (stock final = %).',
            p_id_article_fk, v_new_stock;
    END IF;

    RAISE NOTICE
        'ps_update_qte_article : Article %, opérateur %, delta %, nouveau stock=%.',
        p_id_article_fk, v_operateur, v_delta, v_new_stock;
END;
$BODY$;

COMMENT ON PROCEDURE logistique.ps_update_qte_article(
    integer, numeric, character varying
)
    IS 'Applique une variation de stock (+ ou -) sur QteArticle pour un article, avec contrôles et interdiction du stock négatif.';


/* ============================================================================
   T_Article : ps_crud_article + tr_crud_article (VERSION AVEC ID_cmdFk PAR DÉFAUT)
   - Validation QteArticle (INSERT/UPDATE)
   - Création de mouvements de RAPPORT quand QteArticle change
       * ID_TypeMvtFk = ID_Generique ('Entrée' / 'Sortie')
       * ID_cmdFk     = ID_Commande de C_000E (Entrée) ou C_000S (Sortie)
         (créées automatiquement si elles n'existent pas)
   - Interdiction de supprimer un article lié à T_CommandeDetail ou T_Mouvement
   ============================================================================ */

-- 1) PROCEDURE : logistique.ps_crud_article
-- ------------------------------------------------------------

DROP PROCEDURE IF EXISTS logistique.ps_crud_article(
    integer, numeric, numeric, character varying
);

CREATE OR REPLACE PROCEDURE logistique.ps_crud_article(
    IN p_id_article integer,
    IN p_old_qte    numeric(100,7),
    IN p_new_qte    numeric(100,7),
    IN p_operation  character varying
)
LANGUAGE plpgsql
AS $BODY$
DECLARE
    v_op        text;
    v_new_qte   numeric(100,7);
BEGIN
    v_op := upper(trim(p_operation));
    v_new_qte := COALESCE(p_new_qte, 0)::numeric(100,7);

    /* =============================== INSERT =============================== */

    IF v_op = 'INSERT' THEN

        IF v_new_qte < 0 THEN
            RAISE EXCEPTION
                'ps_crud_article(INSERT) : QteArticle négative (=%) interdite pour ID_Article=%.',
                v_new_qte, p_id_article;
        END IF;

        RAISE NOTICE
            'ps_crud_article(INSERT) : Article %, QteArticle normalisée à %.',
            p_id_article, v_new_qte;

        RETURN;
    END IF;

    /* =============================== UPDATE =============================== */

    IF v_op = 'UPDATE' THEN

        IF v_new_qte < 0 THEN
            RAISE EXCEPTION
                'ps_crud_article(UPDATE) : QteArticle négative (=%) interdite pour ID_Article=% (ancienne=%).',
                v_new_qte, p_id_article, p_old_qte;
        END IF;

        IF p_old_qte IS NOT DISTINCT FROM v_new_qte THEN
            RAISE NOTICE
                'ps_crud_article(UPDATE) : QteArticle inchangée pour ID_Article=% (Qte=%).',
                p_id_article, v_new_qte;
            RETURN;
        END IF;

        RAISE NOTICE
            'ps_crud_article(UPDATE) : Article %, QteArticle % -> % (valeurs acceptées).',
            p_id_article, p_old_qte, v_new_qte;

        RETURN;
    END IF;

    /* =============================== DELETE =============================== */
    -- (rien ici, la logique DELETE est gérée dans le trigger pour vérifier les liens)

    /* ============================== AUTRES ================================ */

    RAISE NOTICE
        'ps_crud_article : opération non gérée [%] pour ID_Article=%.',
        v_op, p_id_article;
END;
$BODY$;

COMMENT ON PROCEDURE logistique.ps_crud_article(
    integer, numeric, numeric, character varying
)
    IS 'CRUD direct pour T_Article : contrôle QteArticle à l''INSERT/UPDATE (interdit les valeurs négatives).';


-- 2) FONCTION DE TRIGGER : logistique.tr_crud_article
-- ------------------------------------------------------------

DROP FUNCTION IF EXISTS logistique.tr_crud_article() CASCADE;

CREATE OR REPLACE FUNCTION logistique.tr_crud_article()
RETURNS trigger
LANGUAGE plpgsql
AS $BODY$
DECLARE
    v_new_qte       numeric(100,7);
    v_old_qte       numeric(100,7);
    v_delta         numeric(100,7);

    v_type_mvt      integer;  -- ID_Generique (Entrée / Sortie)
    v_abr_type_mvt  text;     -- AbrGenerique ('Entrée' / 'Sortie')
    v_qte_mvt       integer;

    v_code_cmd      text;     -- 'C_000E' ou 'C_000S'
    v_idCmdFk       integer;  -- ID_Commande pour C_000E / C_000S
BEGIN
    IF TG_OP = 'INSERT' THEN

        -- Normaliser QteArticle : NULL → 0
        v_new_qte := COALESCE(NEW."QteArticle", 0)::numeric(100,7);
        NEW."QteArticle" := v_new_qte;

        -- Validation métier
        CALL logistique.ps_crud_article(
            NEW."ID_Article",
            NULL,
            v_new_qte,
            'INSERT'
        );

        -- Mouvement de rapport : création initiale avec stock > 0
        IF v_new_qte > 0 THEN

            ----------------------------------------------------------------
            -- 1) Type de mouvement = 'Entrée' (ID_Generique)
            ----------------------------------------------------------------
            SELECT g."ID_Generique", g."AbrGenerique"
            INTO   v_type_mvt, v_abr_type_mvt
            FROM   referentiel."T_Generique" g
            WHERE  g."AbrGenerique" = 'Entrée'
            LIMIT  1;

            IF v_type_mvt IS NULL THEN
                RAISE EXCEPTION
                    'tr_crud_article(INSERT) : aucun type de mouvement trouvé pour AbrGenerique = ''Entrée'' dans referentiel."T_Generique".';
            END IF;

            ----------------------------------------------------------------
            -- 2) Commande par défaut pour les Entrées : CodeCmd = 'C_000E'
            ----------------------------------------------------------------
            v_code_cmd := 'C_000E';

            SELECT "ID_Commande"
            INTO   v_idCmdFk
            FROM   logistique."T_Commande"
            WHERE  "CodeCmd" = v_code_cmd
            LIMIT  1;

            IF v_idCmdFk IS NULL THEN
                INSERT INTO logistique."T_Commande" (
                    "ID_TypeCmdFk",
                    "DateHeureAutoCmd",
                    "DateCmd",
                    "CodeCmd",
                    "ObsCmd",
                    "SelectCmd"
                )
                VALUES (
                    NULL,                 -- ou v_type_mvt si tu veux typer
                    now(),
                    now(),
                    v_code_cmd,
                    'Commande système auto-générée pour mouvements de rapport (Entrée) T_Article',
                    FALSE
                )
                RETURNING "ID_Commande" INTO v_idCmdFk;
            END IF;

            ----------------------------------------------------------------
            -- 3) Création du mouvement de rapport lié à cette commande
            ----------------------------------------------------------------
            v_qte_mvt  := v_new_qte::integer;

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
                v_type_mvt,                 -- *** INTEGER : ID_Generique ***
                NEW."ID_Article",
                v_idCmdFk,                  -- *** JAMAIS NULL : C_000E ***
                now(),
                now(),
                v_qte_mvt,
                COALESCE(NEW."PVArticle", 0)
            );

            RAISE NOTICE
                'tr_crud_article(INSERT) : Mouvement de rapport créé pour Article %, Type % (Abr=%), Qte %, Cmd=%, ID_cmdFk=%.',
                NEW."ID_Article", v_type_mvt, v_abr_type_mvt, v_qte_mvt, v_code_cmd, v_idCmdFk;
        END IF;

        RETURN NEW;


    ELSIF TG_OP = 'UPDATE' THEN

        v_old_qte := COALESCE(OLD."QteArticle", 0)::numeric(100,7);
        v_new_qte := COALESCE(NEW."QteArticle", 0)::numeric(100,7);
        NEW."QteArticle" := v_new_qte;

        -- Validation métier
        CALL logistique.ps_crud_article(
            NEW."ID_Article",
            v_old_qte,
            v_new_qte,
            'UPDATE'
        );

        -- Mouvement de rapport si changement de quantité
        v_delta := v_new_qte - v_old_qte;

        IF v_delta <> 0 THEN

            IF v_delta > 0 THEN
                ----------------------------------------------------------------
                -- AUGMENTATION de stock → type 'Entrée' + commande C_000E
                ----------------------------------------------------------------
                SELECT g."ID_Generique", g."AbrGenerique"
                INTO   v_type_mvt, v_abr_type_mvt
                FROM   referentiel."T_Generique" g
                WHERE  g."AbrGenerique" = 'Entrée'
                LIMIT  1;

                IF v_type_mvt IS NULL THEN
                    RAISE EXCEPTION
                        'tr_crud_article(UPDATE) : aucun type de mouvement trouvé pour AbrGenerique = ''Entrée'' dans referentiel."T_Generique".';
                END IF;

                v_qte_mvt := v_delta::integer;
                v_code_cmd := 'C_000E';

            ELSE
                ----------------------------------------------------------------
                -- DIMINUTION de stock → type 'Sortie' + commande C_000S
                ----------------------------------------------------------------
                SELECT g."ID_Generique", g."AbrGenerique"
                INTO   v_type_mvt, v_abr_type_mvt
                FROM   referentiel."T_Generique" g
                WHERE  g."AbrGenerique" = 'Sortie'
                LIMIT  1;

                IF v_type_mvt IS NULL THEN
                    RAISE EXCEPTION
                        'tr_crud_article(UPDATE) : aucun type de mouvement trouvé pour AbrGenerique = ''Sortie'' dans referentiel."T_Generique".';
                END IF;

                v_qte_mvt := (-v_delta)::integer;
                v_code_cmd := 'C_000S';
            END IF;

            ----------------------------------------------------------------
            -- Chercher / créer la commande par défaut (C_000E ou C_000S)
            ----------------------------------------------------------------
            SELECT "ID_Commande"
            INTO   v_idCmdFk
            FROM   logistique."T_Commande"
            WHERE  "CodeCmd" = v_code_cmd
            LIMIT  1;

            IF v_idCmdFk IS NULL THEN
                INSERT INTO logistique."T_Commande" (
                    "ID_TypeCmdFk",
                    "DateHeureAutoCmd",
                    "DateCmd",
                    "CodeCmd",
                    "ObsCmd",
                    "SelectCmd"
                )
                VALUES (
                    NULL,                 -- ou v_type_mvt si tu préfères
                    now(),
                    now(),
                    v_code_cmd,
                    'Commande système auto-générée pour mouvements de rapport (Sortie/Entrée) T_Article',
                    FALSE
                )
                RETURNING "ID_Commande" INTO v_idCmdFk;
            END IF;

            ----------------------------------------------------------------
            -- Création du mouvement de rapport
            ----------------------------------------------------------------
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
                v_type_mvt,                 -- *** INTEGER : ID_Generique ***
                NEW."ID_Article",
                v_idCmdFk,                  -- *** JAMAIS NULL : C_000E / C_000S ***
                now(),
                now(),
                v_qte_mvt,
                COALESCE(NEW."PVArticle", 0)
            );

            RAISE NOTICE
                'tr_crud_article(UPDATE) : Mouvement de rapport créé pour Article %, Type % (Abr=%), Qte % (old=%, new=%), Cmd=%, ID_cmdFk=%.',
                NEW."ID_Article", v_type_mvt, v_abr_type_mvt,
                v_qte_mvt, v_old_qte, v_new_qte, v_code_cmd, v_idCmdFk;
        END IF;

        RETURN NEW;


    ELSIF TG_OP = 'DELETE' THEN
        ----------------------------------------------------------------
        -- Interdire la suppression si l'article est lié à CommandeDetail ou Mouvement
        ----------------------------------------------------------------
        IF EXISTS (
            SELECT 1
            FROM logistique."T_CommandeDetail" cd
            WHERE cd."ID_ArticleFk" = OLD."ID_Article"
        ) THEN
            RAISE EXCEPTION
                'tr_crud_article(DELETE) : suppression interdite, article % lié à T_CommandeDetail.',
                OLD."ID_Article";
        END IF;

        IF EXISTS (
            SELECT 1
            FROM logistique."T_Mouvement" m
            WHERE m."ID_ArticleFk" = OLD."ID_Article"
        ) THEN
            RAISE EXCEPTION
                'tr_crud_article(DELETE) : suppression interdite, article % lié à T_Mouvement.',
                OLD."ID_Article";
        END IF;

        RETURN OLD;

    ELSE
        RETURN NEW;
    END IF;
END;
$BODY$;

COMMENT ON FUNCTION logistique.tr_crud_article()
    IS 'Trigger BEFORE sur T_Article : contrôle QteArticle + crée des mouvements de rapport (ID_Generique Entrée/Sortie) avec ID_cmdFk pointant vers C_000E / C_000S + interdit le DELETE si article lié.';


-- 3) TRIGGER : tr_crud_article
-- ------------------------------------------------------------

DROP TRIGGER IF EXISTS tr_crud_article ON logistique."T_Article";

CREATE TRIGGER tr_crud_article
BEFORE INSERT OR UPDATE OR DELETE
ON logistique."T_Article"
FOR EACH ROW
EXECUTE FUNCTION logistique.tr_crud_article();

COMMENT ON TRIGGER tr_crud_article ON logistique."T_Article"
    IS 'Before INSERT/UPDATE/DELETE sur T_Article → tr_crud_article → ps_crud_article, création de mouvements de rapport avec commande par défaut (C_000E / C_000S), contrôle liens avant suppression.';
