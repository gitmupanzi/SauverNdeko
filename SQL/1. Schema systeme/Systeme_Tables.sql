-- Extrait canonique du catalogue vérifié le 02/11/2026, sans données ni propriétaires imposés.
-- Voir SQL/README.md. Ces extraits documentent le domaine ; utiliser le fichier global pour une installation vide.
SET check_function_bodies = false;
SELECT pg_catalog.set_config('search_path', '', false);
CREATE SCHEMA IF NOT EXISTS "systeme";
--
-- Name: SCHEMA systeme; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA systeme IS 'Comptes, entités, localisations, licences, connexions, audit et paramètres partagés de l’administration.';

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
-- Name: fn_admin_actor_user_id(); Type: FUNCTION; Schema: systeme; Owner: -
--

CREATE FUNCTION systeme.fn_admin_actor_user_id() RETURNS integer
    LANGUAGE plpgsql STABLE
    AS $_$
DECLARE v_raw text:=nullif(current_setting('systeme.actor_user_id',true),''); v_id integer;
BEGIN
 IF v_raw IS NULL OR v_raw !~ '^[1-9][0-9]{0,9}$' THEN RETURN NULL; END IF;
 BEGIN v_id:=v_raw::integer;
 EXCEPTION WHEN numeric_value_out_of_range THEN RETURN NULL; END;
 IF EXISTS (SELECT 1 FROM systeme."T_Utilisateurs"
            WHERE "IdUser"=v_id AND "ValideUser" IS TRUE) THEN RETURN v_id; END IF;
 RETURN NULL;
END $_$;

--
-- Name: FUNCTION fn_admin_actor_user_id(); Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON FUNCTION systeme.fn_admin_actor_user_id() IS 'Auteur actif existant de la GUC transactionnelle systeme.actor_user_id ; NULL si absence ou valeur invalide. Métadonnée de traçabilité, jamais autorisation SQL.';

--
-- Name: fn_admin_cle_sensible(text); Type: FUNCTION; Schema: systeme; Owner: -
--

CREATE FUNCTION systeme.fn_admin_cle_sensible(p_cle text) RETURNS boolean
    LANGUAGE sql IMMUTABLE PARALLEL SAFE
    AS $_$
 SELECT CASE WHEN p_cle IS NULL THEN false ELSE
  regexp_replace(lower(p_cle),'[^a-z0-9]','','g') ~
  '(password|motdepasse|privatekey|apikey|accesstoken|refreshtoken|idtoken|secret$)'
  OR regexp_replace(lower(p_cle),'[^a-z0-9]','','g') IN
   ('token','authorization','credential','credentials') END;
$_$;

--
-- Name: FUNCTION fn_admin_cle_sensible(p_cle text); Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON FUNCTION systeme.fn_admin_cle_sensible(p_cle text) IS 'Détecte les noms de mots de passe, jetons et secrets sans dépendre de la casse ni des séparateurs.';

--
-- Name: fn_admin_reglage_audit(); Type: FUNCTION; Schema: systeme; Owner: -
--

CREATE FUNCTION systeme.fn_admin_reglage_audit() RETURNS trigger
    LANGUAGE plpgsql
    AS $_$
DECLARE v_before jsonb; v_after jsonb; v_actor integer:=systeme.fn_admin_actor_user_id();
        v_identity jsonb:=jsonb_build_object('IdUser',NULL,'NomComplet',NULL);
        v_scope text; v_scope_value text; v_entity integer;
BEGIN
 IF v_actor IS NOT NULL THEN
  SELECT jsonb_build_object('IdUser',"IdUser",'NomComplet',
         concat_ws(' ',"PrenomUser","NomUser")) INTO v_identity
   FROM systeme."T_Utilisateurs" WHERE "IdUser"=v_actor;
 END IF;
 IF TG_OP IN ('DELETE','UPDATE') THEN
  v_before:=systeme.fn_audit_sans_secrets(to_jsonb(OLD));
  IF v_identity IS NOT NULL THEN v_before:=v_before||jsonb_build_object('_actor',v_identity); END IF;
 END IF;
 IF TG_OP IN ('INSERT','UPDATE') THEN
  v_after:=systeme.fn_audit_sans_secrets(to_jsonb(NEW));
  IF v_identity IS NOT NULL THEN v_after:=v_after||jsonb_build_object('_actor',v_identity); END IF;
 END IF;
 v_scope:=coalesce(v_after->>'SettingScope',v_before->>'SettingScope');
 v_scope_value:=coalesce(v_after->>'ScopeValue',v_before->>'ScopeValue');
 IF v_scope IN ('entity','entite') AND v_scope_value ~ '^[1-9][0-9]{0,9}$' THEN
  BEGIN v_entity:=v_scope_value::integer;
  EXCEPTION WHEN numeric_value_out_of_range THEN v_entity:=NULL; END;
  IF NOT EXISTS(SELECT 1 FROM systeme."T_Entite" WHERE "IdEntite"=v_entity) THEN v_entity:=NULL; END IF;
 END IF;
 INSERT INTO systeme."T_Audit_Log"("TableName","Operation","OldData","NewData","ChangedAt","IdEntiteFk")
 VALUES(TG_TABLE_NAME,TG_OP,v_before,v_after,CURRENT_TIMESTAMP AT TIME ZONE 'Africa/Kinshasa',v_entity);
 RETURN NULL;
END $_$;

--
-- Name: FUNCTION fn_admin_reglage_audit(); Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON FUNCTION systeme.fn_admin_reglage_audit() IS 'Un événement SQL par écriture de réglage ou correspondance, avec images nettoyées et auteur de l’opération, y compris suppression.';

--
-- Name: fn_admin_ui_setting_proteger(); Type: FUNCTION; Schema: systeme; Owner: -
--

CREATE FUNCTION systeme.fn_admin_ui_setting_proteger() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
 IF TG_OP='DELETE' THEN
  IF OLD."IsEditable" IS NOT TRUE OR OLD."IsSystem" IS TRUE THEN
   RAISE EXCEPTION 'Ce paramètre ne peut pas être supprimé' USING ERRCODE='23514';
  END IF;
  RETURN OLD;
 END IF;
 IF OLD."IsEditable" IS NOT TRUE AND
  (to_jsonb(NEW)-ARRAY['UpdatedAt','UpdatedByUserFk']) IS DISTINCT FROM
  (to_jsonb(OLD)-ARRAY['UpdatedAt','UpdatedByUserFk']) THEN
  RAISE EXCEPTION 'Ce paramètre est protégé contre les modifications' USING ERRCODE='23514';
 END IF;
 IF OLD."IsSystem" IS TRUE AND
  ROW(NEW."IdAdminUISetting",NEW."SettingKey",NEW."SettingType",NEW."SettingScope",
      NEW."ScopeValue",NEW."IsEditable",NEW."IsSystem",NEW."CreatedAt") IS DISTINCT FROM
  ROW(OLD."IdAdminUISetting",OLD."SettingKey",OLD."SettingType",OLD."SettingScope",
      OLD."ScopeValue",OLD."IsEditable",OLD."IsSystem",OLD."CreatedAt") THEN
  RAISE EXCEPTION 'Identité et protections du paramètre système immuables' USING ERRCODE='23514';
 END IF;
 RETURN NEW;
END $$;

--
-- Name: FUNCTION fn_admin_ui_setting_proteger(); Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON FUNCTION systeme.fn_admin_ui_setting_proteger() IS 'Refuse les modifications d’un paramètre non éditable et la suppression/altération d’identité d’un paramètre système ; sa valeur reste modifiable si IsEditable=true.';

--
-- Name: fn_admin_ui_setting_set_updated_at(); Type: FUNCTION; Schema: systeme; Owner: -
--

CREATE FUNCTION systeme.fn_admin_ui_setting_set_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
 NEW."UpdatedAt":=CURRENT_TIMESTAMP;
 NEW."UpdatedByUserFk":=systeme.fn_admin_actor_user_id();
 IF TG_OP='INSERT' THEN NEW."CreatedAt":=CURRENT_TIMESTAMP;
 ELSE NEW."CreatedAt":=OLD."CreatedAt"; END IF;
 RETURN NEW;
END $$;

--
-- Name: FUNCTION fn_admin_ui_setting_set_updated_at(); Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON FUNCTION systeme.fn_admin_ui_setting_set_updated_at() IS 'Horodate et attribue les paramètres à l’auteur transactionnel validé ; conserve CreatedAt après création.';

--
-- Name: fn_audit_sans_secrets(jsonb); Type: FUNCTION; Schema: systeme; Owner: -
--

CREATE FUNCTION systeme.fn_audit_sans_secrets(p_data jsonb) RETURNS jsonb
    LANGUAGE plpgsql IMMUTABLE PARALLEL SAFE
    AS $$
