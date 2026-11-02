-- Extrait canonique du catalogue installé le 02/11/2026, sans données ni propriétaires imposés.
-- Voir SQL/README.md. Ces extraits documentent le domaine ; utiliser le fichier global pour une installation vide.
SET check_function_bodies = false;
SELECT pg_catalog.set_config('search_path', '', false);
CREATE SCHEMA IF NOT EXISTS "referentiel";
--
-- Name: SCHEMA referentiel; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA referentiel IS 'Catégories et valeurs génériques utilisées pour les nomenclatures, statuts, types, unités et listes de référence.';

--
-- Name: fn_catalogue_tableau_verifier(); Type: FUNCTION; Schema: referentiel; Owner: -
--

CREATE FUNCTION referentiel.fn_catalogue_tableau_verifier() RETURNS trigger
    LANGUAGE plpgsql
    AS $_$
DECLARE c jsonb; ids text[]:='{}';
BEGIN
 IF jsonb_array_length(NEW."Colonnes") NOT BETWEEN 1 AND 100 THEN
  RAISE EXCEPTION 'Catalogue de colonnes invalide' USING ERRCODE='23514';
 END IF;
 FOR c IN SELECT value FROM jsonb_array_elements(NEW."Colonnes") LOOP
  IF jsonb_typeof(c)<>'object' OR c->>'id' IS NULL OR c->>'id' !~ '^[A-Za-z][A-Za-z0-9_]*$'
   OR c->>'label' IS NULL OR nullif(btrim(c->>'label'),'') IS NULL
   OR jsonb_typeof(c->'defaultVisible') IS DISTINCT FROM 'boolean'
   OR jsonb_typeof(c->'defaultExport') IS DISTINCT FROM 'boolean'
   OR jsonb_typeof(c->'exportable') IS DISTINCT FROM 'boolean'
   OR jsonb_typeof(c->'defaultOrder') IS DISTINCT FROM 'number'
   OR c->>'type' IS NULL OR c->>'id'=ANY(ids)
   OR (c->>'defaultExport'='true' AND c->>'exportable'<>'true')
   OR (c->>'id'='actions' AND c->>'exportable'<>'false') THEN
    RAISE EXCEPTION 'Définition de colonne invalide ou dupliquée' USING ERRCODE='23514';
  END IF;
  ids:=array_append(ids,c->>'id');
 END LOOP;
 IF TG_OP='UPDATE' THEN
  IF NEW."CleInterface" IS DISTINCT FROM OLD."CleInterface" OR NEW."Module" IS DISTINCT FROM OLD."Module" THEN
   RAISE EXCEPTION 'Identité du catalogue immuable' USING ERRCODE='23514';
  END IF;
  NEW."Version":=OLD."Version"+1;
 END IF;
 NEW."ModifieLe":=clock_timestamp();
 RETURN NEW;
END $_$;

--
-- Name: FUNCTION fn_catalogue_tableau_verifier(); Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON FUNCTION referentiel.fn_catalogue_tableau_verifier() IS 'Vérifie les identifiants, options et doublons du catalogue ; interdit l’export des actions et versionne ses modifications.';

--
-- Name: fn_categorie_visible(integer, integer); Type: FUNCTION; Schema: referentiel; Owner: -
--

CREATE FUNCTION referentiel.fn_categorie_visible(p_categorie integer, p_entite integer DEFAULT NULL::integer) RETURNS boolean
    LANGUAGE sql STABLE
    SET search_path TO 'pg_catalog'
    AS $$
 SELECT EXISTS(SELECT FROM referentiel."T_CategorieGenerique" c WHERE c."ID_CategorieGenerique"=p_categorie
  AND (c."IdEntiteFk" IS NULL OR c."IdEntiteFk"=p_entite)) $$;

--
-- Name: FUNCTION fn_categorie_visible(p_categorie integer, p_entite integer); Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON FUNCTION referentiel.fn_categorie_visible(p_categorie integer, p_entite integer) IS 'Visibilité de portée uniquement : catégorie commune ou de l’entreprise explicitement indiquée, jamais d’une autre. NULL entreprise ne désigne que les catégories communes ; validité contrôlée séparément.';

--
-- Name: fn_categories_champ(text, text, text, integer); Type: FUNCTION; Schema: referentiel; Owner: -
--

CREATE FUNCTION referentiel.fn_categories_champ(p_schema text, p_table text, p_colonne text, p_entite integer DEFAULT NULL::integer) RETURNS integer[]
    LANGUAGE sql STABLE
    SET search_path TO 'pg_catalog'
    AS $$ SELECT "CategoryIds" FROM referentiel.fn_resolution_champ(p_schema,p_table,p_colonne,p_entite) $$;

--
-- Name: FUNCTION fn_categories_champ(p_schema text, p_table text, p_colonne text, p_entite integer); Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON FUNCTION referentiel.fn_categories_champ(p_schema text, p_table text, p_colonne text, p_entite integer) IS 'Familles effectives du champ physique et de son entreprise. Vide signifie non configuré ; les scopes pays et visibilités historiques ne sont pas implicitement activés.';

--
-- Name: fn_entite_reference_champ(text, text, jsonb); Type: FUNCTION; Schema: referentiel; Owner: -
--

CREATE FUNCTION referentiel.fn_entite_reference_champ(p_schema text, p_table text, p_ligne jsonb) RETURNS integer
    LANGUAGE plpgsql STABLE
    SET search_path TO 'pg_catalog'
    AS $$
DECLARE owner_id integer;
BEGIN
 -- L'entreprise de l'utilisateur ou d'un résultat de recherche n'est pas
 -- un propriétaire durable d'une ligne partagée.
 IF p_ligne IS NULL OR NOT EXISTS(SELECT FROM referentiel."T_ChampReferentiel" WHERE "SchemaName"=p_schema AND "TableName"=p_table AND "SupportsEntityScope") THEN RETURN NULL;END IF;
 IF (p_schema,p_table)=('logistique','T_PrecisionStock') THEN
  SELECT "IdEntiteFk" INTO owner_id FROM referentiel."T_Generique" WHERE "ID_Generique"=nullif(p_ligne->>'ID_UniteFk','')::integer;RETURN owner_id;END IF;
 IF (p_schema,p_table)=('systeme','T_Entite') THEN RETURN nullif(p_ligne->>'IdEntite','')::integer;END IF;
 owner_id:=coalesce(nullif(p_ligne->>'IdEntiteFk','')::integer,nullif(p_ligne->>'ID_EntiteFk','')::integer);
 IF owner_id IS NOT NULL THEN RETURN owner_id;END IF;
 IF p_schema='support' AND p_table='T_ResolutionSupport' THEN
  SELECT "IdEntiteFk" INTO owner_id FROM support."T_Support" WHERE "ID_Support"=nullif(p_ligne->>'ID_SupportFk','')::bigint;RETURN owner_id;END IF;
 IF p_schema='logistique' THEN
  CASE p_table
   WHEN 'T_Mouvement' THEN
    SELECT "IdEntiteFk" INTO owner_id FROM logistique."T_Commande" WHERE "ID_Commande"=nullif(p_ligne->>'ID_cmdFk','')::integer;
    IF owner_id IS NULL THEN SELECT "IdEntiteFk" INTO owner_id FROM logistique."T_Article" WHERE "ID_Article"=nullif(p_ligne->>'ID_ArticleFk','')::integer;END IF;
   WHEN 'T_Reglements' THEN
    SELECT "IdEntiteFk" INTO owner_id FROM logistique."T_Facture" WHERE "CodeFacture"=p_ligne->>'CodeFactureFk';
    IF owner_id IS NULL THEN SELECT "IdEntiteFk" INTO owner_id FROM logistique."T_Commande" WHERE "CodeFacture"=p_ligne->>'CodeFactureFk';END IF;
   WHEN 'T_Remboursement' THEN SELECT "IdEntiteFk" INTO owner_id FROM logistique."T_Avoir" WHERE "ID_Avoir"=nullif(p_ligne->>'ID_AvoirFk','')::bigint;
   ELSE NULL;
  END CASE;
 END IF;
 RETURN owner_id;
END $$;

--
-- Name: FUNCTION fn_entite_reference_champ(p_schema text, p_table text, p_ligne jsonb); Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON FUNCTION referentiel.fn_entite_reference_champ(p_schema text, p_table text, p_ligne jsonb) IS 'Résout le propriétaire durable de la vraie ligne, y compris la résolution Support via son parent ; aucune entreprise déduite du compte actuel.';

--
-- Name: fn_guard_sens_stock(); Type: FUNCTION; Schema: referentiel; Owner: -
--

CREATE FUNCTION referentiel.fn_guard_sens_stock() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$
BEGIN
 IF EXISTS(SELECT FROM logistique."T_Commande" WHERE "ID_TypeCmdFk"=OLD."ID_Generique") OR EXISTS(SELECT FROM logistique."T_Mouvement" WHERE "ID_TypeMvtFk"=OLD."ID_Generique") THEN
  IF NEW."ID_CategorieGeneriqueFk" IS DISTINCT FROM OLD."ID_CategorieGeneriqueFk" OR logistique.fn_nature_type_bon(NEW."AbrGenerique") IS DISTINCT FROM logistique.fn_nature_type_bon(OLD."AbrGenerique") THEN
   RAISE EXCEPTION 'La nature d’un type de bon déjà utilisé ne peut pas changer.' USING ERRCODE='23514';END IF;
 END IF;RETURN NEW;
END $$;

--
-- Name: FUNCTION fn_guard_sens_stock(); Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON FUNCTION referentiel.fn_guard_sens_stock() IS 'Conserve le sens des types de bon déjà utilisés, dans toute famille actuelle ou ancienne, sans dépendre de l’identifiant historique64.';

--
-- Name: fn_normaliser_libelle(text); Type: FUNCTION; Schema: referentiel; Owner: -
--

CREATE FUNCTION referentiel.fn_normaliser_libelle(p_texte text) RETURNS text
    LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE
    SET search_path TO 'pg_catalog'
    AS $$
 SELECT lower(btrim(regexp_replace(p_texte,'[[:space:]'||chr(160)||']+',' ','g'))) $$;

--
-- Name: FUNCTION fn_normaliser_libelle(p_texte text); Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON FUNCTION referentiel.fn_normaliser_libelle(p_texte text) IS 'Clé de comparaison des libellés/codes : casse et espaces normalisés, y compris espace insécable. Les accents restent distincts ; la forme affichée et les identifiants ne sont jamais réécrits.';

--
-- Name: fn_preference_tableau_verifier(); Type: FUNCTION; Schema: referentiel; Owner: -
--

CREATE FUNCTION referentiel.fn_preference_tableau_verifier() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE c jsonb; id text; ids text[]:='{}'; defs jsonb; auteur integer; usr record;
BEGIN
 auteur:=systeme.fn_admin_actor_user_id();
 IF auteur IS NULL OR auteur IS DISTINCT FROM (CASE WHEN TG_OP='DELETE' THEN OLD."IdUserFk" ELSE NEW."IdUserFk" END) THEN
  RAISE EXCEPTION 'Auteur de préférence non autorisé' USING ERRCODE='23514';
 END IF;
 IF TG_OP='DELETE' THEN RETURN OLD; END IF;
 SELECT "Is_Admin","IdEntiteFk" INTO usr FROM systeme."T_Utilisateurs" WHERE "IdUser"=auteur;
 IF usr."Is_Admin" IS NOT TRUE AND (NEW."IdEntiteFk" IS NULL OR NEW."IdEntiteFk" IS DISTINCT FROM usr."IdEntiteFk") THEN
  RAISE EXCEPTION 'Préférence hors entreprise autorisée' USING ERRCODE='23514';
 END IF;
 SELECT "Colonnes" INTO defs FROM referentiel."T_InterfaceTableau" WHERE "CleInterface"=NEW."CleInterfaceFk" AND "Actif";
 IF defs IS NULL OR jsonb_array_length(NEW."Colonnes") NOT BETWEEN 1 AND 100 THEN
  RAISE EXCEPTION 'Colonnes de préférence invalides' USING ERRCODE='23514';
 END IF;
 FOR c IN SELECT value FROM jsonb_array_elements(NEW."Colonnes") LOOP
  id:=c#>>'{}';
  IF jsonb_typeof(c)<>'string' OR id=ANY(ids) OR NOT EXISTS (
    SELECT 1 FROM jsonb_array_elements(defs) d WHERE d->>'id'=id
      AND (CASE WHEN NEW."Usage"='export' THEN d->>'exportable'='true' ELSE coalesce(d->>'tableAvailable','true')='true' END)) THEN
   RAISE EXCEPTION 'Colonne inconnue, non exportable ou dupliquée' USING ERRCODE='23514';
  END IF;
  ids:=array_append(ids,id);
 END LOOP;
 IF TG_OP='UPDATE' THEN
  IF ROW(NEW."CleInterfaceFk",NEW."IdUserFk",NEW."IdEntiteFk",NEW."Usage") IS DISTINCT FROM
     ROW(OLD."CleInterfaceFk",OLD."IdUserFk",OLD."IdEntiteFk",OLD."Usage") THEN
   RAISE EXCEPTION 'Propriétaire et usage de préférence immuables' USING ERRCODE='23514';
  END IF;
 END IF;
 NEW."Version":=nextval('referentiel.seq_preference_tableau_revision');
 NEW."ModifieLe":=clock_timestamp();
 RETURN NEW;
