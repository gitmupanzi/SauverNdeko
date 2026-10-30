-- Extrait canonique du catalogue installé le 30/10/2026, sans données ni propriétaires imposés.
-- Voir SQL/README.md. Ces extraits documentent le domaine ; utiliser le fichier global pour une installation vide.
SET check_function_bodies = false;
SELECT pg_catalog.set_config('search_path', '', false);
CREATE SCHEMA IF NOT EXISTS "communication";
--
-- Name: SCHEMA communication; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA communication IS 'Discussions, messages de conversation et communications adressées aux utilisateurs et entités.';

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


SET default_tablespace = '';

SET default_table_access_method = heap;

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

COMMENT ON COLUMN communication."T_Chat"."LuChat" IS 'Indicateur de lecture enregistré sur le message.';

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
    "IdEntiteFk" integer
);

--
-- Name: TABLE "T_Communication"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON TABLE communication."T_Communication" IS 'Communications et notifications destinées à un utilisateur, éventuellement rattachées à une entité ; contenu, type, date, validité et lecture. Distinctes des messages de discussion.';

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

COMMENT ON COLUMN communication."T_Communication"."ContenuCommunication" IS 'Texte de la communication ou notification destinée à l’utilisateur.';

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
    CONSTRAINT "Ck_Discussion_Target" CHECK ((((("TypeDiscussion")::text = 'expert'::text) AND ("IdProfessionnelFk" IS NOT NULL) AND ("IdEntiteFk" IS NULL)) OR ((("TypeDiscussion")::text = 'structure'::text) AND ("IdEntiteFk" IS NOT NULL) AND ("IdProfessionnelFk" IS NULL)))),
    CONSTRAINT "Ck_Discussion_Type" CHECK ((("TypeDiscussion")::text = ANY (ARRAY[('expert'::character varying)::text, ('structure'::character varying)::text])))
);

--
-- Name: TABLE "T_Discussion"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON TABLE communication."T_Discussion" IS 'Fil de discussion d’un utilisateur avec un professionnel ou une structure. Les contraintes limitent TypeDiscussion à expert/structure et imposent la cible correspondante.';

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

COMMENT ON COLUMN communication."T_Discussion"."IdEntiteFk" IS 'Entité de rattachement de l’enregistrement. Relation imposée : FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON UPDATE CASCADE ON DELETE SET NULL.';

--
-- Name: COLUMN "T_Discussion"."TypeDiscussion"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."T_Discussion"."TypeDiscussion" IS 'Type de cible du fil : expert ou structure selon la contrainte installée.';

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

COMMENT ON CONSTRAINT "Ck_Discussion_Target" ON communication."T_Discussion" IS 'Contrôle de cohérence des valeurs autorisées dans "communication"."T_Discussion". Définition : CHECK ("TypeDiscussion"::text = ''expert''::text AND "IdProfessionnelFk" IS NOT NULL AND "IdEntiteFk" IS NULL OR "TypeDiscussion"::text = ''structure''::text AND "IdEntiteFk" IS NOT NULL AND "IdProfessionnelFk" IS NULL).';

--
-- Name: CONSTRAINT "Ck_Discussion_Type" ON "T_Discussion"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON CONSTRAINT "Ck_Discussion_Type" ON communication."T_Discussion" IS 'Contrôle de cohérence des valeurs autorisées dans "communication"."T_Discussion". Définition : CHECK ("TypeDiscussion"::text = ANY (ARRAY[''expert''::character varying::text, ''structure''::character varying::text])).';

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
-- Name: T_Communication Pk_IdCommunication; Type: CONSTRAINT; Schema: communication; Owner: -
--

ALTER TABLE ONLY communication."T_Communication"
    ADD CONSTRAINT "Pk_IdCommunication" PRIMARY KEY ("IdCommunication");

--
-- Name: CONSTRAINT "Pk_IdCommunication" ON "T_Communication"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON CONSTRAINT "Pk_IdCommunication" ON communication."T_Communication" IS 'Clé primaire : identifie de manière unique chaque ligne dans "communication"."T_Communication". Définition : PRIMARY KEY ("IdCommunication").';

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
-- Name: T_Chat tr_sync_dernier_message; Type: TRIGGER; Schema: communication; Owner: -
--

CREATE TRIGGER tr_sync_dernier_message AFTER INSERT OR DELETE OR UPDATE ON communication."T_Chat" FOR EACH ROW EXECUTE FUNCTION communication.fn_sync_dernier_message();

--
-- Name: TRIGGER tr_sync_dernier_message ON "T_Chat"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON TRIGGER tr_sync_dernier_message ON communication."T_Chat" IS 'Synchronise la dernière activité avec les messages effectivement présents.';

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
