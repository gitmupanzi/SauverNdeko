-- Extrait canonique du catalogue installé le 31/10/2026, sans données ni propriétaires imposés.
-- Voir SQL/README.md. Ces extraits documentent le domaine ; utiliser le fichier global pour une installation vide.
SET check_function_bodies = false;
SELECT pg_catalog.set_config('search_path', '', false);
CREATE SCHEMA IF NOT EXISTS "support";
--
-- Name: SCHEMA support; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA support IS 'Dossiers d’assistance, incidents et réclamations propres aux entreprises ; les référentiels et configurations restent dans leurs schémas communs.';

--
-- Name: fn_etat_support(jsonb, integer); Type: FUNCTION; Schema: support; Owner: -
--

CREATE FUNCTION support.fn_etat_support(p_circuit jsonb, p_statut integer) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$SELECT key FROM jsonb_each_text(p_circuit->'states') WHERE value=p_statut::text LIMIT 1$$;

--
-- Name: FUNCTION fn_etat_support(p_circuit jsonb, p_statut integer); Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON FUNCTION support.fn_etat_support(p_circuit jsonb, p_statut integer) IS 'Rôle sémantique d’un statut dans la copie exacte du circuit du dossier ; aucun libellé ni ID de catégorie dupliqué.';

--
-- Name: tr_enfant_support_verifier(); Type: FUNCTION; Schema: support; Owner: -
--

CREATE FUNCTION support.tr_enfant_support_verifier() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$
DECLARE actor integer:=systeme.fn_admin_actor_user_id();parent support."T_Support";state text;piece logistique."T_PieceJustificative";entity_id integer;
BEGIN
 IF TG_OP='DELETE' THEN RAISE EXCEPTION 'Les échanges, résolutions et preuves du dossier sont conservés.' USING ERRCODE='23514';END IF;
 SELECT * INTO parent FROM support."T_Support" WHERE "ID_Support"=NEW."ID_SupportFk" FOR UPDATE;
 IF NOT FOUND OR parent."Archive" THEN RAISE EXCEPTION 'Dossier inexistant ou archivé.' USING ERRCODE='23514';END IF;
 state:=support.fn_etat_support(parent."CircuitSnapshot",parent."ID_StatutFk");
 IF actor IS NULL OR NOT EXISTS(SELECT FROM systeme."T_Utilisateurs" WHERE "IdUser"=actor AND ("Is_Admin" OR "IdEntiteFk"=parent."IdEntiteFk")) THEN RAISE EXCEPTION 'Auteur hors entreprise du dossier.' USING ERRCODE='23514';END IF;
 IF TG_TABLE_NAME='T_CommentaireSupport' THEN
  IF TG_OP<>'INSERT' THEN RAISE EXCEPTION 'Les commentaires sont conservés sans réécriture.' USING ERRCODE='23514';END IF;
  IF state='closed' THEN RAISE EXCEPTION 'Rouvrez le dossier avant de commenter.' USING ERRCODE='23514';END IF;
  NEW."ID_AuteurFk":=actor;NEW."DateCreation":=clock_timestamp();NEW."DateModification":=NEW."DateCreation";
 ELSIF TG_TABLE_NAME='T_ResolutionSupport' THEN
  IF TG_OP='INSERT' THEN
   IF state NOT IN('active','pending') OR parent."ID_ResponsableFk" IS NULL THEN RAISE EXCEPTION 'Le dossier doit être pris en charge avant proposition de solution.' USING ERRCODE='23514';END IF;
   IF NEW."ID_ResultatVerificationFk" IS NOT NULL OR NEW."ID_VerifieParFk" IS NOT NULL OR NEW."DateVerification" IS NOT NULL THEN RAISE EXCEPTION 'La vérification intervient après la proposition.' USING ERRCODE='23514';END IF;
   NEW."ID_ProposeParFk":=actor;NEW."DateProposition":=clock_timestamp();
  ELSE
   IF ROW(NEW."ID_ResolutionSupport",NEW."ID_SupportFk",NEW."CauseIdentifiee",NEW."SolutionAppliquee",NEW."ID_ProposeParFk",NEW."DateProposition") IS DISTINCT FROM ROW(OLD."ID_ResolutionSupport",OLD."ID_SupportFk",OLD."CauseIdentifiee",OLD."SolutionAppliquee",OLD."ID_ProposeParFk",OLD."DateProposition") OR OLD."ID_ResultatVerificationFk" IS NOT NULL THEN RAISE EXCEPTION 'La tentative et sa vérification sont immuables ; créez une nouvelle tentative.' USING ERRCODE='23514';END IF;
   IF state<>'resolved' OR NEW."ID_ResolutionSupport" IS DISTINCT FROM (SELECT max("ID_ResolutionSupport") FROM support."T_ResolutionSupport" WHERE "ID_SupportFk"=parent."ID_Support") THEN RAISE EXCEPTION 'Seule la dernière résolution en attente peut être vérifiée.' USING ERRCODE='23514';END IF;
   IF actor=NEW."ID_ProposeParFk" THEN RAISE EXCEPTION 'La vérification doit être faite par une autre personne habilitée.' USING ERRCODE='23514';END IF;
   IF NEW."ID_ResultatVerificationFk" NOT IN((parent."CircuitSnapshot"->'verification'->>'accepted')::integer,(parent."CircuitSnapshot"->'verification'->>'rejected')::integer) OR NEW."ID_ResultatVerificationFk" IS NULL THEN RAISE EXCEPTION 'Résultat absent du circuit du dossier.' USING ERRCODE='23514';END IF;
   IF nullif(btrim(NEW."CommentaireVerification"),'') IS NULL THEN RAISE EXCEPTION 'Commentaire de vérification obligatoire.' USING ERRCODE='23514';END IF;
   NEW."ID_VerifieParFk":=actor;NEW."DateVerification":=clock_timestamp();
  END IF;
 ELSE
  IF TG_OP<>'INSERT' THEN RAISE EXCEPTION 'Le rattachement documentaire est immuable.' USING ERRCODE='23514';END IF;
  IF state='closed' THEN RAISE EXCEPTION 'Rouvrez le dossier avant ajout de preuve.' USING ERRCODE='23514';END IF;
  SELECT * INTO piece FROM logistique."T_PieceJustificative" WHERE "ID_Piece"=NEW."ID_PieceFk";
  IF piece."TypeObjet" IS DISTINCT FROM 'support' OR piece."ID_Objet" IS DISTINCT FROM NEW."ID_SupportFk" OR piece."IdEntiteFk" IS DISTINCT FROM parent."IdEntiteFk" THEN RAISE EXCEPTION 'Preuve liée à un autre dossier ou une autre entreprise.' USING ERRCODE='23514';END IF;
  IF NEW."ID_CommentaireSupportFk" IS NOT NULL AND NOT EXISTS(SELECT FROM support."T_CommentaireSupport" WHERE "ID_CommentaireSupport"=NEW."ID_CommentaireSupportFk" AND "ID_SupportFk"=parent."ID_Support" AND ("Visibilite"='public' OR NEW."Visibilite"='interne')) THEN RAISE EXCEPTION 'Commentaire de preuve incompatible avec le dossier ou sa visibilité.' USING ERRCODE='23514';END IF;
 END IF;
 RETURN NEW;
END $$;

--
-- Name: FUNCTION tr_enfant_support_verifier(); Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON FUNCTION support.tr_enfant_support_verifier() IS 'Verrouille le parent puis valide les échanges, les tentatives successives et les liaisons documentaires ; aucune confusion entre identifiant de tiers et compte, aucune preuve interentreprise, vérification par un auteur distinct.';

--
-- Name: tr_lien_proprietaire_conserver(); Type: FUNCTION; Schema: support; Owner: -
--

