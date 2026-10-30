-- Extrait canonique du catalogue installé le 30/10/2026, sans données ni propriétaires imposés.
-- Voir SQL/README.md. Ces extraits documentent le domaine ; utiliser le fichier global pour une installation vide.
SET check_function_bodies = false;
SELECT pg_catalog.set_config('search_path', '', false);
CREATE SCHEMA IF NOT EXISTS "operations";
--
-- Name: SCHEMA operations; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA operations IS 'Paiements, archives et caisses par entité et devise, avec routines de mouvement, notification et contrôle.';

--
-- Name: archive_paiements(); Type: FUNCTION; Schema: operations; Owner: -
--

CREATE FUNCTION operations.archive_paiements() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO operations."T_Paiement_Archive" (
        "IdPaiement",
        "CodePaiement",
        "IdUserFk",
        "IdTypePaiementFk",
        "MontantPaiement",
        "IdStatutPaiementFk",
        "DatePaiement",
        "ObsPaiement",
        "ValidePaiement",
        "IdDeviseFk",
        "IdPayeurFk",
        "IdTypeMouvementFk",
        "DateArchivage",
        "IdEntiteFk"
    )
    SELECT
        p."IdPaiement",
        p."CodePaiement",
        p."IdUserFk",
        p."IdTypePaiementFk",
        p."MontantPaiement",
        p."IdStatutPaiementFk",
        p."DatePaiement",
        p."ObsPaiement",
        p."ValidePaiement",
        p."IdDeviseFk",
        p."IdPayeurFk",
        p."IdTypeMouvementFk",
        NOW() AS "DateArchivage",
        p."IdEntiteFk"
    FROM operations."T_Paiement" p
    WHERE p."DatePaiement" < NOW() - INTERVAL '2 years';

    DELETE FROM operations."T_Paiement"
    WHERE "DatePaiement" < NOW() - INTERVAL '2 years';

    RETURN NULL;
END;
$$;

--
-- Name: FUNCTION archive_paiements(); Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON FUNCTION operations.archive_paiements() IS 'Après INSERT/UPDATE sur T_Paiement, copie les paiements âgés de plus de deux ans dans T_Paiement_Archive, puis les supprime de la table active. Déclenchement par instruction, sans planification périodique ; les triggers de suppression de la table active restent applicables.';

--
-- Name: fn_audit_caisse(integer, integer, timestamp without time zone); Type: FUNCTION; Schema: operations; Owner: -
--

CREATE FUNCTION operations.fn_audit_caisse(p_id_entite integer DEFAULT NULL::integer, p_id_devise integer DEFAULT NULL::integer, p_date_max timestamp without time zone DEFAULT NULL::timestamp without time zone) RETURNS TABLE("IdEntite" integer, "NomEntite" character varying, "IdDevise" integer, "NomDevise" character varying, "SoldeCaisse" numeric, "SoldeTheorique" numeric, "Ecart" numeric, "NbPaiements" integer, "MontantEntree" numeric, "MontantSortie" numeric)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    WITH paiements_union AS (
        -- Unification paiements actifs + archivés, avec filtre sur date si fourni
        SELECT
            p."IdDeviseFk"       AS IdDevise,
            p."IdEntiteFk"       AS IdEntite,
            p."IdTypeMouvementFk",
            p."MontantPaiement",
            p."IdStatutPaiementFk",
            p."DatePaiement"
        FROM operations."T_Paiement" p

        UNION ALL

        SELECT
            pa."IdDeviseFk"      AS IdDevise,
            pa."IdEntiteFk"      AS IdEntite,
            pa."IdTypeMouvementFk",
            pa."MontantPaiement",
            pa."IdStatutPaiementFk",
            pa."DatePaiement"
        FROM operations."T_Paiement_Archive" pa
    ),
    flux AS (
        SELECT
            u.IdDevise,
            u.IdEntite,
            COUNT(*) FILTER (
                WHERE u."IdStatutPaiementFk" = 21
                  AND u."IdTypeMouvementFk" IN (80, 81)
                  AND u."IdDevise" IN (36, 37)
            )                          AS nb_paiements,
            SUM(
                CASE
                    WHEN u."IdStatutPaiementFk" = 21
                     AND u."IdTypeMouvementFk" = 81
                     AND u."IdDevise" IN (36, 37)
                        AND (p_date_max IS NULL OR u."DatePaiement" <= p_date_max)
                        THEN u."MontantPaiement"
                    ELSE 0
                END
            )                          AS montant_entree,
            SUM(
                CASE
                    WHEN u."IdStatutPaiementFk" = 21
                     AND u."IdTypeMouvementFk" = 80
                     AND u."IdDevise" IN (36, 37)
                        AND (p_date_max IS NULL OR u."DatePaiement" <= p_date_max)
                        THEN u."MontantPaiement"
                    ELSE 0
                END
            )                          AS montant_sortie
        FROM paiements_union u
        WHERE (p_id_entite IS NULL OR u.IdEntite = p_id_entite)
          AND (p_id_devise IS NULL OR u.IdDevise = p_id_devise)
        GROUP BY
            u.IdDevise,
            u.IdEntite
    )
    SELECT
        ent."IdEntite"                    AS "IdEntite",
        ent."NomEntite"                   AS "NomEntite",
        dev."ID_Generique"                AS "IdDevise",
        dev."NomGenerique"                AS "NomDevise",

        COALESCE(c."MontantCaisse", 0)::numeric                        AS "SoldeCaisse",

        COALESCE(
            (COALESCE(f.montant_entree, 0) - COALESCE(f.montant_sortie, 0)),
            0
        )::numeric                                                     AS "SoldeTheorique",

        COALESCE(c."MontantCaisse", 0)::numeric
          - COALESCE(
                (COALESCE(f.montant_entree, 0) - COALESCE(f.montant_sortie, 0)),
                0
            )::numeric                                                 AS "Ecart",

        COALESCE(f.nb_paiements, 0)::integer                           AS "NbPaiements",
        COALESCE(f.montant_entree, 0)::numeric                         AS "MontantEntree",
        COALESCE(f.montant_sortie, 0)::numeric                         AS "MontantSortie"

    FROM operations."T_Caisse" c
    LEFT JOIN flux f
           ON f.IdDevise = c."IdDeviseFk"
          AND f.IdEntite = c."IdEntiteFk"
    LEFT JOIN referentiel."T_Generique" dev
           ON dev."ID_Generique" = c."IdDeviseFk"
    LEFT JOIN systeme."T_Entite" ent
           ON ent."IdEntite" = c."IdEntiteFk"
    WHERE (p_id_entite IS NULL OR c."IdEntiteFk" = p_id_entite)
      AND (p_id_devise IS NULL OR c."IdDeviseFk" = p_id_devise)
    ORDER BY
        ent."NomEntite",
        dev."NomGenerique";
END;
$$;

--
-- Name: FUNCTION fn_audit_caisse(p_id_entite integer, p_id_devise integer, p_date_max timestamp without time zone); Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON FUNCTION operations.fn_audit_caisse(p_id_entite integer, p_id_devise integer, p_date_max timestamp without time zone) IS 'Lecture de rapprochement par caisse entité/devise entre solde courant et flux de T_Paiement UNION ALL T_Paiement_Archive. La définition utilise les identifiants fixes statut 21, entrée 81, sortie 80 et devises 36/37 ; p_date_max borne les sommes, pas le compteur. Ne reconstitue pas le solde courant à une date passée et ne partage pas exactement les critères de gestion_caisse_on_paiement.';

