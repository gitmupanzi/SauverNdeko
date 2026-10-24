-- Extrait canonique du catalogue installé le 24/10/2026, sans données ni propriétaires imposés.
-- Voir SQL/README.md. Ces extraits documentent le domaine ; utiliser le fichier global pour une installation vide.
SET check_function_bodies = false;
SELECT pg_catalog.set_config('search_path', '', false);
CREATE SCHEMA IF NOT EXISTS "systeme";
--
-- Name: audit_log_function(); Type: FUNCTION; Schema: systeme; Owner: -
--

CREATE FUNCTION systeme.audit_log_function() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE before_row jsonb; after_row jsonb; entity_id integer;
BEGIN
 IF TG_OP IN ('DELETE','UPDATE') THEN before_row:=systeme.fn_audit_sans_secrets(to_jsonb(OLD)); END IF;
 IF TG_OP IN ('INSERT','UPDATE') THEN after_row:=systeme.fn_audit_sans_secrets(to_jsonb(NEW)); END IF;
 entity_id:=coalesce((after_row->>'IdEntiteFk')::integer,(before_row->>'IdEntiteFk')::integer);
 INSERT INTO systeme."T_Audit_Log"("TableName","Operation","OldData","NewData","ChangedAt","IdEntiteFk")
 VALUES(TG_TABLE_NAME,TG_OP,before_row,after_row,current_timestamp,entity_id);
 RETURN NULL;
END;$$;


--
-- Name: FUNCTION audit_log_function(); Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON FUNCTION systeme.audit_log_function() IS 'Audit AFTER INSERT/UPDATE/DELETE transactionnel : lit le contexte par JSON sans supposer une colonne IdEntiteFk, ne recopie ni mots de passe ni jetons et accepte une entité absente.';


--
-- Name: fn_admin_ui_setting_set_updated_at(); Type: FUNCTION; Schema: systeme; Owner: -
--

CREATE FUNCTION systeme.fn_admin_ui_setting_set_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW."UpdatedAt" = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;


--
-- Name: FUNCTION fn_admin_ui_setting_set_updated_at(); Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON FUNCTION systeme.fn_admin_ui_setting_set_updated_at() IS 'Avant UPDATE d’un paramètre d’interface, remplace UpdatedAt par CURRENT_TIMESTAMP et renvoie NEW.';


--
-- Name: fn_audit_sans_secrets(jsonb); Type: FUNCTION; Schema: systeme; Owner: -
--

CREATE FUNCTION systeme.fn_audit_sans_secrets(p_data jsonb) RETURNS jsonb
    LANGUAGE sql IMMUTABLE PARALLEL SAFE
    AS $$
 SELECT p_data - ARRAY['MotdepasseUser','password','Password','MotDePasse','accessToken','refreshToken'];
$$;


--
-- Name: FUNCTION fn_audit_sans_secrets(p_data jsonb); Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON FUNCTION systeme.fn_audit_sans_secrets(p_data jsonb) IS 'Retire les champs de mot de passe et jetons d’une image de ligne JSON d’audit ; conserve NULL et les autres données de traçabilité.';


--
-- Name: format_phone_number(); Type: FUNCTION; Schema: systeme; Owner: -
--

CREATE FUNCTION systeme.format_phone_number() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW."PhoneUser" := regexp_replace(NEW."PhoneUser", '[^0-9]', '', 'g');
    RETURN NEW;
END;
$$;


--
-- Name: FUNCTION format_phone_number(); Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON FUNCTION systeme.format_phone_number() IS 'Avant INSERT/UPDATE d’un utilisateur, retire de PhoneUser tous les caractères autres que les chiffres. Ne normalise pas le préfixe international ni la validité téléphonique.';


--
-- Name: notify_licence_expiry(); Type: FUNCTION; Schema: systeme; Owner: -
--

CREATE FUNCTION systeme.notify_licence_expiry() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE recipient integer; notification_type integer;
BEGIN
 IF NEW."ValideLicence" IS NOT TRUE OR NEW."DateFin"::date-current_date<>7 THEN RETURN NEW; END IF;
 IF TG_OP='UPDATE' AND NEW."DateFin" IS NOT DISTINCT FROM OLD."DateFin" AND NEW."ValideLicence" IS NOT DISTINCT FROM OLD."ValideLicence" THEN RETURN NEW; END IF;
 SELECT u."IdUser" INTO recipient FROM systeme."T_Utilisateurs" u LEFT JOIN referentiel."T_Generique" r ON r."ID_Generique"=u."IdRoleFk"
 WHERE u."IdEntiteFk"=NEW."IdEntiteFk" AND u."ValideUser" IS TRUE
 AND (u."Is_Admin" OR u."Is_staff" OR r."NomGenerique"='Admin Entité')
 ORDER BY u."Is_Admin" DESC,u."Is_staff" DESC,u."IdUser" LIMIT 1;
 SELECT "ID_Generique" INTO notification_type FROM referentiel."T_Generique" WHERE "NomGenerique"='Notification' AND "ValideGenerique" IS TRUE ORDER BY "ID_Generique" LIMIT 1;
 IF recipient IS NOT NULL AND notification_type IS NOT NULL THEN
  INSERT INTO communication."T_Communication"("IdUserFk","IdTypeCommunication","ContenuCommunication","DateCommunication","ValideCommunication","LectureCommunication","IdEntiteFk")
  VALUES(recipient,notification_type,'Votre licence expirera dans 7 jours. Veuillez la renouveler.',current_timestamp,true,false,NEW."IdEntiteFk");
 END IF;
 RETURN NEW;
END;$$;


--
-- Name: FUNCTION notify_licence_expiry(); Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON FUNCTION systeme.notify_licence_expiry() IS 'À l’écriture d’une licence valide arrivant à J+7 calendaires, notifie un gestionnaire actif de la même entité. Une modification sans changement de date ni activation ne répète pas la notification. Ce trigger ne constitue pas une tâche quotidienne planifiée.';


--
-- Name: prevent_multiple_active_licenses(); Type: FUNCTION; Schema: systeme; Owner: -
--

CREATE FUNCTION systeme.prevent_multiple_active_licenses() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
 -- Sérialise aussi les activations et changements d’entité ; pas seulement INSERT.
 PERFORM 1 FROM systeme."T_Entite" e
 WHERE e."IdEntite"=ANY(ARRAY[NEW."IdEntiteFk",CASE WHEN TG_OP='UPDATE' THEN OLD."IdEntiteFk" ELSE NULL END])
 ORDER BY e."IdEntite" FOR NO KEY UPDATE;
 IF NEW."ValideLicence" IS TRUE AND EXISTS(
  SELECT 1 FROM systeme."T_Licence" l WHERE l."IdEntiteFk"=NEW."IdEntiteFk"
  AND l."IdLicence" IS DISTINCT FROM NEW."IdLicence" AND l."ValideLicence" IS TRUE
  AND l."DateDebut"<NEW."DateFin" AND NEW."DateDebut"<l."DateFin"
 ) THEN RAISE EXCEPTION 'Deux licences valides ne peuvent pas couvrir la même période pour une entité.' USING ERRCODE='23514'; END IF;
 RETURN NEW;
END;$$;


--
-- Name: FUNCTION prevent_multiple_active_licenses(); Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON FUNCTION systeme.prevent_multiple_active_licenses() IS 'Verrouille les entités dans un ordre stable et refuse tout chevauchement de périodes de licences déclarées valides, à l’insertion et à la mise à jour, y compris concurrentes. Les renouvellements sans chevauchement et licences désactivées restent autorisés.';


--
-- Name: prevention_delete_if_dependent(); Type: FUNCTION; Schema: systeme; Owner: -
--

CREATE FUNCTION systeme.prevention_delete_if_dependent() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_has_dependencies boolean := false;
BEGIN
    ----------------------------------------------------------------------
    -- 1) Vérifier la table T_Evaluations (si elle existe dans la base)
    ----------------------------------------------------------------------
    IF to_regclass('"T_Evaluations"') IS NOT NULL THEN
        PERFORM 1
        FROM "T_Evaluations" e
        WHERE e."IdCibleFk" = OLD."IdUser"
        LIMIT 1;

        IF FOUND THEN
            v_has_dependencies := true;
        END IF;
    END IF;

    ----------------------------------------------------------------------
    -- 2) Vérifier la table operations."T_Paiement" (nouveau schéma)
    ----------------------------------------------------------------------
    IF NOT v_has_dependencies
       AND to_regclass('operations."T_Paiement"') IS NOT NULL THEN

        PERFORM 1
        FROM operations."T_Paiement" p
        WHERE p."IdUserFk" = OLD."IdUser"
        LIMIT 1;

        IF FOUND THEN
            v_has_dependencies := true;
        END IF;
    END IF;

    ----------------------------------------------------------------------
    -- 3) Vérifier la table T_Presence (si elle existe dans la base)
    ----------------------------------------------------------------------
    IF NOT v_has_dependencies
       AND to_regclass('"T_Presence"') IS NOT NULL THEN

        PERFORM 1
        FROM "T_Presence" pr
        WHERE pr."IdControleFk" = OLD."IdUser"
        LIMIT 1;

        IF FOUND THEN
            v_has_dependencies := true;
        END IF;
    END IF;

    ----------------------------------------------------------------------
    -- 4) Si une dépendance est trouvée → bloquer la suppression
    ----------------------------------------------------------------------
    IF v_has_dependencies THEN
        RAISE EXCEPTION
            'Suppression impossible : cet utilisateur a des dépendances dans le système (paiements, présences ou évaluations).';
    END IF;

    RETURN OLD;
END;
$$;


--
-- Name: FUNCTION prevention_delete_if_dependent(); Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON FUNCTION systeme.prevention_delete_if_dependent() IS 'Avant DELETE utilisateur, bloque la suppression si des paiements liés par IdUserFk ou des présences/évaluations liées existent dans les tables que la fonction trouve. Ne couvre pas à elle seule toutes les dépendances : les contraintes FK restent applicables.';


--
-- Name: update_date_modification(); Type: FUNCTION; Schema: systeme; Owner: -
--

CREATE FUNCTION systeme.update_date_modification() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW."DateModificationUser" := NOW();
    RETURN NEW;
END;
$$;


--
-- Name: FUNCTION update_date_modification(); Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON FUNCTION systeme.update_date_modification() IS 'Avant UPDATE utilisateur, remplace DateModificationUser par NOW() et renvoie NEW.';


--
-- Name: update_licence_status(); Type: FUNCTION; Schema: systeme; Owner: -
--

CREATE FUNCTION systeme.update_licence_status() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN NEW."ExpireeLicence":=NEW."DateFin"<=current_timestamp; RETURN NEW; END;$$;


--
-- Name: FUNCTION update_licence_status(); Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON FUNCTION systeme.update_licence_status() IS 'Calcule le drapeau d’expiration au moment de l’écriture. La vue calcule l’état courant à la lecture pour tenir compte du passage du temps.';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: T_Entite; Type: TABLE; Schema: systeme; Owner: -
--

CREATE TABLE systeme."T_Entite" (
    "IdEntite" integer CONSTRAINT "T_Entite_IdEntite_not_null" NOT NULL,
    "NomEntite" text CONSTRAINT "T_Entite_NomEntite_not_null" NOT NULL,
    "PhoneEntite" character varying(20),
    "EmailEntite" character varying(255) CONSTRAINT "T_Entite_EmailEntite_not_null" NOT NULL,
    "AdresseEntite" text,
    "DateCreationEntite" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "IdTypeEntiteFk" integer,
    "ValideEntite" boolean DEFAULT true
);


--
-- Name: TABLE "T_Entite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON TABLE systeme."T_Entite" IS 'Organisations et structures : identité, coordonnées, type, date de création et validité. Source des rattachements utilisateurs, professionnels, licences et opérations.';


--
-- Name: COLUMN "T_Entite"."IdEntite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Entite"."IdEntite" IS 'Identifiant de l’entité.';


--
-- Name: COLUMN "T_Entite"."NomEntite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Entite"."NomEntite" IS 'Nom de la structure ou organisation.';


--
-- Name: COLUMN "T_Entite"."PhoneEntite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Entite"."PhoneEntite" IS 'Téléphone de contact de l’entité.';


--
-- Name: COLUMN "T_Entite"."EmailEntite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Entite"."EmailEntite" IS 'Adresse électronique de contact de l’entité.';


--
-- Name: COLUMN "T_Entite"."AdresseEntite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Entite"."AdresseEntite" IS 'Adresse générale enregistrée pour l’entité.';


--
-- Name: COLUMN "T_Entite"."DateCreationEntite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Entite"."DateCreationEntite" IS 'Date et heure de création de l’entité.';


--
-- Name: COLUMN "T_Entite"."IdTypeEntiteFk"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Entite"."IdTypeEntiteFk" IS 'Type de structure ou d’organisation dans le référentiel. Relation imposée : FOREIGN KEY ("IdTypeEntiteFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE ON DELETE SET NULL.';


--
-- Name: COLUMN "T_Entite"."ValideEntite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Entite"."ValideEntite" IS 'Indique si l’entité est déclaré valide/actif dans le registre ; distinct des qualifications calculées dans les vues.';


--
-- Name: CONSTRAINT "T_Entite_IdEntite_not_null" ON "T_Entite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "T_Entite_IdEntite_not_null" ON systeme."T_Entite" IS 'Non-nullité : exige une valeur renseignée dans "systeme"."T_Entite". Définition : NOT NULL "IdEntite".';


--
-- Name: CONSTRAINT "T_Entite_NomEntite_not_null" ON "T_Entite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "T_Entite_NomEntite_not_null" ON systeme."T_Entite" IS 'Non-nullité : exige une valeur renseignée dans "systeme"."T_Entite". Définition : NOT NULL "NomEntite".';


