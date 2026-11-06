-- Les annonces administratives réutilisent la boîte de notifications personnelle.
-- Les anciennes notifications restent autonomes et ne sont pas modifiées.

CREATE TABLE communication."T_Annonce" (
    "IdAnnonce" bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    "IdAuteurFk" integer REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE ON DELETE SET NULL,
    "IdEntiteFk" integer REFERENCES systeme."T_Entite"("IdEntite") ON UPDATE CASCADE ON DELETE SET NULL,
    "EmisParPlateforme" boolean NOT NULL,
    "PorteeAnnonce" text NOT NULL CHECK ("PorteeAnnonce" IN ('entreprises', 'toutes')),
    "SujetAnnonce" text NOT NULL CHECK (char_length(btrim("SujetAnnonce")) BETWEEN 1 AND 160),
    "ContenuAnnonce" text NOT NULL CHECK (char_length(btrim("ContenuAnnonce")) BETWEEN 1 AND 5000),
    "PublieLe" timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "CleRequete" uuid NOT NULL,
    "Entreprises" jsonb NOT NULL CHECK (jsonb_typeof("Entreprises") = 'array' AND jsonb_array_length("Entreprises") > 0),
    "NombreDestinataires" bigint NOT NULL CHECK ("NombreDestinataires" > 0),
    CONSTRAINT uq_annonce_auteur_requete UNIQUE ("IdAuteurFk", "CleRequete"),
    CONSTRAINT ck_annonce_portee_globale CHECK (
        ("PorteeAnnonce" <> 'toutes' OR "EmisParPlateforme")
        AND (NOT "EmisParPlateforme" OR "IdEntiteFk" IS NULL)
    )
);

COMMENT ON TABLE communication."T_Annonce" IS 'Publications administratives. Une annonce est enregistrée une fois et distribuée aux comptes actifs lors de sa publication.';
COMMENT ON COLUMN communication."T_Annonce"."IdAnnonce" IS 'Identifiant de la publication administrative.';
COMMENT ON COLUMN communication."T_Annonce"."IdAuteurFk" IS 'Compte ayant publié l’annonce. La publication est conservée après suppression du compte.';
COMMENT ON COLUMN communication."T_Annonce"."IdEntiteFk" IS 'Entreprise émettrice lors d’une publication locale. NULL pour une publication de la plateforme ou après retrait de l’entreprise émettrice.';
COMMENT ON COLUMN communication."T_Annonce"."EmisParPlateforme" IS 'Identifie une publication de la plateforme, même si une entreprise ou le compte émetteur sont retirés.';
COMMENT ON COLUMN communication."T_Annonce"."PorteeAnnonce" IS 'Entreprises sélectionnées ou toutes les entreprises actives à la date de publication.';
COMMENT ON COLUMN communication."T_Annonce"."SujetAnnonce" IS 'Titre de l’annonce, limité à 160 caractères.';
COMMENT ON COLUMN communication."T_Annonce"."ContenuAnnonce" IS 'Texte de l’annonce, limité à 5 000 caractères et partagé entre ses notifications personnelles.';
COMMENT ON COLUMN communication."T_Annonce"."PublieLe" IS 'Instant de publication utilisé pour dater toutes les notifications de l’annonce.';
COMMENT ON COLUMN communication."T_Annonce"."CleRequete" IS 'Identifiant de demande unique par auteur pour rejouer une diffusion sans dupliquer les notifications.';
COMMENT ON COLUMN communication."T_Annonce"."Entreprises" IS 'Instantané des identifiants et noms des entreprises ayant au moins un destinataire à la publication.';
COMMENT ON COLUMN communication."T_Annonce"."NombreDestinataires" IS 'Effectif initial des comptes destinataires, conservé indépendamment des lectures ou changements ultérieurs de rattachement.';
COMMENT ON CONSTRAINT uq_annonce_auteur_requete ON communication."T_Annonce" IS 'Identifie le rejeu d’une demande par son auteur et sa clé.';
COMMENT ON CONSTRAINT ck_annonce_portee_globale ON communication."T_Annonce" IS 'Une publication générale est émise par la plateforme, sans entreprise émettrice.';

CREATE INDEX idx_annonce_entite_publication ON communication."T_Annonce" ("IdEntiteFk", "PublieLe" DESC, "IdAnnonce" DESC);
COMMENT ON INDEX communication.idx_annonce_entite_publication IS 'Accès à l’historique des publications locales par date et entreprise émettrice.';

ALTER TABLE communication."T_Communication"
    ADD COLUMN "IdAnnonceFk" bigint REFERENCES communication."T_Annonce"("IdAnnonce") ON DELETE RESTRICT,
    ADD COLUMN "LuLe" timestamptz,
    ADD CONSTRAINT ck_comm_annonce_contenu CHECK ("IdAnnonceFk" IS NULL OR "ContenuCommunication" IS NULL),
    ADD CONSTRAINT ck_comm_annonce_lecture CHECK (
        "IdAnnonceFk" IS NULL OR "LectureCommunication" = ("LuLe" IS NOT NULL)
    );