--
-- Name: fn_audit_flux_caisse(integer, integer, timestamp without time zone, timestamp without time zone); Type: FUNCTION; Schema: operations; Owner: -
--

CREATE FUNCTION operations.fn_audit_flux_caisse(p_id_entite integer DEFAULT NULL::integer, p_id_devise integer DEFAULT NULL::integer, p_date_min timestamp without time zone DEFAULT NULL::timestamp without time zone, p_date_max timestamp without time zone DEFAULT NULL::timestamp without time zone) RETURNS TABLE("DateJour" timestamp without time zone, "IdEntite" integer, "NomEntite" character varying, "IdDevise" integer, "NomDevise" character varying, "MontantEntree" numeric, "MontantSortie" numeric, "NetJour" numeric)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT
        DATE_TRUNC('day', p."DatePaiement") AS "DateJour",
        p."IdEntiteFk"                      AS "IdEntite",
        ent."NomEntite"                     AS "NomEntite",
        p."IdDeviseFk"                      AS "IdDevise",
        dev."NomGenerique"                  AS "NomDevise",

        SUM(
            CASE
                WHEN p."IdStatutPaiementFk" = 21
                 AND p."IdTypeMouvementFk" = 81
                    THEN p."MontantPaiement"
                ELSE 0
            END
        )::numeric                          AS "MontantEntree",

        SUM(
            CASE
                WHEN p."IdStatutPaiementFk" = 21
                 AND p."IdTypeMouvementFk" = 80
                    THEN p."MontantPaiement"
                ELSE 0
            END
        )::numeric                          AS "MontantSortie",

        SUM(
            CASE
                WHEN p."IdStatutPaiementFk" = 21
                 AND p."IdTypeMouvementFk" = 81
                    THEN p."MontantPaiement"
                WHEN p."IdStatutPaiementFk" = 21
                 AND p."IdTypeMouvementFk" = 80
                    THEN -p."MontantPaiement"
                ELSE 0
            END
        )::numeric                          AS "NetJour"

    FROM operations."T_Paiement" p
    LEFT JOIN referentiel."T_Generique" dev
           ON dev."ID_Generique" = p."IdDeviseFk"
    LEFT JOIN systeme."T_Entite" ent
           ON ent."IdEntite" = p."IdEntiteFk"
    WHERE (p_id_entite IS NULL OR p."IdEntiteFk" = p_id_entite)
      AND (p_id_devise IS NULL OR p."IdDeviseFk" = p_id_devise)
      AND (p_date_min IS NULL OR p."DatePaiement" >= p_date_min)
      AND (p_date_max IS NULL OR p."DatePaiement" <= p_date_max)
    GROUP BY
        DATE_TRUNC('day', p."DatePaiement"),
        p."IdEntiteFk",
        ent."NomEntite",
        p."IdDeviseFk",
        dev."NomGenerique"
    ORDER BY
        "DateJour",
        "NomEntite",
        "NomDevise";
END;
$$;

--
-- Name: FUNCTION fn_audit_flux_caisse(p_id_entite integer, p_id_devise integer, p_date_min timestamp without time zone, p_date_max timestamp without time zone); Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON FUNCTION operations.fn_audit_flux_caisse(p_id_entite integer, p_id_devise integer, p_date_min timestamp without time zone, p_date_max timestamp without time zone) IS 'Lecture des flux journaliers par entité/devise, avec bornes inclusives optionnelles ; lit seulement T_Paiement, sans archives. Les contributions utilisent le statut 21 et les mouvements 81/80 ; net = entrées moins sorties.';

--
-- Name: gestion_caisse_on_paiement(); Type: FUNCTION; Schema: operations; Owner: -
--

CREATE FUNCTION operations.gestion_caisse_on_paiement() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    -- Deltas à appliquer sur la caisse
    v_delta_old NUMERIC := 0;
    v_delta_new NUMERIC := 0;

    -- Variables de travail
    v_sign       INTEGER;
    v_is_paid    BOOLEAN;
    v_is_devise  BOOLEAN;
