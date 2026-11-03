-- Extrait canonique du catalogue vérifié le 02/11/2026, sans données ni propriétaires imposés.
-- Voir SQL/README.md. Ces extraits documentent le domaine ; utiliser le fichier global pour une installation vide.
SET check_function_bodies = false;
SELECT pg_catalog.set_config('search_path', '', false);
CREATE SCHEMA IF NOT EXISTS "professionnel";
--
-- Name: SCHEMA professionnel; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA professionnel IS 'Profils professionnels, spécialités et rattachements aux entités.';

--
-- Name: fn_expert_recherche(text); Type: FUNCTION; Schema: professionnel; Owner: -
--

CREATE FUNCTION professionnel.fn_expert_recherche(p_texte text) RETURNS tsquery
    LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE
    SET search_path TO 'pg_catalog'
    AS $$ SELECT plainto_tsquery('simple'::regconfig,referentiel.fn_normaliser_libelle(p_texte)) $$;

--
-- Name: FUNCTION fn_expert_recherche(p_texte text); Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON FUNCTION professionnel.fn_expert_recherche(p_texte text) IS 'Requête plein texte paramétrée en configuration simple, casse et espaces normalisés ; les mots courants sont reliés par les synonymes explicites de la référence sélectionnée.';

--
-- Name: fn_expert_reference_valide(text, text, integer, integer); Type: FUNCTION; Schema: professionnel; Owner: -
--

CREATE FUNCTION professionnel.fn_expert_reference_valide(p_table text, p_champ text, p_valeur integer, p_entite integer) RETURNS boolean
    LANGUAGE sql STABLE
    SET search_path TO 'pg_catalog'
    AS $$
 SELECT EXISTS(SELECT FROM referentiel."T_Generique" g JOIN referentiel."T_CategorieGenerique" c ON c."ID_CategorieGenerique"=g."ID_CategorieGeneriqueFk"
 WHERE g."ID_Generique"=p_valeur AND g."ValideGenerique" AND c."ValideCategorieGenerique" AND referentiel.fn_reference_visible(g."ID_Generique",p_entite)
 AND g."ID_CategorieGeneriqueFk"=ANY(coalesce(referentiel.fn_categories_champ('professionnel',p_table,p_champ,p_entite),ARRAY[]::integer[]))) $$;

--
-- Name: FUNCTION fn_expert_reference_valide(p_table text, p_champ text, p_valeur integer, p_entite integer); Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON FUNCTION professionnel.fn_expert_reference_valide(p_table text, p_champ text, p_valeur integer, p_entite integer) IS 'Contrôle d’une nouvelle sélection : famille configurée du vrai champ, validité de valeur/famille et portée de l’entreprise propriétaire.';

--
-- Name: tr_compte_professionnel_entreprise(); Type: FUNCTION; Schema: professionnel; Owner: -
--

CREATE FUNCTION professionnel.tr_compte_professionnel_entreprise() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$
BEGIN
 IF NEW."IdEntiteFk" IS DISTINCT FROM OLD."IdEntiteFk" AND EXISTS(SELECT FROM professionnel."T_Professionnel" p WHERE p."IdUserFk"=NEW."IdUser" AND p."IdEntiteFk" IS DISTINCT FROM NEW."IdEntiteFk") THEN
  RAISE EXCEPTION 'Ce compte possède une fiche professionnelle rattachée durablement à son entreprise.' USING ERRCODE='23514';END IF;
 RETURN NEW;
END $$;

--
-- Name: FUNCTION tr_compte_professionnel_entreprise(); Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON FUNCTION professionnel.tr_compte_professionnel_entreprise() IS 'Empêche un déplacement de compte qui contredirait la propriété durable d’une fiche professionnelle existante ; ne change ni authentification ni rôles.';

--
-- Name: tr_detail_professionnel_integrite(); Type: FUNCTION; Schema: professionnel; Owner: -
--

CREATE FUNCTION professionnel.tr_detail_professionnel_integrite() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$
DECLARE profile_id integer;owner_id integer;f text;val integer;
BEGIN
 profile_id:=CASE WHEN TG_OP='DELETE' THEN OLD."IdProfessionnelFk" ELSE NEW."IdProfessionnelFk" END;
 SELECT "IdEntiteFk" INTO owner_id FROM professionnel."T_Professionnel" WHERE "IdProfessionnel"=profile_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Fiche professionnelle introuvable.' USING ERRCODE='23503';END IF;
 IF TG_OP='DELETE' THEN RETURN OLD;END IF;
 IF TG_OP='UPDATE' AND NEW."IdProfessionnelFk" IS DISTINCT FROM OLD."IdProfessionnelFk" THEN RAISE EXCEPTION 'Le parent du détail est conservé.' USING ERRCODE='23514';END IF;
 IF TG_TABLE_NAME='T_Professionnel_Entite' THEN
  IF NOT EXISTS(SELECT FROM systeme."T_Entite" WHERE "IdEntite"=NEW."IdEntiteFk" AND "ValideEntite") AND (TG_OP='INSERT' OR NEW."IdEntiteFk" IS DISTINCT FROM OLD."IdEntiteFk") THEN RAISE EXCEPTION 'Structure inactive ou introuvable.' USING ERRCODE='23514';END IF;
  IF (NEW."DateDebut" IS NOT NULL AND NOT isfinite(NEW."DateDebut")) OR (NEW."DateFin" IS NOT NULL AND NOT isfinite(NEW."DateFin")) THEN RAISE EXCEPTION 'Période d’affiliation invalide.' USING ERRCODE='23514';END IF;
  IF NEW."EstPrincipal" THEN
   IF EXISTS(SELECT FROM professionnel."T_Professionnel_Entite" x WHERE x."IdProfessionnelFk"=profile_id AND x."IdEntiteFk"<>NEW."IdEntiteFk" AND x."EstPrincipal" AND tsrange(x."DateDebut",x."DateFin",'[)') && tsrange(NEW."DateDebut",NEW."DateFin",'[)')) THEN RAISE EXCEPTION 'Une seule affiliation principale est possible sur la même période.' USING ERRCODE='23514';END IF;
  END IF;
 END IF;
 RETURN NEW;
END $$;

--
-- Name: FUNCTION tr_detail_professionnel_integrite(); Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON FUNCTION professionnel.tr_detail_professionnel_integrite() IS 'Sérialise les détails sous le verrou du profil, conserve le parent et contrôle les affiliations principales et dates finies ; ne réattribue aucune entreprise.';

--
-- Name: tr_detail_professionnel_revision(); Type: FUNCTION; Schema: professionnel; Owner: -
--

CREATE FUNCTION professionnel.tr_detail_professionnel_revision() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$
DECLARE profile_id integer;actor_id integer:=nullif(current_setting('professionnel.actor_id',true),'')::integer;
BEGIN
 IF TG_OP='UPDATE' AND to_jsonb(NEW) IS NOT DISTINCT FROM to_jsonb(OLD) THEN RETURN NULL;END IF;
 profile_id:=CASE WHEN TG_OP='DELETE' THEN OLD."IdProfessionnelFk" ELSE NEW."IdProfessionnelFk" END;
 -- La garde BEFORE du détail a déjà verrouillé ce même parent. Un UPDATE
 -- ordinaire réutilise sa garde, sa révision, son horodatage et son audit.
 -- Sans acteur explicite, le dernier auteur devient inconnu plutôt que
 -- d'attribuer le changement au compte affecté ou à un ancien éditeur.
 IF actor_id IS NOT NULL AND NOT EXISTS(SELECT FROM systeme."T_Utilisateurs" WHERE "IdUser"=actor_id) THEN actor_id:=NULL;END IF;
 UPDATE professionnel."T_Professionnel" SET "ModifieParUserFk"=actor_id WHERE "IdProfessionnel"=profile_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'Fiche professionnelle parente introuvable.' USING ERRCODE='23503';END IF;
 RETURN NULL;
END $$;

--
-- Name: FUNCTION tr_detail_professionnel_revision(); Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON FUNCTION professionnel.tr_detail_professionnel_revision() IS 'Après un véritable ajout, changement ou retrait de détail, touche le parent sous le verrou existant pour incrémenter sa révision SQL et son horodatage/audit. Une mise à jour sans différence ne change pas sa version. Aucun compte ou propriétaire n’est déduit ; auteur NULL en l’absence de contexte explicite. Tout est annulé avec la transaction en cas de rejet.';

--
-- Name: tr_professionnel_audit(); Type: FUNCTION; Schema: professionnel; Owner: -
--