END $$;

--
-- Name: FUNCTION fn_preference_tableau_verifier(); Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON FUNCTION referentiel.fn_preference_tableau_verifier() IS 'Contrôle SQL de l’auteur et entreprise, des colonnes autorisées et de l’indépendance tableau/export ; date et révise les modifications.';

--
-- Name: fn_reference_champ_connue(text, text, text, integer); Type: FUNCTION; Schema: referentiel; Owner: -
--

CREATE FUNCTION referentiel.fn_reference_champ_connue(p_schema text, p_table text, p_colonne text, p_valeur integer) RETURNS boolean
    LANGUAGE plpgsql STABLE
    SET search_path TO 'pg_catalog'
    AS $_$
DECLARE r referentiel."T_ChampReferentiel"; cat integer; used boolean;
BEGIN
 IF p_valeur IS NULL THEN RETURN true;END IF;
 SELECT * INTO r FROM referentiel."T_ChampReferentiel" WHERE "SchemaName"=p_schema AND "TableName"=p_table AND "ColumnName"=p_colonne;
 IF NOT FOUND THEN RETURN false;END IF;
 SELECT "ID_CategorieGeneriqueFk" INTO cat FROM referentiel."T_Generique" WHERE "ID_Generique"=p_valeur;
 IF NOT FOUND THEN RETURN false;END IF;
 IF cat=r."ID_CategorieDefautFk" OR (r."CanConfigure" AND EXISTS(SELECT FROM systeme."T_Fk_Correspondance" f
 WHERE f."MappingType"='generic_category' AND f."TargetCategoryIdFk"=cat AND (f."IdChampReferentielFk"=r."ID_ChampReferentiel" OR (f."IdChampReferentielFk" IS NULL AND f."SourceKey"=ANY(r."AliasSourceKeys"))))) THEN RETURN true;END IF;
 EXECUTE format('SELECT EXISTS(SELECT FROM %I.%I WHERE %I=$1)',p_schema,p_table,p_colonne) INTO used USING p_valeur;
 RETURN used;
END $_$;

--
-- Name: FUNCTION fn_reference_champ_connue(p_schema text, p_table text, p_colonne text, p_valeur integer); Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON FUNCTION referentiel.fn_reference_champ_connue(p_schema text, p_table text, p_colonne text, p_valeur integer) IS 'Reconnaissance de lecture et des procédures historiques : famille de référence, catégorie déclarée ou valeur déjà utilisée dans la vraie FK. Ne remplace jamais la validation stricte d’une nouvelle affectation.';

--
-- Name: fn_reference_visible(integer, integer); Type: FUNCTION; Schema: referentiel; Owner: -
--

CREATE FUNCTION referentiel.fn_reference_visible(p_valeur integer, p_entite integer DEFAULT NULL::integer) RETURNS boolean
    LANGUAGE sql STABLE
    SET search_path TO 'pg_catalog'
    AS $$
 SELECT EXISTS(SELECT FROM referentiel."T_Generique" g WHERE g."ID_Generique"=p_valeur
  AND (g."IdEntiteFk" IS NULL OR g."IdEntiteFk"=p_entite)
  AND referentiel.fn_categorie_visible(g."ID_CategorieGeneriqueFk",p_entite)) $$;

--
-- Name: FUNCTION fn_reference_visible(p_valeur integer, p_entite integer); Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON FUNCTION referentiel.fn_reference_visible(p_valeur integer, p_entite integer) IS 'Visibilité d’une valeur et de sa famille dans le même périmètre commun/entreprise, sans autorisation d’accès supplémentaire. Ne confond ni valeur inactive ni référence hors catégorie avec une autre entreprise.';

--
-- Name: fn_resolution_champ(text, text, text, integer); Type: FUNCTION; Schema: referentiel; Owner: -
--

CREATE FUNCTION referentiel.fn_resolution_champ(p_schema text, p_table text, p_colonne text, p_entite integer DEFAULT NULL::integer) RETURNS TABLE("CategoryIds" integer[], "OrigineReglage" text)
    LANGUAGE sql STABLE
    SET search_path TO 'pg_catalog'
    AS $$
 WITH champ AS (SELECT * FROM referentiel."T_ChampReferentiel" WHERE "SchemaName"=p_schema AND "TableName"=p_table AND "ColumnName"=p_colonne),
 candidates AS (
 SELECT f.*,CASE WHEN f."SettingScope"='entity' THEN CASE WHEN f."IdChampReferentielFk" IS NOT NULL THEN 1 ELSE 2 END ELSE CASE WHEN f."IdChampReferentielFk" IS NOT NULL THEN 3 ELSE 4 END END priority
 FROM champ c JOIN systeme."T_Fk_Correspondance" f ON (f."IdChampReferentielFk"=c."ID_ChampReferentiel" OR (f."IdChampReferentielFk" IS NULL AND f."SourceKey"=ANY(c."AliasSourceKeys")))
 WHERE c."CanConfigure" AND f."MappingType"='generic_category' AND f."ValideFkCorrespondance"
 AND ((f."SettingScope"='global' AND f."ScopeValue" IS NULL) OR (c."SupportsEntityScope" AND f."SettingScope"='entity' AND f."ScopeValue"=p_entite::text))
 ), chosen AS (SELECT * FROM candidates WHERE priority=(SELECT min(priority) FROM candidates)),
 resolved AS (SELECT CASE WHEN EXISTS(SELECT FROM chosen) THEN
 CASE WHEN EXISTS(SELECT FROM chosen WHERE "MappingValue"='@default') THEN ARRAY_REMOVE(ARRAY[c."ID_CategorieDefautFk"],NULL)
 ELSE ARRAY(SELECT DISTINCT "TargetCategoryIdFk" FROM chosen WHERE "TargetCategoryIdFk" IS NOT NULL ORDER BY "TargetCategoryIdFk") END
 ELSE ARRAY_REMOVE(ARRAY[c."ID_CategorieDefautFk"],NULL) END ids,
 CASE WHEN EXISTS(SELECT FROM chosen WHERE "MappingValue"='@default') THEN CASE WHEN c."ID_CategorieDefautFk" IS NULL THEN 'non_configure' ELSE 'defaut' END
 WHEN EXISTS(SELECT FROM chosen WHERE "SettingScope"='entity') THEN 'entity'
 WHEN EXISTS(SELECT FROM chosen) THEN 'global'
 WHEN c."ID_CategorieDefautFk" IS NULL THEN 'non_configure' ELSE 'defaut' END origin FROM champ c)
 SELECT coalesce((SELECT ids FROM resolved),'{}'::integer[]),coalesce((SELECT origin FROM resolved),'inconnu') $$;

--
-- Name: FUNCTION fn_resolution_champ(p_schema text, p_table text, p_colonne text, p_entite integer); Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON FUNCTION referentiel.fn_resolution_champ(p_schema text, p_table text, p_colonne text, p_entite integer) IS 'Résolution canonique : entreprise puis global, jeu canonique avant alias au même scope, puis défaut immuable. Un marqueur explicite @default ne retombe jamais sur une ancienne surcharge.';

--
-- Name: fn_valider_reference_champ(text, text, text, integer, integer); Type: FUNCTION; Schema: referentiel; Owner: -
--

CREATE FUNCTION referentiel.fn_valider_reference_champ(p_schema text, p_table text, p_colonne text, p_valeur integer, p_entite integer DEFAULT NULL::integer) RETURNS boolean
    LANGUAGE sql STABLE
    SET search_path TO 'pg_catalog'
    AS $$
 SELECT p_valeur IS NULL OR EXISTS(SELECT FROM referentiel."T_Generique" g JOIN referentiel."T_CategorieGenerique" c ON c."ID_CategorieGenerique"=g."ID_CategorieGeneriqueFk"
  JOIN referentiel."T_ChampReferentiel" r ON r."SchemaName"=p_schema AND r."TableName"=p_table AND r."ColumnName"=p_colonne
  WHERE g."ID_Generique"=p_valeur AND g."ValideGenerique" AND c."ValideCategorieGenerique"
   AND g."ID_CategorieGeneriqueFk"=ANY(referentiel.fn_categories_champ(p_schema,p_table,p_colonne,p_entite))
   AND referentiel.fn_reference_visible(p_valeur,CASE WHEN r."SupportsEntityScope" THEN p_entite END)) $$;

--
-- Name: FUNCTION fn_valider_reference_champ(p_schema text, p_table text, p_colonne text, p_valeur integer, p_entite integer); Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON FUNCTION referentiel.fn_valider_reference_champ(p_schema text, p_table text, p_colonne text, p_valeur integer, p_entite integer) IS 'Nouvelle sélection active de la catégorie configurée et de la portée propriétaire réelle. Les champs communs excluent toutes les valeurs privées ; les références historiques inchangées restent gérées par la garde physique existante.';

--
-- Name: tr_catalogue_champ_integrite(); Type: FUNCTION; Schema: referentiel; Owner: -
--

CREATE FUNCTION referentiel.tr_catalogue_champ_integrite() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$
BEGIN
 IF TG_OP='DELETE' THEN RAISE EXCEPTION 'Catalogue physique conservé.' USING ERRCODE='23514';END IF;
 IF TG_OP='INSERT' THEN
  IF NOT EXISTS(SELECT FROM pg_constraint k JOIN pg_class t ON t.oid=k.conrelid JOIN pg_namespace n ON n.oid=t.relnamespace
   JOIN pg_attribute a ON a.attrelid=t.oid AND a.attnum=ANY(k.conkey) WHERE k.contype='f' AND k.confrelid='referentiel."T_Generique"'::regclass
   AND n.nspname=NEW."SchemaName" AND t.relname=NEW."TableName" AND a.attname=NEW."ColumnName") THEN RAISE EXCEPTION 'Colonne physique à FK non prouvée.' USING ERRCODE='23514';END IF;
  RETURN NEW;
 END IF;
 IF (to_jsonb(NEW)-ARRAY['Revision','ModifieLe','ModifieParUserFk']) IS DISTINCT FROM (to_jsonb(OLD)-ARRAY['Revision','ModifieLe','ModifieParUserFk']) OR pg_trigger_depth()<2 THEN
  RAISE EXCEPTION 'Définition et catégorie de référence immuables ; utilisez les correspondances courantes.' USING ERRCODE='23514';END IF;
 RETURN NEW;
END $$;

--
-- Name: FUNCTION tr_catalogue_champ_integrite(); Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON FUNCTION referentiel.tr_catalogue_champ_integrite() IS 'Conserve la clé physique, le défaut prouvé et la politique de sécurité ; seule une révision interne issue des correspondances peut modifier les métadonnées. Un chargement initial doit prouver la vraie FK ; les clés déjà installées sont uniques.';

--
-- Name: tr_categorie_portee_doublon(); Type: FUNCTION; Schema: referentiel; Owner: -
--

