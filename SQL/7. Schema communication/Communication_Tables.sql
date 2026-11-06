-- Extrait canonique PostgreSQL 18 après les migrations Communication du 06/11/2026.
-- Sans données ni propriétaires. Voir SQL/README.md pour le parcours d’installation.
SET check_function_bodies = false;
SELECT pg_catalog.set_config('search_path', '', false);
--
-- Name: communication; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA IF NOT EXISTS "communication";


--
-- Name: SCHEMA communication; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA communication IS 'Discussions, messages de conversation et communications adressées aux utilisateurs et entités.';


--
-- Name: fn_dater_lecture_annonce(); Type: FUNCTION; Schema: communication; Owner: -
--

CREATE FUNCTION communication.fn_dater_lecture_annonce() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$
BEGIN
    IF OLD."IdAnnonceFk" IS NOT NULL THEN
        IF OLD."LectureCommunication" AND NOT NEW."LectureCommunication" THEN
            RAISE EXCEPTION 'La lecture d’une annonce ne peut pas être annulée.' USING ERRCODE = '23514';
        END IF;
        NEW."LuLe" := CASE WHEN NEW."LectureCommunication"
                           THEN COALESCE(OLD."LuLe", CURRENT_TIMESTAMP) END;
    END IF;
    RETURN NEW;
END
$$;


--
-- Name: FUNCTION fn_dater_lecture_annonce(); Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON FUNCTION communication.fn_dater_lecture_annonce() IS 'Date la première lecture d’une annonce individuelle sans changer les anciennes notifications.';


--
-- Name: fn_diffuser_annonce(integer, integer[], text, text, uuid); Type: FUNCTION; Schema: communication; Owner: -
--

CREATE FUNCTION communication.fn_diffuser_annonce(p_auteur integer, p_entites integer[], p_sujet text, p_contenu text, p_cle uuid) RETURNS TABLE("IdAnnonce" bigint, "Rejouee" boolean)
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$
DECLARE
    v_global boolean;
    v_admin boolean;
    v_entite integer;
    v_portee text := CASE WHEN p_entites IS NULL THEN 'toutes' ELSE 'entreprises' END;
    v_sujet text := btrim(p_sujet);
    v_contenu text := btrim(p_contenu);
    v_cibles integer[];
    v_rejeu communication."T_Annonce"%ROWTYPE;
    v_id bigint;
    v_publication timestamptz := CURRENT_TIMESTAMP;
    v_cibles_actives bigint;
    v_entreprises bigint;
    v_livraisons bigint;
BEGIN
    SELECT u."Is_Admin" IS TRUE,
           u."Is_staff" IS TRUE OR lower(coalesce(r."NomGenerique", '')) IN ('admin', 'administrateur'),
           u."IdEntiteFk"
    INTO v_global, v_admin, v_entite
    FROM systeme."T_Utilisateurs" u
    LEFT JOIN referentiel."T_Generique" r ON r."ID_Generique" = u."IdRoleFk"
    WHERE u."IdUser" = p_auteur AND u."ValideUser" IS TRUE
    FOR SHARE OF u;

    IF NOT FOUND OR (NOT v_global AND (NOT v_admin OR v_entite IS NULL)) THEN
        RAISE EXCEPTION 'Diffusion réservée aux administrateurs autorisés.' USING ERRCODE = 'PCO01';
    END IF;

    IF p_entites IS NOT NULL THEN
        IF array_ndims(p_entites) IS DISTINCT FROM 1 OR cardinality(p_entites) > 100
            OR EXISTS (SELECT FROM unnest(p_entites) AS ids(id) WHERE id IS NULL OR id <= 0) THEN
            RAISE EXCEPTION 'Sélectionnez des entreprises valides.' USING ERRCODE = 'PCO02';
        END IF;
        v_cibles := ARRAY(SELECT DISTINCT id FROM unnest(p_entites) AS ids(id) ORDER BY id);
    END IF;

    IF NOT v_global AND v_cibles IS DISTINCT FROM ARRAY[v_entite] THEN
        RAISE EXCEPTION 'Vous pouvez uniquement diffuser à votre entreprise.' USING ERRCODE = 'PCO01';
    END IF;

    IF p_cle IS NULL OR v_sujet IS NULL OR char_length(v_sujet) NOT BETWEEN 1 AND 160
        OR v_sujet ~ '[\r\n]' OR v_sujet !~ '\S'
        OR v_contenu IS NULL OR char_length(v_contenu) NOT BETWEEN 1 AND 5000 OR v_contenu !~ '\S' THEN
        RAISE EXCEPTION 'Renseignez un sujet et un message valides.' USING ERRCODE = 'PCO05';
    END IF;

    PERFORM pg_advisory_xact_lock(hashtextextended('communication.annonce:' || p_auteur || ':' || p_cle, 0));
    SELECT a.* INTO v_rejeu
    FROM communication."T_Annonce" a
    WHERE a."IdAuteurFk" = p_auteur AND a."CleRequete" = p_cle;
    IF FOUND THEN
        IF v_rejeu."EmisParPlateforme" IS DISTINCT FROM v_global
            OR v_rejeu."IdEntiteFk" IS DISTINCT FROM (CASE WHEN NOT v_global THEN v_entite END)
            OR v_rejeu."PorteeAnnonce" <> v_portee OR v_rejeu."SujetAnnonce" <> v_sujet
            OR v_rejeu."ContenuAnnonce" <> v_contenu
            OR (v_cibles IS NOT NULL AND v_cibles <> ARRAY(
                SELECT (cible ->> 'id')::integer FROM jsonb_array_elements(v_rejeu."Entreprises") AS cible
                ORDER BY 1
            )) THEN
            RAISE EXCEPTION 'Cette demande de diffusion a déjà un autre contenu ou périmètre.' USING ERRCODE = 'PCO04';
        END IF;
        RETURN QUERY SELECT v_rejeu."IdAnnonce", true;
        RETURN;
    END IF;

    WITH cibles AS MATERIALIZED (
        SELECT e."IdEntite", e."NomEntite"
        FROM systeme."T_Entite" e
        WHERE e."ValideEntite" IS TRUE AND (v_cibles IS NULL OR e."IdEntite" = ANY(v_cibles))
    ),
    audience AS MATERIALIZED (
        SELECT e."IdEntite", e."NomEntite", u."IdUser"
        FROM cibles e
        JOIN systeme."T_Utilisateurs" u ON u."IdEntiteFk" = e."IdEntite" AND u."ValideUser" IS TRUE
    ),
    entreprises AS (
        SELECT DISTINCT "IdEntite", "NomEntite" FROM audience
    ),
    statistiques AS (
        SELECT (SELECT count(*) FROM cibles) AS cibles_actives,
               count(*) AS entreprises,
               (SELECT count(*) FROM audience) AS destinataires,
               jsonb_agg(jsonb_build_object('id', "IdEntite", 'name', "NomEntite") ORDER BY "IdEntite") AS instantane
        FROM entreprises
    ),
    annonce AS (
        INSERT INTO communication."T_Annonce" AS a (
            "IdAuteurFk", "IdEntiteFk", "EmisParPlateforme", "PorteeAnnonce", "SujetAnnonce", "ContenuAnnonce",
            "PublieLe", "CleRequete", "Entreprises", "NombreDestinataires"
        )
        SELECT p_auteur, CASE WHEN NOT v_global THEN v_entite END, v_global, v_portee, v_sujet, v_contenu,
               v_publication, p_cle, s.instantane, s.destinataires
        FROM statistiques s
        WHERE s.destinataires > 0 AND (v_cibles IS NULL OR s.entreprises = cardinality(v_cibles))
        RETURNING a."IdAnnonce"
    ),
    livraisons AS (
        INSERT INTO communication."T_Communication" ("IdAnnonceFk", "IdUserFk", "IdEntiteFk", "DateCommunication")
        SELECT a."IdAnnonce", u."IdUser", u."IdEntite", v_publication AT TIME ZONE 'Africa/Kinshasa'
        FROM annonce a CROSS JOIN audience u
        ORDER BY u."IdUser"
        RETURNING 1
    )
    SELECT a."IdAnnonce", s.cibles_actives, s.entreprises, (SELECT count(*) FROM livraisons)
    INTO v_id, v_cibles_actives, v_entreprises, v_livraisons
    FROM statistiques s LEFT JOIN annonce a ON true;

    IF v_cibles IS NOT NULL AND v_cibles_actives <> cardinality(v_cibles) THEN
        RAISE EXCEPTION 'Une entreprise sélectionnée est inactive ou introuvable.' USING ERRCODE = 'PCO02';
    END IF;
    IF v_id IS NULL OR v_entreprises = 0 OR v_livraisons = 0 THEN
        RAISE EXCEPTION 'Aucun compte actif pour une entreprise destinataire.' USING ERRCODE = 'PCO03';
    END IF;
    INSERT INTO systeme."T_Audit_Log" ("TableName", "Operation", "NewData", "IdEntiteFk")
    VALUES (
        'communication.T_Annonce', 'DIFFUSION',
        jsonb_build_object('IdAnnonce', v_id, 'PorteeAnnonce', v_portee,
                           'NombreDestinataires', v_livraisons, 'NombreEntreprises', v_entreprises,
                           '_actor', jsonb_build_object('IdUser', p_auteur)),
        CASE WHEN NOT v_global THEN v_entite END
    );
    RETURN QUERY SELECT v_id, false;
