-- Extrait canonique du catalogue installé le 31/10/2026, sans données ni propriétaires imposés.
-- Voir SQL/README.md. Ces extraits documentent le domaine ; utiliser le fichier global pour une installation vide.
SET check_function_bodies = false;
SELECT pg_catalog.set_config('search_path', '', false);
--
-- Name: V_CommentaireSupport; Type: VIEW; Schema: support; Owner: -
--

CREATE VIEW support."V_CommentaireSupport" AS
 SELECT x."ID_CommentaireSupport",
    x."ID_SupportFk",
    x."ID_AuteurFk",
    x."Contenu",
    x."Visibilite",
    x."DateCreation",
    x."DateModification",
    s."IdEntiteFk",
    concat_ws(' '::text, u."PrenomUser", u."NomUser") AS "Auteur"
   FROM ((support."T_CommentaireSupport" x
     JOIN support."T_Support" s ON ((s."ID_Support" = x."ID_SupportFk")))
     JOIN systeme."T_Utilisateurs" u ON ((u."IdUser" = x."ID_AuteurFk")));

--
-- Name: VIEW "V_CommentaireSupport"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON VIEW support."V_CommentaireSupport" IS 'Échanges du dossier avec auteur et propriétaire, sans octets documentaires ; le filtre de visibilité interne reste obligatoire avant réponse API.';

--
-- Name: COLUMN "V_CommentaireSupport"."ID_CommentaireSupport"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."V_CommentaireSupport"."ID_CommentaireSupport" IS 'Donnée Support ID_CommentaireSupport : valeur métier ou projection de la source liée, conservée avec son propriétaire et son contexte de dossier.';

--
-- Name: COLUMN "V_CommentaireSupport"."ID_SupportFk"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."V_CommentaireSupport"."ID_SupportFk" IS 'Donnée Support ID_SupportFk : valeur métier ou projection de la source liée, conservée avec son propriétaire et son contexte de dossier.';

--
-- Name: COLUMN "V_CommentaireSupport"."ID_AuteurFk"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."V_CommentaireSupport"."ID_AuteurFk" IS 'Donnée Support ID_AuteurFk : valeur métier ou projection de la source liée, conservée avec son propriétaire et son contexte de dossier.';

--
-- Name: COLUMN "V_CommentaireSupport"."Contenu"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."V_CommentaireSupport"."Contenu" IS 'Donnée Support Contenu : valeur métier ou projection de la source liée, conservée avec son propriétaire et son contexte de dossier.';

--
-- Name: COLUMN "V_CommentaireSupport"."Visibilite"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."V_CommentaireSupport"."Visibilite" IS 'public : lecteurs autorisés du dossier ; interne : gestionnaires habilités uniquement, jamais un partage Internet.';

--
-- Name: COLUMN "V_CommentaireSupport"."DateCreation"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."V_CommentaireSupport"."DateCreation" IS 'Donnée Support DateCreation : valeur métier ou projection de la source liée, conservée avec son propriétaire et son contexte de dossier.';

--
-- Name: COLUMN "V_CommentaireSupport"."DateModification"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."V_CommentaireSupport"."DateModification" IS 'Donnée Support DateModification : valeur métier ou projection de la source liée, conservée avec son propriétaire et son contexte de dossier.';

--
-- Name: COLUMN "V_CommentaireSupport"."IdEntiteFk"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."V_CommentaireSupport"."IdEntiteFk" IS 'Entreprise propriétaire durable, indépendante du rattachement actuel du créateur.';

--
-- Name: COLUMN "V_CommentaireSupport"."Auteur"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."V_CommentaireSupport"."Auteur" IS 'Donnée Support Auteur : valeur métier ou projection de la source liée, conservée avec son propriétaire et son contexte de dossier.';

--
-- Name: V_PieceSupport; Type: VIEW; Schema: support; Owner: -
--