CREATE FUNCTION referentiel.tr_categorie_portee_doublon() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$
DECLARE normalise text; duplicate_id integer;
BEGIN
 IF TG_OP='UPDATE' AND NEW."IdEntiteFk" IS DISTINCT FROM OLD."IdEntiteFk" THEN
  RAISE EXCEPTION 'La portée d’une catégorie enregistrée est conservée.' USING ERRCODE='23514',CONSTRAINT='ck_categorie_portee_immuable';END IF;
 normalise:=referentiel.fn_normaliser_libelle(NEW."NomCategorieGenerique");
 IF TG_OP='UPDATE' AND normalise IS NOT DISTINCT FROM referentiel.fn_normaliser_libelle(OLD."NomCategorieGenerique") THEN RETURN NEW;END IF;
 IF coalesce(normalise,'')='' THEN RAISE EXCEPTION 'Indiquez le libellé de la catégorie.' USING ERRCODE='23514',CONSTRAINT='ck_categorie_nom_requis';END IF;
 -- Un verrou commun sérialise les lots de catégories dans un ordre unique.
 PERFORM pg_advisory_xact_lock(hashtextextended('referentiel:categories:identite',0));
 SELECT "ID_CategorieGenerique" INTO duplicate_id FROM referentiel."T_CategorieGenerique" c
  WHERE c."ID_CategorieGenerique"<>NEW."ID_CategorieGenerique"
   AND referentiel.fn_normaliser_libelle(c."NomCategorieGenerique")=normalise
   AND (NEW."IdEntiteFk" IS NULL OR c."IdEntiteFk" IS NULL OR c."IdEntiteFk"=NEW."IdEntiteFk") LIMIT 1;
 IF FOUND THEN RAISE EXCEPTION 'Une catégorie de même nom existe déjà dans cette portée.' USING ERRCODE='23505',CONSTRAINT='uq_categorie_nom_effectif';END IF;
 RETURN NEW;
END $$;

--
-- Name: FUNCTION tr_categorie_portee_doublon(); Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON FUNCTION referentiel.tr_categorie_portee_doublon() IS 'Propriété immuable et noms non vides non ambigus entre commun et entreprise. Les identités historiques inchangées restent modifiables descriptivement ; le verrou transactionnel interdit les doublons concurrents.';

--
-- Name: tr_generique_portee_doublon(); Type: FUNCTION; Schema: referentiel; Owner: -
--

CREATE FUNCTION referentiel.tr_generique_portee_doublon() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$
DECLARE famille_entite integer; nom text; code text; nom_change boolean; code_change boolean;
BEGIN
 IF TG_OP='UPDATE' AND NEW."IdEntiteFk" IS DISTINCT FROM OLD."IdEntiteFk" THEN
  RAISE EXCEPTION 'La portée d’une valeur enregistrée est conservée.' USING ERRCODE='23514',CONSTRAINT='ck_generique_portee_immuable';END IF;
 SELECT "IdEntiteFk" INTO famille_entite FROM referentiel."T_CategorieGenerique" WHERE "ID_CategorieGenerique"=NEW."ID_CategorieGeneriqueFk" FOR SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Catégorie introuvable.' USING ERRCODE='23503';END IF;
 IF famille_entite IS NOT NULL AND NEW."IdEntiteFk" IS DISTINCT FROM famille_entite THEN
  RAISE EXCEPTION 'Une valeur de catégorie privée appartient à la même entreprise.' USING ERRCODE='23514',CONSTRAINT='ck_generique_categorie_portee';END IF;
 IF NEW."IdEntiteFk" IS NOT NULL AND EXISTS(SELECT FROM referentiel."T_ChampReferentiel" r
  WHERE NOT r."CanConfigure" AND r."ID_CategorieDefautFk"=NEW."ID_CategorieGeneriqueFk") THEN
  RAISE EXCEPTION 'Les valeurs d’une famille de sécurité restent communes.' USING ERRCODE='23514',CONSTRAINT='ck_generique_securite_commune';END IF;
 nom:=referentiel.fn_normaliser_libelle(NEW."NomGenerique");code:=referentiel.fn_normaliser_libelle(NEW."AbrGenerique");
 nom_change:=TG_OP='INSERT';code_change:=TG_OP='INSERT';
 IF TG_OP='UPDATE' THEN
  nom_change:=nom IS DISTINCT FROM referentiel.fn_normaliser_libelle(OLD."NomGenerique") OR NEW."ID_CategorieGeneriqueFk" IS DISTINCT FROM OLD."ID_CategorieGeneriqueFk";
  code_change:=code IS DISTINCT FROM referentiel.fn_normaliser_libelle(OLD."AbrGenerique") OR NEW."ID_CategorieGeneriqueFk" IS DISTINCT FROM OLD."ID_CategorieGeneriqueFk";
 END IF;
 IF NOT(nom_change OR code_change) THEN RETURN NEW;END IF;
 IF nom_change AND coalesce(nom,'')='' THEN RAISE EXCEPTION 'Indiquez le libellé de la valeur.' USING ERRCODE='23514',CONSTRAINT='ck_generique_nom_requis';END IF;
 -- Une famille est commune au lot de valeurs, comme l’en-tête d’un bon.
 PERFORM pg_advisory_xact_lock(hashtextextended('referentiel:valeurs:'||NEW."ID_CategorieGeneriqueFk"::text,0));
 IF nom_change AND EXISTS(SELECT FROM referentiel."T_Generique" g WHERE g."ID_Generique"<>NEW."ID_Generique" AND g."ID_CategorieGeneriqueFk"=NEW."ID_CategorieGeneriqueFk"
  AND referentiel.fn_normaliser_libelle(g."NomGenerique")=nom AND (NEW."IdEntiteFk" IS NULL OR g."IdEntiteFk" IS NULL OR g."IdEntiteFk"=NEW."IdEntiteFk")) THEN
  RAISE EXCEPTION 'Un libellé identique existe déjà dans cette catégorie et cette portée.' USING ERRCODE='23505',CONSTRAINT='uq_generique_nom_effectif';END IF;
 IF code_change AND coalesce(code,'')<>'' AND EXISTS(SELECT FROM referentiel."T_Generique" g WHERE g."ID_Generique"<>NEW."ID_Generique" AND g."ID_CategorieGeneriqueFk"=NEW."ID_CategorieGeneriqueFk"
  AND referentiel.fn_normaliser_libelle(g."AbrGenerique")=code AND (NEW."IdEntiteFk" IS NULL OR g."IdEntiteFk" IS NULL OR g."IdEntiteFk"=NEW."IdEntiteFk")) THEN
  RAISE EXCEPTION 'Un code identique existe déjà dans cette catégorie et cette portée.' USING ERRCODE='23505',CONSTRAINT='uq_generique_code_effectif';END IF;
 RETURN NEW;
END $$;

--
-- Name: FUNCTION tr_generique_portee_doublon(); Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON FUNCTION referentiel.tr_generique_portee_doublon() IS 'Cohérence de propriétaire catégorie/valeur et contrôle des nouveaux libellés/codes, sérialisé par famille. Les familles de sécurité non configurables restent communes. Un doublon privé entre entreprises distinctes reste autorisé ; aucun ancien doublon n’est fusionné ou effacé.';

--
-- Name: tr_reference_utilisee_integrite(); Type: FUNCTION; Schema: referentiel; Owner: -
--

CREATE FUNCTION referentiel.tr_reference_utilisee_integrite() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $_$
DECLARE r record; used boolean;
BEGIN
 IF TG_OP='UPDATE' AND NEW."ID_Generique" IS NOT DISTINCT FROM OLD."ID_Generique" AND NEW."ID_CategorieGeneriqueFk" IS NOT DISTINCT FROM OLD."ID_CategorieGeneriqueFk" THEN RETURN NEW;END IF;
 FOR r IN SELECT "SchemaName" s,"TableName" t,"ColumnName" col FROM referentiel."T_ChampReferentiel" LOOP
  EXECUTE format('SELECT EXISTS(SELECT FROM %I.%I WHERE %I=$1)',r.s,r.t,r.col) INTO used USING OLD."ID_Generique";
  IF used THEN RAISE EXCEPTION 'Identité et famille d’une référence utilisée sont conservées ; désactivez-la si nécessaire.' USING ERRCODE='23514';END IF;
 END LOOP;
 RETURN CASE WHEN TG_OP='DELETE' THEN OLD ELSE NEW END;
END $_$;

--
-- Name: FUNCTION tr_reference_utilisee_integrite(); Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON FUNCTION referentiel.tr_reference_utilisee_integrite() IS 'Empêche une suppression/cascade ou migration de famille d’une valeur déjà utilisée dans les FK physiques, afin de préserver les historiques. Désactivation et changement de libellé restent distincts.';

--
-- Name: tr_valider_champ_referentiel(); Type: FUNCTION; Schema: referentiel; Owner: -
--

CREATE FUNCTION referentiel.tr_valider_champ_referentiel() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'pg_catalog'
    AS $$
DECLARE r record; before_data jsonb; after_data jsonb:=to_jsonb(NEW); owner_id integer; old_owner integer; value_id integer; parent_data jsonb; parent_column text;
BEGIN
 IF TG_OP='UPDATE' THEN before_data:=to_jsonb(OLD);END IF;
 owner_id:=referentiel.fn_entite_reference_champ(TG_TABLE_SCHEMA,TG_TABLE_NAME,after_data);
 old_owner:=referentiel.fn_entite_reference_champ(TG_TABLE_SCHEMA,TG_TABLE_NAME,before_data);
 IF TG_TABLE_SCHEMA='logistique' THEN
  IF TG_TABLE_NAME='T_Mouvement' THEN
   SELECT to_jsonb(c) INTO parent_data FROM logistique."T_Commande" c WHERE c."ID_Commande"=(after_data->>'ID_cmdFk')::integer;
   IF parent_data IS NULL THEN SELECT to_jsonb(a) INTO parent_data FROM logistique."T_Article" a WHERE a."ID_Article"=(after_data->>'ID_ArticleFk')::integer;END IF;
  ELSIF TG_TABLE_NAME IN('T_Facture','T_Avoir') THEN SELECT to_jsonb(c) INTO parent_data FROM logistique."T_Commande" c WHERE c."ID_Commande"=(after_data->>'ID_CommandeFk')::integer;
  ELSIF TG_TABLE_NAME='T_Reglements' THEN SELECT to_jsonb(c) INTO parent_data FROM logistique."T_Facture" c WHERE c."CodeFacture"=after_data->>'CodeFactureFk';
  ELSIF TG_TABLE_NAME='T_Remboursement' THEN SELECT to_jsonb(c) INTO parent_data FROM logistique."T_Avoir" c WHERE c."ID_Avoir"=(after_data->>'ID_AvoirFk')::bigint;
  ELSIF TG_TABLE_NAME='T_ValorisationOuverture' THEN SELECT to_jsonb(a) INTO parent_data FROM logistique."T_Article" a WHERE a."ID_Article"=(after_data->>'ID_ArticleFk')::integer;
  END IF;
 END IF;
 FOR r IN SELECT * FROM referentiel."T_ChampReferentiel" WHERE "SchemaName"=TG_TABLE_SCHEMA AND "TableName"=TG_TABLE_NAME ORDER BY "ID_ChampReferentiel" LOOP
  IF TG_OP='UPDATE' AND after_data->r."ColumnName" IS NOT DISTINCT FROM before_data->r."ColumnName" AND owner_id IS NOT DISTINCT FROM old_owner THEN CONTINUE;END IF;
  value_id:=nullif(after_data->>r."ColumnName",'')::integer;
  IF value_id IS NOT NULL THEN PERFORM 1 FROM referentiel."T_Generique" WHERE "ID_Generique"=value_id FOR SHARE;END IF;
  -- Une référence financière/physique copiée exactement du parent historique
  -- reste celle du parent, même après changement de la catégorie proposée.
  parent_column:=CASE WHEN TG_TABLE_NAME='T_Mouvement' AND r."ColumnName"='ID_TypeMvtFk' THEN 'ID_TypeCmdFk' ELSE r."ColumnName" END;
  IF TG_TABLE_SCHEMA='logistique' AND parent_data IS NOT NULL AND (
   r."ColumnName"='ID_DeviseFk' OR (TG_TABLE_NAME='T_Mouvement' AND r."ColumnName"='ID_TypeMvtFk')
   OR (TG_TABLE_NAME='T_Facture' AND r."ColumnName" IN('ID_ModePaiementFk','ID_ConditionPaiementFk')))
   AND owner_id IS NOT DISTINCT FROM (parent_data->>'IdEntiteFk')::integer
   AND value_id IS NOT NULL AND after_data->r."ColumnName" IS NOT DISTINCT FROM parent_data->parent_column THEN CONTINUE;END IF;
  IF NOT referentiel.fn_valider_reference_champ(TG_TABLE_SCHEMA,TG_TABLE_NAME,r."ColumnName",value_id,owner_id) THEN
   RAISE EXCEPTION 'Référence inactive ou incompatible pour %.%.%.',TG_TABLE_SCHEMA,TG_TABLE_NAME,r."ColumnName" USING ERRCODE='23514';END IF;
 END LOOP;
 RETURN NEW;