CREATE FUNCTION professionnel.tr_professionnel_audit() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$
DECLARE before_row jsonb;after_row jsonb;entity_id integer;profile_id integer;extra jsonb;
BEGIN
 extra:=jsonb_strip_nulls(jsonb_build_object('_requestId',nullif(current_setting('professionnel.request_id',true),''),'_payloadHash',nullif(current_setting('professionnel.payload_hash',true),''),'_actorId',nullif(current_setting('professionnel.actor_id',true),''),'_operation',nullif(current_setting('professionnel.operation',true),''),'_motif',nullif(current_setting('professionnel.motif',true),'')));
 IF TG_OP IN('UPDATE','DELETE') THEN before_row:=systeme.fn_audit_sans_secrets(to_jsonb(OLD))||extra;END IF;
 IF TG_OP IN('INSERT','UPDATE') THEN after_row:=systeme.fn_audit_sans_secrets(to_jsonb(NEW))||extra;END IF;
 IF TG_TABLE_NAME='T_Professionnel' THEN entity_id:=coalesce((after_row->>'IdEntiteFk')::integer,(before_row->>'IdEntiteFk')::integer);
 ELSIF TG_TABLE_NAME='T_SynonymeRecherche' THEN entity_id:=coalesce((after_row->>'IdEntiteFk')::integer,(before_row->>'IdEntiteFk')::integer);
 ELSE profile_id:=coalesce((after_row->>'IdProfessionnelFk')::integer,(before_row->>'IdProfessionnelFk')::integer);SELECT "IdEntiteFk" INTO entity_id FROM professionnel."T_Professionnel" WHERE "IdProfessionnel"=profile_id;END IF;
 INSERT INTO systeme."T_Audit_Log"("TableName","Operation","OldData","NewData","ChangedAt","IdEntiteFk") VALUES(TG_TABLE_SCHEMA||'.'||TG_TABLE_NAME,TG_OP,before_row,after_row,clock_timestamp(),entity_id);
 RETURN NULL;
END $$;

--
-- Name: FUNCTION tr_professionnel_audit(); Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON FUNCTION professionnel.tr_professionnel_audit() IS 'Événement SQL unique et transactionnel des fiches, sélections et affiliations ; images sans secrets et métadonnées de rejeu/acteur/motif. Ces métadonnées ne remplacent jamais les permissions serveur.';

--
-- Name: tr_professionnel_integrite(); Type: FUNCTION; Schema: professionnel; Owner: -
--

CREATE FUNCTION professionnel.tr_professionnel_integrite() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$
DECLARE account_entity integer;account_global boolean;actor integer:=nullif(current_setting('professionnel.actor_id',true),'')::integer;
BEGIN
 IF TG_OP='DELETE' THEN RAISE EXCEPTION 'Archivez la fiche pour conserver son historique.' USING ERRCODE='23514';END IF;
 IF TG_OP='UPDATE' AND (NEW."IdEntiteFk" IS DISTINCT FROM OLD."IdEntiteFk" OR NEW."IdUserFk" IS DISTINCT FROM OLD."IdUserFk" OR NEW."CreeLe" IS DISTINCT FROM OLD."CreeLe" OR NEW."CreeParUserFk" IS DISTINCT FROM OLD."CreeParUserFk" OR NEW."CreationRequestId" IS DISTINCT FROM OLD."CreationRequestId" OR NEW."CreationPayloadHash" IS DISTINCT FROM OLD."CreationPayloadHash") THEN RAISE EXCEPTION 'Propriétaire, compte et identité de création sont conservés.' USING ERRCODE='23514';END IF;
 IF TG_OP='INSERT' THEN
  SELECT "IdEntiteFk",coalesce("Is_Admin",false) INTO account_entity,account_global FROM systeme."T_Utilisateurs" WHERE "IdUser"=NEW."IdUserFk" FOR SHARE;
  IF NOT FOUND OR (account_entity IS DISTINCT FROM NEW."IdEntiteFk" AND NOT(account_entity IS NULL AND account_global AND coalesce(actor=NEW."IdUserFk",false))) THEN RAISE EXCEPTION 'Le compte professionnel appartient à une autre entreprise.' USING ERRCODE='23514';END IF;
  NEW."Revision":=1;NEW."CreeLe":=clock_timestamp();NEW."ModifieLe":=NEW."CreeLe";
 ELSE NEW."Revision":=OLD."Revision"+1;NEW."ModifieLe":=clock_timestamp();END IF;
 IF NEW."Publie" AND (TG_OP='INSERT' OR NOT OLD."Publie") THEN
  IF NOT EXISTS(SELECT FROM systeme."T_Utilisateurs" WHERE "IdUser"=NEW."IdUserFk" AND "ValideUser") OR NOT EXISTS(SELECT FROM systeme."T_Entite" WHERE "IdEntite"=NEW."IdEntiteFk" AND "ValideEntite") OR NOT NEW."ValideProfessionnel" THEN RAISE EXCEPTION 'Seule une fiche active d’un compte et d’une entreprise actifs peut être publiée.' USING ERRCODE='23514';END IF;
  IF NOT professionnel.fn_expert_reference_valide('T_Professionnel','IdTypeProfessionnelFk',NEW."IdTypeProfessionnelFk",NEW."IdEntiteFk") OR NOT professionnel.fn_expert_reference_valide('T_Professionnel','IdSecteurFk',NEW."IdSecteurFk",NEW."IdEntiteFk") OR (NEW."IdSpecialiteFk" IS NOT NULL AND NOT professionnel.fn_expert_reference_valide('T_Professionnel','IdSpecialiteFk',NEW."IdSpecialiteFk",NEW."IdEntiteFk")) THEN RAISE EXCEPTION 'Corrigez les références devenues incompatibles avant de publier.' USING ERRCODE='23514';END IF;
 END IF;
 RETURN NEW;
END $$;

--
-- Name: FUNCTION tr_professionnel_integrite(); Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON FUNCTION professionnel.tr_professionnel_integrite() IS 'Propriété et compte immuables, révision SQL, cohérence initiale compte/entreprise et publication explicite. Exception limitée au compte global qui se représente lui-même dans une entreprise choisie ; la GUC n’accorde aucun droit API.';

--
-- Name: tr_synonyme_portee(); Type: FUNCTION; Schema: professionnel; Owner: -
--

CREATE FUNCTION professionnel.tr_synonyme_portee() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$
DECLARE owner_id integer;
BEGIN
 SELECT "IdEntiteFk" INTO owner_id FROM referentiel."T_Generique" WHERE "ID_Generique"=NEW."IdGeneriqueFk" FOR SHARE;
 IF NOT FOUND OR NEW."IdEntiteFk" IS DISTINCT FROM owner_id THEN RAISE EXCEPTION 'La portée du synonyme doit être celle de sa référence.' USING ERRCODE='23514';END IF;
 RETURN NEW;
END $$;

--
-- Name: FUNCTION tr_synonyme_portee(); Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON FUNCTION professionnel.tr_synonyme_portee() IS 'Un terme de recherche hérite exactement de la portée de sa valeur centrale, sans exposer les dictionnaires d’une autre entreprise.';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: T_Professionnel; Type: TABLE; Schema: professionnel; Owner: -
--