CREATE VIEW support."V_PieceSupport" AS
 SELECT x."ID_PieceFk",
    x."ID_SupportFk",
    x."ID_CommentaireSupportFk",
    x."Visibilite",
    s."IdEntiteFk",
    p."ID_UserFk",
    p."NomFichier",
    p."MimeType",
    p."TailleOctets",
    p."Sha256",
    p."Archive",
    p."CreeLe"
   FROM ((support."T_PieceSupport" x
     JOIN support."T_Support" s ON ((s."ID_Support" = x."ID_SupportFk")))
     JOIN logistique."T_PieceJustificative" p ON ((p."ID_Piece" = x."ID_PieceFk")));

--
-- Name: VIEW "V_PieceSupport"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON VIEW support."V_PieceSupport" IS 'Métadonnées de preuves liées par vraie FK, sans contenu binaire ; téléchargement autorisé via le parent et le niveau de visibilité.';

--
-- Name: COLUMN "V_PieceSupport"."ID_PieceFk"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."V_PieceSupport"."ID_PieceFk" IS 'Vraie FK vers le stockage binaire privé existant logistique.T_PieceJustificative ; aucun octet dupliqué.';

--
-- Name: COLUMN "V_PieceSupport"."ID_SupportFk"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."V_PieceSupport"."ID_SupportFk" IS 'Donnée Support ID_SupportFk : valeur métier ou projection de la source liée, conservée avec son propriétaire et son contexte de dossier.';

--
-- Name: COLUMN "V_PieceSupport"."ID_CommentaireSupportFk"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."V_PieceSupport"."ID_CommentaireSupportFk" IS 'Commentaire facultatif appartenant au même dossier ; une preuve interne ne devient pas publique.';

--
-- Name: COLUMN "V_PieceSupport"."Visibilite"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."V_PieceSupport"."Visibilite" IS 'public : lecteurs autorisés du dossier ; interne : gestionnaires habilités uniquement, jamais un partage Internet.';

--
-- Name: COLUMN "V_PieceSupport"."IdEntiteFk"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."V_PieceSupport"."IdEntiteFk" IS 'Entreprise propriétaire durable, indépendante du rattachement actuel du créateur.';

--
-- Name: COLUMN "V_PieceSupport"."ID_UserFk"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."V_PieceSupport"."ID_UserFk" IS 'Donnée Support ID_UserFk : valeur métier ou projection de la source liée, conservée avec son propriétaire et son contexte de dossier.';

--
-- Name: COLUMN "V_PieceSupport"."NomFichier"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."V_PieceSupport"."NomFichier" IS 'Donnée Support NomFichier : valeur métier ou projection de la source liée, conservée avec son propriétaire et son contexte de dossier.';

--
-- Name: COLUMN "V_PieceSupport"."MimeType"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."V_PieceSupport"."MimeType" IS 'Donnée Support MimeType : valeur métier ou projection de la source liée, conservée avec son propriétaire et son contexte de dossier.';

--
-- Name: COLUMN "V_PieceSupport"."TailleOctets"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."V_PieceSupport"."TailleOctets" IS 'Donnée Support TailleOctets : valeur métier ou projection de la source liée, conservée avec son propriétaire et son contexte de dossier.';

--
-- Name: COLUMN "V_PieceSupport"."Sha256"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."V_PieceSupport"."Sha256" IS 'Donnée Support Sha256 : valeur métier ou projection de la source liée, conservée avec son propriétaire et son contexte de dossier.';

--
-- Name: COLUMN "V_PieceSupport"."Archive"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."V_PieceSupport"."Archive" IS 'Retrait du parcours actif sans suppression du dossier, de ses échanges, résolutions et preuves.';

--
-- Name: COLUMN "V_PieceSupport"."CreeLe"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."V_PieceSupport"."CreeLe" IS 'Donnée Support CreeLe : valeur métier ou projection de la source liée, conservée avec son propriétaire et son contexte de dossier.';

--
-- Name: V_ResolutionSupport; Type: VIEW; Schema: support; Owner: -
--