END $$;

--
-- Name: FUNCTION tr_valider_champ_referentiel(); Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON FUNCTION referentiel.tr_valider_champ_referentiel() IS 'Garde de toutes les FK cataloguées : INSERT ou changement effectif de valeur/entreprise seulement. Une référence historique inchangée reste consultable et autorise une modification descriptive.';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: T_Generique; Type: TABLE; Schema: referentiel; Owner: -
--

CREATE TABLE referentiel."T_Generique" (
    "ID_Generique" integer CONSTRAINT "T_Generique_ID_Generique_not_null" NOT NULL,
    "ID_CategorieGeneriqueFk" integer CONSTRAINT "T_Generique_ID_CategorieGeneriqueFk_not_null" NOT NULL,
    "NomGenerique" character varying(255) CONSTRAINT "T_Generique_NomGenerique_not_null" NOT NULL,
    "AbrGenerique" character varying(255),
    "VisibleNiveau_2" boolean DEFAULT true,
    "VisibleNiveau_3" boolean DEFAULT true,
    "VisibleNiveau_4" boolean DEFAULT true,
    "VisibleNiveau_5" boolean DEFAULT true,
    "VisibleArticle" boolean DEFAULT true,
    "VisibleCmd" boolean DEFAULT true,
    "VisibleFacture" boolean DEFAULT true,
    "VisibleUsers" boolean DEFAULT true,
    "VisibleVoie" boolean DEFAULT true,
    "VisibleAll" boolean DEFAULT true,
    "ObsGenerique" text,
    "ValideGenerique" boolean DEFAULT true CONSTRAINT "T_Generique_ValideGenerique_not_null" NOT NULL,
    "IdEntiteFk" integer
);

--
-- Name: TABLE "T_Generique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON TABLE referentiel."T_Generique" IS 'Valeurs du référentiel, identifiées par ID_Generique, classées par catégorie et protégées par une portée commune ou entreprise ; les drapeaux de visibilité historiques restent distincts.';

--
-- Name: COLUMN "T_Generique"."ID_Generique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."T_Generique"."ID_Generique" IS 'Identifiant d’une valeur de nomenclature.';

--
-- Name: COLUMN "T_Generique"."ID_CategorieGeneriqueFk"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."T_Generique"."ID_CategorieGeneriqueFk" IS 'Catégorie à laquelle appartient cette valeur de nomenclature. Relation imposée : FOREIGN KEY ("ID_CategorieGeneriqueFk") REFERENCES referentiel."T_CategorieGenerique"("ID_CategorieGenerique") ON UPDATE CASCADE.';

--
-- Name: COLUMN "T_Generique"."NomGenerique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."T_Generique"."NomGenerique" IS 'Libellé métier de la valeur de nomenclature.';

--
-- Name: COLUMN "T_Generique"."AbrGenerique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."T_Generique"."AbrGenerique" IS 'Abréviation de la valeur de nomenclature ; peut porter un code de type utilisé par les règles métier.';

--
-- Name: COLUMN "T_Generique"."VisibleNiveau_2"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."T_Generique"."VisibleNiveau_2" IS 'Indicateur de visibilité pour le niveau géographique de niveau 2.';

--
-- Name: COLUMN "T_Generique"."VisibleNiveau_3"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."T_Generique"."VisibleNiveau_3" IS 'Indicateur de visibilité pour le niveau géographique de niveau 3.';

--
-- Name: COLUMN "T_Generique"."VisibleNiveau_4"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."T_Generique"."VisibleNiveau_4" IS 'Indicateur de visibilité pour le niveau géographique de niveau 4.';

--
-- Name: COLUMN "T_Generique"."VisibleNiveau_5"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."T_Generique"."VisibleNiveau_5" IS 'Indicateur de visibilité pour le niveau géographique de niveau 5.';

--
-- Name: COLUMN "T_Generique"."VisibleArticle"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."T_Generique"."VisibleArticle" IS 'Indique la visibilité de la valeur de nomenclature pour les articles.';

--
-- Name: COLUMN "T_Generique"."VisibleCmd"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."T_Generique"."VisibleCmd" IS 'Indique la visibilité de la valeur de nomenclature pour les commandes.';

--
-- Name: COLUMN "T_Generique"."VisibleFacture"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."T_Generique"."VisibleFacture" IS 'Indique la visibilité de la valeur de nomenclature pour les factures.';

--
-- Name: COLUMN "T_Generique"."VisibleUsers"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."T_Generique"."VisibleUsers" IS 'Indique la visibilité de la valeur de nomenclature pour les utilisateurs.';

--
-- Name: COLUMN "T_Generique"."VisibleVoie"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."T_Generique"."VisibleVoie" IS 'Indique la visibilité de la valeur de nomenclature pour les voies d’accès.';

--
-- Name: COLUMN "T_Generique"."VisibleAll"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."T_Generique"."VisibleAll" IS 'Indique la visibilité générale de la valeur de nomenclature.';

--
-- Name: COLUMN "T_Generique"."ObsGenerique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."T_Generique"."ObsGenerique" IS 'Observations enregistrées sur la valeur de nomenclature.';

--
-- Name: COLUMN "T_Generique"."ValideGenerique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."T_Generique"."ValideGenerique" IS 'Indique si la valeur de nomenclature est déclaré valide/actif dans le registre ; distinct des qualifications calculées dans les vues.';

--
-- Name: COLUMN "T_Generique"."IdEntiteFk"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."T_Generique"."IdEntiteFk" IS 'Propriétaire durable facultatif : NULL commun, sinon valeur privée de cette entreprise. Une catégorie privée impose la même entreprise ; aucune réattribution des données antérieures.';

--
-- Name: CONSTRAINT "T_Generique_ID_Generique_not_null" ON "T_Generique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON CONSTRAINT "T_Generique_ID_Generique_not_null" ON referentiel."T_Generique" IS 'Non-nullité : exige une valeur renseignée dans "referentiel"."T_Generique". Définition : NOT NULL "ID_Generique".';

--
-- Name: CONSTRAINT "T_Generique_ID_CategorieGeneriqueFk_not_null" ON "T_Generique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON CONSTRAINT "T_Generique_ID_CategorieGeneriqueFk_not_null" ON referentiel."T_Generique" IS 'Non-nullité : exige une valeur renseignée dans "referentiel"."T_Generique". Définition : NOT NULL "ID_CategorieGeneriqueFk".';

--
-- Name: CONSTRAINT "T_Generique_NomGenerique_not_null" ON "T_Generique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON CONSTRAINT "T_Generique_NomGenerique_not_null" ON referentiel."T_Generique" IS 'Non-nullité : exige une valeur renseignée dans "referentiel"."T_Generique". Définition : NOT NULL "NomGenerique".';

--
-- Name: CONSTRAINT "T_Generique_ValideGenerique_not_null" ON "T_Generique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON CONSTRAINT "T_Generique_ValideGenerique_not_null" ON referentiel."T_Generique" IS 'Non-nullité : exige une valeur renseignée dans "referentiel"."T_Generique". Définition : NOT NULL "ValideGenerique".';

--
-- Name: T_CategorieGenerique; Type: TABLE; Schema: referentiel; Owner: -
--

CREATE TABLE referentiel."T_CategorieGenerique" (
    "ID_CategorieGenerique" integer CONSTRAINT "T_CategorieGenerique_ID_CategorieGenerique_not_null" NOT NULL,
    "NomCategorieGenerique" character varying(255),
    "ModuleCategorieGenerique" text,
    "ValideCategorieGenerique" boolean DEFAULT true,
    "IdEntiteFk" integer
);

--
-- Name: TABLE "T_CategorieGenerique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON TABLE referentiel."T_CategorieGenerique" IS 'Familles transversales communes ou propres à une entreprise, réutilisées par les champs catalogués. Identifiants et familles antérieures conservés.';

--
-- Name: COLUMN "T_CategorieGenerique"."ID_CategorieGenerique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."T_CategorieGenerique"."ID_CategorieGenerique" IS 'Identifiant de la catégorie de nomenclature.';

--
-- Name: COLUMN "T_CategorieGenerique"."NomCategorieGenerique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."T_CategorieGenerique"."NomCategorieGenerique" IS 'Libellé de la catégorie de nomenclature.';

--
-- Name: COLUMN "T_CategorieGenerique"."ModuleCategorieGenerique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."T_CategorieGenerique"."ModuleCategorieGenerique" IS 'Module ou domaine d’usage de la catégorie de nomenclature.';

--
-- Name: COLUMN "T_CategorieGenerique"."ValideCategorieGenerique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."T_CategorieGenerique"."ValideCategorieGenerique" IS 'Indique si la catégorie est déclaré valide/actif dans le registre ; distinct des qualifications calculées dans les vues.';

--
-- Name: COLUMN "T_CategorieGenerique"."IdEntiteFk"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."T_CategorieGenerique"."IdEntiteFk" IS 'Propriétaire durable facultatif : NULL désigne le référentiel commun. Toutes les catégories antérieures restent communes ; une propriété enregistrée est immuable.';

--
-- Name: CONSTRAINT "T_CategorieGenerique_ID_CategorieGenerique_not_null" ON "T_CategorieGenerique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON CONSTRAINT "T_CategorieGenerique_ID_CategorieGenerique_not_null" ON referentiel."T_CategorieGenerique" IS 'Non-nullité : exige une valeur renseignée dans "referentiel"."T_CategorieGenerique". Définition : NOT NULL "ID_CategorieGenerique".';

--
-- Name: T_CategorieGenerique_ID_CategorieGenerique_seq; Type: SEQUENCE; Schema: referentiel; Owner: -
--

ALTER TABLE referentiel."T_CategorieGenerique" ALTER COLUMN "ID_CategorieGenerique" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME referentiel."T_CategorieGenerique_ID_CategorieGenerique_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

--
-- Name: SEQUENCE "T_CategorieGenerique_ID_CategorieGenerique_seq"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON SEQUENCE referentiel."T_CategorieGenerique_ID_CategorieGenerique_seq" IS 'Séquence de génération de "referentiel"."T_CategorieGenerique"."ID_CategorieGenerique". Les valeurs produites identifient les enregistrements ; les écarts de numérotation ne prouvent pas une suppression.';

--
-- Name: T_ChampReferentiel; Type: TABLE; Schema: referentiel; Owner: -
--