CREATE TABLE professionnel."T_Professionnel" (
    "IdProfessionnel" integer CONSTRAINT "T_Professionnel_IdProfessionnel_not_null" NOT NULL,
    "IdUserFk" integer CONSTRAINT "T_Professionnel_IdUserFk_not_null" NOT NULL,
    "IdTypeProfessionnelFk" integer CONSTRAINT "T_Professionnel_IdTypeProfessionnelFk_not_null" NOT NULL,
    "IdSpecialiteFk" integer,
    "NumeroIdentification" character varying(50),
    "ExperienceAns" integer,
    "ObsProfessionnel" text,
    "ValideProfessionnel" boolean DEFAULT true,
    "IdEntiteFk" integer NOT NULL,
    "IdSecteurFk" integer,
    "TitrePublic" text,
    "PresentationPublique" text,
    "LocalitePublique" text,
    "ContactAutorise" boolean DEFAULT true NOT NULL,
    "Publie" boolean DEFAULT false NOT NULL,
    "Revision" bigint DEFAULT 1 NOT NULL,
    "CreeLe" timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    "ModifieLe" timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    "CreeParUserFk" integer,
    "ModifieParUserFk" integer,
    "CreationRequestId" uuid,
    "CreationPayloadHash" text,
    CONSTRAINT "Chk_Prof_Experience_NonNegative" CHECK ((("ExperienceAns" IS NULL) OR ("ExperienceAns" >= 0))),
    CONSTRAINT "Chk_Prof_NumeroIdentification_NotEmpty" CHECK ((("NumeroIdentification" IS NULL) OR (length(TRIM(BOTH FROM "NumeroIdentification")) > 0))),
    CONSTRAINT ck_prof_experience_max CHECK ((("ExperienceAns" IS NULL) OR ("ExperienceAns" <= 100))),
    CONSTRAINT ck_prof_localite CHECK ((("LocalitePublique" IS NULL) OR ((length(btrim("LocalitePublique")) >= 1) AND (length(btrim("LocalitePublique")) <= 255)))),
    CONSTRAINT ck_prof_note CHECK ((("ObsProfessionnel" IS NULL) OR (length("ObsProfessionnel") <= 5000))),
    CONSTRAINT ck_prof_presentation CHECK ((("PresentationPublique" IS NULL) OR ((length(btrim("PresentationPublique")) >= 1) AND (length(btrim("PresentationPublique")) <= 10000)))),
    CONSTRAINT ck_prof_publication CHECK (((NOT "Publie") OR (("IdSecteurFk" IS NOT NULL) AND (NULLIF(btrim("TitrePublic"), ''::text) IS NOT NULL) AND (NULLIF(btrim("PresentationPublique"), ''::text) IS NOT NULL)))),
    CONSTRAINT ck_prof_rejeu CHECK (((("CreationRequestId" IS NULL) = ("CreationPayloadHash" IS NULL)) AND (("CreationPayloadHash" IS NULL) OR ("CreationPayloadHash" ~ '^[a-f0-9]{64}$'::text)))),
    CONSTRAINT ck_prof_revision CHECK (("Revision" > 0)),
    CONSTRAINT ck_prof_titre CHECK ((("TitrePublic" IS NULL) OR ((length(btrim("TitrePublic")) >= 1) AND (length(btrim("TitrePublic")) <= 180))))
);

--
-- Name: TABLE "T_Professionnel"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON TABLE professionnel."T_Professionnel" IS 'Fiche professionnelle unique par compte et propriétaire entreprise durable. Les compétences sont déclarées, la publication est explicite et distincte de l’activité ; aucune validation de diplôme n’est déduite de ces états.';

--
-- Name: COLUMN "T_Professionnel"."IdProfessionnel"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."T_Professionnel"."IdProfessionnel" IS 'Identifiant du profil professionnel.';

--
-- Name: COLUMN "T_Professionnel"."IdUserFk"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."T_Professionnel"."IdUserFk" IS 'Utilisateur rattaché à l’enregistrement. Relation imposée : FOREIGN KEY ("IdUserFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE ON DELETE RESTRICT.';

--
-- Name: COLUMN "T_Professionnel"."IdTypeProfessionnelFk"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."T_Professionnel"."IdTypeProfessionnelFk" IS 'Type du professionnel dans le référentiel. Relation imposée : FOREIGN KEY ("IdTypeProfessionnelFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE ON DELETE RESTRICT.';

--
-- Name: COLUMN "T_Professionnel"."IdSpecialiteFk"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."T_Professionnel"."IdSpecialiteFk" IS 'Spécialité facultative du référentiel central ; son absence permet les professions transversales sans spécialité sanitaire artificielle.';

--
-- Name: COLUMN "T_Professionnel"."NumeroIdentification"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."T_Professionnel"."NumeroIdentification" IS 'Numéro d’identification professionnel déclaré ; une chaîne vide est interdite si renseigné.';

--
-- Name: COLUMN "T_Professionnel"."ExperienceAns"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."T_Professionnel"."ExperienceAns" IS 'Nombre d’années d’expérience déclaré pour le professionnel ; valeur négative interdite.';

--
-- Name: COLUMN "T_Professionnel"."ObsProfessionnel"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."T_Professionnel"."ObsProfessionnel" IS 'Observations enregistrées sur le profil professionnel.';

--
-- Name: COLUMN "T_Professionnel"."ValideProfessionnel"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."T_Professionnel"."ValideProfessionnel" IS 'Activité de la fiche, distincte de sa publication et de toute vérification de qualification ; faux désigne une fiche archivée.';

--
-- Name: COLUMN "T_Professionnel"."IdEntiteFk"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."T_Professionnel"."IdEntiteFk" IS 'Entreprise propriétaire immuable de la fiche ; distincte des structures auxquelles le professionnel est affilié.';

--
-- Name: COLUMN "T_Professionnel"."IdSecteurFk"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."T_Professionnel"."IdSecteurFk" IS 'Secteur déclaré, valeur T_Generique filtrée par le référencement central de ce champ ; requis pour publier.';

--
-- Name: COLUMN "T_Professionnel"."TitrePublic"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."T_Professionnel"."TitrePublic" IS 'Titre professionnel public volontaire, sans vérification automatique de qualification ; requis pour publier.';

--
-- Name: COLUMN "T_Professionnel"."PresentationPublique"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."T_Professionnel"."PresentationPublique" IS 'Présentation destinée aux lecteurs de l’annuaire ; séparée de la note interne ObsProfessionnel.';

--
-- Name: COLUMN "T_Professionnel"."LocalitePublique"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."T_Professionnel"."LocalitePublique" IS 'Localité ou zone de service déclarée, y compris prestations à distance ; aucune adresse personnelle n’est déduite du compte.';

--
-- Name: COLUMN "T_Professionnel"."ContactAutorise"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."T_Professionnel"."ContactAutorise" IS 'Autorise la demande de contact dans la messagerie pour un profil public actif ; ne publie ni email ni téléphone personnel.';

--
-- Name: COLUMN "T_Professionnel"."Publie"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."T_Professionnel"."Publie" IS 'Consentement de publication explicite, faux par défaut ; l’activité du profil ou du compte ne vaut jamais publication.';

--
-- Name: COLUMN "T_Professionnel"."Revision"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."T_Professionnel"."Revision" IS 'Version concurrente de la fiche, incrémentée par PostgreSQL ; le service la compare sous verrou avant modification.';

--
-- Name: COLUMN "T_Professionnel"."CreeLe"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."T_Professionnel"."CreeLe" IS 'Instant technique de création, conservé après enregistrement.';

--
-- Name: COLUMN "T_Professionnel"."ModifieLe"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."T_Professionnel"."ModifieLe" IS 'Instant technique de la dernière modification de la fiche.';

--
-- Name: COLUMN "T_Professionnel"."CreeParUserFk"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."T_Professionnel"."CreeParUserFk" IS 'Compte auteur de la création, distinct du compte professionnel représenté.';

--
-- Name: COLUMN "T_Professionnel"."ModifieParUserFk"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."T_Professionnel"."ModifieParUserFk" IS 'Compte auteur de la dernière modification autorisée.';

--
-- Name: COLUMN "T_Professionnel"."CreationRequestId"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."T_Professionnel"."CreationRequestId" IS 'Identifiant UUID de demande pour le rejeu de création, unique et immuable.';

--
-- Name: COLUMN "T_Professionnel"."CreationPayloadHash"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."T_Professionnel"."CreationPayloadHash" IS 'Empreinte SHA256 du contenu normalisé de création ; ne contient aucun secret de compte.';

--
-- Name: CONSTRAINT "T_Professionnel_IdProfessionnel_not_null" ON "T_Professionnel"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON CONSTRAINT "T_Professionnel_IdProfessionnel_not_null" ON professionnel."T_Professionnel" IS 'Non-nullité : exige une valeur renseignée dans "professionnel"."T_Professionnel". Définition : NOT NULL "IdProfessionnel".';

--
-- Name: CONSTRAINT "T_Professionnel_IdUserFk_not_null" ON "T_Professionnel"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON CONSTRAINT "T_Professionnel_IdUserFk_not_null" ON professionnel."T_Professionnel" IS 'Non-nullité : exige une valeur renseignée dans "professionnel"."T_Professionnel". Définition : NOT NULL "IdUserFk".';

--
-- Name: CONSTRAINT "T_Professionnel_IdTypeProfessionnelFk_not_null" ON "T_Professionnel"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON CONSTRAINT "T_Professionnel_IdTypeProfessionnelFk_not_null" ON professionnel."T_Professionnel" IS 'Non-nullité : exige une valeur renseignée dans "professionnel"."T_Professionnel". Définition : NOT NULL "IdTypeProfessionnelFk".';