CREATE VIEW support."V_ResolutionSupport" AS
 SELECT x."ID_ResolutionSupport",
    x."ID_SupportFk",
    x."CauseIdentifiee",
    x."SolutionAppliquee",
    x."ID_ProposeParFk",
    x."DateProposition",
    x."ID_ResultatVerificationFk",
    x."ID_VerifieParFk",
    x."DateVerification",
    x."CommentaireVerification",
    s."IdEntiteFk",
    concat_ws(' '::text, u."PrenomUser", u."NomUser") AS "ProposePar",
    NULLIF(concat_ws(' '::text, v."PrenomUser", v."NomUser"), ''::text) AS "VerifiePar",
    (
        CASE
            WHEN (g."ID_Generique" IS NULL) THEN NULL::text
            ELSE COALESCE(NULLIF(btrim((g."AbrGenerique")::text), ''::text), ('Valeur sans abréviation #'::text || (g."ID_Generique")::text))
        END)::character varying(255) AS "ResultatVerification"
   FROM ((((support."T_ResolutionSupport" x
     JOIN support."T_Support" s ON ((s."ID_Support" = x."ID_SupportFk")))
     JOIN systeme."T_Utilisateurs" u ON ((u."IdUser" = x."ID_ProposeParFk")))
     LEFT JOIN systeme."T_Utilisateurs" v ON ((v."IdUser" = x."ID_VerifieParFk")))
     LEFT JOIN referentiel."T_Generique" g ON ((g."ID_Generique" = x."ID_ResultatVerificationFk")));

--
-- Name: VIEW "V_ResolutionSupport"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON VIEW support."V_ResolutionSupport" IS 'Toutes les tentatives successives et leurs vérifications, distinctes du statut courant du dossier.';

--
-- Name: COLUMN "V_ResolutionSupport"."ID_ResolutionSupport"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."V_ResolutionSupport"."ID_ResolutionSupport" IS 'Donnée Support ID_ResolutionSupport : valeur métier ou projection de la source liée, conservée avec son propriétaire et son contexte de dossier.';

--
-- Name: COLUMN "V_ResolutionSupport"."ID_SupportFk"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."V_ResolutionSupport"."ID_SupportFk" IS 'Donnée Support ID_SupportFk : valeur métier ou projection de la source liée, conservée avec son propriétaire et son contexte de dossier.';

--
-- Name: COLUMN "V_ResolutionSupport"."CauseIdentifiee"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."V_ResolutionSupport"."CauseIdentifiee" IS 'Donnée Support CauseIdentifiee : valeur métier ou projection de la source liée, conservée avec son propriétaire et son contexte de dossier.';

--
-- Name: COLUMN "V_ResolutionSupport"."SolutionAppliquee"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."V_ResolutionSupport"."SolutionAppliquee" IS 'Donnée Support SolutionAppliquee : valeur métier ou projection de la source liée, conservée avec son propriétaire et son contexte de dossier.';

--
-- Name: COLUMN "V_ResolutionSupport"."ID_ProposeParFk"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."V_ResolutionSupport"."ID_ProposeParFk" IS 'Auteur réel de cette tentative de résolution ; les tentatives antérieures restent conservées.';

--
-- Name: COLUMN "V_ResolutionSupport"."DateProposition"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."V_ResolutionSupport"."DateProposition" IS 'Donnée Support DateProposition : valeur métier ou projection de la source liée, conservée avec son propriétaire et son contexte de dossier.';

--
-- Name: COLUMN "V_ResolutionSupport"."ID_ResultatVerificationFk"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."V_ResolutionSupport"."ID_ResultatVerificationFk" IS 'Résultat dans T_Generique, parmi ceux capturés dans le circuit ; NULL tant que la solution n’est pas vérifiée.';

--
-- Name: COLUMN "V_ResolutionSupport"."ID_VerifieParFk"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."V_ResolutionSupport"."ID_VerifieParFk" IS 'Personne habilitée ayant vérifié la dernière solution, obligatoirement différente de son auteur.';

--
-- Name: COLUMN "V_ResolutionSupport"."DateVerification"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."V_ResolutionSupport"."DateVerification" IS 'Donnée Support DateVerification : valeur métier ou projection de la source liée, conservée avec son propriétaire et son contexte de dossier.';