CREATE TABLE referentiel."T_ChampReferentiel" (
    "ID_ChampReferentiel" integer CONSTRAINT "T_ChampReferentiel_ID_ChampReferentiel_not_null" NOT NULL,
    "SchemaName" character varying(80) CONSTRAINT "T_ChampReferentiel_SchemaName_not_null" NOT NULL,
    "TableName" character varying(120) CONSTRAINT "T_ChampReferentiel_TableName_not_null" NOT NULL,
    "ColumnName" character varying(120) CONSTRAINT "T_ChampReferentiel_ColumnName_not_null" NOT NULL,
    "ChampLabel" character varying(255) CONSTRAINT "T_ChampReferentiel_ChampLabel_not_null" NOT NULL,
    "ModuleName" character varying(80) CONSTRAINT "T_ChampReferentiel_ModuleName_not_null" NOT NULL,
    "ID_CategorieDefautFk" integer,
    "AliasSourceKeys" text[] DEFAULT '{}'::text[] CONSTRAINT "T_ChampReferentiel_AliasSourceKeys_not_null" NOT NULL,
    "CanConfigure" boolean DEFAULT true CONSTRAINT "T_ChampReferentiel_CanConfigure_not_null" NOT NULL,
    "SupportsEntityScope" boolean DEFAULT false CONSTRAINT "T_ChampReferentiel_SupportsEntityScope_not_null" NOT NULL,
    "Revision" bigint DEFAULT 1 CONSTRAINT "T_ChampReferentiel_Revision_not_null" NOT NULL,
    "CreeLe" timestamp with time zone DEFAULT clock_timestamp() CONSTRAINT "T_ChampReferentiel_CreeLe_not_null" NOT NULL,
    "ModifieLe" timestamp with time zone DEFAULT clock_timestamp() CONSTRAINT "T_ChampReferentiel_ModifieLe_not_null" NOT NULL,
    "ModifieParUserFk" integer,
    CONSTRAINT "T_ChampReferentiel_Revision_check" CHECK (("Revision" > 0)),
    CONSTRAINT ck_champ_identifiants CHECK (((("SchemaName")::text = btrim(("SchemaName")::text)) AND (("TableName")::text = btrim(("TableName")::text)) AND (("ColumnName")::text = btrim(("ColumnName")::text)) AND (length(("SchemaName")::text) > 0) AND (length(("TableName")::text) > 0) AND (length(("ColumnName")::text) > 0)))
);

--
-- Name: TABLE "T_ChampReferentiel"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON TABLE referentiel."T_ChampReferentiel" IS 'Catalogue unique des colonnes physiques à FK vers T_Generique ; famille de référence immuable et alias explicites, aucun choix courant dupliqué.';

--
-- Name: COLUMN "T_ChampReferentiel"."ID_ChampReferentiel"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."T_ChampReferentiel"."ID_ChampReferentiel" IS 'Identifiant immuable d’une colonne physique cataloguée, jamais déduit de sa position affichée.';

--
-- Name: COLUMN "T_ChampReferentiel"."SchemaName"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."T_ChampReferentiel"."SchemaName" IS 'Schéma réel de la table possédant une clé étrangère vers T_Generique.';

--
-- Name: COLUMN "T_ChampReferentiel"."TableName"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."T_ChampReferentiel"."TableName" IS 'Nom réel et sensible à la casse de la table propriétaire de la clé étrangère.';

--
-- Name: COLUMN "T_ChampReferentiel"."ColumnName"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."T_ChampReferentiel"."ColumnName" IS 'Nom physique exact de la colonne de référence ; la clé étrangère est prouvée au catalogue PostgreSQL.';

--
-- Name: COLUMN "T_ChampReferentiel"."ChampLabel"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."T_ChampReferentiel"."ChampLabel" IS 'Libellé métier du champ pour lecture et diagnostic, distinct de son identifiant SQL.';

--
-- Name: COLUMN "T_ChampReferentiel"."ModuleName"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."T_ChampReferentiel"."ModuleName" IS 'Domaine du champ, utilisé pour le catalogue et les correspondances, sans accorder de droits.';

--
-- Name: COLUMN "T_ChampReferentiel"."ID_CategorieDefautFk"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."T_ChampReferentiel"."ID_CategorieDefautFk" IS 'Famille de référence prouvée et immuable ; NULL signifie absence de preuve, aucune famille inventée.';

--
-- Name: COLUMN "T_ChampReferentiel"."AliasSourceKeys"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."T_ChampReferentiel"."AliasSourceKeys" IS 'Anciens SourceKey explicitement associés à cette vraie FK pour compatibilité des réglages hérités.';

--
-- Name: COLUMN "T_ChampReferentiel"."CanConfigure"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."T_ChampReferentiel"."CanConfigure" IS 'Autorise une surcharge de catégorie ; false protège notamment la famille des rôles de sécurité.';

--
-- Name: COLUMN "T_ChampReferentiel"."SupportsEntityScope"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."T_ChampReferentiel"."SupportsEntityScope" IS 'Politique immuable de portée : true seulement si la vraie ligne possède une entreprise directe, sa propre PK Entité ou un parent logistique prouvé. Les tables partagées restent globales, sans entreprise déduite de leur utilisateur.';

--
-- Name: COLUMN "T_ChampReferentiel"."Revision"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."T_ChampReferentiel"."Revision" IS 'Révision opaque incrémentée pour toute modification de jeu canonique ou alias, afin de détecter les écritures concurrentes.';

--
-- Name: COLUMN "T_ChampReferentiel"."CreeLe"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."T_ChampReferentiel"."CreeLe" IS 'Instant réel de création du catalogue physique.';

--
-- Name: COLUMN "T_ChampReferentiel"."ModifieLe"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."T_ChampReferentiel"."ModifieLe" IS 'Instant réel de la dernière modification de correspondance touchant le champ.';

--
-- Name: COLUMN "T_ChampReferentiel"."ModifieParUserFk"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."T_ChampReferentiel"."ModifieParUserFk" IS 'Auteur factuel du dernier réglage si prouvé ; NULL pour installation et absence de contexte.';

--
-- Name: CONSTRAINT "T_ChampReferentiel_ID_ChampReferentiel_not_null" ON "T_ChampReferentiel"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON CONSTRAINT "T_ChampReferentiel_ID_ChampReferentiel_not_null" ON referentiel."T_ChampReferentiel" IS 'Intégrité du référencement physique : NOT NULL "ID_ChampReferentiel"';

--
-- Name: CONSTRAINT "T_ChampReferentiel_SchemaName_not_null" ON "T_ChampReferentiel"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON CONSTRAINT "T_ChampReferentiel_SchemaName_not_null" ON referentiel."T_ChampReferentiel" IS 'Intégrité du référencement physique : NOT NULL "SchemaName"';

--
-- Name: CONSTRAINT "T_ChampReferentiel_TableName_not_null" ON "T_ChampReferentiel"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON CONSTRAINT "T_ChampReferentiel_TableName_not_null" ON referentiel."T_ChampReferentiel" IS 'Intégrité du référencement physique : NOT NULL "TableName"';

--
-- Name: CONSTRAINT "T_ChampReferentiel_ColumnName_not_null" ON "T_ChampReferentiel"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON CONSTRAINT "T_ChampReferentiel_ColumnName_not_null" ON referentiel."T_ChampReferentiel" IS 'Intégrité du référencement physique : NOT NULL "ColumnName"';

--
-- Name: CONSTRAINT "T_ChampReferentiel_ChampLabel_not_null" ON "T_ChampReferentiel"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON CONSTRAINT "T_ChampReferentiel_ChampLabel_not_null" ON referentiel."T_ChampReferentiel" IS 'Intégrité du référencement physique : NOT NULL "ChampLabel"';

--
-- Name: CONSTRAINT "T_ChampReferentiel_ModuleName_not_null" ON "T_ChampReferentiel"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON CONSTRAINT "T_ChampReferentiel_ModuleName_not_null" ON referentiel."T_ChampReferentiel" IS 'Intégrité du référencement physique : NOT NULL "ModuleName"';

--
-- Name: CONSTRAINT "T_ChampReferentiel_AliasSourceKeys_not_null" ON "T_ChampReferentiel"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON CONSTRAINT "T_ChampReferentiel_AliasSourceKeys_not_null" ON referentiel."T_ChampReferentiel" IS 'Intégrité du référencement physique : NOT NULL "AliasSourceKeys"';

--
-- Name: CONSTRAINT "T_ChampReferentiel_CanConfigure_not_null" ON "T_ChampReferentiel"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON CONSTRAINT "T_ChampReferentiel_CanConfigure_not_null" ON referentiel."T_ChampReferentiel" IS 'Intégrité du référencement physique : NOT NULL "CanConfigure"';

--
-- Name: CONSTRAINT "T_ChampReferentiel_SupportsEntityScope_not_null" ON "T_ChampReferentiel"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON CONSTRAINT "T_ChampReferentiel_SupportsEntityScope_not_null" ON referentiel."T_ChampReferentiel" IS 'Intégrité du référencement physique : NOT NULL "SupportsEntityScope"';

--
-- Name: CONSTRAINT "T_ChampReferentiel_Revision_not_null" ON "T_ChampReferentiel"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON CONSTRAINT "T_ChampReferentiel_Revision_not_null" ON referentiel."T_ChampReferentiel" IS 'Intégrité du référencement physique : NOT NULL "Revision"';

--
-- Name: CONSTRAINT "T_ChampReferentiel_CreeLe_not_null" ON "T_ChampReferentiel"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON CONSTRAINT "T_ChampReferentiel_CreeLe_not_null" ON referentiel."T_ChampReferentiel" IS 'Intégrité du référencement physique : NOT NULL "CreeLe"';

--
-- Name: CONSTRAINT "T_ChampReferentiel_ModifieLe_not_null" ON "T_ChampReferentiel"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON CONSTRAINT "T_ChampReferentiel_ModifieLe_not_null" ON referentiel."T_ChampReferentiel" IS 'Intégrité du référencement physique : NOT NULL "ModifieLe"';

--
-- Name: CONSTRAINT "T_ChampReferentiel_Revision_check" ON "T_ChampReferentiel"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON CONSTRAINT "T_ChampReferentiel_Revision_check" ON referentiel."T_ChampReferentiel" IS 'Intégrité du référencement physique : CHECK ("Revision" > 0)';

--
-- Name: CONSTRAINT ck_champ_identifiants ON "T_ChampReferentiel"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON CONSTRAINT ck_champ_identifiants ON referentiel."T_ChampReferentiel" IS 'Intégrité du référencement physique : CHECK ("SchemaName"::text = btrim("SchemaName"::text) AND "TableName"::text = btrim("TableName"::text) AND "ColumnName"::text = btrim("ColumnName"::text) AND length("SchemaName"::text) > 0 AND length("TableName"::text) > 0 AND length("ColumnName"::text) > 0)';

--
-- Name: T_ChampReferentiel_ID_ChampReferentiel_seq; Type: SEQUENCE; Schema: referentiel; Owner: -
--

ALTER TABLE referentiel."T_ChampReferentiel" ALTER COLUMN "ID_ChampReferentiel" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME referentiel."T_ChampReferentiel_ID_ChampReferentiel_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

--
-- Name: SEQUENCE "T_ChampReferentiel_ID_ChampReferentiel_seq"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON SEQUENCE referentiel."T_ChampReferentiel_ID_ChampReferentiel_seq" IS 'Identités techniques du catalogue physique ; aucune relation par nom affiché ou position de ligne.';

--
-- Name: T_Generique_ID_Generique_seq; Type: SEQUENCE; Schema: referentiel; Owner: -
--

ALTER TABLE referentiel."T_Generique" ALTER COLUMN "ID_Generique" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME referentiel."T_Generique_ID_Generique_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

--
-- Name: SEQUENCE "T_Generique_ID_Generique_seq"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON SEQUENCE referentiel."T_Generique_ID_Generique_seq" IS 'Séquence de génération de "referentiel"."T_Generique"."ID_Generique". Les valeurs produites identifient les enregistrements ; les écarts de numérotation ne prouvent pas une suppression.';

--
-- Name: T_InterfaceTableau; Type: TABLE; Schema: referentiel; Owner: -
--

CREATE TABLE referentiel."T_InterfaceTableau" (
    "CleInterface" text CONSTRAINT "T_InterfaceTableau_CleInterface_not_null" NOT NULL,
    "Module" text CONSTRAINT "T_InterfaceTableau_Module_not_null" NOT NULL,
    "Version" integer DEFAULT 1 CONSTRAINT "T_InterfaceTableau_Version_not_null" NOT NULL,
    "Colonnes" jsonb CONSTRAINT "T_InterfaceTableau_Colonnes_not_null" NOT NULL,
    "Actif" boolean DEFAULT true CONSTRAINT "T_InterfaceTableau_Actif_not_null" NOT NULL,
    "ModifieLe" timestamp with time zone DEFAULT clock_timestamp() CONSTRAINT "T_InterfaceTableau_ModifieLe_not_null" NOT NULL,
    CONSTRAINT "T_InterfaceTableau_Colonnes_check" CHECK ((jsonb_typeof("Colonnes") = 'array'::text)),
    CONSTRAINT "T_InterfaceTableau_Version_check" CHECK (("Version" > 0)),
    CONSTRAINT ck_interface_tableau_cle CHECK (("CleInterface" ~ '^[a-z]+[.][a-z-]+$'::text)),
    CONSTRAINT ck_interface_tableau_module CHECK (("Module" = ANY (ARRAY['logistique'::text, 'referentiels'::text, 'administration'::text, 'territoires'::text, 'support'::text, 'caisse'::text])))
);