COMMENT ON TABLE communication."T_Communication" IS 'Notifications individuelles, autonomes ou issues d’une annonce administrative. Distinctes des messages de discussion.';
COMMENT ON COLUMN communication."T_Communication"."IdAnnonceFk" IS 'Source du titre et du corps pour une annonce distribuée. NULL pour les notifications historiques ou autonomes.';
COMMENT ON COLUMN communication."T_Communication"."ContenuCommunication" IS 'Texte d’une notification autonome. Le texte partagé d’une annonce appartient à T_Annonce.';
COMMENT ON COLUMN communication."T_Communication"."LuLe" IS 'Date de la première lecture d’une notification issue d’une annonce. NULL si non lue ou pour une notification autonome.';
COMMENT ON CONSTRAINT ck_comm_annonce_contenu ON communication."T_Communication" IS 'Le corps d’une annonce est enregistré seulement dans sa publication source.';
COMMENT ON CONSTRAINT ck_comm_annonce_lecture ON communication."T_Communication" IS 'La date de lecture et l’état de lecture doivent concorder pour une annonce.';

CREATE UNIQUE INDEX uq_comm_annonce_destinataire
    ON communication."T_Communication" ("IdAnnonceFk", "IdUserFk")
    WHERE "IdAnnonceFk" IS NOT NULL;

COMMENT ON INDEX communication.uq_comm_annonce_destinataire IS 'Empêche une même annonce d’être distribuée deux fois à un compte.';

CREATE FUNCTION communication.fn_dater_lecture_annonce() RETURNS trigger
    LANGUAGE plpgsql SET search_path = pg_catalog
AS $function$
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
$function$;

COMMENT ON FUNCTION communication.fn_dater_lecture_annonce() IS 'Date la première lecture d’une annonce individuelle sans changer les anciennes notifications.';

CREATE TRIGGER tr_dater_lecture_annonce
    BEFORE UPDATE OF "LectureCommunication", "LuLe" ON communication."T_Communication"
    FOR EACH ROW EXECUTE FUNCTION communication.fn_dater_lecture_annonce();

COMMENT ON TRIGGER tr_dater_lecture_annonce ON communication."T_Communication" IS 'Conserve l’instant de la première lecture de chaque annonce reçue.';

CREATE OR REPLACE VIEW communication."V_Communication" AS
SELECT com."IdCommunication",
       com."DateCommunication",
       coalesce(a."ContenuAnnonce", com."ContenuCommunication") AS "ContenuCommunication",
       com."ObsCommunication",
       com."ValideCommunication",
       com."LectureCommunication",
       com."IdUserFk" AS "IdUser",
       u."NomUser",
       u."PrenomUser",
       u."EmailUser",
       com."IdEntiteFk" AS "IdEntite",
       e."NomEntite",
       com."IdTypeCommunication",
       tg."AbrGenerique" AS "TypeCommunicationAbr",
       tg."NomGenerique" AS "TypeCommunicationLibelle",
       a."SujetAnnonce" AS "SujetCommunication",
       com."IdAnnonceFk",
       com."LuLe"
FROM communication."T_Communication" com
LEFT JOIN systeme."T_Utilisateurs" u ON u."IdUser" = com."IdUserFk"
LEFT JOIN systeme."T_Entite" e ON e."IdEntite" = com."IdEntiteFk"
LEFT JOIN referentiel."T_Generique" tg ON tg."ID_Generique" = com."IdTypeCommunication"
LEFT JOIN communication."T_Annonce" a ON a."IdAnnonce" = com."IdAnnonceFk"
WHERE com."IdAnnonceFk" IS NULL OR com."IdEntiteFk" IS NOT NULL;

COMMENT ON VIEW communication."V_Communication" IS 'Notifications au grain destinataire. L’API filtre le compte et son entreprise de rattachement. Une annonce dont l’entreprise destinataire a été retirée reste hors de cette vue.';
COMMENT ON COLUMN communication."V_Communication"."ContenuCommunication" IS 'Texte autonome ou corps partagé de l’annonce administrative liée.';
COMMENT ON COLUMN communication."V_Communication"."SujetCommunication" IS 'Sujet de l’annonce lorsque la notification résulte d’une publication administrative.';
COMMENT ON COLUMN communication."V_Communication"."IdAnnonceFk" IS 'Publication administrative source de cette notification, le cas échéant.';
COMMENT ON COLUMN communication."V_Communication"."LuLe" IS 'Instant de la première lecture individuelle d’une annonce.';

CREATE OR REPLACE VIEW communication."V_Communication_non_lues" AS
SELECT *
FROM communication."V_Communication"
WHERE "LectureCommunication" IS FALSE AND "ValideCommunication" IS TRUE;