--
-- Name: COLUMN "V_ResolutionSupport"."CommentaireVerification"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."V_ResolutionSupport"."CommentaireVerification" IS 'Donnée Support CommentaireVerification : valeur métier ou projection de la source liée, conservée avec son propriétaire et son contexte de dossier.';

--
-- Name: COLUMN "V_ResolutionSupport"."IdEntiteFk"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."V_ResolutionSupport"."IdEntiteFk" IS 'Entreprise propriétaire durable, indépendante du rattachement actuel du créateur.';

--
-- Name: COLUMN "V_ResolutionSupport"."ProposePar"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."V_ResolutionSupport"."ProposePar" IS 'Donnée Support ProposePar : valeur métier ou projection de la source liée, conservée avec son propriétaire et son contexte de dossier.';

--
-- Name: COLUMN "V_ResolutionSupport"."VerifiePar"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."V_ResolutionSupport"."VerifiePar" IS 'Donnée Support VerifiePar : valeur métier ou projection de la source liée, conservée avec son propriétaire et son contexte de dossier.';

--
-- Name: COLUMN "V_ResolutionSupport"."ResultatVerification"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."V_ResolutionSupport"."ResultatVerification" IS 'Libellé courant de la valeur centrale liée : AbrGenerique nettoyée, ou indication neutre avec ID_Generique si elle manque. Les identifiants, codes du circuit et données historiques ne sont pas réécrits.';

--
-- Name: V_Support; Type: VIEW; Schema: support; Owner: -
--