END
$$;


--
-- Name: FUNCTION fn_diffuser_annonce(p_auteur integer, p_entites integer[], p_sujet text, p_contenu text, p_cle uuid); Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON FUNCTION communication.fn_diffuser_annonce(p_auteur integer, p_entites integer[], p_sujet text, p_contenu text, p_cle uuid) IS 'Publie une annonce et toutes ses notifications dans une seule opération. Contrôle le droit réel de l’auteur, les entreprises actives, les destinataires actifs et le rejeu de la demande. L’audit de diffusion ne contient ni sujet ni texte.';


--
-- Name: fn_lock_discussion_message(); Type: FUNCTION; Schema: communication; Owner: -
--

CREATE FUNCTION communication.fn_lock_discussion_message() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE ids integer[];
BEGIN
 IF TG_OP='INSERT' THEN ids:=ARRAY[NEW."IdDiscussionFk"];
 ELSIF TG_OP='DELETE' THEN ids:=ARRAY[OLD."IdDiscussionFk"];
 ELSE ids:=ARRAY[OLD."IdDiscussionFk",NEW."IdDiscussionFk"]; END IF;
 PERFORM 1 FROM communication."T_Discussion" WHERE "IdDiscussion"=ANY(ids) ORDER BY "IdDiscussion" FOR NO KEY UPDATE;
 IF TG_OP='DELETE' THEN RETURN OLD; END IF; RETURN NEW;
END;$$;


--
-- Name: FUNCTION fn_lock_discussion_message(); Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON FUNCTION communication.fn_lock_discussion_message() IS 'Verrouille les discussions parentes dans l’ordre des identifiants avant une mutation de message, afin de sérialiser le calcul de la dernière activité.';


--
-- Name: fn_sync_dernier_message(); Type: FUNCTION; Schema: communication; Owner: -
--

CREATE FUNCTION communication.fn_sync_dernier_message() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE ids integer[];
BEGIN
 IF TG_OP='INSERT' THEN ids:=ARRAY[NEW."IdDiscussionFk"];
 ELSIF TG_OP='DELETE' THEN ids:=ARRAY[OLD."IdDiscussionFk"];
 ELSE ids:=ARRAY[OLD."IdDiscussionFk",NEW."IdDiscussionFk"]; END IF;
 UPDATE communication."T_Discussion" d SET "DernierMessageAt"=(SELECT max(c."DateChat") FROM communication."T_Chat" c WHERE c."IdDiscussionFk"=d."IdDiscussion")
 WHERE d."IdDiscussion"=ANY(ids);
 RETURN NULL;
END;$$;


--
-- Name: FUNCTION fn_sync_dernier_message(); Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON FUNCTION communication.fn_sync_dernier_message() IS 'Maintient DernierMessageAt égal au maximum des DateChat après insertion, modification, déplacement ou suppression ; NULL quand la discussion n’a plus de message. Le parent est verrouillé par le trigger BEFORE associé.';


--
-- Name: fn_verifier_chat_lecture(); Type: FUNCTION; Schema: communication; Owner: -
--

CREATE FUNCTION communication.fn_verifier_chat_lecture() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF TG_OP = 'UPDATE' THEN
        IF NEW."LuLe" IS DISTINCT FROM OLD."LuLe" THEN
            RAISE EXCEPTION 'La date de première lecture est conservée.'
                USING ERRCODE = '23514', CONSTRAINT = 'ck_chat_lecture_date_immuable';
        END IF;
        RETURN NEW;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM communication."T_Chat" c
        JOIN communication."T_Discussion" d ON d."IdDiscussion" = c."IdDiscussionFk"
        JOIN systeme."T_Utilisateurs" u ON u."IdUser" = NEW."IdUserFk"
        LEFT JOIN systeme."T_Entite" e ON e."IdEntite" = u."IdEntiteFk"
        LEFT JOIN referentiel."T_Generique" r ON r."ID_Generique" = u."IdRoleFk"
        WHERE c."IdChat" = NEW."IdChatFk" AND c."SuiviLectureChat" IS TRUE
          AND c."AuthorIdFk" IS DISTINCT FROM u."IdUser"
          AND d."ValideDiscussion" IS TRUE AND u."ValideUser" IS TRUE
          AND (e."ValideEntite" IS DISTINCT FROM false OR u."Is_Admin" IS TRUE)
          AND (
              (d."TypeDiscussion" = 'user' AND d."IdEntiteFk" = u."IdEntiteFk"
                  AND u."IdUser" IN (d."IdUserClientFk", d."IdUserDestinataireFk"))
              OR (d."TypeDiscussion" IN ('expert', 'structure') AND d."IdUserClientFk" = u."IdUser")
              OR (d."TypeDiscussion" = 'expert' AND EXISTS (
                  SELECT 1 FROM professionnel."T_Professionnel" p
                  WHERE p."IdProfessionnel" = d."IdProfessionnelFk" AND p."IdUserFk" = u."IdUser"))
              OR (d."TypeDiscussion" = 'structure' AND d."IdEntiteFk" = u."IdEntiteFk"
                  AND (u."Is_Admin" IS TRUE OR u."Is_staff" IS TRUE
                       OR lower(r."NomGenerique") IN ('admin', 'administrateur')))
          )
    ) THEN
        RAISE EXCEPTION 'Ce message ne peut pas être marqué comme lu pour ce compte.'
            USING ERRCODE = '23514', CONSTRAINT = 'ck_chat_lecture_participant';
    END IF;

    NEW."LuLe" := clock_timestamp();
    RETURN NEW;
END
$$;


--
-- Name: FUNCTION fn_verifier_chat_lecture(); Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON FUNCTION communication.fn_verifier_chat_lecture() IS 'Contrôle la participation du lecteur et conserve la date de première lecture. Exclut les propres messages et les messages historiques.';


--
-- Name: fn_verifier_creation_discussion_directe(); Type: FUNCTION; Schema: communication; Owner: -
--

CREATE FUNCTION communication.fn_verifier_creation_discussion_directe() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    membres integer;
BEGIN
    SELECT count(*) INTO membres FROM (
        SELECT u."IdUser"
        FROM systeme."T_Utilisateurs" u
        JOIN systeme."T_Entite" e ON e."IdEntite" = u."IdEntiteFk"
        WHERE u."IdUser" IN (NEW."IdUserClientFk", NEW."IdUserDestinataireFk")
            AND u."IdEntiteFk" = NEW."IdEntiteFk"
            AND u."ValideUser" IS TRUE AND e."ValideEntite" IS TRUE
        ORDER BY u."IdUser" FOR SHARE OF u, e
    ) actifs;
    IF membres <> 2 THEN
        RAISE EXCEPTION 'Les deux participants doivent appartenir à la même entreprise active.'
            USING ERRCODE = '23514', CONSTRAINT = 'ck_discussion_directe_membres';
    END IF;
    RETURN NEW;
END;
$$;


--
-- Name: FUNCTION fn_verifier_creation_discussion_directe(); Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON FUNCTION communication.fn_verifier_creation_discussion_directe() IS 'Vérifie les deux comptes et leur entreprise à la création du fil direct, même pour un autre producteur SQL.';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: T_Annonce; Type: TABLE; Schema: communication; Owner: -
--