--
-- Name: TABLE "T_InterfaceTableau"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON TABLE referentiel."T_InterfaceTableau" IS 'Catalogue commun versionné des colonnes autorisées et des configurations de référence des tableaux et exports. Aucune donnée métier ni secret.';

--
-- Name: COLUMN "T_InterfaceTableau"."CleInterface"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."T_InterfaceTableau"."CleInterface" IS 'Identifiant stable de l’interface, indépendant du libellé et de l’ordre physique des colonnes SQL.';

--
-- Name: COLUMN "T_InterfaceTableau"."Module"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."T_InterfaceTableau"."Module" IS 'Module dont les droits sont revérifiés par le serveur, une préférence ne donnant aucun accès.';

--
-- Name: COLUMN "T_InterfaceTableau"."Version"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."T_InterfaceTableau"."Version" IS 'Version de référence du catalogue ; les identifiants des colonnes restent stables entre évolutions.';

--
-- Name: COLUMN "T_InterfaceTableau"."Colonnes"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."T_InterfaceTableau"."Colonnes" IS 'Définitions ordonnées : id, label, type, exportable, defaultVisible, defaultExport et defaultOrder.';

--
-- Name: COLUMN "T_InterfaceTableau"."Actif"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."T_InterfaceTableau"."Actif" IS 'Disponibilité de cette configuration, sans supprimer les préférences existantes.';

--
-- Name: COLUMN "T_InterfaceTableau"."ModifieLe"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."T_InterfaceTableau"."ModifieLe" IS 'Horodatage de la dernière évolution du catalogue commun.';

--
-- Name: CONSTRAINT "T_InterfaceTableau_CleInterface_not_null" ON "T_InterfaceTableau"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON CONSTRAINT "T_InterfaceTableau_CleInterface_not_null" ON referentiel."T_InterfaceTableau" IS 'Chaque catalogue possède un identifiant stable d’interface renseigné.';

--
-- Name: CONSTRAINT "T_InterfaceTableau_Module_not_null" ON "T_InterfaceTableau"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON CONSTRAINT "T_InterfaceTableau_Module_not_null" ON referentiel."T_InterfaceTableau" IS 'Le module propriétaire du catalogue doit être renseigné pour vérifier les droits.';

--
-- Name: CONSTRAINT "T_InterfaceTableau_Version_not_null" ON "T_InterfaceTableau"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON CONSTRAINT "T_InterfaceTableau_Version_not_null" ON referentiel."T_InterfaceTableau" IS 'La version de référence du catalogue est toujours connue.';

--
-- Name: CONSTRAINT "T_InterfaceTableau_Colonnes_not_null" ON "T_InterfaceTableau"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON CONSTRAINT "T_InterfaceTableau_Colonnes_not_null" ON referentiel."T_InterfaceTableau" IS 'La définition ordonnée des colonnes ne peut être absente.';

--
-- Name: CONSTRAINT "T_InterfaceTableau_Actif_not_null" ON "T_InterfaceTableau"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON CONSTRAINT "T_InterfaceTableau_Actif_not_null" ON referentiel."T_InterfaceTableau" IS 'La disponibilité du catalogue doit être définie explicitement.';

--
-- Name: CONSTRAINT "T_InterfaceTableau_ModifieLe_not_null" ON "T_InterfaceTableau"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON CONSTRAINT "T_InterfaceTableau_ModifieLe_not_null" ON referentiel."T_InterfaceTableau" IS 'La date technique de mise à jour du catalogue reste renseignée.';

--
-- Name: CONSTRAINT "T_InterfaceTableau_Colonnes_check" ON "T_InterfaceTableau"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON CONSTRAINT "T_InterfaceTableau_Colonnes_check" ON referentiel."T_InterfaceTableau" IS 'Le catalogue de colonnes est un tableau JSON ordonné.';

--
-- Name: CONSTRAINT "T_InterfaceTableau_Version_check" ON "T_InterfaceTableau"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON CONSTRAINT "T_InterfaceTableau_Version_check" ON referentiel."T_InterfaceTableau" IS 'Version de référence strictement positive.';

--
-- Name: CONSTRAINT ck_interface_tableau_cle ON "T_InterfaceTableau"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON CONSTRAINT ck_interface_tableau_cle ON referentiel."T_InterfaceTableau" IS 'Format fermé module.interface pour les identifiants stables.';

--
-- Name: CONSTRAINT ck_interface_tableau_module ON "T_InterfaceTableau"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON CONSTRAINT ck_interface_tableau_module ON referentiel."T_InterfaceTableau" IS 'Modules autorisés pour les tableaux et exports : Logistique, Référentiels, Administration, Territoires, Support et Caisse. La liste ne définit aucun droit ni abonnement.';

--
-- Name: seq_preference_tableau_revision; Type: SEQUENCE; Schema: referentiel; Owner: -
--

CREATE SEQUENCE referentiel.seq_preference_tableau_revision
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: SEQUENCE seq_preference_tableau_revision; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON SEQUENCE referentiel.seq_preference_tableau_revision IS 'Révisions uniques, y compris après réinitialisation puis recréation ; une ancienne version ne peut redevenir actuelle.';

--
-- Name: T_PreferenceTableau; Type: TABLE; Schema: referentiel; Owner: -
--

CREATE TABLE referentiel."T_PreferenceTableau" (
    "ID_PreferenceTableau" bigint CONSTRAINT "T_PreferenceTableau_ID_PreferenceTableau_not_null" NOT NULL,
    "CleInterfaceFk" text CONSTRAINT "T_PreferenceTableau_CleInterfaceFk_not_null" NOT NULL,
    "IdUserFk" integer CONSTRAINT "T_PreferenceTableau_IdUserFk_not_null" NOT NULL,
    "IdEntiteFk" integer,
    "Usage" text CONSTRAINT "T_PreferenceTableau_Usage_not_null" NOT NULL,
    "Colonnes" jsonb CONSTRAINT "T_PreferenceTableau_Colonnes_not_null" NOT NULL,
    "Version" bigint DEFAULT nextval('referentiel.seq_preference_tableau_revision'::regclass) CONSTRAINT "T_PreferenceTableau_Version_not_null" NOT NULL,
    "ModifieLe" timestamp with time zone DEFAULT clock_timestamp() CONSTRAINT "T_PreferenceTableau_ModifieLe_not_null" NOT NULL,
    CONSTRAINT "T_PreferenceTableau_Colonnes_check" CHECK ((jsonb_typeof("Colonnes") = 'array'::text)),
    CONSTRAINT "T_PreferenceTableau_Usage_check" CHECK (("Usage" = ANY (ARRAY['table'::text, 'export'::text]))),
    CONSTRAINT "T_PreferenceTableau_Version_check" CHECK (("Version" > 0))
);

--
-- Name: TABLE "T_PreferenceTableau"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON TABLE referentiel."T_PreferenceTableau" IS 'Préférences personnelles persistantes de colonnes et ordre, isolées par utilisateur, entreprise et usage tableau/export. Les valeurs communes restent dans T_InterfaceTableau.';

--
-- Name: COLUMN "T_PreferenceTableau"."ID_PreferenceTableau"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."T_PreferenceTableau"."ID_PreferenceTableau" IS 'Identifiant technique de la préférence, distinct de l’interface et des données métier.';

--
-- Name: COLUMN "T_PreferenceTableau"."CleInterfaceFk"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."T_PreferenceTableau"."CleInterfaceFk" IS 'Catalogue autorisé de l’interface concernée.';

--
-- Name: COLUMN "T_PreferenceTableau"."IdUserFk"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."T_PreferenceTableau"."IdUserFk" IS 'Utilisateur propriétaire exclusif du choix personnel ; aucun identifiant utilisateur reçu du navigateur.';

--
-- Name: COLUMN "T_PreferenceTableau"."IdEntiteFk"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."T_PreferenceTableau"."IdEntiteFk" IS 'Entreprise du contexte de préférence ; NULL uniquement pour la vue toutes entreprises d’un administrateur global.';

--
-- Name: COLUMN "T_PreferenceTableau"."Usage"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."T_PreferenceTableau"."Usage" IS 'table règle les colonnes visibles ; export règle Excel et CSV indépendamment du tableau.';

--
-- Name: COLUMN "T_PreferenceTableau"."Colonnes"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."T_PreferenceTableau"."Colonnes" IS 'Identifiants stables des colonnes choisies, dans l’ordre exact à afficher ou exporter ; les absentes ne sont pas sélectionnées.';

--
-- Name: COLUMN "T_PreferenceTableau"."Version"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."T_PreferenceTableau"."Version" IS 'Révision optimiste : refuse l’écrasement d’une préférence modifiée dans un autre navigateur.';

--
-- Name: COLUMN "T_PreferenceTableau"."ModifieLe"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON COLUMN referentiel."T_PreferenceTableau"."ModifieLe" IS 'Horodatage SQL de la dernière modification de la préférence personnelle.';

--
-- Name: CONSTRAINT "T_PreferenceTableau_ID_PreferenceTableau_not_null" ON "T_PreferenceTableau"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON CONSTRAINT "T_PreferenceTableau_ID_PreferenceTableau_not_null" ON referentiel."T_PreferenceTableau" IS 'Toute préférence possède son identifiant technique généré.';

--
-- Name: CONSTRAINT "T_PreferenceTableau_CleInterfaceFk_not_null" ON "T_PreferenceTableau"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON CONSTRAINT "T_PreferenceTableau_CleInterfaceFk_not_null" ON referentiel."T_PreferenceTableau" IS 'La préférence référence nécessairement une interface existante.';

--
-- Name: CONSTRAINT "T_PreferenceTableau_IdUserFk_not_null" ON "T_PreferenceTableau"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON CONSTRAINT "T_PreferenceTableau_IdUserFk_not_null" ON referentiel."T_PreferenceTableau" IS 'Le propriétaire personnel de la préférence reste obligatoire.';

--
-- Name: CONSTRAINT "T_PreferenceTableau_Usage_not_null" ON "T_PreferenceTableau"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON CONSTRAINT "T_PreferenceTableau_Usage_not_null" ON referentiel."T_PreferenceTableau" IS 'L’usage tableau ou export est toujours précisé pour préserver leur indépendance.';

--
-- Name: CONSTRAINT "T_PreferenceTableau_Colonnes_not_null" ON "T_PreferenceTableau"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON CONSTRAINT "T_PreferenceTableau_Colonnes_not_null" ON referentiel."T_PreferenceTableau" IS 'La liste ordonnée des colonnes choisies reste renseignée.';

--
-- Name: CONSTRAINT "T_PreferenceTableau_Version_not_null" ON "T_PreferenceTableau"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON CONSTRAINT "T_PreferenceTableau_Version_not_null" ON referentiel."T_PreferenceTableau" IS 'Une révision persistée est nécessaire pour contrôler les modifications concurrentes.';

--
-- Name: CONSTRAINT "T_PreferenceTableau_ModifieLe_not_null" ON "T_PreferenceTableau"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON CONSTRAINT "T_PreferenceTableau_ModifieLe_not_null" ON referentiel."T_PreferenceTableau" IS 'La date technique de dernière modification de la préférence est obligatoire.';

--
-- Name: CONSTRAINT "T_PreferenceTableau_Colonnes_check" ON "T_PreferenceTableau"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON CONSTRAINT "T_PreferenceTableau_Colonnes_check" ON referentiel."T_PreferenceTableau" IS 'Les choix ordonnés sont un tableau JSON.';

--
-- Name: CONSTRAINT "T_PreferenceTableau_Usage_check" ON "T_PreferenceTableau"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON CONSTRAINT "T_PreferenceTableau_Usage_check" ON referentiel."T_PreferenceTableau" IS 'Séparation explicite des configurations tableau et export.';