CREATE VIEW support."V_Support" AS
 SELECT s."ID_Support",
    s."IdEntiteFk",
    s."NumeroSupport",
    s."Objet",
    s."Description",
    s."ID_DemandeurFk",
    s."ID_CreateurFk",
    s."ID_ResponsableFk",
    s."ID_ServiceConcerneFk",
    s."ID_TypeSupportFk",
    s."ID_CategorieSupportFk",
    s."ID_PrioriteFk",
    s."ID_StatutFk",
    s."ID_CanalOrigineFk",
    s."ID_ImmobilisationFk",
    s."ID_CommandeFk",
    s."ID_ArticleFk",
    s."DateCreation",
    s."DateModification",
    s."DateEcheance",
    s."DateResolution",
    s."DateCloture",
    s."VersionEnregistrement",
    s."Archive",
    s."CircuitSnapshot",
    e."NomEntite",
    e."NomEntite" AS "Entreprise",
    d."Nom" AS "Demandeur",
    concat_ws(' '::text, u."PrenomUser", u."NomUser") AS "Createur",
    NULLIF(concat_ws(' '::text, r."PrenomUser", r."NomUser"), ''::text) AS "Responsable",
    (
        CASE
            WHEN (typ."ID_Generique" IS NULL) THEN NULL::text
            ELSE COALESCE(NULLIF(btrim((typ."AbrGenerique")::text), ''::text), ('Valeur sans abréviation #'::text || (typ."ID_Generique")::text))
        END)::character varying(255) AS "TypeSupport",
    (
        CASE
            WHEN (cat."ID_Generique" IS NULL) THEN NULL::text
            ELSE COALESCE(NULLIF(btrim((cat."AbrGenerique")::text), ''::text), ('Valeur sans abréviation #'::text || (cat."ID_Generique")::text))
        END)::character varying(255) AS "CategorieSupport",
    (
        CASE
            WHEN (pri."ID_Generique" IS NULL) THEN NULL::text
            ELSE COALESCE(NULLIF(btrim((pri."AbrGenerique")::text), ''::text), ('Valeur sans abréviation #'::text || (pri."ID_Generique")::text))
        END)::character varying(255) AS "Priorite",
    (
        CASE
            WHEN (sta."ID_Generique" IS NULL) THEN NULL::text
            ELSE COALESCE(NULLIF(btrim((sta."AbrGenerique")::text), ''::text), ('Valeur sans abréviation #'::text || (sta."ID_Generique")::text))
        END)::character varying(255) AS "Statut",
    (
        CASE
            WHEN (can."ID_Generique" IS NULL) THEN NULL::text
            ELSE COALESCE(NULLIF(btrim((can."AbrGenerique")::text), ''::text), ('Valeur sans abréviation #'::text || (can."ID_Generique")::text))
        END)::character varying(255) AS "CanalOrigine",
    (
        CASE
            WHEN (ser."ID_Generique" IS NULL) THEN NULL::text
            ELSE COALESCE(NULLIF(btrim((ser."AbrGenerique")::text), ''::text), ('Valeur sans abréviation #'::text || (ser."ID_Generique")::text))
        END)::character varying(255) AS "ServiceConcerne",
    support.fn_etat_support(s."CircuitSnapshot", s."ID_StatutFk") AS "StatutCode",
    ((NOT s."Archive") AND (support.fn_etat_support(s."CircuitSnapshot", s."ID_StatutFk") <> ALL (ARRAY['resolved'::text, 'closed'::text]))) AS "Ouvert",
    ((NOT s."Archive") AND (support.fn_etat_support(s."CircuitSnapshot", s."ID_StatutFk") <> ALL (ARRAY['resolved'::text, 'closed'::text])) AND (s."DateEcheance" < clock_timestamp())) AS "EnRetard",
    i."CodeImmobilisation",
    i."NomImmobilisation",
    c."CodeCmd",
    a."NomArticle",
    i."NomImmobilisation" AS "Immobilisation",
    c."CodeCmd" AS "BonStock",
    a."NomArticle" AS "Article",
    ( SELECT count(*) AS count
           FROM support."T_CommentaireSupport" x
          WHERE (x."ID_SupportFk" = s."ID_Support")) AS "NbCommentaires",
    ( SELECT count(*) AS count
           FROM support."T_ResolutionSupport" x
          WHERE (x."ID_SupportFk" = s."ID_Support")) AS "NbResolutions",
    ( SELECT count(*) AS count
           FROM (support."T_PieceSupport" x
             JOIN logistique."T_PieceJustificative" p ON ((p."ID_Piece" = x."ID_PieceFk")))
          WHERE ((x."ID_SupportFk" = s."ID_Support") AND (NOT p."Archive"))) AS "NbDocuments"
   FROM (((((((((((((support."T_Support" s
     JOIN systeme."T_Entite" e ON ((e."IdEntite" = s."IdEntiteFk")))
     LEFT JOIN logistique."T_Client" d ON ((d."ID_Client" = s."ID_DemandeurFk")))
     JOIN systeme."T_Utilisateurs" u ON ((u."IdUser" = s."ID_CreateurFk")))
     LEFT JOIN systeme."T_Utilisateurs" r ON ((r."IdUser" = s."ID_ResponsableFk")))
     JOIN referentiel."T_Generique" typ ON ((typ."ID_Generique" = s."ID_TypeSupportFk")))
     LEFT JOIN referentiel."T_Generique" cat ON ((cat."ID_Generique" = s."ID_CategorieSupportFk")))
     JOIN referentiel."T_Generique" pri ON ((pri."ID_Generique" = s."ID_PrioriteFk")))
     JOIN referentiel."T_Generique" sta ON ((sta."ID_Generique" = s."ID_StatutFk")))
     JOIN referentiel."T_Generique" can ON ((can."ID_Generique" = s."ID_CanalOrigineFk")))
     LEFT JOIN referentiel."T_Generique" ser ON ((ser."ID_Generique" = s."ID_ServiceConcerneFk")))
     LEFT JOIN logistique."T_Immobilisation" i ON ((i."ID_Immobilisation" = s."ID_ImmobilisationFk")))
     LEFT JOIN logistique."T_Commande" c ON ((c."ID_Commande" = s."ID_CommandeFk")))
     LEFT JOIN logistique."T_Article" a ON ((a."ID_Article" = s."ID_ArticleFk")));

--
-- Name: VIEW "V_Support"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON VIEW support."V_Support" IS 'Une ligne par dossier avec labels de référence courants, rôles du circuit capturé, entreprise durable et indicateurs exacts ; le service applique le périmètre utilisateur et la visibilité des échanges.';