--
-- Name: CONSTRAINT "Chk_Prof_Experience_NonNegative" ON "T_Professionnel"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON CONSTRAINT "Chk_Prof_Experience_NonNegative" ON professionnel."T_Professionnel" IS 'Contrôle de cohérence des valeurs autorisées dans "professionnel"."T_Professionnel". Définition : CHECK ("ExperienceAns" IS NULL OR "ExperienceAns" >= 0).';

--
-- Name: CONSTRAINT "Chk_Prof_NumeroIdentification_NotEmpty" ON "T_Professionnel"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON CONSTRAINT "Chk_Prof_NumeroIdentification_NotEmpty" ON professionnel."T_Professionnel" IS 'Contrôle de cohérence des valeurs autorisées dans "professionnel"."T_Professionnel". Définition : CHECK ("NumeroIdentification" IS NULL OR length(TRIM(BOTH FROM "NumeroIdentification")) > 0).';

--
-- Name: T_Professionnel_Competence; Type: TABLE; Schema: professionnel; Owner: -
--

CREATE TABLE professionnel."T_Professionnel_Competence" (
    "IdProfessionnelFk" integer NOT NULL,
    "IdCompetenceFk" integer NOT NULL
);

--
-- Name: TABLE "T_Professionnel_Competence"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON TABLE professionnel."T_Professionnel_Competence" IS 'Liaison entre fiche et compétence déclarée du référentiel central ; cette sélection n’est pas une certification.';

--
-- Name: COLUMN "T_Professionnel_Competence"."IdProfessionnelFk"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."T_Professionnel_Competence"."IdProfessionnelFk" IS 'Fiche professionnelle propriétaire ; son entreprise détermine le contexte des références.';

--
-- Name: COLUMN "T_Professionnel_Competence"."IdCompetenceFk"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."T_Professionnel_Competence"."IdCompetenceFk" IS 'Valeur ID_Generique d’une famille de compétences configurée pour ce champ.';

--
-- Name: T_Professionnel_Entite; Type: TABLE; Schema: professionnel; Owner: -
--

CREATE TABLE professionnel."T_Professionnel_Entite" (
    "IdProfessionnelFk" integer CONSTRAINT "T_Professionnel_Entite_IdProfessionnelFk_not_null" NOT NULL,
    "IdEntiteFk" integer CONSTRAINT "T_Professionnel_Entite_IdEntiteFk_not_null" NOT NULL,
    "IdTypeLienFk" integer,
    "DateDebut" timestamp without time zone,
    "DateFin" timestamp without time zone,
    "EstPrincipal" boolean DEFAULT false,
    "ObsLien" text,
    CONSTRAINT "Chk_ProfEnt_Period" CHECK ((("DateFin" IS NULL) OR ("DateDebut" IS NULL) OR ("DateFin" >= "DateDebut")))
);

--
-- Name: TABLE "T_Professionnel_Entite"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON TABLE professionnel."T_Professionnel_Entite" IS 'Rattachement d’un professionnel à une entité, identifié par leur couple, avec type de lien, période et indicateur de lien principal.';

--
-- Name: COLUMN "T_Professionnel_Entite"."IdProfessionnelFk"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."T_Professionnel_Entite"."IdProfessionnelFk" IS 'Professionnel rattaché à la discussion ou à l’entité. Relation imposée : FOREIGN KEY ("IdProfessionnelFk") REFERENCES professionnel."T_Professionnel"("IdProfessionnel") ON UPDATE CASCADE ON DELETE CASCADE.';

--
-- Name: COLUMN "T_Professionnel_Entite"."IdEntiteFk"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."T_Professionnel_Entite"."IdEntiteFk" IS 'Entité de rattachement de l’enregistrement. Relation imposée : FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON UPDATE CASCADE ON DELETE RESTRICT.';

--
-- Name: COLUMN "T_Professionnel_Entite"."IdTypeLienFk"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."T_Professionnel_Entite"."IdTypeLienFk" IS 'Type de relation entre professionnel et entité. Relation imposée : FOREIGN KEY ("IdTypeLienFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE ON DELETE RESTRICT.';

--
-- Name: COLUMN "T_Professionnel_Entite"."DateDebut"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."T_Professionnel_Entite"."DateDebut" IS 'Début du rattachement professionnel à l’entité.';

--
-- Name: COLUMN "T_Professionnel_Entite"."DateFin"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."T_Professionnel_Entite"."DateFin" IS 'Fin éventuelle du rattachement ; ne peut précéder DateDebut lorsque les deux dates sont renseignées.';

--
-- Name: COLUMN "T_Professionnel_Entite"."EstPrincipal"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."T_Professionnel_Entite"."EstPrincipal" IS 'Indique si ce rattachement professionnel est marqué comme principal.';

--
-- Name: COLUMN "T_Professionnel_Entite"."ObsLien"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."T_Professionnel_Entite"."ObsLien" IS 'Observations enregistrées sur le rattachement professionnel.';

--
-- Name: CONSTRAINT "T_Professionnel_Entite_IdProfessionnelFk_not_null" ON "T_Professionnel_Entite"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON CONSTRAINT "T_Professionnel_Entite_IdProfessionnelFk_not_null" ON professionnel."T_Professionnel_Entite" IS 'Non-nullité : exige une valeur renseignée dans "professionnel"."T_Professionnel_Entite". Définition : NOT NULL "IdProfessionnelFk".';

--
-- Name: CONSTRAINT "T_Professionnel_Entite_IdEntiteFk_not_null" ON "T_Professionnel_Entite"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON CONSTRAINT "T_Professionnel_Entite_IdEntiteFk_not_null" ON professionnel."T_Professionnel_Entite" IS 'Non-nullité : exige une valeur renseignée dans "professionnel"."T_Professionnel_Entite". Définition : NOT NULL "IdEntiteFk".';

--
-- Name: CONSTRAINT "Chk_ProfEnt_Period" ON "T_Professionnel_Entite"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON CONSTRAINT "Chk_ProfEnt_Period" ON professionnel."T_Professionnel_Entite" IS 'Contrôle de cohérence des valeurs autorisées dans "professionnel"."T_Professionnel_Entite". Définition : CHECK ("DateFin" IS NULL OR "DateDebut" IS NULL OR "DateFin" >= "DateDebut").';

--
-- Name: T_Professionnel_IdProfessionnel_seq; Type: SEQUENCE; Schema: professionnel; Owner: -
--

ALTER TABLE professionnel."T_Professionnel" ALTER COLUMN "IdProfessionnel" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME professionnel."T_Professionnel_IdProfessionnel_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

--
-- Name: SEQUENCE "T_Professionnel_IdProfessionnel_seq"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON SEQUENCE professionnel."T_Professionnel_IdProfessionnel_seq" IS 'Séquence de génération de "professionnel"."T_Professionnel"."IdProfessionnel". Les valeurs produites identifient les enregistrements ; les écarts de numérotation ne prouvent pas une suppression.';

--
-- Name: T_Professionnel_Prestation; Type: TABLE; Schema: professionnel; Owner: -
--

CREATE TABLE professionnel."T_Professionnel_Prestation" (
    "IdProfessionnelFk" integer NOT NULL,
    "IdPrestationFk" integer NOT NULL
);

--
-- Name: TABLE "T_Professionnel_Prestation"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON TABLE professionnel."T_Professionnel_Prestation" IS 'Liaison entre fiche et prestation proposée du référentiel central ; aucune table de dictionnaire locale.';

--
-- Name: COLUMN "T_Professionnel_Prestation"."IdProfessionnelFk"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."T_Professionnel_Prestation"."IdProfessionnelFk" IS 'Fiche professionnelle propriétaire ; le service contrôle ses droits avant toute modification.';

--
-- Name: COLUMN "T_Professionnel_Prestation"."IdPrestationFk"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."T_Professionnel_Prestation"."IdPrestationFk" IS 'Valeur ID_Generique de la famille de prestations configurée pour ce champ.';

--
-- Name: T_SynonymeRecherche; Type: TABLE; Schema: professionnel; Owner: -
--

CREATE TABLE professionnel."T_SynonymeRecherche" (
    "ID_SynonymeRecherche" bigint NOT NULL,
    "IdGeneriqueFk" integer NOT NULL,
    "Terme" text NOT NULL,
    "Actif" boolean DEFAULT true NOT NULL,
    "IdEntiteFk" integer,
    CONSTRAINT "T_SynonymeRecherche_Terme_check" CHECK (((length(btrim("Terme")) >= 1) AND (length(btrim("Terme")) <= 200)))
);

