-- Extrait canonique du catalogue installé le 28/10/2026, sans données ni propriétaires imposés.
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
-- Name: fn_guard_sens_stock(); Type: FUNCTION; Schema: referentiel; Owner: -
--

CREATE FUNCTION referentiel.fn_guard_sens_stock() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE old_sign integer; new_sign integer;
BEGIN
 IF OLD."ID_CategorieGeneriqueFk"=64 AND (
 EXISTS(SELECT 1 FROM logistique."T_Commande" WHERE "ID_TypeCmdFk"=OLD."ID_Generique") OR
 EXISTS(SELECT 1 FROM logistique."T_Mouvement" WHERE "ID_TypeMvtFk"=OLD."ID_Generique")) THEN
  old_sign:=CASE WHEN OLD."AbrGenerique" ILIKE 'entr%' THEN 1 WHEN OLD."AbrGenerique" ILIKE 'sort%' THEN -1 ELSE 0 END;
  new_sign:=CASE WHEN NEW."AbrGenerique" ILIKE 'entr%' THEN 1 WHEN NEW."AbrGenerique" ILIKE 'sort%' THEN -1 ELSE 0 END;
  IF NEW."ID_CategorieGeneriqueFk"<>64 OR new_sign<>old_sign THEN
   RAISE EXCEPTION 'Le sens d’un type de stock déjà utilisé ne peut pas être changé.' USING ERRCODE='23514';
  END IF;
 END IF;
 RETURN NEW;
END;$$;

--
-- Name: FUNCTION fn_guard_sens_stock(); Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON FUNCTION referentiel.fn_guard_sens_stock() IS 'Protège le signe Entrée/Sortie et la catégorie 64 d’un type déjà utilisé par une commande ou un mouvement ; évite une réinterprétation rétroactive du stock. Un changement de libellé conservant le signe reste permis.';

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
    "ValideGenerique" boolean DEFAULT true CONSTRAINT "T_Generique_ValideGenerique_not_null" NOT NULL
);

--
-- Name: TABLE "T_Generique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON TABLE referentiel."T_Generique" IS 'Valeurs des nomenclatures rattachées à une catégorie : libellé, abréviation, visibilité par usage et validité. La signification métier dépend de la catégorie.';

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
    "ValideCategorieGenerique" boolean DEFAULT true
);

--
-- Name: TABLE "T_CategorieGenerique"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON TABLE referentiel."T_CategorieGenerique" IS 'Catégories de nomenclature : nom, module d’usage et validité. Regroupe les valeurs de T_Generique.';

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
    CONSTRAINT ck_interface_tableau_module CHECK (("Module" = ANY (ARRAY['logistique'::text, 'referentiels'::text, 'administration'::text])))
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

COMMENT ON CONSTRAINT ck_interface_tableau_module ON referentiel."T_InterfaceTableau" IS 'Modules initialement couverts par le mécanisme transverse.';

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
-- Name: INDEX "T_InterfaceTableau_pkey"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON INDEX referentiel."T_InterfaceTableau_pkey" IS 'Accès exact au catalogue de colonnes par interface.';

--
-- Name: INDEX "T_PreferenceTableau_pkey"; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON INDEX referentiel."T_PreferenceTableau_pkey" IS 'Recherche technique d’une préférence.';

--
-- Name: idx_generique_id_categorie; Type: INDEX; Schema: referentiel; Owner: -
--

CREATE INDEX idx_generique_id_categorie ON referentiel."T_Generique" USING btree ("ID_CategorieGeneriqueFk") WITH (fillfactor='100', deduplicate_items='true');

--
-- Name: INDEX idx_generique_id_categorie; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON INDEX referentiel.idx_generique_id_categorie IS 'Index d’accès sur "referentiel"."T_Generique". La définition précise méthode, colonnes/expressions, ordre et éventuel prédicat partiel : CREATE INDEX idx_generique_id_categorie ON referentiel."T_Generique" USING btree ("ID_CategorieGeneriqueFk") WITH (fillfactor=''100'', deduplicate_items=''true'').';

--
-- Name: INDEX uq_preference_tableau_portee; Type: COMMENT; Schema: referentiel; Owner: -
--

COMMENT ON INDEX referentiel.uq_preference_tableau_portee IS 'Accès indexé à la préférence personnelle et unicité en concurrence.';

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

COMMENT ON TRIGGER tr_guard_sens_stock ON referentiel."T_Generique" IS 'Empêche qu’une modification du référentiel inverse ou efface le sens d’un historique de stock existant.';

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