--
-- Name: COLUMN "V_Support"."ID_Support"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."V_Support"."ID_Support" IS 'Donnée Support ID_Support : valeur métier ou projection de la source liée, conservée avec son propriétaire et son contexte de dossier.';

--
-- Name: COLUMN "V_Support"."IdEntiteFk"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."V_Support"."IdEntiteFk" IS 'Entreprise propriétaire durable, indépendante du rattachement actuel du créateur.';

--
-- Name: COLUMN "V_Support"."NumeroSupport"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."V_Support"."NumeroSupport" IS 'Numéro court SUP-identifiant attribué par PostgreSQL ; unique dans son entreprise et non modifiable.';

--
-- Name: COLUMN "V_Support"."Objet"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."V_Support"."Objet" IS 'Donnée Support Objet : valeur métier ou projection de la source liée, conservée avec son propriétaire et son contexte de dossier.';

--
-- Name: COLUMN "V_Support"."Description"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."V_Support"."Description" IS 'Donnée Support Description : valeur métier ou projection de la source liée, conservée avec son propriétaire et son contexte de dossier.';

--
-- Name: COLUMN "V_Support"."ID_DemandeurFk"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."V_Support"."ID_DemandeurFk" IS 'Tiers de T_Client dans la même entreprise ; peut ne pas disposer de compte connecté.';

--
-- Name: COLUMN "V_Support"."ID_CreateurFk"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."V_Support"."ID_CreateurFk" IS 'Compte actif ayant réellement créé le dossier ; identité attribuée depuis le contexte transactionnel validé.';

--
-- Name: COLUMN "V_Support"."ID_ResponsableFk"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."V_Support"."ID_ResponsableFk" IS 'Compte actif affectataire de la même entreprise ou administrateur de plateforme ; requis pour traiter le dossier.';

--
-- Name: COLUMN "V_Support"."ID_ServiceConcerneFk"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."V_Support"."ID_ServiceConcerneFk" IS 'Donnée Support ID_ServiceConcerneFk : valeur métier ou projection de la source liée, conservée avec son propriétaire et son contexte de dossier.';

--
-- Name: COLUMN "V_Support"."ID_TypeSupportFk"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."V_Support"."ID_TypeSupportFk" IS 'Donnée Support ID_TypeSupportFk : valeur métier ou projection de la source liée, conservée avec son propriétaire et son contexte de dossier.';

--
-- Name: COLUMN "V_Support"."ID_CategorieSupportFk"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."V_Support"."ID_CategorieSupportFk" IS 'Donnée Support ID_CategorieSupportFk : valeur métier ou projection de la source liée, conservée avec son propriétaire et son contexte de dossier.';

--
-- Name: COLUMN "V_Support"."ID_PrioriteFk"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."V_Support"."ID_PrioriteFk" IS 'Donnée Support ID_PrioriteFk : valeur métier ou projection de la source liée, conservée avec son propriétaire et son contexte de dossier.';

--
-- Name: COLUMN "V_Support"."ID_StatutFk"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."V_Support"."ID_StatutFk" IS 'ID_Generique de l’état courant dans le circuit initial du dossier, distinct de son libellé modifiable.';

--
-- Name: COLUMN "V_Support"."ID_CanalOrigineFk"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."V_Support"."ID_CanalOrigineFk" IS 'Donnée Support ID_CanalOrigineFk : valeur métier ou projection de la source liée, conservée avec son propriétaire et son contexte de dossier.';

--
-- Name: COLUMN "V_Support"."ID_ImmobilisationFk"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."V_Support"."ID_ImmobilisationFk" IS 'Matériel facultatif lié par FK réelle, propriétaire vérifié ; aucune opération de stock.';

--
-- Name: COLUMN "V_Support"."ID_CommandeFk"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."V_Support"."ID_CommandeFk" IS 'Bon facultatif lié par FK réelle et limité à la même entreprise.';