--
-- Name: TABLE "T_SynonymeRecherche"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON TABLE professionnel."T_SynonymeRecherche" IS 'Détails lexicaux rattachés à une valeur existante de T_Generique, pour retrouver un besoin par un mot courant. Ne relie jamais arbitrairement une personne à une compétence.';

--
-- Name: COLUMN "T_SynonymeRecherche"."ID_SynonymeRecherche"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."T_SynonymeRecherche"."ID_SynonymeRecherche" IS 'Identifiant technique du terme de recherche.';

--
-- Name: COLUMN "T_SynonymeRecherche"."IdGeneriqueFk"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."T_SynonymeRecherche"."IdGeneriqueFk" IS 'Valeur centrale visée par le synonyme ; le terme ne crée pas une nouvelle compétence.';

--
-- Name: COLUMN "T_SynonymeRecherche"."Terme"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."T_SynonymeRecherche"."Terme" IS 'Expression de recherche explicite, sans interprétation médicale ni promesse de service.';

--
-- Name: COLUMN "T_SynonymeRecherche"."Actif"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."T_SynonymeRecherche"."Actif" IS 'Terme utilisé dans la projection de recherche s’il est actif et sa référence reste valide.';

--
-- Name: COLUMN "T_SynonymeRecherche"."IdEntiteFk"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON COLUMN professionnel."T_SynonymeRecherche"."IdEntiteFk" IS 'Portée identique à la référence centrale : NULL commune, sinon entreprise propriétaire de la valeur.';

--
-- Name: T_SynonymeRecherche_ID_SynonymeRecherche_seq; Type: SEQUENCE; Schema: professionnel; Owner: -
--

ALTER TABLE professionnel."T_SynonymeRecherche" ALTER COLUMN "ID_SynonymeRecherche" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME professionnel."T_SynonymeRecherche_ID_SynonymeRecherche_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

--
-- Name: T_Professionnel Pk_IdProfessionnel; Type: CONSTRAINT; Schema: professionnel; Owner: -
--

ALTER TABLE ONLY professionnel."T_Professionnel"
    ADD CONSTRAINT "Pk_IdProfessionnel" PRIMARY KEY ("IdProfessionnel");

--
-- Name: CONSTRAINT "Pk_IdProfessionnel" ON "T_Professionnel"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON CONSTRAINT "Pk_IdProfessionnel" ON professionnel."T_Professionnel" IS 'Clé primaire : identifie de manière unique chaque ligne dans "professionnel"."T_Professionnel". Définition : PRIMARY KEY ("IdProfessionnel").';

--
-- Name: T_Professionnel_Entite Pk_Professionnel_Entite; Type: CONSTRAINT; Schema: professionnel; Owner: -
--

ALTER TABLE ONLY professionnel."T_Professionnel_Entite"
    ADD CONSTRAINT "Pk_Professionnel_Entite" PRIMARY KEY ("IdProfessionnelFk", "IdEntiteFk");

--
-- Name: CONSTRAINT "Pk_Professionnel_Entite" ON "T_Professionnel_Entite"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON CONSTRAINT "Pk_Professionnel_Entite" ON professionnel."T_Professionnel_Entite" IS 'Clé primaire : identifie de manière unique chaque ligne dans "professionnel"."T_Professionnel_Entite". Définition : PRIMARY KEY ("IdProfessionnelFk", "IdEntiteFk").';

--
-- Name: T_Professionnel_Competence T_Professionnel_Competence_pkey; Type: CONSTRAINT; Schema: professionnel; Owner: -
--

ALTER TABLE ONLY professionnel."T_Professionnel_Competence"
    ADD CONSTRAINT "T_Professionnel_Competence_pkey" PRIMARY KEY ("IdProfessionnelFk", "IdCompetenceFk");

--
-- Name: T_Professionnel T_Professionnel_CreationRequestId_key; Type: CONSTRAINT; Schema: professionnel; Owner: -
--

ALTER TABLE ONLY professionnel."T_Professionnel"
    ADD CONSTRAINT "T_Professionnel_CreationRequestId_key" UNIQUE ("CreationRequestId");

--
-- Name: T_Professionnel_Prestation T_Professionnel_Prestation_pkey; Type: CONSTRAINT; Schema: professionnel; Owner: -
--

ALTER TABLE ONLY professionnel."T_Professionnel_Prestation"
    ADD CONSTRAINT "T_Professionnel_Prestation_pkey" PRIMARY KEY ("IdProfessionnelFk", "IdPrestationFk");

--
-- Name: T_SynonymeRecherche T_SynonymeRecherche_pkey; Type: CONSTRAINT; Schema: professionnel; Owner: -
--

ALTER TABLE ONLY professionnel."T_SynonymeRecherche"
    ADD CONSTRAINT "T_SynonymeRecherche_pkey" PRIMARY KEY ("ID_SynonymeRecherche");

--
-- Name: T_Professionnel Uq_Prof_IdUser; Type: CONSTRAINT; Schema: professionnel; Owner: -
--

ALTER TABLE ONLY professionnel."T_Professionnel"
    ADD CONSTRAINT "Uq_Prof_IdUser" UNIQUE ("IdUserFk");

--
-- Name: CONSTRAINT "Uq_Prof_IdUser" ON "T_Professionnel"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON CONSTRAINT "Uq_Prof_IdUser" ON professionnel."T_Professionnel" IS 'Unicité : empêche les doublons sur la combinaison indiquée dans "professionnel"."T_Professionnel". Définition : UNIQUE ("IdUserFk").';

--
-- Name: T_Professionnel Uq_Prof_NumeroIdentification; Type: CONSTRAINT; Schema: professionnel; Owner: -
--

ALTER TABLE ONLY professionnel."T_Professionnel"
    ADD CONSTRAINT "Uq_Prof_NumeroIdentification" UNIQUE ("NumeroIdentification");

--
-- Name: CONSTRAINT "Uq_Prof_NumeroIdentification" ON "T_Professionnel"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON CONSTRAINT "Uq_Prof_NumeroIdentification" ON professionnel."T_Professionnel" IS 'Unicité : empêche les doublons sur la combinaison indiquée dans "professionnel"."T_Professionnel". Définition : UNIQUE ("NumeroIdentification").';

--
-- Name: INDEX "Pk_IdProfessionnel"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON INDEX professionnel."Pk_IdProfessionnel" IS 'Index support de la clé primaire sur "professionnel"."T_Professionnel". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX "Pk_IdProfessionnel" ON professionnel."T_Professionnel" USING btree ("IdProfessionnel").';

--
-- Name: INDEX "Pk_Professionnel_Entite"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON INDEX professionnel."Pk_Professionnel_Entite" IS 'Index support de la clé primaire sur "professionnel"."T_Professionnel_Entite". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX "Pk_Professionnel_Entite" ON professionnel."T_Professionnel_Entite" USING btree ("IdProfessionnelFk", "IdEntiteFk").';

--
-- Name: Uq_ProfEnt_Principal_Par_Prof; Type: INDEX; Schema: professionnel; Owner: -
--

CREATE UNIQUE INDEX "Uq_ProfEnt_Principal_Par_Prof" ON professionnel."T_Professionnel_Entite" USING btree ("IdProfessionnelFk") WHERE ("EstPrincipal" IS TRUE);

--
-- Name: INDEX "Uq_ProfEnt_Principal_Par_Prof"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON INDEX professionnel."Uq_ProfEnt_Principal_Par_Prof" IS 'Index d’unicité sur "professionnel"."T_Professionnel_Entite". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX "Uq_ProfEnt_Principal_Par_Prof" ON professionnel."T_Professionnel_Entite" USING btree ("IdProfessionnelFk") WHERE ("EstPrincipal" IS TRUE).';

--
-- Name: INDEX "Uq_Prof_IdUser"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON INDEX professionnel."Uq_Prof_IdUser" IS 'Index d’unicité sur "professionnel"."T_Professionnel". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX "Uq_Prof_IdUser" ON professionnel."T_Professionnel" USING btree ("IdUserFk").';

--
-- Name: INDEX "Uq_Prof_NumeroIdentification"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON INDEX professionnel."Uq_Prof_NumeroIdentification" IS 'Index d’unicité sur "professionnel"."T_Professionnel". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX "Uq_Prof_NumeroIdentification" ON professionnel."T_Professionnel" USING btree ("NumeroIdentification").';

--
-- Name: idx_prof_specialite; Type: INDEX; Schema: professionnel; Owner: -
--