CREATE FUNCTION support.tr_lien_proprietaire_conserver() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$
DECLARE old_id bigint;col text;
BEGIN
 IF NEW."IdEntiteFk" IS NOT DISTINCT FROM OLD."IdEntiteFk" THEN RETURN NEW;END IF;
 CASE TG_TABLE_NAME
 WHEN 'T_Client' THEN old_id:=OLD."ID_Client";col:='ID_DemandeurFk';
 WHEN 'T_Immobilisation' THEN old_id:=OLD."ID_Immobilisation";col:='ID_ImmobilisationFk';
 WHEN 'T_Commande' THEN old_id:=OLD."ID_Commande";col:='ID_CommandeFk';
 WHEN 'T_Article' THEN old_id:=OLD."ID_Article";col:='ID_ArticleFk';
 WHEN 'T_Utilisateurs' THEN
  IF EXISTS(SELECT FROM support."T_Support" WHERE "ID_ResponsableFk"=OLD."IdUser") THEN RAISE EXCEPTION 'Utilisateur affecté à un dossier Support ; entreprise conservée.' USING ERRCODE='23514';END IF;RETURN NEW;
 ELSE RAISE EXCEPTION 'Lien métier non pris en charge.';
 END CASE;
 IF EXISTS(SELECT FROM support."T_Support" s WHERE (to_jsonb(s)->>col)::bigint=old_id) THEN RAISE EXCEPTION 'Objet lié à un dossier Support ; entreprise conservée.' USING ERRCODE='23514';END IF;
 RETURN NEW;
END $$;

--
-- Name: FUNCTION tr_lien_proprietaire_conserver(); Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON FUNCTION support.tr_lien_proprietaire_conserver() IS 'Empêche le déplacement interentreprise d’un tiers, article, bon, matériel ou affectataire déjà lié à un dossier, actif ou archivé ; complète les contrôles lors du rattachement.';

--
-- Name: tr_piece_liaison_complete(); Type: FUNCTION; Schema: support; Owner: -
--

CREATE FUNCTION support.tr_piece_liaison_complete() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$
BEGIN
 IF NEW."TypeObjet"='support' AND EXISTS(SELECT FROM logistique."T_PieceJustificative" WHERE "ID_Piece"=NEW."ID_Piece") AND NOT EXISTS(SELECT FROM support."T_PieceSupport" WHERE "ID_PieceFk"=NEW."ID_Piece" AND "ID_SupportFk"=NEW."ID_Objet") THEN RAISE EXCEPTION 'Une preuve Support exige sa liaison métier dans la même transaction.' USING ERRCODE='23514';END IF;
 RETURN NULL;
END $$;

--
-- Name: FUNCTION tr_piece_liaison_complete(); Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON FUNCTION support.tr_piece_liaison_complete() IS 'Contrainte différée : un fichier Support du stockage commun possède sa liaison FK de dossier avant commit ; aucune preuve orpheline publiée.';

--
-- Name: tr_support_audit(); Type: FUNCTION; Schema: support; Owner: -
--