BEGIN
    --------------------------------------------------------------------
    -- 1) TRAITEMENT DE L'ANCIEN ENREGISTREMENT (OLD) → DELETE / UPDATE
    --------------------------------------------------------------------
    IF TG_OP IN ('UPDATE', 'DELETE') THEN
        v_delta_old := 0;
        v_sign      := 0;
        v_is_paid   := FALSE;
        v_is_devise := FALSE;

        -- a) Statut paiement = 'Payé(e)' dans catégorie 'Statut paiement' ?
        IF OLD."IdStatutPaiementFk" IS NOT NULL THEN
            SELECT
                ( lower(cg."NomCategorieGenerique") = 'statut paiement'
                  AND trim(g."NomGenerique") = 'Payé(e)' )
            INTO v_is_paid
            FROM referentiel."T_Generique" g
            JOIN referentiel."T_CategorieGenerique" cg
              ON cg."ID_CategorieGenerique" = g."ID_CategorieGeneriqueFk"
            WHERE g."ID_Generique" = OLD."IdStatutPaiementFk";
        END IF;

        -- b) Devise appartenant à la catégorie 'Devise' ?
        IF OLD."IdDeviseFk" IS NOT NULL THEN
            SELECT
                ( referentiel.fn_reference_champ_connue('operations','T_Paiement','IdDeviseFk',g."ID_Generique") )
            INTO v_is_devise
            FROM referentiel."T_Generique" g
            JOIN referentiel."T_CategorieGenerique" cg
              ON cg."ID_CategorieGenerique" = g."ID_CategorieGeneriqueFk"
            WHERE g."ID_Generique" = OLD."IdDeviseFk";
        END IF;

        -- c) Type mouvement paiement : 'Entrée' / 'Sortie' ?
        IF OLD."IdTypeMouvementFk" IS NOT NULL THEN
            SELECT
                CASE
                    WHEN lower(cg."NomCategorieGenerique") = 'type mouvement paiement'
                         AND g."NomGenerique" ILIKE 'entr%' THEN  1   -- Entrée
                    WHEN lower(cg."NomCategorieGenerique") = 'type mouvement paiement'
                         AND g."NomGenerique" ILIKE 'sort%' THEN -1   -- Sortie
                    ELSE 0
                END
            INTO v_sign
            FROM referentiel."T_Generique" g
            JOIN referentiel."T_CategorieGenerique" cg
              ON cg."ID_CategorieGenerique" = g."ID_CategorieGeneriqueFk"
            WHERE g."ID_Generique" = OLD."IdTypeMouvementFk";
        END IF;

        -- d) Calcul de l'effet OLD sur la caisse (qu'on doit annuler)
        IF OLD."ValidePaiement" IS TRUE
           AND v_is_paid
           AND v_is_devise
           AND v_sign <> 0
           AND OLD."IdEntiteFk" IS NOT NULL
        THEN
            -- Pour un DELETE ou la "sortie" de l'ancien état :
            -- delta_old = - (signe * MontantPaiement)
            v_delta_old := - v_sign * OLD."MontantPaiement";

            -- Appliquer delta_old à la caisse correspondante
            INSERT INTO operations."T_Caisse" AS c (
                "IdEntiteFk", "IdDeviseFk", "MontantCaisse"
            )
            VALUES (
                OLD."IdEntiteFk",
                OLD."IdDeviseFk",
                v_delta_old
            )
            ON CONFLICT ("IdEntiteFk", "IdDeviseFk")
            DO UPDATE
            SET "MontantCaisse" = c."MontantCaisse" + EXCLUDED."MontantCaisse";
        END IF;
    END IF;

    --------------------------------------------------------------------
    -- 2) TRAITEMENT DU NOUVEL ENREGISTREMENT (NEW) → INSERT / UPDATE
    --------------------------------------------------------------------
    IF TG_OP IN ('INSERT', 'UPDATE') THEN
        v_delta_new := 0;
        v_sign      := 0;
        v_is_paid   := FALSE;
        v_is_devise := FALSE;

        -- a) Statut paiement = 'Payé(e)' ?
        IF NEW."IdStatutPaiementFk" IS NOT NULL THEN
            SELECT
                ( lower(cg."NomCategorieGenerique") = 'statut paiement'
                  AND trim(g."NomGenerique") = 'Payé(e)' )
            INTO v_is_paid
            FROM referentiel."T_Generique" g
            JOIN referentiel."T_CategorieGenerique" cg
              ON cg."ID_CategorieGenerique" = g."ID_CategorieGeneriqueFk"
            WHERE g."ID_Generique" = NEW."IdStatutPaiementFk";
        END IF;

        -- b) Devise appartenant à la catégorie 'Devise' ?
        IF NEW."IdDeviseFk" IS NOT NULL THEN
            SELECT
                ( referentiel.fn_reference_champ_connue('operations','T_Paiement','IdDeviseFk',g."ID_Generique") )
            INTO v_is_devise
            FROM referentiel."T_Generique" g
            JOIN referentiel."T_CategorieGenerique" cg
              ON cg."ID_CategorieGenerique" = g."ID_CategorieGeneriqueFk"
            WHERE g."ID_Generique" = NEW."IdDeviseFk";
        END IF;

        -- c) Type mouvement : 'Entrée' / 'Sortie' ?
        IF NEW."IdTypeMouvementFk" IS NOT NULL THEN
            SELECT
                CASE
                    WHEN lower(cg."NomCategorieGenerique") = 'type mouvement paiement'
                         AND g."NomGenerique" ILIKE 'entr%' THEN  1
                    WHEN lower(cg."NomCategorieGenerique") = 'type mouvement paiement'
                         AND g."NomGenerique" ILIKE 'sort%' THEN -1
                    ELSE 0
                END
            INTO v_sign
            FROM referentiel."T_Generique" g
            JOIN referentiel."T_CategorieGenerique" cg
              ON cg."ID_CategorieGenerique" = g."ID_CategorieGeneriqueFk"
            WHERE g."ID_Generique" = NEW."IdTypeMouvementFk";
        END IF;

        -- d) Calcul de l'effet NEW sur la caisse
        IF NEW."ValidePaiement" IS TRUE
           AND v_is_paid
           AND v_is_devise
           AND v_sign <> 0
           AND NEW."IdEntiteFk" IS NOT NULL
        THEN
            -- Pour un INSERT ou la "nouvelle" version en UPDATE :
            -- delta_new = signe * MontantPaiement
            v_delta_new := v_sign * NEW."MontantPaiement";

            -- Appliquer delta_new à la caisse correspondante
            INSERT INTO operations."T_Caisse" AS c (
                "IdEntiteFk", "IdDeviseFk", "MontantCaisse"
            )
            VALUES (
                NEW."IdEntiteFk",
                NEW."IdDeviseFk",
                v_delta_new
            )
            ON CONFLICT ("IdEntiteFk", "IdDeviseFk")
            DO UPDATE
            SET "MontantCaisse" = c."MontantCaisse" + EXCLUDED."MontantCaisse";
        END IF;
    END IF;

    -- 3) Retour standard pour un trigger AFTER ROW
    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$$;

--
-- Name: FUNCTION gestion_caisse_on_paiement(); Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON FUNCTION operations.gestion_caisse_on_paiement() IS 'Gestion de caisse existante conservée ; contrôle de devise délégué au catalogue de la vraie FK, sans modifier les règles de statut, de sens ou les écritures antérieures.';

--
-- Name: notification_payment_success(); Type: FUNCTION; Schema: operations; Owner: -
--

CREATE FUNCTION operations.notification_payment_success() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE 
    utilisateur_id INT;
    montant        NUMERIC(10,2);
    devise_nom     VARCHAR;
    statut_nom     VARCHAR;
    mouvement_nom  VARCHAR;
    type_notif     INT;
BEGIN
    -- Récupérer les libellés associés aux IDs (statut, devise, type de mouvement)
    SELECT "NomGenerique"
    INTO statut_nom
    FROM referentiel."T_Generique"
    WHERE "ID_Generique" = NEW."IdStatutPaiementFk";

    SELECT "NomGenerique"
    INTO devise_nom
    FROM referentiel."T_Generique"
    WHERE "ID_Generique" = NEW."IdDeviseFk";

    SELECT "NomGenerique"
    INTO mouvement_nom
    FROM referentiel."T_Generique"
    WHERE "ID_Generique" = NEW."IdTypeMouvementFk";

    -- Récupérer le type de communication "Notification"
    SELECT "ID_Generique"
    INTO type_notif
    FROM referentiel."T_Generique"
    WHERE "NomGenerique" = 'Notification';

    utilisateur_id := NEW."IdUserFk";
    montant        := NEW."MontantPaiement";
    
    -- Vérifier que le statut n'est pas "En attente"
    IF statut_nom NOT IN ('En attente') THEN
        INSERT INTO communication."T_Communication" (
            "IdUserFk",
            "IdTypeCommunication",
            "ContenuCommunication",
            "DateCommunication",
            "ValideCommunication",
            "LectureCommunication",
            "IdEntiteFk"
        )
        VALUES (
            utilisateur_id, 
            type_notif, 
            'Votre paiement de ' || montant || ' ' || devise_nom ||
            ' a été reçu avec succès. Statut: ' || statut_nom ||
            ', Mouvement: ' || mouvement_nom || '.',
            NOW(),
            TRUE,
            FALSE,
            NEW."IdEntiteFk"
        );
    END IF;

    RETURN NEW;
END;
$$;

--
-- Name: FUNCTION notification_payment_success(); Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON FUNCTION operations.notification_payment_success() IS 'Après INSERT/UPDATE du paiement, ajoute une communication à son utilisateur si le libellé de statut n’est pas En attente. Ne vérifie pas une transition vers payé ni l’absence d’une notification précédente ; le nom de la fonction ne certifie pas un paiement réussi.';

--
-- Name: prevent_delete_caisse_if_dependent(); Type: FUNCTION; Schema: operations; Owner: -
--