--
-- Name: CONSTRAINT "T_PreferenceTableau_Version_check" ON "T_PreferenceTableau"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON CONSTRAINT "T_PreferenceTableau_Version_check" ON referentiel."T_PreferenceTableau" IS 'La révision persistée est strictement positive ; zéro indique l’absence de préférence via API.';

--
-- Name: T_PreferenceTableau_ID_PreferenceTableau_seq; Type: SEQUENCE; Schema: referentiel; Owner: -
--

ALTER TABLE referentiel."T_PreferenceTableau" ALTER COLUMN "ID_PreferenceTableau" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME referentiel."T_PreferenceTableau_ID_PreferenceTableau_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

--
-- Name: SEQUENCE "T_PreferenceTableau_ID_PreferenceTableau_seq"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON SEQUENCE referentiel."T_PreferenceTableau_ID_PreferenceTableau_seq" IS 'Séquence technique des préférences personnelles de tableaux.';

--
-- Name: T_Generique Pk_T_Generique; Type: CONSTRAINT; Schema: referentiel; Owner: -
--

ALTER TABLE ONLY referentiel."T_Generique"
    ADD CONSTRAINT "Pk_T_Generique" PRIMARY KEY ("ID_Generique");

--
-- Name: CONSTRAINT "Pk_T_Generique" ON "T_Generique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON CONSTRAINT "Pk_T_Generique" ON referentiel."T_Generique" IS 'Clé primaire : identifie de manière unique chaque ligne dans "referentiel"."T_Generique". Définition : PRIMARY KEY ("ID_Generique").';

--
-- Name: T_CategorieGenerique T_CategorieGenerique_pkey; Type: CONSTRAINT; Schema: referentiel; Owner: -
--

ALTER TABLE ONLY referentiel."T_CategorieGenerique"
    ADD CONSTRAINT "T_CategorieGenerique_pkey" PRIMARY KEY ("ID_CategorieGenerique");

--
-- Name: CONSTRAINT "T_CategorieGenerique_pkey" ON "T_CategorieGenerique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON CONSTRAINT "T_CategorieGenerique_pkey" ON referentiel."T_CategorieGenerique" IS 'Clé primaire : identifie de manière unique chaque ligne dans "referentiel"."T_CategorieGenerique". Définition : PRIMARY KEY ("ID_CategorieGenerique").';

--
-- Name: T_ChampReferentiel T_ChampReferentiel_pkey; Type: CONSTRAINT; Schema: referentiel; Owner: -
--

ALTER TABLE ONLY referentiel."T_ChampReferentiel"
    ADD CONSTRAINT "T_ChampReferentiel_pkey" PRIMARY KEY ("ID_ChampReferentiel");

--
-- Name: CONSTRAINT "T_ChampReferentiel_pkey" ON "T_ChampReferentiel"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON CONSTRAINT "T_ChampReferentiel_pkey" ON referentiel."T_ChampReferentiel" IS 'Intégrité du référencement physique : PRIMARY KEY ("ID_ChampReferentiel")';

--
-- Name: T_InterfaceTableau T_InterfaceTableau_pkey; Type: CONSTRAINT; Schema: referentiel; Owner: -
--

ALTER TABLE ONLY referentiel."T_InterfaceTableau"
    ADD CONSTRAINT "T_InterfaceTableau_pkey" PRIMARY KEY ("CleInterface");

--
-- Name: CONSTRAINT "T_InterfaceTableau_pkey" ON "T_InterfaceTableau"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON CONSTRAINT "T_InterfaceTableau_pkey" ON referentiel."T_InterfaceTableau" IS 'Une configuration de référence par identifiant stable d’interface.';

--
-- Name: T_PreferenceTableau T_PreferenceTableau_pkey; Type: CONSTRAINT; Schema: referentiel; Owner: -
--

ALTER TABLE ONLY referentiel."T_PreferenceTableau"
    ADD CONSTRAINT "T_PreferenceTableau_pkey" PRIMARY KEY ("ID_PreferenceTableau");

--
-- Name: CONSTRAINT "T_PreferenceTableau_pkey" ON "T_PreferenceTableau"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON CONSTRAINT "T_PreferenceTableau_pkey" ON referentiel."T_PreferenceTableau" IS 'Identité technique unique de la préférence.';

--
-- Name: T_ChampReferentiel uq_champ_referentiel_physique; Type: CONSTRAINT; Schema: referentiel; Owner: -
--

ALTER TABLE ONLY referentiel."T_ChampReferentiel"
    ADD CONSTRAINT uq_champ_referentiel_physique UNIQUE ("SchemaName", "TableName", "ColumnName");

--
-- Name: CONSTRAINT uq_champ_referentiel_physique ON "T_ChampReferentiel"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON CONSTRAINT uq_champ_referentiel_physique ON referentiel."T_ChampReferentiel" IS 'Intégrité du référencement physique : UNIQUE ("SchemaName", "TableName", "ColumnName")';

--
-- Name: T_PreferenceTableau uq_preference_tableau_portee; Type: CONSTRAINT; Schema: referentiel; Owner: -
--

ALTER TABLE ONLY referentiel."T_PreferenceTableau"
    ADD CONSTRAINT uq_preference_tableau_portee UNIQUE NULLS NOT DISTINCT ("CleInterfaceFk", "IdUserFk", "IdEntiteFk", "Usage");

--
-- Name: CONSTRAINT uq_preference_tableau_portee ON "T_PreferenceTableau"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON CONSTRAINT uq_preference_tableau_portee ON referentiel."T_PreferenceTableau" IS 'Un choix par utilisateur, entreprise, interface et usage, y compris le contexte global NULL.';

--
-- Name: INDEX "Pk_T_Generique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON INDEX referentiel."Pk_T_Generique" IS 'Index support de la clé primaire sur "referentiel"."T_Generique". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX "Pk_T_Generique" ON referentiel."T_Generique" USING btree ("ID_Generique").';

--
-- Name: INDEX "T_CategorieGenerique_pkey"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON INDEX referentiel."T_CategorieGenerique_pkey" IS 'Index support de la clé primaire sur "referentiel"."T_CategorieGenerique". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE UNIQUE INDEX "T_CategorieGenerique_pkey" ON referentiel."T_CategorieGenerique" USING btree ("ID_CategorieGenerique").';

--
-- Name: INDEX "T_ChampReferentiel_pkey"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON INDEX referentiel."T_ChampReferentiel_pkey" IS 'Accès par identité immuable au catalogue des champs.';

--
-- Name: INDEX "T_InterfaceTableau_pkey"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON INDEX referentiel."T_InterfaceTableau_pkey" IS 'Accès exact au catalogue de colonnes par interface.';

--
-- Name: INDEX "T_PreferenceTableau_pkey"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON INDEX referentiel."T_PreferenceTableau_pkey" IS 'Recherche technique d’une préférence.';

--
-- Name: generique_type_cmd_unique; Type: INDEX; Schema: referentiel; Owner: -
--

CREATE UNIQUE INDEX generique_type_cmd_unique ON referentiel."T_Generique" USING btree ("ID_CategorieGeneriqueFk") WHERE (("ID_CategorieGeneriqueFk" = 64) AND (upper(btrim(("AbrGenerique")::text)) = 'CMD'::text));

--
-- Name: INDEX generique_type_cmd_unique; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON INDEX referentiel.generique_type_cmd_unique IS 'Une seule valeur CMD dans Type de commande ; l’identifiant est attribué par le référentiel et non figé dans les services.';

--
-- Name: idx_generique_id_categorie; Type: INDEX; Schema: referentiel; Owner: -
--

CREATE INDEX idx_generique_id_categorie ON referentiel."T_Generique" USING btree ("ID_CategorieGeneriqueFk") WITH (fillfactor='100', deduplicate_items='true');

--
-- Name: INDEX idx_generique_id_categorie; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON INDEX referentiel.idx_generique_id_categorie IS 'Index d’accès sur "referentiel"."T_Generique". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_generique_id_categorie ON referentiel."T_Generique" USING btree ("ID_CategorieGeneriqueFk") WITH (fillfactor=''100'', deduplicate_items=''true'').';

--
-- Name: ix_categorie_generique_entite; Type: INDEX; Schema: referentiel; Owner: -
--

CREATE INDEX ix_categorie_generique_entite ON referentiel."T_CategorieGenerique" USING btree ("IdEntiteFk");

--
-- Name: INDEX ix_categorie_generique_entite; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON INDEX referentiel.ix_categorie_generique_entite IS 'Lecture des catégories communes et propres au contexte autorisé.';

--
-- Name: ix_categorie_generique_nom_normalise; Type: INDEX; Schema: referentiel; Owner: -
--

CREATE INDEX ix_categorie_generique_nom_normalise ON referentiel."T_CategorieGenerique" USING btree (referentiel.fn_normaliser_libelle(("NomCategorieGenerique")::text));

--
-- Name: INDEX ix_categorie_generique_nom_normalise; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON INDEX referentiel.ix_categorie_generique_nom_normalise IS 'Recherche des ambiguïtés de nom sans supprimer les anciens doublons ; la garde sérialise les nouvelles identités.';

--
-- Name: ix_champ_referentiel_alias; Type: INDEX; Schema: referentiel; Owner: -
--

CREATE INDEX ix_champ_referentiel_alias ON referentiel."T_ChampReferentiel" USING gin ("AliasSourceKeys");

--
-- Name: INDEX ix_champ_referentiel_alias; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON INDEX referentiel.ix_champ_referentiel_alias IS 'Résolution explicite des anciens SourceKey partagés vers leurs colonnes physiques, sans supposer que les alias sont des noms de champs.';

--
-- Name: ix_generique_code_normalise; Type: INDEX; Schema: referentiel; Owner: -
--

CREATE INDEX ix_generique_code_normalise ON referentiel."T_Generique" USING btree ("ID_CategorieGeneriqueFk", referentiel.fn_normaliser_libelle(("AbrGenerique")::text));

--
-- Name: INDEX ix_generique_code_normalise; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON INDEX referentiel.ix_generique_code_normalise IS 'Comparaison du code facultatif dans la catégorie ; les anciens codes identiques restent conservés.';

--
-- Name: ix_generique_entite_categorie; Type: INDEX; Schema: referentiel; Owner: -
--

CREATE INDEX ix_generique_entite_categorie ON referentiel."T_Generique" USING btree ("IdEntiteFk", "ID_CategorieGeneriqueFk");

--
-- Name: INDEX ix_generique_entite_categorie; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON INDEX referentiel.ix_generique_entite_categorie IS 'Lecture des valeurs d’une catégorie dans la portée propriétaire autorisée.';

--
-- Name: ix_generique_nom_normalise; Type: INDEX; Schema: referentiel; Owner: -
--

CREATE INDEX ix_generique_nom_normalise ON referentiel."T_Generique" USING btree ("ID_CategorieGeneriqueFk", referentiel.fn_normaliser_libelle(("NomGenerique")::text));

--
-- Name: INDEX ix_generique_nom_normalise; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON INDEX referentiel.ix_generique_nom_normalise IS 'Comparaison du libellé dans sa famille et sa portée effective ; aucune consolidation des identifiants historiques.';

--
-- Name: INDEX uq_champ_referentiel_physique; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON INDEX referentiel.uq_champ_referentiel_physique IS 'Une seule définition et un seul défaut de référence par colonne physique à clé étrangère.';

--
-- Name: INDEX uq_preference_tableau_portee; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON INDEX referentiel.uq_preference_tableau_portee IS 'Accès indexé à la préférence personnelle et unicité en concurrence.';

--
-- Name: T_Generique aa_reference_utilisee_integrite; Type: TRIGGER; Schema: referentiel; Owner: -
--

CREATE TRIGGER aa_reference_utilisee_integrite BEFORE DELETE OR UPDATE ON referentiel."T_Generique" FOR EACH ROW EXECUTE FUNCTION referentiel.tr_reference_utilisee_integrite();

--
-- Name: TRIGGER aa_reference_utilisee_integrite ON "T_Generique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON TRIGGER aa_reference_utilisee_integrite ON referentiel."T_Generique" IS 'Protection transversale des références utilisées, sans réécrire les anciennes données hors famille.';