--
-- Name: CONSTRAINT "T_Entite_EmailEntite_not_null" ON "T_Entite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "T_Entite_EmailEntite_not_null" ON systeme."T_Entite" IS 'Non-nullité : exige une valeur renseignée dans "systeme"."T_Entite". Définition : NOT NULL "EmailEntite".';


--
-- Name: T_Utilisateurs; Type: TABLE; Schema: systeme; Owner: -
--

CREATE TABLE systeme."T_Utilisateurs" (
    "IdUser" integer CONSTRAINT "T_Utilisateurs_IdUser_not_null" NOT NULL,
    "NomUser" character varying(100) CONSTRAINT "T_Utilisateurs_NomUser_not_null" NOT NULL,
    "PrenomUser" character varying(100) CONSTRAINT "T_Utilisateurs_PrenomUser_not_null" NOT NULL,
    "EmailUser" character varying(150) CONSTRAINT "T_Utilisateurs_EmailUser_not_null" NOT NULL,
    "MotdepasseUser" text CONSTRAINT "T_Utilisateurs_MotdepasseUser_not_null" NOT NULL,
    "PhoneUser" character varying(20),
    "DatecreationUser" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "IdRoleFk" integer,
    "ValideUser" boolean DEFAULT true CONSTRAINT "T_Utilisateurs_ValideUser_not_null" NOT NULL,
    "SexeUser" character(1) CONSTRAINT "T_Utilisateurs_SexeUser_not_null" NOT NULL,
    "DateModificationUser" timestamp without time zone DEFAULT CURRENT_TIMESTAMP CONSTRAINT "T_Utilisateurs_DateModificationUser_not_null" NOT NULL,
    "UrlPhoto" text,
    "IdEntiteFk" integer,
    "Is_staff" boolean DEFAULT false CONSTRAINT "T_Utilisateurs_Is_staff_not_null" NOT NULL,
    "Is_Admin" boolean DEFAULT false CONSTRAINT "T_Utilisateurs_Is_Admin_not_null" NOT NULL,
    CONSTRAINT chk_sexe_utilisateur CHECK (("SexeUser" = ANY (ARRAY['M'::bpchar, 'F'::bpchar])))
);


--
-- Name: TABLE "T_Utilisateurs"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON TABLE systeme."T_Utilisateurs" IS 'Comptes utilisateurs : identité, authentification, rôle, entité, validité et indicateurs staff/administrateur. Les triggers normalisent le téléphone, datent les modifications et alimentent l’audit.';


--
-- Name: COLUMN "T_Utilisateurs"."IdUser"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Utilisateurs"."IdUser" IS 'Identifiant du compte utilisateur.';


--
-- Name: COLUMN "T_Utilisateurs"."NomUser"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Utilisateurs"."NomUser" IS 'Nom de l’utilisateur.';


--
-- Name: COLUMN "T_Utilisateurs"."PrenomUser"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Utilisateurs"."PrenomUser" IS 'Prénom de l’utilisateur.';


--
-- Name: COLUMN "T_Utilisateurs"."EmailUser"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Utilisateurs"."EmailUser" IS 'Adresse électronique du compte, utilisée pour la connexion.';


--
-- Name: COLUMN "T_Utilisateurs"."MotdepasseUser"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Utilisateurs"."MotdepasseUser" IS 'Empreinte du mot de passe utilisée pour l’authentification du compte ; donnée confidentielle à exclure des projections publiques.';


--
-- Name: COLUMN "T_Utilisateurs"."PhoneUser"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Utilisateurs"."PhoneUser" IS 'Téléphone utilisateur ; le trigger de normalisation conserve les chiffres sans interpréter le pays.';


--
-- Name: COLUMN "T_Utilisateurs"."DatecreationUser"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Utilisateurs"."DatecreationUser" IS 'Date et heure de création du compte.';


--
-- Name: COLUMN "T_Utilisateurs"."IdRoleFk"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Utilisateurs"."IdRoleFk" IS 'Rôle de l’utilisateur dans le référentiel. Relation imposée : FOREIGN KEY ("IdRoleFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE ON DELETE SET NULL.';


--
-- Name: COLUMN "T_Utilisateurs"."ValideUser"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Utilisateurs"."ValideUser" IS 'Indique si le compte est déclaré valide/actif dans le registre ; distinct des qualifications calculées dans les vues.';


--
-- Name: COLUMN "T_Utilisateurs"."SexeUser"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Utilisateurs"."SexeUser" IS 'Code de sexe enregistré pour le compte ; la contrainte actuelle admet M ou F.';


--
-- Name: COLUMN "T_Utilisateurs"."DateModificationUser"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Utilisateurs"."DateModificationUser" IS 'Date et heure de dernière modification du compte, actualisée par trigger.';


--
-- Name: COLUMN "T_Utilisateurs"."UrlPhoto"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Utilisateurs"."UrlPhoto" IS 'Référence de la photo de l’utilisateur.';


--
-- Name: COLUMN "T_Utilisateurs"."IdEntiteFk"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Utilisateurs"."IdEntiteFk" IS 'Entité de rattachement de l’enregistrement. Relation imposée : FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON UPDATE CASCADE ON DELETE SET NULL.';


--
-- Name: COLUMN "T_Utilisateurs"."Is_staff"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Utilisateurs"."Is_staff" IS 'Indicateur de compte staff ; pris en compte par les contrôles actuels d’administration.';


--
-- Name: COLUMN "T_Utilisateurs"."Is_Admin"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Utilisateurs"."Is_Admin" IS 'Indicateur de compte administrateur ; pris en compte par les contrôles actuels d’administration.';


--
-- Name: CONSTRAINT "T_Utilisateurs_IdUser_not_null" ON "T_Utilisateurs"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "T_Utilisateurs_IdUser_not_null" ON systeme."T_Utilisateurs" IS 'Non-nullité : exige une valeur renseignée dans "systeme"."T_Utilisateurs". Définition : NOT NULL "IdUser".';


--
-- Name: CONSTRAINT "T_Utilisateurs_NomUser_not_null" ON "T_Utilisateurs"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "T_Utilisateurs_NomUser_not_null" ON systeme."T_Utilisateurs" IS 'Non-nullité : exige une valeur renseignée dans "systeme"."T_Utilisateurs". Définition : NOT NULL "NomUser".';


--
-- Name: CONSTRAINT "T_Utilisateurs_PrenomUser_not_null" ON "T_Utilisateurs"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "T_Utilisateurs_PrenomUser_not_null" ON systeme."T_Utilisateurs" IS 'Non-nullité : exige une valeur renseignée dans "systeme"."T_Utilisateurs". Définition : NOT NULL "PrenomUser".';


--
-- Name: CONSTRAINT "T_Utilisateurs_EmailUser_not_null" ON "T_Utilisateurs"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "T_Utilisateurs_EmailUser_not_null" ON systeme."T_Utilisateurs" IS 'Non-nullité : exige une valeur renseignée dans "systeme"."T_Utilisateurs". Définition : NOT NULL "EmailUser".';


--
-- Name: CONSTRAINT "T_Utilisateurs_MotdepasseUser_not_null" ON "T_Utilisateurs"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "T_Utilisateurs_MotdepasseUser_not_null" ON systeme."T_Utilisateurs" IS 'Non-nullité : exige une valeur renseignée dans "systeme"."T_Utilisateurs". Définition : NOT NULL "MotdepasseUser".';


--
-- Name: CONSTRAINT "T_Utilisateurs_ValideUser_not_null" ON "T_Utilisateurs"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "T_Utilisateurs_ValideUser_not_null" ON systeme."T_Utilisateurs" IS 'Non-nullité : exige une valeur renseignée dans "systeme"."T_Utilisateurs". Définition : NOT NULL "ValideUser".';


--
-- Name: CONSTRAINT "T_Utilisateurs_SexeUser_not_null" ON "T_Utilisateurs"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "T_Utilisateurs_SexeUser_not_null" ON systeme."T_Utilisateurs" IS 'Non-nullité : exige une valeur renseignée dans "systeme"."T_Utilisateurs". Définition : NOT NULL "SexeUser".';


--
-- Name: CONSTRAINT "T_Utilisateurs_DateModificationUser_not_null" ON "T_Utilisateurs"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "T_Utilisateurs_DateModificationUser_not_null" ON systeme."T_Utilisateurs" IS 'Non-nullité : exige une valeur renseignée dans "systeme"."T_Utilisateurs". Définition : NOT NULL "DateModificationUser".';


--
-- Name: CONSTRAINT "T_Utilisateurs_Is_staff_not_null" ON "T_Utilisateurs"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "T_Utilisateurs_Is_staff_not_null" ON systeme."T_Utilisateurs" IS 'Non-nullité : exige une valeur renseignée dans "systeme"."T_Utilisateurs". Définition : NOT NULL "Is_staff".';


--
-- Name: CONSTRAINT "T_Utilisateurs_Is_Admin_not_null" ON "T_Utilisateurs"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "T_Utilisateurs_Is_Admin_not_null" ON systeme."T_Utilisateurs" IS 'Non-nullité : exige une valeur renseignée dans "systeme"."T_Utilisateurs". Définition : NOT NULL "Is_Admin".';


--
-- Name: CONSTRAINT chk_sexe_utilisateur ON "T_Utilisateurs"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT chk_sexe_utilisateur ON systeme."T_Utilisateurs" IS 'Contrôle de cohérence des valeurs autorisées dans "systeme"."T_Utilisateurs". Définition : CHECK ("SexeUser" = ANY (ARRAY[''M''::bpchar, ''F''::bpchar])).';


--
-- Name: T_Entite_Localisation; Type: TABLE; Schema: systeme; Owner: -
--