CREATE FUNCTION operations.prevent_delete_caisse_if_dependent() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    ----------------------------------------------------------------------
    -- 1. Vérifier les dépendances dans operations."T_Paiement"
    --    On bloque si au moins un paiement existe pour cette entité/devise
    ----------------------------------------------------------------------
    IF EXISTS (
        SELECT 1
        FROM operations."T_Paiement" p
        WHERE p."IdDeviseFk" = OLD."IdDeviseFk"
          AND p."IdEntiteFk" = OLD."IdEntiteFk"
    ) THEN
        RAISE EXCEPTION
            'Suppression impossible : des paiements existent pour cette caisse (Entité=% / Devise=%).',
            OLD."IdEntiteFk", OLD."IdDeviseFk";
    END IF;

    ----------------------------------------------------------------------
    -- 2. Vérifier les dépendances dans operations."T_Paiement_Archive"
    --    On bloque aussi si des paiements ARCHIVÉS existent
    ----------------------------------------------------------------------
    IF EXISTS (
        SELECT 1
        FROM operations."T_Paiement_Archive" pa
        WHERE pa."IdDeviseFk" = OLD."IdDeviseFk"
          AND pa."IdEntiteFk" = OLD."IdEntiteFk"
    ) THEN
        RAISE EXCEPTION
            'Suppression impossible : des paiements archivés existent pour cette caisse (Entité=% / Devise=%).',
            OLD."IdEntiteFk", OLD."IdDeviseFk";
    END IF;

    ----------------------------------------------------------------------
    -- Si aucune dépendance → on autorise la suppression
    ----------------------------------------------------------------------
    RETURN OLD;
END;
$$;

--
-- Name: FUNCTION prevent_delete_caisse_if_dependent(); Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON FUNCTION operations.prevent_delete_caisse_if_dependent() IS 'Avant DELETE de caisse, bloque la suppression s’il existe un paiement actif ou archivé pour le même couple entité/devise.';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: T_Caisse; Type: TABLE; Schema: operations; Owner: -
--

CREATE TABLE operations."T_Caisse" (
    "IdCaisse" integer CONSTRAINT "T_Caisse_IdCaisse_not_null" NOT NULL,
    "IdDeviseFk" integer CONSTRAINT "T_Caisse_IdDeviseFk_not_null" NOT NULL,
    "MontantCaisse" numeric(10,2) DEFAULT 0,
    "IdEntiteFk" integer
);

--
-- Name: TABLE "T_Caisse"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON TABLE operations."T_Caisse" IS 'Solde courant de caisse par entité et devise ; unicité du couple IdEntiteFk/IdDeviseFk. Mis à jour par les effets des paiements éligibles dans la fonction de gestion de caisse.';

--
-- Name: COLUMN "T_Caisse"."IdCaisse"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Caisse"."IdCaisse" IS 'Identifiant de la caisse.';

--
-- Name: COLUMN "T_Caisse"."IdDeviseFk"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Caisse"."IdDeviseFk" IS 'Devise de l’opération dans le référentiel ; les montants de devises différentes restent distincts. Relation imposée : FOREIGN KEY ("IdDeviseFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE.';

--
-- Name: COLUMN "T_Caisse"."MontantCaisse"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Caisse"."MontantCaisse" IS 'Solde courant enregistré de cette caisse, dans sa devise ; à rapprocher du solde théorique des paiements.';

--
-- Name: COLUMN "T_Caisse"."IdEntiteFk"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Caisse"."IdEntiteFk" IS 'Entité de rattachement de l’enregistrement. Relation imposée : FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON UPDATE CASCADE ON DELETE SET NULL.';

--
-- Name: CONSTRAINT "T_Caisse_IdCaisse_not_null" ON "T_Caisse"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "T_Caisse_IdCaisse_not_null" ON operations."T_Caisse" IS 'Non-nullité : exige une valeur renseignée dans "operations"."T_Caisse". Définition : NOT NULL "IdCaisse".';

--
-- Name: CONSTRAINT "T_Caisse_IdDeviseFk_not_null" ON "T_Caisse"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "T_Caisse_IdDeviseFk_not_null" ON operations."T_Caisse" IS 'Non-nullité : exige une valeur renseignée dans "operations"."T_Caisse". Définition : NOT NULL "IdDeviseFk".';

--
-- Name: T_Caisse_IdCaisse_seq; Type: SEQUENCE; Schema: operations; Owner: -
--

ALTER TABLE operations."T_Caisse" ALTER COLUMN "IdCaisse" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME operations."T_Caisse_IdCaisse_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

--
-- Name: SEQUENCE "T_Caisse_IdCaisse_seq"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON SEQUENCE operations."T_Caisse_IdCaisse_seq" IS 'Séquence de génération de "operations"."T_Caisse"."IdCaisse". Les valeurs produites identifient les enregistrements ; les écarts de numérotation ne prouvent pas une suppression.';

--
-- Name: T_Paiement; Type: TABLE; Schema: operations; Owner: -
--

CREATE TABLE operations."T_Paiement" (
    "IdPaiement" integer CONSTRAINT "T_Paiement_IdPaiement_not_null" NOT NULL,
    "CodePaiement" character varying(25),
    "IdUserFk" integer CONSTRAINT "T_Paiement_IdUserFk_not_null" NOT NULL,
    "IdTypePaiementFk" integer CONSTRAINT "T_Paiement_IdTypePaiementFk_not_null" NOT NULL,
    "MontantPaiement" numeric(10,2) CONSTRAINT "T_Paiement_MontantPaiement_not_null" NOT NULL,
    "IdStatutPaiementFk" integer,
    "DatePaiement" timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    "ObsPaiement" text,
    "ValidePaiement" boolean DEFAULT true CONSTRAINT "T_Paiement_ValidePaiement_not_null" NOT NULL,
    "IdDeviseFk" integer CONSTRAINT "T_Paiement_IdDeviseFk_not_null" NOT NULL,
    "IdPayeurFk" integer,
    "IdTypeMouvementFk" integer,
    "IdEntiteFk" integer CONSTRAINT "T_Paiement_IdEntiteFk_not_null" NOT NULL,
    CONSTRAINT chk_montant_paiement CHECK (("MontantPaiement" > (0)::numeric))
);

--
-- Name: TABLE "T_Paiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON TABLE operations."T_Paiement" IS 'Paiements actifs avec montant, devise, statut, sens de mouvement, utilisateur et entité. Les triggers gèrent caisse, audit, notification et déplacement des paiements de plus de deux ans vers les archives.';

--
-- Name: COLUMN "T_Paiement"."IdPaiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement"."IdPaiement" IS 'Identifiant du paiement ; conservé depuis le paiement source dans la table d’archives.';

--
-- Name: COLUMN "T_Paiement"."CodePaiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement"."CodePaiement" IS 'Référence métier du paiement.';

--
-- Name: COLUMN "T_Paiement"."IdUserFk"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement"."IdUserFk" IS 'Utilisateur rattaché à l’enregistrement. Relation imposée : FOREIGN KEY ("IdUserFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE.';

--
-- Name: COLUMN "T_Paiement"."IdTypePaiementFk"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement"."IdTypePaiementFk" IS 'Type métier du paiement dans le référentiel. Relation imposée : FOREIGN KEY ("IdTypePaiementFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE.';