COMMENT ON VIEW communication."V_Communication_non_lues" IS 'Notifications actives et non lues au grain destinataire, avec le même filtrage par compte et entreprise que V_Communication.';
COMMENT ON COLUMN communication."V_Communication_non_lues"."ContenuCommunication" IS 'Texte autonome ou corps partagé de l’annonce administrative liée.';
COMMENT ON COLUMN communication."V_Communication_non_lues"."SujetCommunication" IS 'Sujet de l’annonce lorsque la notification résulte d’une publication administrative.';
COMMENT ON COLUMN communication."V_Communication_non_lues"."IdAnnonceFk" IS 'Publication administrative source de cette notification, le cas échéant.';
COMMENT ON COLUMN communication."V_Communication_non_lues"."LuLe" IS 'Instant de lecture, toujours NULL pour une annonce non lue.';

CREATE VIEW communication."V_Annonce" AS
SELECT a."IdAnnonce", a."IdAuteurFk",
       nullif(btrim(concat_ws(' ', u."PrenomUser", u."NomUser")), '') AS "NomAuteur",
       a."IdEntiteFk", e."NomEntite", a."EmisParPlateforme", a."PorteeAnnonce", a."SujetAnnonce",
       a."ContenuAnnonce", a."PublieLe", a."Entreprises", a."NombreDestinataires",
       jsonb_array_length(a."Entreprises") AS "NombreEntreprises",
       (SELECT count(*) FROM communication."T_Communication" c
        WHERE c."IdAnnonceFk" = a."IdAnnonce" AND c."LectureCommunication") AS "NombreLus"
FROM communication."T_Annonce" a
LEFT JOIN systeme."T_Utilisateurs" u ON u."IdUser" = a."IdAuteurFk"
LEFT JOIN systeme."T_Entite" e ON e."IdEntite" = a."IdEntiteFk";

COMMENT ON VIEW communication."V_Annonce" IS 'Historique au grain publication. L’API limite les administrateurs locaux à leur entreprise émettrice et réserve la portée de plateforme aux administrateurs globaux.';
COMMENT ON COLUMN communication."V_Annonce"."IdAnnonce" IS 'Identifiant de la publication.';
COMMENT ON COLUMN communication."V_Annonce"."IdAuteurFk" IS 'Compte ayant émis la publication, si encore enregistré.';
COMMENT ON COLUMN communication."V_Annonce"."NomAuteur" IS 'Prénom et nom actuels du compte émetteur.';
COMMENT ON COLUMN communication."V_Annonce"."IdEntiteFk" IS 'Entreprise émettrice utilisée pour filtrer l’historique des administrateurs locaux.';
COMMENT ON COLUMN communication."V_Annonce"."NomEntite" IS 'Nom actuel de l’entreprise émettrice, lorsque renseignée.';
COMMENT ON COLUMN communication."V_Annonce"."EmisParPlateforme" IS 'Sépare la diffusion de plateforme du registre local des entreprises.';
COMMENT ON COLUMN communication."V_Annonce"."PorteeAnnonce" IS 'Portée initiale : entreprises sélectionnées ou toutes les entreprises actives.';
COMMENT ON COLUMN communication."V_Annonce"."SujetAnnonce" IS 'Sujet publié dans les notifications individuelles.';
COMMENT ON COLUMN communication."V_Annonce"."ContenuAnnonce" IS 'Corps publié dans les notifications individuelles.';
COMMENT ON COLUMN communication."V_Annonce"."PublieLe" IS 'Instant de publication.';
COMMENT ON COLUMN communication."V_Annonce"."Entreprises" IS 'Identifiants et noms des entreprises destinataires à la publication.';
COMMENT ON COLUMN communication."V_Annonce"."NombreDestinataires" IS 'Nombre initial de notifications créées par cette publication.';
COMMENT ON COLUMN communication."V_Annonce"."NombreEntreprises" IS 'Nombre d’entreprises représentées parmi les comptes destinataires initiaux.';
COMMENT ON COLUMN communication."V_Annonce"."NombreLus" IS 'Nombre de notifications individuelles marquées comme lues.';

CREATE FUNCTION communication.fn_diffuser_annonce(
    p_auteur integer, p_entites integer[], p_sujet text, p_contenu text, p_cle uuid
) RETURNS TABLE ("IdAnnonce" bigint, "Rejouee" boolean)
    LANGUAGE plpgsql SET search_path = pg_catalog
AS $function$
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
$function$;

COMMENT ON FUNCTION communication.fn_diffuser_annonce(integer, integer[], text, text, uuid) IS 'Publie une annonce et toutes ses notifications dans une seule opération. Contrôle le droit réel de l’auteur, les entreprises actives, les destinataires actifs et le rejeu de la demande. L’audit de diffusion ne contient ni sujet ni texte.';
