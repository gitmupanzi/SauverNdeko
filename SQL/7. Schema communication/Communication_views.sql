-- Extrait canonique PostgreSQL 18 après les migrations Communication du 06/11/2026.
-- Sans données ni propriétaires. Voir SQL/README.md pour le parcours d’installation.
SET check_function_bodies = false;
SELECT pg_catalog.set_config('search_path', '', false);
--
-- Name: V_Annonce; Type: VIEW; Schema: communication; Owner: -
--

CREATE VIEW communication."V_Annonce" AS
 SELECT a."IdAnnonce",
    a."IdAuteurFk",
    NULLIF(btrim(concat_ws(' '::text, u."PrenomUser", u."NomUser")), ''::text) AS "NomAuteur",
    a."IdEntiteFk",
    e."NomEntite",
    a."EmisParPlateforme",
    a."PorteeAnnonce",
    a."SujetAnnonce",
    a."ContenuAnnonce",
    a."PublieLe",
    a."Entreprises",
    a."NombreDestinataires",
    jsonb_array_length(a."Entreprises") AS "NombreEntreprises",
    ( SELECT count(*) AS count
           FROM communication."T_Communication" c
          WHERE ((c."IdAnnonceFk" = a."IdAnnonce") AND c."LectureCommunication")) AS "NombreLus"
   FROM ((communication."T_Annonce" a
     LEFT JOIN systeme."T_Utilisateurs" u ON ((u."IdUser" = a."IdAuteurFk")))
     LEFT JOIN systeme."T_Entite" e ON ((e."IdEntite" = a."IdEntiteFk")));


--
-- Name: VIEW "V_Annonce"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON VIEW communication."V_Annonce" IS 'Historique au grain publication. L’API limite les administrateurs locaux à leur entreprise émettrice et réserve la portée de plateforme aux administrateurs globaux.';


--
-- Name: COLUMN "V_Annonce"."IdAnnonce"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Annonce"."IdAnnonce" IS 'Identifiant de la publication.';


--
-- Name: COLUMN "V_Annonce"."IdAuteurFk"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Annonce"."IdAuteurFk" IS 'Compte ayant émis la publication, si encore enregistré.';


--
-- Name: COLUMN "V_Annonce"."NomAuteur"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Annonce"."NomAuteur" IS 'Prénom et nom actuels du compte émetteur.';


--
-- Name: COLUMN "V_Annonce"."IdEntiteFk"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Annonce"."IdEntiteFk" IS 'Entreprise émettrice utilisée pour filtrer l’historique des administrateurs locaux.';


--
-- Name: COLUMN "V_Annonce"."NomEntite"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Annonce"."NomEntite" IS 'Nom actuel de l’entreprise émettrice, lorsque renseignée.';


--
-- Name: COLUMN "V_Annonce"."EmisParPlateforme"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Annonce"."EmisParPlateforme" IS 'Sépare la diffusion de plateforme du registre local des entreprises.';


--
-- Name: COLUMN "V_Annonce"."PorteeAnnonce"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Annonce"."PorteeAnnonce" IS 'Portée initiale : entreprises sélectionnées ou toutes les entreprises actives.';


--
-- Name: COLUMN "V_Annonce"."SujetAnnonce"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Annonce"."SujetAnnonce" IS 'Sujet publié dans les notifications individuelles.';


--
-- Name: COLUMN "V_Annonce"."ContenuAnnonce"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Annonce"."ContenuAnnonce" IS 'Corps publié dans les notifications individuelles.';


--
-- Name: COLUMN "V_Annonce"."PublieLe"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Annonce"."PublieLe" IS 'Instant de publication.';


--
-- Name: COLUMN "V_Annonce"."Entreprises"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Annonce"."Entreprises" IS 'Identifiants et noms des entreprises destinataires à la publication.';


--
-- Name: COLUMN "V_Annonce"."NombreDestinataires"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Annonce"."NombreDestinataires" IS 'Nombre initial de notifications créées par cette publication.';


--
-- Name: COLUMN "V_Annonce"."NombreEntreprises"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Annonce"."NombreEntreprises" IS 'Nombre d’entreprises représentées parmi les comptes destinataires initiaux.';


--
-- Name: COLUMN "V_Annonce"."NombreLus"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Annonce"."NombreLus" IS 'Nombre de notifications individuelles marquées comme lues.';


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
    e."NomEntite",
    c."SuiviLectureChat"
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

COMMENT ON COLUMN communication."V_Chat"."LuChat" IS 'Indicateur de lecture historique conservé pour compatibilité.';


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
-- Name: COLUMN "V_Chat"."SuiviLectureChat"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Chat"."SuiviLectureChat" IS 'Indique si le message peut entrer dans le suivi individuel des lectures.';


--
-- Name: V_Communication; Type: VIEW; Schema: communication; Owner: -
--