--
-- Name: COLUMN "T_Paiement"."MontantPaiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement"."MontantPaiement" IS 'Montant du paiement dans IdDeviseFk ; strictement positif sur T_Paiement.';

--
-- Name: COLUMN "T_Paiement"."IdStatutPaiementFk"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement"."IdStatutPaiementFk" IS 'Statut de paiement dans le référentiel ; les règles de caisse et d’audit déterminent les statuts retenus.';

--
-- Name: COLUMN "T_Paiement"."DatePaiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement"."DatePaiement" IS 'Date et heure du paiement ; sert aux regroupements de flux et à l’archivage.';

--
-- Name: COLUMN "T_Paiement"."ObsPaiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement"."ObsPaiement" IS 'Observations enregistrées sur le paiement.';

--
-- Name: COLUMN "T_Paiement"."ValidePaiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement"."ValidePaiement" IS 'Indique si le paiement est déclaré valide/actif dans le registre ; distinct des qualifications calculées dans les vues.';

--
-- Name: COLUMN "T_Paiement"."IdDeviseFk"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement"."IdDeviseFk" IS 'Devise de l’opération dans le référentiel ; les montants de devises différentes restent distincts. Relation imposée : FOREIGN KEY ("IdDeviseFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE.';

--
-- Name: COLUMN "T_Paiement"."IdPayeurFk"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement"."IdPayeurFk" IS 'Payeur enregistré pour le paiement. Relation imposée : FOREIGN KEY ("IdPayeurFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE ON DELETE SET NULL.';

--
-- Name: COLUMN "T_Paiement"."IdTypeMouvementFk"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement"."IdTypeMouvementFk" IS 'Sens/type du mouvement de paiement dans le référentiel ; distinct du type de mouvement de stock.';

--
-- Name: COLUMN "T_Paiement"."IdEntiteFk"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement"."IdEntiteFk" IS 'Entité de rattachement de l’enregistrement. Relation imposée : FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON UPDATE CASCADE ON DELETE CASCADE.';

--
-- Name: CONSTRAINT "T_Paiement_IdPaiement_not_null" ON "T_Paiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "T_Paiement_IdPaiement_not_null" ON operations."T_Paiement" IS 'Non-nullité : exige une valeur renseignée dans "operations"."T_Paiement". Définition : NOT NULL "IdPaiement".';

--
-- Name: CONSTRAINT "T_Paiement_IdUserFk_not_null" ON "T_Paiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "T_Paiement_IdUserFk_not_null" ON operations."T_Paiement" IS 'Non-nullité : exige une valeur renseignée dans "operations"."T_Paiement". Définition : NOT NULL "IdUserFk".';

--
-- Name: CONSTRAINT "T_Paiement_IdTypePaiementFk_not_null" ON "T_Paiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "T_Paiement_IdTypePaiementFk_not_null" ON operations."T_Paiement" IS 'Non-nullité : exige une valeur renseignée dans "operations"."T_Paiement". Définition : NOT NULL "IdTypePaiementFk".';

--
-- Name: CONSTRAINT "T_Paiement_MontantPaiement_not_null" ON "T_Paiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "T_Paiement_MontantPaiement_not_null" ON operations."T_Paiement" IS 'Non-nullité : exige une valeur renseignée dans "operations"."T_Paiement". Définition : NOT NULL "MontantPaiement".';

--
-- Name: CONSTRAINT "T_Paiement_ValidePaiement_not_null" ON "T_Paiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "T_Paiement_ValidePaiement_not_null" ON operations."T_Paiement" IS 'Non-nullité : exige une valeur renseignée dans "operations"."T_Paiement". Définition : NOT NULL "ValidePaiement".';

--
-- Name: CONSTRAINT "T_Paiement_IdDeviseFk_not_null" ON "T_Paiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "T_Paiement_IdDeviseFk_not_null" ON operations."T_Paiement" IS 'Non-nullité : exige une valeur renseignée dans "operations"."T_Paiement". Définition : NOT NULL "IdDeviseFk".';

--
-- Name: CONSTRAINT "T_Paiement_IdEntiteFk_not_null" ON "T_Paiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "T_Paiement_IdEntiteFk_not_null" ON operations."T_Paiement" IS 'Non-nullité : exige une valeur renseignée dans "operations"."T_Paiement". Définition : NOT NULL "IdEntiteFk".';

--
-- Name: CONSTRAINT chk_montant_paiement ON "T_Paiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT chk_montant_paiement ON operations."T_Paiement" IS 'Contrôle de cohérence des valeurs autorisées dans "operations"."T_Paiement". Définition : CHECK ("MontantPaiement" > 0::numeric).';

--
-- Name: T_Paiement_Archive; Type: TABLE; Schema: operations; Owner: -
--

CREATE TABLE operations."T_Paiement_Archive" (
    "IdPaiement" integer,
    "CodePaiement" character varying(25),
    "IdUserFk" integer,
    "IdTypePaiementFk" integer,
    "MontantPaiement" numeric(10,2),
    "IdStatutPaiementFk" integer,
    "DatePaiement" timestamp with time zone,
    "ObsPaiement" text,
    "ValidePaiement" boolean,
    "IdDeviseFk" integer,
    "IdPayeurFk" integer,
    "IdTypeMouvementFk" integer,
    "DateArchivage" timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    "IdEntiteFk" integer,
    "IdPaiementArchive" integer CONSTRAINT "T_Paiement_Archive_IdPaiementArchive_not_null" NOT NULL
);

--
-- Name: TABLE "T_Paiement_Archive"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON TABLE operations."T_Paiement_Archive" IS 'Archive des paiements déplacés depuis T_Paiement, avec identifiant du paiement source, identifiant propre d’archive et date d’archivage. Utilisée avec les paiements actifs par le contrôle de caisse.';

--
-- Name: COLUMN "T_Paiement_Archive"."IdPaiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement_Archive"."IdPaiement" IS 'Identifiant du paiement ; conservé depuis le paiement source dans la table d’archives.';

--
-- Name: COLUMN "T_Paiement_Archive"."CodePaiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement_Archive"."CodePaiement" IS 'Référence métier du paiement.';

--
-- Name: COLUMN "T_Paiement_Archive"."IdUserFk"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement_Archive"."IdUserFk" IS 'Utilisateur rattaché à l’enregistrement.';

--
-- Name: COLUMN "T_Paiement_Archive"."IdTypePaiementFk"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement_Archive"."IdTypePaiementFk" IS 'Type métier du paiement dans le référentiel.';

--
-- Name: COLUMN "T_Paiement_Archive"."MontantPaiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement_Archive"."MontantPaiement" IS 'Montant du paiement dans IdDeviseFk ; strictement positif sur T_Paiement.';

--
-- Name: COLUMN "T_Paiement_Archive"."IdStatutPaiementFk"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement_Archive"."IdStatutPaiementFk" IS 'Statut de paiement dans le référentiel ; les règles de caisse et d’audit déterminent les statuts retenus.';