CREATE FUNCTION support.tr_support_audit() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $_$
DECLARE before_data jsonb;after_data jsonb:=to_jsonb(NEW);ctx jsonb;parent_id bigint;entity_id integer;actor integer:=systeme.fn_admin_actor_user_id();
BEGIN
 IF TG_OP='UPDATE' THEN before_data:=to_jsonb(OLD);END IF;
 BEGIN ctx:=coalesce(nullif(current_setting('support.mutation',true),'')::jsonb,'{}'::jsonb);EXCEPTION WHEN invalid_text_representation THEN RAISE EXCEPTION 'Contexte d’audit invalide.' USING ERRCODE='23514';END;
 IF ctx<>'{}'::jsonb AND (coalesce(ctx->>'requestId','') !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' OR coalesce(ctx->>'payloadHash','') !~ '^[a-f0-9]{64}$' OR length(coalesce(ctx->>'motif',''))>2000) THEN RAISE EXCEPTION 'Preuve de requête invalide.' USING ERRCODE='23514';END IF;
 IF TG_TABLE_NAME='T_Support' THEN parent_id:=NEW."ID_Support";entity_id:=NEW."IdEntiteFk";
 ELSE parent_id:=NEW."ID_SupportFk";SELECT "IdEntiteFk" INTO entity_id FROM support."T_Support" WHERE "ID_Support"=parent_id;END IF;
 after_data:=systeme.fn_audit_sans_secrets(after_data)||jsonb_build_object('_actor',jsonb_build_object('IdUser',actor),'ID_SupportFk',parent_id,'requestId',ctx->>'requestId','payloadHash',ctx->>'payloadHash','operation',coalesce(ctx->>'operation',lower(TG_OP)),'_motif',ctx->>'motif');
 INSERT INTO systeme."T_Audit_Log"("TableName","Operation","OldData","NewData","ChangedAt","IdEntiteFk") VALUES('support.'||TG_TABLE_NAME,coalesce(ctx->>'operation',TG_OP),systeme.fn_audit_sans_secrets(before_data),after_data,CURRENT_TIMESTAMP AT TIME ZONE 'Africa/Kinshasa',entity_id);
 RETURN NULL;
END $_$;

--
-- Name: FUNCTION tr_support_audit(); Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON FUNCTION support.tr_support_audit() IS 'Réutilise le journal système pour une image par écriture métier, acteur, entreprise, motif et preuve UUID/hash, dans la même transaction ; aucun contenu binaire n’est dupliqué.';

--
-- Name: tr_support_verifier(); Type: FUNCTION; Schema: support; Owner: -
--

CREATE FUNCTION support.tr_support_verifier() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $_$
DECLARE actor integer:=systeme.fn_admin_actor_user_id();actor_entity integer;actor_global boolean;old_state text;new_state text;cfg jsonb;ctx jsonb;reason text;f record;latest support."T_ResolutionSupport";target_entity integer;
BEGIN
 IF TG_OP='DELETE' THEN RAISE EXCEPTION 'Archivez le dossier pour conserver son historique.' USING ERRCODE='23514';END IF;
 IF actor IS NULL THEN RAISE EXCEPTION 'Auteur actif requis.' USING ERRCODE='23514';END IF;
 SELECT "IdEntiteFk","Is_Admin" INTO actor_entity,actor_global FROM systeme."T_Utilisateurs" WHERE "IdUser"=actor;
 IF NOT actor_global AND actor_entity IS DISTINCT FROM NEW."IdEntiteFk" THEN RAISE EXCEPTION 'Dossier hors entreprise de l’auteur.' USING ERRCODE='23514';END IF;
 IF NOT EXISTS(SELECT FROM systeme."T_Entite" WHERE "IdEntite"=NEW."IdEntiteFk" AND "ValideEntite") THEN RAISE EXCEPTION 'Entreprise active requise.' USING ERRCODE='23514';END IF;
 BEGIN ctx:=coalesce(nullif(current_setting('support.mutation',true),'')::jsonb,'{}'::jsonb);EXCEPTION WHEN invalid_text_representation THEN RAISE EXCEPTION 'Contexte de traitement invalide.' USING ERRCODE='23514';END;
 reason:=nullif(btrim(ctx->>'motif'),'');
 IF TG_OP='INSERT' THEN
  NEW."NumeroSupport":='SUP-'||NEW."ID_Support"::text;NEW."ID_CreateurFk":=actor;NEW."CircuitSnapshot":=systeme.fn_support_circuit(NEW."IdEntiteFk");
  NEW."ID_StatutFk":=(NEW."CircuitSnapshot"->'states'->>'new')::integer;NEW."VersionEnregistrement":=1;
  NEW."DateCreation":=clock_timestamp();NEW."DateResolution":=NULL;NEW."DateCloture":=NULL;NEW."Archive":=false;
  -- Vérifier la configuration au moment de son utilisation, même si modifiée avant installation du garde.
  FOR f IN SELECT * FROM jsonb_each_text(NEW."CircuitSnapshot"->'states') LOOP
   IF f.value !~ '^[1-9][0-9]{0,8}$' OR NOT referentiel.fn_valider_reference_champ('support','T_Support','ID_StatutFk',f.value::integer,NEW."IdEntiteFk") THEN RAISE EXCEPTION 'Le circuit ne correspond plus aux statuts configurés.' USING ERRCODE='23514';END IF;
  END LOOP;
 ELSE
  IF ROW(NEW."ID_Support",NEW."IdEntiteFk",NEW."NumeroSupport",NEW."ID_CreateurFk",NEW."DateCreation",NEW."CircuitSnapshot") IS DISTINCT FROM ROW(OLD."ID_Support",OLD."IdEntiteFk",OLD."NumeroSupport",OLD."ID_CreateurFk",OLD."DateCreation",OLD."CircuitSnapshot") THEN RAISE EXCEPTION 'Identité, propriétaire et circuit initial du dossier immuables.' USING ERRCODE='23514';END IF;
  IF NEW."VersionEnregistrement"<>OLD."VersionEnregistrement" THEN RAISE EXCEPTION 'La révision est attribuée par la base.' USING ERRCODE='23514';END IF;
  NEW."VersionEnregistrement":=OLD."VersionEnregistrement"+1;
  old_state:=support.fn_etat_support(OLD."CircuitSnapshot",OLD."ID_StatutFk");
  IF OLD."Archive" AND NEW."Archive" THEN RAISE EXCEPTION 'Restaurez le dossier avant modification.' USING ERRCODE='23514';END IF;
  IF NOT OLD."Archive" AND NEW."Archive" AND old_state<>'closed' THEN RAISE EXCEPTION 'Seul un dossier clôturé peut être archivé.' USING ERRCODE='23514';END IF;
  IF OLD."Archive" IS DISTINCT FROM NEW."Archive" AND reason IS NULL THEN RAISE EXCEPTION 'Motif d’archivage ou de restauration obligatoire.' USING ERRCODE='23514';END IF;
  IF OLD."Archive" IS DISTINCT FROM NEW."Archive" AND (to_jsonb(NEW)-ARRAY['Archive','VersionEnregistrement','DateModification']) IS DISTINCT FROM (to_jsonb(OLD)-ARRAY['Archive','VersionEnregistrement','DateModification']) THEN RAISE EXCEPTION 'Archivage et modification se font séparément.' USING ERRCODE='23514';END IF;
 END IF;
 NEW."DateModification":=clock_timestamp();
 new_state:=support.fn_etat_support(NEW."CircuitSnapshot",NEW."ID_StatutFk");
 IF new_state IS NULL THEN RAISE EXCEPTION 'Statut absent du circuit du dossier.' USING ERRCODE='23514';END IF;
 IF TG_OP='UPDATE' AND NEW."ID_StatutFk" IS DISTINCT FROM OLD."ID_StatutFk" THEN
  IF NOT EXISTS(SELECT FROM jsonb_array_elements(NEW."CircuitSnapshot"->'transitions') e WHERE e->>'from'=old_state AND e->>'to'=new_state) THEN RAISE EXCEPTION 'Transition non autorisée par le circuit du dossier.' USING ERRCODE='23514';END IF;
  IF (new_state='pending' OR (old_state IN('resolved','closed') AND new_state='active')) AND reason IS NULL THEN RAISE EXCEPTION 'Un motif est obligatoire pour la mise en attente ou la réouverture.' USING ERRCODE='23514';END IF;
  IF new_state IN('active','pending','resolved') AND NEW."ID_ResponsableFk" IS NULL THEN RAISE EXCEPTION 'Responsable requis avant prise en charge.' USING ERRCODE='23514';END IF;
  SELECT * INTO latest FROM support."T_ResolutionSupport" WHERE "ID_SupportFk"=NEW."ID_Support" ORDER BY "ID_ResolutionSupport" DESC LIMIT 1;
  IF new_state='resolved' THEN
   IF latest."ID_ResolutionSupport" IS NULL OR latest."ID_ResultatVerificationFk" IS NOT NULL OR latest."DateProposition"<OLD."DateModification" THEN RAISE EXCEPTION 'Nouvelle solution documentée requise avant résolution.' USING ERRCODE='23514';END IF;
   NEW."DateResolution":=clock_timestamp();NEW."DateCloture":=NULL;
  ELSIF new_state='closed' THEN
   IF old_state<>'resolved' OR latest."ID_ResultatVerificationFk" IS DISTINCT FROM (NEW."CircuitSnapshot"->'verification'->>'accepted')::integer OR latest."ID_VerifieParFk" IS NULL OR latest."ID_VerifieParFk"=latest."ID_ProposeParFk" THEN RAISE EXCEPTION 'Résolution vérifiée conforme par un autre responsable requise avant clôture.' USING ERRCODE='23514';END IF;
   NEW."DateCloture":=clock_timestamp();
  ELSIF old_state IN('resolved','closed') THEN NEW."DateCloture":=NULL;NEW."DateResolution":=NULL;
  END IF;
 ELSIF TG_OP='UPDATE' THEN NEW."DateResolution":=OLD."DateResolution";NEW."DateCloture":=OLD."DateCloture";
 END IF;
 IF TG_OP='UPDATE' AND old_state='closed' AND new_state='closed' AND NEW."Archive"=OLD."Archive" THEN RAISE EXCEPTION 'Rouvrez le dossier avant modification.' USING ERRCODE='23514';END IF;
 IF NEW."ID_ResponsableFk" IS NOT NULL THEN PERFORM 1 FROM systeme."T_Utilisateurs" WHERE "IdUser"=NEW."ID_ResponsableFk" FOR SHARE;END IF;
 IF NEW."ID_DemandeurFk" IS NOT NULL THEN PERFORM 1 FROM logistique."T_Client" WHERE "ID_Client"=NEW."ID_DemandeurFk" FOR SHARE;END IF;
 IF NEW."ID_ImmobilisationFk" IS NOT NULL THEN PERFORM 1 FROM logistique."T_Immobilisation" WHERE "ID_Immobilisation"=NEW."ID_ImmobilisationFk" FOR SHARE;END IF;
 IF NEW."ID_CommandeFk" IS NOT NULL THEN PERFORM 1 FROM logistique."T_Commande" WHERE "ID_Commande"=NEW."ID_CommandeFk" FOR SHARE;END IF;
 IF NEW."ID_ArticleFk" IS NOT NULL THEN PERFORM 1 FROM logistique."T_Article" WHERE "ID_Article"=NEW."ID_ArticleFk" FOR SHARE;END IF;
 IF NEW."ID_ResponsableFk" IS NOT NULL AND (TG_OP='INSERT' OR NEW."ID_ResponsableFk" IS DISTINCT FROM OLD."ID_ResponsableFk") AND NOT EXISTS(SELECT FROM systeme."T_Utilisateurs" WHERE "IdUser"=NEW."ID_ResponsableFk" AND "ValideUser" AND ("IdEntiteFk"=NEW."IdEntiteFk" OR "Is_Admin")) THEN RAISE EXCEPTION 'Responsable actif hors entreprise.' USING ERRCODE='23514';END IF;
 IF new_state IN('active','pending','resolved') AND NEW."ID_ResponsableFk" IS NULL THEN RAISE EXCEPTION 'Responsable requis pendant le traitement.' USING ERRCODE='23514';END IF;
 IF NEW."ID_DemandeurFk" IS NOT NULL AND NOT EXISTS(SELECT FROM logistique."T_Client" WHERE "ID_Client"=NEW."ID_DemandeurFk" AND "IdEntiteFk"=NEW."IdEntiteFk") THEN RAISE EXCEPTION 'Demandeur hors entreprise.' USING ERRCODE='23514';END IF;
 IF NEW."ID_ImmobilisationFk" IS NOT NULL AND NOT EXISTS(SELECT FROM logistique."T_Immobilisation" WHERE "ID_Immobilisation"=NEW."ID_ImmobilisationFk" AND "IdEntiteFk"=NEW."IdEntiteFk") THEN RAISE EXCEPTION 'Matériel hors entreprise.' USING ERRCODE='23514';END IF;
 IF NEW."ID_CommandeFk" IS NOT NULL AND NOT EXISTS(SELECT FROM logistique."T_Commande" WHERE "ID_Commande"=NEW."ID_CommandeFk" AND "IdEntiteFk"=NEW."IdEntiteFk") THEN RAISE EXCEPTION 'Bon hors entreprise.' USING ERRCODE='23514';END IF;
 IF NEW."ID_ArticleFk" IS NOT NULL AND NOT EXISTS(SELECT FROM logistique."T_Article" WHERE "ID_Article"=NEW."ID_ArticleFk" AND "IdEntiteFk"=NEW."IdEntiteFk") THEN RAISE EXCEPTION 'Article hors entreprise.' USING ERRCODE='23514';END IF;
 FOR f IN SELECT * FROM referentiel."T_ChampReferentiel" WHERE "SchemaName"='support' AND "TableName"='T_Support' AND "ColumnName"<>'ID_StatutFk' LOOP
  IF TG_OP='UPDATE' AND to_jsonb(NEW)->f."ColumnName" IS NOT DISTINCT FROM to_jsonb(OLD)->f."ColumnName" THEN CONTINUE;END IF;
  IF to_jsonb(NEW)->>f."ColumnName" IS NOT NULL THEN PERFORM 1 FROM referentiel."T_Generique" WHERE "ID_Generique"=(to_jsonb(NEW)->>f."ColumnName")::integer FOR SHARE;END IF;
  IF NOT referentiel.fn_valider_reference_champ('support','T_Support',f."ColumnName",(to_jsonb(NEW)->>f."ColumnName")::integer,NEW."IdEntiteFk") THEN RAISE EXCEPTION 'Référence inactive ou incompatible : %.',f."ColumnName" USING ERRCODE='23514';END IF;
 END LOOP;
 RETURN NEW;
END $_$;

--
-- Name: FUNCTION tr_support_verifier(); Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON FUNCTION support.tr_support_verifier() IS 'Socle métier SQL : propriété et identité immuables, copie initiale du circuit, références dynamiques, cohérence d’entreprise, responsable obligatoire, motif, solution puis vérification distincte avant clôture ; révision et dates exclusivement attribuées par la base.';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: T_CommentaireSupport; Type: TABLE; Schema: support; Owner: -
--

CREATE TABLE support."T_CommentaireSupport" (
    "ID_CommentaireSupport" bigint NOT NULL,
    "ID_SupportFk" bigint NOT NULL,
    "ID_AuteurFk" integer NOT NULL,
    "Contenu" text NOT NULL,
    "Visibilite" text DEFAULT 'public'::text NOT NULL,
    "DateCreation" timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    "DateModification" timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    CONSTRAINT "T_CommentaireSupport_Contenu_check" CHECK (((length(btrim("Contenu")) >= 1) AND (length(btrim("Contenu")) <= 20000))),
    CONSTRAINT "T_CommentaireSupport_Visibilite_check" CHECK (("Visibilite" = ANY (ARRAY['public'::text, 'interne'::text])))
);

--
-- Name: TABLE "T_CommentaireSupport"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON TABLE support."T_CommentaireSupport" IS 'Échanges immuables du dossier, publics pour ses lecteurs autorisés ou internes aux gestionnaires ; aucune publication Internet.';

--
-- Name: COLUMN "T_CommentaireSupport"."ID_CommentaireSupport"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."T_CommentaireSupport"."ID_CommentaireSupport" IS 'Donnée Support ID_CommentaireSupport : valeur métier ou projection de la source liée, conservée avec son propriétaire et son contexte de dossier.';

--
-- Name: COLUMN "T_CommentaireSupport"."ID_SupportFk"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."T_CommentaireSupport"."ID_SupportFk" IS 'Donnée Support ID_SupportFk : valeur métier ou projection de la source liée, conservée avec son propriétaire et son contexte de dossier.';

--
-- Name: COLUMN "T_CommentaireSupport"."ID_AuteurFk"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."T_CommentaireSupport"."ID_AuteurFk" IS 'Donnée Support ID_AuteurFk : valeur métier ou projection de la source liée, conservée avec son propriétaire et son contexte de dossier.';

--
-- Name: COLUMN "T_CommentaireSupport"."Contenu"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."T_CommentaireSupport"."Contenu" IS 'Donnée Support Contenu : valeur métier ou projection de la source liée, conservée avec son propriétaire et son contexte de dossier.';

--
-- Name: COLUMN "T_CommentaireSupport"."Visibilite"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."T_CommentaireSupport"."Visibilite" IS 'public : lecteurs autorisés du dossier ; interne : gestionnaires habilités uniquement, jamais un partage Internet.';

--
-- Name: COLUMN "T_CommentaireSupport"."DateCreation"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."T_CommentaireSupport"."DateCreation" IS 'Donnée Support DateCreation : valeur métier ou projection de la source liée, conservée avec son propriétaire et son contexte de dossier.';

--
-- Name: COLUMN "T_CommentaireSupport"."DateModification"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."T_CommentaireSupport"."DateModification" IS 'Donnée Support DateModification : valeur métier ou projection de la source liée, conservée avec son propriétaire et son contexte de dossier.';

--
-- Name: T_CommentaireSupport_ID_CommentaireSupport_seq; Type: SEQUENCE; Schema: support; Owner: -
--

ALTER TABLE support."T_CommentaireSupport" ALTER COLUMN "ID_CommentaireSupport" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME support."T_CommentaireSupport_ID_CommentaireSupport_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

--
-- Name: T_PieceSupport; Type: TABLE; Schema: support; Owner: -
--

CREATE TABLE support."T_PieceSupport" (
    "ID_PieceFk" bigint NOT NULL,
    "ID_SupportFk" bigint NOT NULL,
    "ID_CommentaireSupportFk" bigint,
    "Visibilite" text DEFAULT 'public'::text NOT NULL,
    CONSTRAINT "T_PieceSupport_Visibilite_check" CHECK (("Visibilite" = ANY (ARRAY['public'::text, 'interne'::text])))
);

--
-- Name: TABLE "T_PieceSupport"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON TABLE support."T_PieceSupport" IS 'Liaison à clés étrangères du dossier vers le stockage privé T_PieceJustificative existant, sans duplication des octets ; commentaire facultatif du même dossier.';

--
-- Name: COLUMN "T_PieceSupport"."ID_PieceFk"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."T_PieceSupport"."ID_PieceFk" IS 'Vraie FK vers le stockage binaire privé existant logistique.T_PieceJustificative ; aucun octet dupliqué.';

--
-- Name: COLUMN "T_PieceSupport"."ID_SupportFk"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."T_PieceSupport"."ID_SupportFk" IS 'Donnée Support ID_SupportFk : valeur métier ou projection de la source liée, conservée avec son propriétaire et son contexte de dossier.';

--
-- Name: COLUMN "T_PieceSupport"."ID_CommentaireSupportFk"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."T_PieceSupport"."ID_CommentaireSupportFk" IS 'Commentaire facultatif appartenant au même dossier ; une preuve interne ne devient pas publique.';

--
-- Name: COLUMN "T_PieceSupport"."Visibilite"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."T_PieceSupport"."Visibilite" IS 'public : lecteurs autorisés du dossier ; interne : gestionnaires habilités uniquement, jamais un partage Internet.';

--
-- Name: T_ResolutionSupport; Type: TABLE; Schema: support; Owner: -
--

CREATE TABLE support."T_ResolutionSupport" (
    "ID_ResolutionSupport" bigint NOT NULL,
    "ID_SupportFk" bigint NOT NULL,
    "CauseIdentifiee" text NOT NULL,
    "SolutionAppliquee" text NOT NULL,
    "ID_ProposeParFk" integer NOT NULL,
    "DateProposition" timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    "ID_ResultatVerificationFk" integer,
    "ID_VerifieParFk" integer,
    "DateVerification" timestamp with time zone,
    "CommentaireVerification" text,
    CONSTRAINT "T_ResolutionSupport_CauseIdentifiee_check" CHECK (((length(btrim("CauseIdentifiee")) >= 1) AND (length(btrim("CauseIdentifiee")) <= 10000))),
    CONSTRAINT "T_ResolutionSupport_CommentaireVerification_check" CHECK ((("CommentaireVerification" IS NULL) OR (length("CommentaireVerification") <= 10000))),
    CONSTRAINT "T_ResolutionSupport_SolutionAppliquee_check" CHECK (((length(btrim("SolutionAppliquee")) >= 1) AND (length(btrim("SolutionAppliquee")) <= 20000))),
    CONSTRAINT ck_support_verificateur_distinct CHECK (("ID_VerifieParFk" IS DISTINCT FROM "ID_ProposeParFk")),
    CONSTRAINT ck_support_verification_complete CHECK (((("ID_ResultatVerificationFk" IS NULL) AND ("ID_VerifieParFk" IS NULL) AND ("DateVerification" IS NULL)) OR (("ID_ResultatVerificationFk" IS NOT NULL) AND ("ID_VerifieParFk" IS NOT NULL) AND ("DateVerification" IS NOT NULL))))
);

--
-- Name: TABLE "T_ResolutionSupport"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON TABLE support."T_ResolutionSupport" IS 'Tentatives successives de résolution, solution documentée et vérification contradictoire immuable ; une proposition n’est pas une clôture.';

--
-- Name: COLUMN "T_ResolutionSupport"."ID_ResolutionSupport"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."T_ResolutionSupport"."ID_ResolutionSupport" IS 'Donnée Support ID_ResolutionSupport : valeur métier ou projection de la source liée, conservée avec son propriétaire et son contexte de dossier.';

--
-- Name: COLUMN "T_ResolutionSupport"."ID_SupportFk"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."T_ResolutionSupport"."ID_SupportFk" IS 'Donnée Support ID_SupportFk : valeur métier ou projection de la source liée, conservée avec son propriétaire et son contexte de dossier.';

--
-- Name: COLUMN "T_ResolutionSupport"."CauseIdentifiee"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."T_ResolutionSupport"."CauseIdentifiee" IS 'Donnée Support CauseIdentifiee : valeur métier ou projection de la source liée, conservée avec son propriétaire et son contexte de dossier.';

--
-- Name: COLUMN "T_ResolutionSupport"."SolutionAppliquee"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."T_ResolutionSupport"."SolutionAppliquee" IS 'Donnée Support SolutionAppliquee : valeur métier ou projection de la source liée, conservée avec son propriétaire et son contexte de dossier.';

--
-- Name: COLUMN "T_ResolutionSupport"."ID_ProposeParFk"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."T_ResolutionSupport"."ID_ProposeParFk" IS 'Auteur réel de cette tentative de résolution ; les tentatives antérieures restent conservées.';

--
-- Name: COLUMN "T_ResolutionSupport"."DateProposition"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."T_ResolutionSupport"."DateProposition" IS 'Donnée Support DateProposition : valeur métier ou projection de la source liée, conservée avec son propriétaire et son contexte de dossier.';

--
-- Name: COLUMN "T_ResolutionSupport"."ID_ResultatVerificationFk"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."T_ResolutionSupport"."ID_ResultatVerificationFk" IS 'Résultat dans T_Generique, parmi ceux capturés dans le circuit ; NULL tant que la solution n’est pas vérifiée.';

--
-- Name: COLUMN "T_ResolutionSupport"."ID_VerifieParFk"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."T_ResolutionSupport"."ID_VerifieParFk" IS 'Personne habilitée ayant vérifié la dernière solution, obligatoirement différente de son auteur.';

--
-- Name: COLUMN "T_ResolutionSupport"."DateVerification"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."T_ResolutionSupport"."DateVerification" IS 'Donnée Support DateVerification : valeur métier ou projection de la source liée, conservée avec son propriétaire et son contexte de dossier.';

--
-- Name: COLUMN "T_ResolutionSupport"."CommentaireVerification"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."T_ResolutionSupport"."CommentaireVerification" IS 'Donnée Support CommentaireVerification : valeur métier ou projection de la source liée, conservée avec son propriétaire et son contexte de dossier.';

--
-- Name: T_ResolutionSupport_ID_ResolutionSupport_seq; Type: SEQUENCE; Schema: support; Owner: -
--

ALTER TABLE support."T_ResolutionSupport" ALTER COLUMN "ID_ResolutionSupport" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME support."T_ResolutionSupport_ID_ResolutionSupport_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

--
-- Name: T_Support; Type: TABLE; Schema: support; Owner: -
--

CREATE TABLE support."T_Support" (
    "ID_Support" bigint NOT NULL,
    "IdEntiteFk" integer NOT NULL,
    "NumeroSupport" character varying(40) NOT NULL,
    "Objet" character varying(200) NOT NULL,
    "Description" text NOT NULL,
    "ID_DemandeurFk" bigint,
    "ID_CreateurFk" integer NOT NULL,
    "ID_ResponsableFk" integer,
    "ID_ServiceConcerneFk" integer,
    "ID_TypeSupportFk" integer NOT NULL,
    "ID_CategorieSupportFk" integer,
    "ID_PrioriteFk" integer NOT NULL,
    "ID_StatutFk" integer NOT NULL,
    "ID_CanalOrigineFk" integer NOT NULL,
    "ID_ImmobilisationFk" integer,
    "ID_CommandeFk" integer,
    "ID_ArticleFk" integer,
    "DateCreation" timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    "DateModification" timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    "DateEcheance" timestamp with time zone,
    "DateResolution" timestamp with time zone,
    "DateCloture" timestamp with time zone,
    "VersionEnregistrement" bigint DEFAULT 1 NOT NULL,
    "Archive" boolean DEFAULT false NOT NULL,
    "CircuitSnapshot" jsonb NOT NULL,
    CONSTRAINT "T_Support_CircuitSnapshot_check" CHECK ((jsonb_typeof("CircuitSnapshot") = 'object'::text)),
    CONSTRAINT "T_Support_DateEcheance_check" CHECK ((("DateEcheance" IS NULL) OR isfinite("DateEcheance"))),
    CONSTRAINT "T_Support_Description_check" CHECK (((length(btrim("Description")) >= 1) AND (length(btrim("Description")) <= 20000))),
    CONSTRAINT "T_Support_Objet_check" CHECK (((length(btrim(("Objet")::text)) >= 1) AND (length(btrim(("Objet")::text)) <= 200))),
    CONSTRAINT "T_Support_VersionEnregistrement_check" CHECK (("VersionEnregistrement" > 0))
);

--
-- Name: TABLE "T_Support"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON TABLE support."T_Support" IS 'Dossier d’assistance ou de réclamation appartenant durablement à une entreprise. Le numéro, l’auteur et le circuit initial sont immuables ; la résolution est distincte de sa vérification et de la clôture.';

--
-- Name: COLUMN "T_Support"."ID_Support"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."T_Support"."ID_Support" IS 'Donnée Support ID_Support : valeur métier ou projection de la source liée, conservée avec son propriétaire et son contexte de dossier.';

--
-- Name: COLUMN "T_Support"."IdEntiteFk"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."T_Support"."IdEntiteFk" IS 'Entreprise propriétaire durable, indépendante du rattachement actuel du créateur.';

--
-- Name: COLUMN "T_Support"."NumeroSupport"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."T_Support"."NumeroSupport" IS 'Numéro court SUP-identifiant attribué par PostgreSQL ; unique dans son entreprise et non modifiable.';

--
-- Name: COLUMN "T_Support"."Objet"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."T_Support"."Objet" IS 'Donnée Support Objet : valeur métier ou projection de la source liée, conservée avec son propriétaire et son contexte de dossier.';

--
-- Name: COLUMN "T_Support"."Description"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."T_Support"."Description" IS 'Donnée Support Description : valeur métier ou projection de la source liée, conservée avec son propriétaire et son contexte de dossier.';

--
-- Name: COLUMN "T_Support"."ID_DemandeurFk"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."T_Support"."ID_DemandeurFk" IS 'Tiers de T_Client dans la même entreprise ; peut ne pas disposer de compte connecté.';

--
-- Name: COLUMN "T_Support"."ID_CreateurFk"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."T_Support"."ID_CreateurFk" IS 'Compte actif ayant réellement créé le dossier ; identité attribuée depuis le contexte transactionnel validé.';

--
-- Name: COLUMN "T_Support"."ID_ResponsableFk"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."T_Support"."ID_ResponsableFk" IS 'Compte actif affectataire de la même entreprise ou administrateur de plateforme ; requis pour traiter le dossier.';

--
-- Name: COLUMN "T_Support"."ID_ServiceConcerneFk"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."T_Support"."ID_ServiceConcerneFk" IS 'Donnée Support ID_ServiceConcerneFk : valeur métier ou projection de la source liée, conservée avec son propriétaire et son contexte de dossier.';

--
-- Name: COLUMN "T_Support"."ID_TypeSupportFk"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."T_Support"."ID_TypeSupportFk" IS 'Donnée Support ID_TypeSupportFk : valeur métier ou projection de la source liée, conservée avec son propriétaire et son contexte de dossier.';

--
-- Name: COLUMN "T_Support"."ID_CategorieSupportFk"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."T_Support"."ID_CategorieSupportFk" IS 'Donnée Support ID_CategorieSupportFk : valeur métier ou projection de la source liée, conservée avec son propriétaire et son contexte de dossier.';

--
-- Name: COLUMN "T_Support"."ID_PrioriteFk"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."T_Support"."ID_PrioriteFk" IS 'Donnée Support ID_PrioriteFk : valeur métier ou projection de la source liée, conservée avec son propriétaire et son contexte de dossier.';

--
-- Name: COLUMN "T_Support"."ID_StatutFk"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."T_Support"."ID_StatutFk" IS 'ID_Generique de l’état courant dans le circuit initial du dossier, distinct de son libellé modifiable.';

--
-- Name: COLUMN "T_Support"."ID_CanalOrigineFk"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."T_Support"."ID_CanalOrigineFk" IS 'Donnée Support ID_CanalOrigineFk : valeur métier ou projection de la source liée, conservée avec son propriétaire et son contexte de dossier.';

--
-- Name: COLUMN "T_Support"."ID_ImmobilisationFk"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."T_Support"."ID_ImmobilisationFk" IS 'Matériel facultatif lié par FK réelle, propriétaire vérifié ; aucune opération de stock.';

--
-- Name: COLUMN "T_Support"."ID_CommandeFk"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."T_Support"."ID_CommandeFk" IS 'Bon facultatif lié par FK réelle et limité à la même entreprise.';

--
-- Name: COLUMN "T_Support"."ID_ArticleFk"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."T_Support"."ID_ArticleFk" IS 'Article facultatif lié par FK réelle et limité à la même entreprise.';

--
-- Name: COLUMN "T_Support"."DateCreation"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."T_Support"."DateCreation" IS 'Donnée Support DateCreation : valeur métier ou projection de la source liée, conservée avec son propriétaire et son contexte de dossier.';

--
-- Name: COLUMN "T_Support"."DateModification"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."T_Support"."DateModification" IS 'Donnée Support DateModification : valeur métier ou projection de la source liée, conservée avec son propriétaire et son contexte de dossier.';

--
-- Name: COLUMN "T_Support"."DateEcheance"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."T_Support"."DateEcheance" IS 'Donnée Support DateEcheance : valeur métier ou projection de la source liée, conservée avec son propriétaire et son contexte de dossier.';

--
-- Name: COLUMN "T_Support"."DateResolution"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."T_Support"."DateResolution" IS 'Instant effectif de passage à Résolu ; remise à NULL après réouverture, valeur antérieure conservée dans l’audit.';

--
-- Name: COLUMN "T_Support"."DateCloture"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."T_Support"."DateCloture" IS 'Instant de clôture après vérification conforme de la dernière solution ; NULL pendant un traitement rouvert.';

--
-- Name: COLUMN "T_Support"."VersionEnregistrement"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."T_Support"."VersionEnregistrement" IS 'Révision positive augmentée atomiquement à chaque écriture ; le service compare la version reçue sous verrou avant modification.';

--
-- Name: COLUMN "T_Support"."Archive"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."T_Support"."Archive" IS 'Retrait du parcours actif sans suppression du dossier, de ses échanges, résolutions et preuves.';

--
-- Name: COLUMN "T_Support"."CircuitSnapshot"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON COLUMN support."T_Support"."CircuitSnapshot" IS 'Copie immuable du circuit système et de sa version à la création, avec les ID_Generique des états et résultats ; une modification de configuration ne migre aucun dossier.';

--
-- Name: T_Support_ID_Support_seq; Type: SEQUENCE; Schema: support; Owner: -
--

ALTER TABLE support."T_Support" ALTER COLUMN "ID_Support" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME support."T_Support_ID_Support_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

--
-- Name: T_CommentaireSupport T_CommentaireSupport_pkey; Type: CONSTRAINT; Schema: support; Owner: -
--

ALTER TABLE ONLY support."T_CommentaireSupport"
    ADD CONSTRAINT "T_CommentaireSupport_pkey" PRIMARY KEY ("ID_CommentaireSupport");

--
-- Name: T_PieceSupport T_PieceSupport_pkey; Type: CONSTRAINT; Schema: support; Owner: -
--

ALTER TABLE ONLY support."T_PieceSupport"
    ADD CONSTRAINT "T_PieceSupport_pkey" PRIMARY KEY ("ID_PieceFk");

--
-- Name: T_ResolutionSupport T_ResolutionSupport_pkey; Type: CONSTRAINT; Schema: support; Owner: -
--

ALTER TABLE ONLY support."T_ResolutionSupport"
    ADD CONSTRAINT "T_ResolutionSupport_pkey" PRIMARY KEY ("ID_ResolutionSupport");

--
-- Name: T_Support T_Support_pkey; Type: CONSTRAINT; Schema: support; Owner: -
--

ALTER TABLE ONLY support."T_Support"
    ADD CONSTRAINT "T_Support_pkey" PRIMARY KEY ("ID_Support");

--
-- Name: T_Support uq_support_numero_entite; Type: CONSTRAINT; Schema: support; Owner: -
--

ALTER TABLE ONLY support."T_Support"
    ADD CONSTRAINT uq_support_numero_entite UNIQUE ("IdEntiteFk", "NumeroSupport");

--
-- Name: INDEX "T_CommentaireSupport_pkey"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON INDEX support."T_CommentaireSupport_pkey" IS 'Index du Support pour intégrité, recherche par parent/entreprise et preuve de requête ; aucune permission n’en découle.';

--
-- Name: INDEX "T_PieceSupport_pkey"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON INDEX support."T_PieceSupport_pkey" IS 'Index du Support pour intégrité, recherche par parent/entreprise et preuve de requête ; aucune permission n’en découle.';

--
-- Name: INDEX "T_ResolutionSupport_pkey"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON INDEX support."T_ResolutionSupport_pkey" IS 'Index du Support pour intégrité, recherche par parent/entreprise et preuve de requête ; aucune permission n’en découle.';

--
-- Name: INDEX "T_Support_pkey"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON INDEX support."T_Support_pkey" IS 'Index du Support pour intégrité, recherche par parent/entreprise et preuve de requête ; aucune permission n’en découle.';

--
-- Name: ix_support_commentaire_parent; Type: INDEX; Schema: support; Owner: -
--

CREATE INDEX ix_support_commentaire_parent ON support."T_CommentaireSupport" USING btree ("ID_SupportFk", "ID_CommentaireSupport");

--
-- Name: INDEX ix_support_commentaire_parent; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON INDEX support.ix_support_commentaire_parent IS 'Index du Support pour intégrité, recherche par parent/entreprise et preuve de requête ; aucune permission n’en découle.';

--
-- Name: ix_support_echeance; Type: INDEX; Schema: support; Owner: -
--

CREATE INDEX ix_support_echeance ON support."T_Support" USING btree ("IdEntiteFk", "DateEcheance") WHERE (NOT "Archive");

--
-- Name: INDEX ix_support_echeance; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON INDEX support.ix_support_echeance IS 'Index du Support pour intégrité, recherche par parent/entreprise et preuve de requête ; aucune permission n’en découle.';

--
-- Name: ix_support_entite_statut; Type: INDEX; Schema: support; Owner: -
--

CREATE INDEX ix_support_entite_statut ON support."T_Support" USING btree ("IdEntiteFk", "Archive", "ID_StatutFk", "DateCreation" DESC);

--
-- Name: INDEX ix_support_entite_statut; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON INDEX support.ix_support_entite_statut IS 'Index du Support pour intégrité, recherche par parent/entreprise et preuve de requête ; aucune permission n’en découle.';

--
-- Name: ix_support_piece_parent; Type: INDEX; Schema: support; Owner: -
--

CREATE INDEX ix_support_piece_parent ON support."T_PieceSupport" USING btree ("ID_SupportFk");

--
-- Name: INDEX ix_support_piece_parent; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON INDEX support.ix_support_piece_parent IS 'Index du Support pour intégrité, recherche par parent/entreprise et preuve de requête ; aucune permission n’en découle.';

--
-- Name: ix_support_resolution_parent; Type: INDEX; Schema: support; Owner: -
--

CREATE INDEX ix_support_resolution_parent ON support."T_ResolutionSupport" USING btree ("ID_SupportFk", "ID_ResolutionSupport" DESC);

--
-- Name: INDEX ix_support_resolution_parent; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON INDEX support.ix_support_resolution_parent IS 'Index du Support pour intégrité, recherche par parent/entreprise et preuve de requête ; aucune permission n’en découle.';

--
-- Name: ix_support_responsable; Type: INDEX; Schema: support; Owner: -
--

CREATE INDEX ix_support_responsable ON support."T_Support" USING btree ("IdEntiteFk", "ID_ResponsableFk");

--
-- Name: INDEX ix_support_responsable; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON INDEX support.ix_support_responsable IS 'Index du Support pour intégrité, recherche par parent/entreprise et preuve de requête ; aucune permission n’en découle.';

--
-- Name: INDEX uq_support_numero_entite; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON INDEX support.uq_support_numero_entite IS 'Index du Support pour intégrité, recherche par parent/entreprise et preuve de requête ; aucune permission n’en découle.';

--
-- Name: T_CommentaireSupport a_commentaire_verifier; Type: TRIGGER; Schema: support; Owner: -
--

CREATE TRIGGER a_commentaire_verifier BEFORE INSERT OR DELETE OR UPDATE ON support."T_CommentaireSupport" FOR EACH ROW EXECUTE FUNCTION support.tr_enfant_support_verifier();

--
-- Name: TRIGGER a_commentaire_verifier ON "T_CommentaireSupport"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON TRIGGER a_commentaire_verifier ON support."T_CommentaireSupport" IS 'Garde ou audit transactionnel du Support : identité, circuit, références, entreprise et conservation des preuves vérifiés par la fonction liée.';

--
-- Name: T_PieceSupport a_piece_support_verifier; Type: TRIGGER; Schema: support; Owner: -
--

CREATE TRIGGER a_piece_support_verifier BEFORE INSERT OR DELETE OR UPDATE ON support."T_PieceSupport" FOR EACH ROW EXECUTE FUNCTION support.tr_enfant_support_verifier();

--
-- Name: TRIGGER a_piece_support_verifier ON "T_PieceSupport"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON TRIGGER a_piece_support_verifier ON support."T_PieceSupport" IS 'Garde ou audit transactionnel du Support : identité, circuit, références, entreprise et conservation des preuves vérifiés par la fonction liée.';

--
-- Name: T_ResolutionSupport a_resolution_verifier; Type: TRIGGER; Schema: support; Owner: -
--

CREATE TRIGGER a_resolution_verifier BEFORE INSERT OR DELETE OR UPDATE ON support."T_ResolutionSupport" FOR EACH ROW EXECUTE FUNCTION support.tr_enfant_support_verifier();

--
-- Name: TRIGGER a_resolution_verifier ON "T_ResolutionSupport"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON TRIGGER a_resolution_verifier ON support."T_ResolutionSupport" IS 'Garde ou audit transactionnel du Support : identité, circuit, références, entreprise et conservation des preuves vérifiés par la fonction liée.';

--
-- Name: T_Support a_support_verifier; Type: TRIGGER; Schema: support; Owner: -
--

CREATE TRIGGER a_support_verifier BEFORE INSERT OR DELETE OR UPDATE ON support."T_Support" FOR EACH ROW EXECUTE FUNCTION support.tr_support_verifier();

--
-- Name: TRIGGER a_support_verifier ON "T_Support"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON TRIGGER a_support_verifier ON support."T_Support" IS 'Garde ou audit transactionnel du Support : identité, circuit, références, entreprise et conservation des preuves vérifiés par la fonction liée.';

--
-- Name: T_CommentaireSupport z_commentaire_audit; Type: TRIGGER; Schema: support; Owner: -
--

CREATE TRIGGER z_commentaire_audit AFTER INSERT OR UPDATE ON support."T_CommentaireSupport" FOR EACH ROW EXECUTE FUNCTION support.tr_support_audit();

--
-- Name: TRIGGER z_commentaire_audit ON "T_CommentaireSupport"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON TRIGGER z_commentaire_audit ON support."T_CommentaireSupport" IS 'Garde ou audit transactionnel du Support : identité, circuit, références, entreprise et conservation des preuves vérifiés par la fonction liée.';

--
-- Name: T_PieceSupport z_piece_support_audit; Type: TRIGGER; Schema: support; Owner: -
--

CREATE TRIGGER z_piece_support_audit AFTER INSERT OR UPDATE ON support."T_PieceSupport" FOR EACH ROW EXECUTE FUNCTION support.tr_support_audit();

--
-- Name: TRIGGER z_piece_support_audit ON "T_PieceSupport"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON TRIGGER z_piece_support_audit ON support."T_PieceSupport" IS 'Garde ou audit transactionnel du Support : identité, circuit, références, entreprise et conservation des preuves vérifiés par la fonction liée.';

--
-- Name: T_ResolutionSupport z_resolution_audit; Type: TRIGGER; Schema: support; Owner: -
--

CREATE TRIGGER z_resolution_audit AFTER INSERT OR UPDATE ON support."T_ResolutionSupport" FOR EACH ROW EXECUTE FUNCTION support.tr_support_audit();

--
-- Name: TRIGGER z_resolution_audit ON "T_ResolutionSupport"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON TRIGGER z_resolution_audit ON support."T_ResolutionSupport" IS 'Garde ou audit transactionnel du Support : identité, circuit, références, entreprise et conservation des preuves vérifiés par la fonction liée.';

--
-- Name: T_Support z_support_audit; Type: TRIGGER; Schema: support; Owner: -
--

CREATE TRIGGER z_support_audit AFTER INSERT OR UPDATE ON support."T_Support" FOR EACH ROW EXECUTE FUNCTION support.tr_support_audit();

--
-- Name: TRIGGER z_support_audit ON "T_Support"; Type: COMMENT; Schema: support; Owner: -
--

COMMENT ON TRIGGER z_support_audit ON support."T_Support" IS 'Garde ou audit transactionnel du Support : identité, circuit, références, entreprise et conservation des preuves vérifiés par la fonction liée.';

--
-- Name: T_CommentaireSupport T_CommentaireSupport_ID_AuteurFk_fkey; Type: FK CONSTRAINT; Schema: support; Owner: -
--

ALTER TABLE ONLY support."T_CommentaireSupport"
    ADD CONSTRAINT "T_CommentaireSupport_ID_AuteurFk_fkey" FOREIGN KEY ("ID_AuteurFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON DELETE RESTRICT;

--
-- Name: T_CommentaireSupport T_CommentaireSupport_ID_SupportFk_fkey; Type: FK CONSTRAINT; Schema: support; Owner: -
--

ALTER TABLE ONLY support."T_CommentaireSupport"
    ADD CONSTRAINT "T_CommentaireSupport_ID_SupportFk_fkey" FOREIGN KEY ("ID_SupportFk") REFERENCES support."T_Support"("ID_Support") ON DELETE RESTRICT;

--
-- Name: T_PieceSupport T_PieceSupport_ID_CommentaireSupportFk_fkey; Type: FK CONSTRAINT; Schema: support; Owner: -
--

ALTER TABLE ONLY support."T_PieceSupport"
    ADD CONSTRAINT "T_PieceSupport_ID_CommentaireSupportFk_fkey" FOREIGN KEY ("ID_CommentaireSupportFk") REFERENCES support."T_CommentaireSupport"("ID_CommentaireSupport") ON DELETE RESTRICT;

--
-- Name: T_PieceSupport T_PieceSupport_ID_PieceFk_fkey; Type: FK CONSTRAINT; Schema: support; Owner: -
--

ALTER TABLE ONLY support."T_PieceSupport"
    ADD CONSTRAINT "T_PieceSupport_ID_PieceFk_fkey" FOREIGN KEY ("ID_PieceFk") REFERENCES logistique."T_PieceJustificative"("ID_Piece") ON DELETE RESTRICT;

--
-- Name: T_PieceSupport T_PieceSupport_ID_SupportFk_fkey; Type: FK CONSTRAINT; Schema: support; Owner: -
--

ALTER TABLE ONLY support."T_PieceSupport"
    ADD CONSTRAINT "T_PieceSupport_ID_SupportFk_fkey" FOREIGN KEY ("ID_SupportFk") REFERENCES support."T_Support"("ID_Support") ON DELETE RESTRICT;

--
-- Name: T_ResolutionSupport T_ResolutionSupport_ID_ProposeParFk_fkey; Type: FK CONSTRAINT; Schema: support; Owner: -
--

ALTER TABLE ONLY support."T_ResolutionSupport"
    ADD CONSTRAINT "T_ResolutionSupport_ID_ProposeParFk_fkey" FOREIGN KEY ("ID_ProposeParFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON DELETE RESTRICT;

--
-- Name: T_ResolutionSupport T_ResolutionSupport_ID_ResultatVerificationFk_fkey; Type: FK CONSTRAINT; Schema: support; Owner: -
--

ALTER TABLE ONLY support."T_ResolutionSupport"
    ADD CONSTRAINT "T_ResolutionSupport_ID_ResultatVerificationFk_fkey" FOREIGN KEY ("ID_ResultatVerificationFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON DELETE RESTRICT;

--
-- Name: T_ResolutionSupport T_ResolutionSupport_ID_SupportFk_fkey; Type: FK CONSTRAINT; Schema: support; Owner: -
--

ALTER TABLE ONLY support."T_ResolutionSupport"
    ADD CONSTRAINT "T_ResolutionSupport_ID_SupportFk_fkey" FOREIGN KEY ("ID_SupportFk") REFERENCES support."T_Support"("ID_Support") ON DELETE RESTRICT;

--
-- Name: T_ResolutionSupport T_ResolutionSupport_ID_VerifieParFk_fkey; Type: FK CONSTRAINT; Schema: support; Owner: -
--

ALTER TABLE ONLY support."T_ResolutionSupport"
    ADD CONSTRAINT "T_ResolutionSupport_ID_VerifieParFk_fkey" FOREIGN KEY ("ID_VerifieParFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON DELETE RESTRICT;

--
-- Name: T_Support T_Support_ID_ArticleFk_fkey; Type: FK CONSTRAINT; Schema: support; Owner: -
--

ALTER TABLE ONLY support."T_Support"
    ADD CONSTRAINT "T_Support_ID_ArticleFk_fkey" FOREIGN KEY ("ID_ArticleFk") REFERENCES logistique."T_Article"("ID_Article") ON DELETE RESTRICT;

--
-- Name: T_Support T_Support_ID_CanalOrigineFk_fkey; Type: FK CONSTRAINT; Schema: support; Owner: -
--

ALTER TABLE ONLY support."T_Support"
    ADD CONSTRAINT "T_Support_ID_CanalOrigineFk_fkey" FOREIGN KEY ("ID_CanalOrigineFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON DELETE RESTRICT;

--
-- Name: T_Support T_Support_ID_CategorieSupportFk_fkey; Type: FK CONSTRAINT; Schema: support; Owner: -
--

ALTER TABLE ONLY support."T_Support"
    ADD CONSTRAINT "T_Support_ID_CategorieSupportFk_fkey" FOREIGN KEY ("ID_CategorieSupportFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON DELETE RESTRICT;

--
-- Name: T_Support T_Support_ID_CommandeFk_fkey; Type: FK CONSTRAINT; Schema: support; Owner: -
--

ALTER TABLE ONLY support."T_Support"
    ADD CONSTRAINT "T_Support_ID_CommandeFk_fkey" FOREIGN KEY ("ID_CommandeFk") REFERENCES logistique."T_Commande"("ID_Commande") ON DELETE RESTRICT;

--
-- Name: T_Support T_Support_ID_CreateurFk_fkey; Type: FK CONSTRAINT; Schema: support; Owner: -
--

ALTER TABLE ONLY support."T_Support"
    ADD CONSTRAINT "T_Support_ID_CreateurFk_fkey" FOREIGN KEY ("ID_CreateurFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON DELETE RESTRICT;

--
-- Name: T_Support T_Support_ID_DemandeurFk_fkey; Type: FK CONSTRAINT; Schema: support; Owner: -
--

ALTER TABLE ONLY support."T_Support"
    ADD CONSTRAINT "T_Support_ID_DemandeurFk_fkey" FOREIGN KEY ("ID_DemandeurFk") REFERENCES logistique."T_Client"("ID_Client") ON DELETE RESTRICT;

--
-- Name: T_Support T_Support_ID_ImmobilisationFk_fkey; Type: FK CONSTRAINT; Schema: support; Owner: -
--

ALTER TABLE ONLY support."T_Support"
    ADD CONSTRAINT "T_Support_ID_ImmobilisationFk_fkey" FOREIGN KEY ("ID_ImmobilisationFk") REFERENCES logistique."T_Immobilisation"("ID_Immobilisation") ON DELETE RESTRICT;

--
-- Name: T_Support T_Support_ID_PrioriteFk_fkey; Type: FK CONSTRAINT; Schema: support; Owner: -
--

ALTER TABLE ONLY support."T_Support"
    ADD CONSTRAINT "T_Support_ID_PrioriteFk_fkey" FOREIGN KEY ("ID_PrioriteFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON DELETE RESTRICT;

--
-- Name: T_Support T_Support_ID_ResponsableFk_fkey; Type: FK CONSTRAINT; Schema: support; Owner: -
--

ALTER TABLE ONLY support."T_Support"
    ADD CONSTRAINT "T_Support_ID_ResponsableFk_fkey" FOREIGN KEY ("ID_ResponsableFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON DELETE RESTRICT;

--
-- Name: T_Support T_Support_ID_ServiceConcerneFk_fkey; Type: FK CONSTRAINT; Schema: support; Owner: -
--

ALTER TABLE ONLY support."T_Support"
    ADD CONSTRAINT "T_Support_ID_ServiceConcerneFk_fkey" FOREIGN KEY ("ID_ServiceConcerneFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON DELETE RESTRICT;

--
-- Name: T_Support T_Support_ID_StatutFk_fkey; Type: FK CONSTRAINT; Schema: support; Owner: -
--

ALTER TABLE ONLY support."T_Support"
    ADD CONSTRAINT "T_Support_ID_StatutFk_fkey" FOREIGN KEY ("ID_StatutFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON DELETE RESTRICT;

--
-- Name: T_Support T_Support_ID_TypeSupportFk_fkey; Type: FK CONSTRAINT; Schema: support; Owner: -
--

ALTER TABLE ONLY support."T_Support"
    ADD CONSTRAINT "T_Support_ID_TypeSupportFk_fkey" FOREIGN KEY ("ID_TypeSupportFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON DELETE RESTRICT;

--
-- Name: T_Support T_Support_IdEntiteFk_fkey; Type: FK CONSTRAINT; Schema: support; Owner: -
--

ALTER TABLE ONLY support."T_Support"
    ADD CONSTRAINT "T_Support_IdEntiteFk_fkey" FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON DELETE RESTRICT;