--
-- Name: COLUMN "V_Support"."ID_ArticleFk"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."V_Support"."ID_ArticleFk" IS 'Article facultatif lié par FK réelle et limité à la même entreprise.';

--
-- Name: COLUMN "V_Support"."DateCreation"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."V_Support"."DateCreation" IS 'Donnée Support DateCreation : valeur métier ou projection de la source liée, conservée avec son propriétaire et son contexte de dossier.';

--
-- Name: COLUMN "V_Support"."DateModification"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."V_Support"."DateModification" IS 'Donnée Support DateModification : valeur métier ou projection de la source liée, conservée avec son propriétaire et son contexte de dossier.';

--
-- Name: COLUMN "V_Support"."DateEcheance"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."V_Support"."DateEcheance" IS 'Donnée Support DateEcheance : valeur métier ou projection de la source liée, conservée avec son propriétaire et son contexte de dossier.';

--
-- Name: COLUMN "V_Support"."DateResolution"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."V_Support"."DateResolution" IS 'Instant effectif de passage à Résolu ; remise à NULL après réouverture, valeur antérieure conservée dans l’audit.';

--
-- Name: COLUMN "V_Support"."DateCloture"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."V_Support"."DateCloture" IS 'Instant de clôture après vérification conforme de la dernière solution ; NULL pendant un traitement rouvert.';

--
-- Name: COLUMN "V_Support"."VersionEnregistrement"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."V_Support"."VersionEnregistrement" IS 'Révision positive augmentée atomiquement à chaque écriture ; le service compare la version reçue sous verrou avant modification.';

--
-- Name: COLUMN "V_Support"."Archive"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."V_Support"."Archive" IS 'Retrait du parcours actif sans suppression du dossier, de ses échanges, résolutions et preuves.';

--
-- Name: COLUMN "V_Support"."CircuitSnapshot"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."V_Support"."CircuitSnapshot" IS 'Copie immuable du circuit système et de sa version à la création, avec les ID_Generique des états et résultats ; une modification de configuration ne migre aucun dossier.';

--
-- Name: COLUMN "V_Support"."NomEntite"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."V_Support"."NomEntite" IS 'Donnée Support NomEntite : valeur métier ou projection de la source liée, conservée avec son propriétaire et son contexte de dossier.';

--
-- Name: COLUMN "V_Support"."Entreprise"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."V_Support"."Entreprise" IS 'Donnée Support Entreprise : valeur métier ou projection de la source liée, conservée avec son propriétaire et son contexte de dossier.';

--
-- Name: COLUMN "V_Support"."Demandeur"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."V_Support"."Demandeur" IS 'Donnée Support Demandeur : valeur métier ou projection de la source liée, conservée avec son propriétaire et son contexte de dossier.';

--
-- Name: COLUMN "V_Support"."Createur"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."V_Support"."Createur" IS 'Donnée Support Createur : valeur métier ou projection de la source liée, conservée avec son propriétaire et son contexte de dossier.';

--
-- Name: COLUMN "V_Support"."Responsable"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."V_Support"."Responsable" IS 'Donnée Support Responsable : valeur métier ou projection de la source liée, conservée avec son propriétaire et son contexte de dossier.';

--
-- Name: COLUMN "V_Support"."TypeSupport"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."V_Support"."TypeSupport" IS 'Libellé courant de la valeur centrale liée : AbrGenerique nettoyée, ou indication neutre avec ID_Generique si elle manque. Les identifiants, codes du circuit et données historiques ne sont pas réécrits.';

--
-- Name: COLUMN "V_Support"."CategorieSupport"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."V_Support"."CategorieSupport" IS 'Libellé courant de la valeur centrale liée : AbrGenerique nettoyée, ou indication neutre avec ID_Generique si elle manque. Les identifiants, codes du circuit et données historiques ne sont pas réécrits.';

--
-- Name: COLUMN "V_Support"."Priorite"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."V_Support"."Priorite" IS 'Libellé courant de la valeur centrale liée : AbrGenerique nettoyée, ou indication neutre avec ID_Generique si elle manque. Les identifiants, codes du circuit et données historiques ne sont pas réécrits.';