--
-- Name: COLUMN "T_Paiement_Archive"."DatePaiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement_Archive"."DatePaiement" IS 'Date et heure du paiement ; sert aux regroupements de flux et à l’archivage.';

--
-- Name: COLUMN "T_Paiement_Archive"."ObsPaiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement_Archive"."ObsPaiement" IS 'Observations enregistrées sur le paiement.';

--
-- Name: COLUMN "T_Paiement_Archive"."ValidePaiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement_Archive"."ValidePaiement" IS 'Indique si le paiement est déclaré valide/actif dans le registre ; distinct des qualifications calculées dans les vues.';

--
-- Name: COLUMN "T_Paiement_Archive"."IdDeviseFk"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement_Archive"."IdDeviseFk" IS 'Devise de l’opération dans le référentiel ; les montants de devises différentes restent distincts.';

--
-- Name: COLUMN "T_Paiement_Archive"."IdPayeurFk"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement_Archive"."IdPayeurFk" IS 'Payeur enregistré pour le paiement.';

--
-- Name: COLUMN "T_Paiement_Archive"."IdTypeMouvementFk"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement_Archive"."IdTypeMouvementFk" IS 'Sens/type du mouvement de paiement dans le référentiel ; distinct du type de mouvement de stock.';

--
-- Name: COLUMN "T_Paiement_Archive"."DateArchivage"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement_Archive"."DateArchivage" IS 'Horodatage du déplacement du paiement vers les archives.';

--
-- Name: COLUMN "T_Paiement_Archive"."IdEntiteFk"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement_Archive"."IdEntiteFk" IS 'Entité de rattachement de l’enregistrement. Relation imposée : FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON UPDATE CASCADE ON DELETE SET NULL.';

--
-- Name: COLUMN "T_Paiement_Archive"."IdPaiementArchive"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON COLUMN operations."T_Paiement_Archive"."IdPaiementArchive" IS 'Identifiant propre de la ligne d’archive du paiement.';

--
-- Name: CONSTRAINT "T_Paiement_Archive_IdPaiementArchive_not_null" ON "T_Paiement_Archive"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "T_Paiement_Archive_IdPaiementArchive_not_null" ON operations."T_Paiement_Archive" IS 'Non-nullité : exige une valeur renseignée dans "operations"."T_Paiement_Archive". Définition : NOT NULL "IdPaiementArchive".';

--
-- Name: T_Paiement_Archive_IdPaiementArchive_seq; Type: SEQUENCE; Schema: operations; Owner: -
--

ALTER TABLE operations."T_Paiement_Archive" ALTER COLUMN "IdPaiementArchive" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME operations."T_Paiement_Archive_IdPaiementArchive_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

--
-- Name: SEQUENCE "T_Paiement_Archive_IdPaiementArchive_seq"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON SEQUENCE operations."T_Paiement_Archive_IdPaiementArchive_seq" IS 'Séquence de génération de "operations"."T_Paiement_Archive"."IdPaiementArchive". Les valeurs produites identifient les enregistrements ; les écarts de numérotation ne prouvent pas une suppression.';

--
-- Name: T_Paiement_IdPaiement_seq; Type: SEQUENCE; Schema: operations; Owner: -
--

ALTER TABLE operations."T_Paiement" ALTER COLUMN "IdPaiement" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME operations."T_Paiement_IdPaiement_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

--
-- Name: SEQUENCE "T_Paiement_IdPaiement_seq"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON SEQUENCE operations."T_Paiement_IdPaiement_seq" IS 'Séquence de génération de "operations"."T_Paiement"."IdPaiement". Les valeurs produites identifient les enregistrements ; les écarts de numérotation ne prouvent pas une suppression.';

--
-- Name: T_Paiement Pk_IdPaiement; Type: CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations."T_Paiement"
    ADD CONSTRAINT "Pk_IdPaiement" PRIMARY KEY ("IdPaiement");

--
-- Name: CONSTRAINT "Pk_IdPaiement" ON "T_Paiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "Pk_IdPaiement" ON operations."T_Paiement" IS 'Clé primaire : identifie de manière unique chaque ligne dans "operations"."T_Paiement". Définition : PRIMARY KEY ("IdPaiement").';

--
-- Name: T_Caisse T_Caisse_pkey; Type: CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations."T_Caisse"
    ADD CONSTRAINT "T_Caisse_pkey" PRIMARY KEY ("IdCaisse");

--
-- Name: CONSTRAINT "T_Caisse_pkey" ON "T_Caisse"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "T_Caisse_pkey" ON operations."T_Caisse" IS 'Clé primaire : identifie de manière unique chaque ligne dans "operations"."T_Caisse". Définition : PRIMARY KEY ("IdCaisse").';

--
-- Name: T_Paiement_Archive T_Paiement_Archive_pkey; Type: CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations."T_Paiement_Archive"
    ADD CONSTRAINT "T_Paiement_Archive_pkey" PRIMARY KEY ("IdPaiementArchive");

--
-- Name: CONSTRAINT "T_Paiement_Archive_pkey" ON "T_Paiement_Archive"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "T_Paiement_Archive_pkey" ON operations."T_Paiement_Archive" IS 'Clé primaire : identifie de manière unique chaque ligne dans "operations"."T_Paiement_Archive". Définition : PRIMARY KEY ("IdPaiementArchive").';

--
-- Name: T_Caisse UQ_Entite_Devise; Type: CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations."T_Caisse"
    ADD CONSTRAINT "UQ_Entite_Devise" UNIQUE ("IdEntiteFk", "IdDeviseFk");

--
-- Name: CONSTRAINT "UQ_Entite_Devise" ON "T_Caisse"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "UQ_Entite_Devise" ON operations."T_Caisse" IS 'Unicité : empêche les doublons sur la combinaison indiquée dans "operations"."T_Caisse". Définition : UNIQUE ("IdEntiteFk", "IdDeviseFk").';

--
-- Name: INDEX "Pk_IdPaiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON INDEX operations."Pk_IdPaiement" IS 'Index support de la clé primaire sur "operations"."T_Paiement". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX "Pk_IdPaiement" ON operations."T_Paiement" USING btree ("IdPaiement").';

--
-- Name: INDEX "T_Caisse_pkey"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON INDEX operations."T_Caisse_pkey" IS 'Index support de la clé primaire sur "operations"."T_Caisse". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX "T_Caisse_pkey" ON operations."T_Caisse" USING btree ("IdCaisse").';

--
-- Name: INDEX "T_Paiement_Archive_pkey"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON INDEX operations."T_Paiement_Archive_pkey" IS 'Index support de la clé primaire sur "operations"."T_Paiement_Archive". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX "T_Paiement_Archive_pkey" ON operations."T_Paiement_Archive" USING btree ("IdPaiementArchive").';

--
-- Name: INDEX "UQ_Entite_Devise"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON INDEX operations."UQ_Entite_Devise" IS 'Index d’unicité sur "operations"."T_Caisse". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX "UQ_Entite_Devise" ON operations."T_Caisse" USING btree ("IdEntiteFk", "IdDeviseFk").';

--
-- Name: idx_fk_paiement_user; Type: INDEX; Schema: operations; Owner: -
--

