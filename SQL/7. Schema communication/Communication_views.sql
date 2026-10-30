-- Extrait canonique du catalogue installé le 30/10/2026, sans données ni propriétaires imposés.
-- Voir SQL/README.md. Ces extraits documentent le domaine ; utiliser le fichier global pour une installation vide.
SET check_function_bodies = false;
SELECT pg_catalog.set_config('search_path', '', false);
--
-- Name: V_Chat; Type: VIEW; Schema: communication; Owner: -
--

CREATE VIEW communication."V_Chat" AS
 SELECT c."IdChat",
    c."TextChat",
    c."ChatFile",
    c."ChatLink",
    c."AuthorIdFk" AS "IdUser",
    c."IdDiscussionFk",
    c."DateChat",
    c."LuChat",
    u."NomUser",
    u."PrenomUser",
    u."EmailUser",
    e."IdEntite",
    e."NomEntite"
   FROM ((communication."T_Chat" c
     LEFT JOIN systeme."T_Utilisateurs" u ON ((u."IdUser" = c."AuthorIdFk")))
     LEFT JOIN systeme."T_Entite" e ON ((e."IdEntite" = u."IdEntiteFk")));

--
-- Name: VIEW "V_Chat"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON VIEW communication."V_Chat" IS 'Messages au grain message avec discussion et auteur. Vue privée ; le backend doit contrôler les participants avant toute lecture.';

--
-- Name: COLUMN "V_Chat"."IdChat"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Chat"."IdChat" IS 'Identifiant du message.';

--
-- Name: COLUMN "V_Chat"."TextChat"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Chat"."TextChat" IS 'Texte du message de discussion.';

--
-- Name: COLUMN "V_Chat"."ChatFile"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Chat"."ChatFile" IS 'Référence de la pièce jointe au message.';

--
-- Name: COLUMN "V_Chat"."ChatLink"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Chat"."ChatLink" IS 'Lien associé au message.';

--
-- Name: COLUMN "V_Chat"."IdUser"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Chat"."IdUser" IS 'Identifiant du compte utilisateur.';

--
-- Name: COLUMN "V_Chat"."IdDiscussionFk"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Chat"."IdDiscussionFk" IS 'Discussion contenant le message. Relation imposée : FOREIGN KEY ("IdDiscussionFk") REFERENCES communication."T_Discussion"("IdDiscussion") ON UPDATE CASCADE ON DELETE CASCADE.';

--
-- Name: COLUMN "V_Chat"."DateChat"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Chat"."DateChat" IS 'Date et heure du message avec fuseau horaire.';

--
-- Name: COLUMN "V_Chat"."LuChat"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Chat"."LuChat" IS 'Indicateur de lecture enregistré sur le message.';

--
-- Name: COLUMN "V_Chat"."NomUser"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Chat"."NomUser" IS 'Nom de l’utilisateur.';

--
-- Name: COLUMN "V_Chat"."PrenomUser"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Chat"."PrenomUser" IS 'Prénom de l’utilisateur.';

--
-- Name: COLUMN "V_Chat"."EmailUser"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Chat"."EmailUser" IS 'Adresse électronique du compte, utilisée pour la connexion.';

--
-- Name: COLUMN "V_Chat"."IdEntite"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Chat"."IdEntite" IS 'Identifiant de l’entité.';

--
-- Name: COLUMN "V_Chat"."NomEntite"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Chat"."NomEntite" IS 'Nom de la structure ou organisation.';

--
-- Name: V_Communication; Type: VIEW; Schema: communication; Owner: -
--

CREATE VIEW communication."V_Communication" AS
 SELECT com."IdCommunication",
    com."DateCommunication",
    com."ContenuCommunication",
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
    tg."NomGenerique" AS "TypeCommunicationLibelle"
   FROM (((communication."T_Communication" com
     LEFT JOIN systeme."T_Utilisateurs" u ON ((u."IdUser" = com."IdUserFk")))
     LEFT JOIN systeme."T_Entite" e ON ((e."IdEntite" = com."IdEntiteFk")))
     LEFT JOIN referentiel."T_Generique" tg ON ((tg."ID_Generique" = com."IdTypeCommunication")));

--
-- Name: VIEW "V_Communication"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON VIEW communication."V_Communication" IS 'Notifications au grain communication avec destinataire et entité ; aucune ouverture publique.';

--
-- Name: COLUMN "V_Communication"."IdCommunication"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Communication"."IdCommunication" IS 'Identifiant de la communication ou notification.';

--
-- Name: COLUMN "V_Communication"."DateCommunication"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Communication"."DateCommunication" IS 'Date et heure d’enregistrement de la communication.';

--
-- Name: COLUMN "V_Communication"."ContenuCommunication"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Communication"."ContenuCommunication" IS 'Texte de la communication ou notification destinée à l’utilisateur.';

--
-- Name: COLUMN "V_Communication"."ObsCommunication"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Communication"."ObsCommunication" IS 'Observations enregistrées sur la communication.';

--
-- Name: COLUMN "V_Communication"."ValideCommunication"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Communication"."ValideCommunication" IS 'Indique si la communication est déclaré valide/actif dans le registre ; distinct des qualifications calculées dans les vues.';

--
-- Name: COLUMN "V_Communication"."LectureCommunication"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Communication"."LectureCommunication" IS 'Indique si la communication est marquée comme lue.';

--
-- Name: COLUMN "V_Communication"."IdUser"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Communication"."IdUser" IS 'Identifiant du compte utilisateur.';