CREATE INDEX idx_prof_specialite ON professionnel."T_Professionnel" USING btree ("IdSpecialiteFk");

--
-- Name: INDEX idx_prof_specialite; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON INDEX professionnel.idx_prof_specialite IS 'Index d’accès sur "professionnel"."T_Professionnel". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_prof_specialite ON professionnel."T_Professionnel" USING btree ("IdSpecialiteFk").';

--
-- Name: idx_prof_type; Type: INDEX; Schema: professionnel; Owner: -
--

CREATE INDEX idx_prof_type ON professionnel."T_Professionnel" USING btree ("IdTypeProfessionnelFk");

--
-- Name: INDEX idx_prof_type; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON INDEX professionnel.idx_prof_type IS 'Index d’accès sur "professionnel"."T_Professionnel". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_prof_type ON professionnel."T_Professionnel" USING btree ("IdTypeProfessionnelFk").';

--
-- Name: idx_profent_datedebut; Type: INDEX; Schema: professionnel; Owner: -
--

CREATE INDEX idx_profent_datedebut ON professionnel."T_Professionnel_Entite" USING btree ("DateDebut");

--
-- Name: INDEX idx_profent_datedebut; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON INDEX professionnel.idx_profent_datedebut IS 'Index d’accès sur "professionnel"."T_Professionnel_Entite". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_profent_datedebut ON professionnel."T_Professionnel_Entite" USING btree ("DateDebut").';

--
-- Name: idx_profent_entite; Type: INDEX; Schema: professionnel; Owner: -
--

CREATE INDEX idx_profent_entite ON professionnel."T_Professionnel_Entite" USING btree ("IdEntiteFk");

--
-- Name: INDEX idx_profent_entite; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON INDEX professionnel.idx_profent_entite IS 'Index d’accès sur "professionnel"."T_Professionnel_Entite". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_profent_entite ON professionnel."T_Professionnel_Entite" USING btree ("IdEntiteFk").';

--
-- Name: idx_profession_principal; Type: INDEX; Schema: professionnel; Owner: -
--

CREATE INDEX idx_profession_principal ON professionnel."T_Professionnel_Entite" USING btree ("IdEntiteFk") WHERE ("EstPrincipal" = true);

--
-- Name: INDEX idx_profession_principal; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON INDEX professionnel.idx_profession_principal IS 'Index d’accès sur "professionnel"."T_Professionnel_Entite". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_profession_principal ON professionnel."T_Professionnel_Entite" USING btree ("IdEntiteFk") WHERE ("EstPrincipal" = true).';

--
-- Name: ix_competence_reference; Type: INDEX; Schema: professionnel; Owner: -
--

CREATE INDEX ix_competence_reference ON professionnel."T_Professionnel_Competence" USING btree ("IdCompetenceFk", "IdProfessionnelFk");

--
-- Name: INDEX ix_competence_reference; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON INDEX professionnel.ix_competence_reference IS 'Recherche des fiches par compétence centrale sans dupliquer les profils.';

--
-- Name: ix_prestation_reference; Type: INDEX; Schema: professionnel; Owner: -
--

CREATE INDEX ix_prestation_reference ON professionnel."T_Professionnel_Prestation" USING btree ("IdPrestationFk", "IdProfessionnelFk");

--
-- Name: INDEX ix_prestation_reference; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON INDEX professionnel.ix_prestation_reference IS 'Recherche des fiches par prestation centrale sans double comptage.';

--
-- Name: ix_prof_owner; Type: INDEX; Schema: professionnel; Owner: -
--

CREATE INDEX ix_prof_owner ON professionnel."T_Professionnel" USING btree ("IdEntiteFk", "IdProfessionnel");

--
-- Name: INDEX ix_prof_owner; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON INDEX professionnel.ix_prof_owner IS 'Registre autorisé et pagination par entreprise propriétaire.';

--
-- Name: ix_prof_secteur; Type: INDEX; Schema: professionnel; Owner: -
--

CREATE INDEX ix_prof_secteur ON professionnel."T_Professionnel" USING btree ("IdSecteurFk") WHERE ("Publie" AND "ValideProfessionnel");

--
-- Name: INDEX ix_prof_secteur; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON INDEX professionnel.ix_prof_secteur IS 'Filtre des fiches publiées et actives par secteur.';

--
-- Name: uq_synonyme_reference_terme; Type: INDEX; Schema: professionnel; Owner: -
--

CREATE UNIQUE INDEX uq_synonyme_reference_terme ON professionnel."T_SynonymeRecherche" USING btree ("IdGeneriqueFk", referentiel.fn_normaliser_libelle("Terme"));

--
-- Name: INDEX uq_synonyme_reference_terme; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON INDEX professionnel.uq_synonyme_reference_terme IS 'Interdit un même terme normalisé plusieurs fois pour la même référence.';

--
-- Name: T_Professionnel aa_reference_champ; Type: TRIGGER; Schema: professionnel; Owner: -
--

CREATE TRIGGER aa_reference_champ BEFORE INSERT OR UPDATE ON professionnel."T_Professionnel" FOR EACH ROW EXECUTE FUNCTION referentiel.tr_valider_champ_referentiel();

--
-- Name: TRIGGER aa_reference_champ ON "T_Professionnel"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON TRIGGER aa_reference_champ ON professionnel."T_Professionnel" IS 'Valide les nouvelles références du catalogue physique ; conserve les valeurs historiques inchangées, même devenues hors famille.';

--
-- Name: T_Professionnel_Competence aa_reference_champ; Type: TRIGGER; Schema: professionnel; Owner: -
--

CREATE TRIGGER aa_reference_champ BEFORE INSERT OR UPDATE ON professionnel."T_Professionnel_Competence" FOR EACH ROW EXECUTE FUNCTION referentiel.tr_valider_champ_referentiel();

--
-- Name: TRIGGER aa_reference_champ ON "T_Professionnel_Competence"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON TRIGGER aa_reference_champ ON professionnel."T_Professionnel_Competence" IS 'Valide les nouvelles références depuis le catalogue central dans le contexte propriétaire du profil.';

--
-- Name: T_Professionnel_Entite aa_reference_champ; Type: TRIGGER; Schema: professionnel; Owner: -
--

CREATE TRIGGER aa_reference_champ BEFORE INSERT OR UPDATE ON professionnel."T_Professionnel_Entite" FOR EACH ROW EXECUTE FUNCTION referentiel.tr_valider_champ_referentiel();

--
-- Name: TRIGGER aa_reference_champ ON "T_Professionnel_Entite"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON TRIGGER aa_reference_champ ON professionnel."T_Professionnel_Entite" IS 'Valide les nouvelles références du catalogue physique ; conserve les valeurs historiques inchangées, même devenues hors famille.';

--
-- Name: T_Professionnel_Prestation aa_reference_champ; Type: TRIGGER; Schema: professionnel; Owner: -
--

CREATE TRIGGER aa_reference_champ BEFORE INSERT OR UPDATE ON professionnel."T_Professionnel_Prestation" FOR EACH ROW EXECUTE FUNCTION referentiel.tr_valider_champ_referentiel();

--
-- Name: TRIGGER aa_reference_champ ON "T_Professionnel_Prestation"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON TRIGGER aa_reference_champ ON professionnel."T_Professionnel_Prestation" IS 'Valide les nouvelles références depuis le catalogue central dans le contexte propriétaire du profil.';

--
-- Name: T_Professionnel_Competence ab_detail_professionnel_integrite; Type: TRIGGER; Schema: professionnel; Owner: -
--

CREATE TRIGGER ab_detail_professionnel_integrite BEFORE INSERT OR DELETE OR UPDATE ON professionnel."T_Professionnel_Competence" FOR EACH ROW EXECUTE FUNCTION professionnel.tr_detail_professionnel_integrite();

--
-- Name: TRIGGER ab_detail_professionnel_integrite ON "T_Professionnel_Competence"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON TRIGGER ab_detail_professionnel_integrite ON professionnel."T_Professionnel_Competence" IS 'Verrou parent, intégrité des liens et des affiliations principales sans double comptage.';

--
-- Name: T_Professionnel_Entite ab_detail_professionnel_integrite; Type: TRIGGER; Schema: professionnel; Owner: -
--

CREATE TRIGGER ab_detail_professionnel_integrite BEFORE INSERT OR DELETE OR UPDATE ON professionnel."T_Professionnel_Entite" FOR EACH ROW EXECUTE FUNCTION professionnel.tr_detail_professionnel_integrite();