CREATE VIEW communication."V_Communication" AS
 SELECT com."IdCommunication",
    com."DateCommunication",
    COALESCE(a."ContenuAnnonce", com."ContenuCommunication") AS "ContenuCommunication",
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
   FROM ((((communication."T_Communication" com
     LEFT JOIN systeme."T_Utilisateurs" u ON ((u."IdUser" = com."IdUserFk")))
     LEFT JOIN systeme."T_Entite" e ON ((e."IdEntite" = com."IdEntiteFk")))
     LEFT JOIN referentiel."T_Generique" tg ON ((tg."ID_Generique" = com."IdTypeCommunication")))
     LEFT JOIN communication."T_Annonce" a ON ((a."IdAnnonce" = com."IdAnnonceFk")))
  WHERE ((com."IdAnnonceFk" IS NULL) OR (com."IdEntiteFk" IS NOT NULL));


--
-- Name: VIEW "V_Communication"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON VIEW communication."V_Communication" IS 'Notifications au grain destinataire. L’API filtre le compte et son entreprise de rattachement. Une annonce dont l’entreprise destinataire a été retirée reste hors de cette vue.';


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

COMMENT ON COLUMN communication."V_Communication"."ContenuCommunication" IS 'Texte autonome ou corps partagé de l’annonce administrative liée.';


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
-- Name: COLUMN "V_Communication"."SujetCommunication"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Communication"."SujetCommunication" IS 'Sujet de l’annonce lorsque la notification résulte d’une publication administrative.';


--
-- Name: COLUMN "V_Communication"."IdAnnonceFk"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Communication"."IdAnnonceFk" IS 'Publication administrative source de cette notification, le cas échéant.';


--
-- Name: COLUMN "V_Communication"."LuLe"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Communication"."LuLe" IS 'Instant de la première lecture individuelle d’une annonce.';


--
-- Name: V_Communication_non_lues; Type: VIEW; Schema: communication; Owner: -
--

CREATE VIEW communication."V_Communication_non_lues" AS
 SELECT "IdCommunication",
    "DateCommunication",
    "ContenuCommunication",
    "ObsCommunication",
    "ValideCommunication",
    "LectureCommunication",
    "IdUser",
    "NomUser",
    "PrenomUser",
    "EmailUser",
    "IdEntite",
    "NomEntite",
    "IdTypeCommunication",
    "TypeCommunicationAbr",
    "TypeCommunicationLibelle",
    "SujetCommunication",
    "IdAnnonceFk",
    "LuLe"
   FROM communication."V_Communication"
  WHERE (("LectureCommunication" IS FALSE) AND ("ValideCommunication" IS TRUE));


--
-- Name: VIEW "V_Communication_non_lues"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON VIEW communication."V_Communication_non_lues" IS 'Notifications actives et non lues au grain destinataire, avec le même filtrage par compte et entreprise que V_Communication.';


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

COMMENT ON COLUMN communication."V_Communication_non_lues"."ContenuCommunication" IS 'Texte autonome ou corps partagé de l’annonce administrative liée.';


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


--
-- Name: COLUMN "V_Communication_non_lues"."SujetCommunication"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Communication_non_lues"."SujetCommunication" IS 'Sujet de l’annonce lorsque la notification résulte d’une publication administrative.';


--
-- Name: COLUMN "V_Communication_non_lues"."IdAnnonceFk"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Communication_non_lues"."IdAnnonceFk" IS 'Publication administrative source de cette notification, le cas échéant.';


--
-- Name: COLUMN "V_Communication_non_lues"."LuLe"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_Communication_non_lues"."LuLe" IS 'Instant de lecture, toujours NULL pour une annonce non lue.';


--
-- Name: V_DiscussionBoite; Type: VIEW; Schema: communication; Owner: -
--