--
-- Name: COLUMN "V_Communication"."NomUser"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Communication"."NomUser" IS 'Nom de l’utilisateur.';

--
-- Name: COLUMN "V_Communication"."PrenomUser"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Communication"."PrenomUser" IS 'Prénom de l’utilisateur.';

--
-- Name: COLUMN "V_Communication"."EmailUser"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Communication"."EmailUser" IS 'Adresse électronique du compte, utilisée pour la connexion.';

--
-- Name: COLUMN "V_Communication"."IdEntite"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Communication"."IdEntite" IS 'Identifiant de l’entité.';

--
-- Name: COLUMN "V_Communication"."NomEntite"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Communication"."NomEntite" IS 'Nom de la structure ou organisation.';

--
-- Name: COLUMN "V_Communication"."IdTypeCommunication"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Communication"."IdTypeCommunication" IS 'Type de communication dans le référentiel. Relation imposée : FOREIGN KEY ("IdTypeCommunication") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE ON DELETE SET NULL.';

--
-- Name: COLUMN "V_Communication"."TypeCommunicationAbr"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Communication"."TypeCommunicationAbr" IS 'Projection SQL de TypeCommunicationAbr ; lire le commentaire de la vue pour son grain et son périmètre.';

--
-- Name: COLUMN "V_Communication"."TypeCommunicationLibelle"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Communication"."TypeCommunicationLibelle" IS 'Projection SQL de TypeCommunicationLibelle ; lire le commentaire de la vue pour son grain et son périmètre.';

--
-- Name: V_Communication_non_lues; Type: VIEW; Schema: communication; Owner: -
--

CREATE VIEW communication."V_Communication_non_lues" AS
 SELECT com."IdCommunication",
    com."DateCommunication",
    com."ContenuCommunication",
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
    tg."NomGenerique" AS "TypeCommunicationLibelle"
   FROM (((communication."T_Communication" com
     LEFT JOIN systeme."T_Utilisateurs" u ON ((u."IdUser" = com."IdUserFk")))
     LEFT JOIN systeme."T_Entite" e ON ((e."IdEntite" = com."IdEntiteFk")))
     LEFT JOIN referentiel."T_Generique" tg ON ((tg."ID_Generique" = com."IdTypeCommunication")))
  WHERE ((com."LectureCommunication" = false) AND (com."ValideCommunication" = true));

--
-- Name: VIEW "V_Communication_non_lues"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON VIEW communication."V_Communication_non_lues" IS 'Notifications actives et non lues, même grain que V_Communication ; filtrage du destinataire requis.';

--
-- Name: COLUMN "V_Communication_non_lues"."IdCommunication"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Communication_non_lues"."IdCommunication" IS 'Identifiant de la communication ou notification.';

--
-- Name: COLUMN "V_Communication_non_lues"."DateCommunication"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Communication_non_lues"."DateCommunication" IS 'Date et heure d’enregistrement de la communication.';

--
-- Name: COLUMN "V_Communication_non_lues"."ContenuCommunication"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Communication_non_lues"."ContenuCommunication" IS 'Texte de la communication ou notification destinée à l’utilisateur.';

--
-- Name: COLUMN "V_Communication_non_lues"."ObsCommunication"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Communication_non_lues"."ObsCommunication" IS 'Observations enregistrées sur la communication.';

--
-- Name: COLUMN "V_Communication_non_lues"."ValideCommunication"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Communication_non_lues"."ValideCommunication" IS 'Indique si la communication est déclaré valide/actif dans le registre ; distinct des qualifications calculées dans les vues.';

--
-- Name: COLUMN "V_Communication_non_lues"."LectureCommunication"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Communication_non_lues"."LectureCommunication" IS 'Indique si la communication est marquée comme lue.';

--
-- Name: COLUMN "V_Communication_non_lues"."IdUser"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Communication_non_lues"."IdUser" IS 'Identifiant du compte utilisateur.';

--
-- Name: COLUMN "V_Communication_non_lues"."NomUser"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Communication_non_lues"."NomUser" IS 'Nom de l’utilisateur.';

--
-- Name: COLUMN "V_Communication_non_lues"."PrenomUser"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Communication_non_lues"."PrenomUser" IS 'Prénom de l’utilisateur.';

--
-- Name: COLUMN "V_Communication_non_lues"."EmailUser"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Communication_non_lues"."EmailUser" IS 'Adresse électronique du compte, utilisée pour la connexion.';

--
-- Name: COLUMN "V_Communication_non_lues"."IdEntite"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Communication_non_lues"."IdEntite" IS 'Identifiant de l’entité.';

--
-- Name: COLUMN "V_Communication_non_lues"."NomEntite"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Communication_non_lues"."NomEntite" IS 'Nom de la structure ou organisation.';

--
-- Name: COLUMN "V_Communication_non_lues"."IdTypeCommunication"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Communication_non_lues"."IdTypeCommunication" IS 'Type de communication dans le référentiel. Relation imposée : FOREIGN KEY ("IdTypeCommunication") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE ON DELETE SET NULL.';

--
-- Name: COLUMN "V_Communication_non_lues"."TypeCommunicationAbr"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Communication_non_lues"."TypeCommunicationAbr" IS 'Projection SQL de TypeCommunicationAbr ; lire le commentaire de la vue pour son grain et son périmètre.';

--
-- Name: COLUMN "V_Communication_non_lues"."TypeCommunicationLibelle"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Communication_non_lues"."TypeCommunicationLibelle" IS 'Projection SQL de TypeCommunicationLibelle ; lire le commentaire de la vue pour son grain et son périmètre.';