CREATE INDEX idx_fk_paiement_user ON operations."T_Paiement" USING btree ("IdUserFk") WITH (fillfactor='100', deduplicate_items='true');

--
-- Name: INDEX idx_fk_paiement_user; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON INDEX operations.idx_fk_paiement_user IS 'Index d’accès sur "operations"."T_Paiement". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_fk_paiement_user ON operations."T_Paiement" USING btree ("IdUserFk") WITH (fillfactor=''100'', deduplicate_items=''true'').';

--
-- Name: idx_paiement_archive_date; Type: INDEX; Schema: operations; Owner: -
--

CREATE INDEX idx_paiement_archive_date ON operations."T_Paiement_Archive" USING btree ("DatePaiement");

--
-- Name: INDEX idx_paiement_archive_date; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON INDEX operations.idx_paiement_archive_date IS 'Index d’accès sur "operations"."T_Paiement_Archive". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_paiement_archive_date ON operations."T_Paiement_Archive" USING btree ("DatePaiement").';

--
-- Name: idx_paiement_archive_entite; Type: INDEX; Schema: operations; Owner: -
--

CREATE INDEX idx_paiement_archive_entite ON operations."T_Paiement_Archive" USING btree ("IdEntiteFk");

--
-- Name: INDEX idx_paiement_archive_entite; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON INDEX operations.idx_paiement_archive_entite IS 'Index d’accès sur "operations"."T_Paiement_Archive". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_paiement_archive_entite ON operations."T_Paiement_Archive" USING btree ("IdEntiteFk").';

--
-- Name: idx_paiement_archive_idpaiement; Type: INDEX; Schema: operations; Owner: -
--

CREATE INDEX idx_paiement_archive_idpaiement ON operations."T_Paiement_Archive" USING btree ("IdPaiement");

--
-- Name: INDEX idx_paiement_archive_idpaiement; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON INDEX operations.idx_paiement_archive_idpaiement IS 'Index d’accès sur "operations"."T_Paiement_Archive". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_paiement_archive_idpaiement ON operations."T_Paiement_Archive" USING btree ("IdPaiement").';

--
-- Name: idx_paiement_date; Type: INDEX; Schema: operations; Owner: -
--

CREATE INDEX idx_paiement_date ON operations."T_Paiement" USING btree ("DatePaiement") WITH (fillfactor='100', deduplicate_items='true');

--
-- Name: INDEX idx_paiement_date; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON INDEX operations.idx_paiement_date IS 'Index d’accès sur "operations"."T_Paiement". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_paiement_date ON operations."T_Paiement" USING btree ("DatePaiement") WITH (fillfactor=''100'', deduplicate_items=''true'').';

--
-- Name: idx_paiement_devise; Type: INDEX; Schema: operations; Owner: -
--

CREATE INDEX idx_paiement_devise ON operations."T_Paiement" USING btree ("IdDeviseFk") WITH (fillfactor='100', deduplicate_items='true');

--
-- Name: INDEX idx_paiement_devise; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON INDEX operations.idx_paiement_devise IS 'Index d’accès sur "operations"."T_Paiement". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_paiement_devise ON operations."T_Paiement" USING btree ("IdDeviseFk") WITH (fillfactor=''100'', deduplicate_items=''true'').';

--
-- Name: idx_paiement_entite_date; Type: INDEX; Schema: operations; Owner: -
--

CREATE INDEX idx_paiement_entite_date ON operations."T_Paiement" USING btree ("IdEntiteFk", "DatePaiement");

--
-- Name: INDEX idx_paiement_entite_date; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON INDEX operations.idx_paiement_entite_date IS 'Index d’accès sur "operations"."T_Paiement". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_paiement_entite_date ON operations."T_Paiement" USING btree ("IdEntiteFk", "DatePaiement").';

--
-- Name: idx_paiement_statut; Type: INDEX; Schema: operations; Owner: -
--

CREATE INDEX idx_paiement_statut ON operations."T_Paiement" USING btree ("IdStatutPaiementFk") WITH (fillfactor='100', deduplicate_items='true');

--
-- Name: INDEX idx_paiement_statut; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON INDEX operations.idx_paiement_statut IS 'Index d’accès sur "operations"."T_Paiement". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_paiement_statut ON operations."T_Paiement" USING btree ("IdStatutPaiementFk") WITH (fillfactor=''100'', deduplicate_items=''true'').';

--
-- Name: T_Caisse aa_reference_champ; Type: TRIGGER; Schema: operations; Owner: -
--

CREATE TRIGGER aa_reference_champ BEFORE INSERT OR UPDATE ON operations."T_Caisse" FOR EACH ROW EXECUTE FUNCTION referentiel.tr_valider_champ_referentiel();

--
-- Name: TRIGGER aa_reference_champ ON "T_Caisse"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON TRIGGER aa_reference_champ ON operations."T_Caisse" IS 'Valide les nouvelles références du catalogue physique ; conserve les valeurs historiques inchangées, même devenues hors famille.';

--
-- Name: T_Paiement aa_reference_champ; Type: TRIGGER; Schema: operations; Owner: -
--

CREATE TRIGGER aa_reference_champ BEFORE INSERT OR UPDATE ON operations."T_Paiement" FOR EACH ROW EXECUTE FUNCTION referentiel.tr_valider_champ_referentiel();

--
-- Name: TRIGGER aa_reference_champ ON "T_Paiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON TRIGGER aa_reference_champ ON operations."T_Paiement" IS 'Valide les nouvelles références du catalogue physique ; conserve les valeurs historiques inchangées, même devenues hors famille.';

--
-- Name: T_Paiement trigger_archive_paiements; Type: TRIGGER; Schema: operations; Owner: -
--

CREATE TRIGGER trigger_archive_paiements AFTER INSERT OR UPDATE ON operations."T_Paiement" FOR EACH STATEMENT EXECUTE FUNCTION operations.archive_paiements();

ALTER TABLE operations."T_Paiement" DISABLE TRIGGER trigger_archive_paiements;

--
-- Name: TRIGGER trigger_archive_paiements ON "T_Paiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON TRIGGER trigger_archive_paiements ON operations."T_Paiement" IS 'AFTER INSERT OR UPDATE sur "operations"."T_Paiement", par instruction. Appelle "operations"."archive_paiements" : Après INSERT/UPDATE sur T_Paiement, copie les paiements âgés de plus de deux ans dans T_Paiement_Archive, puis les supprime de la table active. Déclenchement par instruction, sans planification périodique ; les triggers de suppression de la table active restent applicables.';

--
-- Name: T_Paiement trigger_audit_T_Paiement; Type: TRIGGER; Schema: operations; Owner: -
--

CREATE TRIGGER "trigger_audit_T_Paiement" AFTER INSERT OR DELETE OR UPDATE ON operations."T_Paiement" FOR EACH ROW EXECUTE FUNCTION systeme.audit_log_function();