DECLARE v_type text;v_result jsonb;v_key text;v_value jsonb;v_setting_secret boolean:=false;v_decoded jsonb;v_string text;
BEGIN
 IF p_data IS NULL THEN RETURN NULL;END IF;
 v_type:=jsonb_typeof(p_data);
 IF v_type='object' THEN
  SELECT coalesce(bool_or(systeme.fn_admin_cle_sensible(value#>>'{}')),false) INTO v_setting_secret FROM jsonb_each(p_data) WHERE regexp_replace(lower(key),'[^a-z0-9]','','g')='settingkey';
  v_result:='{}'::jsonb;
  FOR v_key,v_value IN SELECT key,value FROM jsonb_each(p_data) LOOP
   IF systeme.fn_admin_cle_sensible(v_key) OR regexp_replace(lower(v_key),'[^a-z0-9]','','g')='logoentite' THEN CONTINUE;END IF;
   IF v_setting_secret AND regexp_replace(lower(v_key),'[^a-z0-9]','','g') IN ('settingvalue','settingvaluejson') THEN v_result:=v_result||jsonb_build_object(v_key,'[Masqué]');
   ELSE v_result:=v_result||jsonb_build_object(v_key,systeme.fn_audit_sans_secrets(v_value));END IF;
  END LOOP;
  RETURN v_result;
 ELSIF v_type='array' THEN
  SELECT coalesce(jsonb_agg(systeme.fn_audit_sans_secrets(value) ORDER BY ord),'[]'::jsonb) INTO v_result FROM jsonb_array_elements(p_data) WITH ORDINALITY AS a(value,ord);RETURN v_result;
 ELSIF v_type='string' THEN
  v_string:=btrim(p_data#>>'{}');
  IF left(v_string,1) IN ('{','[') THEN
   BEGIN v_decoded:=v_string::jsonb;EXCEPTION WHEN invalid_text_representation THEN RETURN p_data;END;
   RETURN systeme.fn_audit_sans_secrets(v_decoded);
  END IF;
 END IF;
 RETURN p_data;
END $$;

--
-- Name: FUNCTION fn_audit_sans_secrets(p_data jsonb); Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON FUNCTION systeme.fn_audit_sans_secrets(p_data jsonb) IS 'Nettoie récursivement secrets, anciennes images JSON encodées et octets LogoEntite ; conserve les métadonnées de logo comme SHA/MIME/date. N’effectue aucune réécriture des journaux antérieurs.';

--
-- Name: fn_fk_correspondance_actualiser(); Type: FUNCTION; Schema: systeme; Owner: -
--

CREATE FUNCTION systeme.fn_fk_correspondance_actualiser() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
 -- Le type existant reste timestamp sans fuseau ; heure civile métier de Kinshasa.
 NEW."UpdatedAt":=CURRENT_TIMESTAMP AT TIME ZONE 'Africa/Kinshasa';
 NEW."UpdatedByUserFk":=systeme.fn_admin_actor_user_id();
 RETURN NEW;
END $$;

--
-- Name: FUNCTION fn_fk_correspondance_actualiser(); Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON FUNCTION systeme.fn_fk_correspondance_actualiser() IS 'Actualise la date civile de Kinshasa et l’auteur transactionnel de chaque correspondance écrite.';

--
-- Name: fn_identifiants_legaux_valides(jsonb); Type: FUNCTION; Schema: systeme; Owner: -
--

CREATE FUNCTION systeme.fn_identifiants_legaux_valides(p_value jsonb) RETURNS boolean
    LANGUAGE plpgsql IMMUTABLE
    SET search_path TO 'pg_catalog'
    AS $$
DECLARE item jsonb; labels text[]:='{}'; label text; value text;
BEGIN
 IF p_value IS NULL OR jsonb_typeof(p_value)<>'array' THEN RETURN false; END IF;
 IF jsonb_array_length(p_value)>10 THEN RETURN false; END IF;
 FOR item IN SELECT jsonb_array_elements(p_value) LOOP
  IF jsonb_typeof(item)<>'object' OR (SELECT count(*) FROM jsonb_object_keys(item))<>2
     OR NOT item ?& ARRAY['libelle','valeur'] THEN RETURN false; END IF;
  IF jsonb_typeof(item->'libelle')<>'string' OR jsonb_typeof(item->'valeur')<>'string' THEN RETURN false; END IF;
  label:=item->>'libelle'; value:=item->>'valeur';
  IF char_length(btrim(label)) NOT BETWEEN 1 AND 60 OR char_length(btrim(value)) NOT BETWEEN 1 AND 180
     OR label ~ '[[:cntrl:]]' OR value ~ '[[:cntrl:]]' THEN RETURN false; END IF;
  IF lower(btrim(label))=ANY(labels) THEN RETURN false; END IF;
  labels:=array_append(labels,lower(btrim(label)));
 END LOOP;
 RETURN true;
END $$;

--
-- Name: FUNCTION fn_identifiants_legaux_valides(p_value jsonb); Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON FUNCTION systeme.fn_identifiants_legaux_valides(p_value jsonb) IS 'Contrôle la structure, les longueurs, les libellés uniques et les caractères de contrôle des identifiants déclaratifs, y compris en SQL direct.';

--
-- Name: fn_identite_documentaire(integer); Type: FUNCTION; Schema: systeme; Owner: -
--

CREATE FUNCTION systeme.fn_identite_documentaire(p_entite integer) RETURNS jsonb
    LANGUAGE sql STABLE
    SET search_path TO 'pg_catalog'
    AS $$
 SELECT jsonb_build_object('IdEntite',"IdEntite",'NomEntite',"NomEntite",'AdresseEntite',"AdresseEntite",
  'EmailEntite',"EmailEntite",'PhoneEntite',"PhoneEntite",'IdentifiantsLegauxEntite',"IdentifiantsLegauxEntite",'MentionDocumentaireEntite',"MentionDocumentaireEntite",
  'SiteWebEntite',"SiteWebEntite",'AfficherEnteteDocument',"AfficherEnteteDocument",'AfficherPiedDocument',"AfficherPiedDocument",
  'HasLogo',"LogoEntite" IS NOT NULL,'LogoMimeEntite',"LogoMimeEntite",'LogoSha256Entite',"LogoSha256Entite",'LogoModifieLe',"LogoModifieLe",'PhoneSecondaireEntite',"PhoneSecondaireEntite")
 FROM systeme."T_Entite" WHERE "IdEntite"=p_entite
$$;

--
-- Name: FUNCTION fn_identite_documentaire(p_entite integer); Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON FUNCTION systeme.fn_identite_documentaire(p_entite integer) IS 'Identité de présentation courante et métadonnées du logo, sans octets binaires. Source des PDF à la demande du propriétaire ; les instantanés financiers et identités antérieurs restent immuables et ne sont pas réécrits.';

--
-- Name: fn_support_circuit(integer); Type: FUNCTION; Schema: systeme; Owner: -
--

CREATE FUNCTION systeme.fn_support_circuit(p_entite integer) RETURNS jsonb
    LANGUAGE plpgsql STABLE
    SET search_path TO 'pg_catalog'
    AS $$
DECLARE r systeme."T_Admin_UI_Setting";
BEGIN
 SELECT * INTO r FROM systeme."T_Admin_UI_Setting" WHERE "SettingKey"='support.workflow' AND "ValideSetting" AND (("SettingScope"='entite' AND "ScopeValue"=p_entite::text) OR ("SettingScope"='global' AND "ScopeValue" IS NULL)) ORDER BY CASE WHEN "SettingScope"='entite' THEN 0 ELSE 1 END LIMIT 1;
 IF NOT FOUND OR r."SettingType"<>'json' OR jsonb_typeof(r."SettingValueJson") IS DISTINCT FROM 'object' THEN RAISE EXCEPTION 'Circuit de traitement Support indisponible.' USING ERRCODE='23514';END IF;
 RETURN r."SettingValueJson"||jsonb_build_object('settingId',r."IdAdminUISetting",'settingUpdatedAt',r."UpdatedAt");
END $$;

--
-- Name: FUNCTION fn_support_circuit(p_entite integer); Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON FUNCTION systeme.fn_support_circuit(p_entite integer) IS 'Résout le circuit Support dans les paramètres système existants, entreprise puis global ; ne crée aucune configuration parallèle et capture sa version lors de la création.';

--
-- Name: fn_support_circuit_defaut(); Type: FUNCTION; Schema: systeme; Owner: -
--

CREATE FUNCTION systeme.fn_support_circuit_defaut() RETURNS jsonb
    LANGUAGE plpgsql STABLE
    SET search_path TO 'pg_catalog'
    AS $$
DECLARE states jsonb;verification jsonb;family integer;
BEGIN
 SELECT "ID_CategorieDefautFk" INTO family FROM referentiel."T_ChampReferentiel" WHERE "SchemaName"='support' AND "TableName"='T_Support' AND "ColumnName"='ID_StatutFk';
 SELECT jsonb_object_agg(replace("AbrGenerique",'support.status.',''),"ID_Generique") INTO states FROM referentiel."T_Generique" WHERE "ID_CategorieGeneriqueFk"=family AND "IdEntiteFk" IS NULL AND "ValideGenerique" AND "AbrGenerique" IN('support.status.new','support.status.active','support.status.pending','support.status.resolved','support.status.closed');
 SELECT "ID_CategorieDefautFk" INTO family FROM referentiel."T_ChampReferentiel" WHERE "SchemaName"='support' AND "TableName"='T_ResolutionSupport' AND "ColumnName"='ID_ResultatVerificationFk';
 SELECT jsonb_object_agg(CASE "AbrGenerique" WHEN 'support.verify.ok' THEN 'accepted' ELSE 'rejected' END,"ID_Generique") INTO verification FROM referentiel."T_Generique" WHERE "ID_CategorieGeneriqueFk"=family AND "IdEntiteFk" IS NULL AND "ValideGenerique" AND "AbrGenerique" IN('support.verify.ok','support.verify.ko');
 IF NOT (coalesce(states,'{}') ?& ARRAY['new','active','pending','resolved','closed']) OR NOT (coalesce(verification,'{}') ?& ARRAY['accepted','rejected']) THEN RAISE EXCEPTION 'Dictionnaire de circuit Support incomplet.' USING ERRCODE='23514';END IF;
 RETURN jsonb_build_object('version',1,'states',states,'verification',verification,'transitions','[{"from":"new","to":"active","action":"start"},{"from":"active","to":"pending","action":"pause"},{"from":"pending","to":"active","action":"resume"},{"from":"active","to":"resolved","action":"resolve"},{"from":"pending","to":"resolved","action":"resolve"},{"from":"resolved","to":"closed","action":"close"},{"from":"resolved","to":"active","action":"reopen"},{"from":"closed","to":"active","action":"reopen"}]'::jsonb);
END $$;

--
-- Name: FUNCTION fn_support_circuit_defaut(); Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON FUNCTION systeme.fn_support_circuit_defaut() IS 'Circuit initial fermé d’installation : résout les identifiants du dictionnaire commun par codes sémantiques et familles du catalogue ; ne transporte aucune surcharge, auteur ou valeur de configuration client.';

--
-- Name: fn_support_object_size(jsonb); Type: FUNCTION; Schema: systeme; Owner: -
--

CREATE FUNCTION systeme.fn_support_object_size(p_value jsonb) RETURNS integer
    LANGUAGE sql IMMUTABLE STRICT
    AS $$SELECT count(*)::integer FROM jsonb_object_keys(p_value)$$;

--
-- Name: FUNCTION fn_support_object_size(p_value jsonb); Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON FUNCTION systeme.fn_support_object_size(p_value jsonb) IS 'Nombre de propriétés d’un objet JSON du circuit, sans extension ni identifiant métier codé en dur.';

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
-- Name: tr_correspondance_categorie_portee(); Type: FUNCTION; Schema: systeme; Owner: -
--

CREATE FUNCTION systeme.tr_correspondance_categorie_portee() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$
DECLARE cible_entite integer;
BEGIN
 IF NEW."MappingType"<>'generic_category' OR NEW."TargetCategoryIdFk" IS NULL THEN RETURN NEW;END IF;
 SELECT "IdEntiteFk" INTO cible_entite FROM referentiel."T_CategorieGenerique" WHERE "ID_CategorieGenerique"=NEW."TargetCategoryIdFk" FOR SHARE;
 IF cible_entite IS NOT NULL AND (NEW."SettingScope"<>'entity' OR NEW."ScopeValue" IS DISTINCT FROM cible_entite::text
  OR EXISTS(SELECT FROM referentiel."T_ChampReferentiel" c WHERE NOT c."SupportsEntityScope" AND
   (c."ID_ChampReferentiel"=NEW."IdChampReferentielFk" OR NEW."SourceKey"=ANY(c."AliasSourceKeys")))) THEN
  RAISE EXCEPTION 'Une catégorie privée exige le champ et la portée de son entreprise.' USING ERRCODE='23514',CONSTRAINT='ck_correspondance_categorie_portee';END IF;
 RETURN NEW;
END $$;

--
-- Name: FUNCTION tr_correspondance_categorie_portee(); Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON FUNCTION systeme.tr_correspondance_categorie_portee() IS 'Une famille privée ne peut configurer que son entreprise et un champ supportant réellement ce contexte ; protège aussi les anciens alias sans modifier leur résolution.';

--
-- Name: tr_correspondance_champ_integrite(); Type: FUNCTION; Schema: systeme; Owner: -
--

CREATE FUNCTION systeme.tr_correspondance_champ_integrite() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $_$
DECLARE row_data jsonb; r referentiel."T_ChampReferentiel"; cat integer;
BEGIN
 row_data:=CASE WHEN TG_OP='DELETE' THEN to_jsonb(OLD) ELSE to_jsonb(NEW) END;
 IF (row_data->>'IdChampReferentielFk') IS NULL THEN
  PERFORM 1 FROM referentiel."T_ChampReferentiel" c WHERE row_data->>'SourceKey'=ANY(c."AliasSourceKeys") ORDER BY c."ID_ChampReferentiel" FOR UPDATE;
  IF row_data->>'SourceKey' LIKE 'champ.%' THEN RAISE EXCEPTION 'Identité de champ canonique obligatoire' USING ERRCODE='23514';END IF;
  IF EXISTS(SELECT FROM referentiel."T_ChampReferentiel" c WHERE NOT c."CanConfigure" AND row_data->>'SourceKey'=ANY(c."AliasSourceKeys") AND (row_data->>'TargetCategoryIdFk')::integer IS DISTINCT FROM c."ID_CategorieDefautFk") THEN
   RAISE EXCEPTION 'Famille de sécurité protégée.' USING ERRCODE='23514';END IF;
  RETURN CASE WHEN TG_OP='DELETE' THEN OLD ELSE NEW END;
 END IF;
 SELECT * INTO r FROM referentiel."T_ChampReferentiel" WHERE "ID_ChampReferentiel"=(row_data->>'IdChampReferentielFk')::integer FOR UPDATE;
 IF NOT FOUND OR NOT r."CanConfigure" THEN RAISE EXCEPTION 'Champ absent ou protégé.' USING ERRCODE='23514';END IF;
 IF TG_OP='UPDATE' AND NEW."IdChampReferentielFk" IS DISTINCT FROM OLD."IdChampReferentielFk" THEN RAISE EXCEPTION 'Identité du réglage conservée.' USING ERRCODE='23514';END IF;
 IF TG_OP='DELETE' THEN RETURN OLD;END IF;
 IF NEW."MappingType"<>'generic_category' OR NEW."SourceKey"<>'champ.'||r."ID_ChampReferentiel"::text OR NEW."SchemaName"<>r."SchemaName" OR NEW."FieldName"<>r."ColumnName" OR NEW."ModuleName"<>r."ModuleName" OR NEW."ViewName" IS NOT NULL
  OR NEW."ReferenceSchemaName" IS DISTINCT FROM 'referentiel' OR NEW."ReferenceObjectName" IS DISTINCT FROM 'T_Generique' OR NEW."ReferenceFieldName" IS DISTINCT FROM 'ID_Generique'
  OR NEW."SettingScope" NOT IN ('global','entity') OR NEW."DisplayOrder"<0 THEN RAISE EXCEPTION 'Correspondance et colonne physique incohérentes.' USING ERRCODE='23514';END IF;
 IF NEW."SettingScope"='entity' AND NOT r."SupportsEntityScope" THEN RAISE EXCEPTION 'Ce champ partagé ne possède pas de portée entreprise.' USING ERRCODE='23514';END IF;
 IF NEW."SettingScope"='entity' AND (NEW."ScopeValue" !~ '^[1-9][0-9]{0,9}$' OR NOT EXISTS(SELECT FROM systeme."T_Entite" WHERE "IdEntite"::text=NEW."ScopeValue")) THEN RAISE EXCEPTION 'Entreprise de réglage introuvable.' USING ERRCODE='23514';END IF;
 IF NEW."MappingValue"='@default' THEN
  IF NEW."TargetCategoryIdFk" IS NOT NULL OR NOT NEW."IsDefaultMapping" THEN RAISE EXCEPTION 'Marqueur de restauration invalide.' USING ERRCODE='23514';END IF;
 ELSE
  IF NEW."TargetCategoryIdFk" IS NULL OR NEW."MappingValue"<>NEW."TargetCategoryIdFk"::text OR NOT EXISTS(SELECT FROM referentiel."T_CategorieGenerique" WHERE "ID_CategorieGenerique"=NEW."TargetCategoryIdFk" AND "ValideCategorieGenerique") THEN
   RAISE EXCEPTION 'Catégorie courante active requise.' USING ERRCODE='23514';END IF;
 END IF;
 IF EXISTS(SELECT FROM systeme."T_Fk_Correspondance" f WHERE f."IdChampReferentielFk"=r."ID_ChampReferentiel" AND f."SettingScope"=NEW."SettingScope" AND f."ScopeValue" IS NOT DISTINCT FROM NEW."ScopeValue" AND f."IdFkCorrespondance"<>coalesce(NEW."IdFkCorrespondance",-1)
  AND ((NEW."MappingValue"='@default')<>(f."MappingValue"='@default'))) THEN RAISE EXCEPTION 'Un jeu de réglage ne mélange pas restauration et catégories.' USING ERRCODE='23514';END IF;
 RETURN NEW;
END $_$;

--
-- Name: FUNCTION tr_correspondance_champ_integrite(); Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON FUNCTION systeme.tr_correspondance_champ_integrite() IS 'Contrôle des jeux canoniques : champ physique, famille active, portée existante, restauration explicite et verrou du catalogue. Les anciens réglages restent conservés, les rôles de sécurité ne changent pas de famille.';

--
-- Name: tr_correspondance_champ_revision(); Type: FUNCTION; Schema: systeme; Owner: -
--

CREATE FUNCTION systeme.tr_correspondance_champ_revision() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$
DECLARE before_data jsonb; after_data jsonb;
BEGIN
 IF TG_OP<>'INSERT' THEN before_data:=to_jsonb(OLD);END IF;
 IF TG_OP<>'DELETE' THEN after_data:=to_jsonb(NEW);END IF;
 UPDATE referentiel."T_ChampReferentiel" c SET "Revision"=c."Revision"+1,"ModifieLe"=clock_timestamp(),"ModifieParUserFk"=systeme.fn_admin_actor_user_id()
 WHERE c."ID_ChampReferentiel" IN (nullif(before_data->>'IdChampReferentielFk','')::integer,nullif(after_data->>'IdChampReferentielFk','')::integer)
 OR coalesce(before_data->>'SourceKey','')=ANY(c."AliasSourceKeys") OR coalesce(after_data->>'SourceKey','')=ANY(c."AliasSourceKeys");
 RETURN NULL;
END $$;

--
-- Name: FUNCTION tr_correspondance_champ_revision(); Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON FUNCTION systeme.tr_correspondance_champ_revision() IS 'Révision opaque commune au champ : chaque modification canonique ou de son alias historique invalide les lectures concurrentes, toutes portées confondues, avec auteur et horodatage factuels.';

--
-- Name: tr_localisation_patrimoine_proprietaire(); Type: FUNCTION; Schema: systeme; Owner: -
--

CREATE FUNCTION systeme.tr_localisation_patrimoine_proprietaire() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$
BEGIN
 IF NEW."IdEntiteFk" IS DISTINCT FROM OLD."IdEntiteFk" AND EXISTS(SELECT FROM logistique."T_Immobilisation" WHERE "ID_LocalisationFk"=OLD."IdEntiteLocalisation") THEN RAISE EXCEPTION 'Une immobilisation est liée à cette localisation ; son entreprise est conservée.' USING ERRCODE='23514';END IF;
 RETURN NEW;
END $$;

--
-- Name: FUNCTION tr_localisation_patrimoine_proprietaire(); Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON FUNCTION systeme.tr_localisation_patrimoine_proprietaire() IS 'Empêche de déplacer une localisation vers une autre entreprise lorsqu’un bien actif ou archivé y reste lié. Ne crée aucun état d’archivage fictif pour les localisations.';

--
-- Name: tr_module_classification(); Type: FUNCTION; Schema: systeme; Owner: -
--

CREATE FUNCTION systeme.tr_module_classification() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$
BEGIN
 PERFORM pg_advisory_xact_lock(hashtextextended('sauverndeko.catalogue.classification',0));
 IF NEW."ModuleParentCode" IS NOT NULL AND NOT EXISTS(
  SELECT FROM systeme."T_ModuleApplication" WHERE "CodeModule"=NEW."ModuleParentCode" AND "TypeApplication"='MODULE'
 ) THEN
  RAISE EXCEPTION 'Une fonctionnalité doit être rattachée à un module du catalogue.' USING ERRCODE='23514';
 END IF;
 IF NEW."TypeApplication"='FONCTIONNALITE' AND EXISTS(
  SELECT FROM systeme."T_ModuleApplication" WHERE "ModuleParentCode"=NEW."CodeModule" AND "CodeModule"<>NEW."CodeModule"
 ) THEN
  RAISE EXCEPTION 'Ce module possède des fonctionnalités ; modifiez leurs rattachements avant sa classification.' USING ERRCODE='23514';
 END IF;
 RETURN NEW;
END $$;

--
-- Name: FUNCTION tr_module_classification(); Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON FUNCTION systeme.tr_module_classification() IS 'Contrôle la nature du parent de présentation et empêche de reclasser en fonctionnalité un module possédant des enfants ; aucun effet sur les autorisations ou licences.';

--
-- Name: tr_support_circuit_valider(); Type: FUNCTION; Schema: systeme; Owner: -
--

CREATE FUNCTION systeme.tr_support_circuit_valider() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $_$
DECLARE v jsonb:=NEW."SettingValueJson";r record;entity_id integer;cnt integer;
BEGIN
 IF NEW."SettingKey"<>'support.workflow' THEN RETURN NEW;END IF;
 IF NEW."SettingScope" NOT IN('global','entite') OR NEW."SettingType"<>'json' OR jsonb_typeof(v) IS DISTINCT FROM 'object' OR coalesce(v->>'version','') !~ '^[1-9][0-9]{0,8}$' OR jsonb_typeof(v->'states') IS DISTINCT FROM 'object' OR jsonb_typeof(v->'verification') IS DISTINCT FROM 'object' OR jsonb_typeof(v->'transitions') IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'Structure du circuit Support invalide.' USING ERRCODE='23514';END IF;
 IF NEW."SettingScope"='entite' THEN
  IF coalesce(NEW."ScopeValue",'') !~ '^[1-9][0-9]{0,8}$' OR NOT EXISTS(SELECT FROM systeme."T_Entite" WHERE "IdEntite"::text=NEW."ScopeValue") THEN RAISE EXCEPTION 'Entreprise du circuit inconnue.' USING ERRCODE='23514';END IF;
  entity_id:=NEW."ScopeValue"::integer;
 END IF;
 SELECT count(DISTINCT value) INTO cnt FROM jsonb_each_text(v->'states');
 IF cnt<>5 OR NOT (v->'states' ?& ARRAY['new','active','pending','resolved','closed']) OR systeme.fn_support_object_size(v->'states')<>5 THEN RAISE EXCEPTION 'Les cinq états distincts du circuit sont requis.' USING ERRCODE='23514';END IF;
 FOR r IN SELECT * FROM jsonb_each_text(v->'states') LOOP
  IF r.value !~ '^[1-9][0-9]{0,8}$' OR NOT referentiel.fn_valider_reference_champ('support','T_Support','ID_StatutFk',r.value::integer,entity_id) THEN RAISE EXCEPTION 'Statut de circuit hors référentiel actif.' USING ERRCODE='23514';END IF;
 END LOOP;
 IF NOT (v->'verification' ?& ARRAY['accepted','rejected']) OR v->'verification'->>'accepted'=v->'verification'->>'rejected' THEN RAISE EXCEPTION 'Résultats de vérification distincts requis.' USING ERRCODE='23514';END IF;
 FOR r IN SELECT * FROM jsonb_each_text(v->'verification') LOOP
  IF r.value !~ '^[1-9][0-9]{0,8}$' OR NOT referentiel.fn_valider_reference_champ('support','T_ResolutionSupport','ID_ResultatVerificationFk',r.value::integer,entity_id) THEN RAISE EXCEPTION 'Vérification hors référentiel actif.' USING ERRCODE='23514';END IF;
 END LOOP;
 FOR r IN SELECT value edge FROM jsonb_array_elements(v->'transitions') LOOP
  IF jsonb_typeof(r.edge) IS DISTINCT FROM 'object' OR NOT (v->'states' ? (r.edge->>'from')) OR NOT (v->'states' ? (r.edge->>'to')) OR r.edge->>'from'=r.edge->>'to' OR NOT EXISTS(
   SELECT FROM (VALUES('new','active','start'),('active','pending','pause'),('pending','active','resume'),('active','resolved','resolve'),('pending','resolved','resolve'),('resolved','closed','close'),('resolved','active','reopen'),('closed','active','reopen')) allowed(src,dst,action)
   WHERE allowed.src=r.edge->>'from' AND allowed.dst=r.edge->>'to' AND allowed.action=r.edge->>'action') THEN RAISE EXCEPTION 'Transition du circuit invalide ou action incompatible.' USING ERRCODE='23514';END IF;
 END LOOP;
 RETURN NEW;
END $_$;

--
-- Name: FUNCTION tr_support_circuit_valider(); Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON FUNCTION systeme.tr_support_circuit_valider() IS 'Contrôle les états et transitions du circuit dans T_Admin_UI_Setting contre le référencement physique courant ; les libellés restent exclusivement dans T_Generique.';

--
-- Name: tr_utilisateur_affectation_verifier(); Type: FUNCTION; Schema: systeme; Owner: -
--

CREATE FUNCTION systeme.tr_utilisateur_affectation_verifier() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$
BEGIN
 IF TG_OP='UPDATE' AND NEW."IdEntiteFk" IS DISTINCT FROM OLD."IdEntiteFk" AND EXISTS(SELECT FROM logistique."T_Immobilisation" WHERE "ID_ResponsableFk"=OLD."IdUser") THEN RAISE EXCEPTION 'Un bien reste lié à cet utilisateur ; son entreprise doit être conservée.' USING ERRCODE='23514';END IF;
 IF TG_OP='INSERT' OR NEW."ID_ServiceFk" IS DISTINCT FROM OLD."ID_ServiceFk" THEN IF NOT logistique.fn_reference_immobilisation_valide(NEW."ID_ServiceFk",'service-rh',NEW."IdEntiteFk") THEN RAISE EXCEPTION 'Service professionnel indisponible.' USING ERRCODE='23514';END IF;END IF;
 IF TG_OP='INSERT' OR NEW."ID_FonctionFk" IS DISTINCT FROM OLD."ID_FonctionFk" THEN IF NOT logistique.fn_reference_immobilisation_valide(NEW."ID_FonctionFk",'fonction-rh',NEW."IdEntiteFk") THEN RAISE EXCEPTION 'Fonction professionnelle indisponible.' USING ERRCODE='23514';END IF;END IF;
 RETURN NEW;
END $$;

--
-- Name: FUNCTION tr_utilisateur_affectation_verifier(); Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON FUNCTION systeme.tr_utilisateur_affectation_verifier() IS 'Références RH actives à leur affectation ; le changement d’entreprise est refusé lorsqu’un bien, même archivé, reste lié comme responsabilité. Aucune extension du profil public.';

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

--
-- Name: verifier_activation_module(); Type: FUNCTION; Schema: systeme; Owner: -
--

CREATE FUNCTION systeme.verifier_activation_module() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
 IF TG_OP='UPDATE' THEN
  IF TG_TABLE_NAME='T_LicenceModule' THEN
   IF OLD."IdLicenceFk"<>NEW."IdLicenceFk" OR OLD."CodeModule"<>NEW."CodeModule" OR OLD."Origine"<>NEW."Origine" THEN RAISE EXCEPTION 'Le rattachement et son origine sont immuables.'; END IF;
  ELSE
   IF OLD."IdEntiteFk"<>NEW."IdEntiteFk" OR OLD."IdRoleFk"<>NEW."IdRoleFk" OR OLD."CodeModule"<>NEW."CodeModule" THEN RAISE EXCEPTION 'Le périmètre du rôle est immuable.'; END IF;
  END IF;
  NEW."Version"=OLD."Version"+1;
 ELSE
  NEW."Version"=1;
 END IF;
 IF TG_TABLE_NAME='T_RoleModule' THEN
  IF NOT EXISTS (SELECT 1 FROM referentiel."T_Generique" WHERE "ID_Generique"=NEW."IdRoleFk" AND "ID_CategorieGeneriqueFk"=39) THEN RAISE EXCEPTION 'Référence de rôle invalide.'; END IF;
 END IF;
 NEW."ModifieLe"=CURRENT_TIMESTAMP;
 RETURN NEW;
END;
$$;

--
-- Name: FUNCTION verifier_activation_module(); Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON FUNCTION systeme.verifier_activation_module() IS 'Préserve les rattachements et leur provenance, contrôle la catégorie de rôle et fixe version et horodatage ; ne crée aucune licence.';


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
    "ValideEntite" boolean DEFAULT true,
    "AlertePeremptionJours" smallint DEFAULT 30 NOT NULL,
    "BloquerLotsPerimes" boolean DEFAULT false NOT NULL,
    "IdentifiantsLegauxEntite" jsonb DEFAULT '[]'::jsonb NOT NULL,
    "MentionDocumentaireEntite" character varying(1000),
    "SiteWebEntite" text,
    "AfficherEnteteDocument" boolean DEFAULT true CONSTRAINT "T_Entite_AfficherEnteteDocument_not_null" NOT NULL,
    "AfficherPiedDocument" boolean DEFAULT true CONSTRAINT "T_Entite_AfficherPiedDocument_not_null" NOT NULL,
    "LogoEntite" bytea,
    "LogoMimeEntite" character varying(32),
    "LogoSha256Entite" character varying(64),
    "LogoModifieLe" timestamp with time zone,
    "PhoneSecondaireEntite" character varying(20),
    "TauxTVAEntite" numeric(7,4) DEFAULT 0 CONSTRAINT "T_Entite_TauxTVAEntite_not_null" NOT NULL,
    CONSTRAINT "T_Entite_AlertePeremptionJours_check" CHECK ((("AlertePeremptionJours" >= 0) AND ("AlertePeremptionJours" <= 3650))),
    CONSTRAINT ck_entite_identifiants_legaux CHECK (systeme.fn_identifiants_legaux_valides("IdentifiantsLegauxEntite")),
    CONSTRAINT ck_entite_logo_complet CHECK ((num_nonnulls("LogoEntite", "LogoMimeEntite", "LogoSha256Entite", "LogoModifieLe") = ANY (ARRAY[0, 4]))),
    CONSTRAINT ck_entite_logo_png CHECK ((("LogoEntite" IS NULL) OR ((octet_length("LogoEntite") >= 45) AND (octet_length("LogoEntite") <= 2097152) AND (("LogoMimeEntite")::text = 'image/png'::text) AND (SUBSTRING("LogoEntite" FROM 1 FOR 8) = decode('89504e470d0a1a0a'::text, 'hex'::text)) AND (SUBSTRING("LogoEntite" FROM 9 FOR 8) = decode('0000000d49484452'::text, 'hex'::text)) AND (SUBSTRING("LogoEntite" FROM (octet_length("LogoEntite") - 11) FOR 12) = decode('0000000049454e44ae426082'::text, 'hex'::text)) AND (("LogoSha256Entite")::text = encode(sha256("LogoEntite"), 'hex'::text))))),
    CONSTRAINT ck_entite_mention_documentaire CHECK ((("MentionDocumentaireEntite" IS NULL) OR (replace(("MentionDocumentaireEntite")::text, E'\n'::text, ''::text) !~ '[[:cntrl:]]'::text))),
    CONSTRAINT ck_entite_phone_secondaire CHECK ((("PhoneSecondaireEntite" IS NULL) OR ((char_length(("PhoneSecondaireEntite")::text) >= 1) AND (char_length(("PhoneSecondaireEntite")::text) <= 20) AND (("PhoneSecondaireEntite")::text = btrim(("PhoneSecondaireEntite")::text)) AND (("PhoneSecondaireEntite")::text !~ '[[:cntrl:]]'::text)))),
    CONSTRAINT ck_entite_site_web CHECK ((("SiteWebEntite" IS NULL) OR ((char_length("SiteWebEntite") >= 1) AND (char_length("SiteWebEntite") <= 255) AND ("SiteWebEntite" = btrim("SiteWebEntite")) AND ("SiteWebEntite" ~* '^https?://[^[:space:]/?#@]+([/?#][^[:space:]]*)?$'::text)))),
    CONSTRAINT ck_entite_taux_tva CHECK ((("TauxTVAEntite" >= (0)::numeric) AND ("TauxTVAEntite" <= (100)::numeric)))
);

--
-- Name: TABLE "T_Entite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON TABLE systeme."T_Entite" IS 'Entreprises propriétaires : identité, coordonnées, licence et profil documentaire courant avec logo PNG privé, site et options d’en-tête/pied. L’identité de présentation peut évoluer sans modifier les écritures ou instantanés historiques.';

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
-- Name: COLUMN "T_Entite"."AlertePeremptionJours"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Entite"."AlertePeremptionJours" IS 'Délai d’alerte par défaut de cette entreprise, en jours ; le seuil explicite de l’article prime.';

--
-- Name: COLUMN "T_Entite"."BloquerLotsPerimes"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Entite"."BloquerLotsPerimes" IS 'Refuse les nouveaux prélèvements sur des lots périmés, sauf dérogation motivée d’un administrateur global ; false conserve le mode informatif.';

--
-- Name: COLUMN "T_Entite"."IdentifiantsLegauxEntite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Entite"."IdentifiantsLegauxEntite" IS 'Dix identifiants déclaratifs génériques facultatifs au maximum : RCCM, NIF, identification nationale ou autre libellé/valeur. Source courante pour la présentation ; les instantanés historiques restent conservés.';

--
-- Name: COLUMN "T_Entite"."MentionDocumentaireEntite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Entite"."MentionDocumentaireEntite" IS 'Mention courante facultative, maximum1000 caractères avec sauts de ligne ; ne modifie jamais les montants, tiers ou identités historiques conservés.';

--
-- Name: COLUMN "T_Entite"."SiteWebEntite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Entite"."SiteWebEntite" IS 'Site web facultatif actuel de l’entreprise, HTTP ou HTTPS, sans identifiants intégrés ni espace ; maximum255 caractères.';

--
-- Name: COLUMN "T_Entite"."AfficherEnteteDocument"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Entite"."AfficherEnteteDocument" IS 'Affiche l’identité courante de l’entreprise en haut de ses PDF métier ; true par défaut. Aucun effet sur les montants et lignes historiques.';

--
-- Name: COLUMN "T_Entite"."AfficherPiedDocument"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Entite"."AfficherPiedDocument" IS 'Affiche le nom, les identifiants et mentions courants ainsi que la pagination dans le pied des PDF métier ; true par défaut. false supprime entièrement le pied de page.';

--
-- Name: COLUMN "T_Entite"."LogoEntite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Entite"."LogoEntite" IS 'Octets PNG privés normalisés par le service après décodage image ; maximum2Mo, signature/structure externe et SHA-256 contrôlés en SQL. Jamais inclus dans les vues JSON, audits ou exports génériques.';

--
-- Name: COLUMN "T_Entite"."LogoMimeEntite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Entite"."LogoMimeEntite" IS 'MIME du logo normalisé : image/png ; NULL en l’absence de logo. Cohérent avec les trois autres champs du logo.';

--
-- Name: COLUMN "T_Entite"."LogoSha256Entite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Entite"."LogoSha256Entite" IS 'Empreinte SHA-256 hexadécimale minuscule des octets PNG exacts stockés en base ; vérifiée indépendamment par PostgreSQL.';

--
-- Name: COLUMN "T_Entite"."LogoModifieLe"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Entite"."LogoModifieLe" IS 'Horodatage serveur de la dernière installation du logo normalisé ; NULL si aucune image. Métadonnée contrôlée par le service de téléversement.';

--
-- Name: COLUMN "T_Entite"."PhoneSecondaireEntite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Entite"."PhoneSecondaireEntite" IS 'Deuxième numéro de téléphone facultatif courant de l’entreprise ; 1 à 20 caractères sans espaces extérieurs ni contrôles. NULL signifie non renseigné.';

--
-- Name: COLUMN "T_Entite"."TauxTVAEntite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Entite"."TauxTVAEntite" IS 'Taux de TVA en pourcentage proposé aux nouvelles factures de cette entreprise, de 0 à 100 avec quatre décimales maximum ; défaut 0, sans réécriture des factures émises.';

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
-- Name: CONSTRAINT "T_Entite_AfficherEnteteDocument_not_null" ON "T_Entite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "T_Entite_AfficherEnteteDocument_not_null" ON systeme."T_Entite" IS 'Option documentaire obligatoire ; true par défaut, false explicite pour masquer cette zone.';

--
-- Name: CONSTRAINT "T_Entite_AfficherPiedDocument_not_null" ON "T_Entite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "T_Entite_AfficherPiedDocument_not_null" ON systeme."T_Entite" IS 'Option documentaire obligatoire ; true par défaut, false explicite pour masquer cette zone.';

--
-- Name: CONSTRAINT "T_Entite_TauxTVAEntite_not_null" ON "T_Entite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "T_Entite_TauxTVAEntite_not_null" ON systeme."T_Entite" IS 'Le défaut fiscal explicite de l’entreprise existe toujours ; zéro ne signifie pas un régime légal déduit.';

--
-- Name: CONSTRAINT ck_entite_identifiants_legaux ON "T_Entite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT ck_entite_identifiants_legaux ON systeme."T_Entite" IS 'Identifiants facultatifs génériques, sans doublon de libellé ni structure JSON arbitraire.';

--
-- Name: CONSTRAINT ck_entite_logo_complet ON "T_Entite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT ck_entite_logo_complet ON systeme."T_Entite" IS 'Logo absent : quatre champs NULL ; logo présent : octets, MIME, empreinte et horodatage obligatoires ensemble.';

--
-- Name: CONSTRAINT ck_entite_logo_png ON "T_Entite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT ck_entite_logo_png ON systeme."T_Entite" IS 'Signature PNG, IHDR et fin IEND, taille45octets à2Mo, MIME PNG et SHA exact ; le décodage complet et la normalisation relèvent du service image.';

--
-- Name: CONSTRAINT ck_entite_mention_documentaire ON "T_Entite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT ck_entite_mention_documentaire ON systeme."T_Entite" IS 'Mention documentaire sans caractères de contrôle, à l’exception du saut de ligne pour sa mise en forme.';

--
-- Name: CONSTRAINT ck_entite_phone_secondaire ON "T_Entite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT ck_entite_phone_secondaire ON systeme."T_Entite" IS 'Téléphone secondaire facultatif limité à20 caractères, non vide, sans contrôles ni espaces avant ou après ; aucun numéro supposé ou généré.';

--
-- Name: CONSTRAINT ck_entite_site_web ON "T_Entite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT ck_entite_site_web ON systeme."T_Entite" IS 'URL de présentation facultative limitée à HTTP/HTTPS et255 caractères ; refus des espaces, contrôles et identifiants dans l’autorité.';

--
-- Name: CONSTRAINT ck_entite_taux_tva ON "T_Entite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT ck_entite_taux_tva ON systeme."T_Entite" IS 'Le taux paramétrable de l’entreprise reste compris entre 0 et 100 pour cent ; aucune valeur réglementaire n’est déduite.';

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
    "MatriculeUser" character varying(50),
    "ID_ServiceFk" integer,
    "ID_FonctionFk" integer,
    "DateEmbauche" date,
    "DateFinEmploi" date,
    "ObservationProfessionnelle" text,
    CONSTRAINT chk_sexe_utilisateur CHECK (("SexeUser" = ANY (ARRAY['M'::bpchar, 'F'::bpchar]))),
    CONSTRAINT ck_user_dates_emploi CHECK (((("DateEmbauche" IS NULL) OR isfinite("DateEmbauche")) AND (("DateFinEmploi" IS NULL) OR isfinite("DateFinEmploi")) AND (("DateEmbauche" IS NULL) OR ("DateFinEmploi" IS NULL) OR ("DateFinEmploi" >= "DateEmbauche")))),
    CONSTRAINT ck_user_matricule CHECK ((("MatriculeUser" IS NULL) OR ((char_length(("MatriculeUser")::text) >= 1) AND (char_length(("MatriculeUser")::text) <= 50) AND (("MatriculeUser")::text = btrim(("MatriculeUser")::text)) AND (("MatriculeUser")::text !~ '[[:cntrl:]]'::text)))),
    CONSTRAINT ck_user_observation_professionnelle CHECK ((("ObservationProfessionnelle" IS NULL) OR ((char_length("ObservationProfessionnelle") <= 1000) AND (replace(replace("ObservationProfessionnelle", E'\r\n'::text, E'\n'::text), E'\n'::text, ''::text) !~ '[[:cntrl:]]'::text))))
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
-- Name: COLUMN "T_Utilisateurs"."MatriculeUser"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Utilisateurs"."MatriculeUser" IS 'Matricule professionnel facultatif, maximum50 caractères, sans espaces extérieurs ; unique sans distinction de casse dans son entreprise.';

--
-- Name: COLUMN "T_Utilisateurs"."ID_ServiceFk"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Utilisateurs"."ID_ServiceFk" IS 'Service professionnel actuel dans la famille générique Service ; ne déplace pas automatiquement les immobilisations affectées.';

--
-- Name: COLUMN "T_Utilisateurs"."ID_FonctionFk"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Utilisateurs"."ID_FonctionFk" IS 'Fonction professionnelle actuelle dans la famille générique Fonction, distincte du rôle de sécurité.';

--
-- Name: COLUMN "T_Utilisateurs"."DateEmbauche"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Utilisateurs"."DateEmbauche" IS 'Début professionnel facultatif ; aucune date supposée pour les comptes existants.';

--
-- Name: COLUMN "T_Utilisateurs"."DateFinEmploi"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Utilisateurs"."DateFinEmploi" IS 'Fin professionnelle facultative, jamais antérieure au début renseigné ; condition de nouvelle affectation des biens.';

--
-- Name: COLUMN "T_Utilisateurs"."ObservationProfessionnelle"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Utilisateurs"."ObservationProfessionnelle" IS 'Note professionnelle facultative, maximum1000 caractères ; séparée des projections publiques et du profil courant.';

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
-- Name: CONSTRAINT ck_user_dates_emploi ON "T_Utilisateurs"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT ck_user_dates_emploi ON systeme."T_Utilisateurs" IS 'Métadonnée professionnelle facultative contrôlée : CHECK (("DateEmbauche" IS NULL OR isfinite("DateEmbauche")) AND ("DateFinEmploi" IS NULL OR isfinite("DateFinEmploi")) AND ("DateEmbauche" IS NULL OR "DateFinEmploi" IS NULL OR "DateFinEmploi" >= "DateEmbauche")). Ne donne aucun droit de sécurité.';

--
-- Name: CONSTRAINT ck_user_matricule ON "T_Utilisateurs"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT ck_user_matricule ON systeme."T_Utilisateurs" IS 'Métadonnée professionnelle facultative contrôlée : CHECK ("MatriculeUser" IS NULL OR char_length("MatriculeUser"::text) >= 1 AND char_length("MatriculeUser"::text) <= 50 AND "MatriculeUser"::text = btrim("MatriculeUser"::text) AND "MatriculeUser"::text !~ ''[[:cntrl:]]''::text). Ne donne aucun droit de sécurité.';

--
-- Name: CONSTRAINT ck_user_observation_professionnelle ON "T_Utilisateurs"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT ck_user_observation_professionnelle ON systeme."T_Utilisateurs" IS E'Métadonnée professionnelle facultative contrôlée : CHECK ("ObservationProfessionnelle" IS NULL OR char_length("ObservationProfessionnelle") <= 1000 AND replace(replace("ObservationProfessionnelle", ''\r\n''::text, ''\n''::text), ''\n''::text, ''''::text) !~ ''[[:cntrl:]]''::text). Ne donne aucun droit de sécurité.';

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
    CONSTRAINT "Ck_Admin_UI_Setting_ScopeValue" CHECK ((((("SettingScope")::text = 'global'::text) AND ("ScopeValue" IS NULL)) OR ((("SettingScope")::text <> 'global'::text) AND (NULLIF(btrim(("ScopeValue")::text), ''::text) IS NOT NULL)))),
    CONSTRAINT "Ck_Admin_UI_Setting_Type" CHECK ((("SettingType")::text = ANY (ARRAY[('text'::character varying)::text, ('number'::character varying)::text, ('boolean'::character varying)::text, ('select'::character varying)::text, ('json'::character varying)::text, ('color'::character varying)::text, ('file'::character varying)::text, ('email'::character varying)::text, ('phone'::character varying)::text, ('url'::character varying)::text, ('textarea'::character varying)::text])))
);

--
-- Name: TABLE "T_Admin_UI_Setting"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON TABLE systeme."T_Admin_UI_Setting" IS 'Paramètres partagés par portée et clé ; unicité y compris portée globale NULL, protections SQL et audit des écritures. Un paramètre système éditable conserve la modification de sa valeur.';

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

COMMENT ON COLUMN systeme."T_Admin_UI_Setting"."CreatedAt" IS 'Instant de création imposé par PostgreSQL ; conservé lors des modifications ultérieures.';

--
-- Name: COLUMN "T_Admin_UI_Setting"."UpdatedAt"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Admin_UI_Setting"."UpdatedAt" IS 'Instant de dernière écriture, imposé par PostgreSQL.';

--
-- Name: COLUMN "T_Admin_UI_Setting"."UpdatedByUserFk"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Admin_UI_Setting"."UpdatedByUserFk" IS 'Auteur actif validé depuis systeme.actor_user_id ; NULL pour une écriture directe sans acteur applicatif.';

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
-- Name: CONSTRAINT "Ck_Admin_UI_Setting_ScopeValue" ON "T_Admin_UI_Setting"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "Ck_Admin_UI_Setting_ScopeValue" ON systeme."T_Admin_UI_Setting" IS 'Contexte NULL pour global ; contexte non vide pour entite, user ou module.';

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
    "IdChampReferentielFk" integer,
    CONSTRAINT "Ck_FkCorrespondance_ScopeValue" CHECK ((((("SettingScope")::text = 'global'::text) AND ("ScopeValue" IS NULL)) OR ((("SettingScope")::text <> 'global'::text) AND (NULLIF(btrim(("ScopeValue")::text), ''::text) IS NOT NULL)))),
    CONSTRAINT chk_fkcorrespondance_mappingtype CHECK ((("MappingType")::text = ANY (ARRAY[('generic_category'::character varying)::text, ('direct_source'::character varying)::text, ('hierarchy_mode'::character varying)::text]))),
    CONSTRAINT chk_fkcorrespondance_scope CHECK ((("SettingScope")::text = ANY (ARRAY[('global'::character varying)::text, ('country'::character varying)::text, ('entity'::character varying)::text])))
);

--
-- Name: TABLE "T_Fk_Correspondance"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON TABLE systeme."T_Fk_Correspondance" IS 'Correspondances de références par source et portée ; unicité y compris contexte NULL, auteur transactionnel et audit SQL.';

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

COMMENT ON COLUMN systeme."T_Fk_Correspondance"."UpdatedAt" IS 'Dernière écriture en heure civile Africa/Kinshasa, type historique sans fuseau conservé.';

--
-- Name: COLUMN "T_Fk_Correspondance"."UpdatedByUserFk"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Fk_Correspondance"."UpdatedByUserFk" IS 'Auteur actif validé depuis systeme.actor_user_id ; NULL pour une écriture directe sans acteur applicatif.';

--
-- Name: COLUMN "T_Fk_Correspondance"."ObsFkCorrespondance"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Fk_Correspondance"."ObsFkCorrespondance" IS 'Observations enregistrées sur la correspondance.';

--
-- Name: COLUMN "T_Fk_Correspondance"."IdChampReferentielFk"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_Fk_Correspondance"."IdChampReferentielFk" IS 'Champ physique canonique pour un jeu de catégories courant ; NULL conserve une correspondance historique ou non catégorielle.';

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
-- Name: CONSTRAINT "Ck_FkCorrespondance_ScopeValue" ON "T_Fk_Correspondance"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "Ck_FkCorrespondance_ScopeValue" ON systeme."T_Fk_Correspondance" IS 'Contexte NULL pour global ; contexte non vide pour country ou entity.';

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
-- Name: T_LicenceModule; Type: TABLE; Schema: systeme; Owner: -
--

CREATE TABLE systeme."T_LicenceModule" (
    "IdLicenceModule" integer NOT NULL,
    "IdLicenceFk" integer NOT NULL,
    "CodeModule" character varying(32) NOT NULL,
    "Actif" boolean DEFAULT true NOT NULL,
    "Origine" character varying(12) DEFAULT 'activation'::character varying NOT NULL,
    "Version" integer DEFAULT 1 NOT NULL,
    "ModifieParUserFk" integer,
    "CreeLe" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "ModifieLe" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT "T_LicenceModule_Origine_check" CHECK ((("Origine")::text = ANY (ARRAY[('activation'::character varying)::text, ('reprise'::character varying)::text]))),
    CONSTRAINT "T_LicenceModule_Version_check" CHECK (("Version" > 0))
);

--
-- Name: TABLE "T_LicenceModule"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON TABLE systeme."T_LicenceModule" IS 'Modules compris dans une licence existante. L’entité et la période sont celles de T_Licence ; aucun abonnement individuel.';

--
-- Name: COLUMN "T_LicenceModule"."IdLicenceModule"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_LicenceModule"."IdLicenceModule" IS 'Identifiant permanent de la ligne d’activation.';

--
-- Name: COLUMN "T_LicenceModule"."IdLicenceFk"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_LicenceModule"."IdLicenceFk" IS 'Licence de l’entité ; cette relation est immuable.';

--
-- Name: COLUMN "T_LicenceModule"."CodeModule"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_LicenceModule"."CodeModule" IS 'Application activée dans cette licence ; code immuable.';

--
-- Name: COLUMN "T_LicenceModule"."Actif"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_LicenceModule"."Actif" IS 'Activation explicite du module dans la licence.';

--
-- Name: COLUMN "T_LicenceModule"."Origine"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_LicenceModule"."Origine" IS 'Reprise identifie les accès conservés lors de la migration ; ce champ ne constitue pas une facturation.';

--
-- Name: COLUMN "T_LicenceModule"."Version"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_LicenceModule"."Version" IS 'Version utilisée pour refuser les modifications concurrentes.';

--
-- Name: COLUMN "T_LicenceModule"."ModifieParUserFk"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_LicenceModule"."ModifieParUserFk" IS 'Administrateur de plateforme auteur de la dernière modification ; NULL pour la migration initiale.';

--
-- Name: COLUMN "T_LicenceModule"."CreeLe"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_LicenceModule"."CreeLe" IS 'Instant de création du rattachement.';

--
-- Name: COLUMN "T_LicenceModule"."ModifieLe"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_LicenceModule"."ModifieLe" IS 'Instant de dernière modification fixé par le trigger.';

--
-- Name: T_LicenceModule_IdLicenceModule_seq; Type: SEQUENCE; Schema: systeme; Owner: -
--

ALTER TABLE systeme."T_LicenceModule" ALTER COLUMN "IdLicenceModule" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME systeme."T_LicenceModule_IdLicenceModule_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

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
-- Name: T_ModuleApplication; Type: TABLE; Schema: systeme; Owner: -
--

CREATE TABLE systeme."T_ModuleApplication" (
    "CodeModule" character varying(32) NOT NULL,
    "Nom" character varying(120) NOT NULL,
    "EstSocle" boolean DEFAULT false NOT NULL,
    "CodeIncluant" character varying(32),
    "Actif" boolean DEFAULT true NOT NULL,
    "Ordre" integer DEFAULT 0 NOT NULL,
    "TypeApplication" character varying(20) DEFAULT 'MODULE'::character varying NOT NULL,
    "Commercialisable" boolean DEFAULT false NOT NULL,
    "ModuleParentCode" character varying(32),
    CONSTRAINT "T_ModuleApplication_Nom_check" CHECK ((btrim(("Nom")::text) <> ''::text)),
    CONSTRAINT "T_ModuleApplication_check" CHECK ((("CodeIncluant")::text IS DISTINCT FROM ("CodeModule")::text)),
    CONSTRAINT ck_module_commercial CHECK (((NOT "Commercialisable") OR (("TypeApplication")::text = 'MODULE'::text))),
    CONSTRAINT ck_module_parent CHECK (((("ModuleParentCode")::text IS DISTINCT FROM ("CodeModule")::text) AND ((("TypeApplication")::text <> 'MODULE'::text) OR ("ModuleParentCode" IS NULL)))),
    CONSTRAINT ck_module_type_application CHECK ((("TypeApplication")::text = ANY (ARRAY[('MODULE'::character varying)::text, ('FONCTIONNALITE'::character varying)::text])))
);

--
-- Name: TABLE "T_ModuleApplication"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON TABLE systeme."T_ModuleApplication" IS 'Catalogue des applications SauverNdeko ; le socle partagé reste distinct des modules compris dans une licence.';

--
-- Name: COLUMN "T_ModuleApplication"."CodeModule"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_ModuleApplication"."CodeModule" IS 'Code stable utilisé par les contrôles serveur et la navigation.';

--
-- Name: COLUMN "T_ModuleApplication"."Nom"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_ModuleApplication"."Nom" IS 'Nom métier de l’application.';

--
-- Name: COLUMN "T_ModuleApplication"."EstSocle"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_ModuleApplication"."EstSocle" IS 'Application incluse au socle d’une entité active ; les droits du rôle restent nécessaires.';

--
-- Name: COLUMN "T_ModuleApplication"."CodeIncluant"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_ModuleApplication"."CodeIncluant" IS 'Application dont la licence inclut aussi ce module, sans créer une seconde souscription.';

--
-- Name: COLUMN "T_ModuleApplication"."Actif"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_ModuleApplication"."Actif" IS 'Disponibilité du module dans le catalogue.';

--
-- Name: COLUMN "T_ModuleApplication"."Ordre"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_ModuleApplication"."Ordre" IS 'Ordre de présentation du catalogue.';

--
-- Name: COLUMN "T_ModuleApplication"."TypeApplication"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_ModuleApplication"."TypeApplication" IS 'Nature de présentation : MODULE commercial ou FONCTIONNALITE complémentaire/commune. Ne remplace pas les règles d’accès existantes.';

--
-- Name: COLUMN "T_ModuleApplication"."Commercialisable"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_ModuleApplication"."Commercialisable" IS 'Le module peut être présenté comme offre commerciale ; ne donne aucun droit, ne crée ni licence ni abonnement.';

--
-- Name: COLUMN "T_ModuleApplication"."ModuleParentCode"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_ModuleApplication"."ModuleParentCode" IS 'Module de présentation de la fonctionnalité ; NULL pour une fonction commune. Distinct de CodeIncluant qui conserve les inclusions de droits historiques.';

--
-- Name: CONSTRAINT ck_module_commercial ON "T_ModuleApplication"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT ck_module_commercial ON systeme."T_ModuleApplication" IS 'Une fonctionnalité n’est pas proposée comme module commercial autonome.';

--
-- Name: CONSTRAINT ck_module_parent ON "T_ModuleApplication"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT ck_module_parent ON systeme."T_ModuleApplication" IS 'Une fonctionnalité peut dépendre d’un module ; un module est racine et ne peut se référencer lui-même.';

--
-- Name: CONSTRAINT ck_module_type_application ON "T_ModuleApplication"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT ck_module_type_application ON systeme."T_ModuleApplication" IS 'Deux natures explicites de présentation, sans dépendance aux libellés affichés.';

--
-- Name: T_RoleModule; Type: TABLE; Schema: systeme; Owner: -
--

CREATE TABLE systeme."T_RoleModule" (
    "IdRoleModule" integer NOT NULL,
    "IdEntiteFk" integer NOT NULL,
    "IdRoleFk" integer NOT NULL,
    "CodeModule" character varying(32) NOT NULL,
    "PeutConsulter" boolean DEFAULT true NOT NULL,
    "PeutGerer" boolean DEFAULT false NOT NULL,
    "PeutExporter" boolean DEFAULT false NOT NULL,
    "Actif" boolean DEFAULT true NOT NULL,
    "Version" integer DEFAULT 1 NOT NULL,
    "ModifieParUserFk" integer,
    "CreeLe" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "ModifieLe" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT "T_RoleModule_Version_check" CHECK (("Version" > 0)),
    CONSTRAINT "T_RoleModule_check" CHECK (("PeutConsulter" OR ((NOT "PeutGerer") AND (NOT "PeutExporter"))))
);

--
-- Name: TABLE "T_RoleModule"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON TABLE systeme."T_RoleModule" IS 'Restrictions par rôle, application et entité. Elles complètent les droits existants sans accorder le rôle d’administrateur.';

--
-- Name: COLUMN "T_RoleModule"."IdRoleModule"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_RoleModule"."IdRoleModule" IS 'Identifiant permanent du paramétrage.';

--
-- Name: COLUMN "T_RoleModule"."IdEntiteFk"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_RoleModule"."IdEntiteFk" IS 'Entité à laquelle s’applique cette règle ; immuable.';

--
-- Name: COLUMN "T_RoleModule"."IdRoleFk"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_RoleModule"."IdRoleFk" IS 'Rôle du référentiel, catégorie Rôles (39) ; immuable.';

--
-- Name: COLUMN "T_RoleModule"."CodeModule"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_RoleModule"."CodeModule" IS 'Application concernée par les restrictions ; code immuable.';

--
-- Name: COLUMN "T_RoleModule"."PeutConsulter"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_RoleModule"."PeutConsulter" IS 'Autorise la consultation si la licence et les droits préexistants l’autorisent aussi.';

--
-- Name: COLUMN "T_RoleModule"."PeutGerer"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_RoleModule"."PeutGerer" IS 'Autorise les créations, modifications et suppressions permises par les services métier existants.';

--
-- Name: COLUMN "T_RoleModule"."PeutExporter"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_RoleModule"."PeutExporter" IS 'Autorise les exports officiels du module.';

--
-- Name: COLUMN "T_RoleModule"."Actif"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_RoleModule"."Actif" IS 'Une règle inactive refuse ces accès ; son absence conserve les droits antérieurs.';

--
-- Name: COLUMN "T_RoleModule"."Version"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_RoleModule"."Version" IS 'Version du paramétrage pour la concurrence optimiste.';

--
-- Name: COLUMN "T_RoleModule"."ModifieParUserFk"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_RoleModule"."ModifieParUserFk" IS 'Administrateur de plateforme auteur de la dernière modification.';

--
-- Name: COLUMN "T_RoleModule"."CreeLe"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_RoleModule"."CreeLe" IS 'Instant de création du paramétrage.';

--
-- Name: COLUMN "T_RoleModule"."ModifieLe"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON COLUMN systeme."T_RoleModule"."ModifieLe" IS 'Instant de dernière modification fixé par le trigger.';

--
-- Name: T_RoleModule_IdRoleModule_seq; Type: SEQUENCE; Schema: systeme; Owner: -
--

ALTER TABLE systeme."T_RoleModule" ALTER COLUMN "IdRoleModule" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME systeme."T_RoleModule_IdRoleModule_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

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
-- Name: T_LicenceModule T_LicenceModule_IdLicenceFk_CodeModule_key; Type: CONSTRAINT; Schema: systeme; Owner: -
--

ALTER TABLE ONLY systeme."T_LicenceModule"
    ADD CONSTRAINT "T_LicenceModule_IdLicenceFk_CodeModule_key" UNIQUE ("IdLicenceFk", "CodeModule");

--
-- Name: T_LicenceModule T_LicenceModule_pkey; Type: CONSTRAINT; Schema: systeme; Owner: -
--

ALTER TABLE ONLY systeme."T_LicenceModule"
    ADD CONSTRAINT "T_LicenceModule_pkey" PRIMARY KEY ("IdLicenceModule");

--
-- Name: T_ModuleApplication T_ModuleApplication_pkey; Type: CONSTRAINT; Schema: systeme; Owner: -
--

ALTER TABLE ONLY systeme."T_ModuleApplication"
    ADD CONSTRAINT "T_ModuleApplication_pkey" PRIMARY KEY ("CodeModule");

--
-- Name: T_RoleModule T_RoleModule_IdEntiteFk_IdRoleFk_CodeModule_key; Type: CONSTRAINT; Schema: systeme; Owner: -
--

ALTER TABLE ONLY systeme."T_RoleModule"
    ADD CONSTRAINT "T_RoleModule_IdEntiteFk_IdRoleFk_CodeModule_key" UNIQUE ("IdEntiteFk", "IdRoleFk", "CodeModule");

--
-- Name: T_RoleModule T_RoleModule_pkey; Type: CONSTRAINT; Schema: systeme; Owner: -
--

ALTER TABLE ONLY systeme."T_RoleModule"
    ADD CONSTRAINT "T_RoleModule_pkey" PRIMARY KEY ("IdRoleModule");

--
-- Name: T_Fk_Correspondance UQ_FkCorrespondance_SourceValueScope; Type: CONSTRAINT; Schema: systeme; Owner: -
--

ALTER TABLE ONLY systeme."T_Fk_Correspondance"
    ADD CONSTRAINT "UQ_FkCorrespondance_SourceValueScope" UNIQUE NULLS NOT DISTINCT ("ModuleName", "SchemaName", "ViewName", "SourceKey", "FieldName", "MappingType", "MappingValue", "SettingScope", "ScopeValue");

--
-- Name: CONSTRAINT "UQ_FkCorrespondance_SourceValueScope" ON "T_Fk_Correspondance"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "UQ_FkCorrespondance_SourceValueScope" ON systeme."T_Fk_Correspondance" IS 'Une seule correspondance logique, même sans vue ou contexte explicite.';

--
-- Name: T_Admin_UI_Setting Uq_Admin_UI_Setting_Key_Scope; Type: CONSTRAINT; Schema: systeme; Owner: -
--

ALTER TABLE ONLY systeme."T_Admin_UI_Setting"
    ADD CONSTRAINT "Uq_Admin_UI_Setting_Key_Scope" UNIQUE NULLS NOT DISTINCT ("SettingScope", "ScopeValue", "SettingKey");

--
-- Name: CONSTRAINT "Uq_Admin_UI_Setting_Key_Scope" ON "T_Admin_UI_Setting"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "Uq_Admin_UI_Setting_Key_Scope" ON systeme."T_Admin_UI_Setting" IS 'Une seule clé par portée et contexte ; NULL global est une valeur unique.';

--
-- Name: T_Entite ck_entite_adresse_documentaire; Type: CHECK CONSTRAINT; Schema: systeme; Owner: -
--

ALTER TABLE systeme."T_Entite"
    ADD CONSTRAINT ck_entite_adresse_documentaire CHECK ((("AdresseEntite" IS NULL) OR ((char_length("AdresseEntite") <= 1000) AND (replace(replace("AdresseEntite", E'\r\n'::text, E'\n'::text), E'\n'::text, ''::text) !~ '[[:cntrl:]]'::text)))) NOT VALID;

--
-- Name: CONSTRAINT ck_entite_adresse_documentaire ON "T_Entite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT ck_entite_adresse_documentaire ON systeme."T_Entite" IS 'Nouvelles écritures d’adresse limitées à1000 caractères, avec LF/CRLF autorisés et autres contrôles refusés ; NOT VALID préserve les données historiques sans les réécrire.';

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

COMMENT ON INDEX systeme."UQ_FkCorrespondance_SourceValueScope" IS 'Index unique de la correspondance source/valeur/portée ; une vue ou un contexte NULL ne permet pas de doublon.';

--
-- Name: INDEX "Uq_Admin_UI_Setting_Key_Scope"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON INDEX systeme."Uq_Admin_UI_Setting_Key_Scope" IS 'Index unique de la clé de paramètre par portée et contexte ; NULLS NOT DISTINCT interdit aussi les doublons globaux.';

--
-- Name: audit_document_identites_new_gin; Type: INDEX; Schema: systeme; Owner: -
--

CREATE INDEX audit_document_identites_new_gin ON systeme."T_Audit_Log" USING gin (logistique.fn_identites_audit("NewData")) WHERE ("TableName" = ANY (ARRAY['logistique.T_Commande'::text, 'T_Commande'::text, 'logistique.T_Facture'::text]));

--
-- Name: INDEX audit_document_identites_new_gin; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON INDEX systeme.audit_document_identites_new_gin IS 'Identités de bons/factures présentes après une écriture auditée ; garde la non-réutilisation après suppression.';

--
-- Name: audit_document_identites_old_gin; Type: INDEX; Schema: systeme; Owner: -
--

CREATE INDEX audit_document_identites_old_gin ON systeme."T_Audit_Log" USING gin (logistique.fn_identites_audit("OldData")) WHERE ("TableName" = ANY (ARRAY['logistique.T_Commande'::text, 'T_Commande'::text, 'logistique.T_Facture'::text]));

--
-- Name: INDEX audit_document_identites_old_gin; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON INDEX systeme.audit_document_identites_old_gin IS 'Identités de bons/factures présentes avant une écriture auditée ; évite regex et parcours complet du journal à chaque réservation.';

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
-- Name: ix_support_audit_rejeu; Type: INDEX; Schema: systeme; Owner: -
--

CREATE UNIQUE INDEX ix_support_audit_rejeu ON systeme."T_Audit_Log" USING btree ("TableName", (("NewData" ->> 'requestId'::text)), ((("NewData" -> '_actor'::text) ->> 'IdUser'::text)), "IdEntiteFk") WHERE (("TableName" ~~ 'support.%'::text) AND (("NewData" ->> 'requestId'::text) IS NOT NULL));

--
-- Name: INDEX ix_support_audit_rejeu; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON INDEX systeme.ix_support_audit_rejeu IS 'Index du Support pour intégrité, recherche par parent/entreprise et preuve de requête ; aucune permission n’en découle.';

--
-- Name: uq_audit_immobilisation_request; Type: INDEX; Schema: systeme; Owner: -
--

CREATE UNIQUE INDEX uq_audit_immobilisation_request ON systeme."T_Audit_Log" USING btree ("IdEntiteFk", (("NewData" #>> '{_actor,IdUser}'::text[])), (("NewData" ->> 'requestId'::text))) WHERE (("TableName" = 'logistique.T_Immobilisation'::text) AND ("NewData" ? 'requestId'::text));

--
-- Name: INDEX uq_audit_immobilisation_request; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON INDEX systeme.uq_audit_immobilisation_request IS 'Une seule preuve UUID d’immobilisation par entreprise et auteur, quelle que soit l’opération ou le contenu ; le service compare hash/opération et sérialise les rejeux avant réponse.';

--
-- Name: uq_fk_champ_categorie_scope; Type: INDEX; Schema: systeme; Owner: -
--

CREATE UNIQUE INDEX uq_fk_champ_categorie_scope ON systeme."T_Fk_Correspondance" USING btree ("IdChampReferentielFk", "SettingScope", "ScopeValue", "MappingValue") NULLS NOT DISTINCT WHERE ("IdChampReferentielFk" IS NOT NULL);

--
-- Name: INDEX uq_fk_champ_categorie_scope; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON INDEX systeme.uq_fk_champ_categorie_scope IS 'Une occurrence par catégorie et portée dans le jeu canonique ; plusieurs catégories historiques restent représentables sans CSV.';

--
-- Name: uq_user_matricule_entite; Type: INDEX; Schema: systeme; Owner: -
--

CREATE UNIQUE INDEX uq_user_matricule_entite ON systeme."T_Utilisateurs" USING btree ("IdEntiteFk", lower(("MatriculeUser")::text)) NULLS NOT DISTINCT WHERE ("MatriculeUser" IS NOT NULL);

--
-- Name: INDEX uq_user_matricule_entite; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON INDEX systeme.uq_user_matricule_entite IS 'Matricule facultatif unique sans distinction de casse dans chaque entreprise ; les valeurs NULL ne représentent pas un matricule.';

--
-- Name: INDEX utilisateurs_emailuser_key; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON INDEX systeme.utilisateurs_emailuser_key IS 'Index d’unicité sur "systeme"."T_Utilisateurs". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX utilisateurs_emailuser_key ON systeme."T_Utilisateurs" USING btree ("EmailUser").';

--
-- Name: T_Fk_Correspondance a_correspondance_champ_integrite; Type: TRIGGER; Schema: systeme; Owner: -
--

CREATE TRIGGER a_correspondance_champ_integrite BEFORE INSERT OR DELETE OR UPDATE ON systeme."T_Fk_Correspondance" FOR EACH ROW EXECUTE FUNCTION systeme.tr_correspondance_champ_integrite();

--
-- Name: TRIGGER a_correspondance_champ_integrite ON "T_Fk_Correspondance"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON TRIGGER a_correspondance_champ_integrite ON systeme."T_Fk_Correspondance" IS 'Valide une correspondance canonique avant les dates/audits existants, sans remplacer les contrôles de droits applicatifs.';

--
-- Name: T_Entite_Localisation aa_localisation_patrimoine_proprietaire; Type: TRIGGER; Schema: systeme; Owner: -
--

CREATE TRIGGER aa_localisation_patrimoine_proprietaire BEFORE UPDATE OF "IdEntiteFk" ON systeme."T_Entite_Localisation" FOR EACH ROW EXECUTE FUNCTION systeme.tr_localisation_patrimoine_proprietaire();

--
-- Name: TRIGGER aa_localisation_patrimoine_proprietaire ON "T_Entite_Localisation"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON TRIGGER aa_localisation_patrimoine_proprietaire ON systeme."T_Entite_Localisation" IS 'Conserve le propriétaire des lieux d’affectation liés au patrimoine.';

--
-- Name: T_Entite aa_reference_champ; Type: TRIGGER; Schema: systeme; Owner: -
--

CREATE TRIGGER aa_reference_champ BEFORE INSERT OR UPDATE ON systeme."T_Entite" FOR EACH ROW EXECUTE FUNCTION referentiel.tr_valider_champ_referentiel();

--
-- Name: TRIGGER aa_reference_champ ON "T_Entite"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON TRIGGER aa_reference_champ ON systeme."T_Entite" IS 'Valide les nouvelles références du catalogue physique ; conserve les valeurs historiques inchangées, même devenues hors famille.';

--
-- Name: T_Licence aa_reference_champ; Type: TRIGGER; Schema: systeme; Owner: -
--

CREATE TRIGGER aa_reference_champ BEFORE INSERT OR UPDATE ON systeme."T_Licence" FOR EACH ROW EXECUTE FUNCTION referentiel.tr_valider_champ_referentiel();

--
-- Name: TRIGGER aa_reference_champ ON "T_Licence"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON TRIGGER aa_reference_champ ON systeme."T_Licence" IS 'Valide les nouvelles références du catalogue physique ; conserve les valeurs historiques inchangées, même devenues hors famille.';

--
-- Name: T_Login aa_reference_champ; Type: TRIGGER; Schema: systeme; Owner: -
--

CREATE TRIGGER aa_reference_champ BEFORE INSERT OR UPDATE ON systeme."T_Login" FOR EACH ROW EXECUTE FUNCTION referentiel.tr_valider_champ_referentiel();

--
-- Name: TRIGGER aa_reference_champ ON "T_Login"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON TRIGGER aa_reference_champ ON systeme."T_Login" IS 'Valide les nouvelles références du catalogue physique ; conserve les valeurs historiques inchangées, même devenues hors famille.';

--
-- Name: T_RoleModule aa_reference_champ; Type: TRIGGER; Schema: systeme; Owner: -
--

CREATE TRIGGER aa_reference_champ BEFORE INSERT OR UPDATE ON systeme."T_RoleModule" FOR EACH ROW EXECUTE FUNCTION referentiel.tr_valider_champ_referentiel();

--
-- Name: TRIGGER aa_reference_champ ON "T_RoleModule"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON TRIGGER aa_reference_champ ON systeme."T_RoleModule" IS 'Valide les nouvelles références du catalogue physique ; conserve les valeurs historiques inchangées, même devenues hors famille.';

--
-- Name: T_Utilisateurs aa_reference_champ; Type: TRIGGER; Schema: systeme; Owner: -
--

CREATE TRIGGER aa_reference_champ BEFORE INSERT OR UPDATE ON systeme."T_Utilisateurs" FOR EACH ROW EXECUTE FUNCTION referentiel.tr_valider_champ_referentiel();

--
-- Name: TRIGGER aa_reference_champ ON "T_Utilisateurs"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON TRIGGER aa_reference_champ ON systeme."T_Utilisateurs" IS 'Valide les nouvelles références du catalogue physique ; conserve les valeurs historiques inchangées, même devenues hors famille.';

--
-- Name: T_Utilisateurs aa_utilisateur_affectation_verifier; Type: TRIGGER; Schema: systeme; Owner: -
--

CREATE TRIGGER aa_utilisateur_affectation_verifier BEFORE INSERT OR UPDATE ON systeme."T_Utilisateurs" FOR EACH ROW EXECUTE FUNCTION systeme.tr_utilisateur_affectation_verifier();

--
-- Name: TRIGGER aa_utilisateur_affectation_verifier ON "T_Utilisateurs"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON TRIGGER aa_utilisateur_affectation_verifier ON systeme."T_Utilisateurs" IS 'Intégrité des nouvelles affectations professionnelles et conservation de l’entreprise des responsables de biens.';

--
-- Name: T_Fk_Correspondance ab_correspondance_categorie_portee; Type: TRIGGER; Schema: systeme; Owner: -
--

CREATE TRIGGER ab_correspondance_categorie_portee BEFORE INSERT OR UPDATE ON systeme."T_Fk_Correspondance" FOR EACH ROW EXECUTE FUNCTION systeme.tr_correspondance_categorie_portee();

--
-- Name: TRIGGER ab_correspondance_categorie_portee ON "T_Fk_Correspondance"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON TRIGGER ab_correspondance_categorie_portee ON systeme."T_Fk_Correspondance" IS 'Complète la garde canonique existante par la propriété de la catégorie choisie.';

--
-- Name: T_Utilisateurs ac_compte_professionnel_entreprise; Type: TRIGGER; Schema: systeme; Owner: -
--

CREATE TRIGGER ac_compte_professionnel_entreprise BEFORE UPDATE OF "IdEntiteFk" ON systeme."T_Utilisateurs" FOR EACH ROW EXECUTE FUNCTION professionnel.tr_compte_professionnel_entreprise();

--
-- Name: TRIGGER ac_compte_professionnel_entreprise ON "T_Utilisateurs"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON TRIGGER ac_compte_professionnel_entreprise ON systeme."T_Utilisateurs" IS 'Conserve la cohérence compte/entreprise du profil sans déplacement implicite des données.';

--
-- Name: T_LicenceModule licence_module_integrite; Type: TRIGGER; Schema: systeme; Owner: -
--

CREATE TRIGGER licence_module_integrite BEFORE INSERT OR UPDATE ON systeme."T_LicenceModule" FOR EACH ROW EXECUTE FUNCTION systeme.verifier_activation_module();

--
-- Name: TRIGGER licence_module_integrite ON "T_LicenceModule"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON TRIGGER licence_module_integrite ON systeme."T_LicenceModule" IS 'Rattachement licence/module immuable et versionné ; les dates de licence ne sont pas modifiées.';

--
-- Name: T_RoleModule role_module_integrite; Type: TRIGGER; Schema: systeme; Owner: -
--

CREATE TRIGGER role_module_integrite BEFORE INSERT OR UPDATE ON systeme."T_RoleModule" FOR EACH ROW EXECUTE FUNCTION systeme.verifier_activation_module();

--
-- Name: TRIGGER role_module_integrite ON "T_RoleModule"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON TRIGGER role_module_integrite ON systeme."T_RoleModule" IS 'Périmètre entité/rôle/module immuable ; les restrictions ne constituent pas un rôle administrateur.';

--
-- Name: T_Admin_UI_Setting support_circuit_valider; Type: TRIGGER; Schema: systeme; Owner: -
--

CREATE TRIGGER support_circuit_valider BEFORE INSERT OR UPDATE ON systeme."T_Admin_UI_Setting" FOR EACH ROW EXECUTE FUNCTION systeme.tr_support_circuit_valider();

--
-- Name: TRIGGER support_circuit_valider ON "T_Admin_UI_Setting"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON TRIGGER support_circuit_valider ON systeme."T_Admin_UI_Setting" IS 'Garde ou audit transactionnel du Support : identité, circuit, références, entreprise et conservation des preuves vérifiés par la fonction liée.';

--
-- Name: T_Utilisateurs support_user_proprietaire; Type: TRIGGER; Schema: systeme; Owner: -
--

CREATE TRIGGER support_user_proprietaire BEFORE UPDATE OF "IdEntiteFk" ON systeme."T_Utilisateurs" FOR EACH ROW EXECUTE FUNCTION support.tr_lien_proprietaire_conserver();

--
-- Name: TRIGGER support_user_proprietaire ON "T_Utilisateurs"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON TRIGGER support_user_proprietaire ON systeme."T_Utilisateurs" IS 'Garde ou audit transactionnel du Support : identité, circuit, références, entreprise et conservation des preuves vérifiés par la fonction liée.';

--
-- Name: T_Admin_UI_Setting tr_admin_ui_setting_audit; Type: TRIGGER; Schema: systeme; Owner: -
--

CREATE TRIGGER tr_admin_ui_setting_audit AFTER INSERT OR DELETE OR UPDATE ON systeme."T_Admin_UI_Setting" FOR EACH ROW EXECUTE FUNCTION systeme.fn_admin_reglage_audit();

--
-- Name: TRIGGER tr_admin_ui_setting_audit ON "T_Admin_UI_Setting"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON TRIGGER tr_admin_ui_setting_audit ON systeme."T_Admin_UI_Setting" IS 'Audit SQL unique des paramètres ; le backend ne produit pas un second événement.';

--
-- Name: T_Admin_UI_Setting tr_admin_ui_setting_proteger; Type: TRIGGER; Schema: systeme; Owner: -
--

CREATE TRIGGER tr_admin_ui_setting_proteger BEFORE DELETE OR UPDATE ON systeme."T_Admin_UI_Setting" FOR EACH ROW EXECUTE FUNCTION systeme.fn_admin_ui_setting_proteger();

--
-- Name: TRIGGER tr_admin_ui_setting_proteger ON "T_Admin_UI_Setting"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON TRIGGER tr_admin_ui_setting_proteger ON systeme."T_Admin_UI_Setting" IS 'Protection des identités système et des paramètres non éditables avant toute mise à jour ou suppression.';

--
-- Name: T_Admin_UI_Setting tr_admin_ui_setting_set_updated_at; Type: TRIGGER; Schema: systeme; Owner: -
--

CREATE TRIGGER tr_admin_ui_setting_set_updated_at BEFORE INSERT OR UPDATE ON systeme."T_Admin_UI_Setting" FOR EACH ROW EXECUTE FUNCTION systeme.fn_admin_ui_setting_set_updated_at();

--
-- Name: TRIGGER tr_admin_ui_setting_set_updated_at ON "T_Admin_UI_Setting"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON TRIGGER tr_admin_ui_setting_set_updated_at ON systeme."T_Admin_UI_Setting" IS 'Date et auteur SQL des paramètres ; les champs fournis par le client ne font pas foi.';

--
-- Name: T_Fk_Correspondance tr_fk_correspondance_actualiser; Type: TRIGGER; Schema: systeme; Owner: -
--

CREATE TRIGGER tr_fk_correspondance_actualiser BEFORE INSERT OR UPDATE ON systeme."T_Fk_Correspondance" FOR EACH ROW EXECUTE FUNCTION systeme.fn_fk_correspondance_actualiser();

--
-- Name: TRIGGER tr_fk_correspondance_actualiser ON "T_Fk_Correspondance"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON TRIGGER tr_fk_correspondance_actualiser ON systeme."T_Fk_Correspondance" IS 'Date et auteur SQL des correspondances avant insertion ou mise à jour.';

--
-- Name: T_Fk_Correspondance tr_fk_correspondance_audit; Type: TRIGGER; Schema: systeme; Owner: -
--

CREATE TRIGGER tr_fk_correspondance_audit AFTER INSERT OR DELETE OR UPDATE ON systeme."T_Fk_Correspondance" FOR EACH ROW EXECUTE FUNCTION systeme.fn_admin_reglage_audit();

--
-- Name: TRIGGER tr_fk_correspondance_audit ON "T_Fk_Correspondance"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON TRIGGER tr_fk_correspondance_audit ON systeme."T_Fk_Correspondance" IS 'Audit SQL unique des correspondances, compatible avec les remplacements transactionnels du réglage historique.';

--
-- Name: T_ModuleApplication tr_module_classification; Type: TRIGGER; Schema: systeme; Owner: -
--

CREATE TRIGGER tr_module_classification BEFORE INSERT OR UPDATE ON systeme."T_ModuleApplication" FOR EACH ROW EXECUTE FUNCTION systeme.tr_module_classification();

--
-- Name: TRIGGER tr_module_classification ON "T_ModuleApplication"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON TRIGGER tr_module_classification ON systeme."T_ModuleApplication" IS 'Valide la hiérarchie de présentation MODULE/FONCTIONNALITE lors de la saisie du catalogue.';

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
-- Name: T_Fk_Correspondance zz_correspondance_champ_revision; Type: TRIGGER; Schema: systeme; Owner: -
--

CREATE TRIGGER zz_correspondance_champ_revision AFTER INSERT OR DELETE OR UPDATE ON systeme."T_Fk_Correspondance" FOR EACH ROW EXECUTE FUNCTION systeme.tr_correspondance_champ_revision();

--
-- Name: TRIGGER zz_correspondance_champ_revision ON "T_Fk_Correspondance"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON TRIGGER zz_correspondance_champ_revision ON systeme."T_Fk_Correspondance" IS 'Invalide la révision du catalogue après changement de correspondance et conserve les audits existants.';

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
-- Name: T_Fk_Correspondance T_Fk_Correspondance_IdChampReferentielFk_fkey; Type: FK CONSTRAINT; Schema: systeme; Owner: -
--

ALTER TABLE ONLY systeme."T_Fk_Correspondance"
    ADD CONSTRAINT "T_Fk_Correspondance_IdChampReferentielFk_fkey" FOREIGN KEY ("IdChampReferentielFk") REFERENCES referentiel."T_ChampReferentiel"("ID_ChampReferentiel") ON DELETE RESTRICT;

--
-- Name: CONSTRAINT "T_Fk_Correspondance_IdChampReferentielFk_fkey" ON "T_Fk_Correspondance"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "T_Fk_Correspondance_IdChampReferentielFk_fkey" ON systeme."T_Fk_Correspondance" IS 'Intégrité du référencement physique : FOREIGN KEY ("IdChampReferentielFk") REFERENCES referentiel."T_ChampReferentiel"("ID_ChampReferentiel") ON DELETE RESTRICT';

--
-- Name: T_LicenceModule T_LicenceModule_CodeModule_fkey; Type: FK CONSTRAINT; Schema: systeme; Owner: -
--

ALTER TABLE ONLY systeme."T_LicenceModule"
    ADD CONSTRAINT "T_LicenceModule_CodeModule_fkey" FOREIGN KEY ("CodeModule") REFERENCES systeme."T_ModuleApplication"("CodeModule") ON DELETE RESTRICT;

--
-- Name: T_LicenceModule T_LicenceModule_IdLicenceFk_fkey; Type: FK CONSTRAINT; Schema: systeme; Owner: -
--

ALTER TABLE ONLY systeme."T_LicenceModule"
    ADD CONSTRAINT "T_LicenceModule_IdLicenceFk_fkey" FOREIGN KEY ("IdLicenceFk") REFERENCES systeme."T_Licence"("IdLicence") ON DELETE RESTRICT;

--
-- Name: T_LicenceModule T_LicenceModule_ModifieParUserFk_fkey; Type: FK CONSTRAINT; Schema: systeme; Owner: -
--

ALTER TABLE ONLY systeme."T_LicenceModule"
    ADD CONSTRAINT "T_LicenceModule_ModifieParUserFk_fkey" FOREIGN KEY ("ModifieParUserFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON DELETE SET NULL;

--
-- Name: T_ModuleApplication T_ModuleApplication_CodeIncluant_fkey; Type: FK CONSTRAINT; Schema: systeme; Owner: -
--

ALTER TABLE ONLY systeme."T_ModuleApplication"
    ADD CONSTRAINT "T_ModuleApplication_CodeIncluant_fkey" FOREIGN KEY ("CodeIncluant") REFERENCES systeme."T_ModuleApplication"("CodeModule") ON DELETE RESTRICT;

--
-- Name: T_RoleModule T_RoleModule_CodeModule_fkey; Type: FK CONSTRAINT; Schema: systeme; Owner: -
--

ALTER TABLE ONLY systeme."T_RoleModule"
    ADD CONSTRAINT "T_RoleModule_CodeModule_fkey" FOREIGN KEY ("CodeModule") REFERENCES systeme."T_ModuleApplication"("CodeModule") ON DELETE RESTRICT;

--
-- Name: T_RoleModule T_RoleModule_IdEntiteFk_fkey; Type: FK CONSTRAINT; Schema: systeme; Owner: -
--

ALTER TABLE ONLY systeme."T_RoleModule"
    ADD CONSTRAINT "T_RoleModule_IdEntiteFk_fkey" FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON DELETE RESTRICT;

--
-- Name: T_RoleModule T_RoleModule_IdRoleFk_fkey; Type: FK CONSTRAINT; Schema: systeme; Owner: -
--

ALTER TABLE ONLY systeme."T_RoleModule"
    ADD CONSTRAINT "T_RoleModule_IdRoleFk_fkey" FOREIGN KEY ("IdRoleFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON DELETE RESTRICT;

--
-- Name: T_RoleModule T_RoleModule_ModifieParUserFk_fkey; Type: FK CONSTRAINT; Schema: systeme; Owner: -
--

ALTER TABLE ONLY systeme."T_RoleModule"
    ADD CONSTRAINT "T_RoleModule_ModifieParUserFk_fkey" FOREIGN KEY ("ModifieParUserFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON DELETE SET NULL;

--
-- Name: T_Utilisateurs T_Utilisateurs_ID_FonctionFk_fkey; Type: FK CONSTRAINT; Schema: systeme; Owner: -
--

ALTER TABLE ONLY systeme."T_Utilisateurs"
    ADD CONSTRAINT "T_Utilisateurs_ID_FonctionFk_fkey" FOREIGN KEY ("ID_FonctionFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON DELETE RESTRICT;

--
-- Name: CONSTRAINT "T_Utilisateurs_ID_FonctionFk_fkey" ON "T_Utilisateurs"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "T_Utilisateurs_ID_FonctionFk_fkey" ON systeme."T_Utilisateurs" IS 'Métadonnée professionnelle facultative contrôlée : FOREIGN KEY ("ID_FonctionFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON DELETE RESTRICT. Ne donne aucun droit de sécurité.';

--
-- Name: T_Utilisateurs T_Utilisateurs_ID_ServiceFk_fkey; Type: FK CONSTRAINT; Schema: systeme; Owner: -
--

ALTER TABLE ONLY systeme."T_Utilisateurs"
    ADD CONSTRAINT "T_Utilisateurs_ID_ServiceFk_fkey" FOREIGN KEY ("ID_ServiceFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON DELETE RESTRICT;

--
-- Name: CONSTRAINT "T_Utilisateurs_ID_ServiceFk_fkey" ON "T_Utilisateurs"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT "T_Utilisateurs_ID_ServiceFk_fkey" ON systeme."T_Utilisateurs" IS 'Métadonnée professionnelle facultative contrôlée : FOREIGN KEY ("ID_ServiceFk") REFERENCES referentiel."T_Generique"("ID_Generique") ON DELETE RESTRICT. Ne donne aucun droit de sécurité.';

--
-- Name: T_ModuleApplication fk_module_parent; Type: FK CONSTRAINT; Schema: systeme; Owner: -
--

ALTER TABLE ONLY systeme."T_ModuleApplication"
    ADD CONSTRAINT fk_module_parent FOREIGN KEY ("ModuleParentCode") REFERENCES systeme."T_ModuleApplication"("CodeModule") ON DELETE RESTRICT;

--
-- Name: CONSTRAINT fk_module_parent ON "T_ModuleApplication"; Type: COMMENT; Schema: systeme; Owner: -
--

COMMENT ON CONSTRAINT fk_module_parent ON systeme."T_ModuleApplication" IS 'Le module parent existe et ne disparaît pas tant que des fonctionnalités le référencent.';