CREATE TABLE communication."T_Annonce" (
    "IdAnnonce" bigint NOT NULL,
    "IdAuteurFk" integer,
    "IdEntiteFk" integer,
    "EmisParPlateforme" boolean NOT NULL,
    "PorteeAnnonce" text NOT NULL,
    "SujetAnnonce" text NOT NULL,
    "ContenuAnnonce" text NOT NULL,
    "PublieLe" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "CleRequete" uuid NOT NULL,
    "Entreprises" jsonb NOT NULL,
    "NombreDestinataires" bigint NOT NULL,
    CONSTRAINT "T_Annonce_ContenuAnnonce_check" CHECK (((char_length(btrim("ContenuAnnonce")) >= 1) AND (char_length(btrim("ContenuAnnonce")) <= 5000))),
    CONSTRAINT "T_Annonce_Entreprises_check" CHECK (((jsonb_typeof("Entreprises") = 'array'::text) AND (jsonb_array_length("Entreprises") > 0))),
    CONSTRAINT "T_Annonce_NombreDestinataires_check" CHECK (("NombreDestinataires" > 0)),
    CONSTRAINT "T_Annonce_PorteeAnnonce_check" CHECK (("PorteeAnnonce" = ANY (ARRAY['entreprises'::text, 'toutes'::text]))),
    CONSTRAINT "T_Annonce_SujetAnnonce_check" CHECK (((char_length(btrim("SujetAnnonce")) >= 1) AND (char_length(btrim("SujetAnnonce")) <= 160))),
    CONSTRAINT ck_annonce_portee_globale CHECK (((("PorteeAnnonce" <> 'toutes'::text) OR "EmisParPlateforme") AND ((NOT "EmisParPlateforme") OR ("IdEntiteFk" IS NULL))))
);


--
-- Name: TABLE "T_Annonce"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON TABLE communication."T_Annonce" IS 'Publications administratives. Une annonce est enregistrée une fois et distribuée aux comptes actifs lors de sa publication.';


--
-- Name: COLUMN "T_Annonce"."IdAnnonce"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Annonce"."IdAnnonce" IS 'Identifiant de la publication administrative.';


--
-- Name: COLUMN "T_Annonce"."IdAuteurFk"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Annonce"."IdAuteurFk" IS 'Compte ayant publié l’annonce. La publication est conservée après suppression du compte.';


--
-- Name: COLUMN "T_Annonce"."IdEntiteFk"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Annonce"."IdEntiteFk" IS 'Entreprise émettrice lors d’une publication locale. NULL pour une publication de la plateforme ou après retrait de l’entreprise émettrice.';


--
-- Name: COLUMN "T_Annonce"."EmisParPlateforme"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Annonce"."EmisParPlateforme" IS 'Identifie une publication de la plateforme, même si une entreprise ou le compte émetteur sont retirés.';


--
-- Name: COLUMN "T_Annonce"."PorteeAnnonce"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Annonce"."PorteeAnnonce" IS 'Entreprises sélectionnées ou toutes les entreprises actives à la date de publication.';


--
-- Name: COLUMN "T_Annonce"."SujetAnnonce"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Annonce"."SujetAnnonce" IS 'Titre de l’annonce, limité à 160 caractères.';


--
-- Name: COLUMN "T_Annonce"."ContenuAnnonce"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Annonce"."ContenuAnnonce" IS 'Texte de l’annonce, limité à 5 000 caractères et partagé entre ses notifications personnelles.';


--
-- Name: COLUMN "T_Annonce"."PublieLe"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Annonce"."PublieLe" IS 'Instant de publication utilisé pour dater toutes les notifications de l’annonce.';


--
-- Name: COLUMN "T_Annonce"."CleRequete"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Annonce"."CleRequete" IS 'Identifiant de demande unique par auteur pour rejouer une diffusion sans dupliquer les notifications.';


--
-- Name: COLUMN "T_Annonce"."Entreprises"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Annonce"."Entreprises" IS 'Instantané des identifiants et noms des entreprises ayant au moins un destinataire à la publication.';


--
-- Name: COLUMN "T_Annonce"."NombreDestinataires"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Annonce"."NombreDestinataires" IS 'Effectif initial des comptes destinataires, conservé indépendamment des lectures ou changements ultérieurs de rattachement.';


--
-- Name: CONSTRAINT ck_annonce_portee_globale ON "T_Annonce"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON CONSTRAINT ck_annonce_portee_globale ON communication."T_Annonce" IS 'Une publication générale est émise par la plateforme, sans entreprise émettrice.';


--
-- Name: T_Annonce_IdAnnonce_seq; Type: SEQUENCE; Schema: communication; Owner: -
--

ALTER TABLE communication."T_Annonce" ALTER COLUMN "IdAnnonce" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME communication."T_Annonce_IdAnnonce_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: T_Chat; Type: TABLE; Schema: communication; Owner: -
--

CREATE TABLE communication."T_Chat" (
    "IdChat" integer CONSTRAINT "T_Chat_IdChat_not_null" NOT NULL,
    "TextChat" text,
    "ChatFile" text,
    "ChatLink" text,
    "AuthorIdFk" integer,
    "IdDiscussionFk" integer,
    "DateChat" timestamp with time zone DEFAULT now() CONSTRAINT "T_Chat_DateChat_not_null" NOT NULL,
    "LuChat" boolean DEFAULT false CONSTRAINT "T_Chat_LuChat_not_null" NOT NULL,
    "CleRequeteChat" uuid,
    "SuiviLectureChat" boolean DEFAULT true NOT NULL,
    CONSTRAINT ck_chat_contenu_non_vide CHECK (((NULLIF(btrim("TextChat"), ''::text) IS NOT NULL) OR (NULLIF(btrim("ChatFile"), ''::text) IS NOT NULL) OR (NULLIF(btrim("ChatLink"), ''::text) IS NOT NULL)))
);


--
-- Name: TABLE "T_Chat"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON TABLE communication."T_Chat" IS 'Messages des discussions : texte, pièce ou lien, auteur, discussion, date et indicateur de lecture. Grain : un message identifié par IdChat.';


--
-- Name: COLUMN "T_Chat"."IdChat"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Chat"."IdChat" IS 'Identifiant du message.';


--
-- Name: COLUMN "T_Chat"."TextChat"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Chat"."TextChat" IS 'Texte du message de discussion.';


--
-- Name: COLUMN "T_Chat"."ChatFile"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Chat"."ChatFile" IS 'Référence de la pièce jointe au message.';


--
-- Name: COLUMN "T_Chat"."ChatLink"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Chat"."ChatLink" IS 'Lien associé au message.';


--
-- Name: COLUMN "T_Chat"."AuthorIdFk"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Chat"."AuthorIdFk" IS 'Utilisateur auteur du message. Relation imposée : FOREIGN KEY ("AuthorIdFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE SET NULL ON DELETE SET NULL.';


--
-- Name: COLUMN "T_Chat"."IdDiscussionFk"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Chat"."IdDiscussionFk" IS 'Discussion contenant le message. Relation imposée : FOREIGN KEY ("IdDiscussionFk") REFERENCES communication."T_Discussion"("IdDiscussion") ON UPDATE CASCADE ON DELETE CASCADE.';


--
-- Name: COLUMN "T_Chat"."DateChat"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Chat"."DateChat" IS 'Date et heure du message avec fuseau horaire.';


--
-- Name: COLUMN "T_Chat"."LuChat"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Chat"."LuChat" IS 'Indicateur historique conservé pour compatibilité. Les lectures individuelles sont enregistrées dans T_ChatLecture.';


--
-- Name: COLUMN "T_Chat"."CleRequeteChat"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Chat"."CleRequeteChat" IS 'Clé de rejeu facultative d’un envoi, propre au fil et à son auteur. Les anciens messages n’en ont pas.';


--
-- Name: COLUMN "T_Chat"."SuiviLectureChat"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Chat"."SuiviLectureChat" IS 'Active le suivi individuel des nouveaux messages. Les messages antérieurs à son installation sont exclus des non-lus.';


--
-- Name: CONSTRAINT "T_Chat_IdChat_not_null" ON "T_Chat"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON CONSTRAINT "T_Chat_IdChat_not_null" ON communication."T_Chat" IS 'Non-nullité : exige une valeur renseignée dans "communication"."T_Chat". Définition : NOT NULL "IdChat".';


--
-- Name: CONSTRAINT "T_Chat_DateChat_not_null" ON "T_Chat"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON CONSTRAINT "T_Chat_DateChat_not_null" ON communication."T_Chat" IS 'Non-nullité : exige une valeur renseignée dans "communication"."T_Chat". Définition : NOT NULL "DateChat".';


--
-- Name: CONSTRAINT "T_Chat_LuChat_not_null" ON "T_Chat"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON CONSTRAINT "T_Chat_LuChat_not_null" ON communication."T_Chat" IS 'Non-nullité : exige une valeur renseignée dans "communication"."T_Chat". Définition : NOT NULL "LuChat".';