--
-- Name: TRIGGER ab_detail_professionnel_integrite ON "T_Professionnel_Entite"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON TRIGGER ab_detail_professionnel_integrite ON professionnel."T_Professionnel_Entite" IS 'Verrou parent, intégrité des liens et des affiliations principales sans double comptage.';

--
-- Name: T_Professionnel_Prestation ab_detail_professionnel_integrite; Type: TRIGGER; Schema: professionnel; Owner: -
--

CREATE TRIGGER ab_detail_professionnel_integrite BEFORE INSERT OR DELETE OR UPDATE ON professionnel."T_Professionnel_Prestation" FOR EACH ROW EXECUTE FUNCTION professionnel.tr_detail_professionnel_integrite();

--
-- Name: TRIGGER ab_detail_professionnel_integrite ON "T_Professionnel_Prestation"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON TRIGGER ab_detail_professionnel_integrite ON professionnel."T_Professionnel_Prestation" IS 'Verrou parent, intégrité des liens et des affiliations principales sans double comptage.';

--
-- Name: T_Professionnel ab_professionnel_integrite; Type: TRIGGER; Schema: professionnel; Owner: -
--

CREATE TRIGGER ab_professionnel_integrite BEFORE INSERT OR DELETE OR UPDATE ON professionnel."T_Professionnel" FOR EACH ROW EXECUTE FUNCTION professionnel.tr_professionnel_integrite();

--
-- Name: TRIGGER ab_professionnel_integrite ON "T_Professionnel"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON TRIGGER ab_professionnel_integrite ON professionnel."T_Professionnel" IS 'Garde commune du registre et des écritures SQL ; la suppression physique est remplacée par l’archivage.';

--
-- Name: T_SynonymeRecherche ab_synonyme_portee; Type: TRIGGER; Schema: professionnel; Owner: -
--

CREATE TRIGGER ab_synonyme_portee BEFORE INSERT OR UPDATE ON professionnel."T_SynonymeRecherche" FOR EACH ROW EXECUTE FUNCTION professionnel.tr_synonyme_portee();

--
-- Name: TRIGGER ab_synonyme_portee ON "T_SynonymeRecherche"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON TRIGGER ab_synonyme_portee ON professionnel."T_SynonymeRecherche" IS 'Garde la cohérence de portée du dictionnaire lexical.';

--
-- Name: T_Professionnel_Competence zy_detail_professionnel_revision; Type: TRIGGER; Schema: professionnel; Owner: -
--

CREATE TRIGGER zy_detail_professionnel_revision AFTER INSERT OR DELETE OR UPDATE ON professionnel."T_Professionnel_Competence" FOR EACH ROW EXECUTE FUNCTION professionnel.tr_detail_professionnel_revision();

--
-- Name: TRIGGER zy_detail_professionnel_revision ON "T_Professionnel_Competence"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON TRIGGER zy_detail_professionnel_revision ON professionnel."T_Professionnel_Competence" IS 'Révision atomique du parent après une mutation réelle de ce détail, avant son audit ; aucune version nouvelle sur un simple UPDATE identique.';

--
-- Name: T_Professionnel_Entite zy_detail_professionnel_revision; Type: TRIGGER; Schema: professionnel; Owner: -
--

CREATE TRIGGER zy_detail_professionnel_revision AFTER INSERT OR DELETE OR UPDATE ON professionnel."T_Professionnel_Entite" FOR EACH ROW EXECUTE FUNCTION professionnel.tr_detail_professionnel_revision();

--
-- Name: TRIGGER zy_detail_professionnel_revision ON "T_Professionnel_Entite"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON TRIGGER zy_detail_professionnel_revision ON professionnel."T_Professionnel_Entite" IS 'Révision atomique du parent après une mutation réelle de ce détail, avant son audit ; aucune version nouvelle sur un simple UPDATE identique.';

--
-- Name: T_Professionnel_Prestation zy_detail_professionnel_revision; Type: TRIGGER; Schema: professionnel; Owner: -
--

CREATE TRIGGER zy_detail_professionnel_revision AFTER INSERT OR DELETE OR UPDATE ON professionnel."T_Professionnel_Prestation" FOR EACH ROW EXECUTE FUNCTION professionnel.tr_detail_professionnel_revision();

--
-- Name: TRIGGER zy_detail_professionnel_revision ON "T_Professionnel_Prestation"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON TRIGGER zy_detail_professionnel_revision ON professionnel."T_Professionnel_Prestation" IS 'Révision atomique du parent après une mutation réelle de ce détail, avant son audit ; aucune version nouvelle sur un simple UPDATE identique.';

--
-- Name: T_Professionnel zz_professionnel_audit; Type: TRIGGER; Schema: professionnel; Owner: -
--

CREATE TRIGGER zz_professionnel_audit AFTER INSERT OR DELETE OR UPDATE ON professionnel."T_Professionnel" FOR EACH ROW EXECUTE FUNCTION professionnel.tr_professionnel_audit();

--
-- Name: TRIGGER zz_professionnel_audit ON "T_Professionnel"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON TRIGGER zz_professionnel_audit ON professionnel."T_Professionnel" IS 'Trace SQL transactionnelle sans secret ; parent et entreprise restent identifiables après modification.';

--
-- Name: T_Professionnel_Competence zz_professionnel_audit; Type: TRIGGER; Schema: professionnel; Owner: -
--

CREATE TRIGGER zz_professionnel_audit AFTER INSERT OR DELETE OR UPDATE ON professionnel."T_Professionnel_Competence" FOR EACH ROW EXECUTE FUNCTION professionnel.tr_professionnel_audit();

--
-- Name: TRIGGER zz_professionnel_audit ON "T_Professionnel_Competence"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON TRIGGER zz_professionnel_audit ON professionnel."T_Professionnel_Competence" IS 'Trace SQL transactionnelle sans secret ; parent et entreprise restent identifiables après modification.';

--
-- Name: T_Professionnel_Entite zz_professionnel_audit; Type: TRIGGER; Schema: professionnel; Owner: -
--

CREATE TRIGGER zz_professionnel_audit AFTER INSERT OR DELETE OR UPDATE ON professionnel."T_Professionnel_Entite" FOR EACH ROW EXECUTE FUNCTION professionnel.tr_professionnel_audit();

--
-- Name: TRIGGER zz_professionnel_audit ON "T_Professionnel_Entite"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON TRIGGER zz_professionnel_audit ON professionnel."T_Professionnel_Entite" IS 'Trace SQL transactionnelle sans secret ; parent et entreprise restent identifiables après modification.';

--
-- Name: T_Professionnel_Prestation zz_professionnel_audit; Type: TRIGGER; Schema: professionnel; Owner: -
--

CREATE TRIGGER zz_professionnel_audit AFTER INSERT OR DELETE OR UPDATE ON professionnel."T_Professionnel_Prestation" FOR EACH ROW EXECUTE FUNCTION professionnel.tr_professionnel_audit();

--
-- Name: TRIGGER zz_professionnel_audit ON "T_Professionnel_Prestation"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON TRIGGER zz_professionnel_audit ON professionnel."T_Professionnel_Prestation" IS 'Trace SQL transactionnelle sans secret ; parent et entreprise restent identifiables après modification.';

--
-- Name: T_SynonymeRecherche zz_professionnel_audit; Type: TRIGGER; Schema: professionnel; Owner: -
--

CREATE TRIGGER zz_professionnel_audit AFTER INSERT OR DELETE OR UPDATE ON professionnel."T_SynonymeRecherche" FOR EACH ROW EXECUTE FUNCTION professionnel.tr_professionnel_audit();

--
-- Name: TRIGGER zz_professionnel_audit ON "T_SynonymeRecherche"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON TRIGGER zz_professionnel_audit ON professionnel."T_SynonymeRecherche" IS 'Trace SQL transactionnelle sans secret ; parent et entreprise restent identifiables après modification.';

--
-- Name: T_Professionnel_Entite Fk_ProfEnt_Entite; Type: FK CONSTRAINT; Schema: professionnel; Owner: -
--

ALTER TABLE ONLY professionnel."T_Professionnel_Entite"
    ADD CONSTRAINT "Fk_ProfEnt_Entite" FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON UPDATE CASCADE ON DELETE RESTRICT;