--
-- Name: T_CategorieGenerique ab_categorie_portee_doublon; Type: TRIGGER; Schema: referentiel; Owner: -
--

CREATE TRIGGER ab_categorie_portee_doublon BEFORE INSERT OR UPDATE ON referentiel."T_CategorieGenerique" FOR EACH ROW EXECUTE FUNCTION referentiel.tr_categorie_portee_doublon();

--
-- Name: TRIGGER ab_categorie_portee_doublon ON "T_CategorieGenerique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON TRIGGER ab_categorie_portee_doublon ON referentiel."T_CategorieGenerique" IS 'Garde des nouvelles identités de familles et de leur portée durable, sans correction implicite des données anciennes.';

--
-- Name: T_Generique ab_generique_portee_doublon; Type: TRIGGER; Schema: referentiel; Owner: -
--

CREATE TRIGGER ab_generique_portee_doublon BEFORE INSERT OR UPDATE ON referentiel."T_Generique" FOR EACH ROW EXECUTE FUNCTION referentiel.tr_generique_portee_doublon();

--
-- Name: TRIGGER ab_generique_portee_doublon ON "T_Generique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON TRIGGER ab_generique_portee_doublon ON referentiel."T_Generique" IS 'Valide la portée et les changements d’identité ; respecte les gardes métier existantes des devises, unités et types de bon utilisés.';

--
-- Name: T_Generique devise_logistique_reference_integrite; Type: TRIGGER; Schema: referentiel; Owner: -
--

CREATE TRIGGER devise_logistique_reference_integrite BEFORE UPDATE OF "ID_CategorieGeneriqueFk", "AbrGenerique" ON referentiel."T_Generique" FOR EACH ROW EXECUTE FUNCTION logistique.tr_proteger_reference_devise();

--
-- Name: TRIGGER devise_logistique_reference_integrite ON "T_Generique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON TRIGGER devise_logistique_reference_integrite ON referentiel."T_Generique" IS 'Stabilité du code monétaire des montants historiques logistiques.';

--
-- Name: T_Generique precision_stock_reference_integrite; Type: TRIGGER; Schema: referentiel; Owner: -
--

CREATE TRIGGER precision_stock_reference_integrite BEFORE DELETE OR UPDATE OF "ID_Generique", "ID_CategorieGeneriqueFk" ON referentiel."T_Generique" FOR EACH ROW EXECUTE FUNCTION logistique.tr_proteger_unite_precision_stock();

--
-- Name: TRIGGER precision_stock_reference_integrite ON "T_Generique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON TRIGGER precision_stock_reference_integrite ON referentiel."T_Generique" IS 'Protège les unités utilisées sans placer de paramètre logistique dans la table de nomenclature.';

--
-- Name: T_ChampReferentiel tr_catalogue_champ_integrite; Type: TRIGGER; Schema: referentiel; Owner: -
--

CREATE TRIGGER tr_catalogue_champ_integrite BEFORE INSERT OR DELETE OR UPDATE ON referentiel."T_ChampReferentiel" FOR EACH ROW EXECUTE FUNCTION referentiel.tr_catalogue_champ_integrite();

--
-- Name: TRIGGER tr_catalogue_champ_integrite ON "T_ChampReferentiel"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON TRIGGER tr_catalogue_champ_integrite ON referentiel."T_ChampReferentiel" IS 'Catalogue et défauts fermés aux écritures ordinaires ; version alimentée par les jeux de correspondances.';

--
-- Name: T_InterfaceTableau tr_catalogue_tableau_verifier; Type: TRIGGER; Schema: referentiel; Owner: -
--

CREATE TRIGGER tr_catalogue_tableau_verifier BEFORE INSERT OR UPDATE ON referentiel."T_InterfaceTableau" FOR EACH ROW EXECUTE FUNCTION referentiel.fn_catalogue_tableau_verifier();

--
-- Name: TRIGGER tr_catalogue_tableau_verifier ON "T_InterfaceTableau"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON TRIGGER tr_catalogue_tableau_verifier ON referentiel."T_InterfaceTableau" IS 'Contrôle structurel des configurations de référence, sans écriture lors d’une consultation.';

--
-- Name: T_Generique tr_guard_sens_stock; Type: TRIGGER; Schema: referentiel; Owner: -
--

CREATE TRIGGER tr_guard_sens_stock BEFORE UPDATE ON referentiel."T_Generique" FOR EACH ROW EXECUTE FUNCTION referentiel.fn_guard_sens_stock();

--
-- Name: TRIGGER tr_guard_sens_stock ON "T_Generique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON TRIGGER tr_guard_sens_stock ON referentiel."T_Generique" IS 'Protège les sens physiques et la nature CMD des types déjà utilisés, sans figer les libellés ni les nouveaux identifiants de valeur.';

--
-- Name: T_PreferenceTableau tr_preference_tableau_verifier; Type: TRIGGER; Schema: referentiel; Owner: -
--

CREATE TRIGGER tr_preference_tableau_verifier BEFORE INSERT OR DELETE OR UPDATE ON referentiel."T_PreferenceTableau" FOR EACH ROW EXECUTE FUNCTION referentiel.fn_preference_tableau_verifier();

--
-- Name: TRIGGER tr_preference_tableau_verifier ON "T_PreferenceTableau"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON TRIGGER tr_preference_tableau_verifier ON referentiel."T_PreferenceTableau" IS 'Refuse les colonnes inconnues, actions exportables, changements de propriétaire et incohérences de portée.';

--
-- Name: T_Generique Fk_ID_CategorieGenerique; Type: FK CONSTRAINT; Schema: referentiel; Owner: -
--

ALTER TABLE ONLY referentiel."T_Generique"
    ADD CONSTRAINT "Fk_ID_CategorieGenerique" FOREIGN KEY ("ID_CategorieGeneriqueFk") REFERENCES referentiel."T_CategorieGenerique"("ID_CategorieGenerique") ON UPDATE CASCADE;

--
-- Name: CONSTRAINT "Fk_ID_CategorieGenerique" ON "T_Generique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON CONSTRAINT "Fk_ID_CategorieGenerique" ON referentiel."T_Generique" IS 'Clé étrangère : impose le rattachement et les actions référentielles dans "referentiel"."T_Generique". Définition : FOREIGN KEY ("ID_CategorieGeneriqueFk") REFERENCES referentiel."T_CategorieGenerique"("ID_CategorieGenerique") ON UPDATE CASCADE.';

--
-- Name: T_CategorieGenerique T_CategorieGenerique_IdEntiteFk_fkey; Type: FK CONSTRAINT; Schema: referentiel; Owner: -
--

ALTER TABLE ONLY referentiel."T_CategorieGenerique"
    ADD CONSTRAINT "T_CategorieGenerique_IdEntiteFk_fkey" FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON DELETE RESTRICT;

--
-- Name: CONSTRAINT "T_CategorieGenerique_IdEntiteFk_fkey" ON "T_CategorieGenerique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON CONSTRAINT "T_CategorieGenerique_IdEntiteFk_fkey" ON referentiel."T_CategorieGenerique" IS 'La catégorie privée appartient à une entreprise réelle qui ne peut être supprimée tant que la référence existe.';

--
-- Name: T_ChampReferentiel T_ChampReferentiel_ID_CategorieDefautFk_fkey; Type: FK CONSTRAINT; Schema: referentiel; Owner: -
--

ALTER TABLE ONLY referentiel."T_ChampReferentiel"
    ADD CONSTRAINT "T_ChampReferentiel_ID_CategorieDefautFk_fkey" FOREIGN KEY ("ID_CategorieDefautFk") REFERENCES referentiel."T_CategorieGenerique"("ID_CategorieGenerique") ON DELETE RESTRICT;

--
-- Name: CONSTRAINT "T_ChampReferentiel_ID_CategorieDefautFk_fkey" ON "T_ChampReferentiel"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON CONSTRAINT "T_ChampReferentiel_ID_CategorieDefautFk_fkey" ON referentiel."T_ChampReferentiel" IS 'Intégrité du référencement physique : FOREIGN KEY ("ID_CategorieDefautFk") REFERENCES referentiel."T_CategorieGenerique"("ID_CategorieGenerique") ON DELETE RESTRICT';

--
-- Name: T_ChampReferentiel T_ChampReferentiel_ModifieParUserFk_fkey; Type: FK CONSTRAINT; Schema: referentiel; Owner: -
--

ALTER TABLE ONLY referentiel."T_ChampReferentiel"
    ADD CONSTRAINT "T_ChampReferentiel_ModifieParUserFk_fkey" FOREIGN KEY ("ModifieParUserFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON DELETE SET NULL;

--
-- Name: CONSTRAINT "T_ChampReferentiel_ModifieParUserFk_fkey" ON "T_ChampReferentiel"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON CONSTRAINT "T_ChampReferentiel_ModifieParUserFk_fkey" ON referentiel."T_ChampReferentiel" IS 'Intégrité du référencement physique : FOREIGN KEY ("ModifieParUserFk") REFERENCES systeme."T_Utilisateurs"("IdUser") ON DELETE SET NULL';

--
-- Name: T_Generique T_Generique_IdEntiteFk_fkey; Type: FK CONSTRAINT; Schema: referentiel; Owner: -
--

ALTER TABLE ONLY referentiel."T_Generique"
    ADD CONSTRAINT "T_Generique_IdEntiteFk_fkey" FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite") ON DELETE RESTRICT;

--
-- Name: CONSTRAINT "T_Generique_IdEntiteFk_fkey" ON "T_Generique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON CONSTRAINT "T_Generique_IdEntiteFk_fkey" ON referentiel."T_Generique" IS 'La valeur privée appartient à une entreprise réelle ; ses identifiants métier ne sont pas déplacés à la suppression du propriétaire.';

--
-- Name: T_PreferenceTableau T_PreferenceTableau_CleInterfaceFk_fkey; Type: FK CONSTRAINT; Schema: referentiel; Owner: -
--

ALTER TABLE ONLY referentiel."T_PreferenceTableau"
    ADD CONSTRAINT "T_PreferenceTableau_CleInterfaceFk_fkey" FOREIGN KEY ("CleInterfaceFk") REFERENCES referentiel."T_InterfaceTableau"("CleInterface");

--
-- Name: CONSTRAINT "T_PreferenceTableau_CleInterfaceFk_fkey" ON "T_PreferenceTableau"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON CONSTRAINT "T_PreferenceTableau_CleInterfaceFk_fkey" ON referentiel."T_PreferenceTableau" IS 'La préférence concerne obligatoirement une interface enregistrée.';

--
-- Name: T_PreferenceTableau T_PreferenceTableau_IdEntiteFk_fkey; Type: FK CONSTRAINT; Schema: referentiel; Owner: -
--

ALTER TABLE ONLY referentiel."T_PreferenceTableau"
    ADD CONSTRAINT "T_PreferenceTableau_IdEntiteFk_fkey" FOREIGN KEY ("IdEntiteFk") REFERENCES systeme."T_Entite"("IdEntite");

--
-- Name: CONSTRAINT "T_PreferenceTableau_IdEntiteFk_fkey" ON "T_PreferenceTableau"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON CONSTRAINT "T_PreferenceTableau_IdEntiteFk_fkey" ON referentiel."T_PreferenceTableau" IS 'Le contexte d’entreprise référencé existe.';

--
-- Name: T_PreferenceTableau T_PreferenceTableau_IdUserFk_fkey; Type: FK CONSTRAINT; Schema: referentiel; Owner: -
--

ALTER TABLE ONLY referentiel."T_PreferenceTableau"
    ADD CONSTRAINT "T_PreferenceTableau_IdUserFk_fkey" FOREIGN KEY ("IdUserFk") REFERENCES systeme."T_Utilisateurs"("IdUser");

--
-- Name: CONSTRAINT "T_PreferenceTableau_IdUserFk_fkey" ON "T_PreferenceTableau"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON CONSTRAINT "T_PreferenceTableau_IdUserFk_fkey" ON referentiel."T_PreferenceTableau" IS 'Le propriétaire de la préférence est un utilisateur existant.';