--
-- Name: CONSTRAINT ck_chat_contenu_non_vide ON "T_Chat"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON CONSTRAINT ck_chat_contenu_non_vide ON communication."T_Chat" IS 'Intégrité imposée par PostgreSQL : CHECK (NULLIF(btrim("TextChat"), ''''::text) IS NOT NULL OR NULLIF(btrim("ChatFile"), ''''::text) IS NOT NULL OR NULLIF(btrim("ChatLink"), ''''::text) IS NOT NULL)';


--
-- Name: T_ChatLecture; Type: TABLE; Schema: communication; Owner: -
--

CREATE TABLE communication."T_ChatLecture" (
    "IdChatFk" integer NOT NULL,
    "IdUserFk" integer NOT NULL,
    "LuLe" timestamp with time zone DEFAULT clock_timestamp() NOT NULL
);


--
-- Name: TABLE "T_ChatLecture"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON TABLE communication."T_ChatLecture" IS 'Première lecture d’un message par un compte participant. Chaque lecteur est suivi séparément, y compris lorsque plusieurs personnes reçoivent les messages d’une structure.';


--
-- Name: COLUMN "T_ChatLecture"."IdChatFk"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_ChatLecture"."IdChatFk" IS 'Identifiant du message suivi.';


--
-- Name: COLUMN "T_ChatLecture"."IdUserFk"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_ChatLecture"."IdUserFk" IS 'Identifiant du compte qui a lu le message.';


--
-- Name: COLUMN "T_ChatLecture"."LuLe"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_ChatLecture"."LuLe" IS 'Date et heure de la première lecture enregistrée par PostgreSQL.';


--
-- Name: T_Chat_IdChat_seq; Type: SEQUENCE; Schema: communication; Owner: -
--

ALTER TABLE communication."T_Chat" ALTER COLUMN "IdChat" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME communication."T_Chat_IdChat_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: SEQUENCE "T_Chat_IdChat_seq"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON SEQUENCE communication."T_Chat_IdChat_seq" IS 'Séquence de génération de "communication"."T_Chat"."IdChat". Les valeurs produites identifient les enregistrements ; les écarts de numérotation ne prouvent pas une suppression.';


--
-- Name: T_Communication; Type: TABLE; Schema: communication; Owner: -
--

CREATE TABLE communication."T_Communication" (
    "IdCommunication" integer CONSTRAINT "T_Communication_IdCommunication_not_null" NOT NULL,
    "IdUserFk" integer,
    "IdTypeCommunication" integer,
    "ContenuCommunication" text,
    "DateCommunication" timestamp without time zone DEFAULT CURRENT_TIMESTAMP CONSTRAINT "T_Communication_DateCommunication_not_null" NOT NULL,
    "ObsCommunication" text,
    "ValideCommunication" boolean DEFAULT true CONSTRAINT "T_Communication_ValideCommunication_not_null" NOT NULL,
    "LectureCommunication" boolean DEFAULT false CONSTRAINT "T_Communication_LectureCommunication_not_null" NOT NULL,
    "IdEntiteFk" integer,
    "IdAnnonceFk" bigint,
    "LuLe" timestamp with time zone,
    CONSTRAINT ck_comm_annonce_contenu CHECK ((("IdAnnonceFk" IS NULL) OR ("ContenuCommunication" IS NULL))),
    CONSTRAINT ck_comm_annonce_lecture CHECK ((("IdAnnonceFk" IS NULL) OR ("LectureCommunication" = ("LuLe" IS NOT NULL))))
);


--
-- Name: TABLE "T_Communication"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON TABLE communication."T_Communication" IS 'Notifications individuelles, autonomes ou issues d’une annonce administrative. Distinctes des messages de discussion.';


--
-- Name: COLUMN "T_Communication"."IdCommunication"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Communication"."IdCommunication" IS 'Identifiant de la communication ou notification.';


--
-- Name: COLUMN "T_Communication"."IdUserFk"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Communication"."IdUserFk" IS 'Utilisateur rattaché à l’enregistrement. Relation imposée : FOREIGN KEY ("IdUserFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE ON DELETE SET NULL.';


--
-- Name: COLUMN "T_Communication"."IdTypeCommunication"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Communication"."IdTypeCommunication" IS 'Type de communication dans le référentiel. Relation imposée : FOREIGN KEY ("IdTypeCommunication") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE ON DELETE SET NULL.';


--
-- Name: COLUMN "T_Communication"."ContenuCommunication"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Communication"."ContenuCommunication" IS 'Texte d’une notification autonome. Le texte partagé d’une annonce appartient à T_Annonce.';


--
-- Name: COLUMN "T_Communication"."DateCommunication"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Communication"."DateCommunication" IS 'Date et heure d’enregistrement de la communication.';


--
-- Name: COLUMN "T_Communication"."ObsCommunication"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Communication"."ObsCommunication" IS 'Observations enregistrées sur la communication.';


--
-- Name: COLUMN "T_Communication"."ValideCommunication"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Communication"."ValideCommunication" IS 'Indique si la communication est déclaré valide/actif dans le registre ; distinct des qualifications calculées dans les vues.';


--
-- Name: COLUMN "T_Communication"."LectureCommunication"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Communication"."LectureCommunication" IS 'Indique si la communication est marquée comme lue.';


--
-- Name: COLUMN "T_Communication"."IdEntiteFk"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Communication"."IdEntiteFk" IS 'Entité de rattachement de l’enregistrement. Relation imposée : FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON UPDATE CASCADE ON DELETE SET NULL.';


--
-- Name: COLUMN "T_Communication"."IdAnnonceFk"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Communication"."IdAnnonceFk" IS 'Source du titre et du corps pour une annonce distribuée. NULL pour les notifications historiques ou autonomes.';


--
-- Name: COLUMN "T_Communication"."LuLe"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Communication"."LuLe" IS 'Date de la première lecture d’une notification issue d’une annonce. NULL si non lue ou pour une notification autonome.';


--
-- Name: CONSTRAINT "T_Communication_IdCommunication_not_null" ON "T_Communication"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON CONSTRAINT "T_Communication_IdCommunication_not_null" ON communication."T_Communication" IS 'Non-nullité : exige une valeur renseignée dans "communication"."T_Communication". Définition : NOT NULL "IdCommunication".';


--
-- Name: CONSTRAINT "T_Communication_DateCommunication_not_null" ON "T_Communication"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON CONSTRAINT "T_Communication_DateCommunication_not_null" ON communication."T_Communication" IS 'Non-nullité : exige une valeur renseignée dans "communication"."T_Communication". Définition : NOT NULL "DateCommunication".';


--
-- Name: CONSTRAINT "T_Communication_ValideCommunication_not_null" ON "T_Communication"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON CONSTRAINT "T_Communication_ValideCommunication_not_null" ON communication."T_Communication" IS 'Non-nullité : exige une valeur renseignée dans "communication"."T_Communication". Définition : NOT NULL "ValideCommunication".';


--
-- Name: CONSTRAINT "T_Communication_LectureCommunication_not_null" ON "T_Communication"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON CONSTRAINT "T_Communication_LectureCommunication_not_null" ON communication."T_Communication" IS 'Non-nullité : exige une valeur renseignée dans "communication"."T_Communication". Définition : NOT NULL "LectureCommunication".';


--
-- Name: CONSTRAINT ck_comm_annonce_contenu ON "T_Communication"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON CONSTRAINT ck_comm_annonce_contenu ON communication."T_Communication" IS 'Le corps d’une annonce est enregistré seulement dans sa publication source.';


--
-- Name: CONSTRAINT ck_comm_annonce_lecture ON "T_Communication"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON CONSTRAINT ck_comm_annonce_lecture ON communication."T_Communication" IS 'La date de lecture et l’état de lecture doivent concorder pour une annonce.';


--
-- Name: T_Communication_IdCommunication_seq; Type: SEQUENCE; Schema: communication; Owner: -
--

ALTER TABLE communication."T_Communication" ALTER COLUMN "IdCommunication" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME communication."T_Communication_IdCommunication_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: SEQUENCE "T_Communication_IdCommunication_seq"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON SEQUENCE communication."T_Communication_IdCommunication_seq" IS 'Séquence de génération de "communication"."T_Communication"."IdCommunication". Les valeurs produites identifient les enregistrements ; les écarts de numérotation ne prouvent pas une suppression.';


--
-- Name: T_Discussion; Type: TABLE; Schema: communication; Owner: -
--

CREATE TABLE communication."T_Discussion" (
    "IdDiscussion" integer CONSTRAINT "T_Discussion_IdDiscussion_not_null" NOT NULL,
    "IdUserClientFk" integer,
    "IdProfessionnelFk" integer,
    "IdEntiteFk" integer,
    "TypeDiscussion" character varying(30) CONSTRAINT "T_Discussion_TypeDiscussion_not_null" NOT NULL,
    "SujetDiscussion" character varying(255),
    "DateCreation" timestamp with time zone DEFAULT now() CONSTRAINT "T_Discussion_DateCreation_not_null" NOT NULL,
    "DernierMessageAt" timestamp with time zone,
    "ValideDiscussion" boolean DEFAULT true CONSTRAINT "T_Discussion_ValideDiscussion_not_null" NOT NULL,
    "IdUserDestinataireFk" integer,
    CONSTRAINT "Ck_Discussion_Target" CHECK ((((("TypeDiscussion")::text = 'expert'::text) AND ("IdProfessionnelFk" IS NOT NULL) AND ("IdEntiteFk" IS NULL) AND ("IdUserDestinataireFk" IS NULL)) OR ((("TypeDiscussion")::text = 'structure'::text) AND ("IdEntiteFk" IS NOT NULL) AND ("IdProfessionnelFk" IS NULL) AND ("IdUserDestinataireFk" IS NULL)) OR ((("TypeDiscussion")::text = 'user'::text) AND ("IdProfessionnelFk" IS NULL) AND (("IdUserClientFk" IS NULL) OR ("IdUserDestinataireFk" IS NULL) OR ("IdUserClientFk" <> "IdUserDestinataireFk"))))),
    CONSTRAINT "Ck_Discussion_Type" CHECK ("TypeDiscussion" IN ('expert', 'structure', 'user'))
);


--
-- Name: TABLE "T_Discussion"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON TABLE communication."T_Discussion" IS 'Un fil privé par échange avec un compte, un professionnel ou une structure. Les deux comptes d’un fil direct sont ses seuls participants.';


--
-- Name: COLUMN "T_Discussion"."IdDiscussion"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Discussion"."IdDiscussion" IS 'Identifiant du fil de discussion.';


--
-- Name: COLUMN "T_Discussion"."IdUserClientFk"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Discussion"."IdUserClientFk" IS 'Utilisateur client à l’origine du fil de discussion. Relation imposée : FOREIGN KEY ("IdUserClientFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE ON DELETE SET NULL.';


--
-- Name: COLUMN "T_Discussion"."IdProfessionnelFk"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Discussion"."IdProfessionnelFk" IS 'Professionnel rattaché à la discussion ou à l’entité. Relation imposée : FOREIGN KEY ("IdProfessionnelFk") REFERENCES professionnel."T_Professionnel"("IdProfessionnel") ON UPDATE CASCADE ON DELETE SET NULL.';


--
-- Name: COLUMN "T_Discussion"."IdEntiteFk"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Discussion"."IdEntiteFk" IS 'Structure destinataire pour un fil structure. Entreprise commune à la création pour un fil direct.';


--
-- Name: COLUMN "T_Discussion"."TypeDiscussion"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Discussion"."TypeDiscussion" IS 'Canal privé : expert, structure ou user. Le canal détermine les clés de rattachement.';


--
-- Name: COLUMN "T_Discussion"."SujetDiscussion"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Discussion"."SujetDiscussion" IS 'Sujet ou titre du fil de discussion.';


--
-- Name: COLUMN "T_Discussion"."DateCreation"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Discussion"."DateCreation" IS 'Horodatage de création de la discussion avec fuseau horaire.';


--
-- Name: COLUMN "T_Discussion"."DernierMessageAt"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Discussion"."DernierMessageAt" IS 'Horodatage du dernier message associé à la discussion.';


--
-- Name: COLUMN "T_Discussion"."ValideDiscussion"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Discussion"."ValideDiscussion" IS 'Indique si la discussion est déclaré valide/actif dans le registre ; distinct des qualifications calculées dans les vues.';


--
-- Name: COLUMN "T_Discussion"."IdUserDestinataireFk"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Discussion"."IdUserDestinataireFk" IS 'Second compte participant à un fil direct. Absent pour les fils professionnels et structures ou si le compte a été supprimé.';


--
-- Name: CONSTRAINT "T_Discussion_IdDiscussion_not_null" ON "T_Discussion"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON CONSTRAINT "T_Discussion_IdDiscussion_not_null" ON communication."T_Discussion" IS 'Non-nullité : exige une valeur renseignée dans "communication"."T_Discussion". Définition : NOT NULL "IdDiscussion".';


--
-- Name: CONSTRAINT "T_Discussion_TypeDiscussion_not_null" ON "T_Discussion"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON CONSTRAINT "T_Discussion_TypeDiscussion_not_null" ON communication."T_Discussion" IS 'Non-nullité : exige une valeur renseignée dans "communication"."T_Discussion". Définition : NOT NULL "TypeDiscussion".';


--
-- Name: CONSTRAINT "T_Discussion_DateCreation_not_null" ON "T_Discussion"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON CONSTRAINT "T_Discussion_DateCreation_not_null" ON communication."T_Discussion" IS 'Non-nullité : exige une valeur renseignée dans "communication"."T_Discussion". Définition : NOT NULL "DateCreation".';


--
-- Name: CONSTRAINT "T_Discussion_ValideDiscussion_not_null" ON "T_Discussion"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON CONSTRAINT "T_Discussion_ValideDiscussion_not_null" ON communication."T_Discussion" IS 'Non-nullité : exige une valeur renseignée dans "communication"."T_Discussion". Définition : NOT NULL "ValideDiscussion".';


--
-- Name: CONSTRAINT "Ck_Discussion_Target" ON "T_Discussion"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON CONSTRAINT "Ck_Discussion_Target" ON communication."T_Discussion" IS 'Contrôle la forme du destinataire et interdit de s’écrire à soi-même. Un compte supprimé ne fait pas disparaître l’historique.';


--
-- Name: CONSTRAINT "Ck_Discussion_Type" ON "T_Discussion"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON CONSTRAINT "Ck_Discussion_Type" ON communication."T_Discussion" IS 'Limite les fils privés aux trois canaux gérés.';


--
-- Name: T_Discussion_IdDiscussion_seq; Type: SEQUENCE; Schema: communication; Owner: -
--

ALTER TABLE communication."T_Discussion" ALTER COLUMN "IdDiscussion" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME communication."T_Discussion_IdDiscussion_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: SEQUENCE "T_Discussion_IdDiscussion_seq"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON SEQUENCE communication."T_Discussion_IdDiscussion_seq" IS 'Séquence de génération de "communication"."T_Discussion"."IdDiscussion". Les valeurs produites identifient les enregistrements ; les écarts de numérotation ne prouvent pas une suppression.';


--
-- Name: T_ChatLecture Pk_ChatLecture; Type: CONSTRAINT; Schema: communication; Owner: -
--

ALTER TABLE ONLY communication."T_ChatLecture"
    ADD CONSTRAINT "Pk_ChatLecture" PRIMARY KEY ("IdChatFk", "IdUserFk");


--
-- Name: CONSTRAINT "Pk_ChatLecture" ON "T_ChatLecture"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON CONSTRAINT "Pk_ChatLecture" ON communication."T_ChatLecture" IS 'Une seule lecture par message et par compte, y compris en cas de rejeu.';


--
-- Name: T_Communication Pk_IdCommunication; Type: CONSTRAINT; Schema: communication; Owner: -
--

ALTER TABLE ONLY communication."T_Communication"
    ADD CONSTRAINT "Pk_IdCommunication" PRIMARY KEY ("IdCommunication");


--
-- Name: CONSTRAINT "Pk_IdCommunication" ON "T_Communication"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON CONSTRAINT "Pk_IdCommunication" ON communication."T_Communication" IS 'Clé primaire : identifie de manière unique chaque ligne dans "communication"."T_Communication". Définition : PRIMARY KEY ("IdCommunication").';


--
-- Name: T_Annonce T_Annonce_pkey; Type: CONSTRAINT; Schema: communication; Owner: -
--

ALTER TABLE ONLY communication."T_Annonce"
    ADD CONSTRAINT "T_Annonce_pkey" PRIMARY KEY ("IdAnnonce");


--
-- Name: T_Chat T_Chat_pkey; Type: CONSTRAINT; Schema: communication; Owner: -
--

ALTER TABLE ONLY communication."T_Chat"
    ADD CONSTRAINT "T_Chat_pkey" PRIMARY KEY ("IdChat");


--
-- Name: CONSTRAINT "T_Chat_pkey" ON "T_Chat"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON CONSTRAINT "T_Chat_pkey" ON communication."T_Chat" IS 'Clé primaire : identifie de manière unique chaque ligne dans "communication"."T_Chat". Définition : PRIMARY KEY ("IdChat").';


--
-- Name: T_Discussion T_Discussion_pkey; Type: CONSTRAINT; Schema: communication; Owner: -
--

ALTER TABLE ONLY communication."T_Discussion"
    ADD CONSTRAINT "T_Discussion_pkey" PRIMARY KEY ("IdDiscussion");


--
-- Name: CONSTRAINT "T_Discussion_pkey" ON "T_Discussion"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON CONSTRAINT "T_Discussion_pkey" ON communication."T_Discussion" IS 'Clé primaire : identifie de manière unique chaque ligne dans "communication"."T_Discussion". Définition : PRIMARY KEY ("IdDiscussion").';


--
-- Name: T_Annonce uq_annonce_auteur_requete; Type: CONSTRAINT; Schema: communication; Owner: -
--

ALTER TABLE ONLY communication."T_Annonce"
    ADD CONSTRAINT uq_annonce_auteur_requete UNIQUE ("IdAuteurFk", "CleRequete");


--
-- Name: CONSTRAINT uq_annonce_auteur_requete ON "T_Annonce"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON CONSTRAINT uq_annonce_auteur_requete ON communication."T_Annonce" IS 'Identifie le rejeu d’une demande par son auteur et sa clé.';


--
-- Name: INDEX "Pk_IdCommunication"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON INDEX communication."Pk_IdCommunication" IS 'Index support de la clé primaire sur "communication"."T_Communication". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX "Pk_IdCommunication" ON communication."T_Communication" USING btree ("IdCommunication").';


--
-- Name: INDEX "T_Chat_pkey"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON INDEX communication."T_Chat_pkey" IS 'Index support de la clé primaire sur "communication"."T_Chat". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX "T_Chat_pkey" ON communication."T_Chat" USING btree ("IdChat").';


--
-- Name: INDEX "T_Discussion_pkey"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON INDEX communication."T_Discussion_pkey" IS 'Index support de la clé primaire sur "communication"."T_Discussion". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX "T_Discussion_pkey" ON communication."T_Discussion" USING btree ("IdDiscussion").';


--
-- Name: idx_annonce_entite_publication; Type: INDEX; Schema: communication; Owner: -
--

CREATE INDEX idx_annonce_entite_publication ON communication."T_Annonce" USING btree ("IdEntiteFk", "PublieLe" DESC, "IdAnnonce" DESC);


--
-- Name: INDEX idx_annonce_entite_publication; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON INDEX communication.idx_annonce_entite_publication IS 'Accès à l’historique des publications locales par date et entreprise émettrice.';


--
-- Name: idx_chat_author; Type: INDEX; Schema: communication; Owner: -
--

CREATE INDEX idx_chat_author ON communication."T_Chat" USING btree ("AuthorIdFk");


--
-- Name: INDEX idx_chat_author; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON INDEX communication.idx_chat_author IS 'Index d’accès sur "communication"."T_Chat". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_chat_author ON communication."T_Chat" USING btree ("AuthorIdFk").';


--
-- Name: idx_chat_author_idchat_desc; Type: INDEX; Schema: communication; Owner: -
--

CREATE INDEX idx_chat_author_idchat_desc ON communication."T_Chat" USING btree ("AuthorIdFk", "IdChat" DESC);


--
-- Name: INDEX idx_chat_author_idchat_desc; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON INDEX communication.idx_chat_author_idchat_desc IS 'Index d’accès sur "communication"."T_Chat". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_chat_author_idchat_desc ON communication."T_Chat" USING btree ("AuthorIdFk", "IdChat" DESC).';


--
-- Name: idx_chat_discussion_date; Type: INDEX; Schema: communication; Owner: -
--

CREATE INDEX idx_chat_discussion_date ON communication."T_Chat" USING btree ("IdDiscussionFk", "DateChat");


--
-- Name: INDEX idx_chat_discussion_date; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON INDEX communication.idx_chat_discussion_date IS 'Index d’accès sur "communication"."T_Chat". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_chat_discussion_date ON communication."T_Chat" USING btree ("IdDiscussionFk", "DateChat").';


--
-- Name: idx_chat_discussion_idchat; Type: INDEX; Schema: communication; Owner: -
--

CREATE INDEX idx_chat_discussion_idchat ON communication."T_Chat" USING btree ("IdDiscussionFk", "IdChat");


--
-- Name: INDEX idx_chat_discussion_idchat; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON INDEX communication.idx_chat_discussion_idchat IS 'Index d’accès sur "communication"."T_Chat". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_chat_discussion_idchat ON communication."T_Chat" USING btree ("IdDiscussionFk", "IdChat").';


--
-- Name: idx_chat_lecture_utilisateur; Type: INDEX; Schema: communication; Owner: -
--

CREATE INDEX idx_chat_lecture_utilisateur ON communication."T_ChatLecture" USING btree ("IdUserFk", "IdChatFk");


--
-- Name: INDEX idx_chat_lecture_utilisateur; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON INDEX communication.idx_chat_lecture_utilisateur IS 'Accès aux messages lus par un compte et aux lectures concernées par une suppression du compte.';


--
-- Name: idx_chat_suivi_discussion_message; Type: INDEX; Schema: communication; Owner: -
--

CREATE INDEX idx_chat_suivi_discussion_message ON communication."T_Chat" USING btree ("IdDiscussionFk", "IdChat") INCLUDE ("AuthorIdFk") WHERE ("SuiviLectureChat" IS TRUE);


--
-- Name: INDEX idx_chat_suivi_discussion_message; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON INDEX communication.idx_chat_suivi_discussion_message IS 'Recherche des nouveaux messages d’une discussion pour le calcul des non-lus.';


--
-- Name: idx_comm_date; Type: INDEX; Schema: communication; Owner: -
--

CREATE INDEX idx_comm_date ON communication."T_Communication" USING btree ("DateCommunication");


--
-- Name: INDEX idx_comm_date; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON INDEX communication.idx_comm_date IS 'Index d’accès sur "communication"."T_Communication". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_comm_date ON communication."T_Communication" USING btree ("DateCommunication").';


--
-- Name: idx_comm_entite; Type: INDEX; Schema: communication; Owner: -
--

CREATE INDEX idx_comm_entite ON communication."T_Communication" USING btree ("IdEntiteFk");


--
-- Name: INDEX idx_comm_entite; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON INDEX communication.idx_comm_entite IS 'Index d’accès sur "communication"."T_Communication". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_comm_entite ON communication."T_Communication" USING btree ("IdEntiteFk").';


--
-- Name: idx_comm_type; Type: INDEX; Schema: communication; Owner: -
--

CREATE INDEX idx_comm_type ON communication."T_Communication" USING btree ("IdTypeCommunication");


--
-- Name: INDEX idx_comm_type; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON INDEX communication.idx_comm_type IS 'Index d’accès sur "communication"."T_Communication". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_comm_type ON communication."T_Communication" USING btree ("IdTypeCommunication").';


--
-- Name: idx_comm_user; Type: INDEX; Schema: communication; Owner: -
--

CREATE INDEX idx_comm_user ON communication."T_Communication" USING btree ("IdUserFk");


--
-- Name: INDEX idx_comm_user; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON INDEX communication.idx_comm_user IS 'Index d’accès sur "communication"."T_Communication". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_comm_user ON communication."T_Communication" USING btree ("IdUserFk").';


--
-- Name: idx_comm_user_unread; Type: INDEX; Schema: communication; Owner: -
--

CREATE INDEX idx_comm_user_unread ON communication."T_Communication" USING btree ("IdUserFk", "DateCommunication" DESC) WHERE ("LectureCommunication" = false);


--
-- Name: INDEX idx_comm_user_unread; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON INDEX communication.idx_comm_user_unread IS 'Index d’accès sur "communication"."T_Communication". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_comm_user_unread ON communication."T_Communication" USING btree ("IdUserFk", "DateCommunication" DESC) WHERE ("LectureCommunication" = false).';


--
-- Name: idx_discussion_dernier_message; Type: INDEX; Schema: communication; Owner: -
--

CREATE INDEX idx_discussion_dernier_message ON communication."T_Discussion" USING btree ("DernierMessageAt" DESC);


--
-- Name: INDEX idx_discussion_dernier_message; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON INDEX communication.idx_discussion_dernier_message IS 'Index d’accès sur "communication"."T_Discussion". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_discussion_dernier_message ON communication."T_Discussion" USING btree ("DernierMessageAt" DESC).';


--
-- Name: idx_discussion_entite; Type: INDEX; Schema: communication; Owner: -
--

CREATE INDEX idx_discussion_entite ON communication."T_Discussion" USING btree ("IdEntiteFk");


--
-- Name: INDEX idx_discussion_entite; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON INDEX communication.idx_discussion_entite IS 'Index d’accès sur "communication"."T_Discussion". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_discussion_entite ON communication."T_Discussion" USING btree ("IdEntiteFk").';


--
-- Name: idx_discussion_professionnel; Type: INDEX; Schema: communication; Owner: -
--

CREATE INDEX idx_discussion_professionnel ON communication."T_Discussion" USING btree ("IdProfessionnelFk");


--
-- Name: INDEX idx_discussion_professionnel; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON INDEX communication.idx_discussion_professionnel IS 'Index d’accès sur "communication"."T_Discussion". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_discussion_professionnel ON communication."T_Discussion" USING btree ("IdProfessionnelFk").';


--
-- Name: idx_discussion_user_client; Type: INDEX; Schema: communication; Owner: -
--

CREATE INDEX idx_discussion_user_client ON communication."T_Discussion" USING btree ("IdUserClientFk");


--
-- Name: INDEX idx_discussion_user_client; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON INDEX communication.idx_discussion_user_client IS 'Index d’accès sur "communication"."T_Discussion". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_discussion_user_client ON communication."T_Discussion" USING btree ("IdUserClientFk").';


--
-- Name: idx_discussion_user_destinataire; Type: INDEX; Schema: communication; Owner: -
--

CREATE INDEX idx_discussion_user_destinataire ON communication."T_Discussion" USING btree ("IdUserDestinataireFk") WHERE ("IdUserDestinataireFk" IS NOT NULL);


--
-- Name: INDEX idx_discussion_user_destinataire; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON INDEX communication.idx_discussion_user_destinataire IS 'Accès aux fils directs du second participant.';


--
-- Name: uq_chat_requete_auteur_discussion; Type: INDEX; Schema: communication; Owner: -
--

CREATE UNIQUE INDEX uq_chat_requete_auteur_discussion ON communication."T_Chat" USING btree ("IdDiscussionFk", "AuthorIdFk", "CleRequeteChat") WHERE ("CleRequeteChat" IS NOT NULL);


--
-- Name: INDEX uq_chat_requete_auteur_discussion; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON INDEX communication.uq_chat_requete_auteur_discussion IS 'Empêche de dupliquer un envoi après une réponse réseau incertaine.';


--
-- Name: uq_comm_annonce_destinataire; Type: INDEX; Schema: communication; Owner: -
--

CREATE UNIQUE INDEX uq_comm_annonce_destinataire ON communication."T_Communication" USING btree ("IdAnnonceFk", "IdUserFk") WHERE ("IdAnnonceFk" IS NOT NULL);


--
-- Name: INDEX uq_comm_annonce_destinataire; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON INDEX communication.uq_comm_annonce_destinataire IS 'Empêche une même annonce d’être distribuée deux fois à un compte.';


--
-- Name: uq_discussion_client_entite; Type: INDEX; Schema: communication; Owner: -
--

CREATE UNIQUE INDEX uq_discussion_client_entite ON communication."T_Discussion" USING btree ("IdUserClientFk", "IdEntiteFk") WHERE ((("TypeDiscussion")::text = 'structure'::text) AND ("ValideDiscussion" = true) AND ("IdUserClientFk" IS NOT NULL) AND ("IdEntiteFk" IS NOT NULL));


--
-- Name: INDEX uq_discussion_client_entite; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON INDEX communication.uq_discussion_client_entite IS 'Index d’unicité sur "communication"."T_Discussion". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX uq_discussion_client_entite ON communication."T_Discussion" USING btree ("IdUserClientFk", "IdEntiteFk") WHERE ((("TypeDiscussion")::text = ''structure''::text) AND ("ValideDiscussion" = true) AND ("IdUserClientFk" IS NOT NULL) AND ("IdEntiteFk" IS NOT NULL)).';


--
-- Name: uq_discussion_client_expert; Type: INDEX; Schema: communication; Owner: -
--

CREATE UNIQUE INDEX uq_discussion_client_expert ON communication."T_Discussion" USING btree ("IdUserClientFk", "IdProfessionnelFk") WHERE ((("TypeDiscussion")::text = 'expert'::text) AND ("ValideDiscussion" = true) AND ("IdUserClientFk" IS NOT NULL) AND ("IdProfessionnelFk" IS NOT NULL));


--
-- Name: INDEX uq_discussion_client_expert; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON INDEX communication.uq_discussion_client_expert IS 'Index d’unicité sur "communication"."T_Discussion". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX uq_discussion_client_expert ON communication."T_Discussion" USING btree ("IdUserClientFk", "IdProfessionnelFk") WHERE ((("TypeDiscussion")::text = ''expert''::text) AND ("ValideDiscussion" = true) AND ("IdUserClientFk" IS NOT NULL) AND ("IdProfessionnelFk" IS NOT NULL)).';


--
-- Name: uq_discussion_directe_entreprise; Type: INDEX; Schema: communication; Owner: -
--

CREATE UNIQUE INDEX uq_discussion_directe_entreprise ON communication."T_Discussion" USING btree ("IdEntiteFk", LEAST("IdUserClientFk", "IdUserDestinataireFk"), GREATEST("IdUserClientFk", "IdUserDestinataireFk")) WHERE ((("TypeDiscussion")::text = 'user'::text) AND "ValideDiscussion" AND ("IdUserClientFk" IS NOT NULL) AND ("IdUserDestinataireFk" IS NOT NULL));


--
-- Name: INDEX uq_discussion_directe_entreprise; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON INDEX communication.uq_discussion_directe_entreprise IS 'Un seul fil direct actif par paire de comptes et entreprise, dans les deux sens.';


--
-- Name: T_Communication aa_reference_champ; Type: TRIGGER; Schema: communication; Owner: -
--

CREATE TRIGGER aa_reference_champ BEFORE INSERT OR UPDATE ON communication."T_Communication" FOR EACH ROW EXECUTE FUNCTION referentiel.tr_valider_champ_referentiel();


--
-- Name: TRIGGER aa_reference_champ ON "T_Communication"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON TRIGGER aa_reference_champ ON communication."T_Communication" IS 'Valide les nouvelles références du catalogue physique ; conserve les valeurs historiques inchangées, même devenues hors famille.';


--
-- Name: T_Chat tr_00_lock_discussion_message; Type: TRIGGER; Schema: communication; Owner: -
--

CREATE TRIGGER tr_00_lock_discussion_message BEFORE INSERT OR DELETE OR UPDATE ON communication."T_Chat" FOR EACH ROW EXECUTE FUNCTION communication.fn_lock_discussion_message();


--
-- Name: TRIGGER tr_00_lock_discussion_message ON "T_Chat"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON TRIGGER tr_00_lock_discussion_message ON communication."T_Chat" IS 'Verrou des discussions avant modification de leurs messages.';


--
-- Name: T_Communication tr_dater_lecture_annonce; Type: TRIGGER; Schema: communication; Owner: -
--

CREATE TRIGGER tr_dater_lecture_annonce BEFORE UPDATE OF "LectureCommunication", "LuLe" ON communication."T_Communication" FOR EACH ROW EXECUTE FUNCTION communication.fn_dater_lecture_annonce();


--
-- Name: TRIGGER tr_dater_lecture_annonce ON "T_Communication"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON TRIGGER tr_dater_lecture_annonce ON communication."T_Communication" IS 'Conserve l’instant de la première lecture de chaque annonce reçue.';


--
-- Name: T_Chat tr_sync_dernier_message; Type: TRIGGER; Schema: communication; Owner: -
--

CREATE TRIGGER tr_sync_dernier_message AFTER INSERT OR DELETE OR UPDATE ON communication."T_Chat" FOR EACH ROW EXECUTE FUNCTION communication.fn_sync_dernier_message();


--
-- Name: TRIGGER tr_sync_dernier_message ON "T_Chat"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON TRIGGER tr_sync_dernier_message ON communication."T_Chat" IS 'Synchronise la dernière activité avec les messages effectivement présents.';


--
-- Name: T_ChatLecture tr_verifier_chat_lecture; Type: TRIGGER; Schema: communication; Owner: -
--

CREATE TRIGGER tr_verifier_chat_lecture BEFORE INSERT OR UPDATE OF "LuLe" ON communication."T_ChatLecture" FOR EACH ROW EXECUTE FUNCTION communication.fn_verifier_chat_lecture();


--
-- Name: TRIGGER tr_verifier_chat_lecture ON "T_ChatLecture"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON TRIGGER tr_verifier_chat_lecture ON communication."T_ChatLecture" IS 'Vérifie toute nouvelle lecture et empêche de modifier sa date.';


--
-- Name: T_Discussion tr_verifier_creation_discussion_directe; Type: TRIGGER; Schema: communication; Owner: -
--

CREATE TRIGGER tr_verifier_creation_discussion_directe BEFORE INSERT ON communication."T_Discussion" FOR EACH ROW WHEN (((new."TypeDiscussion")::text = 'user'::text)) EXECUTE FUNCTION communication.fn_verifier_creation_discussion_directe();


--
-- Name: TRIGGER tr_verifier_creation_discussion_directe ON "T_Discussion"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON TRIGGER tr_verifier_creation_discussion_directe ON communication."T_Discussion" IS 'Refuse la création d’un fil direct hors de l’entreprise des deux comptes actifs.';


--
-- Name: T_Chat AuthorIdFk; Type: FK CONSTRAINT; Schema: communication; Owner: -
--

ALTER TABLE ONLY communication."T_Chat"
    ADD CONSTRAINT "AuthorIdFk" FOREIGN KEY ("AuthorIdFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE SET NULL ON DELETE SET NULL;


--
-- Name: CONSTRAINT "AuthorIdFk" ON "T_Chat"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON CONSTRAINT "AuthorIdFk" ON communication."T_Chat" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "communication"."T_Chat". Définition : FOREIGN KEY ("AuthorIdFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE SET NULL ON DELETE SET NULL.';


--
-- Name: T_ChatLecture Fk_ChatLecture_Chat; Type: FK CONSTRAINT; Schema: communication; Owner: -
--

ALTER TABLE ONLY communication."T_ChatLecture"
    ADD CONSTRAINT "Fk_ChatLecture_Chat" FOREIGN KEY ("IdChatFk") REFERENCES communication."T_Chat"("IdChat") ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: CONSTRAINT "Fk_ChatLecture_Chat" ON "T_ChatLecture"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON CONSTRAINT "Fk_ChatLecture_Chat" ON communication."T_ChatLecture" IS 'La lecture appartient à son message et disparaît si le message est supprimé physiquement.';


--
-- Name: T_ChatLecture Fk_ChatLecture_Utilisateur; Type: FK CONSTRAINT; Schema: communication; Owner: -
--

ALTER TABLE ONLY communication."T_ChatLecture"
    ADD CONSTRAINT "Fk_ChatLecture_Utilisateur" FOREIGN KEY ("IdUserFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: CONSTRAINT "Fk_ChatLecture_Utilisateur" ON "T_ChatLecture"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON CONSTRAINT "Fk_ChatLecture_Utilisateur" ON communication."T_ChatLecture" IS 'La lecture appartient à son compte et disparaît si le compte est supprimé physiquement.';


--
-- Name: T_Chat Fk_Chat_Discussion; Type: FK CONSTRAINT; Schema: communication; Owner: -
--

ALTER TABLE ONLY communication."T_Chat"
    ADD CONSTRAINT "Fk_Chat_Discussion" FOREIGN KEY ("IdDiscussionFk") REFERENCES communication."T_Discussion"("IdDiscussion") ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: CONSTRAINT "Fk_Chat_Discussion" ON "T_Chat"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON CONSTRAINT "Fk_Chat_Discussion" ON communication."T_Chat" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "communication"."T_Chat". Définition : FOREIGN KEY ("IdDiscussionFk") REFERENCES communication."T_Discussion"("IdDiscussion") ON UPDATE CASCADE ON DELETE CASCADE.';


--
-- Name: T_Discussion Fk_Discussion_Entite; Type: FK CONSTRAINT; Schema: communication; Owner: -
--

ALTER TABLE ONLY communication."T_Discussion"
    ADD CONSTRAINT "Fk_Discussion_Entite" FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: CONSTRAINT "Fk_Discussion_Entite" ON "T_Discussion"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON CONSTRAINT "Fk_Discussion_Entite" ON communication."T_Discussion" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "communication"."T_Discussion". Définition : FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON UPDATE CASCADE ON DELETE SET NULL.';


--
-- Name: T_Discussion Fk_Discussion_Professionnel; Type: FK CONSTRAINT; Schema: communication; Owner: -
--

ALTER TABLE ONLY communication."T_Discussion"
    ADD CONSTRAINT "Fk_Discussion_Professionnel" FOREIGN KEY ("IdProfessionnelFk") REFERENCES professionnel."T_Professionnel"("IdProfessionnel") ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: CONSTRAINT "Fk_Discussion_Professionnel" ON "T_Discussion"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON CONSTRAINT "Fk_Discussion_Professionnel" ON communication."T_Discussion" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "communication"."T_Discussion". Définition : FOREIGN KEY ("IdProfessionnelFk") REFERENCES professionnel."T_Professionnel"("IdProfessionnel") ON UPDATE CASCADE ON DELETE SET NULL.';


--
-- Name: T_Discussion Fk_Discussion_UserClient; Type: FK CONSTRAINT; Schema: communication; Owner: -
--

ALTER TABLE ONLY communication."T_Discussion"
    ADD CONSTRAINT "Fk_Discussion_UserClient" FOREIGN KEY ("IdUserClientFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: CONSTRAINT "Fk_Discussion_UserClient" ON "T_Discussion"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON CONSTRAINT "Fk_Discussion_UserClient" ON communication."T_Discussion" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "communication"."T_Discussion". Définition : FOREIGN KEY ("IdUserClientFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE ON DELETE SET NULL.';


--
-- Name: T_Communication Fk_IdEntite; Type: FK CONSTRAINT; Schema: communication; Owner: -
--

ALTER TABLE ONLY communication."T_Communication"
    ADD CONSTRAINT "Fk_IdEntite" FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: CONSTRAINT "Fk_IdEntite" ON "T_Communication"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON CONSTRAINT "Fk_IdEntite" ON communication."T_Communication" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "communication"."T_Communication". Définition : FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON UPDATE CASCADE ON DELETE SET NULL.';


--
-- Name: T_Communication Fk_IdTypeCommunication; Type: FK CONSTRAINT; Schema: communication; Owner: -
--

ALTER TABLE ONLY communication."T_Communication"
    ADD CONSTRAINT "Fk_IdTypeCommunication" FOREIGN KEY ("IdTypeCommunication") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: CONSTRAINT "Fk_IdTypeCommunication" ON "T_Communication"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON CONSTRAINT "Fk_IdTypeCommunication" ON communication."T_Communication" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "communication"."T_Communication". Définition : FOREIGN KEY ("IdTypeCommunication") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE ON DELETE SET NULL.';


--
-- Name: T_Communication Fk_IdUser; Type: FK CONSTRAINT; Schema: communication; Owner: -
--

ALTER TABLE ONLY communication."T_Communication"
    ADD CONSTRAINT "Fk_IdUser" FOREIGN KEY ("IdUserFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: CONSTRAINT "Fk_IdUser" ON "T_Communication"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON CONSTRAINT "Fk_IdUser" ON communication."T_Communication" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "communication"."T_Communication". Définition : FOREIGN KEY ("IdUserFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE ON DELETE SET NULL.';


--
-- Name: T_Annonce T_Annonce_IdAuteurFk_fkey; Type: FK CONSTRAINT; Schema: communication; Owner: -
--

ALTER TABLE ONLY communication."T_Annonce"
    ADD CONSTRAINT "T_Annonce_IdAuteurFk_fkey" FOREIGN KEY ("IdAuteurFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: T_Annonce T_Annonce_IdEntiteFk_fkey; Type: FK CONSTRAINT; Schema: communication; Owner: -
--

ALTER TABLE ONLY communication."T_Annonce"
    ADD CONSTRAINT "T_Annonce_IdEntiteFk_fkey" FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: T_Communication T_Communication_IdAnnonceFk_fkey; Type: FK CONSTRAINT; Schema: communication; Owner: -
--

ALTER TABLE ONLY communication."T_Communication"
    ADD CONSTRAINT "T_Communication_IdAnnonceFk_fkey" FOREIGN KEY ("IdAnnonceFk") REFERENCES communication."T_Annonce"("IdAnnonce") ON DELETE RESTRICT;


--
-- Name: T_Discussion T_Discussion_IdUserDestinataireFk_fkey; Type: FK CONSTRAINT; Schema: communication; Owner: -
--

ALTER TABLE ONLY communication."T_Discussion"
    ADD CONSTRAINT "T_Discussion_IdUserDestinataireFk_fkey" FOREIGN KEY ("IdUserDestinataireFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE ON DELETE SET NULL;