--
-- Name: CONSTRAINT "Fk_ProfEnt_Entite" ON "T_Professionnel_Entite"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON CONSTRAINT "Fk_ProfEnt_Entite" ON professionnel."T_Professionnel_Entite" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "professionnel"."T_Professionnel_Entite". Définition : FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON UPDATE CASCADE ON DELETE RESTRICT.';

--
-- Name: T_Professionnel_Entite Fk_ProfEnt_Prof; Type: FK CONSTRAINT; Schema: professionnel; Owner: -
--

ALTER TABLE ONLY professionnel."T_Professionnel_Entite"
    ADD CONSTRAINT "Fk_ProfEnt_Prof" FOREIGN KEY ("IdProfessionnelFk") REFERENCES professionnel."T_Professionnel"("IdProfessionnel") ON UPDATE CASCADE ON DELETE CASCADE;

--
-- Name: CONSTRAINT "Fk_ProfEnt_Prof" ON "T_Professionnel_Entite"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON CONSTRAINT "Fk_ProfEnt_Prof" ON professionnel."T_Professionnel_Entite" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "professionnel"."T_Professionnel_Entite". Définition : FOREIGN KEY ("IdProfessionnelFk") REFERENCES professionnel."T_Professionnel"("IdProfessionnel") ON UPDATE CASCADE ON DELETE CASCADE.';

--
-- Name: T_Professionnel_Entite Fk_ProfEnt_TypeLien; Type: FK CONSTRAINT; Schema: professionnel; Owner: -
--

ALTER TABLE ONLY professionnel."T_Professionnel_Entite"
    ADD CONSTRAINT "Fk_ProfEnt_TypeLien" FOREIGN KEY ("IdTypeLienFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE ON DELETE RESTRICT;

--
-- Name: CONSTRAINT "Fk_ProfEnt_TypeLien" ON "T_Professionnel_Entite"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON CONSTRAINT "Fk_ProfEnt_TypeLien" ON professionnel."T_Professionnel_Entite" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "professionnel"."T_Professionnel_Entite". Définition : FOREIGN KEY ("IdTypeLienFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE ON DELETE RESTRICT.';

--
-- Name: T_Professionnel Fk_Prof_Specialite; Type: FK CONSTRAINT; Schema: professionnel; Owner: -
--

ALTER TABLE ONLY professionnel."T_Professionnel"
    ADD CONSTRAINT "Fk_Prof_Specialite" FOREIGN KEY ("IdSpecialiteFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE ON DELETE RESTRICT;

--
-- Name: CONSTRAINT "Fk_Prof_Specialite" ON "T_Professionnel"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON CONSTRAINT "Fk_Prof_Specialite" ON professionnel."T_Professionnel" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "professionnel"."T_Professionnel". Définition : FOREIGN KEY ("IdSpecialiteFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE ON DELETE RESTRICT.';

--
-- Name: T_Professionnel Fk_Prof_TypeProfessionnel; Type: FK CONSTRAINT; Schema: professionnel; Owner: -
--

ALTER TABLE ONLY professionnel."T_Professionnel"
    ADD CONSTRAINT "Fk_Prof_TypeProfessionnel" FOREIGN KEY ("IdTypeProfessionnelFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE ON DELETE RESTRICT;

--
-- Name: CONSTRAINT "Fk_Prof_TypeProfessionnel" ON "T_Professionnel"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON CONSTRAINT "Fk_Prof_TypeProfessionnel" ON professionnel."T_Professionnel" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "professionnel"."T_Professionnel". Définition : FOREIGN KEY ("IdTypeProfessionnelFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE ON DELETE RESTRICT.';

--
-- Name: T_Professionnel Fk_Prof_User; Type: FK CONSTRAINT; Schema: professionnel; Owner: -
--

ALTER TABLE ONLY professionnel."T_Professionnel"
    ADD CONSTRAINT "Fk_Prof_User" FOREIGN KEY ("IdUserFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE ON DELETE RESTRICT;

--
-- Name: CONSTRAINT "Fk_Prof_User" ON "T_Professionnel"; Type: COMMENT; Schema: professionnel; Owner: -
--

COMMENT ON CONSTRAINT "Fk_Prof_User" ON professionnel."T_Professionnel" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "professionnel"."T_Professionnel". Définition : FOREIGN KEY ("IdUserFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE ON DELETE RESTRICT.';

--
-- Name: T_Professionnel_Competence T_Professionnel_Competence_IdCompetenceFk_fkey; Type: FK CONSTRAINT; Schema: professionnel; Owner: -
--

ALTER TABLE ONLY professionnel."T_Professionnel_Competence"
    ADD CONSTRAINT "T_Professionnel_Competence_IdCompetenceFk_fkey" FOREIGN KEY ("IdCompetenceFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON DELETE RESTRICT;

--
-- Name: T_Professionnel_Competence T_Professionnel_Competence_IdProfessionnelFk_fkey; Type: FK CONSTRAINT; Schema: professionnel; Owner: -
--

ALTER TABLE ONLY professionnel."T_Professionnel_Competence"
    ADD CONSTRAINT "T_Professionnel_Competence_IdProfessionnelFk_fkey" FOREIGN KEY ("IdProfessionnelFk") REFERENCES professionnel."T_Professionnel"("IdProfessionnel") ON DELETE RESTRICT;

--
-- Name: T_Professionnel T_Professionnel_CreeParUserFk_fkey; Type: FK CONSTRAINT; Schema: professionnel; Owner: -
--

ALTER TABLE ONLY professionnel."T_Professionnel"
    ADD CONSTRAINT "T_Professionnel_CreeParUserFk_fkey" FOREIGN KEY ("CreeParUserFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON DELETE RESTRICT;

--
-- Name: T_Professionnel T_Professionnel_IdEntiteFk_fkey; Type: FK CONSTRAINT; Schema: professionnel; Owner: -
--

ALTER TABLE ONLY professionnel."T_Professionnel"
    ADD CONSTRAINT "T_Professionnel_IdEntiteFk_fkey" FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON DELETE RESTRICT;

--
-- Name: T_Professionnel T_Professionnel_IdSecteurFk_fkey; Type: FK CONSTRAINT; Schema: professionnel; Owner: -
--

ALTER TABLE ONLY professionnel."T_Professionnel"
    ADD CONSTRAINT "T_Professionnel_IdSecteurFk_fkey" FOREIGN KEY ("IdSecteurFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON DELETE RESTRICT;

--
-- Name: T_Professionnel T_Professionnel_ModifieParUserFk_fkey; Type: FK CONSTRAINT; Schema: professionnel; Owner: -
--

ALTER TABLE ONLY professionnel."T_Professionnel"
    ADD CONSTRAINT "T_Professionnel_ModifieParUserFk_fkey" FOREIGN KEY ("ModifieParUserFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON DELETE RESTRICT;

--
-- Name: T_Professionnel_Prestation T_Professionnel_Prestation_IdPrestationFk_fkey; Type: FK CONSTRAINT; Schema: professionnel; Owner: -
--

ALTER TABLE ONLY professionnel."T_Professionnel_Prestation"
    ADD CONSTRAINT "T_Professionnel_Prestation_IdPrestationFk_fkey" FOREIGN KEY ("IdPrestationFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON DELETE RESTRICT;

--
-- Name: T_Professionnel_Prestation T_Professionnel_Prestation_IdProfessionnelFk_fkey; Type: FK CONSTRAINT; Schema: professionnel; Owner: -
--

ALTER TABLE ONLY professionnel."T_Professionnel_Prestation"
    ADD CONSTRAINT "T_Professionnel_Prestation_IdProfessionnelFk_fkey" FOREIGN KEY ("IdProfessionnelFk") REFERENCES professionnel."T_Professionnel"("IdProfessionnel") ON DELETE RESTRICT;

--
-- Name: T_SynonymeRecherche T_SynonymeRecherche_IdEntiteFk_fkey; Type: FK CONSTRAINT; Schema: professionnel; Owner: -
--

ALTER TABLE ONLY professionnel."T_SynonymeRecherche"
    ADD CONSTRAINT "T_SynonymeRecherche_IdEntiteFk_fkey" FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON DELETE RESTRICT;

--
-- Name: T_SynonymeRecherche T_SynonymeRecherche_IdGeneriqueFk_fkey; Type: FK CONSTRAINT; Schema: professionnel; Owner: -
--

ALTER TABLE ONLY professionnel."T_SynonymeRecherche"
    ADD CONSTRAINT "T_SynonymeRecherche_IdGeneriqueFk_fkey" FOREIGN KEY ("IdGeneriqueFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON DELETE RESTRICT;