--
-- Name: TRIGGER "trigger_audit_T_Paiement" ON "T_Paiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON TRIGGER "trigger_audit_T_Paiement" ON operations."T_Paiement" IS 'AFTER INSERT OR DELETE OR UPDATE sur "operations"."T_Paiement", pour chaque ligne. Appelle "systeme"."audit_log_function" : Fonction de trigger AFTER enregistrant INSERT/UPDATE/DELETE dans T_Audit_Log avec TG_TABLE_NAME, états OLD/NEW complets et instant de modification. Tente de reprendre IdEntiteFk si la colonne est présente ; ne déduit pas l’auteur utilisateur.';

--
-- Name: T_Paiement trigger_gestion_caisse_on_paiement; Type: TRIGGER; Schema: operations; Owner: -
--

CREATE TRIGGER trigger_gestion_caisse_on_paiement AFTER INSERT OR DELETE OR UPDATE ON operations."T_Paiement" FOR EACH ROW EXECUTE FUNCTION operations.gestion_caisse_on_paiement();

--
-- Name: TRIGGER trigger_gestion_caisse_on_paiement ON "T_Paiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON TRIGGER trigger_gestion_caisse_on_paiement ON operations."T_Paiement" IS 'AFTER INSERT OR DELETE OR UPDATE sur "operations"."T_Paiement", pour chaque ligne. Appelle "operations"."gestion_caisse_on_paiement" : Après mutation d’un paiement, annule l’effet OLD et applique NEW dans la caisse entité/devise par UPSERT. Éligibilité : ValidePaiement vrai, statut Payé(e), catégorie devise, type de mouvement paiement Entrée/Sortie et entité renseignée. Les libellés de référentiel sont utilisés, contrairement aux codes fixes des fonctions d’audit.';

--
-- Name: T_Paiement trigger_notification_payment_success; Type: TRIGGER; Schema: operations; Owner: -
--

CREATE TRIGGER trigger_notification_payment_success AFTER INSERT OR UPDATE ON operations."T_Paiement" FOR EACH ROW EXECUTE FUNCTION operations.notification_payment_success();

--
-- Name: TRIGGER trigger_notification_payment_success ON "T_Paiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON TRIGGER trigger_notification_payment_success ON operations."T_Paiement" IS 'AFTER INSERT OR UPDATE sur "operations"."T_Paiement", pour chaque ligne. Appelle "operations"."notification_payment_success" : Après INSERT/UPDATE du paiement, ajoute une communication à son utilisateur si le libellé de statut n’est pas En attente. Ne vérifie pas une transition vers payé ni l’absence d’une notification précédente ; le nom de la fonction ne certifie pas un paiement réussi.';

--
-- Name: T_Caisse trigger_prevention_delete_caisse; Type: TRIGGER; Schema: operations; Owner: -
--

CREATE TRIGGER trigger_prevention_delete_caisse BEFORE DELETE ON operations."T_Caisse" FOR EACH ROW EXECUTE FUNCTION operations.prevent_delete_caisse_if_dependent();

--
-- Name: TRIGGER trigger_prevention_delete_caisse ON "T_Caisse"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON TRIGGER trigger_prevention_delete_caisse ON operations."T_Caisse" IS 'BEFORE DELETE sur "operations"."T_Caisse", pour chaque ligne. Appelle "operations"."prevent_delete_caisse_if_dependent" : Avant DELETE de caisse, bloque la suppression s’il existe un paiement actif ou archivé pour le même couple entité/devise.';

--
-- Name: T_Caisse Fk_IdDevise; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations."T_Caisse"
    ADD CONSTRAINT "Fk_IdDevise" FOREIGN KEY ("IdDeviseFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE;

--
-- Name: CONSTRAINT "Fk_IdDevise" ON "T_Caisse"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "Fk_IdDevise" ON operations."T_Caisse" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "operations"."T_Caisse". Définition : FOREIGN KEY ("IdDeviseFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE.';

--
-- Name: T_Paiement Fk_IdDevise; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations."T_Paiement"
    ADD CONSTRAINT "Fk_IdDevise" FOREIGN KEY ("IdDeviseFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE;

--
-- Name: CONSTRAINT "Fk_IdDevise" ON "T_Paiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "Fk_IdDevise" ON operations."T_Paiement" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "operations"."T_Paiement". Définition : FOREIGN KEY ("IdDeviseFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE.';

--
-- Name: T_Caisse Fk_IdEntite; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations."T_Caisse"
    ADD CONSTRAINT "Fk_IdEntite" FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON UPDATE CASCADE ON DELETE SET NULL;

--
-- Name: CONSTRAINT "Fk_IdEntite" ON "T_Caisse"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "Fk_IdEntite" ON operations."T_Caisse" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "operations"."T_Caisse". Définition : FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON UPDATE CASCADE ON DELETE SET NULL.';

--
-- Name: T_Paiement Fk_IdEntite; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations."T_Paiement"
    ADD CONSTRAINT "Fk_IdEntite" FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON UPDATE CASCADE ON DELETE CASCADE;

--
-- Name: CONSTRAINT "Fk_IdEntite" ON "T_Paiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "Fk_IdEntite" ON operations."T_Paiement" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "operations"."T_Paiement". Définition : FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON UPDATE CASCADE ON DELETE CASCADE.';

--
-- Name: T_Paiement_Archive Fk_IdEntite; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations."T_Paiement_Archive"
    ADD CONSTRAINT "Fk_IdEntite" FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON UPDATE CASCADE ON DELETE SET NULL;

--
-- Name: CONSTRAINT "Fk_IdEntite" ON "T_Paiement_Archive"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "Fk_IdEntite" ON operations."T_Paiement_Archive" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "operations"."T_Paiement_Archive". Définition : FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON UPDATE CASCADE ON DELETE SET NULL.';

--
-- Name: T_Paiement Fk_IdPayeurFk; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations."T_Paiement"
    ADD CONSTRAINT "Fk_IdPayeurFk" FOREIGN KEY ("IdPayeurFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE ON DELETE SET NULL;

--
-- Name: CONSTRAINT "Fk_IdPayeurFk" ON "T_Paiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "Fk_IdPayeurFk" ON operations."T_Paiement" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "operations"."T_Paiement". Définition : FOREIGN KEY ("IdPayeurFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE ON DELETE SET NULL.';

--
-- Name: T_Paiement Fk_IdTypePaiement; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations."T_Paiement"
    ADD CONSTRAINT "Fk_IdTypePaiement" FOREIGN KEY ("IdTypePaiementFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE;

--
-- Name: CONSTRAINT "Fk_IdTypePaiement" ON "T_Paiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "Fk_IdTypePaiement" ON operations."T_Paiement" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "operations"."T_Paiement". Définition : FOREIGN KEY ("IdTypePaiementFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE.';

--
-- Name: T_Paiement Fk_IdUserFk; Type: FK CONSTRAINT; Schema: operations; Owner: -
--

ALTER TABLE ONLY operations."T_Paiement"
    ADD CONSTRAINT "Fk_IdUserFk" FOREIGN KEY ("IdUserFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE;

--
-- Name: CONSTRAINT "Fk_IdUserFk" ON "T_Paiement"; Type: COMMENT; Schema: operations; Owner: -
--

COMMENT ON CONSTRAINT "Fk_IdUserFk" ON operations."T_Paiement" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "operations"."T_Paiement". Définition : FOREIGN KEY ("IdUserFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE.';