CREATE TABLE systeme."T_Entite_Localisation" (
    "IdEntiteLocalisation" integer CONSTRAINT "T_Entite_Localisation_IdEntiteLocalisation_not_null" NOT NULL,
    "IdEntiteFk" integer CONSTRAINT "T_Entite_Localisation_IdEntiteFk_not_null" NOT NULL,
    "IdNiveau_3_Fk" integer,
    "IdNiveau_4_Fk" integer,
    "IdNiveau_5_Fk" integer,
    "Latitude" numeric(9,6),
    "Longitude" numeric(9,6),
    "AdresseDetaillee" text,
    "DateCreation" timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: TABLE "T_Entite_Localisation"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON TABLE systeme."T_Entite_Localisation" IS 'Localisations des entités : niveaux géographiques de rattachement, coordonnées et adresse détaillée. Une entité peut posséder plusieurs localisations.';


--
-- Name: COLUMN "T_Entite_Localisation"."IdEntiteLocalisation"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Entite_Localisation"."IdEntiteLocalisation" IS 'Identifiant de la localisation d’entité.';


--
-- Name: COLUMN "T_Entite_Localisation"."IdEntiteFk"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Entite_Localisation"."IdEntiteFk" IS 'Entité de rattachement de l’enregistrement. Relation imposée : FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON UPDATE CASCADE ON DELETE CASCADE.';


--
-- Name: COLUMN "T_Entite_Localisation"."IdNiveau_3_Fk"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Entite_Localisation"."IdNiveau_3_Fk" IS 'Unité géographique de rattachement de niveau 3. Relation imposée : FOREIGN KEY ("IdNiveau_3_Fk") REFERENCES geolocalisation."T_Niveau_3"("ID_Niveau_3").';


--
-- Name: COLUMN "T_Entite_Localisation"."IdNiveau_4_Fk"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Entite_Localisation"."IdNiveau_4_Fk" IS 'Unité géographique de rattachement de niveau 4. Relation imposée : FOREIGN KEY ("IdNiveau_4_Fk") REFERENCES geolocalisation."T_Niveau_4"("ID_Niveau_4").';


--
-- Name: COLUMN "T_Entite_Localisation"."IdNiveau_5_Fk"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Entite_Localisation"."IdNiveau_5_Fk" IS 'Unité géographique de rattachement de niveau 5. Relation imposée : FOREIGN KEY ("IdNiveau_5_Fk") REFERENCES geolocalisation."T_Niveau_5"("ID_Niveau_5").';


--
-- Name: COLUMN "T_Entite_Localisation"."Latitude"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Entite_Localisation"."Latitude" IS 'Latitude de la localisation ; coordonnée décimale.';


--
-- Name: COLUMN "T_Entite_Localisation"."Longitude"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Entite_Localisation"."Longitude" IS 'Longitude de la localisation ; coordonnée décimale.';


--
-- Name: COLUMN "T_Entite_Localisation"."AdresseDetaillee"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Entite_Localisation"."AdresseDetaillee" IS 'Adresse détaillée de cette localisation.';


--
-- Name: COLUMN "T_Entite_Localisation"."DateCreation"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Entite_Localisation"."DateCreation" IS 'Horodatage de création de la localisation, sans fuseau dans le type SQL.';


--
-- Name: CONSTRAINT "T_Entite_Localisation_IdEntiteLocalisation_not_null" ON "T_Entite_Localisation"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "T_Entite_Localisation_IdEntiteLocalisation_not_null" ON systeme."T_Entite_Localisation" IS 'Non-nullité : exige une valeur renseignée dans "systeme"."T_Entite_Localisation". Définition : NOT NULL "IdEntiteLocalisation".';


--
-- Name: CONSTRAINT "T_Entite_Localisation_IdEntiteFk_not_null" ON "T_Entite_Localisation"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "T_Entite_Localisation_IdEntiteFk_not_null" ON systeme."T_Entite_Localisation" IS 'Non-nullité : exige une valeur renseignée dans "systeme"."T_Entite_Localisation". Définition : NOT NULL "IdEntiteFk".';


--
-- Name: T_Admin_UI_Setting; Type: TABLE; Schema: systeme; Owner: -
--

CREATE TABLE systeme."T_Admin_UI_Setting" (
    "IdAdminUISetting" integer CONSTRAINT "T_Admin_UI_Setting_IdAdminUISetting_not_null" NOT NULL,
    "SettingScope" character varying(50) DEFAULT 'global'::character varying CONSTRAINT "T_Admin_UI_Setting_SettingScope_not_null" NOT NULL,
    "ScopeValue" character varying(100),
    "SettingKey" character varying(100) CONSTRAINT "T_Admin_UI_Setting_SettingKey_not_null" NOT NULL,
    "SettingLabel" character varying(150),
    "SettingGroup" character varying(100) DEFAULT 'general'::character varying,
    "SettingValue" text,
    "SettingValueJson" jsonb,
    "SettingType" character varying(50) DEFAULT 'text'::character varying,
    "DisplayOrder" integer DEFAULT 0,
    "IsEditable" boolean DEFAULT true,
    "IsSystem" boolean DEFAULT false,
    "ValideSetting" boolean DEFAULT true,
    "CreatedAt" timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    "UpdatedAt" timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    "UpdatedByUserFk" integer,
    "ObsSetting" text,
    CONSTRAINT "Ck_Admin_UI_Setting_Scope" CHECK ((("SettingScope")::text = ANY (ARRAY[('global'::character varying)::text, ('entite'::character varying)::text, ('user'::character varying)::text, ('module'::character varying)::text]))),
    CONSTRAINT "Ck_Admin_UI_Setting_Type" CHECK ((("SettingType")::text = ANY (ARRAY[('text'::character varying)::text, ('number'::character varying)::text, ('boolean'::character varying)::text, ('select'::character varying)::text, ('json'::character varying)::text, ('color'::character varying)::text, ('file'::character varying)::text, ('email'::character varying)::text, ('phone'::character varying)::text, ('url'::character varying)::text, ('textarea'::character varying)::text])))
);


--
-- Name: TABLE "T_Admin_UI_Setting"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON TABLE systeme."T_Admin_UI_Setting" IS 'Paramètres d’interface partagés avec portée, clé, groupe, type et valeur texte/JSON. La contrainte installée admet les portées global, entite, user et module ; UpdatedAt est actualisé par trigger.';


--
-- Name: COLUMN "T_Admin_UI_Setting"."IdAdminUISetting"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Admin_UI_Setting"."IdAdminUISetting" IS 'Identifiant du paramètre d’interface.';


--
-- Name: COLUMN "T_Admin_UI_Setting"."SettingScope"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Admin_UI_Setting"."SettingScope" IS 'Portée du paramètre d’interface ; la contrainte actuellement installée admet global, entite, user et module. Distincte de la portée des correspondances FK.';


--
-- Name: COLUMN "T_Admin_UI_Setting"."ScopeValue"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Admin_UI_Setting"."ScopeValue" IS 'Identifiant ou valeur du contexte ciblé par SettingScope ; ne constitue pas une autorisation d’accès.';


--
-- Name: COLUMN "T_Admin_UI_Setting"."SettingKey"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Admin_UI_Setting"."SettingKey" IS 'Clé technique stable du paramètre.';


--
-- Name: COLUMN "T_Admin_UI_Setting"."SettingLabel"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Admin_UI_Setting"."SettingLabel" IS 'Libellé du paramètre présenté dans l’administration.';


--
-- Name: COLUMN "T_Admin_UI_Setting"."SettingGroup"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Admin_UI_Setting"."SettingGroup" IS 'Groupe fonctionnel du paramètre d’interface.';


--
-- Name: COLUMN "T_Admin_UI_Setting"."SettingValue"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Admin_UI_Setting"."SettingValue" IS 'Valeur du paramètre sous forme textuelle.';


--
-- Name: COLUMN "T_Admin_UI_Setting"."SettingValueJson"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Admin_UI_Setting"."SettingValueJson" IS 'Valeur structurée JSON du paramètre ; distincte de la représentation textuelle.';


--
-- Name: COLUMN "T_Admin_UI_Setting"."SettingType"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Admin_UI_Setting"."SettingType" IS 'Type de représentation du paramètre contrôlé par la contrainte installée.';


--
-- Name: COLUMN "T_Admin_UI_Setting"."DisplayOrder"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Admin_UI_Setting"."DisplayOrder" IS 'Ordre d’affichage du paramètre ou de la correspondance.';


--
-- Name: COLUMN "T_Admin_UI_Setting"."IsEditable"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Admin_UI_Setting"."IsEditable" IS 'Indique si le paramètre est déclaré modifiable dans l’interface.';


--
-- Name: COLUMN "T_Admin_UI_Setting"."IsSystem"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Admin_UI_Setting"."IsSystem" IS 'Identifie un paramètre système.';


--
-- Name: COLUMN "T_Admin_UI_Setting"."ValideSetting"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Admin_UI_Setting"."ValideSetting" IS 'Indique si le paramètre est déclaré valide/actif dans le registre ; distinct des qualifications calculées dans les vues.';


--
-- Name: COLUMN "T_Admin_UI_Setting"."CreatedAt"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Admin_UI_Setting"."CreatedAt" IS 'Horodatage de création du paramètre.';


--
-- Name: COLUMN "T_Admin_UI_Setting"."UpdatedAt"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Admin_UI_Setting"."UpdatedAt" IS 'Horodatage de dernière mise à jour enregistré.';


--
-- Name: COLUMN "T_Admin_UI_Setting"."UpdatedByUserFk"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Admin_UI_Setting"."UpdatedByUserFk" IS 'Utilisateur ayant enregistré la dernière modification du paramètre ou de la correspondance. Relation imposée : FOREIGN KEY ("UpdatedByUserFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE ON DELETE SET NULL.';


--
-- Name: COLUMN "T_Admin_UI_Setting"."ObsSetting"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Admin_UI_Setting"."ObsSetting" IS 'Observations enregistrées sur le paramètre.';


--
-- Name: CONSTRAINT "T_Admin_UI_Setting_IdAdminUISetting_not_null" ON "T_Admin_UI_Setting"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "T_Admin_UI_Setting_IdAdminUISetting_not_null" ON systeme."T_Admin_UI_Setting" IS 'Non-nullité : exige une valeur renseignée dans "systeme"."T_Admin_UI_Setting". Définition : NOT NULL "IdAdminUISetting".';


--
-- Name: CONSTRAINT "T_Admin_UI_Setting_SettingScope_not_null" ON "T_Admin_UI_Setting"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "T_Admin_UI_Setting_SettingScope_not_null" ON systeme."T_Admin_UI_Setting" IS 'Non-nullité : exige une valeur renseignée dans "systeme"."T_Admin_UI_Setting". Définition : NOT NULL "SettingScope".';


--
-- Name: CONSTRAINT "T_Admin_UI_Setting_SettingKey_not_null" ON "T_Admin_UI_Setting"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "T_Admin_UI_Setting_SettingKey_not_null" ON systeme."T_Admin_UI_Setting" IS 'Non-nullité : exige une valeur renseignée dans "systeme"."T_Admin_UI_Setting". Définition : NOT NULL "SettingKey".';


--
-- Name: CONSTRAINT "Ck_Admin_UI_Setting_Scope" ON "T_Admin_UI_Setting"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "Ck_Admin_UI_Setting_Scope" ON systeme."T_Admin_UI_Setting" IS 'Contrôle de cohérence des valeurs autorisées dans "systeme"."T_Admin_UI_Setting". Définition : CHECK ("SettingScope"::text = ANY (ARRAY[''global''::character varying::text, ''entite''::character varying::text, ''user''::character varying::text, ''module''::character varying::text])).';


--
-- Name: CONSTRAINT "Ck_Admin_UI_Setting_Type" ON "T_Admin_UI_Setting"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "Ck_Admin_UI_Setting_Type" ON systeme."T_Admin_UI_Setting" IS 'Contrôle de cohérence des valeurs autorisées dans "systeme"."T_Admin_UI_Setting". Définition : CHECK ("SettingType"::text = ANY (ARRAY[''text''::character varying::text, ''number''::character varying::text, ''boolean''::character varying::text, ''select''::character varying::text, ''json''::character varying::text, ''color''::character varying::text, ''file''::character varying::text, ''email''::character varying::text, ''phone''::character varying::text, ''url''::character varying::text, ''textarea''::character varying::text])).';


--
-- Name: T_Admin_UI_Setting_IdAdminUISetting_seq; Type: SEQUENCE; Schema: systeme; Owner: -
--

ALTER TABLE systeme."T_Admin_UI_Setting" ALTER COLUMN "IdAdminUISetting" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME systeme."T_Admin_UI_Setting_IdAdminUISetting_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: SEQUENCE "T_Admin_UI_Setting_IdAdminUISetting_seq"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON SEQUENCE systeme."T_Admin_UI_Setting_IdAdminUISetting_seq" IS 'Séquence de génération de "systeme"."T_Admin_UI_Setting"."IdAdminUISetting". Les valeurs produites identifient les enregistrements ; les écarts de numérotation ne prouvent pas une suppression.';


--
-- Name: T_Audit_Log; Type: TABLE; Schema: systeme; Owner: -
--

CREATE TABLE systeme."T_Audit_Log" (
    "IdLog" integer CONSTRAINT "T_Audit_Log_IdLog_not_null" NOT NULL,
    "TableName" text,
    "Operation" text,
    "OldData" jsonb,
    "NewData" jsonb,
    "ChangedAt" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "IdEntiteFk" integer
);


--
-- Name: TABLE "T_Audit_Log"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON TABLE systeme."T_Audit_Log" IS 'Événements d’audit : table, opération, instant, valeurs avant/après en JSON et entité éventuelle. Les événements proviennent des triggers raccordés ou des écritures explicites de l’application.';


--
-- Name: COLUMN "T_Audit_Log"."IdLog"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Audit_Log"."IdLog" IS 'Identifiant de l’événement d’audit.';


--
-- Name: COLUMN "T_Audit_Log"."TableName"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Audit_Log"."TableName" IS 'Nom de la table à l’origine de l’événement d’audit.';


--
-- Name: COLUMN "T_Audit_Log"."Operation"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Audit_Log"."Operation" IS 'Nom de l’opération auditée ; le trigger produit INSERT, UPDATE ou DELETE.';


--
-- Name: COLUMN "T_Audit_Log"."OldData"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Audit_Log"."OldData" IS 'Valeurs avant l’opération auditable, sérialisées en JSON ; NULL lors d’une insertion par le trigger d’audit.';


--
-- Name: COLUMN "T_Audit_Log"."NewData"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Audit_Log"."NewData" IS 'Valeurs après l’opération auditable, sérialisées en JSON ; NULL lors d’une suppression par le trigger d’audit.';


--
-- Name: COLUMN "T_Audit_Log"."ChangedAt"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Audit_Log"."ChangedAt" IS 'Horodatage de l’événement d’audit.';


--
-- Name: COLUMN "T_Audit_Log"."IdEntiteFk"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Audit_Log"."IdEntiteFk" IS 'Entité de rattachement de l’enregistrement. Relation imposée : FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON UPDATE CASCADE ON DELETE SET NULL.';


--
-- Name: CONSTRAINT "T_Audit_Log_IdLog_not_null" ON "T_Audit_Log"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "T_Audit_Log_IdLog_not_null" ON systeme."T_Audit_Log" IS 'Non-nullité : exige une valeur renseignée dans "systeme"."T_Audit_Log". Définition : NOT NULL "IdLog".';


--
-- Name: T_Audit_Log_IdLog_seq; Type: SEQUENCE; Schema: systeme; Owner: -
--

ALTER TABLE systeme."T_Audit_Log" ALTER COLUMN "IdLog" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME systeme."T_Audit_Log_IdLog_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: SEQUENCE "T_Audit_Log_IdLog_seq"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON SEQUENCE systeme."T_Audit_Log_IdLog_seq" IS 'Séquence de génération de "systeme"."T_Audit_Log"."IdLog". Les valeurs produites identifient les enregistrements ; les écarts de numérotation ne prouvent pas une suppression.';


--
-- Name: T_Entite_IdEntite_seq; Type: SEQUENCE; Schema: systeme; Owner: -
--

ALTER TABLE systeme."T_Entite" ALTER COLUMN "IdEntite" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME systeme."T_Entite_IdEntite_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: SEQUENCE "T_Entite_IdEntite_seq"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON SEQUENCE systeme."T_Entite_IdEntite_seq" IS 'Séquence de génération de "systeme"."T_Entite"."IdEntite". Les valeurs produites identifient les enregistrements ; les écarts de numérotation ne prouvent pas une suppression.';


--
-- Name: T_Entite_Localisation_IdEntiteLocalisation_seq; Type: SEQUENCE; Schema: systeme; Owner: -
--

ALTER TABLE systeme."T_Entite_Localisation" ALTER COLUMN "IdEntiteLocalisation" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME systeme."T_Entite_Localisation_IdEntiteLocalisation_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: SEQUENCE "T_Entite_Localisation_IdEntiteLocalisation_seq"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON SEQUENCE systeme."T_Entite_Localisation_IdEntiteLocalisation_seq" IS 'Séquence de génération de "systeme"."T_Entite_Localisation"."IdEntiteLocalisation". Les valeurs produites identifient les enregistrements ; les écarts de numérotation ne prouvent pas une suppression.';


--
-- Name: T_Fk_Correspondance; Type: TABLE; Schema: systeme; Owner: -
--

CREATE TABLE systeme."T_Fk_Correspondance" (
    "IdFkCorrespondance" integer CONSTRAINT "T_Fk_Correspondance_IdFkCorrespondance_not_null" NOT NULL,
    "ModuleName" character varying(80) CONSTRAINT "T_Fk_Correspondance_ModuleName_not_null" NOT NULL,
    "SchemaName" character varying(80) CONSTRAINT "T_Fk_Correspondance_SchemaName_not_null" NOT NULL,
    "ViewName" character varying(120),
    "SourceKey" character varying(120) CONSTRAINT "T_Fk_Correspondance_SourceKey_not_null" NOT NULL,
    "FieldName" character varying(120) CONSTRAINT "T_Fk_Correspondance_FieldName_not_null" NOT NULL,
    "FieldLabel" character varying(255),
    "MappingType" character varying(40) DEFAULT 'generic_category'::character varying CONSTRAINT "T_Fk_Correspondance_MappingType_not_null" NOT NULL,
    "ReferenceSchemaName" character varying(80),
    "ReferenceObjectName" character varying(120),
    "ReferenceFieldName" character varying(120),
    "TargetCategoryIdFk" integer,
    "MappingValue" character varying(120) CONSTRAINT "T_Fk_Correspondance_MappingValue_not_null" NOT NULL,
    "IsDefaultMapping" boolean DEFAULT false CONSTRAINT "T_Fk_Correspondance_IsDefaultMapping_not_null" NOT NULL,
    "ValideFkCorrespondance" boolean DEFAULT true CONSTRAINT "T_Fk_Correspondance_ValideFkCorrespondance_not_null" NOT NULL,
    "SettingScope" character varying(60) DEFAULT 'global'::character varying CONSTRAINT "T_Fk_Correspondance_SettingScope_not_null" NOT NULL,
    "ScopeValue" character varying(120),
    "DisplayOrder" integer DEFAULT 0 CONSTRAINT "T_Fk_Correspondance_DisplayOrder_not_null" NOT NULL,
    "UpdatedAt" timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP CONSTRAINT "T_Fk_Correspondance_UpdatedAt_not_null" NOT NULL,
    "UpdatedByUserFk" integer,
    "ObsFkCorrespondance" text,
    CONSTRAINT chk_fkcorrespondance_mappingtype CHECK ((("MappingType")::text = ANY (ARRAY[('generic_category'::character varying)::text, ('direct_source'::character varying)::text, ('hierarchy_mode'::character varying)::text]))),
    CONSTRAINT chk_fkcorrespondance_scope CHECK ((("SettingScope")::text = ANY (ARRAY[('global'::character varying)::text, ('country'::character varying)::text, ('entity'::character varying)::text])))
);


--
-- Name: TABLE "T_Fk_Correspondance"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON TABLE systeme."T_Fk_Correspondance" IS 'Correspondances configurables des champs et sources de listes : catégorie ou source directe, portée global/country/entity, ordre, validité et auteur de modification.';


--
-- Name: COLUMN "T_Fk_Correspondance"."IdFkCorrespondance"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Fk_Correspondance"."IdFkCorrespondance" IS 'Identifiant de la correspondance de champ.';


--
-- Name: COLUMN "T_Fk_Correspondance"."ModuleName"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Fk_Correspondance"."ModuleName" IS 'Module applicatif auquel s’applique la correspondance.';


--
-- Name: COLUMN "T_Fk_Correspondance"."SchemaName"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Fk_Correspondance"."SchemaName" IS 'Schéma PostgreSQL de la vue dont le champ est configuré.';


--
-- Name: COLUMN "T_Fk_Correspondance"."ViewName"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Fk_Correspondance"."ViewName" IS 'Nom de la vue dont les correspondances de champ sont configurées.';


--
-- Name: COLUMN "T_Fk_Correspondance"."SourceKey"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Fk_Correspondance"."SourceKey" IS 'Clé applicative de la source de liste configurée.';


--
-- Name: COLUMN "T_Fk_Correspondance"."FieldName"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Fk_Correspondance"."FieldName" IS 'Nom technique du champ dont la source de liste est configurée.';


--
-- Name: COLUMN "T_Fk_Correspondance"."FieldLabel"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Fk_Correspondance"."FieldLabel" IS 'Libellé du champ présenté dans le paramétrage des correspondances.';


--
-- Name: COLUMN "T_Fk_Correspondance"."MappingType"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Fk_Correspondance"."MappingType" IS 'Mode de correspondance : generic_category, direct_source ou hierarchy_mode, selon la contrainte installée.';


--
-- Name: COLUMN "T_Fk_Correspondance"."ReferenceSchemaName"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Fk_Correspondance"."ReferenceSchemaName" IS 'Schéma PostgreSQL de l’objet de référence configuré.';


--
-- Name: COLUMN "T_Fk_Correspondance"."ReferenceObjectName"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Fk_Correspondance"."ReferenceObjectName" IS 'Nom technique de l’objet de référence configuré pour la liste.';


--
-- Name: COLUMN "T_Fk_Correspondance"."ReferenceFieldName"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Fk_Correspondance"."ReferenceFieldName" IS 'Champ identifiant ou libellé utilisé dans l’objet de référence configuré.';


--
-- Name: COLUMN "T_Fk_Correspondance"."TargetCategoryIdFk"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Fk_Correspondance"."TargetCategoryIdFk" IS 'Catégorie de nomenclature ciblée par une correspondance de type generic_category. Relation imposée : FOREIGN KEY ("TargetCategoryIdFk") REFERENCES referentiel."T_CategorieGenerique"("ID_CategorieGenerique") ON UPDATE CASCADE ON DELETE SET NULL.';


--
-- Name: COLUMN "T_Fk_Correspondance"."MappingValue"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Fk_Correspondance"."MappingValue" IS 'Valeur de configuration associée à la correspondance.';


--
-- Name: COLUMN "T_Fk_Correspondance"."IsDefaultMapping"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Fk_Correspondance"."IsDefaultMapping" IS 'Indique une correspondance proposée par défaut.';


--
-- Name: COLUMN "T_Fk_Correspondance"."ValideFkCorrespondance"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Fk_Correspondance"."ValideFkCorrespondance" IS 'Indique si la correspondance est déclaré valide/actif dans le registre ; distinct des qualifications calculées dans les vues.';


--
-- Name: COLUMN "T_Fk_Correspondance"."SettingScope"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Fk_Correspondance"."SettingScope" IS 'Portée de la correspondance FK : global, country ou entity selon la contrainte installée.';


--
-- Name: COLUMN "T_Fk_Correspondance"."ScopeValue"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Fk_Correspondance"."ScopeValue" IS 'Identifiant ou valeur du contexte ciblé par SettingScope ; ne constitue pas une autorisation d’accès.';


--
-- Name: COLUMN "T_Fk_Correspondance"."DisplayOrder"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Fk_Correspondance"."DisplayOrder" IS 'Ordre d’affichage du paramètre ou de la correspondance.';


--
-- Name: COLUMN "T_Fk_Correspondance"."UpdatedAt"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Fk_Correspondance"."UpdatedAt" IS 'Horodatage de dernière mise à jour enregistré.';


--
-- Name: COLUMN "T_Fk_Correspondance"."UpdatedByUserFk"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Fk_Correspondance"."UpdatedByUserFk" IS 'Utilisateur ayant enregistré la dernière modification du paramètre ou de la correspondance. Relation imposée : FOREIGN KEY ("UpdatedByUserFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE ON DELETE SET NULL.';


--
-- Name: COLUMN "T_Fk_Correspondance"."ObsFkCorrespondance"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Fk_Correspondance"."ObsFkCorrespondance" IS 'Observations enregistrées sur la correspondance.';


--
-- Name: CONSTRAINT "T_Fk_Correspondance_IdFkCorrespondance_not_null" ON "T_Fk_Correspondance"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "T_Fk_Correspondance_IdFkCorrespondance_not_null" ON systeme."T_Fk_Correspondance" IS 'Non-nullité : exige une valeur renseignée dans "systeme"."T_Fk_Correspondance". Définition : NOT NULL "IdFkCorrespondance".';


--
-- Name: CONSTRAINT "T_Fk_Correspondance_ModuleName_not_null" ON "T_Fk_Correspondance"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "T_Fk_Correspondance_ModuleName_not_null" ON systeme."T_Fk_Correspondance" IS 'Non-nullité : exige une valeur renseignée dans "systeme"."T_Fk_Correspondance". Définition : NOT NULL "ModuleName".';


--
-- Name: CONSTRAINT "T_Fk_Correspondance_SchemaName_not_null" ON "T_Fk_Correspondance"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "T_Fk_Correspondance_SchemaName_not_null" ON systeme."T_Fk_Correspondance" IS 'Non-nullité : exige une valeur renseignée dans "systeme"."T_Fk_Correspondance". Définition : NOT NULL "SchemaName".';


--
-- Name: CONSTRAINT "T_Fk_Correspondance_SourceKey_not_null" ON "T_Fk_Correspondance"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "T_Fk_Correspondance_SourceKey_not_null" ON systeme."T_Fk_Correspondance" IS 'Non-nullité : exige une valeur renseignée dans "systeme"."T_Fk_Correspondance". Définition : NOT NULL "SourceKey".';


--
-- Name: CONSTRAINT "T_Fk_Correspondance_FieldName_not_null" ON "T_Fk_Correspondance"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "T_Fk_Correspondance_FieldName_not_null" ON systeme."T_Fk_Correspondance" IS 'Non-nullité : exige une valeur renseignée dans "systeme"."T_Fk_Correspondance". Définition : NOT NULL "FieldName".';


--
-- Name: CONSTRAINT "T_Fk_Correspondance_MappingType_not_null" ON "T_Fk_Correspondance"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "T_Fk_Correspondance_MappingType_not_null" ON systeme."T_Fk_Correspondance" IS 'Non-nullité : exige une valeur renseignée dans "systeme"."T_Fk_Correspondance". Définition : NOT NULL "MappingType".';


--
-- Name: CONSTRAINT "T_Fk_Correspondance_MappingValue_not_null" ON "T_Fk_Correspondance"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "T_Fk_Correspondance_MappingValue_not_null" ON systeme."T_Fk_Correspondance" IS 'Non-nullité : exige une valeur renseignée dans "systeme"."T_Fk_Correspondance". Définition : NOT NULL "MappingValue".';


--
-- Name: CONSTRAINT "T_Fk_Correspondance_IsDefaultMapping_not_null" ON "T_Fk_Correspondance"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "T_Fk_Correspondance_IsDefaultMapping_not_null" ON systeme."T_Fk_Correspondance" IS 'Non-nullité : exige une valeur renseignée dans "systeme"."T_Fk_Correspondance". Définition : NOT NULL "IsDefaultMapping".';


--
-- Name: CONSTRAINT "T_Fk_Correspondance_ValideFkCorrespondance_not_null" ON "T_Fk_Correspondance"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "T_Fk_Correspondance_ValideFkCorrespondance_not_null" ON systeme."T_Fk_Correspondance" IS 'Non-nullité : exige une valeur renseignée dans "systeme"."T_Fk_Correspondance". Définition : NOT NULL "ValideFkCorrespondance".';


--
-- Name: CONSTRAINT "T_Fk_Correspondance_SettingScope_not_null" ON "T_Fk_Correspondance"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "T_Fk_Correspondance_SettingScope_not_null" ON systeme."T_Fk_Correspondance" IS 'Non-nullité : exige une valeur renseignée dans "systeme"."T_Fk_Correspondance". Définition : NOT NULL "SettingScope".';


--
-- Name: CONSTRAINT "T_Fk_Correspondance_DisplayOrder_not_null" ON "T_Fk_Correspondance"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "T_Fk_Correspondance_DisplayOrder_not_null" ON systeme."T_Fk_Correspondance" IS 'Non-nullité : exige une valeur renseignée dans "systeme"."T_Fk_Correspondance". Définition : NOT NULL "DisplayOrder".';


--
-- Name: CONSTRAINT "T_Fk_Correspondance_UpdatedAt_not_null" ON "T_Fk_Correspondance"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "T_Fk_Correspondance_UpdatedAt_not_null" ON systeme."T_Fk_Correspondance" IS 'Non-nullité : exige une valeur renseignée dans "systeme"."T_Fk_Correspondance". Définition : NOT NULL "UpdatedAt".';


--
-- Name: CONSTRAINT chk_fkcorrespondance_mappingtype ON "T_Fk_Correspondance"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT chk_fkcorrespondance_mappingtype ON systeme."T_Fk_Correspondance" IS 'Contrôle de cohérence des valeurs autorisées dans "systeme"."T_Fk_Correspondance". Définition : CHECK ("MappingType"::text = ANY (ARRAY[''generic_category''::character varying::text, ''direct_source''::character varying::text, ''hierarchy_mode''::character varying::text])).';


--
-- Name: CONSTRAINT chk_fkcorrespondance_scope ON "T_Fk_Correspondance"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT chk_fkcorrespondance_scope ON systeme."T_Fk_Correspondance" IS 'Contrôle de cohérence des valeurs autorisées dans "systeme"."T_Fk_Correspondance". Définition : CHECK ("SettingScope"::text = ANY (ARRAY[''global''::character varying::text, ''country''::character varying::text, ''entity''::character varying::text])).';


--
-- Name: T_Fk_Correspondance_IdFkCorrespondance_seq; Type: SEQUENCE; Schema: systeme; Owner: -
--

ALTER TABLE systeme."T_Fk_Correspondance" ALTER COLUMN "IdFkCorrespondance" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME systeme."T_Fk_Correspondance_IdFkCorrespondance_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: SEQUENCE "T_Fk_Correspondance_IdFkCorrespondance_seq"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON SEQUENCE systeme."T_Fk_Correspondance_IdFkCorrespondance_seq" IS 'Séquence de génération de "systeme"."T_Fk_Correspondance"."IdFkCorrespondance". Les valeurs produites identifient les enregistrements ; les écarts de numérotation ne prouvent pas une suppression.';


--
-- Name: T_Licence; Type: TABLE; Schema: systeme; Owner: -
--

CREATE TABLE systeme."T_Licence" (
    "IdLicence" integer CONSTRAINT "T_Licence_IdLicence_not_null" NOT NULL,
    "IdEntiteFk" integer CONSTRAINT "T_Licence_IdEntiteFk_not_null" NOT NULL,
    "CleLicence" uuid DEFAULT gen_random_uuid(),
    "DateDebut" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "DateFin" timestamp without time zone CONSTRAINT "T_Licence_DateFin_not_null" NOT NULL,
    "IdStatutLicenceFk" integer CONSTRAINT "T_Licence_IdStatutLicenceFk_not_null" NOT NULL,
    "ValideLicence" boolean DEFAULT true,
    "ExpireeLicence" boolean DEFAULT false,
    CONSTRAINT chk_licence_dates CHECK (("DateFin" > "DateDebut"))
);


--
-- Name: TABLE "T_Licence"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON TABLE systeme."T_Licence" IS 'Licences des entités avec clé UUID, période, statut et indicateurs de validité/expiration. Les triggers contrôlent les insertions et actualisent l’expiration lors des écritures ; aucune tâche périodique n’est définie par ces triggers.';


--
-- Name: COLUMN "T_Licence"."IdLicence"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Licence"."IdLicence" IS 'Identifiant automatiquement attribué par une identité PostgreSQL ; les identifiants antérieurs sont conservés.';


--
-- Name: COLUMN "T_Licence"."IdEntiteFk"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Licence"."IdEntiteFk" IS 'Entité de rattachement de l’enregistrement. Relation imposée : FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON UPDATE CASCADE.';


--
-- Name: COLUMN "T_Licence"."CleLicence"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Licence"."CleLicence" IS 'Clé UUID identifiant la licence.';


--
-- Name: COLUMN "T_Licence"."DateDebut"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Licence"."DateDebut" IS 'Début de validité de la licence.';


--
-- Name: COLUMN "T_Licence"."DateFin"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Licence"."DateFin" IS 'Fin de validité de la licence, strictement postérieure à DateDebut selon la contrainte.';


--
-- Name: COLUMN "T_Licence"."IdStatutLicenceFk"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Licence"."IdStatutLicenceFk" IS 'Statut de licence dans le référentiel. Relation imposée : FOREIGN KEY ("IdStatutLicenceFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE.';


--
-- Name: COLUMN "T_Licence"."ValideLicence"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Licence"."ValideLicence" IS 'Indique si la licence est déclaré valide/actif dans le registre ; distinct des qualifications calculées dans les vues.';


--
-- Name: COLUMN "T_Licence"."ExpireeLicence"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Licence"."ExpireeLicence" IS 'Indicateur d’expiration calculé à l’écriture de la licence à partir de DateFin ; ne se met pas à jour seul avec le passage du temps.';


--
-- Name: CONSTRAINT "T_Licence_IdLicence_not_null" ON "T_Licence"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "T_Licence_IdLicence_not_null" ON systeme."T_Licence" IS 'Non-nullité : exige une valeur renseignée dans "systeme"."T_Licence". Définition : NOT NULL "IdLicence".';


--
-- Name: CONSTRAINT "T_Licence_IdEntiteFk_not_null" ON "T_Licence"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "T_Licence_IdEntiteFk_not_null" ON systeme."T_Licence" IS 'Non-nullité : exige une valeur renseignée dans "systeme"."T_Licence". Définition : NOT NULL "IdEntiteFk".';


--
-- Name: CONSTRAINT "T_Licence_DateFin_not_null" ON "T_Licence"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "T_Licence_DateFin_not_null" ON systeme."T_Licence" IS 'Non-nullité : exige une valeur renseignée dans "systeme"."T_Licence". Définition : NOT NULL "DateFin".';


--
-- Name: CONSTRAINT "T_Licence_IdStatutLicenceFk_not_null" ON "T_Licence"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "T_Licence_IdStatutLicenceFk_not_null" ON systeme."T_Licence" IS 'Non-nullité : exige une valeur renseignée dans "systeme"."T_Licence". Définition : NOT NULL "IdStatutLicenceFk".';


--
-- Name: CONSTRAINT chk_licence_dates ON "T_Licence"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT chk_licence_dates ON systeme."T_Licence" IS 'Contrôle de cohérence des valeurs autorisées dans "systeme"."T_Licence". Définition : CHECK ("DateFin" > "DateDebut").';


--
-- Name: T_Licence_IdLicence_seq; Type: SEQUENCE; Schema: systeme; Owner: -
--

ALTER TABLE systeme."T_Licence" ALTER COLUMN "IdLicence" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME systeme."T_Licence_IdLicence_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: SEQUENCE "T_Licence_IdLicence_seq"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON SEQUENCE systeme."T_Licence_IdLicence_seq" IS 'Séquence technique d’identité attribuant les identifiants sans réécrire les lignes existantes.';


--
-- Name: T_Login; Type: TABLE; Schema: systeme; Owner: -
--

CREATE TABLE systeme."T_Login" (
    "IdLogin" integer CONSTRAINT "T_Login_IdLogin_not_null" NOT NULL,
    "IdUserFk" integer CONSTRAINT "T_Login_IdUserFk_not_null" NOT NULL,
    "IdTypeLoginFk" integer CONSTRAINT "T_Login_IdTypeLoginFk_not_null" NOT NULL,
    "DateLogin" timestamp with time zone DEFAULT CURRENT_TIMESTAMP CONSTRAINT "T_Login_DateLogin_not_null" NOT NULL,
    "IdEntiteFk" integer
);


--
-- Name: TABLE "T_Login"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON TABLE systeme."T_Login" IS 'Événements de connexion liés à un utilisateur, un type de connexion et une entité éventuelle.';


--
-- Name: COLUMN "T_Login"."IdLogin"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Login"."IdLogin" IS 'Identifiant de l’événement de connexion.';


--
-- Name: COLUMN "T_Login"."IdUserFk"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Login"."IdUserFk" IS 'Utilisateur rattaché à l’enregistrement. Relation imposée : FOREIGN KEY ("IdUserFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE.';


--
-- Name: COLUMN "T_Login"."IdTypeLoginFk"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Login"."IdTypeLoginFk" IS 'Type de l’événement de connexion dans le référentiel. Relation imposée : FOREIGN KEY ("IdTypeLoginFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE.';


--
-- Name: COLUMN "T_Login"."DateLogin"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Login"."DateLogin" IS 'Date et heure de l’événement de connexion.';


--
-- Name: COLUMN "T_Login"."IdEntiteFk"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Login"."IdEntiteFk" IS 'Entité de rattachement de l’enregistrement. Relation imposée : FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON UPDATE CASCADE ON DELETE SET NULL.';


--
-- Name: CONSTRAINT "T_Login_IdLogin_not_null" ON "T_Login"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "T_Login_IdLogin_not_null" ON systeme."T_Login" IS 'Non-nullité : exige une valeur renseignée dans "systeme"."T_Login". Définition : NOT NULL "IdLogin".';


--
-- Name: CONSTRAINT "T_Login_IdUserFk_not_null" ON "T_Login"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "T_Login_IdUserFk_not_null" ON systeme."T_Login" IS 'Non-nullité : exige une valeur renseignée dans "systeme"."T_Login". Définition : NOT NULL "IdUserFk".';


--
-- Name: CONSTRAINT "T_Login_IdTypeLoginFk_not_null" ON "T_Login"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "T_Login_IdTypeLoginFk_not_null" ON systeme."T_Login" IS 'Non-nullité : exige une valeur renseignée dans "systeme"."T_Login". Définition : NOT NULL "IdTypeLoginFk".';


--
-- Name: CONSTRAINT "T_Login_DateLogin_not_null" ON "T_Login"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "T_Login_DateLogin_not_null" ON systeme."T_Login" IS 'Non-nullité : exige une valeur renseignée dans "systeme"."T_Login". Définition : NOT NULL "DateLogin".';


--
-- Name: T_Login_IdLogin_seq; Type: SEQUENCE; Schema: systeme; Owner: -
--

ALTER TABLE systeme."T_Login" ALTER COLUMN "IdLogin" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME systeme."T_Login_IdLogin_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: SEQUENCE "T_Login_IdLogin_seq"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON SEQUENCE systeme."T_Login_IdLogin_seq" IS 'Séquence de génération de "systeme"."T_Login"."IdLogin". Les valeurs produites identifient les enregistrements ; les écarts de numérotation ne prouvent pas une suppression.';


--
-- Name: T_Utilisateurs_IdUser_seq; Type: SEQUENCE; Schema: systeme; Owner: -
--

ALTER TABLE systeme."T_Utilisateurs" ALTER COLUMN "IdUser" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME systeme."T_Utilisateurs_IdUser_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: SEQUENCE "T_Utilisateurs_IdUser_seq"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON SEQUENCE systeme."T_Utilisateurs_IdUser_seq" IS 'Séquence de génération de "systeme"."T_Utilisateurs"."IdUser". Les valeurs produites identifient les enregistrements ; les écarts de numérotation ne prouvent pas une suppression.';


--
-- Name: T_Admin_UI_Setting Pk_Admin_UI_Setting; Type: CONSTRAINT; Schema: systeme; Owner: -
--

ALTER TABLE ONLY systeme."T_Admin_UI_Setting"
    ADD CONSTRAINT "Pk_Admin_UI_Setting" PRIMARY KEY ("IdAdminUISetting");


--
-- Name: CONSTRAINT "Pk_Admin_UI_Setting" ON "T_Admin_UI_Setting"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "Pk_Admin_UI_Setting" ON systeme."T_Admin_UI_Setting" IS 'Clé primaire : identifie de manière unique chaque ligne dans "systeme"."T_Admin_UI_Setting". Définition : PRIMARY KEY ("IdAdminUISetting").';


--
-- Name: T_Entite Pk_IdEntite; Type: CONSTRAINT; Schema: systeme; Owner: -
--

ALTER TABLE ONLY systeme."T_Entite"
    ADD CONSTRAINT "Pk_IdEntite" PRIMARY KEY ("IdEntite");


--
-- Name: CONSTRAINT "Pk_IdEntite" ON "T_Entite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "Pk_IdEntite" ON systeme."T_Entite" IS 'Clé primaire : identifie de manière unique chaque ligne dans "systeme"."T_Entite". Définition : PRIMARY KEY ("IdEntite").';


--
-- Name: T_Entite_Localisation Pk_IdEntiteLocalisation; Type: CONSTRAINT; Schema: systeme; Owner: -
--

ALTER TABLE ONLY systeme."T_Entite_Localisation"
    ADD CONSTRAINT "Pk_IdEntiteLocalisation" PRIMARY KEY ("IdEntiteLocalisation");


--
-- Name: CONSTRAINT "Pk_IdEntiteLocalisation" ON "T_Entite_Localisation"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "Pk_IdEntiteLocalisation" ON systeme."T_Entite_Localisation" IS 'Clé primaire : identifie de manière unique chaque ligne dans "systeme"."T_Entite_Localisation". Définition : PRIMARY KEY ("IdEntiteLocalisation").';


--
-- Name: T_Licence Pk_IdLicence; Type: CONSTRAINT; Schema: systeme; Owner: -
--

ALTER TABLE ONLY systeme."T_Licence"
    ADD CONSTRAINT "Pk_IdLicence" PRIMARY KEY ("IdLicence");


--
-- Name: CONSTRAINT "Pk_IdLicence" ON "T_Licence"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "Pk_IdLicence" ON systeme."T_Licence" IS 'Clé primaire : identifie de manière unique chaque ligne dans "systeme"."T_Licence". Définition : PRIMARY KEY ("IdLicence").';


--
-- Name: T_Login Pk_IdLogin; Type: CONSTRAINT; Schema: systeme; Owner: -
--

ALTER TABLE ONLY systeme."T_Login"
    ADD CONSTRAINT "Pk_IdLogin" PRIMARY KEY ("IdLogin");


--
-- Name: CONSTRAINT "Pk_IdLogin" ON "T_Login"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "Pk_IdLogin" ON systeme."T_Login" IS 'Clé primaire : identifie de manière unique chaque ligne dans "systeme"."T_Login". Définition : PRIMARY KEY ("IdLogin").';


--
-- Name: T_Utilisateurs Pk_IdUser; Type: CONSTRAINT; Schema: systeme; Owner: -
--

ALTER TABLE ONLY systeme."T_Utilisateurs"
    ADD CONSTRAINT "Pk_IdUser" PRIMARY KEY ("IdUser");


--
-- Name: CONSTRAINT "Pk_IdUser" ON "T_Utilisateurs"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "Pk_IdUser" ON systeme."T_Utilisateurs" IS 'Clé primaire : identifie de manière unique chaque ligne dans "systeme"."T_Utilisateurs". Définition : PRIMARY KEY ("IdUser").';


--
-- Name: T_Audit_Log T_Audit_Log_pkey; Type: CONSTRAINT; Schema: systeme; Owner: -
--

ALTER TABLE ONLY systeme."T_Audit_Log"
    ADD CONSTRAINT "T_Audit_Log_pkey" PRIMARY KEY ("IdLog");


--
-- Name: CONSTRAINT "T_Audit_Log_pkey" ON "T_Audit_Log"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "T_Audit_Log_pkey" ON systeme."T_Audit_Log" IS 'Clé primaire : identifie de manière unique chaque ligne dans "systeme"."T_Audit_Log". Définition : PRIMARY KEY ("IdLog").';


--
-- Name: T_Entite T_Entite_EmailEntite_key; Type: CONSTRAINT; Schema: systeme; Owner: -
--

ALTER TABLE ONLY systeme."T_Entite"
    ADD CONSTRAINT "T_Entite_EmailEntite_key" UNIQUE ("EmailEntite");


--
-- Name: CONSTRAINT "T_Entite_EmailEntite_key" ON "T_Entite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "T_Entite_EmailEntite_key" ON systeme."T_Entite" IS 'Unicité : empêche les doublons sur la combinaison indiquée dans "systeme"."T_Entite". Définition : UNIQUE ("EmailEntite").';


--
-- Name: T_Entite T_Entite_PhoneEntite_key; Type: CONSTRAINT; Schema: systeme; Owner: -
--

ALTER TABLE ONLY systeme."T_Entite"
    ADD CONSTRAINT "T_Entite_PhoneEntite_key" UNIQUE ("PhoneEntite");


--
-- Name: CONSTRAINT "T_Entite_PhoneEntite_key" ON "T_Entite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "T_Entite_PhoneEntite_key" ON systeme."T_Entite" IS 'Unicité : empêche les doublons sur la combinaison indiquée dans "systeme"."T_Entite". Définition : UNIQUE ("PhoneEntite").';


--
-- Name: T_Fk_Correspondance T_Fk_Correspondance_pkey; Type: CONSTRAINT; Schema: systeme; Owner: -
--

ALTER TABLE ONLY systeme."T_Fk_Correspondance"
    ADD CONSTRAINT "T_Fk_Correspondance_pkey" PRIMARY KEY ("IdFkCorrespondance");


--
-- Name: CONSTRAINT "T_Fk_Correspondance_pkey" ON "T_Fk_Correspondance"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "T_Fk_Correspondance_pkey" ON systeme."T_Fk_Correspondance" IS 'Clé primaire : identifie de manière unique chaque ligne dans "systeme"."T_Fk_Correspondance". Définition : PRIMARY KEY ("IdFkCorrespondance").';


--
-- Name: T_Fk_Correspondance UQ_FkCorrespondance_SourceValueScope; Type: CONSTRAINT; Schema: systeme; Owner: -
--

ALTER TABLE ONLY systeme."T_Fk_Correspondance"
    ADD CONSTRAINT "UQ_FkCorrespondance_SourceValueScope" UNIQUE ("ModuleName", "SchemaName", "ViewName", "SourceKey", "FieldName", "MappingType", "MappingValue", "SettingScope", "ScopeValue");


--
-- Name: CONSTRAINT "UQ_FkCorrespondance_SourceValueScope" ON "T_Fk_Correspondance"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "UQ_FkCorrespondance_SourceValueScope" ON systeme."T_Fk_Correspondance" IS 'Unicité : empêche les doublons sur la combinaison indiquée dans "systeme"."T_Fk_Correspondance". Définition : UNIQUE ("ModuleName", "SchemaName", "ViewName", "SourceKey", "FieldName", "MappingType", "MappingValue", "SettingScope", "ScopeValue").';


--
-- Name: T_Admin_UI_Setting Uq_Admin_UI_Setting_Key_Scope; Type: CONSTRAINT; Schema: systeme; Owner: -
--

ALTER TABLE ONLY systeme."T_Admin_UI_Setting"
    ADD CONSTRAINT "Uq_Admin_UI_Setting_Key_Scope" UNIQUE ("SettingScope", "ScopeValue", "SettingKey");


--
-- Name: CONSTRAINT "Uq_Admin_UI_Setting_Key_Scope" ON "T_Admin_UI_Setting"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "Uq_Admin_UI_Setting_Key_Scope" ON systeme."T_Admin_UI_Setting" IS 'Unicité : empêche les doublons sur la combinaison indiquée dans "systeme"."T_Admin_UI_Setting". Définition : UNIQUE ("SettingScope", "ScopeValue", "SettingKey").';


--
-- Name: T_Utilisateurs utilisateurs_emailuser_key; Type: CONSTRAINT; Schema: systeme; Owner: -
--

ALTER TABLE ONLY systeme."T_Utilisateurs"
    ADD CONSTRAINT utilisateurs_emailuser_key UNIQUE ("EmailUser");


--
-- Name: CONSTRAINT utilisateurs_emailuser_key ON "T_Utilisateurs"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT utilisateurs_emailuser_key ON systeme."T_Utilisateurs" IS 'Unicité : empêche les doublons sur la combinaison indiquée dans "systeme"."T_Utilisateurs". Définition : UNIQUE ("EmailUser").';


--
-- Name: Idx_Admin_UI_Setting_Group; Type: INDEX; Schema: systeme; Owner: -
--

CREATE INDEX "Idx_Admin_UI_Setting_Group" ON systeme."T_Admin_UI_Setting" USING btree ("SettingGroup");


--
-- Name: INDEX "Idx_Admin_UI_Setting_Group"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON INDEX systeme."Idx_Admin_UI_Setting_Group" IS 'Index d’accès sur "systeme"."T_Admin_UI_Setting". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX "Idx_Admin_UI_Setting_Group" ON systeme."T_Admin_UI_Setting" USING btree ("SettingGroup").';


--
-- Name: Idx_Admin_UI_Setting_Key; Type: INDEX; Schema: systeme; Owner: -
--

CREATE INDEX "Idx_Admin_UI_Setting_Key" ON systeme."T_Admin_UI_Setting" USING btree ("SettingKey");


--
-- Name: INDEX "Idx_Admin_UI_Setting_Key"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON INDEX systeme."Idx_Admin_UI_Setting_Key" IS 'Index d’accès sur "systeme"."T_Admin_UI_Setting". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX "Idx_Admin_UI_Setting_Key" ON systeme."T_Admin_UI_Setting" USING btree ("SettingKey").';


--
-- Name: Idx_Admin_UI_Setting_Scope; Type: INDEX; Schema: systeme; Owner: -
--

CREATE INDEX "Idx_Admin_UI_Setting_Scope" ON systeme."T_Admin_UI_Setting" USING btree ("SettingScope", "ScopeValue");


--
-- Name: INDEX "Idx_Admin_UI_Setting_Scope"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON INDEX systeme."Idx_Admin_UI_Setting_Scope" IS 'Index d’accès sur "systeme"."T_Admin_UI_Setting". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX "Idx_Admin_UI_Setting_Scope" ON systeme."T_Admin_UI_Setting" USING btree ("SettingScope", "ScopeValue").';


--
-- Name: Idx_Admin_UI_Setting_UpdatedAt; Type: INDEX; Schema: systeme; Owner: -
--

CREATE INDEX "Idx_Admin_UI_Setting_UpdatedAt" ON systeme."T_Admin_UI_Setting" USING btree ("UpdatedAt");


--
-- Name: INDEX "Idx_Admin_UI_Setting_UpdatedAt"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON INDEX systeme."Idx_Admin_UI_Setting_UpdatedAt" IS 'Index d’accès sur "systeme"."T_Admin_UI_Setting". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX "Idx_Admin_UI_Setting_UpdatedAt" ON systeme."T_Admin_UI_Setting" USING btree ("UpdatedAt").';


--
-- Name: Idx_Admin_UI_Setting_Valide; Type: INDEX; Schema: systeme; Owner: -
--

CREATE INDEX "Idx_Admin_UI_Setting_Valide" ON systeme."T_Admin_UI_Setting" USING btree ("ValideSetting");


--
-- Name: INDEX "Idx_Admin_UI_Setting_Valide"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON INDEX systeme."Idx_Admin_UI_Setting_Valide" IS 'Index d’accès sur "systeme"."T_Admin_UI_Setting". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX "Idx_Admin_UI_Setting_Valide" ON systeme."T_Admin_UI_Setting" USING btree ("ValideSetting").';


--
-- Name: INDEX "Pk_Admin_UI_Setting"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON INDEX systeme."Pk_Admin_UI_Setting" IS 'Index support de la clé primaire sur "systeme"."T_Admin_UI_Setting". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX "Pk_Admin_UI_Setting" ON systeme."T_Admin_UI_Setting" USING btree ("IdAdminUISetting").';


--
-- Name: INDEX "Pk_IdEntite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON INDEX systeme."Pk_IdEntite" IS 'Index support de la clé primaire sur "systeme"."T_Entite". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX "Pk_IdEntite" ON systeme."T_Entite" USING btree ("IdEntite").';


--
-- Name: INDEX "Pk_IdEntiteLocalisation"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON INDEX systeme."Pk_IdEntiteLocalisation" IS 'Index support de la clé primaire sur "systeme"."T_Entite_Localisation". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX "Pk_IdEntiteLocalisation" ON systeme."T_Entite_Localisation" USING btree ("IdEntiteLocalisation").';


--
-- Name: INDEX "Pk_IdLicence"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON INDEX systeme."Pk_IdLicence" IS 'Index support de la clé primaire sur "systeme"."T_Licence". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX "Pk_IdLicence" ON systeme."T_Licence" USING btree ("IdLicence").';


--
-- Name: INDEX "Pk_IdLogin"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON INDEX systeme."Pk_IdLogin" IS 'Index support de la clé primaire sur "systeme"."T_Login". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX "Pk_IdLogin" ON systeme."T_Login" USING btree ("IdLogin").';


--
-- Name: INDEX "Pk_IdUser"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON INDEX systeme."Pk_IdUser" IS 'Index support de la clé primaire sur "systeme"."T_Utilisateurs". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX "Pk_IdUser" ON systeme."T_Utilisateurs" USING btree ("IdUser").';


--
-- Name: INDEX "T_Audit_Log_pkey"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON INDEX systeme."T_Audit_Log_pkey" IS 'Index support de la clé primaire sur "systeme"."T_Audit_Log". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX "T_Audit_Log_pkey" ON systeme."T_Audit_Log" USING btree ("IdLog").';


--
-- Name: INDEX "T_Entite_EmailEntite_key"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON INDEX systeme."T_Entite_EmailEntite_key" IS 'Index d’unicité sur "systeme"."T_Entite". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX "T_Entite_EmailEntite_key" ON systeme."T_Entite" USING btree ("EmailEntite").';


--
-- Name: INDEX "T_Entite_PhoneEntite_key"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON INDEX systeme."T_Entite_PhoneEntite_key" IS 'Index d’unicité sur "systeme"."T_Entite". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX "T_Entite_PhoneEntite_key" ON systeme."T_Entite" USING btree ("PhoneEntite").';


--
-- Name: INDEX "T_Fk_Correspondance_pkey"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON INDEX systeme."T_Fk_Correspondance_pkey" IS 'Index support de la clé primaire sur "systeme"."T_Fk_Correspondance". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX "T_Fk_Correspondance_pkey" ON systeme."T_Fk_Correspondance" USING btree ("IdFkCorrespondance").';


--
-- Name: INDEX "UQ_FkCorrespondance_SourceValueScope"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON INDEX systeme."UQ_FkCorrespondance_SourceValueScope" IS 'Index d’unicité sur "systeme"."T_Fk_Correspondance". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX "UQ_FkCorrespondance_SourceValueScope" ON systeme."T_Fk_Correspondance" USING btree ("ModuleName", "SchemaName", "ViewName", "SourceKey", "FieldName", "MappingType", "MappingValue", "SettingScope", "ScopeValue").';


--
-- Name: INDEX "Uq_Admin_UI_Setting_Key_Scope"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON INDEX systeme."Uq_Admin_UI_Setting_Key_Scope" IS 'Index d’unicité sur "systeme"."T_Admin_UI_Setting". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX "Uq_Admin_UI_Setting_Key_Scope" ON systeme."T_Admin_UI_Setting" USING btree ("SettingScope", "ScopeValue", "SettingKey").';


--
-- Name: idx_audit_changedat; Type: INDEX; Schema: systeme; Owner: -
--

CREATE INDEX idx_audit_changedat ON systeme."T_Audit_Log" USING btree ("ChangedAt" DESC);


--
-- Name: INDEX idx_audit_changedat; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON INDEX systeme.idx_audit_changedat IS 'Index d’accès sur "systeme"."T_Audit_Log". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_audit_changedat ON systeme."T_Audit_Log" USING btree ("ChangedAt" DESC).';


--
-- Name: idx_audit_log_entite; Type: INDEX; Schema: systeme; Owner: -
--

CREATE INDEX idx_audit_log_entite ON systeme."T_Audit_Log" USING btree ("IdEntiteFk");


--
-- Name: INDEX idx_audit_log_entite; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON INDEX systeme.idx_audit_log_entite IS 'Index d’accès sur "systeme"."T_Audit_Log". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_audit_log_entite ON systeme."T_Audit_Log" USING btree ("IdEntiteFk").';


--
-- Name: idx_entite_loc_coords; Type: INDEX; Schema: systeme; Owner: -
--

CREATE INDEX idx_entite_loc_coords ON systeme."T_Entite_Localisation" USING btree ("Latitude", "Longitude");


--
-- Name: INDEX idx_entite_loc_coords; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON INDEX systeme.idx_entite_loc_coords IS 'Index d’accès sur "systeme"."T_Entite_Localisation". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_entite_loc_coords ON systeme."T_Entite_Localisation" USING btree ("Latitude", "Longitude").';


--
-- Name: idx_entite_loc_entite; Type: INDEX; Schema: systeme; Owner: -
--

CREATE INDEX idx_entite_loc_entite ON systeme."T_Entite_Localisation" USING btree ("IdEntiteFk");


--
-- Name: INDEX idx_entite_loc_entite; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON INDEX systeme.idx_entite_loc_entite IS 'Index d’accès sur "systeme"."T_Entite_Localisation". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_entite_loc_entite ON systeme."T_Entite_Localisation" USING btree ("IdEntiteFk").';


--
-- Name: idx_entite_nom; Type: INDEX; Schema: systeme; Owner: -
--

CREATE INDEX idx_entite_nom ON systeme."T_Entite" USING btree ("NomEntite");


--
-- Name: INDEX idx_entite_nom; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON INDEX systeme.idx_entite_nom IS 'Index d’accès sur "systeme"."T_Entite". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_entite_nom ON systeme."T_Entite" USING btree ("NomEntite").';


--
-- Name: idx_fk_licence_entite; Type: INDEX; Schema: systeme; Owner: -
--

CREATE INDEX idx_fk_licence_entite ON systeme."T_Licence" USING btree ("IdEntiteFk") WITH (fillfactor='100', deduplicate_items='true');


--
-- Name: INDEX idx_fk_licence_entite; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON INDEX systeme.idx_fk_licence_entite IS 'Index d’accès sur "systeme"."T_Licence". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_fk_licence_entite ON systeme."T_Licence" USING btree ("IdEntiteFk") WITH (fillfactor=''100'', deduplicate_items=''true'').';


--
-- Name: idx_fk_licence_statut; Type: INDEX; Schema: systeme; Owner: -
--

CREATE INDEX idx_fk_licence_statut ON systeme."T_Licence" USING btree ("IdStatutLicenceFk") WITH (fillfactor='100', deduplicate_items='true');


--
-- Name: INDEX idx_fk_licence_statut; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON INDEX systeme.idx_fk_licence_statut IS 'Index d’accès sur "systeme"."T_Licence". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_fk_licence_statut ON systeme."T_Licence" USING btree ("IdStatutLicenceFk") WITH (fillfactor=''100'', deduplicate_items=''true'').';


--
-- Name: idx_fkcorrespondance_category; Type: INDEX; Schema: systeme; Owner: -
--

CREATE INDEX idx_fkcorrespondance_category ON systeme."T_Fk_Correspondance" USING btree ("TargetCategoryIdFk");


--
-- Name: INDEX idx_fkcorrespondance_category; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON INDEX systeme.idx_fkcorrespondance_category IS 'Index d’accès sur "systeme"."T_Fk_Correspondance". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_fkcorrespondance_category ON systeme."T_Fk_Correspondance" USING btree ("TargetCategoryIdFk").';


--
-- Name: idx_fkcorrespondance_scope; Type: INDEX; Schema: systeme; Owner: -
--

CREATE INDEX idx_fkcorrespondance_scope ON systeme."T_Fk_Correspondance" USING btree ("SettingScope", "ScopeValue");


--
-- Name: INDEX idx_fkcorrespondance_scope; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON INDEX systeme.idx_fkcorrespondance_scope IS 'Index d’accès sur "systeme"."T_Fk_Correspondance". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_fkcorrespondance_scope ON systeme."T_Fk_Correspondance" USING btree ("SettingScope", "ScopeValue").';


--
-- Name: idx_fkcorrespondance_source; Type: INDEX; Schema: systeme; Owner: -
--

CREATE INDEX idx_fkcorrespondance_source ON systeme."T_Fk_Correspondance" USING btree ("SchemaName", "ViewName", "SourceKey");


--
-- Name: INDEX idx_fkcorrespondance_source; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON INDEX systeme.idx_fkcorrespondance_source IS 'Index d’accès sur "systeme"."T_Fk_Correspondance". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_fkcorrespondance_source ON systeme."T_Fk_Correspondance" USING btree ("SchemaName", "ViewName", "SourceKey").';


--
-- Name: idx_fkcorrespondance_updatedby; Type: INDEX; Schema: systeme; Owner: -
--

CREATE INDEX idx_fkcorrespondance_updatedby ON systeme."T_Fk_Correspondance" USING btree ("UpdatedByUserFk");


--
-- Name: INDEX idx_fkcorrespondance_updatedby; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON INDEX systeme.idx_fkcorrespondance_updatedby IS 'Index d’accès sur "systeme"."T_Fk_Correspondance". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_fkcorrespondance_updatedby ON systeme."T_Fk_Correspondance" USING btree ("UpdatedByUserFk").';


--
-- Name: idx_login_entite; Type: INDEX; Schema: systeme; Owner: -
--

CREATE INDEX idx_login_entite ON systeme."T_Login" USING btree ("IdEntiteFk");


--
-- Name: INDEX idx_login_entite; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON INDEX systeme.idx_login_entite IS 'Index d’accès sur "systeme"."T_Login". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_login_entite ON systeme."T_Login" USING btree ("IdEntiteFk").';


--
-- Name: idx_login_type; Type: INDEX; Schema: systeme; Owner: -
--

CREATE INDEX idx_login_type ON systeme."T_Login" USING btree ("IdTypeLoginFk");


--
-- Name: INDEX idx_login_type; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON INDEX systeme.idx_login_type IS 'Index d’accès sur "systeme"."T_Login". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_login_type ON systeme."T_Login" USING btree ("IdTypeLoginFk").';


--
-- Name: idx_login_user_date; Type: INDEX; Schema: systeme; Owner: -
--

CREATE INDEX idx_login_user_date ON systeme."T_Login" USING btree ("IdUserFk", "DateLogin");


--
-- Name: INDEX idx_login_user_date; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON INDEX systeme.idx_login_user_date IS 'Index d’accès sur "systeme"."T_Login". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_login_user_date ON systeme."T_Login" USING btree ("IdUserFk", "DateLogin").';


--
-- Name: idx_user_entite; Type: INDEX; Schema: systeme; Owner: -
--

CREATE INDEX idx_user_entite ON systeme."T_Utilisateurs" USING btree ("IdEntiteFk");


--
-- Name: INDEX idx_user_entite; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON INDEX systeme.idx_user_entite IS 'Index d’accès sur "systeme"."T_Utilisateurs". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_user_entite ON systeme."T_Utilisateurs" USING btree ("IdEntiteFk").';


--
-- Name: idx_utilisateur_date_creation; Type: INDEX; Schema: systeme; Owner: -
--

CREATE INDEX idx_utilisateur_date_creation ON systeme."T_Utilisateurs" USING btree ("DatecreationUser") WITH (fillfactor='100', deduplicate_items='true');


--
-- Name: INDEX idx_utilisateur_date_creation; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON INDEX systeme.idx_utilisateur_date_creation IS 'Index d’accès sur "systeme"."T_Utilisateurs". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_utilisateur_date_creation ON systeme."T_Utilisateurs" USING btree ("DatecreationUser") WITH (fillfactor=''100'', deduplicate_items=''true'').';


--
-- Name: idx_utilisateur_nom; Type: INDEX; Schema: systeme; Owner: -
--

CREATE INDEX idx_utilisateur_nom ON systeme."T_Utilisateurs" USING btree ("NomUser", "PrenomUser") WITH (fillfactor='100', deduplicate_items='true');


--
-- Name: INDEX idx_utilisateur_nom; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON INDEX systeme.idx_utilisateur_nom IS 'Index d’accès sur "systeme"."T_Utilisateurs". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_utilisateur_nom ON systeme."T_Utilisateurs" USING btree ("NomUser", "PrenomUser") WITH (fillfactor=''100'', deduplicate_items=''true'').';


--
-- Name: idx_utilisateur_phone; Type: INDEX; Schema: systeme; Owner: -
--

CREATE INDEX idx_utilisateur_phone ON systeme."T_Utilisateurs" USING btree ("PhoneUser") WITH (fillfactor='100', deduplicate_items='true');


--
-- Name: INDEX idx_utilisateur_phone; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON INDEX systeme.idx_utilisateur_phone IS 'Index d’accès sur "systeme"."T_Utilisateurs". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_utilisateur_phone ON systeme."T_Utilisateurs" USING btree ("PhoneUser") WITH (fillfactor=''100'', deduplicate_items=''true'').';


--
-- Name: idx_utilisateur_role; Type: INDEX; Schema: systeme; Owner: -
--

CREATE INDEX idx_utilisateur_role ON systeme."T_Utilisateurs" USING btree ("IdRoleFk") WITH (fillfactor='100', deduplicate_items='true');


--
-- Name: INDEX idx_utilisateur_role; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON INDEX systeme.idx_utilisateur_role IS 'Index d’accès sur "systeme"."T_Utilisateurs". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_utilisateur_role ON systeme."T_Utilisateurs" USING btree ("IdRoleFk") WITH (fillfactor=''100'', deduplicate_items=''true'').';


--
-- Name: INDEX utilisateurs_emailuser_key; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON INDEX systeme.utilisateurs_emailuser_key IS 'Index d’unicité sur "systeme"."T_Utilisateurs". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX utilisateurs_emailuser_key ON systeme."T_Utilisateurs" USING btree ("EmailUser").';


--
-- Name: T_Admin_UI_Setting tr_admin_ui_setting_set_updated_at; Type: TRIGGER; Schema: systeme; Owner: -
--

CREATE TRIGGER tr_admin_ui_setting_set_updated_at BEFORE UPDATE ON systeme."T_Admin_UI_Setting" FOR EACH ROW EXECUTE FUNCTION systeme.fn_admin_ui_setting_set_updated_at();


--
-- Name: TRIGGER tr_admin_ui_setting_set_updated_at ON "T_Admin_UI_Setting"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON TRIGGER tr_admin_ui_setting_set_updated_at ON systeme."T_Admin_UI_Setting" IS 'BEFORE UPDATE sur "systeme"."T_Admin_UI_Setting", pour chaque ligne. Appelle "systeme"."fn_admin_ui_setting_set_updated_at" : Avant UPDATE d’un paramètre d’interface, remplace UpdatedAt par CURRENT_TIMESTAMP et renvoie NEW.';


--
-- Name: T_Login trigger_audit_T_Login; Type: TRIGGER; Schema: systeme; Owner: -
--

CREATE TRIGGER "trigger_audit_T_Login" AFTER INSERT OR DELETE OR UPDATE ON systeme."T_Login" FOR EACH ROW EXECUTE FUNCTION systeme.audit_log_function();


--
-- Name: TRIGGER "trigger_audit_T_Login" ON "T_Login"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON TRIGGER "trigger_audit_T_Login" ON systeme."T_Login" IS 'AFTER INSERT OR DELETE OR UPDATE sur "systeme"."T_Login", pour chaque ligne. Appelle "systeme"."audit_log_function" : Fonction de trigger AFTER enregistrant INSERT/UPDATE/DELETE dans T_Audit_Log avec TG_TABLE_NAME, états OLD/NEW complets et instant de modification. Tente de reprendre IdEntiteFk si la colonne est présente ; ne déduit pas l’auteur utilisateur.';


--
-- Name: T_Utilisateurs trigger_audit_T_Utilisateurs; Type: TRIGGER; Schema: systeme; Owner: -
--

CREATE TRIGGER "trigger_audit_T_Utilisateurs" AFTER INSERT OR DELETE OR UPDATE ON systeme."T_Utilisateurs" FOR EACH ROW EXECUTE FUNCTION systeme.audit_log_function();


--
-- Name: TRIGGER "trigger_audit_T_Utilisateurs" ON "T_Utilisateurs"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON TRIGGER "trigger_audit_T_Utilisateurs" ON systeme."T_Utilisateurs" IS 'AFTER INSERT OR DELETE OR UPDATE sur "systeme"."T_Utilisateurs", pour chaque ligne. Appelle "systeme"."audit_log_function" : Fonction de trigger AFTER enregistrant INSERT/UPDATE/DELETE dans T_Audit_Log avec TG_TABLE_NAME, états OLD/NEW complets et instant de modification. Tente de reprendre IdEntiteFk si la colonne est présente ; ne déduit pas l’auteur utilisateur.';


--
-- Name: T_Licence trigger_audit_log_T_Licence; Type: TRIGGER; Schema: systeme; Owner: -
--

CREATE TRIGGER "trigger_audit_log_T_Licence" AFTER INSERT OR DELETE OR UPDATE ON systeme."T_Licence" FOR EACH ROW EXECUTE FUNCTION systeme.audit_log_function();


--
-- Name: TRIGGER "trigger_audit_log_T_Licence" ON "T_Licence"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON TRIGGER "trigger_audit_log_T_Licence" ON systeme."T_Licence" IS 'AFTER INSERT OR DELETE OR UPDATE sur "systeme"."T_Licence", pour chaque ligne. Appelle "systeme"."audit_log_function" : Fonction de trigger AFTER enregistrant INSERT/UPDATE/DELETE dans T_Audit_Log avec TG_TABLE_NAME, états OLD/NEW complets et instant de modification. Tente de reprendre IdEntiteFk si la colonne est présente ; ne déduit pas l’auteur utilisateur.';


--
-- Name: T_Utilisateurs trigger_format_phone_number; Type: TRIGGER; Schema: systeme; Owner: -
--

CREATE TRIGGER trigger_format_phone_number BEFORE INSERT OR UPDATE ON systeme."T_Utilisateurs" FOR EACH ROW EXECUTE FUNCTION systeme.format_phone_number();


--
-- Name: TRIGGER trigger_format_phone_number ON "T_Utilisateurs"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON TRIGGER trigger_format_phone_number ON systeme."T_Utilisateurs" IS 'BEFORE INSERT OR UPDATE sur "systeme"."T_Utilisateurs", pour chaque ligne. Appelle "systeme"."format_phone_number" : Avant INSERT/UPDATE d’un utilisateur, retire de PhoneUser tous les caractères autres que les chiffres. Ne normalise pas le préfixe international ni la validité téléphonique.';


--
-- Name: T_Licence trigger_notify_licence_expiry; Type: TRIGGER; Schema: systeme; Owner: -
--

CREATE TRIGGER trigger_notify_licence_expiry AFTER INSERT OR UPDATE ON systeme."T_Licence" FOR EACH ROW EXECUTE FUNCTION systeme.notify_licence_expiry();


--
-- Name: TRIGGER trigger_notify_licence_expiry ON "T_Licence"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON TRIGGER trigger_notify_licence_expiry ON systeme."T_Licence" IS 'AFTER INSERT OR UPDATE sur "systeme"."T_Licence", pour chaque ligne. Appelle "systeme"."notify_licence_expiry" : Après INSERT/UPDATE de licence, crée une notification pour un administrateur d’entité si DATE_PART(day, DateFin - NOW()) vaut 7 et si destinataire/type Notification sont trouvés. Ce trigger n’est pas une tâche quotidienne et ne s’exécute pas du seul fait du passage du temps.';


--
-- Name: T_Licence trigger_prevent_multiple_licenses; Type: TRIGGER; Schema: systeme; Owner: -
--

CREATE TRIGGER trigger_prevent_multiple_licenses BEFORE INSERT OR UPDATE ON systeme."T_Licence" FOR EACH ROW EXECUTE FUNCTION systeme.prevent_multiple_active_licenses();


--
-- Name: TRIGGER trigger_prevent_multiple_licenses ON "T_Licence"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON TRIGGER trigger_prevent_multiple_licenses ON systeme."T_Licence" IS 'Contrôle des périodes concurrentes de licences valides après verrouillage de leur entité.';


--
-- Name: T_Utilisateurs trigger_prevention_delete_utilisateur; Type: TRIGGER; Schema: systeme; Owner: -
--

CREATE TRIGGER trigger_prevention_delete_utilisateur BEFORE DELETE ON systeme."T_Utilisateurs" FOR EACH ROW EXECUTE FUNCTION systeme.prevention_delete_if_dependent();


--
-- Name: TRIGGER trigger_prevention_delete_utilisateur ON "T_Utilisateurs"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON TRIGGER trigger_prevention_delete_utilisateur ON systeme."T_Utilisateurs" IS 'BEFORE DELETE sur "systeme"."T_Utilisateurs", pour chaque ligne. Appelle "systeme"."prevention_delete_if_dependent" : Avant DELETE utilisateur, bloque la suppression si des paiements liés par IdUserFk ou des présences/évaluations liées existent dans les tables que la fonction trouve. Ne couvre pas à elle seule toutes les dépendances : les contraintes FK restent applicables.';


--
-- Name: T_Utilisateurs trigger_update_date_modification; Type: TRIGGER; Schema: systeme; Owner: -
--

CREATE TRIGGER trigger_update_date_modification BEFORE UPDATE ON systeme."T_Utilisateurs" FOR EACH ROW EXECUTE FUNCTION systeme.update_date_modification();


--
-- Name: TRIGGER trigger_update_date_modification ON "T_Utilisateurs"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON TRIGGER trigger_update_date_modification ON systeme."T_Utilisateurs" IS 'BEFORE UPDATE sur "systeme"."T_Utilisateurs", pour chaque ligne. Appelle "systeme"."update_date_modification" : Avant UPDATE utilisateur, remplace DateModificationUser par NOW() et renvoie NEW.';


--
-- Name: T_Licence trigger_update_licence_status; Type: TRIGGER; Schema: systeme; Owner: -
--

CREATE TRIGGER trigger_update_licence_status BEFORE INSERT OR UPDATE ON systeme."T_Licence" FOR EACH ROW EXECUTE FUNCTION systeme.update_licence_status();


--
-- Name: TRIGGER trigger_update_licence_status ON "T_Licence"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON TRIGGER trigger_update_licence_status ON systeme."T_Licence" IS 'BEFORE INSERT OR UPDATE sur "systeme"."T_Licence", pour chaque ligne. Appelle "systeme"."update_licence_status" : Avant INSERT/UPDATE de licence, fixe ExpireeLicence selon DateFin < NOW() ; une date NULL suit la branche false. Aucun recalcul périodique indépendant d’une écriture.';


--
-- Name: T_Admin_UI_Setting Fk_Admin_UI_Setting_User; Type: FK CONSTRAINT; Schema: systeme; Owner: -
--

ALTER TABLE ONLY systeme."T_Admin_UI_Setting"
    ADD CONSTRAINT "Fk_Admin_UI_Setting_User" FOREIGN KEY ("UpdatedByUserFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: CONSTRAINT "Fk_Admin_UI_Setting_User" ON "T_Admin_UI_Setting"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "Fk_Admin_UI_Setting_User" ON systeme."T_Admin_UI_Setting" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "systeme"."T_Admin_UI_Setting". Définition : FOREIGN KEY ("UpdatedByUserFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE ON DELETE SET NULL.';


--
-- Name: T_Entite_Localisation Fk_EL_Entite; Type: FK CONSTRAINT; Schema: systeme; Owner: -
--

ALTER TABLE ONLY systeme."T_Entite_Localisation"
    ADD CONSTRAINT "Fk_EL_Entite" FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: CONSTRAINT "Fk_EL_Entite" ON "T_Entite_Localisation"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "Fk_EL_Entite" ON systeme."T_Entite_Localisation" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "systeme"."T_Entite_Localisation". Définition : FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON UPDATE CASCADE ON DELETE CASCADE.';


--
-- Name: T_Entite_Localisation Fk_EL_N3; Type: FK CONSTRAINT; Schema: systeme; Owner: -
--

ALTER TABLE ONLY systeme."T_Entite_Localisation"
    ADD CONSTRAINT "Fk_EL_N3" FOREIGN KEY ("IdNiveau_3_Fk") REFERENCES geolocalisation."T_Niveau_3"("ID_Niveau_3");


--
-- Name: CONSTRAINT "Fk_EL_N3" ON "T_Entite_Localisation"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "Fk_EL_N3" ON systeme."T_Entite_Localisation" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "systeme"."T_Entite_Localisation". Définition : FOREIGN KEY ("IdNiveau_3_Fk") REFERENCES geolocalisation."T_Niveau_3"("ID_Niveau_3").';


--
-- Name: T_Entite_Localisation Fk_EL_N4; Type: FK CONSTRAINT; Schema: systeme; Owner: -
--

ALTER TABLE ONLY systeme."T_Entite_Localisation"
    ADD CONSTRAINT "Fk_EL_N4" FOREIGN KEY ("IdNiveau_4_Fk") REFERENCES geolocalisation."T_Niveau_4"("ID_Niveau_4");


--
-- Name: CONSTRAINT "Fk_EL_N4" ON "T_Entite_Localisation"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "Fk_EL_N4" ON systeme."T_Entite_Localisation" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "systeme"."T_Entite_Localisation". Définition : FOREIGN KEY ("IdNiveau_4_Fk") REFERENCES geolocalisation."T_Niveau_4"("ID_Niveau_4").';


--
-- Name: T_Entite_Localisation Fk_EL_N5; Type: FK CONSTRAINT; Schema: systeme; Owner: -
--

ALTER TABLE ONLY systeme."T_Entite_Localisation"
    ADD CONSTRAINT "Fk_EL_N5" FOREIGN KEY ("IdNiveau_5_Fk") REFERENCES geolocalisation."T_Niveau_5"("ID_Niveau_5");


--
-- Name: CONSTRAINT "Fk_EL_N5" ON "T_Entite_Localisation"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "Fk_EL_N5" ON systeme."T_Entite_Localisation" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "systeme"."T_Entite_Localisation". Définition : FOREIGN KEY ("IdNiveau_5_Fk") REFERENCES geolocalisation."T_Niveau_5"("ID_Niveau_5").';


--
-- Name: T_Licence Fk_Entite; Type: FK CONSTRAINT; Schema: systeme; Owner: -
--

ALTER TABLE ONLY systeme."T_Licence"
    ADD CONSTRAINT "Fk_Entite" FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON UPDATE CASCADE;


--
-- Name: CONSTRAINT "Fk_Entite" ON "T_Licence"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "Fk_Entite" ON systeme."T_Licence" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "systeme"."T_Licence". Définition : FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON UPDATE CASCADE.';


--
-- Name: T_Fk_Correspondance Fk_FkCorrespondance_Category; Type: FK CONSTRAINT; Schema: systeme; Owner: -
--

ALTER TABLE ONLY systeme."T_Fk_Correspondance"
    ADD CONSTRAINT "Fk_FkCorrespondance_Category" FOREIGN KEY ("TargetCategoryIdFk") REFERENCES referentiel."T_CategorieGenerique"("ID_CategorieGenerique") ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: CONSTRAINT "Fk_FkCorrespondance_Category" ON "T_Fk_Correspondance"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "Fk_FkCorrespondance_Category" ON systeme."T_Fk_Correspondance" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "systeme"."T_Fk_Correspondance". Définition : FOREIGN KEY ("TargetCategoryIdFk") REFERENCES referentiel."T_CategorieGenerique"("ID_CategorieGenerique") ON UPDATE CASCADE ON DELETE SET NULL.';


--
-- Name: T_Fk_Correspondance Fk_FkCorrespondance_User; Type: FK CONSTRAINT; Schema: systeme; Owner: -
--

ALTER TABLE ONLY systeme."T_Fk_Correspondance"
    ADD CONSTRAINT "Fk_FkCorrespondance_User" FOREIGN KEY ("UpdatedByUserFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: CONSTRAINT "Fk_FkCorrespondance_User" ON "T_Fk_Correspondance"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "Fk_FkCorrespondance_User" ON systeme."T_Fk_Correspondance" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "systeme"."T_Fk_Correspondance". Définition : FOREIGN KEY ("UpdatedByUserFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE ON DELETE SET NULL.';


--
-- Name: T_Audit_Log Fk_IdEntite; Type: FK CONSTRAINT; Schema: systeme; Owner: -
--

ALTER TABLE ONLY systeme."T_Audit_Log"
    ADD CONSTRAINT "Fk_IdEntite" FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: CONSTRAINT "Fk_IdEntite" ON "T_Audit_Log"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "Fk_IdEntite" ON systeme."T_Audit_Log" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "systeme"."T_Audit_Log". Définition : FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON UPDATE CASCADE ON DELETE SET NULL.';


--
-- Name: T_Login Fk_IdEntite; Type: FK CONSTRAINT; Schema: systeme; Owner: -
--

ALTER TABLE ONLY systeme."T_Login"
    ADD CONSTRAINT "Fk_IdEntite" FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: CONSTRAINT "Fk_IdEntite" ON "T_Login"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "Fk_IdEntite" ON systeme."T_Login" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "systeme"."T_Login". Définition : FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON UPDATE CASCADE ON DELETE SET NULL.';


--
-- Name: T_Utilisateurs Fk_IdEntite; Type: FK CONSTRAINT; Schema: systeme; Owner: -
--

ALTER TABLE ONLY systeme."T_Utilisateurs"
    ADD CONSTRAINT "Fk_IdEntite" FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: CONSTRAINT "Fk_IdEntite" ON "T_Utilisateurs"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "Fk_IdEntite" ON systeme."T_Utilisateurs" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "systeme"."T_Utilisateurs". Définition : FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON UPDATE CASCADE ON DELETE SET NULL.';


--
-- Name: T_Login Fk_IdTypeLogin; Type: FK CONSTRAINT; Schema: systeme; Owner: -
--

ALTER TABLE ONLY systeme."T_Login"
    ADD CONSTRAINT "Fk_IdTypeLogin" FOREIGN KEY ("IdTypeLoginFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE;


--
-- Name: CONSTRAINT "Fk_IdTypeLogin" ON "T_Login"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "Fk_IdTypeLogin" ON systeme."T_Login" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "systeme"."T_Login". Définition : FOREIGN KEY ("IdTypeLoginFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE.';


--
-- Name: T_Login Fk_IdUserFk; Type: FK CONSTRAINT; Schema: systeme; Owner: -
--

ALTER TABLE ONLY systeme."T_Login"
    ADD CONSTRAINT "Fk_IdUserFk" FOREIGN KEY ("IdUserFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE;


--
-- Name: CONSTRAINT "Fk_IdUserFk" ON "T_Login"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "Fk_IdUserFk" ON systeme."T_Login" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "systeme"."T_Login". Définition : FOREIGN KEY ("IdUserFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON UPDATE CASCADE.';


--
-- Name: T_Utilisateurs Fk_RoleFk; Type: FK CONSTRAINT; Schema: systeme; Owner: -
--

ALTER TABLE ONLY systeme."T_Utilisateurs"
    ADD CONSTRAINT "Fk_RoleFk" FOREIGN KEY ("IdRoleFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: CONSTRAINT "Fk_RoleFk" ON "T_Utilisateurs"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "Fk_RoleFk" ON systeme."T_Utilisateurs" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "systeme"."T_Utilisateurs". Définition : FOREIGN KEY ("IdRoleFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE ON DELETE SET NULL.';


--
-- Name: T_Licence Fk_StatutLicence; Type: FK CONSTRAINT; Schema: systeme; Owner: -
--

ALTER TABLE ONLY systeme."T_Licence"
    ADD CONSTRAINT "Fk_StatutLicence" FOREIGN KEY ("IdStatutLicenceFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE;


--
-- Name: CONSTRAINT "Fk_StatutLicence" ON "T_Licence"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "Fk_StatutLicence" ON systeme."T_Licence" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "systeme"."T_Licence". Définition : FOREIGN KEY ("IdStatutLicenceFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE.';


--
-- Name: T_Entite Fk_TypeEntite; Type: FK CONSTRAINT; Schema: systeme; Owner: -
--

ALTER TABLE ONLY systeme."T_Entite"
    ADD CONSTRAINT "Fk_TypeEntite" FOREIGN KEY ("IdTypeEntiteFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: CONSTRAINT "Fk_TypeEntite" ON "T_Entite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "Fk_TypeEntite" ON systeme."T_Entite" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "systeme"."T_Entite". Définition : FOREIGN KEY ("IdTypeEntiteFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON UPDATE CASCADE ON DELETE SET NULL.';


--
-- PostgreSQL database dump complete
--