--
-- Name: COLUMN "V_Support"."Statut"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."V_Support"."Statut" IS 'Libellé courant de la valeur centrale liée : AbrGenerique nettoyée, ou indication neutre avec ID_Generique si elle manque. Les identifiants, codes du circuit et données historiques ne sont pas réécrits.';

--
-- Name: COLUMN "V_Support"."CanalOrigine"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."V_Support"."CanalOrigine" IS 'Libellé courant de la valeur centrale liée : AbrGenerique nettoyée, ou indication neutre avec ID_Generique si elle manque. Les identifiants, codes du circuit et données historiques ne sont pas réécrits.';

--
-- Name: COLUMN "V_Support"."ServiceConcerne"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."V_Support"."ServiceConcerne" IS 'Libellé courant de la valeur centrale liée : AbrGenerique nettoyée, ou indication neutre avec ID_Generique si elle manque. Les identifiants, codes du circuit et données historiques ne sont pas réécrits.';

--
-- Name: COLUMN "V_Support"."StatutCode"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."V_Support"."StatutCode" IS 'Rôle du statut dans le circuit capturé : new, active, pending, resolved ou closed ; les libellés proviennent du référentiel.';

--
-- Name: COLUMN "V_Support"."Ouvert"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."V_Support"."Ouvert" IS 'Dossier non archivé non résolu et non clôturé ; inclut les états Nouveau, En cours et En attente.';

--
-- Name: COLUMN "V_Support"."EnRetard"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."V_Support"."EnRetard" IS 'Dossier non archivé toujours ouvert avec échéance passée ; critère partagé par indicateur et liste.';

--
-- Name: COLUMN "V_Support"."CodeImmobilisation"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."V_Support"."CodeImmobilisation" IS 'Donnée Support CodeImmobilisation : valeur métier ou projection de la source liée, conservée avec son propriétaire et son contexte de dossier.';

--
-- Name: COLUMN "V_Support"."NomImmobilisation"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."V_Support"."NomImmobilisation" IS 'Donnée Support NomImmobilisation : valeur métier ou projection de la source liée, conservée avec son propriétaire et son contexte de dossier.';

--
-- Name: COLUMN "V_Support"."CodeCmd"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."V_Support"."CodeCmd" IS 'Donnée Support CodeCmd : valeur métier ou projection de la source liée, conservée avec son propriétaire et son contexte de dossier.';

--
-- Name: COLUMN "V_Support"."NomArticle"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."V_Support"."NomArticle" IS 'Donnée Support NomArticle : valeur métier ou projection de la source liée, conservée avec son propriétaire et son contexte de dossier.';

--
-- Name: COLUMN "V_Support"."Immobilisation"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."V_Support"."Immobilisation" IS 'Donnée Support Immobilisation : valeur métier ou projection de la source liée, conservée avec son propriétaire et son contexte de dossier.';

--
-- Name: COLUMN "V_Support"."BonStock"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."V_Support"."BonStock" IS 'Donnée Support BonStock : valeur métier ou projection de la source liée, conservée avec son propriétaire et son contexte de dossier.';

--
-- Name: COLUMN "V_Support"."Article"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."V_Support"."Article" IS 'Donnée Support Article : valeur métier ou projection de la source liée, conservée avec son propriétaire et son contexte de dossier.';

--
-- Name: COLUMN "V_Support"."NbCommentaires"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."V_Support"."NbCommentaires" IS 'Donnée Support NbCommentaires : valeur métier ou projection de la source liée, conservée avec son propriétaire et son contexte de dossier.';

--
-- Name: COLUMN "V_Support"."NbResolutions"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."V_Support"."NbResolutions" IS 'Donnée Support NbResolutions : valeur métier ou projection de la source liée, conservée avec son propriétaire et son contexte de dossier.';

--
-- Name: COLUMN "V_Support"."NbDocuments"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."V_Support"."NbDocuments" IS 'Donnée Support NbDocuments : valeur métier ou projection de la source liée, conservée avec son propriétaire et son contexte de dossier.';