CREATE VIEW communication."V_DiscussionBoite" AS
 SELECT d."IdDiscussion",
    d."IdUserClientFk",
    d."IdProfessionnelFk",
    d."IdEntiteFk",
    d."TypeDiscussion",
    d."SujetDiscussion",
    d."DateCreation",
    d."DernierMessageAt",
    d."ValideDiscussion",
    d."IdUserDestinataireFk",
    btrim(concat_ws(' '::text, initiateur."PrenomUser", initiateur."NomUser")) AS "NomInitiateur",
    btrim(concat_ws(' '::text, cible."PrenomUser", cible."NomUser")) AS "NomDestinataire",
    p."IdUserFk" AS "IdCompteProfessionnel",
    btrim(concat_ws(' '::text, expert."PrenomUser", expert."NomUser")) AS "NomProfessionnel",
    NULLIF(btrim((s."AbrGenerique")::text), ''::text) AS "SpecialiteProfessionnel",
    e."NomEntite" AS "NomStructure",
    m."DernierMessage"
   FROM (((((((communication."T_Discussion" d
     LEFT JOIN systeme."T_Utilisateurs" initiateur ON ((initiateur."IdUser" = d."IdUserClientFk")))
     LEFT JOIN systeme."T_Utilisateurs" cible ON ((cible."IdUser" = d."IdUserDestinataireFk")))
     LEFT JOIN professionnel."T_Professionnel" p ON ((p."IdProfessionnel" = d."IdProfessionnelFk")))
     LEFT JOIN systeme."T_Utilisateurs" expert ON ((expert."IdUser" = p."IdUserFk")))
     LEFT JOIN referentiel."T_Generique" s ON ((s."ID_Generique" = p."IdSpecialiteFk")))
     LEFT JOIN systeme."T_Entite" e ON ((e."IdEntite" = d."IdEntiteFk")))
     LEFT JOIN LATERAL ( SELECT jsonb_build_object('IdChat', c."IdChat", 'TextChat', c."TextChat", 'DateChat', c."DateChat", 'ChatFile', c."ChatFile", 'ChatLink', c."ChatLink", 'LuChat', c."LuChat", 'author', jsonb_build_object('IdUser', c."IdUser", 'NomUser', c."NomUser", 'PrenomUser', c."PrenomUser")) AS "DernierMessage"
           FROM communication."V_Chat" c
          WHERE (c."IdDiscussionFk" = d."IdDiscussion")
          ORDER BY c."DateChat" DESC, c."IdChat" DESC
         LIMIT 1) m ON (true));


--
-- Name: VIEW "V_DiscussionBoite"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON VIEW communication."V_DiscussionBoite" IS 'Une ligne par fil privé, avec identités minimales et dernier message. Réservée aux lectures serveur après contrôle du participant.';


--
-- Name: COLUMN "V_DiscussionBoite"."IdDiscussion"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_DiscussionBoite"."IdDiscussion" IS 'Identifiant du fil privé.';


--
-- Name: COLUMN "V_DiscussionBoite"."IdUserClientFk"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_DiscussionBoite"."IdUserClientFk" IS 'Compte qui a initié le fil.';


--
-- Name: COLUMN "V_DiscussionBoite"."IdProfessionnelFk"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_DiscussionBoite"."IdProfessionnelFk" IS 'Profil visé par le fil professionnel.';


--
-- Name: COLUMN "V_DiscussionBoite"."IdEntiteFk"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_DiscussionBoite"."IdEntiteFk" IS 'Structure destinataire ou entreprise de création du fil direct.';


--
-- Name: COLUMN "V_DiscussionBoite"."TypeDiscussion"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_DiscussionBoite"."TypeDiscussion" IS 'Canal du fil privé.';


--
-- Name: COLUMN "V_DiscussionBoite"."SujetDiscussion"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_DiscussionBoite"."SujetDiscussion" IS 'Sujet historique du fil.';


--
-- Name: COLUMN "V_DiscussionBoite"."DateCreation"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_DiscussionBoite"."DateCreation" IS 'Date de création du fil.';


--
-- Name: COLUMN "V_DiscussionBoite"."DernierMessageAt"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_DiscussionBoite"."DernierMessageAt" IS 'Date du dernier message, tenue par le trigger existant.';


--
-- Name: COLUMN "V_DiscussionBoite"."ValideDiscussion"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_DiscussionBoite"."ValideDiscussion" IS 'Fil actif et consultable par ses participants.';


--
-- Name: COLUMN "V_DiscussionBoite"."IdUserDestinataireFk"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_DiscussionBoite"."IdUserDestinataireFk" IS 'Compte destinataire d’un fil direct.';


--
-- Name: COLUMN "V_DiscussionBoite"."NomInitiateur"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_DiscussionBoite"."NomInitiateur" IS 'Nom d’affichage du compte initiateur.';


--
-- Name: COLUMN "V_DiscussionBoite"."NomDestinataire"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_DiscussionBoite"."NomDestinataire" IS 'Nom d’affichage du second participant d’un fil direct.';


--
-- Name: COLUMN "V_DiscussionBoite"."IdCompteProfessionnel"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_DiscussionBoite"."IdCompteProfessionnel" IS 'Compte qui porte le profil professionnel ciblé.';


--
-- Name: COLUMN "V_DiscussionBoite"."NomProfessionnel"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_DiscussionBoite"."NomProfessionnel" IS 'Nom du correspondant professionnel, sans coordonnées privées.';


--
-- Name: COLUMN "V_DiscussionBoite"."SpecialiteProfessionnel"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_DiscussionBoite"."SpecialiteProfessionnel" IS 'Abréviation de la spécialité du professionnel dans le référentiel.';


--
-- Name: COLUMN "V_DiscussionBoite"."NomStructure"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_DiscussionBoite"."NomStructure" IS 'Nom de la structure rattachée au fil.';


--
-- Name: COLUMN "V_DiscussionBoite"."DernierMessage"; Type: COMMENT; Schema: communication; Owner: -
--

COMMENT ON COLUMN communication."V_DiscussionBoite"."DernierMessage" IS 'Aperçu du dernier message et identité minimale de son auteur.';
